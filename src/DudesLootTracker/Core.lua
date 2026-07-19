DudesLootTracker = DudesLootTracker or {}

local ADDON = DudesLootTracker
local DEFAULT_SETTINGS = {
    showMinimapButton = true,
    minimapAngle = 260,
    showAutomationDialogOnInstanceEnter = true,
    hideLootChatMessages = false,
    autoOpenOnBossLoot = true,
    autoOpenOnNormalLoot = false,
    persistOnlyBossSegments = false,
    maxLootEntries = 900,
    window = {
        width = 880,
        height = 560,
        point = "CENTER",
        relativePoint = "CENTER",
        xOfs = 0,
        yOfs = 0,
    },
    filters = {
        ownOnly = false,
        boeOnly = false,
        emblems = false,
        minItemLevel = nil,
        maxItemLevel = nil,
        minRequiredLevel = nil,
        maxRequiredLevel = nil,
        qualities = {
            legendary = true,
            epic = true,
            rare = true,
            uncommon = true,
            common = true,
            poor = true,
        },
        enemies = {
            boss = true,
            normal = true,
        },
        areas = {
            raid = true,
            instance = true,
            world = true,
        },
    },
}

local initialized
local toggleButton
local currentAutomationPromptInstanceKey

BINDING_HEADER_DUDESADDONS = "Dude's Addons"
BINDING_NAME_DUDESLOOTTRACKER_TOGGLE = "Dude's Loot Tracker: Fenster ein-/ausblenden"

local function copyTable(source)
    if type(source) ~= "table" then
        return source
    end
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = copyTable(value)
    end
    return copy
end

local function ensureTable(parent, key)
    if not parent[key] then
        parent[key] = {}
    end
    return parent[key]
end

local function mergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            mergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function getRealmName()
    return GetRealmName and (GetRealmName() or "UnknownRealm") or "UnknownRealm"
end

local function getCharacterName()
    return UnitName and (UnitName("player") or "UnknownCharacter") or "UnknownCharacter"
end

local function printMessage(text)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb88cffDudesLootTracker:|r " .. tostring(text))
    end
end

function ADDON.Print(text)
    printMessage(text)
end

function ADDON.CopyTable(source)
    return copyTable(source)
end

function ADDON.Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end
    return value
end

function ADDON.GetNow()
    return time and time() or 0
end

function ADDON.FormatTime(timestamp)
    if date then
        return date("%d.%m. %H:%M:%S", timestamp or ADDON.GetNow())
    end
    return tostring(timestamp or "")
end

function ADDON.GetPlayerName()
    return getCharacterName()
end

function ADDON.InitDB()
    DudesLootTrackerDB = DudesLootTrackerDB or {}
    DudesLootTrackerDB.profiles = DudesLootTrackerDB.profiles or {}

    local realm = ensureTable(DudesLootTrackerDB.profiles, getRealmName())
    local character = ensureTable(realm, getCharacterName())
    character.settings = character.settings or {}
    if DudesLootTrackerDB.globalSettings == nil then
        -- Preserve the settings of existing installations as the initial
        -- global profile when upgrading from character-only settings.
        DudesLootTrackerDB.globalSettings = copyTable(character.settings)
    end
    DudesLootTrackerDB.globalSettings = DudesLootTrackerDB.globalSettings or {}
    if character.useCharacterSettings == nil then
        character.useCharacterSettings = false
    end
    character.segments = character.segments or {}
    character.raidStates = character.raidStates or {}
    character.nextSegmentId = character.nextSegmentId or 1
    character.nextItemId = character.nextItemId or 1

    mergeDefaults(DudesLootTrackerDB.globalSettings, DEFAULT_SETTINGS)
    mergeDefaults(character.settings, DEFAULT_SETTINGS)
    return character
end

function ADDON.GetCharacterDB()
    return ADDON.InitDB()
end

function ADDON.GetSettings()
    local character = ADDON.GetCharacterDB()
    if character.useCharacterSettings then
        return character.settings
    end
    return DudesLootTrackerDB.globalSettings
end

function ADDON.UsesCharacterSpecificSettings()
    return ADDON.GetCharacterDB().useCharacterSettings and true or false
end

function ADDON.SetCharacterSpecificSettings(enabled)
    local character = ADDON.GetCharacterDB()
    enabled = enabled and true or false
    if character.useCharacterSettings == enabled then
        return false
    end
    character.settings = copyTable(DudesLootTrackerDB.globalSettings)
    mergeDefaults(character.settings, DEFAULT_SETTINGS)
    character.useCharacterSettings = enabled
    return true
end

function ADDON.GetFilters()
    local settings = ADDON.GetSettings()
    settings.filters = settings.filters or copyTable(DEFAULT_SETTINGS.filters)
    mergeDefaults(settings.filters, DEFAULT_SETTINGS.filters)
    return settings.filters
end

function ADDON.GetCurrentRaidKey()
    local name, instanceType, difficultyIndex, difficultyName, maxPlayers
    if GetInstanceInfo then
        name, instanceType, difficultyIndex, difficultyName, maxPlayers = GetInstanceInfo()
    end

    local raidId = nil
    if GetNumSavedInstances and GetSavedInstanceInfo then
        for i = 1, GetNumSavedInstances() do
            local savedName, id, reset, savedDifficulty, locked, extended, instanceIDMostSig, isRaid, savedMaxPlayers, savedDifficultyName = GetSavedInstanceInfo(i)
            if savedName == name and locked then
                raidId = id or instanceIDMostSig
                difficultyIndex = savedDifficulty or difficultyIndex
                difficultyName = savedDifficultyName or difficultyName
                maxPlayers = savedMaxPlayers or maxPlayers
                break
            end
        end
    end

    local key = table.concat({
        name or "World",
        tostring(maxPlayers or ""),
        tostring(difficultyIndex or ""),
        tostring(raidId or "unsaved"),
    }, ":")

    return key, {
        name = name or "World",
        instanceType = instanceType,
        difficultyIndex = difficultyIndex,
        difficultyName = difficultyName,
        size = maxPlayers,
        raidId = raidId,
    }
end

function ADDON.GetRaidState()
    local db = ADDON.GetCharacterDB()
    local raidKey = ADDON.GetCurrentRaidKey()
    db.raidStates[raidKey] = db.raidStates[raidKey] or {}
    db.raidStates[raidKey].automation = db.raidStates[raidKey].automation or {
        bossAction = "manual",
        primordialSaroniteAction = "manual",
        uncommonNormalAction = "manual",
        rareNormalAction = "manual",
        epicBoeNonBossAction = "manual",
    }
    return db.raidStates[raidKey], raidKey
end

function ADDON.GetRollAutomation()
    local state = ADDON.GetRaidState()
    state.automation = state.automation or {}
    state.automation.bossAction = state.automation.bossAction or "manual"
    state.automation.primordialSaroniteAction = state.automation.primordialSaroniteAction or "manual"
    state.automation.uncommonNormalAction = state.automation.uncommonNormalAction or "manual"
    state.automation.rareNormalAction = state.automation.rareNormalAction or "manual"
    state.automation.epicBoeNonBossAction = state.automation.epicBoeNonBossAction or "manual"
    return state.automation
end

function ADDON.SetRollAutomation(values)
    local automation = ADDON.GetRollAutomation()
    automation.bossAction = values and values.bossAction or "manual"
    automation.primordialSaroniteAction = values and values.primordialSaroniteAction or "manual"
    automation.uncommonNormalAction = values and values.uncommonNormalAction or "manual"
    automation.rareNormalAction = values and values.rareNormalAction or "manual"
    automation.epicBoeNonBossAction = values and values.epicBoeNonBossAction or "manual"
    if ADDON.RefreshMainWindow then
        ADDON.RefreshMainWindow()
    end
end

local function refreshAutomationPrompt()
    if not GetInstanceInfo then
        return
    end
    local _, instanceType = GetInstanceInfo()
    if instanceType ~= "party" and instanceType ~= "raid" then
        currentAutomationPromptInstanceKey = nil
        if ADDON.RefreshMainWindow then
            ADDON.RefreshMainWindow()
        end
        return
    end
    local instanceKey = ADDON.GetCurrentRaidKey()
    if currentAutomationPromptInstanceKey == instanceKey then
        return
    end
    currentAutomationPromptInstanceKey = instanceKey
    local state = ADDON.GetRaidState()
    if state.automationInitialized then
        if ADDON.RefreshMainWindow then
            ADDON.RefreshMainWindow()
        end
        return
    end
    state.automationInitialized = true
    ADDON.SetRollAutomation({})
    if ADDON.GetSettings().showAutomationDialogOnInstanceEnter and ADDON.ShowAutomationDialog then
        ADDON.ShowAutomationDialog()
    end
end

local function scheduleAutomationPrompt()
    if C_Timer and C_Timer.After then
        C_Timer.After(1, refreshAutomationPrompt)
    else
        refreshAutomationPrompt()
    end
end

local function ensureToggleButton()
    if toggleButton then
        return toggleButton
    end

    toggleButton = CreateFrame("Button", "DudesLootTrackerToggleButton", UIParent)
    toggleButton:SetScript("OnClick", function()
        ADDON.ToggleMainWindow()
    end)
    toggleButton:Hide()
    return toggleButton
end

function ADDON.ToggleMainWindow()
    if ADDON.ToggleWindow then
        ADDON.ToggleWindow()
    end
end

function ADDON.Initialize()
    if initialized then
        return
    end
    initialized = true
    ADDON.InitDB()
    ensureToggleButton()

    if ADDON.CreateSettingsPanel then
        ADDON.CreateSettingsPanel()
    end
    if ADDON.CreateMinimapButton then
        ADDON.CreateMinimapButton()
    end
    if ADDON.InitializeTracker then
        ADDON.InitializeTracker()
    end
    if ADDON.InitializeAutoRoll then
        ADDON.InitializeAutoRoll()
    end
    if ADDON.PruneHistory then
        ADDON.PruneHistory()
    end
    DudesUtils.EventHandler.Add("PLAYER_ENTERING_WORLD", scheduleAutomationPrompt)
    DudesUtils.EventHandler.Add("ZONE_CHANGED_NEW_AREA", scheduleAutomationPrompt)
    scheduleAutomationPrompt()
end

local function handleSlashCommand(message)
    message = string.lower(message or "")
    if message == "settings" or message == "optionen" then
        if ADDON.ToggleSettings then
            ADDON.ToggleSettings()
        end
    elseif message == "show" or message == "open" or message == "anzeigen" then
        if ADDON.ShowWindow then
            ADDON.ShowWindow()
        end
    else
        ADDON.ToggleMainWindow()
    end
end

SLASH_DudesLootTracker1 = "/dlt"
SLASH_DudesLootTracker2 = "/dudesloottracker"
SlashCmdList["DudesLootTracker"] = handleSlashCommand

DudesUtils.EventHandler.Add("PLAYER_LOGIN", function()
    ADDON.Initialize()
end)
