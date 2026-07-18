DudesFlexFrames = DudesFlexFrames or {}
DudesFlexFrames_Positions = DudesFlexFrames_Positions or {}
DudesFlexFrames_Scales = DudesFlexFrames_Scales or {}
DudesFlexFrames_Settings = DudesFlexFrames_Settings or {}
DudesFlexFrames_ActiveRolls = DudesFlexFrames_ActiveRolls or {}

local NO_DRAG_TARGETS = {}
local GROUP_LOOT_PARENT_NAME = "DudesFlexFrames_GroupLootParent"
local GROUP_LOOT_FRAME_COUNT = 4
local GROUP_LOOT_DEFAULT_SPACING = -15
local GROUP_LOOT_FRAME_NAMES = {"GroupLootFrame1", "GroupLootFrame2", "GroupLootFrame3", "GroupLootFrame4"}
local DEFAULT_SETTINGS = {
	restoreOpenRolls = false,
	autoConfirmBindOnPickup = false,
	showOpenRollCount = false,
	singleRollFrame = false,
	rollFrameSpacing = 0
}

local flexFrameNames = {
    DudesFlexFrames_GroupLootParent = GROUP_LOOT_FRAME_NAMES,
	SpellBookFrame 			        = NO_DRAG_TARGETS,
	CharacterFrame 			        = {"PaperDollFrame", "PetPaperDollFrameCompanionFrame", "ReputationFrame", "SkillFrame", "TokenFrame"},
	PlayerTalentFrame 		        = NO_DRAG_TARGETS,
	AchievementFrame 		        = {"AchievementFrameHeader"},
	CalendarFrame 			        = NO_DRAG_TARGETS,
	QuestLogFrame 			        = NO_DRAG_TARGETS,
	QuestFrame 				        = NO_DRAG_TARGETS,
	FriendsFrame 			        = NO_DRAG_TARGETS,
	PVPParentFrame 			        = {"PVPBattlegroundFrame", "PVPFrame"},
	InspectFrame 			        = {"InspectPVPFrame", "InspectTalentFrame", "InspectNameFrame"},
	AuctionFrame 			        = NO_DRAG_TARGETS,
	TradeSkillFrame 		        = NO_DRAG_TARGETS,
	MacroFrame 				        = NO_DRAG_TARGETS,
	GossipFrame 			        = NO_DRAG_TARGETS,
	TaxiFrame 				        = NO_DRAG_TARGETS,
	MerchantFrame 			        = NO_DRAG_TARGETS,
	ClassTrainerFrame 		        = NO_DRAG_TARGETS,
	DressUpFrame 			        = NO_DRAG_TARGETS,
	ContainerFrame1 		        = NO_DRAG_TARGETS,
	ContainerFrame2 		        = NO_DRAG_TARGETS,
	ContainerFrame3 		        = NO_DRAG_TARGETS,
	ContainerFrame4 		        = NO_DRAG_TARGETS,
	ContainerFrame5 		        = NO_DRAG_TARGETS,
	Atr_Adv_Search_Dialog 	        = NO_DRAG_TARGETS,
	Atr_Buy_Confirm_Frame 	        = NO_DRAG_TARGETS,
	Atr_FullScanFrame 		        = NO_DRAG_TARGETS,
	MailFrame 				        = {"SendMailFrame"},
	BankFrame 				        = NO_DRAG_TARGETS,
	TradeFrame 				        = NO_DRAG_TARGETS,
	GuildBankFrame 			        = NO_DRAG_TARGETS,
	ItemSocketingFrame 		        = NO_DRAG_TARGETS,
	HelpFrame 				        = NO_DRAG_TARGETS,
	StaticPopup1 			        = NO_DRAG_TARGETS,
	LFDParentFrame 			        = NO_DRAG_TARGETS
}
local scaleFrameNames = {
	"InspectModelFrame",
	"CharacterModelFrame",
	"DressUpModel"
}

local function getSettings()
	for key, value in pairs(DEFAULT_SETTINGS) do
		if DudesFlexFrames_Settings[key] == nil then
			DudesFlexFrames_Settings[key] = value
		end
	end
	return DudesFlexFrames_Settings
end

function DudesFlexFrames.GetSettings()
	return getSettings()
end

local function getGroupLootSpacing()
	return GROUP_LOOT_DEFAULT_SPACING + (tonumber(getSettings().rollFrameSpacing) or 0)
end

local function getRollId(frame)
	return frame and (frame.rollID or frame.rollId or frame.id)
end

local function getRollRemaining(rollId)
	local roll = rollId and DudesFlexFrames_ActiveRolls[rollId]
	if roll and roll.expiresAt and GetTime then
		return roll.expiresAt - GetTime()
	end
	return roll and roll.duration or 0
end

local function pruneActiveRolls()
	local now = GetTime and GetTime() or 0
	for rollId, roll in pairs(DudesFlexFrames_ActiveRolls) do
		if roll.expiresAt and roll.expiresAt <= now then
			DudesFlexFrames_ActiveRolls[rollId] = nil
		end
	end
end

local function trackActiveRoll(rollId, rollTime)
	if rollId then
		local duration = tonumber(rollTime) or 60
		DudesFlexFrames_ActiveRolls[rollId] = {
			startedAt = GetTime and GetTime() or 0,
			duration = duration,
			expiresAt = (GetTime and GetTime() or 0) + duration
		}
	end
end

local function countActiveRolls()
	pruneActiveRolls()
	local count = 0
	for _ in pairs(DudesFlexFrames_ActiveRolls) do
		count = count + 1
	end
	return count
end

local function hideGroupLootCount(frame)
	if frame and frame.DudesFlexFrames_CountText then
		frame.DudesFlexFrames_CountText:Hide()
	end
end

local function ensureGroupLootCount(frame)
	if frame.DudesFlexFrames_CountText then
		return
	end
	frame.DudesFlexFrames_CountText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.DudesFlexFrames_CountText:SetTextColor(1, 1, 1)
	frame.DudesFlexFrames_CountText:Hide()
end

local function updateGroupLootCount(frame)
	if not frame or not frame.DudesFlexFrames_CountText then
		return
	end
	local count = countActiveRolls()
	if getSettings().singleRollFrame and getSettings().showOpenRollCount and count > 0 then
		local frameName = frame:GetName()
		local rollButton = frameName and (_G[frameName .. "NeedButton"] or _G[frameName .. "RollButton"])
		frame.DudesFlexFrames_CountText:ClearAllPoints()
		if rollButton then
			frame.DudesFlexFrames_CountText:SetPoint("LEFT", rollButton, "RIGHT", 4, 0)
		else
			frame.DudesFlexFrames_CountText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -16)
		end
		frame.DudesFlexFrames_CountText:SetText(count >= GROUP_LOOT_FRAME_COUNT and tostring(GROUP_LOOT_FRAME_COUNT) .. "+" or count)
		frame.DudesFlexFrames_CountText:Show()
	else
		frame.DudesFlexFrames_CountText:Hide()
	end
end

local function ensureGroupLootBackground(frame)
	if not frame.DudesFlexFrames_Background then
		frame.DudesFlexFrames_Background = frame:CreateTexture(nil, "BACKGROUND")
		frame.DudesFlexFrames_Background:SetTexture(0, 0, 0, 1)
	end
	frame.DudesFlexFrames_Background:ClearAllPoints()
	frame.DudesFlexFrames_Background:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
	frame.DudesFlexFrames_Background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
end

local function layoutGroupLootFrames()
	local parent = DudesFlexFrames_GroupLootParent
	if not parent or not GroupLootFrame1 then
		return
	end
	local settings = getSettings()
	local spacing = getGroupLootSpacing()
	local width = GroupLootFrame1:GetWidth()
	local height = GroupLootFrame1:GetHeight()
	local parentHeight = settings.singleRollFrame and height or ((GROUP_LOOT_FRAME_COUNT * height) + ((GROUP_LOOT_FRAME_COUNT - 1) * spacing))
	local currentBottom = 0
	local shortestFrame
	local shortestRemaining

	parent:SetWidth(width)
	parent:SetHeight(parentHeight)

	for i, frameName in ipairs(GROUP_LOOT_FRAME_NAMES) do
		local frame = _G[frameName]
		if frame then
			ensureGroupLootBackground(frame)
			ensureGroupLootCount(frame)
			hideGroupLootCount(frame)
			frame:ClearAllPoints()
			frame:SetParent(parent)
			frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, settings.singleRollFrame and 0 or currentBottom)
			frame:SetFrameLevel(parent:GetFrameLevel() + i)
			currentBottom = currentBottom + height + spacing

			if settings.singleRollFrame and frame:IsShown() then
				local remaining = getRollRemaining(getRollId(frame))
				if not shortestRemaining or remaining < shortestRemaining then
					shortestRemaining = remaining
					shortestFrame = frame
				end
			end
		end
	end

	if shortestFrame then
		shortestFrame:SetFrameLevel(parent:GetFrameLevel() + GROUP_LOOT_FRAME_COUNT + 1)
	end
	updateGroupLootCount(shortestFrame)
end

local function queueGroupLootLayout()
	if DudesUtils.OnNextUpdate then
		DudesUtils.OnNextUpdate(layoutGroupLootFrames)
	else
		layoutGroupLootFrames()
	end
end

local function enableBlizzardAutoClose(frameName)
	if UISpecialFrames and not DudesUtils.Array.Contains(UISpecialFrames, frameName) then
		table.insert(UISpecialFrames, frameName)
	end
end

local function disableBlizzardAutoClose(frameName)
	if UISpecialFrames then
		for i = #UISpecialFrames, 1, -1 do
			if UISpecialFrames[i] == frameName then
				table.remove(UISpecialFrames, i)
			end
		end
	end
end

local function disableBlizzardPanelManagement(frameName)
	if frameName and frameName ~= GROUP_LOOT_PARENT_NAME then
		if UIPanelWindows and UIPanelWindows[frameName] then
			UIPanelWindows[frameName] = nil
		end
		enableBlizzardAutoClose(frameName)
	end
end

local function savePosition(frame)
	local name = frame:GetName()
	local point, _, relPoint, xOfs, yOfs = frame:GetPoint()
	
	if name and point then
		DudesFlexFrames_Positions[name] = {point, relPoint, xOfs, yOfs}
	end
end

local function saveScale(frame)
	local name = frame:GetName()
	local scale = frame:GetScale()
	
	if name and scale then
		DudesFlexFrames_Scales[name] = scale
	end
end


local function loadPosition(frame)
	local name = frame:GetName()
	local pos = name and DudesFlexFrames_Positions[name]
	
	if pos then
		frame:ClearAllPoints()
		frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	end
end

local function loadScale(frame)
	local name = frame:GetName()
	local scale = name and DudesFlexFrames_Scales[name]

	if scale then
		frame:SetScale(scale)
	end
end

local function initScale(frame, scaleTarget)
	scaleTarget:EnableMouseWheel(true)
	scaleTarget:HookScript("OnMouseWheel", function(_, delta)
		if IsControlKeyDown() and not InCombatLockdown() then
			local scale = frame:GetScale() or 1
			scale = scale + delta * 0.05
			scale = math.max(0.5, math.min(scale, 2.0))

			frame:SetScale(scale)
			saveScale(frame)
		end
	end)
end

local function initDrag(frame, dragTarget)	
	dragTarget:EnableMouse(true)
	dragTarget:RegisterForDrag("LeftButton")
	dragTarget:HookScript("OnDragStart", function()
		frame:StartMoving()
	end)
	dragTarget:HookScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		savePosition(frame)
	end)
end

local function initFlex(frame, dragNames)
	disableBlizzardPanelManagement(frame:GetName())
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:SetUserPlaced(true)
	loadScale(frame)
	loadPosition(frame)
	if frame:GetName() ~= GROUP_LOOT_PARENT_NAME then
		initDrag(frame, frame)
		initScale(frame, frame)
	else
		frame:EnableMouse(false)
	end

	for _, dragName in ipairs(dragNames) do
		local dragTarget = _G[dragName]
		if dragTarget then
			initDrag(frame, dragTarget)
			initScale(frame, dragTarget)
		end
	end
end

local function initFrame(frameName, initFunc)
	local frame = _G[frameName]
	if frame and not frame.DudesFlexFrames_Init then
		initFunc(frame)
		frame.DudesFlexFrames_Init = true
	end
end

local function initGroupLootParent()
    if not DudesFlexFrames_GroupLootParent and GroupLootFrame1 then
        local left = GroupLootFrame1:GetLeft()
        local bottom = GroupLootFrame1:GetBottom()

        local parent = CreateFrame("Frame", GROUP_LOOT_PARENT_NAME, UIParent)
        parent:ClearAllPoints()
        parent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        parent:SetFrameStrata("DIALOG")
        parent:EnableMouse(false)
        layoutGroupLootFrames()
        parent:Show()
    end
end

function DudesFlexFrames.RefreshGroupLootFrames()
	layoutGroupLootFrames()
end

local function restoreOpenRolls()
	if not getSettings().restoreOpenRolls or not GroupLootFrame_OpenNewFrame then
		return
	end
	pruneActiveRolls()
	for rollId, roll in pairs(DudesFlexFrames_ActiveRolls) do
		if GetLootRollItemInfo and GetLootRollItemInfo(rollId) then
			local remaining = roll.expiresAt and GetTime and math.max(1, roll.expiresAt - GetTime()) or roll.duration or 60
			GroupLootFrame_OpenNewFrame(rollId, remaining)
		end
	end
	layoutGroupLootFrames()
end

local function onStartLootRoll(_, rollId, rollTime)
	trackActiveRoll(rollId, rollTime)
	queueGroupLootLayout()
end

local function onCancelLootRoll(_, rollId)
	if rollId then
		DudesFlexFrames_ActiveRolls[rollId] = nil
	end
	queueGroupLootLayout()
end

local function onConfirmLootRoll(_, rollId, rollType)
	if getSettings().autoConfirmBindOnPickup and ConfirmLootRoll and rollId and rollType then
		ConfirmLootRoll(rollId, rollType)
		if StaticPopup_Hide then
			StaticPopup_Hide("CONFIRM_LOOT_ROLL")
		end
	end
end

local function init()
	if not InCombatLockdown() then
		initGroupLootParent()
		for flexFrameName, dragNames in pairs(flexFrameNames) do
			initFrame(flexFrameName, function(frame)
				initFlex(frame, dragNames)
			end)
		end
		for _, scaleFrameName in ipairs(scaleFrameNames) do
			initFrame(scaleFrameName, function(frame)
				initScale(frame, frame)
			end)
		end
		-- Workaround for weird Auctionator frame hanging loosely around
		if Atr_Mask then
			Atr_Mask.Show = function()	end
		end
	end
end

local function resetFrame(frame)
	if frame then
		frame:SetScale(1)
		frame:StopMovingOrSizing()
		if frame:IsUserPlaced() then
		    frame:SetUserPlaced(false)
		end
		frame.DudesFlexFrames_Init = nil
	end
end

function DudesFlexFrames.ResetFrames()
	DudesFlexFrames_Positions = {}
	DudesFlexFrames_Scales = {}

	for flexFrameName in pairs(flexFrameNames) do
		resetFrame(_G[flexFrameName])
	end
	for _, scaleFrameName in ipairs(scaleFrameNames) do
		resetFrame(_G[scaleFrameName])
	end

	ReloadUI()
end

-- ADDON_LOADED is called for every Addon loaded first time, also internal ones
-- Thereby catching the creation of e.g. PlayerTalentFrame
DudesUtils.EventHandler.Add("ADDON_LOADED", init) 

-- PLAYER_REGEN_ENABLED in case we login infight
DudesUtils.EventHandler.Add("PLAYER_REGEN_ENABLED", init)
DudesUtils.EventHandler.Add("START_LOOT_ROLL", onStartLootRoll)
DudesUtils.EventHandler.Add("CANCEL_LOOT_ROLL", onCancelLootRoll)
DudesUtils.EventHandler.Add("CONFIRM_LOOT_ROLL", onConfirmLootRoll)
DudesUtils.EventHandler.Add("PLAYER_ENTERING_WORLD", function()
	if DudesUtils.OnNextUpdate then
		DudesUtils.OnNextUpdate(restoreOpenRolls)
	else
		restoreOpenRolls()
	end
end)

-- Avoid broken esc key functionality since protected frames cannot get closed by UISpecialFrames infight
-- e.g. cannot clear target with esc anymore when CharacterFrame is open infight
DudesUtils.EventHandler.Add("PLAYER_REGEN_ENABLED", function()
	enableBlizzardAutoClose("CharacterFrame")
	enableBlizzardAutoClose("SpellBookFrame")
end)
DudesUtils.EventHandler.Add("PLAYER_REGEN_DISABLED", function()
	disableBlizzardAutoClose("CharacterFrame")
	disableBlizzardAutoClose("SpellBookFrame")
end)
