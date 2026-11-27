-- r52 R (bug hunt F012, promise v241.flightmap.moved_window_within_a_moment): cause is not in UI/FlightPins.lua.
-- The What's new card follows a moved Wuber window on its own 1 s timer (UI/WhatsNew.lua:348), so the card lands
-- over a price tag up to 1 s after the window moved; FlightPins then steps the tag aside at its next 0.25 s look
-- (FlightPins.lua:525-530). The tag clears at most 0.25 s after the card has moved: that is the guard below.
local T = ...
local test, ok, H = T.test, T.ok, T.H

-- guard: FlightPins already steps a tag aside within one look (0.25 s) of a Wuber frame (the news card) landing on it
test("r52 r: a price tag steps aside within 0.5 s of a Wuber frame moving over it (guard for F012)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["anita lift"] = { name = "Anita Lift", key = "anita lift", dest = "Orgrimmar", price = 5000, state = "open", team = 3, heard = r.env.GetTime() }
	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(1.2)
	local pin = Mod.Pins()[1]
	ok(pin and pin.tag and H.visible(pin.tag), "control: a price tag shows")
	local tr = H.rect(pin.tag)
	local env = r.env
	local card = env.WuberNewsCard or env.CreateFrame("Frame", "WuberNewsCard", env.UIParent)
	card:SetSize(300, 150)
	card:ClearAllPoints()
	card:SetPoint("LEFT", env.UIParent, "BOTTOMLEFT", tr.l + 2, tr.b + tr.h / 2)
	card:Show()
	w:advance(0.5)
	pin = Mod.Pins()[1]
	local under = false
	if pin and pin.tag and H.visible(pin.tag) then
		local t, c = H.rect(pin.tag), H.rect(card)
		under = t.l + 0.5 < c.l + c.w and c.l + 0.5 < t.l + t.w and t.b + 0.5 < c.b + c.h and c.b + 0.5 < t.b + t.h
	end
	ok(not under, "the tag is not under the card half a second after the card lands on it")
	T.clean(w)
end)

-- The promise itself (the window moves, the card follows 1 s later, the tag is clear within 0.5 s) is longer than
-- the card's own follow timer; making them agree needs UI/WhatsNew.lua (group B's file) to re-place the card sooner.
if T.pending then
	T.pending("r52 r: R52-01 a price tag under the news card clears within 0.5 s of the Wuber window moving",
		"BUGS-NEXT R52-01: the news card follows a moved Wuber window after up to 1 s (WhatsNew.lua:348), so a price tag shows under the card for up to 1.25 s")
end
