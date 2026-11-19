local ADDON, ns = ...

local panel = CreateFrame("Frame", "TotemDistanceOptionsPanel")
panel.name = "TotemDistance"
local refreshers = {}

local function RefreshPanel()
    for _, fn in ipairs(refreshers) do fn() end
end

local function MakeLabel(parent, text, template, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function Round(v)
    return math.floor(v + 0.5)
end

local function MakeSlider(label, y, minV, maxV, step, get, set, format)
    MakeLabel(panel, label, "GameFontNormal", 16, y)

    local slider = CreateFrame("Slider", nil, panel)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(260, 16)
    slider:SetPoint("TOPLEFT", 220, y + 2)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:EnableMouse(true)

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.2, 0.2, 0.2, 0.9)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(6)

    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:GetThumbTexture():SetSize(16, 24)

    local valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueText:SetPoint("LEFT", slider, "RIGHT", 12, 0)

    local updating = false
    slider:SetScript("OnValueChanged", function(_, value)
        valueText:SetText(format(value))
        if updating or not ns.db then return end
        set(value)
    end)

    refreshers[#refreshers + 1] = function()
        updating = true
        slider:SetValue(get())
        valueText:SetText(format(get()))
        updating = false
    end
    return slider
end

local function MakeCheckbox(label, x, y, get, set)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", x, y)
    check:SetSize(26, 26)
    local text = check.Text or check.text
    if not text then
        text = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    end
    text:SetText(label)
    check:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
    end)
    refreshers[#refreshers + 1] = function()
        check:SetChecked(get())
    end
    return check
end

local function OpenColorPicker(slot)
    local color = ns.GetColor(slot)
    local previous = { color[1], color[2], color[3] }

    local function Apply(r, g, b)
        ns.db.colors[slot] = { r, g, b }
        RefreshPanel()
    end

    local function OnChanged()
        Apply(ColorPickerFrame:GetColorRGB())
    end
    local function OnCancel()
        Apply(previous[1], previous[2], previous[3])
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color[1], g = color[2], b = color[3],
            hasOpacity = false,
            swatchFunc = OnChanged,
            cancelFunc = OnCancel,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.func = OnChanged
        ColorPickerFrame.cancelFunc = OnCancel
        ColorPickerFrame:SetColorRGB(color[1], color[2], color[3])
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

local function MakeColorRow(slot, y)
    local element = ns.ELEMENTS[slot]

    MakeCheckbox(element.label .. " totem", 16, y + 4,
        function() return ns.db.slotEnabled[slot] end,
        function(v) ns.db.slotEnabled[slot] = v end)

    local swatch = CreateFrame("Button", nil, panel)
    swatch:SetSize(36, 20)
    swatch:SetPoint("TOPLEFT", 220, y)
    local border = swatch:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(1, 1, 1, 0.9)
    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    swatch:SetScript("OnClick", function() OpenColorPicker(slot) end)

    local hint = swatch:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("LEFT", swatch, "RIGHT", 10, 0)
    hint:SetText("Click to change color")

    refreshers[#refreshers + 1] = function()
        local c = ns.GetColor(slot)
        fill:SetColorTexture(c[1], c[2], c[3], 1)
    end
end

MakeLabel(panel, "TotemDistance", "GameFontNormalHuge", 16, -16)
local subtitle = MakeLabel(panel, "Shows how far you are from each of your totems and warns you when you walk out of its range. Distances are measured from where each totem landed around you when you dropped it.", "GameFontHighlightSmall", 16, -46)
subtitle:SetWidth(560)
subtitle:SetJustifyH("LEFT")

MakeCheckbox("Enable TotemDistance", 16, -80,
    function() return ns.db.enabled end,
    function(v) ns.db.enabled = v end)

MakeCheckbox("Lock position", 16, -106,
    function() return ns.db.locked end,
    function(v)
        ns.db.locked = v
        ns.ApplyTrackerSettings()
    end)

MakeCheckbox("Flash a warning on screen when leaving range", 16, -132,
    function() return ns.db.alert end,
    function(v) ns.db.alert = v end)

MakeCheckbox("Play a sound when leaving range", 16, -158,
    function() return ns.db.sound end,
    function(v) ns.db.sound = v end)

MakeSlider("Warn when this close to the edge", -200, 0, 15, 1,
    function() return ns.db.warnYards end,
    function(v) ns.db.warnYards = v end,
    function(v) return string.format("%d yd", Round(v)) end)

MakeLabel(panel, "Totems and icon border colors", "GameFontNormalLarge", 16, -240)
for slot = 1, 4 do
    MakeColorRow(slot, -268 - (slot - 1) * 30)
end

local resetColors = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetColors:SetSize(140, 24)
resetColors:SetPoint("TOPLEFT", 16, -392)
resetColors:SetText("Reset colors")
resetColors:SetScript("OnClick", function()
    ns.ResetColors()
    RefreshPanel()
end)

local resetPosition = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetPosition:SetSize(140, 24)
resetPosition:SetPoint("LEFT", resetColors, "RIGHT", 12, 0)
resetPosition:SetText("Reset position")
resetPosition:SetScript("OnClick", function()
    ns.ResetTrackerPosition()
end)

local test = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
test:SetSize(180, 24)
test:SetPoint("LEFT", resetPosition, "RIGHT", 12, 0)
test:SetText("Toggle test totems")
test:SetScript("OnClick", function()
    ns.SetTestMode(not ns.testMode)
end)

panel:SetScript("OnShow", function()
    if ns.db then RefreshPanel() end
end)

local category
if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end

function ns.OpenOptions()
    if Settings and Settings.OpenToCategory and category then
        local id = category.GetID and category:GetID() or category.ID
        Settings.OpenToCategory(id)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    else
        ns.Print("Open the AddOns tab in the game options to find TotemDistance.")
    end
end

local function ParseColor(text)
    local hex = text and text:match("^#?(%x%x%x%x%x%x)$")
    if not hex then return end
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function ParseColor(text)
    local hex = text and text:match("^#?(%x%x%x%x%x%x)$")
    if not hex then return end
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function PrintDebug()
    local db = ns.db
    ns.Print("--- debug ---")
    ns.Print(string.format("enabled=%s test=%s locked=%s alert=%s sound=%s warn=%d",
        tostring(db.enabled), tostring(ns.testMode), tostring(db.locked), tostring(db.alert), tostring(db.sound), db.warnYards))
    local n, w = ns.PlayerWorldPosition()
    local ok, facing = pcall(GetPlayerFacing)
    facing = ok and type(facing) == "number" and not ns.IsSecret(facing) and facing or nil
    ns.Print("player position=" .. (n and string.format("%.1f,%.1f", n, w) or "unavailable")
        .. " facing=" .. (facing and string.format("%.2f", facing) or "unavailable (totems assumed at your feet)"))
    for slot = 1, 4 do
        local label = ns.ELEMENTS[slot].label
        local entry = ns.state[slot]
        if entry then
            local distance = ns.DistanceFromDrop(entry)
            ns.Print(string.format("%s %d: %s range=%d (%s%s) drop=%s distance=%s",
                label, slot, entry.name, entry.range, entry.source, entry.verified and "" or ", unverified",
                entry.worldN and string.format("%.1f,%.1f", entry.worldN, entry.worldW) or "unknown",
                distance and string.format("%.1f yd", distance) or "unknown"))
        else
            ns.Print(string.format("%s %d: no totem", label, slot))
        end
    end
end

local HELP = {
    "/totemdistance - open settings",
    "/totemdistance on | off - enable or disable",
    "/totemdistance lock | unlock - lock the tracker or allow dragging it",
    "/totemdistance resetpos - move the tracker back to its default spot",
    "/totemdistance alert on | off - flashing on-screen warning when you leave a totem's range",
    "/totemdistance sound on | off - sound when you leave a totem's range",
    "/totemdistance warn <0-15> - yards from the edge where the bar turns yellow",
    "/totemdistance color <1-4> <RRGGBB> - set color (1 Fire, 2 Earth, 3 Water, 4 Air)",
    "/totemdistance range <1-4> <yards|auto> - override range for a slot",
    "/totemdistance here - reset all active totems to where they would land if recast now",
    "/totemdistance test - pretend totems dropped where you stand",
    "/totemdistance reset - reset all settings",
    "/totemdistance debug - print diagnostics",
}

local function Toggle(rest, current)
    rest = rest:lower()
    if rest == "on" then return true end
    if rest == "off" then return false end
    return not current
end

SLASH_TOTEMDISTANCE1 = "/totemdistance"
SLASH_TOTEMDISTANCE2 = "/tdist"
SlashCmdList["TOTEMDISTANCE"] = function(input)
    if not ns.db then return end
    local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    local db = ns.db

    if cmd == "" then
        ns.OpenOptions()
    elseif cmd == "on" or cmd == "off" then
        db.enabled = (cmd == "on")
        ns.Print(db.enabled and "enabled" or "disabled")
    elseif cmd == "lock" or cmd == "unlock" then
        db.locked = (cmd == "lock")
        ns.ApplyTrackerSettings()
        ns.Print(db.locked and "locked" or "unlocked: drag the tracker to move it")
    elseif cmd == "resetpos" then
        ns.ResetTrackerPosition()
        ns.Print("tracker moved back to its default spot")
    elseif cmd == "alert" then
        db.alert = Toggle(rest, db.alert)
        ns.Print(db.alert and "on-screen warning on" or "on-screen warning off")
    elseif cmd == "sound" then
        db.sound = Toggle(rest, db.sound)
        ns.Print(db.sound and "leave-range sound on" or "leave-range sound off")
    elseif cmd == "warn" then
        local v = tonumber(rest)
        if not v then return ns.Print("Usage: /totemdistance warn <0-15>") end
        db.warnYards = math.max(0, math.min(15, v))
    elseif cmd == "color" then
        local slotText, hex = rest:match("^(%d)%s+(%S+)$")
        local slot = tonumber(slotText)
        local r, g, b = ParseColor(hex)
        if not (slot and slot >= 1 and slot <= 4 and r) then
            return ns.Print("Usage: /totemdistance color <1-4> <RRGGBB>")
        end
        db.colors[slot] = { r, g, b }
    elseif cmd == "range" then
        local slotText, value = rest:match("^(%d)%s+(%S+)$")
        local slot = tonumber(slotText)
        if not (slot and slot >= 1 and slot <= 4 and value) then
            return ns.Print("Usage: /totemdistance range <1-4> <yards|auto>")
        end
        if value:lower() == "auto" then
            db.rangeOverrides[slot] = nil
        else
            local yards = tonumber(value)
            if not yards or yards <= 0 or yards > 100 then
                return ns.Print("Range must be between 1 and 100 yards.")
            end
            db.rangeOverrides[slot] = yards
        end
        local entry = ns.state[slot]
        if entry then
            entry.range = ns.ResolveRange(slot, entry.name, entry.spellID)
        end
    elseif cmd == "here" then
        local moved = ns.MoveTotemsToPlayer()
        ns.Print(moved > 0 and string.format("%d totem position(s) reset around you", moved) or "no active totems")
    elseif cmd == "test" then
        ns.SetTestMode(not ns.testMode)
        ns.Print(ns.testMode and "test totems on: pretend totems dropped where you stand (Fire 20, Earth 10, Water 30, Air 5 yards). Walk away to see the tracker react." or "test totems off")
    elseif cmd == "reset" then
        for k in pairs(db) do db[k] = nil end
        ns.CopyDefaults(ns.defaults, db)
        ns.ApplyTrackerSettings()
        ns.Print("settings reset")
    elseif cmd == "debug" then
        PrintDebug()
    else
        for _, line in ipairs(HELP) do ns.Print(line) end
    end
    if panel:IsShown() then RefreshPanel() end
end
