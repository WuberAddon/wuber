-- Round 26, item 4: the price card's crossing word agrees with the world map's arrow.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local ZEP = { [11] = true, [20] = true, [23] = true }

local function setup(opts)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, opts or {})
	T.settle(w)
	return w, r, r.W.Mod("UI.Rider.Booking"), r.W.Mod("UI.Rider.SeaRoute")
end

-- the arrow's word, built from the route as WorldMap.drawGold builds its legs
local function arrowWord(W, SeaMod, from, to)
	local ids = W.FlightRoute(from, to)
	if not ids then return nil, false end
	local legs = {}
	for i = 1, #ids - 1 do
		local a, b = ids[i], ids[i + 1]
		local na, nb = W.TAXI.nodes[a], W.TAXI.nodes[b]
		local cross = na[2] ~= nb[2]
		legs[#legs + 1] = { cont = na[2], to = nb[2], pts = { 0, 0, 1, 1 },
			kind = cross and ((ZEP[a] and ZEP[b]) and "zeppelin" or "boat") or "flight" }
	end
	local s = SeaMod.Split(legs, legs[1].cont)
	return s.cross and s.word or nil, true
end

test("r26 item 4: a Horde rider in Orgrimmar to Grom'gol: by zeppelin, and the card says zeppelin", function()
	local w, r, B = setup({ spot = "Orgrimmar" })
	local s, how = r.W.TravelSaved("Grom'gol")
	eq(how, "by zeppelin", "TravelSaved word")
	ok(s and s < 700, "a zeppelin time, not a boat guess: " .. tostring(s))
	eq(B.Via("Grom'gol"), "zeppelin", "Via")
	local info = B.DialInfo({ dest = "Grom'gol", queue = 0 }, 0)
	eq(info and info.crossing, "zeppelin", "the card's crossing")
	T.clean(w)
end)

test("r26 item 4: Orgrimmar to Undercity is still a zeppelin; same continent gives no crossing", function()
	local w, r, B = setup({ spot = "Orgrimmar" })
	local _, how = r.W.TravelSaved("Undercity")
	eq(how, "by zeppelin", "Undercity")
	eq(B.Via("Undercity"), "zeppelin", "Via")
	local info = B.DialInfo({ dest = "Thunder Bluff", queue = 0 }, 0)
	eq(info and info.crossing, nil, "same continent: no crossing")
	eq(B.Via("Thunder Bluff"), nil, "Via same continent")
	T.clean(w)
end)

test("r26 item 4: Alliance Booty Bay to Ratchet is by boat and about five minutes", function()
	local w, r, B = setup({ spot = "Booty Bay", faction = "Alliance" })
	local s, how = r.W.TravelSaved("Ratchet")
	eq(how, "by boat", "word")
	ok(s and s < 400, "under 400 s, not the Menethil detour: " .. tostring(s))
	local row = false
	for _, c in ipairs(r.W.CROSSINGS) do if c[1] == "Ratchet" and c.A then row = true end end
	ok(row, "an Alliance Ratchet row")
	T.clean(w)
end)

test("r26 item 4: every cross-continent flight pair, both factions: card word equals the arrow's word", function()
	local checked, bad = 0, {}
	for _, fac in ipairs({ "Horde", "Alliance" }) do
		local w, r, B, SeaMod = setup({ spot = fac == "Horde" and "Orgrimmar" or "Stormwind", faction = fac })
		local nodes = r.W.TAXI.nodes
		local f = fac:sub(1, 1)
		local names = {}
		for id, n in pairs(nodes) do
			if type(n) == "table" and (n[5] == nil or n[5] == f) and type(n[1]) == "string" then names[#names + 1] = { id, n } end
		end
		table.sort(names, function(a, b) return a[1] < b[1] end)
		for _, a in ipairs(names) do
			for _, b in ipairs(names) do
				if a[2][2] ~= b[2][2] then
					local aw, found = arrowWord(r.W, SeaMod, a[2][1], b[2][1])
					if found then
						checked = checked + 1
						local cw = B.CrossWord(b[2][1], a[2][1])
						if cw ~= aw then bad[#bad + 1] = fac .. " " .. a[2][1] .. " > " .. b[2][1] .. ": card " .. tostring(cw) .. " arrow " .. tostring(aw) end
					end
				end
			end
		end
		T.clean(w)
	end
	ok(checked > 100, "pairs checked: " .. checked)
	eq(#bad, 0, table.concat(bad, "; ", 1, math.min(#bad, 5)))
end)
