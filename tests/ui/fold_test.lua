-- Tests of UI.Fold (SPEC7 2; owner A). Loaded by tests/run.lua with its helper table T.
-- The contract, then SPEC7 2.9's list: auto-unfold on each of the eight pages, the button and its
-- memory, room, combat, no Scale, near the right edge, fx off and interrupted tweens, layouts
-- called twice make no new frames, the 3-slice background drawn as the one texture was.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local PAGES = { "ride", "confirm", "trips", "settings", "console", "raid", "earnings", "messages" }

-- every page registered with a spy layout (C and D register the real ones)
local function spyPages(c, only)
	local UI = c.W.UI
	local log = { built = {}, calls = {} }
	for _, p in ipairs(only or PAGES) do
		UI.Fold.Register(p, {
			build = function(h)
				log.built[p] = (log.built[p] or 0) + 1
				h.mark = h:CreateTexture(nil, "ARTWORK")
				h.mark:SetAllPoints(h)
			end,
			layout = function(on, h)
				log.calls[#log.calls + 1] = p .. (on and " wide" or " narrow")
				ok(h and h.mark, "layout gets the page's holder")
			end,
		})
	end
	return log
end

local function folds(c)
	local list = {}
	c.W.Listen("FOLD", function(on, page) list[#list + 1] = (on and "open " or "shut ") .. tostring(page) end)
	return list
end

-- a client on a wide (or given) screen, the window open on Home, past the splash. The harness
-- runs old tests folded (UI.Fold.Fits says "small") unless a client asks for room: these do
-- (c.wide), unless opts.wide == false.
local function open(w, c, opts)
	opts = opts or {}
	c.wide = opts.wide ~= false
	T.settle(w)
	local W = c.W
	W.db.coach = true -- no first-open tips (their page is nil: always folded)
	if opts.scale then W.db.scale = opts.scale end
	local log = opts.noPages and { built = {}, calls = {} } or spyPages(c, opts.pages)
	local fl = folds(c)
	W.UI.Toggle(true)
	w:advance(3)
	return W, W.UI, log, fl
end

local function setScreen(c, width)
	H.state[c.env.UIParent].w = width
	c:fire("DISPLAY_SIZE_CHANGED")
end

local function win(c) return c.env.WuberFrame end

-- the tooltip a frame shows on hover, as one line
local function tipOf(c, f)
	local gt = c.env.GameTooltip
	H.state[gt].tipLines = {}
	H.state[f].scripts.OnEnter(f)
	local text = table.concat(H.state[gt].tipLines or {}, " | ")
	H.state[f].scripts.OnLeave(f)
	return text
end

local function driverAt(W, c)
	local t0 = c.env.GetTime()
	W.drivers["anita lift"] = { name = "Anita Lift", key = "anita lift", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Anita's Portals", heard = t0, mapID = 1454, x = 0.5, y = 0.5 }
	W.Fire("DRIVERS")
end

test("ui.fold: contract (registered, deps, header, public names); folded and idle where the harness gives no room", function()
	local W, w, r, Mod = T.contract("UI.Fold", "tests/ui/fold_test.lua", {
		["UI.Fold"] = "table",
		["UI.Fold.Apply"] = "function",
		["UI.Fold.Fits"] = "function",
		["UI.Fold.IsUnfolded"] = "function",
		["UI.Fold.Page"] = "function",
		["UI.Fold.Pane"] = "function",
		["UI.Fold.Register"] = "function",
		["UI.Fold.Reset"] = "function",
		["UI.Fold.Toggle"] = "function",
		["UI.WindowWide"] = "function",
		["Mod.state"] = "table",
		["Mod.room"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Fold\")")
	local UI = W.UI
	W.db.coach = true
	eq(UI.Fold.Page(), nil, "no page before the first open (the splash comes first)")
	UI.Fold.Toggle() UI.Fold.Apply(true) UI.Fold.Reset()
	eq(UI.Fold.IsUnfolded(), false, "folded: no page is registered")
	eq(W.db.fold, nil, "nothing saved until the player chooses")
	eq(UI.WindowWide(), true, "Wide pages: Auto by default")
	UI.Toggle(true)
	w:advance(3)
	eq(UI.Fold.Page(), "ride", "Home is the ride page")
	eq(select(2, UI.Fold.Fits()), "small", "the harness gives an old test no room")
	eq(UI.Fold.IsUnfolded(), false, "folded without room")
	eq(win(r):GetWidth(), 360, "360 wide")
	local b = r.W.UI.state.phone.fold
	ok(b:IsShown() and b:GetAlpha() < 1, "the fold button shows, dimmed")
	UI.Fold.Toggle() w:advance(1)
	eq(win(r):GetWidth(), 360, "its click does nothing without room")
	eq(W.db.fold, nil, "still nothing saved")
	T.clean(w)
end)

test("ui.fold 1: each of the eight pages unfolds by itself on a wide screen; FOLD once; other pages stay 360", function()
	local w = T.newWorld()
	local d = T.driver(w, nil, {})
	local W, UI, log, fl = open(w, d)
	eq(UI.Fold.Page(), "ride", "page")
	eq(win(d):GetWidth(), 720, "ride: 720 wide after the tween")
	eq(#fl, 1, "FOLD fired once: " .. table.concat(fl, ", "))
	eq(fl[1], "open ride", "FOLD (true, ride)")
	eq(log.built.ride, 1, "built once, lazily")
	eq(log.built.trips, nil, "trips not built before it unfolds")
	ok(UI.Fold.Pane():IsVisible(), "the side pane shows")
	local pl, pt = UI.Fold.Pane():GetLeft(), UI.Fold.Pane():GetTop()
	eq(math.floor(pl - win(d):GetLeft() + 0.5), 360, "the side pane starts at x 360")
	eq(math.floor(win(d):GetTop() - pt + 0.5), 0, "from the top of the screen (design 2: no top bar)")
	eq(UI.GetTab("Ride"):GetWidth(), 360, "the primary pane stays 360")
	-- confirm (a driver's card)
	driverAt(W, d)
	UI.Show("confirm", "anita lift")
	w:advance(1)
	eq(UI.Fold.Page(), "confirm", "confirm page")
	eq(win(d):GetWidth(), 720, "confirm wide")
	-- trips
	UI.Show("home") w:advance(1)
	UI.SelectTab("Trips") w:advance(1)
	eq(UI.Fold.Page(), "trips", "trips page")
	eq(win(d):GetWidth(), 720, "trips wide")
	-- settings
	UI.OpenSettings() w:advance(1)
	eq(UI.Fold.Page(), "settings", "settings page")
	eq(win(d):GetWidth(), 720, "settings wide")
	UI.CloseSettings(true) w:advance(1)
	-- the Drive tab: console, raid, earnings, messages
	W.Char().wizard = true
	UI.SelectTab("Drive") w:advance(1)
	local D = W.Driver
	eq(D.Mode(), "console", "the driver console")
	eq(UI.Fold.Page(), "console", "console page")
	eq(win(d):GetWidth(), 720, "console wide")
	D.ShowScreen("earnings") w:advance(1)
	eq(UI.Fold.Page(), "earnings", "earnings page")
	eq(win(d):GetWidth(), 720, "earnings wide")
	D.ShowScreen("messages") w:advance(1)
	eq(UI.Fold.Page(), "messages", "messages page")
	eq(win(d):GetWidth(), 720, "messages wide")
	D.ShowScreen("console") w:advance(1)
	W.Drive.SetMode("raid") w:advance(1)
	eq(UI.Fold.Page(), "raid", "raid page")
	eq(win(d):GetWidth(), 720, "raid wide")
	-- a page that isn't one of the eight: the crew screen folds
	D.ShowScreen("crew") w:advance(1)
	eq(UI.Fold.Page(), nil, "crew: no page")
	eq(win(d):GetWidth(), 360, "crew: folded")
	eq(UI.Fold.IsUnfolded(), false, "folded")
	ok(not UI.Fold.Pane():IsShown(), "side pane hidden while folded")
	for _, p in ipairs(PAGES) do eq(log.built[p], 1, p .. " built once") end
	T.clean(w)
end)

test("ui.fold 2: the fold button folds ride and remembers it there only; Reset forgets", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W, UI, log, fl = open(w, r)
	local b = UI.state.phone.fold
	ok(b:IsVisible(), "the fold button shows on ride")
	eq(win(r):GetWidth(), 720, "unfolded")
	r:click(b)
	w:advance(1)
	eq(win(r):GetWidth(), 360, "folded by the button")
	eq(W.db.fold.pages.ride, "closed", "remembered for ride")
	eq(W.db.fold.v, 1, "W.db.fold.v")
	eq(fl[#fl], "shut ride", "FOLD (false, ride)")
	-- leave and come back: still folded
	UI.SelectTab("Trips") w:advance(1)
	eq(win(r):GetWidth(), 720, "trips still unfolds")
	UI.SelectTab("Ride") w:advance(1)
	eq(win(r):GetWidth(), 360, "back on ride: folded")
	driverAt(W, r)
	UI.Show("confirm", "anita lift") w:advance(1)
	eq(win(r):GetWidth(), 720, "confirm still unfolds")
	UI.Show("home") w:advance(1)
	eq(win(r):GetWidth(), 360, "ride folded again")
	-- the button opens it again, and that is remembered too
	r:click(b) w:advance(1)
	eq(win(r):GetWidth(), 720, "unfolded by the button")
	eq(W.db.fold.pages.ride, "open", "open remembered")
	r:click(b) w:advance(1)
	eq(W.db.fold.pages.ride, "closed", "closed again")
	UI.Fold.Reset() w:advance(1)
	eq(next(W.db.fold.pages), nil, "Reset clears the choices")
	eq(win(r):GetWidth(), 720, "ride unfolds again (its default)")
	-- Always narrow: everything folds, the button hides
	UI.WindowWide(false) w:advance(1)
	eq(W.db.fold.narrow, true, "narrow saved")
	eq(win(r):GetWidth(), 360, "always narrow")
	ok(not b:IsShown(), "no fold button while always narrow")
	eq(UI.WindowWide(), false, "WindowWide() reads it")
	UI.WindowWide(true) w:advance(1)
	eq(W.db.fold.narrow, false, "Auto saved (the Settings row reads W.db.fold.narrow)")
	eq(win(r):GetWidth(), 720, "Auto again")
	ok(b:IsShown(), "the button is back")
	T.clean(w)
end)

test("ui.fold 3: too small: never unfolds, the button is dimmed with its tip; a wider screen unfolds", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { screenW = 800 })
	local W, UI, log, fl = open(w, r)
	-- (720 + 16) x 1.15 + 16 = 862 > 800
	eq(UI.Fold.Page(), "ride", "page")
	eq(win(r):GetWidth(), 360, "folded: no room")
	eq((UI.Fold.Fits()), false, "Fits")
	eq(select(2, UI.Fold.Fits()), "small", "why")
	local b = UI.state.phone.fold
	ok(b:IsVisible(), "the button stays visible")
	eq(b:GetAlpha(), 0.4, "dimmed")
	local tip = tipOf(r, b)
	ok(tip:find("Not enough room to unfold. Make the game window wider or Wuber smaller (Settings > Window size).", 1, true), "tip: " .. tip)
	r:click(b) w:advance(1)
	eq(win(r):GetWidth(), 360, "clicking does nothing")
	eq(W.db.fold, nil, "nothing saved")
	-- 1000 wide at scale 1.4: (736 x 1.4) + 16 = 1046 > 1000
	setScreen(r, 1000)
	W.db.scale = 1.4
	UI.ApplyScale() w:advance(1)
	eq(win(r):GetWidth(), 360, "still folded at 1.4")
	W.db.scale = nil
	UI.ApplyScale() w:advance(1)
	eq(win(r):GetWidth(), 720, "1000 wide at 1.15 fits (862): unfolds after the size slider")
	W.db.scale = 1.4
	UI.ApplyScale() w:advance(1)
	eq(win(r):GetWidth(), 360, "too big again: folds")
	setScreen(r, 1400)
	w:advance(1)
	eq(win(r):GetWidth(), 720, "1400 + DISPLAY_SIZE_CHANGED: unfolds")
	eq(b:GetAlpha(), 1, "the button is lit")
	T.clean(w)
end)

test("ui.fold 4: combat: no fold change; the wanted change is made after combat; no secure frame touched in combat", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W, UI, log, fl = open(w, r)
	local b = UI.state.phone.fold
	r:click(b) w:advance(1)
	eq(win(r):GetWidth(), 360, "ride folded by choice")
	driverAt(W, r)
	w:enterCombat(r)
	w:advance(0.5)
	eq(b:GetAlpha(), 0.4, "dimmed in combat")
	eq(select(2, UI.Fold.Fits()), "combat", "Fits: combat")
	local tip = tipOf(r, b)
	ok(tip:find("After combat", 1, true), "tip: " .. tip)
	UI.Fold.Toggle() w:advance(1)
	eq(win(r):GetWidth(), 360, "Toggle does nothing in combat")
	eq(W.db.fold.pages.ride, "closed", "choice unchanged")
	UI.Show("confirm", "anita lift") w:advance(1)
	eq(UI.Fold.Page(), "confirm", "the page changes in combat")
	eq(win(r):GetWidth(), 360, "confirm stays folded in combat")
	local syncs = {}
	local orig = UI.SyncSecure
	UI.SyncSecure = function(...)
		syncs[#syncs + 1] = r.env.GetTime()
		return orig(...)
	end
	local endAt = r.env.GetTime()
	w:leaveCombat(r)
	w:advance(0.15)
	eq(win(r):GetWidth(), 360, "not yet: 0.2 s after combat")
	w:advance(0.1)
	ok(win(r):GetWidth() >= 360, "unfolding")
	w:advance(1)
	eq(win(r):GetWidth(), 720, "unfolded after combat")
	local after = 0
	for _, t in ipairs(syncs) do if t >= endAt + 0.2 + 0.3 - 0.001 then after = after + 1 end end
	ok(after >= 1, "UI.SyncSecure ran after the tween")
	ok(r.env.WuberRequestButton:IsVisible(), "the Request overlay is back on its pill")
	UI.SyncSecure = orig
	T.clean(w) -- (violations: any secure frame changed in combat would be listed)
end)

test("ui.fold 5: no Scale: the tweens change only width, the window's place and the side holder", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W, UI, log, fl = open(w, r)
	local wf = win(r)
	local scaled, widths, others = {}, {}, {}
	for _, obj in ipairs(r.widgets) do
		local s = H.state[obj]
		if s and s.kind == "frame" then
			local set, setW = obj.SetScale, obj.SetWidth
			obj.SetScale = function(self, ...) scaled[#scaled + 1] = tostring(s.name or s.otype) return set(self, ...) end
			obj.SetWidth = function(self, v, ...)
				if self == wf then
					widths[#widths + 1] = v
				elseif s.w ~= v then -- (the screens' own refresh sets the widths they already have)
					others[#others + 1] = tostring(s.name or s.otype) .. " " .. tostring(s.w) .. "->" .. tostring(v)
				end
				return setW(self, v, ...)
			end
		end
	end
	-- (Home's own looping pulses play all the time; nothing new may scale)
	local before = {}
	for g in pairs(r.playing) do before[g] = true end
	local function watch(secs)
		local t = 0
		while t < secs do
			w:advance(0.05)
			t = t + 0.05
			for g in pairs(r.playing) do
				if not before[g] then
					for _, a in ipairs(H.state[g].anims or {}) do
						ok(H.state[a].otype ~= "Scale", "a Scale animation started during the tween")
					end
				end
			end
		end
	end
	UI.Fold.Toggle()
	watch(0.5)
	UI.Fold.Toggle()
	watch(0.5)
	eq(#scaled, 0, "SetScale during the tweens: " .. table.concat(scaled, ", "))
	ok(#widths >= 4, "WuberFrame's width tweened (" .. #widths .. " steps)")
	local mid = 0
	for _, v in ipairs(widths) do if v > 360 and v < 720 then mid = mid + 1 end end
	ok(mid >= 2, "in-between widths: " .. table.concat(widths, ", "))
	eq(#others, 0, "no other frame's width changed: " .. table.concat(others, ", "))
	T.clean(w)
end)

test("ui.fold 6: near the right edge it slides left while it widens; folding keeps the left edge and the overlays", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	r.W.db.pos = { "TOPLEFT", "TOPLEFT", 1400, -100 }
	local W, UI, log, fl = open(w, r, {})
	local wf = win(r)
	local s = wf:GetEffectiveScale() / r.env.UIParent:GetEffectiveScale()
	local right = (1920 - 8) / s
	eq(UI.Fold.IsUnfolded(), true, "unfolded")
	ok(math.abs(wf:GetRight() + 8 - right) < 0.01, "the phone's right edge is 8 px inside the screen: " .. wf:GetRight())
	ok(wf:GetLeft() < 1400 - 400, "slid left by the overflow: " .. wf:GetLeft())
	eq(W.db.pos[1], "TOPLEFT", "position saved by its top left")
	ok(math.abs(W.db.pos[3] - wf:GetLeft()) <= 0.5, "saved where it now is")
	-- Confirm, its Request overlay
	driverAt(W, r)
	UI.Show("confirm", "anita lift") w:advance(1)
	local req = r.env.WuberRequestButton
	ok(req:IsVisible(), "Request overlay on its pill")
	local function rect(f) return ("%.1f,%.1f,%.1f,%.1f"):format(f:GetLeft(), f:GetBottom(), f:GetWidth(), f:GetHeight()) end
	local before, left = rect(req), wf:GetLeft()
	UI.Fold.Toggle()
	w:advance(1)
	eq(wf:GetWidth(), 360, "folded")
	eq(wf:GetLeft(), left, "the left edge did not move back")
	ok(req:IsVisible(), "Request overlay back")
	eq(rect(req), before, "the overlay's rect is unchanged")
	T.clean(w)
end)

test("ui.fold 7: fx off is instant; an interrupted tween snaps to its end first", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W, UI, log, fl = open(w, r)
	local wf = win(r)
	W.db.fx = "off"
	UI.Fold.Toggle()
	eq(wf:GetWidth(), 360, "folded at once")
	eq(fl[#fl], "shut ride", "FOLD at once")
	UI.Fold.Toggle()
	eq(wf:GetWidth(), 720, "unfolded at once")
	W.db.fx = nil
	local n = #fl
	UI.Fold.Toggle() -- folding...
	w:advance(0.1)
	ok(wf:GetWidth() > 360, "mid-tween")
	UI.Fold.Toggle() -- ...interrupted
	eq(fl[n + 1], "shut ride", "the fold snapped to its end (FOLD false) before the unfold")
	eq(#fl, n + 1, "the unfold is playing")
	w:advance(1)
	eq(fl[n + 2], "open ride", "then unfolded")
	eq(wf:GetWidth(), 720, "wide")
	T.clean(w)
end)

test("ui.fold 8: the 3-slice background draws as the one texture did; tab bodies, island, toasts stay put", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W, UI, log, fl = open(w, r, { noPages = true, wide = false })
	local wf = win(r)
	eq(wf:GetWidth(), 360, "folded first (no room yet)")
	local sl = wf.slices
	ok(sl and sl.left and sl.mid and sl.right, "three slices")
	local L, M, R = sl.left, sl.mid, sl.right
	local function u(t) local tc = H.state[t].texCoord return tc[1], tc[2] end
	-- folded: texcoord per window unit is the same in all three (504/512 over 360)
	local k = (504 / 512) / 360
	for _, t in ipairs({ L, M, R }) do
		local a, b = u(t)
		ok(math.abs((b - a) / t:GetWidth() - k) < 1e-9, "same texels per unit")
	end
	eq(L:GetLeft(), wf:GetLeft(), "left cap at the left")
	ok(math.abs(M:GetLeft() - L:GetRight()) < 1e-6 and math.abs(R:GetLeft() - M:GetRight()) < 1e-6, "no gaps")
	ok(math.abs(R:GetRight() - wf:GetRight()) < 1e-6, "right cap at the right")
	local island = UI.state.phone.island
	local ix = island:GetCenter()
	ok(ix and math.abs(ix - wf:GetLeft() - 180) < 1e-6, "folded, the island in the middle of the 360 window: " .. tostring(ix and ix - wf:GetLeft()))
	-- unfolded: the caps keep their size, the middle stretches; (round 13, I19) the island moves to the middle
	spyPages(r, { "ride" })
	r.wide = true
	UI.Fold.Apply() w:advance(1)
	eq(wf:GetWidth(), 720, "wide")
	local function near(a, b, what) ok(math.abs(a - b) < 1e-6, what .. ": " .. a) end
	near(L:GetWidth(), 126, "left cap 126")
	near(R:GetWidth(), 126, "right cap 126")
	near(M:GetWidth(), 468, "middle stretched")
	ok(math.abs(island:GetCenter() - wf:GetLeft() - 360) < 1e-6, "(r13 I19) the island in the middle of the wide window")
	eq(UI.GetTab("Ride"):GetWidth(), 360, "the Ride body stays 360")
	local x = UI.ToastPlace()
	ok(x ~= nil, "toast place")
	T.clean(w)
end)

test("ui.fold 9: unfolding and folding twice makes no new frames the second time", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W, UI, log, fl = open(w, r)
	UI.Fold.Toggle() w:advance(1)
	UI.Fold.Toggle() w:advance(1)
	local n = #r.widgets
	UI.Fold.Toggle() w:advance(1)
	UI.Fold.Toggle() w:advance(1)
	eq(#r.widgets, n, "no new widgets on the second fold and unfold")
	eq(log.built.ride, 1, "built once")
	local calls = table.concat(log.calls, ", ")
	eq(calls, "ride wide, ride narrow, ride wide, ride narrow, ride wide", "layout calls")
	ok(r.W.UI.Fold.IsUnfolded(), "unfolded")
	-- hiding the window folds it; showing it unfolds at once (no tween)
	UI.Toggle(false) w:advance(1)
	eq(win(r):GetWidth(), 360, "hidden: folded")
	UI.Toggle(true)
	eq(win(r):GetWidth(), 720, "shown: unfolded at once")
	w:advance(1)
	T.clean(w)
end)

test("ui.fold 10: an unfold that doesn't move the window saves no position (WuberDB stays as it was)", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	r.W.db.pos = { "CENTER", "CENTER", -200, 40 }
	local W, UI, log, fl = open(w, r)
	eq(UI.Fold.IsUnfolded(), true, "unfolded")
	eq(table.concat(W.db.pos, " "), "CENTER CENTER -200 40", "the saved position is untouched")
	UI.Fold.Toggle() w:advance(1)
	eq(UI.Fold.IsUnfolded(), false, "folded")
	eq(table.concat(W.db.pos, " "), "CENTER CENTER -200 40", "folding saves nothing either")
	T.clean(w)
end)

test("ui.fold: round 9 S16 - the fold button sits in the app header left of Settings, round and clear, folded and unfolded", function()
	local w = T.newWorld()
	local d = T.driver(w, nil, {})
	local W, UI = open(w, d)
	local b = UI.state.phone.fold
	eq(b:GetParent(), UI.state.top, "in the app header")
	eq(win(d):GetWidth(), 720, "unfolded")
	local function check(label)
		ok(b:IsVisible() and b:GetAlpha() == 1, label .. ": shown, not dimmed")
		local br, gr = H.rect(b), H.rect(UI.state.gear)
		ok(br.w >= 26 and br.h >= 26, label .. ": big enough to see: " .. br.w)
		ok(br.l + br.w <= gr.l and gr.l - (br.l + br.w) <= 9.5, label .. ": just left of Settings") -- (design 2) 8 apart, in screen units
		ok(math.abs((br.b + br.h / 2) - (gr.b + gr.h / 2)) < 1, label .. ": on the header's line")
		for _, tab in ipairs(UI.state.tabs) do
			local tr = H.rect(tab.button)
			-- (design 2, C) the tabs are in the bar at the bottom now, not beside it
			ok(tr.b + tr.h <= br.b, label .. ": the " .. tab.name .. " tab is below it: " .. (tr.b + tr.h) .. " vs " .. br.b)
		end
	end
	check("unfolded")
	ok(tipOf(d, b):find("Fold", 1, true), "tip: " .. tipOf(d, b))
	d:click(b) w:advance(1)
	eq(win(d):GetWidth(), 360, "its click folds")
	check("folded")
	ok(tipOf(d, b):find("Unfold", 1, true), "tip: " .. tipOf(d, b))
	T.clean(w)
end)
