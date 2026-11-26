-- Module: UI.Rider.Confirm
-- Purpose: Confirm screen (book a driver, request via the secure button) and the Finding screen.
-- API: UI.TierChip, UI.RaincheckCover
-- Internals: buildConfirm, buildFinding, leaveGroup, tierChip, stackCard, raincheckFor, side, aboutLines,
--   widenDial, foldedAbout, foldBuild, foldLayout, sideUpdate, ridesWith, againLine, againChip, aboutBuild, wideBlocks, ROW_AGAIN
-- Uses: UI.Kit, UI.Secure, UI.Rider.HomeMap, UI.Rider.Cards, UI.Rider.Booking
-- Sets: HomeMap's m.avoid and m.visBottom on its strip
-- Later: UI.Fold (Register: the unfolded "confirm" page, Confirm and Finding), UI.Rider.WorldMap
--   (Build, Show, Wanted: the side pane's Here/World control, the route and the destination's ring)
-- Unfolded (SPEC7 2.8 "confirm"): booking on the left as folded (the dial 324 x 96 plus the
-- savings pill when they fit), the trip on the map on the right (Confirm's map docked; the World
-- view first, else the rider's last pick on Here/World: round 12). Finding keeps the map on the right. The secure
-- Request pill never leaves the left pane. (2.3.2, I29) "About this driver" sits in the booking column under the
-- driver card when it fits (before the bigger dial), never over the map, and (2.3.2) folded too when the sheet has
-- the room; standing in the driver's place there is no route header and no portal pin; a returning rider's driver card says
-- "10th ride with Mia" folded and unfolded. (FEAT-01 b) The grey driver line ends "· usually about 45 sec" for an open
-- driver with nobody waiting whose advert carries their average summon (Cards' usualSummon); it wraps when long.
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/ui/rider/confirm_test.lua
-- From: UI.lua 2471-2903 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Rider.Confirm", { "UI.Kit", "UI.Secure", "UI.Rider.HomeMap", "UI.Rider.Cards", "UI.Rider.Booking" })
local KitMod = W.Mod("UI.Kit")
local SecureMod = W.Mod("UI.Secure")
local HomeMapMod = W.Mod("UI.Rider.HomeMap")
local CardsMod = W.Mod("UI.Rider.Cards")
local Booking = W.Mod("UI.Rider.Booking")
local INNER = KitMod.INNER
local N = KitMod.N
local PAD = KitMod.PAD
local REQUEST_TIMEOUT = KitMod.REQUEST_TIMEOUT
local S = KitMod.S
local call = KitMod.call
local clamp = KitMod.clamp
local duration = KitMod.duration
local inCombat = KitMod.inCombat
local inGroup = KitMod.inGroup
local inGroupWith = KitMod.inGroupWith
local money = KitMod.money
local ordinal = KitMod.ordinal
local now = KitMod.now
local rideView = KitMod.rideView
local safeScript = KitMod.safeScript
local setShown = KitMod.setShown
local ui = KitMod.ui
local BLOCK_TEXT = SecureMod.BLOCK_TEXT
local doCancel = SecureMod.doCancel
local requestBlock = SecureMod.requestBlock
local requestMacro = SecureMod.requestMacro
local buildMapPanel = HomeMapMod.buildMapPanel
local updateMap = HomeMapMod.updateMap
local chipFor = CardsMod.chipFor
local usualSummon = CardsMod.usualSummon
local heartButton = CardsMod.heartButton
local isFav = CardsMod.isFav
local T = W.Theme
local A = T.Animate
local Try = T.Try
local UI = W.UI

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

-- A held raincheck this driver would take (SPEC7 5.8): id, cover (copper), or nil. The rider's
-- copy grants nothing; the driver's book decides when the request comes (R field 7).
local function raincheckFor(d)
	local R = W.Raincheck
	if not d or type(R) ~= "table" or type(R.ForDriver) ~= "function" then return nil end
	local id, cover = call(R.ForDriver, d)
	id, cover = S(id), N(cover)
	if not id or not cover or cover <= 0 then return nil end
	return id, cover
end

-- The rider's choice for the "Use raincheck" toggle (on by default): Net's W.Raincheck.Use, so
-- the request names the raincheck (R field 7) only while it is on.
local function raincheckWanted()
	local R = W.Raincheck
	if type(R) == "table" and type(R.Using) == "function" then return call(R.Using) ~= false end
	return true
end
local function setRaincheckWanted(on)
	local R = W.Raincheck
	if type(R) == "table" and type(R.Use) == "function" then call(R.Use, on and true or false) end
end

-- Lays the sheet's blocks top to bottom (the dial or the savings pill, the driver, the PvP card,
-- the raincheck toggle, how you pay, the group warning) over the Request pill, and moves the sheet
-- up over the map strip when they need the room (never above 100: the route header sits there).
local GAP = 10
local WIDE_TOP = 62 -- unfolded: the sheet's top, under the back + route header row
local function stackCard(s, blocks)
	local card = s.card
	local hx = s.headExtra or 0 -- (r46, REV-r46-1) the headline wrapped to two lines: everything under it moves down
	local need = 58 + hx
	for _, b in ipairs(blocks) do need = need + b.h + GAP end
	local bottom = 54 + PAD + 8
	-- (round 9, S9) unfolded the map is in the side pane: the back button and the route share one
	-- header row and the sheet starts right under it
	local top = s.wide and WIDE_TOP or math.max(100, math.min(168, 544 - need - bottom))
	-- still too tall: how-you-pay steps aside (the raincheck row says what to pay)
	if 544 - top - bottom < need then
		for i, b in ipairs(blocks) do
			if b.frame == s.pay then
				table.remove(blocks, i)
				need = need - b.h - GAP
				s.pay:Hide()
				break
			end
		end
	end
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 0, -top)
	card:SetPoint("BOTTOMRIGHT", s.frame, "BOTTOMRIGHT", 0, 0)
	s.cardTop = top
	local y = 58 + hx
	for _, b in ipairs(blocks) do
		local fr = b.frame
		fr:ClearAllPoints()
		fr:SetPoint(b.point or "TOPLEFT", card, b.point or "TOPLEFT", b.x or PAD, -(y + (b.dy or 0)))
		if b.also then
			b.also:ClearAllPoints()
			b.also:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -y)
		end
		y = y + b.h + GAP
	end
	s.stackEnd = y
end

-- Confirm (the author's pick, 02 v3): the route on a map strip up to a glowing portal pin, then one
-- sheet: "Summon to Undercity" with the fare big on the right, a violet pill with what the
-- summon saves ("5 min faster · Net 27s vs flying", only what we know), the driver card
-- (avatar, name, place · crew · state, the heart), "Trade 50s after you arrive", and one big
-- "Request summon · 50s" button (the secure WuberRequestButton lies over it as before). The
-- whisper it sends is in the button's tooltip.
-- (Simple mode) one line in place of the Fly or summon dial: "Summon 30 sec. Fly about 9 min."
local function simpleDialLine(info)
	if type(info) ~= "table" then return nil end
	local parts = {}
	local wait = N(info.wait)
	if wait and wait > 0 then
		if wait < 60 then
			parts[#parts + 1] = "Summon " .. math.floor(wait + 0.5) .. " sec."
		else
			parts[#parts + 1] = "Summon about " .. math.max(1, math.floor(wait / 60 + 0.5)) .. " min."
		end
	end
	local fly = N(info.flySecs)
	if fly and fly > 0 then
		parts[#parts + 1] = "Fly about " .. math.max(1, math.floor(fly / 60 + 0.5)) .. " min."
	end
	if #parts == 0 then return nil end
	return table.concat(parts, " ")
end

local function buildConfirm(body)
	local s = { frame = CreateFrame("Frame", nil, body) }
	local f = s.frame
	f:SetAllPoints(body)
	f:Hide()
	-- (design 2) a pushed page: the back chevron, its own top row and the window's x; the cog steps aside while it shows
	if UI.HeadPush then
		UI.HeadPush(f)
		f:HookScript("OnShow", function() pcall(UI.HeadPush) end)
		f:HookScript("OnHide", function() pcall(UI.HeadPush) end)
	end
	s.map = buildMapPanel(f, 196, 182)
	s.map.strip = true
	-- (2.3.2, S3) the back button: no pin over it; (round 37, REV-r37-1) nor over the route header, which sits on
	-- the strip just above the sheet (higher when the dial moves the sheet up), its box worked out when a pin is placed
	s.map.avoid = { { l = 10, r = 58, t = 8, b = 56 }, function()
		local h = s.route
		if s.wide or not (h and h:IsShown()) then return nil end
		local bottom = (N(s.cardTop) or 168) - 8
		return { l = PAD, r = PAD + (N(h:GetWidth()) or INNER), t = bottom - (N(h:GetHeight()) or 32), b = bottom }
	end }
	-- (round 37, REV-r37-2) the strip's visible bottom is where the sheet really begins (higher when the dial lifts it),
	-- and the route header's top over it (the rider is kept above that); unfolded (docked) the map shows all
	s.map.visBottom = function()
		if s.wide then return nil end
		local top = N(s.cardTop) or 168
		local h = s.route
		if not (h and h:IsShown()) then return top end
		return top, top - 8 - (N(h:GetHeight()) or 32)
	end
	s.map.net:Hide()
	s.map.zone:Hide()
	-- the destination pin (placed by UI.RouteOnMap at the route's end)
	local pin = CreateFrame("Frame", nil, s.map.dots)
	pin:SetSize(46, 54)
	pin.halo = T.Tex(pin, "glow", "BACKGROUND")
	pin.halo:SetSize(96, 96)
	pin.halo:SetPoint("CENTER", pin, "TOP", 0, -23)
	pin.halo:SetVertexColor(T.RGB("accent", 0.9))
	Try(pin.halo, "SetBlendMode", "ADD")
	pin.tail = T.Circle(pin, 10, "glow", "ARTWORK")
	pin.tail:SetPoint("BOTTOM", pin, "BOTTOM", 0, 0)
	pin.disc = T.Circle(pin, 46, "glow", "ARTWORK", 1)
	pin.disc:SetPoint("TOP", pin, "TOP", 0, 0)
	pin.art = T.Tex(pin, "portal", "OVERLAY")
	pin.art:SetSize(40, 40)
	pin.art:SetPoint("CENTER", pin.disc, "CENTER")
	pin:Hide()
	s.map.destPin = pin
	local top = CreateFrame("Frame", nil, f)
	top:SetAllPoints(f)
	top:SetFrameLevel(s.map:GetFrameLevel() + 12)
	s.back = T.RoundButton(top, "back", 36, "card")
	s.back:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
	safeScript(s.back, "OnClick", function() UI.Show("home") end)

	-- the one sheet
	local card = T.Card(top, nil, nil, { colour = "panel", radius = 18 })
	card:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -168)
	card:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	s.card = card
	local grab = CreateFrame("Frame", nil, card)
	grab:SetSize(36, 5)
	grab:SetPoint("TOP", card, "TOP", 0, -9)
	T.PillFill(grab, "raised", 5, "ARTWORK")
	card.grab = grab -- (round 9, S9: hidden in two-pane)
	card.headline = T.Text(card, "title", "white", "LEFT", "bold")
	card.headline:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -28)
	card.headline:SetWidth(INNER - 92)
	card.headline.wuberSpare = 1.06 -- (round 13, I18) fitted with spare: never "..."
	card.price = T.Text(card, "display", "gold", "RIGHT", "bold")
	card.price:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -24)
	-- what the summon saves: one violet pill (hidden when we know nothing)
	s.saved = T.Tag(card, "", { fill = { 0.36, 0.2, 0.62, 0.95 }, text = "white", h = 28, size = "sub", pad = 14 })
	s.saved:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -62)
	s.saved:EnableMouse(true)
	T.Tip(s.saved, "Against flying", function() return s.savedTip end)
	s.saved:Hide()
	-- the dial (SPEC7 5.1): Fly <-> Summon, in place of the pill when flying is known
	s.dial = Booking.Dial(card, INNER, 88)
	-- (Simple mode) one wrapped text line in place of the dial
	local ds = T.Card(card, INNER, 36, { colour = "card", radius = 14, shadow = false })
	ds.text = T.Text(ds, "sub", "white", "LEFT", "medium")
	ds.text:SetPoint("TOPLEFT", ds, "TOPLEFT", 14, -10)
	ds.text:SetWidth(INNER - 28)
	Try(ds.text, "SetWordWrap", true)
	Try(ds.text, "SetMaxLines", 0)
	ds:EnableMouse(true)
	T.Tip(ds, "Against flying", function() return s.savedTip or "How long the summon takes compared with flying there." end)
	ds:Hide()
	s.dialSimple = ds
	-- the route header (5.2) on the map strip, just above the sheet
	s.route = Booking.RouteHeader(top, INNER)
	s.route:SetPoint("BOTTOMLEFT", card, "TOPLEFT", PAD, 8)

	-- the driver card
	local row = T.Card(card, INNER, 70, { colour = "card", radius = 16, shadow = false })
	row:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -102)
	card.row = row
	card.avatar = T.Circle(row, 46, "accent", "ARTWORK")
	card.avatar:SetPoint("LEFT", row, "LEFT", 14, 0)
	card.glyph = T.Icon(row, "summon", 24, "ink", "OVERLAY")
	card.glyph:SetPoint("CENTER", card.avatar, "CENTER")
	-- (decisions H) "Favourite" is written with the heart, under it (beside it, it took a fifth of the grey line's
	-- room and ordinary lines wrapped). (decisions X4) The pair sits so the WORD, wider than the heart, keeps the
	-- card's 12 px margin; favRoom is how far the word's left end is from the card's right edge, off both text lines.
	card.heart = heartButton(row, 18)
	local favW = math.ceil(N(T.MeasureText("Favourite", "caption", "regular")) or 42)
	local heartW = N(card.heart:GetWidth()) or 18
	local favRoom = 12 + math.max(0, math.ceil((favW - heartW) / 2)) + math.ceil((heartW + favW) / 2)
	card.service = T.Text(row, "body", "white", "LEFT", "bold")
	card.service:SetPoint("TOPLEFT", row, "TOPLEFT", 74, -17)
	card.service.wuberMin = T.SIZE.caption
	card.service:SetWidth(INNER - 74 - favRoom - 2)
	card.driver = T.Text(row, "caption", "muted", "LEFT", "regular")
	card.driver:SetPoint("TOPLEFT", row, "TOPLEFT", 74, -40)
	card.driver:SetWidth(INNER - 74 - favRoom - 2)
	card.heart:SetPoint("RIGHT", row, "RIGHT", -(12 + math.max(0, math.ceil((favW - heartW) / 2))), 6)
	card.heart.word = T.Text(card.heart, "caption", "muted", "CENTER", "regular")
	card.heart.word:SetPoint("TOP", card.heart, "BOTTOM", 0, 2)
	card.heart.word:SetText("Favourite")
	local hitX = math.max(8, math.ceil((favW - heartW) / 2))
	Try(card.heart, "SetHitRectInsets", -hitX, -hitX, 0, -10) -- a click on the word is a click on the heart
	row:EnableMouse(true)
	T.Tip(row, function() return card.service.wuberText end, function()
		local d = s.last
		if not d then return nil end
		return d.name .. " summons you to " .. d.dest .. ". " .. (d.team >= 3 and "Their crew clicks the portal: nobody else needed."
			or ("Bring " .. (3 - d.team) .. " friend" .. (3 - d.team == 1 and "" or "s") .. " to click the portal."))
	end)
	-- how you pay: one quiet row
	local pay = CreateFrame("Frame", nil, card)
	pay:SetSize(INNER, 40)
	pay:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -182)
	pay.bg = T.Rounded(pay, "hover", 12, "BACKGROUND", 0)
	pay.icon = T.Icon(pay, "coin", 16, "muted", "ARTWORK")
	pay.icon:SetPoint("LEFT", pay, "LEFT", 16, 0)
	s.note = T.Text(pay, "sub", "white", "LEFT", "medium")
	s.note:SetPoint("LEFT", pay, "LEFT", 44, 0)
	s.note:SetWidth(INNER - 56)
	pay:EnableMouse(true)
	T.Tip(pay, "How you pay", "Nothing now. After the summon your driver opens a trade: you type the gold yourself and click Trade.")
	s.pay = pay

	-- PvP near the summon spot (5.6): a warning, never a block
	s.pvp = T.AlertCard(card, INNER, 64)
	s.pvp:EnableMouse(true)
	T.Tip(s.pvp, "PvP near the summon", "Wuber saw a fight or enemy players near where you'll land. You can still book; be ready.")
	s.pvp:Hide()
	-- "Use raincheck (covers 50s)" (5.8), on by default
	local rc = CreateFrame("Frame", nil, card)
	rc:SetSize(INNER, 44)
	rc.bg = T.Rounded(rc, { 0.17, 0.12, 0.27, 1 }, 12, "BACKGROUND", 0)
	rc.icon = T.Icon(rc, "ride", 14, "glow", "ARTWORK")
	rc.icon:SetPoint("LEFT", rc, "LEFT", 14, 0)
	rc.label = T.Text(rc, "sub", "white", "LEFT", "bold")
	rc.label:SetPoint("TOPLEFT", rc, "TOPLEFT", 36, -7)
	rc.label:SetWidth(INNER - 100)
	-- what you'll pay (how-you-pay steps aside while this row shows)
	rc.sub = T.Text(rc, "caption", "muted", "LEFT", "regular")
	rc.sub:SetPoint("TOPLEFT", rc.label, "BOTTOMLEFT", 0, -3)
	rc.sub:SetWidth(INNER - 100)
	rc.toggle = T.Toggle(rc, true, function(on)
		setRaincheckWanted(on)
		UI.Refresh(true)
	end)
	rc.toggle:SetPoint("RIGHT", rc, "RIGHT", -10, 0)
	rc:EnableMouse(true)
	local rcTip = "A raincheck is one summon at no charge from this crew after a paid ride that failed. The driver's Wuber checks it when you request."
	T.Tip(rc, "Use raincheck", rcTip)
	T.Tip(rc.toggle, "Use raincheck", rcTip)
	rc:Hide()
	s.rc = rc

	s.warn = T.Text(card, "sub", "red", "LEFT", "medium")
	s.warn:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -236)
	s.warn:SetWidth(180)
	Try(s.warn, "SetWordWrap", true)
	s.leave = T.Pill(card, "Leave group", "dark", 130, 34)
	s.leave:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -232)
	safeScript(s.leave, "OnClick", leaveGroup)
	T.Tip(s.leave, "Leave group", "Leave your group so the driver can invite you to theirs.")

	s.request = T.MainButton(card, "Request summon") -- (Design 2) the one main button's place; the secure overlay follows its rect
	safeScript(s.request, "OnClick", function(self)
		-- only reached when the secure button isn't over it
		if self.inactive then return end
		local why = requestBlock(ui.confirmKey)
		if inCombat() and not why then
			-- book while busy: the request goes out, the chat whisper (protected) doesn't
			local ride, no = call(W.RequestRide, ui.confirmKey)
			if ride then
				UI.Toast("Request sent. No whisper in combat.", "info")
				ui.manual = "home"
				UI.Refresh(true)
			else
				UI.Toast(BLOCK_TEXT[no or ""] or "Couldn't send the request", "warn")
			end
			return
		end
		if why then
			UI.Toast(BLOCK_TEXT[why] or "Can't request right now", "warn")
			return
		end
		ui.animUntil = 0
		UI.SyncSecure()
		UI.Toast("One moment - click Request again", "info")
	end)
	T.Tip(s.request, "Request summon", function()
		if inCombat() then return "Sends your request now. The chat whisper can't be sent in combat; the driver still gets it." end
		return "Whispers the driver and sends your request. You pay after you arrive."
			.. (s.whisper and ("\n\nWhispers: \"" .. s.whisper .. "\"") or "")
	end, "ANCHOR_TOP")
	T.Tip(s.back, "Back", "Back to the list of drivers.")

	function s.enter(key)
		ui.manual = "confirm"
		ui.confirmKey = key or ui.confirmKey
		-- what flying there costs, if we don't know: ask the driver (shared flight prices, 2.2.1)
		if ui.confirmKey and type(W.AskFlight) == "function" then call(W.AskFlight, ui.confirmKey) end
		-- (AUD-134) a driver who is gone: nothing of the earlier driver's card is kept
		if ui.confirmKey and not UI.Driver(ui.confirmKey) then s.last = nil end
		A.SlideUp(card, 30, 0.3)
		-- (AUD-115) unfolded, the side pane's Here/World control owns the map
		if not s.wide then A.FadeIn(s.map, 0.3) end
	end

	-- "5 min faster · Net 27s vs flying" (or "· worth about 2g of your time"); nil: nothing known
	function s.savings(d, total)
		-- (round 9, S1) the same time as the dial's verdict: the flying saved less the wait for
		-- the summon (Booking.DialInfo's timeSaved), so "wins by about 3 min" and "3 min faster" agree
		local info = Booking.DialInfo(d, total)
		local sec = info and N(info.flySecs) and N(info.timeSaved) or nil
		-- (round 12, item 5) under "Flying wins" / "About the same" a bare "3 min faster" read as if
		-- flying were the faster one: the line names the summon then ("worth about" still only
		-- when it beats the fare, 02 v3)
		local _, benefit = Booking.Score(info)
		local summonWins = (N(benefit) or 0) >= 1000
		-- (round 13, I14) by boat or zeppelin from here: no flight price to set against the fare
		local free = info and info.crossing and (N(info.flightCost) or 0) <= 0
		local parts, tips = {}, {}
		if sec and sec > 0 then
			parts[1] = (summonWins and "" or "Summon is ") .. (info.flyAbout and "about " or "") .. duration(sec) .. " faster" -- (AU24-18) a worked-out time says about
			tips[1] = "Saves about " .. duration(sec) .. (free and (" against the " .. info.crossing .. " from where you stand (the wait for the summon taken off).")
				or (" against flying from where you stand (getting to a flight master included, the wait for the summon taken off)."))
		end
		local fl, cost = UI.FlightLine(d.dest, false, total)
		if free then fl, cost = nil, nil end
		if fl and cost then
			local net = total - cost
			-- (design 1 H) next to "3 min faster": the amount in letters
			local function coins(c) return T.Code("gold") .. money(c) .. "|r" end -- (design 1 P)
			parts[#parts + 1] = net > 0 and ("Net " .. coins(net) .. " vs flying") or ("Saves " .. coins(-net) .. " vs flying")
			tips[#tips + 1] = fl .. "."
		end
		-- what the time is worth, when it beats the fare: in the pill without a flight cost
		-- (two parts at most), else in its tooltip
		local value = sec and sec > 0 and type(W.TimeValue) == "function" and N(call(W.TimeValue, sec)) or nil
		if value and value > (N(d.price) or 0) and value > 0 then
			if fl and cost then
				tips[#tips + 1] = "That time is worth about " .. money(value) .. " to you (Settings)."
			else
				parts[#parts + 1] = "worth about " .. T.Code("gold") .. money(value) .. "|r of your time" -- (S18: by a time)
				tips[#tips + 1] = "Change what your time is worth in Settings."
			end
		end
		if #parts == 0 then return nil end
		return table.concat(parts, " · "), table.concat(tips, " ")
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
			-- (AUD-134) the earlier driver's price, route, dial and rows go
			card.price:SetText("")
			for _, f in ipairs({ s.route, s.dial, s.dialSimple, s.saved, s.pvp, s.rc, pay, s.warn, s.leave, row }) do f:Hide() end
			if Mod.side and Mod.side.about then Mod.side.about:Hide() end
			if s.map then s.map.routeDest = nil end
			return
		end
		local adv = W.Advanced()
		-- (2.3.2, S3) standing in the driver's place: no "Undercity > Undercity" route, no portal pin
		local atDest = requestBlock(d.key) == "here"
		s.map.routeDest = (not atDest) and d.dest or nil
		card.service:SetText(d.service)
		local crew = d.team >= 3 and "Crew ready" or ("Bring " .. (3 - d.team) .. (3 - d.team == 1 and " friend" or " friends"))
		local state = d.state == "open" and "Open" or (chipFor(d))
		local who = d.summoner and (d.summoner .. " summons") or (d.creator and "Founder" or nil)
		-- (FEAT-01 b) an open driver with nobody waiting who sends their average: "· usually about 45 sec" at the end
		local usual = usualSummon(d)
		card.driver:SetText(d.dest .. " · " .. crew .. " · " .. state .. (who and (" · " .. who) or "") .. (usual and (" · usually " .. usual) or ""))
		UI.FitOrWrap(card.driver) -- (HUNT-118) shrink first; a line still too long wraps to a second, never cut
		card.heart.key, card.heart.name = d.key, d.name
		card.heart:SetFav(isFav(d.key))
		-- (2.3.2, I29) a returning rider: "10th ride with Mia" in the driver card, folded too (none
		-- for a first ride; the chip is made the first time it is wanted)
		local again = adv and Mod.againLine(d) or nil
		if again then Mod.againChip(card):SetChip(again, "muted") end
		if card.again then setShown(card.again, again ~= nil) end
		-- (HUNT-118) the grey line wrapped: the card grows a line and the chip goes down with it
		-- (design 1) by the line's real height: wrapped lines have room between them now, and a third line counts too
		local extra = 0
		if card.driver.wuberWrapped then
			local one = T.DrawnSize(card.driver.wuberPx or "caption")
			extra = math.max(13, math.ceil((N(card.driver:GetStringHeight()) or one) - one))
		end
		local rowH = (again and Mod.ROW_AGAIN or 70) + extra
		if card.again then
			card.again:ClearAllPoints()
			card.again:SetPoint("TOPLEFT", card.row, "TOPLEFT", 74, -58 - extra)
		end
		row:SetHeight(rowH)
		card.avatar:SetVertexColor(T.RGB(d.creator and "goldDeep" or "accent"))
		if d.creator then
			if not card.crown then card.crown = T.Crown(card.row, 22, d.key) end
			card.crown:ClearAllPoints()
			card.crown:SetPoint("CENTER", card.avatar, "TOP", 0, 2)
			card.crown:Show()
		elseif card.crown then
			card.crown:Hide()
		end
		-- (BRIEF15) a Pioneer Driver's badge on the avatar's corner (the shipped list only; a founder: none)
		local pb = T.ShowPioneer(card, "pioneer", T.PioneerLook(d.key), 16, card.row, true)
		if pb then
			pb:ClearAllPoints()
			pb:SetPoint("CENTER", card.avatar, "BOTTOMRIGHT", -2, 2)
		end
		card.headline:SetText("Summon to " .. d.dest)
		UI.FitOrWrap(card.headline) -- (r46, REV-r46-1) shrink first; a place still too long wraps to a second line, never cut
		s.headExtra = card.headline.wuberWrapped and 14 or 0
		card.price:SetText(money(d.price))
		local total = (N(d.price) or 0) + UI.TipFor(N(d.price) or 0, UI.TipPct())
		local line, tip = s.savings(d, total)
		s.savedTip = tip
		s.route:SetMaxWidth(s.wide and (INNER - 46) or INNER)
		if atDest then
			s.route:Hide()
		else
			s.route:Show()
			s.route:Update(d.dest)
		end
		-- the dial when flying is known (the pill's words go under its verdict), else the pill
		local info = Booking.DialInfo(d, total, { line = line })
		local simpleLine = (not adv and info) and simpleDialLine(info) or nil
		if adv then
			s.dial:SetSize(INNER, 88)
			s.dial:Set(info)
		end
		local blocks = {}
		-- (AUD-134 follow-up) the gone card hid the dial and the row: each block is shown or hidden here
		setShown(s.dial, adv and info ~= nil)
		setShown(s.dialSimple, simpleLine ~= nil)
		row:Show()
		if adv and info then
			s.saved:Hide()
			blocks[#blocks + 1] = { frame = s.dial, h = 88 + (s.dial.extra or 0), dy = -4 }
		elseif simpleLine then
			s.saved:Hide()
			s.dialSimple.text:SetText(simpleLine)
			local th = math.ceil(N(s.dialSimple.text:GetStringHeight()) or T.DrawnSize("small"))
			local dsH = math.max(36, th + 20)
			s.dialSimple:SetHeight(dsH)
			blocks[#blocks + 1] = { frame = s.dialSimple, h = dsH }
		elseif line then
			s.saved:SetTag(line)
			if not s.saved:IsShown() then A.FadeIn(s.saved, 0.25) end
			blocks[#blocks + 1] = { frame = s.saved, h = 28, dy = 4 }
		else
			s.saved:Hide()
		end
		blocks[#blocks + 1] = { frame = row, h = rowH }
		-- PvP near the summon spot
		local level, secs = UI.DangerOf(d)
		local head, body = UI.DangerLine(level, secs, d.short)
		if head then
			s.pvp:SetCompact(false)
			s.pvp:SetAlert(head, body)
			s.pvp.edge:SetColor("red")
			if not s.pvp:IsShown() then A.FadeIn(s.pvp, 0.2) end
			blocks[#blocks + 1] = { frame = s.pvp, h = 64 }
		else
			s.pvp:Hide()
		end
		-- a held raincheck for this crew
		local rcId, cover = raincheckFor(d)
		s.rcId, s.rcCover = rcId, cover
		local useRc = rcId and raincheckWanted()
		if rcId then
			s.rc.label:SetText("Use raincheck (covers " .. money(cover) .. ")")
			if s.rc.toggle.on ~= (useRc and true or false) then s.rc.toggle:SetOn(useRc and true or false) end
			s.rc:Show()
			blocks[#blocks + 1] = { frame = s.rc, h = 44 }
			pay:Hide()
		else
			s.rc:Hide()
			pay:Show()
			blocks[#blocks + 1] = { frame = pay, h = 40 }
		end
		local _, wline = requestMacro(d.key, d)
		s.whisper = wline or ("WTB summon to " .. d.dest .. " for " .. money(d.price))
		local why = requestBlock(d.key)
		if not UI.Driver(ui.confirmKey) then why = "gone" end
		local grouped = why == "group"
		setShown(s.warn, grouped)
		setShown(s.leave, grouped)
		if grouped then
			s.warn:SetWidth(180)
			s.warn:SetText("You're in a group. Leave it so the driver can invite you.")
			blocks[#blocks + 1] = { frame = s.warn, h = 36, dy = 4, also = s.leave }
		elseif why == "here" then
			-- (r53 B) blocked because the rider already stands in the driver's place: say what to do, in the card's width
			local place = type(W.AlreadyAt) == "function" and call(W.AlreadyAt, d.dest) or d.dest
			local cw = N(s.card:GetWidth()) or 0
			s.warn:SetWidth(math.max(180, cw - 2 * PAD))
			s.warn:SetText("This driver summons to " .. tostring(place) .. ", where you are now. Go back and pick a driver going somewhere else.")
			setShown(s.warn, true)
			blocks[#blocks + 1] = { frame = s.warn, h = 4 * (T.DrawnSize("sub") + T.Spacing("sub")), dy = 4 }
		end
		Mod.wideBlocks(s, blocks, d, total, line, info, again ~= nil)
		stackCard(s, blocks)
		-- (round 37, REV-r37-1) the map after the sheet and the route header are laid out: the pin keeps clear of the header
		if s.map:IsVisible() then updateMap(s.map, UI.Drivers()) end
		local inside = type(W.InInstance) == "function" and call(W.InInstance) == true
		local due = N(d.price) or 0
		if useRc then due = math.max(0, due - cover) end
		local payText = "Trade " .. money(d.price) .. " after you arrive"
		if useRc then
			payText = "Raincheck covers " .. money(math.min(cover, N(d.price) or 0)) .. (due > 0 and (" · trade " .. money(due) .. " after") or " · nothing to pay")
		end
		s.note:SetText(inside and "You're inside: your driver waits until you're out"
			or (payText .. (d.seats == 0 and " · group full" or "")))
		if rcId then s.rc.sub:SetText(s.note.wuberText or payText) end
		if why == "here" then
			local place = type(W.AlreadyAt) == "function" and call(W.AlreadyAt, d.dest) or d.dest
			s.request:SetLabel("You're already in " .. tostring(place) .. ".")
			s.request:SetActive(false)
		elseif why then
			s.request:SetLabel(BLOCK_TEXT[why] or "Can't request")
			s.request:SetActive(false)
		else
			local label = "Request summon · " .. money(d.price)
			if inCombat() then
				label = label .. " (in combat: no whisper)"
			elseif d.state == "busy" then
				label = label .. " (busy)"
			end
			local small = inCombat()
			if s.request.small ~= small then
				s.request.small = small
				T.SetFont(s.request.label, small and "body" or "heading", "bold")
			end
			s.request:SetLabel(label)
			s.request:SetActive(true)
		end
		Mod.sideUpdate()
	end
	-- the unfolded page (SPEC7 2.8; Finding shares it)
	local F = UI.Fold
	if type(F) == "table" and type(F.Register) == "function" then
		Mod.side.conf = s
		F.Register("confirm", { build = Mod.foldBuild, layout = Mod.foldLayout })
	end
	return s
end

---------------------------------------------------------------------------
-- Screen: Finding your driver
---------------------------------------------------------------------------

-- The rider's level chip ("Silver rider"); hidden before the first level.
local function tierChip(parent)
	local c = T.Chip(parent, "", "white")
	c:EnableMouse(true)
	T.Tip(c, "Your rider level", function()
		local tier, rides, _, nextAt = nil, nil, nil, nil
		if type(W.TierProgress) == "function" then tier, rides, _, nextAt = call(W.TierProgress) end
		rides = N(rides)
		if nextAt and rides then
			local n = nextAt - rides
			return "Bronze from 3 rides, Silver from 10, Gold from 25. " .. n .. (n == 1 and " more ride" or " more rides") .. " to the next level."
		end
		return "Bronze from 3 rides, Silver from 10, Gold from 25. Drivers see your level."
	end)
	function c.Update(self)
		if not W.Advanced() then
			self:Hide()
			return
		end
		local tier = type(W.Tier) == "function" and N(call(W.Tier)) or 0
		tier = clamp(math.floor(tier or 0), 0, 3)
		if tier < 1 then
			self:Hide()
			return
		end
		local name = type(W.TierName) == "function" and S(call(W.TierName, tier)) or T.TIER[tier].name
		self:SetChip(name .. " rider", T.TIER[tier].colour)
		self:Show()
	end
	c:Hide()
	return c
end
UI.TierChip = tierChip

local function leaveRow(s, f, y)
	s.group = T.Text(f, "sub", "red", "CENTER", "medium")
	s.group:SetPoint("TOP", f, "TOP", 0, y)
	s.group:SetWidth(INNER)
	Try(s.group, "SetWordWrap", true)
	s.leave = T.Pill(f, "Leave group", "dark", 130, 32)
	s.leave:SetPoint("TOP", s.group, "BOTTOM", 0, -8)
	safeScript(s.leave, "OnClick", leaveGroup)
	T.Tip(s.leave, "Leave group", "Leave your group so the driver can invite you to theirs.") -- (HUNT-143) same words as the first pill
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
	local ring = T.Circle(centre, 84, "black", "BACKGROUND")
	ring:SetPoint("CENTER", centre, "CENTER")
	local art = T.Tex(centre, "portal", "ARTWORK")
	art:SetSize(74, 74)
	art:SetPoint("CENTER", centre, "CENTER")
	s.centre = centre

	s.title = T.Text(f, "display", "white", "CENTER", "bold")
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
	s.left = T.Text(f, "caption", "muted", "CENTER", "regular")
	s.left:SetPoint("TOP", track, "BOTTOM", 0, -8)
	leaveRow(s, f, -424)

	s.cancel = T.Pill(f, "Cancel request", "dark", T.MAIN.h, T.MAIN.h) -- (Design 2) the main button's place, a second button
	s.cancel:ClearAllPoints()
	s.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", T.MAIN.side, T.MAIN.foot)
	s.cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -T.MAIN.side, T.MAIN.foot)
	s.cancel:SetHeight(T.MAIN.h)
	safeScript(s.cancel, "OnClick", function() doCancel(false) end)
	T.Tip(s.cancel, "Cancel request", "Take back your request. Nothing to pay.", "ANCHOR_TOP")
	s.tier = tierChip(f)
	s.tier:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -((UI.HEAD_ROW or 44) + 4)) -- (design 2, C) under the window's buttons
	-- the route header (5.2), top left over the radar's corner
	s.route = Booking.RouteHeader(f, INNER - 120)
	s.route:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -12)
	s.route:SetFrameLevel((N(centre:GetFrameLevel()) or 0) + 2)

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
		-- (HUNT-27: ride.grouped is never set anywhere, so ask the roster itself)
		local grouped = rv and inGroup() and not inGroupWith(rv.driverKey)
		setShown(s.group, grouped)
		setShown(s.leave, grouped)
		if grouped then s.group:SetText("You're in a group. Leave it so " .. who .. " can invite you.") end
		s.cancel:SetLabel("Cancel request")
		s.tier:Update()
		if rv then
			s.route:SetMaxWidth(s.tier:IsShown() and (INNER - 120) or INNER)
			s.route:Update(rv.dest)
		end
		s.frameTick()
		Mod.sideUpdate()
	end

	function s.frameTick()
		local rv = rideView()
		local at = rv and rv.at
		-- (FAB-08) a request that goes by whisper waits 120 s (Net.Rides), so the bar runs over that, not 40
		local limit = (rv and rv.raw and rv.raw.noAddon) and 120 or REQUEST_TIMEOUT
		local left = at and (limit - (now() - at)) or limit
		left = clamp(left, 0, limit)
		s.fill:SetWidth(math.max(4, 260 * left / limit))
		s.left:SetText(math.ceil(left) .. " s")
	end
	return s
end

---------------------------------------------------------------------------
-- Unfolded (SPEC7 2.8 "confirm", also Finding): booking left, the trip on the map right
---------------------------------------------------------------------------

local side = { holder = nil, about = nil, conf = nil, mode = nil, dest = nil }
Mod.side = side
-- "About this driver" (2.3.2, I29: it covered the south of both continents in the side pane): a
-- card in the booking column under the driver card; its top, heading, each line, bottom
local ABOUT = { top = 10, head = 18, line = 16, pad = 8 }
local ABOUT_TIGHT = { top = 4, head = 14, line = 13, pad = 3 } -- folded, when the sheet is full (r19, F3)
Mod.DIAL_SHORT = 62 -- folded, squeezed: the flight card's short form (Booking's layoutDial)
Mod.PVP_COMPACT = 50 -- ... and the PvP warning's compact form (T.AlertCard:SetCompact)
Mod.ROW_AGAIN = 90 -- the driver card's height with the "10th ride with Mia" chip
local DIAL_WIDE = 96 -- the unfolded dial's height (the bigger arc), plus its line under the verdict
local DIAL_LINE = 16

-- Unfolded, when everything still fits over the Request pill: the dial at 324 x 96 and the
-- savings pill under it (the pill's words leave the dial then). blocks: Confirm's stack.
function Mod.widenDial(s, blocks, d, total, line)
	local need = 58 + (s.headExtra or 0)
	for _, b in ipairs(blocks) do need = need + b.h + GAP end
	local room = 544 - WIDE_TOP - (54 + PAD + 8)
	-- (round 9, S9) the line stays under the verdict as folded (no separate pill): the bigger dial
	-- grows by the line's height
	local h = DIAL_WIDE + (line and DIAL_LINE or 0)
	local rest = need - blocks[1].h
	s.dial:SetSize(INNER, h)
	h = h + (s.dial.extra or 0) -- (round 22, C1) a verdict wrapped onto two lines
	if rest + h > room then
		s.dial:SetSize(INNER, 88)
		blocks[1].h = 88 + (s.dial.extra or 0)
		return false
	end
	blocks[1].h = h
	return true
end

-- the rides with this driver in the trips kept
local function ridesWith(d)
	local n = 0
	local trips = (W.db and type(W.db.rides) == "table") and W.db.rides or {}
	for _, t in ipairs(trips) do
		if type(t) == "table" and (S(t.driverKey) == d.key or (S(t.driver) and W.Key(S(t.driver)) == d.key)) then n = n + 1 end
	end
	return n
end

-- (I29) "10th ride with Mia" for a returning rider, else nil
function Mod.againLine(d)
	if type(d) ~= "table" or not d.key then return nil end
	local n = ridesWith(d)
	if n < 1 then return nil end
	return ordinal(n + 1) .. " ride with " .. tostring(d.short or d.name or "")
end

-- "About this driver": rides with you (the trips kept), the fare against the usual one to that
-- place (3 or more drivers go there), who clicks the portal. Unknown lines are left out.
local function aboutLines(d)
	local lines = {}
	local n = ridesWith(d)
	lines[1] = n == 0 and ("Your first ride with " .. d.short) or (ordinal(n + 1) .. " ride with " .. d.short)
	local prices = {}
	for _, o in ipairs(UI.Drivers()) do
		local p = N(o.price)
		if p and o.dest and (o.dest == d.dest or (type(W.SamePlace) == "function" and call(W.SamePlace, o.dest, d.dest) == true)) then
			prices[#prices + 1] = p
		end
	end
	local price = N(d.price)
	if price and #prices >= 3 then
		table.sort(prices)
		local usual = prices[math.floor((#prices + 1) / 2)]
		local diff = price - usual
		if math.abs(diff) < 100 then
			lines[#lines + 1] = "The usual fare to " .. d.dest .. " (" .. money(usual) .. ")"
		elseif diff < 0 then
			lines[#lines + 1] = money(-diff) .. " under the usual " .. money(usual) .. " to " .. d.dest
		else
			lines[#lines + 1] = money(diff) .. " over the usual " .. money(usual) .. " to " .. d.dest
		end
	end
	local team = N(d.team) or 0
	lines[#lines + 1] = team >= 3 and "Their crew clicks the portal" or "Bring friends to click the portal"
	return lines
end
Mod.aboutLines = aboutLines

-- (I29) the "10th ride with Mia" chip under the driver line (made the first time it is wanted)
function Mod.againChip(card)
	if card.again then return card.again end
	local c = T.Chip(card.row, "", "muted")
	c:SetPoint("TOPLEFT", card.row, "TOPLEFT", 74, -58)
	c:EnableMouse(true)
	T.Tip(c, "Rides with this driver", "Counted from the trips Wuber keeps on this account.")
	c:Hide()
	card.again = c
	return c
end

-- the card (made on the first unfold, in Confirm's sheet; placed by Confirm's stack, unfolded only)
function Mod.aboutBuild(card)
	local a = T.Card(card, INNER, 60, { colour = "card", radius = 16, shadow = false })
	a.head = T.Text(a, "sub", "white", "LEFT", "bold")
	a.head:SetPoint("TOPLEFT", a, "TOPLEFT", 16, -ABOUT.top)
	a.head:SetText("About this driver")
	a.lines = {}
	for i = 1, 3 do
		local fs = T.Text(a, "caption", "muted", "LEFT", "regular")
		fs:SetPoint("TOPLEFT", a, "TOPLEFT", 16, -(ABOUT.top + ABOUT.head + (i - 1) * ABOUT.line))
		fs:SetWidth(INNER - 32)
		a.lines[i] = fs
	end
	a:EnableMouse(true)
	T.Tip(a, "About this driver", "Your rides with this driver (the trips Wuber keeps) and their fare against other drivers to the same place.")
	a:Hide()
	side.about = a
end

-- the heading and lines at one of the spacings (ABOUT, or ABOUT_TIGHT folded when the sheet is full);
-- both paths call it so a tight folded layout never leaves the unfolded card's lines too close
local function placeAbout(a, m)
	a.head:ClearAllPoints()
	a.head:SetPoint("TOPLEFT", a, "TOPLEFT", 16, -m.top)
	for i, fs in ipairs(a.lines) do
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", a, "TOPLEFT", 16, -(m.top + m.head + (i - 1) * m.line))
	end
end

-- (2.3.2, S3) folded, "About this driver" shows too when the sheet has the room (the card is made the first time it
-- is wanted). Every line stays while a tighter card or the short flight card makes the room; only then the fare
-- line, then the crew line, leave. Nothing is made when it can't fit.
function Mod.foldedAbout(s, blocks, d, again)
	local a = side.about
	if not W.Advanced() then
		if a then a:Hide() end
		return
	end
	local lines = aboutLines(d)
	if again then table.remove(lines, 1) end
	local room = 544 - 100 - (54 + PAD + 8)
	local need = 58 + (s.headExtra or 0)
	for _, b in ipairs(blocks) do need = need + b.h + GAP end
	local at = #blocks
	for i, b in ipairs(blocks) do
		if b.frame == s.card.row then at = i end
	end
	-- (r19, F3) with the flight card and a PvP warning both up the card was dropped (Google's
	-- shot 8). Tiers: as is; then a tighter card, one line only. The
	-- "how you pay" row always stays (what you trade matters more); if neither fits, About is hidden.
	local tight = false
	local h
	local function sized(m, n) return m.top + m.head + n * m.line + m.pad end
	local function find(n0, base)
		local n = n0
		while n >= 1 do
			if base + sized(tight and ABOUT_TIGHT or ABOUT, n) + GAP <= room then return n end
			n = n - 1
		end
		return 0
	end
	-- the fare line, then the crew line, leave first (the trimmed set keeps the last)
	local function trim(n)
		while #lines > n do table.remove(lines, #lines > 2 and 2 or #lines) end
	end
	local n = find(#lines, need)
	-- what the short flight card (62) and the compact PvP warning (50) give back, same words
	-- (r46, REV-r46-1) a wrapped headline takes that room: About steps aside rather than the flight card going short
	local save = 0
	if (s.headExtra or 0) == 0 then
		for _, b in ipairs(blocks) do
			-- b.h already includes the wrapped verdict line (dial.extra), which the short card keeps
			local short = Mod.DIAL_SHORT + (s.dial and s.dial.extra or 0)
			if b.frame == s.dial and b.h > short then save = save + b.h - short end
			if b.frame == s.pvp and b.h > Mod.PVP_COMPACT then save = save + b.h - Mod.PVP_COMPACT end
		end
	end
	local squeezed = false
	-- (decisions X3) no line leaves while the sheet can still make the room: first the tighter card with every
	-- line, then the short flight card too (a driver line that wrapped took 13 off the sheet and the crew line went)
	if n < #lines then
		tight = true
		if find(#lines, need) == #lines then
			n = #lines
		elseif save > 0 and find(#lines, need - save) == #lines then
			n = #lines
			squeezed = true
		else
			tight = false
		end
	end
	if n < 1 then
		tight = true
		n = find(#lines, need)
	end
	-- last tier: the flight card goes short and the PvP warning compact for the lines that still fit
	if n < 1 and save > 0 then
		n = find(#lines, need - save)
		squeezed = n >= 1
	end
	if n < 1 then
		tight = false
		if a then a:Hide() end
		return
	end
	if squeezed then
		for _, b in ipairs(blocks) do
			if b.frame == s.dial and b.h > Mod.DIAL_SHORT then
				s.dial:SetSize(INNER, Mod.DIAL_SHORT)
				b.h = Mod.DIAL_SHORT + (s.dial.extra or 0)
			elseif b.frame == s.pvp and b.h > Mod.PVP_COMPACT then
				b.h = Mod.PVP_COMPACT
				s.pvp:SetCompact(true)
			end
		end
	end
	trim(n)
	if not a then
		Mod.aboutBuild(s.card)
		a = side.about
	end
	local m = tight and ABOUT_TIGHT or ABOUT
	h = sized(m, #lines)
	table.insert(blocks, at + 1, { frame = a, h = h })
	a:SetHeight(h)
	placeAbout(a, m)
	for i, fs in ipairs(a.lines) do
		fs:SetText(lines[i] or "")
		setShown(fs, lines[i] ~= nil)
	end
	if not a:IsShown() then A.FadeIn(a, 0.2) end
end

-- (I29) unfolded, "About this driver" goes under the driver card when the column has room; it
-- comes before the bigger dial (the dial stays 88 when both don't fit). Folded it shows when it fits (foldedAbout).
-- again: the driver card already says "10th ride with Mia" (the card leaves that line out).
function Mod.wideBlocks(s, blocks, d, total, line, info, again)
	local a = side.about
	if not W.Advanced() then
		if a then a:Hide() end
		return
	end
	if not s.wide then
		Mod.foldedAbout(s, blocks, d, again)
		return
	end
	if not a then
		if info then Mod.widenDial(s, blocks, d, total, line) end
		return
	end
	local lines = aboutLines(d)
	if again then table.remove(lines, 1) end
	local h = ABOUT.top + ABOUT.head + #lines * ABOUT.line + ABOUT.pad
	local at = #blocks
	for i, b in ipairs(blocks) do
		if b.frame == s.card.row then at = i end
	end
	table.insert(blocks, at + 1, { frame = a, h = h })
	local need = 58 + (s.headExtra or 0)
	for _, b in ipairs(blocks) do need = need + b.h + GAP end
	local room = 544 - WIDE_TOP - (54 + PAD + 8)
	local fits = (info and Mod.widenDial(s, blocks, d, total, line)) or need <= room
	if not fits then
		table.remove(blocks, at + 1)
		a:Hide()
		if info then Mod.widenDial(s, blocks, d, total, line) end
		return
	end
	a:SetHeight(h)
	placeAbout(a, ABOUT)
	for i, fs in ipairs(a.lines) do
		fs:SetText(lines[i] or "")
		setShown(fs, lines[i] ~= nil)
	end
	if not a:IsShown() then A.FadeIn(a, 0.2) end
end

-- the side pane's holder (made on the first unfold): the map docks there; About this driver is
-- made now too (in the booking column)
function Mod.foldBuild(holder)
	side.holder = holder
	if side.conf and not side.about then Mod.aboutBuild(side.conf.card) end
end

-- the side pane for the page's driver: the route on the map, Here or World, the card
function Mod.sideUpdate()
	local s = side.conf
	if not (s and s.wide and side.holder) then return end
	local d, dest
	if ui.screen == "finding" then
		local rv = rideView()
		d = rv and UI.Driver(rv.driverKey) or nil
		dest = rv and rv.dest or nil
	else
		d = UI.Driver(ui.confirmKey) or s.last
		dest = d and d.dest or nil
	end
	local atDest = d and dest and requestBlock(d.key) == "here"
	s.map.routeDest = (not atDest) and dest or nil
	if s.map:IsVisible() then updateMap(s.map, UI.Drivers()) end
	-- (round 12, item 9) World first, else the rider's last pick on Here/World (WorldMap.Wanted)
	local WorldMod = W.Mod("UI.Rider.WorldMap")
	if side.dest ~= (dest or false) and type(WorldMod) == "table" and type(WorldMod.Show) == "function" then
		side.dest = dest or false
		local mode = type(WorldMod.Wanted) == "function" and WorldMod.Wanted() or "world"
		WorldMod.Show(mode, { holder = side.holder, route = dest and { to = dest } or false, focus = dest or false })
	end
end

-- folded: Confirm's map back on its strip; unfolded: docked in the side pane under Here/World
function Mod.foldLayout(unfolded, holder)
	local s = side.conf
	if not s then return end
	s.wide = unfolded and true or false
	local WorldMod = W.Mod("UI.Rider.WorldMap")
	-- (round 9, S9) unfolded: the route beside the back button, one header row; no grab handle
	s.route:ClearAllPoints()
	if s.wide then
		s.route:SetPoint("LEFT", s.back, "RIGHT", 10, 0)
	else
		s.route:SetPoint("BOTTOMLEFT", s.card, "TOPLEFT", PAD, 8)
	end
	setShown(s.card.grab, not s.wide)
	if s.wide then
		HomeMapMod.Dock(s.map, holder)
		if type(WorldMod) == "table" and type(WorldMod.Build) == "function" then WorldMod.Build(holder, { here = s.map }) end
	else
		HomeMapMod.Undock(s.map)
		s.dial:SetSize(INNER, 88)
	end
	side.dest = nil
	updateMap(s.map, UI.Drivers())
	Mod.sideUpdate()
	UI.Refresh(true)
end

-- internals other modules use (bound at load by later modules, or called late)
Mod.buildConfirm = buildConfirm
Mod.buildFinding = buildFinding
Mod.leaveGroup = leaveGroup
Mod.tierChip = tierChip
