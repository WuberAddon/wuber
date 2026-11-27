-- Module: UI.Rider.Home
-- Purpose: Home screen: watch bell, "your usual", raid card, empty state, place chips, buildHome,
--   UI.LayoutCards, per-frame home animation.
-- (Design 2, items 9 and 10) The drivers are ROWS of one card (s.rows, a T.RowGroup; ui.cards[key] is the driver's
-- row); the OpenMap line is that card's last row (s.mapHint, with its x). "Your usual" is one flat card without a
-- button. Home has ONE main button (T.MainButton, 12 above the page's bottom), one of: s.main "Ride again · <place> ·
-- <price>" while "Your usual" shows (the list's clip then ends above it); s.empty.ping "Ping drivers" on the empty
-- screen; s.empty.bounty.pin "Pin <price>" while a bounty is being set. Drivers listed and no usual: none. Your
-- bounty is a plain row (s.bountyChip: coin, "Your bounty: 50s for Gadgetzan", the minutes left, "Take down" as a link).
-- API: UI.IsWatching, UI.ToggleWatch, UI.RaidHere, UI.BuildRaidCard, UI.FillPlaceChips, UI.LayoutCards,
--   UI.BountyMine, UI.BountyPlace, UI.PinBounty, UI.CancelBounty, UI.BOUNTY_PICKS, UI.BOUNTY_NOTE
-- Internals: buildHome, homeFrame, buildBounty, buildBountyChip, fillBounty, foldLayout, buildOwnChip, ownBeacon, atHere,
--   bountyMiss; Mod.WhyUsual, Mod.WhyBounty (/wuber why: why "Your usual" or a bounty offer is not on Home)
-- (2.3.2) Open as a driver: Home says "You're open as a driver" with what riders see (place, price, state; a tap
-- goes to the Drive tab) - the empty state's pill, or a chip above the list when others are listed too; you are
-- never a bookable card. The empty line's usual hours need 5 sightings on 3 days (local time); else the last
-- driver seen. No bounty or "usual" offer for the city you stand in.
-- Uses: UI.Kit, UI.Rider.HomeMap, UI.Rider.Cards
-- Later: UI.Fold (Register: the unfolded "ride" page), UI.Rider.WorldMap (Build, Show: its Here/World
--   control and the world view in the side pane)
-- Unfolded: the drivers' sheet fills the left pane from y 16; Home's map moves
-- into the side pane (HomeMap's Dock: 360 x 512 under the Here/World control, the rider centred).
-- Events: listens Listen SETTINGS; fires SETTINGS
-- Standalone: no
-- Test: tests/ui/rider/home_test.lua
-- From: UI.lua 1859-2470 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Rider.Home", { "UI.Kit", "UI.Rider.HomeMap", "UI.Rider.Cards" })

local KitMod = W.Mod("UI.Kit")
local HomeMapMod = W.Mod("UI.Rider.HomeMap")
local CardsMod = W.Mod("UI.Rider.Cards")
local BODY_H = KitMod.BODY_H
local CARD_GAP = KitMod.CARD_GAP
local CARD_H = KitMod.CARD_H
local INNER = KitMod.INNER
local LIST_TOP = KitMod.LIST_TOP
local N = KitMod.N
local PAD = KitMod.PAD
-- (#317, run 5) the empty state's top under the card above it: the 8 under a card and the 4 the stack always had, less
-- the list's own top pad (the stack's offsets count from the list's top)
local EMPTY_GAP = 8 + 4 - (tonumber(W.UI and W.UI.LIST_PAD) or 14)
local S = KitMod.S
local SHEET_TOP = KitMod.SHEET_TOP
local WIN_W = KitMod.WIN_W
local call = KitMod.call
local clamp = KitMod.clamp
local money = KitMod.money
local myKey = KitMod.myKey
local now = KitMod.now
local onNetwork = KitMod.onNetwork
local ordinal = KitMod.ordinal
local prominence = KitMod.prominence
local safeScript = KitMod.safeScript
local setShown = KitMod.setShown
local ui = KitMod.ui
local buildMapPanel = HomeMapMod.buildMapPanel
local updateMap = HomeMapMod.updateMap
local applySearch = CardsMod.applySearch
local buildCard = CardsMod.buildCard
local buildSearch = CardsMod.buildSearch
local fillCard = CardsMod.fillCard
local matches = CardsMod.matches
local updatedText = CardsMod.updatedText
local T = W.Theme
local noGlow = T.NoGlow -- (design round 1) the shared no-op glow, Theme.Widgets
local A = T.Animate
local Try = T.Try
local UI = W.UI

-- (HUNT-52) the first seconds after login: the network join is still pending, so "can't reach" waits
-- (the join is tried at once and again every 10 s; after JOIN_GRACE the line shows as before)
local JOIN_GRACE = 15
local loginAt = nil
W.OnLogin(function() loginAt = now() end)

-- "Tell me when a driver to X comes online" (W.ToggleWatch from Net; W.db.watch by place key).
local function watchKey(place)
	local fn = W.WatchKey or W.PlaceKey
	if type(fn) == "function" then
		local k = call(fn, place)
		if type(k) == "string" and k ~= "" then return k end
	end
	return place and place:lower() or nil
end

local function isWatching(place)
	if not place then return false end
	if type(W.IsWatched) == "function" then return call(W.IsWatched, place) == true end
	local w = W.db and W.db.watch
	if type(w) ~= "table" then return false end
	return w[watchKey(place)] ~= nil or w[place] ~= nil
end
UI.IsWatching = isWatching

local function toggleWatch(place)
	if not place then return end
	local on
	if type(W.ToggleWatch) == "function" then
		on = call(W.ToggleWatch, place)
		if type(on) ~= "boolean" then on = isWatching(place) end
	elseif W.db then
		if type(W.db.watch) ~= "table" then W.db.watch = {} end
		local k = watchKey(place)
		on = not W.db.watch[k]
		W.db.watch[k] = on or nil
		W.Fire("SETTINGS", "watch")
	end
	UI.Toast(on and ("We'll tell you when a driver to " .. place .. " comes online") or ("No more alerts for " .. place), on and "watch" or "info")
	UI.Refresh(true)
	return on
end
UI.ToggleWatch = toggleWatch

local function bellTip(self)
	local place = (type(self) == "table" and self.place) or (ui.filter and ui.filter.place)
	if not place then return "Search for a place first." end
	if isWatching(place) then return "You'll get a note when a driver to " .. place .. " comes online. Click to stop." end
	return "Get a note the moment a driver to " .. place .. " comes online."
end

-- (2.3.2, B6) whether the rider already stands in this place (no bounty or "usual" offer for it)
local function atHere(place)
	if type(W.AlreadyAt) ~= "function" then return false end
	return call(W.AlreadyAt, place) ~= nil
end

-- "Your usual": the most frequent destination and driver, when that driver is online.
local function usualRide()
	if type(W.Usual) ~= "function" then return nil end
	local u, k2 = call(W.Usual)
	local dest, key
	if type(u) == "table" then
		dest = S(u.dest)
		key = S(u.driverKey) or S(u.key) or (S(u.driver) and W.Key(u.driver))
	else
		dest, key = S(u), S(k2)
	end
	if not key then return nil end
	local d = UI.Driver(key)
	if not d or d.state == "paused" or d.key == myKey() then return nil end
	-- the card must follow the driver's place now: booking goes to d.dest, so a usual place the
	-- driver no longer serves is not offered (never "Undercity" on the card while they summon to Orgrimmar)
	if dest and d.dest and dest ~= d.dest and not (type(W.SamePlace) == "function" and call(W.SamePlace, dest, d.dest) == true) then return nil end
	-- no "Ride again" to the city the rider is standing in (WhyUsual says "you are already there")
	if atHere(d.dest or dest) then return nil end
	return d, d.dest or dest
end

-- the booking of "Your usual" (the card and Home's main button): re-checked at click time, the driver may have moved
local function usualGo(u)
	if not u.key then return end
	local cd = usualRide()
	if not cd or cd.key ~= u.key then
		u.key = nil
		u:Hide()
		UI.Refresh(true)
		return
	end
	UI.Show("confirm", u.key)
end

-- (design 2) one flat card: the grey caption, the place, "with <driver>", the price in gold. No button inside it:
-- "Ride again" is Home's main button; the whole card still opens the booking.
local USUAL_H = 80
local function buildUsual(content)
	local u = CreateFrame("Button", nil, content)
	u:SetSize(INNER, USUAL_H)
	u:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, 0)
	u:SetFrameLevel(content:GetFrameLevel() + 3)
	u.under = u
	u.glow = noGlow() -- (design 1) one flat card colour: no gold halo, no violet gradient
	u.bg = T.Rounded(u, "card", 16, "BACKGROUND", 0)
	u.kicker = T.Text(u, "caption", "muted", "LEFT", "bold")
	u.kicker:SetPoint("TOPLEFT", u, "TOPLEFT", 16, -13)
	u.kicker:SetText("Your usual")
	u.title = T.Text(u, "heading", "white", "LEFT", "bold")
	u.title:SetPoint("TOPLEFT", u, "TOPLEFT", 16, -30)
	u.title:SetWidth(200)
	u.sub = T.Text(u, "sub", "muted", "LEFT", "regular")
	u.sub:SetPoint("TOPLEFT", u, "TOPLEFT", 16, -54)
	u.sub:SetWidth(200)
	u.price = T.Text(u, "title", "gold", "RIGHT", "bold")
	u.price:SetPoint("RIGHT", u, "RIGHT", -16, 0)
	u:RegisterForClicks("LeftButtonUp")
	safeScript(u, "OnEnter", function(self) self.bg:SetColor("hover") end)
	safeScript(u, "OnLeave", function(self) self.bg:SetColor("card") end)
	T.Press(u, { fill = u.bg })
	safeScript(u, "OnClick", usualGo)
	T.Tip(u, "Your usual", function(self)
		return "Your most frequent ride. One click takes you straight to booking it."
	end)
	u:Hide()
	return u
end

-- "Request a summon": your raid runs raid summons (learned from the raid's HI,
-- W.Drive.RaidHere()). One card at the top of Home; the click asks the raid's runner (an
-- addon message, nothing in chat). Free, nothing to pay.
function UI.RaidHere()
	local DRr = W.Drive
	local info = type(DRr) == "table" and call(DRr.RaidHere) or nil
	if type(info) ~= "table" or not S(info.runner) then return nil end
	return info
end

local function raidAction()
	local DRr = W.Drive
	local info = UI.RaidHere()
	if not info then return end
	if info.queued then
		call(DRr.RaidCancel)
		UI.Toast("You're off the summon list", "info")
	else
		local ok, why = call(DRr.RaidAsk)
		if ok == false then UI.Toast(S(why) or "Couldn't ask right now", "warn") else UI.Toast("Asked " .. W.Short(info.runner) .. "'s Warlocks for a summon", "found") end
	end
	UI.Refresh(true)
end

function UI.BuildRaidCard(content)
	local u = CreateFrame("Frame", nil, content)
	u:SetSize(INNER, 76)
	u:SetFrameLevel(content:GetFrameLevel() + 3)
	u.bg = T.Rounded(u, { 0.16, 0.12, 0.3, 1 }, 16, "BACKGROUND", 0)
	u.edge = T.Rounded(u, "accent", 17, "BACKGROUND", -1, 1)
	u.kicker = T.Text(u, "caption", "muted", "LEFT", "bold")
	u.kicker:SetPoint("TOPLEFT", u, "TOPLEFT", 16, -13)
	u.kicker:SetText("Your raid · summons at no charge")
	u.title = T.Text(u, "body", "white", "LEFT", "bold")
	u.title:SetPoint("TOPLEFT", u, "TOPLEFT", 16, -30)
	u.title:SetWidth(INNER - 32)
	Try(u.title, "SetWordWrap", true)
	Try(u.title, "SetMaxLines", 0)
	u.sub = T.Text(u, "sub", "muted", "LEFT", "regular")
	u.sub:SetPoint("TOPLEFT", u.title, "BOTTOMLEFT", 0, -4)
	u.sub:SetWidth(INNER - 32)
	Try(u.sub, "SetWordWrap", true)
	Try(u.sub, "SetMaxLines", 0)
	-- (2.4) Requesting is Home's ONE main button; the card never draws a gold button (Cancel stays dark while queued)
	u.go = T.Pill(u, "Cancel request", "dark", 148, 32)
	u.go:SetPoint("BOTTOMRIGHT", u, "BOTTOMRIGHT", -12, 12)
	safeScript(u.go, "OnClick", raidAction)
	T.Tip(u.go, "Cancel my request", "Takes you off your raid's summon list.")
	u.go:Hide()
	u:EnableMouse(true)
	T.Tip(u, "Raid summons", "Your raid leader runs summons at no charge for the raid with Wuber. Ask here instead of typing in raid chat.")
	function u.Paint(self, info)
		local who = W.Short(info.runner)
		local sums = type(info.summoners) == "table" and info.summoners or {}
		self.title:SetText(info.queued and (info.state == "summoning" and "Your summon is coming" or "You're on the summon list") or ("Get summoned to " .. (S(info.place) or "the raid")))
		local pos = N(info.position)
		local sub = info.queued and (pos and (pos == 1 and "You're next" or ("You're " .. ordinal(pos) .. " in line")) or "Accept when it pops")
			or (who .. " runs summons" .. (#sums > 0 and (" · " .. #sums .. (#sums == 1 and " Warlock" or " Warlocks")) or ""))
		self.sub:SetWidth(info.queued and (INNER - 168) or (INNER - 32))
		self.sub:SetText(sub)
		setShown(self.go, info.queued and true or false)
		if info.queued then
			self.go:SetLabel("Cancel request")
			self.go:SetStyle("dark")
		end
		local titleH = math.max(18, math.ceil(N(self.title:GetStringHeight()) or 18))
		local subH = math.max(14, math.ceil(N(self.sub:GetStringHeight()) or 14))
		self:SetHeight(math.max(info.queued and 92 or 76, 30 + titleH + 4 + subH + 14))
	end
	u:Hide()
	return u
end

---------------------------------------------------------------------------
-- Want-to-go bounties (SPEC7 5.3, rider side): when nobody summons to a searched place, pin a
-- bounty (a wish, never a payment) so drivers see it; a chip on Home while it lasts. The wire
-- and the rules (one active, 30 min, ends when you book or a driver starts serving it) are
-- W.Bounty's (Net.Bounty); Home only asks and shows.
---------------------------------------------------------------------------

UI.BOUNTY_PICKS = { 5000, 7500, 10000 }
UI.BOUNTY_NOTE = "A bounty is a wish, not a payment. You still pay the driver's fare."
local BOUNTY_TTL = 30 * 60

-- the rider's active bounty: { place, copper, at, sends } or nil
function UI.BountyMine()
	local B = W.Bounty
	if type(B) ~= "table" or type(B.Mine) ~= "function" then return nil end
	local b = call(B.Mine)
	if type(b) ~= "table" or not S(b.place) then return nil end
	return b
end

-- A searched place a bounty can be pinned for: a known place (not a zone) no open driver serves.
function UI.BountyPlace(place, all)
	place = S(place)
	if not place then return nil end
	local B = W.Bounty
	if type(B) == "table" and type(B.Place) == "function" then
		place = S(call(B.Place, place))
		if not place then return nil end
	end
	if type(W.ExactPlace) ~= "function" then return nil end
	local p = call(W.ExactPlace, place)
	if type(p) ~= "table" or p.kind == "zone" or not S(p.name) then return nil end
	for _, d in ipairs(all or UI.Drivers()) do
		if d.state == "open" then
			local same = type(W.SamePlace) == "function" and call(W.SamePlace, d.dest, p.name)
			if same == true or d.dest:lower() == p.name:lower() then return nil end
		end
	end
	return p.name
end

function UI.PinBounty(place, copper)
	local B = W.Bounty
	copper = N(copper)
	if not (place and copper and copper > 0) or type(B) ~= "table" or type(B.Pin) ~= "function" then return false end
	-- (Net.Bounty also watches the place: the "now summons" toast tells you when someone serves it)
	local ok, why = call(B.Pin, place, copper)
	if ok then
		ui.bountyPlace = place
		UI.Toast("Bounty pinned: drivers see you want " .. place, "watch")
	else
		local WHY = { served = "Someone summons there now: book them", ride = "Not during a ride", place = "Pick a town or city" }
		UI.Toast(WHY[S(why) or ""] or "Couldn't pin a bounty right now", "warn")
	end
	UI.Refresh(true)
	return ok and true or false
end

function UI.CancelBounty()
	local B = W.Bounty
	local ok = type(B) == "table" and type(B.Cancel) == "function" and call(B.Cancel)
	ui.bountyPlace = nil
	if ok then UI.Toast("Bounty taken down", "info") end
	UI.Refresh(true)
	return ok and true or false
end

local function minutesLeft(b)
	local t = type(time) == "function" and time() or 0
	local left = N(b.left) or ((N(b.at) or t) + BOUNTY_TTL - t)
	return math.max(1, math.ceil(left / 60))
end

-- the quick picks and Pin, inside the empty state
local function buildBounty(e)
	local bb = CreateFrame("Frame", nil, e)
	bb:SetSize(INNER, 120)
	bb:SetPoint("TOPLEFT", e, "TOPLEFT", PAD, -74)
	bb.picks = {}
	local labels = { "50s", "75s", "1g", "Custom" }
	-- (#268) each pick as wide as its words as the game draws them (about 6% over the font table) plus the pill's two ends, the
	-- spare shared evenly: "Custom" is cut in four equal parts at the maintainer's size
	local need, sum = {}, 0
	for i, label in ipairs(labels) do
		need[i] = math.ceil((tonumber(T.MeasureText(label, "sub", "medium")) or 40) * 1.07) + 30 + 2
		sum = sum + need[i]
	end
	local spare = (INNER - 3 * 8 - sum) / #labels
	local px = 0
	for i, label in ipairs(labels) do
		local PW = spare >= 0 and need[i] + spare or need[i] * (INNER - 3 * 8) / sum
		local b = T.Pill(bb, label, "dark", PW, 30)
		b:SetPoint("TOPLEFT", bb, "TOPLEFT", px, 0)
		px = px + PW + 8
		b.copper = UI.BOUNTY_PICKS[i]
		safeScript(b, "OnClick", function(self)
			-- (round 13, I23) while the bounty is up its lit price is only a mark
			local up = UI.BountyMine()
			if up and bb.place and W.SamePlace and call(W.SamePlace, up.place, bb.place) == true then return end
			if self.copper then
				bb.copper = self.copper
				bb.custom:Hide()
			else
				-- (2.3.2) the box keeps its text: the state follows it (Enter on unchanged text commits nothing)
				bb.copper = bb.custom:Text() ~= "" and W.ParseMoney(S(bb.custom:Text()) or "") or nil
				bb.custom:Show()
				Try(bb.custom.edit, "SetFocus")
			end
			bb.Paint()
		end)
		T.Tip(b, label == "Custom" and "Your own amount" or ("Pledge " .. label), "What you'd like to pay for a summon there. Drivers see it; nothing is paid now.")
		bb.picks[i] = b
	end
	bb.custom = T.Field(bb, 120, 30, { max = 12, placeholder = "e.g. 60s", size = "caption", onCommit = function(text)
		bb.copper = W.ParseMoney(S(text) or "")
		bb.Paint()
	end })
	bb.custom:SetPoint("TOPLEFT", bb, "TOPLEFT", 0, -38)
	T.Tip(bb.custom.edit, "Your own amount", "Type an amount like 60s or 1g 20s, then press Enter.")
	bb.custom:Hide()
	-- (design 2) "Pin <price>" is Home's main button while a bounty is being set: at the foot of the empty state
	-- (which ends 8 above the page's bottom), not beside the amounts. It hides while your bounty for this place is
	-- up: "Take down" is then the link on your bounty's row.
	bb.pin = T.MainButton(bb, "Pin")
	bb.pin:ClearAllPoints()
	bb.pin:SetPoint("BOTTOMLEFT", e, "BOTTOMLEFT", T.MAIN.side, T.MAIN.foot - 8)
	bb.pin:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -T.MAIN.side, T.MAIN.foot - 8)
	safeScript(bb.pin, "OnClick", function(self)
		if self.inactive then return end
		local mine = UI.BountyMine()
		if mine and bb.place and W.SamePlace and call(W.SamePlace, mine.place, bb.place) then
			UI.CancelBounty()
		else
			UI.PinBounty(bb.place, bb.copper)
		end
	end)
	T.Tip(bb.pin, "Pin a bounty", function()
		return "Drivers nearby see that you want " .. (bb.place or "this place") .. " for about " .. money(bb.copper or 0)
			.. " for 30 minutes. " .. UI.BOUNTY_NOTE
	end)
	bb.note = T.Text(bb, "caption", "muted", "LEFT", "regular")
	bb.note:SetPoint("TOPLEFT", bb, "TOPLEFT", 0, -40)
	bb.note:SetWidth(INNER)
	Try(bb.note, "SetWordWrap", true)
	bb.note:SetText(UI.BOUNTY_NOTE)
	function bb.Paint()
		local mine = UI.BountyMine()
		local pinned = mine and bb.place and W.SamePlace and call(W.SamePlace, mine.place, bb.place) == true
		-- (round 13, I23) a bounty up: its price lit (Custom for an amount of your own), the others
		-- quiet; Take down is a quiet button (gold is for pinning)
		local live = pinned and N(mine.copper) or nil
		local pick
		for _, b in ipairs(bb.picks) do if live and b.copper == live then pick = b end end
		for _, b in ipairs(bb.picks) do
			local on
			if live then
				on = b == pick or (not pick and not b.copper)
			else
				on = (b.copper and b.copper == bb.copper) or (not b.copper and bb.custom:IsShown())
			end
			b:SetStyle(on and "violet" or "ghost")
			b:SetActive(not pinned or on)
		end
		setShown(bb.pin, not pinned)
		if not pinned then
			bb.pin:SetLabel(bb.copper and ("Pin " .. money(bb.copper)) or "Pin")
			bb.pin:SetActive(bb.copper ~= nil and bb.copper > 0)
		end
		-- the note sits under the amounts, or under the box for an amount of your own
		bb.note:ClearAllPoints()
		bb.note:SetPoint("TOPLEFT", bb, "TOPLEFT", 0, bb.custom:IsShown() and -78 or -40)
	end
	bb.copper = UI.BOUNTY_PICKS[1]
	bb:Hide()
	return bb
end

-- (design 2) Your bounty, at the top of the list: a plain row of a card of its own: coin, "Your bounty: 50s for
-- Gadgetzan", the minutes left under it, and "Take down" as a link (c.close; no x). c.text is the row's title.
local function buildBountyChip(content)
	local c = T.RowGroup(content, INNER)
	c:SetFrameLevel(content:GetFrameLevel() + 3)
	local tipBody = function()
		return "Drivers see that you want this place. It ends when you book a ride, a driver starts serving it, you take it "
			.. "down, or after 30 minutes. " .. UI.BOUNTY_NOTE
	end
	c.row = c:Row({ icon = "coin", title = "", sub = "", right = "button", value = "Take down",
		onClick = function() UI.CancelBounty() end, tip = { title = "Your bounty", body = tipBody } })
	c.text, c.close = c.row.title, c.row.button
	c.close:SetStyle("ghost")
	T.Tip(c.close, "Take the bounty down", "Drivers stop seeing it.")
	c:Hide()
	return c
end

-- (2.3.2, B4) You, open as a driver: what riders see of you, never a card you could book. The chip on a
-- list that has other drivers too; the pill in the empty state. A tap goes to the Drive tab.
local function goDrive()
	if type(UI.SelectTab) == "function" then UI.SelectTab("Drive") end
end
local function ownBeacon()
	local b = type(W.DriverBeacon) == "function" and call(W.DriverBeacon) or nil
	if type(b) ~= "table" or b.only then return nil end -- a private test beacon is not on the public network
	return b
end
local OWN_STATE = { open = "open", busy = "busy", paused = "paused" }
local function ownPlace(b) return S(b.destShown) or S(b.dest) or "somewhere" end
local function ownSummary(b)
	return ownPlace(b) .. " · " .. money(N(b.price) or 0) .. " · " .. (OWN_STATE[b.state] or "open")
end
local function ownTip()
	return "Riders see you like this, in their list and on the maps. You can't book yourself. Click to open the Drive tab."
end
local function buildOwnChip(content)
	local c = CreateFrame("Button", nil, content)
	c:SetSize(INNER, 28)
	c:SetFrameLevel(content:GetFrameLevel() + 3)
	c.fill = T.PillFill(c, { 0.2, 0.15, 0.32, 1 }, 28, "BACKGROUND", 0)
	c.icon = T.Icon(c, "summon", 14, "glow", "ARTWORK")
	c.icon:SetPoint("LEFT", c, "LEFT", 12, 0)
	c.text = T.Text(c, "sub", "white", "LEFT", "medium")
	c.text:SetPoint("LEFT", c, "LEFT", 32, 0)
	c.text:SetWidth(INNER - 48)
	c:RegisterForClicks("LeftButtonUp")
	T.Press(c, { fill = c.fill })
	safeScript(c, "OnClick", goDrive)
	T.Tip(c, "You're listed as a driver", ownTip)
	c:Hide()
	return c
end

-- (round 9, Y2) When drivers are usually around, from real times only: the rider's own rides
-- (W.db.rides[].at) and the last time each driver was heard (W.db.seenDrivers[].at), one per day
-- and hour, the last 60 days. (2.3.2, B5) Only with real evidence: at least 5 sightings on at least 3
-- different days, and half of them in one 3-hour stretch: "7-10pm" (the PC's own clock); else nil.
local function clockHour(h)
	h = h % 24
	local h12 = h % 12
	return (h12 == 0 and 12 or h12), h < 12 and "am" or "pm"
end
local function usualHours()
	local d0 = W.db
	if type(d0) ~= "table" or type(date) ~= "function" then return nil end
	local stamp = N(call(time)) or 0
	local seen, byHour, n, days, nDays = {}, {}, 0, {}, 0
	local function add(at)
		at = N(at)
		if not at or at > stamp + 3600 or stamp - at > 60 * 86400 then return end
		local t = call(date, "*t", at)
		if type(t) ~= "table" or not N(t.hour) then return end
		local k = (t.year or 0) .. "-" .. (t.yday or 0) .. "-" .. t.hour
		if seen[k] then return end
		seen[k] = true
		local dk = (t.year or 0) .. "-" .. (t.yday or 0)
		if not days[dk] then days[dk] = true nDays = nDays + 1 end
		byHour[t.hour] = (byHour[t.hour] or 0) + 1
		n = n + 1
	end
	for _, r in ipairs(type(d0.rides) == "table" and d0.rides or {}) do if type(r) == "table" then add(r.at) end end
	for _, s in pairs(type(d0.seenDrivers) == "table" and d0.seenDrivers or {}) do if type(s) == "table" then add(s.at) end end
	if n < 5 or nDays < 3 then return nil end
	local best, bestN = nil, 0
	for h = 0, 23 do
		local c = (byHour[h] or 0) + (byHour[(h + 1) % 24] or 0) + (byHour[(h + 2) % 24] or 0)
		if c > bestN then best, bestN = h, c end
	end
	if not best or bestN * 2 < n then return nil end
	local first, last = best, best + 2
	while not byHour[first % 24] do first = first + 1 end
	while not byHour[last % 24] do last = last - 1 end
	local a, sa = clockHour(first)
	local b, sb = clockHour(last + 1)
	return sa == sb and (a .. "-" .. b .. sb) or (a .. sa .. "-" .. b .. sb)
end

-- The last time Wuber heard any driver (W.db.seenDrivers, kept 14 days): "3 days ago", or nil.
local function lastSeenDriver()
	local list = W.db and W.db.seenDrivers
	if type(list) ~= "table" then return nil end
	local stamp, last = N(call(time)) or 0, nil
	for _, s in pairs(list) do
		local at = type(s) == "table" and N(s.at)
		if at and at <= stamp + 60 and (not last or at > last) then last = at end
	end
	if not last then return nil end
	local ago = stamp - last
	if ago < 86400 then return W.Ago(ago) end
	local days = math.floor(ago / 86400)
	return days == 1 and "yesterday" or (days .. " days ago")
end

-- The place the rider usually goes (W.Usual: most rides), for the empty Home's watch and bounty.
local function usualPlace()
	if type(W.Usual) ~= "function" then return nil end
	local u = call(W.Usual)
	local dest = type(u) == "table" and S(u.dest) or nil
	local p = dest and type(W.FindPlace) == "function" and call(W.FindPlace, dest) or nil
	return type(p) == "table" and S(p.name) or dest
end
-- (2.3.2, B6) whether the rider already stands in this place (no bounty or "usual" offer for it)
Mod.usualHours, Mod.usualPlace = usualHours, usualPlace

local function buildEmpty(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints(parent)
	f.disc = CreateFrame("Frame", nil, f)
	f.disc:SetSize(56, 56)
	f.disc:SetPoint("TOP", f, "TOP", 0, -24)
	f.pulse = A.Pulse(f.disc, { size = 150, colour = "magenta", alpha = 0.4, period = 2.6, rings = 3, start = false })
	f.circle = T.Circle(f.disc, 56, "card", "ARTWORK")
	f.circle:SetPoint("CENTER", f.disc, "CENTER")
	f.glyph = T.Icon(f.disc, "summon", 28, "muted", "OVERLAY")
	f.glyph:SetPoint("CENTER", f.disc, "CENTER")
	f.title = T.Text(f, "body", "white", "CENTER", "bold")
	f.title:SetPoint("TOP", f.disc, "BOTTOM", 0, -16)
	f.title:SetWidth(INNER)
	T.Lines(f.title, 2) -- (2.4 fix round, ING-07) a long place wraps, never cut
	f.sub = T.Text(f, "sub", "muted", "CENTER", "regular")
	f.sub:SetPoint("TOP", f.title, "BOTTOM", 0, -4)
	f.sub:SetWidth(280)
	Try(f.sub, "SetWordWrap", true)
	f.subHit = CreateFrame("Frame", nil, f)
	f.subHit:SetAllPoints(f.sub)
	f.subHit:EnableMouse(true)
	T.Tip(f.subHit, function() return f.subTipTitle end, function() return f.subTipBody end)
	f.subHit:Hide()
	-- (design 2) "Ping drivers" is Home's main button on the empty screen: at the foot (the empty state ends 8 above
	-- the page's bottom, so 4 here is the main button's 12)
	f.ping = T.MainButton(f, "Ping drivers", { foot = T.MAIN.foot - 8 })
	-- the bell: a note when a driver to the searched place comes online
	f.watch = T.Pill(f, "Tell me", "dark", INNER, 36)
	f.watch:SetPoint("TOP", f.sub, "BOTTOM", 0, -14)
	f.watch.icon = T.Icon(f.watch, "bell", 16, "glow", "OVERLAY")
	f.watch.icon:SetPoint("LEFT", f.watch, "LEFT", 18, 0)
	f.watch.label:ClearAllPoints()
	f.watch.label:SetPoint("LEFT", f.watch.icon, "RIGHT", 8, 0)
	f.watch.label:SetPoint("RIGHT", f.watch, "RIGHT", -16, 0)
	safeScript(f.watch, "OnClick", function(self)
		local place = self.place or (ui.filter and ui.filter.place)
		if place then toggleWatch(place) end
	end)
	T.Tip(f.watch, "Tell me when a driver comes online", function(self)
		local place = (type(self) == "table" and self.place) or (ui.filter and ui.filter.place)
		local body = bellTip(self)
		return place and ("Tell me when one to " .. place .. " opens\n" .. body) or body
	end)
	f.watch:Hide()
	-- (round 9, Y2) nobody online: a bounty for the rider's usual place (opens its bounty card)
	f.bountyGo = T.Pill(f, "Pin a bounty", "dark", INNER, 36)
	f.bountyGo:SetPoint("TOP", f.watch, "BOTTOM", 0, -2)
	f.bountyGo.icon = T.Icon(f.bountyGo, "coin", 16, "gold", "OVERLAY")
	f.bountyGo.icon:SetPoint("LEFT", f.bountyGo, "LEFT", 18, 0)
	f.bountyGo.label:ClearAllPoints()
	f.bountyGo.label:SetPoint("LEFT", f.bountyGo.icon, "RIGHT", 8, 0)
	f.bountyGo.label:SetPoint("RIGHT", f.bountyGo, "RIGHT", -16, 0)
	Try(f.bountyGo.label, "SetJustifyH", "LEFT")
	safeScript(f.bountyGo, "OnClick", function(self)
		if not self.place then return end
		applySearch(self.place, true)
	end)
	T.Tip(f.bountyGo, "Pin a bounty", function(self)
		local body = "Tell drivers you want " .. (self.place or "a place") .. ": pick what you'd pay, and drivers nearby see it for "
			.. "30 minutes. " .. UI.BOUNTY_NOTE
		return self.place and ("Pin a bounty for " .. self.place .. "\n" .. body) or body
	end)
	f.bountyGo:Hide()
	safeScript(f.ping, "OnClick", function(self)
		if self.inactive then return end
		local ok, why
		if type(W.Ping) == "function" then
			ok, why = call(W.Ping)
		elseif type(W.SendChannel) == "function" then
			call(W.SendChannel, "Q")
			ok = true
		end
		if ok then
			W.Sound("ping")
			UI.Toast(why == "recent" and "Drivers were just asked - they're answering" or "Asked every driver to check in", "info")
			ui.pingAt = now()

		elseif why == "offline" then
			UI.Toast("Can't reach the network right now", "warn")
		elseif tonumber(why) then
			ui.pingAt = now() - (20 - tonumber(why))
			UI.Toast("You can ping again in " .. why .. " s", "info")
		else
			UI.Toast("Can't ping right now", "warn")
		end
		UI.Refresh(true)
	end)
	T.Tip(f.ping, "Ping drivers", "Ask every driver online to check in now, in case one was missed.")
	-- "Why can't I see anyone?": the page that explains how drivers are found
	-- (2.3.2, B4) open as a driver, nobody else listed: what riders see of you (a tap: the Drive tab)
	f.own = T.Pill(f, "", "dark", 300, 38)
	f.own:SetPoint("TOP", f.sub, "BOTTOM", 0, -14)
	f.own.icon = T.Icon(f.own, "summon", 16, "glow", "OVERLAY")
	f.own.icon:SetPoint("LEFT", f.own, "LEFT", 18, 0)
	f.own.label:ClearAllPoints()
	f.own.label:SetPoint("LEFT", f.own.icon, "RIGHT", 8, 0)
	f.own.label:SetPoint("RIGHT", f.own, "RIGHT", -16, 0)
	Try(f.own.label, "SetJustifyH", "LEFT")
	safeScript(f.own, "OnClick", goDrive)
	T.Tip(f.own, "You're listed as a driver", ownTip)
	f.own:Hide()
	f.why = CreateFrame("Button", nil, f)
	f.why:SetSize(220, 24)
	f.why:RegisterForClicks("LeftButtonUp")
	f.why.label = T.Text(f.why, "sub", "glow", "CENTER", "medium")
	f.why.label:SetPoint("CENTER", f.why, "CENTER", 0, 0)
	f.why.label:SetText("Why?")
	f.why:SetPoint("TOP", f.sub, "BOTTOM", 0, -14)
	T.Press(f.why)
	safeScript(f.why, "OnClick", function()
		if type(UI.OpenHelp) == "function" then UI.OpenHelp("home") end
	end)
	T.Tip(f.why, "Why can't I see anyone?", "How Wuber finds drivers, and what helps when the list is short.")
	-- (2.4) empty screen: quiet OpenMap line directly under "Why can't I see anyone?" (both modes, no x)
	local mh = CreateFrame("Frame", nil, f)
	mh:SetSize(INNER, 18)
	mh.text = T.Text(mh, "sub", "muted", "CENTER", "regular")
	mh.text:SetPoint("TOPLEFT", mh, "TOPLEFT", 0, 0)
	mh.text:SetPoint("TOPRIGHT", mh, "TOPRIGHT", 0, 0)
	mh.text:SetWidth(INNER)
	Try(mh.text, "SetWordWrap", true)
	Try(mh.text, "SetMaxLines", 0)
	mh.text:SetText("Get OpenMap to see drivers on your world map")
	mh:EnableMouse(true)
	T.Tip(mh, "OpenMap", "Install the free OpenMap addon (on CurseForge) to see drivers, prices and your route on its world map. "
		.. "Without it you still see them on the game's own world map, and every driver here.")
	mh:Hide()
	f.mapHint = mh
	f:Hide()
	return f
end

-- The destination chips: "All" and the places online drivers go (most drivers first), as
-- many as fit. A chip filters the list like a search; "All" clears it. (Round 13, I22: every
-- driver the list shows counts, your own advert too; when the chips don't all fit they get
-- tighter before any place is left out.)
function UI.FillPlaceChips(s, all)
	local row = s.chips
	if not row then return end
	local count, order = {}, {}
	for _, d in ipairs(all or {}) do
		local k = d.dest
		if k and k ~= "" and k ~= "Unknown" then
			if not count[k] then order[#order + 1] = k count[k] = 0 end
			count[k] = count[k] + (d.state == "paused" and 0.5 or 1)
		end
	end
	table.sort(order, function(a, b)
		if count[a] ~= count[b] then return count[a] > count[b] end
		return a < b
	end)
	local f = ui.filter
	local current = f and (f.place or f.text) or nil
	local function same(a, b) return a and b and a:lower() == b:lower() end
	local want = { { label = "All", place = nil, on = f == nil } }
	for _, p in ipairs(order) do want[#want + 1] = { label = p, place = p, on = same(current, p) } end
	-- a searched place with nobody going there yet still shows, selected
	if f and f.place and not count[f.place] then table.insert(want, 2, { label = f.place, place = f.place, on = true }) end
	local chips = {}
	for i, it in ipairs(want) do
		local c = row.list[i]
		if not c then
			c = CreateFrame("Button", nil, row)
			c:SetSize(60, 30)
			c.tag = T.Tag(c, "", { h = 30, size = "sub", pad = 16 })
			c.tag:SetPoint("LEFT", c, "LEFT", 0, 0)
			c.tag:EnableMouse(false)
			c:RegisterForClicks("LeftButtonUp")
			T.Press(c, { fill = c.tag.fill })
			safeScript(c, "OnClick", function(self)
				local e = s.search and s.search.edit
				if e and (S(e:GetText()) or "") ~= "" then e:SetText("") e:ClearFocus() end
				applySearch(self.place or "", self.place ~= nil)
			end)
			T.Tip(c, function(self) return self.place or "All drivers" end, function(self)
				if not self.place then return "Show every driver online." end
				return "Only drivers going to " .. self.place .. "."
			end)
			row.list[i] = c
		end
		c.place = it.place
		chips[i] = { c = c, label = it.label, on = it.on }
	end
	-- the roomy look (16 px inside, 8 between) while everything fits, else tighter (10 and 5)
	local function lay(pad, gap, place)
		local x = 0
		for i, ch in ipairs(chips) do
			local tag = ch.c.tag
			tag.pad, tag.lead = pad, pad
			T.PlaceOnce(tag.label, "LEFT", tag, "LEFT", pad, 0)
			tag:SetTag(ch.label, ch.on and "accent" or "card", ch.on and "white" or "muted")
			local w = N(tag:GetWidth()) or 60
			local fits = x + w <= INNER or i == 1
			if place then
				if fits then
					ch.c:SetWidth(w)
					T.PlaceOnce(ch.c, "LEFT", row, "LEFT", x, 0)
					ch.c:Show()
				else
					ch.c:Hide()
				end
			elseif not fits then
				return false
			end
			if fits then x = x + w + gap end
		end
		return true
	end
	if lay(16, 8, false) then lay(16, 8, true) else lay(10, 5, true) end
	for i = #want + 1, #row.list do row.list[i]:Hide() end
	setShown(row, #want > 1)
end

-- the "ride" page unfolded (true) or folded (false): the map docks in the side pane or comes
-- back; the sheet starts at y 16 or under the map, as today
local WIDE_TOP = 16
local function foldLayout(s, unfolded, holder)
	s.wide = unfolded and true or false
	local WorldMod = W.Mod("UI.Rider.WorldMap")
	s.sheet:ClearAllPoints()
	if s.wide then
		HomeMapMod.Dock(s.map, holder)
		if type(WorldMod) == "table" and type(WorldMod.Build) == "function" then
			WorldMod.Build(holder, { here = s.map })
			s.wideFocus = nil
		end
		s.sheet:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 0, -WIDE_TOP)
		-- (design 2) the OpenMap line is the last row of the drivers list: it no longer goes with the map
	else
		HomeMapMod.Undock(s.map)
		s.sheet:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 0, -SHEET_TOP)
	end
	s.sheet:SetPoint("BOTTOMRIGHT", s.frame, "BOTTOMRIGHT", 0, 0)
	setShown(s.grab, not s.wide)
	updateMap(s.map, UI.Drivers())
	UI.Refresh(true)
end
Mod.foldLayout = foldLayout

local function buildHome(body)
	local s = { frame = CreateFrame("Frame", nil, body) }
	local home = s.frame
	home:SetAllPoints(body)
	s.map = buildMapPanel(home)
	local sheet = T.Card(home, nil, nil, { colour = "panel", radius = 18 })
	sheet:SetPoint("TOPLEFT", home, "TOPLEFT", 0, -SHEET_TOP)
	sheet:SetPoint("BOTTOMRIGHT", home, "BOTTOMRIGHT", 0, 0)
	sheet:SetFrameLevel(s.map:GetFrameLevel() + 10)
	s.sheet = sheet
	local grab = CreateFrame("Frame", nil, sheet)
	grab:SetSize(36, 5)
	grab:SetPoint("TOP", sheet, "TOP", 0, -9)
	T.PillFill(grab, "raised", 5, "ARTWORK")
	s.grab = grab -- (round 9, S9: hidden in two-pane, where the sheet doesn't slide)
	s.search = buildSearch(sheet)
	-- the places drivers go, as chips under the search: All | Undercity | Ratchet (01 v2)
	s.chips = CreateFrame("Frame", nil, sheet)
	s.chips:SetSize(INNER, 30)
	s.chips:SetPoint("TOPLEFT", sheet, "TOPLEFT", PAD, -74)
	s.chips.list = {}
	s.header = T.Text(sheet, "heading", "white", "LEFT", "bold")
	s.header:SetPoint("TOPLEFT", sheet, "TOPLEFT", PAD, -110)
	s.count = T.Text(sheet, "sub", "muted", "RIGHT", "regular")
	s.count:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", -PAD, -114)
	-- the bell next to the count while a place is searched
	-- (design 1, K) a small button with words (was a bare round bell), on its own line at the top of the list.
	-- Off: the second button (bell). On: the chosen look (violet fill, ink words) and a tick instead of the bell,
	-- so the state does not rest on colour alone.
	s.bell = T.Pill(sheet, "Tell me when one opens", "dark", 214, 30)
	s.bell.onFill = T.PillFill(s.bell, "accent", 30, "BACKGROUND", 1)
	s.bell.onFill:SetShown(false)
	s.bell.icon = T.Icon(s.bell, "bell", 14, "white", "OVERLAY")
	s.bell.tick = T.Icon(s.bell, "check", 14, "ink", "OVERLAY")
	s.bell.icon:SetPoint("LEFT", s.bell, "LEFT", 14, 0)
	s.bell.tick:SetPoint("LEFT", s.bell, "LEFT", 14, 0)
	s.bell.tick:SetShown(false)
	s.bell.label:ClearAllPoints()
	s.bell.label:SetPoint("LEFT", s.bell, "LEFT", 34, 0)
	s.bell.label:SetPoint("RIGHT", s.bell, "RIGHT", -14, 0)
	s.bell.label.wuberRoom = 214 - 48
	T.Fit(s.bell.label) -- the room is narrower than the pill fitted it to: fit again (the words stay whole)
	function s.bell.SetOn(self, on)
		self.watching = on and true or false
		self.onFill:SetShown(self.watching)
		self.icon:SetShown(not self.watching)
		self.tick:SetShown(self.watching)
		self.label:SetTextColor(T.RGB(self.watching and "ink" or "white"))
	end
	safeScript(s.bell, "OnClick", function()
		local place = ui.filter and ui.filter.place
		if place then toggleWatch(place) end
	end)
	T.Tip(s.bell, "Tell me when a driver comes online", bellTip)
	s.bell:Hide()
	local clip = CreateFrame("Frame", nil, sheet)
	clip:SetPoint("TOPLEFT", sheet, "TOPLEFT", 0, -LIST_TOP)
	clip:SetPoint("BOTTOMRIGHT", sheet, "BOTTOMRIGHT", 0, 8)
	Try(clip, "SetClipsChildren", true)
	clip:EnableMouseWheel(true)
	safeScript(clip, "OnMouseWheel", function(_, delta)
		ui.scrollTarget = ui.scrollTarget - (tonumber(delta) or 0) * 64
		ui.scrollTarget = clamp(ui.scrollTarget, 0, ui.scrollMax or 0)
	end)
	s.clip = clip
	-- S6: the shared soft edges, in the sheet's colour (a small lift: the bar stays under Settings and Help, REV-r25-1)
	T.EdgeFade(clip, { colour = "panel", lift = 12, source = function() return ui.scroll, ui.scrollMax end })
	local content = CreateFrame("Frame", nil, clip)
	content:SetSize(WIN_W, 10)
	content:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
	s.content = content
	s.empty = buildEmpty(clip)
	s.usual = buildUsual(content)
	-- (2.3.2, E2) one small line where the "Your usual" card would be, when nobody serves that place
	s.usualNote = T.Text(content, "sub", "muted", "LEFT", "regular")
	s.usualNote:SetWidth(INNER)
	s.usualNote:Hide()
	s.raidCard = UI.BuildRaidCard(content)
	s.bountyChip = buildBountyChip(content)
	s.ownChip = buildOwnChip(content)
	s.empty.bounty = buildBounty(s.empty)

	-- (design 2, item 10) the drivers: rows of ONE card (UI.LayoutCards fills and orders them)
	s.rows = T.RowGroup(content, INNER)
	s.rows:SetFrameLevel(content:GetFrameLevel() + 3)
	s.rows:Hide()
	-- without OpenMap: a line until its x is clicked (W.db.openMapHint); Settings has the OpenMap row for later.
	-- (design 2) It no longer floats over the map: it is the LAST row of the drivers list, with its x.
	local hint = s.rows:Row({ icon = "pin", title = "Get OpenMap to see drivers on your world map",
		onClick = function()
			if type(UI.OpenHelp) == "function" then UI.OpenHelp("home") end
		end,
		tip = { title = "OpenMap", body = "Install the free OpenMap addon (on CurseForge) to see drivers, prices and your route on its world map. "
			.. "Without it you still see them on the game's own world map, and every driver here." } })
	hint.label = hint.title
	hint.close = CreateFrame("Button", nil, hint)
	hint.close:SetSize(22, 22)
	hint.close:RegisterForClicks("LeftButtonUp")
	hint.close.x = T.Icon(hint.close, "close", 9, "muted", "ARTWORK")
	hint.close.x:SetPoint("CENTER", hint.close, "CENTER")
	hint.rightFrame, hint.rightW = hint.close, 22 -- the row's control at its right (T.RowGroup places it)
	safeScript(hint.close, "OnClick", function()
		ui.openMapHintOn = false
		if W.db then W.db.openMapHint = true end
		s.hintOn = false
		hint:SetShown(false)
		UI.Refresh(true)
	end)
	T.Press(hint.close)
	T.Tip(hint.close, "Hide this tip", "Wuber won't show it again. Settings > OpenMap says what it adds.")
	hint.off = true
	hint:Hide()
	s.mapHint = hint

	-- (Group Finder, setting groupFinder) the search row and the count line are built the first time the setting is on
	-- (buildGroupFinder, called by layoutGroupFinder): with the setting off nothing of them exists.

	-- (design 2, item 9) Home's main button while "Your usual" shows: "Ride again · Undercity · 50s", at the foot of
	-- the page (12 above its bottom); it does what the card does. The list's clip ends above it (s.update).
	s.main = T.MainButton(sheet, "Ride again")
	safeScript(s.main, "OnClick", function(self)
		if self.mode == "raid" then
			raidAction()
		else
			usualGo(s.usual)
		end
	end)
	T.Tip(s.main, function(self)
		return self.mode == "raid" and "Request a summon" or "Your usual"
	end, function(self)
		if self.mode == "raid" then
			return "Puts you on your raid's summon list (the same as typing 123 in raid chat). A Warlock summons you to the raid; accept when it pops. It costs nothing."
		end
		return "Your most frequent ride. One click takes you straight to booking it."
	end)
	s.main:Hide()

	function s.enter()
		ui.manual = "home"
		ui.confirmKey = nil
		A.SlideUp(sheet, 40, 0.32)
		A.FadeIn(s.map, 0.3)
		s.staggerNext = true
	end

	function s.update()
		local all = UI.Drivers()
		local list = {}
		for _, d in ipairs(all) do
			if matches(d, ui.filter) then list[#list + 1] = d end
		end
		if s.map:IsVisible() then updateMap(s.map, all) end
		-- unfolded: the world view rings the place searched
		if s.wide then
			local fp = (ui.filter and ui.filter.place) or false
			local WorldMod = W.Mod("UI.Rider.WorldMap")
			if s.wideFocus ~= fp and type(WorldMod) == "table" and type(WorldMod.Show) == "function" then
				s.wideFocus = fp
				WorldMod.Show(nil, { holder = s.holder, focus = fp })
			end
		end
		-- the OpenMap hint: once ever, never with OpenMap
		local hasOM = type(UI.HasOpenMap) == "function" and call(UI.HasOpenMap) == true
		-- (it stays until its x is clicked: W.db.openMapHint, review #22)
		if not hasOM and W.db and ui.openMapHintOn == nil then
			ui.openMapHintOn = not W.db.openMapHint
		end
		local adv = W.Advanced()
		s.hintOn = (not hasOM) and ui.openMapHintOn == true and not (W.db and W.db.openMapHint) -- (design 2) the last row of the list: UI.LayoutCards shows it
		local f = ui.filter
		s.header:SetText(f and f.place and ("Drivers to " .. f.place) or (f and "Matching drivers" or "Drivers online"))
		local open = 0
		for _, d in ipairs(list) do
			if d.state == "open" then open = open + 1 end
		end
		local showCount = adv and #list > 0
		s.count:SetText(showCount and (open .. " open · " .. #list .. " online") or "")
		setShown(s.count, showCount)
		-- the bell (a place searched) sits right of the header; the count moves left of it
		local place = f and f.place
		-- (design 1, K) with no driver listed the empty state has its own "Tell me when one opens" button
		local bellOn = adv and place ~= nil and #list > 0
		setShown(s.bell, bellOn)
		if bellOn then s.bell:SetOn(isWatching(place)) end
		s.count:ClearAllPoints()
		s.count:SetPoint("TOPRIGHT", s.sheet, "TOPRIGHT", -PAD, -114)
		-- (r47, REV-r47-1) the heading keeps to the room the count and the bell leave: it shrinks first, and a place
		-- still too long wraps, so "Drivers to Feathermoon Stronghold" never draws over "0 open · 1 online"
		local countW = showCount and (N(T.TextWidth(s.count)) or 0) or 0
		s.header:SetWidth(math.max(120, INNER - countW - 8))
		UI.FitOrWrap(s.header)
		UI.FillPlaceChips(s, all)
		-- "Your usual" first, when that driver is online and no search is on
		local ud, udest = nil, nil
		if not f then ud, udest = usualRide() end
		local u = s.usual
		-- the raid's free summons first, then "Your usual"
		local raid = UI.RaidHere()
		local rc = s.raidCard
		s.listTop = UI.LIST_PAD
		-- (design 1, K) the bell button has the first line of the list while a place is searched
		if bellOn then
			s.bell:SetParent(content)
			s.bell:ClearAllPoints()
			-- a place long enough to wrap its heading takes a second line: the button stays clear of it
			-- (#263) or the game's own answer: it draws the words about 6% wider than the font table and may wrap a heading the table keeps on one line
			local drawnLines = N(Try(s.header, "GetNumLines")) or 1
			if s.header.wuberWrapped or drawnLines >= 2 then
				-- the heading's second line is its drawn size and the line spacing: follow it, not a fixed 18
				local lines = math.max(2, N(s.header.wuberLines) or 2, drawnLines)
				s.listTop = s.listTop + math.max(18, (lines - 1) * (T.DrawnSize("heading") + T.Spacing("heading")))
			end
			s.bell:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -s.listTop)
			T.Fit(s.bell.label) -- laid out now: the game's own answer can shrink the words (they are never cut)
			s.listTop = s.listTop + 38
		end
		local mine = UI.BountyMine()
		local bc = s.bountyChip
		-- (#317, run 5) what the empty state stands under (your bounty's card, then the Group Finder card when it is on
		-- top): the empty state is anchored to its BOTTOM, so the game itself lays the stack out and no measured height
		-- can put the title or the picks under the card
		s.emptyUnder = nil
		if mine then
			bc.row:SetTitle("Your bounty: " .. money(N(mine.copper) or 0) .. " for " .. mine.place)
			bc.row:SetSub(minutesLeft(mine) .. " min")
			bc:ClearAllPoints()
			bc:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -s.listTop)
			if not bc:IsShown() then A.FadeIn(bc, 0.2) end
			-- (#317) what sits under the card starts below its REAL height: a card whose layout is held to the end of a text
			-- refresh is 0 high until then, and the empty state's title and picks were drawn under the card
			bc:LayoutNow()
			local chipH = N(bc.height)
			if not chipH or chipH <= 0 then chipH = 56 end
			s.chipUsedH = chipH
			-- ... and if its real height changes later (a font that arrives, a wrap), the page is placed again
			bc.onLayout = function(_, y) if y ~= s.chipUsedH and bc:IsShown() then UI.Refresh(true) end end
			s.listTop = s.listTop + chipH + 8
			s.chipEnd = s.listTop -- (the room sums only; the card's place is the anchor below)
			s.emptyUnder = bc
			ui.bountyPlace = mine.place
		elseif bc:IsShown() then
			bc:Hide()
		end
		-- (2.3.2, B4) open as a driver and others are listed too: a chip says you are live (never a bookable card)
		local own = (not f) and ownBeacon() or nil
		local oc = s.ownChip
		if own and #list > 0 then
			oc.text:SetText("You're " .. (OWN_STATE[own.state] or "open") .. " as a driver · " .. ownSummary(own))
			UI.FitOrWrap(oc.text) -- (r33, HUNT-100) shrink first; a line still too long wraps and the chip grows
			local tall = oc.text.wuberWrapped == true
			oc:SetHeight(tall and 44 or 28) -- (design 3) two lines at the sub size: 44, on the grid
			oc.fill:SetHeight(tall and 44 or 28)
			oc:ClearAllPoints()
			oc:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -s.listTop)
			if not oc:IsShown() then A.FadeIn(oc, 0.2) end
			s.listTop = s.listTop + (tall and 52 or 36)
		elseif oc:IsShown() then
			oc:Hide()
		end
		if raid then
			rc:Paint(raid)
			rc:ClearAllPoints()
			rc:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -s.listTop)
			if not rc:IsShown() then A.FadeIn(rc, 0.25) end
			s.listTop = s.listTop + (N(rc:GetHeight()) or 80) + 8
		else
			rc:Hide()
		end
		if ud then
			u.key = ud.key
			u.title:SetText(udest)
			u.sub:SetText("with " .. ud.service .. (ud.state == "busy" and " · busy" or ""))
			u.price:SetText(money(ud.price))
			u:ClearAllPoints()
			u:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -s.listTop)
			if not u:IsShown() then A.Pop(u, 0.32) end
			s.listTop = s.listTop + USUAL_H + 12
		else
			u.key = nil
			u:Hide()
		end
		-- (2.3.2, E2) the card is gone because no driver serves the usual place: say so, no button
		local note = s.usualNote
		local upl = (not f and not ud and not own and onNetwork()) and usualPlace() or nil
		-- (AUD-179) an open driver who serves that place means somebody is there
		if upl then
			for _, d in ipairs(all) do
				if d.state == "open" and d.dest and (d.dest == upl or (type(W.SamePlace) == "function" and call(W.SamePlace, d.dest, upl) == true)) then upl = nil break end
			end
		end
		-- (design 2, 2.4) the one main button: "Request a summon" while a raid card is up and not queued, else
		-- "Ride again · <place> · <price>" while "Your usual" shows. The list ends above it.
		local raidMain = raid ~= nil and not raid.queued
		local mainOn = raidMain or ud ~= nil
		s.main.mode = raidMain and "raid" or "usual"
		setShown(s.main, mainOn)
		if raidMain then
			s.main:SetLabel("Request a summon")
		elseif ud then
			s.main:SetLabel("Ride again · " .. udest .. " · " .. money(ud.price))
		end
		clip:ClearAllPoints()
		clip:SetPoint("TOPLEFT", sheet, "TOPLEFT", 0, -LIST_TOP)
		clip:SetPoint("BOTTOMRIGHT", sheet, "BOTTOMRIGHT", 0, mainOn and (T.MAIN.foot + T.MAIN.h + 8) or 8)
		if upl and not atHere(upl) and #list > 0 then
			note:SetText("Your usual: " .. upl .. " - nobody's there right now")
			note:ClearAllPoints()
			note:SetPoint("TOPLEFT", content, "TOPLEFT", PAD + 2, -s.listTop)
			s.listTop = s.listTop + 24
			note:Show()
		else
			note:Hide()
		end
		local keepScroll = ui.scrollTarget -- (H24-14) an empty state taller than the list scrolls (below)
		UI.LayoutCards(s, list)
		-- the empty state
		local empty = #list == 0 and not raid
		if empty then
			local e = s.empty
			-- (round 9, C8) under the bounty chip, never behind it: (#317, run 5) by anchors, the same gap as always
			e:ClearAllPoints()
			if s.emptyUnder then
				e:SetPoint("TOPLEFT", s.emptyUnder, "BOTTOMLEFT", -PAD, -EMPTY_GAP)
			else
				e:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0) -- nothing above: right under the heading, at the list's top
			end
			e:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", 0, 0)
			if f then
				e.title:SetText(f.place and ("No drivers to " .. f.place .. " yet") or "No drivers match that")
			else
				e.title:SetText("No drivers online")
			end
			local wplace = f and f.place
			-- nobody serves a known place: offer a bounty instead of the ping and the bell
			-- (2.3.2, B6) never a bounty for the city you stand in
			local bplace = adv and wplace and UI.BountyPlace(wplace, all) or nil
			if bplace and atHere(bplace) then bplace = nil end
			-- (round 9, Y2) no search, nobody online: the rider's usual place gets the bell and a bounty
			local up = (not f) and onNetwork() and usualPlace() or nil
			if up and atHere(up) then up = nil end
			local ubounty = adv and up and not mine and UI.BountyPlace(up, all) or nil
			if own then bplace, up, ubounty = nil, nil, nil end
			local plain = up ~= nil
			local mapHintOn = s.hintOn == true and bplace == nil and not own
			local bb = e.bounty
			bb.place = bplace
			setShown(bb, bplace ~= nil)
			setShown(e.disc, bplace == nil and not plain and not own)
			setShown(e.ping, bplace == nil and not own)
			setShown(e.why, bplace == nil and not own)
			if own then e.ping:Hide() end
			-- (2.3.2, B4) you are the open driver: say so, and what riders see
			local ownEmpty = own ~= nil
			setShown(e.own, ownEmpty)
			if ownEmpty then
				e.own:SetLabel(ownSummary(own))
				e.title:SetText("You're " .. (OWN_STATE[own.state] or "open") .. " as a driver")
			end
			e.disc:ClearAllPoints()
			e.disc:SetPoint("TOP", e, "TOP", 0, -24)
			e.title:ClearAllPoints()
			if ownEmpty then
				e.title:SetPoint("TOP", e, "TOP", 0, -24)
				if e.pulse.running then e.pulse:Stop() end
			elseif bplace then
				e.title:SetPoint("TOP", e, "TOP", 0, -10)
				e.title:SetText("Nobody summons to " .. bplace .. " right now")
				if e.pulse.running then e.pulse:Stop() end
				bb.Paint()
			elseif plain then
				-- the "Your usual" line holds the foot: the block starts a little higher, so the sub can
				-- wrap to two lines and "Why can't I see anyone?" still stops above that line
				e.title:SetPoint("TOP", e, "TOP", 0, -15) -- (D2 P1) 12 under the heading (its frame reaches 2 into the clip)
				if e.pulse.running then e.pulse:Stop() end
			else
				e.title:SetPoint("TOP", e.disc, "BOTTOM", 0, -16)
			end
			local wp = wplace or up -- (HR-2) also above the bounty card
			-- ... but not once your bounty is up: it already watches the place, and the card needs the room
			-- (H24-14) ... nor for the usual place your bounty is up for (the same watch, and the stack needs the room)
			local function minePlace(p) return p and mine and W.SamePlace and call(W.SamePlace, mine.place, p) == true end
			local pinned = minePlace(bplace) or minePlace(wp)
			if pinned then wp = nil end
			e.watch.place = wp
			setShown(e.watch, wp ~= nil)
			e.bountyGo.place = ubounty
			setShown(e.bountyGo, ubounty ~= nil)
			if ubounty then e.bountyGo:SetLabel("Pin a bounty") end
			e.watch:ClearAllPoints()
			e.sub:ClearAllPoints()
			bb:ClearAllPoints()
			if bplace and wp then
				-- (HR-2) heading, the bell, then the ask and the bounty card
				e.watch:SetPoint("TOP", e.title, "BOTTOM", 0, -8)
				e.sub:SetPoint("TOP", e.watch, "BOTTOM", 0, -8)
				bb:SetPoint("TOP", e.sub, "BOTTOM", 0, -8)
			else
				e.sub:SetPoint("TOP", e.title, "BOTTOM", 0, -4)				e.watch:SetPoint("TOP", e.sub, "BOTTOM", 0, (plain and note:IsShown()) and -6 or -14)
				bb:SetPoint("TOPLEFT", e, "TOPLEFT", PAD, -74)
			end
			e.why:ClearAllPoints()
			if ubounty or wp then
				e.why:SetPoint("TOP", ubounty and e.bountyGo or e.watch, "BOTTOM", 0, ubounty and 0 or -8)
			else
				e.why:SetPoint("TOP", e.sub, "BOTTOM", 0, -14)
			end
			if wp then
				local on = isWatching(wp)
				e.watch:SetLabel(on and "We'll tell you when one's online" or "Tell me")
				e.watch.icon:SetVertexColor(T.RGB(on and "glow" or "muted"))
			end
			if loginAt and not onNetwork() and now() - loginAt < JOIN_GRACE and not e.graceAt then
				e.graceAt = true
				W.After(JOIN_GRACE - (now() - loginAt) + 0.5, function() e.graceAt = nil UI.Refresh() end)
			end
			local subHours = nil
			if ownEmpty then
				e.sub:SetText(own.state == "paused" and "Riders see you as paused. Open up on the Drive tab to take riders."
					or ("Riders see you in " .. ownPlace(own) .. " for " .. money(N(own.price) or 0) .. ". No other drivers are online."))
			elseif bplace then
				local mine2 = UI.BountyMine()
				e.sub:SetText((mine2 and W.SamePlace and call(W.SamePlace, mine2.place, bplace)) and "Your bounty is up: drivers see you want it."
					or "Pin a bounty so drivers see you want it:")
			elseif not onNetwork() and not (loginAt and now() - loginAt < JOIN_GRACE) then
				e.sub:SetText("Can't reach the Wuber network. You may be in ten chat channels already.")
			elseif not f then
				-- (round 9, Y2) when drivers are usually around, only from real times Wuber saw
				-- (2.3.2, B5) only from several days of sightings, and said to be local time
				local hours, last = usualHours(), nil
				if not hours then last = lastSeenDriver() end
				if hours then
					subHours = hours
					e.sub:SetText("Usually here " .. hours)
				elseif last then
					e.sub:SetText("Last driver seen " .. last .. ". Drivers appear here as soon as they open.")
				else
					e.sub:SetText("Drivers show up here the moment they go online. Fares from " .. money(N(W.MIN_PRICE) or 5000) .. ".")
				end
			else
				e.sub:SetText("Drivers show up here the moment they go online. Fares from " .. money(N(W.MIN_PRICE) or 5000) .. ".")

			end
			-- the quiet OpenMap line under "Why?": only when it fits without touching a gap (12 under the heading, 12
			-- above the main button, no line on another); if not, the round icon gives way first (the title moves up), and
			-- if there is still no room the line is not shown here.
			-- (H24-14) The same room rule holds for the whole stack, with or without the OpenMap line: your bounty's row
			-- above it leaves 152 of the list's 238, so the round icon gives way there too; a stack still too tall (a
			-- bell for another place) makes the empty state reach past the list's foot and scroll with it, Ping drivers
			-- at its end, never under the words.
			setShown(e.mapHint, false)
			local clipH = N(clip:GetHeight()) or 0
			-- (a list not laid out yet, height 0, has no room to measure: the next refresh does it)
			if not own and clipH > 0 then
				local one = T.DrawnSize("small")
				local mhH = math.max(one, math.ceil(N(e.mapHint.text:GetStringHeight()) or one))
				-- (G1) never less than one line: a label whose font has not loaded yet says 0
				local titleH = math.max(T.DrawnSize("body"), math.ceil(N(e.title:GetStringHeight()) or 17))
				local subH = math.max(T.DrawnSize("sub"), math.ceil(N(e.sub:GetStringHeight()) or one))
				local off = (mine or s.gfPushed) and (s.listTop - UI.LIST_PAD + 4) or 0
				local avail = clipH - off
				-- (#235) a bounty card to pin: its pills sit under the sub (or 74 down), the note under them (under the box for an
				-- amount of your own), Pin at the foot; the stack needs all of that, so a short list (a Group Finder card on top, a long
				-- place name on two lines) grows the empty state and scrolls, never lays Pin over the pills or the note.
				-- With your bounty up Pin is hidden: the room the main button takes is not asked for.
				local function bountyNeed()
					local bb2 = e.bounty
					local noteH = math.max(one, math.ceil(N(bb2.note:GetStringHeight()) or one))
					local bbOff = 74
					if wp then bbOff = 10 + titleH + 8 + 36 + 8 + subH + 8 end
					local y = bbOff + (bb2.custom:IsShown() and 78 or 40) + noteH
					local foot = 12 + T.MAIN.h + (T.MAIN.foot - 8)
					return pinned and (y - foot) or y
				end
				local function need(top, hint)
					if bplace then return bountyNeed() end
					local y = top + titleH + 4 + subH
					if ubounty then y = y + 14 + 36 + 2 + 36
					elseif wp then y = y + ((plain and note:IsShown()) and 6 or 14) + 36 + 8
					else y = y + 14 end
					return y + 24 + (hint and (4 + mhH) or 0)
				end
				local room = avail - (T.MAIN.foot - 8) - T.MAIN.h - 12
				-- (Group Finder) the card on top leaves the stack too little room (its lines can take 110 of the list's 238):
				-- the card goes under the stack instead, at the end of the page, and the stack keeps the whole view, so
				-- the bounty and Ping drivers stay where they always stand
				local belowGF = false
				if s.gfPushed and need(15) > room then
					belowGF = true
					-- (#317, run 5) your bounty's card stays on top: the stack still starts under it (only the Group
					-- Finder card moves). It used to start at the list's top, under the card, on the folded window.
					s.gfPushed = false
					off = mine and ((N(s.chipEnd) or UI.LIST_PAD) - UI.LIST_PAD + 4) or 0
					avail = clipH - off
					room = avail - (T.MAIN.foot - 8) - T.MAIN.h - 12
				end
				local top = plain and 15 or (24 + 56 + 16)
				local function dropDisc()
					top = 15
					e.disc:Hide()
					e.title:ClearAllPoints()
					e.title:SetPoint("TOP", e, "TOP", 0, -15)
					if e.pulse.running then e.pulse:Stop() end
				end
				local hint = false
				if mapHintOn then
					if need(top, true) <= room then
						hint = true
					elseif not plain and need(15, true) <= room then
						dropDisc()
						hint = true
					end
				end
				if not hint and not plain and not bplace and need(top) > room then dropDisc() end
				if hint then
					e.mapHint:SetHeight(mhH)
					e.mapHint:ClearAllPoints()
					e.mapHint:SetPoint("TOP", e.why, "BOTTOM", 0, -4)
					e.mapHint:Show()
				end
				local over = math.ceil(need(top, hint) - room)
				if over > 0 or belowGF then
					over = math.max(over, 0)
					local tail = belowGF and (8 + (N(s.gfRows:GetHeight()) or 0)) or 0
					e:ClearAllPoints()
					-- (#317, run 5) under the card above it by anchors (the Group Finder card, moved below, is not above)
					local under = s.emptyUnder
					if belowGF then under = mine and bc or nil end
					if under then
						e:SetPoint("TOPLEFT", under, "BOTTOMLEFT", -PAD, -EMPTY_GAP)
					else
						e:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -off)
					end
					e:SetSize(N(clip:GetWidth()) or WIN_W, avail + over)
					if belowGF then
						s.gfRows:ClearAllPoints()
						s.gfRows:SetPoint("TOPLEFT", e, "BOTTOMLEFT", PAD, -8)
					end
					content:SetHeight(off + avail + over + tail)
					ui.scrollMax = over + tail
					ui.scrollTarget = clamp(keepScroll or 0, 0, over + tail)
				end
			end
			if subHours then
				e.subTipTitle = "Usually here " .. subHours
				e.subTipBody = "You've mostly seen drivers around " .. subHours .. " (local time). They appear here as soon as they open."
				e.subHit:Show()
			else
				e.subTipTitle, e.subTipBody = nil, nil
				e.subHit:Hide()
			end
			local wait = ui.pingAt and math.ceil(20 - (now() - ui.pingAt)) or 0
			if wait > 0 then
				e.ping:SetLabel("Ping again in " .. wait .. " s")
				e.ping:SetActive(false)
			else
				e.ping:SetLabel("Ping drivers")
				e.ping:SetActive(true)
			end
			if not e:IsShown() then
				A.FadeIn(e, 0.3)
			end
			-- the ring pulse follows the disc: also after a search is cleared (the empty state stayed up).
			-- (ING-12) Only while the disc shows: where it gave way to the OpenMap line above, the rings were
			-- stopped there and started here again on every refresh (each letter typed, and about once a second).
			if not bplace and not plain and not own and not e.pulse.running and e.disc:IsShown() then e.pulse:Start() end
		elseif s.empty:IsShown() then
			s.empty.pulse:Stop()
			s.empty:Hide()
		end
		s.search.Hint()
	end

	function s.tick() -- every 10 s while shown: the "Updated..." texts
		for _, c in pairs(ui.cards) do
			if c.view and c.view.heard then c.updated = updatedText(c.view) end
		end
	end

	-- the unfolded page
	local F = UI.Fold
	if type(F) == "table" and type(F.Register) == "function" then
		F.Register("ride", {
			build = function(holder) s.holder = holder end,
			layout = function(on, holder) foldLayout(s, on, holder) end,
		})
	end
	return s
end

-- (Design 2, item 10) Lays out the drivers as rows of ONE card (s.rows), keyed by driver, in the list's order, with
-- the OpenMap line as the last row; a row that is gone goes back to the pool. The card's height (every row as tall
-- as its words need) feeds the scroll maths. c.targetY / c.curY say where each row stands in the content.
-- (Group Finder, setting groupFinder) under the drivers: the search row and the count line, one more card. Built lazily, the
-- first time the setting is on; both rows stay hidden (and the card with them) while it is off: UI.LayoutCards decides.
local function buildGroupFinder(s)
	if s.gfRows or not s.content then return end
	local gfw = W.GroupFinder and W.GroupFinder.DRAFT_WORDS or {}
	local content = s.content
	s.gfRows = T.RowGroup(content, INNER)
	s.gfRows:SetFrameLevel(content:GetFrameLevel() + 3)
	s.gfRows:Hide()
	s.gfSearch = s.gfRows:Row({ icon = "signal", title = gfw.searchButton or "", tip = false,
		onClick = function(row)
			if row.disabled then return end
			local GF = W.GroupFinder
			if GF and GF.On() then GF.Search() end -- ONLY here: the game wants a real click
			UI.Refresh(true)
		end })
	s.gfSearch.off = true
	s.gfSearch:Hide()
	s.gfExtra = s.gfRows:Row({ title = "", tip = false })
	s.gfExtra.off = true
	s.gfExtra:Hide()
	-- the rows' real heights are known after their first layout: draw the page once more, as a player would see it settle
	if type(W.After) == "function" then W.After(0, function() UI.Refresh(true) end) end
end

-- (Group Finder) the search row and the count line under the drivers; returns the card's height (0: nothing shows).
-- The search row is off while a search is pending (busy), when no category is known, or when the game has no Group Finder.
local function layoutGroupFinder(s)
	local GF = W.GroupFinder
	local on = GF ~= nil and GF.On()
	if on then buildGroupFinder(s) end
	local g = s.gfRows
	if not g then return 0 end
	local sr, er = s.gfSearch, s.gfExtra
	local words = GF and GF.DRAFT_WORDS or {}
	sr.off, er.off = not on, true
	if on then
		local reason
		if type(C_LFGList) ~= "table" or type(C_LFGList.Search) ~= "function" then
			reason = words.nolfg
		elseif GF.Pending() then
			reason = words.busy
		elseif GF.SearchCategory() == nil then
			reason = words.nocategory
		end
		sr.disabled = reason ~= nil
		sr:SetSub(reason or "")
		sr:SetAlpha(reason and 0.55 or 1)
		if type(sr.Disable) == "function" then
			if reason then sr:Disable() else sr:Enable() end
		end
		local n = GF.ExtraCount()
		if n > 0 then
			er.off = false
			er:SetTitle(string.format(words.extra or "%d", n))
		end
	end
	setShown(sr, not sr.off)
	setShown(er, not er.off)
	local h = on and g:Layout() or 0
	setShown(g, h > 0)
	return h
end

function UI.LayoutCards(s, list)
	local group = s.rows
	if not group then
		group = T.RowGroup(s.content, INNER)
		s.rows = group
	end
	local want = {}
	for i, d in ipairs(list) do want[d.key] = i end
	-- gone (sorted so cardPool order does not depend on Lua pairs() hash order)
	local gone = {}
	for key in pairs(ui.cards) do
		if not want[key] then gone[#gone + 1] = key end
	end
	table.sort(gone)
	for _, key in ipairs(gone) do
		local c = ui.cards[key]
		ui.cards[key] = nil
		c.key = nil
		c.off = true
		c:Hide()
		ui.cardPool[#ui.cardPool + 1] = c
	end
	local fresh, order = {}, {}
	local top = s.listTop or 0
	for _, d in ipairs(list) do
		local c = ui.cards[d.key]
		if not c then
			c = table.remove(ui.cardPool)
			if not c or c.group ~= group then c = buildCard(group) end
			ui.cards[d.key] = c
			c.off = false
			c:Show()
			fresh[#fresh + 1] = c
		end
		fillCard(c, d, (prominence(d, list)), true)
		order[#order + 1] = c
	end
	-- the OpenMap line: the last row, only under drivers (Advanced only)
	local hint = s.mapHint
	if hint and hint.group == group then
		hint.off = not (W.Advanced() and s.hintOn == true and #list > 0)
		setShown(hint, not hint.off)
		order[#order + 1] = hint
	end
	local shownRows = #order
	for _, c in ipairs(group.rows) do
		if c.off and c ~= hint then order[#order + 1] = c end
	end
	group.rows = order
	group:ClearAllPoints()
	group:SetPoint("TOPLEFT", s.content, "TOPLEFT", PAD, -top)
	local rowsH = group:Layout()
	setShown(group, rowsH > 0)
	local y = 0
	for i = 1, shownRows do
		local c = order[i]
		if not c.off then
			c.targetY = -(top + y)
			c.curY = c.targetY
			y = y + (N(c:GetHeight()) or 0)
		end
	end
	-- (Group Finder) under the drivers; with no driver it stands at the top and the empty state starts under it
	local gfH = layoutGroupFinder(s)
	s.gfPushed = false
	if gfH > 0 then
		local gy = rowsH > 0 and (top + rowsH + 8) or top
		s.gfRows:ClearAllPoints()
		s.gfRows:SetPoint("TOPLEFT", s.content, "TOPLEFT", PAD, -gy)
		rowsH = (rowsH > 0 and (rowsH + 8) or 0) + gfH
		if #list == 0 then
			-- (#317, run 5) on top of an empty list it stands under your bounty's card by anchors, and the empty
			-- state under it (s.update)
			local above = s.emptyUnder
			if above and above:IsShown() then
				s.gfRows:ClearAllPoints()
				s.gfRows:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -8)
			end
			s.emptyUnder = s.gfRows
			s.listTop = top + gfH + 8
			s.gfPushed = true
			rowsH = 0
			top = s.listTop
		end
	end
	local height = top + rowsH + UI.LIST_PAD
	s.content:SetHeight(math.max(10, height))
	local clipH = N(s.clip:GetHeight()) or (BODY_H - SHEET_TOP - LIST_TOP - 8)
	ui.scrollMax = math.max(0, height - clipH)
	ui.scrollTarget = clamp(ui.scrollTarget, 0, ui.scrollMax)
	if s.staggerNext then
		-- the first look at Home: the first rows rise in turn
		s.staggerNext = false
		local rows = {}
		for _, d in ipairs(list) do rows[#rows + 1] = ui.cards[d.key] end
		local shown = {}
		for i = 1, math.min(#rows, 6) do shown[i] = rows[i] end
		for i = 7, #rows do rows[i]:Show() rows[i]:SetAlpha(rows[i].disabled and 0.55 or 1) end
		A.Stagger(shown, 0.05, "SlideUp")
	else
		for _, c in ipairs(fresh) do A.FadeIn(c, 0.2) end
	end
	-- the faded look of paused rows survives the animations
	for _, c in pairs(ui.cards) do
		if c.disabled then W.After(0.4, function() if c.disabled then c:SetAlpha(0.55) end end) end
	end
end

-- Per frame while Home is shown: the list scrolls smoothly. (Design 2: the rows stand where their card puts them.)
local function homeFrame(s, elapsed)
	local k = math.min(1, (elapsed or 0) * 14)
	if ui.scroll ~= ui.scrollTarget then
		local y = ui.scroll + (ui.scrollTarget - ui.scroll) * k
		if math.abs(y - ui.scrollTarget) < 0.5 then y = ui.scrollTarget end
		ui.scroll = y
		s.content:ClearAllPoints()
		s.content:SetPoint("TOPLEFT", s.clip, "TOPLEFT", 0, y)
	end
	-- (the scroll bar is the shared T.EdgeFade one; Home no longer draws a second)
end

-- (REC-01) /wuber why, read only: why "Your usual" (the card, s.update) is not on Home, or nil when it
-- shows; the first rule in s.update's order.
function Mod.WhyUsual()
	if ui.filter then return "Your usual: hidden while you search." end
	if usualRide() then return nil end
	local upl = usualPlace()
	if not upl then return "Your usual: no rides yet, so no usual place." end
	if atHere(upl) then return "Your usual: you are already there." end
	-- (REV-r28-4) name the usual driver when somebody else is open at the place
	local u, k2 = call(W.Usual)
	local key
	if type(u) == "table" then
		key = S(u.driverKey) or S(u.key) or (S(u.driver) and W.Key(u.driver))
	else
		key = S(k2)
	end
	local d = key and UI.Driver(key)
	if d and d.key ~= myKey() then
		local other = false
		for _, o in ipairs(UI.Drivers()) do
			local od = S(o.dest)
			if o.state == "open" and o.key ~= d.key and o.key ~= myKey() and od
				and (od == upl or (type(W.SamePlace) == "function" and call(W.SamePlace, od, upl) == true)) then
				other = true
				break
			end
		end
		local nm = S(d.name) or S(d.key)
		if d.state == "paused" and nm then return "Your usual: " .. nm .. " is paused right now." end
		if other and nm then return "Your usual: " .. nm .. " is not open at " .. upl .. " right now." end
	elseif not d and key then
		local nm = S(type(u) == "table" and u.driver) or key
		for _, o in ipairs(UI.Drivers()) do
			local od = S(o.dest)
			if o.state == "open" and o.key ~= myKey() and od
				and (od == upl or (type(W.SamePlace) == "function" and call(W.SamePlace, od, upl) == true)) then
				return "Your usual: " .. nm .. " is not open at " .. upl .. " right now."
			end
		end
	end
	return "Your usual: nobody is open at " .. upl .. "."
end

local BOUNTY_WHY = {
	drive = "Bounties (driving): off in Settings.",
	served = "Bounty offers: a driver already serves that place.",
	online = "Bounty offers: drivers are online right now.",
	raid = "Bounty offers: not while your raid runs summons.",
	place = "Bounty offers: only for a town or city.",
	here = "Bounty offers: you are already there.",
	net = "Bounty offers: Wuber can't reach its network.",
	pinned = "Bounty offers: you already have one pinned.",
	own = "Bounty offers: you are an open driver.",
}
-- why UI.BountyPlace said no: an open driver serves it, or it is no town or city
local function bountyMiss(place, all)
	for _, d in ipairs(all) do
		local dest = d.state == "open" and S(d.dest)
		if dest and ((type(W.SamePlace) == "function" and call(W.SamePlace, dest, place) == true) or dest:lower() == place:lower()) then
			return BOUNTY_WHY.served
		end
	end
	return BOUNTY_WHY.place
end
-- (REC-01) /wuber why, read only: why no bounty is offered on Home (the empty state's bounty card for a
-- searched place, or its "Pin a bounty for" pill for the usual place), in s.update's order; for an open
-- driver, the console's "Show what riders want" switch first. nil when an offer shows or none is due.
function Mod.WhyBounty()
	local DR, dd = W.Drive, W.db and W.db.drive
	if type(DR) == "table" and call(DR.IsOpen) == true and type(dd) == "table" and type(dd.opts) == "table"
		and dd.opts.watchBounty == false then
		return BOUNTY_WHY.drive
	end
	local f = ui.filter
	local wplace = f and S(f.place)
	local up = (not f) and usualPlace() or nil
	if not (wplace or up) then return nil end
	local all = UI.Drivers()
	for _, d in ipairs(all) do
		if matches(d, f) then return wplace and BOUNTY_WHY.served or BOUNTY_WHY.online end
	end
	if UI.RaidHere() then return BOUNTY_WHY.raid end
	if wplace then
		local bplace = UI.BountyPlace(wplace, all)
		if not bplace then return bountyMiss(wplace, all) end
		return atHere(bplace) and BOUNTY_WHY.here or nil
	end
	if not onNetwork() then return BOUNTY_WHY.net end
	if atHere(up) then return BOUNTY_WHY.here end
	if UI.BountyMine() then return BOUNTY_WHY.pinned end
	if not UI.BountyPlace(up, all) then return bountyMiss(up, all) end
	if ownBeacon() then return BOUNTY_WHY.own end
	return nil
end

W.Listen("SETTINGS", function(key)
	if key == "advanced" or key == "groupFinder" then UI.Refresh(true) end
end)

-- (Group Finder) a search began, ended or changed the listed drivers: the rows and the cards are drawn again
W.Listen("GROUPFINDER", function()
	if W.GroupFinder and W.GroupFinder.On() then UI.Refresh(true) end
end)

-- internals other modules use (bound at load by later modules, or called late)
Mod.buildHome = buildHome
Mod.homeFrame = homeFrame
