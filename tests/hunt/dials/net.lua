-- The hunt's NET dial (owner RIDE): the network of OTHER drivers when the check starts.
--   none     no driver at all (but me, when I drive)
--   one      (default) one open [Wuber] driver at Ratchet, 50s
--   many     8 open drivers at 8 places, prices from 20s to 5g (the order is seeded)
--   layers   3 drivers, 2 of them on another copy of the channel (Forever's internal realms: World:splitChannel /
--            channelCopy, on "Realm 6" of the same ruleset): their beacons never reach me; the first posts its tagged
--            [Wuber] advert in Trade (as its Advertise click does), so the whisper fallback can find it
--   late     one driver, and every addon message (everyone's) arrives 0.1 to 3 s late (one sender's stay in order;
--            different senders' cross)
--   oldpeer  one driver on the installed round-one Wuber (tests/round1/Wuber, version 1.0.0)
-- For a rider these are the drivers to ride with: ctx.peers.driver is the first (the one the ride dial books).
-- For a Warlock, a runner or a crew member they are rivals (ctx.peers.rivals); the customer is the ride dial's.
-- Facts: drivers = { { name, dest, price, copy, version } }, netDrivers (how many), lateMessages (true for late).
return function(Hunt)

local NAMES = { "Ana Smith", "Kit Lowe", "Max Dunn", "Ned Rowe", "Ola Finch", "Pat Webb", "Roy Cole", "Sam Tate", "Tia Marsh" }
local PLACES = { "Ratchet", "Crossroads", "Undercity", "Thunder Bluff", "Booty Bay", "Gadgetzan", "Tarren Mill", "Everlook" }
local PRICES = { 2000, 3000, 5000, 7500, 10000, 15000, 25000, 50000 }
local OTHER_REALM = "CAMWOW EU5 Realm 6 PvE" -- the founders' ruleset, another internal realm

local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end

local function freeNames(ctx, n)
	local out = {}
	for _, x in ipairs(NAMES) do
		if #out >= n then break end
		if key(x) ~= key(ctx.name) and not ctx.w:player(x) then out[#out + 1] = x end
	end
	if #out < n then error("net: not enough free names") end
	return out
end

local function waitFor(ctx, pred, max, step)
	step = step or 0.25
	local t = 0
	while not pred() do
		if t >= max then return false end
		ctx:advance(step)
		t = t + step
	end
	return true
end

-- adds the drivers (world hook): list of { spot, price, copy, old }
local function addDrivers(ctx, list)
	ctx.facts.drivers = {}
	local names = freeNames(ctx, #list)
	for i, d in ipairs(list) do
		local o = { spot = d.spot, class = "WARLOCK", shards = 10, money = 100000 }
		if d.copy then o.channelCopy, o.realm = d.copy, OTHER_REALM end
		if d.old then o.addonDirs = { Wuber = ctx.H.ADDONS.Wuber1 } end
		ctx.w:addClient(names[i], o)
		ctx.facts.drivers[i] = { name = names[i], dest = d.spot, price = d.price, copy = d.copy, version = d.old and "1.0.0" or nil,
			advert = d.advert }
	end
	ctx.facts.netDrivers = #list
end

-- opens every driver's shop (apply hook) and, for a rider, waits until my list has the ones I can hear
local function openDrivers(ctx)
	local W = ctx.W
	local clients = {}
	for i, d in ipairs(ctx.facts.drivers or {}) do
		local c = ctx.w:clientOf(d.name)
		clients[i] = c
		c.W.Char().price = d.price
		local Ch = c.W.Char()
		if Ch then Ch.welcomed = true end
		local okc = c.W.Driver.SetOnline(true)
		if okc == false then ctx:cannot("net: driver " .. d.name .. " could not open") end
		d.version = d.version or c.W.VERSION
	end
	if ctx.sit.role == "rider" then ctx.peers.driver = clients[1] else ctx.peers.rivals = clients end
	ctx.peers.drivers = clients
	-- the tagged advert of a driver on another copy (the driver's own Advertise click posts it in Trade). A player is in
	-- Trade by then: the channels are joined a few seconds after the login, so wait for that (a line posted before it is never heard)
	local function inTrade()
		for _, c in ipairs(ctx.me.player.channels or {}) do
			if tostring(c.name):lower() == "trade" then return true end
		end
		return false
	end
	local wantsAdvert = false
	for _, d in ipairs(ctx.facts.drivers or {}) do if d.advert then wantsAdvert = true end end
	if wantsAdvert and not inTrade() then waitFor(ctx, inTrade, 15) end
	for i, d in ipairs(ctx.facts.drivers or {}) do
		if d.advert then
			local DR = clients[i].W.Drive
			local text = DR and DR.AdvertText and DR.AdvertText()
			if text then ctx.w:chatFrom(d.name, text, "CHANNEL", "Trade") end
		end
	end
	-- what I can hear: drivers on my copy, and (by whisper) the one that advertised
	local function heard()
		if not (W and W.drivers) then return true end
		for _, d in ipairs(ctx.facts.drivers or {}) do
			if (not d.copy or d.advert) and not W.drivers[key(d.name)] then return false end
		end
		return true
	end
	if not waitFor(ctx, heard, ctx.sit.net == "late" and 25 or 15) then
		if ctx.sit.role == "rider" then ctx:cannot("net: the open drivers never showed in my list") end
	end
end

-- every addon message gets its own delay (0.1 to 3 s, seeded), never earlier than the sender's last one: late,
-- one sender's in order, different senders' crossing
local function lateWire(ctx)
	local w, rng = ctx.w, ctx.rng
	local send = w.sendAddon
	-- slow, but each sender's messages still arrive in the order sent (the game's server queue keeps it)
	local due = {}
	w.sendAddon = function(self, client, ...)
		local keep = self.latency
		local from = client and client.player and client.player.name or "?"
		local at = math.max(self.time + 0.1 + (rng:int(30) - 1) / 10, (due[from] or 0) + 0.01)
		due[from] = at
		self.latency = at - self.time
		local a, b, c = send(self, client, ...)
		self.latency = keep
		return a, b, c
	end
	ctx.facts.lateMessages = true
end

Hunt.dial{
	name = "net",
	about = "the other drivers on the network: none, one, many, on other realm copies, slow messages, an old Wuber",
	phase = 50,
	default = "one",
	values = {
		{ id = "none", about = "no driver anywhere (but me, when I drive)",
			world = function(ctx) ctx.facts.drivers, ctx.facts.netDrivers = {}, 0 end },
		{ id = "one", about = "one open [Wuber] driver at Ratchet for 50s",
			world = function(ctx) addDrivers(ctx, { { spot = "Ratchet", price = 5000 } }) end,
			apply = openDrivers },
		{ id = "many", about = "8 open drivers at 8 places, 20s to 5g",
			world = function(ctx)
				-- the first stays at Ratchet (the ride dial's); the rest of the places and the prices are shuffled
				local places, prices = { unpack(PLACES, 2) }, { unpack(PRICES) }
				for i = #places, 2, -1 do local j = ctx.rng:int(i) places[i], places[j] = places[j], places[i] end
				for i = #prices, 2, -1 do local j = ctx.rng:int(i) prices[i], prices[j] = prices[j], prices[i] end
				local list = { { spot = "Ratchet", price = prices[1] } }
				for i, p in ipairs(places) do list[#list + 1] = { spot = p, price = prices[i + 1] } end
				addDrivers(ctx, list)
			end,
			apply = openDrivers },
		{ id = "layers", about = "3 drivers, 2 on another copy of the channel (another internal realm); one of those posts its [Wuber] advert",
			world = function(ctx)
				addDrivers(ctx, { { spot = "Ratchet", price = 5000, copy = "B", advert = true }, { spot = "Crossroads", price = 4000 },
					{ spot = "Undercity", price = 6000, copy = "B" } })
			end,
			apply = openDrivers },
		{ id = "late", about = "one driver; every addon message arrives 0.1 to 3 s late (one sender's in order; senders cross)",
			world = function(ctx)
				lateWire(ctx)
				addDrivers(ctx, { { spot = "Ratchet", price = 5000 } })
			end,
			apply = openDrivers },
		{ id = "oldpeer", about = "one driver on the round-one Wuber (1.0.0)",
			world = function(ctx) addDrivers(ctx, { { spot = "Ratchet", price = 5000, old = true } }) end,
			apply = openDrivers },
	},
}

end
