-- BlackguardChecks.lua
BlackguardChecks = {}

function BlackguardChecks.isAbilityBlocked(actionId, currentActionPoints, currentMechanic, abilityData, stackCount)
    local currentMechanic = tonumber(GetCareerResource(GameData.BuffTargetType.SELF))
		    -- Check for Black Guard career mechanic block
		if currentMechanic < 74 then
			if actionId == 9329 then
            -- Logic for insufficient career resource
            return true
			end
		end
		
		-- Add a condition to block actionId 1373 if action points are above 50
		if actionId == 9319 then
			if currentActionPoints > 50 then
			-- Block this specific ability if action points are below 50
			return true
			end
		end

        -- Check for the buff on the target or SELF
        if (actionId == 3073 or actionId == 3480) and (GCDsaverAPI.hasBuff(getTargetType(abilityData.targetType), abilityData, stackCount) and not GetBuff(getTargetType(abilityData.targetType), abilityData.iconNum).castByPlayer) or GCDsaverAPI.hasBuff(GameData.BuffTargetType.SELF, abilityData, stackCount) then
            -- If all conditions are met, block the ability and show an alert if error messages are enabled
            return true
        end
    
    -- Return false by default if none of the conditions are met
    return false
end