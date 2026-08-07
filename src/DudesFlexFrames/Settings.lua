local ADDON = DudesFlexFrames
local settingsPanel
local characterSpecificSettings
local BORDER_R, BORDER_G, BORDER_B = 0.32, 0.38, 0.46
local HOVER_BORDER_R, HOVER_BORDER_G, HOVER_BORDER_B = 0.72, 0.86, 1

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

local function styleButton(button)
    if button:GetNormalTexture() then
        button:GetNormalTexture():SetTexture(nil)
    end
    if button:GetPushedTexture() then
        button:GetPushedTexture():SetTexture(nil)
    end
    if button:GetDisabledTexture() then
        button:GetDisabledTexture():SetTexture(nil)
    end
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    if button:GetHighlightTexture() then
        button:GetHighlightTexture():SetVertexColor(0, 0, 0, 0)
    end
    setBackdrop(button, 0.055, 0.065, 0.08, 1)
    button:HookScript("OnEnter", function(self)
        self:SetBackdropBorderColor(HOVER_BORDER_R, HOVER_BORDER_G, HOVER_BORDER_B, 1)
    end)
    button:HookScript("OnLeave", function(self)
        self:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
    end)
    DudesUtils.SettingsUI.StyleButtonText(button)
end

local function createCheckbox(parent, anchor, yOffset, label, setter)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetWidth(22)
    checkbox:SetHeight(24)
    checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    DudesUtils.SettingsUI.CreateCheckboxLabel(checkbox, parent, label)
    checkbox:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)
    return checkbox
end

local function layoutPanel()
    DudesUtils.SettingsUI.LayoutScrollablePanel(settingsPanel, 620)
end

local function refreshControls()
    if characterSpecificSettings then
        characterSpecificSettings:SetChecked(ADDON.UsesCharacterSpecificSettings and ADDON.UsesCharacterSpecificSettings() or false)
    end
end

local function createOptionsPanel()
    if settingsPanel then
        return settingsPanel
    end

    settingsPanel = DudesUtils.SettingsUI.CreateScrollablePanel(
        "DudesFlexFramesOptionsPanel",
        "DudesFlexFrames",
        "DudesFlexFramesOptionsScrollFrame",
        "DudesFlexFramesOptionsContent"
    )
    local content = settingsPanel.content

    local title = DudesUtils.SettingsUI.CreateText(content, "title")
    title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
    DudesUtils.SettingsUI.AnchorTextToContent(title, content)
    title:SetText("Dude's Flexible Frames")

    characterSpecificSettings = createCheckbox(content, title, -18, "Charakterspezifische Einstellungen", function(value)
        ADDON.SetCharacterSpecificSettings(value)
    end)

    local resetButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetButton:SetWidth(170)
    resetButton:SetHeight(24)
    resetButton:SetPoint("TOPLEFT", characterSpecificSettings, "BOTTOMLEFT", 0, -14)
    resetButton:SetText("Alle Frames zurücksetzen")
    styleButton(resetButton)
    resetButton:SetScript("OnClick", ADDON.ResetFrames)

    settingsPanel:SetScript("OnShow", function()
        layoutPanel()
        refreshControls()
    end)
    settingsPanel:SetScript("OnSizeChanged", layoutPanel)
    layoutPanel()
    refreshControls()
    InterfaceOptions_AddCategory(settingsPanel)
    return settingsPanel
end

DudesUtils.EventHandler.Add("PLAYER_LOGIN", createOptionsPanel)
