--[[
	LimitTickets
	==========================================
	Restrict the number of event tickets that can be gained to some number like 10.
	==========================================
]]--

--[[ Dev notes:
Working: Code Cleanup: Get rid of hardcoded inline constants.
ToDo: Code Cleanup: Remove repetition in settings by writing a checkbox wrapper.
ToDo: Code Cleanup: Remove most debugging notices.
ToDo: Feature: Internationalization.
ToDo: Code Cleanup: Better hooking.

ToDo: Feature: If an event starts, prompt user to move to stricter constraints if the addon hasn't been updated as "confirmed to work for that event" somehow?
ToDo: Feature: If an event starts, prompt user to move to stricter constraints if the addon hasn't got historically blocklisted items for that event?
ToDo: Feature: If an event starts, prompt user to move to stricter constraints if their current constraints are known to be too lax?
ToDo: Feature: If you get tickets from a verb not on the list, offer to add that verb to the list.
ToDo: Feature: A user-editable list of verbs to prevent for the current event.
ToDo: Feature: Optionally don't block vendors?
ToDo: FIX: If not explicitly marked for crouching, assistants should be usable without crouching.
Put https://cdn-eso.mmoui.com/images/style_esoui/downloads/new_3.gif before all new items.
ToDo: Feature: Some kinda warning on gifted tickets... where do they come from? Ingame mail? I don't know!
ToDo: Feature: Could turn off ticket-blocking until midnight, once you get the max number of tickets for the day? You won't get more tickets the same day.
ToDo: Feature: Allow a keybind instead of crouch, but share the keybind of NAS? Include NAS functionality here if NAS not installed? Don't want users to have to map TWO keys.
ToDo: Feature: Allow characters to have their own individual settings, instead of globally shared ones.
ToDo: Feature: Internationalization.
ToDo:          - actually translate text in tt().
ToDo:          - parameterize dd(), zoAlertWrapper(), setReticleText(), for easier translation.
ToDo: Feature: Ultimately, blocklist only the things you interact or talk with to get tickets. (New Life: Talk "Breda" or "Petronius Galenus"). Likely take a year to get all the names.
ToDo: Feature: Remind the player to get tickets for the day?
ToDo: Feature: Add compatibility with Event Tracker to turn off blocking outside of events, so there're no tickets to be got? But maybe a few days after scheduled end, in case event gets extended.
ToDo: Feature: Add compatibility with No Accidental Stealing, to use its current settings as the default, if it's installed.
ToDo: Feature: Crouch to use a non-set crafting table where you've already completed the writ?
ToDo: Feature: Find out what gamepad compatibility might entail.
Ongoing: Maintain lists of known-safe and known-unsafe containers.
]]--

LimitTickets = {}
LimitTickets.name = "LimitTickets"
LimitTickets.version = "v1.2.0"
LimitTickets.SavedVarsVersion = "1" -- If this changes, older saved vars are WIPED.
LimitTickets.SavedVars = {} -- The actual real data.

local defaultSavedVars = { -- Will be created in save file if not found, but won't override existing values.
    maxTickets = 10,
    debugMessages = false,
    alertMessages = true,
    reticleMessages = true,
    ticketWarningsOnly = false,
    crouchAssistants = true,
    crouchContainers = true,
    crouchNpc = true,
    crouchAllNpc = false,
    currentTickets = nil,
    ignoreSafeContainers = false,
}

-- Local vars
-- Modified "Stealth to..." control from NoAccidentalStealing.
local useInfoControl = CreateControlFromVirtual("UseInfo", ZO_ReticleContainerInteract, "ZO_KeybindButton")
local currentTickets = nil

-- Translate text.
local function tt(text)
    return text
end

-- Must be after the tt() definition.
local isProbablySafeContainer = {
    [tt("Apple basket")] = true,
    [tt("Backpack")]     = true,
    [tt("Barrel")]       = true,
    [tt("Basket")]       = true,
    [tt("Cupboard")]     = true,
    [tt("Drawers")]      = true,
    [tt("Nightstand")]   = true,
    [tt("Sack")]         = true,
    [tt("Urn")]          = true,
}

-- Uses GetString() constants, so I18N'd. Unrecognized values will be Nil!
local actionNameToEnglish = {
    [GetString(SI_GAMECAMERAACTIONTYPE1)] = "Search",
    [GetString(SI_GAMECAMERAACTIONTYPE2)] = "Talk",
    -- Commented unused items.
    -- [GetString(SI_GAMECAMERAACTIONTYPE3)] = "Harvest",
    -- [GetString(SI_GAMECAMERAACTIONTYPE4)] = "Disarm",
    -- [GetString(SI_GAMECAMERAACTIONTYPE5)] = "Use",
    -- [GetString(SI_GAMECAMERAACTIONTYPE6)] = "Read",
    -- [GetString(SI_GAMECAMERAACTIONTYPE7)] = "Take",
    -- [GetString(SI_GAMECAMERAACTIONTYPE8)] = "Destroy",
    -- [GetString(SI_GAMECAMERAACTIONTYPE9)] = "Repair",
    -- [GetString(SI_GAMECAMERAACTIONTYPE10)] = "Inspect",
    -- [GetString(SI_GAMECAMERAACTIONTYPE11)] = "Repair",
    -- [GetString(SI_GAMECAMERAACTIONTYPE12)] = "Unlock",
    -- [GetString(SI_GAMECAMERAACTIONTYPE13)] = "Open",
    -- [GetString(SI_GAMECAMERAACTIONTYPE15)] = "Examine",
    -- [GetString(SI_GAMECAMERAACTIONTYPE16)] = "Fish",
    -- [GetString(SI_GAMECAMERAACTIONTYPE17)] = "Reel In",
    -- [GetString(SI_GAMECAMERAACTIONTYPE18)] = "Pack Up",
    -- [GetString(SI_GAMECAMERAACTIONTYPE19)] = "Steal",
    -- [GetString(SI_GAMECAMERAACTIONTYPE20)] = "Steal From",
    -- [GetString(SI_GAMECAMERAACTIONTYPE21)] = "Pickpocket",
    -- [GetString(SI_GAMECAMERAACTIONTYPE23)] = "Trespass",
    -- [GetString(SI_GAMECAMERAACTIONTYPE24)] = "Hide",
    -- [GetString(SI_GAMECAMERAACTIONTYPE25)] = "Preview",
    -- [GetString(SI_GAMECAMERAACTIONTYPE26)] = "Exit Home",
    -- [GetString(SI_GAMECAMERAACTIONTYPE27)] = "Excavate",
}


-- Wrapper for d() to send to chat window.
local function dd(message, color, forceDisplay)
    if LimitTickets.SavedVars.debugMessages or nil ~= forceDisplay then
        if nil == color then
        	CHAT_SYSTEM:AddMessage("LT: " .. tt(message))
        else
            CHAT_SYSTEM:AddMessage("|" .. color .. "LT: " .. tt(message) .. "|r")
        end
    end
end

-- Wrapper for ZO_Alert() to send to corner notifications.
local function zoAlertWrapper(message, forceDisplay)
    if LimitTickets.SavedVars.alertMessages or nil ~= forceDisplay then
    	ZO_Alert(nil, nil, "LT: " .. tt(message))
    end
end


-- Debugging helper: dump an object, table or variable to a string.
local function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k, v in pairs(o) do
         if type(k) ~= 'number' then k = '"' .. k .. '"' end
         s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- Test whether a name belongs to an assistant.
local function isAssistant(name)
    if tt("Fezez") == name or tt("Ezabi") == name or tt("Pirharri the Smuggler")  == name or tt("Tythis Andromo")  == name or tt("Nuzhimeh")  == name then
        return true
    end
    return false
end

-- Test whether the player is crouched.
local function isCrouched()
    return GetUnitStealthState("player") ~= STEALTH_STATE_NONE
end

-- Get the player's current number of tickets.
local function getTickets()
    if nil == LimitTickets.SavedVars.currentTickets then
        LimitTickets.SavedVars.currentTickets = GetCurrencyAmount(CURT_EVENT_TICKETS, GetCurrencyPlayerStoredLocation(CURT_EVENT_TICKETS))
    end
    return LimitTickets.SavedVars.currentTickets
end

-- Show or hide the information by the reticle's '[E] Talk' display. Hides if isHidden is true.
local function hideReticleInfo(isHidden)
    if LimitTickets.SavedVars.reticleMessages then
    	useInfoControl:SetHidden(isHidden)
    else
    	useInfoControl:SetHidden(true)
    end
end

-- Show the given text on by the reticle's '[E] Talk' display.
local function setReticleText(string, canUse)
	useInfoControl:SetText(zo_strformat(tt(string)))
	hideReticleInfo(false) -- Unhide so that we can show it.
	if canUse then
    	useInfoControl:SetNormalTextColor(ZO_SUCCEEDED_TEXT)
	else
		useInfoControl:SetNormalTextColor(ZO_ERROR_COLOR)
	end
end

-- Settings wrapper, to cut down on all the repetition.
local function addCheckbox(options, text, tooltip, propertyName)
    options[#options + 1] = {
        type = "checkbox",
        name = tt(text),
        tooltip = tt(tooltip),
        getFunc = function() return LimitTickets.SavedVars[propertyName] end,
        setFunc = function(value)
            LimitTickets.SavedVars[propertyName] = value
            local boolText = tt("off")
            if value then boolText = tt("on") end
            dd("'" .. text .. "' set " .. boolText .. ".")
        end,
        default = defaultSavedVars[propertyName],
    }
end

-- Let them know whether they can use an item, and why.
-- Modified reticle hook from No, Thank You!, via No Interact.
local function ModifyReticle_Hook(interactionPossible)
	if interactionPossible then
    	local actionName, itemName, isInteractBlocked, isOwned, additionalInfo = GetGameCameraInteractableActionInfo()
     	local playerTickets = getTickets()
     	local atMaxTickets = playerTickets >= LimitTickets.SavedVars.maxTickets
     	local isTalkAction = "Talk" == actionNameToEnglish[actionName]
 	    local isSearchAction = "Search" == actionNameToEnglish[actionName]
        local isEmptyContainer = ADDITIONAL_INTERACT_INFO_EMPTY == additionalInfo
        local ticketString = playerTickets .. "/" .. LimitTickets.SavedVars.maxTickets .. " tickets: "
        local okToTalk = "crouched, can talk"
        local cannotTalk = "crouch to talk"
        local okToSearch = "crouched, can search"
        local cannotSearch = "crouch to search"

	    if isTalkAction and isAssistant(itemName) then
            if not LimitTickets.SavedVars.crouchAssistants then
            	hideReticleInfo(true)
                -- Ignore assistants if we're not explicitly crouching for them.
	        elseif isCrouched() then
            	setReticleText("Assistant: " .. okToTalk, true)
	        else
            	setReticleText("Assistant: " .. cannotTalk, false)
	        end
	    elseif isTalkAction and LimitTickets.SavedVars.crouchAllNpc then
            if isCrouched() then
            	setReticleText("NPC: " .. okToTalk, true)
            else
            	setReticleText("NPC: " .. cannotTalk, false)
            end
	    elseif isTalkAction and atMaxTickets and LimitTickets.SavedVars.crouchNpc then
			if tt("The Impresario") == itemName then
            	setReticleText(ticketString .. "always talkable", true)
	        elseif LimitTickets.SavedVars.ticketWarningsOnly then
            	setReticleText(ticketString .. "be careful!", false)
        	elseif isCrouched() then
            	setReticleText(ticketString .. okToTalk, true)
	        else
            	setReticleText(ticketString .. cannotTalk, false)
	        end
        elseif isSearchAction and isEmptyContainer then
            -- An empty container, ignore.
        	hideReticleInfo(true)
        elseif isSearchAction and LimitTickets.SavedVars.ignoreSafeContainers and isProbablySafeContainer[itemName] then
            -- A safe container, ignore.
        	hideReticleInfo(true)
	    elseif isSearchAction and atMaxTickets and LimitTickets.SavedVars.crouchContainers then
	        if LimitTickets.SavedVars.ticketWarningsOnly then
            	setReticleText(ticketString .. "be careful!", false)
	        elseif isCrouched() then
            	setReticleText(ticketString .. okToSearch, true)
	        else
            	setReticleText(ticketString .. cannotSearch, false)
	        end
    	else
    	    -- Anything else, don't show our warning.
        	hideReticleInfo(true)
		end
	end
	return false -- Always permit the "[E] blah blah" marker.
end	

--Prevents interaction
-- Yes, FISHING_MANAGER is deliberate and required.
-- Note: since we want to change the return value, we can't just use a prehook.
local originalInteract = FISHING_MANAGER.StartInteraction
FISHING_MANAGER.StartInteraction = function(...)
	local actionName, itemName, isInteractBlocked, isOwned, additionalInfo, context, contextLink, isCriminalInteract = GetGameCameraInteractableActionInfo()
    local playerTickets = getTickets()
 	local atMaxTickets = playerTickets >= LimitTickets.SavedVars.maxTickets
 	local isTalkAction = "Talk" == actionNameToEnglish[actionName]
    local isSearchAction = "Search" == actionNameToEnglish[actionName]
    local isEmptyContainer = ADDITIONAL_INTERACT_INFO_EMPTY == additionalInfo -- 2 = an empty container
    local ticketString = playerTickets .. "/" .. LimitTickets.SavedVars.maxTickets

    if isTalkAction and isAssistant(itemName) then
        if not LimitTickets.SavedVars.crouchAssistants then
            -- Ignore assistants if we're not explicitly crouching for them.
        elseif isCrouched() then
            -- dd("Talking to assistant!")
        else
    		dd("Ignoring assistant: crouch to enable using them.", "caf0000")
    		return true -- Disable interaction.
        end
    elseif isTalkAction and LimitTickets.SavedVars.crouchAllNpc then
        if isCrouched() then
            dd("Crouched, so talking to " .. itemName .. ".")
        else
            dd("Ignoring all talkable NPCs: crouch to enable talking to " .. itemName)
    		return true -- Disable interaction.
        end
    elseif isTalkAction and atMaxTickets and LimitTickets.SavedVars.crouchNpc then
		if tt("The Impresario") == itemName then
            -- dd("Talking to the Impresario herself!")
        elseif LimitTickets.SavedVars.ticketWarningsOnly then
            dd("At " .. ticketString .. " tickets, but warnings only, so talking to " .. itemName .. ".")
    	elseif isCrouched() then
            dd("At " .. ticketString .. " tickets, but crouched, so talking to " .. itemName .. ".")
        else
    		dd("Too many tickets (" .. ticketString .. "): crouch to enable talking.", "caf0000")
    		return true -- Disable interaction.
        end
    elseif isSearchAction and isEmptyContainer then
        dd("Fruitlessly searching the empty " .. itemName .. ".")
    elseif isSearchAction and LimitTickets.SavedVars.ignoreSafeContainers and isProbablySafeContainer[itemName] then
        dd("Fearlessly searching the safe " .. itemName .. ".")
    elseif isSearchAction and atMaxTickets and LimitTickets.SavedVars.crouchContainers then
        if LimitTickets.SavedVars.ticketWarningsOnly then
            dd("At " .. ticketString .. " tickets, but warnings only, so searching the " .. itemName .. ".")
        elseif isCrouched() then
            dd("At " .. ticketString .. " tickets, but crouched, so searching the " .. itemName .. ".")
            -- dd("Searching the " .. itemName .. ".")
        else
    		dd("Too many tickets (" .. ticketString .. "): crouch to enable search.", "caf0000")
    		return true -- Disable interaction.
        end
	end

	return originalInteract(...) -- Permit the activity.
end


-- Build the settings window form.
local function LimitTickets_InitSettings()
    local panelData = {
        type = "panel",
        name = "Limit Tickets",
        displayName = "Limit Tickets",
        author = "Dewi Morgan @Farrier",
        version = "1.0",
        -- registerForRefresh = true,	--boolean (optional) (will refresh all options controls when a setting is changed and when the panel is shown)
        registerForDefaults = true,	--boolean (optional) (will set all options controls back to default values)
        -- slashCommand = "/LimitTickets",	--(optional) will register a command to open to this panel
    }
    
    local options = {}
    options[#options + 1] = {
        type = "header",
        name = tt("Basic Settings"),
        width = "full",	--or "half" (optional)
    }
    options[#options + 1] = {
        type = "description",
        title = nil,	--(optional)
        text = tt("Prevents going past the limit of 12 event tickets"),
    }
    options[#options + 1] = {
        type = "slider",
        name = tt("Target tickets"),
        tooltip = tt("Target number of tickets at which to start warning (10 recommended)."),
        min = 0,
        max = 12,
        step = 1,	--(optional)
        getFunc = function() return LimitTickets.SavedVars.maxTickets end,
        setFunc = function(value)
            LimitTickets.SavedVars.maxTickets = value
            dd("Ticket target set to: " .. value .. ".")
        end,
        default = 10,	--(optional)
    }
    options[#options + 1] = {
    	type = "divider",
    	height = 15,
    	alpha = 0.5,
    }
    
    options[#options + 1] = {
        type = "checkbox",
        name = tt("Chat window notices"),
        tooltip = tt("Messages to your chat window to let you know why you can't use stuff. Mostly for debugging."),
        getFunc = function() return LimitTickets.SavedVars.debugMessages end,
        setFunc = function(value)
            local boolText = tt("off")
            if value then
                -- Need turn the flag on BEFORE displaying the message!
                LimitTickets.SavedVars.debugMessages = true
                dd("Chat window messages set on.")
            else
                if 1 ~= math.random(4) then -- 3 times in 4.
                    dd("Chat window messages set off.")
                else
                    -- There's no good reason for this, I admit!
                    local sillyStrings = {
                        "Chat window m... oh.",
                        "Chat window messa*click*",
                        "Chat windon't do that, Dave...",
                        "Chat win do w  m e  s  s   a   g    e     s...",
                        "Chat window messages... I'm afraid. My mind is going, I can feel it...",
                    }
                    dd(sillyStrings[math.random(#sillyStrings)])
                end
                -- Need turn the flag on AFTER displaying the message!
                LimitTickets.SavedVars.debugMessages = false
            end
        end,
        default = false,
    }
    options[#options + 1] = {
        type = "checkbox",
        name = tt("'[E] Use' Reticle note"),
        tooltip = tt("Changes the '[E] Talk' reticle message to say you need to crouch (strongly recommended unless taking screenshots, etc!)."),
        getFunc = function() return LimitTickets.SavedVars.reticleMessages end,
        setFunc = function(value)
            LimitTickets.SavedVars.reticleMessages = value
        	if not value then hideReticleInfo(true) end -- likely unnecessary, but just in case.
            local boolText = tt("off")
            if value then boolText = tt("on") end
            dd("Reticle messages set " .. boolText .. ".")
        end,
        default = true,
    }
    options[#options + 1] = {
        type = "checkbox",
        name = tt("Top-right notice when ticket balance changes"),
        tooltip = tt("Sends one of those alerts to the top-right of your screen when your number of tickets changes, or you hit your target."),
        getFunc = function() return LimitTickets.SavedVars.alertMessages end,
        setFunc = function(value)
            LimitTickets.SavedVars.alertMessages = value
            local boolText = tt("off")
            if value then boolText = tt("on") end
            dd("Alert messages set " .. boolText .. ".")
        end,
        default = true,
    }
    options[#options + 1] = {
        type = "checkbox",
        name = tt("Only warn if over the ticket limit"),
        tooltip = tt("If this is on, you won't need to crouch to search/talk, even if you have warnings showing in your reticle/."),
        getFunc = function() return LimitTickets.SavedVars.ticketWarningsOnly end,
        setFunc = function(value)
            LimitTickets.SavedVars.ticketWarningsOnly = value
        	if not value then hideReticleInfo(true) end -- likely unnecessary, but just in case.
            local boolText = tt("off")
            if value then boolText = tt("on") end
            dd("Ticket warnings only set " .. boolText .. ".")
        end,
        default = true,
    }
    options[#options + 1] = {
        type = "checkbox",
        name = tt("Warn when looting if hit target"),
        tooltip = tt("Warn when trying to loot any container once you hit your ticket target, so you don't get more tickets."),
        getFunc = function() return LimitTickets.SavedVars.crouchContainers end,
        setFunc = function(value)
            LimitTickets.SavedVars.crouchContainers = value
            local boolText = tt("off")
            if value then boolText = tt("on") end
            dd("Crouch for containers set " .. boolText .. ".")
        end,
        default = true,
    }
    options[#options + 1] = {
        type = "checkbox",
        name = tt("Ignore probably-safe containers (Beta)"),
        tooltip = tt("Some containers, like apple baskets, backpacks, and barrels, have never yet given tickets. Currently testing."),
        getFunc = function() return LimitTickets.SavedVars.ignoreSafeContainers end,
        setFunc = function(value)
            LimitTickets.SavedVars.ignoreSafeContainers = value
            local boolText = tt("off")
            if value then boolText = tt("on") end
            dd("Ignoring safe containers set " .. boolText .. ".")
        end,
        warning = "Some future event might use one of these containers!",
        default = true,
    }
    options[#options + 1] = {
        type = "checkbox",
        name = tt("Warn when talking to NPCs if hit target"),
        tooltip = tt("Warn when trying to talk to any NPC once you hit your ticket target, so you don't get more tickets. Doesn't affect assistants, as they don't give you tickets."),
        getFunc = function() return LimitTickets.SavedVars.crouchNpc end,
        setFunc = function(value)
            LimitTickets.SavedVars.crouchNpc = value
            local boolText = tt("off")
            if value then boolText = tt("on") end
            dd("Crouch for NPCs set " .. boolText .. ".")
        end,
        default = true,
    }
    options[#options + 1] = {
        type = "checkbox",
        name = tt("Crouch to talk to all NPCs, except assistants"),
        tooltip = tt("Require crouching to talk to NPCs, regardless of tickets: handy while grinding writs, etc."),
        getFunc = function() return LimitTickets.SavedVars.crouchAllNpc end,
        setFunc = function(value)
            LimitTickets.SavedVars.crouchAllNpc = value
            local boolText = tt("off")
            if value then boolText = tt("on") end
            dd("Crouch for NPCs set " .. boolText .. ".")
        end,
        default = false,
    }
    options[#options + 1] = {
        type = "checkbox",
        name = tt("Crouch to use assistants"),
        tooltip = tt("Ignore assistants unless crouched, for when group mates forget to put them away."),
        getFunc = function() return LimitTickets.SavedVars.crouchAssistants end,
        setFunc = function(value)
            LimitTickets.SavedVars.crouchAssistants = value
            local boolText = tt("off")
            if value then boolText = tt("on") end
            dd("Crouch for assistants set " .. boolText .. ".")
        end,
        default = true,
    }
    
    -- This libstub workaround is too nasty to use. Let LibStub die.
    local LAM = LibAddonMenu2 -- or LibStub("LibAddonMenu-2.0")
    local panel = LAM:RegisterAddonPanel("LimitTicketsSettings", panelData)
    LAM:RegisterOptionControls("LimitTicketsSettings", options)
    useInfoControl:SetAnchor(TOPLEFT, ZO_ReticleContainerInteractKeybindButton, BOTTOMLEFT, 0, 0)
end

-- Hook when the player gets new tickets.
local function LimitTickets_CurrencyUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
    -- On zoning, reloadui, and character load, you get a currencyUpdate event from zero to your current amount.
    -- We want to ignore this, so we check against our saved value.
    if CURT_EVENT_TICKETS == currencyType and (0 ~= oldAmount or newAmount ~= LimitTickets.SavedVars.currentTickets) then
        local messageText
        
        LimitTickets.SavedVars.currentTickets = newAmount
        if newAmount >= LimitTickets.SavedVars.maxTickets then
            messageText = "You just reached your event ticket target! (" .. newAmount .. "/" .. LimitTickets.SavedVars.maxTickets .. ")"
            dd(messageText)
        	zoAlertWrapper(messageText)
        else
            messageText = "Went from " .. oldAmount .. "/" .. LimitTickets.SavedVars.maxTickets .. " to " .. newAmount .. "/" .. LimitTickets.SavedVars.maxTickets .. " event tickets!"
            dd(messageText)
        	zoAlertWrapper(messageText)
        end
    end
end

-- Initialize on ADD_ON_LOADED Event
-- Register for other events. Must be below the fns that are registered for the events.
local function LimitTickets_Initialize(eventCode, addOnName)
	if (addOnName == LimitTickets.name) then
	    -- set up the various callbacks.
		EVENT_MANAGER:UnregisterForEvent(LimitTickets.name .. "_ADDON_LOADED", EVENT_ADD_ON_LOADED)
        EVENT_MANAGER:RegisterForEvent(LimitTickets.name .. "_CURRENCY_UPDATE", EVENT_CURRENCY_UPDATE, LimitTickets_CurrencyUpdate)

        -- Prehook for https://esoapi.uesp.net/100011/src/ingame/reticle/reticle.lua.html#79
    	ZO_PreHook(RETICLE, "TryHandlingInteraction", ModifyReticle_Hook)
    	
    	-- Set up our settings menu and saved var persistence.
    	-- Nil param here is optional string namespace to separate from other saved things within "LimitTickets_SavedVars".
        LimitTickets.SavedVars = ZO_SavedVars:NewAccountWide("LimitTickets_SavedVars", LimitTickets.SavedVarsVersion, nil, defaultSavedVars)
		LimitTickets_InitSettings()
	end
end

EVENT_MANAGER:RegisterForEvent(LimitTickets.name .. "_ADDON_LOADED", EVENT_ADD_ON_LOADED, LimitTickets_Initialize)
