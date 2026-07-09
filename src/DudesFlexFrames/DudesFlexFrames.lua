local NO_DRAG_TARGETS = {}
local flexFrameNames = {
	GroupLootFrame1 		= NO_DRAG_TARGETS,
	GroupLootFrame2 		= NO_DRAG_TARGETS,
	GroupLootFrame3 		= NO_DRAG_TARGETS,
	GroupLootFrame4 		= NO_DRAG_TARGETS,
	SpellBookFrame 			= NO_DRAG_TARGETS,
	CharacterFrame 			= {"PaperDollFrame", "ReputationFrame", "SkillFrame", "TokenFrame"},
	PlayerTalentFrame 		= NO_DRAG_TARGETS,
	AchievementFrame 		= {"AchievementFrameHeader"},
	CalendarFrame 			= NO_DRAG_TARGETS,
	QuestLogFrame 			= NO_DRAG_TARGETS,
	QuestFrame 				= NO_DRAG_TARGETS,
	FriendsFrame 			= NO_DRAG_TARGETS,
	PVPParentFrame 			= {"PVPBattlegroundFrame", "PVPFrame"},
	InspectFrame 			= {"InspectPVPFrame", "InspectTalentFrame", "InspectNameFrame"},
	AuctionFrame 			= NO_DRAG_TARGETS,
	TradeSkillFrame 		= NO_DRAG_TARGETS,
	MacroFrame 				= NO_DRAG_TARGETS,
	GossipFrame 			= NO_DRAG_TARGETS,
	TaxiFrame 				= NO_DRAG_TARGETS,
	MerchantFrame 			= NO_DRAG_TARGETS,
	ClassTrainerFrame 		= NO_DRAG_TARGETS,
	DressUpFrame 			= NO_DRAG_TARGETS,
	ContainerFrame1 		= NO_DRAG_TARGETS,
	ContainerFrame2 		= NO_DRAG_TARGETS,
	ContainerFrame3 		= NO_DRAG_TARGETS,
	ContainerFrame4 		= NO_DRAG_TARGETS,
	ContainerFrame5 		= NO_DRAG_TARGETS,
	Atr_Adv_Search_Dialog 	= NO_DRAG_TARGETS,
	Atr_Buy_Confirm_Frame 	= NO_DRAG_TARGETS,
	Atr_FullScanFrame 		= NO_DRAG_TARGETS,
	MailFrame 				= {"SendMailFrame"},
	BankFrame 				= NO_DRAG_TARGETS,
	TradeFrame 				= NO_DRAG_TARGETS,
	GuildBankFrame 			= NO_DRAG_TARGETS,
	ItemSocketingFrame 		= NO_DRAG_TARGETS,
	HelpFrame 				= NO_DRAG_TARGETS,
	StaticPopup1 			= NO_DRAG_TARGETS,
	LFDParentFrame 			= NO_DRAG_TARGETS
}
local scaleFrameNames = {
	"InspectModelFrame",
	"CharacterModelFrame",
	"DressUpModel"
}
if not DudesFlexFrames_Positions then DudesFlexFrames_Positions = {} end
if not DudesFlexFrames_Scales then DudesFlexFrames_Scales = {} end

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
	if frameName then 
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
	initDrag(frame, frame)
	initScale(frame, frame)

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

local function init()
	if not InCombatLockdown() then	
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

-- ADDON_LOADED is called for every Addon loaded first time, also internal ones
-- Thereby catching the creation of e.g. PlayerTalentFrame
DudesUtils.EventHandler.Add("ADDON_LOADED", init) 

-- PLAYER_REGEN_ENABLED in case we login infight
DudesUtils.EventHandler.Add("PLAYER_REGEN_ENABLED", init)

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