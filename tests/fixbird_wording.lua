-- FIX-BIRD: the bird card keeps its full "Skip the bird" wording and the card grows to fit the longest case.
local T = ...
local test, ok = T.test, T.ok

test("fixbird: message starts Skip the bird, names the driver and place; longest case grows the card", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	local Mod = W.Mod("UI.Bird")
	local d = { short = "Wolfgangbert", dest = "Thunder Bluff", price = 1234567 }
	local s = Mod.Message(d, { cost = 4700, secs = 420, about = true })
	ok(s:find("^Skip the bird: Wolfgangbert summons to Thunder Bluff for "), s)
	ok(s:find("really about ", 1, true) and s:find("and about 7 min back.", 1, true), s)
	local s2 = Mod.Message(d, { cost = 99999999, secs = 420, about = false })
	ok(s2:find("The summon saves ", 1, true) and s2:find(" of gold, and 7 min back.", 1, true), s2)
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Wolfgangbert Runner", key = "mia runner", dest = "Thunder Bluff", price = 1234567, state = "open", team = 3, service = "W", heard = r.env.GetTime() }
	W.FlightCost = function() return 4700, 1 end
	W.FlightTime = function() return 420, "est" end
	w:openTaxiMap(r, { { name = "Orgrimmar, Durotar", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 } })
	w:advance(0.5)
	local c = Mod.Card()
	ok(c and c.text:GetText():find("^Summon .* Fly ") ~= nil, "card text")
	ok(c.sub:GetText():find("Wolfgangbert", 1, true) and c.sub:GetText():find("Thunder Bluff", 1, true), "the second line names the driver and place")
	ok(c.tipBody:find("Skip the bird: Wolfgangbert summons to Thunder Bluff for ", 1, true), "the full wording is the tooltip's second paragraph")
	local _, h = c:GetSize()
	ok(h >= 74, "card at least its base height: " .. tostring(h))
	-- (word rule) the card's two lines may wrap to four: with the shipped fonts' real metrics the long second line
	-- makes the card taller than its 74 base, and the words are not cut
	local TL = dofile("tools/preview/textlayout.lua")
	local old = T.H.textMetrics
	T.H.textMetrics = TL
	local good, err = pcall(function()
		c.sub:SetText(c.sub:GetText()) -- measured again with real metrics
		local _, h2 = W.Mod("UI.Bird").Layout(c)
		ok(h2 > 74, "the long second line grows the card: " .. tostring(h2))
		ok(not T.H.truncation or not T.H.truncation(c.sub), "the second line is not cut")
	end)
	T.H.textMetrics = old
	if not good then error(err, 0) end
	T.clean(w)
end)
