-- Module: UI.InFlight
-- Purpose: mid-flight summon offer: while on a flight path with at least 90 s left and an open
--   driver at the destination, shows a small card once per flight with Book and Don't show. (Design 2) The card is a
--   T.SheetCard (the one sheet look) inside a frame named WuberInFlight that carries the place: "Book · <price>" is
--   its gold main button, "Don't show" its link, the x hides it for this flight. It sits clear of Wuber's window.
-- API: Mod.Check, Mod.Refresh, Mod.Hide, Mod.Card, Mod.Driver, Mod.Why
--   Refresh(): while the card is up, re-reads the driver, his price and the time left (the step calls it each second); false when no open driver is left
-- Internals: onTaxi, flightLeft, rideBlocks, placeKey, pickDriver (skips a driver whose summon is not faster than the flight left), buildCard, layoutCard,
--   frameRect, windowRect, winChanged, onScreen, rectsNear, setAnchor, validPlacement,
--   placeCard, fillCard, openBook, onLand, wireLand, startWatch, beginFlight
-- Uses: UI.Kit
-- Later: UI.Map.Map (RedrawSoon)
-- Events: listens On PLAYER_CONTROL_LOST, On TAXIMAP_CLOSED, On PLAYER_REGEN_DISABLED,
--   On PLAYER_ENTERING_WORLD, Listen RIDE (from the first flight: On PLAYER_CONTROL_GAINED);
--   fires SETTINGS (midFlight, from "Don't show")
-- Standalone: no
-- Test: tests/v24/inflight_test.lua
-- From: new in Wuber 2.4 (part 6)

local _, W = ...
local Mod = W.Module("UI.InFlight", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local N = KitMod.N
local S = KitMod.S
local call = KitMod.call
local inCombat = KitMod.inCombat
local money = KitMod.money
local myKey = KitMod.myKey
local rideActive = KitMod.rideActive
local safeScript = KitMod.safeScript
local T = W.Theme
local UI = W.UI

local K = {
	MIN_LEFT = 90,
	CHECK = 1,
	W = 280,
	MAXW = 320,
	TOP_Y = -210, -- (run 1) lower than the Daylight "Flying to" bar and the zone text at top centre
	TOP = 18, -- the sheet card's body starts this far below its top (no title: the two lines are the offer)
	FOOT = 100, -- the main button (46 high, 12 clear below and above) and the link under it (30)
	TEXT_W = 216, -- the lines' width: clear of the x at the right
	WIN_GAP = 32, -- (lead review) parts of Wuber's window stick out past its frame (the layout checker measured 21 px or more): keep well clear
}

local card, shownThisFlight, flightOn, watchToken
local dragging = false
local saveCardPos -- below, where frameRect is
local landWired = false
local lastWinShown, lastWl, lastWr, lastWt, lastWb
local noRoom = false -- (lead review) no place clear of Wuber's own window: the card waits

local function onTaxi()
	return type(W.OnTaxi) == "function" and W.OnTaxi() == true
end

local function flightLeft()
	if type(W.FlightLeft) ~= "function" then return nil, nil end
	local left, dest = W.FlightLeft()
	return N(left), S(dest)
end

local function rideBlocks()
	local rv = KitMod.rideView()
	return rideActive(rv) and (rv.rank or 0) < KitMod.RIDE_RANK.arrived
end

local function placeKey(name)
	name = S(name)
	if not name then return nil end
	if type(W.FLY) == "table" and type(W.FLY.NodePlace) == "function" then
		name = S(call(W.FLY.NodePlace, name)) or name
	end
	local k = type(W.NormPlace) == "function" and S(call(W.NormPlace, name)) or name:lower()
	return k ~= "" and k or nil
end

-- (left: the flight seconds left; a driver whose summon, UI.SummonWait(d), is not faster than that is no offer)
local function pickDriver(dest, left)
	local target = placeKey(dest)
	if not target then return nil end
	local me = myKey()
	local best, bestGlow
	for _, d in ipairs(UI.Drivers and UI.Drivers() or {}) do
		if type(d) == "table" and d.state == "open" and d.key ~= me and placeKey(d.dest) == target
			and not (left and (N(UI.SummonWait and UI.SummonWait(d)) or 30) >= left) then
			local glow = UI.Prominence and N((select(1, UI.Prominence(d)))) or 0
			local price = N(d.price) or 0
			if not best or glow > bestGlow or (glow == bestGlow and price < (N(best.price) or 0)) then
				best, bestGlow = d, glow
			end
		end
	end
	return best
end

local function openBook()
	local key = card and card.key
	Mod.Hide()
	if not key then return end
	if UI.Toggle and not (UI.state and UI.state.win and UI.state.win:IsShown()) then UI.Toggle(true) end
	UI.Show("confirm", key)
end

local function buildCard()
	local c = CreateFrame("Frame", "WuberInFlight", UIParent)
	c:SetSize(K.W, 200)
	c:SetClampedToScreen(true)
	c:SetFrameStrata("HIGH")
	local sc = T.SheetCard(c, K.W, 200, "")
	sc:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	c.sheet = sc
	sc.card.topPad = K.TOP
	c.line1 = T.Para(sc.body, "sub", "white", K.TEXT_W, "medium")
	c.line1:SetPoint("TOPLEFT", sc.body, "TOPLEFT", 16, 0)
	c.line2 = T.Para(sc.body, "caption", "muted", K.TEXT_W, "regular")
	c.line2:SetPoint("TOPLEFT", c.line1, "BOTTOMLEFT", 0, -6)

	c.book = sc:MainButton("Book", openBook, "Opens Wuber on this driver. You still click Request yourself.")
	c.x = sc.close
	T.Press(c.x)
	safeScript(c.x, "OnClick", function() Mod.Hide() end)
	T.Tip(c.x, "Close")
	c.never = sc:Link("Don't show", function()
		if W.db then W.db.midFlight = false end
		W.Fire("SETTINGS", "midFlight")
		Mod.Hide()
		UI.Toast("No more offers while you fly. To get them back, turn Flight offers off and on in Settings (Riding).", "info")
	end, "No more offers while you fly.")
	-- (run 1) the card can be dragged by the left button (from the card, its sheet, or its inner sheet card); the spot is saved
	c:SetMovable(true)
	sc.card.wuberNoTip = nil
	for _, f in ipairs({ c, sc, sc.card }) do
		f:EnableMouse(true)
		-- (run 1, Q5, 22 Nov) "Drag to move" on Wuber's own tip card; below the card, never above it (the Daylight "Flying to" bar is up there)
		T.Tip(f, "Drag to move", nil, "ANCHOR_BOTTOM")
		f:RegisterForDrag("LeftButton")
		safeScript(f, "OnDragStart", function()
			dragging = true
			c:StartMoving()
		end)
		safeScript(f, "OnDragStop", function()
			c:StopMovingOrSizing()
			dragging = false
			saveCardPos(c)
		end)
	end
	-- the sheet's own fade-out ends hidden: the frame that carries the name goes with it
	sc:HookScript("OnHide", function() c:Hide() end)
	c:Hide()
	return c
end

-- the card's height follows its two lines (wrapped, with line spacing); the width is the sheet card's own
local fillCard
local function layoutCard(c)
	local h1 = tonumber(c.line1.paraH) or 0
	local h2 = tonumber(c.line2.paraH) or 0
	local w, h = K.W, K.TOP + h1 + 6 + h2 + 10 + K.FOOT
	c:SetSize(w, h)
	c.sheet:SetSize(w, h)
	return w, h
end

local function frameRect(f)
	if type(f) ~= "table" and type(f) ~= "userdata" then return nil end
	local uScale = type(UIParent.GetEffectiveScale) == "function" and N(call(UIParent.GetEffectiveScale, UIParent)) or 1
	if not uScale or uScale <= 0 then uScale = 1 end
	local fScale = type(f.GetEffectiveScale) == "function" and N(call(f.GetEffectiveScale, f)) or uScale
	if not fScale or fScale <= 0 then fScale = uScale end
	local l = type(f.GetLeft) == "function" and N(call(f.GetLeft, f)) or nil
	local r = type(f.GetRight) == "function" and N(call(f.GetRight, f)) or nil
	local t = type(f.GetTop) == "function" and N(call(f.GetTop, f)) or nil
	local b = type(f.GetBottom) == "function" and N(call(f.GetBottom, f)) or nil
	if not (l and r and t and b) then return nil end
	local k = fScale / uScale
	return l * k, r * k, t * k, b * k
end

-- where the player dropped the card: the left and bottom edge in screen units (W.db.flightCardPos, made here)
saveCardPos = function(c)
	local l, r, t, b = frameRect(c)
	if l and b and W.db then W.db.flightCardPos = { math.floor(l + 0.5), math.floor(b + 0.5) } end
end

local function windowRect()
	local wf = type(_G) == "table" and rawget(_G, "WuberFrame") or nil
	if type(wf) ~= "table" and type(wf) ~= "userdata" then return false end
	if type(wf.IsShown) ~= "function" or W.Plain(call(wf.IsShown, wf)) ~= true then return false end
	local wl, wr, wt, wb = frameRect(wf)
	if not wl then return true end
	return true, wl, wr, wt, wb
end

local function winChanged()
	local shown, wl, wr, wt, wb = windowRect()
	if shown ~= lastWinShown then return true end
	if not shown then return false end
	return wl ~= lastWl or wr ~= lastWr or wt ~= lastWt or wb ~= lastWb
end

local function onScreen(l, b, w, h, sw, sh)
	return l >= 0 and l + w <= sw and b >= 0 and b + h <= sh
end

local function rectsNear(l, b, w, h, wl, wr, wt, wb, gap)
	return l < wr + gap and l + w > wl - gap and b < wt + gap and b + h > wb - gap
end

local function setAnchor(c, pt, x, y)
	c:ClearAllPoints()
	c:SetPoint(pt, UIParent, "BOTTOMLEFT", x, y)
	c:SetFrameStrata("HIGH")
end

local function validPlacement(c, sw, sh, wl, wr, wt, wb, gap)
	local cl, cr, ct, cb = frameRect(c)
	if not cl then return true end
	if not onScreen(cl, cb, cr - cl, ct - cb, sw, sh) then return false end
	if wl and rectsNear(cl, cb, cr - cl, ct - cb, wl, wr, wt, wb, gap) then return false end
	return true
end

-- Wuber's own floating pieces that can be up with the card (the driver's floating button and mini console)
local function ownRects()
	local out = {}
	for _, name in ipairs({ "WuberDriveButton", "WuberDriveMini" }) do
		local f = rawget(_G, name)
		if type(f) == "table" and type(f.IsShown) == "function" and W.Plain(call(f.IsShown, f)) == true then
			local l, r, t, b = frameRect(f)
			if l then out[#out + 1] = { l, r, t, b } end
		end
	end
	return out
end

local function placeCard(c)
	local cw, ch = layoutCard(c)
	local sw, sh = N(call(UIParent.GetWidth, UIParent)) or 0, N(call(UIParent.GetHeight, UIParent)) or 0
	local shown, wl, wr, wt, wb = windowRect()
	lastWinShown, lastWl, lastWr, lastWt, lastWb = shown, wl, wr, wt, wb
	if sw <= 0 or sh <= 0 then
		c:ClearAllPoints()
		c:SetPoint("TOP", UIParent, "TOP", 0, K.TOP_Y)
		c:SetFrameStrata("HIGH")
		return true
	end
	-- (run 1) a spot the player chose, while it is on screen: used as it is, no nudging
	local sp = W.db and W.db.flightCardPos
	if type(sp) == "table" and N(sp[1]) and N(sp[2]) and onScreen(N(sp[1]), N(sp[2]), cw, ch, sw, sh) then
		setAnchor(c, "BOTTOMLEFT", N(sp[1]), N(sp[2]))
		return true
	end
	local dl, db = sw / 2 - cw / 2, sh + K.TOP_Y - ch
	if type(UI.ClearOfHud) == "function" then
		local nl, nb, moved = UI.ClearOfHud(dl, db, cw, ch)
		if moved then
			dl, db = N(nl) or dl, N(nb) or db
		end
	end
	-- under a floating piece of Wuber's: below it, else to its right
	for _, r in ipairs(ownRects()) do
		if rectsNear(dl, db, cw, ch, r[1], r[2], r[3], r[4], K.WIN_GAP) then
			if r[4] - K.WIN_GAP - ch >= 0 then db = r[4] - K.WIN_GAP - ch else dl = r[2] + K.WIN_GAP end
		end
	end
	dl = math.min(math.max(0, dl), math.max(0, sw - cw))
	db = math.min(math.max(0, db), math.max(0, sh - ch))
	setAnchor(c, "BOTTOMLEFT", dl, db)
	if not (shown and wl) then return true end
	local cl, cr, ct, cb = frameRect(c)
	local near
	if cl then
		near = rectsNear(cl, cb, cr - cl, ct - cb, wl, wr, wt, wb, K.WIN_GAP)
	else
		near = rectsNear(dl, db, cw, ch, wl, wr, wt, wb, K.WIN_GAP)
	end
	if not near then return true end

	-- (lead review) above the window when that fits on screen
	local ax = (wl + wr) / 2
	if onScreen(ax - cw / 2, wt + K.WIN_GAP, cw, ch, sw, sh) then
		setAnchor(c, "BOTTOM", ax, wt + K.WIN_GAP)
		if validPlacement(c, sw, sh, wl, wr, wt, wb, K.WIN_GAP - 0.5) then return true end
	end
	-- else beside it: the card narrows to the free strip (its text wraps: nothing is cut)
	local function beside(avail, point, x)
		if avail < K.W then return false end
		local w2, h2 = layoutCard(c, math.min(K.MAXW, avail))
		if w2 > avail or h2 > sh then return false end
		setAnchor(c, point, x, math.min(sh, math.max(h2, wt)))
		return validPlacement(c, sw, sh, wl, wr, wt, wb, K.WIN_GAP - 0.5)
	end
	if beside(wl - 2 * K.WIN_GAP, "TOPRIGHT", wl - K.WIN_GAP) then return true end
	if beside(sw - wr - 2 * K.WIN_GAP, "TOPLEFT", wr + K.WIN_GAP) then return true end
	-- no free place: the caller hides the card until there is one
	layoutCard(c)
	setAnchor(c, "BOTTOMLEFT", dl, db)
	return false
end

function Mod.Card() return card end

function Mod.Driver()
	if card and card:IsShown() then return card.key end
	return nil
end

local function redrawMap()
	if type(W.Map) == "table" and type(W.Map.RedrawSoon) == "function" then
		call(W.Map.RedrawSoon)
	end
end

function Mod.Hide()
	lastWinShown, lastWl, lastWr, lastWt, lastWb = nil, nil, nil, nil, nil
	if card then
		local wasShown = card:IsShown()
		card.key = nil
		if wasShown then
			card.sheet:Close(true)
			card:Hide()
			redrawMap()
		end
	end
end

local function onLand()
	watchToken = nil
	flightOn = false
	shownThisFlight = false
	noRoom = false
	Mod.Hide()
end

local function wireLand()
	if landWired then return end
	landWired = true
	W.On("PLAYER_CONTROL_GAINED", function()
		if not onTaxi() then onLand() end
	end)
end

local function startWatch()
	wireLand()
	if watchToken then return end
	local tok = {}
	watchToken = tok
	local function step()
		if watchToken ~= tok then return end
		if not onTaxi() then onLand() return end
		if card and card:IsShown() then
			if inCombat() or rideBlocks() then
				Mod.Hide()
			elseif not Mod.Refresh() then
				-- the driver has closed his shop (or gone): the card goes; another open driver may bring it back
				shownThisFlight = false
				Mod.Hide()
			elseif not dragging and winChanged() then
				if not placeCard(card) then
					-- the window now leaves no room: the card goes and may come back on this flight
					noRoom, shownThisFlight = true, false
					Mod.Hide()
				end
			end
		elseif not shownThisFlight then
			Mod.Check()
		end
		W.After(K.CHECK, step)
	end
	W.After(0.1, step)
end

local function beginFlight()
	if not onTaxi() then return end
	if not flightOn then
		flightOn = true
		shownThisFlight = false
	end
	startWatch()
end

-- The card's words for driver d (Check fills it, Refresh keeps it true while it is up).
fillCard = function(d, left, dest)
	local mins = math.max(1, math.floor(left / 60))
	local wait = math.floor((N(UI.SummonWait and UI.SummonWait(d)) or 30) + 0.5)
	local place = S(d.dest) or dest
	card.line1:SetPara("About " .. mins .. " min left. A summon takes about " .. wait .. " sec.")
	card.line2:SetPara("The summon is at " .. place .. ": check your world map to see it.")
	card.book:SetLabel("Book · " .. money(d.price))
	card.key = d.key
	card.words = mins .. "|" .. wait .. "|" .. place .. "|" .. tostring(d.price) .. "|" .. tostring(d.key)
end

-- While the card is up: the driver it names, his price and the time left, as they are now.
-- Returns false when no open driver goes there any more.
function Mod.Refresh()
	if not (card and card:IsShown()) then return true end
	local left, dest = flightLeft()
	if not left or not dest then return true end
	local d = pickDriver(dest, left)
	if not d then return false end
	local before = card.words
	fillCard(d, left, dest)
	if card.words ~= before then layoutCard(card) end
	return true
end

function Mod.Check()
	if not onTaxi() then
		if flightOn then onLand() end
		return false
	end
	if not flightOn then
		flightOn = true
		shownThisFlight = false
		startWatch()
	end
	if shownThisFlight or (card and card:IsShown()) then return false end
	if not W.db or W.db.flightOffers == false or W.db.midFlight == false then return false end
	if inCombat() or rideBlocks() then return false end
	local left, dest = flightLeft()
	if not left or left < K.MIN_LEFT or not dest then return false end
	local d = pickDriver(dest, left)
	if not d then return false end
	card = card or buildCard()
	fillCard(d, left, dest)
	if not placeCard(card) then
		noRoom = true
		return false
	end
	shownThisFlight = true
	card.key = d.key
	card.sheet:Open() -- (first: an Open ends a drop still running, which hides the frame that carries the name)
	card:Show()
	if not placeCard(card) then
		noRoom, shownThisFlight = true, false
		Mod.Hide()
		return false
	end
	noRoom = false
	redrawMap()
	return true
end

function Mod.Why()
	if card and card:IsShown() then return nil end
	if not W.db then return nil end
	if W.db.flightOffers == false or W.db.midFlight == false then
		return "Mid-flight offer: off in Settings (Riding, Flight offers)."
	end
	if not onTaxi() then return nil end
	if shownThisFlight then return "Mid-flight offer: already shown on this flight." end
	if inCombat() then return "Mid-flight offer: in combat." end
	if rideBlocks() then return "Mid-flight offer: on a ride." end
	local left, dest = flightLeft()
	if not left then return "Mid-flight offer: time left is unknown." end
	if left < K.MIN_LEFT then return "Mid-flight offer: under 90 seconds left." end
	if not pickDriver(dest, left) then return "Mid-flight offer: no open driver to that place." end
	if noRoom then return "Mid-flight offer: no room beside Wuber's window." end
	return nil
end

W.On("PLAYER_CONTROL_LOST", function()
	if onTaxi() then beginFlight() else W.After(0.1, beginFlight) end
end)
W.On("TAXIMAP_CLOSED", function()
	W.After(1.1, beginFlight)
end)
W.On("PLAYER_REGEN_DISABLED", function() Mod.Hide() end)
W.On("PLAYER_ENTERING_WORLD", function()
	if not onTaxi() then onLand() else Mod.Hide() end
end)
W.Listen("RIDE", function()
	if rideBlocks() then Mod.Hide() end
end)
