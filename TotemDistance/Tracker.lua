local ADDON, ns = ...

-- Distance tracker: how far the player is from each totem's drop point. The
-- totem lands at the player's feet, so the drop point is the player's world
-- position when PLAYER_TOTEM_UPDATE fired.

local NUM_SLOTS = 4
local ROW_HEIGHT = 34
local ICON_SIZE = 26
local BAR_WIDTH = 170
local BAR_HEIGHT = 12
local WIDTH = ICON_SIZE + 4 + 6 + BAR_WIDTH
local DEFAULT_POINT = { "CENTER", "CENTER", 0, -200 }
local LEAVE_SOUND = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959

local GREEN = { 0.25, 0.85, 0.30 }
local YELLOW = { 1.00, 0.80, 0.10 }
local RED = { 1.00, 0.20, 0.15 }
local GREY = { 0.50, 0.50, 0.50 }

local TEST_ICONS = {
    "Interface\\Icons\\Spell_Fire_SearingTotem",
    "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02",
    "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
    "Interface\\Icons\\Spell_Nature_Windfury",
}

local tracker = CreateFrame("Frame", "TotemDistanceFrame", UIParent)
tracker:SetSize(WIDTH, ROW_HEIGHT)
tracker:SetFrameStrata("MEDIUM")
tracker:SetClampedToScreen(true)
tracker:SetMovable(true)
tracker:RegisterForDrag("LeftButton")
tracker:Hide()
ns.tracker = tracker

tracker:SetScript("OnDragStart", function(self)
    if not ns.db.locked then self:StartMoving() end
end)
tracker:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    if point then ns.db.point = { point, relPoint, x, y } end
end)
tracker:SetScript("OnEnter", function(self)
    if ns.db.locked or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("TotemDistance")
    GameTooltip:AddLine("Drag to move. Lock it with /totemdistance lock.", 1, 1, 1)
    GameTooltip:Show()
end)
tracker:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
end)

local function NewRow(index)
    local row = CreateFrame("Frame", nil, tracker)
    row:SetSize(WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

    row.border = row:CreateTexture(nil, "BACKGROUND")
    row.border:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
    row.border:SetPoint("LEFT", 0, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("CENTER", row.border, "CENTER", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
    row.bar:SetPoint("BOTTOMLEFT", row.border, "BOTTOMRIGHT", 6, 2)
    row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.bar:SetMinMaxValues(0, 1)

    local barBg = row.bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0, 0, 0, 0.6)

    row.barText = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.barText:SetPoint("CENTER", row.bar, "CENTER", 0, 0)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("BOTTOMLEFT", row.bar, "TOPLEFT", 0, 2)
    row.label:SetWidth(BAR_WIDTH - 70)
    row.label:SetJustifyH("LEFT")
    if row.label.SetWordWrap then row.label:SetWordWrap(false) end

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.status:SetPoint("BOTTOMRIGHT", row.bar, "TOPRIGHT", 0, 2)
    row.status:SetJustifyH("RIGHT")

    return row
end

local rows = {}
local testSubjects = {}
local pulse = 0

local ALERT_DURATION = 3
local ALERT_FLASH = 1.5

local alert = CreateFrame("Frame", "TotemDistanceAlert", UIParent)
alert:SetSize(600, 40)
alert:SetPoint("TOP", UIParent, "TOP", 0, -170)
alert:SetFrameStrata("HIGH")
alert:EnableMouse(false)
alert:Hide()
alert.text = alert:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
alert.text:SetPoint("CENTER")
if STANDARD_TEXT_FONT then alert.text:SetFont(STANDARD_TEXT_FONT, 28, "THICKOUTLINE") end
alert.text:SetTextColor(RED[1], RED[2], RED[3])
alert.elapsed = 0
alert:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    local e = self.elapsed
    if e >= ALERT_DURATION then
        self:Hide()
    elseif e < ALERT_FLASH then
        self:SetAlpha(0.4 + 0.6 * math.abs(math.cos(e * 6)))
    else
        self:SetAlpha(1 - (e - ALERT_FLASH) / (ALERT_DURATION - ALERT_FLASH))
    end
end)
ns.alert = alert

local function ShowAlert(subject)
    alert.subject = subject
    alert.text:SetText("Out of " .. subject.name:gsub(" [Tt]otem", "") .. " range!")
    alert.elapsed = 0
    alert:SetAlpha(1)
    alert:Show()
end

function ns.ApplyTrackerSettings()
    local db = ns.db
    local p = db.point
    if type(p) ~= "table" or not p[1] then p = DEFAULT_POINT end
    tracker:ClearAllPoints()
    tracker:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    tracker:EnableMouse(not db.locked)
end

function ns.ResetTrackerPosition()
    ns.db.point = {}
    ns.ApplyTrackerSettings()
end

-- Test subjects stand in for totems dropped where the player is when test mode starts.
function ns.ResetTestSubjects()
    local n, w = ns.PlayerWorldPosition()
    for slot = 1, NUM_SLOTS do
        testSubjects[slot] = {
            name = "Test " .. ns.ELEMENTS[slot].label,
            range = ns.TEST_RANGES[slot],
            icon = TEST_ICONS[slot],
            worldN = n,
            worldW = w,
        }
    end
end

function ns.TestSubject(slot)
    if not testSubjects[slot] then ns.ResetTestSubjects() end
    return testSubjects[slot]
end

-- Yards from the subject's drop point, or nil when positions are unavailable.
function ns.DistanceFromDrop(subject)
    if not subject.worldN then return nil end
    local n, w = ns.PlayerWorldPosition()
    if not n then return nil end
    local dN, dW = n - subject.worldN, w - subject.worldW
    return math.sqrt(dN * dN + dW * dW)
end

local function ShortName(name)
    return (name:gsub(" [Tt]otem", ""))
end

local function UpdateRow(row, slot, subject)
    local db = ns.db
    local element = ns.GetColor(slot)
    local range = subject.range
    local distance = ns.DistanceFromDrop(subject)

    row.icon:SetTexture(subject.icon or TEST_ICONS[slot])
    row.label:SetText(ShortName(subject.name))

    local color, out
    if not distance then
        color = GREY
        row.bar:SetValue(1)
        row.barText:SetText("? / " .. range .. " yd")
        row.status:SetText("no position here")
    else
        local remaining = range - distance
        out = remaining < 0
        row.bar:SetValue(math.max(0, math.min(1, remaining / range)))
        row.barText:SetText(string.format("%d / %d yd", math.floor(distance + 0.5), range))
        if out then
            color = RED
            row.status:SetText(string.format("OUT by %d yd", math.ceil(-remaining)))
        else
            color = remaining < db.warnYards and YELLOW or GREEN
            row.status:SetText(string.format("%d yd left", math.floor(remaining)))
        end
    end

    row.bar:SetStatusBarColor(color[1], color[2], color[3])
    row.status:SetTextColor(color[1], color[2], color[3])
    row.icon:SetDesaturated(out == true)

    if out then
        local a = 0.55 + 0.45 * math.sin(pulse * 8)
        row.border:SetColorTexture(RED[1], RED[2], RED[3], a)
    else
        row.border:SetColorTexture(element[1], element[2], element[3], 1)
    end

    if out and not subject.wasOut then
        if db.alert then ShowAlert(subject) end
        if db.sound then PlaySound(LEAVE_SOUND, "Master") end
    elseif not out and alert.subject == subject then
        alert:Hide()
        alert.subject = nil
    end
    if distance then subject.wasOut = out end
end

function ns.UpdateTracker(elapsed)
    local db = ns.db
    pulse = pulse + (elapsed or 0)
    local shown = 0

    if db.enabled then
        for slot = 1, NUM_SLOTS do
            local subject
            if ns.testMode then
                subject = ns.TestSubject(slot)
            else
                subject = ns.state[slot]
            end
            if subject and db.slotEnabled[slot] then
                shown = shown + 1
                local row = rows[shown] or NewRow(shown)
                rows[shown] = row
                UpdateRow(row, slot, subject)
                row:Show()
            end
        end
    end

    for i = shown + 1, #rows do rows[i]:Hide() end
    if shown > 0 then
        tracker:SetHeight(shown * ROW_HEIGHT)
        tracker:Show()
    else
        tracker:Hide()
    end
end
