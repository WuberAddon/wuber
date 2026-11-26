-- Module: Drive.Places
-- Purpose: Place names riders use and reading "WTB summon to X" chat lines (was Drive_Places.lua).
-- API: W.Drive, DR.Norm, DR.PLACES, DR.Distance, DR.Near, DR.Summonish, DR.PlaceEntry, DR.DestNames,
--   DR.PlaceIn, DR.Mentions, DR.HasGameLink, DR.PublicWant, DR.AskedPlaces, DR.MapOf, DR.PlaceOf, DR.Stations, DR.WorkStations,
--   DR.MultiStation, DR.StationList, DR.SetStation, DR.StationOf, DR.MyStation, DR.ForMyStation,
--   DR.DestIn, DR.Route, DR.ArrivedAt
-- Internals: SELL, SELLISH, ADVERT_PHRASES
-- Uses: (none)
-- Later: (none)
-- Events: listens Listen DRIVE_STATIONS; fires DRIVE_STATIONS
-- Standalone: no
-- Test: tests/drive/places_test.lua
-- From: Drive_Places.lua 1-703 (Wuber 2.2.1)
--
-- Drive_Places: the names players use for where they want to go, and reading a public chat
-- line for "I want to buy a summon to X" (Ritual Rides' Places.lua, on Wuber's one place table).
--
--   "wtb summon ratchet", "LF summ to rachet pls", "any lock for ratchet?"  -> a buyer, Ratchet
--   "WTS summons to Ratchet, whisper me"                                    -> a seller: left alone
--
-- RR's alias lists are merged into the matching W.PLACES entries (p.aliases, at load: only
-- Places.lua's table is touched, no Drive file is called). Places only RR knew are kept in a
-- local list for matching only.

local _, W = ...
local Mod = W.Module("Drive.Places", {})
W.Drive = W.Drive or {}
local DR = W.Drive

-- RR's names (lower case, no apostrophes). The first is how the place is written.
local RR_PLACES = {
	{ "Ratchet", "ratchet", "rachet", "ratchett", "rachett", "ratchit", "ratch", "ratchet docks" },
	{ "Orgrimmar", "orgrimmar", "orgrimar", "orgimmar", "orgrimmer", "orgri", "orgrim", "org", "og" },
	{ "Thunder Bluff", "thunder bluff", "thunderbluff", "thunder bluf", "tb" },
	{ "Crossroads", "crossroads", "the crossroads", "xroads", "xr", "cross roads" },
	{ "Gadgetzan", "gadgetzan", "gadgetzen", "gadgetsan", "gadget", "gadge", "gz" },
	{ "Everlook", "everlook", "ever look" },
	{ "Cenarion Hold", "cenarion hold", "cenarion", "ch" },
	{ "Marshal's Refuge", "marshals refuge", "marshal refuge", "marshals" },
	{ "Splintertree Post", "splintertree", "splinter tree" },
	{ "Brackenwall Village", "brackenwall", "bracken wall" },
	{ "Camp Mojache", "camp mojache", "mojache" },
	{ "Valormok", "valormok" },
	{ "Moonglade", "moonglade", "nighthaven" },
	{ "Theramore", "theramore" },
	{ "Undercity", "undercity", "under city", "the undercity", "uc", "u c", "ucity", "undercit", "undercty", "undrcity", "undercitty", "undacity", "undercitee", "underctiy", "undercitys" },
	{ "Booty Bay", "booty bay", "bootybay", "booty", "bb" },
	{ "Kargath", "kargath" },
	{ "Thorium Point", "thorium point", "thorium" },
	{ "Light's Hope Chapel", "lights hope chapel", "lights hope", "light hope", "lhc" },
	{ "Grom'gol", "gromgol", "grom gol", "grom" },
	{ "Revantusk Village", "revantusk" },
	{ "Tarren Mill", "tarren mill", "tarrenmill", "tm" },
	{ "Hammerfall", "hammerfall" },
	{ "Stonard", "stonard" },
	{ "Ironforge", "ironforge", "iron forge" },
	{ "Stormwind", "stormwind", "storm wind", "sw" },
	{ "Darnassus", "darnassus", "darn" },
	{ "Blackrock Mountain", "blackrock mountain", "blackrock", "black rock", "brm", "brd", "lbrs", "ubrs", "mc", "molten core", "bwl", "blackrock depths", "blackrock spire" },
	{ "Stratholme", "stratholme", "strat", "strath", "stratholm" },
	{ "Scholomance", "scholomance", "scholo", "scholo mance" },
	{ "Dire Maul", "dire maul", "diremaul", "dm", "dmn", "dme", "dmw", "dm north", "dm east", "dm west" },
	{ "Zul'Farrak", "zulfarrak", "zul farrak", "zf" },
	{ "Maraudon", "maraudon", "mara" },
	{ "Sunken Temple", "sunken temple", "temple of atalhakkar", "st" },
	{ "Uldaman", "uldaman", "ulda", "uld" },
	{ "Razorfen Downs", "razorfen downs", "rfd" },
	{ "Razorfen Kraul", "razorfen kraul", "rfk" },
	{ "Wailing Caverns", "wailing caverns", "wc" },
	{ "Scarlet Monastery", "scarlet monastery", "scarlet", "sm", "sm cath", "sm arm", "sm lib", "sm gy" },
	{ "Shadowfang Keep", "shadowfang keep", "shadowfang", "sfk" },
	{ "Blackfathom Deeps", "blackfathom deeps", "blackfathom", "bfd" },
	{ "Gnomeregan", "gnomeregan", "gnomer", "gnomeragan" },
	{ "Zul'Gurub", "zulgurub", "zul gurub", "zg" },
	{ "Onyxia's Lair", "onyxias lair", "onyxia", "ony" },
	{ "Ahn'Qiraj", "ahnqiraj", "ahn qiraj", "aq", "aq20", "aq40" },
	{ "Tanaris", "tanaris" },
	{ "Un'Goro Crater", "ungoro crater", "ungoro", "un goro" },
	{ "Felwood", "felwood", "fel wood" },
	{ "Winterspring", "winterspring", "winter spring", "ws" },
	{ "Silithus", "silithus" },
	{ "Azshara", "azshara" },
	{ "Feralas", "feralas" },
	{ "Desolace", "desolace" },
	{ "Dustwallow Marsh", "dustwallow marsh", "dustwallow", "dwm" },
	{ "Thousand Needles", "thousand needles", "1k needles", "1000 needles", "needles" },
	{ "Stonetalon Mountains", "stonetalon mountains", "stonetalon", "stm" },
	{ "Ashenvale", "ashenvale" },
	{ "The Barrens", "the barrens", "barrens" },
	{ "Durotar", "durotar" },
	{ "Mulgore", "mulgore" },
	{ "Searing Gorge", "searing gorge", "searing", "sg" },
	{ "Burning Steppes", "burning steppes", "burning steps", "steppes", "bs" },
	{ "Badlands", "badlands", "bad lands" },
	{ "Eastern Plaguelands", "eastern plaguelands", "eastern plague", "epl" },
	{ "Western Plaguelands", "western plaguelands", "western plague", "wpl" },
	{ "The Hinterlands", "the hinterlands", "hinterlands", "hinterland" },
	{ "Stranglethorn Vale", "stranglethorn vale", "stranglethorn", "stv" },
	{ "Swamp of Sorrows", "swamp of sorrows", "sos" },
	{ "Blasted Lands", "blasted lands", "blasted" },
	{ "Arathi Highlands", "arathi highlands", "arathi" },
	{ "Hillsbrad Foothills", "hillsbrad foothills", "hillsbrad" },
	{ "Alterac Mountains", "alterac mountains", "alterac" },
	{ "Silverpine Forest", "silverpine forest", "silverpine" },
	{ "Tirisfal Glades", "tirisfal glades", "tirisfal" },
	{ "Deadwind Pass", "deadwind pass", "deadwind", "kara" },
	{ "The Riverglades", "the riverglades", "riverglades", "river glades" },
	{ "Mount Hyjal", "mount hyjal", "hyjal", "mt hyjal" },
	{ "Shen'dralas", "shendralas", "shen dralas" },
	-- (BRIEF22 P1) every other Classic zone and city riders name: a line asking for one is somewhere else
	{ "Loch Modan", "loch modan", "lochmodan", "loch", "thelsamar" },
	{ "Dun Morogh", "dun morogh", "dunmorogh", "morogh", "kharanos" },
	{ "Elwynn Forest", "elwynn forest", "elwynn", "elwyn", "goldshire" },
	{ "Westfall", "westfall", "west fall", "sentinel hill" },
	{ "Redridge Mountains", "redridge mountains", "redridge", "red ridge", "lakeshire" },
	{ "Duskwood", "duskwood", "dusk wood", "darkshire" },
	{ "Wetlands", "wetlands", "the wetlands", "menethil harbor", "menethil" },
	{ "Darkshore", "darkshore", "dark shore", "auberdine" },
	{ "Teldrassil", "teldrassil", "teldrasil", "dolanaar" },
	{ "Silvermoon City", "silvermoon city", "silvermoon", "smc" },
	{ "The Exodar", "the exodar", "exodar" },
	{ "Shattrath City", "shattrath city", "shattrath", "shatt" },
	{ "Dalaran", "dalaran" },
	{ "Southshore", "southshore", "south shore" },
	{ "Astranaar", "astranaar", "astranar" },
	{ "Camp Taurajo", "camp taurajo", "taurajo" },
	{ "Bloodhoof Village", "bloodhoof village", "bloodhoof" },
	{ "Razor Hill", "razor hill", "razorhill" },
	{ "The Sepulcher", "the sepulcher", "sepulcher" },
	{ "Ragefire Chasm", "ragefire chasm", "ragefire", "rfc" },
	{ "The Deadmines", "the deadmines", "deadmines", "deadmine" },
	{ "The Stockade", "the stockade", "stockade", "stockades" },
}

-- Names of W.PLACES that are common words in chat lines: never matched as a place.
local STOP = { ["if"] = true, ["the"] = true, ["bay"] = true, ["hold"] = true, ["or"] = true, ["in"] = true,
	["at"] = true, ["to"] = true, ["on"] = true, ["a"] = true, ["i"] = true, ["me"] = true, ["post"] = true }

-- Lower case, apostrophes dropped, the rest not a letter or digit a space, padded with
-- spaces so " word " finds whole words only.
function DR.Norm(text)
	local s = tostring(text or ""):lower()
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	s = s:gsub("|h.-|h(.-)|h", "%1")
	s = s:gsub("['`]", ""):gsub("\226\128\153", "")
	s = s:gsub("[^%a%d]+", " ")
	return " " .. s:gsub("^%s+", ""):gsub("%s+$", "") .. " "
end

local function bare(text) return (DR.Norm(text):gsub("^ ", ""):gsub(" $", "")) end

-- The matching list: { name, alias, alias... } per place, RR's and Wuber's merged.
local PLACES = {}
DR.PLACES = PLACES

do
	local byName = {}
	local function entryFor(name)
		local n = bare(name)
		local e = byName[n]
		if not e then
			e = { name, seen = {} }
			byName[n] = e
			PLACES[#PLACES + 1] = e
		end
		return e
	end
	local function addName(e, n)
		n = bare(n)
		if n ~= "" and not STOP[n] and not e.seen[n] then
			e.seen[n] = true
			e[#e + 1] = n
		end
	end
	-- Wuber's places first (their names are how places are written on the network)
	local wByName = {}
	for _, p in ipairs(W.PLACES or {}) do
		local e = entryFor(p.name)
		e.place = p
		addName(e, p.name)
		for _, n in ipairs(p.names or {}) do addName(e, n) end
		wByName[bare(p.name)] = p
	end
	for _, r in ipairs(RR_PLACES) do
		local p = (W.ExactPlace and W.ExactPlace(r[1])) or wByName[bare(r[1])]
		local e = p and byName[bare(p.name)] or entryFor(r[1])
		for i = 2, #r do addName(e, r[i]) end
		addName(e, r[1])
		if p then
			-- the aliases riders type, on Wuber's own place
			p.aliases = p.aliases or {}
			local have = {}
			for _, a in ipairs(p.aliases) do have[a] = true end
			for _, n in ipairs(p.names or {}) do have[n] = true end
			have[W.NormPlace and W.NormPlace(p.name) or bare(p.name)] = true
			for i = 2, #r do
				local n = bare(r[i])
				if n ~= "" and not have[n] and not STOP[n] then
					have[n] = true
					p.aliases[#p.aliases + 1] = n
				end
			end
		end
	end
	for _, e in ipairs(PLACES) do e.seen = nil end
end

local function has(norm, phrase)
	return norm:find(" " .. phrase .. " ", 1, true) ~= nil
end

---------------------------------------------------------------------------
-- Typos
---------------------------------------------------------------------------

-- The edit distance between a and b (added, dropped, changed, two swapped), or limit + 1.
-- Three rows kept for every call (SPEC5 public, review #18: no tables made per call).
local ROWS = { {}, {}, {} }
-- (perf audit, 26 Nov 2026) Most words a chat line holds are nowhere near a place name, and the grid below costs
-- length x length steps for each name. Every edit (added, dropped, changed, two swapped) takes at most one letter
-- of a away from b's letters, so when more than limit of a's letters have no partner in b the distance is over
-- the limit: said after one pass over each word. A count of the letters, kept for every call (no tables made per call).
local LETTERS = {}
for c = 0, 255 do LETTERS[c] = 0 end -- every letter has its slot from the start: counting and clearing never grows or shrinks the table
local function farApart(a, b, limit)
	for j = 1, #b do
		local c = b:byte(j)
		LETTERS[c] = LETTERS[c] + 1
	end
	local alone = 0
	for i = 1, #a do
		local c = a:byte(i)
		local n = LETTERS[c]
		if n > 0 then LETTERS[c] = n - 1 else alone = alone + 1 end
	end
	for j = 1, #b do LETTERS[b:byte(j)] = 0 end
	return alone > limit
end
local function distance(a, b, limit)
	local la, lb = #a, #b
	if math.abs(la - lb) > limit then return limit + 1 end
	if farApart(a, b, limit) then return limit + 1 end
	local prev2, prev, cur = ROWS[3], ROWS[1], ROWS[2]
	for j = 0, lb do prev[j] = j end
	for i = 1, la do
		cur[0] = i
		local best = i
		local ca = a:byte(i)
		for j = 1, lb do
			local cb = b:byte(j)
			local cost = ca == cb and 0 or 1
			local v = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
			if i > 1 and j > 1 and ca == b:byte(j - 1) and a:byte(i - 1) == cb then
				v = math.min(v, prev2[j - 2] + 1)
			end
			cur[j] = v
			if v < best then best = v end
		end
		if best > limit then return limit + 1 end
		prev2, prev, cur = prev, cur, prev2
	end
	return prev[lb]
end
DR.Distance = distance

-- Typos a name of this length may carry: none below six letters, one up to seven, two from eight.
local function allowed(n)
	if n < 6 then return 0 end
	if n < 8 then return 1 end
	return 2
end

local function near(norm, phrase, words)
	if has(norm, phrase) then return true end
	local limit = allowed(#phrase)
	if limit == 0 then return false end
	words = words or {}
	if #words == 0 then for w in norm:gmatch("%S+") do words[#words + 1] = w end end
	local n = 1
	for _ in phrase:gmatch(" ") do n = n + 1 end
	local joined = phrase:gsub(" ", "")
	for i = 1, #words do
		if i + n - 1 <= #words then
			local chunk = table.concat(words, " ", i, i + n - 1)
			if distance(chunk, phrase, limit) <= limit then return true end
		end
		if n > 1 and distance(words[i], joined, limit) <= limit then return true end
	end
	return false
end
DR.Near = near

-- "summon" misspelt: sumon, summn, summoon, sunmon, smmon, summonig ...
local SPELLINGS = { "summon", "summons", "summoning", "summoner" }
local function summonish(w)
	if #w < 4 then return false end
	for _, s in ipairs(SPELLINGS) do
		local limit = (#s >= 8 and #w >= 8) and 2 or 1
		if distance(w, s, limit) <= limit then return true end
	end
	return false
end
DR.Summonish = summonish

-- (20 Nov) topic words one letter off (one substitution, insertion, deletion or swap): only for a word
-- of 5+ letters against a target of 6+ letters, and never a real word ("postal", "mortal", "warlord").
local TYPO_TARGETS = { "portal", "portals", "teleport", "warlock", "warlocks" }
local NOT_TOPIC = { postal = true, mortal = true, mortals = true, portly = true, warlord = true, warlords = true, portico = true }
local function topicish(w)
	if #w < 5 or NOT_TOPIC[w] then return false end
	for _, s in ipairs(TYPO_TARGETS) do
		if distance(w, s, 1) <= 1 then return true end
	end
	return false
end

-- Every place name and alias in one table (SPEC5 public, review #18: a lookup, not a scan of
-- ~350 names): BYNAME[name or alias] = entry (the first entry that has it, in PLACES order);
-- ALIAS[alias] = { entry, order } for the exact search in a line; MAXW = the most words in one.
local BYNAME, ALIAS, MAXW = {}, {}, 1
do
	local order = 0
	for _, entry in ipairs(PLACES) do
		local own = bare(entry[1])
		if own ~= "" and not BYNAME[own] then BYNAME[own] = entry end
		for i = 2, #entry do
			local n = entry[i]
			order = order + 1
			if not BYNAME[n] then BYNAME[n] = entry end
			if not ALIAS[n] then ALIAS[n] = { entry, order } end
			local nw = 1
			for _ in n:gmatch(" ") do nw = nw + 1 end
			if nw > MAXW then MAXW = nw end
		end
	end
end

-- The matching entry of a place name ({ name, aliases... }), or nil.
function DR.PlaceEntry(name)
	local n = bare(name)
	if n == "" then return nil end
	return BYNAME[n]
end

-- Every name the destination goes by: its own, its place's names, and "Also called" words.
function DR.DestNames()
	local out, seen = {}, {}
	local function add(n)
		n = bare(n)
		if n ~= "" and not seen[n] then
			seen[n] = true
			out[#out + 1] = n
		end
	end
	local dest = DR.Dest and DR.Dest() or ""
	add(dest)
	local entry = DR.PlaceEntry(dest)
	if entry then
		for i = 2, #entry do add(entry[i]) end
	end
	local words = DR.char and DR.char().destWords or ""
	for w in tostring(words or ""):gmatch("[^,]+") do add(w) end
	return out
end

-- The place a line names (the longest name found first), or nil.
function DR.PlaceIn(norm)
	local words = {}
	for w in norm:gmatch("%S+") do words[#words + 1] = w end
	-- exact: every run of up to MAXW words looked up (the longest name wins, then the first)
	local best, bestLen, bestOrder
	for i = 1, #words do
		for k = 1, MAXW do
			if i + k - 1 > #words then break end
			local a = ALIAS[table.concat(words, " ", i, i + k - 1)]
			if a then
				local n = #table.concat(words, " ", i, i + k - 1)
				if not bestLen or n > bestLen or (n == bestLen and a[2] < bestOrder) then
					best, bestLen, bestOrder = a[1], n, a[2]
				end
			end
		end
	end
	if best then return best end
	for _, entry in ipairs(PLACES) do
		for i = 2, #entry do
			if near(norm, entry[i], words) then return entry end
		end
	end
	return nil
end

local TO = { to = true, ["2"] = true, too = true, into = true, towards = true, toward = true, til = true, till = true }
-- (AUD-57) the word before a place, stepping over "the": "I'm in the badlands" is "in", not "the"
local function wordBefore(words, at)
	local b = words[at - 1]
	if b == "the" then b = words[at - 2] end
	return b
end
local FROM = { from = true, frm = true, fron = true, ["in"] = true, at = true, leaving = true, outside = true, near = true }

-- (BRIEF22 P1) Words that follow "to"/"2" and are no place: pronouns, verbs ("to pay"), groups, counts
-- ("2 ppl"), fillers. Any other word there is a place, known or not ("summons to loch modan?").
local NOT_PLACE = {}
for w in ([[me us you u ya yall him her them it its my our your ur their his this that these those there here where
	wherever anywhere somewhere everywhere home a an any anyone anybody someone somebody everyone all both each some
	one two three four five other another same next first last be go get got buy pay do make help take come give have
	see sell trade join inv invite run fly walk travel finish turn quest farm grind kill save skip spend find meet
	bring use tank heal play start wait stay say ask know work try keep let put set show tip talk ride return head move
	reach catch hit raid level lvl queue que attune hand deliver collect gather pick loot learn train visit explore
	avoid rejoin hearth die rez res cast open close leave stop check sign accept decline cancel hurry rush chill relog
	log swap switch change craft cook fish follow look read reply answer call port hang spare afford tell thank sit
	group grp party dungeon dungeons dung instance inst stone stones meeting city town capital world zone boss
	bosses bg bgs guild friend friends mate mates buddy alt alts char chars toon toons people ppl peeps players player
	person persons guys more of x times min mins minute minutes sec secs hour hours hrs stack stacks spot spots slot
	slots man men pls plz please thanks thx ty asap now fast quick quickly soon today tonight lol lmao xd ok okay
	yes no not also again back off up out down over away
	location loc locations myself self yourself ourselves entrance entry inside front top bottom side middle centre center
	area place spot coords coordinates position pos arena afk bank banker ah auction auctioneer trainer trainers vendor
	vendors repair mailbox mail inn innkeeper tavern flightpath flight fp flightmaster fm gryphon wyvern bat zeppelin zep
	zepp boat ship tram docks dock graveyard gy spirit healer corpse body npc stable stables stablemaster barber gate
	gates bridge tower cave lake river pvp battleground battlegrounds duel duels event rogue warrior mage priest hunter
	druid shaman paladin class]]):gmatch("%a+") do NOT_PLACE[w] = true end
local TO_PLACE = { to = true, ["2"] = true, into = true, towards = true, toward = true }

-- The first word after "to"/"2" (past "the") that is no known place of the line (taken[i]), no common word and
-- no topic word, and not a typo of my own place (it starts as one of names does): the place the line asks
-- for that no list knows, and where; or nil. skip(w): more words that are no place (the request words).
local function unknownTo(words, taken, names, skip)
	for i = 1, #words - 1 do
		if TO_PLACE[words[i]] then
			local j = i + 1
			if words[j] == "the" then j = j + 1 end
			local w = words[j]
			local placeLike = w and not taken[j] and #w >= 3 and not w:find("%A") and not NOT_PLACE[w]
				and not (skip and skip(w))
			if placeLike then
				for _, n in ipairs(names or {}) do
					if (#n >= 3 and w:sub(1, 3) == n:sub(1, 3)) or (#n >= 3 and w:sub(1, #n) == n) then placeLike = false end
				end
			end
			if placeLike then return w, j end
		end
	end
	return nil
end

-- The word positions the found places cover (a place of two words covers both).
local function covered(lists)
	local t = {}
	for _, list in ipairs(lists) do
		for _, m in ipairs(list) do
			local nw = 1
			for _ in tostring(m.name or ""):gmatch(" ") do nw = nw + 1 end
			for k = m.at, m.at + nw - 1 do t[k] = true end
		end
	end
	return t
end

-- Every place a line names: `mine` (names of my destination) and `others`.
local NAME_INFO = {}
-- (perf audit) What a word of a chat line is near, remembered. Chat says the same few thousand words all day, and
-- holding each new word against every place name costs about as much as the rest of reading the line. So the first
-- time a word is seen it is held against every one-word place name once (SINGLES: the names of the place list), and
-- what it is near (within the typo allowance) is kept: usually nothing. The answer for a word and a name never
-- changes (it depends only on the two spellings and the allowance the name's length sets). Emptied at 4,000 words, so
-- it never holds more than a few hundred KB. A name not in the list gets the plain distance, as before.
local SINGLES, SINGLES_KEY = {}, nil
local WORD_NEAR, WORD_NEAR_N, NO_NEAR = {}, 0, {}
local function singlesNow()
	local key = #PLACES
	for _, entry in ipairs(PLACES) do key = key + #entry end
	if key ~= SINGLES_KEY then
		SINGLES, SINGLES_KEY, WORD_NEAR, WORD_NEAR_N = {}, key, {}, 0
		for _, entry in ipairs(PLACES) do
			for i = 2, #entry do
				local n = entry[i]
				if type(n) == "string" and allowed(#n) > 0 then
					-- a name of several words is also matched by one word written without the spaces: joined to it
					SINGLES[n] = { allowed(#n), (n:gsub(" ", "")) }
				end
			end
		end
	end
	return SINGLES
end
local function nearWord(word)
	local near = WORD_NEAR[word]
	if near then return near end
	local lw = #word
	if lw < 4 then return NO_NEAR end
	near = nil
	for n, s in pairs(SINGLES) do
		local limit, spelt = s[1], s[2]
		local ln = #spelt
		if lw - ln <= limit and ln - lw <= limit then
			local d = distance(word, spelt, limit)
			if d <= limit then
				near = near or {}
				near[n] = d
			end
		end
	end
	near = near or NO_NEAR
	WORD_NEAR[word] = near
	WORD_NEAR_N = WORD_NEAR_N + 1
	if WORD_NEAR_N >= 4000 then WORD_NEAR, WORD_NEAR_N = {}, 0 end
	return near
end
function DR.Mentions(words)
	local mine, others = {}, {}
	local destEntry = DR.PlaceEntry(DR.Dest and DR.Dest() or "")
	local singles = singlesNow()
	local nears = {} -- per word of this line: what it is near
	local reach = { [0] = 0 } -- reach[i]: the letters of words 1..i written with a space after each (a run of words' length without writing it)
	for i = 1, #words do reach[i] = reach[i - 1] + #words[i] + 1 end
	local function scan(names, into, skipEntry)
		for _, n in ipairs(names) do
			-- (perf audit) a name's word count, typo allowance and joined spelling do not change: worked out once
			local info = NAME_INFO[n]
			if not info then
				local count = 1
				for _ in n:gmatch(" ") do count = count + 1 end
				info = { count, allowed(#n), (n:gsub(" ", "")) }
				NAME_INFO[n] = info
			end
			local nw, limit, joined = info[1], info[2], info[3]
			if nw == 1 then
				-- (perf audit) the common case, a one-word name: a word is far from it unless its length is within the allowance
				local listed = singles[n] ~= nil
				local ln = #n
				for i = 1, #words do
					local chunk = words[i]
					local lc = #chunk
					if chunk == n then
						into[#into + 1] = { at = i, name = n, entry = skipEntry, dist = 0 }
					elseif limit > 0 and lc >= 4 and lc - ln <= limit and ln - lc <= limit then
						local dist
						if listed then
							local near = nears[i]
							if not near then near = nearWord(chunk) nears[i] = near end
							dist = near[n]
						else
							dist = distance(chunk, n, limit)
							if dist > limit then dist = nil end
						end
						if dist then into[#into + 1] = { at = i, name = n, entry = skipEntry, dist = dist } end
					end
				end
			else
			local listed = singles[n] ~= nil
			local ln = #n
			for i = 1, #words do
				local hit, dist = false, 0
				if i + nw - 1 <= #words then
					-- (perf audit) the run's length is known without writing it: only a run about as long as the name is looked at
					local clen = reach[i + nw - 1] - reach[i - 1] - 1
					if clen == ln or (limit > 0 and clen >= 4 and clen - ln <= limit and ln - clen <= limit) then
						local chunk = table.concat(words, " ", i, i + nw - 1)
						if chunk == n then
							hit = true
						elseif limit > 0 and #chunk >= 4 then
							dist = distance(chunk, n, limit)
							hit = dist <= limit
						end
					end
				end
				if not hit and nw > 1 and limit > 0 and #words[i] >= 4 then
					if listed then
						local near = nears[i]
						if not near then near = nearWord(words[i]) nears[i] = near end
						dist = near[n]
						hit = dist ~= nil
					else
						dist = distance(words[i], joined, limit)
						hit = dist <= limit
					end
				end
				if hit then into[#into + 1] = { at = i, name = n, entry = skipEntry, dist = dist } end
			end
			end
		end
	end
	scan(DR.DestNames(), mine)
	for _, entry in ipairs(PLACES) do
		if entry ~= destEntry then
			local names = {}
			for i = 2, #entry do names[#names + 1] = entry[i] end
			local found = {}
			scan(names, found, entry)
			for _, m in ipairs(found) do
				local taken = false
				-- (BRIEF23 H4) one word names one place: "darkshore" is Darkshore, not Duskwood's "darkshire"
				-- one letter off; the nearest spelling wins, and the first place at a tie
				for j, x in ipairs(others) do
					if x.at == m.at then
						taken = true
						if (m.dist or 0) < (x.dist or 0) then others[j] = m end
					end
				end
				if not taken then others[#others + 1] = m end
			end
		end
	end
	-- (BRIEF23 H4) the driver's own place against the others, word by word: the nearer spelling wins,
	-- the driver's own place at a tie ("summon to darkshore" in Duskwood is Darkshore, "darkshire" is ours)
	local keptOthers = {}
	for _, m in ipairs(others) do
		local best
		for _, x in ipairs(mine) do
			if x.at == m.at and (not best or (x.dist or 0) < best) then best = x.dist or 0 end
		end
		if not best or (m.dist or 0) < best then
			keptOthers[#keptOthers + 1] = m
			if best then
				for i = #mine, 1, -1 do if mine[i].at == m.at then table.remove(mine, i) end end
			end
		end
	end
	return mine, keptOthers
end

local TOPIC = {
	summon = true, summons = true, summoning = true, summoner = true, summonz = true, summonnig = true,
	sumon = true, sumons = true, summ = true, summs = true, sum = true, sums = true, summy = true,
	warlock = true, warlocks = true, lock = true, locks = true, lfs = true,
	-- (20 Nov hotfix, the author) riders who ask for a "portal" (or misspell it) take a summon just as well
	portal = true, portals = true, poral = true, porals = true, protal = true, portl = true, port = true, ports = true,
	tele = true, teleport = true,
}
local WANT = {
	wtb = true, lf = true, lfs = true, lfg = true, looking = true, need = true, needs = true, needing = true,
	any = true, anyone = true, anybody = true, someone = true, somebody = true,
	buying = true, buy = true, paying = true, pay = true, want = true, wanting = true, wanted = true,
	pls = true, plz = true, please = true, lookin = true, iso = true,
}
local WANT_PHRASES = { "can i", "could i", "can u", "can you", "could you", "can someone", "can somebody", "summon me", "sum me", "summ me", "port me", "need a", "need sum", "need summon", "need summons" }
local ADVERT_PHRASES = { "w me", "msg me", "pm me", "pst me", "pst for", "whisper for", "for only" }
local SELL = {
	wts = true, selling = true, sell = true, sells = true, offering = true, offer = true, available = true,
	avail = true, lfm = true, recruiting = true, guild = true, whisper = true, whisp = true, wisp = true,
	cheap = true, cheapest = true, open = true, ready = true,
}
local SOFT_SELL = { whisper = true, whisp = true, wisp = true, ready = true }
-- (20 Nov hotfix) seller words that only count when the line doesn't ask for anything: "portal service
-- 70s to org" is an advert, but "anyone doing a summon service to org?" is still a buyer
local SELLISH = { service = true, services = true, svc = true, business = true, pst = true, dm = true }
Mod.ADVERT_PHRASES = ADVERT_PHRASES
Mod.SELL = SELL
Mod.SELLISH = SELLISH
local JOINED = { "^lf(s?u?m+o?n?s?)$", "^wtb(s?u?m+o?n?s?)$" }

-- What a public chat line asks for: "match" (names my destination, or with several stations an open
-- one a crew Warlock summons from), "elsewhere", "noplace", "unclear" (two places, listed only), or
-- nil (not a buyer). A tagged [Wuber] line is an advert.
-- (2.4 fix round, LRN-06) A game link ("|Hitem:..|h[Name]|h": item, spell, quest, achievement, enchant, trade skill) in a
-- public line means the words are about the linked thing, not a ride request. Careful, the public reader and the
-- auto-reply all ask this one question; a whisper to the driver is not asked.
function DR.HasGameLink(text)
	return type(text) == "string" and text:find("|H%a+[:%d]", 1) ~= nil and text:find("|h", 1, true) ~= nil
end

function DR.PublicWant(text)
	if type(text) ~= "string" or #text > 160 then return nil end
	if DR.HasGameLink(text) then return nil end
	if text:lower():find("[wuber]", 1, true) then return nil end
	local norm = DR.Norm((text:gsub(">+", " to ")))   -- "org > uc" reads as "org to uc"
	local topic, want, sellish = false, text:find("?", 1, true) ~= nil, false
	local mineKw = {}
	local o = DR.opts and DR.opts() or {}
	for _, kw in ipairs(type(o.keywords) == "table" and o.keywords or {}) do
		kw = tostring(kw):lower()
		if #kw >= 3 and kw ~= "inv" and kw ~= "invite" and kw ~= "invites" then mineKw[kw] = true end
	end
	-- (AU24-03) "whisper"/"ready" are seller words only when the line does not ask to buy
	local buyer = false
	for w in norm:gmatch("%S+") do
		if w == "wtb" or w == "lf" or w == "lfs" or w == "lfg" then buyer = true end
		for _, p in ipairs(JOINED) do
			local rest = w:match(p)
			if rest and rest ~= "" and rest:find("^s?um") then buyer = true end
		end
	end
	for w in norm:gmatch("%S+") do
		if SELL[w] and not (buyer and SOFT_SELL[w]) then return nil end
		if TOPIC[w] or summonish(w) or topicish(w) or mineKw[w] then topic = true end
		if WANT[w] then want = true end
		if SELLISH[w] then sellish = true end
		for _, p in ipairs(JOINED) do
			local rest = w:match(p)
			if rest and rest ~= "" and rest:find("^s?um") then topic, want = true, true end
		end
	end
	if not topic then return nil end
	for _, p in ipairs(WANT_PHRASES) do
		if has(norm, p) then want = true end
	end
	if not want then
		for _, p in ipairs(ADVERT_PHRASES) do
			if has(norm, p) then return nil end
		end
		if sellish then return nil end
		-- a price with no ask is an advert: "70s", "1g", "50 silver", "2 gold"
		if norm:find(" %d+ ?[gs] ") or norm:find(" %d+ ?silver ") or norm:find(" %d+ ?gold ") then return nil end
	end
	local words = {}
	for w in norm:gmatch("%S+") do words[#words + 1] = w end
	local function notPlace(w)
		return TOPIC[w] or WANT[w] or SELLISH[w] or mineKw[w] or summonish(w) or topicish(w)
	end
	local mine, others = DR.Mentions(words)
	-- (AUD-47) with several open stations, a place one of them stands at is ours too
	if #others > 0 and DR.MultiStation and DR.MultiStation() then
		local kept = {}
		for _, m in ipairs(others) do
			local e, served = m.entry, false
			for _, st in ipairs(DR.Stations()) do
				if st.open and #st.summoners > 0 and e and (DR.PlaceEntry(st.place) == e
					or W.SamePlace(st.place, (e.place and e.place.name) or e[1])) then served = true end
			end
			if served then mine[#mine + 1] = m else kept[#kept + 1] = m end
		end
		others = kept
	end
	if #mine > 0 and #others > 0 then
		local function marked(list, set)
			for _, m in ipairs(list) do
				local before = wordBefore(words, m.at)
				if before and set[before] then return true end
			end
			return false
		end
		local mineTo, othersTo = marked(mine, TO), marked(others, TO)
		local mineFrom, othersFrom = marked(mine, FROM), marked(others, FROM)
		if mineTo and not othersTo then return "match" end
		if othersTo and not mineTo then return "elsewhere" end
		if mineFrom and not othersFrom then return "elsewhere" end
		if othersFrom and not mineFrom then return "match" end
		return "unclear"
	end
	if #mine > 0 then
		-- only "to my place" counts: a line naming only my place after "from"/"in"/"at" is where they are
		local function marked(set)
			for _, m in ipairs(mine) do
				local before = wordBefore(words, m.at)
				if before and set[before] then return true end
			end
			return false
		end
		if marked(TO) then return "match" end
		if marked(FROM) then return "elsewhere" end
		-- (BRIEF22 P1) "org to xanadu": a place nobody knows after "to" is where they go
		if unknownTo(words, covered({ mine, others }), DR.DestNames(), notPlace) then return "elsewhere" end
		return "match"
	end
	if not want then return nil end
	if #others > 0 then return "elsewhere" end
	-- (BRIEF22 P1) "Any summons to loch modan?" with no list knowing it: somewhere else, never a buyer
	if unknownTo(words, covered({ mine, others }), DR.DestNames(), notPlace) then return "elsewhere" end
	return "noplace"
end

-- (BRIEF18 00:53) The places a request (a whisper, a Wuber app line) asks to go to: { {name, to} },
-- to = written after "to". A place after "in"/"at"/"from" is where the rider stands, never where
-- they go ("summon pls, I'm in Ironforge"), so it is left out. Empty: no place named.
function DR.AskedPlaces(text)
	if type(text) ~= "string" or text == "" or #text > 200 then return {} end
	local norm = DR.Norm((text:gsub(">+", " to ")))
	local words = {}
	for w in norm:gmatch("%S+") do words[#words + 1] = w end
	local mine, others = DR.Mentions(words)
	local out, dest = {}, DR.Dest and DR.Dest() or ""
	local function add(m, name)
		local before = wordBefore(words, m.at)
		if before and FROM[before] then return end
		if type(name) == "string" and name ~= "" then out[#out + 1] = { name = name, to = before ~= nil and TO[before] == true } end
	end
	for _, m in ipairs(mine) do add(m, dest) end
	for _, m in ipairs(others) do
		local e = m.entry
		add(m, e and ((e.place and e.place.name) or e[1]) or m.name)
	end
	-- (BRIEF22 P1) a place nobody knows after "to" ("summon to astranaar"): asked for, as written
	local hasTo = false
	for _, p in ipairs(out) do if p.to then hasTo = true end end
	if not hasTo then
		local w = unknownTo(words, covered({ mine, others }), DR.DestNames(),
			function(x) return TOPIC[x] or WANT[x] or summonish(x) or topicish(x) end)
		if w then out[#out + 1] = { name = (w:gsub("^%l", string.upper)), to = true } end
	end
	return out
end

---------------------------------------------------------------------------
-- Stations (SPEC4 2): several crew Warlocks summoning from different places, one service
---------------------------------------------------------------------------
-- A station = a place where at least one of the crew's summoners stands. Riders are routed
-- to the station their destination names; each summoner's button plans its own station.
-- One station (or none) = 2.0 exactly.

local function placeOfMap(map)
	local CM = rawget(_G, "C_Map")
	if not map or type(CM) ~= "table" or type(CM.GetMapInfo) ~= "function" then return nil end
	local ok, info = pcall(CM.GetMapInfo, map)
	info = ok and W.Plain(info)
	local name = type(info) == "table" and W.Str(info.name) or nil
	if not name then return nil end
	local p = W.FindPlace and W.FindPlace(name)
	return (p and p.name) or W.CleanDest(name)
end

local function mapOf(unit)
	local CM = rawget(_G, "C_Map")
	if not unit or type(CM) ~= "table" or type(CM.GetBestMapForUnit) ~= "function" then return nil end
	local ok, m = pcall(CM.GetBestMapForUnit, unit)
	return ok and W.Num(m) or nil
end
DR.MapOf = mapOf

-- (r54 FAB-11) Whether a map is a continent, the world or the cosmos (C_Map mapType 2, 1, 0): nobody stands at
-- such a map's name. A secret or unknown type: no.
local function onWideMap(map)
	local CM = rawget(_G, "C_Map")
	if not map or type(CM) ~= "table" or type(CM.GetMapInfo) ~= "function" then return false end
	local ok, info = pcall(CM.GetMapInfo, map)
	info = ok and W.Plain(info)
	local t = type(info) == "table" and W.Num(info.mapType) or nil
	return t ~= nil and t <= 2
end

-- (AUD-45) The town a unit stands at on map `map` (W.PlaceAt on its map position), or nil:
-- out of range, in an instance or no town near. Never a zone. (r32 AUD-50) false, not nil, when
-- the position is known and no town is near (out in the zone).
local function townOf(unit, map)
	local CM = rawget(_G, "C_Map")
	if not (unit and map) or type(CM) ~= "table" or type(CM.GetPlayerMapPosition) ~= "function" then return nil end
	local ok, pos = pcall(CM.GetPlayerMapPosition, map, unit)
	if not ok or pos == nil or W.Plain(pos) == nil then return nil end
	local okXY, x, y = pcall(function() return pos:GetXY() end)
	if not okXY then return nil end
	x, y = W.Num(x), W.Num(y)
	local p = W.PlaceAt and x and y and W.PlaceAt(map, x, y)
	if p then return W.Str(p.name) or nil end
	if x and y and W.PlaceAt then return false end
	return nil
end

-- Where a crew member (key) or a unit stands: place name, map id. Me: the place for my
-- subzone, else my zone (W.DestHere); others: their HI, else the town at their map position,
-- else their map's name.
function DR.PlaceOf(who)
	if who == nil then return nil end
	if who == "player" or who == W.myKey then
		local ok, name, place = pcall(W.DestHere)
		name = ok and W.Str(name) or nil
		if name == "Unknown" then name = nil end
		local map = mapOf("player")
		-- (r54 FAB-11) the first moments after a login (or a loading screen) the game puts the player on the
		-- continent's or the world's map with no zone text yet: "Kalimdor" is no place we stand at, not known yet
		if name and not (ok and place) and onWideMap(map) then name = nil end
		return name, map
	end
	local unit, key = nil, who
	if DR.units[who] then
		unit = DR.units[who]
	elseif type(who) == "string" and who:match("^%a+%d*$") and not who:find(" ") and rawget(_G, "UnitExists") then
		unit = who
		key = W.Key(W.UnitName(who))
	end
	local app = key and (DR.peers[key] or DR.apps[key])
	if app and app.place then return app.place, app.map end
	local map = mapOf(unit)
	if not map then return nil end
	return townOf(unit, map) or placeOfMap(map), map
end

local function stationOff(place)
	local ch = DR.char()
	local list = (ch.captain == "") and ch.stations or (DR.crewStations or {})
	for p, on in pairs(list) do
		if on == false and W.SamePlace(p, place) then return true end
	end
	return false
end

local cache = { at = nil, out = nil }
W.Listen("DRIVE_STATIONS", function() cache.at = nil end)

-- Every station: { place, map, summoners = {keys}, helpers = {keys}, open, ready }. The
-- runner's own station first, then in the summoners' order. (Worked out once per moment.)
function DR.Stations()
	local now = GetTime()
	if cache.at == now and cache.out then return cache.out end
	local out = DR.WorkStations()
	cache.at, cache.out = now, out
	return out
end

function DR.WorkStations()
	local out, byPlace = {}, {}
	local keys = {}
	local chosen = DR.Summoners and DR.Summoners() or {}
	if #chosen > 0 then
		for _, k in ipairs(chosen) do keys[#keys + 1] = k end
	else
		if DR.IsWarlock() then keys[1] = W.myKey end
		local lst = {}
		for k in pairs(DR.units) do
			local m = DR.CrewEntry(k)
			local peer = DR.peers[k]
			if (m and m.role == "lock" and (m.app == false or peer)) or (peer and peer.role == "L" and DR.TrustKey(k)) then
				lst[#lst + 1] = k
			end
		end
		table.sort(lst)
		for _, k in ipairs(lst) do keys[#keys + 1] = k end
	end
	local function stationAt(place, map)
		local n = W.NormPlace(place)
		local st = byPlace[n]
		if not st then
			st = { place = place, map = map, summoners = {}, helpers = {}, open = not stationOff(place) }
			byPlace[n] = st
			out[#out + 1] = st
		end
		st.map = st.map or map
		return st
	end
	local isSummoner = {}
	for _, k in ipairs(keys) do
		if k == W.myKey or DR.units[k] then
			local place, map = DR.PlaceOf(k)
			if place then
				local st = stationAt(place, map)
				st.summoners[#st.summoners + 1] = k
				isSummoner[k] = true
			end
		end
	end
	-- the helpers (any crew member, the runner too) where they stand
	local others = { W.myKey }
	for _, m in ipairs(DR.char().crew) do others[#others + 1] = W.Key(m.name) end
	local cap = DR.char().captain
	if cap ~= "" then others[#others + 1] = W.Key(cap) end
	local runnerPlace
	for _, k in ipairs(others) do
		if k and not isSummoner[k] and (k == W.myKey or DR.units[k]) then
			local place = DR.PlaceOf(k)
			local st = place and byPlace[W.NormPlace(place)]
			if st then
				local dup = false
				for _, h in ipairs(st.helpers) do if h == k then dup = true end end
				if not dup then st.helpers[#st.helpers + 1] = k end
			end
		end
		if k and k == DR.CaptainKey() then runnerPlace = DR.PlaceOf(k) end
	end
	for _, st in ipairs(out) do
		st.ready = #st.summoners >= 1 and #st.summoners + #st.helpers >= 3
	end
	if runnerPlace then
		for i, st in ipairs(out) do
			if W.SamePlace(st.place, runnerPlace) and i > 1 then
				table.remove(out, i)
				table.insert(out, 1, st)
				break
			end
		end
	end
	return out
end

local function openStations()
	local out = {}
	for _, st in ipairs(DR.Stations()) do
		if st.open then out[#out + 1] = st end
	end
	return out
end

-- Two or more open stations: riders are routed (else 2.0 exactly).
function DR.MultiStation()
	if DR.Mode and DR.Mode() == "raid" then return false end
	return #openStations() >= 2
end

-- "Undercity, Orgrimmar": where we summon to (open stations).
function DR.StationList()
	local names = {}
	for _, st in ipairs(openStations()) do names[#names + 1] = st.place end
	return table.concat(names, ", ")
end

-- The runner switches a station off (or on again). Synced in CFG.
function DR.SetStation(place, on)
	place = W.Clean(place or "", 32)
	if place == "" or DR.char().captain ~= "" then return false end
	local list = DR.char().stations
	for p in pairs(list) do
		if W.SamePlace(p, place) then list[p] = nil end
	end
	if not on then list[place] = false end
	cache.at = nil
	if DR.SendConfig then DR.SendConfig() end
	W.Fire("DRIVE_STATIONS")
	DR.Changed()
	return true
end

-- The station (place name) a rider was routed to, or nil.
function DR.StationOf(name)
	local c = name and DR.Find and DR.Find(name)
	return c and c.station or nil
end

-- The station where this window stands: place, station; nil when I am at none.
function DR.MyStation()
	local place = DR.PlaceOf("player")
	if not place then return nil end
	for _, st in ipairs(DR.Stations()) do
		if W.SamePlace(st.place, place) then return st.place, st end
	end
	return nil
end

-- Whether this window's button plans this rider: always with one station; with several,
-- only riders of the station I stand at (a window at no station plans everyone).
function DR.ForMyStation(c)
	if not c or not c.station or not DR.MultiStation() then return true end
	local mine = DR.MyStation()
	if not mine then return true end
	return W.SamePlace(mine, c.station)
end

-- The place a line names (a whisper, a Wuber request), as Wuber writes it, or nil.
-- (r28 AUD-46) A known place after "to" wins, and a place after "from"/"in"/"at" is where the
-- rider stands, so "from Ironforge to UC" is Undercity; otherwise the longest name the line holds.
local function placeName(entry)
	return entry and ((entry.place and entry.place.name) or entry[1]) or nil
end
function DR.DestIn(text)
	if type(text) ~= "string" or text == "" then return nil end
	local longest = placeName(DR.PlaceIn(DR.Norm(text)))
	if not longest then return nil end
	local known, longestAsked = {}, false
	for _, p in ipairs(DR.AskedPlaces(text)) do
		local name = placeName(DR.PlaceIn(DR.Norm(p.name)))
		if name then
			if p.to then return name end
			known[#known + 1] = name
			if name == longest then longestAsked = true end
		end
	end
	if not longestAsked and known[1] then return known[1] end
	return longest
end

-- Routes a rider (SPEC4 2.2): "ok" (c.station set, or one station), "ask" (no place named:
-- the station they have if it is still open, else the runner's, and "Where to?" once: c.askWhere), "elsewhere" (a place no open
-- station summons to: not queued, c.elsewhere).
function DR.Route(c, text)
	if not c then return "ok" end
	local dest = DR.DestIn(text)
	if dest then c.dest = dest end
	if DR.relayStation then
		c.station, c.askWhere = DR.relayStation, nil
		return "ok"
	end
	local list = openStations()
	if #list < 2 then
		c.station = list[1] and list[1].place or nil
		return "ok"
	end
	if c.dest then
		for _, st in ipairs(list) do
			if W.SamePlace(st.place, c.dest) then
				c.station, c.askWhere, c.elsewhere = st.place, nil, nil
				return "ok"
			end
		end
		return "elsewhere"
	end
	-- (r32 AUD-51) a station kept from an earlier ride that is closed now (or gone) is replaced
	local keep = false
	for _, st in ipairs(list) do
		if c.station and W.SamePlace(st.place, c.station) then keep = true end
	end
	if not keep then c.station = list[1].place end
	if not c.whereTold then c.askWhere = true end
	return "ask"
end

-- Arrived (SPEC4 2.2): with one station, or at the station I stand at, here (DR.Here: I can see
-- them). (r32 AUD-50) At another window's station: on its map and, for a town station, at that
-- town by their map position (only the map when the position is unknown).
function DR.ArrivedAt(c, unit)
	local sim = DR.SimHooks -- the test addon's shard-free test mode (SPEC5): see DR.Here
	if sim and sim.here and unit then
		local ok, v = pcall(sim.here, unit, c)
		if ok and v == true then return true end
	end
	if c and c.station and DR.MultiStation() then
		local mine = DR.MyStation()
		if mine and W.SamePlace(mine, c.station) then return DR.Here(unit) end
		for _, st in ipairs(DR.Stations()) do
			if W.SamePlace(st.place, c.station) and st.map then
				local m = mapOf(unit)
				if m then
					if m ~= st.map then return false end
					local zone = placeOfMap(st.map)
					if zone and W.SamePlace(zone, st.place) then return true end
					local town = townOf(unit, m)
					if town == nil then return true end
					return town ~= false and W.SamePlace(town, st.place)
				end
			end
		end
	end
	return DR.Here(unit)
end
