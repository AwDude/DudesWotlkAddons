local ADDON = DudesLootTracker

local DEFAULT_POPUP_WIDTH = 300
local MIN_POPUP_WIDTH = 190
local MAX_POPUP_WIDTH = 600
local ROW_HEIGHT = 46
local ROW_SPACING = 4

local popup
local entries = {}
local rows = {}
local debugActive = false
local updateElapsed = 0

local QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 1, 1, 1 },
    [2] = { 0.12, 1, 0 },
    [3] = { 0, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 1, 0.5, 0 },
    [6] = { 0.9, 0.8, 0.5 },
    [7] = { 0.9, 0.8, 0.5 },
}

local DEBUG_ITEMS = {
    {
        name = "Beispiel: Epische Streitaxt",
        quality = 4,
        itemType = "Waffe",
        itemSubType = "Zweihandäxte",
        texture = "Interface\\Icons\\INV_Axe_09",
        count = 1,
        infoReady = true,
    },
    {
        name = "Beispiel: Frostemblem",
        quality = 3,
        itemType = "Verschiedenes",
        itemSubType = "Währung",
        texture = "Interface\\Icons\\INV_Misc_FrostEmblem_01",
        count = 2,
        infoReady = true,
    },
    {
        name = "Beispiel: Saronitbarren",
        quality = 2,
        itemType = "Handwerkswaren",
        itemSubType = "Metall & Stein",
        texture = "Interface\\Icons\\INV_Ingot_09",
        count = 4,
        infoReady = true,
    },
}

local function getPopupSettings()
    return ADDON.GetSettings().lootPopup
end

local function setBackdrop(frame, r, g, b, a)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(r, g, b, a)
end

local function getQualityColor(quality)
    if GetItemQualityColor then
        local r, g, b = GetItemQualityColor(tonumber(quality) or 1)
        if r then
            return r, g, b
        end
    end
    local color = QUALITY_COLORS[tonumber(quality) or 1] or QUALITY_COLORS[1]
    return color[1], color[2], color[3]
end

local function getPlayerKey(name)
    if not name then
        return nil
    end
    name = string.match(name, "|h%[(.-)%]|h") or name
    name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
    name = string.gsub(name, "|r", "")
    name = string.match(name, "^([^%-]+)") or name
    return string.lower(name)
end

local function isOwnLoot(recipient)
    return getPlayerKey(recipient) == getPlayerKey(UnitName and UnitName("player"))
end

local function savePosition()
    if not popup then
        return
    end
    local point, _, relativePoint, xOfs, yOfs = popup:GetPoint(1)
    local position = getPopupSettings().position
    position.point = point or "CENTER"
    position.relativePoint = relativePoint or point or "CENTER"
    position.xOfs = math.floor((tonumber(xOfs) or 0) + 0.5)
    position.yOfs = math.floor((tonumber(yOfs) or 0) + 0.5)
end

local function stopMoving()
    if not popup then
        return
    end
    popup:StopMovingOrSizing()
    savePosition()
end

local function stopSizing()
    if not popup then
        return
    end
    popup:StopMovingOrSizing()
    local width = ADDON.Clamp(popup:GetWidth(), MIN_POPUP_WIDTH, MAX_POPUP_WIDTH)
    getPopupSettings().width = math.floor(width + 0.5)
    popup:SetWidth(getPopupSettings().width)
    savePosition()
end

local function startMoving()
    if popup and getPopupSettings().debug then
        popup:StartMoving()
    end
end

local function startSizing()
    if popup and getPopupSettings().debug then
        popup:StartSizing("RIGHT")
    end
end

local function createRow()
    local row = CreateFrame("Button", nil, popup)
    row:SetWidth(popup:GetWidth() or DEFAULT_POPUP_WIDTH)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", startMoving)
    row:SetScript("OnDragStop", stopMoving)
    setBackdrop(row, 0.025, 0.03, 0.04, 0.94)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(36)
    row.icon:SetHeight(36)
    row.icon:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.iconBorder = row:CreateTexture(nil, "OVERLAY")
    row.iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    row.iconBorder:SetWidth(60)
    row.iconBorder:SetHeight(60)
    row.iconBorder:SetPoint("CENTER", row.icon, "CENTER", 0, 0)

    row.count = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", -1, 2)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetFont(STANDARD_TEXT_FONT, 12, "")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 9, -4)
    row.name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.name:SetHeight(18)
    row.name:SetJustifyH("LEFT")
    if row.name.SetWordWrap then
        row.name:SetWordWrap(false)
    end

    row.itemType = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.itemType:SetFont(STANDARD_TEXT_FONT, 10, "")
    row.itemType:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 9, 4)
    row.itemType:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.itemType:SetHeight(15)
    row.itemType:SetJustifyH("LEFT")
    row.itemType:SetTextColor(0.72, 0.75, 0.8)
    if row.itemType.SetWordWrap then
        row.itemType:SetWordWrap(false)
    end

    row:SetScript("OnEnter", function(self)
        local item = self.entry and self.entry.item
        if item and item.link and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(item.link)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    row:SetScript("OnClick", function(self)
        local item = self.entry and self.entry.item
        if item and item.link and HandleModifiedItemClick then
            HandleModifiedItemClick(item.link)
        end
    end)
    row:Hide()
    table.insert(rows, row)
    return row
end

local function renderRow(row, entry)
    local item = entry.item
    local r, g, b = getQualityColor(item.quality)
    local itemType = item.itemType or ""
    local itemSubType = item.itemSubType or ""
    local typeText
    if itemType ~= "" and itemSubType ~= "" and itemType ~= itemSubType then
        typeText = itemType .. " - " .. itemSubType
    else
        typeText = itemType ~= "" and itemType or itemSubType
    end
    if not typeText or typeText == "" then
        typeText = "Gegenstandsinformationen werden geladen ..."
    end

    row.entry = entry
    row.icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.name:SetText(item.name or ADDON.GetItemDisplayName(item.link))
    row.name:SetTextColor(r, g, b)
    row.itemType:SetText(typeText)
    row.count:SetText((tonumber(item.count) or 1) > 1 and tostring(item.count) or "")
    row:SetBackdropBorderColor(r, g, b, 0.9)
end

local function layoutEntries()
    if not popup then
        return
    end
    local growUp = getPopupSettings().growUp
    for index, entry in ipairs(entries) do
        local row = rows[index] or createRow()
        row:SetWidth(popup:GetWidth() or DEFAULT_POPUP_WIDTH)
        row:ClearAllPoints()
        if growUp then
            row:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 0, (index - 1) * (ROW_HEIGHT + ROW_SPACING))
        else
            row:SetPoint("TOPLEFT", popup, "TOPLEFT", 0, -(index - 1) * (ROW_HEIGHT + ROW_SPACING))
        end
        renderRow(row, entry)
        row:Show()
    end

    popup.debugHandle:SetWidth(popup:GetWidth() or DEFAULT_POPUP_WIDTH)
    for index = #entries + 1, #rows do
        rows[index].entry = nil
        rows[index]:Hide()
    end

    popup.debugHandle:ClearAllPoints()
    if growUp then
        popup.debugHandle:SetPoint("TOP", popup, "BOTTOM", 0, -4)
    else
        popup.debugHandle:SetPoint("BOTTOM", popup, "TOP", 0, 4)
    end

    if debugActive then
        popup.debugHandle:Show()
    else
        popup.debugHandle:Hide()
    end
    if #entries > 0 then
        popup:Show()
    else
        popup:Hide()
    end
end

local function clearEntries()
    for index = #entries, 1, -1 do
        table.remove(entries, index)
    end
    layoutEntries()
end

local function loadPosition()
    local position = getPopupSettings().position
    popup:ClearAllPoints()
    popup:SetPoint(
        position.point or "CENTER",
        UIParent,
        position.relativePoint or position.point or "CENTER",
        tonumber(position.xOfs) or 0,
        tonumber(position.yOfs) or 0
    )
end

local function showDebugItems()
    clearEntries()
    for _, definition in ipairs(DEBUG_ITEMS) do
        local item = ADDON.CopyTable(definition)
        table.insert(entries, { item = item, debug = true })
    end
    layoutEntries()
end

local function updateEntries(_, elapsed)
    updateElapsed = updateElapsed + (tonumber(elapsed) or 0)
    if updateElapsed < 0.1 then
        return
    end
    updateElapsed = 0

    local changed = false
    local now = GetTime and GetTime() or 0
    if not debugActive then
        for index = #entries, 1, -1 do
            if entries[index].expiresAt and entries[index].expiresAt <= now then
                table.remove(entries, index)
                changed = true
            end
        end
    end

    for _, entry in ipairs(entries) do
        if not entry.debug and not entry.item.infoReady and ADDON.RefreshItemInfo(entry.item) then
            changed = true
        end
    end
    if changed then
        layoutEntries()
    end
end

local function applySettings()
    if not popup then
        return
    end
    loadPosition()
    local settings = getPopupSettings()
    popup:SetWidth(ADDON.Clamp(settings.width, MIN_POPUP_WIDTH, MAX_POPUP_WIDTH))
    if settings.debug then
        if not debugActive then
            debugActive = true
            showDebugItems()
        else
            layoutEntries()
        end
    else
        if debugActive then
            debugActive = false
            clearEntries()
        elseif not settings.enabled then
            clearEntries()
        else
            layoutEntries()
        end
    end
end

function ADDON.CreateLootPopup()
    if popup then
        return popup
    end

    popup = CreateFrame("Frame", "DudesLootTrackerLootPopup", UIParent)
    popup:SetWidth(DEFAULT_POPUP_WIDTH)
    popup:SetHeight(ROW_HEIGHT)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(120)
    popup:SetMovable(true)
    popup:SetResizable(true)
    popup:SetMinResize(MIN_POPUP_WIDTH, ROW_HEIGHT)
    if popup.SetMaxResize then
        popup:SetMaxResize(MAX_POPUP_WIDTH, ROW_HEIGHT)
    end
    popup:SetClampedToScreen(true)
    popup:SetScript("OnUpdate", updateEntries)
    popup:SetScript("OnSizeChanged", layoutEntries)

    popup.debugHandle = CreateFrame("Frame", nil, popup)
    popup.debugHandle:SetWidth(DEFAULT_POPUP_WIDTH)
    popup.debugHandle:SetHeight(22)
    popup.debugHandle:EnableMouse(true)
    popup.debugHandle:RegisterForDrag("LeftButton")
    popup.debugHandle:SetScript("OnDragStart", startMoving)
    popup.debugHandle:SetScript("OnDragStop", stopMoving)
    setBackdrop(popup.debugHandle, 0.08, 0.1, 0.14, 0.96)
    popup.debugHandle.text = popup.debugHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popup.debugHandle.text:SetPoint("LEFT", popup.debugHandle, "LEFT", 8, 0)
    popup.debugHandle.text:SetPoint("RIGHT", popup.debugHandle, "RIGHT", -24, 0)
    popup.debugHandle.text:SetText("Debugmodus - Leiste verschieben, rechten Griff für Breite ziehen")
    popup.debugHandle.text:SetTextColor(0.72, 0.86, 1)

    popup.debugHandle.resizeGrip = CreateFrame("Button", nil, popup.debugHandle)
    popup.debugHandle.resizeGrip:SetWidth(18)
    popup.debugHandle.resizeGrip:SetHeight(18)
    popup.debugHandle.resizeGrip:SetPoint("RIGHT", popup.debugHandle, "RIGHT", -3, 0)
    popup.debugHandle.resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    popup.debugHandle.resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    popup.debugHandle.resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    popup.debugHandle.resizeGrip:RegisterForDrag("LeftButton")
    popup.debugHandle.resizeGrip:SetScript("OnDragStart", startSizing)
    popup.debugHandle.resizeGrip:SetScript("OnDragStop", stopSizing)
    popup.debugHandle:Hide()

    popup:Hide()
    applySettings()
    return popup
end

function ADDON.ApplyLootPopupSettings()
    if not popup then
        ADDON.CreateLootPopup()
        return
    end
    applySettings()
end

function ADDON.ShowLootPopupItem(link, count, recipient)
    local settings = getPopupSettings()
    if not settings.enabled or settings.debug then
        return
    end
    if settings.ownOnly and not isOwnLoot(recipient) then
        return
    end

    ADDON.CreateLootPopup()
    local item = ADDON.BuildItem(link, math.max(1, tonumber(count) or 1))
    table.insert(entries, {
        item = item,
        recipient = recipient,
        expiresAt = (GetTime and GetTime() or 0) + ADDON.Clamp(settings.duration, 1, 120),
    })
    layoutEntries()
end
