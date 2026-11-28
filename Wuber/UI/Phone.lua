-- Module: UI.Phone
-- Purpose: The splash and the handset round the window (bezel, island, status bar: UI.SignalBars,
--   UI.UpdateStatusBar; the 3-slice screen background and the fold button UI.Fold paints).
-- API: UI.EndSplash, UI.SignalBars, UI.UpdateStatusBar (the island grows into the live pill while a ride runs:
--   Mod.pillWords gives its two parts, Mod.openRide is its click)
-- Internals: buildPhone, buildSplash, startSplash
-- Uses: UI.Kit, UI.Secure, UI.Window
-- Later: UI.Fold (the fold button's click: UI.Fold.Toggle)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/ui/phone_test.lua
-- From: UI.lua 4523-4807 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Phone", { "UI.Kit", "UI.Secure", "UI.Window" })
local KitMod = W.Mod("UI.Kit")
local SecureMod = W.Mod("UI.Secure")
local WindowMod = W.Mod("UI.Window")
local BEZEL = KitMod.BEZEL
local HOME_H = KitMod.HOME_H
local ISLAND_H = KitMod.ISLAND_H
local ISLAND_W = KitMod.ISLAND_W
local N = KitMod.N
local S = KitMod.S
local STATUS_H = KitMod.STATUS_H
local WIN_W = KitMod.WIN_W
local call = KitMod.call
local now = KitMod.now
local onNetwork = KitMod.onNetwork
local rideActive = KitMod.rideActive
local rideView = KitMod.rideView
local safeScript = KitMod.safeScript
local setShown = KitMod.setShown
local threeSlice = KitMod.threeSlice
local ui = KitMod.ui
local hideOverlays = SecureMod.hideOverlays
local savePosition = WindowMod.savePosition
local screens = WindowMod.screens
local T = W.Theme
local A = T.Animate
local UI = W.UI

---------------------------------------------------------------------------
-- Building the window
---------------------------------------------------------------------------

-- (Design 2 B) the live pill's room: left of it the dot (9 + 6 + 6); at the right 12 (the lens hides while the pill
-- speaks, as in the mockup, so both parts fit beside the clock and the signal bars)
local PILL_LEFT, PILL_RIGHT, PILL_GAP, PILL_CLEAR = 19, 12, 8, 8

local function buildSplash(win)
	local sp = CreateFrame("Frame", nil, win)
	sp:SetAllPoints(win)
	sp:SetFrameLevel(win:GetFrameLevel() + 60)
	sp:EnableMouse(false) -- click-through: any click ends it (GLOBAL_MOUSE_DOWN)
	sp.bg = T.Tex(sp, "winbg", "BACKGROUND")
	sp.bg:SetAllPoints(sp)
	sp.bg:SetTexCoord(0, 504 / 512, 0, 840 / 1024) if type(T.RegisterBackdrop) == "function" then T.RegisterBackdrop(sp, { art = { sp.bg }, layer = "BACKGROUND", sub = 0 }) end
	sp.art = CreateFrame("Frame", nil, sp)
	sp.art:SetSize(250, 250)
	sp.art:SetPoint("CENTER", sp, "CENTER", 0, 30)
	local badge = T.Tex(sp.art, "badge", "ARTWORK")
	badge:SetAllPoints(sp.art)
	sp.caption = T.Text(sp, "sub", "muted", "CENTER", "medium")
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
	-- the page unfolds as the splash fades (SPEC7 2.1: always folded under the splash)
	if UI.Fold then W.Safe("fold", UI.Fold.Apply) end
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

---------------------------------------------------------------------------
-- The phone: a handset drawn round the window (bezel, Dynamic Island, status bar, home
-- indicator). WuberFrame stays the app's screen (360 x 600), so every screen, the secure
-- overlays and the tests keep their places; the phone's parts hang outside it.
---------------------------------------------------------------------------

-- Signal bars: 4 = on the channel and drivers heard, 3 = on the channel and Wuber messages
-- heard, 2 = on the channel and nothing heard yet, 0 = not on the network.
function UI.SignalBars()
	if not onNetwork() then return 0 end
	if #UI.Drivers() > 0 then return 4 end
	local net = type(W.net) == "table" and W.net or nil
	if net and (N(net.heard) or 0) > 0 then return 3 end
	return 2
end

local SIGNAL_TIP = {
	[0] = "Not on Wuber's network yet: it joins by itself in a moment.",
	[2] = "On Wuber's network. No drivers heard yet.",
	[3] = "On Wuber's network and hearing it. No drivers online right now.",
	[4] = "On Wuber's network with drivers online. Full bars.",
}

local function gameClock()
	local h, m = call(GetGameTime)
	h, m = N(h), N(m)
	if h and m then return ("%02d:%02d"):format(h % 24, m % 60) end
	local d = call(date, "%H:%M")
	return S(d) or ""
end

local function dragFrom(f)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	if not f.wuberTip then T.Tip(f, "Wuber", "Drag here to move the app.") end
	safeScript(f, "OnDragStart", function()
		ui.moving = true
		hideOverlays()
		ui.win:StartMoving() W.Fire("WINDOW_DRAG", true)
	end)
	safeScript(f, "OnDragStop", function()
		ui.win:StopMovingOrSizing()
		ui.moving = false W.Fire("WINDOW_DRAG", false)
		savePosition()
		if UI.Fold then W.Safe("fold", UI.Fold.Apply) end
		UI.SyncSecure()
	end)
end

local function sideKey(ph, side, y, len)
	local k = T.Tex(ph, "phonekey", "BACKGROUND", -6)
	k:SetSize(4, len)
	if side == "LEFT" then
		k:SetPoint("TOPRIGHT", ph, "TOPLEFT", 1.5, -y)
	else
		k:SetPoint("TOPLEFT", ph, "TOPRIGHT", -1.5, -y)
		k:SetTexCoord(1, 0, 0, 1)
	end
	return k
end

-- The fold button: shown on the pages that unfold, painted by UI.Fold (glyph, dimmed
-- when there's no room or in combat, its tip). Built left of the signal bars; (round 9, S16)
-- UI.Window then docks it in the app header, a round button left of Settings (b:Dock), so it is
-- plain to see folded and unfolded.
local FOLD_TIP = {
	small = "Not enough room to unfold. Make the game window wider or Wuber smaller (Settings > Window size).",
	combat = "After combat",
	-- at its default place the wide window would cover the chat box (UI.Fold)
	chat = "Kept narrow so it doesn't cover your chat box.",
}
local function foldButton(bar, right)
	local b = CreateFrame("Button", nil, bar)
	b:SetSize(22, 18)
	b:SetPoint("RIGHT", right, "LEFT", -6, 0)
	b:RegisterForClicks("LeftButtonUp")
	b.icon = T.Tex(b, "fold", "ARTWORK")
	b.icon:SetSize(16, 16)
	b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.icon:SetTexCoord(0, 0.5, 0, 1)
	b.icon:SetVertexColor(T.RGB("muted"))
	local function rest(self) return self.docked and "white" or "muted" end
	-- (round 9, S16) into the app header: round, a card circle like Settings and Close. (design 2, C) on the
	-- cog's level (over the pages), 8 left of it; UI.HeadLayout then places the header's buttons that show
	function b.Dock(self, top, gear)
		self:SetParent(top)
		self:SetFrameLevel(gear:GetFrameLevel())
		self:SetSize(26, 26)
		self:ClearAllPoints()
		self:SetPoint("RIGHT", gear, "LEFT", -8, 0)
		self.bg = self.bg or T.Circle(self, 26, "card", "BACKGROUND")
		self.bg:SetPoint("CENTER", self, "CENTER")
		self.icon:SetSize(16, 16)
		self.docked = true
		self.icon:SetVertexColor(T.RGB(rest(self)))
	end
	-- glyph: "unfold" (one tall rect and an arrow) while folded, "fold" (two rects) while unfolded
	function b.Paint(self, unfolded, why)
		self.unfolded, self.why = unfolded and true or false, why
		if unfolded then self.icon:SetTexCoord(0.5, 1, 0, 1) else self.icon:SetTexCoord(0, 0.5, 0, 1) end
		self:SetAlpha(why and 0.4 or 1)
		self.icon:SetVertexColor(T.RGB((self.hover and not why) and "accent" or rest(self)))
		T.RefreshTip(self)
	end
	safeScript(b, "OnEnter", function(self)
		self.hover = true
		if not self.why then self.icon:SetVertexColor(T.RGB("accent")) end
		if self.bg and not self.why then self.bg:SetVertexColor(T.RGB("hover")) end
	end)
	safeScript(b, "OnLeave", function(self)
		self.hover = nil
		self.icon:SetVertexColor(T.RGB(rest(self)))
		if self.bg then self.bg:SetVertexColor(T.RGB("card")) end
	end)
	T.Press(b, { fill = function(self) return self.bg end })
	safeScript(b, "OnClick", function()
		if UI.Fold and UI.Fold.Toggle then UI.Fold.Toggle() end
	end)
	T.Tip(b, function(self) return self.unfolded and "Fold" or "Unfold" end, function(self)
		if self.why then return FOLD_TIP[self.why] end
		return self.unfolded and "Back to the phone size: one page, 360 wide." or "Show this page wide, with the map or details beside it."
	end, "ANCHOR_BOTTOM")
	b:Hide()
	return b
end

local function buildPhone(win)
	local base = win:GetFrameLevel()
	-- the handset's outline, for anchoring: the screen plus status bar, home strip and bezel
	local ph = CreateFrame("Frame", nil, win)
	ph:SetPoint("TOPLEFT", win, "TOPLEFT", -BEZEL, STATUS_H + BEZEL)
	ph:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", BEZEL, -(HOME_H + BEZEL))
	ph:SetFrameLevel(base + 1)
	ph:EnableMouse(false)
	ui.phone = ph
	win:SetClampRectInsets(-BEZEL, BEZEL, STATUS_H + BEZEL, -(HOME_H + BEZEL))

	-- under everything (the window's own textures): a soft drop shadow and a faint violet glow
	win.shadow = T.NineSlice(win, "shadow", 40, 31 / 64, "BACKGROUND", -8, 22, ph)
	win.shadow:SetColor({ 0, 0, 0, 0.75 })
	for _, t in pairs(win.shadow.parts) do
		local p, rel, rp, x, y = t:GetPoint(1)
		if p and rel == ph then t:SetPoint(p, rel, rp, x, (y or 0) - 6) end
	end
	win.aura = T.NineSlice(win, "edge", 44, 0.4, "BACKGROUND", -7, 14, ph)
	win.aura:SetColor("accent", 0.22)
	-- the screen: the night gradient from the top of the status bar to the bottom of the home
	-- strip, its corners as round as the bezel's (nothing may show outside the handset)
	-- (three slices: a left cap, a middle that stretches and a right cap, so the window can
	-- unfold to WIDE_W without stretching the corners; folded it draws as the one texture did)
	win.slices = threeSlice(win.bg, win, T.MEDIA .. "screen", "BACKGROUND", -4, 504 / 512, 0, 898 / 1024, STATUS_H, -HOME_H)
	-- Home's bottom sheet carries on under the home indicator (shown with Home)
	local sheetEnd = CreateFrame("Frame", nil, win)
	sheetEnd:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 0, 90)
	sheetEnd:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, -HOME_H)
	ph.sheetEnd = T.NineSlice(win, "rounded", 43, 0.25, "BACKGROUND", -3, 0, sheetEnd)
	ph.sheetEnd:SetColor("panel")
	ph.sheetEnd:SetShown(false)

	-- the bezel: over the screen's corners (it rounds whatever is drawn under them)
	local bezel = CreateFrame("Frame", nil, win)
	bezel:SetAllPoints(ph)
	bezel:SetFrameLevel(base + 85)
	bezel:EnableMouse(false)
	ph.bezel = bezel
	ph.ring = T.NineSlice(bezel, "phone", 56, 112 / 256, "ARTWORK", 0)
	ph.ring.parts.M:Hide()
	ph.ring:SetColor({ 1, 1, 1, 1 })
	-- side keys: action button and volume on the left, power on the right
	ph.keys = {
		sideKey(ph, "LEFT", 112, 24), sideKey(ph, "LEFT", 158, 48), sideKey(ph, "LEFT", 214, 48),
		sideKey(ph, "RIGHT", 172, 76),
	}

	-- status bar: the time, the Dynamic Island, signal and battery
	local bar = CreateFrame("Frame", nil, win)
	bar:SetPoint("BOTTOMLEFT", win, "TOPLEFT", 0, 0)
	bar:SetPoint("BOTTOMRIGHT", win, "TOPRIGHT", 0, 0)
	bar:SetHeight(STATUS_H)
	bar:SetFrameLevel(base + 86)
	dragFrom(bar)
	ph.status = bar
	local earW = (WIN_W - ISLAND_W) / 2
	local midY = -2
	ph.island = CreateFrame("Button", nil, bar)
	ph.island:SetSize(ISLAND_W, ISLAND_H)
	ph.island:SetPoint("CENTER", bar, "CENTER", 0, midY) -- (round 13, I19) the middle of the bar, folded or unfolded
	ph.island.fill = T.PillFill(ph.island, { 0, 0, 0, 1 }, ISLAND_H, "ARTWORK", 0)
	ph.island.lens = T.Circle(ph.island, 8, { 0.07, 0.06, 0.13, 1 }, "OVERLAY")
	ph.island.lens:SetPoint("RIGHT", ph.island, "RIGHT", -7, 0)
	ph.island.glint = T.Circle(ph.island, 3, { 0.36, 0.33, 0.62, 0.7 }, "OVERLAY")
	ph.island.glint:SetPoint("CENTER", ph.island.lens, "CENTER", -1, 1)
	-- a ride under way: a little violet light in the island (a live activity)
	ph.island.live = T.Circle(ph.island, 6, "glow", "OVERLAY")
	ph.island.live:SetPoint("LEFT", ph.island, "LEFT", 9, 0)
	ph.island.live:Hide()
	-- (Design 2 B) the live pill: while a ride runs it grows and says the state (violet) and the step or price (gold)
	ph.island.words = CreateFrame("Frame", nil, ph.island)
	ph.island.words:SetAllPoints(ph.island)
	ph.island.state = T.Text(ph.island.words, "caption", "accent", "LEFT", "medium")
	ph.island.state:SetPoint("LEFT", ph.island, "LEFT", PILL_LEFT, 0)
	ph.island.step = T.Text(ph.island.words, "caption", "gold", "RIGHT", "medium")
	ph.island.step:SetPoint("RIGHT", ph.island, "RIGHT", -PILL_RIGHT, 0)
	ph.island.words:SetAlpha(0)
	ph.island.words:Hide()
	dragFrom(ph.island) -- a drag on the pill still moves the window
	T.Tip(ph.island, "Your ride", "Click to open your ride.", "ANCHOR_BOTTOM")
	ph.island:RegisterForClicks("LeftButtonUp")
	safeScript(ph.island, "OnClick", function() Mod.openRide() end)
	ph.island:EnableMouse(false) -- at rest it takes no mouse
	-- (#20) a fold or unfold changes the window's width, so the bar's: the live pill is fitted at once, not at the next 1 s refresh
	win:HookScript("OnSizeChanged", function() if Mod.fitPill then Mod.fitPill(ph) end end)
	ph.clock = T.Text(bar, "body", "white", "CENTER", "bold")
	ph.clock:SetPoint("CENTER", bar, "LEFT", earW / 2 - 4, midY) -- (design 2) 10 further out, as the mockup: room for the live pill
	ph.clock:SetText(gameClock())
	-- the right ear: signal bars and battery, centred together
	local right = CreateFrame("Frame", nil, bar)
	right:SetSize(50, 14)
	right:SetPoint("CENTER", bar, "RIGHT", -(earW / 2 - 6), midY)
	ph.signal = CreateFrame("Frame", nil, right)
	ph.signal:SetSize(20, 12)
	ph.signal:SetPoint("LEFT", right, "LEFT", 0, 0)
	ph.signal:EnableMouse(true)
	ph.signal.dim = T.Tex(ph.signal, "signal", "ARTWORK")
	ph.signal.dim:SetAllPoints(ph.signal)
	ph.signal.dim:SetVertexColor(1, 1, 1, 0.28)
	ph.signal.lit = T.Tex(ph.signal, "signal", "OVERLAY")
	ph.signal.lit:SetPoint("TOPLEFT", ph.signal, "TOPLEFT", 0, 0)
	ph.signal.lit:SetPoint("BOTTOMLEFT", ph.signal, "BOTTOMLEFT", 0, 0)
	ph.signal.lit:SetVertexColor(T.RGB("white"))
	T.Tip(ph.signal, "Network", function()
		return (SIGNAL_TIP[UI.SignalBars()] or SIGNAL_TIP[0]) .. "\nFew drivers? Tap to see how Wuber finds them"
	end, "ANCHOR_BOTTOM")
	safeScript(ph.signal, "OnMouseUp", function()
		if type(UI.OpenHelp) == "function" then UI.OpenHelp("status") end
	end)
	T.Press(ph.signal)
	ph.battery = T.Tex(right, "battery", "ARTWORK")
	ph.battery:SetSize(26, 13)
	ph.battery:SetPoint("LEFT", ph.signal, "RIGHT", 5, 0)
	ph.battery:SetVertexColor(1, 1, 1, 0.5)
	ph.charge = T.Tex(right, "battery_fill", "OVERLAY")
	ph.charge:SetPoint("TOPLEFT", ph.battery, "TOPLEFT", 0, 0)
	ph.charge:SetPoint("BOTTOMLEFT", ph.battery, "BOTTOMLEFT", 0, 0)
	ph.charge:SetWidth(26 * 0.72)
	ph.charge:SetTexCoord(0, 0.72, 0, 1)
	ph.charge:SetVertexColor(T.RGB("white"))
	ph.fold = foldButton(bar, right)

	-- the home indicator: closes the app
	local home = CreateFrame("Button", nil, win)
	home:SetSize(150, HOME_H + 4)
	home:SetPoint("TOP", win, "BOTTOM", 0, 2)
	home:SetFrameLevel(base + 86)
	home:RegisterForClicks("LeftButtonUp")
	home.bar = CreateFrame("Frame", nil, home)
	home.bar:SetSize(124, 5)
	home.bar:SetPoint("CENTER", home, "CENTER", 0, -1)
	home.bar.fill = T.PillFill(home.bar, { 1, 1, 1, 0.78 }, 5, "ARTWORK", 0)
	local function homeRest()
		if T.activeTheme == T.DEFAULT_THEME then return { 1, 1, 1, 0.78 } end
		return "white", 0.55
	end
	local function homeHover()
		if T.activeTheme == T.DEFAULT_THEME then return { 1, 1, 1, 1 } end
		return "white", 0.9
	end
	safeScript(home, "OnEnter", function(self) self.bar.fill:SetColor(homeHover()) end)
	safeScript(home, "OnLeave", function(self) self.bar.fill:SetColor(homeRest()) end)
	T.Press(home, { fill = home.bar.fill })
	if type(T.OnTheme) == "function" then
		T.OnTheme(ph, function()
			if T.activeTheme == T.DEFAULT_THEME then
				ph.signal.dim:SetVertexColor(1, 1, 1, 0.28)
				ph.battery:SetVertexColor(1, 1, 1, 0.5)
			else
				ph.signal.dim:SetVertexColor(T.RGB("white", 0.28))
				ph.battery:SetVertexColor(T.RGB("white", 0.5))
			end
			home.bar.fill:SetColor(homeRest())
		end)
	end
	safeScript(home, "OnClick", function() UI.Toggle(false) end)
	T.Tip(home, "Close Wuber", "Swipe home: hides the app. Your ride carries on; the minimap button or /wuber opens it again.", "ANCHOR_BOTTOM")
	ph.home = home

	-- the bezel itself is a drag handle (left, right, bottom; the status bar covers the top)
	local function strip(p1, x1, y1, p2, x2, y2)
		local f = CreateFrame("Frame", nil, win)
		f:SetPoint(p1, ph, p1, x1, y1)
		f:SetPoint(p2, ph, p2, x2, y2)
		f:SetFrameLevel(base + 2)
		dragFrom(f)
		return f
	end
	ph.grips = {
		strip("TOPLEFT", 0, 0, "BOTTOMLEFT", BEZEL, 0),
		strip("TOPRIGHT", -BEZEL, 0, "BOTTOMRIGHT", 0, 0),
		strip("BOTTOMLEFT", 0, 0, "BOTTOMRIGHT", 0, BEZEL),
		strip("TOPLEFT", 0, 0, "TOPRIGHT", 0, -BEZEL),
	}
	return ph
end

-- (Design 2 B) What the live pill says for the ride: state (violet), step or price (gold, may be nil); nil at rest.
--   requesting -> Finding a driver | accepted -> Accepted | invited, ingroup -> Invited | summoning -> Summoning
--   portal (or summoning with the summon up) -> Portal open + "n of m" clickers (only when both are known)
--   clickers still missing (tapped < need, both known) -> Portal opening + "n of m" (the mockup's line)
--   arrived, paying -> Arrived + the price in letters (W.Money of what is to pay; nothing when unknown or free)
local PILL_STATE = {
	requesting = "Finding a driver", accepted = "Accepted", invited = "Invited", ingroup = "Invited",
	summoning = "Summoning", portal = "Portal open", arrived = "Arrived", paying = "Arrived",
}
function Mod.pillWords(rv)
	if not (rv and rideActive(rv)) then return nil end
	local state = PILL_STATE[rv.state]
	if not state then return nil end
	if rv.portalUp then state = "Portal open" end
	local step
	local g = type(rv.raw) == "table" and rv.raw.ritual
	local tapped, need = type(g) == "table" and N(g.tapped), type(g) == "table" and N(g.need)
	local counted = tapped and need and need >= 1
	if counted and tapped < need and (state == "Summoning" or state == "Portal open") then state = "Portal opening" end
	if state == "Portal open" or state == "Portal opening" then
		if counted then step = math.max(0, math.min(tapped, need)) .. " of " .. need end
	elseif state == "Arrived" then
		local due = type(UI.PayTotal) == "function" and N(UI.PayTotal(rv)) or N(rv.price)
		if due and due > 0 then step = W.Money(due) end
	end
	return state, step
end

-- A click on the pill: the ride, from any tab and from Settings.
function Mod.openRide()
	if not ui.win then return end
	if ui.settingsOpen and UI.CloseSettings then UI.CloseSettings(true) end
	local rv = rideView()
	if rv then ui.peek = nil end
	if ui.tab ~= "Ride" then UI.SelectTab("Ride") end
	UI.Refresh(true)
	UI.UpdateStatusBar() -- now on the ride: the pill takes no more clicks
end

local function reduced() return T.ReduceMotion and T.ReduceMotion() and true or false end

-- the pill's width for its words: as wide as they need (about 200 when there is room), within what the bar allows
local function pillWidth(ph, state, step)
	local isl = ph.island
	isl.state:SetText(state)
	isl.step:SetText(step or "")
	local need = PILL_LEFT + T.TextWidth(isl.state, state) + PILL_RIGHT
	if step then need = need + PILL_GAP + T.TextWidth(isl.step, step) end
	need = math.ceil(need) + 1
	local barW = N(ph.status:GetWidth()) or WIN_W
	local earW = (WIN_W - ISLAND_W) / 2
	local clockW = T.TextWidth(ph.clock, ph.clock.last or "") or 30
	local halfL = barW / 2 - (earW / 2 - 4 + clockW / 2) - PILL_CLEAR
	local halfR = (barW - (earW / 2 - 6) - 29) - barW / 2 - PILL_CLEAR
	local room = math.floor(2 * math.min(halfL, halfR))
	return math.max(ISLAND_W, math.min(math.max(need, 200), room)), need, room
end

local function setPillWidth(isl, w) isl:SetWidth(w) end

-- The pill takes a click only where the click shows something new: not while the ride's own screen is already up.
local function pillClickShows(rv)
	if not (rv and rideActive(rv)) then return false end
	return ui.tab ~= "Ride" or ui.settingsOpen == true or ui.peek == rv.id
end

local function updatePill(ph, rv)
	local isl = ph.island
	local state, step = Mod.pillWords(rv)
	if state then isl:EnableMouse(pillClickShows(rv)) end
	local sig = state and (state .. "|" .. (step or "")) or ""
	if state then
		local w, need, room = pillWidth(ph, state, step)
		if need > room and step then -- never cut: the room is too small for both parts, so the step goes and the state stays
			step = nil
			w = pillWidth(ph, state, nil)
		end
		sig = state .. "|" .. (step or "") .. "|" .. w
		if isl.sig == sig then return end
		isl.sig = sig
		isl.step:SetText(step or "")
		isl.lens:Hide()
		isl.glint:Hide()
		local grown = isl.grown
		isl.grown = true
		local function arrive()
			isl.words:Show()
			if reduced() then A.FadeIn(isl.words, 0.12) elseif not grown then A.FadeIn(isl.words, 0.2) else isl.words:SetAlpha(1) end
		end
		if not grown then isl.words:Hide() isl.words:SetAlpha(0) end
		if reduced() then
			isl:SetWidth(w)
			arrive()
		else
			T.Tween(isl, N(isl:GetWidth()) or ISLAND_W, w, function(f, v)
				setPillWidth(f, v)
				if v == w and f.sig == sig then arrive() end
			end)
		end
	else
		if isl.sig == "" then return end
		isl.sig = ""
		isl.grown = false
		isl:EnableMouse(false)
		isl.lens:Show()
		isl.glint:Show()
		isl.words:Hide()
		isl.words:SetAlpha(0)
		if reduced() then isl:SetWidth(ISLAND_W)
		else T.Tween(isl, N(isl:GetWidth()) or ISLAND_W, ISLAND_W, function(f, v) if not f.grown then setPillWidth(f, v) end end) end
	end
end

-- (#20) the bar changed width (a fold): a pill wider than the room is cut down to it at once, so it never rides over the clock
-- before the next refresh; then updatePill re-fits it the way the refresh would (a tween already running gets the new target, the
-- step goes when both parts no longer fit).
function Mod.fitPill(ph)
	local isl = ph.island
	if not (isl and isl.grown) then return end
	local state = isl.state:GetText()
	if not state or state == "" then return end
	local step = isl.step:GetText()
	if step == "" then step = nil end
	local _, _, room = pillWidth(ph, state, step)
	local cur = N(isl:GetWidth())
	if cur and room >= ISLAND_W and cur > room then isl:SetWidth(room) end
	updatePill(ph, rideView())
end

-- The status bar: the game time, the signal bars, the island's live light.
function UI.UpdateStatusBar()
	local ph = ui.phone
	if not ph then return end
	local t = gameClock()
	if ph.clock.last ~= t then
		ph.clock:SetText(t)
		ph.clock.last = t
	end
	local bars = UI.SignalBars()
	if ph.signal.bars ~= bars then
		ph.signal.bars = bars
		if bars <= 0 then
			ph.signal.lit:Hide()
		else
			ph.signal.lit:SetWidth(20 * bars / 4)
			ph.signal.lit:SetTexCoord(0, bars / 4, 0, 1)
			ph.signal.lit:Show()
		end
		T.RefreshTip(ph.signal)
	end
	local rv = rideView()
	setShown(ph.island.live, rideActive(rv) and true or false)
	updatePill(ph, rv)
	ph.sheetEnd:SetShown(ui.tab == "Ride" and ui.screen == "home" and not ui.settingsOpen)
end

-- internals other modules use (bound at load by later modules, or called late)
Mod.buildPhone = buildPhone
Mod.buildSplash = buildSplash
Mod.startSplash = startSplash
