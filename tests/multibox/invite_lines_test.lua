-- Multibox safety, invites and self-sent lines (Drive.Queue auto-invite, Drive.AutoLines): a rider who asked one own window is
-- invited once and greeted once, however often the window reloads or relogs. (A rider who whispers two windows chose to; not covered.)
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local M = dofile(T.dir .. "/multibox/mb.lua")(T)
local ANITA, ANA, BEA = T.ANITA, T.ANA, T.BEA

local function invitesTo(w, name)
	local n, k = 0, M.key(name)
	for _, inv in ipairs(w.invites) do
		if M.key(inv.to) == k then n = n + 1 end
	end
	return n
end

local function autos(w, name, text)
	local out = {}
	for _, x in ipairs(w.whispers) do
		if x.how == "auto" and H.key(x.to) == H.key(name) then out[#out + 1] = x end
	end
	return out
end

test("multibox invite: a rider whispers one own window: invited once; reloads and relogs of both windows invite nobody again", function()
	local w, cs = M.windows({ ANITA, ANA, BEA })
	w:addBot("Eve Stone", { spot = "Orgrimmar", acceptsInvites = false, faction = "Horde" })
	w:botWhisper("Eve Stone", cs[1], "summon Orgrimmar")
	w:advance(3)
	eq(invitesTo(w, "Eve Stone"), 1, "setup: invited once by the window she asked")
	local a = w:reload(cs[1])
	w:advance(20)
	local b = w:reload(w:clientOf(ANA))
	w:advance(20)
	a = M.relog(w, w:clientOf(ANITA))
	w:advance(20)
	for _, c in ipairs({ a, w:clientOf(ANA), w:clientOf(BEA) }) do c.W.Drive.SetOpen(true) end
	w:advance(30)
	eq(invitesTo(w, "Eve Stone"), 1, "after two reloads and a relog still one invite in all")
	T.clean(w)
end)

test("multibox invite: a public request invites nobody from any of three own windows", function()
	local w, cs = M.windows({ ANITA, ANA, BEA })
	M.ask(w, "Dan Miller")
	w:advance(5)
	eq(invitesTo(w, "Dan Miller"), 0, "a public line is answered with a whisper, never an invite")
	T.clean(w)
end)

test("multibox lines: the greeting goes once to a rider, and a reload of the window does not greet again", function()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", shards = 10 })
	local b = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", shards = 10 })
	w:addBot("Bob Helper", { spot = "Undercity" })
	w:addBot("Bo Second", { spot = "Undercity" })
	w:group({ ANITA, "Bob Helper", "Bo Second" })
	w:advance(1)
	ok(a.W.Drive.SetOpen(true), "the driver opens")
	ok(b.W.Drive.SetOpen(true), "the sister window opens")
	w:advance(2)
	a.W.Drive.SetLineOn("greet", true)
	b.W.Drive.SetLineOn("greet", true)
	w:addBot("Dan Moss", { spot = "Orgrimmar" })
	w:botWhisper("Dan Moss", a, "summon pls")
	w:advance(3)
	local c = a.W.Drive.Find("Dan Moss")
	ok(c and c.state == "joined", "setup: Dan is in the group")
	a.W.Fire("DRIVE_RITUAL", c.name, "c", { key = c.key, mine = true })
	w:advance(1)
	eq(#autos(w, "Dan Moss"), 1, "the greeting went once")
	local a2 = w:reload(a)
	w:advance(20)
	local c2 = a2.W.Drive.Find("Dan Moss")
	ok(c2 ~= nil, "setup: Dan is still on the reloaded window's list")
	a2.W.Fire("DRIVE_RITUAL", c2.name, "c", { key = c2.key, mine = true })
	w:advance(30)
	eq(#autos(w, "Dan Moss"), 1, "after the reload still one self-sent line to Dan in all")
	T.clean(w)
end)
