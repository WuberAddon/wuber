-- Wuber: the Drive tab, for Warlocks who drive with Wuber itself.
-- A big GO ONLINE / GO OFFLINE button, today's earnings, the price, the name riders see,
-- where a summon goes from here (refreshed every 5 s) and the team (1 or 3 Warlocks).
-- Requests slide in with a 30 s countdown ring: Accept (invite + A) or Decline (N); after
-- 30 s with no answer the request is declined as busy. Each accepted ride has stage
-- buttons: Portal up, Arrived, Paid. Settings are per character (W.Char()). While another
-- driver addon is set as the provider, the tab says so and lists the requests it handles.
--
-- W.Driver.Build(parent)   builds the tab into parent (W.UI.AddTab calls it)
-- W.Driver.Refresh()       redraws it
-- W.Driver.SetOnline(on)   go online or offline
-- W.Driver.Toggle()        a window of its own, used only when the Wuber window has no tabs

local _, W = ...

local D = {}
W.Driver = D

local MEDIA = "Interface\\AddOns\\" .. tostring(W.ADDON or "Wuber") .. "\\Media\\"
local FONT = "Fonts\\ARIALN.TTF"
local TTL = 30                 -- seconds to answer a request
local ETA = 3                  -- seconds until the invite, as told to the rider
local MAX_PRICE = 99999999
local CARD_GAP = 6
local DOTS = 30                -- the countdown ring: one dot a second

-- the author's logo colours (the same as W.Theme's)
local function hex(h)
	return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, 1 }
end
local VIOLET = hex("883FDA")
local MAGENTA = hex("E467FC")
local GOLD = hex("F9C53E")

local P = {
	text = hex("F2EEFF"),
	muted = hex("9A93B8"),
	faint = hex("333154"),      -- lines, unlit countdown dots
	card = hex("1D1B31"),
	field = hex("161628"),
	primary = GOLD,             -- the main button
	onPrimary = hex("0B0B16"),
	secondary = hex("333154"),
	onSecondary = hex("F2EEFF"),
	disc = hex("161628"),
	online = hex("CD7DF5"),     -- open: violet, never green
	warn = hex("F9A23E"),       -- busy, the last 10 s
	price = GOLD,
	window = hex("0B0B16"),
}

D.rides = {}        -- accepted rides: { id, buyer, buyerKey, dest, price, stage, at, ended, endAt }
D.earned = 0        -- copper marked paid this session
D.paidCount = 0

local answered = {} -- rideId -> true once accepted, declined or expired here
local firstSeen = {}-- rideId -> when this client first listed it
local destNow       -- where a summon from here goes
local ui            -- the built tab
local Refresh       -- forward

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function Now() return W.Now() end

local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end

local function Show(f, on)
	if on then f:Show() else f:Hide() end
end

local function Toast(text, kind)
	if W.UI and type(W.UI.Toast) == "function" then W.Safe("toast", W.UI.Toast, text, kind) end
end

local function IsWarlock()
	if type(W.IsWarlock) == "function" then
		local ok, yes = pcall(W.IsWarlock)
		return ok and yes == true
	end
	if type(UnitClass) ~= "function" then return false end
	local ok, _, class = pcall(UnitClass, "player")
	return ok and W.Str(class) == "WARLOCK"
end

local function Provider()
	local p = W.provider
	if p == nil or p == false then return nil end
	if type(p) == "table" then return W.Str(p.name) or "another addon" end
	return "another addon"
end

-- this character's settings, once we know who we are
local function Char()
	if not W.myKey or type(W.Char) ~= "function" then return nil end
	local ok, c = pcall(W.Char)
	if ok and type(c) == "table" then return c end
	return nil
end

local function Online()
	local c = Char()
	return c ~= nil and c.drive == true and not Provider() and IsWarlock()
end

local function Price()
	local c = Char()
	local p = c and W.Num(c.price)
	local floor = W.MIN_PRICE or 5000
	if not p or p < floor then return floor end
	return math.min(math.floor(p + 0.5), MAX_PRICE)
end

local function Team()
	local c = Char()
	local t = c and W.Num(c.team)
	if t == 3 then return 3 end
	if t == 2 then return 2 end
	return 1
end

local function CleanService(text)
	text = W.Clean(text or "", 32):gsub("[^%w%s'%-]", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	return text
end

local function Service()
	local c = Char()
	local s = c and CleanService(c.service) or ""
	if s ~= "" then return s end
	return W.Me()
end

local function DestName()
	if type(W.DestHere) ~= "function" then return nil end
	local ok, name, place = pcall(W.DestHere)
	if not ok then return nil end
	if type(name) == "table" then return W.Str(name.name) end
	return W.Str(name) or (type(place) == "table" and W.Str(place.name)) or nil
end

local function Position()
	if type(W.MyPosition) == "function" then
		local ok, m, x, y = pcall(W.MyPosition)
		if ok then return W.Num(m), W.Num(x), W.Num(y) end
		return nil
	end
	if not (C_Map and type(C_Map.GetBestMapForUnit) == "function") then return nil end
	local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
	m = ok and W.Num(m)
	if not m or type(C_Map.GetPlayerMapPosition) ~= "function" then return m end
	local ok2, pos = pcall(C_Map.GetPlayerMapPosition, m, "player")
	pos = ok2 and W.Plain(pos)
	if type(pos) ~= "table" or type(pos.GetXY) ~= "function" then return m end
	local ok3, x, y = pcall(pos.GetXY, pos)
	if not ok3 then return m end
	return m, W.Num(x), W.Num(y)
end

local function GroupSize()
	local n = 0
	if type(GetNumGroupMembers) == "function" then
		local ok, v = pcall(GetNumGroupMembers)
		n = ok and W.Num(v) or 0
	end
	local raid = false
	if type(IsInRaid) == "function" then
		local ok, v = pcall(IsInRaid)
		raid = ok and W.Plain(v) and true or false
	end
	return math.max(1, n), raid and 40 or 5
end

local function FreeSeats()
	local n, max = GroupSize()
	return math.max(0, math.min(39, max - n))
end

local function InGroupWith(key)
	if not key then return false end
	if type(W.InGroupWith) == "function" then
		local ok, yes = pcall(W.InGroupWith, key)
		return ok and yes == true
	end
	for i = 1, 4 do
		if W.Key(W.UnitName("party" .. i)) == key then return true end
	end
	return false
end

local function Invite(name)
	if type(W.Invite) == "function" then
		local ok, done = pcall(W.Invite, name)
		return ok and done and true or false
	end
	name = W.Str(name)
	if not name then return false end
	if type(C_PartyInfo) == "table" and type(C_PartyInfo.InviteUnit) == "function" then
		if pcall(C_PartyInfo.InviteUnit, name) then return true end
	end
	if type(InviteUnit) == "function" then return (pcall(InviteUnit, name)) end
	return false
end

local function Announce()
	if Provider() then return end
	if type(W.SendBeacon) == "function" then W.Safe("beacon", W.SendBeacon) end
end

---------------------------------------------------------------------------
-- Requests and rides
---------------------------------------------------------------------------

local function Incoming()
	return type(W.incoming) == "table" and W.incoming or {}
end

local function FindIncoming(id)
	for _, r in pairs(Incoming()) do
		if type(r) == "table" and r.id == id then return r end
	end
	return nil
end

-- requests nobody has answered yet, oldest first
local function Pending()
	local out = {}
	for _, r in pairs(Incoming()) do
		if type(r) == "table" and r.id and not answered[r.id] and (r.state == nil or r.state == "new") then
			out[#out + 1] = r
		end
	end
	table.sort(out, function(a, b)
		local ta, tb = firstSeen[a.id] or 0, firstSeen[b.id] or 0
		if ta ~= tb then return ta < tb end
		return tostring(a.id) < tostring(b.id)
	end)
	return out
end

local function Remaining(r)
	local t = Now()
	local at = W.Num(r.at)
	if not at or at > t + 5 or t - at > 3600 then at = firstSeen[r.id] or t end
	return TTL - (t - at)
end

local function ActiveRides()
	local n = 0
	for _, ride in ipairs(D.rides) do
		if not ride.ended and ride.stage ~= "paid" then n = n + 1 end
	end
	return n
end

local function FindRide(id)
	for i, ride in ipairs(D.rides) do
		if ride.id == id then return ride, i end
	end
	return nil
end

local function RemoveRide(id)
	local _, i = FindRide(id)
	if i then table.remove(D.rides, i) end
end

function D.Decline(id, reason)
	if not id or answered[id] then return false end
	answered[id] = true
	local r = FindIncoming(id)
	if type(W.DeclineRequest) == "function" then
		W.Safe("decline", W.DeclineRequest, id, reason or "busy", r and W.Str(r.buyer) or nil)
	end
	if Refresh then Refresh() end
	return true
end

function D.Accept(id)
	if not id or answered[id] or Provider() then return false end
	local r = FindIncoming(id)
	if not r then return false end
	local sent = false
	if type(W.AcceptRequest) == "function" then
		local ok, res = W.Safe("accept", W.AcceptRequest, id, ETA, W.Str(r.buyer))
		sent = ok and res ~= false
	end
	local who = W.Short(W.Str(r.buyer) or "?")
	if not sent then
		Toast("Couldn't reach " .. who .. ". Try again.", "error")
		return false
	end
	answered[id] = true
	D.rides[#D.rides + 1] = {
		id = id, buyer = W.Str(r.buyer), buyerKey = r.buyerKey, dest = W.Str(r.dest) or destNow or "?",
		price = W.Num(r.price) or Price(), stage = "accepted", at = Now(),
	}
	if not Invite(r.buyer) then Toast("Invite " .. who .. " to your group yourself.", "info") end
	W.Sound("click")
	Announce()
	if Refresh then Refresh() end
	return true
end

-- the stage buttons, in order (a ride only moves forward)
local STAGES = { "portal", "arrived", "paid" }
local STAGE_RANK = { accepted = 0, portal = 1, arrived = 2, paid = 3 }
local STAGE_LABEL = { portal = "Portal up", arrived = "Arrived", paid = "Paid" }

function D.Stage(id, stage)
	local ride = FindRide(id)
	if not ride or ride.ended or not STAGE_RANK[stage] then return false end
	if STAGE_RANK[stage] <= (STAGE_RANK[ride.stage] or 0) then return false end
	-- set first: Net drops a paid ride from W.incoming (and fires REQUESTS) while sending
	local before = ride.stage
	ride.stage = stage
	local sent = false
	if type(W.SendStage) == "function" then
		local ok, res = W.Safe("stage", W.SendStage, id, stage, ride.buyer)
		sent = ok and res ~= false
	end
	if not sent then
		ride.stage = before
		Toast("Couldn't tell " .. W.Short(ride.buyer) .. ". Try again.", "error")
		if Refresh then Refresh() end
		return false
	end
	if stage == "paid" then
		D.earned = D.earned + (ride.price or 0)
		D.paidCount = D.paidCount + 1
		ride.endAt = Now()
		W.Sound("found")
		Announce()
	end
	if Refresh then Refresh() end
	return true
end

function D.Drop(id)
	RemoveRide(id)
	Announce()
	if Refresh then Refresh() end
end

-- rides Net no longer lists ended on the rider's side (cancelled, or gone for good)
local function Reconcile()
	local t, changed = Now(), false
	for i = #D.rides, 1, -1 do
		local ride = D.rides[i]
		if not ride.ended and ride.stage ~= "paid" and not FindIncoming(ride.id) then
			ride.ended, ride.endAt, changed = true, t, true
			Toast(W.Short(ride.buyer) .. " cancelled the ride", "info")
		end
		if ride.endAt and t - ride.endAt >= (ride.ended and 6 or 2.5) then
			table.remove(D.rides, i)
			changed = true
		end
	end
	if changed then Announce() end
	return changed
end

-- once a second: unanswered requests time out (busy); while offline they are closed
local function Expire()
	if Provider() then return end
	local online, changed = Online(), false
	for _, r in ipairs(Pending()) do
		if not firstSeen[r.id] then firstSeen[r.id] = Now() end
		if not online then
			changed = D.Decline(r.id, "closed") or changed
		elseif Remaining(r) <= 0 then
			changed = D.Decline(r.id, "busy") or changed
		end
	end
	if Reconcile() then changed = true end
	if changed and Refresh then Refresh() end
end

local function OnRequests()
	local t = Now()
	local fresh = {}
	for _, r in ipairs(Pending()) do
		if not firstSeen[r.id] then
			firstSeen[r.id] = t
			fresh[#fresh + 1] = r
		end
	end
	if #fresh > 0 and Online() then
		local r = fresh[#fresh]
		W.Sound("ping")
		Toast(W.Short(W.Str(r.buyer) or "?") .. " wants a summon to " .. (W.Str(r.dest) or "?") .. " for "
			.. W.Money(W.Num(r.price) or 0), "request")
	end
	Reconcile()
	if Refresh then Refresh() end
end

-- what this client beacons as a driver (Net asks; nil while offline)
local function Beacon()
	if not Online() then return nil end
	local mapID, x, y = Position()
	local state = "open"
	if ActiveRides() > 0 then state = "busy" end
	if not (mapID and x and y) then state = "paused" end -- inside an instance: can't summon
	destNow = DestName() or destNow
	return {
		dest = destNow or "Unknown",
		mapID = mapID, x = x, y = y,
		price = Price(),
		service = Service(),
		state = state,
		team = Team(),
		seats = FreeSeats(),
	}
end

function D.SetOnline(on)
	on = on and true or false
	local c = Char()
	if not c then return false end
	if on and (Provider() or not IsWarlock()) then return false end
	if (c.drive == true) == on then return true end
	c.drive = on
	if type(W.SetDriving) == "function" then
		W.Safe("drive", W.SetDriving, on) -- fires SETTINGS and beacons (X when going off)
	else
		W.Fire("SETTINGS", "drive")
		Announce()
	end
	if not on then
		for _, r in ipairs(Pending()) do D.Decline(r.id, "closed") end
	end
	W.Sound(on and "open" or "close")
	if ui and ui.go then ui.go.pressed = true end
	if Refresh then Refresh() end
	return true
end

local function Changed()
	W.Fire("SETTINGS", "driver")
	if Online() then Announce() end
end

---------------------------------------------------------------------------
-- Drawing kit (dark Wuber look; W.Theme's colours when it has them)
---------------------------------------------------------------------------

-- the Wuber font (W.Theme's, at a weight that fits the size), else Arial Narrow
local function SetFont(fs, size)
	local T = W.Theme
	if type(T) == "table" and type(T.SetFont) == "function" then
		local weight = size >= 17 and "bold" or (size >= 13 and "medium" or "regular")
		if pcall(T.SetFont, fs, size, weight) then return end
	end
	local ok, set = pcall(fs.SetFont, fs, FONT, size, "")
	if (not ok or set == false) and GameFontNormal then pcall(fs.SetFontObject, fs, GameFontNormal) end
end

local function Font(parent, size, colour, justify, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	SetFont(fs, size)
	fs:SetTextColor(rgba(colour or P.text))
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

local function Tex(parent, layer, file, size, colour)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(MEDIA .. file)
	if size then t:SetSize(size, size) end
	if colour then t:SetVertexColor(rgba(colour)) end
	return t
end

-- violet to magenta (or to `to`) across a texture; plain violet if gradients fail
local function Accent(t, alpha, to)
	alpha = alpha or 1
	to = to or MAGENTA
	local done = false
	if type(CreateColor) == "function" then
		done = pcall(t.SetGradient, t, "HORIZONTAL", CreateColor(VIOLET[1], VIOLET[2], VIOLET[3], alpha),
			CreateColor(to[1], to[2], to[3], alpha))
	end
	if not done and t.SetGradientAlpha then
		done = pcall(t.SetGradientAlpha, t, "HORIZONTAL", VIOLET[1], VIOLET[2], VIOLET[3], alpha,
			to[1], to[2], to[3], alpha)
	end
	if not done then t:SetVertexColor(VIOLET[1], VIOLET[2], VIOLET[3], alpha) end
end

-- a rounded rectangle from the 9-slice "rounded" texture (corners are its quarters)
local function Rounded(f, r, colour, layer)
	local parts = {}
	local function piece(l, rr, t, b)
		local x = f:CreateTexture(nil, layer or "BACKGROUND")
		x:SetTexture(MEDIA .. "rounded")
		x:SetTexCoord(l, rr, t, b)
		parts[#parts + 1] = x
		return x
	end
	local tl = piece(0, 0.25, 0, 0.25)
	tl:SetSize(r, r)
	tl:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	local tr = piece(0.75, 1, 0, 0.25)
	tr:SetSize(r, r)
	tr:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	local bl = piece(0, 0.25, 0.75, 1)
	bl:SetSize(r, r)
	bl:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	local br = piece(0.75, 1, 0.75, 1)
	br:SetSize(r, r)
	br:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	local top = piece(0.25, 0.75, 0, 0.25)
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
	top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT", 0, 0)
	local bottom = piece(0.25, 0.75, 0.75, 1)
	bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
	local left = piece(0, 0.25, 0.25, 0.75)
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT", 0, 0)
	local right = piece(0.75, 1, 0.25, 0.75)
	right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
	local mid = piece(0.25, 0.75, 0.25, 0.75)
	mid:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT", 0, 0)
	mid:SetPoint("BOTTOMRIGHT", br, "TOPLEFT", 0, 0)
	local shape = {}
	function shape.Colour(c)
		for i = 1, #parts do parts[i]:SetVertexColor(rgba(c)) end
	end
	shape.Colour(colour or P.card)
	return shape
end

-- a pill from the 3-slice "pill" texture (caps are its outer quarters)
local function PillShape(f, h, colour, layer)
	local parts = {}
	local function piece(l, r)
		local x = f:CreateTexture(nil, layer or "BACKGROUND")
		x:SetTexture(MEDIA .. "pill")
		x:SetTexCoord(l, r, 0, 1)
		parts[#parts + 1] = x
		return x
	end
	local left = piece(0, 0.25)
	left:SetSize(h / 2, h)
	left:SetPoint("LEFT", f, "LEFT", 0, 0)
	local right = piece(0.75, 1)
	right:SetSize(h / 2, h)
	right:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	local mid = piece(0.25, 0.75)
	mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
	mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
	local shape = {}
	function shape.Colour(c)
		for i = 1, #parts do parts[i]:SetVertexColor(rgba(c)) end
	end
	shape.Colour(colour or P.primary)
	return shape
end

local STYLES = {
	primary = { "primary", "onPrimary" },
	secondary = { "secondary", "onSecondary" },
	done = { "field", "muted" },
}

-- a pill button: b.Label(text), b.Style("primary" | "secondary" | "done"), b.onClick
local function Button(parent, w, h, label, style, size)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b:RegisterForClicks("LeftButtonUp")
	local shape = PillShape(b, h, P.primary, "BACKGROUND")
	local text = Font(b, size or (h >= 30 and 15 or 12), P.onPrimary, "CENTER")
	text:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.text = text
	function b.Label(t) text:SetText(t) end
	function b.Style(s)
		local st = STYLES[s] or STYLES.primary
		b.style = s
		shape.Colour(P[st[1]])
		text:SetTextColor(rgba(P[st[2]]))
	end
	b.Label(label or "")
	b.Style(style or "primary")
	b:SetScript("OnEnter", function(self) self:SetAlpha(0.85) end)
	b:SetScript("OnLeave", function(self) self:SetAlpha(1) end)
	b:SetScript("OnClick", function(self)
		W.Safe("drive button", function()
			if self.onClick then self.onClick(self) end
		end)
	end)
	return b
end

local function ScaleTo(a, from, to)
	local f = a.SetScaleFrom or a.SetFromScale
	local t = a.SetScaleTo or a.SetToScale
	if f then f(a, from, from) end
	if t then t(a, to, to) end
end

-- grows from small to rest (an animation that ends where the frame really is)
local function PopAnim(frame)
	local ag = frame:CreateAnimationGroup()
	local s = ag:CreateAnimation("Scale")
	ScaleTo(s, 0.88, 1)
	s:SetDuration(0.28)
	s:SetSmoothing("OUT")
	return ag
end

-- slides in from the right and fades in, ending at rest
local function SlideAnim(frame)
	local ag = frame:CreateAnimationGroup()
	local jump = ag:CreateAnimation("Translation")
	jump:SetOffset(40, 0)
	jump:SetDuration(0)
	jump:SetOrder(1)
	local hide = ag:CreateAnimation("Alpha")
	hide:SetFromAlpha(0)
	hide:SetToAlpha(0)
	hide:SetDuration(0)
	hide:SetOrder(1)
	local back = ag:CreateAnimation("Translation")
	back:SetOffset(-40, 0)
	back:SetDuration(0.3)
	back:SetSmoothing("OUT")
	back:SetOrder(2)
	local show = ag:CreateAnimation("Alpha")
	show:SetFromAlpha(0)
	show:SetToAlpha(1)
	show:SetDuration(0.3)
	show:SetOrder(2)
	return ag
end

-- a ring that grows and fades for ever
local function PulseAnim(frame, to, duration)
	local ag = frame:CreateAnimationGroup()
	ag:SetLooping("REPEAT")
	local s = ag:CreateAnimation("Scale")
	ScaleTo(s, 1, to)
	s:SetDuration(duration)
	s:SetSmoothing("OUT")
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(0.8)
	a:SetToAlpha(0)
	a:SetDuration(duration)
	a:SetSmoothing("OUT")
	return ag
end

-- breathes between two alphas for ever
local function BreatheAnim(frame, low, high, half)
	local ag = frame:CreateAnimationGroup()
	ag:SetLooping("REPEAT")
	local up = ag:CreateAnimation("Alpha")
	up:SetFromAlpha(low)
	up:SetToAlpha(high)
	up:SetDuration(half)
	up:SetOrder(1)
	local down = ag:CreateAnimation("Alpha")
	down:SetFromAlpha(high)
	down:SetToAlpha(low)
	down:SetDuration(half)
	down:SetOrder(2)
	return ag
end

local function Play(frame, ag)
	frame:Show()
	if frame.playing ~= ag then
		frame.playing = ag
		ag:Play()
	end
end

local function Stop(frame, ag)
	if frame.playing == ag then
		frame.playing = nil
		ag:Stop()
	end
	frame:Hide()
end

local function Level(frame)
	local ok, l = pcall(frame.GetFrameLevel, frame)
	return ok and W.Num(l) or 1
end

---------------------------------------------------------------------------
-- The tab: the parts
---------------------------------------------------------------------------

local function GoButton(parent)
	local go = CreateFrame("Button", nil, parent)
	go:SetSize(104, 104)
	go:RegisterForClicks("LeftButtonUp")

	local glow = CreateFrame("Frame", nil, go)
	glow:SetSize(104, 104)
	glow:SetPoint("CENTER", go, "CENTER", 0, 0)
	local gt = Tex(glow, "BACKGROUND", "glow", 168)
	gt:SetPoint("CENTER", glow, "CENTER", 0, 0)
	Accent(gt, 1)
	glow.anim = BreatheAnim(glow, 0.35, 0.85, 1.2)
	glow:Hide()

	local pulses = {}
	for i = 1, 2 do
		local p = CreateFrame("Frame", nil, go)
		p:SetSize(104, 104)
		p:SetPoint("CENTER", go, "CENTER", 0, 0)
		local t = Tex(p, "ARTWORK", "ring")
		t:SetAllPoints(p)
		Accent(t, 1)
		p.anim = PulseAnim(p, 1.45, 2)
		p:Hide()
		pulses[i] = p
	end

	local ring = CreateFrame("Frame", nil, go)
	ring:SetSize(116, 116)
	ring:SetPoint("CENTER", go, "CENTER", 0, 0)
	local rt = Tex(ring, "ARTWORK", "ring")
	rt:SetAllPoints(ring)
	Accent(rt, 1, GOLD) -- online: violet to gold
	ring:Hide()

	local disc = CreateFrame("Frame", nil, go)
	disc:SetSize(104, 104)
	disc:SetPoint("CENTER", go, "CENTER", 0, 0)
	local shadow = Tex(disc, "BACKGROUND", "glow", 132, { 0, 0, 0, 0.7 })
	shadow:SetPoint("CENTER", disc, "CENTER", 0, -3)
	local face = Tex(disc, "ARTWORK", "circle")
	face:SetAllPoints(disc)
	local big = Font(disc, 30, P.onPrimary, "CENTER")
	big:SetPoint("CENTER", disc, "CENTER", 0, 7)
	big:SetText("GO")
	local small = Font(disc, 12, P.onPrimary, "CENTER")
	small:SetPoint("TOP", big, "BOTTOM", 0, -2)
	disc.pop = PopAnim(disc)

	go.glow, go.pulses, go.ring, go.disc, go.face, go.big, go.small = glow, pulses, ring, disc, face, big, small

	-- the parts stack: glow, pulses, ring, then the disc on top
	function go.Stack()
		local l = Level(go)
		glow:SetFrameLevel(l + 1)
		pulses[1]:SetFrameLevel(l + 2)
		pulses[2]:SetFrameLevel(l + 2)
		ring:SetFrameLevel(l + 3)
		disc:SetFrameLevel(l + 4)
	end

	function go.Paint(online, enabled)
		if online then
			face:SetVertexColor(rgba(P.disc))
			big:SetTextColor(rgba(P.text))
			small:SetTextColor(rgba(P.text))
			small:SetText("OFFLINE")
			ring:Show()
			Play(glow, glow.anim)
			if not pulses[1].playing then
				Play(pulses[1], pulses[1].anim)
				pulses[2].due = Now() + 1 -- the second ring a beat behind
			end
		else
			face:SetVertexColor(rgba(enabled and P.primary or P.faint))
			big:SetTextColor(rgba(P.onPrimary))
			small:SetTextColor(rgba(P.onPrimary))
			small:SetText("ONLINE")
			ring:Hide()
			Stop(glow, glow.anim)
			Stop(pulses[1], pulses[1].anim)
			Stop(pulses[2], pulses[2].anim)
			pulses[2].due = nil
		end
		if go.pressed then
			go.pressed = nil
			disc.pop:Stop()
			disc.pop:Play()
		end
	end

	-- starts the second pulse ring once its beat comes (called from the tab's OnUpdate)
	function go.Beat()
		local p = pulses[2]
		if p.due and Now() >= p.due then
			p.due = nil
			Play(p, p.anim)
		end
	end

	go:SetScript("OnEnter", function() disc:SetAlpha(0.92) end)
	go:SetScript("OnLeave", function() disc:SetAlpha(1) end)
	go:SetScript("OnClick", function()
		W.Safe("go online", function()
			local c = Char()
			if not c then return end
			D.SetOnline(not (c.drive == true))
		end)
	end)
	return go
end

-- a request card: countdown ring, who, where to, price, Accept / Decline
local function RequestCard(parent)
	local card = CreateFrame("Frame", nil, parent)
	card:SetHeight(66)
	card.bg = Rounded(card, 14, P.card)

	local ring = CreateFrame("Frame", nil, card)
	ring:SetSize(40, 40)
	ring:SetPoint("LEFT", card, "LEFT", 12, 0)
	ring.dots = {}
	for i = 1, DOTS do
		local a = math.rad(90 - (i - 1) * (360 / DOTS))
		local dot = Tex(ring, "ARTWORK", "circle", 4)
		dot:SetPoint("CENTER", ring, "CENTER", 17 * math.cos(a), 17 * math.sin(a))
		ring.dots[i] = dot
	end
	ring.num = Font(ring, 13, P.text, "CENTER")
	ring.num:SetPoint("CENTER", ring, "CENTER", 0, 0)
	card.ring = ring

	card.name = Font(card, 15, P.text)
	card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 64, -15)
	card.name:SetPoint("RIGHT", card, "RIGHT", -160, 0)
	card.price = Font(card, 15, P.price, "RIGHT")
	card.price:SetPoint("TOPRIGHT", card, "TOPRIGHT", -98, -15)
	card.info = Font(card, 12, P.muted)
	card.info:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
	card.info:SetPoint("RIGHT", card, "RIGHT", -100, 0)

	card.accept = Button(card, 78, 24, "Accept", "primary")
	card.accept:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -8)
	card.accept.onClick = function() D.Accept(card.id) end
	card.decline = Button(card, 78, 24, "Decline", "secondary")
	card.decline:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 8)
	card.decline.onClick = function() D.Decline(card.id, "busy") end

	card.status = Font(card, 12, P.muted, "RIGHT")
	card.status:SetPoint("RIGHT", card, "RIGHT", -14, 0)

	card.slide = SlideAnim(card)
	card:Hide()
	return card
end

local function PaintCountdown(card, r)
	local left = math.max(0, Remaining(r))
	local lit = math.ceil(left)
	local hot = left <= 10
	for i = 1, DOTS do
		local dot = card.ring.dots[i]
		if i <= lit then
			if hot then dot:SetVertexColor(rgba(P.warn)) else dot:SetVertexColor(VIOLET[1], VIOLET[2], VIOLET[3], 1) end
		else
			dot:SetVertexColor(rgba(P.faint))
		end
	end
	card.ring.num:SetText(tostring(lit))
end

-- an accepted ride: who, where, status, Portal up / Arrived / Paid
local function RideCard(parent)
	local card = CreateFrame("Frame", nil, parent)
	card:SetHeight(72)
	card.bg = Rounded(card, 14, P.card)
	card.title = Font(card, 14, P.text)
	card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
	card.title:SetPoint("RIGHT", card, "RIGHT", -32, 0)
	card.status = Font(card, 11, P.muted)
	card.status:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
	card.status:SetPoint("RIGHT", card, "RIGHT", -12, 0)
	card.close = CreateFrame("Button", nil, card)
	card.close:SetSize(20, 20)
	card.close:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -6)
	card.close:RegisterForClicks("LeftButtonUp")
	local x = Tex(card.close, "ARTWORK", "close", 12, P.muted)
	x:SetPoint("CENTER", card.close, "CENTER", 0, 0)
	card.close:SetScript("OnClick", function()
		W.Safe("drop ride", function() if card.id then D.Drop(card.id) end end)
	end)
	card.steps = {}
	for i, stage in ipairs(STAGES) do
		local b = Button(card, 90, 22, STAGE_LABEL[stage], "secondary", 11)
		b.stage = stage
		b.onClick = function() if card.id then D.Stage(card.id, stage) end end
		card.steps[i] = b
	end
	card.slide = SlideAnim(card)
	card:Hide()
	return card
end

local function LayoutSteps(card)
	local ok, w = pcall(card.GetWidth, card)
	w = ok and W.Num(w) or 0
	local bw = 90
	if w > 120 then bw = math.floor((w - 24 - 12) / 3) end
	for i, b in ipairs(card.steps) do
		b:SetWidth(bw)
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 12 + (i - 1) * (bw + 6), 8)
	end
end

local function RideStatus(ride)
	if ride.ended then return "Ride cancelled", P.warn end
	local price = W.Money(ride.price or 0)
	if ride.stage == "paid" then return "Paid " .. price .. ". Nice one!", P.online end
	if ride.stage == "arrived" then return "Arrived. Collect " .. price .. " by trade.", P.muted end
	if ride.stage == "portal" then return "Portal up. Waiting for them to accept.", P.muted end
	if InGroupWith(ride.buyerKey) then return "In your group. Start the ritual.", P.online end
	return "Invite sent. Waiting for them to join.", P.muted
end

local function PaintRide(card, ride)
	card.title:SetText(W.Short(ride.buyer or "?") .. "  ·  " .. tostring(ride.dest or "?") .. "  ·  |cfff9c53e"
		.. W.Money(ride.price or 0) .. "|r")
	local text, colour = RideStatus(ride)
	card.status:SetText(text)
	card.status:SetTextColor(rgba(colour))
	local rank = STAGE_RANK[ride.stage] or 0
	local nextShown = false
	for _, b in ipairs(card.steps) do
		Show(b, not ride.ended)
		local r = STAGE_RANK[b.stage]
		if r <= rank then
			b.Style("done")
			b:EnableMouse(false)
		elseif not nextShown then
			nextShown = true
			b.Style("primary")
			b:EnableMouse(true)
		else
			b.Style("secondary")
			b:EnableMouse(true)
		end
	end
	card.close:EnableMouse(true)
	LayoutSteps(card)
end

---------------------------------------------------------------------------
-- The tab: building and drawing
---------------------------------------------------------------------------

local function Header(parent, text)
	local fs = Font(parent, 14, P.text)
	fs:SetText(text)
	return fs
end

local function Acquire(pool, maker, parent, i)
	local card = pool[i]
	if not card then
		card = maker(parent)
		pool[i] = card
	end
	return card
end

-- shows `card` for item id; slides in when it shows something new
local function Assign(card, id)
	local fresh = card.id ~= id or not card:IsShown()
	card.id = id
	card:Show()
	if fresh then
		card.slide:Stop()
		card.slide:Play()
	end
end

local function Capacity(view, top)
	local ok, h = pcall(view.GetHeight, view)
	h = ok and W.Num(h) or 0
	if h <= top + 40 then return 3 end
	return math.max(1, math.floor((h - top - 8 + CARD_GAP) / (66 + CARD_GAP)))
end

local function BuildLocked(root)
	local v = CreateFrame("Frame", nil, root)
	v:SetAllPoints(root)
	local disc = Tex(v, "ARTWORK", "circle", 72, P.card)
	disc:SetPoint("TOP", v, "TOP", 0, -90)
	local glyph = Tex(v, "OVERLAY", "summon", 40)
	glyph:SetPoint("CENTER", disc, "CENTER", 0, 0)
	Accent(glyph, 1)
	local title = Font(v, 20, P.text, "CENTER")
	title:SetPoint("TOP", disc, "BOTTOM", 0, -18)
	title:SetText("Only Warlocks can drive")
	local sub = Font(v, 13, P.muted, "CENTER")
	sub:SetPoint("TOP", title, "BOTTOM", 0, -8)
	sub:SetText("Log in on a Warlock to take summons.")
	v:Hide()
	return v
end

local function BuildRR(root)
	local v = CreateFrame("Frame", nil, root)
	v:SetAllPoints(root)
	local glyph = Tex(v, "ARTWORK", "summon", 28)
	glyph:SetPoint("TOPLEFT", v, "TOPLEFT", 14, -14)
	Accent(glyph, 1)
	v.title = Font(v, 20, P.text)
	v.title:SetPoint("LEFT", glyph, "RIGHT", 10, 0)
	v.sub = Font(v, 12, P.muted)
	v.sub:SetPoint("TOPLEFT", v, "TOPLEFT", 14, -52)
	v.sub:SetPoint("RIGHT", v, "RIGHT", -14, 0)
	v.sub:SetWordWrap(true)
	local head = Header(v, "Requests")
	head:SetPoint("TOPLEFT", v, "TOPLEFT", 14, -96)
	v.empty = Font(v, 13, P.muted, "CENTER")
	v.empty:SetPoint("TOP", v, "TOP", 0, -140)
	v.empty:SetText("No Wuber requests yet")
	v.cards = {}
	v.top = 120
	v:Hide()
	return v
end

local function Row(card, y, label)
	local fs = Font(card, 13, P.muted)
	fs:SetPoint("LEFT", card, "TOPLEFT", 14, -y)
	fs:SetText(label)
	return fs
end

-- an edit box on a field pill: commit(text) returns the text to show (or nil to revert)
local function Field(parent, w, h, justify, maxLetters, commit, shown)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(w, h)
	PillShape(holder, h, P.field, "BACKGROUND")
	local eb = CreateFrame("EditBox", nil, holder)
	eb:SetPoint("TOPLEFT", holder, "TOPLEFT", h / 2, 0)
	eb:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -h / 2, 0)
	eb:SetAutoFocus(false)
	SetFont(eb, 13)
	eb:SetTextColor(rgba(P.text))
	eb:SetJustifyH(justify or "RIGHT")
	eb:SetMaxLetters(maxLetters or 24)
	local hint = Font(holder, 13, P.faint, justify or "RIGHT")
	hint:SetPoint("TOPLEFT", eb, "TOPLEFT", 0, 0)
	hint:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 0, 0)
	holder.edit, holder.hint = eb, hint

	local function current()
		local text, placeholder = shown()
		return text or "", placeholder
	end
	function holder.Sync()
		if eb.focused then return end
		local text, placeholder = current()
		eb:SetText(text)
		hint:SetText(placeholder or "")
		Show(hint, text == "" and placeholder ~= nil)
	end
	local function done(self, keep)
		if keep then
			local text = self:GetText() or ""
			if text ~= (current()) then commit(text) end
		end
		self.focused = nil
		holder.Sync()
	end
	eb:SetScript("OnEditFocusGained", function(self)
		W.Safe("field", function()
			self.focused = true
			hint:Hide()
			pcall(self.HighlightText, self)
		end)
	end)
	eb:SetScript("OnEditFocusLost", function(self) W.Safe("field", done, self, true) end)
	eb:SetScript("OnEnterPressed", function(self) W.Safe("field", function() self:ClearFocus() end) end)
	eb:SetScript("OnEscapePressed", function(self)
		W.Safe("field", function()
			self:SetText((current()))
			self:ClearFocus()
		end)
	end)
	return holder
end

local function BuildDrive(root)
	local v = CreateFrame("Frame", nil, root)
	v:SetAllPoints(root)

	-- status (left) and today's earnings (right)
	v.dot = Tex(v, "ARTWORK", "circle", 9, P.faint)
	v.dot:SetPoint("TOPLEFT", v, "TOPLEFT", 14, -19)
	v.status = Font(v, 20, P.text)
	v.status:SetPoint("LEFT", v.dot, "RIGHT", 8, 0)
	v.sub = Font(v, 12, P.muted)
	v.sub:SetPoint("TOPLEFT", v, "TOPLEFT", 14, -36)
	local today = Font(v, 11, P.muted, "RIGHT")
	today:SetPoint("TOPRIGHT", v, "TOPRIGHT", -14, -10)
	today:SetText("Today")
	v.earned = Font(v, 20, P.price, "RIGHT")
	v.earned:SetPoint("TOPRIGHT", today, "BOTTOMRIGHT", 0, -2)
	v.rides = Font(v, 11, P.muted, "RIGHT")
	v.rides:SetPoint("TOPRIGHT", v.earned, "BOTTOMRIGHT", 0, -2)

	v.go = GoButton(v)
	v.go:SetPoint("TOP", v, "TOP", 0, -62)

	-- settings
	local card = CreateFrame("Frame", nil, v)
	card:SetPoint("TOPLEFT", v, "TOPLEFT", 12, -184)
	card:SetPoint("RIGHT", v, "RIGHT", -12, 0)
	card:SetHeight(124)
	Rounded(card, 14, P.card)
	v.card = card

	Row(card, 20, "Price")
	v.price = Field(card, 104, 22, "RIGHT", 16, function(text)
		local c = Char()
		if not c then return end
		local copper = W.ParseMoney(text)
		if not copper or copper < 0 or copper > MAX_PRICE then
			Toast("Price not clear. Try 50s or 2g.", "error")
			return
		end
		local floor = W.MIN_PRICE or 5000
		if copper < floor then
			Toast("The lowest fare on Wuber is " .. W.Money(floor) .. ".", "error")
			return
		end
		c.price = math.floor(copper + 0.5)
		Changed()
	end, function() return W.Money(Price()) end)
	v.price:SetPoint("RIGHT", card, "TOPRIGHT", -12, -20)

	Row(card, 48, "Name riders see")
	v.service = Field(card, 150, 22, "RIGHT", 32, function(text)
		local c = Char()
		if not c then return end
		c.service = CleanService(text)
		Changed()
	end, function()
		local c = Char()
		return c and CleanService(c.service) or "", W.Me()
	end)
	v.service:SetPoint("RIGHT", card, "TOPRIGHT", -12, -48)

	Row(card, 76, "Summon to")
	v.dest = Font(card, 13, P.text, "RIGHT")
	v.dest:SetPoint("RIGHT", card, "TOPRIGHT", -16, -76)

	Row(card, 104, "Warlocks")
	v.teamHint = Font(card, 11, P.muted)
	v.teamHint:SetPoint("LEFT", card, "TOPLEFT", 76, -104)
	v.team = {}
	for i, n in ipairs({ 3, 1 }) do
		local b = Button(card, 34, 22, tostring(n), "secondary", 12)
		b:SetPoint("RIGHT", card, "TOPRIGHT", -12 - (i - 1) * 40, -104)
		b.onClick = function()
			local c = Char()
			if not c or c.team == n then return end
			c.team = n
			W.Sound("click")
			Changed()
			Refresh()
		end
		b.n = n
		v.team[i] = b
	end

	-- requests and rides
	v.head = Header(v, "Requests")
	v.head:SetPoint("TOPLEFT", v, "TOPLEFT", 14, -320)
	v.count = Font(v, 12, P.muted)
	v.count:SetPoint("LEFT", v.head, "RIGHT", 8, 0)
	v.more = Font(v, 12, P.muted, "CENTER")
	v.empty = Font(v, 13, P.muted, "CENTER")
	v.empty:SetPoint("TOP", v, "TOP", 0, -366)
	v.waiting = CreateFrame("Frame", nil, v)
	v.waiting:SetSize(14, 14)
	v.waiting:SetPoint("BOTTOM", v.empty, "TOP", 0, 8)
	local wt = Tex(v.waiting, "ARTWORK", "glow", 14)
	wt:SetAllPoints(v.waiting)
	Accent(wt, 1)
	v.waiting.anim = BreatheAnim(v.waiting, 0.25, 1, 0.9)
	v.waiting:Hide()
	v.top = 344
	v.reqCards, v.rideCards = {}, {}
	return v
end

local function HideFrom(pool, n)
	for i = n + 1, #pool do
		pool[i]:Hide()
		pool[i].id = nil
	end
end

local function DrawDrive(v)
	local online = Online()
	local c = Char()
	v.dot:SetVertexColor(rgba(online and P.online or P.faint))
	v.status:SetText(online and "You're online" or "You're offline")
	v.sub:SetText(online and "Riders can see you on the map" or "Go online to take summons")
	v.earned:SetText(D.earned > 0 and W.Money(D.earned) or "0g")
	v.rides:SetText(D.paidCount == 1 and "1 ride" or (D.paidCount .. " rides"))
	v.go.Stack()
	v.go.Paint(online, c ~= nil)

	v.price.Sync()
	v.service.Sync()
	destNow = DestName() or destNow
	v.dest:SetText(destNow or "Unknown")
	local team = Team()
	for _, b in ipairs(v.team) do b.Style(b.n == team and "primary" or "secondary") end
	v.teamHint:SetText(team >= 3 and "no helpers needed" or ("riders bring " .. (3 - team) .. " helper" .. (team == 2 and "" or "s")))

	-- requests first (they can't wait), then rides
	local pending = Pending()
	local items = {}
	for _, r in ipairs(pending) do items[#items + 1] = { kind = "request", r = r } end
	for _, ride in ipairs(D.rides) do items[#items + 1] = { kind = "ride", ride = ride } end
	v.count:SetText(#pending > 0 and (#pending .. " waiting") or "")

	local cap = Capacity(v, v.top)
	local shown = math.min(#items, cap)
	if #items > cap and cap > 1 then shown = cap - 1 end
	local nReq, nRide, y = 0, 0, v.top
	for i = 1, shown do
		local it = items[i]
		local card
		if it.kind == "request" then
			nReq = nReq + 1
			card = Acquire(v.reqCards, RequestCard, v, nReq)
			card.h = 66
			Assign(card, it.r.id)
			card.r = it.r
			card.name:SetText(W.Short(W.Str(it.r.buyer) or "?"))
			card.info:SetText("to " .. (W.Str(it.r.dest) or "?"))
			card.price:SetText(W.Money(W.Num(it.r.price) or 0))
			card.ring:Show()
			card.accept:Show()
			card.decline:Show()
			card.status:Hide()
			PaintCountdown(card, it.r)
		else
			nRide = nRide + 1
			card = Acquire(v.rideCards, RideCard, v, nRide)
			card.h = 72
			Assign(card, it.ride.id)
			PaintRide(card, it.ride)
		end
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", v, "TOPLEFT", 12, -y)
		card:SetPoint("RIGHT", v, "RIGHT", -12, 0)
		y = y + card.h + CARD_GAP
	end
	HideFrom(v.reqCards, nReq)
	HideFrom(v.rideCards, nRide)
	if shown < #items then
		v.more:ClearAllPoints()
		v.more:SetPoint("TOP", v, "TOP", 0, -(y + 2))
		v.more:SetText("+" .. (#items - shown) .. " more")
		v.more:Show()
	else
		v.more:Hide()
	end
	if #items == 0 then
		v.empty:SetText(online and "Waiting for riders..." or "Go online to get requests here")
		v.empty:Show()
		if online then Play(v.waiting, v.waiting.anim) else Stop(v.waiting, v.waiting.anim) end
	else
		v.empty:Hide()
		Stop(v.waiting, v.waiting.anim)
	end
end

local STATE_TEXT = { new = "New", accepted = "Accepted" }
local STAGE_TEXT = { invited = "Invited", summoning = "Summoning", portal = "Portal up", waiting = "Portal up",
	arrived = "Arrived", paid = "Paid", done = "Done" }

local function DrawRR(v, name)
	v.title:SetText("Driving with " .. name)
	v.sub:SetText(name .. " answers your Wuber requests. Use its window to drive.")
	local list = {}
	for _, r in pairs(Incoming()) do
		if type(r) == "table" and r.id then list[#list + 1] = r end
	end
	table.sort(list, function(a, b) return (W.Num(a.at) or 0) > (W.Num(b.at) or 0) end)
	local cap = Capacity(v, v.top)
	local n = math.min(#list, cap)
	for i = 1, n do
		local r = list[i]
		local card = Acquire(v.cards, RequestCard, v, i)
		card.h = 66
		Assign(card, r.id)
		card.name:SetText(W.Short(W.Str(r.buyer) or "?"))
		card.info:SetText("to " .. (W.Str(r.dest) or "?") .. "  ·  " .. W.Money(W.Num(r.price) or 0))
		card.price:SetText("")
		card.ring:Hide()
		card.accept:Hide()
		card.decline:Hide()
		card.status:SetText(STAGE_TEXT[r.stage] or STATE_TEXT[r.state] or "")
		card.status:Show()
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", v, "TOPLEFT", 12, -(v.top + (i - 1) * (66 + CARD_GAP)))
		card:SetPoint("RIGHT", v, "RIGHT", -12, 0)
	end
	HideFrom(v.cards, n)
	Show(v.empty, #list == 0)
end

Refresh = function()
	if not ui or not ui.root:IsShown() then return end
	local name = Provider()
	local mode = name and "rr" or (IsWarlock() and "drive" or "locked")
	Show(ui.locked, mode == "locked")
	Show(ui.rr, mode == "rr")
	Show(ui.drive, mode == "drive")
	if mode == "drive" then
		DrawDrive(ui.drive)
	elseif mode == "rr" then
		DrawRR(ui.rr, name)
	end
end

function D.Refresh()
	W.Safe("drive refresh", Refresh)
end

-- countdown rings and the GO button's second pulse, ten times a second while shown
local function OnUpdate(self, elapsed)
	self.wait = (self.wait or 0) + (tonumber(elapsed) or 0)
	if self.wait < 0.1 then return end
	self.wait = 0
	W.Safe("drive tick", function()
		local v = ui and ui.drive
		if not (v and v:IsShown()) then return end
		v.go.Beat()
		for _, card in ipairs(v.reqCards) do
			if card:IsShown() and card.r and card.ring:IsShown() then PaintCountdown(card, card.r) end
		end
	end)
end

function D.Build(parent)
	if ui and ui.parent == parent then return ui.root end
	local root = CreateFrame("Frame", nil, parent)
	root:SetAllPoints(parent)
	ui = { parent = parent, root = root }
	ui.locked = BuildLocked(root)
	ui.rr = BuildRR(root)
	ui.drive = BuildDrive(root)
	ui.go = ui.drive.go
	root:SetScript("OnShow", function() W.Safe("drive show", Refresh) end)
	root:SetScript("OnHide", function()
		W.Safe("drive hide", function()
			ui.drive.price.edit:ClearFocus()
			ui.drive.service.edit:ClearFocus()
		end)
	end)
	root:SetScript("OnUpdate", OnUpdate)
	W.Safe("drive build", Refresh)
	return root
end

---------------------------------------------------------------------------
-- A window of its own (only if the Wuber window offers no tabs)
---------------------------------------------------------------------------

local tabbed = false

local function AddTab()
	if tabbed then return true end
	if not (W.UI and type(W.UI.AddTab) == "function") then return false end
	local ok = W.Safe("drive tab", W.UI.AddTab, "Drive", function(parent)
		local okb, root = W.Safe("drive build", D.Build, parent)
		return okb and root or nil
	end)
	tabbed = ok and true or false
	return tabbed
end

function D.Toggle()
	if tabbed and W.UI and type(W.UI.Show) == "function" then
		W.UI.Show("drive")
		return
	end
	local f = D.window
	if not f then
		f = CreateFrame("Frame", "WuberDriveFrame", UIParent)
		f:SetSize(360, 600)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		f:SetFrameStrata("DIALOG")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:RegisterForDrag("LeftButton")
		f:SetClampedToScreen(true)
		f:SetScript("OnDragStart", function(self) self:StartMoving() end)
		f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
		local bg = Rounded(f, 16, { P.window[1], P.window[2], P.window[3], 0.97 })
		local close = CreateFrame("Button", nil, f)
		close:SetSize(24, 24)
		close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
		close:RegisterForClicks("LeftButtonUp")
		local x = Tex(close, "ARTWORK", "close", 14, P.muted)
		x:SetPoint("CENTER", close, "CENTER", 0, 0)
		close:SetScript("OnClick", function() f:Hide() end)
		local title = Font(f, 18, P.text)
		title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
		title:SetText("Wuber Drive")
		local body = CreateFrame("Frame", nil, f)
		body:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -44)
		body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 8)
		D.Build(body)
		if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "WuberDriveFrame") end
		f:Hide()
		D.window = f
		f.bg = bg
	end
	if f:IsShown() then f:Hide() else f:Show() end
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

if type(W.SetLocalDriver) == "function" then W.SetLocalDriver(Beacon) end
AddTab()

W.Listen("REQUESTS", function() OnRequests() end)
W.Listen("SETTINGS", function() D.Refresh() end)
W.Listen("PROVIDER", function() D.Refresh() end)
W.On("GROUP_ROSTER_UPDATE", function() D.Refresh() end)

W.OnLogin(function()
	if type(W.SetLocalDriver) == "function" then W.SetLocalDriver(Beacon) end
	AddTab()
	destNow = DestName()
	-- where a summon goes from here, every 5 s
	W.Every(5, function()
		local d = DestName()
		if d and d ~= destNow then
			destNow = d
			if Online() then Announce() end
			D.Refresh()
		end
	end)
	W.Every(1, Expire)
	-- back online after a /reload if this character was driving
	if Online() then Announce() end
end)
