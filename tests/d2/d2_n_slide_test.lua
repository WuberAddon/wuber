-- Design round 2, group N (item 13): pages slide in from the right. The Ride screens, Settings, Help, a Settings
-- section, the driver's pushed pages and the wizard's steps go through A.Push / A.PopPage; a tab change swaps at
-- once; in combat nothing moves and nothing secure is touched; the overlays come when the move ends.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function open(wide, noDriver)
	local w = T.newWorld()
	local d = not noDriver and T.driver(w, T.ANITA, { spot = "Ratchet" }) or nil
	local r = T.rider(w, T.TESTCHAR, wide and { spot = "Orgrimmar", screenW = 1920, screenH = 1080, wide = true } or { spot = "Orgrimmar", screenW = 1024, screenH = 768 })
	r.wide = wide and true or nil
	T.settle(w)
	if d then T.goOnline(d) end
	w:advance(5)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	local UI = r.W.UI
	return w, r, UI.state, UI, d and d.W.myKey
end

-- how far right of the Ride tab's body (or of 'of') a frame is now
local function dx(f, of) return f:GetLeft() - (of or f:GetParent()):GetLeft() end
local function near(a, b, x) return math.abs(a - b) <= (x or 0.6) end

-- counts the calls that move, show or hide a frame from now on
local function watch(f)
	local calls = { SetPoint = 0, ClearAllPoints = 0, Show = 0, Hide = 0, SetAlpha = 0 }
	for name in pairs(calls) do
		local real = f[name]
		f[name] = function(self, ...)
			calls[name] = calls[name] + 1
			return real(self, ...)
		end
	end
	return calls
end

test("d2 n: Home to Confirm pushes Confirm in from a full width right, alone on screen; back, Home returns from 30% left", function()
	local w, r, ui, UI, key = open()
	local home, confirm = ui.screens.home.frame, ui.screens.confirm.frame
	local body = UI.GetTab("Ride")
	eq(ui.screen, "home", "on Home")
	ok(body:DoesClipChildren(), "the Ride tab's body cuts its pages off")
	UI.Show("confirm", key)
	eq(ui.screen, "confirm", "Confirm is the screen")
	ok(confirm:IsShown() and not home:IsShown(), "only the new page is on screen while it travels (TF: one page at a time)")
	ok(near(dx(confirm), 360), "Confirm starts a full width to the right: " .. dx(confirm))
	w:advance(0.1)
	local mid = dx(confirm)
	ok(mid > 20 and mid < 340, "half-way Confirm is between: " .. mid)
	local cover = body.wuberPageCover
	ok(not (cover and cover:IsShown()), "no cover: nothing lies under the page but the flat fill")
	ok(body.wuberPageBacking and body.wuberPageBacking:IsShown(), "the flat fill is behind it")
	-- a refresh in the middle repaints and leaves the travel alone
	UI.RefreshNow()
	ok(near(dx(confirm), mid), "a refresh does not move the travelling page")
	ok(not home:IsShown(), "nor bring back the page that left")
	w:advance(0.5)
	ok(near(dx(confirm), 0), "Confirm ends in its place: " .. dx(confirm))
	ok(confirm:IsShown() and not home:IsShown(), "Home is hidden at the end")
	ok(not body.wuberPageBacking:IsShown(), "the fill is gone")
	eq(confirm:GetAlpha(), 1, "nothing faded")
	-- back: the mirror
	UI.Show("home")
	eq(ui.screen, "home", "Home again")
	ok(home:IsShown() and not confirm:IsShown(), "only Home is on screen on the way back")
	ok(near(dx(home), -108), "Home comes back from 30% left: " .. dx(home))
	w:advance(0.1)
	ok(dx(home) < -2 and dx(home) > -106, "Home is on its way back from the left: " .. dx(home))
	w:advance(0.5)
	ok(home:IsShown() and not confirm:IsShown(), "Confirm is hidden at the end")
	ok(near(dx(home), 0), "Home is in its place")
	home:Hide() confirm:Show()
	ok(near(dx(confirm), 0), "and Confirm's points are back for the next time")
	eq(#w.violations, 0, table.concat(w.violations, "; "))
	T.clean(w)
end)

test("d2 n: the Request overlay is away while Confirm travels and lies over its pill when the move ends", function()
	local w, r, ui, UI, key = open()
	local b = r.env.WuberRequestButton
	UI.Show("confirm", key)
	local pill = ui.screens.confirm.request
	for _ = 1, 2 do
		ok(not b:IsShown(), "no overlay while the page travels")
		UI.RefreshNow()
		ok(not b:IsShown(), "a refresh does not bring it early")
		w:advance(0.1)
	end
	w:advance(0.2)
	ok(b:IsShown(), "the overlay shows once the page is in place")
	ok(near(b:GetLeft() * b:GetEffectiveScale(), pill:GetLeft() * pill:GetEffectiveScale(), 1), "over its pill")
	ok(w.time - 1000 < 60, "sanity")
	T.clean(w)
end)

test("d2 n: a tab change swaps at once: no page moves and nothing fades", function()
	local w, r, ui, UI = open()
	local ride, trips = UI.GetTab("Ride"), UI.GetTab("Trips")
	local c1, c2, c3 = watch(ride), watch(trips), watch(ui.screens.home.frame)
	UI.SelectTab("Trips")
	ok(trips:IsShown() and not ride:IsShown(), "Trips shows, Ride is hidden, at once")
	eq(trips:GetAlpha(), 1, "at full alpha")
	local g = trips.wuberAnims and trips.wuberAnims.fadein
	ok(not (g and g:IsPlaying()), "no fade plays on the tab")
	w:advance(0.1)
	UI.SelectTab("Ride")
	w:advance(1)
	eq(c1.SetPoint + c2.SetPoint + c3.SetPoint, 0, "no page was moved")
	eq(c1.ClearAllPoints + c2.ClearAllPoints + c3.ClearAllPoints, 0, "no page was re-anchored")
	T.clean(w)
end)

test("d2 n: a tab change, hiding the window and UI.HideOtherScreens end a move that is running", function()
	local w, r, ui, UI, key = open()
	local home, confirm = ui.screens.home.frame, ui.screens.confirm.frame
	for _, how in ipairs({ "tab", "hide", "others" }) do
		UI.Show("home") w:advance(1)
		UI.Show("confirm", key)
		w:advance(0.1)
		ok(dx(confirm) > 20, how .. ": on its way")
		if how == "tab" then UI.SelectTab("Trips") elseif how == "hide" then ui.win:Hide() else UI.HideOtherScreens() end
		ok(near(select(4, confirm:GetPoint(1)), 0), how .. ": Confirm is in its place at once")
		ok(not home:IsShown(), how .. ": Home is hidden")
		if how == "tab" then UI.SelectTab("Ride") elseif how == "hide" then UI.Toggle(true) end
		w:advance(3)
	end
	T.clean(w)
end)

test("d2 n: a window that was shut opens on the settled page", function()
	local w, r, ui, UI, key = open()
	local confirm = ui.screens.confirm.frame
	ui.win:Hide()
	w:advance(1)
	UI.Show("confirm", key)
	ok(confirm:IsShown() and near(dx(confirm), 0), "Confirm is in place at once: " .. dx(confirm))
	ok(not ui.screens.home.frame:IsShown(), "Home is hidden")
	T.clean(w)
end)

test("d2 n: Settings from the cog is a push inside a frame that clips, and its chevron a pop", function()
	local w, r, ui, UI = open()
	local st = r.W.Mod("UI.Settings.Rows").st
	r:click(ui.gear)
	local p = st.panel
	ok(ui.settingsOpen and p:IsShown(), "Settings is open")
	local clip = p:GetParent()
	ok(clip ~= ui.win and clip:DoesClipChildren(), "the panel lives in a frame that clips")
	ok(near(clip:GetLeft(), ui.win:GetLeft()) and near(clip:GetWidth(), ui.win:GetWidth()), "the size of the window")
	ok(near(dx(p, ui.win), 360), "it starts a full width to the right: " .. dx(p, ui.win))
	ok(UI.GetTab("Ride"):IsShown(), "the tab under it stays")
	w:advance(0.1)
	ok(dx(p, ui.win) > 20 and dx(p, ui.win) < 340, "on its way")
	local cover = clip.wuberPageCover
	ok(cover and cover:IsShown() and cover:GetAlpha() > 0, "the page under it dims")
	UI.RefreshNow()
	ok(dx(p, ui.win) > 20, "a refresh leaves it travelling")
	w:advance(0.5)
	ok(near(dx(p, ui.win), 0) and p:IsShown(), "in its place")
	ok(near(p:GetWidth(), 360), "as wide as the phone")
	-- the chevron
	r:click(st.back)
	ok(not ui.settingsOpen, "closed")
	ok(p:IsShown() and near(dx(p, ui.win), 0), "it starts in place")
	w:advance(0.1)
	ok(dx(p, ui.win) > 20 and dx(p, ui.win) < 340, "and leaves to the right: " .. dx(p, ui.win))
	w:advance(0.5)
	ok(not p:IsShown(), "hidden at the end")
	ok(UI.GetTab("Ride"):IsShown() and ui.screens.home.frame:IsShown(), "Home is there")
	-- Help the same way
	UI.OpenHelp()
	local hp
	for _, c in ipairs({ clip:GetChildren() }) do
		if c ~= p and c ~= st.under and c ~= cover and c:IsShown() then hp = c end
	end
	ok(hp and near(dx(hp, ui.win), 360), "Help starts a full width to the right")
	w:advance(0.6)
	ok(near(dx(hp, ui.win), 0), "and ends in place")
	UI.CloseHelp()
	w:advance(0.1)
	ok(hp:IsShown() and dx(hp, ui.win) > 20, "its chevron pops it")
	w:advance(0.5)
	ok(not hp:IsShown(), "gone")
	eq(#w.violations, 0, table.concat(w.violations, "; "))
	T.clean(w)
end)

test("d2 n: a Settings section is pushed in place of the Settings home and popped by the chevron; a refresh keeps the move", function()
	local w, r, ui, UI = open()
	local st = r.W.Mod("UI.Settings.Rows").st
	local Panel = r.W.Mod("UI.Settings.Panel")
	UI.OpenSettings()
	w:advance(1)
	local home, sec = st.find.home, st.clip
	ok(home:IsShown() and not sec:IsShown(), "the Settings home")
	local x0 = dx(sec, ui.win)
	Panel.openSection("sound")
	eq(st.view, "section", "the section's view")
	ok(sec:IsShown() and not home:IsShown(), "only the section is on screen while it travels")
	ok(near(dx(sec, ui.win) - x0, 360), "the section starts a full width to the right")
	w:advance(0.1)
	UI.RefreshNow()
	UI.LayoutSettings()
	ok(not home:IsShown() and sec:IsShown(), "a refresh does not bring back the home that left")
	local mid = dx(sec, ui.win) - x0
	ok(mid > 20 and mid < 340, "nor re-anchor the section: " .. mid)
	w:advance(0.5)
	ok(near(dx(sec, ui.win), x0) and sec:IsShown() and not home:IsShown(), "the section is in place, the home hidden")
	r:click(st.back)
	eq(st.view, "home", "back on the home's view")
	ok(home:IsShown() and not sec:IsShown(), "only the home is on screen on the way back")
	ok(dx(home, ui.win) < -100, "the home comes back from 30% left: " .. dx(home, ui.win))
	w:advance(0.1)
	UI.RefreshNow()
	ok(home:IsShown() and not sec:IsShown() and dx(home, ui.win) < -2, "the home is on its way back from the left: " .. dx(home, ui.win))
	w:advance(0.5)
	ok(home:IsShown() and not sec:IsShown(), "the home is back")
	ok(near(dx(home, ui.win), 0), "in its place")
	ok(ui.settingsOpen, "Settings is still open")
	T.clean(w)
end)

test("d2 n: in combat no page point changes and no secure frame is touched", function()
	local w, r, ui, UI, key = open()
	local st = r.W.Mod("UI.Settings.Rows").st
	UI.OpenSettings() w:advance(1) UI.CloseSettings() w:advance(1) -- built
	local home, confirm = ui.screens.home.frame, ui.screens.confirm.frame
	w.violations = {}
	w:enterCombat(r)
	w:advance(1)
	local c1, c2, c3 = watch(home), watch(confirm), watch(st.panel)
	UI.Show("confirm", key)
	ok(confirm:IsShown() and not home:IsShown(), "the pages swap at once")
	w:advance(1)
	UI.Show("home")
	ok(home:IsShown() and not confirm:IsShown(), "and back at once")
	w:advance(1)
	UI.OpenSettings()
	ok(st.panel:IsShown() and near(dx(st.panel, ui.win), 0), "Settings is in place at once")
	w:advance(1)
	UI.CloseSettings()
	ok(not st.panel:IsShown(), "and gone at once")
	w:advance(1)
	eq(c1.SetPoint + c2.SetPoint + c3.SetPoint, 0, "no page point changed")
	eq(c1.ClearAllPoints + c2.ClearAllPoints + c3.ClearAllPoints, 0, "no page was re-anchored")
	eq(c1.SetAlpha + c2.SetAlpha + c3.SetAlpha - c1.Show - c2.Show - c3.Show <= 0, true, "no fade")
	eq(#w.violations, 0, "nothing protected was touched: " .. table.concat(w.violations, "; "))
	w:leaveCombat(r)
	T.clean(w)
end)

test("d2 n: combat starting in the middle of a move ends it at once, and nothing secure changes in the fight", function()
	local w, r, ui, UI, key = open()
	local home, confirm = ui.screens.home.frame, ui.screens.confirm.frame
	local b = r.env.WuberRequestButton
	UI.Show("confirm", key)
	w:advance(0.1)
	ok(dx(confirm) > 20, "on its way")
	w.violations = {}
	w:enterCombat(r)
	ok(near(dx(confirm), 0), "Confirm is in its place at once: " .. dx(confirm))
	ok(not home:IsShown(), "Home is hidden")
	local calls = watch(confirm)
	local shown = b:IsShown()
	w:advance(2)
	eq(calls.SetPoint, 0, "nothing moves in the fight")
	eq(b:IsShown(), shown, "the overlay is not shown or hidden in the fight")
	eq(#w.violations, 0, "nothing protected was touched: " .. table.concat(w.violations, "; "))
	w:leaveCombat(r)
	T.clean(w)
end)

test("d2 n: Reduce motion: the page fades in in place, nothing travels", function()
	local w, r, ui, UI, key = open()
	local home, confirm = ui.screens.home.frame, ui.screens.confirm.frame
	r.W.db.reduceMotion = true
	local calls = watch(confirm)
	UI.Show("confirm", key)
	ok(confirm:IsShown() and not home:IsShown(), "the pages swap")
	ok(near(dx(confirm), 0), "Confirm is in place from the start")
	ok(confirm:GetAlpha() < 1, "and fades in: " .. confirm:GetAlpha())
	w:advance(0.5)
	eq(confirm:GetAlpha(), 1, "to full")
	eq(calls.SetPoint, 0, "it never moved")
	local st = r.W.Mod("UI.Settings.Rows").st
	UI.OpenSettings()
	ok(near(dx(st.panel, ui.win), 0) and st.panel:GetAlpha() < 1, "Settings fades in in place too")
	w:advance(0.5)
	eq(st.panel:GetAlpha(), 1, "to full")
	T.clean(w)
end)

test("d2 n: the unfolded window: a page travels inside the 360-wide tab body, never over the side pane", function()
	local w, r, ui, UI, key = open(true)
	local body = UI.GetTab("Ride")
	ok(ui.win:GetWidth() > 700 and UI.Fold.IsUnfolded(), "the window is unfolded: " .. ui.win:GetWidth())
	local confirm = ui.screens.confirm.frame
	UI.Show("confirm", key)
	ok(near(dx(confirm), 360), "Confirm starts one pane to the right, not two: " .. dx(confirm))
	w:advance(0.1)
	ok(dx(confirm) > 20 and dx(confirm) < 340, "it travels in the unfolded window too: " .. dx(confirm))
	ok(confirm:GetParent() == body and body:DoesClipChildren(), "the travelling page is cut off by the tab body")
	ok(near(body:GetWidth(), 360), "which is the primary pane, not the window: " .. body:GetWidth())
	ok(confirm:GetRight() > body:GetRight() + 20, "so the part of it over the side pane is not drawn")
	w:advance(2)
	ok(near(dx(confirm), 0), "Confirm ends in place (a fold or unfold on the way ends the move)")
	ok(not ui.screens.home.frame:IsShown(), "Home is hidden")
	-- Settings unfolded is two panes wide: it does not travel
	local st = r.W.Mod("UI.Settings.Rows").st
	UI.OpenSettings()
	w:advance(0.1)
	ok(ui.win:GetWidth() > 700, "Settings is unfolded")
	ok(near(select(4, st.panel:GetPoint(1)), 0), "the wide Settings page is not pushed")
	w:advance(1)
	ok(near(select(4, st.panel:GetPoint(1)), 0), "and is in place")
	T.clean(w)
end)

test("d2 n: a driver's page is pushed over the console, back pops it, and the big button's slot waits for the end", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	T.openDrive(d)
	w:advance(2)
	local D = d.W.Driver
	local ui = D.ui
	local base = ui.console:IsShown() and ui.console or (ui.welcome:IsShown() and ui.welcome or ui.provider)
	D.ShowScreen("crew")
	local f = ui.subs.crew.frame
	ok(f:IsShown() and not base:IsShown(), "only the page is on screen while it travels")
	ok(near(dx(f, ui.root), 360), "the page starts a full width to the right: " .. dx(f, ui.root))
	w:advance(0.1)
	ok(dx(f, ui.root) > 20 and dx(f, ui.root) < 340, "on its way")
	w:advance(0.5)
	ok(near(dx(f, ui.root), 0), "in place")
	eq(D.pageMoving, nil, "the move is over")
	D.ShowScreen("console")
	ok(not f:IsShown() and base:IsShown(), "back: the page is hidden at once, only the console is on screen")
	eq(D.Slot(), nil, "no slot for the big button while the console is on its way")
	w:advance(0.1)
	ok(dx(base, ui.root) < -2, "the console comes back from the left: " .. dx(base, ui.root))
	w:advance(0.5)
	ok(not f:IsShown(), "gone")
	ok(near(dx(base, ui.root), 0), "the console is in its place")
	eq(D.pageMoving, nil, "the move is over")
	if base == ui.console then ok(D.Slot() ~= nil, "the slot is back") end
	-- the wizard's next step
	D.ShowScreen("wizard") w:advance(1)
	local wz = ui.subs.wizard
	d:clickText("My friends help") w:advance(0.5)
	d:click(wz.next)
	eq(wz.step, 2, "step two")
	ok(not wz.pages[1]:IsShown() and wz.pages[2]:IsShown(), "only step two is on screen while it travels")
	ok(dx(wz.pages[2], wz.content) > 100, "step two starts to the right: " .. dx(wz.pages[2], wz.content))
	wz.paint()
	ok(not wz.pages[1]:IsShown() and wz.pages[2]:IsShown(), "a repaint does not bring back the step that left")
	w:advance(0.6)
	ok(near(dx(wz.pages[2], wz.content), 0) and not wz.pages[1]:IsShown(), "step two in place, step one hidden")
	d:click(wz.back) -- the back chevron at the top (the wizard has no Back button of its own any more)
	eq(wz.step, 1, "back to step one")
	ok(wz.pages[1]:IsShown() and not wz.pages[2]:IsShown(), "only step one is on screen on the way back")
	w:advance(0.1)
	ok(dx(wz.pages[1], wz.content) < -2, "step one comes back from the left: " .. dx(wz.pages[1], wz.content))
	w:advance(0.5)
	ok(wz.pages[1]:IsShown() and not wz.pages[2]:IsShown(), "step one is back")
	eq(#w.violations, 0, table.concat(w.violations, "; "))
	T.clean(w)
end)
