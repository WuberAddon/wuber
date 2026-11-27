-- r34 group j: toasts find their place from the window that is really on screen
-- (HUNT-63, HUNT-111). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	H.state[d.env.UIParent].w, H.state[d.env.UIParent].h = 1365, 768
	d.physW, d.physH = 1920, 1080
	d.wide = true
	d:fire("DISPLAY_SIZE_CHANGED")
	w:advance(2)
	return w, d, W
end

test("r34 j: with Wuber closed a toast goes to the top centre, not beside the window that is not there", function()
	local w, d, W = setup()
	W.UI.Toggle(true) w:advance(1.5)
	W.UI.Toggle(false) w:advance(1.5)
	local x, top = W.UI.ToastPlace()
	eq(x, 0, "x")
	eq(top, -18, "top")
	T.clean(w)
end)

test("r34 j: a toast that came up with Wuber closed moves clear of the window when it is opened", function()
	local w, d, W = setup()
	if W.UI.IsShown() then W.UI.Toggle(false) end
	w:advance(1.5)
	local toast = W.UI.Toast("Wuber 9.9.9 is out", "info")
	w:advance(0.3)
	local ph = W.UI.state.phone or W.UI.state.win
	W.UI.Toggle(true) w:advance(1.5)
	local t = H.rect(ph)
	ok(toast, "the toast frame")
	local x, top = W.UI.ToastPlace()
	local sw, sh = 1365, 768
	local tb = { l = sw / 2 + x - 160, b = sh + top - 56, w = 320, h = 56 }
	local hit = tb.l < t.l + t.w and tb.l + tb.w > t.l and tb.b < t.b + t.h and tb.b + tb.h > t.b
	ok(not hit, "the toast box overlaps the open phone: toast " .. tb.l .. "," .. tb.b .. " phone " .. t.l .. "," .. t.b .. " " .. t.w .. "x" .. t.h)
	local _, _, _, px = toast:GetPoint(1)
	ok(math.abs((px or 0) - x) < 1, "the toast frame is anchored at the new x: " .. tostring(px) .. " vs " .. tostring(x))
	T.clean(w)
end)
