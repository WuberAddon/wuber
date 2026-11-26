local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function home(n)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768, saved = { Wuber = { coach = false } } })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	for i = 1, n do
		local nm = "Driver" .. string.char(64 + i) .. " Test"
		local k = nm:lower()
		W.drivers[k] = { name = nm, key = k, dest = "Undercity", price = 5000 + i, state = "open", team = 3,
			service = nm .. "'s Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" }
	end
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Show("home")
	w:advance(3)
	W.UI.Refresh(true)
	w:advance(3)
	return w, r, W, W.UI.state.screens.home
end

test("r47 k: a short driver list has no scroll bar at all", function()
	local w, r, W, s = home(1)
	ok(not (s.barFrame and H.visible(s.barFrame)), "no legacy bar with one driver")
	ok(not s.clip.edgeFade:BarShown(), "no edge-fade bar with one driver")
end)

test("r47 k: a long driver list draws ONE scroll bar on its right edge, not two", function()
	local w, r, W, s = home(9)
	local fd = s.clip.edgeFade
	ok(W.UI.state and true, "ui")
	local legacy = s.barFrame and H.visible(s.barFrame)
	local fade = fd:BarShown() and H.visible(fd.thumb)
	local n = (legacy and 1 or 0) + (fade and 1 or 0)
	ok(legacy or fade, "control: the list scrolls so at least one bar shows (" .. T.list(r:visibleTexts()):sub(1, 100) .. ")")
	eq(n, 1, "the player sees " .. n .. " scroll bars on Home's list (legacy Home bar shown=" .. tostring(legacy) .. ", EdgeFade bar shown=" .. tostring(fade) .. "), at x=-5 and x=-3, out of step")
	T.clean(w)
end)