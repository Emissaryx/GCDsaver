SwordmasterChecks = {}

function SwordmasterChecks.isAbilityBlocked(actionId, currentActionPoints, currentMechanic, abilityData, stackCount)
    local currentMechanic = tonumber(GetCareerResource(GameData.BuffTargetType.SELF))
	
    -- Check for Swordmaster career mechanic block
    if currentMechanic > 0 then
        if actionId == 9010 or actionId == 9002 or actionId == 9031 then
            --d("Blocking ability with Action ID " .. actionId .. " due to Swordmaster career mechanic (" .. currentMechanic .. ")")
            -- Logic for insufficient career resource
            return true
        end
    end
	
	    -- if actionId == 9010 or actionId == 9002 or actionId == 9031 and GCDsaverAPI.hasMechanic(1) then
        -- return true  -- blocks the ability if the current mechanic is more than 200
    -- end
	
	----------
	-- Check for Wrath of Hoeth on Hostile Target
 if (actionId == 9017) then
	if (GCDsaverAPI.hasBuff(GCDsaverAPI.getTargetType(abilityData.targetType), abilityData, stackCount) and not GetBuff(GCDsaverAPI.getTargetType(abilityData.targetType), abilityData.iconNum).castByPlayer) or GCDsaverAPI.hasBuff(GameData.BuffTargetType.TARGET_HOSTILE, abilityData, stackCount) then
	return true
	end
 end
 
    -- Check for ability IDs 9007 on yourself
    if actionId == 9007 then
        local abilityData = GetAbilityData(9007)  -- Fetching data for the current ability ID
        if GCDsaverAPI.hasBuff(GameData.BuffTargetType.SELF, abilityData, nil) then
            if GCDsaver.Settings.ErrorMessages then 
                GCDsaverAPI.alertText("Ability " .. tostring(actionId) .. " is blocked due to self buffs")
            end
            return true
        end
    end

-- Other checks can be added here if necessary

return false
end