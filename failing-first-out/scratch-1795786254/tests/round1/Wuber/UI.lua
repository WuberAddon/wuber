-- Wuber: the rider's app window (Home, Confirm, Finding, Driver found, Done, Sorry), its
-- tabs (Driver.lua adds "Drive"), the splash, toasts and the minimap button.
-- Reads the network only through W.drivers / W.DriversSorted(), W.ride and Net's
-- functions, each guarded, so a missing piece never raises an error.
--
-- The Request and Cancel chat whispers need a hardware click on a secure macro button.
-- Those buttons (WuberRequestButton, WuberCancelButton) are parented to UIParent and laid
-- over the visible pill out of combat, never parented or anchored to the window: a
-- protected child would lock the window in combat.

local _, W = ...
local T = W.Theme
local A = T.Animate
local Try = T.Try

local UI = {}
W.UI = UI

local WIN_W, WIN_H, TOP_H = 360, 600, 56
local BODY_H = WIN_H - TOP_H
local PAD = 18
local INNER = WIN_W - PAD * 2
local CARD_H, CARD_GAP = 72, 8
local MAP_H, SHEET_TOP = 212, 184
local LIST_TOP = 112
local REQUEST_TIMEOUT = 40
local REFRESH_GAP = 0.25 -- at most 4 refreshes a second

local ui = {
	screen = nil, manual = "home", confirmKey = nil, dismissed = {}, toasted = {},
	tabs = {}, pendingTabs = {}, dirty = true, lastRefresh = 0, animUntil = 0,
	cards = {}, cardPool = {}, filter = nil, scroll = 0, scrollTarget = 0,
}
UI.state = ui -- for tests and /dump

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function S(v) return W.Str(v) end
local function N(v) return W.Num(v) end

local function ret(ok, ...)
	if not ok then
		W.Error("UI", (...))
		return nil
	end
	return ...
end

-- Calls another file's function if it is there; errors are reported, never raised.
local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	return ret(pcall(fn, ...))
end

local function now() return N(call(GetTime)) or 0 end
local function inCombat()
	if type(W.InCombat) == "function" then return call(W.InCombat) == true end
	return type(InCombatLockdown) == "function" and W.Plain(call(InCombatLockdown)) == true
end

local function safeScript(frame, script, fn)
	frame:SetScript(script, function(...)
		local ok, err = pcall(fn, ...)
		if not ok then W.Error(script, err) end
	end)
end

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function money(c) return W.Money(c or 0) end

-- One line for a macro: no line breaks or pipes, at most `max` bytes.
local function macroSafe(text, max)
	text = S(text)
	if not text then return nil end
	text = text:gsub("[\r\n|]", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	if text == "" then return nil end
	return W.Clean(text, max or 200)
end

local function setShown(region, shown)
	if shown then region:Show() else region:Hide() end
end

---------------------------------------------------------------------------
-- Reading the network's data (plain values only)
---------------------------------------------------------------------------

local STATE_ORDER = { open = 1, busy = 2, paused = 3 }

local function driverView(d)
	if type(d) ~= "table" then return nil end
	local name = S(d.name)
	local key = S(d.key) or (name and W.Key(name))
	if not (name and key) then return nil end
	local x, y = N(d.x), N(d.y)
	if x and x > 1 then x = x / 1000 end
	if y and y > 1 then y = y / 1000 end
	local state = S(d.state)
	if not STATE_ORDER[state or ""] then state = "paused" end
	local team = N(d.team) or 1
	team = clamp(math.floor(team), 1, 3)
	local service = S(d.service)
	return {
		key = key, name = name, short = W.Short(name), dest = S(d.dest) or "Unknown",
		price = math.max(0, N(d.price) or 0), service = service or name, state = state,
		team = team, seats = N(d.seats), heard = N(d.heard), mapID = N(d.mapID), x = x, y = y,
	}
end

local function sortDrivers(list)
	table.sort(list, function(a, b)
		local oa, ob = STATE_ORDER[a.state] or 3, STATE_ORDER[b.state] or 3
		if oa ~= ob then return oa < ob end
		if a.price ~= b.price then return a.price < b.price end
		local na, nb = a.name:lower(), b.name:lower()
		if na ~= nb then return na < nb end
		return a.key < b.key
	end)
	return list
end

-- Every driver heard, open first, then busy, then paused; cheapest first within each.
function UI.Drivers()
	local src
	if type(W.DriversSorted) == "function" then
		local list = call(W.DriversSorted)
		if type(list) == "table" then src = list end
	end
	if not src then
		src = {}
		if type(W.drivers) == "table" then
			for _, d in pairs(W.drivers) do src[#src + 1] = d end
		end
	end
	local out, seen = {}, {}
	for _, d in ipairs(src) do
		local v = driverView(d)
		if v and not seen[v.key] then
			seen[v.key] = true
			out[#out + 1] = v
		end
	end
	return sortDrivers(out)
end

function UI.Driver(key)
	if not key or type(W.drivers) ~= "table" then return nil end
	local d = W.drivers[key]
	if not d and W.Key then d = W.drivers[W.Key(key) or ""] end
	return driverView(d)
end

local RIDE_RANK = { requesting = 1, accepted = 2, invited = 3, ingroup = 4, summoning = 5, portal = 6, arrived = 7, paying = 8, done = 9 }
local ENDED = { done = true, declined = true, cancelled = true, timeout = true, failed = true }

local function rideView()
	local r = W.ride
	if type(r) ~= "table" then return nil end
	local v = {
		id = S(r.id) or tostring(r), driver = S(r.driver) or "your driver", driverKey = S(r.driverKey),
		dest = S(r.dest) or "your destination", price = N(r.price), state = S(r.state) or "requesting",
		at = N(r.at), eta = N(r.eta), etaAt = N(r.etaAt), stage = S(r.stage), reason = S(r.reason),
		service = S(r.service), summonUp = W.Plain(r.summonUp) == true, grouped = W.Plain(r.grouped) == true,
		stars = N(r.stars), rated = W.Plain(r.rated) == true, raw = r,
	}
	v.short = W.Short(v.driver)
	v.rank = RIDE_RANK[v.state] or 0
	-- the summon is up and waiting to be accepted
	v.portalUp = v.state == "portal" or (v.state == "summoning" and v.summonUp)
	return v
end
UI.Ride = rideView

local function rideActive(rv)
	rv = rv or rideView()
	return rv ~= nil and not ENDED[rv.state]
end

local function myKey() return W.myKey or (W.Key and W.Key(call(W.UnitName, "player"))) end

local function inGroup() return call(W.InGroup) == true end
local function inGroupWith(key)
	if type(W.InGroupWith) ~= "function" then return false end
	return call(W.InGroupWith, key) == true
end

local function onNetwork()
	if type(W.OnNetwork) ~= "function" then return true end
	return call(W.OnNetwork) ~= false
end

local function cancellable(rv)
	return rv and not ENDED[rv.state] and rv.rank < RIDE_RANK.arrived
end

---------------------------------------------------------------------------
-- Toasts: slide down from the top centre, up to three, gone after 4 s
---------------------------------------------------------------------------

local toasts, toastPool = {}, {}
local toastHost
local TOAST_W, TOAST_H, TOAST_GAP, TOAST_TOP = 320, 56, 8, -18
local TOAST_KIND = {
	found = { colour = "glow", glyph = "check", sound = "found" },
	summon = { colour = "magenta", glyph = "summon", sound = "alert" },
	request = { colour = "gold", glyph = "summon", sound = "found" },
	info = { colour = "accent", glyph = "ride" },
	warn = { colour = "amber", text = "!" },
	error = { colour = "red", text = "!" },
}
-- glyphs on light circles are drawn in ink, on dark ones in white
local LIGHT = { glow = true, gold = true, amber = true, magenta = true }

local function toastY(i) return TOAST_TOP - (i - 1) * (TOAST_H + TOAST_GAP) end

local function layoutToasts()
	for i, t in ipairs(toasts) do t.targetY = toastY(i) end
	if toastHost then toastHost:Show() end
end

local function removeToast(t, quick)
	for i, x in ipairs(toasts) do
		if x == t then
			table.remove(toasts, i)
			break
		end
	end
	t.token = (t.token or 0) + 1
	A.FadeOut(t, quick and 0.1 or 0.22, function()
		t:Hide()
		toastPool[#toastPool + 1] = t
	end)
	layoutToasts()
end

local function buildToast()
	local t = CreateFrame("Button", nil, UIParent)
	t:SetSize(TOAST_W, TOAST_H)
	t:SetFrameStrata("FULLSCREEN_DIALOG")
	t.card = T.Card(t, TOAST_W, TOAST_H, { colour = { 0.086, 0.086, 0.157, 0.97 }, radius = 18, border = "line" })
	t.card:SetAllPoints(t)
	t.icon = T.Circle(t.card, 30, "white", "ARTWORK")
	t.icon:SetPoint("LEFT", t.card, "LEFT", 13, 0)
	t.glyph = T.Icon(t.card, "check", 16, "ink", "OVERLAY")
	t.glyph:SetPoint("CENTER", t.icon, "CENTER")
	t.mark = T.Text(t.card, 16, "ink", "CENTER", "bold")
	t.mark:SetPoint("CENTER", t.icon, "CENTER", 0, 0)
	t.text = T.Text(t.card, "body", "white", "LEFT", "medium")
	t.text:SetPoint("LEFT", t.icon, "RIGHT", 12, 0)
	t.text:SetPoint("RIGHT", t.card, "RIGHT", -14, 0)
	Try(t.text, "SetWordWrap", true)
	Try(t.text, "SetMaxLines", 2)
	t:RegisterForClicks("LeftButtonUp")
	safeScript(t, "OnClick", function(self)
		removeToast(self, true)
		UI.Toggle(true)
	end)
	return t
end

local function buildToastHost()
	toastHost = CreateFrame("Frame", nil, UIParent)
	toastHost:SetSize(1, 1)
	toastHost:SetPoint("TOP", UIParent, "TOP", 0, 0)
	toastHost:Hide()
	safeScript(toastHost, "OnUpdate", function(self, elapsed)
		local moving = false
		local k = math.min(1, (elapsed or 0) * 12)
		for _, t in ipairs(toasts) do
			local y = t.curY or t.targetY
			if t.targetY and math.abs(y - t.targetY) > 0.5 then
				y = y + (t.targetY - y) * k
				moving = true
			else
				y = t.targetY or y
			end
			if y ~= t.curY then
				t.curY = y
				t:ClearAllPoints()
				t:SetPoint("TOP", UIParent, "TOP", 0, y)
			end
		end
		if not moving then self:Hide() end
	end)
end

-- Toast(text, kind): kind "found", "summon", "info", "warn" or "error".
function UI.Toast(text, kind)
	text = S(text)
	if not text then return nil end
	local spec = TOAST_KIND[kind or "info"] or TOAST_KIND.info
	local t0 = now()
	for _, x in ipairs(toasts) do
		if x.message == text and t0 - (x.at or 0) < 2 then return x end -- no repeats
	end
	if not toastHost then buildToastHost() end
	while #toasts >= 3 do removeToast(toasts[1], true) end
	local t = table.remove(toastPool) or buildToast()
	t.message, t.at = text, t0
	t.text:SetText(text)
	t.icon:SetVertexColor(T.RGB(spec.colour))
	if spec.glyph then
		t.glyph:SetTexture(T.MEDIA .. spec.glyph)
		t.glyph:SetVertexColor(T.RGB(LIGHT[spec.colour] and "ink" or "white"))
		t.glyph:Show()
		t.mark:Hide()
	else
		t.glyph:Hide()
		t.mark:SetText(spec.text or "")
		t.mark:SetTextColor(T.RGB(LIGHT[spec.colour] and "ink" or "white"))
		t.mark:Show()
	end
	toasts[#toasts + 1] = t
	t.targetY = toastY(#toasts)
	t.curY = t.targetY + 70 -- starts above, slides down
	t:ClearAllPoints()
	t:SetPoint("TOP", UIParent, "TOP", 0, t.curY)
	A.FadeIn(t, 0.22)
	layoutToasts()
	if spec.sound then W.Sound(spec.sound) end
	local token = (t.token or 0) + 1
	t.token = token
	W.After(4, function()
		if t.token == token then removeToast(t) end
	end)
	return t
end

---------------------------------------------------------------------------
-- Secure buttons (Request and Cancel whispers)
---------------------------------------------------------------------------

local secure = {}

-- The request: driver key and the macro, if this click may go ahead.
local function requestBlock(key)
	local d = UI.Driver(key)
	if not d then return "gone" end
	if d.key == myKey() then return "self" end
	if d.state == "paused" then return "paused" end
	if rideActive() then return "active" end
	if inGroup() and not inGroupWith(d.key) then return "group" end
	if not onNetwork() and not (W.drivers and W.drivers[d.key]) then return "offline" end
	return nil, d
end

local BLOCK_TEXT = {
	gone = "That driver has gone offline",
	self = "That's you!",
	paused = "That driver has paused for now",
	active = "You already have a ride under way",
	group = "Leave your group first",
	offline = "The network is unavailable",
}

-- "/w Name-Surname text" checked: one line, a plain name, at most 255 bytes.
local function checkMacro(macro)
	macro = S(macro)
	if not macro or macro:find("[\r\n|]") then return nil end
	local target, line = macro:match("^/w (%S+) (.+)$")
	if not target or target:find("/", 1, true) then return nil end
	line = macroSafe(line, 200)
	if not line then return nil end
	return "/w " .. target .. " " .. line, line
end

local function requestMacro(key, d)
	local macro
	if type(W.RequestMacro) == "function" then
		macro = call(W.RequestMacro, key)
	elseif type(W.RequestWhisper) == "function" then
		local line, target = call(W.RequestWhisper, key)
		if line and target then macro = "/w " .. tostring(target) .. " " .. tostring(line) end
	elseif d then
		local target = W.Tell and call(W.Tell, d.name) or (d.name:gsub("%s+", "-"))
		macro = "/w " .. tostring(target) .. " WTB summon to " .. d.dest .. " for " .. money(d.price)
	end
	return checkMacro(macro)
end

local CANCEL_LINE = "Sorry, I have to cancel - thanks anyway"

local function cancelMacro(rv)
	local macro
	if type(W.CancelMacro) == "function" then macro = call(W.CancelMacro) end
	local ok, line = checkMacro(macro)
	if not ok and rv and rv.driver then
		local target = W.Tell and call(W.Tell, rv.driver) or rv.driver:gsub("%s+", "-")
		ok, line = checkMacro("/w " .. tostring(target) .. " " .. CANCEL_LINE)
	end
	if not ok then return nil end
	-- the line must never read as a new request
	if line:lower():find("summon", 1, true) then
		ok = checkMacro((ok:match("^(/w %S+ )") or "") .. CANCEL_LINE)
	end
	return ok
end

-- Cancels the ride (C to the driver); the secure overlay has already whispered if it could.
local function doCancel(whispered)
	local rv = rideView()
	if not cancellable(rv) then
		UI.Toast("Too late to cancel now", "warn")
		return
	end
	local ok = call(W.CancelRide)
	if ok == false then
		UI.Toast("Too late to cancel now", "warn")
		return
	end
	ui.dismissed[rv.id] = true
	call(W.ClearRide)
	ui.manual = "home"
	if whispered or not inCombat() then
		UI.Toast("Ride cancelled", "info")
	else
		UI.Toast("Ride cancelled. No whisper in combat.", "info")
	end
	UI.Refresh(true)
end

-- What each overlay sits on, and whether it may be used now.
local function overlayTarget(which)
	local win = ui.win
	if not (win and win:IsShown()) or ui.tab ~= "Ride" or ui.moving or ui.splashing then return nil end
	if now() < ui.animUntil then return nil end
	local scr = ui.screens and ui.screens[ui.screen]
	if not scr then return nil end
	if which == "request" then
		if ui.screen ~= "confirm" or not ui.confirmKey then return nil end
		if requestBlock(ui.confirmKey) then return nil end
		return scr.request
	else
		local rv = rideView()
		if not cancellable(rv) then return nil end
		return scr.cancel
	end
end

local function placeOverlay(b, pill)
	if inCombat() then return end
	if not (pill and pill:IsVisible()) then
		if b:IsShown() then b:Hide() end
		b.sig = nil
		return
	end
	local l, bt = N(pill:GetLeft()), N(pill:GetBottom())
	local w, h = N(pill:GetWidth()), N(pill:GetHeight())
	local pe, ue = N(pill:GetEffectiveScale()), N(UIParent:GetEffectiveScale())
	if not (l and bt and w and h and pe and ue) or w <= 0 or h <= 0 or ue <= 0 then
		if b:IsShown() then b:Hide() end
		return
	end
	local s = pe / ue
	local sig = ("%.1f:%.1f:%.1f:%.1f:%.4f"):format(l, bt, w, h, s)
	local level = (N(ui.win and ui.win:GetFrameLevel()) or 0) + 100
	if b.level ~= level then
		b:SetFrameLevel(level)
		b.level = level
	end
	if b.sig ~= sig then
		b:SetScale(s)
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, bt)
		b:SetSize(w, h)
		b.sig = sig
	end
	b.pill = pill
	if not b:IsShown() then b:Show() end
end

-- Lays the secure buttons over their pills (out of combat only).
function UI.SyncSecure()
	if inCombat() then return end
	if secure.request then placeOverlay(secure.request, overlayTarget("request")) end
	if secure.cancel then placeOverlay(secure.cancel, overlayTarget("cancel")) end
end

local function hideOverlays()
	if inCombat() then return end
	for _, b in pairs(secure) do
		b:SetAttribute("macrotext", "")
		b:Hide()
		b.sig = nil
	end
end

local function forward(b, script, pill)
	pill = pill or b.pill
	if not pill then return end
	local fn = pill:GetScript(script)
	if fn then pcall(fn, pill) end
end

local function makeSecure(name, pre, post)
	local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
	b:SetSize(10, 10)
	b:SetFrameStrata("FULLSCREEN_DIALOG")
	b:SetFrameLevel(120)
	b:RegisterForClicks("LeftButtonUp")
	b:SetAttribute("useOnKeyDown", false)
	b:SetAttribute("type", "macro")
	b:SetAttribute("macrotext", "")
	b:Hide()
	b:SetScript("PreClick", function(self, button, down)
		local ok, err = pcall(pre, self, button, down)
		if not ok then
			self.armed = nil
			W.Error("secure button", err)
		end
	end)
	b:SetScript("PostClick", function(self, button, down)
		if down then return end
		local armed = self.armed
		self.armed = nil
		if not inCombat() then self:SetAttribute("macrotext", "") end
		local ok, err = pcall(post, self, armed)
		if not ok then W.Error("secure button", err) end
	end)
	-- the pill underneath shows hover and press
	b:SetScript("OnEnter", function(self) forward(self, "OnEnter") end)
	b:SetScript("OnLeave", function(self) forward(self, "OnLeave") end)
	b:SetScript("OnMouseDown", function(self) forward(self, "OnMouseDown") end)
	b:SetScript("OnMouseUp", function(self) forward(self, "OnMouseUp") end)
	return b
end

local function buildSecure()
	if secure.request then return end
	if inCombat() then
		if W.AfterCombat then W.AfterCombat(buildSecure) end
		return
	end
	secure.request = makeSecure("WuberRequestButton", function(self, _, down)
		self.armed = nil
		if down or inCombat() then return end
		self:SetAttribute("macrotext", "")
		local key = ui.confirmKey
		local why, d = requestBlock(key)
		if why then return end
		local macro = requestMacro(d.key, d)
		if not macro then return end
		self:SetAttribute("type", "macro")
		self:SetAttribute("macrotext", macro)
		self.armed = d.key
	end, function(_, armed)
		if armed then
			local ride, why = call(W.RequestRide, armed)
			if not ride and why then UI.Toast(BLOCK_TEXT[why] or "Couldn't send the request", "warn") end
			ui.manual = "home"
			UI.Refresh(true)
		elseif inCombat() then
			UI.Toast("Can't request in combat", "warn")
		else
			local why = requestBlock(ui.confirmKey)
			UI.Toast(BLOCK_TEXT[why or ""] or "Couldn't send the request", "warn")
		end
	end)
	secure.cancel = makeSecure("WuberCancelButton", function(self, _, down)
		self.armed = nil
		if down or inCombat() then return end
		self:SetAttribute("macrotext", "")
		local rv = rideView()
		if not cancellable(rv) then return end
		local macro = cancelMacro(rv)
		if not macro then
			self.armed = "quiet"
			return
		end
		self:SetAttribute("type", "macro")
		self:SetAttribute("macrotext", macro)
		self.armed = "whisper"
	end, function(_, armed)
		doCancel(armed == "whisper")
	end)
	UI.secure = secure
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local screens = {}
ui.screens = screens
local SCREEN_RANK = { home = 1, confirm = 2, finding = 3, found = 4, done = 5, sorry = 5 }

local function applyScale()
	local win = ui.win
	if not win then return end
	local db = W.db or {}
	local s = N(db.scale)
	if s then
		s = clamp(s, 0.4, 2)
	else
		local h, w = N(UIParent:GetHeight()) or 0, N(UIParent:GetWidth()) or 0
		s = 1
		if h > 0 then s = math.min(s, (h - 40) / WIN_H) end
		if w > 0 then s = math.min(s, (w - 40) / WIN_W) end
		s = clamp(s, 0.5, 1)
	end
	win:SetScale(s)
end
UI.ApplyScale = applyScale

-- Above the world map while it is open (a map pin opens Confirm), else the usual layer.
local function raise()
	local win = ui.win
	if not win then return end
	local map = type(WorldMapFrame) == "table" and WorldMapFrame or nil
	local over = map and type(map.IsShown) == "function" and W.Plain(call(map.IsShown, map)) == true
	local want = over and "FULLSCREEN_DIALOG" or "HIGH"
	if ui.strata ~= want then
		win:SetFrameStrata(want)
		ui.strata = want
	end
end
UI.Raise = raise

local function placeWindow()
	local win = ui.win
	win:ClearAllPoints()
	local p = W.db and W.db.pos
	if type(p) == "table" and type(p[1]) == "string" and type(p[2]) == "string" and tonumber(p[3]) and tonumber(p[4]) then
		local ok = pcall(win.SetPoint, win, p[1], UIParent, p[2], tonumber(p[3]), tonumber(p[4]))
		if ok then return end
		win:ClearAllPoints()
	end
	win:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
end

local function savePosition()
	local win = ui.win
	local point, _, relPoint, x, y = win:GetPoint(1)
	point, relPoint, x, y = S(point), S(relPoint), N(x), N(y)
	if point and relPoint and x and y and W.db then
		W.db.pos = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) }
	end
end

local function tabButton(name)
	local b = T.Pill(ui.top, name, "ghost", 64, 30)
	b.tabName = name
	local width = N(Try(b.label, "GetStringWidth")) or 0
	if width <= 0 then width = #name * 8 end
	b:SetWidth(math.floor(width + 30))
	b:HookScript("OnClick", function(self)
		W.Safe("tab", UI.SelectTab, self.tabName)
	end)
	return b
end

local function layoutTabs()
	local x = 130
	for _, tab in ipairs(ui.tabs) do
		tab.button:ClearAllPoints()
		tab.button:SetPoint("LEFT", ui.top, "LEFT", x, -2)
		x = x + (N(tab.button:GetWidth()) or 64) + 4
		local on = tab.name == ui.tab
		tab.button:SetStyle(on and "dark" or "ghost")

		if not on then tab.button.label:SetTextColor(T.RGB("muted")) end
	end
end

local function addTabNow(name, buildFn)
	for _, tab in ipairs(ui.tabs) do
		if tab.name == name then return tab.body end
	end
	local body = CreateFrame("Frame", nil, ui.win)
	body:SetPoint("TOPLEFT", ui.win, "TOPLEFT", 0, -TOP_H)
	body:SetPoint("BOTTOMRIGHT", ui.win, "BOTTOMRIGHT", 0, 0)
	Try(body, "SetClipsChildren", true)
	body:Hide()
	local tab = { name = name, body = body, button = tabButton(name) }
	ui.tabs[#ui.tabs + 1] = tab
	if buildFn then W.Safe("tab " .. name, buildFn, body) end
	layoutTabs()
	return body
end

-- AddTab(name, buildFn): a tab in the window's top bar. buildFn(body) runs once, when the
-- window is built (at login), under W.Safe; body is 360 x 544 below the top bar and is
-- shown while its tab is selected. Returns the body (nil until the window exists).
function UI.AddTab(name, buildFn)
	name = S(name)
	if not name then return nil end
	if ui.win then return addTabNow(name, buildFn) end
	ui.pendingTabs[#ui.pendingTabs + 1] = { name = name, build = buildFn }
	return nil
end

function UI.GetTab(name)
	for _, tab in ipairs(ui.tabs) do
		if tab.name == name then return tab.body end
	end
	return nil
end

function UI.SelectTab(name)
	if not ui.win then return false end
	local found = false
	for _, tab in ipairs(ui.tabs) do
		if tab.name == name then found = true end
	end
	if not found then return false end
	local old = ui.tab
	ui.tab = name
	for _, tab in ipairs(ui.tabs) do
		if tab.name == name then
			if old ~= name then A.FadeIn(tab.body, 0.18) else tab.body:Show() end
		else
			tab.body:Hide()
		end
	end
	layoutTabs()
	ui.animUntil = now() + 0.2
	hideOverlays()
	UI.Refresh(true)
	return true
end

---------------------------------------------------------------------------
-- Screen: Home (map panel and the bottom sheet of drivers)
---------------------------------------------------------------------------

local function buildMapPanel(home)
	local m = CreateFrame("Frame", nil, home)
	m:SetPoint("TOPLEFT", home, "TOPLEFT", 0, 0)
	m:SetSize(WIN_W, MAP_H + 40)
	Try(m, "SetClipsChildren", true)
	-- the hero image when there is no map art: the author's scene, darkened
	m.hero = T.Tex(m, "header", "BACKGROUND", -2)
	m.hero:SetAllPoints(m)
	-- the top two thirds of the scene (the portal), never the gold lettering below it
	local v0, v1 = 0.04, 0.70
	local aspect = WIN_W / (MAP_H + 40)
	local cut = (1 - (512 * (v1 - v0) * aspect) / 1024) / 2
	m.hero:SetTexCoord(cut, 1 - cut, v0, v1)
	m.hero:SetVertexColor(0.72, 0.7, 0.8)
	m.canvas = CreateFrame("Frame", nil, m)
	m.canvas:SetSize(WIN_W, MAP_H)
	m.canvas:SetPoint("TOPLEFT", m, "TOPLEFT", 0, 0)
	m.tiles = {}
	m.shade = CreateFrame("Frame", nil, m)
	m.shade:SetAllPoints(m)
	m.shade:SetFrameLevel(m.canvas:GetFrameLevel() + 2)
	local top = T.Tex(m.shade, "fade", "ARTWORK")
	top:SetPoint("TOPLEFT", m, "TOPLEFT")
	top:SetPoint("TOPRIGHT", m, "TOPRIGHT")
	top:SetHeight(56)
	top:SetTexCoord(0, 1, 1, 0)
	top:SetVertexColor(T.RGB("black", 0.8))
	local bottom = T.Tex(m.shade, "fade", "ARTWORK")
	bottom:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT")
	bottom:SetHeight(110)
	bottom:SetVertexColor(T.RGB("black", 1))
	m.dots = CreateFrame("Frame", nil, m)
	m.dots:SetAllPoints(m)
	m.dots:SetFrameLevel(m.canvas:GetFrameLevel() + 4)
	m.zone = T.Chip(m.dots, "", "white")
	m.zone:SetPoint("TOPLEFT", m, "TOPLEFT", 16, -12)
	m.net = T.Chip(m.dots, "Network offline", "amber")
	m.net:SetPoint("TOPRIGHT", m, "TOPRIGHT", -16, -12)
	m.net:Hide()
	-- the rider
	m.me = CreateFrame("Frame", nil, m.dots)
	m.me:SetSize(14, 14)
	m.me.glow = T.Tex(m.me, "glow", "BACKGROUND")
	m.me.glow:SetSize(44, 44)
	m.me.glow:SetPoint("CENTER", m.me, "CENTER")
	m.me.glow:SetVertexColor(T.RGB("white", 0.35))
	m.me.dot = T.Circle(m.me, 14, "white", "OVERLAY")
	m.me.dot:SetPoint("CENTER", m.me, "CENTER")
	m.me.pulse = A.Pulse(m.me, { size = 56, colour = "white", alpha = 0.35, period = 2.2, rings = 2 })
	m.me:Hide()
	m.pins = {}
	return m
end

local function mapArt(mapID)
	if not (type(C_Map) == "table" and mapID) then return nil end
	local layers = call(C_Map.GetMapArtLayers, mapID)
	local info = type(layers) == "table" and layers[1]
	if type(info) ~= "table" then return nil end
	local lw, lh = N(info.layerWidth), N(info.layerHeight)
	local tw, th = N(info.tileWidth), N(info.tileHeight)
	if not (lw and lh and tw and th) or lw <= 0 or lh <= 0 or tw <= 0 or th <= 0 then return nil end
	local files = call(C_Map.GetMapArtLayerTextures, mapID, 1)
	if type(files) ~= "table" then return nil end
	local cols, rows = math.ceil(lw / tw), math.ceil(lh / th)
	if cols * rows > 64 or cols * rows < 1 then return nil end
	local list = {}
	for i = 1, cols * rows do
		local f = W.Plain(files[i])
		if f == nil then return nil end
		list[i] = f
	end
	return { lw = lw, lh = lh, tw = tw, th = th, cols = cols, rows = rows, files = list }
end

local function playerSpot()
	if type(C_Map) ~= "table" then return nil end
	local mapID = N(call(C_Map.GetBestMapForUnit, "player"))
	if not mapID then return nil end
	local x, y
	local pos = call(C_Map.GetPlayerMapPosition, mapID, "player")
	if pos then
		local ok, px, py = pcall(pos.GetXY, pos)
		if ok then x, y = N(px), N(py) end
	end
	local name
	local info = call(C_Map.GetMapInfo, mapID)
	if type(info) == "table" then name = S(info.name) end
	return mapID, x, y, name
end

local function mapPin(m, i)
	local p = m.pins[i]
	if p then return p end
	p = CreateFrame("Button", nil, m.dots)
	p:SetSize(22, 22)
	p.ring = T.Circle(p, 20, "white", "ARTWORK", 0)
	p.ring:SetPoint("CENTER", p, "CENTER")
	p.dot = T.Circle(p, 14, "accent", "ARTWORK", 1)
	p.dot:SetPoint("CENTER", p, "CENTER")
	p.glyph = T.Icon(p, "summon", 10, "white", "OVERLAY")
	p.glyph:SetPoint("CENTER", p, "CENTER")
	p.pulse = A.Pulse(p, { size = 60, colour = "magenta", alpha = 0.6, period = 2, rings = 2, start = false })
	p:RegisterForClicks("LeftButtonUp")
	safeScript(p, "OnClick", function(self)
		if self.key then UI.Show("confirm", self.key) end
	end)
	safeScript(p, "OnEnter", function(self)
		local d = self.key and UI.Driver(self.key)
		if not (d and GameTooltip) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(d.service, 1, 1, 1)
		GameTooltip:AddLine(d.name .. " · to " .. d.dest, 0.56, 0.56, 0.58)
		GameTooltip:AddLine(money(d.price), T.RGB("gold"))
		GameTooltip:AddLine("Click to request", T.RGB("glow"))
		GameTooltip:Show()
	end)
	safeScript(p, "OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	m.pins[i] = p
	return p
end

local function updateMap(m, list)
	local mapID, px, py, zone = playerSpot()
	m.zone:SetChip(zone or "Azeroth", "white")
	setShown(m.net, not onNetwork())
	local art = mapID and (m.artFor == mapID and m.art or mapArt(mapID))
	m.artFor, m.art = mapID, art
	local pins = 0
	if art then
		m.hero:Hide()
		local k = WIN_W / (0.42 * art.lw)
		local cw, ch = art.lw * k, art.lh * k
		local tw, th = art.tw * k, art.th * k
		for i = 1, art.cols * art.rows do
			local t = m.tiles[i]
			if not t then
				t = m.canvas:CreateTexture(nil, "ARTWORK")
				Try(t, "SetDesaturated", true)
				t:SetVertexColor(0.36, 0.33, 0.52) -- a night-violet map
				m.tiles[i] = t
			end
			local col, row = (i - 1) % art.cols, math.floor((i - 1) / art.cols)
			if t.file ~= art.files[i] then
				t:SetTexture(art.files[i])
				t.file = art.files[i]
			end
			t:SetSize(tw, th)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", m.canvas, "TOPLEFT", col * tw, -row * th)
			t:Show()
		end
		for i = art.cols * art.rows + 1, #m.tiles do m.tiles[i]:Hide() end
		m.canvas:SetSize(cw, ch)
		-- the rider in the middle of the visible part (the sheet covers the bottom)
		local fx, fy = px or 0.5, py or 0.5
		local ox = clamp(WIN_W / 2 - fx * cw, math.min(0, WIN_W - cw), 0)
		local oy = clamp(SHEET_TOP / 2 - fy * ch, math.min(0, MAP_H - ch), 0)
		m.canvas:ClearAllPoints()
		m.canvas:SetPoint("TOPLEFT", m, "TOPLEFT", ox, oy)
		m.canvas:Show()
		if px and py then
			m.me:ClearAllPoints()
			m.me:SetPoint("CENTER", m.canvas, "TOPLEFT", px * cw, -py * ch)
			if not m.me:IsShown() then
				m.me:Show()
				m.me.pulse:Start()
			end
		else
			m.me:Hide()
		end
		for _, d in ipairs(list) do
			if d.mapID == mapID and d.x and d.y and pins < 24 then
				pins = pins + 1
				local p = mapPin(m, pins)
				p.key = d.key
				p:ClearAllPoints()
				p:SetPoint("CENTER", m.canvas, "TOPLEFT", d.x * cw, -d.y * ch)
				local colour = d.state == "open" and "accent" or (d.state == "busy" and "amber" or "off")
				p.dot:SetVertexColor(T.RGB(colour))
				if d.state == "open" then
					if not p.pulse.running then p.pulse:Start() end
				elseif p.pulse.running then
					p.pulse:Stop()
				end
				p:Show()
			end
		end
	else
		m.hero:Show()
		m.canvas:Hide()
		m.me:Hide()
	end
	for i = pins + 1, #m.pins do
		local p = m.pins[i]
		if p:IsShown() then
			p.pulse:Stop()
			p:Hide()
		end
	end
end

-- A driver card in the list.
local function buildCard(content)
	local c = CreateFrame("Button", nil, content)
	c:SetSize(INNER, CARD_H)
	c.bg = T.Rounded(c, "card", 14, "BACKGROUND", 0)
	c.avatar = T.Circle(c, 40, "line", "ARTWORK")
	c.avatar:SetPoint("LEFT", c, "LEFT", 14, 0)
	c.glyph = T.Icon(c, "summon", 22, "white", "OVERLAY")
	c.glyph:SetPoint("CENTER", c.avatar, "CENTER")
	c.title = T.Text(c, 14, "white", "LEFT", "bold")
	c.title:SetPoint("TOPLEFT", c, "TOPLEFT", 66, -11)
	c.title:SetWidth(158)
	c.sub = T.Text(c, "small", "muted", "LEFT", "regular")
	c.sub:SetPoint("TOPLEFT", c, "TOPLEFT", 66, -31)
	c.sub:SetWidth(126)
	c.chip = T.Chip(c, "Open", "glow")
	c.chip:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 66, 8)
	c.ago = T.Text(c, 10, "muted", "LEFT", "regular")
	c.ago:SetPoint("LEFT", c.chip, "RIGHT", 7, 0)
	c.price = T.Text(c, "price", "gold", "RIGHT", "bold")
	c.price:SetPoint("TOPRIGHT", c, "TOPRIGHT", -14, -10)
	-- team 3: the premium badge; fewer: how many helpers to bring
	c.badge = T.Badge(c, "No helpers needed", "gold")
	c.badge:SetPoint("TOPRIGHT", c, "TOPRIGHT", -14, -30)

	c.team = T.Text(c, "small", "muted", "RIGHT", "regular")
	c.team:SetPoint("TOPRIGHT", c, "TOPRIGHT", -14, -34)
	c.full = T.Text(c, 10, "amber", "RIGHT", "medium")
	c.full:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -14, 12)
	c:RegisterForClicks("LeftButtonUp")
	safeScript(c, "OnEnter", function(self)
		if not self.disabled then self.bg:SetColor("hover") end
	end)
	safeScript(c, "OnLeave", function(self) self.bg:SetColor("card") end)
	safeScript(c, "OnMouseDown", function(self)
		if not self.disabled then A.Tap(self) end
	end)
	safeScript(c, "OnClick", function(self)
		if not self.key then return end
		if self.disabled then
			UI.Toast((self.short or "This driver") .. " has paused for now", "info")
			return
		end
		W.Sound("click")
		UI.Show("confirm", self.key)
	end)
	return c
end

local function helpersText(d)
	if d.team >= 3 then return "No helpers needed" end
	local n = 3 - d.team
	return "Bring " .. n .. (n == 1 and " helper" or " helpers")
end

local function chipFor(d)
	if d.state == "open" then return "Open", "glow" end
	if d.state == "busy" then return "Busy · about 2 min", "amber" end
	return "Paused", "off"
end

local function updatedText(d)
	if not d.heard then return "" end
	return "Updated " .. W.Ago(now() - d.heard)
end

local function fillCard(c, d)
	c.key, c.short = d.key, d.short
	c.title:SetText(d.service)
	c.sub:SetText("To " .. d.dest .. " · " .. d.short)
	c.chip:SetChip(chipFor(d))
	c.ago:SetText(updatedText(d))
	c.price:SetText(money(d.price))
	local premium = d.team >= 3
	setShown(c.badge, premium)
	setShown(c.team, not premium)
	if not premium then c.team:SetText(helpersText(d)) end
	c.full:SetText(d.seats == 0 and "Group full" or "")
	c.disabled = d.state == "paused"
	c.heard = d.heard
	c.glyph:SetVertexColor(T.RGB(d.state == "open" and "white" or (d.state == "busy" and "amber" or "off")))
	c.avatar:SetVertexColor(T.RGB(d.state == "open" and "accent" or "line"))

	c:SetAlpha(c.disabled and 0.55 or 1)
	c.view = d
end

local function matches(d, filter)
	if not filter then return true end
	if filter.place then
		if W.SamePlace then
			local same = call(W.SamePlace, d.dest, filter.place)
			if same ~= nil then return same == true end
		end
		return d.dest:lower() == filter.place:lower()
	end
	local t = filter.text:lower()
	return d.dest:lower():find(t, 1, true) ~= nil or d.service:lower():find(t, 1, true) ~= nil
		or d.name:lower():find(t, 1, true) ~= nil
end

local function applySearch(text, final)
	text = S(text)
	if text then text = text:gsub("^%s+", ""):gsub("%s+$", "") end
	if not text or text == "" then
		ui.filter = nil
	else
		local place = (#text >= 2) and call(W.FindPlace, text)
		local name = type(place) == "table" and S(place.name) or nil
		ui.filter = name and { place = name, text = text } or { text = text }
		if final and name and W.db then W.db.lastDest = name end
	end
	ui.scrollTarget = 0
	UI.Refresh(true)
end

local function buildSearch(sheet)
	local box = CreateFrame("Frame", nil, sheet)
	box:SetSize(INNER, 46)
	box:SetPoint("TOPLEFT", sheet, "TOPLEFT", PAD, -22)
	box.fill = T.PillFill(box, "card", 46, "BACKGROUND", 1)
	box.icon = T.Icon(box, "search", 18, "white", "ARTWORK")
	box.icon:SetPoint("LEFT", box, "LEFT", 18, 0)
	local e = CreateFrame("EditBox", nil, box)
	e:SetPoint("TOPLEFT", box, "TOPLEFT", 46, 0)
	e:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -40, 0)
	e:SetAutoFocus(false)
	Try(e, "SetMaxLetters", 40)
	T.SetFont(e, 16, "bold")
	Try(e, "SetTextColor", 1, 1, 1, 1)
	Try(e, "SetTextInsets", 0, 0, 0, 0)
	box.edit = e
	box.hint = T.Text(box, 16, "white", "LEFT", "bold")
	box.hint:SetPoint("LEFT", box, "LEFT", 46, 0)
	box.hint:SetText("Where to?")
	box.clear = T.RoundButton(box, "close", 26, "line")
	box.clear:SetPoint("RIGHT", box, "RIGHT", -10, 0)
	box.clear:Hide()
	local function hint()
		local t = S(e:GetText()) or ""
		setShown(box.hint, t == "" and not ui.searchFocus)
		setShown(box.clear, t ~= "")
	end
	box.Hint = hint
	safeScript(e, "OnEditFocusGained", function()
		ui.searchFocus = true
		box.fill:SetColor("hover")
		hint()
	end)
	safeScript(e, "OnEditFocusLost", function()
		ui.searchFocus = false
		box.fill:SetColor("card")
		hint()
	end)
	safeScript(e, "OnTextChanged", function(self)
		hint()
		applySearch(self:GetText(), false)
	end)
	safeScript(e, "OnEnterPressed", function(self)
		self:ClearFocus()
		applySearch(self:GetText(), true)
		local f = ui.filter
		if f and f.place then
			local any = false
			for _, d in ipairs(UI.Drivers()) do
				if matches(d, f) then any = true break end
			end
			if not any then UI.Toast("No drivers to " .. f.place .. " right now", "info") end
		elseif f then
			UI.Toast("No place called " .. f.text, "warn")
		end
	end)
	safeScript(e, "OnEscapePressed", function(self) self:ClearFocus() end)
	safeScript(box.clear, "OnClick", function()
		e:SetText("")
		e:ClearFocus()
		applySearch("", false)
	end)
	return box
end

local function buildEmpty(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints(parent)
	f.disc = CreateFrame("Frame", nil, f)
	f.disc:SetSize(56, 56)
	f.disc:SetPoint("TOP", f, "TOP", 0, -24)
	f.pulse = A.Pulse(f.disc, { size = 150, colour = "magenta", alpha = 0.4, period = 2.6, rings = 3, start = false })
	f.circle = T.Circle(f.disc, 56, "card", "ARTWORK")
	f.circle:SetPoint("CENTER", f.disc, "CENTER")
	f.glyph = T.Icon(f.disc, "summon", 28, "muted", "OVERLAY")
	f.glyph:SetPoint("CENTER", f.disc, "CENTER")
	f.title = T.Text(f, 14, "white", "CENTER", "bold")
	f.title:SetPoint("TOP", f.disc, "BOTTOM", 0, -16)
	f.title:SetWidth(INNER)
	f.sub = T.Text(f, "small", "muted", "CENTER", "regular")
	f.sub:SetPoint("TOP", f.title, "BOTTOM", 0, -6)
	f.sub:SetWidth(280)
	Try(f.sub, "SetWordWrap", true)
	f.ping = T.Pill(f, "Ping drivers", "dark", 160, 38)
	f.ping:SetPoint("TOP", f.sub, "BOTTOM", 0, -14)
	safeScript(f.ping, "OnClick", function(self)
		if self.inactive then return end
		local ok, why
		if type(W.Ping) == "function" then
			ok, why = call(W.Ping)
		elseif type(W.SendChannel) == "function" then
			call(W.SendChannel, "Q")
			ok = true
		end
		if ok then
			W.Sound("ping")
			UI.Toast(why == "recent" and "Drivers were just asked - they're answering" or "Asked every driver to check in", "info")
			ui.pingAt = now()

		elseif why == "offline" then
			UI.Toast("Can't reach the network right now", "warn")
		elseif tonumber(why) then
			ui.pingAt = now() - (20 - tonumber(why))
			UI.Toast("You can ping again in " .. why .. " s", "info")
		else
			UI.Toast("Can't ping right now", "warn")
		end
		UI.Refresh(true)
	end)
	f:Hide()
	return f
end

local function buildHome(body)
	local s = { frame = CreateFrame("Frame", nil, body) }
	local home = s.frame
	home:SetAllPoints(body)
	s.map = buildMapPanel(home)
	local sheet = T.Card(home, nil, nil, { colour = "panel", radius = 18 })
	sheet:SetPoint("TOPLEFT", home, "TOPLEFT", 0, -SHEET_TOP)
	sheet:SetPoint("BOTTOMRIGHT", home, "BOTTOMRIGHT", 0, 0)
	sheet:SetFrameLevel(s.map:GetFrameLevel() + 10)
	s.sheet = sheet
	local grab = CreateFrame("Frame", nil, sheet)
	grab:SetSize(36, 5)
	grab:SetPoint("TOP", sheet, "TOP", 0, -9)
	T.PillFill(grab, "raised", 5, "ARTWORK")
	s.search = buildSearch(sheet)
	s.header = T.Text(sheet, "heading", "white", "LEFT", "bold")
	s.header:SetPoint("TOPLEFT", sheet, "TOPLEFT", PAD, -84)
	s.count = T.Text(sheet, "small", "muted", "RIGHT", "regular")
	s.count:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", -PAD, -88)
	local clip = CreateFrame("Frame", nil, sheet)
	clip:SetPoint("TOPLEFT", sheet, "TOPLEFT", 0, -LIST_TOP)
	clip:SetPoint("BOTTOMRIGHT", sheet, "BOTTOMRIGHT", 0, 8)
	Try(clip, "SetClipsChildren", true)
	clip:EnableMouseWheel(true)
	safeScript(clip, "OnMouseWheel", function(_, delta)
		ui.scrollTarget = ui.scrollTarget - (tonumber(delta) or 0) * 64
		ui.scrollTarget = clamp(ui.scrollTarget, 0, ui.scrollMax or 0)
	end)
	s.clip = clip
	local content = CreateFrame("Frame", nil, clip)
	content:SetSize(WIN_W, 10)
	content:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
	s.content = content
	s.bar = T.Rounded(CreateFrame("Frame", nil, clip), { 1, 1, 1, 0.25 }, 1.5, "OVERLAY")
	s.barFrame = s.bar.parts.M:GetParent()
	s.barFrame:SetWidth(3)
	s.barFrame:Hide()
	s.empty = buildEmpty(clip)

	function s.enter()
		ui.manual = "home"
		ui.confirmKey = nil
		A.SlideUp(sheet, 40, 0.32)
		A.FadeIn(s.map, 0.3)
		s.staggerNext = true
	end

	function s.update()
		local all = UI.Drivers()
		local list = {}
		for _, d in ipairs(all) do
			if matches(d, ui.filter) then list[#list + 1] = d end
		end
		if s.map:IsVisible() then updateMap(s.map, all) end
		local f = ui.filter
		s.header:SetText(f and f.place and ("Drivers to " .. f.place) or (f and "Matching drivers" or "Drivers online"))
		local open = 0
		for _, d in ipairs(list) do
			if d.state == "open" then open = open + 1 end
		end
		s.count:SetText(#list == 0 and "" or (open .. " open · " .. #list .. " online"))
		UI.LayoutCards(s, list)
		-- the empty state
		local empty = #list == 0
		if empty then
			local e = s.empty
			if f then
				e.title:SetText(f.place and ("No drivers to " .. f.place .. " yet") or "No drivers match that")
			else
				e.title:SetText("No drivers online right now")
			end
			if not onNetwork() then
				e.sub:SetText("Can't reach the Wuber network. You may be in ten chat channels already.")
			else
				e.sub:SetText("Drivers show up here the moment they go online. Fares from " .. money(N(W.MIN_PRICE) or 5000) .. ".")

			end
			local wait = ui.pingAt and math.ceil(20 - (now() - ui.pingAt)) or 0
			if wait > 0 then
				e.ping:SetLabel("Ping again in " .. wait .. " s")
				e.ping:SetActive(false)
			else
				e.ping:SetLabel("Ping drivers")
				e.ping:SetActive(true)
			end
			if not e:IsShown() then
				A.FadeIn(e, 0.3)
				e.pulse:Start()
			end
		elseif s.empty:IsShown() then
			s.empty.pulse:Stop()
			s.empty:Hide()
		end
		s.search.Hint()
	end

	function s.tick() -- every 10 s while shown: the "Updated..." texts
		for _, c in pairs(ui.cards) do
			if c.view then c.ago:SetText(updatedText(c.view)) end
		end
	end

	return s
end

-- Lays out driver cards keyed by driver: new cards slide in, gone cards fade out, the rest
-- glide to their new places.
function UI.LayoutCards(s, list)
	local want = {}
	for i, d in ipairs(list) do want[d.key] = i end
	-- gone
	for key, c in pairs(ui.cards) do
		if not want[key] then
			ui.cards[key] = nil
			c.key = nil
			A.FadeOut(c, 0.18, function()
				c:Hide()
				ui.cardPool[#ui.cardPool + 1] = c
			end)
		end
	end
	local fresh = {}
	for i, d in ipairs(list) do
		local c = ui.cards[d.key]
		local y = -(i - 1) * (CARD_H + CARD_GAP)
		if not c then
			c = table.remove(ui.cardPool) or buildCard(s.content)
			ui.cards[d.key] = c
			c.curY = y
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", s.content, "TOPLEFT", PAD, y)
			fresh[#fresh + 1] = c
		end
		c.targetY = y
		fillCard(c, d)
	end
	local height = #list * (CARD_H + CARD_GAP)
	s.content:SetHeight(math.max(10, height))
	local clipH = N(s.clip:GetHeight()) or (BODY_H - SHEET_TOP - LIST_TOP - 8)
	ui.scrollMax = math.max(0, height - CARD_GAP - clipH)
	ui.scrollTarget = clamp(ui.scrollTarget, 0, ui.scrollMax)
	if s.staggerNext then
		-- the first look at Home: every card rises in turn
		s.staggerNext = false
		local order = {}
		for _, d in ipairs(list) do order[#order + 1] = ui.cards[d.key] end
		local shown = {}
		for i = 1, math.min(#order, 6) do shown[i] = order[i] end
		for i = 7, #order do order[i]:Show() order[i]:SetAlpha(order[i].disabled and 0.55 or 1) end
		A.Stagger(shown, 0.05, "SlideUp")
	else
		for i, c in ipairs(fresh) do A.SlideIn(c, 36, 0.28, (i - 1) * 0.05) end
	end
	-- the faded look of paused cards survives the animations
	for _, c in pairs(ui.cards) do
		if c.disabled then W.After(0.4, function() if c.disabled then c:SetAlpha(0.55) end end) end
	end
end

-- Per frame while Home is shown: cards glide, the list scrolls smoothly.
local function homeFrame(s, elapsed)
	local k = math.min(1, (elapsed or 0) * 14)
	for _, c in pairs(ui.cards) do
		if c.targetY and c.curY ~= c.targetY then
			local y = c.curY + (c.targetY - c.curY) * k
			if math.abs(y - c.targetY) < 0.5 then y = c.targetY end
			c.curY = y
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", s.content, "TOPLEFT", PAD, y)
		end
	end
	if ui.scroll ~= ui.scrollTarget then
		local y = ui.scroll + (ui.scrollTarget - ui.scroll) * k
		if math.abs(y - ui.scrollTarget) < 0.5 then y = ui.scrollTarget end
		ui.scroll = y
		s.content:ClearAllPoints()
		s.content:SetPoint("TOPLEFT", s.clip, "TOPLEFT", 0, y)
	end
	local max = ui.scrollMax or 0
	if max > 0 then
		local clipH = N(s.clip:GetHeight()) or 200
		local barH = math.max(24, clipH * clipH / (clipH + max))
		s.barFrame:SetHeight(barH)
		s.barFrame:ClearAllPoints()
		s.barFrame:SetPoint("TOPRIGHT", s.clip, "TOPRIGHT", -5, -(clipH - barH) * (ui.scroll / max))
		s.barFrame:Show()
	else
		s.barFrame:Hide()
	end
end

---------------------------------------------------------------------------
-- Screen: Confirm
---------------------------------------------------------------------------

local function backHeader(s, title)
	s.back = T.RoundButton(s.frame, "back", 36, "card")
	s.back:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 16, -10)
	safeScript(s.back, "OnClick", function() UI.Show("home") end)
	s.title = T.Text(s.frame, "heading", "white", "LEFT", "bold")
	s.title:SetPoint("LEFT", s.back, "RIGHT", 12, 0)
	s.title:SetText(title)
end

local function leaveGroup()
	local ok
	if type(W.LeaveGroup) == "function" then
		ok = call(W.LeaveGroup)
	else
		local fn = type(C_PartyInfo) == "table" and C_PartyInfo.LeaveParty or nil
		if type(fn) ~= "function" then fn = LeaveParty end
		ok = type(fn) == "function" and pcall(fn)
	end
	if ok then UI.Toast("You left your group", "info") else UI.Toast("Leave your group from your portrait menu", "warn") end
	W.After(0.5, function() UI.Refresh(true) end)
end

local function buildConfirm(body)
	local s = { frame = CreateFrame("Frame", nil, body) }
	local f = s.frame
	f:SetAllPoints(body)
	f:Hide()
	backHeader(s, "Confirm your ride")
	local card = T.Card(f, INNER, 206, { colour = "card", radius = 18 })
	card:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -64)
	s.card = card
	card.avatar = T.Circle(card, 52, "accent", "ARTWORK")
	card.avatar:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -16)
	card.glyph = T.Icon(card, "summon", 28, "white", "OVERLAY")
	card.glyph:SetPoint("CENTER", card.avatar, "CENTER")
	card.service = T.Text(card, 16, "white", "LEFT", "bold")
	card.service:SetPoint("TOPLEFT", card, "TOPLEFT", 80, -22)
	card.service:SetWidth(150)
	card.driver = T.Text(card, "small", "muted", "LEFT", "regular")
	card.driver:SetPoint("TOPLEFT", card, "TOPLEFT", 80, -44)
	card.driver:SetWidth(150)
	card.chip = T.Chip(card, "Open", "glow")
	card.chip:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -22)
	card.headline = T.Text(card, "title", "white", "LEFT", "bold")
	card.headline:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -84)
	card.headline:SetWidth(INNER - 32)
	Try(card.headline, "SetWordWrap", true)
	Try(card.headline, "SetMaxLines", 2)
	card.price = T.Text(card, "price", "gold", "LEFT", "bold")
	card.price:SetPoint("TOPLEFT", card.headline, "BOTTOMLEFT", 0, -6)
	card.with = T.Text(card, "body", "muted", "LEFT", "medium")
	card.with:SetPoint("LEFT", card.price, "RIGHT", 6, 0)
	card.with:SetText("· with Wuber")
	local line = card:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(T.RGB("line"))
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 16, 46)
	line:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -16, 46)
	card.team = T.Text(card, "small", "white", "LEFT", "medium")
	card.team:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 16, 17)
	card.badge = T.Badge(card, "No helpers needed", "gold")
	card.badge:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 16, 14)
	card.seats = T.Text(card, "small", "muted", "RIGHT", "regular")
	card.seats:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -16, 17)

	s.note = T.Text(f, "small", "muted", "LEFT", "regular")
	s.note:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 14, -288)
	s.note:SetText("You pay after you arrive, by trade.")
	local dot = T.Circle(f, 6, "accent", "ARTWORK")
	dot:SetPoint("RIGHT", s.note, "LEFT", -8, 0)

	local quote = T.Card(f, INNER, 52, { colour = "panel", radius = 12, shadow = false, border = "line" })
	quote:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -312)
	quote.label = T.Text(quote, 10, "muted", "LEFT", "regular")
	quote.label:SetPoint("TOPLEFT", quote, "TOPLEFT", 14, -9)
	quote.label:SetText("Your request whispers")
	quote.text = T.Text(quote, "small", "white", "LEFT", "medium")
	quote.text:SetPoint("TOPLEFT", quote, "TOPLEFT", 14, -27)
	quote.text:SetWidth(INNER - 28)
	s.quote = quote

	s.warn = T.Text(f, "small", "amber", "LEFT", "medium")
	s.warn:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -386)
	s.warn:SetWidth(180)
	Try(s.warn, "SetWordWrap", true)
	s.leave = T.Pill(f, "Leave group", "dark", 130, 34)
	s.leave:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -378)
	safeScript(s.leave, "OnClick", leaveGroup)

	s.request = T.Pill(f, "Request", "primary", INNER, 54)
	s.request:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
	safeScript(s.request, "OnClick", function(self)
		-- only reached when the secure button isn't over it
		if inCombat() then
			UI.Toast("Can't request in combat", "warn")
			return
		end
		local why = requestBlock(ui.confirmKey)
		if why then
			UI.Toast(BLOCK_TEXT[why] or "Can't request right now", "warn")
			return
		end
		ui.animUntil = 0
		UI.SyncSecure()
		UI.Toast("One moment - click Request again", "info")
	end)

	function s.enter(key)
		ui.manual = "confirm"
		ui.confirmKey = key or ui.confirmKey
		A.Pop(card, 0.34, 0.05)
	end

	function s.update()
		local d = UI.Driver(ui.confirmKey)
		if d then s.last = d end
		d = d or s.last
		if not d then
			card.service:SetText("Driver gone")
			card.headline:SetText("This driver went offline")
			s.request:SetLabel("Driver went offline")
			s.request:SetActive(false)
			return
		end
		card.service:SetText(d.service)
		card.driver:SetText(d.name)
		card.chip:SetChip(chipFor(d))
		card.headline:SetText("Summon to " .. d.dest)
		card.price:SetText(money(d.price))
		setShown(card.badge, d.team >= 3)
		setShown(card.team, d.team < 3)
		card.team:SetText(helpersText(d) .. " for the portal")
		card.seats:SetText(d.seats == 0 and "Group full" or (d.seats and ("Room for " .. d.seats) or ""))
		local _, line = requestMacro(d.key, d)
		s.quote.text:SetText(line or ("WTB summon to " .. d.dest .. " for " .. money(d.price)))
		local why = requestBlock(d.key)
		if not UI.Driver(ui.confirmKey) then why = "gone" end
		local grouped = why == "group"
		setShown(s.warn, grouped)
		setShown(s.leave, grouped)
		if grouped then s.warn:SetText("You're in a group. Leave it so the driver can invite you.") end
		if inCombat() then
			s.request:SetLabel("In combat")
			s.request:SetActive(false)
		elseif why then
			s.request:SetLabel(BLOCK_TEXT[why] or "Can't request")
			s.request:SetActive(false)
		else
			s.request:SetLabel(d.state == "busy" and ("Request · " .. money(d.price) .. " (busy)") or ("Request · " .. money(d.price)))
			s.request:SetActive(true)
		end
	end
	return s
end

---------------------------------------------------------------------------
-- Screen: Finding your driver
---------------------------------------------------------------------------

local function leaveRow(s, f, y)
	s.group = T.Text(f, "small", "amber", "CENTER", "medium")
	s.group:SetPoint("TOP", f, "TOP", 0, y)
	s.group:SetWidth(INNER)
	Try(s.group, "SetWordWrap", true)
	s.leave = T.Pill(f, "Leave group", "dark", 130, 32)
	s.leave:SetPoint("TOP", s.group, "BOTTOM", 0, -8)
	safeScript(s.leave, "OnClick", leaveGroup)
	s.group:Hide()
	s.leave:Hide()
end

local function buildFinding(body)
	local s = { frame = CreateFrame("Frame", nil, body) }
	local f = s.frame
	f:SetAllPoints(body)
	f:Hide()
	local radar = CreateFrame("Frame", nil, f)
	radar:SetSize(290, 290)
	radar:SetPoint("TOP", f, "TOP", 0, -10)
	s.radar = radar
	for i, size in ipairs({ 280, 190, 100 }) do
		local r = T.Tex(radar, "ring", "BACKGROUND", i)
		r:SetSize(size, size)
		r:SetPoint("CENTER", radar, "CENTER")
		r:SetVertexColor(1, 1, 1, 0.07)
	end
	s.sweep = T.Tex(radar, "radar_vm", "ARTWORK")
	s.sweep:SetSize(280, 280)
	s.sweep:SetPoint("CENTER", radar, "CENTER")
	s.sweep:SetVertexColor(1, 1, 1, 0.6)
	s.pulse = A.Pulse(radar, { size = 290, colour = "magenta", alpha = 0.45, period = 2.4, rings = 3, from = 0.22, start = false })
	local centre = CreateFrame("Frame", nil, radar)
	centre:SetSize(84, 84)
	centre:SetPoint("CENTER", radar, "CENTER")
	centre:SetFrameLevel(s.pulse.frame:GetFrameLevel() + 3)
	local halo = T.Tex(centre, "glow", "BACKGROUND", -1)
	halo:SetSize(150, 150)
	halo:SetPoint("CENTER", centre, "CENTER")
	halo:SetVertexColor(T.RGB("accent", 0.55))
	local ring = T.Circle(centre, 84, "black", "BACKGROUND")
	ring:SetPoint("CENTER", centre, "CENTER")
	local art = T.Tex(centre, "portal", "ARTWORK")
	art:SetSize(74, 74)
	art:SetPoint("CENTER", centre, "CENTER")
	s.centre = centre

	s.title = T.Text(f, "title", "white", "CENTER", "bold")
	s.title:SetPoint("TOP", f, "TOP", 0, -318)
	s.title:SetText("Finding your driver")
	s.sub = T.Text(f, "body", "muted", "CENTER", "regular")
	s.sub:SetPoint("TOP", s.title, "BOTTOM", 0, -8)
	s.sub:SetWidth(INNER)
	local track = CreateFrame("Frame", nil, f)
	track:SetSize(260, 4)
	track:SetPoint("TOP", f, "TOP", 0, -396)
	T.PillFill(track, "line", 4, "BACKGROUND")
	s.fill = CreateFrame("Frame", nil, track)
	s.fill:SetPoint("TOPLEFT", track, "TOPLEFT")
	s.fill:SetSize(260, 4)
	local grad = T.Tex(s.fill, "hgrad", "ARTWORK")
	grad:SetAllPoints(s.fill)
	s.left = T.Text(f, 10, "muted", "CENTER", "regular")
	s.left:SetPoint("TOP", track, "BOTTOM", 0, -8)
	leaveRow(s, f, -432)

	s.cancel = T.Pill(f, "Cancel request", "dark", INNER, 50)
	s.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
	safeScript(s.cancel, "OnClick", function() doCancel(false) end)

	function s.enter()
		A.Pop(centre, 0.4)
		s.pulse:Start()
		A.Spin(s.sweep, 2.4, true)
	end

	function s.leaveScreen()
		s.pulse:Stop()
		if s.sweep.wuberSpin then s.sweep.wuberSpin:Stop() end
	end

	function s.update()
		local rv = rideView()
		local who = rv and rv.short or "the driver"
		s.sub:SetText("Waiting for " .. who .. " to accept...")
		local grouped = rv and rv.grouped and inGroup() and not inGroupWith(rv.driverKey)
		setShown(s.group, grouped)
		setShown(s.leave, grouped)
		if grouped then s.group:SetText("You're in a group. Leave it so " .. who .. " can invite you.") end
		s.cancel:SetLabel("Cancel request")
		s.frameTick()
	end

	function s.frameTick()
		local rv = rideView()
		local at = rv and rv.at
		local left = at and (REQUEST_TIMEOUT - (now() - at)) or REQUEST_TIMEOUT
		left = clamp(left, 0, REQUEST_TIMEOUT)
		s.fill:SetWidth(math.max(4, 260 * left / REQUEST_TIMEOUT))
		s.left:SetText(math.ceil(left) .. " s")
	end
	return s
end

---------------------------------------------------------------------------
-- Screen: Driver found (accepted to paying)
---------------------------------------------------------------------------

local STEPS = { "Accepted", "Invite", "Portal", "Arrived", "Pay" }
local REACHED = { accepted = 1, invited = 2, ingroup = 2, summoning = 3, portal = 3, arrived = 4, paying = 5, done = 5 }
local STEP_X0, STEP_GAP = 34, 73

local function foundTexts(rv)
	local who, dest, price = rv.short, rv.dest, money(rv.price)
	local st = rv.state
	if rv.portalUp then
		return "The portal is up", "Accept the summon to go to " .. dest .. ".",
			"Accept the summon", "Click Accept summon below, or Accept on the game's summon window."
	elseif st == "accepted" then
		local eta = rv.etaAt and math.max(0, math.ceil(rv.etaAt - now())) or rv.eta
		local when = (eta and eta > 0) and ("in about " .. eta .. " s") or "shortly"
		return who .. " accepted", "A group invite is on its way " .. when .. ".",
			"Keep this window handy", "Accept the invite when it comes. You'll be summoned to " .. dest .. "."
	elseif st == "invited" then
		return who .. " invited you", "Join the group to be summoned.",
			"Accept the invite", "Click Accept invite below to join " .. who .. "'s group."
	elseif st == "ingroup" then
		return "You're in the group", who .. " is getting the portal ready.",
			"Stay put", "The Warlocks start the ritual soon. The portal pops up for you to accept."
	elseif st == "summoning" then
		return "The ritual is under way", "Your portal to " .. dest .. " is coming.",
			"Almost there", "When the summon window shows, accept it."
	elseif st == "arrived" then
		return "You've arrived", "Welcome to " .. dest .. ".",
			"Trade " .. who .. " " .. price, who .. " opens a trade. Put " .. price .. " in and accept."
	elseif st == "paying" then
		return "Time to pay", "Put " .. price .. " in the trade window.",
			"Trade " .. who .. " " .. price, "Put " .. price .. " in the trade window and click Trade."
	end
	return "On the way", "", "", ""
end

local function buildFound(body)
	local s = { frame = CreateFrame("Frame", nil, body) }
	local f = s.frame
	f:SetAllPoints(body)
	f:Hide()
	s.title = T.Text(f, "title", "white", "LEFT", "bold")
	s.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -20)
	s.title:SetWidth(INNER)
	s.sub = T.Text(f, "body", "muted", "LEFT", "regular")
	s.sub:SetPoint("TOPLEFT", s.title, "BOTTOMLEFT", 0, -6)
	s.sub:SetWidth(INNER)
	Try(s.sub, "SetWordWrap", true)

	-- the progress line
	local prog = CreateFrame("Frame", nil, f)
	prog:SetSize(WIN_W, 50)
	prog:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -100)
	s.prog = prog
	local track = prog:CreateTexture(nil, "BACKGROUND")
	track:SetColorTexture(T.RGB("line"))
	track:SetHeight(2)
	track:SetPoint("LEFT", prog, "TOPLEFT", STEP_X0, -8)
	track:SetWidth(STEP_GAP * 4)
	s.fill = prog:CreateTexture(nil, "BORDER")
	s.fill:SetTexture(T.MEDIA .. "hgrad")
	s.fill:SetHeight(3)
	s.fill:SetPoint("LEFT", prog, "TOPLEFT", STEP_X0, -8)
	s.fill:SetWidth(1)
	s.fillCur, s.fillTarget = 0, 0
	s.nodes = {}
	for i, name in ipairs(STEPS) do
		local n = CreateFrame("Frame", nil, prog)
		n:SetSize(16, 16)
		n:SetPoint("CENTER", prog, "TOPLEFT", STEP_X0 + (i - 1) * STEP_GAP, -8)
		n.dot = T.Circle(n, 12, "line", "ARTWORK")
		n.dot:SetPoint("CENTER", n, "CENTER")
		n.pulse = A.Pulse(n, { size = 34, colour = "magenta", alpha = 0.6, period = 1.6, rings = 2, start = false })
		n.label = T.Text(prog, 10, "muted", "CENTER", "medium")
		n.label:SetPoint("TOP", n, "BOTTOM", 0, -6)
		n.label:SetText(name)
		s.nodes[i] = n
	end

	-- the driver
	local card = T.Card(f, INNER, 80, { colour = "card", radius = 16 })
	card:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -164)
	card.avatar = T.Circle(card, 44, "accent", "ARTWORK")
	card.avatar:SetPoint("LEFT", card, "LEFT", 16, 0)
	card.glyph = T.Icon(card, "summon", 24, "white", "OVERLAY")
	card.glyph:SetPoint("CENTER", card.avatar, "CENTER")
	card.name = T.Text(card, 14, "white", "LEFT", "bold")
	card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 72, -20)
	card.name:SetWidth(150)
	card.service = T.Text(card, "small", "muted", "LEFT", "regular")
	card.service:SetPoint("TOPLEFT", card, "TOPLEFT", 72, -42)
	card.service:SetWidth(150)
	card.price = T.Text(card, "price", "gold", "RIGHT", "bold")
	card.price:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -18)
	card.dest = T.Text(card, "small", "muted", "RIGHT", "regular")
	card.dest:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -44)
	card.dest:SetWidth(120)
	s.card = card

	-- what to do now
	local tip = T.Card(f, INNER, 92, { colour = "panel", radius = 16, shadow = false, border = "line" })
	tip:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -260)
	tip.head = T.Text(tip, 15, "white", "LEFT", "bold")
	tip.head:SetPoint("TOPLEFT", tip, "TOPLEFT", 16, -16)
	tip.head:SetWidth(INNER - 32)
	tip.body = T.Text(tip, "small", "muted", "LEFT", "regular")
	tip.body:SetPoint("TOPLEFT", tip.head, "BOTTOMLEFT", 0, -6)
	tip.body:SetWidth(INNER - 32)
	Try(tip.body, "SetWordWrap", true)
	Try(tip.body, "SetMaxLines", 3)
	s.tip = tip

	s.action = T.Pill(f, "", "primary", INNER, 52)
	s.action:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 70)
	safeScript(s.action, "OnClick", function(self)
		if self.inactive or not self.what then return end
		UI.DoAction(self.what)
	end)
	s.cancel = T.Pill(f, "Cancel ride", "ghost", INNER, 40)
	s.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 22)
	s.cancel.label:SetTextColor(T.RGB("muted"))
	safeScript(s.cancel, "OnClick", function() doCancel(false) end)

	function s.enter()
		s.reached = nil
		A.Pop(card, 0.34)
		A.SlideUp(tip, 20, 0.3, 0.08)
	end

	function s.leaveScreen()
		for _, n in ipairs(s.nodes) do n.pulse:Stop() end
	end

	function s.update()
		local rv = rideView()
		if not rv then return end
		local title, sub, head, tipText = foundTexts(rv)
		s.title:SetText(title)
		s.sub:SetText(sub)
		s.tip.head:SetText(head)
		s.tip.body:SetText(tipText)
		card.name:SetText(rv.driver)
		card.service:SetText(rv.service or "Wuber driver")
		card.price:SetText(money(rv.price))
		card.dest:SetText("to " .. rv.dest)
		-- progress
		local reached = REACHED[rv.state] or 1
		s.fillTarget = (reached - 1) * STEP_GAP
		for i, n in ipairs(s.nodes) do
			local done = i <= reached
			n.dot:SetVertexColor(T.RGB(done and (i == reached and "magenta" or "glow") or "line"))
			n.label:SetTextColor(T.RGB(done and "white" or "muted"))
			if i == reached and rv.state ~= "done" then
				if not n.pulse.running then n.pulse:Start() end
			elseif n.pulse.running then
				n.pulse:Stop()
			end
		end
		if s.reached and reached > s.reached then
			A.Pop(s.nodes[reached], 0.3)
			A.SlideUp(tip, 12, 0.25)
		end
		s.reached = reached
		-- the context button
		local a = s.action
		a.what = nil
		local grouped = rv.grouped and rv.rank < RIDE_RANK.ingroup and inGroup() and not inGroupWith(rv.driverKey)
		if grouped then
			a:SetLabel("Leave your group first")
			a:SetStyle("dark")
			a:SetActive(true)
			a.what = "leave"
		elseif rv.portalUp then
			a:SetLabel("Accept summon")
			a:SetStyle("primary")
			a:SetActive(true)
			a.what = "summon"
		elseif rv.state == "invited" then
			a:SetLabel("Accept invite")
			a:SetStyle("primary")
			a:SetActive(true)
			a.what = "invite"
		else
			local waiting = {
				accepted = "Waiting for the invite", ingroup = "Waiting for the portal",
				summoning = "The ritual is under way", arrived = "Waiting for the trade",
				paying = "Pay " .. money(rv.price) .. " in the trade window",
			}
			a:SetLabel(waiting[rv.state] or "On the way")
			a:SetActive(false)
		end
		setShown(s.cancel, cancellable(rv))
	end

	function s.frameTick(elapsed)
		if s.fillCur ~= s.fillTarget then
			local k = math.min(1, (elapsed or 0) * 6)
			local v = s.fillCur + (s.fillTarget - s.fillCur) * k
			if math.abs(v - s.fillTarget) < 0.5 then v = s.fillTarget end
			s.fillCur = v
			s.fill:SetWidth(math.max(1, v))
		end
	end
	return s
end

local function hidePopup(which, flag)
	if type(StaticPopup_FindVisible) == "function" then
		local dialog = call(StaticPopup_FindVisible, which)
		if type(dialog) == "table" and flag then dialog[flag] = 1 end
	end
	if type(StaticPopup_Hide) == "function" then pcall(StaticPopup_Hide, which) end
end

-- The Found screen's button: "invite", "summon" or "leave". Runs from the click.
function UI.DoAction(what)
	if what == "leave" then
		leaveGroup()
	elseif what == "invite" then
		if type(W.AcceptInvite) == "function" then
			local ok, line = call(W.AcceptInvite)
			if not ok then UI.Toast(S(line) or "Click Accept on the invite window", "warn") end
		else
			local ok = type(AcceptGroup) == "function" and pcall(AcceptGroup)
			if ok then
				-- hiding the popup without this flag would decline the invite
				hidePopup("PARTY_INVITE", "inviteAccepted")
				W.After(0.2, function() hidePopup("PARTY_INVITE", "inviteAccepted") end)
			else
				UI.Toast("Click Accept on the invite window", "warn")
			end
		end
	elseif what == "summon" then
		if inCombat() then
			UI.Toast("Leave combat first", "warn")
			return
		end
		if type(W.AcceptSummon) == "function" then
			local ok, line = call(W.AcceptSummon)
			if not ok then UI.Toast(S(line) or "Click Accept on the summon window", "warn") end
		else
			local fn = type(C_SummonInfo) == "table" and C_SummonInfo.ConfirmSummon
			local ok = type(fn) == "function" and pcall(fn)
			if ok then
				hidePopup("CONFIRM_SUMMON")
			else
				UI.Toast("Click Accept on the summon window", "warn")
			end
		end
	end
	UI.Refresh(true)
end

---------------------------------------------------------------------------
-- Screen: Done
---------------------------------------------------------------------------

local function buildDone(body)
	local s = { frame = CreateFrame("Frame", nil, body) }
	local f = s.frame
	f:SetAllPoints(body)
	f:Hide()
	local badge = CreateFrame("Frame", nil, f)
	badge:SetSize(96, 96)
	badge:SetPoint("TOP", f, "TOP", 0, -46)
	s.ring = A.Pulse(badge, { size = 200, colour = "magenta", alpha = 0.55, period = 1.4, rings = 1, from = 0.45, start = false })
	local halo = T.Tex(badge, "glow", "BACKGROUND")
	halo:SetSize(190, 190)
	halo:SetPoint("CENTER", badge, "CENTER")
	halo:SetVertexColor(T.RGB("accent", 0.5))
	local disc = CreateFrame("Frame", nil, badge)
	disc:SetAllPoints(badge)
	disc:SetFrameLevel(s.ring.frame:GetFrameLevel() + 2)
	local circle = T.Circle(disc, 96, "accent", "ARTWORK")
	circle:SetPoint("CENTER", disc, "CENTER")
	s.disc = disc
	local tick = CreateFrame("Frame", nil, disc)
	tick:SetSize(52, 52)
	tick:SetPoint("CENTER", disc, "CENTER", 0, -1)
	local mark = T.Icon(tick, "check", 52, "white", "OVERLAY")
	mark:SetPoint("CENTER", tick, "CENTER")
	s.tick = tick

	s.title = T.Text(f, "title", "white", "CENTER", "bold")
	s.title:SetPoint("TOP", f, "TOP", 0, -168)
	s.title:SetWidth(INNER)
	Try(s.title, "SetWordWrap", true)
	Try(s.title, "SetMaxLines", 2)
	s.sub = T.Text(f, "body", "muted", "CENTER", "regular")
	s.sub:SetPoint("TOP", s.title, "BOTTOM", 0, -8)
	s.sub:SetWidth(INNER)

	local rate = T.Card(f, INNER, 128, { colour = "card", radius = 18 })
	rate:SetPoint("TOP", f, "TOP", 0, -262)
	rate.q = T.Text(rate, 14, "white", "CENTER", "bold")
	rate.q:SetPoint("TOP", rate, "TOP", 0, -18)
	rate.q:SetText("How was your ride?")
	rate.note = T.Text(rate, "small", "muted", "CENTER", "regular")
	rate.note:SetPoint("BOTTOM", rate, "BOTTOM", 0, 16)
	s.rate = rate
	s.stars = {}
	local function paint(n)
		for i, st in ipairs(s.stars) do
			local on = i <= n
			st.fill:SetShown(on)
			st.outline:SetShown(not on)
			st.fill:SetVertexColor(T.RGB("gold"))
		end
	end
	s.paint = paint
	for i = 1, 5 do
		local st = CreateFrame("Button", nil, rate)
		st:SetSize(40, 40)
		st:SetPoint("TOP", rate, "TOP", (i - 3) * 46, -46)
		st.fill = T.Icon(st, "star", 32, "gold", "ARTWORK")
		st.fill:SetPoint("CENTER", st, "CENTER")
		st.outline = T.Icon(st, "star_outline", 32, "goldDeep", "ARTWORK")
		st.outline:SetPoint("CENTER", st, "CENTER")
		st.fill:Hide()
		st:RegisterForClicks("LeftButtonUp")
		safeScript(st, "OnEnter", function()
			if not s.rated then paint(i) end
		end)
		safeScript(st, "OnLeave", function()
			if not s.rated then paint(s.stars.chosen or 0) end
		end)
		safeScript(st, "OnClick", function()
			if s.rated then return end
			local ok = call(W.Rate, i)
			s.stars.chosen = i
			s.rated = ok ~= false
			paint(i)
			local pops = {}
			for k = 1, i do pops[k] = s.stars[k] end
			A.Stagger(pops, 0.06, "Pop")
			rate.note:SetText(s.rated and ("Thanks! You gave " .. i .. (i == 1 and " star." or " stars.")) or "Couldn't send your rating")
			W.Sound("click")
		end)
		s.stars[i] = st
	end

	s.saved = T.Text(f, "small", "muted", "CENTER", "regular")
	s.saved:SetPoint("BOTTOM", f, "BOTTOM", 0, 84)
	s.saved:SetText("Saved to your trips")
	s.done = T.Pill(f, "Done", "primary", INNER, 52)
	s.done:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
	safeScript(s.done, "OnClick", function()
		UI.Dismiss()
	end)

	function s.enter()
		local rv = rideView()
		s.rated = rv and rv.rated or false
		s.stars.chosen = rv and rv.stars or nil
		paint(s.stars.chosen or 0)
		rate.note:SetText(s.rated and "Thanks for rating" or "Tap a star")
		A.Pop(disc, 0.45)
		A.Pop(tick, 0.35, 0.22)
		s.ring:Start()
		local token = {}
		s.token = token
		W.After(1.45, function() if s.token == token then s.ring:Stop() end end)
		A.SlideUp(rate, 24, 0.35, 0.18)
		W.Sound("found")
	end

	function s.leaveScreen() s.ring:Stop() end

	function s.update()
		local rv = rideView()
		if not rv then return end
		s.title:SetText("You've arrived in " .. rv.dest)
		s.sub:SetText((rv.price and rv.price > 0) and ("Paid " .. money(rv.price) .. " to " .. rv.short) or ("Thanks for riding with " .. rv.short))
	end
	return s
end

---------------------------------------------------------------------------
-- Screen: Sorry (declined, timed out, cancelled, failed)
---------------------------------------------------------------------------

local REASON_TEXT = {
	busy = "They're busy with another ride.",
	full = "Their group is full right now.",
	closed = "They've just closed for now.",
	blocked = "They can't take your request.",
	price = "Their price has just changed.",
}

-- The cheapest open or busy driver to the same place, not the one who said no.
local function nextBest(rv)
	if not rv then return nil end
	for _, d in ipairs(UI.Drivers()) do
		if d.key ~= rv.driverKey and d.state ~= "paused" and d.key ~= myKey() then
			local same
			if W.SamePlace then same = call(W.SamePlace, d.dest, rv.dest) end
			if same == nil then same = d.dest:lower() == rv.dest:lower() end
			if same then return d end
		end
	end
	return nil
end

local function buildSorry(body)
	local s = { frame = CreateFrame("Frame", nil, body) }
	local f = s.frame
	f:SetAllPoints(body)
	f:Hide()
	local icon = CreateFrame("Frame", nil, f)
	icon:SetSize(84, 84)
	icon:SetPoint("TOP", f, "TOP", 0, -64)
	s.circle = T.Circle(icon, 84, "card", "ARTWORK")
	s.circle:SetPoint("CENTER", icon, "CENTER")
	s.glyph = T.Icon(icon, "close", 34, "white", "OVERLAY")
	s.glyph:SetPoint("CENTER", icon, "CENTER")
	s.icon = icon
	s.title = T.Text(f, 22, "white", "CENTER", "bold")
	s.title:SetPoint("TOP", f, "TOP", 0, -174)
	s.title:SetWidth(INNER)
	Try(s.title, "SetWordWrap", true)
	Try(s.title, "SetMaxLines", 2)
	s.sub = T.Text(f, "body", "muted", "CENTER", "regular")
	s.sub:SetPoint("TOP", s.title, "BOTTOM", 0, -8)
	s.sub:SetWidth(300)
	Try(s.sub, "SetWordWrap", true)

	local alt = CreateFrame("Button", nil, f)
	alt:SetSize(INNER, 72)
	alt:SetPoint("TOP", f, "TOP", 0, -290)
	alt.bg = T.Rounded(alt, "card", 16, "BACKGROUND")
	alt.kicker = T.Text(alt, 10, "glow", "LEFT", "bold")
	alt.kicker:SetPoint("TOPLEFT", alt, "TOPLEFT", 16, -14)
	alt.kicker:SetText("NEXT BEST TO THE SAME PLACE")
	alt.name = T.Text(alt, 14, "white", "LEFT", "bold")
	alt.name:SetPoint("TOPLEFT", alt, "TOPLEFT", 16, -32)
	alt.name:SetWidth(200)
	alt.price = T.Text(alt, "price", "gold", "RIGHT", "bold")
	alt.price:SetPoint("RIGHT", alt, "RIGHT", -16, -6)
	alt:RegisterForClicks("LeftButtonUp")
	safeScript(alt, "OnEnter", function(self) self.bg:SetColor("hover") end)
	safeScript(alt, "OnLeave", function(self) self.bg:SetColor("card") end)
	safeScript(alt, "OnClick", function(self)
		local key = self.key
		if not key then return end
		UI.Dismiss(true)
		UI.Show("confirm", key)
	end)
	alt:Hide()
	s.alt = alt

	s.again = T.Pill(f, "Try another driver", "primary", INNER, 52)
	s.again:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
	safeScript(s.again, "OnClick", function() UI.Dismiss() end)

	function s.enter()
		A.Pop(icon, 0.4)
	end

	function s.update()
		local rv = rideView()
		local who = rv and rv.short or "The driver"
		local st = rv and rv.state
		if st == "timeout" then
			s.title:SetText("No answer from " .. who)
			s.sub:SetText("Drivers sometimes step away. Try another one.")
			s.glyph:SetTexture(T.MEDIA .. "ride")
		elseif st == "cancelled" then
			s.title:SetText("Ride cancelled")
			s.sub:SetText("Nothing to pay. Pick another driver when you're ready.")
			s.glyph:SetTexture(T.MEDIA .. "close")
		elseif st == "failed" then
			s.title:SetText("This ride didn't work out")
			s.sub:SetText("Something went wrong along the way. Try another driver.")
			s.glyph:SetTexture(T.MEDIA .. "close")
		else
			s.title:SetText(who .. " can't take this one")
			s.sub:SetText(REASON_TEXT[rv and rv.reason or ""] or "They can't take your ride right now.")
			s.glyph:SetTexture(T.MEDIA .. "close")
		end
		local d = nextBest(rv)
		if d then
			alt.key = d.key
			alt.name:SetText(d.service .. " · " .. d.short)
			alt.price:SetText(money(d.price))
			if not alt:IsShown() then A.SlideUp(alt, 20, 0.3, 0.1) end
		else
			alt.key = nil
			alt:Hide()
		end
	end
	return s
end

---------------------------------------------------------------------------
-- Which screen, and moving between screens
---------------------------------------------------------------------------

local function wantedScreen()
	local rv = rideView()
	if rv and not ui.dismissed[rv.id] then
		local st = rv.state
		if st == "requesting" then return "finding" end
		if st == "done" then return "done" end
		if st == "declined" or st == "timeout" or st == "failed" or st == "cancelled" then return "sorry" end
		return "found"
	end
	if ui.manual == "confirm" and ui.confirmKey then return "confirm" end
	return "home"
end

local function goTo(name, arg, instant)
	local new = screens[name]
	if not new then return end
	local oldName = ui.screen
	local old = oldName and screens[oldName]
	if oldName == name then
		if new.enter and arg ~= nil then W.Safe("screen", new.enter, arg) end
		return
	end
	ui.screen = name
	hideOverlays()
	if old then
		if old.leaveScreen then W.Safe("screen", old.leaveScreen) end
		if instant then old.frame:Hide() end
	end
	local dir = (SCREEN_RANK[name] or 0) >= (SCREEN_RANK[oldName or ""] or 0) and 1 or -1
	if new.update then W.Safe("screen " .. name, new.update) end
	if instant or not old then
		new.frame:Show()
		new.frame:SetAlpha(1)
	else
		A.SlideOut(old.frame, -48 * dir, 0.2)
		A.SlideIn(new.frame, 48 * dir, 0.28)
	end
	if new.enter then W.Safe("screen " .. name, new.enter, arg) end
	if new.update then W.Safe("screen " .. name, new.update) end
	ui.animUntil = now() + 0.34
	W.After(0.36, function() UI.SyncSecure() end)
end

-- Forgets a finished ride (Done, Try another driver) and goes back to Home.
function UI.Dismiss(quiet)
	local rv = rideView()
	if rv then
		ui.dismissed[rv.id] = true
		if ENDED[rv.state] then call(W.ClearRide) end
	end
	ui.manual = "home"
	ui.confirmKey = nil
	if not quiet then UI.Refresh(true) end
end

---------------------------------------------------------------------------
-- Ride toasts and the minimap flash
---------------------------------------------------------------------------

local function onRide()
	local rv = rideView()
	if not rv then return end
	local seen = ui.toasted[rv.id]
	local mark = rv.state .. (rv.portalUp and "+portal" or "")
	if seen == mark then return end
	ui.toasted[rv.id] = mark
	local who, dest, price = rv.short, rv.dest, money(rv.price)
	if rv.portalUp then
		UI.Toast("Accept the summon to " .. dest .. "!", "summon")
	elseif rv.state == "accepted" then
		UI.Toast(who .. " accepted - " .. price .. " to " .. dest, "found")
	elseif rv.state == "invited" then
		UI.Toast(who .. " invited you. Accept the invite.", "info")
	elseif rv.state == "arrived" then
		UI.Toast("You've arrived in " .. dest, "found")
	elseif rv.state == "paying" then
		UI.Toast("Trade " .. who .. " " .. price, "info")
	elseif rv.state == "declined" then
		UI.Toast(who .. " can't take this ride", "warn")
	elseif rv.state == "timeout" then
		UI.Toast("No answer from " .. who, "warn")
	elseif rv.state == "failed" then
		UI.Toast("The ride didn't work out", "error")
	end
	UI.FlashMinimap(rv.portalUp and not (ui.win and ui.win:IsShown()))
end

---------------------------------------------------------------------------
-- Building the window
---------------------------------------------------------------------------

local function buildSplash(win)
	local sp = CreateFrame("Frame", nil, win)
	sp:SetAllPoints(win)
	sp:SetFrameLevel(win:GetFrameLevel() + 60)
	sp:EnableMouse(false) -- click-through: any click ends it (GLOBAL_MOUSE_DOWN)
	sp.bg = T.Tex(sp, "winbg", "BACKGROUND")
	sp.bg:SetAllPoints(sp)
	sp.bg:SetTexCoord(0, 504 / 512, 0, 840 / 1024)
	sp.glow = T.Tex(sp, "glow", "BORDER")
	sp.glow:SetSize(420, 420)
	sp.glow:SetPoint("CENTER", sp, "CENTER", 0, 30)
	sp.glow:SetVertexColor(T.RGB("accent", 0.35))
	sp.art = CreateFrame("Frame", nil, sp)
	sp.art:SetSize(250, 250)
	sp.art:SetPoint("CENTER", sp, "CENTER", 0, 30)
	local badge = T.Tex(sp.art, "badge", "ARTWORK")
	badge:SetAllPoints(sp.art)
	sp.caption = T.Text(sp, "small", "muted", "CENTER", "medium")
	sp.caption:SetPoint("TOP", sp.art, "BOTTOM", 0, -22)
	sp.caption:SetText("Summons, on demand")
	sp:Hide()
	return sp
end

function UI.EndSplash()
	local sp = ui.splash
	if not (sp and ui.splashing) then return end
	ui.splashing = false
	ui.splashToken = (ui.splashToken or 0) + 1
	A.SlideOut(sp.art, 0, 0.3, nil, 40)
	A.FadeOut(sp, 0.4, function()
		ui.animUntil = 0
		UI.SyncSecure()
	end)
	local home = screens.home
	if ui.screen == "home" and home then W.Safe("splash", home.enter) end
	ui.animUntil = now() + 0.45
end

local function startSplash()
	local sp = ui.splash
	if not sp then return end
	ui.splashed, ui.splashing = true, true
	sp:SetAlpha(1)
	sp:Show()
	A.Pop(sp.art, 0.6)
	A.FadeIn(sp.caption, 0.4, 0.3)
	local token = (ui.splashToken or 0) + 1
	ui.splashToken = token
	W.After(1.2, function()
		if ui.splashToken == token then UI.EndSplash() end
	end)
end

local function buildWindow()
	if ui.win then return ui.win end
	local win = CreateFrame("Frame", "WuberFrame", UIParent)
	ui.win = win
	win:SetSize(WIN_W, WIN_H)
	win:SetFrameStrata("HIGH")
	Try(win, "SetToplevel", true)
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	win:Hide()
	-- the night-sky background (gradient, rounded, edged) is one texture, plus a shadow
	win.shadow = T.NineSlice(win, "shadow", 28, 31 / 64, "BACKGROUND", -8, 16)
	win.shadow:SetColor("shadow")
	win.bg = T.Tex(win, "winbg", "BACKGROUND", -4)
	win.bg:SetAllPoints(win)
	win.bg:SetTexCoord(0, 504 / 512, 0, 840 / 1024)
	if type(UISpecialFrames) == "table" then
		local there = false
		for _, n in ipairs(UISpecialFrames) do if n == "WuberFrame" then there = true end end
		if not there then table.insert(UISpecialFrames, "WuberFrame") end
	end

	-- top bar (drag handle)
	local top = CreateFrame("Frame", nil, win)
	top:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
	top:SetHeight(TOP_H)
	top:SetFrameLevel(win:GetFrameLevel() + 30)
	top:EnableMouse(true)
	top:RegisterForDrag("LeftButton")
	ui.top = top
	local logo = T.Tex(top, "portal", "ARTWORK")
	logo:SetSize(28, 28)
	logo:SetPoint("LEFT", top, "LEFT", 16, -2)
	local mark = T.Tex(top, "wordmark", "ARTWORK")
	mark:SetSize(68, 24)
	mark:SetTexCoord(0, 180 / 256, 0, 1)
	mark:SetVertexColor(T.RGB("white"))
	mark:SetPoint("LEFT", logo, "RIGHT", 7, 0)
	ui.wordmark = mark
	local close = T.RoundButton(top, "close", 32, "card")
	close:SetPoint("RIGHT", top, "RIGHT", -16, -2)
	safeScript(close, "OnClick", function() UI.Toggle(false) end)
	safeScript(top, "OnDragStart", function()
		ui.moving = true
		hideOverlays()
		win:StartMoving()
	end)
	safeScript(top, "OnDragStop", function()
		win:StopMovingOrSizing()
		ui.moving = false
		savePosition()
		UI.SyncSecure()
	end)

	-- the Ride tab and its screens
	local ride = addTabNow("Ride")
	screens.home = buildHome(ride)
	screens.confirm = buildConfirm(ride)
	screens.finding = buildFinding(ride)
	screens.found = buildFound(ride)
	screens.done = buildDone(ride)
	screens.sorry = buildSorry(ride)
	ui.tab = "Ride"
	ride:Show()
	for _, t in ipairs(ui.pendingTabs) do addTabNow(t.name, t.build) end
	ui.pendingTabs = {}
	layoutTabs()

	ui.splash = buildSplash(win)

	safeScript(win, "OnShow", function()
		ui.dirty = true
		UI.FlashMinimap(false)
	end)
	safeScript(win, "OnHide", function()
		if ui.splashing then UI.EndSplash() end
		local e = screens.home and screens.home.search and screens.home.search.edit
		if e then e:ClearFocus() end
		hideOverlays()
		if ui.moving then
			win:StopMovingOrSizing()
			ui.moving = false
		end
	end)
	local tickAt = 0
	safeScript(win, "OnUpdate", function(_, elapsed)
		local t = now()
		if ui.tab == "Ride" then
			local scr = screens[ui.screen]
			if ui.screen == "home" then homeFrame(screens.home, elapsed) end
			if scr and scr.frameTick then scr.frameTick(elapsed) end
		end
		-- place the secure overlay the moment an animation ends (not at the next 1 s refresh),
		-- so a quick click on Request never meets "One moment"
		if ui.animUntil > 0 and t >= ui.animUntil and ui.syncedFor ~= ui.animUntil then
			ui.syncedFor = ui.animUntil
			UI.SyncSecure()
		end
		if ui.dirty and t - ui.lastRefresh >= REFRESH_GAP then
			UI.RefreshNow()
		elseif t - ui.lastRefresh >= 1 then
			UI.RefreshNow() -- countdowns, combat and group changes
		end
		if t - tickAt >= 10 then
			tickAt = t
			local home = screens.home
			if home and ui.screen == "home" then home.tick() end
		end
	end)

	goTo(wantedScreen(), nil, true)
	return win
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------

local function placeMinimap(b)
	local angle = math.rad(N(W.db and W.db.minimapAngle) or 215)
	local r = ((N(Minimap:GetWidth()) or 140) / 2) + 10
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function buildMinimap()
	if ui.minimap or type(Minimap) ~= "table" then return end
	local b = CreateFrame("Button", "WuberMinimapButton", Minimap)
	ui.minimap = b
	b:SetSize(32, 32)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b.shadow = T.Circle(b, 36, { 0, 0, 0, 0.5 }, "BACKGROUND")
	b.shadow:SetPoint("CENTER", b, "CENTER", 0, -1)
	b.face = T.Tex(b, "minimap", "ARTWORK")
	b.face:SetSize(30, 30)
	b.face:SetPoint("CENTER", b, "CENTER")
	b.hover = T.Tex(b, "ring", "OVERLAY")
	b.hover:SetSize(32, 32)
	b.hover:SetPoint("CENTER", b, "CENTER")
	b.hover:SetVertexColor(T.RGB("glow"))
	b.hover:Hide()
	b.badge = T.Circle(b, 9, "glow", "OVERLAY")
	b.badge:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	b.badge:Hide()
	b.pulse = A.Pulse(b, { size = 64, colour = "magenta", alpha = 0.8, period = 1.2, rings = 2, start = false })

	safeScript(b, "OnClick", function(_, which)
		if which == "RightButton" then
			if not UI.Show("drive") then UI.Toast("Driving isn't available here", "info") end
		else
			UI.Toggle()
		end
	end)
	safeScript(b, "OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local ok = pcall(function()
				local mx, my = Minimap:GetCenter()
				local x, y = GetCursorPosition()
				local scale = Minimap:GetEffectiveScale()
				mx, my, x, y, scale = N(mx), N(my), N(x), N(y), N(scale)
				if not (mx and my and x and y and scale and scale > 0) then return end
				if W.db then W.db.minimapAngle = math.floor(math.deg(math.atan2(y / scale - my, x / scale - mx)) + 0.5) end
				placeMinimap(self)
			end)
			if not ok then self:SetScript("OnUpdate", nil) end
		end)
	end)
	safeScript(b, "OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	safeScript(b, "OnEnter", function(self)
		self.hover:Show()
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Wuber")
		local list = UI.Drivers()
		local open = 0
		for _, d in ipairs(list) do if d.state == "open" then open = open + 1 end end
		GameTooltip:AddLine(open == 1 and "1 driver open now" or (open .. " drivers open now"), 1, 1, 1)
		local rv = rideView()
		if rideActive(rv) then GameTooltip:AddLine("Your ride: " .. rv.short .. " to " .. rv.dest, 0.54, 0.36, 1) end
		GameTooltip:AddLine("Left-click: open or close. Right-click: drive. Drag: move.", 0.56, 0.56, 0.58, true)
		GameTooltip:Show()
	end)
	safeScript(b, "OnLeave", function(self)
		self.hover:Hide()
		if GameTooltip then GameTooltip:Hide() end
	end)
	placeMinimap(b)
	if W.db and W.db.minimapHidden then b:Hide() end
end

-- Pulses the minimap button (the summon is up while the window is closed).
function UI.FlashMinimap(on)
	local b = ui.minimap
	if not b then return end
	if on then
		if not b.pulse.running then b.pulse:Start() end
	elseif b.pulse.running then
		b.pulse:Stop()
	end
end

local function refreshMinimap()
	local b = ui.minimap
	if not b then return end
	local open = false
	for _, d in ipairs(UI.Drivers()) do
		if d.state == "open" then open = true break end
	end
	setShown(b.badge, open)
	local rv = rideView()
	if not (rv and rv.portalUp) then UI.FlashMinimap(false) end
end

---------------------------------------------------------------------------
-- Refreshing
---------------------------------------------------------------------------

-- Refresh(): something changed; the window redraws within a quarter of a second.
function UI.Refresh(soon)
	ui.dirty = true
	if soon then ui.lastRefresh = 0 end
end

function UI.RefreshNow()
	ui.dirty = false
	ui.lastRefresh = now()
	W.Safe("minimap", refreshMinimap)
	local win = ui.win
	if not (win and win:IsShown()) then return end
	raise()
	local want = wantedScreen()

	if want ~= ui.screen then goTo(want) end
	local scr = screens[ui.screen]
	if scr and scr.update and ui.tab == "Ride" then W.Safe("screen " .. tostring(ui.screen), scr.update) end
	UI.SyncSecure()
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

-- Toggle(show): true opens, false closes, nil flips.
function UI.Toggle(show)
	local win = buildWindow()
	if show == nil then show = not win:IsShown() end
	if show then
		raise()
		if win:IsShown() and not ui.closing then return end

		ui.closing = false
		applyScale()
		placeWindow()
		raise()
		W.Sound("open")
		ui.animUntil = now() + 0.35
		A.Move(win, 0, -16, 0.26)
		if not ui.splashed then startSplash() end
		UI.RefreshNow()
		W.After(0.4, function() UI.SyncSecure() end)
	else
		if not win:IsShown() then return end
		hideOverlays()
		W.Sound("close")
		ui.closing = true
		A.FadeOut(win, 0.15, function() ui.closing = false end)
	end
end

-- Show(screen, arg): opens the window on a screen: "home", "confirm" (arg = driver key),
-- or the ride's own screens ("finding", "found", "done", "sorry"), which follow W.ride.
function UI.Show(screen, arg)
	screen = S(screen) or "home"
	-- a tab's name ("drive", "Drive") opens the window on that tab
	if not screens[screen] and screen ~= "confirm" then
		UI.Toggle(true)
		for _, tab in ipairs(ui.tabs) do
			if tab.name:lower() == screen:lower() then return UI.SelectTab(tab.name) end
		end
		return false
	end
	UI.Toggle(true)
	if ui.tab ~= "Ride" then UI.SelectTab("Ride") end
	if screen == "confirm" then
		local key = S(arg)
		if key and W.Key then key = W.drivers and W.drivers[key] and key or W.Key(key) end
		ui.confirmKey = key
		ui.manual = "confirm"
		screens.confirm.last = nil
		if wantedScreen() == "confirm" then goTo("confirm", key) end
	elseif screen == "home" then
		ui.manual = "home"
		ui.confirmKey = nil
		if wantedScreen() == "home" then goTo("home") end
	elseif screens[screen] then
		goTo(screen, arg)
	end
	UI.Refresh(true)
	return true
end

function UI.IsShown() return ui.win ~= nil and ui.win:IsShown() end

---------------------------------------------------------------------------
-- Start-up and events
---------------------------------------------------------------------------

W.Listen("DRIVERS", function() UI.Refresh() end)
W.Listen("RIDE", function()
	W.Safe("ride toast", onRide)
	UI.Refresh(true)
end)
W.Listen("SETTINGS", function()
	if ui.minimap and W.db then
		setShown(ui.minimap, not W.db.minimapHidden)
		placeMinimap(ui.minimap)
	end
	if ui.win and ui.win:IsShown() then applyScale() end
end)

W.On("PLAYER_REGEN_DISABLED", function()
	-- the last moment secure buttons may still be changed: put them away
	hideOverlays()
	if W.AfterCombat then W.AfterCombat(function() UI.Refresh(true) end) end
	UI.Refresh(true)
end)
W.On("PLAYER_REGEN_ENABLED", function() UI.Refresh(true) end)
W.Listen("NETWORK", function() UI.Refresh() end)
W.Listen("PROVIDER", function() UI.Refresh() end)
-- the splash ends at any click
W.On("GLOBAL_MOUSE_DOWN", function()
	if ui.splashing then UI.EndSplash() end
end)

W.On("GROUP_ROSTER_UPDATE", function() UI.Refresh() end)
W.On("ZONE_CHANGED_NEW_AREA", function()
	local home = screens.home
	if home and home.map then home.map.artFor = nil end
	UI.Refresh()
end)

W.OnLogin(function()
	buildSecure()
	buildWindow()
	buildMinimap()
	if W.Every then
		W.Every(10, function() W.Safe("minimap", refreshMinimap) end)
	end
end)
