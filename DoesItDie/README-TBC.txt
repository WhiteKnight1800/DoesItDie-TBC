DoesItDie - TBC Anniversary & Classic Era port
==============================================

Ported by WhiteKnight / Smuggz_.

A port of "Does It Die" (by JoeGG, MIT licence, github.com/swirllyman/DoesItDie, v0.8.2) from WoW Forever to
the TBC Classic Anniversary client (interface 20505 / 20506 / 20507) and the Classic Era client (Classic Era,
Hardcore; interface 11507 / 11508 / 11509). One download works on both.

INSTALL
  Put the DoesItDie folder in:  World of Warcraft\_anniversary_\Interface\AddOns\  (TBC Anniversary)
                            or:  World of Warcraft\_classic_era_\Interface\AddOns\  (Classic Era)
  then restart the game fully. Type /did for options.
  If the addon shows as "out of date", tick "Load out of date AddOns" on the character screen.

WHAT CHANGED FROM THE FOREVER VERSION
  * Uses the combat log. Forever forbids addons from reading it, so the original guesses which hit was which
    DoT tick from damage school, size and timing. TBC allows it, so this version reads every tick, miss,
    debuff application and removal of YOUR spells exactly, by name, on every mob - including mobs you have
    tabbed away from and mobs without a nameplate. Death, dispels and early removal clear the marker at once.
  * DoT timing starts when the debuff actually lands (Serpent Sting, Fireball and Pyroblast travel time).
  * Spell power / attack power: learned tick sizes remember the power they were learned at, and the next cast
    rescales the bonus part to your power when you cast (trinket procs, flasks, new gear).
  * Combo points are read directly (Rip, Rupture), since TBC doesn't hide them.
  * TBC spells: Unstable Affliction (Shadow), Pounce (ticks as "Pounce Bleed"), Immolation Trap ("Immolation
    Trap Effect"), Curse of Agony's back-loaded ticks (ramp on the base
    damage, spell power spread evenly), Vampiric Touch, Siphon Life, Holy Fire, Rupture, etc.
  * Plater: the marker goes on Plater's own health bar, including with its "use UIParent" option.
  * Nameplates: any other nameplate addon's health bar is found by matching the mob's health (readable on TBC),
    so the marker shows on the plate itself, not just a skull beside it.
  * Channels: Drain Life, Drain Soul and Mind Flay count toward the marker while you channel them (ticks left
    before the channel ends, pushback included). /did channels turns this off.
  * Health text stays readable: the target frame marker is drawn over the bar's colour, and a copy of the health
    numbers inside the bar is drawn on top of it (works with Blizzard's frame, BetterBlizzFrames and others, in
    combat too). /did text (or Advanced > Health text above marker) turns this off; /did textcheck lists the text
    it found over the bar.
  * PvP: the TBC client only reports enemy players' health as a percentage, so their real health is measured from
    the damage and healing they take (combat log, all sources) against how far their percentage moves. Until it's
    known, nothing is drawn on that player instead of a full bar; the size is then remembered per player name.
    Ticks on players are learned separately, so PvP (resilience) never drags down your PvE estimates.
    Players kept topped up (healers, Ice Barrier, Mana Shield) are measured hit by hit instead.
    /did pvp (or Advanced > Show on enemy players) turns the marker and kill icon off on players.
  * Classic Era: the same build loads there. Spells that don't exist in vanilla (Unstable Affliction, Seed of
    Corruption, Vampiric Touch, Lacerate) simply never show up; vanilla tooltip wording ("every second") is read.
    Vanilla has no focus frame, so the focus marker only appears if a unit frame addon provides one.
  * Shields: while the target has a shield or immunity up (Power Word: Shield, Ice Barrier, Mana Shield, Sacrifice,
    the mage and warlock Wards, Divine Shield, Ice Block, Blessing of Protection) the kill icon is hidden, since
    the shield soaks damage first. The marker still shows.
  * Options page falls back to the classic Interface Options if the newer Settings panel isn't there.
  Everything else (marker, kill icon, nameplates, focus frame, looks, /did window) is the original's.

WARLOCK DOTS TRACKED
  Corruption, Immolate, Curse of Agony, Unstable Affliction, Siphon Life, Seed of Corruption (its DoT part).
  Plus Drain Life and Drain Soul while channelling.
  Not tracked: Curse of Doom (one hit after 60s, not a DoT).

FIRST CAST OF EACH RANK
  Tooltips leave out your +spell damage, so the very first estimate for a spell rank is low (safe: no false
  skull). After its first tick the addon knows your real tick size and remembers it between sessions.
  Before a cast's first tick, the estimate is cautious: the lowest of your last 5 casts of that spell rank,
  scaled to your spell power now. What's on or about the mob (partial resists, Curse of Shadow, Shadow
  Vulnerability, Shadow Weaving) can change ticks by 10-25%, and can't be known until a tick lands, so a lucky
  earlier cast never gives a false kill icon. From the first tick, that DoT's own real ticks take over.
  /did accuracy shows, for your last DoTs, what was predicted when each landed vs what it really dealt. Partial resists are shown too.
  /did reset forgets learned sizes (do this after a big gear upgrade if estimates look off until it relearns).

LIMITS (same as the original)
  Only your own DoTs; no healing on the target; proc DoTs (Deep Wounds, Ignite, poisons) aren't tracked.
  If something looks wrong, /did accuracy and /did debug show what the addon predicted and saw.
