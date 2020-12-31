--[[
	LimitTickets
	==========================================
	Restrict the number of event tickets that can be gained to some number like 10.
	==========================================
]]--

LimitTickets = {}
-- If changing any of these, remember to upgrade the .txt file, too.
LimitTickets.name = "LimitTickets"
LimitTickets.displayName = "Limit Tickets"
LimitTickets.author = "Dewi Morgan @Farrier"
LimitTickets.shortName = "LT" -- Not guaranteed unique, but OK for tagging messages, etc.
LimitTickets.version = "1.2.0"
LimitTickets.description = "This addon causes actions with potentially annoying effects (such as getting too many tickets) to warn you and/or require you to crouch before doing them."

LimitTickets.SavedVarsVersion = "1" -- If this changes, older saved vars are WIPED.
LimitTickets.SavedVars = {} -- The actual real data.

--local DEBUG = false
--local function dx(...)
--    if DEBUG then
--        d(...)
--    end
--end

local lamOptions = {} -- The LibAddonMenu options page.

local defaultSavedVars = { -- Will be created in save file if not found, but won't override existing values.
    -- Config settings.
    maxTickets = 10,
    debugMessages = false,
    alertMessages = true,
    reticleMessages = true,
    ticketWarningsOnly = false,
    crouchAssistants = true,
    crouchContainers = true,
    crouchNpc = true,
    crouchAllNpc = false,
    ignoreSafeContainers = true,
    -- Non-settings, just stored data.
    currentTickets = nil,
}

-- Local vars
-- Modified "Stealth to..." control from NoAccidentalStealing.
local reticleInfoLabel = CreateControlFromVirtual("UseInfo", ZO_ReticleContainerInteract, "ZO_KeybindButton")

-- Safe containers, not corpses or consolidate area loot. Ideally, we would just detect corpses and mark them as UN-safe.
local probablySafeContainerLookup = {
    ["Apple Basket"]   = true,
    ["Apple Crate"]    = true,
    ["Apples"]         = true,
    ["Backpack"]       = true,
    ["Bookshelf"]      = true,
    ["Barrel"]         = true,
    ["Barrels"]        = true,
    ["Basket"]         = true,
    ["Cabinet"]        = true,
    ["Cauldron"]       = true,
    ["Cupboard"]       = true,
    ["Corn Basket"]    = true,
    ["Crate"]          = true,
    ["Crates"]         = true,
    ["Desk"]           = true,
    ["Drawers"]        = true,
    ["Dresser"]        = true,
    ["Flour Sack"]     = true,
    ["Greens Basket"]  = true,
    ["Heavy Crate"]    = true,
    ["Heavy Sack"]     = true,
    ["Jewelry Box"]    = true,
    ["Keg"]            = true,
    ["Loose Tile"]     = true,
    ["Melon Basket"]   = true,
    ["Millet Basket"]  = true,
    ["Nightstand"]     = true,
    ["Pumpkin Basket"] = true,
    ["Rack"]           = true,
    ["Rubble"]         = true,
    ["Sack"]           = true,
    ["Saltrice Sack"]  = true,
    ["Seasoning Sack"] = true,
    ["Tomato Crate"]   = true,
    ["Trunk"]          = true,
    ["Urn"]            = true,
    ["Wardrobe"]       = true,
}
local assistantLookup = {
    ["Fezez"]                 = true,
    ["Ezabi"]                 = true,
    ["Pirharri the Smuggler"] = true,
    ["Tythis Andromo"]        = true,
    ["Nuzhimeh"]              = true,
}
local impresarioLookup = {
    ["The Impresario"] = true,
}

-- Uses GetString() constants, so I18N'd. Unrecognized values will be Nil!
local actionNameToEnglishLookup = {
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
    	reticleInfoLabel:SetHidden(isHidden)
    else
    	reticleInfoLabel:SetHidden(true)
    end
end

-- Wrapper for d() to send to chat window.
local function chatText(...)
    if LimitTickets.SavedVars.debugMessages then
        CHAT_SYSTEM:AddMessage(string.format("%s: %s", LimitTickets.shortName, zo_strformat(...)))
    end
end
local function chatError(...)
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
	reticleInfoLabel:SetText(zo_strformat(...))
	hideReticleInfo(false)
	if canUse then
    	reticleInfoLabel:SetNormalTextColor(ZO_SUCCEEDED_TEXT)
	else
		reticleInfoLabel:SetNormalTextColor(ZO_ERROR_COLOR)
	end
end

-- Test whether a name belongs to an assistant.
local function isAssistant(name)
    return assistantLookup[name]
end

-- Test whether a name belongs to an impresario.
local function isImpresario(name)
    return impresarioLookup[name]
end

-- Test whether a name belongs to a container that's unlikely to give tickets.
local function isProbablySafeContainer(name)
    return probablySafeContainerLookup[name]
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
        -- actionName, itemName, isInteractBlocked, isOwned, additionalInfo, context, contextLink, isCriminalInteract
    	local actionName, itemName, _, _, additionalInfo = GetGameCameraInteractableActionInfo()
     	local playerTickets = getTickets()
     	local atMaxTickets = playerTickets >= LimitTickets.SavedVars.maxTickets
     	local isTalkAction = "Talk" == actionNameToEnglishLookup[actionName]
 	    local isSearchAction = "Search" == actionNameToEnglishLookup[actionName]
        local isEmptyContainer = ADDITIONAL_INTERACT_INFO_EMPTY == additionalInfo
        local ticketFormat = string.format(
            "%s/%s tickets <<1>>",
            ZO_LocalizeDecimalNumber(playerTickets),
            ZO_LocalizeDecimalNumber(LimitTickets.SavedVars.maxTickets)
        )
        local assistantFormat = "Assistant: <<1>>"
        local npcFormat =  "NPC: <<1>>"
        local beCareful = "be careful!"
        local okToTalk = "crouched, can talk"
        local cannotTalk = "crouch to talk"
        local alwaysTalk = "can always talk"
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
        elseif isSearchAction and LimitTickets.SavedVars.ignoreSafeContainers and isProbablySafeContainer(itemName) then
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


local originalStartInteraction
-- Prevents interaction.
-- @return Boolean True if interaction should NOT start, otherwise whatever the original fn did.
local function StartInteraction_hook(...)
	local actionName, itemName, _, _, additionalInfo, _, _, _ = GetGameCameraInteractableActionInfo()
    local playerTickets = getTickets()
 	local atMaxTickets = playerTickets >= LimitTickets.SavedVars.maxTickets
 	local isTalkAction = "Talk" == actionNameToEnglishLookup[actionName]
    local isSearchAction = "Search" == actionNameToEnglishLookup[actionName]
    local isEmptyContainer = ADDITIONAL_INTERACT_INFO_EMPTY == additionalInfo -- 2 = an empty container

    local ticketString = string.format("%s/%s", ZO_LocalizeDecimalNumber(playerTickets), ZO_LocalizeDecimalNumber(LimitTickets.SavedVars.maxTickets))

    if isTalkAction and isAssistant(itemName) then
        if not LimitTickets.SavedVars.crouchAssistants then
            -- Freely use assistants if we're not explicitly crouching for them.
        elseif isCrouched() then
            -- Talk to assistant
        else
    		chatError("Assistant: crouch to enable using.")
    		return true -- Disable interaction.
        end
    elseif isTalkAction and LimitTickets.SavedVars.crouchAllNpc then
        if isCrouched() then
            chatText("Crouched, so talking to <<C:1>>." , itemName)
        else
            chatText("Ignoring all talkable NPCs: crouch to enable talking to <<C:1>>.", itemName)
    		return true -- Disable interaction.
        end
    elseif isTalkAction and atMaxTickets and LimitTickets.SavedVars.crouchNpc then
		if isImpresario(itemName) then
            -- chatText("Talking to the Impresario herself!")
        elseif LimitTickets.SavedVars.ticketWarningsOnly then
            chatText("At <<1>> tickets, but warnings only, so talking to <<C:2>>." , ticketString, itemName)
    	elseif isCrouched() then
            chatText("At <<1>> tickets, but crouched, so talking to <<C:2>>.", ticketString, itemName)
        else
    		chatError("Too many tickets (<<1>>): crouch to enable talking.", ticketString)
    		return true -- Disable interaction.
        end
    elseif isSearchAction and isEmptyContainer then
        chatText("Fruitlessly searching the empty <<1>>.", itemName)
    elseif isSearchAction and LimitTickets.SavedVars.ignoreSafeContainers and isProbablySafeContainer(itemName) then
        chatText("Fearlessly searching the safe <<1>>.", itemName)
    elseif isSearchAction and atMaxTickets and LimitTickets.SavedVars.crouchContainers then
        if LimitTickets.SavedVars.ticketWarningsOnly then
            chatText("At <<1>> tickets, but warnings only, so searching the <<C:2>>.", ticketString, itemName)
        elseif isCrouched() then
            chatText("At <<1>> tickets, but crouched, so searching the <<C:2>>.", ticketString, itemName)
            -- chatText("Searching the <<C:1>>.", itemName)
        else
    		chatError("Too many tickets (<<1>>): crouch to enable search.", ticketString)
    		return true -- Disable interaction.
        end
	end
    return originalStartInteraction(...) -- Permit the activity.
end

-- Hook when the player gets new tickets.
local function LimitTickets_CurrencyUpdate(_, currencyType, _, newAmount, oldAmount, _)
    -- On zoning, reloadui, and character load, you get a currencyUpdate event from zero to your current amount.
    -- We want to ignore this, so we check against our saved value.
    if CURT_EVENT_TICKETS == currencyType and (0 ~= oldAmount or newAmount ~= LimitTickets.SavedVars.currentTickets) then
        local messageText
        
        LimitTickets.SavedVars.currentTickets = newAmount
        if newAmount >= LimitTickets.SavedVars.maxTickets then
            messageText = zo_strformat("You just reached your event ticket target! (<<1>>/<<2>>).", newAmount, LimitTickets.SavedVars.maxTickets)
            chatText(messageText)
        	zoAlertWrapper(messageText, newAmount, LimitTickets.SavedVars.maxTickets)
        else
            messageText = zo_strformat("Went from <<1>>/<<2>> to <<3>>/<<4>> event tickets!", oldAmount, LimitTickets.SavedVars.maxTickets, newAmount, LimitTickets.SavedVars.maxTickets)
            chatText(messageText)
        	zoAlertWrapper(messageText)
        end
    end
end

-- Settings wrapper for checkboxes, to cut down on all the repetition.
local function addCheckbox(propertyName, text, tooltip)
    lamOptions[#lamOptions + 1] = {
        type = "checkbox",
        name = text,
        tooltip = tooltip,
        getFunc = function() return LimitTickets.SavedVars[propertyName] end,
        setFunc = function(value)
            -- Differing order here only matters if we're toggling chatText() itself.
            if value then
                LimitTickets.SavedVars[propertyName] = value
                chatText("'<<1>>' set <<2>>.", text, GetString(SI_CHECK_BUTTON_ON))
            else
                chatText("'<<1>>' set <<2>>.", text, GetString(SI_CHECK_BUTTON_OFF))
                LimitTickets.SavedVars[propertyName] = value
            end
        end,
        default = defaultSavedVars[propertyName],
    }
end

-- Settings wrapper for headers, to cut down on all the repetition.
local function addHeader(text) 
    lamOptions[#lamOptions + 1] = {
        type = "header",
        name = text,
        width = "full",
    }
end

-- Build the settings window form.
local function LimitTickets_InitSettings()

    local panelData = {
        type = "panel",
        name = LimitTickets.name,
        displayName = LimitTickets.displayName,
        author = LimitTickets.author,
        version = LimitTickets.version,
        -- registerForRefresh = true,	--boolean (optional) (will refresh all options controls when a setting is changed and when the panel is shown).
        registerForDefaults = true,	--boolean (optional) (will set all options controls back to default values).
        -- slashCommand = "/LimitTickets",	--(optional) will register a command to open to this panel.
    }
    lamOptions[#lamOptions + 1] = {
        type = "description",
        title = nil,	--(optional)
        text = LimitTickets.description,
    }
    
    addHeader("Limit")
    lamOptions[#lamOptions + 1] = {
        type = "description",
        title = nil,	--(optional)
        text = "Setting a limit prevents going past the limit of 12 event tickets, and hence losing the extra tickets before you spend them.",
    }
    
    lamOptions[#lamOptions + 1] = {
        type = "slider",
        name = "Target tickets",
        tooltip = "Target number of tickets at which to start warning: you can only have at most 12. Recommended: 10, or (13, minus the most tickets you can get with one action in the current event, usually 3).",
        min = 0,
        max = 13,
        getFunc = function() return LimitTickets.SavedVars.maxTickets end,
        setFunc = function(value)
            LimitTickets.SavedVars.maxTickets = value
            chatText("Ticket target set to: <<1>>.", value)
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
    addCheckbox("crouchAllNpc",         "Crouch to talk to all NPCs, except assistants",  "Require crouching to talk to NPCs: handy while grinding writs, etc. Pickpocketable NPCs won't be talkable!")

    local LAM = LibAddonMenu2
    LAM:RegisterAddonPanel("LimitTicketsSettings", panelData)
    LAM:RegisterOptionControls("LimitTicketsSettings", lamOptions)
end

-- Initialize on ADD_ON_LOADED Event
-- Register for other events. Must be below the fns that are registered for the events.
local function LimitTickets_Initialize(_, addOnName)
	if (addOnName == LimitTickets.name) then
	    -- set up the various callbacks.
		EVENT_MANAGER:UnregisterForEvent(string.format("%s_%s", LimitTickets.name, "ADDON_LOADED"), EVENT_ADD_ON_LOADED)
        EVENT_MANAGER:RegisterForEvent(string.format("%s_%s", LimitTickets.name, "CURRENCY_UPDATE"), EVENT_CURRENCY_UPDATE, LimitTickets_CurrencyUpdate)

        -- Hooks. For our code to be an excessively good citizen, we try to modify the (local/private) class definitions,
        -- but *ONLY IF* it's absolutely safe to do so: otherwise we hook the instance, because someone else already has.
        -- This is certainly overkill, but doesn't hurt anything.

        -- Prehook for the reticle display.
        if RETICLE.TryHandlingInteraction == RETICLE.__index.TryHandlingInteraction then
        	ZO_PreHook(RETICLE.__index, "TryHandlingInteraction", ModifyReticle_Hook)
        else
        	ZO_PreHook(RETICLE, "TryHandlingInteraction", ModifyReticle_Hook)
        end

        -- Around-hook for the interaction response. Can't use ZO_*Hook methods, because we're changing the return value.
        if FISHING_MANAGER.StartInteraction == FISHING_MANAGER.__index.StartInteraction then
            originalStartInteraction = FISHING_MANAGER.__index.StartInteraction
            FISHING_MANAGER.__index.StartInteraction = StartInteraction_hook
        else
            originalStartInteraction = FISHING_MANAGER.StartInteraction
            FISHING_MANAGER.StartInteraction = StartInteraction_hook
        end

    	-- Set up our settings menu and saved var persistence.
    	-- Nil param here is optional string namespace to separate from other saved things within "LimitTickets_SavedVars".
        LimitTickets.SavedVars = ZO_SavedVars:NewAccountWide("LimitTickets_SavedVars", LimitTickets.SavedVarsVersion, nil, defaultSavedVars)
		LimitTickets_InitSettings()
		
		-- Place our reticle label.
        reticleInfoLabel:SetAnchor(TOPLEFT, ZO_ReticleContainerInteractKeybindButton, BOTTOMLEFT, 0, 0)
	end
end

EVENT_MANAGER:RegisterForEvent(string.format("%s_%s", LimitTickets.name, "ADDON_LOADED"), EVENT_ADD_ON_LOADED, LimitTickets_Initialize)
