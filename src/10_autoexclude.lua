-- Autoexclude sleeping uniques
function AutoExcludeSleepingUniques()
    for _, c in ipairs(los_coords()) do
        local mons = monster.get_monster_at(c.x, c.y)
        if mons and mons:is_unique() and is_asleep(mons)
            and not travel.is_excluded(c.x, c.y) then
            travel.set_exclude(c.x, c.y)
        end
    end
end
