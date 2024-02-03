-- ==========================
-- ===== Public members =====
-- ==========================

GCDsaverMatchMaking = {
    Loaded = false
}


-- ===========================
-- ===== Private members =====
-- ===========================

local IconId2ActionId = {}
local ActionId2IconId = {}
local PlayerAbilitiesTable = nil


-- ===========================
-- ===== Private methods =====
-- ===========================



-- ============================
-- ===== Internal methods =====
-- ============================

function GCDsaverMatchMaking.Initialize()

    RegisterEventHandler(SystemData.Events.PLAYER_NEW_ABILITY_LEARNED,      "GCDsaverMatchMaking.OnPlayerAbilitiesListUpdated" )
    RegisterEventHandler(SystemData.Events.PLAYER_NEW_PET_ABILITY_LEARNED,  "GCDsaverMatchMaking.OnPlayerAbilitiesListUpdated" )
    RegisterEventHandler(SystemData.Events.PLAYER_ABILITIES_LIST_UPDATED,   "GCDsaverMatchMaking.OnPlayerAbilitiesListUpdated" )
    
    RegisterEventHandler(SystemData.Events.PLAYER_INVENTORY_SLOT_UPDATED,   "GCDsaverMatchMaking.OnPlayerItemsListUpdated" )
    RegisterEventHandler(SystemData.Events.PLAYER_EQUIPMENT_SLOT_UPDATED,   "GCDsaverMatchMaking.OnPlayerItemsListUpdated" )
    

    GCDsaverMatchMaking.OnPlayerAbilitiesListUpdated()
    GCDsaverMatchMaking.OnPlayerItemsListUpdated()
    
    if PlayerAbilitiesTable then
        GCDsaverMatchMaking.Loaded = true
    end
    
    return GCDsaverMatchMaking.Loaded
end

-- Updates two tables that provide quick mapping between icon ids and action ids
function GCDsaverMatchMaking.OnPlayerAbilitiesListUpdated()

    PlayerAbilitiesTable = Player.GetAbilityTable(GameData.AbilityType.STANDARD)
    
    local ActionTables = {
        Player.GetAbilityTable(GameData.AbilityType.STANDARD),
        Player.GetAbilityTable(GameData.AbilityType.MORALE),
        Player.GetAbilityTable(GameData.AbilityType.TACTIC),
        Player.GetAbilityTable(GameData.AbilityType.GRANTED),
        Player.GetAbilityTable(GameData.AbilityType.PET),
        Player.GetAbilityTable(GameData.AbilityType.PASSIVE),
        Player.GetAbilityTable(GameData.AbilityType.GUILD)    
    }
    
    for _, actiontable in pairs(ActionTables) do
        for actionId, actionData in pairs(actiontable) do
            local iconNum = actionData.iconNum        
            ActionId2IconId[actionId] = iconNum
            IconId2ActionId[iconNum] = actionId
        end
    end
end

-- Updates two tables that provide quick mapping between icon ids and action ids
function GCDsaverMatchMaking.OnPlayerItemsListUpdated()

    local ItemTables = DataUtils.GetItems() 
    for _, itemTable in pairs(ItemTables) do
            local iconNum  = itemTable.iconNum  
            local actionId = itemTable.uniqueID             
            ActionId2IconId[actionId] = iconNum
            IconId2ActionId[iconNum] = actionId
    end
end


-- ==========================
-- ===== Public methods =====
-- ==========================


-- Retrieves an action id from an icon id
-- @param number effectIconId the effect to look up.
-- @return number theId the id of the action associated with the icon
-- TODO: some actions spawn effects with non-correating iconNums. May need
--       to add an exception list to deal with these in future
function GCDsaverMatchMaking.GetActionIdFromIconId(theId)
    if IconId2ActionId[theId] then
        return IconId2ActionId[theId]
    end
    return 0
end


-- Retrieves an icon id from an action id
-- @param number theId the action id to look up for its corresponding icon id.
-- @return number the id of the icon associated with the ability
function GCDsaverMatchMaking.getIconIdFromActionId(theId)
    if ActionId2IconId[theId] then
        return ActionId2IconId[theId]
    end
    return 0
end


-- @depecated
-- @see GCDsaverMatchMaking.GetActionIdFromEffect
function GCDsaverMatchMaking.GetAbilityIdFromEffect(effectData)
    return GCDsaverMatchMaking.GetActionIdFromIconId(effectData.iconNum)
end


