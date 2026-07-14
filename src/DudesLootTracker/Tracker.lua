local ADDON = DudesLootTracker

local lastBossKill
local currentLootSegment
local lastNormalLootTime
local pendingLootDecisions = {}
local lastDisenchantLoot
local LOOT_GROUP_SECONDS = 8
local PENDING_DECISION_SECONDS = 120

local function shouldAutoOpen(segmentType, reason)
    local settings = ADDON.GetSettings()
    if segmentType == "boss" then
        return settings.autoOpenOnBossLoot
    elseif segmentType == "miniBoss" then
        return settings.autoOpenOnEliteLoot
    end
    return settings.autoOpenOnNormalLoot
end

local function autoOpen(segmentType, reason)
    if shouldAutoOpen(segmentType, reason) and ADDON.RequestShowWindow then
        ADDON.RequestShowWindow()
    end
end

local function getLootSourceName()
    if UnitName and UnitExists and UnitExists("target") and UnitIsDead("target") then
        return UnitName("target")
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
        return currentLootSegment
    end

    local segment = ADDON.CreateSegment(segmentType, sourceName)
    ADDON.AddSegment(segment)
    currentLootSegment = segment
    if segmentType == "normal" then
        lastNormalLootTime = now
    end
    return segment
end

local function addItemToSegment(segment, link, recipient, rollInfo, count)
    local itemId = ADDON.GetItemId(link)
    local recipientMethod = (rollInfo and rollInfo.method) or (segment and segment.lootMethod == "master" and "master") or "loot"
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
                existing.recipients = existing.recipients or {}
                if not sameRecipient then
                    table.insert(existing.recipients, { name = recipient, method = recipientMethod, timestamp = ADDON.GetNow() })
                elseif sameRecipientEntry and rollInfo and rollInfo.method then
                    sameRecipientEntry.method = recipientMethod
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
                existing.count = math.max(tonumber(existing.count or 1) or 1, tonumber(count or 1) or 1)
                existing.recipients = existing.recipients or {}
                table.insert(existing.recipients, { name = recipient, method = recipientMethod, timestamp = ADDON.GetNow() })
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
        tracked.count = math.max(tonumber(tracked.count or 1) or 1, tonumber(count or 1) or 1)
        tracked.recipients = tracked.recipients or {}
        local found
        for _, trackedRecipient in ipairs(tracked.recipients) do
            if trackedRecipient.name == recipient then
                trackedRecipient.method = recipientMethod or trackedRecipient.method or "loot"
                found = true
                break
            end
        end
        if not found then
            table.insert(tracked.recipients, { name = recipient, method = recipientMethod, timestamp = ADDON.GetNow() })
        end
        return tracked
    end

    local item = ADDON.BuildItem(link, count)
    item.id = ADDON.AllocateItemId()
    item.timestamp = ADDON.GetNow()
    if recipient and recipient ~= "" then
        table.insert(item.recipients, { name = recipient, method = recipientMethod, timestamp = ADDON.GetNow() })
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

local function updateExistingLootRecipientFromTrade(message, links)
    if not isSelfItemReceiveMessage(message) then
        return false
    end

    local player = UnitName and UnitName("player")
    if lastDisenchantLoot and ADDON.GetNow() - (lastDisenchantLoot.timestamp or 0) <= 20 then
        local source = ADDON.FindItemById(lastDisenchantLoot.itemId)
        if source then
            source.disenchantRewards = source.disenchantRewards or {}
            for _, link in ipairs(links or {}) do
                table.insert(source.disenchantRewards, link)
            end
            if ADDON.RequestRefreshMainWindow then
                ADDON.RequestRefreshMainWindow()
            end
            return true
        end
    end

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

local function handleLootMessage(message)
    local links = ADDON.ExtractItemLinks(message)
    if #links == 0 then
        return
    end

    if not isLootMessage(message) then
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

    local recipient = parseLootRecipient(message)
    local segment = createOrReuseSegment(classified, sourceName)
    for _, link in ipairs(links) do
        local itemId = ADDON.GetItemId(link)
        local rollInfo = consumePendingLootDecision(itemId)
        local item = addItemToSegment(segment, link, recipient, rollInfo)
        if item and rollInfo and rollInfo.method == "disenchant" then
            lastDisenchantLoot = {
                itemId = item.id,
                timestamp = ADDON.GetNow(),
            }
        end
    end

    autoOpen(classified, "loot")
    if ADDON.RequestRefreshMainWindow then
        ADDON.RequestRefreshMainWindow()
    end
end

function ADDON.SetPendingLootDecision(item, method)
    if not item or not item.itemId or not method then
        return
    end
    pendingLootDecisions[item.itemId] = {
        itemDbId = item.id,
        method = method,
        timestamp = ADDON.GetNow(),
    }
end

local function handleEncounterEnd(encounterName, success)
    if success == 1 or success == true then
        lastBossKill = {
            name = encounterName,
            timestamp = ADDON.GetNow(),
        }
        currentLootSegment = nil
    end
end

local function handleCombatLogEvent(...)
    local subEvent = select(2, ...)
    if subEvent ~= "UNIT_DIED" and subEvent ~= "PARTY_KILL" then
        return
    end

    local destName = select(7, ...)
    if not destName or ADDON.ClassifyLootSource(destName, "normal") == "normal" then
        destName = select(9, ...)
    end
    if destName and ADDON.ClassifyLootSource(destName, "normal") == "miniBoss" then
        handleEncounterEnd(destName, true)
    end
end

local function handleLootOpened()
    local sourceUnit = getLootSourceUnit()
    local sourceName = getLootSourceName()
    local segmentType = ADDON.ClassifyLootSource(sourceName, "normal", sourceUnit)
    if segmentType == "boss" then
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
                local texture, itemName, quantity = GetLootSlotInfo and GetLootSlotInfo(slot)
                addItemToSegment(segment, link, nil, nil, quantity)
            end
        end
        if segment then
            autoOpen(segmentType, "loot")
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
    end
    return item, segment
end

function ADDON.InitializeTracker()
    DudesUtils.EventHandler.Add("CHAT_MSG_LOOT", function(_, message)
        handleLootMessage(message)
    end)
    DudesUtils.EventHandler.Add("COMBAT_LOG_EVENT_UNFILTERED", function(_, ...)
        handleCombatLogEvent(...)
    end)
    DudesUtils.EventHandler.Add("LOOT_OPENED", function()
        handleLootOpened()
    end)
end
