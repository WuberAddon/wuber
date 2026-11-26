-- tests/lib/fakes8.lua: game fakes for round 8 (Wuber 2.3.0, SPEC7 section 8, the lead's row).
-- Loaded once by tests/harness.lua (H.fakes8); F.api runs for every client while its game API
-- is built. Nothing here creates a frame, fires an event or schedules a timer unless a test calls
-- one of the World/Client helpers below, so the behaviour transcript of every older test stays
-- byte-identical (the addon of 2.2.x reads none of these names).
--
-- In every client (always there):
--   bit                     the WoW bit library (band bor bxor bnot lshift rshift arshift mod), 32-bit,
--                           pure Lua. A client without it: opts.prepare = function(env, c) c.api.bit = nil end
--   COMBATLOG_OBJECT_*      the flag constants (TYPE_PLAYER 0x400, REACTION_HOSTILE 0x40, ...)
--   (round 12: the combat log itself is forbidden in this client, tools/forbidden.lua: the
--   harness raises ADDON_ACTION_FORBIDDEN on its event and its reader; there is no fake of it)
--   UnitIsEnemy(a, b), UnitIsFriend(a, b)  players: different / same faction; an NPC (World:addNpc):
--                           its `hostile` flag. UnitIsPlayer is false and UnitGUID "Creature-..." for NPCs
--   UnitCanAttack(a, b)     enemies (as UnitIsEnemy) who can fight: an NPC always; two players unless
--                           either has p.pvp == false (unflagged on a PvE realm)
--   GetZonePVPInfo()        NOT in the real client (fact api.getzonepvpinfo: the test addon's check
--                           read "GetZonePVPInfo is missing"), so not here by default. A world made with
--                           H.NewWorld({ zonePvpInfo = true }) has the old fake one: -> pvpType, isFFA,
--                           faction: the player's override (p.pvpZone, a string or { type, ffa, faction }),
--                           else World:setZonePvp's entry for the subzone, then the zone; else nil
--   TaxiNodePosition(i)     -> x, y (0..1) of node i of the open flight map (nodes[i].x / .y)
--   TakeTaxiNode(slot)      the player picks a destination: the map closes (TAXIMAP_CLOSED), and
--                           after the take-off delay (World:openTaxiMap opts.takeoff, default 1 s)
--                           UnitOnTaxi("player") is true and PLAYER_CONTROL_LOST fires.
--                           hooksecurefunc("TakeTaxiNode", fn) works (the hook runs after it)
--   UnitOnTaxi(unit)        true while that player is in the air
--   CloseTaxiMap()          closes the open flight map (TAXIMAP_CLOSED)
--   C_SummonInfo.GetSummonConfirmSummoner()  the summoner's name (World:summon opts.shownBy can
--                           make it name someone else: a forged or mismatched summon)
--
-- World helpers (w = the World, c = a client):
--   w:openTaxiMap(c, nodes, opts)   a flight master's map opens: nodes = { { name, type =
--       "CURRENT"|"REACHABLE"|"NONE", cost, x, y }, ... } (World:openTaxi's nodes plus map x, y), or
--       H.realTaxi(continent, town, { known = { towns } }): the real client's whole continent map.
--       Makes the game's map frame the first time (opts.frame: "TaxiFrame" (default, 603 x 638 at
--       TOPLEFT 16,-118 of UIParent as measured on the real client; opts.frameSize = "old": the former
--       384 x 512 at 16,-116), "FlightMapFrame" (618 x 482, never seen on this client), or false for
--       none), shows it, then TAXIMAP_OPENED. opts.takeoff = seconds from TakeTaxiNode to take-off.
--   C_TaxiMap.GetAllTaxiNodes(uiMapID)  the open map's nodes with ids ({ nodeID, name, slotIndex })
--       (The real client always has its TaxiFrame, hidden; here it exists from the first open.)
--   w:closeTaxiMap(c)               hides the map frame, TAXIMAP_CLOSED
--   w:takeTaxi(c, slot)             the player clicks node `slot` (TakeTaxiNode through the client's
--                                   globals, so addon hooks run; errors land in w.errors)
--   w:landTaxi(c, spot)             lands: the player moves to `spot` (H.SPOTS name or table),
--                                   ZONE_CHANGED_NEW_AREA + ZONE_CHANGED when the zone changed,
--                                   then UnitOnTaxi false and PLAYER_CONTROL_GAINED. w:landTaxi(c, spot,
--                                   lag) (opt-in): PLAYER_CONTROL_GAINED comes while UnitOnTaxi is still
--                                   true, and the flag drops `lag` seconds later with no event
--   w:fly(c, slot, secs, spot, opts) take, then land `secs` after take-off (run w:advance to play
--       it). opts.loadingScreen = seconds after take-off: a loading screen mid-flight
--       (LOADING_SCREEN_ENABLED, PLAYER_ENTERING_WORLD(false, false), LOADING_SCREEN_DISABLED);
--       opts.logout = seconds: PLAYER_LOGOUT mid-flight (the client stays alive); opts.flagLag =
--       seconds: the landing as w:landTaxi(c, spot, lag) (off by default)
--   w:combatLog(...)                retired in round 12 (it errors): the combat log is forbidden in
--       this client; a fight as an addon can see it is World:pvpFight (tests/harness.lua)
--   w:addNpc(name, opts)            an NPC (a bot flagged npc): opts.spot, opts.hostile (default
--       true), opts.faction (default "Monster"). c:showPlate(name) shows its nameplate as usual
--   w:setZonePvp(zone, pvpType, faction, ffa)  GetZonePVPInfo's answer (zonePvpInfo worlds) in that zone or subzone
--       (pvpType nil clears it). Fire ZONE_CHANGED yourself if the addon should notice now
--   w:summon(caster, target, { shownBy = "Some Name" })  (tests/harness.lua) the summon popup
--       names `shownBy` instead of the real caster
-- Events added to H.KNOWN_EVENTS: none (round 12: COMBAT_LOG_EVENT_UNFILTERED is forbidden).

return function(H, World, Client)
	local F = {}
	local S = H.state

	---------------------------------------------------------------------------
	-- bit (32-bit, as WoW's BitLib: results are unsigned 0..2^32-1, arshift keeps the sign bit)
	---------------------------------------------------------------------------

	local TWO32 = 4294967296
	local function u32(x)
		x = tonumber(x) or 0
		x = x >= 0 and math.floor(x) or math.ceil(x)
		return x % TWO32
	end
	local function bitop(a, b, fn)
		a, b = u32(a), u32(b)
		local out, place = 0, 1
		for _ = 1, 32 do
			local x, y = a % 2, b % 2
			if fn(x, y) then out = out + place end
			a, b, place = (a - x) / 2, (b - y) / 2, place * 2
		end
		return out
	end
	local bit = {}
	function bit.band(a, b, ...)
		local r = bitop(a, b == nil and TWO32 - 1 or b, function(x, y) return x == 1 and y == 1 end)
		if ... ~= nil then return bit.band(r, ...) end
		return r
	end
	function bit.bor(a, b, ...)
		local r = bitop(a, b or 0, function(x, y) return x == 1 or y == 1 end)
		if ... ~= nil then return bit.bor(r, ...) end
		return r
	end
	function bit.bxor(a, b, ...)
		local r = bitop(a, b or 0, function(x, y) return x ~= y end)
		if ... ~= nil then return bit.bxor(r, ...) end
		return r
	end
	function bit.bnot(a) return TWO32 - 1 - u32(a) end
	function bit.lshift(a, n)
		n = math.floor(tonumber(n) or 0)
		if n >= 32 then return 0 end
		return (u32(a) * 2 ^ n) % TWO32
	end
	function bit.rshift(a, n)
		n = math.floor(tonumber(n) or 0)
		if n >= 32 then return 0 end
		return math.floor(u32(a) / 2 ^ n)
	end
	function bit.arshift(a, n)
		a = u32(a)
		n = math.floor(tonumber(n) or 0)
		local neg = a >= 2147483648
		if n >= 32 then return neg and TWO32 - 1 or 0 end
		local r = math.floor(a / 2 ^ n)
		if neg then r = r + (TWO32 - 2 ^ (32 - n)) end
		return r
	end
	function bit.mod(a, b) return math.fmod(tonumber(a) or 0, tonumber(b) or 1) end
	F.bit = bit

	---------------------------------------------------------------------------
	-- Combat log flags
	---------------------------------------------------------------------------

	local FLAGS = {
		COMBATLOG_OBJECT_AFFILIATION_MINE = 0x1, COMBATLOG_OBJECT_AFFILIATION_PARTY = 0x2,
		COMBATLOG_OBJECT_AFFILIATION_RAID = 0x4, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER = 0x8,
		COMBATLOG_OBJECT_AFFILIATION_MASK = 0xF,
		COMBATLOG_OBJECT_REACTION_FRIENDLY = 0x10, COMBATLOG_OBJECT_REACTION_NEUTRAL = 0x20,
		COMBATLOG_OBJECT_REACTION_HOSTILE = 0x40, COMBATLOG_OBJECT_REACTION_MASK = 0xF0,
		COMBATLOG_OBJECT_CONTROL_PLAYER = 0x100, COMBATLOG_OBJECT_CONTROL_NPC = 0x200,
		COMBATLOG_OBJECT_CONTROL_MASK = 0x300,
		COMBATLOG_OBJECT_TYPE_PLAYER = 0x400, COMBATLOG_OBJECT_TYPE_NPC = 0x800, COMBATLOG_OBJECT_TYPE_PET = 0x1000,
		COMBATLOG_OBJECT_TYPE_GUARDIAN = 0x2000, COMBATLOG_OBJECT_TYPE_OBJECT = 0x4000, COMBATLOG_OBJECT_TYPE_MASK = 0xFC00,
		COMBATLOG_OBJECT_TARGET = 0x10000, COMBATLOG_OBJECT_FOCUS = 0x20000, COMBATLOG_OBJECT_NONE = 0x80000000,
	}
	F.FLAGS = FLAGS

	local function faction(u) return u.faction or "Horde" end

	local function guid(u)
		if not u then return "" end
		if u.npc then return "Creature-0-1-1-1-" .. (u.npcId or 1) .. "-0000000001" end
		return "Player-1-" .. H.key(u.name)
	end

	---------------------------------------------------------------------------
	-- The API of one client (called while tests/harness.lua builds it; env == api then)
	---------------------------------------------------------------------------

	function F.api(api, client, p, w, sec)
		api.bit = bit
		for k, v in pairs(FLAGS) do api[k] = v end

		-- NPCs (World:addNpc) are not players; enemies are the other faction (or a hostile NPC)
		api.UnitIsPlayer = function(unit) local u = client:unit(unit) return u ~= nil and not u.npc end
		api.UnitGUID = function(unit) local u = client:unit(unit) return u and guid(u) or nil end
		local function enemies(x, y)
			if x.npc or y.npc then
				if x.npc and y.npc then return false end
				local npc = x.npc and x or y
				return npc.hostile ~= false
			end
			return faction(x) ~= faction(y)
		end
		api.UnitIsEnemy = function(a, b)
			local x, y = client:unit(a), client:unit(b)
			if not x or not y then return false end
			return enemies(x, y)
		end
		-- can x and y fight? enemies, and for two players both PvP-flagged (p.pvp == false: an
		-- unflagged player on a PvE realm, who can't attack or be attacked)
		api.UnitCanAttack = function(a, b)
			local x, y = client:unit(a), client:unit(b)
			if not x or not y or x == y or not enemies(x, y) then return false end
			if x.npc or y.npc then return true end
			return x.pvp ~= false and y.pvp ~= false
		end
		api.UnitIsFriend = function(a, b)
			local x, y = client:unit(a), client:unit(b)
			if not x or not y then return false end
			if x.npc or y.npc then return (x.npc and x or y).hostile == false end
			return faction(x) == faction(y)
		end

		-- (fact api.getzonepvpinfo) only in a world that asks for the old fake one
		if w.zonePvpInfo then api.GetZonePVPInfo = function()
			local z = p.pvpZone
			local zones = w.zonePvp
			if z == nil and zones then z = (p.subZone ~= "" and zones[p.subZone]) or zones[p.zone] end
			if z == nil then return nil end
			if type(z) == "string" then return z, false, nil end
			return z.type, z.ffa or false, z.faction
		end end

		-- the flight map and flights
		api.TaxiNodePosition = function(i)
			local t = client.taxi
			local n = t and t.open and t.nodes[i]
			if not n then return 0, 0 end
			return n.x or 0, n.y or 0
		end
		api.UnitOnTaxi = function(unit) local u = client:unit(unit) return u ~= nil and u.onTaxi == true end
		-- C_TaxiMap (the real client has it: WuberDB.flightNodes.H holds 27 node ids read from it): the
		-- open map's nodes when they carry ids (H.realTaxi's lists do) and uiMapID is their continent;
		-- else an empty list. Hand-made node lists have no ids, so older tests see nothing new.
		api.C_TaxiMap = {
			GetAllTaxiNodes = function(uiMapID)
				local t = client.taxi
				local out = {}
				if not (t and t.open and t.nodes and t.nodes.mapID and t.nodes.mapID == uiMapID) then return out end
				for i, n in ipairs(t.nodes) do
					if n.nodeID then out[#out + 1] = { nodeID = n.nodeID, name = n.name, slotIndex = i } end
				end
				return out
			end,
		}
		api.CloseTaxiMap = function() w:closeTaxiMap(client) end
		api.TakeTaxiNode = function(slot)
			local t = client.taxi
			if not (t and t.open) then return end
			local node = t.nodes[slot]
			if not node then return end
			local from
			for _, n in ipairs(t.nodes) do if n.type == "CURRENT" then from = n.name end end
			local flight = { slot = slot, from = from, to = node.name, clickAt = w.time }
			t.flight = flight
			w:closeTaxiMap(client)
			w:after(t.takeoff or 1, function()
				if t.flight ~= flight then return end
				flight.startAt = w.time
				p.onTaxi = true
				client:fire("PLAYER_CONTROL_LOST")
			end, client, "taxi take-off")
		end
	end

	---------------------------------------------------------------------------
	-- World helpers
	---------------------------------------------------------------------------

	-- TaxiFrame is the one the real client showed (fact taxi.frame); its size and place are measured on
	-- two screenshots of 21 Nov (tests/fixtures/rec/lab-taxi.lua: about 603 x 638 at 16, -118, an
	-- estimate to about 2 percent, to be replaced by the recorder's exact numbers). opts.frameSize = "old":
	-- the former fake TaxiFrame, 384 x 512 at 16, -116. FlightMapFrame was never seen on this client.
	local FRAMES = {
		TaxiFrame = { w = 603, h = 638, x = 16, y = -118 },
		TaxiFrameOld = { w = 384, h = 512, x = 16, y = -116 },
		FlightMapFrame = { w = 618, h = 482, x = 16, y = -116 },
	}
	F.TAXI_FRAMES = FRAMES

	-- The real flight maps (tests/fixtures/rec/lab-taxi.lua), loaded on first use.
	local here = (debug.getinfo(1, "S").source or ""):gsub("^@", ""):gsub("\\", "/")
	local fixturesDir = (here:match("^(.*)/lib/[^/]*$") or "tests") .. "/fixtures/rec/"
	local taxiData
	function H.realTaxiData()
		taxiData = taxiData or dofile(fixturesDir .. "lab-taxi.lua")
		return taxiData
	end

	-- H.realTaxi(continent, here, opts) -> the nodes a Horde character standing at the flight master of
	-- `here` (a town: "Thunder Bluff") sees on the real client, for w:openTaxiMap: EVERY node of the
	-- continent ("Kalimdor": 22, "Eastern Kingdoms": 13 of the recorded 14), as the game spells it, in id
	-- order (the real order is not recorded), with the recorded TaxiNodePosition (0, 0 when there is
	-- none). `here` is CURRENT, the towns in opts.known REACHABLE, every other node "NONE" (the real word
	-- for those is not recorded). A REACHABLE node costs the recorded TaxiNodeCost (some are 0), else
	-- opts.costs[town], else 0. The list carries mapID (the continent) and nodeID per node, so
	-- C_TaxiMap.GetAllTaxiNodes answers for it.
	function H.realTaxi(continent, hereTown, opts)
		opts = opts or {}
		local data = H.realTaxiData()
		local cont = data[continent]
		if not cont then error("H.realTaxi: no recorded flight map for " .. tostring(continent), 2) end
		local known = {}
		for _, t in ipairs(opts.known or {}) do known[t] = true end
		local costs = data.costs[hereTown] or {}
		local list, found = { mapID = cont.mapID, continent = continent }, false
		for _, n in ipairs(cont.nodes) do
			local town = n.name:match("^([^,]+)") or n.name
			local node = { name = n.name, nodeID = n.id, x = n.x, y = n.y, type = "NONE" }
			if town == hereTown then
				node.type, node.cost, found = "CURRENT", 0, true
			elseif known[town] then
				node.type = "REACHABLE"
				node.cost = costs[town] or (opts.costs and opts.costs[town]) or 0
			end
			list[#list + 1] = node
		end
		if not found then error("H.realTaxi: no node " .. tostring(hereTown) .. " on " .. continent, 2) end
		return list
	end

	function World:openTaxiMap(client, nodes, opts)
		opts = opts or {}
		local t = client.taxi or {}
		client.taxi = t
		t.nodes, t.open, t.takeoff = nodes, true, opts.takeoff
		local fname = opts.frame
		if fname == nil then fname = "TaxiFrame" end
		if fname then
			local f = rawget(client.env, fname)
			if not f then
				local g = (fname == "TaxiFrame" and opts.frameSize == "old" and FRAMES.TaxiFrameOld) or FRAMES[fname] or FRAMES.TaxiFrame
				f = H.createFrame(client, "Frame", fname, client.env.UIParent)
				f:SetSize(g.w, g.h)
				f:SetPoint("TOPLEFT", client.env.UIParent, "TOPLEFT", g.x, g.y)
				f:SetFrameStrata("HIGH")
				S[f].gameFrame = true
			end
			t.frame = f
			S[f].shown = true
		end
		-- (PF-057, B16 on build 71037) a TaxiRouteMap of 580 x 580 inside TaxiFrame and one TaxiButton per node,
		-- shown for CURRENT and REACHABLE nodes (the real read: 22 buttons, 2 shown, with one known node)
		local tf = client.taxi.frame
		if tf and fname == "TaxiFrame" then
			local env = client.env
			local route = rawget(env, "TaxiRouteMap")
			if not route then
				route = H.createFrame(client, "Frame", "TaxiRouteMap", tf)
				route:SetSize(580, 580)
				route:SetPoint("TOPLEFT", tf, "TOPLEFT", 11, -28)
			end
			S[route].shown = true
			-- buttons left over from a longer list are hidden
			for i = #nodes + 1, 200 do
				local old = rawget(env, "TaxiButton" .. i)
				if old and S[old] then S[old].shown = false end
			end
			for i, n in ipairs(nodes) do
				local btn = rawget(env, "TaxiButton" .. i)
				if not btn then
					btn = H.createFrame(client, "Button", "TaxiButton" .. i, tf)
					btn:SetSize(18, 18)
				end
				btn:ClearAllPoints()
				btn:SetPoint("CENTER", route, "TOPLEFT", (n.x or 0.5) * 580, -(n.y or 0.5) * 580)
				S[btn].shown = n.type ~= "NONE"
			end
		end
		self:openTaxi(client, nodes)
	end

	function World:closeTaxiMap(client)
		local t = client.taxi
		if not (t and t.open) then return end
		t.open = false
		if t.frame then
			S[t.frame].shown = false
			-- the node buttons go with the map (they are shown per open, never left over from the last map)
			for i = 1, #(t.nodes or {}) do
				local btn = rawget(client.env, "TaxiButton" .. i)
				if btn and S[btn] then S[btn].shown = false end
			end
		end
		client:fire("TAXIMAP_CLOSED")
	end

	function World:takeTaxi(client, slot)
		local fn = client.env.TakeTaxiNode
		H.protect(self, client, "TakeTaxiNode", fn, slot)
	end

	function World:landTaxi(client, spot, lag)
		local p = client.player
		local oldZone, oldSub = p.zone, p.subZone
		if spot then self:placePlayer(p, spot) end
		if client.taxi then client.taxi.flight = nil end
		if p.zone ~= oldZone then client:fire("ZONE_CHANGED_NEW_AREA") end
		if p.zone ~= oldZone or p.subZone ~= oldSub then client:fire("ZONE_CHANGED") end
		if lag then
			-- (opt-in) the landing event while the taxi flag is still set; it drops later, silently
			client:fire("PLAYER_CONTROL_GAINED")
			self:after(lag, function() p.onTaxi = false end, client, "taxi flag drops")
			return
		end
		p.onTaxi = false
		client:fire("PLAYER_CONTROL_GAINED")
	end

	function World:fly(client, slot, secs, spot, opts)
		opts = opts or {}
		self:takeTaxi(client, slot)
		local t = client.taxi
		local flight = t and t.flight
		if not flight then return end
		local takeoff = t.takeoff or 1
		if opts.loadingScreen then
			self:after(takeoff + opts.loadingScreen, function()
				client:fire("LOADING_SCREEN_ENABLED")
				client:fire("PLAYER_ENTERING_WORLD", false, false)
				client:fire("LOADING_SCREEN_DISABLED")
			end, client, "taxi loading screen")
		end
		if opts.logout then
			self:after(takeoff + opts.logout, function() client:fire("PLAYER_LOGOUT") end, client, "taxi logout")
		end
		self:after(takeoff + secs, function()
			if t.flight == flight then self:landTaxi(client, spot, opts.flagLag) end
		end, client, "taxi landing")
	end

	-- retired in round 12: the combat log is forbidden in this client (tools/forbidden.lua)
	function World:combatLog()
		error("w:combatLog is retired: the combat log is forbidden in this client; use w:pvpFight(c, foe)", 2)
	end

	function World:addNpc(name, opts)
		opts = opts or {}
		local p = self:addBot(name, { spot = opts.spot, faction = opts.faction or "Monster", class = "WARRIOR" })
		p.npc = true
		p.hostile = opts.hostile ~= false
		p.npcId = opts.npcId
		return p
	end

	function World:setZonePvp(zone, pvpType, factionName, ffa)
		self.zonePvp = self.zonePvp or {}
		if pvpType == nil then self.zonePvp[zone] = nil return end
		self.zonePvp[zone] = { type = pvpType, faction = factionName, ffa = ffa and true or false }
	end

	return F
end
