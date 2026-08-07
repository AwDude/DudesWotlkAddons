local ADDON = DudesLootTracker

local optionsPanel
local minimapButton
local positionMinimapButton
local BORDER_R, BORDER_G, BORDER_B = 0.32, 0.38, 0.46
local HOVER_R, HOVER_G, HOVER_B = 0.72, 0.86, 1

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
        DudesUtils.SettingsUI.StyleButtonText(button)
    end
end

local function createText(parent, size)
    return DudesUtils.SettingsUI.CreateText(parent, size or "normal")
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

positionMinimapButton = function()
    if not minimapButton or not Minimap then
        return
    end
    local radians = math.rad(ADDON.GetSettings().minimapAngle or 260)
    local radius = (Minimap:GetWidth() or 140) / 2 + 10
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
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
    ADDON.GetSettings().minimapAngle = getAngleFromDelta(cursorY / scale - centerY, cursorX / scale - centerX)
    positionMinimapButton()
end

local function createCheckbox(parent, anchor, yOffset, label, getter, setter)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetWidth(22)
    checkbox:SetHeight(24)
    checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset or -8)
    DudesUtils.SettingsUI.CreateCheckboxLabel(checkbox, parent, label)
    checkbox:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)
    checkbox.refresh = function()
        checkbox:SetChecked(getter() and true or false)
    end
    return checkbox
end

local function setControlEnabled(control, enabled)
    if not control then
        return
    end
    if enabled then
        if control.Enable then
            control:Enable()
        end
    elseif control.Disable then
        control:Disable()
    end
    local alpha = enabled and 1 or 0.45
    if control.SetAlpha then
        control:SetAlpha(alpha)
    end
    if control.text then
        control.text:SetTextColor(1, 1, 1)
        control.text:SetAlpha(alpha)
    end
    if control.labelText then
        control.labelText:SetTextColor(1, 1, 1)
        control.labelText:SetAlpha(alpha)
    end
end

local function createEdit(parent, anchor, label, width, getter, setter)
    local labelText = createText(parent, 11)
    labelText:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    labelText:SetWidth(250)
    labelText:SetText(label)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetWidth(width or 70)
    box:SetHeight(20)
    box:SetPoint("LEFT", labelText, "RIGHT", 12, 0)
    box:SetAutoFocus(false)
    box:SetFont(STANDARD_TEXT_FONT, 11, "")
    box:SetTextColor(1, 1, 1)
    box:SetTextInsets(5, 5, 0, 0)
    setBackdrop(box, 0.055, 0.065, 0.08, 1)
    addBorderHover(box)
    box:SetScript("OnEnterPressed", function(self)
        setter(self:GetText())
        self:ClearFocus()
        ADDON.RefreshSettings()
    end)
    box.labelText = labelText
    box.refresh = function()
        box:SetText(tostring(getter()))
    end
    return box, labelText
end

local function layoutPanel()
    DudesUtils.SettingsUI.LayoutScrollablePanel(optionsPanel, 680)
end

local function createOptionsPanel()
    if optionsPanel then
        return optionsPanel
    end

    optionsPanel = DudesUtils.SettingsUI.CreateScrollablePanel(
        "DudesLootTrackerOptionsPanel",
        "DudesLootTracker",
        "DudesLootTrackerOptionsScrollFrame",
        "DudesLootTrackerOptionsContent"
    )
    optionsPanel.controls = {}
    optionsPanel.scroll = optionsPanel.scrollFrame

    local content = optionsPanel.content
    local title = createText(content, 18)
    title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
    DudesUtils.SettingsUI.AnchorTextToContent(title, content)
    title:SetText("Dude's Loot Tracker")
    local c = createCheckbox(content, title, -18, "Charakterspezifische Einstellungen", function()
        return ADDON.UsesCharacterSpecificSettings()
    end, function(value)
        ADDON.SetCharacterSpecificSettings(value)
        if ADDON.ApplySettingsProfile then
            ADDON.ApplySettingsProfile()
        end
        if ADDON.PruneHistory then
            ADDON.PruneHistory()
        end
        ADDON.RefreshSettings()
    end)
    table.insert(optionsPanel.controls, c)
    c = createCheckbox(content, c, -8, "Minimap Button anzeigen", function() return ADDON.GetSettings().showMinimapButton end, function(value) ADDON.GetSettings().showMinimapButton = value refreshMinimapButton() end)
    table.insert(optionsPanel.controls, c)
    c = createCheckbox(content, c, -8, "Beute nicht im Chat anzeigen", function() return ADDON.GetSettings().hideLootChatMessages end, function(value) ADDON.GetSettings().hideLootChatMessages = value end)
    table.insert(optionsPanel.controls, c)

    local maxLootEntries = createEdit(content, c, "Max Einträge im Beute-Fenster", 60, function() return ADDON.GetSettings().maxLootEntries end, function(value) ADDON.GetSettings().maxLootEntries = ADDON.Clamp(tonumber(value) or 900, 50, 10000) ADDON.PruneHistory() end)
    table.insert(optionsPanel.controls, maxLootEntries)

    optionsPanel:SetScript("OnShow", function()
        layoutPanel()
        ADDON.RefreshSettings()
    end)
    optionsPanel:SetScript("OnSizeChanged", layoutPanel)
    layoutPanel()
    InterfaceOptions_AddCategory(optionsPanel)
    return optionsPanel
end

function ADDON.RefreshSettings()
    if not optionsPanel then
        return
    end
    for _, control in ipairs(optionsPanel.controls or {}) do
        if control.refresh then
            control.refresh()
        end
        if control.dltRequires then
            setControlEnabled(control, control.dltRequires() and true or false)
        else
            setControlEnabled(control, true)
        end
    end
    refreshMinimapButton()
end

function ADDON.CreateSettingsPanel()
    createOptionsPanel()
end

function ADDON.ToggleSettings()
    createOptionsPanel()
    ADDON.RefreshSettings()
    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
        local displayedPanel = InterfaceOptionsFramePanelContainer and InterfaceOptionsFramePanelContainer.displayedPanel
        if displayedPanel == optionsPanel or optionsPanel:IsShown() then
            InterfaceOptionsFrame:Hide()
            return
        end
    end
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
    end
end

function ADDON.CreateMinimapButton()
    if minimapButton then
        refreshMinimapButton()
        return minimapButton
    end
    minimapButton = CreateFrame("Button", "DudesLootTrackerMinimapButton", Minimap)
    minimapButton:SetWidth(32)
    minimapButton:SetHeight(32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton.icon = minimapButton:CreateTexture(nil, "ARTWORK")
    minimapButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
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
            ADDON.ToggleWindow()
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
        GameTooltip:AddLine("DudesLootTracker")
        GameTooltip:AddLine("Linksklick: Lootfenster", 1, 1, 1)
        GameTooltip:AddLine("Rechtsklick: Einstellungen", 1, 1, 1)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    refreshMinimapButton()
    positionMinimapButton()
    return minimapButton
end
