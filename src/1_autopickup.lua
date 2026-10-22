-- From gammafunk as of 14/10/2026
-- https://github.com/gammafunk/dcss-rc/blob/13b4e5585dee8a1236a48283aed7bb1cf670e1e6/gammafunk.rc

-- Equipment autopickup
local function pickup_equipment(it, name)
    if it.is_useless then
        return
    end

    local class = it.class(true)
    if class == "armour" then
        local good_slots = {
            cloak = "cloak",
            helmet = "helmet",
            gloves = "gloves",
            boots = "boots",
            barding = "barding"
        }
        st = it.subtype()

        -- Autopickup found aux armour if (1) we don't have any or (2) it's
        -- artefact, or (3) if we don't have artefact or ego armour, and the
        -- found armour is ego.
        if good_slots[st] ~= nil then
            if good_slots[st] == "gloves" and you.has_claws() > 0 then
                return
            end

            if it.artefact then
                return true
            end

            local cur = items.equipped_at(good_slots[st])
            return not cur
                or not cur.branded and not cur.artefact and it.branded
            -- Autopickup found body armour of the same kind we're wearing,
            -- according to conditions (2) and (3) above used for aux slots.
        elseif st == "body" then
            local cur = items.equipped_at("armour")
            if not cur or cur.name("qual") ~= it.name("qual") then
                return
            end

            if it.artefact
                or not cur.branded and not cur.artefact and it.branded then
                return true
            end
        end
    end
end

add_autopickup_func(pickup_equipment)
