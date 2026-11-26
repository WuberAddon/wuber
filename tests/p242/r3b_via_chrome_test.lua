-- Round 3 b: the route header's via tag ("boat") on the Waiting-for-the-driver screen lay in the place of the window's
-- header buttons. Promise: the header pill, its words and its via tag stay clear of the header buttons (fold, cog, x),
-- folded and unfolded, for every via word, and a header with no via tag is unchanged.
local T = ...
local H, test, ok = T.H, T.test, T.ok

local function meet(a, b)
	return a and b and a.l < b.l + b.w - 2 and b.l < a.l + a.w - 2 and a.b < b.b + b.h - 2 and b.b < a.b + a.h - 2
end
local function box(r) return r and string.format("(%d,%d %dx%d)", r.l, r.b, r.w, r.h) or "nil" end

local function finding(unfold, from, to, via)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Booty Bay" })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.UI.Toggle(true) w:advance(3)
	W.ride = { id = "r3bfind", driver = "Mia Runner", driverKey = "mia runner", dest = "Ratchet", price = 5000,
		state = "requesting", at = r.env.GetTime(), service = "Mia's Rides" }
	W.UI.Show("finding") w:advance(1)
	W.UI.RefreshNow() w:advance(0.5)
	local s = W.UI.state.screens.finding
	s.route:Set(from, to, via)
	w:advance(0.5)
	return W, s
end

local function clear(W, s, what)
	local ui = W.UI.state
	local route = s.route
	ok(H.visible(route), what .. ": the header shows")
	local parts = { { "pill", route }, { "from", route.from }, { "to", route.to } }
	if route.viaText then parts[#parts + 1] = { "via tag", route.via } end
	local btns = { close = ui.close, gear = ui.gear, fold = ui.phone and ui.phone.fold }
	for bn, b in pairs(btns) do
		if H.visible(b) then
			local br = H.rect(b)
			for _, p in ipairs(parts) do
				local pr = H.rect(p[2])
				ok(not meet(pr, br), what .. ": the " .. p[1] .. " " .. box(pr) .. " is clear of the " .. bn .. " button " .. box(br))
			end
		end
	end
end

-- guard: none (fails on base 44d6e2c6)
test("r3b: the route header's via tag is clear of the header buttons, for every via word and place", function()
	for _, via in ipairs({ "boat", "zeppelin", "tram", "portal" }) do
		for _, pair in ipairs({ { "Booty Bay", "Ratchet" }, { "Stranglethorn Vale", "Undercity" }, { "Booty Bay", "Thousand Needles Crossing" } }) do
			local W, s = finding(false, pair[1], pair[2], via)
			clear(W, s, via .. " " .. pair[1] .. " > " .. pair[2])
		end
	end
end)

-- guard: the header with no via tag is unchanged (same width and height as the plain route)
test("r3b: a header with no via tag keeps its shape and stays clear of the buttons", function()
	local W, s = finding(false, "Booty Bay", "Ratchet", nil)
	clear(W, s, "no via")
	ok(s.route:GetHeight() == 32, "one row high, got " .. tostring(s.route:GetHeight()))
	ok(not s.route.via:IsShown(), "no tag shows")
end)
