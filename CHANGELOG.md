Changelog
=========
This changelog is a summary: for a more detailed breakdown, see https://github.com/DewiMorgan/LimitTickets/CHANGELOG.md


1.3.0
-----
* DONE: Feature: Stop players from picking up the quest. Preventing looting corpses is already too late. Corpses don't wait around for people to spend their tickets. 
* DONE: Feature: Prevent players from handing in the quest. 
* DONE: Feature: Make conversation-modding rely on checkbox settings.
* DONE: Feature: Change disabled conversation options to say how many tickets there are.
* DONE: Update: Change crouch-to-loot-corpse and crouch-to-search-container into constant toggles. 
* DONE: Update: Add "Fish" to safe list.
* DONE: Code Cleanup: Removed excessive hooking logic.
* WontDo: Maintain a list of killed mob names, and use those names to tell if something's a corpse. Can something be killed and lootable without the player getting a notification? (Turns out, we don't care about corpses).
* WontDo: GetLootTargetInfo() = INTERACT_TARGET_TYPE_OBJECT for bodies, chests, and resource nodes; INTERACT_TARGET_TYPE_NONE for backpacks, desks, barrels, etc. Thanks to code65536 from ESO forums! (Sadly, these seem only available once you've started looting, which may be too late for the tickets: will need testing.)
* WontDo: Feature: Check if you autoloot tickets from corpses even with autoloot off. If not: Option to turn off autoloot for corpses if at ticket limit? (WontDo, I think you get the tickets ANYWAY but it's irrelevant because once the corpse spawns with tickets in, it's too late to help the player. See CraftAutoLoot addon for similar features.)

1.2.1
-----
* DONE: Update: Add "Rubble" and "Loose Tile" to safe list.
* DONE: FIX: remove nil debug messages when toggling checkboxes.

1.2.0
-----
* DONE: Feature: Create better list of known-safe containers. Now I've checked through all events, too, it's non-beta and quite good: defaulted on.
* DONE: FIX: Changed max ticket target to 13, in order to effectively switch off all ticket checking behavior even when you're at 12 (needed in this event since there's nothing else to buy).
* DONE: FIX: Duplicate display of debug toggle confirmation.
* DONE: FIX: Don't trigger crouching for assistants if crouch for everyone is on. Thanks to danbest82 for reporting.
* DONE: FIX: If not explicitly marked for crouching, assistants should be usable without crouching.
* DONE: FIX: I found some pickpocketable NPCs who could be Talked to, so reinstated the warning tooltip.
* DONE: Code Cleanup: Create GitHub repo (https://github.com/DewiMorgan/LimitTickets) and set up project.
* DONE: Code Cleanup: Configure IntelliJ IDE for easier development.
* DONE: Code Cleanup: Remove repetition in settings by writing a checkbox wrapper.
* DONE: Code Cleanup: Move ToDo/Done comments into changelog file.
* DONE: Code Cleanup: Get rid of hardcoded inline constants.
* DONE: Code Cleanup: Parameterize dd(), zoAlertWrapper(), setReticleText(), for easier translation.
* DONE: Code cleanup: Hook FishingManager (the parent class) rather than FISHING_MANAGER (the instance) unless the latter is already hooked.
* DONE: Code cleanup: Put a desc in the required addons area.
* DONE: Code Cleanup: Remove tt() method.
* WontDo: Code Cleanup: "If other addons interfere, try to add those addons to your addon's txt file, at the `## OptionalDependsOn: DolgubonsLazyWritCrafter NoAccidentalStealing`
  This way their `event_add_on_loaded` will trigger before your addon, hopefully also applying their hooks before yours." - Baertram (Not needed in this case, but good to know for future!)
* WontDo: Code Cleanup: Remove most debugging notices.
* WontDo: Code Cleanup: Better hooking, using the ZOS functions (not possible in one case, already doing in the other).
* WontDo: Name local "class" vars something nicer. (They're fine.)
* WontDo: Actually use a class, and OOP? https://www.lua.org/pil/16.1.html (Doesn't really feel necessary for a one-file singleton.)

1.1.0
-----
* DONE: Feature: Add a toggle setting for the ZO_Alert if you max your tickets.
* DONE: Feature: Add a toggle setting to make crouching optional - so, you could show a warning but still not need to crouch.
* DONE: Feature (Beta): Option not to decorate reticle, nor prevent use, for known-safe containers like "Apple basket", "Backpack", "barrel"...
* DONE: FIX: Removed incorrect "went from 0/N" notification when zoning. Thanks to @willandbeyond for reporting.
* DONE: FIX: Don't decorate reticle for empty containers.
* DONE: FIX: A tooltip incorrectly claimed pickpocketable NPCs may be affected: in fact, they never get the "[E] Talk" reticle prompt.
* DONE: FIX: remove empty, unused settings.lua file, and various other code cleanup.
* WontDo: Use things like interaction types (sadly always null) and extraInfo=0 to restrict the list of things that need to be blocked.

1.0.0
-----
* DONE: Optimize to only get player currency if needed.
* DONE: Option not to talk to anyone without crouching - good for crafting mules
* DONE: Get settings to actually have an effect.
* DONE: Get settings to save and load.
* DONE: Separate addon.
* DONE: Make it actually not interact. That weird FISHING_MANAGER block.
* DONE: Make the message only appear once.
* DONE: Make max tickets a const.
* DONE: Test if the three trailing underscore params are needed. (they aren't)
* WontDo: Options for popup, interact blocking. (crouch was a better solution)
* WontDo: Allow bypassing it for each NPC. (crouch allows this already)
* WontDo: Popup message to alert when past 10. Steal DolgubonsLazyWritCreator:ResetWarning.lua "daily reset for writs" notification. (Reticle notice is better)
* WontDo: Whitelist getting stuff from the writ loot crates (don't ned to: they're "Examine", not "Search".

Future
------
* Ongoing: Maintain lists of known-safe (and known-unsafe?) containers.
* ToDo: Feature: Handle "Examine" items and "Use" items, too.
* ToDo: Feature: Some kinda warning on gifted tickets... where do they come from? Ingame mail? I don't know!
* ToDo: Feature: Internationalization.
* ToDo: ReOrg: Make this ext'n a minimalist, no-config ticket limiter: move other features (ignore assistants, ignore NPCs, etc) to other minimalist addons. Rename this one big do-everything app to something more general, like "Annoying Sneak" or something.
* ToDo: Bug: If you log out while stealthed, you'll be standing but stealthed (eye reticle, unable to mount, etc) when you log in. Same if you zone while stealthed. This is ESO's bug, not mine! But should maybe detect, on player load, and not consider this state to be crouched?
* ToDo: Feature: Have "jump within N seconds before" as an alternative to crouching, for sneaky players who crouch a lot anyway.
* ToDo: Feature: Have "holding shift" as an alternative to crouching, for sneaky players who crouch a lot anyway.
* ToDo: Feature: Have "crouch within N seconds" requirement, so that people don't accidentally trigger things if they're just sneaking?
* ToDo: Feature: Have the build batch file ensure that version, etc are the same between .lua and .txt files.
* ToDo: Feature: Crouch to socially interact with players.
* ToDo: Feature: If an event starts, prompt user to move to stricter constraints if the addon hasn't been updated as "confirmed to work for that event" somehow?
* ToDo: Feature: If an event starts, prompt user to move to stricter constraints if the addon hasn't got historically blocklisted items for that event?
* ToDo: Feature: If an event starts, prompt user to move to stricter constraints if their current constraints are known to be too lax?
* ToDo: Feature: If you get tickets from a verb not on the list, offer to add that verb to the list.
* ToDo: Feature: A user-editable list of verbs to prevent for the current event.
* ToDo: Feature: Optionally don't block vendors?
* ToDo: Feature: Could turn off ticket-blocking until midnight, once you get the max number of tickets for the day? You won't get more tickets the same day.
* ToDo: Feature: Allow a keybind instead of crouch, but share the keybind of NAS? Include NAS functionality here if NAS not installed? Don't want users to have to map TWO keys.
* ToDo: Feature: Allow characters to have their own individual settings, instead of globally shared ones.
* ToDo: Feature: Ultimately, blocklist only the things you interact or talk with to get tickets. (New Life: Talk "Breda" or "Petronius Galenus"). Likely take a year to get all the names.
* ToDo: Feature: Remind the player to get tickets for the day?
* ToDo: Feature: Add compatibility with Event Tracker to turn off blocking outside of events, so there're no tickets to be got? But maybe a few days after scheduled end, in case event gets extended.
* ToDo: Feature: Add compatibility with No Accidental Stealing, to use its current settings as the default, if it's installed.
* ToDo: Feature: Crouch to use a non-set crafting table where you've already completed the writ?
* ToDo: Feature: Find out what gamepad compatibility might entail.
* ToDo: Murdered corpses are still "Steal", not shown as a crime on the reticle, but is a crime to loot. See if they're different somehow.
* ToDo: Feature: confirm social interaction. Or maybe if you hold the "interact" key it pops up saying "are you really sure you want to interact with this person and challenge them to a duel/invite them to a group/beg them to be your friend/whatever?"
* ToDo: Optionally do/don't block talking to certain groups (vendors, assistants, houseguests, quest-givers, etc)?
* ToDo: Disable ticket checks in player housing.

Other Stuff
-----------
* Put https://cdn-eso.mmoui.com/images/style_esoui/downloads/new_3.gif before all new items?
* Addon idea: popup on EVENT_BEING_ARRESTED to say what stolen items you'll lose, and maybe calculate their total (TTC value minus fence charge) or (vendor price for treasures), plus bounty, to give a total loss, so you can see whether running's worth it.
* Addon idea: Tactical maps for all of Tamriel.
* Addon idea: examine item under reticle, log all lang-names, dump log, etc.
* Addon idea: examine dialog (events triggered, methods called, values set, etc).
* Addon idea: dolmen grinding: reticle pointer to next ws/dolmen/chest; map/minimap map lines to show dolmen cycle order and which is next; switch to zoomies between dolmen and wayshrine; clearly-visible reticle target at dolmens; assistant crouch (overrides defaults in my other addons).
* Pull request: Add toggle to Keybinder, between windows-user-account-wide and eso-user-account-wide.
* Pull request: Change Minion to allow the blocked categories (obsolete, dev tools) on a settings toggle, default off; and to show a sign in the list when an addon is obsolete.
