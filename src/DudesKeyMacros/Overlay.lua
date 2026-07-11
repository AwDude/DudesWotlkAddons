local ADDON = DudesKeyMacros

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
local CONTROL_HEIGHT = 18
local KEYBOARD_COLS = 13
local MOUSE_COLS = 2
local LAYOUT_ROWS = 5
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
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(r, g, b, a)
    frame:SetBackdropBorderColor(0.35, 0.45, 0.65, 1)
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

local function fitButtonLabel(button, width)
    local maxWidth = math.max(10, width - 12)
    local label = button.label
    local text = button.labelText or ""
    local fontSize = 12

    if maxWidth < 38 then
        fontSize = 9
    elseif maxWidth < 50 then
        fontSize = 10
    end

    label:SetFont(STANDARD_TEXT_FONT, fontSize)
    label:SetWidth(maxWidth)
    label:SetHeight(fontSize + 3)
    if label.SetNonSpaceWrap then
        label:SetNonSpaceWrap(false)
    end
    if label.SetWordWrap then
        label:SetWordWrap(false)
    end

    label:SetText(text)
    while label:GetStringWidth() > maxWidth and fontSize > 7 do
        fontSize = fontSize - 1
        label:SetFont(STANDARD_TEXT_FONT, fontSize)
        label:SetHeight(fontSize + 3)
    end

    if label:GetStringWidth() <= maxWidth then
        return
    end

    local clipped = text
    while string.len(clipped) > 1 do
        clipped = string.sub(clipped, 1, string.len(clipped) - 1)
        label:SetText(clipped)
        if label:GetStringWidth() <= maxWidth then
            return
        end
    end
end

local function buildInterfaceActionText(entry, actionName)
    local color = entry and entry.color or "ffffffff"
    return "|cff" .. color .. actionName .. "|r"
end

local function fitInterfaceActionText(fontString, entry, width, height)
    local actionName = entry.actionName or ""
    local fontSize = 10
    local minFontSize = 7

    fontString:SetWidth(width)
    fontString:SetHeight(height)
    fontString:SetJustifyH("CENTER")
    if fontString.SetJustifyV then
        fontString:SetJustifyV("MIDDLE")
    end
    if fontString.SetIndentedWordWrap then
        fontString:SetIndentedWordWrap(false)
    end
    if fontString.SetWordWrap then
        fontString:SetWordWrap(true)
    end
    if fontString.SetNonSpaceWrap then
        fontString:SetNonSpaceWrap(true)
    end

    while fontSize >= minFontSize do
        fontString:SetFont(STANDARD_TEXT_FONT, fontSize)
        fontString:SetText(buildInterfaceActionText(entry, actionName))
        if not fontString.GetStringHeight or fontString:GetStringHeight() <= height + 1 then
            return
        end
        fontSize = fontSize - 1
    end

    fontSize = minFontSize
    fontString:SetFont(STANDARD_TEXT_FONT, fontSize)
    if fontString.SetWordWrap then
        fontString:SetWordWrap(false)
    end
    fontString:SetText(buildInterfaceActionText(entry, actionName))
    while fontString.GetStringWidth and fontString:GetStringWidth() > width and string.len(actionName) > 1 do
        actionName = string.sub(actionName, 1, string.len(actionName) - 1)
        fontString:SetText(buildInterfaceActionText(entry, actionName .. "..."))
    end
end

local function getBestIconGrid(count, areaWidth, areaHeight, gap)
    local bestCols = 1
    local bestRows = count
    local bestSize = 0
    local bestArea = 0
    local targetRatio = areaHeight > 0 and areaWidth / areaHeight or 1
    local bestRatioDiff = 999

    for cols = 1, count do
        local rows = math.ceil(count / cols)
        local iconSize = math.floor(math.min((areaWidth - (cols - 1) * gap) / cols, (areaHeight - (rows - 1) * gap) / rows))
        local totalArea = cols * rows * iconSize * iconSize
        local ratioDiff = math.abs((cols / rows) - targetRatio)
        if iconSize > bestSize or (iconSize == bestSize and (ratioDiff < bestRatioDiff or (ratioDiff == bestRatioDiff and totalArea > bestArea))) then
            bestCols = cols
            bestRows = rows
            bestSize = iconSize
            bestArea = totalArea
            bestRatioDiff = ratioDiff
        end
    end

    return bestCols, bestRows, math.max(8, bestSize)
end

local function setIconText(iconFrame, text, iconSize)
    text = text or ""
    local minFontSize = 5
    local fontSize = math.floor(iconSize * 0.55)
    if fontSize < minFontSize then
        iconFrame.label:SetText("")
        return
    end

    fontSize = math.min(22, fontSize)
    iconFrame.label:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    iconFrame.label:SetText(text)
    while fontSize > minFontSize and iconFrame.label.GetStringWidth and iconFrame.label:GetStringWidth() > iconSize - 2 do
        fontSize = fontSize - 1
        iconFrame.label:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    end
    if iconFrame.label.GetStringWidth and iconFrame.label:GetStringWidth() > iconSize - 2 then
        iconFrame.label:SetText("")
    end
end

local function layoutMacroIcons(button, width, height, titleHeight, actionTopY)
    local icons = button.macroIcons or {}
    local count = math.min(#icons, #(button.macroIconFrames or {}))
    local areaTop = titleHeight
    local areaBottom = actionTopY and math.max(titleHeight + 4, actionTopY - 4) or (height - 8)
    local areaHeight = math.max(1, areaBottom - areaTop - 4)
    local areaWidth = math.max(1, width - 12)

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
                setIconText(iconFrame, icon.text, iconSize)
                iconFrame:Show()
            else
                local gap = 2
                local cols, rows, iconSize = getBestIconGrid(count, areaWidth, areaHeight, gap)
                local totalWidth = cols * iconSize + (cols - 1) * gap
                local totalHeight = rows * iconSize + (rows - 1) * gap
                local startX = 6 + math.max(0, (areaWidth - totalWidth) / 2)
                local startY = -(areaTop + 2 + math.max(0, (areaHeight - totalHeight) / 2))
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)

                iconFrame:SetWidth(iconSize)
                iconFrame:SetHeight(iconSize)
                iconFrame:SetPoint("TOPLEFT", button, "TOPLEFT", startX + col * (iconSize + gap), startY - row * (iconSize + gap))
                iconFrame.texture:SetTexture(icon.texture)
                setIconText(iconFrame, icon.text, iconSize)
                iconFrame:Show()
            end
        else
            iconFrame:Hide()
        end
    end

    button.macroPlaceholder:Hide()
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
    local contentHeight = math.max(1, height - OUTER_PADDING * 2 - CONTROL_HEIGHT)
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

local function layoutKeyButton(button)
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
    button.label:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -4)
    button.label:SetJustifyH("LEFT")
    fitButtonLabel(button, width)

    local interfaceActions = button.interfaceActions or {}
    local rowCount = #interfaceActions
    local titleHeight = 22
    local bottomPadding = 8
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
            actionText:SetPoint("TOPLEFT", button, "TOPLEFT", 5, startY - (i - 1) * (lineHeight + lineGap))
            actionText:SetWidth(width - 10)
            actionText:SetHeight(lineHeight)
            fitInterfaceActionText(actionText, entry, width - 10, lineHeight)
            actionText:Show()
        else
            actionText:Hide()
        end
    end

    button.conflictText:ClearAllPoints()
    button.conflictText:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 5, 4)
    button.conflictText:SetPoint("RIGHT", button, "RIGHT", -5, 0)
end

local function layoutOverlay()
    if not overlay or not overlay.closeButton then
        return
    end

    overlay.closeButton:ClearAllPoints()
    overlay.closeButton:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -12, -10)
    overlay.settingsButton:ClearAllPoints()
    overlay.settingsButton:SetPoint("RIGHT", overlay.closeButton, "LEFT", -6, 0)

    for _, button in pairs(keyButtons) do
        layoutKeyButton(button)
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
    local modifierColors = {
        normal = "ffffff",
        shift = "9dff9d",
        ctrl = "fff28a",
        alt = "ff9dff",
    }
    for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
        local action = ADDON.GetDefaultBindingAction(variant.key)
        if action and action ~= "" then
            local modifier = variant.modifier or "normal"
            local actionName = ADDON.GetBindingDisplayName(action)
            table.insert(interfaceActions, {
                modifier = modifier,
                action = action,
                actionName = actionName,
                color = modifierColors[modifier] or modifierColors.normal,
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
                action = "__DUDESKEYMACROS_MACRO__",
                actionName = "Makro",
                color = "73ccff",
            })
        end
    end
    button.interfaceActions = interfaceActions
    if #conflicts > 0 then
        button.conflictText:Hide()
    else
        button.conflictText:Hide()
    end

    button:SetBackdropBorderColor(0, 0, 0, 1)
end

local function createKeyButton(parent, def)
    local key = def[1]
    local button = CreateFrame("Button", nil, parent)
    button:SetFrameLevel(parent:GetFrameLevel() + 1)
    button.layoutDef = def
    setBackdrop(button, 0.04, 0.05, 0.07, 1)
    button:SetBackdropBorderColor(0, 0, 0, 1)
    button:SetAlpha(1)

    button.solidBackground = button:CreateTexture(nil, "BACKGROUND")
    button.solidBackground:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    button.solidBackground:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.solidBackground:SetTexture(0.04, 0.05, 0.07, 1)

    button.key = key
    button.label = createText(button, 12)
    button.label:SetTextColor(1, 0.55, 0.05)
    button.labelText = def[2] or keyLabels[key] or key
    button.label:SetText(button.labelText)

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
        iconFrame.label = createText(iconFrame, 8, "RIGHT")
        iconFrame.label:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
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
    parent.closeButton:SetWidth(24)
    parent.closeButton:SetHeight(22)
    parent.closeButton:SetFrameLevel(parent:GetFrameLevel() + 2)
    parent.closeButton:SetText("X")
    parent.closeButton:SetScript("OnClick", function()
        parent:Hide()
    end)

    parent.settingsButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    parent.settingsButton:SetWidth(24)
    parent.settingsButton:SetHeight(22)
    parent.settingsButton:SetFrameLevel(parent:GetFrameLevel() + 2)
    parent.settingsButton:SetText("...")
    parent.settingsButton:SetScript("OnClick", function()
        if ADDON.ToggleSettings then
            ADDON.ToggleSettings()
        end
    end)
    parent.settingsButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("DudesKeyMacros")
        GameTooltip:AddLine("Einstellungen", 1, 1, 1)
        GameTooltip:Show()
    end)
    parent.settingsButton:SetScript("OnLeave", function()
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
        if parent.StartSizing then
            parent:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeGrip:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        saveOverlayPlacement()
        layoutOverlay()
    end)
end

local function registerOverlaySpecialFrame()
    if registeredSpecialFrame or not UISpecialFrames then
        return
    end

    for _, frameName in ipairs(UISpecialFrames) do
        if frameName == "DudesKeyMacrosOverlay" then
            registeredSpecialFrame = true
            return
        end
    end

    table.insert(UISpecialFrames, "DudesKeyMacrosOverlay")
    registeredSpecialFrame = true
end

function ADDON.CreateOverlay()
    if overlay then
        return overlay
    end

    overlay = CreateFrame("Frame", "DudesKeyMacrosOverlay", UIParent)
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
    overlay:SetScript("OnSizeChanged", function()
        layoutOverlay()
    end)
    setBackdrop(overlay, 0.02, 0.025, 0.035, 0.72)
    registerOverlaySpecialFrame()

    loadOverlayPlacement()
    createHeader(overlay)
    createLayoutButtons(overlay)
    createResizeGrip(overlay)
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
