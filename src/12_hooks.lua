local need_skills_opened = true

function c_message(text, channel)
    -- Note the current branch and depth when done exploring
    if string.find(text, "Done exploring%.") then
        done_exploring_branch = you.branch()
        done_exploring_depth = you.depth()
    end

    NoteFadedAltar(text)
    IssueMessageWarnings(text)
end

function ready()
    if you.turns() == 0 and need_skills_opened then
        need_skills_opened = false
        crawl.sendkeys("m")
    end

    WarnThreats()
    AnnounceDamage()

    AutoInscribe()
    MarkReturnStair()
    ShoutWalkManager()
    WaitUntilWakeManager()
end
