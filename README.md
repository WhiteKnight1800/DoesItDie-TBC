# Does It Die (TBC)

A World of Warcraft **TBC Classic Anniversary** addon that tracks your DoTs and shows, on your target frame and nameplates, how much damage they still have to deal, with a kill icon when that's enough to finish the mob off.

Ported to TBC by **WhiteKnight / Smuggz_** from **[Does It Die](https://github.com/swirllyman/DoesItDie)** by **JoeGG**, originally made for WoW: Forever and released under the MIT licence (see [LICENSE](LICENSE)). The marker, kill icon, options window and overall design are his work.

## What the TBC version adds

- **Exact tracking from the combat log:** every tick, miss, resist, dispel and death is read by spell name, on every mob, including ones you've tabbed away from.
- **Channels count:** Drain Life, Drain Soul and Mind Flay add the ticks they still have to deal, pushback included (`/did channels`).
- **Spell power and attack power** are read at cast time, so trinket procs and flasks are reflected.
- **Curse of Agony** modelled correctly: the base damage ramps up, the spell power bonus is spread evenly.
- **Cautious first estimate** before a DoT's first tick (lowest of your last 5 casts), so no false kill icons.
- **Health numbers stay readable:** a copy of the target frame's health text is drawn on top of the marker. Works with Blizzard's frame, BetterBlizzFrames and other unit frame addons, in combat too (`/did text`, `/did textcheck`).
- **Plater support**, plus automatic detection of other nameplate addons' health bars.
- **Accuracy report:** `/did accuracy` shows predicted vs real damage for your last DoTs.

## Install

Copy the `DoesItDie` folder into `World of Warcraft\_anniversary_\Interface\AddOns\` and restart the game. Type `/did` for options.

Also on CurseForge as **Does It Die (TBC)**.

## Commands

| Command | What it does |
|---|---|
| `/did` | Options window with a live preview |
| `/did accuracy` | Predicted vs real damage for your last DoTs |
| `/did channels` | Turn channel prediction on or off |
| `/did text` | Health numbers above or below the marker |
| `/did textcheck` | List the text over the target's health bar (for bug reports) |
| `/did ticks` | What each DoT really ticks for vs its tooltip |
| `/did reset` | Forget learned tick sizes |
| `/did debug` | Echo the tracking log to chat |

## Tests

`tests/tbc_test.lua` loads every addon file in a fake WoW environment (based on the original project's test harness) set up like the TBC client, and plays scripted fights through the combat log: tick tracking, misses, channels, Agony's ramp, spell power scaling, Plater, and the health text copy. It needs a Lua 5.1 interpreter:

```
lua tests/tbc_test.lua DoesItDie tests
```

## Bugs and feedback

Open an issue with your class, the spell, which unit frame and nameplate addons you use, and the output of `/did debug` or `/did textcheck` if relevant.
