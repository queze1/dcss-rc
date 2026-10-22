-- From rypofalem as of 15/10/2026
-- https://tavern.dcss.io/t/some-helpful-rc-snippits/1973

---------------------------------
--- Safe Channel Macro        ---
---------------------------------
-- Wait but only if you're channeling a spell.
-- We bind this above with macros += M S ===safe_channel

function SafeChannel()
    if you.channelled_spell() then
        crawl.sendkeys("s")
    else
        crawl.mpr("You are not channelling a spell!")
    end
end
