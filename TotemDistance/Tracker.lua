local ADDON, ns = ...

-- Distance tracker: how far the player is from each totem's recorded position,
-- with warnings when the player leaves a totem's range or nears despawn distance.

local NUM_SLOTS = 4
local ROW_HEIGHT = 34
local ICON_SIZE = 26
local BAR_WIDTH = 170
local BAR_HEIGHT = 12
local WIDTH = ICON_SIZE + 4 + 6 + BAR_WIDTH
local DEFAULT_POINT = { "CENTER", "CENTER", 0, -200 }
local LEAVE_SOUND = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959
local DESPAWN_SOUND = (SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3) or 12867
-- Yards the player must come back inside the despawn warning before it can fire again.
local DESPAWN_REARM = 3

local GREEN = { 0.25, 0.85, 0.30 }
local YELLOW = { 1.00, 0.80, 0.10 }
local RED = { 1.00, 0.20, 0.15 }
local GREY = { 0.50, 0.50, 0.50 }
local ORANGE = { 1.00, 0.55, 0.10 }

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
    GameTooltip:AddLine("Drag to move. Turn on Lock Interface In Place in settings, or type /totemdistance lock.", 1, 1, 1)
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

local ALERT_TOP = -170
local ALERT_GAP = 12

local function AlertFlashTime(duration)
    return math.min(1.5, duration / 2)
end

local function NewAlert(name, color)
    local alert = CreateFrame("Frame", name, UIParent)
    alert:SetSize(700, 40)
    alert:SetFrameStrata("HIGH")
    alert:EnableMouse(false)
    alert:Hide()
    alert.text = alert:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    alert.text:SetPoint("CENTER")
    alert.text:SetTextColor(color[1], color[2], color[3])
    alert.elapsed = 0
    alert:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        local e = self.elapsed
        local duration = ns.db.alertDuration
        local flash = AlertFlashTime(duration)
        if e >= duration then
            self:Hide()
            self.subject = nil
        elseif e < flash then
            self:SetAlpha(0.4 + 0.6 * math.abs(math.cos(e * 6)))
        else
            self:SetAlpha(1 - (e - flash) / (duration - flash))
        end
    end)
    return alert
end

local alert = NewAlert("TotemDistanceAlert", RED)
local despawnAlert = NewAlert("TotemDistanceDespawnAlert", ORANGE)
ns.alert = alert
ns.despawnAlert = despawnAlert

local function ShowAlert(frame, subject, text)
    frame.subject = subject
    frame.text:SetText(text)
    frame.elapsed = 0
    frame:SetAlpha(1)
    frame:Show()
end

local function HideAlert(frame, subject)
    if frame.subject == subject then
        frame:Hide()
        frame.subject = nil
    end
end

local function PlayAlertSound(id)
    pcall(PlaySound, id, "Master")
end

function ns.ApplyAlertSettings()
    local size = ns.db.alertSize
    for i, frame in ipairs({ alert, despawnAlert }) do
        frame.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "THICKOUTLINE")
        frame:SetHeight(size + 12)
        frame:ClearAllPoints()
        frame:SetPoint("TOP", UIParent, "TOP", 0, ALERT_TOP - (i - 1) * (size + 12 + ALERT_GAP))
    end
end

-- Shows both alerts with sample text so their size and duration can be judged.
function ns.PreviewAlerts()
    ShowAlert(alert, nil, "Out of Strength of Earth range!")
    ShowAlert(despawnAlert, nil, "Strength of Earth is about to despawn!")
end

function ns.ApplyTrackerSettings()
    local db = ns.db
    local p = db.point
    if type(p) ~= "table" or not p[1] then p = DEFAULT_POINT end
    tracker:ClearAllPoints()
    tracker:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    tracker:EnableMouse(not db.locked)
    ns.ApplyAlertSettings()
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

    local color, out, nearDespawn
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
        local toDespawn = ns.DESPAWN_YARDS - distance
        nearDespawn = toDespawn <= db.despawnWarnYards
        if out then
            color = RED
            row.status:SetText(string.format("OUT by %d yd", math.ceil(-remaining)))
            if nearDespawn then
                row.barText:SetText(string.format("despawn in %d yd", math.max(0, math.floor(toDespawn))))
                row.barText:SetTextColor(ORANGE[1], ORANGE[2], ORANGE[3])
            end
        else
            color = remaining < db.warnYards and YELLOW or GREEN
            row.status:SetText(string.format("%d yd left", math.floor(remaining)))
        end
    end

    if not nearDespawn then row.barText:SetTextColor(1, 1, 1) end
    row.bar:SetStatusBarColor(color[1], color[2], color[3])
    row.status:SetTextColor(color[1], color[2], color[3])
    row.icon:SetDesaturated(out == true)

    if out then
        local a = 0.55 + 0.45 * math.sin(pulse * 8)
        row.border:SetColorTexture(RED[1], RED[2], RED[3], a)
    else
        row.border:SetColorTexture(element[1], element[2], element[3], 1)
    end

    local name = ShortName(subject.name)
    if out and not subject.wasOut then
        if db.alert then ShowAlert(alert, subject, "Out of " .. name .. " range!") end
        if db.sound then PlayAlertSound(LEAVE_SOUND) end
    elseif not out then
        HideAlert(alert, subject)
    end
    if distance then subject.wasOut = out end

    if nearDespawn and not subject.despawnWarned then
        subject.despawnWarned = true
        if db.despawnAlert then
            ShowAlert(despawnAlert, subject, name .. " is about to despawn!")
            if db.despawnSound then PlayAlertSound(DESPAWN_SOUND) end
        end
    elseif distance and subject.despawnWarned
        and ns.DESPAWN_YARDS - distance > db.despawnWarnYards + DESPAWN_REARM then
        subject.despawnWarned = nil
        HideAlert(despawnAlert, subject)
    end
end

local function IsDespawned(subject)
    if subject.hidden then return true end
    local distance = ns.DistanceFromDrop(subject)
    if distance and distance > ns.DESPAWN_YARDS then
        ns.HideEntry(subject, string.format("you went more than %d yd away", ns.DESPAWN_YARDS))
        HideAlert(alert, subject)
        HideAlert(despawnAlert, subject)
        return true
    end
    return false
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
            if subject and ns.IsTracked(subject) and not IsDespawned(subject) then
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
