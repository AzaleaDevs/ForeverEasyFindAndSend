local addonName, ns = ...

ns.addonName = addonName
ns.version = "0.1.0-alpha.2"

function ns.Print(message)
    print("|cff33ff99[FEFS]|r " .. tostring(message))
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("FRIENDLIST_UPDATE")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == addonName then
            ns.Database.Initialize()
            ns.Search.Refresh()
            ns.isLoaded = true

            if ns.Mail then
                ns.Mail.TryInstall()
            end
        elseif loadedAddonName == "Blizzard_MailFrame" and ns.isLoaded and ns.Mail then
            ns.Mail.TryInstall()
        end
        return
    end

    if not ns.isLoaded or not ns.Sources then
        return
    end

    if event == "PLAYER_LOGIN" then
        ns.Sources.StartInitialSync()
    else
        ns.Sources.OnEvent(event, ...)
    end
end)

SLASH_FOREVEREASYFINDANDSEND1 = "/fefs"
SlashCmdList.FOREVEREASYFINDANDSEND = function(message)
    local command, argument = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")

    if command == "search" and argument ~= "" then
        local results = ns.Search.Find(argument, 10)
        ns.Print(string.format("%d result(s) for %q:", #results, argument))
        for resultIndex = 1, #results do
            local result = results[resultIndex]
            ns.Print(string.format("%d. %s (score %d)", resultIndex, result.record.actionName, result.score))
        end
        return
    end

    if command == "debug" then
        ns.Sources.PrintDebug()
        return
    end

    local mailStatus = ns.Mail and ns.Mail.IsInstalled() and "installed" or "waiting for Blizzard_MailFrame"
    ns.Print(string.format("%s; schema %s; mail integration %s.", ns.version, tostring(ns.Database.GetSchemaVersion()), mailStatus))
    ns.Print("Use /fefs search <name> or /fefs debug.")
end
