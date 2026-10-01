<unit netsync="position" save="false">
	<behavior class="PlayerOwnedActor">
		<string name="team">player</string>
		<int name="hp">100000</int>
		<string name="ttl-bind">totem-ttl</string>
		<int name="aggro-range">200</int>
		<int name="max-range">1000</int>
		<bool name="must-see-target">true</bool>
		<bool name="targetable">false</bool>
		<bool name="targetable-friendly">true</bool>
		<bool name="collide-with-team">false</bool>
		<bool name="hide-health">true</bool>
		<int name="teleport-leash">0</int>
		<array name="tags"><string>summon</string></array>
		<dict name="movement"><string name="class">PassiveMovement</string><string name="anim-idle">idle</string></dict>
		<array name="skills">
			<dict>
				<string name="class">CompositeActorUtilitySkill</string>
				<int name="cooldown">500</int>
				<int name="range">2000</int>
				<int name="castpoint">0</int>
				<bool name="must-see">false</bool>
				<bool name="is-attack">false</bool>
				<bool name="is-spell">false</bool>
				<array name="actions">
					<dict><string name="class">PlaySound</string><string name="sound">event:/sfx/player/classes/warrior/ancient_totems/ancient_totems_attack</string></dict>
					<dict>
						<string name="class">Explode</string>
						<string name="fx">players/warrior/effects/totem_quake.effect?radius=53</string>
						<int name="radius">53</int>
						<int name="min-radius">8</int>
						<float name="dist-scaling">1000</float>
						<array name="effects">
							<dict><float name="intensity-mul">1</float></dict>
							<dict>
								<string name="class">StatBasedDamage</string>
								<string name="type">physical</string>
								<string name="stat">thorns</string>
								<string name="amount-bind">totem-thorns-mul</string>
							</dict>
							<dict>
								<string name="class">StatBasedDamage</string>
								<string name="type">physical</string>
								<string name="stat">thorns</string>
								<string name="amount-bind">totem-bonus-thorns-mul</string>
							</dict>
							<dict>
								<string name="class">AddStacks</string>
								<string name="buff">tweak/buffs/stacks_bulwark.sval:bulwark_bleeding</string>
								<string name="stacks-bind">totem-bleed-stacks</string>
								<float name="chance">1</float>
							</dict>
						</array>
					</dict>
				</array>
			</dict>
			<dict>
				<string name="class">CompositeActorTriggeredSkill</string>
				<string name="trigger">OnDeath</string>
				<int name="cooldown">0</int>
				<int name="range">2000</int>
				<array name="actions">
					<dict><string name="class">PlaySound</string><string name="sound">event:/sfx/player/classes/warrior/ancient_totems/ancient_totems_attack</string></dict>
					<dict><string name="class">SpawnEffect</string><string name="effect">players/warrior/units/totem_tower_death.effect?ice=0</string></dict>
					<dict>
						<string name="class">Explode</string>
						<string name="fx">players/warrior/effects/totem_quake.effect?radius=150</string>
						<int name="radius">150</int>
						<int name="min-radius">8</int>
						<float name="dist-scaling">1000</float>
						<array name="effects">
							<dict>
								<string name="class">StatBasedDamage</string>
								<string name="type">physical</string>
								<string name="stat">thorns</string>
								<string name="amount-bind">totem-death-thorns-mul</string>
							</dict>
						</array>
					</dict>
				</array>
			</dict>
		</array>
	</behavior>
	<scenes>
		<scene name="idle">
			<collision static="true"><circle radius="1" sensor="true" aim-through="true" shoot-through="true" charge-through="true" /></collision>
			<scene src="special/minimap.unit:npc_normal"/>
			<effect src="players/warrior/units/totem_tower.effect?ice=0"/>
		</scene>
	</scenes>
</unit>
