-- Module: UI.Driver.Mini
-- Purpose: Crew-offer card (UI.CrewOffer), the floating mini console, driver toasts and alerts,
--   UI.ShowDrive / DriveSlot / DriveSummary / DriveWantsClick. (BRIEF19 R6) the crew offer keeps off the
--   chat frame and (BRIEF20 B4) the action bars (UI.ClearOfHud, at run time). (round 31) the console shows the
--   rows its place has room for (DR.Button.MiniRows, at run time).
-- API: UI.CrewOffer, D.UpdateMini, UI.ShowDrive, UI.DriveSlot, UI.DriveSummary, UI.DriveWantsClick,
--   D.SyncMini, D.MiniTicking
-- Internals: (none)
-- Uses: UI.Driver.Screens
-- Later: (none)
-- Events: listens Listen DRIVE_ALERT, Listen DRIVE_BLOCKED, Listen DRIVE_OFFER, Listen DRIVE, Listen
--   DRIVE_PAID, Listen DRIVE_LOG, login, Listen DRIVE, On PLAYER_REGEN_ENABLED; fires -
-- Standalone: no
-- Test: tests/ui/driver/mini_test.lua
-- From: UI_Drive.lua 2669-3062 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Driver.Mini", { "UI.Driver.Screens" })
local ScreensMod = W.Mod("UI.Driver.Screens")
local call, dr, money, now = ScreensMod.call, ScreensMod.dr, ScreensMod.money, ScreensMod.now
local para, plural, safeScript, short = ScreensMod.para, ScreensMod.plural, ScreensMod.safeScript, ScreensMod.short
local st, toast = ScreensMod.st, ScreensMod.toast
local T = W.Theme
local A = T.Animate
local Try = T.Try
local UI = W.UI

local DR = W.Drive
local D = W.Driver

local K = D.kit or {}

local S, N = W.Str, W.Num

---------------------------------------------------------------------------
-- The crew offer (the invited side): one card, one tap
---------------------------------------------------------------------------

local offerCard
local OFFER_W, OFFER_H, OFFER_TOP = 330, 168, -120
-- (v2.4 fix 3, stage B) the card takes its height from its text: up to three lines of body use the
-- standard 168 (up to three lines of body, 49 px, as it always was); a fourth line and more make it
-- taller (the buttons hang from the bottom, so they move down), the text then clear of the buttons
local OFFER_TEXT_ROOM = 46 -- the body's height that fits above the buttons in 168 (three lines, 49, touch them by 3)

local function buildOffer()
	local f = CreateFrame("Frame", "WuberCrewOffer", UIParent)
	f:SetSize(OFFER_W, OFFER_H)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:EnableMouse(true)
	T.Tip(f, "Crew offer", "A Warlock asks you to help with their summons. Yes or No thanks: nothing changes without your tap.")
	f.under = CreateFrame("Frame", nil, f)
	f.under:SetAllPoints(f)
	f.glow = T.OuterGlow(f.under, "accent", 0.5, 18)
	f.card = T.Card(f, OFFER_W, OFFER_H, { colour = { 0.09, 0.08, 0.17, 0.98 }, radius = 20, border = "accent" })
	f.card:SetAllPoints(f)
	local host = f.card
	f.disc = T.Circle(host, 44, "accent", "ARTWORK")
	f.disc:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -18)
	f.icon = T.Icon(host, "summon", 24, "ink", "OVERLAY")
	f.icon:SetPoint("CENTER", f.disc, "CENTER")
	f.kicker = T.Text(host, "caption", "glow", "LEFT", "bold")
	f.kicker:SetPoint("TOPLEFT", f, "TOPLEFT", 74, -20)
	f.kicker:SetText("Wuber · crew offer")
	f.title = T.Text(host, "body", "white", "LEFT", "bold")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 74, -36)
	f.title:SetWidth(240)
	f.text = para(host, "caption", "muted", 296, 3)
	f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -72)
	f.yes = T.Pill(host, "Yes", "primary", 124, 36)
	f.yes:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
	f.no = T.Pill(host, "No thanks", "dark", 108, 36)
	f.no:SetPoint("RIGHT", f.yes, "LEFT", -8, 0)
	f.no.fill:SetColor("raised")
	f.no:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
	f.never = CreateFrame("Button", nil, host)
	f.never:SetSize(60, 20)
	f.never:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 22)
	f.never.text = T.Text(f.never, "caption", "muted", "LEFT", "regular")
	f.never.text:SetPoint("LEFT", f.never, "LEFT", 0, 0)
	f.never.text:SetText("Hide them")
	local function answer(yes)
		local who = f.from
		f.from = nil
		A.FadeOut(f, 0.18)
		if not who then return end
		dr("AnswerOffer", who, yes)
		if yes then
			toast(f.raid and ("You summon for " .. short(who) .. "'s raid") or ("You're in " .. short(who) .. "'s crew"), "found")
		end
		D.Refresh(true)
	end
	safeScript(f.yes, "OnClick", function() answer(true) end)
	safeScript(f.no, "OnClick", function() answer(false) end)
	T.Press(f.never)
	safeScript(f.never, "OnClick", function()
		local who = f.from
		local k = who and W.Key(who)
		if k and W.db and type(W.db.hidden) == "table" then W.db.hidden[k] = true end
		answer(false)
	end)
	T.Tip(f.yes, "Yes, join", function()
		if f.raid then return "You summon raiders who ask: your big button casts on the next one. Leave any time from Crew." end
		return "You'll get a call to click their portal, and their group invites are accepted for you. Leave any time from Crew."
	end)
	T.Tip(f.no, "No thanks", "Says no. Nothing changes for you.")
	T.Tip(f.never, "Hide them", "Says no and hides this player in Wuber: no more offers from them.")
	f:Hide()
	return f
end

-- (issue 102) the big summon button and its console, while they show: boxes { left, right, bottom,
-- top } in UIParent units, for the card to keep off
local function buttonBoxes()
	local out = {}
	local ue = N(Try(UIParent, "GetEffectiveScale"))
	if not (ue and ue > 0) then return nil end
	for _, name in ipairs({ "WuberDriveButton", "WuberDriveMini" }) do
		local g = rawget(_G, name)
		if type(g) == "table" and W.Plain(Try(g, "IsVisible")) then
			local l, r, b, t = N(Try(g, "GetLeft")), N(Try(g, "GetRight")), N(Try(g, "GetBottom")), N(Try(g, "GetTop"))
			local e = N(Try(g, "GetEffectiveScale"))
			if l and r and b and t and e and r > l and t > b then
				local k = e / ue
				out[#out + 1] = { l * k, r * k, b * k, t * k }
			end
		end
	end
	return #out > 0 and out or nil
end

-- (BRIEF19 R6) at the top of the screen, unless the chat frame is there (a UI pack moved it);
-- (BRIEF20 B4) or an action bar or the party frames; (issue 102) or the big button and its console
local function placeOffer(f)
	local x, y = 0, OFFER_TOP
	local OFFER_H = f:GetHeight() or OFFER_H
	local sw, sh = N(Try(UIParent, "GetWidth")), N(Try(UIParent, "GetHeight"))
	local away = UI.ClearOfHud or UI.ClearOfChat
	if sw and sh and type(away) == "function" then
		local l, b, moved = away(sw / 2 - OFFER_W / 2, sh + OFFER_TOP - OFFER_H, OFFER_W, OFFER_H, buttonBoxes(), true)
		if moved then x, y = l + OFFER_W / 2 - sw / 2, b + OFFER_H - sh end
	end
	f:ClearAllPoints()
	f:SetPoint("TOP", UIParent, "TOP", x, y)
end

function UI.CrewOffer(fromName, service)
	fromName = S(fromName)
	if not fromName then return false end
	offerCard = offerCard or buildOffer()
	local f = offerCard
	local who = short(fromName)
	f.from = fromName
	local svc = S(service)
	f.raid = svc == "raid"
	if f.raid then
		-- raid summons (SPEC4 3.1): a Warlock in the raid is asked to summon for it
		f.kicker:SetText("Wuber · raid summons")
		f.title:SetText("Summon for " .. who .. "'s raid?")
		f.text:SetText("You'll get a big button that summons the next raider. No charge, for your own raid; stop any time.")
	else
		f.kicker:SetText("Wuber · crew offer")
		f.title:SetText("Join " .. who .. "'s summoning crew?")
		f.text:SetText((svc and svc ~= "" and svc ~= fromName and (svc .. ". ") or "") .. "You'll get a call to click the portal and "
			.. who .. "'s invites are accepted for you.")
	end
	local h = OFFER_H + ((f.text.paraH or 0) > 49 and (f.text.paraH - OFFER_TEXT_ROOM) or 0)
	f:SetHeight(h)
	f.card:SetHeight(h)
	placeOffer(f)
	f:SetAlpha(1)
	A.FadeIn(f, 0.2)
	A.Move(f, 0, 30, 0.26)
	W.Sound("found")
	local token = (f.token or 0) + 1
	f.token = token
	-- no answer in a minute: put away (no answer is sent)
	W.After(60, function()
		if f.token == token and f.from then
			f.from = nil
			A.FadeOut(f, 0.3)
		end
	end)
	-- (issue 102) the big button or its console can show after the card does: look again until it is
	-- answered, so the card never sits on them (a place that has not changed is set again, unseen)
	local function keepClear()
		W.After(0.5, function()
			if f.token ~= token or not f.from then return end
			-- not from under the mouse: a card that jumps as the player clicks is a missed click
			if not W.Plain(Try(f, "IsMouseOver")) then placeOffer(f) end
			keepClear()
		end)
	end
	keepClear()
	st.offer = f
	return true
end

---------------------------------------------------------------------------
-- The floating mini console: the top four riders and Pause / Close under the big button
---------------------------------------------------------------------------

local mini
local PILL_H = 30 -- Pause and Close: a pill keeps half its height clear at each end of its label

local function buildMini()
	local f = CreateFrame("Frame", "WuberDriveMini", UIParent)
	f:SetSize(300, 60)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f.bg = T.Rounded(f, { 0.07, 0.07, 0.13, 0.92 }, 14, "BACKGROUND", 0)
	f.rows = {}
	for i = 1, 4 do
		local r = D.Row(f, 284)
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8 - (i - 1) * 48)
		f.rows[i] = r
	end
	f.pause = T.Pill(f, "Pause", "dark", 136, PILL_H)
	f.pause.fill:SetColor("raised")
	safeScript(f.pause, "OnClick", function()
		-- a helper's pause would only pause their own screen (review #17): Warlocks pause
		if D.CanPause and not D.CanPause() then return end
		D.SetPaused(not (dr("IsPaused") == true))
	end)
	T.Tip(f.pause, function() return dr("IsPaused") == true and "Resume" or "Pause" end,
		function()
			if K.RaidMode and K.RaidMode() then return "Pause: no new summons. Resume: summon raiders again." end
			return "Pause: no new invites, riders in your group are still summoned. Resume: invite again."
		end)
	f.close = T.Pill(f, "Close", "dark", 136, PILL_H)
	f.close.fill:SetColor("raised")
	safeScript(f.close, "OnClick", function()
		local wasOpen = dr("IsOpen") == true
		D.SetOnline(not wasOpen)
		if wasOpen and dr("IsOpen") ~= true then D.DelistOnOffline() end
	end)
	T.Tip(f.close, function()
		if K.RaidMode and K.RaidMode() then return dr("IsOpen") == true and "Stop" or "Start" end
		return dr("IsOpen") == true and "Close" or "Open"
	end, function()
		if K.RaidMode and K.RaidMode() then return "Stop or start raid summons. The full console is in Wuber's Drive tab." end
		return "Close: stop taking riders. Open: take riders again. The full console is in Wuber's Drive tab."
	end)
	f.more = T.Text(f, "caption", "muted", "CENTER", "medium")
	f.more:SetWidth(284)
	-- (2.3, SPEC7 5.4) the small fuel gauge between Pause and Close
	if type(D.FuelGauge) == "function" then f.fuel = D.FuelGauge(f, 24, 16, "caption") end
	f:Hide()
	st.mini = f
	return f
end

-- placed under the floating button, at its scale (by coordinates, never anchored to it);
-- the last place is kept as numbers on f (no string built 4 times a second, review #27)
local MINI_GAP = 10 -- clear space between a pill and the shard gauge

-- (design 3, fix wave) the console is as wide as the button (240 at least). Only when its foot's words do not
-- fit that does it take more (f.grow, set by D.UpdateMini), and then evenly on both sides: centred on the button
local function anchorMini(f)
	local grow = N(f.grow) or 0
	f:SetWidth((N(f.baseW) or 300) + grow)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (N(f.ax) or 0) - grow / 2, N(f.ay) or 0)
end

local function placeMini(f, b)
	local l, bt = N(Try(b, "GetLeft")), N(Try(b, "GetBottom"))
	local bw, be = N(Try(b, "GetWidth")), N(Try(b, "GetEffectiveScale"))
	-- (BRIEF18) the button's layer too: above the window when it cannot clear it, never under
	local strata = S(Try(b, "GetFrameStrata")) or "MEDIUM"
	if f.placed and l == f.pl and bt == f.pb and bw == f.pw and be == f.pe and strata == f.ps then return true end
	f.pl, f.pb, f.pw, f.pe, f.placed = l, bt, bw, be, nil
	if strata ~= f.ps then
		f.ps = strata
		f:SetFrameStrata(strata)
	end
	local ue = N(Try(UIParent, "GetEffectiveScale"))
	if not (l and bt and be and ue and bw) or ue <= 0 then return false end
	f.placed = true
	local s = be / ue
	f:SetScale(s)
	f.baseW, f.ax, f.ay = math.max(240, bw), l * be / (ue * s), (bt - 4) * be / (ue * s)
	anchorMini(f)
	return true
end

local function miniWanted()
	if dr("Lock") then return nil end
	local b = DR.button
	if type(b) ~= "table" or type(b.IsShown) ~= "function" or not b:IsShown() then return nil end
	if type(DR.Button) == "table" and type(DR.Button.Floating) == "function" then
		if call(DR.Button.Floating) ~= true then return nil end
	elseif D.Slot and D.Slot() then
		return nil
	end
	if type(DR.Button) == "table" and DR.Button.docked then return nil end
	-- (round 19 review) no room for the console beside the open phone: the button floats alone
	if type(DR.Button) == "table" and type(DR.Button.Solo) == "function" and call(DR.Button.Solo) == true then return nil end
	return b
end

function D.UpdateMini()
	local b = miniWanted()
	if not b then
		if mini and mini:IsShown() then mini:Hide() end
		return
	end
	mini = mini or buildMini()
	local f = mini
	if not f.follows then
		-- while the button is dragged it moves every frame: the console follows in the same frame, not at the next tick
		f.follows = true
		f:SetScript("OnUpdate", function(self)
			local btn = DR.button
			if type(btn) == "table" and btn.moving then
				local wb = miniWanted()
				if wb and not placeMini(self, wb) then self:Hide() end
			end
		end)
	end
	if not placeMini(f, b) then
		f:Hide()
		return
	end
	-- the rows: when something changed, else once a second (their timers)
	local t0 = now()
	if f:IsShown() and not f.dirty and t0 - (f.paintedAt or 0) < 1 then return end
	f.dirty, f.paintedAt = nil, t0
	local raid = K.RaidMode and K.RaidMode() == true
	local list = dr(raid and "RaidQueue" or "Sorted")
	list = type(list) == "table" and list or {}
	local wdt = N(f.baseW) or N(f:GetWidth()) or 300
	local open = dr("IsOpen") == true
	local canPause = not D.CanPause or D.CanPause()
	local pauseWord = canPause and (dr("IsPaused") == true and "Resume" or "Pause") or "Warlocks pause"
	local closeWord = raid and (open and "Stop" or "Start") or (open and "Close" or "Open")
	-- (BRIEF18 item 2) laid out from measured geometry: 8 | pill | gap | gauge | gap | pill | 8, the gauge between the pills
	if f.fuel and D.PaintFuel then call(D.PaintFuel, f.fuel) end -- (design 1 J) the words first: their width is the gauge's
	local gw = f.fuel and (N(f.fuel:GetWidth()) or 24) or 0
	local gap = f.fuel and MINI_GAP or 6
	-- (design 3) the foot holds its words whole in the button's width: two equal pills where both labels fit in
	-- them (as it always was); else each pill is as wide as its own label needs (the label, half the pill's height
	-- clear at each end, 2 spare) and they share what is left. Only when even that is wider than the button does
	-- the console (and its rows) take the wider measure, centred on the button (anchorMini)
	local pauseW = math.floor((wdt - 16 - 2 * gap - gw) / 2)
	local closeW = pauseW
	local grow = 0
	if open then
		local words1 = f.pause.label
		local size, weight = words1.wuberBase or "sub", words1.wuberWeight
		local pw = math.ceil(N(T.MeasureText(pauseWord, size, weight)) or 0) + PILL_H + 2
		local cw = math.ceil(N(T.MeasureText(closeWord, size, weight)) or 0) + PILL_H + 2
		if math.max(pw, cw) > pauseW then
			local need = 16 + 2 * gap + gw + pw + cw
			if need > wdt then
				grow = need - wdt
				wdt = need
			end
			local spare = math.floor((wdt - need) / 2)
			pauseW, closeW = pw + spare, cw + spare
		end
	end
	if grow ~= (N(f.grow) or 0) then
		f.grow = grow
		anchorMini(f)
	end
	local y = 8
	-- (round 31) as many rows as the button's place has room for (B.MiniRows; nil: four)
	local cap = type(DR.Button) == "table" and type(DR.Button.MiniRows) == "function" and N(call(DR.Button.MiniRows)) or nil
	local n = math.min(cap or 4, 4, #list)
	local t = now()
	-- (design 3) a row whose chips need a third line is taller: each row is placed under the one before, and a
	-- row that would pass the room the button's place has (cap rows of 48, or the screen bottom at f.ay) stays
	-- out ("+N more" says so), keeping the Pause/Close foot on screen
	local budget = cap and (8 + cap * 48) or nil
	local room = N(f.ay)
	for i = 1, 4 do
		local r = f.rows[i]
		r:SetWidth(wdt - 16)
		if i <= n then
			if raid then D.PaintRaidRow(r, list[i], t) else D.PaintRow(r, list[i], t) end
			local rh = N(r:GetHeight()) or 44
			local foot = (#list > i and 16 or 0) + 38
			if (budget and i > 1 and y + rh + 4 > budget) or (room and y + rh + 4 + foot > room) then
				n = i - 1
				r:Hide()
			else
				r:ClearAllPoints()
				r:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -y)
				y = y + rh + 4
			end
		else
			r:Hide()
		end
	end
	if #list > n and (not room or y + 16 + 38 <= room) then
		f.more:ClearAllPoints()
		f.more:SetPoint("TOP", f, "TOP", 0, -y)
		f.more:SetText("+" .. (#list - n) .. " more in Wuber's Drive tab")
		f.more:Show()
		y = y + 16
	else
		f.more:Hide()
	end
	-- (BRIEF20 B5, shots 83 and 88) closed or stopped, Pause does nothing: hidden (not dimmed), and
	-- the line is 8 | gauge | gap | Open (or Start) | 8
	f.pause:SetShown(open)
	local gx = math.floor(wdt / 2)
	if open then
		f.close:SetWidth(closeW)
		-- unequal pills: the gauge stands in the middle of the room between them
		if pauseW ~= closeW then gx = math.floor((8 + pauseW + wdt - 8 - closeW) / 2 + 0.5) end
	else
		gx = 8 + math.floor(gw / 2 + 0.5)
		f.close:SetWidth(wdt - 16 - (f.fuel and (gw + gap) or 0))
	end
	f.pause:SetWidth(pauseW)
	-- the words after the widths: a label is fitted to the room its pill has now
	f.pause:SetLabel(pauseWord)
	f.pause:SetActive(open and canPause)
	f.close:SetLabel(closeWord)
	f.pause:ClearAllPoints()
	f.pause:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -y)
	f.close:ClearAllPoints()
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -y)
	if f.fuel then
		f.fuel:ClearAllPoints()
		f.fuel:SetPoint("CENTER", f, "TOPLEFT", gx, -(y + 15))
		-- (20 Nov hotfix) the gauge draws above the pills, so a pill can never cover the shard count
		pcall(f.fuel.SetFrameLevel, f.fuel, (tonumber(f.pause:GetFrameLevel()) or 0) + 3)
	end
	f:SetHeight(y + 38)
	if not f:IsShown() then f:Show() end
end

---------------------------------------------------------------------------
-- Toasts and alerts
---------------------------------------------------------------------------

-- (2.3, SPEC7 5.8) a rider asks for a raincheck: DRIVE_ALERT(text, "raincheck", data), data =
-- { rideId, name } (or the ride id, then the name). A click opens "Give raincheck" for that ride.
local function raincheckAlert(text, data, name)
	local ride, who
	if type(data) == "table" then
		ride, who = S(data.rideId) or S(data.ride) or S(data.id), S(data.name) or S(data.rider)
	else
		ride, who = S(data), S(name)
	end
	local t = toast(text, "raincheck", function()
		if UI.ShowDrive then UI.ShowDrive("console") end
		if ride then D.ShowSheet("menu", { name = who or "Rider", key = who and W.Key(who), wuberRide = ride, iouOnly = true }) end
	end)
	if type(t) == "table" then t.tip = "Click to give a raincheck: one summon later at no charge. It counts only once they accept." end
	return t
end

W.Listen("DRIVE_ALERT", function(text, kind, data, name)
	text = S(text)
	if not text then return end
	kind = S(kind) or "info"
	local t
	if kind == "raincheck" then
		t = raincheckAlert(text, data, name)
	else
		t = toast(text, kind, function()
			if UI.Show then UI.Show("drive") end
		end)
		if type(t) == "table" then t.tip = "Click to open your driver console." end
	end
	W.Sound("alert")
	if kind == "portal" and type(UIErrorsFrame) == "table" and type(UIErrorsFrame.AddMessage) == "function" then
		pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, text, 1, 0.36, 0.48)
	end
	D.Refresh(true)
end)

W.Listen("DRIVE_BLOCKED", function(name, reason, auto)
	name = S(name)
	if not name then return end
	local text = auto and (short(name) .. " left without paying: blocked. Click to undo.")
		or (short(name) .. " is blocked (" .. (S(reason) or "by hand") .. "). Click to undo.")
	local t = toast(text, auto and "nonpayer" or "blocked", function()
		dr("Unblacklist", name)
		toast(short(name) .. " is unblocked", "info")
		D.Refresh(true)
	end)
	if type(t) == "table" then t.tip = "Click within 10 seconds to unblock them (your crew too)." end
	D.Refresh(true)
end)

W.Listen("DRIVE_OFFER", function(fromName, service) UI.CrewOffer(fromName, service) end)

-- the mini console and the minimap's gold flash follow the engine
W.Listen("DRIVE", function()
	if mini then mini.dirty = true end
	if UI.RefreshMinimap then
		local t = now()
		if t - (st.mmAt or 0) >= 0.5 then
			st.mmAt = t
			call(UI.RefreshMinimap)
		end
	end
end)

W.Listen("DRIVE_PAID", function()
	D.Refresh(true)
	local e = st.screens.earnings
	if e and e.frame:IsShown() and e.update then call(e.update) end
end)

W.Listen("DRIVE_LOG", function()
	local e = st.screens.earnings
	if e and e.frame:IsShown() and e.update then call(e.update) end
end)

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

-- Opens the window on the Drive tab and shows a screen there.
function UI.ShowDrive(screen, arg)
	screen = S(screen) or "console"
	if UI.Show and not (UI.IsShown and UI.IsShown() and UI.state and UI.state.tab == "Drive") then
		call(UI.Show, "drive")
	end
	if UI.state and UI.state.settingsOpen and UI.CloseSettings then call(UI.CloseSettings, true) end
	return D.ShowScreen(screen, arg) == true
end

function UI.DriveSlot() return D.Slot and D.Slot() or nil end

-- "Open · 2 riders · 1g 50s today" (nil when not driving at all)
function UI.DriveSummary()
	if dr("Lock") then return nil end
	local role = D.Role and D.Role() or nil
	if not role then return nil end
	local open, paused = dr("IsOpen") == true, dr("IsPaused") == true
	if K.RaidMode and K.RaidMode() then
		local q = dr("RaidQueue")
		local nq = type(q) == "table" and #q or 0
		return "Raid summons: " .. (open and (paused and "paused" or "running") or "stopped") .. " · " .. nq .. " waiting"
			.. " · " .. (D.RaidTonight and D.RaidTonight() or 0) .. " tonight"
	end
	local list = dr("Sorted")
	local n = type(list) == "table" and #list or 0
	local _, copper = 0, 0
	if D.Today then _, copper = D.Today() end
	local state = open and (paused and "Paused" or "Open") or "Closed"
	if not open and n == 0 and (copper or 0) == 0 then return "Driving: closed" end
	return "Driving: " .. state .. " · " .. plural(n, "rider") .. " · " .. ((copper or 0) > 0 and money(copper) or "0g") .. " today"
end

-- the big button has a click for you (a summon, a trade, a thanks, the portal)
function UI.DriveWantsClick()
	if dr("Lock") then return false end
	local plan = DR.button and DR.button.plan or dr("Plan")
	if type(plan) ~= "table" or plan.paused then return false end
	return plan.type == "macro" or plan.type == "click" or plan.color == "alert"
end

-- The mini console's ticker runs only while the big button floats (review #27): nothing ticks
-- on a rider, or while the button is docked in the Drive tab or hidden. The button's own
-- placing (B.onPlace), its show / hide and the engine's DRIVE event start and stop it.
local miniTicker
function D.SyncMini()
	local want = miniWanted() ~= nil
	if want and not miniTicker then
		miniTicker = W.Every(0.25, function() W.Safe("drive mini", D.UpdateMini) end)
		if mini then mini.dirty = true end
		W.Safe("drive mini", D.UpdateMini)
	elseif not want and miniTicker then
		if type(miniTicker) == "table" and miniTicker.Cancel then pcall(miniTicker.Cancel, miniTicker) end
		miniTicker = nil
		if mini and mini:IsShown() then mini:Hide() end
	end
	return want
end
function D.MiniTicking() return miniTicker ~= nil end

local hooked
local function hookButton()
	local B = DR.Button
	if type(B) == "table" and not B.wuberMiniHook then
		local before = B.onPlace
		B.onPlace = function(...)
			if type(before) == "function" then pcall(before, ...) end
			W.Safe("drive mini", D.SyncMini)
		end
		B.wuberMiniHook = true
	end
	local b = DR.button
	if not hooked and type(b) == "table" and type(b.HookScript) == "function" then
		hooked = true
		pcall(b.HookScript, b, "OnShow", function() W.Safe("drive mini", D.SyncMini) end)
		pcall(b.HookScript, b, "OnHide", function() W.Safe("drive mini", D.SyncMini) end)
	end
end

W.OnLogin(function()
	W.After(0.5, function()
		hookButton()
		W.Safe("drive mini", D.SyncMini)
	end)
end)
W.Listen("DRIVE", function()
	hookButton()
	W.Safe("drive mini", D.SyncMini)
end)
W.On("PLAYER_REGEN_ENABLED", function() W.Safe("drive mini", D.SyncMini) end)
