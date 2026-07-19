local ADDON = DudesFlexBindings

local optionsPanel
local minimapButton
local layoutRows = {}
local layoutMenu
local importLayoutDialog
local exportLayoutDialog
local positionMinimapButton
local bonusAnchorSelectorPopup
local bonusGrowthSelectorPopup
local BORDER_R, BORDER_G, BORDER_B = 0.32, 0.38, 0.46
local HOVER_BORDER_R, HOVER_BORDER_G, HOVER_BORDER_B = 0.72, 0.86, 1
local BONUS_ANCHOR_OPTIONS = {
    { value = "topLeft", text = "Oben links" },
    { value = "top", text = "Oben" },
    { value = "topRight", text = "Oben rechts" },
    { value = "left", text = "Links" },
    { value = "center", text = "Zentriert" },
    { value = "right", text = "Rechts" },
    { value = "bottomLeft", text = "Unten links" },
    { value = "bottom", text = "Unten" },
    { value = "bottomRight", text = "Unten rechts" },
}
local BONUS_GROWTH_OPTIONS = {
    { value = "right", text = "Nach rechts" },
    { value = "down", text = "Nach unten" },
    { value = "left", text = "Nach links" },
    { value = "up", text = "Nach oben" },
}

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end
    return value
end

local function createText(parent, size)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetFont(STANDARD_TEXT_FONT, size or 11)
    text:SetJustifyH("LEFT")
    return text
end

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

local function addBorderHover(frame)
    if not frame or not frame.HookScript then
        return
    end
    frame:HookScript("OnEnter", function(self)
        self:SetBackdropBorderColor(HOVER_BORDER_R, HOVER_BORDER_G, HOVER_BORDER_B, 1)
    end)
    frame:HookScript("OnLeave", function(self)
        self:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
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
    setBackdrop(button, 0.055, 0.065, 0.08, 1)
    addBorderHover(button)
    if button:GetFontString() then
        button:GetFontString():SetTextColor(0.86, 0.92, 1)
    end
end

local function getAngleFromDelta(y, x)
    local atan2 = math.atan2 or _G.atan2
    if atan2 then
        return math.deg(atan2(y, x))
    end
    if x == 0 then
        return y >= 0 and 90 or -90
    end

    local angle = math.deg(math.atan(y / x))
    if x < 0 then
        angle = angle + 180
    end
    return angle
end

local function refreshMinimapButton()
    if not minimapButton then
        return
    end

    if ADDON.GetSyncedSetting("showMinimapButton") then
        positionMinimapButton()
        minimapButton:Show()
    else
        minimapButton:Hide()
    end
end

positionMinimapButton = function()
    if not minimapButton or not Minimap then
        return
    end

    local settings = ADDON.GetSettings()
    local angle = settings.minimapAngle or 225
    local radians = math.rad(angle)
    local radius = (Minimap:GetWidth() or 140) / 2 + 10
    local x = math.cos(radians) * radius
    local y = math.sin(radians) * radius

    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function updateMinimapButtonFromCursor()
    if not minimapButton or not Minimap then
        return
    end

    local scale = Minimap:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    local centerX, centerY = Minimap:GetCenter()
    if not cursorX or not cursorY or not centerX or not centerY then
        return
    end

    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local angle = getAngleFromDelta(cursorY - centerY, cursorX - centerX)
    ADDON.GetSettings().minimapAngle = angle
    positionMinimapButton()
end

local function layoutSettingsRows()
    if not optionsPanel or not optionsPanel.layoutRows then
        return
    end

    local panelWidth = optionsPanel:GetWidth() or 520
    local rowWidth = clamp(panelWidth - 48, 260, 520)
    local loadWidth = 64
    local menuWidth = 34
    local buttonGap = 6
    local textWidth = math.max(120, rowWidth - loadWidth - menuWidth - buttonGap * 2 - 12)
    local loadX = textWidth + 8

    for _, row in ipairs(optionsPanel.layoutRows) do
        row:SetWidth(rowWidth)
        row.name:SetWidth(textWidth)
        row.meta:SetWidth(textWidth)

        row.load:ClearAllPoints()
        row.load:SetWidth(loadWidth)
        row.load:SetPoint("TOPLEFT", row, "TOPLEFT", loadX, -5)

        row.menu:ClearAllPoints()
        row.menu:SetWidth(menuWidth)
        row.menu:SetPoint("LEFT", row.load, "RIGHT", buttonGap, 0)
    end
end

local function layoutOptionsPanel()
    if not optionsPanel or not optionsPanel.scrollFrame or not optionsPanel.content then
        return
    end

    local width = optionsPanel:GetWidth() or 620
    local height = optionsPanel:GetHeight() or 560
    local contentHeight = math.max(980, height + 420)
    optionsPanel.scrollFrame:ClearAllPoints()
    optionsPanel.scrollFrame:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 0, -4)
    optionsPanel.scrollFrame:SetPoint("BOTTOMRIGHT", optionsPanel, "BOTTOMRIGHT", -28, 4)
    optionsPanel.content:SetWidth(math.max(520, width - 34))
    optionsPanel.content:SetHeight(contentHeight)
    layoutSettingsRows()
end

local function refreshLayoutRows()
    if not optionsPanel or not optionsPanel.layoutRows then
        return
    end

    layoutSettingsRows()

    local profiles = ADDON.GetLayoutProfiles and ADDON.GetLayoutProfiles() or {}
    local lastVisibleRow
    for i, row in ipairs(optionsPanel.layoutRows) do
        local profile = profiles[i]
        row.profileId = profile and profile.id or nil
        if profile then
            row.name:SetText(profile.name or "")
            row.meta:SetText((profile.createdAt or "-") .. "  " .. (profile.characterName or "-") .. "  " .. (profile.className or "-") .. "  " .. (profile.specText or "-"))
            if profile.system then
                row.menu:Hide()
            else
                row.menu:Show()
            end
            row:Show()
            lastVisibleRow = row
        else
            row:Hide()
        end
    end
    if optionsPanel.bonusTitle then
        optionsPanel.bonusTitle:ClearAllPoints()
        if lastVisibleRow then
            optionsPanel.bonusTitle:SetPoint("TOPLEFT", lastVisibleRow, "BOTTOMLEFT", 0, -18)
        elseif optionsPanel.saveLayoutButton then
            optionsPanel.bonusTitle:SetPoint("TOPLEFT", optionsPanel.saveLayoutButton, "BOTTOMLEFT", 0, -18)
        end
    end
end

local function setFrameEnabled(frame, enabled)
    if not frame then
        return
    end
    if enabled then
        frame:Enable()
        frame:SetAlpha(1)
    else
        frame:Disable()
        frame:SetAlpha(0.45)
    end
end

local function showFrame(frame, visible)
    if not frame then
        return
    end
    if visible then
        frame:Show()
    else
        frame:Hide()
    end
end

local function refreshBonusBarSettingsControls()
    if not optionsPanel then
        return
    end
    local settings = ADDON.GetSettings()
    local bonusSettings = ADDON.GetBonusBarSettings()
    local enabled = bonusSettings.showBonusBar and true or false

    if optionsPanel.bonusBarCheckbox then
        optionsPanel.bonusBarCheckbox:SetChecked(enabled)
    end
    if optionsPanel.alignBonusBarCheckbox then
        optionsPanel.alignBonusBarCheckbox:SetChecked(bonusSettings.alignBonusBar and true or false)
        setFrameEnabled(optionsPanel.alignBonusBarCheckbox, enabled)
        showFrame(optionsPanel.alignBonusBarCheckbox, enabled)
    end
    if optionsPanel.bonusBarAnchorSelector then
        optionsPanel.bonusBarAnchorSelector.refresh()
        setFrameEnabled(optionsPanel.bonusBarAnchorSelector, enabled)
        optionsPanel.bonusBarAnchorSelector.text:SetAlpha(enabled and 1 or 0.45)
        showFrame(optionsPanel.bonusBarAnchorSelector, enabled)
        showFrame(optionsPanel.bonusBarAnchorSelector.text, enabled)
    end
    if optionsPanel.bonusBarGrowthSelector then
        optionsPanel.bonusBarGrowthSelector.refresh()
        setFrameEnabled(optionsPanel.bonusBarGrowthSelector, enabled)
        optionsPanel.bonusBarGrowthSelector.text:SetAlpha(enabled and 1 or 0.45)
        showFrame(optionsPanel.bonusBarGrowthSelector, enabled)
        showFrame(optionsPanel.bonusBarGrowthSelector.text, enabled)
    end
    if optionsPanel.showBonusBarBindingsCheckbox then
        optionsPanel.showBonusBarBindingsCheckbox:SetChecked(bonusSettings.showBonusBarBindings and true or false)
        setFrameEnabled(optionsPanel.showBonusBarBindingsCheckbox, enabled)
        showFrame(optionsPanel.showBonusBarBindingsCheckbox, enabled)
    end
    if optionsPanel.showBonusBarTooltipsCheckbox then
        optionsPanel.showBonusBarTooltipsCheckbox:SetChecked(bonusSettings.showBonusBarTooltips and true or false)
        setFrameEnabled(optionsPanel.showBonusBarTooltipsCheckbox, enabled)
        showFrame(optionsPanel.showBonusBarTooltipsCheckbox, enabled)
    end
    if optionsPanel.clickBonusBarButtonsCheckbox then
        optionsPanel.clickBonusBarButtonsCheckbox:SetChecked(bonusSettings.clickBonusBarButtons and true or false)
        setFrameEnabled(optionsPanel.clickBonusBarButtonsCheckbox, enabled)
        showFrame(optionsPanel.clickBonusBarButtonsCheckbox, enabled)
    end
    if optionsPanel.resetBonusBarPositionButton then
        setFrameEnabled(optionsPanel.resetBonusBarPositionButton, enabled)
        showFrame(optionsPanel.resetBonusBarPositionButton, enabled)
    end
    if optionsPanel.bonusBarBindingSizeControl then
        optionsPanel.bonusBarBindingSizeControl.refresh()
        setFrameEnabled(optionsPanel.bonusBarBindingSizeControl.decrease, enabled and bonusSettings.showBonusBarBindings)
        setFrameEnabled(optionsPanel.bonusBarBindingSizeControl.increase, enabled and bonusSettings.showBonusBarBindings)
        optionsPanel.bonusBarBindingSizeControl.text:SetAlpha(enabled and bonusSettings.showBonusBarBindings and 1 or 0.45)
        optionsPanel.bonusBarBindingSizeControl.value:SetAlpha(enabled and bonusSettings.showBonusBarBindings and 1 or 0.45)
        showFrame(optionsPanel.bonusBarBindingSizeControl, enabled and bonusSettings.showBonusBarBindings)
        showFrame(optionsPanel.bonusBarBindingSizeControl.text, enabled and bonusSettings.showBonusBarBindings)
    end
    if optionsPanel.characterSpecificSettingsCheckbox and ADDON.IsCharacterSpecificSettingsEnabled then
        optionsPanel.characterSpecificSettingsCheckbox:SetChecked(ADDON.IsCharacterSpecificSettingsEnabled())
    end
    if optionsPanel.triggerOnKeyDownCheckbox then
        optionsPanel.triggerOnKeyDownCheckbox:SetChecked(ADDON.GetSyncedSetting("triggerOnKeyDown") and true or false)
    end
end

local function createCheckbox(parent, anchor, yOffset, label, getter, setter, afterClick)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetWidth(22)
    checkbox:SetHeight(22)
    checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    styleButton(checkbox)
    checkbox.text = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 2, 1)
    checkbox.text:SetText(label)
    checkbox:SetScript("OnClick", function(self)
        if setter(self:GetChecked() and true or false) == false then
            checkbox.refresh()
            return
        end
        refreshBonusBarSettingsControls()
        if afterClick then
            afterClick(self)
        end
        if ADDON.RefreshBonusBar then
            ADDON.RefreshBonusBar()
        end
    end)
    checkbox.refresh = function()
        checkbox:SetChecked(getter() and true or false)
    end
    return checkbox
end

local function getBonusAnchorText(value)
    for _, option in ipairs(BONUS_ANCHOR_OPTIONS) do
        if option.value == value then
            return option.text
        end
    end
    return BONUS_ANCHOR_OPTIONS[1].text
end

local function getBonusGrowthText(value)
    for _, option in ipairs(BONUS_GROWTH_OPTIONS) do
        if option.value == value then
            return option.text
        end
    end
    return BONUS_GROWTH_OPTIONS[1].text
end

local function showBonusAnchorSelector(selector)
    if not selector or not selector:IsEnabled() then
        return
    end
    if bonusGrowthSelectorPopup then
        bonusGrowthSelectorPopup:Hide()
    end
    if not bonusAnchorSelectorPopup then
        bonusAnchorSelectorPopup = CreateFrame("Frame", "DudesFlexBindingsBonusAnchorSelectorPopup", UIParent)
        bonusAnchorSelectorPopup:SetWidth(134)
        bonusAnchorSelectorPopup:SetHeight(#BONUS_ANCHOR_OPTIONS * 24 + 10)
        bonusAnchorSelectorPopup:SetFrameStrata("TOOLTIP")
        bonusAnchorSelectorPopup:SetFrameLevel(100)
        setBackdrop(bonusAnchorSelectorPopup, 0.045, 0.052, 0.065, 1)
        bonusAnchorSelectorPopup.buttons = {}
        for i, option in ipairs(BONUS_ANCHOR_OPTIONS) do
            local button = CreateFrame("Button", nil, bonusAnchorSelectorPopup)
            button:SetWidth(118)
            button:SetHeight(22)
            button:SetPoint("TOPLEFT", bonusAnchorSelectorPopup, "TOPLEFT", 8, -6 - (i - 1) * 24)
            button.value = option.value
            styleButton(button)
            button.text = createText(button, 11)
            button.text:SetAllPoints(button)
            button.text:SetJustifyH("CENTER")
            button.text:SetText(option.text)
            button:SetScript("OnClick", function(self)
                local owner = bonusAnchorSelectorPopup.owner
                if owner then
                    ADDON.GetBonusBarSettings().bonusBarAnchor = self.value
                    owner.refresh()
                    refreshBonusBarSettingsControls()
                    if ADDON.RefreshEditorBindings then
                        ADDON.RefreshEditorBindings()
                    end
                    if ADDON.RefreshBonusBar then
                        ADDON.RefreshBonusBar()
                    end
                end
                bonusAnchorSelectorPopup:Hide()
            end)
            bonusAnchorSelectorPopup.buttons[i] = button
        end
        bonusAnchorSelectorPopup:Hide()
    end

    if bonusAnchorSelectorPopup:IsShown() and bonusAnchorSelectorPopup.owner == selector then
        bonusAnchorSelectorPopup:Hide()
        return
    end

    local value = ADDON.GetBonusBarSettings().bonusBarAnchor or "topLeft"
    for _, button in ipairs(bonusAnchorSelectorPopup.buttons or {}) do
        if button.value == value then
            button:SetBackdropBorderColor(1, 0.82, 0.1, 1)
        else
            button:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
        end
    end
    bonusAnchorSelectorPopup.owner = selector
    bonusAnchorSelectorPopup:ClearAllPoints()
    bonusAnchorSelectorPopup:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -4)
    bonusAnchorSelectorPopup:Show()
end

local function showBonusGrowthSelector(selector)
    if not selector or not selector:IsEnabled() then
        return
    end
    if bonusAnchorSelectorPopup then
        bonusAnchorSelectorPopup:Hide()
    end
    if not bonusGrowthSelectorPopup then
        bonusGrowthSelectorPopup = CreateFrame("Frame", "DudesFlexBindingsBonusGrowthSelectorPopup", UIParent)
        bonusGrowthSelectorPopup:SetWidth(118)
        bonusGrowthSelectorPopup:SetHeight(#BONUS_GROWTH_OPTIONS * 24 + 10)
        bonusGrowthSelectorPopup:SetFrameStrata("TOOLTIP")
        bonusGrowthSelectorPopup:SetFrameLevel(100)
        setBackdrop(bonusGrowthSelectorPopup, 0.045, 0.052, 0.065, 1)
        bonusGrowthSelectorPopup.buttons = {}
        for i, option in ipairs(BONUS_GROWTH_OPTIONS) do
            local button = CreateFrame("Button", nil, bonusGrowthSelectorPopup)
            button:SetWidth(102)
            button:SetHeight(22)
            button:SetPoint("TOPLEFT", bonusGrowthSelectorPopup, "TOPLEFT", 8, -6 - (i - 1) * 24)
            button.value = option.value
            styleButton(button)
            button.text = createText(button, 11)
            button.text:SetAllPoints(button)
            button.text:SetJustifyH("CENTER")
            button.text:SetText(option.text)
            button:SetScript("OnClick", function(self)
                local owner = bonusGrowthSelectorPopup.owner
                if owner then
                    ADDON.GetBonusBarSettings().bonusBarGrowthDirection = self.value
                    owner.refresh()
                    refreshBonusBarSettingsControls()
                    if ADDON.RefreshEditorBindings then
                        ADDON.RefreshEditorBindings()
                    end
                    if ADDON.RefreshBonusBar then
                        ADDON.RefreshBonusBar()
                    end
                end
                bonusGrowthSelectorPopup:Hide()
            end)
            bonusGrowthSelectorPopup.buttons[i] = button
        end
        bonusGrowthSelectorPopup:Hide()
    end

    if bonusGrowthSelectorPopup:IsShown() and bonusGrowthSelectorPopup.owner == selector then
        bonusGrowthSelectorPopup:Hide()
        return
    end

    local value = ADDON.GetBonusBarSettings().bonusBarGrowthDirection or "right"
    for _, button in ipairs(bonusGrowthSelectorPopup.buttons or {}) do
        if button.value == value then
            button:SetBackdropBorderColor(1, 0.82, 0.1, 1)
        else
            button:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
        end
    end
    bonusGrowthSelectorPopup.owner = selector
    bonusGrowthSelectorPopup:ClearAllPoints()
    bonusGrowthSelectorPopup:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -4)
    bonusGrowthSelectorPopup:Show()
end

local function createBonusAnchorSelector(parent, anchor, yOffset)
    local selector = CreateFrame("Button", nil, parent)
    selector:SetWidth(118)
    selector:SetHeight(24)
    selector:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    styleButton(selector)
    selector.valueText = createText(selector, 11)
    selector.valueText:SetAllPoints(selector)
    selector.valueText:SetJustifyH("CENTER")
    selector.text = selector:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selector.text:SetPoint("LEFT", selector, "RIGHT", 8, 1)
    selector.text:SetText("Bonusleisten Anker")
    selector:SetScript("OnClick", function(self)
        showBonusAnchorSelector(self)
    end)
    selector.refresh = function()
        selector.valueText:SetText(getBonusAnchorText(ADDON.GetBonusBarSettings().bonusBarAnchor or "topLeft"))
    end
    selector.refresh()
    return selector
end

local function createBonusGrowthSelector(parent, anchor, yOffset)
    local selector = CreateFrame("Button", nil, parent)
    selector:SetWidth(118)
    selector:SetHeight(24)
    selector:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    styleButton(selector)
    selector.valueText = createText(selector, 11)
    selector.valueText:SetAllPoints(selector)
    selector.valueText:SetJustifyH("CENTER")
    selector.text = selector:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selector.text:SetPoint("LEFT", selector, "RIGHT", 8, 1)
    selector.text:SetText("Bonusleisten Wachstum")
    selector:SetScript("OnClick", function(self)
        showBonusGrowthSelector(self)
    end)
    selector.refresh = function()
        selector.valueText:SetText(getBonusGrowthText(ADDON.GetBonusBarSettings().bonusBarGrowthDirection or "right"))
    end
    selector.refresh()
    return selector
end

local function createBindingSizeControl(parent, anchor, yOffset)
    local control = CreateFrame("Frame", nil, parent)
    control:SetWidth(118)
    control:SetHeight(24)
    control:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    control.text = createText(parent, 11)
    control.text:SetPoint("LEFT", control, "RIGHT", 8, 1)
    control.text:SetText("Textgröße")
    control.value = createText(control, 11)
    control.value:SetPoint("CENTER", control, "CENTER", 0, 1)
    control.value:SetWidth(36)
    control.value:SetJustifyH("CENTER")

    control.decrease = CreateFrame("Button", nil, control)
    control.decrease:SetWidth(24)
    control.decrease:SetHeight(22)
    control.decrease:SetPoint("LEFT", control, "LEFT", 0, 0)
    styleButton(control.decrease)
    control.decrease.label = createText(control.decrease, 12)
    control.decrease.label:SetAllPoints(control.decrease)
    control.decrease.label:SetJustifyH("CENTER")
    control.decrease.label:SetText("-")

    control.increase = CreateFrame("Button", nil, control)
    control.increase:SetWidth(24)
    control.increase:SetHeight(22)
    control.increase:SetPoint("RIGHT", control, "RIGHT", 0, 0)
    styleButton(control.increase)
    control.increase.label = createText(control.increase, 12)
    control.increase.label:SetAllPoints(control.increase)
    control.increase.label:SetJustifyH("CENTER")
    control.increase.label:SetText("+")

    local function adjust(delta)
        local settings = ADDON.GetBonusBarSettings()
        settings.bonusBarBindingFontSize = math.max(7, math.min(16, (settings.bonusBarBindingFontSize or 10) + delta))
        control.refresh()
        if ADDON.RefreshBonusBar then
            ADDON.RefreshBonusBar()
        end
        if ADDON.RefreshEditorBindings then
            ADDON.RefreshEditorBindings()
        end
    end
    control.decrease:SetScript("OnClick", function()
        adjust(-1)
    end)
    control.increase:SetScript("OnClick", function()
        adjust(1)
    end)
    control.refresh = function()
        control.value:SetText(tostring(ADDON.GetBonusBarSettings().bonusBarBindingFontSize or 10))
    end
    control.refresh()
    return control
end

local function showDisableCharacterBindingsDialog(onAccept, onCancel)
    DudesUtils.Dialog.Show({
        title = "Charakterspezifische Einstellungen deaktivieren?",
        text = "Danach werden die gemeinsamen Interface-Belegungen, Bonusleisten-Einstellungen, Minimap-Sichtbarkeit und das gemeinsame Auslöseverhalten verwendet.",
        acceptText = "Deaktivieren",
        cancelText = "Abbrechen",
        onAccept = function()
            if onAccept then
                onAccept()
            end
        end,
        onCancel = function()
            if onCancel then
                onCancel()
            end
        end,
    })
end

local function saveLayoutFromDialog(name)
    if ADDON.SaveAppliedLayoutProfile and ADDON.SaveAppliedLayoutProfile(name) then
        refreshLayoutRows()
        return true
    end
    return false, "Layout-Name muss eindeutig sein"
end

local function showSaveLayoutDialog()
    DudesUtils.Dialog.Show({
        title = "Layout speichern",
        text = "Layout-Name",
        acceptText = "Speichern",
        cancelText = "Abbrechen",
        hasEditBox = true,
        maxLetters = 64,
        onAccept = function(name)
            return saveLayoutFromDialog(name)
        end,
    })
end

local function showLoadLayoutDialog(profileId, profileName)
    if not profileId then
        return
    end

    local loadLayoutText = "Aktuelle Makros, Interface- und Bonusleisten-Belegungen des aktiven Specs werden ersetzt."
    local showAccountWarning = ADDON.IsCharacterBindingSetEnabled and not ADDON.IsCharacterBindingSetEnabled()
    if showAccountWarning then
        loadLayoutText = loadLayoutText .. "\n\n|cffff3333Warnung: Charakterspezifische Einstellungen sind nicht aktiv. Dadurch werden auch die gemeinsamen Interface-Belegungen für andere Charaktere geändert.|r"
    end

    DudesUtils.Dialog.Show({
        title = string.format("Layout '%s' laden?", tostring(profileName or "")),
        text = loadLayoutText,
        width = 560,
        acceptText = "Laden",
        cancelText = "Abbrechen",
        data = { profileId = profileId },
        onAccept = function(_, data)
            if data.profileId and ADDON.LoadLayoutProfile then
                ADDON.LoadLayoutProfile(data.profileId)
                refreshLayoutRows()
            end
        end,
    })
end

local function showDeleteLayoutDialog(profileId, profileName)
    if not profileId then
        return
    end

    DudesUtils.Dialog.Show({
        title = string.format("Layout '%s' löschen?", tostring(profileName or "")),
        text = "Dieses gespeicherte Layout wird dauerhaft entfernt.",
        acceptText = "Löschen",
        cancelText = "Abbrechen",
        data = { profileId = profileId },
        onAccept = function(_, data)
            if data.profileId and ADDON.DeleteLayoutProfile then
                ADDON.DeleteLayoutProfile(data.profileId)
                refreshLayoutRows()
            end
        end,
    })
end

local function createDialogFrame(name, titleText, width, height)
    local dialog = CreateFrame("Frame", name, UIParent)
    dialog:SetWidth(width)
    dialog:SetHeight(height)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dialog:SetFrameStrata("TOOLTIP")
    dialog:SetFrameLevel(120)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    setBackdrop(dialog, 0.045, 0.052, 0.065, 1)

    dialog.title = createText(dialog, 14)
    dialog.title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -12)
    dialog.title:SetText(titleText)
    dialog.title:SetTextColor(1, 1, 1)

    dialog.dragHandle = CreateFrame("Frame", nil, dialog)
    dialog.dragHandle:SetPoint("TOPLEFT", dialog, "TOPLEFT", 0, 0)
    dialog.dragHandle:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -36, 0)
    dialog.dragHandle:SetHeight(38)
    dialog.dragHandle:EnableMouse(true)
    dialog.dragHandle:SetScript("OnMouseDown", function()
        dialog:StartMoving()
    end)
    dialog.dragHandle:SetScript("OnMouseUp", function()
        dialog:StopMovingOrSizing()
    end)
    dialog:SetScript("OnMouseDown", function(self)
        self:StartMoving()
    end)
    dialog:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
    end)

    dialog.close = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.close:SetWidth(24)
    dialog.close:SetHeight(22)
    dialog.close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -8, -8)
    dialog.close:SetText("X")
    styleButton(dialog.close)
    dialog.close:SetScript("OnClick", function()
        dialog:Hide()
    end)

    dialog:Hide()
    return dialog
end

local function makeFrameSolid(frame, r, g, b)
    if not frame then
        return
    end
    if not frame.solidBackground then
        frame.solidBackground = frame:CreateTexture(nil, "BACKGROUND")
        frame.solidBackground:SetAllPoints(frame)
        frame.solidBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    frame.solidBackground:SetVertexColor(r, g, b, 1)
end

local function createDialogEditBox(parent, width, height, multiLine)
    local editBox = CreateFrame("EditBox", nil, parent)
    editBox:SetWidth(width)
    editBox:SetHeight(height)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextInsets(6, 6, 0, 0)
    if multiLine then
        editBox:SetMultiLine(true)
    end
    setBackdrop(editBox, 0.075, 0.086, 0.108, 1)
    addBorderHover(editBox)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    return editBox
end

local function createDialogScrollTextBox(parent, name, width, height, editable)
    local textBox = CreateFrame("Frame", nil, parent)
    textBox:SetWidth(width)
    textBox:SetHeight(height)
    setBackdrop(textBox, 0.075, 0.086, 0.108, 1)
    makeFrameSolid(textBox, 0.075, 0.086, 0.108)

    local scroll = CreateFrame("ScrollFrame", name, textBox, "UIPanelScrollFrameTemplate")
    scroll:SetWidth(width - 34)
    scroll:SetHeight(height - 12)
    scroll:SetPoint("TOPLEFT", textBox, "TOPLEFT", 6, -6)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetWidth(width - 34)
    editBox:SetHeight(height - 12)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextInsets(0, 0, 0, 0)
    editBox:SetMultiLine(true)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    scroll:SetScrollChild(editBox)

    textBox.scroll = scroll
    textBox.editBox = editBox
    return textBox, scroll, editBox
end

local function selectExportText()
    if not exportLayoutDialog or not exportLayoutDialog.editBox then
        return
    end
    exportLayoutDialog.editBox:SetFocus()
    exportLayoutDialog.editBox:HighlightText()
end

local function showDialogError(dialog, message)
    if not dialog or not dialog.errorText then
        return
    end
    dialog.errorText:SetText(message or "")
    dialog.errorText:Show()
end

local function hideDialogError(dialog)
    if dialog and dialog.errorText then
        dialog.errorText:Hide()
    end
end

local function importLayoutFromDialog()
    if not importLayoutDialog then
        return
    end

    local name = importLayoutDialog.nameEditBox:GetText() or ""
    local importString = importLayoutDialog.importEditBox:GetText() or ""
    local ok, reason
    if ADDON.ImportLayoutProfile then
        ok, reason = ADDON.ImportLayoutProfile(name, importString)
    end
    if ok then
        importLayoutDialog:Hide()
        refreshLayoutRows()
        return
    end

    if reason == "import" then
        showDialogError(importLayoutDialog, "Import-String ist ungültig")
        importLayoutDialog.importEditBox:SetFocus()
        importLayoutDialog.importEditBox:HighlightText()
    else
        showDialogError(importLayoutDialog, "Layout-Name muss eindeutig sein")
        importLayoutDialog.nameEditBox:SetFocus()
        importLayoutDialog.nameEditBox:HighlightText()
    end
end

local function showImportLayoutDialog()
    if not importLayoutDialog then
        importLayoutDialog = createDialogFrame("DudesFlexBindingsImportLayoutDialog", "Layout importieren", 520, 310)

        importLayoutDialog.nameLabel = createText(importLayoutDialog, 11)
        importLayoutDialog.nameLabel:SetPoint("TOPLEFT", importLayoutDialog, "TOPLEFT", 16, -48)
        importLayoutDialog.nameLabel:SetText("Name")

        importLayoutDialog.nameEditBox = createDialogEditBox(importLayoutDialog, 488, 22, false)
        importLayoutDialog.nameEditBox:SetPoint("TOPLEFT", importLayoutDialog.nameLabel, "BOTTOMLEFT", 0, -6)

        importLayoutDialog.importLabel = createText(importLayoutDialog, 11)
        importLayoutDialog.importLabel:SetPoint("TOPLEFT", importLayoutDialog.nameEditBox, "BOTTOMLEFT", 0, -14)
        importLayoutDialog.importLabel:SetText("Import-String")

        importLayoutDialog.importTextBox, importLayoutDialog.importScroll, importLayoutDialog.importEditBox = createDialogScrollTextBox(importLayoutDialog, "DudesFlexBindingsImportLayoutScrollFrame", 488, 126, true)
        importLayoutDialog.importTextBox:SetPoint("TOPLEFT", importLayoutDialog.importLabel, "BOTTOMLEFT", 0, -6)

        importLayoutDialog.errorText = createText(importLayoutDialog, 10)
        importLayoutDialog.errorText:SetPoint("TOPLEFT", importLayoutDialog.importTextBox, "BOTTOMLEFT", 0, -8)
        importLayoutDialog.errorText:SetPoint("RIGHT", importLayoutDialog, "RIGHT", -16, 0)
        importLayoutDialog.errorText:SetTextColor(1, 0.25, 0.18)
        importLayoutDialog.errorText:Hide()

        importLayoutDialog.importButton = CreateFrame("Button", nil, importLayoutDialog, "UIPanelButtonTemplate")
        importLayoutDialog.importButton:SetWidth(110)
        importLayoutDialog.importButton:SetHeight(24)
        importLayoutDialog.importButton:SetPoint("BOTTOMRIGHT", importLayoutDialog, "BOTTOMRIGHT", -16, 16)
        importLayoutDialog.importButton:SetText("Importieren")
        styleButton(importLayoutDialog.importButton)
        importLayoutDialog.importButton:SetScript("OnClick", importLayoutFromDialog)

        importLayoutDialog.nameEditBox:SetScript("OnEnterPressed", importLayoutFromDialog)
    end

    hideDialogError(importLayoutDialog)
    importLayoutDialog.nameEditBox:SetText("")
    importLayoutDialog.importEditBox:SetText("")
    importLayoutDialog:Show()
    importLayoutDialog.nameEditBox:SetFocus()
end

local function showExportLayoutDialog(profileId, profileName)
    local exportString = ADDON.ExportLayoutProfile and ADDON.ExportLayoutProfile(profileId)
    if not exportString then
        return
    end

    if not exportLayoutDialog then
        exportLayoutDialog = createDialogFrame("DudesFlexBindingsExportLayoutDialog", "Layout exportieren", 540, 230)
        makeFrameSolid(exportLayoutDialog, 0.045, 0.052, 0.065)

        exportLayoutDialog.label = createText(exportLayoutDialog, 11)
        exportLayoutDialog.label:SetPoint("TOPLEFT", exportLayoutDialog, "TOPLEFT", 16, -48)
        exportLayoutDialog.label:SetText("Export-String")

        exportLayoutDialog.textBox, exportLayoutDialog.scroll, exportLayoutDialog.editBox = createDialogScrollTextBox(exportLayoutDialog, "DudesFlexBindingsExportLayoutScrollFrame", 508, 132, false)
        exportLayoutDialog.textBox:SetPoint("TOPLEFT", exportLayoutDialog.label, "BOTTOMLEFT", 0, -6)
        exportLayoutDialog.editBox:SetScript("OnEditFocusGained", selectExportText)
        exportLayoutDialog.editBox:SetScript("OnMouseDown", selectExportText)
        exportLayoutDialog.editBox:SetScript("OnMouseUp", selectExportText)
        exportLayoutDialog.editBox:SetScript("OnTextChanged", function(self)
            if exportLayoutDialog.suppressExportTextChanged then
                return
            end
            if (self:GetText() or "") ~= (exportLayoutDialog.exportString or "") then
                exportLayoutDialog.suppressExportTextChanged = true
                self:SetText(exportLayoutDialog.exportString or "")
                exportLayoutDialog.suppressExportTextChanged = nil
                selectExportText()
            end
        end)
    end

    exportLayoutDialog.title:SetText("Layout exportieren: " .. (profileName or ""))
    exportLayoutDialog.exportString = exportString
    exportLayoutDialog.suppressExportTextChanged = true
    exportLayoutDialog.editBox:SetText(exportString)
    exportLayoutDialog.suppressExportTextChanged = nil
    exportLayoutDialog:Show()
    selectExportText()
end

local function renameLayoutFromDialog(profileId, name)
    if profileId and ADDON.RenameLayoutProfile and ADDON.RenameLayoutProfile(profileId, name) then
        refreshLayoutRows()
        return true
    end
    return false, "Layout-Name muss eindeutig sein"
end

local function showRenameLayoutDialog(profileId, profileName)
    if not profileId then
        return
    end

    DudesUtils.Dialog.Show({
        title = "Layout umbenennen",
        text = "Neuer Layout-Name",
        acceptText = "Umbenennen",
        cancelText = "Abbrechen",
        hasEditBox = true,
        maxLetters = 64,
        inputText = profileName or "",
        data = { profileId = profileId },
        onAccept = function(name, data)
            return renameLayoutFromDialog(data.profileId, name)
        end,
    })
end

local function createLayoutMenuButton(parent, index, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(126)
    button:SetHeight(24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8 - (index - 1) * 26)
    styleButton(button)
    button.text = createText(button, 11)
    button.text:SetAllPoints(button)
    button.text:SetJustifyH("CENTER")
    button.text:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function showLayoutMenu(owner, profileId, profileName)
    if not owner or not profileId then
        return
    end

    if not layoutMenu then
        layoutMenu = CreateFrame("Frame", "DudesFlexBindingsLayoutMenu", UIParent)
        layoutMenu:SetWidth(142)
        layoutMenu:SetHeight(86)
        layoutMenu:SetFrameStrata("TOOLTIP")
        layoutMenu:SetFrameLevel(115)
        setBackdrop(layoutMenu, 0.045, 0.052, 0.065, 1)
        layoutMenu.exportButton = createLayoutMenuButton(layoutMenu, 1, "Exportieren", function()
            showExportLayoutDialog(layoutMenu.profileId, layoutMenu.profileName)
            layoutMenu:Hide()
        end)
        layoutMenu.renameButton = createLayoutMenuButton(layoutMenu, 2, "Umbenennen", function()
            showRenameLayoutDialog(layoutMenu.profileId, layoutMenu.profileName)
            layoutMenu:Hide()
        end)
        layoutMenu.deleteButton = createLayoutMenuButton(layoutMenu, 3, "Löschen", function()
            showDeleteLayoutDialog(layoutMenu.profileId, layoutMenu.profileName)
            layoutMenu:Hide()
        end)
        layoutMenu:Hide()
    end

    if layoutMenu:IsShown() and layoutMenu.owner == owner then
        layoutMenu:Hide()
        return
    end

    layoutMenu.owner = owner
    layoutMenu.profileId = profileId
    layoutMenu.profileName = profileName
    layoutMenu:ClearAllPoints()
    layoutMenu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", -104, -4)
    layoutMenu:Show()
end

local function createOptionsPanel()
    if optionsPanel then
        return optionsPanel
    end

    optionsPanel = CreateFrame("Frame", "DudesFlexBindingsOptionsPanel", UIParent)
    optionsPanel.name = "DudesFlexBindings"

    optionsPanel.scrollFrame = CreateFrame("ScrollFrame", "DudesFlexBindingsOptionsScrollFrame", optionsPanel, "UIPanelScrollFrameTemplate")
    optionsPanel.content = CreateFrame("Frame", "DudesFlexBindingsOptionsContent", optionsPanel.scrollFrame)
    optionsPanel.scrollFrame:SetScrollChild(optionsPanel.content)
    optionsPanel.scrollFrame:EnableMouseWheel(true)
    optionsPanel.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = _G[self:GetName() .. "ScrollBar"]
        if scrollBar then
            local value = scrollBar:GetValue() or 0
            local minValue, maxValue = scrollBar:GetMinMaxValues()
            scrollBar:SetValue(clamp(value - delta * 32, minValue or 0, maxValue or 0))
        end
    end)

    local content = optionsPanel.content

    local title = createText(content, 18)
    title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
    title:SetText("Dude's Flexible Bindings")

    local subtitle = createText(content, 11)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Einheitliche Interface, Makro und Bonusleisten Belegungen")
    subtitle:SetTextColor(0.8, 0.8, 0.8)

    optionsPanel.minimapCheckbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    optionsPanel.minimapCheckbox:SetWidth(22)
    optionsPanel.minimapCheckbox:SetHeight(22)
    optionsPanel.minimapCheckbox:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -18)
    styleButton(optionsPanel.minimapCheckbox)
    optionsPanel.minimapCheckbox.text = optionsPanel.minimapCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optionsPanel.minimapCheckbox.text:SetPoint("LEFT", optionsPanel.minimapCheckbox, "RIGHT", 2, 1)
    optionsPanel.minimapCheckbox.text:SetText("Minimap Button anzeigen")
    optionsPanel.minimapCheckbox:SetScript("OnClick", function(self)
        ADDON.SetSyncedSetting("showMinimapButton", self:GetChecked() and true or false)
        refreshMinimapButton()
    end)

    optionsPanel.characterSpecificSettingsCheckbox = createCheckbox(content, optionsPanel.minimapCheckbox, -4, "Charakterspezifische Einstellungen", function()
        return ADDON.IsCharacterSpecificSettingsEnabled and ADDON.IsCharacterSpecificSettingsEnabled()
    end, function(value)
        if value == false and ADDON.IsCharacterSpecificSettingsEnabled and ADDON.IsCharacterSpecificSettingsEnabled() then
            showDisableCharacterBindingsDialog(function()
                ADDON.SetCharacterSpecificSettingsEnabled(false)
                ADDON.RefreshSettings()
            end, function()
                ADDON.RefreshSettings()
            end)
            return false
        end
        if ADDON.SetCharacterSpecificSettingsEnabled and not ADDON.SetCharacterSpecificSettingsEnabled(value) then
            return false
        end
    end, function()
        if ADDON.RefreshEditorBindings then
            ADDON.RefreshEditorBindings()
        end
    end)

    optionsPanel.triggerOnKeyDownCheckbox = createCheckbox(content, optionsPanel.characterSpecificSettingsCheckbox, -4, "Tasten beim Drücken auslösen", function()
        return ADDON.GetSyncedSetting("triggerOnKeyDown")
    end, function(value)
        ADDON.SetSyncedSetting("triggerOnKeyDown", value)
        if ADDON.UpdateRuntimeButtonClickRegistration then
            return ADDON.UpdateRuntimeButtonClickRegistration()
        end
    end)

    local openLayoutButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    openLayoutButton:SetWidth(160)
    openLayoutButton:SetHeight(24)
    openLayoutButton:SetPoint("TOPLEFT", optionsPanel.triggerOnKeyDownCheckbox, "BOTTOMLEFT", 2, -16)
    openLayoutButton:SetText("Layout Editor")
    styleButton(openLayoutButton)
    openLayoutButton:SetScript("OnClick", function()
        if ADDON.ToggleOverlay then
            ADDON.ToggleOverlay()
        end
    end)

    local layoutTitle = createText(content, 15)
    layoutTitle:SetPoint("TOPLEFT", openLayoutButton, "BOTTOMLEFT", -2, -24)
    layoutTitle:SetText("Layouts")

    local saveLayoutButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    saveLayoutButton:SetWidth(120)
    saveLayoutButton:SetHeight(24)
    saveLayoutButton:SetPoint("TOPLEFT", layoutTitle, "BOTTOMLEFT", 0, -10)
    saveLayoutButton:SetText("Speichern")
    styleButton(saveLayoutButton)
    saveLayoutButton:SetScript("OnClick", showSaveLayoutDialog)
    optionsPanel.saveLayoutButton = saveLayoutButton

    local importLayoutButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    importLayoutButton:SetWidth(120)
    importLayoutButton:SetHeight(24)
    importLayoutButton:SetPoint("LEFT", saveLayoutButton, "RIGHT", 8, 0)
    importLayoutButton:SetText("Importieren")
    styleButton(importLayoutButton)
    importLayoutButton:SetScript("OnClick", showImportLayoutDialog)
    optionsPanel.importLayoutButton = importLayoutButton

    optionsPanel.layoutRows = layoutRows
    for i = 1, 8 do
        local row = CreateFrame("Frame", nil, content)
        row:SetWidth(260)
        row:SetHeight(34)
        row:SetPoint("TOPLEFT", saveLayoutButton, "BOTTOMLEFT", 0, -8 - (i - 1) * 38)

        row.name = createText(row, 11)
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
        row.name:SetWidth(130)

        row.meta = createText(row, 9)
        row.meta:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row.meta:SetWidth(130)
        row.meta:SetTextColor(0.72, 0.72, 0.72)

        row.load = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.load:SetWidth(58)
        row.load:SetHeight(22)
        row.load:SetPoint("TOPLEFT", row, "TOPLEFT", 140, -5)
        row.load:SetText("Laden")
        styleButton(row.load)
        row.load:SetScript("OnClick", function(self)
            local parent = self:GetParent()
            if parent.profileId then
                showLoadLayoutDialog(parent.profileId, parent.name:GetText())
            end
        end)

        row.menu = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.menu:SetWidth(34)
        row.menu:SetHeight(22)
        row.menu:SetPoint("LEFT", row.load, "RIGHT", 6, 0)
        row.menu:SetText("...")
        styleButton(row.menu)
        row.menu:SetScript("OnClick", function(self)
            local parent = self:GetParent()
            if parent.profileId then
                showLayoutMenu(self, parent.profileId, parent.name:GetText())
            end
        end)

        layoutRows[i] = row
    end

    local bonusTitle = createText(content, 15)
    bonusTitle:SetPoint("TOPLEFT", layoutRows[8], "BOTTOMLEFT", 0, -18)
    bonusTitle:SetText("Bonusleiste")
    optionsPanel.bonusTitle = bonusTitle

    optionsPanel.bonusBarCheckbox = createCheckbox(content, bonusTitle, -8, "Bonusleiste anzeigen", function()
        return ADDON.GetBonusBarSettings().showBonusBar
    end, function(value)
        ADDON.GetBonusBarSettings().showBonusBar = value
        if ADDON.RefreshEditorBindings then
            ADDON.RefreshEditorBindings()
        end
    end)

    optionsPanel.alignBonusBarCheckbox = createCheckbox(content, optionsPanel.bonusBarCheckbox, -2, "Bonusleiste ausrichten", function()
        return ADDON.GetBonusBarSettings().alignBonusBar
    end, function(value)
        ADDON.GetBonusBarSettings().alignBonusBar = value
        if ADDON.RefreshEditorBindings then
            ADDON.RefreshEditorBindings()
        end
    end)

    optionsPanel.bonusBarAnchorSelector = createBonusAnchorSelector(content, optionsPanel.alignBonusBarCheckbox, -2)

    optionsPanel.bonusBarGrowthSelector = createBonusGrowthSelector(content, optionsPanel.bonusBarAnchorSelector, -2)

    optionsPanel.showBonusBarBindingsCheckbox = createCheckbox(content, optionsPanel.bonusBarGrowthSelector, -2, "Bonusleisten Belegungen anzeigen", function()
        return ADDON.GetBonusBarSettings().showBonusBarBindings
    end, function(value)
        ADDON.GetBonusBarSettings().showBonusBarBindings = value
        if ADDON.RefreshEditorBindings then
            ADDON.RefreshEditorBindings()
        end
    end)

    optionsPanel.bonusBarBindingSizeControl = createBindingSizeControl(content, optionsPanel.showBonusBarBindingsCheckbox, -2)

    optionsPanel.showBonusBarTooltipsCheckbox = createCheckbox(content, optionsPanel.bonusBarBindingSizeControl, -2, "Bonusleisten Tooltips anzeigen", function()
        return ADDON.GetBonusBarSettings().showBonusBarTooltips
    end, function(value)
        ADDON.GetBonusBarSettings().showBonusBarTooltips = value
        if ADDON.RefreshEditorBindings then
            ADDON.RefreshEditorBindings()
        end
    end)

    optionsPanel.clickBonusBarButtonsCheckbox = createCheckbox(content, optionsPanel.showBonusBarTooltipsCheckbox, -2, "Bonusleisten Buttons klickbar", function()
        return ADDON.GetBonusBarSettings().clickBonusBarButtons
    end, function(value)
        ADDON.GetBonusBarSettings().clickBonusBarButtons = value
        if ADDON.RefreshEditorBindings then
            ADDON.RefreshEditorBindings()
        end
    end)

    optionsPanel.resetBonusBarPositionButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    optionsPanel.resetBonusBarPositionButton:SetWidth(178)
    optionsPanel.resetBonusBarPositionButton:SetHeight(24)
    optionsPanel.resetBonusBarPositionButton:SetPoint("TOPLEFT", optionsPanel.clickBonusBarButtonsCheckbox, "BOTTOMLEFT", 2, -8)
    optionsPanel.resetBonusBarPositionButton:SetText("Bonusleiste zurücksetzen")
    styleButton(optionsPanel.resetBonusBarPositionButton)
    optionsPanel.resetBonusBarPositionButton:SetScript("OnClick", function()
        if ADDON.ResetBonusBar then
            ADDON.ResetBonusBar()
        end
        refreshBonusBarSettingsControls()
        if ADDON.RefreshEditorBindings then
            ADDON.RefreshEditorBindings()
        end
    end)

    optionsPanel:SetScript("OnShow", function()
        layoutOptionsPanel()
        ADDON.RefreshSettings()
    end)
    optionsPanel:SetScript("OnSizeChanged", layoutOptionsPanel)
    layoutOptionsPanel()

    InterfaceOptions_AddCategory(optionsPanel)

    return optionsPanel
end

function ADDON.RefreshSettings()
    if not optionsPanel then
        return
    end
    optionsPanel.minimapCheckbox:SetChecked(ADDON.GetSyncedSetting("showMinimapButton"))
    refreshMinimapButton()
    refreshBonusBarSettingsControls()
    refreshLayoutRows()
end

function ADDON.ToggleSettings()
    createOptionsPanel()
    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
        local displayedPanel = InterfaceOptionsFramePanelContainer and InterfaceOptionsFramePanelContainer.displayedPanel
        if displayedPanel == optionsPanel or optionsPanel:IsShown() then
            InterfaceOptionsFrame:Hide()
            return
        end
    end

    ADDON.RefreshSettings()
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
    end
end

function ADDON.CreateSettingsPanel()
    createOptionsPanel()
end

function ADDON.CreateMinimapButton()
    if minimapButton then
        refreshMinimapButton()
        return minimapButton
    end

    minimapButton = CreateFrame("Button", "DudesFlexBindingsMinimapButton", Minimap)
    minimapButton:SetWidth(32)
    minimapButton:SetHeight(32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)

    minimapButton.icon = minimapButton:CreateTexture(nil, "ARTWORK")
    minimapButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
    minimapButton.icon:SetWidth(20)
    minimapButton.icon:SetHeight(20)
    minimapButton.icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    minimapButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    minimapButton.border = minimapButton:CreateTexture(nil, "OVERLAY")
    minimapButton.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    minimapButton.border:SetWidth(54)
    minimapButton.border:SetHeight(54)
    minimapButton.border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)

    minimapButton:SetScript("OnClick", function(_, button)
        if minimapButton.dragged then
            minimapButton.dragged = nil
            return
        end
        if button == "RightButton" then
            ADDON.ToggleSettings()
        else
            ADDON.ToggleOverlay()
        end
    end)
    minimapButton:SetScript("OnDragStart", function(self)
        self.dragging = true
        self.dragged = true
        updateMinimapButtonFromCursor()
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self.dragging = nil
        updateMinimapButtonFromCursor()
    end)
    minimapButton:SetScript("OnUpdate", function(self)
        if self.dragging then
            updateMinimapButtonFromCursor()
        end
    end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("DudesFlexBindings")
        GameTooltip:AddLine("Left click: layout editor", 1, 1, 1)
        GameTooltip:AddLine("Right click: settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    refreshMinimapButton()
    positionMinimapButton()
    return minimapButton
end

DudesUtils.EventHandler.Add("PLAYER_LOGIN", function()
    ADDON.CreateSettingsPanel()
end)
