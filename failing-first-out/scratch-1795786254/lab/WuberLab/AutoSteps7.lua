-- Wuber Lab (developer only, never ship): more of the Auto check's own screens (job 242 Lab: the hand steps the game can do itself).
-- The tester's in-game session must be as short as possible. Each check below was a hand step; the game now does it by itself inside the
-- Auto check (local only: nothing is sent to a player or the network, only a button's or box's own insecure handler is called, WuberDB is
-- put back by the tour's snapshot, no secure frame is pressed or changed, nothing runs in combat). Each result carries the hidden step id
-- (the PR number of the pull request that fixed it) so tools/steps2lua.py --auto leaves the step out of his note when every result passed:
--   a_settings_asks  settings  PR-79  a question in the Settings search box ("how do I turn off sounds?"): the matching row shows, its section is named
--                              PR-78  Report a bug: the text has the class and level, the changed settings and the other-addons line
--                              PR-50  /wuber emblem off (SlashCmdList) with Settings open: "Badges over heads" shows OFF (then put back)
--                              PR-62  the back arrow of the pushed Settings page is the topmost mouse-enabled Wuber frame at its centre
--   a_driver_hits    driver    PR-97  Enter in the block-reason box (the box's own OnEnterPressed) blocks the rider; the block is put back
--                              PR-62  the Drive switch (Sell / Raid) is the topmost mouse-enabled Wuber frame at the centre of each half
--   a_pill_hit       rider     PR-45  the ride pill takes the mouse only where a click shows something new, is topmost there, and its
--                                     hit rectangle is the pill
--   a_rider_checks   rider     PR-116 the Trips count counts paid rides only (demo trips, some paid, some not; put back)
--                              PR-115 the celebration card's own OnClick opens Wuber on Trips
--                              PR-48  a world-map price tag is clear of its pin's aura frame (a scratch pin, measured in this game's units)
--   (passive)        PLAYER_LOGOUT / next login   PR-76  a checksum of WuberDB is kept at logout and compared at the next load:
--                              "saved data survived a restart" (pass or look), in WuberLabDB.autoCheck and as a Game facts entry
-- Not done: PR-61 (the blocked-call line): see the hand-back note; it cannot be raised without a real blocked call.
-- What none of them can do (each says so in its words): click with a real mouse. The hit-order checks compute what the game's
-- mouse would find from the frames' strata, levels, hit rectangles and clipping (the way the fake game does, which the Lab's
-- GetMouseFoci samples proved); a real click on the three controls stays a hand step only if one of these says look.
-- New file: needs a full game restart (a /reload does not find it). Same rules as AutoSteps.lua.

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
local function result(name, status, detail, step)
	return { name = name, status = status, detail = detail, steps = step and { step } or nil }
end
-- a guarded method call: every value it gives, or nothing
local function callm(o, name, ...)
	if type(o) ~= "table" or not fn(o, name) then return nil end
	local r = { pcall(o[name], o, ...) }
	if not r[1] then return nil end
	return unpack(r, 2)
end
-- a boolean the game hides (a secret value) cannot be compared: it is read as "no" and the frame is skipped
local function isTrue(o, name)
	local v = callm(o, name)
	local sec = rawget(_G, "issecretvalue")
	if type(sec) == "function" and sec(v) then return false end
	return v == true
end
-- a round back arrow: the flag T.RoundButton sets (the real client's GetTexture() is a file id, not the name), else the glyph's path
local function isBackArrow(f)
	if type(f) ~= "table" then return false end
	if rawget(f, "wuberBackArrow") == true then return true end
	local g = rawget(f, "glyph")
	local p = type(g) == "table" and str(callm(g, "GetTextureFilePath")) or nil
	return p ~= nil and p:sub(-4) == "back"
end
local function script(f, name)
	if type(f) ~= "table" or not fn(f, "GetScript") then return nil end
	local ok, h = pcall(f.GetScript, f, name)
	return ok and type(h) == "function" and h or nil
end
local function textOf(fs)
	local t = callm(fs, "GetText")
	return str(t)
end
local function shown(f) return callm(f, "IsShown") == true end
local function settingsOf(W) return type(W.UI) == "table" and type(W.UI.settings) == "table" and W.UI.settings or nil end
local function uiState(W) return type(W.UI) == "table" and type(W.UI.state) == "table" and W.UI.state or nil end
local function modOf(W, name)
	if not fn(W, "Mod") then return nil end
	local ok, m = pcall(W.Mod, name)
	return ok and type(m) == "table" and m or nil
end
-- every check of a screen runs by itself: one that breaks says so and does not stop the others
local function guarded(d, key, f)
	local ok, err = pcall(f)
	if not ok then d[key] = { broke = tostring(err):sub(1, 200) } end
end

---------------------------------------------------------------------------
-- The game's mouse: which Wuber frame is on top at a point
---------------------------------------------------------------------------
-- Ranked the way the fake game ranks it (tests/harness.lua Client:frameAt, proven by the Lab's GetMouseFoci samples: 122 of 122 rows
-- where level order and the game disagreed, none against): a frame cut off at the point by an ancestor that clips its children never
-- takes the mouse; a frame inside a clipping ancestor competes with frames OUTSIDE it at the clipping ancestor's own strata and level;
-- at an equal level the frame outside the clipping ancestor wins; otherwise strata, then level, then the later frame (here: the later
-- one in a walk of UIParent's children, which is creation order within a parent). Only Wuber's own frames compete (the window and its
-- parts, the frames named Wuber...); a frame of another addon over a control is not judged here. Geometry is read, nothing is called on
-- a frame but getters (a protected frame is read the same way: no script, no click, no change).

local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local MAX_FRAMES = 30000

local function rectOf(f, up)
	local l, b, w, h = callm(f, "GetScaledRect")
	l, b, w, h = num(l), num(b), num(w), num(h)
	if l and b and w and h and up > 0 then return { l = l / up, b = b / up, r = (l + w) / up, t = (b + h) / up } end
	l, b, w, h = num(callm(f, "GetLeft")), num(callm(f, "GetBottom")), num(callm(f, "GetWidth")), num(callm(f, "GetHeight"))
	local es = num(callm(f, "GetEffectiveScale")) or 1
	if not (l and b and w and h) then return nil end
	return { l = l * es / up, b = b * es / up, r = (l + w) * es / up, t = (b + h) * es / up }
end

-- the world of frames under UIParent: list in walk order, parent of each
local function gather(W)
	local upf = rawget(_G, "UIParent")
	local list, par, index = {}, {}, {}
	local function walk(f, depth)
		if #list >= MAX_FRAMES or depth > 40 then return end
		local kids = { callm(f, "GetChildren") }
		for _, c in ipairs(kids) do
			if type(c) == "table" and not index[c] then
				list[#list + 1] = c
				index[c] = #list
				par[c] = f
				walk(c, depth + 1)
			end
		end
	end
	walk(upf, 0)
	local st = uiState(W)
	local win = st and st.win
	local up = num(callm(upf, "GetEffectiveScale")) or 1
	local own = {}
	local function owned(f)
		local v = own[f]
		if v ~= nil then return v end
		local p, n, yes = f, 0, false
		while type(p) == "table" and n < 60 do
			if p == win then yes = true break end
			local name = str(callm(p, "GetName"))
			if name and name:find("^WuberLab") then break end -- the Lab's own frames (the photo catcher) are not Wuber's
			if name and name:find("^Wuber") then yes = true break end
			p, n = par[p], n + 1
		end
		own[f] = yes
		return yes
	end
	return { list = list, par = par, index = index, up = up, owned = owned }
end

local function chainOf(w, f)
	local out, n = {}, 0
	while f and n < 60 do out[#out + 1] = f f, n = w.par[f], n + 1 end
	return out
end
local function clips(f) return callm(f, "DoesClipChildren") == true end
local function standIn(w, chain, stop)
	local who
	for i = 1, #chain do
		local g = chain[i]
		if g == stop then break end
		if i > 1 and clips(g) then who = g end
	end
	return who or chain[1], who ~= nil
end
local function hitKey(f)
	local s = STRATA[str(callm(f, "GetFrameStrata")) or "MEDIUM"] or 3
	return s * 1e5 + (num(callm(f, "GetFrameLevel")) or 0)
end
local function above(w, a, b)
	local ca, cb = chainOf(w, a), chainOf(w, b)
	local inB = {}
	for _, g in ipairs(cb) do inB[g] = true end
	local lca
	for _, g in ipairs(ca) do if inB[g] then lca = g break end end
	local ra, clipA = standIn(w, ca, lca)
	local rb, clipB = standIn(w, cb, lca)
	if ra ~= rb then
		local ka, kb = hitKey(ra), hitKey(rb)
		if ka ~= kb then return ka > kb end
		if clipA ~= clipB then return clipB end
	end
	local ka, kb = hitKey(a), hitKey(b)
	if ka ~= kb then return ka > kb end
	return (w.index[a] or 0) > (w.index[b] or 0)
end
local function cutOff(w, f, x, y)
	local p, n = w.par[f], 0
	while p and n < 60 do
		if clips(p) then
			local r = rectOf(p, w.up)
			if not r or x < r.l or x > r.r or y < r.b or y > r.t then return true end
		end
		p, n = w.par[p], n + 1
	end
	return false
end
-- the mouse-enabled, visible Wuber frames whose hit rectangle holds the point, top first
local function framesAt(w, x, y)
	local cands = {}
	for _, f in ipairs(w.list) do
		if isTrue(f, "IsMouseEnabled") and isTrue(f, "IsVisible") and w.owned(f) then
			local r = rectOf(f, w.up)
			if r then
				local il, ir, it, ib = callm(f, "GetHitRectInsets")
				il, ir, it, ib = num(il) or 0, num(ir) or 0, num(it) or 0, num(ib) or 0
				local l, rr, t, b = r.l + il, r.r - ir, r.t - it, r.b + ib
				if x >= l and x <= rr and y >= b and y <= t and not cutOff(w, f, x, y) then cands[#cands + 1] = f end
			end
		end
	end
	local out = {}
	while #cands > 0 do
		local best = 1
		for k = 2, #cands do if above(w, cands[k], cands[best]) then best = k end end
		out[#out + 1] = cands[best]
		table.remove(cands, best)
	end
	return out
end
local function within(w, f, ctl)
	local n = 0
	while f and n < 60 do
		if f == ctl then return true end
		f, n = w.par[f], n + 1
	end
	return false
end
local function nameOfFrame(f)
	if type(f) ~= "table" then return "nothing" end
	local name = str(callm(f, "GetName"))
	local tex = type(rawget(f, "glyph")) == "table" and str(callm(rawget(f, "glyph"), "GetTextureFilePath")) or nil
	return (name or tex or str(callm(f, "GetObjectType")) or "a frame") .. " (strata " .. tostring(callm(f, "GetFrameStrata")) .. ", level "
		.. tostring(callm(f, "GetFrameLevel")) .. ")"
end
-- is this control the top Wuber frame at its own centre? -> true | false, why | nil, why (cannot judge)
local function topAtCentre(w, ctl, what)
	if not isTrue(ctl, "IsVisible") then return nil, what .. " is not shown" end
	if not isTrue(ctl, "IsMouseEnabled") then return false, what .. " does not take the mouse" end
	local r = rectOf(ctl, w.up)
	if not r then return nil, what .. " has no place yet" end
	local x, y = (r.l + r.r) / 2, (r.b + r.t) / 2
	local hits = framesAt(w, x, y)
	if #hits == 0 then return false, "no mouse-enabled Wuber frame is at the centre of " .. what end
	if within(w, hits[1], ctl) then return true end
	return false, ("the top Wuber frame at the centre of %s is %s, not %s"):format(what, nameOfFrame(hits[1]), nameOfFrame(ctl))
end

---------------------------------------------------------------------------
-- a_settings_asks: Settings' search, Report a bug, /wuber emblem off, the back arrow
---------------------------------------------------------------------------

local QUESTION = "how do I turn off sounds?"
local MATCH_LABEL = "Sounds"

local function backArrows(w)
	local out = {}
	for _, f in ipairs(w.list) do
		if w.owned(f) and callm(f, "GetObjectType") == "Button" and isTrue(f, "IsVisible") and isBackArrow(f) then out[#out + 1] = f end
	end
	return out
end

local function sectionName(W, key)
	local P2 = modOf(W, "UI.Settings.Panel")
	for _, s in ipairs(P2 and type(P2.SECTIONS) == "table" and P2.SECTIONS or {}) do
		if s[1] == key then return s[2] end
	end
	return nil
end

screen({ id = "a_settings_asks", side = "settings",
	title = "Settings: a question in the search box, the bug report's words, /wuber emblem off, the back arrow takes the mouse",
	covers = { any = { verify = { "PR-79", "PR-78", "PR-50", "PR-62" } } },
	run = function(W)
		return P.settings(W, function(UI) return true end)
	end,
	post = function(W)
		local d = data()
		d.sa = {}
		local sa = d.sa
		-- PR-79: the question
		guarded(sa, "ask", function()
			local st = settingsOf(W)
			local f = st and type(st.find) == "table" and st.find
			local eb = f and type(f.box) == "table" and f.box.edit
			local Pan = modOf(W, "UI.Settings.Panel")
			if type(eb) ~= "table" or not Pan then sa.ask = { none = true } return end
			pcall(eb.SetText, eb, QUESTION)
			local changed = script(eb, "OnTextChanged")
			if changed then pcall(changed, eb, true) end
			local a = { typed = textOf(eb) }
			for i, b in ipairs(type(f.items) == "table" and f.items or {}) do
				local m = type(b) == "table" and b.m
				if shown(b) and type(m) == "table" and m.label == MATCH_LABEL then
					a.row = { label = m.label, where = textOf(b.where), want = sectionName(W, m.key), i = i }
					break
				end
			end
			a.count = f.count
			sa.ask = a
			if Pan and fn(Pan, "search") then pcall(Pan.search, "") end
			if fn(eb, "ClearFocus") then pcall(eb.ClearFocus, eb) end
		end)
		-- PR-78: the report's words (one default setting is changed for a moment, then put back)
		guarded(sa, "bug", function()
			local B = type(W.UI) == "table" and W.UI.Bug
			if type(B) ~= "table" or not fn(B, "Report") then sa.bug = { none = true } return end
			local key, old
			for k, v in pairs(type(W.DEFAULTS) == "table" and W.DEFAULTS or {}) do
				if type(v) == "boolean" and type(W.db) == "table" and W.db[k] == v and k ~= "advanced" and (not key or k < key) then key = k end
			end
			if key then old = W.db[key] W.db[key] = not old end
			local ok, text = pcall(B.Report, "check")
			if key then W.db[key] = old end
			sa.bug = { text = ok and str(text) or nil, key = key, flipped = key and tostring(not old) or nil }
		end)
		-- PR-50: /wuber emblem off with Settings open
		guarded(sa, "emblem", function()
			local st = settingsOf(W)
			local sw = st and type(st.controls) == "table" and st.controls.plates
			local slash = type(rawget(_G, "SlashCmdList")) == "table" and rawget(_G, "SlashCmdList")["WUBER"]
			if type(sw) ~= "table" or type(slash) ~= "function" then sa.emblem = { none = true } return end
			local e = { before = sw.on, dbBefore = type(W.db) == "table" and W.db.emblems }
			if sw.on ~= true then sa.emblem = e e.notOn = true return end
			pcall(slash, "emblem off")
			e.after = sw.on
			pcall(slash, "emblem on")
			e.back = sw.on
			sa.emblem = e
		end)
		-- PR-62: the back arrow of the pushed Settings page
		guarded(sa, "back", function()
			local w = gather(W)
			local arrows = backArrows(w)
			if #arrows == 0 then sa.back = { none = true } return end
			table.sort(arrows, function(a, b) return hitKey(a) > hitKey(b) end)
			local ok, why = topAtCentre(w, arrows[1], "the back arrow")
			sa.back = { ok = ok, why = why, n = #arrows, frames = #w.list }
		end)
		return true
	end,
	verify = function()
		local sa = data().sa
		if not sa then return "skip", "the Settings screen did not set up" end
		local out = {}
		local function broke(key, name, step)
			local x = sa[key]
			if type(x) == "table" and x.broke then out[#out + 1] = result(name, "look", "the check itself broke: " .. x.broke, step) return true end
			if type(x) == "table" and x.none then out[#out + 1] = result(name, "skip", "this Wuber has no such widget the check knows", step) return true end
			return false
		end
		if not broke("ask", "question in the search box", "PR-79") then
			local a = sa.ask
			if not a.row then
				out[#out + 1] = result("question in the search box", "look", ('"%s" shows no "%s" row (%s rows)'):format(QUESTION, MATCH_LABEL, tostring(a.count)), "PR-79")
			elseif not a.row.where or a.row.where == "" or (a.row.want and not a.row.where:find(a.row.want, 1, true)) then
				out[#out + 1] = result("question in the search box", "look", ('the "%s" row does not name its section "%s": it says "%s"'):format(MATCH_LABEL, tostring(a.row.want), tostring(a.row.where)), "PR-79")
			else
				out[#out + 1] = result("question in the search box", "pass", ('"%s" shows the "%s" row, in %s'):format(QUESTION, MATCH_LABEL, a.row.where), "PR-79")
			end
		end
		if not broke("bug", "report a bug words", "PR-78") then
			local b = sa.bug
			local t = b.text or ""
			local miss = {}
			if not t:find("\nCharacter: %u+ level %d+") then miss[#miss + 1] = "class and level"
			end
			local cs = t:match("\nChanged settings:\n(.-)\n\n") or t:match("\nChanged settings:\n(.-)\n%S") or ""
			if b.key and not cs:find("  " .. b.key .. " = " .. tostring(b.flipped), 1, true) then miss[#miss + 1] = "the changed setting " .. b.key end
			if not t:find("\nOther addons: %d+ loaded") then miss[#miss + 1] = "the other-addons line" end
			if #miss == 0 then
				out[#out + 1] = result("report a bug words", "pass", "the report has class and level, the changed settings and the other-addons line", "PR-78")
			else
				out[#out + 1] = result("report a bug words", "look", "the report lacks: " .. table.concat(miss, ", "), "PR-78")
			end
		end
		if not broke("emblem", "emblem off with Settings open", "PR-50") then
			local e = sa.emblem
			if e.notOn then
				out[#out + 1] = result("emblem off with Settings open", "skip", "Badges over heads is already off, so the switch cannot show the change", "PR-50")
			elseif e.after == false and e.back == true then
				out[#out + 1] = result("emblem off with Settings open", "pass", 'after /wuber emblem off the "Badges over heads" row shows OFF; after emblem on it shows ON again', "PR-50")
			else
				out[#out + 1] = result("emblem off with Settings open", "look", ('after /wuber emblem off the "Badges over heads" row shows %s (it should show OFF); after emblem on it shows %s'):format(
					e.after == true and "ON" or "something else", e.back == true and "ON" or "OFF"), "PR-50")
			end
		end
		if not broke("back", "back arrow takes the mouse", "PR-62") then
			local b = sa.back
			if b.ok == true then
				out[#out + 1] = result("back arrow takes the mouse", "pass", "at the centre of the back arrow it is the top mouse-enabled Wuber frame (computed from strata, level, hit rectangle and clipping; a real click is not made)", "PR-62")
			elseif b.ok == nil then
				out[#out + 1] = result("back arrow takes the mouse", "skip", tostring(b.why), "PR-62")
			else
				out[#out + 1] = result("back arrow takes the mouse", "look", tostring(b.why), "PR-62")
			end
		end
		return out
	end })

---------------------------------------------------------------------------
-- BACK-REAL: the topmost mouse frame at the back arrow's centre IS the arrow, and ITS OnClick changes the page
---------------------------------------------------------------------------
-- (T243-1: the header drag strip took every real click on the arrows because the old finder compared GetTexture() with a name.)
-- Same ranking as above; the click is the OnClick of whatever is on top, never of the arrow itself. Each page is read after the slide:
-- Settings from the Drive cog opens at a section, so the arrow is clicked again until none shows (3 clicks at most).
local BACKREAL_STEP = "BACK-REAL"
local BACKREAL_SETTLE = 0.8
local backReal = {}

local function backRealClick(W, label, closed)
	local p = { name = "back arrow, real click: " .. label, clicks = 0, closed = closed }
	backReal[#backReal + 1] = p
	local timer = rawget(_G, "C_Timer")
	local function step()
		local ok, err = pcall(function()
			local w = gather(W)
			local arrows = backArrows(w)
			-- (T243 round 2) a chain on Settings stops once Settings is shut: an arrow showing then is the next page's (Your crew opens
			-- while this chain's last read is still to come), and clicking it would put that page away before its own check looks
			if closed and p.clicks > 0 and #arrows > 0 and type(W.UI) == "table" and fn(W.UI, "SettingsShown") and W.UI.SettingsShown() ~= true then
				p.done = true
				return
			end
			if #arrows == 0 then
				p.done = true
				if closed and type(W.UI) == "table" and fn(W.UI, "SettingsShown") and W.UI.SettingsShown() == true then
					p.fail = "no back arrow shows but Settings is still open"
				end
				return
			end
			if p.clicks >= 3 then p.fail = "a back arrow is still there after 3 clicks" return end
			table.sort(arrows, function(a, b) return hitKey(a) > hitKey(b) end)
			local a = arrows[1]
			local r = rectOf(a, w.up)
			if not r then p.fail = "the back arrow has no place yet" return end
			local hits = framesAt(w, (r.l + r.r) / 2, (r.b + r.t) / 2)
			local top = hits[1]
			if not top then p.fail = "no mouse-enabled Wuber frame is at the centre of the back arrow" return end
			if not within(w, top, a) then
				p.fail = ("a click at the centre of the back arrow lands on %s, not on the arrow"):format(nameOfFrame(top))
				return
			end
			local h = script(top, "OnClick")
			if not h then p.fail = "the frame on top has no OnClick" return end
			p.clicks = p.clicks + 1
			h(top, "LeftButton")
			if type(timer) == "table" and fn(timer, "After") then timer.After(BACKREAL_SETTLE, step) else p.fail = "no timer to wait for the slide" end
		end)
		if not ok then p.fail = "the check broke: " .. tostring(err):sub(1, 160) end
	end
	step()
end

local function backRealRows()
	local out = {}
	for _, p in ipairs(backReal) do
		if p.fail then out[#out + 1] = result(p.name, "look", "FAIL: " .. p.fail, BACKREAL_STEP)
		elseif p.done and p.clicks > 0 then
			out[#out + 1] = result(p.name, "pass", ("the arrow was the top frame at its centre; the OnClick of that frame (%d click%s) put the page away"):format(p.clicks, p.clicks == 1 and "" or "s"), BACKREAL_STEP)
		elseif p.done then out[#out + 1] = result(p.name, "skip", "no back arrow showed on this page", BACKREAL_STEP)
		else out[#out + 1] = result(p.name, "skip", "the page after the click was not read in time", BACKREAL_STEP) end
	end
	backReal = {}
	return out
end

local function driveSettingsRun(W)
	local UI = W.UI
	if type(UI) ~= "table" or not fn(UI, "SelectTab") then return "W.UI.SelectTab is missing" end
	UI.SelectTab("Drive")
	if not UI.OpenSettings() then return "Settings did not open from the Drive tab" end
	return true
end
for _, d in ipairs({
	{ "a_backreal_ride", "Settings from Ride", runOf("settings"), true, true },
	{ "a_backreal_drive", "Settings from the Drive cog", function(W)
		local r = runOf("settings")(W)
		if r ~= true and r ~= nil then return r end
		return driveSettingsRun(W)
	end, true, true },
	{ "a_backreal_crew", "Drive > Your crew", runOf("crew"), nil, false },
}) do
	screen({ id = d[1], side = "settings", unfold = d[4], title = "Back arrow, real click: " .. d[2] .. " (the top frame at the arrow's centre is the arrow and its click goes back)",
		run = d[3],
		verify = function(W)
			local rows = backRealRows() -- the page clicked on the screen before has settled by now
			backRealClick(W, d[2], d[5])
			return rows
		end })
end
screen({ id = "a_backreal_last", side = "settings", title = "Back arrow, real click: the last page, read after the slide",
	run = function(W) return runOf("home")(W) end,
	verify = function() return backRealRows() end })

---------------------------------------------------------------------------
-- a_driver_hits: Enter in the block-reason box, the Drive switch
---------------------------------------------------------------------------

local REASON = "lab check"

-- the blocklist table that holds key inside the saved data, or nil
local function blocklistHolding(key)
	local db = rawget(_G, "WuberDB")
	local seen = {}
	local function walk(t, depth)
		if type(t) ~= "table" or seen[t] or depth > 5 then return nil end
		seen[t] = true
		local bl = rawget(t, "blocklist")
		if type(bl) == "table" and bl[key] ~= nil then return bl end
		for _, v in pairs(t) do
			if type(v) == "table" then
				local r = walk(v, depth + 1)
				if r then return r end
			end
		end
		return nil
	end
	return walk(db, 0)
end

screen({ id = "a_driver_hits", side = "driver",
	title = "Drive: Enter in the block-reason box blocks the rider, and the Drive switch takes the mouse",
	covers = { any = { verify = { "PR-97", "PR-62" } } },
	run = function(W)
		return P.openConsole(W)
	end,
	post = function(W)
		local d = data()
		d.dh = {}
		local dh = d.dh
		local D = W.Driver
		-- PR-62: the Drive switch, both halves
		guarded(dh, "switch", function()
			local v = type(D) == "table" and type(D.ui) == "table" and D.ui.console
			local seg = type(v) == "table" and v.modeBar
			if type(seg) ~= "table" then dh.switch = { none = true } return end
			local btns = type(seg.buttons) == "table" and seg.buttons or {}
			if callm(seg, "IsVisible") ~= true or #btns == 0 then dh.switch = { hidden = true } return end
			local w = gather(W)
			local res = {}
			for i, b in ipairs(btns) do
				local ok, why = topAtCentre(w, b, "the Drive switch (part " .. i .. ")")
				res[#res + 1] = { ok = ok, why = why }
			end
			dh.switch = { res = res }
		end)
		-- PR-97: Enter in the block-reason box
		guarded(dh, "block", function()
			local DR = W.Drive
			local c = type(DR) == "table" and type(DR.customers) == "table" and DR.customers["dan rider"]
			if type(c) ~= "table" or not fn(D, "OpenMenu") or not fn(DR, "BlockEntry") then dh.block = { none = true } return end
			local key = c.key
			local had = DR.BlockEntry(key)
			if had then dh.block = { had = true } return end
			D.OpenMenu(c)
			local dv = type(W.UI) == "table" and W.UI.drive
			local s = type(dv) == "table" and (dv.menu or (type(dv.screens) == "table" and dv.screens.menu) or (type(dv.sheets) == "table" and dv.sheets.menu))
			if type(s) ~= "table" or not fn(s, "pick") or type(s.reason) ~= "table" then dh.block = { none = true } return end
			s.pick("block")
			local eb = s.reason.edit
			local b = { key = key }
			pcall(eb.SetText, eb, REASON)
			local enter = script(eb, "OnEnterPressed")
			if not enter then b.noEnter = true else b.ok, b.err = pcall(enter, eb) end
			local e = DR.BlockEntry(key)
			b.blocked = e ~= nil
			b.reason = e and e.reason
			b.saved = blocklistHolding(key) ~= nil
			b.closed = not (fn(D, "SheetOpen") and D.SheetOpen())
			-- put it back: the rider is not blocked, nothing was sent (the tour has every sender stubbed)
			local holder = blocklistHolding(key)
			if holder then holder[key] = nil end
			if type(DR.refusals) == "table" then DR.refusals[key] = nil end
			if type(DR.ignored) == "table" then DR.ignored[key] = nil end
			dh.block = b
		end)
		return true
	end,
	verify = function()
		local dh = data().dh
		if not dh then return "skip", "the Drive screen did not set up" end
		local out = {}
		local bl = dh.block
		if type(bl) ~= "table" then bl = { none = true } end
		if bl.broke then out[#out + 1] = result("Enter blocks the rider", "look", "the check itself broke: " .. bl.broke, "PR-97")
		elseif bl.none then out[#out + 1] = result("Enter blocks the rider", "skip", "no demo rider or no rider menu with a block box on this screen", "PR-97")
		elseif bl.had then out[#out + 1] = result("Enter blocks the rider", "skip", "the demo rider is already blocked", "PR-97")
		elseif bl.noEnter then out[#out + 1] = result("Enter blocks the rider", "look", "the block-reason box has no OnEnterPressed handler", "PR-97")
		elseif bl.ok == false then out[#out + 1] = result("Enter blocks the rider", "look", "Enter in the box broke: " .. tostring(bl.err), "PR-97")
		elseif not bl.blocked then out[#out + 1] = result("Enter blocks the rider", "look", "Enter in the block-reason box did not block the rider", "PR-97")
		elseif not bl.saved then out[#out + 1] = result("Enter blocks the rider", "look", "Enter blocked the rider but the block is not in WuberDB", "PR-97")
		elseif bl.reason ~= REASON then out[#out + 1] = result("Enter blocks the rider", "look", ('the block has the reason "%s", not the typed "%s"'):format(tostring(bl.reason), REASON), "PR-97")
		elseif not bl.closed then out[#out + 1] = result("Enter blocks the rider", "look", "Enter blocked the rider but the sheet stayed open", "PR-97")
		else out[#out + 1] = result("Enter blocks the rider", "pass", "Enter in the block-reason box blocked the rider with the typed reason, in WuberDB, and shut the sheet (put back after)", "PR-97") end
		local sw = dh.switch
		if type(sw) ~= "table" then sw = { none = true } end
		if sw.broke then out[#out + 1] = result("Drive switch takes the mouse", "look", "the check itself broke: " .. sw.broke, "PR-62")
		elseif sw.none then out[#out + 1] = result("Drive switch takes the mouse", "skip", "this Drive screen has no switch the check knows", "PR-62")
		elseif sw.hidden then out[#out + 1] = result("Drive switch takes the mouse", "skip", "the Drive switch is not shown on this screen", "PR-62")
		else
			local bad, nil_ = {}, nil
			for _, r in ipairs(sw.res) do
				if r.ok == false then bad[#bad + 1] = r.why elseif r.ok == nil then nil_ = r.why end
			end
			if #bad > 0 then out[#out + 1] = result("Drive switch takes the mouse", "look", table.concat(bad, "; "), "PR-62")
			elseif nil_ then out[#out + 1] = result("Drive switch takes the mouse", "skip", nil_, "PR-62")
			else out[#out + 1] = result("Drive switch takes the mouse", "pass", "at the centre of each half of the Drive switch it is the top mouse-enabled Wuber frame (computed; a real click is not made)", "PR-62") end
		end
		return out
	end })

---------------------------------------------------------------------------
-- a_pill_hit: the ride pill
---------------------------------------------------------------------------

local function pillOf(W)
	local st = uiState(W)
	local ph = st and st.phone
	local isl = type(ph) == "table" and ph.island
	return type(isl) == "table" and isl or nil
end
-- the pill's drawn rectangle: the union of its three fill parts
local function pillArt(isl, up)
	local fill = type(isl.fill) == "table" and isl.fill
	local u
	for _, t in ipairs(fill and type(fill.parts) == "table" and fill.parts or {}) do
		local r = rectOf(t, up)
		if r then
			u = u or { l = r.l, b = r.b, r = r.r, t = r.t }
			u.l, u.b, u.r, u.t = math.min(u.l, r.l), math.min(u.b, r.b), math.max(u.r, r.r), math.max(u.t, r.t)
		end
	end
	return u
end
local function pillRead(W, d)
	local isl = pillOf(W)
	if not isl then return { none = true } end
	local w = gather(W)
	local p = { shown = callm(isl, "IsVisible") == true, mouse = callm(isl, "IsMouseEnabled") == true }
	local r = rectOf(isl, w.up)
	if r then
		local il, ir, it, ib = callm(isl, "GetHitRectInsets")
		p.insets = (num(il) or 0) + (num(ir) or 0) + (num(it) or 0) + (num(ib) or 0)
		local art = pillArt(isl, w.up)
		if art then
			p.art = art
			p.off = math.max(math.abs(art.l - r.l - (num(il) or 0)), math.abs(art.r - r.r + (num(ir) or 0)),
				math.abs(art.t - r.t + (num(it) or 0)), math.abs(art.b - r.b - (num(ib) or 0)))
		end
		local x, y = (r.l + r.r) / 2, (r.b + r.t) / 2
		local hits = framesAt(w, x, y)
		p.top = hits[1]
		p.topIsPill = hits[1] ~= nil and within(w, hits[1], isl)
		p.topName = nameOfFrame(hits[1])
	end
	return p
end

screen({ id = "a_pill_hit", side = "rider", maxWait = 6,
	title = "Ride page: the ride pill takes a click only where it shows something new, and its hit rectangle is the pill",
	covers = { any = { verify = { "PR-45" } } },
	run = function(W)
		data().pill = { phase = 0 }
		return runOf("tracker")(W)
	end,
	ready = function(W)
		local d = data().pill
		if not d or d.phase == 2 then return true end
		local UI = W.UI
		if d.phase == 0 then
			guarded(d, "own", function() d.own = pillRead(W, d) end)
			if not fn(UI, "SelectTab") then d.noTab = true d.phase = 2 return true end
			UI.SelectTab("Trips")
			d.t1, d.phase = clock(), 1
			return false
		end
		if clock() - d.t1 >= 0.8 then
			guarded(d, "other", function() d.other = pillRead(W, d) end)
			if fn(UI, "SelectTab") then UI.SelectTab("Ride") end
			d.phase = 2
			return true
		end
		return false
	end,
	verify = function()
		local d = data().pill
		if not d then return "skip", "the ride screen did not set up" end
		local o, a = d.own, d.other
		if d.noTab or type(o) ~= "table" or type(a) ~= "table" or o.none or a.none then
			return "skip", "this Wuber has no ride pill (UI.state.phone.island) or no tab to leave the ride for"
		end
		if o.broke or a.broke then return "look", "the check itself broke: " .. tostring(o.broke or a.broke) end
		if not (o.shown and a.shown) then return "skip", "no ride pill showed (no ride under way in this screen)" end
		local out = {}
		if o.mouse or o.topIsPill then
			out[#out + 1] = result("pill on the ride's own screen", "look", "the ride is already on screen and the pill still takes the mouse: a click on it shows nothing new", "PR-45")
		else
			out[#out + 1] = result("pill on the ride's own screen", "pass", "on the ride's own screen the pill takes no click", "PR-45")
		end
		if not a.mouse then
			out[#out + 1] = result("pill on another tab", "look", "on another tab the pill does not take the mouse, so a click cannot bring back the ride", "PR-45")
		elseif not a.topIsPill then
			out[#out + 1] = result("pill on another tab", "look", "the top Wuber frame at the centre of the pill is " .. tostring(a.topName), "PR-45")
		elseif a.off == nil then
			out[#out + 1] = result("pill on another tab", "skip", "the pill's drawn parts have no place to compare with", "PR-45")
		elseif a.off > 1 then
			out[#out + 1] = result("pill on another tab", "look", ("the pill's hit rectangle differs from the drawn pill by %.1f units"):format(a.off), "PR-45")
		else
			out[#out + 1] = result("pill on another tab", "pass", "on another tab the pill takes the mouse, is on top at its centre, and its hit rectangle is the drawn pill (computed; a real click is not made)", "PR-45")
		end
		return out
	end })

---------------------------------------------------------------------------
-- a_rider_checks: Trips count, the celebration card, a price tag and its aura
---------------------------------------------------------------------------

local function tripRow(n, unpaid)
	return { at = 1700000000 + n * 86400, driver = "Demo Driver " .. n, driverKey = "demo driver " .. n, dest = "Orgrimmar", price = 5000 * n,
		stars = 5, unpaid = unpaid or nil }
end

-- the function the tour replaced with a sink, as it was before (the tour keeps it to put back)
local function originalOf(tbl, key)
	local t = K.tour()
	for _, s in ipairs(t and type(t.saved) == "table" and t.saved or {}) do
		if s[1] == tbl and s[2] == key and type(s[3]) == "function" then return s[3] end
	end
	return tbl[key]
end

local PRICES = { 100, 5000, 25000, 120000, 9990000 }
local function overlaps(a, b)
	return not (a.r <= b.l + 0.5 or b.r <= a.l + 0.5 or a.t <= b.b + 0.5 or b.t <= a.b + 0.5)
end

screen({ id = "a_rider_checks", side = "rider",
	title = "Trips: the count is paid rides only, the celebration card opens Trips, a map price tag is clear of its glow",
	covers = { any = { verify = { "PR-116", "PR-115", "PR-48" } } },
	run = runOf("trips"),
	post = function(W)
		local d = data()
		d.rc = {}
		local rc = d.rc
		local UI = W.UI
		-- PR-116: three paid trips and two unpaid
		guarded(rc, "trips", function()
			local TM = modOf(W, "UI.Rider.Trips")
			local tr = TM and fn(TM, "view") and TM.view()
			if type(W.db) ~= "table" or type(tr) ~= "table" or not fn(W, "RebuildTotals") or not fn(UI, "UpdateTrips") then rc.trips = { none = true } return end
			local oldRides, oldTotals = W.db.rides, W.db.totals
			W.db.rides = { tripRow(1), tripRow(2, true), tripRow(3), tripRow(4, true), tripRow(5) }
			W.db.totals = nil
			local t = {}
			local okR, errR = pcall(W.RebuildTotals)
			if okR then
				pcall(UI.UpdateTrips)
				t.count = textOf(tr.hCount)
				local s = fn(W, "Stats") and W.Stats()
				t.stats = type(s) == "table" and num(s.rides) or nil
				local tp = fn(W, "TierProgress") and { W.TierProgress() }
				t.tier = tp and num(tp[2]) or nil
			else
				t.err = tostring(errR)
			end
			W.db.rides, W.db.totals = oldRides, oldTotals
			pcall(UI.UpdateTrips)
			rc.trips = t
		end)
		-- PR-115: the celebration card, from another tab; its own OnClick
		guarded(rc, "pop", function()
			local st = uiState(W)
			if not st or not fn(UI, "Celebrate") or not fn(UI, "ShowNextPop") or not fn(UI, "SelectTab") then rc.pop = { none = true } return end
			UI.SelectTab("Ride")
			local sinkPop, sinkCelebrate = UI.ShowNextPop, UI.Celebrate
			local realPop, realCelebrate = originalOf(UI, "ShowNextPop"), originalOf(UI, "Celebrate")
			UI.ShowNextPop, UI.Celebrate = realPop, realCelebrate
			local okC, errC = pcall(realCelebrate, "firstride", { "firstride" })
			local pop = st.pop
			local p = { okC = okC, err = not okC and tostring(errC) or nil, shown = shown(pop) }
			if p.shown then
				local click = script(pop, "OnClick")
				if click then
					local okK, errK = pcall(click, pop, "LeftButton", false)
					p.clicked, p.errK = okK, not okK and tostring(errK) or nil
				else
					p.noClick = true
				end
				p.tab = st.tab
				p.open = fn(UI, "IsShown") and UI.IsShown() == true
				pcall(pop.Hide, pop)
			end
			-- the tour's sinks are back exactly as they were
			UI.ShowNextPop, UI.Celebrate = sinkPop, sinkCelebrate
			rc.pop = p
		end)
		-- PR-48: a scratch pin, each price: the tag is clear of the aura frame
		guarded(rc, "pin", function()
			local PM = modOf(W, "UI.Map.Pins")
			local upf = rawget(_G, "UIParent")
			if not (PM and fn(PM, "NewPin") and fn(PM, "Paint") and type(upf) == "table" and type(rawget(_G, "CreateFrame")) == "function") then rc.pin = { none = true } return end
			local holder = L.pinHolder
			if not holder then
				holder = CreateFrame("Frame", nil, upf)
				holder:SetSize(600, 400)
				holder:SetPoint("CENTER", upf, "CENTER", 0, 0)
				L.pinHolder = holder
			end
			holder:Show()
			local up = num(callm(upf, "GetEffectiveScale")) or 1
			local pin = L.pinScratch
			if not pin then
				pin = PM.NewPin(holder)
				pin:SetPoint("CENTER", holder, "CENTER", 0, 0)
				L.pinScratch = pin
			end
			pin:Show()
			pin.key, pin.nx, pin.ny = "labcheck", 0.5, 0.5
			local rows = {}
			for _, price in ipairs(PRICES) do
				local okP, errP = pcall(PM.Paint, pin, { key = "labcheck", name = "Lab Check", service = "Z", state = "open", price = price, dest = "Ratchet", team = 1, seats = 4 }, true, 0, false)
				local ring = type(pin.auraRing) == "table" and pin.auraRing.frame
				local row = { price = price, ok = okP, err = not okP and tostring(errP) or nil }
				if okP and shown(pin.tag) and type(ring) == "table" and shown(ring) then
					local tr, ar = rectOf(pin.tag, up), rectOf(ring, up)
					if tr and ar then row.over = overlaps(tr, ar) row.measured = true end
				end
				rows[#rows + 1] = row
			end
			holder:Hide()
			rc.pin = { rows = rows }
		end)
		return true
	end,
	verify = function()
		local rc = data().rc
		if not rc then return "skip", "the Trips screen did not set up" end
		local out = {}
		local function bad(key, name, step)
			local x = rc[key]
			if type(x) == "table" and x.broke then out[#out + 1] = result(name, "look", "the check itself broke: " .. x.broke, step) return true end
			if type(x) ~= "table" or x.none then out[#out + 1] = result(name, "skip", "this Wuber has no such widget the check knows", step) return true end
			return false
		end
		if not bad("trips", "Trips count is paid rides only", "PR-116") then
			local t = rc.trips
			if t.err then out[#out + 1] = result("Trips count is paid rides only", "look", "the totals could not be worked out: " .. t.err, "PR-116")
			elseif t.count == "3 trips" and t.stats == 3 and (t.tier == nil or t.tier == 3) then
				out[#out + 1] = result("Trips count is paid rides only", "pass", "5 trips saved, 2 unpaid: the Trips page says 3 trips and 3 rides (put back after)", "PR-116")
			else
				out[#out + 1] = result("Trips count is paid rides only", "look", ("5 trips saved, 2 unpaid: the Trips list says %s, the stats count %s rides, the level counts %s (3 paid rides expected)"):format(
					tostring(t.count), tostring(t.stats), tostring(t.tier)), "PR-116")
			end
		end
		if not bad("pop", "celebration card opens Trips", "PR-115") then
			local p = rc.pop
			if not p.okC then out[#out + 1] = result("celebration card opens Trips", "look", "the card could not be raised: " .. tostring(p.err), "PR-115")
			elseif not p.shown then out[#out + 1] = result("celebration card opens Trips", "skip", "the card did not show (held for a ride or combat)", "PR-115")
			elseif p.noClick then out[#out + 1] = result("celebration card opens Trips", "look", "the card has no click handler", "PR-115")
			elseif p.clicked == false then out[#out + 1] = result("celebration card opens Trips", "look", "the card's click broke: " .. tostring(p.errK), "PR-115")
			elseif p.tab == "Trips" and p.open then out[#out + 1] = result("celebration card opens Trips", "pass", "the card's own click opened Wuber on Trips (the click is made on its handler, not with a real mouse)", "PR-115")
			else out[#out + 1] = result("celebration card opens Trips", "look", ("after the card's click Wuber is on the %s tab, %s"):format(tostring(p.tab), p.open and "open" or "not open"), "PR-115") end
		end
		if not bad("pin", "price tag clear of its glow", "PR-48") then
			local worst, n, errs = {}, 0, {}
			for _, r in ipairs(rc.pin.rows) do
				if not r.ok then errs[#errs + 1] = r.err
				elseif r.measured then
					n = n + 1
					if r.over then worst[#worst + 1] = tostring(r.price) end
				end
			end
			if #errs > 0 then out[#out + 1] = result("price tag clear of its glow", "look", "a pin could not be painted: " .. tostring(errs[1]), "PR-48")
			elseif n == 0 then out[#out + 1] = result("price tag clear of its glow", "skip", "the scratch pin showed no price tag and aura frame to measure", "PR-48")
			elseif #worst > 0 then out[#out + 1] = result("price tag clear of its glow", "look", "the price tag lies over its pin's aura frame at these prices (copper): " .. table.concat(worst, ", "), "PR-48")
			else out[#out + 1] = result("price tag clear of its glow", "pass", ("a price tag does not touch its pin's aura frame at %d prices (1s to 999g)"):format(n), "PR-48") end
		end
		return out
	end })

---------------------------------------------------------------------------
-- PR-76: saved data survived a restart (passive)
---------------------------------------------------------------------------
-- At PLAYER_LOGOUT: a canonical text of WuberDB (keys sorted, numbers as %.14g) is hashed twice (two moduli) and kept in
-- WuberLabDB.savedSum, per top-level key as well. At the next load of the Lab (ADDON_LOADED, after Wuber has filled its defaults
-- and before any login code has run) the same is worked out again and compared: the same -> pass, any difference -> look, naming the
-- top-level keys that differ. The kept sum is used once (a crash then gives "no sum", not a false look). A different Wuber version
-- between the two is not judged (the new version may add default keys). Result: WuberLabDB.autoCheck.steps["PR-76"] and a row in its
-- results (and again at the end of every Auto check, which replaces that table), plus the Game facts entry "PR-76".

local MOD_A, MOD_B = 2147483629, 2147483587
local function hashText(t)
	local a, b = 7, 11
	for i = 1, #t do
		local c = t:byte(i)
		a = (a * 131 + c) % MOD_A
		b = (b * 137 + c + i % 7) % MOD_B
	end
	return ("%d:%d:%d"):format(#t, a, b)
end
local function canon(v, out, seen, depth)
	local ty = type(v)
	if ty == "string" then
		out[#out + 1] = ("%q"):format(v)
	elseif ty == "number" then
		out[#out + 1] = ("%.14g"):format(v)
	elseif ty == "boolean" then
		out[#out + 1] = v and "true" or "false"
	elseif ty == "table" then
		if seen[v] or depth > 30 then out[#out + 1] = "<cycle>" return end
		seen[v] = true
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b)
			local ta, tb = type(a), type(b)
			if ta ~= tb then return ta < tb end
			if ta == "number" or ta == "string" then return a < b end
			return tostring(a) < tostring(b)
		end)
		out[#out + 1] = "{"
		for _, k in ipairs(keys) do
			out[#out + 1] = "["
			canon(k, out, seen, depth + 1)
			out[#out + 1] = "]="
			canon(v[k], out, seen, depth + 1)
			out[#out + 1] = ","
		end
		out[#out + 1] = "}"
		seen[v] = nil
	else
		out[#out + 1] = "<" .. ty .. ">"
	end
end
-- { all = hash of everything, keys = { top-level key -> hash } }
function L.SavedSum(db)
	if type(db) ~= "table" then return nil end
	local out = {}
	canon(db, out, {}, 0)
	local sum = { all = hashText(table.concat(out)), keys = {} }
	for k, v in pairs(db) do
		local o = {}
		canon(v, o, {}, 1)
		sum.keys[tostring(k)] = hashText(table.concat(o))
	end
	return sum
end

local function wuberVersion()
	local W = L.W and L.W()
	return W and str(W.VERSION) or nil
end

-- compare a kept sum with the saved data now -> status, detail
function L.SavedCompare(kept, db, version)
	if type(kept) ~= "table" or type(kept.sum) ~= "table" then return nil, "no checksum was kept at the last logout" end
	if kept.wuber and version and kept.wuber ~= version then return nil, ("Wuber changed from %s to %s since the last logout"):format(tostring(kept.wuber), tostring(version)) end
	local now = L.SavedSum(db)
	if not now then return "look", "WuberDB is not a table now" end
	if now.all == kept.sum.all then return "pass", "WuberDB read back as it was at the last logout (checksum " .. now.all .. ")" end
	local diff = {}
	for k, h in pairs(now.keys) do if kept.sum.keys[k] ~= h then diff[#diff + 1] = k end end
	for k in pairs(kept.sum.keys) do if now.keys[k] == nil then diff[#diff + 1] = k end end
	table.sort(diff)
	return "look", "WuberDB differs from the last logout in: " .. (#diff > 0 and table.concat(diff, ", ") or "its shape") .. " (checksum " .. now.all .. ", was " .. kept.sum.all .. ")"
end

local PR76 = "saved data survived a restart"
-- the result in the last Auto check's saved table, so the report shows it
local function putResult(status, detail)
	local db = L.db
	if type(db) ~= "table" then return end
	db.savedSurvived = { status = status, detail = detail, at = L.Epoch and L.Epoch() or 0, wuber = wuberVersion() }
	local ac = db.autoCheck
	if type(ac) == "table" then
		ac.steps = type(ac.steps) == "table" and ac.steps or {}
		ac.results = type(ac.results) == "table" and ac.results or {}
		ac.steps["PR-76"] = status
		local row
		for _, r in ipairs(ac.results) do if r.id == "a_saved_survived" then row = r break end end
		if not row then row = { id = "a_saved_survived", view = "login", kind = PR76 } ac.results[#ac.results + 1] = row end
		row.status, row.detail, row.steps = status, tostring(detail):sub(1, 900), "PR-76"
	end
end
function L.SavedPut(status, detail) putResult(status, detail) end

function L.SavedAtLogout()
	local db = L.db
	if type(db) ~= "table" then return false end
	local sum = L.SavedSum(rawget(_G, "WuberDB"))
	if not sum then db.savedSum = nil return false end
	db.savedSum = { sum = sum, wuber = wuberVersion(), at = L.Epoch and L.Epoch() or 0 }
	return true
end

function L.SavedAtLoad()
	local db = L.db
	if type(db) ~= "table" then return nil end
	local kept = db.savedSum
	db.savedSum = nil -- used once
	local status, detail = L.SavedCompare(kept, rawget(_G, "WuberDB"), wuberVersion())
	if not status then
		L.Log("auto", "saved data check not judged: " .. tostring(detail))
		return nil, detail
	end
	putResult(status, detail)
	L.Log("auto", ("%s %s %s: %s"):format(status == "look" and "LOOK" or status, "a_saved_survived", "login", detail))
	local G = L.GameFacts
	if type(G) == "table" and fn(G, "Put") then pcall(G.Put, "PR-76", PR76 .. ": " .. status .. " - " .. detail, { status = status }) end
	return status, detail
end

L.On("PLAYER_LOGOUT", function() pcall(L.SavedAtLogout) end)
L.On("ADDON_LOADED", function(name)
	if L.plain(name) ~= "WuberLab" then return end
	pcall(L.SavedAtLoad)
	-- an Auto check replaces autoCheck at its end: put the result in again (GameFacts.lua's instant part runs at the end of a run)
	local inst = L.GameFactsInstant
	if type(inst) == "function" and not L.savedWrapped then
		L.savedWrapped = true
		L.GameFactsInstant = function(...)
			local r = inst(...)
			local s = L.db and L.db.savedSurvived
			if type(s) == "table" and s.status then pcall(putResult, s.status, s.detail) end
			return r
		end
	end
end)


---------------------------------------------------------------------------
-- (job 2904) What the 2.4.4 round changed, walked by the Auto check: screens the tour did not reach, and the WATCH list
---------------------------------------------------------------------------
-- a_bird_card: Wuber's own "Skip the bird" card (its "Don't show again" link, #258) beside a stand-in for the flight map. The tour keeps
-- it behind a gate (it needs the flight map or a stand-in); the Auto check takes the stand-in version, hands off. Skipped, with the
-- reason, when the game has its own flight map open or no flight from here is long enough for a summon to beat it.
local function gatedShot(id)
	for _, g in ipairs(L.PHOTO_GATED or {}) do if g.id == id then return g end end
	return nil
end
screen({ id = "a_bird_card", side = "rider", noWin = true, maxWait = 6,
	title = "Skip the bird: Wuber's own card (Don't show again holds its words, the card is whole)",
	run = function(W, view)
		local g = gatedShot("bird_card_text")
		if not g then return "the tour has no bird_card_text shot" end
		local need = g.need and g.need(W)
		if need ~= true and need ~= nil then return tostring(need) end
		return g.run(W, view)
	end })

-- a_retire_card: the Drive console's card for a character that still has the old summoning addon on (#248): the card shows, its
-- "Switch it off and reload" pill's tooltip is read (the checks hover every shown pill). Nothing is pressed: that pill would switch
-- the other addon off.
screen({ id = "a_retire_card", side = "driver", maxWait = 6,
	title = "Drive console: the old summoning addon's card, its Switch it off pill and tooltip (hovered, never pressed)",
	run = function(W, view)
		local s = tourScreen("console_open")
		if not s then return "the tour has no screen console_open" end
		local DR = W.Drive
		if type(DR) ~= "table" or type(W.db) ~= "table" then return "no Drive module" end
		local r = s.run(W, view)
		-- after the console's own set-up (it puts the tour's stubs in place first): the old addon is on and its data was copied in
		K.stub(DR, "Lock", function() return "rr" end)
		if type(W.db.drive) ~= "table" then W.db.drive = {} end
		W.db.drive.imported = W.db.drive.imported or { at = 1 }
		W.db.drive.rrCard = nil
		local D = W.Driver
		if fn(D, "RefreshNow") then pcall(D.RefreshNow) end
		return r
	end,
	verify = function(W, view, X)
		local S = X.scan(W)
		local card = X.find(S, "Your old summoning addon is still on", true)
		if not card then return "look", "the card for the old summoning addon did not show (Lock rr, data imported)" end
		local go = X.find(S, "Switch it off and reload", true)
		if not go then return "look", "the Switch it off and reload pill is not drawn" end
		return "pass", "the old addon's card and its pill are drawn"
	end })

-- a variant of an Auto check screen with its state made first: the same set-up, the same checks
local function variant(baseId, id, title, pre, extra)
	local base
	for _, s in ipairs(SCREENS) do if s.id == baseId then base = s end end
	if not base then return nil end
	local s = {}
	for k, v in pairs(base) do s[k] = v end
	s.id, s.title, s.covers, s.steps = id, title, nil, nil
	for k, v in pairs(extra or {}) do s[k] = v end
	s.run = function(W, view)
		pre(W)
		return base.run(W, view)
	end
	return screen(s)
end
-- a_settings_adv: Settings home in Advanced mode: the Report a bug card (its tooltip's words changed, #2884 round)
variant("a_set_riding", "a_hidden_row", "Settings > Riding with one hidden driver: the Hidden drivers row and its Show all pill",
	function(W) if type(W.db) == "table" then W.db.hidden = { ["demo-realm"] = true } end end)
local advBase = tourScreen("settings")
if advBase then
	local s = {}
	for k, v in pairs(advBase) do s[k] = v end
	s.id, s.title, s.auto, s.covers = "a_settings_adv", "Settings home in Advanced mode: every card, the Report a bug card's tooltip", true, nil
	s.run = function(W, view)
		if type(W.db) == "table" then W.db.advanced = true end
		return advBase.run(W, view)
	end
	SCREENS[#SCREENS + 1] = s
end
-- a_coach_2: the first-open tip "Pick a driver" (its words changed)
screen({ id = "a_coach_2", side = "rider", maxWait = 6,
	title = "First-open tip 2 of 5: Pick a driver",
	run = function(W)
		local UI = W.UI
		if not (type(UI) == "table" and fn(UI, "CoachStep") and fn(UI, "ReplayCoach")) then return "no coach in this Wuber" end
		P.homeBase(W, P.demoDrivers())
		if type(W.db) == "table" then W.db.coach = false end
		if fn(UI, "Show") then pcall(UI.Show, "home") end
		pcall(UI.ReplayCoach)
		data().coach = { t0 = clock() }
		return true
	end,
	-- the tips start on a timer after Replay: go to the second one once the first is up, then let it settle
	ready = function(W)
		local d = data().coach
		if not d or d.done then return true end
		local ui = W.UI and W.UI.state
		local up = type(ui) == "table" and ui.coaching and type(ui.coach) == "table" and shown(ui.coach)
		if up and not d.went then
			pcall(W.UI.CoachStep, 2)
			d.went, d.t1 = true, clock()
			return false
		end
		if d.went and clock() - d.t1 >= 0.6 then d.done = true return true end
		if clock() - d.t0 > 4 then d.done = true return true end
		return false
	end })

-- a_tip_<id>: a first-open tip card whose words changed, shown as the login tip card (the tour's tipcard shot, with this tip as the
-- longest one): the card is whole and every line is drawn, not cut
for _, tid in ipairs({ "skip_the_bird", "drive_setup" }) do
	screen({ id = "a_tip_" .. tid, side = "rider", maxWait = 6,
		title = "Login tip card for the tip " .. tid .. " (its words changed in 2.4.4)",
		run = function(W, view)
			local s = tourScreen("tipcard")
			if not s then return "the tour has no screen tipcard" end
			local Tips, TT = modOf(W, "UI.Tips"), modOf(W, "UI.TipTexts")
			local tip
			for _, t in ipairs(TT and type(TT.list) == "table" and TT.list or {}) do if t.id == tid then tip = t end end
			if not tip then return "no tip " .. tid end
			if type(Tips) ~= "table" then return "no UI.Tips" end
			K.stub(Tips, "Longest", function() return tip end)
			return s.run(W, view)
		end })
end

---------------------------------------------------------------------------
-- a_pulse_ring: the "Waiting for riders" ring pulses once every 3 s (the play test said it flashed)
---------------------------------------------------------------------------
-- The open console with nobody in the list: the real game times the ring's alpha for about 9 s. Each time the alpha jumps up from a
-- faded ring a new ring starts; the gaps between starts must be about 3 s, with one ring only. Local only: no chat, no network, no click.
local RING_WATCH = 9.0
screen({ id = "a_pulse_ring", side = "driver", maxWait = 16,
	title = "Driver console: the Waiting for riders ring starts once every 3 seconds",
	run = function(W)
		data().ring = { phase = 0, starts = {}, samples = 0 }
		local r = runOf("console_open")(W)
		if r ~= true then return r end
		local DR = W.Drive
		if type(DR) == "table" and fn(DR, "Sorted") then K.stub(DR, "Sorted", function() return {} end) end
		local D = W.Driver
		if type(D) == "table" and fn(D, "RefreshNow") then D.RefreshNow() end
		return true
	end,
	ready = function(W)
		local d = data().ring
		if not d or d.phase == 2 then return true end
		local D = W.Driver
		local v = type(D) == "table" and type(D.ui) == "table" and D.ui.console or nil
		local pulse = type(v) == "table" and type(v.empty) == "table" and v.empty.pulse or nil
		local t = clock()
		if not d.t0 then d.t0 = t end
		guarded(d, "err", function()
			if type(pulse) ~= "table" or type(pulse.rings) ~= "table" or not pulse.rings[1] then d.none = true return end
			d.rings = #pulse.rings
			d.period = num(pulse.period)
			local a = num(callm(pulse.rings[1], "GetAlpha")) or 0
			d.samples = d.samples + 1
			d.peak = math.max(d.peak or 0, a)
			-- a start: the alpha rises again after it had faded (below a third of the peak so far)
			if d.last and a > d.last + 0.08 and d.low then
				d.starts[#d.starts + 1] = t
				d.low = false
			end
			if a < (d.peak or 0) / 3 then d.low = true end
			d.last = a
		end)
		if d.none or d.err or t - d.t0 >= RING_WATCH then d.phase = 2 return true end
		return false
	end,
	verify = function()
		local d = data().ring
		if not d then return "skip", "the console did not set up" end
		if d.err then return "look", "the check itself broke: " .. tostring(d.err.broke) end
		if d.none then return "skip", "no Waiting for riders ring on the console (UI.Driver ui.console.empty.pulse)" end
		if (d.peak or 0) <= 0 then return "skip", "the ring never showed any alpha (Reduce motion on, or the console is not open)" end
		local out = {}
		if d.rings ~= 1 then
			out[#out + 1] = result("one ring", "look", "the pulse has " .. tostring(d.rings) .. " rings, not one", nil)
		else
			out[#out + 1] = result("one ring", "pass", "the pulse has one ring", nil)
		end
		local n = #d.starts
		if n < 2 then
			out[#out + 1] = result("ring every 3 s", "look", ("only %d ring start(s) in %.0f s (%d samples, peak alpha %.2f): too slow or not measurable"):format(n, RING_WATCH, d.samples, d.peak or 0), nil)
		else
			local gap = (d.starts[n] - d.starts[1]) / (n - 1)
			if gap >= 2.6 and gap <= 3.4 then
				out[#out + 1] = result("ring every 3 s", "pass", ("a ring starts every %.2f s (%d starts, peak alpha %.2f)"):format(gap, n, d.peak or 0), nil)
			else
				out[#out + 1] = result("ring every 3 s", "look", ("a ring starts every %.2f s, not about 3 s (%d starts)"):format(gap, n), nil)
			end
		end
		return out
	end })

---------------------------------------------------------------------------
-- a_pulse_map: the rider Home map's you-dot ring pulses once every 3 s (the play test said the map pulse was too fast)
---------------------------------------------------------------------------
-- Same timing as a_pulse_ring, read from the Home map's you dot (UI state screens.home.map.me.pulse). Local only: no chat, no network, no click.
screen({ id = "a_pulse_map", side = "rider", maxWait = 16,
	title = "Home map: the you-dot ring starts once every 3 seconds",
	run = function(W)
		data().mring = { starts = {}, samples = 0 }
		return runOf("home_empty")(W)
	end,
	ready = function(W)
		local d = data().mring
		if not d or d.done then return true end
		local st = type(W.UI) == "table" and W.UI.state
		local hs = type(st) == "table" and type(st.screens) == "table" and st.screens.home
		local m = type(hs) == "table" and hs.map
		local pulse = type(m) == "table" and type(m.me) == "table" and m.me.pulse or nil
		local t = clock()
		if not d.t0 then d.t0 = t end
		guarded(d, "err", function()
			if type(pulse) ~= "table" or type(pulse.rings) ~= "table" or not pulse.rings[1] then d.none = true return end
			d.rings = #pulse.rings
			local a = num(callm(pulse.rings[1], "GetAlpha")) or 0
			d.samples = d.samples + 1
			d.peak = math.max(d.peak or 0, a)
			if d.last and a > d.last + 0.08 and d.low then
				d.starts[#d.starts + 1] = t
				d.low = false
			end
			if a < (d.peak or 0) / 3 then d.low = true end
			d.last = a
		end)
		if d.none or d.err or t - d.t0 >= RING_WATCH then d.done = true return true end
		return false
	end,
	verify = function()
		local d = data().mring
		if not d then return "skip", "the Home screen did not set up" end
		if d.err then return "look", "the check itself broke: " .. tostring(d.err.broke) end
		if d.none then return "skip", "no you-dot ring on the Home map (UI.state.screens.home.map.me.pulse)" end
		if (d.peak or 0) <= 0 then return "skip", "the ring never showed any alpha (Reduce motion on, or the map is not showing)" end
		local out = {}
		if d.rings ~= 1 then
			out[#out + 1] = result("one ring", "look", "the map pulse has " .. tostring(d.rings) .. " rings, not one", nil)
		else
			out[#out + 1] = result("one ring", "pass", "the map pulse has one ring", nil)
		end
		local n = #d.starts
		if n < 2 then
			out[#out + 1] = result("map ring every 3 s", "look", ("only %d ring start(s) in %.0f s (%d samples, peak alpha %.2f): too slow or not measurable"):format(n, RING_WATCH, d.samples, d.peak or 0), nil)
		else
			local gap = (d.starts[n] - d.starts[1]) / (n - 1)
			if gap >= 2.6 and gap <= 3.4 then
				out[#out + 1] = result("map ring every 3 s", "pass", ("a ring starts every %.2f s (%d starts, peak alpha %.2f)"):format(gap, n, d.peak or 0), nil)
			else
				out[#out + 1] = result("map ring every 3 s", "look", ("a ring starts every %.2f s, not about 3 s (%d starts)"):format(gap, n), nil)
			end
		end
		return out
	end })

-- the WATCH list (AutoCheck.lua): each thing the round changed, the words that must appear on a walked screen or in a tooltip, and the
-- screens that walk it. "tip": a tooltip a hover opened; "text": a drawn text. Judged at the end of a whole run.
local function watch(id, what, words, screens, on, steps)
	L.AUTO_WATCH[#L.AUTO_WATCH + 1] = { id = id, what = what, words = words, screens = screens, on = on, steps = steps }
end
watch("w258", "#258 Bird card: Don't show again", { "Don't show again" }, { "a_bird_card" }, "text")
watch("w259", "#259 World view: continent names", { "Eastern Kingdoms", "Kalimdor" }, { "worldmap", "worldmap_sea" }, "text")
watch("w260", "#260 Drive queue rows and the floating bar", nil, { "console_open", "float_queued", "float_queued_member", "customers_queued" })
watch("w261", "#261 Settings: Replay and Reset place buttons", { "Replay" }, { "a_set_window", "a_pos_reset" }, "text")
watch("w262", "#262 Places sheet: Where I stand", { "Where I stand" }, { "sheet_places" }, "text")
watch("w263", "#263 Home search: the Drivers to title", nil, { "home_search_long", "a_home_long", "home_search" })
watch("w264", "#264 Earnings: the target value", { "/ hour" }, { "earnings" }, "text")
watch("w266", "#266 Settings: Always narrow", { "Always narrow" }, { "a_set_window", "a_wide_reset" }, "text")
watch("w268", "#268 Bounty card: the Custom pick", { "Custom" }, { "home_bounty" }, "text")
watch("w265", "#265 Help: the whispers lines", { "Whispers are the backup" }, { "help" }, "text")
watch("w265b", "#265 Help: Wuber adds the [Wuber] tag", { "Wuber adds the [Wuber] tag" }, { "help" }, "text")
watch("w267", "#267 Messages lines (no-click promise)", { "Messages lines" }, { "a_welcome", "help" }, "text")
watch("w270", "#270 Group card sub line", nil, { "home_gf", "home_gf_busy", "gf_console_none" })
watch("w272", "#272 queue owes words", nil, { "float_summon_held", "console_summon_long" })
watch("w249", "#249 Group Finder note sheet", nil, { "sheet_gf_list" })
watch("w255", "#255 Big Drive button clear of the phone's controls", nil, { "earnings", "customers", "crew", "messages" })
watch("w248", "#248 Retire pill tooltip: type /reload", { "type /reload" }, { "a_retire_card" }, "tip")
watch("wcoach", "Coach tip: Click a card to see the fare", { "Click a card to see the fare, then Request summon" }, { "a_coach_2" }, "text")
watch("wcoachskip", "Coach: Skip tips tooltip", { "Settings > Riding > Tips > Replay" }, { "a_replay_tips" }, "tip")
watch("wwizard", "Crew wizard: Send offers tooltip", { "Yes or No thanks" }, { "wizard_noanswer_long", "crew_noanswer_long", "wizard_summoner" }, "tip")
watch("wbugcard", "Settings: Report a bug card's tooltip", { "player 1" }, { "a_settings_adv" }, "tip")
watch("whidden", "Settings: Hidden drivers row tooltip", { "In Advanced mode, right-click" }, { "a_hidden_row" }, "tip")
watch("wwhisper", "Settings: whisper Button tooltip", { "if your whispers do not go through" }, { "a_set_driving" }, "tip")
watch("wscale", "Settings: big button size and Fit tooltips", { "small screens" }, { "a_set_driving", "settings_merged_big" }, "tip")
watch("wkeep", "Settings: keep the big button tooltip", { "whether or not anyone is in your list" }, { "a_set_driving", "settings_merged_big" }, "tip")
watch("whelpfoot", "Help footer: the Messages lines you switch on", { "Messages lines you switch on" }, { "help" }, "text")
watch("wnews", "What's new 2.4: public chat buyers only if you switch that on", { "public chat buyers only if you switch that on" }, { "whatsnew_list" }, "text")
watch("wtipbird", "Tip skip_the_bird: the card that says Summon ... Fly", { "the card that says" }, { "a_tip_skip_the_bird" }, "text")
watch("wtipdrive", "Tip drive_setup: Set up driving", { "Set up driving" }, { "a_tip_drive_setup" }, "text")
