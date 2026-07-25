local ADDON = DudesLootTracker

local window
local lootRows = {}
local lootLayoutEntries = {}
local collapsedLootAreas = {}
local registeredSpecialFrame
local focusedNumberBox
local lootContentMinHeight = 1
local pendingShowWindow
local pendingRefreshMainWindow
local pendingResizeLayout
local pendingLootViewportRefresh
local requestLootViewportRefresh
local renderLootLayoutEntry
local getInstanceGroupKey
local getAreaType
local BORDER_R, BORDER_G, BORDER_B = 0.32, 0.38, 0.46
local HOVER_R, HOVER_G, HOVER_B = 0.72, 0.86, 1
local MIN_WIDTH, MIN_HEIGHT = 620, 340
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
local AREA_HEADER_HEIGHT = 28
local COLLAPSED_AREA_HEIGHT = 34
local ENEMY_ROW_HEIGHT = 26
local ITEM_ROW_HEIGHT = 34
local AREA_CONTENT_BOTTOM_PADDING = 8
local LOOT_AREA_CONTENT_X = 24
local LOOT_AREA_RIGHT_INSET = 12
local LOOT_AREA_META_RIGHT_INSET = 24
local LOOT_SEPARATOR_RIGHT_INSET = 16
local AUTO_GREED_LABEL_PREFIX = "|cff1eff00Ungewöhnlich|r"
local AUTO_GREED_LABEL_SUFFIX = " automatisch Gier/Entzaubern"
local AUTO_GREED_LABEL_FULL = AUTO_GREED_LABEL_PREFIX .. AUTO_GREED_LABEL_SUFFIX
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
    title:SetTextColor(1, 1, 1)
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
    row.count:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    row.count:SetTextColor(1, 1, 1)
    row.accent = row:CreateTexture(nil, "BACKGROUND")
    row.accent:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.separator = row:CreateTexture(nil, "ARTWORK")
    row.separator:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.separatorRight = row:CreateTexture(nil, "ARTWORK")
    row.separatorRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.badge = createText(row, 8, "CENTER")
    row.expandText = createText(row, 12, "CENTER")
    row.text = createText(row, 10)
    row.subtext = createText(row, 8)
    row.detail = createText(row, 9, "RIGHT")
    row.method = createText(row, 8, "RIGHT")
    row.enemyHitbox = CreateFrame("Frame", nil, row)
    row.enemyHitbox:EnableMouse(true)
    row.itemHitbox = CreateFrame("Frame", nil, row)
    row.itemHitbox:EnableMouse(true)
    row.detailHitbox = CreateFrame("Frame", nil, row)
    row.detailHitbox:EnableMouse(true)
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
    if row.text then
        row.text:SetText("")
        row.text:SetJustifyH("LEFT")
    end
    if row.subtext then
        row.subtext:SetText("")
        row.subtext:SetJustifyH("LEFT")
    end
    if row.detail then
        row.detail:SetText("")
        row.detail:SetJustifyH("RIGHT")
    end
    if row.method then
        row.method:SetText("")
        row.method:SetJustifyH("RIGHT")
    end
    if row.enemyHitbox then
        row.enemyHitbox:Hide()
        row.enemyHitbox:SetScript("OnEnter", nil)
        row.enemyHitbox:SetScript("OnLeave", nil)
    end
    if row.itemHitbox then
        row.itemHitbox:Hide()
        row.itemHitbox:SetScript("OnEnter", nil)
        row.itemHitbox:SetScript("OnLeave", nil)
        row.itemHitbox:SetScript("OnMouseUp", nil)
    end
    if row.detailHitbox then
        row.detailHitbox:Hide()
        row.detailHitbox:SetScript("OnEnter", nil)
        row.detailHitbox:SetScript("OnLeave", nil)
    end
    if row.accent then
        row.accent:Hide()
    end
    if row.separator then
        row.separator:Hide()
    end
    if row.separatorRight then
        row.separatorRight:Hide()
    end
    if row.badge then
        row.badge:Hide()
    end
    if row.expandText then
        row.expandText:Hide()
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
    filters.areas = filters.areas or { raid = true, instance = true, world = true }

    local isEmblem = ADDON.IsEmblem and ADDON.IsEmblem(item)
    if isEmblem then
        if not filters.emblems then
            return false
        end
        local player = ADDON.GetPlayerName()
        local receivedByPlayer
        for _, recipient in ipairs(item.recipients or {}) do
            if recipient.name == player or string.match(recipient.name or "", "^([^%-]+)") == player then
                receivedByPlayer = true
                break
            end
        end
        if not receivedByPlayer then
            return false
        end
    end

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
    if not filters.areas[getAreaType(segment)] then
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
        table.insert(parts, recipient.name or "?")
    end
    return table.concat(parts, ", ")
end

local function formatLootTimestamp(timestamp)
    if timestamp and date then
        return date("%d.%m. %H:%M", timestamp)
    end
    return ""
end

local function formatSegmentLootTimestamp(timestamp)
    if timestamp and date then
        return date("%d.%m.%Y %H:%M", timestamp)
    end
    return "Zeitpunkt unbekannt"
end

local function formatLootMethod(method)
    local labels = {
        trade = "Handel",
        master = "Zugewiesen",
        greed = "Gier",
        need = "Bedarf",
        disenchant = "Entzaubern",
        loot = "Geplündert",
        manual = "Manuell",
    }
    return labels[method] or method or ""
end

local function formatOwnership(item)
    if item and item.blizzardRollStarted and #(item.recipients or {}) == 0 then
        return "wird verwürfelt"
    end
    local recipients = formatRecipients(item)
    if recipients ~= "" then
        return recipients
    end
    return "Unvergeben"
end

local function formatLootMethodDetail(item)
    if item and item.blizzardRollStarted and #(item.recipients or {}) == 0 then
        return ""
    end
    local parts = {}
    for _, recipient in ipairs(item.recipients or {}) do
        local method = formatLootMethod(recipient.method)
        if method ~= "" then
            table.insert(parts, method)
        end
    end
    return table.concat(parts, ", ")
end

local function formatLootTimestampDetail(item)
    local parts = {}
    for _, recipient in ipairs(item.recipients or {}) do
        local timestamp = formatLootTimestamp(recipient.timestamp)
        if timestamp ~= "" then
            local method = formatLootMethod(recipient.method)
            if method ~= "" then
                table.insert(parts, method .. " " .. timestamp)
            else
                table.insert(parts, timestamp)
            end
        end
    end
    return table.concat(parts, "\n")
end

local function isDisenchantRoll(item)
    if not item then
        return false
    end
    if item.rollMethod == "disenchant" then
        return true
    end
    for _, recipient in ipairs(item.recipients or {}) do
        if recipient.method == "disenchant" then
            return true
        end
    end
    return false
end

local function formatDisenchantRewardDetails(item)
    if not item or not item.disenchantRewards or #item.disenchantRewards == 0 then
        return {}
    end
    local rewards = {}
    local order = {}
    for _, rewardEntry in ipairs(item.disenchantRewards) do
        local rewardLink = type(rewardEntry) == "table" and rewardEntry.link or rewardEntry
        local rewardCount = type(rewardEntry) == "table" and (tonumber(rewardEntry.count) or 1) or 1
        local itemId = (type(rewardEntry) == "table" and rewardEntry.itemId) or ADDON.GetItemId(rewardLink) or tostring(rewardLink or "")
        local reward = rewards[itemId]
        if not reward then
            reward = {
                link = rewardLink,
                count = 0,
            }
            rewards[itemId] = reward
            table.insert(order, itemId)
        end
        reward.count = reward.count + rewardCount
    end
    local lines = {}
    for _, itemId in ipairs(order) do
        local reward = rewards[itemId]
        local countText = reward.count > 1 and (" x" .. tostring(reward.count)) or ""
        table.insert(lines, tostring(reward.link or "?") .. countText)
    end
    return lines
end

local function normalizeEquipmentType(subType, slot)
    local value = subType or ""
    local lower = string.lower(value)
    local normalizedTypes = {
        ["zweihandschwerter"] = "Zweihandschwert",
        ["two-handed swords"] = "Zweihandschwert",
        ["einhandschwerter"] = "Schwert",
        ["one-handed swords"] = "Schwert",
        ["schwerter"] = "Schwert",
        ["swords"] = "Schwert",
        ["zweihandäxte"] = "Zweihandaxt",
        ["two-handed axes"] = "Zweihandaxt",
        ["einhändige äxte"] = "Axt",
        ["one-handed axes"] = "Axt",
        ["äxte"] = "Axt",
        ["axes"] = "Axt",
        ["zweihandstreitkolben"] = "Zweihandstreitkolben",
        ["two-handed maces"] = "Zweihandstreitkolben",
        ["einhändige streitkolben"] = "Streitkolben",
        ["one-handed maces"] = "Streitkolben",
        ["streitkolben"] = "Streitkolben",
        ["maces"] = "Streitkolben",
        ["dolche"] = "Dolch",
        ["daggers"] = "Dolch",
        ["stäbe"] = "Stab",
        ["staves"] = "Stab",
        ["stangenwaffen"] = "Stangenwaffe",
        ["polearms"] = "Stangenwaffe",
        ["schusswaffen"] = "Schusswaffe",
        ["guns"] = "Schusswaffe",
        ["bögen"] = "Bogen",
        ["bows"] = "Bogen",
        ["armbrüste"] = "Armbrust",
        ["crossbows"] = "Armbrust",
        ["wurfwaffen"] = "Wurfwaffe",
        ["thrown"] = "Wurfwaffe",
        ["faustwaffen"] = "Faustwaffe",
        ["fist weapons"] = "Faustwaffe",
        ["schilde"] = "Schild",
        ["shields"] = "Schild",
        ["stoff"] = "Stoff",
        ["cloth"] = "Stoff",
        ["leder"] = "Leder",
        ["leather"] = "Leder",
        ["schwere rüstung"] = "Schwere Rüstung",
        ["mail"] = "Schwere Rüstung",
        ["platte"] = "Platte",
        ["plate"] = "Platte",
    }
    if normalizedTypes[lower] then
        return normalizedTypes[lower]
    end
    if value ~= "" then
        return value
    end
    return slot or ""
end

local ARMOR_TYPES = {
    ["stoff"] = true,
    ["cloth"] = true,
    ["leder"] = true,
    ["leather"] = true,
    ["schwere rüstung"] = true,
    ["mail"] = true,
    ["platte"] = true,
    ["plate"] = true,
}

local function formatItemInfo(item)
    if ADDON.IsEmblem and ADDON.IsEmblem(item) then
        return ""
    end
    local parts = {}
    local slot = item.slot or ""
    local subType = item.itemSubType or ""
    local lowerSubType = string.lower(subType)
    local isGenericSubType = lowerSubType == "verschiedenes" or lowerSubType == "miscellaneous" or lowerSubType == "misc"
    if item.isEquipment then
        local equipmentType = not isGenericSubType and normalizeEquipmentType(subType, slot) or slot
        if not isGenericSubType and ARMOR_TYPES[lowerSubType] and slot ~= "" and slot ~= equipmentType then
            equipmentType = equipmentType .. " " .. slot
        end
        if equipmentType ~= "" then
            table.insert(parts, equipmentType)
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

local function measureMultilineTextWidth(fontString, text)
    if not fontString or not fontString.GetStringWidth or not fontString.SetText then
        return 0
    end
    local maxWidth = 0
    text = tostring(text or "")
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        fontString:SetText(line)
        local width = fontString:GetStringWidth() or 0
        if width > maxWidth then
            maxWidth = width
        end
    end
    fontString:SetText(text)
    return maxWidth
end

getAreaType = function(segment)
    local size = tonumber(segment and segment.raidSize or 0) or 0
    if size > 5 then
        return "raid"
    elseif size == 5 then
        return "instance"
    end
    return "world"
end

local function getAreaAccent(areaType)
    if areaType == "raid" then
        return 0.48, 0.26, 0.76
    elseif areaType == "instance" then
        return 0.20, 0.46, 0.78
    end
    return 0.38, 0.42, 0.48
end

local function getAreaTitle(segment)
    if not segment or not segment.raid or segment.raid == "" or segment.raid == "World" then
        return "Au\195\159erhalb"
    end
    return tostring(segment.raid)
end

local function getInstanceIdText(segment)
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
    return tostring(raidId)
end

local function formatAreaSize(segment)
    local size = tonumber(segment and segment.raidSize or 0) or 0
    if size > 0 and segment and segment.instanceType ~= "none" then
        return tostring(size)
    end
    return ""
end

local function getAreaStableKey(segment)
    local key = getInstanceGroupKey(segment)
    return tostring(key or "outside")
end

local function getEnemyStableKey(segment)
    return getAreaStableKey(segment) .. ":" .. tostring(segment and segment.id or segment and segment.sourceName or "")
end

local function isAreaExpanded(area)
    local value = collapsedLootAreas[area.key]
    if value == nil then
        return true
    end
    return not value
end

local function setAllLootExpanded(expanded)
    for _, entry in ipairs(lootLayoutEntries or {}) do
        if entry.kind == "area" and entry.area then
            collapsedLootAreas[entry.area.key] = not expanded
        end
    end
    ADDON.RefreshMainWindow()
end

local function toggleAllLootExpanded()
    local anyExpanded
    for _, entry in ipairs(lootLayoutEntries or {}) do
        if entry.kind == "area" and entry.area and isAreaExpanded(entry.area) then
            anyExpanded = true
            break
        end
    end
    setAllLootExpanded(not anyExpanded)
end

local function setupItemTooltip(frame, item)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        if item.link then
            GameTooltip:SetHyperlink(item.link)
        else
            GameTooltip:AddLine(item.name or "Item")
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function setupLootTimestampTooltip(frame, item)
    local timestampText = formatLootTimestampDetail(item)
    local rewardLines = isDisenchantRoll(item) and formatDisenchantRewardDetails(item) or {}
    if timestampText == "" and #rewardLines == 0 then
        return
    end
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        for line in string.gmatch(timestampText .. "\n", "([^\n]*)\n") do
            if line ~= "" then
                GameTooltip:AddLine(line, 0.78, 0.82, 0.88)
            end
        end
        if #rewardLines > 0 then
            if timestampText ~= "" then
                GameTooltip:AddLine(" ")
            end
            GameTooltip:AddLine("Entzauber-Ergebnis:", 1, 1, 1)
            for _, rewardLine in ipairs(rewardLines) do
                GameTooltip:AddLine(rewardLine, 0.78, 0.82, 0.88)
            end
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
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

getInstanceGroupKey = function(segment)
    if not segment or not segment.raid or segment.raid == "" or segment.raid == "World" then
        return "outside"
    end
    local raidId = segment.raidId
    if not raidId and segment.raidKey then
        raidId = string.match(segment.raidKey, ":([^:]+)$")
    end
    return table.concat({
        tostring(segment.raid),
        tostring(segment.raidSize or ""),
        tostring(segment.difficultyIndex or segment.difficultyName or (segment.heroic and "heroic" or "normal")),
        tostring(raidId or "unsaved"),
    }, ":")
end

local function addAreaHeader(index, area, y)
    local height = area.layoutHeight or AREA_HEADER_HEIGHT
    if not isLootRowInViewport(y, height) then
        return y - height, index
    end
    local row = acquireLootRow(index)
    resetLootRow(row)
    row:SetPoint("TOPLEFT", window.lootContent, "TOPLEFT", 4, y)
    row:SetPoint("RIGHT", window.lootContent, "RIGHT", -4, 0)
    row:SetHeight(height)
    row:SetFrameLevel((window.lootContent:GetFrameLevel() or 0) + 1)
    local r, g, b = getAreaAccent(area.areaType)
    setBackdrop(row, 0.032 + r * 0.05, 0.038 + g * 0.05, 0.052 + b * 0.05, 0.98)
    row:SetBackdropBorderColor(r, g, b, 0.95)
    row.subtext:ClearAllPoints()
    row.subtext:SetPoint("TOPRIGHT", row, "TOPRIGHT", -LOOT_AREA_META_RIGHT_INSET, isAreaExpanded(area) and -10 or -8)
    row.subtext:SetHeight(18)
    row.subtext:SetFont(STANDARD_TEXT_FONT, 9, "")
    row.subtext:SetTextColor(0.78, 0.82, 0.88)
    row.subtext:SetJustifyH("RIGHT")
    if row.subtext.SetWordWrap then
        row.subtext:SetWordWrap(false)
    end
    if row.subtext.SetNonSpaceWrap then
        row.subtext:SetNonSpaceWrap(false)
    end
    local meta = area.sizeText or ""
    if meta ~= "" and area.instanceId and area.instanceId ~= "" then
        meta = meta .. " Spieler (ID: " .. area.instanceId .. ")"
    elseif meta ~= "" then
        meta = meta .. " Spieler"
    else
        meta = ""
    end
    row.subtext:SetText(meta)
    local metaWidth = 0
    if meta ~= "" then
        metaWidth = math.min(220, math.max(54, measureMultilineTextWidth(row.subtext, meta) + 8))
    end
    row.subtext:SetWidth(metaWidth)
    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", LOOT_AREA_CONTENT_X, isAreaExpanded(area) and -10 or -8)
    if meta ~= "" then
        row.text:SetPoint("RIGHT", row.subtext, "LEFT", -12, 0)
    else
        row.text:SetPoint("RIGHT", row, "RIGHT", -LOOT_AREA_RIGHT_INSET, 0)
    end
    row.text:SetHeight(18)
    row.text:SetFont(STANDARD_TEXT_FONT, 12, "")
    if row.text.SetWordWrap then
        row.text:SetWordWrap(false)
    end
    if row.text.SetNonSpaceWrap then
        row.text:SetNonSpaceWrap(false)
    end
    row.text:SetText("|cffffffff" .. tostring(area.title or "?") .. "|r")
    row:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            collapsedLootAreas[area.key] = isAreaExpanded(area)
            ADDON.RefreshMainWindow()
        end
    end)
    rememberLootRow(row, y, height)
    return y - height, index + 1
end

local function addEnemyRow(index, enemy, y)
    local height = enemy.layoutHeight or ENEMY_ROW_HEIGHT
    if not isLootRowInViewport(y, height) then
        return y - height, index
    end
    local row = acquireLootRow(index)
    resetLootRow(row)
    row:SetPoint("TOPLEFT", window.lootContent, "TOPLEFT", 4, y)
    row:SetPoint("RIGHT", window.lootContent, "RIGHT", -12, 0)
    row:SetHeight(height)
    row:SetFrameLevel((window.lootContent:GetFrameLevel() or 0) + 2)
    setBackdrop(row, 0.035, 0.041, 0.052, 0)
    row:SetBackdropBorderColor(0.18, 0.21, 0.28, 0)
    row.text:ClearAllPoints()
    row.text:SetPoint("TOP", row, "TOP", 0, -4)
    row.text:SetHeight(18)
    row.text:SetFont(STANDARD_TEXT_FONT, 10, "")
    row.text:SetJustifyH("CENTER")
    row.text:SetText("|cffffffff" .. tostring(enemy.title or "?") .. "|r")
    local textWidth = row.text.GetStringWidth and (row.text:GetStringWidth() or 0) or 120
    local labelWidth = math.max(90, textWidth + 14)
    row.text:SetWidth(labelWidth)
    if row.enemyHitbox then
        local enemyTitle = tostring(enemy.title or "Gegner")
        local timestampText = formatSegmentLootTimestamp(enemy.segment and enemy.segment.timestamp)
        row.enemyHitbox:ClearAllPoints()
        row.enemyHitbox:SetPoint("TOPLEFT", row.text, "TOPLEFT", -4, 2)
        row.enemyHitbox:SetPoint("BOTTOMRIGHT", row.text, "BOTTOMRIGHT", 4, -2)
        row.enemyHitbox:SetFrameLevel(row:GetFrameLevel() + 1)
        row.enemyHitbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:AddLine(enemyTitle, 1, 1, 1)
            GameTooltip:AddLine("Gelootet: " .. timestampText, 0.78, 0.82, 0.88)
            GameTooltip:Show()
        end)
        row.enemyHitbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row.enemyHitbox:Show()
    end
    if row.separator and row.separatorRight then
        local r, g, b = getAreaAccent(enemy.areaType)
        local rowWidth = row:GetWidth() or 600
        local labelHalfWidth = labelWidth / 2
        local centerX = rowWidth / 2
        local leftEndX = centerX - labelHalfWidth - 6
        local rightStartX = centerX + labelHalfWidth + 6
        local lineY = -13
        row.separator:Show()
        row.separator:ClearAllPoints()
        row.separator:SetPoint("TOPLEFT", row, "TOPLEFT", LOOT_AREA_CONTENT_X, lineY)
        row.separator:SetPoint("TOPRIGHT", row, "TOPLEFT", leftEndX, lineY)
        row.separator:SetHeight(1)
        row.separator:SetVertexColor(r, g, b, 0.85)
        row.separatorRight:Show()
        row.separatorRight:ClearAllPoints()
        row.separatorRight:SetPoint("TOPLEFT", row, "TOPLEFT", rightStartX, lineY)
        row.separatorRight:SetPoint("TOPRIGHT", row, "TOPRIGHT", -LOOT_SEPARATOR_RIGHT_INSET, lineY)
        row.separatorRight:SetHeight(1)
        row.separatorRight:SetVertexColor(r, g, b, 0.85)
    end
    rememberLootRow(row, y, height)
    return y - height, index + 1
end

local function addItemRow(index, item, y)
    if not isLootRowInViewport(y, ITEM_ROW_HEIGHT) then
        return y - ITEM_ROW_HEIGHT, index
    end
    local row = acquireLootRow(index)
    resetLootRow(row)
    row:SetPoint("TOPLEFT", window.lootContent, "TOPLEFT", 4, y)
    row:SetPoint("RIGHT", window.lootContent, "RIGHT", -16, 0)
    row:SetHeight(ITEM_ROW_HEIGHT)
    row:SetFrameLevel((window.lootContent:GetFrameLevel() or 0) + 3)
    row.icon:Show()
    row.icon:SetWidth(30)
    row.icon:SetHeight(30)
    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", row, "LEFT", LOOT_AREA_CONTENT_X, 0)
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
    setBackdrop(row, 0.044, 0.052, 0.066, 0)
    row:SetBackdropBorderColor(0.18, 0.21, 0.28, 0)
    row.detail:ClearAllPoints()
    row.detail:SetPoint("TOPRIGHT", row, "TOPRIGHT", -LOOT_AREA_RIGHT_INSET, -2)
    row.detail:SetHeight(14)
    row.detail:SetFont(STANDARD_TEXT_FONT, 9, "")
    row.detail:SetJustifyH("RIGHT")
    row.detail:SetTextColor(0.88, 0.91, 0.96)
    if row.detail.SetWordWrap then
        row.detail:SetWordWrap(false)
    end
    if row.detail.SetNonSpaceWrap then
        row.detail:SetNonSpaceWrap(false)
    end
    local ownerText = formatOwnership(item)
    local methodText = formatLootMethodDetail(item)
    row.detail:SetText(ownerText)
    row.method:ClearAllPoints()
    row.method:SetPoint("TOPRIGHT", row.detail, "BOTTOMRIGHT", 0, -1)
    row.method:SetHeight(13)
    row.method:SetFont(STANDARD_TEXT_FONT, 8, "")
    row.method:SetJustifyH("RIGHT")
    row.method:SetTextColor(0.65, 0.71, 0.80)
    row.method:SetText(methodText)
    local measuredDetailWidth = math.max(
        measureMultilineTextWidth(row.detail, ownerText),
        measureMultilineTextWidth(row.method, methodText)
    )
    local maxDetailWidth = math.max(90, math.min(180, math.floor((row:GetWidth() or 520) * 0.42)))
    local detailWidth = math.min(maxDetailWidth, math.max(70, measuredDetailWidth + 12))
    row.detail:SetWidth(detailWidth)
    row.method:SetWidth(detailWidth)
    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
    row.text:SetPoint("RIGHT", row.detail, "LEFT", -12, 0)
    row.text:SetHeight(14)
    row.text:SetFont(STANDARD_TEXT_FONT, 11, "")
    row.text:SetJustifyH("LEFT")
    row.subtext:ClearAllPoints()
    row.subtext:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -1)
    row.subtext:SetPoint("RIGHT", row.text, "RIGHT", 0, 0)
    row.subtext:SetHeight(13)
    row.subtext:SetFont(STANDARD_TEXT_FONT, 9, "")
    row.subtext:SetJustifyH("LEFT")
    row.subtext:SetTextColor(0.78, 0.82, 0.88)
    row.text:SetText("|cff" .. ADDON.GetQualityColor(item.quality) .. tostring(item.name or "?") .. "|r")
    row.subtext:SetText(formatItemInfo(item))
    if row.itemHitbox then
        row.itemHitbox:Show()
        row.itemHitbox:SetFrameLevel(row:GetFrameLevel() + 2)
        row.itemHitbox:ClearAllPoints()
        row.itemHitbox:SetPoint("TOPLEFT", row, "TOPLEFT", LOOT_AREA_CONTENT_X, 0)
        row.itemHitbox:SetPoint("BOTTOMRIGHT", row.text, "BOTTOMRIGHT", 0, -14)
        setupItemTooltip(row.itemHitbox, item)
    end
    if row.detailHitbox then
        row.detailHitbox:Show()
        row.detailHitbox:SetFrameLevel(row:GetFrameLevel() + 2)
        row.detailHitbox:ClearAllPoints()
        row.detailHitbox:SetPoint("TOPLEFT", row.detail, "TOPLEFT", 0, 0)
        row.detailHitbox:SetPoint("BOTTOMRIGHT", row.method, "BOTTOMRIGHT", 0, 0)
        setupLootTimestampTooltip(row.detailHitbox, item)
    end
    rememberLootRow(row, y, ITEM_ROW_HEIGHT)
    return y - ITEM_ROW_HEIGHT, index + 1
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
    row:SetFrameLevel((window.lootContent:GetFrameLevel() or 0) + 3)
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

function renderLootLayoutEntry(index, entry)
    if entry.kind == "area" then
        addAreaHeader(index, entry.area, entry.y)
    elseif entry.kind == "enemy" then
        addEnemyRow(index, entry.enemy, entry.y)
    elseif entry.kind == "item" then
        addItemRow(index, entry.item, entry.y)
    elseif entry.kind == "detail" then
        addDetailRow(index, entry.y, entry.text, entry.detail)
    end
end

local function buildLootAreas(segments, maxVisibleItems)
    local areas = {}
    local areaOrder = {}
    local visibleItemCount = 0

    for i = #(segments or {}), 1, -1 do
        if maxVisibleItems > 0 and visibleItemCount >= maxVisibleItems then
            break
        end
        local segment = segments[i]
        local visibleItems = {}
        for _, item in ipairs(segment.items or {}) do
            if maxVisibleItems > 0 and visibleItemCount >= maxVisibleItems then
                break
            end
            if not item.infoReady then
                ADDON.RefreshItemInfo(item)
            end
            if rowPassesFilters(item, segment) then
                table.insert(visibleItems, item)
                visibleItemCount = visibleItemCount + 1
            end
        end

        if #visibleItems > 0 then
            local areaKey = getAreaStableKey(segment)
            local area = areas[areaKey]
            if not area then
                local areaType = getAreaType(segment)
                area = {
                    key = areaKey,
                    title = getAreaTitle(segment),
                    areaType = areaType,
                    instanceId = getInstanceIdText(segment),
                    sizeText = formatAreaSize(segment),
                    enemies = {},
                }
                areas[areaKey] = area
                table.insert(areaOrder, area)
            end

            local title = tostring(segment.sourceName or "")
            if title == "" then
                title = "Unbekannt"
            end
            local enemy = {
                key = getEnemyStableKey(segment),
                title = title,
                segment = segment,
                areaType = area.areaType,
                items = visibleItems,
            }
            table.insert(area.enemies, enemy)
        end
    end

    return areaOrder
end

local function refreshLootContent()
    if not window then
        return
    end
    clearRows(lootRows)
    lootLayoutEntries = {}
    local y = -4
    local segments = ADDON.GetCharacterDB().segments or {}
    local settings = ADDON.GetSettings()
    local maxVisibleItems = tonumber(settings.maxLootEntries or 0) or 0
    local areas = buildLootAreas(segments, maxVisibleItems)

    for _, area in ipairs(areas) do
        local areaHeight = AREA_HEADER_HEIGHT
        if isAreaExpanded(area) then
            for _, enemy in ipairs(area.enemies or {}) do
                local enemyHeight = ENEMY_ROW_HEIGHT + (#(enemy.items or {}) * ITEM_ROW_HEIGHT)
                enemy.layoutHeight = enemyHeight
                areaHeight = areaHeight + enemyHeight
            end
            areaHeight = areaHeight + AREA_CONTENT_BOTTOM_PADDING
        else
            areaHeight = COLLAPSED_AREA_HEIGHT
        end
        area.layoutHeight = areaHeight
        appendLootLayoutEntry("area", y, areaHeight, { area = area })
        y = y - (isAreaExpanded(area) and AREA_HEADER_HEIGHT or COLLAPSED_AREA_HEIGHT)
        if isAreaExpanded(area) then
            for _, enemy in ipairs(area.enemies or {}) do
                appendLootLayoutEntry("enemy", y, enemy.layoutHeight or ENEMY_ROW_HEIGHT, { enemy = enemy })
                y = y - ENEMY_ROW_HEIGHT
                for _, item in ipairs(enemy.items or {}) do
                    appendLootLayoutEntry("item", y, ITEM_ROW_HEIGHT, { item = item })
                    y = y - ITEM_ROW_HEIGHT
                end
            end
            y = y - AREA_CONTENT_BOTTOM_PADDING
        end
        y = y - CARD_GAP
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
    filters.emblems = false
    filters.minItemLevel = nil
    filters.maxItemLevel = nil
    filters.minRequiredLevel = nil
    filters.maxRequiredLevel = nil
    filters.qualities = { legendary = true, epic = true, rare = true, uncommon = true, common = true, poor = true }
    filters.areas = { raid = true, instance = true, world = true }
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

local function setAllAreas(value)
    local filters = ADDON.GetFilters()
    filters.areas = filters.areas or { raid = true, instance = true, world = true }
    local areas = filters.areas
    areas.raid = value
    areas.instance = value
    areas.world = value
end

local function refreshControls()
    if not window or not window.controls then
        return
    end
    local filters = ADDON.GetFilters()
    local contentWidth = window.controlContent:GetWidth() or (LEFT_WIDTH - 2)
    if window.filterFrame then
        window.filterFrame:SetWidth(contentWidth)
        window.filterFrame:ClearAllPoints()
        window.filterFrame:SetPoint("TOPLEFT", window.controlContent, "TOPLEFT", 0, 0)
    end
    local contentHeight = window.filterFrameHeight or 1
    window.controlContent:SetHeight(math.max(1, contentHeight))

    window.controls.ownOnly:SetChecked(filters.ownOnly and true or false)
    window.controls.boeOnly:SetChecked(filters.boeOnly and true or false)
    window.controls.emblems:SetChecked(filters.emblems and true or false)
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
    window.autoGreedDisenchant:SetChecked(ADDON.GetSettings().autoGreedDisenchantUncommon and true or false)
    filters.areas = filters.areas or { raid = true, instance = true, world = true }
    window.controls.raid:SetChecked(filters.areas.raid)
    window.controls.instance:SetChecked(filters.areas.instance)
    window.controls.world:SetChecked(filters.areas.world)
end

local function updateAutoGreedLabel()
    if not window or not window.autoGreedDisenchant or not window.autoGreedDisenchant.text then
        return
    end
    local label = window.autoGreedDisenchant.text
    local availableWidth = label:GetWidth() or 0
    if availableWidth <= 0 then
        return
    end

    label:SetText(AUTO_GREED_LABEL_FULL)
    if (label:GetStringWidth() or 0) <= availableWidth then
        return
    end

    for length = #AUTO_GREED_LABEL_SUFFIX, 0, -1 do
        local suffix = string.sub(AUTO_GREED_LABEL_SUFFIX, 1, length)
        suffix = string.gsub(suffix, "%s+$", "")
        label:SetText(AUTO_GREED_LABEL_PREFIX .. suffix .. "...")
        if (label:GetStringWidth() or 0) <= availableWidth then
            return
        end
    end
    label:SetText(AUTO_GREED_LABEL_PREFIX .. "...")
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
    window.lootTitleButton = CreateFrame("Button", nil, window)
    window.lootTitleButton:SetScript("OnClick", toggleAllLootExpanded)
    window.lootTitleButton:HookScript("OnMouseDown", clearFocusedNumberBox)
    window.autoGreedDisenchant = createCheckbox(window, AUTO_GREED_LABEL_FULL)
    window.autoGreedDisenchant.text:SetFont(STANDARD_TEXT_FONT, 10, "")
    window.autoGreedDisenchant.text:SetPoint("LEFT", window.autoGreedDisenchant, "RIGHT", 2, 0)
    window.autoGreedDisenchant.text:SetHeight(22)
    if window.autoGreedDisenchant.text.SetWordWrap then
        window.autoGreedDisenchant.text:SetWordWrap(false)
    end
    window.autoGreedDisenchant:SetScript("OnClick", function(self)
        ADDON.GetSettings().autoGreedDisenchantUncommon = self:GetChecked() and true or false
    end)
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

    local emblems = createCheckbox(filterFrame, "Embleme")
    window.controls.emblems = emblems
    emblems:SetScript("OnClick", function(self)
        ADDON.GetFilters().emblems = self:GetChecked() and true or false
        ADDON.RefreshMainWindow()
    end)
    y, emblems.dltCard = addControl(filterFrame, emblems, y, nil, true)

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

    local areaMap = {
        { key = "raid", label = "Raid", color = "b88cff" },
        { key = "instance", label = "Instanz", color = "58a6ff" },
        { key = "world", label = "Welt", color = "9aa3b0" },
    }
    local areaEntries = {}
    for _, entry in ipairs(areaMap) do
        local cb = createCheckbox(filterFrame, entry.label)
        setTextColorHex(cb.text, entry.color)
        window.controls[entry.key] = cb
        cb:SetScript("OnClick", function(self)
            local filters = ADDON.GetFilters()
            filters.areas = filters.areas or { raid = true, instance = true, world = true }
            local areas = filters.areas
            areas[entry.key] = self:GetChecked() and true or false
            ADDON.RefreshMainWindow()
        end)
        table.insert(areaEntries, { checkbox = cb })
    end
    y = createGroupCard(filterFrame, y, "Gebiet", function()
        local filters = ADDON.GetFilters()
        filters.areas = filters.areas or { raid = true, instance = true, world = true }
        local areas = filters.areas
        local allChecked = areas.raid and areas.instance and areas.world
        setAllAreas(not allChecked)
        ADDON.RefreshMainWindow()
    end, areaEntries)
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
        if window.lootTitleButton then
            window.lootTitleButton:ClearAllPoints()
            window.lootTitleButton:SetPoint("TOPLEFT", window.lootTitle, "TOPLEFT", -4, 2)
            window.lootTitleButton:SetWidth(54)
            window.lootTitleButton:SetHeight(22)
        end
        if window.autoGreedDisenchant then
            window.autoGreedDisenchant:ClearAllPoints()
            window.autoGreedDisenchant:SetPoint("LEFT", window.lootTitle, "RIGHT", 6, 0)
            window.autoGreedDisenchant.text:ClearAllPoints()
            window.autoGreedDisenchant.text:SetPoint("LEFT", window.autoGreedDisenchant, "RIGHT", 2, 0)
            window.autoGreedDisenchant.text:SetPoint("RIGHT", window.settings, "LEFT", -8, 0)
            window.autoGreedDisenchant:Show()
            window.autoGreedDisenchant.text:Show()
            updateAutoGreedLabel()
        end

    end

    window.close:ClearAllPoints()
    window.close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -12, -10)
    window.settings:ClearAllPoints()
    window.settings:SetPoint("RIGHT", window.close, "LEFT", -6, 0)

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

function ADDON.ApplySettingsProfile()
    if window then
        loadPlacement()
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
