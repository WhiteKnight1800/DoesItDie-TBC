-- DoesItDie nameplates: the damage marker (and optionally the kill icon) on every enemy nameplate that has your
-- DoTs on it, using the per-mob tracking in DoesItDie.lua (ns.dotBreakdownForUnit). Same secret-value trick as
-- the target frame: StatusBars are fed the mob's hidden health and do the comparing.
--
-- Widgets are created per Blizzard nameplate frame (which WoW recycles between mobs) and parented to it, so
-- they move, scale and hide with the plate. With EllesmereUI's nameplates they go on its own plate frame instead,
-- and with Platynator's they anchor to its health bar (see findHealthBar). They're lighter than the target marker: fill, per-DoT segments and a thin outline in the
-- Marker tab's style; no glow, shine, spark or animation.
--
-- Also the probe (/did plates): what the addon can reach on nameplates, logged, with a test bar on each.

local ADDON_NAME, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local MAX_PLATES = 40
local UPDATE_INTERVAL = 0.1
local MAX_SEGMENTS = 4
local OUTLINE_THICKNESS = 1
local ICON_BAR_LENGTH = 10000 -- see the kill icon notes in DoesItDie.lua
local FALLBACK_LEVEL = 200    -- frame level when the plate's own level can't be read
local TEST_SECONDS = 8
local TEST_BAR_WIDTH, TEST_BAR_HEIGHT = 90, 6

ns.lists.nameplateModes = {
    { id = "off",        label = "Off" },
    { id = "marker",     label = "Marker only" },
    { id = "markerIcon", label = "Marker and kill icon" },
}
ns.lists.nameplateIconPositions = {
    { id = "right", label = "Right of the health bar" },
    { id = "left",  label = "Left of the health bar" },
    { id = "above", label = "Above the health bar" },
}

local testBars = {}
local hideTestBarsAt = 0

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- "secret", "nil", "error: ...", or the value.
local function describe(ok, value)
    if not ok then return "error: " .. tostring(value) end
    if value == nil then return "nil" end
    if isSecret(value) then return "secret" end
    return tostring(value)
end

local function call(fn, ...)
    if type(fn) ~= "function" then return "missing" end
    return describe(pcall(fn, ...))
end

-- Platynator hides Blizzard's UnitFrame and draws its own display frames (40 per style, preallocated),
-- parented to "NamePlate<i>" or, when that doesn't exist yet at creation (as in Forever), to UIParent. The
-- active one for a unit is shown with .unit = the nameplate unit token; its .widgets list holds the health
-- widget (details.kind == "health") with the real StatusBar in .statusBar. Displays are found by scanning
-- UIParent's and the plate's children, cached, and rescanned (throttled) when a unit has none.
local platyDisplays = {}
local platyLastScan = -math.huge
local PLATY_RESCAN_INTERVAL = 2

local function isPlatyDisplay(frame)
    return type(frame.widgets) == "table" and type(frame.Install) == "function" and type(frame.SetUnit) == "function"
end

local function scanPlatyDisplays(plate)
    for _, parent in ipairs({ UIParent, plate }) do
        for _, child in ipairs({ parent:GetChildren() }) do
            if not platyDisplays[child] and isPlatyDisplay(child) then platyDisplays[child] = true end
        end
    end
end

local function platyBarFor(unit)
    for display in pairs(platyDisplays) do
        if display.unit == unit and display:IsShown() and type(display.widgets) == "table" then
            for _, widget in ipairs(display.widgets) do
                if type(widget.details) == "table" and widget.details.kind == "health" and widget.statusBar then
                    return widget.statusBar
                end
            end
        end
    end
end

local function findPlatynatorBar(plate, unit)
    if not (Platynator and unit) then return nil end
    local bar = platyBarFor(unit)
    if bar then return bar end
    local now = GetTime()
    if now - platyLastScan < PLATY_RESCAN_INTERVAL then return nil end
    platyLastScan = now
    scanPlatyDisplays(plate)
    return platyBarFor(unit)
end

-- False only when the bar is known to be hidden or fully transparent, e.g. a plate addon took over and parked or
-- faded out Blizzard's: the marker would otherwise draw over nothing.
local function barShown(bar)
    local ok, visible = pcall(bar.IsVisible, bar)
    if ok and not isSecret(visible) and visible == false then return false end
    local okAlpha, alpha = pcall(bar.GetEffectiveAlpha, bar)
    if okAlpha and type(alpha) == "number" and not isSecret(alpha) and alpha <= 0 then return false end
    return true
end

local function isStatusBar(value)
    if type(value) ~= "table" or type(value.GetObjectType) ~= "function" then return false end
    local ok, kind = pcall(value.GetObjectType, value)
    return ok and kind == "StatusBar"
end

local function forbidden(frame)
    local ok, result = pcall(function() return frame.IsForbidden and frame:IsForbidden() end)
    return not ok or result == true
end

-- The Advanced tab's "Nameplate health bar": keys from the Blizzard nameplate, e.g. "unitFrame.healthBar".
local function resolveFromPlate(plate, path)
    local current = plate
    for key in string.gmatch(path, "[^%.]+") do
        local ok, value = pcall(function() return current[key] end)
        if not ok or type(value) ~= "table" then return nil end
        current = value
    end
    if current ~= plate and isStatusBar(current) then return current end
end

-- Automatic search for a nameplate addon's health bar (Plater, KUI, ...): they hang their own frames on Blizzard's
-- nameplate and keep the bar in a field named like "health" (healthBar, health, HealthBar). Breadth-first through
-- the plate's frames (not Blizzard's UnitFrame), the first shown StatusBar under such a key wins. Returns the bar
-- and where it was found ("unitFrame.healthBar"). Reading every field of a frame is slow, so each plate's result
-- is kept (searchCache) and only searched again, at most once a second, when it's gone or hidden.
local SEARCH_DEPTH = 4
local NEATPLATES_HEIGHT = 8 -- marker height that fits NeatPlates' default bar
local SEARCH_INTERVAL = 1
local searchCache = {} -- plate -> { bar, path, at }

-- Whether `frame` sits inside `plate` (fields can point anywhere: a frame's back-reference to UIParent would
-- otherwise lead the search to some other "health" bar).
local function isUnder(frame, plate)
    local current = frame
    for _ = 1, 12 do
        local ok, parent = pcall(current.GetParent, current)
        if not ok or parent == nil then return false end
        if parent == plate then return true end
        current = parent
    end
    return false
end

-- A plain Lua table (an addon's own bookkeeping, like Threat Plates' TPFrame.visual), as opposed to a frame.
local MAX_TABLE_ENTRIES = 200 -- bigger plain tables are settings or caches, not where a plate keeps its bar
local function isFrame(value)
    local ok, kind = pcall(function() return value:GetObjectType() end)
    return ok and type(kind) == "string"
end

-- The string-keyed table fields of `container`, sorted (the same answer every time). Nil if it can't be read, or
-- for a plain table that's too big.
local function tableFields(container, plain)
    local ok, fields = pcall(function()
        local found, count = {}, 0
        for key, value in pairs(container) do
            count = count + 1
            if plain and count > MAX_TABLE_ENTRIES then return nil end
            if type(key) == "string" and type(value) == "table" then table.insert(found, { key, value }) end
        end
        return found
    end)
    if not ok or not fields then return nil end
    table.sort(fields, function(a, b) return a[1] < b[1] end)
    return fields
end

-- Each field is checked under its own pcall: plate addons build frames with frameworks whose objects may error
-- when read (an __index that throws), and one such field mustn't stop the whole search.
local function searchHealthBar(plate)
    local blizzardBar = plate.UnitFrame and plate.UnitFrame.healthBar
    local queue = { { node = plate, path = "", depth = 0, plain = false } }
    local seen = { [plate] = true }
    local head = 1
    while queue[head] do
        local item = queue[head]
        head = head + 1
        local fields = tableFields(item.node, item.plain)
        if fields then
            -- A shown StatusBar under a "health" key, inside the plate, is the answer.
            for _, field in ipairs(fields) do
                local key, value = field[1], field[2]
                local ok, found = pcall(function()
                    return key:lower():find("health", 1, true) and value ~= blizzardBar and isStatusBar(value)
                        and not forbidden(value) and isUnder(value, plate) and barShown(value)
                end)
                if ok and found then return value, item.path .. key end
            end
            -- Else go one level deeper: frames inside the plate (not Blizzard's UnitFrame), and plain tables.
            if item.depth < SEARCH_DEPTH then
                for _, field in ipairs(fields) do
                    local key, value = field[1], field[2]
                    if not seen[value] and value ~= plate.UnitFrame then
                        seen[value] = true
                        local frame = isFrame(value)
                        local ok, visit = pcall(function()
                            if frame then return not isStatusBar(value) and not forbidden(value) and isUnder(value, plate) end
                            return true
                        end)
                        if ok and visit then
                            table.insert(queue, { node = value, path = item.path .. key .. ".", depth = item.depth + 1,
                                plain = not frame })
                        end
                    end
                end
            end
        end
    end
end

-- TBC: the mob's health is readable (Forever hides it), so any plate addon's bar can be recognised by what it shows:
-- a shown, wide StatusBar inside the plate whose max is the mob's max health and whose value is its health (or a
-- 0-100 percent bar showing its percent). Found through GetChildren, so it doesn't matter what the addon calls it
-- or whether it keeps it in a field at all. Blizzard's own (hidden) bar is skipped.
local MATCH_DEPTH = 5

local function healthMatches(bar, unit)
    local okM, _, high = pcall(bar.GetMinMaxValues, bar)
    local okV, value = pcall(bar.GetValue, bar)
    local okH, health = pcall(UnitHealth, unit)
    local okX, maxHealth = pcall(UnitHealthMax, unit)
    if not (okM and okV and okH and okX) then return false end
    for _, v in ipairs({ high, value, health, maxHealth }) do
        if type(v) ~= "number" or isSecret(v) then return false end
    end
    if maxHealth <= 0 or high <= 0 then return false end
    local okW, width = pcall(bar.GetWidth, bar)
    local okHt, height = pcall(bar.GetHeight, bar)
    if okW and okHt and type(width) == "number" and type(height) == "number" and width < height * 2 then
        return false -- a vertical or square bar isn't a nameplate's health bar
    end
    if math.abs(high - maxHealth) <= 1 then
        return math.abs(value - health) <= math.max(1, maxHealth * 0.02)
    end
    if high == 100 then
        return math.abs(value - health / maxHealth * 100) <= 2
    end
    return false
end

local function matchHealthBar(plate, unit)
    if type(unit) ~= "string" then return nil end
    local unitFrame = rawget(plate, "UnitFrame")
    local blizzardBar = type(unitFrame) == "table" and rawget(unitFrame, "healthBar") or nil
    local best, bestWidth
    local function visit(frame, depth, path)
        local ok, children = pcall(function() return { frame:GetChildren() } end)
        if not ok then return end
        for i, child in ipairs(children) do
            local name
            local okN, n = pcall(child.GetName, child)
            name = okN and type(n) == "string" and n or ("child" .. i)
            local childPath = path .. name
            if child ~= blizzardBar and not forbidden(child) then
                if isStatusBar(child) then
                    if barShown(child) and healthMatches(child, unit) then
                        local okW, width = pcall(child.GetWidth, child)
                        width = okW and type(width) == "number" and width or 0
                        if not best or width > bestWidth then best, bestWidth = { child, childPath }, width end
                    end
                elseif depth < MATCH_DEPTH then
                    visit(child, depth + 1, childPath .. ".")
                end
            end
        end
    end
    visit(plate, 1, "")
    if best then return best[1], best[2] end
end

-- Plate addons that keep their frame outside the Blizzard plate (NeatPlates Community Edition, Tidy Plates, Plater
-- on UIParent) still link it from the plate in a field. Follow the plate's own frame fields, wherever those frames
-- sit, and find the bar showing the mob's health: on the frame, in its fields (and plain tables of them, like
-- .bars), or among its children. The world and UI root frames are never searched.
local function linkedHealthBar(plate, unit)
    if type(unit) ~= "string" then return nil end
    local okP, plateParent = pcall(plate.GetParent, plate)
    local skip = { [UIParent or false] = true, [WorldFrame or false] = true, [plate.UnitFrame or false] = true }
    if okP and plateParent then skip[plateParent] = true end
    local roots = tableFields(plate, false) or {}
    local function candidate(bar)
        return isStatusBar(bar) and not forbidden(bar) and bar ~= (plate.UnitFrame and plate.UnitFrame.healthBar)
            and barShown(bar) and healthMatches(bar, unit)
    end
    for _, field in ipairs(roots) do
        local key, root = field[1], field[2]
        if not skip[root] and isFrame(root) and not forbidden(root) then
            local okC, isBar = pcall(candidate, root)
            if okC and isBar then return root, key end
            for _, sub in ipairs(tableFields(root, false) or {}) do
                local subKey, value = sub[1], sub[2]
                if not skip[value] then
                    local okS, hit = pcall(candidate, value)
                    if okS and hit then return value, key .. "." .. subKey end
                    if not isFrame(value) then
                        for _, inner in ipairs(tableFields(value, true) or {}) do
                            local okI, hitI = pcall(candidate, inner[2])
                            if okI and hitI then return inner[2], key .. "." .. subKey .. "." .. inner[1] end
                        end
                    end
                end
            end
            local okM, matched, path = pcall(matchHealthBar, root, unit)
            if okM and matched then return matched, key .. "." .. tostring(path) end
        end
    end
end

local function autoHealthBar(plate, unit)
    local cached = searchCache[plate]
    local now = GetTime()
    if cached and cached.bar and barShown(cached.bar) then return cached.bar, cached.path end
    -- Nothing found last time (a plate addon we can't read): search that plate less often, it's the costly part.
    if cached and now - cached.at < (cached.bar and SEARCH_INTERVAL or SEARCH_INTERVAL * 5) then return nil end
    local ok, bar, path = pcall(searchHealthBar, plate)
    if not ok then bar, path = nil, nil end
    if not bar then
        local okM, matched, matchedPath = pcall(matchHealthBar, plate, unit)
        if okM and matched then bar, path = matched, "matched by health: " .. tostring(matchedPath) end
    end
    if not bar then
        local okL, linked, linkedPath = pcall(linkedHealthBar, plate, unit)
        if okL and linked then bar, path = linked, "linked: " .. tostring(linkedPath) end
    end
    searchCache[plate] = { bar = bar, path = path, at = now }
    return bar, path
end

-- The health bar a nameplate shows, the frame our widgets go on, the path the bar was found under, and whether
-- it's a plate addon's bar (drawn in a strata of its own, which ours must match). In order:
--   * the Advanced tab's path from the plate, when set and shown
--   * EllesmereUI: it parks Blizzard's bar on a hidden frame and shows its own plate, a pooled frame parented to
--     the Blizzard plate while in use, listed by unit in its addon table, with the bar at .health. Our widgets go
--     on that frame so they fade, scale and hide with it.
--   * Platynator: its displays aren't tied to one plate (they're reassigned between units, and may hang off
--     UIParent), so our widgets stay on Blizzard's plate and only anchor to its bar.
--   * Blizzard's own bar, while it's shown
--   * the automatic search (searchHealthBar), for other plate addons
--   * Blizzard's bar, hidden: only the kill icon is drawn, beside the plate (iconOnly)
local function findHealthBar(plate, unit)
    local db = ns.db
    local custom = db and strtrim(db.customPlateHealthBar or "") or ""
    if custom ~= "" then
        local bar = resolveFromPlate(plate, custom)
        if bar and barShown(bar) then return bar, plate, "custom " .. custom, true end
    end
    local eui = EllesmereNameplates_NS
    local euiPlate = type(eui) == "table" and type(eui.plates) == "table" and eui.plates[unit]
    if type(euiPlate) == "table" and euiPlate.nameplate == plate and euiPlate.health then
        return euiPlate.health, euiPlate, "EllesmereUI plate.health", true
    end
    local ok, platyBar = pcall(findPlatynatorBar, plate, unit)
    if ok and platyBar then return platyBar, plate, "Platynator health widget", true end
    -- Plater: its own unit frame hangs off the Blizzard plate as .unitFrame (lowercase; Blizzard's is .UnitFrame),
    -- with the bar at .healthBar. With Plater's "use UIParent" option that frame is parented to UIParent, so no
    -- search inside the plate finds it. Our widgets go on Plater's unit frame: they take its strata, scale and
    -- alpha, and hide when Plater recycles it.
    local platerFrame = rawget(plate, "unitFrame")
    if type(platerFrame) == "table" and platerFrame ~= plate.UnitFrame then
        local okBar, platerBar = pcall(function() return platerFrame.healthBar end)
        if okBar and isStatusBar(platerBar) and not forbidden(platerBar) and barShown(platerBar) then
            return platerBar, platerFrame, (Plater and "Plater" or "plate.unitFrame") .. " healthBar", true
        end
    end

    -- NeatPlates / Tidy Plates: their plate frame hangs off the Blizzard plate as .extended (parented to a carrier
    -- frame on WorldFrame, so no search inside the plate finds it), with the bar at .bars.healthbar.
    local extended = rawget(plate, "extended")
    if type(extended) == "table" then
        local okBar, npBar = pcall(function()
            local bars = extended.bars
            return bars and (bars.healthbar or bars.health or bars.healthBar)
        end)
        -- Their bar is their own widget (a Frame with a .Bar texture and Lua SetValue), not a StatusBar: only its
        -- position and layer are used, so any frame will do.
        if okBar and npBar and isFrame(npBar) and not forbidden(npBar) and barShown(npBar) then
            local who = (NeatPlates and "NeatPlates") or (TidyPlates and "Tidy Plates") or "plate.extended"
            return npBar, extended, who .. " healthbar", true
        end
    end

    local unitFrame = plate.UnitFrame
    local blizzard, blizzardPath
    if unitFrame then
        local container = unitFrame.HealthBarsContainer
        if unitFrame.healthBar then
            blizzard, blizzardPath = unitFrame.healthBar, "UnitFrame.healthBar"
        elseif container and container.healthBar then
            blizzard, blizzardPath = container.healthBar, "UnitFrame.HealthBarsContainer.healthBar"
        elseif unitFrame.HealthBar then
            blizzard, blizzardPath = unitFrame.HealthBar, "UnitFrame.HealthBar"
        end
    end
    if blizzard and barShown(blizzard) then return blizzard, plate, blizzardPath, false end
    local found, path = autoHealthBar(plate, unit)
    if found then return found, plate, "auto " .. path, true end
    -- Nothing found and Blizzard's bar hidden: a plate addon we can't read. A marker on the hidden bar would float
    -- over nothing, but the kill icon beside the plate still says "this one dies" (as before v0.7.0): icon only.
    if blizzard then return blizzard, plate, blizzardPath .. " (hidden: kill icon only)", false, true end
    return nil, nil, unitFrame and "no health bar found" or "no UnitFrame"
end

-- What the last drawn nameplate's marker was on, for the options window.
local lastBarPath

function ns.plateBarStatus()
    if not lastBarPath then return "|cff888888none drawn yet|r" end
    if lastBarPath:find("^custom ") then return "|cff66ff66" .. lastBarPath:sub(8) .. "|r" end
    if lastBarPath:find("^auto ") then return "found: " .. lastBarPath:sub(6) end
    return lastBarPath
end

---------------------------------------------------------------------------
-- Nameplate display
---------------------------------------------------------------------------

local widgetsByHost = {} -- frame the widgets are parented to (Blizzard's or EllesmereUI's plate) -> our widgets

local function hideWidgets(w)
    w.marker:Hide()
    w.iconWindow:Hide()
end

local function coverSpan(texture, span)
    texture:SetPoint("TOPLEFT", span, "TOPLEFT")
    texture:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")
end

local function invisibleBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(0, 0, 0, 0)
    return bar
end

-- Anchors the widgets to a health bar and layers them above it. Its level/strata can be secret in Forever;
-- then use a fixed level. matchStrata: a plate addon's bar (EllesmereUI, Platynator), drawn in a strata of its
-- own (EllesmereUI flattens its plate's children into one render layer; frames that set a strata are drawn
-- apart from it, ordered by level; Platynator's bars are MEDIUM, above the plate's WORLD). Set before the
-- levels: a strata change resets them.
-- Layering is checked again on every update, not only when attaching: Plater moves a plate to another strata or
-- level when it changes (the target's plate is raised), and a marker layered once was left underneath its bar.
local function layerWidgets(w, healthBar, matchStrata)
    local strataOf = matchStrata and healthBar or w.host
    local okStrata, strata = pcall(strataOf.GetFrameStrata, strataOf)
    if w.strataFloor then okStrata, strata = true, w.strataFloor end -- Enemy Frames: the cell's highest strata
    if (matchStrata or w.strataSet) and okStrata and type(strata) == "string" and not isSecret(strata)
        and strata ~= w.appliedStrata then
        w.marker:SetFrameStrata(strata)
        w.iconWindow:SetFrameStrata(strata)
        w.iconBar:SetFrameStrata(strata)
        w.strataSet, w.appliedStrata, w.layerKey = true, strata, nil -- a strata change resets levels
    end
    local ok, level = pcall(healthBar.GetFrameLevel, healthBar)
    if not ok or isSecret(level) or type(level) ~= "number" then level = FALLBACK_LEVEL end
    -- levelFloor (Enemy Frames): the highest level in the whole cell, so the marker also covers its cast bar,
    -- which is drawn over the health bar while the mob casts or is crowd controlled.
    if w.levelFloor and w.levelFloor > level then level = w.levelFloor end
    -- The icon sits well above: plate decorations beside the bar (the level badge) must not cover it. Above the
    -- bar's own child frames too (Plater draws its border and health text on frames inside the bar).
    local okKids, kids = pcall(function() return { healthBar:GetChildren() } end)
    if okKids then
        for _, kid in ipairs(kids) do
            local okL, kidLevel = pcall(kid.GetFrameLevel, kid)
            if okL and type(kidLevel) == "number" and not isSecret(kidLevel) and kidLevel > level then
                level = kidLevel
            end
        end
    end
    -- Our own level can move too (a parent's level change carries its children along).
    local markerLevel = level + 5
    local okOwn, own = pcall(w.marker.GetFrameLevel, w.marker)
    local key = tostring(w.appliedStrata or "") .. ":" .. level .. ":" .. markerLevel
    if key == w.layerKey and okOwn and own == markerLevel then return end
    w.layerKey = key
    w.marker:SetFrameLevel(markerLevel)
    w.iconWindow:SetFrameLevel(level + 20)
    w.iconBar:SetFrameLevel(level + 21)
end

local function attachWidgets(w, healthBar, matchStrata)
    w.healthBar = healthBar
    w.signature = nil -- the icon position is anchored to the bar in applyStyle
    w.marker:ClearAllPoints()
    w.marker:SetAllPoints(healthBar)
    w.inset = nil
    w.layerKey = nil
    layerWidgets(w, healthBar, matchStrata)
end

-- pooledHost: host is a plate addon's own pooled frame (EllesmereUI), not Blizzard's nameplate.
local function createWidgets(host, healthBar, pooledHost, matchStrata)
    local w = { host = host }

    -- Marker: filled from the bar's left edge to the remaining DoT damage, on the mob's (secret) health scale.
    w.marker = invisibleBar(host)
    w.span = w.marker:GetStatusBarTexture()
    w.fill = w.marker:CreateTexture(nil, "ARTWORK")
    coverSpan(w.fill, w.span)

    -- Per-DoT segments: running-total bars, each segment between the previous bar's fill end and its own.
    w.segments = {}
    for i = 1, MAX_SEGMENTS do
        local bar = invisibleBar(w.marker)
        bar:SetAllPoints(w.marker)
        local fillEnd = bar:GetStatusBarTexture()
        local texture = w.marker:CreateTexture(nil, "ARTWORK", nil, 1)
        if i == 1 then
            texture:SetPoint("TOPLEFT", w.marker, "TOPLEFT")
        else
            texture:SetPoint("TOPLEFT", w.segments[i - 1].fillEnd, "TOPRIGHT")
        end
        texture:SetPoint("BOTTOMRIGHT", fillEnd, "BOTTOMRIGHT")
        w.segments[i] = { bar = bar, fillEnd = fillEnd, texture = texture }
    end

    w.edges = {}
    for _, points in ipairs({ { true, "TOPLEFT", "TOPRIGHT" }, { true, "BOTTOMLEFT", "BOTTOMRIGHT" },
        { false, "TOPLEFT", "BOTTOMLEFT" }, { false, "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = w.marker:CreateTexture(nil, "OVERLAY")
        edge:SetPoint(points[2], w.span, points[2])
        edge:SetPoint(points[3], w.span, points[3])
        if points[1] then edge:SetHeight(OUTLINE_THICKNESS) else edge:SetWidth(OUTLINE_THICKNESS) end
        table.insert(w.edges, { texture = edge, horizontal = points[1] })
    end

    -- Kill icon: a clipped window; the icon rides the end of a very long bar with max = current health and
    -- value = remaining damage, so it only slides into the window when damage >= health.
    w.iconWindow = CreateFrame("Frame", nil, host)
    w.iconWindow:SetClipsChildren(true)
    w.iconBar = invisibleBar(w.iconWindow)
    w.iconBar:SetPoint("RIGHT", w.iconWindow, "RIGHT")
    w.icon = w.iconBar:CreateTexture(nil, "OVERLAY")
    w.icon:SetPoint("RIGHT", w.iconBar:GetStatusBarTexture(), "RIGHT")

    -- The plate is pooled: a recycled one must not show the last mob's marker before our next update.
    if pooledHost then host:HookScript("OnHide", function() hideWidgets(w) end) end

    attachWidgets(w, healthBar, matchStrata)
    widgetsByHost[host] = w
    return w
end

-- Nameplates have their own look (plate* settings), separate from the target marker: enemy plates are red.
local STYLE_KEYS = {
    "plateFillTexture", "plateFillColor", "plateFillOpacity", "plateDotColors", "plateOutlineStyle",
    "plateDashLength", "plateOutlineThickness", "plateOutlineColor", "plateOutlineOpacity", "plateIcon",
    "nameplateIconSize", "nameplateIconPosition", "plateIconOffsetX", "plateIconOffsetY",
}

-- Pushes the look settings onto one plate's widgets when any of them changed since the last time.
local function applyStyle(w, db)
    local parts = {}
    for i, key in ipairs(STYLE_KEYS) do parts[i] = tostring(db[key]) end
    local signature = table.concat(parts, "|")
    if signature == w.signature then return end
    w.signature = signature

    local lists = ns.lists
    local style = ns.findById(lists.fills, db.plateFillTexture)
    local path = (style.path and not style.gradient) and style.path or nil
    local wrap = style.tiled and "REPEAT" or nil
    w.fill:SetShown(path ~= nil and db.plateDotColors == "single")
    if path then
        w.fill:SetTexture(path, wrap, wrap)
        w.fill:SetHorizTile(style.tiled or false)
        w.fill:SetVertTile(style.tiled or false)
        w.fill:SetVertexColor(ns.colorOf(db.plateFillColor, db.plateFillOpacity))
    end
    for _, segment in ipairs(w.segments) do
        segment.texture:SetTexture(path or WHITE, wrap, wrap)
        segment.texture:SetHorizTile(style.tiled or false)
        segment.texture:SetVertTile(style.tiled or false)
    end

    local r, g, b, a = ns.colorOf(db.plateOutlineColor, db.plateOutlineOpacity)
    for _, edge in ipairs(w.edges) do
        if db.plateOutlineStyle == "dashed" then
            local file = (edge.horizontal and "DashH" or "DashV") .. db.plateDashLength
            edge.texture:SetTexture(ns.textureDir .. file, "REPEAT", "REPEAT")
            edge.texture:SetHorizTile(edge.horizontal)
            edge.texture:SetVertTile(not edge.horizontal)
        else
            edge.texture:SetTexture(WHITE)
            edge.texture:SetHorizTile(false)
            edge.texture:SetVertTile(false)
        end
        if edge.horizontal then
            edge.texture:SetHeight(db.plateOutlineThickness)
        else
            edge.texture:SetWidth(db.plateOutlineThickness)
        end
        edge.texture:SetVertexColor(r, g, b, a)
        edge.texture:SetShown(db.plateOutlineStyle ~= "none")
    end

    local size = db.nameplateIconSize
    w.iconWindow:SetSize(size, size)
    w.iconBar:SetSize(ICON_BAR_LENGTH, size)
    w.icon:SetSize(size, size)
    w.icon:SetTexture(ns.findById(lists.icons, db.plateIcon).path)
    w.iconWindow:ClearAllPoints()
    local x, y = db.plateIconOffsetX, db.plateIconOffsetY
    if db.nameplateIconPosition == "left" then
        w.iconWindow:SetPoint("RIGHT", w.healthBar, "LEFT", -4 + x, y)
    elseif db.nameplateIconPosition == "above" then
        w.iconWindow:SetPoint("BOTTOM", w.healthBar, "TOP", x, 4 + y)
    else
        w.iconWindow:SetPoint("LEFT", w.healthBar, "RIGHT", 4 + x, y)
    end
end

-- Draws one plate's widgets. maxHealth and health may be secret (real plates) or plain (the options preview):
-- they only ever go into StatusBar min/max, never into Lua math. Returns false if drawing failed.
local function drawPlate(w, entries, total, maxHealth, health, db)
    applyStyle(w, db)
    local perDot = db.plateDotColors ~= "single"
    local count = perDot and math.min(#entries, MAX_SEGMENTS) or 0
    local ok = pcall(function()
        w.marker:SetMinMaxValues(0, maxHealth)
        w.marker:SetValue(total)
        local running = 0
        for i, segment in ipairs(w.segments) do
            local entry = entries[i]
            if i <= count then
                running = running + entry.damage
                -- The last segment also covers any DoTs beyond MAX_SEGMENTS.
                if i == count then running = total end
                local color = ns.dotColor(entry, db.plateDotColors)
                segment.texture:SetVertexColor(color[1], color[2], color[3], db.plateFillOpacity / 100)
            end
            segment.bar:SetMinMaxValues(0, maxHealth)
            segment.bar:SetValue(i <= count and running or total)
            segment.texture:SetShown(i <= count)
        end
        w.iconBar:SetMinMaxValues(0, health)
        w.iconBar:SetValue(total)
    end)
    if not ok then
        hideWidgets(w)
        return false
    end
    w.marker:SetShown(db.showMarkers)
    w.iconWindow:SetShown(db.nameplateMode == "markerIcon")
    return true
end

-- Widgets are made once per host and re-anchored when the host's bar changes (Blizzard swaps the bar under a
-- plate; Platynator reassigns its displays between units): frames can't be freed, so making new ones would leak.
local function widgetsFor(host, healthBar, pooledHost, matchStrata)
    local w = widgetsByHost[host]
    if not w then
        w = createWidgets(host, healthBar, pooledHost, matchStrata)
    elseif w.healthBar ~= healthBar then
        attachWidgets(w, healthBar, matchStrata)
    else
        layerWidgets(w, healthBar, matchStrata)
    end
    return w
end

-- Hosts drawn this update; refreshPlates hides the widgets of every other one, except pinned hosts: those
-- another file draws on with these widgets (Focus.lua), which shows and hides them itself.
local seenHosts = {}
local pinnedHosts = {}

-- A dead mob keeps its plate for a moment, and its DoTs stay tracked until they expire.
local function unitIsDead(unit)
    local ok, dead = pcall(UnitIsDead, unit)
    return ok and not isSecret(dead) and dead
end

-- Text drawn on top of the marker, so the stripes never hide it: the plate's health text ("2.4K (72.7%)" on Plater)
-- and Enemy Frames' mob name and health. Each copy has the original's font, color, position and visibility, and
-- its alpha too (a text faded out by its addon stays faded out).
-- Enemy Frames (cell given): a row is its health bar plus overlays (cast bar, crowd control bar) shown over it.
-- While an overlay is shown, the health bar's text is under it, so only the overlay's text is copied (copying the
-- name too drew "GladVenom Spit": the mob's name under the spell it was casting).
local TEXT_RESCAN = 3
local function effectiveAlpha(region, owner)
    local okA, alpha = pcall(region.GetAlpha, region)
    local okE, ownerAlpha = pcall(owner.GetEffectiveAlpha, owner)
    if not okA or isSecret(alpha) or type(alpha) ~= "number" then alpha = 1 end
    if not okE or isSecret(ownerAlpha) or type(ownerAlpha) ~= "number" then ownerAlpha = 1 end
    return alpha * ownerAlpha
end
-- Shown, itself and every parent up to (not including) `stop`. Not IsVisible: Enemy Frames' row frame itself can
-- say it's hidden while its bars are on screen, which made every text look hidden.
local function shownUpTo(frame, stop)
    local depth = 0
    while frame and frame ~= stop and frame ~= UIParent and depth < 12 do
        local okS, shown = pcall(frame.IsShown, frame)
        if okS and not isSecret(shown) and not shown then return false end
        local okP, parent = pcall(frame.GetParent, frame)
        frame = okP and parent or nil
        depth = depth + 1
    end
    return true
end
local function frameShows(frame, stop)
    if not shownUpTo(frame, stop) then return false end
    local okA, alpha = pcall(frame.GetAlpha, frame)
    return not okA or isSecret(alpha) or type(alpha) ~= "number" or alpha > 0.05
end
local function copyText(w, root, healthBar, cell)
    if not w.textHolder then
        w.textHolder = CreateFrame("Frame", nil, w.marker)
        w.textHolder:SetAllPoints(cell or w.marker)
        w.textCopies = {}
    end
    local okL, level = pcall(w.marker.GetFrameLevel, w.marker)
    if okL and type(level) == "number" and not isSecret(level) then w.textHolder:SetFrameLevel(level + 4) end
    local now = GetTime()
    if w.textRoot ~= root or not w.textScannedAt or now - w.textScannedAt >= TEXT_RESCAN then
        if w.textRoot ~= root then
            for _, c in pairs(w.textCopies) do c.copy:Hide() end
            w.textCopies, w.textRoot = {}, root
        end
        w.textScannedAt = now
        -- group: the row part a text belongs to (the health bar, or an overlay); nil off Enemy Frames
        local function walk(frame, depth, group)
            if frame == w.marker or frame == w.iconWindow or frame == w.iconBar then return end
            local okF, forbidden = pcall(function() return frame.IsForbidden and frame:IsForbidden() end)
            if not okF or forbidden then return end
            local ok, regions = pcall(function() return { frame:GetRegions() } end)
            for _, region in ipairs(ok and regions or {}) do
                local okT, isText = pcall(function() return region:GetObjectType() == "FontString" end)
                if okT and isText and not w.textCopies[region] then
                    local okD, layer = pcall(region.GetDrawLayer, region)
                    local copy = w.textHolder:CreateFontString(nil, okD and type(layer) == "string" and layer or "OVERLAY")
                    copy:SetFontObject(GameFontHighlightSmall or GameFontNormalSmall)
                    copy:SetAllPoints(region)
                    w.textCopies[region] = { copy = copy, owner = frame, group = group }
                end
            end
            if depth < 4 then
                local okK, kids = pcall(function() return { frame:GetChildren() } end)
                for _, kid in ipairs(okK and kids or {}) do walk(kid, depth + 1, group or (cell and kid) or nil) end
            end
        end
        walk(root, 0, nil)
    end
    -- Enemy Frames: is an overlay (anything in the row but the health bar) showing over the health bar?
    local overlayShown = false
    if cell then
        local okK, kids = pcall(function() return { cell:GetChildren() } end)
        for _, kid in ipairs(okK and kids or {}) do
            -- An overlay is a bar (cast bar, crowd control bar): a StatusBar, or a frame holding one. The row's aura
            -- icons (frames of icons) aren't, and counting them hid the name as soon as your DoTs' icons appeared.
            local isOverlay = isStatusBar(kid)
            if not isOverlay then
                local okP, parts = pcall(function() return { kid:GetChildren() } end)
                for _, part in ipairs(okP and parts or {}) do if isStatusBar(part) then isOverlay = true break end end
            end
            if isOverlay and kid ~= healthBar and kid ~= w.marker and kid ~= w.iconWindow and kid ~= w.iconBar
                and frameShows(kid, cell) then
                overlayShown = true
            end
        end
    end
    for region, c in pairs(w.textCopies) do
        local copy = c.copy
        local show
        if cell then
            show = shownUpTo(region, cell)
            if show then
                if c.group == healthBar then show = not overlayShown
                elseif c.group then show = frameShows(c.group, cell) end
            end
        else
            local okV, visible = pcall(region.IsVisible, region)
            show = okV and (isSecret(visible) or visible)
        end
        c.shown = show
        if show then
            -- Each part on its own: on Forever any of them can be secret (passed on as is, never tested).
            pcall(function() local font, size, flags = region:GetFont(); if isSecret(font) or font then copy:SetFont(font, size, flags) end end)
            pcall(function() copy:SetTextColor(region:GetTextColor()) end)
            pcall(function() copy:SetShadowColor(region:GetShadowColor()) end)
            pcall(function() copy:SetShadowOffset(region:GetShadowOffset()) end)
            pcall(function() copy:SetJustifyH(region:GetJustifyH()) end)
            pcall(function() copy:SetJustifyV(region:GetJustifyV()) end)
            pcall(function()
                local text = region:GetText()
                if isSecret(text) then copy:SetText(text) else copy:SetText(text or "") end
            end)
            copy:SetAlpha(effectiveAlpha(region, c.owner))
            copy:Show()
        else
            copy:Hide()
        end
    end
    w.textHolder:SetShown(ns.db.markerUnderText ~= false)
end
local function plateText(w, bar) copyText(w, bar, bar, nil) end
ns.copyCellText = function(w, cell, bar) copyText(w, cell, bar, cell) end

local function updatePlate(unit, plate, db)
    local entries, total = ns.dotBreakdownForUnit(unit)
    if total <= 0 or unitIsDead(unit) then return end
    local health, maxHealth = (ns.realHealth or function(u) return UnitHealth(u), UnitHealthMax(u) end)(unit) -- nil for an enemy player not measured yet
    if not health then return end
    local healthBar, host, path, addonBar, iconOnly = findHealthBar(plate, unit)
    if not healthBar or (not iconOnly and not barShown(healthBar)) then return end
    seenHosts[host] = true
    lastBarPath = path
    local w = widgetsFor(host, healthBar, host ~= plate, addonBar)
    -- Nameplates tab > Marker height: 0 covers the bar frame's full height; otherwise the marker is that many pixels
    -- tall, centred on the bar, full width. For plate addons whose bar frame is taller than the bar drawn in it
    -- (NeatPlates: a 32-high frame around a bar about 7 high).
    local height = tonumber(db.plateMarkerHeight) or 0
    -- 0 on NeatPlates: its bar is about 8 high inside a 32-high frame (tested in game), so fit it automatically.
    if height == 0 and type(path) == "string" and path:find("NeatPlates", 1, true) then height = NEATPLATES_HEIGHT end
    if w.inset ~= height then
        w.inset = height
        w.marker:ClearAllPoints()
        if height > 0 then
            w.marker:SetPoint("LEFT", healthBar, "LEFT")
            w.marker:SetPoint("RIGHT", healthBar, "RIGHT")
            w.marker:SetHeight(height)
        else
            w.marker:SetAllPoints(healthBar)
        end
    end
    if drawPlate(w, entries, total, maxHealth, ns.atLeast(health), db) then
        if iconOnly then w.marker:Hide() else plateText(w, healthBar) end
        if ns.shielded and ns.shielded(unit) then w.iconWindow:Hide() end -- a shield soaks damage first
    end
end

-- The options window's mock nameplate: { plate, healthBar } plus its preview state ({ health, dots } in % of
-- max health), or nil. Drawn by the same code as real plates, with plain numbers.
local previewPlate, previewState

function ns.setPlatePreview(host, state)
    local old = previewPlate
    previewPlate, previewState = host, state
    if old and not host then
        local w = widgetsByHost[old.plate]
        if w then hideWidgets(w) end
    end
end

local function updatePreviewPlate(db)
    local entries, total = {}, 0
    for _, dot in ipairs(previewState.dots) do
        if dot.damage > 0 then
            table.insert(entries, dot)
            total = total + dot.damage
        end
    end
    local w = widgetsFor(previewPlate.plate, previewPlate.healthBar)
    if total <= 0 or db.nameplateMode == "off" then return hideWidgets(w) end
    drawPlate(w, entries, total, 100, math.max(previewState.health, 0.01), db)
end

-- Enemy Frames (Krelock, Forever): a list with a bar per enemy nameplate. Its cells are unnamed frames on an
-- unnamed grid under UIParent, each with .unit = "nameplateN" and its health StatusBar as a child (fed with that
-- unit's health). Found once by those fields and kept; the marker and kill icon go on each listed enemy's bar.
local enemyCells -- unit -> { cell, bar }, once found
local cellTopLevel
local enemyCellsSearchedAt = -math.huge
local function enemyFramesLoaded()
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    local ok, loaded = pcall(function() return isLoaded and isLoaded("EnemyFrames") end)
    return ok and loaded and true or false
end
-- Enemy Frames reuses its rows: a row shows one mob now and another later (its .unit changes), and rows are added
-- as the list grows. So the rows are read again every refresh (cheap: the list's own frame and its children), and
-- each row's unit is read as it is now. (Before v1.3.1 the rows were mapped once, so the marker could go on a row
-- that had moved on to another mob or was hidden.)
local enemyRoot -- the frame holding the rows, once found
local function cellsOf(root)
    local found, count = {}, 0
    local okK, kids = pcall(function() return { root:GetChildren() } end)
    if not okK then return found, 0 end
    for _, cell in ipairs(kids) do
        local okU, unit = pcall(rawget, cell, "unit")
        if okU and type(unit) == "string" and unit:find("^nameplate%d+$") then
            local okB, parts = pcall(function() return { cell:GetChildren() } end)
            if okB then
                for _, child in ipairs(parts) do
                    if isStatusBar(child) then
                        -- Two rows on one unit (one hidden, left over): the shown one wins.
                        local entry = { cell = cell, bar = child }
                        if not found[unit] or (not barShown(found[unit].cell) and barShown(cell)) then found[unit] = entry end
                        count = count + 1
                        break
                    end
                end
            end
        end
    end
    return found, count
end
local function findEnemyCells()
    if enemyRoot then
        local found, count = cellsOf(enemyRoot)
        if count > 0 then return found end
        enemyRoot = nil
    end
    local okC, roots = pcall(function() return { UIParent:GetChildren() } end)
    if not okC then return nil end
    for _, root in ipairs(roots) do
        local found, count = cellsOf(root)
        if count > 0 then
            enemyRoot = root
            return found
        end
    end
    return nil
end
-- The marker is drawn over the whole cell, cast bar included (it covers the health bar while the mob casts or
-- is crowd controlled), so whether a mob is dotted always shows.
local function isOurs(w, frame)
    return frame == w.marker or frame == w.iconWindow or frame == w.iconBar
end
local function cellFrames(cell, w, visit)
    local function walk(frame, depth)
        if (w and isOurs(w, frame)) or (frame.IsForbidden and select(2, pcall(frame.IsForbidden, frame)) == true) then return end
        visit(frame)
        if depth < 8 then
            local ok, kids = pcall(function() return { frame:GetChildren() } end)
            if ok then for _, kid in ipairs(kids) do walk(kid, depth + 1) end end
        end
    end
    walk(cell, 0)
end
local CELL_STRATA_RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5 } -- higher isn't followed
-- The highest strata and level of anything in the cell (its crowd control bar can be drawn in a higher strata
-- than the health bar): the marker goes there, above it.
cellTopLevel = function(cell)
    local w, topStrata, topRank, top = widgetsByHost[cell], nil, 0, nil
    cellFrames(cell, w, function(frame)
        local okS, strata = pcall(frame.GetFrameStrata, frame)
        local okL, level = pcall(frame.GetFrameLevel, frame)
        if okS and okL and type(level) == "number" and not isSecret(level) and type(strata) == "string"
            and not isSecret(strata) then
            local rank = CELL_STRATA_RANK[strata] or 0
            if rank > topRank or (rank == topRank and (not top or level > top)) then
                topStrata, topRank, top = strata, rank, level
            end
        end
    end)
    return top, topStrata
end
-- /dida efcheck: every frame in the first Enemy Frames cells, to see what covers the marker.
function ns.enemyFramesReport()
    local report = {}
    if not enemyFramesLoaded() then return { "Enemy Frames isn't loaded." } end
    if not enemyCells then return { "No Enemy Frames cells found yet: get an enemy in the list and try again." } end
    enemyCells = findEnemyCells() or enemyCells
    -- The rows on screen, the ones with our marker first.
    local rows = {}
    for unit, entry in pairs(enemyCells) do
        if barShown(entry.cell) then table.insert(rows, { unit = unit, entry = entry }) end
    end
    table.sort(rows, function(a, b) return (widgetsByHost[a.entry.cell] and 1 or 0) > (widgetsByHost[b.entry.cell] and 1 or 0) end)
    if #rows == 0 then table.insert(report, "No Enemy Frames rows on screen right now.") end
    for index, row in ipairs(rows) do
        if index > 2 then break end
        local unit, entry = row.unit, row.entry
        local w = widgetsByHost[entry.cell]
        local function describe(frame)
            local function get(m) local ok, v = pcall(frame[m], frame); if not ok then return "?" end
                if isSecret(v) then return "secret" end return tostring(v) end
            return string.format("%s %s/%s shown=%s", get("GetObjectType"), get("GetFrameStrata"), get("GetFrameLevel"),
                get("IsShown"))
        end
        table.insert(report, unit .. " cell: " .. describe(entry.cell))
        local function walk(frame, depth)
            local tag = ""
            if w and frame == w.marker then tag = "  <- our marker"
            elseif w and (frame == w.iconWindow or frame == w.iconBar) then tag = "  <- our icon"
            elseif frame == entry.bar then tag = "  <- health bar" end
            if depth > 0 then table.insert(report, string.rep("  ", depth) .. describe(frame) .. tag) end
            local okR, regions = pcall(function() return { frame:GetRegions() } end)
            for _, region in ipairs(okR and regions or {}) do
                local okT, isText = pcall(function() return region:GetObjectType() == "FontString" end)
                if okT and isText then
                    local okX, text = pcall(region.GetText, region)
                    text = (not okX and "?") or (isSecret(text) and "secret") or tostring(text)
                    local c = w and w.textCopies and w.textCopies[region]
                    table.insert(report, string.format("%s  text \"%s\" shown=%s alpha=%s: %s", string.rep("  ", depth), text,
                        (function() local ok, v = pcall(region.IsShown, region); return ok and (isSecret(v) and "secret" or tostring(v)) or "?" end)(),
                        (function() local ok, v = pcall(region.GetAlpha, region); return ok and (isSecret(v) and "secret" or tostring(v)) or "?" end)(),
                        not c and "no copy" or (c.shown and "copied above the stripes" or "copy hidden")))
                end
            end
            if depth < 8 then
                local ok, kids = pcall(function() return { frame:GetChildren() } end)
                if ok then for _, kid in ipairs(kids) do walk(kid, depth + 1) end end
            end
        end
        walk(entry.cell, 0)
    end
    return report
end
local function updateEnemyFrames(db)
    if db.enemyFrames == false or not enemyFramesLoaded() then return end
    local now = GetTime()
    if enemyRoot or now - enemyCellsSearchedAt >= 5 then -- known list: read its rows now; not yet: look every 5s
        enemyCellsSearchedAt = now
        local hadRoot = enemyRoot
        enemyCells = findEnemyCells()
        if enemyRoot and not hadRoot then ns.trace("ENEMYFRAMES bars found: the marker and kill icon go on its list too") end
    end
    if not enemyCells then return end
    for unit, entry in pairs(enemyCells) do
        if UnitExists(unit) and barShown(entry.cell) and barShown(entry.bar) and not unitIsDead(unit) then
            local entries, total = ns.dotBreakdownForUnit(unit)
            if total > 0 then
                local health, maxHealth = (ns.realHealth or function(u) return UnitHealth(u), UnitHealthMax(u) end)(unit)
                if health then
                    seenHosts[entry.cell] = true
                    local floor, floorStrata = cellTopLevel(entry.cell)
                    local w = widgetsByHost[entry.cell]
                    if w and (w.levelFloor ~= floor or w.strataFloor ~= floorStrata) then
                        w.levelFloor, w.strataFloor, w.layerKey, w.appliedStrata = floor, floorStrata, nil, nil
                    end
                    w = widgetsFor(entry.cell, entry.bar, true, true)
                    if w.levelFloor ~= floor or w.strataFloor ~= floorStrata then
                        w.levelFloor, w.strataFloor, w.layerKey, w.appliedStrata = floor, floorStrata, nil, nil
                        layerWidgets(w, entry.bar, true)
                    end
                    drawPlate(w, entries, total, maxHealth, ns.atLeast(health), db)
                    if w.marker:IsShown() then copyText(w, entry.cell, entry.bar, entry.cell) end
                end
            end
        end
    end
end

local function refreshPlates()
    local db = ns.db
    wipe(seenHosts)
    if db and previewPlate and previewState then
        seenHosts[previewPlate.plate] = true
        updatePreviewPlate(db)
    end
    if db and db.nameplateMode ~= "off" and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        for i = 1, MAX_PLATES do
            local unit = "nameplate" .. i
            if UnitExists(unit) then
                local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
                local forbidden = ok and plate and plate.IsForbidden and plate:IsForbidden()
                if ok and plate and not forbidden then
                    updatePlate(unit, plate, db)
                end
            end
        end
    end
    if db then pcall(updateEnemyFrames, db) end
    for host, w in pairs(widgetsByHost) do
        if not seenHosts[host] and not pinnedHosts[host] then hideWidgets(w) end
    end
end

-- The same marker and kill icon on another health bar (Focus.lua). Widgets live on `host`, made once and
-- re-anchored when the bar changes; draw takes the breakdown, max health and health (secret or plain).
ns.barMarker = {
    pin = function(host) pinnedHosts[host] = true end,
    widgetsFor = widgetsFor,
    draw = drawPlate,
    hide = hideWidgets,
    -- Puts the widgets in `strata`, just above `level` (a frame's top layer, when its bar's own isn't enough).
    layer = function(w, strata, level)
        w.marker:SetFrameStrata(strata)
        w.iconWindow:SetFrameStrata(strata)
        w.iconBar:SetFrameStrata(strata)
        w.strataSet = true
        w.marker:SetFrameLevel(level + 5)
        w.iconWindow:SetFrameLevel(level + 20)
        w.iconBar:SetFrameLevel(level + 21)
    end,
}

local driver = CreateFrame("Frame")
local sinceUpdate = 0
local reportedError = false
driver:SetScript("OnUpdate", function(_, elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < UPDATE_INTERVAL then return end
    sinceUpdate = 0
    local ok, err = pcall(refreshPlates)
    if not ok and not reportedError and ns.trace then
        reportedError = true
        ns.trace("ERROR in nameplate update: " .. tostring(err))
        ns.print("Nameplate display error (logged): " .. tostring(err))
    end
end)

local function testBar(i)
    if not testBars[i] then
        local bar = CreateFrame("StatusBar", nil, UIParent)
        bar:SetSize(TEST_BAR_WIDTH, TEST_BAR_HEIGHT)
        bar:SetStatusBarTexture(WHITE)
        bar:SetStatusBarColor(1, 0, 1, 1)
        bar:SetFrameStrata("HIGH")
        local back = bar:CreateTexture(nil, "BACKGROUND")
        back:SetAllPoints()
        back:SetColorTexture(0, 0, 0, 0.8)
        bar:Hide()
        testBars[i] = bar
    end
    return testBars[i]
end

local hider = CreateFrame("Frame")
hider:Hide()
hider:SetScript("OnUpdate", function(self)
    if GetTime() < hideTestBarsAt then return end
    for _, bar in ipairs(testBars) do bar:Hide() end
    self:Hide()
end)

-- A small window with selectable text, so results can be copied out of the game and pasted in a comment.
local copyBox
function ns.showCopyBox(title, text)
    if not copyBox then
        copyBox = CreateFrame("Frame", "DoesItDieAdvancedCopyBox", UIParent, "BackdropTemplate")
        copyBox:SetSize(620, 320)
        copyBox:SetPoint("CENTER")
        copyBox:SetFrameStrata("DIALOG")
        copyBox:EnableMouse(true)
        copyBox:SetMovable(true)
        copyBox:RegisterForDrag("LeftButton")
        copyBox:SetScript("OnDragStart", copyBox.StartMoving)
        copyBox:SetScript("OnDragStop", copyBox.StopMovingOrSizing)
        if copyBox.SetBackdrop then
            copyBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            copyBox:SetBackdropColor(0.06, 0.05, 0.08, 0.97)
            copyBox:SetBackdropBorderColor(0.66, 0.4, 1, 1)
        end
        copyBox.title = copyBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        copyBox.title:SetPoint("TOPLEFT", 12, -10)
        copyBox.title:SetPoint("TOPRIGHT", -36, -10)
        copyBox.title:SetJustifyH("LEFT")
        local close = CreateFrame("Button", nil, copyBox, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        local scroll = CreateFrame("ScrollFrame", nil, copyBox, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -34)
        scroll:SetPoint("BOTTOMRIGHT", -32, 12)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFontObject("GameFontHighlightSmall")
        box:SetWidth(570)
        box:SetScript("OnEscapePressed", function() copyBox:Hide() end)
        scroll:SetScrollChild(box)
        copyBox.box = box
        if UISpecialFrames then table.insert(UISpecialFrames, "DoesItDieAdvancedCopyBox") end
    end
    copyBox.title:SetText(title)
    copyBox.box:SetText(text)
    copyBox:Show()
    copyBox.box:SetFocus()
    copyBox.box:HighlightText()
end

-- Checks one nameplate unit; returns a log line and whether the test bar could be shown.
local function probePlate(unit, index)
    local parts = { unit }
    table.insert(parts, "guid=" .. call(UnitGUID, unit))
    -- What DoTs on it are tracked under: its GUID, "plate:nameplateN" (secret GUID, e.g. instances) or nil.
    table.insert(parts, "key=" .. tostring(ns.tracking and ns.tracking.unitKey(unit)))
    table.insert(parts, "attackable=" .. call(UnitCanAttack, "player", unit))
    table.insert(parts, "health=" .. call(UnitHealth, unit))
    table.insert(parts, "max=" .. call(UnitHealthMax, unit))

    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
        table.insert(parts, "plate API missing")
        return table.concat(parts, " "), false
    end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok then
        table.insert(parts, "plate: error " .. tostring(plate))
        return table.concat(parts, " "), false
    end
    if not plate then
        table.insert(parts, "plate: nil")
        return table.concat(parts, " "), false
    end
    local forbidden = plate.IsForbidden and plate:IsForbidden()
    table.insert(parts, "forbidden=" .. tostring(forbidden))
    if forbidden then return table.concat(parts, " "), false end

    -- What the plate links to (plate addons hang their frames here), for finding an unknown addon's bar.
    local links = {}
    for _, field in ipairs(tableFields(plate, false) or {}) do
        local key, value = field[1], field[2]
        local okT, kind = pcall(function() return value:GetObjectType() end)
        local label = key .. "(" .. (okT and tostring(kind) or "table") .. ")"
        if okT and value ~= plate.UnitFrame then
            local okU, under = pcall(isUnder, value, plate)
            if okU and not under then label = label .. "outside" end
        end
        table.insert(links, label)
        if #links >= 15 then break end
    end
    table.insert(parts, "links=" .. table.concat(links, ","))
    local healthBar, host, path = findHealthBar(plate, unit)
    table.insert(parts, "healthBar=" .. path)
    if healthBar then
        table.insert(parts, "barForbidden=" .. tostring(healthBar.IsForbidden and healthBar:IsForbidden() or false))
        table.insert(parts, "barShown=" .. tostring(barShown(healthBar)))
        table.insert(parts, "barStrata=" .. call(healthBar.GetFrameStrata, healthBar))
        table.insert(parts, "barRect=" .. call(healthBar.GetRect, healthBar))
        table.insert(parts, "barScale=" .. call(healthBar.GetEffectiveScale, healthBar))
    end
    -- Platynator: which display frames we know of, and which unit each shows.
    if Platynator then
        pcall(scanPlatyDisplays, plate)
        local known, units = 0, {}
        for display in pairs(platyDisplays) do
            known = known + 1
            if display.unit then table.insert(units, tostring(display.unit) .. (display:IsShown() and "" or "(hidden)")) end
        end
        table.insert(parts, "platyDisplays=" .. known .. " units=" .. table.concat(units, ","))
        local childCount = select("#", plate:GetChildren())
        table.insert(parts, "plateChildren=" .. childCount)
    end
    local w = host and widgetsByHost[host]
    if w then
        table.insert(parts, "markerRect=" .. call(w.marker.GetRect, w.marker))
        table.insert(parts, "markerOnBar=" .. tostring(w.healthBar == healthBar))
    end

    local bar = testBar(index)
    bar:ClearAllPoints()
    local anchorOK, anchorErr = pcall(bar.SetPoint, bar, "BOTTOM", plate, "TOP", 0, 2)
    table.insert(parts, "anchorPlate=" .. (anchorOK and "ok" or ("error " .. tostring(anchorErr))))
    if healthBar then
        local probeAnchor = testBar(MAX_PLATES + 1)
        probeAnchor:ClearAllPoints()
        local ok2, err2 = pcall(probeAnchor.SetPoint, probeAnchor, "TOPLEFT", healthBar, "TOPLEFT")
        table.insert(parts, "anchorHealthBar=" .. (ok2 and "ok" or ("error " .. tostring(err2))))
        probeAnchor:ClearAllPoints()
        probeAnchor:Hide()
    end
    local feedOK, feedErr = pcall(function()
        bar:SetMinMaxValues(0, UnitHealthMax(unit))
        bar:SetValue(UnitHealth(unit))
    end)
    table.insert(parts, "feedHealth=" .. (feedOK and "ok" or ("error " .. tostring(feedErr))))

    local shown = anchorOK and feedOK
    if shown then bar:Show() end
    return table.concat(parts, " "), shown
end

function ns.probeNameplates()
    local inInstance, instanceType = IsInInstance()
    ns.trace(string.format("PLATES probe: C_NamePlate=%s GetNamePlateForUnit=%s instance=%s (%s) inCombat=%s",
        tostring(C_NamePlate ~= nil), tostring(C_NamePlate ~= nil and C_NamePlate.GetNamePlateForUnit ~= nil),
        tostring(inInstance), tostring(instanceType), call(UnitAffectingCombat, "player")))
    for _, bar in ipairs(testBars) do bar:Hide() end

    local found, shown, report = 0, 0, {}
    local addons = {}
    for _, name in ipairs({ "Plater", "NeatPlates", "TidyPlates", "Platynator", "KuiNameplates", "ThreatPlates",
        "EllesmereNameplates_NS", "ElvUI" }) do
        if _G[name] then table.insert(addons, name) end
    end
    table.insert(report, "Does It Die Advanced " .. tostring((function()
        local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local ok, v = pcall(function() return get and get(ADDON_NAME, "Version") end)
        return ok and v or ""
    end)()) .. " plate probe. Plate addons loaded: "
        .. (#addons > 0 and table.concat(addons, ", ") or "none known"))
    for i = 1, MAX_PLATES do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            found = found + 1
            local line, ok = probePlate(unit, found)
            ns.trace("PLATES " .. line)
            if found <= 3 then table.insert(report, line) end
            if ok then shown = shown + 1 end
        end
    end
    if ns.showCopyBox then
        ns.showCopyBox("Nameplate probe: select all (Ctrl+A), copy (Ctrl+C) and paste it in a comment",
            table.concat(report, "\n\n"))
    end

    hideTestBarsAt = GetTime() + TEST_SECONDS
    hider:Show()
    ns.trace(string.format("PLATES probe done: %d nameplates, %d test bars shown", found, shown))
    ns.print(string.format("Nameplate probe: %d nameplates found, %d magenta test bars shown for %d seconds. "
        .. "Results are in the log (/reload to save it).", found, shown, TEST_SECONDS))
end
