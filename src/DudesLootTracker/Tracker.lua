local ADDON = DudesLootTracker

local lastBossKill
local currentLootSegment
local lastNormalLootTime
local pendingLootDecisions = {}
local pendingRollSelections = {}
local pendingRollItems = {}
local lastDisenchantLoot
local registeredLootChatFilter
local knownBossGuids = {}
local autoOpenedSegments = {}
local autoOpenedLootSources = {}
local formatPatternCache = {}
local LOOT_GROUP_SECONDS = 8
local PENDING_DECISION_SECONDS = 120
local BOSS_LOOT_SECONDS = 300
local DISENCHANT_MATERIAL_IDS = {
    [10938] = true, [10939] = true, [10940] = true, [10978] = true,
    [10998] = true, [11082] = true, [11083] = true, [11084] = true,
    [11134] = true, [11135] = true, [11137] = true, [11138] = true,
    [11139] = true, [11174] = true, [11175] = true, [11176] = true,
    [11177] = true, [11178] = true, [14343] = true, [14344] = true,
    [16202] = true, [16203] = true, [16204] = true, [20725] = true,
    [22445] = true, [22446] = true, [22447] = true, [22448] = true,
    [22449] = true, [22450] = true, [34052] = true, [34053] = true,
    [34054] = true, [34055] = true, [34056] = true, [34057] = true,
}

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

local function matchLocalizedFormat(message, formatText)
    local pattern = compileFormatPattern(formatText)
    if not pattern then
        return nil
    end
    local captures = { string.match(message or "", pattern) }
    if #captures == 0 then
        return nil
    end
    return captures
end

local function cleanRecipientName(name)
    if not name then
        return nil
    end
    name = string.match(name, "|h%[(.-)%]|h") or name
    name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
    name = string.gsub(name, "|r", "")
    return name
end

local function getRecipientKey(name)
    name = cleanRecipientName(name)
    name = name and string.match(name, "^([^%-]+)") or name
    return name and string.lower(name) or nil
end

local ROLL_SELECTION_FORMATS = {
    { method = "need", text = LOOT_ROLL_NEED },
    { method = "greed", text = LOOT_ROLL_GREED },
    { method = "disenchant", text = LOOT_ROLL_DISENCHANT },
}

local function recordRollSelection(message, links)
    local itemId = links and links[1] and ADDON.GetItemId(links[1])
    if not itemId then
        return false
    end
    for _, definition in ipairs(ROLL_SELECTION_FORMATS) do
        local captures = matchLocalizedFormat(message, definition.text)
        if captures then
            local recipient
            for _, value in ipairs(captures) do
                if not string.find(value, "|Hitem:", 1, true) and not string.match(value, "^%d+$") then
                    recipient = value
                end
            end
            recipient = recipient or (UnitName and UnitName("player"))
            local key = getRecipientKey(recipient)
            if key then
                pendingRollSelections[itemId] = pendingRollSelections[itemId] or {
                    recipients = {},
                    timestamp = ADDON.GetNow(),
                }
                pendingRollSelections[itemId].recipients[key] = definition.method
                pendingRollSelections[itemId].timestamp = ADDON.GetNow()
            end
            return true
        end
    end
    return false
end

local function getRollSelection(itemId, recipient)
    local pending = itemId and pendingRollSelections[itemId]
    if not pending then
        return nil
    end
    if ADDON.GetNow() - (pending.timestamp or 0) > PENDING_DECISION_SECONDS then
        pendingRollSelections[itemId] = nil
        return nil
    end
    local key = getRecipientKey(recipient)
    return key and pending.recipients[key] or nil
end

local function parseRollWinner(message)
    local captures = matchLocalizedFormat(message, LOOT_ROLL_YOU_WON)
    if captures then
        return UnitName and UnitName("player")
    end
    captures = matchLocalizedFormat(message, LOOT_ROLL_WON)
    if captures then
        for _, value in ipairs(captures) do
            if not string.find(value, "|Hitem:", 1, true) and not string.match(value, "^%d+$") then
                return cleanRecipientName(value)
            end
        end
    end
    return nil
end

local function isUnknownName(name)
    return not name
        or name == ""
        or name == "Unbekannt"
        or name == "Unknown"
        or (UNKNOWNOBJECT and name == UNKNOWNOBJECT)
end

local function shouldAutoOpen(segmentType)
    local settings = ADDON.GetSettings()
    if segmentType == "boss" or segmentType == "miniBoss" then
        return settings.autoOpenOnBossLoot
    end
    return settings.autoOpenOnNormalLoot
end

local function autoOpenSegment(segment)
    if not segment or autoOpenedSegments[segment.id] then
        return
    end
    autoOpenedSegments[segment.id] = true
    if shouldAutoOpen(segment.type) and ADDON.RequestShowWindow then
        ADDON.RequestShowWindow()
    end
end

local function autoOpenLootSource(segment, sourceGuid)
    if not segment then
        return
    end
    local sourceKey = sourceGuid or ("segment:" .. tostring(segment.id))
    if autoOpenedLootSources[sourceKey] then
        return
    end
    autoOpenedLootSources[sourceKey] = true
    autoOpenedSegments[segment.id] = true
    if shouldAutoOpen(segment.type) and ADDON.RequestShowWindow then
        ADDON.RequestShowWindow()
    end
end

local function getLootSourceName()
    if UnitName and UnitExists and UnitExists("target") and UnitIsDead("target") then
        local name = UnitName("target")
        if not isUnknownName(name) then
            return name
        end
        local guid = UnitGUID and UnitGUID("target")
        if guid and knownBossGuids[guid] then
            return knownBossGuids[guid]
        end
    end
    if lastBossKill and ADDON.GetNow() - (lastBossKill.timestamp or 0) < 300 then
        return lastBossKill.name
    end
    return nil
end

local function getLootSourceUnit()
    if UnitExists and UnitExists("target") and UnitIsDead and UnitIsDead("target") then
        return "target"
    end
    return nil
end

local function getLootSourceGuid()
    local unit = getLootSourceUnit()
    return unit and UnitGUID and UnitGUID(unit) or nil
end

local function rememberBossUnit(unit)
    if not UnitExists or not UnitExists(unit) or not UnitClassification or UnitClassification(unit) ~= "worldboss" then
        return
    end
    local guid = UnitGUID and UnitGUID(unit)
    local name = UnitName and UnitName(unit)
    if guid and not isUnknownName(name) then
        knownBossGuids[guid] = name
    end
end

local function scanBossUnits()
    rememberBossUnit("target")
    rememberBossUnit("focus")
    rememberBossUnit("mouseover")
    local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0
    for i = 1, raidCount do
        rememberBossUnit("raid" .. tostring(i) .. "target")
    end
    local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 0
    for i = 1, partyCount do
        rememberBossUnit("party" .. tostring(i) .. "target")
    end
end

local function handleBossKill(bossName)
    if isUnknownName(bossName) then
        return
    end
    lastBossKill = {
        name = bossName,
        timestamp = ADDON.GetNow(),
    }
    currentLootSegment = nil
end

local function isBossContext(segmentType)
    if segmentType == "boss" or segmentType == "miniBoss" then
        return true
    end
    if lastBossKill and ADDON.GetNow() - (lastBossKill.timestamp or 0) < 180 then
        return true
    end
    return false
end

local function createOrReuseSegment(segmentType, sourceName)
    local now = ADDON.GetNow()
    if segmentType == "normal" and currentLootSegment and currentLootSegment.type == "normal" and now - (lastNormalLootTime or 0) <= LOOT_GROUP_SECONDS then
        lastNormalLootTime = now
        return currentLootSegment, false
    end
    if segmentType ~= "normal"
        and currentLootSegment
        and currentLootSegment.type ~= "normal"
        and currentLootSegment.sourceName == sourceName
        and now - (currentLootSegment.timestamp or 0) <= BOSS_LOOT_SECONDS then
        return currentLootSegment, false
    end

    local segment = ADDON.CreateSegment(segmentType, sourceName)
    ADDON.AddSegment(segment)
    currentLootSegment = segment
    if segmentType == "normal" then
        lastNormalLootTime = now
    end
    return segment, true
end

local function resolveRecipientMethod(defaultMethod, rollInfo, item)
    if rollInfo and rollInfo.method then
        return rollInfo.method
    end
    if defaultMethod == "loot" and item and item.blizzardRollStarted and item.rollMethod then
        return item.rollMethod
    end
    return defaultMethod
end

local function addItemToSegment(segment, link, recipient, rollInfo, count)
    local itemId = ADDON.GetItemId(link)
    local recipientMethod = (rollInfo and rollInfo.method) or (segment and segment.lootMethod == "master" and "master") or "loot"
    if rollInfo and rollInfo.itemDbId and recipient and recipient ~= "" then
        local tracked = ADDON.FindItemById(rollInfo.itemDbId)
        if tracked then
            local method = resolveRecipientMethod(recipientMethod, rollInfo, tracked)
            tracked.count = math.max(tonumber(tracked.count or 1) or 1, tonumber(count or 1) or 1)
            tracked.recipients = tracked.recipients or {}
            table.insert(tracked.recipients, { name = recipient, method = method, timestamp = ADDON.GetNow() })
            return tracked
        end
    end
    for _, existing in ipairs(segment.items or {}) do
        if existing.itemId == itemId and ADDON.GetNow() - (existing.timestamp or 0) <= 3 then
            existing.count = math.max(tonumber(existing.count or 1) or 1, tonumber(count or 1) or 1)
            local hasRecipient = #(existing.recipients or {}) > 0
            local sameRecipient
            local sameRecipientEntry
            for _, existingRecipient in ipairs(existing.recipients or {}) do
                if recipient and existingRecipient.name == recipient then
                    sameRecipient = true
                    sameRecipientEntry = existingRecipient
                    break
                end
            end
            if recipient and recipient ~= "" and (not hasRecipient or sameRecipient) then
                local method = resolveRecipientMethod(recipientMethod, rollInfo, existing)
                existing.recipients = existing.recipients or {}
                if not sameRecipient then
                    table.insert(existing.recipients, { name = recipient, method = method, timestamp = ADDON.GetNow() })
                elseif sameRecipientEntry and method then
                    sameRecipientEntry.method = method
                end
                return existing
            elseif not recipient and hasRecipient then
                return existing
            end
        end
    end

    if recipient and recipient ~= "" then
        for i = #(segment.items or {}), 1, -1 do
            local existing = segment.items[i]
            if existing.itemId == itemId and #(existing.recipients or {}) == 0 then
                local method = resolveRecipientMethod(recipientMethod, rollInfo, existing)
                existing.count = math.max(tonumber(existing.count or 1) or 1, tonumber(count or 1) or 1)
                existing.recipients = existing.recipients or {}
                table.insert(existing.recipients, { name = recipient, method = method, timestamp = ADDON.GetNow() })
                return existing
            end
        end
    end

    local tracked
    if rollInfo and rollInfo.itemDbId then
        tracked = ADDON.FindItemById(rollInfo.itemDbId)
    else
        tracked = itemId and ADDON.FindRecipientCandidateByItemId(itemId)
    end
    if tracked and recipient and recipient ~= "" then
        local method = resolveRecipientMethod(recipientMethod, rollInfo, tracked)
        tracked.count = math.max(tonumber(tracked.count or 1) or 1, tonumber(count or 1) or 1)
        tracked.recipients = tracked.recipients or {}
        local found
        for _, trackedRecipient in ipairs(tracked.recipients) do
            if trackedRecipient.name == recipient then
                trackedRecipient.method = method or trackedRecipient.method or "loot"
                found = true
                break
            end
        end
        if not found then
            table.insert(tracked.recipients, { name = recipient, method = method, timestamp = ADDON.GetNow() })
        end
        return tracked
    end

    local item = ADDON.BuildItem(link, count)
    item.id = ADDON.AllocateItemId()
    item.timestamp = ADDON.GetNow()
    if rollInfo and rollInfo.method then
        item.rollMethod = rollInfo.method
    end
    if recipient and recipient ~= "" then
        table.insert(item.recipients, {
            name = recipient,
            method = resolveRecipientMethod(recipientMethod, rollInfo, item),
            timestamp = ADDON.GetNow(),
        })
    end
    table.insert(segment.items, item)
    return item
end

local function consumePendingLootDecision(itemId)
    local decision = itemId and pendingLootDecisions[itemId]
    if not decision then
        return nil
    end
    if ADDON.GetNow() - (decision.timestamp or 0) > PENDING_DECISION_SECONDS then
        pendingLootDecisions[itemId] = nil
        return nil
    end
    pendingLootDecisions[itemId] = nil
    return decision
end

local function rememberPendingRollItem(item)
    if not item or not item.itemId or not item.id then
        return
    end
    local items = pendingRollItems[item.itemId] or {}
    pendingRollItems[item.itemId] = items
    for _, itemDbId in ipairs(items) do
        if itemDbId == item.id then
            return
        end
    end
    table.insert(items, item.id)
end

local function consumePendingRollItem(itemId)
    local items = itemId and pendingRollItems[itemId]
    if not items then
        return nil
    end
    while #items > 0 do
        local itemDbId = table.remove(items, 1)
        local item = ADDON.FindItemById(itemDbId)
        if item
            and item.blizzardRollStarted
            and #(item.recipients or {}) == 0
            and ADDON.GetNow() - (item.timestamp or 0) <= PENDING_DECISION_SECONDS then
            if #items == 0 then
                pendingRollItems[itemId] = nil
            end
            return { itemDbId = itemDbId }
        end
    end
    pendingRollItems[itemId] = nil
    return nil
end

local function parseLootRecipient(message)
    if not message then
        return nil
    end

    local player = UnitName and UnitName("player")
    if player and string.find(message, "You receive loot", 1, true) then
        return player
    end
    if player and string.find(message, "Ihr erhaltet Beute", 1, true) then
        return player
    end

    local recipient = string.match(message, "^([^%s]+) receives loot")
    if recipient then
        return recipient
    end
    recipient = string.match(message, "^([^%s]+) erhält Beute")
    if recipient then
        return recipient
    end
    recipient = string.match(message, "^([^%s]+) bekommt")
    return recipient
end

local function isPlayerRecipient(recipient)
    local player = UnitName and UnitName("player")
    if not player or not recipient then
        return false
    end
    if recipient == player then
        return true
    end
    return string.match(recipient, "^([^%-]+)") == player
end

local function isSelfLootMessage(message)
    return message and (
        string.find(message, "You receive", 1, true)
        or string.find(message, "Ihr erhaltet", 1, true)
    )
end

local function getLootCount(message, link)
    local _, linkEnd = string.find(message or "", link or "", 1, true)
    if not linkEnd then
        return 1
    end
    local suffix = string.sub(message, linkEnd + 1)
    local count = string.match(suffix, "^%s*[xX]%s*(%d+)")
        or string.match(suffix, "[xX]%s*(%d+)")
    return math.max(1, tonumber(count) or 1)
end

local function isLootMessage(message)
    if not message then
        return false
    end
    if string.find(message, "loot", 1, true) or string.find(message, "Loot", 1, true) then
        return true
    end
    if string.find(message, "Beute", 1, true) then
        return true
    end
    return false
end

local function isSelfItemReceiveMessage(message)
    if not message then
        return false
    end
    if string.find(message, "You receive item", 1, true) then
        return true
    end
    if string.find(message, "You receive an item", 1, true) then
        return true
    end
    if string.find(message, "Ihr erhaltet Gegenstand", 1, true) then
        return true
    end
    if string.find(message, "Ihr erhaltet einen Gegenstand", 1, true) then
        return true
    end
    if string.find(message, "Ihr erhaltet den Gegenstand", 1, true) then
        return true
    end
    return false
end

local function isDisenchantMaterial(link)
    if not link then
        return false
    end
    local itemId = ADDON.GetItemId(link)
    if itemId and DISENCHANT_MATERIAL_IDS[itemId] then
        return true
    end
    if not GetItemInfo then
        return false
    end
    local name, itemLink, quality, itemLevel, requiredLevel, itemType, itemSubType = GetItemInfo(link)
    local subType = itemSubType and string.lower(itemSubType) or ""
    return subType == "enchanting" or subType == "verzauberkunst"
end

local function addDisenchantReward(source, link, count)
    source.disenchantRewards = source.disenchantRewards or {}
    local itemId = ADDON.GetItemId(link)
    for _, reward in ipairs(source.disenchantRewards) do
        if type(reward) == "table" and reward.itemId == itemId then
            reward.count = (tonumber(reward.count) or 1) + (tonumber(count) or 1)
            return
        end
    end
    table.insert(source.disenchantRewards, {
        itemId = itemId,
        link = link,
        count = tonumber(count) or 1,
    })
end

local function captureDisenchantRewards(message, links)
    if not lastDisenchantLoot or ADDON.GetNow() - (lastDisenchantLoot.timestamp or 0) > 10 then
        return false
    end
    local rewardRecipient = parseLootRecipient(message)
    if not rewardRecipient and (isSelfLootMessage(message) or isSelfItemReceiveMessage(message)) then
        rewardRecipient = UnitName and UnitName("player")
    end
    if not rewardRecipient
        or (lastDisenchantLoot.recipient and getRecipientKey(rewardRecipient) ~= getRecipientKey(lastDisenchantLoot.recipient)) then
        return false
    end
    local source = ADDON.FindItemById(lastDisenchantLoot.itemId)
    if not source then
        return false
    end
    local added
    for _, link in ipairs(links or {}) do
        if isDisenchantMaterial(link) then
            addDisenchantReward(source, link, getLootCount(message, link))
            added = true
        end
    end
    if added and ADDON.RequestRefreshMainWindow then
        ADDON.RequestRefreshMainWindow()
    end
    return added and true or false
end

local function updateExistingLootRecipientFromTrade(message, links)
    if not isSelfItemReceiveMessage(message) then
        return false
    end

    local player = UnitName and UnitName("player")
    local changed
    for _, link in ipairs(links or {}) do
        local itemId = ADDON.GetItemId(link)
        local item = itemId and (ADDON.FindRecipientCandidateByItemId(itemId) or ADDON.FindLatestItemByItemId(itemId))
        if item then
            item.recipients = item.recipients or {}
            for i = #item.recipients, 1, -1 do
                table.remove(item.recipients, i)
            end
            if player and player ~= "" then
                table.insert(item.recipients, { name = player, method = "trade", timestamp = ADDON.GetNow() })
            end
            changed = true
        end
    end
    if changed and ADDON.RequestRefreshMainWindow then
        ADDON.RequestRefreshMainWindow()
    end
    return changed
end

local function handleLootMessage(message, recipientHint)
    local links = ADDON.ExtractItemLinks(message)
    if #links == 0 then
        return
    end

    if recordRollSelection(message, links) then
        return
    end
    if captureDisenchantRewards(message, links) then
        return
    end

    local rollWinner = parseRollWinner(message)

    local containsEmblem
    for _, link in ipairs(links) do
        if ADDON.IsEmblem and ADDON.IsEmblem(link) then
            containsEmblem = true
            break
        end
    end

    if not isLootMessage(message) and not containsEmblem and not rollWinner then
        updateExistingLootRecipientFromTrade(message, links)
        return
    end

    local sourceName = getLootSourceName()
    local sourceUnit = getLootSourceUnit()
    local classified = ADDON.ClassifyLootSource(sourceName, "normal", sourceUnit)
    if lastBossKill and ADDON.GetNow() - (lastBossKill.timestamp or 0) < 180 then
        classified = ADDON.ClassifyLootSource(lastBossKill.name, "boss")
        sourceName = lastBossKill.name
    end

    local recipient = rollWinner or parseLootRecipient(message) or (recipientHint ~= "" and recipientHint or nil)
    if not recipient and isSelfLootMessage(message) then
        recipient = UnitName and UnitName("player")
    end
    if not recipient and containsEmblem and string.match(message or "", "^%s*%+") then
        recipient = UnitName and UnitName("player")
    end
    local segment
    for _, link in ipairs(links) do
        local isEmblem = ADDON.IsEmblem and ADDON.IsEmblem(link)
        if not isEmblem or isPlayerRecipient(recipient) then
            segment = segment or createOrReuseSegment(classified, sourceName)
            local itemId = ADDON.GetItemId(link)
            local rollInfo
            if rollWinner then
                rollInfo = consumePendingRollItem(itemId)
            end
            if isPlayerRecipient(recipient) then
                local pendingDecision = consumePendingLootDecision(itemId)
                if pendingDecision then
                    rollInfo = pendingDecision
                end
            end
            local selectedMethod = getRollSelection(itemId, recipient)
            if selectedMethod then
                rollInfo = rollInfo or {}
                rollInfo.method = selectedMethod
            end
            local item = addItemToSegment(segment, link, recipient, rollInfo, getLootCount(message, link))
            if item and rollInfo and rollInfo.method == "disenchant" then
                lastDisenchantLoot = {
                    itemId = item.id,
                    recipient = recipient,
                    timestamp = ADDON.GetNow(),
                }
            end
        end
    end

    if segment then
        autoOpenSegment(segment)
    end
    if segment and ADDON.RequestRefreshMainWindow then
        ADDON.RequestRefreshMainWindow()
    end
end

function ADDON.SetPendingLootDecision(item, method)
    if not item or not item.itemId or not method then
        return
    end
    item.rollMethod = method
    pendingLootDecisions[item.itemId] = {
        itemDbId = item.id,
        method = method,
        timestamp = ADDON.GetNow(),
    }
    local player = UnitName and UnitName("player")
    local playerKey = getRecipientKey(player)
    if playerKey then
        pendingRollSelections[item.itemId] = pendingRollSelections[item.itemId] or {
            recipients = {},
            timestamp = ADDON.GetNow(),
        }
        pendingRollSelections[item.itemId].recipients[playerKey] = method
        pendingRollSelections[item.itemId].timestamp = ADDON.GetNow()
    end
end

local function handleEncounterEnd(encounterName, success)
    if success == 1 or success == true then
        handleBossKill(encounterName)
    end
end

local function handleCombatLogEvent(_, timestamp, subEvent, sourceGUID, sourceName, sourceFlags, destGUID, destName)
    if subEvent ~= "UNIT_DIED" and subEvent ~= "UNIT_DESTROYED" then
        return
    end
    scanBossUnits()
    local bossName = destGUID and knownBossGuids[destGUID]
    if bossName then
        handleEncounterEnd(bossName, true)
        knownBossGuids[destGUID] = nil
    end
end

local function handleLootOpened()
    local sourceUnit = getLootSourceUnit()
    local sourceGuid = getLootSourceGuid()
    local sourceName = getLootSourceName()
    local segmentType = ADDON.ClassifyLootSource(sourceName, "normal", sourceUnit)
    if segmentType == "boss" and not isUnknownName(sourceName) then
        lastBossKill = {
            name = sourceName,
            timestamp = ADDON.GetNow(),
        }
    end
    if isBossContext(segmentType) and lastBossKill then
        segmentType = ADDON.ClassifyLootSource(lastBossKill.name, "boss")
        sourceName = lastBossKill.name
    end

    if GetNumLootItems and GetLootSlotLink then
        local segment
        for slot = 1, GetNumLootItems() do
            local link = GetLootSlotLink(slot)
            if link then
                segment = segment or createOrReuseSegment(segmentType, sourceName)
                if not (ADDON.IsEmblem and ADDON.IsEmblem(link)) then
                    local texture, itemName, quantity = GetLootSlotInfo and GetLootSlotInfo(slot)
                    addItemToSegment(segment, link, nil, nil, quantity)
                end
            end
        end
        if segment then
            autoOpenLootSource(segment, sourceGuid)
            if ADDON.RequestRefreshMainWindow then
                ADDON.RequestRefreshMainWindow()
            end
        end
    end
end

function ADDON.TrackRollLootItem(link)
    if not link then
        return nil
    end

    local itemId = ADDON.GetItemId(link)
    local item, segment = ADDON.FindRollCandidateByItemId(itemId)
    if item then
        item.blizzardRollStarted = true
        rememberPendingRollItem(item)
        if segment then
            autoOpenSegment(segment)
        end
        return item, segment
    end

    local segmentType = "normal"
    local sourceName = getLootSourceName()
    if lastBossKill and ADDON.GetNow() - (lastBossKill.timestamp or 0) < 180 then
        segmentType = ADDON.ClassifyLootSource(lastBossKill.name, "boss")
        sourceName = lastBossKill.name
    else
        segmentType = ADDON.ClassifyLootSource(sourceName, "normal", getLootSourceUnit())
    end
    segment = createOrReuseSegment(segmentType, sourceName)
    item = addItemToSegment(segment, link)
    if item then
        item.blizzardRollStarted = true
        rememberPendingRollItem(item)
        autoOpenSegment(segment)
    end
    return item, segment
end

function ADDON.InitializeTracker()
    if ChatFrame_AddMessageEventFilter and not registeredLootChatFilter then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", function()
            return ADDON.GetSettings().hideLootChatMessages and true or false
        end)
        registeredLootChatFilter = true
    end
    DudesUtils.EventHandler.Add("CHAT_MSG_LOOT", function(_, message, recipient)
        handleLootMessage(message, recipient)
    end)
    DudesUtils.EventHandler.Add("LOOT_OPENED", function()
        handleLootOpened()
    end)
    DudesUtils.EventHandler.Add("PLAYER_TARGET_CHANGED", scanBossUnits)
    DudesUtils.EventHandler.Add("UNIT_TARGET", scanBossUnits)
    DudesUtils.EventHandler.Add("UPDATE_MOUSEOVER_UNIT", scanBossUnits)
    DudesUtils.EventHandler.Add("COMBAT_LOG_EVENT_UNFILTERED", handleCombatLogEvent)
    scanBossUnits()
end
