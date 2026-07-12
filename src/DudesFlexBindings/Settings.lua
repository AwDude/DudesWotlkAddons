local ADDON = DudesFlexBindings

local optionsPanel
local minimapButton
local layoutRows = {}
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

local function stylePopupButtons(popup)
    if not popup or not popup.GetName then
        return
    end

    local name = popup:GetName()
    styleButton(_G[name .. "Button1"])
    styleButton(_G[name .. "Button2"])
    styleButton(_G[name .. "Button3"])
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

    if ADDON.GetSettings().showMinimapButton then
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
    local deleteWidth = 76
    local buttonGap = 6
    local textWidth = math.max(120, rowWidth - loadWidth - deleteWidth - buttonGap - 12)
    local loadX = textWidth + 8

    for _, row in ipairs(optionsPanel.layoutRows) do
        row:SetWidth(rowWidth)
        row.name:SetWidth(textWidth)
        row.meta:SetWidth(textWidth)

        row.load:ClearAllPoints()
        row.load:SetWidth(loadWidth)
        row.load:SetPoint("TOPLEFT", row, "TOPLEFT", loadX, -5)

        row.delete:ClearAllPoints()
        row.delete:SetWidth(deleteWidth)
        row.delete:SetPoint("LEFT", row.load, "RIGHT", buttonGap, 0)
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
                row.delete:Hide()
            else
                row.delete:Show()
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
    local enabled = settings.showBonusBar and true or false

    if optionsPanel.bonusBarCheckbox then
        optionsPanel.bonusBarCheckbox:SetChecked(enabled)
    end
    if optionsPanel.alignBonusBarCheckbox then
        optionsPanel.alignBonusBarCheckbox:SetChecked(settings.alignBonusBar and true or false)
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
        optionsPanel.showBonusBarBindingsCheckbox:SetChecked(settings.showBonusBarBindings and true or false)
        setFrameEnabled(optionsPanel.showBonusBarBindingsCheckbox, enabled)
        showFrame(optionsPanel.showBonusBarBindingsCheckbox, enabled)
    end
    if optionsPanel.characterInterfaceBindingsCheckbox and ADDON.IsCharacterBindingSetEnabled then
        optionsPanel.characterInterfaceBindingsCheckbox:SetChecked(ADDON.IsCharacterBindingSetEnabled())
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
        setter(self:GetChecked() and true or false)
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
                    ADDON.GetSettings().bonusBarAnchor = self.value
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

    local value = ADDON.GetSettings().bonusBarAnchor or "topLeft"
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
                    ADDON.GetSettings().bonusBarGrowthDirection = self.value
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

    local value = ADDON.GetSettings().bonusBarGrowthDirection or "right"
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
    selector.text:SetText("Bonus-Bar Anker")
    selector:SetScript("OnClick", function(self)
        showBonusAnchorSelector(self)
    end)
    selector.refresh = function()
        selector.valueText:SetText(getBonusAnchorText(ADDON.GetSettings().bonusBarAnchor or "topLeft"))
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
    selector.text:SetText("Bonus-Bar Wachstum")
    selector:SetScript("OnClick", function(self)
        showBonusGrowthSelector(self)
    end)
    selector.refresh = function()
        selector.valueText:SetText(getBonusGrowthText(ADDON.GetSettings().bonusBarGrowthDirection or "right"))
    end
    selector.refresh()
    return selector
end

local function raiseSettingsPopup(popup)
    if not popup then
        return
    end
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(100)
    stylePopupButtons(popup)
end

local function showSaveLayoutDialog()
    StaticPopupDialogs["DUDES_FLEX_BINDINGS_SAVE_LAYOUT_SETTINGS"] = StaticPopupDialogs["DUDES_FLEX_BINDINGS_SAVE_LAYOUT_SETTINGS"] or {
        text = "Layout-Name",
        button1 = "Speichern",
        button2 = "Abbrechen",
        hasEditBox = 1,
        maxLetters = 64,
        OnAccept = function(self)
            local name = self.editBox and self.editBox:GetText() or ""
            if ADDON.SaveAppliedLayoutProfile and ADDON.SaveAppliedLayoutProfile(name) then
                refreshLayoutRows()
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffDudesFlexBindings:|r Layout name must be unique.")
            end
        end,
        OnShow = function(self)
            if self.editBox then
                self.editBox:SetText("")
                self.editBox:SetFocus()
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local name = self:GetText() or ""
            if ADDON.SaveAppliedLayoutProfile and ADDON.SaveAppliedLayoutProfile(name) then
                parent:Hide()
                refreshLayoutRows()
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
    raiseSettingsPopup(StaticPopup_Show("DUDES_FLEX_BINDINGS_SAVE_LAYOUT_SETTINGS"))
end

local function showLoadLayoutDialog(profileId, profileName)
    if not profileId then
        return
    end

    StaticPopupDialogs["DUDES_FLEX_BINDINGS_LOAD_LAYOUT_SETTINGS"] = StaticPopupDialogs["DUDES_FLEX_BINDINGS_LOAD_LAYOUT_SETTINGS"] or {
        text = "Layout '%s' laden?\n\nDieses Layout ersetzt alle aktuellen DudesFlexBindings-Makros und Interface-Bindings des aktiven Specs.\n\nMöchtest du wirklich fortfahren?",
        button1 = "Laden",
        button2 = "Abbrechen",
        OnAccept = function(self)
            local id = self.profileId
            if id and ADDON.LoadLayoutProfile then
                ADDON.LoadLayoutProfile(id)
                refreshLayoutRows()
            end
            self.profileId = nil
        end,
        OnCancel = function(self)
            self.profileId = nil
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }

    local popup = StaticPopup_Show("DUDES_FLEX_BINDINGS_LOAD_LAYOUT_SETTINGS", profileName or "")
    if popup then
        popup.profileId = profileId
        raiseSettingsPopup(popup)
    end
end

local function showDeleteLayoutDialog(profileId, profileName)
    if not profileId then
        return
    end

    StaticPopupDialogs["DUDES_FLEX_BINDINGS_DELETE_LAYOUT_SETTINGS"] = StaticPopupDialogs["DUDES_FLEX_BINDINGS_DELETE_LAYOUT_SETTINGS"] or {
        text = "Layout '%s' löschen?\n\nDieses gespeicherte Layout wird dauerhaft entfernt.",
        button1 = "Löschen",
        button2 = "Abbrechen",
        OnAccept = function(self)
            local id = self.profileId
            if id and ADDON.DeleteLayoutProfile then
                ADDON.DeleteLayoutProfile(id)
                refreshLayoutRows()
            end
            self.profileId = nil
        end,
        OnCancel = function(self)
            self.profileId = nil
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }

    local popup = StaticPopup_Show("DUDES_FLEX_BINDINGS_DELETE_LAYOUT_SETTINGS", profileName or "")
    if popup then
        popup.profileId = profileId
        raiseSettingsPopup(popup)
    end
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
    title:SetText("DudesFlexBindings")

    local subtitle = createText(content, 11)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Character and spec specific key macros.")
    subtitle:SetTextColor(0.8, 0.8, 0.8)

    optionsPanel.minimapCheckbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    optionsPanel.minimapCheckbox:SetWidth(22)
    optionsPanel.minimapCheckbox:SetHeight(22)
    optionsPanel.minimapCheckbox:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -18)
    styleButton(optionsPanel.minimapCheckbox)
    optionsPanel.minimapCheckbox.text = optionsPanel.minimapCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optionsPanel.minimapCheckbox.text:SetPoint("LEFT", optionsPanel.minimapCheckbox, "RIGHT", 2, 1)
    optionsPanel.minimapCheckbox.text:SetText("Show minimap button")
    optionsPanel.minimapCheckbox:SetScript("OnClick", function(self)
        ADDON.GetSettings().showMinimapButton = self:GetChecked() and true or false
        refreshMinimapButton()
    end)

    optionsPanel.characterInterfaceBindingsCheckbox = createCheckbox(content, optionsPanel.minimapCheckbox, -4, "Charakterspezifische Interface Belegungen", function()
        return ADDON.IsCharacterBindingSetEnabled and ADDON.IsCharacterBindingSetEnabled()
    end, function(value)
        if ADDON.SetCharacterBindingSetEnabled and not ADDON.SetCharacterBindingSetEnabled(value) and optionsPanel.characterInterfaceBindingsCheckbox then
            optionsPanel.characterInterfaceBindingsCheckbox:SetChecked(ADDON.IsCharacterBindingSetEnabled and ADDON.IsCharacterBindingSetEnabled() or false)
        end
    end, function()
        if ADDON.RefreshEditorBindings then
            ADDON.RefreshEditorBindings()
        end
    end)

    local openLayoutButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    openLayoutButton:SetWidth(160)
    openLayoutButton:SetHeight(24)
    openLayoutButton:SetPoint("TOPLEFT", optionsPanel.characterInterfaceBindingsCheckbox, "BOTTOMLEFT", 2, -16)
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

        row.delete = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.delete:SetWidth(70)
        row.delete:SetHeight(22)
        row.delete:SetPoint("LEFT", row.load, "RIGHT", 6, 0)
        row.delete:SetText("Löschen")
        styleButton(row.delete)
        row.delete:SetScript("OnClick", function(self)
            local parent = self:GetParent()
            if parent.profileId then
                showDeleteLayoutDialog(parent.profileId, parent.name:GetText())
            end
        end)

        layoutRows[i] = row
    end

    local bonusTitle = createText(content, 15)
    bonusTitle:SetPoint("TOPLEFT", layoutRows[8], "BOTTOMLEFT", 0, -18)
    bonusTitle:SetText("Bonus-Bar")
    optionsPanel.bonusTitle = bonusTitle

    optionsPanel.bonusBarCheckbox = createCheckbox(content, bonusTitle, -8, "Bonus-Bar anzeigen", function()
        return ADDON.GetSettings().showBonusBar
    end, function(value)
        ADDON.GetSettings().showBonusBar = value
    end)

    optionsPanel.alignBonusBarCheckbox = createCheckbox(content, optionsPanel.bonusBarCheckbox, -2, "Bonus-Bar ausrichten", function()
        return ADDON.GetSettings().alignBonusBar
    end, function(value)
        ADDON.GetSettings().alignBonusBar = value
    end)

    optionsPanel.bonusBarAnchorSelector = createBonusAnchorSelector(content, optionsPanel.alignBonusBarCheckbox, -2)

    optionsPanel.bonusBarGrowthSelector = createBonusGrowthSelector(content, optionsPanel.bonusBarAnchorSelector, -2)

    optionsPanel.showBonusBarBindingsCheckbox = createCheckbox(content, optionsPanel.bonusBarGrowthSelector, -2, "Bonus-Bar Bindings anzeigen", function()
        return ADDON.GetSettings().showBonusBarBindings
    end, function(value)
        ADDON.GetSettings().showBonusBarBindings = value
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
    optionsPanel.minimapCheckbox:SetChecked(ADDON.GetSettings().showMinimapButton)
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
