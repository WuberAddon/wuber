-- Scenario 14, the after-the-reload half (round4.lua keeps the click half). #231 changed the flow: the retire pill switches
-- the old addon off and says "Type /reload to finish"; the player then types /reload. This simulates that /reload: a fresh
-- load of the saved variables with the old addon disabled.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA, FARRA, HAYLEY = T.ANITA or "Anita Lift", "Farra Way", "Hayley Cab"

-- RitualRidesDB as Ritual Rides 1.4.1 saved it (the same fixture as round4.lua's scenario 14)
local function rrDB()
	return {
		price = 50000, service = "Giga Rides", dest = "", caster = "", team = { ANITA, FARRA, HAYLEY },
		keywords = { "summon", "taxi" }, maxGroup = 10, whisperMode = "macro", adEvery = 20, autoBlock = true,
		templates = { thanks = "Cheers {name}!" },
		blocklist = { ["dan miller"] = { reason = "never paid", at = "17 Nov" } },
		log = { v = 1, rides = { "1700000000,50000,Old Rider,Undercity,t" }, asks = {}, open = { ["2026111719"] = 30 },
			seen = {}, wreq = {}, wdec = {}, rivals = {} },
		stats = { rides = 3, copper = 150000 },
		setupSeen = true,
	}
end

-- guard: was pending since #231, the after-reload half of scenario 14
test("scenario 14 (after the reload): the retire card reloads into Wuber alone: no RR, no lock, the import kept", function()
	local w = T.newWorld()
	local c = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", loadRR = "1.4.1", saved = { RitualRides = rrDB() } })
	c.W.Char().wizard = true
	c.W.db.coach = true
	c.W.Driver.Toggle()
	w:advance(3)
	c:clickText("Switch it off and reload")
	w:advance(1)
	ok(#c:findText("Type /reload to finish") > 0, "the pill asks for /reload")
	eq(w:clientOf(ANITA), c, "nothing reloaded by itself")
	-- the player types /reload
	local n = w:reload(c)
	w:advance(3)
	ok(n ~= c, "reloaded")
	eq(w:clientOf(ANITA), n, "the new window")
	eq(n.RR, nil, "Ritual Rides did not load")
	eq(n.W.Drive.Lock(), nil, "no lock")
	ok(n.W.Drive.Active(), "the engine is active")
	eq(n.W.Char().price, 50000, "the imported price")
	eq(#n.W.Char().crew, 2, "the crew")
	ok(n.W.Drive.BlockEntry("dan miller"), "the blocklist")
	eq(n.W.db.drive.templates.thanks, "Cheers {name}!", "the messages")
	eq(#n.W.db.drive.log.rides, 1, "the log")
	local imported = n.W.db.drive.imported
	n.W.Drive.ImportRR()
	eq(n.W.db.drive.imported, imported, "import twice changes nothing")
	eq(#n.W.db.drive.log.rides, 1, "the log after a second import")
	eq(#w.errors, 0, "no error")
	T.clean(w)
end)
