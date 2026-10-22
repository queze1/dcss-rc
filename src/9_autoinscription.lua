local inscription_properties = {
    Will = true,
    rC = true,
    rF = true,
    rN = true,
    Regen = true,
    Stlth = true,
    Str = true,
    Int = true,
    Dex = true,
    Slay = true,
    EV = true,
    AC = true,
    MP = true,
    rCorr = true,
    rElec = true,
    rMut = true,
    rPois = true,
    rSteam = true,
    rTorment = true,
    rDrown = true,
    Ice = true,
    Fire = true,
    sInv = true,
    flight = true,
};

-- Relies on stash annotation
-- See https://github.com/crawl/crawl/blob/master/crawl-ref/source/dat/clua/stash.lua
local function FindItemProperties(description)
    local prefixes = description:match("Stash search prefixes:%s*(.-)\nMenu/colouring prefixes:")
        or description:match("Stash search prefixes:%s*(.*)")
    if not prefixes then
        return nil
    end

    -- Find an item's properties by searching their description
    local properties, seen = {}, {}
    for group in prefixes:gmatch("{([^{}]*)}") do
        for token in group:gmatch("%S+") do
            local base = token:match("^([%a]+)[+-]*%d*$")
            if inscription_properties[base] and not seen[token] then
                properties[#properties + 1] = token
                seen[token] = true
            end
        end
    end
    return properties
end

local talisman_property_order = {
    "rF", "rC", "rPois", "rN", "rElec", "rCorr", "Will",
    "Str", "Int", "Dex", "Stlth",
};
local talisman_property_aliases = { rNeg = "rN", Stealth = "Stlth" }
local talisman_property_types = {
    rF = "resist",
    rC = "resist",
    rPois = "resist",
    rN = "resist",
    rElec = "resist",
    rCorr = "resist",
    Will = "resist",
    Str = "stat",
    Int = "stat",
    Dex = "stat",
    Stlth = "stealth",
};

-- Extract talisman properties from their description
-- Overcomplicated much?
local function FindTalismanProperties(description)
    local plain = description:gsub("<[^>]*>", ""):gsub("\r", "")
    local block = plain:match("\n%s*Cur%s+[^\n]*\n(.*)")
    if not block then
        return nil
    end

    local values, started = {}, false
    for line in (block .. "\n"):gmatch("([^\n]*)\n") do
        if line:match("^%s*Melds:") or line:match("^%s*Mutations") then
            break
        end
        if not line:match("%S") then
            if started then
                break
            end
        else
            if not line:match("^%s*[%a ]+:") then
                break
            end
            if not line:match("^%s*Class:") then
                started = true
            end
            for label, value in line:gmatch("(%a+):%s*(%S+)") do
                local key = talisman_property_aliases[label] or label
                local kind = talisman_property_types[key]
                if kind then
                    if kind == "stat" then
                        if not value:match("^[+-]%d+$") then
                            return nil
                        end
                        value = tonumber(value) ~= 0 and value or ""
                    elseif kind == "resist" and (value == "∞" or value == "inf") then
                        value = "∞"
                    else
                        if not value:match("^[+x.%-]+$") then
                            return nil
                        end
                        value = value:gsub("%.", ""):gsub("x", "-")
                    end
                    if values[key] and values[key] ~= value then
                        return nil
                    end
                    values[key] = value
                end
            end
        end
    end

    local properties = {}
    for _, key in ipairs(talisman_property_order) do
        if values[key] and values[key] ~= "" then
            properties[#properties + 1] = key .. values[key]
        end
    end
    return properties
end

-- Autoinscribe items with their properties
function AutoInscribe()
    for _, item_list in ipairs({ items.inventory(), you.floor_items() or {} }) do
        for _, item in ipairs(item_list) do
            if not item.artefact then
                local properties
                if item.class(true) == "talisman" then
                    properties = FindTalismanProperties(item.description or "")
                else
                    properties = FindItemProperties(item.description or "")
                end

                if properties then
                    local inscription = table.concat(properties, " ")
                    if item.inscription ~= inscription then
                        item.inscribe(inscription, false)
                    end
                end
            end
        end
    end
end
