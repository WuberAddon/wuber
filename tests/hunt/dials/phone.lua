-- Hunt dial file (tests/hunt/README.md): the phone. Owner: WORLD.
-- phone  what the phone shows when the check starts: closed, or open on a screen. Every tab and screen a player can
--        leave the phone on (Wuber/UI/Window.lua tabs Ride, Trips, Drive; Drive's screens; Settings and its five
--        sections; Help; the report; Confirm; the World view; Wrapped). The suffix says HOW it got there:
--        "drive" = the player opened the phone (it ran its splash, Home showed) and then CLICKED the Drive tab;
--        "drive_direct" = the phone opened on Drive by itself, never having shown Home (what a toast, "/wuber drive"
--        and Settings > Edit do: UI.ShowDrive / UI.Show("drive")). Wuber saves no "last tab": the saved state a phone
--        really remembers is where it stands (pos), how wide pages were left (fold) and the World/Here view (mapView).
-- fold   wide pages: Auto (the default: a page that fits unfolds), every page folded by the player earlier (saved),
--        "Always narrow" (saved), or the player clicks the fold button after the phone opened.
-- size   the game window and Wuber size, the nine the layout check runs (tools/layout-check.lua: 3 windows x 3 sizes).
-- pos    where the phone was left: none saved (the usual place), a corner, or a place that is off screen (a smaller
--        window than the one it was dragged in).
-- Combat: world.lua's "combat" dial, value "before", is done HERE: every phone value starts with entering combat when
-- sit.combat == "before", then opens the phone (a player clicking the minimap button in a fight). Whether the phone
-- opened is then Wuber's answer: ctx.facts.phoneOpened.
-- Facts: phoneOpened, tab, screen, settings (true when Settings shows), wrappedShown, helpShown, bugShown, unfolded, fits, uiWidth, uiHeight.
return function(Hunt)
	local function log(ctx, line)
		if type(ctx.note) == "function" then ctx:note(line) end -- the core's step log, for the repro file
	end
	local function wdb(ctx)
		local s = ctx.saved
		if type(s) ~= "table" then s = {} ctx.saved = s end
		if type(s.Wuber) == "table" then return s.Wuber end
		if s.chars ~= nil or s.rides ~= nil or s.fx ~= nil then return s end
		s.Wuber = {}
		return s.Wuber
	end
	local function sub(t, k)
		if type(t[k]) ~= "table" then t[k] = {} end
		return t[k]
	end
	local function UI(ctx) return ctx.W and ctx.W.UI end
	local function st(ctx) local u = UI(ctx) return u and u.state end
	local function shown(ctx)
		local u = UI(ctx)
		return u ~= nil and type(u.IsShown) == "function" and u.IsShown() == true
	end

	-- the facts a promise reads, written after every value
	local function facts(ctx)
		local f, s, u = ctx.facts, st(ctx), UI(ctx)
		f.phoneOpened = shown(ctx)
		f.tab, f.screen = s and s.tab or nil, s and s.screen or nil
		f.settings = s and s.settingsOpen == true or false
		local F = u and u.Fold
		f.unfolded = F and type(F.IsUnfolded) == "function" and F.IsUnfolded() == true or false
		if F and type(F.Fits) == "function" then f.fits = F.Fits() == true end
		local WM = ctx:mod("UI.Rider.Wrapped")
		f.wrappedShown = WM and type(WM.Shown) == "function" and WM.Shown() == true or false
		f.helpShown = u and type(u.HelpShown) == "function" and u.HelpShown() == true or false
		f.bugShown = u and type(u.Bug) == "table" and type(u.Bug.Shown) == "function" and u.Bug.Shown() == true or false
		local P = ctx.me and ctx.me.env and ctx.me.env.UIParent
		if P then f.uiWidth, f.uiHeight = P:GetWidth(), P:GetHeight() end
	end

	-- combat before the phone opens (see the header)
	local function before(ctx)
		if ctx.sit and ctx.sit.combat == "before" and not ctx.me.player.combat then
			ctx.w:enterCombat(ctx.me)
			log(ctx, "enter combat before the phone opens")
		end
	end

	-- the player opens the phone with /wuber (the minimap button does the same Toggle)
	local function open(ctx)
		-- the phone may already be open by itself (a ride arrived: "You've arrived"): /wuber would CLOSE it, so a
		-- player just goes on from the open phone (clicks the tab)
		if shown(ctx) then log(ctx, "(the phone is already open)") return true end
		ctx.me:slash("/wuber")
		ctx:advance(0.3)
		log(ctx, "/wuber")
		if not shown(ctx) and not (ctx.me.player.combat) then ctx:cannot("the phone did not open on /wuber") return false end
		return shown(ctx)
	end
	local function settle(ctx) ctx:advance(2.2) end -- the splash (1.2 s) ends, Home shows

	-- the player clicks a tab (a real click on its button; the API only when the click lands on nothing)
	local function clickTab(ctx, name)
		local s = st(ctx)
		if not s then return false end
		for _, tab in ipairs(s.tabs or {}) do
			if tab.name == name and tab.button then
				-- the tabs hide while a ride is on (Window.lua): a player cannot click what is not there
				if not ctx:visible(tab.button) then ctx:cannot("the " .. name .. " tab is hidden (a ride is on): it cannot be clicked") return false end
				ctx.me:clickOn(tab.button)
				ctx:advance(0.8)
				log(ctx, "click the " .. name .. " tab")
				if s.tab ~= name then
					UI(ctx).SelectTab(name)
					ctx:advance(0.8)
					log(ctx, "(the click missed) SelectTab " .. name)
				end
				return s.tab == name
			end
		end
		return false
	end

	-- quick: the value is "just opened, the splash still plays" (no waiting after it)
	local function wrap(fn, quick)
		return function(ctx)
			before(ctx)
			fn(ctx)
			if not quick then ctx:advance(0.3) end
			facts(ctx)
		end
	end
	local function needOpen(ctx)
		if not open(ctx) then
			if ctx.me.player.combat then return false end
			return false
		end
		return true
	end
	local function drive(screen)
		return function(ctx)
			local u = UI(ctx)
			if not (u and u.ShowDrive) then ctx:cannot("no UI.ShowDrive") return end
			if not open(ctx) then return end
			settle(ctx)
			log(ctx, "UI.ShowDrive " .. screen)
			if not u.ShowDrive(screen) then ctx:cannot("Drive screen " .. screen .. " did not show") return end
			ctx:advance(0.5)
		end
	end
	local function settingsAt(where)
		return function(ctx)
			local u = UI(ctx)
			u.Toggle(true) ctx:advance(0.3) settle(ctx)
			log(ctx, "UI.OpenSettings " .. tostring(where))
			if not u.OpenSettings(where) then ctx:cannot("Settings did not open") return end
			ctx:advance(0.5)
		end
	end

	local VALUES = {
		{ "closed", "the phone is closed (never opened this session; if a ride opened it by itself, the player closes it with /wuber)", function(ctx)
			if shown(ctx) then
				ctx.me:slash("/wuber") ctx:advance(0.3) log(ctx, "/wuber (close the phone the ride opened)")
				if shown(ctx) then ctx:cannot("the phone did not close on /wuber") end
			end
		end },
		{ "splash", "just opened: the splash is still showing", function(ctx) open(ctx) ctx:advance(0.3) end },
		{ "home", "opened with /wuber, splash over, on Ride / Home", function(ctx) if needOpen(ctx) then settle(ctx) end end },
		{ "trips", "opened, then the Trips tab clicked", function(ctx) if needOpen(ctx) then settle(ctx) clickTab(ctx, "Trips") end end, nil, nil, { ride = { "requested", "invited", "summoning", "arrived" } } }, -- (the tabs hide while a ride is summoning or has arrived)
		{ "drive", "opened, then the Drive tab clicked", function(ctx) if needOpen(ctx) then settle(ctx) clickTab(ctx, "Drive") end end, nil, nil, { ride = { "requested", "invited", "summoning", "arrived" } } },
		{ "trips_direct", "opened by itself on Trips (UI.Show(\"trips\"), as the milestone toast does), the splash still playing", function(ctx)
			log(ctx, "UI.Show trips") UI(ctx).Show("trips") ctx:advance(0.3) end, nil, true },
		{ "drive_direct", "opened by itself on the Drive tab (as the shift toast and /wuber drive do), the splash still playing; a due login tip moves it to Home when the splash ends", function(ctx)
			log(ctx, "UI.Show drive") UI(ctx).Show("drive") ctx:advance(0.3) end, nil, true },
		{ "drive_earnings", "Drive tab, the Earnings screen (a rider never gets it: it opens from the console's 'today' line, which a rider has no console for)", function(ctx) drive("earnings")(ctx) end, nil, nil, { role = { "rider" } } },
		{ "drive_messages", "Drive tab, the Messages screen (the settings 'Edit' button opens it; Settings > Driving shows for Warlocks only: never a rider)", function(ctx) drive("messages")(ctx) end, nil, nil, { role = { "rider" } } },
		{ "drive_customers", "Drive tab, the Customers screen (a rider never gets it: the screen is for drivers)", function(ctx) drive("customers")(ctx) end, nil, nil, { role = { "rider" } } },
		{ "drive_crew", "Drive tab, the Crew screen (opens from the console's crew chips: never a rider)", function(ctx) drive("crew")(ctx) end, nil, nil, { role = { "rider" } } },
		-- (drive_wizard stays for a rider: the Drive tab's welcome page has "Set up driving", which opens the wizard)
		{ "drive_wizard", "Drive tab, the crew set-up wizard", function(ctx) drive("wizard")(ctx) end },
		{ "drive_sheet", "Drive tab, the price and place sheet open over the console (a rider has no console)", function(ctx)
			drive("console")(ctx)
			local D = ctx.W.Driver
			log(ctx, "D.ShowSheet sheet")
			if not (D and D.ShowSheet and D.ShowSheet("sheet")) then ctx:cannot("the price sheet did not open") end
			ctx:advance(0.8)
		end, nil, nil, { role = { "rider" } } },
		{ "settings", "Settings, its home list", function(ctx) settingsAt(nil)(ctx) end },
		{ "settings_riding", "Settings > Riding", function(ctx) settingsAt("riding")(ctx) end },
		{ "settings_driving", "Settings > Driving (Warlocks and crews only)", function(ctx) settingsAt("driving")(ctx) end },
		{ "settings_map", "Settings > Map", function(ctx) settingsAt("map")(ctx) end },
		{ "settings_sound", "Settings > Sound and effects", function(ctx) settingsAt("sound")(ctx) end },
		{ "settings_window", "Settings > This window", function(ctx) settingsAt("window")(ctx) end },
		{ "help", "the Help page: finding drivers (/wuber help from Settings)", function(ctx)
			local u = UI(ctx)
			u.Toggle(true) ctx:advance(0.3) settle(ctx)
			log(ctx, "UI.OpenHelp")
			if not (u.OpenHelp and u.OpenHelp()) and not (u.HelpShown and u.HelpShown()) then ctx:cannot("Help did not open") end
			ctx:advance(0.8)
		end },
		{ "bug", "the bug report card (/wuber bug)", function(ctx)
			open(ctx) settle(ctx)
			ctx.me:slash("/wuber bug")
			log(ctx, "/wuber bug")
			ctx:advance(0.8)
		end },
		{ "world_view", "Home with the World map view chosen (saved mapView = world); unfolds where there is room", function(ctx)
			if needOpen(ctx) then settle(ctx) end
		end, function(ctx) if not ctx.facts.firstRun then wdb(ctx).mapView = "world" end end },
		{ "here_view", "Home with the Here map view chosen (saved mapView = here; not on a first run)", function(ctx)
			if needOpen(ctx) then settle(ctx) end
		end, function(ctx) wdb(ctx).mapView = "here" end, nil, { session = { "first" } } },
		{ "confirm", "the Confirm screen for the first driver the phone lists (a driver must be heard)", function(ctx)
			local u = UI(ctx)
			local list = u.Drivers and u.Drivers() or {}
			local d = list[1]
			if not (d and d.key) then ctx:cannot("no driver is listed to confirm") return end
			u.Show("confirm", d.key) ctx:advance(0.3) settle(ctx)
			log(ctx, "UI.Show confirm " .. tostring(d.key))
		end, nil, nil, { net = { "none" } } }, -- (net=none has no driver to book)
		{ "wrapped", "the Wrapped story over Trips (needs rides in an earlier month)", function(ctx)
			local WM = ctx:mod("UI.Rider.Wrapped")
			if not (WM and WM.Months and WM.Open) then ctx:cannot("no Wrapped module") return end
			needOpen(ctx) settle(ctx) clickTab(ctx, "Trips")
			local months = WM.Months()
			-- no rides in an earlier month in the saved data: three rides 35 days old (last month or the one before),
			-- written the way the layout check does (tests/layout/run.lua); a player has these from riding
			if not (type(months) == "table" and months[1]) then
				local W = ctx.W
				local t = ctx.me.env.time() - 35 * 86400
				for i = 1, 3 do
					W.db.rides[#W.db.rides + 1] = { dest = "Ratchet", driver = "Real Driver", price = 5000, at = t + i * 3600, stars = 4 }
				end
				log(ctx, "three rides from 35 days ago added to the saved trips")
				months = WM.Months()
			end
			local m = type(months) == "table" and months[1] or nil
			if not m then ctx:cannot("no month with rides to wrap") return end
			log(ctx, "Wrapped.Open")
			WM.Open(m.year or m[1], m.month or m[2])
			ctx:advance(0.8)
		end, nil, nil, { ride = { "requested", "invited", "summoning", "arrived" } } }, -- (it opens through the Trips tab, which hides on those rides)
	}

	local list = {}
	for _, v in ipairs(VALUES) do
		local id, about, run, pre, quick, excludes = v[1], v[2], v[3], v[4], v[5], v[6]
		local e = { id = id, about = about, apply = wrap(run, quick), pre = pre, excludes = excludes }
		list[#list + 1] = e
	end
	Hunt.dial{
		name = "phone",
		about = "what the phone shows when the check starts: closed, or open on a tab or screen (the way it got there is in the value)",
		phase = 80,
		default = "closed",
		values = list,
	}

	---------------------------------------------------------------------------
	-- Fold
	---------------------------------------------------------------------------
	-- The harness answers "small" to UI.Fold.Fits for a client that is not made with wide = true (old tests run folded:
	-- tests/harness.lua, "Round 8"). The hunt wants the game's own answer, so every value asks for it. (World:reload
	-- keeps it: Ctx:reload copies the login options.)
	local function wide(ctx)
		if type(ctx.clientOpts) ~= "table" then ctx.clientOpts = {} end
		ctx.clientOpts.wide = true
	end
	local PAGES = { "ride", "confirm", "trips", "settings", "console", "raid", "earnings", "messages", "customers" }
	Hunt.dial{
		name = "fold",
		about = "wide pages: Auto (unfold where there is room), folded earlier by the player, Always narrow, or folded by a click now",
		phase = 85,
		default = "unfolded",
		values = {
			{ id = "unfolded", about = "no choice saved: every page that fits unfolds by itself", pre = wide },
			{ id = "folded_saved", about = "the player folded every page with the button earlier (saved fold.pages all closed)",
				excludes = { session = { "first" } },
				pre = function(ctx)
					wide(ctx)
					local pages = {}
					for _, p in ipairs(PAGES) do pages[p] = "closed" end
					wdb(ctx).fold = { v = 1, pages = pages, narrow = false }
				end },
			{ id = "narrow", about = "Settings > This window > Wide pages: Always narrow (saved fold.narrow = true)",
				excludes = { session = { "first" } },
				pre = function(ctx) wide(ctx) wdb(ctx).fold = { v = 1, pages = {}, narrow = true } end },
			{ id = "folded_click", about = "the phone opened unfolded and the player clicks the fold button",
				-- the phone must be open, on a page that unfolds (Fold.lua PAGES: not the splash, Help, the report, the
				-- crew screen, the wizard, a sheet; and never in a fight that began before the phone opened: Fold.lua keeps the width then); the Drive welcome and a window too small say so at run time (cannot)
				excludes = { combat = { "before" }, phone = { "closed", "splash", "trips_direct", "drive_direct", "drive_crew", "drive_wizard", "drive_sheet", "help", "bug" } },
				pre = wide,
				apply = function(ctx)
					local u, s = UI(ctx), st(ctx)
					local F = u and u.Fold
					local btn = s and s.phone and s.phone.fold
					if not (F and btn and F.IsUnfolded and F.IsUnfolded()) then ctx:cannot("this page is not unfolded here: nothing to fold") return end
					ctx.me:clickOn(btn)
					ctx:advance(1)
					log(ctx, "click the fold button")
					facts(ctx)
				end },
		},
	}

	---------------------------------------------------------------------------
	-- Size: the nine layout sizes (tools/layout-check.lua WINDOWS x SCALES; tests/layout/run.lua newClient/sizes)
	---------------------------------------------------------------------------
	local WINDOWS = { { 2662, 2089, 0.7353 }, { 1920, 1080, 1.0 }, { 3840, 2160, 1.0 } }
	local SCALES = { 1, 1.5, 2.2 }
	local sizes = { { id = "std", about = "the harness's own game window and Wuber's own size" } }
	for _, win in ipairs(WINDOWS) do
		for _, sc in ipairs(SCALES) do
			local pw, ph, ui = win[1], win[2], win[3]
			sizes[#sizes + 1] = { id = ("%dx%d@%s"):format(pw, ph, tostring(sc)),
				about = ("game window %dx%d pixels (game UI scale %s), Wuber at size %s"):format(pw, ph, tostring(ui), tostring(sc)),
				pre = function(ctx)
					local unitH = 768 / ui
					local unitW = pw / ph * unitH
					local o = ctx.clientOpts
					o.screenW, o.screenH, o.physW, o.physH = unitW, unitH, pw, ph
					ctx.facts.windowPx = { pw, ph }
					-- a first run ever has no saved size (session = first): the window is the same, Wuber's size the usual
					if ctx.facts.firstRun then return end
					local db = wdb(ctx)
					db.scale = sc
					db.scaleV = 2 -- the migration of 1.0 to 1.15 (UI.MigrateScale) is done: a saved 1.0 stays 1.0
					local b = sub(sub(db, "drive"), "button")
					b.scale, b.sizeSet = sc, true -- DR.SetScale, the big button's size
				end }
		end
	end
	Hunt.dial{
		name = "size",
		about = "the game window and Wuber's sizes: the nine of the layout check (3 windows x 3 Wuber sizes)",
		phase = 80,
		default = "std",
		values = sizes,
	}

	---------------------------------------------------------------------------
	-- Pos
	---------------------------------------------------------------------------
	local function pos(point, rel, x, y) return function(ctx) wdb(ctx).pos = { point, rel, x, y } end end
	local NOT_FIRST = { session = { "first" } } -- a first run ever has no saved place
	-- The real game keeps a window with SetClampedToScreen(true) on the screen: Window.lua asks for it and Phone.lua sets the
	-- clamp rectangle to the handset's outline (the bezel, the status bar above, the home strip below). The fake game does not
	-- clamp, so a saved off-screen place would leave the window, and everything anchored to it, far off screen. This moves the
	-- window (never the saved place) the shortest way that puts the whole outline on screen (centred when it is bigger than the
	-- screen), and does it again whenever the addon places the window afresh in this session. A /reload builds a new window.
	local function clampNow(ctx, win, P, setPoint)
		local kit = ctx:mod("UI.Kit")
		local bz, sb, hm = (kit and kit.BEZEL) or 8, (kit and kit.STATUS_H) or 26, (kit and kit.HOME_H) or 15
		local ws, ps = win:GetEffectiveScale(), P:GetEffectiveScale()
		if not (ws and ps and ps > 0) then return end
		local k = ws / ps
		local l, b, w, h = win:GetRect()
		local sw, sh = P:GetWidth(), P:GetHeight()
		if not (l and b and w and h and sw and sh) then return end
		local cl, cr, cb, ct = l * k - bz * k, (l + w) * k + bz * k, b * k - (hm + bz) * k, (b + h) * k + (sb + bz) * k
		local function shift(lo, hi, size)
			if hi - lo > size then return (size - (hi - lo)) / 2 - lo end
			if lo < 0 then return -lo end
			if hi > size then return size - hi end
			return 0
		end
		local dx, dy = shift(cl, cr, sw), shift(cb, ct, sh)
		if dx == 0 and dy == 0 then return end
		local p, rel, rp, x, y = win:GetPoint(1)
		if not p then return end
		setPoint(win, p, rel, rp, (x or 0) + dx / k, (y or 0) + dy / k)
		return true
	end
	local function clampWindow(ctx)
		local env = ctx.me and ctx.me.env
		local win, P = env and env.WuberFrame, env and env.UIParent
		if not (win and P and win.GetRect and win.SetPoint) then return end
		ctx.facts.clamped = true
		local orig, busy = win.SetPoint, false
		win.SetPoint = function(self, ...)
			orig(self, ...)
			if busy then return end
			busy = true
			pcall(clampNow, ctx, win, P, orig)
			busy = false
		end
		local ok, moved = pcall(clampNow, ctx, win, P, orig)
		-- the big button and its console follow the window within about half a second (Drive/Button.lua watch)
		if ok and moved then ctx:advance(0.8) end
	end
	Hunt.dial{
		name = "pos",
		about = "where the phone was left: nowhere saved, or a corner",
		phase = 80,
		default = "usual",
		values = {
			{ id = "usual", about = "no place saved: the usual one" },
			{ id = "corner", about = "saved at the top left, 20 from the edges", pre = pos("TOPLEFT", "TOPLEFT", 20, -20), excludes = NOT_FIRST },
			{ id = "bottom_right", about = "saved at the bottom right", pre = pos("BOTTOMRIGHT", "BOTTOMRIGHT", -20, 20), excludes = NOT_FIRST },
			-- (removed: value "offscreen", saved far off the screen. The real game pulls such a window back on screen, because
			-- the window is SetClampedToScreen; the fake game cannot: tests/harness.lua:1692 stores SetClampedToScreen and never applies it.
			-- Anything placed BEFORE the dial moved WuberFrame (toasts, the rain check sheet, the Drive button) stayed thousands of pixels
			-- off screen and was reported: 20 findings in the second sweep, all a fake-game gap. Listed in the fake-game gap list.)
		},
	}
end
