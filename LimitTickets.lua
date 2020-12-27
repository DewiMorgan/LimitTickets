--[[
	LimitTickets
	==========================================
	Restrict the number of event tickets that can be gained to some number like 10.
	==========================================
]]--

--[[ Dev notes:
ToDo: Hook FishingManager (the parent class), not FISHING_MANAGER (the instance). IMPORTANT, might break other addons otherwise?
ToDo: Code Cleanup: Better hooking.
ToDo: Feature: Internationalization.
ToDo:          - actually translate text in tt().
ToDo:           "Use the txt files language constant to auto load the lang.Lua file
And in there do not use GetString constants but add the texts to your addons global namespace lang table
Just as strings
Would be an advantage if you want access to all texts of all languages at the same time
" - Baertram
ToDo: Name local "class" vars something nicer.
ToDo: Actually use a class, and OOP? https://www.lua.org/pil/16.1.html

ToDo: Bug: If you log out while stealthed, you'll be standing but stealthed (eye reticle, unable to mount, etc) when you log in. This is ESO's bug, not mine!
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
LimitTickets.shortName = "LT" -- Not guaranteed unique, but OK for tagging messages, etc.
LimitTickets.version = "v1.2.0"
LimitTickets.SavedVarsVersion = "1" -- If this changes, older saved vars are WIPED.
LimitTickets.SavedVars = {} -- The actual real data.

local DEBUG = false

local options = {} -- The LibAddonMenu options page.
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

-- Show or hide the information by the reticle's '[E] Talk' display. Hides if isHidden is true.
local function hideReticleInfo(isHidden)
    if LimitTickets.SavedVars.reticleMessages then
    	useInfoControl:SetHidden(isHidden)
    else
    	useInfoControl:SetHidden(true)
    end
end

local function dx(...)
    if DEBUG then
        d(...)
    end
end

-- Wrapper for d() to send to chat window.
local function dd(...)
    if LimitTickets.SavedVars.debugMessages then
        CHAT_SYSTEM:AddMessage(string.format("%s: %s", LimitTickets.shortName, zo_strformat(...)))
    end
end
local function derr(...)
    if LimitTickets.SavedVars.debugMessages then
        CHAT_SYSTEM:AddMessage(string.format("|caf0000%s: %s|r", LimitTickets.shortName, zo_strformat(...)))
    end
end

-- Wrapper for ZO_Alert() to send to corner notifications.
local function zoAlertWrapper(...)
    if LimitTickets.SavedVars.alertMessages then
    	ZO_Alert(nil, nil, string.format("%s: %s", LimitTickets.shortName, zo_strformat(...)))
    end
end

-- Show the given text on the reticle's '[E] Talk' display.
local function setReticleText(canUse, ...)
	useInfoControl:SetText(zo_strformat(...))
	hideReticleInfo(false) -- Unhide so that we can show it.
	if canUse then
    	useInfoControl:SetNormalTextColor(ZO_SUCCEEDED_TEXT)
	else
		useInfoControl:SetNormalTextColor(ZO_ERROR_COLOR)
	end
end

-- Test whether a name belongs to an assistant.
local function isAssistant(name)
    return (
        tt("Fezez") == name or 
        tt("Ezabi") == name or
        tt("Pirharri the Smuggler") == name or
        tt("Tythis Andromo") == name or
        tt("Nuzhimeh") == name
    )
end

-- Test whether a name belongs to an impresario.
local function isImpresario(name)
    return tt("The Impresario") == name
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
        local ticketFormat = string.format(
            "%s/%s tickets <<1>>", -- Could use SI_JOURNAL_PROGRESS_BAR_PROGRESS or SI_ZONE_STORY_ACTIVITY_COMPLETION_VALUES
            ZO_LocalizeDecimalNumber(playerTickets),
            ZO_LocalizeDecimalNumber(LimitTickets.SavedVars.maxTickets)
        )
        local assistantFormat = "Assistant: <<1>>"
        local npcFormat =  "NPC: <<1>>"
        local beCareful = "be careful!"
        local okToTalk = "crouched, can talk"
        local cannotTalk = "crouch to talk"
        local alwaysTalk = "always talkable"
        local okToSearch = "crouched, can search"
        local cannotSearch = "crouch to search"

        if not LimitTickets.SavedVars.reticleMessages then
        	hideReticleInfo(true)
	    elseif isTalkAction and isAssistant(itemName) then
            if not LimitTickets.SavedVars.crouchAssistants then
            	hideReticleInfo(true)
                -- Ignore assistants if we're not explicitly crouching for them.
	        elseif isCrouched() then
            	setReticleText(true, assistantFormat, okToTalk)
	        else
            	setReticleText(false, assistantFormat, cannotTalk)
	        end
	    elseif isTalkAction and LimitTickets.SavedVars.crouchAllNpc then
            if isCrouched() then
            	setReticleText(true, npcFormat, okToTalk)
            else
            	setReticleText(false, npcFormat, cannotTalk)
            end
	    elseif isTalkAction and atMaxTickets and LimitTickets.SavedVars.crouchNpc then
			if isImpresario(itemName) then
            	setReticleText(true, ticketFormat, alwaysTalk)
	        elseif LimitTickets.SavedVars.ticketWarningsOnly then
            	setReticleText(false, ticketFormat, beCareful)
        	elseif isCrouched() then
            	setReticleText(true, ticketFormat, okToTalk)
	        else
            	setReticleText(false, ticketFormat, cannotTalk)
	        end
        elseif isSearchAction and isEmptyContainer then
            -- An empty container, ignore.
        	hideReticleInfo(true)
        elseif isSearchAction and LimitTickets.SavedVars.ignoreSafeContainers and isProbablySafeContainer[itemName] then
            -- A safe container, ignore.
        	hideReticleInfo(true)
	    elseif isSearchAction and atMaxTickets and LimitTickets.SavedVars.crouchContainers then
	        if LimitTickets.SavedVars.ticketWarningsOnly then
            	setReticleText(false, ticketFormat, beCareful)
	        elseif isCrouched() then
            	setReticleText(true, ticketFormat, okToSearch)
	        else
            	setReticleText(false, ticketFormat, cannotSearch)
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
    
dx("Clicked, maybe even on a thing!")

    local ticketString = string.format(
        "%s/%s", -- Could use SI_JOURNAL_PROGRESS_BAR_PROGRESS or SI_ZONE_STORY_ACTIVITY_COMPLETION_VALUES
        ZO_LocalizeDecimalNumber(playerTickets),
        ZO_LocalizeDecimalNumber(LimitTickets.SavedVars.maxTickets)
    )
dx("Ticketstring: " .. ticketString)
dx("itemName: " .. itemName)

    if isTalkAction and isAssistant(itemName) then
dx("1")
        if not LimitTickets.SavedVars.crouchAssistants then
dx("1.1")
            -- Freely use assistants if we're not explicitly crouching for them.
        elseif isCrouched() then
dx("1.2")
            -- Talk to assistant
        else
dx("1.3")
    		derr("Assistant: crouch to enable using.")
    		return true -- Disable interaction.
        end
    elseif isTalkAction and LimitTickets.SavedVars.crouchAllNpc then
dx("2")
        if isCrouched() then
dx("2.1")
            dd("Crouched, so talking to <<C:1>>." , itemName)
        else
dx("2.2")
            dd("Ignoring all talkable NPCs: crouch to enable talking to <<C:1>>.", itemName)
    		return true -- Disable interaction.
        end
    elseif isTalkAction and atMaxTickets and LimitTickets.SavedVars.crouchNpc then
dx("3")
		if isImpresario(itemName) then
dx("3.1")
            -- dd("Talking to the Impresario herself!")
        elseif LimitTickets.SavedVars.ticketWarningsOnly then
dx("3.2")
            dd("At <<1>> tickets, but warnings only, so talking to <<C:2>>." , ticketString, itemName)
    	elseif isCrouched() then
dx("3.3")
            dd("At <<1>> tickets, but crouched, so talking to <<C:2>>.", ticketString, itemName)
        else
dx("3.4")
    		derr("Too many tickets (<<1>>): crouch to enable talking.", ticketString)
    		return true -- Disable interaction.
        end
    elseif isSearchAction and isEmptyContainer then
dx("4")
        dd("Fruitlessly searching the empty <<1>>.", itemName)
    elseif isSearchAction and LimitTickets.SavedVars.ignoreSafeContainers and isProbablySafeContainer[itemName] then
dx("5")
        dd("Fearlessly searching the safe <<1>>.", itemName)
    elseif isSearchAction and atMaxTickets and LimitTickets.SavedVars.crouchContainers then
dx("6")
        if LimitTickets.SavedVars.ticketWarningsOnly then
dx("6.1")
            dd("At <<1>> tickets, but warnings only, so searching the <<C:2>>.", ticketString, itemName)
        elseif isCrouched() then
dx("6.2")
            dd("At <<1>> tickets, but crouched, so searching the <<C:2>>.", ticketString, itemName)
            -- dd("Searching the <<C:1>>.", itemName)
        else
dx("6.3")
    		derr("Too many tickets (<<1>>): crouch to enable search.", ticketString)
    		return true -- Disable interaction.
        end
	end
dx("end click")

	return originalInteract(...) -- Permit the activity.
end

-- Hook when the player gets new tickets.
local function LimitTickets_CurrencyUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
    -- On zoning, reloadui, and character load, you get a currencyUpdate event from zero to your current amount.
    -- We want to ignore this, so we check against our saved value.
    if CURT_EVENT_TICKETS == currencyType and (0 ~= oldAmount or newAmount ~= LimitTickets.SavedVars.currentTickets) then
        local messageText
        
        LimitTickets.SavedVars.currentTickets = newAmount
        if newAmount >= LimitTickets.SavedVars.maxTickets then
            messageText = zo_formatstring("You just reached your event ticket target! (<<1>>/<<2>>).", newAmount, LimitTickets.SavedVars.maxTickets)
            dd(messageText)
        	zoAlertWrapper(messageText, newAmount, LimitTickets.SavedVars.maxTickets)
        else
            messageText = zo_formatstring("Went from <<1>>/<<2>> to <<3>>/<<4>> event tickets!", oldAmount, LimitTickets.SavedVars.maxTickets, newAmount, LimitTickets.SavedVars.maxTickets)
            dd(messageText)
        	zoAlertWrapper(messageText)
        end
    end
end

-- Settings wrapper for checkboxes, to cut down on all the repetition.
local function addCheckbox(propertyName, text, tooltip)
    options[#options + 1] = {
        type = "checkbox",
        name = tt(text),
        tooltip = tt(tooltip),
        getFunc = function() return LimitTickets.SavedVars[propertyName] end,
        setFunc = function(value)
            -- Differing order here only matters if we're toggling dd() itself.
            if value then
                LimitTickets.SavedVars[propertyName] = value
                dd("'<<1>>' set <<2>>.", text, GetString(SI_CHECK_BUTTON_ON))
            else
                dd("'<<1>>' set <<2>>.", text, GetString(SI_CHECK_BUTTON_OFF))
                LimitTickets.SavedVars[propertyName] = value
            end
        end,
        default = defaultSavedVars[propertyName],
    }
end

-- Settings wrapper for headers, to cut down on all the repetition.
local function addHeader(text) 
    options[#options + 1] = {
        type = "header",
        name = tt(text),
        width = "full",
    }
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
    
    addHeader("Limit")
    options[#options + 1] = {
        type = "description",
        title = nil,	--(optional)
        text = tt("Setting a limit prevents going past the limit of 12 event tickets, and hence losing the extra tickets before you spend them."),
    }
    
    options[#options + 1] = {
        type = "slider",
        name = tt("Target tickets"),
        tooltip = tt("Target number of tickets at which to start warning. Recommented: 10, or (13, minus the most tickets you can get with one action in the current event, usually 3)."),
        min = 0,
        max = 12,
        getFunc = function() return LimitTickets.SavedVars.maxTickets end,
        setFunc = function(value)
            LimitTickets.SavedVars.maxTickets = value
            dd("Ticket target set to: <<1>>.", value)
        end,
        default = defaultSavedVars.maxTickets,
    }

    addHeader("Output options")
    addCheckbox("reticleMessages",      "Warnings by the '[E] Use' Reticle note",  "Changes the '[E] Talk' reticle message to say you need to crouch (strongly recommended unless taking screenshots, etc!).")
    addCheckbox("alertMessages",        "Notice at Top-right when ticket balance changes",  "Sends one of those alerts to the top-right of your screen when your number of tickets changes, or you hit your target.")
    addCheckbox("debugMessages",        "Messages in chat window",  "Messages to your chat window to let you know why you can't use stuff. Mostly for debugging.")

    addHeader("Behavior once the ticket limit is reached")
    addCheckbox("crouchNpc",            "Block talking to NPCs if hit target",  "Warn when trying to talk to any NPC once you hit your ticket target, so you don't get more tickets. Doesn't affect assistants, as they don't give you tickets.")
    addCheckbox("crouchContainers",     "Block looting if hit target",  "When trying to loot any container once you hit your ticket target, so you don't get more tickets.")
    addCheckbox("ignoreSafeContainers", "Ignore probably-safe containers",  "Some containers, like apple baskets, backpacks, and barrels, have never yet given tickets, so should be safe to loot freely.")
    addCheckbox("ticketWarningsOnly",   "Warnings only, don't block actions", "If this is on, you won't need to crouch to search/talk, but you'll still see any enabled messages in the reticle, alerts, and/or chat window.")
 
    addHeader("Constant Behavior")
    addCheckbox("crouchAssistants",     "Crouch to use assistants",  "Ignore assistants unless crouched, for when group mates forget to put them away.")
    addCheckbox("crouchAllNpc",         "Crouch to talk to all NPCs, except assistants",  "Require crouching to talk to NPCs: handy while grinding writs, etc.")

    local LAM = LibAddonMenu2
    local panel = LAM:RegisterAddonPanel("LimitTicketsSettings", panelData)
    LAM:RegisterOptionControls("LimitTicketsSettings", options)
    useInfoControl:SetAnchor(TOPLEFT, ZO_ReticleContainerInteractKeybindButton, BOTTOMLEFT, 0, 0)
end

-- Initialize on ADD_ON_LOADED Event
-- Register for other events. Must be below the fns that are registered for the events.
local function LimitTickets_Initialize(eventCode, addOnName)
	if (addOnName == LimitTickets.name) then
	    -- set up the various callbacks.
		EVENT_MANAGER:UnregisterForEvent(string.format("%s_%s", LimitTickets.name, "ADDON_LOADED"), EVENT_ADD_ON_LOADED)
        EVENT_MANAGER:RegisterForEvent(string.format("%s_%s", LimitTickets.name, "CURRENCY_UPDATE"), EVENT_CURRENCY_UPDATE, LimitTickets_CurrencyUpdate)

        -- Prehook for https://esoapi.uesp.net/100011/src/ingame/reticle/reticle.lua.html#79
    	ZO_PreHook(RETICLE, "TryHandlingInteraction", ModifyReticle_Hook)
    	
    	-- Set up our settings menu and saved var persistence.
    	-- Nil param here is optional string namespace to separate from other saved things within "LimitTickets_SavedVars".
        LimitTickets.SavedVars = ZO_SavedVars:NewAccountWide("LimitTickets_SavedVars", LimitTickets.SavedVarsVersion, nil, defaultSavedVars)
		LimitTickets_InitSettings()
	end
end

EVENT_MANAGER:RegisterForEvent(string.format("%s_%s", LimitTickets.name, "ADDON_LOADED"), EVENT_ADD_ON_LOADED, LimitTickets_Initialize)
