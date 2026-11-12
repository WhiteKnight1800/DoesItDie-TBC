# Changelog (Does It Die Advanced)

## v1.3.1
- Enemy Frames: **fixed the marker missing from dotted mobs.** Enemy Frames reuses its rows as mobs come and go, and the addon kept drawing on the row a mob had when it was first seen, which could later be hidden or showing another mob. It now follows each mob to whichever row it's in.
- `/dida efcheck` lists the rows on screen (the ones with the marker first).

## v1.3.0
- **Update notice:** if someone in your guild or group has a newer version, you're told once in chat that yours is out of date. Works between copies from 1.3.0 on. `/dida updates` turns it off.

## v1.2.9
- **Nameplate health text stays readable:** the health numbers on nameplates (e.g. Plater's "2.4K (72.7%)") are now drawn on top of the stripes, like on the target frame. Turned off together with **Advanced → Health text above marker**.

## v1.2.8
- **Pick the color of each DoT:** `/dida` → Marker → **Color of each DoT → Pick**. All your class's DoTs are listed (Drain Life, Bane of Agony and so on, even before you've cast them); click a color to change it, **Default** to undo. Your colors are used on the target frame, nameplates and focus, and are kept.
- Red is no longer used for DoT colors: enemy health bars are red, so a red DoT disappeared into the bar.

## v1.2.7
- Forever: health text of unit frame addons like EllesmereUI ("603 | 87.3%") is drawn above the marker. The game hides where that text sits, so the addon couldn't tell it was over the health bar; any text that's part of your target frame is now copied above the marker.
- `/dida textcheck` now lists every text in your target frame, whether the game hides its position, and parts of the frame the game locks.

## v1.2.6
- **No two DoTs share a color any more, and common DoTs always get the same one:** Corruption purple, Agony green, Immolate orange, Siphon Life teal, Unstable Affliction blue (and set colors for the other classes' DoTs). Other spells take a color no DoT is using.
- Nameplates and the focus frame now give each DoT its own color too. They used to color by spell school, where Corruption and Agony are both purple. (Changed once for everyone; "By spell school" is still in the options.)

## v1.2.5
- Forever: learning tick sizes from the damage meter is no longer skipped after a DoT that missed (e.g. when your pet's melee missed at the same moment and the DoT was recast).
- Forever: other unit frame addons' health text (EllesmereUI and others) is drawn above the marker again by default. 1.2.0 turned it off there, but it's been confirmed working. Turn it off in **Advanced → Other addons' health text too**.

## v1.2.4
- **Curse of the Elements and Curse of Shadow put on after your DoTs now raise their remaining damage.** The % and schools are read from the curse's own tooltip, so every rank is right (on Forever: 4%, 6%, 8% or 10% on all Magic damage). On Forever, where the game hides debuffs on mobs, your own curse cast counts; casting another curse on the mob replaces it.
- Forever: **fixed the skull showing on mobs that didn't die.** Tick sizes learned from the damage meter could come out too big:
  - a tick the addon didn't spot was still in the meter's total (Corruption learned 132 when it ticks for 112). Every tick that was due is now counted.
  - DoT ticks can crit on Forever, and crits were counted in (Immolate learned 56 when it normally ticks for about 50). Crits are now taken out, so the skull only shows when your normal ticks will kill.
  - Bane of Agony learned far too high from fights that ended early (small early ticks only). Its ramp and your spell power are now learned separately.
  - Tick sizes learned by v1.2.0 are forgotten once on Forever, so they're relearned correctly.
- Enemy Frames: the marker shows while a mob is casting or crowd controlled (Fear and so on). Before, the cast bar covered it, so you couldn't see whether the mob was dotted.
- New `/dida efcheck`: lists what's in an Enemy Frames row, for bug reports if the marker is ever hidden there.

## v1.2.0
- **Restart the game fully after updating** (new files were added).
- Forever: **learns your real tick sizes from the damage meter.** Forever hides each tick's damage, but after a fight the addon reads the game's damage meter and works out what each DoT really ticked for, so the next cast's marker matches your real damage (spell power, talents and buffs included).
- **Russian, Chinese and Portuguese** spell tooltips are read, from JoeGG's Does It Die (Russian translated by donesvad).
- Action targeting: when the last kill's corpse is still your target, a DoT cast on the next mob goes on that mob, not the corpse.
- Forever: other unit frame addons' health text is no longer copied above the marker by default (Blizzard's own always is). Turn it on in **Advanced → Other addons' health text too**. TBC and Classic are unchanged.

## v1.1.5
- Forever: fixed errors on feral bleeds (Rake, Rip). Forever hides attack power in combat, and it was being added up.
- Forever: `/dida accuracy` explains that it isn't available there, instead of saying no DoTs finished.
- Forever: bleeds (Rake, Rip, Rend, Garrote, Rupture) keep the timing from when they were cast, so melee hits landing near a tick can't pull them early.

## v1.1.4
- Forever: **Rip** is read (its tooltip leaves out the word "damage").

## v1.1.3
- `/dida debug` says why a cast isn't tracked when its name or tooltip is hidden by the game, or it had no target, for bug reports.

## v1.1.2
- EllesmereUI (Forever): the health text is drawn above the marker again. A locked frame inside EllesmereUI's target frame stopped the layering check, so nothing was copied.

## v1.1.1
- Enemy Frames: the marker sits under the mob's name, so the name stays readable.

## v1.1.0
- **Enemy Frames support** (Krelock's enemy list, Forever): the marker and kill icon show on every enemy's bar in its list, so you can see which mobs in the pack your DoTs will finish. `/dida enemyframes` turns it off.

## v1.0.4
- Forever: **Immolation Trap** is tracked. It springs on the first Fire tick on whoever walks into it, even though Forever hides the tick's amount.

## v1.0.3
- Forever: the health percentage no longer drops under the marker at times. When the game hid the health bar's position (in combat, on some mobs), the health text wasn't copied above the marker at all; Blizzard's own health text is now always copied.
- The options header reads "by WhiteKnight / Smuggz_".

## v1.0.2
- `/dida textcheck` works on Forever (it errored where a frame's position or visibility is hidden) and opens a copyable report, including Blizzard's health text and the layers the marker and the text copies use.

## v1.0.1
- Forever: the target marker covers the whole health bar again by default. v1.0.0 started it fitted to one player's frame (height 10, offset -4, left edge 5), which put it below the bar on Blizzard's default UI. The Marker tab's height, offset and edge settings are reset once for everyone; set them again if your frame needs a fit.

## v1.0.0: Does It Die Advanced
- **New name: Does It Die Advanced.** The addon's folder is now `DoesItDieAdvanced`: delete the old `DoesItDie` folder when updating. Settings start fresh.
- **WoW: Forever support.** One download for Classic Era, Hardcore, TBC Anniversary and Forever. On Forever, ticks are matched by school and timing (Forever hides their amounts), and the combat log is never touched (it's blocked there).
- **Installs alongside JoeGG's original** without clashing: its own folder, saved settings and window names. The command is `/dida`; `/did` also works when the original isn't installed.
- New Marker tab options: **Marker height**, **vertical offset**, and **left / right edge**, to fit the marker to any target frame style.
- The marker never goes above the target frame's own layers (a menu parented into it lifted it over the whole interface on Forever).
- Blizzard's own health text is found by name, so it stays above the marker even where its position can't be read (Forever).


## v0.8.2-22
- New option Nameplates > **Marker height**: 0 (default) is automatic: the nameplate's whole bar, or 8 pixels on NeatPlates, whose frame is much taller than the bar drawn in it. Any other value sets the marker's height, centred.
- **NeatPlates (Community Edition) fixed:** its health bar is its own widget rather than a standard WoW bar, so it was skipped and only a small skull showed beside the plate. The marker now sits on NeatPlates' bar.
- **Nameplate addons that keep their frame outside the nameplate** (NeatPlates Community Edition and others) are found by following the frames the nameplate links to and picking the bar that shows the mob's health. Before, only the small kill icon showed beside the plate.
- `/did plates` shows its results in a window you can copy from, so they can be pasted in a bug report.

## v0.8.2-21
- **NeatPlates / Tidy Plates:** the marker and kill icon go on their own health bar (plate.extended.bars.healthbar), which the automatic search couldn't reach.

## v0.8.2-20
- **Starshards** (night elf priest) is tracked on TBC, where it's an instant DoT. It's still ignored on Classic Era, where it's a channel.

## v0.8.2-19
- **Fixed non-English clients:** since v0.8.2-17, DoTs whose tooltip has brackets (German "Punkt(e)", as on Corruption and Curse of Agony) weren't read. Brackets are now only dropped for English tooltips.
- Tests for German, French, Spanish and Korean tooltips.

## v0.8.2-18
- **Performance:** fixed a short stutter every minute or so. Finding unit frame addons' health text searched every frame in the interface at once; it now searches a little at a time, and only repeats every 5 minutes.
- Nameplates an addon draws in a way that can't be read are searched less often.
- Refreshed `/did` window: violet theme to match the logo, the logo and version in the header, and a credit for the Classic & TBC port.
- The preview shows a Voidwalker instead of a boar.

## v0.8.2-17
- **Shields:** the kill icon is hidden while the target has a shield or immunity up (Power Word: Shield, Ice Barrier, Mana Shield, Sacrifice, the Wards, Divine Shield, Ice Block, Blessing of Protection), since it soaks your damage first. The marker still shows.
- **PvP:** enemy players who keep getting healed back up (healers, a mage's Ice Barrier or Mana Shield) are now measured hit by hit, so their marker shows instead of staying hidden.
- Health drained from enemy players by spells counts toward measuring their health.
- Nameplates: the marker stays on top when Plater raises a plate (when it becomes your target, for example). Before, it could end up underneath Plater's bar.
- A DoT cast before the game has loaded its tooltip (seen on a fresh character) is no longer skipped: it waits a moment for the tooltip, then shows.
- Rend on TBC is tracked again: its tooltip adds weapon damage ("28 damage plus an additional 1 (based on weapon damage) over 12 sec"), which wasn't read.
- `/did debug` shows a spell's tooltip when it isn't read as a DoT, so missed DoTs are easy to report.

## v0.8.2-tbc16
- More accurate first estimate: one odd cast (heavy partial resists, a tanky mob) can no longer halve the prediction for your next casts. The cautious estimate before a DoT's first tick now stays within 80% of your latest cast.
- Partly resisted ticks are learned at their full size, so a run of resists isn't mistaken for the spell's real damage.
- `/did accuracy` reads clearly when the prediction was low ("50% too low" instead of "-100% too low").
- Threat Plates: tested and listed as supported.

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
