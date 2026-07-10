local ADDON = DudesKeyMacros

local editor
local actionPicker
local currentKey
local selectedIcons = {}
local interfaceRows = {}
local actionButtons = {}
local suggestionButtons = {}
local selectedIconButtons = {}
local spellClickHooked
local pickerBindingKey
local pendingActionMove

local EDITOR_FRAME_LEVEL = 40
local PICKER_FRAME_LEVEL = 80

local function copyArray(source)
    local copy = {}
    for i, value in ipairs(source or {}) do
        copy[i] = value
    end
    return copy
end

local function arrayContains(array, value)
    for _, item in ipairs(array or {}) do
        if item == value then
            return true
        end
    end
    return false
end

local function removeFromArray(array, value)
    for i = #array, 1, -1 do
        if array[i] == value then
            table.remove(array, i)
        end
    end
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

local function updateSelectedIcons()
    for i = 1, 8 do
        local button = selectedIconButtons[i]
        if selectedIcons[i] then
            button.texture:SetTexture(selectedIcons[i])
            button.texture:Show()
            button:Show()
        else
            button.texture:Hide()
            button:Hide()
        end
    end
end

local function refreshSuggestionSelection()
    for _, button in ipairs(suggestionButtons) do
        if button.texturePath and arrayContains(selectedIcons, button.texturePath) then
            button:SetBackdropBorderColor(0.3, 1, 0.45, 1)
        else
            button:SetBackdropBorderColor(0.25, 0.3, 0.4, 1)
        end
    end
end

local function toggleSelectedIcon(texture)
    if not texture or texture == "" then
        return
    end
    if arrayContains(selectedIcons, texture) then
        removeFromArray(selectedIcons, texture)
    else
        table.insert(selectedIcons, texture)
    end
    updateSelectedIcons()
    refreshSuggestionSelection()
end

local function setSuggestionButton(button, suggestion)
    if suggestion then
        button.texturePath = suggestion.texture
        button.texture:SetTexture(suggestion.texture)
        button.text:SetText(suggestion.name or suggestion.texture)
        button:Show()
    else
        button.texturePath = nil
        button:Hide()
    end
end

local function refreshSuggestions()
    local macrotext = editor.macroEditBox:GetText() or ""
    local suggestions = ADDON.GetMacroIconSuggestions(macrotext)
    for i = 1, #suggestionButtons do
        setSuggestionButton(suggestionButtons[i], suggestions[i])
    end
    refreshSuggestionSelection()
end

local function refreshMacroScrollBar()
    if not editor or not editor.macroScrollFrame or not editor.macroEditBox then
        return
    end

    if editor.macroScrollFrame.UpdateScrollChildRect then
        editor.macroScrollFrame:UpdateScrollChildRect()
    end

    local scrollBar = _G["DudesKeyMacrosEditorScrollFrameScrollBar"]
    if not scrollBar then
        return
    end

    local contentHeight = 0
    if editor.macroEditBox.GetStringHeight then
        contentHeight = editor.macroEditBox:GetStringHeight() or 0
    else
        contentHeight = editor.macroEditBox:GetHeight() or 0
    end
    if contentHeight > editor.macroScrollFrame:GetHeight() - 8 then
        scrollBar:Show()
        if scrollBar.ScrollUpButton then
            scrollBar.ScrollUpButton:Show()
        end
        if scrollBar.ScrollDownButton then
            scrollBar.ScrollDownButton:Show()
        end
    else
        scrollBar:Hide()
        if scrollBar.ScrollUpButton then
            scrollBar.ScrollUpButton:Hide()
        end
        if scrollBar.ScrollDownButton then
            scrollBar.ScrollDownButton:Hide()
        end
    end
end

local function saveMacroDraft()
    local macrotext = editor.macroEditBox:GetText() or ""
    if macrotext == "" and #selectedIcons == 0 then
        ADDON.ClearBinding(currentKey)
    else
        ADDON.SaveBinding(currentKey, macrotext, copyArray(selectedIcons))
    end
end

local function refreshInterfaceRows()
    local variants = ADDON.GetDefaultBindingKeysForKey(currentKey)
    for i, row in ipairs(interfaceRows) do
        local variant = variants[i]
        local action = variant and ADDON.GetDefaultBindingAction(variant.key) or ""
        row.bindingKey = variant and variant.key or nil
        row.modifier = variant and variant.modifier or nil
        row.keyText:SetText(variant and variant.key or "")
        row.action = action or ""
        if action ~= "" then
            row.actionText:SetText(ADDON.GetBindingDisplayName(action))
            row.actionText:SetTextColor(1, 0.82, 0.1)
            row.clear:Show()
        else
            row.actionText:SetText("<not bound>")
            row.actionText:SetTextColor(0.45, 0.48, 0.52)
            row.clear:Hide()
        end
        if variant then
            row:Show()
        else
            row:Hide()
        end
    end
end

local function applyActionToRow(bindingKey, action)
    ADDON.SetDefaultBindingAction(bindingKey, action or "")
    refreshInterfaceRows()
end

local function confirmAndApplyAction(bindingKey, action, conflict)
    if not conflict then
        applyActionToRow(bindingKey, action)
        if actionPicker then
            actionPicker:Hide()
        end
        return
    end

    StaticPopupDialogs["DUDES_KEY_MACROS_MOVE_BINDING"] = StaticPopupDialogs["DUDES_KEY_MACROS_MOVE_BINDING"] or {
        text = "Diese Aktion ist bereits gebunden an:\n%s\n\nVon dort lösen und hier binden?",
        button1 = "Lösen",
        button2 = "Abbrechen",
        OnAccept = function()
            if not pendingActionMove then
                return
            end
            if pendingActionMove.conflict and pendingActionMove.conflict.bindingKey then
                ADDON.ClearDefaultBindingAction(pendingActionMove.conflict.bindingKey)
            end
            applyActionToRow(pendingActionMove.bindingKey, pendingActionMove.action)
            pendingActionMove = nil
            if actionPicker then
                actionPicker:Hide()
            end
        end,
        OnCancel = function()
            pendingActionMove = nil
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }

    pendingActionMove = {
        bindingKey = bindingKey,
        action = action,
        conflict = conflict,
    }
    local popup = StaticPopup_Show("DUDES_KEY_MACROS_MOVE_BINDING", conflict.bindingKey or conflict.text or "")
    if popup then
        popup:SetFrameStrata("TOOLTIP")
        popup:SetFrameLevel(PICKER_FRAME_LEVEL + 20)
    end
end

local function selectAction(command)
    if not pickerBindingKey or not command then
        return
    end

    local conflict = ADDON.FindDraftBindingForAction(command, pickerBindingKey)
    confirmAndApplyAction(pickerBindingKey, command, conflict)
end

local function refreshActionPicker()
    if not actionPicker then
        return
    end

    local filter = actionPicker.filter:GetText() or ""
    local actions = ADDON.GetAvailableBindingActions(filter)
    for i, button in ipairs(actionButtons) do
        local action = actions[i]
        if action then
            button.command = action.command
            button.text:SetText(action.name)
            button.commandText:SetText(action.command)
            button:Show()
        else
            button.command = nil
            button:Hide()
        end
    end
end

local function createActionPicker()
    if actionPicker then
        return actionPicker
    end

    actionPicker = CreateFrame("Frame", "DudesKeyMacrosActionPicker", UIParent)
    actionPicker:SetWidth(520)
    actionPicker:SetHeight(372)
    actionPicker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    actionPicker:SetFrameStrata("FULLSCREEN_DIALOG")
    actionPicker:SetFrameLevel(PICKER_FRAME_LEVEL)
    actionPicker:EnableMouse(true)
    if actionPicker.EnableKeyboard then
        actionPicker:EnableKeyboard(true)
    end
    actionPicker:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    setBackdrop(actionPicker, 0.02, 0.025, 0.035, 1)
    createSolidTexture(actionPicker, 0.02, 0.025, 0.035)

    actionPicker.title = createText(actionPicker, 14)
    actionPicker.title:SetPoint("TOPLEFT", actionPicker, "TOPLEFT", 16, -14)
    actionPicker.title:SetText("Interface-Aktion wählen")

    local close = CreateFrame("Button", nil, actionPicker, "UIPanelButtonTemplate")
    close:SetFrameLevel(PICKER_FRAME_LEVEL + 2)
    close:SetWidth(32)
    close:SetHeight(26)
    close:SetPoint("TOPRIGHT", actionPicker, "TOPRIGHT", -14, -12)
    close:SetText("X")
    close:SetScript("OnClick", function()
        actionPicker:Hide()
    end)

    actionPicker.filter = CreateFrame("EditBox", nil, actionPicker, "InputBoxTemplate")
    actionPicker.filter:SetWidth(300)
    actionPicker.filter:SetHeight(20)
    actionPicker.filter:SetPoint("TOPLEFT", actionPicker, "TOPLEFT", 18, -44)
    actionPicker.filter:SetAutoFocus(false)
    actionPicker.filter:SetScript("OnTextChanged", refreshActionPicker)

    local clear = CreateFrame("Button", nil, actionPicker, "UIPanelButtonTemplate")
    clear:SetFrameLevel(PICKER_FRAME_LEVEL + 2)
    clear:SetWidth(80)
    clear:SetHeight(22)
    clear:SetPoint("LEFT", actionPicker.filter, "RIGHT", 10, 0)
    clear:SetText("Lösen")
    clear:SetScript("OnClick", function()
        if pickerBindingKey then
            ADDON.ClearDefaultBindingAction(pickerBindingKey)
            refreshInterfaceRows()
        end
        actionPicker:Hide()
    end)
    actionPicker.clearButton = clear

    for i = 1, 14 do
        local button = CreateFrame("Button", nil, actionPicker)
        button:SetFrameLevel(PICKER_FRAME_LEVEL + 1)
        button:SetWidth(236)
        button:SetHeight(34)
        button:SetPoint("TOPLEFT", actionPicker, "TOPLEFT", 18 + ((i - 1) % 2) * 246, -78 - math.floor((i - 1) / 2) * 39)
        setBackdrop(button, 0.045, 0.055, 0.07, 1)
        button.text = createText(button, 11)
        button.text:SetPoint("TOPLEFT", button, "TOPLEFT", 8, -5)
        button.text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        button.text:SetTextColor(1, 0.82, 0.1)
        button.commandText = createText(button, 8)
        button.commandText:SetPoint("TOPLEFT", button.text, "BOTTOMLEFT", 0, -2)
        button.commandText:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        button.commandText:SetTextColor(0.65, 0.7, 0.78)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        local highlight = button:GetHighlightTexture()
        if highlight then
            highlight:SetBlendMode("ADD")
        end
        button:SetScript("OnClick", function(self)
            selectAction(self.command)
        end)
        actionButtons[i] = button
    end

    actionPicker:Hide()
    return actionPicker
end

local function openActionPicker(row)
    if not row or not row.bindingKey then
        return
    end

    createActionPicker()
    pickerBindingKey = row.bindingKey
    actionPicker.title:SetText("Interface-Aktion für " .. row.bindingKey)
    actionPicker.filter:SetText("")
    if ADDON.GetDefaultBindingAction(row.bindingKey) ~= "" then
        actionPicker.clearButton:Show()
    else
        actionPicker.clearButton:Hide()
    end
    refreshActionPicker()
    actionPicker:Show()
end

local function getSpellBookButton(button)
    if type(button) == "table" and button.GetID then
        return button
    end
    if type(this) == "table" and this.GetID then
        return this
    end
    return nil
end

local function getSpellBookType(button)
    local spellButton = getSpellBookButton(button)
    return spellButton and spellButton.bookType or (SpellBookFrame and SpellBookFrame.bookType) or BOOKTYPE_SPELL
end

local function getSelectedSpellBookTab()
    if SpellBookFrame and SpellBookFrame.selectedSkillLine then
        return SpellBookFrame.selectedSkillLine
    end

    local tabIndex = 1
    while _G["SpellBookSkillLineTab" .. tabIndex] do
        local tab = _G["SpellBookSkillLineTab" .. tabIndex]
        local checkedTexture = tab.GetCheckedTexture and tab:GetCheckedTexture()
        if (tab.GetChecked and tab:GetChecked())
            or (checkedTexture and checkedTexture.IsShown and checkedTexture:IsShown())
            or (tab.GetButtonState and tab:GetButtonState() == "PUSHED") then
            return (tab.GetID and tab:GetID()) or tabIndex
        end
        tabIndex = tabIndex + 1
    end

    return nil
end

local function getVisibleSpellButtonSlot(button)
    local spellButton = getSpellBookButton(button)
    local slot = spellButton and spellButton:GetID()
    if not slot or slot <= 0 then
        return nil
    end

    local page = 1
    if SpellBook_GetCurrentPage then
        page = SpellBook_GetCurrentPage() or 1
    end

    return slot + (page - 1) * (SPELLS_PER_PAGE or 12)
end

local function getSpellBookSlotAndBookType(button)
    local spellButton = getSpellBookButton(button)
    local bookType = getSpellBookType(button)

    if spellButton and SpellBook_GetSpellID then
        local slot = SpellBook_GetSpellID(spellButton:GetID())
        if slot then
            return slot, bookType
        end
    end

    local visibleSlot = getVisibleSpellButtonSlot(button)

    if visibleSlot and bookType == BOOKTYPE_SPELL and GetSpellTabInfo then
        local tabIndex = getSelectedSpellBookTab()
        if tabIndex then
            local _, _, offset, numSpells = GetSpellTabInfo(tabIndex)
            if offset then
                local firstSlot = offset + 1
                local lastSlot = offset + (numSpells or 0)
                if visibleSlot >= firstSlot and (numSpells == nil or visibleSlot <= lastSlot) then
                    return visibleSlot, bookType
                end

                local tabSlot = offset + visibleSlot
                if numSpells == nil or tabSlot <= lastSlot then
                    return tabSlot, bookType
                end
            end
        end
    end

    if visibleSlot then
        return visibleSlot, bookType
    end

    if spellButton and SpellBook_GetSpellBookSlot then
        local slot, helperBookType = SpellBook_GetSpellBookSlot(spellButton)
        if slot then
            return slot, helperBookType or bookType
        end
    end

    if spellButton and SpellButton_GetSpellID then
        local slot = SpellButton_GetSpellID(spellButton)
        if slot then
            return slot, bookType
        end
    end

    return nil, bookType
end

local function insertSpellFromSpellBook(button)
    if not IsShiftKeyDown() then
        return
    end
    if not editor or not editor:IsShown() then
        return
    end

    local slot, bookType = getSpellBookSlotAndBookType(button)
    local spellName = slot and GetSpellName(slot, bookType)
    if spellName and spellName ~= "" then
        editor.macroEditBox:SetFocus()
        editor.macroEditBox:Insert(spellName)
        refreshSuggestions()
        refreshMacroScrollBar()
    end
end

local function initSpellClickHook()
    if spellClickHooked then
        return
    end
    if SpellButton_OnModifiedClick and hooksecurefunc then
        hooksecurefunc("SpellButton_OnModifiedClick", insertSpellFromSpellBook)
        spellClickHooked = true
    end
end

function ADDON.InsertMacroText(text)
    if not editor or not editor:IsShown() or not editor.macroEditBox then
        return false
    end

    editor.macroEditBox:SetFocus()
    editor.macroEditBox:Insert(text)
    refreshSuggestions()
    refreshMacroScrollBar()
    return true
end

local function createInterfaceRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(594)
    row:SetHeight(34)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -106 - (index - 1) * 35)
    setBackdrop(row, 0.04, 0.05, 0.07, 1)
    row:SetScript("OnClick", function(self)
        openActionPicker(self)
    end)

    row.keyText = createText(row, 13)
    row.keyText:SetPoint("LEFT", row, "LEFT", 12, 0)
    row.keyText:SetWidth(105)

    row.actionText = createText(row, 12)
    row.actionText:SetPoint("LEFT", row, "LEFT", 132, 0)
    row.actionText:SetPoint("RIGHT", row, "RIGHT", -76, 0)
    row.actionText:SetTextColor(1, 0.82, 0.1)

    row.clear = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.clear:SetWidth(58)
    row.clear:SetHeight(20)
    row.clear:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.clear:SetText("Lösen")
    row.clear:SetScript("OnClick", function(self)
        local parentRow = self:GetParent()
        if parentRow.bindingKey then
            ADDON.ClearDefaultBindingAction(parentRow.bindingKey)
            refreshInterfaceRows()
        end
    end)

    interfaceRows[index] = row
    return row
end

local function createSuggestionButton(parent, index)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(184)
    button:SetHeight(28)
    setBackdrop(button, 0.04, 0.05, 0.07, 0.95)
    button.texture = button:CreateTexture(nil, "ARTWORK")
    button.texture:SetWidth(22)
    button.texture:SetHeight(22)
    button.texture:SetPoint("LEFT", button, "LEFT", 4, 0)
    button.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.text = createText(button, 10)
    button.text:SetPoint("LEFT", button.texture, "RIGHT", 5, 0)
    button.text:SetPoint("RIGHT", button, "RIGHT", -5, 0)
    button.text:SetJustifyH("LEFT")
    button:SetScript("OnClick", function(self)
        toggleSelectedIcon(self.texturePath)
    end)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 22 + ((index - 1) % 3) * 196, -500 - math.floor((index - 1) / 3) * 32)
    button:Hide()
    return button
end

local function createSelectedIconButton(parent, index)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(26)
    button:SetHeight(26)
    setBackdrop(button, 0.04, 0.05, 0.07, 0.95)
    button.texture = button:CreateTexture(nil, "ARTWORK")
    button.texture:SetAllPoints(button)
    button.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetScript("OnClick", function()
        if selectedIcons[index] then
            table.remove(selectedIcons, index)
            updateSelectedIcons()
            refreshSuggestionSelection()
        end
    end)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 22 + (index - 1) * 30, -435)
    button:Hide()
    return button
end

local function createEditor()
    if editor then
        return editor
    end

    editor = CreateFrame("Frame", "DudesKeyMacrosEditor", UIParent)
    editor:SetWidth(640)
    editor:SetHeight(600)
    editor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    editor:SetFrameStrata("FULLSCREEN_DIALOG")
    editor:SetFrameLevel(EDITOR_FRAME_LEVEL)
    editor:EnableMouse(true)
    if editor.EnableKeyboard then
        editor:EnableKeyboard(true)
    end
    editor:SetMovable(true)
    editor:RegisterForDrag("LeftButton")
    editor:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    editor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    editor:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            saveMacroDraft()
            self:Hide()
        end
    end)
    setBackdrop(editor, 0.02, 0.025, 0.035, 1)
    createSolidTexture(editor, 0.02, 0.025, 0.035)

    editor.title = createText(editor, 20)
    editor.title:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -20)

    local close = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    close:SetWidth(36)
    close:SetHeight(30)
    close:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -16, -16)
    close:SetText("X")
    close:SetScript("OnClick", function()
        saveMacroDraft()
        editor:Hide()
    end)

    local interfaceTitle = createText(editor, 17)
    interfaceTitle:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -78)
    interfaceTitle:SetText("Interface")

    for i = 1, 4 do
        createInterfaceRow(editor, i)
    end

    local macroTitle = createText(editor, 17)
    macroTitle:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -288)
    macroTitle:SetText("Makro")

    local macroBox = CreateFrame("Frame", nil, editor)
    macroBox:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -320)
    macroBox:SetWidth(580)
    macroBox:SetHeight(92)
    setBackdrop(macroBox, 0.07, 0.075, 0.085, 1)

    local scroll = CreateFrame("ScrollFrame", "DudesKeyMacrosEditorScrollFrame", macroBox, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", macroBox, "TOPLEFT", 8, -7)
    scroll:SetWidth(552)
    scroll:SetHeight(76)
    editor.macroScrollFrame = scroll

    editor.macroEditBox = CreateFrame("EditBox", nil, scroll)
    editor.macroEditBox:SetMultiLine(true)
    editor.macroEditBox:SetAutoFocus(false)
    editor.macroEditBox:SetWidth(536)
    editor.macroEditBox:SetHeight(76)
    editor.macroEditBox:SetFontObject(ChatFontNormal)
    editor.macroEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editor.macroEditBox:SetScript("OnTextChanged", function()
        refreshSuggestions()
        refreshMacroScrollBar()
    end)
    scroll:SetScrollChild(editor.macroEditBox)

    local selectedLabel = createText(editor, 11)
    selectedLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -418)
    selectedLabel:SetText("Selected icons")

    for i = 1, 8 do
        selectedIconButtons[i] = createSelectedIconButton(editor, i)
    end

    editor.manualIcon = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    editor.manualIcon:SetWidth(300)
    editor.manualIcon:SetHeight(20)
    editor.manualIcon:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -470)
    editor.manualIcon:SetAutoFocus(false)

    local addIcon = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    addIcon:SetWidth(82)
    addIcon:SetHeight(22)
    addIcon:SetPoint("LEFT", editor.manualIcon, "RIGHT", 8, 0)
    addIcon:SetText("Add Icon")
    addIcon:SetScript("OnClick", function()
        toggleSelectedIcon(editor.manualIcon:GetText())
        editor.manualIcon:SetText("")
    end)

    local suggest = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    suggest:SetWidth(98)
    suggest:SetHeight(22)
    suggest:SetPoint("LEFT", addIcon, "RIGHT", 8, 0)
    suggest:SetText("Suggest")
    suggest:SetScript("OnClick", refreshSuggestions)

    for i = 1, 9 do
        suggestionButtons[i] = createSuggestionButton(editor, i)
    end

    editor:Hide()
    return editor
end

function ADDON.OpenEditor(key)
    createEditor()
    currentKey = key

    local binding = ADDON.GetBinding(key)
    editor.title:SetText("Binding Key \"" .. key .. "\"")
    editor.macroEditBox:SetText(binding and binding.macrotext or "")
    selectedIcons = copyArray(binding and binding.icons or {})
    editor.manualIcon:SetText("")
    updateSelectedIcons()
    refreshSuggestionSelection()
    refreshSuggestions()
    refreshMacroScrollBar()
    refreshInterfaceRows()

    editor:Show()
end

DudesUtils.EventHandler.Add("PLAYER_LOGIN", initSpellClickHook)
DudesUtils.EventHandler.Add("ADDON_LOADED", initSpellClickHook)
