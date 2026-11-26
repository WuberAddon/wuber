-- Mutation run 2765: guards for auto-reply refusals and payment (Drive/AutoReply, Trade, Commands).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function openOrgDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().watchPublic = true
	ok(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	return w, a, DR
end

local function faction(a) return (a.player and a.player.faction) or "Horde" end

-- a real public "WTB summon" line from a stranger; returns how many whispers went back to them
local function ask(w, a, name)
	if not w:player(name) then
		w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = faction(a) })
	end
	w:chatFrom(name, "WTB summon to Orgrimmar", "CHANNEL", "Trade", faction(a))
	w:advance(0.5)
	return #w:whispersTo(name, "reply")
end

-- the asker is let through first, so the refusal below is the only thing that changes
local function allowed(DR, who)
	local yes, why = DR.CanReply(who)
	eq(yes, true, "baseline: " .. who .. " may be whispered (" .. tostring(why) .. ")")
end

local function refused(DR, who, reason)
	local yes, why = DR.CanReply(who)
	eq(yes, false, "refused with false, not nil")
	eq(why, reason, "the reason the driver sees")
end

-- guards Wuber/Drive/AutoReply.lua:256 (mutation run 2765, mutant 1622: return -> nil)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation pay: no auto-reply while the game refuses addon invites, and the reason says so", function()
	local w, a, DR = openOrgDriver()
	allowed(DR, "Dan Miller")
	local W = a.W
	local real = W.IsBlocked
	W.IsBlocked = function(what) return what == "invite" end
	eq(ask(w, a, "Dan Miller"), 0, "nothing is whispered")
	refused(DR, "Dan Miller", "the game refuses addon invites")
	W.IsBlocked = real
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:285 (mutation run 2765, mutant 16162: return -> nil)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation pay: no auto-reply when the group is already full, and the reason says so", function()
	local w, a, DR = openOrgDriver()
	allowed(DR, "Dan Miller")
	DR.GroupSize = function() return DR.MaxGroup() end
	eq(ask(w, a, "Dan Miller"), 0, "nothing is whispered")
	refused(DR, "Dan Miller", "group is full")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:280 (mutation run 2765, mutant 18984: return -> nil)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation pay: no auto-reply while invites are paused, and the reason says so", function()
	local w, a, DR = openOrgDriver()
	allowed(DR, "Dan Miller")
	DR.inviteHold = a.W.Now() + 100
	eq(ask(w, a, "Dan Miller"), 0, "nothing is whispered")
	refused(DR, "Dan Miller", "invites paused")
	DR.inviteHold = nil
	allowed(DR, "Dan Miller")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:308 (mutation run 2765, mutant 13939: return -> nil)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation pay: a blocked player is never whispered, and the reason says so", function()
	local w, a, DR = openOrgDriver()
	allowed(DR, "Dan Miller")
	DR.db.blocklist = DR.db.blocklist or {}
	DR.db.blocklist[key("Dan Miller")] = { reason = "never paid" }
	eq(ask(w, a, "Dan Miller"), 0, "nothing is whispered")
	refused(DR, "Dan Miller", "blocked")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:321 (mutation run 2765, mutant 4222: return -> nil)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation pay: someone already whispered back is not whispered again within the hour", function()
	local w, a, DR = openOrgDriver()
	w:addBot("Fay Wood", { spot = "Ratchet", acceptsInvites = false, faction = (a.player and a.player.faction) or "Horde" })
	w:chatFrom("Fay Wood", "WTB summon to Orgrimmar", "CHANNEL", "Trade", (a.player and a.player.faction) or "Horde")
	w:advance(0.5)
	eq(#w:whispersTo("Fay Wood", "reply"), 1, "first ask gets the whisper")
	w:advance(600)
	w:chatFrom("Fay Wood", "WTB summon to Orgrimmar", "CHANNEL", "Trade", faction(a))
	w:advance(0.5)
	eq(#w:whispersTo("Fay Wood", "reply"), 1, "no second whisper went out")
	refused(DR, "Fay Wood", "already whispered within the hour")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:225 (mutation run 2765, mutant 9931: return -> nil)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation pay: no auto-reply once the hourly whisper limit is reached, and the reason says so", function()
	local w, a, DR = openOrgDriver()
	allowed(DR, "Dan Miller")
	local was = DR.REPLY_HOURLY
	DR.REPLY_HOURLY = 0
	eq(ask(w, a, "Dan Miller"), 0, "nothing is whispered")
	refused(DR, "Dan Miller", "whisper back limit for the hour reached")
	DR.REPLY_HOURLY = was
	allowed(DR, "Dan Miller")
	T.clean(w)
end)

-- guards Wuber/Drive/Trade.lua:180 (mutation run 2765, mutant 8402: swap or->and)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation pay: a stranger's gold in a trade is booked under their name, or ? when the name is unknown", function()
	local w, a, DR = openOrgDriver()
	local seen = {}
	DR.Do = function(what, who, amount) seen[#seen + 1] = { what, who, amount } end
	DR.IsOpen = function() return true end
	DR.TradeDone({ name = "Zed Rider", money = 7000, complete = true })
	eq(#seen, 1, "one payment booked")
	eq(seen[1][1], "PAID") eq(seen[1][2], "Zed Rider", "under the payer's name") eq(seen[1][3], 7000)
	DR.TradeDone({ money = 3000, complete = true })
	eq(#seen, 2, "a nameless payer is booked too")
	eq(seen[2][2], "?", "under ?")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:326 (mutation run 2765, mutant 9994: cmp >-><=)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation pay: /wuber drive paid books what is still owed, else the rider's own price", function()
	local w, a, DR = openOrgDriver()
	local seen, owed = {}, 0
	local c = { name = "Dan Miller", key = key("Dan Miller"), price = 12345 }
	DR.MarkPaid = nil
	DR.Find = function() return c end
	DR.Due = function() return owed end
	DR.Do = function(what, who, amount, how) seen[#seen + 1] = { what, who, amount, how } end
	DR.COMMANDS.paid("Dan Miller")
	eq(#seen, 1, "one payment booked")
	eq(seen[1][1], "PAID") eq(seen[1][2], "Dan Miller") eq(seen[1][4], "m")
	eq(seen[1][3], 12345, "nothing owed: the rider's price")
	owed = 4000
	DR.COMMANDS.paid("Dan Miller")
	eq(seen[2][3], 4000, "part owed: what is left")
	T.clean(w)
end)
