-- Forever test: the same addon on a fake Forever client. GetBuildInfo says 1.60 (interface 16001), the combat log
-- is forbidden (registering it would show a "blocked" popup), target health is secret (can't be compared or used
-- in math), and ticks come from UNIT_COMBAT. Checks nothing errors and the marker follows the ticks.
-- Run: lua forever_test.lua <addon dir> <test dir>
local ADDON, TESTDIR = arg[1], arg[2]
dofile(TESTDIR .. "/fake_wow.lua")
local H = dofile(TESTDIR .. "/helpers.lua")

C_AddOns = { IsAddOnLoaded = function(name) return name == "DoesItDie" or name == "EnemyFrames" end } -- JoeGG's original installed too
function GetBuildInfo() return "1.60.2", "70000", "Oct 1 2026", 11600 end -- interface not in the 16000s: found by its version
CombatLogGetCurrentEventInfo = function() error("combat log read on Forever") end
-- Secret values: opaque tables; comparing or doing math with them errors, as on Forever.
local secretMeta = { __lt = function() error("compared a secret value") end, __le = function() error("compared a secret value") end,
    __add = function() error("math on a secret value") end, __sub = function() error("math on a secret value") end,
    __mul = function() error("math on a secret value") end, __div = function() error("math on a secret value") end,
    __unm = function() error("math on a secret value") end, __concat = function() error("concat of a secret value") end }
local function secret(v) return setmetatable({ v = v }, secretMeta) end
function issecretvalue(v) return getmetatable(v) == secretMeta end
local realMathMax = math.max
math.max = function(...) for i = 1, select("#", ...) do if issecretvalue((select(i, ...))) then error("math.max on a secret value") end end return realMathMax(...) end
function UnitHealth(unit) if unit == "target" or unit == "nameplate1" then return secret(100) end return 100 end
function UnitHealthMax(unit) if unit == "target" or unit == "nameplate1" then return secret(100) end return 100 end
function GetSpellBonusDamage() return secret(300) end
function UnitAttackPower() return secret(500), secret(20), 0 end

local failures, passes = 0, 0
local function check(label, actual, expected)
    local ok = actual == expected
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
local toc = io.open(ADDON .. "/DoesItDieAdvanced.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if line:match("%.lua$") then
        step("load " .. line, function()
            local f = assert(io.open(ADDON .. "/" .. line)); H.load(line, f:read("*a"), ns); f:close()
        end)
    end
end
DoesItDieAdvancedDB = { markerHeight = 10, markerOffsetY = -4, markerInsetLeft = 6 } -- a v1.0.0 install, fit adjusted
step("ADDON_LOADED", function() H.fire("ADDON_LOADED", "DoesItDieAdvanced") end)
local db = DoesItDieAdvancedDB
check("recognised as Forever", ns.isForever, true)
check("original Does It Die installed: /dida registered", SLASH_DOESITDIEADVANCED1, "/dida")
check("original Does It Die installed: /did left to it", SLASH_DOESITDIEADVANCED3, nil)
check("v1.0.0's Forever fit reset: whole bar again", DoesItDieAdvancedDB.markerHeight == 0 and DoesItDieAdvancedDB.markerOffsetY == 0 and DoesItDieAdvancedDB.markerInsetLeft == 0, true)
check("saved settings in their own variable", DoesItDieAdvancedDB ~= nil and DoesItDieDB == nil, true)
local forbiddenRegistered = false
for _, f in ipairs(frames) do if f.events and f.events.COMBAT_LOG_EVENT_UNFILTERED then forbiddenRegistered = true end end
check("combat log never registered (no blocked popup)", forbiddenRegistered, false)

local errors = {}
local realPrint = print
step("/did opens and closes", function() SlashCmdList.DOESITDIEADVANCED(""); DoesItDieAdvancedOptions:Hide() end)

targetGuid = "Creature-0-0000-0-0000-1234-000000F0F0"
H.fire("PLAYER_TARGET_CHANGED")
local castCount = 0
local function cast(id)
    castCount = castCount + 1
    H.fire("UNIT_SPELLCAST_SENT", "player", "Mob", "Cast-" .. castCount, id)
    H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. castCount, id)
end
-- Blizzard's modern target frame, with health text whose position is secret
TargetFrame = CreateFrame("Frame", "TargetFrame", UIParent)
TargetFrame.TargetFrameContainer, TargetFrame.portrait, TargetFrame.healthbar = false, false, false
TargetFrame.TargetFrameContent = CreateFrame("Frame", nil, TargetFrame)
TargetFrame.TargetFrameContent.TargetFrameContentMain = CreateFrame("Frame", nil, TargetFrame.TargetFrameContent)
local main = TargetFrame.TargetFrameContent.TargetFrameContentMain
main.HealthBarsContainer = CreateFrame("Frame", nil, main)
main.HealthBar, main.HealthBarsContainer.healthBar = false, false
TargetFrame.TargetFrameContent.TargetFrameContentContextual = false
local hbar = CreateFrame("StatusBar", nil, main.HealthBarsContainer)
main.HealthBarsContainer.HealthBar = hbar
function hbar.GetRect() return 100, 500, 126, 20 end
function hbar.GetEffectiveScale() return 1 end
local leftText = FakeMock("FontString", hbar)
function leftText.GetObjectType() return "FontString" end
function leftText.GetLeft() return secret(110) end
function leftText.GetText() return "41%" end
function leftText.GetFont() return "Fonts\\FRIZQT__.TTF", 10, "OUTLINE" end
function leftText.GetTextColor() return 1, 1, 1, 1 end
function leftText.GetDrawLayer() return "OVERLAY", 0 end
function leftText.GetParent() return hbar end
hbar.LeftText = leftText
hbar.RightText, hbar.TextString, hbar.HealthBarText, hbar.ManaBarText = false, false, false, false
main.HealthBarsContainer.LeftText, main.HealthBarsContainer.RightText, main.HealthBarsContainer.TextString = false, false, false
main.HealthBarsContainer.HealthBarText, main.HealthBarsContainer.ManaBarText = false, false
-- An unnamed health text on its own frame (as EllesmereUI has), position hidden: copied too, being in the frame
local textFrame = CreateFrame("Frame", nil, hbar)
local otherText = FakeMock("FontString", textFrame)
function otherText.GetObjectType() return "FontString" end
function otherText.GetLeft() return secret(150) end
function otherText.GetRight() return secret(200) end
function otherText.GetTop() return secret(140) end
function otherText.GetBottom() return secret(130) end
function otherText.GetText() return "603 | 87.3%" end
function otherText.GetDrawLayer() return "OVERLAY", 0 end
function otherText.IsShown() return true end
function textFrame.GetRegions() return otherText end
function hbar.GetChildren() return textFrame end
step("attach to the target frame", function() ns.display.attach(true); ns.relayer(); ns.refresh() end)
step("cast Corruption", function() cast(172) end)
step("display refresh with secret health", function() for _ = 1, 5 do H.update(0.1) end end)
local list, total = ns.dotBreakdownForUnit("target")
check("Corruption tracked from its tooltip: 40", math.floor(total + 0.5), 40)
step("tick arrives through UNIT_COMBAT", function()
    H.update(2.5) -- 3 s after the cast: on the DoT's rhythm
    H.fire("UNIT_COMBAT", "target", "WOUND", "", 12, 32)
    for _ = 1, 3 do H.update(0.1) end
end)
list, total = ns.dotBreakdownForUnit("target")
check("Corruption follows its real tick: 3 left x 12", math.floor(total + 0.5), 36)
-- Live Forever hides the amount: ticks still matched by school and timing, so the DoT isn't dropped
step("cast Immolate", function() cast(348) end)
step("Immolate ticks with hidden amounts", function()
    for i = 1, 3 do
        H.update(3)
        H.fire("UNIT_COMBAT", "target", "WOUND", "", secret(7), 4)
        H.fire("UNIT_COMBAT", "nameplate1", "WOUND", "", secret(7), 4) -- the same hit through the plate
    end
    for _ = 1, 3 do H.update(0.1) end
end)
local _, by = nil, {}
list = ns.dotBreakdownForUnit("target")
for _, e in ipairs(list) do by[e.name] = math.floor(e.damage + 0.5) end
check("Immolate kept after 3 hidden ticks: 2 of 5 left (2 x 4)", by["Immolate"], 8)
local hiddenTicks = 0
for _, l in ipairs(db.log) do if l:find("TICK Immolate (amount hidden)", 1, true) then hiddenTicks = hiddenTicks + 1 end end
check("each hidden tick counted once (not once per unit)", hiddenTicks, 3)
local dropped = false
for _, l in ipairs(db.log) do if l:find("DROP Immolate", 1, true) then dropped = true end end
check("Immolate not dropped as never ticked", dropped, false)
check("Blizzard's health text found by name (position secret): copied above the marker", (ns.textMirror(leftText)), true)
check("an unnamed text in the target frame, position hidden: copied above the marker", (ns.textMirror(otherText)), true)
function hbar.GetRect() return secret(100), secret(500), secret(126), secret(20) end
function leftText.IsVisible() return setmetatable({}, getmetatable(secret(1))) end
step("refresh with the bar's position hidden", function() ns.relayer(); ns.refresh() end)
check("bar position hidden: health text still copied above the marker", (ns.textMirror(leftText)), true)
step("/dida textcheck with secret positions and visibility", function() SlashCmdList.DOESITDIEADVANCED("textcheck") end)
local listed = false
for _, l in ipairs(DoesItDieAdvancedDB.log) do if l:find("TEXTCHECK LeftText", 1, true) then listed = true end end
check("textcheck lists Blizzard's health text", listed, true)
-- Immolation Trap on Forever: sprung by its first (hidden-amount) Fire tick on whoever walked in
C_Spell.GetSpellName = (function(orig) return function(id) if id == 13795 then return "Immolation Trap" end return orig(id) end end)(C_Spell.GetSpellName)
C_Spell.GetSpellDescription = (function(orig) return function(id) if id == 13795 then return "Place a fire trap that will burn the first enemy to approach for 690 Fire damage over 15 sec.  Trap will exist for 1 min.  Only one trap can be active at a time." end return orig(id) end end)(C_Spell.GetSpellDescription)
local trapMob = "Creature-0-0000-0-0000-7777-0000AB0007"
targetGuid = trapMob; H.fire("PLAYER_TARGET_CHANGED")
step("place Immolation Trap", function() cast(13795) end)
step("mob walks in: hidden Fire tick", function() H.update(3.2); H.fire("UNIT_COMBAT", "target", "WOUND", "", secret(140), 4); H.update(0.1) end)
local _, trapBy = nil, {}
for _, e in ipairs(ns.dotBreakdownForUnit("target")) do trapBy[e.name] = math.floor(e.damage + 0.5) end
check("Immolation Trap tracked on Forever: 4 of 5 ticks left (552)", trapBy["Immolation Trap"], 552)
-- Enemy Frames: an unnamed grid under UIParent with a cell per nameplate unit, health bar as its child
local efGrid = CreateFrame("Frame", nil, UIParent)
local efCell = CreateFrame("Frame", nil, efGrid)
efCell.unit = "nameplate1"
local efBar = CreateFrame("StatusBar", nil, efCell)
efBar:SetFrameLevel(10)
local efTop = CreateFrame("Frame", nil, efBar) -- its name text frame, 2 above the bar
efTop:SetFrameLevel(12)
function efBar.GetChildren() return efTop end
local efName = FakeMock("FontString", efTop)
function efName.GetObjectType() return "FontString" end
function efName.GetText() return "Venom Spitter" end
function efName.GetDrawLayer() return "OVERLAY", 0 end
function efTop.GetRegions() return efName end
local efCast = CreateFrame("StatusBar", nil, efCell) -- its cast bar, drawn over the health bar while casting
efCast:SetFrameLevel(14)
function efCell.GetChildren() return efBar, efCast end
function efGrid.GetChildren() return efCell end
function UIParent.GetChildren() return efGrid end
function efCell.GetEffectiveAlpha() return 1 end
function efBar.GetEffectiveAlpha() return 1 end
step("cast Corruption for Enemy Frames", function() cast(172) end)
-- (the fake StatusBar does maths on its min/max, which a secret value refuses: plain health for this check)
local realUH, realUHM = UnitHealth, UnitHealthMax
function UnitHealth() return 100 end
function UnitHealthMax() return 100 end
step("refresh with Enemy Frames loaded", function() H.update(5.5); H.update(0.2) end)
UnitHealth, UnitHealthMax = realUH, realUHM
local efMarker
for _, f in ipairs(frames) do if f.parent == efCell and f.kind == "StatusBar" and f.allPoints == efBar then efMarker = f end end
check("marker on Enemy Frames' bar", efMarker ~= nil, true)
check("Enemy Frames marker shown", efMarker and efMarker.shown, true)
check("Enemy Frames marker above the cast bar too (level 14 + 5)", efMarker and efMarker.level, 19)
local efCopy
for _, f in ipairs(frames) do if f.kind == "fontstring" and f.allPoints == efName then efCopy = f end end
check("no copy of the mob's name drawn over the marker", efCopy, nil)
-- its crowd control bar (Fear) in a higher strata than the health bar: the marker follows it up
local efCC = CreateFrame("StatusBar", nil, efTop)
efCC:SetFrameStrata("HIGH"); efCC:SetFrameLevel(3)
function efTop.GetChildren() return efCC end
step("refresh with a crowd control bar in HIGH", function()
    function UnitHealth() return 100 end
    function UnitHealthMax() return 100 end
    H.update(0.2); H.update(0.2)
    UnitHealth, UnitHealthMax = realUH, realUHM
end)
check("Enemy Frames marker follows the CC bar's strata", efMarker and efMarker.strata, "HIGH")
check("Enemy Frames marker above the CC bar (above level 3)", efMarker and efMarker.level > 3, true)
local okEF, efReport = pcall(ns.enemyFramesReport)
check("/dida efcheck report", okEF and type(efReport) == "table" and #efReport > 3, true)
-- Enemy Frames reuses rows: the dotted mob moves to another row; the marker follows it there
local efCell2 = CreateFrame("Frame", nil, efGrid)
efCell2.unit = "nameplate2"
local efBar2 = CreateFrame("StatusBar", nil, efCell2)
function efCell2.GetChildren() return efBar2 end
function efCell2.GetEffectiveAlpha() return 1 end
function efBar2.GetEffectiveAlpha() return 1 end
function efGrid.GetChildren() return efCell, efCell2 end
step("rows swap mobs", function()
    efCell.unit, efCell2.unit = "nameplate2", "nameplate1"
    function UnitHealth() return 100 end
    function UnitHealthMax() return 100 end
    H.update(0.2); H.update(0.2)
    UnitHealth, UnitHealthMax = realUH, realUHM
end)
local efMarker2
for _, f in ipairs(frames) do if f.parent == efCell2 and f.kind == "StatusBar" and f.allPoints == efBar2 then efMarker2 = f end end
check("marker moved with the mob to its new row", efMarker2 ~= nil and efMarker2.shown, true)
check("old row's marker hidden", efMarker.shown, false)
efCell.unit = "nameplate1"; function efGrid.GetChildren() return efCell end
-- Feral bleeds scale with attack power, which Forever hides in combat
C_Spell.GetSpellName = (function(orig) return function(id) if id == 1822 then return "Rake" end return orig(id) end end)(C_Spell.GetSpellName)
C_Spell.GetSpellDescription = (function(orig) return function(id) if id == 1822 then return "Rake the target for 10 Bleed damage and an additional 57 Bleed damage over 15 sec.\r\n\r\nAwards 1 combo point." end return orig(id) end end)(C_Spell.GetSpellDescription)
step("Rake with secret attack power", function() cast(1822); H.update(0.2) end)
local rakeBy = {}
for _, e in ipairs(ns.dotBreakdownForUnit("target")) do rakeBy[e.name] = math.floor(e.damage + 0.5) end
check("Rake tracked on Forever: 57", rakeBy["Rake"], 57)
-- White hits (Physical too) landing just before each tick must not pull the bleed's timing earlier: after four
-- early hits the last tick is still to come
local bleedMob = "Creature-0-0000-0-0000-8888-0000AB0008"
targetGuid = bleedMob; H.fire("PLAYER_TARGET_CHANGED")
step("Rake on a new mob", function() cast(1822) end)
step("white hits landing a little earlier each tick", function()
    -- at 2.8, 5.6, 8.4, 11.2s: each within the window, each 0.2s earlier than the last one's rhythm
    H.update(2.8); H.fire("UNIT_COMBAT", "target", "WOUND", "", secret(9), 1)
    for _ = 1, 3 do H.update(2.8); H.fire("UNIT_COMBAT", "target", "WOUND", "", secret(9), 1) end
end)
H.update(3.0) -- 14.2s after the cast: tick 5 lands at 15s
local lastBy = {}
for _, e in ipairs(ns.dotBreakdownForUnit("target")) do lastBy[e.name] = e.damage end
check("bleed timing kept: last tick still to come", lastBy["Rake"] ~= nil and lastBy["Rake"] > 0, true)
-- Damage meter learning: Corruption (40 over 12s, 10 per tick by its tooltip) ticks 4 times with hidden amounts;
-- after combat the meter says it really did 64 in all, so 16 per tick is learned
local meterMob = "Creature-0-0000-0-0000-9999-0000AB0009"
targetGuid = meterMob; H.fire("PLAYER_TARGET_CHANGED")
H.fire("PLAYER_REGEN_ENABLED") -- the earlier fights end here (their tally is set aside)
combat = true
step("Corruption in combat, 4 hidden ticks", function()
    cast(172)
    for _ = 1, 4 do H.update(3); H.fire("UNIT_COMBAT", "target", "WOUND", "", secret(16), 32) end
end)
combat = false
local meterTotal = nil -- hidden at first, then readable
C_DamageMeter = { GetCombatSessionSourceFromType = function()
    if not meterTotal then return nil end
    return { combatSpells = { { spellID = 172, totalAmount = meterTotal } } }
end }
Enum = Enum or {}
local timers = {}
local realAfter = C_Timer.After
C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
local function runTimers() local due = timers; timers = {}; for _, fn in ipairs(due) do fn() end end
step("combat ends", function() H.fire("PLAYER_REGEN_ENABLED") end)
step("meter hidden at first, readable a moment later", function() runTimers(); meterTotal = 64; runTimers() end)
C_Timer.After = realAfter
check("real Corruption tick learned from the damage meter: 16", DoesItDieAdvancedDB.ticks[172], 16)
-- A tick the addon didn't pick out (the 2nd) still counts toward the meter's 64: 4 ticks of 16, not 3 of 21
targetGuid = "Creature-0-0000-0-0000-9999-0000AB0019"; H.fire("PLAYER_TARGET_CHANGED")
combat = true
step("Corruption again, its 2nd hidden tick not picked out", function()
    cast(172)
    for i = 1, 4 do H.update(3); if i ~= 2 then H.fire("UNIT_COMBAT", "target", "WOUND", "", secret(16), 32) end end
end)
combat = false
C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
step("combat ends, meter says 64", function() H.fire("PLAYER_REGEN_ENABLED"); meterTotal = 64; runTimers(); runTimers() end)
C_Timer.After = realAfter
check("missed tick doesn't inflate the learned size: still 16", DoesItDieAdvancedDB.ticks[172], 16)
-- Ticks can crit on Forever: with 10% shadow crit the meter's 4 ticks come to 67.2; the normal tick (16) is learned
targetGuid = "Creature-0-0000-0-0000-9999-0000AB0029"; H.fire("PLAYER_TARGET_CHANGED")
combat = true
step("Corruption again, one tick crits", function()
    cast(172)
    for _ = 1, 4 do H.update(3); H.fire("UNIT_COMBAT", "target", "WOUND", "", secret(16), 32) end
end)
combat = false
GetSpellCritChance = function(index) return index == 6 and 10 or 0 end
C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
step("combat ends, meter says 67.2", function() H.fire("PLAYER_REGEN_ENABLED"); meterTotal = 67.2; runTimers(); runTimers() end)
C_Timer.After = realAfter
GetSpellCritChance = nil
check("crits taken out of the learned size: still 16", DoesItDieAdvancedDB.ticks[172], 16)
-- Bane of Agony: the base ramps (0.5x early), spell power is the same on every tick. Tooltip 725 over 24s (60.4 a
-- tick); bonus 20 a tick, so early ticks are 30.2 + 20. A mob that dies after 4 ticks: the average is 80.4, not 100
C_Spell.GetSpellName = (function(orig) return function(id) if id == 1014 then return "Bane of Agony" end return orig(id) end end)(C_Spell.GetSpellName)
C_Spell.GetSpellDescription = (function(orig) return function(id) if id == 1014 then return "Banes the target with agony, causing 725 Shadow damage over 24 sec.  This damage is dealt slowly at first, and builds up as the Bane reaches its full duration." end return orig(id) end end)(C_Spell.GetSpellDescription)
targetGuid = "Creature-0-0000-0-0000-9999-0000AB0039"; H.fire("PLAYER_TARGET_CHANGED")
combat = true
step("Bane of Agony, 4 early ticks then the mob dies", function()
    cast(1014)
    for _ = 1, 4 do H.update(2); H.fire("UNIT_COMBAT", "target", "WOUND", "", secret(50), 32) end
end)
combat = false
C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
step("combat ends, meter says 200.8", function()
    H.fire("PLAYER_REGEN_ENABLED")
    C_DamageMeter.GetCombatSessionSourceFromType = function()
        return { combatSpells = { { spellID = 1014, totalAmount = 200.8 } } }
    end
    runTimers(); runTimers()
end)
C_Timer.After = realAfter
check("Bane of Agony learns its average (60.4 + 20), not the early ramp scaled up", DoesItDieAdvancedDB.ticks[1014], 80.4)
-- The pet's melee miss right after a cast makes it doubtful; it really missed (no first tick), the recast landed:
-- the miss doesn't stop learning (Rost4Love's log: "LEARN skipped: a cast showed no ticks")
targetGuid = "Creature-0-0000-0-0000-9999-0000AB0049"; H.fire("PLAYER_TARGET_CHANGED")
combat = true
step("Corruption missed (a melee miss at the same moment), recast, 4 ticks", function()
    cast(172); H.fire("UNIT_COMBAT", "target", "MISS", "", 0, 1)
    H.update(2); H.update(2) -- its first tick was due at 3s and didn't come
    cast(172)
    for _ = 1, 4 do H.update(3); H.fire("UNIT_COMBAT", "target", "WOUND", "", secret(16), 32) end
end)
combat = false
local learnedBefore = DoesItDieAdvancedDB.tickWeights[172]
C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
step("combat ends, meter says 64", function()
    H.fire("PLAYER_REGEN_ENABLED")
    C_DamageMeter.GetCombatSessionSourceFromType = function()
        return { combatSpells = { { spellID = 172, totalAmount = 64 } } }
    end
    runTimers(); runTimers()
end)
C_Timer.After = realAfter
check("a cast that missed doesn't stop learning", DoesItDieAdvancedDB.tickWeights[172] > learnedBefore, true)
check("and the size is still 16", DoesItDieAdvancedDB.ticks[172], 16)
targetGuid = "Creature-0-0000-0-0000-9999-0000AB0010"; H.fire("PLAYER_TARGET_CHANGED")
step("next Corruption", function() cast(172) end)
local nextBy = {}
for _, e in ipairs(ns.dotBreakdownForUnit("target")) do nextBy[e.name] = math.floor(e.damage + 0.5) end
check("next Corruption uses the learned size: 4 x 16", nextBy["Corruption"], 64)
-- Forever's Curse of the Elements (rank 1: 4% on all Magic damage), cast after the DoT: auras are hidden, the cast counts
C_Spell.GetSpellName = (function(orig) return function(id) if id == 1490 then return "Curse of the Elements" end return orig(id) end end)(C_Spell.GetSpellName)
C_Spell.GetSpellDescription = (function(orig) return function(id) if id == 1490 then return "Curses the target for 5 min, reducing Magic resistances by 30 and increases Magic damage taken by 4%.  Only one Curse per Warlock can be active on any one target." end return orig(id) end end)(C_Spell.GetSpellDescription)
step("cast Curse of the Elements rank 1", function() cast(1490) end)
nextBy = {}
for _, e in ipairs(ns.dotBreakdownForUnit("target")) do nextBy[e.name] = math.floor(e.damage + 0.5) end
check("Forever CoE rank 1 (4%, Magic) raises Corruption: 64 x 1.04", nextBy["Corruption"], 67)
step("nameplates and focus refresh with secret health", function() for _ = 1, 15 do H.update(0.1) end end)
step("/did plates", function() SlashCmdList.DOESITDIEADVANCED("plates") end)
step("/did accuracy", function() SlashCmdList.DOESITDIEADVANCED("accuracy") end)

-- v1.2.4: other addons' health text is on by default on Forever again
check("other addons' health text on by default on Forever", DoesItDieAdvancedDB.markerUnderTextAddons, true)

-- v1.2.0: Russian, Chinese and Portuguese tooltips (JoeGG's locale files)
local function parsed(desc) local t, school, d = ns.parseDot(desc, 5); return tostring(t) .. "/" .. tostring(school) .. "/" .. tostring(d) end
check("Russian Corruption", parsed("Поражает цель порчей, нанося 40 ед. урона от темной магии за 12 сек."), "40/32/12")
check("Russian Rip 5 points", parsed("Завершающий прием. 1 прием: 44 ед. урона за 12 сек. 5 приемов: 189 ед. урона за 12 сек."), "189/1/12")
check("Chinese Corruption", parsed("使目标受到腐蚀，在12秒内造成总计40点暗影伤害。"), "40/32/12")
check("Portuguese Immolate", parsed("Queima o inimigo causando 11 de dano de Fogo e mais 20 de dano de Fogo ao longo de 15 s."), "20/4/15")

-- v1.2.0: with the last kill's corpse still targeted, a cast goes to the next mob (the soft enemy)
local corpse, nextMob = targetGuid, "Creature-0-0000-0-0000-9999-0000AB0011"
local realGUID, realDead, realName = UnitGUID, UnitIsDeadOrGhost, UnitName
UnitGUID = function(unit) if unit == "softenemy" then return nextMob end return realGUID(unit) end
UnitIsDeadOrGhost = function(unit) return unit == "target" end
UnitName = function(unit) if unit == "target" or unit == "softenemy" then return "Mob" end end
step("cast Corruption with a corpse targeted", function() cast(172) end)
local onNext = 0
for _, e in ipairs(ns.dotBreakdownForUnit("softenemy")) do if e.name == "Corruption" then onNext = onNext + 1 end end
check("corpse targeted: Corruption goes on the next mob", onNext, 1)
UnitGUID, UnitIsDeadOrGhost, UnitName = realGUID, realDead, realName

if os.getenv("SHOWLOG") then for _, l in ipairs(db.log) do print("LOG: " .. l) end end
print(string.format("\n%d passed, %d failed", passes, failures))
local errs = 0
check("no display or update errors logged", (function() for _, l in ipairs(db.log) do if l:find("ERROR") or l:find("failed") then return false end end return true end)(), true)
for _, l in ipairs(db.log) do if l:find("ERROR") or l:find("failed") then errs = errs + 1; print("LOG: " .. l) end end
if failures > 0 then os.exit(1) end
