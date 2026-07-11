DudesKeyMacros = DudesKeyMacros or {}

local ADDON = DudesKeyMacros
local BUTTON_PREFIX = "DKM_"
local MODIFIERS = { "SHIFT", "CTRL", "ALT" }
local TOGGLE_BINDING_ACTION = "CLICK DudesKeyMacrosToggleButton:LeftButton"
local CHARACTER_BINDING_SET = 2

ADDON.keys = {
    "ESCAPE",
    "^", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "ß", "´",
    "TAB",
    "CAPSLOCK",
    "Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P", "Ü", "+",
    "A", "S", "D", "F", "G", "H", "J", "K", "L", "Ö", "Ä", "#",
    "<",
    "SPACE", "PRINTSCREEN",
    "Y", "X", "C", "V", "B", "N", "M", ",", ".", "-",
    "F1", "F2", "F3", "F4", "F5", "F6",
    "F7", "F8", "F9", "F10", "F11", "F12",
}

ADDON.mouseKeys = {
    "MOUSEWHEELUP",
    "MOUSEWHEELDOWN",
    "BUTTON3",
    "BUTTON5",
    "BUTTON4",
}

local ownerFrame
local toggleButton
local runtimeButtons = {}
local pendingRuntimeUpdate
local pendingDefaultBindingUpdate
local initialized
local macroErrorHandlerInstalled
local previousErrorHandler
local draftLayout
local draftDirty
local isOwnBindingAction
local applyDefaultBindingActionNow

local BLIZZARD_DEFAULT_BINDINGS = {
    ESCAPE = { normal = "TOGGLEGAMEMENU" },
    F1 = { normal = "TARGETSELF" },
    F2 = { normal = "TARGETPARTYMEMBER1" },
    F3 = { normal = "TARGETPARTYMEMBER2" },
    F4 = { normal = "TARGETPARTYMEMBER3" },
    F5 = { normal = "TARGETPARTYMEMBER4" },
    F6 = { normal = "SHAPESHIFTBUTTON6" },
    F7 = { normal = "SHAPESHIFTBUTTON7" },
    F8 = { normal = "TOGGLEBAG1" },
    F9 = { normal = "TOGGLEBAG2" },
    F10 = { normal = "TOGGLEBAG3" },
    F11 = { normal = "TOGGLEBAG4" },
    F12 = { normal = "TOGGLEBACKPACK" },
    ["1"] = { normal = "ACTIONBUTTON1" },
    ["2"] = { normal = "ACTIONBUTTON2" },
    ["3"] = { normal = "ACTIONBUTTON3" },
    ["4"] = { normal = "ACTIONBUTTON4" },
    ["5"] = { normal = "ACTIONBUTTON5" },
    ["6"] = { normal = "ACTIONBUTTON6" },
    ["7"] = { normal = "ACTIONBUTTON7" },
    ["8"] = { normal = "ACTIONBUTTON8" },
    ["9"] = { normal = "ACTIONBUTTON9" },
    ["0"] = { normal = "ACTIONBUTTON10" },
    ["ß"] = { normal = "ACTIONBUTTON11" },
    ["´"] = { normal = "ACTIONBUTTON12" },
    TAB = { normal = "TARGETNEARESTENEMY" },
    CAPSLOCK = { normal = "TOGGLEAUTORUN" },
    Q = { normal = "STRAFELEFT" },
    W = { normal = "MOVEFORWARD" },
    E = { normal = "STRAFERIGHT" },
    R = { normal = "REPLY" },
    T = { normal = "ATTACKTARGET" },
    U = { normal = "TOGGLECHARACTER4" },
    I = { normal = "TOGGLEDUNGEONSANDRAIDS" },
    O = { normal = "TOGGLESOCIAL" },
    P = { normal = "TOGGLESPELLBOOK" },
    ["+"] = { normal = "MINIMAPZOOMIN" },
    A = { normal = "TURNLEFT" },
    S = { normal = "MOVEBACKWARD" },
    D = { normal = "TURNRIGHT" },
    F = { normal = "ASSISTTARGET" },
    G = { normal = "TARGETLASTHOSTILE" },
    H = { normal = "TOGGLEPVP" },
    K = { normal = "TOGGLECHARACTER3" },
    L = { normal = "TOGGLEQUESTLOG" },
    Y = { normal = "TOGGLESHEATH" },
    X = { normal = "SITORSTAND" },
    C = { normal = "TOGGLECHARACTER0" },
    V = { normal = "NAMEPLATES" },
    B = { normal = "OPENALLBAGS" },
    N = { normal = "TOGGLETALENTS" },
    M = { normal = "TOGGLEWORLDMAP" },
    ["-"] = { normal = "MINIMAPZOOMOUT" },
    SPACE = { normal = "JUMP" },
    PRINTSCREEN = { normal = "SCREENSHOT" },
    MOUSEWHEELUP = { normal = "MINIMAPZOOMIN" },
    MOUSEWHEELDOWN = { normal = "MINIMAPZOOMOUT" },
    BUTTON4 = { normal = "TOGGLEAUTORUN" },
}

local function printMessage(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffDudesKeyMacros:|r " .. text)
end

local function getRealmName()
    return GetRealmName() or "UnknownRealm"
end

local function getCharacterName()
    return UnitName("player") or "UnknownCharacter"
end

local function getActiveSpec()
    if GetActiveTalentGroup then
        return GetActiveTalentGroup() or 1
    end
    return 1
end

local function ensureTable(parent, key)
    if not parent[key] then
        parent[key] = {}
    end
    return parent[key]
end

local function ensureSpec(character, specIndex)
    character.specs = character.specs or {}
    character.specs[specIndex] = character.specs[specIndex] or { bindings = {} }
    character.specs[specIndex].bindings = character.specs[specIndex].bindings or {}
    character.specs[specIndex].defaultBindings = character.specs[specIndex].defaultBindings or {}
    return character.specs[specIndex]
end

local function copyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            copy[key] = copyTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local function tablesEqual(a, b)
    a = a or {}
    b = b or {}
    for key, value in pairs(a) do
        if type(value) == "table" then
            if not tablesEqual(value, b[key]) then
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

local function getClassName()
    local _, classFile = UnitClass("player")
    return classFile or ""
end

local function getTalentSummary()
    local parts = {}
    local talentGroup = getActiveSpec()
    if GetTalentTabInfo then
        for i = 1, 3 do
            local _, _, pointsSpent = GetTalentTabInfo(i, false, false, talentGroup)
            table.insert(parts, tostring(pointsSpent or 0))
        end
    end
    return table.concat(parts, "/")
end

local function getLayoutKeyList()
    local keys = {}
    for _, key in ipairs(ADDON.keys) do
        table.insert(keys, key)
    end
    for _, key in ipairs(ADDON.mouseKeys) do
        table.insert(keys, key)
    end
    return keys
end

local function makeEmptyLayout()
    return {
        bindings = {},
        defaultBindings = {},
    }
end

local function normalizeLayout(layout)
    layout = layout or {}
    layout.bindings = layout.bindings or {}
    layout.defaultBindings = layout.defaultBindings or {}
    return layout
end

local function buildBlizzardDefaultLayout()
    return {
        bindings = {},
        defaultBindings = copyTable(BLIZZARD_DEFAULT_BINDINGS),
    }
end

local function getCurrentAppliedLayout()
    local spec = ADDON.GetCurrentSpecDB()
    return {
        bindings = copyTable(spec.bindings),
        defaultBindings = copyTable(spec.defaultBindings),
    }
end

local function setDraftLayout(layout, dirty)
    draftLayout = normalizeLayout(copyTable(layout))
    draftDirty = dirty and true or nil
    if ADDON.RefreshOverlay then
        ADDON.RefreshOverlay()
    end
end

local function captureLiveDefaultBindings(spec)
    if spec.defaultBindingsInitialized then
        return
    end

    spec.defaultBindings = spec.defaultBindings or {}
    for _, key in ipairs(getLayoutKeyList()) do
        for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
            local action = GetBindingAction(variant.key)
            if action and action ~= "" and not isOwnBindingAction(action) then
                spec.defaultBindings[key] = spec.defaultBindings[key] or {}
                spec.defaultBindings[key][variant.modifier or "normal"] = action
            end
        end
    end
    spec.defaultBindingsInitialized = true
end

function ADDON.InitDB()
    DudesKeyMacrosDB = DudesKeyMacrosDB or {}
    DudesKeyMacrosDB.profiles = DudesKeyMacrosDB.profiles or {}
    DudesKeyMacrosDB.sharedProfiles = DudesKeyMacrosDB.sharedProfiles or {}
    DudesKeyMacrosDB.savedLayouts = DudesKeyMacrosDB.savedLayouts or {}

    local realm = ensureTable(DudesKeyMacrosDB.profiles, getRealmName())
    local character = ensureTable(realm, getCharacterName())
    character.settings = character.settings or {}
    character.settings.layout = character.settings.layout or "QWERTZ"
    character.settings.toggleKey = nil
    if character.settings.showMinimapButton == nil then
        character.settings.showMinimapButton = true
    end
    if character.settings.bindModifiers == nil then
        character.settings.bindModifiers = true
    end
    character.specs = character.specs or {}
    ensureSpec(character, 1)
    ensureSpec(character, 2)
end

function ADDON.GetCharacterDB()
    ADDON.InitDB()
    return DudesKeyMacrosDB.profiles[getRealmName()][getCharacterName()]
end

function ADDON.GetSettings()
    return ADDON.GetCharacterDB().settings
end

function ADDON.GetCurrentSpecIndex()
    return getActiveSpec()
end

function ADDON.GetCurrentSpecDB()
    local character = ADDON.GetCharacterDB()
    return ensureSpec(character, getActiveSpec())
end

function ADDON.EnsureDraftLayout()
    if not draftLayout then
        setDraftLayout(getCurrentAppliedLayout(), false)
    end
    return draftLayout
end

function ADDON.ResetDraftToApplied()
    setDraftLayout(getCurrentAppliedLayout(), false)
end

function ADDON.HasPendingChanges()
    return false
end

function ADDON.GetDraftLayout()
    return ADDON.EnsureDraftLayout()
end

function ADDON.GetAppliedLayout()
    return getCurrentAppliedLayout()
end

function ADDON.GetBinding(key)
    local spec = ADDON.GetCurrentSpecDB()
    return spec.bindings[key]
end

function ADDON.GetOrCreateBinding(key)
    local spec = ADDON.GetCurrentSpecDB()
    spec.bindings[key] = spec.bindings[key] or { macrotext = "", icons = {} }
    spec.bindings[key].icons = spec.bindings[key].icons or {}
    return spec.bindings[key]
end

local function normalizeIconList(icons)
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

function ADDON.SetBindingData(key, macrotext, icons)
    macrotext = macrotext or ""
    icons = normalizeIconList(icons)
    local spec = ADDON.GetCurrentSpecDB()
    local oldBinding = spec.bindings[key]
    if oldBinding and (oldBinding.macrotext or "") == macrotext and tablesEqual(normalizeIconList(oldBinding.icons), icons) then
        return
    end
    local binding = ADDON.GetOrCreateBinding(key)
    binding.macrotext = macrotext
    binding.icons = icons
    binding.iconMatrix = nil
    ADDON.ApplyRuntime()
    if ADDON.RefreshOverlay then
        ADDON.RefreshOverlay()
    end
end

local function getButtonNameForKey(key)
    local name = string.upper(key or "")
    name = string.gsub(name, "[^A-Z0-9]", "_")
    return BUTTON_PREFIX .. name
end

local function getBindingKeys(key)
    local bindingKeys = { key }
    if ADDON.GetSettings().bindModifiers then
        for _, modifier in ipairs(MODIFIERS) do
            table.insert(bindingKeys, modifier .. "-" .. key)
        end
    end
    return bindingKeys
end

function ADDON.GetBindingKeysForKey(key)
    return getBindingKeys(key)
end

function ADDON.GetDefaultBindingKeysForKey(key)
    return {
        { label = "Normal", key = key, modifier = "normal" },
        { label = "Shift", key = "SHIFT-" .. key, modifier = "shift" },
        { label = "Ctrl", key = "CTRL-" .. key, modifier = "ctrl" },
        { label = "Alt", key = "ALT-" .. key, modifier = "alt" },
    }
end

isOwnBindingAction = function(action)
    return action and string.find(action, "CLICK " .. BUTTON_PREFIX, 1, true)
end

function ADDON.IsOwnBindingAction(action)
    return isOwnBindingAction(action)
end

function ADDON.GetBindingDisplayName(action)
    if not action or action == "" then
        return ""
    end

    if string.find(action, "CLICK DudesKeyMacrosToggleButton", 1, true) then
        return "DudesKeyMacros: Toggle layout editor"
    end

    local text = GetBindingText(action, "BINDING_NAME_")
    if text and text ~= "" then
        return text
    end
    return action
end

function ADDON.GetConflicts(key)
    local conflicts = {}
    local spec = ADDON.GetCurrentSpecDB()
    local keyDefaults = spec.defaultBindings[key] or {}
    for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
        local action = keyDefaults[variant.modifier or "normal"]
        if action and action ~= "" then
            table.insert(conflicts, {
                key = variant.key,
                action = action,
            })
        end
    end
    return conflicts
end

function ADDON.GetDefaultBindingAction(bindingKey)
    local spec = ADDON.GetCurrentSpecDB()
    for _, key in ipairs(getLayoutKeyList()) do
        for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
            if variant.key == bindingKey then
                local keyDefaults = spec.defaultBindings[key] or {}
                return keyDefaults[variant.modifier or "normal"] or ""
            end
        end
    end
    return ""
end

function ADDON.SetDefaultBindingAction(bindingKey, action)
    local spec = ADDON.GetCurrentSpecDB()
    for _, key in ipairs(getLayoutKeyList()) do
        for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
            if variant.key == bindingKey then
                local oldAction = ((spec.defaultBindings[key] or {})[variant.modifier or "normal"]) or ""
                action = action or ""
                if oldAction == action then
                    return true
                end
                spec.defaultBindings[key] = spec.defaultBindings[key] or {}
                spec.defaultBindings[key][variant.modifier or "normal"] = action ~= "" and action or nil
                if next(spec.defaultBindings[key]) == nil then
                    spec.defaultBindings[key] = nil
                end
                if applyDefaultBindingActionNow then
                    applyDefaultBindingActionNow(bindingKey, action)
                end
                ADDON.ApplyRuntime()
                if ADDON.RefreshOverlay then
                    ADDON.RefreshOverlay()
                end
                return true
            end
        end
    end
    return false
end

function ADDON.FindDraftBindingForAction(action, excludedBindingKey)
    if not action or action == "" then
        return nil
    end

    local spec = ADDON.GetCurrentSpecDB()
    for _, key in ipairs(getLayoutKeyList()) do
        local keyDefaults = spec.defaultBindings[key]
        if keyDefaults then
            for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
                if variant.key ~= excludedBindingKey and keyDefaults[variant.modifier or "normal"] == action then
                    return {
                        key = key,
                        bindingKey = variant.key,
                        modifier = variant.modifier or "normal",
                        action = action,
                    }
                end
            end
        end
    end
    if GetBindingKey then
        local bindingKey1, bindingKey2 = GetBindingKey(action)
        if bindingKey1 and bindingKey1 ~= excludedBindingKey then
            return {
                bindingKey = bindingKey1,
                action = action,
                external = true,
            }
        end
        if bindingKey2 and bindingKey2 ~= excludedBindingKey then
            return {
                bindingKey = bindingKey2,
                action = action,
                external = true,
            }
        end
    end
    return nil
end

function ADDON.ClearDefaultBindingAction(bindingKey)
    return ADDON.SetDefaultBindingAction(bindingKey, "")
end

function ADDON.GetAvailableBindingActions(filter)
    local actions = {}
    local seen = {}
    filter = string.lower(filter or "")

    local toggleName = ADDON.GetBindingDisplayName(TOGGLE_BINDING_ACTION)
    if filter == "" or string.find(string.lower(toggleName), filter, 1, true) then
        table.insert(actions, {
            command = TOGGLE_BINDING_ACTION,
            name = toggleName,
        })
        seen[TOGGLE_BINDING_ACTION] = true
    end

    if not GetNumBindings or not GetBinding then
        return actions
    end

    for i = 1, GetNumBindings() do
        local command = GetBinding(i)
        if command and command ~= "" and not seen[command] then
            local name = ADDON.GetBindingDisplayName(command)
            local haystack = string.lower((name or "") .. " " .. command)
            if filter == "" or string.find(haystack, filter, 1, true) then
                seen[command] = true
                table.insert(actions, {
                    command = command,
                    name = name,
                })
            end
        end
    end

    table.sort(actions, function(a, b)
        return (a.name or a.command) < (b.name or b.command)
    end)
    return actions
end

function ADDON.ClearDefaultBindingsForKey(key)
    local spec = ADDON.GetCurrentSpecDB()
    spec.defaultBindings[key] = nil
    ADDON.ApplyRuntime()
    if ADDON.RefreshOverlay then
        ADDON.RefreshOverlay()
    end
    return true
end

local function ensureOwnerFrame()
    if ownerFrame then
        return ownerFrame
    end

    ownerFrame = CreateFrame("Frame", "DudesKeyMacrosOwnerFrame", UIParent)
    ownerFrame:Hide()

    toggleButton = CreateFrame("Button", "DudesKeyMacrosToggleButton", UIParent)
    toggleButton:SetScript("OnClick", function()
        if ADDON.ToggleOverlay then
            ADDON.ToggleOverlay()
        end
    end)
    toggleButton:Hide()

    return ownerFrame
end

local function installMacroErrorHandler()
    if macroErrorHandlerInstalled or not seterrorhandler then
        return
    end

    if geterrorhandler then
        previousErrorHandler = geterrorhandler()
    end
    seterrorhandler(function(message)
        if ADDON.executingMacroKey then
            printMessage("Makro auf Taste '" .. tostring(ADDON.executingMacroKey) .. "' hat einen Fehler verursacht. Bitte ueberpruefe das Makro.")
            ADDON.executingMacroKey = nil
            return
        end
        if previousErrorHandler then
            previousErrorHandler(message)
        elseif DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(tostring(message))
        end
    end)
    macroErrorHandlerInstalled = true
end

local function ensureRuntimeButton(key)
    local buttonName = getButtonNameForKey(key)
    if runtimeButtons[key] then
        return runtimeButtons[key]
    end

    local button = CreateFrame("Button", buttonName, UIParent, "SecureActionButtonTemplate")
    button.dkmKey = key
    button:SetAttribute("type", "macro")
    button:SetAttribute("type1", "macro")
    button:SetScript("PreClick", function(self)
        ADDON.executingMacroKey = self.dkmKey
    end)
    button:SetScript("PostClick", function()
        ADDON.executingMacroKey = nil
    end)
    button:Hide()
    runtimeButtons[key] = button
    return button
end

local function setRuntimeMacroAttributes(button, macrotext)
    macrotext = macrotext or ""
    macrotext = string.gsub(macrotext, "([%[,])mod:", "%1modifier:")
    macrotext = string.gsub(macrotext, "([%[,])nomod:", "%1nomodifier:")
    macrotext = string.gsub(macrotext, "([%[,])mod([,%]])", "%1modifier%2")
    macrotext = string.gsub(macrotext, "([%[,])nomod([,%]])", "%1nomodifier%2")

    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", macrotext)
    button:SetAttribute("type1", "macro")
    button:SetAttribute("macrotext1", macrotext)
    button:SetAttribute("shift-type1", "macro")
    button:SetAttribute("shift-macrotext1", macrotext)
    button:SetAttribute("ctrl-type1", "macro")
    button:SetAttribute("ctrl-macrotext1", macrotext)
    button:SetAttribute("alt-type1", "macro")
    button:SetAttribute("alt-macrotext1", macrotext)
end

function ADDON.QueueRuntimeUpdate()
    pendingRuntimeUpdate = true
end

function ADDON.ApplyRuntime()
    ensureOwnerFrame()
    installMacroErrorHandler()

    if InCombatLockdown() then
        ADDON.QueueRuntimeUpdate()
        printMessage("Runtime update is queued until combat ends.")
        return false
    end

    ClearOverrideBindings(ownerFrame)

    local spec = ADDON.GetCurrentSpecDB()
    for key, binding in pairs(spec.bindings) do
        if binding.macrotext and binding.macrotext ~= "" then
            local button = ensureRuntimeButton(key)
            local ok = pcall(setRuntimeMacroAttributes, button, binding.macrotext)
            if ok then
                local buttonName = button:GetName()
                local keyDefaults = spec.defaultBindings[key] or {}

                if not keyDefaults.normal or keyDefaults.normal == "" then
                    ok = pcall(SetOverrideBindingClick, ownerFrame, true, key, buttonName, "LeftButton")
                end
            end
            if not ok then
                printMessage("Makro auf Taste '" .. tostring(key) .. "' hat einen Fehler verursacht. Bitte ueberpruefe das Makro.")
            end
        end
    end

    pendingRuntimeUpdate = nil
    return true
end

function ADDON.SaveBinding(key, macrotext, icons)
    ADDON.SetBindingData(key, macrotext, icons)
    if ADDON.RefreshOverlay then
        ADDON.RefreshOverlay()
    end
end

function ADDON.ClearBinding(key)
    local spec = ADDON.GetCurrentSpecDB()
    if not spec.bindings[key] then
        return
    end
    spec.bindings[key] = nil
    ADDON.ApplyRuntime()
    if ADDON.RefreshOverlay then
        ADDON.RefreshOverlay()
    end
end

local clearPermanentBindingsForAction

local function setPermanentBinding(bindingKey, action)
    if action == TOGGLE_BINDING_ACTION and SetBindingClick then
        SetBindingClick(bindingKey, "DudesKeyMacrosToggleButton")
    elseif action and action ~= "" then
        SetBinding(bindingKey, action)
    else
        SetBinding(bindingKey)
    end
end

applyDefaultBindingActionNow = function(bindingKey, action)
    if InCombatLockdown() then
        printMessage("Interface binding update is blocked during combat.")
        pendingDefaultBindingUpdate = true
        return false
    end
    if action and action ~= "" then
        clearPermanentBindingsForAction(action, bindingKey)
    end
    setPermanentBinding(bindingKey, action)
    if SaveBindings then
        SaveBindings(CHARACTER_BINDING_SET)
    end
    return true
end

clearPermanentBindingsForAction = function(action, targetBindingKey)
    if not action or action == "" or not GetBindingKey then
        return
    end

    local bindingKey1, bindingKey2 = GetBindingKey(action)
    if bindingKey1 and bindingKey1 ~= targetBindingKey then
        SetBinding(bindingKey1)
    end
    if bindingKey2 and bindingKey2 ~= targetBindingKey then
        SetBinding(bindingKey2)
    end
end

local function applyCurrentDefaultBindings()
    if InCombatLockdown() then
        pendingDefaultBindingUpdate = true
        return false
    end

    local spec = ADDON.GetCurrentSpecDB()
    for _, key in ipairs(getLayoutKeyList()) do
        local keyDefaults = spec.defaultBindings[key] or {}
        for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
            local action = keyDefaults[variant.modifier or "normal"]
            if action and action ~= "" then
                clearPermanentBindingsForAction(action, variant.key)
            end
            setPermanentBinding(variant.key, action)
        end
    end
    if SaveBindings then
        SaveBindings(CHARACTER_BINDING_SET)
    end
    pendingDefaultBindingUpdate = nil
    return true
end

function ADDON.EnsureCharacterBindingSet()
    if InCombatLockdown() then
        return false
    end
    if SaveBindings then
        SaveBindings(CHARACTER_BINDING_SET)
    end
    return true
end

function ADDON.ApplyDraftLayout()
    if InCombatLockdown() then
        printMessage("Runtime update is queued until combat ends.")
        ADDON.QueueRuntimeUpdate()
        return false
    end
    ADDON.ApplyRuntime()
    return true
end

function ADDON.DiscardDraftLayout()
    return true
end

function ADDON.LoadLayoutIntoDraft(layout)
    return ADDON.LoadLayout(layout)
end

local function makeProfile(name, layout, systemId, protected)
    return {
        id = systemId or name,
        name = name,
        system = protected and true or nil,
        createdAt = date("%Y-%m-%d %H:%M"),
        characterName = getCharacterName(),
        className = getClassName(),
        specText = getTalentSummary(),
        bindings = copyTable((layout or {}).bindings),
        defaultBindings = copyTable((layout or {}).defaultBindings),
    }
end

function ADDON.GetLayoutProfiles()
    ADDON.InitDB()
    local profiles = {
        makeProfile("Alles leer", makeEmptyLayout(), "system_empty", true),
        makeProfile("Blizzard default bindings", buildBlizzardDefaultLayout(), "system_blizzard_defaults", true),
    }
    profiles[1].createdAt = "-"
    profiles[1].characterName = "-"
    profiles[1].className = "-"
    profiles[1].specText = "-"
    profiles[2].createdAt = "-"
    profiles[2].characterName = "-"
    profiles[2].className = "-"
    profiles[2].specText = "-"

    for name, profile in pairs(DudesKeyMacrosDB.savedLayouts or {}) do
        local copy = copyTable(profile)
        copy.id = name
        copy.name = copy.name or name
        table.insert(profiles, copy)
    end

    table.sort(profiles, function(a, b)
        if a.system and not b.system then
            return true
        elseif b.system and not a.system then
            return false
        end
        return (a.name or "") < (b.name or "")
    end)
    return profiles
end

local function findLayoutProfile(profileId)
    for _, profile in ipairs(ADDON.GetLayoutProfiles()) do
        if profile.id == profileId then
            return profile
        end
    end
    return nil
end

function ADDON.LoadLayout(layout)
    if InCombatLockdown() then
        printMessage("Layout cannot be loaded during combat.")
        return false
    end

    layout = layout or makeEmptyLayout()
    local spec = ADDON.GetCurrentSpecDB()
    spec.bindings = copyTable(layout.bindings or {})
    spec.defaultBindings = copyTable(layout.defaultBindings or {})

    applyCurrentDefaultBindings()

    ADDON.ApplyRuntime()
    if ADDON.RefreshOverlay then
        ADDON.RefreshOverlay()
    end
    return true
end

function ADDON.LoadLayoutProfile(profileId)
    local profile = findLayoutProfile(profileId)
    if not profile then
        return false
    end
    if not ADDON.LoadLayout({
        bindings = profile.bindings or {},
        defaultBindings = profile.defaultBindings or {},
    }) then
        return false
    end
    printMessage("Loaded layout '" .. profile.name .. "'.")
    return true
end

function ADDON.SaveAppliedLayoutProfile(name)
    ADDON.InitDB()
    name = string.gsub(name or "", "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    if name == "" then
        return false
    end
    if name == "system_empty" or name == "system_blizzard_defaults" then
        return false
    end
    local lowerName = string.lower(name)
    for _, profile in ipairs(ADDON.GetLayoutProfiles()) do
        if string.lower(profile.name or "") == lowerName then
            return false
        end
    end

    local layout = getCurrentAppliedLayout()
    DudesKeyMacrosDB.savedLayouts[name] = makeProfile(name, layout, name, false)
    printMessage("Saved layout '" .. name .. "'.")
    return true
end

function ADDON.DeleteLayoutProfile(profileId)
    ADDON.InitDB()
    local profile = findLayoutProfile(profileId)
    if not profile or profile.system then
        return false
    end
    DudesKeyMacrosDB.savedLayouts[profileId] = nil
    return true
end

function ADDON.CopyCurrentSpecToSharedProfile(profileName)
    if not profileName or profileName == "" then
        return
    end
    ADDON.InitDB()
    DudesKeyMacrosDB.sharedProfiles[profileName] = {
        bindings = copyTable(ADDON.GetCurrentSpecDB().bindings),
    }
    return true
end

function ADDON.LoadSharedProfileToCurrentSpec(profileName)
    ADDON.InitDB()
    local profile = profileName and DudesKeyMacrosDB.sharedProfiles[profileName]
    if not profile then
        return false
    end
    ADDON.GetCurrentSpecDB().bindings = copyTable(profile.bindings or {})
    ADDON.ApplyRuntime()
    if ADDON.RefreshOverlay then
        ADDON.RefreshOverlay()
    end
    return true
end

function ADDON.CopyTable(source)
    return copyTable(source)
end

local function refreshForWorldState()
    ADDON.InitDB()
    captureLiveDefaultBindings(ADDON.GetCurrentSpecDB())
    ADDON.EnsureCharacterBindingSet()
    if not initialized then
        ensureOwnerFrame()
        if ADDON.CreateOverlay then
            ADDON.CreateOverlay()
        end
        if ADDON.CreateMinimapButton then
            ADDON.CreateMinimapButton()
        end
        initialized = true
    end
    ADDON.ResetDraftToApplied()
    applyCurrentDefaultBindings()
    ADDON.ApplyRuntime()
    if ADDON.RefreshOverlay then
        ADDON.RefreshOverlay()
    end
end

local function getFirstArgument(text)
    text = text or ""
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function handleSlashCommand(text)
    local command, rest = string.match(text or "", "^(%S+)%s*(.*)$")
    command = string.lower(command or "")
    rest = getFirstArgument(rest)

    if command == "profile-save" and rest ~= "" then
        ADDON.CopyCurrentSpecToSharedProfile(rest)
        printMessage("Saved current spec to shared profile '" .. rest .. "'.")
    elseif command == "profile-load" and rest ~= "" then
        if ADDON.LoadSharedProfileToCurrentSpec(rest) then
            printMessage("Loaded shared profile '" .. rest .. "' into current spec.")
        else
            printMessage("Shared profile '" .. rest .. "' was not found.")
        end
    elseif command == "settings" then
        if ADDON.ToggleSettings then
            ADDON.ToggleSettings()
        end
    elseif command == "refresh" then
        ADDON.ApplyRuntime()
        printMessage("Runtime refreshed.")
    else
        if ADDON.ToggleOverlay then
            ADDON.ToggleOverlay()
        end
        printMessage("Commands: /dkm, /dkm settings, /dkm refresh, /dkm profile-save Name, /dkm profile-load Name")
    end
end

SLASH_DUDESKEYMACROS1 = "/dkm"
SLASH_DUDESKEYMACROS2 = "/dudeskeymacros"
SlashCmdList["DUDESKEYMACROS"] = handleSlashCommand

DudesUtils.EventHandler.Add("PLAYER_LOGIN", refreshForWorldState)
DudesUtils.EventHandler.Add("PLAYER_ENTERING_WORLD", refreshForWorldState)
DudesUtils.EventHandler.Add("ACTIVE_TALENT_GROUP_CHANGED", refreshForWorldState)
DudesUtils.EventHandler.Add("PLAYER_REGEN_ENABLED", function()
    if pendingDefaultBindingUpdate then
        applyCurrentDefaultBindings()
    end
    if pendingRuntimeUpdate then
        ADDON.ApplyRuntime()
    end
end)
