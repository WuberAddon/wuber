-- Decisions round, group E: the fair split survives a /reload, What's new counts a driver's rides, the self-test's hidden
-- secure button is made once at login. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

test("dec e: a /reload in the middle of a shift keeps the shift's casts and gold for the fair split", function()
	local w = H.NewWorld({})
	local d = w:addClient(T.ANITA, { spot = "Ratchet", class = "WARLOCK" })
	w:addBot("Dan Rider", { spot = "Orgrimmar" })
	w:group({ T.ANITA, "Dan Rider" })
	w:advance(1)
	ok(d.W.Drive.SetOpen(true), "setup: open")
	w:advance(3)
	d.W.Drive.Do("CAST", "Dan Rider")
	w:advance(1)
	d.W.Drive.Do("END", "Dan Rider", 1)
	w:advance(1)
	d.W.Fire("DRIVE_PAID", "Dan Rider", 5000, 0, key(T.ANITA), true, "t", 5000)
	local rows, _, info = d.W.Drive.Cut()
	eq(rows[1] and rows[1].casts, 1, "control: one cast counted before the reload")
	eq(info.gold, 5000, "control: 50s counted before the reload")
	local started = d.W.db.drive.log.shift.start
	local d2 = w:reload(d)
	w:advance(5)
	ok(d2.W.Drive.IsOpen(), "control: still open after the reload")
	eq(d2.W.db.drive.log.shift.start, started, "control: the same shift goes on")
	local rows2, _, info2 = d2.W.Drive.Cut()
	ok(info2.gold == 5000 and rows2[1] and rows2[1].casts == 1,
		"after the /reload the fair split shows " .. tostring(info2.gold) .. " copper and "
		.. tostring(rows2[1] and rows2[1].casts or 0) .. " casts (before: 5000 copper, 1 cast)")
	-- a new shift starts from nothing
	d2.W.Drive.SetOpen(false)
	w:advance(3)
	d2.W.Drive.SetOpen(true)
	w:advance(3)
	local _, _, info3 = d2.W.Drive.Cut()
	ok(info3.gold == 0 or info3.since ~= started, "a new shift does not inherit the old tallies (gold " .. tostring(info3.gold) .. ")")
	T.clean(w)
end)

test("dec e: a driver with rides in the earnings log (guide never finished) gets the What's new card after updating", function()
	local w = T.newWorld()
	local saved = { Wuber = { drive = { v = 1, log = { v = 1, rides = { "900,5000,Dan Rider,Ratchet,t,5000" } } } } }
	local d = T.driver(w, T.ANITA, { saved = saved })
	local Mod = d.W.Mod("UI.WhatsNew")
	w:advance(30)
	eq(#d.W.db.drive.log.rides, 1, "control: the earnings log still holds the ride")
	local card = Mod.Card()
	ok(Mod.Pending() == "2.4.0" or (card and H.visible(card)),
		"a driver who earned gold with an older Wuber is treated as a fresh install (pending "
		.. tostring(Mod.Pending()) .. ", newsSeen saved as " .. tostring(d.W.db.newsSeen) .. ")")
	T.clean(w)
end)

test("dec e: Check my game makes no secure button after login (the one hidden button is made at login and reused)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local secure = 0
	local real = r.env.CreateFrame
	r.env.CreateFrame = function(kind, name, parent, tmpl, ...)
		if tmpl == "SecureActionButtonTemplate" then secure = secure + 1 end
		return real(kind, name, parent, tmpl, ...)
	end
	r.W.SelfTest() r.W.SelfTest()
	ok(secure == 0, "Check my game made " .. secure .. " secure buttons after login")
	T.clean(w)
end)
