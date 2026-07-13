local ADDON = DudesFlexBindings

local frame
local buttons = {}
local resizeGrip
local centerHorizontalButton
local centerVerticalButton
local hideAlignButton
local refreshTimer
local refreshDelayRemaining
local refreshBurstRemaining
local hookedSourceButtons = {}
local pressAnimations = {}
local pressAnimationTimer

local BORDER_R, BORDER_G, BORDER_B = 0.32, 0.38, 0.46
local ACTIVE_BORDER_R, ACTIVE_BORDER_G, ACTIVE_BORDER_B = 0.72, 0.86, 1
local SLOT_COUNT = 12
local REFRESH_BURST_DELAY = 0.12
local REFRESH_BURST_COUNT = 8
local PRESS_ANIMATION_DURATION = 0.12
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

local function getBonusBarOffset()
    return (GetBonusBarOffset and GetBonusBarOffset()) or 0
end

local function getFrameIconTexture(frameName)
    local frame = _G[frameName]
    if frame then
        local icon = frame.icon or frame.Icon
        if icon and icon.GetTexture then
            local texture = icon:GetTexture()
            if texture then
                return texture
            end
        end
    end

    local icon = _G[frameName .. "Icon"]
    if icon and icon.GetTexture then
        return icon:GetTexture()
    end
    return nil
end

local function getActionTexture(actionSlot)
    if not actionSlot or not GetActionTexture then
        return nil
    end
    if HasAction and not HasAction(actionSlot) then
        return nil
    end
    return GetActionTexture(actionSlot)
end

local function getBonusActionInfo(slot)
    local buttonName = ADDON.GetBonusBarButtonName and ADDON.GetBonusBarButtonName(slot) or ("BonusActionButton" .. tostring(slot))
    local button = buttonName and _G[buttonName]
    if not button or (button.IsShown and not button:IsShown()) then
        return nil
    end

    local actionSlot = button and (button.action or (button.GetAttribute and button:GetAttribute("action")))
    local texture = getActionTexture(actionSlot) or getFrameIconTexture(buttonName)
    if not texture then
        return nil
    end
    return {
        slot = slot,
        texture = texture,
        buttonName = buttonName,
        sourceButton = button,
        actionSlot = actionSlot,
    }
end

local function getActiveSlots()
    local activeSlots = {}
    for slot = 1, SLOT_COUNT do
        local actionInfo = getBonusActionInfo(slot)
        if actionInfo then
            table.insert(activeSlots, actionInfo)
        end
    end
    return activeSlots
end

local function getButtonForBonusSlot(slot)
    for _, button in ipairs(buttons) do
        if button.activeSlot and button.activeSlot.slot == slot then
            return button
        end
    end
    return nil
end

local function clearButtonActionState(button)
    if button.cooldown then
        button.cooldown:Hide()
    end
    if button.checkedOverlay then
        button.checkedOverlay:Hide()
    end
    if button.pushedOverlay then
        button.pushedOverlay:Hide()
    end
    if button.autoCastOverlay then
        button.autoCastOverlay:Hide()
    end
    if button.unusableOverlay then
        button.unusableOverlay:Hide()
    end
    if button.SetAttribute and not InCombatLockdown() then
        button:SetAttribute("type", nil)
        button:SetAttribute("type1", nil)
        button:SetAttribute("clickbutton", nil)
        button:SetAttribute("clickbutton1", nil)
    end
    button.activeSlot = nil
end

local function updateCooldown(button, actionSlot)
    if not button.cooldown then
        return
    end
    if not actionSlot or not GetActionCooldown then
        button.cooldown:Hide()
        return
    end

    local start, duration, enable = GetActionCooldown(actionSlot)
    if start and duration and duration > 0 and enable ~= 0 then
        if CooldownFrame_SetTimer then
            CooldownFrame_SetTimer(button.cooldown, start, duration, enable)
        elseif button.cooldown.SetCooldown then
            button.cooldown:SetCooldown(start, duration)
        end
        button.cooldown:Show()
    else
        button.cooldown:Hide()
    end
end

local function getActionAutocastState(actionSlot)
    if not actionSlot or not GetActionAutocast then
        return false, false
    end
    local ok, allowed, enabled = pcall(GetActionAutocast, actionSlot)
    if ok then
        return allowed and true or false, enabled and true or false
    end
    return false, false
end

local function getActionCheckedState(actionSlot, sourceButton)
    if sourceButton then
        if sourceButton.GetChecked and sourceButton:GetChecked() then
            return true
        end
        local checkedTexture = sourceButton.GetCheckedTexture and sourceButton:GetCheckedTexture()
        if checkedTexture and checkedTexture.IsShown and checkedTexture:IsShown() then
            return true
        end
    end
    if not actionSlot then
        return false
    end
    if IsCurrentAction and IsCurrentAction(actionSlot) then
        return true
    end
    if IsAutoRepeatAction and IsAutoRepeatAction(actionSlot) then
        return true
    end
    local _, autoCastEnabled = getActionAutocastState(actionSlot)
    return autoCastEnabled
end

local function updateButtonActionState(button)
    local actionInfo = button.activeSlot
    if not actionInfo then
        clearButtonActionState(button)
        return
    end

    local sourceButton = actionInfo.sourceButton
    local actionSlot = actionInfo.actionSlot
    local texture = getActionTexture(actionSlot) or getFrameIconTexture(actionInfo.buttonName)
    if texture then
        button.icon:SetTexture(texture)
    end

    local usable, noMana = true, false
    if actionSlot and IsUsableAction then
        usable, noMana = IsUsableAction(actionSlot)
    end
    if not usable then
        button.icon:SetVertexColor(noMana and 0.55 or 0.35, noMana and 0.2 or 0.35, noMana and 0.2 or 0.35, 1)
        button.unusableOverlay:SetVertexColor(noMana and 0.6 or 0, noMana and 0.05 or 0, noMana and 0.05 or 0, noMana and 0.28 or 0.36)
        button.unusableOverlay:Show()
    else
        button.icon:SetVertexColor(1, 1, 1, 1)
        button.unusableOverlay:Hide()
    end

    updateCooldown(button, actionSlot)

    local autoCastAllowed, autoCastEnabled = getActionAutocastState(actionSlot)
    if autoCastAllowed then
        button.autoCastOverlay:SetVertexColor(1, 0.82, 0.18, autoCastEnabled and 1 or 0.45)
        button.autoCastOverlay:Show()
    else
        button.autoCastOverlay:Hide()
    end

    if getActionCheckedState(actionSlot, sourceButton) then
        button.checkedOverlay:Show()
    else
        button.checkedOverlay:Hide()
    end

    local pushed = pressAnimations[actionInfo.slot] or (sourceButton and sourceButton.GetButtonState and sourceButton:GetButtonState() == "PUSHED")
    if pushed then
        button.pushedOverlay:Show()
    else
        button.pushedOverlay:Hide()
    end
end

local function updatePressAnimations()
    local now = GetTime and GetTime() or 0
    local hasActiveAnimation
    for slot, endTime in pairs(pressAnimations) do
        if endTime <= now then
            pressAnimations[slot] = nil
            local button = getButtonForBonusSlot(slot)
            if button then
                updateButtonActionState(button)
            end
        else
            hasActiveAnimation = true
        end
    end
    if not hasActiveAnimation and pressAnimationTimer then
        pressAnimationTimer:Hide()
    end
end

local function ensurePressAnimationTimer()
    if pressAnimationTimer then
        return pressAnimationTimer
    end
    pressAnimationTimer = CreateFrame("Frame")
    pressAnimationTimer:Hide()
    pressAnimationTimer:SetScript("OnUpdate", updatePressAnimations)
    return pressAnimationTimer
end

function ADDON.PlayBonusBarPress(slot)
    slot = tonumber(slot)
    if not slot then
        return
    end
    local button = getButtonForBonusSlot(slot)
    if not button then
        return
    end
    pressAnimations[slot] = (GetTime and GetTime() or 0) + PRESS_ANIMATION_DURATION
    button.pushedOverlay:Show()
    ensurePressAnimationTimer():Show()
end

local function updateVisibleButtonStates()
    if not frame or not frame:IsShown() then
        return
    end
    for _, button in ipairs(buttons) do
        if button:IsShown() and button.activeSlot then
            updateButtonActionState(button)
        end
    end
end

local function queueButtonStateUpdate()
    if ADDON.QueueBonusBarRefresh then
        ADDON.QueueBonusBarRefresh(0)
    end
end

local function hookSourceButton(actionInfo)
    local sourceButton = actionInfo and actionInfo.sourceButton
    if not sourceButton or hookedSourceButtons[sourceButton] or not hooksecurefunc then
        return
    end
    hookedSourceButtons[sourceButton] = true

    pcall(hooksecurefunc, sourceButton, "SetButtonState", queueButtonStateUpdate)
    pcall(hooksecurefunc, sourceButton, "SetChecked", queueButtonStateUpdate)
    pcall(hooksecurefunc, sourceButton, "Show", queueButtonStateUpdate)
    pcall(hooksecurefunc, sourceButton, "Hide", queueButtonStateUpdate)

    local icon = sourceButton.icon or sourceButton.Icon or _G[(actionInfo.buttonName or "") .. "Icon"]
    if icon then
        pcall(hooksecurefunc, icon, "SetTexture", queueButtonStateUpdate)
        pcall(hooksecurefunc, icon, "SetVertexColor", queueButtonStateUpdate)
    end

    local cooldown = sourceButton.cooldown or sourceButton.Cooldown or _G[(actionInfo.buttonName or "") .. "Cooldown"]
    if cooldown then
        pcall(hooksecurefunc, cooldown, "SetCooldown", queueButtonStateUpdate)
        pcall(hooksecurefunc, cooldown, "Show", queueButtonStateUpdate)
        pcall(hooksecurefunc, cooldown, "Hide", queueButtonStateUpdate)
    end
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
        button:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, active and 1 or 0.85)
        button.borderFrame:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, active and 1 or 0.85)
        button.borderFrame:Show()
        button.gloss:SetVertexColor(1, 0.92, 0.72, active and 0.08 or 0.04)
        button.gloss:Show()
    else
        button:SetBackdropColor(0, 0, 0, 0)
        button:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 0)
        button.borderFrame:Hide()
        button.gloss:Hide()
    end
end

local function showButtonTooltip(button)
    local actionInfo = button and button.activeSlot
    local settings = getSettings()
    if not actionInfo or not settings.showBonusBarTooltips or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if actionInfo.actionSlot and GameTooltip.SetAction then
        GameTooltip:SetAction(actionInfo.actionSlot)
    elseif actionInfo.sourceButton and actionInfo.sourceButton.GetName then
        GameTooltip:AddLine(actionInfo.sourceButton:GetName())
    end
    GameTooltip:Show()
end

local function updateButtonClickTarget(button, actionInfo, clickable)
    if not button or not button.SetAttribute or InCombatLockdown() then
        return
    end
    if clickable and actionInfo and actionInfo.sourceButton then
        button:SetAttribute("type", "click")
        button:SetAttribute("type1", "click")
        button:SetAttribute("clickbutton", actionInfo.sourceButton)
        button:SetAttribute("clickbutton1", actionInfo.sourceButton)
    else
        button:SetAttribute("type", nil)
        button:SetAttribute("type1", nil)
        button:SetAttribute("clickbutton", nil)
        button:SetAttribute("clickbutton1", nil)
    end
end

local function hideButtonTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function ADDON.IsBonusBarActive()
    return getBonusBarOffset() > 0
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
        button.bindingText:SetFont(STANDARD_TEXT_FONT, math.max(7, math.min(16, settings.bonusBarBindingFontSize or 10)), "OUTLINE")
    end

    if resizeGrip then
        resizeGrip:ClearAllPoints()
        resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    end
    if centerVerticalButton and centerHorizontalButton and hideAlignButton then
        centerHorizontalButton:ClearAllPoints()
        centerHorizontalButton:SetPoint("TOP", frame, "BOTTOM", -142, -6)
        centerVerticalButton:ClearAllPoints()
        centerVerticalButton:SetPoint("LEFT", centerHorizontalButton, "RIGHT", 8, 0)
        hideAlignButton:ClearAllPoints()
        hideAlignButton:SetPoint("LEFT", centerVerticalButton, "RIGHT", 8, 0)
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

    if not settings.showBonusBarTooltips and GameTooltip then
        GameTooltip:Hide()
    end

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
    if centerVerticalButton and centerHorizontalButton and hideAlignButton then
        if align then
            centerVerticalButton:Show()
            centerHorizontalButton:Show()
            hideAlignButton:Show()
        else
            centerVerticalButton:Hide()
            centerHorizontalButton:Hide()
            hideAlignButton:Hide()
        end
    end

    layoutButtons(active and #activeSlots or SLOT_COUNT)
    for i, button in ipairs(buttons) do
        local activeSlot = activeSlots[i]
        if activeSlot then
            setButtonFrameStyle(button, true, true)
            button.activeSlot = activeSlot
            hookSourceButton(activeSlot)
            updateButtonClickTarget(button, activeSlot, settings.clickBonusBarButtons)
            button:EnableMouse((settings.showBonusBarTooltips or settings.clickBonusBarButtons) and true or false)
            button.icon:SetTexture(activeSlot.texture)
            button.icon:SetVertexColor(1, 1, 1, 1)
            button.icon:SetAlpha(1)
            button.icon:Show()
            button.placeholderText:Hide()
            updateButtonActionState(button)
        elseif align then
            clearButtonActionState(button)
            button:EnableMouse(false)
            setButtonFrameStyle(button, true, false)
            button.icon:SetTexture("Interface\\Buttons\\WHITE8X8")
            button.icon:SetVertexColor(0.45, 0.55, 0.68, 0.28)
            button.icon:SetAlpha(0.28)
            button.icon:Show()
            button.placeholderText:SetText(tostring(i))
            button.placeholderText:Show()
        else
            clearButtonActionState(button)
            button:EnableMouse(false)
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

function ADDON.QueueBonusBarRefresh(delay)
    delay = type(delay) == "number" and delay or 0.05
    refreshBurstRemaining = math.max(refreshBurstRemaining or 0, REFRESH_BURST_COUNT)
    if refreshDelayRemaining then
        refreshDelayRemaining = math.min(refreshDelayRemaining, delay)
    else
        refreshDelayRemaining = delay
    end
    if not refreshTimer then
        refreshTimer = CreateFrame("Frame")
        refreshTimer:Hide()
        refreshTimer:SetScript("OnUpdate", function(self, elapsed)
            refreshDelayRemaining = (refreshDelayRemaining or 0) - (elapsed or 0)
            if refreshDelayRemaining > 0 then
                return
            end
            refreshDelayRemaining = nil
            ADDON.RefreshBonusBar()
            if refreshBurstRemaining and refreshBurstRemaining > 0 then
                refreshBurstRemaining = refreshBurstRemaining - 1
                refreshDelayRemaining = REFRESH_BURST_DELAY
                return
            end
            refreshBurstRemaining = nil
            self:Hide()
        end)
    end
    refreshTimer:Show()
end

local function createButton(parent, index)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    button:EnableMouse(false)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    setBackdrop(button, 0.04, 0.048, 0.06, 0.65)
    button:SetScript("OnEnter", showButtonTooltip)
    button:SetScript("OnLeave", hideButtonTooltip)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.unusableOverlay = button:CreateTexture(nil, "ARTWORK")
    button.unusableOverlay:SetAllPoints(button.icon)
    button.unusableOverlay:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.unusableOverlay:Hide()

    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.cooldown:SetFrameLevel(button:GetFrameLevel() + 2)
    button.cooldown:Hide()

    button.checkedOverlay = button:CreateTexture(nil, "OVERLAY")
    button.checkedOverlay:SetAllPoints(button.icon)
    button.checkedOverlay:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    button.checkedOverlay:SetBlendMode("ADD")
    button.checkedOverlay:SetVertexColor(1, 0.82, 0.2, 0.75)
    button.checkedOverlay:Hide()

    button.pushedOverlay = button:CreateTexture(nil, "OVERLAY")
    button.pushedOverlay:SetAllPoints(button.icon)
    button.pushedOverlay:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    button.pushedOverlay:SetBlendMode("BLEND")
    button.pushedOverlay:Hide()

    button.autoCastOverlay = button:CreateTexture(nil, "OVERLAY")
    button.autoCastOverlay:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
    button.autoCastOverlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    button.autoCastOverlay:SetTexture("Interface\\Buttons\\UI-AutoCastableOverlay")
    button.autoCastOverlay:SetTexCoord(0.18, 0.82, 0.18, 0.82)
    button.autoCastOverlay:SetBlendMode("ADD")
    button.autoCastOverlay:Hide()

    button.borderFrame = CreateFrame("Frame", nil, button)
    button.borderFrame:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.borderFrame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button.borderFrame:SetFrameLevel(button:GetFrameLevel() + 3)
    button.borderFrame:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button.borderFrame:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
    button.borderFrame:Hide()

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
    button.bindingText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 5)
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

    hideAlignButton = CreateFrame("Button", nil, frame)
    hideAlignButton:SetWidth(128)
    hideAlignButton:SetHeight(22)
    styleControlButton(hideAlignButton)
    hideAlignButton.text = createText(hideAlignButton, 10)
    hideAlignButton.text:SetAllPoints(hideAlignButton)
    hideAlignButton.text:SetText("Ausrichten ausblenden")
    hideAlignButton:SetScript("OnClick", function()
        local settings = ADDON.GetSettings()
        settings.alignBonusBar = false
        savePlacement()
        if ADDON.RefreshSettings then
            ADDON.RefreshSettings()
        end
        if ADDON.RefreshEditorBindings then
            ADDON.RefreshEditorBindings()
        end
        ADDON.RefreshBonusBar()
    end)
    hideAlignButton:Hide()

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
    ADDON.QueueBonusBarRefresh()
end)
DudesUtils.EventHandler.Add("PLAYER_ENTERING_WORLD", function()
    ADDON.CreateBonusBar()
    ADDON.QueueBonusBarRefresh()
end)
DudesUtils.EventHandler.Add("UPDATE_BONUS_ACTIONBAR", ADDON.QueueBonusBarRefresh)
DudesUtils.EventHandler.Add("UPDATE_POSSESS_BAR", ADDON.QueueBonusBarRefresh)
DudesUtils.EventHandler.Add("UNIT_ENTERED_VEHICLE", ADDON.QueueBonusBarRefresh)
DudesUtils.EventHandler.Add("UNIT_EXITED_VEHICLE", ADDON.QueueBonusBarRefresh)
DudesUtils.EventHandler.Add("ACTIONBAR_PAGE_CHANGED", ADDON.QueueBonusBarRefresh)
DudesUtils.EventHandler.Add("ACTIONBAR_SLOT_CHANGED", ADDON.QueueBonusBarRefresh)
DudesUtils.EventHandler.Add("ACTIONBAR_UPDATE_COOLDOWN", updateVisibleButtonStates)
DudesUtils.EventHandler.Add("ACTIONBAR_UPDATE_USABLE", updateVisibleButtonStates)
DudesUtils.EventHandler.Add("ACTIONBAR_UPDATE_STATE", updateVisibleButtonStates)
DudesUtils.EventHandler.Add("UNIT_PET", ADDON.QueueBonusBarRefresh)
DudesUtils.EventHandler.Add("PET_BAR_UPDATE", ADDON.QueueBonusBarRefresh)
DudesUtils.EventHandler.Add("PET_BAR_UPDATE_USABLE", ADDON.QueueBonusBarRefresh)
DudesUtils.EventHandler.Add("PET_BAR_UPDATE_COOLDOWN", updateVisibleButtonStates)
DudesUtils.EventHandler.Add("SPELL_UPDATE_COOLDOWN", updateVisibleButtonStates)
DudesUtils.EventHandler.Add("SPELL_UPDATE_USABLE", updateVisibleButtonStates)
DudesUtils.EventHandler.Add("START_AUTOREPEAT_SPELL", updateVisibleButtonStates)
DudesUtils.EventHandler.Add("STOP_AUTOREPEAT_SPELL", updateVisibleButtonStates)
DudesUtils.EventHandler.Add("PLAYER_CONTROL_LOST", ADDON.QueueBonusBarRefresh)
DudesUtils.EventHandler.Add("PLAYER_CONTROL_GAINED", ADDON.QueueBonusBarRefresh)
