-- ==========================
-- ===== Public members =====
-- ==========================

GCDsaverTalks = {
    LANGUAGES       = {},
    
    Loaded = false
}


-- ===========================
-- ===== Private members =====
-- ===========================

local nTl      = nil
local chatInputMaxChars = 4096
local Commands = {}


-- ===========================
-- ===== Private methods =====
-- ===========================
-- Utility methods
-- ===============

-- Shortcut function
local function say(text)
    GCDsaverTalks.Say(text)
end

-- Shortcut function
local function clearHotbarSlot(barSlot)
    SetHotbarData(barSlot, GameData.PlayerActions.NONE, 0)
end

-- create a link wstring 
local function CreateLink(actionId)
    local tableData = nil
    local linkIdString = nil
    local theType = nil   
    if (GetAbilityData(actionId) and GetAbilityData(actionId).id == actionId) then
        tableData = GetAbilityData(actionId)
        linkIdString  = L"ABILITY:" .. actionId
        theType = "ability"
    elseif (DataUtils.FindItem(actionId) and DataUtils.FindItem(actionId).uniqueID == actionId) then
        tableData = DataUtils.FindItem(actionId)
        linkIdString  = L"ITEM:" .. actionId
        theType = "item"    
    else
        -- try the cache
        tableData = GCDsaverMemory.getActionDataCache(actionId)
        if tableData then
            if tableData.actionType=="ability" then
                linkIdString  = L"ABILITY:" .. actionId
            elseif tableData.actionType=="item" then
                linkIdString  = L"ITEM:" .. actionId
            else
                d("GCDsaverTalks:CreateLink: Unrecognised actionType")
            end            
        else
            -- not in cache for some reason fall back to id
            tableData = {}
            tableData.name = actionId
            linkIdString  = L"UNKNOWN:" .. actionId
            d("GCDsaverTalks:CreateLink: actionId not in cache.")
        end

    end    
    --tableData.actionType = theType -- store the type in the data structure
    local text  = L"[" .. tableData.name .. L"]"    
    local color = DefaultColor.LIGHT_BLUE
    local link = CreateHyperLink( linkIdString, text, {color.r,color.g,color.b}, {} )
    --GCDsaverMemory.setActionDataCache(actionId, tableData) -- update cache
    return link
end

local function getShortName(check)
    for shortName, checkName in pairs(GCDsaverChecks.ShortNames) do
        if check == checkName then
            return shortName
        end
    end
    return check
end

-- Parsing of links and checks sequence
local function sequenceParsing(sequenceString)
    local remainder = sequenceString
    local _Sequence = {}

    while remainder and remainder:find(L"^<LINK[^>]*>") do
        -- link found. extract id and options
        local slotConfig = { }
        
        -- Extract ability ID
        local abilityId = tonumber(remainder:match(L"ABILITY:(%d+)"))
        local itemId = tonumber(remainder:match(L"ITEM:(%d+)"))
        
        -- obtain index for the first ability and item links
        local abilityIndex = remainder:find(L"ABILITY:(%d+)")
        local itemIndex = remainder:find(L"ITEM:(%d+)")
        
        -- extracts item and ability ids one at a time
        if not abilityIndex and not itemIndex then
            say(nTl.ABILITY_ERR)
            say(nTl.BIND_FAILED)
            return
        else
            if not abilityIndex then
                slotConfig[GCDsaverAPI.PARAMS.item] = itemId
            elseif not itemIndex then
                slotConfig[GCDsaverAPI.PARAMS.ability] = abilityId
            else
                if (abilityIndex < itemIndex) then
                    slotConfig[GCDsaverAPI.PARAMS.ability] = abilityId
                else
                    slotConfig[GCDsaverAPI.PARAMS.item] = itemId
                end
            end
        end
        
        remainder = remainder:match(L"^<LINK[^>]*>(.*)") -- extract link text
        
        local options = nil
        flags ,remainder = remainder:match(L"^([^<]*)(.*)")
        
        while flags and flags:find(L"^;?%a+:[^;]+") do
            local flag = nil
            local values = nil
            flag, values, flags = flags:match(L"^;?(%a+)(:[^;]+)(.*)")
            local rawParams = {}
            while values and values:find(L"^:[^:]*") do
                local value = nil
                value, values = values:match(L"^:([^:]*)(.*)")
                table.insert(rawParams, tostring(value))
            end
            local checkName = tostring(flag)
            if GCDsaverChecks.ShortNames[checkName] then
                checkName = GCDsaverChecks.ShortNames[checkName]
            end
            
            local params = {}
            local paramList = {}
            if GCDsaverChecks.CustomChecks[checkName] then
                paramList = GCDsaverChecks.CustomChecks[checkName]
            end
            for position, param in pairs(paramList) do
                local value = rawParams[position]
                local number = tonumber(value)
                local string = tostring(value)
                if number then
                    params[param] = number
                elseif value and string and string ~= "" then
                    params[param] = string
                end
            end
            if not slotConfig[checkName] then
                slotConfig[checkName] = {}
            end
            local i = 0
            while slotConfig[checkName][i] do
                i = i + 1
            end
            slotConfig[checkName][i] = params
        end
        table.insert(_Sequence, slotConfig)
    end -- while
    return _Sequence
end

-- prints sequence for button:SlotNumber
local function listSequence(sequence)
    if not sequence then
        return nil
    end
    
    local s = L""
    for _, abilityInfo in ipairs(sequence) do
        if(abilityInfo[GCDsaverAPI.PARAMS.ability]) then
            s = s .. CreateLink(abilityInfo[GCDsaverAPI.PARAMS.ability])
        else
            s = s .. CreateLink(abilityInfo[GCDsaverAPI.PARAMS.item])
        end

        -- Very weird bug here, i'd like to set the separator to L"" at first,
        -- but then the name of the check doesn't appear, any (it seems) non-letter
        -- character between the link and the check name fixes the problem
        local separator = L";"
        for check, instances in pairs(abilityInfo) do
            if (check == GCDsaverAPI.PARAMS.ability) or (check == GCDsaverAPI.PARAMS.item)  then
                -- nothing, taken care of above
            else
                local shortName = getShortName(check)
                local paramTable = nil
                if GCDsaverChecks.CustomChecks[check] then
                    paramTable = GCDsaverChecks.CustomChecks[check]
                end
                for _, params in pairs(instances) do
	                s = s .. separator .. towstring(shortName)
	                for _, param in ipairs(paramTable) do
	                    local paramString = ""
	                    if params[param] then
	                        paramString = params[param]
	                    end
	                    s = s .. L":" .. towstring(paramString)
	                end
	                separator = L";"
                end
            end
        end
    end
    return s
end


local function displaySlot(SlotNumber, sequence)
    return L"  ["..SlotNumber..L"] = " .. listSequence(sequence)
end

local function getSlotCommand(SlotNumber, sequence)
    return L"/nb add " ..SlotNumber .. L" " .. listSequence(sequence)
end


-- ===============
-- Command methods
-- ===============

-- display the UI
function Commands.ui()
    NBSBCore.Show()
end

-- wipe out all char settings
function Commands.clear(param)
    GCDsaverMemory.ClearCharacterConfig()
    say(nTl.CLEARED)
end


-- chose help text and print it
function Commands.help(param)
    if param then
        local _p = nTl["HELP_"..WStringToString(param)]
        if _p then
            say(_p)
        else
            say(nTl.BAD_CMDLN..L"help "..param)
        end
    else
         say(nTl.HELP_)
    end
end


-- display credits information
function Commands.credits()
    say(nTl.CREDITS)
end


-- read a sequence definition and store it
function Commands.add(param)
    local slot, remainder = param:match(L"([0-9]+)[ ]?(.*)")
    slot = tonumber(slot)
    
    -- Slot number check
    if not slot or (slot < 1) or (slot > GCDsaverAPI.MAX_BUTTONS) then
        say(nTl.BAD_SLOT)
        say(nTl.HELP_add)
        return
    end
    
    local _Sequence = sequenceParsing(remainder)

    -- Sequence check
    if table.getn(_Sequence) <= 0 then
        say(nTl.HELP_add)
        return
    end
    -- insert
    GCDsaverMemory.SetBinding(slot, _Sequence)
    say(displaySlot(slot, _Sequence))
end


-- try to delete a sequence
function Commands.del(param)
    local slot = tonumber(param)
    if slot and (slot >= 1) and (slot <= GCDsaverAPI.MAX_BUTTONS) then
        local cleared = GCDsaverMemory.ClearBinding(slot)
        if cleared then
            clearHotbarSlot(slot)
        else
            say(nTl.NOSEQS_BOUND)
        end
    else
        say(nTl.HELP_del)
    end
end


-- show infos about stored sequences
function Commands.list(param)
    local slot = tonumber(param)
    if param == L"all" then
        local count = 0
        for slot, sequence in pairs(GCDsaverMemory.GetBindings()) do
            if type(slot) == "number" then 
	            say(displaySlot(slot, sequence))
	            count = count + 1
            end
        end
        if count == 0 then
            say(nTl.NOSEQS_BOUND)
        end
    elseif param == L"" then
        local s = L""
        for slot in pairs(GCDsaverMemory.GetBindings()) do
            if type(slot) == "number" then
                s = s .. slot .. L" "
            end
        end
        if s ~= L"" then
            say(nTl.SEQS_BOUND .. s)
        else
            say(nTl.NOSEQS_BOUND)
        end
    elseif slot then
        local sequence = GCDsaverMemory.GetBinding(slot)
        if sequence then
            say(displaySlot(slot, sequence))
        else
            say(nTl.NOSEQS_BOUND)
        end
    else
        say(nTl.HELP_list)
    end
end


-- puts the command line used for a slot back in the chat text box
function Commands.edit(param)
    local empty = (param == L"")
    local slot = tonumber(param)
    if slot then
        local sequence = GCDsaverMemory.GetBinding(slot)
        if sequence then
            EA_ChatWindow.InsertText( getSlotCommand(slot, sequence) )
        else
            say(nTl.NOSEQS_BOUND)
        end
    else
        say(nTl.HELP_edit)
    end
end

local function printChecks(paramTable)
    for checkName, params in pairs(paramTable) do
        local shortName = getShortName(checkName)
        local paramString = L""
        for _, param in ipairs(params) do
            paramString = paramString .. L":<" .. towstring(param) .. L">"
        end
        say(L"" .. towstring(checkName) .. L"" .. L" = " .. towstring(shortName) .. paramString)
    end
end

-- print the effects on a target
local function printEffects(target)
    local effects = NerfedEngine.GetEffects(target)
    if not effects then return end
    for effectId, effectData in pairs(effects) do
        local stats = "]  ["..effectId.."] ("..effectData.self.stackCount..","..effectData.other.stackCount..")"
        say("  * ["..WStringToString(effectData.name)..stats)
    end
end


-- list all the effects on you
function Commands.effects(param)
    say("")
    say("Effects: [Name] [Id] (selfStack,totalStack)")
    say("")
    say("Player Effects:")
    printEffects("p")
    say("Friendly Target Effects:")
    printEffects("f")
    say("Enemy Target Effects:")
    printEffects("e")
end


-- print the printConditions on a target
local function printConditions(target)
    local conditions = NerfedEngine.GetConditions(target)
    if not conditions then return end
	local revCondLookup = {}
    for conditionShort, conditionLong in pairs(GCDsaverAPI.CONDITIONS) do
    	revCondLookup[conditionLong] = conditionShort
    end	
    for conditionType, conditionStatus in pairs(conditions) do
    	if(conditionStatus==true) then
    		say("  * "..string.sub(conditionType, 3).." ["..revCondLookup[conditionType].."]")
    	end
    end
end


-- list all the conditions on you
function Commands.conditions(param)
    say("")
    say("Conditions: Name [Id]")
    say("")
    say("Player Conditions:")
    printConditions("p")
    say("Friendly Target Conditions:")
    printConditions("f")
    say("Enemy Target Conditions:")
    printConditions("e")
end


-- list all the actions available to you
function Commands.actions(param)
    say("")
    say("Actions: (Type) Name [Id]")
    say("")
    local actions = GCDsaverMemory.actionDataCache
    for actionId, actionData in pairs(actions) do
    	if(actionData.hasAction and actionId~=0) then
			say(L"  * ("..towstring(actionData.actionType)..L") - "..towstring(actionData.name)..L" ["..towstring(actionId)..L"]")
		end
    end
end

--
function Commands.checks(param)
    if nTl['HELP_CHECKS.'..tostring(param)..'.fullname'] then
        say(L'\n')
        say(L'* * * ' .. nTl['HELP_CHECKS.'..tostring(param)..'.fullname'] .. L' Check * * * ')
        if nTl['HELP_CHECKS.'..tostring(param)..'.description'] then
            say(nTl['HELP_CHECKS.'..tostring(param)..'.description'])
        else
            say(nTl['HELP_CHECKS_No_Description'])
        end
        say(L'\n')        
        -- parameter high level
        local paramString = L""
        local paramBreakdownString = L""
        local fullname = nTl['HELP_CHECKS.'..tostring(param)..'.fullname']
        for _, part in ipairs(GCDsaverChecks.CustomChecks[tostring(fullname)]) do
            paramString = paramString .. L":<" .. towstring(part) .. L">"
            paramBreakdownString = paramBreakdownString .. L'  * <' .. towstring(part) .. L'>: ' .. nTl['HELP_PARAMS.'..tostring(part)] .. L"\n"
        end  
        say(param .. paramString)
        say(paramBreakdownString)
        -- parameter low level
        local fullparamname = nTl['HELP_CHECKS.'..tostring(param)..'.fullname']
        for _, part in ipairs(GCDsaverChecks.CustomChecks[tostring(fullname)]) do
            paramString = paramString .. L":<" .. towstring(part) .. L">"
        end          
        
        if nTl['HELP_CHECKS.'..tostring(param)..'.example'] then
            say(nTl['HELP_CHECKS.'..tostring(param)..'.example'])
        else
            say(nTl['HELP_CHECKS_No_Example'])
        end        
        say(L'\n')
    else
        if param ~= L"" then
            say(nTl.HELP_checks)
            return
        end    
        printChecks(GCDsaverChecks.CustomChecks)
    end
end

--
function Commands.params(param)
    if param ~= L"" then
        say(nTl.HELP_params)
        return
    end
    
    say(nTl.PARAMS_1)
    for shortName, fullName in pairs(GCDsaverAPI.CONDITIONS) do
        say(L"  " .. towstring(shortName) .. L" : " .. towstring(fullName))
    end
    say(nTl.PARAMS_2)
    local c = L""
    for shortName in pairs(NerfedAPI.careerDB) do
        c = c .. L"  " .. towstring(shortName) .. L","
    end
    say(c)
    say(nTl.PARAMS_3)
    local a = L""
    for shortName in pairs(NerfedAPI.ARCHETYPE) do
        a = a .. L"  " .. towstring(shortName) .. L","
    end
    say(a)
    say(nTl.PARAMS_4)
end

--
function Commands.toggleautodismount(param)

    local installed, enabled = NerfedUtils.isModule('AutoDismount') 
    
    if not installed then
        say(L"nb> autodismount addon in not installed.")
        return
    end
    
    if not enabled then
        say(L"nb> autodismount addon in not enabled.")
        return
    end

    if GCDsaverMemory.GetAutoDismount() then
        GCDsaverMemory.SetAutoDismount(false)
        say(L"nb> autodismount (experimental) = " .. nTl.OFF)
    else
        GCDsaverMemory.SetAutoDismount(true)
        say(L"nb> autodismount (experimental) = " .. nTl.ON)
    end
end

--
function Commands.toggledisabled(param)
    if GCDsaverMemory.GetDisabledButtons() then
        GCDsaverMemory.SetDisabledButtons(false)
        say(L"nb> disabledbuttons = " .. nTl.OFF)
    else
        GCDsaverMemory.SetDisabledButtons(true)
        say(L"nb> disabledbuttons = " .. nTl.ON)
    end
end

--
function Commands.toggleblank(param)
    if GCDsaverMemory.GetBlankButtons() then
        GCDsaverMemory.SetBlankButtons(false)
        say(L"nb> blankbuttons = " .. nTl.OFF)
    else
        GCDsaverMemory.SetBlankButtons(true)
        say(L"nb> blankbuttons = " .. nTl.ON)
    end
end

--
function Commands.togglepages(param)
    if GCDsaverMemory.GetPagesSupport() then
        GCDsaverMemory.SetPagesSupport(false)
        say(L"nb> pagesupport = " .. nTl.OFF)
    else
        GCDsaverMemory.SetPagesSupport(true)
        say(L"nb> pagesupport = " .. nTl.ON)
    end
end

--
function Commands.togglefullsoc(param)
    if GCDsaverMemory.GetFullStayOnCast() then
        GCDsaverMemory.SetFullStayOnCast(false)
        say(L"nb> full StayOnCast = " .. nTl.OFF)
    else
        GCDsaverMemory.SetFullStayOnCast(true)
        say(L"nb> full StayOnCast = " .. nTl.ON)
    end
end

--
function Commands.id(param)
    if param:match(L"ABILITY:([0-9]*)") then
        say(L"nb> ".. param .. L" = "..param:match(L"ABILITY:([0-9]*)"))    
    elseif param:match(L"ITEM:([0-9]*)") then
        say(L"nb> ".. param .. L" = "..param:match(L"ITEM:([0-9]*)"))    
    end
end

--
function Commands.vcd(param)
    if param == L"list" then
        say(nTl.VCD_LIST)
        for abilityId, vcd in pairs(GCDsaverMemory.GetCareerwideVCDs()) do
            say(L"   "..CreateLink(abilityId)..L" = "..vcd)
        end
    elseif param == L"clear" then
        GCDsaverMemory.ClearCareerwideVCDs()
        say(nTl.VCD_CLEAR)
    elseif param:find(L"^<LINK[^>]*>") then
        local abilityId = param:match(L"ABILITY:(%d+)")
        abilityId = tonumber(abilityId)
        local link, remainder = param:match(L"^(<LINK[^>]*>)(.*)") -- extract link text
        
        local virtualCDown = remainder:match(L"(%d+[.]?%d?)")
        virtualCDown = tonumber(virtualCDown)
        
        if abilityId and virtualCDown and virtualCDown ~= 0 then
            GCDsaverMemory.SetCareerwideVCD(abilityId, virtualCDown)
            say(nTl.VCD_SET..link..L" = "..towstring(virtualCDown))
        elseif abilityId then
            GCDsaverMemory.ClearCareerwideVCD(abilityId)
            say(nTl.VCD_RESET..link)
        else
            say(nTl.HELP_vcd)
        end
    else
        say(nTl.HELP_vcd)
    end
end

--
function Commands.dt(param)
    if param == L"list" then
        say(nTl.DT_LIST_1)
        for abilityId, dTarget in pairs(GCDsaverAPI.DefaultTarget) do
            if GCDsaverMemory.getActionDataCache(abilityId).id ~= 0 then
                say(L"   "..CreateLink(abilityId)..L" = "..towstring(dTarget))
            end
        end
        say(nTl.DT_LIST_2)
        for abilityId, dTarget in pairs(GCDsaverMemory.GetDefaultTargets()) do
            say(L"   "..CreateLink(abilityId)..L" = "..towstring(dTarget))
        end
    elseif param == L"clear" then
        GCDsaverMemory.ClearDefaultTargets()
        say(nTl.DT_CLEAR)
    elseif param:find(L"^<LINK[^>]*>") then
        local abilityId = param:match(L"ABILITY:(%d+)")
        abilityId = tonumber(abilityId)
        local link, remainder = param:match(L"^(<LINK[^>]*>)(.*)") -- extract link text
        
        local dTarget = remainder:match(L" ?(%l)")
        dTarget = WStringToString(dTarget)
        
        local valid = false
        for _, target in pairs(GCDsaverAPI.TARGET) do
            if dTarget == target then
                valid = true
            end
        end
        if abilityId and valid then
            GCDsaverMemory.SetDefaultTarget(abilityId, dTarget)
            say(nTl.DT_SET..link..L" = "..towstring(dTarget))
        elseif abilityId then
            GCDsaverMemory.ClearDefaultTarget(abilityId)
            say(nTl.DT_RESET..link)
        else
            say(nTl.HELP_dt)
        end
    else
        say(nTl.HELP_dt)
    end
end

--
function Commands.macro(param)
    if param == L"list" then
        say(nTl.MACRO_LIST)
        for slot, macro in pairs(GCDsaverMemory.GetMacros()) do
            say(L"   "..slot..L" : "..macro)
        end
    elseif param:find(L"^%d+") then
        local slot, macro = param:match(L"^(%d+) ?(%d*)")
        slot = tonumber(slot)
        macro = tonumber(macro)
        
        if slot and macro and macro < 43 and macro > 0 then
            GCDsaverMemory.SetMacro(slot, macro)
            say(nTl.MACRO_SET..slot..L" : "..macro)
        elseif slot then
            GCDsaverMemory.ClearMacro(slot)
            say(nTl.MACRO_RESET..slot)
        else
            say(nTl.HELP_macro)
        end
    else
        say(nTl.HELP_macro)
    end
end

--
function Commands.ddcheck(param)
    if param == L"list" then
        say(nTl.DDC_LIST)
        for abilityId, checks in pairs(GCDsaverMemory.GetDisableDChecks()) do
            for check in pairs(checks) do
                say(L"   "..CreateLink(abilityId)..L" : "..towstring(check))
            end
        end
    elseif param:find(L"^<LINK[^>]*>") then
        local abilityId = param:match(L"ABILITY:(%d+)")
        abilityId = tonumber(abilityId)
        local link, remainder = param:match(L"^(<LINK[^>]*>)(.*)") -- extract link text
        
        local check = remainder:match(L" ?(%l+)")
        check = WStringToString(check)
        
        if abilityId and check and (check == "enabled" or check == "target" or check == "cooldown") then
            GCDsaverMemory.ToggleDisableDCheck(check, abilityId)
            if GCDsaverMemory.GetDisableDCheck(check, abilityId) then
                say(nTl.DDC_SET..link..L" : "..towstring(check))
            else
                say(nTl.DDC_UNSET..link..L" : "..towstring(check))
            end
            
        elseif abilityId and not check then
            GCDsaverMemory.ClearDisableDCheck(abilityId)
            say(nTl.DDC_RESET..link)
        else
            say(nTl.HELP_ddcheck)
        end
    else
        say(nTl.HELP_ddcheck)
    end
end


function Commands.pcur(param)
    say(nTl.PROFILE_pcur)
    say(L"  ["..towstring(GCDsaverMemory.GetCurProfileNum())..L"] "..towstring(GCDsaverMemory.GetProfileDesc()))
end

function Commands.plist(param)
    say(nTl.PROFILE_plist)
    local list = GCDsaverMemory.ListProfiles()
    for number, desc in pairs(list) do
        say(L"  ["..towstring(number)..L"] "..towstring(desc))
    end
end

function Commands.pcreate(param)
    local desc = WStringToString(param)
    if not desc or desc == "" then
        say(nTl.PROFILE_pcreate)
        return
    end
    
    local num = GCDsaverMemory.CreateProfile(desc)
    
    say(L"  >"..nTl.PROFILE_pcreate2..L" ["..towstring(num)..L"] "..towstring(desc))
end

function Commands.pcopy(param)
    local desc = WStringToString(param)
    if not desc or desc == "" then
        say(nTl.PROFILE_pcopy)
        return
    end
    
    local num = GCDsaverMemory.CopyProfile(desc)
    
    say(L"  >"..nTl.PROFILE_pcopy2..L" ["..towstring(num)..L"] "..towstring(desc))
end

function Commands.pdel(param)
    local profile = tonumber(param)
    
    local result = GCDsaverMemory.DeleteProfile(profile)
    
    if not result then
        say(L"  >"..nTl.PROFILE_pdel)
        return
    end
    
    if type(result) == "string" then
        say(L"  >"..nTl.PROFILE_pdel2..L" "..towstring(result))
        return
    end
    
    say(L"  "..nTl.PROFILE_pdel3..L" "..profile..L" "..nTl.PROFILE_pdel4..L".")
end

function Commands.pforcedel(param)
    local profile = tonumber(param)
    
    if profile == GCDsaverMemory.GetCurProfileNum() then
        say(L"  >"..nTl.PROFILE_pforcedel)
    end
    local result = GCDsaverMemory.ForceDeleteProfile(profile)
    
    if not result then
        say(L"  >"..nTl.PROFILE_pforcedel2)
        return
    end
    
    say(L"  "..nTl.PROFILE_pdel3..L" "..profile..L" "..nTl.PROFILE_pdel4..L".")
end

function Commands.pswitch(param)
    local result = GCDsaverMemory.SwitchProfile(tonumber(param))
    
    if not result then
        say(L"  >"..nTl.PROFILE_pswitch)
        return
    end
    
    say(L"  >".. nTl.PROFILE_pswitch2 ..L" ["..towstring(GCDsaverMemory.GetCurProfileNum())..L"] "..towstring(GCDsaverMemory.GetProfileDesc()))
end

function Commands.pdesc(param)
    local desc = WStringToString(param)
    
    if not desc or desc == "" then
        say(nTl.PROFILE_pdesc)
        return
    end
    
    GCDsaverMemory.SetProfileDesc(desc)
end

-- ============================
-- ===== Internal methods =====
-- ============================

function GCDsaverTalks.Initialize()
    local Language = "english"
    
    for lang, number in pairs(SystemData.Settings.Language) do
        if lang ~= "active" and number == SystemData.Settings.Language.active then
            Language = string.lower(lang)
            break
        end
    end
    nTl = GCDsaverTalks.LANGUAGES[Language] -- language pointer
    
    -- increase chat field maximum input length
    TextEditBoxSetMaxChars('EA_TextEntryGroupEntryBoxTextInput', chatInputMaxChars) 
    
    -- development fallback
    if not nTl.MSG1 then
        nTl = GCDsaverTalks.LANGUAGES['englishdev'] -- language pointer
    end

    -- LibSlash check, a required dependency
    if not LibSlash.RegisterWSlashCmd then
        say("Warning: GCDsaverAPI needs LibSlash V1.8++ !")
        return false
    end
    
    -- register slash command "/nb"
    local cmdRegistered = LibSlash.RegisterWSlashCmd("nb", GCDsaverTalks.Command)
    
    -- Help message
    say(nTl.MSG1)
    
    if cmdRegistered and nTl then
        GCDsaverTalks.Loaded = true
    end
    return GCDsaverTalks.Loaded
end

-- try to interprete a /NB <commnd>
function GCDsaverTalks.Command(input)

    -- check length of input
    --if string.len(input) > chatInputMaxChars then
    --    say("Warning: You entered a command longer than the maximum characters allowed!")
    --    return
    --end

    local cmd, parameter = input:match(L"([a-z]+)[ ]?(.*)")
    if cmd then
        local _p = Commands[WStringToString(cmd)]
        if _p then
            _p(parameter)
            return
        else
            say(nTl.BAD_CMDLN..cmd)
        end
    end
    say(nTl.HELP_)
end


-- ==========================
-- ===== Public methods =====
-- ==========================

-- text to chatlog
function GCDsaverTalks.Say(s)
    local str = towstring(s)
    TextLogAddEntry("Chat", SystemData.ChatLogFilters.SAY, str)
end

function GCDsaverTalks.lang(key)
    return nTl[key]
end

function GCDsaverTalks.SequenceParsing(sequenceString)
    return sequenceParsing(sequenceString)
end

function GCDsaverTalks.ListSequence(sequence)
    return listSequence(sequence)
end