-- Design round 2, triage groups TA and TF: a page on a phone is opaque, and NO frame level is ever changed for a
-- page move. The Ride screens, a Settings section, the driver's pages and the wizard's steps are siblings whose
-- frames interleave, so only ONE of the two pages is on screen while one travels (A.Push / A.PopPage with
-- opts.single): the other is hidden when the move starts, and the travelling page moves over a flat fill in the
-- window's colour, a texture of the clip frame itself (under every frame in it by parenting); gone at the end.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function open()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1024, screenH = 768 })
	T.settle(w)
	T.goOnline(d)
	w:advance(5)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state, r.W.UI, d.W.myKey, d
end

local function near(a, b) return math.abs(a - b) <= 0.6 end
local function dx(f, of) return f:GetLeft() - (of or f:GetParent()):GetLeft() end

-- the fill shows, is a texture of the clip frame that fills it, solid, in the window's colour; 'gone' is hidden
local function lies(r, clip, gone, what)
	local b = clip.wuberPageBacking
	ok(b and b:IsShown(), what .. ": the fill shows while the page travels")
	eq(b:GetParent(), clip, what .. ": it is a texture of the clip frame itself")
	eq(b:GetObjectType(), "Texture", what .. ": a texture, not a frame with a level")
	eq(b:GetDrawLayer(), "BACKGROUND", what .. ": in the background layer, under every frame in the clip frame")
	local rb, rc = H.rect(b), H.rect(clip)
	ok(near(rb.l, rc.l) and near(rb.b, rc.b) and near(rb.w, rc.w) and near(rb.h, rc.h), what .. ": it fills the clip frame")
	eq(b:GetAlpha(), 1, what .. ": opaque")
	local cr, cg, cb, ca = unpack(H.state[b].color or {})
	local wr, wg, wb = r.W.Theme.RGB("black")
	ok(cr and math.abs(cr - wr) < 0.01 and math.abs(cg - wg) < 0.01 and math.abs(cb - wb) < 0.01 and ca == 1, what .. ": the window's colour, solid")
	ok(not gone:IsShown(), what .. ": the other page is hidden, only one page is on screen")
	ok(not (clip.wuberPageCover and clip.wuberPageCover:IsShown()), what .. ": no cover")
	return b
end

-- every frame under 'root' with its level
local function levels(root, into, depth)
	into = into or {}
	depth = depth or 0
	into[root] = tonumber(root:GetFrameLevel()) or 0
	if depth < 40 then
		for _, c in ipairs({ root:GetChildren() }) do levels(c, into, depth + 1) end
	end
	return into
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
-- no frame that was there before has another level now
local function same(root, before, what)
	local now, bad = levels(root), {}
	for f, lv in pairs(before) do
		if now[f] ~= nil and now[f] ~= lv then bad[#bad + 1] = tostring(f.GetName and f:GetName() or "?") .. " " .. lv .. " -> " .. now[f] end
	end
	eq(#bad, 0, what .. ": " .. #bad .. " frame levels changed: " .. table.concat(bad, ", ", 1, math.min(#bad, 6)))
end

test("d2 ta: while Confirm is pushed only Confirm is on screen, over a flat fill of the clip frame; back, only Home, from the left", function()
	local w, r, ui, UI, key = open()
	local home, confirm = ui.screens.home.frame, ui.screens.confirm.frame
	local body = UI.GetTab("Ride")
	UI.Show("confirm", key)
	local b = lies(r, body, home, "push, first frame")
	ok(confirm:IsShown() and near(dx(confirm), 360), "Confirm starts a full width to the right: " .. dx(confirm))
	w:advance(0.1)
	lies(r, body, home, "push, on the way")
	ok(dx(confirm) > 20 and dx(confirm) < 340, "Confirm is on its way: " .. dx(confirm))
	ok(#(H.state[b].animGroups or {}) == 0, "no animation group on the fill: it is shown and hidden, never faded")
	w:advance(0.5)
	ok(not b:IsShown(), "the fill is gone when the page is in place")
	ok(confirm:IsShown() and near(dx(confirm), 0) and not home:IsShown(), "Confirm in place, Home hidden")
	-- the way back: Confirm is hidden at once, Home comes in from 30% left
	UI.Show("home")
	lies(r, body, confirm, "pop, first frame")
	ok(home:IsShown() and near(dx(home), -108), "Home starts 30% to the left: " .. dx(home))
	w:advance(0.1)
	lies(r, body, confirm, "pop, on the way")
	ok(dx(home) < -2 and dx(home) > -106, "Home is on its way back from the left: " .. dx(home))
	w:advance(0.5)
	ok(not b:IsShown() and not confirm:IsShown(), "the fill is gone")
	ok(home:IsShown() and near(dx(home), 0), "Home is in its place")
	home:Hide() confirm:Show()
	ok(near(dx(confirm), 0), "Confirm never moved on the way back")
	eq(#w.violations, 0, table.concat(w.violations, "; "))
	T.clean(w)
end)

test("d2 ta: a Settings section, and a driver's page over the console, travel alone over a fill too", function()
	local w, r, ui, UI, _, d = open()
	UI.OpenSettings()
	w:advance(1)
	local st = UI.settings
	local home = st.find.home
	r.W.Mod("UI.Settings.Panel").openSection("window")
	lies(r, st.pages, home, "section")
	w:advance(0.6)
	ok(not st.pages.wuberPageBacking:IsShown(), "gone when the section is in place")
	T.openDrive(d)
	w:advance(2)
	local D = d.W.Driver
	local base = D.ui.console:IsShown() and D.ui.console or (D.ui.welcome:IsShown() and D.ui.welcome or D.ui.provider)
	D.ShowScreen("crew")
	lies(d, D.ui.parent, base, "driver's page")
	w:advance(0.6)
	ok(not D.ui.parent.wuberPageBacking:IsShown(), "gone when the page is in place")
	T.clean(w)
end)

test("d2 ta: Settings over the tab keeps the push with the cover: the panel travels, no fill, the tab stays", function()
	local w, r, ui, UI = open()
	UI.OpenSettings()
	w:advance(0.1)
	local st = UI.settings
	local c = st.pages
	ok(c.wuberPageCover and c.wuberPageCover:IsShown(), "the cover dims the tab")
	ok(not (c.wuberPageBacking and c.wuberPageBacking:IsShown()), "no fill: the panel has its own")
	ok(UI.GetTab("Ride"):IsShown() and ui.screens.home.frame:IsShown(), "the tab under it stays on screen")
	T.clean(w)
end)

test("d2 tf: no frame level changes during or after a push and a pop: Home to Confirm, a Settings section, a driver's page", function()
	local w, r, ui, UI, key, d = open()
	local Panel = r.W.Mod("UI.Settings.Panel")
	-- once round first, so every page is built (a page sets its own levels when it is made)
	UI.Show("confirm", key) w:advance(1)
	UI.Show("home") w:advance(1)
	local before = levels(ui.win)
	ok(count(before) > 50, "the window's frames are walked: " .. count(before))
	UI.Show("confirm", key)
	same(ui.win, before, "Confirm pushed, first frame")
	w:advance(0.08)
	ok(dx(ui.screens.confirm.frame) > 20, "half-way: " .. dx(ui.screens.confirm.frame) .. " on " .. tostring(ui.screen))
	same(ui.win, before, "Confirm pushed, half-way")
	w:advance(0.6)
	same(ui.win, before, "Confirm pushed, after")
	UI.Show("home")
	same(ui.win, before, "Confirm popped, first frame")
	w:advance(0.08)
	ok(dx(ui.screens.home.frame) < -2, "half-way back")
	same(ui.win, before, "Confirm popped, half-way")
	w:advance(0.6)
	same(ui.win, before, "Confirm popped, after")
	-- a Settings section
	UI.OpenSettings() w:advance(1)
	local st = UI.settings
	Panel.openSection("sound") w:advance(1)
	r:click(st.back) w:advance(1)
	before = levels(ui.win)
	Panel.openSection("sound")
	w:advance(0.08)
	ok(st.pages.wuberPageBacking:IsShown(), "the section is half-way")
	same(ui.win, before, "section pushed, half-way")
	w:advance(0.6)
	same(ui.win, before, "section pushed, after")
	r:click(st.back)
	w:advance(0.08)
	ok(st.pages.wuberPageBacking:IsShown(), "the section is half-way back")
	same(ui.win, before, "section popped, half-way")
	w:advance(0.6)
	same(ui.win, before, "section popped, after")
	-- a driver's page
	T.openDrive(d)
	w:advance(2)
	local D = d.W.Driver
	local dwin = d.W.UI.state.win
	D.ShowScreen("crew") w:advance(1)
	D.ShowScreen("console") w:advance(1)
	before = levels(dwin)
	D.ShowScreen("crew")
	w:advance(0.08)
	ok(D.pageMoving, "the driver's page is half-way")
	same(dwin, before, "driver's page pushed, half-way")
	w:advance(0.6)
	same(dwin, before, "driver's page pushed, after")
	D.ShowScreen("console")
	w:advance(0.08)
	ok(D.pageMoving, "half-way back")
	same(dwin, before, "driver's page popped, half-way")
	w:advance(0.6)
	same(dwin, before, "driver's page popped, after")
	T.clean(w)
end)

test("d2 ta: Reduce motion and combat lay no fill (nothing travels)", function()
	local w, r, ui, UI, key = open()
	local body = UI.GetTab("Ride")
	r.W.db.reduceMotion = true
	UI.Show("confirm", key)
	ok(not (body.wuberPageBacking and body.wuberPageBacking:IsShown()), "Reduce motion: a fade in place, no fill")
	w:advance(1)
	r.W.db.reduceMotion = false
	w:enterCombat(r)
	w:advance(1)
	UI.Show("home")
	ok(not (body.wuberPageBacking and body.wuberPageBacking:IsShown()), "combat: a swap at once, no fill")
	T.clean(w)
end)
