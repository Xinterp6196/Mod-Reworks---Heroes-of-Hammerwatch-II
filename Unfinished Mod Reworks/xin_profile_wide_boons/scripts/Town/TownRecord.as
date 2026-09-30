TownRecord@ g_myTownRecord;
TownRecord@ g_currTownRecord;


class ActiveHeroTitle : IModifierProvider
{
	HeroTitle@ m_title;
	int m_level;
	uint m_uniqueKey;
	
	string GetModifierProviderName() 
	{
		if (m_uniqueKey == 0)
			return m_title.m_name;
		return m_title.m_name + " (" + Resources::GetString(".menu.loadgame.charlevel_short", {{"level", m_level}}) + ")";
	}
}

class TownRecord
{
	// Userdata that can be used by mods. This does NOT save by itself.
	dictionary userdata;

	array<BuildingManagement::PlacedBuilding@> m_buildings;
	array<WorldScript::BuildingPlot@> m_plots;

	int m_ngp;

	array<ActiveHeroTitle@> m_heroTitles;
	array<ActiveHeroTitle@> m_donationTitles;
	array<pint> m_materials;

	array<uint> m_townFlags;
	array<uint32> m_unlockedBoons;
	BlueprintBank m_blueprints;

	StatCollection@ statsTown;

	TownStash@ m_townStash;
	StashSorting m_sorting;
	StashHiding m_hiding;

	Stats::StatAccomplishmentReward@ m_accomplishmentRewards;


	bool HasTownFlag(uint nameHash)
	{
		return m_townFlags.find(nameHash) >= 0;
	}

	void SetTownFlag(uint nameHash, bool value, bool netSync = true)
	{
		if (value)
		{
			int idx = m_townFlags.find(nameHash);
			if (idx < 0)
				m_townFlags.insertLast(nameHash);
		}
		else
		{
			while(true)
			{
				int idx = m_townFlags.find(nameHash);
				if (idx >= 0)
					m_townFlags.removeAt(idx);
				else
					break;
			}
		}
		
		if (netSync)
			(Network::Message("SetTownFlag") << nameHash << value).SendToAll();
	}

	bool HasUnlockedBoon(uint32 boonId)
	{
		return m_unlockedBoons.find(boonId) >= 0;
	}

	void UnlockBoon(uint32 boonId, bool netSync = true)
	{
		if (m_unlockedBoons.find(boonId) >= 0)
			return;

		m_unlockedBoons.insertLast(boonId);

		if (netSync)
			(Network::Message("UnlockBoon") << boonId).SendToAll();
	}

	TownRecord()
	{
		@statsTown = StatCollection(0, 0);
		InitializeStatCollection();
		
		while(m_materials.length() < MaterialType::Num)
			m_materials.insertLast(0);

		@m_townStash = TownStash();
		m_sorting = StashSorting::None;
		m_hiding = StashHiding::None;

		Hooks::Call("TownRecordConstructor", @this);
	}

	void InitializeStatCollection()
	{
		Stats::InitializeCollection(statsTown);
		
		for (uint i = 0; i < Item::Trinket::Instances.length(); i++)
		{
			auto trinket = Item::Trinket::Instances[i];
			statsTown.MakeStat("trinket-found-" + trinket.m_id, StatCollType::Int32);
		}
	}

	void AddBuilding(BuildingManagement::BuildingDef@ buildingDef, WorldScript::BuildingPlot@ plot, uint variation = 0)
	{
		if (plot !is null && !IsPlotEmpty(plot))
		{
			PrintError("Plot is not empty.");
			return;
		}
		
		BuildingManagement::PlacedBuilding newBuilding;
		
		@newBuilding.buildingDef = buildingDef;
		newBuilding.variation = variation;
		if (plot !is null)
			newBuilding.plotHash = plot.m_idHash;
		else
			newBuilding.plotHash = 0;
		
		m_buildings.insertLast(newBuilding);
		Refresh(plot);
	}

	void IncrementVariationOnBuilding(BuildingManagement::BuildingDef@ buildingDef)
	{
		for (uint i = 0; i < m_buildings.length(); i++)
		{
			auto building = m_buildings[i];
			if (building.buildingDef is buildingDef)
			{
				building.variation = min(building.variation + 1, building.buildingDef.m_variations.length() - 1);
				Refresh(GetPlot(building.plotHash));
				return;
			}
		}
	}

	int GetVariationOnBuilding(uint buildingId)
	{
		for (uint i = 0; i < m_buildings.length(); i++)
		{
			if (m_buildings[i].buildingDef.m_idHash == buildingId)
				return m_buildings[i].variation;
		}
		
		return -1;
	}

	void RemoveBuilding(WorldScript::BuildingPlot@ plot)
	{
		for (uint i = 0; i < m_buildings.length(); i++)
		{
			if (m_buildings[i].plotHash == plot.m_idHash)
			{
				m_buildings.removeAt(i);
				Refresh(plot);
				return;
			}
		}
	}

	void NetRefresh(vec2 spawnPos = vec2(-1, -1))
	{
		print("NetRefresh: " + spawnPos);
		
		m_plots.removeRange(0, m_plots.length());
		WorldScript::ClearTimers();
		QuickReloadLevel();
		
		for (uint i = 0; i < g_players.length(); i++)
			@g_players[i].actor = null;
		
		auto gm = cast<AGameplayGameMode>(g_gameMode);
		if (gm !is null)
			gm.SpawnLocalPlayers(spawnPos);
		auto gm2 = cast<HWR2GameMode>(g_gameMode);
		if (gm2 !is null)
			gm2.m_fadeinC = 300;
	}


	void Refresh(WorldScript::BuildingPlot@ plot = null)
	{
		if (this is g_myTownRecord)
		{
			int numBuilt = 0;
			for (uint i = 0; i < m_buildings.length(); i++)
				numBuilt += m_buildings[i].variation + 1;
			
			%STAT Max buildings-built numBuilt
		}
		
		if (g_currTownRecord !is this)
			return;
		
		vec2 plrRespawnPos = vec2(-1, -1);
		
		BuildingManagement::BuildingPlotDef@ plotDef = null;
		if (plot !is null)
			@plotDef = BuildingManagement::BuildingPlotDef::Get(plot.m_plotDefHash);
		
		for (uint i = 0; i < g_players.length(); i++)
		{
			if (g_players[i].peer == 255)
				continue;
			
			auto plr = g_players[i];
			if (plr.actor is null)
			{
				if (!plr.local)
					(Network::Message("RefreshTown")).SendToPeer(plr.peer);
				continue;
			}
			
			vec2 spawnPos = xy(plr.actor.m_unit.GetPosition());
			if (plotDef !is null)
			{
				int plotW2 = plotDef.m_width / 2;
				int plotH2 = plotDef.m_height / 2;
				vec2 p = vec2(spawnPos.x - plot.Position.x, spawnPos.y - plot.Position.y);
				if (p.x > -plotW2 && p.x < plotW2 && p.y > -plotH2 && p.y < plotH2)
				{
					if (abs(p.x) > abs(p.y))
						p.x = p.x < 0 ? -plotW2 : plotW2;
					else
						p.y = p.y < 0 ? -plotH2 : plotH2;
					
					spawnPos = xy(plot.Position) + p;
				}
			}
			print("Making spawn pos: " + spawnPos);
			
			if (!plr.local)
				(Network::Message("RefreshTownSpawnPos") << spawnPos).SendToPeer(plr.peer);
			else
				plrRespawnPos = spawnPos;
		}
		//else
		//	(Network::Message("RefreshTown")).SendToAll();
		
		m_plots.removeRange(0, m_plots.length());
		WorldScript::ClearTimers();
		QuickReloadLevel();
		
		for (uint i = 0; i < g_players.length(); i++)
			@g_players[i].actor = null;
		
		
		SpawnTown();
		
		auto gm = cast<AGameplayGameMode>(g_gameMode);
		if (gm !is null)
			gm.SpawnLocalPlayers(plrRespawnPos);
		auto gm2 = cast<HWR2GameMode>(g_gameMode);
		if (gm2 !is null)
			gm2.m_fadeinC = 300;
	}

	BuildingManagement::PlacedBuilding@ GetPlacedBuildingOnPlot(WorldScript::BuildingPlot@ plot)
	{
		for (uint i = 0; i < m_buildings.length(); i++)
		{
			auto building = m_buildings[i];
			if (building.plotHash == plot.m_idHash)
				return building;
		}
		
		return null;
	}

	BuildingManagement::PlacedBuilding@ GetPlacedBuildingWithoutPlot(BuildingManagement::BuildingDef@ buildingDef)
	{
		for (uint i = 0; i < m_buildings.length(); i++)
		{
			auto building = m_buildings[i];
			if (building.plotHash == 0 && building.buildingDef is buildingDef)
				return building;
		}
		
		return null;
	}

	WorldScript::BuildingPlot@ GetPlot(const string &in id)
	{
		return GetPlot(HashString(id));
	}

	WorldScript::BuildingPlot@ GetPlot(uint id)
	{
		if (id == 0)
			return null;
		
		for (uint i = 0; i < m_plots.length(); i++)
		{
			if (m_plots[i].m_idHash == id)
				return m_plots[i];
		}
		
		return null;
	}

	bool IsPlotEmpty(WorldScript::BuildingPlot@ plot)
	{
		for (uint i = 0; i < m_buildings.length(); i++)
		{
			if (m_buildings[i].plotHash == plot.m_idHash)
				return false;
		}

		return true;
	}


	int GiveMaterial(MaterialType type, int amount)
	{
		if (amount == 0)
			return 0;

		int preMaterial = m_materials[int(type)];
		m_materials[int(type)] = max(0, m_materials[int(type)] + amount);

		return m_materials[int(type)] - preMaterial;
	}

	int GetMaterial(MaterialType type)
	{
		return m_materials[int(type)];
	}

	bool Save(SValueBuilder& builder)
	{
		int totMats = 0;
		for (uint i = 0; i < m_materials.length(); i++)
			totMats += m_materials[i];
		
		if (m_buildings.length() <= 0 && m_townFlags.length() <= 0 && m_unlockedBoons.length() <= 0 && totMats <= 0)
			return false;

		builder.PushDictionary();
		builder.PushInteger("ngp", m_ngp);

		builder.PushArray("buildings");
		for (uint i = 0; i < m_buildings.length(); i++)
		{
			builder.PushDictionary();
			builder.PushInteger("building-def", m_buildings[i].buildingDef.m_idHash);
			builder.PushInteger("plot", m_buildings[i].plotHash);
			builder.PushInteger("variation", m_buildings[i].variation);
			builder.PopDictionary();
		}
		builder.PopArray();

		builder.PushArray("materials");
		for (uint i = 0; i < m_materials.length(); i++)
			builder.PushInteger(m_materials[i]);
		builder.PopArray();

		builder.PushArray("flags");
		for (uint i = 0; i < m_townFlags.length(); i++)
			builder.PushInteger(m_townFlags[i]);
		builder.PopArray();

		builder.PushArray("unlocked-boons");
		for (uint i = 0; i < m_unlockedBoons.length(); i++)
			builder.PushInteger(m_unlockedBoons[i]);
		builder.PopArray();

		builder.PushArray("blueprints");
		m_blueprints.Save(builder);
		builder.PopArray();

		if (m_townStash !is null)
		{
			builder.PushArray("town-stash");
			m_townStash.Save(builder);
			builder.PopArray();
		}
		else
			print("TownStash is null!");

		builder.PushInteger("stash-sorting", int(m_sorting));
		builder.PushInteger("stash-hiding", int(m_hiding));

		builder.PushSimple("stats-town", statsTown.Save());


		try {
		Hooks::Call("TownRecordSave", @this, builder);
		} catch { PrintError("Exception when saving player record via hooks"); }

		builder.PopDictionary();

		return true;
	}

	void Load(SValue@ save)
	{
		if (save is null)
			return;

		if (!VerifyProperNetworking())
			return;

		UnitPtr u;

		m_ngp = GetParamInt(u, save, "ngp", false, -1);

		auto buildingData = save.GetDictionaryEntry("buildings");
		if (buildingData !is null)
		{
			auto arr = buildingData.GetArray();
			m_buildings.removeRange(0, m_buildings.length());
			for (uint i = 0; i < arr.length(); i++)
			{
				BuildingManagement::PlacedBuilding newBuilding;
				
				@newBuilding.buildingDef = BuildingManagement::BuildingDef::Get(uint(GetParamInt(u, arr[i], "building-def")));
				newBuilding.plotHash = uint(GetParamInt(u, arr[i], "plot"));
				newBuilding.variation = uint(GetParamInt(u, arr[i], "variation"));
				
				if (newBuilding.buildingDef is null)
					continue;
				
				m_buildings.insertLast(newBuilding);
			}
		}

		auto materialsArr = GetParamArray(u, save, "materials", false);
		if (materialsArr !is null)
		{
			m_materials.removeRange(0, m_materials.length());
			for (uint i = 0; i < materialsArr.length(); i++)
				m_materials.insertLast(int(materialsArr[i].GetInteger()));
		}
		while(m_materials.length() < MaterialType::Num)
			m_materials.insertLast(0);


		auto flagsArr = GetParamArray(u, save, "flags", false);
		if (flagsArr !is null)
		{
			m_townFlags.removeRange(0, m_townFlags.length());
			for (uint i = 0; i < flagsArr.length(); i++)
				m_townFlags.insertLast(uint(flagsArr[i].GetInteger()));
		}

		auto unlockedBoonsArr = GetParamArray(u, save, "unlocked-boons", false);
		if (unlockedBoonsArr !is null)
		{
			m_unlockedBoons.removeRange(0, m_unlockedBoons.length());
			for (uint i = 0; i < unlockedBoonsArr.length(); i++)
				m_unlockedBoons.insertLast(uint(unlockedBoonsArr[i].GetInteger()));
		}

		m_townStash.Load(GetParamArray(u, save, "town-stash", false));
		m_sorting = StashSorting(GetParamInt(u, save, "stash-sorting", false, 0));
		m_hiding = StashHiding(GetParamInt(u, save, "stash-hiding", false, 0));


		m_blueprints.Load(GetParamArray(u, save, "blueprints", false));

		Hooks::Call("TownRecordLoad", @this, @save);

		statsTown.Load(save.GetDictionaryEntry("stats-town"));
		InitializeStatCollection();

		if (this is g_myTownRecord)
		{
			RefreshHeroTitles();
			RefreshDonationTitles();
			RefreshStatAccomplishmentsTitles();
		}
	}

	BuildingManagement::BuildingDef@ GetBuildingDef(uint32 prefabHash)
	{
		auto pfb = Resources::GetPrefab(prefabHash);
		if (pfb is null)
			return null;
		
		for (uint i = 0; i < BuildingManagement::BuildingDef::Instances.length(); i++)
		{
			auto bDef = BuildingManagement::BuildingDef::Instances[i];
			if (bDef.m_unbuiltPrefab is pfb)
				return bDef;
			
			for (uint j = 0; j < bDef.m_variations.length(); j++)
			{
				if (bDef.m_variations[j].m_prefab is pfb)
					return bDef;
			}
		}
		
		return null;
	}

	void PlaceTownPlacedPrefab(CellGrid@ grid, uint32 pdbId, ivec2 pos)
	{
		auto pPfb = MissionPrefabDef::Get(pdbId);
		if (pPfb !is null)
		{
			print(" placing MissionPrefabDef! " + pPfb.m_id);
			if (pPfb.m_parent !is null)
			{
				@pPfb = pPfb.m_parent;
				print("   changed to " + pPfb.m_id);
			}
			
			if (!pPfb.CanGet())
				return;
			
			auto place = pPfb.UsePrefab();
			if (place is null)
				return;
			
			PlaceTownSegment(grid, place, pos - place.m_gridOffset);
		}
		
		auto pBld = GetBuildingDef(pdbId);
		if (pBld !is null)
		{
			auto placed = GetPlacedBuildingWithoutPlot(pBld);
			if (placed !is null)
			{
				auto variation = pBld.m_variations[min(pBld.m_variations.length() -1, placed.variation)];
				print(" placing BuildingDef " + pBld.m_id + ", variation! " + variation.m_name);
				PlaceBuilding(grid, variation, pos);
			}
			else if (pBld.m_unbuiltPrefab !is null)
			{
				print(" placing BuildingDef " + pBld.m_id + ", unbuilt prefab! " + pBld.m_unbuiltPrefab.GetDebugName());
				pBld.m_unbuiltPrefab.Fabricate(g_scene, vec3(pos.x * 16, pos.y * 16, 0), true);
				
				for (uint i = 0; i < pBld.m_unbuiltPlacedPrefabs.length(); i++)
				{
					auto p = pos + pBld.m_unbuiltPlacedPrefabs[i].m_pos;
					PlaceTownPlacedPrefab(grid, pBld.m_unbuiltPlacedPrefabs[i].m_id, p);
				}
			}
			else
				print(" BuildingDef not placed " + pBld.m_id);
		}
	}

	void PlaceTownSegment(CellGrid@ grid, MissionPrefabDef@ prefabDef, ivec2 pos)
	{
		print("placing TownSegment " + prefabDef.m_id);
		
		PatternMatcher::CopyPrefabPattern(grid, pos, prefabDef.m_gridPattern, prefabDef.m_gridCommand, prefabDef.m_gridSz);
		//m_brush.AddPointOfInterest(prefabDef, pos.x + prefabDef.m_gridOffset.x, pos.y + prefabDef.m_gridOffset.y);
		
		if (prefabDef.m_prefab !is null)
		{
			ivec2 p = (pos + prefabDef.m_gridOffset) * 16;
			prefabDef.m_prefab.Fabricate(g_scene, vec3(p.x, p.y, 0));
		}
		
		for (uint i = 0; i < prefabDef.m_placedPrefabs.length(); i++)
		{
			auto p = pos + prefabDef.m_placedPrefabs[i].m_pos + prefabDef.m_gridOffset;
			PlaceTownPlacedPrefab(grid, prefabDef.m_placedPrefabs[i].m_id, p);
		}
	}

	void PlaceBuilding(CellGrid@ grid, BuildingManagement::BuildingVariation@ building, ivec2 pos)
	{
		building.UnpackData();
		
		if (building.m_gridCommand !is null)
			PatternMatcher::CopyPrefabPattern(grid, pos - building.m_gridOffset, building.m_gridPattern, building.m_gridCommand, building.m_gridSz);
		
		if (building.m_prefab is null)
			PrintWarning("Building missing prefab: " + building.m_name);
		else
			building.m_prefab.Fabricate(g_scene, vec3(pos.x * 16, pos.y * 16, 0), true);
		
		for (uint i = 0; i < building.m_placedPrefabs.length(); i++)
		{
			auto p = pos + building.m_placedPrefabs[i].m_pos + building.m_gridOffset;
			PlaceTownPlacedPrefab(grid, building.m_placedPrefabs[i].m_id, p);
		}
	}

	void SpawnTown()
	{
		CellGrid grid;
		auto basePfbs = MissionPrefabDef::GetPossiblePrefabs(HashString("town_segment_base"));
		MissionPrefabDef@ basePfb = null;
		
		if (basePfbs.length() > 0)
		{
			@basePfb = basePfbs[MissionPrefabDef::RollIndex(basePfbs)];
			if (basePfb.CanGet())
				@basePfb = basePfb.UsePrefab();
			else
				@basePfb = null;
		}
		
		if (basePfb is null)
			return;
		
		g_genNumId = randi();
		grid.MakeGrid(basePfb.m_gridSz.x, basePfb.m_gridSz.y, Cell::Floor);
		PlaceTownSegment(grid, basePfb, ivec2());
		
		auto segments = MissionPrefabDef::GetPossiblePrefabs(HashString("town_segment"));
		print("Num town segments to place: " + segments.length());
		for (uint i = 0; i < segments.length(); i++)
		{
			if (!segments[i].CanGet())
				continue;
			
			auto mspfb = segments[i].UsePrefab();
			PlaceTownSegment(grid, segments[i], ivec2());
		}
		
		for (uint i = 0; i < m_buildings.length(); i++)
		{
			auto building = m_buildings[i];
			auto plot = GetPlot(building.plotHash);
			if (plot is null)
				continue;
			
			auto variation = building.buildingDef.m_variations[min(building.buildingDef.m_variations.length() -1, building.variation)];
			PlaceBuilding(grid, variation, ivec2(int(plot.Position.x / 16), int(plot.Position.y / 16)));
		}
		
		PrefabPlacement placement(grid);
		bool printPfb = GetVarBool("debug_dungeon_prefabs");
		/*
		for (int step = 1; step < 100; step++)
		{
			auto set = HashString("town_road_t1_step" + step);
			print("Placing prefabs: " + "town_road_t1_step" + step);
			if (placement.PlacePrefabs(set, 10000, 10000.0f) < 0)
				break;
			if (placement.PlacePrefabs(set, 10000, 10000.0f) > 0)
				placement.PlacePrefabs(set, 10000, 10000.0f);
		}
		*/
		
		auto@ pointsOfInterests = grid.m_pointsOfInterest;
		print("Spawning " + pointsOfInterests.length() + " road prefabs");
		for (uint i = 0; i < pointsOfInterests.length(); i++)
		{
			if (pointsOfInterests[i].m_type.m_prefab !is null)
			{
				vec2 offset = randdir(false) * pointsOfInterests[i].m_type.m_posJitter;
				vec3 pos = vec3(16 * pointsOfInterests[i].m_pos.x + offset.x, 16 * pointsOfInterests[i].m_pos.y + offset.y, 0);
				//g_prefabsToSpawn.insertLast(PrefabToSpawn(pointsOfInterests[i].m_type.m_prefab, pos));
				pointsOfInterests[i].m_type.m_prefab.Fabricate(g_scene, pos, true);
				
				if (printPfb)
					print("Spawning '" + pointsOfInterests[i].m_type.m_id + "'");
			}
			else
				PrintError("Failed to open prefab '" + pointsOfInterests[i].m_type.m_id + "'");
		}
		
		
		/*
		StringBuilder gridDbg;
		for (int x = 0; x < grid.m_width; x++)
		{
			for (int y = 0; y < grid.m_height; y++)
				gridDbg.Append(grid.m_grid[x][y]);
			gridDbg.Append("\n");
		}
		print("Grid:\n" + gridDbg.String());
		*/
		
		
		
		if (this is g_myTownRecord)
		{
			%STAT Max highest-ngp m_ngp
		}
/*
		for (uint i = 0; i < m_plots.length(); i++)
		{
			auto plot = m_plots[i];
			if (occupiedPlotsHashes.find(plot.m_idHash) == -1)
				BuildingManagement::BuildingPlotDef::Get(plot.m_plotDefHash).m_prefabRubble.Fabricate(g_scene, GetPlot(plot.m_idHash).Position);
		}
*/


		Hooks::Call("TownRecordSpawnTown", @this);
	}
	
	void RefreshHeroTitles()
	{
		%PROFILE_SCOPE RefreshHeroTitles
		
		UnitPtr u;
		
		int bestNgp = 0;
		
		auto characters = PersistentSaves::GetCharacterList();
		for (uint c = 0; c < characters.length(); c++)
		{
			if (characters[c] == 0)
				continue;
			
			SValue@ plrData = PersistentSaves::GetCharacter(characters[c]);
			if (plrData is null)
				continue;
			
			auto@ plrClass = PlayerClass::Get(GetParamString(u, plrData, "class", false, ""));
			if (plrClass is null || plrClass.m_title is null)
				continue;
			
			auto@ title = plrClass.m_title;
			int lvl = GetParamInt(u, plrData, "level", false, 1);
			if (m_ngp < 0)
				bestNgp = max(bestNgp, GetParamInt(u, plrData, "ngp", false, 0));
			
			bool added = false;
			for (uint t = 0; t < m_heroTitles.length(); t++)
			{
				if (m_heroTitles[t].m_title !is title)
					continue;
				
				if (lvl > m_heroTitles[t].m_level)
				{
					m_heroTitles[t].m_level = lvl;
					m_heroTitles[t].m_uniqueKey = characters[c];
				}
				added = true;
			}
			
			if (!added)
			{
				ActiveHeroTitle activeTitle;
				@activeTitle.m_title = title;
				activeTitle.m_level = lvl;
				activeTitle.m_uniqueKey = characters[c];
				m_heroTitles.insertLast(activeTitle);
			}
		}
		
		if (m_ngp < 0)
			m_ngp = bestNgp;
		
		Hooks::Call("TownRecordRefreshHeroTitles", @this);
	}
	
	void RefreshDonationTitles()
	{
		%PROFILE_SCOPE RefreshDonationTitles
		
		m_donationTitles.removeRange(0, m_donationTitles.length());
		
		AddDonationTitle(HeroTitle::Get("title_mat_gold"), "gold", 3000);
		AddDonationTitle(HeroTitle::Get("title_mat_wood"), "wood", 10);
		AddDonationTitle(HeroTitle::Get("title_mat_stone"), "stone", 5);
		AddDonationTitle(HeroTitle::Get("title_mat_iron"), "iron", 2.5);
		
		Hooks::Call("TownRecordRefreshDonationTitles", @this);
	}
	
	void AddDonationTitle(HeroTitle@ title, const string &in mat, double divisor)
	{
		auto value = g_myTownRecord.statsTown.GetStatCurr(HashString("chapel-revive-" + mat));
		auto level = int(pow(value / divisor, 0.5f) + 0.5f);
		if (level <= 0)
			return;
		
		ActiveHeroTitle activeTitle;
		@activeTitle.m_title = title;
		activeTitle.m_level = level;
		activeTitle.m_uniqueKey = 0;
		m_donationTitles.insertLast(activeTitle);
	}
	
	void RefreshStatAccomplishmentsTitles()
	{
		%PROFILE_SCOPE RefreshStatAccomplishmentsTitles
		
		Stats::StatAccomplishmentReward rewardSum;
		
		for (uint i = 0; i < Stats::StatDef::Instances.length(); i++)
		{
			auto currVal = statsTown.GetStatCurr(Stats::StatDef::Instances[i].m_idHash);
			auto@ rewards = Stats::StatDef::Instances[i].m_rewards;
			for (uint j = 0; j < rewards.length(); j++)
			{
				if (rewards[j].m_value > currVal)
					break;
				
				rewards[j].AddRewardSum(rewardSum);
				
				if (!rewards[j].m_rAchievement.isEmpty() && this is g_myTownRecord && Network::IsServer())
				{
					Platform::Service.UnlockAchievement(rewards[j].m_rAchievement);
				}
			}
		}
		
		@m_accomplishmentRewards = rewardSum;
	}

}
