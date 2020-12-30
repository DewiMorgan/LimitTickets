Helpful coding notes and Addon dev principles
=============================================

Tips
----
IMPORTANT: Ignore updates to your addon in Minion!
d() is debug command in yellow text.
d(dump(SOME_TABLE)) is a method I stole from the interwebs to dump data.
CHAT_SYSTEM:AddMessage(<message String>) is for prettier stuff. I've wrapped this with tt() and dd(), below.


Principles
----------
* Have I18N
* Declare all dependencies
* Use ZOS constants wherever possible
* Avoid LibStub
* Avoid embedding shared libs
* Either use LibAddonMenu or at least put settings under Settings/Addons
* Avoid compulsory bound keys
* Avoid creating gobals
* Don't overwrite globals, especially constants! (or global styles!)
* Gamepad mode compatibility?
* Graceful crash-handling?
* Take care hooking (see below).
* Ensure replaced API fns will still work if ZOS adds more params/return values in the future. So use (...) as the params.
* Use ZO_ hooking fns where possible: https://github.com/esoui/esoui/blob/a34599f2cba93196976512d71f3b850cc9975ed9/esoui/libraries/utility/zo_hook.lua
  Note they won't let you modify return values though.
* All hooks should fail gracefully! Not break anything if they fail.
* Don't depend on libs that change the UI, eg libslashcommander 
* For performance, avoid LUA's string concatenation, instead using string.format("%s %s", string1, string2), ZO_GenerateCommaSeparatedList(), or table.concat.
* Use OOP https://www.lua.org/pil/16.html

Hooking gotchas
---------------
Sirinsidator wrote:
  use hooks on the class def if possible, or on the object when you do not have access to the class def
  [...] when you hook the instance with the intention to undo the hook later,
  you have to be careful how you do that, since the class works with metatables. When you simply set
  the original function on the table, you'll actually prevent hooks on the class itself from working.
  [...] Don't undo your hooks.

That is:
Say you have `obj`, which inherits a `obj:fn` from it parent class definition through the `obj.__index` metatable. (this is how OOP works in Lua).
Then if you do `obj:fn = ...`, then `obj` will no longer inherit `fn`, but rather will use its own member function that you gave it.
So anything that hooks that parent's method after your hook, won't be able to affect `obj`.

Anything that hooks a method after you did, but before you removed it, will have hooked your
instance of the method. So if you saved a copy of the original, unhooked method and stick it back
there, you will remove all those later hooks, not just your own.


If other addons interfere, you can try to add those addons to you addon's manifest txt file, using eg
## OptionalDependsOn: DolgubonsLazyWritCrafter NoAccidentalStealing
This way, their event_add_on_loaded will trigegr before your addon, hopefully applying their hooks before yours unless they delay their hooking.
To get the other order, with yours loading first, you need to ask them to put your addon in their manifest txt files.

Intrnationalization
-------------------
ToDo:           "Use the txt files language constant to auto load the lang.Lua file
And in there do not use GetString constants but add the texts to your addons global namespace lang table
Just as strings
Would be an advantage if you want access to all texts of all languages at the same time
" - Baertram

"I recommend using https://www.esoui.com/downloads/info2837-LibLanguage.html to handle localization strings myself (but then I wrote it <g>)." -- Shadowfen
