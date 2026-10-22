-- Shout before walking and stop if any monsters shout back
local ask_for_confirmation = true
local noise_warning = false
local last_action
local next_direction

-- Create a shout walk function for a direction
function shout_walk_creator(direction)
    return function()
        -- Do not shout walk if monsters are in LOS
        if is_enemy_in_los() then
            crawl.mpr("There are monsters nearby!", 5)
            return
        end

        -- If a monster has made a noise in the last shout walk, prompt whether to shout walk anyway
        if noise_warning then
            if not crawl.yesno("Your last walk was canceled because a monster made a noise. Continue anyway?") then
                return
            end
        end

        -- Shout walking is dangerous, ask to confirm
        if ask_for_confirmation then
            if not crawl.yesno("Really shout walk? This will wake up nearby monsters!") then
                return
            end
            ask_for_confirmation = false
        end

        -- Shout, then set direction for next turn
        crawl.sendkeys("tt")
        last_action = "shout"
        next_direction = direction
    end
end

-- Manages the state tracking
function ShoutWalkManager()
    local direction = next_direction
    local action = last_action
    noise_warning = false
    next_direction = nil
    last_action = nil

    -- Ask for confirmation again between shout walks
    if action == nil then
        ask_for_confirmation = true
    end

    -- Skip if no direction was set, or if we didn't shout last turn
    if direction == nil or action ~= "shout" then
        return
    end

    -- Abort if an enemy is in LOS
    if is_enemy_in_los() then
        crawl.mpr("A monster has walked into LOS. Walk canceled.", 3)
        return
    end

    -- Abort if a noise was made
    local noise_made = find_message("You hear", "for attention")
    if noise_made then
        crawl.mpr("A noise has been made in response. Walk canceled.", 3)
        noise_warning = true
        return
    end

    -- Walk in the direction set last turn
    crawl.sendkeys(direction)
    last_action = "walk"
end

function shout_walk_mapper()
    ShoutWalkY = shout_walk_creator("y")
    ShoutWalkU = shout_walk_creator("u")
    ShoutWalkH = shout_walk_creator("h")
    ShoutWalkB = shout_walk_creator("b")
    ShoutWalkN = shout_walk_creator("n")
    ShoutWalkJ = shout_walk_creator("j")
    ShoutWalkK = shout_walk_creator("k")
    ShoutWalkL = shout_walk_creator("l")
end

-- Set up shout walk functions
shout_walk_mapper()
