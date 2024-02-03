--[[
GCDsaverMemory deals with the storage of configuration
and cached action data.
]]--

-- ==========================
-- ===== Public members =====
-- ==========================

GCDsaverMemory = {
    Loaded     = false
}

-- ===========================
-- ===== Private members =====
-- ===========================

local nMp -- [p]layer bindings shortcut
local nMm -- [m]acro shortcut
local nMg -- [g]lobal config shortcut


-- ===========================
-- ===== Private methods =====
-- ===========================

local function deepcopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, _copy(getmetatable(object)))
    end
    return _copy(object)
end

function GCDsaverMemory.ResetCache()
  EA_ChatWindow.Print( L"Resetting GCDsaverButtons Cache" )
  GCDsaverMemory.buildActionDataCache()
end


-- ============================
-- ===== Internal methods =====
-- ============================

function GCDsaverMemory.Initialize()
    -- build cache
    if not GCDsaverMemory.actionDataCache then
        GCDsaverMemory.actionDataCache = {}
    end
    GCDsaverMemory.buildActionDataCache()
    
	-- build memory
	local ServerName = WStringToString(SystemData.Server.Name)
    local PlayerName = string.sub(WStringToString(GameData.Player.name), 1, -3)
	
	GCDsaverMemory.InitProfile()
    
    -- create global config table
    if not GCDsaverMemory.global then
        GCDsaverMemory.global = {}
    end
    nMg = GCDsaverMemory.global
    
    if not nMg.vcd then
        nMg.vcd = {}
    end
    
    if not nMg.dTarget then
        nMg.dTarget = {}
    end
    
    if not nMg.disabledDChecks then
        nMg.disabledDChecks = {}
    end
    
    if nMp and nMg and nMg.vcd and nMg.dTarget and nMg.disabledDChecks then
        GCDsaverMemory.Loaded = true
    end
    
    RegisterEventHandler(SystemData.Events.PLAYER_NEW_ABILITY_LEARNED,      "GCDsaverMemory.buildActionDataCache" )
    RegisterEventHandler(SystemData.Events.PLAYER_NEW_PET_ABILITY_LEARNED,  "GCDsaverMemory.buildActionDataCache" )
    RegisterEventHandler(SystemData.Events.PLAYER_ABILITIES_LIST_UPDATED,   "GCDsaverMemory.buildActionDataCache" )
    
    RegisterEventHandler(SystemData.Events.PLAYER_INVENTORY_SLOT_UPDATED,   "GCDsaverMemory.buildActionDataCache" )
    RegisterEventHandler(SystemData.Events.PLAYER_EQUIPMENT_SLOT_UPDATED,   "GCDsaverMemory.buildActionDataCache" )
    
    RegisterEventHandler(SystemData.Events.LOADING_END,      "GCDsaverMemory.buildActionDataCache" )    
    
    return GCDsaverMemory.Loaded
end

function GCDsaverMemory.InitProfile()
    if not GCDsaverMemory.profiles then
		GCDsaverMemory.profiles = {}
	end
	
	if not GCDsaverMemory.profiles.actual then
		GCDsaverMemory.profiles.actual = {}
	end
	
	if not GCDsaverMemory.profiles.current then
		GCDsaverMemory.profiles.current = {}
	end
    
    local ServerName = WStringToString(SystemData.Server.Name)
    local PlayerName = string.sub(WStringToString(GameData.Player.name), 1, -3)
    
    if not GCDsaverMemory.profiles.current[ServerName] then
        GCDsaverMemory.profiles.current[ServerName] = {}
    end
    if not GCDsaverMemory.profiles.current[ServerName][PlayerName] then
        GCDsaverMemory.profiles.current[ServerName][PlayerName] = GCDsaverMemory.CreateProfile(PlayerName.." @ "..ServerName)
    end
    
    GCDsaverMemory.SetupProfile()
end

function GCDsaverMemory.SetupProfile()
	-- update bindings
	if GCDsaverMemory.bindings then
		GCDsaverMemory.GetCurProfile().bindings = GCDsaverMemory.bindings
		GCDsaverMemory.bindings = nil
	end
	-- end update
    nMp = GCDsaverMemory.GetCurProfile().bindings
    
	-- update macros
	if GCDsaverMemory.macros then
		GCDsaverMemory.GetCurProfile().macros = GCDsaverMemory.macros
		GCDsaverMemory.macros = nil
	end
	-- end update
    nMm = GCDsaverMemory.GetCurProfile().macros
end

-- ==========================
-- ===== Public methods =====
-- ==========================

-- build a cache of all item and ability data
function GCDsaverMemory.buildActionDataCache()
    --d("NerfedButtons.buildActionDataCache()")
    GCDsaverMemory.actionDataCache = {}
    local dataTables = nil
    
    -- set hasAction status of all actions to false
    if GCDsaverMemory.actionDataCache ~= nil then
      for actionId, actionData in pairs(GCDsaverMemory.actionDataCache) do
        if GCDsaverMemory.actionDataCache[actionId] ~= nil then
          GCDsaverMemory.actionDataCache[actionId].hasAction = false
        end
      end
    end

    -- add items to cache
    if CharacterWindow then
        dataTables = {
            CharacterWindow.equipmentData,
            DataUtils.GetItems (),
            DataUtils.GetQuestItems ()
        }
    else 
        dataTables = {
            DataUtils.GetItems (),
            DataUtils.GetQuestItems ()
        }    
    end
    -- d(dataTables)
    for tableId, dataTable in ipairs (dataTables) do
        for _, actionData in pairs(dataTable) do
            actionData.actionType = "item"
            actionData.hasAction = true
	    actionData.petAbility = false
            GCDsaverMemory.setActionDataCache(actionData.uniqueID, actionData) 
        end
    end
    
    -- add abilities to the cache
    dataTables = {
        Player.GetAbilityTable(GameData.AbilityType.STANDARD),
        Player.GetAbilityTable(GameData.AbilityType.GUILD),
        Player.GetAbilityTable(GameData.AbilityType.MORALE),
        Player.GetAbilityTable(GameData.AbilityType.FIRST),
        Player.GetAbilityTable(GameData.AbilityType.GRANTED),
        Player.GetAbilityTable(GameData.AbilityType.TACTIC)
    } 
    for tableId, dataTable in ipairs (dataTables) do
        for actionId, actionData in pairs(dataTable) do
            actionData.actionType = "ability"
            actionData.hasAction = true
	    actionData.petAbility = false
            GCDsaverMemory.setActionDataCache(actionId, actionData) 
        end
    end
    
    dataTables = {
        Player.GetAbilityTable(GameData.AbilityType.PET)
    } 
    for tableId, dataTable in ipairs (dataTables) do
        for actionId, actionData in pairs(dataTable) do
            actionData.actionType = "ability"
            actionData.hasAction = true
	    actionData.petAbility = true
            GCDsaverMemory.setActionDataCache(actionId, actionData) 
        end
    end
    

end


-- ActionDataCache wipe method
function GCDsaverMemory.clearActionDataCache()
    GCDsaverMemory.actionDataCache = {}
end

-- ActionDataCache set method
function GCDsaverMemory.setActionDataCache(actionId, theData)
    GCDsaverMemory.actionDataCache[actionId] = theData
end

-- ActionDataCache get method
function GCDsaverMemory.getActionDataCache(actionId)
    return GCDsaverMemory.actionDataCache[actionId]
end


-- Character wipe method
function GCDsaverMemory.ClearCharacterConfig()
    GCDsaverMemory.profiles.actual[GCDsaverMemory.GetCurProfileNum()].profiles = {}
    GCDsaverMemory.profiles.actual[GCDsaverMemory.GetCurProfileNum()].macros = {}
end

-- Profiles methods
function GCDsaverMemory.GetCurProfileNum()
    local ServerName = WStringToString(SystemData.Server.Name)
    local PlayerName = string.sub(WStringToString(GameData.Player.name), 1, -3)
    
    return GCDsaverMemory.profiles.current[ServerName][PlayerName]
end
function GCDsaverMemory.GetCurProfile()
    return GCDsaverMemory.profiles.actual[GCDsaverMemory.GetCurProfileNum()]
end

function GCDsaverMemory.CreateProfile(description)
    local i = 1
    while GCDsaverMemory.profiles.actual[i] do i = i+1 end
    GCDsaverMemory.profiles.actual[i] = {desc = description, bindings = {}, macros = {}}
    
    return i
end
function GCDsaverMemory.CopyProfile(description)
    local i = 1
    while GCDsaverMemory.profiles.actual[i] do i = i+1 end
    GCDsaverMemory.profiles.actual[i] = deepcopy(GCDsaverMemory.GetCurProfile())
    GCDsaverMemory.profiles.actual[i].desc = description
    
    return i
end
function GCDsaverMemory.SetProfileDesc(description)
    GCDsaverMemory.GetCurProfile().desc = description
end
function GCDsaverMemory.GetProfileDesc()
    return GCDsaverMemory.GetCurProfile().desc
end
function GCDsaverMemory.SwitchProfile(profile)
    if not GCDsaverMemory.profiles.actual[profile] then
        return nil
    end
    
    local ServerName = WStringToString(SystemData.Server.Name)
    local PlayerName = string.sub(WStringToString(GameData.Player.name), 1, -3)
    
    GCDsaverMemory.profiles.current[ServerName][PlayerName] = profile
    
    GCDsaverMemory.SetupProfile()
    return true
end
function GCDsaverMemory.DeleteProfile(profile)
    if not GCDsaverMemory.profiles.actual[profile] then
        return nil
    end
   
    for server, playerTable in pairs(GCDsaverMemory.profiles.current) do
        for player, curProfile in pairs(playerTable) do
            if profile == curProfile then return player.." @ "..server end
        end
    end
    
    GCDsaverMemory.profiles.actual[profile] = nil
    return true
end
function GCDsaverMemory.ForceDeleteProfile(profile)
    if not GCDsaverMemory.profiles.actual[profile] or profile == GCDsaverMemory.GetCurProfileNum() then
        return nil
    end
   
    for server, playerTable in pairs(GCDsaverMemory.profiles.current) do
        for player, curProfile in pairs(playerTable) do
            if profile == curProfile then
                GCDsaverMemory.profiles.current[server][player] = nil
            end
        end
    end
    
    return GCDsaverMemory.DeleteProfile(profile)
end
function GCDsaverMemory.ListProfiles()
    profiles = {}
   
    for key, profile in pairs(GCDsaverMemory.profiles.actual) do
        profiles[key] = profile.desc
    end
    
    return profiles
end


-- Bindings methods
function GCDsaverMemory.SetBinding(slot, sequence)
    local valid = true
    if sequence == {} then
        sequence = nil
        valid = false
    end
    nMp[slot] = sequence
    
    GCDsaverEngine.VCDNeedUpdate = true
    return valid
end

function GCDsaverMemory.GetBindings()
    return nMp
end

function GCDsaverMemory.GetBinding(slot)
    return nMp[slot]
end

function GCDsaverMemory.ClearBinding(slot)
    return GCDsaverMemory.SetBinding(slot, nil)
end

-- VCD methods
function GCDsaverMemory.SetCareerwideVCD(abilityId, cooldown)
    if cooldown == 0 then
        cooldown = nil
    end
    nMg.vcd[abilityId] = cooldown
    
    GCDsaverEngine.VCDNeedUpdate = true
    return true
end

function GCDsaverMemory.GetCareerwideVCDs()
    return nMg.vcd
end

function GCDsaverMemory.GetCareerwideVCD(abilityId)
    return nMg.vcd[abilityId]
end

function GCDsaverMemory.ClearCareerwideVCD(abilityId)
    return GCDsaverMemory.SetCareerwideVCD(abilityId, 0)
end

function GCDsaverMemory.ClearCareerwideVCDs()
    nMg.vcd = {}
    
    GCDsaverEngine.VCDNeedUpdate = true
end

-- Default target methods
function GCDsaverMemory.SetDefaultTarget(abilityId, dTarget)
    if not dTarget then
        nMg.dTarget[abilityId] = nil
        return true
    end
    
    dTarget = tostring(dTarget)
    local valid = false
    for _, target in pairs(GCDsaverAPI.TARGET) do
        if dTarget == target then
            nMg.dTarget[abilityId] = target
            valid = true
        end
    end
    if not valid then
        nMg.dTarget[abilityId] = nil
    end
    
    return valid
end

function GCDsaverMemory.GetDefaultTargets()
    return nMg.dTarget
end

function GCDsaverMemory.GetDefaultTarget(abilityId)
    return nMg.dTarget[abilityId]
end

function GCDsaverMemory.ClearDefaultTarget(abilityId)
    return GCDsaverMemory.SetDefaultTarget(abilityId, nil)
end

function GCDsaverMemory.ClearDefaultTargets()
    nMg.dTarget = {}
end

-- AutoDismount methods
function GCDsaverMemory.SetAutoDismount(autoDismount)
    if autoDismount then
        nMg.autoDismount = true
    else
        nMg.autoDismount = nil
    end
end

function GCDsaverMemory.GetAutoDismount()
    return nMg.autoDismount
end

-- Disabledbuttons methods
function GCDsaverMemory.SetDisabledButtons(disabledButtons)
    if disabledButtons then
        nMg.disabledButton = true
    else
        nMg.disabledButton = nil
    end
end

function GCDsaverMemory.GetDisabledButtons()
    return nMg.disabledButton
end

-- Blankbuttons methods
function GCDsaverMemory.SetBlankButtons(blankButtons)
    if blankButtons then
        nMg.blankbutton = true
    else
        nMg.blankbutton = nil
    end
end

function GCDsaverMemory.GetBlankButtons()
    return nMg.blankbutton
end

-- ActionBar pages support methods
function GCDsaverMemory.SetPagesSupport(pageSupport)
    if pageSupport then
        nMg.pageSupport = true
    else
        nMg.pageSupport = nil
    end
end

function GCDsaverMemory.GetPagesSupport()
    return nMg.pageSupport
end

-- Full StayOnCast methods
function GCDsaverMemory.SetFullStayOnCast(fullSoc)
    if fullSoc then
        nMg.fullStayOnCast = true
    else
        nMg.fullStayOnCast = nil
    end
end

function GCDsaverMemory.GetFullStayOnCast()
    return nMg.fullStayOnCast
end

-- Macros methods
function GCDsaverMemory.SetMacro(slot, macro)
    if macro and (macro < 1 or macro > 42) then
        macro = nil
    end
    nMm[slot] = macro
end

function GCDsaverMemory.ClearMacro(slot)
    GCDsaverMemory.SetMacro(slot, nil)
end

function GCDsaverMemory.GetMacros()
    return nMm
end

function GCDsaverMemory.GetMacro(slot)
    return nMm[slot]
end

-- Disable default checks methods
function GCDsaverMemory.ToggleDisableDCheck(check, abilityId, disable)
    if nMg.disabledDChecks[abilityId] and nMg.disabledDChecks[abilityId][check] then
        nMg.disabledDChecks[abilityId][check] = nil
        if nMg.disabledDChecks[abilityId] == {} then
            nMg.disabledDChecks[abilityId] = nil
        end
    else
        if not nMg.disabledDChecks[abilityId] then
            nMg.disabledDChecks[abilityId] = {}
        end
        nMg.disabledDChecks[abilityId][check] = true
    end
end

function GCDsaverMemory.ClearDisableDCheck(abilityId)
    nMg.disabledDChecks[abilityId] = nil
end

function GCDsaverMemory.GetDisableDCheck(check, abilityId)
    return nMg.disabledDChecks[abilityId] and nMg.disabledDChecks[abilityId][check]
end

function GCDsaverMemory.GetDisableDChecks()
    return nMg.disabledDChecks
end