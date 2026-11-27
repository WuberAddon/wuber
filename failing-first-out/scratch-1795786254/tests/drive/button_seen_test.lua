-- Tests of Drive.Button (BRIEF18, the author 20 Nov 00:28: "that other button thing randomly disappears
-- and comes back; it's invisible now; I can only see it if I wiggle the main menu"). Whenever the
-- big button is wanted it is seen: shown, not faded, on the screen, and never under the window,
-- on every path (login, open / close, Drive <-> Ride, fold, small screens, combat, /reload, the
-- ride's own states). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- why the button cannot be seen now (nil: it can)
local function unseen(d)
	local env = d.env
	local b = env.WuberDriveButton
	if not b then return "no button" end
	if not b:IsVisible() then return "not shown" end
	if b:GetEffectiveAlpha() < 0.05 then return "faded" end
	local r, u = H.rect(b), H.rect(env.UIParent)
	if not r then return "no place" end
	if r.l < -1 or r.b < -1 or r.l + r.w > u.w + 1 or r.b + r.h > u.h + 1 then
		return ("off the screen (%.0f,%.0f %.0fx%.0f on %.0fx%.0f)"):format(r.l, r.b, r.w, r.h, u.w, u.h)
	end
	local win = env.WuberFrame
	local wr = win and win:IsVisible() and H.rect(win)
	if wr and r.l < wr.l + wr.w and r.l + r.w > wr.l and r.b < wr.b + wr.h and r.b + r.h > wr.b then
		local bs, ws = H.STRATA_RANK(b:GetFrameStrata()), H.STRATA_RANK(win:GetFrameStrata())
		if bs < ws or (bs == ws and b:GetFrameLevel() <= win:GetFrameLevel()) then
			return ("under the window (%s under %s)"):format(b:GetFrameStrata(), win:GetFrameStrata())
		end
	end
	return nil
end

local function seen(d, what)
	local why = unseen(d)
	ok(why == nil, what .. ": the big button is seen" .. (why and (" (" .. why .. ")") or ""))
end

-- a Warlock driver, open for riders, the window closed
local function setup(opts)
	opts = opts or {}
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	if opts.screen then
		H.state[d.env.UIParent].w, H.state[d.env.UIParent].h = opts.screen[1], opts.screen[2]
		d.wide = true
		d:fire("DISPLAY_SIZE_CHANGED")
	end
	if opts.scale then W.Drive.SetScale(opts.scale) end
	W.Driver.SetOnline(true)
	w:advance(2)
	return w, d, W, d.env.WuberDriveButton
end

local function noViolations(w)
	eq(#(w.violations or {}), 0, "no secure frame changed in combat: " .. table.concat(w.violations or {}, "; "))
end

test("Drive.Button BRIEF18: login with the window closed, open, Drive <-> Ride, fold, close: always seen", function()
	local w, d, W, b = setup()
	local DR = W.Drive
	seen(d, "login, window closed")
	ok(DR.Button.Floating(), "it floats")
	W.UI.Toggle(true)
	w:advance(0.6)
	seen(d, "window opened (Ride)")
	w:advance(2)
	W.UI.SelectTab("Drive")
	w:advance(0.1)
	ok(DR.Button.Docked(), "docked in the Drive tab")
	seen(d, "Drive tab")
	W.UI.SelectTab("Ride")
	w:advance(0.1)
	ok(DR.Button.Floating(), "floats again on the Ride tab")
	seen(d, "back on the Ride tab")
	d.wide = true
	W.UI.Fold.Toggle()
	w:advance(0.1)
	w:advance(1)
	seen(d, "after a fold toggle")
	W.UI.Fold.Toggle()
	w:advance(1)
	seen(d, "after a second fold toggle")
	W.UI.SelectTab("Drive")
	w:advance(1)
	W.UI.Toggle(false)
	w:advance(1)
	seen(d, "window closed from the Drive tab")
	ok(DR.Button.Floating(), "floats with the window closed")
	T.clean(w)
end)

test("Drive.Button BRIEF18: the window reopened on the Drive tab, then Ride: clear of the window at once", function()
	local w, d, W, b = setup()
	W.UI.Toggle(true)
	w:advance(1)
	W.UI.SelectTab("Drive")
	w:advance(1)
	W.UI.Toggle(false)
	w:advance(2)
	-- open straight onto the Drive tab: docked before the ticker settles the window's box
	W.UI.Toggle(true)
	w:advance(0.1)
	ok(W.Drive.Button.Docked(), "docked")
	w:advance(1)
	W.UI.SelectTab("Ride")
	w:advance(0.05)
	seen(d, "undocked on Ride, the first frame")
	T.clean(w)
end)

test("Drive.Button BRIEF18: no room beside the phone (small screen, big button): above the window, never under it", function()
	local w, d, W, b = setup({ screen = { 1366, 768 }, scale = 1.5 })
	seen(d, "window closed")
	eq(b:GetFrameStrata(), "MEDIUM", "closed: its usual layer")
	W.UI.Toggle(true)
	w:advance(1)
	seen(d, "window open (unfolded)")
	local mini = d.env.WuberDriveMini
	ok(mini and mini:IsShown(), "its console shows")
	eq(mini:GetFrameStrata(), b:GetFrameStrata(), "the console in the button's layer")
	W.UI.Fold.Toggle()
	w:advance(1)
	seen(d, "window open (folded)")
	W.UI.Toggle(false)
	w:advance(1)
	seen(d, "window closed again")
	eq(b:GetFrameStrata(), "MEDIUM", "closed: back to its usual layer")
	eq(mini:GetFrameStrata(), "MEDIUM", "and its console")
	T.clean(w)
end)

test("Drive.Button BRIEF18: hidden, faded or pushed off the screen by something else: back within a second", function()
	local w, d, W, b = setup()
	seen(d, "start")
	b:Hide()
	w:advance(1)
	seen(d, "after something hid it")
	b:SetAlpha(0)
	w:advance(1)
	seen(d, "after something faded it")
	b:ClearAllPoints()
	b:SetPoint("BOTTOMLEFT", d.env.UIParent, "BOTTOMLEFT", 5000, -900)
	w:advance(1)
	seen(d, "after it was pushed off the screen")
	-- the game window got smaller (the saved place is now off it)
	W.UI.Toggle(false)
	H.state[d.env.UIParent].w, H.state[d.env.UIParent].h = 800, 600
	d:fire("DISPLAY_SIZE_CHANGED")
	w:advance(1)
	seen(d, "after the screen shrank")
	-- a button that is not wanted stays hidden (the watch never shows it)
	W.Drive.Button.SetShown(false)
	w:advance(1)
	ok(not b:IsShown(), "switched off: hidden")
	w:advance(3)
	ok(not b:IsShown(), "switched off: still hidden")
	W.Drive.Button.SetShown(true)
	w:advance(1)
	seen(d, "switched on again")
	T.clean(w)
end)

test("Drive.Button BRIEF18: combat freezes it; after the fight it is seen again; nothing secure changes in combat", function()
	local w, d, W, b = setup({ screen = { 1366, 768 }, scale = 1.5 })
	w:enterCombat(d)
	w:advance(0.5)
	W.UI.Toggle(true)
	w:advance(2)
	W.UI.SelectTab("Drive")
	w:advance(2)
	noViolations(w)
	w:leaveCombat(d)
	w:advance(1)
	seen(d, "after the fight, Drive tab")
	W.UI.SelectTab("Ride")
	w:advance(0.5)
	w:enterCombat(d)
	w:advance(0.5)
	W.UI.Toggle(false)
	w:advance(2)
	noViolations(w)
	w:leaveCombat(d)
	w:advance(1)
	seen(d, "after the second fight, window closed")
	noViolations(w)
	T.clean(w)
end)

test("Drive.Button BRIEF18: /reload with the window open, on Drive and on Ride: seen", function()
	local w, d, W = setup()
	W.UI.Toggle(true)
	w:advance(1)
	W.UI.SelectTab("Drive")
	w:advance(1)
	local d2 = w:reload(d)
	w:advance(3)
	seen(d2, "after a /reload on the Drive tab")
	d2.W.UI.Toggle(true)
	w:advance(1)
	seen(d2, "window opened after the /reload")
	d2.W.UI.SelectTab("Ride")
	w:advance(1)
	local d3 = w:reload(d2)
	w:advance(3)
	d3.W.UI.Toggle(true)
	w:advance(1)
	seen(d3, "after a /reload on the Ride tab")
	T.clean(w)
end)

test("Drive.Button BRIEF18: the ride's own states (paused, closed, open again) keep it seen whenever it is wanted", function()
	local w, d, W, b = setup()
	W.UI.Toggle(true)
	w:advance(1)
	W.Driver.SetPaused(true)
	w:advance(1)
	seen(d, "paused, window open")
	W.UI.Toggle(false)
	w:advance(1)
	seen(d, "paused, window closed")
	W.Driver.SetPaused(false)
	w:advance(1)
	seen(d, "resumed")
	W.Driver.SetOnline(false)
	w:advance(1)
	ok(not b:IsShown(), "closed with nobody waiting: not wanted, hidden")
	W.Driver.SetOnline(true)
	w:advance(1)
	seen(d, "open again")
	T.clean(w)
end)

test("Drive.Button BRIEF18: UIParent faded by another addon, or a screen too small for the button and console: no re-place every 2 s", function()
	local w, d, W, b = setup()
	local n, setAlpha, setPoint = 0, b.SetAlpha, b.SetPoint
	b.SetAlpha = function(self, ...) n = n + 1; return setAlpha(self, ...) end
	d.env.UIParent:SetAlpha(0.01)
	w:advance(12)
	eq(n, 0, "UIParent faded: the watch leaves the button alone")
	d.env.UIParent:SetAlpha(1)
	b:SetAlpha(0)
	w:advance(3)
	ok(b:GetAlpha() > 0.9, "the button's own alpha at 0 is still put right")
	b.SetAlpha = nil
	-- a screen too small for the button plus its console: the "off screen" test is not a fault
	H.state[d.env.UIParent].w, H.state[d.env.UIParent].h = 260, 200
	d:fire("DISPLAY_SIZE_CHANGED")
	w:advance(3)
	local p = 0
	b.SetPoint = function(self, ...) p = p + 1; return setPoint(self, ...) end
	w:advance(12)
	b.SetPoint = nil
	ok(p <= 2, "no re-anchoring loop on a screen that cannot fit it (" .. p .. " SetPoint calls in 12 s)")
	T.clean(w)
end)
