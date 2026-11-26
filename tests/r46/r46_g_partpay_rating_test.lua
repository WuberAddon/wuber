-- Round 46 g: the part-paid pay card's small line says what is left; the star tooltip says the driver is told.
local T = ...
local test, ok, eq = T.test, T.ok, T.eq
local MIA = "Mia Runner"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function ride(state, extra)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local rd = { id = "r46", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = state,
		at = r.env.GetTime(), payee = "Bea Jones", payto = "Bea", summoner = "Bea Jones", service = "Mia's Rides" }
	for k, v in pairs(extra or {}) do rd[k] = v end
	r.W.ride = rd
	r.W.db.tipPct = 10
	r.W.Fire("RIDE")
	return w, r
end
local function joined(r, pat)
	local t = {}
	for _, fs in ipairs(r:findText(pat, true)) do t[#t + 1] = fs:GetText() end
	return table.concat(t, " | ")
end

test("r46 g: part paid, the small line says what is left of the fare and the tip", function()
	local w, r = ride("arrived", { paidSoFar = 2500 })
	r.W.UI.Toggle(true) w:advance(3)
	local s = joined(r, "left of")
	ok(s:find("25.-s left of 50.-s %+ 5.-s tip") ~= nil, "small line: " .. s .. " / " .. joined(r, "fare"))
	ok(#r:findText("50s fare", false, true) == 0, "no 'fare + tip' sum that disagrees with the big figure")
	T.clean(w)
end)

test("r46 g: nothing paid yet, the small line stays 'fare + tip'", function()
	local w, r = ride("arrived", {})
	r.W.UI.Toggle(true) w:advance(3)
	ok(#r:findText("fare %+ ", false, false) > 0, "fare + tip line: " .. joined(r, "fare"))
	ok(#r:findText("left of", false, true) == 0, "no 'left of' line")
	T.clean(w)
end)

test("r46 g: part paid with no tip drops the tip part", function()
	local w, r = ride("arrived", { paidSoFar = 2500 })
	r.W.db.tipPct = 0
	r.W.Fire("RIDE") r.W.UI.Toggle(true) w:advance(3)
	local s = joined(r, "left of")
	ok(s:find("left of 50") ~= nil and s:find("tip") == nil, "line: " .. s)
	T.clean(w)
end)

test("r46 g: the star tooltip says the driver is told the stars", function()
	local w, r = ride("done", { paid = 6000 })
	r.W.UI.Toggle(true) w:advance(2)
	r.W.UI.Show("done") w:advance(3)
	local st = r.W.UI.state.screens.done.stars[2]
	eq(st.wuberTip.text, "Rate your ride. Your driver is told the stars. You see your ratings in Trips.")
	T.clean(w)
end)
