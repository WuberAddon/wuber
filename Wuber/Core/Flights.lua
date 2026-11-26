-- Module: Core.Flights
-- Purpose: what flying would cost and take: W.FlightCost and the learned-price store, list prices and
--   routes from W.TAXI, W.FlightTime (measured here, shared, else the estimate), and the generated flight
--   table (BEGIN/END FLIGHT TABLE block, rewritten by tools/build-flights.js).
-- API: W.FLY_EST, W.FLY, W.FlightPrune, W.FlightMerge, W.FlightShareList, W.LearnFlights, W.LearnFlightNodes,
--   W.FlightCost, W.FlightSeen, W.FlightTime, W.FlightInfo, W.TAXI
-- Internals: (none)
-- Uses: Core.Places
-- Later: Core.FlightTimes
-- Events: listens On TAXIMAP_OPENED, On TAXIMAP_CLOSED, login; fires FLIGHTS
-- Standalone: no
-- Test: tests/core/flights_test.lua
-- From: Places.lua 548-1292 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("Core.Flights", { "Core.Places" })
local PlacesMod = W.Mod("Core.Places")
local call, exact = PlacesMod.call, PlacesMod.exact

local str, num = W.Str, W.Num

---------------------------------------------------------------------------
-- What flying would cost (SPEC5, the author: "money saved vs flight paths")
---------------------------------------------------------------------------
-- W.FlightCost(fromPlace, toPlace) -> copper, exact (always 1), source ("own" or "shared"),
-- or nil when no flight master showed it (then nothing is shown). fromPlace nil = where the
-- player stands. W.FlightTime(fromPlace, toPlace) -> seconds, source: "own" (measured on this
-- account, Core.FlightTimes), "shared" (another Wuber user measured it), else "est" (the
-- time worked out from the game's own flight splines, Core.FlightTimes; shown as "about"), or nil.
--
-- The store: WuberDB.flights["faction|from|to"] (review 2.2 #11: one side's prices; neutral
-- towns have a flight master for each side) = { c = copper, at = time(), src, n,
-- t = seconds, tat, tsrc, tn }:
--   own:    read at a flight master on this account (TAXIMAP_OPENED: TaxiNodeCost, the game's
--           own total for the whole route; the newest visit wins). src nil.
--   own times: flights this account took (Core.FlightTimes: take-off to landing), tsrc "own".
--           (2.2.x read Enhanced Flight Map's times as tsrc "efm": 2.3.0 no longer reads it; the
--           login migration, W.db.flightsV = 3, keeps those seconds as "own": they were real
--           flights of this account.)
--   shared: real prices (and measured times) another Wuber user's flight master showed,
--           passed over the network (Net.lua, kind F). src/tsrc "shared", n/tn = how many
--           peers reported that same value. Own always wins over shared; a shared value
--           replaces an older shared one only when newer or reported by more peers.
-- Shared entries must name two known towns or cities, none of them the other side's, at
-- most 100g (more than 0), 5 s to 1 h. 2000 entries at most: the oldest shared go first.
-- Exact only (the author: never show a number we can't back): a shared price was seen by a player.
W.FLY_EST = {}

do
local FLY = {
	MAX = 2000,             -- entries kept; past this the oldest shared go
	MAX_COPPER = 1000000,   -- 100g: anything dearer is not a flight
	MAX_AGE = 90 * 86400,   -- an older shared price is not taken
	MIN_SECS = 5, MAX_SECS = 3600,
	NODES_MAX = 600,        -- node ids remembered per side
	SPEED = 30,             -- yards a second on a flight (the estimate; calibrated by own flights; 29.8 over 4,558 recorded flights)
	TAKEOFF = 3,            -- seconds added once per flight (the estimate)
	CROSS = 240,            -- seconds a boat or zeppelin crossing takes (the estimate)
	vouch = {},             -- this session: [key|field][value] = { [peer] = true, n }
	ver = 0,                -- goes up whenever the store changes (Net's share list follows it)
}
W.FLY = FLY

-- Towns whose flight master serves one side only (neutral towns have one for each side).
FLY.SIDE = {}
for _, n in ipairs({ "Orgrimmar", "Undercity", "Thunder Bluff", "Crossroads", "Camp Mojache", "Brackenwall Village",
	"Splintertree Post", "Sun Rock Retreat", "Shadowprey Village", "Freewind Post", "Valormok", "Grom'gol",
	"Tarren Mill", "Kargath", "Stonard", "Hammerfall", "Revantusk Village" }) do
	FLY.SIDE[W.NormPlace(n)] = "H"
end
for _, n in ipairs({ "Stormwind", "Ironforge", "Darnassus", "Feathermoon Stronghold", "Theramore", "Auberdine",
	"Southshore", "Menethil Harbor" }) do
	FLY.SIDE[W.NormPlace(n)] = "A"
end

local function flightDB()
	local d0 = W.db
	if type(d0) ~= "table" then return nil end
	if type(d0.flights) ~= "table" then d0.flights = {} end
	return d0.flights
end

local function side()
	local s = W.Faction and W.Faction() or nil
	if s == "H" or s == "A" then return s end
	return nil
end

local function stamp() return num(call(time)) or 0 end

-- A place's (or a flight node's) key for the store: the place's name when it is one, else the
-- node's own name, lower case.
local function flyKey(name)
	name = str(name)
	if not name then return nil end
	local p = exact(name) or (W.FindPlace and W.FindPlace(name))
	return W.NormPlace(p and p.name or name)
end

-- "Ratchet, The Barrens" -> "Ratchet"
local function nodePlace(nodeName)
	nodeName = str(nodeName)
	if not nodeName then return nil end
	local head = nodeName:match("^([^,]+)") or nodeName
	head = head:gsub("%s+$", "")
	return head
end

-- A town or city for a shared or measured entry: its store key, or nil (unknown, a zone or a
-- dungeon, or a town only the other side flies to).
local function town(s, name)
	local p = exact(name or "")
	if not p or (p.kind ~= "town" and p.kind ~= "city") then return nil end
	local k = W.NormPlace(p.name)
	local only = FLY.SIDE[k]
	if only and only ~= s then return nil end
	return k
end

-- Both ends of a shared entry (store keys), or nil.
function FLY.places(s, fromName, toName)
	if s ~= "H" and s ~= "A" then return nil end
	local a, b = town(s, fromName), town(s, toName)
	if not a or not b or a == b then return nil end
	return a, b
end

local function okCopper(c)
	c = num(c)
	if c and c > 0 and c <= FLY.MAX_COPPER and c % 1 == 0 then return c end
	return nil
end

local function okSecs(t)
	t = num(t)
	if t and t >= FLY.MIN_SECS and t <= FLY.MAX_SECS then return math.floor(t + 0.5) end
	return nil
end

-- Whether an entry holds anything of our own (never dropped by the cap).
local function hasOwn(e)
	return (num(e.c) ~= nil and e.src ~= "shared") or (num(e.t) ~= nil and e.tsrc ~= "shared")
end

-- Keeps the store at FLY.MAX entries: bad ones go, then the oldest shared. Returns the count.
function W.FlightPrune()
	local store = flightDB()
	if not store then return 0 end
	local n, shared = 0, {}
	for k, e in pairs(store) do
		if type(k) ~= "string" or type(e) ~= "table" then
			store[k] = nil
		else
			n = n + 1
			if not hasOwn(e) then shared[#shared + 1] = { k = k, at = math.max(num(e.at) or 0, num(e.tat) or 0) } end
		end
	end
	if n <= FLY.MAX then return n end
	table.sort(shared, function(a, b)
		if a.at ~= b.at then return a.at < b.at end
		return a.k < b.k
	end)
	for i = 1, math.min(#shared, n - FLY.MAX) do
		store[shared[i].k] = nil
		n = n - 1
	end
	FLY.ver = FLY.ver + 1
	return n
end

local FIELDS = { c = { "c", "at", "src", "n" }, t = { "t", "tat", "tsrc", "tn" } }

-- One shared value into an entry (field "c" or "t"); true when the entry changed.
local function take(e, k, which, v, at, peer)
	local f = FIELDS[which]
	local vf, af, sf, nf = f[1], f[2], f[3], f[4]
	local cur = num(e[vf])
	if cur and e[sf] ~= "shared" then return false end -- own always wins
	-- each peer counts once per entry and value (this session)
	local vk = k .. "|" .. which
	local seen = FLY.vouch[vk]
	if not seen then
		seen = {}
		FLY.vouch[vk] = seen
	end
	local by = seen[v]
	if not by then
		by = { n = 0 }
		seen[v] = by
	end
	local newPeer = true
	if peer then
		newPeer = not by[peer]
		if newPeer then
			by[peer] = true
			by.n = by.n + 1
		end
	end
	if not cur then
		e[vf], e[af], e[sf], e[nf] = v, at, "shared", 1
		return true
	end
	local oldAt, oldN = num(e[af]) or 0, num(e[nf]) or 1
	if cur == v then
		local changed = false
		if newPeer and peer and oldN < 99 then
			e[nf] = oldN + 1
			changed = true
		end
		if at > oldAt then
			e[af] = at
			changed = true
		end
		return changed
	end
	if at > oldAt + 60 or by.n > oldN then
		e[vf], e[af], e[nf] = v, at, math.max(1, by.n)
		return true
	end
	return false
end

-- A price (copper) and/or a measured time (seconds) another Wuber user passed on, for side s
-- ("H"/"A", must be ours), seen at `at` (time()); peer: who said it. Implausible values,
-- unknown places and the other side's towns are refused. Returns true when the store changed.
function W.FlightMerge(s, fromName, toName, copper, secs, at, peer)
	local store = flightDB()
	if not store or s ~= side() then return false end
	local a, b = FLY.places(s, fromName, toName)
	at = num(at)
	local now0 = stamp()
	if not a or not at or at > now0 + 300 or now0 - at > FLY.MAX_AGE then return false end
	copper, secs = okCopper(copper), okSecs(secs)
	if not copper and not secs then return false end
	local k = s .. "|" .. a .. "|" .. b
	local e = store[k]
	local fresh = type(e) ~= "table"
	if fresh then e = {} end
	local changed = false
	if copper then changed = take(e, k, "c", copper, at, peer) end
	if secs then changed = take(e, k, "t", secs, at, peer) or changed end
	if fresh and changed then
		store[k] = e
		W.FlightPrune()
	end
	if changed then FLY.ver = FLY.ver + 1 end
	return changed
end

-- What this character may pass on: its side's entries between two towns, with a plausible
-- price and/or measured time: { k, from, to, c, t, at, own }.
function W.FlightShareList()
	local s, store = side(), flightDB()
	if not s or not store then return {} end
	local cache = FLY.cache
	if cache and cache.ver == FLY.ver and cache.side == s and cache.store == store then return cache.list end
	local out, pre = {}, s .. "|"
	for k, e in pairs(store) do
		if type(k) == "string" and k:sub(1, 2) == pre and type(e) == "table" then
			local a, b = k:match("^.|([^|]+)|([^|]+)$")
			if a and FLY.places(s, a, b) then
				local c, t = okCopper(e.c), okSecs(e.t)
				if c or t then
					local at = c and num(e.at) or num(e.tat) or 0
					out[#out + 1] = { k = k, from = a, to = b, c = c, t = t, at = at, own = hasOwn(e) }
				end
			end
		end
	end
	FLY.cache = { ver = FLY.ver, side = s, store = store, list = out }
	return out
end

-- A flight this account took (Core.FlightTimes): side s, store keys a and b, seconds. A new
-- time replaces the old one unless within 10 % (then the smaller stays). Returns the seconds
-- stored, or nil (refused).
function FLY.SetOwnTime(s, a, b, secs)
	local store = flightDB()
	local t = okSecs(secs)
	if not store or not t or (s ~= "H" and s ~= "A") or type(a) ~= "string" or type(b) ~= "string" or a == b then return nil end
	local k = s .. "|" .. a .. "|" .. b
	local e = store[k]
	if type(e) ~= "table" then
		e = {}
		store[k] = e
	end
	local old = e.tsrc ~= "shared" and okSecs(e.t) or nil
	if old and math.abs(t - old) <= old * 0.1 then t = math.min(t, old) end
	e.t, e.tat, e.tsrc, e.tn = t, stamp(), "own", nil
	W.FlightPrune()
	FLY.ver = FLY.ver + 1
	return t
end

-- Learns every cost from the flight master the player stands at (TAXIMAP_OPENED). Returns
-- how many were stored.
function W.LearnFlights()
	local n = num(call(NumTaxiNodes))
	local store = flightDB()
	if not n or n <= 0 or not store then return 0 end
	local here
	for i = 1, math.min(n, 200) do
		if str(call(TaxiNodeGetType, i)) == "CURRENT" then here = nodePlace(call(TaxiNodeName, i)) end
	end
	local fromKey = here and flyKey(here)
	if not fromKey or fromKey == "" then return 0 end
	local t0, learned = stamp(), 0
	local s = side()
	if not s then return 0 end -- (a cost is only ever one side's)
	for i = 1, math.min(n, 200) do
		if str(call(TaxiNodeGetType, i)) == "REACHABLE" then
			local to = flyKey(nodePlace(call(TaxiNodeName, i)))
			local cost = num(call(TaxiNodeCost, i))
			if to and to ~= "" and to ~= fromKey and cost and cost >= 0 and cost < 10000000 then
				local k = s .. "|" .. fromKey .. "|" .. to
				local e = store[k]
				if type(e) ~= "table" then
					e = {}
					store[k] = e
				end
				e.c, e.at, e.src, e.n = math.floor(cost), t0, nil, nil -- own: beats any shared
				learned = learned + 1
			end
		end
	end
	if learned > 0 then
		W.FlightPrune()
		FLY.ver = FLY.ver + 1
	end
	return learned
end

---------------------------------------------------------------------------
-- The game's list prices (W.TAXI: the client's own TaxiNodes / TaxiPath, tools/build-flights.js)
---------------------------------------------------------------------------
-- the author: always the FULL list price, without reputation discounts. So first choice: the
-- cheapest route over the game's direct legs between flight points this side can use, plus
-- free boats and zeppelins (W.TAXI.boats, each for its side), from the rider's flight point to
-- the destination's. Source "table". Prices seen at a flight master (own, then shared) are
-- used only where the table can't route the trip (a route it lacks, e.g. after a patch); a
-- seen price may carry a discount, so it never replaces a table price.
-- Flight points:
--   a place with its own (by name: "Undercity" <-> node "Undercity, Tirisfal"; Darnassus <->
--   Rut'theran Village; Nighthaven <-> Moonglade): those this side can use;
--   anything else (a dungeon, a rider out in a zone): the nearest flight point this side can
--   use on the same continent, by straight distance in world coordinates: the place's map
--   point (or the rider's position) through W.WorldPos (C_Map.GetWorldPosFromMapPos: the
--   continent and world x, y, the same as TaxiNodes' Pos).
-- No route at all (no crossing for this side, a position that can't be read): nil (hidden).
local NODE_PLACE = { ["ruttheran village"] = "darnassus", moonglade = "nighthaven" }
local taxi

local function taxiData()
	if taxi then return taxi end
	taxi = { at = {}, place = {}, adj = {}, nodes = {}, cache = {} }
	local T = W.TAXI
	if type(T) ~= "table" or type(T.nodes) ~= "table" then return taxi end
	taxi.nodes = T.nodes
	for id, n in pairs(T.nodes) do
		local nm = W.NormPlace(n[1])
		local p = exact(NODE_PLACE[nm] or nm)
		if p and (p.kind == "town" or p.kind == "city") then
			local k = W.NormPlace(p.name)
			taxi.at[k] = taxi.at[k] or {}
			table.insert(taxi.at[k], id)
			taxi.place[id] = k
		end
	end
	local function link(a, b, c, s)
		local l = taxi.adj[a] or {}
		taxi.adj[a] = l
		l[#l + 1] = { b, c, s }
	end
	local L = type(T.legs) == "table" and T.legs or {}
	for i = 1, #L - 2, 3 do link(L[i], L[i + 1], L[i + 2]) end
	local B = type(T.boats) == "table" and T.boats or {}
	for i = 1, #B - 2, 3 do
		link(B[i], B[i + 1], 0, B[i + 2])
		link(B[i + 1], B[i], 0, B[i + 2])
	end
	return taxi
end
FLY.TaxiData = taxiData
function FLY.TaxiReset() taxi = nil end -- (W.TAXI changed: read again)

local function usable(n, s) return type(n) == "table" and type(n[5]) == "string" and n[5]:find(s, 1, true) ~= nil end

-- Whether flight point id has a flight or crossing this side can take (a node with none, like
-- Tidegear Coast, is no use as the nearest flight point).
local function linked(id, s)
	local d = taxiData()
	for _, e in ipairs(d.adj[id] or {}) do
		if usable(d.nodes[e[1]], s) and (e[3] == nil or e[3] == s) then return true end
	end
	return false
end

-- The nearest flight point this side can use on a continent, to world x, y.
local function nearestNode(cont, wx, wy, s)
	if not (cont and wx and wy) then return nil end
	local best, bestD
	for id, n in pairs(taxiData().nodes) do
		if n[2] == cont and usable(n, s) and linked(id, s) then
			local dx, dy = n[3] - wx, n[4] - wy
			local dd = dx * dx + dy * dy
			if not bestD or dd < bestD or (dd == bestD and id < best) then best, bestD = id, dd end
		end
	end
	return best
end

-- A journey's end: the flight points of the place, else the nearest one (to the rider when
-- mine, else to the place).
local function endpoints(place, s, mine)
	local d, out = taxiData(), {}
	for _, id in ipairs(place and d.at[W.NormPlace(place.name)] or {}) do
		if usable(d.nodes[id], s) then out[#out + 1] = id end
	end
	if #out > 0 then return out end
	local cont, wx, wy
	if mine then
		cont, wx, wy = W.WorldPos(W.MyPosition())
	elseif place then
		cont, wx, wy = W.PlaceWorld(place)
	end
	out[1] = nearestNode(cont, wx, wy, s)
	return out
end

-- One continent for every node of srcs and dsts: that continent, else nil.
local function oneContinent(d, srcs, dsts)
	local cont
	for _, list in ipairs({ srcs, dsts }) do
		for _, id in ipairs(list) do
			local n = d.nodes[id]
			if not n or (cont and n[2] ~= cont) then return nil end
			cont = n[2]
		end
	end
	return cont
end

-- Dijkstra from any of srcs to any of dsts; inland: no boat or zeppelin over the sea (one
-- whose two ends are on different continents). { copper, boat on the way, node ids } or
-- { false, false, false }.
local function search(d, srcs, dsts, s, inland)
	local dist, done, boat, goal, prev = {}, {}, {}, {}, {}
	for _, id in ipairs(srcs) do dist[id], boat[id] = 0, false end
	for _, id in ipairs(dsts) do goal[id] = true end
	local res = { false, false, false }
	for _ = 1, 500 do
		local u, du
		for id, v in pairs(dist) do
			if not done[id] and (not du or v < du or (v == du and id < u)) then u, du = id, v end
		end
		if not u then break end
		if goal[u] then
			local path, at = {}, u
			while at do
				table.insert(path, 1, at)
				at = prev[at]
			end
			res = { du, boat[u], path }
			break
		end
		done[u] = true
		for _, e in ipairs(d.adj[u] or {}) do
			local v, c, es = e[1], e[2], e[3]
			if not done[v] and usable(d.nodes[v], s) and (es == nil or es == s)
				and not (inland and es ~= nil and d.nodes[v][2] ~= d.nodes[u][2]) then
				local nd = du + c
				if not dist[v] or nd < dist[v] then dist[v], boat[v], prev[v] = nd, boat[u] or es ~= nil, u end
			end
		end
	end
	return res
end

-- The cheapest route from any of srcs to any of dsts: copper, whether a boat or zeppelin is on
-- the way, and the route's node ids in order; nil when they don't connect. A trip on one
-- continent flies when it can: the free boats over the sea and back are nobody's way there
-- (Auberdine > Theramore is the 6s30c flight, not two boats by Menethil Harbor).
local function cheapest(srcs, dsts, s)
	local d = taxiData()
	local key = s .. "|" .. table.concat(srcs, ",") .. ">" .. table.concat(dsts, ",")
	local hit = d.cache[key]
	if hit then return hit[1], hit[2], hit[3] end
	local res = oneContinent(d, srcs, dsts) and search(d, srcs, dsts, s, true)
	if not (res and res[1]) then res = search(d, srcs, dsts, s, false) end
	d.cache[key] = res
	return res[1], res[2], res[3]
end
FLY.Cheapest = cheapest -- (read by the tests)

-- The game's list price from `from` to `to` for side s (mine: from is where the rider stands):
-- copper, "boat" when a boat or zeppelin is on the way; nil when nothing connects or it's free.
function FLY.tableCost(from, to, mine, s)
	if not s then return nil end
	local srcs, dsts = endpoints(from, s, mine), endpoints(to, s, false)
	if #srcs == 0 or #dsts == 0 then return nil end
	local c, boat = cheapest(srcs, dsts, s)
	if not c or c <= 0 then return nil end
	return c, boat and "boat" or nil
end

-- The cheapest route's node ids from `from` to `to` (places; mine: from is where the rider
-- stands) for side s, and "boat" when a crossing is on it; nil when nothing connects.
function FLY.Route(from, to, mine, s)
	if not s then return nil end
	local srcs, dsts = endpoints(from, s, mine), endpoints(to, s, false)
	if #srcs == 0 or #dsts == 0 then return nil end
	local c, boat, path = cheapest(srcs, dsts, s)
	if not c or type(path) ~= "table" then return nil end
	return path, boat and "boat" or nil
end
FLY.Usable = usable
FLY.NodePlace = nodePlace

---------------------------------------------------------------------------
-- The flight map's node ids (C_TaxiMap, where the client has them)
---------------------------------------------------------------------------
-- WuberDB.flightNodes[side][id] = place key: our own reading of the flight map.

local function nodesDB(s)
	local d0 = W.db
	if type(d0) ~= "table" or not s then return nil end
	if type(d0.flightNodes) ~= "table" then d0.flightNodes = {} end
	local t = d0.flightNodes[s]
	if type(t) ~= "table" then
		t = {}
		d0.flightNodes[s] = t
	end
	return t
end

-- A node's side from the game's enum (Neutral 0, Horde 1, Alliance 2): "H", "A" or nil.
local function nodeSide(v)
	v = num(v)
	local E = type(Enum) == "table" and type(Enum.FlightPathFaction) == "table" and Enum.FlightPathFaction or {}
	if v == nil then return nil end
	if v == (num(E.Horde) or 1) then return "H" end
	if v == (num(E.Alliance) or 2) then return "A" end
	return nil
end

-- Reads the flight map's node ids (TAXIMAP_OPENED). Returns how many were new.
function W.LearnFlightNodes()
	local s = side()
	local list = nodesDB(s)
	local TM = C_TaxiMap
	if not list or type(TM) ~= "table" then return 0 end
	local maps, seen = {}, {}
	local function add(id)
		id = num(id)
		if id and id > 0 and not seen[id] then
			seen[id] = true
			maps[#maps + 1] = id
		end
	end
	add(call(GetTaxiMapID))
	add((W.MyPosition()))
	add(1414) -- Kalimdor
	add(1415) -- Eastern Kingdoms
	local have = 0
	for _ in pairs(list) do have = have + 1 end
	local added = 0
	for _, fname in ipairs({ "GetAllTaxiNodes", "GetTaxiNodesForMap" }) do
		local fn = TM[fname]
		for _, mapID in ipairs(maps) do
			local nodes = type(fn) == "function" and W.Plain((call(fn, mapID))) or nil
			if type(nodes) == "table" then
				for i, node in ipairs(nodes) do
					if i > 300 then break end
					node = W.Plain(node)
					if type(node) == "table" then
						local id, name = num(node.nodeID), str(node.name)
						local ns = nodeSide(node.faction)
						local k = name and town(s, nodePlace(name))
						if id and id > 0 and id % 1 == 0 and k and (not ns or ns == s) and list[id] ~= k
							and have + added < FLY.NODES_MAX then
							if list[id] == nil then added = added + 1 end
							list[id] = k
						end
					end
				end
			end
		end
	end
	return added
end

-- 2.2.x stored Enhanced Flight Map's times as tsrc "efm": they were real flights of this
-- account, so they stay, as "own" (once: W.db.flightsV = 3, written only when one moved).
local function migrate()
	local d0, store = W.db, flightDB()
	if type(d0) ~= "table" or not store or num(d0.flightsV) == 3 then return 0 end
	local n = 0
	for _, e in pairs(store) do
		if type(e) == "table" and e.tsrc == "efm" then
			e.tsrc, e.tn = "own", nil
			n = n + 1
		end
	end
	if n > 0 then
		d0.flightsV = 3
		FLY.ver = FLY.ver + 1
	end
	return n
end
FLY.Migrate = migrate

-- Core.FlightTimes (later in the TOC) watches the player's own flights and learns the map's
-- calibration; the flight map's events reach it from here (nothing else is registered).
local function times(fn, ...)
	local FT = W.Mod("Core.FlightTimes")
	local f = type(FT) == "table" and FT[fn]
	if type(f) == "function" then W.Safe("flight times", f, ...) end
end

-- The flight map opened. The real client (recorder, run 1) fired TAXIMAP_CLOSED but never TAXIMAP_OPENED, so the
-- map frame's OnShow (TaxiFrame, or FlightMapFrame once Blizzard_FlightMap loads) opens it too; the event always
-- counts, the OnShow only when no open is already running (the event came first, or the map is already open).
-- W.FlightMapShownAt: when a show-only open last ran (0 = never), so the Bird does not open twice for one map.
local mapOpen, hooked = false, {}
W.FlightMapShownAt = 0
local function mapOpened()
	W.Safe("flights", W.LearnFlights)
	W.Safe("flight nodes", W.LearnFlightNodes)
	times("MapOpened")
	W.Fire("FLIGHTS")
end
local function mapShown()
	if mapOpen then return end
	mapOpen = true
	W.FlightMapShownAt = GetTime()
	mapOpened()
	W.Fire("FLIGHTMAP_SHOWN")
end
local function hookMaps()
	for _, name in ipairs({ "TaxiFrame", "FlightMapFrame" }) do
		local f = _G[name]
		if type(f) == "table" and not hooked[f] and type(f.HookScript) == "function" then
			hooked[f] = true
			pcall(f.HookScript, f, "OnShow", function() W.Safe("flight map shown", mapShown) end)
			pcall(f.HookScript, f, "OnHide", function() mapOpen = false end)
			if type(f.IsShown) == "function" and W.Plain(call(f.IsShown, f)) == true then W.Safe("flight map shown", mapShown) end
		end
	end
end
W.On("TAXIMAP_OPENED", function()
	hookMaps()
	if W.FlightMapShownAt > 0 and GetTime() - W.FlightMapShownAt < 1 then return end -- (the show came first: already done)
	mapOpen = true
	mapOpened()
end)
W.On("TAXIMAP_CLOSED", function()
	mapOpen = false
	times("MapClosed")
end)
W.On("ADDON_LOADED", hookMaps) -- (FlightMapFrame arrives with Blizzard_FlightMap)
W.On("PLAYER_ENTERING_WORLD", hookMaps)
W.OnLogin(function()
	hookMaps()
	-- the stores exist from login (as in 2.2), then the old times move over
	flightDB()
	nodesDB(side())
	W.Safe("flight times", migrate)
end)

-- A lookup's places: to, from (nil: not at a place), mine (from is where the player stands),
-- and the stored entry; nil when there is nothing to look up.
local function pair(fromPlace, toPlace)
	local to = exact(toPlace or "") or (W.FindPlace and W.FindPlace(toPlace or ""))
	if not to or to.kind == "zone" then return nil end
	local from, mine
	if fromPlace ~= nil then
		from = exact(fromPlace) or (W.FindPlace and W.FindPlace(fromPlace))
		if not from then return nil end
	else
		local _, p = W.DestHere()
		from, mine = p, true
	end
	if from == to then return nil end
	local store, s = flightDB(), side()
	local e = (from and store and s) and store[s .. "|" .. W.NormPlace(from.name) .. "|" .. W.NormPlace(to.name)] or nil
	return to, from, mine, type(e) == "table" and e or nil
end

-- copper, exact (1), source ("table", "own" or "shared"), "boat" (a table route with a boat
-- or zeppelin on the way); nil when nothing is known. The game's full list price first; a
-- price seen at a flight master only where the table can't route the trip.
function W.FlightCost(fromPlace, toPlace)
	local to, from, mine, e = pair(fromPlace, toPlace)
	if not to then return nil end
	local c, via = FLY.tableCost(from, to, mine, side())
	if c then return c, 1, "table", via end
	if e and num(e.c) and (e.src ~= "shared" or okCopper(e.c)) then
		return num(e.c), 1, e.src == "shared" and "shared" or "own"
	end
	return nil
end

-- The price a flight master showed (own beats shared), whatever the table says: copper, source.
function W.FlightSeen(fromPlace, toPlace)
	local to, _, _, e = pair(fromPlace, toPlace)
	if not to or not e or not num(e.c) or (e.src == "shared" and not okCopper(e.c)) then return nil end
	return num(e.c), e.src == "shared" and "shared" or "own"
end

-- Seconds of flying from `from` to `to` (fromPlace nil: from where the player stands) and
-- where the number comes from: "own" (this account flew it), "shared" (another Wuber user
-- did), "est" (worked out by Core.FlightTimes from the game's splines: say "about"); nil when
-- nothing is known.
function W.FlightTime(fromPlace, toPlace)
	local to, from, mine, e = pair(fromPlace, toPlace)
	if not to then return nil end
	local t = e and okSecs(e.t) or nil
	if t then return t, e.tsrc == "shared" and "shared" or "own" end
	local FT = W.Mod("Core.FlightTimes")
	local est = type(FT) == "table" and type(FT.Estimate) == "function" and FT.Estimate(from, to, mine) or nil
	if est then return est, "est" end
	return nil
end
FLY.Pair = pair

-- What flying to `dest` costs from here: { cost, exact (1), from (place name or nil), source
-- ("own", "shared", "table"), shared (true: another Wuber user's flight master showed it),
-- via ("boat": a boat or zeppelin on the way) }, or nil.
function W.FlightInfo(dest)
	local okC, cost, ex, src, via = pcall(W.FlightCost, nil, dest)
	if not okC or not cost or cost <= 0 then return nil end
	local _, p = W.DestHere()
	return { cost = cost, exact = ex, from = p and p.name or nil, source = src, shared = src == "shared" or nil, via = via }
end
end -- flight costs

---------------------------------------------------------------------------
-- The game's own flight table (list prices; see W.FlightCost)
---------------------------------------------------------------------------
-- BEGIN FLIGHT TABLE (tools/build-flights.js)
-- WoW Forever 1.60.1's own flight tables (TaxiNodes, TaxiPath; wow.export): 68 nodes, 286 legs. Generated: do not edit by hand.
-- nodes[id] = { name, continent (0 Eastern Kingdoms, 1 Kalimdor...), world x, world y, sides ("H", "A", "HA") }
-- legs = { from, to, copper, from, to, copper, ... } (direct legs; a route costs the sum)
-- boats = { a, b, side, ... } (boats and zeppelins: free, both ways, that side only)
-- lens = { from, to, yards, delay, ... } (each direct leg along its spline (TaxiPathNode): 3D yards, stop seconds)
W.TAXI = { nodes = {
	[2] = { "Stormwind", 0, -8832.8, 478.6, "A" },
	[4] = { "Sentinel Hill", 0, -10628.9, 1036.7, "A" },
	[5] = { "Lakeshire", 0, -9429.1, -2231.4, "A" },
	[6] = { "Ironforge", 0, -4821.8, -1155.4, "A" },
	[7] = { "Menethil Harbor", 0, -3792.3, -783.3, "A" },
	[8] = { "Thelsamar", 0, -5421.9, -2930, "A" },
	[10] = { "The Sepulcher", 0, 478.9, 1536.6, "H" },
	[11] = { "Undercity", 0, 1568.6, 268, "H" },
	[12] = { "Darkshire", 0, -10515.5, -1261.7, "A" },
	[13] = { "Tarren Mill", 0, -0.1, -859.9, "H" },
	[14] = { "Southshore", 0, -711.5, -515.5, "A" },
	[16] = { "Refuge Pointe", 0, -1240.5, -2515.1, "A" },
	[17] = { "Hammerfall", 0, -916.3, -3496.9, "H" },
	[18] = { "Booty Bay", 0, -14444.3, 509.6, "H" },
	[19] = { "Booty Bay", 0, -14473, 464.1, "A" },
	[20] = { "Grom'gol", 0, -12414.2, 146.3, "H" },
	[21] = { "Kargath", 0, -6634, -2180.1, "H" },
	[22] = { "Thunder Bluff", 1, -1197.2, 29.7, "H" },
	[23] = { "Orgrimmar", 1, 1677.6, -4315.7, "H" },
	[25] = { "Crossroads", 1, -441.8, -2596.1, "H" },
	[26] = { "Auberdine", 1, 6341.4, 557.7, "A" },
	[27] = { "Rut'theran Village", 1, 8643.6, 841, "A" },
	[28] = { "Astranaar", 1, 2827.3, -289.2, "A" },
	[29] = { "Sun Rock Retreat", 1, 966.6, 1040.3, "H" },
	[30] = { "Freewind Post", 1, -5407.7, -2414.3, "H" },
	[31] = { "Thalanaar", 1, -4491.9, -775.9, "A" },
	[32] = { "Theramore", 1, -3825.4, -4516.6, "A" },
	[33] = { "Stonetalon Peak", 1, 2681.1, 1461.7, "A" },
	[37] = { "Nijel's Point", 1, 139.2, 1325.8, "A" },
	[38] = { "Shadowprey Village", 1, -1767.6, 3263.9, "H" },
	[39] = { "Gadgetzan", 1, -7224, -3734.6, "A" },
	[40] = { "Gadgetzan", 1, -7048.9, -3780.4, "H" },
	[41] = { "Feathermoon", 1, -4373.8, 3338.6, "A" },
	[42] = { "Camp Mojache", 1, -4419.9, 199.3, "H" },
	[43] = { "Aerie Peak", 0, 283.7, -2002.8, "A" },
	[44] = { "Valormok", 1, 3661.5, -4390.4, "H" },
	[45] = { "Nethergarde Keep", 0, -11112.2, -3435.7, "A" },
	[48] = { "Bloodvenom Post", 1, 5068.4, -337.2, "H" },
	[49] = { "Moonglade", 1, 7458.5, -2487.2, "A" },
	[52] = { "Everlook", 1, 6799.2, -4742.4, "A" },
	[53] = { "Everlook", 1, 6813.1, -4611.1, "H" },
	[55] = { "Brackenwall Village", 1, -3147.4, -2842.2, "H" },
	[56] = { "Stonard", 0, -10457, -3279.2, "H" },
	[58] = { "Zoram'gar Outpost", 1, 3374.7, 997, "H" },
	[61] = { "Splintertree Post", 1, 2302.4, -2524.6, "H" },
	[64] = { "Talrendis Point", 1, 2722, -3880.6, "A" },
	[65] = { "Talonbranch Glade", 1, 6205.9, -1949.6, "A" },
	[66] = { "Chillwind Camp", 0, 931.3, -1430.1, "A" },
	[67] = { "Light's Hope Chapel", 0, 2271.1, -5340.8, "A" },
	[68] = { "Light's Hope Chapel", 0, 2327.4, -5286.9, "H" },
	[69] = { "Moonglade", 1, 7470.4, -2123.4, "H" },
	[70] = { "Flame Crest", 0, -7504, -2187.5, "H" },
	[71] = { "Morgan's Vigil", 0, -8364.6, -2738.4, "A" },
	[72] = { "Cenarion Hold", 1, -6811.4, 836.7, "H" },
	[73] = { "Cenarion Hold", 1, -6761.8, 772, "A" },
	[74] = { "Thorium Point", 0, -6552.6, -1168.3, "A" },
	[75] = { "Thorium Point", 0, -6554.9, -1100.1, "H" },
	[76] = { "Revantusk Village", 0, -635.3, -4720.5, "H" },
	[77] = { "Camp Taurajo", 1, -2380.7, -1882.7, "H" },
	[79] = { "Marshal's Refuge", 1, -6113.8, -1142.7, "HA" },
	[80] = { "Ratchet", 1, -894.6, -3773, "HA" },
	[559] = { "Summit of Eternity", 1, 5283.2, -3306.7, "HA" },
	[3203] = { "Rog'mar", 0, -7923.7, -4783, "H" },
	[3205] = { "Tidegear Coast", 0, -4375.7, 864.8, "A" },
	[3242] = { "Tainted Foothills", 1, 4393.5, -2836.4, "HA" },
	[3274] = { "Powderfuse Port", 0, -8157.2, -5724.7, "H" },
	[3275] = { "Powderfuse Port", 0, -8180, -5616.3, "A" },
	[3276] = { "Farholde Keep", 0, -9104.1, -4830.5, "A" },
}, legs = {
	2, 4, 110, 2, 5, 210, 2, 6, 50, 2, 12, 330, 2, 19, 630, 2, 45, 830, 2, 71, 830, 4, 2, 110,
	4, 5, 210, 4, 12, 330, 4, 19, 630, 5, 2, 210, 5, 4, 110, 5, 12, 330, 5, 71, 830, 5, 3276, 630,
	6, 2, 50, 6, 7, 330, 6, 8, 110, 6, 14, 330, 6, 16, 530, 6, 43, 730, 6, 66, 1020, 6, 67, 1020,
	6, 74, 830, 7, 6, 330, 7, 8, 110, 7, 14, 330, 7, 16, 530, 8, 6, 110, 8, 7, 330, 8, 16, 530,
	8, 3276, 630, 10, 11, 110, 10, 13, 330, 11, 10, 110, 11, 13, 330, 11, 17, 530, 11, 21, 630, 11, 68, 1020,
	11, 76, 730, 12, 2, 330, 12, 4, 110, 12, 5, 210, 12, 19, 630, 12, 45, 830, 13, 10, 110, 13, 11, 330,
	13, 17, 530, 13, 76, 730, 14, 6, 330, 14, 7, 330, 14, 16, 530, 14, 43, 730, 14, 66, 830, 16, 6, 530,
	16, 7, 330, 16, 8, 110, 16, 14, 330, 16, 43, 730, 17, 11, 530, 17, 13, 330, 17, 21, 630, 17, 76, 730,
	17, 3203, 830, 18, 20, 630, 18, 21, 630, 18, 56, 630, 19, 2, 630, 19, 4, 530, 19, 12, 330, 20, 18, 630,
	20, 21, 630, 20, 56, 630, 21, 11, 630, 21, 17, 630, 21, 18, 630, 21, 20, 530, 21, 56, 710, 21, 70, 830,
	21, 75, 830, 21, 3203, 630, 22, 23, 50, 22, 25, 110, 22, 29, 210, 22, 30, 430, 22, 38, 530, 22, 40, 730,
	22, 42, 730, 22, 44, 830, 22, 55, 630, 22, 77, 110, 23, 22, 50, 23, 25, 110, 23, 40, 730, 23, 44, 830,
	23, 48, 830, 23, 53, 1020, 23, 55, 630, 23, 61, 530, 25, 22, 110, 25, 23, 110, 25, 29, 210, 25, 30, 430,
	25, 40, 730, 25, 42, 730, 25, 44, 830, 25, 48, 930, 25, 55, 630, 25, 58, 330, 25, 61, 530, 25, 77, 110,
	25, 80, 110, 26, 27, 0, 26, 28, 330, 26, 32, 630, 26, 33, 330, 26, 37, 530, 26, 41, 730, 26, 49, 830,
	26, 64, 730, 26, 65, 730, 27, 26, 0, 28, 26, 330, 28, 33, 330, 28, 64, 730, 29, 22, 210, 29, 25, 210,
	29, 38, 530, 30, 22, 430, 30, 25, 430, 30, 40, 730, 30, 42, 730, 30, 77, 430, 31, 32, 730, 31, 39, 730,
	31, 41, 630, 32, 26, 630, 32, 31, 430, 32, 37, 530, 32, 39, 730, 32, 64, 730, 32, 80, 110, 33, 26, 330,
	33, 28, 330, 33, 37, 530, 37, 26, 530, 37, 32, 530, 37, 33, 330, 37, 41, 730, 38, 22, 530, 38, 29, 210,
	38, 42, 730, 39, 31, 430, 39, 32, 630, 39, 73, 1020, 39, 79, 830, 40, 22, 730, 40, 23, 730, 40, 25, 730,
	40, 30, 430, 40, 42, 630, 40, 55, 630, 40, 72, 1020, 40, 79, 830, 41, 26, 730, 41, 31, 430, 41, 37, 730,
	41, 73, 1030, 42, 22, 730, 42, 25, 730, 42, 30, 430, 42, 38, 730, 42, 40, 630, 42, 72, 1030, 43, 6, 730,
	43, 14, 330, 43, 16, 530, 43, 66, 1020, 43, 67, 1020, 44, 22, 830, 44, 23, 830, 44, 25, 830, 44, 48, 930,
	44, 53, 1020, 44, 61, 530, 45, 2, 830, 45, 12, 330, 45, 71, 830, 48, 23, 930, 48, 25, 930, 48, 44, 830,
	48, 53, 1020, 48, 69, 830, 49, 26, 830, 49, 52, 1020, 49, 65, 730, 52, 49, 830, 52, 64, 730, 52, 65, 730,
	52, 3242, 330, 53, 23, 1020, 53, 44, 830, 53, 48, 930, 53, 69, 830, 53, 3242, 330, 55, 22, 630, 55, 23, 630,
	55, 25, 630, 55, 40, 730, 56, 18, 630, 56, 20, 630, 56, 21, 630, 56, 70, 830, 56, 3203, 630, 58, 25, 110,
	58, 61, 530, 61, 23, 530, 61, 25, 530, 61, 44, 830, 61, 58, 330, 64, 26, 730, 64, 28, 330, 64, 32, 630,
	64, 52, 1030, 64, 65, 730, 64, 80, 110, 65, 26, 730, 65, 49, 1020, 65, 52, 1020, 65, 64, 730, 66, 6, 1020,
	66, 14, 330, 66, 43, 730, 66, 67, 1020, 67, 6, 1020, 67, 43, 730, 67, 66, 1020, 68, 11, 1020, 68, 76, 730,
	69, 48, 930, 69, 53, 1020, 70, 21, 830, 70, 56, 830, 70, 75, 830, 70, 3203, 630, 71, 2, 830, 71, 5, 210,
	71, 45, 830, 71, 74, 830, 71, 3276, 630, 72, 40, 730, 72, 42, 730, 72, 79, 830, 73, 39, 730, 73, 41, 730,
	73, 79, 830, 74, 6, 830, 74, 71, 830, 75, 21, 630, 75, 70, 830, 76, 11, 730, 76, 13, 330, 76, 17, 530,
	76, 68, 1030, 77, 22, 110, 77, 25, 110, 77, 30, 430, 79, 39, 730, 79, 40, 730, 79, 72, 1030, 79, 73, 1030,
	80, 25, 110, 80, 32, 630, 80, 64, 730, 559, 3242, 510, 3203, 17, 830, 3203, 21, 630, 3203, 56, 630, 3203, 70, 630,
	3242, 52, 1020, 3242, 53, 1020, 3242, 559, 510, 3276, 5, 630, 3276, 8, 630, 3276, 71, 630,
}, boats = {
	23, 11, "H", -- zeppelin Orgrimmar - Undercity
	23, 20, "H", -- zeppelin Orgrimmar - Grom'gol
	11, 20, "H", -- zeppelin Undercity - Grom'gol
	80, 18, "H", -- boat Ratchet - Booty Bay
	80, 19, "A", -- boat Ratchet - Booty Bay
	7, 32, "A", -- boat Menethil Harbor - Theramore
	7, 26, "A", -- boat Menethil Harbor - Auberdine
	26, 27, "A", -- boat Auberdine - Rut'theran Village
}, lens = {
	2, 4, 2329, 0, 2, 5, 3380, 0, 2, 6, 7757, 0, 2, 12, 3480, 0,
	2, 19, 7318, 0, 2, 45, 5282, 0, 2, 71, 4706, 0, 4, 2, 2443, 0,
	4, 5, 3890, 0, 4, 12, 2897, 0, 4, 19, 5561, 0, 5, 2, 3374, 0,
	5, 4, 4003, 0, 5, 12, 1812, 0, 5, 71, 1825, 0, 5, 3276, 3962, 0,
	6, 2, 6310, 0, 6, 7, 3861, 0, 6, 8, 3037, 0, 6, 14, 7938, 0,
	6, 16, 7585, 0, 6, 43, 8941, 0, 6, 66, 8816, 0, 6, 67, 10440, 0,
	6, 74, 2594, 0, 7, 6, 2658, 0, 7, 8, 4877, 0, 7, 14, 3215, 0,
	7, 16, 3388, 0, 8, 6, 3266, 0, 8, 7, 4564, 0, 8, 16, 4902, 0,
	8, 3276, 5531, 0, 10, 11, 3345, 0, 10, 13, 2868, 0, 11, 10, 3180, 0,
	11, 13, 4222, 0, 11, 17, 9014, 0, 11, 21, 14837, 0, 11, 68, 7849, 0,
	11, 76, 8530, 0, 12, 2, 2629, 0, 12, 4, 2794, 0, 12, 5, 1787, 0,
	12, 19, 5135, 0, 12, 45, 2903, 0, 13, 10, 2989, 0, 13, 11, 4172, 0,
	13, 17, 3532, 0, 13, 76, 5840, 0, 14, 6, 6174, 0, 14, 7, 3304, 0,
	14, 16, 2214, 0, 14, 43, 2139, 0, 14, 66, 2418, 0, 16, 6, 8109, 0,
	16, 7, 3776, 0, 16, 8, 5113, 0, 16, 14, 2596, 0, 16, 43, 2152, 0,
	17, 11, 7763, 0, 17, 13, 3493, 0, 17, 21, 7760, 0, 17, 76, 2705, 0,
	17, 3203, 9767, 0, 18, 20, 3047, 0, 18, 21, 12190, 0, 18, 56, 7986, 0,
	19, 2, 6585, 0, 19, 4, 5439, 0, 19, 12, 5242, 0, 20, 18, 2422, 0,
	20, 21, 9802, 0, 20, 56, 6151, 0, 21, 11, 14918, 0, 21, 17, 7881, 0,
	21, 18, 12493, 0, 21, 20, 9376, 0, 21, 56, 8424, 0, 21, 70, 2593, 0,
	21, 75, 1682, 0, 21, 3203, 3821, 0, 22, 23, 6213, 0, 22, 25, 4752, 0,
	22, 29, 5439, 0, 22, 30, 6113, 0, 22, 38, 4752, 0, 22, 40, 8693, 0,
	22, 42, 7563, 0, 22, 44, 8070, 0, 22, 55, 7149, 0, 22, 77, 2599, 0,
	23, 22, 6745, 0, 23, 25, 3304, 0, 23, 40, 12500, 0, 23, 44, 2965, 0,
	23, 48, 7558, 0, 23, 53, 9582, 0, 23, 55, 6853, 0, 23, 61, 2680, 0,
	25, 22, 5461, 0, 25, 23, 4252, 0, 25, 29, 4495, 0, 25, 30, 5532, 0,
	25, 40, 9093, 0, 25, 42, 7547, 0, 25, 44, 5051, 0, 25, 48, 7603, 0,
	25, 55, 4878, 0, 25, 58, 6902, 0, 25, 61, 4871, 0, 25, 77, 2705, 0,
	25, 80, 1545, 0, 26, 27, 2525, 0, 26, 28, 5270, 0, 26, 32, 20225, 0,
	26, 33, 5432, 0, 26, 37, 8723, 0, 26, 41, 14168, 0, 26, 49, 4525, 0,
	26, 64, 8981, 0, 26, 65, 5682, 0, 27, 26, 2551, 0, 28, 26, 4426, 0,
	28, 33, 4599, 0, 28, 64, 4428, 0, 29, 22, 5227, 0, 29, 25, 4477, 0,
	29, 38, 4297, 0, 30, 22, 6764, 0, 30, 25, 5810, 0, 30, 40, 2782, 0,
	30, 42, 3685, 0, 30, 77, 4111, 0, 31, 32, 4780, 0, 31, 39, 5122, 0,
	31, 41, 5335, 0, 32, 26, 18633, 0, 32, 31, 4887, 0, 32, 37, 10017, 0,
	32, 39, 4694, 0, 32, 64, 7052, 0, 32, 80, 3446, 0, 33, 26, 5304, 0,
	33, 28, 4613, 0, 33, 37, 3803, 0, 37, 26, 8458, 0, 37, 32, 9202, 0,
	37, 33, 3581, 0, 37, 41, 6949, 0, 38, 22, 5331, 0, 38, 29, 5966, 0,
	38, 42, 5873, 0, 39, 31, 5304, 0, 39, 32, 4606, 0, 39, 73, 5907, 0,
	39, 79, 3115, 0, 40, 22, 9107, 0, 40, 23, 10495, 0, 40, 25, 9008, 0,
	40, 30, 2602, 0, 40, 42, 5973, 0, 40, 55, 6647, 0, 40, 72, 6976, 0,
	40, 79, 3218, 0, 41, 26, 14014, 0, 41, 31, 4635, 0, 41, 37, 6797, 0,
	41, 73, 4774, 0, 42, 22, 7777, 0, 42, 25, 7915, 0, 42, 30, 3215, 0,
	42, 38, 6016, 0, 42, 40, 6024, 0, 42, 72, 3897, 0, 43, 6, 7658, 0,
	43, 14, 2039, 0, 43, 16, 2267, 0, 43, 66, 1590, 0, 43, 67, 4922, 0,
	44, 22, 7700, 0, 44, 23, 3622, 0, 44, 25, 5163, 0, 44, 48, 6955, 0,
	44, 53, 3905, 0, 44, 61, 2795, 0, 45, 2, 5672, 0, 45, 12, 2748, 0,
	45, 71, 6251, 0, 48, 23, 7747, 0, 48, 25, 7227, 0, 48, 44, 7221, 0,
	48, 53, 5700, 0, 48, 69, 4947, 0, 49, 26, 4247, 0, 49, 52, 3900, 0,
	49, 65, 1840, 0, 52, 49, 3639, 0, 52, 64, 5265, 0, 52, 65, 3670, 0,
	52, 3242, 4057, 0, 53, 23, 9115, 0, 53, 44, 4078, 0, 53, 48, 5853, 0,
	53, 69, 4016, 0, 53, 3242, 4078, 0, 55, 22, 6729, 0, 55, 23, 6496, 0,
	55, 25, 4848, 0, 55, 40, 6660, 0, 56, 18, 7798, 0, 56, 20, 5646, 0,
	56, 21, 8555, 0, 56, 70, 5916, 0, 56, 3203, 5085, 0, 58, 25, 6827, 0,
	58, 61, 5013, 0, 61, 23, 2869, 0, 61, 25, 4806, 0, 61, 44, 2870, 0,
	61, 58, 4995, 0, 64, 26, 9038, 0, 64, 28, 4578, 0, 64, 32, 7242, 0,
	64, 52, 5355, 0, 64, 65, 8502, 0, 64, 80, 4062, 0, 65, 26, 5622, 0,
	65, 49, 2005, 0, 65, 52, 3601, 0, 65, 64, 8465, 0, 66, 6, 7782, 0,
	66, 14, 2559, 0, 66, 43, 1958, 0, 66, 67, 4390, 0, 67, 6, 11024, 0,
	67, 43, 4871, 0, 67, 66, 4484, 0, 68, 11, 7837, 0, 68, 76, 4232, 0,
	69, 48, 4713, 0, 69, 53, 4256, 0, 70, 21, 2994, 0, 70, 56, 6376, 0,
	70, 75, 2154, 0, 70, 3203, 4113, 0, 71, 2, 4528, 0, 71, 5, 1884, 0,
	71, 45, 6288, 0, 71, 74, 3090, 0, 71, 3276, 3936, 0, 72, 40, 7224, 0,
	72, 42, 3895, 0, 72, 79, 2896, 0, 73, 39, 5652, 0, 73, 41, 5239, 0,
	73, 79, 2745, 0, 74, 6, 2802, 0, 74, 71, 2865, 0, 75, 21, 2090, 0,
	75, 70, 2297, 0, 76, 11, 8538, 0, 76, 13, 4767, 0, 76, 17, 2785, 0,
	76, 68, 4159, 0, 77, 22, 3407, 0, 77, 25, 2380, 0, 77, 30, 3750, 0,
	79, 39, 3100, 0, 79, 40, 3396, 0, 79, 72, 3003, 0, 79, 73, 2823, 0,
	80, 25, 2041, 0, 80, 32, 3149, 0, 80, 64, 3960, 0, 559, 3242, 1866, 0,
	3203, 17, 9845, 0, 3203, 21, 3607, 0, 3203, 56, 4624, 0, 3203, 70, 3993, 0,
	3242, 52, 3745, 0, 3242, 53, 3967, 0, 3242, 559, 1849, 0, 3276, 5, 3917, 0,
	3276, 8, 5193, 0, 3276, 71, 3676, 0,
} }
-- END FLIGHT TABLE
