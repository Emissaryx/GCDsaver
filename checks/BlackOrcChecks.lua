BlackOrcChecks = {}

function BlackOrcChecks.isAbilityBlocked(actionId, currentActionPoints, currentMechanic, abilityData, stackCount)
    local currentMechanic = tonumber(GetCareerResource(GameData.BuffTargetType.SELF))
	
    -- Check for Black Orc career mechanic block
    if currentMechanic > 0 then
        if actionId == 1664 or actionId == 1667 or actionId == 1666 then
            --d("Blocking ability with Action ID " .. actionId .. " due to Black Orc career mechanic (" .. currentMechanic .. ")")
            -- Logic for insufficient career resource
            return true
        end
    end
	
	        -- Check for the buff on the target or SELF
		if actionId == 1667 or actionId == 1677 then
			if (GCDsaverAPI.hasBuff(GCDsaverAPI.getTargetType(abilityData.targetType), abilityData, stackCount) and not GetBuff(GCDsaverAPI.getTargetType(abilityData.targetType), abilityData.iconNum).castByPlayer) or GCDsaverAPI.hasBuff(GameData.BuffTargetType.SELF, abilityData, stackCount) then
			return true
			end
		end
	
	    -- if actionId == 9010 or actionId == 9002 or actionId == 9031 and GCDsaverAPI.hasMechanic(1) then
        -- return true  -- blocks the ability if the current mechanic is more than 200
    -- end
	
	----------
	-- Check for Wrath of Hoeth on Hostile Target
-- if (actionId == 9017) then
	-- if (GCDsaverAPI.hasBuff(GCDsaverAPI.getTargetType(abilityData.targetType), abilityData, stackCount) and not GetBuff(GCDsaverAPI.getTargetType(abilityData.targetType), abilityData.iconNum).castByPlayer) or GCDsaverAPI.hasBuff(GameData.BuffTargetType.TARGET_HOSTILE, abilityData, stackCount) then
	-- return true
	-- end
 -- end
 
  -- -- Check for self-targeted abilities
 -- if (actionId == 9007) then
	-- if (GCDsaverAPI.hasBuff(GCDsaverAPI.getTargetType(abilityData.targetType), abilityData, stackCount) and not GetBuff(GCDsaverAPI.getTargetType(abilityData.targetType), abilityData.iconNum).castByPlayer) or GCDsaverAPI.hasBuff(GameData.BuffTargetType.SELF, abilityData, stackCount) then
	-- return true
	-- end
 -- end
-------------------------

 -- Check for self-targeted abilities

-- Other checks can be added here if necessary

return false
end