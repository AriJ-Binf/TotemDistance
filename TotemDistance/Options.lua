local ADDON, ns = ...

local panel = CreateFrame("Frame", "TotemDistanceOptionsPanel")
panel.name = "TotemDistance"
local totemsPanel = CreateFrame("Frame", "TotemDistanceTotemsPanel")
totemsPanel.name = "Tracked totems"
totemsPanel.parent = panel.name
-- Frames start shown; the settings window only fires OnShow on a hidden frame,
-- so without this the first visit shows every control unset.
panel:Hide()
totemsPanel:Hide()
local refreshers = {}

local function RefreshPanel()
    if not ns.db then return end
    for _, fn in ipairs(refreshers) do fn() end
end
ns.RefreshOptions = RefreshPanel

local function MakeLabel(parent, text, template, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function Round(v)
    return math.floor(v + 0.5)
end

local function MakeSlider(parent, label, y, minV, maxV, step, get, set, format)
    MakeLabel(parent, label, "GameFontNormal", 16, y)

    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(220, 16)
    slider:SetPoint("TOPLEFT", 260, y + 2)
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

local function MakeCheckbox(parent, label, x, y, get, set, small)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", x, y)
    check:SetSize(small and 22 or 26, small and 22 or 26)
    local text = check.Text or check.text
    if not text then
        text = check:CreateFontString(nil, "ARTWORK", small and "GameFontHighlightSmall" or "GameFontHighlight")
        text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    elseif small and text.SetFontObject then
        text:SetFontObject("GameFontHighlightSmall")
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

local function MakeButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
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

local function MakeSwatch(parent, slot, relativeTo)
    local swatch = CreateFrame("Button", nil, parent)
    swatch:SetSize(28, 16)
    swatch:SetPoint("LEFT", relativeTo, "RIGHT", 8, 0)
    local border = swatch:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(1, 1, 1, 0.9)
    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    swatch:SetScript("OnClick", function() OpenColorPicker(slot) end)
    refreshers[#refreshers + 1] = function()
        local c = ns.GetColor(slot)
        fill:SetColorTexture(c[1], c[2], c[3], 1)
    end
    return swatch
end

local function Percent(v) return string.format("%d%%", Round(v)) end
local function Yards(v) return string.format("%d yd", Round(v)) end
local function Seconds(v) return string.format("%.1f s", v) end

local function ApplyAlerts()
    ns.ApplyAlertSettings()
end

-- Main page: tracker and alerts.

MakeLabel(panel, "TotemDistance", "GameFontNormalHuge", 16, -16)
local subtitle = MakeLabel(panel, "Shows how far you are from each of your totems and warns you when you walk out of its range or far enough away that it is about to despawn. Choose which totems to track under Tracked totems.", "GameFontHighlightSmall", 16, -46)
subtitle:SetWidth(580)
subtitle:SetJustifyH("LEFT")

MakeCheckbox(panel, "Enable TotemDistance", 16, -76,
    function() return ns.db.enabled end,
    function(v) ns.db.enabled = v end)

MakeCheckbox(panel, "Lock Interface In Place", 240, -76,
    function() return ns.db.locked end,
    function(v)
        ns.db.locked = v
        ns.ApplyTrackerSettings()
    end)

MakeSlider(panel, "Turn yellow this close to the edge", -114, 0, 15, 1,
    function() return ns.db.warnYards end,
    function(v) ns.db.warnYards = v end,
    Yards)

MakeLabel(panel, "Leaving range warning", "GameFontNormalLarge", 16, -148)

MakeCheckbox(panel, "Show warning on screen", 16, -170,
    function() return ns.db.alert end,
    function(v) ns.db.alert = v end)

MakeCheckbox(panel, "Play a sound", 240, -170,
    function() return ns.db.sound end,
    function(v) ns.db.sound = v end)

MakeSlider(panel, "Warning text size", -208, 12, 48, 1,
    function() return ns.db.alertSize end,
    function(v)
        ns.db.alertSize = Round(v)
        ApplyAlerts()
    end,
    function(v) return string.format("%d", Round(v)) end)

MakeSlider(panel, "Warning stays on screen for", -240, 1, 10, 0.5,
    function() return ns.db.alertDuration end,
    function(v) ns.db.alertDuration = v end,
    Seconds)

MakeLabel(panel, "Despawn warning", "GameFontNormalLarge", 16, -276)
local despawnNote = MakeLabel(panel, "Totems despawn when you are more than 100 yards away from them. Text size and time on screen match the leaving range warning.", "GameFontHighlightSmall", 16, -298)
despawnNote:SetWidth(580)
despawnNote:SetJustifyH("LEFT")

MakeCheckbox(panel, "Show warning on screen", 16, -318,
    function() return ns.db.despawnAlert end,
    function(v) ns.db.despawnAlert = v end)

MakeCheckbox(panel, "Play a sound", 240, -318,
    function() return ns.db.despawnSound end,
    function(v) ns.db.despawnSound = v end)

MakeSlider(panel, "Warn this many yards before", -356, 5, 40, 1,
    function() return ns.db.despawnWarnYards end,
    function(v) ns.db.despawnWarnYards = Round(v) end,
    Yards)

local preview = MakeButton(panel, "Preview warnings", 150, function() ns.PreviewAlerts() end)
preview:SetPoint("TOPLEFT", 16, -396)

local resetPosition = MakeButton(panel, "Reset position", 130, function() ns.ResetTrackerPosition() end)
resetPosition:SetPoint("LEFT", preview, "RIGHT", 12, 0)

local test = MakeButton(panel, "Toggle test totems", 160, function() ns.SetTestMode(not ns.testMode) end)
test:SetPoint("LEFT", resetPosition, "RIGHT", 12, 0)

-- Second page: which totems to track, by element, with each element's color.

local COLUMN_WIDTH = 150
local ROW_STEP = 24

MakeLabel(totemsPanel, "Tracked totems", "GameFontNormalHuge", 16, -16)
local totemsNote = MakeLabel(totemsPanel, "Only checked totems appear in the tracker and trigger warnings. Click a color to change that element's icon border.", "GameFontHighlightSmall", 16, -46)
totemsNote:SetWidth(580)
totemsNote:SetJustifyH("LEFT")

local function SetAllTracked(tracked)
    for base in pairs(ns.TOTEM_RANGES) do
        ns.db.untracked[base] = (not tracked) or nil
    end
    RefreshPanel()
end

for slot = 1, 4 do
    local x = 16 + (slot - 1) * COLUMN_WIDTH
    local header = MakeLabel(totemsPanel, ns.ELEMENTS[slot].label, "GameFontNormalLarge", x, -76)
    MakeSwatch(totemsPanel, slot, header)
    for i, base in ipairs(ns.TOTEMS_BY_SLOT[slot]) do
        MakeCheckbox(totemsPanel, ns.DisplayName(base), x, -98 - (i - 1) * ROW_STEP,
            function() return not ns.db.untracked[base] end,
            function(v) ns.db.untracked[base] = (not v) or nil end,
            true)
    end
end

local selectAll = MakeButton(totemsPanel, "Track all", 110, function() SetAllTracked(true) end)
selectAll:SetPoint("TOPLEFT", 16, -260)

local selectNone = MakeButton(totemsPanel, "Track none", 110, function() SetAllTracked(false) end)
selectNone:SetPoint("LEFT", selectAll, "RIGHT", 12, 0)

local resetColors = MakeButton(totemsPanel, "Reset colors", 120, function()
    ns.ResetColors()
    RefreshPanel()
end)
resetColors:SetPoint("LEFT", selectNone, "RIGHT", 12, 0)

for _, p in ipairs({ panel, totemsPanel }) do
    p:SetScript("OnShow", RefreshPanel)
    p.OnRefresh = RefreshPanel
end

local category
if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    if Settings.RegisterCanvasLayoutSubcategory then
        Settings.RegisterCanvasLayoutSubcategory(category, totemsPanel, totemsPanel.name)
    end
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
    InterfaceOptions_AddCategory(totemsPanel)
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
    ns.Print(string.format("enabled=%s test=%s locked=%s alert=%s sound=%s size=%d duration=%.1f warn=%d",
        tostring(db.enabled), tostring(ns.testMode), tostring(db.locked), tostring(db.alert), tostring(db.sound),
        db.alertSize, db.alertDuration, db.warnYards))
    ns.Print(string.format("despawn: alert=%s sound=%s at=%d warnBefore=%d", tostring(db.despawnAlert),
        tostring(db.despawnSound), ns.DESPAWN_YARDS, db.despawnWarnYards))
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
        if entry and entry.hidden then
            ns.Print(string.format("    hidden: %s", entry.hidden))
        end
        local ok, have, name, start, duration = pcall(GetTotemInfo, slot)
        if ok and not (ns.IsSecret(have) or ns.IsSecret(name) or ns.IsSecret(start) or ns.IsSecret(duration)) then
            if not have or name == "" then
                ns.Print("    game reports: nothing")
            else
                ns.Print(string.format("    game reports: %s, started %s s ago, lasts %s s", name,
                type(start) == "number" and string.format("%.1f", GetTime() - start) or "?",
                    tostring(duration)))
            end
        else
            ns.Print("    game reports: hidden values")
        end
    end
    if #ns.history == 0 then
        ns.Print("recently removed: none")
    else
        ns.Print("recently removed, newest first:")
        for _, h in ipairs(ns.history) do
            ns.Print(string.format("    %s, %ds ago: %s", h.name, math.floor(GetTime() - h.time), h.reason))
        end
    end
end

local HELP = {
    "/totemdistance - open settings",
    "/totemdistance on | off - enable or disable",
    "/totemdistance lock | unlock - lock the interface in place or allow dragging it",
    "/totemdistance resetpos - move the tracker back to its default spot",
    "/totemdistance alert on | off - flashing on-screen warning when you leave a totem's range",
    "/totemdistance sound on | off - sound when you leave a totem's range",
    "/totemdistance warn <0-15> - yards from the edge where the bar turns yellow",
    "/totemdistance size <12-48> - warning text size",
    "/totemdistance duration <1-10> - seconds a warning stays on screen",
    "/totemdistance despawn on | off - warning when a totem is about to despawn",
    "/totemdistance despawnsound on | off - sound with the despawn warning",
    "/totemdistance despawnwarn <5-40> - warn this many yards before despawn",
    "/totemdistance track - list tracked totems; track <totem name> on | off to change one",
    "/totemdistance preview - show both warnings with sample text",
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
    elseif cmd == "size" then
        local v = tonumber(rest)
        if not v then return ns.Print("Usage: /totemdistance size <12-48>") end
        db.alertSize = math.floor(math.max(12, math.min(48, v)) + 0.5)
        ns.ApplyAlertSettings()
        ns.PreviewAlerts()
    elseif cmd == "duration" then
        local v = tonumber(rest)
        if not v then return ns.Print("Usage: /totemdistance duration <1-10>") end
        db.alertDuration = math.max(1, math.min(10, v))
    elseif cmd == "despawn" then
        db.despawnAlert = Toggle(rest, db.despawnAlert)
        ns.Print(db.despawnAlert and "despawn warning on" or "despawn warning off")
    elseif cmd == "despawnsound" then
        db.despawnSound = Toggle(rest, db.despawnSound)
        ns.Print(db.despawnSound and "despawn sound on" or "despawn sound off")
    elseif cmd == "despawnwarn" then
        local v = tonumber(rest)
        if not v then return ns.Print("Usage: /totemdistance despawnwarn <5-40>") end
        db.despawnWarnYards = math.floor(math.max(5, math.min(40, v)) + 0.5)
    elseif cmd == "preview" then
        ns.PreviewAlerts()
    elseif cmd == "track" then
        local nameText, state = rest:lower():match("^(.-)%s+(on)$")
        if not nameText then nameText, state = rest:lower():match("^(.-)%s+(off)$") end
        if rest == "" then
            local on, off = {}, {}
            for slot = 1, 4 do
                for _, base in ipairs(ns.TOTEMS_BY_SLOT[slot]) do
                    local list = db.untracked[base] and off or on
                    list[#list + 1] = ns.DisplayName(base)
                end
            end
            ns.Print("Tracked: " .. (#on > 0 and table.concat(on, ", ") or "none"))
            ns.Print("Not tracked: " .. (#off > 0 and table.concat(off, ", ") or "none"))
            return
        end
        local base = nameText and ns.BaseName(nameText)
        if base and not ns.TOTEM_RANGES[base] then base = base .. " totem" end
        if not (base and ns.TOTEM_RANGES[base]) then
            return ns.Print("Usage: /totemdistance track <totem name> on | off, for example: track windfury off")
        end
        db.untracked[base] = (state == "off") or nil
        ns.Print(string.format("%s %s", ns.DisplayName(base), state == "off" and "not tracked" or "tracked"))
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
    if panel:IsShown() or totemsPanel:IsShown() then RefreshPanel() end
end
