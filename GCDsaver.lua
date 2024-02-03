-- Local data
local VERSION = 1.24
local TIME_DELAY = 1.5
local timeLeft = TIME_DELAY
local MAX_STACK = 3
local IMMOVABLE = 4
local UNSTOPPABLE = 5
local CAREER_RESOURCE = 6
local MAX_BUTTONS = 60
local eventsRegistered = false
local loadingEnd = false

-- Localized functions
local pairs = pairs
local tostring = tostring
local towstring = towstring
local GetBuffs = GetBuffs
local GetHotbarCooldown = GetHotbarCooldown
local GetAbilityData = GetAbilityData
local GetHotbarData = GetHotbarData
local BroadcastEvent = BroadcastEvent
local TextLogAddEntry = TextLogAddEntry
local RegisterEventHandler = RegisterEventHandler
local UnregisterEventHandler = UnregisterEventHandler

--Local functions

-- Define this near the top of your gcdsaver.lua or in an appropriate place
local CareerCheckFunctions = {
    [GameData.CareerLine.SWORDMASTER] = SwordmasterChecks.isAbilityBlocked,
    [GameData.CareerLine.WITCH_HUNTER] = WitchhunterChecks.isAbilityBlocked,
    [GameData.CareerLine.WITCH_ELF] = WitchelfChecks.isAbilityBlocked,
    [GameData.CareerLine.IRON_BREAKER] = IronbreakerChecks.isAbilityBlocked,
	[GameData.CareerLine.BLACKGUARD] = BlackguardChecks.isAbilityBlocked,
	[GameData.CareerLine.BLACK_ORC] = BlackOrcChecks.isAbilityBlocked,
	[GameData.CareerLine.DISCIPLE] = DiscipleChecks.isAbilityBlocked,
	[GameData.CareerLine.WARRIOR_PRIEST] = WarriorpriestChecks.isAbilityBlocked
    -- Add other careers as necessary
}

local function isAbilityBlocked(actionId, slot)
        if GCDsaver.Settings.DebugMessages then
            -- Debug message for any target update
            d("[GCDsaver] Checking if ability is blocked for ID: " .. tostring(actionId))
        end

    if GCDsaver.Settings.Enabled and not GCDsaver.Settings.DisableSlotChecks[slot] then
        local abilityData = GetAbilityData(actionId)
        local stackCount = GCDsaver.Settings.Abilities[actionId] or 1
        local currentMechanic = tonumber(GetCareerResource( GameData.BuffTargetType.SELF ))
        local myCareer = GameData.Player.career.line
        local currentActionPoints = GameData.Player.actionPoints.current

        -- Use the career function map for a clean lookup
        local checkFunction = CareerCheckFunctions[myCareer]
        if checkFunction and checkFunction(actionId, currentActionPoints, currentMechanic, abilityData, stackCount) then
            return true  
        end
		
		-- Snare Checks
		if GCDsaverAPI.hasSnareBuffOnHostileTarget() and Emissary.Snares[actionId] then
		return true
		end

        if GCDsaver.TargetImmovable and GCDsaver.Settings.Abilities[actionId] and GCDsaver.Settings.Abilities[actionId] == IMMOVABLE then
            return true
        elseif GCDsaver.TargetUnstoppable and GCDsaver.Settings.Abilities[actionId] and GCDsaver.Settings.Abilities[actionId] == UNSTOPPABLE then
            return true
		elseif GCDsaver.Settings.Abilities[actionId] and GCDsaver.Settings.Abilities[actionId] == CAREER_RESOURCE then
			local resources = GetCareerResource(GameData.BuffTargetType.SELF)
			if resources == nil or tonumber(resources) < GCDsaver.Settings.MaxResources then
				return true
			end
        elseif GCDsaver.Settings.Abilities[actionId] and GCDsaverAPI.hasBuff(GCDsaverAPI.getTargetType(abilityData.targetType), abilityData, GCDsaver.Settings.Abilities[actionId]) then
            return true
        else
            return false
        end
    else
        return false
    end
end


-- Block WindowGameAction
local orgWindowGameAction = WindowGameAction
local function blockedWindowGameAction(windowName)
	-- Do nothing
end

-- GCDsaver
GCDsaver = GCDsaver or {}
GCDsaver.FriendlyTargetId = 0
GCDsaver.HostileTargetId = 0
GCDsaver.TargetImmovable = false
GCDsaver.TargetUnstoppable = false
GCDsaver.SelfTargetEffects = {}
GCDsaver.FriendlyTargetEffects = {}
GCDsaver.HostileTargetEffects = {}
GCDsaver.EnabledStatesNeedUpdate = true -- Throttle calls to GCDsaver.UpdateButtonsEnabledStates()
GCDsaver.CheckResources = true
GCDsaver.ButtonIconsNeedUpdate = true -- Throttle calls to GCDsaver.UpdateButtonIcons()

GCDsaver.DefaultSettings = {
	Version = VERSION,
	Enabled = true,
	Symbols = true,
	ErrorMessages = true,
	BlockPlayerBuffs = false,          -- New setting for blocking player buffs
    BlockFriendlyBuffs = false,        -- New setting for blocking friendly buffs
    BlockHostileBuffs = false,         -- New setting for blocking hostile buffs
	DebugMessages = false,
	Abilities = {
		-- Ironbreaker
		[1384] = UNSTOPPABLE,	-- Cave-In
		[1369] = UNSTOPPABLE,	-- Shield of Reprisal
		[1365] = IMMOVABLE,		-- Away With Ye
		-- Slayer
		[1443] = UNSTOPPABLE,	-- Incapacitate
		-- Runepriest
		[1613] = UNSTOPPABLE,	-- Rune of Binding
		[1607] = UNSTOPPABLE,	-- Spellbinding Rune
		-- Engineer
		[1536] = UNSTOPPABLE,	-- Crack Shot
		[1531] = IMMOVABLE,		-- Concussion Grenade
		-- Black Orc
		[1688] = UNSTOPPABLE,	-- Down Ya Go
		[1683] = UNSTOPPABLE,	-- Shut Yer Face
		-- Choppa
		[1755] = UNSTOPPABLE,	-- Sit Down!
		-- Shaman
		[1929] = IMMOVABLE,		-- Geddoff!
		[1917] = UNSTOPPABLE,	-- You Got Nuthin!
		-- Squig Herder
		[1839] = UNSTOPPABLE,	-- Choking Arrer
		[1837] = UNSTOPPABLE,	-- Drop That!!
		[1835] = UNSTOPPABLE,	-- Not So Fast!
		-- Witch Hunter
		[8110] = UNSTOPPABLE,	-- Dragon Gun
		[8086] = UNSTOPPABLE,	-- Confess!
		[8115] = UNSTOPPABLE,	-- Pistol Whip
		[8100] = UNSTOPPABLE,	-- Silence The Heretic
		[8094] = UNSTOPPABLE,	-- Declare Anathema
		-- Knight of the Blazing Sun
		[8018] = UNSTOPPABLE,	-- Smashing Counter
		[8017] = IMMOVABLE,		-- Repel Darkness
		-- Bright Wizard
		[8186] = UNSTOPPABLE,	-- Stop, Drop, and Roll
		[8174] = UNSTOPPABLE,	-- Choking Smoke
		-- Warrior Priest
		[8256] = UNSTOPPABLE,	-- Vow of Silence
		-- Chosen
		[8346] = UNSTOPPABLE,	-- Downfall
		[8329] = IMMOVABLE,		-- Repel
		-- Marauder
		[8412] = UNSTOPPABLE,	-- Mutated Energy
		[8405] = UNSTOPPABLE,	-- Death Grip
		[8410] = IMMOVABLE,		-- Terrible Embrace
		-- Zealot
		[8571] = UNSTOPPABLE,	-- Aethyric Shock
		[8565] = UNSTOPPABLE,	-- Tzeentch's Lash
		-- Magus
		[8495] = UNSTOPPABLE,	-- Perils of The Warp
		[8483] = IMMOVABLE,		-- Warping Blast
		-- Swordmaster
		[9032] = IMMOVABLE,		-- Redirected Force
		-- [9030] = UNSTOPPABLE,	-- Whispering Window
		[9028] = UNSTOPPABLE,	-- Chrashing Wave
		-- Shadow Warrior
		[9096] = UNSTOPPABLE,	-- Eye Shot
		[9108] = UNSTOPPABLE,	-- Exploit Weakness
		[9098] = UNSTOPPABLE,	-- Opportunistic Strike
		-- White Lion
		[9193] = UNSTOPPABLE,	-- Brutal Pounce
		[9177] = UNSTOPPABLE,	-- Throat Bite
		[9178] = IMMOVABLE,		-- Fetch!
		-- Archmage
		[9266] = IMMOVABLE,		-- Cleansing Flare
		[9253] = UNSTOPPABLE,	-- Law of Gold
		-- Blackguard
		[2888] = UNSTOPPABLE,	-- Malignant Strike!
		[9321] = UNSTOPPABLE,	-- Spiteful Slam
		[9328] = IMMOVABLE,		-- Exile
		-- Witch Elf
		[9422] = UNSTOPPABLE,	-- On Your Knees!
		[9400] = UNSTOPPABLE,	-- Sever Limb
		[9427] = UNSTOPPABLE,	-- Heart Seeker
		[9409] = UNSTOPPABLE,	-- Throat Slitter
		[9396] = UNSTOPPABLE,	-- Agile Escape
		-- Disciple of Khaine
		[9565] = UNSTOPPABLE,	-- Consume Thought
		-- Sorcerer
		[9482] = UNSTOPPABLE,	-- Frostbite
		[9489] = UNSTOPPABLE,	-- Stricken Voices
	},
	DisableSlotChecks = {},
	MaxResources = 5
}

function GCDsaver.Initialize()
--GCDsaver.DebugObject(SystemData)

	-- No old settings use default settings
	if not GCDsaver.Settings then
		GCDsaver.Settings = GCDsaver.DefaultSettings
	
	-- Import old settings
	elseif GCDsaver.Settings then
		GCDsaver.Settings.Version = GCDsaver.DefaultSettings.Version
		GCDsaver.Settings.Enabled = GCDsaver.Settings.Enabled or GCDsaver.DefaultSettings.Enabled
		GCDsaver.Settings.Symbols = GCDsaver.Settings.Symbols or GCDsaver.DefaultSettings.Symbols
		GCDsaver.Settings.ErrorMessages = GCDsaver.Settings.ErrorMessages or GCDsaver.DefaultSettings.ErrorMessages
		GCDsaver.Settings.Abilities = GCDsaver.Settings.Abilities or GCDsaver.DefaultSettings.Abilities
		GCDsaver.Settings.DisableSlotChecks = GCDsaver.Settings.DisableSlotChecks or GCDsaver.DefaultSettings.DisableSlotChecks
		-- Changed below here
		-- Initialize new settings
        GCDsaver.Settings.BlockPlayerBuffs = GCDsaver.Settings.BlockPlayerBuffs or GCDsaver.DefaultSettings.BlockPlayerBuffs
        GCDsaver.Settings.BlockFriendlyBuffs = GCDsaver.Settings.BlockFriendlyBuffs or GCDsaver.DefaultSettings.BlockFriendlyBuffs
        GCDsaver.Settings.BlockHostileBuffs = GCDsaver.Settings.BlockHostileBuffs or GCDsaver.DefaultSettings.BlockHostileBuffs
		-- Changed Above here
	end

	if not GCDsaver.Settings.MaxResources then
		if GameData.Player.career.line == GameData.CareerLine.CHOPPA or GameData.Player.career.line == GameData.CareerLine.SLAYER then
			GCDsaver.Settings.MaxResources = 65
		else
			GCDsaver.Settings.MaxResources = 5
		end
	end
	
	LibSlash.RegisterSlashCmd("GCDsaver", function(input) GCDsaver_Config.Slash(input) end)
	LibSlash.RegisterSlashCmd("gcdsaverdebug", function(input) GCDsaver.ToggleDebugMessages() end)
	
	if GCDsaver.Settings.Enabled then GCDsaver.RegisterEvents()	end
	
	TextLogAddEntry("Chat", 0, towstring("<icon57> GCDsaver loaded. Type /GCDsaver for settings."))
end

function GCDsaver.DebugObject(obj, objName)
	if (obj == nil)
	then
		return
	end
	d("--------------------")
	if (objName ~= nil)
	then
		d("object name=" .. tostring(objName))
	end
	for name, val in pairs(obj) do
		d("  name=" .. tostring(name) .. ", value=" .. tostring(val))
	end
end

function GCDsaver.OnShutdown()
	GCDsaver.UnregisterEvents()
end

function GCDsaver.RegisterEvents()
	if not eventsRegistered then
		RegisterEventHandler(SystemData.Events.ENTER_WORLD, "GCDsaver.ENTER_WORLD")
		RegisterEventHandler(SystemData.Events.PLAYER_ZONE_CHANGED, "GCDsaver.PLAYER_ZONE_CHANGED")
		RegisterEventHandler(SystemData.Events.INTERFACE_RELOADED, "GCDsaver.INTERFACE_RELOADED")
		RegisterEventHandler(SystemData.Events.PLAYER_TARGET_UPDATED, "GCDsaver.PLAYER_TARGET_UPDATED")
		RegisterEventHandler(SystemData.Events.PLAYER_TARGET_IS_IMMUNE_TO_MOVEMENT_IMPARING, "GCDsaver.PLAYER_TARGET_IS_IMMUNE_TO_MOVEMENT_IMPARING")
		RegisterEventHandler(SystemData.Events.PLAYER_TARGET_IS_IMMUNE_TO_DISABLES, "GCDsaver.PLAYER_TARGET_IS_IMMUNE_TO_DISABLES")
		RegisterEventHandler(SystemData.Events.PLAYER_EFFECTS_UPDATED, "GCDsaver.PLAYER_EFFECTS_UPDATED")
		RegisterEventHandler(SystemData.Events.PLAYER_TARGET_EFFECTS_UPDATED, "GCDsaver.PLAYER_TARGET_EFFECTS_UPDATED")
		RegisterEventHandler(SystemData.Events.PLAYER_CAREER_RESOURCE_UPDATED, "GCDsaver.PLAYER_CAREER_RESOURCE_UPDATED")
		RegisterEventHandler(SystemData.Events.PLAYER_HOT_BAR_UPDATED, "GCDsaver.PLAYER_HOT_BAR_UPDATED")
		RegisterEventHandler(SystemData.Events.PLAYER_HOT_BAR_PAGE_UPDATED, "GCDsaver.PLAYER_HOT_BAR_PAGE_UPDATED")
	end
	eventsRegistered = true
end

function GCDsaver.UnregisterEvents()
	if eventsRegistered then
		UnregisterEventHandler(SystemData.Events.ENTER_WORLD, "GCDsaver.ENTER_WORLD")
		UnregisterEventHandler(SystemData.Events.PLAYER_ZONE_CHANGED, "GCDsaver.PLAYER_ZONE_CHANGED")
		UnregisterEventHandler(SystemData.Events.INTERFACE_RELOADED, "GCDsaver.INTERFACE_RELOADED")
		UnregisterEventHandler(SystemData.Events.PLAYER_TARGET_UPDATED, "GCDsaver.PLAYER_TARGET_UPDATED")
		UnregisterEventHandler(SystemData.Events.PLAYER_TARGET_IS_IMMUNE_TO_MOVEMENT_IMPARING, "GCDsaver.PLAYER_TARGET_IS_IMMUNE_TO_MOVEMENT_IMPARING")
		UnregisterEventHandler(SystemData.Events.PLAYER_TARGET_IS_IMMUNE_TO_DISABLES, "GCDsaver.PLAYER_TARGET_IS_IMMUNE_TO_DISABLES")
		UnregisterEventHandler(SystemData.Events.PLAYER_EFFECTS_UPDATED, "GCDsaver.PLAYER_EFFECTS_UPDATED")
		UnregisterEventHandler(SystemData.Events.PLAYER_TARGET_EFFECTS_UPDATED, "GCDsaver.PLAYER_TARGET_EFFECTS_UPDATED")
		UnRegisterEventHandler(SystemData.Events.PLAYER_CAREER_RESOURCE_UPDATED, "GCDsaver.PLAYER_CAREER_RESOURCE_UPDATED")
		UnregisterEventHandler(SystemData.Events.PLAYER_HOT_BAR_UPDATED, "GCDsaver.PLAYER_HOT_BAR_UPDATED")
		UnRegisterEventHandler(SystemData.Events.PLAYER_HOT_BAR_PAGE_UPDATED, "GCDsaver.PLAYER_HOT_BAR_PAGE_UPDATED")
	end
	eventsRegistered = false
end

-- Event handlers
function GCDsaver.ENTER_WORLD()
	loadingEnd = true
	GCDsaver.ButtonIconsNeedUpdate = true
end

function GCDsaver.PLAYER_ZONE_CHANGED()
	loadingEnd = true
	GCDsaver.ButtonIconsNeedUpdate = true
end

function GCDsaver.INTERFACE_RELOADED()
	loadingEnd = true
	GCDsaver.ButtonIconsNeedUpdate = true
end

function GCDsaver.ToggleDebugMessages()
    GCDsaver.Settings.DebugMessages = not GCDsaver.Settings.DebugMessages
    local state = GCDsaver.Settings.DebugMessages and "ON" or "OFF"
    TextLogAddEntry("Chat", 0, towstring("Debug messages are now " .. state))
end

function GCDsaver.PLAYER_TARGET_UPDATED(targetClassification, targetId, targetType)
    -- Ignore mouseover target changes
    if targetClassification ~= "mouseovertarget" then
        if GCDsaver.Settings.DebugMessages then
            -- Debug message for any target update
			d("PLAYER_TARGET_UPDATED: targetClassification = " .. targetClassification .. ", targetId = " .. targetId .. ", targetType = " .. targetType)
        end

        if targetClassification == TargetInfo.FRIENDLY_TARGET and GCDsaver.FriendlyTargetId ~= targetId then
            GCDsaver.FriendlyTargetId = targetId
            GCDsaver.FriendlyTargetEffects = {}
            GCDsaver.TargetImmovable = false
            GCDsaver.TargetUnstoppable = false
            GCDsaver.EnabledStatesNeedUpdate = true
            
            -- Debug message for friendly target update
            if GCDsaver.Settings.DebugMessages then
                d("Friendly target updated. ID: " .. targetId)
            end
            
        elseif targetClassification == TargetInfo.HOSTILE_TARGET and GCDsaver.HostileTargetId ~= targetId then
            -- Added check to skip hostile target updates if BlockHostileBuffs is enabled
            if GCDsaver.Settings.BlockHostileBuffs then
                -- Debug message for blocked hostile target update
                if GCDsaver.Settings.DebugMessages then
                    d("Hostile target update skipped due to settings. ID: " .. targetId)
                end
                return  -- Early return to skip processing the hostile target
            end

            GCDsaver.HostileTargetId = targetId
            GCDsaver.HostileTargetEffects = {}
            GCDsaver.TargetImmovable = false
            GCDsaver.TargetUnstoppable = false
            GCDsaver.EnabledStatesNeedUpdate = true
            
            -- Debug message for hostile target update
            if GCDsaver.Settings.DebugMessages then
                d("Hostile target updated. ID: " .. targetId)
            end
        end
    end
end


function GCDsaver.PLAYER_TARGET_IS_IMMUNE_TO_DISABLES(state)
	GCDsaver.TargetUnstoppable = state
	GCDsaver.EnabledStatesNeedUpdate = true
end

function GCDsaver.PLAYER_TARGET_IS_IMMUNE_TO_MOVEMENT_IMPARING(state)
	GCDsaver.TargetImmovable = state
	GCDsaver.EnabledStatesNeedUpdate = true
end

function GCDsaver.PLAYER_CAREER_RESOURCE_UPDATED(previous, resources)
	GCDsaver.CheckResources = true
end

function GCDsaver.PLAYER_EFFECTS_UPDATED(updatedEffects, isFullList)
	-- Changed below here
   -- Skip updating player effects if "Block Player Buffs" is enabled
    if GCDsaver.Settings.BlockPlayerBuffs then
        return
    end
	-- Changed Above here
	if not updatedEffects then return end
	for k, v in pairs(updatedEffects) do
		if v.castByPlayer then
			GCDsaver.SelfTargetEffects[k] = v.abilityId
			GCDsaver.EnabledStatesNeedUpdate = true
		elseif GCDsaver.SelfTargetEffects[k] then
			GCDsaver.SelfTargetEffects[k] = nil
			GCDsaver.EnabledStatesNeedUpdate = true
		end
	end
end

function GCDsaver.PLAYER_TARGET_EFFECTS_UPDATED(updateType, updatedEffects, isFullList)
    if not updatedEffects then
        d("No updated effects.")
        return
    end
    
    -- Skipping buff checks and storage for hostile target based on settings
    if updateType == GameData.BuffTargetType.TARGET_HOSTILE and GCDsaver.Settings.BlockHostileBuffs then
			if GCDsaver.Settings.DebugMessages then
			d("Skipping hostile target buff checks and storage.")
			end
        GCDsaver.HostileTargetEffects = {}  -- Clearing any existing hostile target effects
        return
    end
	
    -- Skipping buff checks and storage for friendly target based on settings
    if updateType == GameData.BuffTargetType.TARGET_FRIENDLY and GCDsaver.Settings.BlockFriendlyBuffs then
			if GCDsaver.Settings.DebugMessages then
			d("Skipping friendly target buff checks and storage.")
			end
        GCDsaver.FriendlyTargetEffects = {}  -- Clearing any existing friendly target effects
        return
    end

    -- Processing effects
    for k, v in pairs(updatedEffects) do
        if updateType == GameData.BuffTargetType.TARGET_HOSTILE then
				if GCDsaver.Settings.DebugMessages then
				d("Processing hostile target effect: " .. tostring(v.abilityId))
				end
            -- Effect cast by player applied on hostile target
            if v.castByPlayer then
                GCDsaver.HostileTargetEffects[k] = v.abilityId
                GCDsaver.EnabledStatesNeedUpdate = true
            -- Effect cast by player removed from hostile target
            elseif GCDsaver.HostileTargetEffects[k] then
                GCDsaver.HostileTargetEffects[k] = nil
                GCDsaver.EnabledStatesNeedUpdate = true
            end
        elseif updateType == GameData.BuffTargetType.TARGET_FRIENDLY then
				if GCDsaver.Settings.DebugMessages then
				d("Processing friendly target effect: " .. tostring(v.abilityId))
				end
            -- Effect cast by player applied on friendly target
            if v.castByPlayer then
                GCDsaver.FriendlyTargetEffects[k] = v.abilityId
                GCDsaver.EnabledStatesNeedUpdate = true
            -- Effect cast by player removed from friendly target
            elseif GCDsaver.FriendlyTargetEffects[k] then
                GCDsaver.FriendlyTargetEffects[k] = nil
                GCDsaver.EnabledStatesNeedUpdate = true
            end
        end
    end
end


function GCDsaver.PLAYER_HOT_BAR_PAGE_UPDATED(...)
		if GCDsaver.Settings.DebugMessages then
		d("PLAYER_HOT_BAR_PAGE_UPDATED")
		end
	GCDsaver.ButtonIconsNeedUpdate = true
end

function GCDsaver.PLAYER_HOT_BAR_UPDATED(slot, actionType, actionId)
			if GCDsaver.Settings.DebugMessages then
			d("PLAYER_HOT_BAR_UPDATED(" .. tostring(slot) .. "," .. tostring(actionType) .. "," .. tostring(actionId) .. ")")
			end
	--local hbar, buttonid
	--hbar, buttonid = ActionBars:BarAndButtonIdFromSlot(slot)
	--if actionType == 0 or buttonid ~= actionId then
		--d("Clear disable for slot " .. tostring(slot))
		--GCDsaver.Settings.DisableSlotChecks[slot] = nil
	--end
	GCDsaver.UpdateButtonIcon(slot, GCDsaver.Settings.Abilities[actionId])
	GCDsaver.UpdateButtonEnabledState(slot)
end

-- Main update function
function GCDsaver.OnUpdate(elapsed)
	if not loadingEnd then return end
	if not GCDsaver.Settings.Enabled then return end
	
	timeLeft = timeLeft - elapsed
	if timeLeft > 0 then
		return
	end
	timeLeft = TIME_DELAY
	
	if GCDsaver.ButtonIconsNeedUpdate then
		GCDsaver.UpdateButtonIcons()
		GCDsaver.ButtonIconsNeedUpdate = false
	end
	
	local updateButtons = false
	if GCDsaver.EnabledStatesNeedUpdate then
		updateButtons = true
		GCDsaver.EnabledStatesNeedUpdate = false
	end

	if GCDsaver.CheckResources then
		local resources = tonumber(GetCareerResource(GameData.BuffTargetType.SELF) or "0")
		if resources >= GCDsaver.Settings.MaxResources then
			updateButtons = true
		end
		GCDsaver.CheckResources = false
	end

	if updateButtons then
		GCDsaver.UpdateButtonsEnabledStates()
	end
end


function GCDsaver.UpdateSettings()
	if GCDsaver.Settings.Enabled and not eventsRegistered then
		GCDsaver.RegisterEvents()
	elseif not GCDsaver.Settings.Enabled and eventsRegistered then
		GCDsaver.UnregisterEvents()
	end
	
	GCDsaver.UpdateButtonIcons()

	TextLogAddEntry("Chat", 0, towstring("GCDsaver v" .. tostring(GCDsaver.Settings.Version) .. " settings: /gcdsaver"))
	if GCDsaver.Settings.Enabled then
		TextLogAddEntry("Chat", 0, L"--- <icon57> Enabled")
	else
		TextLogAddEntry("Chat", 0, L"--- <icon58> Enabled")
	end
	if GCDsaver.Settings.Symbols then
		TextLogAddEntry("Chat", 0, L"--- <icon57> Show Symbols")
	else
		TextLogAddEntry("Chat", 0, L"--- <icon58> Show Symbols")
	end
	if GCDsaver.Settings.ErrorMessages then
		TextLogAddEntry("Chat", 0, L"--- <icon57> Show Combat Error Messages")
	else
		TextLogAddEntry("Chat", 0, L"--- <icon58> Show Combat Error Messages")
	end
	-- Changed Below Here
	if GCDsaver.Settings.BlockFriendlyBuffs then
		TextLogAddEntry("Chat", 0, L"--- <icon57> Block Self and Friendly Buffs")
	else
		TextLogAddEntry("Chat", 0, L"--- <icon58> Block Self and Friendly Buffs")
	end
	if GCDsaver.Settings.BlockHostileBuffs then
		TextLogAddEntry("Chat", 0, L"--- <icon57> Block Hositle Buffs")
	else
		TextLogAddEntry("Chat", 0, L"--- <icon58> Block Hostile Buffs")
	end
	if GCDsaver.Settings.MaxResources then
		TextLogAddEntry("Chat", 0, L"--- <icon57> Limit Max Resources")
	else
		TextLogAddEntry("Chat", 0, L"--- <icon58> Limit Max Resources")
	end
	if GCDsaver.Settings.DebugMessages then
		TextLogAddEntry("Chat", 0, L"--- <icon57> Toggle Debug Messages")
	else
		TextLogAddEntry("Chat", 0, L"--- <icon58> Toggle Debug Messages")
	end
	--Changed Above Here	
end

function GCDsaver.UpdateButtonIcons()
    local actionType, actionId, isSlotEnabled, isTargetValid, isSlotBlocked
    for slot = 1, MAX_BUTTONS do
        actionType, actionId, isSlotEnabled, isTargetValid, isSlotBlocked = GetHotbarData(slot)        
        if GCDsaver.Settings.Enabled and GCDsaver.Settings.Symbols and GCDsaver.Settings.Abilities[actionId] then
            GCDsaver.UpdateButtonIcon(slot, GCDsaver.Settings.Abilities[actionId])
            if GCDsaver.Settings.DebugMessages then
                d("GCDsaver.UpdateButtonIcons: Updated button icon for slot " .. slot .. " with Ability ID " .. actionId)
            end
        elseif (not GCDsaver.Settings.Enabled or not GCDsaver.Settings.Symbols) and GCDsaver.Settings.Abilities[actionId] then
            GCDsaver.UpdateButtonIcon(slot, 0)
            if GCDsaver.Settings.DebugMessages then
                d("GCDsaver.UpdateButtonIcons: Reset button icon for slot " .. slot)
            end
        end
    end
end

local SaveHotKeySetText

function HotKeySetText(obj, text)
--	d("SetHotKeyText("..obj.m_Name..", "..text..")")
	SaveHotKeySetText(obj, text);
end

function DummyHotKeySetText(obj, text)
--	d("DummyHotKeySetText")
end

function GCDsaver.UpdateButtonIcon(slot, check)
	local actionType, actionId, isSlotEnabled, isTargetValid, isSlotBlocked
	local hbar, buttonid, button
	hbar, buttonid = ActionBars:BarAndButtonIdFromSlot(slot)
	if hbar and buttonid then
		button = hbar.m_Buttons[buttonid]
		if not SaveHotKeySetText then
			SaveHotKeySetText = button.m_Windows[7].SetText
		end
		if GCDsaver.Settings.DisableSlotChecks[slot] then
			d("slot " .. tostring(slot) .. " disabled.")
			button.m_Windows[7]:Show(true)
			button.m_Windows[7]:SetFont("font_default_war_heading", WindowUtils.FONT_DEFAULT_TEXT_LINESPACING)
			button.m_Windows[7]:SetTextColor(255, 255, 0)
			--button.m_Windows[7]:SetText("d")
			button.m_Windows[7].SetText = DummyHotKeySetText
			HotKeySetText(button.m_Windows[7], "d")
		elseif check then
			if check == IMMOVABLE then
				button.m_Windows[7]:Show(true)
				--button.m_Windows[7]:SetText("<icon05007>")
				button.m_Windows[7].SetText = DummyHotKeySetText
				HotKeySetText(button.m_Windows[7], "<icon05007>")
			elseif check == UNSTOPPABLE then
				button.m_Windows[7]:Show(true)
				--button.m_Windows[7]:SetText("<icon05006>")
				button.m_Windows[7].SetText = DummyHotKeySetText
				HotKeySetText(button.m_Windows[7], "<icon05006>")
			elseif check == CAREER_RESOURCE then
				button.m_Windows[7]:Show(true)
				button.m_Windows[7]:SetFont("font_default_war_heading", WindowUtils.FONT_DEFAULT_TEXT_LINESPACING)
				button.m_Windows[7]:SetTextColor(255, 255, 0)
				--button.m_Windows[7]:SetText("RE")
				button.m_Windows[7].SetText = DummyHotKeySetText
				HotKeySetText(button.m_Windows[7], "RE")
			elseif check >= 1 and check <= 3 then
				button.m_Windows[7]:Show(true)
				button.m_Windows[7]:SetFont("font_default_war_heading", WindowUtils.FONT_DEFAULT_TEXT_LINESPACING)
				button.m_Windows[7]:SetTextColor(255, 255, 0)
				--button.m_Windows[7]:SetText(tostring(check).."x")
				button.m_Windows[7].SetText = DummyHotKeySetText
				HotKeySetText(button.m_Windows[7], tostring(check).."x")
			elseif check == 0 then
				button.m_Windows[7]:Show(false)
			end
		end
	end
end

function GCDsaver.UpdateButtonsEnabledStates()
	for slot = 1, MAX_BUTTONS do
		GCDsaver.UpdateButtonEnabledState(slot)
	end
end

function GCDsaver.UpdateButtonEnabledState(slot)
	local actionType, actionId, isSlotEnabled, isTargetValid, isSlotBlocked = GetHotbarData(slot)
	--if actionId ~= 0 then
	if GCDsaver.Settings.Abilities[actionId] then
		ActionBars.UpdateSlotEnabledState(slot, isSlotEnabled, isTargetValid, isSlotBlocked)
	end
end

-- Hooked Functions
local orgActionButtonOnLButtonDown = ActionButton.OnLButtonDown
function ActionButton.OnLButtonDown(self, flags, x, y)

	if flags == SystemData.ButtonFlags.SHIFT and self.m_ActionId ~= 0 then
		local action = GCDsaver.Settings.Abilities[self.m_ActionId];
		if not action then
			GCDsaver.Settings.Abilities[self.m_ActionId] = 1
		elseif action < 6 then
			action = action + 1
			GCDsaver.Settings.Abilities[self.m_ActionId] = action
		else
			GCDsaver.Settings.Abilities[self.m_ActionId] = nil
		end

		GCDsaver.UpdateButtonIcon(self.m_HotBarSlot, GCDsaver.Settings.Abilities[self.m_ActionId] or 0)
		GCDsaver.UpdateButtonEnabledState(self.m_HotBarSlot)
		GCDsaverAPI.chatInfo(self.m_ActionId, self.m_HotBarSlot)

		-- Block WindowGameAction
		WindowGameAction = blockedWindowGameAction
		
	elseif flags == SystemData.ButtonFlags.CONTROL and self.m_ActionId ~= 0 then
		if GCDsaver.Settings.DisableSlotChecks[self.m_HotBarSlot] then
			GCDsaver.Settings.DisableSlotChecks[self.m_HotBarSlot] = nil
		else
			GCDsaver.Settings.DisableSlotChecks[self.m_HotBarSlot] = 1
		end

		GCDsaver.UpdateButtonIcon(self.m_HotBarSlot, GCDsaver.Settings.Abilities[self.m_ActionId] or 0)
		GCDsaver.UpdateButtonEnabledState(self.m_HotBarSlot)
		GCDsaverAPI.chatInfo(self.m_ActionId, self.m_HotBarSlot)

		-- Block WindowGameAction
		WindowGameAction = blockedWindowGameAction		

	elseif self.m_ActionId ~= 0
	and GCDsaver.Settings.Abilities[self.m_ActionId]
	and isAbilityBlocked(self.m_ActionId, self.m_HotBarSlot) then
		-- Block WindowGameAction
		WindowGameAction = blockedWindowGameAction

	else
		-- Restore WindowGameAction
		WindowGameAction = orgWindowGameAction

		orgActionButtonOnLButtonDown(self, flags, x, y)
	end
end

local orgActionBarsUpdateSlotEnabledState = ActionBars.UpdateSlotEnabledState
function ActionBars.UpdateSlotEnabledState(slot, isSlotEnabled, isTargetValid, isSlotBlocked)

	if not GCDsaver.Settings.DisableSlotChecks[slot] then
		local hbar, buttonid = ActionBars:BarAndButtonIdFromSlot(slot)
		if hbar and buttonid then
			local button = hbar.m_Buttons[buttonid]
			local abilityData = GetAbilityData(button.m_ActionId)
			local actionId = button.m_ActionId -- Added this
			
			if GCDsaver.Settings.Abilities[button.m_ActionId]
			and GCDsaver.Settings.Abilities[button.m_ActionId] == IMMOVABLE
			and GCDsaver.TargetImmovable
			then
				isSlotEnabled = false
			elseif GCDsaver.Settings.Abilities[button.m_ActionId]
			and GCDsaver.Settings.Abilities[button.m_ActionId] == UNSTOPPABLE
			and GCDsaver.TargetUnstoppable
			then
				isSlotEnabled = false
			elseif GCDsaver.Settings.Abilities[button.m_ActionId]
			and GCDsaverAPI.hasBuff(GCDsaverAPI.getTargetType(abilityData.targetType), abilityData, GCDsaver.Settings.Abilities[button.m_ActionId])
			then
				isSlotEnabled = false
			------------------------ Changed below here
			elseif isAbilityBlocked(actionId, slot) 
			then
                isSlotEnabled = false	
			------------------------- Changed above here
			elseif GCDsaver.Settings.Abilities[button.m_ActionId]
			and GCDsaver.Settings.Abilities[button.m_ActionId] == CAREER_RESOURCE
			then
				local resources = GetCareerResource( GameData.BuffTargetType.SELF )
				if resources == nil or tonumber(resources) < GCDsaver.Settings.MaxResources then
					isSlotEnabled = false
				end
			end
		end
	end

	orgActionBarsUpdateSlotEnabledState(slot, isSlotEnabled, isTargetValid, isSlotBlocked)
end

local orgActionButtonUpdateInventory = ActionButton.UpdateInventory
function ActionButton.UpdateInventory(self)
	if not GCDsaver.Settings.Abilities[self.m_ActionId] then
		orgActionButtonUpdateInventory(self)
	end
end