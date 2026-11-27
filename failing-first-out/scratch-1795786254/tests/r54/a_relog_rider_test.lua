-- r54 group A (FAB-11, the real game 24 Nov 15:05-15:08): a rider who booked and is in the driver's group stays
-- the driver's rider across a relog or a /reload. In the game the driver logged out and back in while standing in
-- Orgrimmar; for the first moments after a login the game placed the player on the continent's map ("Kalimdor", no
-- zone text yet), the place sweep took that for the place the driver serves, gave the restored rider (whose saved row
-- had no booked place) "Kalimdor" as his place, then dropped him as "moved" once Orgrimmar came back: the Riders list
-- said "Waiting for riders" while the big button offered "Say sorry to Wuber", then "Remove Wuber".
-- Promise: the rider is back on the list with the same step and the big button offers the normal next step (never a
-- sorry or a remove); a "moved" sorry only when the serving place really changed since the rider booked.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, DAN = "Anita Lift", "Dan Miller"
local KDAN = "dan miller"

local function setup()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", shards = 10 })
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = true })
	w:advance(15)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(5)
	local c = DR.customers[KDAN]
	eq(c and c.state, "joined", "control: Dan asked, was invited and is in the group")
	eq(c and c.forPlace, "Orgrimmar", "control: he booked a summon to Orgrimmar")
	return w, a
end

-- the first moments after a login: the player's map is the continent, no zone or subzone text yet
local function continentMoment(p)
	p.mapID, p.zone, p.subZone = 1414, "", ""
end

local function sorryTo(w, name)
	local n = 0
	for _, x in ipairs(w:whispersTo(name)) do if x.text:find("moved to", 1, true) then n = n + 1 end end
	return n
end

local function buttonTitle(c)
	local b = c.env.WuberDriveButton
	return b and b.title and b.title:GetText() or ""
end

-- the promise: Dan is a rider on the list with his step kept, nothing owed to him, the button about the next step
local function riderKept(w, a, what)
	local DR = a.W.Drive
	local c = DR.customers[KDAN]
	ok(c, what .. ": Dan is still on the Riders list")
	eq(c and c.state, "joined", what .. ": in the group, waiting for his summon (the same step)")
	eq(c and c.forPlace, "Orgrimmar", what .. ": still a ride to Orgrimmar")
	eq(DR.moved[KDAN], nil, what .. ": not dropped as moved")
	ok(not DR.ignored[KDAN], what .. ": not ignored")
	for _, p in ipairs(DR.Pending()) do ok(p.kind ~= "moved", what .. ": no sorry whisper owed") end
	local title = DR.Plan().title or ""
	ok(not title:find("Say sorry", 1, true), what .. ": the big button offers no sorry: " .. title)
	ok(not title:find("Remove", 1, true), what .. ": the big button offers no remove: " .. title)
	ok(not buttonTitle(a):find("Say sorry", 1, true) and not buttonTitle(a):find("Remove", 1, true),
		what .. ": the button the driver sees agrees: " .. buttonTitle(a))
	-- the big button and the list name the same rider
	local listed = false
	for _, x in ipairs(DR.Sorted()) do if x.key == KDAN then listed = true end end
	ok(not title:find("Dan", 1, true) or listed, what .. ": a rider the button names is on the list")
	eq(sorryTo(w, DAN), 0, what .. ": no sorry whisper went out")
end

-- a state change run by an event (the zone arrives) and by a timer (the sweep, once a second): two step sizes
local function reloadOnContinent(step)
	local w, a = setup()
	continentMoment(a.player)
	local a2 = w:reload(a)
	for _ = 1, math.floor(6 / step) do w:advance(step) end
	w:move(ANA, "Orgrimmar") -- the zone arrives
	for _ = 1, math.floor(20 / step) do w:advance(step) end
	riderKept(w, a2, "reload")
	T.clean(w)
end

local function relogOnContinent(step)
	local w, a = setup()
	w:logout(a)
	w:advance(10)
	continentMoment(w:player(ANA))
	local a2 = w:addClient(ANA, { saved = w.savedOf[ANA], class = "WARLOCK", shards = 10, allowMissing = true })
	for _ = 1, math.floor(6 / step) do w:advance(step) end
	w:move(ANA, "Orgrimmar")
	for _ = 1, math.floor(20 / step) do w:advance(step) end
	riderKept(w, a2, "relog")
	T.clean(w)
end

test("r54-A FAB-11: a /reload while the game still shows the continent keeps the rider (step 1 s)", function() reloadOnContinent(1) end)
test("r54-A FAB-11: a /reload while the game still shows the continent keeps the rider (step 5 s)", function() reloadOnContinent(5) end)
test("r54-A FAB-11: a relog (logout to the character screen and back) keeps the rider (step 1 s)", function() relogOnContinent(1) end)
test("r54-A FAB-11: a relog (logout to the character screen and back) keeps the rider (step 5 s)", function() relogOnContinent(5) end)

-- guard: a plain /reload (the zone known at once) kept the rider before the fix too
test("r54-A FAB-11 guard: a plain /reload keeps the rider for the same place", function()
	local w, a = setup()
	local a2 = w:reload(a)
	w:advance(20)
	riderKept(w, a2, "plain reload")
	T.clean(w)
end)

-- guard: the unchanged path, a real move (the driver goes to another city after the reload): the sorry is offered
test("r54-A FAB-11 guard: a real move after the reload still offers the sorry", function()
	local w, a = setup()
	local a2 = w:reload(a)
	w:advance(3)
	w:move(ANA, "Undercity")
	w:advance(8)
	local DR = a2.W.Drive
	eq(DR.customers[KDAN], nil, "Dan, booked for Orgrimmar, is off the list")
	local m = DR.moved[KDAN]
	eq(m and m.from, "Orgrimmar", "remembered as booked for Orgrimmar")
	eq(m and m.to, "Undercity", "the driver is in Undercity now")
	local owed = false
	for _, p in ipairs(DR.Pending()) do if p.kind == "moved" then owed = true end end
	ok(owed, "the sorry whisper is owed (the big button's click sends it)")
	eq(sorryTo(w, DAN), 0, "nothing sent by itself")
	T.clean(w)
end)

-- the booked place is what counts: the driver moved while the window was away (a hearth, then a relog in Undercity)
test("r54-A FAB-11: a relog in another city than the rider booked offers the sorry for the booked place", function()
	local w, a = setup()
	w:logout(a)
	w:move(ANA, "Undercity")
	w:advance(10)
	local a2 = w:addClient(ANA, { saved = w.savedOf[ANA], class = "WARLOCK", shards = 10, allowMissing = true })
	w:advance(10)
	local DR = a2.W.Drive
	eq(DR.customers[KDAN], nil, "Dan, booked for Orgrimmar, is off the list")
	local m = DR.moved[KDAN]
	eq(m and m.from, "Orgrimmar", "the sorry names the place he booked")
	eq(m and m.to, "Undercity", "and where the driver is now")
	T.clean(w)
end)

-- guard: a rider who left the group while the driver was away is not resurrected
test("r54-A FAB-11 guard: a rider who left the group during the relog is not back", function()
	local w, a = setup()
	w:logout(a)
	w:leave(DAN)
	w:advance(10)
	continentMoment(w:player(ANA))
	local a2 = w:addClient(ANA, { saved = w.savedOf[ANA], class = "WARLOCK", shards = 10, allowMissing = true })
	w:advance(3)
	w:move(ANA, "Orgrimmar")
	w:advance(10)
	local DR = a2.W.Drive
	eq(DR.customers[KDAN], nil, "Dan is not on the list")
	eq(DR.moved[KDAN], nil, "and nothing is owed to him")
	local title = DR.Plan().title or ""
	ok(not title:find("Dan", 1, true), "the big button is not about Dan: " .. title)
	T.clean(w)
end)
