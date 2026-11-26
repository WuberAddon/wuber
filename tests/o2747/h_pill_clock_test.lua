-- Group H, #20: after a fold the live pill never overlaps the clock, at any moment (not only after the 1 s refresh).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	local W = c.W
	W.db.coach = true
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.OpenSettings() -- a page that unfolds
	w:advance(3)
	W.ride = { id = "r1", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = "requesting", at = c.env.GetTime() }
	W.UI.Refresh(true)
	w:advance(3)
	return w, c, W
end

local function setWide(c, W, wide, instant)
	c.wide = wide and true or false
	W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
	W.UI.Fold.Apply(instant)
end

local function gap(ph)
	local isl, clock = H.rect(ph.island), H.rect(ph.clock)
	return isl.l - (clock.l + clock.w), isl.w
end

-- the promise: while a ride shows the pill (ride requested, Settings page), its left edge is never left of the clock's right edge,
-- at every moment after a fold or unfold: right after it (0 s), then every step until 6 s. The pill is an event (the fold) plus a timer (the 1 s refresh).
local function sweepTest(step)
	test("o2747 h #20: ride requested, fold and unfold, the pill never overlaps the clock, stepping " .. step .. " s", function()
		local w, c, W = setup()
		local ph = W.UI.state.phone
		ok(ph.island.grown, "the pill is up for a requested ride")
		for _, wide in ipairs({ true, false, true, false }) do
			setWide(c, W, wide)
			local what = (wide and "unfolded" or "folded")
			local g, iw = gap(ph)
			ok(g >= 0, what .. " +0 s: the pill clears the clock (gap " .. g .. ", pill " .. iw .. " wide)")
			local elapsed = 0
			while elapsed < 6 do
				w:advance(step)
				elapsed = elapsed + step
				g, iw = gap(ph)
				ok(g >= 0, what .. " +" .. elapsed .. " s: the pill clears the clock (gap " .. g .. ", pill " .. iw .. " wide)")
			end
		end
		eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
		T.clean(w)
	end)
end
sweepTest(0.05)
-- guard: the harness runs the refresh inside one advance(), so steps of 1 s and more cannot see the window; kept for the two-step-size rule
sweepTest(1)
-- guard: the harness runs the refresh inside one advance(), so steps of 1 s and more cannot see the window; kept for the two-step-size rule
sweepTest(5)

-- a width tween already running at the fold must not write its old target over the fitted width
-- guard: the harness's fold tween outlasts the pill tween (and the pill is already refitted by then), so the stale target is not reachable here; kept for the retarget in fitPill
test("o2747 h #20: a pill tween running at the fold cannot widen the pill back over the clock (0.05 s steps)", function()
	local w, c, W = setup()
	local ph = W.UI.state.phone
	local ride = W.ride
	W.ride = nil
	setWide(c, W, true)
	w:advance(5)
	W.UI.Refresh(true)
	w:advance(3)
	W.ride = ride -- a ride starts: the pill grows from 92 towards 230 while the bar is wide
	W.UI.Refresh(true)
	W.UI.UpdateStatusBar() -- the tween starts now
	setWide(c, W, false, true) -- an instant fold in the same tick (the way the splash and a fold without room apply it)
	local g, iw = gap(ph)
	ok(g >= 0, "+0 s: clear (gap " .. g .. ", pill " .. iw .. ")")
	for i = 1, 120 do
		w:advance(0.05)
		g, iw = gap(ph)
		ok(g >= 0, "+" .. i * 0.05 .. " s: clear (gap " .. g .. ", pill " .. iw .. ")")
	end
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- the step ("1 of 3") is dropped as soon as the fitted pill cannot hold both parts, as updatePill does; the two texts never overlap
test("o2747 h #20: a ride with a step: after a fold the state and the step never overlap each other or the clock (0.05 s steps)", function()
	local w, c, W = setup()
	local ph = W.UI.state.phone
	W.ride.state = "arrived" -- Arrived + the price in letters: the long step
	W.ride.price = 12345678
	W.UI.Refresh(true)
	w:advance(3)
	setWide(c, W, true)
	w:advance(5)
	ok((ph.island.step:GetText() or "") ~= "", "unfolded: the step shows (" .. tostring(ph.island.step:GetText()) .. ")")
	setWide(c, W, false)
	for i = 0, 120 do
		if i > 0 then w:advance(0.05) end
		local g, iw = gap(ph)
		ok(g >= 0, "+" .. i * 0.05 .. " s: clear of the clock (gap " .. g .. ", pill " .. iw .. ")")
		local st = ph.island.step:GetText() or ""
		-- the step is there only when the pill is wide enough for both parts (the folded room, 188.6, is not)
		ok(st == "" or iw > 189, "+" .. i * 0.05 .. " s: no step in a pill cut to the folded room (step '" .. st .. "', pill " .. iw .. ")")
		if st ~= "" then
			local s1, s2 = H.rect(ph.island.state), H.rect(ph.island.step)
			ok(s1.l + s1.w <= s2.l, "+" .. i * 0.05 .. " s: the step text clear of the state text (" .. (s1.l + s1.w) .. " vs " .. s2.l .. ")")
		end
	end
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- guard: the settled folded pill (the 1 s refresh's own place) is what it was before the fix, so the fix changes nothing once the refresh has run
test("o2747 h #20: guard: settled folded pill width and place are what the 1 s refresh gives", function()
	local w, c, W = setup()
	local ph = W.UI.state.phone
	setWide(c, W, false)
	w:advance(5)
	local g1, w1 = gap(ph)
	eq(w1, 188.6, "the folded pill width the refresh fits")
	W.UI.UpdateStatusBar()
	w:advance(5)
	local g2, w2 = gap(ph)
	eq(w2, w1, "same width after another refresh")
	eq(g2, g1, "same gap after another refresh")
	T.clean(w)
end)
