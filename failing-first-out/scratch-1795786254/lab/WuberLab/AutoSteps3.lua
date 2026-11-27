-- Wuber Lab (developer only, never ship): more of the Auto check's own screens (job 2603, 23 Nov 2026).
-- The tester (23 Nov, 16:35): "put more in-game checks into the Auto check so my own in-game part gets shorter". The hand steps
-- of the 2.4 run 2 that the real game can answer by itself, now answered here (each result carries the hidden step id of
-- the step it replaces; steps2lua.py --auto leaves a step out of his note only when every result carrying its id passed):
--   a_portal_smooth    GL-03  the Ride page's portal turns smoothly: readings for 3 s, each stretch of 0.3 s or more anticlockwise at
--                             one turn in 8 s plus or minus 35%, none backwards: no jump, no stall, never backwards   (step: "Portal turn")
--   a_back_settings    GL-02  Settings opened from a page, then its back arrow: Settings is gone, the same page is back
--                             with its words, the page under Settings was hidden meanwhile      (step: "does back go back")
--   a_options_page     GL-01  the game's Options > AddOns page "Wuber": its button opens Wuber's Settings, and Wuber's
--                             window then lies above the game's Options window (frame strata and level)
--   a_keybinding       GL-04  the game's Key Bindings list holds "Open or close Wuber"; its words; running what the key runs
--                             opens and closes Wuber                                   (step: "give it a key, press it")
-- What none of them can do (they say so, and the step stays the tester's when a result is skipped or needs a look): press a real
-- key, click with a real mouse, open the game's Options window from addon code (it would risk a blocked action), drag.
-- Same rules as AutoSteps.lua: local only, nothing is sent, WuberDB is put back by the tour's snapshot.
-- tools/steps2lua.py --auto reads the quoted step ids in every Auto*.lua of this folder.

local _, L = ...

local K, P, X = L.PhotoKit, L.PhotoShotKit, L.AutoKit
local str, num = L.str, L.num
local fn = K.fn

local SCREENS = L.AUTO_SCREENS
local function screen(s)
	s.auto = true
	SCREENS[#SCREENS + 1] = s
	return s
end

local TWO_PI = 2 * math.pi
local SEARCH_TEXTS = { "Ask or search: how do I mute sounds?", "Ask or search settings", "Search settings" } -- UI/Settings/Find.lua
local SEARCH_WORDS = "the search placeholder"
local function searchShown(S)
	for _, t in ipairs(SEARCH_TEXTS) do
		if X.find(S, t, true) then return true end
	end
	return false
end

local function tourScreen(id)
	for _, s in ipairs(L.PHOTO_SCREENS or {}) do if s.id == id then return s end end
	return nil
end
local function runOf(id)
	return function(W, view)
		local s = tourScreen(id)
		if not s then return "the tour has no screen " .. id end
		return s.run(W, view)
	end
end
local function data()
	local t = K.tour()
	if not t then return {} end
	t.autoData = t.autoData or {}
	return t.autoData
end
local function clock() return L.Now() end
local function edge(f, name)
	if type(f) ~= "table" or not fn(f, name) then return nil end
	local ok, v = pcall(f[name], f)
	return ok and num(v) or nil
end
local function text(f, name)
	if type(f) ~= "table" or not fn(f, name) then return nil end
	local ok, v = pcall(f[name], f)
	return ok and str(v) or nil
end
local function shown(f)
	if type(f) ~= "table" or not fn(f, "IsShown") then return false end
	local ok, v = pcall(f.IsShown, f)
	return ok and v == true
end
local function uiState(W) return type(W.UI) == "table" and type(W.UI.state) == "table" and W.UI.state or nil end
local function settingsOf(W) return type(W.UI) == "table" and type(W.UI.settings) == "table" and W.UI.settings or nil end
local function foundScreen(W)
	local st = uiState(W)
	return st and type(st.screens) == "table" and type(st.screens.found) == "table" and st.screens.found or nil
end
local function result(name, status, detail, step)
	return { name = name, status = status, detail = detail, steps = step and { step } or nil }
end
-- verify() answers with a LIST of results (a bare result would be read as an empty list)
local function one(...) return { result(...) } end

---------------------------------------------------------------------------
-- GL-03: the portal turns smoothly
---------------------------------------------------------------------------

local SMOOTH_SECS, SMOOTH_TOL, PORTAL_SECS, MIN_SPAN = 3, 0.35, 8, 0.3

screen({ id = "a_portal_smooth", side = "rider", maxWait = 8,
	title = "Ride page: the portal turns smoothly and anticlockwise (readings for 3 seconds: no jump, no stall)",
	run = function(W, view)
		data().smooth = { phase = 0, s = {} }
		return runOf("portal")(W, view)
	end,
	ready = function(W)
		local d = data().smooth
		if not d or d.phase == 2 then return true end
		local h = foundScreen(W)
		local art = type(h) == "table" and type(h.hero) == "table" and type(h.hero.art) == "table" and h.hero.art or nil
		local t = clock()
		if d.phase == 0 then
			if not art or not fn(art, "GetRotation") then
				d.noRot, d.phase = true, 2
				return true
			end
			if type(W.db) == "table" and W.db.reduceMotion then
				d.reduced, d.phase = true, 2
				return true
			end
			d.t0, d.phase = t, 1
		end
		local a = edge(art, "GetRotation")
		if a then d.s[#d.s + 1] = { t = t, a = a } end
		if t - d.t0 >= SMOOTH_SECS then d.phase = 2 return true end
		return false
	end,
	verify = function(W)
		local d = data().smooth
		if not d then return "skip", "the portal screen did not set up" end
		if d.noRot then return one("portal smooth", "skip", "this game gave no portal picture or no Texture:GetRotation: the turn cannot be read", "GL-03") end
		if d.reduced then return one("portal smooth", "skip", "Reduce motion is on, so the portal stands still: run it again with Reduce motion off", "GL-03") end
		local want = TWO_PI / PORTAL_SECS
		local n, bad, worst, worstRate, back = 0, 0, nil, nil, 0
		-- a reading is the turn over a stretch of at least 0.3 s (one frame of timing slack is then under 10%); a reading
		-- that goes backwards at all (more than half a turn forward in one step) is counted on its own
		local i = 1
		for k = 2, #d.s do
			if ((d.s[k].a - d.s[k - 1].a) % TWO_PI) > math.pi then back = back + 1 end
		end
		while i < #d.s do
			local j = i + 1
			while j <= #d.s and d.s[j].t - d.s[i].t < MIN_SPAN do j = j + 1 end
			if j > #d.s then break end
			local dt = d.s[j].t - d.s[i].t
			n = n + 1
			local rate = ((d.s[j].a - d.s[i].a) % TWO_PI) / dt
			local off = math.abs(rate - want) / want
			if off > SMOOTH_TOL then bad = bad + 1 end
			if not worst or off > worst then worst, worstRate = off, rate end
			i = j
		end
		bad = bad + back
		if n < 6 then return one("portal smooth", "skip", ("only %d readings in %d s: too few to judge the turn"):format(n, SMOOTH_SECS), "GL-03") end
		local words = ("%d readings of 0.3 s or more: worst %.3f rad per second (%.0f%% off), %d backwards, wanted %.3f anticlockwise (one turn in %d s) plus or minus %.0f%%"):format(
			n, worstRate, worst * 100, back, want, PORTAL_SECS, SMOOTH_TOL * 100)
		if bad == 0 then return one("portal smooth", "pass", "even, anticlockwise: " .. words, "GL-03") end
		return one("portal smooth", "look", ("fail: %d of %d readings jump, stall or run backwards: %s"):format(bad, n, words), "GL-03")
	end })

---------------------------------------------------------------------------
-- GL-02: Settings, then the back arrow
---------------------------------------------------------------------------

local function wordsOf(S)
	local set, n = {}, 0
	for _, t in ipairs(S.texts or {}) do
		if not t.hidden and type(t.text) == "string" and #t.text > 2 then
			if not set[t.text] then n = n + 1 end
			set[t.text] = true
		end
	end
	return set, n
end
-- (r54 E) the words of the home PAGE only: a word counts when its text sits inside the page's own frame. The clock and the tab
-- labels are the window's chrome, drawn over Settings by design, and are not "the page showing through".
local function insideOf(obj, frame)
	local p, n = obj, 0
	while type(p) == "table" and n < 40 do
		if p == frame then return true end
		local ok, up = pcall(p.GetParent, p)
		p, n = ok and up or nil, n + 1
	end
	return false
end
local function pageWordsOf(S, frame)
	local set = {}
	for _, t in ipairs(S.texts or {}) do
		if not t.hidden and type(t.text) == "string" and #t.text > 2 and (not frame or insideOf(t.obj, frame)) then set[t.text] = true end
	end
	return set
end
local function leftWords(from, set)
	local out = {}
	for w in pairs(from) do if set[w] then out[#out + 1] = w end end
	table.sort(out)
	return table.concat(out, " | ")
end
local function shareOf(from, set)
	local n, have = 0, 0
	for w in pairs(from) do
		n = n + 1
		if set[w] then have = have + 1 end
	end
	return n > 0 and have / n or 0, n
end

screen({ id = "a_back_settings", side = "rider", maxWait = 6,
	title = "Home, then Settings, then its back arrow: Home is back with its words and nothing of Settings is left on top",
	run = function(W, view)
		data().back = { phase = 0 }
		return runOf("home")(W, view)
	end,
	ready = function(W)
		local d = data().back
		if not d or d.phase == 3 then return true end
		local ui, UI, t = uiState(W), W.UI, clock()
		if d.phase == 0 then
			local st = settingsOf(W)
			if not (ui and st and type(st.back) == "table" and type(UI.OpenSettings) == "function" and type(UI.SettingsShown) == "function") then
				d.noApi, d.phase = true, 3
				return true
			end
			d.screen = ui.screen
			local home = ui.screens and type(ui.screens.home) == "table" and ui.screens.home.frame or nil
			d.homeFrame = type(home) == "table" and home or nil
			d.homeWords = pageWordsOf(X.scan(W), d.homeFrame)
			local ok, err = pcall(UI.OpenSettings)
			d.openErr = (not ok) and tostring(err) or nil
			d.at, d.phase = t, 1
			return false
		elseif d.phase == 1 then
			if t - d.at < 0.8 then return false end
			local openScan = pageWordsOf(X.scan(W), d.homeFrame)
			d.open = { shown = UI.SettingsShown() == true, flag = ui.settingsOpen == true, share = shareOf(d.homeWords, openScan), left = leftWords(d.homeWords, openScan) }
			d.pressed, d.err = X.press(settingsOf(W).back)
			d.at, d.phase = t, 2
			return false
		end
		if t - d.at < 0.8 then return false end
		local S = X.scan(W)
		local _, _ = wordsOf(S)
		d.after = { shown = UI.SettingsShown() == true, flag = ui.settingsOpen == true, screen = ui.screen,
			share = shareOf(d.homeWords, (wordsOf(S))), leftOver = searchShown(S) }
		d.phase = 3
		return true
	end,
	verify = function(W)
		local d = data().back
		if not d then return "skip", "the back screen did not set up" end
		if d.noApi then return one("back arrow", "skip", "this Wuber has no Settings back arrow or no UI.SettingsShown the check knows", "GL-02") end
		if d.openErr then return one("back arrow", "look", "fail: opening Settings broke: " .. d.openErr, "GL-02") end
		local out = {}
		local o, a = d.open or {}, d.after or {}
		if o.shown and o.flag then
			out[#out + 1] = result("settings open", "pass", "Settings showed over the page")
			if o.share <= 0.5 then
				out[#out + 1] = result("page under settings hidden", "pass", ("only %.0f%% of the page's words were still drawn under Settings"):format(o.share * 100))
			else
				out[#out + 1] = result("page under settings hidden", "look", ("fail: %.0f%% of the page's own words are still drawn while Settings shows: %s"):format(o.share * 100, (o.left or ""):sub(1, 200)))
			end
		else
			out[#out + 1] = result("settings open", "look", "fail: Settings did not show (shown " .. tostring(o.shown) .. ", flag " .. tostring(o.flag) .. ")")
		end
		if not d.pressed then
			out[#out + 1] = result("back arrow", "look", "fail: the back arrow's click broke: " .. tostring(d.err), "GL-02")
		elseif a.shown or a.flag then
			out[#out + 1] = result("back arrow", "look", ("fail: after the back arrow Settings is still there (shown %s, flag %s)"):format(tostring(a.shown), tostring(a.flag)), "GL-02")
		elseif a.leftOver then
			out[#out + 1] = result("back arrow", "look", 'fail: after the back arrow "' .. SEARCH_WORDS .. '" is still drawn: something of Settings is left on top', "GL-02")
		elseif a.screen ~= d.screen then
			out[#out + 1] = result("back arrow", "look", ("fail: the page before was %s, after the back arrow it is %s"):format(tostring(d.screen), tostring(a.screen)), "GL-02")
		elseif a.share < 0.8 then
			out[#out + 1] = result("back arrow", "look", ("fail: only %.0f%% of the page's words are back after the back arrow"):format(a.share * 100), "GL-02")
		else
			out[#out + 1] = result("back arrow", "pass", ("back on %s, %.0f%% of its words drawn, no Settings left"):format(tostring(a.screen), a.share * 100), "GL-02")
		end
		return out
	end })

---------------------------------------------------------------------------
-- GL-01: the game's Options > AddOns page
---------------------------------------------------------------------------

local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

screen({ id = "a_options_page", side = "rider", maxWait = 4,
	title = 'The game\'s Options > AddOns page "Wuber": its button opens Wuber\'s Settings, above the game\'s Options window',
	run = runOf("home"),
	post = function(W)
		local d = data()
		d.opt = {}
		local o = d.opt
		local page = rawget(_G, "WuberOptionsPage")
		if type(page) ~= "table" then o.none = true return true end
		o.name = page.name
		local btn = page.openBtn
		if type(btn) ~= "table" then o.noBtn = true return true end
		local ui, UI = uiState(W), W.UI
		local win = ui and ui.win
		local sp = rawget(_G, "SettingsPanel") or rawget(_G, "InterfaceOptionsFrame")
		o.spName = type(sp) == "table" and (sp.GetName and text(sp, "GetName")) or nil
		o.spShown = shown(sp)
		o.pressed, o.err = X.press(btn)
		o.settings = type(UI.SettingsShown) == "function" and UI.SettingsShown() == true
		o.win = shown(win)
		if type(sp) == "table" and type(win) == "table" then
			o.spStrata, o.winStrata = text(sp, "GetFrameStrata"), text(win, "GetFrameStrata")
			o.spLevel, o.winLevel = edge(sp, "GetFrameLevel"), edge(win, "GetFrameLevel")
		end
		-- put back: Settings away at once, and the flag that says "opened over Options"
		if ui then ui.overOptions = false end
		if type(UI.CloseSettings) == "function" then pcall(UI.CloseSettings, true) end
		return true
	end,
	verify = function(W)
		local o = data().opt
		if not o then return "skip", "the options screen did not set up" end
		if o.none then return one("options page", "skip", "this game has no Options page of Wuber's (no Settings API at login), so there is nothing to press", "GL-01") end
		if o.noBtn then return one("options page", "look", "fail: Wuber's Options page has no open button", "GL-01") end
		local out = {}
		if not o.pressed then
			return one("options page", "look", "fail: the button's click broke: " .. tostring(o.err), "GL-01")
		end
		if o.settings and o.win then
			out[#out + 1] = result("options button opens settings", "pass", ('the page "%s" button opened Wuber\'s window on Settings'):format(tostring(o.name)))
		else
			return one("options button opens settings", "look", ("fail: after the button Settings shown %s, Wuber's window shown %s"):format(tostring(o.settings), tostring(o.win)), "GL-01")
		end
		local rs, rw = STRATA[o.spStrata or ""], STRATA[o.winStrata or ""]
		if not (rs and rw) then
			out[#out + 1] = result("above the game's Options", "skip", "no game Options window to compare with (SettingsPanel): the step stays yours", "GL-01")
		elseif rw > rs or (rw == rs and (o.winLevel or 0) > (o.spLevel or 0)) then
			out[#out + 1] = result("above the game's Options", "pass", ("Wuber's window is on %s level %s, the game's Options on %s level %s%s"):format(
				o.winStrata, tostring(o.winLevel), o.spStrata, tostring(o.spLevel), o.spShown and "" or " (the Options window was not open: the order is read from the frames)"), "GL-01")
		else
			out[#out + 1] = result("above the game's Options", "look", ("fail: Wuber's window (%s, level %s) is not above the game's Options (%s, level %s)"):format(
				o.winStrata, tostring(o.winLevel), o.spStrata, tostring(o.spLevel)), "GL-01")
		end
		return out
	end })

---------------------------------------------------------------------------
-- GL-04: the key binding "Open or close Wuber"
---------------------------------------------------------------------------

screen({ id = "a_keybinding", side = "rider", maxWait = 6,
	title = 'Key Bindings: "Open or close Wuber" is in the game\'s list and what its key runs opens and closes Wuber',
	run = runOf("home"),
	ready = function(W)
		local d = data().keys
		local ui, t = uiState(W), clock()
		if not d then
			d = { phase = 0 }
			data().keys = d
		end
		if d.phase == 3 then return true end
		local win = ui and ui.win
		local slash = type(rawget(_G, "SlashCmdList")) == "table" and rawget(_G, "SlashCmdList")["WUBER"] or nil
		if d.phase == 0 then
			if type(slash) ~= "function" or type(win) ~= "table" then d.noSlash, d.phase = true, 3 return true end
			d.before = shown(win)
			d.err1 = select(2, pcall(slash, "")) -- what the binding runs: the /wuber handler with no words
			d.at, d.phase = t, 1
			return false
		elseif d.phase == 1 then
			if t - d.at < 0.7 then return false end
			d.one = shown(win)
			d.err2 = select(2, pcall(slash, ""))
			d.at, d.phase = t, 2
			return false
		end
		if t - d.at < 2.6 then return false end -- the floating big button re-places itself up to 2 s after the window moves (Drive/Button.lua)
		d.two = shown(win)
		d.phase = 3
		return true
	end,
	verify = function(W)
		local d = data().keys or {}
		local out = {}
		local gnb, gb = rawget(_G, "GetNumBindings"), rawget(_G, "GetBinding")
		if type(gnb) ~= "function" or type(gb) ~= "function" then
			out[#out + 1] = result("binding listed", "skip", "this game has no GetNumBindings / GetBinding to read the Key Bindings list with", "GL-04")
		else
			local found, keys
			local okN, n = pcall(gnb)
			for i = 1, okN and num(n) or 0 do
				local r = { pcall(gb, i) }
				if r[1] and r[2] == "WUBER_TOGGLE" then
					found, keys = true, {}
					for j = 4, #r do if type(r[j]) == "string" and r[j] ~= "" then keys[#keys + 1] = r[j] end end
					break
				end
			end
			if found then
				out[#out + 1] = result("binding listed", "pass", "the game's list holds WUBER_TOGGLE" .. (#keys > 0 and (" (bound to " .. table.concat(keys, ", ") .. ")") or " (no key yet)"), "GL-04")
			else
				out[#out + 1] = result("binding listed", "look", "fail: the game's Key Bindings list has no WUBER_TOGGLE (Bindings.xml not loaded: a new file needs a full game restart)", "GL-04")
			end
		end
		local nm, hd = rawget(_G, "BINDING_NAME_WUBER_TOGGLE"), rawget(_G, "BINDING_HEADER_WUBER")
		if nm == "Open or close Wuber" and hd == "Wuber" then
			out[#out + 1] = result("binding words", "pass", 'the list says "Wuber" > "Open or close Wuber"', "GL-04")
		else
			out[#out + 1] = result("binding words", "look", ("fail: the list says %q > %q"):format(tostring(hd), tostring(nm)), "GL-04")
		end
		if d.noSlash then
			out[#out + 1] = result("binding runs", "skip", "no /wuber handler or no window to run the key's action on", "GL-04")
		elseif d.err1 or d.err2 then
			out[#out + 1] = result("binding runs", "look", "fail: what the key runs broke: " .. tostring(d.err1 or d.err2), "GL-04")
		elseif d.one ~= d.before and d.two == d.before then
			out[#out + 1] = result("binding runs", "pass", ("run once the window %s, run again it %s"):format(d.one and "opened" or "closed", d.two and "opened" or "closed"), "GL-04")
		else
			out[#out + 1] = result("binding runs", "look", ("fail: the window was %s, after the key's action %s, after it again %s"):format(
				tostring(d.before), tostring(d.one), tostring(d.two)), "GL-04")
		end
		return out
	end })
