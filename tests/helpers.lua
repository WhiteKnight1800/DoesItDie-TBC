
local H = {}
function H.load(path, src, ns)
    local fn, err = (loadstring or load)(src, "@" .. path)
    if not fn then error(err) end
    fn("DoesItDie", ns)
end
function H.fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events and f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
function H.update(elapsed)
    now = now + elapsed
    for _, f in ipairs(frames) do
        if f.scripts.OnUpdate then f.scripts.OnUpdate(f, elapsed) end
    end
end
-- The same in reverse order: WoW doesn't promise an order between frames' OnUpdate scripts.
function H.updateReversed(elapsed)
    now = now + elapsed
    for i = #frames, 1, -1 do
        local f = frames[i]
        if f.scripts.OnUpdate then f.scripts.OnUpdate(f, elapsed) end
    end
end
-- The clickable owner of a visible text (buttons with SetText, or a button whose child font string has it).
function H.clickText(text)
    for _, f in ipairs(frames) do
        if f.text == text then
            local target = f.scripts.OnClick and f or f.parent
            if target and target.scripts and target.scripts.OnClick then
                target.scripts.OnClick(target)
                return true
            end
        end
    end
    error("nothing clickable with text: " .. text)
end
-- The row whose label is `text`: returns its first child widget of the given kind.
function H.rowWidget(text, kind)
    for _, f in ipairs(frames) do
        if f.kind == "fontstring" and f.text == text and f.parent then
            for _, child in ipairs(f.parent.children) do
                if child.kind == kind then return child end
            end
        end
    end
    error("no " .. kind .. " in row " .. text)
end
function H.shownMenuEntries()
    local out = {}
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.swatch and f.shown and f.scripts.OnClick then table.insert(out, f) end
    end
    return out
end
function H.runTickers(times)
    for _ = 1, times do
        for _, t in ipairs(tickers) do if not t.cancelled then now = now + 0.5; t.fn() end end
    end
end
return H
