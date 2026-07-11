local ADDON = DudesKeyMacros

local editor
local actionPicker
local currentKey
local selectedIcons = {}
local iconMatrix
local selectedMatrixCellKey
local interfaceRows = {}
local actionButtons = {}
local suggestionButtons = {}
local selectedIconButtons = {}
local selectedIconRows = {}
local draggedIconIndex
local iconListOffset = 1
local matrixCellButtons = {}
local matrixRowLabels = {}
local matrixRowActionTexts = {}
local matrixColHeaders = {}
local matrixRowLocks = {}
local matrixGlobalLocked
local spellClickHooked
local bagItemClickHooked
local inventoryItemClickHooked
local companionClickHooked
local pickerBindingKey
local pendingActionMove
local refreshSuggestions
local refreshMacroLockState
local setEditorMode
local refreshActionPicker
local showFrame
local saveMacroDraft
local editorMode = "interface"
local suppressMacroSave
local suppressIconSave
local macroDirty

local EDITOR_FRAME_LEVEL = 40
local PICKER_FRAME_LEVEL = 80
local MACRO_LOCK_WARNING_TEXT = "Makro deaktiviert: Die Haupttaste ist als Interface-Aktion gebunden"

local function copyArray(source)
    local copy = {}
    for i, value in ipairs(source or {}) do
        if type(value) == "table" then
            copy[i] = {
                texture = value.texture,
                text = value.text or "",
                name = value.name or value.texture,
            }
        else
            copy[i] = value
        end
    end
    return copy
end

local function normalizeSelectedIcons(icons)
    local normalized = {}
    for _, icon in ipairs(icons or {}) do
        if type(icon) == "table" and icon.texture and icon.texture ~= "" then
            table.insert(normalized, {
                texture = icon.texture,
                text = icon.text or "",
                name = icon.name or icon.texture,
            })
        elseif type(icon) == "string" and icon ~= "" then
            table.insert(normalized, {
                texture = icon,
                text = "",
                name = icon,
            })
        end
    end
    return normalized
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
    if iconListOffset > math.max(1, #selectedIcons) then
        iconListOffset = math.max(1, #selectedIcons - #selectedIconRows + 1)
    end
    suppressIconSave = true
    for i, row in ipairs(selectedIconRows) do
        local iconIndex = iconListOffset + i - 1
        local icon = selectedIcons[iconIndex]
        row.iconIndex = iconIndex
        if icon then
            row.texture:SetTexture(icon.texture)
            row.name:SetText(icon.name or icon.texture or "")
            row.text:SetText(icon.text or "")
            row:Show()
        else
            row:Hide()
        end
    end
    suppressIconSave = nil

    if editor and editor.iconPageText then
        local last = math.min(#selectedIcons, iconListOffset + #selectedIconRows - 1)
        if #selectedIcons > 0 then
            editor.iconPageText:SetText(tostring(iconListOffset) .. "-" .. tostring(last) .. " / " .. tostring(#selectedIcons))
        else
            editor.iconPageText:SetText("0 / 0")
        end
    end
    if editor and editor.iconPrevButton then
        if iconListOffset > 1 then
            editor.iconPrevButton:Enable()
        else
            editor.iconPrevButton:Disable()
        end
    end
    if editor and editor.iconNextButton then
        if iconListOffset + #selectedIconRows <= #selectedIcons then
            editor.iconNextButton:Enable()
        else
            editor.iconNextButton:Disable()
        end
    end
end

local function refreshSuggestionSelection()
end

local function addSelectedIcon(texture, name, text)
    if not texture or texture == "" then
        return
    end
    table.insert(selectedIcons, {
        texture = texture,
        name = name or texture,
        text = text or "",
    })
    if #selectedIcons > #selectedIconRows then
        iconListOffset = math.max(1, #selectedIcons - #selectedIconRows + 1)
    end
    updateSelectedIcons()
    if currentKey then
        saveMacroDraft()
    end
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

local function moveSelectedIcon(fromIndex, toIndex)
    if not fromIndex or not toIndex or fromIndex == toIndex then
        draggedIconIndex = nil
        return
    end
    if not selectedIcons[fromIndex] or not selectedIcons[toIndex] then
        draggedIconIndex = nil
        return
    end

    local icon = table.remove(selectedIcons, fromIndex)
    table.insert(selectedIcons, toIndex, icon)
    draggedIconIndex = nil
    updateSelectedIcons()
    if currentKey then
        saveMacroDraft()
    end
end

local function getMatrixCell(rowKey, colKey)
    if not iconMatrix or not ADDON.GetMatrixCellKey then
        return nil
    end
    return iconMatrix.cells[ADDON.GetMatrixCellKey(rowKey, colKey)]
end

local function getCellRowKey(cellKey)
    return string.match(cellKey or "", "^([^|]+)|")
end

local function isMatrixRowLocked(rowKey)
    return matrixGlobalLocked or (rowKey and matrixRowLocks and matrixRowLocks[rowKey] and true or false)
end

local function isSelectedMatrixCellLocked()
    if not selectedMatrixCellKey then
        return true
    end
    return isMatrixRowLocked(getCellRowKey(selectedMatrixCellKey))
end

local function hasMatrixRow(matrix, rowKey)
    for _, row in ipairs((matrix or {}).rows or {}) do
        if row.key == rowKey then
            return true
        end
    end
    return false
end

local function hasMatrixCol(matrix, colKey)
    for _, col in ipairs((matrix or {}).cols or {}) do
        if col.key == colKey then
            return true
        end
    end
    return false
end

local function addEditorMatrixColumn(matrix, kind, index)
    kind = kind or "default"
    local key = kind == "default" and "default" or (kind .. ":" .. tostring(index))
    if hasMatrixCol(matrix, key) then
        return
    end

    local texture
    local name = "Default"
    if kind ~= "default" and GetShapeshiftFormInfo then
        texture, name = GetShapeshiftFormInfo(index)
    end

    table.insert(matrix.cols, {
        key = key,
        kind = kind,
        index = index,
        label = kind == "default" and "" or tostring(index),
        texture = texture,
        name = name or (kind .. " " .. tostring(index)),
    })
end

local function applyEditorMatrixRowLabels(matrix)
    local labels = {
        normal = "Normal",
        shift = "Shift",
        ctrl = "Control",
        alt = "Alt",
    }
    for _, row in ipairs((matrix or {}).rows or {}) do
        if labels[row.key] then
            row.label = labels[row.key]
        end
    end
    return matrix
end

local function expandMatrixForEditor(matrix)
    matrix = matrix or (ADDON.BuildMacroIconMatrix and ADDON.BuildMacroIconMatrix("")) or { rows = {}, cols = {}, cells = {} }
    matrix.rows = matrix.rows or {}
    matrix.cols = matrix.cols or {}
    matrix.cells = matrix.cells or {}

    local editorRows = {
        { key = "normal", label = "Normal" },
        { key = "shift", label = "Shift" },
        { key = "ctrl", label = "Control" },
        { key = "alt", label = "Alt" },
    }
    for _, row in ipairs(editorRows) do
        if not hasMatrixRow(matrix, row.key) then
            table.insert(matrix.rows, {
                key = row.key,
                label = row.label,
            })
        end
    end

    addEditorMatrixColumn(matrix, "default")
    if GetNumShapeshiftForms and GetNumShapeshiftForms() > 0 then
        for i = 1, GetNumShapeshiftForms() do
            addEditorMatrixColumn(matrix, "stance", i)
        end
    end

    matrix = ADDON.NormalizeIconMatrix and ADDON.NormalizeIconMatrix(matrix) or matrix
    return applyEditorMatrixRowLabels(matrix)
end

local function matrixHasIcons(matrix)
    for _, cell in pairs((matrix or {}).cells or {}) do
        if cell and cell.texture then
            return true
        end
    end
    return false
end

local function setSelectedMatrixCell(cellKey)
    if isMatrixRowLocked(getCellRowKey(cellKey)) then
        return
    end
    selectedMatrixCellKey = cellKey
    for _, button in ipairs(matrixCellButtons) do
        if button.cellKey and button.cellKey == selectedMatrixCellKey then
            button:SetBackdropBorderColor(0.3, 1, 0.45, 1)
        else
            button:SetBackdropBorderColor(0.25, 0.3, 0.4, 1)
        end
    end
end

local function refreshIconMatrixPreview()
    if not editor then
        return
    end

    iconMatrix = ADDON.NormalizeIconMatrix and ADDON.NormalizeIconMatrix(iconMatrix) or iconMatrix
    iconMatrix = applyEditorMatrixRowLabels(iconMatrix)
    iconMatrix = expandMatrixForEditor(iconMatrix)

    local rows = iconMatrix.rows or {}
    local cols = iconMatrix.cols or {}

    for i, label in ipairs(matrixRowLabels) do
        local row = rows[i]
        if row then
            label:SetText(row.label or "")
            label:Show()
            local actionText = matrixRowActionTexts[i]
            local lockedAction = matrixRowLocks[row.key]
            if lockedAction then
                actionText:SetText(ADDON.GetBindingDisplayName(lockedAction))
                actionText:Show()
            else
                actionText:Hide()
            end
        else
            label:Hide()
            if matrixRowActionTexts[i] then
                matrixRowActionTexts[i]:Hide()
            end
        end
    end

    for i, header in ipairs(matrixColHeaders) do
        local col = cols[i]
        if col then
            header.texture:Hide()
            header.text:Hide()
            if col.texture then
                header.texture:SetTexture(col.texture)
                header.texture:Show()
            else
                header.text:SetText(col.label or "")
                header.text:Show()
            end
            header:Show()
        else
            header:Hide()
        end
    end

    for _, button in ipairs(matrixCellButtons) do
        local row = rows[button.rowIndex]
        local col = cols[button.colIndex]
        if row and col then
            local cellKey = ADDON.GetMatrixCellKey(row.key, col.key)
            local cell = iconMatrix.cells[cellKey]
            local lockedRow = isMatrixRowLocked(row.key)
            button.cellKey = cellKey
            button.rowKey = row.key
            button.colKey = col.key
            if lockedRow then
                button.texture:Hide()
                button:Hide()
                button:SetBackdropBorderColor(0.6, 0.18, 0.16, 1)
            elseif cell and cell.texture then
                button.texture:SetTexture(cell.texture)
                button.texture:Show()
                button:SetAlpha(1)
                button:Show()
            else
                button.texture:Hide()
                button:SetAlpha(1)
                button:Show()
            end
        else
            button.cellKey = nil
            button:Hide()
        end
    end

    if isSelectedMatrixCellLocked() then
        selectedMatrixCellKey = nil
        for _, row in ipairs(rows) do
            if not isMatrixRowLocked(row.key) then
                local col = cols[1]
                if col and ADDON.GetMatrixCellKey then
                    selectedMatrixCellKey = ADDON.GetMatrixCellKey(row.key, col.key)
                end
                break
            end
        end
    end
    setSelectedMatrixCell(selectedMatrixCellKey)
end

local function setSelectedMatrixCellIcon(texture, name, manual)
    if isSelectedMatrixCellLocked() then
        return
    end
    if not selectedMatrixCellKey or not texture or texture == "" then
        return
    end
    iconMatrix = iconMatrix or (ADDON.BuildMacroIconMatrix and ADDON.BuildMacroIconMatrix(""))
    iconMatrix.cells = iconMatrix.cells or {}
    iconMatrix.cells[selectedMatrixCellKey] = {
        texture = texture,
        name = name or texture,
        kind = "texture",
        manual = manual and true or nil,
    }
    refreshIconMatrixPreview()
end

local function clearSelectedMatrixCellIcon()
    if isSelectedMatrixCellLocked() then
        return
    end
    if not selectedMatrixCellKey or not iconMatrix or not iconMatrix.cells then
        return
    end
    iconMatrix.cells[selectedMatrixCellKey] = nil
    refreshIconMatrixPreview()
end

local function buildMatrixFromMacro()
    if not editor or not ADDON.BuildMacroIconMatrix then
        return
    end
    iconMatrix = ADDON.BuildMacroIconMatrix(editor.macroEditBox:GetText() or "")
    local firstRow = iconMatrix.rows and iconMatrix.rows[1]
    local firstCol = iconMatrix.cols and iconMatrix.cols[1]
    if firstRow and firstCol and ADDON.GetMatrixCellKey then
        selectedMatrixCellKey = ADDON.GetMatrixCellKey(firstRow.key, firstCol.key)
    end
    refreshIconMatrixPreview()
    refreshSuggestions()
end

function refreshSuggestions()
    local macrotext = editor.macroEditBox:GetText() or ""
    local query = editor.iconSearch and editor.iconSearch:GetText() or ""
    local suggestions = ADDON.SearchIcons and ADDON.SearchIcons(query, macrotext) or ADDON.GetMacroIconSuggestions(macrotext)
    for i = 1, #suggestionButtons do
        setSuggestionButton(suggestionButtons[i], suggestions[i])
    end
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

saveMacroDraft = function()
    if suppressMacroSave or not currentKey or not editor or not editor.macroEditBox then
        return true
    end
    local macrotext = editor.macroEditBox:GetText() or ""
    if macrotext == "" and #selectedIcons == 0 then
        ADDON.ClearBinding(currentKey)
    else
        ADDON.SaveBinding(currentKey, macrotext, copyArray(selectedIcons))
    end
    macroDirty = nil
    return true
end

local function hasInterfaceBindings(key)
    if not key then
        return false
    end
    for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
        local action = ADDON.GetDefaultBindingAction(variant.key)
        if action and action ~= "" then
            return true
        end
    end
    return false
end

local function hasMacroBinding(binding)
    return binding and (((binding.macrotext or "") ~= "") or #(binding.icons or {}) > 0)
end

local function setModeButtonActive(button, active)
    if not button then
        return
    end
    if active then
        button:SetBackdropColor(0.16, 0.12, 0.02, 1)
        button:SetBackdropBorderColor(1, 0.82, 0.1, 1)
        button.text:SetTextColor(1, 0.82, 0.1)
    else
        button:SetBackdropColor(0.04, 0.05, 0.07, 1)
        button:SetBackdropBorderColor(0.25, 0.3, 0.4, 1)
        button.text:SetTextColor(0.72, 0.75, 0.8)
    end
end

showFrame = function(frame, visible)
    if not frame then
        return
    end
    if visible then
        frame:Show()
    else
        frame:Hide()
    end
end

local function refreshActionFilterPlaceholder()
    if not editor or not editor.actionFilterPlaceholder or not editor.actionFilter then
        return
    end
    if editorMode == "interface" and (editor.actionFilter:GetText() or "") == "" then
        editor.actionFilterPlaceholder:Show()
    else
        editor.actionFilterPlaceholder:Hide()
    end
end

setEditorMode = function(mode)
    if not editor then
        return
    end
    mode = mode == "macro" and "macro" or "interface"
    if editorMode == "macro" and mode ~= "macro" and macroDirty then
        saveMacroDraft()
    end
    editorMode = mode

    local showInterface = mode == "interface"
    local showMacro = mode == "macro"

    editor:SetHeight(640)

    setModeButtonActive(editor.interfaceModeButton, showInterface)
    setModeButtonActive(editor.macroModeButton, showMacro)

    showFrame(editor.interfaceTitle, showInterface)
    showFrame(editor.interfaceLockWarning, showInterface and editor.macroLocked)
    showFrame(editor.actionListTitle, showInterface)
    showFrame(editor.actionFilter, showInterface)
    showFrame(editor.actionLimitHint, showInterface)
    refreshActionFilterPlaceholder()
    for _, row in ipairs(interfaceRows) do
        showFrame(row, showInterface)
    end
    for _, button in ipairs(actionButtons) do
        if showInterface and button.command then
            button:Show()
        else
            button:Hide()
        end
    end

    showFrame(editor.macroTitle, showMacro)
    showFrame(editor.macroLockWarning, showMacro and editor.macroLocked)
    showFrame(editor.macroBox, showMacro)
    showFrame(editor.iconMatrixTitle, showMacro)
    showFrame(editor.autoMatrixButton, showMacro and not editor.macroLocked)
    showFrame(editor.iconPrevButton, showMacro and not editor.macroLocked)
    showFrame(editor.iconPageText, showMacro and not editor.macroLocked)
    showFrame(editor.iconNextButton, showMacro and not editor.macroLocked)
    showFrame(editor.iconSearch, showMacro and not editor.macroLocked)
    showFrame(editor.iconSearchPlaceholder, showMacro and not editor.macroLocked and editor.iconSearch and (editor.iconSearch:GetText() or "") == "")
    for _, button in ipairs(selectedIconButtons) do
        showFrame(button, false)
    end
    for _, row in ipairs(selectedIconRows) do
        showFrame(row, showMacro and not editor.macroLocked and row.iconIndex and selectedIcons[row.iconIndex])
    end
    for _, button in ipairs(suggestionButtons) do
        if showMacro and button.texturePath and not editor.macroLocked then
            button:Show()
        else
            button:Hide()
        end
    end

    for _, header in ipairs(matrixColHeaders) do
        showFrame(header, false)
    end
    for _, label in ipairs(matrixRowLabels) do
        showFrame(label, false)
    end
    for _, text in ipairs(matrixRowActionTexts) do
        showFrame(text, false)
    end
    for _, button in ipairs(matrixCellButtons) do
        showFrame(button, false)
    end

    if showMacro then
        if actionPicker then
            actionPicker:Hide()
        end
        refreshMacroLockState()
        refreshMacroScrollBar()
    else
        if actionPicker then
            actionPicker:Hide()
        end
        refreshActionPicker()
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
        if variant and editorMode == "interface" then
            row:Show()
        else
            row:Hide()
        end
    end
    if refreshMacroLockState then
        refreshMacroLockState()
    end
    if editorMode == "interface" and refreshActionPicker then
        refreshActionPicker()
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

function refreshActionPicker()
    if not editor or not editor.actionFilter then
        return
    end

    local filter = editor.actionFilter:GetText() or ""
    local actions = ADDON.GetAvailableBindingActions(filter) or {}
    local variants = currentKey and ADDON.GetDefaultBindingKeysForKey(currentKey) or {}
    refreshActionFilterPlaceholder()
    for i, button in ipairs(actionButtons) do
        local action = actions[i]
        if action then
            button.command = action.command
            button.text:SetText(action.name)
            button.commandText:SetText(action.command)
            for bindIndex, bindButton in ipairs(button.bindButtons or {}) do
                local variant = variants[bindIndex]
                bindButton.bindingKey = variant and variant.key or nil
                bindButton:Show()
            end
            if editorMode == "interface" then
                button:Show()
            else
                button:Hide()
            end
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

local function getNameFromLink(link)
    if not link or link == "" then
        return nil
    end
    return string.match(link, "%[(.-)%]")
end

local function getClickedItemButton(button)
    if type(button) == "table" and button.GetID then
        return button
    end
    if type(this) == "table" and this.GetID then
        return this
    end
    return nil
end

local function insertMacroTextFromClick(text)
    if not IsShiftKeyDown() then
        return false
    end
    if not editor or not editor:IsShown() or not editor.macroEditBox or editor.macroLocked then
        return false
    end
    if editorMode ~= "macro" then
        setEditorMode("macro")
    end
    if not text or text == "" then
        return false
    end

    editor.macroEditBox:SetFocus()
    editor.macroEditBox:Insert(text)
    refreshSuggestions()
    refreshMacroScrollBar()
    return true
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
    insertMacroTextFromClick(spellName)
end

local function insertBagItemFromButton(button)
    button = getClickedItemButton(button)
    if not button then
        return
    end

    local slot = button:GetID()
    local parent = button:GetParent()
    local bag = parent and parent:GetID()
    local link = bag and slot and GetContainerItemLink and GetContainerItemLink(bag, slot)
    local name = getNameFromLink(link)
    if not name and link and GetItemInfo then
        name = GetItemInfo(link)
    end
    insertMacroTextFromClick(name)
end

local function insertInventoryItemFromButton(button)
    button = getClickedItemButton(button)
    if not button then
        return
    end

    local slot = button:GetID()
    local link = slot and GetInventoryItemLink and GetInventoryItemLink("player", slot)
    local name = getNameFromLink(link)
    if not name and link and GetItemInfo then
        name = GetItemInfo(link)
    end
    insertMacroTextFromClick(name)
end

local function insertCompanionFromButton(button)
    button = getClickedItemButton(button)
    if not button then
        return
    end

    local index = button:GetID()
    if not index or not GetCompanionInfo then
        return
    end

    local _, creatureName, spellID = GetCompanionInfo("MOUNT", index)
    local spellName = spellID and GetSpellInfo and GetSpellInfo(spellID)
    insertMacroTextFromClick(spellName or creatureName)
end

local function hookModifiedClickFunction(name, handler)
    if not hooksecurefunc or not _G or not _G[name] then
        return false
    end
    hooksecurefunc(name, handler)
    return true
end

local function initSpellClickHook()
    if not spellClickHooked and hookModifiedClickFunction("SpellButton_OnModifiedClick", insertSpellFromSpellBook) then
        spellClickHooked = true
    end
    if not bagItemClickHooked then
        if hookModifiedClickFunction("ContainerFrameItemButton_OnModifiedClick", insertBagItemFromButton) or hookModifiedClickFunction("ContainerFrameItemButton_OnClick", insertBagItemFromButton) then
            bagItemClickHooked = true
        end
    end
    if not inventoryItemClickHooked then
        if hookModifiedClickFunction("PaperDollItemSlotButton_OnModifiedClick", insertInventoryItemFromButton) or hookModifiedClickFunction("PaperDollItemSlotButton_OnClick", insertInventoryItemFromButton) then
            inventoryItemClickHooked = true
        end
    end
    if not companionClickHooked then
        if hookModifiedClickFunction("CompanionButton_OnModifiedClick", insertCompanionFromButton) or hookModifiedClickFunction("CompanionButton_OnClick", insertCompanionFromButton) then
            companionClickHooked = true
        end
    end
end

function ADDON.InsertMacroText(text)
    if not editor or not editor:IsShown() or not editor.macroEditBox or editor.macroLocked then
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
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -136 - (index - 1) * 35)
    setBackdrop(row, 0.04, 0.05, 0.07, 1)

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

local function bindInlineAction(button, bindingKey)
    if not button or not button.command or not bindingKey then
        return
    end
    local conflict = ADDON.FindDraftBindingForAction(button.command, bindingKey)
    confirmAndApplyAction(bindingKey, button.command, conflict)
end

local function createInlineActionButton(parent, index)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(594)
    button:SetHeight(34)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -350 - (index - 1) * 39)
    setBackdrop(button, 0.045, 0.055, 0.07, 1)

    button.text = createText(button, 11)
    button.text:SetPoint("TOPLEFT", button, "TOPLEFT", 8, -5)
    button.text:SetWidth(260)
    button.text:SetTextColor(1, 0.82, 0.1)

    button.commandText = createText(button, 8)
    button.commandText:SetPoint("TOPLEFT", button.text, "BOTTOMLEFT", 0, -2)
    button.commandText:SetWidth(260)
    button.commandText:SetTextColor(0.65, 0.7, 0.78)

    button.bindButtons = {}
    local labels = { "Normal", "Shift", "Ctrl", "Alt" }
    for i = 1, 4 do
        local bind = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
        bind:SetWidth(58)
        bind:SetHeight(22)
        bind:SetPoint("RIGHT", button, "RIGHT", -8 - (4 - i) * 62, 0)
        bind:SetText(labels[i])
        bind:SetScript("OnClick", function(self)
            bindInlineAction(button, self.bindingKey)
        end)
        button.bindButtons[i] = bind
    end

    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetBlendMode("ADD")
    end
    button:Hide()
    actionButtons[index] = button
    return button
end

local function createModeButton(parent, label, mode, x)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(118)
    button:SetHeight(28)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -62)
    setBackdrop(button, 0.04, 0.05, 0.07, 1)
    button.text = createText(button, 13, "CENTER")
    button.text:SetAllPoints(button)
    button.text:SetText(label)
    button:SetScript("OnClick", function()
        setEditorMode(mode)
    end)
    return button
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
        addSelectedIcon(self.texturePath, self.text:GetText(), "")
    end)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 22 + ((index - 1) % 3) * 196, -526 - math.floor((index - 1) / 3) * 32)
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

local function createSelectedIconRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(580)
    row:SetHeight(30)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -294 - (index - 1) * 34)
    row:RegisterForDrag("LeftButton")
    row:EnableMouse(true)
    setBackdrop(row, 0.04, 0.05, 0.07, 0.95)

    row.texture = row:CreateTexture(nil, "ARTWORK")
    row.texture:SetWidth(24)
    row.texture:SetHeight(24)
    row.texture:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = createText(row, 10)
    row.name:SetPoint("LEFT", row.texture, "RIGHT", 6, 0)
    row.name:SetWidth(230)

    row.text = CreateFrame("EditBox", nil, row)
    row.text:SetWidth(70)
    row.text:SetHeight(20)
    row.text:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.text:SetAutoFocus(false)
    row.text:SetFontObject(ChatFontNormal)
    row.text:SetTextInsets(4, 4, 0, 0)
    setBackdrop(row.text, 0.02, 0.025, 0.03, 1)
    row.text:SetScript("OnTextChanged", function(self)
        if suppressIconSave then
            return
        end
        local icon = selectedIcons[row.iconIndex]
        if icon then
            icon.text = self:GetText() or ""
        end
    end)
    row.text:SetScript("OnEditFocusLost", function(self)
        local icon = selectedIcons[row.iconIndex]
        if icon then
            icon.text = self:GetText() or ""
            saveMacroDraft()
        end
    end)
    row.text:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    row.text:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    row.up = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.up:SetWidth(24)
    row.up:SetHeight(22)
    row.up:SetPoint("LEFT", row.text, "RIGHT", 6, 0)
    row.up:SetText("^")
    row.up:SetScript("OnClick", function()
        moveSelectedIcon(row.iconIndex, row.iconIndex - 1)
    end)

    row.down = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.down:SetWidth(24)
    row.down:SetHeight(22)
    row.down:SetPoint("LEFT", row.up, "RIGHT", 4, 0)
    row.down:SetText("v")
    row.down:SetScript("OnClick", function()
        moveSelectedIcon(row.iconIndex, row.iconIndex + 1)
    end)

    row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.remove:SetWidth(74)
    row.remove:SetHeight(22)
    row.remove:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.remove:SetText("Entfernen")
    row.remove:SetScript("OnClick", function()
        if selectedIcons[row.iconIndex] then
            table.remove(selectedIcons, row.iconIndex)
            updateSelectedIcons()
            saveMacroDraft()
        end
    end)

    row.dragHint = createText(row, 9, "CENTER")
    row.dragHint:SetPoint("RIGHT", row.remove, "LEFT", -8, 0)
    row.dragHint:SetWidth(60)
    row.dragHint:SetText("ziehen")
    row.dragHint:SetTextColor(0.65, 0.7, 0.78)

    row:SetScript("OnDragStart", function(self)
        draggedIconIndex = self.iconIndex
        self:SetAlpha(0.55)
    end)
    row:SetScript("OnDragStop", function(self)
        self:SetAlpha(1)
    end)
    row:SetScript("OnMouseUp", function(self)
        if draggedIconIndex then
            local target = self.iconIndex
            for _, other in ipairs(selectedIconRows) do
                other:SetAlpha(1)
            end
            moveSelectedIcon(draggedIconIndex, target)
        end
    end)

    row:Hide()
    return row
end

local function createMatrixColumnHeader(parent, index)
    local header = CreateFrame("Frame", nil, parent)
    header:SetWidth(28)
    header:SetHeight(22)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 88 + (index - 1) * 34, -294)

    header.texture = header:CreateTexture(nil, "ARTWORK")
    header.texture:SetWidth(20)
    header.texture:SetHeight(20)
    header.texture:SetPoint("CENTER", header, "CENTER", 0, 0)
    header.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    header.text = createText(header, 10, "CENTER")
    header.text:SetAllPoints(header)

    header:Hide()
    return header
end

local function createMatrixRowLabel(parent, index)
    local label = createText(parent, 11)
    label:SetWidth(54)
    label:SetHeight(28)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -318 - (index - 1) * 34)
    label:Hide()
    return label
end

local function createMatrixRowActionText(parent, index)
    local text = createText(parent, 10)
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", 88, -318 - (index - 1) * 34)
    text:SetWidth(480)
    text:SetHeight(28)
    text:SetTextColor(1, 0.35, 0.25)
    text:Hide()
    return text
end

local function createMatrixCellButton(parent, rowIndex, colIndex)
    local button = CreateFrame("Button", nil, parent)
    button.rowIndex = rowIndex
    button.colIndex = colIndex
    button:SetWidth(28)
    button:SetHeight(28)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 88 + (colIndex - 1) * 34, -314 - (rowIndex - 1) * 34)
    setBackdrop(button, 0.04, 0.05, 0.07, 1)
    button.texture = button:CreateTexture(nil, "ARTWORK")
    button.texture:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.texture:SetWidth(24)
    button.texture:SetHeight(24)
    button.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetScript("OnClick", function(self)
        if isMatrixRowLocked(self.rowKey) then
            return
        end
        if self.cellKey then
            setSelectedMatrixCell(self.cellKey)
            if refreshMacroLockState then
                refreshMacroLockState()
            end
        end
    end)
    button:Hide()
    return button
end

local function setMacroButtonEnabled(button, enabled)
    if not button then
        return
    end
    if enabled then
        button:Enable()
    else
        button:Disable()
    end
end

function refreshMacroLockState()
    if not editor or not currentKey then
        return
    end

    local baseAction = ADDON.GetDefaultBindingAction(currentKey)
    local locked = baseAction and baseAction ~= ""

    matrixRowLocks = {}
    for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(currentKey)) do
        local action = ADDON.GetDefaultBindingAction(variant.key)
        if action and action ~= "" then
            matrixRowLocks[variant.modifier or "normal"] = action
        end
    end
    matrixGlobalLocked = locked and true or nil

    if isSelectedMatrixCellLocked() then
        selectedMatrixCellKey = nil
    end
    if not selectedMatrixCellKey and iconMatrix and iconMatrix.rows and iconMatrix.cols and iconMatrix.cols[1] and ADDON.GetMatrixCellKey then
        for _, row in ipairs(iconMatrix.rows) do
            if not isMatrixRowLocked(row.key) then
                selectedMatrixCellKey = ADDON.GetMatrixCellKey(row.key, iconMatrix.cols[1].key)
                break
            end
        end
    end

    editor.macroLocked = locked and true or nil

    if locked then
        editor.macroEditBox:ClearFocus()
        editor.macroEditBox:EnableMouse(false)
        editor.macroEditBox:SetTextColor(0.55, 0.55, 0.55)
        editor.manualIcon:ClearFocus()
        editor.manualIcon:EnableMouse(false)
        showFrame(editor.autoMatrixButton, false)
        showFrame(editor.iconPrevButton, false)
        showFrame(editor.iconPageText, false)
        showFrame(editor.iconNextButton, false)
        showFrame(editor.iconSearch, false)
        showFrame(editor.iconSearchPlaceholder, false)
        for _, row in ipairs(selectedIconRows) do
            row:Hide()
        end
        for _, button in ipairs(suggestionButtons) do
            button:Hide()
        end
        editor.macroLockWarning:SetText(MACRO_LOCK_WARNING_TEXT)
        editor.interfaceLockWarning:SetText(MACRO_LOCK_WARNING_TEXT)
        if editorMode == "macro" then
            editor.macroLockWarning:Show()
        else
            editor.macroLockWarning:Hide()
        end
        if editorMode == "interface" then
            editor.interfaceLockWarning:Show()
        else
            editor.interfaceLockWarning:Hide()
        end
    else
        editor.macroEditBox:EnableMouse(true)
        editor.macroEditBox:SetTextColor(1, 1, 1)
        editor.manualIcon:EnableMouse(true)
        editor.macroLockWarning:Hide()
        editor.interfaceLockWarning:Hide()
        if editorMode == "macro" then
            showFrame(editor.autoMatrixButton, true)
            showFrame(editor.iconPrevButton, true)
            showFrame(editor.iconPageText, true)
            showFrame(editor.iconNextButton, true)
            showFrame(editor.iconSearch, true)
            showFrame(editor.iconSearchPlaceholder, editor.iconSearch and (editor.iconSearch:GetText() or "") == "")
            updateSelectedIcons()
            refreshSuggestions()
        end
    end

    setMacroButtonEnabled(editor.autoMatrixButton, not locked)
    setMacroButtonEnabled(editor.suggestButton, not locked)
    setMacroButtonEnabled(editor.clearCellButton, not locked)
    setMacroButtonEnabled(editor.addIconButton, not locked)

    for _, button in ipairs(matrixCellButtons) do
        if isMatrixRowLocked(button.rowKey) then
            button:SetAlpha(0.45)
        else
            button:SetAlpha(1)
        end
    end
    for _, button in ipairs(suggestionButtons) do
        if isSelectedMatrixCellLocked() then
            button:SetAlpha(0.45)
        else
            button:SetAlpha(1)
        end
    end

end

local function createEditor()
    if editor then
        return editor
    end

    editor = CreateFrame("Frame", "DudesKeyMacrosEditor", UIParent)
    editor:SetWidth(640)
    editor:SetHeight(640)
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
            if editorMode == "macro" and macroDirty then
                saveMacroDraft()
            end
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
        if editorMode == "macro" and macroDirty then
            saveMacroDraft()
        end
        editor:Hide()
    end)

    editor.interfaceModeButton = createModeButton(editor, "Interface", "interface", 22)
    editor.macroModeButton = createModeButton(editor, "Makro", "macro", 144)

    local interfaceTitle = createText(editor, 17)
    interfaceTitle:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -108)
    interfaceTitle:SetText("Interface")
    editor.interfaceTitle = interfaceTitle

    editor.interfaceLockWarning = createText(editor, 10)
    editor.interfaceLockWarning:SetPoint("LEFT", interfaceTitle, "RIGHT", 14, 0)
    editor.interfaceLockWarning:SetPoint("RIGHT", editor, "RIGHT", -24, 0)
    editor.interfaceLockWarning:SetTextColor(1, 0.35, 0.25)
    editor.interfaceLockWarning:Hide()

    for i = 1, 4 do
        createInterfaceRow(editor, i)
    end

    editor.actionListTitle = createText(editor, 17)
    editor.actionListTitle:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -290)
    editor.actionListTitle:SetText("Aktionen")

    editor.actionFilter = CreateFrame("EditBox", nil, editor)
    editor.actionFilter:SetWidth(380)
    editor.actionFilter:SetHeight(20)
    editor.actionFilter:SetPoint("TOPLEFT", editor, "TOPLEFT", 32, -320)
    editor.actionFilter:SetAutoFocus(false)
    editor.actionFilter:SetFontObject(ChatFontNormal)
    editor.actionFilter:SetTextInsets(6, 6, 0, 0)
    setBackdrop(editor.actionFilter, 0.02, 0.025, 0.03, 1)
    editor.actionFilter:SetScript("OnTextChanged", function()
        refreshActionPicker()
    end)
    editor.actionFilter:SetScript("OnEditFocusGained", function()
        if editor.actionFilterPlaceholder then
            editor.actionFilterPlaceholder:Hide()
        end
    end)
    editor.actionFilter:SetScript("OnEditFocusLost", refreshActionFilterPlaceholder)

    editor.actionFilterPlaceholder = createText(editor.actionFilter, 10)
    editor.actionFilterPlaceholder:SetPoint("LEFT", editor.actionFilter, "LEFT", 6, 0)
    editor.actionFilterPlaceholder:SetPoint("RIGHT", editor.actionFilter, "RIGHT", -6, 0)
    editor.actionFilterPlaceholder:SetTextColor(0.45, 0.48, 0.52)
    editor.actionFilterPlaceholder:SetText("Suche nach Interface-Aktionen")

    editor.actionLimitHint = createText(editor, 10)
    editor.actionLimitHint:SetPoint("LEFT", editor.actionFilter, "RIGHT", 12, 0)
    editor.actionLimitHint:SetPoint("RIGHT", editor, "RIGHT", -24, 0)
    editor.actionLimitHint:SetTextColor(0.55, 0.58, 0.64)
    editor.actionLimitHint:SetText("Mehr Treffer per Suche eingrenzen")

    for i = 1, 6 do
        createInlineActionButton(editor, i)
    end

    local macroTitle = createText(editor, 17)
    macroTitle:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -108)
    macroTitle:SetText("Makro")
    editor.macroTitle = macroTitle

    editor.macroLockWarning = createText(editor, 10)
    editor.macroLockWarning:SetPoint("LEFT", macroTitle, "RIGHT", 14, 0)
    editor.macroLockWarning:SetPoint("RIGHT", editor, "RIGHT", -24, 0)
    editor.macroLockWarning:SetTextColor(1, 0.35, 0.25)
    editor.macroLockWarning:Hide()

    local macroBox = CreateFrame("Frame", nil, editor)
    macroBox:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -138)
    macroBox:SetWidth(580)
    macroBox:SetHeight(112)
    setBackdrop(macroBox, 0.07, 0.075, 0.085, 1)
    macroBox:EnableMouse(true)
    macroBox:SetScript("OnMouseDown", function()
        if editor.macroEditBox and not editor.macroLocked then
            editor.macroEditBox:SetFocus()
        end
    end)
    editor.macroBox = macroBox

    local scroll = CreateFrame("ScrollFrame", "DudesKeyMacrosEditorScrollFrame", macroBox, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", macroBox, "TOPLEFT", 8, -7)
    scroll:SetWidth(552)
    scroll:SetHeight(96)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function()
        if editor.macroEditBox and not editor.macroLocked then
            editor.macroEditBox:SetFocus()
        end
    end)
    editor.macroScrollFrame = scroll

    editor.macroEditBox = CreateFrame("EditBox", nil, scroll)
    editor.macroEditBox:SetMultiLine(true)
    editor.macroEditBox:SetAutoFocus(false)
    editor.macroEditBox:SetWidth(552)
    editor.macroEditBox:SetHeight(96)
    editor.macroEditBox:SetFontObject(ChatFontNormal)
    editor.macroEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editor.macroEditBox:SetScript("OnTextChanged", function()
        refreshSuggestions()
        refreshMacroScrollBar()
        if not suppressMacroSave then
            macroDirty = true
        end
    end)
    editor.macroEditBox:SetScript("OnEditFocusLost", function()
        if macroDirty then
            saveMacroDraft()
        end
    end)
    scroll:SetScrollChild(editor.macroEditBox)

    local selectedLabel = createText(editor, 17)
    selectedLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -264)
    selectedLabel:SetText("Icons")
    editor.iconMatrixTitle = selectedLabel

    local addMacroIcons = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    addMacroIcons:SetWidth(158)
    addMacroIcons:SetHeight(22)
    addMacroIcons:SetPoint("LEFT", selectedLabel, "RIGHT", 14, 0)
    addMacroIcons:SetText("Aus Makro hinzufügen")
    addMacroIcons:SetScript("OnClick", function()
        local suggestions = ADDON.GetMacroIconSuggestions and ADDON.GetMacroIconSuggestions(editor.macroEditBox:GetText() or "") or {}
        for _, suggestion in ipairs(suggestions) do
            if suggestion.texture and suggestion.texture ~= "" then
                table.insert(selectedIcons, {
                    texture = suggestion.texture,
                    name = suggestion.name or suggestion.texture,
                    text = "",
                })
            end
        end
        if #selectedIcons > #selectedIconRows then
            iconListOffset = math.max(1, #selectedIcons - #selectedIconRows + 1)
        end
        updateSelectedIcons()
        saveMacroDraft()
    end)
    editor.autoMatrixButton = addMacroIcons

    for i = 1, 5 do
        selectedIconRows[i] = createSelectedIconRow(editor, i)
    end

    editor.iconPrevButton = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    editor.iconPrevButton:SetWidth(28)
    editor.iconPrevButton:SetHeight(22)
    editor.iconPrevButton:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -464)
    editor.iconPrevButton:SetText("<")
    editor.iconPrevButton:SetScript("OnClick", function()
        iconListOffset = math.max(1, iconListOffset - #selectedIconRows)
        updateSelectedIcons()
    end)

    editor.iconPageText = createText(editor, 10, "CENTER")
    editor.iconPageText:SetPoint("LEFT", editor.iconPrevButton, "RIGHT", 6, 0)
    editor.iconPageText:SetWidth(72)
    editor.iconPageText:SetTextColor(0.75, 0.78, 0.84)

    editor.iconNextButton = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    editor.iconNextButton:SetWidth(28)
    editor.iconNextButton:SetHeight(22)
    editor.iconNextButton:SetPoint("LEFT", editor.iconPageText, "RIGHT", 6, 0)
    editor.iconNextButton:SetText(">")
    editor.iconNextButton:SetScript("OnClick", function()
        if iconListOffset + #selectedIconRows <= #selectedIcons then
            iconListOffset = iconListOffset + #selectedIconRows
            updateSelectedIcons()
        end
    end)

    editor.iconSearch = CreateFrame("EditBox", nil, editor)
    editor.iconSearch:SetWidth(300)
    editor.iconSearch:SetHeight(20)
    editor.iconSearch:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, -492)
    editor.iconSearch:SetAutoFocus(false)
    editor.iconSearch:SetFontObject(ChatFontNormal)
    editor.iconSearch:SetTextInsets(6, 6, 0, 0)
    setBackdrop(editor.iconSearch, 0.02, 0.025, 0.03, 1)
    editor.iconSearch:SetScript("OnTextChanged", refreshSuggestions)

    editor.iconSearchPlaceholder = createText(editor.iconSearch, 10)
    editor.iconSearchPlaceholder:SetPoint("LEFT", editor.iconSearch, "LEFT", 6, 0)
    editor.iconSearchPlaceholder:SetPoint("RIGHT", editor.iconSearch, "RIGHT", -6, 0)
    editor.iconSearchPlaceholder:SetTextColor(0.45, 0.48, 0.52)
    editor.iconSearchPlaceholder:SetText("Icons suchen")
    editor.iconSearch:SetScript("OnEditFocusGained", function()
        editor.iconSearchPlaceholder:Hide()
    end)
    editor.iconSearch:SetScript("OnEditFocusLost", function()
        if (editor.iconSearch:GetText() or "") == "" then
            editor.iconSearchPlaceholder:Show()
        end
    end)

    editor.manualIcon = editor.iconSearch
    editor.addIconButton = addMacroIcons
    editor.suggestButton = addMacroIcons
    editor.clearCellButton = addMacroIcons

    for i = 1, 9 do
        suggestionButtons[i] = createSuggestionButton(editor, i)
        suggestionButtons[i]:Hide()
    end

    editor:Hide()
    return editor
end

function ADDON.OpenEditor(key)
    createEditor()
    currentKey = key

    local binding = ADDON.GetBinding(key)
    editor.title:SetText("Binding Key \"" .. key .. "\"")
    suppressMacroSave = true
    editor.macroEditBox:SetText(binding and binding.macrotext or "")
    suppressMacroSave = nil
    macroDirty = nil
    selectedIcons = normalizeSelectedIcons(binding and binding.icons or {})
    iconListOffset = 1
    iconMatrix = nil
    selectedMatrixCellKey = nil
    if #selectedIcons == 0 and binding and binding.iconMatrix then
        for _, cell in pairs(binding.iconMatrix.cells or {}) do
            if cell and cell.texture then
                table.insert(selectedIcons, {
                    texture = cell.texture,
                    text = "",
                    name = cell.name or cell.texture,
                })
            end
        end
    end
    editor.iconSearch:SetText("")
    editor.iconSearchPlaceholder:Show()
    if editor.actionFilter then
        editor.actionFilter:SetText("")
    end
    updateSelectedIcons()
    refreshSuggestionSelection()
    refreshSuggestions()
    refreshMacroScrollBar()
    refreshInterfaceRows()

    if hasMacroBinding(binding) then
        setEditorMode("macro")
    elseif hasInterfaceBindings(key) then
        setEditorMode("interface")
    else
        setEditorMode("interface")
    end

    editor:Show()
end

DudesUtils.EventHandler.Add("PLAYER_LOGIN", initSpellClickHook)
DudesUtils.EventHandler.Add("ADDON_LOADED", initSpellClickHook)
