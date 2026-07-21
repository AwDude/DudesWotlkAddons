local ADDON = DudesLootTracker

local ROLL_TYPE_NEED = 1
local ROLL_TYPE_GREED = 2
local ROLL_TYPE_DISENCHANT = 3
local ROLL_TYPE_PASS = 0
local bindTooltip
local PRIMORDIAL_SARONITE_ITEM_ID = 49908
local pendingAutoConfirmRolls = {}
local ownedAutoConfirmRolls = {}
local pendingRollItems = {}
local registeredRollHook
local handleConfirmLootRoll
local ACTION_LABELS = {
    pass = "Passen",
    greed = "Gier",
    need = "Bedarf",
    disenchant = "Entzaubern",
}
local ROLL_ACTIONS = {
    [ROLL_TYPE_NEED] = "need",
    [ROLL_TYPE_GREED] = "greed",
    [ROLL_TYPE_DISENCHANT] = "disenchant",
}

local function isLevel80InstanceOrRaid()
    local name, instanceType, difficultyIndex, difficultyName, maxPlayers, playerDifficulty, isDynamic, mapID
    if GetInstanceInfo then
        name, instanceType, difficultyIndex, difficultyName, maxPlayers, playerDifficulty, isDynamic, mapID = GetInstanceInfo()
    end
    if instanceType ~= "party" and instanceType ~= "raid" then
        return false
    end
    if maxPlayers and maxPlayers >= 10 then
        return true
    end
    return UnitLevel and UnitLevel("player") == 80
end

local function isBossOrMiniBossItem(item)
    local _, segment = ADDON.FindItemById(item and item.id)
    return segment and (segment.type == "boss" or segment.type == "miniBoss")
end

local function isIcecrownCitadel()
    if not GetInstanceInfo then
        return false
    end
    local name, instanceType, difficultyIndex, difficultyName, maxPlayers, playerDifficulty, isDynamic, mapID = GetInstanceInfo()
    return mapID == 631 or name == "Eiskronenzitadelle" or name == "Icecrown Citadel"
end

local function disenchantAvailable(rollId)
    if not GetLootRollItemInfo then
        return false
    end
    local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant = GetLootRollItemInfo(rollId)
    return canDisenchant and true or false
end

local function greedAvailable(rollId)
    if not GetLootRollItemInfo then
        return true
    end
    local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant = GetLootRollItemInfo(rollId)
    return canGreed and true or false
end

local function isBindOnEquip(item)
    if not item or not item.link or not CreateFrame then
        return false
    end
    if not bindTooltip then
        bindTooltip = CreateFrame("GameTooltip", "DudesLootTrackerBindTooltip", UIParent, "GameTooltipTemplate")
        bindTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    bindTooltip:ClearLines()
    bindTooltip:SetHyperlink(item.link)
    local bindText = ITEM_BIND_ON_EQUIP or "Binds when equipped"
    for i = 1, 12 do
        local line = _G["DudesLootTrackerBindTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text and text == bindText then
            return true
        end
    end
    return false
end

local function performRollAction(rollId, item, action)
    if not RollOnLoot or not action or action == "manual" then
        return false
    end
    local rollType
    local performedAction = action
    if action == "pass" then
        rollType = ROLL_TYPE_PASS
    elseif action == "greed" then
        rollType = ROLL_TYPE_GREED
    elseif action == "need" then
        rollType = ROLL_TYPE_NEED
    elseif action == "disenchant" then
        if disenchantAvailable(rollId) then
            rollType = ROLL_TYPE_DISENCHANT
        elseif greedAvailable(rollId) then
            rollType = ROLL_TYPE_GREED
            performedAction = "greed"
        else
            return false
        end
    else
        return false
    end
    if performedAction ~= "pass" then
        pendingAutoConfirmRolls[rollId] = rollType
        ownedAutoConfirmRolls[rollId] = {
            rollType = rollType,
            expiresAt = (GetTime and GetTime() or 0) + 120,
        }
    end
    if performedAction ~= "pass" and ADDON.SetPendingLootDecision then
        ADDON.SetPendingLootDecision(item, performedAction)
    end
    RollOnLoot(rollId, rollType)
    ADDON.Print("Auto-" .. tostring(ACTION_LABELS[performedAction] or performedAction) .. " auf Loot: " .. (item.link or item.name or "Item"))
    return true
end

handleConfirmLootRoll = function(rollId, rollType)
    local expectedRollType = rollId and pendingAutoConfirmRolls[rollId]
    if not expectedRollType or expectedRollType ~= rollType or not ConfirmLootRoll then
        return
    end
    ConfirmLootRoll(rollId, rollType)
    pendingAutoConfirmRolls[rollId] = nil
end

function ADDON.OwnsLootRollConfirmation(rollId, rollType)
    local owned = rollId and ownedAutoConfirmRolls[rollId]
    if not owned or owned.rollType ~= rollType then
        return false
    end
    if GetTime and owned.expiresAt and owned.expiresAt < GetTime() then
        ownedAutoConfirmRolls[rollId] = nil
        return false
    end
    return true
end

local function getAutomationAction(item)
    local automation = ADDON.GetRollAutomation()
    local quality = tonumber(item.quality) or 1
    local bossLoot = isBossOrMiniBossItem(item)
    if isIcecrownCitadel() and tonumber(item.itemId) == PRIMORDIAL_SARONITE_ITEM_ID then
        return automation.primordialSaroniteAction
    end
    if bossLoot then
        return automation.bossAction
    end
    if quality == 2 then
        return automation.uncommonNormalAction
    end
    if quality == 3 then
        return automation.rareNormalAction
    end
    if quality == 4 and isBindOnEquip(item) then
        return automation.epicBoeNonBossAction
    end
    return "manual"
end

local function handleStartLootRoll(rollId)
    local link = GetLootRollItemLink and GetLootRollItemLink(rollId)
    local item = link and ADDON.TrackRollLootItem and ADDON.TrackRollLootItem(link)

    if rollId and item then
        pendingRollItems[rollId] = item
    end

    if not isLevel80InstanceOrRaid() or not item then
        return
    end

    performRollAction(rollId, item, getAutomationAction(item))
end

local function handleRollOnLoot(rollId, rollType)
    local action = ROLL_ACTIONS[rollType]
    local item = rollId and pendingRollItems[rollId]
    if item and action and ADDON.SetPendingLootDecision then
        ADDON.SetPendingLootDecision(item, action)
    end
end

function ADDON.InitializeAutoRoll()
    if hooksecurefunc and RollOnLoot and not registeredRollHook then
        hooksecurefunc("RollOnLoot", handleRollOnLoot)
        registeredRollHook = true
    end
    DudesUtils.EventHandler.Add("START_LOOT_ROLL", function(_, rollId)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                handleStartLootRoll(rollId)
            end)
        else
            handleStartLootRoll(rollId)
        end
    end)
    local function confirmAutomatedRoll(_, rollId, rollType)
        handleConfirmLootRoll(rollId, rollType)
    end
    DudesUtils.EventHandler.Add("CONFIRM_LOOT_ROLL", confirmAutomatedRoll)
    DudesUtils.EventHandler.Add("CONFIRM_DISENCHANT_ROLL", confirmAutomatedRoll)
    DudesUtils.EventHandler.Add("CANCEL_LOOT_ROLL", function(_, rollId)
        if rollId then
            pendingAutoConfirmRolls[rollId] = nil
            ownedAutoConfirmRolls[rollId] = nil
            pendingRollItems[rollId] = nil
        end
    end)
end
