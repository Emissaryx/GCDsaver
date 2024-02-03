-- IronbreakerChecks.lua
IronbreakerChecks = {}

function IronbreakerChecks.isAbilityBlocked(actionId, currentActionPoints, currentMechanic, abilityData, stackCount)
    local currentMechanic = tonumber(GetCareerResource(GameData.BuffTargetType.SELF))
		    -- Check for Iron Breaker career mechanic block
		if currentMechanic < 74 then
			if actionId == 1371 then
            -- Logic for insufficient career resource
            return true
			end
		end
		
		    -- Add a condition to block actionId 1373 if action points are above 50
		if actionId == 1373 then
			if currentActionPoints > 50 then
			-- Block this specific ability if action points are below 50
			return true
			end
		end

        -- Check for the buff on the target or SELF
		if (actionId == 1364 or actionId == 1357 or actionId == 1356) then
			if (GCDsaverAPI.hasBuff(GCDsaverAPI.getTargetType(abilityData.targetType), abilityData, stackCount) and not GetBuff(GCDsaverAPI.getTargetType(abilityData.targetType), abilityData.iconNum).castByPlayer) or GCDsaverAPI.hasBuff(GameData.BuffTargetType.SELF, abilityData, stackCount) then
			return true
			end
		end
    
    -- Return false by default if none of the conditions are met
    return false
end