-- #83: a /reload while another Warlock's summon is waiting for the rider must not make the big button cast a
-- second summon on them. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"
local SPOT = "Undercity"
local TITLE = "Dan has a summon waiting"

local function casts(b) return tostring(b:GetAttribute("macrotext") or ""):find("/cast", 1, true) ~= nil end

-- a driver with Dan's summon (from Wes) seen waiting, then a /reload after `gap` seconds; returns the world, the new client, the old saved table
local function reloaded(gap, opts)
	opts = opts or {}
	local w = T.newWorld({ incomingSummon = true })
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	w:addBot("Bob Helper", { spot = SPOT })
	w:addBot("Wes Other", { spot = "Thunder Bluff", class = "WARLOCK", shards = 5 })
	w:group({ ANITA, "Bob Helper", "Wes Other" })
	w:advance(1)
	lock.W.Drive.SetOpen(true)
	w:advance(2)
	w:addBot("Dan Moss", { spot = "Orgrimmar", acceptsSummon = false })
	w:botWhisper("Dan Moss", lock, "summon pls")
	w:advance(3)
	if not opts.late then w:summon(w:player("Wes Other"), "Dan Moss") end
	w:advance(2)
	if opts.wipe then lock.W.db.drive.summonWait = nil end
	if opts.old then for _, r in pairs(lock.W.db.drive.summonWait) do r.at = r.at - 250 end end
	if gap then
		-- the driver is away from the window for a while: the saved record's last look gets old
		for _, r in pairs(lock.W.db.drive.summonWait or {}) do r.look = r.look - gap end
	end
	local lock2 = w:reload(lock)
	w:advance(3)
	return w, lock2
end

test("v24 83 summon guard survives a reload: a record whose last look is over 30 s old is not believed", function()
	local w, lock2 = reloaded(40)
	eq(lock2.W.Drive.Plan().title, "Summon Dan", "the old look is no proof: as before")
	T.clean(w)
end)

test("v24 83 summon guard survives a reload: a waiting answer with no record is not believed (the first-look rule)", function()
	local w, lock2 = reloaded(nil, { wipe = true })
	eq(lock2.W.Drive.Plan().title, "Summon Dan", "no record: not seen to appear, so as before")
	T.clean(w)
end)

test("v24 83 summon guard survives a reload: a summon record over 200 s old is not believed", function()
	local w, lock2 = reloaded(nil, { old = true })
	eq(lock2.W.Drive.Plan().title, "Summon Dan", "a box lasts 2 to 3 minutes: not believed")
	T.clean(w)
end)

test("v24 83 summon guard survives a reload: stale records are purged, and no table is made until one is written", function()
	local w = T.newWorld({ incomingSummon = true })
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	w:addBot("Bob Helper", { spot = SPOT })
	w:addBot("Wes Other", { spot = "Thunder Bluff", class = "WARLOCK", shards = 5 })
	w:group({ ANITA, "Bob Helper", "Wes Other" })
	w:advance(1)
	lock.W.Drive.SetOpen(true)
	w:advance(2)
	w:addBot("Dan Moss", { spot = "Orgrimmar", acceptsSummon = false })
	w:botWhisper("Dan Moss", lock, "summon pls")
	w:advance(3)
	eq(lock.W.db.drive.summonWait, nil, "nothing waiting yet: no summonWait table")
	lock.W.db.drive.summonWait = { ["old rider"] = { at = 1, look = 1 } }
	w:summon(w:player("Wes Other"), "Dan Moss")
	w:advance(2)
	local sw = lock.W.db.drive.summonWait
	ok(sw and sw["dan moss"], "Dan's waiting summon is written")
	eq(sw["old rider"], nil, "the stale record was dropped")
	T.clean(w)
end)

test("v24 83 summon guard survives a reload: saved data without summonWait loads fine", function()
	local w, lock2 = reloaded(nil, { late = true })
	eq(lock2.W.db.drive.summonWait, nil, "no table")
	eq(lock2.W.Drive.Plan().title, "Summon Dan", "the button works as before")
	T.clean(w)
end)

test("v24 83 summon guard survives a reload: the waiting summon seen before the /reload still holds the cast", function()
	local w = T.newWorld({ incomingSummon = true })
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	w:addBot("Bob Helper", { spot = SPOT })
	w:addBot("Wes Other", { spot = "Thunder Bluff", class = "WARLOCK", shards = 5 })
	w:group({ ANITA, "Bob Helper", "Wes Other" })
	w:advance(1)
	lock.W.Drive.SetOpen(true)
	w:advance(2)
	w:addBot("Dan Moss", { spot = "Orgrimmar", acceptsSummon = false })
	w:botWhisper("Dan Moss", lock, "summon pls")
	w:advance(3)
	eq(lock.W.Drive.Plan().title, "Summon Dan", "control: the button offers Dan's summon")
	w:summon(w:player("Wes Other"), "Dan Moss")
	w:advance(2)
	eq(lock.W.Drive.Plan().title, TITLE, "control: before the reload the button holds the cast")
	local lock2 = w:reload(lock)
	w:advance(3)
	local DR = lock2.W.Drive
	local b = lock2.env.WuberDriveButton
	eq(DR.Plan().title, TITLE, "after the reload the button still says Dan has a summon waiting")
	ok(not casts(b), "and the secure button holds no /cast: " .. tostring(b and b:GetAttribute("macrotext")))
	lock2:click(b)
	w:advance(3)
	eq(w.casts, 0, "the click cast nothing")
	T.clean(w)
end)
