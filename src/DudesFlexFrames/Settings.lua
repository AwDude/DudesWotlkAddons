local ADDON = DudesFlexFrames
local settingsPanel
local controls = {}

local function createText(parent, size, justify)
	local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetFont(STANDARD_TEXT_FONT, size or 11)
	text:SetJustifyH(justify or "LEFT")
	return text
end

local function refreshControls()
	local settings = ADDON.GetSettings()
	if controls.characterSpecificSettings then
		controls.characterSpecificSettings:SetChecked(ADDON.UsesCharacterSpecificSettings and ADDON.UsesCharacterSpecificSettings() or false)
	end
	if controls.restoreOpenRolls then
		controls.restoreOpenRolls:SetChecked(settings.restoreOpenRolls and true or false)
	end
	if controls.autoConfirmBindOnPickup then
		controls.autoConfirmBindOnPickup:SetChecked(settings.autoConfirmBindOnPickup and true or false)
	end
	if controls.singleRollFrame then
		controls.singleRollFrame:SetChecked(settings.singleRollFrame and true or false)
	end
	if controls.showOpenRollCount then
		controls.showOpenRollCount:SetChecked(settings.showOpenRollCount and true or false)
		if controls.singleRollFrame then
			controls.showOpenRollCount:ClearAllPoints()
			controls.showOpenRollCount:SetPoint("TOPLEFT", controls.singleRollFrame, "BOTTOMLEFT", 0, -4)
		end
		if settings.singleRollFrame then
			controls.showOpenRollCount:Show()
			controls.showOpenRollCount.text:Show()
		else
			controls.showOpenRollCount:Hide()
			controls.showOpenRollCount.text:Hide()
		end
	end
	if controls.rollFrameSpacing then
		if controls.singleRollFrame then
			controls.rollFrameSpacing:ClearAllPoints()
			controls.rollFrameSpacing:SetPoint("TOPLEFT", controls.singleRollFrame, "BOTTOMLEFT", 6, -24)
		end
		controls.rollFrameSpacing:SetValue(settings.rollFrameSpacing or 0)
		if controls.rollFrameSpacing.valueText then
			controls.rollFrameSpacing.valueText:SetText(tostring(settings.rollFrameSpacing or 0))
		end
		if settings.singleRollFrame then
			controls.rollFrameSpacing:Hide()
			controls.rollFrameSpacing.valueText:Hide()
		else
			controls.rollFrameSpacing:Show()
			controls.rollFrameSpacing.valueText:Show()
		end
	end
end

local function settingChanged()
	refreshControls()
	if ADDON.RefreshGroupLootFrames then
		ADDON.RefreshGroupLootFrames()
	end
end

local function createCheckbox(parent, anchor, yOffset, label, settingKey, setter)
	local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkbox:SetWidth(22)
	checkbox:SetHeight(22)
	checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
	checkbox.text = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 2, 1)
	checkbox.text:SetText(label)
	checkbox:SetScript("OnClick", function(self)
		local value = self:GetChecked() and true or false
		if setter then
			setter(value)
		else
			ADDON.GetSettings()[settingKey] = value
		end
		settingChanged()
	end)
	return checkbox
end

local function createSpacingSlider(parent, anchor)
	local sliderName = "DudesFlexFramesRollSpacingSlider"
	local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
	slider:SetWidth(180)
	slider:SetHeight(16)
	slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 6, -24)
	slider:SetMinMaxValues(0, 60)
	slider:SetValueStep(1)
	_G[sliderName .. "Low"]:SetText("0")
	_G[sliderName .. "High"]:SetText("60")
	_G[sliderName .. "Text"]:SetText("Abstand zwischen Würfelfenstern")
	slider.valueText = createText(parent, 11, "LEFT")
	slider.valueText:SetPoint("LEFT", slider, "RIGHT", 16, 0)
	slider:SetScript("OnValueChanged", function(self, value)
		value = math.floor((tonumber(value) or 0) + 0.5)
		ADDON.GetSettings().rollFrameSpacing = value
		if self.valueText then
			self.valueText:SetText(tostring(value))
		end
		if ADDON.RefreshGroupLootFrames then
			ADDON.RefreshGroupLootFrames()
		end
	end)
	return slider
end

local function createOptionsPanel()
	if settingsPanel then
		return settingsPanel
	end

	settingsPanel = CreateFrame("Frame", "DudesFlexFramesOptionsPanel", UIParent)
	settingsPanel.name = "DudesFlexFrames"

	local title = createText(settingsPanel, 18)
	title:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 16, -16)
	title:SetText("Dude's Flexible Frames")

	local subtitle = createText(settingsPanel, 11)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	subtitle:SetText("Positionen und Skalierungen der verschiebbaren Frames")
	subtitle:SetTextColor(0.8, 0.8, 0.8)

	controls.characterSpecificSettings = createCheckbox(settingsPanel, subtitle, -12, "Charakterspezifische Einstellungen", nil, function(value)
		ADDON.SetCharacterSpecificSettings(value)
	end)

	local resetButton = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
	resetButton:SetWidth(170)
	resetButton:SetHeight(24)
	resetButton:SetPoint("TOPLEFT", controls.characterSpecificSettings, "BOTTOMLEFT", 0, -14)
	resetButton:SetText("Alle Frames zurücksetzen")
	resetButton:SetScript("OnClick", ADDON.ResetFrames)

	local rollTitle = createText(settingsPanel, 14)
	rollTitle:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -28)
	rollTitle:SetText("Würfel Fenster")

	controls.restoreOpenRolls = createCheckbox(settingsPanel, rollTitle, -10, "Offene Würfe nach Ladebildschirm wieder einblenden", "restoreOpenRolls")
	controls.autoConfirmBindOnPickup = createCheckbox(settingsPanel, controls.restoreOpenRolls, -4, "Loot-Bindung automatisch bestätigen", "autoConfirmBindOnPickup")
	controls.singleRollFrame = createCheckbox(settingsPanel, controls.autoConfirmBindOnPickup, -4, "Einzelnes Würfelfenster", "singleRollFrame")
	controls.showOpenRollCount = createCheckbox(settingsPanel, controls.singleRollFrame, -4, "Anzahl offener Würfe anzeigen", "showOpenRollCount")
	controls.rollFrameSpacing = createSpacingSlider(settingsPanel, controls.singleRollFrame)
	refreshControls()

	InterfaceOptions_AddCategory(settingsPanel)
	return settingsPanel
end

DudesUtils.EventHandler.Add("PLAYER_LOGIN", createOptionsPanel)
