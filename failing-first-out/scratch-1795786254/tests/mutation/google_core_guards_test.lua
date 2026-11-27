-- Guard tests for Wuber/Drive/Core.lua lines not protected by other tests.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- guards Wuber/Drive/Core.lua:332 (== to ~=)
test("mutation core: answering the public-invites warning clears the pending state before callbacks run", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	T.settle(w)
	local DR = a.W.Drive
	local secondAnswer = nil
	local secondRes = nil
	eq(DR.SetAutoPublic(true, function(v)
		eq(v, false, "first caller hears cancel")
		-- If a callback re-prompts while the popup frame is still visible (before hide),
		-- it must open a fresh prompt rather than joining the finishing callback list.
		secondRes = DR.SetAutoPublic(true, function(v2) secondAnswer = v2 end)
	end), "asked", "first call shows warning")
	local dlg = a.env.StaticPopupDialogs[DR.PUBLIC_POPUP]
	ok(dlg, "warning dialog registered")
	dlg.OnCancel()
	eq(secondRes, "asked", "re-prompting asks anew")
	eq(secondAnswer, nil, "second callback waits for the new prompt instead of inheriting the old cancel")
	a.env.StaticPopup_Hide(DR.PUBLIC_POPUP)
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:744 (and to or)
test("mutation core: UnitClassKey returns the class file string for a grouped player", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	local b = w:addClient(T.BOB, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)
	w:group({ T.ANITA, T.BOB })
	w:advance(2)
	eq(a.W.Drive.UnitClassKey(key(T.BOB)), "MAGE", "returns the class file string, not a boolean")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:892 (== to ~=)
test("mutation core: importing old addon logs preserves existing ride lines", function()
	local w = T.newWorld()
	local a = w:addClient(T.ANITA, { spot = "Undercity", class = "WARLOCK" })
	T.settle(w)
	a.W.db.drive.log.rides = { "100,existing ride" }
	a.env.RitualRidesDB = { log = { rides = { "200,imported ride" } } }
	ok(a.W.Drive.ImportRR(), "import runs")
	local rides = a.W.db.drive.log.rides
	eq(#rides, 2, "both existing and imported lines are kept")
	eq(rides[1], "100,existing ride", "existing line preserved")
	eq(rides[2], "200,imported ride", "imported line appended")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:899 (~= to ==)
test("mutation core: importing old addon logs sorts lines chronologically by timestamp", function()
	local w = T.newWorld()
	local a = w:addClient(T.ANITA, { spot = "Undercity", class = "WARLOCK" })
	T.settle(w)
	a.env.RitualRidesDB = { log = { rides = { "200,later", "100,earlier" } } }
	ok(a.W.Drive.ImportRR(), "import runs")
	local rides = a.W.db.drive.log.rides
	eq(rides[1], "100,earlier", "earlier timestamp comes first")
	eq(rides[2], "200,later", "later timestamp comes second")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:900 (< to >=)
test("mutation core: importing old addon logs keeps equal-timestamp lines in order without error", function()
	local w = T.newWorld()
	local a = w:addClient(T.ANITA, { spot = "Undercity", class = "WARLOCK" })
	T.settle(w)
	a.env.RitualRidesDB = { log = { rides = { "100,first", "100,second" } } }
	ok(a.W.Drive.ImportRR(), "import runs")
	local rides = a.W.db.drive.log.rides
	eq(rides[1], "100,first", "first equal-time line stays first")
	eq(rides[2], "100,second", "second equal-time line stays second")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:910 (negate the if)
test("mutation core: importing old addon hour stats keeps valid 10-digit hour keys and skips invalid ones", function()
	local w = T.newWorld()
	local a = w:addClient(T.ANITA, { spot = "Undercity", class = "WARLOCK" })
	T.settle(w)
	a.env.RitualRidesDB = { log = { open = { ["1234567890"] = 3, bad = 5 } } }
	ok(a.W.Drive.ImportRR(), "import runs")
	local open = a.W.db.drive.log.open
	eq(open["1234567890"], 3, "valid 10-digit hour key imported")
	eq(open["bad"], nil, "invalid key ignored")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:980 (and to or)
test("mutation core: importing old addon bell team caps the list at 8 members", function()
	local w = T.newWorld()
	local a = w:addClient(T.ANITA, { spot = "Undercity", class = "WARLOCK" })
	T.settle(w)
	a.env.RitualRidesDB = {
		bellTeam = {
			"One A", "Two B", "Three C", "Four D", "Five E",
			"Six F", "Seven G", "Eight H", "Nine I", "Ten J",
		},
	}
	ok(a.W.Drive.ImportRR(), "import runs")
	eq(#a.W.db.drive.bell.team, 8, "bell team stops at 8 entries")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:989 (== to ~=)
test("mutation core: importing old addon button position preserves string anchor fields", function()
	local w = T.newWorld()
	local a = w:addClient(T.ANITA, { spot = "Undercity", class = "WARLOCK" })
	T.settle(w)
	a.env.RitualRidesDB = { pos = { point = "CENTER", x = 10, y = 20 } }
	ok(a.W.Drive.ImportRR(), "import runs")
	local pos = a.W.db.drive.button.pos
	eq(pos.point, "CENTER", "string point preserved")
	eq(pos.x, 10, "numeric x preserved")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:1127 (return false)
test("mutation core: MergeRetired returns true when merging post-import old addon data", function()
	local w = T.newWorld()
	local a = w:addClient(T.ANITA, { spot = "Undercity", class = "WARLOCK" })
	T.settle(w)
	a.W.db.drive.imported = { at = H.EPOCH, from = "1.4.1", rrStats = { rides = 1, copper = 100 } }
	a.env.RitualRidesDB = { stats = { rides = 2, copper = 250 } }
	eq(a.W.Drive.MergeRetired(), true, "MergeRetired reports true on merge")
	eq(a.W.db.drive.stats.rides, 1, "new ride delta merged")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:1298 (and to or)
test("mutation core: RestoreQueue does not recreate came-with rows for ignored friends", function()
	local DAN = "Dan Miller"
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = true })
	w:addBot(T.BOB, { spot = "Ratchet", acceptsInvites = true })
	T.settle(w)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(2)
	w:group({ T.ANITA, DAN, T.BOB })
	w:advance(1)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(5)
	local DR = a.W.Drive
	DR.ignored[key(T.BOB)] = true
	DR.customers[key(T.BOB)] = nil
	ok(DR.customers[key(DAN)] and DR.units[key(DAN)], "Dan is in the group and listed")
	ok(DR.units[key(T.BOB)], "Bob is in the group")
	a.W.Char().queue = {
		at = a.env.time(),
		list = { { key = key(DAN), name = DAN, state = "joined" } },
		with = { { key = key(T.BOB), name = T.BOB, cameWith = DAN } },
	}
	DR.RestoreQueue()
	eq(DR.customers[key(T.BOB)], nil, "ignored friend is not recreated as a came-with row")
	T.clean(w)
end)
