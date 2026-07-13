local ADDON = DudesFlexBindings

local MODIFIER_ORDER = {
    normal = 1,
    shift = 2,
    ctrl = 3,
    alt = 4,
}

local MODIFIER_LABELS = {
    normal = "",
    shift = "S",
    ctrl = "C",
    alt = "A",
}
local macroIconTextureCache

local function trim(text)
    text = text or ""
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function lower(text)
    return string.lower(text or "")
end

local function copyArray(source)
    local copy = {}
    for i, value in ipairs(source or {}) do
        copy[i] = value
    end
    return copy
end

local function contains(array, value)
    for _, item in ipairs(array or {}) do
        if item == value then
            return true
        end
    end
    return false
end

local function splitList(text, separator)
    local values = {}
    for value in string.gmatch(text or "", "([^" .. separator .. "]+)") do
        table.insert(values, trim(value))
    end
    return values
end

local function stripMacroOptions(text)
    return trim(string.gsub(text or "", "%b[]", ""))
end

local function normalizeModifier(modifier)
    modifier = lower(modifier)
    if modifier == "" or modifier == "none" or modifier == "normal" or modifier == "nomod" or modifier == "nomodifier" then
        return "normal"
    end
    if modifier == "control" then
        return "ctrl"
    end
    return modifier
end

local function getCellKey(rowKey, colKey)
    return (rowKey or "normal") .. "|" .. (colKey or "default")
end

local function getStanceLabel(kind, index)
    if kind == "default" then
        return ""
    end
    return tostring(index or "")
end

local function getStanceTexture(kind, index)
    if kind ~= "stance" and kind ~= "form" then
        return nil
    end
    if not GetShapeshiftFormInfo then
        return nil
    end
    local icon = GetShapeshiftFormInfo(index)
    return icon
end

local function getStanceName(kind, index)
    if kind ~= "stance" and kind ~= "form" then
        return "Default"
    end
    if not GetShapeshiftFormInfo then
        return kind .. " " .. tostring(index)
    end
    local _, name = GetShapeshiftFormInfo(index)
    return name or (kind .. " " .. tostring(index))
end

local function createRow(key)
    return {
        key = normalizeModifier(key),
        label = MODIFIER_LABELS[normalizeModifier(key)] or string.upper(string.sub(key or "", 1, 1)),
    }
end

local function createColumn(kind, index)
    kind = kind or "default"
    local key = kind == "default" and "default" or (kind .. ":" .. tostring(index))
    return {
        key = key,
        kind = kind,
        index = index,
        label = getStanceLabel(kind, index),
        texture = getStanceTexture(kind, index),
        name = getStanceName(kind, index),
    }
end

local function ensureRow(matrix, rowKey)
    rowKey = normalizeModifier(rowKey)
    if not matrix.rowMap[rowKey] then
        table.insert(matrix.rows, createRow(rowKey))
        matrix.rowMap[rowKey] = true
    end
end

local function ensureColumn(matrix, kind, index)
    local column = createColumn(kind, index)
    if not matrix.colMap[column.key] then
        table.insert(matrix.cols, column)
        matrix.colMap[column.key] = true
    end
    return column.key
end

local function createEmptyMatrix()
    return {
        rows = {},
        cols = {},
        cells = {},
        rowMap = {},
        colMap = {},
    }
end

local function finalizeMatrix(matrix)
    if #matrix.rows == 0 then
        ensureRow(matrix, "normal")
    end
    if #matrix.cols == 0 then
        ensureColumn(matrix, "default")
    end

    table.sort(matrix.rows, function(a, b)
        return (MODIFIER_ORDER[a.key] or 99) < (MODIFIER_ORDER[b.key] or 99)
    end)
    table.sort(matrix.cols, function(a, b)
        if a.kind == "default" and b.kind ~= "default" then
            return true
        end
        if b.kind == "default" and a.kind ~= "default" then
            return false
        end
        return (a.index or 0) < (b.index or 0)
    end)

    matrix.rowMap = nil
    matrix.colMap = nil
    return matrix
end

local function addSuggestion(suggestions, seen, name, texture, kind)
    if not texture or texture == "" then
        return nil
    end
    local key = tostring(texture)
    if not seen[key] then
        seen[key] = true
        table.insert(suggestions, {
            name = name or texture,
            texture = texture,
            kind = kind or "texture",
        })
    end
    return texture
end

local function getTextureFileName(texture)
    local text = tostring(texture or "")
    local name = string.match(text, "[\\/]([^\\/]+)$") or text
    name = string.gsub(name, "%.[%a%d]+$", "")
    return name
end

local function getMacroIconTextures()
    if macroIconTextureCache then
        return macroIconTextureCache
    end

    local textures = {}
    local seen = {}

    local function add(texture)
        if texture and texture ~= "" and not seen[texture] then
            seen[texture] = true
            table.insert(textures, texture)
        end
    end

    if GetMacroIcons then
        local iconTable = {}
        local ok, result = pcall(GetMacroIcons, iconTable)
        if ok then
            if type(result) == "table" then
                for _, texture in ipairs(result) do
                    add(texture)
                end
            end
            for _, texture in ipairs(iconTable) do
                add(texture)
            end
        end
    end

    if #textures == 0 and GetMacroIconInfo then
        for i = 1, 5000 do
            local texture = GetMacroIconInfo(i)
            if not texture then
                break
            end
            add(texture)
        end
    end

    macroIconTextureCache = textures
    return macroIconTextureCache
end

local function resolveSpellIcon(name)
    name = stripMacroOptions(name)
    if name == "" then
        return nil
    end

    local spellName, _, texture
    if GetSpellInfo then
        spellName, _, texture = GetSpellInfo(name)
    end
    if (not texture or texture == "") and GetSpellTexture then
        texture = GetSpellTexture(name)
    end
    return texture, spellName or name, "spell"
end

local function resolveItemIcon(name)
    name = stripMacroOptions(name)
    if name == "" then
        return nil
    end

    local texture
    local itemName = name
    local slot = tonumber(name)
    if slot and GetInventoryItemTexture then
        texture = GetInventoryItemTexture("player", slot)
        itemName = "Inventory Slot " .. tostring(slot)
    end
    if (not texture or texture == "") and GetItemIcon then
        texture = GetItemIcon(name)
    end
    if (not texture or texture == "") and GetItemInfo then
        local resolvedName
        resolvedName, _, _, _, _, _, _, _, _, texture = GetItemInfo(name)
        itemName = resolvedName or itemName
    end
    return texture, itemName, "item"
end

local function resolveUseIcon(name)
    local texture, resolvedName, kind = resolveItemIcon(name)
    if texture then
        return texture, resolvedName, kind
    end

    return resolveSpellIcon(name)
end

local function parseOptionBlock(block)
    local state = {
        modifiers = {},
        columns = {},
    }

    for condition in string.gmatch(block or "", "([^,]+)") do
        condition = trim(condition)
        local conditionLower = lower(condition)
        local modValue = string.match(conditionLower, "^mod:(.+)$") or string.match(conditionLower, "^modifier:(.+)$")
        if modValue then
            for _, modifier in ipairs(splitList(modValue, "/")) do
                modifier = normalizeModifier(modifier)
                if modifier == "shift" or modifier == "ctrl" or modifier == "alt" then
                    table.insert(state.modifiers, modifier)
                end
            end
        elseif conditionLower == "mod" or conditionLower == "modifier" then
            table.insert(state.modifiers, "shift")
            table.insert(state.modifiers, "ctrl")
            table.insert(state.modifiers, "alt")
        elseif conditionLower == "nomod" or conditionLower == "nomodifier" then
            table.insert(state.modifiers, "normal")
        end

        local stanceValue = string.match(conditionLower, "^stance:(.+)$") or string.match(conditionLower, "^form:(.+)$")
        if stanceValue then
            for _, stance in ipairs(splitList(stanceValue, "/")) do
                local stanceIndex = tonumber(stance)
                if stanceIndex then
                    table.insert(state.columns, {
                        kind = "stance",
                        index = stanceIndex,
                    })
                end
            end
        elseif conditionLower == "nostance" or conditionLower == "noform" then
            table.insert(state.columns, {
                kind = "default",
            })
        end
    end

    if #state.modifiers == 0 then
        table.insert(state.modifiers, "normal")
    end
    if #state.columns == 0 then
        table.insert(state.columns, {
            kind = "default",
        })
    end

    return state
end

local function parseSegment(segment)
    local combined = {
        modifiers = {},
        columns = {},
    }

    local hasOptions
    for block in string.gmatch(segment or "", "%[([^%]]+)%]") do
        hasOptions = true
        local parsed = parseOptionBlock(block)
        for _, modifier in ipairs(parsed.modifiers) do
            if not contains(combined.modifiers, modifier) then
                table.insert(combined.modifiers, modifier)
            end
        end
        for _, column in ipairs(parsed.columns) do
            local key = column.kind == "default" and "default" or (column.kind .. ":" .. tostring(column.index))
            if not combined.columnMap then
                combined.columnMap = {}
            end
            if not combined.columnMap[key] then
                combined.columnMap[key] = true
                table.insert(combined.columns, column)
            end
        end
    end

    if not hasOptions or #combined.modifiers == 0 then
        table.insert(combined.modifiers, "normal")
    end
    if not hasOptions or #combined.columns == 0 then
        table.insert(combined.columns, {
            kind = "default",
        })
    end

    combined.columnMap = nil
    combined.payload = stripMacroOptions(segment)
    return combined
end

local function getFirstCastSequenceEntry(payload)
    payload = stripMacroOptions(payload)
    payload = string.gsub(payload, "^reset=[^%s]+%s+", "")
    local first = string.match(payload, "^([^,]+)")
    return trim(first or payload)
end

local function iterCommandSegments(macrotext, callback)
    for line in string.gmatch(macrotext or "", "[^\r\n]+") do
        local command, payload = string.match(line, "^%s*/([%a]+)%s+(.+)")
        command = lower(command)
        if command == "cast" or command == "use" or command == "castsequence" then
            for segment in string.gmatch(payload or "", "([^;]+)") do
                callback(command, parseSegment(segment))
            end
        end
    end
end

local function resolveSegmentIcon(command, payload)
    if command == "cast" then
        return resolveSpellIcon(payload)
    end
    if command == "castsequence" then
        return resolveSpellIcon(getFirstCastSequenceEntry(payload))
    end
    if command == "use" then
        return resolveUseIcon(payload)
    end
    return nil
end

function ADDON.BuildMacroIconMatrix(macrotext)
    local matrix = createEmptyMatrix()
    local suggestions = {}
    local seenSuggestions = {}

    iterCommandSegments(macrotext, function(command, segment)
        local texture, name, kind = resolveSegmentIcon(command, segment.payload)
        local cellKeys = {}
        for _, modifier in ipairs(segment.modifiers) do
            ensureRow(matrix, modifier)
            for _, column in ipairs(segment.columns) do
                local colKey = ensureColumn(matrix, column.kind, column.index)
                table.insert(cellKeys, getCellKey(modifier, colKey))
            end
        end

        if texture then
            addSuggestion(suggestions, seenSuggestions, name, texture, kind)
            for _, cellKey in ipairs(cellKeys) do
                if not matrix.cells[cellKey] then
                    matrix.cells[cellKey] = {
                        texture = texture,
                        name = name,
                        kind = kind,
                        auto = true,
                    }
                end
            end
        end
    end)

    matrix = finalizeMatrix(matrix)
    matrix.suggestions = suggestions
    return matrix
end

function ADDON.GetMacroIconSuggestions(macrotext)
    return ADDON.BuildMacroIconMatrix(macrotext).suggestions or {}
end

function ADDON.SearchIcons(query, macrotext)
    local results = {}
    local seen = {}
    query = lower(query or "")

    local function add(name, texture, kind)
        if not texture or texture == "" or seen[texture] then
            return
        end
        local haystack = lower((name or "") .. " " .. texture)
        if query == "" or string.find(haystack, query, 1, true) then
            seen[texture] = true
            table.insert(results, {
                name = name or texture,
                texture = texture,
                kind = kind or "texture",
            })
        end
    end

    for _, suggestion in ipairs(ADDON.GetMacroIconSuggestions(macrotext) or {}) do
        add(suggestion.name, suggestion.texture, suggestion.kind)
    end

    for _, texture in ipairs(getMacroIconTextures()) do
        add(getTextureFileName(texture), texture, "macroIcon")
    end

    if GetNumSpellTabs and GetSpellTabInfo and GetSpellName then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, numSpells = GetSpellTabInfo(tab)
            if offset and numSpells then
                for slot = offset + 1, offset + numSpells do
                    local name = GetSpellName(slot, BOOKTYPE_SPELL)
                    local texture
                    if name and GetSpellTexture then
                        texture = GetSpellTexture(slot, BOOKTYPE_SPELL) or GetSpellTexture(name)
                    end
                    add(name, texture, "spell")
                end
            end
        end
    end

    return results
end

function ADDON.GetMacroMarkers(macrotext)
    local markers = {}
    local seen = {}

    local function add(marker)
        if not seen[marker] then
            seen[marker] = true
            table.insert(markers, marker)
        end
    end

    macrotext = lower(macrotext or "")
    if string.find(macrotext, "%[.-mod:") or string.find(macrotext, "%[.-modifier:") then
        add("mod")
    end
    if string.find(macrotext, "%[.-stance:") or string.find(macrotext, "%[.-nostance") then
        add("stance")
    end
    if string.find(macrotext, "%[.-form:") or string.find(macrotext, "%[.-noform") then
        add("form")
    end

    return markers
end

function ADDON.GetMatrixCellKey(rowKey, colKey)
    return getCellKey(rowKey, colKey)
end

function ADDON.CopyIconMatrix(matrix)
    if not matrix then
        return nil
    end
    local copy = {
        rows = {},
        cols = {},
        cells = {},
    }
    for i, row in ipairs(matrix.rows or {}) do
        copy.rows[i] = {
            key = row.key,
            label = row.label,
        }
    end
    for i, col in ipairs(matrix.cols or {}) do
        copy.cols[i] = {
            key = col.key,
            kind = col.kind,
            index = col.index,
            label = col.label,
            texture = col.texture,
            name = col.name,
        }
    end
    for key, cell in pairs(matrix.cells or {}) do
        copy.cells[key] = {
            texture = cell.texture,
            name = cell.name,
            kind = cell.kind,
            auto = cell.auto,
            manual = cell.manual,
        }
    end
    return copy
end

function ADDON.NormalizeIconMatrix(matrix)
    if not matrix then
        return nil
    end
    local normalized = createEmptyMatrix()
    for _, row in ipairs(matrix.rows or {}) do
        ensureRow(normalized, row.key or "normal")
    end
    for _, col in ipairs(matrix.cols or {}) do
        ensureColumn(normalized, col.kind or "default", col.index)
    end
    for key, cell in pairs(matrix.cells or {}) do
        if cell and cell.texture then
            normalized.cells[key] = {
                texture = cell.texture,
                name = cell.name,
                kind = cell.kind,
                auto = cell.auto,
                manual = cell.manual,
            }
        end
    end
    return finalizeMatrix(normalized)
end
