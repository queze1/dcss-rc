function SafeExplore()
    -- Do not allow exploring if you have a sentinel's mark
    if you.status("marked") then
        crawl.mpr("<lightred>A sentinel's mark is upon you!</lightred>")
        return
    end

    crawl.do_commands({ "CMD_EXPLORE" })
end
