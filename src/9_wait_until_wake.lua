local waiting_until_wake = false
local turns_waited = 0

-- Wait until an enemy wakes up
function WaitUntilWake()
    if not is_enemy_in_los() then
        crawl.mpr("No enemies are in view!")
        return
    end

    if is_awake_enemy_in_los() then
        crawl.mpr("Awake enemies are in view!")
        return
    end

    if not crawl.yesno("Really wait until a monster wakes up?") then
        return
    end

    -- Set waiting flag
    waiting_until_wake = true
    turns_waited = 1
    crawl.do_commands({ "CMD_WAIT" })
end

function WaitUntilWakeManager()
    if not waiting_until_wake then
        return
    end

    if is_awake_enemy_in_los() then
        crawl.mpr("An awake monster is in view. Waited " .. turns_waited .. " turns.")
        waiting_until_wake = false
        turns_waited = 0
        return
    end

    if not is_enemy_in_los() then
        crawl.mpr("No enemies are in view. Waited " .. turns_waited .. " turns.")
        waiting_until_wake = false
        turns_waited = 0
        return
    end

    turns_waited = turns_waited + 1
    crawl.do_commands({ "CMD_WAIT" })
end
