-- Hunt dial file (tests/hunt/README.md): where the player stands and what is around. Owner: WORLD.
-- place   the flight master (flight map open), with the flight to the drivers known or not; the other continent
-- cost    the summon dearer or cheaper than flying (W.FlightCost / W.FlightTime answer; see "Flight answers" below)
-- combat  before the phone opens (phone.lua opens it afterwards: see the note there), or after it opened (phase 90)
-- group   alone, in a party, in a raid (bots without a window, grouped at once)
-- enemies enemy players near (a nameplate), or just fought (the fight as an addon can see it: harness pvpFight)
--
-- Flight answers. The flight table in Core/Flights.lua knows a price for every pair of towns it can route, so "known"
-- is only false for what it cannot route; the hunt wants both states whatever the drivers' places are. The way
-- tests/ui/bird_test.lua does it, the two lookups on the client's W are wrapped by one idempotent installer
-- (ctx.facts.installFlight()): known = the real answer, with a made-up one (23s, 9 min) where the table has none;
-- not known = nil; dearer/cheaper = a price built from the driver's own price. A /reload makes a new W: a scenario
-- that reloads calls ctx.facts.installFlight() again (and ctx.facts.openFlightMap() to open the map again).
-- Facts written: continent (0 Eastern Kingdoms, 1 Kalimdor, nil unknown), atFlightMaster, flightMapOpen,
-- flightRule = { known = true|false|nil, cost = "plain"|"dearer"|"cheaper" }, flightKnown (true/false when the rule
-- forces it), flightSecs (540 when forced), flightFor(dest) -> copper, secs, groupSize, groupKind, enemy (a name).
return function(Hunt)
	-- the flight masters the fake geography has (H.SPOTS names) and the node name their map lists
	local NODE = {
		Orgrimmar = "Orgrimmar, Durotar", ["Thunder Bluff"] = "Thunder Bluff, Mulgore", Crossroads = "Crossroads, The Barrens",
		Undercity = "Undercity, Tirisfal", Stormwind = "Stormwind, Elwynn", Ironforge = "Ironforge, Dun Morogh",
		["Booty Bay"] = "Booty Bay, Stranglethorn", Gadgetzan = "Gadgetzan, Tanaris", ["Tarren Mill"] = "Tarren Mill, Hillsbrad",
		Everlook = "Everlook, Winterspring",
	}
	local KALIMDOR = { "Orgrimmar", "Thunder Bluff", "Crossroads", "Gadgetzan", "Everlook" }
	local EASTERN = { "Undercity", "Tarren Mill", "Booty Bay", "Stormwind", "Ironforge" }

	local function opts(ctx)
		if type(ctx.clientOpts) ~= "table" then ctx.clientOpts = {} end
		return ctx.clientOpts
	end
	local function contOfSpot(ctx, spot)
		local s = ctx.H.SPOTS[spot]
		return s and (ctx.H.continentOf(s.mapID)) or nil
	end
	local function contOf(ctx, p)
		return p and p.mapID and (ctx.H.continentOf(p.mapID)) or nil
	end

	---------------------------------------------------------------------------
	-- Flight answers (see the header)
	---------------------------------------------------------------------------
	local function priceFor(W, dest)
		local best
		local ok, list = pcall(function() return W.UI.Drivers() end)
		if ok and type(list) == "table" then
			for _, d in ipairs(list) do
				if type(d) == "table" and type(d.dest) == "string" and tostring(dest or ""):lower() == d.dest:lower() and tonumber(d.price) then
					if not best or d.price < best then best = d.price end
				end
			end
		end
		return best or 5000
	end

	local function install(ctx)
		local W, f = ctx.W, ctx.facts
		local rule = f.flightRule
		if not (W and rule) then return false end
		if rule.known == nil and rule.cost == "plain" then return false end
		if f._flightW ~= W then
			f._flightW, f._origCost, f._origTime = W, W.FlightCost, W.FlightTime
			f._flightInstalled = nil
		end
		if f._flightInstalled then return true end
		f._flightInstalled = true
		local oc, ot = f._origCost, f._origTime
		W.FlightCost = function(from, to)
			if rule.known == false then return nil end
			if rule.cost == "dearer" then return math.max(1, math.floor(priceFor(W, to) / 2)), 1, "own" end
			if rule.cost == "cheaper" then return priceFor(W, to) * 3 + 100, 1, "own" end
			local c, ex, src, via
			if type(oc) == "function" then c, ex, src, via = oc(from, to) end
			if c == nil and rule.known == true then return 2300, 1, "own" end
			return c, ex, src, via
		end
		W.FlightTime = function(from, to)
			if rule.known == false then return nil end
			local t, src
			if type(ot) == "function" then t, src = ot(from, to) end
			if t == nil and (rule.known == true or rule.cost ~= "plain") then return 540, "est" end
			return t, src
		end
		return true
	end

	local function rule(ctx)
		local f = ctx.facts
		f.flightRule = f.flightRule or { known = nil, cost = "plain" }
		f.installFlight = function() return install(ctx) end
		f.flightFor = function(dest)
			local W = ctx.W
			if not (W and type(W.FlightCost) == "function") then return nil end
			local ok, c = pcall(W.FlightCost, nil, dest)
			local ok2, t = pcall(W.FlightTime, nil, dest)
			return ok and c or nil, ok2 and t or nil
		end
		return f.flightRule
	end

	---------------------------------------------------------------------------
	-- The flight map
	---------------------------------------------------------------------------
	local function mapNodes(ctx, known)
		local here = ctx.facts.flightSpot
		local list = { { name = NODE[here] or (here .. ", Somewhere"), type = "CURRENT", cost = 0, x = 0.5, y = 0.3 } }
		local pool = contOfSpot(ctx, here) == 1 and KALIMDOR or EASTERN
		local n = 0
		for _, s in ipairs(pool) do
			if s ~= here and NODE[s] then
				n = n + 1
				list[#list + 1] = { name = NODE[s], type = known and "REACHABLE" or "NONE", cost = known and (200 + 150 * n) or 0,
					x = 0.2 + 0.1 * n, y = 0.4 + 0.05 * n }
			end
		end
		return list
	end

	local function openMap(ctx)
		local f = ctx.facts
		ctx.w:openTaxiMap(ctx.me, mapNodes(ctx, f.flightRule and f.flightRule.known ~= false))
		ctx:advance(0.6)
		f.flightMapOpen = true
	end

	local function atMaster(ctx, known)
		local f = ctx.facts
		local r = rule(ctx)
		r.known = known
		f.atFlightMaster = true
		f.flightSpot = opts(ctx).spot
		f.openFlightMap = function()
			ctx.w:closeTaxiMap(ctx.me)
			ctx:advance(0.1)
			openMap(ctx)
		end
	end

	-- the ride dial's customer and the driver roles stand at places of their own (role.lua: Ratchet; ride.lua: the
	-- Barrens border): a driver moved to a flight master is refused every request ("here"). Not a bug, not a state
	-- a ride can be built in: skipped before the build.
	-- (a driver is moved to Undercity or Thunder Bluff, never to Orgrimmar where the riders stand). What still cannot
	-- be built is skipped before the build, at once: a rain check's trade, and a friend's group with a rider far away.
	local function driverRole(ctx) local r = (ctx.sit or {}).role return r ~= nil and r ~= "rider" end
	local function checkDriver(ctx, far)
		local sit = ctx.sit or {}
		-- (a rain check's trade needs the driver and the rider in one place: a driver is built there and walks to his
		-- place afterwards, ctx.facts.latePlace, which ride.lua calls when the rain check is done)
		-- every ride that needs the group: a friend's rider cannot join a friend on the other continent
		local needsGroup = { invited = true, summoning = true, arrived = true, paid = true, ended = true, timedout = true, raincheck = true }
		if far and sit.role == "friend" and needsGroup[sit.ride or "none"] then
			ctx:cannot("place: the friend's rider cannot join the group of a friend on the other continent")
		end
		-- a crew helper clicks the caster's portal: not from the other continent (Cast.lua counts a click only at the caster's station)
		local needsClick = { summoning = true, arrived = true, paid = true, ended = true, raincheck = true }
		if far and sit.role == "crew" and needsClick[sit.ride or "none"] then
			ctx:cannot("place: a crew helper cannot click the portal from the other continent")
		end
	end
	-- a driver with a rain check is built where the customer is and moves to his place afterwards: fn runs then
	local function lateWanted(ctx)
		local s = ctx.sit or {}
		return driverRole(ctx) and s.ride == "raincheck"
	end
	local function later(ctx, fn)
		local f = ctx.facts
		if not f.lateSpot then return fn() end
		f.latePlace = function()
			f.latePlace = nil
			local spot = f.lateSpot
			opts(ctx).spot = spot
			ctx.w:move(ctx.name, spot)
			ctx:advance(0.5)
			fn()
		end
	end
	local function placeValue(id, about, spots, known)
		return { id = id, about = about,
			pre = function(ctx)
				checkDriver(ctx, false)
				if spots then
					local pool = spots
					if driverRole(ctx) then pool = { "Undercity", "Thunder Bluff" } end
					local home = opts(ctx).spot
					opts(ctx).spot = ctx.rng:pick(pool)
					if lateWanted(ctx) then
						ctx.facts.lateSpot = opts(ctx).spot
						opts(ctx).spot = home
					end
				end
			end,
			apply = function(ctx) later(ctx, function()
				local f = ctx.facts
				if known ~= nil then
					atMaster(ctx, known)
					f.flightKnown = known
					f.flightSecs = known and 540 or nil
					f.flightCost = known and 2300 or nil
					install(ctx)
					ctx:advance(3) -- the drivers' beacons are heard before the map opens
					openMap(ctx)
				end
				f.continent = contOf(ctx, ctx.me.player)
			end) end }
	end

	Hunt.dial{
		name = "place",
		about = "where the player stands: in town, at a flight master (flight map open) with the flight known or not, or on the other continent",
		phase = 60,
		default = "town",
		values = {
			{ id = "town", about = "the session's own spot (a city); no flight map",
				apply = function(ctx)
					ctx.facts.atFlightMaster = false
					ctx.facts.continent = contOf(ctx, ctx.me.player)
					rule(ctx)
				end },
			placeValue("fm_known", "at a flight master, the flight map open, flying to the drivers known and a real flight (23s, about 9 min)",
				{ "Orgrimmar", "Undercity", "Thunder Bluff" }, true),
			placeValue("fm_unknown", "at a flight master, the flight map open, flying to the drivers NOT known (no price, no time)",
				{ "Orgrimmar", "Undercity", "Thunder Bluff" }, false),
			{ id = "other_continent", about = "in a town on the other continent from where the other players stand",
				pre = function(ctx) checkDriver(ctx, true) end,
				world = function(ctx)
					local kal, east = 0, 0
					for _, p in pairs(ctx.w.players) do
						local c = contOf(ctx, p)
						if c == 1 then kal = kal + 1 elseif c == 0 then east = east + 1 end
					end
					-- the other players' continent is the one with more of them (a tie counts as Kalimdor)
					local theirs = (east > kal) and 0 or 1
					local pool = theirs == 1 and { "Booty Bay", "Undercity", "Stormwind" } or { "Gadgetzan", "Orgrimmar", "Thunder Bluff" }
					local home = opts(ctx).spot
					opts(ctx).spot = ctx.rng:pick(pool)
					if lateWanted(ctx) then
						ctx.facts.lateSpot = opts(ctx).spot
						opts(ctx).spot = home
					end
					ctx.facts.driverContinent = theirs
				end,
				apply = function(ctx) later(ctx, function()
					ctx.facts.atFlightMaster = false
					ctx.facts.continent = contOf(ctx, ctx.me.player)
					rule(ctx)
				end) end },
		},
	}

	---------------------------------------------------------------------------
	-- Cost: summon against flying
	---------------------------------------------------------------------------
	local function costValue(id, about, cost)
		return { id = id, about = about,
			apply = function(ctx)
				local r = rule(ctx)
				r.cost = cost
				if cost ~= "plain" then ctx.facts.flightCost = nil ctx.facts.flightSecs = ctx.facts.flightSecs or 540 end
				ctx.facts.summonVsFlight = cost == "dearer" and "summon dearer" or cost == "cheaper" and "summon cheaper" or nil
				install(ctx)
			end }
	end
	Hunt.dial{
		name = "cost",
		about = "the summon's price against flying: as the plain world gives, dearer, or cheaper",
		phase = 59, -- before "place" (60): the rule is in force when the flight map opens
		default = "plain",
		values = {
			costValue("plain", "whatever the plain world gives", "plain"),
			costValue("summon_dearer", "the summon costs more than flying (flying costs half the driver's price, 9 min)", "dearer"),
			costValue("summon_cheaper", "the summon costs less than flying (flying costs three times the price plus 1s, 9 min)", "cheaper"),
		},
	}

	---------------------------------------------------------------------------
	-- Combat (the phone's "before" is done by phone.lua's own hook, which opens the phone: see there)
	---------------------------------------------------------------------------
	local function fight(ctx)
		if not ctx.me.player.combat then ctx.w:enterCombat(ctx.me) end
		ctx.facts.inCombat = true
	end
	Hunt.dial{
		name = "combat",
		about = "combat: none, started before the phone opens, or started after it opened",
		phase = 90,
		default = "no",
		values = {
			{ id = "no", apply = function(ctx) ctx.facts.inCombat = ctx.me.player.combat == true end },
			{ id = "before", about = "in combat before the phone opens (phone.lua enters combat first, then opens it)",
				apply = function(ctx) fight(ctx) end },
			{ id = "after", about = "combat starts after the phone opened", apply = function(ctx) fight(ctx) end },
		},
	}

	---------------------------------------------------------------------------
	-- Group
	---------------------------------------------------------------------------
	-- every ride state but none (ride.lua): a rider already in a group is refused ("group") and cannot be invited
	local RIDES = { "requested", "invited", "summoning", "arrived", "paid", "ended", "timedout", "raincheck" }
	local MATES = { "Alder Mate", "Birch Mate", "Cedar Mate", "Dune Mate", "Elm Mate", "Fir Mate", "Gorse Mate", "Holly Mate", "Ivy Mate" }
	local function here(ctx, p)
		local me = ctx.me.player
		ctx.w:placePlayer(p, { mapID = me.mapID, x = me.x, y = me.y, zone = me.zone, sub = me.subZone })
	end
	local function grouped(n, kind)
		return function(ctx)
			local names = { ctx.me.player.name }
			for i = 1, n do
				local p = ctx.w:addBot(MATES[i], { spot = "Orgrimmar", class = (i % 3 == 0) and "WARLOCK" or "MAGE" })
				here(ctx, p)
				names[#names + 1] = p.name
			end
			ctx.w:group(names)
			ctx:advance(1)
			ctx.facts.groupSize, ctx.facts.groupKind = #names, kind
		end
	end
	Hunt.dial{
		name = "group",
		about = "alone, in a party (3 players), or in a raid (10 players); the player leads",
		phase = 60,
		default = "solo",
		values = {
			{ id = "solo", apply = function(ctx) ctx.facts.groupSize, ctx.facts.groupKind = 1, "solo" end },
			{ id = "party", about = "in a party of 3 with two bots, the player leads (never with a ride: the driver's invite is refused, \"group\")",
				excludes = { ride = RIDES }, apply = grouped(2, "party") },
			{ id = "raid", about = "in a raid of 10 with nine bots, the player leads (never with a ride)",
				excludes = { ride = RIDES }, apply = grouped(9, "raid") },
		},
	}

	---------------------------------------------------------------------------
	-- Enemies
	---------------------------------------------------------------------------
	local function foe(ctx)
		local me = ctx.me.player
		local faction = (me.faction or "Horde") == "Horde" and "Alliance" or "Horde"
		local p = ctx.w:addBot("Ally Foe", { faction = faction, class = "WARRIOR" })
		here(ctx, p)
		ctx.facts.enemy = p.name
		ctx.facts.showEnemy = function() return ctx.me:showPlate(p.name) end
		return p
	end
	Hunt.dial{
		name = "enemies",
		about = "enemy players: none, one close with its nameplate in view, or one just fought (a fight an addon can see)",
		phase = 60,
		default = "none",
		values = {
			{ id = "none" },
			{ id = "near", about = "a flagged enemy player stands close, nameplate in view", apply = function(ctx)
				local p = foe(ctx)
				ctx.me:showPlate(p.name)
			end },
			{ id = "fought", about = "a fight with a flagged enemy player just ended (nameplate seen, combat entered and left)", apply = function(ctx)
				local p = foe(ctx)
				ctx.w:pvpFight(ctx.me, p.name)
			end },
		},
	}
end
