local ADDON = DudesKeyMacros

local function trim(text)
    text = text or ""
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function stripConditionals(text)
    text = string.gsub(text or "", "%b[]", "")
    return trim(text)
end

local function addSuggestion(suggestions, seen, name, texture, kind)
    if not texture or texture == "" then
        return
    end
    if seen[texture] then
        return
    end
    seen[texture] = true
    table.insert(suggestions, {
        name = name or texture,
        texture = texture,
        kind = kind or "texture",
    })
end

local function addSpellSuggestion(suggestions, seen, spellName)
    spellName = stripConditionals(spellName)
    if spellName == "" then
        return
    end

    local name, _, texture = GetSpellInfo(spellName)
    addSuggestion(suggestions, seen, name or spellName, texture, "spell")
end

local function addItemSuggestion(suggestions, seen, itemName)
    itemName = stripConditionals(itemName)
    if itemName == "" then
        return
    end

    local name, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemName)
    addSuggestion(suggestions, seen, name or itemName, texture, "item")
end

local function scanCommandPayloads(macrotext, command, callback)
    for line in string.gmatch(macrotext or "", "[^\r\n]+") do
        local payload = string.match(line, "^%s*/" .. command .. "%s+(.+)")
        if payload then
            for segment in string.gmatch(payload, "([^;]+)") do
                callback(segment)
            end
        end
    end
end

function ADDON.GetMacroIconSuggestions(macrotext)
    local suggestions = {}
    local seen = {}

    scanCommandPayloads(macrotext, "cast", function(segment)
        addSpellSuggestion(suggestions, seen, segment)
    end)
    scanCommandPayloads(macrotext, "castsequence", function(segment)
        segment = stripConditionals(segment)
        for spellName in string.gmatch(segment, "([^,]+)") do
            addSpellSuggestion(suggestions, seen, spellName)
        end
    end)
    scanCommandPayloads(macrotext, "use", function(segment)
        addItemSuggestion(suggestions, seen, segment)
    end)

    return suggestions
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

    macrotext = string.lower(macrotext or "")
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
