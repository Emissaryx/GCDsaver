-- Modifying the DiscipleChecks.lua
DiscipleChecks = {}

-- This function checks if an ability should be blocked based on various conditions.
function DiscipleChecks.isAbilityBlocked(actionId, currentMechanic, abilityData, stackCount)
    -- Retrieve updated ability data for the given actionId.
    local abilityData = GetAbilityData(actionId)

    -- Block ability 9566 if the resource is above 200.
    if currentMechanic > 200 and actionId == 9566 then
        return true
    end

    -- Add additional checks for other abilities as needed.

    -- Return false by default if none of the conditions are met.
    return false
end
