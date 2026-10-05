local _, ns = ...

local WhisperSuggestions = {}
ns.WhisperSuggestions = WhisperSuggestions

local MAX_RESULTS = 5
local PANEL_WIDTH = 270
local ROW_HEIGHT = 44
local PANEL_PADDING = 8

local panel
local rows = {}
local results = {}
local selectedIndex = 1
local activeEditBox
local selectionHandler

local function SetClassIcon(row, record)
    local coordinates = record.classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[record.classFile]
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

local function UpdateHighlights()
    for rowIndex = 1, #rows do
        if panel:IsShown() and rowIndex == selectedIndex and rows[rowIndex]:IsShown() then
            rows[rowIndex].selection:Show()
        else
            rows[rowIndex].selection:Hide()
        end
    end
end

local function SelectRow(rowIndex)
    local result = results[rowIndex]
    if result and type(selectionHandler) == "function" then
        selectionHandler(activeEditBox, result.record)
    end
end

local function CreateRow(rowIndex)
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(PANEL_WIDTH - (PANEL_PADDING * 2), ROW_HEIGHT)
    row:SetPoint("TOPLEFT", PANEL_PADDING, -PANEL_PADDING - ((rowIndex - 1) * ROW_HEIGHT))

    row.selection = row:CreateTexture(nil, "BACKGROUND")
    row.selection:SetAllPoints()
    row.selection:SetColorTexture(1, 1, 1, 0.12)
    row.selection:Hide()

    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetSize(30, 30)
    row.classIcon:SetPoint("LEFT", 4, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.classIcon, "TOPRIGHT", 7, -5)
    row.name:SetWidth(PANEL_WIDTH - 58)
    row.name:SetJustifyH("LEFT")

    row.metadata = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.metadata:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.metadata:SetWidth(PANEL_WIDTH - 58)
    row.metadata:SetJustifyH("LEFT")
    row.metadata:SetTextColor(0.7, 0.7, 0.7)

    row:SetScript("OnEnter", function()
        selectedIndex = rowIndex
        UpdateHighlights()
    end)
    row:SetScript("OnClick", function()
        SelectRow(rowIndex)
    end)
    rows[rowIndex] = row
end

local function CreatePanel()
    panel = CreateFrame("Frame", "FEFSWhisperSuggestions", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, PANEL_PADDING * 2)
    panel:SetFrameStrata("TOOLTIP")
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:Hide()

    for rowIndex = 1, MAX_RESULTS do
        CreateRow(rowIndex)
    end
end

local function AnchorToEditBox(editBox, resultCount)
    local height = PANEL_PADDING * 2 + (resultCount * ROW_HEIGHT)
    panel:SetHeight(height)
    panel:ClearAllPoints()

    local editBoxTop = editBox.GetTop and editBox:GetTop()
    local screenHeight = UIParent.GetHeight and UIParent:GetHeight()
    if editBoxTop and screenHeight and editBoxTop + height + 4 > screenHeight then
        panel:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -4)
    else
        panel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 0, 4)
    end
end

function WhisperSuggestions.SetSelectionHandler(handler)
    selectionHandler = type(handler) == "function" and handler or nil
end

function WhisperSuggestions.Show(editBox, searchResults)
    if not panel then
        CreatePanel()
    end

    wipe(results)
    local resultCount = math.min(type(searchResults) == "table" and #searchResults or 0, MAX_RESULTS)
    if not editBox or resultCount == 0 then
        WhisperSuggestions.Hide(editBox)
        return false
    end

    activeEditBox = editBox
    selectedIndex = 1
    for rowIndex = 1, MAX_RESULTS do
        local row = rows[rowIndex]
        local result = searchResults[rowIndex]
        if rowIndex <= resultCount and result and type(result.record) == "table" then
            local record = result.record
            results[rowIndex] = result
            row.record = record
            row.name:SetText(record.displayName or record.actionName)
            row.metadata:SetText(ns.Formatter.GetMetadata(record))
            SetClassIcon(row, record)
            SetClassColor(row, record)
            row:Show()
        else
            row.record = nil
            row:Hide()
        end
    end

    AnchorToEditBox(editBox, resultCount)
    panel:Show()
    UpdateHighlights()
    return true
end

function WhisperSuggestions.Hide(editBox)
    if not panel or (editBox and activeEditBox ~= editBox) then
        return false
    end
    panel:Hide()
    activeEditBox = nil
    wipe(results)
    selectedIndex = 1
    UpdateHighlights()
    return true
end

function WhisperSuggestions.IsShownFor(editBox)
    return panel and panel:IsShown() and activeEditBox == editBox
end

function WhisperSuggestions.MoveSelection(editBox, direction)
    if not WhisperSuggestions.IsShownFor(editBox) or #results == 0 then
        return false
    end
    selectedIndex = ((selectedIndex - 1 + direction) % #results) + 1
    UpdateHighlights()
    return true
end

function WhisperSuggestions.Select(editBox)
    if not WhisperSuggestions.IsShownFor(editBox) then
        return false
    end
    SelectRow(selectedIndex)
    return true
end
