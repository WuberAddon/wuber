-- Module: UI.Moments
-- Purpose: Ride toasts and minimap flash on RIDE (on arrival with a fare due it asks UI.OpenForPay,
--   from UI.Rider.Pay, to open the app on the pay screen), the milestone / level-up pop card (UI.Celebrate,
--   UI.ShowNextPop), favourite/watch online toasts.
-- API: UI.MilestoneIcon, UI.MilestoneInfo, UI.ShowNextPop, UI.Celebrate, UI.RaincheckOffer, UI.RaincheckDate, UI.RankCard
-- Internals: onRide, buildOffer, buildOfferCard, wireOffer, rankHeld, wireRank, buildRankCard
-- Uses: UI.Kit, UI.Rider.Ride
-- Later: UI.Share, UI.WhatsNew (PlaceBeside), UI.Tips (NoteTabAsked)
-- Events: listens Listen MILESTONE, Listen FAV_ONLINE, Listen WATCH_HIT, Listen RAINCHECK, Listen DRIVE_RANK, On PLAYER_REGEN_DISABLED, On PLAYER_REGEN_ENABLED; fires (none);
--   gives Mod.popCount()
--   (the accessor UI.Window reads pops through), Mod.WhyMilestone() (/wuber why: a held card's reason)
-- Standalone: no
-- Test: tests/ui/moments_test.lua
-- From: UI.lua 4122-4353 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Moments", { "UI.Kit", "UI.Rider.Ride" })
local KitMod = W.Mod("UI.Kit")
local RideMod = W.Mod("UI.Rider.Ride")
local ENDED = KitMod.ENDED
local N = KitMod.N
local RIDE_RANK = KitMod.RIDE_RANK
local S = KitMod.S
local call = KitMod.call
local driverView = KitMod.driverView
local inCombat = KitMod.inCombat
local money = KitMod.money
local now = KitMod.now
local rideActive = KitMod.rideActive
local rideView = KitMod.rideView
local safeScript = KitMod.safeScript
local ui = KitMod.ui
local invitePending = RideMod.invitePending
local T = W.Theme
local A = T.Animate
local Try = T.Try
local UI = W.UI

---------------------------------------------------------------------------
-- Ride toasts and the minimap flash
---------------------------------------------------------------------------

local function onRide()
	local rv = rideView()
	if not rv then return end
	-- the flight cost is quoted while the rider is still where they booked from
	if rideActive(rv) and rv.rank <= RIDE_RANK.ingroup then UI.FlightQuote(rv) end
	if rv.state == "done" then UI.CountFlightSaved(rv) end
	local seen = ui.toasted[rv.id]
	local mark = rv.state .. (rv.portalUp and "+portal" or "")
	if seen == mark then return end
	ui.toasted[rv.id] = mark
	ui.peek = nil -- the ride moved on: back to its screen
	local who, dest, price = rv.short, rv.dest, money(rv.price)
	if rv.portalUp then
		UI.Toast("Accept the summon to " .. dest .. "!", "summon")
	elseif rv.state == "accepted" then
		UI.Toast(who .. " accepted - " .. price .. " to " .. dest, "found")
	elseif rv.state == "invited" then
		if invitePending(rv) and not (rv.raw and W.Plain(rv.raw.autoAccepted) == true) then
			UI.Toast(who .. " invited you. Accept the invite.", "info")
		else
			UI.Toast("Joining " .. who .. "'s group", "info")
		end
	elseif rv.state == "arrived" then
		UI.Toast("You've arrived in " .. dest, "found")
		-- something still due: the app opens on the pay screen (UI.Rider.Pay; once per ride, not in combat)
		if UI.OpenForPay then UI.OpenForPay("arrived") end
	elseif rv.state == "paying" then
		-- the same amount the pay card and strip ask for: what is left, plus the chosen tip
		local due = UI.PayTotal and UI.PayTotal(rv)
		UI.Toast("Trade " .. (rv.payto or who) .. " " .. (due and due > 0 and money(due) or price), "info")
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
-- Moments: the milestone / level-up pop card (one at a time, never in combat or during a
-- ride), favourite and watch toasts. FX.lua plays the ride's own screen effects.
---------------------------------------------------------------------------

local POP_ICON = {
	first = "ride", hoursaver = "clock", daysaver = "clock", loyal = "heart", nightowl = "star",
	weekend = "summon", explorer = "pin", globetrotter = "pin", worldwalker = "pin",
}
local MEDIA_OK = {
	ride = true, star = true, pin = true, clock = true, heart = true, summon = true, check = true,
	trophy = true, coin = true, bell = true, circle = true, radar = true,
}

-- The Media glyph for a milestone id (levels: the trophy).
function UI.MilestoneIcon(id, m)
	id = S(id) or ""
	if id:match("^tier%d") then return "trophy" end
	if id:match("^rides%d") then return "trophy" end
	if POP_ICON[id] then return POP_ICON[id] end
	local icon = type(m) == "table" and S(m.icon)
	if icon and MEDIA_OK[icon] then return icon end
	return "star"
end

function UI.MilestoneInfo(id)
	if type(W.MilestoneInfo) == "function" then
		local m = call(W.MilestoneInfo, id)
		if type(m) == "table" then return m end
	end
	if type(W.MILESTONES) == "table" then
		for _, m in ipairs(W.MILESTONES) do
			if type(m) == "table" and m.id == id then return m end
		end
	end
	return nil
end

local pops, popFrame = {}, nil

local function buildPop()
	local f = CreateFrame("Button", nil, UIParent)
	f:SetSize(310, 112)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetPoint("TOP", UIParent, "TOP", 0, -84)
	f.under = CreateFrame("Frame", nil, f)
	f.under:SetAllPoints(f)
	f.under:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
	f.glow = T.OuterGlow(f.under, "gold", 0.55, 18)
	f.card = T.Card(f, 310, 112, { colour = { 0.09, 0.08, 0.17, 0.98 }, radius = 20, border = "goldDeep" })
	f.card:SetAllPoints(f)
	local host = f.card -- everything sits on the card (a child frame draws over its parent)
	f.disc = CreateFrame("Frame", nil, host)
	f.disc:SetSize(68, 68)
	f.disc:SetPoint("LEFT", f, "LEFT", 18, 0)
	f.halo = T.Tex(f.disc, "glow", "BACKGROUND")
	f.halo:SetSize(130, 130)
	f.halo:SetPoint("CENTER", f.disc, "CENTER")
	f.halo:SetVertexColor(T.RGB("gold", 0.45))
	f.circle = T.Circle(f.disc, 64, "accent", "ARTWORK")
	f.circle:SetPoint("CENTER", f.disc, "CENTER")
	f.ring = T.Tex(f.disc, "ring", "ARTWORK", 1)
	f.ring:SetSize(68, 68)
	f.ring:SetPoint("CENTER", f.disc, "CENTER")
	f.ring:SetVertexColor(T.RGB("gold"))
	f.icon = T.Icon(f.disc, "trophy", 34, "ink", "OVERLAY")
	f.icon:SetPoint("CENTER", f.disc, "CENTER")
	f.kicker = T.Text(host, "caption", "muted", "LEFT", "bold")
	f.kicker:SetPoint("TOPLEFT", f, "TOPLEFT", 100, -20)
	f.title = T.Text(host, "heading", "white", "LEFT", "bold")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 100, -36)
	f.title:SetWidth(196)
	f.sub = T.Text(host, "sub", "muted", "LEFT", "regular")
	f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -5)
	f.sub:SetWidth(196)
	Try(f.sub, "SetWordWrap", true)
	Try(f.sub, "SetMaxLines", 2)
	f:RegisterForClicks("LeftButtonUp")
	safeScript(f, "OnClick", function(self)
		self.token = (self.token or 0) + 1
		A.FadeOut(self, 0.15, function() W.After(0.3, UI.ShowNextPop) end)
		UI.Toggle(true)
		-- Settings would stay up over the Trips tab: put it away first (as UI.Show does)
		if ui.settingsOpen and UI.CloseSettings then UI.CloseSettings(true) end
		UI.SelectTab("Trips")
		-- the tap asked for Trips: the first-open login tip must not move the phone to Home
		local tips = W.Mod("UI.Tips")
		if type(tips) == "table" and type(tips.NoteTabAsked) == "function" then tips.NoteTabAsked() end
	end)
	T.Tip(f, "Nice one!", "Click to see your trips and milestones.")
	f:Hide()
	return f
end

-- why the next card waits ("combat", "ride": a ride not ended), or nil when it may show
local function popHeld()
	if inCombat() then return "combat" end
	local rv = rideView()
	if rv and not ENDED[rv.state] then return "ride" end
	return nil
end
local function popAllowed() return popHeld() == nil end

function UI.ShowNextPop()
	if popFrame and popFrame:IsShown() then return end
	if #pops == 0 then return end
	if not popAllowed() then
		if not ui.popWait then
			ui.popWait = true
			W.After(3, function()
				ui.popWait = false
				UI.ShowNextPop()
			end)
		end
		return
	end
	local p = table.remove(pops, 1)
	popFrame = popFrame or buildPop()
	local f = popFrame
	ui.pop = f
	-- another card at the top of the screen (What's new) must not sit over this one and take its tap
	f:Raise()
	f.kicker:SetText(p.kicker)
	f.title:SetText(p.title)
	f.sub:SetText(p.sub or "")
	f.icon:SetTexture(T.MEDIA .. p.icon)
	f.circle:SetVertexColor(T.RGB(p.colour or "accent"))
	f.data = p
	A.Pop(f, 0.45)
	A.Pop(f.disc, 0.5, 0.12)
	W.Sound(888) -- the level-up fanfare
	if T.FxLevel() ~= "off" and W.FX and type(W.FX.Play) == "function" then
		local ok, err = pcall(W.FX.Play, "milestone", f.disc, { size = 180 })
		if not ok then W.Error("FX milestone", err) end
	end
	local token = (f.token or 0) + 1
	f.token = token
	W.After(7, function()
		if f.token ~= token then return end
		A.FadeOut(f, 0.4, function() W.After(0.3, UI.ShowNextPop) end)
	end)
end

-- Celebrate(mainId, ids): the MILESTONE event. One card: a level-up wins, other new
-- milestones are mentioned on it.
function UI.Celebrate(mainId, ids)
	mainId = S(mainId)
	if not mainId then return end
	local m = UI.MilestoneInfo(mainId) or { name = mainId }
	local p = { icon = UI.MilestoneIcon(mainId, m) }
	local level = tonumber(mainId:match("^tier(%d)$"))
	local others = 0
	if type(ids) == "table" then
		for _, id in ipairs(ids) do
			if id ~= mainId and not tostring(id):match("^tier") then others = others + 1 end
		end
	end
	if level then
		local name = type(W.TierName) == "function" and S(call(W.TierName, level)) or (T.TIER[level] and T.TIER[level].name) or "New"
		p.kicker = "Level up"
		p.title = "You're a " .. name .. " rider!"
		p.sub = "Drivers now see you as a " .. name .. " rider."
		p.colour = T.TIER[level] and T.TIER[level].colour or "gold"
	else
		p.kicker = "Milestone"
		p.title = (S(m.name) or mainId) .. " unlocked!"
		p.sub = S(m.desc) or ""
	end
	if others > 0 then p.sub = p.sub .. " Plus " .. others .. (others == 1 and " more milestone." or " more milestones.") end
	pops = { p } -- one pop slot: the newest wins
	UI.ShowNextPop()
	UI.Refresh()
end

W.Listen("MILESTONE", function(mainId, ids) UI.Celebrate(mainId, ids) end)

-- Favourites and watched places coming online (Net merges them and keeps the rate limits).
local function onlineToast(kind, driver, count)
	local d = driverView(driver)
	if not d or inCombat() then return end
	count = N(count) or 1
	local text
	if kind == "fav" then
		if count > 1 then
			text = count .. " favourites online · " .. d.short .. " " .. money(d.price) .. " to " .. d.dest
		else
			text = d.short .. " is online · " .. money(d.price) .. " to " .. d.dest
		end
	else
		-- a pinned bounty's place is served now: say so; the bounty ends
		local bplace = ui.bountyPlace
		local B = W.Bounty
		local mine = type(B) == "table" and type(B.Mine) == "function" and call(B.Mine) or nil
		if type(mine) == "table" and S(mine.place) then bplace = mine.place end
		-- the bounty just ended as served (BOUNTY listener): its place still counts for 10 s
		local sv = ui.bountyServed
		if not bplace and sv and sv.at and now() - sv.at < 10 then bplace = sv.place end
		local same = bplace and type(W.SamePlace) == "function" and call(W.SamePlace, bplace, d.dest) == true
		if same then
			if ui.bountyServed and ui.bountyServed.at and now() - ui.bountyServed.at < 10 then return end
			text = d.short .. " now summons to " .. d.dest .. " · " .. money(d.price) .. ". Your bounty ended."
			ui.bountyServed = { place = bplace, at = now() }
		elseif count > 1 then
			text = count .. " drivers to " .. d.dest .. " are online · from " .. money(d.price)
		else
			text = "A driver to " .. d.dest .. " is online · " .. d.short .. " " .. money(d.price)
		end
	end
	UI.Toast(text, kind, function() UI.Show("confirm", d.key) end)
end
-- The rider's bounty ended because a driver serves the place now (Net.Bounty: BOUNTY("mine", nil,
-- "served", driverName)): one toast, whichever of this and WATCH_HIT comes first.
W.Listen("BOUNTY", function(kind, b, why, who)
	if kind ~= "mine" then return end
	if not b and why == "served" then
		local place = ui.bountyPlace
		if place and not (ui.bountyServed and ui.bountyServed.at and now() - ui.bountyServed.at < 10) and not inCombat() then
			UI.Toast((S(who) and W.Short(S(who)) or "A driver") .. " now summons to " .. place .. ". Your bounty ended.", "watch")
			ui.bountyServed = { place = place, at = now() }
		end
	end
	if type(b) == "table" and S(b.place) then ui.bountyPlace = S(b.place) end
	if not b then ui.bountyPlace = nil end
	UI.Refresh(true)
end)
-- A bounty pinned before a /reload: remember its place now, so the toast still knows it if Home is never opened.
W.OnLogin(function()
	local B = W.Bounty
	local m = type(B) == "table" and type(B.Mine) == "function" and call(B.Mine) or nil
	if type(m) == "table" and S(m.place) then ui.bountyPlace = S(m.place) end
end)
W.Listen("FAV_ONLINE", function(driver, count) onlineToast("fav", driver, count) end)
W.Listen("WATCH_HIT", function(driver, count) onlineToast("watch", driver, count) end)

---------------------------------------------------------------------------
-- A raincheck offered: "Anita offers a raincheck: one free summon, up to 50s, until
-- 25 Nov. Accept / No thanks". Active only once the driver's Wuber gets the Accept.
---------------------------------------------------------------------------

-- "25 Nov"
function UI.RaincheckDate(at)
	at = N(at)
	if not at or type(date) ~= "function" then return nil end
	local ok, text = pcall(date, "%d %b", at)
	if ok and type(text) == "string" then return (text:gsub("^0", "")) end
	return nil
end

local offerFrame, offerCard
-- (Design 2) the offer is a sheet: inside the phone (over the whole window, so it takes the window's scale)
-- while the app is open, and the same look as a card that stands alone at the top of the screen while the app is
-- closed. Title "Raincheck", the words, "Accept" as the main button, "No thanks" as a link.
local SHEET_H = 214
local function wireOffer(f)
	local body = f.body
	f.head = T.Text(body, "heading", "white", "LEFT", "bold")
	f.head:SetPoint("TOPLEFT", body, "TOPLEFT", 16, -4)
	f.head:SetPoint("TOPRIGHT", body, "TOPRIGHT", -16, -4)
	Try(f.head, "SetWordWrap", true)
	f.sub = T.Text(body, "sub", "muted", "LEFT", "regular")
	f.sub:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 0, -6)
	f.sub:SetPoint("TOPRIGHT", f.head, "BOTTOMRIGHT", 0, -6)
	Try(f.sub, "SetWordWrap", true)
	Try(f.sub, "SetMaxLines", 3)
	local function answer(yes)
		local R = W.Raincheck
		local id = f.id
		if not id or type(R) ~= "table" then f:Close() return end
		-- (r47) read the driver's name first: Accept/Decline can raise RAINCHECK, which shows the next offer on this card
		local who = f.who
		local ok = call(yes and R.Accept or R.Decline, id)
		-- a refused Accept (three held, send failed) leaves the offer open to come back; a decline retires it
		if ok or not yes then
			ui.rcSeen = ui.rcSeen or {}
			ui.rcSeen[id] = true
		end
		-- (round 34) "Raincheck kept" waits for Net.Raincheck's RAINCHECK "kept" (the listener below)
		if yes and ok then
			ui.rcKept = ui.rcKept or {}
			ui.rcKept[id] = who or "this crew"
		elseif yes then
			UI.Toast("Couldn't answer right now", "warn")
		end
		-- (r47) only close when the card still shows this offer, not a newly shown next one
		if f.id == id then f:Close() end
	end
	f.yes = f:MainButton("Accept", function() answer(true) end,
		"Your next summon from this crew costs nothing, up to the amount shown. Nothing is paid back in gold.")
	f.no = f:Link("No thanks", function() answer(false) end, "Turn it down. Nothing changes.")
	-- the home map's location pill steps aside while the sheet shows (HomeMap reads ui.rcOffer)
	safeScript(f, "OnShow", function() UI.Refresh(true) end)
	safeScript(f, "OnHide", function()
		if f.HeadDown then f:HeadDown() end -- (r49, E1-07) the header's buttons come down with the sheet
		UI.Refresh(true)
	end)
	f:Hide()
end

-- (E3b-09) the room under the raincheck sheet: the tab bar's height, or 0 while the bar is away (the live ride page)
local function sheetFoot()
	if type(UI.TabsHidden) == "function" and UI.TabsHidden() then return 0 end
	return UI.TABBAR_H or 56
end

-- (E3b-01) the holder is the whole screen from the window's top down to the tab bar (or the foot): the dim lies over
-- the page whole, the header zone too, so no page row is cut by the sheet's edge; the dim's header strip takes no
-- mouse (T.Sheet opts.head), so the header's buttons stay usable
local function placeOffer(f)
	local holder = f.holder
	if not (holder and ui.win) then return end
	f.foot = sheetFoot()
	holder:ClearAllPoints()
	holder:SetPoint("TOPLEFT", ui.win, "TOPLEFT", 0, 0)
	holder:SetPoint("BOTTOMRIGHT", ui.win, "BOTTOMRIGHT", 0, f.foot)
end

local function buildOffer()
	-- a holder above everything the window draws (home cards sit in a higher strata than the window itself)
	local holder = CreateFrame("Frame", nil, ui.win)
	-- (design 2) the sheet rests on the tab bar (or the foot while the bar is away) and the tabs stay free; a tab
	-- click closes the offer as its x would
	holder:SetFrameStrata("FULLSCREEN_DIALOG")
	holder:SetFrameLevel(400)
	local f = T.Sheet(holder, SHEET_H, "Raincheck", { head = UI.HEAD_H or 56 })
	f.host, f.holder = ui.win, holder
	placeOffer(f)
	local tab
	holder:SetScript("OnUpdate", function()
		if not f.open then tab = nil return end
		if f.foot ~= sheetFoot() then placeOffer(f) end
		if tab == nil then tab = ui.tab or false end
		if (ui.tab or false) ~= tab then tab = nil f:Close() end
	end)
	wireOffer(f)
	return f
end

local function buildOfferCard()
	local f = T.SheetCard(UIParent, 310, SHEET_H, "Raincheck")
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetPoint("TOP", UIParent, "TOP", 0, -84)
	wireOffer(f)
	return f
end

-- Shows the newest raincheck offer the rider hasn't answered (W.Raincheck.Mine(), state "offered").
function UI.RaincheckOffer()
	local R = W.Raincheck
	if type(R) ~= "table" or type(R.Mine) ~= "function" then return nil end
	local list = call(R.Mine)
	if type(list) ~= "table" then return nil end
	ui.rcSeen = ui.rcSeen or {}
	for _, rc in ipairs(list) do
		local id = type(rc) == "table" and S(rc.id)
		if id and S(rc.state) == "offered" and not ui.rcSeen[id] then
			local win = ui.win
			local inApp = (win and win:IsShown()) and true or false
			if inApp and offerFrame and offerFrame.host ~= win then offerFrame = nil end
			local f
			if inApp then
				offerFrame = offerFrame or buildOffer()
				f = offerFrame
				if offerCard and offerCard:IsShown() then offerCard:Close(true) end
			else
				offerCard = offerCard or buildOfferCard()
				f = offerCard
				if offerFrame and offerFrame:IsShown() then offerFrame:Close(true) end
			end
			f.id = id
			local who = S(rc.driver) and W.Short(S(rc.driver)) or S(rc.service) or "Your driver"
			f.who = who
			f.head:SetText(who .. " offers a raincheck")
			local cover, untilDay = N(rc.cover), UI.RaincheckDate(rc.expires)
			f.sub:SetText("One summon at no charge" .. (cover and (", up to " .. money(cover)) or "") .. (untilDay and (", until " .. untilDay) or "") .. ".")
			ui.rcOffer = f
			if f.holder then placeOffer(f) end
			if not (f.open and f:IsShown()) then f:Open() end
			return f
		end
	end
	return nil
end

-- (round 34) an Accept the driver got: "kept"; one lost ("No player named"): "offer" again, the card comes back
W.Listen("RAINCHECK", function(op, id)
	local who = ui.rcKept and id and ui.rcKept[id]
	if who and (op == "kept" or op == "offer") then
		ui.rcKept[id] = nil
		if op == "kept" then
			UI.Toast("Raincheck kept: one summon at no charge from " .. who, "found")
		else
			if ui.rcSeen then ui.rcSeen[id] = nil end
			UI.Toast("Couldn't answer right now", "warn")
		end
	end
	UI.RaincheckOffer()
end)

---------------------------------------------------------------------------
-- Driver ranks, part 3: the new-title card and guild brag pill
---------------------------------------------------------------------------

local RANK_SHEET_H = 176
local rankCard, lastRank

local function rankHeld()
	local why = popHeld()
	if why then return why end
	if popFrame and popFrame:IsShown() then return "pop" end
	if (offerFrame and offerFrame:IsShown()) or (offerCard and offerCard:IsShown()) then return "offer" end
	if rankCard and rankCard:IsShown() then return "rank" end
	return nil
end

local function myShortName()
	local me = S(W.myName)
	if not me and type(W.UnitName) == "function" then me = S(call(W.UnitName, "player")) end
	if me and type(W.Short) == "function" then
		local short = S(call(W.Short, me))
		if short then return short end
	end
	return me or "Driver"
end

local function rankBragLine(f)
	local rung = N(f.rung)
	local n = N(f.rankN)
	local title = S(f.rankTitle)
	if not rung or not n or not title then return nil end
	local ch = W.Char()
	local r = type(ch) == "table" and type(ch.rank) == "table" and ch.rank or nil
	local brag = r and N(r.bragRung) or 0
	if brag >= rung then return nil end
	local who = myShortName()
	-- a run of four digits is refused by the line checks (a phone-number look), so 1000 is written 1,000
	n = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	if title == "Has The Knowledge" then
		return "[Wuber] " .. who .. " has summoned " .. n .. " riders and Has The Knowledge."
	end
	return "[Wuber] " .. who .. " has summoned " .. n .. " riders and is now a " .. title .. "."
end

local function wireRank(f)
	local body = f.body
	f.head = T.Text(body, "heading", "white", "LEFT", "bold")
	f.head:SetPoint("TOPLEFT", body, "TOPLEFT", 16, -4)
	f.head:SetPoint("TOPRIGHT", body, "TOPRIGHT", -16, -4)
	Try(f.head, "SetWordWrap", true)
	f.sub = T.Text(body, "sub", "muted", "LEFT", "regular")
	f.sub:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 0, -6)
	f.sub:SetPoint("TOPRIGHT", f.head, "BOTTOMRIGHT", 0, -6)
	Try(f.sub, "SetWordWrap", true)
	Try(f.sub, "SetMaxLines", 2)
	-- the brag pill: the same dark pill every share pill is (T.Pill), never a colour of its own
	local p = T.Pill(body, "Tell the guild", "dark", 124, 30)
	p:SetPoint("TOPLEFT", f.sub, "BOTTOMLEFT", 0, -14)
	T.Tip(p, "Tell the guild", "Posts one line in guild chat, on this click: your new title and your verified summons. Party or raid chat when you have no guild. Once for each title.")
	p:Hide()
	f.pill = p
	local Sh = UI.Share
	if type(Sh) == "table" and type(Sh.Register) == "function" then
		call(Sh.Register, p, function() return rankBragLine(f) end, {
			label = "Tell the guild",
			guild = true,
			onShared = function()
				local rung = N(f.rung)
				if rung then
					local ch = W.Char()
					if type(ch) == "table" then
						if type(ch.rank) ~= "table" then ch.rank = { n = N(f.rankN) or 0, seen = {} } end
						ch.rank.bragRung = rung
					end
				end
				p:Hide()
				f:Close()
			end,
		})
	end
	safeScript(f, "OnShow", function() UI.Refresh(true) end)
	safeScript(f, "OnHide", function()
		UI.Refresh(true)
		-- the window may be shut: its refresh would not put the share overlay away from the closed card
		if type(UI.SyncSecure) == "function" then call(UI.SyncSecure) end
		W.After(0.3, UI.RankCard)
	end)
	f:Hide()
end

local function buildRankCard()
	local f = T.SheetCard(UIParent, 310, RANK_SHEET_H, "New title")
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetPoint("TOP", UIParent, "TOP", 0, -84)
	wireRank(f)
	return f
end

-- the New title card stands beside the phone like the What's new card: clear of Wuber's window, the floating big
-- button and the mini console (UI.WhatsNew's PlaceBeside); where there is no such room it keeps the top of the screen
local function placeRank(f)
	local NewsMod = W.Mod("UI.WhatsNew")
	local ok, placed = false, false
	if type(NewsMod) == "table" and type(NewsMod.PlaceBeside) == "function" then
		ok, placed = pcall(NewsMod.PlaceBeside, f, 310, RANK_SHEET_H, -84)
	end
	if not (ok and placed) then
		f:ClearAllPoints()
		f:SetPoint("TOP", UIParent, "TOP", 0, -84)
	end
end

-- while it shows: the phone or the big button moved under it, so it stands beside them again
local function watchRank(token)
	if token ~= ui.rankWatch or not (rankCard and rankCard:IsShown()) then return end
	placeRank(rankCard)
	W.After(1, function() watchRank(token) end)
end

-- Shows the waiting new-title card if a rung >= 2 hasn't been seen yet.
function UI.RankCard()
	local ch = W.Char()
	local r = type(ch) == "table" and type(ch.rank) == "table" and ch.rank or nil
	local rung = r and N(r.cardRung)
	if not rung or rung < 2 then return nil end
	rung = math.floor(rung)
	local seen = N(r.cardSeen) or 0
	if seen >= rung then return nil end
	if rankHeld() then
		if not ui.rankWait then
			ui.rankWait = true
			W.After(3, function()
				ui.rankWait = false
				UI.RankCard()
			end)
		end
		return nil
	end
	local n = N(r.n)
	local title
	if lastRank and lastRank.rung == rung then
		if not n or n < (lastRank.n or 0) then n = lastRank.n end
		title = S(lastRank.title)
	end
	if not title and type(W.RANKS) == "table" and type(W.RANKS[rung]) == "table" then
		title = S(W.RANKS[rung].title)
	end
	if not title and n and type(W.RankOf) == "function" then
		local _, t = call(W.RankOf, n)
		title = S(t)
	end
	if not n or n < 0 then
		n = (type(W.RANKS) == "table" and type(W.RANKS[rung]) == "table" and N(W.RANKS[rung].at)) or 0
	end
	n = math.floor(n)
	title = title or "New title"
	rankCard = rankCard or buildRankCard()
	local f = rankCard
	f.rung = rung
	f.rankN = n
	f.rankTitle = title
	f.head:SetText(title)
	f.sub:SetText(n .. " verified summons")
	r.cardSeen = rung
	local Sh = UI.Share
	if type(Sh) == "table" and type(Sh.Sync) == "function" then call(Sh.Sync) end
	placeRank(f)
	if not (f.open and f:IsShown()) then f:Open() end
	ui.rankWatch = (ui.rankWatch or 0) + 1
	local token = ui.rankWatch
	W.After(1, function() watchRank(token) end)
	if type(UI.SyncSecure) == "function" then call(UI.SyncSecure) end
	return f
end

W.Listen("DRIVE_RANK", function(n, rung, title, rungChanged)
	rung = N(rung)
	if rungChanged ~= true or not rung or rung < 2 then return end
	rung = math.floor(rung)
	lastRank = { n = N(n) or 0, rung = rung, title = S(title) }
	local ch = W.Char()
	if type(ch) ~= "table" then return end
	if type(ch.rank) ~= "table" then ch.rank = { n = N(n) or 0, seen = {} } end
	ch.rank.cardRung = rung
	UI.RankCard()
end)

-- the pill's words and its overlay follow a fight even when the window is shut (the window's refresh does nothing then)
local function rankSync()
	if not (rankCard and rankCard:IsShown()) then return end
	local Sh = UI.Share
	if type(Sh) == "table" and type(Sh.Sync) == "function" then call(Sh.Sync) end
	if type(UI.SyncSecure) == "function" then call(UI.SyncSecure) end
end
W.On("PLAYER_REGEN_DISABLED", function() W.After(0.5, rankSync) end)
W.On("PLAYER_REGEN_ENABLED", function()
	rankSync()
	W.After(1, UI.RankCard)
end)

W.OnLogin(function()
	UI.RankCard()
end)

-- internals other modules use (bound at load by later modules, or called late)
Mod.onRide = onRide
-- pops is rebound (UI.Celebrate keeps one pop slot), so UI.Window reads its length through this
function Mod.popCount() return #pops end

-- (REC-01) /wuber why: the milestone / level-up card held back right now (UI.ShowNextPop's own
-- rules, read only), or nil when none waits
local POP_WHY = {
	up = "Milestone card: waits until the card on screen closes.",
	combat = "Milestone card: waits until combat ends.",
	ride = "Milestone card: waits until your ride ends.",
}
function Mod.WhyMilestone()
	if #pops == 0 then return nil end
	if popFrame and popFrame:IsShown() then return POP_WHY.up end
	local why = popHeld()
	return why and POP_WHY[why] or nil
end
