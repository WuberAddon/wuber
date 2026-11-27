-- Module: UI.Window
-- Purpose: The app window: screens table, scale, raise, position, tabs (UI.AddTab/GetTab/SelectTab), screen
--   routing (wantedScreen, goTo), buildWindow, UI.Refresh/RefreshNow, UI.Toggle/Show/IsShown/SetSearch,
--   start-up listeners and the login build. the default place keeps the handset off the chat frame
--   and the action bars (UI.ClearOfHud, UI.Toasts, at run time); a saved place (W.db.pos) is never moved.
-- API: UI.WantedScale, UI.ApplyScale, UI.MigrateScale, UI.Raise, UI.AddTab, UI.GetTab, UI.SelectTab,
--   UI.HideOtherScreens, UI.Dismiss, UI.Refresh, UI.RefreshNow, UI.Toggle, UI.Show, UI.IsShown,
--   UI.SetSearch, UI.PlaceWindow, UI.PaintGear, UI.SyncClose, UI.HEAD_H, UI.TABBAR_H, UI.HEAD_ROW, UI.HeadRoom, UI.HeadPush,
--   UI.HeadControl, UI.HeadHit, UI.HeadLayout, UI.TabsHidden, UI.HeadAbove
-- Internals: savePosition, screens
-- (design 2, C) The screen from the top: a 56-high header ZONE (UI.HEAD_H) that draws nothing: an invisible strip
--   (ui.top) the window is dragged by, UNDER the pages, and at its right end the round buttons (fold, cog, x: 32
--   high, 8 apart, 16 from the edge), over the pages. The tab bodies start at the top of the screen and are 360 x 544;
--   under them the tab bar (ui.tabbar, UI.TABBAR_H = 56: Ride, Trips, Drive, a glyph over the word, the chosen one
--   violet). A page keeps its top row clear of the buttons:
--     UI.HeadRoom()        the width the buttons take over the primary pane now, from the window's right edge to the
--                          left edge of the leftmost button (0 while the window is wide: they are over the side pane)
--     UI.HeadRoom("side")  the same over the side pane (0 while folded)
--     UI.HeadRoom("most")  the most the primary pane ever has to leave (all three buttons): for a row laid out once
--     UI.HeadRoom("plain") the same for a page that never unfolds (the cog and the x; no fold button there)
--     UI.HeadRoom("x")     the same for a page that never unfolds and hides the cog (a ride under way: the x alone)
--     UI.HEAD_ROW (44)     where the buttons end, down from the top of the screen: a first row that cannot end
--                          before the buttons starts here or lower
--     UI.HeadPush(frame)   frame is a pushed page (a back chevron and a title in the header zone): while it is
--                          visible the cog is hidden (chevron, title, x). UI.HeadPush() looks again -> is any up
--     UI.HeadControl(frame) frame is a page control in the header zone (the Drive Sell / Raid switch): the drag strip leaves it free
--     UI.HeadHit()         sets where the drag strip's hit rect starts (right of the visible registered controls, and the back
--                          chevrons, drawn inside the window and not cut off; always HEAD.dragMin short of the round buttons)
--                          -> the inset; called by HeadPush, a control's show and hide, and when a page slide ends
--     UI.HeadLayout()      places the buttons that show, right to left (called when one shows or hides)
--     UI.HeadAbove(on[, who])     (r49, E1-07) true: the header's buttons (fold, cog, x, back) are lifted over a modal sheet's full-height
--                          dim (strata FULLSCREEN_DIALOG, level HEAD.above), so they are drawn whole and take the click;
--                          false: each goes back to the strata and level it had. T.Sheet (opts.head) calls it at run time.
-- (design 4, C) The tab bar hides while the rider's live ride is the page on screen (the Ride tab on the "found"
--   screen, Settings not over it): it drops by its height inside its own cut-off strip (ui.barClip) and fades in
--   0.28 s, and comes back the same way; with Reduce motion it only fades (0.12 s). While it is away the Ride tab's
--   body is the whole screen high (600), so the ride page's main button stands where the bar's foot was; on every
--   other page the body ends at the bar (544). UI.TabsHidden() -> is it away now. The bar is not secure and may hide
--   or show in a fight; the secure overlays belong to UIParent and are laid again when the bar has arrived.
-- Uses: UI.Kit, UI.Secure
-- Later: UI.Rider.Cards, UI.Rider.Home, UI.Rider.Confirm, UI.Rider.Ride, UI.Rider.Done, UI.Moments,
--   UI.Coach, UI.Phone, UI.Minimap, UI.Tips (NoteDriveAsked), UI.Fold (Page, Apply), UI.Share (Sync), UI.Rider.Wrapped (Shown)
-- (design 2, N) Pages slide: goTo pushes the new Ride screen in from the right when it goes deeper (A.Push) and pops
--   on the way back (A.PopPage), inside the Ride tab's body; a tab change swaps at once. A move ends at once
--   (A.StopPage) when a fight starts, the window hides or folds, a tab is chosen or UI.HideOtherScreens runs; the
--   secure overlays are laid when the move ends. UI.Show on a shut window opens it on the settled page.
-- Events: listens Listen DRIVERS, Listen FLIGHTS, Listen RIDE, Listen SETTINGS, Listen FOLD, Listen DRIVE_OFFER,
--   Listen DRIVE_CREW, Listen DRIVE_MODE, On PLAYER_REGEN_DISABLED,
--   On PLAYER_REGEN_ENABLED, Listen NETWORK, Listen PROVIDER, On GLOBAL_MOUSE_DOWN, On GROUP_ROSTER_UPDATE,
--   On ZONE_CHANGED_NEW_AREA, login; fires PAGE (the page key changed); reads UI.Moments'
--   pops through MomentsMod.popCount()
-- Standalone: no
-- Test: tests/ui/window_test.lua
-- From: UI.lua 908-1079, 4040-4121, 4808-4961, 5096-5294 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Window", { "UI.Kit", "UI.Secure" })
local KitMod = W.Mod("UI.Kit")
local SecureMod = W.Mod("UI.Secure")
local CardsMod = W.Mod("UI.Rider.Cards")
local HomeMod = W.Mod("UI.Rider.Home")
local ConfirmMod = W.Mod("UI.Rider.Confirm")
local RideMod = W.Mod("UI.Rider.Ride")
local DoneMod = W.Mod("UI.Rider.Done")
local MomentsMod = W.Mod("UI.Moments")
local CoachMod = W.Mod("UI.Coach")
local PhoneMod = W.Mod("UI.Phone")
local MinimapMod = W.Mod("UI.Minimap")
local ENDED = KitMod.ENDED
local N = KitMod.N
local PHONE_H = KitMod.PHONE_H
local PHONE_W = KitMod.PHONE_W
local REFRESH_GAP = KitMod.REFRESH_GAP
local S = KitMod.S
local TOP_H = KitMod.TOP_H
local HOME_H = KitMod.HOME_H
local WIN_H = KitMod.WIN_H
local WIN_W = KitMod.WIN_W
local call = KitMod.call
local clamp = KitMod.clamp
local now = KitMod.now
local rideActive = KitMod.rideActive
local rideView = KitMod.rideView
local safeScript = KitMod.safeScript
local setShown = KitMod.setShown
local ui = KitMod.ui
local buildSecure = SecureMod.buildSecure
local hideOverlays = SecureMod.hideOverlays
local T = W.Theme
local A = T.Animate
local Try = T.Try
local UI = W.UI

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local screens = {}
ui.screens = screens
local SCREEN_RANK = { home = 1, confirm = 2, finding = 3, found = 4, done = 5, sorry = 5 }

-- The scale the whole phone fits the screen at (a little room to spare).
local function fitScale()
	local h, w = N(UIParent:GetHeight()) or 0, N(UIParent:GetWidth()) or 0
	local s = 2
	if h > 0 then s = math.min(s, (h - 8) / PHONE_H) end
	if w > 0 then s = math.min(s, (w - 8) / PHONE_W) end
	return s
end

-- The window's scale: the saved one (the Window size slider), else the default (1.15),
-- either way no bigger than the screen holds.
local function wantedScale()
	local db = W.db or {}
	local s = N(db.scale)
	if s then return clamp(math.min(clamp(s, 0.4, 2), fitScale()), 0.4, 2) end
	return clamp(math.min(UI.DEFAULT_SCALE, fitScale()), 0.5, UI.DEFAULT_SCALE)
end
UI.WantedScale = wantedScale

local function applyScale()
	local win = ui.win
	if not win then return end
	-- (round 12, item 8) only a real change: opening, Settings and the Fold never call SetScale
	local s = wantedScale()
	if math.abs((N(win:GetScale()) or 0) - s) > 0.0001 then win:SetScale(s) end
	-- the Fold: does an unfolded window still fit at this size?
	if UI.Fold and win:IsShown() then W.Safe("fold", UI.Fold.Apply) end
end
UI.ApplyScale = applyScale

-- Round two saved 1.0 as "the usual size": that is now 1.15 (only once, only that value).
function UI.MigrateScale()
	local db = W.db
	if type(db) ~= "table" then return end
	if (N(db.scaleV) or 1) >= 2 then return end
	local s = N(db.scale)
	if s and math.abs(s - 1) < 0.001 then db.scale = UI.DEFAULT_SCALE end
	db.scaleV = 2
end

-- Above the world map while it is open (a map pin opens Confirm), or above the game's Options window while it
-- was opened from there (Options > AddOns > Wuber, ui.overOptions: until the window shuts), else the usual layer.
local function raise()
	local win = ui.win
	if not win then return end
	local map = type(WorldMapFrame) == "table" and WorldMapFrame or nil
	local over = map and type(map.IsShown) == "function" and W.Plain(call(map.IsShown, map)) == true
	local want = (over or ui.overOptions) and "FULLSCREEN_DIALOG" or "HIGH"
	if ui.strata ~= want then
		win:SetFrameStrata(want)
		ui.strata = want
	end
end
UI.Raise = raise

-- The default place: the middle of the screen, unless the handset would cover the
-- chat frame there (a narrow or square game window, or a UI pack moved the chat): then the
-- nearest place beside, under or over the chat. and clear of the action bars, micro
-- menu and party frames too (UI.ClearOfHud), with room to breathe; none clear: the place that
-- covers the least. In window units from the screen's centre. The player's own place (W.db.pos)
-- is never moved.
local function defaultOffset(win)
	local ue, we = N(UIParent:GetEffectiveScale()), N(win:GetEffectiveScale())
	local sw, sh = N(UIParent:GetWidth()), N(UIParent:GetHeight())
	local w, h = N(win:GetWidth()), N(win:GetHeight())
	local away = UI.ClearOfHud or UI.ClearOfChat
	if not (ue and we and sw and sh and w and h and type(away) == "function") or ue <= 0 or we <= 0 then return 0, 0 end
	local k = we / ue
	local ph = UI.PHONE or {}
	local bz = N(ph.bezel) or 0
	local pw = (w + 2 * bz) * k
	local up, down = (h / 2 + bz + (N(ph.status) or 0)) * k, (h / 2 + bz + (N(ph.home) or 0)) * k
	local l, b = sw / 2 - pw / 2, sh / 2 - down
	local nl, nb, moved = away(l, b, pw, up + down)
	if not moved then return 0, 0 end
	return (nl - l) / k, (nb - b) / k
end

local function placeWindow()
	local win = ui.win
	win:ClearAllPoints()
	local p = W.db and W.db.pos
	if type(p) == "table" and type(p[1]) == "string" and type(p[2]) == "string" and tonumber(p[3]) and tonumber(p[4]) then
		local ok = pcall(win.SetPoint, win, p[1], UIParent, p[2], tonumber(p[3]), tonumber(p[4]))
		if ok then return end
		win:ClearAllPoints()
	end
	local x, y = defaultOffset(win)
	win:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

-- Puts the window at its place now: the saved one, else the default (the middle,
-- clear of the chat frame). Out of combat only; false when it did nothing.
function UI.PlaceWindow()
	if not ui.win or W.InCombat() then return false end
	placeWindow()
	return true
end

-- (HUNT-01) saved by the window's top left, where it stands: the game re-anchors a dragged frame
-- by whichever point it likes (its centre, a side), and that point moves when the window is
-- narrower at the next open (it opens one pane wide and unfolds to the right), so a place saved
-- two panes wide by the centre came back half a pane to the right. The left edge and the top
-- are the same in every fold state. Places saved before are read as they were (placeWindow).
local function savePosition()
	local win = ui.win
	local l, t, uh = N(win:GetLeft()), N(win:GetTop()), N(UIParent:GetHeight())
	local ue, we = N(UIParent:GetEffectiveScale()), N(win:GetEffectiveScale())
	if l and t and uh and ue and we and ue > 0 and we > 0 and W.db then
		W.db.pos = { "TOPLEFT", "TOPLEFT", math.floor(l + 0.5), math.floor(t - uh * ue / we + 0.5) }
		return
	end
	local point, _, relPoint, x, y = win:GetPoint(1)
	point, relPoint, x, y = S(point), S(relPoint), N(x), N(y)
	if point and relPoint and x and y and W.db then
		W.db.pos = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) }
	end
end

-- PAGE: the page key (UI.Fold.Page) changed: the tab, the screen, the window shown.
-- UI.Fold unfolds or folds on it.
local function notePage()
	local F = UI.Fold
	local key = F and call(F.Page) or nil
	if key == ui.pageKey then return end
	ui.pageKey = key
	W.Fire("PAGE", key)
end

local TAB_TIPS = {
	Ride = "Find a Warlock and book a summon.",
	Trips = "Your rides, your rider level and the milestones you've earned.",
	Drive = "Sell summons: your driver console, crew, messages and earnings (Warlocks and their crews).",
}

-- (design 2, C) The header zone and the tab bar: sizes in one table.
local HEAD = { h = 56, bar = 56, btn = 32, gap = 8, edge = 16, foldW = 48, hitGap = 8, dragMin = 8, glyph = 22, level = 64, above = 700, splash = 70, row = 44, barTime = 0.28 }
UI.HEAD_H = HEAD.h
UI.TABBAR_H = HEAD.bar
UI.HEAD_ROW = HEAD.row
local TAB_GLYPH = { Ride = "ride", Trips = "clock", Drive = "wheel" }
local pushed = {}

local function headButtons()
	return { ui.close, ui.gear, ui.phone and ui.phone.fold }
end

-- The header buttons that show, right to left from 16 inside the window's right edge, 8 apart.
function UI.HeadLayout()
	local top = ui.top
	if not top then return end
	local x = -HEAD.edge
	for i = 1, 3 do
		local b = headButtons()[i]
		-- (the x keeps its place while it is hidden: Wrapped's own x stands there)
		if b and (b:IsShown() or i == 1) then
			b:ClearAllPoints()
			b:SetPoint("RIGHT", top, "RIGHT", x, 0)
			x = x - (N(b:GetWidth()) or HEAD.btn) - HEAD.gap
		end
	end
end

-- (r49, E1-07) lifts the header's buttons (fold, cog, x, and the back chevron of a pushed page) over a modal sheet's dim, or
-- puts them back (see the top of this file). Only while a sheet is up: a button left in that strata would also draw over the
-- game's own dialogs that lie over Wuber.
-- the round "back" chevrons of the pushed pages (UI.HeadPush's frames): Button children flagged wuberBackArrow (T.RoundButton with the "back" glyph), looked
-- for down to four levels (each page makes its own; none has a name to look up)
local function backButtons(list)
	local function walk(f, depth)
		if type(f) ~= "table" or type(f.GetChildren) ~= "function" then return end
		for _, c in ipairs({ f:GetChildren() }) do
			if type(c) == "table" and rawget(c, "wuberBackArrow") and type(c.SetFrameStrata) == "function" then
				list[#list + 1] = c
			elseif depth < 4 then
				walk(c, depth + 1)
			end
		end
	end
	for i = 1, #pushed do walk(pushed[i], 1) end
	return list
end

local headHolders = {} -- sheets that hold the lift now (UI.HeadAbove with a second argument)
function UI.HeadAbove(on, who)
	if who ~= nil then
		headHolders[who] = on and true or nil
		on = next(headHolders) ~= nil -- the buttons stay up while any holder is
	end
	local list = { ui.close or false, ui.gear or false, (ui.phone and ui.phone.fold) or false }
	backButtons(list)
	for _, b in ipairs(list) do
		if b and b.SetFrameStrata then
			if on and not b.wuberHeadWas then
				b.wuberHeadWas = { b:GetFrameStrata(), b:GetFrameLevel() }
				b:SetFrameStrata("FULLSCREEN_DIALOG")
				b:SetFrameLevel(HEAD.above)
			elseif not on and b.wuberHeadWas then
				local was = b.wuberHeadWas
				b.wuberHeadWas = nil
				-- the window's strata now (UI.Raise may have moved it while the sheet was up), not the one saved
				local now = ui.win and ui.win.GetFrameStrata and ui.win:GetFrameStrata() or was[1]
				b:SetFrameStrata(now or was[1])
				b:SetFrameLevel(was[2])
			end
		end
	end
end

-- The width the header buttons take at the right (see the top of this file).
function UI.HeadRoom(where)
	if not ui.win then return 0 end
	local wide = (N(ui.win:GetWidth()) or WIN_W) > WIN_W + 1
	if where == "side" then
		if not wide then return 0 end
	elseif where ~= "most" and where ~= "plain" and where ~= "x" and wide then
		return 0
	end
	local w, n = HEAD.edge, 0
	for i = 1, (where == "x" and 1 or where == "plain" and 2 or 3) do
		local b = headButtons()[i]
		if b and (where == "most" or where == "plain" or b:IsShown() or i == 1) then
			local bw = N(b:GetWidth()) or HEAD.btn
			if where == "most" and i == 3 then bw = math.max(bw, HEAD.foldW) end
			w = w + bw + (n > 0 and HEAD.gap or 0)
			n = n + 1
		end
	end
	return w
end

-- (#36) The drag strip (ui.top) lies in the same rank as the tab body that holds the pages: a page control in the header
-- zone (a back arrow, the Drive Sell / Raid switch) would lose the mouse to it (the strip wins at an equal level). So
-- the strip's hit rect starts to the right of the right-most VISIBLE registered header control (UI.HeadControl; the back
-- chevrons of the pushed pages count by themselves) plus HEAD.hitGap, and from the window's left edge when none shows.
-- One place: called by HeadPush (a page came or went) and by a registered control's show, hide and move.
local headControls = {}
-- true when a clipping ancestor of frame cuts the point (x, y) off (the game does not draw or hit it there)
local function cutOff(frame, x, y)
	local p = frame.GetParent and frame:GetParent()
	while p do
		if p.DoesClipChildren and p:DoesClipChildren() then
			local l, r, t, b = N(p:GetLeft()), N(p:GetRight()), N(p:GetTop()), N(p:GetBottom())
			if not (l and r and t and b) or x < l or x > r or y > t or y < b then return true end
		end
		p = p.GetParent and p:GetParent()
	end
	return false
end
function UI.HeadControl(frame)
	if type(frame) ~= "table" or type(frame.IsVisible) ~= "function" then return end
	for i = 1, #headControls do if headControls[i] == frame then return end end
	headControls[#headControls + 1] = frame
end
function UI.HeadHit()
	local top, win = ui.top, ui.win
	if not (top and win and top.SetHitRectInsets) then return 0 end
	local list = {}
	for i = 1, #headControls do list[#list + 1] = headControls[i] end
	backButtons(list)
	local wl, wt, wr, wb = N(win:GetLeft()), N(win:GetTop()), N(win:GetRight()), N(win:GetBottom())
	local inset = 0
	for _, c in ipairs(list) do
		if c.IsVisible and c:IsVisible() and wl and wt and wr and wb then
			local l, r, t, b = N(c:GetLeft()), N(c:GetRight()), N(c:GetTop()), N(c:GetBottom())
			if l and r and t and b then
				local cx, cy = (l + r) / 2, (t + b) / 2
				-- counts when it is drawn where it is: its middle is in the window's own rect (a page still sliding in
				-- stands far right), not cut off by a clipping ancestor, and in the header zone (a switch that fell to a
				-- row of its own is not)
				if cx >= wl and cx <= wr and cy <= wt and cy >= wb and cy > wt - HEAD.h and not cutOff(c, cx, cy) then
					inset = math.max(inset, r - wl + HEAD.hitGap)
				end
			end
		end
	end
	-- the strip keeps at least HEAD.dragMin to the left of the round buttons: it can always start a drag
	local room = math.max(UI.HeadRoom(), UI.HeadRoom("side"))
	inset = math.max(0, math.min(inset, (N(top:GetWidth()) or (wr - wl)) - room - HEAD.dragMin))
	if top.wuberHitLeft ~= inset then
		top.wuberHitLeft = inset
		top:SetHitRectInsets(inset, 0, 0, 0)
	end
	return inset
end

-- HeadPush(frame): frame is a pushed page (a back chevron and a title in the header zone): the cog hides while
-- it is visible (Settings and Help count by themselves: ui.settingsOpen). No argument: looks again (a pushed
-- page came or went) and says whether any is up.
function UI.HeadPush(frame)
	if type(frame) == "table" and type(frame.IsVisible) == "function" then pushed[#pushed + 1] = frame end
	local any = ui.settingsOpen == true
	if not any then
		for i = 1, #pushed do
			if pushed[i]:IsVisible() then any = true break end
		end
	end
	UI.HeadHit()
	local g = ui.gear
	if g and g:IsShown() == any then
		g:SetShown(not any)
		UI.HeadLayout()
	end
	return any
end

-- (design 2, C) the chosen tab has a violet glyph and a violet word, the others are grey; no pill. Only colours
-- change, never an alpha or a texture shown or hidden (in the game a texture keeps the alpha it had
-- when the tab changed while the window was shut), on every change and at open.
local function paintTab(b)
	local c = b.tabName == ui.tab and "accent" or ((b.hover or b.wuberPressed) and "white" or "offText")
	b.glyph:SetVertexColor(T.RGB(c))
	b.label:SetTextColor(T.RGB(c))
end

local function paintTabs()
	for _, tab in ipairs(ui.tabs) do paintTab(tab.button) end
end

local function tabShown(name)
	if name ~= "Drive" then return true end
	if call(W.Advanced) ~= false then return true end
	if call(W.IsWarlock) == true then return true end
	local DR = W.Drive
	if type(DR) == "table" then
		if type(DR.Role) == "function" then
			local role = call(DR.Role)
			if role and role ~= "none" then return true end
		end
		if type(DR.pendingOffers) == "table" and next(DR.pendingOffers) ~= nil then return true end
	end
	return false
end

local function tabButton(name)
	local b = CreateFrame("Button", nil, ui.tabbar)
	b:SetSize(WIN_W / 3, HEAD.bar)
	b:RegisterForClicks("LeftButtonUp")
	b.tabName = name
	b.glyph = T.Icon(b, TAB_GLYPH[name] or "circle", HEAD.glyph, "offText", "ARTWORK")
	b.glyph:SetPoint("TOP", b, "TOP", 0, -8)
	b.label = T.Text(b, "caption", "offText", "CENTER", "medium")
	b.label:SetPoint("BOTTOM", b, "BOTTOM", 0, 8)
	b.label:SetText(name)
	safeScript(b, "OnEnter", function(self) self.hover = true end)
	safeScript(b, "OnLeave", function(self) self.hover = nil end)
	-- the press look: the words and the glyph answer at once (T.Press plays the click)
	T.Press(b, { paint = function(self) paintTab(self) end })
	for _, ev in ipairs({ "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp" }) do
		b:HookScript(ev, function(self) pcall(paintTab, self) end)
	end
	safeScript(b, "OnClick", function(self)
		if ui.settingsOpen and UI.CloseSettings then W.Safe("settings", UI.CloseSettings, true) end
		W.Safe("tab", UI.SelectTab, self.tabName)
	end)
	T.Tip(b, name, TAB_TIPS[name] or ("Open the " .. name .. " tab."), "ANCHOR_TOP")
	setShown(b, tabShown(name))
	return b
end

-- each shown tab shares the folded width evenly, from the left: in the wide window the tabs
-- stay in the left pane
local function layoutTabs()
	local shown = {}
	for _, tab in ipairs(ui.tabs) do
		local show = tabShown(tab.name)
		setShown(tab.button, show)
		if show then shown[#shown + 1] = tab end
	end
	local w = WIN_W / math.max(1, #shown)
	for i, tab in ipairs(shown) do
		tab.button:ClearAllPoints()
		tab.button:SetPoint("BOTTOMLEFT", ui.tabbar, "BOTTOMLEFT", (i - 1) * w, 0)
		tab.button:SetWidth(w)
	end
	paintTabs()
end

local function syncTabs()
	if not ui.win then return end
	if ui.tab and not tabShown(ui.tab) then
		UI.SelectTab("Ride")
		return
	end
	layoutTabs()
end

---------------------------------------------------------------------------
-- (design 4, C) The tab bar hides during a ride
---------------------------------------------------------------------------

-- the bar at p of its way out: 0 in its place and solid, 1 a whole height down and gone (Reduce motion: it stays
-- in its place and only fades). The strip of its colour under the home indicator fades with it.
local function barAt(p)
	local bar = ui.tabbar
	ui.barP = p
	local y = T.ReduceMotion() and 0 or -HEAD.bar * p
	bar:ClearAllPoints()
	bar:SetPoint("BOTTOMLEFT", ui.barClip, "BOTTOMLEFT", 0, y)
	bar:SetPoint("BOTTOMRIGHT", ui.barClip, "BOTTOMRIGHT", 0, y)
	bar:SetAlpha(1 - p)
	if bar.under then bar.under:SetAlpha(1 - p) end
end

-- The bar is away while the live ride is the page on screen, and the Ride tab's body has its room then. still: no
-- travel (the window opens, or is shut).
local function syncBar(still)
	local bar = ui.tabbar
	if not (bar and ui.barClip) then return end
	local hide = ui.tab == "Ride" and ui.screen == "found" and not ui.settingsOpen
	if ui.barHidden == hide and not still then return end
	local changed = ui.barHidden ~= hide
	ui.barHidden = hide
	local body = UI.GetTab("Ride")
	if body then body:SetHeight(WIN_H - (hide and 0 or HEAD.bar)) end
	if changed then UI.NotifyBarSync(hide) end
	local from, to = ui.barP or 0, hide and 1 or 0
	if still or from == to or not (ui.win and ui.win:IsVisible()) then
		T.GlideStop(bar)
		barAt(to)
		setShown(bar, not hide)
		return
	end
	-- the page's lower controls move with the room: their secure overlays step aside until the bar has arrived
	hideOverlays()
	local secs = T.ReduceMotion() and T.MOTION.reduced or HEAD.barTime
	ui.animUntil = math.max(ui.animUntil or 0, now() + secs)
	bar:Show()
	T.Glide(bar, secs, function(_, k) barAt(from + (to - from) * k) end, function()
		if ui.barHidden then bar:Hide() end
		UI.SyncSecure()
	end, "OUT")
end

-- TabsHidden(): the tab bar is away (the live ride is the page on screen).
function UI.TabsHidden() return ui.barHidden == true end

-- TabBottom(): how far above the window's foot sheets and cards sit (0 when the tab bar is away).
function UI.TabBottom() return UI.TabsHidden() and 0 or (UI.TABBAR_H or 56) end

local barListeners = {}
function UI.OnBarSync(fn)
	if type(fn) == "function" then barListeners[#barListeners + 1] = fn end
end
function UI.NotifyBarSync(hide)
	for _, fn in ipairs(barListeners) do W.Safe("bar sync", fn, hide) end
end

-- (run 1, a) CoverTab(true): a page pushed over the tab (Settings, Help) is in place: the open tab's own page is
-- hidden, so none of it can draw over the pushed page (its frames may sit above the pushed page's level);
-- CoverTab(false): it shows again, before the pushed page leaves. Tab pages hold no secure button: safe in combat.
function UI.CoverTab(on)
	ui.tabCovered = on and true or nil
	for _, tab in ipairs(ui.tabs) do
		if tab.name == ui.tab then
			if on then
				tab.body:Hide()
			else
				tab.body:SetAlpha(1)
				tab.body:Show()
			end
		end
	end
end
--[[run1a-cut]]function UI.TabsHidden() return ui.barHidden == true end

local function addTabNow(name, buildFn)
	for _, tab in ipairs(ui.tabs) do
		if tab.name == name then return tab.body end
	end
	-- the primary pane: WIN_W wide even when the window unfolds
	local body = CreateFrame("Frame", nil, ui.win)
	-- (design 2, C) from the top of the screen down to the tab bar: as high as it always was
	body:SetPoint("TOPLEFT", ui.win, "TOPLEFT", 0, 0)
	body:SetSize(WIN_W, WIN_H - HEAD.bar)
	Try(body, "SetClipsChildren", true)
	body:Hide()
	local tab = { name = name, body = body, button = tabButton(name) }
	ui.tabs[#ui.tabs + 1] = tab
	if buildFn then W.Safe("tab " .. name, buildFn, body) end
	layoutTabs()
	return body
end

-- AddTab(name, buildFn): a tab in the window's tab bar (at the bottom). buildFn(body) runs once, when the
-- window is built (at login), under W.Safe; body is 360 x 544 from the top of the screen (the primary
-- pane: it stays 360 wide when the window unfolds) and is shown while its tab is selected.
-- Returns the body (nil until the window exists).
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
		if tab.name == name and tabShown(tab.name) then found = true end
	end
	if not found then return false end
	local old = ui.tab
	-- (r53 A) a click on the Ride tab while Ride is up leaves the driver's confirm page for Home (a ride in progress keeps its page)
	if old == name and name == "Ride" and ui.manual == "confirm" and not ui.settingsOpen then
		local rv = rideView()
		if not (rv and not ui.dismissed[rv.id]) then
			ui.manual = "home"
			ui.confirmKey = nil
		end
	end
	ui.tab = name
	if old ~= name then A.StopPage() end -- a page still on its way is put in its place first
	syncBar()
	for _, tab in ipairs(ui.tabs) do
		if tab.name == name then
			-- (design 2, N) a tab change swaps at once: nothing slides, nothing fades
			if old ~= name then
				A.Stop(tab.body)
				tab.body:SetAlpha(1)
			end
			-- (run 1, a) not while a pushed page (Settings, Help) covers the tab: UI.CoverTab shows it again
			if ui.tabCovered then tab.body:Hide() else tab.body:Show() end
		else
			tab.body:Hide()
		end
	end
	layoutTabs()
	ui.animUntil = now() + 0.2
	if UI.UpdateStatusBar then W.Safe("status bar", UI.UpdateStatusBar) end
	hideOverlays()
	notePage()
	UI.Refresh(true)
	return true
end

---------------------------------------------------------------------------
-- Which screen, and moving between screens
---------------------------------------------------------------------------

local function wantedScreen()
	local rv = rideView()
	-- a look at Home during a ride (UI.Show("home")), until the ride's next step
	if rv and ui.peek == rv.id and rideActive(rv) then return "home" end
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
	syncBar(instant)
	if old then
		if old.leaveScreen then W.Safe("screen", old.leaveScreen) end
		if instant then old.frame:Hide() end
	end
	local dir = (SCREEN_RANK[name] or 0) >= (SCREEN_RANK[oldName or ""] or 0) and 1 or -1
	if new.update then W.Safe("screen " .. name, new.update) end
	-- (design 2, N) going deeper the new page comes in from the right (A.Push); going back the page that returns
	-- comes in from the left (A.PopPage). The screens are siblings whose frames interleave, so only one is on
	-- screen during the move (opts.single): the other is hidden when it starts and no frame level is touched. The Ride tab's body is the frame that cuts both off (360 wide in the wide window too). A
	-- move still running jumps to its end first. Nothing travels at login, while the Ride tab is not on screen, or
	-- in combat (opts.secure: these pages hold the Request, Cancel and Share overlays): then the pages swap at once.
	local body = Try(new.frame, "GetParent")
	if instant or not old or not (body and body:IsVisible()) then
		A.StopPage(body)
		if old then old.frame:Hide() end
		new.frame:Show()
		new.frame:SetAlpha(1)
	else
		-- the overlays stay away for the travel (ui.animUntil, below) and are laid over their pills when it ends
		local opts = { clip = body, width = WIN_W, secure = true, single = true, onDone = function()
			if ui.animUntil > now() then ui.animUntil = now() end
			UI.SyncSecure()
		end }
		if dir > 0 then A.Push(new.frame, old.frame, opts) else A.PopPage(old.frame, new.frame, opts) end
	end
	if new.enter then W.Safe("screen " .. name, new.enter, arg) end
	if new.update then W.Safe("screen " .. name, new.update) end
	ui.animUntil = now() + 0.34
	if UI.UpdateStatusBar then W.Safe("status bar", UI.UpdateStatusBar) end
	notePage()
	W.After(0.36, function() UI.SyncSecure() end)
	-- a slide-out that never finished (the window was hidden or zooming) must not leave the old
	-- screen showing under the new one
	local serial = (ui.goSerial or 0) + 1
	ui.goSerial = serial
	W.After(0.45, function()
		-- (design 2, N) not for an older change: a newer page may be on its way
		if ui.goSerial == serial and UI.HideOtherScreens then W.Safe("screens", UI.HideOtherScreens) end
	end)
end

-- Hides every screen but the current one (and puts the current one fully in place).
function UI.HideOtherScreens()
	-- (design 2, N) a page still travelling is put in its place first
	local cur = ui.screen and screens[ui.screen]
	if cur and cur.frame then A.StopPage(Try(cur.frame, "GetParent")) end
	for n, sc in pairs(screens) do
		if sc and sc.frame then
			if n ~= ui.screen then
				if sc.frame:IsShown() then
					if A.Stop then pcall(A.Stop, sc.frame) end
					sc.frame:Hide()
				end
			else
				if not sc.frame:IsShown() then sc.frame:Show() end
				sc.frame:SetAlpha(1)
			end
		end
	end
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

-- Where the window grows from: the minimap button when it opened the window, else its centre.
local function zoomOffset(from)
	local win = ui.win
	if not (from and win) then return 0, 0 end
	local fx, fy = from:GetCenter()
	local wx, wy = win:GetCenter()
	local fe, we = N(from:GetEffectiveScale()), N(win:GetEffectiveScale())
	fx, fy, wx, wy = N(fx), N(fy), N(wx), N(wy)
	if not (fx and fy and wx and wy and fe and we) or we <= 0 then return 0, 0 end
	return (fx * fe - wx * we) / we, (fy * fe - wy * we) / we
end

local function maybeSimpleNote()
	local db = W.db
	if type(db) ~= "table" or db.simpleNote ~= true then return end
	if call(W.Advanced) ~= false then
		db.simpleNote = nil
		return
	end
	if KitMod.inCombat() then return end
	db.simpleNote = nil
	if type(UI.Toast) == "function" then
		UI.Toast("Wuber is simpler now. Everything else is in Settings: Advanced mode.", "info")
	end
end

local function buildWindow()
	if ui.win then return ui.win end
	local win = CreateFrame("Frame", "WuberFrame", UIParent)
	ui.win = win
	-- labels built while hidden (before the addon font was loaded) are redrawn the first times the
	-- window shows, then once more a moment later
	local refreshes = 0
	local function onShowRefresh()
		-- opening the app during a ride shows the ride, not a peek at Home
		local rv = rideView and rideView()
		if rv and ui.peek == rv.id then ui.peek = nil end
		W.After(0.5, function() if UI.HideOtherScreens then W.Safe("screens", UI.HideOtherScreens) end end)
		if refreshes >= 3 then return end
		refreshes = refreshes + 1
		pcall(T.RefreshText)
		W.After(0.5, function() pcall(T.RefreshText) end)
	end
	win:SetSize(WIN_W, WIN_H)
	win:SetFrameStrata("HIGH")
	Try(win, "SetToplevel", true)
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	win.wuberNoTip = true -- the app's own background: its parts have tips
	win:Hide()
	-- the night-sky background (gradient, rounded, edged) is one texture, plus a shadow
	win.bg = T.Tex(win, "winbg", "BACKGROUND", -4)
	win.bg:SetAllPoints(win)
	win.bg:SetTexCoord(0, 504 / 512, 0, 840 / 1024)
	-- the handset round it (shadow, bezel, status bar, home indicator)
	PhoneMod.buildPhone(win)
	if type(UISpecialFrames) == "table" and not W.GamepadUI() then -- (PST-01 B) the controller's menus would close it inside our code
		local there = false
		for _, n in ipairs(UISpecialFrames) do if n == "WuberFrame" then there = true end end
		if not there then table.insert(UISpecialFrames, "WuberFrame") end
	end

	-- (design 2, C) the top: no bar, no fill, no logo. An invisible strip is the handle the window is dragged by; it
	-- lies UNDER the pages (a page's own controls in the header zone take the mouse first), and the round buttons
	-- at its right end lie over them.
	local top = CreateFrame("Frame", nil, win)
	top:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
	top:SetHeight(HEAD.h)
	top:SetFrameLevel(win:GetFrameLevel() + 1)
	top:EnableMouse(true)
	top:RegisterForDrag("LeftButton")
	ui.top = top
	local close = T.RoundButton(top, "close", HEAD.btn, "card")
	close:SetFrameLevel(win:GetFrameLevel() + HEAD.level)
	close:SetPoint("RIGHT", top, "RIGHT", -HEAD.edge, 0)
	ui.close = close
	safeScript(close, "OnClick", function()
		-- (E1-01) Settings was opened over the game's Options ("Open Wuber settings") and is on screen: the X puts
		-- Settings away, back to the page it came from, like the back arrow. Wuber stays up and the game's Options is
		-- left as it is; the next press of the X (no Settings) hides Wuber as everywhere else.
		if ui.overOptions and ui.settingsOpen and UI.SettingsShown and UI.SettingsShown() and UI.CloseSettings then
			W.Safe("settings", UI.CloseSettings)
			return
		end
		UI.Toggle(false)
	end)
	T.Tip(close, "Close", "Hide Wuber. Your ride carries on; type /wuber to open it again.", "ANCHOR_BOTTOM")
	-- the tab bar: 56 high at the bottom of the screen, above the home strip; the sheet's flat colour, a line on top
	-- (design 4, C) it lives in a strip of its own size that cuts it off: on its way out (a ride) it drops out of
	-- sight there and never over the handset's foot
	local barClip = CreateFrame("Frame", nil, win)
	barClip:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 0, 0)
	barClip:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 0)
	barClip:SetHeight(HEAD.bar)
	barClip:SetFrameLevel(win:GetFrameLevel() + 30)
	Try(barClip, "SetClipsChildren", true)
	ui.barClip = barClip
	local bar = CreateFrame("Frame", nil, barClip)
	bar:SetPoint("BOTTOMLEFT", barClip, "BOTTOMLEFT", 0, 0)
	bar:SetPoint("BOTTOMRIGHT", barClip, "BOTTOMRIGHT", 0, 0)
	bar:SetHeight(HEAD.bar)
	bar:SetFrameLevel(win:GetFrameLevel() + 30)
	bar:EnableMouse(true)
	bar.wuberNoTip = true
	bar.fill = T.Line(bar, "panel", 1, "BACKGROUND")
	bar.fill:SetAllPoints(bar)
	bar.line = T.Line(bar, "line", 1, "BORDER")
	bar.line:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	bar.line:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
	bar.line:SetHeight(1)
	-- the same colour carries on under the home indicator, round at the handset's bottom corners (its own top
	-- corners are behind the bar)
	local under = CreateFrame("Frame", nil, win)
	under:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 0, HEAD.bar - 4)
	under:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, -HOME_H)
	bar.under = T.NineSlice(win, "rounded", 43, 0.25, "BACKGROUND", -2, 0, under)
	bar.under:SetColor("panel")
	ui.tabbar = bar
	-- Settings: everything that isn't riding or driving
	local gear = T.RoundButton(top, "gear", HEAD.btn, "card")
	gear:SetFrameLevel(win:GetFrameLevel() + HEAD.level)
	gear:SetPoint("RIGHT", close, "LEFT", -HEAD.gap, 0)
	safeScript(gear, "OnClick", function()
		-- (run 1, a) only a Settings page that is on screen is closed: a stale flag opens it
		if ui.settingsOpen and UI.SettingsShown and UI.SettingsShown() then
			if UI.CloseSettings then UI.CloseSettings() end
		elseif UI.OpenSettings then
			-- (round 13, I20) the driver footer's Settings is gone: from the Drive tab this opens Driving
			UI.OpenSettings(UI.state and UI.state.tab == "Drive" and "drive" or nil)
		end
	end)
	T.Tip(gear, "Settings", function()
		if UI.state and UI.state.tab == "Drive" then return "Every driving option, in plain words, and the rest of Wuber's settings." end
		return "Sounds, effects, the map, your time's worth, and a check of your game."
	end, "ANCHOR_BOTTOM")
	ui.gear = gear
	-- (design 1, K) the cog is never gold: white, and while Settings is open it wears the chosen look
	-- (the raised fill the open tab has), kept when the pointer leaves
	function UI.PaintGear(on)
		local g = ui.gear
		if not g then return end
		g.glyph:SetVertexColor(T.RGB("white"))
		g.chosen = on and true or false
		g.bg:SetVertexColor(T.RGB(g.chosen and "raised" or "card"))
		UI.HeadPush() -- (design 2, C) Settings is a pushed page: the cog steps aside while it shows
		syncBar() -- (design 4, C) Settings over the ride page: the tab bar is back under it
	end
	gear:HookScript("OnLeave", function(self)
		if self.chosen then self.bg:SetVertexColor(T.RGB("raised")) end
	end)
	-- (design 1, K) Wrapped has its own x: the window's x steps aside while it shows
	function UI.SyncClose()
		local c = ui.close
		if not c then return end
		local WrappedMod = W.Mod("UI.Rider.Wrapped")
		local up = type(WrappedMod) == "table" and type(WrappedMod.Shown) == "function" and WrappedMod.Shown() == true
		if c:IsShown() == up then
			c:SetShown(not up)
			UI.HeadLayout()
		end
	end
	-- (round 9, S16) the fold button sits in this header, left of Settings (UI.Phone builds it)
	local fb = ui.phone and ui.phone.fold
	if fb and fb.Dock then fb:Dock(top, gear) end
	UI.HeadLayout()
	safeScript(top, "OnDragStart", function()
		ui.moving = true
		hideOverlays()
		win:StartMoving()
		W.Fire("WINDOW_DRAG", true)
	end)
	safeScript(top, "OnDragStop", function()
		win:StopMovingOrSizing()
		ui.moving = false
		W.Fire("WINDOW_DRAG", false)
		savePosition()
		-- (AUD-186) a place the player chose may now be clear of the chat: the fold answers it at once
		if UI.Fold then W.Safe("fold", UI.Fold.Apply) end
		UI.SyncSecure()
	end)

	-- the tabs: Ride, Trips (UI_Trips.lua), then the ones other files add (Drive)
	local ride = addTabNow("Ride")
	screens.home = HomeMod.buildHome(ride)
	screens.confirm = ConfirmMod.buildConfirm(ride)
	screens.finding = ConfirmMod.buildFinding(ride)
	screens.found = RideMod.buildFound(ride)
	screens.done = DoneMod.buildDone(ride)
	screens.sorry = DoneMod.buildSorry(ride)
	ui.tab = "Ride"
	ride:Show()
	if type(UI.BuildTrips) == "function" then addTabNow("Trips", UI.BuildTrips) end
	for _, t in ipairs(ui.pendingTabs) do addTabNow(t.name, t.build) end
	ui.pendingTabs = {}
	layoutTabs()

	ui.splash = PhoneMod.buildSplash(win)
	ui.splash:SetFrameLevel(win:GetFrameLevel() + HEAD.splash) -- over the header's buttons too
	if type(UI.BuildSettings) == "function" then W.Safe("settings", UI.BuildSettings, win) end

	safeScript(win, "OnShow", function()
		-- (2.3.2 C1) the first-show text refresh used to be a HookScript, which this SetScript dropped
		pcall(onShowRefresh)
		pcall(syncTabs)
		pcall(paintTabs) -- the lit tab at open, whatever changed while shut
		ui.dirty = true
		UI.FlashMinimap(false)
		-- the Fold: this page's width at once (no tween while the window zooms in)
		if UI.Fold then W.Safe("fold", UI.Fold.Apply, true) end
		pcall(syncBar, true) -- (design 4, C) the tab bar in its settled place at open: nothing travels
		notePage()
		W.Safe("simpleNote", maybeSimpleNote)
	end)
	safeScript(win, "OnHide", function()
		A.StopPage() -- (design 2, N) no page is left half-way when the window goes
		if ui.splashing then UI.EndSplash() end
		if ui.coaching then CoachMod.stopCoachForNow() end
		if ui.settingsOpen and UI.CloseSettings then W.Safe("settings", UI.CloseSettings, true) end
		ui.overOptions = nil -- (run 1, a) the next open is on the usual layer
		local e = screens.home and screens.home.search and screens.home.search.edit
		if e then e:ClearFocus() end
		hideOverlays()
		if ui.moving then
			win:StopMovingOrSizing()
			ui.moving = false
			W.Fire("WINDOW_DRAG", false)
		end
		if UI.Fold then W.Safe("fold", UI.Fold.Apply, true) end
		if UI.RefreshMinimap then UI.RefreshMinimap() end -- (HUNT-46) the summon pulse comes back
	end)
	local tickAt = 0
	safeScript(win, "OnUpdate", function(_, elapsed)
		local t = now()
		if ui.tab == "Ride" then
			local scr = screens[ui.screen]
			if ui.screen == "home" then HomeMod.homeFrame(screens.home, elapsed) end
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
	W.Safe("minimap", MinimapMod.refreshMinimap)
	local win = ui.win
	if not (win and win:IsShown()) then return end
	raise()
	W.Safe("status bar", UI.UpdateStatusBar)
	W.Safe("close", UI.SyncClose)
	W.Safe("head", UI.HeadPush)
	local want = wantedScreen()

	if want ~= ui.screen then goTo(want) end
	syncBar()
	local scr = screens[ui.screen]
	if scr and scr.update and ui.tab == "Ride" and not ui.settingsOpen then W.Safe("screen " .. tostring(ui.screen), scr.update) end
	if ui.tab == "Trips" and not ui.settingsOpen and type(UI.UpdateTrips) == "function" then W.Safe("trips", UI.UpdateTrips) end
	if ui.settingsOpen and type(UI.UpdateSettings) == "function" then W.Safe("settings", UI.UpdateSettings) end
	if ui.coaching and (rideActive() or ui.tab ~= "Ride" or ui.screen ~= "home" or ui.settingsOpen) then CoachMod.stopCoachForNow() end
	if not ui.coaching then CoachMod.maybeCoach() end
	-- a page change no one announced (the splash or the coach ending, a sheet): PAGE now
	notePage()
	-- the share pills (flex, wrapped, cut): shown in a group, "Share after combat" in combat
	if UI.Share and UI.Share.Sync then W.Safe("share", UI.Share.Sync) end
	UI.SyncSecure()
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

-- The button the window zooms out of and back into (the minimap button, if it is showing).
local function zoomButton(from)
	if from == nil then from = ui.minimap end
	if from and type(from.IsVisible) == "function" and from:IsVisible() then return from end
	return nil
end

-- Toggle(show, from): true opens, false closes, nil flips. from: the frame the app zooms
-- out of (the minimap button when it was clicked); else it grows from its own centre.
function UI.Toggle(show, from)
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
		ui.animUntil = now() + 0.45
		local btn = from and zoomButton(from) or nil
		local x, y = zoomOffset(btn)
		A.ZoomIn(win, x, y, btn and 0.36 or 0.3, btn and 0.12 or 0.86)
		if not ui.splashed then PhoneMod.startSplash() end
		UI.RefreshNow()
		W.After(0.5, function() UI.SyncSecure() end)
	else
		if not win:IsShown() then return end
		-- (r53 A) a driver's confirm page with no request sent is not kept: the window reopens on Home
		if ui.manual == "confirm" then
			local rv = rideView()
			if not (rv and not ui.dismissed[rv.id]) then
				ui.manual = "home"
				ui.confirmKey = nil
			end
		end
		hideOverlays()
		W.Sound("close")
		ui.closing = true
		local btn = zoomButton(from)
		local x, y = zoomOffset(btn)
		A.ZoomOut(win, x, y, btn and 0.24 or 0.18, btn and 0.12 or 0.9, function() ui.closing = false end)
	end
end

-- Show(screen, arg): opens the window on a screen: "home", "confirm" (arg = driver key),
-- or the ride's own screens ("finding", "found", "done", "sorry"), which follow W.ride.
function UI.Show(screen, arg)
	screen = S(screen) or "home"
	local shut = not UI.IsShown() -- (design 2, N) a window that was shut opens on the settled page: nothing slides
	-- Settings ("/wuber help", "/wuber settings")
	local low = screen:lower()
	if low == "settings" or low == "options" or low == "help" then
		UI.Toggle(true)
		if ui.splashing then UI.EndSplash() end
		if not ui.settingsOpen and UI.OpenSettings then return UI.OpenSettings() end
		return ui.settingsOpen == true
	end
	-- a tab's name ("drive", "Drive") opens the window on that tab
	if low ~= "book" and not screens[screen] and screen ~= "confirm" then
		if not ui.win then buildWindow() end
		local target, hidden
		for _, tab in ipairs(ui.tabs) do
			if tab.name:lower() == screen:lower() then
				if tabShown(tab.name) then target = tab.name else hidden = true end
				break
			end
		end
		-- a tab Simple mode hides: nothing opens, nothing changes
		if hidden then return false end
		if ui.settingsOpen and UI.CloseSettings then UI.CloseSettings(true) end
		-- (HR-1) a shut window opened on Drive by the player's own ask: the login tip waits for the next open
		if target == "Drive" then
			local tips = W.Mod("UI.Tips")
			if type(tips) == "table" and type(tips.NoteDriveAsked) == "function" then call(tips.NoteDriveAsked) end
		end
		UI.Toggle(true)
		if not target then return false end -- (as before) a name Wuber does not know still opens the window
		return UI.SelectTab(target)
	end
	if ui.settingsOpen and UI.CloseSettings then UI.CloseSettings(true) end
	-- "book": drivers to a place (the map's "Ride here" and Ctrl-click), cheapest open first
	if low == "book" then
		UI.Toggle(true)
		if ui.tab ~= "Ride" then UI.SelectTab("Ride") end
		ui.manual = "home"
		ui.confirmKey = nil
		-- a finished ride's Done or Sorry screen still up: put it away, the place's drivers come first
		local rv0 = rideView()
		if rv0 and ENDED[rv0.state] and not ui.dismissed[rv0.id] then UI.Dismiss(true) end
		local place = S(arg)
		if type(arg) == "table" then place = S(arg.name) end
		UI.SetSearch(place or "")
		if wantedScreen() == "home" then goTo("home", nil, shut) end
		UI.Refresh(true)
		return true
	end
	UI.Toggle(true)
	if ui.tab ~= "Ride" then UI.SelectTab("Ride") end
	if screen == "confirm" then
		local key = S(arg)
		if key and W.Key then key = W.drivers and W.drivers[key] and key or W.Key(key) end
		-- a finished ride's Done or Sorry screen still up: put it away, the driver's card comes first
		local rv0 = rideView()
		if rv0 and ENDED[rv0.state] and not ui.dismissed[rv0.id] then UI.Dismiss(true) end
		ui.confirmKey = key
		ui.manual = "confirm"
		screens.confirm.last = nil
		if wantedScreen() == "confirm" then goTo("confirm", key, shut) end
	elseif screen == "home" then
		ui.manual = "home"
		ui.confirmKey = nil
		local rv = rideView()
		if rv and rideActive(rv) then ui.peek = rv.id end
		if wantedScreen() == "home" then goTo("home", nil, shut) end
	elseif screens[screen] then
		goTo(screen, arg, shut)
	end
	UI.Refresh(true)
	return true
end

function UI.IsShown() return ui.win ~= nil and ui.win:IsShown() end

-- SetSearch(text): fills Home's "Where to?" box and filters the drivers ("" clears it).
function UI.SetSearch(text)
	text = S(text) or ""
	local home = screens.home
	local e = home and home.search and home.search.edit
	if e then
		e:SetText(text)
		e:ClearFocus()
		home.search.Hint()
	end
	CardsMod.applySearch(text, true)
	return ui.filter
end

---------------------------------------------------------------------------
-- Start-up and events
---------------------------------------------------------------------------

W.Listen("DRIVERS", function() UI.Refresh() end)
W.Listen("FLIGHTS", function() UI.Refresh() end) -- a flight price came (own, shared or measured)
W.Listen("RIDE", function()
	W.Safe("ride toast", MomentsMod.onRide)
	UI.Refresh(true)
	if MomentsMod.popCount() > 0 then W.After(1.5, UI.ShowNextPop) end
end)
W.Listen("SETTINGS", function(key)
	if key == "advanced" then
		syncTabs()
		local db = W.db
		if type(db) == "table" and db.simpleNote == true and call(W.Advanced) ~= false then
			db.simpleNote = nil
		end
	end
	UI.Refresh(true)
	if ui.minimap and W.db then
		setShown(ui.minimap, not W.db.minimapHidden)
		MinimapMod.placeMinimap(ui.minimap)
	end
	if ui.win and ui.win:IsShown() then applyScale() end
end)
W.Listen("DRIVE_OFFER", syncTabs)
W.Listen("DRIVE_CREW", syncTabs)
W.Listen("DRIVE_MODE", syncTabs)

W.On("PLAYER_REGEN_DISABLED", function()
	-- (design 2, N) a page on its way is put in its place at once, before anything secure would have to change
	A.StopPage()
	-- the last moment secure buttons may still be changed: put them away
	hideOverlays()
	if W.AfterCombat then W.AfterCombat(function() UI.Refresh(true) end) end
	UI.Refresh(true)
end)
W.On("PLAYER_REGEN_ENABLED", function()
	UI.Refresh(true)
	W.After(1, UI.ShowNextPop)
end)
-- (design 2, N) the window folds or unfolds: a page on its way is put in its place first (FOLD also comes when
-- only the page changed in the unfolded window: that is the push itself and is left alone)
W.Listen("FOLD", function(unfolded)
	unfolded = unfolded and true or false
	if ui.foldWas == unfolded then return end
	ui.foldWas = unfolded
	A.StopPage()
end)
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
	W.Safe("scale", UI.MigrateScale)
	buildSecure()
	buildWindow()
	-- (round 12, item 8) the window has its size from login, not from its first open (the author's 4K
	-- test read 1.00 before the first open, then saw 1.15)
	if not KitMod.inCombat() then W.Safe("scale", applyScale) end
	MinimapMod.buildMinimap()
	if W.Every then
		W.Every(10, function() W.Safe("minimap", MinimapMod.refreshMinimap) end)
	end
end)

-- internals other modules use (bound at load by later modules, or called late)
Mod.savePosition = savePosition
Mod.screens = screens
