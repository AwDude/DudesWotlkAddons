local ADDON = DudesLootTracker
local bindTooltip

local QUALITY_COLORS = {
    [0] = "9d9d9d",
    [1] = "ffffff",
    [2] = "1eff00",
    [3] = "0070dd",
    [4] = "a335ee",
    [5] = "ff8000",
    [6] = "e6cc80",
    [7] = "e6cc80",
}

local EMBLEM_ITEM_IDS = {
    [43228] = true, -- Stone Keeper's Shard
    [40752] = true, -- Emblem of Heroism
    [40753] = true, -- Emblem of Valor
    [45624] = true, -- Emblem of Conquest
    [47241] = true, -- Emblem of Triumph
    [49426] = true, -- Emblem of Frost
}

local function parseItemId(link)
    if not link then
        return nil
    end
    return tonumber(string.match(link, "item:(%d+)"))
end

local function parseItemName(link)
    if not link then
        return nil
    end
    return string.match(link, "%[(.-)%]")
end

local function isBindOnEquip(link)
    if not link or not CreateFrame then
        return false
    end
    if not bindTooltip then
        bindTooltip = CreateFrame("GameTooltip", "DudesLootTrackerDataBindTooltip", UIParent, "GameTooltipTemplate")
        bindTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    bindTooltip:ClearLines()
    bindTooltip:SetHyperlink(link)
    local bindText = ITEM_BIND_ON_EQUIP or "Binds when equipped"
    for i = 1, 12 do
        local line = _G["DudesLootTrackerDataBindTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text and text == bindText then
            return true
        end
    end
    return false
end

local function getLootMethodInfo()
    local method, partyIndex, raidIndex = GetLootMethod and GetLootMethod()
    local masterName
    if method == "master" then
        if raidIndex and GetRaidRosterInfo then
            masterName = GetRaidRosterInfo(raidIndex)
        elseif partyIndex and partyIndex > 0 and UnitName then
            masterName = UnitName("party" .. tostring(partyIndex))
        elseif partyIndex == 0 and UnitName then
            masterName = UnitName("player")
        end
    end
    return method or "unknown", masterName
end

function ADDON.GetQualityColor(quality)
    return QUALITY_COLORS[tonumber(quality) or 1] or QUALITY_COLORS[1]
end

function ADDON.ExtractItemLinks(text)
    local links = {}
    text = text or ""
    for link in string.gmatch(text, "|c%x+|Hitem:.-|h%[.-%]|h|r") do
        table.insert(links, link)
    end
    return links
end

function ADDON.GetItemId(link)
    return parseItemId(link)
end

function ADDON.IsEmblem(itemOrLink)
    local itemId
    if type(itemOrLink) == "table" then
        itemId = tonumber(itemOrLink.itemId) or parseItemId(itemOrLink.link)
    else
        itemId = parseItemId(itemOrLink)
    end
    return itemId and EMBLEM_ITEM_IDS[itemId] and true or false
end

function ADDON.GetItemDisplayName(link)
    local name = parseItemName(link)
    if (not name or name == "") and GetItemInfo then
        name = GetItemInfo(link)
    end
    return name or link or "Unbekanntes Item"
end

function ADDON.BuildItem(link, count)
    local name, itemLink, quality, itemLevel, requiredLevel, itemType, itemSubType, _, itemEquipLoc, texture
    if GetItemInfo then
        name, itemLink, quality, itemLevel, requiredLevel, itemType, itemSubType, _, itemEquipLoc, texture = GetItemInfo(link)
    end

    local slot = itemEquipLoc and _G[itemEquipLoc] or itemEquipLoc
    local isEquipment = itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_NON_EQUIP"
    return {
        id = nil,
        itemId = parseItemId(link),
        link = itemLink or link,
        name = name or parseItemName(link) or tostring(link or "Unbekannt"),
        quality = quality or 1,
        itemLevel = itemLevel or 0,
        requiredLevel = requiredLevel or 0,
        slot = slot or "",
        equipLoc = itemEquipLoc or "",
        isEquipment = isEquipment and true or false,
        bindOnEquip = nil,
        bindInfoReady = false,
        itemType = itemType or "",
        itemSubType = itemSubType or "",
        isEmblem = EMBLEM_ITEM_IDS[parseItemId(link)] and true or false,
        texture = texture or "Interface\\Icons\\INV_Misc_QuestionMark",
        infoReady = name and true or false,
        count = count or 1,
        recipients = {},
        expanded = false,
    }
end

function ADDON.RefreshItemInfo(item)
    if not item or not item.link or not GetItemInfo then
        return false
    end
    local name, itemLink, quality, itemLevel, requiredLevel, itemType, itemSubType, _, itemEquipLoc, texture = GetItemInfo(item.link)
    if not name then
        return false
    end
    item.name = name
    item.link = itemLink or item.link
    item.quality = quality or item.quality
    item.itemLevel = itemLevel or item.itemLevel
    item.requiredLevel = requiredLevel or item.requiredLevel
    item.itemType = itemType or item.itemType
    item.itemSubType = itemSubType or item.itemSubType
    item.isEmblem = EMBLEM_ITEM_IDS[item.itemId] and true or false
    item.equipLoc = itemEquipLoc or item.equipLoc
    item.isEquipment = itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_NON_EQUIP" or item.isEquipment
    item.slot = (itemEquipLoc and _G[itemEquipLoc]) or item.slot
    item.texture = texture or item.texture
    item.infoReady = true
    return true
end

function ADDON.RefreshItemBindInfo(item)
    if not item or item.bindInfoReady then
        return item and item.bindOnEquip
    end
    item.bindOnEquip = isBindOnEquip(item.link)
    item.bindInfoReady = true
    return item.bindOnEquip
end

function ADDON.GetInstanceContext()
    local name, instanceType, difficultyIndex, difficultyName, maxPlayers
    if GetInstanceInfo then
        name, instanceType, difficultyIndex, difficultyName, maxPlayers = GetInstanceInfo()
    end

    local heroic = false
    if difficultyName and string.find(string.lower(difficultyName), "hero") then
        heroic = true
    elseif difficultyIndex == 2 or difficultyIndex == 4 or difficultyIndex == 6 then
        heroic = true
    end

    return {
        raid = name or "World",
        instanceType = instanceType or "none",
        size = maxPlayers,
        difficultyIndex = difficultyIndex,
        difficultyName = difficultyName,
        heroic = heroic,
    }
end

function ADDON.GetLootMethodContext()
    local method, masterName = getLootMethodInfo()
    return {
        method = method,
        masterName = masterName,
        label = method == "master" and "Plündermeister" or "Plündern als Gruppe",
    }
end

function ADDON.AllocateSegmentId()
    local db = ADDON.GetCharacterDB()
    local id = db.nextSegmentId or 1
    db.nextSegmentId = id + 1
    return id
end

function ADDON.AllocateItemId()
    local db = ADDON.GetCharacterDB()
    local id = db.nextItemId or 1
    db.nextItemId = id + 1
    return id
end

function ADDON.CreateSegment(sourceName)
    local context = ADDON.GetInstanceContext()
    local lootMethod = ADDON.GetLootMethodContext()
    local raidKey, raidInfo = ADDON.GetCurrentRaidKey()
    return {
        id = ADDON.AllocateSegmentId(),
        timestamp = ADDON.GetNow(),
        sourceName = sourceName,
        raid = context.raid,
        instanceType = context.instanceType,
        raidSize = context.size or raidInfo.size,
        difficultyIndex = context.difficultyIndex or raidInfo.difficultyIndex,
        heroic = context.heroic,
        difficultyName = context.difficultyName,
        lootMethod = lootMethod.method,
        lootMethodLabel = lootMethod.label,
        masterLooter = lootMethod.masterName,
        raidKey = raidKey,
        raidId = raidInfo.raidId,
        items = {},
    }
end

function ADDON.AddSegment(segment)
    local db = ADDON.GetCharacterDB()
    table.insert(db.segments, segment)
    if ADDON.PruneHistory then
        ADDON.PruneHistory()
    end
    if ADDON.RequestRefreshMainWindow then
        ADDON.RequestRefreshMainWindow()
    end
    return segment
end

function ADDON.PruneHistory()
    local db = ADDON.GetCharacterDB()
    local settings = ADDON.GetSettings()
    local segments = db.segments or {}

    local maxLootEntries = tonumber(settings.maxLootEntries) or 0
    if maxLootEntries > 0 then
        local count = 0
        for i = #segments, 1, -1 do
            count = count + #(segments[i].items or {})
            if count > maxLootEntries then
                table.remove(segments, i)
            end
        end
    end
end

function ADDON.FindItemById(itemId)
    if not itemId then
        return nil
    end
    local segments = ADDON.GetCharacterDB().segments or {}
    for _, segment in ipairs(segments) do
        for _, item in ipairs(segment.items or {}) do
            if item.id == itemId then
                return item, segment
            end
        end
    end
    return nil
end

function ADDON.FindLatestItemByItemId(itemId)
    if not itemId then
        return nil
    end
    local segments = ADDON.GetCharacterDB().segments or {}
    for i = #segments, 1, -1 do
        local segment = segments[i]
        for j = #(segment.items or {}), 1, -1 do
            local item = segment.items[j]
            if item.itemId == itemId then
                return item, segment
            end
        end
    end
    return nil
end

function ADDON.FindRollCandidateByItemId(itemId)
    if not itemId then
        return nil
    end
    local segments = ADDON.GetCharacterDB().segments or {}
    for i = #segments, 1, -1 do
        local segment = segments[i]
        for j = #(segment.items or {}), 1, -1 do
            local item = segment.items[j]
            if item.itemId == itemId
                and not item.blizzardRollStarted
                and #(item.recipients or {}) == 0 then
                return item, segment
            end
        end
    end
    return nil
end

function ADDON.FindRecipientCandidateByItemId(itemId)
    if not itemId then
        return nil
    end
    local segments = ADDON.GetCharacterDB().segments or {}
    for i = #segments, 1, -1 do
        local segment = segments[i]
        for j = #(segment.items or {}), 1, -1 do
            local item = segment.items[j]
            if item.itemId == itemId
                and #(item.recipients or {}) == 0
                and item.blizzardRollStarted then
                return item, segment
            end
        end
    end
    return nil
end
