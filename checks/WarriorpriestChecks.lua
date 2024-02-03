-- WarriorpriestChecks.lua
WarriorpriestChecks = {}

function WarriorpriestChecks.isAbilityBlocked(actionId, currentMechanic, abilityData, stackCount)
        local abilityData = GetAbilityData(actionId)		
		
     -- Check for specific Warrior Priest career mechanic block
		if currentMechanic > 200 and actionId == 8250 then
        -- Assuming you want to block this specific ability under certain conditions
			return true
		end
		
    -- Check for specific ability (ID 8271) on a hostile target
    if actionId == 8271 and GCDsaverAPI.hasHostileTarget() then
        local abilityData = GetAbilityData(8271)  -- Assuming GetAbilityData fetches data based on ability ID
        if GCDsaverAPI.hasBuff(GameData.BuffTargetType.TARGET_HOSTILE, abilityData, nil) then
            if GCDsaver.Settings.ErrorMessages then 
                GCDsaverAPI.alertText("Ability 8271 is blocked on hostile target")
            end
            return true
        end
    end
	
    -- Check for ability IDs 8253 and 8268 on yourself
    if actionId == 8253 or actionId == 8268 then
        local abilityData = GetAbilityData(actionId)  -- Fetching data for the current ability ID
        if GCDsaverAPI.hasBuff(GameData.BuffTargetType.SELF, abilityData, nil) then
            if GCDsaver.Settings.ErrorMessages then 
                GCDsaverAPI.alertText("Ability " .. tostring(actionId) .. " is blocked due to self buffs")
            end
            return true
        end
    end

			
    return false  -- Return false by default if none of the conditions are met
end