local ADDON = DudesFlexBindings

local frame
local buttons = {}
local resizeGrip
local centerHorizontalButton
local centerVerticalButton

local BORDER_R, BORDER_G, BORDER_B = 0.32, 0.38, 0.46
local ACTIVE_BORDER_R, ACTIVE_BORDER_G, ACTIVE_BORDER_B = 0.72, 0.86, 1
local SLOT_COUNT = 12
local ANCHORS = {
    topLeft = true,
    top = true,
    topRight = true,
    left = true,
    center = true,
    right = true,
    bottomLeft = true,
    bottom = true,
    bottomRight = true,
}
local GROWTH_DIRECTIONS = {
    right = true,
    down = true,
    left = true,
    up = true,
}

local function setBackdrop(target, r, g, b, a)
    target:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    target:SetBackdropColor(r, g, b, a)
    target:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
end

local function createText(parent, size)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetFont(STANDARD_TEXT_FONT, size or 11)
    text:SetJustifyH("CENTER")
    text:SetTextColor(0.9, 0.92, 0.96)
    return text
end

local function styleControlButton(button)
    setBackdrop(button, 0.055, 0.065, 0.08, 1)
    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(ACTIVE_BORDER_R, ACTIVE_BORDER_G, ACTIVE_BORDER_B, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
    end)
end

local function getSettings()
    local settings = ADDON.GetSettings()
    settings.bonusBar = settings.bonusBar or {}
    settings.bonusBar.point = settings.bonusBar.point or "BOTTOM"
    settings.bonusBar.relativePoint = settings.bonusBar.relativePoint or "BOTTOM"
    settings.bonusBar.xOfs = settings.bonusBar.xOfs or 0
    settings.bonusBar.yOfs = settings.bonusBar.yOfs or 160
    settings.bonusBar.width = settings.bonusBar.width or 460
    settings.bonusBar.height = settings.bonusBar.height or 46
    if not ANCHORS[settings.bonusBarAnchor] then
        settings.bonusBarAnchor = "topLeft"
    end
    if not GROWTH_DIRECTIONS[settings.bonusBarGrowthDirection] then
        settings.bonusBarGrowthDirection = "right"
    end
    return settings
end

local function getSlotTexture(slot)
    local actionSlot
    local button = _G["BonusActionButton" .. tostring(slot)]
    if button and button.action then
        actionSlot = button.action
    end

    if not actionSlot then
        local offset = GetBonusBarOffset and GetBonusBarOffset() or 0
        if offset and offset > 0 then
            actionSlot = offset * SLOT_COUNT + slot
        end
    end

    if actionSlot and GetActionTexture then
        if HasAction and not HasAction(actionSlot) then
            return nil
        end
        return GetActionTexture(actionSlot)
    end
    return nil
end

local function getActiveSlots()
    local activeSlots = {}
    for slot = 1, SLOT_COUNT do
        local texture = getSlotTexture(slot)
        if texture then
            table.insert(activeSlots, {
                slot = slot,
                texture = texture,
            })
        end
    end
    return activeSlots
end

local function setRootFrameStyle(active, align)
    if active then
        frame:SetBackdropColor(0, 0, 0, 0)
        frame:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 0)
    else
        frame:SetBackdropColor(0.02, 0.025, 0.035, 0.28)
        frame:SetBackdropBorderColor(align and ACTIVE_BORDER_R or BORDER_R, align and ACTIVE_BORDER_G or BORDER_G, align and ACTIVE_BORDER_B or BORDER_B, 1)
    end
end

local function setButtonFrameStyle(button, visible, active)
    if visible then
        button:SetBackdropColor(0.015, 0.012, 0.01, active and 0.95 or 0.65)
        button:SetBackdropBorderColor(0, 0, 0, active and 1 or 0.85)
        for _, border in ipairs(button.innerBorders) do
            border:SetVertexColor(active and 0.52 or BORDER_R, active and 0.45 or BORDER_G, active and 0.34 or BORDER_B, active and 0.95 or 0.8)
            border:Show()
        end
        button.gloss:SetVertexColor(1, 0.92, 0.72, active and 0.08 or 0.04)
        button.gloss:Show()
    else
        button:SetBackdropColor(0, 0, 0, 0)
        button:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 0)
        for _, border in ipairs(button.innerBorders) do
            border:Hide()
        end
        button.gloss:Hide()
    end
end

function ADDON.IsBonusBarActive()
    if IsPossessBarVisible and IsPossessBarVisible() then
        return true
    end
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then
        return true
    end
    local offset = GetBonusBarOffset and GetBonusBarOffset() or 0
    return offset and offset == 5
end

local function savePlacement()
    if not frame then
        return
    end
    local settings = getSettings().bonusBar
    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
    settings.point = point
    settings.relativePoint = relativePoint
    settings.xOfs = xOfs
    settings.yOfs = yOfs
    settings.width = frame:GetWidth()
    settings.height = frame:GetHeight()
end

local function getCenterOffsets()
    local centerX, centerY = frame:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()
    return (centerX or parentCenterX or 0) - (parentCenterX or 0), (centerY or parentCenterY or 0) - (parentCenterY or 0)
end

local function centerFrame(horizontal, vertical)
    if not frame then
        return
    end
    local xOfs, yOfs = getCenterOffsets()
    if horizontal then
        xOfs = 0
    end
    if vertical then
        yOfs = 0
    end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", xOfs, yOfs)
    savePlacement()
    ADDON.RefreshBonusBar()
end

local function loadPlacement()
    local settings = getSettings().bonusBar
    frame:SetWidth(settings.width or 460)
    frame:SetHeight(settings.height or 46)
    frame:ClearAllPoints()
    frame:SetPoint(settings.point or "BOTTOM", UIParent, settings.relativePoint or "BOTTOM", settings.xOfs or 0, settings.yOfs or 160)
end

local function layoutButtons(buttonCount)
    if not frame then
        return
    end
    buttonCount = math.max(1, math.min(SLOT_COUNT, buttonCount or SLOT_COUNT))

    local settings = getSettings()
    local padding = 4
    local gap = 2
    local availableWidth = math.max(18, frame:GetWidth() - padding * 2)
    local availableHeight = math.max(18, frame:GetHeight() - padding * 2)
    local anchor = settings.bonusBarAnchor or "topLeft"
    local growthDirection = settings.bonusBarGrowthDirection or "right"
    local preferVertical = growthDirection == "down" or growthDirection == "up"
    local bestCols, bestRows, bestSize = buttonCount, 1, 0

    for primaryCount = 1, buttonCount do
        local cols, rows
        if preferVertical then
            rows = primaryCount
            cols = math.ceil(buttonCount / rows)
        else
            cols = primaryCount
            rows = math.ceil(buttonCount / cols)
        end

        local widthSize = (availableWidth - (cols - 1) * gap) / cols
        local heightSize = (availableHeight - (rows - 1) * gap) / rows
        local size = math.floor(math.min(widthSize, heightSize))
        local better = size > bestSize
        if size == bestSize then
            if preferVertical then
                better = rows > bestRows
            else
                better = cols > bestCols
            end
        end
        if better then
            bestCols = cols
            bestRows = rows
            bestSize = size
        end
    end

    local iconSize = math.max(12, bestSize)
    local totalWidth = bestCols * iconSize + (bestCols - 1) * gap
    local totalHeight = bestRows * iconSize + (bestRows - 1) * gap
    local startX = padding
    local startY = -padding

    if anchor == "top" or anchor == "center" or anchor == "bottom" then
        startX = math.max(padding, (frame:GetWidth() - totalWidth) / 2)
    elseif anchor == "topRight" or anchor == "right" or anchor == "bottomRight" then
        startX = frame:GetWidth() - padding - totalWidth
    end

    if anchor == "left" or anchor == "center" or anchor == "right" then
        startY = -math.max(padding, (frame:GetHeight() - totalHeight) / 2)
    elseif anchor == "bottomLeft" or anchor == "bottom" or anchor == "bottomRight" then
        startY = -frame:GetHeight() + padding + totalHeight
    end

    for i = 1, buttonCount do
        local button = buttons[i]
        local index = i - 1
        local col, row
        if preferVertical then
            col = math.floor(index / bestRows)
            row = index % bestRows
        else
            col = index % bestCols
            row = math.floor(index / bestCols)
        end
        if growthDirection == "left" then
            col = bestCols - 1 - col
        elseif growthDirection == "up" then
            row = bestRows - 1 - row
        end

        local x = startX + col * (iconSize + gap)
        local y = startY - row * (iconSize + gap)

        button:ClearAllPoints()
        button:SetWidth(iconSize)
        button:SetHeight(iconSize)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        button.bindingText:SetFont(STANDARD_TEXT_FONT, math.max(7, math.floor(iconSize * 0.24)), "OUTLINE")
    end

    if resizeGrip then
        resizeGrip:ClearAllPoints()
        resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    end
    if centerVerticalButton and centerHorizontalButton then
        centerVerticalButton:ClearAllPoints()
        centerVerticalButton:SetPoint("TOPRIGHT", frame, "BOTTOM", -4, -6)
        centerHorizontalButton:ClearAllPoints()
        centerHorizontalButton:SetPoint("TOPLEFT", frame, "BOTTOM", 4, -6)
    end
end

function ADDON.RefreshBonusBar()
    if not frame then
        return
    end

    local settings = getSettings()
    local active = ADDON.IsBonusBarActive()
    local align = settings.alignBonusBar and true or false
    local show = settings.showBonusBar and (active or align)
    local activeSlots = active and getActiveSlots() or {}

    if not show then
        frame:Hide()
        return
    end

    setRootFrameStyle(active, align)
    frame:EnableMouse(align)
    if resizeGrip then
        if align then
            resizeGrip:Show()
        else
            resizeGrip:Hide()
        end
    end
    if centerVerticalButton and centerHorizontalButton then
        if align then
            centerVerticalButton:Show()
            centerHorizontalButton:Show()
        else
            centerVerticalButton:Hide()
            centerHorizontalButton:Hide()
        end
    end

    layoutButtons(active and #activeSlots or SLOT_COUNT)
    for i, button in ipairs(buttons) do
        local activeSlot = activeSlots[i]
        if activeSlot then
            setButtonFrameStyle(button, true, true)
            button.icon:SetTexture(activeSlot.texture)
            button.icon:SetVertexColor(1, 1, 1, 1)
            button.icon:SetAlpha(1)
            button.icon:Show()
            button.placeholderText:Hide()
        elseif align then
            setButtonFrameStyle(button, true, false)
            button.icon:SetTexture("Interface\\Buttons\\WHITE8X8")
            button.icon:SetVertexColor(0.45, 0.55, 0.68, 0.28)
            button.icon:SetAlpha(0.28)
            button.icon:Show()
            button.placeholderText:SetText(tostring(i))
            button.placeholderText:Show()
        else
            setButtonFrameStyle(button, false, false)
            button.icon:SetTexture(nil)
            button.icon:Hide()
            button.placeholderText:Hide()
        end

        if activeSlot and settings.showBonusBarBindings then
            button.bindingText:SetText(ADDON.GetBonusBarBindingTextForSlot and ADDON.GetBonusBarBindingTextForSlot(activeSlot.slot) or "")
            button.bindingText:Show()
        elseif not active and settings.showBonusBarBindings then
            button.bindingText:SetText(ADDON.GetBonusBarBindingTextForSlot and ADDON.GetBonusBarBindingTextForSlot(i) or "")
            button.bindingText:Show()
        else
            button.bindingText:Hide()
        end
        if active and not activeSlot then
            button:Hide()
        else
            button:Show()
        end
    end
    frame:Show()
end

local function createButton(parent, index)
    local button = CreateFrame("Frame", nil, parent)
    setBackdrop(button, 0.04, 0.048, 0.06, 0.65)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.innerBorders = {}
    button.innerBorders[1] = button:CreateTexture(nil, "OVERLAY")
    button.innerBorders[1]:SetPoint("TOPLEFT", button.icon, "TOPLEFT", -1, 1)
    button.innerBorders[1]:SetPoint("TOPRIGHT", button.icon, "TOPRIGHT", 1, 1)
    button.innerBorders[1]:SetHeight(1)
    button.innerBorders[2] = button:CreateTexture(nil, "OVERLAY")
    button.innerBorders[2]:SetPoint("BOTTOMLEFT", button.icon, "BOTTOMLEFT", -1, -1)
    button.innerBorders[2]:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 1, -1)
    button.innerBorders[2]:SetHeight(1)
    button.innerBorders[3] = button:CreateTexture(nil, "OVERLAY")
    button.innerBorders[3]:SetPoint("TOPLEFT", button.icon, "TOPLEFT", -1, 1)
    button.innerBorders[3]:SetPoint("BOTTOMLEFT", button.icon, "BOTTOMLEFT", -1, -1)
    button.innerBorders[3]:SetWidth(1)
    button.innerBorders[4] = button:CreateTexture(nil, "OVERLAY")
    button.innerBorders[4]:SetPoint("TOPRIGHT", button.icon, "TOPRIGHT", 1, 1)
    button.innerBorders[4]:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 1, -1)
    button.innerBorders[4]:SetWidth(1)
    for _, border in ipairs(button.innerBorders) do
        border:SetTexture("Interface\\Buttons\\WHITE8X8")
        border:Hide()
    end

    button.gloss = button:CreateTexture(nil, "OVERLAY")
    button.gloss:SetPoint("TOPLEFT", button.icon, "TOPLEFT", 1, -1)
    button.gloss:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", -1, 1)
    button.gloss:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.gloss:Hide()

    button.placeholderText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.placeholderText:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.placeholderText:SetTextColor(0.72, 0.78, 0.88)
    button.placeholderText:Hide()

    button.bindingText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.bindingText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 1)
    button.bindingText:SetJustifyH("RIGHT")
    button.bindingText:SetTextColor(1, 1, 1)
    button.bindingText:SetShadowColor(0, 0, 0, 1)
    button.bindingText:SetShadowOffset(1, -1)
    buttons[index] = button
end

function ADDON.CreateBonusBar()
    if frame then
        ADDON.RefreshBonusBar()
        return frame
    end

    frame = CreateFrame("Frame", "DudesFlexBindingsBonusBar", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    if frame.SetResizable then
        frame:SetResizable(true)
        frame:SetMinResize(180, 28)
    end
    setBackdrop(frame, 0.02, 0.025, 0.035, 0.28)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if getSettings().alignBonusBar then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePlacement()
    end)
    frame:SetScript("OnSizeChanged", function()
        layoutButtons()
    end)

    for i = 1, SLOT_COUNT do
        createButton(frame, i)
    end

    centerVerticalButton = CreateFrame("Button", nil, frame)
    centerVerticalButton:SetWidth(126)
    centerVerticalButton:SetHeight(22)
    styleControlButton(centerVerticalButton)
    centerVerticalButton.text = createText(centerVerticalButton, 10)
    centerVerticalButton.text:SetAllPoints(centerVerticalButton)
    centerVerticalButton.text:SetText("Vertikal zentrieren")
    centerVerticalButton:SetScript("OnClick", function()
        centerFrame(false, true)
    end)
    centerVerticalButton:Hide()

    centerHorizontalButton = CreateFrame("Button", nil, frame)
    centerHorizontalButton:SetWidth(136)
    centerHorizontalButton:SetHeight(22)
    styleControlButton(centerHorizontalButton)
    centerHorizontalButton.text = createText(centerHorizontalButton, 10)
    centerHorizontalButton.text:SetAllPoints(centerHorizontalButton)
    centerHorizontalButton.text:SetText("Horizontal zentrieren")
    centerHorizontalButton:SetScript("OnClick", function()
        centerFrame(true, false)
    end)
    centerHorizontalButton:Hide()

    resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetWidth(14)
    resizeGrip:SetHeight(14)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:RegisterForDrag("LeftButton")
    resizeGrip:SetScript("OnDragStart", function()
        if frame.StartSizing and getSettings().alignBonusBar then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeGrip:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePlacement()
    end)

    loadPlacement()
    ADDON.RefreshBonusBar()
    return frame
end

DudesUtils.EventHandler.Add("PLAYER_LOGIN", function()
    ADDON.CreateBonusBar()
end)
DudesUtils.EventHandler.Add("PLAYER_ENTERING_WORLD", function()
    ADDON.CreateBonusBar()
    ADDON.RefreshBonusBar()
end)
DudesUtils.EventHandler.Add("UPDATE_BONUS_ACTIONBAR", ADDON.RefreshBonusBar)
DudesUtils.EventHandler.Add("UPDATE_POSSESS_BAR", ADDON.RefreshBonusBar)
DudesUtils.EventHandler.Add("UNIT_ENTERED_VEHICLE", ADDON.RefreshBonusBar)
DudesUtils.EventHandler.Add("UNIT_EXITED_VEHICLE", ADDON.RefreshBonusBar)
DudesUtils.EventHandler.Add("ACTIONBAR_PAGE_CHANGED", ADDON.RefreshBonusBar)
DudesUtils.EventHandler.Add("ACTIONBAR_SLOT_CHANGED", ADDON.RefreshBonusBar)
