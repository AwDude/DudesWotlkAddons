DudesUtils = DudesUtils or {}
DudesUtils.Array = DudesUtils.Array or {}
DudesUtils.String = DudesUtils.String or {}
DudesUtils.Table = DudesUtils.Table or {}
DudesUtils.EventHandler = DudesUtils.EventHandler or {}
DudesUtils.Dialog = DudesUtils.Dialog or {}
DudesUtils.SettingsUI = DudesUtils.SettingsUI or {}

local hiddenFrame = hiddenFrame or CreateFrame("Frame")
local nextUpdateCallbacks = {}
local eventHandlers = {}

hiddenFrame:SetScript("OnEvent", function(self, event, ...)
    if eventHandlers[event] then
        for eventHandler in pairs(eventHandlers[event]) do
            local ok, err = pcall(eventHandler, event, ...)
            if not ok then
                geterrorhandler()(err)
            end
        end
    end
end)

local function onUpdate()
    hiddenFrame:SetScript("OnUpdate", nil)
	
    local initialCount = #nextUpdateCallbacks
    for i = 1, initialCount do
        local ok, err = pcall(nextUpdateCallbacks[i])
        if not ok then
            geterrorhandler()(err)
        end
    end

	-- if DudesUtils.OnNextUpdate gets called inside a callback
    local remaining = #nextUpdateCallbacks - initialCount
    if remaining > 0 then
        for i = 1, remaining do
            nextUpdateCallbacks[i] = nextUpdateCallbacks[initialCount + i]
            nextUpdateCallbacks[initialCount + i] = nil
        end
        hiddenFrame:SetScript("OnUpdate", onUpdate)
    else
        table.wipe(nextUpdateCallbacks)
    end
end

-- -- -- -- -- -- -- -- EVENT HANDLER -- -- -- -- -- -- -- --

function DudesUtils.EventHandler.Add(event, handler)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        hiddenFrame:RegisterEvent(event)
    end
    eventHandlers[event][handler] = true
end

function DudesUtils.EventHandler.Remove(event, handler)
    if eventHandlers[event] then
        eventHandlers[event][handler] = nil
        if next(eventHandlers[event]) == nil then
            eventHandlers[event] = nil
            hiddenFrame:UnregisterEvent(event)
        end
    end
end

function DudesUtils.EventHandler.Clear()
    eventHandlers = {}
    hiddenFrame:UnregisterAllEvents()
end

-- -- -- -- -- -- -- -- STRING UTILS -- -- -- -- -- -- -- --

function DudesUtils.String.StartsWith(text, prefix)
   return string.sub(text, 1, string.len(prefix)) == prefix
end

-- -- -- -- -- -- -- -- ARRAY UTILS -- -- -- -- -- -- -- --

function DudesUtils.Array.Contains(array, value)
	for _, item in ipairs(array) do
		if item == value then
			return true
		end
	end
	return false
end

function DudesUtils.Array.Copy(array)
	local copy = {}
	for i, value in ipairs(array or {}) do
		if type(value) == "table" then
			copy[i] = DudesUtils.Table.Copy(value)
		else
			copy[i] = value
		end
	end
	return copy
end

-- -- -- -- -- -- -- -- TABLE UTILS -- -- -- -- -- -- -- --

function DudesUtils.Table.Copy(source)
	if type(source) ~= "table" then
		return source
	end
	local copy = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			copy[key] = DudesUtils.Table.Copy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

function DudesUtils.Table.Equals(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	a = a or {}
	b = b or {}
	for key, value in pairs(a) do
		if type(value) == "table" then
			if not DudesUtils.Table.Equals(value, b[key]) then
				return false
			end
		elseif b[key] ~= value then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- -- -- -- -- -- -- -- SETTINGS UI -- -- -- -- -- -- -- --

local SETTINGS_TEXT_SIZES = {
    title = 18,
    section = 14,
    normal = 11,
    small = 10,
    button = 11,
}

function DudesUtils.SettingsUI.ApplyTextStyle(fontString, style, justify)
    if not fontString then
        return fontString
    end
    local size = type(style) == "number" and style or SETTINGS_TEXT_SIZES[style or "normal"] or SETTINGS_TEXT_SIZES.normal
    fontString:SetFont(STANDARD_TEXT_FONT, size, "")
    fontString:SetTextColor(1, 1, 1)
    fontString:SetJustifyH(justify or "LEFT")
    if fontString.SetWordWrap then
        fontString:SetWordWrap(true)
    end
    if fontString.SetNonSpaceWrap then
        fontString:SetNonSpaceWrap(true)
    end
    return fontString
end

function DudesUtils.SettingsUI.CreateText(parent, style, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    return DudesUtils.SettingsUI.ApplyTextStyle(text, style, justify)
end

function DudesUtils.SettingsUI.StyleButtonText(button)
    if button and button.GetFontString then
        DudesUtils.SettingsUI.ApplyTextStyle(button:GetFontString(), "button", "CENTER")
    end
end

function DudesUtils.SettingsUI.CreateScrollablePanel(frameName, categoryName, scrollName, contentName)
    local panel = CreateFrame("Frame", frameName, UIParent)
    panel.name = categoryName
    panel.scrollFrame = CreateFrame("ScrollFrame", scrollName, panel, "UIPanelScrollFrameTemplate")
    panel.content = CreateFrame("Frame", contentName, panel.scrollFrame)
    panel.scrollFrame:SetScrollChild(panel.content)
    panel.scrollFrame:EnableMouseWheel(true)
    panel.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = _G[self:GetName() .. "ScrollBar"]
        if not scrollBar then
            return
        end
        local value = scrollBar:GetValue() or 0
        local minValue, maxValue = scrollBar:GetMinMaxValues()
        value = math.max(minValue or 0, math.min(maxValue or 0, value - delta * 32))
        scrollBar:SetValue(value)
    end)
    return panel, panel.scrollFrame, panel.content
end

function DudesUtils.SettingsUI.LayoutScrollablePanel(panel, contentHeight)
    if not panel or not panel.scrollFrame or not panel.content then
        return
    end
    local width = panel:GetWidth() or 620
    local height = panel:GetHeight() or 560
    if width <= 0 then
        width = 620
    end
    if height <= 0 then
        height = 560
    end
    panel.scrollFrame:ClearAllPoints()
    panel.scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -4)
    panel.scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 4)
    panel.content:SetWidth(math.max(260, width - 34))
    panel.content:SetHeight(math.max(tonumber(contentHeight) or 1, height - 8))
end

function DudesUtils.SettingsUI.AnchorTextToContent(text, content, rightInset)
    if text and content then
        text:SetPoint("RIGHT", content, "RIGHT", -(rightInset or 16), 0)
    end
    return text
end

function DudesUtils.SettingsUI.CreateCheckboxLabel(checkbox, content, label)
    local text = DudesUtils.SettingsUI.CreateText(checkbox, "normal")
    text:SetPoint("LEFT", checkbox, "RIGHT", 2, 1)
    text:SetPoint("RIGHT", content, "RIGHT", -16, 0)
    text:SetHeight(24)
    text:SetText(label)
    checkbox.text = text
    return text
end

-- -- -- -- -- -- -- -- NEXT UPDATE -- -- -- -- -- -- -- --

function DudesUtils.OnNextUpdate(callback)
    table.insert(nextUpdateCallbacks, callback)
	if not hiddenFrame:GetScript("OnUpdate") then
        hiddenFrame:SetScript("OnUpdate", onUpdate)
    end
end

-- -- -- -- -- -- -- -- DIALOGS -- -- -- -- -- -- -- --

local dialogFrame
local dialogScale = 1
local DIALOG_PADDING = 22
local DIALOG_BUTTON_WIDTH = 126
local DIALOG_BUTTON_HEIGHT = 24

local function clampDialogValue(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function setDialogBackdrop(frame, r, g, b, a)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(r, g, b, a)
    frame:SetBackdropBorderColor(0.32, 0.38, 0.46, 1)
end

local function createDialogButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(DIALOG_BUTTON_WIDTH)
    button:SetHeight(DIALOG_BUTTON_HEIGHT)
    setDialogBackdrop(button, 0.055, 0.065, 0.08, 1)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetAllPoints(button)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetTextColor(1, 1, 1)
    button:SetFontString(label)

    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.72, 0.86, 1, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.32, 0.38, 0.46, 1)
        self:SetBackdropColor(0.055, 0.065, 0.08, 1)
    end)
    button:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(0.035, 0.042, 0.055, 1)
    end)
    button:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(0.055, 0.065, 0.08, 1)
    end)
    return button
end

local function measureDialogText(fontString, text, width)
    fontString:SetWidth(width)
    fontString:SetText(text or "")
    return math.max(1, math.ceil(fontString:GetStringHeight() or 14))
end

local function layoutDialog(frame)
    local options = frame.options or {}
    local width = clampDialogValue(tonumber(options.width) or 480, 360, 720)
    local contentWidth = width - DIALOG_PADDING * 2
    local y = -18

    frame:SetWidth(width)

    local title = tostring(options.title or "")
    if title ~= "" then
        local titleHeight = measureDialogText(frame.title, title, contentWidth)
        frame.title:ClearAllPoints()
        frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", DIALOG_PADDING, y)
        frame.title:SetHeight(titleHeight)
        frame.title:Show()
        y = y - titleHeight - 12
    else
        frame.title:Hide()
    end

    local message = tostring(options.text or "")
    if message ~= "" then
        local messageHeight = measureDialogText(frame.message, message, contentWidth)
        frame.message:ClearAllPoints()
        frame.message:SetPoint("TOPLEFT", frame, "TOPLEFT", DIALOG_PADDING, y)
        frame.message:SetHeight(messageHeight)
        frame.message:Show()
        y = y - messageHeight - 14
    else
        frame.message:Hide()
    end

    if options.hasEditBox then
        frame.editBox:ClearAllPoints()
        frame.editBox:SetPoint("TOPLEFT", frame, "TOPLEFT", DIALOG_PADDING, y)
        frame.editBox:SetWidth(contentWidth)
        frame.editBox:Show()
        y = y - 24 - 10
    else
        frame.editBox:Hide()
    end

    local errorText = tostring(frame.errorMessage or "")
    if errorText ~= "" then
        local errorHeight = measureDialogText(frame.errorText, errorText, contentWidth)
        frame.errorText:ClearAllPoints()
        frame.errorText:SetPoint("TOPLEFT", frame, "TOPLEFT", DIALOG_PADDING, y)
        frame.errorText:SetHeight(errorHeight)
        frame.errorText:Show()
        y = y - errorHeight - 12
    else
        frame.errorText:Hide()
    end

    frame.acceptButton:ClearAllPoints()
    frame.cancelButton:ClearAllPoints()
    local totalButtonWidth = DIALOG_BUTTON_WIDTH * 2 + 12
    frame.acceptButton:SetPoint("TOPLEFT", frame, "TOPLEFT", (width - totalButtonWidth) / 2, y)
    frame.cancelButton:SetPoint("LEFT", frame.acceptButton, "RIGHT", 12, 0)
    frame.acceptButton:SetText(options.acceptText or ACCEPT or "OK")
    frame.cancelButton:SetText(options.cancelText or CANCEL or "Abbrechen")
    y = y - DIALOG_BUTTON_HEIGHT

    frame:SetHeight(math.max(104, -y + 18))
end

local function closeDialog(frame, accepted)
    frame.accepted = accepted and true or false
    frame:Hide()
end

local function acceptDialog(frame)
    local options = frame.options or {}
    local value = options.hasEditBox and frame.editBox:GetText() or nil
    if options.onAccept then
        local accepted, errorMessage = options.onAccept(value, options.data, frame)
        if accepted == false then
            frame.errorMessage = errorMessage or "Eingabe ungültig"
            layoutDialog(frame)
            if options.hasEditBox then
                frame.editBox:SetFocus()
                frame.editBox:HighlightText()
            end
            return
        end
    end
    closeDialog(frame, true)
end

local function createDialogFrame()
    local frame = CreateFrame("Frame", "DudesUtilsDialogFrame", UIParent)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:RegisterForDrag("LeftButton")
    setDialogBackdrop(frame, 0.025, 0.03, 0.04, 1)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetJustifyH("CENTER")
    frame.title:SetTextColor(1, 1, 1)
    frame.title:SetWordWrap(true)
    if frame.title.SetNonSpaceWrap then
        frame.title:SetNonSpaceWrap(true)
    end

    frame.message = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.message:SetJustifyH("CENTER")
    frame.message:SetTextColor(1, 1, 1)
    frame.message:SetWordWrap(true)
    if frame.message.SetNonSpaceWrap then
        frame.message:SetNonSpaceWrap(true)
    end

    frame.editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.editBox:SetHeight(24)
    frame.editBox:SetAutoFocus(false)
    frame.editBox:SetFont(STANDARD_TEXT_FONT, SETTINGS_TEXT_SIZES.normal, "")
    frame.editBox:SetTextColor(1, 1, 1)
    frame.editBox:SetTextInsets(6, 6, 0, 0)

    frame.errorText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.errorText:SetJustifyH("LEFT")
    frame.errorText:SetTextColor(1, 1, 1)
    frame.errorText:SetWordWrap(true)
    if frame.errorText.SetNonSpaceWrap then
        frame.errorText:SetNonSpaceWrap(true)
    end

    frame.acceptButton = createDialogButton(frame)
    frame.cancelButton = createDialogButton(frame)

    frame.acceptButton:SetScript("OnClick", function()
        acceptDialog(frame)
    end)
    frame.cancelButton:SetScript("OnClick", function()
        closeDialog(frame, false)
    end)
    frame.editBox:SetScript("OnEnterPressed", function()
        acceptDialog(frame)
    end)
    frame.editBox:SetScript("OnEscapePressed", function()
        closeDialog(frame, false)
    end)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    frame:SetScript("OnMouseWheel", function(self, delta)
        if IsControlKeyDown and IsControlKeyDown() then
            dialogScale = clampDialogValue(dialogScale + delta * 0.05, 0.5, 2)
            self:SetScale(dialogScale)
        end
    end)
    frame:SetScript("OnHide", function(self)
        local options = self.options
        local accepted = self.accepted
        self.options = nil
        self.errorMessage = nil
        self.accepted = nil
        self.editBox:ClearFocus()
        if options and not accepted and options.onCancel then
            options.onCancel(options.data, self)
        end
    end)

    if UISpecialFrames and not DudesUtils.Array.Contains(UISpecialFrames, frame:GetName()) then
        table.insert(UISpecialFrames, frame:GetName())
    end
    frame:Hide()
    return frame
end

function DudesUtils.Dialog.Show(options)
    options = options or {}
    dialogFrame = dialogFrame or createDialogFrame()
    if dialogFrame:IsShown() then
        dialogFrame:Hide()
    end
    dialogFrame.options = options
    dialogFrame.accepted = nil
    dialogFrame.errorMessage = options.errorText
    dialogFrame:SetScale(dialogScale)
    dialogFrame.editBox:SetMaxLetters(tonumber(options.maxLetters) or 0)
    dialogFrame.editBox:SetText(options.inputText or "")
    layoutDialog(dialogFrame)
    dialogFrame:Show()
    if options.hasEditBox then
        dialogFrame.editBox:SetFocus()
        if options.highlightInput ~= false then
            dialogFrame.editBox:HighlightText()
        end
    end
    return dialogFrame
end

function DudesUtils.Dialog.Hide()
    if dialogFrame and dialogFrame:IsShown() then
        closeDialog(dialogFrame, false)
    end
end
