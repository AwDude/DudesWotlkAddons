local ADDON = DudesFlexBindings

local overlay
local keyButtons = {}
local resizeGrip
local registeredSpecialFrame

local DEFAULT_WIDTH = 1120
local DEFAULT_HEIGHT = 430
local MIN_WIDTH = 1120
local MIN_HEIGHT = 520

local OUTER_PADDING = 28
local PANEL_PADDING = 10
local SECTION_GAP = 10
local KEY_GAP = 8
local KEY_CONTENT_PADDING = 8
local ICON_LABEL_PADDING = 2
local ICON_LABEL_MAX_LINES = 2
local INTERFACE_ACTION_MAX_FONT_SIZE = 10
local KEYBOARD_COLS = 13
local MOUSE_COLS = 2
local LAYOUT_ROWS = 5
local BORDER_R, BORDER_G, BORDER_B = 0.32, 0.38, 0.46
local HOVER_BORDER_R, HOVER_BORDER_G, HOVER_BORDER_B = 0.72, 0.86, 1
local addBorderHover
local MODIFIER_COLORS = {
    normal = "ffffff",
    shift = "b8ffb8",
    ctrl = "a8dcff",
    alt = "ffc4ff",
}
local keyLabels = {
    ESCAPE = "Esc",
    TAB = "Tab",
    MOUSEWHEELUP = "Wheel Up",
    MOUSEWHEELDOWN = "Wheel Dn",
    BUTTON3 = "Wheel Click",
    BUTTON4 = "Back",
    BUTTON5 = "Forward",
    CAPSLOCK = "Caps",
    PRINTSCREEN = "Druck",
}

local keyDefs = {
    { "ESCAPE", "Esc", "keyboard", 0, 0 },
    { "F1", nil, "keyboard", 1, 0 }, { "F2", nil, "keyboard", 2, 0 }, { "F3", nil, "keyboard", 3, 0 }, { "F4", nil, "keyboard", 4, 0 },
    { "F5", nil, "keyboard", 5, 0 }, { "F6", nil, "keyboard", 6, 0 }, { "F7", nil, "keyboard", 7, 0 }, { "F8", nil, "keyboard", 8, 0 },
    { "F9", nil, "keyboard", 9, 0 }, { "F10", nil, "keyboard", 10, 0 }, { "F11", nil, "keyboard", 11, 0 }, { "F12", nil, "keyboard", 12, 0 },

    { "^", nil, "keyboard", 0, 1 }, { "1", nil, "keyboard", 1, 1 }, { "2", nil, "keyboard", 2, 1 }, { "3", nil, "keyboard", 3, 1 }, { "4", nil, "keyboard", 4, 1 }, { "5", nil, "keyboard", 5, 1 }, { "6", nil, "keyboard", 6, 1 }, { "7", nil, "keyboard", 7, 1 }, { "8", nil, "keyboard", 8, 1 }, { "9", nil, "keyboard", 9, 1 }, { "0", nil, "keyboard", 10, 1 }, { "ß", nil, "keyboard", 11, 1 }, { "´", nil, "keyboard", 12, 1 },
    { "TAB", "Tab", "keyboard", 0, 2 }, { "Q", nil, "keyboard", 1, 2 }, { "W", nil, "keyboard", 2, 2 }, { "E", nil, "keyboard", 3, 2 }, { "R", nil, "keyboard", 4, 2 }, { "T", nil, "keyboard", 5, 2 }, { "Z", nil, "keyboard", 6, 2 }, { "U", nil, "keyboard", 7, 2 }, { "I", nil, "keyboard", 8, 2 }, { "O", nil, "keyboard", 9, 2 }, { "P", nil, "keyboard", 10, 2 }, { "Ü", nil, "keyboard", 11, 2 }, { "+", nil, "keyboard", 12, 2 },
    { "A", nil, "keyboard", 1, 3 }, { "S", nil, "keyboard", 2, 3 }, { "D", nil, "keyboard", 3, 3 }, { "F", nil, "keyboard", 4, 3 }, { "G", nil, "keyboard", 5, 3 }, { "H", nil, "keyboard", 6, 3 }, { "J", nil, "keyboard", 7, 3 }, { "K", nil, "keyboard", 8, 3 }, { "L", nil, "keyboard", 9, 3 }, { "Ö", nil, "keyboard", 10, 3 }, { "Ä", nil, "keyboard", 11, 3 }, { "#", nil, "keyboard", 12, 3 },
    { "<", nil, "keyboard", 0, 4 }, { "Y", nil, "keyboard", 1, 4 }, { "X", nil, "keyboard", 2, 4 }, { "C", nil, "keyboard", 3, 4 }, { "V", nil, "keyboard", 4, 4 }, { "B", nil, "keyboard", 5, 4 }, { "N", nil, "keyboard", 6, 4 }, { "M", nil, "keyboard", 7, 4 }, { ",", nil, "keyboard", 8, 4 }, { ".", nil, "keyboard", 9, 4 }, { "-", nil, "keyboard", 10, 4 },

    { "CAPSLOCK", "Caps", "keyboard", 0, 3 },
    { "SPACE", "Space", "keyboard", 11, 4 },
    { "PRINTSCREEN", "Druck", "keyboard", 12, 4 },

    { "BUTTON5", "Forward", "mouse", 0, 1.5 },
    { "BUTTON4", "Back", "mouse", 0, 2.5 },
    { "MOUSEWHEELUP", "Wheel Up", "mouse", 1, 1 },
    { "BUTTON3", "Wheel Click", "mouse", 1, 2 },
    { "MOUSEWHEELDOWN", "Wheel Dn", "mouse", 1, 3 },
}

local function setBackdrop(frame, r, g, b, a)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(r, g, b, a)
    frame:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
end

local function setRoundedKeyBackdrop(frame, r, g, b, a)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 20,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(r, g, b, a)
    frame:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
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
    if button.GetDisabledTexture and button:GetDisabledTexture() then
        button:GetDisabledTexture():SetTexture(nil)
    end
    if button.SetHighlightTexture then
        button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        local highlight = button:GetHighlightTexture()
        if highlight then
            highlight:SetVertexColor(0, 0, 0, 0)
        end
    end
    setBackdrop(button, 0.09, 0.105, 0.13, 1)
    button:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
    addBorderHover(button)
    if button:GetFontString() then
        button:GetFontString():SetTextColor(0.86, 0.92, 1)
    end
end

local function setRoundedRootBackdrop(frame, r, g, b, a)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(r, g, b, a)
    frame:SetBackdropBorderColor(r, g, b, a)
end

local function createText(parent, size, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetFont(STANDARD_TEXT_FONT, size or 11)
    text:SetJustifyH(justify or "LEFT")
    return text
end

local function createSolidTexture(parent, r, g, b)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(parent)
    texture:SetTexture(r, g, b, 1)
    return texture
end

addBorderHover = function(frame)
    if not frame or not frame.HookScript then
        return
    end
    frame:HookScript("OnEnter", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(HOVER_BORDER_R, HOVER_BORDER_G, HOVER_BORDER_B, 1)
        end
    end)
    frame:HookScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
        end
    end)
end

local function fitButtonLabel(button, width)
    local maxWidth = math.max(10, width - KEY_CONTENT_PADDING * 2)
    local measureWidth = math.max(256, width * 4)
    local label = button.label
    local text = button.labelText or ""
    local fontSize = 12
    local minFontSize = 7

    if maxWidth < 38 then
        fontSize = 9
    elseif maxWidth < 50 then
        fontSize = 10
    end

    if label.SetNonSpaceWrap then
        label:SetNonSpaceWrap(false)
    end
    if label.SetWordWrap then
        label:SetWordWrap(false)
    end

    local function measureText(value, size)
        label:SetFont(STANDARD_TEXT_FONT, size)
        label:SetWidth(measureWidth)
        label:SetHeight(size + 3)
        label:SetText(value or "")
        return label.GetStringWidth and label:GetStringWidth() or 0
    end

    while fontSize > minFontSize and measureText(text, fontSize) > maxWidth do
        fontSize = fontSize - 1
    end

    local fittedText = text
    if measureText(fittedText, fontSize) > maxWidth then
        local clipped = text
        while string.len(clipped) > 1 and measureText(clipped, fontSize) > maxWidth do
            clipped = string.sub(clipped, 1, string.len(clipped) - 1)
        end
        fittedText = clipped
    end

    label:SetFont(STANDARD_TEXT_FONT, fontSize)
    label:SetWidth(maxWidth)
    label:SetHeight(fontSize + 3)
    label:SetText(fittedText)
    if label.GetStringWidth and label:GetStringWidth() > maxWidth then
        local clipped = fittedText
        while string.len(clipped) > 1 and label:GetStringWidth() > maxWidth do
            clipped = string.sub(clipped, 1, string.len(clipped) - 1)
            label:SetText(clipped)
        end
    end
    if label.GetStringWidth and label:GetStringWidth() > maxWidth then
        label:SetText("")
    end
end

local function buildInterfaceActionText(entry, actionName)
    local color = entry and entry.color or "ffffffff"
    return "|cff" .. color .. actionName .. "|r"
end

local function fitInterfaceActionText(fontString, entry, width, height)
    local actionName = entry.actionName or ""
    local fontSize = INTERFACE_ACTION_MAX_FONT_SIZE
    local minFontSize = 8
    local measureWidth = math.max(256, width * 4)

    fontString:SetJustifyH("CENTER")
    if fontString.SetJustifyV then
        fontString:SetJustifyV("MIDDLE")
    end
    if fontString.SetIndentedWordWrap then
        fontString:SetIndentedWordWrap(false)
    end
    if fontString.SetWordWrap then
        fontString:SetWordWrap(false)
    end
    if fontString.SetNonSpaceWrap then
        fontString:SetNonSpaceWrap(false)
    end

    local function measureText(value, size)
        fontString:SetFont(STANDARD_TEXT_FONT, size)
        fontString:SetWidth(measureWidth)
        fontString:SetHeight(height)
        fontString:SetText(value or "")
        return fontString.GetStringWidth and fontString:GetStringWidth() or 0
    end

    while fontSize > minFontSize and measureText(actionName, fontSize) > width do
        fontSize = fontSize - 1
    end

    local fittedName = actionName
    if measureText(fittedName, fontSize) > width then
        while string.len(fittedName) > 1 and measureText(fittedName, fontSize) > width do
            fittedName = string.sub(fittedName, 1, string.len(fittedName) - 1)
        end
    end

    fontString:SetFont(STANDARD_TEXT_FONT, fontSize)
    fontString:SetWidth(width)
    fontString:SetHeight(height)
    fontString:SetText(buildInterfaceActionText(entry, fittedName))
    if fontString.GetStringWidth and fontString:GetStringWidth() > width then
        while string.len(fittedName) > 1 and fontString:GetStringWidth() > width do
            fittedName = string.sub(fittedName, 1, string.len(fittedName) - 1)
            fontString:SetText(buildInterfaceActionText(entry, fittedName))
        end
    end
end

local function getBestIconGrid(count, areaWidth, areaHeight, gap)
    local candidates = {}
    local maxSize = 0
    local targetRatio = areaHeight > 0 and areaWidth / areaHeight or 1

    for cols = 1, count do
        local rows = math.ceil(count / cols)
        local iconSize = math.floor(math.min((areaWidth - (cols - 1) * gap) / cols, (areaHeight - (rows - 1) * gap) / rows))
        local emptyCells = cols * rows - count
        local totalArea = cols * rows * iconSize * iconSize
        local ratioDiff = math.abs((cols / rows) - targetRatio)
        table.insert(candidates, {
            cols = cols,
            rows = rows,
            iconSize = iconSize,
            emptyCells = emptyCells,
            totalArea = totalArea,
            ratioDiff = ratioDiff,
        })
        if iconSize > maxSize then
            maxSize = iconSize
        end
    end

    local best = candidates[1]
    local minUsefulSize = maxSize * 0.92
    for _, candidate in ipairs(candidates) do
        if candidate.iconSize >= minUsefulSize then
            if not best
                or candidate.emptyCells < best.emptyCells
                or (candidate.emptyCells == best.emptyCells and candidate.iconSize > best.iconSize)
                or (candidate.emptyCells == best.emptyCells and candidate.iconSize == best.iconSize and candidate.ratioDiff < best.ratioDiff)
                or (candidate.emptyCells == best.emptyCells and candidate.iconSize == best.iconSize and candidate.ratioDiff == best.ratioDiff and candidate.totalArea > best.totalArea) then
                best = candidate
            end
        end
    end

    return best.cols, best.rows, math.max(8, best.iconSize)
end

local function setIconText(iconFrame, text, iconSize)
    text = text or ""
    local minFontSize = 7
    local fontSize = math.min(INTERFACE_ACTION_MAX_FONT_SIZE, math.floor(iconSize * 0.55))
    local maxTextWidth = math.max(8, iconSize - ICON_LABEL_PADDING * 2)
    local maxTextHeight = (fontSize + 2) * ICON_LABEL_MAX_LINES
    local canWrap = string.find(text, "[%s%-_/%+%.:,;]", 1) and true or false
    local measureWidth = math.max(256, iconSize * 8)

    iconFrame.label:ClearAllPoints()
    iconFrame.label:SetPoint("BOTTOM", iconFrame, "BOTTOM", 0, ICON_LABEL_PADDING)
    iconFrame.label:SetWidth(maxTextWidth)
    iconFrame.label:SetHeight(maxTextHeight)
    iconFrame.label:SetJustifyH("CENTER")
    if iconFrame.label.SetJustifyV then
        iconFrame.label:SetJustifyV("BOTTOM")
    end
    if iconFrame.label.SetWordWrap then
        iconFrame.label:SetWordWrap(canWrap)
    end
    if iconFrame.label.SetNonSpaceWrap then
        iconFrame.label:SetNonSpaceWrap(false)
    end

    if fontSize < minFontSize then
        iconFrame.label:SetText("")
        return
    end

    local function measureText(value, size)
        iconFrame.label:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
        iconFrame.label:SetWidth(measureWidth)
        iconFrame.label:SetHeight(100)
        if iconFrame.label.SetWordWrap then
            iconFrame.label:SetWordWrap(false)
        end
        if iconFrame.label.SetNonSpaceWrap then
            iconFrame.label:SetNonSpaceWrap(false)
        end
        iconFrame.label:SetText(value or "")
        return iconFrame.label.GetStringWidth and iconFrame.label:GetStringWidth() or 0
    end

    local function splitTextForWidth(value, size)
        if not canWrap then
            return nil
        end

        local bestText
        local bestBalance
        for i = 1, string.len(value) do
            local char = string.sub(value, i, i)
            if string.find(char, "[%s%-_/%+%.:,;]") then
                local left
                local right
                if string.find(char, "%s") then
                    left = string.sub(value, 1, i - 1)
                    right = string.sub(value, i + 1)
                else
                    left = string.sub(value, 1, i)
                    right = string.sub(value, i + 1)
                end

                if left ~= "" and right ~= "" then
                    local leftWidth = measureText(left, size)
                    local rightWidth = measureText(right, size)
                    if leftWidth <= maxTextWidth and rightWidth <= maxTextWidth then
                        local balance = math.abs(leftWidth - rightWidth)
                        if not bestBalance or balance < bestBalance then
                            bestText = left .. "\n" .. right
                            bestBalance = balance
                        end
                    end
                end
            end
        end

        return bestText
    end

    local function fitText(value, size)
        if measureText(value, size) <= maxTextWidth then
            return value
        end
        return splitTextForWidth(value, size)
    end

    local fittedText = fitText(text, fontSize)
    while fontSize > minFontSize and not fittedText do
        fontSize = fontSize - 1
        fittedText = fitText(text, fontSize)
    end

    if not fittedText then
        local shortened = text
        while string.len(shortened) > 1 and not fittedText do
            shortened = string.sub(shortened, 1, string.len(shortened) - 1)
            fittedText = fitText(shortened, fontSize)
        end
        if not fittedText then
            iconFrame.label:SetText("")
            iconFrame.label:SetWidth(maxTextWidth)
            iconFrame.label:SetHeight((fontSize + 2) * ICON_LABEL_MAX_LINES)
            return
        end
    end

    maxTextHeight = (fontSize + 2) * ICON_LABEL_MAX_LINES
    iconFrame.label:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    iconFrame.label:SetWidth(maxTextWidth)
    iconFrame.label:SetHeight(maxTextHeight)
    if iconFrame.label.SetWordWrap then
        iconFrame.label:SetWordWrap(false)
    end
    if iconFrame.label.SetNonSpaceWrap then
        iconFrame.label:SetNonSpaceWrap(false)
    end
    iconFrame.label:SetText(fittedText)
end

local function layoutMacroIcons(button, width, height, titleHeight, actionTopY)
    local icons = button.macroIcons or {}
    local count = math.min(#icons, #(button.macroIconFrames or {}))
    local areaTop = titleHeight
    local areaBottom = actionTopY and math.max(titleHeight + 4, actionTopY - 4) or (height - KEY_CONTENT_PADDING)
    local areaHeight = math.max(1, areaBottom - areaTop - 4)
    local areaWidth = math.max(1, width - KEY_CONTENT_PADDING * 2)

    for i, iconFrame in ipairs(button.macroIconFrames) do
        local icon = icons[i]
        iconFrame:ClearAllPoints()
        if icon and icon.texture and i <= count then
            if count == 1 then
                local iconSize = math.floor(math.min(areaWidth, areaHeight))
                iconSize = math.max(8, iconSize)
                iconFrame:SetWidth(iconSize)
                iconFrame:SetHeight(iconSize)
                iconFrame:SetPoint("CENTER", button, "TOPLEFT", width / 2, -(areaTop + 2 + areaHeight / 2))
                iconFrame.texture:SetTexture(icon.texture)
                setIconText(iconFrame, icon.useName and icon.name or icon.text, iconSize)
                iconFrame:Show()
            else
                local gap = 2
                local cols, rows, iconSize = getBestIconGrid(count, areaWidth, areaHeight, gap)
                local totalWidth = cols * iconSize + (cols - 1) * gap
                local totalHeight = rows * iconSize + (rows - 1) * gap
                local startX = KEY_CONTENT_PADDING + math.max(0, (areaWidth - totalWidth) / 2)
                local startY = -(areaTop + 2 + math.max(0, (areaHeight - totalHeight) / 2))
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)

                iconFrame:SetWidth(iconSize)
                iconFrame:SetHeight(iconSize)
                iconFrame:SetPoint("TOPLEFT", button, "TOPLEFT", startX + col * (iconSize + gap), startY - row * (iconSize + gap))
                iconFrame.texture:SetTexture(icon.texture)
                setIconText(iconFrame, icon.useName and icon.name or icon.text, iconSize)
                iconFrame:Show()
            end
        else
            iconFrame:Hide()
        end
    end

    button.macroPlaceholder:Hide()
end

local function hideDynamicKeyContent(button)
    for _, actionText in ipairs(button.interfaceActionTexts or {}) do
        actionText:Hide()
    end
    for _, iconFrame in ipairs(button.macroIconFrames or {}) do
        iconFrame:Hide()
    end
    if button.macroPlaceholder then
        button.macroPlaceholder:Hide()
    end
    if button.conflictText then
        button.conflictText:Hide()
    end
end

local function getOverlaySettings()
    local settings = ADDON.GetSettings()
    settings.overlay = settings.overlay or {}
    return settings.overlay
end

local function saveOverlayPlacement()
    if not overlay then
        return
    end

    local overlaySettings = getOverlaySettings()
    local point, _, relativePoint, xOfs, yOfs = overlay:GetPoint()
    overlaySettings.point = point
    overlaySettings.relativePoint = relativePoint
    overlaySettings.xOfs = xOfs
    overlaySettings.yOfs = yOfs
    overlaySettings.width = overlay:GetWidth()
    overlaySettings.height = overlay:GetHeight()
end

local function loadOverlayPlacement()
    local overlaySettings = getOverlaySettings()
    overlay:SetWidth(math.max(MIN_WIDTH, overlaySettings.width or DEFAULT_WIDTH))
    overlay:SetHeight(math.max(MIN_HEIGHT, overlaySettings.height or DEFAULT_HEIGHT))
    overlay:ClearAllPoints()
    overlay:SetPoint(overlaySettings.point or "CENTER", UIParent, overlaySettings.relativePoint or "CENTER", overlaySettings.xOfs or 0, overlaySettings.yOfs or 0)
end

local function getLayoutMetrics()
    local width = math.max(MIN_WIDTH, overlay:GetWidth() or DEFAULT_WIDTH)
    local height = math.max(MIN_HEIGHT, overlay:GetHeight() or DEFAULT_HEIGHT)
    local contentWidth = math.max(1, width - OUTER_PADDING * 2)
    local contentHeight = math.max(1, height - OUTER_PADDING * 2)
    local totalKeyGaps = (KEYBOARD_COLS - 1) * KEY_GAP + (MOUSE_COLS - 1) * KEY_GAP
    local totalPanelPadding = PANEL_PADDING * 4
    local keyWidth = (contentWidth - SECTION_GAP - totalPanelPadding - totalKeyGaps) / (KEYBOARD_COLS + MOUSE_COLS)
    local keyHeight = (contentHeight - PANEL_PADDING * 2 - (LAYOUT_ROWS - 1) * KEY_GAP) / LAYOUT_ROWS

    keyWidth = math.max(30, keyWidth)
    keyHeight = math.max(28, keyHeight)

    local keyboardWidth = PANEL_PADDING * 2 + KEYBOARD_COLS * keyWidth + (KEYBOARD_COLS - 1) * KEY_GAP
    local mouseWidth = PANEL_PADDING * 2 + MOUSE_COLS * keyWidth + (MOUSE_COLS - 1) * KEY_GAP
    local panelHeight = PANEL_PADDING * 2 + LAYOUT_ROWS * keyHeight + (LAYOUT_ROWS - 1) * KEY_GAP

    return {
        keyWidth = keyWidth,
        keyHeight = keyHeight,
        keyboardX = OUTER_PADDING,
        mouseX = OUTER_PADDING + keyboardWidth + SECTION_GAP,
        panelY = OUTER_PADDING,
        keyboardWidth = keyboardWidth,
        mouseWidth = mouseWidth,
        panelHeight = panelHeight,
    }
end

local function layoutKeyButton(button, lightweight)
    local metrics = getLayoutMetrics()
    local def = button.layoutDef
    local col = def[4]
    local row = def[5]
    local panelX = def[3] == "mouse" and metrics.mouseX or metrics.keyboardX
    local width = metrics.keyWidth
    local height = metrics.keyHeight
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", overlay, "TOPLEFT", panelX + PANEL_PADDING + col * (width + KEY_GAP), -metrics.panelY - PANEL_PADDING - row * (height + KEY_GAP))
    button:SetWidth(width)
    button:SetHeight(height)

    button.label:ClearAllPoints()
    button.label:SetPoint("TOPLEFT", button, "TOPLEFT", KEY_CONTENT_PADDING, -KEY_CONTENT_PADDING)
    button.label:SetJustifyH("LEFT")
    button.bonusBarText:ClearAllPoints()
    button.bonusBarText:SetPoint("TOPRIGHT", button, "TOPRIGHT", -KEY_CONTENT_PADDING, -KEY_CONTENT_PADDING - 1)
    button.bonusBarText:SetWidth(math.max(10, width - KEY_CONTENT_PADDING * 2))
    button.bonusBarText:SetHeight(12)
    button.bonusBarText:SetFont(STANDARD_TEXT_FONT, 9)
    button.bonusBarText:SetJustifyH("RIGHT")

    if lightweight then
        button.label:SetWidth(math.max(10, width - KEY_CONTENT_PADDING * 2))
        button.label:SetHeight(16)
        button.label:Show()
        if (button.bonusBarText:GetText() or "") ~= "" then
            button.bonusBarText:Show()
        end
        hideDynamicKeyContent(button)
        return
    end

    fitButtonLabel(button, width)

    local interfaceActions = button.interfaceActions or {}
    local rowCount = #interfaceActions
    local titleHeight = KEY_CONTENT_PADDING + 16
    local bottomPadding = KEY_CONTENT_PADDING
    local lineGap = 2
    local maxLineHeight = 14
    local availableHeight = math.max(1, height - titleHeight - bottomPadding)
    local lineHeight = rowCount > 0 and math.min(maxLineHeight, math.max(9, (availableHeight - (rowCount - 1) * lineGap) / rowCount)) or 12
    local totalTextHeight = rowCount * lineHeight + math.max(0, rowCount - 1) * lineGap
    local actionTopY = rowCount > 0 and math.max(titleHeight + 4, height - bottomPadding - totalTextHeight) or nil
    local startY = actionTopY and -actionTopY or nil

    layoutMacroIcons(button, width, height, titleHeight, actionTopY)

    for i, actionText in ipairs(button.interfaceActionTexts) do
        local entry = interfaceActions[i]
        actionText:ClearAllPoints()
        if entry and entry.action then
            actionText:SetPoint("TOPLEFT", button, "TOPLEFT", KEY_CONTENT_PADDING, startY - (i - 1) * (lineHeight + lineGap))
            actionText:SetWidth(width - KEY_CONTENT_PADDING * 2)
            actionText:SetHeight(lineHeight)
            fitInterfaceActionText(actionText, entry, width - KEY_CONTENT_PADDING * 2, lineHeight)
            actionText:Show()
        else
            actionText:Hide()
        end
    end

    button.conflictText:ClearAllPoints()
    button.conflictText:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", KEY_CONTENT_PADDING, KEY_CONTENT_PADDING)
    button.conflictText:SetPoint("RIGHT", button, "RIGHT", -KEY_CONTENT_PADDING, 0)
end

local function layoutOverlay(lightweight)
    if not overlay or not overlay.closeButton or not overlay.settingsButton then
        return
    end

    overlay.closeButton:ClearAllPoints()
    overlay.closeButton:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -12, -10)
    overlay.settingsButton:ClearAllPoints()
    overlay.settingsButton:SetPoint("RIGHT", overlay.closeButton, "LEFT", -6, 0)

    for _, button in pairs(keyButtons) do
        layoutKeyButton(button, lightweight)
    end

    if resizeGrip then
        resizeGrip:ClearAllPoints()
        resizeGrip:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -5, 5)
    end
end

local function refreshLayoutActions()
end

local function updateKeyButton(key, button)
    local binding = ADDON.GetBinding(key)
    local macrotext = binding and binding.macrotext or ""
    local conflicts = ADDON.GetConflicts(key)
    local interfaceActions = {}
    for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
        local action = ADDON.GetDefaultBindingAction(variant.key)
        if action and action ~= "" then
            local modifier = variant.modifier or "normal"
            local actionName = ADDON.GetBindingDisplayName(action)
            table.insert(interfaceActions, {
                modifier = modifier,
                action = action,
                actionName = actionName,
                color = MODIFIER_COLORS[modifier] or MODIFIER_COLORS.normal,
            })
        end
    end

    if ADDON.GetDefaultBindingAction(key) ~= "" then
        button.macroIcons = {}
        button.hasMacro = nil
    else
        button.macroIcons = binding and binding.icons or {}
        button.hasMacro = macrotext ~= ""
        if button.hasMacro and #(button.macroIcons or {}) == 0 then
            table.insert(interfaceActions, 1, {
                modifier = "macro",
                action = "__DudesFlexBindings_MACRO__",
                actionName = "<< Makro >>",
                color = "ff6b6b",
            })
        end
    end
    button.interfaceActions = interfaceActions
    local bonusParts = {}
    local bonusBindings = ADDON.GetBonusBarBindings and ADDON.GetBonusBarBindings(key) or {}
    for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
        local modifier = variant.modifier or "normal"
        local slot = bonusBindings[modifier]
        if slot then
            table.insert(bonusParts, "|cff" .. (MODIFIER_COLORS[modifier] or MODIFIER_COLORS.normal) .. tostring(slot) .. "|r")
        end
    end
    if #bonusParts > 0 then
        button.bonusBarText:SetText(table.concat(bonusParts, " "))
        button.bonusBarText:Show()
    else
        button.bonusBarText:SetText("")
        button.bonusBarText:Hide()
    end
    if #conflicts > 0 then
        button.conflictText:Hide()
    else
        button.conflictText:Hide()
    end

    button:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
end

local function createKeyButton(parent, def)
    local key = def[1]
    local button = CreateFrame("Button", nil, parent)
    button:SetFrameLevel(parent:GetFrameLevel() + 1)
    button.layoutDef = def
    setRoundedKeyBackdrop(button, 0.085, 0.098, 0.12, 1)
    button:SetAlpha(1)
    addBorderHover(button)

    button.solidBackground = button:CreateTexture(nil, "BACKGROUND")
    button.solidBackground:SetPoint("TOPLEFT", button, "TOPLEFT", 5, -5)
    button.solidBackground:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
    button.solidBackground:SetTexture(0.085, 0.098, 0.12, 1)

    button.key = key
    button.label = createText(button, 12)
    button.label:SetTextColor(1, 1, 1)
    button.labelText = def[2] or keyLabels[key] or key
    button.label:SetText(button.labelText)

    button.bonusBarText = createText(button, 9, "RIGHT")
    button.bonusBarText:SetTextColor(1, 1, 1)
    button.bonusBarText:Hide()

    button.interfaceActionTexts = {}
    for i = 1, 5 do
        local text = createText(button, 7, "LEFT")
        text:SetTextColor(1, 1, 1)
        text:Hide()
        button.interfaceActionTexts[i] = text
    end

    button.macroIconFrames = {}
    for i = 1, 16 do
        local iconFrame = CreateFrame("Frame", nil, button)
        iconFrame.texture = iconFrame:CreateTexture(nil, "ARTWORK")
        iconFrame.texture:SetAllPoints(iconFrame)
        iconFrame.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        iconFrame.label = createText(iconFrame, 8, "CENTER")
        iconFrame.label:SetPoint("BOTTOM", iconFrame, "BOTTOM", 0, ICON_LABEL_PADDING)
        iconFrame.label:SetJustifyH("CENTER")
        iconFrame.label:SetTextColor(1, 1, 1)
        iconFrame.label:SetShadowOffset(0, 0)
        iconFrame.label:SetShadowColor(0, 0, 0, 0)
        iconFrame:Hide()
        button.macroIconFrames[i] = iconFrame
    end

    button.macroPlaceholder = createText(button, 8, "LEFT")
    button.macroPlaceholder:SetTextColor(0.45, 0.8, 1)
    button.macroPlaceholder:Hide()

    button.conflictText = createText(button, 8, "LEFT")
    button.conflictText:SetTextColor(1, 0.35, 0.25)
    button.conflictText:Hide()

    button:SetScript("OnClick", function(self)
        if ADDON.OpenEditor then
            ADDON.OpenEditor(self.key)
        end
    end)

    keyButtons[key] = button
    return button
end

local function createHeader(parent)
    parent.closeButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    parent.closeButton:SetWidth(36)
    parent.closeButton:SetHeight(30)
    parent.closeButton:SetFrameLevel(parent:GetFrameLevel() + 2)
    parent.closeButton:SetText("X")
    styleButton(parent.closeButton)
    parent.closeButton:SetScript("OnClick", function()
        parent:Hide()
    end)

    parent.settingsButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    parent.settingsButton:SetWidth(36)
    parent.settingsButton:SetHeight(30)
    parent.settingsButton:SetFrameLevel(parent:GetFrameLevel() + 2)
    parent.settingsButton:SetText("...")
    styleButton(parent.settingsButton)
    parent.settingsButton:SetScript("OnClick", function()
        if ADDON.ToggleSettings then
            ADDON.ToggleSettings()
        end
    end)
    parent.settingsButton:SetScript("OnEnter", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(HOVER_BORDER_R, HOVER_BORDER_G, HOVER_BORDER_B, 1)
        end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("DudesFlexBindings")
        GameTooltip:AddLine("Einstellungen", 1, 1, 1)
        GameTooltip:Show()
    end)
    parent.settingsButton:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
        end
        GameTooltip:Hide()
    end)

end

local function createLayoutButtons(parent)
    for _, def in ipairs(keyDefs) do
        createKeyButton(parent, def)
    end
end

local function createResizeGrip(parent)
    resizeGrip = CreateFrame("Button", nil, parent)
    resizeGrip:SetWidth(16)
    resizeGrip:SetHeight(16)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:RegisterForDrag("LeftButton")
    resizeGrip:SetScript("OnDragStart", function()
        parent.isResizing = true
        layoutOverlay(true)
        if parent.StartSizing then
            parent:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeGrip:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        parent.isResizing = nil
        saveOverlayPlacement()
        layoutOverlay(false)
    end)
end

local function registerOverlaySpecialFrame()
    if registeredSpecialFrame or not UISpecialFrames then
        return
    end

    for _, frameName in ipairs(UISpecialFrames) do
        if frameName == "DudesFlexBindingsOverlay" then
            registeredSpecialFrame = true
            return
        end
    end

    table.insert(UISpecialFrames, "DudesFlexBindingsOverlay")
    registeredSpecialFrame = true
end

function ADDON.CreateOverlay()
    if overlay then
        return overlay
    end

    overlay = CreateFrame("Frame", "DudesFlexBindingsOverlay", UIParent)
    overlay:SetFrameStrata("MEDIUM")
    overlay:SetFrameLevel(100)
    overlay:EnableMouse(true)
    overlay:SetMovable(true)
    if overlay.SetResizable then
        overlay:SetResizable(true)
    end
    if overlay.SetMinResize then
        overlay:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
    end
    overlay:RegisterForDrag("LeftButton")
    overlay:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    overlay:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        saveOverlayPlacement()
    end)
    overlay:SetScript("OnSizeChanged", function(self)
        layoutOverlay(self.isResizing)
    end)
    setRoundedRootBackdrop(overlay, 0.02, 0.025, 0.035, 0.72)
    registerOverlaySpecialFrame()

    createHeader(overlay)
    createLayoutButtons(overlay)
    createResizeGrip(overlay)
    loadOverlayPlacement()
    layoutOverlay()

    overlay:Hide()
    return overlay
end

function ADDON.RefreshOverlay()
    if not overlay then
        return
    end

    for key, button in pairs(keyButtons) do
        updateKeyButton(key, button)
    end
    refreshLayoutActions()
    layoutOverlay()
end

function ADDON.ToggleOverlay()
    ADDON.CreateOverlay()
    ADDON.RefreshOverlay()
    if overlay:IsShown() then
        overlay:Hide()
    else
        overlay:Show()
    end
end

function ADDON.ShowOverlay()
    ADDON.CreateOverlay()
    ADDON.RefreshOverlay()
    overlay:Show()
end
