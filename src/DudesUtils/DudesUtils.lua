DudesUtils = DudesUtils or {}
DudesUtils.Array = DudesUtils.Array or {}
DudesUtils.String = DudesUtils.String or {}
DudesUtils.EventHandler = DudesUtils.EventHandler or {}

local hiddenFrame = hiddenFrame or CreateFrame("Frame")
local nextUpdateCallbacks = {}
local eventHandlers = {}

hiddenFrame:SetScript("OnEvent", function(self, event, ...)
    if eventHandlers[event] then
        for eventHandler in pairs(eventHandlers[event]) do
            local ok, err = pcall(eventHandler, event, ...)
            if not ok then
                geterrorhandler()(err)
            end
        end
    end
end)

local function onUpdate()
    hiddenFrame:SetScript("OnUpdate", nil)
	
    local initialCount = #nextUpdateCallbacks
    for i = 1, initialCount do
        local ok, err = pcall(nextUpdateCallbacks[i])
        if not ok then
            geterrorhandler()(err)
        end
    end

	-- if DudesUtils.OnNextUpdate gets called inside a callback
    local remaining = #nextUpdateCallbacks - initialCount
    if remaining > 0 then
        for i = 1, remaining do
            nextUpdateCallbacks[i] = nextUpdateCallbacks[initialCount + i]
            nextUpdateCallbacks[initialCount + i] = nil
        end
        hiddenFrame:SetScript("OnUpdate", onUpdate)
    else
        table.wipe(nextUpdateCallbacks)
    end
end

-- -- -- -- -- -- -- -- EVENT HANDLER -- -- -- -- -- -- -- --

function DudesUtils.EventHandler.Add(event, handler)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        hiddenFrame:RegisterEvent(event)
    end
    eventHandlers[event][handler] = true
end

function DudesUtils.EventHandler.Remove(event, handler)
    if eventHandlers[event] then
        eventHandlers[event][handler] = nil
        if next(eventHandlers[event]) == nil then
            eventHandlers[event] = nil
            hiddenFrame:UnregisterEvent(event)
        end
    end
end

function DudesUtils.EventHandler.Clear()
    eventHandlers = {}
    hiddenFrame:UnregisterAllEvents()
end

-- -- -- -- -- -- -- -- STRING UTILS -- -- -- -- -- -- -- --

function DudesUtils.String.StartsWith(text, prefix)
   return string.sub(text, 1, string.len(prefix)) == prefix
end

-- -- -- -- -- -- -- -- ARRAY UTILS -- -- -- -- -- -- -- --

function DudesUtils.Array.Contains(array, value)
	for _, item in ipairs(array) do
		if item == value then
			return true
		end
	end
	return false
end

-- -- -- -- -- -- -- -- NEXT UPDATE -- -- -- -- -- -- -- --

function DudesUtils.OnNextUpdate(callback)
    table.insert(nextUpdateCallbacks, callback)
	if not hiddenFrame:GetScript("OnUpdate") then
        hiddenFrame:SetScript("OnUpdate", onUpdate)
    end
end
