local addonName, ns = ...

ns.addonName = addonName
ns.version = "0.1.0-alpha.4"

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
eventFrame:RegisterEvent("WHO_LIST_UPDATE")

local function TryInstallMailFeatures()
    if ns.Mail then
        ns.Mail.TryInstall()
    end
    if ns.MailContacts then
        ns.MailContacts.TryInstall()
    end
end

local function TryInstallWhisperFeatures()
    if ns.Whisper then
        ns.Whisper.TryInstall()
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == addonName then
            ns.Database.Initialize()
            ns.Database.SetChangeHandler(function(searchChanged)
                if searchChanged then
                    ns.Search.Refresh()
                end
                if ns.MailContacts then
                    ns.MailContacts.Invalidate()
                end
            end)
            ns.Search.Refresh()
            ns.isLoaded = true

            TryInstallMailFeatures()
            TryInstallWhisperFeatures()
        elseif loadedAddonName == "Blizzard_MailFrame" and ns.isLoaded then
            TryInstallMailFeatures()
        end
        return
    end

    if not ns.isLoaded then
        return
    end

    if event == "WHO_LIST_UPDATE" then
        if ns.Who then
            ns.Who.OnEvent(event)
        end
        return
    end

    if not ns.Sources then
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
        ns.Print(string.format(ns.L.CMD_SEARCH_RESULTS, #results, argument))
        for resultIndex = 1, #results do
            local result = results[resultIndex]
            ns.Print(string.format(ns.L.CMD_SEARCH_RESULT, resultIndex, result.record.actionName, result.score))
        end
        return
    end

    if command == "debug" and string.lower(argument or "") == "perf" then
        ns.Performance.Print()
        return
    end

    if command == "debug" then
        ns.Sources.PrintDebug()
        if ns.Who then
            ns.Who.PrintDebug()
        end
        return
    end

    local mailStatus = ns.Mail and ns.Mail.IsInstalled() and ns.L.STATUS_INSTALLED or ns.L.STATUS_WAITING_MAIL
    local whisperStatus = ns.Whisper and ns.Whisper.IsInstalled() and ns.L.STATUS_INSTALLED or ns.L.STATUS_WAITING_CHAT
    local panelStatus = ns.MailContacts and ns.MailContacts.IsInstalled() and ns.L.STATUS_INSTALLED or ns.L.STATUS_WAITING_MAIL
    ns.Print(string.format(
        ns.L.CMD_STATUS,
        ns.version,
        tostring(ns.Database.GetSchemaVersion()),
        mailStatus,
        whisperStatus,
        panelStatus
    ))
    ns.Print(ns.L.CMD_HELP)
end
