local addonName, ns = ...

ns.addonName = addonName
ns.version = "0.1.0-alpha.2"

function ns.Print(message)
    print("|cff33ff99[FEFS]|r " .. tostring(message))
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event ~= "ADDON_LOADED" then
        return
    end

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

    local mailStatus = ns.Mail and ns.Mail.IsInstalled() and "installed" or "waiting for Blizzard_MailFrame"
    ns.Print(string.format("%s; schema %s; mail integration %s.", ns.version, tostring(ns.Database.GetSchemaVersion()), mailStatus))
    ns.Print("Use /fefs search <name> to inspect the development search fixture.")
end
