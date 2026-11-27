-- Tests from the mutation run (job 2765): the driver's auto-reply whisper (Drive/AutoReply.lua).
-- Each test guards lines that no other test noticed when they were broken. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- a Horde Warlock driver open in Orgrimmar with auto mode and public chat on
local function openOrgDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().watchPublic = true
	ok(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	return w, a, DR, (a.player and a.player.faction) or "Horde"
end

-- run fn with some fields of a table replaced (false stands for nil), then put them back
local function with(tbl, over, fn)
	local saved, had = {}, {}
	for k, v in pairs(over) do
		saved[k] = tbl[k]
		if v == false then tbl[k] = nil else tbl[k] = v end
	end
	local good, err = pcall(fn)
	for k in pairs(over) do tbl[k] = saved[k] end
	if not good then error(err, 0) end
end

-- what CanReply says for a sender, as "false/reason"
local function why(DR, sender)
	local can, reason = DR.CanReply(sender)
	return tostring(can) .. "/" .. tostring(reason)
end

-- guards Wuber/Drive/AutoReply.lua:232,235,239,242,245,250,256,259,262 (mutation run, mutants 9845 9518 27449 4406 11096 9481 1622 10238 27246: drop return value)
test("mutation autoreply: every switch and state that forbids a whisper-back says false with its reason", function()
	local w, a, DR = openOrgDriver()
	eq(why(DR, "Dan Miller"), "true/nil", "control: nothing in the way")
	local build = a.W.Build()
	a.W.db.blockedBuild = a.W.db.blockedBuild or {}
	a.W.db.blockedBuild[build] = a.W.db.blockedBuild[build] or {}

	with(DR, { on = false }, function() eq(why(DR, "Dan Miller"), "false/not a driver", "addon not running") end)
	DR.SetOpen(false)
	eq(why(DR, "Dan Miller"), "false/not open", "closed")
	ok(DR.SetOpen(true), "reopen")
	DR.opts().autoInvite = false
	eq(why(DR, "Dan Miller"), "false/Inviting riders who whisper you or ask in the app is off", "auto mode off")
	DR.opts().autoInvite = true
	DR.opts().watchPublic = false
	eq(why(DR, "Dan Miller"), "false/Listing people who ask for a summon in public chat is off", "public chat off")
	DR.opts().watchPublic = true
	DR.opts().autoReply = false
	eq(why(DR, "Dan Miller"), "false/Whisper back to public requests is off", "auto-reply switched off")
	DR.opts().autoReply = true
	DR.opts().whisperMode = "box"
	eq(why(DR, "Dan Miller"), "false/whispers are not set to go by themselves", "chat box mode needs the player's Enter")
	DR.opts().whisperMode = "off"
	eq(why(DR, "Dan Miller"), "false/whispers are not set to go by themselves", "whispers off")
	DR.opts().whisperMode = "macro"
	a.W.db.blockedBuild[build].invite = true
	eq(why(DR, "Dan Miller"), "false/the game refuses addon invites", "the game refuses addon invites")
	a.W.db.blockedBuild[build].invite = nil
	DR.char().paused = true
	eq(why(DR, "Dan Miller"), "false/paused", "paused")
	DR.char().paused = false
	local realCasting = a.env.UnitCastingInfo
	a.env.UnitCastingInfo = function() return "Hearthstone" end
	eq(why(DR, "Dan Miller"), "false/travelling", "casting a travel spell")
	a.env.UnitCastingInfo = realCasting
	eq(why(DR, "Dan Miller"), "true/nil", "control again")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:265,268,274,277,280,285 (mutation run, mutants 27484 6283 10815 13425 18984 16162: drop return value)
test("mutation autoreply: no whisper-back when the driver cannot invite, is fighting, is inside, is mid-ride, is on hold or is full", function()
	local w, a, DR = openOrgDriver()
	with(DR, { CanInvite = function() return false end }, function()
		eq(why(DR, "Dan Miller"), "false/cannot invite", "cannot invite")
	end)
	w:enterCombat(a)
	eq(why(DR, "Dan Miller"), "false/in combat", "in combat")
	w:leaveCombat(a)
	a.player.instance = true
	eq(why(DR, "Dan Miller"), "false/in an instance", "in an instance")
	a.player.instance = false
	with(DR, { Busy = function() return true end }, function()
		eq(why(DR, "Dan Miller"), "false/a ride is in progress", "a ride is in progress")
	end)
	DR.inviteHold = a.W.Now() + 10
	eq(why(DR, "Dan Miller"), "false/invites paused", "the game said the party is full a moment ago")
	DR.inviteHold = nil
	with(DR, { GroupSize = function() return 5 end }, function()
		eq(why(DR, "Dan Miller"), "false/group is full", "the group is full")
	end)
	eq(why(DR, "Dan Miller"), "true/nil", "control: all clear again")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:290,297,301,304,308,311,314,318,321 (mutation run, mutants 8856 18207 16118 7962 13939 1871 11392 9714 4222: drop return value)
test("mutation autoreply: never whisper a half name, yourself, the group, a driver, a blocked, crew, held, riding or just-answered player", function()
	local w, a, DR = openOrgDriver()
	eq(why(DR, "Dan"), "false/not a full name", "one-word name")
	eq(why(DR, T.ANITA), "false/yourself", "the driver's own line")
	DR.units[key("Eve Stone")] = "party1"
	eq(why(DR, "Eve Stone"), "false/in your group", "a group member")
	DR.units[key("Eve Stone")] = nil
	a.W.drivers[key("Fay Wood")] = { state = "open" }
	eq(why(DR, "Fay Wood"), "false/another driver", "another driver")
	a.W.drivers[key("Fay Wood")] = nil
	DR.db.blocklist = DR.db.blocklist or {}
	DR.db.blocklist[key("Gil Moss")] = true
	eq(why(DR, "Gil Moss"), "false/blocked", "blocked player")
	DR.db.blocklist[key("Gil Moss")] = nil
	DR.helpers[key("Hal Reed")] = true
	eq(why(DR, "Hal Reed"), "false/never a rider", "crew helper")
	DR.helpers[key("Hal Reed")] = nil
	DR.SetServeHold("Ida Frost", true)
	eq(why(DR, "Ida Frost"), "false/not served again yet", "held by the driver")
	DR.customers[key("Jon Vale")] = { state = "invited" }
	with(DR, { Busy = function() return false end }, function()
		eq(why(DR, "Jon Vale"), "false/already a rider", "already a rider")
	end)
	DR.customers[key("Jon Vale")] = nil
	DR.db.replied = { [key("Kay Pine")] = a.env.time() - 60 }
	eq(why(DR, "Kay Pine"), "false/already whispered within the hour", "whispered a minute ago")
	eq(why(DR, "Dan Miller"), "true/nil", "control: a stranger is fine")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:294 (mutation run, mutant 28807: drop return value)
test("mutation autoreply: a name that cannot be turned into a key is never whispered", function()
	local w, a, DR = openOrgDriver()
	with(a.W, { Key = function() return nil end }, function()
		eq(why(DR, "Dan Miller"), "false/not a full name", "CanReply without a key")
	end)
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:399,403 (mutation run, mutants 24280 23093: drop return value)
-- guard: the name is checked again after the gate, so TryReply alone refuses a bad name even if the gate said yes
test("mutation autoreply: TryReply re-checks the name itself", function()
	local w, a, DR = openOrgDriver()
	with(DR, { CanReply = function() return true end }, function()
		local sent, reason = DR.TryReply("Dan", "WTB summon to Orgrimmar", "invite")
		eq(sent, false, "a one-word name is not whispered")
		eq(reason, "not a full name", "reason for a one-word name")
		with(a.W, { Key = function() return nil end }, function()
			local sent2, reason2 = DR.TryReply("Dan Miller", "WTB summon to Orgrimmar", "invite")
			eq(sent2, false, "no key, no whisper")
			eq(reason2, "not a full name", "reason for no key")
		end)
	end)
	eq(#w:whispersTo("Dan", "reply"), 0, "nothing left")
	eq(#w:whispersTo("Dan Miller", "reply"), 0, "nothing left for the full name either")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:177 (mutation run, mutant 14850 is killed by the "fits two different served places" test below, not this one)
test("mutation autoreply: a line naming two places gets no reply place and says why", function()
	local w, a, DR = openOrgDriver()
	local place, reason = DR.ReplyPlace("WTB summon to org and uc pls")
	eq(place, nil, "no place")
	eq(reason, "more than one place", "two places named")
	eq(DR.ReplyPlace("WTB summon to Orgrimmar"), "Orgrimmar", "control: one place is answered")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:191,194,197,200,201,202,207 (mutation run, mutants 8066 12658 22066 4087 30632 26971 31038: drop return value)
test("mutation autoreply: the reply is only offered when our own whisper-back would be invited, routed here and short enough", function()
	local w, a, DR = openOrgDriver()
	local text = "WTB summon to Orgrimmar"
	eq(DR.ReplyPlace(text), "Orgrimmar", "control")
	local function refuses(over, expectWhy, label)
		with(DR, over, function()
			local place, reason = DR.ReplyPlace(text)
			eq(place, nil, label .. ": no place")
			eq(reason, expectWhy, label .. ": reason")
		end)
	end
	refuses({ Careful = function() return "ignore" end }, "whisper back would not invite", "careful would not invite")
	refuses({ Classify = function() return "chatter" end }, "whisper back is not a request", "not a request")
	refuses({ AskedFor = function() return "other" end }, "whisper back place check failed", "place check")
	refuses({ MultiStation = function() return true end, DestIn = function() return "Undercity" end },
		"whisper back would not route here", "routed elsewhere")
	refuses({ MultiStation = function() return true end, DestIn = function() return nil end },
		"whisper back would not route here", "routed nowhere")
	with(DR, { MultiStation = function() return true end, DestIn = function() return "Orgrimmar" end }, function()
		eq(DR.ReplyPlace(text), "Orgrimmar", "routed here: answered")
	end)
	refuses({ ReplyText = function() return string.rep("x", 300) end }, "reply too long", "line over 255 characters")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:411 (mutation run, mutant 27335: drop return value)
test("mutation autoreply: TryReply sends nothing when the final line turns out too long", function()
	local w, a, DR = openOrgDriver()
	local calls = 0
	with(DR, { ReplyText = function(p)
		calls = calls + 1
		return calls >= 2 and string.rep("x", 300) or ("Want a summon to " .. tostring(p))
	end }, function()
		local sent, reason = DR.TryReply("Dan Miller", "WTB summon to Orgrimmar", "invite")
		eq(sent, false, "not sent")
		eq(reason, "reply too long", "reason")
	end)
	eq(#w:whispersTo("Dan Miller", "reply"), 0, "nothing whispered")
	eq(DR.db.replied and DR.db.replied[key("Dan Miller")], nil, "and nothing remembered")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:387,391 (mutation run, mutants 21860 23689: drop return value)
test("mutation autoreply: no whisper for a line with a game link or a place we do not serve, and the reason says so", function()
	local w, a, DR = openOrgDriver()
	local sent, reason = DR.TryReply("Dan Miller", "|cff1eff00|Hitem:6948:0:0:0|h[Hearthstone]|h|r WTB summon to Orgrimmar", "invite")
	eq(sent, false, "link line: not sent")
	eq(reason, "game link", "link line: reason")
	sent, reason = DR.TryReply("Dan Miller", "WTB summon to Undercity", "invite")
	eq(sent, false, "other place: not sent")
	eq(reason, "place not served", "other place: reason")
	eq(#w:whispersTo("Dan Miller", "reply"), 0, "nothing whispered")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:183 (mutation run, mutant 14850: drop return value, the one where two served places answer to the asked place)
test("mutation autoreply: when the asked place fits two different served places there is no reply", function()
	local w, a, DR = openOrgDriver()
	local function same(x, y) return x == y or x == "Orgrimmar" or y == "Orgrimmar" end
	with(a.W, { SamePlace = same }, function()
		with(DR, { ServedPlaces = function() return { "Alpha Camp", "Beta Camp" } end }, function()
			local place, reason = DR.ReplyPlace("WTB summon to Orgrimmar")
			eq(place, nil, "no place")
			eq(reason, "more than one place", "two served places answer to the asked one")
		end)
	end)
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:123,124,126,127 (mutation run, mutants 21733 7212 22511 13509: place matching fallbacks)
test("mutation autoreply: served and asked places are matched by known entry, then by normal form, then by plain text", function()
	local w, a, DR = openOrgDriver()
	local ENTRY = { "Orgrimmar", "Org" }
	local pass = {
		AskedPlaces = function() return { { name = "Orgrimmar" } } end,
		Careful = function() return "invite" end,
		Classify = function() return "request" end,
		AskedFor = function() return "match" end,
	}
	local function over(extra)
		local o = {}
		for k, v in pairs(pass) do o[k] = v end
		for k, v in pairs(extra) do o[k] = v end
		return o
	end
	with(a.W, { SamePlace = false }, function()
		with(DR, over({
			ServedPlaces = function() return { "Org" } end,
			PlaceEntry = function(n) return (n == "Org" or n == "Orgrimmar") and ENTRY or nil end,
		}), function()
			eq(DR.ReplyPlace("anything"), "Org", "two spellings of one known place are the same place")
		end)
		with(DR, over({
			ServedPlaces = function() return { "ORGRIMMAR" } end,
			PlaceEntry = false,
		}), function()
			eq(DR.ReplyPlace("anything"), "ORGRIMMAR", "no entry known: same normal form is the same place")
		end)
		with(DR, over({
			ServedPlaces = function() return { "Undercity" } end,
			PlaceEntry = false,
		}), function()
			local place, reason = DR.ReplyPlace("anything")
			eq(place, nil, "a different place is not a match")
			eq(reason, "place not served", "reason")
		end)
		with(DR, over({
			ServedPlaces = function() return { "Orgrimmar" } end,
			PlaceEntry = false,
			Norm = false,
		}), function()
			eq(DR.ReplyPlace("anything"), "Orgrimmar", "nothing to normalise with: identical text is the same place")
		end)
	end)
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:135,136,137 (mutation run, mutants 12672 5697 10641: served place fallback)
test("mutation autoreply: with no station list the single destination is the served place, unless it is Unknown", function()
	local w, a, DR = openOrgDriver()
	with(DR, { ServedPlaces = function() return nil end, Dest = function() return "Orgrimmar" end }, function()
		eq(DR.ReplyPlace("WTB summon to Orgrimmar"), "Orgrimmar", "the destination is served")
	end)
	with(DR, { ServedPlaces = function() return nil end, Dest = function() return "Unknown" end }, function()
		local place, reason = DR.ReplyPlace("WTB summon to Orgrimmar")
		eq(place, nil, "Unknown is not a place")
		eq(reason, "no served place", "reason")
	end)
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:222,225,325 (mutation run, mutants 29904 9931 24534: overall whisper-back limits)
test("mutation autoreply: whisper-backs keep 8 seconds apart and stop at the hourly limit, and the gate says so", function()
	local w, a, DR = openOrgDriver()
	local sent = DR.TryReply("Dan Miller", "WTB summon to Orgrimmar", "invite")
	eq(sent, true, "first whisper-back goes")
	eq(why(DR, "Eve Stone"), "false/too soon after the last whisper back", "a second asker right away")
	local s2, r2 = DR.TryReply("Eve Stone", "WTB summon to Orgrimmar", "invite")
	eq(s2, false, "TryReply holds back")
	eq(r2, "too soon after the last whisper back", "with the reason")
	w:advance(9)
	DR.REPLY_HOURLY = 1
	eq(why(DR, "Eve Stone"), "false/whisper back limit for the hour reached", "one an hour is the limit here")
	DR.REPLY_HOURLY = 30
	eq(why(DR, "Eve Stone"), "true/nil", "control: allowed again with the real limit")
	eq(#w:whispersTo("Eve Stone", "reply"), 0, "nothing went to the second asker")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:419,427 (mutation run, mutants 23531 29870: a whisper that cannot be sent or remembered)
test("mutation autoreply: a whisper that cannot be remembered or cannot be sent is reported and leaves no stamp", function()
	local w, a, DR = openOrgDriver()
	-- cannot be sent: the chat call fails
	local realSend = a.env.C_ChatInfo.SendChatMessage
	a.env.C_ChatInfo.SendChatMessage = function() error("the game said no") end
	local sent, reason = DR.TryReply("Dan Miller", "WTB summon to Orgrimmar", "invite")
	a.env.C_ChatInfo.SendChatMessage = realSend
	eq(sent, false, "not sent")
	eq(reason, "could not send", "reason")
	eq(DR.db.replied[key("Dan Miller")], nil, "the asker is not marked as answered")
	eq(#w:whispersTo("Dan Miller", "reply"), 0, "nothing went out")
	-- cannot be remembered: no saved table to keep the stamp in
	local replied = DR.db.replied
	DR.db.replied = false
	with(DR, { db = false, CanReply = function() return true end,
		ReplyPlace = function() return "Orgrimmar" end }, function()
		with(a.W.db, { drive = false }, function()
			local s2, r2 = DR.TryReply("Eve Stone", "WTB summon to Orgrimmar", "invite")
			eq(s2, false, "not sent without a place to remember it")
			eq(r2, "nowhere to remember the whisper", "reason")
		end)
	end)
	DR.db.replied = replied
	eq(#w:whispersTo("Eve Stone", "reply"), 0, "nothing went out")
	T.clean(w)
end)

-- the number Drive/AutoReply.lua works out for an asker and a driver (their copy is local)
local function turnScore(askerKey, driverKey)
	local s = askerKey .. "|" .. driverKey
	local h = 7
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
	return h
end

-- guards Wuber/Drive/AutoReply.lua:349,353,357 (mutation run, mutants 12546 21684 16706: early returns of the turn rule)
test("mutation autoreply: with no name, no place or no driver list it is always our turn", function()
	local w, a, DR = openOrgDriver()
	local W = a.W
	with(W, { myKey = false }, function() eq(DR.ReplyTurn("dan miller", "Orgrimmar"), true, "no key of our own") end)
	eq(DR.ReplyTurn("dan miller", ""), true, "no place")
	eq(DR.ReplyTurn("dan miller", nil), true, "place missing")
	local drivers = W.drivers
	W.drivers = nil
	local turn = DR.ReplyTurn("dan miller", "Orgrimmar")
	W.drivers = drivers
	eq(turn, true, "no driver list")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:369,407 (mutation run, mutants 814 2715: the lowest number has the turn)
test("mutation autoreply: the driver with the lowest number for the asker answers, the others stay quiet", function()
	local w, a, DR = openOrgDriver()
	local W = a.W
	local mine = turnScore("dan miller", W.myKey)
	local lower, higher
	for i = 1, 400 do
		local k = "other driver " .. i
		local s = turnScore("dan miller", k)
		if s < mine and not lower then lower = k end
		if s > mine and not higher then higher = k end
	end
	ok(lower and higher, "found a lower and a higher rival")
	local function rival(k) W.drivers = { [k] = { state = "open", dest = "Orgrimmar", ver = "2.4.2" } } end
	local drivers = W.drivers
	rival(higher)
	eq(DR.ReplyTurn("dan miller", "Orgrimmar"), true, "a rival with a higher number: our turn")
	local sent = DR.TryReply("Dan Miller", "WTB summon to Orgrimmar", "invite")
	eq(sent, true, "so the whisper goes")
	rival(lower)
	local turn, reason = DR.ReplyTurn("dan miller", "Orgrimmar")
	eq(turn, false, "a rival with a lower number: not our turn")
	eq(reason, "another driver's turn", "reason")
	w:advance(9)
	local lowerForEve
	local mineEve = turnScore("eve stone", W.myKey)
	for i = 1, 400 do
		local k = "other driver " .. i
		if turnScore("eve stone", k) < mineEve then lowerForEve = k break end
	end
	rival(lowerForEve)
	local s2, r2 = DR.TryReply("Eve Stone", "WTB summon to Orgrimmar", "invite")
	W.drivers = drivers
	eq(s2, false, "TryReply stays quiet")
	eq(r2, "another driver's turn", "with the reason")
	eq(#w:whispersTo("Eve Stone", "reply"), 0, "nothing went to the asker")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:73,75 (mutation run, mutants 27971 14885: the clock jumps but the hour has not passed)
test("mutation autoreply: a player answered a moment ago is not whispered again when the wall clock jumps forward", function()
	local w, a, DR = openOrgDriver()
	eq(DR.TryReply("Dan Miller", "WTB summon to Orgrimmar", "invite"), true, "first whisper-back")
	w:advance(30)
	local realTime = a.env.time
	a.env.time = function(t) if t then return realTime(t) end return realTime() + 5000 end
	local verdict = why(DR, "Dan Miller")
	a.env.time = realTime
	eq(verdict, "false/already whispered within the hour", "the saved stamp looks old, the game clock says it is not")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:87 (mutation run, mutant 7523: old stamps are dropped from the saved table)
test("mutation autoreply: stale whisper stamps are cleared from the saved table when a new one is written", function()
	local w, a, DR = openOrgDriver()
	local now = a.env.time()
	DR.db.replied = { [key("Old Timer")] = now - 5000, [key("Fresh One")] = now - 100 }
	eq(DR.TryReply("Dan Miller", "WTB summon to Orgrimmar", "invite"), true, "whisper-back")
	local r = DR.db.replied
	eq(r[key("Old Timer")], nil, "the stale stamp is gone")
	eq(r[key("Fresh One")], now - 100, "the fresh stamp stays")
	ok(r[key("Dan Miller")] ~= nil, "the new one is kept")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:96,97,102,103 (mutation run, mutants 10876 19769 23965 6526: the oldest stamp goes first when the table is full)
test("mutation autoreply: a full table of stamps forgets the oldest one only", function()
	local w, a, DR = openOrgDriver()
	local now = a.env.time()
	DR.REPLY_MAX = 3
	DR.db.replied = {
		[key("Zed Last")] = now - 900,   -- the oldest, and the last in alphabetical order
		[key("Amy First")] = now - 300,
		[key("Bob Middle")] = now - 600,
	}
	eq(DR.TryReply("Dan Miller", "WTB summon to Orgrimmar", "invite"), true, "whisper-back")
	local r = DR.db.replied
	eq(r[key("Zed Last")], nil, "the oldest was forgotten")
	eq(r[key("Amy First")], now - 300, "newer one kept")
	eq(r[key("Bob Middle")], now - 600, "newer one kept")
	ok(r[key("Dan Miller")] ~= nil, "the new one was kept")
	DR.REPLY_MAX = 200
	T.clean(w)
end)
