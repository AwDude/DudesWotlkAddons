local ADDON = DudesFlexFrames
local settingsPanel

local function createText(parent, size)
	local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetFont(STANDARD_TEXT_FONT, size or 11)
	text:SetJustifyH("LEFT")
	return text
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

	local resetButton = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
	resetButton:SetWidth(170)
	resetButton:SetHeight(24)
	resetButton:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -18)
	resetButton:SetText("Alle Frames zurücksetzen")
	resetButton:SetScript("OnClick", ADDON.ResetFrames)

	InterfaceOptions_AddCategory(settingsPanel)
	return settingsPanel
end

DudesUtils.EventHandler.Add("PLAYER_LOGIN", createOptionsPanel)
