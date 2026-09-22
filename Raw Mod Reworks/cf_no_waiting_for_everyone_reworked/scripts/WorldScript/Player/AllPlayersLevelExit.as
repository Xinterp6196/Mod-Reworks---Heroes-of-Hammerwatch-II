namespace WorldScript
{
	[WorldScript color="200 255 100" icon="system/icons.png;480;256;32;32"]
	class AllPlayersLevelExit : IUsable
	{
		UnitPtr Unit;

		[Editable default="levels/.lvl"]
		string Level;
		
		[Editable]
		string StartID;
		
		[Editable]
		float TimeTravelHours;
		
		[Editable]
		array<CollisionArea@>@ Areas;
		
		[Editable default=".exit.notall"]
		string TooFewPlayersMsg;


		void Initialize()
		{
			for (uint i = 0; i < Areas.length(); i++)
			{
				Areas[i].AddOnEnter(this, "OnEnter");
				Areas[i].AddOnExit(this, "OnExit");
			}
		}

		void Cleanup()
		{
			auto localPlayer = GetLocalPlayer();
			if (localPlayer !is null)
				localPlayer.RemoveUsable(this);
			
			if (Areas !is null)
			{
				for (uint i = 0; i < Areas.length(); i++)
					Areas[i].ClearFuncs(this);
			}
		}

		Player@ GetPlayer(UnitPtr unit)
		{
			if (!unit.IsValid())
				return null;

			ref@ behavior = unit.GetScriptBehavior();

			if (behavior is null)
				return null;

			return cast<Player>(behavior);
		}

		void OnEnter(UnitPtr unit, vec2 pos, vec2 normal)
		{
			Player@ plr = GetPlayer(unit);
			if (plr !is null)
				plr.AddUsable(this);
		}

		void OnExit(UnitPtr unit)
		{
			Player@ plr = GetPlayer(unit);
			if (plr !is null)
				plr.RemoveUsable(this);
		}

		SValue@ ServerExecute()
		{
			return null;
		}

		UnitPtr GetUseUnit()
		{
			return Unit;
		}

		bool CanUse(PlayerBase@ player)
		{
			auto ws = WorldScript::GetWorldScript(Unit);
			if (!ws.IsEnabled())
				return false;
			if (!ws.CanExecuteNow())
				return false;
			return true;
		}

		void Use(PlayerBase@ player)
		{
			WorldScript::GetWorldScript(Unit).Execute();
			Lobby::SetJoinable(false);
			g_worldTimeLevelChangeDelay = TimeTravelHours;
			g_startId = StartID;
   			ChangeLevel(Level);
			
		}

		void NetUse(PlayerHusk@ player)
		{
			Use(player);
		}

		ITooltip@ GetTooltip() { return null; }
		UsableIcon GetIcon(Player@ player)
		{
			if (!CanUse(player))
				return UsableIcon::None;
			return UsableIcon::Exit;
		}

		int UsePriority() { return -1; }
		
		bool IsInside(UnitPtr unit)
		{
			for (uint i = 0; i < Areas.length(); i++)
				if (Areas[i].IsInside(unit))
					return true;
			return false;
		}

	}
}