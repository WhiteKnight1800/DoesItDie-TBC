-- Enemy players' real health (TBC port).
-- The TBC client only tells addons a percentage (0-100) for players outside your group, so a DoT marker scaled to
-- "100 health" covered the whole bar after a single DoT. Their real maximum is worked out from the damage they take:
-- every damage and healing event on them is counted from the combat log (from all sources, not just yours) and
-- compared with how far their health percentage moved. 1,200 damage taking them from 80% to 70% means about 12,000
-- health. Until enough has been seen, the marker and kill icon stay hidden on that player rather than lie.
-- Estimates are remembered per player name, so the next fight with the same player starts with a size straight away.

local _, ns = ...

local MIN_MOVE = 8            -- percentage points of movement before an estimate is trusted (integer percents)
local ANCHOR_SECONDS = 30     -- measure over at most this long: natural regeneration isn't in the combat log
local FORGET_SECONDS = 300    -- drop a player's running totals after this long without events
local MIN_HEALTH, MAX_HEALTH = 200, 60000 -- plausible TBC player and pet health
local CACHE_SIZE = 300
-- Hit by hit: each change in percentage is paired with the damage or healing logged since the last one. This measures
-- players whose health goes up and down without ever dropping MIN_MOVE overall (healed in a group, or a mage refreshing
-- Ice Barrier and Mana Shield). Small steps round to whole percents, so more of them are needed first.
local GROSS_MIN = 12          -- percentage points of hit-by-hit movement before that estimate is used
local PAIR_SECONDS = 2        -- a percentage change and its combat log event arrive within this of each other

local trackers = {}           -- guid -> { net, anchorNet, anchorPct, anchorAt, lastPct, est, seenAt, name }

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

local function tracked(guid)
    return type(guid) == "string" and not isSecret(guid) and guid:find("^Player%-") ~= nil
end

local function trackerFor(guid)
    local t = trackers[guid]
    if not t then
        t = { net = 0 }
        trackers[guid] = t
    end
    t.seenAt = GetTime()
    return t
end

-- Whether the client only reports a percentage for this unit: another player (or a player's pet) outside your group.
local function percentOnly(unit)
    local okC, controlled = pcall(UnitPlayerControlled, unit)
    if not okC or not controlled or isSecret(controlled) then return false end
    local okP, isMe = pcall(UnitIsUnit, unit, "player")
    if okP and isMe then return false end
    local okG, inGroup = pcall(function() return UnitInParty(unit) or UnitInRaid(unit) end)
    if okG and inGroup then return false end
    local okM, maxHealth = pcall(UnitHealthMax, unit)
    return okM and maxHealth == 100
end

local function cacheKey(unit)
    local ok, name, realm = pcall(UnitName, unit)
    if not ok or type(name) ~= "string" or isSecret(name) or name == "" then return nil end
    if type(realm) == "string" and realm ~= "" then name = name .. "-" .. realm end
    return name
end

local function remember(name, est)
    local db = ns.db
    if not db or not name then return end
    db.playerHealth = db.playerHealth or {}
    db.playerHealth[name] = { est = math.floor(est + 0.5), at = time and time() or 0 }
    local count, oldestName, oldestAt = 0, nil, math.huge
    for n, entry in pairs(db.playerHealth) do
        count = count + 1
        if (entry.at or 0) < oldestAt then oldestName, oldestAt = n, entry.at or 0 end
    end
    if count > CACHE_SIZE and oldestName then db.playerHealth[oldestName] = nil end
end

-- Compare the player's current percentage with the damage counted since the anchor, and update the estimate.
-- Each measuring window (at most ANCHOR_SECONDS) gives an estimate weighted by how far the percentage moved (wider
-- spans are more precise with whole-number percents); windows are blended, older ones capped so new data still counts.
local function startWindow(t, pct, now)
    t.anchorNet, t.anchorPct, t.anchorAt = t.net, pct, now
    t.baseEst, t.baseSpan = t.est, math.min(t.span or 0, 60)
    t.winSpan = 0
end

-- Pairs the percentage change since the last match with the damage or healing logged since then (see GROSS_MIN).
-- The health update and its combat log event can arrive in either order, so one side waits for the other briefly.
local function pairStep(t, pct, now)
    if not t.matchPct then t.matchPct, t.pendNet, t.matchAt = pct, 0, now return end
    local dp, dn = t.matchPct - pct, t.pendNet or 0
    if dp ~= 0 and dn ~= 0 then
        local est = dn / dp * 100
        if (dp > 0) == (dn > 0) and est >= MIN_HEALTH and est <= MAX_HEALTH then
            t.grossNet = (t.grossNet or 0) + math.abs(dn)
            t.grossPct = (t.grossPct or 0) + math.abs(dp)
        end
        t.matchPct, t.pendNet, t.matchAt = pct, 0, now
    elseif (dp ~= 0 or dn ~= 0) and now - (t.matchAt or now) > PAIR_SECONDS then
        -- Only one side moved (regeneration, an event out of range): start again from here.
        t.matchPct, t.pendNet, t.matchAt = pct, 0, now
    elseif dp == 0 and dn == 0 then
        t.matchAt = now
    end
    if not t.est and (t.grossPct or 0) >= GROSS_MIN then
        t.est = t.grossNet / t.grossPct * 100
        t.span = t.grossPct
        remember(t.name, t.est)
        if ns.trace then ns.trace(string.format("PLAYER health of %s estimated at %d (hit by hit, %d dealt over %d%%)",
            tostring(t.name), t.est, t.grossNet, t.grossPct)) end
    end
end

local function sample(unit, guid)
    local okH, pct = pcall(UnitHealth, unit)
    if not okH or type(pct) ~= "number" or isSecret(pct) then return end
    local t = trackerFor(guid)
    t.name = t.name or cacheKey(unit)
    local now = GetTime()
    pairStep(t, pct, now)
    if not t.anchorPct or now - t.anchorAt > ANCHOR_SECONDS or pct <= 0 then return startWindow(t, pct, now) end
    local moved, dealt = t.anchorPct - pct, t.net - t.anchorNet
    local span = math.abs(moved)
    if span < MIN_MOVE or span <= (t.winSpan or 0) or dealt == 0 or (moved > 0) ~= (dealt > 0) then return end
    local est = dealt / moved * 100
    if est < MIN_HEALTH or est > MAX_HEALTH then return startWindow(t, pct, now) end -- didn't add up (a missed heal?)
    t.winSpan = span
    local baseEst, baseSpan = t.baseEst, t.baseSpan or 0
    if baseEst and baseSpan > 0 then
        t.est = (baseEst * baseSpan + est * span) / (baseSpan + span)
    else
        t.est = est
    end
    t.span = baseSpan + span
    remember(t.name, t.est)
    if ns.trace then ns.trace(string.format("PLAYER health of %s estimated at %d (%d dealt over %d%%)",
        tostring(t.name or guid), t.est, dealt, moved)) end
end

-- Health and maximum health of `unit` in real hit points, or nil when it isn't known yet (an enemy player whose
-- size hasn't been measured). For everything else this is just UnitHealth/UnitHealthMax.
function ns.realHealth(unit)
    if not percentOnly(unit) then return UnitHealth(unit), UnitHealthMax(unit) end
    if ns.db and ns.db.showOnPlayers == false then return nil end -- "Show on enemy players" is off: draw nothing
    local okG, guid = pcall(UnitGUID, unit)
    if not okG or not tracked(guid) then return nil end
    sample(unit, guid)
    local t = trackers[guid]
    local est = t and t.est
    if not est then
        local name = cacheKey(unit)
        local cached = name and ns.db and ns.db.playerHealth and ns.db.playerHealth[name]
        est = cached and cached.est
    end
    if not est then
        -- Say once per player per session that it's measuring, so an empty bar doesn't look like a fault.
        local who = cacheKey(unit) or guid
        if unit == "target" and ns.print and t and not t.told then
            t.told = true
            ns.print(string.format("measuring %s's health. The marker shows once they've lost a little health "
                .. "(/did pvp turns this off).", tostring(who)))
        end
        return nil
    end
    local pct = UnitHealth(unit)
    return pct / 100 * est, est
end

-- Shields and immunities on a unit: damage goes into them before health, and the client doesn't say how much is left,
-- so while one is up the kill icon is hidden (the marker still shows). Names come from the client by spell ID, so they
-- match in every language; the English names are a fallback.
local SHIELD_SPELLS = {
    17,    -- Power Word: Shield
    11426, -- Ice Barrier
    1463,  -- Mana Shield
    7812,  -- Sacrifice (Voidwalker)
    543,   -- Fire Ward
    6143,  -- Frost Ward
    6229,  -- Shadow Ward
    642,   -- Divine Shield
    498,   -- Divine Protection
    1022,  -- Blessing of Protection
    45438, -- Ice Block (TBC)
    11958, -- Ice Block (Classic Era)
}
local SHIELD_NAMES = { ["Power Word: Shield"] = true, ["Ice Barrier"] = true, ["Mana Shield"] = true,
    ["Sacrifice"] = true, ["Fire Ward"] = true, ["Frost Ward"] = true, ["Shadow Ward"] = true,
    ["Divine Shield"] = true, ["Divine Protection"] = true, ["Blessing of Protection"] = true, ["Ice Block"] = true }
local namesFilled = false
local function fillShieldNames()
    if namesFilled then return end
    namesFilled = true
    for _, id in ipairs(SHIELD_SPELLS) do
        local ok, name = pcall(function()
            if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
            return GetSpellInfo and GetSpellInfo(id)
        end)
        if ok and type(name) == "string" and name ~= "" and not isSecret(name) then SHIELD_NAMES[name] = true end
    end
end

local function buffName(unit, i)
    if UnitBuff then
        local ok, name = pcall(UnitBuff, unit, i)
        if ok then return name end
    end
    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
        local ok, data = pcall(C_UnitAuras.GetBuffDataByIndex, unit, i)
        if ok and type(data) == "table" then return data.name end
    end
end

function ns.shielded(unit)
    fillShieldNames()
    for i = 1, 40 do
        local name = buffName(unit, i)
        if name == nil then return false end
        if type(name) == "string" and not isSecret(name) and SHIELD_NAMES[name] then return true, name end
    end
    return false
end

-- Whether `unit` is an enemy player whose size is still being measured (for the trace log and /did help).
function ns.healthUnknown(unit)
    return percentOnly(unit) and select(2, ns.realHealth(unit)) == nil
end

local DAMAGE_AT_15 = { SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = true, DAMAGE_SHIELD = true,
    DAMAGE_SPLIT = true, SPELL_BUILDING_DAMAGE = true }
local HEAL = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }
local LEECH = { SPELL_LEECH = true, SPELL_PERIODIC_LEECH = true, SPELL_DRAIN = true, SPELL_PERIODIC_DRAIN = true }

local frame = CreateFrame("Frame")
if type(CombatLogGetCurrentEventInfo) == "function" then
    pcall(frame.RegisterEvent, frame, "COMBAT_LOG_EVENT_UNFILTERED")
end
frame:RegisterEvent("UNIT_HEALTH")
pcall(frame.RegisterEvent, frame, "UNIT_HEALTH_FREQUENT") -- older clients only
frame:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" then
        if type(unit) == "string" and percentOnly(unit) then
            local okG, guid = pcall(UnitGUID, unit)
            if okG and tracked(guid) then sample(unit, guid) end
        end
        return
    end
    local _, sub, _, _, _, _, _, destGUID, _, _, _, a12, a13, _, a15, a16 = CombatLogGetCurrentEventInfo()
    if not tracked(destGUID) then return end
    local amount
    if sub == "SWING_DAMAGE" then amount = a12
    elseif sub == "ENVIRONMENTAL_DAMAGE" then amount = a13
    elseif DAMAGE_AT_15[sub] then amount = a15
    elseif HEAL[sub] then amount = -((tonumber(a15) or 0) - (tonumber(a16) or 0))
    elseif LEECH[sub] and tonumber(a16) == -2 then amount = a15 -- health drained (power type -2 is health)
    elseif sub == "UNIT_DIED" then trackers[destGUID] = nil return
    else return end
    if type(amount) ~= "number" or amount == 0 then return end
    local t = trackerFor(destGUID)
    t.net = t.net + amount
    t.pendNet = (t.pendNet or 0) + amount
end)

-- Forget players not seen for a while.
local sincePrune = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    sincePrune = sincePrune + elapsed
    if sincePrune < 30 then return end
    sincePrune = 0
    local now = GetTime()
    for guid, t in pairs(trackers) do
        if now - (t.seenAt or 0) > FORGET_SECONDS then trackers[guid] = nil end
    end
end)
