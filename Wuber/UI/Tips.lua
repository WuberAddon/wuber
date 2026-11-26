-- Module: UI.Tips
-- Purpose: Login tips: one short tip sheet inside the phone the first time Wuber opens after a login
--   (not after a /reload), the next unseen tip in order, each tip once, with Show me (the main button),
--   Next tip and Don't show again (a link). Texts and "Show me" targets live in UI.TipTexts.
-- API: Mod.SetOn, Mod.ShowNow, Mod.ShowAgain, Mod.IsOn, Mod.Hide, Mod.Card, Mod.Next, Mod.Eligible, Mod.Longest,
--   Mod.Layout, Mod.Spot, Mod.OFF_LINE, Mod.Why, Mod.NoteTabAsked, Mod.NoteDriveAsked
--   Card(): the frame WuberTipCard (the phone's primary pane, shown only while a tip is up). It holds .sheet (a T.Sheet:
--   the page behind dims, the card rises from the foot), .kicker ("Tip 4 of 14", a grey caption), .text, .show, .next,
--   .never, .close.
--   Why(): nil, or the line /wuber why prints for a hidden card ("Login tip: ..."); read-only.
--   ShowAgain(): this session's last tip again (else the next one), on Home; the Help row and /wuber tips call it.
--   Spot(frame, secs): a gold ring round a frame for about 3 s (Show me rings the tip's target).
-- Internals: tipList, usedDrive, pickNext, buildCard, showTip, maybeShow, goHome, hookWindow
-- Uses: UI.Kit
-- Later: UI.TipTexts (list, Show), UI.Window (UI.Toggle, UI.SelectTab, UI.Show, UI.CloseSettings), Drive (DR.Role)
-- Events: listens On PLAYER_ENTERING_WORLD, On PLAYER_REGEN_DISABLED, Listen PAGE, Listen RIDE, login; fires SETTINGS (tipsOn)
-- Standalone: no
-- Test: tests/r25_a_tips.lua
-- From: new in Wuber 2.3.3 (BRIEF25 T1)
--
-- When: the first open after a real login (PLAYER_ENTERING_WORLD's isReloadingUi; a client that
-- does not say is treated as a login, so at most once per session), and only when the first-open
-- coach marks were done before this login (W.db.coach). A login saves W.db.tipsPending until a tip
-- shows, so a /reload before the first open still gets it. Never in combat, never during a ride,
-- never while the coach marks show, only on Home in the Ride tab (the card sits at the bottom of
-- the primary pane; a sheet dims the page behind it, so Home does not give way to it).
-- The first open moves to Home for the tip when the phone opens on another tab (the Drive tab); a first
-- open on a Ride tab screen (a driver's booking screen from a map pin, a toast or Skip the bird) stays
-- there, and the tip waits for the next time Home shows.
-- The tip that points at the World view is skipped while the window cannot show it (Always narrow, or
-- no room for the wide phone). Turning tips back on arms the next open. Show me opens the tip's screen and rings its target.
-- A tip counts as seen when it shows, unless the game then closes it (combat, a ride): that tip comes back (gameHid).
-- The common rules for opening by itself are UI.MayOpen("tip") (UI.Kit). Rider tips are for everyone; driver tips (tip.driver) only
-- for Warlocks and players who have used Drive. Saved per account: W.db.tipsOn, W.db.tipsSeen
-- ({ [id] = true }). The sheet rises and the page dims; nothing holding text is Scale-animated.

local _, W = ...
local Mod = W.Module("UI.Tips", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local S = KitMod.S
local call = KitMod.call
local inCombat = KitMod.inCombat
local rideActive = KitMod.rideActive
local safeScript = KitMod.safeScript
local ui = KitMod.ui
local WIN_W = KitMod.WIN_W
local T = W.Theme
local function wrapH(n, size) return n * T.DrawnSize(size) + (n - 1) * T.Spacing(size) end -- n wrapped lines, spacing between them
local A = T.Animate
local Try = T.Try
local UI = W.UI

local L = {
	PAD = 16, TOP = 44, FOOT = 134, LINE_FOOT = 8, MAIN_Y = 88, NEXT_Y = 40, NEXT_H = 40,
	STAY_OFF = 8, STAY_DONE = 4,
	TEXT3 = 44, -- the text's height at three lines of "sub": 3 x 12 + 2 x 4 (Layout works it out from the font)
}
-- the sheet's height follows its text (a long tip makes it taller; the text is never cut). cardH is the height now.
local cardH = L.TOP + L.TEXT3 + 12 + L.FOOT
local OFF_LINE = "Tips are off. Turn them back on in Settings > Riding > Tips, or type /wuber tips."
local DONE_LINE = "That was the last tip. Type /wuber tips to see them again."
Mod.OFF_LINE = OFF_LINE
Mod.DONE_LINE = DONE_LINE

local st = { up = false, armed = false, seenWorld = false, hooked = false, current = nil, last = nil, closeAt = 0,
	fresh = false, hold = false, spot = 0 }
local card

local function db() return W.db end

-- UI.TipTexts loads after this file (group C's module): reached at run time only. The name is held in
-- a local so a branch without it still passes tools/check.lua; the table may be empty until it loads.
local function texts() return W.Mod("UI.TipTexts") end

function Mod.IsOn()
	local d = db()
	return type(d) == "table" and d.tipsOn ~= false
end

local function seenSet()
	local d = db()
	if type(d) ~= "table" then return {} end
	if type(d.tipsSeen) ~= "table" then d.tipsSeen = {} end
	return d.tipsSeen
end

-- the tip texts (UI.TipTexts, loaded later): a list of { id, text, driver, screen }
local function tipList()
	local t = texts()
	local list = type(t) == "table" and t.list
	if type(list) ~= "table" then return {} end
	return list
end

-- Warlocks, and players who have used Drive (on any character of this account)
local function usedDrive()
	if call(W.IsWarlock) == true then return true end
	local DR = W.Drive
	if type(DR) == "table" and type(DR.Role) == "function" then
		local role = call(DR.Role)
		if role == "driver" or role == "helper" then return true end
	end
	local d = db()
	if type(d) == "table" and type(d.chars) == "table" then
		for _, c in pairs(d.chars) do
			if type(c) == "table" and (c.wizard == true or c.runner == true or c.drive == true or c.raidRun == true
				or (type(c.crew) == "table" and #c.crew > 0) or (type(c.summoners) == "table" and #c.summoners > 0)
				or (type(c.captain) == "string" and c.captain ~= "")) then
				return true
			end
		end
	end
	return false
end
Mod.UsedDrive = usedDrive

-- false when this window cannot show the World view (Always narrow, or no room for the wide phone):
-- its tip waits. A fight is only for now, so it does not count.
local function worldFits()
	local UIm = W.UI
	if type(UIm) ~= "table" then return true end
	if type(UIm.WindowWide) == "function" and call(UIm.WindowWide) == false then return false end
	local Fold = UIm.Fold
	if type(Fold) == "table" and type(Fold.Fits) == "function" then
		local ok_, fits, why = pcall(Fold.Fits)
		if ok_ and fits == false and why ~= "combat" then return false end
	end
	return true
end

-- the tips this player gets, in order
function Mod.Eligible()
	local out, driver = {}, nil
	for _, tip in ipairs(tipList()) do
		if type(tip) == "table" and S(tip.id) and S(tip.text) then
			if tip.advanced and call(W.Advanced) == false then
				-- hidden in Simple mode
			elseif tip.screen == "world" and not worldFits() then
				-- skipped for now (a narrow window): it shows once the window can open the World view
			elseif tip.driver then
				if driver == nil then driver = usedDrive() end
				if driver then out[#out + 1] = tip end
			else
				out[#out + 1] = tip
			end
		end
	end
	return out
end

-- the next unseen tip (and its place in the list), or nil
local function pickNext()
	local seen = seenSet()
	local list = Mod.Eligible()
	for i, tip in ipairs(list) do
		if not seen[tip.id] then return tip, i, #list end
	end
	return nil, nil, #list
end
Mod.Next = pickNext

local function allSeen()
	local tip = pickNext()
	return tip == nil
end

-- the eligible tip with the longest text (the layout sweep shows it)
function Mod.Longest()
	local best
	for _, tip in ipairs(Mod.Eligible()) do
		if not best or #tip.text > #best.text then best = tip end
	end
	return best
end

---------------------------------------------------------------------------
-- The card
---------------------------------------------------------------------------

local function setButtons(c, shown)
	c.buttons = shown and true or false
	for _, b in ipairs({ c.show, c.next, c.never }) do
		if shown then b:Show() else b:Hide() end
	end
end

-- sizes and anchors for the sheet; returns its width and height
function Mod.Layout(c)
	c = c or card
	if not c then return nil end
	local textW = WIN_W - 2 * L.PAD
	-- the text's lines at its width (T.Para's measure), so the height is known in this frame
	local lines = T.ParaLines(S(c.text:GetText()) or "", "sub", "regular", textW)
	local texth = wrapH(lines, "sub") -- (design 3) n lines of the text's own size and spacing
	cardH = L.TOP + texth + 12 + (c.buttons == false and L.LINE_FOOT or L.FOOT)
	local sh = c.sheet
	sh:SetSheetHeight(cardH)
	local card_ = sh.card
	c.kicker:ClearAllPoints()
	c.kicker:SetPoint("TOPLEFT", card_, "TOPLEFT", L.PAD, -20)
	c.text:ClearAllPoints()
	c.text:SetPoint("TOPLEFT", card_, "TOPLEFT", L.PAD, -L.TOP)
	c.text:SetWidth(textW)
	c.show:ClearAllPoints()
	c.show:SetPoint("BOTTOMLEFT", card_, "BOTTOMLEFT", 16, L.MAIN_Y)
	c.show:SetPoint("BOTTOMRIGHT", card_, "BOTTOMRIGHT", -16, L.MAIN_Y)
	c.next:ClearAllPoints()
	c.next:SetPoint("BOTTOMLEFT", card_, "BOTTOMLEFT", 16, L.NEXT_Y)
	c.next:SetPoint("BOTTOMRIGHT", card_, "BOTTOMRIGHT", -16, L.NEXT_Y)
	return WIN_W, cardH
end

-- (Design 2) the page behind the sheet dims, so Home no longer gives way to the card: this only says whether a
-- tip is up (Home's old give-way is gone; Up() keeps its name)
local function reserve(on)
	st.up = on and true or false
end
-- true while a tip (or its off line) is up
function Mod.Up() return st.up == true end

-- UI.Show("drive") calls this just before it opens a shut window on the Drive tab (HR-1)
function Mod.NoteDriveAsked()
	st.driveAsked = not (ui.win and ui.win:IsShown())
end

-- the player picked a tab by a click on something else (the celebration card's tap to Trips): the first-open move
-- to Home is dropped; the tip comes at the next open
function Mod.NoteTabAsked()
	st.fresh = false
end
Mod.Reserve = reserve

-- over the phone's primary pane (WIN_W wide even when unfolded): the sheet's host
local function place(c)
	local win = ui.win
	if not (c and win) then return end
	c:ClearAllPoints()
	-- (design 2) the host is the page, from the top of the screen down to the tab bar: the sheet rests on the tab
	-- bar and the tabs stay free (a tip never locks the way to Trips or Drive)
	c:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
	c:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 0, UI.TabBottom())
	c:SetWidth(WIN_W)
	-- (run 1, item 2) the window's own strata, a level under Settings' panel (+40): never over its back chevron
	c:SetFrameStrata(ui.strata or "HIGH")
	c:SetFrameLevel(win:GetFrameLevel() + 20)
end

local function hideCard(fade)
	st.current, st.closeAt = nil, 0
	if not card then return end
	reserve(false)
	if fade and card:IsShown() and card.sheet.open then
		card.sheet:Close()
	else
		card.sheet:Close(true)
		card:Hide()
	end
end
function Mod.Hide() hideCard(false) end

local function buildCard()
	if card then return card end
	if not ui.win then return nil end
	local c = CreateFrame("Frame", "WuberTipCard", ui.win)
	c:SetFrameStrata(ui.strata or "HIGH")
	c:SetSize(WIN_W, 600)
	local sh = T.Sheet(c, cardH, "")
	c.sheet = sh
	local cd = sh.card
	cd.topPad = L.TOP
	cd.layFoot()
	-- (the words live on the sheet's body frame: the card's own regions would lie under its fill)
	c.kicker = T.Text(sh.body, "caption", "muted", "LEFT", "regular")
	c.text = T.Text(sh.body, "sub", "white", "LEFT", "regular")
	Try(c.text, "SetWordWrap", true)
	Try(c.text, "SetMaxLines", 0) -- the sheet grows for its text (Mod.Layout)
	Try(c.text, "SetJustifyV", "TOP")
	c.close = sh.close
	c.show = sh:MainButton("Show me", function() Mod.ShowMe() end, "Open the screen this tip is about.")
	c.never = sh:Link("Don't show again", function() Mod.Never() end,
		"Turn login tips off. Settings > Riding > Tips turns them back on.")
	c.next = T.Pill(cd, "Next tip", "dark", 200, L.NEXT_H)
	c.next:SetHeight(L.NEXT_H)
	T.Tip(c.next, "Next tip", "Show the next tip now.")
	sh.onClose = function() st.current, st.closeAt = nil, 0 reserve(false) end
	-- the sheet's own drop ends hidden: the frame that carries the name goes with it
	sh:HookScript("OnHide", function() c:Hide() end)
	safeScript(c, "OnShow", function() reserve(true) end)
	safeScript(c, "OnHide", function() reserve(false) end)
	safeScript(c.close, "OnClick", function() hideCard(true) end)
	safeScript(c.show, "OnClick", function() Mod.ShowMe() end)
	safeScript(c.next, "OnClick", function() Mod.NextTip() end)
	safeScript(c.never, "OnClick", function() Mod.Never() end)
	T.Tip(c.close, "Close", "Hide this tip. You won't see it again.")
	-- the off line and the last-tip line close by themselves
	safeScript(c, "OnUpdate", function()
		if st.closeAt > 0 and (tonumber(call(GetTime)) or 0) >= st.closeAt then hideCard(true) end
	end)
	c.buttons = true
	Mod.Layout(c)
	c:Hide()
	card = c
	UI.OnBarSync(function() if card and card:IsShown() then place(card) end end)
	return c
end
function Mod.Card() return card or buildCard() end

local function present(c)
	place(c)
	if not (c:IsShown() and c.sheet.open) then
		c.sheet:Open() -- (first: an Open ends a drop still running, which hides the frame that carries the name)
		c:Show()
	end
end

-- shows this tip on the card and marks it seen
local function showTip(tip, i, n)
	local c = buildCard()
	if not (c and tip) then return false end
	seenSet()[tip.id] = true
	local d = db()
	if type(d) == "table" then d.tipsPending = nil end
	st.current, st.last, st.closeAt = tip, tip, 0
	st.shown = true
	c.kicker:SetText(i and n and ("Tip " .. i .. " of " .. n) or "Tip")
	c.text:SetText(tip.text)
	setButtons(c, true)
	Mod.Layout(c)
	local tt = texts()
	c.show:SetActive(type(tt) == "table" and type(tt.Show) == "function")
	present(c)
	return true
end

-- a line on the card with no buttons (tips off, last tip), closing by itself
local function showLine(kicker, text, stay)
	local c = buildCard()
	if not c then return false end
	st.current = nil
	c.kicker:SetText(kicker)
	c.text:SetText(text)
	setButtons(c, false)
	Mod.Layout(c)
	present(c)
	st.closeAt = (tonumber(call(GetTime)) or 0) + stay
	return true
end

---------------------------------------------------------------------------
-- The buttons
---------------------------------------------------------------------------

-- a gold ring round a frame for about secs (3) seconds; alpha only, never takes the mouse
function Mod.Spot(target, secs)
	local win = ui.win
	if not (win and type(target) == "table" and type(target.IsVisible) == "function" and target:IsVisible()) then return false end
	local r = st.ring
	if not r then
		r = CreateFrame("Frame", nil, win)
		r:EnableMouse(false)
		r.edge = T.Outline(r, "glow", 2) -- (design 1) a flat thin outline, no glow
		r.ag = r:CreateAnimationGroup()
		r.ag:SetLooping("BOUNCE")
		local a = r.ag:CreateAnimation("Alpha")
		a:SetFromAlpha(1)
		a:SetToAlpha(0.35)
		a:SetDuration(0.5)
		st.ring = r
	end
	r:SetFrameStrata(ui.strata or "HIGH") -- (run 1, item 2) the window's strata, never FULLSCREEN_DIALOG
	r:ClearAllPoints()
	r:SetPoint("TOPLEFT", target, "TOPLEFT", -4, 4)
	r:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 4, -4)
	r:SetFrameLevel((tonumber(call(target.GetFrameLevel, target)) or 0) + 10)
	r:SetAlpha(1)
	r:Show()
	r.ag:Play()
	st.ringTarget = target
	st.spot = st.spot + 1
	local token = st.spot
	W.After(secs or 3, function()
		if st.spot ~= token then return end
		r.ag:Stop()
		A.FadeOut(r, 0.3)
	end)
	return true
end

local function unspot()
	st.spot = st.spot + 1
	if st.ring then st.ring.ag:Stop() st.ring:Hide() end
end

-- opens the tip's screen, then rings the thing it is about (once that screen has drawn)
function Mod.ShowMe()
	local tip = st.current
	hideCard(false)
	if not tip then return false end
	st.last = tip
	local t = texts()
	if type(t) ~= "table" or type(t.Show) ~= "function" then return false end
	local opened = call(t.Show, tip) == true
	if type(t.Target) == "function" then
		W.After(0.3, function() Mod.Spot(call(t.Target, tip)) end)
	end
	return opened
end

function Mod.NextTip()
	local tip, i, n = pickNext()
	if tip then return showTip(tip, i, n) end
	return showLine("TIPS", DONE_LINE, L.STAY_DONE)
end

function Mod.Never()
	Mod.SetOn(false)
	return showLine("TIPS OFF", OFF_LINE, L.STAY_OFF)
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

-- Turns login tips on or off. On, with every tip already seen: they start again from the first.
-- Off hides the card.
function Mod.SetOn(on)
	local d = db()
	if type(d) ~= "table" then return end
	on = on and true or false
	d.tipsOn = on
	if on then
		if allSeen() then d.tipsSeen = {} end
		-- the next open shows one (not this one, if the phone is open: Settings is in it)
		st.armed, d.tipsPending = true, true
		st.hold = ui.win and ui.win:IsShown() and true or false
	else
		d.tipsPending = nil
		st.armed = false
		hideCard(false)
	end
	W.Fire("SETTINGS", "tipsOn")
end

-- the window open with nothing on top (no splash, coach marks or Settings)
local function windowReady()
	local win = ui.win
	if not (win and win:IsShown()) then return false end
	return not (ui.splashing or ui.coaching or ui.settingsOpen)
end

-- where the card can show: the window open on Home in the Ride tab, nothing on top
local function homeReady()
	return windowReady() and ui.tab == "Ride" and ui.screen == "home"
end

-- the Ride tab's Home (ShowNow, and a first open on another tab)
local function goHome()
	if ui.settingsOpen and type(UI.CloseSettings) == "function" then call(UI.CloseSettings, true) end
	if ui.tab ~= "Ride" then call(UI.SelectTab, "Ride") end
	if ui.screen ~= "home" then call(UI.Show, "home") end
end

-- /wuber tips (and the layout sweep): the next unseen tip now, opening the phone on Home.
-- id: a given tip instead (the sweep shows Mod.Longest()). Returns true when the card shows,
-- else false and why ("ride", "combat", "coach", "none").
function Mod.ShowNow(id)
	if inCombat() then return false, "combat" end
	if rideActive() then return false, "ride" end
	if ui.coaching then return false, "coach" end
	local tip, i, n
	if id then
		for k, t in ipairs(Mod.Eligible()) do
			if t.id == id or t == id then tip, i, n = t, k, #Mod.Eligible() end
		end
	else
		tip, i, n = pickNext()
		if not tip and #Mod.Eligible() > 0 then
			db().tipsSeen = {} -- asked for by hand: from the first again
			tip, i, n = pickNext()
		end
	end
	if not tip then return false, "none" end
	st.armed = false
	st.hold = false
	if not (ui.win and ui.win:IsShown()) then call(UI.Toggle, true) end
	goHome()
	-- the first open's splash: the tip waits for it (PAGE)
	if ui.splashing or (ui.splash and not ui.splashed) then
		st.waiting = { tip = tip, i = i, n = n }
		return true
	end
	return showTip(tip, i, n)
end

-- the Help row and /wuber tips: this session's last tip again (Show me hid it), else the next one;
-- same guards and returns as ShowNow
function Mod.ShowAgain()
	local last = st.last
	if last then
		for _, t in ipairs(Mod.Eligible()) do
			if t.id == last.id then return Mod.ShowNow(t.id) end
		end
	end
	return Mod.ShowNow()
end

---------------------------------------------------------------------------
-- When
---------------------------------------------------------------------------

local function maybeShow()
	if st.waiting and homeReady() then
		local w = st.waiting
		st.waiting = nil
		showTip(w.tip, w.i, w.n)
		return
	end
	if card and card:IsShown() and not homeReady() then hideCard(false) end
	-- the first look after an open (the splash and coach marks done): the only time it moves screens
	-- (only the first open's own look: Settings up, or any later look, cancels the move)
	local first = st.fresh and windowReady()
	if first then st.fresh = false end
	if st.fresh and ui.settingsOpen then st.fresh = false end
	-- the splash on another tab may end without a PAGE: look again shortly
	if st.fresh and ui.splashing and ui.win and ui.win:IsShown() then W.After(0.5, maybeShow) end
	if not st.armed or st.hold or not Mod.IsOn() then return end
	local d = db()
	if not (type(d) == "table" and d.coach == true) then return end
	if rideActive() then return end
	-- the common rules for opening by itself (UI.MayOpen: combat, a cinematic, just logged in, another card or the
	-- guide up): the tip stays armed and looks again each second while the phone is open
	if not UI.MayOpen("tip") then
		-- (the first open's move to Home is kept for the retry: a gate that is only shut for now, like the seconds
		-- after login, must not use it up, or a first open on another tab never gets its tip)
		if first then st.fresh = true end
		if not st.retry and ui.win and ui.win:IsShown() then
			st.retry = true
			W.After(1, function() st.retry = false Mod.MaybeShow() end)
		end
		return
	end
	-- (from another tab only: a booking screen the player was sent to stays; the tip waits for Home)
	-- (HR-1) unless the player asked for Drive itself (/wuber drive, the minimap's Drive click): it stays on Drive
	-- and the tip comes at the next open
	local asked = st.driveAsked
	if first then st.driveAsked = false end
	if first and not homeReady() and ui.tab ~= "Ride" and not asked then goHome() end
	if not homeReady() then return end
	st.armed = false
	local tip, i, n = pickNext()
	if tip then showTip(tip, i, n) elseif type(d) == "table" then d.tipsPending = nil end
end
Mod.MaybeShow = maybeShow

-- /wuber why: nil while the card shows or nothing hides it, else one line naming the first rule that
-- keeps it hidden (maybeShow's rules, with OnLogin's two reasons for not being armed first). Read-only.
function Mod.Why()
	if card and card:IsShown() then return nil end
	if st.waiting then return nil end -- it shows once the splash has gone
	if not Mod.IsOn() then return "Login tip: off in Settings (Riding, Tips)." end
	local d = db()
	if not (type(d) == "table" and d.coach == true) then return "Login tip: waits until the first-open guide has run." end
	local list = Mod.Eligible()
	local seen = type(d.tipsSeen) == "table" and d.tipsSeen or {}
	local left = false
	for _, tip in ipairs(list) do
		if not seen[tip.id] then left = true break end
	end
	if #list > 0 and not left then return "Login tip: you have seen every tip." end
	if not st.armed and st.reloaded and not st.shown then
		return "Login tip: one shows when you log in, not again after a /reload. /wuber tips shows one now."
	end
	if not st.armed then return "Login tip: already shown this login. /wuber tips shows it again." end
	if st.hold then return "Login tip: shows the next time you open Wuber." end
	local okGate, gate = UI.MayOpen("tip")
	if gate == "combat" then return "Login tip: not in combat." end
	if gate == "cinematic" then return "Login tip: not during a cinematic." end
	if rideActive() then return "Login tip: not during a ride." end
	if not homeReady() then return "Login tip: it shows on the Ride tab's first screen." end
	if gate == "login" then return "Login tip: shows a few seconds after login." end
	if not okGate then return "Login tip: waits for the card or guide on screen to close." end
	return nil
end

local function hookWindow()
	local win = ui.win
	if st.hooked or not win or type(win.HookScript) ~= "function" then return end
	st.hooked = true
	win:HookScript("OnShow", function()
		st.fresh, st.hold = true, false
		W.After(0.8, maybeShow)
	end)
	win:HookScript("OnHide", function()
		st.waiting, st.fresh, st.driveAsked = nil, false, false
		unspot()
		if card and card:IsShown() then hideCard(false) end
	end)
	-- a tab button click cancels the first-open move to Home: the player just chose a tab
	for _, tab in ipairs(type(ui.tabs) == "table" and ui.tabs or {}) do
		local b = tab.button
		if b and type(b.HookScript) == "function" then
			b:HookScript("OnClick", function() st.fresh = false end)
		end
	end
end

W.OnLogin(function()
	-- the coach marks were done before this login (tips start from the next one)
	st.armed = type(W.db) == "table" and W.db.coach == true and W.db.tipsOn ~= false
	hookWindow()
end)

-- isReloadingUi true: a /reload, no tip (the first loading screen only; later ones are zone changes)
W.On("PLAYER_ENTERING_WORLD", function(_, isReloadingUi)
	if st.seenWorld then return end
	st.seenWorld = true
	local d = db()
	if type(d) ~= "table" then return end
	-- a /reload keeps a login's tip that never showed (tipsPending); a login saves it until one shows
	if W.Plain(isReloadingUi) == true then
		st.armed = st.armed and d.tipsPending == true
		st.reloaded = true -- (why: not armed because of the /reload)
	else
		d.tipsPending = st.armed or nil
	end
end)

-- the game closes it (combat starts, a ride begins): hidden, and NOT seen: the tip is unmarked and armed again, so
-- the same tip comes back when the rules allow. Only the player's own click (Show me, Next tip, the x, Don't show
-- again, closing the phone or leaving Home) leaves it seen.
local function gameHid()
	if not (card and card:IsShown()) then return end
	local tip = st.current
	hideCard(false)
	if not tip then return end
	seenSet()[tip.id] = nil
	st.armed = Mod.IsOn()
	local d = db()
	if type(d) == "table" and st.armed then d.tipsPending = true end
	W.After(1, function() Mod.MaybeShow() end)
end
Mod.gameHid = gameHid
W.On("PLAYER_REGEN_DISABLED", gameHid)
W.Listen("RIDE", function() if card and card:IsShown() and rideActive() then gameHid() end end)
-- the ring goes with its target: leaving the screen must not leave it floating over the next one
local function ringGone()
	local rt = st.ringTarget
	if st.ring and st.ring:IsShown() and not (rt and call(rt.IsVisible, rt)) then unspot() end
end
W.Listen("PAGE", function()
	ringGone()
	-- (run 1, item 2) Settings (or any page) up: the card goes at once, no fade and no 0.3 s over its back chevron
	if card and card:IsShown() and ui.settingsOpen then hideCard(false) end
	-- (again once the old screen has gone: a screen that is still shown at the moment of the switch)
	W.After(0.3, function() ringGone() maybeShow() end)
end)

Mod.state = st -- tests read it (armed, current)
