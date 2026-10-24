-- TBC port test: loads every file in the .toc with the original project's fake WoW environment, adjusted to look
-- like a TBC Anniversary client (no C_Spell, no Settings panel, combat log available), then plays fights through
-- the combat log and checks what the marker would show.
-- Run: lua tbc_test.lua <addon dir> <test dir>
local ADDON, TESTDIR = arg[1], arg[2]
dofile(TESTDIR .. "/fake_wow.lua")
local H = dofile(TESTDIR .. "/helpers.lua")

-- TBC client differences ----------------------------------------------------------------------------------
C_Spell = nil
Settings = nil
local registeredPanel
function InterfaceOptions_AddCategory(panel) registeredPanel = panel end

-- TBC tooltips (max rank wording, base numbers).
local SPELLS = {
    [27216] = { "Corruption", "Corrupts the target, causing 900 Shadow damage over 18 sec." },
    [27215] = { "Immolate", "Burns the enemy for 332 Fire damage and then an additional 615 Fire damage over 15 sec." },
    [27218] = { "Curse of Agony", "Curses the target with agony, causing 1356 Shadow damage over 24 sec.  This damage is dealt slowly at first, and builds up as the Curse reaches its full duration.  Only one Curse per Warlock can be active on any one target." },
    [30405] = { "Unstable Affliction", "Shadow energy slowly destroys the target, causing 1050 damage over 18 sec.  In addition, if the Unstable Affliction is dispelled it will cause 1575 damage to the dispeller and silence them for 5 sec." },
    [30911] = { "Siphon Life", "Transfers 63 health from the target to the caster every 3 sec.  Lasts 30 sec." },
    [27238] = { "Drain Life", "Transfers 108 health every 1 sec from the target to the caster.  Lasts 5 sec." },
    [27209] = { "Shadow Bolt", "Sends a shadowy bolt at the enemy, causing 544 to 607 Shadow damage." },
    [27008] = { "Rip", "Finishing move that causes damage over time.  Damage increases per combo point and by your attack power:\r\n   1 point: 210 damage over 12 sec.\r\n   2 points: 384 damage over 12 sec.\r\n   3 points: 558 damage over 12 sec.\r\n   4 points: 732 damage over 12 sec.\r\n   5 points: 906 damage over 12 sec." },
    [27006] = { "Pounce", "Pounce, stunning the target for 3 sec and causing 1236 damage over 18 sec.  Must be prowling.  Awards 1 combo point." },
    [27023] = { "Immolation Trap", "Place a fire trap that will burn the first enemy to approach for 690 Fire damage over 15 sec.  Trap will exist for 1 min.  Only one trap can be active at a time." },
    [27016] = { "Serpent Sting", "Stings the target, causing 660 Nature damage over 15 sec.  Only one Sting per Hunter can be active on any one target." },
    [34917] = { "Vampiric Touch", "Causes 650 Shadow damage over 15 sec to your target and causes all party members to gain mana equal to 5% of any Shadow spell damage you deal." },
    [26993] = { "Rupture", "Finishing move that causes damage over time, increased by your attack power.  Lasts longer per combo point:\n   1 point: 324 damage over 8 secs\n   2 points: 456 damage over 10 secs\n   3 points: 606 damage over 12 secs\n   4 points: 774 damage over 14 secs\n   5 points: 960 damage over 16 secs" },
    [25311] = { "Drain Soul", "Drains the soul of the target, causing 620 Shadow damage over 15 sec.  If the target dies while being drained, and yields experience or honor, the caster gains a Soul Shard." },
    [25387] = { "Mind Flay", "Assault the target's mind with Shadow energy, causing 528 Shadow damage over 3 sec and slowing their movement speed by 50%." },
    [25469] = { "Holy Fire", "Consumes the enemy in holy flames that cause 412 to 523 Holy damage and an additional 165 Holy damage over 10 sec." },
}
function GetSpellInfo(id) return SPELLS[id] and SPELLS[id][1] or nil end
function GetSpellDescription(id) return SPELLS[id] and SPELLS[id][2] or "" end
function GetSpellTexture() return 136118 end

comboPoints = 0
function GetComboPoints() return comboPoints end

local PLAYER = "Player-1-0001"
local mobs = { A = "Creature-0-1-1-1-1-000A", B = "Creature-0-1-1-1-1-000B" }
targetGuid = mobs.A
function UnitGUID(unit)
    if unit == "player" then return PLAYER end
    if unit == "target" or unit == "nameplate1" then return targetGuid end
end
function UnitName(unit) if unit == "target" then return "Mob" end end

local currentEvent = {}
function CombatLogGetCurrentEventInfo() return unpack(currentEvent, 1, 21) end
local function log(sub, src, dest, spellID, extra)
    local name = SPELLS[spellID] and SPELLS[spellID][1] or spellID -- a string id means a tick/aura name
    local school = type(spellID) == "table" and spellID[2] or 32
    if type(spellID) == "table" then name = spellID[1] end
    currentEvent = { now, sub, false, src, "Me", 0, 0, dest, "Mob", 0, 0, 0, name, school }
    for i, v in ipairs(extra or {}) do currentEvent[14 + i] = v end
    H.fire("COMBAT_LOG_EVENT_UNFILTERED")
end

-- Test plumbing ---------------------------------------------------------------------------------------------
local failures, passes = 0, 0
local function check(label, actual, expected, tolerance)
    local ok
    if tolerance and type(actual) == "number" and type(expected) == "number" then
        ok = math.abs(actual - expected) <= tolerance
    else
        ok = actual == expected
    end
    if ok then passes = passes + 1 else failures = failures + 1 end
    print(string.format("%s  %-66s %s%s", ok and "PASS" or "FAIL", label, tostring(actual),
        ok and "" or ("   (expected " .. tostring(expected) .. ")")))
end
local function step(label, fn)
    local ok, err = pcall(fn)
    if ok then passes = passes + 1 else failures = failures + 1 end
    print((ok and "PASS  " or "FAIL  ") .. label .. (ok and "" or ("\n      " .. tostring(err))))
end

local ns = {}
local toc = io.open(ADDON .. "/DoesItDie.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if line:match("%.lua$") then
        step("load " .. line, function()
            local f = assert(io.open(ADDON .. "/" .. line))
            H.load(line, f:read("*a"), ns)
            f:close()
        end)
    end
end
step("ADDON_LOADED", function() H.fire("ADDON_LOADED", "DoesItDie") end)
local db = DoesItDieDB
local function logHas(text)
    for _, l in ipairs(db.log) do if l:find(text, 1, true) then return true end end
    return false
end
check("combat log in use", logHas("Combat log in use"), true)
check("options page registered without the Settings API", registeredPanel ~= nil, true)
step("/did opens the window", function() SlashCmdList.DOESITDIE("") end)
check("options window shown", DoesItDieOptions and DoesItDieOptions.shown, true)
step("close it", function() DoesItDieOptions:Hide() end)

local castCount = 0
local function cast(spellID)
    castCount = castCount + 1
    local guid = "Cast-" .. castCount
    H.fire("UNIT_SPELLCAST_SENT", "player", "Mob", guid, spellID)
    H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", guid, spellID)
end
local function remaining(unit)
    local list, total = ns.dotBreakdownForUnit(unit or "target")
    local byName = {}
    for _, e in ipairs(list) do byName[e.name] = math.floor(e.damage + 0.5) end
    return math.floor(total + 0.5), byName, #list
end
local function wait(seconds) H.update(seconds) end
local function tick(dest, spell, amount, crit)
    log("SPELL_PERIODIC_DAMAGE", PLAYER, dest, spell, { amount, 0, 32, 0, 0, 0, crit or nil })
end
local function applied(dest, spell) log("SPELL_AURA_APPLIED", PLAYER, dest, spell, { "DEBUFF" }) end

-- 1. Corruption: tooltip estimate, then learned ticks ---------------------------------------------------------
cast(27216); applied(mobs.A, 27216)
local total = remaining()
check("Corruption shows the tooltip estimate at once", total, 900)
wait(3); tick(mobs.A, 27216, 180)
check("after tick 1 of 6 (180): 5 x 180 left", (remaining()), 900)
wait(3); tick(mobs.A, 27216, 180)
check("after tick 2: 4 x 180 left", (remaining()), 720)
check("tick size learned per spell rank", db.ticks[27216], 180)

-- 2. A stranger's Shadow damage on the mob no longer confuses it (combat log names the spell) ------------------
log("SPELL_PERIODIC_DAMAGE", "Player-1-OTHER", mobs.A, 27216, { 400 })
log("SPELL_DAMAGE", PLAYER, mobs.A, 27209, { 580 })
check("someone else's Corruption and my Shadow Bolt ignored", (remaining()), 720)

-- 3. Tab-dotting: the earlier mob keeps ticking while it's not the target ------------------------------------
targetGuid = mobs.B; H.fire("PLAYER_TARGET_CHANGED")
cast(27218); applied(mobs.B, 27218)
check("Agony estimate on mob B (12 ticks, back-loaded)", (remaining()), 1356)
wait(3) -- mob A ticks unseen by UNIT_COMBAT, but the combat log reports it
tick(mobs.A, 27216, 180)
wait(3); tick(mobs.A, 27216, 180)
targetGuid = mobs.A; H.fire("PLAYER_TARGET_CHANGED")
check("mob A still tracked after tabbing away: 2 x 180 left", (remaining()), 360)

-- 4. Agony's shape: 4 small ticks, 4 average, 4 large ---------------------------------------------------------
targetGuid = mobs.B; H.fire("PLAYER_TARGET_CHANGED")
-- Agony was applied 6s ago and ticks every 2s (its first ticks went unreported here, but the aura was seen,
-- so it stays): this is tick 3 of 12 at 0.5 x the average
tick(mobs.B, 27218, 56)
local t, by = remaining()
check("Agony after tick 3 (56, no bonus): 1 x 56 + 4 x 112.5 + 4 x 169 left", by["Curse of Agony"], 1182, 1)

-- 5. A resisted recast keeps the earlier DoT -----------------------------------------------------------------
targetGuid = mobs.A; H.fire("PLAYER_TARGET_CHANGED")
cast(27216)
log("SPELL_MISSED", PLAYER, mobs.A, 27216, { "RESIST" })
check("resisted recast: the earlier Corruption (2 ticks) remains", (remaining()), 360)

-- 6. A resisted fresh cast is dropped ---------------------------------------------------------------------------
cast(27215)
log("SPELL_MISSED", PLAYER, mobs.A, 27215, { "RESIST" })
local _, byA = remaining()
check("resisted Immolate isn't shown", byA["Immolate"], nil)

-- 7. Dispelled / broken: aura removed -------------------------------------------------------------------------
wait(1)
log("SPELL_AURA_REMOVED", PLAYER, mobs.A, 27216, { "DEBUFF" })
check("Corruption removed by the combat log", (remaining()), 0)

-- 8. Mob died: everything on it goes -----------------------------------------------------------------------------
targetGuid = mobs.B; H.fire("PLAYER_TARGET_CHANGED")
log("UNIT_DIED", "", mobs.B, 0)
check("dead mob's DoTs cleared", (remaining()), 0)

-- 9. Unstable Affliction reads as Shadow ---------------------------------------------------------------------------
cast(30405); applied(mobs.B, 30405)
wait(3); tick(mobs.B, 30405, 210)
check("Unstable Affliction tick matched (Shadow, 6 ticks): 5 x 210", (remaining()), 1050)

-- 10. Siphon Life ("health every 3 sec") ------------------------------------------------------------------------
cast(30911); applied(mobs.B, 30911)
local _, byB = remaining()
check("Siphon Life parsed: 10 x 63", byB["Siphon Life"], 630)
-- Drain Life is a channel: not tracked, and its ticks don't feed anything
cast(27238); applied(mobs.B, 27238)
wait(1); tick(mobs.B, 27238, 108)
_, byB = remaining()
check("Drain Life ignored", byB["Drain Life"], nil)
log("UNIT_DIED", "", mobs.B, 0)

-- 11. Rip with real combo points (readable on TBC) ----------------------------------------------------------------
comboPoints = 5
cast(27008); comboPoints = 0
log("SPELL_AURA_APPLIED", PLAYER, mobs.B, { "Rip", 1 }, { "DEBUFF" })
_, byB = remaining()
check("Rip at 5 combo points: 906", byB["Rip"], 906)
wait(2); log("SPELL_PERIODIC_DAMAGE", PLAYER, mobs.B, { "Rip", 1 }, { 160 })
_, byB = remaining()
check("Rip after a 160 tick: 5 x 160", byB["Rip"], 800)
check("Rip's tick learned per combo point count", db.ticks["27008x5"], 160)
log("UNIT_DIED", "", mobs.B, 0)

-- 12. Pounce: its ticks are "Pounce Bleed"; its stun can be IMMUNE while the bleed lands --------------------------
cast(27006)
log("SPELL_MISSED", PLAYER, mobs.B, { "Pounce", 1 }, { "IMMUNE" })
log("SPELL_AURA_APPLIED", PLAYER, mobs.B, { "Pounce Bleed", 1 }, { "DEBUFF" })
_, byB = remaining()
check("Pounce kept after a stun IMMUNE, bleed aura confirms it", byB["Pounce"], 1236)
wait(3); log("SPELL_PERIODIC_DAMAGE", PLAYER, mobs.B, { "Pounce Bleed", 1 }, { 250 })
_, byB = remaining()
check("Pounce Bleed tick feeds Pounce: 5 x 250", byB["Pounce"], 1250)
log("UNIT_DIED", "", mobs.B, 0)

-- 13. Serpent Sting: the projectile lands 1.2s after the cast; ticks are timed from landing --------------------
cast(27016)
wait(1.2)
log("SPELL_AURA_APPLIED", PLAYER, mobs.B, { "Serpent Sting", 8 }, { "DEBUFF" })
wait(3)
log("SPELL_PERIODIC_DAMAGE", PLAYER, mobs.B, { "Serpent Sting", 8 }, { 140 })
_, byB = remaining()
check("Serpent Sting tick 1 of 5 matched after travel: 4 x 140", byB["Serpent Sting"], 560)
log("UNIT_DIED", "", mobs.B, 0)

-- 14. Immolation Trap: springs on whoever walks in (here: not the target) ------------------------------------
cast(27023)
wait(10)
log("SPELL_AURA_APPLIED", PLAYER, mobs.A, { "Immolation Trap Effect", 4 }, { "DEBUFF" })
targetGuid = mobs.A; H.fire("PLAYER_TARGET_CHANGED")
local _, byT = remaining()
check("trap sprung on mob A: 690 estimate", byT["Immolation Trap"], 690)
wait(3); log("SPELL_PERIODIC_DAMAGE", PLAYER, mobs.A, { "Immolation Trap Effect", 4 }, { 150 })
_, byT = remaining()
check("trap tick fed through the alias: 4 x 150", byT["Immolation Trap"], 600)
log("UNIT_DIED", "", mobs.A, 0)

-- 15. Expiry: a DoT runs out on its own -----------------------------------------------------------------------
cast(34917); applied(mobs.A, 34917)
for _ = 1, 5 do wait(3); tick(mobs.A, 34917, 140) end
wait(1)
log("SPELL_AURA_REMOVED", PLAYER, mobs.A, 34917, { "DEBUFF" })
check("Vampiric Touch gone after its 5th tick", (remaining()), 0)

-- 16. Holy Fire ticks every 2s (5 ticks) ---------------------------------------------------------------------------
cast(25469); log("SPELL_AURA_APPLIED", PLAYER, mobs.A, { "Holy Fire", 2 }, { "DEBUFF" })
wait(2); log("SPELL_PERIODIC_DAMAGE", PLAYER, mobs.A, { "Holy Fire", 2 }, { 40 })
_, byT = remaining()
check("Holy Fire: 4 x 40 left after tick 1", byT["Holy Fire"], 160)

-- 17. Rupture's duration follows combo points -----------------------------------------------------------------
log("UNIT_DIED", "", mobs.A, 0)
comboPoints = 3; cast(26993); comboPoints = 0
log("SPELL_AURA_APPLIED", PLAYER, mobs.A, { "Rupture", 1 }, { "DEBUFF" })
_, byT = remaining()
check("Rupture at 3 points: 606 over 12s", byT["Rupture"], 606)

-- An unconfirmed DoT (no aura seen) that never ticks is still dropped
cast(27215)
wait(7)
local _, byZ = remaining()
check("Immolate with no aura and no ticks dropped after 2 missed ticks", byZ["Immolate"], nil)

-- 18. The display loop and the marker -------------------------------------------------------------------------
step("display loop runs with live DoTs", function() for _ = 1, 20 do H.update(0.1) end end)
step("/did debug, /did ticks, /did help", function()
    SlashCmdList.DOESITDIE("ticks"); SlashCmdList.DOESITDIE("help")
end)

-- 19. A nameplate addon with an unnamed health bar (Blizzard's hidden): found by matching the mob's health ------
do
    FakePlate.UnitFrame.healthBar:Hide()
    local holder = CreateFrame("Frame", nil, FakePlate)
    local castbar = CreateFrame("StatusBar", nil, holder)
    castbar:SetSize(120, 8); castbar:SetMinMaxValues(0, 1.5); castbar.value = 0.7
    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetSize(120, 12); bar:SetMinMaxValues(0, 100); bar.value = 100
    function FakePlate.GetChildren(self) return holder end
    function holder.GetChildren(self) return castbar, bar end
    function bar.GetEffectiveAlpha() return 1 end
    function castbar.GetEffectiveAlpha() return 1 end
    function FakePlate.UnitFrame.healthBar.GetEffectiveAlpha() return 1 end
    step("nameplate refresh with a plate addon", function() for _ = 1, 15 do H.update(0.1) end end)
    local status = ns.plateBarStatus and ns.plateBarStatus() or "?"
    check("plate addon's bar found by health (not the cast bar)", status:find("matched by health: child1.child2", 1, true) ~= nil, true)
    print("      status: " .. tostring(status))
end

-- 19b. Threat Plates: its plate frame hangs on Blizzard's plate as plate.TPFrame, the bar in TPFrame.visual.healthbar
do
    local tp = CreateFrame("Frame", nil, FakePlate)
    local hb = CreateFrame("StatusBar", nil, tp)
    hb:SetSize(120, 12); hb:SetMinMaxValues(0, 100); hb.value = 100
    function hb.GetEffectiveAlpha() return 1 end
    tp.visual = { healthbar = hb, name = {}, castbar = CreateFrame("StatusBar", nil, tp) }
    FakePlate.TPFrame = tp
    local oldChildren = FakePlate.GetChildren
    function FakePlate.GetChildren(self) return tp end
    -- a fresh plate: the previous test's addon bar is gone
    local hidden = {}
    for _, f in ipairs(frames) do
        if f.kind == "StatusBar" and f.shown and f.parent and f.parent.parent == FakePlate and f.parent ~= tp then f:Hide(); table.insert(hidden, f) end
    end
    step("nameplate refresh with Threat Plates", function() for _ = 1, 3 do H.update(0.1) end end)
    local status = ns.plateBarStatus and ns.plateBarStatus() or "?"
    check("Threat Plates' health bar found", status:find("TPFrame.visual.healthbar", 1, true) ~= nil, true)
    print("      status: " .. tostring(status))
    FakePlate.TPFrame = nil
    FakePlate.GetChildren = oldChildren
    hb:Hide()
    for _, f in ipairs(hidden) do f:Show() end
end

-- 20. Plater with "use UIParent": its unit frame is outside the Blizzard plate, linked as plate.unitFrame -----------
do
    Plater = {}
    local platerFrame = CreateFrame("Frame", nil, UIParent)
    platerFrame:SetFrameStrata("HIGH"); platerFrame:SetFrameLevel(40)
    local hb = CreateFrame("StatusBar", nil, platerFrame)
    hb:SetSize(130, 14); hb:SetFrameStrata("HIGH"); hb:SetFrameLevel(42); hb:SetMinMaxValues(0, 100); hb.value = 100
    local border = CreateFrame("Frame", nil, hb); border:SetFrameLevel(46)
    function hb.GetChildren() return border end
    function hb.GetEffectiveAlpha() return 1 end
    platerFrame.healthBar = hb
    FakePlate.unitFrame = platerFrame
    step("nameplate refresh with Plater on UIParent", function() for _ = 1, 15 do H.update(0.1) end end)
    check("Plater's bar used", ns.plateBarStatus(), "Plater healthBar")
    local marker
    for _, f in ipairs(frames) do if f.parent == platerFrame and f.kind == "StatusBar" and f.allPoints == hb then marker = f end end
    check("marker sits on Plater's frame, over its health bar", marker ~= nil, true)
    check("marker in Plater's strata", marker and marker.strata, "HIGH")
    check("marker above Plater's border frame", marker and marker.level, 51)
    check("marker shown", marker and marker.shown, true)
    -- Plater raises the plate (it became the target): the marker must follow it on top
    platerFrame:SetFrameStrata("DIALOG"); hb:SetFrameStrata("DIALOG"); hb:SetFrameLevel(60); border:SetFrameLevel(64)
    for _ = 1, 3 do H.update(0.1) end
    check("marker follows Plater's raised strata", marker and marker.strata, "DIALOG")
    check("marker back above Plater's raised bar", marker and marker.level, 69)
end

-- 21. Drain Life while channelling: 5 ticks over 5s, pushback shortens it, stopping removes it ------------------
do
    local channelEnd
    function UnitChannelInfo(unit) if channelEnd then return "Drain Life", "", 0, 0, channelEnd * 1000 end end
    local function channel(spellID, seconds)
        castCount = castCount + 1
        local guid = "Cast-" .. castCount
        channelEnd = now + seconds
        H.fire("UNIT_SPELLCAST_SENT", "player", "Mob", guid, spellID)
        H.fire("UNIT_SPELLCAST_CHANNEL_START", "player", guid, spellID)
        H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", guid, spellID)
    end
    local function stop() channelEnd = nil; H.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "x", 0) end
    local function dl() local _, by = remaining(); return by["Drain Life"] end
    channel(27238, 5)
    applied(mobs.A, 27238)
    check("Drain Life channel predicted: 5 x 108", dl(), 540)
    wait(1); tick(mobs.A, 27238, 150)
    check("after a 150 tick: 4 x 150 left", dl(), 600)
    wait(0.5)
    channelEnd = channelEnd - 1.2 -- pushback: now ends at 3.8s
    H.fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
    check("pushback: ticks at 2s and 3s left (4s is past the end)", dl(), 300)
    wait(0.5); tick(mobs.A, 27238, 150)
    check("after tick 2: one tick left, the end isn't reset by the tick", dl(), 150)
    stop()
    check("channel stopped: Drain Life gone", dl(), nil)
    check("Drain Life tick learned", db.ticks[27238], 150)
    -- Re-channel: starts from the learned size straight away
    channel(27238, 5)
    check("next Drain Life starts at the learned 5 x 150", dl(), 750)
    stop()
    -- Drain Soul (3s ticks) and Mind Flay (1s ticks)
    channel(25311, 15)
    local _, by = remaining(); check("Drain Soul channel: 620 over 15s", by["Drain Soul"], 620)
    stop()
    channel(25387, 3)
    _, by = remaining(); check("Mind Flay channel: 3 ticks of 176", by["Mind Flay"], 528)
    stop()
    SlashCmdList.DOESITDIE("channels")
    channel(27238, 5)
    check("/did channels turns it off", dl(), nil)
    stop(); SlashCmdList.DOESITDIE("channels")
end

-- 22. Accuracy report: a tick size learned under a +20% debuff, then a cast without it ---------------------------
do
    log("UNIT_DIED", "", mobs.A, 0)
    db.ticks[27216] = 216 -- learned while Shadow Vulnerability was up
    db.tickHistory = {}
    cast(27216); applied(mobs.A, 27216)
    for _ = 1, 6 do wait(3); tick(mobs.A, 27216, 180) end
    wait(0.5)
    log("SPELL_AURA_REMOVED", PLAYER, mobs.A, 27216, { "DEBUFF" })
    local last = db.accuracy and db.accuracy[#db.accuracy] or ""
    print("      " .. last)
    check("accuracy: predicted 1296 from the learned 216/tick", last:find("predicted 1296", 1, true) ~= nil, true)
    check("accuracy: really dealt 1080, 20% too high", last:find("dealt 1080 (17% too high)", 1, true) ~= nil, true)
    step("/did accuracy prints", function() SlashCmdList.DOESITDIE("accuracy") end)
    check("printed to chat", chat[#chat]:find("Corruption: predicted 1296", 1, true) ~= nil, true)
end

-- 23. Curse of Agony with spell power: base ramps (56/113/169), bonus (+83) is flat. The in-game case. ---------------
do
    log("UNIT_DIED", "", mobs.A, 0)
    targetGuid = mobs.A; H.fire("PLAYER_TARGET_CHANGED")
    local ticks = { 139, 139, 139, 139, 196, 196, 196, 196, 252, 252, 252, 252 } -- 2348 in all
    db.tickHistory = {}; db.ticks[27218] = nil
    cast(27218); applied(mobs.A, 27218)
    wait(2); tick(mobs.A, 27218, ticks[1])
    local _, by = remaining()
    check("Agony after its first tick predicts the other 11 exactly (2209)", by["Curse of Agony"], 3 * 139 + 4 * 196 + 4 * 252, 3)
    for i = 2, 12 do wait(2); tick(mobs.A, 27218, ticks[i]) end
    wait(0.5); log("SPELL_AURA_REMOVED", PLAYER, mobs.A, 27218, { "DEBUFF" })
    check("learned average tick ~196", db.ticks[27218], 195.7, 1)
    -- next cast, before any tick: the whole curse from the learned size
    cast(27218); applied(mobs.A, 27218)
    _, by = remaining()
    check("next Agony predicted from the learned size: 2348", by["Curse of Agony"], 2348, 6)
    for i = 1, 12 do wait(2); tick(mobs.A, 27218, ticks[i]) end
    wait(0.5); log("SPELL_AURA_REMOVED", PLAYER, mobs.A, 27218, { "DEBUFF" })
    local last = db.accuracy[#db.accuracy]
    print("      " .. last)
    check("accuracy line shows 0%", last:find("(0% too high)", 1, true) ~= nil, true)
end

-- 24. Spell power changed since a size was learned: the bonus part follows the power at cast -----------------------
do
    log("UNIT_DIED", "", mobs.A, 0)
    spellPower = 500
    function GetSpellBonusDamage(index) return index == 6 and spellPower or 0 end
    db.ticks[27216], db.tickPower, db.tickHistory = nil, {}, {}
    cast(27216); applied(mobs.A, 27216)
    for _ = 1, 6 do wait(3); tick(mobs.A, 27216, 230) end -- base 150 + bonus 80 at 500 spell power
    wait(0.5); log("SPELL_AURA_REMOVED", PLAYER, mobs.A, 27216, { "DEBUFF" })
    check("learned 230 per tick at 500 spell power", db.tickPower[27216], 500)
    spellPower = 750 -- a trinket proc
    cast(27216); applied(mobs.A, 27216)
    local _, by = remaining()
    check("Corruption at 750 spell power: 6 x (150 + 120) = 1620", by["Corruption"], 1620)
    spellPower = 500
    wait(3); tick(mobs.A, 27216, 270)
    _, by = remaining()
    check("its own first tick then takes over: 5 x 270", by["Corruption"], 1350)
    log("UNIT_DIED", "", mobs.A, 0)
    GetSpellBonusDamage = nil
end

-- 25. Shadow Vulnerability (+20%) on one mob, not the next: the pre-first-tick estimate stays cautious ---------------
do
    local function fullCorruption(tickSize)
        cast(27216); applied(mobs.A, 27216)
        for _ = 1, 6 do wait(3); tick(mobs.A, 27216, tickSize) end
        wait(0.5); log("SPELL_AURA_REMOVED", PLAYER, mobs.A, 27216, { "DEBUFF" })
    end
    log("UNIT_DIED", "", mobs.A, 0)
    SlashCmdList.DOESITDIE("reset")
    fullCorruption(243) -- no debuff on the mob
    fullCorruption(291) -- Shadow Vulnerability up
    cast(27216); applied(mobs.A, 27216)
    local _, by = remaining()
    check("after a buffed cast, the next starts from the lowest recent size: 6 x 243", by["Corruption"], 1458)
    wait(3); tick(mobs.A, 27216, 291)
    _, by = remaining()
    check("its first tick (291, debuff up again) takes over: 5 x 291", by["Corruption"], 1455)
    log("UNIT_DIED", "", mobs.A, 0)
    for _ = 1, 5 do fullCorruption(291) end -- 5 buffed casts in a row push the 243 out of the history
    log("UNIT_DIED", "", mobs.A, 0)
    cast(27216); applied(mobs.A, 27216)
    _, by = remaining()
    check("history of 5: old low cast forgotten, 6 x 291", by["Corruption"], 1746)
    log("UNIT_DIED", "", mobs.A, 0)
end

-- 26. Partial resists show in the accuracy report -----------------------------------------------------------------
do
    log("UNIT_DIED", "", mobs.A, 0)
    cast(27216); applied(mobs.A, 27216)
    for _ = 1, 6 do wait(3); log("SPELL_PERIODIC_DAMAGE", PLAYER, mobs.A, 27216, { 218, 0, 32, 73, 0, 0 }) end
    wait(0.5); log("SPELL_AURA_REMOVED", PLAYER, mobs.A, 27216, { "DEBUFF" })
    local last = db.accuracy[#db.accuracy]
    print("      " .. last)
    check("report shows the resisted amount", last:find("438 resisted by the mob", 1, true) ~= nil, true)
end

-- 27. The marker sits under the target frame's health text ---------------------------------------------------------
local okT, errT = pcall(function()
    local function textAt(cx, cy, owner)
        local fs = FakeMock("FontString", owner)
        function fs.GetObjectType() return "FontString" end
        function fs.GetLeft() return cx - 10 end
        function fs.GetRight() return cx + 10 end
        function fs.GetTop() return cy + 5 end
        function fs.GetBottom() return cy - 5 end
        function fs.SetParent(self, p) self.parent = p end
        function fs.GetText() return "39%" end
        function fs.GetFont() return "Fonts\\ARIALN.TTF", 12, "OUTLINE" end
        function fs.GetTextColor() return 1, 1, 1, 1 end
        function fs.GetDrawLayer() return "OVERLAY", 0 end
        return fs
    end
    TargetFrame = CreateFrame("Frame", "TargetFrame", UIParent)
    TargetFrame:SetFrameStrata("LOW"); TargetFrame:SetFrameLevel(2)
    TargetFrame.TargetFrameContent, TargetFrame.TargetFrameContainer, TargetFrame.portrait, TargetFrame.healthbar = false, false, false, false
    local bar = CreateFrame("StatusBar", "TargetFrameHealthBar", TargetFrame)
    bar:SetFrameStrata("LOW"); bar:SetFrameLevel(4)
    function bar.GetRect() return 100, 500, 120, 14 end
    function bar.GetEffectiveScale() return 1 end
    local textFrame = CreateFrame("Frame", nil, bar)               -- the addon's text frame, just above the bar
    textFrame:SetFrameStrata("LOW"); textFrame:SetFrameLevel(5)
    function textFrame.GetEffectiveScale() return 1 end
    local pct = textAt(120, 507, textFrame)                         -- "32%" at the left of the bar
    local value = textAt(260, 507, textFrame)                       -- "2.1K" to the right of the bar, outside it
    local onBar = textAt(160, 507, bar)                             -- text drawn on the bar itself
    function textFrame.GetRegions() return pct, value end
    function bar.GetRegions() return onBar end
    function bar.GetChildren() return textFrame, overlay end
    local overlay = CreateFrame("StatusBar", nil, bar)              -- the visible red colour, drawn above the bar
    overlay:SetFrameStrata("LOW"); overlay:SetFrameLevel(12)
        local high = CreateFrame("Frame", nil, TargetFrame)             -- border art far above everything
    high:SetFrameStrata("LOW"); high:SetFrameLevel(30)
    function TargetFrame.GetChildren() return bar, high end
    local deepText = CreateFrame("Frame", nil, high)                -- text kept on the border frame, elsewhere in the tree
    deepText:SetFrameStrata("LOW"); deepText:SetFrameLevel(31)
    function deepText.GetEffectiveScale() return 1 end
    local deep = textAt(200, 507, deepText)
    function deepText.GetRegions() return deep end
    function high.GetChildren() return deepText end
    TargetFrameHealthBar = bar
    ns.display.attach(true)
    ns.relayer(); ns.refresh()
    local marker = DoesItDieRemaining
    check("marker above everything on the frame (top 31 + 1)", marker.level, 32)
    check("marker in the frame's top strata", marker.strata, "LOW")
    targetGuid = mobs.B; H.fire("PLAYER_TARGET_CHANGED")
    cast(27216); applied(mobs.B, 27216)
    for _ = 1, 3 do H.update(0.1) end
    local mirrored, copy = ns.textMirror(pct)
    check("percentage text copied above the marker", mirrored, true)
    check("original text left on its own frame", pct.parent, textFrame)
    local holder = copy and copy.parent
    check("copy sits above the marker's top layer", holder and holder.level, 37)
    check("copy shows the same text", copy and copy.text, "39%")
    check("copy shown while the marker shows", copy and copy.shown, true)
    check("text on the bar itself copied too", (ns.textMirror(onBar)), true)
    for _ = 1, 3 do ns.relayer(); ns.refresh() end
    check("layers stay put on later checks (no creeping up)", marker.level, 32)
    check("text still copied after later checks", (ns.textMirror(pct)), true)
    check("text outside the bar left alone", (ns.textMirror(value)), false)
    check("text elsewhere in the frame, over the bar, copied too", (ns.textMirror(deep)), true)
    check("marker drawn above the visible red colour (level 12)", marker.level > overlay.level, true)
    db.markerUnderText = false
    ns.relayer(); ns.refresh()
    local _, copyOff = ns.textMirror(pct)
    check("setting off: copy hidden", copyOff and copyOff.shown, false)
    check("setting off: marker still above the whole frame", marker.level, 32)
    db.markerUnderText = true
    SlashCmdList.DOESITDIE("text")
    check("/did text toggles it", db.markerUnderText, false)
    SlashCmdList.DOESITDIE("text")
end)
if not okT then failures = failures + 1; print('FAIL  layering test crashed: ' .. tostring(errT)) end

-- 28. Text kept on a frame outside the target frame (as some unit frame addons do) is found too --------------------
local okT2, errT2 = pcall(function()
    local function textAt(cx, cy, owner)
        local fs = FakeMock("FontString", owner)
        function fs.GetObjectType() return "FontString" end
        function fs.GetLeft() return cx - 10 end
        function fs.GetRight() return cx + 10 end
        function fs.GetTop() return cy + 5 end
        function fs.GetBottom() return cy - 5 end
        function fs.GetText() return "39%" end
        function fs.SetParent(self, p) self.parent = p end
        function fs.GetFont() return "Fonts\\ARIALN.TTF", 12, "OUTLINE" end
        function fs.GetTextColor() return 1, 1, 1, 1 end
        function fs.GetDrawLayer() return "OVERLAY", 0 end
        return fs
    end
    local isFrame = { Frame = true, StatusBar = true, Button = true }
    function EnumerateFrames(after)
        local start = 1
        if after then for i, f in ipairs(frames) do if f == after then start = i + 1 break end end end
        for i = start, #frames do if isFrame[frames[i].kind] then return frames[i] end end
    end
    local outside = CreateFrame("Frame", "MyUnitFramesTargetText", UIParent)
    outside:SetFrameStrata("LOW"); outside:SetFrameLevel(8)
    function outside.GetEffectiveScale() return 1 end
    local far = textAt(130, 507, outside)
    function outside.GetRegions() return far end
    ns.relayer(); ns.refresh()
    check("text on a frame outside the target frame copied too", (ns.textMirror(far)), true)
    local report = ns.textReport()
    local joined = table.concat(report, " | ")
    print("      " .. joined:sub(1, 160))
    check("/did textcheck lists it as lifted", joined:find("MyUnitFramesTargetText", 1, true) ~= nil and joined:find("copied above the marker", 1, true) ~= nil, true)
    step("/did textcheck runs", function() SlashCmdList.DOESITDIE("textcheck") end)
end)
if not okT2 then failures = failures + 1; print("FAIL  outside-text test crashed: " .. tostring(errT2)) end

-- 29. PvP: an enemy player's health is only a percentage; the real size is measured from damage taken ---------------
local okT3, errT3 = pcall(function()
    local enemy = "Player-1-0000ABCD"
    local pct, realUnitHealth, realUnitHealthMax, realUnitName = 100, UnitHealth, UnitHealthMax, UnitName
    function UnitPlayerControlled(u) return (u == "target" or u == "nameplate1") and targetGuid == enemy end
    function UnitIsUnit() return false end
    function UnitInParty() return false end
    function UnitInRaid() return false end
    function UnitHealth(u) if UnitPlayerControlled(u) then return pct end return realUnitHealth(u) end
    function UnitHealthMax(u) if UnitPlayerControlled(u) then return 100 end return realUnitHealthMax(u) end
    function UnitName(u) if UnitPlayerControlled(u) then return "Gankster" end return realUnitName(u) end
    targetGuid = enemy; H.fire("PLAYER_TARGET_CHANGED")
    for _ = 1, 3 do H.update(0.1) end                                   -- first look at the player: 100%
    local ticksBefore = db.ticks[27216]
    cast(27216); applied(enemy, 27216)
    for _ = 1, 3 do H.update(0.1) end
    check("enemy player not measured yet: no marker (instead of a full bar)", DoesItDieRemaining.shown, false)
    local told = false
    for _, line in ipairs(chat) do if line:find("measuring Gankster's health", 1, true) then told = true end end
    check("chat says it's measuring the player", told, true)
    log("SPELL_DAMAGE", "Player-1-OTHER", enemy, 27209, { 1200 })      -- someone hits them for 1200: 100% -> 90%
    pct = 90; H.fire("UNIT_HEALTH", "target")
    for _ = 1, 3 do H.update(0.1) end
    check("health measured: 1200 damage moved 10% = 12000", db.playerHealth and db.playerHealth.Gankster and db.playerHealth.Gankster.est, 12000)
    check("marker shows once the size is known", DoesItDieRemaining.shown, true)
    local _, mx = DoesItDieRemaining:GetMinMaxValues()
    check("marker scaled to the player's real health", mx, 12000, 1)
    wait(3); tick(enemy, 27216, 150)
    check("PvP tick learned separately", db.ticks["27216p"], 150)
    check("PvE tick size untouched by PvP", db.ticks[27216], ticksBefore)
    -- A later fight with the same player (new GUID after a relog) starts with the remembered size
    log("UNIT_DIED", "", enemy, 0)
    enemy = "Player-1-0000BEEF"; targetGuid = enemy; pct = 100; H.fire("PLAYER_TARGET_CHANGED")
    cast(27216); applied(enemy, 27216)
    for _ = 1, 3 do H.update(0.1) end
    check("same player again: remembered size used at once", DoesItDieRemaining.shown, true)
    SlashCmdList.DOESITDIE("pvp")
    for _ = 1, 3 do H.update(0.1) end
    check("/did pvp off: nothing drawn on the enemy player", DoesItDieRemaining.shown, false)
    check("setting saved", db.showOnPlayers, false)
    SlashCmdList.DOESITDIE("pvp")
    for _ = 1, 3 do H.update(0.1) end
    check("/did pvp on again: marker back", DoesItDieRemaining.shown, true)
    UnitPlayerControlled, UnitHealth, UnitHealthMax, UnitName = nil, realUnitHealth, realUnitHealthMax, realUnitName
    log("UNIT_DIED", "", enemy, 0)
end)
if not okT3 then failures = failures + 1; print("FAIL  PvP test crashed: " .. tostring(errT3)) end

-- PvP: a player kept topped up (healer, or a mage's Ice Barrier) never drops 8% overall: measured hit by hit ---------
local okT4, errT4 = pcall(function()
    local enemy = "Player-1-0000C0DE"
    local pct, realUnitHealth, realUnitHealthMax, realUnitName = 100, UnitHealth, UnitHealthMax, UnitName
    function UnitPlayerControlled(u) return (u == "target" or u == "nameplate1") and targetGuid == enemy end
    function UnitIsUnit() return false end
    function UnitInParty() return false end
    function UnitInRaid() return false end
    function UnitHealth(u) if UnitPlayerControlled(u) then return pct end return realUnitHealth(u) end
    function UnitHealthMax(u) if UnitPlayerControlled(u) then return 100 end return realUnitHealthMax(u) end
    local who = "Glacier"
    function UnitName(u) if UnitPlayerControlled(u) then return who end return realUnitName(u) end
    targetGuid = enemy; H.fire("PLAYER_TARGET_CHANGED")
    for _ = 1, 3 do H.update(0.1) end
    cast(27216); applied(enemy, 27216)
    for i = 1, 4 do
        log("SPELL_DAMAGE", "Player-1-OTHER", enemy, 27209, { 500 }); pct = 95; H.fire("UNIT_HEALTH", "target")
        H.update(0.5)
        -- the heal's health update arrives before its combat log event this time
        pct = 100; H.fire("UNIT_HEALTH", "target")
        log("SPELL_HEAL", "Player-1-HEALER", enemy, 27209, { 500, 0 })
        H.update(0.5)
    end
    local cached = db.playerHealth and db.playerHealth.Glacier
    check("topped-up player measured hit by hit: 500 per 5% = 10000", cached and cached.est, 10000)
    check("marker shows on the topped-up player", DoesItDieRemaining.shown, true)
    -- health drained by a spell (SPELL_PERIODIC_LEECH, power type -2) counts as damage
    enemy, who, pct = "Player-1-0000D00D", "Drainee", 100
    targetGuid = enemy; H.fire("PLAYER_TARGET_CHANGED")
    for _ = 1, 3 do H.update(0.1) end
    H.fire("UNIT_HEALTH", "target") -- first look at 100%
    log("SPELL_PERIODIC_LEECH", PLAYER, enemy, 27238, { 1000, -2, 0 }); pct = 90; H.fire("UNIT_HEALTH", "target")
    for _ = 1, 3 do H.update(0.1) end
    local drained = db.playerHealth and db.playerHealth.Drainee
    check("drained health counted as damage: 1000 per 10% = 10000", drained and drained.est, 10000)
    UnitPlayerControlled, UnitHealth, UnitHealthMax, UnitName = nil, realUnitHealth, realUnitHealthMax, realUnitName
    log("UNIT_DIED", "", enemy, 0)
end)
if not okT4 then failures = failures + 1; print("FAIL  PvP hit-by-hit test crashed: " .. tostring(errT4)) end

-- One odd cast can't halve the cautious estimate; partial resists learn the unresisted size -------------------
local okF, errF = pcall(function()
    db.ticks[27216] = 350; db.tickPower = db.tickPower or {}; db.tickPower[27216] = nil
    db.tickHistory = db.tickHistory or {}
    db.tickHistory[27216] = { { avg = 175 }, { avg = 350 } }
    local mob = "Creature-0-0000-0-0000-22222-0000F10001"
    targetGuid = mob; H.fire("PLAYER_TARGET_CHANGED")
    cast(27216); applied(mob, 27216)
    local _, by = remaining()
    check("cautious estimate floored at 80% of the latest cast (6 x 280)", by["Corruption"], 1680)
    -- a tick with 175 partly resisted is learned as 350
    wait(3); log("SPELL_PERIODIC_DAMAGE", PLAYER, mob, 27216, { 175, 0, 32, 175, 0, 0, nil })
    log("UNIT_DIED", "", mob, 0)
    check("partly resisted tick learned at its full size", db.ticks[27216], 350)
    -- the accuracy label for a prediction at half the real damage
    local last = db.accuracy[#db.accuracy]
    check("accuracy line has no minus sign", last:find("-", 1, true) == nil or last:find("%(%-") == nil, true)
end)
if not okF then failures = failures + 1; print("FAIL  cautious floor test crashed: " .. tostring(errF)) end

-- A tooltip that isn't loaded yet on the first cast (fresh character): the cast waits for it -----------------------
local okW, errW = pcall(function()
    SPELLS[6547] = { "Rend", "" }
    local mob = "Creature-0-0000-0-0000-33333-0000AB0001"
    targetGuid = mob; H.fire("PLAYER_TARGET_CHANGED")
    cast(6547); applied(mob, 6547)
    local _, by = remaining()
    check("Rend with no tooltip yet: not shown", by["Rend"], nil)
    SPELLS[6547][2] = "Wounds the target causing them to bleed for 45 damage over 15 sec."
    H.update(0.2)
    _, by = remaining()
    check("Rend tracked once its tooltip loads", by["Rend"] ~= nil, true)
    log("UNIT_DIED", "", mob, 0)
end)
if not okW then failures = failures + 1; print("FAIL  tooltip wait test crashed: " .. tostring(errW)) end

-- A tooltip that isn't read as a DoT is logged once, so a missed DoT can be found with /did debug
do
    cast(27209); cast(27209)
    local n = 0
    for _, line in ipairs(db.log) do if line:find("SKIP Shadow Bolt", 1, true) then n = n + 1 end end
    check("skipped tooltip logged once", n, 1)
end

-- Classic Era (vanilla tooltips, max ranks) ---------------------------------------------------------------------------
local okCE, errCE = pcall(function()
    local P = ns.parseDot
    local function total(desc, cp) return (P(desc, cp)) end
    check("CE Corruption", total("Corrupts the target, causing 822 Shadow damage over 18 sec."), 822)
    check("CE Immolate: periodic part", total("Burns the enemy for 279 Fire damage and then an additional 510 Fire damage over 15 sec."), 510)
    check("CE Curse of Agony", total("Curses the target with agony, causing 1044 Shadow damage over 24 sec."), 1044)
    check("CE Siphon Life: 10 x 15", total("Transfers 15 health from the target to the caster every 3 sec.  Lasts 30 sec."), 150)
    check("CE Drain Life 'every second': 5 x 71", total("Transfers 71 health every second from the target to the caster.  Lasts 5 sec."), 355)
    check("CE Drain Life 'every 1 sec': 5 x 71", total("Transfers 71 health every 1 sec from the target to the caster.  Lasts 5 sec."), 355)
    check("CE Shadow Word: Pain", total("A word of darkness that causes 852 Shadow damage over 18 sec."), 852)
    check("CE Devouring Plague", total("Afflicts the target with a disease that causes 904 Shadow damage over 24 sec.  Damage caused by the Devouring Plague heals the caster."), 904)
    check("CE Moonfire", total("Burns the enemy for 189 to 222 Arcane damage and then an additional 384 Arcane damage over 12 sec."), 384)
    check("TBC low-rank Rend with weapon bonus: 28 + 1", total("Wounds the target causing them to bleed for 28 damage plus an additional 1 (based on weapon damage) over 12 sec."), 29)
    check("bracketed note before 'over' ignored", total("Bleeds the target for 50 damage (increased by attack power) over 15 sec."), 50)
    check("CE Rend", total("Wounds the target causing them to bleed for 147 damage over 21 sec."), 147)
    check("CE Flame Shock", total("Instantly sears the target with fire, causing 292 Fire damage immediately and 320 Fire damage over 12 sec."), 320)
    check("CE Garrote", total("Garrote the enemy, causing 1194 damage over 18 sec.  Awards 1 combo point."), 1194)
    check("CE Rupture 5 points", total("Finishing move that causes damage over time, increased by your attack power.  Lasts longer per combo point:\n   1 point: 284 damage over 8 secs\n   2 points: 400 damage over 10 secs\n   3 points: 532 damage over 12 secs\n   4 points: 680 damage over 14 secs\n   5 points: 844 damage over 16 secs", 5), 844)
    check("CE Rip 3 points", total("Finishing move that causes damage over time.  Damage increases per combo point and by your attack power:\r\n   1 point: 282 damage over 12 sec.\r\n   2 points: 408 damage over 12 sec.\r\n   3 points: 534 damage over 12 sec.\r\n   4 points: 660 damage over 12 sec.\r\n   5 points: 786 damage over 12 sec.", 3), 534)

    -- A vanilla fight end to end, with vanilla spell IDs (Corruption rank 7, Immolate rank 8)
    SPELLS[11672] = { "Corruption", "Corrupts the target, causing 822 Shadow damage over 18 sec." }
    SPELLS[11668] = { "Immolate", "Burns the enemy for 279 Fire damage and then an additional 510 Fire damage over 15 sec." }
    local mob = "Creature-0-0000-0-0000-11111-0000CE0001"
    targetGuid = mob; H.fire("PLAYER_TARGET_CHANGED")
    cast(11672); applied(mob, 11672)
    cast(11668); applied(mob, 11668)
    local t, by = remaining()
    check("CE fight: both DoTs shown", by["Corruption"] ~= nil and by["Immolate"] ~= nil, true)
    wait(3); tick(mob, 11672, 160)
    _, by = remaining()
    check("CE fight: Corruption follows its real ticks (5 left x 160)", by["Corruption"], 800)
    log("UNIT_DIED", "", mob, 0)
    check("CE fight: cleared on death", (remaining()), 0)
end)
if not okCE then failures = failures + 1; print("FAIL  Classic Era test crashed: " .. tostring(errCE)) end

print(string.format("\n%d passed, %d failed", passes, failures))
if failures > 0 then
    print("--- last log lines ---")
    for i = math.max(1, #db.log - 40), #db.log do print(db.log[i]) end
    os.exit(1)
end
