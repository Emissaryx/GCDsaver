-- WitchelfChecks.lua
WitchelfChecks = {}

function WitchelfChecks.isAbilityBlocked(actionId, currentMechanic, abilityData, stackCount)
    local currentMechanic = tonumber(GetCareerResource(GameData.BuffTargetType.SELF))
	
	-- Debug message to display the current mechanic value
    --d("Current Mechanic: " .. tostring(currentMechanic))
	
    -- Check for Witch Elf career mechanic block
    if currentMechanic <= 3 then
        if Emissary.Execution[actionId] then -- Check if the actionId is in the Emissary.Execution table located in the Emissary.Abilities.lua file
            if GCDsaver.Settings.ErrorMessages then
                GCDsaverAPI.alertText("Ability " .. tostring(actionId) .. " blocked due to insufficient career resource")
            end
            return true
        end
    end

    -- Add any other Witch Elf specific checks here...

    return false  -- Return false by default if none of the conditions are met
end
