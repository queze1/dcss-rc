-- Helper function generating all coords in LOS
function los_coords()
    local coords = {}
    for x = -you.los(), you.los() do
        for y = -you.los(), you.los() do
            table.insert(coords, { x = x, y = y })
        end
    end
    return coords
end

-- Helper function returning true if a hostile creature is in LOS
function is_enemy_in_los()
    return util.exists(los_coords(), function(c)
        local m = monster.get_monster_at(c.x, c.y)
        -- 0 = hostile, 1 = neutral, 2 = strict neutral, 3 = good neutral, 4 = friendly
        return m and m:attitude() < 1 and not m:is_safe()
    end)
end

-- Helper function returning true if an awake hostile creature is in LOS
function is_awake_enemy_in_los()
    return util.exists(los_coords(), function(c)
        local m = monster.get_monster_at(c.x, c.y)
        return m and m:attitude() < 1 and not m:is_safe() and not m:status("asleep") and not m:status("dormant")
    end)
end

-- Helper function which finds a message in the buffer containing a pattern
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

-- Helper function returning true if you are completely rested
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

-- Helper function returning true if a feature is an upstair
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

-- Helper function returning true if a feature is an downstair
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

-- Helper function returning true if it's safe to autoexplore
function is_safe()
    local feature = view.feature_at(0, 0)
    if is_upstair(feature) then
        return true
    end

    local hp, mhp = you.hp()
    local mp, mmp = you.mp()
    return hp == mhp and mp == mmp
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

    crawl.mpr(table.concat(lines, "\n"))
end
