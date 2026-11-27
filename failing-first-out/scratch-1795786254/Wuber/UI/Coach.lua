-- Module: UI.Coach
-- Purpose: First-open coach marks (UI.COACH, UI.CoachStep, UI.ReplayCoach, UI.EndCoach).
-- API: UI.COACH, UI.EndCoach, UI.ReplayCoach, UI.CoachStep, UI.MaybeCoach, Mod.Why
--   Why(): nil, or the line /wuber why prints while the guide is held back ("First-open guide: ..."); read-only.
-- Internals: maybeCoach, stopCoachForNow
-- Uses: UI.Kit, UI.Window
-- Later: UI.Fold (Apply, when the tips start or stop); the guide waits while UI.Tips' card shows (the frame WuberTipCard, read by its name).
--   The common rules for opening by itself (combat, a cinematic, the first seconds after login, another self-opening
--   thing up) are UI.MayOpen("coach") (UI.Kit); its own rules are Home in the Ride tab and no ride.
-- Events: listens (none); fires SETTINGS
-- Standalone: no
-- Test: tests/v24/f3_l_coach_test.lua
-- From: UI.lua 4354-4522 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Coach", { "UI.Kit", "UI.Window" })
local KitMod = W.Mod("UI.Kit")
local WindowMod = W.Mod("UI.Window")
local N = KitMod.N
local WIN_W = KitMod.WIN_W
local call = KitMod.call
local rideActive = KitMod.rideActive
local safeScript = KitMod.safeScript
local ui = KitMod.ui
local screens = WindowMod.screens
local T = W.Theme
local function wrapH(n, size) return n * T.DrawnSize(size) + (n - 1) * T.Spacing(size) end -- n wrapped lines, spacing between them
local A = T.Animate
local Try = T.Try
local UI = W.UI

---------------------------------------------------------------------------
-- First-open coach marks: five short tips inside the window (finding, paying, driving),
-- skippable; done only on "Got it" or "Skip tips" (review #22), Settings > Replay tips again
---------------------------------------------------------------------------

local COACH = {
	{ title = "Where to?", text = "Type a place, like Undercity. Only drivers who match are listed.",
		target = function() return screens.home and screens.home.search end },
	{ title = "Pick a driver", text = "Click a card to see the fare, then Request summon.",
		target = function() return screens.home and screens.home.header end },
	{ title = "Pay when you land", text = "Nothing up front. After the summon, type the fare in your driver's trade and click Trade.",
		target = function() return screens.home and screens.home.clip end },
	{ title = "Sell summons too", text = "Warlocks and their friends can sell summons from the Drive tab.",
		target = function()
			for _, tab in ipairs(ui.tabs) do if tab.name == "Drive" then return tab.button end end
			return nil
		end },
	{ title = "Your trips and settings", text = "Trips keeps your rides. The cog has every option; hover for tips.",
		target = function() return ui.gear end },
}
UI.COACH = COACH

local COACH_W, COACH_H = WIN_W - 24, 126
-- (v2.4 fix 3, stage B) the mark's height follows its words: 126 holds a one-line title and two lines of text;
-- each line more (a longer title wrapping, a third line of text) makes the card taller, never cuts or shrinks
local COACH_TITLE_LINE = 18 -- a 14 px title line (COACH_H holds two lines of the text: wrapH(2, "sub"); a third adds one more line)

local function buildCoach()
	-- inside the window (never off the screen's edge), over everything in it
	local b = CreateFrame("Frame", nil, ui.win)
	b:SetSize(COACH_W, COACH_H)
	b:SetFrameStrata(ui.strata or "HIGH") -- (run 1, item 2) the window's strata, never over another page
	b:SetFrameLevel(ui.win:GetFrameLevel() + 90)
	b:SetClampedToScreen(true)
	b:EnableMouse(true)
	b.card = T.Card(b, COACH_W, COACH_H, { colour = { 0.09, 0.08, 0.17, 1 }, radius = 16, border = "accent" })
	b.card:SetAllPoints(b)
	local host = b.card
	b.step = T.Text(host, "caption", "glow", "LEFT", "bold")
	b.step:SetPoint("TOPLEFT", b, "TOPLEFT", 16, -14)
	b.title = T.Text(host, "body", "white", "LEFT", "bold")
	b.title:SetPoint("TOPLEFT", b, "TOPLEFT", 16, -30)
	b.title:SetWidth(COACH_W - 32)
	Try(b.title, "SetWordWrap", true)
	b.text = T.Text(host, "sub", "muted", "LEFT", "regular")
	b.text:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -5)
	b.text:SetWidth(COACH_W - 32)
	Try(b.text, "SetWordWrap", true)
	Try(b.text, "SetMaxLines", 0)
	b.next = T.Pill(host, "Next", "primary", 84, 28)
	b.next:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -12, 10)
	b.skip = T.Pill(host, "Skip tips", "ghost", 90, 28)
	b.skip:SetPoint("RIGHT", b.next, "LEFT", -4, 0)
	b.skip.label:SetTextColor(T.RGB("muted"))
	safeScript(b.next, "OnClick", function()
		local i = (ui.coachStep or 1) + 1
		if i > #COACH then UI.EndCoach() else UI.CoachStep(i) end
	end)
	safeScript(b.skip, "OnClick", function() UI.EndCoach() end)
	T.Tip(b.next, "Next tip", "Show the next tip.")
	T.Tip(b.skip, "Skip tips", "Hide these tips. Settings > Riding > Tips > Replay shows them again.")
	-- the thin violet outline round the thing a tip is about (never takes the mouse; design 1: flat, no glow)
	b.ring = CreateFrame("Frame", nil, ui.win)
	b.ring:SetFrameStrata(ui.strata or "HIGH")
	b.ring:SetFrameLevel(ui.win:GetFrameLevel() + 89)
	b.ring:EnableMouse(false)
	b.ring.edge = T.Outline(b.ring, "glow", 2)
	b.ring.ag = b.ring:CreateAnimationGroup()
	b.ring.ag:SetLooping("BOUNCE")
	local a = b.ring.ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.35)
	a:SetDuration(0.8)
	b.ring:Hide()
	b:Hide()
	return b
end

-- hides the tips; done = they were read or skipped (W.db.coach), else they come back
local function refold()
	-- the window folds while the tips run and may open out again after (UI.Fold loads later)
	if UI.Fold and type(UI.Fold.Apply) == "function" then W.Safe("fold", UI.Fold.Apply) end
end

local function hideCoach(done)
	ui.coaching = false
	refold()
	if done and W.db then
		W.db.coach = true
		ui.coachStep = nil
		W.Fire("SETTINGS", "coach")
	end
	local b = ui.coach
	if b then
		b.ring.ag:Stop()
		b.ring:Hide()
		if done then A.FadeOut(b, 0.2) else b:Hide() end
	end
end

function UI.EndCoach() hideCoach(true) end

-- Settings > Replay tips: the tips again from the first, on Home
function UI.ReplayCoach()
	if W.db then W.db.coach = false end
	ui.coachTried, ui.coachStep = false, nil
	hideCoach(false)
	if type(UI.CloseSettings) == "function" and ui.settingsOpen then call(UI.CloseSettings, true) end
	if ui.tab ~= "Ride" then call(UI.SelectTab, "Ride") end
	UI.Show("home")
	UI.Refresh(true)
end

function UI.CoachStep(i)
	local b = ui.coach
	local tip = COACH[i]
	local win = ui.win
	if not (b and tip and win and win:IsShown()) then
		hideCoach(false)
		return
	end
	if not ui.coachBarHooked then
		ui.coachBarHooked = true
		UI.OnBarSync(function()
			if ui.coaching and ui.coach and ui.coach:IsShown() then UI.CoachStep(ui.coachStep or 1) end
		end)
	end
	local target = tip.target()
	if not (target and target:IsVisible()) then
		-- nothing to point at (e.g. no Drive tab): the next tip, or the end
		if i < #COACH then return UI.CoachStep(i + 1) end
		UI.EndCoach()
		return
	end
	local pos, total = 0, 0
	for k = 1, #COACH do
		local t = COACH[k].target()
		if t and t:IsVisible() then
			total = total + 1
			if k <= i then pos = total end
		end
	end
	ui.coachStep = i
	b.step:SetText("Tip " .. pos .. " of " .. total)
	b.title:SetText(tip.title)
	b.text:SetText(tip.text)
	b.next:SetLabel(pos == total and "Got it" or "Next")
	local tl = T.ParaLines(tip.title, "body", "bold", COACH_W - 32)
	local xl = T.ParaLines(tip.text, T.SIZE.sub, "regular", COACH_W - 32)
	local texth = wrapH(xl, "sub") -- (design 3) n lines of the text's own size and spacing
	local h = COACH_H + (tl - 1) * math.max(COACH_TITLE_LINE, wrapH(2, "body") - T.DrawnSize("body")) + math.max(0, texth - wrapH(2, "sub"))
	b:SetHeight(h)
	-- inside the window: at the bottom when the target is in the top half, else at the top. (design 2) The tabs are
	-- a bar at the bottom and the window's buttons (fold, cog, x) lie over the top: the bubble rests 8 above the tab
	-- bar (the tabs stay free, and tip 4 points at one) or 8 under the buttons (tip 5 points at the cog)
	local wt, wb = N(win:GetTop()) or 600, N(win:GetBottom()) or 0
	local _, ty = target:GetCenter()
	ty = N(ty) or wt
	b:ClearAllPoints()
	if ty > (wt + wb) / 2 then
		b:SetPoint("BOTTOM", win, "BOTTOMLEFT", WIN_W / 2, UI.TabBottom() + 8) -- the primary pane's centre
	else
		b:SetPoint("TOP", win, "TOPLEFT", WIN_W / 2, -((N(UI.HEAD_ROW) or 44) + 8))
	end
	-- the window may have been raised (over the world map) since the marks were built
	b:SetFrameStrata(ui.strata or "HIGH")
	b.ring:SetFrameStrata(ui.strata or "HIGH")
	b.ring:ClearAllPoints()
	b.ring:SetPoint("TOPLEFT", target, "TOPLEFT", -4, 4)
	b.ring:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 4, -4)
	b.ring:Show()
	b.ring.ag:Play()
	if not b:IsShown() then A.Pop(b, 0.3) end
	b:Show()
end

-- the login tip card is up (Help > Show a tip before the guide has run): the guide waits for a later look
local function tipUp()
	-- (the frame by its name: asking UI.Tips for its card would build it on every first look)
	local c = rawget(_G, "WuberTipCard")
	return type(c) == "table" and type(c.IsShown) == "function" and c:IsShown() and true or false
end

local maybeCoachAgain -- (maybeCoach, for its own timer)

-- Starts the tips on the first open (and after an interruption: where they were): Home, no
-- ride, nothing else on top (not the login tip card either).
local function maybeCoach()
	if ui.coaching or ui.coachTried or not W.db or W.db.coach == true then return end
	local win = ui.win
	if not (win and win:IsShown()) or ui.splashing or ui.settingsOpen or ui.tab ~= "Ride" or ui.screen ~= "home" then return end
	if rideActive() then return end
	if not UI.MayOpen("coach") then
		-- held by a common rule (combat, a cinematic, just logged in, the tip card): one look again shortly
		if not ui.coachRetry then
			ui.coachRetry = true
			W.After(1, function() ui.coachRetry = false maybeCoachAgain() end)
		end
		return
	end
	ui.coachTried = true
	ui.coaching = true
	refold()
	-- a token: a timer from an earlier queueing (left Home, came back) must not start the tips
	ui.coachToken = (ui.coachToken or 0) + 1
	local token = ui.coachToken
	W.After(0.6, function()
		if not ui.coaching or ui.coachToken ~= token then return end
		if ui.splashing or ui.settingsOpen or ui.tab ~= "Ride" or ui.screen ~= "home" or rideActive() or not UI.MayOpen("coach") then
			ui.coaching, ui.coachTried = false, false
			refold()
			return
		end
		ui.coach = ui.coach or buildCoach()
		UI.CoachStep(ui.coachStep or 1)
	end)
end
UI.MaybeCoach = maybeCoach
maybeCoachAgain = function() UI.MaybeCoach() end

local function stopCoachForNow()
	if not ui.coaching then return end
	-- a ride, another tab or screen, or closing the window: hidden for now, never "done"
	-- (only Got it / Skip tips are); they come back on Home where they were
	hideCoach(false)
	ui.coachTried = false
end

-- the common rules' lines (UI.MayOpen's reasons)
local GATE_WHY = {
	combat = "First-open guide: not in combat.",
	cinematic = "First-open guide: not during a cinematic.",
	login = "First-open guide: shows a few seconds after login.",
	other = "First-open guide: waits for the card on screen to close.",
}

-- /wuber why: nil while the guide shows, once it is done (Got it or Skip tips), or when no rule
-- holds it back; else one line naming the first of maybeCoach's rules that does. Read-only.
function Mod.Why()
	if ui.coaching or not W.db or W.db.coach == true then return nil end
	if ui.coachTried then return "First-open guide: stopped for this session. The Replay button on the Tips row of Settings, Riding, starts it again." end
	local win = ui.win
	if not (win and win:IsShown()) then return "First-open guide: it shows when you open Wuber." end
	if ui.splashing or ui.settingsOpen or ui.tab ~= "Ride" or ui.screen ~= "home" then
		return "First-open guide: it shows on the Ride tab's first screen."
	end
	if rideActive() then return "First-open guide: not during a ride." end
	if tipUp() then return "First-open guide: waiting for the tip card to close." end
	local okGate, gate = UI.MayOpen("coach")
	if not okGate then return GATE_WHY[gate] end
	return nil
end

-- internals other modules use (bound at load by later modules, or called late)
Mod.maybeCoach = maybeCoach
Mod.stopCoachForNow = stopCoachForNow
