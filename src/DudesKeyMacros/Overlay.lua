local ADDON = DudesKeyMacros

local overlay
local keyButtons = {}
local resizeGrip
local loadDialog
local loadRows = {}
local loadOffset = 1

local DEFAULT_WIDTH = 1120
local DEFAULT_HEIGHT = 430
local MIN_WIDTH = 760
local MIN_HEIGHT = 360

local OUTER_PADDING = 28
local PANEL_PADDING = 10
local SECTION_GAP = 10
local KEY_GAP = 8
local CONTROL_HEIGHT = 18
local KEYBOARD_COLS = 13
local MOUSE_COLS = 2
local LAYOUT_ROWS = 5
local DIALOG_FRAME_LEVEL = 70

local keyLabels = {
    ESCAPE = "Esc",
    TAB = "Tab",
    MOUSEWHEELUP = "Wheel Up",
    MOUSEWHEELDOWN = "Wheel Dn",
    BUTTON3 = "Wheel Click",
    BUTTON4 = "Back",
    BUTTON5 = "Forward",
}

local keyDefs = {
    { "ESCAPE", "Esc", "keyboard", 0, 0 },
    { "F1", nil, "keyboard", 1, 0 }, { "F2", nil, "keyboard", 2, 0 }, { "F3", nil, "keyboard", 3, 0 }, { "F4", nil, "keyboard", 4, 0 },
    { "F5", nil, "keyboard", 5, 0 }, { "F6", nil, "keyboard", 6, 0 }, { "F7", nil, "keyboard", 7, 0 }, { "F8", nil, "keyboard", 8, 0 },
    { "F9", nil, "keyboard", 9, 0 }, { "F10", nil, "keyboard", 10, 0 }, { "F11", nil, "keyboard", 11, 0 }, { "F12", nil, "keyboard", 12, 0 },

    { "^", nil, "keyboard", 0, 1 }, { "1", nil, "keyboard", 1, 1 }, { "2", nil, "keyboard", 2, 1 }, { "3", nil, "keyboard", 3, 1 }, { "4", nil, "keyboard", 4, 1 }, { "5", nil, "keyboard", 5, 1 }, { "6", nil, "keyboard", 6, 1 }, { "7", nil, "keyboard", 7, 1 }, { "8", nil, "keyboard", 8, 1 }, { "9", nil, "keyboard", 9, 1 }, { "0", nil, "keyboard", 10, 1 }, { "ß", nil, "keyboard", 11, 1 }, { "´", nil, "keyboard", 12, 1 },
    { "TAB", "Tab", "keyboard", 0, 2 }, { "Q", nil, "keyboard", 1, 2 }, { "W", nil, "keyboard", 2, 2 }, { "E", nil, "keyboard", 3, 2 }, { "R", nil, "keyboard", 4, 2 }, { "T", nil, "keyboard", 5, 2 }, { "Z", nil, "keyboard", 6, 2 }, { "U", nil, "keyboard", 7, 2 }, { "I", nil, "keyboard", 8, 2 }, { "O", nil, "keyboard", 9, 2 }, { "P", nil, "keyboard", 10, 2 }, { "Ü", nil, "keyboard", 11, 2 }, { "+", nil, "keyboard", 12, 2 },
    { "A", nil, "keyboard", 1, 3 }, { "S", nil, "keyboard", 2, 3 }, { "D", nil, "keyboard", 3, 3 }, { "F", nil, "keyboard", 4, 3 }, { "G", nil, "keyboard", 5, 3 }, { "H", nil, "keyboard", 6, 3 }, { "J", nil, "keyboard", 7, 3 }, { "K", nil, "keyboard", 8, 3 }, { "L", nil, "keyboard", 9, 3 }, { "Ö", nil, "keyboard", 10, 3 }, { "Ä", nil, "keyboard", 11, 3 }, { "#", nil, "keyboard", 12, 3 },
    { "<", nil, "keyboard", 0, 4 }, { "Y", nil, "keyboard", 1, 4 }, { "X", nil, "keyboard", 2, 4 }, { "C", nil, "keyboard", 3, 4 }, { "V", nil, "keyboard", 4, 4 }, { "B", nil, "keyboard", 5, 4 }, { "N", nil, "keyboard", 6, 4 }, { "M", nil, "keyboard", 7, 4 }, { ",", nil, "keyboard", 8, 4 }, { ".", nil, "keyboard", 9, 4 }, { "-", nil, "keyboard", 10, 4 },

    { "BUTTON4", "Back", "mouse", 0, 1.5 },
    { "BUTTON5", "Forward", "mouse", 0, 2.5 },
    { "MOUSEWHEELUP", "Wheel Up", "mouse", 1, 1 },
    { "BUTTON3", "Wheel Click", "mouse", 1, 2 },
    { "MOUSEWHEELDOWN", "Wheel Dn", "mouse", 1, 3 },
}

local function setBackdrop(frame, r, g, b, a)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(r, g, b, a)
    frame:SetBackdropBorderColor(0.35, 0.45, 0.65, 1)
end

local function createText(parent, size, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetFont(STANDARD_TEXT_FONT, size or 11)
    text:SetJustifyH(justify or "LEFT")
    return text
end

local function createSolidTexture(parent, r, g, b)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(parent)
    texture:SetTexture(r, g, b, 1)
    return texture
end

local function fitButtonLabel(button, width)
    local maxWidth = math.max(10, width - 12)
    local label = button.label
    local text = button.labelText or ""
    local fontSize = 12

    if maxWidth < 38 then
        fontSize = 9
    elseif maxWidth < 50 then
        fontSize = 10
    end

    label:SetFont(STANDARD_TEXT_FONT, fontSize)
    label:SetWidth(maxWidth)
    label:SetHeight(fontSize + 3)
    if label.SetNonSpaceWrap then
        label:SetNonSpaceWrap(false)
    end
    if label.SetWordWrap then
        label:SetWordWrap(false)
    end

    label:SetText(text)
    while label:GetStringWidth() > maxWidth and fontSize > 7 do
        fontSize = fontSize - 1
        label:SetFont(STANDARD_TEXT_FONT, fontSize)
        label:SetHeight(fontSize + 3)
    end

    if label:GetStringWidth() <= maxWidth then
        return
    end

    local clipped = text
    while string.len(clipped) > 1 do
        clipped = string.sub(clipped, 1, string.len(clipped) - 1)
        label:SetText(clipped)
        if label:GetStringWidth() <= maxWidth then
            return
        end
    end
end

local function getOverlaySettings()
    local settings = ADDON.GetSettings()
    settings.overlay = settings.overlay or {}
    return settings.overlay
end

local function saveOverlayPlacement()
    if not overlay then
        return
    end

    local overlaySettings = getOverlaySettings()
    local point, _, relativePoint, xOfs, yOfs = overlay:GetPoint()
    overlaySettings.point = point
    overlaySettings.relativePoint = relativePoint
    overlaySettings.xOfs = xOfs
    overlaySettings.yOfs = yOfs
    overlaySettings.width = overlay:GetWidth()
    overlaySettings.height = overlay:GetHeight()
end

local function loadOverlayPlacement()
    local overlaySettings = getOverlaySettings()
    overlay:SetWidth(math.max(MIN_WIDTH, overlaySettings.width or DEFAULT_WIDTH))
    overlay:SetHeight(math.max(MIN_HEIGHT, overlaySettings.height or DEFAULT_HEIGHT))
    overlay:ClearAllPoints()
    overlay:SetPoint(overlaySettings.point or "CENTER", UIParent, overlaySettings.relativePoint or "CENTER", overlaySettings.xOfs or 0, overlaySettings.yOfs or 0)
end

local function getLayoutMetrics()
    local width = math.max(MIN_WIDTH, overlay:GetWidth() or DEFAULT_WIDTH)
    local height = math.max(MIN_HEIGHT, overlay:GetHeight() or DEFAULT_HEIGHT)
    local contentWidth = math.max(1, width - OUTER_PADDING * 2)
    local contentHeight = math.max(1, height - OUTER_PADDING * 2 - CONTROL_HEIGHT)
    local totalKeyGaps = (KEYBOARD_COLS - 1) * KEY_GAP + (MOUSE_COLS - 1) * KEY_GAP
    local totalPanelPadding = PANEL_PADDING * 4
    local keyWidth = (contentWidth - SECTION_GAP - totalPanelPadding - totalKeyGaps) / (KEYBOARD_COLS + MOUSE_COLS)
    local keyHeight = (contentHeight - PANEL_PADDING * 2 - (LAYOUT_ROWS - 1) * KEY_GAP) / LAYOUT_ROWS

    keyWidth = math.max(30, keyWidth)
    keyHeight = math.max(28, keyHeight)

    local keyboardWidth = PANEL_PADDING * 2 + KEYBOARD_COLS * keyWidth + (KEYBOARD_COLS - 1) * KEY_GAP
    local mouseWidth = PANEL_PADDING * 2 + MOUSE_COLS * keyWidth + (MOUSE_COLS - 1) * KEY_GAP
    local panelHeight = PANEL_PADDING * 2 + LAYOUT_ROWS * keyHeight + (LAYOUT_ROWS - 1) * KEY_GAP

    return {
        keyWidth = keyWidth,
        keyHeight = keyHeight,
        keyboardX = OUTER_PADDING,
        mouseX = OUTER_PADDING + keyboardWidth + SECTION_GAP,
        panelY = OUTER_PADDING,
        keyboardWidth = keyboardWidth,
        mouseWidth = mouseWidth,
        panelHeight = panelHeight,
    }
end

local function layoutKeyButton(button)
    local metrics = getLayoutMetrics()
    local def = button.layoutDef
    local col = def[4]
    local row = def[5]
    local panelX = def[3] == "mouse" and metrics.mouseX or metrics.keyboardX
    local width = metrics.keyWidth
    local height = metrics.keyHeight
    local iconSize = math.max(12, math.min(18, math.min(width, height) * 0.34))
    local iconGap = 3

    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", overlay, "TOPLEFT", panelX + PANEL_PADDING + col * (width + KEY_GAP), -metrics.panelY - PANEL_PADDING - row * (height + KEY_GAP))
    button:SetWidth(width)
    button:SetHeight(height)

    button.label:ClearAllPoints()
    button.label:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -4)
    fitButtonLabel(button, width)

    for i = 1, 4 do
        local texture = button.icons[i]
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        texture:ClearAllPoints()
        texture:SetWidth(iconSize)
        texture:SetHeight(iconSize)
        texture:SetPoint("TOPLEFT", button, "TOPLEFT", 7 + col * (iconSize + iconGap), -19 - row * (iconSize + iconGap))
    end

    button.markerText:ClearAllPoints()
    button.markerText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 4)

    button.conflictText:ClearAllPoints()
    button.conflictText:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 5, 4)
    button.conflictText:SetPoint("RIGHT", button.markerText, "LEFT", -3, 0)
end

local function layoutOverlay()
    if not overlay or not overlay.closeButton then
        return
    end

    overlay.closeButton:ClearAllPoints()
    overlay.closeButton:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -12, -10)

    overlay.buttonAnchor:ClearAllPoints()
    overlay.buttonAnchor:SetPoint("BOTTOM", overlay, "BOTTOM", 0, 18)

    overlay.applyButton:ClearAllPoints()
    overlay.applyButton:SetPoint("RIGHT", overlay.buttonAnchor, "LEFT", -4, 0)
    overlay.discardButton:ClearAllPoints()
    overlay.discardButton:SetPoint("LEFT", overlay.applyButton, "RIGHT", 8, 0)
    overlay.loadButton:ClearAllPoints()
    overlay.loadButton:SetPoint("RIGHT", overlay.buttonAnchor, "LEFT", -4, 0)
    overlay.saveButton:ClearAllPoints()
    overlay.saveButton:SetPoint("LEFT", overlay.loadButton, "RIGHT", 8, 0)

    for _, button in pairs(keyButtons) do
        layoutKeyButton(button)
    end

    if resizeGrip then
        resizeGrip:ClearAllPoints()
        resizeGrip:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -5, 5)
    end
end

local function refreshLayoutActions()
    if not overlay then
        return
    end

    if ADDON.HasPendingChanges and ADDON.HasPendingChanges() then
        overlay.applyButton:Show()
        overlay.discardButton:Show()
        overlay.loadButton:Hide()
        overlay.saveButton:Hide()
        overlay.closeButton:Disable()
    else
        overlay.applyButton:Hide()
        overlay.discardButton:Hide()
        overlay.loadButton:Show()
        overlay.saveButton:Show()
        overlay.closeButton:Enable()
    end
end

local function updateIconGrid(button, icons)
    for i = 1, 4 do
        local texture = button.icons[i]
        if icons and icons[i] then
            texture:SetTexture(icons[i])
            texture:Show()
        else
            texture:Hide()
        end
    end
end

local function updateKeyButton(key, button)
    local binding = ADDON.GetBinding(key)
    local macrotext = binding and binding.macrotext or ""
    local icons = binding and binding.icons or {}
    local markers = ADDON.GetMacroMarkers and ADDON.GetMacroMarkers(macrotext) or {}
    local conflicts = ADDON.GetConflicts(key)

    updateIconGrid(button, icons)
    button.markerText:SetText(table.concat(markers, " "))
    if #conflicts > 0 then
        button.conflictText:SetText(ADDON.GetBindingDisplayName(conflicts[1].action))
        button.conflictText:Show()
    else
        button.conflictText:Hide()
    end

    if macrotext ~= "" then
        button:SetBackdropBorderColor(0.5, 0.8, 1, 1)
    elseif #conflicts > 0 then
        button:SetBackdropBorderColor(1, 0.35, 0.25, 1)
    else
        button:SetBackdropBorderColor(0.2, 0.25, 0.3, 1)
    end
end

local function refreshLoadDialog()
    if not loadDialog then
        return
    end

    local profiles = ADDON.GetLayoutProfiles and ADDON.GetLayoutProfiles() or {}
    if loadOffset > #profiles then
        loadOffset = math.max(1, #profiles - #loadRows + 1)
    end
    for i, row in ipairs(loadRows) do
        local profile = profiles[loadOffset + i - 1]
        if profile then
            row.profileId = profile.id
            row.name:SetText(profile.name or "")
            row.date:SetText(profile.createdAt or "")
            row.character:SetText(profile.characterName or "")
            row.class:SetText(profile.className or "")
            row.spec:SetText(profile.specText or "")
            if profile.system then
                row.delete:Hide()
            else
                row.delete:Show()
            end
            row:Show()
        else
            row.profileId = nil
            row:Hide()
        end
    end

    if loadDialog.prevButton then
        if loadOffset > 1 then
            loadDialog.prevButton:Enable()
        else
            loadDialog.prevButton:Disable()
        end
    end
    if loadDialog.nextButton then
        if loadOffset + #loadRows <= #profiles then
            loadDialog.nextButton:Enable()
        else
            loadDialog.nextButton:Disable()
        end
    end
end

local function showLoadDialog()
    if not loadDialog then
        loadDialog = CreateFrame("Frame", "DudesKeyMacrosLoadLayoutDialog", UIParent)
        loadDialog:SetWidth(760)
        loadDialog:SetHeight(430)
        loadDialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        loadDialog:SetFrameStrata("FULLSCREEN_DIALOG")
        loadDialog:SetFrameLevel(DIALOG_FRAME_LEVEL)
        loadDialog:EnableMouse(true)
        if loadDialog.EnableKeyboard then
            loadDialog:EnableKeyboard(true)
        end
        loadDialog:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:Hide()
            end
        end)
        setBackdrop(loadDialog, 0.02, 0.025, 0.035, 1)
        createSolidTexture(loadDialog, 0.02, 0.025, 0.035)

        local title = createText(loadDialog, 15)
        title:SetPoint("TOPLEFT", loadDialog, "TOPLEFT", 18, -16)
        title:SetText("Layout laden")

        local headers = {
            { "Name", 18 },
            { "Datum", 210 },
            { "Charakter", 330 },
            { "Klasse", 450 },
            { "Spec", 540 },
        }
        for _, header in ipairs(headers) do
            local text = createText(loadDialog, 10)
            text:SetPoint("TOPLEFT", loadDialog, "TOPLEFT", header[2], -46)
            text:SetText(header[1])
            text:SetTextColor(0.8, 0.8, 0.8)
        end

        for i = 1, 10 do
            local row = CreateFrame("Button", nil, loadDialog)
            row:SetFrameLevel(DIALOG_FRAME_LEVEL + 1)
            row:SetWidth(720)
            row:SetHeight(28)
            row:SetPoint("TOPLEFT", loadDialog, "TOPLEFT", 18, -64 - (i - 1) * 31)
            setBackdrop(row, 0.04, 0.05, 0.07, 1)
            row:SetScript("OnClick", function(self)
                if self.profileId and ADDON.LoadLayoutProfile then
                    ADDON.LoadLayoutProfile(self.profileId)
                    loadDialog:Hide()
                end
            end)

            row.name = createText(row, 10)
            row.name:SetPoint("LEFT", row, "LEFT", 6, 0)
            row.name:SetWidth(180)
            row.date = createText(row, 10)
            row.date:SetPoint("LEFT", row, "LEFT", 192, 0)
            row.date:SetWidth(110)
            row.character = createText(row, 10)
            row.character:SetPoint("LEFT", row, "LEFT", 312, 0)
            row.character:SetWidth(110)
            row.class = createText(row, 10)
            row.class:SetPoint("LEFT", row, "LEFT", 432, 0)
            row.class:SetWidth(80)
            row.spec = createText(row, 10)
            row.spec:SetPoint("LEFT", row, "LEFT", 522, 0)
            row.spec:SetWidth(70)

            row.delete = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.delete:SetFrameLevel(DIALOG_FRAME_LEVEL + 2)
            row.delete:SetWidth(70)
            row.delete:SetHeight(20)
            row.delete:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            row.delete:SetText("Löschen")
            row.delete:SetScript("OnClick", function(self)
                local parent = self:GetParent()
                if parent.profileId and ADDON.DeleteLayoutProfile then
                    ADDON.DeleteLayoutProfile(parent.profileId)
                    refreshLoadDialog()
                end
            end)

            loadRows[i] = row
        end

        local close = CreateFrame("Button", nil, loadDialog, "UIPanelButtonTemplate")
        close:SetFrameLevel(DIALOG_FRAME_LEVEL + 2)
        close:SetWidth(70)
        close:SetHeight(24)
        close:SetPoint("BOTTOMRIGHT", loadDialog, "BOTTOMRIGHT", -16, 16)
        close:SetText("Schließen")
        close:SetScript("OnClick", function()
            loadDialog:Hide()
        end)

        loadDialog.prevButton = CreateFrame("Button", nil, loadDialog, "UIPanelButtonTemplate")
        loadDialog.prevButton:SetFrameLevel(DIALOG_FRAME_LEVEL + 2)
        loadDialog.prevButton:SetWidth(70)
        loadDialog.prevButton:SetHeight(24)
        loadDialog.prevButton:SetPoint("RIGHT", close, "LEFT", -8, 0)
        loadDialog.prevButton:SetText("Zurück")
        loadDialog.prevButton:SetScript("OnClick", function()
            loadOffset = math.max(1, loadOffset - #loadRows)
            refreshLoadDialog()
        end)

        loadDialog.nextButton = CreateFrame("Button", nil, loadDialog, "UIPanelButtonTemplate")
        loadDialog.nextButton:SetFrameLevel(DIALOG_FRAME_LEVEL + 2)
        loadDialog.nextButton:SetWidth(70)
        loadDialog.nextButton:SetHeight(24)
        loadDialog.nextButton:SetPoint("RIGHT", loadDialog.prevButton, "LEFT", -8, 0)
        loadDialog.nextButton:SetText("Weiter")
        loadDialog.nextButton:SetScript("OnClick", function()
            loadOffset = loadOffset + #loadRows
            refreshLoadDialog()
        end)
    end

    loadOffset = 1
    refreshLoadDialog()
    loadDialog:Show()
end

local function createKeyButton(parent, def)
    local key = def[1]
    local button = CreateFrame("Button", nil, parent)
    button:SetFrameLevel(parent:GetFrameLevel() + 1)
    button.layoutDef = def
    setBackdrop(button, 0.04, 0.05, 0.07, 1)
    button:SetAlpha(1)

    button.solidBackground = button:CreateTexture(nil, "BACKGROUND")
    button.solidBackground:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    button.solidBackground:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.solidBackground:SetTexture(0.04, 0.05, 0.07, 1)

    button.key = key
    button.label = createText(button, 12)
    button.labelText = def[2] or keyLabels[key] or key
    button.label:SetText(button.labelText)

    button.icons = {}
    for i = 1, 4 do
        local texture = button:CreateTexture(nil, "ARTWORK")
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icons[i] = texture
    end

    button.markerText = createText(button, 9, "RIGHT")
    button.markerText:SetTextColor(0.8, 0.85, 1)

    button.conflictText = createText(button, 8, "LEFT")
    button.conflictText:SetTextColor(1, 0.35, 0.25)
    button.conflictText:Hide()

    button:SetScript("OnClick", function(self)
        if ADDON.OpenEditor then
            ADDON.OpenEditor(self.key)
        end
    end)

    keyButtons[key] = button
    return button
end

local function createHeader(parent)
    parent.closeButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    parent.closeButton:SetWidth(24)
    parent.closeButton:SetHeight(22)
    parent.closeButton:SetFrameLevel(parent:GetFrameLevel() + 2)
    parent.closeButton:SetText("X")
    parent.closeButton:SetScript("OnClick", function()
        parent:Hide()
    end)

    parent.buttonAnchor = CreateFrame("Frame", nil, parent)
    parent.buttonAnchor:SetWidth(1)
    parent.buttonAnchor:SetHeight(1)

    parent.applyButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    parent.applyButton:SetWidth(94)
    parent.applyButton:SetHeight(24)
    parent.applyButton:SetText("Anwenden")
    parent.applyButton:SetScript("OnClick", function()
        if ADDON.ApplyDraftLayout then
            ADDON.ApplyDraftLayout()
        end
    end)

    parent.discardButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    parent.discardButton:SetWidth(94)
    parent.discardButton:SetHeight(24)
    parent.discardButton:SetText("Verwerfen")
    parent.discardButton:SetScript("OnClick", function()
        if ADDON.DiscardDraftLayout then
            ADDON.DiscardDraftLayout()
        end
    end)

    parent.loadButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    parent.loadButton:SetWidth(94)
    parent.loadButton:SetHeight(24)
    parent.loadButton:SetText("Laden")
    parent.loadButton:SetScript("OnClick", showLoadDialog)

    parent.saveButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    parent.saveButton:SetWidth(94)
    parent.saveButton:SetHeight(24)
    parent.saveButton:SetText("Speichern")
    parent.saveButton:SetScript("OnClick", function()
        StaticPopupDialogs["DUDES_KEY_MACROS_SAVE_LAYOUT"] = StaticPopupDialogs["DUDES_KEY_MACROS_SAVE_LAYOUT"] or {
            text = "Layout-Name",
            button1 = "Speichern",
            button2 = "Abbrechen",
            hasEditBox = 1,
            maxLetters = 64,
            OnAccept = function(self)
                local name = self.editBox and self.editBox:GetText() or ""
                if not ADDON.SaveAppliedLayoutProfile or not ADDON.SaveAppliedLayoutProfile(name) then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffDudesKeyMacros:|r Layout name must be unique.")
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
                end
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
        }
        local popup = StaticPopup_Show("DUDES_KEY_MACROS_SAVE_LAYOUT")
        if popup then
            popup:SetFrameStrata("TOOLTIP")
            popup:SetFrameLevel(DIALOG_FRAME_LEVEL + 20)
        end
    end)
end

local function createLayoutButtons(parent)
    for _, def in ipairs(keyDefs) do
        createKeyButton(parent, def)
    end
end

local function createResizeGrip(parent)
    resizeGrip = CreateFrame("Button", nil, parent)
    resizeGrip:SetWidth(16)
    resizeGrip:SetHeight(16)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:RegisterForDrag("LeftButton")
    resizeGrip:SetScript("OnDragStart", function()
        if parent.StartSizing then
            parent:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeGrip:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        saveOverlayPlacement()
        layoutOverlay()
    end)
end

function ADDON.CreateOverlay()
    if overlay then
        return overlay
    end

    overlay = CreateFrame("Frame", "DudesKeyMacrosOverlay", UIParent)
    overlay:SetFrameStrata("DIALOG")
    overlay:EnableMouse(true)
    if overlay.EnableKeyboard then
        overlay:EnableKeyboard(true)
    end
    overlay:SetMovable(true)
    if overlay.SetResizable then
        overlay:SetResizable(true)
    end
    if overlay.SetMinResize then
        overlay:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
    end
    overlay:RegisterForDrag("LeftButton")
    overlay:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    overlay:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        saveOverlayPlacement()
    end)
    overlay:SetScript("OnSizeChanged", function()
        layoutOverlay()
    end)
    overlay:SetScript("OnKeyDown", function(self, key)
        if key ~= "ESCAPE" then
            return
        end
        if ADDON.HasPendingChanges and ADDON.HasPendingChanges() then
            DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffDudesKeyMacros:|r Apply or discard pending changes before closing the layout.")
        else
            self:Hide()
        end
    end)
    setBackdrop(overlay, 0.02, 0.025, 0.035, 0.72)

    loadOverlayPlacement()
    createHeader(overlay)
    createLayoutButtons(overlay)
    createResizeGrip(overlay)
    layoutOverlay()

    overlay:Hide()
    return overlay
end

function ADDON.RefreshOverlay()
    if not overlay then
        return
    end

    for key, button in pairs(keyButtons) do
        updateKeyButton(key, button)
    end
    refreshLayoutActions()
    layoutOverlay()
end

function ADDON.ToggleOverlay()
    ADDON.CreateOverlay()
    ADDON.RefreshOverlay()
    if overlay:IsShown() then
        if ADDON.HasPendingChanges and ADDON.HasPendingChanges() then
            DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffDudesKeyMacros:|r Apply or discard pending changes before closing the layout.")
        else
            overlay:Hide()
        end
    else
        overlay:Show()
    end
end

function ADDON.ShowOverlay()
    ADDON.CreateOverlay()
    ADDON.RefreshOverlay()
    overlay:Show()
end
