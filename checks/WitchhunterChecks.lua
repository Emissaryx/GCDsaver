-- WitchhunterChecks.lua
WitchhunterChecks = {}

function WitchhunterChecks.isAbilityBlocked(actionId, currentMechanic, abilityData, stackCount)
    local currentMechanic = tonumber(GetCareerResource(GameData.BuffTargetType.SELF))
    -- Check for Witch Hunter career mechanic block
    if currentMechanic <= 3 then
        if Emissary.Execution[actionId] then -- Check if the actionId is in the Emissary.Execution table
            if GCDsaver.Settings.ErrorMessages then
                GCDsaverAPI.alertText("Ability " .. tostring(actionId) .. " blocked due to insufficient career resource")
            end
            return true
        end
    end

    -- Add any other Witch Hunter specific checks here...

    return false  -- Return false by default if none of the conditions are met
end
