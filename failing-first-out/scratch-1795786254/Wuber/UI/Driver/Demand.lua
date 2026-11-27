-- Module: UI.Driver.Demand
-- Purpose: what riders want (bounties) on the driver's console: the "3 riders want Gadgetzan" line
--   (folded, above the riders), the "Wanted nearby" card (unfolded, on the left) and its sheet with "Serve it".
-- API: D.screens.demand, D.DemandCard
-- Internals: List, Range, Here, drawLine, hideLine, serve
-- Uses: UI.Driver.Screens
-- Later: (none)
-- Events: listens (none: the console redraws once a second); fires (none)
-- Standalone: no
-- Test: tests/ui/driver/demand_test.lua
-- From: new in Wuber 2.3.0
--
-- The data is Net.Bounty's W.Bounty.Demand() -> { { place, riders, low, high, newest }, ... }
-- (newest: seconds since the latest bounty for that place)
-- (riders who pinned a bounty for a place no open driver serves; anti-abuse, faction and the
-- range are Net.Bounty's). Shown only to the character running a selling service, and only
-- while the Driving setting "Show what riders want" (opts.watchBounty) is on. A bounty is a wish,
-- not a payment: nothing here moves gold. "Serve it" opens the price and place sheet with that
-- place chosen, only when the driver stands there (else its tip says "Go there to serve them").
-- Nothing is made until there is something to show (an idle console keeps its 2.2 widgets).

local _, W = ...
local Mod = W.Module("UI.Driver.Demand", { "UI.Driver.Screens" })
local ScreensMod = W.Mod("UI.Driver.Screens")
local PAD, INNER = ScreensMod.PAD, ScreensMod.INNER
local call, dr, money = ScreensMod.call, ScreensMod.dr, ScreensMod.money
local opts, plural, safeScript, setShown = ScreensMod.opts, ScreensMod.plural, ScreensMod.safeScript, ScreensMod.setShown
local st = ScreensMod.st
local T = W.Theme

local DR = W.Drive
local D = W.Driver

local S, N = W.Str, W.Num

local MAX_PLACES = 5

---------------------------------------------------------------------------
-- The data
---------------------------------------------------------------------------

-- the places riders want, most riders first (then the newest), at most `max`; {} when the
-- setting is off, in raid summons, or for a helper
local function List(max)
	if opts().watchBounty == false then return {} end
	local K = D.kit or {}
	if K.RaidMode and K.RaidMode() then return {} end
	if D.Role and D.Role() ~= "driver" then return {} end
	local B = W.Bounty
	local raw = type(B) == "table" and call(B.Demand) or nil
	if type(raw) ~= "table" then return {} end
	local out = {}
	for _, e in ipairs(raw) do
		local place, riders = type(e) == "table" and S(e.place), type(e) == "table" and N(e.riders)
		if place and place ~= "" and riders and riders >= 1 then
			out[#out + 1] = { place = W.Clean(place, 32), riders = math.floor(riders), low = N(e.low), high = N(e.high), newest = N(e.newest) }
		end
	end
	-- (newest is an age in seconds: the smaller, the newer; none known sorts last)
	local huge = math.huge
	table.sort(out, function(a, b)
		if a.riders ~= b.riders then return a.riders > b.riders end
		if (a.newest or huge) ~= (b.newest or huge) then return (a.newest or huge) < (b.newest or huge) end
		return a.place < b.place
	end)
	for i = #out, (max or MAX_PLACES) + 1, -1 do out[i] = nil end
	return out
end

-- "50s–1g" (one price when low = high), or nil when no pledge is known
local function Range(e)
	local lo, hi = N(e.low), N(e.high)
	if not lo and not hi then return nil end
	lo, hi = lo or hi, hi or lo
	if lo > hi then lo, hi = hi, lo end
	if lo == hi then return money(lo) end
	return money(lo) .. "–" .. money(hi)
end

-- how long ago the newest rider pinned it ("newest": W.Bounty.Demand's age in seconds; a time()
-- stamp, from an older caller, still reads right)
local function age(e)
	local at = N(e.newest)
	if not at then return nil end
	if at > 1e8 then return W.Ago(math.max(0, (N(call(time)) or at) - at)) end
	return W.Ago(math.max(0, at))
end

local function Here(place)
	local here = type(W.DestHere) == "function" and call(W.DestHere) or nil
	if type(here) == "table" then here = here.name end
	here = S(here)
	if not here or not place then return false end
	if type(W.SamePlace) == "function" then return call(W.SamePlace, here, place) == true end
	return here:lower() == place:lower()
end

local function detail(e)
	local bits = { plural(e.riders, "rider") }
	local range = Range(e)
	if range then bits[#bits + 1] = range end
	local ago = age(e)
	if ago then bits[#bits + 1] = "newest " .. ago end
	return table.concat(bits, " · ")
end

-- "Serve it": the price and place sheet with that place chosen (only where the driver stands)
local function serve(place)
	if not Here(place) then
		ScreensMod.toast("Go to " .. place .. " to serve them: Wuber summons riders to where you stand", "info")
		return false
	end
	return D.ShowSheet("sheet", { dest = place }) == true
end

---------------------------------------------------------------------------
-- A place row (the sheet and the card): the place, "3 riders · 50s–1g · newest 2 min ago",
-- "Serve it"
---------------------------------------------------------------------------

local function placeRow(parent, w)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(w, 56) -- (design 3) the line under the place is the row's full width, below the button
	r.bg = T.Rounded(r, "card", 12, "BACKGROUND", 0)
	r.coin = T.Icon(r, "coin", 16, "muted", "ARTWORK")
	r.coin:SetPoint("LEFT", r, "LEFT", 12, 0)
	r.place = T.Text(r, "body", "white", "LEFT", "bold")
	r.place:SetPoint("TOPLEFT", r, "TOPLEFT", 38, -12) -- (design 3, P) 12 above the place, the detail line 4 under it
	r.place:SetWidth(w - 38 - 100)
	r.sub = T.Text(r, "caption", "muted", "LEFT", "regular")
	r.sub:SetPoint("TOPLEFT", r, "TOPLEFT", 38, -33)
	r.sub:SetWidth(w - 38 - 12)
	r.serve = T.Pill(r, "Serve it", "dark", 84, 26)
	r.serve:SetPoint("TOPRIGHT", r, "TOPRIGHT", -10, -6)
	safeScript(r.serve, "OnClick", function()
		if r.e and serve(r.e.place) and r.onServe then r.onServe() end
	end)
	T.Tip(r.serve, "Serve it", function()
		if r.e and not Here(r.e.place) then return "Go there to serve them. Wuber summons riders to where you stand." end
		return "Opens your price and place with " .. (r.e and r.e.place or "this place") .. " chosen. Riders who wanted it hear you serve it."
	end)
	r:EnableMouse(true)
	T.Tip(r, function() return r.e and r.e.place or "Wanted" end, function()
		return "Riders pinned a bounty for this place: nobody summons there right now. A bounty is a wish, not a payment: they still pay your fare."
	end)
	function r.Set(self, e)
		self.e = e
		self.place:SetText(e.place)
		self.sub:SetText(detail(e))
		local here = Here(e.place)
		self.serve:SetStyle(here and "primary" or "dark")
		self.serve:SetActive(here)
		self.coin:SetVertexColor(T.RGB(here and "glow" or "muted"))
	end
	return r
end

---------------------------------------------------------------------------
-- The folded console: one line above the queue (round 13, I9), "3 riders want Gadgetzan" (tap: the sheet)
---------------------------------------------------------------------------

local function drawLine(v, y)
	local list = List(MAX_PLACES)
	if #list == 0 then
		if v.demand then v.demand:Hide() end
		return y
	end
	local b = v.demand
	if not b then
		b = CreateFrame("Button", nil, v.scroll.content)
		b:SetSize(INNER, 30)
		b:RegisterForClicks("LeftButtonUp")
		b.fill = T.PillFill(b, "card", 30, "BACKGROUND", 0)
		b.coin = T.Icon(b, "coin", 14, "muted", "ARTWORK")
		b.coin:SetPoint("LEFT", b, "LEFT", 12, 0)
		b.text = T.Text(b, "sub", "white", "LEFT", "medium")
		b.text:SetPoint("LEFT", b, "LEFT", 32, 0)
		b.text:SetPoint("RIGHT", b, "RIGHT", -26, 0)
		b.chev = T.Icon(b, "back", 9, "muted", "OVERLAY")
		b.chev:SetPoint("RIGHT", b, "RIGHT", -10, 0)
		T.Try(b.chev, "SetRotation", math.pi)
		safeScript(b, "OnEnter", function(self) self.fill:SetColor("hover") end)
		safeScript(b, "OnLeave", function(self) self.fill:SetColor("card") end)
		T.Press(b, { fill = b.fill })
		safeScript(b, "OnClick", function() D.ShowSheet("demand") end)
		T.Tip(b, "What riders want", "Riders pinned bounties for places nobody summons to right now. Tap to see them all and serve one.")
		v.demand = b
	end
	local top = list[1]
	local more = #list > 1 and (" · +" .. (#list - 1) .. " more") or ""
	b.text:SetText(plural(top.riders, "rider") .. " want" .. (top.riders == 1 and "s " or " ") .. top.place .. more)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", v.scroll.content, "TOPLEFT", PAD, -y)
	b:Show()
	return y + 30 + 10
end

local function hideLine(v)
	if v and v.demand then v.demand:Hide() end
end

---------------------------------------------------------------------------
-- The sheet (from the line): every place, each with "Serve it"
---------------------------------------------------------------------------

D.screens.demand = function(parent)
	local sh = T.Sheet(parent, 300, "What riders want")
	local s = { frame = sh, rows = {} }
	st.screens.demand = s
	local b = sh.body
	s.note = T.Text(b, "caption", "muted", "LEFT", "regular")
	s.note:SetWidth(320)
	T.Lines(s.note, 2)
	s.note:SetText("A bounty is a wish, not a payment: riders still pay your fare. Wuber never moves gold.")
	s.empty = T.Text(b, "sub", "muted", "LEFT", "regular")
	s.empty:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -6)
	s.empty:SetWidth(320)
	s.empty:SetText("Nobody is asking for a place right now.")
	s.update = function()
		local list = List(MAX_PLACES)
		local y = 2
		for i, e in ipairs(list) do
			local r = s.rows[i]
			if not r then
				r = placeRow(b, 320)
				r.onServe = function() end
				s.rows[i] = r
			end
			r:Set(e)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -y)
			r:Show()
			y = y + 64
		end
		for i = #list + 1, #s.rows do s.rows[i]:Hide() end
		setShown(s.empty, #list == 0)
		if #list == 0 then y = y + 30 end
		s.note:ClearAllPoints()
		s.note:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -(y + 4))
		sh:SetSheetHeight(66 + y + 40)
	end
	s.enter = function()
		sh:SetTitle("What riders want", "Places nobody summons to right now")
	end
	return s
end

---------------------------------------------------------------------------
-- The unfolded console's "Wanted nearby" card (top five places): on the left pane since round 13 (I9)
---------------------------------------------------------------------------

-- D.DemandCard(parent, w) -> card; card:Update() -> its height (0 and hidden when nothing)
function D.DemandCard(parent, w)
	w = w or INNER
	local card = CreateFrame("Frame", nil, parent)
	card:SetSize(w, 40)
	card.head = T.Text(card, "body", "white", "LEFT", "bold")
	card.head:SetPoint("TOPLEFT", card, "TOPLEFT", 4, 0)
	card.head:SetText("Wanted nearby")
	card.sub = T.Text(card, "caption", "muted", "RIGHT", "regular")
	card.sub:SetPoint("TOPRIGHT", card, "TOPRIGHT", -4, -2)
	card.sub:SetWidth(w - 130)
	card.sub:SetText("a wish, not a payment")
	card:EnableMouse(true)
	T.Tip(card, "Wanted nearby", "Riders pinned bounties for these places: nobody summons there right now. They still pay your fare; Wuber never moves gold.")
	card.rows = {}
	function card.Update(self)
		local list = List(MAX_PLACES)
		local y = 22
		for i, e in ipairs(list) do
			local r = self.rows[i]
			if not r then
				r = placeRow(self, w)
				self.rows[i] = r
			end
			r:Set(e)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
			r:Show()
			y = y + 60
		end
		for i = #list + 1, #self.rows do self.rows[i]:Hide() end
		setShown(self, #list > 0)
		if #list == 0 then return 0 end
		self:SetHeight(y)
		return y
	end
	card:Hide()
	return card
end

-- for other modules (REFACTOR-MAP section 2): set at the end, when every local holds its final value
Mod.List = List
Mod.Range = Range
Mod.Here = Here
Mod.drawLine = drawLine
Mod.hideLine = hideLine
Mod.serve = serve
