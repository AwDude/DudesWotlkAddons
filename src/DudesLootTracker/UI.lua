local ADDON = DudesLootTracker

local window
local automationDialog
local lootRows = {}
local lootLayoutEntries = {}
local registeredSpecialFrame
local focusedNumberBox
local lootContentMinHeight = 1
local pendingShowWindow
local pendingRefreshMainWindow
local pendingResizeLayout
local pendingLootViewportRefresh
local isInstanceContext
local requestLootViewportRefresh
local renderLootLayoutEntry
local BORDER_R, BORDER_G, BORDER_B = 0.32, 0.38, 0.46
local HOVER_R, HOVER_G, HOVER_B = 0.72, 0.86, 1
local BOSS_TEXT_COLOR = "b82020"
local MIN_WIDTH, MIN_HEIGHT = 820, 430
local TOP_TITLE_Y = -18
local TITLE_CONTENT_GAP = 30
local SCROLLBAR_BOTTOM_INSET = 16
local SCROLLFRAME_BOTTOM_ADJUST = 2
local LOOT_SCROLLBAR_BOTTOM_ADJUST = -3
local LEFT_WIDTH = 226
local DIVIDER_GAP = 6
local DIVIDER_SCROLL_GAP = 12
local DIVIDER_WIDTH = 1
local DIVIDER_SHADOW_WIDTH = 1
local DIVIDER_OUTER_SHADOW_WIDTH = 1
local SCROLLBAR_RESERVE = 18
local ROW_HEIGHT = 28
local CONTROL_LABEL_WIDTH = 132
local CONTROL_VALUE_CENTER_X = -30
local CONTROL_RANGE_MINOR_WIDTH = 24
local CONTROL_RANGE_INPUT_GAP = 5
local CONTROL_LABEL_GAP = 6
local CHECKBOX_LABEL_GAP = 13
local CONTROL_ROW_HEIGHT = 26
local CARD_GAP = 6
local PRIMORDIAL_SARONITE_LINK = "|cffa335ee|Hitem:49908:0:0:0:0:0:0:0:80|h[Urtümliches Saronit]|h|r"
local AUTOMATION_ACTION_LABELS = {
    manual = "Manuell",
    pass = "Passen",
    disenchant = "Entzaubern",
    greed = "Gier",
    need = "Bedarf",
}

local function setBackdrop(frame, r, g, b, a)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(r, g, b, a)
    frame:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
end

local function removeFontOutline(fontString, fallbackSize)
    if not fontString or not fontString.GetFont or not fontString.SetFont then
        return
    end
    local font, size = fontString:GetFont()
    fontString:SetFont(font or STANDARD_TEXT_FONT, size or fallbackSize or 11, "")
end

local function addBorderHover(frame)
    frame:HookScript("OnEnter", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(HOVER_R, HOVER_G, HOVER_B, 1)
        end
    end)
    frame:HookScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
        end
    end)
end

local function styleButton(button)
    if not button then
        return
    end
    if button.GetNormalTexture and button:GetNormalTexture() then
        button:GetNormalTexture():SetTexture(nil)
    end
    if button.GetPushedTexture and button:GetPushedTexture() then
        button:GetPushedTexture():SetTexture(nil)
    end
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    if button:GetHighlightTexture() then
        button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0)
    end
    setBackdrop(button, 0.09, 0.105, 0.13, 1)
    addBorderHover(button)
    if button:GetFontString() then
        removeFontOutline(button:GetFontString(), 11)
        button:GetFontString():SetTextColor(0.86, 0.92, 1)
    end
end

local function createText(parent, size, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetFont(STANDARD_TEXT_FONT, size or 11, "")
    text:SetJustifyH(justify or "LEFT")
    return text
end

local function setTextColorHex(text, hex)
    if not text or not hex then
        return
    end
    local r = tonumber(string.sub(hex, 1, 2), 16) or 255
    local g = tonumber(string.sub(hex, 3, 4), 16) or 255
    local b = tonumber(string.sub(hex, 5, 6), 16) or 255
    text:SetTextColor(r / 255, g / 255, b / 255)
end

local function createSectionTitle(parent, text)
    local title = createText(parent, 13)
    title:SetText(text)
    title:SetTextColor(1, 0.82, 0.1)
    return title
end

local function registerSpecialFrame()
    if registeredSpecialFrame or not UISpecialFrames then
        return
    end
    table.insert(UISpecialFrames, "DudesLootTrackerWindow")
    registeredSpecialFrame = true
end

local function savePlacement()
    if not window then
        return
    end
    local settings = ADDON.GetSettings()
    settings.window = settings.window or {}
    local point, _, relativePoint, xOfs, yOfs = window:GetPoint()
    settings.window.point = point
    settings.window.relativePoint = relativePoint
    settings.window.xOfs = xOfs
    settings.window.yOfs = yOfs
    settings.window.width = window:GetWidth()
    settings.window.height = window:GetHeight()
end

local function loadPlacement()
    local placement = ADDON.GetSettings().window or {}
    window:SetWidth(math.max(MIN_WIDTH, placement.width or 920))
    window:SetHeight(math.max(MIN_HEIGHT, placement.height or 560))
    window:ClearAllPoints()
    window:SetPoint(placement.point or "CENTER", UIParent, placement.relativePoint or "CENTER", placement.xOfs or 0, placement.yOfs or 0)
end

local function clearFocusedNumberBox()
    if focusedNumberBox and focusedNumberBox.ClearFocus then
        focusedNumberBox:ClearFocus()
    end
end

local function createCheckbox(parent, label)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetWidth(22)
    checkbox:SetHeight(22)
    checkbox.text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    removeFontOutline(checkbox.text, 11)
    checkbox.text:SetFont(STANDARD_TEXT_FONT, 11, "")
    checkbox.text:SetText(label)
    checkbox.text:SetTextColor(1, 1, 1)
    checkbox.text:SetJustifyH("LEFT")
    checkbox:HookScript("OnMouseDown", clearFocusedNumberBox)
    return checkbox
end

local function createNumberBox(parent, width)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetWidth(width or 42)
    box:SetHeight(20)
    box:SetAutoFocus(false)
    box:SetFont(STANDARD_TEXT_FONT, 10, "")
    box:SetJustifyH("CENTER")
    box:SetTextInsets(0, 0, 0, 0)
    setBackdrop(box, 0.055, 0.065, 0.08, 1)
    addBorderHover(box)
    box:SetScript("OnEditFocusGained", function(self)
        focusedNumberBox = self
        self:HighlightText()
    end)
    return box
end

local function parseOpenNumber(text, fallback)
    if text == "-" or text == "" then
        return nil
    end
    return tonumber(text) or fallback
end

local function formatOpenNumber(value)
    value = tonumber(value)
    if not value then
        return "-"
    end
    return tostring(value)
end

local function formatSegmentDateTime(timestamp)
    timestamp = timestamp or ADDON.GetNow()
    if date then
        return date("%d.%m.%y", timestamp), date("%H:%M", timestamp)
    end
    return "", tostring(timestamp)
end

local function createSmallButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width or 82)
    button:SetHeight(22)
    button:SetText(text)
    styleButton(button)
    button:HookScript("OnMouseDown", clearFocusedNumberBox)
    return button
end

local function setButtonTextColor(button, r, g, b)
    if button and button:GetFontString() then
        button:GetFontString():SetTextColor(r, g, b)
    end
end

local function createCard(parent, height)
    local card = CreateFrame("Frame", nil, parent)
    card:SetHeight(height or CONTROL_ROW_HEIGHT)
    setBackdrop(card, 0.04, 0.047, 0.058, 0.88)
    card:SetBackdropBorderColor(0.18, 0.21, 0.28, 0.95)
    card:EnableMouse(true)
    card:SetScript("OnMouseDown", clearFocusedNumberBox)
    return card
end

local function clearRows(rows)
    for _, row in ipairs(rows) do
        row._activeLayout = false
        row:Hide()
    end
end

local function updateScrollBarVisibility(scroll, padding)
    if not scroll or not scroll.GetName then
        return false
    end
    local scrollBar = _G[scroll:GetName() .. "ScrollBar"]
    if not scrollBar or not scrollBar.GetMinMaxValues then
        return false
    end
    if padding and scroll.GetScrollChild and scroll.GetHeight then
        local child = scroll:GetScrollChild()
        if child and child.GetHeight then
            local needsScroll = child:GetHeight() > (scroll:GetHeight() + padding)
            if not needsScroll then
                scrollBar:SetValue(0)
                scrollBar:Hide()
                return false
            end
            scrollBar:Show()
            return true
        end
    end
    local minValue, maxValue = scrollBar:GetMinMaxValues()
    if (maxValue or 0) <= (minValue or 0) then
        scrollBar:Hide()
        return false
    else
        scrollBar:Show()
        return true
    end
end

local function showScrollBar(scroll)
    if not scroll or not scroll.GetName then
        return false
    end
    local scrollBar = _G[scroll:GetName() .. "ScrollBar"]
    if not scrollBar then
        return false
    end
    scrollBar:Show()
    return true
end

local function updateLootContentHeight()
    if window and window.lootContent and window.lootScroll then
        window.lootContent:SetHeight(math.max(window.lootScroll:GetHeight(), lootContentMinHeight))
    end
end

local function updateVisibleLootRows()
    if not window or not window.lootScroll or not window.lootScroll.GetName then
        return
    end
    if not renderLootLayoutEntry then
        return
    end
    local scrollBar = _G[window.lootScroll:GetName() .. "ScrollBar"]
    local scrollValue = scrollBar and scrollBar.GetValue and (scrollBar:GetValue() or 0) or 0
    local top = scrollValue - 80
    local bottom = scrollValue + (window.lootScroll:GetHeight() or 0) + 80
    clearRows(lootRows)
    local index = 1
    for _, entry in ipairs(lootLayoutEntries) do
        local rowTop = entry.top or 0
        local rowBottom = rowTop + (entry.height or 0)
        if rowBottom >= top and rowTop <= bottom then
            renderLootLayoutEntry(index, entry)
            index = index + 1
        end
    end
end

local function rememberLootRow(row, y, height)
    row._layoutTop = -y
    row._layoutHeight = height
    row._activeLayout = true
end

local function isLootRowInViewport(y, height)
    if not window or not window.lootScroll or not window.lootScroll.GetName then
        return true
    end
    local scrollBar = _G[window.lootScroll:GetName() .. "ScrollBar"]
    local scrollValue = scrollBar and scrollBar.GetValue and (scrollBar:GetValue() or 0) or 0
    local rowTop = -y
    local rowBottom = rowTop + height
    local top = scrollValue - 80
    local bottom = scrollValue + (window.lootScroll:GetHeight() or 0) + 80
    return rowBottom >= top and rowTop <= bottom
end

local function placeScrollBar(scroll, xOffset, bottomOffset)
    if not scroll or not scroll.GetName then
        return
    end
    local scrollBar = _G[scroll:GetName() .. "ScrollBar"]
    if not scrollBar then
        return
    end
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", xOffset or -4, -16)
    scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", xOffset or -4, bottomOffset or 16)
end

local function placeScrollBarBeforeDivider(scroll, dividerX, bottomOffset)
    if not scroll or not scroll.GetName then
        return
    end
    local scrollBar = _G[scroll:GetName() .. "ScrollBar"]
    if not scrollBar then
        return
    end
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", window, "TOPLEFT", dividerX - 4, -26)
    scrollBar:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", dividerX - 4, bottomOffset or 16)
end

local function acquireLootRow(index)
    if lootRows[index] then
        lootRows[index]:Show()
        return lootRows[index]
    end
    local row = CreateFrame("Frame", nil, window.lootContent)
    row:SetHeight(ROW_HEIGHT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(22)
    row.icon:SetHeight(22)
    row.icon:SetPoint("LEFT", row, "LEFT", 7, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.count = createText(row, 8, "RIGHT")
    row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", -1, 1)
    row.count:SetWidth(24)
    row.count:SetHeight(10)
    row.count:SetTextColor(1, 1, 1)
    row.text = createText(row, 10)
    row.subtext = createText(row, 8)
    row.detail = createText(row, 9, "RIGHT")
    row:EnableMouse(true)
    row:SetScript("OnMouseDown", clearFocusedNumberBox)
    lootRows[index] = row
    return row
end

local function resetLootRow(row)
    row.icon:Hide()
    if row.count then
        row.count:Hide()
    end
    if row.subtext then
        row.subtext:SetText("")
    end
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    row:SetScript("OnMouseDown", clearFocusedNumberBox)
    row:SetScript("OnMouseUp", nil)
end

local function getQualityKey(quality)
    quality = tonumber(quality) or 1
    if quality >= 5 then
        return "legendary"
    elseif quality == 4 then
        return "epic"
    elseif quality == 3 then
        return "rare"
    elseif quality == 2 then
        return "uncommon"
    elseif quality == 1 then
        return "common"
    elseif quality <= 0 then
        return "poor"
    end
    return "common"
end

local function rowPassesFilters(item, segment)
    local filters = ADDON.GetFilters()
    filters.qualities = filters.qualities or {}
    filters.enemies = filters.enemies or {}

    if filters.ownOnly then
        local player = ADDON.GetPlayerName()
        local found
        for _, recipient in ipairs(item.recipients or {}) do
            if recipient.name == player then
                found = true
                break
            end
        end
        if not found then
            return false
        end
    end
    if filters.boeOnly and not (ADDON.RefreshItemBindInfo and ADDON.RefreshItemBindInfo(item)) then
        return false
    end

    if not filters.qualities[getQualityKey(item.quality)] then
        return false
    end
    if not filters.enemies[segment.type or "normal"] then
        return false
    end

    local itemLevel = tonumber(item.itemLevel or 0) or 0
    local requiredLevel = tonumber(item.requiredLevel or 0) or 0
    if filters.minItemLevel and itemLevel < tonumber(filters.minItemLevel) then
        return false
    end
    if filters.maxItemLevel and itemLevel > tonumber(filters.maxItemLevel) then
        return false
    end
    if filters.minRequiredLevel and requiredLevel < tonumber(filters.minRequiredLevel) then
        return false
    end
    if filters.maxRequiredLevel and requiredLevel > tonumber(filters.maxRequiredLevel) then
        return false
    end
    return true
end

local function formatRecipients(item)
    local parts = {}
    for _, recipient in ipairs(item.recipients or {}) do
        local method = recipient.method
        local methodLabel
        if method == "trade" then
            methodLabel = "Handel"
        elseif method == "master" then
            methodLabel = "zugeteilt"
        elseif method == "manual" then
            methodLabel = "manuell"
        elseif method == "need" then
            methodLabel = "Bedarf"
        elseif method == "greed" then
            methodLabel = "Gier"
        elseif method == "disenchant" then
            methodLabel = "Entzaubern"
        elseif method == "loot" then
            methodLabel = "gelootet"
        end
        if methodLabel then
            local timeText = recipient.timestamp and (" " .. ADDON.FormatTime(recipient.timestamp)) or ""
            table.insert(parts, tostring(recipient.name or "?") .. " (" .. methodLabel .. timeText .. ")")
        else
            table.insert(parts, recipient.name or "?")
        end
    end
    return table.concat(parts, ", ")
end

local function formatOwnership(item)
    local recipients = formatRecipients(item)
    if recipients ~= "" then
        return recipients
    end
    return "unverteilt"
end

local function formatItemInfo(item)
    local parts = {}
    local slot = item.slot or ""
    local subType = item.itemSubType or ""
    local lowerSubType = string.lower(subType)
    local isGenericSubType = lowerSubType == "verschiedenes" or lowerSubType == "miscellaneous" or lowerSubType == "misc"
    if item.isEquipment then
        if subType ~= "" and slot ~= "" and subType ~= slot and not isGenericSubType then
            table.insert(parts, subType)
            table.insert(parts, slot)
        elseif slot ~= "" then
            table.insert(parts, slot)
        elseif subType ~= "" and not isGenericSubType then
            table.insert(parts, subType)
        end
    elseif subType ~= "" and not isGenericSubType then
        table.insert(parts, subType)
    elseif item.itemType and item.itemType ~= "" then
        table.insert(parts, item.itemType)
    end
    if ADDON.RefreshItemBindInfo and ADDON.RefreshItemBindInfo(item) then
        table.insert(parts, "BoE")
    end
    if item.isEquipment and item.itemLevel and item.itemLevel > 0 then
        table.insert(parts, "<" .. tostring(item.itemLevel) .. ">")
    end
    return table.concat(parts, " ")
end

local function formatItemDetail(item)
    return formatOwnership(item)
end

local function setupItemTooltip(row, item)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if item.link then
            GameTooltip:SetHyperlink(item.link)
        else
            GameTooltip:AddLine(item.name or "Item")
        end
        if item.disenchantRewards and #item.disenchantRewards > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Entzaubert zu:", 1, 0.82, 0.1)
            for _, rewardLink in ipairs(item.disenchantRewards) do
                GameTooltip:AddLine(rewardLink, 1, 1, 1)
            end
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function setupItemClick(row, item)
    row:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            item.expanded = not item.expanded
            ADDON.RefreshMainWindow()
        end
    end)
end

local function formatInstanceLabel(segment)
    if not segment or not segment.raid or segment.raid == "" or segment.raid == "World" then
        return "Außerhalb"
    end
    local size = tonumber(segment.raidSize or 0) or 0
    if size <= 0 or segment.instanceType == "none" then
        return tostring(segment.raid)
    end
    return tostring(segment.raid) .. "  |cffbfc8d8" .. tostring(size) .. " Spieler|r"
end

local function formatInstanceId(segment)
    if not segment or not segment.raid or segment.raid == "" or segment.raid == "World" then
        return ""
    end
    local size = tonumber(segment.raidSize or 0) or 0
    if size <= 0 or segment.instanceType == "none" then
        return ""
    end
    local raidId = segment.raidId
    if not raidId and segment.raidKey then
        raidId = string.match(segment.raidKey, ":([^:]+)$")
    end
    if not raidId or tostring(raidId) == "" or tostring(raidId) == "unsaved" then
        return ""
    end
    return "ID " .. tostring(raidId)
end

local function getInstanceGroupKey(segment)
    if not segment or not segment.raid or segment.raid == "" or segment.raid == "World" then
        return "outside"
    end
    return segment.raidKey or (tostring(segment.raid) .. ":" .. tostring(segment.raidSize or ""))
end

local function toggleInstanceItemDetails(segment)
    local targetKey = getInstanceGroupKey(segment)
    local anyCollapsed
    for _, groupedSegment in ipairs(ADDON.GetCharacterDB().segments or {}) do
        if getInstanceGroupKey(groupedSegment) == targetKey then
            for _, item in ipairs(groupedSegment.items or {}) do
                if item.disenchantRewards and #item.disenchantRewards > 0 then
                    if not item.expanded then
                        anyCollapsed = true
                        break
                    end
                end
            end
        end
        if anyCollapsed then
            break
        end
    end
    local expand = anyCollapsed and true or false
    for _, groupedSegment in ipairs(ADDON.GetCharacterDB().segments or {}) do
        if getInstanceGroupKey(groupedSegment) == targetKey then
            for _, item in ipairs(groupedSegment.items or {}) do
                if item.disenchantRewards and #item.disenchantRewards > 0 then
                    item.expanded = expand
                end
            end
        end
    end
    ADDON.RefreshMainWindow()
end

local function addInstanceHeader(index, segment, y)
    if not isLootRowInViewport(y, 30) then
        return y - 34, index
    end
    local row = acquireLootRow(index)
    resetLootRow(row)
    row:SetPoint("TOPLEFT", window.lootContent, "TOPLEFT", 4, y)
    row:SetPoint("RIGHT", window.lootContent, "RIGHT", -4, 0)
    row:SetHeight(30)
    setBackdrop(row, 0.028, 0.035, 0.048, 0.98)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -88, 0)
    row.text:SetFont(STANDARD_TEXT_FONT, 13, "")
    row.text:SetTextColor(1, 0.82, 0.1)
    row.text:SetText(formatInstanceLabel(segment))
    row.detail:ClearAllPoints()
    row.detail:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.detail:SetWidth(72)
    row.detail:SetHeight(16)
    row.detail:SetFont(STANDARD_TEXT_FONT, 8, "")
    row.detail:SetTextColor(0.78, 0.82, 0.88)
    row.detail:SetText(formatInstanceId(segment))
    row:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            toggleInstanceItemDetails(segment)
        end
    end)
    rememberLootRow(row, y, 30)
    return y - 34, index + 1
end

local function addSegmentHeader(index, segment, y)
    if not isLootRowInViewport(y, 30) then
        return y - 34, index
    end
    local row = acquireLootRow(index)
    resetLootRow(row)
    row:SetPoint("TOPLEFT", window.lootContent, "TOPLEFT", 16, y)
    row:SetPoint("RIGHT", window.lootContent, "RIGHT", -8, 0)
    row:SetHeight(30)
    local r, g, b, a = ADDON.GetSegmentColor(segment.type)
    setBackdrop(row, r, g, b, a)
    local title = tostring(segment.sourceName or segment.raid or "")
    if title == "" then
        title = segment.type == "boss" and "Boss" or (segment.type == "miniBoss" and "Elite" or "Normal")
    end
    local dateText, timeText = formatSegmentDateTime(segment.timestamp)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -108, 0)
    row.text:SetFont(STANDARD_TEXT_FONT, 11, "")
    row.text:SetText("|cffffffff" .. title .. "|r")
    row.detail:ClearAllPoints()
    row.detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.detail:SetWidth(92)
    row.detail:SetHeight(28)
    row.detail:SetFont(STANDARD_TEXT_FONT, 8, "")
    row.detail:SetTextColor(0.78, 0.82, 0.88)
    row.detail:SetText(timeText .. "\n" .. dateText)
    rememberLootRow(row, y, 30)
    return y - 34, index + 1
end

local function addItemRow(index, item, y)
    if not isLootRowInViewport(y, 36) then
        return y - 40, index
    end
    local row = acquireLootRow(index)
    resetLootRow(row)
    row:SetPoint("TOPLEFT", window.lootContent, "TOPLEFT", 32, y)
    row:SetPoint("RIGHT", window.lootContent, "RIGHT", -12, 0)
    row:SetHeight(36)
    row.icon:Show()
    row.icon:SetWidth(26)
    row.icon:SetHeight(26)
    row.icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    local count = tonumber(item.count or 1) or 1
    if row.count then
        if count > 1 then
            row.count:SetText(tostring(count))
            row.count:Show()
        else
            row.count:Hide()
        end
    end
    setBackdrop(row, 0.055, 0.065, 0.08, 0.95)
    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 7, -1)
    row.text:SetPoint("RIGHT", row, "RIGHT", -280, 0)
    row.text:SetHeight(14)
    row.text:SetFont(STANDARD_TEXT_FONT, 10, "")
    row.subtext:ClearAllPoints()
    row.subtext:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -1)
    row.subtext:SetPoint("RIGHT", row.text, "RIGHT", 0, 0)
    row.subtext:SetHeight(12)
    row.subtext:SetFont(STANDARD_TEXT_FONT, 8, "")
    row.subtext:SetTextColor(0.72, 0.76, 0.84)
    row.detail:ClearAllPoints()
    row.detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.detail:SetWidth(268)
    row.detail:SetHeight(32)
    row.detail:SetFont(STANDARD_TEXT_FONT, 8, "")
    row.text:SetText("|cff" .. ADDON.GetQualityColor(item.quality) .. tostring(item.name or "?") .. "|r")
    row.subtext:SetText(formatItemInfo(item))
    row.detail:SetText(formatItemDetail(item))
    setupItemTooltip(row, item)
    setupItemClick(row, item)
    rememberLootRow(row, y, 36)
    return y - 40, index + 1
end

local function addDetailRow(index, y, text, detail)
    if not isLootRowInViewport(y, 21) then
        return y - 23, index
    end
    local row = acquireLootRow(index)
    resetLootRow(row)
    row:SetPoint("TOPLEFT", window.lootContent, "TOPLEFT", 58, y)
    row:SetPoint("RIGHT", window.lootContent, "RIGHT", -18, 0)
    row:SetHeight(21)
    setBackdrop(row, 0.038, 0.044, 0.056, 0.96)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -170, 0)
    row.text:SetFont(STANDARD_TEXT_FONT, 9, "")
    row.text:SetText(text)
    row.detail:ClearAllPoints()
    row.detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.detail:SetWidth(160)
    row.detail:SetHeight(21)
    row.detail:SetFont(STANDARD_TEXT_FONT, 8, "")
    row.detail:SetTextColor(0.78, 0.82, 0.88)
    row.detail:SetText(detail or "")
    rememberLootRow(row, y, 21)
    return y - 23, index + 1
end

local function appendLootLayoutEntry(kind, y, height, payload)
    local entry = payload or {}
    entry.kind = kind
    entry.y = y
    entry.top = -y
    entry.height = height
    table.insert(lootLayoutEntries, entry)
end

local function appendExpandedItemLayout(item, y)
    if not item.expanded then
        return y
    end
    if item.disenchantRewards and #item.disenchantRewards > 0 then
        appendLootLayoutEntry("detail", y, 21, { text = "|cffffd200Entzaubert zu|r", detail = "" })
        y = y - 23
        for _, rewardLink in ipairs(item.disenchantRewards) do
            appendLootLayoutEntry("detail", y, 21, { text = rewardLink, detail = "" })
            y = y - 23
        end
    end
    return y
end

function renderLootLayoutEntry(index, entry)
    if entry.kind == "instance" then
        addInstanceHeader(index, entry.segment, entry.y)
    elseif entry.kind == "segment" then
        addSegmentHeader(index, entry.segment, entry.y)
    elseif entry.kind == "item" then
        addItemRow(index, entry.item, entry.y)
    elseif entry.kind == "detail" then
        addDetailRow(index, entry.y, entry.text, entry.detail)
    end
end

local function refreshLootContent()
    if not window then
        return
    end
    clearRows(lootRows)
    lootLayoutEntries = {}
    local y = -4
    local segments = ADDON.GetCharacterDB().segments or {}
    local lastInstanceKey
    local settings = ADDON.GetSettings()
    local maxVisibleItems = tonumber(settings.maxLootEntries or 0) or 0
    local visibleItemCount = 0
    for i = #segments, 1, -1 do
        if maxVisibleItems > 0 and visibleItemCount >= maxVisibleItems then
            break
        end
        local segment = segments[i]
        local anyVisible
        for _, item in ipairs(segment.items or {}) do
            if maxVisibleItems > 0 and visibleItemCount >= maxVisibleItems then
                break
            end
            if not item.infoReady then
                ADDON.RefreshItemInfo(item)
            end
            if rowPassesFilters(item, segment) then
                anyVisible = true
                break
            end
        end
        if anyVisible then
            local instanceKey = getInstanceGroupKey(segment)
            if instanceKey ~= lastInstanceKey then
                appendLootLayoutEntry("instance", y, 30, { segment = segment })
                y = y - 34
                lastInstanceKey = instanceKey
            end
            appendLootLayoutEntry("segment", y, 30, { segment = segment })
            y = y - 34
            for _, item in ipairs(segment.items or {}) do
                if maxVisibleItems > 0 and visibleItemCount >= maxVisibleItems then
                    break
                end
                if rowPassesFilters(item, segment) then
                    visibleItemCount = visibleItemCount + 1
                    appendLootLayoutEntry("item", y, 36, { item = item })
                    y = y - 40
                    y = appendExpandedItemLayout(item, y)
                end
            end
        end
    end
    lootContentMinHeight = -y + 16
    updateLootContentHeight()
    showScrollBar(window.lootScroll)
    updateVisibleLootRows()
end

local function resetFilters()
    local filters = ADDON.GetFilters()
    filters.ownOnly = false
    filters.boeOnly = false
    filters.minItemLevel = nil
    filters.maxItemLevel = nil
    filters.minRequiredLevel = nil
    filters.maxRequiredLevel = nil
    filters.qualities = { legendary = true, epic = true, rare = true, uncommon = true, common = true, poor = true }
    filters.enemies = { boss = true, miniBoss = true, normal = true }
end

local function setAllQuality(value)
    local qualities = ADDON.GetFilters().qualities
    qualities.legendary = value
    qualities.epic = value
    qualities.rare = value
    qualities.uncommon = value
    qualities.common = value
    qualities.poor = value
end

local function setAllEnemies(value)
    local enemies = ADDON.GetFilters().enemies
    enemies.boss = value
    enemies.miniBoss = value
    enemies.normal = value
end

local function refreshControls()
    if not window or not window.controls then
        return
    end
    local filters = ADDON.GetFilters()
    local contentWidth = window.controlContent:GetWidth() or (LEFT_WIDTH - 2)
    if window.automationFrame then
        window.automationFrame:SetWidth(contentWidth)
        window.automationFrame:Hide()
    end
    if window.filterFrame then
        window.filterFrame:SetWidth(contentWidth)
        window.filterFrame:ClearAllPoints()
        window.filterFrame:SetPoint("TOPLEFT", window.controlContent, "TOPLEFT", 0, 0)
    end
    local contentHeight = window.filterFrameHeight or 1
    window.controlContent:SetHeight(math.max(1, contentHeight))

    window.controls.ownOnly:SetChecked(filters.ownOnly and true or false)
    window.controls.boeOnly:SetChecked(filters.boeOnly and true or false)
    window.controls.minItemLevel:SetText(formatOpenNumber(filters.minItemLevel))
    window.controls.maxItemLevel:SetText(formatOpenNumber(filters.maxItemLevel))
    window.controls.minRequiredLevel:SetText(formatOpenNumber(filters.minRequiredLevel))
    window.controls.maxRequiredLevel:SetText(formatOpenNumber(filters.maxRequiredLevel))
    window.controls.legendary:SetChecked(filters.qualities.legendary)
    window.controls.epic:SetChecked(filters.qualities.epic)
    window.controls.rare:SetChecked(filters.qualities.rare)
    window.controls.uncommon:SetChecked(filters.qualities.uncommon)
    window.controls.common:SetChecked(filters.qualities.common)
    window.controls.poor:SetChecked(filters.qualities.poor)
    window.controls.boss:SetChecked(filters.enemies.boss)
    window.controls.miniBoss:SetChecked(filters.enemies.miniBoss)
    window.controls.normal:SetChecked(filters.enemies.normal)
end

local function addControl(parent, control, y, height, titleStyle)
    height = height or CONTROL_ROW_HEIGHT
    local card = createCard(parent, height)
    card.dltHeight = height
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
    card:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
    control:SetParent(card)
    control:ClearAllPoints()
    control:SetPoint("CENTER", card, "RIGHT", CONTROL_VALUE_CENTER_X, 0)
    if control.text then
        control.text:SetParent(card)
        control.text:ClearAllPoints()
        if titleStyle then
            control.text:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -5)
            control.text:SetPoint("RIGHT", control, "LEFT", -CHECKBOX_LABEL_GAP, 0)
            control.text:SetHeight(math.max(18, height - 6))
            control.text:SetJustifyH("LEFT")
            if control.text.SetJustifyV then
                control.text:SetJustifyV("TOP")
            end
        else
            control.text:SetPoint("RIGHT", control, "LEFT", -CHECKBOX_LABEL_GAP, 0)
            control.text:SetWidth(CONTROL_LABEL_WIDTH)
            control.text:SetHeight(height)
            control.text:SetJustifyH("RIGHT")
        end
    end
    return y - height - CARD_GAP, card
end

local function addNumberRange(parent, y, label, minBox, maxBox)
    local cardHeight = CONTROL_ROW_HEIGHT + 18
    local card = createCard(parent, cardHeight)
    card.dltHeight = cardHeight
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
    card:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
    minBox:SetParent(card)
    maxBox:SetParent(card)
    maxBox:ClearAllPoints()
    minBox:ClearAllPoints()
    minBox:SetWidth(38)
    maxBox:SetWidth(38)
    minBox:SetPoint("CENTER", card, "RIGHT", CONTROL_VALUE_CENTER_X, 8)
    maxBox:SetPoint("CENTER", card, "RIGHT", CONTROL_VALUE_CENTER_X, -8)

    local minLabel = createText(card, 10, "RIGHT")
    minLabel:SetPoint("RIGHT", minBox, "LEFT", -CONTROL_RANGE_INPUT_GAP, 0)
    minLabel:SetWidth(CONTROL_RANGE_MINOR_WIDTH)
    minLabel:SetHeight(16)
    minLabel:SetText("min")
    minLabel:SetTextColor(1, 1, 1)

    local maxLabel = createText(card, 10, "RIGHT")
    maxLabel:SetPoint("RIGHT", maxBox, "LEFT", -CONTROL_RANGE_INPUT_GAP, 0)
    maxLabel:SetWidth(CONTROL_RANGE_MINOR_WIDTH)
    maxLabel:SetHeight(16)
    maxLabel:SetText("max")
    maxLabel:SetTextColor(1, 1, 1)

    local text = createText(card, 11)
    text:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -3)
    text:SetPoint("RIGHT", minLabel, "LEFT", -CONTROL_LABEL_GAP, 0)
    text:SetHeight(18)
    text:SetJustifyH("LEFT")
    text:SetText(label)
    text:SetTextColor(1, 1, 1)

    return y - cardHeight - CARD_GAP, card
end

local function bindNumberFilter(box, filterKey, minValue, maxValue)
    local function apply(self)
        local value = parseOpenNumber(self:GetText(), ADDON.GetFilters()[filterKey])
        if value then
            value = ADDON.Clamp(value, minValue, maxValue)
        end
        ADDON.GetFilters()[filterKey] = value
        self:SetText(formatOpenNumber(value))
        if ADDON.RefreshMainWindow then
            ADDON.RefreshMainWindow()
        end
    end
    box:SetScript("OnEnterPressed", function(self)
        apply(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        if focusedNumberBox == self then
            focusedNumberBox = nil
        end
        apply(self)
    end)
end

local function createGroupCard(parent, y, title, toggleAll, entries)
    local rowHeight = 20
    local rowPadding = 2
    local height = #entries * rowHeight + rowPadding * 2
    local card = createCard(parent, height)
    card.dltHeight = height
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
    card:SetPoint("RIGHT", parent, "RIGHT", -6, 0)

    local titleButton = CreateFrame("Button", nil, card)
    titleButton:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -4)
    titleButton:SetWidth(math.max(58, string.len(title or "") * 9))
    titleButton:SetHeight(18)
    titleButton.text = createText(titleButton, 11)
    titleButton.text:SetAllPoints(titleButton)
    titleButton.text:SetJustifyH("LEFT")
    titleButton.text:SetText(title)
    titleButton.text:SetTextColor(1, 1, 1)
    titleButton:SetScript("OnClick", function()
        if toggleAll then
            toggleAll()
        end
    end)
    titleButton:HookScript("OnMouseDown", clearFocusedNumberBox)

    local rowY = -rowPadding
    for _, entry in ipairs(entries) do
        entry.checkbox:SetParent(card)
        entry.checkbox:ClearAllPoints()
        entry.checkbox:SetPoint("CENTER", card, "TOPRIGHT", CONTROL_VALUE_CENTER_X, rowY - (rowHeight / 2))
        if entry.checkbox.text then
            entry.checkbox.text:SetParent(card)
            entry.checkbox.text:ClearAllPoints()
            entry.checkbox.text:SetPoint("RIGHT", entry.checkbox, "LEFT", -CHECKBOX_LABEL_GAP, 0)
            entry.checkbox.text:SetWidth(CONTROL_LABEL_WIDTH)
            entry.checkbox.text:SetHeight(rowHeight)
            entry.checkbox.text:SetJustifyH("RIGHT")
        end
        rowY = rowY - rowHeight
    end

    return y - height - CARD_GAP, card
end

local function createControls()
    window.controls = {}
    local content = window.controlContent
    local sectionWidth = LEFT_WIDTH - 2

    local filterFrame = CreateFrame("Frame", nil, content)
    window.filterFrame = filterFrame
    filterFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    filterFrame:SetWidth(sectionWidth)
    local y = -8

    local filterTitle = createSectionTitle(filterFrame, "Filter")
    window.filterTitle = filterTitle
    filterTitle:SetPoint("TOPLEFT", filterFrame, "TOPLEFT", 14, y)
    filterTitle:SetFont(STANDARD_TEXT_FONT, 15, "")
    window.lootTitle = createSectionTitle(window, "Beute")
    window.lootTitle:SetFont(STANDARD_TEXT_FONT, 15, "")
    local reset = createSmallButton(filterFrame, "Zurücksetzen", 88)
    window.resetFiltersButton = reset
    reset:GetFontString():SetFont(STANDARD_TEXT_FONT, 10, "")
    reset:SetPoint("TOPRIGHT", filterFrame, "TOPRIGHT", -10, y + 3)
    reset:SetScript("OnClick", function()
        resetFilters()
        ADDON.RefreshMainWindow()
    end)
    y = y - TITLE_CONTENT_GAP

    local ownOnly = createCheckbox(filterFrame, "Gegenstand erhalten")
    window.controls.ownOnly = ownOnly
    ownOnly:SetScript("OnClick", function(self)
        ADDON.GetFilters().ownOnly = self:GetChecked() and true or false
        ADDON.RefreshMainWindow()
    end)
    y, ownOnly.dltCard = addControl(filterFrame, ownOnly, y, nil, true)

    local boeOnly = createCheckbox(filterFrame, "nur BoE")
    window.controls.boeOnly = boeOnly
    boeOnly:SetScript("OnClick", function(self)
        ADDON.GetFilters().boeOnly = self:GetChecked() and true or false
        ADDON.RefreshMainWindow()
    end)
    y, boeOnly.dltCard = addControl(filterFrame, boeOnly, y, nil, true)

    window.controls.minItemLevel = createNumberBox(filterFrame, 38)
    window.controls.maxItemLevel = createNumberBox(filterFrame, 38)
    y = addNumberRange(filterFrame, y, "Gegenstandsstufe", window.controls.minItemLevel, window.controls.maxItemLevel)
    bindNumberFilter(window.controls.minItemLevel, "minItemLevel", 1, 284)
    bindNumberFilter(window.controls.maxItemLevel, "maxItemLevel", 1, 284)

    window.controls.minRequiredLevel = createNumberBox(filterFrame, 38)
    window.controls.maxRequiredLevel = createNumberBox(filterFrame, 38)
    y = addNumberRange(filterFrame, y, "Level", window.controls.minRequiredLevel, window.controls.maxRequiredLevel)
    bindNumberFilter(window.controls.minRequiredLevel, "minRequiredLevel", 0, 80)
    bindNumberFilter(window.controls.maxRequiredLevel, "maxRequiredLevel", 0, 80)

    local qualityMap = {
        { key = "legendary", label = "Legendär", color = "ff8000" },
        { key = "epic", label = "Episch", color = "a335ee" },
        { key = "rare", label = "Selten", color = "0070dd" },
        { key = "uncommon", label = "Ungewöhnlich", color = "1eff00" },
        { key = "common", label = "Gewöhnlich", color = "ffffff" },
        { key = "poor", label = "Minderwertig", color = "9d9d9d" },
    }
    local qualityEntries = {}
    for _, entry in ipairs(qualityMap) do
        local cb = createCheckbox(filterFrame, entry.label)
        setTextColorHex(cb.text, entry.color)
        window.controls[entry.key] = cb
        cb:SetScript("OnClick", function(self)
            ADDON.GetFilters().qualities[entry.key] = self:GetChecked() and true or false
            ADDON.RefreshMainWindow()
        end)
        table.insert(qualityEntries, { checkbox = cb })
    end
    y = createGroupCard(filterFrame, y, "Qualität", function()
        local qualities = ADDON.GetFilters().qualities
        local allChecked = qualities.legendary and qualities.epic and qualities.rare and qualities.uncommon and qualities.common and qualities.poor
        setAllQuality(not allChecked)
        ADDON.RefreshMainWindow()
    end, qualityEntries)

    local enemyMap = {
        { key = "boss", label = "Boss", color = BOSS_TEXT_COLOR },
        { key = "miniBoss", label = "Elite", color = "ffd200" },
        { key = "normal", label = "Normal", color = "ffffff" },
    }
    local enemyEntries = {}
    for _, entry in ipairs(enemyMap) do
        local cb = createCheckbox(filterFrame, entry.label)
        setTextColorHex(cb.text, entry.color)
        window.controls[entry.key] = cb
        cb:SetScript("OnClick", function(self)
            ADDON.GetFilters().enemies[entry.key] = self:GetChecked() and true or false
            ADDON.RefreshMainWindow()
        end)
        table.insert(enemyEntries, { checkbox = cb })
    end
    y = createGroupCard(filterFrame, y, "Gegner", function()
        local enemies = ADDON.GetFilters().enemies
        local allChecked = enemies.boss and enemies.miniBoss and enemies.normal
        setAllEnemies(not allChecked)
        ADDON.RefreshMainWindow()
    end, enemyEntries)
    window.filterFrameHeight = -y - CARD_GAP
    filterFrame:SetHeight(window.filterFrameHeight)
    content:SetHeight(window.filterFrameHeight)
end

local function layoutWindow(refreshContent)
    if not window or not window.controlScroll or not window.lootScroll then
        return
    end
    local shouldRefreshContent = refreshContent ~= false
    local leftX = 12

    local function anchorMainAreas(rightReserve, reserveControlScrollbar)
        local dividerGap = reserveControlScrollbar and DIVIDER_SCROLL_GAP or DIVIDER_GAP
        local dividerX = leftX + LEFT_WIDTH + dividerGap
        local rightLeft = dividerX + DIVIDER_WIDTH + leftX

        window.controlScroll:ClearAllPoints()
        window.controlScroll:SetPoint("TOPLEFT", window, "TOPLEFT", leftX, -10)
        window.controlScroll:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", leftX, leftX + SCROLLFRAME_BOTTOM_ADJUST)
        window.controlScroll:SetWidth(LEFT_WIDTH)
        window.controlContent:SetWidth(LEFT_WIDTH - 2)
        placeScrollBarBeforeDivider(window.controlScroll, dividerX, leftX + SCROLLBAR_BOTTOM_INSET + SCROLLFRAME_BOTTOM_ADJUST)

        if window.divider then
            if window.dividerLeftOuterShadow then
                window.dividerLeftOuterShadow:ClearAllPoints()
                window.dividerLeftOuterShadow:SetPoint("TOPLEFT", window, "TOPLEFT", dividerX - DIVIDER_SHADOW_WIDTH - DIVIDER_OUTER_SHADOW_WIDTH, -3)
                window.dividerLeftOuterShadow:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", dividerX - DIVIDER_SHADOW_WIDTH - DIVIDER_OUTER_SHADOW_WIDTH, 3)
                window.dividerLeftOuterShadow:SetWidth(DIVIDER_OUTER_SHADOW_WIDTH)
            end
            if window.dividerLeftShadow then
                window.dividerLeftShadow:ClearAllPoints()
                window.dividerLeftShadow:SetPoint("TOPLEFT", window, "TOPLEFT", dividerX - DIVIDER_SHADOW_WIDTH, -3)
                window.dividerLeftShadow:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", dividerX - DIVIDER_SHADOW_WIDTH, 3)
                window.dividerLeftShadow:SetWidth(DIVIDER_SHADOW_WIDTH)
            end
            window.divider:ClearAllPoints()
            window.divider:SetPoint("TOPLEFT", window, "TOPLEFT", dividerX, -3)
            window.divider:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", dividerX, 3)
            window.divider:SetWidth(DIVIDER_WIDTH)
            if window.dividerRightShadow then
                window.dividerRightShadow:ClearAllPoints()
                window.dividerRightShadow:SetPoint("TOPLEFT", window, "TOPLEFT", dividerX + DIVIDER_WIDTH, -3)
                window.dividerRightShadow:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", dividerX + DIVIDER_WIDTH, 3)
                window.dividerRightShadow:SetWidth(DIVIDER_SHADOW_WIDTH)
            end
            if window.dividerRightOuterShadow then
                window.dividerRightOuterShadow:ClearAllPoints()
                window.dividerRightOuterShadow:SetPoint("TOPLEFT", window, "TOPLEFT", dividerX + DIVIDER_WIDTH + DIVIDER_SHADOW_WIDTH, -3)
                window.dividerRightOuterShadow:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", dividerX + DIVIDER_WIDTH + DIVIDER_SHADOW_WIDTH, 3)
                window.dividerRightOuterShadow:SetWidth(DIVIDER_OUTER_SHADOW_WIDTH)
            end
        end

        window.lootScroll:ClearAllPoints()
        window.lootScroll:SetPoint("TOPLEFT", window, "TOPLEFT", rightLeft, TOP_TITLE_Y - TITLE_CONTENT_GAP)
        window.lootScroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -leftX - rightReserve, leftX + SCROLLFRAME_BOTTOM_ADJUST)
        window.lootContent:SetWidth(math.max(1, window.lootScroll:GetWidth() - 4))
        placeScrollBar(window.lootScroll, -2, SCROLLBAR_BOTTOM_INSET + SCROLLFRAME_BOTTOM_ADJUST + LOOT_SCROLLBAR_BOTTOM_ADJUST)
        if window.lootTitle then
            window.lootTitle:ClearAllPoints()
            window.lootTitle:SetPoint("TOPLEFT", window, "TOPLEFT", rightLeft + 14, TOP_TITLE_Y)
        end

    end

    window.close:ClearAllPoints()
    window.close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -12, -10)
    window.settings:ClearAllPoints()
    window.settings:SetPoint("RIGHT", window.close, "LEFT", -6, 0)
    window.automationButton:ClearAllPoints()
    window.automationButton:SetPoint("RIGHT", window.settings, "LEFT", -6, 0)
    if isInstanceContext() then
        window.automationButton:Show()
    else
        window.automationButton:Hide()
    end

    anchorMainAreas(SCROLLBAR_RESERVE, true)

    if window.resizeGrip then
        window.resizeGrip:ClearAllPoints()
        window.resizeGrip:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -5, 5)
    end

    if shouldRefreshContent then
        refreshControls()
        refreshLootContent()
    else
        updateLootContentHeight()
        updateVisibleLootRows()
    end
    local controlCanScroll = updateScrollBarVisibility(window.controlScroll, 0)
    showScrollBar(window.lootScroll)
    if not controlCanScroll then
        anchorMainAreas(SCROLLBAR_RESERVE, false)
        updateLootContentHeight()
        updateScrollBarVisibility(window.controlScroll, 0)
        showScrollBar(window.lootScroll)
        updateVisibleLootRows()
    end
end

function requestLootViewportRefresh()
    if pendingLootViewportRefresh then
        return
    end
    pendingLootViewportRefresh = true
    local function run()
        pendingLootViewportRefresh = nil
        if window then
            updateVisibleLootRows()
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, run)
    else
        run()
    end
end

local function requestResizeLayout()
    if pendingResizeLayout then
        return
    end
    pendingResizeLayout = true
    local function run()
        pendingResizeLayout = nil
        if window then
            layoutWindow(false)
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, run)
    else
        run()
    end
end

local function createScrollFrame(name, parent)
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", name .. "Content", scroll)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = _G[self:GetName() .. "ScrollBar"]
        if scrollBar then
            local value = scrollBar:GetValue() or 0
            local minValue, maxValue = scrollBar:GetMinMaxValues()
            scrollBar:SetValue(ADDON.Clamp(value - delta * 32, minValue or 0, maxValue or 0))
            if self == window.lootScroll then
                requestLootViewportRefresh()
            end
        end
    end)
    return scroll, content
end

local function isIcecrownCitadel()
    if not GetInstanceInfo then
        return false
    end
    local name, instanceType, difficultyIndex, difficultyName, maxPlayers, playerDifficulty, isDynamic, mapID = GetInstanceInfo()
    return mapID == 631 or name == "Eiskronenzitadelle" or name == "Icecrown Citadel"
end

function isInstanceContext()
    if not GetInstanceInfo then
        return false
    end
    local name, instanceType = GetInstanceInfo()
    return instanceType == "party" or instanceType == "raid"
end

local function setSelectorValue(selector, value)
    selector.dltValue = value or "manual"
    selector:SetText(AUTOMATION_ACTION_LABELS[selector.dltValue] or AUTOMATION_ACTION_LABELS.manual)
end

local function hideActionSelectorMenus(exceptSelector)
    if not automationDialog or not automationDialog.controls then
        return
    end
    for _, row in pairs(automationDialog.controls) do
        local selector = row and row.selector
        if selector and selector ~= exceptSelector and selector.dltMenu then
            selector.dltMenu:Hide()
        end
    end
end

local function createActionSelectorMenu(selector)
    local actions = selector.dltActions or {}
    local width = selector:GetWidth()
    if not width or width < 1 then
        width = 82
    end
    local menu = CreateFrame("Frame", nil, selector)
    selector.dltMenu = menu
    menu:SetFrameLevel(selector:GetFrameLevel() + 10)
    menu:SetWidth(width)
    menu:SetHeight((#actions * 22) + 6)
    menu:EnableMouse(true)
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
    })
    menu:SetBackdropColor(0.02, 0.025, 0.035, 1)
    menu:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -2)
    menu:Hide()

    for index, action in ipairs(actions) do
        local option = createSmallButton(menu, AUTOMATION_ACTION_LABELS[action] or action, width - 6)
        option:SetFrameLevel(menu:GetFrameLevel() + 1)
        option:SetPoint("TOPLEFT", menu, "TOPLEFT", 3, -3 - ((index - 1) * 22))
        option:SetScript("OnClick", function()
            setSelectorValue(selector, action)
            menu:Hide()
        end)
    end

    return menu
end

local function createActionSelector(parent, actions)
    local selector = createSmallButton(parent, "Manuell", 82)
    selector.dltActions = actions
    selector:Enable()
    selector:EnableMouse(true)
    if selector.RegisterForClicks then
        selector:RegisterForClicks("AnyUp")
    end
    if selector:GetFontString() then
        selector:GetFontString():SetDrawLayer("OVERLAY", 7)
    end
    selector:SetScript("OnClick", function(self)
        hideActionSelectorMenus(self)
        if not self.dltMenu then
            createActionSelectorMenu(self)
        end
        if self.dltMenu:IsShown() then
            self.dltMenu:Hide()
        else
            self.dltMenu:Show()
        end
    end)
    return selector
end

local function createAutomationRow(parent, y, label, actions, itemLink)
    local row = CreateFrame("Frame", nil, parent)
    row:SetFrameLevel(parent:GetFrameLevel() + 1)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    row:SetHeight(28)
    row.label = CreateFrame("Button", nil, row)
    row.label:SetFrameLevel(row:GetFrameLevel() + 1)
    row.label:EnableMouse(itemLink and true or false)
    row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -90, 0)
    row.label:SetHeight(28)
    row.labelText = createText(row.label, 12)
    row.labelText:SetAllPoints(row.label)
    row.labelText:SetJustifyH("RIGHT")
    row.labelText:SetText(label)
    row.labelText:SetTextColor(1, 1, 1)
    row.labelText:SetDrawLayer("OVERLAY", 7)
    if itemLink then
        row.label:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()
        end)
        row.label:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    row.selector = createActionSelector(row, actions)
    row.selector:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.selector:SetFrameLevel(row:GetFrameLevel() + 2)
    return row
end

local function refreshAutomationDialogValues()
    if not automationDialog then
        return
    end
    hideActionSelectorMenus()
    local automation = ADDON.GetRollAutomation and ADDON.GetRollAutomation() or {}
    setSelectorValue(automationDialog.controls.bossAction.selector, automation.bossAction)
    setSelectorValue(automationDialog.controls.primordialSaroniteAction.selector, automation.primordialSaroniteAction)
    setSelectorValue(automationDialog.controls.uncommonNormalAction.selector, automation.uncommonNormalAction)
    setSelectorValue(automationDialog.controls.rareNormalAction.selector, automation.rareNormalAction)
    setSelectorValue(automationDialog.controls.epicBoeNonBossAction.selector, automation.epicBoeNonBossAction)
    if isIcecrownCitadel() then
        automationDialog.controls.primordialSaroniteAction:ClearAllPoints()
        automationDialog.controls.primordialSaroniteAction:SetPoint("TOPLEFT", automationDialog.content, "TOPLEFT", 0, -32)
        automationDialog.controls.primordialSaroniteAction:SetPoint("TOPRIGHT", automationDialog.content, "TOPRIGHT", 0, -32)
        automationDialog.controls.primordialSaroniteAction:Show()
        automationDialog.controls.uncommonNormalAction:ClearAllPoints()
        automationDialog.controls.uncommonNormalAction:SetPoint("TOPLEFT", automationDialog.content, "TOPLEFT", 0, -64)
        automationDialog.controls.uncommonNormalAction:SetPoint("TOPRIGHT", automationDialog.content, "TOPRIGHT", 0, -64)
        automationDialog.controls.rareNormalAction:ClearAllPoints()
        automationDialog.controls.rareNormalAction:SetPoint("TOPLEFT", automationDialog.content, "TOPLEFT", 0, -96)
        automationDialog.controls.rareNormalAction:SetPoint("TOPRIGHT", automationDialog.content, "TOPRIGHT", 0, -96)
        automationDialog.controls.epicBoeNonBossAction:ClearAllPoints()
        automationDialog.controls.epicBoeNonBossAction:SetPoint("TOPLEFT", automationDialog.content, "TOPLEFT", 0, -128)
        automationDialog.controls.epicBoeNonBossAction:SetPoint("TOPRIGHT", automationDialog.content, "TOPRIGHT", 0, -128)
        automationDialog:SetHeight(256)
    else
        automationDialog.controls.primordialSaroniteAction:Hide()
        automationDialog.controls.uncommonNormalAction:ClearAllPoints()
        automationDialog.controls.uncommonNormalAction:SetPoint("TOPLEFT", automationDialog.content, "TOPLEFT", 0, -32)
        automationDialog.controls.uncommonNormalAction:SetPoint("TOPRIGHT", automationDialog.content, "TOPRIGHT", 0, -32)
        automationDialog.controls.rareNormalAction:ClearAllPoints()
        automationDialog.controls.rareNormalAction:SetPoint("TOPLEFT", automationDialog.content, "TOPLEFT", 0, -64)
        automationDialog.controls.rareNormalAction:SetPoint("TOPRIGHT", automationDialog.content, "TOPRIGHT", 0, -64)
        automationDialog.controls.epicBoeNonBossAction:ClearAllPoints()
        automationDialog.controls.epicBoeNonBossAction:SetPoint("TOPLEFT", automationDialog.content, "TOPLEFT", 0, -96)
        automationDialog.controls.epicBoeNonBossAction:SetPoint("TOPRIGHT", automationDialog.content, "TOPRIGHT", 0, -96)
        automationDialog:SetHeight(224)
    end
end

function ADDON.ShowAutomationDialog()
    if not automationDialog then
        automationDialog = CreateFrame("Frame", "DudesLootTrackerAutomationDialog", UIParent)
        automationDialog:SetFrameStrata("DIALOG")
        automationDialog:SetFrameLevel(200)
        automationDialog:SetWidth(470)
        automationDialog:SetHeight(256)
        automationDialog:SetAlpha(1)
        automationDialog:EnableMouse(true)
        automationDialog:SetMovable(true)
        automationDialog:RegisterForDrag("LeftButton")
        automationDialog:SetScript("OnDragStart", function(self)
            self:StartMoving()
        end)
        automationDialog:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
        end)
        automationDialog:SetScript("OnHide", function()
            hideActionSelectorMenus()
        end)
        setBackdrop(automationDialog, 0.02, 0.025, 0.035, 1)
        automationDialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        automationDialog.controls = {}

        local title = createSectionTitle(automationDialog, "Würfel Automation")
        title:SetDrawLayer("OVERLAY", 7)
        title:SetFont(STANDARD_TEXT_FONT, 15, "")
        title:SetTextColor(1, 0.48, 0.08)
        title:SetPoint("TOPLEFT", automationDialog, "TOPLEFT", 0, -16)
        title:SetPoint("RIGHT", automationDialog, "RIGHT", 0, 0)
        title:SetJustifyH("CENTER")

        local content = CreateFrame("Frame", nil, automationDialog)
        automationDialog.content = content
        content:SetFrameLevel(automationDialog:GetFrameLevel() + 1)
        content:SetPoint("TOPLEFT", automationDialog, "TOPLEFT", 16, -54)
        content:SetPoint("TOPRIGHT", automationDialog, "TOPRIGHT", -16, -54)
        content:SetHeight(160)

        local standardActions = { "manual", "pass", "disenchant", "greed" }
        automationDialog.controls.bossAction = createAutomationRow(content, 0, "Beute von |cff" .. BOSS_TEXT_COLOR .. "Bossen|r", standardActions)
        automationDialog.controls.primordialSaroniteAction = createAutomationRow(content, -32, PRIMORDIAL_SARONITE_LINK, { "manual", "pass", "greed", "need" }, PRIMORDIAL_SARONITE_LINK)
        automationDialog.controls.uncommonNormalAction = createAutomationRow(content, -64, "|cff1eff00Ungewöhnliche|r Beute von normalen Gegnern", standardActions)
        automationDialog.controls.rareNormalAction = createAutomationRow(content, -96, "|cff0070ddSeltene|r Beute von normalen Gegnern", standardActions)
        automationDialog.controls.epicBoeNonBossAction = createAutomationRow(content, -128, "|cffa335eeEpische|r, beim Anlegen gebundene Beute von Nicht-Bossen", { "manual", "need", "pass", "disenchant", "greed" })

        local apply = createSmallButton(automationDialog, "Anwenden", 112)
        automationDialog.apply = apply
        apply:SetFrameLevel(automationDialog:GetFrameLevel() + 2)
        apply:Enable()
        apply:EnableMouse(true)
        apply:SetHeight(28)
        if apply:GetFontString() then
            apply:GetFontString():SetFont(STANDARD_TEXT_FONT, 12, "")
        end
        if apply.RegisterForClicks then
            apply:RegisterForClicks("AnyUp")
        end
        apply:SetPoint("BOTTOM", automationDialog, "BOTTOM", 0, 8)
        apply:SetScript("OnClick", function()
            if ADDON.SetRollAutomation then
                ADDON.SetRollAutomation({
                    bossAction = automationDialog.controls.bossAction.selector.dltValue,
                    primordialSaroniteAction = automationDialog.controls.primordialSaroniteAction.selector.dltValue,
                    uncommonNormalAction = automationDialog.controls.uncommonNormalAction.selector.dltValue,
                    rareNormalAction = automationDialog.controls.rareNormalAction.selector.dltValue,
                    epicBoeNonBossAction = automationDialog.controls.epicBoeNonBossAction.selector.dltValue,
                })
            end
            automationDialog:Hide()
            if ADDON.RefreshMainWindow then
                ADDON.RefreshMainWindow()
            end
        end)
    end
    refreshAutomationDialogValues()
    automationDialog:Show()
end

function ADDON.CreateMainWindow()
    if window then
        return window
    end
    window = CreateFrame("Frame", "DudesLootTrackerWindow", UIParent)
    window:SetFrameStrata("MEDIUM")
    window:SetFrameLevel(110)
    window:EnableMouse(true)
    window:SetMovable(true)
    if window.SetResizable then
        window:SetResizable(true)
    end
    if window.SetMinResize then
        window:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
    end
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnMouseDown", clearFocusedNumberBox)
    window:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePlacement()
    end)
    window:SetScript("OnSizeChanged", function()
        requestResizeLayout()
    end)
    setBackdrop(window, 0.02, 0.025, 0.035, 1)
    registerSpecialFrame()

    window.close = createSmallButton(window, "X", 34)
    window.close:SetScript("OnClick", function()
        window:Hide()
    end)
    window.settings = createSmallButton(window, "...", 34)
    window.settings:SetScript("OnClick", function()
        ADDON.ToggleSettings()
    end)
    window.automationButton = createSmallButton(window, "Automation", 92)
    setButtonTextColor(window.automationButton, 1, 0.48, 0.08)
    if window.automationButton:GetFontString() then
        window.automationButton:GetFontString():SetFont(STANDARD_TEXT_FONT, 10, "")
    end
    window.automationButton:SetScript("OnClick", function()
        ADDON.ShowAutomationDialog()
    end)

    window.controlScroll, window.controlContent = createScrollFrame("DudesLootTrackerControlScroll", window)
    window.lootScroll, window.lootContent = createScrollFrame("DudesLootTrackerLootScroll", window)
    local lootScrollBar = _G[window.lootScroll:GetName() .. "ScrollBar"]
    if lootScrollBar and lootScrollBar.HookScript then
        lootScrollBar:HookScript("OnValueChanged", requestLootViewportRefresh)
    end
    window.divider = window:CreateTexture(nil, "BORDER")
    window.divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    window.divider:SetVertexColor(BORDER_R * 0.62, BORDER_G * 0.62, BORDER_B * 0.62, 0.78)
    window.dividerLeftShadow = window:CreateTexture(nil, "BORDER")
    window.dividerLeftShadow:SetTexture("Interface\\Buttons\\WHITE8X8")
    window.dividerLeftShadow:SetVertexColor(0, 0, 0, 0.72)
    window.dividerLeftOuterShadow = window:CreateTexture(nil, "BORDER")
    window.dividerLeftOuterShadow:SetTexture("Interface\\Buttons\\WHITE8X8")
    window.dividerLeftOuterShadow:SetVertexColor(0, 0, 0, 0.32)
    window.dividerRightShadow = window:CreateTexture(nil, "BORDER")
    window.dividerRightShadow:SetTexture("Interface\\Buttons\\WHITE8X8")
    window.dividerRightShadow:SetVertexColor(0, 0, 0, 0.72)
    window.dividerRightOuterShadow = window:CreateTexture(nil, "BORDER")
    window.dividerRightOuterShadow:SetTexture("Interface\\Buttons\\WHITE8X8")
    window.dividerRightOuterShadow:SetVertexColor(0, 0, 0, 0.32)
    window.controlScroll:HookScript("OnMouseDown", clearFocusedNumberBox)
    window.controlContent:EnableMouse(true)
    window.controlContent:SetScript("OnMouseDown", clearFocusedNumberBox)
    window.lootScroll:HookScript("OnMouseDown", clearFocusedNumberBox)
    window.lootContent:EnableMouse(true)
    window.lootContent:SetScript("OnMouseDown", clearFocusedNumberBox)

    window.resizeGrip = CreateFrame("Button", nil, window)
    window.resizeGrip:SetWidth(16)
    window.resizeGrip:SetHeight(16)
    window.resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    window.resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    window.resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    window.resizeGrip:RegisterForDrag("LeftButton")
    window.resizeGrip:SetScript("OnDragStart", function()
        window:StartSizing("BOTTOMRIGHT")
    end)
    window.resizeGrip:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        savePlacement()
        layoutWindow(false)
    end)

    createControls()
    if WorldFrame and WorldFrame.HookScript then
        WorldFrame:HookScript("OnMouseDown", clearFocusedNumberBox)
    end
    loadPlacement()
    layoutWindow()
    window:Hide()
    return window
end

function ADDON.RefreshMainWindow()
    if window then
        layoutWindow()
    end
end

function ADDON.RequestRefreshMainWindow()
    if pendingRefreshMainWindow then
        return
    end
    pendingRefreshMainWindow = true
    local function refresh()
        pendingRefreshMainWindow = nil
        if ADDON.RefreshMainWindow then
            ADDON.RefreshMainWindow()
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, refresh)
    else
        refresh()
    end
end

function ADDON.ShowWindow()
    ADDON.CreateMainWindow()
    ADDON.RefreshMainWindow()
    window:Show()
end

function ADDON.RequestShowWindow()
    if pendingShowWindow then
        return
    end
    pendingShowWindow = true
    local function show()
        pendingShowWindow = nil
        if ADDON.ShowWindow then
            ADDON.ShowWindow()
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, show)
    else
        show()
    end
end

function ADDON.ToggleWindow()
    ADDON.CreateMainWindow()
    ADDON.RefreshMainWindow()
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
    end
end
