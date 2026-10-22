local retreated = false

function SafeExplore()
    -- Do not allow exploring if you have a sentinel's mark
    -- Not sure if you.status() works now
    if find_message("mark forms upon you", "mark upon you fades away") then
        crawl.mpr("<lightred>A sentinel's mark is upon you!</lightred>")
    elseif is_safe() or retreated then
        crawl.do_commands({ "CMD_EXPLORE" })
        retreated = false
    else
        retreated = true

        -- If possible, retreat to a stair
        for _, c in ipairs(los_coords()) do
            if is_upstair(view.feature_at(c.x, c.y)) then
                crawl.sendkeys("X<")
                return
            end
        end

        -- Otherwise, open level map
        crawl.sendkeys("X")
    end
end
