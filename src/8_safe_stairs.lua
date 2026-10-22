local mark_return_stair
local done_exploring_branch
local done_exploring_depth

function DoneExploringCurrentFloor()
    return done_exploring_branch == you.branch()
        and done_exploring_depth == you.depth()
        and FindMessage("Done exploring%.") ~= nil
end

function WarnBlackTorch()
    if you.status("lit torch") and not DoneExploringCurrentFloor() then
        return crawl.yesno("Really end your conquest for Yredelemnul?")
    end
    return true
end

function SafeUpstairs()
    if IdWarn() then
        return
    end

    local feature = view.feature_at(0, 0)

    -- Warn before using an escape hatch
    if string.find(feature, "escape_hatch_up") then
        if not crawl.yesno("Really use the escape hatch?") then
            return
        end
    end

    -- Warn before extinguishing the Black Torch
    if not WarnBlackTorch() then
        return
    end

    mark_return_stair = IsUpstair(feature) and IsEnemyInLOS()
    crawl.do_commands({ "CMD_GO_UPSTAIRS" })
end

-- Save a downstair in waypoint 9, if enemies were in LOS when going upstairs
function MarkReturnStair()
    if not mark_return_stair then
        return
    end

    if IsDownstair(view.feature_at(0, 0)) then
        crawl.mpr("<lightred>Staircase saved. Enemies were in view.</lightred>")
        travel.set_waypoint(9, 0, 0)
    end

    mark_return_stair = false
end

-- Prompt when going downstairs in dangerous situations
function SafeDownstairs()
    IdWarn()

    if not IsDownstair(view.feature_at(0, 0)) then
        crawl.do_commands({ "CMD_GO_DOWNSTAIRS" })
        return
    end

    -- Warn before extinguishing the Black Torch
    if not WarnBlackTorch() then
        return
    end

    local return_stair_x, return_stair_y = travel.waypoint_delta(9)
    if return_stair_x == 0 and return_stair_y == 0 then
        if not crawl.yesno("Really use the return stair? Enemies were in view.") then
            return
        end
    end

    local branch = you.branch()
    local depth = you.depth()
    local deepest_current = travel.find_deepest_explored(branch) or 0
    local deepest_depths = travel.find_deepest_explored("Depths") or 0

    -- Prevent going to Vaults:5 before Depths
    if branch == "Vaults" and depth == 4 and deepest_depths == 0 then
        crawl.mpr("<lightred>Visit Depths before doing Vaults:5, please.</lightred>")
        return
    end

    -- Warn before going to V:5 for the first time
    if branch == "Vaults" and depth == 4 and deepest_current < 5 then
        if crawl.yesno("Are you really prepared to enter Vaults:5?") then
            crawl.do_commands({ "CMD_GO_DOWNSTAIRS" })
            return
        end
    end

    local s_branches = { "Shoals", "Swamp", "Snake", "Spider" }
    local in_s_branch = util.contains(s_branches, branch)

    -- Warn before entering the fourth floor of an S-branch for the first time before exploring another
    if in_s_branch and depth == 3 and deepest_current < 4 then
        local explored_another_s_branch = util.exists(s_branches, function(s_branch)
            return s_branch ~= branch
                and (travel.find_deepest_explored(s_branch) or 0) > 0
        end)

        if not explored_another_s_branch then
            if crawl.yesno("Really go downstairs to the last level before exploring another S-branch?") then
                crawl.do_commands({ "CMD_GO_DOWNSTAIRS" })
            end
            return
        end
    end

    -- Warn before using an escape hatch
    if string.find(view.feature_at(0, 0), "escape_hatch_down") then
        if not crawl.yesno("Really use the escape hatch?") then
            return
        end
    end

    if IsHealthy() then
        crawl.do_commands({ "CMD_GO_DOWNSTAIRS" })
    elseif crawl.yesno("Really go downstairs while injured?") then
        crawl.do_commands({ "CMD_GO_DOWNSTAIRS" })
    end
end
