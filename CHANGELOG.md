# Changelog (TBC port)

## v0.8.2-tbc15
- **Classic Era support:** the same download now loads on Classic Era (and Hardcore) as well as TBC Anniversary.
- Vanilla tooltip wording is read ("every second", as on Drain Life).
- Tests for vanilla tooltips and a Classic Era fight.
- On an enemy player, chat says when the addon is measuring their health, so an empty bar doesn't look like a fault.
- The display keeps working if the game wasn't restarted after updating.

## v0.8.2-tbc14
- New option Advanced > **Show on enemy players**, and `/did pvp`, to turn the marker and kill icon off on players.

## v0.8.2-tbc13
- **PvP:** the marker no longer fills the whole bar on enemy players. The TBC client only reports their health as a percentage, so their real health is worked out from the damage and healing they take, then remembered per player name.
- Ticks on players are learned separately, so PvP (resilience) never changes your PvE estimates.

## v0.8.2-tbc12
- Health numbers on the target frame are drawn on top of the DoT marker (a copy of the text, so it works on Blizzard's protected frame in combat). Works with Blizzard's frame, BetterBlizzFrames and other unit frame addons.
- New option Advanced > Health text above marker, and `/did text`.
- New `/did textcheck` to list the text over the target's health bar.

## v0.8.2-tbc8
- Cautious estimate before a DoT's first tick: the lowest of your last 5 casts, scaled to your spell power now.
- Partial resists shown in `/did accuracy`.

## v0.8.2-tbc7
- Learned tick sizes remember the spell or attack power they were learned at and rescale to your power when you cast.

## v0.8.2-tbc6
- Curse of Agony: the ramp applies to the base damage only, spell power is spread evenly (was 11–29% too high).

## v0.8.2-tbc5
- `/did accuracy`: predicted vs real damage for your last DoTs.

## v0.8.2-tbc4
- Drain Life, Drain Soul and Mind Flay count toward the marker while channelling, pushback included (`/did channels`).

## v0.8.2-tbc2 – tbc3
- Plater support (including "use UIParent"), and automatic detection of other nameplate addons' health bars.

## v0.8.2-tbc1
- First TBC Classic Anniversary release, ported from Does It Die v0.8.2 by JoeGG: combat log tracking, TBC spells and tooltips, real combo points, DoT timing from when the debuff lands.

The original addon's changelog is in [CHANGELOG-original.md](CHANGELOG-original.md).
