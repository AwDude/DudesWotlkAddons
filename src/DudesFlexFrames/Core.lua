DudesFlexFrames = DudesFlexFrames or {}
DudesFlexFrames_Positions = DudesFlexFrames_Positions or {}
DudesFlexFrames_Scales = DudesFlexFrames_Scales or {}
DudesFlexFrames_Settings = DudesFlexFrames_Settings or {}
DudesFlexFrames_CharacterSettings = DudesFlexFrames_CharacterSettings or {}

local NO_DRAG_TARGETS = {}
local DEFAULT_SETTINGS = {}
local flexFrameOptions = {}

local flexFrameNames = {
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
	LFDParentFrame 			        = NO_DRAG_TARGETS,
	LFDDungeonReadyPopup            = NO_DRAG_TARGETS,
    BarberShopFrame                 = NO_DRAG_TARGETS
}
local scaleFrameNames = {
	"InspectModelFrame",
	"CharacterModelFrame",
	"DressUpModel"
}

local function mergeDefaultSettings(settings)
	for key, value in pairs(DEFAULT_SETTINGS) do
		if settings[key] == nil then
			settings[key] = value
		end
	end
	return settings
end

local function getCharacterSettingsProfile()
	local realmName = GetRealmName and (GetRealmName() or "UnknownRealm") or "UnknownRealm"
	local characterName = UnitName and (UnitName("player") or "UnknownCharacter") or "UnknownCharacter"
	DudesFlexFrames_CharacterSettings[realmName] = DudesFlexFrames_CharacterSettings[realmName] or {}
	local realm = DudesFlexFrames_CharacterSettings[realmName]
	realm[characterName] = realm[characterName] or {
		useCharacterSettings = false,
		settings = {},
		positions = {},
		scales = {}
	}
	realm[characterName].settings = realm[characterName].settings or {}
	realm[characterName].positions = realm[characterName].positions or {}
	realm[characterName].scales = realm[characterName].scales or {}
	return realm[characterName]
end

local function getPositions()
	local profile = getCharacterSettingsProfile()
	return profile.useCharacterSettings and profile.positions or DudesFlexFrames_Positions
end

local function getScales()
	local profile = getCharacterSettingsProfile()
	return profile.useCharacterSettings and profile.scales or DudesFlexFrames_Scales
end

local function getSettings()
	mergeDefaultSettings(DudesFlexFrames_Settings)
	local profile = getCharacterSettingsProfile()
	if profile.useCharacterSettings then
		return mergeDefaultSettings(profile.settings)
	end
	return DudesFlexFrames_Settings
end

function DudesFlexFrames.GetSettings()
	return getSettings()
end

function DudesFlexFrames.UsesCharacterSpecificSettings()
	return getCharacterSettingsProfile().useCharacterSettings and true or false
end

function DudesFlexFrames.SetCharacterSpecificSettings(enabled)
	local profile = getCharacterSettingsProfile()
	enabled = enabled and true or false
	if profile.useCharacterSettings == enabled then
		return false
	end
	mergeDefaultSettings(DudesFlexFrames_Settings)
	profile.settings = DudesUtils.Table.Copy(DudesFlexFrames_Settings)
	profile.positions = DudesUtils.Table.Copy(DudesFlexFrames_Positions)
	profile.scales = DudesUtils.Table.Copy(DudesFlexFrames_Scales)
	profile.useCharacterSettings = enabled
	-- Existing Blizzard frames retain their position and scale after changing
	-- the backing profile. Reloading applies the selected profile consistently.
	if ReloadUI then
		ReloadUI()
	end
	return true
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
		getPositions()[name] = {point, relPoint, xOfs, yOfs}
	end
end

local function saveScale(frame)
	local name = frame:GetName()
	local scale = frame:GetScale()
	
	if name and scale then
		getScales()[name] = scale
	end
end


local function loadPosition(frame)
	local name = frame:GetName()
	local pos = name and getPositions()[name]
	
	if pos then
		frame:ClearAllPoints()
		frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	end
end

local function loadScale(frame)
	local name = frame:GetName()
	local scale = name and getScales()[name]

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

local function initFlex(frame, dragNames, options)
	options = options or {}
	if options.managePanel ~= false then
		disableBlizzardPanelManagement(frame:GetName())
	end
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:SetUserPlaced(true)
	loadScale(frame)
	loadPosition(frame)
	if options.directInteraction ~= false then
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

function DudesFlexFrames.RegisterFrame(frameName, dragNames, options)
	if not frameName then
		return false
	end
	flexFrameNames[frameName] = dragNames or NO_DRAG_TARGETS
	flexFrameOptions[frameName] = options or {}
	if not InCombatLockdown() then
		initFrame(frameName, function(frame)
			initFlex(frame, flexFrameNames[frameName], flexFrameOptions[frameName])
		end)
	end
	return true
end

local function init()
	if not InCombatLockdown() then
		for flexFrameName, dragNames in pairs(flexFrameNames) do
			initFrame(flexFrameName, function(frame)
				initFlex(frame, dragNames, flexFrameOptions[flexFrameName])
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
	local positions = getPositions()
	local scales = getScales()
	for key in pairs(positions) do
		positions[key] = nil
	end
	for key in pairs(scales) do
		scales[key] = nil
	end

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
