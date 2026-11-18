-- From HyperOdds as of 19/11/2026
-- https://underhound.eu/crawl/rcfiles/crawl-git/HyperOdds.rc
-- Don't explore over deep water in Shoals

function ShoalsCheck()
    if you.branch() == "Shoals" then
        crawl.setopt("travel_avoid_terrain = deep water")
    else
        crawl.setopt("travel_avoid_terrain = ")
    end
end

function SafeExplore()
    -- Do not allow exploring if you have a sentinel's mark
    if you.status("marked") then
        crawl.mpr("<lightred>A sentinel's mark is upon you!</lightred>")
        return
    end

    crawl.do_commands({ "CMD_EXPLORE" })
end
