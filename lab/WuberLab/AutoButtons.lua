-- Wuber Lab (developer only, never ship): AutoButtons.lua, two passes of the Auto check (job 2748b, issue #36).
-- New file: restart the game once. Nothing is sent; every click is local; all of it is put back by the tour's own reset.
--
--   "Back on every page"  (screens a_back_*, one per page): for each page with a back arrow (Ride confirm, Settings from Ride, Settings
--       from the Drive cog, Drive > Customers, Messages, Earnings, Your crew, Help): open it, find the arrow, and ask which
--       Wuber frame is on top at the arrow's centre. The Auto check has no mouse, so the lab ranks the frames itself with the
--       client's real rule, read from real frame data (strata, level, DoesClipChildren, rects, GetHitRectInsets). The rule
--       (proven from GetMouseFoci samples, 122 of 122 rows that differ from plain level order, none against): a frame cut
--       off at the point by a clipping ancestor never takes the mouse; a frame inside a clipping ancestor competes with
--       frames outside that ancestor at the clipping ancestor's own strata and level, and at an equal level the outside frame
--       wins; otherwise strata, then level, then the newer frame. Fail when the top frame is not the arrow (the row names
--       the frame that covers it). If the cursor happens to be over the arrow, GetMouseFoci is written into the row as
--       evidence. Then the arrow is clicked (arrow:Click(): a real click reaches OnClick only if the arrow is on top, which is
--       what the top check proves), the page before must be shown again (what the window draws changes). The
--       tour waits for each page to stop sliding in before its screen is looked at, so the places are the settled ones.
--   "Click every safe local button" (screens a_click_*): a fixed allow list below, by screen and label (never a deny
--       list): the top-frame check at the button's centre, and something visible changed after its click.
--
-- Rows (status pass, or look = the failure) carry the step ids BUTTONS-BACK / BUTTONS-CLICK so labreport lists them.
-- The two checks are screens of the Auto check list, so they run in its order: Auto check first, hands off.
local _, L = ...

local K, P, X = L.PhotoKit, L.PhotoShotKit, L.AutoKit
local str, num = L.str, L.num
local fn = K.fn
local SCREENS = L.AUTO_SCREENS

local B = {}
L.AutoButtons = B

local STRATA = { WORLD = 0, BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

local function m(o, name, ...)
	if type(o) ~= "table" then return nil end
	local f = o[name]
	if type(f) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(f, o, ...)
	if not ok then return nil end
	return a, b, c, d
end

-- o:name() -> every result in a list (m() keeps four)
local function many(o, name)
	if type(o) ~= "table" or type(o[name]) ~= "function" then return {} end
	local r = { pcall(o[name], o) }
	table.remove(r, 1)
	return r
end

local function tourScreen(id)
	for _, s in ipairs(L.PHOTO_SCREENS or {}) do if s.id == id then return s end end
	return nil
end
local function openTour(W, id, view)
	local s = tourScreen(id)
	if not s then return "the tour has no screen " .. id end
	local ok, r = pcall(s.run, W, view)
	if not ok then return "opening it broke: " .. tostring(r) end
	if r ~= true and r ~= nil then return tostring(r) end
	return true
end

---------------------------------------------------------------------------
-- The client's own ranking, from real frame data
---------------------------------------------------------------------------

local function winOf(W)
	local st = type(W.UI) == "table" and W.UI.state
	local win = type(st) == "table" and st.win
	return (type(win) == "table" and fn(win, "GetChildren")) and win or nil
end

-- a frame's box where the mouse takes it: its scaled rect less its hit-rect insets (left, right, top, bottom; positive = smaller)
local function hitBox(f)
	local l, b, w, h = m(f, "GetScaledRect")
	l, b, w, h = num(l), num(b), num(w), num(h)
	if not (l and b and w and h) then return nil end
	local il, ir, it, ib = m(f, "GetHitRectInsets")
	local k = num(m(f, "GetEffectiveScale")) or 1
	il, ir, it, ib = (num(il) or 0) * k, (num(ir) or 0) * k, (num(it) or 0) * k, (num(ib) or 0) * k
	return { l = l + il, r = l + w - ir, b = b + ib, t = b + h - it }, { l = l, r = l + w, b = b, t = b + h }
end

local function has(box, x, y) return box and x >= box.l and x <= box.r and y >= box.b and y <= box.t end

local function chainOf(f)
	local out, n = {}, 0
	while type(f) == "table" and n < 60 do
		out[#out + 1] = f
		f = m(f, "GetParent")
		n = n + 1
	end
	return out
end

-- a clipping ancestor (SetClipsChildren) whose box does not hold the point cuts the frame off there
local function cutOff(f, x, y)
	local ch = chainOf(f)
	for i = 2, #ch do
		if m(ch[i], "DoesClipChildren") == true then
			local _, plain = hitBox(ch[i])
			if plain and not has(plain, x, y) then return true end
		end
	end
	return false
end

-- the frame that stands for a chain when it meets a frame outside the subtree under stop: its highest clipping ancestor below stop, else itself
local function standIn(chain, stop)
	local who
	for i = 1, #chain do
		local g = chain[i]
		if g == stop then break end
		if i > 1 and m(g, "DoesClipChildren") == true then who = g end
	end
	return who or chain[1], who ~= nil
end
local function key(f) return (STRATA[m(f, "GetFrameStrata") or "MEDIUM"] or 3) * 1e5 + (num(m(f, "GetFrameLevel")) or 0) end

-- true when a lies over b at the point (both take the mouse there); ia, ib: their order of creation
local function above(a, ia, b, ib)
	local ca, cb = chainOf(a), chainOf(b)
	local inB = {}
	for _, g in ipairs(cb) do inB[g] = true end
	local lca
	for _, g in ipairs(ca) do if inB[g] then lca = g break end end
	local ra, clipA = standIn(ca, lca)
	local rb, clipB = standIn(cb, lca)
	if ra ~= rb then
		local ka, kb = key(ra), key(rb)
		if ka ~= kb then return ka > kb end
		if clipA ~= clipB then return clipB end
	end
	local ka, kb = key(a), key(b)
	if ka ~= kb then return ka > kb end
	return ia > ib
end
B.above = above

-- Wuber's visible frames that take the mouse and hold the point: { f, i }, in order of creation (parents before children)
local function roots(W)
	local out, seen = {}, {}
	local win = winOf(W)
	if win then out[#out + 1] = win seen[win] = true end
	for name, v in pairs(_G) do
		if type(name) == "string" and name:find("^Wuber") and not name:find("^WuberLab") and type(v) == "table" and not seen[v]
			and fn(v, "GetChildren") and m(v, "IsShown") == true and m(v, "GetParent") == rawget(_G, "UIParent") then
			out[#out + 1] = v
			seen[v] = true
		end
	end
	return out
end

local function takesMouse(f)
	if m(f, "IsMouseEnabled") ~= true then return false end
	if m(f, "IsMouseClickEnabled") == false then return false end
	return true
end

function B.hitsAt(W, x, y, rts)
	local out, n, seen = {}, 0, {}
	local function walk(f, depth)
		if seen[f] or depth > 40 or m(f, "IsShown") ~= true then return end
		seen[f] = true
		n = n + 1
		if takesMouse(f) then
			local hit = hitBox(f)
			if has(hit, x, y) and not cutOff(f, x, y) then out[#out + 1] = { f = f, i = n } end
		end
		for _, c in ipairs(many(f, "GetChildren")) do walk(c, depth + 1) end
	end
	for _, r in ipairs(rts or roots(W)) do walk(r, 1) end
	return out
end

-- the top frame at a point: its entry (f, i), and how many frames hold the point
function B.topAt(W, x, y, rts)
	local hits = B.hitsAt(W, x, y, rts)
	local best
	for _, h in ipairs(hits) do
		if not best or above(h.f, h.i, best.f, best.i) then best = h end
	end
	return best and best.f or nil, #hits
end

function B.centre(f)
	local l, b, w, h = m(f, "GetScaledRect")
	l, b, w, h = num(l), num(b), num(w), num(h)
	if not (l and b and w and h) then return nil end
	return l + w / 2, b + h / 2
end

local function textsOf(f)
	local out = {}
	for _, r in ipairs(many(f, "GetRegions")) do
		local t = m(r, "GetText")
		if type(t) == "string" and t ~= "" and m(r, "IsShown") == true then out[#out + 1] = X.plain(t) end
	end
	return out
end

-- what a frame is, for a row: its name, or its kind, level, size and parent
function B.describe(f)
	if type(f) ~= "table" then return "nothing" end
	local name = m(f, "GetName")
	local par = m(f, "GetParent")
	local pn = par and m(par, "GetName")
	local w, h = num(m(f, "GetWidth")), num(m(f, "GetHeight"))
	local tx = textsOf(f)
	return ("%s%s (%s, %s level %s, %.0f x %.0f%s%s)"):format(name and (name .. " ") or "an unnamed ", str(m(f, "GetObjectType")) or "frame",
		m(f, "DoesClipChildren") == true and "clips" or "no clip", str(m(f, "GetFrameStrata")) or "?", str(m(f, "GetFrameLevel")) or "?",
		w or 0, h or 0, pn and (", in " .. pn) or (par and ", in an unnamed parent" or ""), #tx > 0 and (', text "' .. X.short(tx[1], 24) .. '"') or "")
end

-- every visible back arrow (Buttons flagged wuberBackArrow, as Window.lua finds them)
function B.arrows(W)
	local out, win = {}, winOf(W)
	local function walk(f, depth)
		if depth > 12 then return end
		for _, c in ipairs(many(f, "GetChildren")) do
			-- (the flag T.RoundButton sets; the real client's GetTexture() is a file id, so the path is the fallback)
			local g = type(c) == "table" and rawget(c, "glyph") or nil
			local tex = type(g) == "table" and m(g, "GetTextureFilePath") or nil
			local isBack = type(c) == "table" and (rawget(c, "wuberBackArrow") == true or (type(tex) == "string" and tex:sub(-4) == "back"))
			if isBack and m(c, "IsVisible") == true then
				out[#out + 1] = c
			else
				walk(c, depth + 1)
			end
		end
	end
	if win then walk(win, 1) end
	return out
end

-- of several visible arrows (a page over a page: Help over Settings) the one a player reaches: the top-ranked of them
function B.topArrow(arrows)
	local best, bi
	for i, a in ipairs(arrows) do
		if not best or above(a, i, best, bi) then best, bi = a, i end
	end
	return best
end

-- where the window is, as the lab's Focus rows name it: tab, screen, Settings and Help shown, the driver's screen
function B.where(W)
	local UI = W.UI
	local st = type(UI) == "table" and UI.state
	local out = {}
	if type(st) == "table" then out.tab, out.screen = str(st.tab), str(st.screen) end
	if fn(UI, "SettingsShown") then local ok, v = pcall(UI.SettingsShown) out.settings = ok and v == true end
	if fn(UI, "HelpShown") then local ok, v = pcall(UI.HelpShown) out.help = ok and v == true end
	local D = type(W.Driver) == "table" and W.Driver or nil
	if D and fn(D, "CurrentScreen") then local ok, v = pcall(D.CurrentScreen) out.dscreen = ok and str(v) or nil end
	return out
end
local function whereText(t)
	return ("%s/%s%s%s, driver screen %s"):format(tostring(t.tab), tostring(t.screen), t.settings and " +settings" or "", t.help and " +help" or "", tostring(t.dscreen))
end
local function sameWhere(want, got)
	for k, v in pairs(want) do if got[k] ~= v then return false end end
	return true
end

-- the game's own answer when the cursor is over the arrow now: the top frame at the cursor (GetMouseFoci), or nil
local function fociAt(f)
	if m(f, "IsMouseOver") ~= true then return nil end
	local get = rawget(_G, "GetMouseFoci")
	local list = type(get) == "function" and select(2, pcall(get)) or nil
	if type(list) ~= "table" then
		local one = rawget(_G, "GetMouseFocus")
		list = { type(one) == "function" and select(2, pcall(one)) or nil }
	end
	return list[1] or false
end

---------------------------------------------------------------------------
-- The top check: -> ok, detail
---------------------------------------------------------------------------

function B.topCheck(W, f, what, rts)
	local x, y = B.centre(f)
	if not x then return false, what .. " has no place on the screen" end
	local top, n = B.topAt(W, x, y, rts)
	local line = ("%d Wuber frames take the mouse at its centre (only Wuber's own frames are walked)"):format(n)
	local foci = fociAt(f)
	local ev = ""
	if foci ~= nil then ev = "; the cursor is over it: GetMouseFoci top = " .. (foci and B.describe(foci) or "nothing") end
	if top == nil then return false, what .. ": no Wuber frame takes the mouse at its centre (" .. line .. ")" .. ev end
	if top ~= f then
		-- a child of the arrow (its glyph frame) is the arrow itself to the mouse
		local ch = chainOf(top)
		for _, g in ipairs(ch) do if g == f then return true, line .. ev end end
		return false, what .. " is covered at its centre (" .. ("%.0f, %.0f"):format(x, y) .. ") by the top Wuber frame there, " .. B.describe(top) .. "; " .. line .. ev
	end
	return true, line .. ev
end

---------------------------------------------------------------------------
-- Pass 1: Back on every page
---------------------------------------------------------------------------

local function backRow(name, ok, detail)
	return { name = name, status = ok and "pass" or "look", detail = (ok and "" or "FAIL: ") .. detail, steps = { "BUTTONS-BACK" } }
end

local function driveSettings(W)
	local r = openTour(W, "settings")
	if r ~= true then return r end
	local UI = W.UI
	if not fn(UI, "SelectTab") then return "W.UI.SelectTab is missing" end
	UI.SelectTab("Drive")
	if not UI.OpenSettings() then return "Settings didn't open from the Drive tab" end
	return true
end

-- { screen id, label, how the tour opens it, unfold, where the window must be once the arrow has been clicked and the slide has settled }:
-- each is a screen of the Auto check, so the tour has waited until the page has stopped sliding in before the arrow is looked at
B.BACK_PAGES = {
	{ "a_back_confirm", "Ride confirm", function(W) return openTour(W, "confirm") end, nil, { tab = "Ride", screen = "home", settings = false, help = false } },
	{ "a_back_settings_ride", "Settings from Ride", function(W) return openTour(W, "settings") end, true, { tab = "Ride", screen = "home", settings = false, help = false } },
	{ "a_back_settings_drive", "Settings from the Drive cog", driveSettings, true, { tab = "Drive", screen = "home", settings = false, help = false, dscreen = "console" } },
	{ "a_back_customers", "Drive > Customers", function(W) return openTour(W, "customers") end, true, { tab = "Drive", screen = "home", dscreen = "console" } },
	{ "a_back_messages", "Drive > Messages", function(W) return openTour(W, "messages") end, nil, { tab = "Drive", screen = "home", dscreen = "console" } },
	{ "a_back_earnings", "Drive > Earnings", function(W) return openTour(W, "earnings") end, nil, { tab = "Drive", screen = "home", dscreen = "console" } },
	{ "a_back_crew", "Drive > Your crew", function(W) return openTour(W, "crew") end, nil, { tab = "Drive", screen = "home", dscreen = "console" } },
	-- Help opens over Settings: the page before it is Settings itself
	{ "a_back_help", "Help", function(W) return openTour(W, "help") end, true, { settings = true, help = false } },
}
B.SETTLE = 0.8 -- seconds after the click before the page is read (the slide is done)

local pending = {} -- rows waiting for their page to settle: { name, want, after, row }

-- One page, already open and settled: the arrow, the top check, the click. The page the click lands on is read B.SETTLE seconds
-- later (a timer), and the row is given by the next back screen's verify (or the last one's). -> nothing
function B.backPage(W, label, want)
	local name = "back " .. label
	local p = { name = name, want = want or {} }
	pending[#pending + 1] = p
	local arrows = B.arrows(W)
	if #arrows == 0 then p.row = backRow(name, false, "no back arrow is visible on this page") return end
	local a = B.topArrow(arrows)
	local okTop, why = B.topCheck(W, a, "the back arrow", roots(W))
	if not okTop then p.row = backRow(name, false, why) return end
	p.why = why
	local okClick, err = pcall(a.Click, a)
	if not okClick then p.row = backRow(name, false, "its click broke: " .. tostring(err)) return end
	local timer = rawget(_G, "C_Timer")
	local function read() p.after = B.where(W) end
	if type(timer) == "table" and fn(timer, "After") then timer.After(B.SETTLE, read) else read() end
end

-- the rows of every page clicked so far whose page has settled (unsettled ones are skip rows)
function B.flush()
	local out = {}
	for _, p in ipairs(pending) do
		local row = p.row
		if not row then
			if not p.after then
				row = { name = p.name, status = "skip", detail = "the page after the click was not read in time", steps = { "BUTTONS-BACK" } }
			elseif sameWhere(p.want, p.after) then
				row = backRow(p.name, true, "on top at its centre, and its click went back to the page before (" .. whereText(p.after) .. "): " .. p.why)
			else
				row = backRow(p.name, false, "after its click and the slide the window shows " .. whereText(p.after) .. ", not the page before")
			end
		end
		out[#out + 1] = row
	end
	pending = {}
	return out
end

for _, p in ipairs(B.BACK_PAGES) do
	SCREENS[#SCREENS + 1] = { id = p[1], side = "settings", unfold = p[4] or nil, auto = true,
		title = "Back on every page: " .. p[2] .. ", the back arrow is the top Wuber frame at its centre and its click goes back to the page before",
		run = p[3],
		verify = function(W, view)
			local rows = B.flush() -- (the page clicked on the screen before: it has settled by now)
			B.backPage(W, p[2] .. (view == "unfolded" and " (wide)" or ""), p[5])
			return rows
		end }
end
-- the last page's row
SCREENS[#SCREENS + 1] = { id = "a_back_last", side = "settings", auto = true,
	title = "Back on every page: the last page's click, read after the slide",
	run = function(W) return openTour(W, "home") end,
	verify = function() return B.flush() end }

---------------------------------------------------------------------------
-- Pass 2: Click every safe local button
---------------------------------------------------------------------------

-- The allow list: tour screen id -> buttons, by the button's first drawn text. Only what is local to this window (it changes what is
-- shown or a setting the tour puts back). Never Ping drivers, Advertise, Invite, Summon, Pay, Trade, Report, Reset stats, or anything
-- that sends or casts. (Wide and Earnings > Today are left out: in the tour Wide changes nothing a state can name, and Today looks like
-- the default range on demo data: no expectation to hold them to.) undo = true: pressed again afterwards, to put it back. expect(W, ctx) -> true or what was seen: the explicit
-- result of the press (a named state), read straight after it; ctx = { width0 = the window's width before, texts = what it draws now }.
local function settingsSec(key)
	return function(W)
		local st = type(W.UI) == "table" and W.UI.settings
		if type(st) == "table" and st.sec == key then return true end
		return "Settings' section is " .. tostring(type(st) == "table" and st.sec)
	end
end
local function whereIs(want)
	return function(W)
		local got = B.where(W)
		return sameWhere(want, got) or ("the window shows " .. whereText(got))
	end
end
local function drawsText(plainText)
	return function(W, ctx)
		return ctx.texts:find(plainText, 1, true) and true or ("the window does not draw " .. plainText)
	end
end
B.CLICK_LIST = {
	{ screen = "home", labels = {
		{ "Trips", expect = whereIs({ tab = "Trips" }) } } },
	{ screen = "settings", labels = {
		{ "Riding", expect = settingsSec("riding") }, { "Driving", expect = settingsSec("driving") },
		{ "Map", expect = settingsSec("map") }, { "Sound and effects", expect = settingsSec("sound") } } },
	{ screen = "earnings", labels = {
		{ "30 days", expect = drawsText("last 30 days") } } },
}

local function findButton(W, label)
	local win = winOf(W)
	local found
	local function walk(f, depth)
		if found or depth > 40 or m(f, "IsShown") ~= true then return end
		local ty = m(f, "GetObjectType")
		if (ty == "Button" or ty == "CheckButton") and m(f, "IsVisible") == true then
			local tx = textsOf(f)
			if tx[1] == label then found = f return end
		end
		for _, c in ipairs(many(f, "GetChildren")) do walk(c, depth + 1) end
	end
	if win then walk(win, 1) end
	return found
end

local function clickRow(name, ok, detail)
	return { name = name, status = ok and "pass" or "look", detail = (ok and "" or "FAIL: ") .. detail, steps = { "BUTTONS-CLICK" } }
end

-- phase 1 (the page settled): every allow-listed button of the screen is found and its top check made; phase 2: each is pressed
-- (the page is opened again once before each press after the first) and its own expectation must hold. -> rows
local function plainTexts(W)
	local win = winOf(W)
	local out = {}
	local function walk(f, depth)
		if depth > 40 or m(f, "IsShown") ~= true then return end
		for _, t in ipairs(textsOf(f)) do out[#out + 1] = t end
		for _, c in ipairs(many(f, "GetChildren")) do walk(c, depth + 1) end
	end
	if win then walk(win, 1) end
	return table.concat(out, "|")
end

function B.clickScreen(W, screenId, entries)
	local out, checked, rts = {}, {}, roots(W)
	for i, entry in ipairs(entries) do
		local f = findButton(W, entry[1])
		if not f then
			checked[i] = { false, "no visible button called " .. entry[1] .. " on this screen (the allow list names it)" }
		elseif m(f, "IsProtected") == true then
			checked[i] = { false, "it is a secure button: never pressed by the lab" }
		else
			local okTop, why = B.topCheck(W, f, "the button", rts)
			checked[i] = { okTop, why }
		end
	end
	for i, entry in ipairs(entries) do
		local name = "click " .. screenId .. " > " .. entry[1]
		local ck = checked[i]
		if not ck[1] then
			out[#out + 1] = clickRow(name, false, ck[2])
		else
			local r = i == 1 and true or openTour(W, screenId)
			local f = r == true and findButton(W, entry[1]) or nil
			if not f then
				out[#out + 1] = clickRow(name, false, "the button was gone when it was pressed")
			else
				local win = winOf(W)
				local ctx = { width0 = num(m(win, "GetWidth")) }
				local okClick, err = pcall(f.Click, f)
				ctx.texts = plainTexts(W)
				local got = type(entry.expect) == "function" and entry.expect(W, ctx) or "the allow list has no expectation for it"
				if entry.undo then pcall(f.Click, f) end
				if not okClick then out[#out + 1] = clickRow(name, false, "its click broke: " .. tostring(err))
				elseif got ~= true then out[#out + 1] = clickRow(name, false, "after the click: " .. tostring(got))
				else out[#out + 1] = clickRow(name, true, "on top at its centre and the click did what the list expects: " .. ck[2]) end
			end
		end
	end
	openTour(W, screenId)
	return out
end

for _, s in ipairs(B.CLICK_LIST) do
	SCREENS[#SCREENS + 1] = { id = "a_click_" .. s.screen, side = "settings", auto = true,
		title = "Click every safe local button: " .. s.screen .. ", each is on top at its centre and does something visible",
		run = function(W) return openTour(W, s.screen) end,
		verify = function(W) return B.clickScreen(W, s.screen, s.labels) end }
end
