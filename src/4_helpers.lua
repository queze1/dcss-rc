-- 0 = hostile, 1 = neutral, 2 = strict neutral, 3 = good neutral, 4 = friendly
local ATT_NEUTRAL = 1

-- Generate all coords in LOS
function los_coords()
    local coords = {}
    for x = -you.los(), you.los() do
        for y = -you.los(), you.los() do
            table.insert(coords, { x = x, y = y })
        end
    end
    return coords
end

-- Return true if a monster is an enemy
function is_enemy(m)
    return m:attitude() < ATT_NEUTRAL and not m:is_safe()
end

-- Return true if a monster is asleep
function is_asleep(m)
    return m:status("asleep") or m:status("dormant")
end

-- Return true if a hostile creature is in LOS
function is_enemy_in_los()
    return util.exists(los_coords(), function(c)
        local m = monster.get_monster_at(c.x, c.y)
        return m and is_enemy(m)
    end)
end

-- Return true if an awake hostile creature is in LOS
function is_awake_enemy_in_los()
    return util.exists(los_coords(), function(c)
        local m = monster.get_monster_at(c.x, c.y)
        return m and is_enemy(m) and not is_asleep(m)
    end)
end

-- Find a message in the buffer containing a pattern
-- If a subsequent message matches the stop pattern, return nil
function find_message(match, stop)
    local counter = 1
    -- Check at most 100 messages
    while (counter < 100)
    do
        local message = crawl.messages(counter)
        counter = counter + 1

        if string.find(message, match) then
            return message
        end
        if stop and string.find(message, stop) then
            return
        end
    end
end

-- Return true if you are completely rested
function is_healthy()
    local hp, mhp = you.hp()
    local mp, mmp = you.mp()
    if hp < mhp then
        return false
    elseif mp < mmp then
        return false
    elseif you.contamination() > 0 then
        return false
    end
    return true
end

-- Return true if a feature is an upstair
function is_upstair(feature)
    if feature == nil then
        return false
    elseif string.find(feature, "stairs_up") then
        return true
    elseif string.find(feature, "escape_hatch_up") then
        return true
    elseif string.find(feature, "exit_") then
        return true
    end
    return false
end

-- Return true if a feature is an downstair
function is_downstair(feature)
    if feature == nil then
        return false
    elseif string.find(feature, "enter_shop") then
        return false
    elseif string.find(feature, "stairs_down") then
        return true
    elseif string.find(feature, "escape_hatch_down") then
        return true
    elseif string.find(feature, "enter_") then
        return true
    end
    return false
end

-- Return true if the first artefact is strictly better than the second based on its properties
function is_better_than_artefact(first, second)
    -- From https://github.com/crawl/crawl/blob/32f959a6b094e375b291c6452be3bc58c622a7bf/crawl-ref/source/artefact.cc#L894
    local negative_props = {
        ["*Noise"] = true,
        ["-Cast"] = true,
        ["-Tele"] = true,
        ["*Rage"] = true,
        ["^Contam"] = true,
        ["*Corrode"] = true,
        ["^Drain"] = true,
        ["*Slow"] = true,
        ["^Fragile"] = true,
        ["*Silence"] = true,
        ["Bane"] = true,
    }

    first = first or {}
    second = second or {}

    local function value(props, key)
        local result = props[key]
        if result == nil or result == false then
            return 0
        elseif result == true then
            return 1
        end
        return result
    end

    local function is_negative(key, prop_value)
        return negative_props[key] or (type(prop_value) == "number" and prop_value < 0)
    end

    local strictly_better = false
    for key, first_value in pairs(first) do
        first_value = value(first, key)
        local second_value = value(second, key)
        if is_negative(key, first_value) then
            if first_value > second_value then
                return false
            elseif first_value < second_value then
                strictly_better = true
            end
        elseif first_value < second_value then
            return false
        elseif first_value > second_value then
            strictly_better = true
        end
    end

    for key, second_value in pairs(second) do
        second_value = value(second, key)
        local first_value = value(first, key)
        if not is_negative(key, second_value) and first_value < second_value then
            return false
        end
    end

    return strictly_better
end

-- Debug function to print a feature
function debug_feature(x, y)
    x = x or 0
    y = y or 0
    local feature = view.feature_at(x, y)
    crawl.mpr("Feature at " .. x .. "," .. y .. ": " .. feature)
end

-- Debug function to print item info
function debug_item(slot)
    local item = items.inslot(items.letter_to_index(slot))
    if not item then
        crawl.mpr("No item in slot " .. tostring(slot))
        return
    end

    local lines = {}
    local function add_attribute(label, value)
        if value ~= nil then
            lines[#lines + 1] = label .. ": " .. tostring(value)
        end
    end

    add_attribute("Name", item.name())

    local rarity
    if item.artefact then
        rarity = "artefact"
    elseif item.branded then
        rarity = "branded"
    else
        rarity = "plain"
    end
    add_attribute("Rarity", rarity)
    add_attribute("Plus", item.plus)
    add_attribute("Ego", item.ego())

    if item.artprops then
        local keys = {}
        for key in pairs(item.artprops) do
            keys[#keys + 1] = key
        end
        table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
        end)

        lines[#lines + 1] = "Artprops:"
        if #keys == 0 then
            lines[#lines + 1] = "  {}"
        else
            for _, key in ipairs(keys) do
                lines[#lines + 1] = "  " .. tostring(key) .. ": " .. tostring(item.artprops[key])
            end
        end
    end

    add_attribute("Inscription", item.inscription)

    crawl.mpr(table.concat(lines, "\n"))
end
