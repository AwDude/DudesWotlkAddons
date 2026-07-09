DudesUtils.EventHandler.Add("PLAYER_ENTERING_WORLD", function()
	local debuff = _G["DebuffButton1"]
	
	if not debuff then
		return
	end
	
    local name, type = GetInstanceInfo()

    if name == "Eiskronenzitadelle" and type == "raid" then
		debuff.__iccDebuffActive = true
		if not debuff.__iccDebuffHideHook then
			debuff:HookScript("OnShow", function()
				if debuff.__iccDebuffActive then
					debuff:Hide()
				end
			end)
			debuff.__iccDebuffHideHook = true
		end
		debuff:Hide()
	else
		debuff.__iccDebuffActive = nil
		debuff:Show()
    end
end)