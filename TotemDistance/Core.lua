local ADDON, ns = ...

local UPDATE_INTERVAL = 0.05
local NUM_SLOTS = 4

ns.NUM_SLOTS = NUM_SLOTS
-- Totems despawn once the player is more than this many yards away.
ns.DESPAWN_YARDS = 100
ns.TEST_RANGES = { [1] = 20, [2] = 10, [3] = 30, [4] = 5 }

ns.defaults = {
    enabled = true,
    locked = false,
    sound = true,
    alert = true,
    alertSize = 28,
    alertDuration = 3,
    warnYards = 5,
    despawnAlert = true,
    despawnSound = true,
    despawnWarnYards = 15,
    untracked = {},
    point = {},
    colors = {},
    rangeOverrides = {},
}

ns.state = {}
ns.testMode = false

function ns.Print(msg)
    print("|cff33ff99TotemDistance|r: " .. tostring(msg))
end

function ns.CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ns.CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function ns.GetColor(slot)
    local c = ns.db.colors[slot]
    if c then return c end
    return ns.ELEMENTS[slot].color
end

function ns.ResetColors()
    wipe(ns.db.colors)
end

function ns.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local function SafeNumber(fn, ...)
    if not fn then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok or ns.IsSecret(a) or ns.IsSecret(b) or type(a) ~= "number" then return nil end
    return a, b
end

-- World position in yards as (north, west), or nil in instances.
function ns.PlayerWorldPosition()
    local n, w = SafeNumber(UnitPosition, "player")
    if type(w) ~= "number" then return nil end
    return n, w
end

-- Totems are placed around the player relative to the way the player faces:
-- Fire front-left, Earth front-right, Water back-right, Air back-left.
-- Angles are counterclockwise from the facing direction, like GetPlayerFacing().
local PLACE_DISTANCE = 2.5
local PLACE_ANGLES = { math.pi / 4, -math.pi / 4, -3 * math.pi / 4, 3 * math.pi / 4 }
ns.PLACE_DISTANCE = PLACE_DISTANCE
ns.PLACE_ANGLES = PLACE_ANGLES

-- Where a totem of `slot` lands if cast now, as (north, west). Falls back to
-- the player's feet when the facing is unavailable, or nil in instances.
function ns.TotemPlacement(slot)
    local n, w = ns.PlayerWorldPosition()
    if not n then return nil end
    local facing = SafeNumber(GetPlayerFacing)
    if not facing then return n, w end
    local a = facing + PLACE_ANGLES[slot]
    return n + PLACE_DISTANCE * math.cos(a), w + PLACE_DISTANCE * math.sin(a)
end

-- How long the game must keep reporting an empty slot before its row goes away.
-- A single empty read can be a blip while the totem is still up.
local MISSING_GRACE = 0.5
local POLL_INTERVAL = 0.25
local HISTORY_SIZE = 8

-- Returns "active" plus the totem's details, "none" for an empty slot, or
-- "unknown" when the game hides the values (secret values) or the call fails.
local function ReadTotem(slot)
    local ok, haveTotem, name, startTime, duration, icon, _, spellID = pcall(GetTotemInfo, slot)
    if not ok then return "unknown" end
    if ns.IsSecret(haveTotem) or ns.IsSecret(name) or ns.IsSecret(startTime) or ns.IsSecret(duration) then
        return "unknown"
    end
    if not haveTotem or type(name) ~= "string" or name == "" then
        return "none"
    end
    if ns.IsSecret(spellID) then spellID = nil end
    return "active", name, startTime, duration, spellID, icon
end

-- Recent reasons a totem's row went away, newest first, for /totemdistance debug.
ns.history = {}

local function Remember(entry, reason)
    table.insert(ns.history, 1, { time = GetTime(), name = entry.name, reason = reason })
    ns.history[HISTORY_SIZE + 1] = nil
end

-- Hides a totem the game may still list. The entry stays so later reads of the
-- same totem don't record it again at the player's feet.
function ns.HideEntry(entry, reason)
    if entry.hidden then return end
    entry.hidden = reason
    Remember(entry, reason)
end

local function Forget(slot, reason)
    local entry = ns.state[slot]
    if not entry then return end
    if not entry.hidden then Remember(entry, reason) end
    ns.state[slot] = nil
end

-- Totem spells the player just cast, by base name. A recast always gets a fresh
-- bar, even if the game still reports the old totem's start time.
local RECAST_WINDOW = 2
local recentCasts = {}

function ns.NoteTotemCast(spellName)
    local base = spellName and ns.BaseName(spellName)
    if not (base and ns.TOTEM_RANGES[base]) then return false end
    for slot = 1, NUM_SLOTS do
        local entry = ns.state[slot]
        if entry and entry.base == base and not entry.hidden
            and GetTime() - (entry.createdAt or 0) < MISSING_GRACE then
            return true
        end
    end
    recentCasts[base] = GetTime()
    ns.UpdateAllSlots()
    return true
end

local function IsSameTotem(entry, name, startTime)
    if entry.name ~= name then return false end
    if type(entry.startTime) ~= "number" or type(startTime) ~= "number" then
        return entry.startTime == startTime
    end
    return math.abs(entry.startTime - startTime) < 0.5
end

function ns.IsTracked(subject)
    return not (subject.base and ns.db.untracked[subject.base])
end

local function CheckTimer(entry)
    if entry.expires and not entry.hidden and GetTime() >= entry.expires then
        ns.HideEntry(entry, "timer ran out")
    end
end

-- A totem's position is taken from where the player stood and faced when the
-- game first reported it.
function ns.UpdateSlot(slot)
    local status, name, startTime, duration, spellID, icon = ReadTotem(slot)
    local entry = ns.state[slot]
    if status == "unknown" then
        if entry then CheckTimer(entry) end
        return
    end

    if status == "none" then
        if not entry then return end
        if entry.expires and GetTime() >= entry.expires - MISSING_GRACE then
            return Forget(slot, "timer ran out")
        end
        entry.missingSince = entry.missingSince or GetTime()
        if GetTime() - entry.missingSince >= MISSING_GRACE then
            Forget(slot, "game reports it gone (destroyed, recalled or despawned)")
        end
        return
    end

    local base = ns.BaseName(name)
    local castAt = recentCasts[base]
    if castAt and GetTime() - castAt > RECAST_WINDOW then
        recentCasts[base] = nil
        castAt = nil
    end
    local recast = castAt and entry and entry.base == base and entry.createdAt < castAt
    if entry and IsSameTotem(entry, name, startTime) and not recast then
        entry.missingSince = nil
        CheckTimer(entry)
        return
    end
    recentCasts[base] = nil

    local range, source, verified = ns.ResolveRange(slot, name, spellID)
    entry = {
        name = name,
        base = base,
        startTime = startTime,
        duration = duration,
        spellID = spellID,
        icon = icon,
        range = range,
        source = source,
        verified = verified,
        createdAt = GetTime(),
    }
    -- A totem that is new to us but whose reported timer is already over means
    -- the game is still reporting the previous totem's start time. Time it from
    -- the cast instead, or leave it to the game when the cast wasn't seen.
    if type(startTime) == "number" and type(duration) == "number" and duration > 0 then
        entry.expires = startTime + duration
        if entry.expires <= GetTime() then
            entry.expires = castAt and castAt + duration or nil
        end
    end
    entry.worldN, entry.worldW = ns.TotemPlacement(slot)
    ns.state[slot] = entry
    if source == "default" then
        ns.Print(string.format("No range known for \"%s\"; using %d yards. Use /totemdistance range %d <yards> to set it.", name, range, slot))
    end
end

function ns.UpdateAllSlots()
    for slot = 1, NUM_SLOTS do
        ns.UpdateSlot(slot)
    end
end

function ns.SetTestMode(enabled)
    ns.testMode = enabled
    if enabled then ns.ResetTestSubjects() end
end

-- Spells that move all active totems back around the player, to the spots
-- they would take if recast now.
local MOVE_SPELLS = { ["totemic call"] = true, ["totemic projection"] = true }
-- Spells that clear every bar as soon as the player tries to cast them, even
-- if the cast fails because no totems are down.
local CLEAR_SPELLS = { ["totemic recall"] = true }

local function SpellName(spellID)
    if type(spellID) ~= "number" or ns.IsSecret(spellID) then return nil end
    local getter = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if not getter then return nil end
    local ok, name = pcall(getter, spellID)
    if not ok or type(name) ~= "string" or ns.IsSecret(name) then return nil end
    return string.lower(name)
end

-- Moves every active totem's recorded position to where it would land if recast now.
function ns.MoveTotemsToPlayer()
    local moved = 0
    for slot = 1, NUM_SLOTS do
        local entry = ns.state[slot]
        if entry and entry.hidden ~= "timer ran out" then
            entry.worldN, entry.worldW = ns.TotemPlacement(slot)
            entry.hidden = nil
            entry.wasOut = nil
            entry.despawnWarned = nil
            moved = moved + 1
        end
    end
    return moved
end

-- Hides every bar, including test totems. A totem the game still lists stays
-- hidden; a newly dropped totem gets a bar again.
function ns.ClearAllBars(reason)
    for slot = 1, NUM_SLOTS do
        local entry = ns.state[slot]
        if entry then ns.HideEntry(entry, reason) end
        if ns.testMode then ns.HideEntry(ns.TestSubject(slot), reason) end
    end
    ns.HideAlerts()
end

local function OnCastAttempt(name)
    if name and CLEAR_SPELLS[name] then ns.ClearAllBars("Totemic Recall cast") end
end

-- Catches button presses, macros and /cast before the game checks whether the
-- spell can be cast; a press with no totems down produces no cast events.
local function ActionSpellName(action)
    local kind, id = GetActionInfo(action)
    if kind == "macro" and GetMacroSpell then
        kind, id = "spell", GetMacroSpell(id)
    end
    if kind == "spell" then return SpellName(id) end
end

local function SpellNameFromText(text)
    if type(text) ~= "string" or ns.IsSecret(text) then return nil end
    return (string.lower(text):gsub("%s*%b()", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function HookCast(fnName, toName)
    if not (hooksecurefunc and _G[fnName]) then return end
    hooksecurefunc(fnName, function(value)
        if not ns.db then return end
        local ok, name = pcall(toName, value)
        if ok then OnCastAttempt(name) end
    end)
end

if GetActionInfo then HookCast("UseAction", ActionSpellName) end
HookCast("CastSpellByName", SpellNameFromText)
HookCast("CastSpellByID", SpellName)
if C_Spell and C_Spell.CastSpell and hooksecurefunc then
    hooksecurefunc(C_Spell, "CastSpell", function(spell)
        if not ns.db then return end
        local ok, name = pcall(function()
            return type(spell) == "number" and SpellName(spell) or SpellNameFromText(spell)
        end)
        if ok then OnCastAttempt(name) end
    end)
end

local frame = CreateFrame("Frame")
ns.eventFrame = frame

local CAST_EVENTS = {
    "UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_FAILED_QUIET",
    "UNIT_SPELLCAST_SUCCEEDED",
}

frame:SetScript("OnEvent", function(_, event, arg1, ...)
    if event == "UNIT_SPELLCAST_SENT" then
        local _, _, spellID = ...
        if arg1 == "player" then OnCastAttempt(SpellName(spellID)) end
        return
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET" then
        local _, spellID = ...
        if arg1 == "player" then OnCastAttempt(SpellName(spellID)) end
        return
    end
    local _, spellID = ...
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        TotemDistanceDB = TotemDistanceDB or {}
        ns.CopyDefaults(ns.defaults, TotemDistanceDB)
        ns.db = TotemDistanceDB
        ns.ApplyTrackerSettings()
        ns.RefreshOptions()
        frame:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_TOTEM_UPDATE" then
        if arg1 and arg1 >= 1 and arg1 <= NUM_SLOTS then
            ns.UpdateSlot(arg1)
        else
            ns.UpdateAllSlots()
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg1 ~= "player" then return end
        local name = SpellName(spellID)
        if MOVE_SPELLS[name] then
            ns.MoveTotemsToPlayer()
        elseif not ns.NoteTotemCast(name) then
            OnCastAttempt(name)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.UpdateAllSlots()
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TOTEM_UPDATE")
for _, event in ipairs(CAST_EVENTS) do
    if frame.RegisterUnitEvent then
        frame:RegisterUnitEvent(event, "player")
    else
        frame:RegisterEvent(event)
    end
end

-- The game doesn't always send PLAYER_TOTEM_UPDATE when a totem despawns, so
-- the slots are also re-read on a timer.
local sinceUpdate = 0
local sincePoll = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    if not ns.db then return end
    sincePoll = sincePoll + elapsed
    if sincePoll >= POLL_INTERVAL then
        sincePoll = 0
        ns.UpdateAllSlots()
    end
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < UPDATE_INTERVAL then return end
    ns.UpdateTracker(sinceUpdate)
    sinceUpdate = 0
end)
