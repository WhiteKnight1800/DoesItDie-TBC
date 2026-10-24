
now = 1000
chat = {}
frames = {}
tickers = {}

local methods = {}
local function mock(kind, parent)
    local o = { kind = kind, parent = parent, scripts = {}, shown = true, width = 100, height = 20, children = {} }
    if parent and type(parent) == "table" and parent.children then table.insert(parent.children, o) end
    table.insert(frames, o)
    -- Unknown methods (CamelCase, like WoW's) do nothing; unknown fields are nil like a real table.
    return setmetatable(o, { __index = function(t, k)
        if methods[k] then return methods[k] end
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
end
FakeMock = mock

function methods.SetScript(self, name, fn) self.scripts[name] = fn end
function methods.GetScript(self, name) return self.scripts[name] end
function methods.HookScript(self, name, fn) self.scripts[name] = fn end
function methods.Show(self)
    local was = self.shown
    self.shown = true
    if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods.Hide(self)
    local was = self.shown
    self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods.SetShown(self, v) if v then self:Show() else self:Hide() end end
function methods.IsShown(self) return self.shown end
function methods.GetObjectType(self) return self.kind end
function methods.IsVisible(self)
    if not self.shown then return false end
    local parent = self.parent
    if type(parent) == "table" and parent.shown ~= nil then return methods.IsVisible(parent) end
    return true
end
function methods.SetText(self, t) self.text = t end
function methods.GetText(self) return self.text end
function methods.SetSize(self, w, h) self.width, self.height = w, h end
function methods.SetWidth(self, w) self.width = w end
function methods.SetHeight(self, h) self.height = h end
function methods.GetWidth(self) return self.width end
function methods.GetHeight(self) return self.height end
function methods.GetStringWidth(self) return #(self.text or "") * 6 end
function methods.GetFont(self) return "Fonts\\FRIZQT__.TTF", 12, "" end
function methods.SetFrameStrata(self, v) self.strata = v end
function methods.GetFrameStrata(self) return self.strata or "MEDIUM" end
function methods.SetFrameLevel(self, v) self.level = v end
function methods.GetFrameLevel(self) return self.level or 5 end
function methods.GetChildren(self) return end
function methods.SetClipsChildren(self, v) self.clips = v end
function methods.IsMouseOver(self) return false end
function methods.GetStatusBarTexture(self) self._tex = self._tex or mock("tex", self); return self._tex end
function methods.GetThumbTexture(self) self._thumb = self._thumb or mock("thumb", self); return self._thumb end
function methods.CreateTexture(self) return mock("texture", self) end
function methods.CreateMaskTexture(self) return mock("mask", self) end
function methods.CreateFontString(self) return mock("fontstring", self) end
function methods.CreateAnimationGroup(self) return mock("animgroup", self) end
function methods.CreateAnimation(self) return mock("anim", self) end
function methods.SetChecked(self, v) self.checked = v end
function methods.GetChecked(self) return self.checked end
function methods.SetMinMaxValues(self, a, b) self.min, self.max = a, b end
function methods.GetMinMaxValues(self) return self.min, self.max end
function methods.SetValue(self, v)
    if self.min and type(v) == "number" then v = math.max(self.min, math.min(self.max, v)) end
    self.value = v
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v, false) end
end
function methods.GetValue(self) return self.value or 0 end
function methods.RegisterEvent(self, e) self.events = self.events or {}; self.events[e] = true end
function methods.RegisterUnitEvent(self, e) self.events = self.events or {}; self.events[e] = true end
function methods.GetDebugName(self) return self.name or "mock" end
function methods.GetName(self) return self.name end
function methods.GetParent(self) return self.parent end
function methods.SetAllPoints(self, target) self.allPoints = target end

function CreateFrame(kind, name, parent, template)
    local f = mock(kind, parent)
    f.name, f.template = name, template
    if kind ~= "Frame" or name then f.shown = true end
    if name then _G[name] = f end
    return f
end
UIParent = mock("UIParent")
GameTooltip = mock("GameTooltip")
GameFontNormalSmall = mock("font")
DEFAULT_CHAT_FRAME = mock("chat")
function DEFAULT_CHAT_FRAME.AddMessage(self, msg) table.insert(chat, msg) end
SlashCmdList = {}
UISpecialFrames = {}
Settings = {
    RegisterCanvasLayoutCategory = function() return mock("category") end,
    RegisterAddOnCategory = function() end,
}
C_Timer = {
    After = function(t, fn) end,
    NewTicker = function(t, fn)
        local ticker = { fn = fn, cancelled = false }
        function ticker:Cancel() self.cancelled = true end
        table.insert(tickers, ticker)
        return ticker
    end,
}
local SPELLS = {
    [172] = { "Corruption", "Corrupts the target, causing 40 Shadow damage over 12 sec." },
    [348] = { "Immolate", "Burns the enemy for 11 Fire damage and then an additional 20 Fire damage over 15 sec." },
}
C_Spell = {
    GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] or "Spell" end,
    GetSpellDescription = function(id) return SPELLS[id] and SPELLS[id][2] or "" end,
}
Enum = { PowerType = { ComboPoints = 4 } }
function GetTime() return now end
targetGuid = nil -- set later: the target and nameplate1 are then the same mob
function UnitExists(unit) return unit == "nameplate1" or (unit == "target" and targetGuid ~= nil) end
function UnitCanAttack() return true end
function IsInInstance() return false, "none" end
local plate = mock("Frame")
FakePlate = plate
plate.UnitFrame = mock("Frame", plate)
plate.UnitFrame.healthBar = mock("StatusBar", plate.UnitFrame)
C_NamePlate = { GetNamePlateForUnit = function(unit) if unit == "nameplate1" then return plate end end }
function UnitGUID(unit) if unit == "target" or unit == "nameplate1" then return targetGuid end end
function UnitIsDead() return false end
combat = false
function UnitAffectingCombat() return combat end
function InCombatLockdown() return combat end
function UnitHealth() return 100 end
function UnitHealthMax() return 100 end
function hooksecurefunc() end
function HideUIPanel() end
function CreateColor(...) return { ... } end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strlower(s) return string.lower(s) end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function date() return "12:00:00" end
unpack = unpack or table.unpack
