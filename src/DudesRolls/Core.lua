DudesRolls = DudesRolls or {}
DudesRollsDB = DudesRollsDB or {}
DudesRolls_ActiveRolls = DudesRolls_ActiveRolls or {}

local ADDON = DudesRolls
local DEFAULT_SETTINGS = {
    autoRollUncommon = false,
    autoRollRare = false,
    showGroupRollCounts = false,
    restoreOpenRolls = false,
    autoConfirmRollBind = false,
    autoConfirmLootBind = false,
    autoConfirmEnchantBind = false,
    autoConfirmReplaceEnchant = false,
    singleRollFrame = false,
    showOpenRollCount = false,
    rollFrameSpacing = 0,
}

local function mergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
    return target
end

local function migrateLegacySettings()
    if DudesRollsDB.legacySettingsMigrated then
        return
    end

    local settings = DudesRollsDB.settings
    local flexSettings
    if DudesFlexFrames and DudesFlexFrames.GetSettings then
        flexSettings = DudesFlexFrames.GetSettings()
    elseif type(DudesFlexFrames_Settings) == "table" then
        flexSettings = DudesFlexFrames_Settings
    end

    if flexSettings then
        local directMappings = {
            restoreOpenRolls = "restoreOpenRolls",
            singleRollFrame = "singleRollFrame",
            showOpenRollCount = "showOpenRollCount",
            rollFrameSpacing = "rollFrameSpacing",
        }
        for oldKey, newKey in pairs(directMappings) do
            if flexSettings[oldKey] ~= nil then
                settings[newKey] = flexSettings[oldKey]
            end
        end
        local legacyAutoConfirm = flexSettings.autoConfirmLootDialogs
        if legacyAutoConfirm == nil then
            legacyAutoConfirm = flexSettings.autoConfirmBindOnPickup
        end
        if legacyAutoConfirm ~= nil then
            local enabled = legacyAutoConfirm and true or false
            settings.autoConfirmRollBind = enabled
            settings.autoConfirmLootBind = enabled
            settings.autoConfirmEnchantBind = enabled
            settings.autoConfirmReplaceEnchant = enabled
        end
    end

    local lootTrackerSettings
    if DudesLootTracker and DudesLootTracker.GetSettings then
        lootTrackerSettings = DudesLootTracker.GetSettings()
    elseif type(DudesLootTrackerDB) == "table" then
        lootTrackerSettings = DudesLootTrackerDB.globalSettings
    end
    if lootTrackerSettings and lootTrackerSettings.autoGreedDisenchantUncommon ~= nil then
        settings.autoRollUncommon = lootTrackerSettings.autoGreedDisenchantUncommon and true or false
    end

    DudesRollsDB.legacySettingsMigrated = true
end

function ADDON.GetSettings()
    DudesRollsDB.settings = DudesRollsDB.settings or {}
    mergeDefaults(DudesRollsDB.settings, DEFAULT_SETTINGS)
    if IsLoggedIn and IsLoggedIn() and not DudesRollsDB.legacySettingsMigrated then
        migrateLegacySettings()
    end
    return DudesRollsDB.settings
end

function ADDON.Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.max(minimum, math.min(maximum, value))
end

ADDON.GetSettings()
DudesUtils.EventHandler.Add("PLAYER_LOGIN", migrateLegacySettings)

local function openSettings()
    if ADDON.OpenSettings then
        ADDON.OpenSettings()
    end
end

SLASH_DudesRolls1 = "/dr"
SLASH_DudesRolls2 = "/dudesrolls"
SlashCmdList["DudesRolls"] = openSettings
