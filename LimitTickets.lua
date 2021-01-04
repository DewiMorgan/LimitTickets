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
LimitTickets.version = "1.3.0"
LimitTickets.description = "Causes actions with annoying effects (like getting too many tickets) to warn you and/or require you to crouch before doing them."

LimitTickets.SavedVarsVersion = "1" -- If this changes, older saved vars are WIPED.
LimitTickets.SavedVars = {} -- The actual real data.

local DEBUG = true
local function dx(...)
    if DEBUG then
        d(...)
    end
end

local lamOptions = {} -- The LibAddonMenu options page.

local defaultSavedVars = { -- Will be created in save file if not found, but won't override existing values.
    -- Config settings.
    maxTickets = 10,
    debugMessages = false,
    alertMessages = true,
    reticleMessages = true,
    ticketWarningsOnly = false,
    crouchNpc = true,
    crouchAssistants = true, -- should probably be "crouchAllContainers", historical reasons.
    crouchAllNpc = false,
    crouchContainers = true, -- should probably be "crouchAllContainers", historical reasons.
    ignoreSafeContainers = true, -- should probably be "crouchAllCorpses", historical reasons.
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
    ["Coffer"]         = true, -- Vivec Impresario tent.
    ["Corn Basket"]    = true,
    ["Crate"]          = true,
    ["Crates"]         = true,
    ["Desk"]           = true,
    ["Drawers"]        = true,
    ["Dresser"]        = true,
    ["Fish"]           = true, -- Searchable fish rack, eg at Philosopher's Cradle crafting area in Blackreach.
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
    ["Tomb Urn"]       = true, -- eg Shroud Hearth Barrow in the Rift
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
-- For this, I'd prefer a sensible way to programmatically say "this year's cake, not last year's, in any language", but...
local isJubileeCakeLookup = {
    ["Jubilee Cake 2020"] = true, -- obsolete, but used for testing.
    ["Jubilee Cake 2021"] = true,
    ["Jubilee Cake 2022"] = true,
    ["Jubilee Cake 2023"] = true,
    ["Jubilee Cake 2024"] = true,
    ["Jubilee Cake 2025"] = true,
    ["Jubilee Cake 2026"] = true,
    ["Jubilee Cake 2027"] = true,
}


-- Uses GetString() constants, so I18N'd. Unrecognized values will be Nil!
local actionNameToEnglishLookup = {
    [GetString(SI_GAMECAMERAACTIONTYPE1)] = "Search",
    [GetString(SI_GAMECAMERAACTIONTYPE2)] = "Talk",
    -- Commented unused items.
    -- [GetString(SI_GAMECAMERAACTIONTYPE3)] = "Harvest",
    -- [GetString(SI_GAMECAMERAACTIONTYPE4)] = "Disarm",
    [GetString(SI_GAMECAMERAACTIONTYPE5)] = "Use",
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

local function isJubileeCake(name)
    -- Probably Won't work with translation.
    --cakename = "Jubilee Cake"
    --return str:sub(1, #start) == start
    return isJubileeCakeLookup[name]
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

-- Let them know whether they can use an item, and if so, why.
-- Modified reticle hook from No, Thank You!, via No Interact.
local function ModifyReticle_Hook(interactionPossible)
	if interactionPossible then
        -- actionName, itemName, isInteractBlocked, isOwned, additionalInfo, context, contextLink, isCriminalInteract
    	local actionName, itemName, _, _, additionalInfo = GetGameCameraInteractableActionInfo()
     	local playerTickets = getTickets()
     	local atMaxTickets = playerTickets >= LimitTickets.SavedVars.maxTickets
     	local isTalkAction = "Talk" == actionNameToEnglishLookup[actionName]
 	    local isSearchAction = "Search" == actionNameToEnglishLookup[actionName]
 	    local isUseAction = "Use" == actionNameToEnglishLookup[actionName]
        local isEmptyContainer = ADDITIONAL_INTERACT_INFO_EMPTY == additionalInfo
        local ticketFormat = string.format(
            "%s/%s tickets: <<1>>",
            ZO_LocalizeDecimalNumber(playerTickets),
            ZO_LocalizeDecimalNumber(LimitTickets.SavedVars.maxTickets)
        )
        local assistantFormat = "Assistant: <<1>>"
        local npcFormat =  "NPC: <<1>>"
        local containerFormat =  "Container: <<1>>"
        local corpseFormat =  "Corpse: <<1>>"
        local beCareful = "be careful!"
        local cannotEat = "crouch to eat."
        local okToTalk = "crouched, can talk"
        local cannotTalk = "crouch to talk"
        local alwaysTalk = "can always talk"
        local okToSearch = "crouched, can search"
        local cannotSearch = "crouch to search"

        if not LimitTickets.SavedVars.reticleMessages then
        	hideReticleInfo(true)
	    elseif isUseAction and atMaxTickets and isJubileeCake(itemName) then
            if isCrouched() then
            	setReticleText(true, ticketFormat, beCareful)
	        else
            	setReticleText(false, ticketFormat, cannotEat)
	        end
	    elseif isTalkAction and LimitTickets.SavedVars.crouchAssistants and isAssistant(itemName) then
            if isCrouched() then
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
        elseif isSearchAction and isEmptyContainer then
            -- An empty container, ignore.
        	hideReticleInfo(true)
        elseif isSearchAction and LimitTickets.SavedVars.ignoreSafeContainers and not isProbablySafeContainer(itemName) then
            -- Crouch to search bodies.
	        if isCrouched() then
            	setReticleText(true, corpseFormat, okToSearch)
	        else
            	setReticleText(false, corpseFormat, cannotSearch)
	        end
	    elseif isSearchAction and LimitTickets.SavedVars.crouchContainers and isProbablySafeContainer(itemName)  then
            -- Crouch to search containers.
	        if isCrouched() then
            	setReticleText(true, containerFormat, okToSearch)
	        else
            	setReticleText(false, containerFormat, cannotSearch)
	        end
    	elseif isSearchAction and DEBUG then
            if isProbablySafeContainer(itemName) then
            	setReticleText(true, containerFormat, "Debug")
            else
            	setReticleText(false, corpseFormat, "Debug")
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
    local isUseAction = "Use" == actionNameToEnglishLookup[actionName]
    local isEmptyContainer = ADDITIONAL_INTERACT_INFO_EMPTY == additionalInfo -- 2 = an empty container

    local ticketString = string.format("%s/%s", ZO_LocalizeDecimalNumber(playerTickets), ZO_LocalizeDecimalNumber(LimitTickets.SavedVars.maxTickets))

    if isUseAction and atMaxTickets and isJubileeCake(itemName) then
        if isCrouched() then
            chatText("At <<1>> tickets, but crouched, so eating the <<C:2>>.", ticketString, itemName)
        else
            chatText("At <<1>> tickets: crouch to eat the <<C:2>>.", ticketString, itemName)
    		return true -- Disable interaction.
        end
    elseif isTalkAction and isAssistant(itemName) then
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
    elseif isTalkAction and atMaxTickets then
		if isImpresario(itemName) then
            -- Don't need anything special for her.
        elseif LimitTickets.SavedVars.ticketWarningsOnly then
            chatText("At <<1>> tickets, but 'warnings only' set: can accept quests and rewards.", ticketString, itemName)
    	elseif isCrouched() then
            chatText("At <<1>> tickets, but crouched: can accept quests and rewards.", ticketString, itemName)
        else
    		chatError("At <<1>> tickets: crouch to accept quests and rewards.", ticketString)
        end
    elseif isSearchAction and isEmptyContainer then
        chatText("Fruitlessly searching the empty <<1>>.", itemName)
    elseif isSearchAction and LimitTickets.SavedVars.ignoreSafeContainers and not isProbablySafeContainer(itemName) then
        if isCrouched() then
            chatText("Crouched, so searching the <<C:1>>.", itemName)
        else
    		chatError("Crouch to search the <<C:1>>.", itemName)
    		return true -- Disable interaction.
        end
    elseif isSearchAction and LimitTickets.SavedVars.crouchContainers and isProbablySafeContainer(itemName) then
        if isCrouched() then
            chatText("Crouched, so searching the <<C:1>>.", itemName)
        else
    		chatError("Crouch to search the <<C:1>>.", itemName)
    		return true -- Disable interaction.
        end
	end
    return originalStartInteraction(...) -- Permit the activity.
end


local NeedToChangeGoodbye
local LastQuestRewarded

-- When any conversation begins, we set this false.
local function OnChatterBegin(eventCode, chatterOptionCount) -- number, number
    NeedToChangeGoodbye = false
    LastQuestRewarded = nil
end

local function ShowQuestRewards_Hook(_, journalQuestIndex) -- Number
    LastQuestRewarded = journalQuestIndex
    return false
end

-- When response options are added to a conversation, check to see if they give
-- quest rewards. Decline if too many tickets.

local function PopulateChatterOption_Hook(self, controlID, optionIndex, optionText, optionType, optionalArg, isImportant, chosenBefore, importantOptions)
    local needToBlockAccept = false
    local optionControl
    local playerTickets

    -- Note, the following two lines exist already in ZOS' code, so I may be being redundant?
    -- warn the player they aren't going to get their money when they hit complete
    -- confirmError = self:TryGetMaxCurrencyWarningText(reward.rewardType, reward.amount)

    -- Not much is gained with a blocklist. Spend your damn tickets!
    -- local lootName = GetLootTargetInfo()
    -- if isKnownTicketQuestGiver(zo_strformat("<<1>>", lootName)) then

    -- This fn is called for every single conversation option, so trying to be lightweight for most of them.
    if CHATTER_GOODBYE == optionType then
        if NeedToChangeGoodbye then
            NeedToChangeGoodbye = false
            optionControl = self.optionControls[controlID]
            if optionControl then
                optionControl:SetText("I should spend some tickets, first.")
                optionControl:SetColor(ZO_ERROR_COLOR:UnpackRGBA())
            end
        end
        return -- exit early.
    elseif CHATTER_GENERIC_ACCEPT == optionType then -- Accepting quest
        playerTickets = getTickets()
        if playerTickets >= LimitTickets.SavedVars.maxTickets then
            needToBlockAccept = true
        end
    elseif CHATTER_COMPLETE_QUEST == optionType and LastQuestRewarded > 0 then -- Accepting quest reward
        playerTickets = getTickets()
        if playerTickets >= LimitTickets.SavedVars.maxTickets then
            local numRewards = GetJournalQuestNumRewards(LastQuestRewarded)
            for i = 1, numRewards do
                local rewardType = GetJournalQuestRewardInfo(LastQuestRewarded, i)
                if REWARD_TYPE_EVENT_TICKETS == rewardType then
                    chatText("Event Tickets being offered!")
                    needToBlockAccept = true
                end
            end
        end
    end

    -- Block if we decided we needed to.
    if needToBlockAccept then
        optionControl = self.optionControls[controlID]
        if optionControl then
            -- Disable accepting the quest ro reward.
            local warningString = ""
            if (LimitTickets.SavedVars.crouchNpc and isCrouched()) or LimitTickets.SavedVars.ticketWarningsOnly then
                chatText("Warning given.")
                warningString = "[Careful: %d/%d tickets!]: %s"
                optionControl:SetColor(ZO_ERROR_COLOR:UnpackRGBA())
            else
                chatText("Acceptance blocked.")
                warningString = "[Blocked: %d/%d tickets!]: %s"
                optionControl:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
                GetControl(optionControl, "IconImage"):SetDesaturation(1)
                optionControl.enabled = false
            end
            optionControl:SetText(string.format(warningString,
                ZO_LocalizeDecimalNumber(playerTickets),
                ZO_LocalizeDecimalNumber(LimitTickets.SavedVars.maxTickets),
                optionText
            ))
            NeedToChangeGoodbye = true
        end
    end
end

-- Hook when the player gets new tickets.
local function OnCurrencyUpdate(_, currencyType, _, newAmount, oldAmount, _)
    -- On zoning, reloadui, and character load, you get a currencyUpdate event from zero to your current amount.
    -- We want to ignore this, so we check against our saved value.
    if CURT_EVENT_TICKETS == currencyType and (0 ~= oldAmount or newAmount ~= LimitTickets.SavedVars.currentTickets) then
        local messageText
        
        LimitTickets.SavedVars.currentTickets = newAmount
        if newAmount >= LimitTickets.SavedVars.maxTickets then
            messageText = zo_strformat("You just reached your event Ticket Limit! (<<1>>/<<2>>).", newAmount, LimitTickets.SavedVars.maxTickets)
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
local function InitSettings()

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
        text = "The limit stops you exceeding the max 12 event tickets, so losing the extra tickets.",
    }
    
    lamOptions[#lamOptions + 1] = {
        type = "slider",
        name = "Ticket limit",
        tooltip = "Number of tickets before warning. Recommended: 10, or (13, minus the most tickets you can get with one action in the current event, usually 3). Choosing 13 effectively turns the warning off, as you can only ever have 12.",
        min = 0,
        max = 13,
        getFunc = function() return LimitTickets.SavedVars.maxTickets end,
        setFunc = function(value)
            LimitTickets.SavedVars.maxTickets = value
            chatText("Ticket limit set to: <<1>>.", value)
        end,
        default = defaultSavedVars.maxTickets,
    }

    addHeader("Output options")
    addCheckbox("reticleMessages",      "Warnings by the '[E] Use' reticle note",  "Changes the '[E]' reticle message to warn about tickets (strongly recommended unless taking screenshots, etc!).")
    addCheckbox("alertMessages",        "Notice at Top-right when ticket balance changes",  "Sends an alert to the top-right of your screen when your number of tickets changes, or you hit your limit.")
    addCheckbox("debugMessages",        "Messages in chat window",  "Messages to your chat window to let you know why you can't use stuff. Mostly for debugging.")

    addHeader("Behavior once your 'Ticket Limit' is reached")
    addCheckbox("crouchNpc",            "Block quests/rewards from NPCs",  "Once you hit your ticket limit, prevent selecting conversation options that would give you a quest, or tickets.")
    addCheckbox("ticketWarningsOnly",   "Warnings only, don't block actions", "If this is on, you won't need to crouch to search/talk, but you'll still see any enabled messages in the reticle, alerts, and/or chat window.")
 
    addHeader("Constant Behavior")
    addCheckbox("crouchContainers",     "Crouch to 'Search' containers.",  "Only those containers where the action is 'Search': barrels, etc.")
    addCheckbox("ignoreSafeContainers", "Crouch to loot bodies.",  "Possibly useful for murdered people, but doesn't check you're hidden, only crouched.")
    addCheckbox("crouchAssistants",     "Crouch to use assistants",  "Ignore assistants unless crouched, for when group mates forget to put them away.")
    addCheckbox("crouchAllNpc",         "Crouch to talk to all NPCs, except assistants",  "Require crouching to talk to NPCs: handy while grinding writs, etc. Pickpocketable NPCs won't be talkable!")

    local LAM = LibAddonMenu2
    LAM:RegisterAddonPanel("LimitTicketsSettings", panelData)
    LAM:RegisterOptionControls("LimitTicketsSettings", lamOptions)
end

-- Initialize on ADD_ON_LOADED Event
-- Register for other events. Must be below the fns that are registered for the events.
local function OnAddOnLoaded(_, addOnName)
	if (addOnName == LimitTickets.name) then
	    -- set up the various callbacks.
		EVENT_MANAGER:UnregisterForEvent(string.format("%s_%s", LimitTickets.name, "ADDON_LOADED"), EVENT_ADD_ON_LOADED)
        EVENT_MANAGER:RegisterForEvent(string.format("%s_%s", LimitTickets.name, "CURRENCY_UPDATE"), EVENT_CURRENCY_UPDATE, OnCurrencyUpdate)
        EVENT_MANAGER:RegisterForEvent(string.format("a%s_%s", LimitTickets.name, "EVENT_CHATTER_BEGIN"), EVENT_CHATTER_BEGIN, OnChatterBegin)

        -- Prehook for the reticle display.
        ZO_PreHook(RETICLE, "TryHandlingInteraction", ModifyReticle_Hook)
        -- PreHook to get quest id.
        -- This could have been an event handler, but we want to guarantee running before PopulateChatterOption_Hook
        ZO_PreHook(INTERACTION, "ShowQuestRewards", ShowQuestRewards_Hook)

        -- Around-hook for the interaction response. Can't use ZO_*Hook methods, because we're changing the return value.
        originalStartInteraction = FISHING_MANAGER.StartInteraction
        FISHING_MANAGER.StartInteraction = StartInteraction_hook

        -- Posthook for quest-giver conversations.
        ZO_PostHook(INTERACTION, "PopulateChatterOption", PopulateChatterOption_Hook)

    	-- Set up our settings menu and saved var persistence.
    	-- Nil param here is optional string namespace to separate from other saved things within "LimitTickets_SavedVars".
        LimitTickets.SavedVars = ZO_SavedVars:NewAccountWide("LimitTickets_SavedVars", LimitTickets.SavedVarsVersion, nil, defaultSavedVars)
		InitSettings()
		
		-- Place our reticle label.
        reticleInfoLabel:SetAnchor(TOPLEFT, ZO_ReticleContainerInteractKeybindButton, BOTTOMLEFT, 0, 0)
	end
end

EVENT_MANAGER:RegisterForEvent(string.format("%s_%s", LimitTickets.name, "ADDON_LOADED"), EVENT_ADD_ON_LOADED, OnAddOnLoaded)
