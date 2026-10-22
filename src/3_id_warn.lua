-- From rypofalem as of 15/10/2026
-- https://tavern.dcss.io/t/some-helpful-rc-snippits/1973
-- Modified to work with my preexisting stair logic

---------------------------------
--- Identification Notify     ---
---------------------------------
-- Print a warning when going downstairs if it looks like you need to ID items.

function IdWarn()
    -- return early if we're not on stairs (you use <> for portals and shops too)
    local standing_on = view.feature_at(0, 0)
    if standing_on == "enter_shop" or
        (not (standing_on:find("stairs") or standing_on:find("hatch") or standing_on:find("enter") or standing_on:find("exit"))) then
        return false
    end

    -- look for unidentified items return early if there are none
    local function is_unid(item) return not item.is_identified end
    local unid = util.filter(is_unid, items.inventory())
    if unid == nil or #unid == 0 then
        return false
    end

    -- print how many unidentified items we have
    local potions = 0
    local potion_stack = 0
    local scrolls = 0
    local scroll_stack = 0
    for i, it in ipairs(unid) do
        if it.class() == "Scrolls" then
            scrolls = scrolls + it.quantity
            scroll_stack = scroll_stack + 1
        elseif it.class() == "Potions" then
            potions = potions + it.quantity
            potion_stack = potion_stack + 1
        end
    end
    if scrolls > 0 then
        crawl.mpr(string.format("<lightred>You have %d unidentified scrolls in %d stacks.</lightred>", scrolls,
            scroll_stack))
    end
    if potions > 0 then
        crawl.mpr(string.format("<lightred>You have %d unidentified potions in %d stacks.</lightred>", potions,
            potion_stack))
    end


    -- prompt the user if we also have ID scrolls
    local function is_id(item) return item.subtype() == "identify" end
    if util.exists(items.inventory(), is_id) then
        -- Ask the user if they wish to proceed without reading ID and abort if they say no.
        local proceed = crawl.yesno("You have ID scrolls. Proceed anyway? (y/n)", true)
        if not proceed then
            crawl.mpr("Okay then.")
            return true
        end
    end

    -- If they agreed to the prompt or there were no ID scrolls, just do the action
    return false
end
