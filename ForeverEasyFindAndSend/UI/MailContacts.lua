local _, ns = ...

local MailContacts = {}
ns.MailContacts = MailContacts

local PANEL_WIDTH = 390
local PANEL_HEIGHT = 420
local ROW_HEIGHT = 52
local VISIBLE_ROWS = 6
local SEARCH_DEBOUNCE_SECONDS = 0.075
local CONTENT_LEFT = 18
local CONTENT_RIGHT = 370
local CONTENT_WIDTH = CONTENT_RIGHT - CONTENT_LEFT

local installed = false
local activeTab = "GENERAL"
local panel
local toggleButton
local searchBox
local onlineSearchButton
local whoStatusText
local scrollFrame
local emptyText
local rows = {}
local visibleResults = {}
local guildOnlineByRecord = {}
local searchGeneration = 0
local resultsDirty = true
local lastQuery
local lastTab
local lastRenderedOffset

local function ShowTooltip(owner, text, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(text)
    GameTooltip:Show()
end

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
        return ONLINE or ns.L.ONLINE
    end

    return OFFLINE or ns.L.OFFLINE
end

local function GetEmptyMessage(query)
    if query ~= "" then
        return ns.L.NO_MATCHES
    end

    if activeTab == "GUILD" then
        local state = ns.Sources.GetState().guild
        if state == "none" then
            return ns.L.NOT_IN_GUILD
        elseif state == "pending" then
            return ns.L.GUILD_LOADING
        elseif state == "unavailable" then
            return ns.L.GUILD_UNAVAILABLE
        end
        return ns.L.NO_GUILD_MEMBERS
    elseif activeTab == "FAVORITES" then
        return ns.L.NO_FAVORITES
    end

    return ns.L.NO_KNOWN_CHARACTERS
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
        tostring(record.classID or ""),
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
    SetClassIcon(row, record)
    SetClassColor(row, record)
    row:Show()
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(CONTENT_WIDTH - 12, ROW_HEIGHT - 2)
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
    row.name:SetWidth(230)
    row.name:SetJustifyH("LEFT")

    row.metadata = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.metadata:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.metadata:SetWidth(230)
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
        ShowTooltip(self, ns.L.SET_MAIL_RECIPIENT)
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
        ShowTooltip(self, row.record and row.record.favorite and ns.L.REMOVE_FAVORITE or ns.L.ADD_FAVORITE)
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
    MailContacts.UpdateWhoState()
    if query == "" or not C_Timer or type(C_Timer.After) ~= "function" then
        MailContacts.Refresh("search")
        return
    end

    C_Timer.After(SEARCH_DEBOUNCE_SECONDS, function()
        if generation == searchGeneration and searchBox and (searchBox:GetText() or "") == query then
            MailContacts.Refresh("search")
        end
    end)
end

local function SetActiveTab(tab)
    activeTab = tab
    ResetScroll()

    for tabName, button in pairs(panel.tabButtons) do
        button:SetChecked(tabName == activeTab)
    end

    if activeTab == "GENERAL" then
        searchBox:SetWidth(224)
        onlineSearchButton:Show()
        whoStatusText:Show()
    else
        searchBox:SetWidth(CONTENT_WIDTH)
        onlineSearchButton:Hide()
        whoStatusText:Hide()
    end

    MailContacts.UpdateWhoState()
    MailContacts.Refresh("tab")
end

local function UpdateCollapseButton(collapsed)
    toggleButton.icon:SetAtlas(collapsed and "common-icon-forwardarrow" or "common-icon-backarrow", false)
end

local function SetCollapsed(collapsed)
    local settings = ns.Database.GetSettings()
    settings.panelCollapsed = collapsed == true

    if settings.panelCollapsed then
        panel:Hide()
        UpdateCollapseButton(true)
    elseif SendMailFrame:IsShown() then
        panel:Show()
        UpdateCollapseButton(false)
        MailContacts.Refresh("show")
    end
end

local function CreatePanel()
    panel = CreateFrame("Frame", "FEFSMailContactsPanel", MailFrame, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("TOPLEFT", SendMailFrame, "TOPRIGHT", 34, 0)
    panel:SetClampedToScreen(true)
    panel:SetFrameLevel(MailFrame:GetFrameLevel() + 5)
    panel:Hide()
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
    title:SetText(ns.L.CONTACTS_TITLE)

    searchBox = CreateFrame("EditBox", nil, panel, "SearchBoxNineSliceTemplate")
    searchBox:SetSize(CONTENT_WIDTH, 24)
    searchBox:SetPoint("TOPLEFT", CONTENT_LEFT, -40)
    if searchBox.Instructions then
        searchBox.Instructions:SetText(ns.L.SEARCH_PLACEHOLDER)
    end
    searchBox:HookScript("OnTextChanged", ScheduleSearchRefresh)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    onlineSearchButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    onlineSearchButton:SetSize(118, 24)
    onlineSearchButton:SetPoint("TOPLEFT", 252, -40)
    onlineSearchButton:SetText(ns.L.SEARCH_ONLINE)
    onlineSearchButton:SetScript("OnClick", function()
        if ns.Who then
            ns.Who.Request(searchBox:GetText())
        end
    end)

    whoStatusText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    whoStatusText:SetPoint("TOPLEFT", CONTENT_LEFT, -68)
    whoStatusText:SetWidth(CONTENT_WIDTH)
    whoStatusText:SetJustifyH("LEFT")
    whoStatusText:SetTextColor(0.7, 0.7, 0.7)

    panel.tabButtons = {}
    local tabs = {
        {
            key = "GENERAL",
            tooltip = ns.L.TAB_GENERAL,
            activeAtlas = "friends-icon-tab-friends",
            inactiveAtlas = "friends-icon-tab-friends-inactive",
        },
        {
            key = "GUILD",
            tooltip = ns.L.TAB_GUILD,
            iconTexture = "Interface/GuildFrame/GuildLogo-NoLogoSm",
        },
        {
            key = "FAVORITES",
            tooltip = ns.L.TAB_FAVORITES,
            activeAtlas = "friends-icon-favorites",
            inactiveAtlas = "friends-icon-favorites-dis",
        },
    }
    for tabIndex = 1, #tabs do
        local tab = tabs[tabIndex]
        local tabKey = tab.key
        local button = CreateFrame("Button", nil, panel, "LargeSideTabButtonTemplate")
        button:SetFrameLevel(panel:GetFrameLevel() + 2)
        button:SetPoint("TOPLEFT", panel, "TOPRIGHT", 0, -52 - ((tabIndex - 1) * 49))
        button.tooltipText = tab.tooltip
        button.activeAtlas = tab.activeAtlas
        button.inactiveAtlas = tab.inactiveAtlas
        if tab.iconTexture then
            button.Icon:SetTexture(tab.iconTexture)
            button.Icon:SetTexCoord(0, 1, 0, 1)
            button.Icon:SetSize(30, 30)
        end
        button:SetChecked(false)
        button:SetScript("OnClick", function()
            SetActiveTab(tabKey)
        end)
        panel.tabButtons[tabKey] = button
    end

    scrollFrame = CreateFrame("ScrollFrame", "FEFSContactScrollFrame", panel, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", CONTENT_LEFT, -91)
    scrollFrame:SetSize(CONTENT_WIDTH - 8, VISIBLE_ROWS * ROW_HEIGHT)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
            MailContacts.Refresh("scroll")
        end)
    end)

    emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyText:SetPoint("CENTER", scrollFrame, "CENTER", 0, 20)
    emptyText:SetWidth(240)
    emptyText:SetJustifyH("CENTER")
    emptyText:SetTextColor(0.7, 0.7, 0.7)

    for rowIndex = 1, VISIBLE_ROWS do
        CreateRow(rowIndex)
    end

    toggleButton = CreateFrame("Button", "FEFSMailContactsToggle", MailFrame)
    toggleButton:SetSize(28, 36)
    toggleButton:SetPoint("TOPLEFT", SendMailFrame, "TOPRIGHT", 3, -10)
    toggleButton:SetNormalAtlas("common-button-tertiary-square-normal")
    toggleButton:SetPushedAtlas("common-button-tertiary-square-pressed")
    toggleButton:SetHighlightAtlas("common-button-tertiary-square-normal", "ADD")
    toggleButton.icon = toggleButton:CreateTexture(nil, "ARTWORK")
    toggleButton.icon:SetSize(10, 16)
    toggleButton.icon:SetPoint("CENTER")
    toggleButton:SetScript("OnClick", function()
        SetCollapsed(not ns.Database.GetSettings().panelCollapsed)
    end)
    toggleButton:SetScript("OnEnter", function(self)
        local collapsed = ns.Database.GetSettings().panelCollapsed == true
        ShowTooltip(self, collapsed and ns.L.SHOW_CONTACTS or ns.L.HIDE_CONTACTS, "ANCHOR_LEFT")
    end)
    toggleButton:SetScript("OnLeave", GameTooltip_Hide)

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
    if panel:IsShown() then
        MailContacts.Refresh("show")
    end
    return true
end

function MailContacts.IsInstalled()
    return installed
end

function MailContacts.Invalidate()
    resultsDirty = true
    MailContacts.Refresh("invalidation")
end

function MailContacts.UpdateWhoState()
    if not installed or not onlineSearchButton or not whoStatusText or not ns.Who then
        return
    end

    local enabled, label, message = ns.Who.GetState(searchBox:GetText())
    onlineSearchButton:SetText(label)
    onlineSearchButton:SetEnabled(enabled)
    whoStatusText:SetText(message or "")
end

function MailContacts.Refresh(reason)
    if not installed or not panel or not panel:IsShown() then
        return
    end

    local startedAt = ns.Performance and ns.Performance.Start()
    local query = searchBox:GetText() or ""
    local rebuilt = false
    if reason ~= "scroll" and reason ~= "search" and reason ~= "tab" then
        MailContacts.UpdateWhoState()
    end
    if resultsDirty or query ~= lastQuery or activeTab ~= lastTab then
        visibleResults = ns.Search.Filter(GetRecordsForActiveTab(), query)
        rebuilt = true
        resultsDirty = false
        lastQuery = query
        lastTab = activeTab
    end
    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    if not rebuilt and offset == lastRenderedOffset then
        if ns.Performance then
            ns.Performance.ContactRefresh(reason, startedAt, false, false)
        end
        return
    end
    lastRenderedOffset = offset

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
    if ns.Performance then
        ns.Performance.ContactRefresh(reason, startedAt, rebuilt, true)
    end
end
