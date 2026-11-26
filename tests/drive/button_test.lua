-- Tests of Drive.Button (round 9: S3, the big Drive card's accent line). Loaded by tests/run.lua
-- with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- a Warlock driver with the window on the Drive tab (the button docked in the hero card)
local function setup()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	W.UI.Toggle(true)
	w:advance(2)
	W.UI.SelectTab("Drive")
	w:advance(2)
	return w, d, W, d.env.WuberDriveButton
end

-- the accent textures of the button that show
local function lit(b)
	local out = {}
	for _, t in ipairs(b.accent or {}) do
		if t:IsVisible() then out[#out + 1] = t end
	end
	return out
end

test("Drive.Button: contract (registered, deps, header, public names)", function()
	local W, w = T.contract("Drive.Button", "tests/drive/button_test.lua", {
		["DR.Button"] = "table", ["DR.BuildButton"] = "function", ["DR.Scale"] = "function", ["DR.SetScale"] = "function",
		["DR.SkipTarget"] = "function", ["DR.Skip"] = "function",
	})
	T.clean(w)
end)

test("Drive.Button S3: no accent stroke while closed; a clean full-width bottom line while a click is due", function()
	local w, d, W, b = setup()
	ok(b, "WuberDriveButton exists")
	local DR = W.Drive
	DR.Button.Refresh()
	w:advance(1)
	eq(#lit(b), 0, "closed: no accent stroke (it drew a half border)")
	-- something to click: the plan lights the line
	local real = DR.Plan
	DR.Plan = function()
		return { marks = {}, color = "go", title = "Summon Dan", sub = "he is in your group", doing = {}, says = {}, lines = 0 }
	end
	DR.Button.Refresh()
	w:advance(0.2)
	local on = lit(b)
	eq(#on, 1, "a click is due: one line")
	local r, br = H.rect(on[1]), H.rect(b)
	ok(r.h <= 4, "a line, not a stroke round the card (" .. r.h .. " high)")
	ok(math.abs(r.b - br.b) < 0.5, "along the bottom")
	local left, right = r.l - br.l, (br.l + br.w) - (r.l + r.w)
	ok(math.abs(left - right) < 0.5, ("centred: %.1f from the left, %.1f from the right"):format(left, right))
	ok(r.w > br.w * 0.8, "across the whole bottom (between the corners)")
	for _, t in ipairs(b.accent) do
		local tr = H.rect(t)
		ok(tr.h <= 4, "no piece of the accent runs up an edge")
	end
	-- back to idle: gone again
	DR.Plan = function()
		return { marks = {}, color = "idle", title = "Closed", sub = "", doing = {}, says = {}, lines = 0 }
	end
	DR.Button.Refresh()
	w:advance(0.2)
	eq(#lit(b), 0, "idle again: no line")
	DR.Plan = real
	T.clean(w)
end)

test("Drive.Button S1: the floating button and its console stay on screen and clear of the open window", function()
	local w, d, W, b = setup()
	local DR = W.Drive
	W.UI.SelectTab("Customers")
	w:advance(1)
	W.Driver.SetOnline(true)
	w:advance(2)
	DR.Button.Dock(nil)
	w:advance(1)
	DR.Button.Place()
	ok(b:IsShown() and DR.Button.Floating(), "the button floats")
	local win = d.env.WuberFrame
	ok(win and win:IsShown(), "the window is open")
	local function box(f)
		local k = f:GetEffectiveScale() / d.env.UIParent:GetEffectiveScale()
		return f:GetLeft() * k, f:GetRight() * k, f:GetBottom() * k, f:GetTop() * k
	end
	local wl, wr, wb, wt = box(win)
	local bl, br, bb, bt = box(b)
	local k = b:GetEffectiveScale() / d.env.UIParent:GetEffectiveScale()
	local free = bl >= wr - 0.5 or br <= wl + 0.5 or bb >= wt or bt <= wb - 0
	ok(free, ("button clear of the window (button %.0f-%.0f, window %.0f-%.0f)"):format(bl, br, wl, wr))
	ok(bl >= -0.5 and br <= d.env.UIParent:GetWidth() + 0.5, "button on screen across")
	ok(bb - 300 * k >= -0.5 or bb >= 0, "the console under it fits on screen")
	T.clean(w)
end)

test("Drive.Button S1: the handset's bezel and status bar count; a button left of the phone does not move needlessly", function()
	local w, d, W, b = setup()
	local DR = W.Drive
	W.UI.SelectTab("Customers")
	W.Driver.SetOnline(true)
	w:advance(2)
	DR.Button.Dock(nil)
	w:advance(1)
	DR.Button.Place()
	local win = d.env.WuberFrame
	local k = win:GetEffectiveScale() / d.env.UIParent:GetEffectiveScale()
	local pr = (win:GetRight() + W.UI.PHONE.bezel) * k
	local pl = (win:GetLeft() - W.UI.PHONE.bezel) * k
	local bk = b:GetEffectiveScale() / d.env.UIParent:GetEffectiveScale()
	local bl, br = b:GetLeft() * bk, b:GetRight() * bk
	ok(bl >= pr - 0.5 or br <= pl + 0.5, ("clear of the bezel (button %.0f-%.0f, handset %.0f-%.0f)"):format(bl, br, pl, pr))
	-- moving the window: no re-place until it has held still for a tick
	local moves = 0
	local real = b.SetPoint
	b.SetPoint = function(...) moves = moves + 1 return real(...) end
	win:ClearAllPoints()
	win:SetPoint("CENTER", d.env.UIParent, "CENTER", 40, 0)
	DR.Button.Place()
	eq(moves, 0, "no churn on the first tick of a move")
	b.SetPoint = real
	T.clean(w)
end)

---------------------------------------------------------------------------
-- (BRIEF18 3a) every title and subtitle Drive.Plan can put on the big button fits, floating and
-- docked, at the author's sizes: never "...", the subtitle on two lines at most. The texts are read from
-- Drive/Plan.lua itself (every plan.title / plan.sub / plan.here assignment, filled in with the
-- longest name the game allows and long numbers), so a new state is checked the day it is written.
-- The fake game draws each glyph on whole screen pixels (H.TEXT_PIXELS, about 0.75 screen pixels per
-- UI unit: a windowed game at a small UI scale), so the button's scale counts as it does in game.
-- (the author's cut Paused subtitle was the login font, not this: see the next test.)
---------------------------------------------------------------------------

local LONG_NAME = "Bartholomewz" -- 12 letters: the longest name the game allows
local FIELD = { title = "title", sub = "sub", here = "here", below = "sub", tradeTitle = "title", tradeSub = "sub" }

-- every statement in a source file that assigns a title, sub or here, as { line, code }
local function assignments(path)
	local f = assert(io.open(path, "r"))
	local src = f:read("*a")
	f:close()
	local lines = {}
	for l in (src .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
	local out = {}
	local i = 1
	while i <= #lines do
		local l = lines[i]
		local lhs = l:match("^%s*(plan%.[%w_]+[%w_%.,%s]-)%s*=[^=]")
		local hit = false
		if lhs then
			for name in lhs:gmatch("plan%.([%w_]+)") do if FIELD[name] then hit = true end end
		end
		if hit then
			local code, first = l, i
			-- an expression that runs on: the next lines start with or / and / ..
			while lines[i + 1] and (lines[i + 1]:match("^%s*or%s") or lines[i + 1]:match("^%s*and%s") or lines[i + 1]:match("^%s*%.%.")) do
				i = i + 1
				code = code .. "\n" .. lines[i]
			end
			out[#out + 1] = { line = first, code = code }
		end
		i = i + 1
	end
	return out
end

-- runs one assignment with every free name filled in (truthy first, then falsy, so both sides of
-- an "a and x or y" are seen); returns the texts it made, by field
local function evaluate(code)
	local got = {}
	local stub
	local mt = {}
	stub = setmetatable({}, mt)
	mt.__index = function() return stub end
	mt.__call = function() return stub end
	mt.__tostring = function() return LONG_NAME end
	mt.__concat = function(a, b)
		return (a == stub and LONG_NAME or tostring(a)) .. (b == stub and LONG_NAME or tostring(b))
	end
	mt.__sub = function() return 0 end
	mt.__add = function() return 0 end
	local made = 0
	for _, truthy in ipairs({ true, false }) do
		local rec = {}
		local plan = setmetatable({}, {
			__index = function(_, k) return truthy and stub or nil end,
			__newindex = function(_, k, v) if FIELD[k] and v ~= nil then rec[#rec + 1] = { FIELD[k], v == stub and LONG_NAME or tostring(v) } end end,
		})
		local env = setmetatable({
			plan = plan, tostring = tostring, tonumber = tonumber, math = math, type = type,
			short = function() return LONG_NAME end, money = function() return "199g 99s" end,
			count = function() return 12 end, due = function() return 1999900 end, now = function() return 0 end,
			CALL_AGAIN = 30, n = 12,
		}, { __index = function() if truthy then return stub end return nil end })
		local fn = loadstring(code)
		if fn then
			setfenv(fn, env)
			if pcall(fn) then
				made = made + 1
				for _, r in ipairs(rec) do got[#got + 1] = r end
			end
		end
	end
	return got, made
end

local function planTexts()
	local texts = { title = {}, sub = {}, here = {} }
	local seen, bad = {}, {}
	local function add(field, t)
		if t ~= "" and not seen[field .. t] then
			seen[field .. t] = true
			texts[field][#texts[field] + 1] = t
		end
	end
	for _, a in ipairs(assignments("Wuber/Drive/Plan.lua")) do
		local got, made = evaluate(a.code)
		if made == 0 then bad[#bad + 1] = "Plan.lua:" .. a.line end
		for _, r in ipairs(got) do add(r[1], r[2]) end
	end
	-- the button's own plans (the fight's "Paused during combat")
	local f = assert(io.open("Wuber/Drive/Button.lua", "r"))
	local src = f:read("*a")
	f:close()
	for t, s in src:gmatch('title = "([^"]+)", sub = "([^"]+)"') do add("title", t) add("sub", s) end
	return texts, bad
end

-- what is wrong with one label now, or nil
local function cut(fs, what, maxLines)
	if not fs:IsVisible() then return nil end
	local tr = H.truncation(fs)
	if tr then return ("%s cut%s: '%s' (needs %.0f of %.0f)"):format(what, tr.stale and " (stale)" or "", tostring(fs:GetText()), tr.need or 0, tr.room or 0) end
	local n = H.textLines(fs)
	if maxLines and n and n > maxLines then return ("%s on %d lines: '%s'"):format(what, n, tostring(fs:GetText())) end
	return nil
end

test("Drive.Button BRIEF18 3a: every plan state's title and sub fit the big button, floating and docked, at the author's sizes", function()
	local texts, bad = planTexts()
	eq(#bad, 0, "every title/sub assignment in Drive/Plan.lua can be filled in by this test: " .. table.concat(bad, ", "))
	ok(#texts.title >= 20 and #texts.sub >= 30, ("the states were found (%d titles, %d subs)"):format(#texts.title, #texts.sub))
	local found = {}
	for _, s in ipairs(texts.sub) do found[s] = true end
	ok(found["nobody new is invited: tap Resume"], "Paused is among them")
	local w, d, W, b = setup()
	local DR = W.Drive
	local was = H.TEXT_PIXELS
	H.TEXT_PIXELS = { px = 0.75, snap = "round", track = 0 }
	local real, realCombat = DR.Plan, W.InCombat
	local problems = {}
	local function check(where, title, sub, here, combat)
		DR.Plan = function()
			return { marks = {}, color = "go", title = title, sub = sub, here = here, doing = {}, says = {}, lines = 0, paused = false }
		end
		DR.Button.Refresh()
		if combat then
			W.InCombat = function() return true end
			DR.Button.Refresh()
			W.InCombat = realCombat
		end
		for _, p in ipairs({ cut(b.title, where .. " title", 1), cut(b.sub, where .. " sub", 2) }) do
			if #problems < 12 then problems[#problems + 1] = p end
		end
	end
	local function run(where)
		local n = math.max(#texts.title, #texts.sub)
		for i = 1, n do
			check(where, texts.title[i] or texts.title[1], texts.sub[i] or texts.sub[1], nil, false)
		end
		for i = 1, #texts.sub do check(where .. " in combat", texts.title[1], texts.sub[i], nil, true) end
		for i = 1, #texts.here do check(where, texts.title[1], texts.sub[1], texts.here[i], false) end
	end
	-- docked in the Drive tab's hero card
	ok(DR.Button.Docked(), "docked in the Drive tab")
	run("docked")
	-- floating, at the sizes the button takes (auto-scale 1 to 2.2, the author's 1.4)
	W.UI.SelectTab("Customers")
	W.Driver.SetOnline(true)
	w:advance(2)
	DR.Button.Dock(nil)
	w:advance(1)
	for _, s in ipairs({ 1, 1.4, 1.7, 2.2 }) do
		DR.SetScale(s)
		DR.Button.Place()
		ok(DR.Button.Floating(), "floats at " .. s)
		run(("floating x%.1f"):format(s))
	end
	DR.SetScale(nil)
	DR.Plan, W.InCombat = real, realCombat
	H.TEXT_PIXELS = was
	eq(#problems, 0, "no '...' and no third line:\n  " .. table.concat(problems, "\n  "))
	T.clean(w)
end)

test("Drive.Button BRIEF18: words set at login before the font loaded are set again when it arrives (no '...' anywhere, window never opened)", function()
	local w = T.newWorld()
	w.fontReadyAt = (w.time or 0) + 25 -- the game is still loading the addon font (H.fontPending)
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W, env = d.W, d.env
	ok(w.time < w.fontReadyAt, ("the font still loads after login (t=%.1f)"):format(w.time))
	-- the author's state: open, Paused, and the window never opened
	W.Driver.SetOnline(true)
	W.Driver.SetPaused(true)
	w:advance(1)
	local b = env.WuberDriveButton
	ok(b:IsShown() and W.Drive.Button.Floating(), "the button floats")
	eq(b.sub:GetText(), "nobody new is invited: tap Resume", "Paused")
	local before = H.truncation(b.sub)
	ok(before and before.stale, "set before the font: laid out with the wrong widths (the fake game models it)")
	w:advance(w.fontReadyAt - w.time + 3)
	ok(not (env.WuberFrame and env.WuberFrame:IsShown()), "the window was never opened")
	local bad, n = {}, 0
	for fs in pairs(W.Theme.allText) do
		local p = cut(fs, "'" .. tostring(fs:GetText()) .. "'", (fs == b.sub) and 2 or nil)
		if fs:IsVisible() then n = n + 1 end
		if p and #bad < 12 then bad[#bad + 1] = p end
	end
	ok(n >= 3, "strings on screen were checked (" .. n .. ")")
	eq(#bad, 0, "after the font arrived, nothing on screen is cut:\n  " .. table.concat(bad, "\n  "))
	T.clean(w)
end)

test("Drive.Button BRIEF18: the Drive tab's pills never cut their words ('Advertis...'), steady and when the font arrives late", function()
	-- the window opened on the Drive tab while the game is still loading the addon font (its own first-open
	-- refreshes run too early), then the font arrives
	local w = T.newWorld()
	w.fontReadyAt = (w.time or 0) + 25
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W, env = d.W, d.env
	W.db.coach = true
	W.Char().wizard = true
	W.UI.Toggle(true)
	w:advance(2)
	W.UI.SelectTab("Drive")
	w:advance(2)
	ok(w.time < w.fontReadyAt, "the window opened before the font arrived")
	local v = W.Driver.ui.console
	ok(v and v.advert and v.advert:IsVisible(), "the Advertise pill shows")
	w:advance(w.fontReadyAt - w.time + 3)
	local bad = {}
	for fs in pairs(W.Theme.allText) do
		local p = cut(fs, "'" .. tostring(fs:GetText()) .. "'", nil)
		if p and #bad < 12 then bad[#bad + 1] = p end
	end
	eq(#bad, 0, "the font arrived: nothing in the window is cut:\n  " .. table.concat(bad, "\n  "))
	-- steady: every word each of the three pills can take, drawn on whole pixels at three screens
	local was = H.TEXT_PIXELS
	local words = { "Open", "Close", "Start", "Stop", "Pause", "Resume", "Advertise", "Advertise!", "Advert 15m",
		"In combat", "No channel", "Warlocks" }
	for _, px in ipairs({ 0.6, 0.75, 1, 1.5 }) do
		H.TEXT_PIXELS = { px = px, snap = "round", track = 0 }
		for _, pill in ipairs({ v.open, v.pause, v.advert }) do
			for _, word in ipairs(words) do
				pill:SetLabel(word)
				local p = cut(pill.label, ("pill '%s' at %.2f px/unit"):format(word, px), 2)
				if p and #bad < 12 then bad[#bad + 1] = p end
			end
		end
	end
	H.TEXT_PIXELS = was
	eq(#bad, 0, "every pill word fits:\n  " .. table.concat(bad, "\n  "))
	T.clean(w)
end)


---------------------------------------------------------------------------
-- (BRIEF20 B5, shots 83 and 88) closed or stopped, the floating button's words point at the Open /
-- Start pill of its console right under it ("tap Open below"), not at Wuber's Drive tab; alone (no
-- room for its console beside the open phone, B.Solo) they still say where Open is: the Drive tab.
---------------------------------------------------------------------------

local SQUARE = { 1331, 1044, 2662, 2089 } -- the author's 2662x2089 window at UI scale 0.74

local function sizedDriver(size)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	if size then
		H.state[d.env.UIParent].w, H.state[d.env.UIParent].h = size[1], size[2]
		d.physW, d.physH = size[3], size[4]
		d.wide = true
		d:fire("DISPLAY_SIZE_CHANGED")
	end
	return w, d, W
end

test("Drive.Button BRIEF20 B5: closed, the floating button says tap Open below (its console is there); docked, the Drive tab's words", function()
	local w, d, W = sizedDriver()
	local DR, env = W.Drive, d.env
	local b = env.WuberDriveButton
	DR.Button.KeepClosed(true)
	W.Driver.SetOnline(false)
	w:advance(2)
	ok(not DR.IsOpen(), "closed")
	ok(b:IsShown() and DR.Button.Floating(), "the button floats (window shut)")
	ok(not DR.Button.Solo(), "with its console")
	local m = env.WuberDriveMini
	ok(m and m:IsVisible(), "its console shows under it")
	eq(m.close.label:GetText(), "Open", "the console's Open pill")
	eq(b.title:GetText(), "Closed", "title")
	eq(b.sub:GetText(), "tap Open below", "the words point at the Open pill right below")
	-- docked in the Drive tab: the hero card's own words
	W.UI.Toggle(true)
	w:advance(2)
	W.UI.SelectTab("Drive")
	w:advance(2)
	ok(DR.Button.Docked(), "docked")
	eq(b.sub:GetText(), "Tap Open below to start taking riders", "docked words")
	-- and floating again
	W.UI.Toggle(false)
	w:advance(2)
	ok(DR.Button.Floating(), "floats again")
	eq(b.sub:GetText(), "tap Open below", "floating words again")
	-- raid summons stopped: Start
	local realMode = DR.Mode
	DR.Mode = function() return "raid" end
	DR.Button.Refresh()
	w:advance(1)
	eq(b.title:GetText(), "Raid summons stopped", "raid title")
	eq(b.sub:GetText(), "tap Start below", "raid: the Start pill below")
	DR.Mode = realMode
	T.clean(w)
end)

test("Drive.Button BRIEF20 B5: the button alone (no room for its console beside the unfolded phone) says Open is in Wuber's Drive tab", function()
	local w, d, W = sizedDriver(SQUARE)
	local DR, env = W.Drive, d.env
	local b = env.WuberDriveButton
	DR.Button.KeepClosed(true)
	W.Driver.SetOnline(false)
	-- (round 31) at size 1 a shorter console now fits under the phone (B.MiniRows); at 1.5 not even that
	DR.SetScale(1.5)
	W.db.pos = { "TOPLEFT", "TOPLEFT", math.floor((1331 / 1.15 - 720) / 2 + 0.5), -60 }
	W.UI.Toggle(true)
	w:advance(1)
	W.UI.SelectTab("Drive")
	w:advance(0.5)
	W.Driver.ShowScreen("customers")
	w:advance(2)
	ok(W.UI.Fold.IsUnfolded(), "the Customers page unfolds")
	ok(DR.Button.Floating(), "the button floats")
	ok(DR.Button.Solo(), "alone: no room for its console")
	ok(not (env.WuberDriveMini and env.WuberDriveMini:IsVisible()), "no console under it")
	eq(b.sub:GetText(), "tap Open in Wuber's Drive tab", "no Open pill below: the Drive tab")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- (BRIEF22 L3-L5, the layout checker at Wuber sizes 1.5 and 2.2) on a 1920x1080 screen (1365 x 768 units) and the
-- square one: the floating big button stays on the screen (its top was 112 above it at 2.2), keeps off the open
-- phone (a smaller button beside it when the chosen size has no room there), and off the minimap and its button.
---------------------------------------------------------------------------
local L_SIZES = { { 1365, 768, 1920, 1080 }, { 1331, 1044, 2662, 2089 } }

local function rectK(env, f)
	if not (f and f:IsVisible()) then return nil end
	local k = f:GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	return { l = f:GetLeft() * k, r = f:GetRight() * k, b = f:GetBottom() * k, t = f:GetTop() * k }
end
local function meets(a, c) return a and c and a.l < c.r and a.r > c.l and a.b < c.t and a.t > c.b end
local function sized(W, n)
	W.db.scale = n
	W.Drive.SetScale(n)
	if W.UI.ApplyScale then W.UI.ApplyScale() end
end

test("Drive.Button BRIEF22 L4 L5: at size 2.2 the floating button is on the screen and off the minimap and its button", function()
	for _, size in ipairs(L_SIZES) do
		local w, d, W = sizedDriver(size)
		local env, DR = d.env, W.Drive
		-- the chat where the game puts it (the button keeps off it too: there the minimap had given way)
		local chat = env.DEFAULT_CHAT_FRAME
		chat:ClearAllPoints()
		chat:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 32, 95)
		chat:SetSize(430, 120)
		chat:Show()
		sized(W, 2.2)
		W.Driver.SetOnline(true)
		W.Driver.SetPaused(true)
		w:advance(4)
		local b = env.WuberDriveButton
		ok(b:IsShown() and DR.Button.Floating(), "the button floats")
		local r = rectK(env, b)
		local tag = size[3] .. "x" .. size[4] .. ": "
		ok(r.t <= size[2] + 0.5 and r.b >= -0.5 and r.l >= -0.5 and r.r <= size[1] + 0.5,
			tag .. ("the button on the screen (%.0f..%.0f x %.0f..%.0f)"):format(r.l, r.r, r.b, r.t))
		local mm = rectK(env, env.WuberMinimapButton)
		local mini = rectK(env, env.WuberDriveMini)
		ok(mm, tag .. "the minimap button shows")
		ok(not meets(r, mm), tag .. "the button is off the minimap button")
		ok(not meets(mini, mm), tag .. "its console is off the minimap button")
		ok(not meets(r, rectK(env, env.Minimap)), tag .. "the button is off the minimap")
		ok(not meets(r, rectK(env, chat)), tag .. "and off the chat")
		T.clean(w)
	end
end)

-- (the unfolded phone on the square screen leaves no room beside it at any readable size: there the button goes
-- alone above or below it, BRIEF20 B5; so that screen is checked folded)
test("Drive.Button BRIEF22 L3: at sizes 1.5 and 2.2 the floating button and its console keep off the open phone", function()
	for _, size in ipairs(L_SIZES) do
		for _, n in ipairs({ 1.5, 2.2 }) do
			local w, d, W = sizedDriver(size)
			local env, DR = d.env, W.Drive
			sized(W, n)
			if size[4] == 2089 then W.db.fold = { v = 1, pages = {}, narrow = true } end
			W.Driver.SetOnline(true)
			W.UI.Toggle(true)
			w:advance(1)
			W.UI.SelectTab("Drive")
			w:advance(0.5)
			W.Driver.ShowScreen("customers")
			w:advance(2)
			local tag = size[3] .. "x" .. size[4] .. " at " .. n .. ": "
			ok(DR.Button.Floating(), tag .. "the button floats")
			local win = env.WuberFrame
			local k = win:GetEffectiveScale() / env.UIParent:GetEffectiveScale()
			local bz = W.UI.PHONE.bezel
			local ph = { l = (win:GetLeft() - bz) * k, r = (win:GetRight() + bz) * k, b = (win:GetBottom() - bz) * k, t = (win:GetTop() + bz) * k }
			local r, mini = rectK(env, env.WuberDriveButton), rectK(env, env.WuberDriveMini)
			ok(r and not meets(r, ph), tag .. ("the button (%.0f..%.0f) off the phone (%.0f..%.0f)"):format(r and r.l or -1, r and r.r or -1, ph.l, ph.r))
			ok(not meets(mini, ph), tag .. "its console off the phone")
			ok(r.l >= -0.5 and r.r <= size[1] + 0.5 and r.b >= -0.5 and r.t <= size[2] + 0.5, tag .. "the button on the screen")
			-- the window shut: the chosen size again
			W.UI.Toggle(false)
			w:advance(2)
			eq(math.floor(env.WuberDriveButton:GetScale() * 100 + 0.5), math.floor(n * 100 + 0.5), tag .. "window shut: the chosen size again")
			T.clean(w)
		end
	end
end)
