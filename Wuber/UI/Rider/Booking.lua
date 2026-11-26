-- Module: UI.Rider.Booking
-- Purpose: the booking widgets Confirm, Finding and the Found screen share: the Fly-vs-Summon dial
--   (and its pure score), and the "Brill -> Undercity" route header.
-- API: Booking.CrossWord, Booking.Dial, Booking.RouteHeader, Booking.Score, Booking.DialInfo, Booking.Verdict,
--   Booking.RouteFrom, Booking.Via
-- Internals: tanh, arcPoint, fitOrigin
-- Uses: UI.Kit
-- Later: (none)
-- Events: listens On ZONE_CHANGED and ZONE_CHANGED_INDOORS (a shown route header follows the rider); fires (none)
-- Standalone: no
-- Test: tests/ui/rider/booking_test.lua
-- From: new in Wuber 2.3.0 (SPEC7 sections 5.1, 5.2; owner C)
--
-- Through the handle:
--   local Booking = W.Mod("UI.Rider.Booking")
--   Booking.Score(info) -> knob position p (0 = fly, 1 = summon), benefit (copper). Pure:
--     benefit = timeSaved / 3600 * rate - (fare - flightCost); p = 0.5 + 0.5 * tanh(benefit / 5000)
--     (info.rate: copper an hour, default "My time is worth"; flightCost unknown counts as 0).
--   Booking.DialInfo(d, total, opts) -> the numbers for one driver (a driver view; total = fare +
--     tip; opts.wait = seconds the summon takes when known, e.g. the ride's eta; else a ready driver's
--     d.avgSummon, their average from D field 21, else W.SUMMON_SECS) or nil when nothing about
--     flying is known (the dial then stays hidden: H10).
--   Booking.Dial(parent, w, h) -> dial frame; dial:Set(info) (nil hides it), dial:SetSize(w, h)
--     (88 folded, 96 unfolded: from 96 the bigger arc); dial.verdict / dial.line / dial.flyText / dial.summonText.
--   Booking.RouteHeader(parent, w) -> header frame (w x 32); header:Set(from, to, via),
--     header:Update(dest) (from = where you stand), header:SetMaxWidth(w). A header too narrow for the route and its
--     tag on one row puts the tag on a row of its own and grows by it (header.viaBelow).
-- The knob moves by SetPoint along the arc (cos/sin): no rotation, no scale (H5).

local _, W = ...
local Mod = W.Module("UI.Rider.Booking", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local N = KitMod.N
local S = KitMod.S
local call = KitMod.call
local duration = KitMod.duration
local money = KitMod.money
local setShown = KitMod.setShown
local T = W.Theme
local function wrapH(n, size) return n * T.DrawnSize(size) + (n - 1) * T.Spacing(size) end -- n wrapped lines, spacing between them
local Try = T.Try
local UI = W.UI

local SCALE = 5000 -- copper: 50s of benefit moves the knob most of the way

local function tanh(x)
	if x > 20 then return 1 elseif x < -20 then return -1 end
	local e = math.exp(2 * x)
	return (e - 1) / (e + 1)
end

---------------------------------------------------------------------------
-- The maths (pure)
---------------------------------------------------------------------------

function Mod.Score(info)
	if type(info) ~= "table" then return nil end
	local saved = N(info.timeSaved) or 0
	local fare = N(info.fare) or 0
	local cost = N(info.flightCost) or 0
	local rate = N(info.rate) or N(W.db and W.db.timeValue) or 100000
	local benefit = saved / 3600 * rate - (fare - cost)
	local p = 0.5 + 0.5 * tanh(benefit / SCALE)
	if p < 0 then p = 0 elseif p > 1 then p = 1 end
	return p, benefit
end

-- "Summon wins by 7 min" / "Flying is 27s cheaper, 7 min slower" / "About the same"
function Mod.Verdict(info, benefit)
	local saved = N(info.timeSaved) or 0
	local about = info.flyAbout and "about " or ""
	if math.abs(benefit or 0) < 1000 then return "About the same" end
	if benefit > 0 then
		if saved >= 60 then return "Summon wins by " .. about .. duration(saved) end
		return "Summon wins"
	end
	local cost, fare = N(info.flightCost), N(info.fare) or 0
	-- (round 13, I14) by boat or zeppelin: named so, never "Flying"
	local other = info.crossing and (((cost or 0) > 0 and "Flying" or ("The " .. info.crossing))) or "Flying"
	if cost and cost <= 0 and fare > 0 and info.crossing then
		return "The " .. info.crossing .. " costs nothing" .. (saved >= 60 and (", " .. about .. duration(saved) .. " slower") or "")
	end
	if cost and fare > cost then
		-- (round 9, S18) next to a time: the amount with the game's coin icon
		-- (round 22, C1) plain "49s 50c": the coin icons made "49c 50c" and measured wide, so the line was cut
		return other .. " is " .. money(fare - cost) .. " cheaper" .. (saved >= 60 and (", " .. about .. duration(saved) .. " slower") or "")
	end
	return other .. " wins"
end

-- The flight route's two ends (W.TAXI.nodes ids) on different continents: a crossing even
-- before any flight price is known. nil, nil when the route isn't known.
local function crossesSea(dest)
	local a, b
	if type(W.FlightRoute) == "function" then
		local path = call(W.FlightRoute, nil, dest)
		if type(path) == "table" and #path >= 2 then a, b = path[1], path[#path] end
	end
	if not a and type(W.FLY) == "table" and type(W.FLY.Pair) == "function" then
		local tp, fp = call(W.FLY.Pair, nil, dest)
		a, b = fp, tp
	end
	local nodes = type(W.TAXI) == "table" and type(W.TAXI.nodes) == "table" and W.TAXI.nodes or nil
	local na, nb = nodes and a and nodes[a] or nil, nodes and b and nodes[b] or nil
	if type(na) ~= "table" or type(nb) ~= "table" or N(na[2]) == nil or N(nb[2]) == nil then return false end
	return na[2] ~= nb[2], na
end

-- the zeppelin towers (W.TAXI node ids), as the world map's arrow has them: a crossing between two of them is
-- a zeppelin, any other a boat
local ZEPPELIN = { [11] = true, [20] = true, [23] = true }

-- (BRIEF26 item 4) The crossing word the world map's arrow uses, read from the same route (W.FlightRoute):
-- the first hop between two continents is "zeppelin" (both ends towers) or "boat"; nil when the route
-- stays on one continent or isn't known. from nil: where the player stands.
function Mod.CrossWord(dest, from)
	if type(W.FlightRoute) ~= "function" or type(W.TAXI) ~= "table" or type(W.TAXI.nodes) ~= "table" then return nil end
	local ids = call(W.FlightRoute, from, dest)
	if type(ids) ~= "table" then return nil end
	for i = 1, #ids - 1 do
		local a, b = ids[i], ids[i + 1]
		local na, nb = W.TAXI.nodes[a], W.TAXI.nodes[b]
		-- (AUD-174) two zeppelin towers are a zeppelin hop even on one continent (Undercity to Grom'gol)
		if type(na) == "table" and type(nb) == "table" and (na[2] ~= nb[2] or (ZEPPELIN[a] and ZEPPELIN[b])) then
			return (ZEPPELIN[a] and ZEPPELIN[b]) and "zeppelin" or "boat"
		end
	end
	return nil
end

-- How you'd cross the sea: "zeppelin", "boat" or nil. A known flight price says so (via "boat");
-- without one, a route whose ends are on two continents is a crossing too.
function Mod.Via(dest)
	local via
	if type(W.FlightCost) == "function" then
		local _, _, _, v = call(W.FlightCost, nil, dest)
		via = v
	end
	local start
	if via ~= "boat" then
		local crosses, na = crossesSea(dest)
		if not crosses then return nil end
		start = na
	end
	local word = Mod.CrossWord(dest)
	if word then return word end
	local _, how = nil, nil
	if type(W.TravelSaved) == "function" then _, how = call(W.TravelSaved, dest) end
	if S(how) == "by zeppelin" then return "zeppelin" end
	if S(how) == "by boat" then return "boat" end
	-- (no word on how: Horde flight masters cross by zeppelin)
	if start and start[5] == "H" then return "zeppelin" end
	return "boat"
end

-- The numbers for one driver, or nil when nothing about flying is known.
function Mod.DialInfo(d, total, opts)
	if type(d) ~= "table" or not S(d.dest) then return nil end
	opts = opts or {}
	local flySecs, how, measured
	if type(W.TravelSaved) == "function" then flySecs, how, measured = call(W.TravelSaved, d.dest) end
	flySecs = N(flySecs)
	local src
	if type(W.FlightTime) == "function" then
		local _, s2 = call(W.FlightTime, nil, d.dest)
		src = S(s2)
	end
	local flyAbout = not (measured == true and src ~= "est") or how == "est"
	local flyCost = UI.FlightCostTo and UI.FlightCostTo(d.dest) or nil
	-- (round 13, I14) a trip that goes by boat or zeppelin from here is compared against that
	-- (free), not a flight: a price counts only for a priced route with the crossing on it
	-- (flights to the port, W.FlightCost's "boat")
	local crossing = (S(how) == "by zeppelin" and "zeppelin") or (S(how) == "by boat" and "boat") or nil
	-- (BRIEF26 item 4) the map's own word wins, once there is something to show
	-- (AUD-216) also when the game gave no travel answer at all (no map position: an instance, a boat) but a flight
	-- price is known: the route's own word still says boat or zeppelin
	if (flySecs or flyCost) and how ~= "same continent" and (S(how) or not flySecs) then crossing = Mod.CrossWord(d.dest) or crossing end
	if crossing then
		local via
		if type(W.FlightCost) == "function" then via = select(4, call(W.FlightCost, nil, d.dest)) end
		if via ~= "boat" then flyCost = 0 end
	end
	if not flySecs and not flyCost then return nil end
	-- FEAT-01: a ready driver's summon is their own average when they send one (10..900 s), else the default
	local ready = UI.SummonWait(d)
	local wait, waitKnown = N(opts.wait), false
	if wait then
		waitKnown = true
	elseif N(d.queue) == 0 then
		wait, waitKnown = ready, true
	end
	local info = {
		dest = d.dest, flySecs = flySecs, flyAbout = flyAbout, flightCost = flyCost, fare = N(total) or N(d.price) or 0,
		crossing = crossing, flyHead = crossing and ((flyCost or 0) > 0 and ("Fly + " .. crossing) or (crossing == "zeppelin" and "Zeppelin" or "Boat")) or nil,
		wait = wait, waitKnown = waitKnown,
		timeSaved = flySecs and math.max(0, flySecs - (wait or ready)) or 0,
		line = opts.line,
	}
	return info
end

---------------------------------------------------------------------------
-- The dial
---------------------------------------------------------------------------

local DOTS = 15

-- A point on the arc: angle from p (0 = left end, 1 = right end), in the dial's TOPLEFT space.
local function arcPoint(dial, p)
	local a = math.pi * (1 - p)
	return dial.cx + dial.r * math.cos(a), -(dial.top + dial.r - dial.r * math.sin(a))
end

local function placeKnob(dial, p)
	local x, y = arcPoint(dial, p)
	dial.knob:ClearAllPoints()
	dial.knob:SetPoint("CENTER", dial, "TOPLEFT", x, y)
	dial.p = p
end

local function layoutDial(dial)
	local w, h = N(dial:GetWidth()) or 324, (N(dial:GetHeight()) or 88) - (dial.extra or 0) -- (C1) the verdict's second line is not part of the shape
	local wide = h >= 96 -- (the unfolded Confirm's dial is 96 high; folded 88)
	local short = h <= 64 -- (r19, F3) folded Confirm squeezed by a PvP card: a flatter arc, 62 high
	dial.r = wide and 50 or (short and 20 or 38) -- (design 3) the short arc is 2 less: the body-size verdict and the small line must end inside 62
	dial.top = wide and 5 or (short and 3 or 6)
	dial.cx = w / 2
	for i, dot in ipairs(dial.dots) do
		local x, y = arcPoint(dial, (i - 1) / (DOTS - 1))
		dot:ClearAllPoints()
		dot:SetPoint("CENTER", dial, "TOPLEFT", x, y)
	end
	local side = (w - 2 * dial.r - 24) / 2
	for _, k in ipairs({ "flyHead", "flyText" }) do dial[k]:SetWidth(side) end
	for _, k in ipairs({ "sumHead", "summonText" }) do dial[k]:SetWidth(side) end
	-- (r46, HUNT-39) a new width shrinks the words again but drops a wrap: wrap the side lines again
	UI.FitOrWrap(dial.flyText)
	UI.FitOrWrap(dial.summonText)
	-- (r33, HUNT-98) a side line too long for its side wraps onto a second line (never cut with "..."); the
	-- unfolded dial's heads then start a line higher so the second line stays clear of the verdict
	local lift = (wide and (dial.flyText.wuberWrapped or dial.summonText.wuberWrapped)) and 12 or 0
	dial.flyHead:ClearAllPoints()
	dial.flyHead:SetPoint("TOPLEFT", dial, "TOPLEFT", 0, wide and -(dial.top + dial.r - 24 - lift) or -4)
	dial.flyText:ClearAllPoints()
	dial.flyText:SetPoint("TOPLEFT", dial.flyHead, "BOTTOMLEFT", 0, -3)
	dial.sumHead:ClearAllPoints()
	dial.sumHead:SetPoint("TOPRIGHT", dial, "TOPRIGHT", 0, wide and -(dial.top + dial.r - 24 - lift) or -4)
	dial.summonText:ClearAllPoints()
	dial.summonText:SetPoint("TOPRIGHT", dial.sumHead, "BOTTOMRIGHT", 0, -3)
	dial.verdict:ClearAllPoints()
	dial.verdict:SetPoint("TOP", dial, "TOP", 0, -(dial.top + dial.r + 9)) -- (r30) 9 = the knob's radius at the arc's lowest point, so it never covers the verdict
	dial.line:ClearAllPoints()
	-- (2.4 fix round, HUNT-133) the short dial's line sits right under the verdict, never a unit into it: at a large
	-- Wuber scale that unit is two pixels of one text on the other (the line still ends inside the 62)
	dial.line:SetPoint("TOP", dial.verdict, "BOTTOM", 0, (wide or short) and 0 or -3)
	T.SetFont(dial.verdict, "body", "bold")
	-- (r47, AUD-155) fitted again at the new size, so its wrap (and the room refit gives it) is the one drawn
	T.Fit(dial.verdict)
	if dial.p then placeKnob(dial, dial.p) end
end

function Mod.Dial(parent, w, h)
	local dial = CreateFrame("Frame", nil, parent)
	dial:SetSize(w or 324, h or 88)
	dial.bg = T.Rounded(dial, "card", 14, "BACKGROUND", 0)
	dial.dots = {}
	for i = 1, DOTS do
		local k = (i - 1) / (DOTS - 1)
		local dot = T.Circle(dial, 6, "glow", "ARTWORK")
		dot:SetVertexColor(0.75 + 0.23 * k, 0.65 + 0.12 * k, 1 - 0.76 * k, 0.55)
		dial.dots[i] = dot
	end
	-- the knob: a flat gold disc (moved by SetPoint only)
	local knob = CreateFrame("Frame", nil, dial)
	knob:SetSize(18, 18)
	knob:SetFrameLevel((N(dial:GetFrameLevel()) or 0) + 3)
	knob.disc = T.Circle(knob, 14, "glow", "ARTWORK")
	knob.disc:SetPoint("CENTER", knob, "CENTER")
	dial.knob = knob
	dial.flyHead = T.Text(dial, "sub", "white", "LEFT", "bold")
	dial.flyHead:SetText("Fly")
	dial.flyText = T.Text(dial, "caption", "muted", "LEFT", "regular")
	dial.sumHead = T.Text(dial, "sub", "white", "RIGHT", "bold")
	dial.sumHead:SetText("Summon")
	dial.summonText = T.Text(dial, "caption", "muted", "RIGHT", "regular")
	dial.verdict = T.Text(dial, "body", "white", "CENTER", "bold")
	dial.verdict:SetWidth((w or 324) - 16)
	-- (round 22, C1) a verdict too long for one line wraps onto a second at its own size (the dial grows by a
	-- line: dial.extra); only if two lines still fall short does it shrink, never below 11
	T.Lines(dial.verdict, 2)
	dial.verdict.wuberMin = T.SIZE.caption
	dial.line = T.Text(dial, "caption", "muted", "CENTER", "regular")
	dial.line:SetWidth((w or 324) - 16)
	dial:EnableMouse(true)
	T.Tip(dial, "Fly or summon?", function()
		local i = dial.info
		if not i then return nil end
		return "Where the knob sits weighs the time a summon saves (at what your time is worth, in Settings) against what it "
			.. "costs more than flying." .. (i.flyAbout and " A flight time with about in front is worked out from the flight paths, not timed." or "")
	end)
	local baseSize = dial.SetSize
	-- hh is the dial's own height (88 / 96 / 62); a wrapped verdict adds dial.extra under it (Confirm reads it)
	local function refit(self)
		local fs = self.verdict
		-- (design 3) the second line is one more line of the verdict's own size: drawn size plus its line spacing
		local px = N(fs.wuberPx) or T.SIZE.body
		local e = fs.wuberWrapped and (T.DrawnSize(px) + T.Spacing(px)) or 0
		-- (2.4 fix round, HUNT-139) the small line under it wraps too, never cut with "...": one more line of its size
		local ln = self.line
		if ln and ln.wuberWrapped and S(ln.wuberText) then
			local lp = N(ln.wuberPx) or T.SIZE.caption
			e = e + T.DrawnSize(lp) + T.Spacing(lp)
		end
		if e ~= (self.extra or 0) then
			self.extra = e
			baseSize(self, N(self:GetWidth()) or 324, self.baseH + e)
			layoutDial(self)
		end
	end
	function dial.SetSize(self, ww, hh)
		self.baseH = hh
		baseSize(self, ww, hh + (self.extra or 0))
		self.verdict:SetWidth(ww - 16)
		self.line:SetWidth(ww - 16)
		UI.FitOrWrap(self.line)
		layoutDial(self)
		refit(self)
	end
	function dial.Set(self, info)
		self.info = info
		if not info then
			self:Hide()
			return
		end
		local fly = {}
		-- (decisions H, the author's words) a price directly beside a time on one line: the time first with no "about",
		-- then "costing" and the gold price ("2 min · costing 23s"). A time alone keeps "about"; a price alone is bare.
		local flyBoth = info.flySecs and info.flightCost and info.flightCost > 0
		if info.flySecs then fly[#fly + 1] = ((info.flyAbout and not flyBoth) and "about " or "") .. duration(info.flySecs) end
		-- (design 1 H) amounts are letters, like W.Money writes them (nothing is "0g", never "free")
		-- (design 1 P) in gold, so "23s" beside a time is never read as seconds
		local function coins(c) return T.Code("gold") .. (c > 0 and money(c) or "0g") .. "|r" end
		if info.flightCost then fly[#fly + 1] = info.flightCost > 0 and ((flyBoth and "costing " or "") .. coins(info.flightCost)) or "free" end
		self.flyText:SetText(table.concat(fly, " · "))
		UI.FitOrWrap(self.flyText) -- (r33, HUNT-98) shrink first; a line still too long wraps
		self.flyHead:SetText(S(info.flyHead) or "Fly")
		local sum = {}
		-- (26b) a summon under a minute says its seconds ("about 30 sec", not "about under a minute": that is wider than a side)
		-- (r46, HUNT-39) "about", never a tilde, like the fly side
		-- (decisions H) beside its price: "30 sec · costing 50s", no "about" (a fare of nothing keeps the old line)
		local fare = N(info.fare) or 0
		local lead = ""
		if info.waitKnown and info.wait then
			lead = fare > 0 and "costing " or ""
			sum[#sum + 1] = (fare > 0 and "" or "about ") .. (info.wait < 60 and (math.floor(info.wait + 0.5) .. " sec") or duration(info.wait))
		end
		local net = ""
		if info.flightCost and info.flightCost > 0 then
			if fare > info.flightCost then net = " (net " .. coins(fare - info.flightCost) .. ")"
			elseif fare < info.flightCost then net = " (saves " .. coins(info.flightCost - fare) .. ")" end
		end
		sum[#sum + 1] = lead .. coins(fare) .. net
		-- (r46 lead) back to one line before the new words: a side that wrapped for the last driver would be
		-- measured at its full size below, and "(net 27s)" would step aside where it fits once shrunk (a ready
		-- driver's card first, then a busy one's)
		self.summonText.wuberLines = nil
		Try(self.summonText, "SetWordWrap", false)
		self.summonText.wuberWrapped = false
		self.summonText:SetText(table.concat(sum, " · "))
		-- (2.3.2, I29's page check) "~2 min · 50s (net 27s)" is wider than a side (the unfolded dial's
		-- most of all, and folded too once shrunk to its smallest): "(net 27s)" steps aside rather than
		-- the game cutting the line with "..." (the line under the verdict says the net)
		local fs = self.summonText
		local room = N(fs.wuberRoom)
		if net ~= "" and room and (N(T.MeasureText(fs.wuberText or "", fs.wuberPx or "caption", fs.wuberWeight)) or 0) > room then
			sum[#sum] = lead .. coins(fare)
			fs:SetText(table.concat(sum, " · "))
		end
		UI.FitOrWrap(fs) -- (r46, HUNT-39) "about 59 sec" is wider than "~59 sec": shrink first, then wrap
		local p, benefit = Mod.Score(info)
		self.benefit = benefit
		self.verdict:SetText(Mod.Verdict(info, benefit))
		self.line:SetText(S(info.line) or "")
		UI.FitOrWrap(self.line) -- (HUNT-139) shrink first, then wrap onto a second line (refit counts it in dial.extra)
		setShown(self.line, S(info.line) ~= nil)
		self.baseH = self.baseH or ((N(self:GetHeight()) or 88) - (self.extra or 0))
		refit(self)
		layoutDial(self) -- (r33) the side lines may have wrapped
		local was = self.p
		if not self:IsShown() then self:Show() end
		if was and was ~= p and T.FxLevel() ~= "off" and self:IsVisible() then
			T.Tween(self.knob, was, p, function(_, v) placeKnob(self, v) end)
			self.p = p -- the target (the tween moves the knob there)
		else
			-- (r47, AUD-214) a tween still easing toward the last driver's spot would drag the knob back
			T.Tween(self.knob, p, p, function(_, v) placeKnob(self, v) end)
		end
		self.target = p
	end
	layoutDial(dial)
	dial:Hide()
	return dial
end

---------------------------------------------------------------------------
-- The route header: "Brill  ->  Undercity" [zeppelin]
---------------------------------------------------------------------------

-- Where the rider stands, as the header's origin: the place (subzone) else the zone, else "Here".
function Mod.RouteFrom()
	if type(W.DestHere) == "function" then
		local _, p = call(W.DestHere)
		if type(p) == "table" and S(p.name) and p.kind ~= "zone" then return p.name end
	end
	local zone = type(W.ZoneHere) == "function" and S(call(W.ZoneHere)) or nil
	if zone and zone ~= "Unknown" then return zone end
	return "Here"
end

local live = setmetatable({}, { __mode = "k" }) -- headers that follow the rider

local PILL_H = 32 -- the route pill's height; it grows only when the origin needs more than two lines
local ORIGIN_LINE = 15 -- one line of the 12 px origin, in the pill
local VIA_ROW = 24 -- the tag's own row under the route, when the row cannot hold it (HUNT-132)
-- (prep-242 r3 b) from the window's right edge: 16 edge + the x and the cog (32 + 8 each) + the fold button (48 + 8) + 6 clear
local HEAD_REACH = 16 + 2 * (32 + 8) + 48 + 8 + 6

function Mod.RouteHeader(parent, w)
	local h = CreateFrame("Frame", nil, parent)
	h:SetSize(w or 324, 32)
	h.maxW = w or 324
	h.fill = T.PillFill(h, { 0.13, 0.11, 0.22, 0.94 }, 32, "BACKGROUND", 0)
	h.from = T.Text(h, "sub", "muted", "LEFT", "medium")
	h.from:SetPoint("LEFT", h, "LEFT", 14, 0)
	h.arrow = T.Icon(h, "back", 12, "glow", "ARTWORK")
	h.arrow:SetTexCoord(1, 0, 0, 1) -- mirrored: points right (no rotation)
	h.to = T.Text(h, "body", "white", "LEFT", "bold")
	h.via = T.Tag(h, "", { fill = "raised", text = "muted", h = 20, size = "caption", pad = 8 })
	h.via:Hide()
	h:EnableMouse(true)
	T.Tip(h, "Your trip", function()
		local route = (h.fromText or "Here") .. " to " .. (h.toText or "?") .. ". "
		if h.viaText then return route .. "Flying there takes a " .. h.viaText .. " on the way." end
		return route .. "From where you stand to where the driver summons you."
	end)
	function h.SetMaxWidth(self, mw) self.maxW = mw end
	function h.Set(self, from, to, via)
		from, to = S(from) or "Here", S(to) or "?"
		self.fromText, self.toText, self.viaText = from, to, S(via)
		-- (prep-242 r3 b) a header whose top lies in the window's header row (the Waiting-for-the-driver screen) stops short of
		-- the header's round buttons, so its via tag never lies in their place; the tag then takes its own row (below)
		local maxW = self.maxW
		local pw = N(self:GetParent() and self:GetParent():GetWidth())
		local pt, rel, _, px, py = self:GetPoint(1)
		if pw and pt == "TOPLEFT" and rel == self:GetParent() and N(px) and N(py) and -py < (N(UI.HEAD_ROW) or 44) then
			maxW = math.max(120, math.min(maxW, pw - px - HEAD_REACH))
		end
		local viaW = 0
		if self.viaText then
			self.via:SetTag(self.viaText)
			viaW = (N(self.via:GetWidth()) or 60) + 8
		end
		-- the origin always keeps room for its longest word (a word cannot wrap); the destination gives that back
		local longest, longestTo = 0, 0
		for word in from:gmatch("%S+") do longest = math.max(longest, T.MeasureText(word, "sub", "medium")) end
		for word in to:gmatch("%S+") do longestTo = math.max(longestTo, T.MeasureText(word, "caption", "bold")) end
		local toW, room
		local function share(tagW)
			-- the destination gives way to the tag: origin minimum, arrow and padding stay
			toW = math.min(T.MeasureText(to, "body", "bold"), maxW - 120, math.max(30, maxW - 96 - tagW))
			room = maxW - 14 - 14 - 12 - 16 - toW - tagW
			if room < longest + 2 and toW > 30 then
				local give = math.min(longest + 2 - room, toW - 30)
				toW, room = toW - give, room + give
			end
		end
		share(viaW)
		-- (2.4 fix round, HUNT-132) a narrow header (the finding screen's, 204) cannot hold "Undercity", the arrow, the
		-- destination and the tag on one row: a word of the origin or (at its smallest size) of the destination would
		-- be cut. The tag then takes a row of its own under the route and the pill grows by that row; nothing is cut.
		local drop = self.viaText ~= nil and (room < longest + 2 or toW + 2 < longestTo)
		if drop then share(0) end
		-- (2.4 fix round 3) a long origin wraps onto a second line, whole ("Stranglethorn Vale"), never "..."
		room = math.max(30, room)
		local shown = from
		local lines = 1
		if T.MeasureText(shown, "sub", "medium") > room then lines = T.ParaLines(shown, "sub", "medium", room) end
		self.from:SetWordWrap(lines > 1)
		if lines > 1 then
			self.from:SetWidth(room)
			self.from:SetHeight(math.max(lines * ORIGIN_LINE, wrapH(lines, "sub")))
		else
			self.from:SetWidth(math.max(30, math.min(room, T.MeasureText(shown, "sub", "medium") + 2)))
			self.from:SetHeight(PILL_H)
		end
		local rowH = math.max(PILL_H, math.max(lines * ORIGIN_LINE, wrapH(lines, "sub")) + 4)
		local pillH = rowH + (drop and VIA_ROW or 0)
		self.from:ClearAllPoints()
		self.from:SetPoint("LEFT", self, "TOPLEFT", 14, -rowH / 2) -- (the route's row is the pill's top part when the tag has its own row)
		if self:GetHeight() ~= pillH then
			self:SetHeight(pillH)
			self.fill:SetHeight(pillH)
		end
		self.from:SetText(shown)
		self.fromShown = shown
		self.viaBelow = drop
		self.arrow:ClearAllPoints()
		self.arrow:SetPoint("LEFT", self.from, "RIGHT", 6, 0)
		self.to:SetWidth(toW + 2)
		self.to:ClearAllPoints()
		self.to:SetPoint("LEFT", self.arrow, "RIGHT", 6, 0)
		self.to:SetText(to)
		UI.FitOrWrap(self.to) -- shrink first; a name still too long for what the tag leaves wraps
		local used = 14 + (N(self.from:GetWidth()) or 0) + 6 + 12 + 6 + toW + 2 + 14
		if drop then
			self.via:ClearAllPoints()
			self.via:SetPoint("TOPLEFT", self, "TOPLEFT", 14, -(rowH - 2))
			self.via:Show()
			used = math.max(used, 14 + viaW - 8 + 14)
		elseif self.viaText then
			self.via:ClearAllPoints()
			self.via:SetPoint("LEFT", self.to, "RIGHT", 6, 0)
			self.via:Show()
			used = used + viaW
		else
			self.via:Hide()
		end
		self:SetWidth(math.min(maxW, math.floor(used + 0.5)))
	end
	-- from where the rider stands to `dest`
	function h.Update(self, dest)
		self.dest = dest
		live[self] = true
		self:Set(Mod.RouteFrom(), dest, Mod.Via(dest))
	end
	return h
end

-- the rider moved: shown headers say where from now
local function refreshHeaders()
	for h in pairs(live) do
		if h.dest and h:IsVisible() then h:Update(h.dest) end
	end
end
W.On("ZONE_CHANGED", refreshHeaders)
W.On("ZONE_CHANGED_INDOORS", refreshHeaders)
