-- Wuber Lab (developer only, never ship): Focus.lua, the PASSIVE focus recorder (job 2630, item 02). DRAFT.
--
-- What it settles: what the real game says is under the mouse while Wuber is open, so the fake game's Client:frameAt (rectangles only: no
-- clipping, no hit-rect insets, no alpha) can be checked against it. Nobody has to do a step: the player just plays with Wuber open.
--
-- Which kind of check, and why: a PASSIVE check (like Passive.lua: runs while the player plays, off unless passive play is on), not an Auto
-- check (an Auto check has no mouse: it can call handlers but cannot put the cursor anywhere, so GetMouseFoci would only ever answer
-- "nothing") and not a recorder snapshot (WuberRec's one ticker runs every 1 s, too slow to catch a hover, and its README allows one frame
-- and one ticker). Passive.lua already samples the cursor every 0.25 s (its cursor() and C.TICK) and already counts GLOBAL_MOUSE_DOWN as input.
--
-- Wiring (three one-line changes, nothing else of the Lab changes):
--   WuberLab.toc        add  Focus.lua  after Passive.lua
--   Passive.lua start() add  if L.FocusStart then L.FocusStart() end        (next to  keyWatcher(true))
--   Passive.lua stop()  add  if L.FocusStop then L.FocusStop(why) end       (next to  keyWatcher(false))
-- Like GameFacts.lua it makes no frame, registers no event and starts no timer at load (Wuber's own tests load the Lab on every branch).
--
-- Safety (the rules of every Lab probe):
--   * read-only: no hook, no SetScript, no Show/Hide, no click, no key, no cvar, nothing sent to anyone, no typed command, no macro.
--   * every game call goes through pcall and type checks (mm / m below); a secret value is dropped (L.plain / L.num).
--   * nothing in combat: the tick returns at once while InCombatLockdown() is true, so no protected call can come from it. Only getters
--     are used; a frame that is itself protected or forbidden is never read further than its name (protected()).
--   * it writes only L.db.focus (WuberLabDB.focus), a ring of at most C.KEEP rows per session, three sessions kept.
--
-- What it logs: one row when the focus frame changes, on every GLOBAL_MOUSE_DOWN, and every C.MOVE screen units of cursor travel inside
-- Wuber's window, but only while the focus is a Wuber frame or the cursor is over a Wuber window. See rowOf() for the fields. Per row:
--   x, y     cursor in UIParent units (GetCursorPosition divided by UIParent:GetEffectiveScale())
--   f, ot    the focus frame's debug name (or name) and object type; w = it is Wuber's (its own or an ancestor's name starts with "Wuber", or Wuber's window)
--   scr      Wuber's screen: tab / screen (+settings, +help), from W.UI.state like WuberRec's "wuber" snapshot
--   fr,st,lv,ea,mc,mm,ins,hit  the focus frame's rectangle (UIParent units), strata, level, effective alpha, click flag, motion flag,
--            GetHitRectInsets, and the hit rectangle worked out from them
--   clip     the focus's ancestors that clip their children (DoesClipChildren) with their rectangle and whether the cursor is inside it
--   under    every other shown, mouse-enabled Wuber frame whose hit rectangle holds the cursor (what the fake would have to choose from):
--            name, type, rectangle, strata, level, alpha, insets, and clipOut = the cursor is outside a clipping ancestor of it
--   win      Wuber's window rectangle and effective scale
-- How it becomes a fixture: tools/rec/import_focus.lua (import_focus.lua in this folder) reads WuberLab.lua from the game's SavedVariables,
-- refuses anything that is not plain data, and writes tests/fixtures/rec/focus-<build>.lua = { build, ui = { w, h, es }, samples, facts };
-- the facts (clipCutsMouse, hitInsetNegativeGrows, ...) are worked out from the rows by rules written in the importer.

local _, L = ...

local str, num, plain = L.str, L.num, L.plain

local C = {
	TICK = 0.25,   -- seconds between looks (the same as Passive.lua's own C.TICK); its own L.Every ticker, started by L.FocusStart
	MOVE = 12,     -- UIParent units the cursor may travel inside Wuber's window before another row is kept
	KEEP = 1500,   -- rows per session (a ring)
	SESSIONS = 3,
	WALK = 400,    -- frames looked at in one walk of Wuber's windows
	UNDER = 8,     -- candidate frames kept per row
	CLIPS = 6,     -- clipping ancestors kept per row
	DEPTH = 12,    -- ancestors walked up from a frame
}
L.FOCUS = C

local F = { session = nil, last = nil, lastSig = nil, wired = false, n = 0 }
L.focusState = F

---------------------------------------------------------------------------
-- Guarded reads (any call may be missing, fail or give a secret value)
---------------------------------------------------------------------------

local function fn(t, k) return type(t) == "table" and type(t[k]) == "function" end

-- o:k(...) -> its results, or nothing when o has no such method, it failed, or a result is secret
local function mm(o, k, ...)
	if not fn(o, k) then return end
	local r = { pcall(o[k], o, ...) }
	if not r[1] then return end
	for i = 2, #r do r[i] = plain(r[i]) end
	return unpack(r, 2)
end
-- the first result only
local function m(o, k, ...)
	local v = mm(o, k, ...)
	return v
end
local function r1(x) x = num(x) return x and math.floor(x * 10 + 0.5) / 10 or nil end

local function protected(f)
	if plain(m(f, "IsForbidden")) == true then return true end
	local prot, explicit = mm(f, "IsProtected")
	return explicit == true
end

local function nameOf(f)
	if type(f) ~= "table" then return nil end
	local n = str(m(f, "GetDebugName")) or str(m(f, "GetName"))
	if n then return n:sub(1, 80) end
	local ot = str(m(f, "GetObjectType")) or "?"
	local p = m(f, "GetParent")
	local pn = type(p) == "table" and str(m(p, "GetName")) or nil
	return "<" .. ot .. (pn and (" in " .. pn) or "") .. ">"
end

local function W_() return L.W() end
local function winOf()
	local W = W_()
	local UI = type(W) == "table" and type(W.UI) == "table" and W.UI or nil
	local st = UI and type(UI.state) == "table" and UI.state or nil
	return W, UI, st, st and st.win
end

-- UIParent's effective scale (the cursor is in pixels; UIParent units = pixels / this)
local function uiScale()
	local up = rawget(_G, "UIParent")
	return num(m(up, "GetEffectiveScale")) or 1, up
end

-- a frame's rectangle in PIXEL space (the cursor's space): GetScaledRect, else GetRect times the effective scale
local function pxRect(f)
	local l, b, w, h = mm(f, "GetScaledRect")
	l, b, w, h = num(l), num(b), num(w), num(h)
	if l and b and w and h then return l, b, w, h end
	l, b, w, h = mm(f, "GetRect")
	l, b, w, h = num(l), num(b), num(w), num(h)
	local s = num(m(f, "GetEffectiveScale"))
	if l and b and w and h and s then return l * s, b * s, w * s, h * s end
end

-- the hit rectangle in pixel space: the rectangle moved in by the insets (a negative inset grows it)
local function pxHit(f)
	local l, b, w, h = pxRect(f)
	if not l then return end
	local il, ir, it, ib = mm(f, "GetHitRectInsets")
	il, ir, it, ib = num(il) or 0, num(ir) or 0, num(it) or 0, num(ib) or 0
	local s = num(m(f, "GetEffectiveScale")) or 1
	return l + il * s, b + ib * s, w - (il + ir) * s, h - (it + ib) * s, il, ir, it, ib
end

local function inside(px, py, l, b, w, h) return l and px >= l and px <= l + w and py >= b and py <= b + h end

local function ui(v, es) v = num(v) return v and r1(v / es) or nil end
local function rectUI(l, b, w, h, es)
	if not l then return nil end
	return { l = ui(l, es), b = ui(b, es), w = ui(w, es), h = ui(h, es) }
end

---------------------------------------------------------------------------
-- What is Wuber's
---------------------------------------------------------------------------

local function wuberRoots()
	local _, _, _, win = winOf()
	local out, seen = {}, {}
	local function add(f)
		if type(f) == "table" and not seen[f] and fn(f, "GetChildren") then
			seen[f] = true
			out[#out + 1] = f
		end
	end
	add(win)
	for _, name in ipairs({ "WuberFrame", "WuberDriveButton", "WuberDriveFrame", "WuberDriveMini", "WuberBug", "WuberTipCard" }) do add(rawget(_G, name)) end
	return out
end

local function isWuber(f, win)
	local g = f
	for _ = 1, C.DEPTH do
		if type(g) ~= "table" then return false end
		if g == win then return true end
		local n = str(m(g, "GetName"))
		if n and n:find("^Wuber") then return true end
		g = m(g, "GetParent")
	end
	return false
end

-- ancestors of f (and f itself is NOT included) that clip their children: { frame, rect } from the nearest up
local function clipChain(f)
	local out = {}
	local g = m(f, "GetParent")
	for _ = 1, C.DEPTH do
		if type(g) ~= "table" then break end
		if plain(m(g, "DoesClipChildren")) == true then
			local l, b, w, h = pxRect(g)
			out[#out + 1] = { f = g, l = l, b = b, w = w, h = h }
			if #out >= C.CLIPS then break end
		end
		g = m(g, "GetParent")
	end
	return out
end

local function clipOut(chain, px, py)
	for _, c in ipairs(chain) do
		if c.l and not inside(px, py, c.l, c.b, c.w, c.h) then return true end
	end
	return false
end

local function frameInfo(f, px, py, es, withClip)
	local l, b, w, h = pxRect(f)
	local hl, hb, hw, hh, il, ir, it, ib = pxHit(f)
	local o = {
		f = nameOf(f), ot = str(m(f, "GetObjectType")),
		fr = rectUI(l, b, w, h, es), hit = rectUI(hl, hb, hw, hh, es),
		st = str(m(f, "GetFrameStrata")), lv = num(m(f, "GetFrameLevel")), ea = r1(m(f, "GetEffectiveAlpha")),
		mc = m(f, "IsMouseClickEnabled"), mm = m(f, "IsMouseMotionEnabled"), me = m(f, "IsMouseEnabled"),
	}
	if il then o.ins = { il, ir, it, ib } end
	if withClip then
		local chain = clipChain(f)
		if #chain > 0 then
			o.clip = {}
			for i, c in ipairs(chain) do
				o.clip[i] = { f = nameOf(c.f), r = rectUI(c.l, c.b, c.w, c.h, es), inside = inside(px, py, c.l, c.b, c.w, c.h) and true or false }
			end
		end
		o.clipOut = clipOut(chain, px, py) or nil
	end
	return o
end

-- every shown, mouse-enabled Wuber frame whose hit rectangle holds the cursor (a walk of Wuber's windows, at most C.WALK frames)
local function candidates(px, py, es, focus)
	local out, seen, n = {}, {}, 0
	local stack = {}
	for _, r in ipairs(wuberRoots()) do stack[#stack + 1] = r end
	while #stack > 0 and n < C.WALK do
		local f = table.remove(stack)
		if not seen[f] then
			seen[f] = true
			n = n + 1
			if not protected(f) and plain(m(f, "IsShown")) == true then
				if plain(m(f, "IsMouseEnabled")) == true or plain(m(f, "IsMouseMotionEnabled")) == true or plain(m(f, "IsMouseClickEnabled")) == true then
					local hl, hb, hw, hh = pxHit(f)
					if inside(px, py, hl, hb, hw, hh) and #out < C.UNDER then
						local o = frameInfo(f, px, py, es, true)
						o.isFocus = (f == focus) or nil
						out[#out + 1] = o
					end
				end
				local kids = { mm(f, "GetChildren") }
				for i = 1, #kids do
					if type(kids[i]) == "table" and not seen[kids[i]] then stack[#stack + 1] = kids[i] end
				end
			end
		end
	end
	return out, n
end

---------------------------------------------------------------------------
-- A row
---------------------------------------------------------------------------

local function screenId()
	local W, UI, st = winOf()
	if not st then return nil, nil end
	local bits = { str(st.tab) or "?", str(st.screen) or "?" }
	local replay = { tab = str(st.tab), screen = str(st.screen) }
	-- (Wuber's own functions, called without self, as WuberRec's "wuber" snapshot calls them)
	if fn(UI, "SettingsShown") and plain(L.call(UI.SettingsShown)) == true then bits[#bits + 1] = "+settings" replay.settings = true end
	if fn(UI, "HelpShown") and plain(L.call(UI.HelpShown)) == true then bits[#bits + 1] = "+help" replay.help = true end
	local D = type(W) == "table" and type(W.Driver) == "table" and W.Driver or nil
	if D then replay.dmode, replay.dscreen = str(L.call(D.Mode)), str(L.call(D.CurrentScreen)) end
	return table.concat(bits, "/"), replay
end

local function focusOf()
	local get = rawget(_G, "GetMouseFoci")
	if type(get) == "function" then
		local ok, t = pcall(get)
		t = ok and plain(t) or nil
		if type(t) == "table" then return t[1], #t, "GetMouseFoci" end
		return nil, 0, "GetMouseFoci"
	end
	get = rawget(_G, "GetMouseFocus") -- (not in this build's documentation: a fallback, and the row says which was used)
	if type(get) == "function" then
		local ok, f = pcall(get)
		f = ok and plain(f) or nil
		return type(f) == "table" and f or nil, f and 1 or 0, "GetMouseFocus"
	end
	return nil, 0, "none"
end

local function rowOf(why, button)
	local gc = rawget(_G, "GetCursorPosition")
	if type(gc) ~= "function" then return nil end
	local okc, cx, cy = pcall(gc)
	cx, cy = okc and num(cx), okc and num(cy)
	if not (cx and cy) then return nil end
	local es = uiScale()
	local _, _, _, win = winOf()
	local focus, nf, via = focusOf()
	local winShown = type(win) == "table" and plain(m(win, "IsShown")) == true
	local wl, wb, ww, wh = nil, nil, nil, nil
	if winShown then wl, wb, ww, wh = pxRect(win) end
	local overWin = winShown and inside(cx, cy, wl, wb, ww, wh) or false
	local focusWuber = type(focus) == "table" and isWuber(focus, win) or false
	-- other Wuber windows (the floating button, the console, the bug box) count as "the cursor is over Wuber" through their own focus
	if not (focusWuber or overWin) then return nil end
	local row = { t = r1(L.Now()), x = r1(cx / es), y = r1(cy / es), ev = why, btn = str(button), nf = nf, via = via, w = focusWuber or nil, win_over = overWin or nil }
	row.scr, row.replay = screenId()
	if winShown then
		row.win = { rect = rectUI(wl, wb, ww, wh, es), es = r1(num(m(win, "GetEffectiveScale"))), sc = r1(num(m(win, "GetScale"))) }
	end
	if type(focus) == "table" then
		if protected(focus) then
			row.f, row.prot = nameOf(focus), true
		else
			local o = frameInfo(focus, cx, cy, es, true)
			for k, v in pairs(o) do row[k] = v end
		end
	end
	row.under = candidates(cx, cy, es, focus)
	return row, cx, cy, es
end

local function keep(row)
	local s = F.session
	if not s or not row then return end
	s.n = s.n + 1
	s.rows[((s.n - 1) % C.KEEP) + 1] = row
	if row.ev == "down" then s.downs = s.downs + 1 end
end

-- the same focus (frame, rectangle, screen)?
local function sig(row)
	local fr = row.fr
	return table.concat({ tostring(row.f), tostring(row.ot), fr and (fr.l .. "," .. fr.b .. "," .. fr.w .. "," .. fr.h) or "-", tostring(row.scr), tostring(row.nf) }, "|")
end

local function look(why, button)
	if L.InCombat() then return end
	local row = rowOf(why, button)
	if not row then
		F.last = nil
		return
	end
	local s = sig(row)
	local moved = true
	if F.last then moved = math.abs(row.x - F.last.x) + math.abs(row.y - F.last.y) >= C.MOVE end
	if why == "down" or s ~= F.lastSig or moved then
		keep(row)
		F.last, F.lastSig = row, s
	end
end

---------------------------------------------------------------------------
-- On and off (called by Passive.lua's start() and stop())
---------------------------------------------------------------------------

local function dbf()
	local d = L.db
	if type(d) ~= "table" then return nil end
	if type(d.focus) ~= "table" then d.focus = { v = 1, sessions = {} } end
	return d.focus
end

local ticker
function L.FocusStart()
	local d = dbf()
	if not d then return end
	if not F.session then
		local es, up = uiScale()
		local s = { char = L.me or "?", started = L.Epoch(), wuber = L.RunWuberVersion(), lab = L.VERSION, n = 0, downs = 0, rows = {} }
		s.ui = { es = r1(es), sc = r1(num(m(up, "GetScale"))) }
		local gw, gh = rawget(_G, "GetScreenWidth"), rawget(_G, "GetScreenHeight")
		s.ui.w, s.ui.h = r1(plain(L.call(gw))), r1(plain(L.call(gh)))
		-- GetBuildInfo gives version, build, date, toc: kept as one plain text, e.g. "1.60.1 (71037)"
		local okB, v, b = pcall(rawget(_G, "GetBuildInfo") or function() end)
		s.build = okB and (tostring(plain(v)) .. " (" .. tostring(plain(b)) .. ")") or "?"
		d.sessions[#d.sessions + 1] = s
		while #d.sessions > C.SESSIONS do table.remove(d.sessions, 1) end
		F.session = s
	end
	if not F.wired then
		F.wired = true
		L.On("GLOBAL_MOUSE_DOWN", function(button)
			if L.PassiveOn and L.PassiveOn() and F.session then look("down", button) end
		end)
		L.On("PLAYER_LOGOUT", function()
			local s = F.session
			if s and L.PassiveResult then
				s.ended = L.Epoch()
				L.PassiveResult("focus", "the session", "pass", ("%d focus rows, %d clicks, over Wuber"):format(s.n, s.downs))
			end
		end)
	end
	if not ticker then ticker = L.Every(C.TICK, function() if L.PassiveOn and L.PassiveOn() then look("tick") end end) end
end

function L.FocusStop()
	if ticker and fn(ticker, "Cancel") then pcall(ticker.Cancel, ticker) end
	ticker = nil
	if F.session then F.session.ended = L.Epoch() end
	F.session, F.last, F.lastSig = nil, nil, nil
end
