local ADDON = DudesKeyMacros

local optionsPanel
local minimapButton

local function createText(parent, size)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetFont(STANDARD_TEXT_FONT, size or 11)
    return text
end

local function refreshMinimapButton()
    if not minimapButton then
        return
    end

    if ADDON.GetSettings().showMinimapButton then
        minimapButton:Show()
    else
        minimapButton:Hide()
    end
end

local function createOptionsPanel()
    if optionsPanel then
        return optionsPanel
    end

    optionsPanel = CreateFrame("Frame", "DudesKeyMacrosOptionsPanel", UIParent)
    optionsPanel.name = "DudesKeyMacros"

    local title = createText(optionsPanel, 18)
    title:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 16, -16)
    title:SetText("DudesKeyMacros")

    local subtitle = createText(optionsPanel, 11)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Character and spec specific key macros.")
    subtitle:SetTextColor(0.8, 0.8, 0.8)

    optionsPanel.minimapCheckbox = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
    optionsPanel.minimapCheckbox:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -18)
    optionsPanel.minimapCheckbox.text = optionsPanel.minimapCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optionsPanel.minimapCheckbox.text:SetPoint("LEFT", optionsPanel.minimapCheckbox, "RIGHT", 2, 1)
    optionsPanel.minimapCheckbox.text:SetText("Show minimap button")
    optionsPanel.minimapCheckbox:SetScript("OnClick", function(self)
        ADDON.GetSettings().showMinimapButton = self:GetChecked() and true or false
        refreshMinimapButton()
    end)

    local openLayoutButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    openLayoutButton:SetWidth(160)
    openLayoutButton:SetHeight(24)
    openLayoutButton:SetPoint("TOPLEFT", optionsPanel.minimapCheckbox, "BOTTOMLEFT", 2, -16)
    openLayoutButton:SetText("Open layout editor")
    openLayoutButton:SetScript("OnClick", function()
        if ADDON.ShowOverlay then
            ADDON.ShowOverlay()
        end
    end)

    optionsPanel:SetScript("OnShow", function()
        ADDON.RefreshSettings()
    end)

    InterfaceOptions_AddCategory(optionsPanel)

    return optionsPanel
end

function ADDON.RefreshSettings()
    if not optionsPanel then
        return
    end
    optionsPanel.minimapCheckbox:SetChecked(ADDON.GetSettings().showMinimapButton)
end

function ADDON.ToggleSettings()
    createOptionsPanel()
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

    minimapButton = CreateFrame("Button", "DudesKeyMacrosMinimapButton", Minimap)
    minimapButton:SetWidth(32)
    minimapButton:SetHeight(32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
        if button == "RightButton" then
            ADDON.ToggleSettings()
        else
            ADDON.ToggleOverlay()
        end
    end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("DudesKeyMacros")
        GameTooltip:AddLine("Left click: layout editor", 1, 1, 1)
        GameTooltip:AddLine("Right click: settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    refreshMinimapButton()
    return minimapButton
end

DudesUtils.EventHandler.Add("PLAYER_LOGIN", function()
    ADDON.CreateSettingsPanel()
end)
