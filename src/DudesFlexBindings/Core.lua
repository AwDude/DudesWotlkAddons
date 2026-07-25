DudesFlexBindings = DudesFlexBindings or {}

local ADDON = DudesFlexBindings
local BUTTON_PREFIX = "DFB_"
local MODIFIERS = { "SHIFT", "CTRL", "ALT" }
local TOGGLE_BINDING_ACTION = "DUDESFLEXBINDINGS_TOGGLE"
local ACCOUNT_BINDING_SET = 1
local CHARACTER_BINDING_SET = 2
local BONUS_BAR_SLOT_COUNT = 12
local EXPORT_PREFIX = "DudesFlexBindings:1:"
local DEFAULT_BONUS_BAR_SETTINGS = {
    showBonusBar = true,
    alignBonusBar = false,
    bonusBarAnchor = "topLeft",
    bonusBarGrowthDirection = "right",
    showBonusBarBindings = true,
    showBonusBarTooltips = true,
    clickBonusBarButtons = false,
    bonusBarBindingFontSize = 10,
    bonusBar = {},
}
local SHARED_GENERAL_SETTING_KEYS = {
    showMinimapButton = true,
    triggerOnKeyDown = true,
}

BINDING_HEADER_DUDESADDONS = "Dude's Addons"
BINDING_NAME_DUDESFLEXBINDINGS_TOGGLE = "Dude's Flex Bindings: Fenster ein-/ausblenden"

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
local runtimeButtons = {}
local pendingRuntimeUpdate
local pendingDefaultBindingUpdate
local initialized
local macroErrorHandlerInstalled
local previousErrorHandler
local draftLayout
local isOwnBindingAction
local applyDefaultBindingActionNow
local dominosPossessBarHooked
local copyTable

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

local BLIZZARD_DEFAULT_BONUS_BAR_BINDINGS = {
    ["1"] = { normal = 1 },
    ["2"] = { normal = 2 },
    ["3"] = { normal = 3 },
    ["4"] = { normal = 4 },
    ["5"] = { normal = 5 },
    ["6"] = { normal = 6 },
    ["7"] = { normal = 7 },
    ["8"] = { normal = 8 },
    ["9"] = { normal = 9 },
    ["0"] = { normal = 10 },
    ["ß"] = { normal = 11 },
    ["´"] = { normal = 12 },
}

local function printMessage(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffDudesFlexBindings:|r " .. text)
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
    character.specs[specIndex].macroPlaceholders = character.specs[specIndex].macroPlaceholders or {}
    if character.specs[specIndex].bonusBarBindings == nil then
        character.specs[specIndex].bonusBarBindings = DudesUtils.Table.Copy(BLIZZARD_DEFAULT_BONUS_BAR_BINDINGS)
    end
    return character.specs[specIndex]
end

local function ensureBonusBarSettings(settings)
    for key, value in pairs(DEFAULT_BONUS_BAR_SETTINGS) do
        if type(value) == "table" then
            settings[key] = settings[key] or copyTable(value)
        elseif settings[key] == nil then
            settings[key] = value
        end
    end
    settings.bonusBar = settings.bonusBar or {}
    return settings
end

copyTable = function(source)
    return DudesUtils.Table.Copy(source)
end

local function tablesEqual(a, b)
    return DudesUtils.Table.Equals(a, b)
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
        bonusBarBindings = {},
        bonusBarSettings = copyTable(DEFAULT_BONUS_BAR_SETTINGS),
        macroPlaceholders = {},
    }
end

local function normalizeLayout(layout)
    layout = layout or {}
    layout.bindings = layout.bindings or {}
    layout.defaultBindings = layout.defaultBindings or {}
    layout.bonusBarBindings = layout.bonusBarBindings or {}
    layout.bonusBarSettings = ensureBonusBarSettings(layout.bonusBarSettings or {})
    layout.macroPlaceholders = layout.macroPlaceholders or {}
    return layout
end

local function buildBlizzardDefaultLayout()
    return {
        bindings = {},
        defaultBindings = copyTable(BLIZZARD_DEFAULT_BINDINGS),
        bonusBarBindings = copyTable(BLIZZARD_DEFAULT_BONUS_BAR_BINDINGS),
        bonusBarSettings = copyTable(DEFAULT_BONUS_BAR_SETTINGS),
        macroPlaceholders = {},
    }
end

local function getCurrentAppliedLayout()
    local spec = ADDON.GetCurrentSpecDB()
    local bonusSpec = ADDON.GetBonusBarSpecDB()
    return {
        bindings = copyTable(spec.bindings),
        defaultBindings = copyTable(spec.defaultBindings),
        bonusBarBindings = copyTable(bonusSpec.bonusBarBindings),
        bonusBarSettings = copyTable(ADDON.GetBonusBarSettings()),
        macroPlaceholders = copyTable(spec.macroPlaceholders),
    }
end

local function setDraftLayout(layout)
    draftLayout = normalizeLayout(copyTable(layout))
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
    DudesFlexBindingsDB = DudesFlexBindingsDB or {}
    DudesFlexBindingsDB.profiles = DudesFlexBindingsDB.profiles or {}
    DudesFlexBindingsDB.sharedProfiles = DudesFlexBindingsDB.sharedProfiles or {}
    DudesFlexBindingsDB.savedLayouts = DudesFlexBindingsDB.savedLayouts or {}
    DudesFlexBindingsDB.sharedBonusBar = DudesFlexBindingsDB.sharedBonusBar or {}
    DudesFlexBindingsDB.sharedBonusBar.settings = ensureBonusBarSettings(DudesFlexBindingsDB.sharedBonusBar.settings or {})
    DudesFlexBindingsDB.sharedBonusBar.specs = DudesFlexBindingsDB.sharedBonusBar.specs or {}
    ensureSpec(DudesFlexBindingsDB.sharedBonusBar, 1)
    ensureSpec(DudesFlexBindingsDB.sharedBonusBar, 2)

    local realm = ensureTable(DudesFlexBindingsDB.profiles, getRealmName())
    local character = ensureTable(realm, getCharacterName())
    character.settings = character.settings or {}
    character.settings.layout = character.settings.layout or "QWERTZ"
    character.settings.toggleKey = nil
    if character.settings.showMinimapButton == nil then
        character.settings.showMinimapButton = true
    end
    character.settings.minimapAngle = character.settings.minimapAngle or 225
    if character.settings.bindModifiers == nil then
        character.settings.bindModifiers = true
    end
    if character.settings.triggerOnKeyDown == nil then
        character.settings.triggerOnKeyDown = false
    end
    ensureBonusBarSettings(character.settings)
    if character.settings.characterBonusBarSettings == nil then
        character.settings.characterBonusBarSettings = false
    end
    if DudesFlexBindingsDB.sharedSettings == nil then
        DudesFlexBindingsDB.sharedSettings = {
            showMinimapButton = character.settings.showMinimapButton,
            triggerOnKeyDown = character.settings.triggerOnKeyDown,
        }
    end
    if DudesFlexBindingsDB.sharedSettings.showMinimapButton == nil then
        DudesFlexBindingsDB.sharedSettings.showMinimapButton = true
    end
    if DudesFlexBindingsDB.sharedSettings.triggerOnKeyDown == nil then
        DudesFlexBindingsDB.sharedSettings.triggerOnKeyDown = false
    end
    character.specs = character.specs or {}
    ensureSpec(character, 1)
    ensureSpec(character, 2)
end

function ADDON.GetCharacterDB()
    ADDON.InitDB()
    return DudesFlexBindingsDB.profiles[getRealmName()][getCharacterName()]
end

function ADDON.GetSettings()
    return ADDON.GetCharacterDB().settings
end

function ADDON.IsCharacterBonusBarSettingsEnabled()
    return ADDON.GetSettings().characterBonusBarSettings ~= false
end

function ADDON.IsCharacterSpecificSettingsEnabled()
    return ADDON.IsCharacterBindingSetEnabled() and ADDON.IsCharacterBonusBarSettingsEnabled()
end

function ADDON.GetSyncedSetting(key)
    local settings = ADDON.GetSettings()
    if not SHARED_GENERAL_SETTING_KEYS[key] or ADDON.IsCharacterSpecificSettingsEnabled() then
        return settings[key]
    end
    ADDON.InitDB()
    return DudesFlexBindingsDB.sharedSettings[key]
end

function ADDON.SetSyncedSetting(key, value)
    if not SHARED_GENERAL_SETTING_KEYS[key] then
        ADDON.GetSettings()[key] = value
    elseif ADDON.IsCharacterSpecificSettingsEnabled() then
        ADDON.GetSettings()[key] = value
    else
        ADDON.InitDB()
        DudesFlexBindingsDB.sharedSettings[key] = value
    end
    return true
end

function ADDON.GetBonusBarSettings()
    local settings = ADDON.GetSettings()
    if settings.characterBonusBarSettings == false then
        ADDON.InitDB()
        return ensureBonusBarSettings(DudesFlexBindingsDB.sharedBonusBar.settings)
    end
    return ensureBonusBarSettings(settings)
end

function ADDON.GetBonusBarSpecDB()
    if ADDON.GetSettings().characterBonusBarSettings == false then
        ADDON.InitDB()
        return ensureSpec(DudesFlexBindingsDB.sharedBonusBar, getActiveSpec())
    end
    return ADDON.GetCurrentSpecDB()
end

local function copyBonusBarSettings(target, source)
    source = ensureBonusBarSettings(source or {})
    for key in pairs(DEFAULT_BONUS_BAR_SETTINGS) do
        target[key] = copyTable(source[key])
    end
    ensureBonusBarSettings(target)
end

function ADDON.SetCharacterBonusBarSettingsEnabled(enabled)
    enabled = enabled and true or false
    ADDON.InitDB()
    local settings = ADDON.GetSettings()
    if settings.characterBonusBarSettings == enabled then
        return true
    end

    local previousBonusSettings = copyTable(ADDON.GetBonusBarSettings())
    local previousBonusBindings = copyTable(ADDON.GetBonusBarSpecDB().bonusBarBindings or {})
    settings.characterBonusBarSettings = enabled

    if enabled then
        copyBonusBarSettings(settings, previousBonusSettings)
        ADDON.GetCurrentSpecDB().bonusBarBindings = previousBonusBindings
    else
        ensureBonusBarSettings(DudesFlexBindingsDB.sharedBonusBar.settings)
        ensureSpec(DudesFlexBindingsDB.sharedBonusBar, getActiveSpec())
    end

    ADDON.ApplyRuntime()
    if ADDON.RefreshBonusBar then
        ADDON.RefreshBonusBar()
    end
    if ADDON.RefreshOverlay then
        ADDON.RefreshOverlay()
    end
    if ADDON.RefreshSettings then
        ADDON.RefreshSettings()
    end
    if ADDON.RefreshEditorBindings then
        ADDON.RefreshEditorBindings()
    end
    return true
end

function ADDON.GetActiveBindingSet()
    if GetCurrentBindingSet then
        return GetCurrentBindingSet()
    end
    return CHARACTER_BINDING_SET
end

function ADDON.IsCharacterBindingSetEnabled()
    return ADDON.GetActiveBindingSet() == CHARACTER_BINDING_SET
end

function ADDON.SetCharacterBindingSetEnabled(enabled)
    if InCombatLockdown and InCombatLockdown() then
        printMessage("Interface binding set cannot be changed during combat.")
        return false
    end

    local spec = ADDON.GetCurrentSpecDB()
    if LoadBindings then
        local targetBindingSet = enabled and CHARACTER_BINDING_SET or ACCOUNT_BINDING_SET
        LoadBindings(targetBindingSet)
        spec.defaultBindings = {}
        spec.defaultBindingsInitialized = nil
        captureLiveDefaultBindings(spec)
        if SaveBindings then
            SaveBindings(targetBindingSet)
        end
    elseif SaveBindings then
        SaveBindings(enabled and CHARACTER_BINDING_SET or ACCOUNT_BINDING_SET)
    else
        return false
    end
    ADDON.SetCharacterBonusBarSettingsEnabled(enabled)
    if ADDON.RefreshSettings then
        ADDON.RefreshSettings()
    end
    if ADDON.RefreshEditorBindings then
        ADDON.RefreshEditorBindings()
    end
    ADDON.ApplyRuntime()
    return true
end

function ADDON.SetCharacterSpecificSettingsEnabled(enabled)
    enabled = enabled and true or false
    local previousShowMinimapButton = ADDON.GetSyncedSetting("showMinimapButton")
    local previousTriggerOnKeyDown = ADDON.GetSyncedSetting("triggerOnKeyDown")

    if not ADDON.SetCharacterBindingSetEnabled(enabled) then
        return false
    end

    if enabled then
        local settings = ADDON.GetSettings()
        settings.showMinimapButton = previousShowMinimapButton and true or false
        settings.triggerOnKeyDown = previousTriggerOnKeyDown and true or false
    end

    if ADDON.UpdateRuntimeButtonClickRegistration then
        ADDON.UpdateRuntimeButtonClickRegistration()
    end
    if ADDON.RefreshSettings then
        ADDON.RefreshSettings()
    end
    return true
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
        setDraftLayout(getCurrentAppliedLayout())
    end
    return draftLayout
end

function ADDON.ResetDraftToApplied()
    setDraftLayout(getCurrentAppliedLayout())
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

local function normalizeMacroPlaceholderKey(key)
    if type(key) ~= "string" or not string.match(key, "^%$[A-Za-z0-9]+$") then
        return nil
    end
    return string.lower(key)
end

function ADDON.GetMacroPlaceholders()
    local placeholders = {}
    for canonicalKey, placeholder in pairs(ADDON.GetCurrentSpecDB().macroPlaceholders or {}) do
        if type(placeholder) == "table" then
            table.insert(placeholders, {
                canonicalKey = canonicalKey,
                key = placeholder.key or canonicalKey,
                text = placeholder.text or "",
            })
        end
    end
    table.sort(placeholders, function(a, b)
        return a.canonicalKey < b.canonicalKey
    end)
    return placeholders
end

function ADDON.SetMacroPlaceholder(key, text, previousKey)
    local canonicalKey = normalizeMacroPlaceholderKey(key)
    if not canonicalKey then
        return false, "key"
    end
    if type(text) ~= "string" or text == "" then
        return false, "text"
    end
    if string.match(text, "%$[A-Za-z0-9]+") then
        return false, "nested"
    end

    local spec = ADDON.GetCurrentSpecDB()
    local placeholders = spec.macroPlaceholders
    local previousCanonicalKey = normalizeMacroPlaceholderKey(previousKey)
    if placeholders[canonicalKey] and canonicalKey ~= previousCanonicalKey then
        return false, "duplicate"
    end

    if previousCanonicalKey and previousCanonicalKey ~= canonicalKey then
        placeholders[previousCanonicalKey] = nil
    end
    placeholders[canonicalKey] = {
        key = key,
        text = text,
    }

    ADDON.ApplyRuntime()
    if ADDON.RefreshSettings then
        ADDON.RefreshSettings()
    end
    return true
end

function ADDON.DeleteMacroPlaceholder(key)
    local canonicalKey = normalizeMacroPlaceholderKey(key)
    local placeholders = ADDON.GetCurrentSpecDB().macroPlaceholders
    if not canonicalKey or not placeholders[canonicalKey] then
        return false
    end
    placeholders[canonicalKey] = nil
    ADDON.ApplyRuntime()
    if ADDON.RefreshSettings then
        ADDON.RefreshSettings()
    end
    return true
end

function ADDON.ExpandMacroPlaceholders(macrotext)
    local placeholders = ADDON.GetCurrentSpecDB().macroPlaceholders or {}
    return string.gsub(macrotext or "", "%$([A-Za-z0-9]+)", function(name)
        local token = "$" .. name
        local placeholder = placeholders[string.lower(token)]
        if placeholder and type(placeholder.text) == "string" then
            return placeholder.text
        end
        return token
    end)
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
                useName = icon.useName and true or false,
            })
        elseif type(icon) == "string" and icon ~= "" then
            table.insert(normalized, {
                texture = icon,
                text = "",
                name = icon,
                useName = false,
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

local function getVariantForBindingKey(bindingKey)
    for _, key in ipairs(getLayoutKeyList()) do
        for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
            if variant.key == bindingKey then
                return key, variant.modifier or "normal", variant
            end
        end
    end
    return nil
end

local function normalizeBonusSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > BONUS_BAR_SLOT_COUNT then
        return nil
    end
    return math.floor(slot)
end

local function getDominosPossessBarId()
    if IsAddOnLoaded and not IsAddOnLoaded("Dominos") then
        return nil
    end
    if not Dominos or not Dominos.GetPossessBar then
        return nil
    end
    local ok, possessBar = pcall(Dominos.GetPossessBar, Dominos)
    if ok and possessBar and possessBar.id then
        return tonumber(possessBar.id)
    end
    return nil
end

local function getDominosButtonName(actionId)
    actionId = tonumber(actionId)
    if not actionId or actionId < 1 then
        return nil
    end
    if actionId <= 12 then
        return "ActionButton" .. tostring(actionId)
    elseif actionId <= 24 then
        return "BonusActionButton" .. tostring(actionId - 12)
    elseif actionId <= 36 then
        return "MultiBarRightButton" .. tostring(actionId - 24)
    elseif actionId <= 48 then
        return "MultiBarLeftButton" .. tostring(actionId - 36)
    elseif actionId <= 60 then
        return "MultiBarBottomRightButton" .. tostring(actionId - 48)
    elseif actionId <= 72 then
        return "MultiBarBottomLeftButton" .. tostring(actionId - 60)
    end
    return "DominosActionButton" .. tostring(actionId - 72)
end

function ADDON.GetBonusBarButtonName(slot)
    slot = normalizeBonusSlot(slot)
    if not slot then
        return nil
    end

    local possessBarId = getDominosPossessBarId()
    if possessBarId then
        local buttonName = getDominosButtonName((possessBarId - 1) * BONUS_BAR_SLOT_COUNT + slot)
        if buttonName and _G[buttonName] then
            return buttonName
        end
    end

    return "BonusActionButton" .. tostring(slot)
end

function ADDON.GetBonusBarSlotCount()
    return BONUS_BAR_SLOT_COUNT
end

function ADDON.GetBonusBarBindings(key)
    local spec = ADDON.GetBonusBarSpecDB()
    return spec.bonusBarBindings[key] or {}
end

function ADDON.GetBonusBarBindingAction(bindingKey)
    local key, modifier = getVariantForBindingKey(bindingKey)
    if not key then
        return nil
    end
    return ADDON.GetBonusBarBindings(key)[modifier]
end

function ADDON.SetBonusBarBindingAction(bindingKey, slot)
    local key, modifier = getVariantForBindingKey(bindingKey)
    if not key then
        return false
    end
    if slot and ADDON.GetDefaultBindingAction(bindingKey) ~= "" then
        return false
    end

    slot = normalizeBonusSlot(slot)
    local spec = ADDON.GetBonusBarSpecDB()
    spec.bonusBarBindings[key] = spec.bonusBarBindings[key] or {}
    if slot then
        spec.bonusBarBindings[key][modifier] = slot
    else
        spec.bonusBarBindings[key][modifier] = nil
    end
    if next(spec.bonusBarBindings[key]) == nil then
        spec.bonusBarBindings[key] = nil
    end

    ADDON.ApplyRuntime()
    if ADDON.RefreshOverlay then
        ADDON.RefreshOverlay()
    end
    if ADDON.RefreshBonusBar then
        ADDON.RefreshBonusBar()
    end
    return true
end

function ADDON.ClearBonusBarBindingAction(bindingKey)
    return ADDON.SetBonusBarBindingAction(bindingKey, nil)
end

function ADDON.FindDraftBindingForBonusBarAction(slot, excludedBindingKey)
    slot = normalizeBonusSlot(slot)
    if not slot then
        return nil
    end

    local spec = ADDON.GetBonusBarSpecDB()
    for _, key in ipairs(getLayoutKeyList()) do
        local keyBindings = spec.bonusBarBindings[key]
        if keyBindings then
            for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
                if variant.key ~= excludedBindingKey and keyBindings[variant.modifier or "normal"] == slot then
                    return {
                        key = key,
                        bindingKey = variant.key,
                        modifier = variant.modifier or "normal",
                        slot = slot,
                    }
                end
            end
        end
    end
    return nil
end

function ADDON.GetBonusBarBindingTextForSlot(slot)
    slot = normalizeBonusSlot(slot)
    if not slot then
        return ""
    end

    local prefixes = {
        normal = "",
        shift = "<s>",
        ctrl = "<c>",
        alt = "<a>",
    }
    local spec = ADDON.GetBonusBarSpecDB()
    for _, key in ipairs(getLayoutKeyList()) do
        local keyBindings = spec.bonusBarBindings[key]
        if keyBindings then
            for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
                local modifier = variant.modifier or "normal"
                if keyBindings[modifier] == slot then
                    return (prefixes[modifier] or "") .. key
                end
            end
        end
    end
    return ""
end

local function getButtonNameForKey(key)
    local name = string.upper(key or "")
    -- Frame names must be unique. Replacing every special character with "_"
    -- made keys such as ^, ß, ´, + and - all share the same secure button.
    -- Encode every non-ASCII byte instead so localized keys remain distinct.
    name = string.gsub(name, "[^A-Z0-9]", function(character)
        return string.format("_%02X", string.byte(character))
    end)
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
        { label = "Strg", key = "CTRL-" .. key, modifier = "ctrl" },
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

    if action == TOGGLE_BINDING_ACTION then
        return BINDING_NAME_DUDESFLEXBINDINGS_TOGGLE
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
    if filter == "" or string.find(string.lower(toggleName), filter, 1, true) or string.find(string.lower(TOGGLE_BINDING_ACTION), filter, 1, true) then
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
        if command and command ~= "" and not seen[command] and not string.find(command, "^HEADER_") then
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

function ADDON.ClearAllBindingsForKey(key)
    if not key then
        return false
    end
    local spec = ADDON.GetCurrentSpecDB()
    spec.bindings[key] = nil
    spec.defaultBindings[key] = nil
    ADDON.GetBonusBarSpecDB().bonusBarBindings[key] = nil
    ADDON.ApplyRuntime()
    if ADDON.RefreshOverlay then
        ADDON.RefreshOverlay()
    end
    if ADDON.RefreshBonusBar then
        ADDON.RefreshBonusBar()
    end
    return true
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

    ownerFrame = CreateFrame("Frame", "DudesFlexBindingsOwnerFrame", UIParent)
    ownerFrame:Hide()

    return ownerFrame
end

local function updateRuntimeButtonClickRegistration(button)
    if not button or not button.RegisterForClicks then
        return
    end
    if ADDON.GetSyncedSetting("triggerOnKeyDown") then
        button:RegisterForClicks("LeftButtonDown")
    else
        button:RegisterForClicks("LeftButtonUp")
    end
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
            printMessage("Makro auf Taste '" .. tostring(ADDON.executingMacroKey) .. "' hat einen Fehler verursacht. Bitte überprüfe das Makro.")
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
    updateRuntimeButtonClickRegistration(button)
    button:SetAttribute("type", "macro")
    button:SetAttribute("type1", "macro")
    button:SetScript("PreClick", function(self)
        ADDON.executingMacroKey = self.dkmKey
        if ADDON.IsBonusBarActive and ADDON.IsBonusBarActive() and ADDON.PlayBonusBarPress then
            local modifier = "normal"
            if IsShiftKeyDown and IsShiftKeyDown() then
                modifier = "shift"
            elseif IsControlKeyDown and IsControlKeyDown() then
                modifier = "ctrl"
            elseif IsAltKeyDown and IsAltKeyDown() then
                modifier = "alt"
            end
            local bonusSlot = self.dkmBonusBarBindings and self.dkmBonusBarBindings[modifier]
            if normalizeBonusSlot(bonusSlot) then
                ADDON.PlayBonusBarPress(bonusSlot)
            end
        end
    end)
    button:SetScript("PostClick", function()
        ADDON.executingMacroKey = nil
    end)
    button:Hide()
    runtimeButtons[key] = button
    return button
end

function ADDON.UpdateRuntimeButtonClickRegistration()
    if InCombatLockdown and InCombatLockdown() then
        ADDON.QueueRuntimeUpdate()
        printMessage("Runtime-Aktualisierung wird bis nach dem Kampf verschoben.")
        return false
    end

    for _, button in pairs(runtimeButtons) do
        updateRuntimeButtonClickRegistration(button)
    end
    ADDON.ApplyRuntime()
    return true
end

local function buildRuntimeMacro(bonusBindings, macrotext)
    macrotext = macrotext or ""
    bonusBindings = bonusBindings or {}
    if not next(bonusBindings) then
        return macrotext
    end

    local lines = {}
    local modifierConditions = {
        normal = "nomod",
        shift = "mod:shift",
        ctrl = "mod:ctrl",
        alt = "mod:alt",
    }
    local modifierOrder = { "ctrl", "shift", "alt", "normal" }
    for _, modifier in ipairs(modifierOrder) do
        local slot = normalizeBonusSlot(bonusBindings[modifier])
        if slot then
            local clickTarget = ADDON.GetBonusBarButtonName and ADDON.GetBonusBarButtonName(slot) or ("BonusActionButton" .. tostring(slot))
            local condition = modifierConditions[modifier] or "nomod"
            table.insert(lines, "/click [" .. condition .. ",vehicleui][" .. condition .. ",bonusbar:5] " .. clickTarget)
            table.insert(lines, "/stopmacro [" .. condition .. ",vehicleui][" .. condition .. ",bonusbar:5]")
        end
    end

    if macrotext ~= "" then
        table.insert(lines, macrotext)
    end
    return table.concat(lines, "\n")
end

local function setRuntimeVariantAttributes(button, binding, bonusBindings)
    local macrotext = binding and binding.macrotext or ""
    macrotext = ADDON.ExpandMacroPlaceholders(macrotext)
    button.dkmBonusBarBindings = bonusBindings or {}
    local runtimeMacro = buildRuntimeMacro(bonusBindings, macrotext)

    button:SetAttribute("type", "macro")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("macrotext", runtimeMacro)
    button:SetAttribute("macrotext1", runtimeMacro)
    for _, prefix in ipairs({ "shift-", "ctrl-", "alt-" }) do
        button:SetAttribute(prefix .. "type", nil)
        button:SetAttribute(prefix .. "type1", nil)
        button:SetAttribute(prefix .. "macrotext", nil)
        button:SetAttribute(prefix .. "macrotext1", nil)
    end
end

function ADDON.QueueRuntimeUpdate()
    pendingRuntimeUpdate = true
end

function ADDON.ApplyRuntime()
    ensureOwnerFrame()
    installMacroErrorHandler()

    if InCombatLockdown() then
        ADDON.QueueRuntimeUpdate()
        printMessage("Runtime-Aktualisierung wird bis nach dem Kampf verschoben.")
        return false
    end

    ClearOverrideBindings(ownerFrame)

    local spec = ADDON.GetCurrentSpecDB()
    local bonusSpec = ADDON.GetBonusBarSpecDB()
    local keysToBind = {}
    for key, binding in pairs(spec.bindings) do
        if binding and binding.macrotext and binding.macrotext ~= "" then
            keysToBind[key] = true
        end
    end
    for key in pairs(bonusSpec.bonusBarBindings or {}) do
        keysToBind[key] = true
    end

    for key in pairs(keysToBind) do
        local binding = spec.bindings[key]
        local bonusBindings = (bonusSpec.bonusBarBindings or {})[key] or {}
        local hasMacro = binding and binding.macrotext and binding.macrotext ~= ""
        local hasBonus
        for _, slot in pairs(bonusBindings) do
            if normalizeBonusSlot(slot) then
                hasBonus = true
                break
            end
        end

        if hasMacro or hasBonus then
            local button = ensureRuntimeButton(key)
            local ok = pcall(setRuntimeVariantAttributes, button, binding, bonusBindings)
            if ok then
                local buttonName = button:GetName()
                local keyDefaults = spec.defaultBindings[key] or {}

                if not keyDefaults.normal or keyDefaults.normal == "" then
                    local bindOk = pcall(SetOverrideBindingClick, ownerFrame, true, key, buttonName, "LeftButton")
                    ok = ok and bindOk
                end
            end
            if not ok then
                printMessage("Makro auf Taste '" .. tostring(key) .. "' hat einen Fehler verursacht. Bitte überprüfe das Makro.")
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
    action = action or ""

    local currentAction = GetBindingAction and (GetBindingAction(bindingKey) or "") or ""
    if currentAction == action then
        return false
    end

    if action and action ~= "" then
        SetBinding(bindingKey, action)
    else
        SetBinding(bindingKey)
    end
    return true
end

applyDefaultBindingActionNow = function(bindingKey, action)
    if InCombatLockdown() then
        printMessage("Interface binding update is blocked during combat.")
        pendingDefaultBindingUpdate = true
        return false
    end
    local changed
    if action and action ~= "" then
        changed = clearPermanentBindingsForAction(action, bindingKey)
    end
    changed = setPermanentBinding(bindingKey, action) or changed
    if changed and SaveBindings then
        SaveBindings(ADDON.GetActiveBindingSet())
    end
    return true
end

clearPermanentBindingsForAction = function(action, targetBindingKey)
    if not action or action == "" or not GetBindingKey then
        return false
    end

    local changed
    local bindingKey1, bindingKey2 = GetBindingKey(action)
    if bindingKey1 and bindingKey1 ~= targetBindingKey then
        SetBinding(bindingKey1)
        changed = true
    end
    if bindingKey2 and bindingKey2 ~= targetBindingKey then
        SetBinding(bindingKey2)
        changed = true
    end
    return changed
end

local function applyCurrentDefaultBindings(saveChanges)
    if InCombatLockdown() then
        pendingDefaultBindingUpdate = true
        return false
    end

    local changed
    local spec = ADDON.GetCurrentSpecDB()
    for _, key in ipairs(getLayoutKeyList()) do
        local keyDefaults = spec.defaultBindings[key] or {}
        for _, variant in ipairs(ADDON.GetDefaultBindingKeysForKey(key)) do
            local action = keyDefaults[variant.modifier or "normal"]
            if action and action ~= "" then
                changed = clearPermanentBindingsForAction(action, variant.key) or changed
            end
            if setPermanentBinding(variant.key, action) then
                changed = true
            end
        end
    end
    if changed and saveChanges and SaveBindings then
        SaveBindings(ADDON.GetActiveBindingSet())
    end
    pendingDefaultBindingUpdate = nil
    return true
end

function ADDON.EnsureCharacterBindingSet()
    if InCombatLockdown() then
        return false
    end
    return true
end

function ADDON.ApplyDraftLayout()
    if InCombatLockdown() then
        printMessage("Runtime-Aktualisierung wird bis nach dem Kampf verschoben.")
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
        bonusBarBindings = copyTable((layout or {}).bonusBarBindings),
        bonusBarSettings = copyTable((layout or {}).bonusBarSettings or DEFAULT_BONUS_BAR_SETTINGS),
        macroPlaceholders = copyTable((layout or {}).macroPlaceholders or {}),
    }
end

local function trimProfileName(name)
    name = string.gsub(name or "", "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    return name
end

local function isReservedProfileName(name)
    return name == "" or name == "system_empty" or name == "system_blizzard_defaults"
end

local function isLayoutProfileNameAvailable(name, excludedProfileId)
    name = trimProfileName(name)
    if isReservedProfileName(name) then
        return false
    end

    local lowerName = string.lower(name)
    for _, profile in ipairs(ADDON.GetLayoutProfiles()) do
        if profile.id ~= excludedProfileId and string.lower(profile.name or "") == lowerName then
            return false
        end
    end
    return true
end

local function serializeValue(value)
    local valueType = type(value)
    if valueType == "string" then
        return string.format("%q", value)
    elseif valueType == "number" or valueType == "boolean" then
        return tostring(value)
    elseif valueType ~= "table" then
        return "nil"
    end

    local keys = {}
    for key in pairs(value) do
        if type(key) == "string" or type(key) == "number" then
            table.insert(keys, key)
        end
    end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then
            return a < b
        end
        return type(a) < type(b)
    end)

    local parts = { "{" }
    for _, key in ipairs(keys) do
        table.insert(parts, "[" .. serializeValue(key) .. "]=" .. serializeValue(value[key]) .. ",")
    end
    table.insert(parts, "}")
    return table.concat(parts)
end

local function deserializeValue(text)
    text = text or ""
    if string.sub(text, 1, string.len(EXPORT_PREFIX)) == EXPORT_PREFIX then
        text = string.sub(text, string.len(EXPORT_PREFIX) + 1)
    end
    if text == "" then
        return nil
    end

    local chunk = loadstring and loadstring("return " .. text)
    if not chunk then
        return nil
    end
    if setfenv then
        setfenv(chunk, {})
    end
    local ok, value = pcall(chunk)
    if ok and type(value) == "table" then
        return value
    end
    return nil
end

local function sanitizeIconList(icons)
    local sanitized = {}
    for _, icon in ipairs(icons or {}) do
        if type(icon) == "table" and type(icon.texture) == "string" and icon.texture ~= "" then
            table.insert(sanitized, {
                texture = icon.texture,
                text = type(icon.text) == "string" and icon.text or "",
                name = type(icon.name) == "string" and icon.name or icon.texture,
                useName = icon.useName and true or false,
            })
        end
    end
    return sanitized
end

local function sanitizeBindings(bindings)
    local sanitized = {}
    for key, binding in pairs(bindings or {}) do
        if type(key) == "string" and type(binding) == "table" then
            local macrotext = type(binding.macrotext) == "string" and binding.macrotext or ""
            local icons = sanitizeIconList(binding.icons)
            if macrotext ~= "" or #icons > 0 then
                sanitized[key] = {
                    macrotext = macrotext,
                    icons = icons,
                }
            end
        end
    end
    return sanitized
end

local function sanitizeDefaultBindings(defaultBindings)
    local sanitized = {}
    for key, variants in pairs(defaultBindings or {}) do
        if type(key) == "string" and type(variants) == "table" then
            for modifier, action in pairs(variants) do
                if type(modifier) == "string" and type(action) == "string" and action ~= "" then
                    sanitized[key] = sanitized[key] or {}
                    sanitized[key][modifier] = action
                end
            end
        end
    end
    return sanitized
end

local function sanitizeBonusBarBindings(bonusBarBindings)
    local sanitized = {}
    for key, variants in pairs(bonusBarBindings or {}) do
        if type(key) == "string" and type(variants) == "table" then
            for modifier, slot in pairs(variants) do
                slot = normalizeBonusSlot(slot)
                if type(modifier) == "string" and slot then
                    sanitized[key] = sanitized[key] or {}
                    sanitized[key][modifier] = slot
                end
            end
        end
    end
    return sanitized
end

local function sanitizeBonusBarSettings(settings)
    if type(settings) ~= "table" then
        return copyTable(DEFAULT_BONUS_BAR_SETTINGS)
    end
    local sanitized = {}
    for key, defaultValue in pairs(DEFAULT_BONUS_BAR_SETTINGS) do
        local value = settings[key]
        if type(defaultValue) == "boolean" then
            sanitized[key] = value and true or false
        elseif type(defaultValue) == "number" then
            sanitized[key] = tonumber(value) or defaultValue
        elseif type(defaultValue) == "string" then
            sanitized[key] = type(value) == "string" and value or defaultValue
        elseif type(defaultValue) == "table" then
            sanitized[key] = type(value) == "table" and copyTable(value) or copyTable(defaultValue)
        end
    end
    return ensureBonusBarSettings(sanitized)
end

local function sanitizeMacroPlaceholders(placeholders)
    local sanitized = {}
    for storedKey, placeholder in pairs(type(placeholders) == "table" and placeholders or {}) do
        if type(placeholder) == "table" then
            local key = type(placeholder.key) == "string" and placeholder.key or storedKey
            local canonicalKey = normalizeMacroPlaceholderKey(key)
            local text = placeholder.text
            if canonicalKey and type(text) == "string" and text ~= "" and not string.match(text, "%$[A-Za-z0-9]+") and not sanitized[canonicalKey] then
                sanitized[canonicalKey] = {
                    key = key,
                    text = text,
                }
            end
        end
    end
    return sanitized
end

local function sanitizeImportedLayout(layout)
    if type(layout) ~= "table" then
        return nil
    end
    return {
        bindings = sanitizeBindings(layout.bindings),
        defaultBindings = sanitizeDefaultBindings(layout.defaultBindings),
        bonusBarBindings = sanitizeBonusBarBindings(layout.bonusBarBindings),
        bonusBarSettings = sanitizeBonusBarSettings(layout.bonusBarSettings),
        macroPlaceholders = sanitizeMacroPlaceholders(layout.macroPlaceholders),
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

    for name, profile in pairs(DudesFlexBindingsDB.savedLayouts or {}) do
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
    local bonusSpec = ADDON.GetBonusBarSpecDB()
    spec.bindings = copyTable(layout.bindings or {})
    spec.defaultBindings = copyTable(layout.defaultBindings or {})
    bonusSpec.bonusBarBindings = copyTable(layout.bonusBarBindings or {})
    copyBonusBarSettings(ADDON.GetBonusBarSettings(), layout.bonusBarSettings or DEFAULT_BONUS_BAR_SETTINGS)
    spec.macroPlaceholders = sanitizeMacroPlaceholders(layout.macroPlaceholders)

    applyCurrentDefaultBindings(true)

    ADDON.ApplyRuntime()
    if ADDON.RefreshBonusBar then
        ADDON.RefreshBonusBar()
    end
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
        bonusBarBindings = profile.bonusBarBindings or {},
        bonusBarSettings = profile.bonusBarSettings or DEFAULT_BONUS_BAR_SETTINGS,
        macroPlaceholders = profile.macroPlaceholders or {},
    }) then
        return false
    end
    printMessage("Loaded layout '" .. profile.name .. "'.")
    return true
end

function ADDON.SaveAppliedLayoutProfile(name)
    ADDON.InitDB()
    name = trimProfileName(name)
    if not isLayoutProfileNameAvailable(name) then
        return false
    end

    local layout = getCurrentAppliedLayout()
    DudesFlexBindingsDB.savedLayouts[name] = makeProfile(name, layout, name, false)
    printMessage("Saved layout '" .. name .. "'.")
    return true
end

function ADDON.OverwriteLayoutProfile(profileId)
    ADDON.InitDB()
    local profile = findLayoutProfile(profileId)
    if not profile or profile.system then
        return false
    end

    local name = profile.name or profileId
    DudesFlexBindingsDB.savedLayouts[profileId] = makeProfile(name, getCurrentAppliedLayout(), profileId, false)
    printMessage("Overwrote layout '" .. name .. "'.")
    return true
end

function ADDON.ExportLayoutProfile(profileId)
    local profile = findLayoutProfile(profileId)
    if not profile or profile.system then
        return nil
    end
    return EXPORT_PREFIX .. serializeValue({
        bindings = profile.bindings or {},
        defaultBindings = profile.defaultBindings or {},
        bonusBarBindings = profile.bonusBarBindings or {},
        bonusBarSettings = profile.bonusBarSettings or DEFAULT_BONUS_BAR_SETTINGS,
        macroPlaceholders = profile.macroPlaceholders or {},
    })
end

function ADDON.ImportLayoutProfile(name, importString)
    ADDON.InitDB()
    name = trimProfileName(name)
    if not isLayoutProfileNameAvailable(name) then
        return false, "name"
    end

    local layout = sanitizeImportedLayout(deserializeValue(importString))
    if not layout then
        return false, "import"
    end

    DudesFlexBindingsDB.savedLayouts[name] = makeProfile(name, layout, name, false)
    printMessage("Imported layout '" .. name .. "'.")
    return true
end

function ADDON.RenameLayoutProfile(profileId, newName)
    ADDON.InitDB()
    local profile = findLayoutProfile(profileId)
    if not profile or profile.system then
        return false
    end

    newName = trimProfileName(newName)
    if not isLayoutProfileNameAvailable(newName, profileId) then
        return false
    end

    local savedProfile = copyTable(profile)
    savedProfile.id = newName
    savedProfile.name = newName
    DudesFlexBindingsDB.savedLayouts[profileId] = nil
    DudesFlexBindingsDB.savedLayouts[newName] = savedProfile
    return true
end

function ADDON.DeleteLayoutProfile(profileId)
    ADDON.InitDB()
    local profile = findLayoutProfile(profileId)
    if not profile or profile.system then
        return false
    end
    DudesFlexBindingsDB.savedLayouts[profileId] = nil
    return true
end

function ADDON.CopyCurrentSpecToSharedProfile(profileName)
    if not profileName or profileName == "" then
        return
    end
    ADDON.InitDB()
    DudesFlexBindingsDB.sharedProfiles[profileName] = {
        bindings = copyTable(ADDON.GetCurrentSpecDB().bindings),
        bonusBarBindings = copyTable(ADDON.GetBonusBarSpecDB().bonusBarBindings),
    }
    return true
end

function ADDON.LoadSharedProfileToCurrentSpec(profileName)
    ADDON.InitDB()
    local profile = profileName and DudesFlexBindingsDB.sharedProfiles[profileName]
    if not profile then
        return false
    end
    ADDON.GetCurrentSpecDB().bindings = copyTable(profile.bindings or {})
    ADDON.GetBonusBarSpecDB().bonusBarBindings = copyTable(profile.bonusBarBindings or {})
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
        if ADDON.CreateMinimapButton then
            ADDON.CreateMinimapButton()
        end
        initialized = true
    end
    ADDON.ResetDraftToApplied()
    applyCurrentDefaultBindings(false)
    ADDON.ApplyRuntime()
    if ADDON.RefreshSettings then
        ADDON.RefreshSettings()
    end
    if ADDON.RefreshOverlay then
        ADDON.RefreshOverlay()
    end
end

local function refreshBonusBarRoute()
    ADDON.ApplyRuntime()
    if ADDON.QueueBonusBarRefresh then
        ADDON.QueueBonusBarRefresh()
    elseif ADDON.RefreshBonusBar then
        ADDON.RefreshBonusBar()
    end
end

local function hookDominosPossessBar()
    if dominosPossessBarHooked or not Dominos or not Dominos.SetPossessBar or not hooksecurefunc then
        return
    end

    local ok = pcall(hooksecurefunc, Dominos, "SetPossessBar", refreshBonusBarRoute)
    if ok then
        dominosPossessBarHooked = true
        if initialized then
            refreshBonusBarRoute()
        end
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

SLASH_DudesFlexBindings1 = "/dkm"
SLASH_DudesFlexBindings2 = "/DudesFlexBindings"
SlashCmdList["DudesFlexBindings"] = handleSlashCommand

DudesUtils.EventHandler.Add("PLAYER_ENTERING_WORLD", refreshForWorldState)
DudesUtils.EventHandler.Add("PLAYER_LOGIN", hookDominosPossessBar)
DudesUtils.EventHandler.Add("ADDON_LOADED", hookDominosPossessBar)
DudesUtils.EventHandler.Add("ACTIVE_TALENT_GROUP_CHANGED", refreshForWorldState)
DudesUtils.EventHandler.Add("UPDATE_BINDINGS", function()
    if ADDON.RefreshEditorBindings then
        ADDON.RefreshEditorBindings()
    end
    if ADDON.RefreshSettings then
        ADDON.RefreshSettings()
    end
    if ADDON.RefreshOverlay then
        ADDON.RefreshOverlay()
    end
end)
DudesUtils.EventHandler.Add("PLAYER_REGEN_ENABLED", function()
    if pendingDefaultBindingUpdate then
        applyCurrentDefaultBindings(true)
    end
    if pendingRuntimeUpdate then
        ADDON.ApplyRuntime()
    end
end)
