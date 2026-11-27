-- Run 1 group h: items 6 and 8. A driver can remove a rider from the group after "Take off the list" or an early
-- "Mark as paid" (an OFFER on the click, never automatic); the idle button says why when a rider is in the group.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, DAN = "Ana Smith", "Dan Miller"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function setup()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK", shards = 10 })
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = true })
	w:advance(15)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(4)
	eq(DR.customers[key(DAN)] and DR.customers[key(DAN)].state, "joined", "Dan joined")
	return w, a, DR
end

test("run1h: a rider taken off the list but still in the group is offered a Remove step at once", function()
	local w, a, DR = setup()
	DR.Do("DROP", DAN)
	w:advance(1)
	eq(DR.customers[key(DAN)], nil, "off the list")
	ok(DR.ignored[key(DAN)], "ignored, never kicked by itself")
	local plan = DR.Plan()
	ok((plan.macrotext or ""):find("/uninvite " .. DAN, 1, true), "offers /uninvite: " .. tostring(plan.macrotext))
	ok((plan.title or ""):find("Remove", 1, true), "title says Remove: " .. tostring(plan.title))
	T.clean(w)
end)

test("run1h: a joined rider who is already here is told so, not 'Open - waiting for riders'", function()
	local w, a, DR = setup()
	DR.Here = function() return true end
	local plan = DR.Plan()
	eq(plan.title, "Dan is in the group")
	ok((plan.sub or ""):find("already here", 1, true), "sub: " .. tostring(plan.sub))
	T.clean(w)
end)

test("run1h: a joined rider the summon passes over is explained, not 'Open - waiting for riders'", function()
	local w, a, DR = setup()
	local c = DR.customers[key(DAN)]
	DR.PlaceStale = function() return true end
	ok(DR.NextSummon() == nil, "no summon")
	local plan = DR.Plan()
	ok(plan.title ~= "Open - waiting for riders", "title: " .. tostring(plan.title))
	ok((plan.title or ""):find("Dan", 1, true), "names the rider: " .. tostring(plan.title))
	T.clean(w)
end)
