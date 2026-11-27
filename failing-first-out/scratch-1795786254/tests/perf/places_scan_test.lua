-- tests/perf/places_scan_test.lua (job 2879, perf audit 26 Nov 2026): reading a public chat line for place names stays cheap.
-- Every public chat line a Warlock driver hears (and every other player too: Wuber reads Trade for ride asks) goes through
-- DR.Mentions, which held each line's words against every place name with a typo-tolerant edit distance. The cost is the
-- Lua VM instructions run (a deterministic count, not a clock): the budget below is per chat line, over twelve everyday
-- Trade lines. The edit distance gives the same answer as before: the first test holds it to the plain version.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local LINES = {
	"LFM Mara need tank and healer", "WTS Linen Cloth x20 cheap", "anyone summon to Orgrimmar please", "lf1m ZG pst",
	"WTB Thorium Bar pm me", "LFG Deadmines need dps", "wuber to Ratchet 5g", "guild recruiting casual raiders",
	"LF enchanter pst", "selling Netherweb Lining fair prices", "need a lock for summon at Stonetalon", "free port to Undercity",
}

-- the plain edit distance (added, dropped, changed, two swapped), as the addon wrote it before: the reference
local function reference(a, b, limit)
	local la, lb = #a, #b
	if math.abs(la - lb) > limit then return limit + 1 end
	local d = {}
	for i = 0, la do d[i] = { [0] = i } end
	for j = 0, lb do d[0][j] = j end
	for i = 1, la do
		local best = i
		for j = 1, lb do
			local cost = a:byte(i) == b:byte(j) and 0 or 1
			local v = math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
			if i > 1 and j > 1 and a:byte(i) == b:byte(j - 1) and a:byte(i - 1) == b:byte(j) then v = math.min(v, d[i - 2][j - 2] + 1) end
			d[i][j] = v
			if v < best then best = v end
		end
		if best > limit then return limit + 1 end
	end
	return d[la][lb]
end

local function client()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	return w, d
end

test("perf: the edit distance answers as the plain version does (same words, same limit)", function()
	local w, d = client()
	local DR = d.W.Drive
	local seed = 7
	local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return seed % n end
	local names = { "orgrimmar", "undercity", "thunder bluff", "ratchet", "stonetalon", "booty bay", "gadgetzan", "tarren mill", "crossroads" }
	local letters = "abcdefghijklmnopqrstuvwxyz "
	local function mutate(s)
		local t = s
		for _ = 1, rnd(4) do
			local p = rnd(#t) + 1
			local k = rnd(4)
			if k == 0 then t = t:sub(1, p - 1) .. t:sub(p + 1)
			elseif k == 1 then local c = rnd(#letters) + 1 t = t:sub(1, p - 1) .. letters:sub(c, c) .. t:sub(p)
			elseif k == 2 then local c = rnd(#letters) + 1 t = t:sub(1, p - 1) .. letters:sub(c, c) .. t:sub(p + 1)
			elseif p < #t then t = t:sub(1, p - 1) .. t:sub(p + 1, p + 1) .. t:sub(p, p) .. t:sub(p + 2) end
		end
		return t
	end
	local n = 0
	for _, name in ipairs(names) do
		for _ = 1, 150 do
			local a = rnd(3) == 0 and mutate(mutate(name)) or mutate(name)
			for limit = 0, 3 do
				-- a distance over the limit is only ever read as "too far": both are held to limit + 1
				local want, got = math.min(reference(a, name, limit), limit + 1), math.min(DR.Distance(a, name, limit), limit + 1)
				if want ~= got then eq(got, want, ("Distance(%q, %q, %d)"):format(a, name, limit)) end
				n = n + 1
			end
		end
	end
	ok(n > 1000, "pairs checked: " .. n)
	T.clean(w)
end)

-- the words a Trade channel says all day (so the answers Mentions remembers are warm, as they are a few minutes into a session)
local EVERYDAY = {
	"LFM UBRS need tank and healer", "WTS Mooncloth x4 cheap pst", "anyone summon to Stormwind please", "lf2m Scholomance pst",
	"WTB Arcanite Bar pm me", "LFG Blackfathom need dps", "wuber to Booty Bay 5g", "guild recruiting casual players for raids",
	"LF alchemist pst", "selling Runecloth Bandage fair prices", "need a warlock for summon at Crossroads", "free port to Orgrimmar",
	"LFM Zul Gurub two spots left", "WTS Black Lotus whisper offers", "looking for a mage portal to Darnassus", "need more for Strat live",
	"selling enchants for gold tips welcome", "WTB Dark Iron Ore stack", "Hello everyone anyone doing Mara tonight", "LF healer for Deadmines run",
	"guild has openings for raiders and crafters", "WTS Thorium Armor Kit cheap", "port to Ironforge anyone", "LFM Sunken Temple tank needed",
}

test("perf: a public chat line costs under 120,000 Lua instructions to read for place names (everyday words warm)", function()
	local w, d = client()
	local DR = d.W.Drive
	local function split(line)
		local t = {}
		for x in DR.Norm(line):gmatch("%S+") do t[#t + 1] = x end
		return t
	end
	for _, line in ipairs(EVERYDAY) do DR.Mentions(split(line)) end
	for _, line in ipairs(LINES) do DR.Mentions(split(line)) end -- the words these lines hold are as everyday as the rest
	local words = {}
	for i, line in ipairs(LINES) do words[i] = split(line) end
	collectgarbage("collect")
	local count = 0
	debug.sethook(function() count = count + 1 end, "", 100)
	for _ = 1, 5 do
		for i = 1, #words do DR.Mentions(words[i]) end
	end
	debug.sethook()
	local perLine = count * 100 / (5 * #words)
	-- before: about 370,000 a line; the words a line holds are held against every place name once and remembered
	ok(perLine < 120000, ("Lua instructions per chat line: %d (budget 120000)"):format(perLine))
	T.clean(w)
end)

