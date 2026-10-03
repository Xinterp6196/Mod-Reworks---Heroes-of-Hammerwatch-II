# Changelog

Notable changes to the Arbalest mod are recorded here. Entries remain under
`[Unreleased]` until they are included in a published release.

## [Unreleased]

### Added

#### 2026-10-02

- Added the Arbalest, a dexterity-focused ranged class that starts with a crossbow.
- Added Air Support, Tactician, and Captain subclass variants.
- Added Loaded for Bear, Arcane Quiver, Artillery, and Sustained Salvo as class skills.
- Added Payload and Napalm Expertise, Toxic Chaff and Gas Training, and Morale Booster and Footmen as subclass skills.
- Added mortar bombardment art and an expanded toxic-cloud radius for the requested abilities.
- Added the Arbalest title and class-level accomplishment rewards.
- Added the Arbalest title bonus: grants move speed at 0.25 per level.

### Changed

- Rebalanced and ranked the requested skill modifiers: Heavy Hitters, Thrill of the Hunt, Big Game Hunter, Expanded Volley, Ricochet, Stunning Missiles, Sustained Barrage, Execution Order, Hotter Charges, Volatile Ignition, Advanced Filtration, and Poison Payload.
- Renamed the Payload upgrades to Superheated Casing and Arc Casing, added Shrapnel Casing, set Superheated Casing's fire-zone duration to 4 seconds, and localized the added explosion and fire-area units.
- Added Encased Thermite's 4-second fire damage on Artillery impact and Irritant Particles' 33/66/100% blind chance to Toxic Chaff.
- Replaced inherited Ranger modifier labels on Sustained Salvo with In the Flow, Efficiency, and Momentum.
- Kept Footmen's pikeman unit and Echo status icon definition under Arbalest-specific resource paths to avoid Commander resource collisions and dependencies.
- Used the same base-game shared pikeman sprite sheets as Priest's Crusader Pikeman.
- Changed Payload and Toxic Chaff to use Loaded for Bear-style target selection; Toxic Chaff now throws its cloud to the selected location.
- Reworked Napalm Expertise into a modest fire-damage bonus with a chance to weaken enemies, and changed Gas Training to convert Dexterity into additional Spell Power.
- Replaced Footmen's mismatched pikeman visuals with the Priest Crusader Pikeman model and removed Priest-specific summon hooks.
- Matched Payload and Toxic Chaff projectile binds to the stock target-fired projectile skill pattern; made both projectiles scale their travel to the selected target and spawn their effects on landing.
- Doubled Payload and Toxic Chaff casting range from 180 to 360.
- Added three selectable modifier upgrades to every Arbalest class and subclass skill.
- Added Arbalest-local venom-star and incendiary-area units for Arcane Quiver and Artillery upgrades.
- Added the pixelated custom skill icons to the Arbalest atlas and assigned each icon to its skill and three modifier upgrades.
- Rebuilt Arcane Quiver on the Scroll of Magic Missile pattern: every fourth weapon skill cast launches a homing missile at a nearby enemy, while damage remains weapon-scaled and activation remains attack-based.
- Replaced Arcane Quiver's rocket upgrades with Magic Missile-style upgrades for extra missiles, jumps, and stun chance, and adopted the game's native Magic Missile visuals and impact effects.
- Increased Arcane Quiver's Expanded Volley and Ricochet upgrades to three ranks and set Stunning Missiles to 5/10/15% stun chance.
- Added all five Arcane Quiver skill ranks, scaling missile damage from 30% to 70% of Weapon Damage.
- Increased Artillery's rank progression to 12/14/16/18/20 strikes over 6/7/8/9/10 seconds.
