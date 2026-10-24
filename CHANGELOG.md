# Changelog (TBC port)

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
