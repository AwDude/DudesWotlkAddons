local ADDON = DudesLootTracker

local activeRollsById = {}
local activeRollCountsByItemId = {}
local activeRollSegmentsByItemId = {}
local rollItemsByItemId = {}
local registeredLootChatFilter
local registeredRollHook
local formatPatternCache = {}

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
        if character ~= "%" then
            if string.find("^$()%.[]*+-?", character, 1, true) then
                pattern = pattern .. "%" .. character
            else
                pattern = pattern .. character
            end
            index = index + 1
        else
            local nextIndex = index + 1
            if string.sub(formatText, nextIndex, nextIndex) == "%" then
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

local function cleanPlayerName(name)
    if not name then
        return nil
    end
    name = string.match(name, "|h%[(.-)%]|h") or name
    name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
    name = string.gsub(name, "|r", "")
    return name ~= "" and name or nil
end

local function getPlayerKey(name)
    name = cleanPlayerName(name)
    name = name and string.match(name, "^([^%-]+)") or nil
    return name and string.lower(name) or nil
end

local function getCaptureValues(captures)
    local playerName
    local number
    for _, value in ipairs(captures or {}) do
        if string.match(value, "^%d+$") then
            number = tonumber(value)
        elseif not string.find(value, "|Hitem:", 1, true) then
            playerName = cleanPlayerName(value)
        end
    end
    return playerName, number
end

local function refreshWindow()
    if ADDON.RequestRefreshMainWindow then
        ADDON.RequestRefreshMainWindow()
    end
end

local function createStorageBatch(kind)
    local segment = ADDON.CreateSegment(kind)
    ADDON.AddSegment(segment)
    return segment
end

local function findItemInSegment(segment, itemId)
    for _, item in ipairs(segment and segment.items or {}) do
        if item.itemId == itemId then
            return item
        end
    end
    return nil
end

local function addRecipient(item, name, method, count, mergeRecipient)
    name = cleanPlayerName(name)
    if not item or not name then
        return nil
    end

    item.recipients = item.recipients or {}
    count = math.max(1, tonumber(count) or 1)
    if mergeRecipient then
        local key = getPlayerKey(name)
        for _, recipient in ipairs(item.recipients) do
            if getPlayerKey(recipient.name) == key then
                recipient.count = (tonumber(recipient.count) or 0) + count
                recipient.timestamp = ADDON.GetNow()
                recipient.method = method or recipient.method
                return recipient
            end
        end
    end

    local recipient = {
        name = name,
        method = method,
        count = count,
        timestamp = ADDON.GetNow(),
    }
    table.insert(item.recipients, recipient)
    return recipient
end

local function findRecipient(item, name, predicate)
    local key = getPlayerKey(name)
    if not item or not key then
        return nil
    end
    for _, recipient in ipairs(item.recipients or {}) do
        if getPlayerKey(recipient.name) == key and (not predicate or predicate(recipient)) then
            return recipient
        end
    end
    return nil
end

local function findPlayerRoll(item, playerName, predicate)
    local key = getPlayerKey(playerName)
    if not item or not key then
        return nil
    end
    for _, roll in ipairs(item.rolls or {}) do
        if getPlayerKey(roll.name) == key and (not predicate or predicate(roll)) then
            return roll
        end
    end
    return nil
end

local function addOrUpdateRollWinner(item, name, method)
    local recipient = findRecipient(item, name, function(entry)
        return not entry.winnerRecorded
    end)
    if not recipient then
        recipient = addRecipient(item, name, method, 1, false)
    end
    if recipient then
        recipient.method = method or recipient.method
        recipient.timestamp = ADDON.GetNow()
        recipient.winnerRecorded = true
    end
    return recipient
end

local function trackRollItem(item)
    if not item or not item.itemId then
        return
    end
    local items = rollItemsByItemId[item.itemId]
    if not items then
        items = {}
        rollItemsByItemId[item.itemId] = items
    end
    table.insert(items, item)
end

local function untrackRollItem(item)
    local itemId = item and item.itemId
    local items = itemId and rollItemsByItemId[itemId]
    if not items then
        return
    end
    for index = #items, 1, -1 do
        if items[index] == item then
            table.remove(items, index)
            break
        end
    end
    if #items == 0 then
        rollItemsByItemId[itemId] = nil
    end
end

local function clearCompletedRollAward(item)
    if not item or not item.itemId or not item.rollComplete then
        return
    end
    for _, recipient in ipairs(item.recipients or {}) do
        if recipient.winnerRecorded and not recipient.awardConfirmed then
            return
        end
    end
    untrackRollItem(item)
end

local function confirmRollAward(link, recipient, count)
    local itemId = ADDON.GetItemId(link)
    local items = itemId and rollItemsByItemId[itemId]
    if not items then
        return nil
    end

    local item
    local entry
    for _, candidateItem in ipairs(items) do
        local candidateEntry = findRecipient(candidateItem, recipient, function(candidate)
            return not candidate.awardConfirmed
        end)
        if candidateEntry then
            item = candidateItem
            entry = candidateEntry
            break
        end
    end
    if not item then
        for _, candidateItem in ipairs(items) do
            local matchingRoll = findPlayerRoll(candidateItem, recipient, function(roll)
                return roll.method ~= "pass"
            end)
            if not candidateItem.rollComplete and matchingRoll and not findRecipient(candidateItem, recipient) then
                item = candidateItem
                break
            end
        end
    end
    if not item then
        for _, candidateItem in ipairs(items) do
            if not candidateItem.rollComplete and not findRecipient(candidateItem, recipient) then
                item = candidateItem
                break
            end
        end
    end
    if item and not entry then
        entry = addRecipient(item, recipient, "roll", count, false)
    end
    if not item or not entry then
        return nil
    end

    entry.awardConfirmed = true
    entry.count = math.max(tonumber(entry.count) or 1, tonumber(count) or 1)
    entry.timestamp = ADDON.GetNow()
    clearCompletedRollAward(item)
    return item
end

local function addAward(segment, link, recipient, method, count)
    local itemId = ADDON.GetItemId(link)
    local isEmblem = ADDON.IsEmblem and ADDON.IsEmblem(link)
    local item = isEmblem and findItemInSegment(segment, itemId) or nil
    if not item then
        item = ADDON.AddItemToSegment(segment, link, count)
    end
    if not item then
        return nil
    end

    if isEmblem then
        addRecipient(item, recipient, method, count, true)
        local perPersonCount = 0
        for _, entry in ipairs(item.recipients or {}) do
            perPersonCount = math.max(perPersonCount, tonumber(entry.count) or 1)
        end
        item.count = math.max(1, perPersonCount)
    else
        addRecipient(item, recipient, method, count, false)
    end
    return item
end

local AWARD_FORMATS = {
    { text = LOOT_ITEM_SELF_MULTIPLE, self = true },
    { text = LOOT_ITEM_SELF, self = true },
    { text = LOOT_ITEM_MULTIPLE, self = false },
    { text = LOOT_ITEM, self = false },
    { text = LOOT_ITEM_PUSHED_SELF_MULTIPLE, self = true },
    { text = LOOT_ITEM_PUSHED_SELF, self = true },
}

local function parseAward(message)
    for _, definition in ipairs(AWARD_FORMATS) do
        local captures = matchLocalizedFormat(message, definition.text)
        if captures then
            local recipient, count = getCaptureValues(captures)
            if definition.self then
                recipient = UnitName and UnitName("player")
            end
            return recipient, count or 1
        end
    end
    return nil
end

local ROLL_SELECTION_FORMATS = {
    { text = LOOT_ROLL_NEED_SELF, method = "need", self = true },
    { text = LOOT_ROLL_NEED, method = "need" },
    { text = LOOT_ROLL_GREED_SELF, method = "greed", self = true },
    { text = LOOT_ROLL_GREED, method = "greed" },
    { text = LOOT_ROLL_DISENCHANT_SELF, method = "disenchant", self = true },
    { text = LOOT_ROLL_DISENCHANT, method = "disenchant" },
    { text = LOOT_ROLL_PASSED_SELF, method = "pass", self = true },
    { text = LOOT_ROLL_PASSED_SELF_AUTO, method = "pass", self = true },
    { text = LOOT_ROLL_PASSED, method = "pass" },
    { text = LOOT_ROLL_PASSED_AUTO, method = "pass" },
    { text = LOOT_ROLL_PASSED_AUTO_FEMALE, method = "pass" },
}

local ROLL_RESULT_FORMATS = {
    { text = LOOT_ROLL_ROLLED_NEED, method = "need" },
    { text = LOOT_ROLL_ROLLED_GREED, method = "greed" },
    { text = LOOT_ROLL_ROLLED_DE, method = "disenchant" },
}

local ROLL_WINNER_FORMATS = {
    { text = LOOT_ROLL_YOU_WON_NO_SPAM_NEED, self = true, method = "need", incomplete = true },
    { text = LOOT_ROLL_YOU_WON_NO_SPAM_GREED, self = true, method = "greed", incomplete = true },
    { text = LOOT_ROLL_YOU_WON_NO_SPAM_DE, self = true, method = "disenchant", incomplete = true },
    { text = LOOT_ROLL_WON_NO_SPAM_NEED, method = "need", incomplete = true },
    { text = LOOT_ROLL_WON_NO_SPAM_GREED, method = "greed", incomplete = true },
    { text = LOOT_ROLL_WON_NO_SPAM_DE, method = "disenchant", incomplete = true },
    { text = LOOT_ROLL_YOU_WON, self = true },
    { text = LOOT_ROLL_WON, self = false },
}

local function createStandaloneRollItem(link)
    local segment = createStorageBatch("roll")
    local item = ADDON.AddItemToSegment(segment, link, 1)
    if item then
        item.blizzardRollStarted = true
        item.rollHistoryIncomplete = true
        trackRollItem(item)
    end
    return item
end

local function getRollItem(link, allowStandalone, predicate)
    local itemId = ADDON.GetItemId(link)
    for _, item in ipairs(itemId and rollItemsByItemId[itemId] or {}) do
        if (not predicate or predicate(item)) then
            return item
        end
    end
    if not allowStandalone then
        return nil
    end
    return createStandaloneRollItem(link)
end

local function addRollSelection(item, playerName, method, rollId)
    playerName = cleanPlayerName(playerName)
    if not item or not playerName or not method then
        return nil
    end
    item.rolls = item.rolls or {}
    local existing = findPlayerRoll(item, playerName)
    if existing then
        existing.method = method
        existing.timestamp = ADDON.GetNow()
        existing.rollId = rollId or existing.rollId
        return existing
    end
    local roll = {
        name = playerName,
        method = method,
        timestamp = ADDON.GetNow(),
        rollId = rollId,
    }
    table.insert(item.rolls, roll)
    return roll
end

local function addRollResult(item, playerName, method, result)
    playerName = cleanPlayerName(playerName)
    if not item or not playerName or not method or not result then
        return nil
    end
    local roll = findPlayerRoll(item, playerName, function(candidate)
        return candidate.method == method
    end)
    if not roll then
        roll = addRollSelection(item, playerName, method)
    end
    roll.result = result
    roll.timestamp = ADDON.GetNow()
    return roll
end

local function getWinnerRoll(item, playerName, method)
    return findPlayerRoll(item, playerName, function(roll)
        return roll.method ~= "pass" and (not method or roll.method == method) and not roll.won
    end)
end

local function getRollItemForSelection(link, playerName)
    -- Chat messages do not contain a roll ID. Assign each player's first choice
    -- to the first identical item they have not handled yet, then continue in order.
    return getRollItem(link, false, function(item)
        return not item.rollComplete and not findPlayerRoll(item, playerName)
    end)
end

local function confirmRecordedRollSelection(link, playerName, method)
    local itemId = ADDON.GetItemId(link)
    for _, item in ipairs(itemId and rollItemsByItemId[itemId] or {}) do
        local roll = findPlayerRoll(item, playerName, function(candidate)
            return candidate.method == method and not candidate.chatConfirmed
        end)
        if roll then
            roll.chatConfirmed = true
            roll.timestamp = ADDON.GetNow()
            return roll
        end
    end
    return nil
end

local function getRollItemForResult(link, playerName, method)
    local itemId = ADDON.GetItemId(link)
    for _, item in ipairs(itemId and rollItemsByItemId[itemId] or {}) do
        local roll = findPlayerRoll(item, playerName, function(candidate)
            return candidate.method == method and candidate.result == nil
        end)
        if roll then
            return item
        end
    end
    return getRollItemForSelection(link, playerName)
end

local function getRollItemForWinner(link, playerName, method, result)
    local itemId = ADDON.GetItemId(link)
    local items = itemId and rollItemsByItemId[itemId] or {}
    if result then
        for _, item in ipairs(items) do
            local roll = getWinnerRoll(item, playerName, method)
            if not item.rollComplete and roll and tonumber(roll.result) == tonumber(result) then
                return item
            end
        end
    end
    for _, item in ipairs(items) do
        if not item.rollComplete and getWinnerRoll(item, playerName, method) then
            return item
        end
    end
    return getRollItem(link, true, function(item)
        return not item.rollComplete
    end)
end

local function handleRollSelection(message, link)
    for _, definition in ipairs(ROLL_SELECTION_FORMATS) do
        local captures = matchLocalizedFormat(message, definition.text)
        if captures then
            local playerName = getCaptureValues(captures)
            if definition.self then
                playerName = UnitName and UnitName("player")
            end
            local roll = confirmRecordedRollSelection(link, playerName, definition.method)
            if not roll then
                local item = getRollItemForSelection(link, playerName)
                roll = addRollSelection(item, playerName, definition.method)
                if roll then
                    roll.chatConfirmed = true
                end
            end
            refreshWindow()
            return true
        end
    end
    return false
end

local function handleRollResult(message, link)
    for _, definition in ipairs(ROLL_RESULT_FORMATS) do
        local captures = matchLocalizedFormat(message, definition.text)
        if captures then
            local playerName, result = getCaptureValues(captures)
            addRollResult(
                getRollItemForResult(link, playerName, definition.method),
                playerName,
                definition.method,
                result
            )
            refreshWindow()
            return true
        end
    end
    return false
end

local function handleRollWinner(message, link)
    for _, definition in ipairs(ROLL_WINNER_FORMATS) do
        local captures = matchLocalizedFormat(message, definition.text)
        if captures then
            local playerName, result = getCaptureValues(captures)
            if definition.self then
                playerName = UnitName and UnitName("player")
            end
            local item = getRollItemForWinner(link, playerName, definition.method, result)
            if item and playerName then
                local winnerRoll
                if result and definition.method then
                    winnerRoll = addRollResult(item, playerName, definition.method, result)
                else
                    winnerRoll = getWinnerRoll(item, playerName, definition.method)
                end
                local method = definition.method or (winnerRoll and winnerRoll.method)
                if not method then
                    item.rollHistoryIncomplete = true
                    method = "roll"
                end
                if definition.incomplete then
                    item.rollHistoryIncomplete = true
                end
                if winnerRoll then
                    winnerRoll.won = true
                end
                item.rollMethod = method
                addOrUpdateRollWinner(item, playerName, method)
                item.rollOutcomes = 1
                item.rollComplete = true
                clearCompletedRollAward(item)
            end
            refreshWindow()
            return true
        end
    end
    return false
end

local function handleAllPassed(message, link)
    local captures = matchLocalizedFormat(message, LOOT_ROLL_ALL_PASSED)
    if not captures then
        return false
    end
    local item = getRollItem(link, true, function(candidate)
        return not candidate.rollComplete
    end)
    if item then
        item.rollOutcomes = 1
        item.rollComplete = true
        item.allPassed = true
        untrackRollItem(item)
    end
    refreshWindow()
    return true
end

local function handleLootMessage(message)
    local links = ADDON.ExtractItemLinks(message)
    local link = links[1]
    if not link then
        return
    end

    if handleRollSelection(message, link)
        or handleRollResult(message, link)
        or handleRollWinner(message, link)
        or handleAllPassed(message, link) then
        return
    end

    local recipient, count = parseAward(message)
    if not recipient then
        return
    end
    local segment
    for _, awardLink in ipairs(links) do
        -- CHAT_MSG_LOOT confirms item and recipient, but does not distinguish
        -- direct looting from a master-loot assignment on every client.
        if not confirmRollAward(awardLink, recipient, count) then
            segment = segment or createStorageBatch("loot")
            addAward(segment, awardLink, recipient, "loot", count)
        end
        if ADDON.ShowLootPopupItem then
            ADDON.ShowLootPopupItem(awardLink, count, recipient)
        end
    end
    refreshWindow()
end

local function handleRollStarted(rollId)
    if rollId and activeRollsById[rollId] then
        return
    end
    local link = rollId and GetLootRollItemLink and GetLootRollItemLink(rollId)
    local itemId = ADDON.GetItemId(link)
    if not rollId or not link or not itemId then
        return
    end

    local existingItems = rollItemsByItemId[itemId]
    local hasActiveItem
    for _, existingItem in ipairs(existingItems or {}) do
        if existingItem.rollId and activeRollsById[existingItem.rollId] == existingItem then
            hasActiveItem = true
            break
        end
    end
    if not hasActiveItem then
        -- A later roll for the same item starts a new sequence. Old unresolved
        -- candidates remain in history but must not receive events from this batch.
        rollItemsByItemId[itemId] = nil
    end

    local segment = activeRollSegmentsByItemId[itemId]
    local createdSegment
    if not segment then
        segment = createStorageBatch("roll")
        activeRollSegmentsByItemId[itemId] = segment
        createdSegment = true
    end
    local item = ADDON.AddItemToSegment(segment, link, 1)
    if not item then
        if createdSegment then
            activeRollSegmentsByItemId[itemId] = nil
        end
        return
    end
    item.blizzardRollStarted = true
    item.rollId = rollId
    trackRollItem(item)

    activeRollsById[rollId] = item
    activeRollCountsByItemId[itemId] = (activeRollCountsByItemId[itemId] or 0) + 1
    refreshWindow()
end

local function handleRollCancelled(rollId)
    local item = rollId and activeRollsById[rollId]
    if not item then
        return
    end

    activeRollsById[rollId] = nil
    local itemId = item.itemId
    activeRollCountsByItemId[itemId] = math.max(0, (activeRollCountsByItemId[itemId] or 1) - 1)
    if activeRollCountsByItemId[itemId] == 0 then
        activeRollCountsByItemId[itemId] = nil
        activeRollSegmentsByItemId[itemId] = nil
    end
    if not item.rollComplete then
        item.rollClosed = true
    end
    refreshWindow()
end

local function recordPlayerRoll(rollId, rollType)
    local item = rollId and activeRollsById[rollId]
    local method = rollType == 0 and "pass"
        or rollType == 1 and "need"
        or rollType == 2 and "greed"
        or rollType == 3 and "disenchant"
    if item and method then
        local roll = addRollSelection(item, UnitName and UnitName("player"), method, rollId)
        if roll and roll.chatConfirmed == nil then
            roll.chatConfirmed = false
        end
        refreshWindow()
    end
end

function ADDON.InitializeTracker()
    if ChatFrame_AddMessageEventFilter and not registeredLootChatFilter then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", function()
            return ADDON.GetSettings().hideLootChatMessages and true or false
        end)
        registeredLootChatFilter = true
    end
    if hooksecurefunc and RollOnLoot and not registeredRollHook then
        hooksecurefunc("RollOnLoot", recordPlayerRoll)
        registeredRollHook = true
    end

    DudesUtils.EventHandler.Add("CHAT_MSG_LOOT", function(_, message)
        handleLootMessage(message)
    end)
    DudesUtils.EventHandler.Add("START_LOOT_ROLL", function(_, rollId)
        if DudesUtils.OnNextUpdate then
            DudesUtils.OnNextUpdate(function()
                handleRollStarted(rollId)
            end)
        else
            handleRollStarted(rollId)
        end
    end)
    DudesUtils.EventHandler.Add("CANCEL_LOOT_ROLL", function(_, rollId)
        handleRollCancelled(rollId)
    end)
end
