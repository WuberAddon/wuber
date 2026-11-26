-- Module: UI.Fold
-- Purpose: the Fold: the phone unfolds to a two-pane 720-wide window on pages that need room (page
--   key, wanted state per page, room check, width/translation/alpha tween, side pane, combat rules).
-- API: UI.Fold, UI.Fold.Register, UI.Fold.Page, UI.Fold.IsUnfolded, UI.Fold.Pane, UI.Fold.Fits,
--   UI.Fold.Toggle, UI.Fold.Apply, UI.Fold.Reset, UI.WindowWide
-- Internals: state (tests), PAGES, room
-- Uses: UI.Kit, UI.Secure, UI.Window
-- Later: UI.Phone (the fold button it builds: ui.phone.fold), UI.Driver.* (D.Mode, D.CurrentScreen,
--   D.SheetOpen), Drive (DR.Mode)
-- Events: listens Listen PAGE, Listen SETTINGS, On DISPLAY_SIZE_CHANGED, On UI_SCALE_CHANGED, On PLAYER_REGEN_DISABLED,
--   On PLAYER_REGEN_ENABLED; fires FOLD (unfolded, page) after every completed change
-- Standalone: no
-- Test: tests/ui/fold_test.lua
-- From: new in Wuber 2.3.0
--
-- The Fold. Folded, the window is today's 360-wide phone, pixel for pixel. Unfolded it
-- is 720 wide: the folded page stays in the left (primary) pane - every tab body is 360 wide -
-- and a second 360 x 544 side pane opens on its right. No crease: the panes are apart only by
-- their own padding.
--   UI.Fold.Register(page, { build = fn(holder), layout = fn(unfolded, holder) })
--     once per page, at login. build(holder) runs the first time the page unfolds (holder: the
--     page's own 360 x 544 frame in the side pane, shown only while it is the page). layout(
--     unfolded, holder) arranges the page for the state (idempotent; makes no frames after its
--     first call); it is called only when the page's state changes (unfolded at the start of an
--     unfold; folded at the end of a fold, or when the page is left while unfolded). A page
--     without a registration never unfolds. Pages keep a working folded layout: in combat the
--     width never changes, so a page may have to draw folded or unfolded either way.
--   UI.Fold.Page() -> "ride" | "confirm" | "trips" | "settings" | "console" | "raid" |
--     "earnings" | "messages" | "customers" | nil (the window's state only; customers: round 9)
--   UI.Fold.IsUnfolded() -> bool       UI.Fold.Pane() -> the side pane (nil before the window)
--   UI.Fold.Fits() -> bool, "small" | "chat" | "combat" | nil: room at the window's current scale
--     ((720 + 2 x bezel) x scale + 16 <= the screen's width) and not in combat; at the
--     window's default place (no W.db.pos) the wide phone must also stay off the chat frame (UI.ChatBox;
--     else "chat": kept narrow)
--   UI.Fold.Toggle(): the fold button; flips the current page's choice (W.db.fold.pages[page] =
--     "open" | "closed"), saves it and applies it. Does nothing without room or in combat.
--   UI.Fold.Apply(instant): recompute the wanted state and apply it (PAGE, size and scale
--     changes, combat end, the window shown or hidden -> instant)
--   UI.Fold.Reset(): Settings > Window "Reset fold choices" (clears W.db.fold.pages and the Always narrow choice)
--   UI.WindowWide(on): Settings > Window "Wide pages": true = Auto, false = Always narrow;
--     UI.WindowWide() -> the current choice (true = Auto)
-- Saved: W.db.fold = { v = 1, pages = { [page] = "open" | "closed" }, narrow = bool }, made only
-- when the player first chooses (every page's default is "open": it unfolds by itself).
-- Animation (H5): window width, the window's left offset and the side holder's offset and alpha
-- only; never a scale. One ticker frame runs the tween's OnUpdate, only while it plays.

local _, W = ...
local Mod = W.Module("UI.Fold", { "UI.Kit", "UI.Secure", "UI.Window" })
local KitMod = W.Mod("UI.Kit")
local SecureMod = W.Mod("UI.Secure")
local WindowMod = W.Mod("UI.Window")
local BEZEL = KitMod.BEZEL
local N = KitMod.N
local S = KitMod.S
local TOP_H = KitMod.TOP_H
local WIDE_W = KitMod.WIDE_W
local WIN_H = KitMod.WIN_H
local WIN_W = KitMod.WIN_W
local call = KitMod.call
local inCombat = KitMod.inCombat
local now = KitMod.now
local safeScript = KitMod.safeScript
local ui = KitMod.ui
local hideOverlays = SecureMod.hideOverlays
local savePosition = WindowMod.savePosition
local T = W.Theme
local A = T.Animate
local Try = T.Try
local UI = W.UI

local Fold = {}
UI.Fold = Fold

-- the eight pages that unfold
-- (round 9: + customers, the driver's Customers list, FIXROUND-2.3.0 item 3)
local PAGES = { ride = true, confirm = true, trips = true, settings = true, console = true, raid = true, earnings = true, messages = true,
	customers = true }
-- timings
local TW = {
	unfold = 0.30, widen = 0.28, sideAt = 0.08, side = 0.22, fromX = -40, -- unfold
	fold = 0.26, sideOut = 0.12, toX = -24, narrowAt = 0.04, narrow = 0.22, -- fold
	hold = 0.36, -- ui.animUntil: no secure overlay while the window changes width
	edge = 8, margin = 16, -- room kept at the screen's right edge; extra room the check asks for
	fade = 0.18, -- a page's side content when the page changes while unfolded
}

local st = {
	unfolded = false, -- the window is wide (or widening)
	page = nil,       -- the page the window was last laid out for
	regs = {},        -- [page] = { build, layout, holder }
	laid = {},        -- [page] = the state its layout was last called with
	pending = false,  -- a change wanted in combat, made when it ends
	tween = nil,      -- the playing tween (one at a time)
}

---------------------------------------------------------------------------
-- Saved choices
---------------------------------------------------------------------------

local function foldDb(make)
	local d = W.db
	if type(d) ~= "table" then return nil end
	local f = d.fold
	if type(f) ~= "table" then
		if not make then return nil end
		f = { v = 1, pages = {}, narrow = false }
		d.fold = f
	end
	if type(f.pages) ~= "table" then f.pages = {} end
	return f
end

local function savedNarrow()
	local f = foldDb()
	return f ~= nil and f.narrow == true
end

local function narrow()
	if call(W.Advanced) == false then return true end
	return savedNarrow()
end

-- the page's wanted state: Always narrow -> folded; else the button's last choice there; else
-- the page's default ("open" for all eight)
local function wanted(page)
	if not page or not st.regs[page] then return false end
	if narrow() then return false end
	local f = foldDb()
	return not (f and f.pages[page] == "closed")
end

---------------------------------------------------------------------------
-- The page, and the room
---------------------------------------------------------------------------

function Fold.Page()
	if not ui.win then return nil end
	-- the splash (and the first open, before it starts) and the coach marks: always folded
	if ui.splashing or ui.coaching or (ui.splash and not ui.splashed) then return nil end
	if ui.settingsOpen then return "settings" end
	local tab = ui.tab
	if tab == "Ride" then
		local scr = ui.screen
		if scr == "home" then return "ride" end
		if scr == "confirm" or scr == "finding" then return "confirm" end
		return nil
	end
	if tab == "Trips" then return "trips" end
	if tab ~= "Drive" then return nil end
	local D = W.Driver
	if type(D) ~= "table" then return nil end
	-- the console (not the welcome, the wizard or a provider's screen), no sheet over it
	if type(D.Mode) == "function" and call(D.Mode) ~= "console" then return nil end
	if type(D.SheetOpen) == "function" and call(D.SheetOpen) then return nil end
	local scr = type(D.CurrentScreen) == "function" and S(call(D.CurrentScreen)) or "console"
	if scr == "console" then
		local DR = W.Drive
		local mode = type(DR) == "table" and type(DR.Mode) == "function" and call(DR.Mode) or "sell"
		return mode == "raid" and "raid" or "console"
	end
	if scr == "earnings" or scr == "shift" then return "earnings" end
	if scr == "messages" then return "messages" end
	if scr == "customers" then return "customers" end
	return nil
end

-- the window's own scale against the screen's (the Window size slider, never changed here)
local function scaleOf(win)
	local ue = N(UIParent:GetEffectiveScale()) or 1
	local we = N(win:GetEffectiveScale()) or ue
	if ue <= 0 then return 1 end
	return we / ue
end

-- room for the wide phone at the window's current scale; false and why ("small",
-- "chat") when there is none
local function room()
	local win = ui.win
	if not win then return false, "small" end
	local sw = N(UIParent:GetWidth())
	if not sw then return false, "small" end
	if (WIDE_W + 2 * BEZEL) * scaleOf(win) + TW.margin > sw then return false, "small" end
	-- at its default place (none saved) the wide phone never covers the chat frame
	-- where it would stand (it widens to the right, sliding left at the screen's edge): a square
	-- game window keeps the narrow one, clear of the chat
	local c = W.db and W.db.pos == nil and type(UI.ChatBox) == "function" and UI.ChatBox()
	local l, t, b = N(win:GetLeft()), N(win:GetTop()), N(win:GetBottom())
	if not (c and l and t and b) then return true end
	local s, ph = scaleOf(win), UI.PHONE or {}
	local x = l - math.max(0, l + WIDE_W + BEZEL - (sw - TW.edge) / s)
	local x0, x1 = (x - BEZEL) * s, (x + WIDE_W + BEZEL) * s
	local y0, y1 = (b - BEZEL - (N(ph.home) or 0)) * s, (t + BEZEL + (N(ph.status) or 0)) * s
	if x0 < c[2] and x1 > c[1] and y0 < c[4] and y1 > c[3] then return false, "chat" end
	return true
end

function Fold.Fits()
	local fits, why = room()
	if not fits then return false, why or "small" end
	if inCombat() then return false, "combat" end
	return true, nil
end

function Fold.IsUnfolded() return st.unfolded == true end

---------------------------------------------------------------------------
-- The side pane and the pages' holders
---------------------------------------------------------------------------

local function pane()
	if st.pane then return st.pane end
	local win = ui.win
	if not win then return nil end
	local p = CreateFrame("Frame", nil, win)
	-- (design 2, C) from the top of the screen down to the tab bar, as the tab bodies
	p:SetPoint("TOPLEFT", win, "TOPLEFT", WIN_W, 0)
	p:SetSize(WIN_W, WIN_H - TOP_H)
	-- above the tab bodies and the settings panel (both reach under it once the window widens)
	p:SetFrameLevel(win:GetFrameLevel() + 45)
	Try(p, "SetClipsChildren", true)
	p:Hide()
	st.pane = p
	return p
end

function Fold.Pane() return pane() end

local function placeHolder(h, x, alpha)
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", st.pane, "TOPLEFT", x, 0)
	h:SetAlpha(alpha)
end

-- the page's holder in the side pane; its build runs the first time
local function holderFor(page)
	local r = page and st.regs[page]
	if not r then return nil end
	if r.holder then return r.holder end
	local p = pane()
	if not p then return nil end
	local h = CreateFrame("Frame", nil, p)
	h:SetSize(WIN_W, WIN_H - TOP_H)
	r.holder = h
	placeHolder(h, 0, 1)
	h:Hide()
	if r.build then W.Safe("fold build " .. page, r.build, h) end
	return h
end

-- the page's layout for the state, when it changed (pages never built keep their folded one)
local function layout(page, unfolded)
	local r = page and st.regs[page]
	if not (r and r.holder) then return end
	unfolded = unfolded and true or false
	if (st.laid[page] or false) == unfolded then return end
	st.laid[page] = unfolded
	if r.layout then W.Safe("fold layout " .. page, r.layout, unfolded, r.holder) end
end

local function hideHolders(except)
	for _, r in pairs(st.regs) do
		if r.holder and r.holder ~= except and r.holder:IsShown() then r.holder:Hide() end
	end
end

-- a page's layouts (called once per page, at login)
function Fold.Register(page, spec)
	page = S(page)
	if not (page and PAGES[page]) or type(spec) ~= "table" then return false end
	local r = st.regs[page] or {}
	r.build = type(spec.build) == "function" and spec.build or nil
	r.layout = type(spec.layout) == "function" and spec.layout or nil
	st.regs[page] = r
	-- the window may already be on this page
	if ui.win and ui.win:IsShown() then W.After(0.05, function() Fold.Apply() end) end
	return true
end

---------------------------------------------------------------------------
-- The fold button (UI.Phone builds it in the status bar; painted here)
---------------------------------------------------------------------------

-- (design 1, K) the fold button says what a click does: "Wide" while the window is narrow, "Narrow" while it is
-- wide. There is no room for the word beside the glyph at 360, so it sits under the glyph (caption 11)
-- inside the same button, a rounded rectangle (radius 14) 32 high; its width is that of the longer word, so it
-- never jumps. Built once, on the first paint (UI.Phone builds the plain round button).
local FOLD_WORDS = { wide = "Wide", narrow = "Narrow" }
local function dress(b)
	if b.word then return end
	b.word = T.Text(b, "caption", "white", "CENTER", "regular")
	local ww = 0
	for _, text in pairs(FOLD_WORDS) do
		b.word:SetText(text)
		local x = N(T.TextWidth(b.word, text)) or (#text * 6)
		if x > ww then ww = x end
	end
	local w = math.max(32, math.ceil(ww) + 8)
	b:SetSize(w, 32) -- (design 2, C) as high as the cog and the x beside it
	if b.bg then b.bg:Hide() end
	local fill = T.Rounded(b, "card", 14, "BACKGROUND", 0)
	fill.SetVertexColor = function(self, r, g, bl, a)
		for _, t in pairs(self.parts) do t:SetVertexColor(r, g, bl, a) end
	end
	b.bg = fill
	b.icon:SetSize(13, 13)
	b.icon:ClearAllPoints()
	b.icon:SetPoint("TOP", b, "TOP", 0, -3)
	b.word:ClearAllPoints()
	b.word:SetPoint("BOTTOM", b, "BOTTOM", 0, 3)
	b.word:SetWidth(w)
	if UI.HeadLayout then UI.HeadLayout() end
end

local function paint(page, combat)
	local b = ui.phone and ui.phone.fold
	if not b then return end
	if not (page and st.regs[page]) or narrow() then
		if b:IsShown() then
			b:Hide()
			if UI.HeadLayout then UI.HeadLayout() end
		end
		return
	end
	local ok, why = Fold.Fits()
	if ok then why = nil end
	if combat and why == nil then why = "combat" end
	local came = not b:IsShown()
	if came then b:Show() end
	if came and UI.HeadLayout then UI.HeadLayout() end
	if b.Paint then
		dress(b)
		b.word:SetText(st.unfolded and FOLD_WORDS.narrow or FOLD_WORDS.wide)
		b:Paint(st.unfolded, why)
	end
end

---------------------------------------------------------------------------
-- Width, place and the tween
---------------------------------------------------------------------------

local function ease(p) -- ease-out cubic
	if p <= 0 then return 0 elseif p >= 1 then return 1 end
	local q = 1 - p
	return 1 - q * q * q
end

local function part(e, at, dur)
	local p = (e - at) / dur
	if p < 0 then return 0 elseif p > 1 then return 1 end
	return p
end

-- Re-anchors the window by its TOPLEFT to the screen's, where it stands (it then widens to the
-- right and narrows from the right). Returns its x, y offsets.
local function anchorTopLeft(win)
	local l, t = N(win:GetLeft()), N(win:GetTop())
	local uh = N(UIParent:GetHeight())
	if not (l and t and uh) then return nil end
	local y = t - uh / scaleOf(win)
	win:ClearAllPoints()
	win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", l, y)
	return l, y
end

local function setLeft(win, x, y)
	win:ClearAllPoints()
	win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
end

-- how far left the wide window must slide to keep its right edge on the screen (window units)
local function overflow(win, x)
	local sw = N(UIParent:GetWidth())
	if not sw then return 0 end
	local s = scaleOf(win)
	local over = x + WIDE_W + BEZEL - (sw - TW.edge) / s
	return over > 0 and over or 0
end

local function ticker()
	if st.ticker then return st.ticker end
	st.ticker = CreateFrame("Frame", nil, UIParent)
	st.ticker:Hide()
	return st.ticker
end

local function stopTicker()
	local t = st.ticker
	if not t then return end
	t:SetScript("OnUpdate", nil)
	t:Hide()
end

-- ends the tween now, at its end state (an interrupted tween snaps)
local function endTween()
	local tw = st.tween
	if not tw then return end
	st.tween = nil
	stopTicker()
	tw.finish()
end

local function stepTween()
	local tw = st.tween
	if not tw then
		stopTicker()
		return
	end
	tw.step(now() - tw.t0)
	if now() - tw.t0 >= tw.total then endTween() end
end

local function playTween(tw)
	tw.t0 = now()
	st.tween = tw
	ui.animUntil = math.max(N(ui.animUntil) or 0, tw.t0 + TW.hold)
	tw.until_ = ui.animUntil
	local t = ticker()
	safeScript(t, "OnUpdate", stepTween)
	t:Show()
end

-- the overlays come back where their pills are now
local function settled(tw)
	if tw and ui.animUntil == tw.until_ then ui.animUntil = now() end
	UI.SyncSecure()
end

local function instantly(instant)
	return instant or T.FxLevel() == "off" or not (ui.win and ui.win:IsVisible())
end

local function unfold(page, instant)
	local win = ui.win
	local h = holderFor(page)
	if not h then return end
	hideOverlays()
	st.unfolded, st.page = true, page
	hideHolders(h)
	st.pane:Show()
	h:Show()
	layout(page, true)
	local x0, y0 = anchorTopLeft(win)
	local dx = x0 and overflow(win, x0) or 0
	local function finish(tw)
		win:SetWidth(WIDE_W)
		if dx > 0 then setLeft(win, x0 - dx, y0) end
		placeHolder(h, 0, 1)
		-- saved only when the window really moved (re-anchoring alone changes nothing on screen),
		-- and only a place the player chose: Wuber's default place (no W.db.pos)
		-- is worked out afresh each time, and saving it would make it count as the player's own
		-- (HUNT-144) the place before the slide and the one saved by it are kept, so folding can put the window back
		st.shift = nil
		if x0 and dx > 0 and W.db and W.db.pos ~= nil then
			local was = W.db.pos
			local copy = {}
			for i = 1, #was do copy[i] = was[i] end
			savePosition()
			local now2 = W.db.pos
			if type(now2) == "table" then
				local mine = {}
				for i = 1, #now2 do mine[i] = now2[i] end
				st.shift = { was = copy, saved = mine, left = x0, top = y0 }
			end
		end
		settled(tw)
		W.Fire("FOLD", true, page)
		paint(Fold.Page())
	end
	if instantly(instant) then return finish() end
	placeHolder(h, TW.fromX, 0)
	local tw = { total = TW.unfold }
	function tw.step(e)
		local k = ease(part(e, 0, TW.widen))
		win:SetWidth(WIN_W + (WIDE_W - WIN_W) * k)
		if dx > 0 then setLeft(win, x0 - dx * k, y0) end
		local q = ease(part(e, TW.sideAt, TW.side))
		placeHolder(h, TW.fromX * (1 - q), q)
	end
	tw.finish = function() finish(tw) end
	playTween(tw)
end

local function fold(page, instant)
	local win = ui.win
	local old = st.page
	local r = old and st.regs[old]
	local h = r and r.holder
	hideOverlays()
	st.unfolded, st.page = false, page
	-- the left edge never moves back: the window narrows from the right
	anchorTopLeft(win)
	-- (HUNT-144) the wide pane slid the window left and saved that place: folding back puts the saved place back as it was, unless the
	-- player has moved the window since (the saved place is no longer the one the slide made)
	local shift = st.shift
	st.shift = nil
	local function finish(tw)
		win:SetWidth(WIN_W)
		if shift and W.db and type(W.db.pos) == "table" then
			local same = true
			for i = 1, math.max(#shift.saved, #W.db.pos) do
				if shift.saved[i] ~= W.db.pos[i] then same = false end
			end
			if same then
				W.db.pos = shift.was -- (the window itself stays where it is: the left edge never moves back)
			end
		end
		hideHolders()
		if h then placeHolder(h, 0, 1) end
		if st.pane then st.pane:Hide() end
		layout(old, false)
		if page ~= old then layout(page, false) end
		settled(tw)
		W.Fire("FOLD", false, page)
		paint(Fold.Page())
	end
	if instantly(instant) or not h then return finish() end
	local tw = { total = TW.fold }
	function tw.step(e)
		local q = part(e, 0, TW.sideOut)
		placeHolder(h, TW.toX * q, 1 - q)
		win:SetWidth(WIDE_W - (WIDE_W - WIN_W) * ease(part(e, TW.narrowAt, TW.narrow)))
	end
	tw.finish = function() finish(tw) end
	playTween(tw)
end

-- unfolded, the page changed to another (or to none, in combat): its side content swaps
local function switchPage(page)
	local old = st.page
	st.page = page
	layout(old, false)
	local h = page and st.regs[page] and holderFor(page)
	hideHolders(h)
	if h then
		placeHolder(h, 0, 1)
		layout(page, true)
		A.FadeIn(h, TW.fade)
	end
	W.Fire("FOLD", true, page)
end

---------------------------------------------------------------------------
-- Applying the wanted state
---------------------------------------------------------------------------

function Fold.Apply(instant)
	local win = ui.win
	if not win then return end
	local page = Fold.Page()
	local shown = win:IsShown()
	-- room through the table (Fold.Fits; "combat" still means room: combat is handled below)
	local fits, why = Fold.Fits()
	local want = (shown and wanted(page) and (fits or why == "combat")) and true or false
	if inCombat() then
		-- never a width change in combat: made when combat ends
		if want ~= st.unfolded then st.pending = true end
		if st.unfolded and page ~= st.page then switchPage(page) end
		paint(page)
		return
	end
	st.pending = false
	if st.tween then endTween() end
	if not shown then instant = true end
	if want and st.unfolded then
		if page ~= st.page then switchPage(page) end
	elseif want then
		unfold(page, instant)
	elseif st.unfolded then
		fold(page, instant)
	else
		st.page = page
		layout(page, false)
	end
	paint(page)
end

-- the fold button: flip the current page's choice, save it, apply it
function Fold.Toggle()
	local page = Fold.Page()
	if not (page and st.regs[page]) or narrow() then return false end
	local ok = Fold.Fits()
	if not ok then
		paint(page)
		return false
	end
	local f = foldDb(true)
	f.pages[page] = st.unfolded and "closed" or "open"
	Fold.Apply()
	return true
end

-- Settings > Window "Reset fold choices"
function Fold.Reset()
	local f = foldDb()
	if f then f.pages = {}; f.narrow = false end -- the width choice goes back to Auto too
	Fold.Apply()
end

-- Settings > Window "Wide pages": on = Auto, off = Always narrow; no argument: the choice
function UI.WindowWide(on)
	if on == nil then return not savedNarrow() end
	on = on and true or false
	local f = foldDb(not on)
	if f then f.narrow = not on end
	Fold.Apply()
	return on
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

W.Listen("PAGE", function() Fold.Apply() end)
W.Listen("SETTINGS", function(key)
	if key == "advanced" then Fold.Apply() end
end)
-- the game window or the UI scale changed: is there still room?
W.On("DISPLAY_SIZE_CHANGED", function() Fold.Apply() end)
W.On("UI_SCALE_CHANGED", function() Fold.Apply() end)
-- the button dims in combat; a change wanted in combat is made a moment after it ends
-- (as combat starts, InCombatLockdown() still says no)
W.On("PLAYER_REGEN_DISABLED", function() paint(Fold.Page(), true) end)
W.On("PLAYER_REGEN_ENABLED", function()
	W.After(0.2, function() Fold.Apply() end)
end)

-- internals other modules use (bound at load by later modules, or called late)
Mod.PAGES = PAGES
Mod.room = room
Mod.state = st
