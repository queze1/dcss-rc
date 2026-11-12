local previous_spell_failures = nil

-- Print a message when a memorised spell reaches 9% spell fail or lower
function PrintSpellFailRate()
    local current_spell_failures = {}

    for _, spell in ipairs(you.spells()) do
        local failure = spells.fail(spell)
        local previous_failure = previous_spell_failures and previous_spell_failures[spell]

        if previous_failure and previous_failure > 10 and failure < 10 then
            crawl.mpr("<lightcyan>" .. spell .. " reached " .. failure .. "% fail rate.</lightcyan>")
            crawl.more()
        end

        current_spell_failures[spell] = failure
    end

    previous_spell_failures = current_spell_failures
end
