-- DoesItDie focus frame: the damage marker (and the kill icon, as on nameplates) on the focus frame's health bar,
-- for your DoTs on the focused mob. Based on toughnuts99's patch (issue #12).
--
-- Tracking is per mob already (ns.dotBreakdownForUnit) and UNIT_COMBAT reports hits on the focus, so this is only
-- display: it reuses the nameplate widgets (ns.barMarker) in a look of its own (Focus tab, focus* settings, read
-- through a view that maps the widgets' plate* keys to them), drawn on a custom focus bar (Advanced tab, a frame
-- path like the target's), else EllesmereUI's focus frame, else Blizzard's. The options window's preview has a
-- mock focus frame drawn the same way with its plain numbers (ns.setFocusPreview).
--
-- The widgets hang off a frame of our own rather than the bar's parent: unit frame addons may put the bar in a
-- clipping frame, which would cut off a kill icon beside the bar. So they're hidden by hand whenever there's no
-- focus, the bar isn't visible or there are no DoTs, and pinned so the nameplate refresh leaves them alone.

local _, ns = ...

local UPDATE_INTERVAL = 0.1

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- Blizzard's focus frame is built from the target frame's template, so its bar sits at the same paths.
local function blizzardFocusBar()
    local ff = FocusFrame
    local content = ff and ff.TargetFrameContent
    local main = content and content.TargetFrameContentMain
    return (main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar)
        or (main and main.HealthBar)
        or FocusFrameHealthBar
        or (ff and ff.healthbar)
end

-- The bar to draw on, and a description of it for the options window.
local function focusBar(db)
    local path = strtrim(db.customFocusHealthBar or "")
    local custom = path ~= "" and ns.resolveFramePath(path)
    if custom then return custom, "|cff66ff66" .. path .. "|r" end
    local known, owner = ns.knownFocusFrame()
    local fallback = (known and (owner .. " focus frame")) or (blizzardFocusBar() and "Blizzard's focus frame")
    local note = path ~= "" and ("|cffff6666" .. path .. " not found|r, using ") or ""
    if known then return known, note .. fallback end
    local blizzard = blizzardFocusBar()
    if blizzard then return blizzard, note .. fallback end
    return nil, note .. "|cffff6666no focus frame found|r"
end

-- What the focus marker is attached to (options window).
function ns.focusStatus()
    if not ns.db then return "" end
    return select(2, focusBar(ns.db))
end

-- The focus look: the nameplate widgets read plate* (and nameplateMode, nameplateIcon*) settings; this view
-- answers those keys with the focus* ones, and everything else (showMarkers) straight from the settings.
local FOCUS_KEYS = {
    nameplateMode = "focusMode", plateIcon = "focusIcon", nameplateIconSize = "focusIconSize",
    nameplateIconPosition = "focusIconPosition", plateIconOffsetX = "focusIconOffsetX",
    plateIconOffsetY = "focusIconOffsetY", plateDotColors = "focusDotColors", plateFillTexture = "focusFillTexture",
    plateFillColor = "focusFillColor", plateFillOpacity = "focusFillOpacity", plateOutlineStyle = "focusOutlineStyle",
    plateDashLength = "focusDashLength", plateOutlineThickness = "focusOutlineThickness",
    plateOutlineColor = "focusOutlineColor", plateOutlineOpacity = "focusOutlineOpacity",
}
local focusLook = setmetatable({}, { __index = function(_, key) return ns.db[FOCUS_KEYS[key] or key] end })
ns.focusKeys = FOCUS_KEYS -- (Options.lua's "Copy from Nameplates tab")

local host = CreateFrame("Frame", nil, UIParent)
host:SetAllPoints(UIParent)
local widgets

local function hide()
    if widgets then ns.barMarker.hide(widgets) end
end

-- The options window's mock focus frame: { frame, healthBar } and the preview state ({ health, dots } in % of max
-- health), or nil.
local previewHost, previewState, previewWidgets

function ns.setFocusPreview(mock, state)
    previewHost, previewState = mock, state
    if not mock and previewWidgets then ns.barMarker.hide(previewWidgets) end
end

local function refreshPreview(db)
    if not previewHost or not previewState then return end
    ns.barMarker.pin(previewHost.frame)
    previewWidgets = ns.barMarker.widgetsFor(previewHost.frame, previewHost.healthBar)
    local entries, total = {}, 0
    for _, dot in ipairs(previewState.dots) do
        if dot.damage > 0 then
            table.insert(entries, dot)
            total = total + dot.damage
        end
    end
    if total <= 0 or db.focusMode == "off" then return ns.barMarker.hide(previewWidgets) end
    ns.barMarker.draw(previewWidgets, entries, total, 100, math.max(previewState.health, 0.01), focusLook)
end

local function shown(bar)
    local ok, visible = pcall(bar.IsVisible, bar)
    return not ok or isSecret(visible) or visible ~= false
end

-- Highest strata/level anywhere in the focus frame: the bar's own level isn't enough, since Blizzard's focus frame
-- (like the target frame, see Display.lua) has art layered far above its health bar, and can re-layer it any time.
local STRATA_RANK = {
    BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}
local LAYER_CHECK_INTERVAL = 1
local layerCheckedAt, topStrata, topLevel, layerBar = -math.huge, nil, nil, nil

local function topLayer(root)
    local bestStrata, bestLevel = "BACKGROUND", 0
    local found, sawSecret = false, false
    local function visit(frame, depth)
        -- Only what's on screen counts (hidden HIGH parts lifted the marker over the world map), and frames the game
        -- won't let us read are skipped. Some report a secret strata/level; those are skipped (their children aren't).
        local okV, visible = pcall(frame.IsVisible, frame)
        if okV and not isSecret(visible) and not visible then return end
        local okSL, strata, level = pcall(function() return frame:GetFrameStrata(), frame:GetFrameLevel() end)
        if okSL and (isSecret(strata) or isSecret(level)) then sawSecret = true end
        if okSL and not isSecret(strata) and not isSecret(level) then
            found = true
            local rank, bestRank = STRATA_RANK[strata] or 0, STRATA_RANK[bestStrata] or 0
            if rank > bestRank then
                bestStrata, bestLevel = strata, level
            elseif rank == bestRank and level > bestLevel then
                bestLevel = level
            end
        end
        if depth < 6 then
            local okK, kids = pcall(function() return { frame:GetChildren() } end)
            for _, child in ipairs(okK and kids or {}) do visit(child, depth + 1) end
        end
    end
    visit(root, 0)
    return bestStrata, bestLevel, found, sawSecret
end

-- Keeps the focus widgets above everything on the frame that holds `bar` (checked at most once a second).
local function updateLayering(bar, now)
    if bar ~= layerBar or now - layerCheckedAt >= LAYER_CHECK_INTERVAL then
        layerCheckedAt, layerBar = now, bar
        local root = ns.frameRoot and ns.frameRoot(bar) or bar
        local ok, strata, level, found, sawSecret = pcall(topLayer, root)
        -- Nothing measured (the frame hidden for a moment): the last layer is kept. Secret layers on the frame
        -- (Blizzard's on Forever): its real top is unknown, so the marker goes one strata up, out of LOW (as on the
        -- target frame).
        if ok and not found then
            ok, layerCheckedAt = false, 0
        elseif ok and sawSecret and (STRATA_RANK[strata] or 0) < STRATA_RANK.MEDIUM then
            strata, level = "MEDIUM", 1
        end
        if ok and (strata ~= topStrata or level ~= topLevel) then
            topStrata, topLevel = strata, level
            ns.trace(string.format("LAYER focus frame top is %s/%d; focus marker placed above it", strata, level))
        end
    end
    if topStrata then ns.barMarker.layer(widgets, topStrata, topLevel) end
end

local function dead()
    local ok, isDead = pcall(UnitIsDead, "focus")
    return ok and not isSecret(isDead) and isDead
end

local function refresh()
    local db = ns.db
    if not db or not ns.barMarker then return end
    refreshPreview(db)
    if db.focusMode == "off" or not UnitExists("focus") or dead() then return hide() end
    local bar = focusBar(db)
    if not bar or not shown(bar) then return hide() end
    if ns.mapCovers and ns.mapCovers(bar) then return hide() end -- the world map open over it
    local entries, total = ns.dotBreakdownForUnit("focus")
    if total <= 0 then return hide() end
    ns.barMarker.pin(host)
    widgets = ns.barMarker.widgetsFor(host, bar, false, true)
    updateLayering(bar, GetTime())
    local health, maxHealth = (ns.realHealth or function(u) return UnitHealth(u), UnitHealthMax(u) end)("focus") -- nil for an enemy player not measured yet
    if not health then return hide() end
    ns.barMarker.draw(widgets, entries, total, maxHealth, ns.atLeast(health), focusLook)
    if ns.shielded and ns.shielded("focus") and widgets.iconWindow then widgets.iconWindow:Hide() end
end

local driver = CreateFrame("Frame")
local sinceUpdate = 0
local reportedError = false
driver:SetScript("OnUpdate", function(_, elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < UPDATE_INTERVAL then return end
    sinceUpdate = 0
    local ok, err = pcall(refresh)
    if not ok then
        pcall(hide)
        if not reportedError and ns.trace then
            reportedError = true
            ns.trace("ERROR in focus update: " .. tostring(err))
            ns.print("Focus display error (logged): " .. tostring(err))
        end
    end
end)
