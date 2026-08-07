local ADDON = DudesRolls
local settingsPanel
local controls = {}

local function refreshControls()
    local settings = ADDON.GetSettings()
    for key, control in pairs(controls) do
        if key ~= "rollFrameSpacing" then
            control:SetChecked(settings[key] and true or false)
        end
    end
    if controls.rollFrameSpacing then
        controls.rollFrameSpacing:SetValue(settings.rollFrameSpacing or 0)
        controls.rollFrameSpacing.valueText:SetText(tostring(settings.rollFrameSpacing or 0))
        if settings.singleRollFrame then
            controls.rollFrameSpacing:Hide()
            controls.rollFrameSpacing.valueText:Hide()
        else
            controls.rollFrameSpacing:Show()
            controls.rollFrameSpacing.valueText:Show()
        end
    end
    if controls.showOpenRollCount then
        if settings.singleRollFrame then
            controls.showOpenRollCount:Show()
            controls.showOpenRollCount.text:Show()
        else
            controls.showOpenRollCount:Hide()
            controls.showOpenRollCount.text:Hide()
        end
    end
end

local function settingChanged()
    refreshControls()
    if ADDON.RefreshGroupLootFrames then
        ADDON.RefreshGroupLootFrames()
    end
end

local function createCheckbox(parent, anchor, yOffset, label, settingKey)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetWidth(22)
    checkbox:SetHeight(24)
    checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    DudesUtils.SettingsUI.CreateCheckboxLabel(checkbox, parent, label)
    checkbox:SetScript("OnClick", function(self)
        ADDON.GetSettings()[settingKey] = self:GetChecked() and true or false
        settingChanged()
    end)
    controls[settingKey] = checkbox
    return checkbox
end

local function createSectionTitle(parent, anchor, yOffset, label, height)
    local title = DudesUtils.SettingsUI.CreateText(parent, "section")
    title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    DudesUtils.SettingsUI.AnchorTextToContent(title, parent)
    title:SetHeight(height or 24)
    title:SetText(label)
    return title
end

local function createSpacingSlider(parent, anchor)
    local sliderName = "DudesRollsRollSpacingSlider"
    local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
    slider:SetWidth(180)
    slider:SetHeight(16)
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 6, -30)
    slider:SetMinMaxValues(0, 60)
    slider:SetValueStep(1)

    local low = _G[sliderName .. "Low"]
    local high = _G[sliderName .. "High"]
    local label = _G[sliderName .. "Text"]
    low:SetText("0")
    high:SetText("60")
    label:SetText("Abstand zwischen Würfelfenstern")
    DudesUtils.SettingsUI.ApplyTextStyle(low, "small", "LEFT")
    DudesUtils.SettingsUI.ApplyTextStyle(high, "small", "RIGHT")
    DudesUtils.SettingsUI.ApplyTextStyle(label, "normal", "CENTER")
    label:SetWidth(240)
    if label.SetWordWrap then
        label:SetWordWrap(false)
    end

    slider.valueText = DudesUtils.SettingsUI.CreateText(parent, "normal")
    slider.valueText:SetPoint("LEFT", slider, "RIGHT", 16, 0)
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor((tonumber(value) or 0) + 0.5)
        ADDON.GetSettings().rollFrameSpacing = value
        self.valueText:SetText(tostring(value))
        if ADDON.RefreshGroupLootFrames then
            ADDON.RefreshGroupLootFrames()
        end
    end)
    controls.rollFrameSpacing = slider
    return slider
end

local function layoutPanel()
    DudesUtils.SettingsUI.LayoutScrollablePanel(settingsPanel, 650)
end

local function createOptionsPanel()
    if settingsPanel then
        return settingsPanel
    end

    settingsPanel = DudesUtils.SettingsUI.CreateScrollablePanel(
        "DudesRollsOptionsPanel",
        "DudesRolls",
        "DudesRollsOptionsScrollFrame",
        "DudesRollsOptionsContent"
    )
    local content = settingsPanel.content

    local title = DudesUtils.SettingsUI.CreateText(content, "title")
    title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
    DudesUtils.SettingsUI.AnchorTextToContent(title, content)
    title:SetText("Dude's Rolls")

    local autoRollTitle = createSectionTitle(content, title, -24, "Auf entzauberbare Gegenstände automatisch mit Entzaubern / Gier würfeln", 36)
    local uncommon = createCheckbox(content, autoRollTitle, -8, "Ungewöhnliche Gegenstände", "autoRollUncommon")
    local rare = createCheckbox(content, uncommon, -4, "Seltene Gegenstände", "autoRollRare")

    local displayTitle = createSectionTitle(content, rare, -22, "Würfelfenster")
    local restore = createCheckbox(content, displayTitle, -8, "Offene Würfe nach Ladebildschirm wieder einblenden", "restoreOpenRolls")
    local single = createCheckbox(content, restore, -4, "Einzelnes Würfelfenster", "singleRollFrame")
    local showOpen = createCheckbox(content, single, -4, "Anzahl offener Würfe anzeigen", "showOpenRollCount")
    local showChoices = createCheckbox(content, showOpen, -4, "Anzahl Würfe anderer Raid- und Gruppenmitglieder anzeigen", "showGroupRollCounts")
    createSpacingSlider(content, showChoices)

    local confirmationsTitle = createSectionTitle(content, showChoices, -68, "Automatisch bestätigen")
    local confirmRoll = createCheckbox(content, confirmationsTitle, -8, "Beim Würfeln gebundene Gegenstände automatisch bestätigen", "autoConfirmRollBind")
    local confirmLoot = createCheckbox(content, confirmRoll, -4, "Beim Plündern gebundene Gegenstände automatisch bestätigen", "autoConfirmLootBind")
    local confirmEnchant = createCheckbox(content, confirmLoot, -4, "Beim Verzaubern gebundene Gegenstände automatisch bestätigen", "autoConfirmEnchantBind")
    createCheckbox(content, confirmEnchant, -4, "Ändern von Verzauberungen automatisch bestätigen", "autoConfirmReplaceEnchant")

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

function ADDON.OpenSettings()
    createOptionsPanel()
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(settingsPanel)
        InterfaceOptionsFrame_OpenToCategory(settingsPanel)
    end
end

DudesUtils.EventHandler.Add("PLAYER_LOGIN", createOptionsPanel)
