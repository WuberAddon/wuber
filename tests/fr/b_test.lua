-- Fix round group b: Add by name refuses what cannot be a character name; a "No player named" answer drops the waiting offer.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("fr b: names that cannot be a character's name are refused, nothing is sent", function()
	local w = T.newWorld()
	local d = T.driver(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = d.W.Drive
	local bad = {}
	for _, name in ipairs({ "Anita Lift ...", "---", "...", "a.b", "Bob!!", "12345", "x" }) do
		if DR.OfferCrew(name) == true then bad[#bad + 1] = name end
		ok(DR.offers[d.W.Key(name) or "?"] == nil, "no row for " .. name)
	end
	ok(#bad == 0, "accepted: " .. table.concat(bad, " | "))
	T.clean(w)
end)

test("fr b: real names are still offered (plain, accented, with realm)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = d.W.Drive
	for _, name in ipairs({ "Anita", "Zoë", "Bob-Firemaw", "Anita Lift" }) do
		ok(DR.ValidName(name), name .. " is a name")
	end
	for _, name in ipairs({ "Abcdefghijklm", "Bob-", "a.b", "x" }) do
		ok(not DR.ValidName(name), name .. " is not a name")
	end
	T.clean(w)
end)

test("fr b: the game saying nobody of that name plays drops the waiting offer", function()
	local w = T.newWorld()
	local d = T.driver(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = d.W.Drive
	DR.OfferCrew("Nobodyhere")
	local k = d.W.Key("Nobodyhere")
	ok(DR.offers[k] and DR.offers[k].state == "waiting", "control: offer waits")
	d:chatEvent("CHAT_MSG_SYSTEM", "No player named 'Nobodyhere' is currently playing.")
	ok(DR.offers[k] == nil, "offer dropped")
	T.clean(w)
end)
