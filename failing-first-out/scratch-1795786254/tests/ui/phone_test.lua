-- Tests of UI.Phone (round 13, A). Loaded by tests/run.lua with its helper table T.
--   I19: the Dynamic Island sits in the middle of the status bar, folded (360) and unfolded (720);
--   the clock stays in the left ear and signal and battery in the right.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function fold(c, W, wide)
	c.wide = wide and true or false
	W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
	W.UI.Fold.Apply()
end

test("ui.phone r13 I19: the island is in the middle of the status bar, folded and unfolded", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	local W = c.W
	local UI = W.UI
	W.db.coach = true
	UI.Toggle(true)
	w:advance(3)
	UI.OpenSettings() -- a page that unfolds
	w:advance(1)
	local ph = UI.state.phone
	local win = UI.state.win
	ok(ph and ph.island and ph.status, "the handset, its island and status bar")
	for _, wide in ipairs({ false, true, false }) do
		fold(c, W, wide)
		w:advance(1)
		local what = wide and "unfolded" or "folded"
		eq(win:GetWidth(), wide and 720 or 360, what .. ": the window's width")
		local bar, isl, clock = H.rect(ph.status), H.rect(ph.island), H.rect(ph.clock)
		local mid = bar.l + bar.w / 2
		ok(math.abs((isl.l + isl.w / 2) - mid) < 0.5, what .. ": the island is centred (" .. (isl.l + isl.w / 2) .. " vs " .. mid .. ")")
		local wr = H.rect(win)
		ok(math.abs((isl.l + isl.w / 2) - (wr.l + wr.w / 2)) < 0.5, what .. ": in the middle of the window too")
		ok(clock.l + clock.w <= isl.l, what .. ": the clock left of the island")
		local sig = H.rect(ph.signal)
		ok(sig.l >= isl.l + isl.w, what .. ": signal right of the island")
	end
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("ui.window 2.3.2 C1: the first-show text refresh survives (OnShow is not replaced)", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local W = c.W
	local n = 0
	local real = W.Theme.RefreshText
	W.Theme.RefreshText = function(...) n = n + 1 return real(...) end
	local win = W.UI.state.win
	win:Hide()
	win:Show()
	w:advance(1)
	W.Theme.RefreshText = real
	ok(n >= 1, "RefreshText ran on show (" .. n .. ")")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)
