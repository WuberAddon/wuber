-- tests/layout/routes.lua: the layout checker's ROUTE WALKS (job 211, group D; tools/layout-check.lua hooks it in).
-- The photo tour shows each screen on its own; the bugs of in-game run 1 (items 1, 2, 12.1, 12.2) were in the MOVES
-- between pages: Settings drawn over a leftover Trips page, the back chevron covered, Settings clipped when the window
-- folds. A route walk drives the fake game through the real buttons (tab bar tabs, the cog, the Settings back chevron,
-- Options > AddOns > "Open Wuber settings" through the fake Options window, the fold button, the ride page's back chevron
-- and black pill, the driver's button and console) and after EVERY step checks:
--   pages    exactly one page shown (a tab body, Settings, or one screen of the Ride tab): none left showing under another
--   head     the page's back control and title are visible, inside the window and the screen, and nothing is drawn over the
--            back chevron (tests/lib/topmost.lua: any frame that takes the mouse above its centre)
--   click    a real click on the control lands on it
--   <kind>   the normal layout kinds (cut, overlap, under, boxes, clipped, outside, spill, offscreen, chrome ...) on that state,
--            with tests/layout/allow.lua applied (the shot is named like the tour screen it looks like)
-- Every problem is printed as "route | <window@size> | <route> step N <what> | <kind>: <detail>" and counts as a route problem.
--   Routes.main(ctx) -> exit code (0 clean, 1 problems, 2 could not run), prints the lines and a "routes:" summary on stderr.
--     ctx = { root, lua, script, wuber, lab, jobs }; sets Routes.bad (the count of route problems) for tools/layout-check.lua.
--   Routes.child(ctx) -> text: runs the walks in this process (needs the harness; the checker's --routes-child).
-- Tests may call Routes.walk(H, E, root, cfg) -> { problems = { { route, step, kind, detail, allowed } }, steps, errors }.
local Routes = { bad = 0 }

local CONFIGS = { "1920x1080@1", "2662x2089@1" }
local WINDOWS = { ["2662x2089"] = 0.7353 }

local function parseConfig(s)
	local w, h, sc = tostring(s):match("^(%d+)x(%d+)@([%d.]+)$")
	w, h, sc = tonumber(w), tonumber(h), tonumber(sc)
	return { w = w, h = h, ui = WINDOWS[w .. "x" .. h] or 1.0, scale = sc, id = s }
end

---------------------------------------------------------------------------
-- The walk (in the fake game)
---------------------------------------------------------------------------

function Routes.walk(H, E, root, cfg)
	local out = { problems = {}, steps = 0, errors = {} }
	local TL = dofile(root .. "/tools/preview/textlayout.lua")
	local okT, TOP = pcall(dofile, root .. "/tests/lib/topmost.lua")
	if not okT then TOP = nil end
	local ALLOW = dofile(root .. "/tests/layout/allow.lua")
	local function allowed(shot, h)
		for _, a in ipairs(ALLOW) do
			if (not a.kind or a.kind == h.kind) and (not a.screen or shot:find(a.screen)) and (not a.key or h.key:find(a.key))
				and (not a.what or h.what:find(a.what)) and (not a.detail or h.detail:find(a.detail)) then
				return a.reason or a.known or "allowed"
			end
		end
	end
	local unitH = 768 / cfg.ui
	local unitW = cfg.w / cfg.h * unitH
	H.textMetrics = TL
	TL.PX = cfg.h / unitH
	TL.SNAP, TL.SIZE_SNAP = "round", "round"
	TL.STRETCH = 1

	-- a rider (or driver) with the window at this size; Simple, the way everyone starts
	local function client(spec)
		local w = H.NewWorld({})
		w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
		local c = w:addClient(spec.name or "Wuber TestCharacter", { spot = spec.spot or "Orgrimmar", class = spec.class or "MAGE", money = 100000,
			screenW = unitW, screenH = unitH, physW = cfg.w, physH = cfg.h, simple = true, saved = spec.saved, prepare = spec.prepare,
			addons = { "Wuber" } })
		w:advance(15)
		c.W.db.scale = cfg.scale
		pcall(c.W.UI.ApplyScale)
		return w, c
	end

	local function walkRoute(name, spec, fn)
		local w, c = client(spec)
		local UI, ui = c.W.UI, c.W.UI.state
		local R = { w = w, c = c, UI = UI, ui = ui, n = 0, name = name }
		local errs0 = #w.errors
		local seen = {}
		local function problem(kind, detail, key, shot)
			local k = R.n .. "|" .. kind .. "|" .. (key or detail)
			if seen[k] then return end
			seen[k] = true
			local h = { kind = kind, what = key or "", detail = detail, key = key or detail }
			out.problems[#out.problems + 1] = { route = name, step = R.n, desc = R.desc, kind = kind, detail = detail,
				allowed = shot and kind ~= "route" and allowed(shot, h) or nil }
		end
		R.problem = problem
		local function inside(r, outer, slop)
			return r and outer and r.l >= outer.l - slop and r.b >= outer.b - slop and r.l + r.w <= outer.l + outer.w + slop and r.b + r.h <= outer.b + outer.h + slop
		end
		-- the pages that show now: tab bodies, Settings, and the Ride tab's screens
		function R.pages()
			local list = {}
			for _, tab in ipairs(ui.tabs or {}) do
				if tab.body and H.visible(tab.body) then
					local label = "tab:" .. tab.name
					if tab.name == "Ride" then
						for sname, scr in pairs(ui.screens or {}) do
							if scr.frame and H.visible(scr.frame) then list[#list + 1] = label .. "/" .. sname end
						end
						if not list[#list] or not list[#list]:find("^" .. label) then list[#list + 1] = label .. "/none" end
					else
						list[#list + 1] = label
					end
				end
			end
			if UI.SettingsShown and UI.SettingsShown() then list[#list + 1] = "settings" end
			table.sort(list)
			return list
		end
		-- the harness does not clip mouse hits (or topmost.lua's cover test) to a SetClipsChildren view; the game does: a frame
		-- whose whole spot at (x, y) is outside a clipping ancestor's rect is not there
		local function clippedAt(f, x, y)
			local p = H.state[f] and H.state[f].parent
			while p do
				if p.DoesClipChildren and p:DoesClipChildren() then
					local r = H.rect(p)
					if r and (x < r.l or x > r.l + r.w or y < r.b or y > r.b + r.h) then return true end
				end
				p = H.state[p] and H.state[p].parent
			end
			return false
		end
		-- step(desc, want, shot): want = "settings" | "tab:Trips" | "tab:Ride/found" ...; shot = the tour screen it looks like
		function R.step(desc, want, shot, opt)
			opt = opt or {}
			R.n = R.n + 1
			out.steps = out.steps + 1
			R.desc = desc
			w:advance(1.2)
			local sh = (shot or "route") .. "/" .. (c.W.UI.Fold and c.W.UI.Fold.IsUnfolded and c.W.UI.Fold.IsUnfolded() and "unfolded" or "folded")
			local pages = R.pages()
			if want then
				if #pages ~= 1 or pages[1] ~= want then
					problem("route", ("expected only {%s}, got {%s}"):format(want, table.concat(pages, ", ")), "pages", sh)
				end
			end
			-- the head: back control and title
			local win = H.rect(ui.win)
			local screenR = { l = 0, b = 0, w = unitW, h = unitH }
			local function control(label, f)
				if not f then problem("route", label .. " does not exist", "head " .. label, sh) return end
				if not H.visible(f) then problem("route", label .. " is not visible", "head " .. label, sh) return end
				local r = H.rect(f)
				if not inside(r, screenR, 1) then problem("route", label .. " is off the screen", "head " .. label, sh) end
				if not inside(r, win, 1) then problem("route", label .. " is cut by the window's edge", "head " .. label, sh) end
			end
			local back = opt.back
			if want == "settings" then
				local st = c.W.Mod("UI.Settings.Rows").st
				back = st.back
				control("the Settings back chevron", st.back)
				control("the Settings title", st.title)
				if st.title and H.visible(st.title) and (st.title:GetText() or "") == "" then problem("route", "the Settings title is empty", "head title", sh) end
			elseif want and want:find("^tab:Ride/found") then
				back = ui.screens.found and ui.screens.found.back
				control("the ride page back chevron", back)
			end
			if want and not want:find("settings") and not (want:find("found")) then
				if UI.TabsHidden and UI.TabsHidden() then problem("route", "the tab bar is hidden on a page that has it", "tabs", sh) end
			end
			if back and TOP and H.visible(back) then
				local res = TOP.checkButton(H, c, back, { mouseOnly = true })
				if not res.ok and res.blockers then
					local real = false
					for _, b in ipairs(res.blockers) do if not clippedAt(b.frame, res.cx, res.cy) then real = true end end
					if not real then res = { ok = true } end
				end
				if not res.ok then problem("route", "the back chevron is covered: " .. tostring(res.reason) .. " (made at " .. (function()
					local chain, f = {}, res.topBlocker
					for _ = 1, 6 do
						local s = f and H.state[f]
						if not s then break end
						chain[#chain + 1] = tostring(s.lcSrc or s.name) .. (s.rect and "" or "")
						f = s.parent
					end
					return table.concat(chain, " < ")
				end)() .. ")", "covered", sh) end
			end
			-- the normal layout kinds on this state
			local ok, hits = pcall(E.check, c, { TL = TL })
			if not ok then problem("route", "the checker threw: " .. tostring(hits), "checker")
			else
				for _, h in ipairs(hits) do
					local a = allowed(sh, h)
					out.problems[#out.problems + 1] = { route = name, step = R.n, desc = desc, kind = h.kind,
						detail = ("%s | %s"):format(h.what, h.detail), allowed = a, key = h.key }
				end
			end
		end
		-- a real click on a control: it must land on it
		function R.click(label, f)
			if not f then problem("route", "no " .. label .. " to click", "click " .. label) return false end
			local hit = c:clickOn(f)
			if hit ~= f and hit then
				local r = H.rect(f)
				if r and clippedAt(hit, r.l + r.w / 2, r.b + r.h / 2) then f:Click() hit = f end -- (see clippedAt)
			end
			if hit ~= f then problem("route", ("the click on %s did not land on it"):format(label), "click " .. label) return false end
			return true
		end
		local okRun, err = pcall(fn, R)
		if not okRun then problem("route", "the walk stopped: " .. tostring(err):gsub("[\r\n]+", " / "), "walk") end
		for i = errs0 + 1, #w.errors do out.errors[#out.errors + 1] = name .. ": " .. tostring(w.errors[i]):match("^[^\n]*") end
	end

	local function openApp(R)
		R.UI.Toggle(true)
		R.w:advance(3)
	end
	local function tabButton(R, name)
		for _, tab in ipairs(R.ui.tabs) do if tab.name == name then return tab.button end end
	end
	local function ride(R, t)
		local c, w = R.c, R.w
		local base = { id = "route", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = "accepted",
			at = c.env.GetTime(), service = "Bea's Rides" }
		for k, v in pairs(t or {}) do base[k] = v end
		c.W.ride = base
		c.W.Fire("RIDE")
		c.W.UI.RefreshNow()
		w:advance(2)
	end

	-- run 1 item 2 / 12.1: Trips, the cog, Settings, the back chevron, and again; the cog closes it as well
	walkRoute("trips-settings", {}, function(R)
		openApp(R)
		R.step("window opens on the Ride page", "tab:Ride/home", "home")
		R.click("the Trips tab", tabButton(R, "Trips"))
		R.step("Trips tab", "tab:Trips", "trips")
		R.click("the cog", R.ui.gear)
		R.step("Trips -> cog -> Settings", "settings", "settings")
		R.click("the Settings back chevron", R.c.W.Mod("UI.Settings.Rows").st.back)
		R.step("Settings -> back chevron: Trips again", "tab:Trips", "trips")
		R.click("the cog", R.ui.gear)
		R.step("Trips -> cog -> Settings again", "settings", "settings")
		R.click("the Settings back chevron", R.c.W.Mod("UI.Settings.Rows").st.back)
		R.step("Settings -> back chevron: Trips (second time)", "tab:Trips", "trips")
		R.click("the Ride tab", tabButton(R, "Ride"))
		R.step("Ride tab", "tab:Ride/home", "home")
	end)

	-- run 1 item 1: Options > AddOns > Wuber > "Open Wuber settings" (the game's Options window up, Wuber left on Trips)
	walkRoute("options-open", { prepare = function(env, client)
		H.fakeOptionsList(env, client, "new")
		local p = env.CreateFrame("Frame", "SettingsPanel", env.UIParent)
		p:SetFrameStrata("DIALOG")
		p:SetAllPoints(env.UIParent)
		p:EnableMouse(true)
		p:Hide()
	end }, function(R)
		local c, w = R.c, R.w
		openApp(R)
		R.UI.SelectTab("Trips")
		R.step("Trips tab (left like this)", "tab:Trips", "trips")
		R.UI.Toggle(false)
		w:advance(1)
		local cat = c.settingsCats and c.settingsCats[1]
		if not (cat and cat.frame) then error("the Wuber Options category is not registered") end
		c.env.SettingsPanel:Show()
		cat.frame:Show()
		cat.frame.openBtn:Click()
		R.step("Options > AddOns > Wuber > Open Wuber settings", "settings", "settings")
		R.click("the Settings back chevron (over the game's Options window)", c.W.Mod("UI.Settings.Rows").st.back)
		R.step("back chevron: Wuber stays on Trips", "tab:Trips", "trips")
		R.click("the cog", R.ui.gear)
		R.step("the cog: Settings again", "settings", "settings")
	end)

	-- run 1 item 12.2: Settings when the window unfolds and folds (wide and narrow), the fold button
	walkRoute("fold-settings", {}, function(R)
		openApp(R)
		local Fold = R.UI.Fold
		local btn = R.ui.phone and R.ui.phone.fold
		local function toggle(desc)
			if not btn or not H.visible(btn) then return false end
			R.click("the fold button", btn)
			R.w:advance(1)
			return true
		end
		if not Fold.IsUnfolded() then toggle() end
		if not Fold.IsUnfolded() then return end -- this window size does not unfold: nothing to walk
		R.step("Ride page, unfolded", "tab:Ride/home", "home")
		R.click("the cog", R.ui.gear)
		R.step("unfolded Settings", "settings", "settings")
		toggle()
		R.step("Settings folded (fold button)", "settings", "settings")
		toggle()
		R.step("Settings unfolded again", "settings", "settings")
		R.click("the Settings back chevron", R.c.W.Mod("UI.Settings.Rows").st.back)
		R.step("back out of unfolded Settings", "tab:Ride/home", "home")
		R.click("the Trips tab", tabButton(R, "Trips"))
		R.step("Trips, unfolded", "tab:Trips", "trips")
		toggle()
		R.step("Trips folded", "tab:Trips", "trips")
	end)

	-- the ride page: back chevron to Home with the tabs, the black pill back in, other tabs and Settings over it
	walkRoute("ride-pill", {}, function(R)
		openApp(R)
		ride(R, { state = "ingroup" })
		R.step("a live ride: the ride page", "tab:Ride/found", "tracker")
		R.click("the ride page back chevron", R.ui.screens.found and R.ui.screens.found.back)
		R.step("ride back chevron: Home with the tabs", "tab:Ride/home", "home")
		R.click("the black pill", R.ui.phone and R.ui.phone.island)
		R.step("the pill: the ride page again", "tab:Ride/found", "tracker")
		R.UI.OpenSettings() -- (the ride page has no cog: the tabs are away)
		R.step("ride page -> Settings (UI.OpenSettings)", "settings", "settings")
		R.click("the Settings back chevron", R.c.W.Mod("UI.Settings.Rows").st.back)
		R.step("Settings -> back: the ride page", "tab:Ride/found", "tracker")
		R.UI.SelectTab("Trips")
		R.step("Trips during a ride", "tab:Trips", "trips")
		R.click("the black pill", R.ui.phone and R.ui.phone.island)
		R.step("the pill from Trips: the ride page", "tab:Ride/found", "tracker")
	end)

	-- the first-open coach mark and the login tip are up when Settings opens (their cards sit above the window)
	walkRoute("coach-settings", { saved = { Wuber = { coach = true } } }, function(R)
		local c, w = R.c, R.w
		R.UI.Toggle(true)
		for _ = 1, 400 do
			if R.ui.coach and R.ui.coaching then break end
			w:advance(0.05)
		end
		R.step("first open (coach mark up)", nil, "home")
		R.UI.OpenSettings()
		R.step("Settings with the coach in play", "settings", "settings")
		R.click("the Settings back chevron", c.W.Mod("UI.Settings.Rows").st.back)
		R.step("back out of Settings", nil, "home")
	end)

	-- the driver: online (the floating button and its console), the window open on Drive, Settings, closed again
	walkRoute("driver-console", { name = "Anita Lift", class = "WARLOCK", spot = "Orgrimmar" }, function(R)
		local c, w = R.c, R.w
		if not (c.W.Driver and c.W.Driver.SetOnline) then error("no W.Driver.SetOnline") end
		c.W.Driver.SetOnline(true)
		w:advance(2)
		w:advance(8) -- (the "you are online" toast has gone)
		R.step("online, window closed: the button and its console", nil, "float_")
		R.UI.Toggle(true)
		w:advance(2)
		R.UI.SelectTab("Drive")
		R.step("window open on the Drive tab", "tab:Drive", "earnings")
		R.click("the cog", R.ui.gear)
		R.step("Drive -> cog -> Settings", "settings", "settings")
		R.click("the Settings back chevron", c.W.Mod("UI.Settings.Rows").st.back)
		w:advance(1)
		if R.UI.SettingsShown() then -- (Settings opened on a section: the first Back is to Settings' own home)
			R.step("Settings section -> back: Settings home", "settings", "settings")
			R.click("the Settings back chevron", c.W.Mod("UI.Settings.Rows").st.back)
		end
		R.step("Settings -> back: Drive", "tab:Drive", "earnings")
		R.UI.Toggle(false)
		R.step("window closed again: the button and its console", nil, "float_")
	end)

	return out
end

---------------------------------------------------------------------------
-- The child: the walks at each window, as lines
---------------------------------------------------------------------------

function Routes.child(ctx)
	arg = { [0] = ctx.root .. "/tests/run.lua" }
	local H = require("harness")
	if ctx.wuber then H.ADDONS.Wuber = ctx.wuber:gsub("\\", "/") end
	local E = assert(loadfile(ctx.root .. "/tests/layout/engine.lua"))(H)
	-- (every widget knows which addon's code made it: the engine only checks Wuber's)
	E.tag({ Wuber = H.ADDONS.Wuber })
	local lines = {}
	for _, text in ipairs(ctx.configs or CONFIGS) do
		local cfg = parseConfig(text)
		local ok, res = pcall(Routes.walk, H, E, ctx.root, cfg)
		if not ok then lines[#lines + 1] = "RERR\t" .. text .. "\t" .. tostring(res):gsub("[\r\n]+", " / ")
		else
			for _, p in ipairs(res.problems) do
				lines[#lines + 1] = table.concat({ "ROUTE", text, p.route, tostring(p.step), p.desc or "", p.kind, (p.detail or ""):gsub("[\r\t\n]+", " "), p.allowed or "" }, "\t")
			end
			for _, e in ipairs(res.errors) do lines[#lines + 1] = "RERR\t" .. text .. "\t" .. e:gsub("[\r\t\n]+", " ") end
			lines[#lines + 1] = "RSTEPS\t" .. text .. "\t" .. res.steps
		end
	end
	return table.concat(lines, "\n") .. "\nRDONE\n"
end

---------------------------------------------------------------------------
-- The parent: one child process, its lines merged and printed
---------------------------------------------------------------------------

function Routes.main(ctx)
	local function q(s) s = tostring(s):gsub("\\", "/") if s:find("[%s\"]") then return '"' .. s .. '"' end return s end
	local parts = { q(ctx.lua), q(ctx.script), "--routes-child" }
	if ctx.wuber then parts[#parts + 1] = "--wuber" parts[#parts + 1] = q(ctx.wuber) end
	parts[#parts + 1] = "--lab" parts[#parts + 1] = q(ctx.lab)
	local cmd = table.concat(parts, " ") .. " 2>&1"
	if package.config:sub(1, 1) == "\\" and cmd:find('"', 1, true) then cmd = '"' .. cmd .. '"' end
	local p = io.popen(cmd, "r")
	if not p then io.stderr:write("layout-check: could not start the route walks\n") return 2 end
	local text = p:read("*a") or ""
	p:close()
	local seen, bad, steps, errors, done = {}, 0, 0, {}, false
	for line in text:gmatch("[^\r\n]+") do
		local f = {}
		for x in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = x end
		if f[1] == "ROUTE" then
			local cfg, route, step, desc, kind, detail, allowed = f[2], f[3], f[4], f[5], f[6], f[7], f[8] or ""
			if allowed == "" then
				local k = route .. "|" .. step .. "|" .. kind .. "|" .. detail
				if not seen[k] then
					seen[k] = { cfgs = {} }
					bad = bad + 1
					print(("route | %s | %s step %s %s | %s: %s"):format(cfg, route, step, desc, kind, detail))
				end
			end
		elseif f[1] == "RSTEPS" then steps = steps + (tonumber(f[3]) or 0)
		elseif f[1] == "RERR" then errors[#errors + 1] = (f[2] or "") .. ": " .. (f[3] or "")
		elseif f[1] == "RDONE" then done = true
		elseif line ~= "" then errors[#errors + 1] = "route child said: " .. line end
	end
	if not done then errors[#errors + 1] = "the route walks did not finish" end
	for _, e in ipairs(errors) do io.stderr:write("layout-check: routes: " .. e .. "\n") end
	io.stderr:write(("layout-check: routes: %d steps, %d route problems\n"):format(steps, bad))
	Routes.bad = bad
	Routes.steps = steps
	if #errors > 0 or steps == 0 then return 2 end
	return bad > 0 and 1 or 0
end

return Routes
