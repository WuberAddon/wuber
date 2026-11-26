-- Module: UI.Rider.Ride
-- Purpose: The Driver-found screen (accepted to paying: steps, invite, portal, arrived, pay) and
--   UI.DoAction. (design 4, C) A back chevron at its top left (s.back) shows Home with the tabs; the ride carries on.
-- API: UI.DoAction, UI.FlexText, UI.RitualText
-- Internals: buildFound, invitePending, buildKitchen, kitchenTick, passTick, verAtLeast, founderLook,
--   fitHeader (Mod.fitHeader)
-- Uses: UI.Kit, UI.Secure, UI.Rider.HomeMap, UI.Rider.Confirm, UI.Rider.Booking
-- Later: UI.Share (the share pill's registration, at run time)
-- Events: listens Listen RITUAL; fires (none)
-- Standalone: no
-- Test: tests/ui/rider/ride_test.lua
-- From: UI.lua 2945-3672 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Rider.Ride", { "UI.Kit", "UI.Secure", "UI.Rider.HomeMap", "UI.Rider.Confirm", "UI.Rider.Booking" })

local KitMod = W.Mod("UI.Kit")
local SecureMod = W.Mod("UI.Secure")
local HomeMapMod = W.Mod("UI.Rider.HomeMap")
local ConfirmMod = W.Mod("UI.Rider.Confirm")
local Booking = W.Mod("UI.Rider.Booking")
local INNER = KitMod.INNER
local N = KitMod.N
local PAD = KitMod.PAD
local RIDE_RANK = KitMod.RIDE_RANK
local S = KitMod.S
local duration = KitMod.duration
local ui = KitMod.ui
local WIN_W = KitMod.WIN_W
local call = KitMod.call
local cancellable = KitMod.cancellable
local inCombat = KitMod.inCombat
local inGroup = KitMod.inGroup
local inGroupWith = KitMod.inGroupWith
local money = KitMod.money
local now = KitMod.now
local ordinal = KitMod.ordinal
local rideView = KitMod.rideView
local safeScript = KitMod.safeScript
local setShown = KitMod.setShown
local doCancel = SecureMod.doCancel
local buildMapPanel = HomeMapMod.buildMapPanel
local updateMap = HomeMapMod.updateMap
local leaveGroup = ConfirmMod.leaveGroup
local tierChip = ConfirmMod.tierChip
local T = W.Theme
local noGlow = T.NoGlow -- (design round 1) the shared no-op glow, Theme.Widgets
local A = T.Animate
local Try = T.Try
local UI = W.UI

-- (design 4, A2) the portal still is drawn square (its soft edge fades to clear, so no square shows) and LARGE: the room the
-- hidden tab bar left. max/min: the size's limits; top: clear of the dark header bar; gap: under it, before the headline;
-- base: the size at which the headline keeps its old place (everything under it moves by size - base); foot: kept free
-- between the last live card and the link; first: before the first fit. min: the size wanted (the tests); a page too full for it
-- gets the largest that fits. The size is worked out from the room each time (Ride.fitHero), never typed per state.
-- (design 4, lead) top is 24, not 8: the rider's own "you" dot of the map strip stands between the header bar and the
-- picture (4 under the bar, 14 high, 6 clear above the picture), so nothing is hidden to make the picture fit; base follows
-- (44 = 60 less the 16 the picture moved down), so the headline is still 8 under the picture.
local PORTAL = { max = 200, min = 104, top = 24, gap = 8, base = 44, foot = 6, first = 88 }
local PORTAL_TURN = 8 -- seconds for one full turn (the approved preview)
local STEPS = { "Accepted", "Invite", "Portal", "Arrived", "Pay" }
local REACHED = { accepted = 1, invited = 2, ingroup = 2, summoning = 3, portal = 3, arrived = 4, paying = 5, done = 5 }
local STEP_X0, STEP_GAP = 34, 73
-- (design 3) with no second line under the live title (display, about 34 high) the steps row rises by this much, not more:
-- it keeps 8 under the title's bottom (the title's top is HEAD_H + 78, the steps are HEAD_H + 144 with a line)
local NO_SUB_LIFT = 24
-- (design 4, C) the back chevron at the top left, as on the pushed pages (Confirm's size, place and tooltip): Back
-- shows Home with the tabs and leaves the ride alone (UI.Show("home")); the black pill opens this page again. left:
-- where the level chip's room (live look) and the warning (pay look) start, 8 after it; the title (pay look) follows
-- it by 12; row: what the chevron's row adds to the live look's dark bar (the route has the row under it).
local BACK = { size = 36, x = 16, y = 10, gap = 8, title = 12, row = 36, tip = { "Back", "Back to the list of drivers." } }
BACK.left = BACK.x + BACK.size + BACK.gap
-- (round 13, I16) the dark bar over the portal: the route and the level chip. (design 4, C) Two rows now: the back
-- chevron, the level chip and the window's x, then the route with the whole width to itself; the page has the room
-- (the tab bar is away while it shows), and neither the route nor the chip gives way to the chevron.
local HEAD_H = 44 + BACK.row

-- (round 13, I16) the route and the level chip share the bar. (design 4, C) Each has a row: the route the lower one,
-- as wide as the page's content; the chip the upper one, between the back chevron and the window's x. A chip that
-- is wider than that room says just the level ("Silver"); when that still doesn't fit, it steps aside (the pay look
-- shows it by the title).
-- (design 2, C) the bar ends before the window's x. A ride under way shows the x alone, as the mockup draws it:
-- the cog steps aside while this screen shows (UI.HeadPush; Settings is a tab away).
local function headRight() return (UI.HeadRoom and N(UI.HeadRoom("x")) or 48) + 4 end
local function fitHeader(s, rv)
	local route, chip = s.route, s.tier
	route:SetMaxWidth(INNER)
	route:Update(rv.dest)
	if not chip:IsShown() then return end
	local room = WIN_W - BACK.left - headRight()
	if (N(chip:GetWidth()) or 90) <= room then return end
	local t = math.max(0, math.min(3, math.floor(type(W.Tier) == "function" and N(call(W.Tier)) or 0)))
	local look = T.TIER[t]
	if t >= 1 and look then chip:SetChip(type(W.TierName) == "function" and S(call(W.TierName, t)) or look.name, look.colour) end
	if (N(chip:GetWidth()) or 90) > room then chip:Hide() end
end
Mod.fitHeader = fitHeader

-- A group invite is waiting in the game's invite box (and Wuber didn't accept it for you).
local function invitePending(rv)
	if rv and rv.raw and W.Plain(rv.raw.autoAccepted) == true and inGroup() then return false end
	if type(StaticPopup_FindVisible) ~= "function" then return true end
	return call(StaticPopup_FindVisible, "PARTY_INVITE") ~= nil
end

-- A trade window is open (the Found screen then says exactly what to type).
local function tradeOpen()
	if W.tradeOpen then return true end
	local f = TradeFrame
	if type(f) ~= "table" or type(f.IsShown) ~= "function" then return false end
	return W.Plain(call(f.IsShown, f)) == true
end

local function foundTexts(rv)
	local who, dest, price = rv.short, rv.dest, money(UI.PayTotal(rv))
	local payto = rv.payto or who
	local st = rv.state
	if rv.portalUp then
		local blank = rv.raw and W.Plain(rv.raw.summonNoName) == true
		local sub = blank and ((rv.summoner or who) .. " is summoning you to " .. dest) or ("Ready to teleport to " .. dest)
		return "The portal is up", sub,
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
		return "You're in the group", "",
			"Stay put", "Accept the portal when it pops up."
	elseif st == "summoning" then
		return "Your summon is under way", "Your portal to " .. dest .. " is coming.",
			"Almost there", "When the summon window shows, accept it."
	elseif st == "arrived" then
		return "You've arrived", "Welcome to " .. dest .. ".",
			(rv.payto and ("Pay " .. payto .. " " .. price) or ("Trade " .. who .. " " .. price)),
			payto .. " opens a trade. Put " .. price .. " in and accept."
	elseif st == "paying" then
		return "Time to pay", "Put " .. price .. " in the trade window" .. (rv.payto and (" for " .. payto) or "") .. ".",
			(rv.payto and ("Pay " .. payto .. " " .. price) or ("Trade " .. who .. " " .. price)), "Put " .. price .. " in the trade window and click Trade."
	end
	return "On the way", "", "", ""
end

---------------------------------------------------------------------------
-- Round 8: the live portal tracker (5.10), the passphrase (5.7), the founder's gold
-- ring (5.13) and the arrival share line (5.12)
---------------------------------------------------------------------------

-- "2.3.0" >= "2.2.1"
local function verAtLeast(v, want)
	v = S(v)
	if not v then return false end
	local a, b = {}, {}
	for n in v:gmatch("%d+") do a[#a + 1] = tonumber(n) end
	for n in want:gmatch("%d+") do b[#b + 1] = tonumber(n) end
	for i = 1, math.max(#a, #b) do
		local x, y = a[i] or 0, b[i] or 0
		if x ~= y then return x > y end
	end
	return true
end
Mod.verAtLeast = verAtLeast

-- The tracker's line for the ride's last G (W.ride.ritual = { phase, tapped, need, caster }):
-- text, tapped, need; nil when there is nothing live to say.
function UI.RitualText(rv)
	local r = rv and rv.raw
	local g = r and r.ritual
	if type(g) ~= "table" then return nil end
	local phase = S(g.phase)
	local tapped, need = math.max(0, math.min(9, N(g.tapped) or 0)), math.max(0, math.min(9, N(g.need) or 2))
	local caster = S(g.caster) and W.Short(S(g.caster)) or rv.short
	if phase == "q" then
		local pos = N(rv.position)
		return "In the queue" .. ((pos and pos >= 1) and (" · " .. ordinal(pos)) or ""), 0, need
	elseif phase == "t" then
		return caster .. " is getting ready", 0, need
	elseif phase == "c" then
		return "Opening rift...", 0, need
	elseif phase == "h" then
		return "Opening rift... " .. tapped .. "/" .. need .. " clickers tapped", tapped, need
	elseif phase == "s" then
		return "Summon sent - accept it!", need, need
	elseif phase == "f" then
		return "The rift closed - trying again", 0, need
	end
	return nil
end

-- the tracker card: one line and a pip per clicker (lit by alpha, never scale)
local function buildKitchen(f)
	local k = T.Card(f, INNER, 36, { colour = { 0.17, 0.12, 0.27, 1 }, radius = 18, shadow = false })
	k.icon = T.Icon(k, "portal", 18, "glow", "ARTWORK")
	k.icon:SetPoint("LEFT", k, "LEFT", 14, 0)
	k.text = T.Text(k, "sub", "white", "LEFT", "bold")
	k.text:SetPoint("LEFT", k.icon, "RIGHT", 9, 0)
	k.text:SetWidth(INNER - 100)
	k.pips = {}
	for i = 1, 2 do
		local pip = T.Circle(k, 12, "glow", "ARTWORK")
		pip:SetPoint("RIGHT", k, "RIGHT", -14 - (2 - i) * 18, 0)
		pip:SetAlpha(0.25)
		k.pips[i] = pip
	end
	k:EnableMouse(true)
	T.Tip(k, "The summon, live", "Your driver's Wuber says how the summon is going: the caster, then each helper's click on the portal.")
	k:Hide()
	return k
end

local function kitchenTick(s, rv)
	local k = s.kitchen
	if not W.Advanced() then
		if k:IsShown() then k:Hide() end
		return false
	end
	local text, tapped, need
	if rv and rv.rank >= RIDE_RANK.accepted and rv.rank < RIDE_RANK.arrived then text, tapped, need = UI.RitualText(rv) end
	if not text then
		if k:IsShown() then k:Hide() end
		return false
	end
	k.text:SetText(text)
	for i, pip in ipairs(k.pips) do
		local lit = i <= (tapped or 0)
		setShown(pip, i <= (need or 2))
		local want = lit and 1 or 0.25
		if pip.want ~= want then
			pip.want = want
			if T.FxLevel() == "off" or not k:IsVisible() then
				pip:SetAlpha(want)
			else
				T.Tween(pip, N(pip:GetAlpha()) or 0.25, want, function(p, v) p:SetAlpha(v) end)
			end
		end
	end
	if not k:IsShown() then A.FadeIn(k, 0.2) end
	return true
end

-- "Passphrase: Violet Otter" once in the driver's group,
-- only when the driver shows it (round 9: the driver's "Show ride passphrase", off by default;
-- the flag is cached on the ride, W.ride.showPass, so the line stays when the driver's entry goes).
local function passTick(s, rv)
	local words
	if rv and rv.rank >= RIDE_RANK.ingroup and rv.rank < RIDE_RANK.arrived and type(W.Passphrase) == "function" then
		if rv.raw and rv.raw.showPass == true then words = S(call(W.Passphrase, rv.id, W.myKey)) end
	end
	setShown(s.pass, words ~= nil)
	setShown(s.passHit, words ~= nil)
	if words then s.pass:SetText("Passphrase: " .. T.Code("white") .. words .. "|r") end
	s.passWords = words
end

-- the gold rune ring for a genuine founder's summon (W.FounderSummon; any doubt: violet)
local function founderLook(hero, rv)
	local gold = rv and type(W.FounderSummon) == "function" and call(W.FounderSummon, rv.raw) == true or false
	if hero.gold == gold then return end
	hero.gold = gold
	if hero.runesSet then hero.runes:SetTexture(T.MEDIA .. (gold and "fx\\runes_gold" or "fx\\runes")) end
	hero.runes:SetVertexColor(T.RGB(gold and "gold" or "glow"))
	hero.runes:SetAlpha(gold and 0.55 or 0.4) -- strength by region alpha, never the colour's
	hero.glow:SetVertexColor(T.RGB(gold and "gold" or "accent", 0.9))
	-- the same still, desaturated and tinted with the gold token (design 4, A)
	Try(hero.art, "SetDesaturated", gold)
	hero.art:SetVertexColor(T.RGB(gold and "gold" or "white"))
end

-- The arrival share line (5.12): "Summoned to Undercity by Anita with Wuber - 9 min saved."
-- (the time only when known; a time worked out, not timed, says about). No price, no link, no "gold".
function UI.FlexText(rv)
	if not rv or not S(rv.dest) then return nil end
	local who = rv.summoner or rv.short
	local line = "Summoned to " .. rv.dest .. " by " .. who .. " with Wuber"
	local saved = N(rv.saved)
	if saved and saved >= 60 then
		local how = rv.raw and S(rv.raw.savedHow)
		local about = not (how == "own" or how == "shared")
		line = line .. " - " .. (about and "about " or "") .. duration(saved) .. " saved"
	end
	line = line .. "."
	if type(W.SentenceSpam) == "function" and call(W.SentenceSpam, line) then return nil end
	return W.Clean(line, 240)
end

-- Found (accepted to paying). Two looks (the author's picks):
--   on the way (03 v1): a live portal over the top, the title and line centred, the steps,
--     the driver, then one amber safety card when the summoner is somewhere else, and the
--     big Accept summon;
--   arrived (04 v1): the title over the map strip, the steps, then the pay card: TYPE IN TRADE
--     WINDOW, the exact silver big and gold, the fare and tip, the tip buttons (No tip, 10%,
--     20%, Custom: the stops 0 to 100%), what flying would have cost; then a status pill with a
--     spinner until the trade opens. A stranger's trade puts the amber card over the title.
local function buildFound(body)
	local s = { frame = CreateFrame("Frame", nil, body) }
	local f = s.frame
	f:SetAllPoints(body)
	f:Hide()
	if UI.HeadPush then
		UI.HeadPush(f)
		f:HookScript("OnShow", function() pcall(UI.HeadPush) end)
		f:HookScript("OnHide", function() pcall(UI.HeadPush) end)
	end
	-- the map strip behind the title: you, the drivers, and the route to where you're going
	s.map = buildMapPanel(f, 156, 156)
	s.map.strip = true
	-- (design 4, X2) the dark header bar is two rows tall: the you dot stands 4 clear under its lower edge (half its 14, then 4)
	s.map.meMin = HEAD_H + 2 + 4 + 7
	s.map.zone:Hide()
	s.map.net:Hide()
	s.map:SetAlpha(0.85)
	local head = CreateFrame("Frame", nil, f)
	head:SetAllPoints(f)
	head:SetFrameLevel(s.map:GetFrameLevel() + 12)
	s.head = head

	-- the live portal (on the way): a glow, a slow rune ring and the portal flipbook
	-- (a flat ring, as seen from the side: sized, never scale-animated; the flipbook turns it)
	-- (round 13, I16: under the dark header bar, clear of the route and the level chip)
	local hero = CreateFrame("Frame", nil, head)
	hero:SetSize(220, PORTAL.first)
	hero:SetPoint("TOP", f, "TOP", 0, -(HEAD_H + 2 + PORTAL.top)) -- (design 4, A2) the picture's top is PORTAL.top under the dark header bar, clear of the you dot
	hero.glow = noGlow() -- (design 1) the portal has no glow behind it; founderLook still colours it
	-- the rune ring is an effect sheet: its file is set the first time the portal shows (lazy)
	hero.runes = hero:CreateTexture(nil, "ARTWORK")
	hero.runes:SetSize(224, 80)
	hero.runes:SetPoint("CENTER", hero, "CENTER")
	hero.runes:SetVertexColor(T.RGB("glow"))
	hero.runes:SetAlpha(0.4)
	Try(hero.runes, "SetBlendMode", "ADD")
	-- (design 4, A) the portal is ONE still picture (media/portal_still, made by tools/art/still.py) that the game
	-- turns in place: one full turn every PORTAL_TURN seconds, anticlockwise (A.Spin works the angle out from the
	-- clock). A founder's summon is the same picture, desaturated and tinted gold. No flipbook, no second file.
	hero.runes:Hide() -- the flat rune ring does not sit behind a round picture
	hero.art = hero:CreateTexture(nil, "ARTWORK", nil, 1)
	hero.art:SetSize(PORTAL.first, PORTAL.first) -- Ride.fitHero sets the size from the room
	hero.art:SetPoint("TOP", hero, "TOP", 0, 0)
	hero.art:SetTexture(T.MEDIA .. "portal_still")
	hero.art:SetBlendMode("BLEND")
	hero.spin = A.Spin(hero.art, PORTAL_TURN, false)
	-- Reduce motion (or effects off) stops the turn: the picture stands upright; it turns again when the switch goes off
	hero:SetScript("OnUpdate", function()
		local still = (T.ReduceMotion and T.ReduceMotion()) or (T.FxLevel and T.FxLevel() == "off")
		if still then
			if hero.spin.driver and hero.spin.driver:IsShown() then hero.spin:Stop() end
			Try(hero.art, "SetRotation", 0)
		elseif hero.spin.driver and not hero.spin.driver:IsShown() then
			hero.spin:Start()
		end
	end)
	s.hero = hero

	s.title = T.Text(head, "title", "white", "LEFT", "bold")
	s.title.wuberSpare = 1.06 -- (round 13, I18) fitted with spare ('Your summon is under way' was cut)
	s.title:SetWidth(INNER - 100)
	s.sub = T.Text(head, "body", "muted", "LEFT", "regular")
	s.sub:SetWidth(INNER)
	Try(s.sub, "SetWordWrap", true)
	-- (round 13, I16) the route and the level chip on a dark bar of their own above the portal:
	-- never on its bright glow, the route's start never cut to "Or..."
	local bar = CreateFrame("Frame", nil, head)
	bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	bar:SetHeight(HEAD_H + 2) -- (design 2, C) the window's buttons lie on it, whole
	bar:SetFrameLevel((N(hero:GetFrameLevel()) or 0) + 6)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints(bar)
	bar.bg:SetColorTexture(0.07, 0.06, 0.13, 0.97)
	bar.fade = T.Tex(bar, "fade", "BACKGROUND", 1)
	bar.fade:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
	bar.fade:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	bar.fade:SetHeight(10)
	bar.fade:SetVertexColor(0.07, 0.06, 0.13, 0.9)
	s.bar = bar
	s.tier = tierChip(head)
	s.tier:SetPoint("TOPRIGHT", f, "TOPRIGHT", -headRight(), -24)
	s.tier:SetFrameLevel((N(bar:GetFrameLevel()) or 0) + 2)

	-- the progress line
	local prog = CreateFrame("Frame", nil, head)
	prog:SetSize(WIN_W, 50)
	prog:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -100)
	s.prog = prog
	-- a dark band under the stepper: the map's route dots never run behind its labels
	prog.fade = T.Tex(prog, "fade", "BACKGROUND", -3)
	prog.fade:SetPoint("BOTTOMLEFT", prog, "TOPLEFT", 0, -2)
	prog.fade:SetPoint("BOTTOMRIGHT", prog, "TOPRIGHT", 0, -2)
	prog.fade:SetHeight(22)
	prog.fade:SetVertexColor(T.RGB("black", 0.96))
	prog.band = prog:CreateTexture(nil, "BACKGROUND", nil, -3)
	prog.band:SetColorTexture(T.RGB("black", 0.96))
	prog.band:SetPoint("TOPLEFT", prog, "TOPLEFT", 0, -2)
	prog.band:SetPoint("BOTTOMRIGHT", prog, "BOTTOMRIGHT", 0, 0)
	local track = prog:CreateTexture(nil, "BACKGROUND")
	track:SetColorTexture(T.RGB("line"))
	track:SetHeight(3)
	track:SetPoint("LEFT", prog, "TOPLEFT", STEP_X0, -8)
	track:SetWidth(STEP_GAP * 4)
	s.fill = prog:CreateTexture(nil, "BORDER")
	s.fill:SetTexture(T.MEDIA .. "hgrad")
	s.fill:SetHeight(4)
	s.fill:SetPoint("LEFT", prog, "TOPLEFT", STEP_X0, -8)
	s.fill:SetWidth(1)
	s.fillCur, s.fillTarget = 0, 0
	s.nodes = {}
	for i, name in ipairs(STEPS) do
		local n = CreateFrame("Frame", nil, prog)
		n:SetSize(16, 16)
		n:SetPoint("CENTER", prog, "TOPLEFT", STEP_X0 + (i - 1) * STEP_GAP, -8)
		n.dot = T.Circle(n, 14, "line", "ARTWORK")
		n.dot:SetPoint("CENTER", n, "CENTER")
		n.pulse = A.Pulse(n, { size = 34, colour = "magenta", alpha = 0.6, period = 1.6, rings = 2, start = false })
		n.label = T.Text(prog, "caption", "muted", "CENTER", "medium")
		n.label:SetPoint("TOP", n, "BOTTOM", 0, -12) -- (ING-09) the pulse ring reaches 9 under the node: the words start clear of it
		n.label:SetText(name)
		s.nodes[i] = n
	end

	-- the driver
	local card = T.Card(f, INNER, 66, { colour = "card", radius = 16 })
	card.avatar = T.Circle(card, 44, "accent", "ARTWORK")
	card.avatar:SetPoint("LEFT", card, "LEFT", 14, 0)
	card.glyph = T.Icon(card, "summon", 24, "ink", "OVERLAY")
	card.glyph:SetPoint("CENTER", card.avatar, "CENTER")
	card.name = T.Text(card, "body", "white", "LEFT", "bold")
	card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 70, -15)
	card.name:SetWidth(160)
	card.service = T.Text(card, "sub", "muted", "LEFT", "regular")
	card.service:SetPoint("TOPLEFT", card, "TOPLEFT", 70, -37)
	card.service:SetWidth(160)
	card.price = T.Text(card, "title", "gold", "RIGHT", "bold")
	card.price:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -13)
	card.dest = T.Text(card, "caption", "muted", "RIGHT", "regular")
	card.dest:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -39)
	card.dest:SetWidth(90)
	s.card = card

	-- your place in the driver's queue and a live countdown
	local q = T.Card(f, INNER, 36, { colour = { 0.17, 0.12, 0.27, 1 }, radius = 18, shadow = false })
	q.icon = T.Icon(q, "clock", 18, "glow", "ARTWORK")
	q.icon:SetPoint("LEFT", q, "LEFT", 14, 0)
	q.text = T.Text(q, "sub", "white", "LEFT", "bold")
	q.text:SetPoint("LEFT", q.icon, "RIGHT", 9, 0)
	q.text:SetWidth(INNER - 110)
	q.clock = T.Text(q, "body", "white", "RIGHT", "bold")
	q.clock:SetPoint("RIGHT", q, "RIGHT", -16, 0)
	q:EnableMouse(true)
	T.Tip(q, "Your place in line", "Riders ahead of you are summoned first. The time counts down as the driver works through the line.")
	q:Hide()
	s.queue = q

	-- what to do now (on the way, before the portal)
	local tip = T.Card(f, INNER, 70, { colour = "panel", radius = 16, shadow = false, border = "line" })
	tip.head = T.Text(tip, "body", "white", "LEFT", "bold")
	tip.head:SetPoint("TOPLEFT", tip, "TOPLEFT", 16, -14)
	tip.head:SetWidth(INNER - 32)
	tip.body = T.Text(tip, "sub", "muted", "LEFT", "regular")
	tip.body:SetPoint("TOPLEFT", tip.head, "BOTTOMLEFT", 0, -5)
	tip.body:SetWidth(INNER - 32)
	Try(tip.body, "SetWordWrap", true)
	Try(tip.body, "SetMaxLines", 2)
	s.tip = tip

	-- the amber safety card: the map check before Accept summon (review #26: a warning, never a
	-- block), or a stranger's trade while you pay
	s.alert = T.AlertCard(head, INNER, 72)
	s.alert:EnableMouse(true)
	T.Tip(s.alert, function() return s.alertTitle end, function() return s.alertTip end, "ANCHOR_TOP")
	s.alert:Hide()
	-- round 8: the route header (live look), the live tracker, the passphrase, the share pill
	s.route = Booking.RouteHeader(head, INNER - 120)
	s.route:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(BACK.y + BACK.size + 2)) -- (design 4, C) the row under the chevron
	s.route:SetFrameLevel((N(s.bar:GetFrameLevel()) or 0) + 2)
	s.back = T.RoundButton(head, "back", BACK.size, "card")
	s.back:SetPoint("TOPLEFT", f, "TOPLEFT", BACK.x, -BACK.y)
	s.back:SetFrameLevel((N(s.bar:GetFrameLevel()) or 0) + 3)
	safeScript(s.back, "OnClick", function() UI.Show("home") end)
	T.Tip(s.back, BACK.tip[1], BACK.tip[2])
	s.kitchen = buildKitchen(f)
	s.pass = T.Text(f, "caption", "white", "CENTER", "medium")
	s.pass:SetPoint("TOP", f, "TOP", 0, -(HEAD_H + 350))
	s.pass:SetWidth(INNER)
	s.pass:Hide()
	s.passHit = CreateFrame("Frame", nil, f)
	s.passHit:SetAllPoints(s.pass)
	s.passHit:EnableMouse(true)
	T.Tip(s.passHit, "Passphrase", "Your driver sees the same words.")
	s.passHit:Hide()
	s.share = T.Pill(head, "Share", "dark", 92, 30)
	s.share:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -((UI.HEAD_ROW or 44) + 4)) -- (design 2, C) under the window's buttons (the chip's corner)
	safeScript(s.share, "OnClick", function()
		-- only reached when the secure share button isn't over it (combat, not grouped)
		UI.Toast(inCombat() and "Share after combat" or "Join a group to share", "info")
	end)
	T.Tip(s.share, "Share", function() return s.shareLine and ("Posts to your group: \"" .. s.shareLine .. "\"") or "Posts one line to your party." end)
	s.share:Hide()
	if UI.Share and type(UI.Share.Register) == "function" then
		pcall(UI.Share.Register, s.share, function() return W.Advanced() and s.shareLine or nil end, { label = "Share", onShared = function()
			local rv = rideView()
			if rv then ui.flexShared = ui.flexShared or {} ui.flexShared[rv.id] = true end
			s.shareLine = nil
			UI.Refresh(true)
		end })
	end

	-- the pay card (arrived)
	local pc = T.Card(f, INNER, 216, { colour = "card", radius = 20, border = "line" })
	pc:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -160)
	pc.kicker = T.Text(pc, "caption", "muted", "CENTER", "bold")
	pc.kicker:SetPoint("TOP", pc, "TOP", 0, -18)
	pc.kicker:SetText("Type in trade window")
	pc.big = T.Text(pc, "hero", "gold", "CENTER", "bold")
	pc.big:SetPoint("TOP", pc, "TOP", 0, -34)
	pc.big:SetWidth(INNER - 24)
	pc.sub = T.Text(pc, "sub", "muted", "CENTER", "regular")
	pc.sub:SetPoint("TOP", pc, "TOP", 0, -102)
	pc.sub:SetWidth(INNER - 28)
	pc.band = pc:CreateTexture(nil, "BACKGROUND", nil, 2)
	pc.band:SetColorTexture(T.RGB("black", 0.18))
	pc.band:SetPoint("TOPLEFT", pc, "TOPLEFT", 1, -126)
	pc.band:SetPoint("TOPRIGHT", pc, "TOPRIGHT", -1, -126)
	pc.band:SetHeight(1)
	pc.flight = T.Text(pc, "caption", "muted", "CENTER", "regular")
	pc.flight:SetPoint("TOP", pc, "TOP", 0, -198)
	pc.flight:SetWidth(INNER - 24)
	pc:EnableMouse(true)
	T.Tip(pc, "What to type", "When the trade opens, type this much in the trade window's money box yourself and click Trade. "
		.. "The game only lets you put gold in a trade.")
	-- (round 20, B7) a stranger's trade: the card is dimmed under the warning. A separate shaded card
	-- that is Shown/Hidden on every tick (a texture's alpha set at build did not take in the client)
	pc.dim = T.Card(pc, INNER, 216, { colour = { 0.06, 0.05, 0.14, 0.7 }, radius = 20, shadow = false })
	pc.dim:SetAllPoints(pc)
	pc.dim:SetFrameLevel(pc:GetFrameLevel() + 30)
	pc.dim:Hide()
	pc:Hide()
	s.pay = pc

	-- the tip buttons: a rounded key with one or two lines, violet when chosen
	local KEY_W, KEY_H, KEY_GAP = (INNER - 28 - 3 * 8) / 4, 52, 8
	local function tipKey(parent, w, h)
		local b = CreateFrame("Button", nil, parent)
		b:SetSize(w, h)
		b.edge = T.Rounded(b, "line", 13, "BACKGROUND", 0, 1)
		b.bg = T.Rounded(b, "panel", 12, "BACKGROUND", 1)
		b.top = T.Text(b, "body", "white", "CENTER", "bold")
		b.top:SetWidth(w - 8)
		b.bottom = T.Text(b, "caption", "white", "CENTER", "regular")
		b.bottom:SetWidth(w - 8)
		b:RegisterForClicks("LeftButtonUp")
		function b.Paint(self, top, bottom, on)
			self.on = on and true or false
			self.top:SetText(top or "")
			self.bottom:SetText(bottom or "")
			self.top:ClearAllPoints()
			if bottom and bottom ~= "" then
				self.top:SetPoint("CENTER", self, "CENTER", 0, 8)
				self.bottom:SetPoint("CENTER", self, "CENTER", 0, -9)
				self.bottom:Show()
			else
				self.top:SetPoint("CENTER", self, "CENTER", 0, 0)
				self.bottom:Hide()
			end
			self.bg:SetColor(self.on and "glow" or (self.hover and "hover" or "panel"))
			self.edge:SetColor(self.on and "glow" or "line")
			local tc = self.on and "ink" or "white"
			self.top:SetTextColor(T.RGB(tc))
			self.bottom:SetTextColor(T.RGB(self.on and "ink" or "muted"))
		end
		safeScript(b, "OnEnter", function(self) self.hover = true if not self.on then self.bg:SetColor("hover") end end)
		safeScript(b, "OnLeave", function(self) self.hover = nil if not self.on then self.bg:SetColor("panel") end end)
		T.Press(b, { fill = b.bg })
		return b
	end
	s.tipKeys = {}
	for i = 1, 4 do
		local b = tipKey(pc, KEY_W, KEY_H)
		b:SetPoint("TOPLEFT", pc, "TOPLEFT", 14 + (i - 1) * (KEY_W + KEY_GAP), -136)
		b.pct = UI.TIP_QUICK[i]
		safeScript(b, "OnClick", function(self)
			if self.pct then
				s.picking = false
				UI.SetTipPct(self.pct)
			else
				s.picking = not s.picking
				UI.Refresh(true)
			end
		end)
		s.tipKeys[i] = b
	end
	T.Tip(s.tipKeys[1], "No tip", "Pay the fare only. You can always tip next time.")
	T.Tip(s.tipKeys[2], "10% tip", "Add 10% for your Warlock, rounded up to whole silver. Wuber remembers your choice.")
	T.Tip(s.tipKeys[3], "20% tip", "Add 20% for your Warlock, rounded up to whole silver. Wuber remembers your choice.")
	T.Tip(s.tipKeys[4], "Custom tip", "Pick any tip from 0 to 100%, rounded up to whole silver. Wuber remembers your choice.")
	-- Custom: every stop, 0 to 100%
	local pick = CreateFrame("Frame", nil, pc)
	pick:SetPoint("TOPLEFT", pc, "TOPLEFT", 10, -130)
	pick:SetPoint("TOPRIGHT", pc, "TOPRIGHT", -10, -130)
	pick:SetHeight(84)
	pick:SetFrameLevel((N(pc:GetFrameLevel()) or 0) + 6)
	pick:EnableMouse(true)
	pick.bg = T.Rounded(pick, "hover", 14, "BACKGROUND", 0)
	pick.keys = {}
	local PW = (INNER - 20 - 12 - 4 * 6) / 5
	for i, pct in ipairs(UI.TIP_STOPS) do
		local b = tipKey(pick, PW, 34)
		local col, rowN = (i - 1) % 5, math.floor((i - 1) / 5)
		b:SetPoint("TOPLEFT", pick, "TOPLEFT", 6 + col * (PW + 6), -6 - rowN * 38)
		b.pct = pct
		if pct == 0 then
			T.Tip(b, "No tip", "Leave no tip. Wuber remembers your choice.")
		else
			T.Tip(b, pct .. "% tip", "Add " .. pct .. "% for your Warlock, rounded up to whole silver. Wuber remembers your choice.")
		end -- (AU24-33)
		safeScript(b, "OnClick", function(self)
			s.picking = false
			UI.SetTipPct(self.pct)
		end)
		pick.keys[i] = b
	end
	pick:Hide()
	s.pick = pick

	function s.tipTick(rv)
		local want = rv and (rv.state == "arrived" or rv.state == "paying") and (rv.price or 0) > 0
			and not (rv.raw and (rv.raw.paid or rv.raw.unpaid))
		local price = rv and N(rv.price) or 0
		local pct = UI.TipPct()
		local custom = pct ~= 0 and pct ~= 10 and pct ~= 20
		local showCustom = W.Advanced() or custom
		if not showCustom then s.picking = false end
		local cols = showCustom and 4 or 3
		local kw = (INNER - 28 - (cols - 1) * KEY_GAP) / cols
		for i, b in ipairs(s.tipKeys) do
			local show = want and (i < 4 or showCustom)
			if show then
				b:SetSize(kw, KEY_H)
				b.top:SetWidth(kw - 8)
				b.bottom:SetWidth(kw - 8)
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", pc, "TOPLEFT", 14 + (i - 1) * (kw + KEY_GAP), -136)
			end
			if b.pct then
				local t = UI.TipFor(price, b.pct)
				b:Paint(b.pct == 0 and "No tip" or (b.pct .. "%"), b.pct > 0 and ("(+" .. money(t) .. ")") or nil, pct == b.pct)
			else
				if custom then
					b:Paint(pct .. "%", "(+" .. money(UI.TipFor(price, pct)) .. ")", true)
				else
					b:Paint("Custom", nil, s.picking)
				end
			end
			setShown(b, show)
		end
		for _, b in ipairs(s.pick.keys) do
			b:Paint(b.pct == 0 and "None" or (b.pct .. "%"), nil, b.pct == pct)
		end
		setShown(s.pick, want and showCustom and s.picking)
		return want
	end

	-- one line over the button: kept for the tooltip of the map check (the card says it now)
	s.action = T.MainButton(f, "") -- (Design 2) the one main button's place
	safeScript(s.action, "OnClick", function(self)
		if self.inactive or not self.what then return end
		UI.DoAction(self.what)
	end)
	-- a spinner while Wuber waits (the trade, the invite, the portal)
	s.spin = T.Icon(s.action, "arc", 22, "glow", "OVERLAY")
	s.spin:Hide()
	s.cancel = T.Pill(f, "Cancel ride", "ghost", INNER, 40)
	s.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, T.MAIN.foot + T.MAIN.h + 8) -- a link above the main button
	s.cancel.label:SetTextColor(T.RGB("muted"))
	safeScript(s.cancel, "OnClick", function() doCancel(false) end)
	-- (AU24-17, as AUD-190) once part or all of the fare is paid, "Nothing to pay" would be wrong
	T.Tip(s.cancel, "Cancel ride", function()
		local rv = rideView()
		local raw = rv and type(rv.raw) == "table" and rv.raw or {}
		if (N(raw.paid) or 0) > 0 or (N(raw.paidSoFar) or 0) > 0 then
			return "Stop this ride before the summon. You have already paid some or all of the fare."
		end
		return "Stop this ride before the summon. Nothing to pay."
	end, "ANCHOR_TOP")
	-- after arriving (no trade came, or paid another way): end the ride here
	s.endRide = T.Pill(f, "End ride", "ghost", INNER, 40)
	s.endRide:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, T.MAIN.foot + T.MAIN.h + 8)
	s.endRide.label:SetTextColor(T.RGB("muted"))
	safeScript(s.endRide, "OnClick", function()
		if type(W.EndRide) == "function" then call(W.EndRide, "rider") end
	end)
	T.Tip(s.endRide, "End ride", "Finish this ride without paying through Wuber, e.g. if you already paid or the driver waived it.", "ANCHOR_TOP")
	s.endRide:Hide()
	T.Tip(s.action, function(self) return self.label:GetText() end, function(self)
		if self.what == "summon" then return "Accepts the summon: you're on your way." end
		if self.what == "invite" then return "Joins the driver's group so they can summon you." end
		if self.what == "pay" then return "Puts the cursor in the trade's money box and tells you exactly what to type. The game only lets you put gold in a trade yourself." end
		if self.what == "leave" then return "Leave your group so the driver can invite you." end
		return "Wuber follows each step for you."
	end, "ANCHOR_TOP")

	-- (design 4, A2) where a live-look item sits: it sat n under the header zone before the portal grew; now it is
	-- s.drop lower (the portal's size less its old room), and still rises by NO_SUB_LIFT when there is no second line
	-- (plain: the title and its line, which do not rise). The pay look keeps the old places (drop 0).
	s.drop = PORTAL.first - PORTAL.base
	local function liveY(n, plain)
		local live = s.mode == "live"
		local lift = (not plain and live and not s.sub:IsShown()) and NO_SUB_LIFT or 0
		return -(HEAD_H + n + (live and s.drop or 0)) + lift
	end

	-- the two looks: "live" (on the way) or "pay" (arrived)
	function s.layout(mode)
		if s.mode == mode then return end
		s.mode = mode
		local live = mode == "live"
		setShown(hero, live)
		s.map:SetAlpha(live and 0.3 or 0.85)
		s.title:ClearAllPoints()
		s.sub:ClearAllPoints()
		if live then
			T.SetFont(s.title, "display", "bold")
			s.title:SetJustifyH("CENTER")
			s.title:SetWidth(INNER)
			s.title:SetPoint("TOP", f, "TOP", 0, liveY(78, true))
			s.sub:SetJustifyH("CENTER")
			s.sub:SetPoint("TOP", f, "TOP", 0, liveY(110, true))
			prog:ClearAllPoints()
			prog:SetPoint("TOPLEFT", f, "TOPLEFT", 0, liveY(144, true))
			card:ClearAllPoints()
			card:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, liveY(192, true))
		else
			T.SetFont(s.title, "title", "bold")
			s.title:SetJustifyH("LEFT")
			s.title:SetWidth(WIN_W - BACK.x - BACK.size - BACK.title - headRight())
			s.title:SetPoint("LEFT", s.back, "RIGHT", BACK.title, 0)
			s.sub:SetJustifyH("LEFT")
			s.sub:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -54)
			prog:ClearAllPoints()
			prog:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -102)
		end
		setShown(prog.fade, not live)
		setShown(prog.band, not live)
		if live and not hero.runesSet then
			hero.runes:SetTexture(T.MEDIA .. (hero.gold and "fx\\runes_gold" or "fx\\runes"))
			hero.runesSet = true
		end
		setShown(s.route, live)
		setShown(s.bar, live)
		s.tier:ClearAllPoints()
		-- (design 2, C) live: in the bar's upper row, left of the window's buttons; else under them, beside the second line
		if live then
			s.tier:SetPoint("RIGHT", f, "TOPRIGHT", -headRight(), -(BACK.y + BACK.size / 2)) -- (design 4, C) on the chevron's line
		else
			s.tier:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -((UI.HEAD_ROW or 44) + 4))
		end
	end

	function s.enter()
		s.reached = nil
		s.picking = false
		if s.mode ~= "pay" then A.Pop(card, 0.34) end
	end

	function s.leaveScreen()
		for _, n in ipairs(s.nodes) do n.pulse:Stop() end
		if s.spin.wuberSpin then s.spin.wuberSpin:Stop() end
		-- (AUD-114: hidden, so the next update shows it again and restarts the spin)
		s.spin:Hide()
		s.mode = nil
	end

	function s.update()
		local rv = rideView()
		if not rv then return end
		local paying = rv.state == "arrived" or rv.state == "paying"
		s.layout(paying and "pay" or "live")
		local title, sub, headText, tipText = foundTexts(rv)
		if rv.raw and W.Plain(rv.raw.waitingOut) == true and rv.rank < RIDE_RANK.summoning then
			sub = "Your driver will wait until you're out."
		end
		if rv.state == "invited" and not invitePending(rv) then
			headText, tipText = "Joining the group", "Wuber accepted " .. rv.short .. "'s invite for you."
		end
		-- the pay look has no driver card: the line under the title says who summoned you
		if paying and rv.summoner then sub = sub .. " Summoned by " .. rv.summoner .. "." end
		local trade = paying and tradeOpen()
		local open = trade and (rv.price or 0) > 0
		s.title:SetText(title)
		s.sub:SetText(sub)
		setShown(s.sub, sub ~= "")
		-- (fix round, ING-09/5) in the pay look the line under the title stops short of the map strip's rider dot (at the
		-- middle) and wraps, rather than hiding the dot
		s.sub:SetWidth(s.mode == "pay" and math.min(INNER, (INNER + 2 * PAD) / 2 - 32 - PAD) or INNER)
		if not paying then
			prog:ClearAllPoints()
			prog:SetPoint("TOPLEFT", f, "TOPLEFT", 0, liveY(144))
			card:ClearAllPoints()
			card:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, liveY(192))
		end
		s.tip.head:SetText(headText)
		s.tip.body:SetText(tipText)
		card.name:SetText(rv.driver)
		card.service:SetText(rv.summoner and ("Summoned by " .. rv.summoner) or (rv.service or "Wuber driver"))
		s.tier:Update()
		founderLook(hero, rv)
		if not paying then fitHeader(s, rv) end
		if s.map:IsVisible() then updateMap(s.map, UI.Drivers()) end
		local creator = rv.driverKey and type(W.IsCreator) == "function" and call(W.IsCreator, rv.driverKey) == true
		if creator then
			if not card.crown then card.crown = T.Crown(card, 22, rv.driverKey) end
			card.crown:ClearAllPoints()
			card.crown:SetPoint("CENTER", card.avatar, "TOP", 0, 1)
			card.crown:Show()
		elseif card.crown then
			card.crown:Hide()
		end
		card.avatar:SetVertexColor(T.RGB(creator and "goldDeep" or "accent"))
		card.price:SetText(money(rv.price))
		card.dest:SetText("to " .. rv.dest)
		setShown(card, not paying)
		-- progress
		local reached = REACHED[rv.state] or 1
		s.fillTarget = (reached - 1) * STEP_GAP
		for i, n in ipairs(s.nodes) do
			local done = i <= reached
			n.dot:SetVertexColor(T.RGB(done and (i == reached and "white" or "glow") or "line"))
			n.label:SetTextColor(T.RGB(done and "white" or "muted"))
			if i == reached and rv.state ~= "done" then
				if not n.pulse.running then n.pulse:Start() end
			elseif n.pulse.running then
				n.pulse:Stop()
			end
		end
		if s.reached and reached > s.reached then
			A.Pop(s.nodes[reached], 0.3)
			if not paying then A.SlideUp(tip, 12, 0.25) end
		end
		s.reached = reached
		-- the pay card
		local payTo = rv.payto or rv.short
		if paying then
			local total = UI.PayTotal(rv)
			local rcLine = UI.RaincheckLine and UI.RaincheckLine(rv)
			local rcCover, rcTaken = nil, nil
			if UI.RaincheckCover then rcCover, rcTaken = UI.RaincheckCover(rv) end
			local due = rv.price or 0
			local tipC = due > 0 and UI.TipFor(due) or 0
			local paidC = (type(rv.raw) == "table" and tonumber(rv.raw.paidSoFar)) or 0 -- part already paid: say what is left
			pc.big:SetText(total > 0 and money(total) or "Nothing to pay")
			pc.sub:SetText((rcLine and rcCover) and (rcLine .. " · " .. ((rv.payto and rv.payto ~= rv.short) and ("Pay " .. rv.payto) or rv.driver))
				or (((paidC > 0 and paidC < due) and (money(due - paidC) .. " left of " .. money(due)) or (money(rv.price or 0) .. " fare"))
				.. (tipC > 0 and (" + " .. money(tipC) .. " tip") or "")
				.. " · " .. ((rv.payto and rv.payto ~= rv.short) and ("Pay " .. rv.payto) or rv.driver)))
			if UI.FitOrWrap then UI.FitOrWrap(pc.sub) end -- (REV-r30-1) the longest part-payment line: smaller, or two lines, never cut
			pc.sub:SetPoint("TOP", pc, "TOP", 0, pc.sub.wuberWrapped and -96 or -102)
			local want = s.tipTick(rv)
			local fl = (not (rv.raw and (rv.raw.paid or rv.raw.unpaid))) and UI.FlightLine(rv, nil, nil, true) or nil -- (round 9, S18: coin icons)
			if fl then
				pc.flight:SetText(fl)
				if UI.FitOrWrap then UI.FitOrWrap(pc.flight) end -- (HUNT-138) a long line wraps, never ends in dots
			end
			setShown(pc.flight, fl ~= nil)
			-- the Custom stops reach 214 px down the card: never past its edge
			pc:SetHeight(math.max(fl and (pc.flight.wuberWrapped and 238 or 222) or (want and 202 or 132), (want and s.picking) and 222 or 0))
			if not pc:IsShown() then A.SlideUp(pc, 18, 0.3) end
		else
			s.picking = false
			s.tipTick(nil)
			pc:Hide()
		end
		-- the context button
		local a = s.action
		a.what = nil
		local spin = false
		-- (HUNT-27: r.grouped is never set anywhere, so ask the roster itself)
		local grouped = rv.rank < RIDE_RANK.ingroup and inGroup() and not inGroupWith(rv.driverKey)
		-- (HUNT-82: a free ride has no price to type, but a stranger's trade is still warned about)
		local stranger = trade and UI.TradePartnerOK(rv) == false
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
		elseif rv.state == "invited" and invitePending(rv) then
			a:SetLabel("Accept invite")
			a:SetStyle("primary")
			a:SetActive(true)
			a.what = "invite"
		elseif open and not stranger then
			a:SetLabel("Type " .. money(UI.PayTotal(rv)) .. ", click Trade")
			a:SetStyle("primary")
			a:SetActive(false)
		elseif rv.state == "invited" then
			a:SetLabel("Joining " .. rv.short .. "'s group...")
			a:SetStyle("dark")
			a:SetActive(false)
			spin = true
		else
			local waiting = {
				accepted = "Waiting for the invite", ingroup = "Waiting for the portal",
				summoning = "Summon on its way", arrived = "Waiting for " .. payTo .. " to trade",
				paying = "Waiting for " .. payTo .. " to trade", -- (round 13, I18: was cut at "open tra...")
			}
			a:SetLabel(waiting[rv.state] or "On the way")
			a:SetStyle("dark")
			a:SetActive(false)
			spin = true
		end
		-- the label moves right a little to make room for the spinner, so the two sit centred
		a.label:SetPoint("LEFT", a, "LEFT", spin and 50 or 26, 0)
		a.label:SetPoint("RIGHT", a, "RIGHT", spin and -26 or -26, 0)
		if spin then
			-- the label in white on the dark pill, the spinner just left of its words
			a.label:SetTextColor(T.RGB("white"))
			local w = math.min(INNER - 80, T.TextWidth(a.label))
			s.spin:ClearAllPoints()
			s.spin:SetPoint("CENTER", a, "CENTER", 12 - w / 2 - 17, 0)
			if not s.spin:IsShown() then
				s.spin:Show()
				if T.FxLevel() ~= "off" then A.Spin(s.spin, 1.2, true) end
			end
		elseif s.spin:IsShown() then
			s.spin:Hide()
			if s.spin.wuberSpin then s.spin.wuberSpin:Stop() end
		end
		setShown(s.cancel, cancellable(rv))
		setShown(s.endRide, paying)
		-- the arrival share (once per ride, never a price); UI.Share shows the pill when grouped
		-- (AUD-116: no Share pill over a stranger's-trade warning)
		s.shareLine = (W.Advanced() and paying and not stranger and not (ui.flexShared and ui.flexShared[rv.id])) and UI.FlexText(rv) or nil
		s.queueTick()
		passTick(s, rv)
		s.noteTick(rv, stranger)
	end

	-- the amber card, and what sits under the driver: the queue, else what to do now
	function s.noteTick(rv, stranger)
		local head, bodyText
		local mapOK, where
		if rv.portalUp and type(W.SummonerMapOK) == "function" then mapOK, where = call(W.SummonerMapOK, rv.raw) end
		if mapOK == false then
			-- the map check (review #26): a warning card, never a block
			where = S(where)
			head = where and ("Summoner is in " .. where) or "Check before accepting"
			bodyText = where and ("Not " .. rv.dest .. " - check before accepting")
				or ("Nobody in this group seems to be in " .. rv.dest .. ".")
			s.alertTitle = "Check before you accept"
			s.alertTip = (where and ("Careful: your summoner is in " .. where .. ", not " .. rv.dest .. ". ")
				or ("Careful: nobody in this group seems to be in " .. rv.dest .. ". "))
				.. "The summon may take you somewhere else. Read where the game's summon window says before you accept."
		elseif not stranger and rv.rank < RIDE_RANK.arrived then
			-- PvP near the summon spot (5.6): the higher of the live tracker's level and the driver's
			-- beacon (HUNT-33: the tracker only hears danger with the next phase message)
			local g = rv.raw and rv.raw.ritual
			local level, secs = UI.DangerOf(UI.Driver(rv.driverKey))
			if type(g) == "table" and (N(g.danger) or 0) > level then level, secs = N(g.danger), nil end
			local dh, db = UI.DangerLine(level, secs, rv.short)
			if dh then
				head, bodyText = dh, db
				s.alertTitle = "PvP near the summon"
				s.alertTip = db .. " Accepting is still up to you."
			end
		end
		if not head and stranger then
			local who = W.Short(S(call(W.UnitName, "npc")) or "Someone")
			head = who .. " isn't your driver"
			bodyText = "Don't pay this trade: pay " .. (rv.payto or rv.short) .. "."
			s.alertTitle = "Not your driver"
			s.alertTip = who .. " isn't your driver or their crew. Cancel this trade and wait for " .. (rv.payto or rv.short) .. "."
		end
		-- the pay card is dimmed while a stranger's trade is warned about (never offered as a way to pay)
		setShown(s.pay.dim, stranger and head ~= nil and s.mode == "pay")
		local al = s.alert
		if head then
			al:SetAlert(head, bodyText)
			s.alertHead = true
			s.placeStack()
			if not al:IsShown() then A.FadeIn(al, 0.15) end
		else
			s.alertHead = false
			if al:IsShown() then al:Hide() end
			s.placeStack()
		end
		-- the title steps aside for the card while you pay
		local cover = head ~= nil and s.mode == "pay"
		s.title:SetAlpha(cover and 0 or 1)
		s.sub:SetAlpha(cover and 0 or 1)
		-- (round 9, S14) the map strip's glowing rider dot sits right under the card: hidden with it
		-- (design 3) and in the pay look when the line under the title reaches over it (it stands left, the dot at the middle)
		-- (design 4, P1) the rider dot is hidden when the dark header bar would cover any of it (it sat half under the bar's
		-- lower edge at the top middle: a grey half disc); the route and the pins say the rest
		local under = false
		if s.map.me and s.map.me:IsShown() then
			local top, edge = N(s.map.me:GetTop()), N(s.bar:GetBottom())
			under = top ~= nil and edge ~= nil and top > edge
		end
		if s.map.me then s.map.me:SetAlpha((cover or under or s.mode == "live") and 0 or 1) end
		-- (round 9, C7) the tier chip also steps aside for the arrival Share pill (same corner)
		s.tier:SetAlpha((cover or (s.shareLine ~= nil and inGroup())) and 0 or 1)
		-- on the way: the queue, else what to do now (never with the safety card or the portal)
		local live = s.mode == "live"
		-- the live tracker takes the slot from the queue line and the hint
		local kShown = live and not head and kitchenTick(s, rv)
		if not kShown and s.kitchen:IsShown() then s.kitchen:Hide() end
		if kShown then
			s.kitchen:ClearAllPoints()
			s.kitchen:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, liveY(270))
			if s.queue:IsShown() then s.queue:Hide() end
		end
		local qShown = live and s.queue:IsShown()
		local showTip = live and not head and not kShown and not rv.portalUp and not qShown and (S(s.tip.head.wuberText) or "") ~= ""
		tip:ClearAllPoints()
		tip:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, liveY(270))
		setShown(tip, showTip)
		s.fitHero()
	end

	-- the amber card sits at the queue line's spot, so with the queue line up it moves one line lower
	-- (and the passphrase line below it); neither is dropped or shortened
	-- (design 2) on the pay look the card is at the top, where the window's x is: it ends 8 before the x and is as
	-- high as its words need at that width (the head may take a second line; nothing is cut)
	local function alertSize(pay)
		local al = s.alert
		local w = pay and (WIN_W - BACK.left - headRight() - 4) or INNER
		al:SetWidth(w)
		al.head:SetWidth(w - 76)
		al.body:SetWidth(w - 76)
		local h = 72
		if pay then
			local hl = T.ParaLines(S(al.head.wuberText) or "", "body", "bold", w - 76)
			local bl = T.ParaLines(S(al.body.wuberText) or "", "caption", "regular", w - 76)
			h = h + (hl - 1) * 18 + math.max(0, bl - 2) * 15
		end
		Try(al.head, "SetWordWrap", pay and true or false)
		Try(al.body, "SetMaxLines", pay and 0 or 2)
		al:SetHeight(h)
	end

	function s.placeStack()
		local al = s.alert
		if not s.alertHead then
			s.pass:ClearAllPoints()
			s.pass:SetPoint("TOP", f, "TOP", 0, liveY(350))
			return
		end
		al:ClearAllPoints()
		alertSize(s.mode == "pay")
		if s.mode == "pay" then
			al:SetPoint("TOPLEFT", f, "TOPLEFT", BACK.left, -12)
			s.pass:ClearAllPoints()
			s.pass:SetPoint("TOP", f, "TOP", 0, -(HEAD_H + 350))
			return
		end
		local both = q:IsShown()
		al:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, liveY(both and 312 or 270))
		s.pass:ClearAllPoints()
		s.pass:SetPoint("TOP", f, "TOP", 0, liveY(both and 394 or 350))
	end

	-- (design 4, A2) the portal's size from the room. Everything live sat at its old place; the picture takes the room above
	-- (its top PORTAL.top under the dark bar, the headline PORTAL.gap under it) and all of it moves down by size - PORTAL.base. The room
	-- is what lies between the lowest live card (the card, queue, tip or tracker, the amber card, the passphrase) and the link
	-- above the main button: the size is as large as that allows, at most PORTAL.max. When the page is too full for PORTAL.min
	-- (the amber card with a queue line and more) it is the largest that fits, so nothing overlaps: no text shrinks and none is cut.
	local function stackBottom()
		local lift = s.sub:IsShown() and 0 or NO_SUB_LIFT
		local low = 192 + (N(card:GetHeight()) or 66)
		local function seen(top, fr, h) if fr:IsShown() then low = math.max(low, top + (N(fr:GetHeight()) or h)) end end
		seen(270, q, 36)
		seen(270, tip, 70)
		seen(270, s.kitchen, 36)
		local both = q:IsShown()
		if s.alertHead then seen(both and 312 or 270, s.alert, 72) end
		seen(s.alertHead and (both and 394 or 350) or 350, s.pass, 16)
		return low - lift
	end

	-- with the portal up the map strip is hidden altogether: its picture, shade, pins, route and you dot go clear
	-- (alpha 0, so a Show from the map never brings one back)
	local stripFaded = {}
	local function stripHide(on)
		local m = s.map
		local a = on and 0 or 1
		local function fade(fr)
			if fr and type(fr.SetAlpha) == "function" then
				if on then
					stripFaded[fr] = true
				elseif not stripFaded[fr] then
					return
				end
				fr:SetAlpha(a)
			end
		end
		fade(m.hero)
		for _, ch in ipairs({ m:GetChildren() }) do
			if ch == m.dots then
				for _, d in ipairs({ m.dots:GetChildren() }) do fade(d) end
			else
				fade(ch)
			end
		end
		if not on then stripFaded = {} end
	end

	function s.fitHero()
		if s.mode ~= "live" then
			if s.portalUp then
				s.portalUp, s.map.noPulse = false, false
				stripHide(false)
				if s.map.me and s.mode == "pay" and s.alertHead then s.map.me:SetAlpha(0) end
				s.map:SetAlpha(0.85)
				if s.map.me and s.map.me:IsShown() then s.map.me.pulse:Start() end
			end
			return
		end
		local h = N(f:GetHeight()) or 0
		local room = h - (T.MAIN.foot + T.MAIN.h + 8 + (N(s.cancel:GetHeight()) or 40)) - HEAD_H -- N of the link's top
		local fit = h > 0 and math.floor(room - PORTAL.foot - stackBottom() + PORTAL.base) or PORTAL.first
		local size = math.min(PORTAL.max, math.max(PORTAL.base, fit))
		if size ~= s.portalPx then
			s.portalPx = size
			hero:SetSize(220, size)
			hero.art:SetSize(size, size)
		end
		local me = s.map.me
		-- while the portal shows it is the only focus: the whole map strip (including the you dot and its pulse) is hidden
		local up = hero:IsShown() and hero.art:IsShown()
		if up ~= (s.portalUp or false) then
			s.portalUp = up
			s.map.noPulse = up
			if me and up then me.pulse:Stop() end
			s.map:SetAlpha(0.85)
			if not up then stripHide(false) end
		end
		if up then stripHide(true) end -- every pass: a pin, the route, or the dot that came back since stays clear
		local drop = size - PORTAL.base
		if drop == s.drop then return end
		s.drop = drop
		s.title:ClearAllPoints()
		s.title:SetPoint("TOP", f, "TOP", 0, liveY(78, true))
		s.sub:ClearAllPoints()
		s.sub:SetPoint("TOP", f, "TOP", 0, liveY(110, true))
		prog:ClearAllPoints()
		prog:SetPoint("TOPLEFT", f, "TOPLEFT", 0, liveY(144))
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, liveY(192))
		q:ClearAllPoints()
		q:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, liveY(270))
		tip:ClearAllPoints()
		tip:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, liveY(270))
		s.kitchen:ClearAllPoints()
		s.kitchen:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, liveY(270))
		s.placeStack()
	end

	-- "You're 2nd in line · about 1 min", counting down between the driver's updates
	function s.queueTick()
		local rv = rideView()
		local pos = rv and rv.position
		if not W.Advanced() and s.kitchen:IsShown() then s.kitchen:Hide() end
		if not pos or pos < 1 or rv.rank >= RIDE_RANK.summoning or rv.rank < RIDE_RANK.accepted or s.kitchen:IsShown() then
			if q:IsShown() then q:Hide() end
			s.placeStack()
			s.fitHero()
			return
		end
		local r = rv.raw
		local eta = N(r.eta)
		local left
		if N(r.etaAt) then
			left = N(r.etaAt) - now()
		elseif eta then
			local sig = pos .. ":" .. eta .. ":" .. tostring(rv.id)
			if s.qSig ~= sig then s.qSig, s.qAt = sig, now() end
			left = eta - (now() - s.qAt)
		end
		local where = pos == 1 and "You're next" or ("You're " .. ordinal(pos) .. " in line")
		if left then
			left = math.max(0, math.floor(left + 0.5))
			local when = left <= 0 and "any moment now" or (left < 60 and "under a minute" or ("about " .. math.ceil(left / 60) .. " min"))
			q.text:SetText(where .. " · " .. when)
			q.clock:SetText(("%d:%02d"):format(math.floor(left / 60), left % 60))
		else
			q.text:SetText(where)
			q.clock:SetText("")
		end
		q:ClearAllPoints()
		q:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, liveY(270))
		if not q:IsShown() then
			A.FadeIn(q, 0.25)
			tip:Hide()
		end
		s.placeStack()
		s.fitHero()
	end

	function s.frameTick(elapsed)
		s.qAcc = (s.qAcc or 1) + (elapsed or 0)
		if s.qAcc >= 0.25 then
			s.qAcc = 0
			s.queueTick()
		end
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
	if what == "pay" then
		if inCombat() then
			UI.Toast("Leave combat first", "warn")
		elseif type(W.PayFare) == "function" then
			local ok, line = call(W.PayFare)
			if ok then
				local total = UI.PayTotal(rideView())
				if total > 0 then line = W.FareSteps(total) end
				if S(line) then UI.Toast(line, "found") end
			else
				UI.Toast(S(line) or "Put the fare in the trade window and click Trade", "warn")
			end
		else
			UI.Toast("Put the fare in the trade window and click Trade", "info")
		end
	elseif what == "leave" then
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
				if W.ride then W.ride.summonNoName = nil end
				hidePopup("CONFIRM_SUMMON")
			else
				UI.Toast("Click Accept on the summon window", "warn")
			end
		end
	end
	UI.Refresh(true)
end

-- the live tracker moved on (Net.Portal's G): redraw the Found screen
W.Listen("RITUAL", function() UI.Refresh(true) end)

-- internals other modules use (bound at load by later modules, or called late)
Mod.buildFound = buildFound
Mod.invitePending = invitePending
