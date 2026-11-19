local ADDON, ns = ...

-- Slot order matches GetTotemInfo(): Fire = 1, Earth = 2, Water = 3, Air = 4.
ns.ELEMENTS = {
    [1] = { key = "FIRE",  label = "Fire",  color = { 1.00, 0.30, 0.12 } },
    [2] = { key = "EARTH", label = "Earth", color = { 0.55, 0.35, 0.16 } },
    [3] = { key = "WATER", label = "Water", color = { 0.10, 0.45, 1.00 } },
    [4] = { key = "AIR",   label = "Air",   color = { 0.82, 0.95, 0.98 } },
}

-- Range in yards, keyed by lowercase totem name without rank suffix.
-- verified = false marks values taken from Classic or inferred; check them
-- against the in-game tooltip with /totemdistance debug.
ns.TOTEM_RANGES = {
    ["searing totem"]            = { range = 20, verified = true },
    ["magma totem"]              = { range = 8,  verified = true },
    ["flametongue totem"]        = { range = 30, verified = true },
    ["frost resistance totem"]   = { range = 30, verified = true },

    ["earthbind totem"]          = { range = 10, verified = true },
    ["stoneclaw totem"]          = { range = 8,  verified = true },
    ["stoneskin totem"]          = { range = 30, verified = true },
    ["strength of earth totem"]  = { range = 30, verified = true },
    ["tremor totem"]             = { range = 30, verified = true },

    ["healing stream totem"]     = { range = 30, verified = true },
    ["mana spring totem"]        = { range = 30, verified = true },
    ["fire resistance totem"]    = { range = 30, verified = true },
    ["poison cleansing totem"]   = { range = 30, verified = false },
    ["disease cleansing totem"]  = { range = 30, verified = false },
    ["mana tide totem"]          = { range = 30, verified = false },

    ["grace of air totem"]       = { range = 30, verified = true },
    ["windfury totem"]           = { range = 30, verified = true },
    ["nature resistance totem"]  = { range = 30, verified = false },
    ["grounding totem"]          = { range = 30, verified = false },
    ["sentry totem"]             = { range = 40, verified = false },
}

ns.DEFAULT_RANGE = 20

function ns.BaseName(name)
    local base = string.lower(name or "")
    base = base:gsub("%s*%b()", "")
    base = base:gsub("%s+[ivx]+$", "")
    base = base:gsub("%s+%d+$", "")
    base = base:gsub("^%s+", ""):gsub("%s+$", "")
    return base
end

local function GetSpellIDByName(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        if ok and type(info) == "table" then
            return info.spellID
        end
    elseif GetSpellInfo then
        local ok, _, _, _, _, _, _, spellID = pcall(GetSpellInfo, name)
        if ok then
            return spellID
        end
    end
end

local function ParseRangeFromDescription(spellID)
    if not spellID then return end
    local getter = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    if not getter then return end
    local ok, desc = pcall(getter, spellID)
    if not ok or type(desc) ~= "string" then return end
    local yards = desc:match("(%d+)%s*[Yy]ards?") or desc:match("(%d+)%s*[Yy]d")
    return yards and tonumber(yards) or nil
end

-- Returns range in yards, the source ("override", "table", "tooltip", "default"),
-- and whether the value is verified for Forever.
function ns.ResolveRange(slot, name, spellID)
    local override = ns.db and ns.db.rangeOverrides and ns.db.rangeOverrides[slot]
    if override then
        return override, "override", true
    end

    local base = ns.BaseName(name)
    local entry = ns.TOTEM_RANGES[base]
    if entry then
        return entry.range, "table", entry.verified
    end

    spellID = spellID or GetSpellIDByName(name)
    local parsed = ParseRangeFromDescription(spellID)
    if parsed and parsed > 0 then
        return parsed, "tooltip", false
    end

    return ns.DEFAULT_RANGE, "default", false
end
