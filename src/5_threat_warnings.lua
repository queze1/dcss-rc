-- Heavily based on Implojin's threat warning system
-- https://github.com/Implojin/implo-rc/blob/main/init.lua

local DEBUG_MONS_STATUS = false
local DEBUG_MONS_FLAGS = false
local DEBUG_MONS_DESC = false
local DEBUG_MONS_TARGET_DESC = false
local DEBUG_THREATS = false
local DEBUG_ABIL_XDY = false
local DEBUG_ABIL_DAM = false
local DEBUG_ABIL_PCT = false

local mons_table = {}
local current_threats = {}
local known_threats = {}

-- Check if an ability exists within the monster's spellbook.
-- The third parameter is optional, and tests if the ability deals more than the given damage.
-- @param mons mons
-- @param string ability name
-- @param number[opt="nil"] damage optional
-- @return bool
function check(mons, ability_string, damage)
    if not util.contains(mons:spells() or {}, ability_string) then
        return false
    end
    if damage == nil then
        return true
    end
    local ability_damage = check_abil_dam(mons, ability_string)
    return ability_damage ~= nil and ability_damage > damage
end

-- lua string.find() returns an index, not a bool, if a pattern match is found,
-- therefore string.find() comparisons need to include ~= nil
-- this function is syntactic sugar to help the danger table inlines read a little better
function check_desc(mons, string)
    local desc = mons:desc(true)
    if string.find(desc, string) ~= nil then return true end
    return false
end

function check_tdesc(mons, string)
    local desc = mons:target_desc()
    if string.find(desc, string) ~= nil then return true end
    return false
end

-- Check if a monster description contains a damage string for a given ability.
-- Returns the damage string if it exists, otherwise nil.
-- The damage string is typically formatted as "#d#" (ex: 3d23), but is sometimes formatted as "#-#" (Smiting: 7-17),
-- prefixed with "#x" (CBL: 3x3d25), or postfixed with "*" (LRD: 3d23*).
-- @param mons mons
-- @param string ability name
-- @return string|nil xdy
function check_abil_xdy(mons, ability)
    local xdy = nil
    local desc = mons:desc(true)
    -- manually fixup ability names that get mangled/chopped by crawl in the mons:desc window
    if ability == "Lehudib's Crystal Spear" then ability = "Crystal Spear" end
    if ability == "Lee's Rapid Deconstruction" then ability = "Lee's Rapid Deconst" end

    -- if the ability exists in the full desc,
    if string.find(desc, ability) ~= nil then
        -- try to extract "ability string, (optional) whitespace, (optional) <color>, ([ax]x[d-]y*)" from the full desc
        xdy = string.match(desc, ability .. "%s*" .. "<?%l*>?" .. "%(?%d*x?%d+[d%-]%d+%*?%)?")
        -- if our pattern exists, try to extract "xdy"
        if xdy ~= nil then
            xdy = string.match(xdy, "%d*x?%d+[d%-]%d+")
            assert(xdy ~= nil)
        end
    end
    if DEBUG_ABIL_XDY then
        if xdy ~= nil then
            crawl.mpr(ability .. " xdy: " .. xdy)
        end
    end
    return xdy
end

-- Check how much damage a monster will deal with an ability.
-- Returns the maximum possible damage of the ability if we can calculate it, otherwise nil.
-- @param mons mons
-- @param string ability name
-- @return number|nil damage
function check_abil_dam(mons, ability)
    local xdy = check_abil_xdy(mons, ability)
    if xdy == nil then return nil end
    assert(type(xdy) == "string")

    local damage = nil
    local dice = {}

    for i in string.gmatch(xdy, "%d+") do
        table.insert(dice, tonumber(i))
    end
    assert(next(dice) ~= nil and #dice >= 2)

    -- most damage formats: "3d23", "3x3d25", "3d23*"
    if string.find(xdy, "d") ~= nil then
        local roll = 1
        for _, die in ipairs(dice) do
            roll = roll * die
        end
        damage = roll
        -- smiting damage format: "7-17"
    elseif string.find(xdy, "%-") ~= nil and #dice == 2 then
        damage = dice[#dice]
    end
    -- This assert should trigger for damage formats like "3x7-17", which are unhandled above as they do not currently exist
    assert(damage ~= nil, "ability damage format unrecognized!")
    if DEBUG_ABIL_DAM then crawl.mpr(ability .. " damage: " .. tostring(damage)) end
    return damage
end

-- Check if a given monster ability has a (percentage) value listed in the monster description.
-- Returns "percentage" as a string if it exists, otherwise nil.
-- @param mons mons
-- @param string ability name
-- @return string|nil percentage
function check_abil_pct(mons, ability)
    local pct = nil
    local desc = mons:desc(true)
    -- if the ability exists in the full desc,
    if string.find(desc, ability) ~= nil then
        -- try to extract "ability string, whitespace, optional <color>, (decimal%)" from the full desc
        pct = string.match(desc, ability .. "%s+" .. "<?%l*>?" .. "%(%d+%%%)")
        -- if our pattern exists, try to extract the decimal
        if pct ~= nil then
            pct = tonumber(string.match(pct, "%d+"))
            if DEBUG_ABIL_PCT then crawl.mpr(ability .. "(%): " .. pct) end
        end
    end
    return pct
end

function debug_mpr_current_threats()
    crawl.mpr("current_threats : ")
    for _, entry in ipairs(current_threats) do
        local pos = {}
        pos1, pos2 = entry[1]:pos()
        crawl.mpr("name: " .. entry.name .. " pos(): " .. pos1 .. "," .. pos2)
    end
end

function debug_mpr_mons_flags(mons)
    crawl.mpr(mons:name() .. " flags: ")
    local flags = {}
    flags = mons:flags()
    if next(flags) ~= nil then
        for _, flag in ipairs(flags) do
            crawl.mpr(flag .. " | ")
        end
    end
end

-- copied from ff.rc, which used a clua re-implementation of explorer.rare_ood() from /dat/dlua/explorer.dlua
function check_rare_ood(m)
    local you_depth = you.depth()
    local mdepth = m:avg_local_depth()
    local mprob = m:avg_local_prob()
    local br_depth = you.depth_fraction()
    -- explorer.rare_ood() used ood_threshold = math.max(2, you_depth / 3),
    -- we use a fixed OOD threshold so it doesn't grow later
    local ood_threshold = 3
    return mdepth > you_depth + ood_threshold and mprob < 2
end

-- Here we reconstruct the Dream Sheep "Dream Dust" success rate, as it's not exposed anywhere in-game.
local DREAM_SHEEP_CAP = 6
local DREAM_SHEEP_MAGIC_NUMBER = 25
function get_dream_dust_success_rate()
    local sheep = 0
    local rate = 0

    for _, mons in ipairs(mons_table) do
        if check(mons, "Dream Dust") then
            sheep = sheep + 1
        end
    end

    if sheep > DREAM_SHEEP_CAP then sheep = DREAM_SHEEP_CAP end
    if sheep > 0 then
        rate = 100 * ((sheep - 1) * DREAM_SHEEP_MAGIC_NUMBER + 1) / (sheep * DREAM_SHEEP_MAGIC_NUMBER)
    end

    return rate
end

local pending_message_warnings = {}
local pending_player_warnings = {}

local HP_WARN_T2_PERCENT = 70
local HP_WARN_T3_PERCENT = 50
local LAST_HP = math.huge

function construct_hp_warning()
    local hp, mhp = you.hp()
    local threat = nil
    local percent = math.floor(100 * hp / mhp)

    if next(mons_table) ~= nil and percent <= HP_WARN_T2_PERCENT and hp < LAST_HP then
        threat = {
            name = "Low HP Warning",
            tier = (percent <= HP_WARN_T3_PERCENT and 3 or 2),
            reason = ("" .. percent .. "% HP (" .. hp .. "/" .. mhp .. ")"),
            last_warned = nil
        }
    end

    LAST_HP = hp
    return threat
end

function update_hp_warning()
    local threat = construct_hp_warning()

    if threat ~= nil then
        table.insert(pending_player_warnings, threat)
    end
end

local status = {
    _update_mons = function()
        local LOS = you.los()
        local mons = nil
        mons_table = {}

        for i = -LOS, LOS do
            for j = -LOS, LOS do
                mons = monster.get_monster_at(i, j)
                if mons and you.see_cell_no_trans(i, j) and is_enemy(mons) then
                    table.insert(mons_table, mons)
                end
            end
        end
    end,
    -- returns false if a warning did not occur, true if a warning occurred
    _warn = function(self, threat, force_more)
        if force_more == nil then force_more = true end
        if threat.last_warned ~= nil and threat.last_warned == you.turns() then return false end

        local tier = threat.tier
        local colour = "yellow"
        if tier > 1 then colour = "yellow" end
        if tier > 2 then colour = "lightred" end

        crawl.formatted_mpr("<lightred>Danger: " .. threat.name .. "</lightred> |T" .. tostring(tier) .. "| " ..
            "<" .. colour .. ">Reason: " .. threat.reason .. "</" .. colour .. ">")
        crawl.flush_prev_message()

        -- Tier 2+, flash screen. There is no clua binding to manually perform a flash screen.
        -- Here, we have to rely on the rcfile flash_screen_message option, pattern matching our (custom) printed tier messages.

        if tier >= 3 and force_more then crawl.more() end

        if tier >= 2 then
            crawl.redraw_screen()
            crawl.delay(150)
        end

        threat.last_warned = you.turns()
        return true
    end,
    _check_threat = function(self, mons)
        -- when in debug mode, print the monster status table to mpr
        if DEBUG_MONS_STATUS == true then crawl.mpr(mons:name() .. " status: " .. mons:status()) end
        if DEBUG_MONS_FLAGS == true then debug_mpr_mons_flags(mons) end
        if DEBUG_MONS_DESC == true then crawl.mpr(mons:name() .. " desc: " .. mons:desc(true)) end
        if DEBUG_MONS_TARGET_DESC == true then crawl.mpr(mons:name() .. " target_desc: " .. mons:target_desc()) end


        -- begin danger table
        local danger_table = {
            -- Generic warnings
            {
                conditions = { mons:is_unique() == true },
                tier = 2,
                reason = "Unique monster, careful!"
            },
            {
                conditions = { check_rare_ood(mons) },
                tier = 2,
                reason = "OOD monster, careful!"
            },

            -- Torment, smite, damnation, malmutation
            {
                -- TODO: Add a check if the spell is silencable and don't trigger if monster is silenced
                conditions = { check(mons, "Symbol of Torment"), not you.torment_immune() },
                tier = 3,
                reason = "Torment and not torment immune!"
            },
            {
                conditions = { check(mons, "Siphon Essence"), not you.torment_immune() },
                tier = 3,
                reason = "Siphon Essence (torment) and not torment immune!"
            },
            {
                conditions = { check(mons, "Hurl Damnation") },
                tier = 2,
                reason = "Damnation in LOS, careful!"
            },
            {
                conditions = { check(mons, "Call Down Damnation") },
                tier = 2,
                reason = "Damnation (smite) in LOS, watch out!"
            },
            {
                conditions = { check(mons, "Smiting"), you.hp() < 100 },
                tier = 2,
                reason = "Smiter in LOS and HP below 100, watch out!"
            },
            {
                conditions = { check(mons, "Malmutate") },
                tier = 2,
                reason = "Malmutator in LOS!"
            },

            -- Will-resistable effects
            {
                conditions = { check_abil_pct(mons, "Paralyse") ~= nil and check_abil_pct(mons, "Paralyse") > 5 },
                tier = 3,
                reason = "Paralyse " .. (check_abil_pct(mons, "Paralyse") or "buggy") .. "%, equip more Will?"
            },
            {
                conditions = { check_abil_pct(mons, "Petrify") ~= nil and check_abil_pct(mons, "Petrify") > 5 },
                tier = 3,
                reason = "Petrify " .. (check_abil_pct(mons, "Petrify") or "buggy") .. "%, equip more Will?"
            },
            {
                conditions = { check_abil_pct(mons, "Banishment") ~= nil and check_abil_pct(mons, "Banishment") > 5 },
                tier = 3,
                reason = "Banishment " .. (check_abil_pct(mons, "Banishment") or "buggy") .. "%, equip more Will?"
            },
            {
                conditions = { check_abil_pct(mons, "Sleep") ~= nil and check_abil_pct(mons, "Sleep") > 5 },
                tier = 3,
                reason = "Sleep " .. (check_abil_pct(mons, "Sleep") or "buggy") .. "%, equip more Will?"
            },
            {
                conditions = { check_abil_pct(mons, "Confuse") ~= nil and check_abil_pct(mons, "Confuse") > 5 },
                tier = 2,
                reason = "Confuse " .. (check_abil_pct(mons, "Confuse") or "buggy") .. "%, equip more Will?"
            },
            {
                conditions = { check_abil_pct(mons, "Mass Confusion") ~= nil and check_abil_pct(mons, "Mass Confusion") > 5 },
                tier = 2,
                reason = "Mass Confusion " ..
                    (check_abil_pct(mons, "Mass Confusion") or "buggy") .. "%, equip more Will?"
            },
            {
                conditions = { check_abil_pct(mons, "Confusion Gaze") ~= nil and check_abil_pct(mons, "Confusion Gaze") > 5 },
                tier = 2,
                reason = "Confusion Gaze " ..
                    (check_abil_pct(mons, "Confusion Gaze") or "buggy") .. "%, equip more Will?"
            },
            {
                conditions = { check_abil_pct(mons, "Slow") ~= nil and check_abil_pct(mons, "Slow") > 5 },
                tier = 2,
                reason = "Slow " .. (check_abil_pct(mons, "Slow") or "buggy") .. "%, equip more Will?"
            },
            {
                conditions = { check_abil_pct(mons, "Sentinel's Mark") ~= nil and check_abil_pct(mons, "Sentinel's Mark") > 5 },
                tier = 3,
                reason = "Sentinel's Mark " ..
                    (check_abil_pct(mons, "Sentinel's Mark") or "buggy") .. "%, equip more Will?"
            },
            {
                conditions = { check_abil_pct(mons, "Porkalator") ~= nil and check_abil_pct(mons, "Porkalator") > 5 },
                tier = 2,
                reason = "Porkalator " .. (check_abil_pct(mons, "Porkalator") or "buggy") .. "%, equip more Will?"
            },
            {
                conditions = { check_abil_pct(mons, "Dimension Anchor") ~= nil and check_abil_pct(mons, "Dimension Anchor") > 5 },
                tier = 2,
                reason = "Dimension Anchor " ..
                    (check_abil_pct(mons, "Dimension Anchor") or "buggy") .. "%, equip more Will?"
            },

            -- Resistance checks
            {
                conditions = { check(mons, "Call Down Lightning"), you.res_shock() < 1 },
                tier = 3,
                reason = "Call Down Lightning and no rElec!"
            },
            {
                conditions = { check(mons, "Spit Acid"), not you.res_corr() },
                tier = 2,
                reason = "Spit Acid and no rCorr!"
            },
            {
                conditions = { check(mons, "Corrosive Bolt"), not you.res_corr() },
                tier = 2,
                reason = "Corrosive Bolt and no rCorr!"
            },

            -- Dangerous items
            {
                conditions = { check_tdesc(mons, "[dD]istort"), you.branch() ~= "Zig" },
                tier = 3,
                reason = "Distortion weapon!"
            },
            {
                conditions = { check_tdesc(mons, "carrying a wand") },
                tier = 2,
                reason = "carrying a " ..
                    (string.match(mons:target_desc(), "wand of %w+") or "unknown/nonexistent wand?")
                    .. ", careful!"
            },
            {
                conditions = { check_tdesc(mons, "quivering poison"), you.res_poison() < 1, you.branch() ~= "Zig" },
                tier = 2,
                reason = "Quivering poison darts and no rPois, careful!"
            },
            {
                conditions = { check_tdesc(mons, "quivering curare"), you.res_poison() < 1, you.branch() ~= "Zig" },
                tier = 3,
                reason = "Quivering curare and no rPois, watch out!!"
            },
            {
                conditions = { check_tdesc(mons, "quivering atropa"), you.branch() ~= "Zig" },
                tier = 2,
                reason = "Quivering atropa, careful!"
            },
            {
                conditions = { check_tdesc(mons, "quivering datura"), you.branch() ~= "Zig" },
                tier = 3,
                reason = "Quivering datura, careful!"
            },
            {
                conditions = { check_tdesc(mons, "quivering dispersal"), you.branch() ~= "Zig" },
                tier = 3,
                reason = "Quivering dispersal, careful!"
            },
            {
                conditions = { check_tdesc(mons, "throwing net"), you.branch() ~= "Zig" },
                tier = 3,
                reason = "Quivering throwing nets, watch out!"
            },
            -- TODO: branded javelins (silver), branded large rocks (chuck)
            {
                conditions = { check_tdesc(mons, "large rock"), you.branch() ~= "Zig" },
                tier = 2,
                reason = "Quivering large rocks, watch out!!"
            },
            {
                conditions = { check_tdesc(mons, "javelin"), you.branch() ~= "Zig" },
                tier = 2,
                reason = "Quivering javelins, watch out!"
            },
            {
                conditions = { check_tdesc(mons, "boomerang"), you.branch() ~= "Zig" },
                tier = 2,
                reason = "Quivering boomerangs, careful!"
            },

            -- Dangerous abilities
            {
                conditions = { check(mons, "Stunning Burst"), you.res_shock() < 1 },
                tier = 3,
                reason = "Stunning Burst (paralyse) and no rElec!"
            },
            {
                -- TODO: Add immunity checks
                -- Undead, nonliving, berserk and clarity provide immunity
                conditions = { check(mons, "Dream Dust"), },
                tier = 2,
                reason = "Irresistable Dream Dust (" .. get_dream_dust_success_rate() .. "%), watch out!"
            },
            {
                conditions = { check_abil_pct(mons, "Oblivion Howl") ~= nil and check_abil_pct(mons, "Oblivion Howl") > 5 },
                tier = 3,
                reason = "Oblivion Howl " ..
                    (check_abil_pct(mons, "Oblivion Howl") or "buggy") .. "%, equip more Will or hex it or something"
            },
            {
                conditions = { check(mons, "Blink Allies Encircling") },
                tier = 2,
                reason = "Encircling blink in LOS, careful!"
            },
            {
                conditions = { check(mons, "Irradiate") },
                tier = 2,
                reason = "Irradiate, careful!"
            },
            -- Dangerous monsters
            {
                conditions = { mons:name() == "orb of fire", you.res_fire() < 2 },
                tier = 3,
                reason = "Orb of fire and no rF++!"
            },
            {
                conditions = { mons:name() == "orb of winter", you.res_cold() < 2 },
                tier = 3,
                reason = "Orb of winter and no rC++!"
            },
            {
                conditions = { mons:name() == "orb of fire", you.res_fire() == 2 },
                tier = 2,
                reason = "Orb of fire and rF++, equip more rF?"
            },
            {
                conditions = { mons:name() == "orb of winter", you.res_cold() == 2 },
                tier = 2,
                reason = "Orb of winter and rC++, equip more rC?"
            },
            {
                conditions = { mons:name() == "orb of entropy", you.res_draining() < 2 or not you.res_corr() },
                tier = 3,
                reason = (function()
                    local missing = {}
                    if you.res_draining() < 2 then table.insert(missing, "no rN++") end
                    if not you.res_corr() then table.insert(missing, "no rCorr") end
                    return "Orb of entropy and " .. table.concat(missing, ", ") .. "!"
                end)()
            },
            {
                conditions = { mons:name() == "orb of entropy", you.res_draining() == 2 },
                tier = 2,
                reason = "Orb of entropy and rN++, equip more rN?"
            },
            {
                conditions = { mons:name() == "Nikola", you.res_shock() < 1 },
                tier = 3,
                reason = "Nikola and no rElec!"
            },
            {
                conditions = { mons:name() == "Nikola", check_tdesc(mons, "[sS]ilenced") ~= true and mons:status("waterlogged") ~= true },
                tier = 3,
                reason = "Nikola in LOS and not silenced or waterlogged!"
            }, }

        for _, entry in ipairs(danger_table) do
            assert(type(entry.conditions) == "table" and type(entry.tier) == "number" and type(entry.reason) == "string")
        end
        -- end danger table

        for _, threat in ipairs(danger_table) do
            if util.forall(threat.conditions, function(value) return value == true end) then
                local needs_warn = true
                -- if this entry to current_threats matches a known_threats entry, don't warn about it,
                -- but also delete the matching known_threats entry, so that we can properly warn about duplicate threats.
                for key, entry in pairs(known_threats) do
                    if entry.name == mons:name() and entry.reason == threat.reason then
                        needs_warn = false
                        table.remove(known_threats, key)
                        break
                    end
                end

                table.insert(current_threats,
                    { name = mons:name(), tier = threat.tier, reason = threat.reason, last_warned = nil })
                if needs_warn then self:_warn(current_threats[#current_threats]) end
            end
        end
    end,
    _update_threats = function(self)
        current_threats = {}
        for _, mons in ipairs(mons_table) do
            self:_check_threat(mons)
        end
        if DEBUG_THREATS == true then debug_mpr_current_threats() end

        -- at the end of each update, replace the known_threats table with the current_threats table
        known_threats = current_threats
    end,
    _reissue_warnings = function(self)
        for _, threat in ipairs(current_threats) do
            if threat.tier >= 3 then
                self:_warn(threat, false)
            end
        end
    end,
    _issue_message_log_warnings = function(self)
        local warnings = pending_message_warnings
        pending_message_warnings = {}
        for _, warning in ipairs(warnings) do
            self:_warn(warning)
        end
    end,
    _update_player_warnings = function(self)
        update_hp_warning()
    end,
    _issue_player_warnings = function(self)
        for key, warning in ipairs(pending_player_warnings) do
            self:_warn(warning, true)
            table.remove(pending_player_warnings, key)
        end
    end,
    -- ready() can be called multiple times per game turn, if the player takes actions that do not end the turn.
    -- (e.g. pressing escape, checking inventory with 'i', checking spells with 'I', etc.)
    -- We don't want the script to rebuild threat tables or reissue warnings if it has already done so this turn,
    -- therefore, we only take these actions if the game turn has changed.
    update = function(self)
        if self._last_updated == nil or self._last_updated ~= you.turns() then
            self:_update_mons()
            self:_update_threats()
            self:_reissue_warnings()
            self:_update_player_warnings()
            self:_issue_player_warnings()
            self._last_updated = you.turns()
        end
    end,
}

local message_log_threat_table = {
    {
        conditions = "into a shaft and drop",
        tier = 3,
        reason = "Shafted!"
    },
    {
        conditions = "You are yanked towards",
        tier = 3,
        reason = "Malevolent teleportation!"
    }, }

function IssueMessageWarnings(text)
    for _, threat in ipairs(message_log_threat_table) do
        if string.find(text, threat.conditions) then
            table.insert(pending_message_warnings,
                { name = threat.reason, tier = threat.tier, reason = threat.reason, last_warned = nil })
            status:_issue_message_log_warnings()
        end
    end
end

function WarnThreats()
    status:update()
end
