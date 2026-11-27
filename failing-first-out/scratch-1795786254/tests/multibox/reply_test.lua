-- Multibox safety, the auto-reply whisper (Drive.AutoReply): the author's own windows must never whisper the same stranger twice
-- (one stranger, one whisper, one hour) after a /reload, a relog or a lost window. Two- and three-window scenarios.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local M = dofile(T.dir .. "/multibox/mb.lua")(T)
local ANITA, ANA, BEA = T.ANITA, T.ANA, T.BEA

local function total(w, who) return M.replies(w, who) end

test("multibox reply: two open windows, one stranger, one whisper in all", function()
	local w, cs = M.windows({ ANITA, ANA })
	M.ask(w, "Dan Miller")
	eq(total(w, "Dan Miller"), 1, "one whisper from two own windows")
	w:advance(600)
	M.ask(w, "Dan Miller")
	eq(total(w, "Dan Miller"), 1, "still one ten minutes later")
	T.clean(w)
end)

test("multibox reply: three open windows, three strangers, one whisper each", function()
	local w, cs = M.windows({ ANITA, ANA, BEA })
	for _, n in ipairs({ "Dan Miller", "Eve Stone", "Fay Wood" }) do M.ask(w, n) end
	for _, n in ipairs({ "Dan Miller", "Eve Stone", "Fay Wood" }) do eq(total(w, n), 1, n .. ": one whisper from three own windows") end
	for _, n in ipairs({ "Dan Miller", "Eve Stone", "Fay Wood" }) do M.ask(w, n) end
	for _, n in ipairs({ "Dan Miller", "Eve Stone", "Fay Wood" }) do eq(total(w, n), 1, n .. ": still one") end
	T.clean(w)
end)

test("multibox reply: the window that whispered reloads: the stranger asks again, no second whisper", function()
	local w, cs = M.windows({ ANITA, ANA })
	M.ask(w, "Dan Miller")
	eq(total(w, "Dan Miller"), 1, "setup: one whisper")
	for _, c in ipairs({ cs[1], cs[2] }) do
		local nc = M.reload(w, w:clientOf(c.player.name))
		w:advance(20)
		nc.W.Drive.SetOpen(true)
		w:advance(3)
	end
	M.ask(w, "Dan Miller")
	eq(total(w, "Dan Miller"), 1, "both windows reloaded: still one whisper in all")
	T.clean(w)
end)

test("multibox reply: relog of each window: no second whisper to the same stranger", function()
	local w, cs = M.windows({ ANITA, ANA, BEA })
	M.ask(w, "Dan Miller")
	eq(total(w, "Dan Miller"), 1, "setup: one whisper")
	for _, c in ipairs({ cs[1], cs[2], cs[3] }) do
		local nc = M.relog(w, w:clientOf(c.player.name))
		w:advance(20)
		nc.W.Drive.SetOpen(true)
		w:advance(3)
	end
	M.ask(w, "Dan Miller")
	eq(total(w, "Dan Miller"), 1, "all three relogged: still one whisper in all")
	T.clean(w)
end)

test("multibox reply: the whisperer logs out while its beacon is still fresh: the sister window stays quiet (the beacon turn)", function()
	local w, cs = M.windows({ ANITA, ANA })
	M.ask(w, "Dan Miller")
	eq(total(w, "Dan Miller"), 1, "setup: one whisper")
	local who
	for _, x in ipairs(w:whispersTo("Dan Miller", "reply")) do who = x.from end
	local first = w:clientOf(who)
	ok(first ~= nil, "setup: the whisperer is found")
	w:logout(first)
	w:advance(60)
	M.ask(w, "Dan Miller")
	eq(total(w, "Dan Miller"), 1, "the other own window did not whisper the same stranger within the hour")
	T.clean(w)
end)

-- Own windows marked as his own (a crew in one party): what one whispered, the sister window knows, so a lost window does not
-- make the stranger hear from the other one within the hour. (Windows that are not in a crew share nothing: see the report.)
local function crewWindows(names)
	local w, cs = M.windows(names)
	local cap = cs[1]
	w:group(names)
	w:advance(3)
	for i = 2, #cs do
		ok(cap.W.Drive.OfferCrew(names[i]), "setup: crew offer to " .. names[i])
		w:advance(3)
		cs[i].W.Drive.AnswerOffer(names[1], true)
		w:advance(3)
		ok(cs[i].W.Drive.char().captain ~= "", "setup: " .. names[i] .. " is in the crew")
	end
	for _, c in ipairs(cs) do c.W.Drive.opts().autoInvite = true c.W.Drive.opts().watchPublic = true end
	w:advance(10)
	return w, cs
end

test("multibox reply: crew windows: the whisperer logs out, its beacon goes stale: the sister window stays quiet for the hour", function()
	local w, cs = crewWindows({ ANITA, ANA })
	M.ask(w, "Dan Miller")
	eq(total(w, "Dan Miller"), 1, "setup: one whisper")
	local who
	for _, x in ipairs(w:whispersTo("Dan Miller", "reply")) do who = x.from end
	local first = w:clientOf(who)
	ok(first ~= nil, "setup: the whisperer is found")
	w:advance(5)
	w:logout(first)
	w:advance(1500) -- the gone window's beacon is stale by now; 25 minutes into the stranger's hour
	local other = (who == ANITA) and w:clientOf(ANA) or w:clientOf(ANITA)
	ok(other.W.Drive.Selling(), "setup: the sister window is still open")
	M.ask(w, "Dan Miller")
	eq(total(w, "Dan Miller"), 1, "the sister window did not whisper the same stranger again within the hour")
	T.clean(w)
end)

test("multibox reply: the crew turn counts only crew Warlocks that can answer: an old version, a helper or a window with no hello holds no turn", function()
	local w, cs = crewWindows({ ANITA, ANA })
	local A, B = cs[1].W.Drive, cs[2].W.Drive
	local bKey = cs[2].W.myKey
	local app = A.apps[bKey]
	ok(app and app.role == "L", "setup: Anita's window has Ana's hello (a Warlock driver)")
	local function turns()
		local n = 0
		for i = 1, 40 do
			if A.ReplyTurn("asker" .. i .. " realm", "Orgrimmar") then n = n + 1 end
		end
		return n
	end
	local counted = turns()
	ok(counted > 0 and counted < 40, "control: with Ana counted the turns are shared (" .. counted .. " of 40 are Anita's)")
	local was = app.version
	app.version = "2.3.9"
	eq(turns(), 40, "an older Wuber never answers: every turn is Anita's")
	app.version = was
	A.apps[bKey] = nil
	eq(turns(), 40, "no hello from the window: it holds no turn")
	A.apps[bKey] = app
	app.role = "H"
	eq(turns(), 40, "a crew helper (not a Warlock driver) holds no turn")
	app.role = "L"
	ok(turns() < 40, "control again: with Ana's hello back the turns are shared")
	T.clean(w)
end)

test("multibox reply: three crew windows: a stranger is whispered once, the crew knows it, and a new stranger is still answered", function()
	local w, cs = crewWindows({ ANITA, ANA, BEA })
	M.ask(w, "Dan Miller")
	eq(total(w, "Dan Miller"), 1, "setup: one whisper")
	w:advance(5)
	local stamped = 0
	for _, c in ipairs(cs) do
		local r = c.env.WuberDB.drive.replied
		if type(r) == "table" and r[M.key("Dan Miller")] then stamped = stamped + 1 end
	end
	eq(stamped, 3, "all three own windows hold the stamp")
	M.ask(w, "Eve Stone")
	eq(total(w, "Eve Stone"), 1, "a new stranger is answered")
	T.clean(w)
end)

test("multibox reply: a window reloads and hears the stranger before it knows the other's beacon: one whisper in all", function()
	local w, cs = M.windows({ ANITA, ANA })
	local nc = M.reload(w, cs[2])
	nc.W.Drive.SetOpen(true)
	w:advance(0.5)
	M.ask(w, "Gil Moss")
	eq(total(w, "Gil Moss"), 1, "one whisper although one window had just reloaded")
	T.clean(w)
end)

test("multibox reply: the stamp is in the saved variables, so the hour survives a reload on its own", function()
	local w, cs = M.windows({ ANITA })
	M.ask(w, "Dan Miller")
	eq(total(w, "Dan Miller"), 1, "setup: one whisper")
	local nc = M.reload(w, cs[1])
	local saved = nc.env.WuberDB and nc.env.WuberDB.drive and nc.env.WuberDB.drive.replied
	ok(type(saved) == "table" and type(saved[M.key("Dan Miller")]) == "number", "the reply stamp is in WuberDB.drive.replied after the reload")
	T.clean(w)
end)
