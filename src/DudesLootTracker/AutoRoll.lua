local ADDON = DudesLootTracker

local ROLL_TYPE_NEED = 1
local ROLL_TYPE_GREED = 2
local ROLL_TYPE_DISENCHANT = 3
local pendingAutoConfirmRolls = {}
local ownedAutoConfirmRolls = {}
local pendingRollItems = {}
local registeredRollHook

-- WotLK exposes whether the group may currently roll Disenchant, but not a
-- general "disenchantable" item flag. Equippable armor and weapons use these
-- inventory locations. Shirts, tabards and bags are intentionally absent.
local DISENCHANTABLE_EQUIP_LOCS = {
    INVTYPE_HEAD = true,
    INVTYPE_NECK = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_WAIST = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_WRIST = true,
    INVTYPE_HAND = true,
    INVTYPE_FINGER = true,
    INVTYPE_TRINKET = true,
    INVTYPE_CLOAK = true,
    INVTYPE_WEAPON = true,
    INVTYPE_SHIELD = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_HOLDABLE = true,
    INVTYPE_RANGED = true,
    INVTYPE_THROWN = true,
    INVTYPE_RANGEDRIGHT = true,
    INVTYPE_RELIC = true,
}

local function getRollInfo(rollId)
    if not GetLootRollItemInfo then
        return nil
    end
    local _, _, _, quality, _, _, canGreed, canDisenchant = GetLootRollItemInfo(rollId)
    return tonumber(quality), canGreed and true or false, canDisenchant and true or false
end

local function isDisenchantableItem(rollId, canDisenchant)
    if canDisenchant then
        return true
    end
    local link = GetLootRollItemLink and GetLootRollItemLink(rollId)
    if not link or not GetItemInfo then
        return false
    end
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
    return equipLoc and DISENCHANTABLE_EQUIP_LOCS[equipLoc] and true or false
end

local function performAutomaticRoll(rollId, item)
    if not RollOnLoot or not ADDON.GetSettings().autoGreedDisenchantUncommon then
        return false
    end
    local quality, canGreed, canDisenchant = getRollInfo(rollId)
    if quality ~= 2 or not isDisenchantableItem(rollId, canDisenchant) then
        return false
    end

    local rollType
    local action
    if canDisenchant then
        rollType = ROLL_TYPE_DISENCHANT
        action = "disenchant"
    elseif canGreed then
        rollType = ROLL_TYPE_GREED
        action = "greed"
    else
        return false
    end

    pendingAutoConfirmRolls[rollId] = rollType
    ownedAutoConfirmRolls[rollId] = {
        rollType = rollType,
        expiresAt = (GetTime and GetTime() or 0) + 120,
    }
    if item and ADDON.SetPendingLootDecision then
        ADDON.SetPendingLootDecision(item, action)
    end
    RollOnLoot(rollId, rollType)
    return true
end

local function handleConfirmLootRoll(rollId, rollType)
    local expectedRollType = rollId and pendingAutoConfirmRolls[rollId]
    if expectedRollType and expectedRollType == rollType and ConfirmLootRoll then
        ConfirmLootRoll(rollId, rollType)
        pendingAutoConfirmRolls[rollId] = nil
    end
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

local function handleStartLootRoll(rollId)
    local link = GetLootRollItemLink and GetLootRollItemLink(rollId)
    local item = link and ADDON.TrackRollLootItem and ADDON.TrackRollLootItem(link)
    if rollId and item then
        pendingRollItems[rollId] = item
    end
    performAutomaticRoll(rollId, item)
end

local function handleRollOnLoot(rollId, rollType)
    local item = rollId and pendingRollItems[rollId]
    local action = rollType == ROLL_TYPE_DISENCHANT and "disenchant"
        or rollType == ROLL_TYPE_GREED and "greed"
        or rollType == ROLL_TYPE_NEED and "need"
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
