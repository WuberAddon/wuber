-- Round 33 group h: HUNT-118, the grey line on a busy driver's booking card is never cut.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local LINE = "Crossroads · Bring 2 friends · Busy · about 2 min"

local function find(f, text)
	for _, rg in ipairs({ f:GetRegions() }) do
		if rg.GetText and rg:GetText() == text then return rg end
	end
	for _, ch in ipairs({ f:GetChildren() }) do
		local got = find(ch, text)
		if got then return got end
	end
end

local function card(state, team)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Crossroads", price = 5000, state = state,
		team = team, service = "Mia's Rides", heard = r.env.GetTime() }
	W.UI.Show("confirm", "mia runner")
	w:advance(2)
	return w, r, W
end

test("r33 h: HUNT-118: a busy driver's long grey line wraps to a second line, whole, and the card grows", function()
	local w, r = card("busy", 1)
	local fs = find(r.env.UIParent, LINE)
	ok(fs, "the grey line is there, in full")
	ok(fs.wuberWrapped, "it wraps instead of being cut")
	local row = fs:GetParent()
	eq(row:GetHeight(), 83, "the driver card is a line taller")
	T.clean(w)
end)

test("r33 h: HUNT-118: control, a short grey line stays on one line at the old height", function()
	local w, r = card("open", 3)
	local fs = find(r.env.UIParent, "Crossroads · Crew ready · Open")
	ok(fs, "the short line is there")
	ok(not fs.wuberWrapped, "one line")
	eq(fs:GetParent():GetHeight(), 70, "the old height")
	T.clean(w)
end)
