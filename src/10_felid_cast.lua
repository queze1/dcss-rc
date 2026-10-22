-- Repurpose (w)ield for spellcasting, but only for felids
function FelidZE()
    if you.race() == "Felid" then
        crawl.sendkeys("ze")
    else
        crawl.do_commands({ "CMD_WIELD_WEAPON" })
    end
end
