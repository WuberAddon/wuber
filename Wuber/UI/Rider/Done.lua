-- Module: UI.Rider.Done
-- Purpose: Done and Sorry screens.
-- API: UI.RaincheckAskable
-- Internals: buildDone, buildSorry, askPill
-- Uses: UI.Kit
-- Later: UI.Share (the share pill's registration, at run time), Drive.Mail (Mod.RiderLine: the unpaid end's
--   "Send 5g to Anita Lift by mail, subject Wuber.")
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/ui/rider/done_test.lua
-- From: UI.lua 3673-4039 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Rider.Done", { "UI.Kit" })

local KitMod = W.Mod("UI.Kit")
local INNER = KitMod.INNER
local N = KitMod.N
local PAD = KitMod.PAD
local S = KitMod.S
local call = KitMod.call
local duration = KitMod.duration
local money = KitMod.money
local myKey = KitMod.myKey
local rideView = KitMod.rideView
local safeScript = KitMod.safeScript
local setShown = KitMod.setShown
local inCombat = KitMod.inCombat
local inGroup = KitMod.inGroup
local ui = KitMod.ui
local T = W.Theme
local noGlow = T.NoGlow -- (design round 1) the shared no-op glow, Theme.Widgets
local A = T.Animate
local Try = T.Try
local UI = W.UI

---------------------------------------------------------------------------
-- Round 8: "Ask for a raincheck" (SPEC7 5.8) and the arrival share (5.12)
---------------------------------------------------------------------------

-- A paid ride that failed before you arrived, within 30 minutes of paying: worth asking the
-- driver for a raincheck (the driver's Wuber decides; this only shows the button).
function UI.RaincheckAskable(rv)
	local R = W.Raincheck
	if not rv or type(R) ~= "table" or type(R.Ask) ~= "function" then return false end
	if ui.rcAsked and ui.rcAsked[rv.id] then return false end
	local r = rv.raw or {}
	if type(R.CanAsk) == "function" then return call(R.CanAsk, rv.id) == true end
	local price, paid = N(rv.price) or 0, N(r.paid) or 0
	if price <= 0 or paid < price or r.unpaid then return false end
	if W.Plain(r.arrived) == true or N(r.arrivedAt) or rv.state == "done" then return false end
	local paidAt, t = N(r.paidAt), type(time) == "function" and time() or nil
	if paidAt and t and t - paidAt > 30 * 60 then return false end
	return true
end

local function askPill(f, s)
	local b = T.Pill(f, "Ask for a raincheck", "dark", INNER, 40)
	b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, T.MAIN.foot + T.MAIN.h + 8)
	safeScript(b, "OnClick", function(self)
		if self.inactive then return end
		local rv = rideView()
		if not rv then return end
		local ok = call(W.Raincheck and W.Raincheck.Ask, rv.id)
		if ok then
			ui.rcAsked = ui.rcAsked or {}
			ui.rcAsked[rv.id] = true
			UI.Toast("Asked " .. rv.short .. " for a raincheck", "info")
		else
			UI.Toast("Couldn't ask right now", "warn")
		end
		UI.Refresh(true)
	end)
	T.Tip(b, "Ask for a raincheck", "You paid and the summon didn't happen. Ask the driver for one summon later at no charge instead. "
		.. "Wuber never sends gold back; the driver decides.", "ANCHOR_TOP")
	b:Hide()
	return b
end

---------------------------------------------------------------------------
-- Screen: Done
---------------------------------------------------------------------------

-- Done (the author's pick, 05 v3): "✓ Undercity · Paid 60s to Mia" on top, then one card with the
-- driver's portal avatar over its edge: "Thank you for riding with Mia", five stars, your
-- habit with them; under it the time saved and what flying would have cost, as quiet pills
-- (only what we know), and Done. An unpaid end: a grey coin, "Ride ended" and one calm card.
local function buildDone(body)
	local s = { frame = CreateFrame("Frame", nil, body) }
	local f = s.frame
	f:SetAllPoints(body)
	f:Hide()
	-- the top line: a small check disc and the place and fare
	local top = CreateFrame("Frame", nil, f)
	top:SetSize(INNER, 40)
	top:SetPoint("TOP", f, "TOP", 0, -18)
	local badge = CreateFrame("Frame", nil, top)
	badge:SetSize(32, 32)
	s.ring = A.Pulse(badge, { size = 70, colour = "magenta", alpha = 0.55, period = 1.4, rings = 1, from = 0.45, start = false })
	s.halo = noGlow() -- (design 1) no halo behind the badge: shown or hidden, it draws nothing
	s.haloOff = noGlow()
	local disc = CreateFrame("Frame", nil, badge)
	disc:SetAllPoints(badge)
	disc:SetFrameLevel(s.ring.frame:GetFrameLevel() + 2)
	local circle = T.Circle(disc, 32, "accent", "ARTWORK")
	circle:SetPoint("CENTER", disc, "CENTER")
	s.disc, s.circle = disc, circle
	local tick = CreateFrame("Frame", nil, disc)
	tick:SetSize(18, 18)
	tick:SetPoint("CENTER", disc, "CENTER", 0, 0)
	local mark = T.Icon(tick, "check", 18, "ink", "OVERLAY")
	mark:SetPoint("CENTER", tick, "CENTER")
	s.tick, s.mark = tick, mark
	s.title = T.Text(top, "heading", "white", "LEFT", "bold")
	-- (design 3) the pulse ring is 70 wide round the 32 badge, so 19 reach past it: the words start 24 from the badge
	s.title:SetPoint("LEFT", badge, "RIGHT", 24, 0)
	s.title:SetWidth(INNER - 56)
	Try(s.title, "SetWordWrap", true) -- (design 2) a long headline goes on a second line (s.centreTop), never under the buttons
	Try(s.title, "SetMaxLines", 0)
	s.top, s.badge = top, badge

	-- the card, the driver's portal over its top edge
	local rate = T.Card(f, INNER, 198, { colour = "card", radius = 22 })
	rate:SetPoint("TOP", f, "TOP", 0, -112)
	s.rate = rate
	local av = CreateFrame("Frame", nil, rate)
	av:SetSize(68, 68)
	av:SetPoint("CENTER", rate, "TOP", 0, 0)
	av:SetFrameLevel((N(rate:GetFrameLevel()) or 0) + 4)
	av.ring = T.Circle(av, 68, "panel", "ARTWORK")
	av.ring:SetPoint("CENTER", av, "CENTER")
	av.art = T.Tex(av, "portal", "ARTWORK", 1)
	av.art:SetSize(62, 62)
	av.art:SetPoint("CENTER", av, "CENTER")
	s.avatar = av
	rate.q = T.Text(rate, "title", "white", "CENTER", "bold")
	rate.q:SetPoint("TOP", rate, "TOP", 0, -42)
	rate.q:SetWidth(INNER - 30)
	Try(rate.q, "SetWordWrap", true)
	Try(rate.q, "SetMaxLines", 2)
	rate.note = T.Text(rate, "caption", "muted", "CENTER", "regular")
	rate.note:SetPoint("TOP", rate, "TOP", 0, -152)
	-- your habit with this driver (review #19): "4-day ride streak · 5 rides with Mia · 3g 20s in all"
	s.habit = T.Text(rate, "sub", "muted", "CENTER", "medium")
	s.habit:SetPoint("TOP", rate, "TOP", 0, -172)
	s.habit:SetWidth(INNER - 24)
	s.stars = {}
	local function paint(n)
		for i, st in ipairs(s.stars) do
			local on = i <= n
			st.fill:SetShown(on)
			st.outline:SetShown(not on)
			st.fill:SetVertexColor(T.RGB("glow"))
		end
	end
	s.paint = paint
	for i = 1, 5 do
		local st = CreateFrame("Button", nil, rate)
		st:SetSize(42, 42)
		st:SetPoint("TOP", rate, "TOP", (i - 3) * 48, -106)
		st.fill = T.Icon(st, "star", 34, "glow", "ARTWORK")
		st.fill:SetPoint("CENTER", st, "CENTER")
		st.outline = T.Icon(st, "star_outline", 34, "muted", "ARTWORK")
		st.outline:SetPoint("CENTER", st, "CENTER")
		st.fill:Hide()
		st:RegisterForClicks("LeftButtonUp")
		safeScript(st, "OnEnter", function()
			if not s.rated then paint(i) end
		end)
		safeScript(st, "OnLeave", function()
			if not s.rated then paint(s.stars.chosen or 0) end
		end)
		T.Press(st)
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
		end)
		T.Tip(st, i .. (i == 1 and " star" or " stars"), "Rate your ride. Your driver is told the stars. You see your ratings in Trips.")
		s.stars[i] = st
	end
	-- the unpaid end's words (inside the same card, no avatar, no stars)
	s.unpaidText = T.Para(rate, "body", "muted", INNER - 40)
	s.unpaidText:SetJustifyH("CENTER")
	s.unpaidText:SetPoint("TOP", rate, "TOP", 0, -24)

	-- the pills: time saved (and "saved to your trips"); what flying would have cost
	local function statPill(icon)
		local p = CreateFrame("Frame", nil, f)
		p:SetSize(INNER, 40)
		p.bg = T.Rounded(p, "card", 14, "BACKGROUND", 0)
		p.icon = T.Icon(p, icon, 18, "muted", "ARTWORK")
		p.icon:SetPoint("LEFT", p, "LEFT", 16, 0)
		p.text = T.Text(p, "caption", "white", "LEFT", "medium")
		p.text:SetPoint("LEFT", p, "LEFT", 44, 0)
		p.text:SetWidth(INNER - 56)
		T.Lines(p.text, 2) -- (design 3) a long line wraps onto a second one, every word kept; the pill grows (fitPill)
		p:EnableMouse(true)
		return p
	end
	-- the pill is 40 high for one line, 48 for two
	local function fitPill(p)
		p:SetHeight(p.text.wuberWrapped and 48 or 40)
	end
	local sp = statPill("clock")
	s.savedPill = sp
	s.saved = sp.text
	T.Tip(sp, "Saved to your trips", "Every paid ride goes into Trips: time saved, places, milestones.")
	local fp = statPill("coin")
	s.flightPill = fp
	s.flight = fp.text
	T.Tip(fp, "Against flying", "The flight master's price for the same trip (as you, or one of your characters, saw it), against what you paid.")
	fp:Hide()
	s.done = T.MainButton(f, "Done") -- (Design 2) the one main button's place
	safeScript(s.done, "OnClick", function()
		UI.Dismiss()
	end)
	T.Tip(s.done, "Done", function()
		return s.unpaid and "Back to the drivers. An unpaid ride isn't saved in Trips." or "Back to the drivers. This trip is saved in Trips."
	end, "ANCHOR_TOP")
	-- the arrival share (5.12): once per ride, in a group, never in combat
	s.share = T.Pill(f, "Share", "dark", INNER, 40)
	s.share:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, T.MAIN.foot + T.MAIN.h + 8)
	safeScript(s.share, "OnClick", function()
		UI.Toast(inCombat() and "Share after combat" or "Join a group to share", "info")
	end)
	T.Tip(s.share, "Share", function() return s.shareLine and ("Posts to your group: \"" .. s.shareLine .. "\"") or "Posts one line to your party." end, "ANCHOR_TOP")
	s.share:Hide()
	if UI.Share and type(UI.Share.Register) == "function" then
		pcall(UI.Share.Register, s.share, function() return W.Advanced() and s.shareLine or nil end, { label = "Share", onShared = function()
			local rv = rideView()
			if rv then ui.flexShared = ui.flexShared or {} ui.flexShared[rv.id] = true end
			s.shareLine = nil
			UI.Refresh(true)
		end })
	end
	s.ask = askPill(f, s)

	-- the top line, centred as one: the disc and the words
	-- (design 2) the window's buttons (cog, x, the fold button) lie over the right end of this row: the line ends 8
	-- before them. Centred while it fits; a longer one moves left; one longer than the room goes on a second line,
	-- every word kept (the row is 40 high and the portal starts 20 under it: two lines of 18 fit).
	function s.centreTop()
		local need = T.MeasureText(S(s.title.wuberText) or "", "heading", "bold")
		-- (folded: at least the cog and the x; the cog is still hidden when this runs on the way in from the pay screen)
		local room = UI.HeadRoom and N(UI.HeadRoom()) or 0
		if room > 0 then room = math.max(room, N(UI.HeadRoom("plain")) or 0) end
		local right = room > 0 and (INNER + PAD - room - 8) or INNER -- the row's right end, from the row's left edge
		local w = math.min(right - 56, need)
		local tw = math.min(right - 56, math.ceil(need * 1.06) + 2)
		s.title:SetWidth(tw)
		-- the row grows with the words: n lines of the heading size plus their spacing (40 for one)
		local n = math.max(1, T.ParaLines(S(s.title.wuberText) or "", "heading", "bold", tw))
		top:SetHeight(math.max(40, n * T.DrawnSize("heading") + (n - 1) * T.Spacing("heading")))
		local left = math.max(0, math.min((INNER - (w + 56)) / 2, right - (w + 56)))
		badge:ClearAllPoints()
		badge:SetPoint("LEFT", top, "LEFT", left, 0)
	end

	function s.enter()
		local rv = rideView()
		s.rated = rv and rv.rated or false
		s.stars.chosen = rv and rv.stars or nil
		paint(s.stars.chosen or 0)
		rate.note:SetText(s.rated and "Thanks for rating" or "Tap a star")
		-- an unpaid end is no victory: no pop, no ring, no fanfare
		if rv and rv.raw and rv.raw.unpaid then return end
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
		local unpaid = rv.raw and rv.raw.unpaid
		local adv = W.Advanced()
		s.shareLine = (adv and not unpaid and not (ui.flexShared and ui.flexShared[rv.id]) and UI.FlexText) and UI.FlexText(rv) or nil
		local askable = not (s.shareLine and inGroup()) and UI.RaincheckAskable(rv)
		setShown(s.ask, askable)
		-- the badge: a violet tick for a paid ride, a quiet grey coin for an unpaid end
		s.circle:SetVertexColor(T.RGB(unpaid and "card" or "accent"))
		s.mark:SetTexture(T.MEDIA .. (unpaid and "coin" or "check"))
		s.mark:SetVertexColor(T.RGB(unpaid and "muted" or "ink"))
		s.mark:SetSize(unpaid and 20 or 18, unpaid and 20 or 18)
		s.halo:SetShown(not unpaid)
		s.haloOff:SetShown(unpaid and true or false)
		s.unpaid = unpaid and true or false
		-- the screen can open a moment before the ride is marked unpaid: stop any celebration then
		if unpaid and s.ring then s.token = nil s.ring:Stop() end
		for _, st in ipairs(s.stars) do setShown(st, not unpaid) end
		setShown(av, not unpaid)
		setShown(rate.q, not unpaid)
		setShown(rate.note, not unpaid)
		setShown(s.unpaidText, unpaid)
		if unpaid then
			s.title:SetText("Ride ended")
			-- never "saved to your trips" (it isn't), and say plainly what leaving unpaid risks
			-- (payment by mail) after a summon that was never paid, what the rider can still do, in plain words: the
			-- real amount and the driver's whole name. Wuber only says it; the rider sends the mail himself.
			local MailMod = W.Mod("Drive.Mail")
			local mailLine = type(MailMod.RiderLine) == "function" and S(call(MailMod.RiderLine, rv.raw)) or nil
			s.mailLine = mailLine
			s.unpaidText:SetPara("Not paid, so no level progress.\n\n"
				.. T.Code("red") .. "Drivers can block riders who don't pay.|r"
				.. (mailLine and ("\n\n" .. mailLine) or ""))
			rate:SetHeight(math.max(96, (s.unpaidText.paraH or 60) + 48))
			rate:ClearAllPoints()
			rate:SetPoint("TOP", f, "TOP", 0, -88)
			s.habit:Hide()
			sp:Hide()
			fp:Hide()
			s.centreTop()
			return
		end
		rate:SetHeight(198)
		rate:ClearAllPoints()
		rate:SetPoint("TOP", f, "TOP", 0, -112)
		-- what was really paid (the tip included) when the trade said so, else the fare
		local paid = rv.raw and N(rv.raw.paid)
		paid = (paid and paid > 0) and paid or rv.price
		s.title:SetText(rv.dest .. ((paid and paid > 0) and (" · Paid " .. money(paid) .. " to " .. (rv.payto or rv.short)) or ""))
		s.centreTop()
		rate.q:SetText("Thank you for\nriding with " .. rv.short)
		local habit = adv and UI.HabitLine and UI.HabitLine(rv.driverKey) or nil
		if habit then s.habit:SetText(habit) end
		setShown(s.habit, habit ~= nil)
		rate.note:ClearAllPoints()
		rate.note:SetPoint("TOP", rate, "TOP", 0, habit and -152 or -158)
		local saved = rv.saved
		if saved and saved > 0 then
			local how = rv.raw and S(rv.raw.savedHow)
			local about = not (how == "own" or how == "shared")
			s.saved:SetText("You saved " .. (about and "about " or "") .. duration(saved) .. " of flying · saved to your trips")
		else
			s.saved:SetText("Saved to your trips")
		end
		fitPill(sp)
		sp:ClearAllPoints()
		sp:SetPoint("TOP", rate, "BOTTOM", 0, -14)
		sp:Show()
		local fl = adv and UI.FlightLine(rv, true, nil, true) or nil
		-- the short form: "Flying: 23s · this summon really cost 37s" (round 9, S18: with coin icons, under a time)
		if fl then s.flight:SetText((fl:gsub("^Flying here would cost ", "Flying: "))) end
		fitPill(fp)
		fp:ClearAllPoints()
		fp:SetPoint("TOP", sp, "BOTTOM", 0, -8)
		setShown(fp, fl ~= nil)
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
	s.title = T.Text(f, "title", "white", "CENTER", "bold")
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
	alt.kicker = T.Text(alt, "caption", "muted", "LEFT", "bold")
	alt.kicker:SetPoint("TOPLEFT", alt, "TOPLEFT", 16, -14)
	alt.kicker:SetText("Next best to the same place")
	alt.name = T.Text(alt, "body", "white", "LEFT", "bold")
	alt.name:SetPoint("TOPLEFT", alt, "TOPLEFT", 16, -32)
	alt.name:SetWidth(200)
	alt.price = T.Text(alt, "title", "gold", "RIGHT", "bold")
	alt.price:SetPoint("RIGHT", alt, "RIGHT", -16, -6)
	alt:RegisterForClicks("LeftButtonUp")
	safeScript(alt, "OnEnter", function(self) self.bg:SetColor("hover") end)
	safeScript(alt, "OnLeave", function(self) self.bg:SetColor("card") end)
	T.Press(alt, { fill = alt.bg })
	safeScript(alt, "OnClick", function(self)
		local key = self.key
		if not key then return end
		UI.Dismiss(true)
		UI.Show("confirm", key)
	end)
	T.Tip(alt, "Next best driver", "The cheapest other driver going to the same place. Click to book them.")
	alt:Hide()
	s.alt = alt

	s.ask = askPill(f, s)
	s.again = T.MainButton(f, "Try another driver")
	safeScript(s.again, "OnClick", function() UI.Dismiss() end)
	T.Tip(s.again, "Try another driver", "Back to the list of drivers.", "ANCHOR_TOP")

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
			-- (AUD-190) a fare paid by trade can be asked back: "Nothing to pay" would be wrong beside that button
			if UI.RaincheckAskable(rv) then
				s.sub:SetText("Pick another driver when you're ready.")
			else
				s.sub:SetText("Nothing to pay. Pick another driver when you're ready.")
			end
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
		local askable = UI.RaincheckAskable(rv)
		setShown(s.ask, askable)
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

-- internals other modules use (bound at load by later modules, or called late)
Mod.buildDone = buildDone
Mod.buildSorry = buildSorry
