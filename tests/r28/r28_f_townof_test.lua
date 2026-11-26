local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local ANA, BEA = "Ana Smith", "Bea Jones"

-- Ana (Wuber, Warlock, runner) at Ratchet; Bea a plain Warlock (no Wuber) at beaSpot.
local function world(beaSpot)
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = "Ratchet", class = "WARLOCK",
		saved = { Wuber = { chars = { [key(ANA)] = { wizard = true, captain = "", summoners = { ANA, BEA },
			crew = { { name = BEA, role = "lock", app = false } } } } } } })
	w:addBot(BEA, { spot = beaSpot })
	w:group({ ANA, BEA })
	w:advance(20)
	local DR = ana.W.Drive
	ok(DR.SetOpen(true))
	w:advance(10)
	return w, ana, DR
end

local function stationNames(DR)
	local names = {}
	for _, st in ipairs(DR.Stations()) do names[#names + 1] = st.place end
	return names
end

test("r28 AUD-45: a plain summoner standing at Ratchet beside the runner is one station, not a second one called The Barrens", function()
	local w, ana, DR = world("Ratchet")
	local names = stationNames(DR)
	eq(DR.PlaceOf("player"), "Ratchet", "control: my own station is Ratchet")
	eq(#names, 1, "both Warlocks stand in Ratchet: one station expected, got: " .. table.concat(names, " + "))
	ok(not DR.MultiStation(), "the phone asks riders 'Where to?' (two stations) although everyone is in Ratchet")
	eq(DR.PlaceOf(key(BEA)), "Ratchet", "PlaceOf(plain summoner)")
	T.clean(w)
end)

test("r28 AUD-45: a plain summoner at Crossroads (same zone, another town) is still its own station", function()
	local w, ana, DR = world("Crossroads")
	local place = DR.PlaceOf(key(BEA))
	ok(place ~= "Ratchet", "Bea at Crossroads must not count as standing at Ratchet, got " .. tostring(place))
	eq(place, "Crossroads", "PlaceOf(plain summoner at Crossroads)")
	local names = stationNames(DR)
	eq(#names, 2, "Ratchet and Crossroads are two stations, got: " .. table.concat(names, " + "))
	ok(DR.MultiStation(), "two towns: riders are asked where to")
	T.clean(w)
end)

test("r28 AUD-45: a summoner's own reported place still wins, and no map position falls back to the zone", function()
	local w, ana, DR = world("Ratchet")
	DR.apps[key(BEA)] = { place = "Crossroads", map = 1413 }
	local place, map = DR.PlaceOf(key(BEA))
	eq(place, "Crossroads", "a Wuber summoner's own reported place is used as it is")
	eq(map, 1413, "with its own reported map")
	DR.apps[key(BEA)] = nil
	ana.env.C_Map.GetPlayerMapPosition = function() return nil end
	eq(DR.PlaceOf(key(BEA)), "The Barrens", "out of range (no position): the zone name, as before")
	ana.env.C_Map.GetPlayerMapPosition = function() error("no") end
	eq(DR.PlaceOf(key(BEA)), "The Barrens", "an erroring position call: the zone name, quietly")
	T.clean(w)
end)
