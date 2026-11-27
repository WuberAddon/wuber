-- Issue #230: the retire card's pill must not call ReloadUI from addon code (the real client blocks it as
-- tainted). After it switches the old addon off it says "Type /reload to finish" instead.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

local function rrDB()
	return { price = 50000, service = "Giga Rides", team = { ANITA }, keywords = { "summon" }, maxGroup = 10,
		whisperMode = "macro", templates = {}, blocklist = {}, setupSeen = true,
		log = { v = 1, rides = {}, asks = {}, open = {}, seen = {}, wreq = {}, wdec = {}, rivals = {} }, stats = { rides = 0, copper = 0 } }
end

test("retire card: the pill switches the old addon off and asks for /reload, with no ReloadUI call (#230)", function()
	local w = T.newWorld()
	local c = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", loadRR = "1.4.1", saved = { RitualRides = rrDB() } })
	c.W.Char().wizard = true
	c.W.db.coach = true
	c.W.Driver.Toggle()
	w:advance(3)
	ok(#c:findText("Switch it off and reload") > 0, "the pill is there")
	c:clickText("Switch it off and reload")
	w:advance(1)
	eq(c.disabledCalls, 1, "the old addon was switched off")
	eq(c.reloadAsked or 0, 0, "the click did not call ReloadUI")
	eq(#(c.reloadForbidden or {}), 0, "no forbidden ReloadUI from addon code")
	ok(#c:findText("Type /reload to finish") > 0, "the plain line shows: " .. table.concat(c:visibleTexts(), " | "))
	eq(w:clientOf(ANITA), c, "nothing reloaded")
end)
