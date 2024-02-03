
--[[
GCDsaverEngine acts as the core of the addon keeping track
of what effects and abilities are on you and your targets,
the position of your character and any virtual cooldowns.
]]--

-- ==========================
-- ===== Public members =====
-- ==========================

GCDsaverEngine = { 
    BARSLOT4TEST    = 118, -- bar slot used for cooldown tests
    
    TIME_DELAY      = .2,
    
    VCDNeedUpdate   = false,
    
    Loaded          = false,
    
    RunepriestZealotMechanic = false
}


-- ===========================
-- ===== Private members =====
-- ===========================

local Conditions      = {}
local Effects         = {}
local MountId         = 0

local VirtualCDowns   = {}
local GlobalCooldown  = 0

local AbilityCasting  = nil
local CastTime        = 0 -- Needed until game v1.2

local Position = {
    CurrentX = 0,
    CurrentY = 0,
    LastX = 0,
    LastY = 0,
    Moving = false
}

local TimeLeft = GCDsaverEngine.TIME_DELAY


----------------------------------------------------------------------------------------------------------------------
local function setupEffectsTable(target, id)
    -- create table or use previously created one
    if not Effects[target][id] then
        Effects[target][id] = {}
        Effects[target][id].name = ""
        Effects[target][id].actionId = 0
    end
    if not Effects[target][id].self then
        Effects[target][id].self = {}
        --Effects[target][id].self.duration = 0
        Effects[target][id].self.stackCount = 0
    end
    if not Effects[target][id].other then
        Effects[target][id].other = {}
        --Effects[target][id].self.duration = 0
        Effects[target][id].other.stackCount = 0
    end
end

-- text to chatlog
function GCDsaverEngine.Say(s)
    local str = towstring(s)
    TextLogAddEntry("Chat", SystemData.ChatLogFilters.SAY, str)
end

function GCDsaverEngine.lang(key)
    return nTl[key]
end

function GCDsaverEngine.SequenceParsing(sequenceString)
    return sequenceParsing(sequenceString)
end

function GCDsaverEngine.ListSequence(sequence)
    return listSequence(sequence)
end

local function buildEffectsAndConditions()

    -- start with a clean state
    Effects = {}
    
    Conditions = {}
    
    MountId = 0
    
    local allEffects = {}
    allEffects[GCDsaverAPI.TARGET.PLAYER] = GetBuffs( GameData.BuffTargetType.SELF )
    if NerfedAPI.hasFriend() then
        allEffects[GCDsaverAPI.TARGET.FRIEND] = GetBuffs( GameData.BuffTargetType.TARGET_FRIENDLY )
    end
    if NerfedAPI.hasEnemy() then
        allEffects[GCDsaverAPI.TARGET.ENEMY]  = GetBuffs( GameData.BuffTargetType.TARGET_HOSTILE )
    end

    for target, targetEffects in pairs(allEffects) do
        Effects[target] = {}
        Conditions[target] = {}
        for _, condition in pairs(GCDsaverAPI.CONDITIONS) do
            Conditions[target][condition] = false
        end

        for _, effect in pairs(targetEffects) do
        
            -- get effect id and actionid (which may be the same)
            local effectId = effect.abilityId
            local actionId = GCDsaverMatchMaking.GetActionIdFromIconId(effect.iconNum)
            
            -- create the default effects table structure for the target and action
            setupEffectsTable(target, effectId)
            
            if effect.castByPlayer then
                Effects[target][effectId].self.stackCount = Effects[target][effectId].self.stackCount + effect.stackCount

                if not effect.permanentUntilDispelled then
                    Effects[target][effectId].self.duration = effect.duration
                    Effects[target][effectId].other.duration = effect.duration
                end
            end
            Effects[target][effectId].other.stackCount  = Effects[target][effectId].other.stackCount  + effect.stackCount
            Effects[target][effectId].actionId = effectId
            Effects[target][effectId].name = effect.name
            
            if actionId~=effectId and actionId~=0 then
                setupEffectsTable(target, actionId)
                
                if effect.castByPlayer then
                    Effects[target][actionId].self.stackCount = Effects[target][actionId].self.stackCount + effect.stackCount

                    if not effect.permanentUntilDispelled then
                        Effects[target][actionId].self.duration = effect.duration
                        Effects[target][actionId].other.duration = effect.duration
                    end
                end
                Effects[target][actionId].other.stackCount  = Effects[target][actionId].other.stackCount  + effect.stackCount
                Effects[target][actionId].actionId = actionId
                Effects[target][actionId].name = effect.name
            end
            
            -- List based condition checks (see GCDsaverLists.lua for the actual lists)
            -- Snared condition ?
            if GCDsaverLists.snaredAbilities[actionId] then
                Conditions[target].isSnared = true
            end
            
            -- Rooted condition ?
            if GCDsaverLists.rootedAbilities[actionId] then
                Conditions[target].isRooted = true
            end
            
            -- Detaunted condition ?
            if GCDsaverLists.detauntedAbilities[actionId] then
                Conditions[target].isDetaunted = true
            end
            
            -- Mounted condition ?
            if GCDsaverLists.mountActions[actionId] then
                if target == 'p' then MountId=actionId end -- store the MountId
                Conditions[target].isMounted = true -- store the mounted condition against the target
            end
            
            -- loop through all available conditions and work out who has what
            for _, condition in pairs(GCDsaverAPI.CONDITIONS) do
                if effect[condition] then
                    Conditions[target][condition] = Conditions[target][condition] or effect[condition]
                end
            end
            
            -- Unstoppable condition
            local un = GCDsaverEngine.lang('Unstoppable')
            if wstring.match( effect.name, L"([^\^]+).*" ) == L""..un then
                Conditions[target].isUnstoppable = true
            end
            
            -- Immovable condition
            local im = GCDsaverEngine.lang('Immovable')
            if wstring.match( effect.name, L"([^\^]+).*" ) == L""..im then
                Conditions[target].isImmovable = true
            end
        end
        
        for actionId in pairs(Effects[target]) do
            if not Effects[target][actionId].self then Effects[target][actionId].self = 0 end
        end
    end
end

local function getVirtualCDown(abilityData)
    -- First try to get the VCD from the abilityData
    if abilityData.VirtualCooldown then
        local maxCd = 0
        for _, params in pairs(abilityData.VirtualCooldown) do
            local cd = params[GCDsaverAPI.PARAMS.cd]
            maxCd = math.max(cd, maxCd)
        end
        return maxCd
    end
    
    -- If none is defined in abilityData then get it from the career-wide VCDs
    return GCDsaverMemory.GetCareerwideVCD(abilityData[GCDsaverAPI.PARAMS.ability])
end

-- Reset virtual cooldowns
local function resetVirtualCDowns()
    VirtualCDowns = {}
    for _, sequence in pairs(GCDsaverMemory.GetBindings()) do
        for position, abilityData in pairs(sequence) do
            local abilityId = abilityData[GCDsaverAPI.PARAMS.ability]
            
            if not abilityId then
                continue
            end
            
            -- get the VCD if there is one
            local virtualCDown = getVirtualCDown(abilityData)
            
            if virtualCDown then
                if VirtualCDowns[abilityId] then
                    virtualCDown = math.max(virtualCDown, VirtualCDowns[abilityId].maxVCD)
                end
                VirtualCDowns[abilityId] = { maxVCD = virtualCDown, current = {} }
            end
        end
    end
end

-- Update virtual cooldowns
local function updateVirtualCDowns(elapsed)
    for abilityId, cooldownInfo in pairs(VirtualCDowns) do
        local maxVCD = cooldownInfo.maxVCD
        for targetId, currentVCD in pairs(cooldownInfo.current) do
            if currentVCD < maxVCD then
                currentVCD = currentVCD + elapsed
                if currentVCD >= maxVCD then
                   currentVCD = nil
                end
                VirtualCDowns[abilityId].current[targetId] = currentVCD
            end
        end
    end
end

-- Start virtual cooldown for an ability
local function startVirtualCDowns(abilityId, targetId)
    if VirtualCDowns[abilityId] then
        VirtualCDowns[abilityId].current[targetId] = 0
    end
end

-- Stop virtual cooldown for an ability
local function stopVirtualCDowns(abilityId, targetId)
    if VirtualCDowns[abilityId] then
        VirtualCDowns[abilityId].current[targetId] = nil
    end
end


-- ============================
-- ===== Internal methods =====
-- ============================
    
function GCDsaverEngine.Initialize()
    -- register event handler
    RegisterEventHandler(SystemData.Events.PLAYER_BEGIN_CAST, "GCDsaverEngine.OnPlayerBeginCast" )
    RegisterEventHandler(SystemData.Events.PLAYER_END_CAST, "GCDsaverEngine.OnPlayerEndCast" )
    RegisterEventHandler(SystemData.Events.WORLD_OBJ_COMBAT_EVENT, "GCDsaverEngine.OnCombatEvent")
    RegisterEventHandler(SystemData.Events.PLAYER_TARGET_UPDATED, "GCDsaverEngine.OnTargetUpdated")
    RegisterEventHandler(SystemData.Events.PLAYER_ABILITY_TOGGLED, "GCDsaverEngine.OnAbilityToggled" )
    RegisterEventHandler(SystemData.Events.PLAYER_CAST_TIMER_SETBACK, "GCDsaverEngine.OnSetbackCast")
    RegisterEventHandler(SystemData.Events.PLAYER_POSITION_UPDATED, "GCDsaverEngine.OnMove")
    RegisterEventHandler(SystemData.Events.LOADING_END, "GCDsaverEngine.OnLoading")
    RegisterEventHandler(SystemData.Events.RELOAD_INTERFACE, "GCDsaverEngine.OnLoading")

    resetVirtualCDowns()

    GCDsaverEngine.Loaded = true
    return GCDsaverEngine.Loaded
end

function GCDsaverEngine.OnLoading()
	if ActionBars.m_ActiveActions[1659] == true or ActionBars.m_ActiveActions[8550] == true then 
		RunepriestZealotMechanic = 1 
	else 
		RunepriestZealotMechanic = 0 
	end
end

function GCDsaverEngine.OnUpdate(elapsed)
    if not GCDsaverEngine.Loaded or not GCDsaverMemory.Loaded then
        return
    end

    -- Abilities cast time
    if CastTime > 0 then
        CastTime = CastTime - elapsed
        if CastTime <= 0 then
            CastTime = 0
            AbilityCasting = nil
            NerfedButtons.NeedUpdate = true
        end
    end
    
    -- update global cooldown
    if GlobalCooldown > 0 then
        GlobalCooldown = GlobalCooldown - elapsed
        if GlobalCooldown < 0 then
            GlobalCooldown = 0
        end
    end

    -- update virtual cooldowns
    updateVirtualCDowns(elapsed)
    
    -- update position
    if(Position.CurrentX ~= Position.LastX or Position.CurrentY ~= Position.LastY) then
        Position.LastX = Position.CurrentX
        Position.LastY = Position.CurrentY
        Position.Moving = true
    else
        Position.Moving = false
    end
    
    -- stop the code from eating up all CPU resources
    TimeLeft = TimeLeft - elapsed
    if TimeLeft > 0 then
        return -- cut out early
    end

    -- reset to TIME_DELAY seconds
    TimeLeft = GCDsaverEngine.TIME_DELAY
    
    if GCDsaverEngine.VCDNeedUpdate then
        resetVirtualCDowns()
        GCDsaverEngine.VCDNeedUpdate = false
    end
    
    buildEffectsAndConditions()
end


function GCDsaverEngine.OnMove(x, y)
    Position.CurrentX = x
    Position.CurrentY = y
end

--
function GCDsaverEngine.OnPlayerBeginCast(abilityId, isChannel, desiredCastTime, averageLatency)
    -- Current casting ability
    if (desiredCastTime > 0) then
        AbilityCasting = abilityId
        if GCDsaverMemory.GetFullStayOnCast() then
            CastTime = desiredCastTime + averageLatency
        else
            CastTime = 0.5
        end
    end
    
    -- Global CoolDown
    GlobalCooldown = 1.5
    
    -- Virtual Cooldown
    local target = GCDsaverAPI.GetDefaultTarget(abilityId)
    startVirtualCDowns(abilityId, GCDsaverAPI.GetTargetId(target))

end


--
function GCDsaverEngine.OnSetbackCast(newCastTime)
    if GCDsaverMemory.GetFullStayOnCast() and CastTime ~= 0 then
        CastTime = newCastTime
    end
end


--
function GCDsaverEngine.OnPlayerEndCast(interupt)
    if interupt and AbilityCasting then
        local target = GCDsaverAPI.GetDefaultTarget(AbilityCasting)
        stopVirtualCDowns(AbilityCasting, GCDsaverAPI.GetTargetId(target))
    end
    
    AbilityCasting = nil
    CastTime = 0

end

--
function GCDsaverEngine.OnCombatEvent(targetObjNum, eventMagnitude, eventType, abilityId)
    if abilityId ~= 0 and
	      (eventType == GameData.CombatEvent.BLOCK   or eventType == GameData.CombatEvent.PARRY   or
	       eventType == GameData.CombatEvent.EVADE   or eventType == GameData.CombatEvent.DISRUPT or
	       eventType == GameData.CombatEvent.ABSORB  or eventType == GameData.CombatEvent.IMMUNE) then
        local target = GCDsaverAPI.GetDefaultTarget(abilityId)
        stopVirtualCDowns(abilityId, GCDsaverAPI.GetTargetId(target))
    
    end
end

--
function GCDsaverEngine.OnAbilityToggled(abilityId, toggledOn)
	-- Runepriest and Zealot mechanic catch (may be a better way to do this...)
	if abilityId == 1659 or abilityId == 8550 then
		if toggledOn == true then
			RunepriestZealotMechanic = 1
		else
			RunepriestZealotMechanic = 0
		end
	end
    -- Virtual Cooldown
    if toggledOn then
        local target = GCDsaverAPI.GetDefaultTarget(abilityId)
        startVirtualCDowns(abilityId, GCDsaverAPI.GetTargetId(target))
    end
    
end

local lastTarget = 0
--
function GCDsaverEngine.OnTargetUpdated(targetClassification, targetId, targetType)
    if targetClassification == TargetInfo.FRIENDLY_TARGET and targetId ~= lastTarget then
        TimeLeft = 0
        lastTarget = targetId
    end
end


-- ==========================
-- ===== Public methods =====
-- ==========================

function GCDsaverEngine.AbilityBeingCast()
    return AbilityCasting
end

function GCDsaverEngine.PlayerMoving()
    return Position.Moving
end

--------------------------------------------------------------------------------

-------------------------------------------------------------------------------------
 
function GCDsaverEngine.OnVirtualCDown(actionId, vcd, target)
    if not VirtualCDowns[actionId] then return false end
    
    local targetId = GCDsaverAPI.GetTargetId(target)
    if not VirtualCDowns[actionId].current[targetId] then return false end
    
    return VirtualCDowns[actionId].current[targetId] < vcd - (GlobalCooldown + 0.1)
end

--
function GCDsaverEngine.GetEffects(target)
    if target then
        return Effects[target]
    end
    return Effects
end

--
function GCDsaverEngine.GetConditions(target)
    if target then
        return Conditions[target]
    end
    return Conditions
end

-- returns the mount action id for the player
function GCDsaverEngine.GetMountId()
    return MountId
end

-- RunepriestZealotMechanic hack
function GCDsaverEngine.getRunepriestZealotMechanic()
	return RunepriestZealotMechanic
end
