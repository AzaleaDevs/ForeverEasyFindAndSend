local _, ns = ...

local MailContacts = {}
ns.MailContacts = MailContacts

local PANEL_WIDTH = 390
local PANEL_HEIGHT = 420
local ROW_HEIGHT = 52
local VISIBLE_ROWS = 6
local SEARCH_DEBOUNCE_SECONDS = 0.075

local installed = false
local activeTab = "GENERAL"
local panel
local toggleButton
local searchBox
local scrollFrame
local emptyText
local rows = {}
local visibleResults = {}
local guildOnlineByRecord = {}
local searchGeneration = 0

local function SetRecipient(record)
    local editBox = _G.SendMailNameEditBox
    if not editBox or type(record.actionName) ~= "string" then
        return
    end

    editBox:SetText(record.actionName)
    editBox:SetCursorPosition(string.len(record.actionName))
    editBox:SetFocus()
end

local function ResetScroll()
    if not scrollFrame then
        return
    end

    scrollFrame.offset = 0
    scrollFrame:SetVerticalScroll(0)
end

local function GetGuildStatus(record)
    local isOnline = guildOnlineByRecord[record]
    if isOnline == nil then
        return nil
    end

    if isOnline then
        return ONLINE or "Online"
    end

    return OFFLINE or "Offline"
end

local function GetEmptyMessage(query)
    if query ~= "" then
        return "No matching characters."
    end

    if activeTab == "GUILD" then
        local state = ns.Sources.GetState().guild
        if state == "none" then
            return "This character is not in a guild."
        elseif state == "pending" then
            return "Loading guild roster..."
        elseif state == "unavailable" then
            return "Guild roster is unavailable in this client."
        end
        return "No guild members available."
    elseif activeTab == "FAVORITES" then
        return "No favorite characters yet."
    end

    return "No known characters yet."
end

local function GetRecordsForActiveTab()
    if activeTab == "GUILD" then
        local records = {}
        wipe(guildOnlineByRecord)

        local entries = ns.Sources.GetGuildEntries()
        for entryIndex = 1, #entries do
            local entry = entries[entryIndex]
            records[#records + 1] = entry.record
            guildOnlineByRecord[entry.record] = entry.isOnline
        end
        return records
    elseif activeTab == "FAVORITES" then
        return ns.Database.GetFavoriteRecords()
    end

    wipe(guildOnlineByRecord)
    return ns.Database.GetPersistentRecords()
end

local function SetClassIcon(row, record)
    local classFile = record.classFile
    local coordinates = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]

    if coordinates then
        row.classIcon:SetTexture("Interface/TargetingFrame/UI-Classes-Circles")
        row.classIcon:SetTexCoord(coordinates[1], coordinates[2], coordinates[3], coordinates[4])
        row.classIcon:Show()
    else
        row.classIcon:Hide()
    end
end

local function SetClassColor(row, record)
    local color = record.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[record.classFile]
    if color then
        row.name:SetTextColor(color.r, color.g, color.b)
    else
        row.name:SetTextColor(1, 0.82, 0)
    end
end

local function UpdateRow(row, result)
    local record = result.record
    row.record = record
    local guildStatus = activeTab == "GUILD" and GetGuildStatus(record) or nil
    local renderKey = table.concat({
        activeTab,
        tostring(record.actionName or ""),
        tostring(record.displayName or ""),
        tostring(record.level or ""),
        tostring(record.race or ""),
        tostring(record.class or ""),
        tostring(record.classFile or ""),
        tostring(record.favorite == true),
        tostring(guildStatus or ""),
    }, "\031")

    if row.renderKey == renderKey then
        row:Show()
        return
    end

    row.renderKey = renderKey
    row.name:SetText(record.displayName or record.actionName)
    row.metadata:SetText(ns.Formatter.GetMetadata(record, guildStatus))
    row.favoriteButton.icon:SetAtlas(record.favorite and "friends-icon-favorites" or "friends-icon-favorites-dis")
    row.favoriteButton:SetEnabled(not record.isDevelopmentFixture)
    SetClassIcon(row, record)
    SetClassColor(row, record)
    row:Show()
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(258, ROW_HEIGHT - 2)
    row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 2, -((index - 1) * ROW_HEIGHT))

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.08)
    row.highlight:Hide()

    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetSize(30, 30)
    row.classIcon:SetPoint("LEFT", 3, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.classIcon, "TOPRIGHT", 7, -6)
    row.name:SetWidth(155)
    row.name:SetJustifyH("LEFT")

    row.metadata = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.metadata:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.metadata:SetWidth(155)
    row.metadata:SetJustifyH("LEFT")
    row.metadata:SetTextColor(0.7, 0.7, 0.7)

    row.mailButton = CreateFrame("Button", nil, row)
    row.mailButton:SetSize(24, 24)
    row.mailButton:SetPoint("RIGHT", row, "RIGHT", -30, 0)
    row.mailButton:SetNormalTexture("Interface/Icons/INV_Letter_15")
    row.mailButton:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")
    row.mailButton:SetScript("OnClick", function()
        if row.record then
            SetRecipient(row.record)
        end
    end)
    row.mailButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Set mail recipient")
        GameTooltip:Show()
    end)
    row.mailButton:SetScript("OnLeave", GameTooltip_Hide)

    row.favoriteButton = CreateFrame("Button", nil, row)
    row.favoriteButton:SetSize(26, 24)
    row.favoriteButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.favoriteButton.icon = row.favoriteButton:CreateTexture(nil, "ARTWORK")
    row.favoriteButton.icon:SetSize(18, 18)
    row.favoriteButton.icon:SetPoint("CENTER")
    row.favoriteButton:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")
    row.favoriteButton:SetScript("OnClick", function()
        if row.record then
            ns.Database.SetFavorite(row.record, not row.record.favorite)
        end
    end)
    row.favoriteButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(row.record and row.record.favorite and "Remove favorite" or "Add favorite")
        GameTooltip:Show()
    end)
    row.favoriteButton:SetScript("OnLeave", GameTooltip_Hide)

    row:SetScript("OnEnter", function(self)
        self.highlight:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
    end)

    rows[index] = row
end

local function ScheduleSearchRefresh()
    searchGeneration = searchGeneration + 1
    local generation = searchGeneration
    local query = searchBox:GetText() or ""

    ResetScroll()
    if query == "" or not C_Timer or type(C_Timer.After) ~= "function" then
        MailContacts.Refresh()
        return
    end

    C_Timer.After(SEARCH_DEBOUNCE_SECONDS, function()
        if generation == searchGeneration and searchBox and (searchBox:GetText() or "") == query then
            MailContacts.Refresh()
        end
    end)
end

local function SetActiveTab(tab)
    activeTab = tab
    ResetScroll()

    for tabName, button in pairs(panel.tabButtons) do
        button:SetEnabled(tabName ~= activeTab)
    end

    MailContacts.Refresh()
end

local function SetCollapsed(collapsed)
    local settings = ns.Database.GetSettings()
    settings.panelCollapsed = collapsed == true

    if settings.panelCollapsed then
        panel:Hide()
        toggleButton:SetText(">")
    elseif SendMailFrame:IsShown() then
        panel:Show()
        toggleButton:SetText("<")
        MailContacts.Refresh()
    end
end

local function CreatePanel()
    panel = CreateFrame("Frame", "FEFSMailContactsPanel", MailFrame, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("TOPLEFT", SendMailFrame, "TOPRIGHT", 34, 0)
    panel:SetClampedToScreen(true)
    panel:SetFrameLevel(MailFrame:GetFrameLevel() + 5)
    panel:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("FEFS Contacts")

    searchBox = CreateFrame("EditBox", nil, panel, "SearchBoxTemplate")
    searchBox:SetSize(270, 24)
    searchBox:SetPoint("TOPLEFT", 98, -40)
    if searchBox.Instructions then
        searchBox.Instructions:SetText(SEARCH or "Search")
    end
    searchBox:HookScript("OnTextChanged", ScheduleSearchRefresh)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    panel.tabButtons = {}
    local tabs = {
        { key = "GENERAL", label = "GENERAL" },
        { key = "GUILD", label = "GUILD" },
        { key = "FAVORITES", label = "FAVORITOS" },
    }
    for tabIndex = 1, #tabs do
        local tab = tabs[tabIndex]
        local tabKey = tab.key
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(82, 28)
        button:SetPoint("TOPLEFT", 10, -40 - ((tabIndex - 1) * 32))
        button:SetText(tab.label)
        button:SetScript("OnClick", function()
            SetActiveTab(tabKey)
        end)
        panel.tabButtons[tabKey] = button
    end

    scrollFrame = CreateFrame("ScrollFrame", "FEFSContactScrollFrame", panel, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 98, -74)
    scrollFrame:SetSize(262, VISIBLE_ROWS * ROW_HEIGHT)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, MailContacts.Refresh)
    end)

    emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyText:SetPoint("CENTER", scrollFrame, "CENTER", 0, 20)
    emptyText:SetWidth(240)
    emptyText:SetJustifyH("CENTER")
    emptyText:SetTextColor(0.7, 0.7, 0.7)

    for rowIndex = 1, VISIBLE_ROWS do
        CreateRow(rowIndex)
    end

    toggleButton = CreateFrame("Button", "FEFSMailContactsToggle", MailFrame, "UIPanelButtonTemplate")
    toggleButton:SetSize(28, 44)
    toggleButton:SetPoint("TOPLEFT", SendMailFrame, "TOPRIGHT", 3, -8)
    toggleButton:SetScript("OnClick", function()
        SetCollapsed(not ns.Database.GetSettings().panelCollapsed)
    end)

    SendMailFrame:HookScript("OnShow", function()
        toggleButton:Show()
        SetCollapsed(ns.Database.GetSettings().panelCollapsed)
    end)
    SendMailFrame:HookScript("OnHide", function()
        panel:Hide()
        toggleButton:Hide()
    end)

    SetActiveTab("GENERAL")
    if SendMailFrame:IsShown() then
        toggleButton:Show()
        SetCollapsed(ns.Database.GetSettings().panelCollapsed)
    else
        panel:Hide()
        toggleButton:Hide()
    end
end

function MailContacts.TryInstall()
    if installed then
        return true
    end

    if not _G.MailFrame or not _G.SendMailFrame or not _G.SendMailNameEditBox then
        return false
    end

    CreatePanel()
    installed = true
    MailContacts.Refresh()
    return true
end

function MailContacts.IsInstalled()
    return installed
end

function MailContacts.Refresh()
    if not installed or not panel then
        return
    end

    local query = searchBox:GetText() or ""
    visibleResults = ns.Search.Filter(GetRecordsForActiveTab(), query)
    local offset = FauxScrollFrame_GetOffset(scrollFrame)

    FauxScrollFrame_Update(scrollFrame, #visibleResults, VISIBLE_ROWS, ROW_HEIGHT)

    for rowIndex = 1, VISIBLE_ROWS do
        local result = visibleResults[offset + rowIndex]
        if result then
            UpdateRow(rows[rowIndex], result)
        else
            rows[rowIndex].record = nil
            rows[rowIndex].renderKey = nil
            rows[rowIndex]:Hide()
        end
    end

    if #visibleResults == 0 then
        emptyText:SetText(GetEmptyMessage(query))
        emptyText:Show()
    else
        emptyText:Hide()
    end
end
