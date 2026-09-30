// Local, boon-only equivalents of MissionBuff::GetMissionBuffs / IsValidMissionBuff.
// Deliberately NOT using the shared MissionBuff.as functions, since those also
// drive the vanilla buff loadout (SelectBuffLoadout) and we don't want to change
// that behavior. A boon is selectable if either:
//   - the character currently meets its normal conditionals (e.g. stat > 0), OR
//   - it has already been unlocked account-wide (g_myTownRecord.m_unlockedBoons)
array<MissionBuff@>@ GetAvailableBoons(PlayerRecord@ plr, uint32 setHash)
{
	auto@ blueprints = g_myTownRecord.m_blueprints;
	array<MissionBuff@> ret;
	for (uint i = 0; i < MissionBuff::Instances.length(); i++)
	{
		auto@ buff = MissionBuff::Instances[i];
		if (buff.m_setHash != setHash)
			continue;
		if (buff.m_blueprintHash != 0 && !blueprints.HasBlueprint(buff.m_blueprintHash))
			continue;

		bool unlocked = g_myTownRecord.HasUnlockedBoon(buff.m_idHash);
		if (!unlocked && !CheckConditionals(buff.m_conditionals, plr))
			continue;

		ret.insertLast(buff);
	}
	return ret;
}

bool IsAvailableBoon(PlayerRecord@ plr, uint32 setHash, MissionBuff@ buff)
{
	if (buff is null)
		return false;

	auto@ blueprints = g_myTownRecord.m_blueprints;
	if (buff.m_setHash != setHash)
		return false;
	if (buff.m_blueprintHash != 0 && !blueprints.HasBlueprint(buff.m_blueprintHash))
		return false;

	if (g_myTownRecord.HasUnlockedBoon(buff.m_idHash))
		return true;

	return CheckConditionals(buff.m_conditionals, plr);
}

class SelectBoonLoadout : MissionGUILoadout
{
	PlayerRecord@ m_player;
	TextWidget@ m_currentBoon;
	uint32 m_boonSet;

	MissionBuff@ m_boon;
	
	SelectBoonLoadout(SValue& params)
	{
		super(params);
		
		m_boonSet = HashString(GetParamString(UnitPtr(), params, "buff-set", true));
	}
	
	bool BuildGUI(PlayerRecord@ plr, MissionLoadoutMenu@ menu, Widget@ segment, int yNavPos) override
	{
		if (!MissionGUILoadout::BuildGUI(plr, menu, segment, yNavPos))
			return false;
		
		@m_player = plr;
		auto boonTemplate = segment.GetWidgetById("template-buff");
		auto container = segment.GetWidgetById("container");

		auto group = cast<AInteractableWidget>(segment.GetWidgetById("rect").Clone());
		group.m_visible = true;
		group.m_func = m_id + " open";
		group.m_navPos = ivec2(0, yNavPos);
		
		int width = 0;
		auto boons = GetAvailableBoons(plr, m_boonSet);
		for (uint i = 0; i < boons.length(); i++)
		{
			if (m_player.HasMissionBuff(m_idHash, boons[i]))
			{
				@m_boon = boons[i];
				break;
			}
		}

		auto boonW = boonTemplate.Clone();
		boonW.m_visible = m_boon !is null;

		@m_currentBoon = cast<TextWidget>(boonW.GetWidgetById("text"));
		m_currentBoon.SetText((m_boon !is null ? m_boon.m_name : ""));

		group.AddChild(boonW);
		
		container.AddChild(group);
		
		if (boons.length() <= 0)
			return false;
		
		return true;
	}

	void UpdateBoon(MissionBuff@ boon)
	{
		@m_boon = boon;

		if (boon is null)
		{
			m_currentBoon.SetText("");
			m_currentBoon.m_parent.m_visible = false;
			return;
		}

		m_currentBoon.m_parent.m_visible = true;
		m_currentBoon.SetText(boon.m_name);
	}

	void OnPlay() override
	{
		if (m_boon !is null)
			m_player.SetMissionBuff(m_idHash, m_boon);
	}

	void OnFunc(Widget@ sender, const string &in name) override
	{
		auto parse = name.split(" ");
		if (parse[1] == "open")
		{
			cast<BaseGameMode>(g_gameMode).m_windowManager.AddWindowObject(
				MissionBoonSelector(this));
		}
	}

	void Save(SValueBuilder& builder) override 
	{
		if (m_boon is null)
			return;
		builder.PushString(m_id, m_boon.m_id);
	}
	
	void Load(PlayerRecord@ plr, SValue@ save) override 
	{
		@m_boon = MissionBuff::Get(GetParamString(UnitPtr(), save, m_id, false));
		
		if (!IsAvailableBoon(m_player, m_boonSet, m_boon))
			@m_boon = null;
	}
}

class MissionBoonSelector : AWindowObject
{
	SelectBoonLoadout@ m_host;
	MissionBuff@ m_selected;

	ITooltip@ m_selectedTooltip;
	Widget@ m_compareAnchor;

	bool m_changed;

	MissionBoonSelector(SelectBoonLoadout@ host)
	{
		super(g_gameMode.m_guiBuilder, "gui/mission_loadout/boon_picker.gui");

		@m_host = host;

		@m_compareAnchor = m_widget.GetWidgetById("compare-anchor");
		cast<TextWidget>(m_widget.GetWidgetById("title")).SetText(Resources::GetString(m_host.m_name));

		auto boons = GetAvailableBoons(m_host.m_player, m_host.m_boonSet);
		auto template = m_widget.GetWidgetById("template");
		auto list = m_widget.GetWidgetById("scroll");

		for (uint i = 0; i < boons.length(); i++)
		{
			auto templateW = cast<AInteractableWidget>(template.Clone());
			auto textW = cast<TextWidget>(templateW.GetWidgetById("text"));
			textW.SetText(boons[i].m_name);
			
			if (m_host.m_boon is boons[i])
			{
				templateW.GetWidgetById("selected").m_visible = true;
				@m_selected = boons[i];

				@m_selectedTooltip = CreateTitledTooltip(
					Resources::GetSValue("gui/variable/itemtooltip_common.sval"), 
					boons[i].m_name, 
					GetBoonDetails(boons[i]),
					null,
					null
				);
			}

			templateW.m_visible = true;
			templateW.SetID(boons[i].m_id);
			templateW.m_navPos = ivec2(0, i);

			list.AddChild(templateW);
		}

		@m_input.m_menuAdditionalOnPressed = WindowInput::OnFunc(this.Apply);
	}

	void Draw(SpriteBatch& sb, int idt) override
	{
		AWindowObject::Draw(sb, idt);

		if (m_selectedTooltip !is null)
		{
			vec2 ttPos = m_compareAnchor.m_origin;
			m_selectedTooltip.Draw(sb, ttPos);
		}
	}

	void RefreshKeybinds(ControlMap@ currMap) override
	{
		if (m_navigationBar is null)
			return;

		auto currInteractable = m_input.GetCurrentInteractable();
		if (currInteractable is null)
			return;

		array<string>@ rawTexts = currInteractable.NavigationBarText();
		array<KeyNavigationText@> navTexts;
		for (uint i = 0; i < rawTexts.length(); i++)
			navTexts.insertLast(KeyNavigationText(m_navigationBar.m_font.BuildText(rawTexts[i])));

		navTexts.insertLast(KeyNavigationText(m_navigationBar.m_font.BuildText(FormatKeyName(GetActionBinding("MenuAdditional")) + " " + Resources::GetString(".menu.nav.apply")), WindowInput::OnFunc(this.Apply)));

		m_navigationBar.BuildBar(navTexts, this);
	}

	void OnInteractableIndexChanged() override
	{
		auto currInteractable = m_input.GetCurrentInteractable();
		if (currInteractable is null)
			return;

		array<string>@ rawTexts = currInteractable.NavigationBarText();
		array<KeyNavigationText@> navTexts;
		for (uint i = 0; i < rawTexts.length(); i++)
			navTexts.insertLast(KeyNavigationText(m_navigationBar.m_font.BuildText(rawTexts[i])));

		navTexts.insertLast(KeyNavigationText(m_navigationBar.m_font.BuildText(FormatKeyName(GetActionBinding("MenuAdditional")) + " " + Resources::GetString(".menu.nav.apply")), WindowInput::OnFunc(this.Apply)));

		m_navigationBar.BuildBar(navTexts, this);
	}

	void Apply()
	{
		if (m_selected !is null)
			g_myTownRecord.UnlockBoon(m_selected.m_idHash);

		m_host.UpdateBoon(m_selected);

		m_manager.CloseTooltip();

		m_changed = false;
		m_closing = true;
	}

	bool Back() override
	{
		if (m_changed)
		{
			//g_gameMode.ShowDialog("exit", Resources::GetString(".option.prompt.settings_appy"), Resources::GetString(".menu.nav.save"), Resources::GetString(".menu.nav.revert"), this);
			Apply();
			return false;
		}

		return true;
	}

	void OnFunc(Widget@ sender, const string &in name) override
	{
		if (name == "hover")
		{
			auto boon = MissionBuff::Get(sender.m_id);
			if (boon !is null)
			{
				m_manager.SetTooltip(
					CreateTitledTooltip(Resources::GetSValue("gui/variable/itemtooltip_common.sval"), 
						boon.m_name, 
						GetBoonDetails(boon),
						null,
						null)
				, true);
			}
		}
		else if (name == "select")
		{
		 	auto boon = MissionBuff::Get(sender.m_id);
			if (m_selected is boon)
			{
				@boon = null;
				@sender = null;
			}

			@m_selected = boon;

		 	if (boon !is null)
		 	{
				@m_selectedTooltip = CreateTitledTooltip(
					Resources::GetSValue("gui/variable/itemtooltip_common.sval"), 
					boon.m_name, 
					GetBoonDetails(boon),
					null,
					null
				);
			}

			m_changed = true;

			auto list = m_widget.GetWidgetById("scroll");
			for (uint i = 0; i < list.m_children.length(); i++)
			{
				auto child = list.m_children[i];
				child.GetWidgetById("selected").m_visible = sender is child;
			}
		}
		else if (name == "exit yes")
			Apply();
		else if (name == "exit no")
			m_closing = true;
	}
}

	
string GetBoonDetails(MissionBuff@ boon)
{
	auto record = GetLocalPlayerRecord();
	auto skillDef = boon.skill;
	StringBuilder desc;
	desc.Append(Resources::GetString(boon.m_description));
	desc.Append("\n");
	AppendSkillDesc(record, desc, skillDef);

	auto result = desc.String();

	return result;
}