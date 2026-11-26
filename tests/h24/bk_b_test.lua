-- Group B break-it guards: the tab bar's foot (UI.TabBottom, UI.OnBarSync) and who follows it (tip card, coach mark).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function near(a, b) return math.abs(a - b) <= 0.6 end
-- a screen distance of n window units (the window may be scaled)
local function wu(win, n) return n * H.rect(win).w / win:GetWidth() end

local function open(coachDone)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768 })
	if coachDone then r.W.db.coach = true end
	w:advance(15)
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state, r.W.UI
end

local function ride(r, w, state)
	r.W.ride = { id = "h24bk", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = state,
		at = r.env.GetTime(), service = "Bea's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.RefreshNow()
	w:advance(2)
end

-- guard: break-it, Window.lua:411 UI.NotifyBarSync call dropped; :405/:408 barHidden set after the notify (TabBottom stale);
-- :437 W.Safe around each listener dropped (one bad listener stops the rest); :404 "changed" test dropped (notify on every open)
-- guard: break-it (the break this test catches is named in the guard comment above)
test("h24 bk-b1: a ride hiding and restoring the tab bar tells every listener once, with the new foot, one bad listener harming none", function()
	local w, r, ui, UI = open(true)
	local seen = {}
	UI.OnBarSync(function(h) seen[#seen + 1] = { h, UI.TabBottom(), UI.TabsHidden() } end)
	UI.OnBarSync(function() error("h24 bk-b1 listener fails on purpose") end)
	local after = {}
	UI.OnBarSync(function(h) after[#after + 1] = h end)
	eq(UI.TabBottom(), UI.TABBAR_H, "the tab bar is in place: the foot is its height")
	ride(r, w, "accepted")
	eq(ui.screen, "found", "the ride's page is up")
	ok(UI.TabsHidden(), "the tab bar is away")
	eq(#seen, 1, "one notice when the bar went away")
	eq(seen[1][1], true, "told: hidden")
	eq(seen[1][2], 0, "at the notice the foot is already 0")
	eq(#after, 1, "the listener after the failing one was still told")
	ok(tostring(r.W.lastError):find("bar sync", 1, true), "the failure was reported, not thrown")
	r.W.lastError = nil -- the failure above is the point of this test
	-- the window shut and opened again changes nothing about the bar: no notice
	UI.Toggle(false)
	w:advance(1)
	UI.Toggle(true)
	w:advance(2)
	eq(#seen, 1, "no new notice when the window is shut and opened with the bar unchanged")
	r.W.ride = nil
	r.W.Fire("RIDE")
	UI.RefreshNow()
	w:advance(2)
	ok(not UI.TabsHidden(), "the ride is over: the bar is back")
	eq(#seen, 2, "a second notice when the bar came back")
	eq(seen[2][1], false, "told: back")
	eq(seen[2][2], UI.TABBAR_H, "at the notice the foot is the bar's height again")
	r.W.lastError = nil
	T.clean(w)
end)

-- guard: break-it, Window.lua:431 TabBottom always the bar's height / always 0; Tips.lua:235 the anchor not from TabBottom;
-- Tips.lua:297 the OnBarSync listener dropped
-- guard: break-it (the break this test catches is named in the guard comment above)
test("h24 bk-b2: the tip card follows the tab bar's foot when the bar goes and comes back", function()
	local w, r, ui, UI = open(true)
	local Tips = r.W.Mod("UI.Tips")
	ok(Tips.ShowNow(), "the tip card shows")
	w:advance(1)
	local card = Tips.Card()
	local win = ui.win
	local function gap() return H.rect(card).b - H.rect(win).b end
	ok(near(gap(), wu(win, UI.TABBAR_H)), "the card rests on the bar: gap " .. gap())
	ui.barHidden = true
	UI.NotifyBarSync(true)
	ok(near(gap(), 0), "bar away: the card rests on the phone's foot: gap " .. gap())
	ui.barHidden = false
	UI.NotifyBarSync(false)
	ok(near(gap(), wu(win, UI.TABBAR_H)), "bar back: the card is back on the bar: gap " .. gap())
	T.clean(w)
end)

-- guard: break-it, Coach.lua:195 the bubble anchored at the bar's height not TabBottom; Coach.lua:153-158 the OnBarSync hook dropped
-- or its coaching test dropped, or it restarting at tip 1 instead of the tip it was on
-- guard: break-it (the break this test catches is named in the guard comment above)
test("h24 bk-b3: the coach mark follows the tab bar's foot, stays on its tip, and stays quiet when no guide runs", function()
	local w, r, ui, UI = open(false)
	ok(ui.coaching and ui.coach and ui.coach:IsShown(), "the guide is up")
	local b, win = ui.coach, ui.win
	local function gap() return H.rect(b).b - H.rect(win).b end
	ok(near(gap(), wu(win, UI.TABBAR_H + 8)), "tip 1 rests 8 above the bar: gap " .. gap())
	ui.barHidden = true
	UI.NotifyBarSync(true)
	ok(near(gap(), wu(win, 8)), "bar away: the mark rests 8 above the phone's foot: gap " .. gap())
	ui.barHidden = false
	UI.NotifyBarSync(false)
	ok(near(gap(), wu(win, UI.TABBAR_H + 8)), "bar back: the mark is back above the bar: gap " .. gap())
	-- it stays on its own tip
	UI.CoachStep(2)
	eq(ui.coachStep, 2, "on tip 2")
	UI.NotifyBarSync(false)
	eq(ui.coachStep, 2, "a bar notice leaves the guide on tip 2")
	-- and a mark that is only fading out (no guide running) is not moved or revived
	UI.CoachStep(1)
	local before = gap()
	ui.coaching = false
	ui.barHidden = true
	UI.NotifyBarSync(true)
	ok(near(gap(), before), "no guide running: a bar notice does not move the mark")
	ui.barHidden = false
	ui.coaching = true
	T.clean(w)
end)

-- guard: break-it, Window.lua:284-290 HeadPush's scan of pushed pages inverted (the cog stays when a pushed page shows)
test("h24 bk-b4: a visible pushed page makes the cog step aside, and it returns when the page goes", function()
	local w, r, ui, UI = open(true)
	local vis = true
	local page = { IsVisible = function() return vis end }
	UI.HeadPush(page)
	ok(not ui.gear:IsShown(), "a pushed page shows: the cog steps aside")
	vis = false
	UI.HeadPush()
	ok(ui.gear:IsShown(), "the page is gone: the cog is back")
	T.clean(w)
end)
