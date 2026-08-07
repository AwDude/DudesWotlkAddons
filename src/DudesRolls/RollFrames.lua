local ADDON = DudesRolls

local ROLL_TYPE_NEED = 1
local ROLL_TYPE_GREED = 2
local ROLL_TYPE_DISENCHANT = 3
local GROUP_LOOT_FRAME_COUNT = 4
local GROUP_LOOT_DEFAULT_SPACING = -15
local GROUP_LOOT_PARENT_NAME = "DudesRolls_GroupLootParent"
local GROUP_LOOT_FRAME_NAMES = { "GroupLootFrame1", "GroupLootFrame2", "GroupLootFrame3", "GroupLootFrame4" }
local BUTTON_SUFFIXES = {
    need = { "NeedButton", "RollButton" },
    greed = { "GreedButton" },
    disenchant = { "DisenchantButton" },
    pass = { "PassButton" },
}

local pendingAutomaticConfirmations = {}
local formatPatternCache = {}
local messageDefinitions = {}
local groupLootParent
local registeredWithFlexFrames

-- WotLK only reports whether Disenchant is currently available to the group.
-- These equipment locations let us additionally recognize items which are
-- inherently disenchantable even when no enchanter is present.
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

local function addMessageDefinition(action, formatText)
    if formatText and formatText ~= "" then
        table.insert(messageDefinitions, { action = action, text = formatText })
    end
end

addMessageDefinition("need", LOOT_ROLL_NEED)
addMessageDefinition("greed", LOOT_ROLL_GREED)
addMessageDefinition("disenchant", LOOT_ROLL_DISENCHANT)
addMessageDefinition("pass", LOOT_ROLL_PASSED)
addMessageDefinition("pass", LOOT_ROLL_PASSED_AUTO)

local function compileFormatPattern(formatText)
    if not formatText or formatText == "" then
        return nil
    end
    if formatPatternCache[formatText] then
        return formatPatternCache[formatText]
    end

    local pattern = "^"
    local index = 1
    while index <= #formatText do
        local character = string.sub(formatText, index, index)
        if character == "%" then
            local nextIndex = index + 1
            local nextCharacter = string.sub(formatText, nextIndex, nextIndex)
            if nextCharacter == "%" then
                pattern = pattern .. "%%"
                index = index + 2
            else
                while string.match(string.sub(formatText, nextIndex, nextIndex), "%d") do
                    nextIndex = nextIndex + 1
                end
                if string.sub(formatText, nextIndex, nextIndex) == "$" then
                    nextIndex = nextIndex + 1
                end
                local valueType = string.sub(formatText, nextIndex, nextIndex)
                if valueType == "s" then
                    pattern = pattern .. "(.+)"
                    index = nextIndex + 1
                elseif valueType == "d" then
                    pattern = pattern .. "(%d+)"
                    index = nextIndex + 1
                else
                    pattern = pattern .. "%%"
                    index = index + 1
                end
            end
        else
            if string.find("^$()%.[]*+-?", character, 1, true) then
                pattern = pattern .. "%" .. character
            else
                pattern = pattern .. character
            end
            index = index + 1
        end
    end

    pattern = pattern .. "$"
    formatPatternCache[formatText] = pattern
    return pattern
end

local function getLocalizedCaptures(message, formatText)
    local pattern = compileFormatPattern(formatText)
    if not pattern then
        return nil
    end
    local captures = { string.match(message or "", pattern) }
    return #captures > 0 and captures or nil
end

local function getLinkKey(link)
    local itemString = link and string.match(link, "|H(item:[^|]+)|h")
    if not itemString then
        return link
    end
    -- Ignore the per-instance unique ID so two simultaneous drops of the
    -- same item share their counts. Keep the random suffix to avoid merging
    -- visibly different "... der ..." variants which use the same item ID.
    local itemId, suffixId = string.match(itemString, "^item:([^:]*):[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:([^:]*)")
    if itemId then
        return itemId .. ":" .. (suffixId or "")
    end
    return itemString
end

local function cleanPlayerName(name)
    if not name then
        return nil
    end
    name = string.match(name, "|h%[(.-)%]|h") or name
    name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
    name = string.gsub(name, "|r", "")
    name = string.match(name, "^([^%-]+)") or name
    return string.lower(name)
end

local function getGroupMemberKeys()
    local members = {}
    local playerKey = cleanPlayerName(UnitName and UnitName("player"))
    if playerKey then
        members[playerKey] = true
    end

    local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raidCount == 0 and IsInRaid and IsInRaid() and GetNumGroupMembers then
        raidCount = GetNumGroupMembers()
    end
    if raidCount > 0 and GetRaidRosterInfo then
        for index = 1, raidCount do
            local name = GetRaidRosterInfo(index)
            local key = cleanPlayerName(name)
            if key then
                members[key] = true
            end
        end
    else
        local partyCount = GetNumPartyMembers and GetNumPartyMembers()
            or GetNumSubgroupMembers and GetNumSubgroupMembers()
            or GetNumGroupMembers and math.max(0, GetNumGroupMembers() - 1)
            or 0
        for index = 1, partyCount do
            local key = cleanPlayerName(UnitName and UnitName("party" .. index))
            if key then
                members[key] = true
            end
        end
    end
    return members, playerKey
end

local function getRollId(frame)
    return frame and (frame.rollID or frame.rollId or frame.id)
end

local function getRollRemaining(rollId)
    local roll = rollId and DudesRolls_ActiveRolls[rollId]
    if roll and roll.expiresAt and GetTime then
        return roll.expiresAt - GetTime()
    end
    return roll and roll.duration or 0
end

local function pruneActiveRolls()
    local now = GetTime and GetTime() or 0
    for rollId, roll in pairs(DudesRolls_ActiveRolls) do
        if roll.expiresAt and roll.expiresAt <= now then
            DudesRolls_ActiveRolls[rollId] = nil
        end
    end
end

local function countActiveRolls()
    pruneActiveRolls()
    local count = 0
    for _ in pairs(DudesRolls_ActiveRolls) do
        count = count + 1
    end
    return count
end

local function countChoices(roll, action)
    local choices = roll and roll.choices and roll.choices[action]
    if type(choices) == "number" then
        return choices
    end
    local count = 0
    for _ in pairs(choices or {}) do
        count = count + 1
    end
    return count
end

local function ensureButtonCounts(frame)
    if frame.DudesRolls_ButtonCounts then
        return
    end
    frame.DudesRolls_ButtonCounts = {}
    local frameName = frame:GetName()
    for action, suffixes in pairs(BUTTON_SUFFIXES) do
        local button
        for _, suffix in ipairs(suffixes) do
            button = frameName and _G[frameName .. suffix]
            if button then
                break
            end
        end
        if button then
            local count = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
            count:SetTextColor(1, 1, 1)
            count:SetShadowColor(0, 0, 0, 1)
            count:SetShadowOffset(1, -1)
            count:Hide()
            frame.DudesRolls_ButtonCounts[action] = count
        end
    end
end

local function updateButtonCounts(frame)
    if not frame then
        return
    end
    ensureButtonCounts(frame)
    local roll = DudesRolls_ActiveRolls[getRollId(frame)]
    local show = ADDON.GetSettings().showGroupRollCounts and roll
    for action, countText in pairs(frame.DudesRolls_ButtonCounts or {}) do
        if show then
            countText:SetText(tostring(countChoices(roll, action)))
            countText:Show()
        else
            countText:Hide()
        end
    end
end

local function ensureOpenRollCount(frame)
    if frame.DudesRolls_OpenRollCount then
        return
    end
    frame.DudesRolls_OpenRollCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.DudesRolls_OpenRollCount:SetTextColor(1, 1, 1)
    frame.DudesRolls_OpenRollCount:Hide()
end

local function updateOpenRollCount(frame)
    if not frame then
        return
    end
    ensureOpenRollCount(frame)
    local settings = ADDON.GetSettings()
    local count = countActiveRolls()
    if settings.singleRollFrame and settings.showOpenRollCount and count > 0 then
        local frameName = frame:GetName()
        local rollButton = frameName and (_G[frameName .. "NeedButton"] or _G[frameName .. "RollButton"])
        frame.DudesRolls_OpenRollCount:ClearAllPoints()
        if rollButton then
            frame.DudesRolls_OpenRollCount:SetPoint("LEFT", rollButton, "RIGHT", 4, 0)
        else
            frame.DudesRolls_OpenRollCount:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -16)
        end
        frame.DudesRolls_OpenRollCount:SetText(count >= GROUP_LOOT_FRAME_COUNT and tostring(GROUP_LOOT_FRAME_COUNT) .. "+" or count)
        frame.DudesRolls_OpenRollCount:Show()
    else
        frame.DudesRolls_OpenRollCount:Hide()
    end
end

local function ensureBackground(frame)
    if not frame.DudesRolls_Background then
        frame.DudesRolls_Background = frame:CreateTexture(nil, "BACKGROUND")
        frame.DudesRolls_Background:SetTexture(0, 0, 0, 1)
    end
    frame.DudesRolls_Background:ClearAllPoints()
    frame.DudesRolls_Background:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    frame.DudesRolls_Background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
end

local function updateAllButtonCounts()
    for _, frameName in ipairs(GROUP_LOOT_FRAME_NAMES) do
        updateButtonCounts(_G[frameName])
    end
end

local function layoutGroupLootFrames()
    if not groupLootParent or not GroupLootFrame1 then
        return
    end

    local settings = ADDON.GetSettings()
    local spacing = GROUP_LOOT_DEFAULT_SPACING + (tonumber(settings.rollFrameSpacing) or 0)
    local width = GroupLootFrame1:GetWidth()
    local height = GroupLootFrame1:GetHeight()
    local parentHeight = settings.singleRollFrame and height or ((GROUP_LOOT_FRAME_COUNT * height) + ((GROUP_LOOT_FRAME_COUNT - 1) * spacing))
    local currentBottom = 0
    local shortestFrame
    local shortestRemaining

    groupLootParent:SetWidth(width)
    groupLootParent:SetHeight(parentHeight)

    for index, frameName in ipairs(GROUP_LOOT_FRAME_NAMES) do
        local frame = _G[frameName]
        if frame then
            ensureBackground(frame)
            ensureButtonCounts(frame)
            ensureOpenRollCount(frame)
            frame.DudesRolls_OpenRollCount:Hide()
            frame:ClearAllPoints()
            frame:SetParent(groupLootParent)
            frame:SetPoint("BOTTOMLEFT", groupLootParent, "BOTTOMLEFT", 0, settings.singleRollFrame and 0 or currentBottom)
            frame:SetFrameLevel(groupLootParent:GetFrameLevel() + index)
            currentBottom = currentBottom + height + spacing

            if settings.singleRollFrame and frame:IsShown() then
                local remaining = getRollRemaining(getRollId(frame))
                if not shortestRemaining or remaining < shortestRemaining then
                    shortestRemaining = remaining
                    shortestFrame = frame
                end
            end
            updateButtonCounts(frame)
        end
    end

    if shortestFrame then
        shortestFrame:SetFrameLevel(groupLootParent:GetFrameLevel() + GROUP_LOOT_FRAME_COUNT + 1)
    end
    updateOpenRollCount(shortestFrame)
end

local function queueLayout()
    if DudesUtils.OnNextUpdate then
        DudesUtils.OnNextUpdate(layoutGroupLootFrames)
    else
        layoutGroupLootFrames()
    end
end

local function registerWithFlexFrames()
    if registeredWithFlexFrames or not groupLootParent or not DudesFlexFrames or not DudesFlexFrames.RegisterFrame then
        return
    end
    DudesFlexFrames.RegisterFrame(GROUP_LOOT_PARENT_NAME, GROUP_LOOT_FRAME_NAMES, {
        directInteraction = false,
        managePanel = false,
    })
    registeredWithFlexFrames = true
end

local function createGroupLootParent()
    if groupLootParent or not GroupLootFrame1 or (InCombatLockdown and InCombatLockdown()) then
        return
    end

    local left = GroupLootFrame1:GetLeft() or 0
    local bottom = GroupLootFrame1:GetBottom() or 0
    groupLootParent = CreateFrame("Frame", GROUP_LOOT_PARENT_NAME, UIParent)
    groupLootParent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    groupLootParent:SetFrameStrata("DIALOG")
    groupLootParent:EnableMouse(false)
    groupLootParent:Show()
    layoutGroupLootFrames()
    registerWithFlexFrames()
end

function ADDON.RefreshGroupLootFrames()
    layoutGroupLootFrames()
end

local function trackActiveRoll(rollId, rollTime)
    if not rollId then
        return
    end
    local now = GetTime and GetTime() or 0
    local duration = tonumber(rollTime) or 60
    local link = GetLootRollItemLink and GetLootRollItemLink(rollId)
    DudesRolls_ActiveRolls[rollId] = {
        startedAt = now,
        duration = duration,
        expiresAt = now + duration,
        link = link,
        linkKey = getLinkKey(link),
        choices = {},
    }
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

local function performAutomaticRoll(rollId)
    if not RollOnLoot or not GetLootRollItemInfo then
        return false
    end
    local _, _, _, quality, _, _, canGreed, canDisenchant = GetLootRollItemInfo(rollId)
    local settings = ADDON.GetSettings()
    if (quality ~= 2 or not settings.autoRollUncommon) and (quality ~= 3 or not settings.autoRollRare) then
        return false
    end
    if not isDisenchantableItem(rollId, canDisenchant) then
        return false
    end

    local rollType
    if canDisenchant then
        rollType = ROLL_TYPE_DISENCHANT
    elseif canGreed then
        rollType = ROLL_TYPE_GREED
    else
        return false
    end

    pendingAutomaticConfirmations[rollId] = rollType
    RollOnLoot(rollId, rollType)
    return true
end

local function onStartLootRoll(_, rollId, rollTime)
    trackActiveRoll(rollId, rollTime)
    queueLayout()
    local function finishStart()
        local roll = DudesRolls_ActiveRolls[rollId]
        if roll and not roll.link then
            roll.link = GetLootRollItemLink and GetLootRollItemLink(rollId)
            roll.linkKey = getLinkKey(roll.link)
        end
        performAutomaticRoll(rollId)
    end
    if DudesUtils.OnNextUpdate then
        DudesUtils.OnNextUpdate(finishStart)
    else
        finishStart()
    end
end

local function onCancelLootRoll(_, rollId)
    if rollId then
        DudesRolls_ActiveRolls[rollId] = nil
        pendingAutomaticConfirmations[rollId] = nil
    end
    queueLayout()
end

local function onConfirmLootRoll(_, rollId, rollType)
    if not ConfirmLootRoll or not rollId or not rollType then
        return
    end
    local automaticType = pendingAutomaticConfirmations[rollId]
    if automaticType == rollType then
        pendingAutomaticConfirmations[rollId] = nil
        ConfirmLootRoll(rollId, rollType)
    elseif ADDON.GetSettings().autoConfirmRollBind then
        ConfirmLootRoll(rollId, rollType)
    end
end

local function onLootBindConfirm(_, lootSlot)
    if ADDON.GetSettings().autoConfirmLootBind and ConfirmLootSlot and lootSlot then
        ConfirmLootSlot(lootSlot)
    end
end

local function onBindEnchant()
    if ADDON.GetSettings().autoConfirmEnchantBind and BindEnchant then
        BindEnchant()
    end
end

local function onReplaceEnchant()
    if ADDON.GetSettings().autoConfirmReplaceEnchant and ReplaceEnchant then
        ReplaceEnchant()
    end
end

local function onReplaceTradeEnchant()
    if ADDON.GetSettings().autoConfirmReplaceEnchant and ReplaceTradeEnchant then
        ReplaceTradeEnchant()
    end
end

local function handleRollChatMessage(message)
    if not ADDON.GetSettings().showGroupRollCounts then
        return
    end
    for _, definition in ipairs(messageDefinitions) do
        local captures = getLocalizedCaptures(message, definition.text)
        if captures then
            local playerName
            local link
            for _, value in ipairs(captures) do
                if string.find(value, "|Hitem:", 1, true) then
                    link = value
                elseif not string.match(value, "^%d+$") then
                    playerName = value
                end
            end

            local playerKey = cleanPlayerName(playerName)
            local groupMembers, ownKey = getGroupMemberKeys()
            if playerKey and playerKey ~= ownKey and groupMembers[playerKey] then
                local linkKey = getLinkKey(link)
                for _, roll in pairs(DudesRolls_ActiveRolls) do
                    if linkKey and roll.linkKey == linkKey then
                        roll.choices = roll.choices or {}
                        roll.choices[definition.action] = (tonumber(roll.choices[definition.action]) or 0) + 1
                    end
                end
                updateAllButtonCounts()
            end
            return
        end
    end
end

local function restoreOpenRolls()
    if not ADDON.GetSettings().restoreOpenRolls or not GroupLootFrame_OpenNewFrame then
        return
    end
    pruneActiveRolls()
    for rollId, roll in pairs(DudesRolls_ActiveRolls) do
        if GetLootRollItemInfo and GetLootRollItemInfo(rollId) then
            local remaining = roll.expiresAt and GetTime and math.max(1, roll.expiresAt - GetTime()) or roll.duration or 60
            GroupLootFrame_OpenNewFrame(rollId, remaining)
        end
    end
    layoutGroupLootFrames()
end

DudesUtils.EventHandler.Add("PLAYER_LOGIN", function()
    createGroupLootParent()
    registerWithFlexFrames()
end)
DudesUtils.EventHandler.Add("PLAYER_REGEN_ENABLED", function()
    createGroupLootParent()
    registerWithFlexFrames()
end)
DudesUtils.EventHandler.Add("ADDON_LOADED", function(_, addonName)
    if addonName == "DudesFlexFrames" then
        registerWithFlexFrames()
    end
end)
DudesUtils.EventHandler.Add("START_LOOT_ROLL", onStartLootRoll)
DudesUtils.EventHandler.Add("CANCEL_LOOT_ROLL", onCancelLootRoll)
DudesUtils.EventHandler.Add("CONFIRM_LOOT_ROLL", onConfirmLootRoll)
DudesUtils.EventHandler.Add("CONFIRM_DISENCHANT_ROLL", onConfirmLootRoll)
DudesUtils.EventHandler.Add("LOOT_BIND_CONFIRM", onLootBindConfirm)
DudesUtils.EventHandler.Add("BIND_ENCHANT", onBindEnchant)
DudesUtils.EventHandler.Add("REPLACE_ENCHANT", onReplaceEnchant)
DudesUtils.EventHandler.Add("TRADE_REPLACE_ENCHANT", onReplaceTradeEnchant)
DudesUtils.EventHandler.Add("CHAT_MSG_LOOT", function(_, message)
    handleRollChatMessage(message)
end)
DudesUtils.EventHandler.Add("PLAYER_ENTERING_WORLD", function()
    if DudesUtils.OnNextUpdate then
        DudesUtils.OnNextUpdate(restoreOpenRolls)
    else
        restoreOpenRolls()
    end
end)
