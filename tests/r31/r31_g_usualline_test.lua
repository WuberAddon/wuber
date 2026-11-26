local T = ...
-- Round 31 group G (HUNT-91): Home with nobody listed and a saved usual place: "Why can't I see
-- anyone?" must not sit on the "Your usual: ..." line, and that line must not be cut off.
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function homeNobody()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = {}
	W.db.fold = { v = 1, pages = {}, narrow = true }
	W.AlreadyAt = function() return nil end
	W.db.rides = {}
	for i = 1, 3 do
		W.db.rides[i] = { dest = "Undercity", driver = "Mia Runner", driverKey = "mia runner", price = 5000, at = r.env.time() - i * 3600, saved = 600 }
	end
	W.db.seenDrivers = {}
	for i = 1, 6 do W.db.seenDrivers[tostring(i)] = { at = r.env.time() - i * 86400 - 3600 } end
	if W.RebuildTotals then W.RebuildTotals() end
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Show("home")
	w:advance(1.5)
	W.UI.Refresh(true)
	w:advance(1)
	return w, r, W, W.UI.state.screens.home
end

test("r31 G HUNT-91: the usual line and 'Why can't I see anyone?' do not overlap, and the line is whole", function()
	local w, r, W, s = homeNobody()
	local note, why = s.usualNote, s.empty.why
	-- (word rule) the usual line no longer shows while nobody is listed: the empty screen's own controls carry the usual place
	ok(not H.visible(note), "no usual line while nobody is listed")
	ok(H.visible(why), "the why link shows")
	ok(H.visible(s.empty.watch), "the bell for the usual place shows")
	local ping = s.empty.ping
	ok(why:GetBottom() >= ping:GetTop(), "the why link sits above the main button")
	T.clean(w)
end)
