-- Wuber Lab (developer only, never ship): the usage trail and the Huh key.
--
-- The trail: "/lab trail on|off|status" (saved in WuberLabDB.trail.on, off by default, apart from
-- passive play; it never starts the photo tour, and passive play's idle tour waits while it is on).
-- While on, every line is kind "trail" and starts with the real clock time (date("%H:%M:%S")):
--   open <window|mini bar|floating button|drive window|bell|crew offer|bug report|map>, close <...>
--   tab <new> (from <old>)          screen <Ride/home|Drive/console|settings|help|Trips|...>
--   click "<label>" on <tab or window>      hover "<label>" 1.4s [(tooltip)] on <tab or window>
--   type in "<box>" on <tab>  (never what was typed)      setting <key>: <old> -> <new>
--   trail on (<why>), trail off (<why>), trail paused (photo tour), trail resumed, trail end (logout)
-- A line said while Wuber's window is open ends with " @ <screen>". Labels come from the control's
-- own text, its tooltip title or its frame name (at most 32 characters); no chat text is logged here
-- (Hooks.lua logs whispers itself), and an edit box's text never is.
--
-- How it watches: HookScript only (OnShow/OnHide on Wuber's named frames and the world map; OnClick,
-- OnMouseUp/Down, OnEnter/OnLeave, OnEditFocusGained on their controls). A frame is hooked when its
-- window first shows; new children are picked up by a walk after clicks, page changes and every few
-- seconds while a window is open (one 2 s ticker, no OnUpdate). Nothing is hooked in combat: it waits
-- for PLAYER_REGEN_ENABLED. Settings come from W.Fire("SETTINGS", key) (Hooks.lua's W.Fire wrapper
-- calls L.TrailFire), old -> new from a copy taken when the trail started; a slider's run of changes
-- is one line once it has rested 1.5 s. Nothing is called on Wuber's frames but reads and HookScript.
--
-- The Huh key (Bindings.xml: Esc > Options > Keybindings > WuberLab; also "/lab huh [words]" and the
-- Huh button in the panel's Tools tab): one "huh" line - the clock time, the words, a summary of the
-- last 30 s of the trail - then L.Snap() (one screenshot). Works with the trail on or off.
--
-- Saved: WuberLabDB.trail = { on, lines = { "epoch|character|trail|text", ... } }: a copy of every
-- trail and huh line (the newest 4000), so an hour of play survives the timeline's 6000-line cap.
-- labreport.js merges it with the timeline (the same lines) for its "Struggles" and trail timeline.
-- Nothing is wired (no event, no hook, no ticker) until the trail is first turned on.

local _, L = ...

local show, str, call, plain = L.show, L.str, L.call, L.plain

if type(L.KINDS) == "table" then
	L.KINDS.trail = "usage trail (windows, tabs, screens, clicks, hovers, settings; clock time)"
	L.KINDS.huh = "Huh key (the tester was stuck: his words, the last 30 s, a screenshot)"
end

-- Key binding names (Bindings.xml)
BINDING_HEADER_WUBERLAB = "WuberLab"
BINDING_NAME_WUBERLAB_HUH = "Huh: mark + screenshot"

-- Tunables (tests read and shorten them)
local C = {
	HOVER = 0.3,        -- a hover this long or longer is a line
	HOVER_MAX = 20,     -- a longer one is the cursor left over a background window: not a line
	NEW = 0.5,          -- a control made after a walk is hooked this long after the last CreateFrame (a burst is one walk)
	NEW_GAP = 1,        -- ...and never sooner than this after the previous walk
	TICK = 2,           -- the one ticker: new roots, the screen, a pause for the photo tour
	RESCAN = 6,         -- a walk for new children at most this often from the ticker
	MAX_FRAMES = 6000,  -- frames looked at per walk
	KEEP = 4000,        -- lines kept in WuberLabDB.trail.lines
	HUH_BACK = 30,      -- seconds of trail a Huh sums up
	RECENT = 120,       -- seconds of trail kept in memory
	LABEL = 32,         -- characters of a label
	SETTLE = 1.5,       -- a setting's changes become one line once it rests this long
}
L.TRAIL_C = C

-- Wuber's top-level frames: { global name, what the tester calls it }
local ROOTS = {
	{ "WuberFrame", "window" },
	{ "WuberDriveMini", "mini bar" },
	{ "WuberDriveButton", "floating button" },
	{ "WuberDriveFrame", "drive window" },
	{ "WuberBell", "bell" },
	{ "WuberCrewOffer", "crew offer" },
	{ "WuberMinimapButton", "minimap button", quiet = true }, -- its clicks only
	{ "WuberBug", "bug report" },
	{ "WorldMapFrame", "map", map = true }, -- the game's map (Wuber's pins): open/close only
}
L.TRAIL_ROOTS = ROOTS

local TR = {
	wired = false,      -- the trail is on and listening
	events = false,     -- its events are registered (once)
	listening = false,  -- the kept copy's listener is in L.listeners (once)
	paused = false,     -- the photo tour is running: its demo screens are not the tester's play
	queued = false,     -- a hook waits for the end of combat
	roots = {},         -- [global name] = frame (OnShow/OnHide hooked)
	hooked = setmetatable({}, { __mode = "k" }), -- [control] = the root's label
	nHooked = 0,
	tab = nil, screen = nil,
	hover = nil,        -- { f, t, tip, clicked }
	recent = {},        -- { t, tag, label } of the last C.RECENT seconds (Huh's summary)
	shadow = {},        -- [setting key] = value text, for old -> new
	pend = {},          -- [setting key] = { old, vals, clock, gen } resting
	lastScan = -100,
	count = { lines = 0, click = 0, hover = 0, huh = 0 },
}
L.trailState = TR

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function clock()
	return str(call(rawget(_G, "date"), "%H:%M:%S")) or "??:??:??"
end
L.TrailClock = clock

-- cut a UTF-8 string to at most max bytes without splitting a character
local function cut(s, max)
	if #s <= max then return s end
	local n = max - 3
	while n > 0 do
		local b = s:byte(n + 1)
		if not b or b < 128 or b >= 192 then break end
		n = n - 1
	end
	return s:sub(1, n) .. "..."
end

-- plain one-line text: no colour codes, textures, line breaks, "|" or double quotes
local function clean(s, max)
	s = str(s)
	if not s then return nil end
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|n", " ")
	s = s:gsub("[\r\n\t]+", " "):gsub("|", "/"):gsub('"', "'"):gsub("%s%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if s == "" then return nil end
	return cut(s, max or C.LABEL)
end
L.TrailClean = clean

local function tdb()
	local db = L.db
	if type(db) ~= "table" then return nil end
	if type(db.trail) ~= "table" then db.trail = { on = false, lines = {} } end
	if type(db.trail.lines) ~= "table" then db.trail.lines = {} end
	return db.trail
end

local function isOn()
	local db = L.db
	return type(db) == "table" and type(db.trail) == "table" and db.trail.on == true
end
L.TrailOn = isOn

-- the kept copy: every "trail" and "huh" timeline line, exactly as the timeline has it
local function keep(kind, text, at)
	if kind ~= "trail" and kind ~= "huh" then return end
	local t = tdb()
	if not t then return end
	local lines = t.lines
	if #lines >= C.KEEP then
		local drop = math.max(1, math.floor(C.KEEP / 8))
		local out = {}
		for i = drop + 1, #lines do out[#out + 1] = lines[i] end
		t.dropped = (tonumber(t.dropped) or 0) + drop
		t.lines = out
		lines = out
	end
	lines[#lines + 1] = string.format("%.3f|%s|%s|%s", tonumber(at) or L.Epoch(), tostring(L.me or "?"), kind, tostring(text))
end

local function listen()
	if TR.listening or type(L.listeners) ~= "table" then return end
	TR.listening = true
	L.listeners[#L.listeners + 1] = function(kind, text, at)
		local ok, err = pcall(keep, kind, text, at)
		if not ok then L.Bug("trail keep", err) end
	end
end

local function remember(tag, label)
	local now = L.Now()
	local r = TR.recent
	r[#r + 1] = { t = now, tag = tag, label = label }
	if #r > 400 or (r[1] and now - r[1].t > C.RECENT) then
		local out = {}
		for i = 1, #r do
			if now - r[i].t <= C.RECENT then out[#out + 1] = r[i] end
		end
		TR.recent = out
	end
end

-- one trail line. opts: bare (no " @ screen"), force (also while paused), clock (the time to show),
-- label (what Huh's summary calls it)
local function note(text, tag, opts)
	opts = opts or {}
	if not TR.wired and not opts.force then return end
	if TR.paused and not opts.force then return end
	local line = (opts.clock or clock()) .. " " .. text
	if not opts.bare and TR.screen then line = line .. " @ " .. TR.screen end
	L.Log("trail", line)
	TR.count.lines = TR.count.lines + 1
	remember(tag or "other", opts.label or text)
end

---------------------------------------------------------------------------
-- Where the tester is: the tab and the screen of Wuber's window
---------------------------------------------------------------------------

local function kitUi(W)
	if type(W.Mod) ~= "function" then return nil end
	local kit = call(W.Mod, "UI.Kit")
	return type(kit) == "table" and type(kit.ui) == "table" and kit.ui or nil
end

-- the screen ("Ride/home", "Drive/console", "settings", ...) and the tab, or nil when the window is shut
local function screenNow()
	local W = L.W()
	local UI = W and W.UI
	if type(UI) ~= "table" or plain(call(UI.IsShown)) ~= true then return nil, nil end
	local ui = kitUi(W)
	local tab = ui and str(ui.tab) or nil
	if plain(call(UI.HelpShown)) == true then return "help", tab end
	if plain(call(UI.SettingsShown)) == true then return "settings", tab end
	if ui and ui.splashing then return "splash", tab end
	if ui and ui.coaching then return "tips", tab end
	if tab == "Ride" then return "Ride/" .. (str(ui.screen) or "?"), tab end
	if tab == "Drive" then
		local D = W.Driver
		if type(D) ~= "table" then return "Drive", tab end
		local mode = str(call(D.Mode))
		local scr = (mode and mode ~= "console") and mode or (str(call(D.CurrentScreen)) or "console")
		local sheet = plain(call(D.SheetOpen)) and "+sheet" or ""
		return "Drive/" .. scr .. sheet, tab
	end
	return tab or "window", tab
end
L.TrailScreen = screenNow

local function checkScreen()
	if not TR.wired or TR.paused then return end
	local scr, tab = screenNow()
	if scr and tab and tab ~= TR.tab then
		local old = TR.tab
		TR.tab = tab
		if old then note(("tab %s (from %s)"):format(tab, old), "tab", { bare = true, label = tab }) end
	end
	if scr ~= TR.screen then
		TR.screen = scr
		if scr then note("screen " .. scr, "screen", { bare = true, label = scr }) end
	end
end
L.TrailCheckScreen = checkScreen

local screenSoon = false
local function checkScreenSoon()
	if screenSoon then return end
	screenSoon = true
	L.After(0.05, function()
		screenSoon = false
		checkScreen()
	end)
end

---------------------------------------------------------------------------
-- Naming a control
---------------------------------------------------------------------------

local function tipTitle(f)
	local tip = rawget(f, "wuberTip")
	if type(tip) ~= "table" then return nil end
	local title = tip.title
	if type(title) == "function" then title = call(title, f) end
	return clean(title)
end

local function fontText(f)
	local regions = { call(f.GetRegions, f) }
	for i = 1, #regions do
		local r = regions[i]
		if type(r) == "table" and str(call(r.GetObjectType, r)) == "FontString" and plain(call(r.IsShown, r)) ~= false then
			local t = clean(call(r.GetText, r), 24)
			if t then return t end
		end
	end
	return nil
end

-- the control's own words, its tooltip title, its frame name, a text inside it; never an edit box's text
local function labelOf(f)
	local ot = str(call(f.GetObjectType, f)) or "Frame"
	if ot == "Button" or ot == "CheckButton" then
		local t = clean(call(f.GetText, f))
		if t then return t end
	end
	local t = tipTitle(f) or clean(call(f.GetName, f), 40)
	if t then return t end
	if ot ~= "EditBox" then
		t = fontText(f)
		if t then return t end
	end
	if ot == "EditBox" then return "a text box" end
	return "a " .. ot:lower() .. " with no label"
end
L.TrailLabel = labelOf

local function bigButtonLabel()
	local W = L.W()
	local B = W and W.Drive and W.Drive.Button
	if type(B) == "table" and plain(call(B.Docked)) == true then return nil end -- docked: part of the window
	return "floating button"
end

local function whereOf(f)
	local root = TR.hooked[f]
	if root == "window" then return TR.tab or "window" end
	if root == "floating button" then return bigButtonLabel() or ("big button on " .. (TR.tab or "window")) end
	return root or "?"
end

---------------------------------------------------------------------------
-- Clicks, hovers, typing
---------------------------------------------------------------------------

local screenAndScan -- (below)

local lastClick, lastClickAt, lastVia = nil, -100, nil
local function clicked(f, button, via)
	if not TR.wired or TR.paused then return end
	local t = L.Now()
	if lastClick == f and lastVia ~= via and t - lastClickAt < 0.08 then return end -- OnClick and OnMouseUp of one click
	lastClick, lastClickAt, lastVia = f, t, via
	local h = TR.hover
	if h and h.f == f then h.clicked = true end
	local label = labelOf(f)
	local b = str(button)
	local which = (b and b ~= "LeftButton") and (" (" .. b:gsub("Button$", ""):lower() .. ")") or ""
	TR.count.click = TR.count.click + 1
	note(("click \"%s\"%s on %s"):format(label, which, whereOf(f)), "click", { label = label })
	screenAndScan()
end

local function onClick(self, button)
	if TR.wired then L.Safe("trail click", clicked, self, button, "click") end
end

local function onMouseDown(self, button)
	if TR.wired then L.Safe("trail click", clicked, self, button, "down") end
end

local function onMouseUp(self, button)
	if not TR.wired then return end
	if plain(call(self.IsMouseOver, self)) == false then return end -- let go somewhere else: not a click
	L.Safe("trail click", clicked, self, button, "up")
end

local function tipOwnedBy(f)
	return L.Tip.owner() == f -- Wuber's card or the game's tooltip (Log.lua)
end

local function onEnter(self)
	if not TR.wired or TR.paused then return end
	TR.hover = { f = self, t = L.Now(), tip = tipOwnedBy(self), clicked = false }
end

local function hoverEnded(f)
	local h = TR.hover
	if not h or h.f ~= f then return end
	TR.hover = nil
	if h.clicked or not TR.wired or TR.paused then return end
	local dwell = L.Now() - h.t
	if dwell < C.HOVER or dwell > C.HOVER_MAX then return end
	local tip = (h.tip or tipOwnedBy(f)) and " (tooltip)" or ""
	local label = labelOf(f)
	TR.count.hover = TR.count.hover + 1
	note(("hover \"%s\" %.1fs%s on %s"):format(label, dwell, tip, whereOf(f)), "hover", { label = label })
end

local function onLeave(self)
	if TR.wired then L.Safe("trail hover", hoverEnded, self) end
end

local function onFocus(self)
	if not TR.wired or TR.paused then return end
	L.Safe("trail focus", function()
		local label = labelOf(self)
		note(("type in \"%s\" on %s"):format(label, whereOf(self)), "type", { label = label })
	end)
end

---------------------------------------------------------------------------
-- Hooking (HookScript only; never in combat)
---------------------------------------------------------------------------

local CLICKY = { Button = true, CheckButton = true }

local function hasScript(f, name)
	if plain(call(f.HasScript, f, name)) ~= true then return false end
	return call(f.GetScript, f, name) ~= nil
end

local function hook(f, script, fn)
	return (pcall(f.HookScript, f, script, fn))
end

-- a control (button, a frame that takes clicks or shows a tip, an edit box, a slider): hooked once
local function hookControl(f, root)
	if TR.hooked[f] or type(f.HookScript) ~= "function" then return end
	local ot = str(call(f.GetObjectType, f)) or ""
	local up, down = hasScript(f, "OnMouseUp"), hasScript(f, "OnMouseDown")
	local button, edit, slider = CLICKY[ot], ot == "EditBox", ot == "Slider"
	local enter = hasScript(f, "OnEnter")
	if not (button or edit or slider or up or down or enter) then return end
	TR.hooked[f] = root
	TR.nHooked = TR.nHooked + 1
	if button then
		hook(f, "OnClick", onClick)
		if up and not hasScript(f, "OnClick") then hook(f, "OnMouseUp", onMouseUp) end
	elseif up or slider then
		hook(f, "OnMouseUp", onMouseUp)
	elseif down then
		hook(f, "OnMouseDown", onMouseDown)
	end
	if edit then hook(f, "OnEditFocusGained", onFocus) end
	if button or enter or slider or up or down then
		hook(f, "OnEnter", onEnter)
		hook(f, "OnLeave", onLeave)
	end
end

local function walk(f, root, budget)
	local kids = { call(f.GetChildren, f) }
	for i = 1, #kids do
		if budget.n <= 0 then return end
		local k = kids[i]
		if type(k) == "table" then
			budget.n = budget.n - 1
			hookControl(k, root)
			walk(k, root, budget)
		end
	end
end

local function shownNow(f) return plain(call(f.IsShown, f)) == true end

-- every control under the shown roots (their hidden tabs too)
local function rescan()
	if not TR.wired then return end
	if L.InCombat() then
		TR.queued = true
		return
	end
	TR.lastScan = L.Now()
	local budget = { n = C.MAX_FRAMES }
	for _, r in ipairs(ROOTS) do
		local f = TR.roots[r[1]]
		if f and not r.map and shownNow(f) then walk(f, r[2], budget) end
	end
end
L.TrailRescan = rescan

local scanSoon = false
screenAndScan = function()
	checkScreenSoon()
	if scanSoon then return end
	scanSoon = true
	L.After(0.3, function()
		scanSoon = false
		rescan()
	end)
end

local function rootShown(name, label, on)
	if not TR.wired or TR.paused or not label then return end
	if name == "WuberDriveButton" then
		label = bigButtonLabel()
		if not label then return end
	end
	if on then
		note("open " .. label, "open", { bare = true, label = "open " .. label })
		if name == "WuberFrame" then checkScreen() end
		screenAndScan()
	else
		note("close " .. label, "close", { label = "close " .. label })
		if name == "WuberFrame" then TR.screen = nil end
	end
end

local function hookRoot(r)
	local name, label = r[1], r[2]
	if TR.roots[name] then return true end
	local f = rawget(_G, name)
	if type(f) ~= "table" or type(f.HookScript) ~= "function" then return false end
	if r.map and not L.W() then return false end
	if L.InCombat() then
		TR.queued = true
		return false
	end
	TR.roots[name] = f
	if not r.quiet then
		hook(f, "OnShow", function() L.Safe("trail open", rootShown, name, label, true) end)
		hook(f, "OnHide", function() L.Safe("trail close", rootShown, name, label, false) end)
	end
	-- a root that is itself a button (the floating button, the bell, the minimap button)
	if not r.map and CLICKY[str(call(f.GetObjectType, f)) or ""] then hookControl(f, label) end
	return true
end

local function findRoots()
	if L.InCombat() then
		TR.queued = true
		return
	end
	for _, r in ipairs(ROOTS) do hookRoot(r) end
end

---------------------------------------------------------------------------
-- Settings: old -> new
---------------------------------------------------------------------------

local MASK = { "pass", "msg", "message", "text", "note", "keyword", "say", "whisper" }

local function masked(key)
	key = tostring(key):lower()
	for _, m in ipairs(MASK) do
		if key:find(m, 1, true) then return true end
	end
	return false
end

local function hash(s)
	local h = 5381
	for i = 1, #s do h = (h * 33 + s:byte(i)) % 1048576 end
	return string.format("%05x", h)
end

local function scalarText(v, key)
	if L.IsSecret and L.IsSecret(v) then return "<secret>" end
	if v == nil then return "nil" end
	local t = type(v)
	if t == "number" then
		if v == math.floor(v) then return tostring(v) end
		return (string.format("%.4g", v))
	end
	if t == "string" then
		if masked(key) or #v > 24 then return ("(text, %d chars #%s)"):format(#v, hash(v)) end
		return clean(v, 24) or "''"
	end
	if t == "boolean" then return tostring(v) end
	return "{" .. t .. "}"
end

local function valueText(v, key)
	if type(v) ~= "table" or (L.IsSecret and L.IsSecret(v)) then return scalarText(v, key) end
	local pairsList = {}
	for k, x in pairs(v) do
		if type(x) ~= "table" and type(x) ~= "function" then pairsList[#pairsList + 1] = { tostring(k), x } end
		if #pairsList > 30 then return "{many}" end
	end
	table.sort(pairsList, function(a, b) return a[1] < b[1] end)
	local parts = {}
	for _, p in ipairs(pairsList) do parts[#parts + 1] = p[1] .. "=" .. scalarText(p[2], p[1]) end
	local s = "{" .. table.concat(parts, ",") .. "}"
	if #s > 60 then s = ("{%d values #%s}"):format(#parts, hash(s)) end
	return s
end
L.TrailValueText = valueText

local function driveOpts(W)
	local DR = W.Drive
	local o = type(DR) == "table" and call(DR.opts) or nil
	if type(o) == "table" then return o end
	o = type(W.db) == "table" and W.db.drive
	return type(o) == "table" and o or nil
end

local function settingValue(key)
	local W = L.W()
	local db = W and W.db
	if type(db) ~= "table" then return nil end
	local sub = key:match("^drive%.(.+)$")
	if sub then
		local o = driveOpts(W)
		return o and o[sub]
	end
	local v = db[key]
	if v == nil then
		local c = call(W.Char)
		if type(c) == "table" then v = c[key] end
	end
	return v
end

local function snapshot()
	TR.shadow = {}
	local W = L.W()
	local db = W and W.db
	if type(db) ~= "table" then return end
	for k, v in pairs(db) do
		if type(k) == "string" then TR.shadow[k] = valueText(v, k) end
	end
	local o = driveOpts(W)
	if o then
		for k, v in pairs(o) do
			if type(k) == "string" then TR.shadow["drive." .. k] = valueText(v, k) end
		end
	end
end

local function flushSetting(key)
	local p = TR.pend[key]
	TR.pend[key] = nil
	if not p then return end
	local chain = { p.old }
	for _, v in ipairs(p.vals) do
		if v ~= chain[#chain] then chain[#chain + 1] = v end
	end
	if #chain == 1 then return end -- fired with the value it had
	local text
	if #chain >= 3 and chain[#chain] == chain[1] then
		text = chain[1] .. " -> " .. chain[2] .. " -> " .. chain[1] .. " (back)"
	else
		text = chain[1] .. " -> " .. chain[#chain]
	end
	note(("setting %s: %s"):format(key, text), "setting", { clock = p.clock, label = key })
end

local function flushAll()
	local keys = {}
	for k in pairs(TR.pend) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do flushSetting(k) end
end

local function settingChanged(key)
	key = str(key)
	if not key or not TR.wired then return end
	local new = valueText(settingValue(key), key:match("([^.]+)$"))
	local p = TR.pend[key]
	if not p then
		p = { old = TR.shadow[key] or "?", vals = {}, clock = clock(), gen = 0 }
		TR.pend[key] = p
	end
	TR.shadow[key] = new
	p.vals[#p.vals + 1] = new
	p.gen = p.gen + 1
	local gen = p.gen
	L.After(C.SETTLE, function()
		if TR.pend[key] == p and p.gen == gen then flushSetting(key) end
	end)
end

-- Hooks.lua's W.Fire wrapper calls this for every Wuber event (before Wuber's own listeners)
function L.TrailFire(name, ...)
	if not TR.wired then return end
	if name == "SETTINGS" then
		L.Safe("trail setting", settingChanged, (...))
	elseif name == "PAGE" or name == "RIDE" or name == "DRIVE_MODE" or name == "DRIVE" then
		checkScreenSoon()
	end
end

-- another lab file's own line for the trail (Hooks.lua: a place booked from the map)
function L.TrailNote(text, tag)
	if not TR.wired then return end
	note(tostring(text), tag or "click", { label = tostring(text) })
end

---------------------------------------------------------------------------
-- On and off
---------------------------------------------------------------------------

local function tick()
	if not TR.wired then return end
	local photo = L.photo and true or false
	if photo ~= TR.paused then
		if photo then
			note("trail paused (photo tour)", "pause", { bare = true, force = true })
			TR.paused, TR.hover = true, nil
		else
			TR.paused, TR.screen = false, nil
			note("trail resumed", "resume", { bare = true, force = true })
		end
	end
	if TR.paused then return end
	findRoots()
	checkScreen()
	if L.Now() - TR.lastScan >= C.RESCAN then
		for _, r in ipairs(ROOTS) do
			local f = TR.roots[r[1]]
			if f and not r.map and shownNow(f) then
				rescan()
				break
			end
		end
	end
end

local newGen = 0
local function ensureEvents()
	if TR.events then return end
	TR.events = true
	-- a control made after the last walk (Confirm's Request summon, the finding / found / done screens, sheets) is
	-- hooked a moment after CreateFrame, so even a click right after it opens is heard
	if type(hooksecurefunc) == "function" then
		pcall(hooksecurefunc, "CreateFrame", function()
			if not TR.wired then return end
			newGen = newGen + 1
			local gen = newGen
			local function fire()
				if gen ~= newGen or not TR.wired then return end -- a later CreateFrame moved the walk back
				local wait = C.NEW_GAP - (L.Now() - TR.lastScan)
				if wait > 0 then
					L.After(wait, function() if gen == newGen then rescan() end end)
				else
					rescan()
				end
			end
			L.After(C.NEW, fire)
		end)
	end
	L.On("PLAYER_REGEN_ENABLED", function()
		if not TR.wired or not TR.queued then return end
		TR.queued = false
		findRoots()
		rescan()
	end)
	L.On("PLAYER_LOGOUT", function()
		if not TR.wired then return end
		flushAll()
		note("trail end (logout)", "off", { bare = true, force = true })
	end)
end

local function wire(why)
	if TR.wired then return end
	listen()
	ensureEvents()
	TR.wired = true
	TR.paused = L.photo and true or false
	TR.tab, TR.screen, TR.hover, TR.recent = nil, nil, nil, {}
	TR.count = { lines = 0, click = 0, hover = 0, huh = TR.count.huh or 0 }
	snapshot()
	note("trail on (" .. why .. ")", "on", { bare = true, force = true })
	findRoots()
	if not TR.paused then
		for _, r in ipairs(ROOTS) do
			local f = TR.roots[r[1]]
			local label = r[1] == "WuberDriveButton" and bigButtonLabel() or r[2]
			if f and label and not r.quiet and shownNow(f) then
				note("open " .. label .. " (already open)", "open", { bare = true, label = "open " .. label })
			end
		end
		checkScreen()
		rescan()
	end
	TR.ticker = L.Every(C.TICK, tick)
end

local function unwire(why)
	if not TR.wired then return end
	flushAll()
	note("trail off (" .. why .. ")", "off", { bare = true, force = true })
	TR.wired = false
	if TR.ticker and type(TR.ticker.Cancel) == "function" then pcall(TR.ticker.Cancel, TR.ticker) end
	TR.ticker, TR.hover, TR.paused = nil, nil, false
end

function L.TrailSet(on)
	local t = tdb()
	if not t then return false end
	on = on and true or false
	t.on = on
	if on then wire("turned on") else unwire("turned off") end
	if L.RefreshPanel then L.RefreshPanel() end
	return on
end

local function say(text)
	if L.Say then L.Say(text) end
end

function L.TrailStatus()
	if not isOn() then
		return "usage trail is off (/lab trail on: every Wuber window, tab, screen, click, hover and setting with the clock time, for the report's Struggles)"
	end
	local t = tdb()
	return ("usage trail is on: %d lines since it started (%d clicks, %d hovers), %d controls watched, %d Huh; window %s; %d lines kept%s"):format(
		TR.count.lines, TR.count.click, TR.count.hover, TR.nHooked, TR.count.huh,
		TR.screen and ("open on " .. TR.screen) or "closed", t and #t.lines or 0,
		TR.paused and "; paused (photo tour)" or (TR.queued and "; hooks wait for the end of combat" or ""))
end

function L.TrailSlash(rest)
	local a = (str(rest) or ""):lower()
	if a == "on" then
		L.TrailSet(true)
		say("usage trail on: play as usual; Huh key (or /lab huh <words>) where you get stuck. /lab trail off when done, then log out or /reload")
	elseif a == "off" then
		L.TrailSet(false)
		say("usage trail off")
	else
		say(L.TrailStatus())
	end
end

---------------------------------------------------------------------------
-- Huh
---------------------------------------------------------------------------

local function join(list, sep, max)
	local out = {}
	for i = 1, math.min(#list, max or #list) do out[#out + 1] = list[i] end
	local s = table.concat(out, sep)
	if max and #list > max then s = s .. sep .. "..." end
	return s
end

-- one line: what the trail saw in the last back seconds
local function summary(back)
	if not TR.wired then
		local scr = screenNow()
		return "trail off; " .. (scr and ("screen " .. scr) or "Wuber's window shut")
	end
	local now = L.Now()
	local clicks, hovers, tabs, screens, sets, opens = {}, 0, {}, {}, {}, {}
	for _, e in ipairs(TR.recent) do
		if now - e.t <= back then
			if e.tag == "click" or e.tag == "type" then
				clicks[#clicks + 1] = e.label
			elseif e.tag == "hover" then
				hovers = hovers + 1
			elseif e.tag == "tab" then
				tabs[#tabs + 1] = e.label
			elseif e.tag == "screen" then
				screens[#screens + 1] = e.label
			elseif e.tag == "setting" then
				sets[#sets + 1] = e.label
			elseif e.tag == "open" or e.tag == "close" then
				opens[#opens + 1] = e.label
			end
		end
	end
	local parts = {}
	if #clicks > 0 then parts[#parts + 1] = #clicks .. " clicks (" .. join(clicks, ", ", 4) .. ")" end
	if hovers > 0 then parts[#parts + 1] = hovers .. " hovers" end
	if #tabs > 0 then parts[#parts + 1] = "tabs " .. join(tabs, ">", 5) end
	if #screens > 0 then parts[#parts + 1] = "screens " .. join(screens, ">", 4) end
	if #sets > 0 then parts[#parts + 1] = "settings " .. join(sets, ", ", 3) end
	if #opens > 0 then parts[#parts + 1] = join(opens, ", ", 3) end
	if #parts == 0 then parts[1] = "nothing" end
	return table.concat(parts, "; ") .. "; now " .. (TR.screen or "window shut")
end
L.TrailSummary = summary

-- the Huh key, /lab huh <words>, the Tools tab's Huh button: a line, then a screenshot
function L.Huh(words)
	listen()
	tdb()
	words = clean(words, 100)
	TR.count.huh = (TR.count.huh or 0) + 1
	L.Log("huh", ("%s %s -- last %d s: %s"):format(clock(), words or "(no words)", C.HUH_BACK, summary(C.HUH_BACK)))
	say("huh noted (" .. clock() .. ")" .. (words and ". /reload when you want me to look" or ""))
	if L.Snap then return L.Snap() end
	return false
end

-- Bindings.xml's key
function L.HuhKey()
	L.Safe("huh key", L.Huh, nil)
end

L.OnLogin(function()
	if isOn() then wire("login") end
end)
