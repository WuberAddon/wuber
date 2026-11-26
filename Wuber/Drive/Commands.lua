-- Module: Drive.Commands
-- Purpose: /wuber drive commands (was Drive_Commands.lua).
-- API: W.Drive, DR.COMMAND_TOGGLES, DR.COMMANDS, DR.Command
-- Internals: (none)
-- Uses: (none)
-- Later: UI.Driver.State (D.OPEN_WHY, read at run time)
-- Events: listens -; fires SETTINGS
-- Standalone: no
-- Test: tests/drive/commands_test.lua
-- From: Drive_Commands.lua 1-638 (Wuber 2.2.1)
--
-- Wuber Drive: typed commands (agent B). Ritual Rides' /rr commands, as
-- "/wuber drive <command>". Not advertised anywhere except one line at the bottom of
-- Settings > Driving: everything here is also a tap in the app. "/wuber drive" alone opens
-- the Drive tab.

local ADDON, W = ...
local Mod = W.Module("Drive.Commands", {})
W.Drive = W.Drive or {}
local DR = W.Drive

local Y, R = "|cffffd200", "|r"

local function say(text) W.Print(text) end

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function call(name, ...)
	local fn = DR[name]
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		W.Error("drive " .. name, a)
		return nil
	end
	return a, b
end

local function opts()
	local o = call("opts")
	return type(o) == "table" and o or {}
end

local function setOpt(key, value)
	if type(DR.SetOpt) ~= "function" or call("SetOpt", key, value) == nil then
		-- a habit the engine does not clean (yet): kept as given
		opts()[key] = value
	end
end

local function show(screen)
	local ui = W.UI
	if type(ui) == "table" and type(ui.ShowDrive) == "function" then
		W.Safe("drive screen", ui.ShowDrive, screen)
		return true
	end
	if W.Driver and W.Driver.Toggle then W.Safe("drive", W.Driver.Toggle) end
	return false
end

local function findName(arg)
	local c = call("Find", arg)
	if type(c) == "table" then return c end
	-- by first name, when only one matches
	local key, found = W.Key(arg), nil
	for _, other in pairs(DR.customers or {}) do
		if type(other) == "table" and other.key and other.key:match("^(%S+)") == key then
			if found then return nil end
			found = other
		end
	end
	return found
end

local function dest() return tostring(call("Dest") or "") end
local function price() return tonumber(W.Char().price) or W.MIN_PRICE end

local TOGGLES = {
	kick = { key = "kickAfter", text = "Removing riders after their ride", shared = true },
	autotrade = { key = "autoTrade", text = "Opening the trade for a rider who landed" },
	public = { key = "watchPublic", text = "Listing people who ask for a summon in public chat" },
	market = { key = "autoPublic", text = "Inviting buyers in the public chat channels you read who name your place" },
	oneatatime = { key = "oneAtATime", text = "One rider at a time" },
	autoblock = { key = "autoBlock", text = "Blocking riders who leave without paying" },
	tellblocked = { key = "tellBlocked", text = "Telling blocked players why" },
	remind = { key = "remindPay", text = "Reminding riders who haven't paid" },
	shards = { key = "needShards", text = "Only casting with a Soul Shard" },
	sound = { key = "sound", text = "Sounds", db = true },
	invite = { key = "autoInvite", text = "Inviting riders who whisper you or ask in the app" },
	under = { key = "acceptUnder", text = "Counting a smaller payment as paid" },
	accept = { key = "autoAccept", text = "Accepting your crew's invites" },
	raidsum = { key = "raidsum", text = "Whispering raiders when their summon starts", shared = true },
	raidclick = { key = "raidclick", text = "Asking the raid to click the portal", shared = true },
	away = { key = "awayGuard", text = "Pausing you when you are away" },
	wants = { key = "watchBounty", text = "Showing what riders want" },
	sharenotes = { key = "shareNotes", text = "Sharing notes with your own accounts" },
}
DR.COMMAND_TOGGLES = TOGGLES

local C = {}
DR.COMMANDS = C

function C.help()
	say("Driving commands (everything is also in the Drive tab and Settings):")
	say(Y .. "on" .. R .. " / " .. Y .. "off" .. R .. ", " .. Y .. "pause" .. R .. ", " .. Y .. "resume" .. R .. ", "
		.. Y .. "price 1g" .. R .. ", " .. Y .. "dest <place>" .. R .. " (or auto), " .. Y .. "service <name>" .. R .. ", " .. Y .. "team" .. R)
	say(Y .. "add" .. R .. ", " .. Y .. "drop" .. R .. ", " .. Y .. "paid" .. R .. ", " .. Y .. "block" .. R .. ", " .. Y .. "unblock" .. R
		.. " <name>; " .. Y .. "blocked" .. R .. ", " .. Y .. "msgs" .. R .. ", " .. Y .. "msg <kind> <text>" .. R .. ", " .. Y .. "keywords" .. R)
	say(Y .. "ad" .. R .. ", " .. Y .. "adevery 15" .. R .. ", " .. Y .. "caster" .. R .. ", " .. Y .. "lowshards 3" .. R .. ", " .. Y .. "max 10" .. R
		.. ", " .. Y .. "mode auto" .. R .. " (macro, box or off), " .. Y .. "spell" .. R .. ", " .. Y .. "bell <name>" .. R)
	say(Y .. "bind F5" .. R .. ", " .. Y .. "show" .. R .. ", " .. Y .. "hide" .. R .. ", " .. Y .. "lock" .. R .. ", " .. Y .. "unlock" .. R
		.. ", " .. Y .. "resetpos" .. R .. ", " .. Y .. "scale 1.5" .. R .. ", " .. Y .. "status" .. R .. ", " .. Y .. "stats" .. R .. ", "
		.. Y .. "log" .. R .. ", " .. Y .. "retry" .. R)
	say(Y .. "raid" .. R .. " / " .. Y .. "sell" .. R .. " (raid summons or selling), " .. Y .. "summoners Bea Jones, Cal Brown" .. R
		.. " (who casts, in order; " .. Y .. "summoners clear" .. R .. "), " .. Y .. "stations" .. R .. " (" .. Y .. "stations Orgrimmar off" .. R .. ")")
	say("Someone who joins your group while you are open and leading becomes a rider (joined). " .. Y .. "add <name>" .. R .. " invites a player yourself.")
	local names = {}
	for k in pairs(TOGGLES) do names[#names + 1] = k end
	table.sort(names)
	say("Switches, each with on or off: " .. table.concat(names, ", ") .. ".")
end

local function open(on)
	local ok, why = call("SetOpen", on)
	if ok == false then
		-- the Start button's sentence for the code (D.OPEN_WHY lives in UI, which loads later)
		local table_ = W.Driver and W.Driver.OPEN_WHY
		local line = why and why ~= "" and ((type(table_) == "table" and table_[why]) or tostring(why)) or nil
		if line then say(line .. (line:find("[%.!?]$") and "" or "."))
		elseif on then say("Can't open right now.")
		else say("Can't close right now.") end
		return
	end
	if on and call("Mode") == "raid" then
		say("Open: raid summons. Raiders who say 123 in raid chat are summoned at no charge.")
	elseif on then
		say("Open: " .. W.Money(price()) .. " to " .. dest() .. ". Riders whisper \"" .. (DR.Keyword and DR.Keyword() or "summon") .. "\".")
	else
		say("Closed. Nobody is invited or asked to pay.")
	end
end

function C.on() open(true) end
function C.off() open(false) end
C.open, C.close = C.on, C.off

-- Only a Warlock of the crew (or the runner) pauses: a helper's pause would show "Paused" on
-- its own screen while the Warlocks stay open (2.2, review #17).
local function mayPause()
	local role = call("Role")
	if role == nil or role == "driver" then return true end
	say("Only " .. ((DR.ShortOf and DR.ShortOf(W.Char().captain)) or "your crew's Warlock") .. " can pause or resume: you click the portal.")
	return false
end

function C.pause()
	if not mayPause() then return end
	local on = not call("IsPaused")
	call("SetPaused", on)
	local paused = call("Mode") == "raid" and "Paused: nobody is summoned until you resume." or "Paused: nobody new is invited. Riders already with you carry on."
	say(on and paused or "Resumed.")
end
function C.resume()
	if not mayPause() then return end
	call("SetPaused", false)
	say("Resumed.")
end

function C.price(arg)
	local copper = W.ParseMoney(arg)
	if not copper then
		say("Your price is " .. W.Money(price()) .. ". Change it like this: " .. Y .. "/wuber drive price 1g" .. R)
		return
	end
	if copper < W.MIN_PRICE then
		say("Wuber's lowest fare is " .. W.Money(W.MIN_PRICE) .. ", so that's your price.")
		copper = W.MIN_PRICE
	end
	if type(DR.SetPrice) == "function" then call("SetPrice", copper) else W.Char().price = copper end
	say("Price: " .. W.Money(price()) .. " (riders already in the group keep the price they were told).")
end

function C.dest(arg)
	if arg == "" then
		local d = W.Char().dest
		say("You summon to " .. dest() .. ((d == nil or d == "") and " (where you stand)" or "") .. ".")
		return
	end
	call("SetDest", arg:lower() == "auto" and "" or arg)
	say("You summon to " .. dest() .. ".")
end

function C.team(arg)
	if arg:lower() == "clear" or arg:lower() == "leave" then
		if call("IsCaptain") then
			for _, m in ipairs(call("Crew") or {}) do
				if type(m) == "table" and m.key ~= W.myKey then call("RemoveCrew", m.name) end
			end
			say("Your crew is cleared.")
		else
			call("LeaveCrew")
			say("You left the crew.")
		end
		return
	end
	if not show("wizard") then say("The crew wizard isn't loaded.") end
end

function C.ad(arg)
	if arg ~= "" then
		setOpt("adChannels", arg:lower() == "none" and "" or arg)
		if opts().adChannels == "" then
			say("Timed adverts are off. Advertise still posts to the first channel joined.")
		else
			say("Adverts go to: " .. tostring(opts().adChannels) .. ", in turn.")
		end
	end
	-- a typed command can't post: the line goes into the chat box for your Enter
	local own = call("AdvertText")
	local nextAd = call("NextAd")
	local plan, why, wait = W.AdvertPlan(dest(), price(), { text = own, channel = type(nextAd) == "table" and nextAd.index or nil })
	if not plan then
		if why == "wait" then
			say("Your next advert can go in " .. math.ceil((tonumber(wait) or 0) / 60) .. " min.")
		elseif why == "combat" then
			say("Not in combat.")
		elseif why == "channel" then
			say("Join Trade or LookingForGroup first.")
		elseif why == "spam" then
			say("Your advert line was refused by the spam filter: change it in Messages.")
		else
			say("There's no advert to post.")
		end
		return
	end
	if DR.ChatBox and DR.ChatBox(plan.macro) then
		W.AdvertPosted(plan)
		say("Your advert is in the chat box: press Enter to post it.")
	end
end

function C.adevery(arg)
	local n = tonumber(arg)
	if n then setOpt("adEvery", math.max(0, math.floor(n))) end
	local every = tonumber(opts().adEvery) or 0
	say(every > 0 and ("Advert reminder every " .. every .. " minutes while open.") or "No advert reminder.")
end

function C.caster(arg)
	if arg ~= "" then
		local low = arg:lower()
		if low == "any" or low == "anyone" then
			call("SetCaster", "-")
		elseif low == "me" then
			call("SetCaster", "")
		else
			call("SetCaster", W.Clean(arg, 48))
		end
	end
	local c = W.Char().caster
	if c == "-" then
		say("Whoever clicks first casts.")
	elseif c == nil or c == "" then
		say("You are the main caster (the next Warlock takes over when you can't).")
	else
		say("Main caster: " .. tostring(c) .. " (the next Warlock takes over when they can't).")
	end
end

function C.lowshards(arg)
	local n = tonumber(arg)
	if n then setOpt("lowShards", math.max(0, math.min(10, math.floor(n)))) end
	local v = tonumber(opts().lowShards) or 0
	say(v > 0 and ("Warning at " .. v .. " Soul Shards.") or "No Soul Shard warning.")
end

function C.bind(arg)
	if arg == "" then
		local key = W.db and W.db.drive and W.db.drive.button and W.db.drive.button.key
		say(key and ("The big button is on " .. key .. ". " .. Y .. "/wuber drive bind none" .. R .. " removes it.")
			or ("No key is set. Example: " .. Y .. "/wuber drive bind F5" .. R))
		return
	end
	if arg:lower() == "none" then
		if DR.SetKey then DR.SetKey(nil) end
		say("Key removed.")
	else
		local key = DR.SetKey and DR.SetKey(arg)
		if DR.SetKey and not key then
			say("Escape can't be the big button's key. The key was removed.")
			return
		end
		say("The big button is on " .. tostring(key or arg:upper()) .. (W.InCombat() and " after this fight." or "."))
	end
end

function C.add(arg)
	if arg == "" then
		say(Y .. "/wuber drive add <name>" .. R .. " puts a player on the list and invites them.")
		return
	end
	if not call("IsOpen") then
		say("Open first.")
		return
	end
	local c
	if call("Mode") == "raid" then c = call("RaidAdd", arg) else c = call("Request", arg, "manual") end
	say(type(c) == "table" and (c.name .. " is on the list.") or (arg .. " can't be added to the list right now."))
end

function C.drop(arg)
	local c = findName(arg)
	if not c then
		say("Nobody called \"" .. arg .. "\" is on the list.")
		return
	end
	call("Do", "DROP", c.name)
	say(c.name .. " is off the list.")
end

function C.paid(arg)
	local c = findName(arg)
	if not c then
		say("Nobody called \"" .. arg .. "\" is on the list.")
		return
	end
	if type(DR.MarkPaid) == "function" then
		call("MarkPaid", c)
	else
		local owed = tonumber(call("Due", c)) or 0
		call("Do", "PAID", c.name, owed > 0 and owed or (tonumber(c.price) or price()), "m")
	end
	say(c.name .. " is marked as paid.")
end

function C.block(arg)
	if arg == "" then
		say(Y .. "/wuber drive block <name> - <reason>" .. R)
		return
	end
	-- "Dan Miller - never paid": the reason after a dash
	local who, reason = arg:match("^(.-)%s+%-%s+(.+)$")
	who = who or arg
	local c = findName(who)
	local key = call("Blacklist", c and c.name or who, reason or "blocked by hand")
	say(key and ((c and c.name or who) .. " won't be served again, in every crew window.") or (arg .. " can't be blocked (in your crew?)."))
end

function C.unblock(arg)
	if arg == "" then
		say(Y .. "/wuber drive unblock <name>" .. R)
		return
	end
	if W.Key(arg) == nil then return end
	local n = tonumber(call("Unblacklist", arg)) or 0
	say(n > 0 and (arg .. " is served again.") or (arg .. " wasn't blocked."))
end

function C.blocked()
	if not show("blocked") then
		local list = call("BlockedList") or {}
		say(#list .. " blocked.")
	end
end
C.blacklist = C.blocked

function C.mode(arg)
	arg = arg:lower()
	if arg == "direct" then
		say("Wuber can't whisper by itself on this game: whispers go by the button (macro) or the chat box.")
		return
	end
	if arg ~= "auto" and arg ~= "macro" and arg ~= "box" and arg ~= "off" then
		say("Whispers go by " .. (DR.ChatMode and DR.ChatMode() or "macro") .. " (setting: " .. tostring(opts().whisperMode or "auto")
			.. "). Choose auto, macro, box or off.")
		return
	end
	setOpt("whisperMode", arg)
	if DR.ResetChat then DR.ResetChat() end
	if DR.SendConfig then call("SendConfig") end
	say("Whispers: " .. arg .. ".")
end

function C.max(arg)
	local n = tonumber(arg)
	if not n then
		say("The group grows to " .. tostring(call("MaxGroup") or opts().maxGroup) .. " at most (your crew included).")
		return
	end
	setOpt("maxGroup", math.max(3, math.min(40, math.floor(n))))
	if DR.SendConfig then call("SendConfig") end
	say("Largest group: " .. tostring(call("MaxGroup") or opts().maxGroup) .. ".")
end

function C.msgs()
	local own = (W.db and W.db.drive and W.db.drive.templates) or {}
	for _, kind in ipairs(DR.TEMPLATE_ORDER or {}) do
		say(Y .. kind .. R .. (own[kind] and " (yours)" or "") .. ": " .. tostring(DR.Template and DR.Template(kind) or ""))
	end
	say("Placeholders: {" .. table.concat(DR.PLACEHOLDERS or {}, "} {") .. "}")
end

function C.msg(arg)
	local kind, text = arg:match("^(%S+)%s*(.*)$")
	kind = kind and kind:lower()
	if not kind or not (DR.TEMPLATES and DR.TEMPLATES[kind]) then
		say(Y .. "/wuber drive msg <kind> <text>" .. R .. " - the kinds: " .. table.concat(DR.TEMPLATE_ORDER or {}, ", "))
		return
	end
	text = trim(text)
	if text == "" then
		say(kind .. ": " .. tostring(DR.Template and DR.Template(kind) or ""))
		say("Now reads: " .. (DR.Text and DR.Text(kind) or ""))
		return
	end
	local newText = text
	if text:lower() == "reset" then newText = nil end
	local ok, why = DR.SetTemplate(kind, newText)
	if not ok then
		say("Not saved: " .. tostring(why) .. ".")
		return
	end
	local sample = DR.Text and DR.Text(kind) or ""
	say(kind .. " now reads: " .. sample)
	if #sample >= (DR.TEXT_MAX or 190) and kind ~= "advert" then say("That is cut off at " .. (DR.TEXT_MAX or 190) .. " characters: make it shorter.") end
end

function C.keywords(arg)
	if arg == "" then
		local k = opts().keywords
		say("A whisper with one of these words is a request: " .. (type(k) == "table" and table.concat(k, ", ") or tostring(k or "")))
		return
	end
	local words = {}
	for w in arg:lower():gmatch("[%a%d]+") do words[#words + 1] = w end
	if #words == 0 then return end
	setOpt("keywords", table.concat(words, " "))
	if DR.SendService then call("SendService") end
	say("Request words: " .. table.concat(words, ", ") .. " (the first one is named in your messages).")
end

function C.service(arg)
	if arg ~= "" then
		local ok, why = call("SetService", arg)
		if ok == false then
			say("That name isn't allowed" .. (why and (" (" .. tostring(why) .. ")") or "") .. ".")
			return
		end
	end
	say("Your service is called " .. (DR.ServiceName and DR.ServiceName() or W.Me()) .. ".")
end

function C.ritual(arg)
	if arg ~= "" then
		setOpt("ritual", arg:lower() == "reset" and "" or arg)
	end
	local spell, known = call("Ritual")
	-- (round 13, I8) the game's name only when the player set one of their own
	local own = opts().ritual
	own = type(own) == "string" and own ~= "" and own or nil
	if own and own ~= spell then say("\"" .. own .. "\" isn't in this spellbook.") end
	local what = (own and own == spell) and ("\"" .. tostring(spell) .. "\"") or "the summoning spell"
	say("The button casts " .. what .. (known and "." or ", which isn't in this spellbook."))
end

C.spell = C.ritual -- (round 13, I8: the help says "spell"; the old word still works)

function C.log() call("LogReport") end

function C.bell(arg)
	local low = arg:lower()
	if low == "" then
		local b = W.db and W.db.drive and W.db.drive.bell
		say((b and b.name ~= "" and ("Your alert character is " .. b.name .. ".")) or ("No alert character. " .. Y .. "/wuber drive bell <name>" .. R))
	elseif low == "off" or low == "none" then
		call("BellSet", "")
		say("No alert character.")
	elseif low == "test" then
		local ok, why = call("BellTest")
		say(ok and "Test sent" or (tostring(why or "") ~= "" and tostring(why) or "No alert character set"))
	elseif low == "forget" then
		call("BellForget")
		say("This window forgot the crews it alerted for.")
	else
		local set, why = call("BellSet", arg)
		if set == false and why then say(tostring(why)) else say("Your alert character is " .. arg .. ".") end
	end
end

function C.stats(arg)
	if arg:lower() == "reset" then
		call("ResetStats")
		say("Counts reset.")
		return
	end
	local life, session = call("Stats")
	if type(session) == "table" then
		say("This session: " .. (session.rides or 0) .. " rides, " .. W.Money(session.copper or 0) .. ".")
	end
	if type(life) == "table" then
		say("Ever, on this account: " .. (life.rides or 0) .. " rides, " .. W.Money(life.copper or 0) .. ".")
	end
	local raid = tonumber(call("RaidCount")) or 0
	if raid > 0 then say("Raiders summoned tonight: " .. raid .. ".") end
end

-- 2.1: raid summons (free, for your own raid) or selling
local function setMode(m)
	if type(DR.SetMode) ~= "function" then
		say("This version can't switch modes.")
		return
	end
	local okM, why = call("SetMode", m)
	if okM == false then
		say("Can't switch: " .. tostring(why or "not now") .. ".")
		return
	end
	if m == "raid" then
		local can, reason = call("CanRunRaid")
		say("Raid summons: raiders who say 123 in raid chat are summoned at no charge." .. (can == false and (" Not yet: " .. tostring(reason or ""):gsub("[%.!?]+$", "") .. ".") or ""))
	else
		say("Selling summons.")
	end
end
function C.raid(arg)
	if arg:lower() == "off" then setMode("sell") else setMode("raid") end
end
function C.sell() setMode("sell") end

-- A name in my group or crew -> its key.
local function keyOf(name)
	local k = W.Key(name)
	if not k then return nil end
	for _, m in ipairs(call("Crew") or {}) do
		if type(m) == "table" and m.key and (m.key == k or m.key:match("^(%S+)") == k) then return m.key end
	end
	for _, r in ipairs(call("RaidWarlocks") or {}) do
		if type(r) == "table" and r.key and (r.key == k or r.key:match("^(%S+)") == k) then return r.key end
	end
	for key in pairs(DR.units or {}) do
		if key == k or key:match("^(%S+)") == k then return key end
	end
	return k
end

function C.summoners(arg)
	if arg ~= "" then
		local list = {}
		if arg:lower() ~= "clear" and arg:lower() ~= "none" then
			for part in (arg .. ","):gmatch("([^,]*),") do
				local k = keyOf(trim(part))
				if k then list[#list + 1] = k end
			end
		end
		call("SetSummoners", list)
	end
	local now = call("Summoners") or {}
	local names = {}
	for _, k in ipairs(now) do
		names[#names + 1] = (DR.ShortOf and DR.ShortOf(k)) or k
		if DR.KeyHasApp and not DR.KeyHasApp(k) then names[#names] = names[#names] .. " (no Wuber: your button asks them in chat)" end
	end
	say(#names > 0 and ("Summoners, in order: " .. table.concat(names, ", ") .. ".")
		or (W.IsWarlock() and "You summon (no summoners chosen)." or "No summoner chosen: pick a Warlock friend in the crew wizard."))
end

function C.stations(arg)
	local place, onoff = arg:match("^(.-)%s+(%a+)$")
	if place and (onoff:lower() == "on" or onoff:lower() == "off") then call("SetStation", place, onoff:lower() == "on") end
	local list = call("Stations") or {}
	if #list == 0 then
		say("You summon to " .. dest() .. ".")
		return
	end
	for _, st in ipairs(list) do
		if type(st) == "table" then
			say(tostring(st.place) .. ": " .. #(st.summoners or {}) .. " summoner(s), " .. #(st.helpers or {}) .. " helper(s)"
				.. (st.open == false and " - switched off" or ""))
		end
	end
end

function C.retry()
	if W.RetryBlocked then W.RetryBlocked() end
	if DR.ResetChat then DR.ResetChat() end
	say("Everything the game refused before is tried again.")
end

function C.status()
	local lines = call("Readiness") or {}
	if call("Mode") == "raid" then
		say("Raid summons " .. (call("IsOpen") and "running" or "stopped") .. (call("IsPaused") and ", paused" or "") .. ".")
	end
	if call("Mode") ~= "raid" then
		say("Driving " .. (call("IsOpen") and ("open: " .. W.Money(price()) .. " to " .. dest()) or "closed")
			.. (call("IsPaused") and ", paused" or "") .. ".")
	end
	for _, l in ipairs(lines) do
		if type(l) == "table" then say((l.ok and "|cff60ff60 ok |r " or (l.ok == nil and "|cffa0a0a0 -- |r " or "|cffff5050 !! |r ")) .. tostring(l.text or "")) end
	end
	local comm = DR.comm or {}
	say("Crew messages: " .. (comm.sent or 0) .. " sent, " .. (comm.failed or 0) .. " refused, " .. (comm.heard or 0) .. " heard.")
	local chat = DR.chat or {}
	say("Whispers go by " .. (DR.ChatMode and DR.ChatMode() or "macro") .. "; seen leaving " .. (chat.confirms or 0) .. ", not seen " .. (chat.misses or 0) .. ".")
end
C.check = C.status

function C.show()
	if DR.Button and DR.Button.SetShown then DR.Button.SetShown(true) end
	say("The big button is shown.")
end
function C.hide()
	if DR.Button and DR.Button.SetShown then DR.Button.SetShown(false) end
	say("The big button is hidden. " .. Y .. "/wuber drive show" .. R .. " brings it back.")
end
function C.lock()
	if DR.Button and DR.Button.SetLocked then DR.Button.SetLocked(true) end
	say("The big button stays where it is.")
end
function C.unlock()
	if DR.Button and DR.Button.SetLocked then DR.Button.SetLocked(false) end
	say("Shift-drag the big button to move it.")
end
function C.resetpos()
	if DR.ResetPosition then DR.ResetPosition() end
	say("The big button is back in the middle.")
end

function C.scale(arg)
	local low = arg:lower()
	if low == "auto" or low == "fit" then
		DR.SetScale(nil)
		say("The big button fits the window: " .. math.floor(DR.Scale() * 100 + 0.5) .. "% here.")
		return
	end
	local n = tonumber(arg)
	if not n then
		say("The big button is at " .. math.floor(DR.Scale() * 100 + 0.5) .. "%. Try 1.5 (0.5 to 3) or auto.")
		return
	end
	if n >= 10 then n = n / 100 end -- "150" means 150%
	if n < 0.5 or n > 3 then
		say("The big button can be 0.5 to 3 (or 50 to 300 percent), or auto. It stays at " .. math.floor(DR.Scale() * 100 + 0.5) .. "%.")
		return
	end
	DR.SetScale(n)
	say("Big button size: " .. math.floor(DR.Scale() * 100 + 0.5) .. "%.")
end

local function run(line)
	local cmd, arg = trim(line):match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	arg = trim(arg)
	if cmd == "" then
		show("console")
		return
	end
	local toggle = TOGGLES[cmd]
	if toggle then
		local v = arg:lower()
		local db = toggle.db and (W.db or {}) or opts()
		if v == "on" or v == "off" then
			local on = v == "on"
			-- (2.3.2) inviting public chat buyers is turned on only after its warning
			-- (Yes / Cancel on screen); the answer is said when it comes
			if toggle.key == "autoPublic" and type(DR.SetAutoPublic) == "function" then
				local res = DR.SetAutoPublic(on, function(yes)
					say(toggle.text .. ": " .. (yes and "on" or "off") .. ".")
					call("Changed")
				end)
				if res == nil then say(toggle.text .. ": off (the warning can't be shown right now).") end
				return
			end
			if toggle.db then
				db[toggle.key] = on
				W.Fire("SETTINGS", toggle.key)
			else
				setOpt(toggle.key, on)
				db = opts()
			end
			if toggle.shared and DR.SendConfig then call("SendConfig") end
		elseif v ~= "" then
			say(Y .. "/wuber drive " .. cmd .. " on" .. R .. ", or " .. Y .. "off" .. R)
			return
		end
		local cur
		if toggle.db then
			cur = db[toggle.key]
		else
			cur = type(DR.Opt) == "function" and call("Opt", toggle.key)
			if cur == nil then cur = db[toggle.key] end
		end
		say(toggle.text .. ": " .. (cur ~= false and "on" or "off") .. ".")
		call("Changed")
		return
	end
	local fn = C[cmd]
	if fn then
		fn(arg)
		call("Changed")
		return
	end
	say("Unknown: " .. cmd .. ". " .. Y .. "/wuber drive help" .. R .. " lists the commands.")
end

-- Runs one typed driving command ("price 1g", "pause"...), as after "/wuber drive".
function DR.Command(line)
	W.Safe("/wuber drive", run, line)
end
