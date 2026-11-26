-- The hunt's situations (tests/hunt/README.md): loads the dial files in a fixed order and gives the sets.
--   local Sit = dofile("tests/hunt/situations.lua")(Hunt)   (lib.lua does this; it is Hunt.Sit)
--   Sit.loadDials()                        every tests/hunt/dials/*.lua, sorted by file name; a broken one is reported
--   Sit.pairs(domains, accept, seed)       a pairwise covering set: every allowed pair of dial values in at least one
--                                          situation (greedy, seeded; excludes and accept() honoured) -> list, info
--   Sit.random(domains, accept, seed, n)   n different random situations -> list
--   Sit.forPromise(p, mode, seed, n)       a promise's set: its needs fixed, its when() and excludes honoured
--   Sit.stats                              { hits, made, written }: pairwise sets read from / made into the set cache
--   Sit.useCache = false                   (sweep.lua --no-cache) never read or write the cache
--   Sit.promiseSig(p)                      a hash of everything a promise's result depends on in the hunt (sweep --resume)
-- Every situation handed out is one every dial's valid(fullSituation) accepts (Hunt.compatible, via acceptFull).
-- The set cache (tests/out/hunt/cache/<hash>.lua): a pairwise set is written once made in full and read back when the
-- hash matches: the dials (names, values, excludes, whether they have valid), the contents of every file under
-- tests/hunt/dials and tests/hunt/fixtures, of lib.lua and situations.lua, and for a promise with needs or when its
-- id, needs, the contents of its file and the seed. A promise with neither shares one set (the key says "plain").
-- domains: { [dialName] = { valueId, ... } } (Hunt.domains(p)); a situation is a full { [dialName] = valueId }.
-- Deterministic from the seed: never math.random.
return function(Hunt)
	local Sit = { cache = {} }

	function Sit.loadDials()
		for _, path in ipairs(Hunt.listLua(Hunt.DIR .. "/dials")) do Hunt.loadFile(path) end
	end

	Sit.stats = { hits = 0, made = 0, written = 0 }
	Sit.useCache = true

	local function names() local out = {} for _, d in ipairs(Hunt.dialOrder) do out[#out + 1] = d.name end return out end

	-- may dial a's value va and dial b's value vb exist together (excludes, both ways)?
	local function pairOk(a, va, b, vb)
		local da, db = Hunt.dials[a], Hunt.dials[b]
		local x = da.byId[va].excludes
		if x and x[b] and Hunt.contains(type(x[b]) == "table" and x[b] or { x[b] }, vb) then return false end
		local y = db.byId[vb].excludes
		if y and y[a] and Hunt.contains(type(y[a]) == "table" and y[a] or { y[a] }, va) then return false end
		return true
	end

	local function key(sit)
		local parts = {}
		for _, n in ipairs(names()) do parts[#parts + 1] = n .. "=" .. tostring(sit[n]) end
		return table.concat(parts, ",")
	end
	Sit.key = key

	local function acceptFull(sit, accept)
		if not Hunt.compatible(sit) then return false end
		if accept then
			local ok, res = pcall(accept, sit)
			return ok and res and true or false
		end
		return true
	end

	-- the greedy pairwise covering set (AETG style): each new situation starts from an uncovered pair and
	-- fills the other dials with the value that covers the most new pairs (ties by the generator); the best
	-- of a few candidates is kept. A pair no situation can hold (excludes, accept) is dropped after a few tries.
	-- Dials and values are numbered (numeric keys: fast enough for 60 dials).
	-- (the body; emit(sit) is called for each situation as it is added: Sit.pairsStream hands them out one by one)
	local function pairsBody(domains, accept, seed, opts, emit)
		opts = opts or {}
		local rng = Hunt.rng(seed or 1):fork("pairs")
		local all = names()
		local free, fixed = {}, {}
		for _, n in ipairs(all) do
			local dom = domains[n]
			if #dom == 1 then fixed[n] = dom[1] else free[#free + 1] = n end
		end
		local out, seen = {}, {}
		local function add(sit)
			local k = key(sit)
			if seen[k] then return false end
			seen[k] = true
			out[#out + 1] = sit
			if emit then emit(sit) end
			return true
		end
		if #free == 0 then
			local sit = Hunt.copy(fixed)
			if acceptFull(sit, accept) then add(sit) end
			return out, { pairs = 0, dropped = 0 }
		end
		if #free == 1 then
			local n = free[1]
			for _, v in ipairs(domains[n]) do
				local sit = Hunt.copy(fixed)
				sit[n] = v
				if acceptFull(sit, accept) then add(sit) end
			end
			return out, { pairs = 0, dropped = 0 }
		end
		local F = #free
		local vals = {} -- vals[i] = the value ids of free dial i
		for i, n in ipairs(free) do vals[i] = domains[n] end
		-- may value a of free dial i stand with value b of free dial j (and with every fixed dial)?
		local okFixed = {}
		for i, n in ipairs(free) do
			okFixed[i] = {}
			for a, v in ipairs(vals[i]) do
				local good = true
				for fn, fv in pairs(fixed) do if not pairOk(n, v, fn, fv) then good = false break end end
				okFixed[i][a] = good
			end
		end
		local function pk(i, a, j, b)
			if i > j then i, a, j, b = j, b, i, a end
			return ((i * 128 + a) * 128 + j) * 128 + b
		end
		-- the base situation (each dial's default where the domain has it) and which single values accept() takes
		-- on it: a pair with a value it does not take is tried once on the base, and dropped when that fails too
		-- (a promise's when() rules out whole values, e.g. a phone screen: never loop over those pairs)
		local base = {}
		for i, n in ipairs(free) do
			base[i] = 1
			for a, v in ipairs(vals[i]) do if v == Hunt.dials[n].default and okFixed[i][a] then base[i] = a end end
		end
		local function baseWith(i, a, j, b)
			local sit = Hunt.copy(fixed)
			for x = 1, F do sit[free[x]] = vals[x][base[x]] end
			sit[free[i]] = vals[i][a]
			if j then sit[free[j]] = vals[j][b] end
			return sit
		end
		-- a promise whose when() rules out the default situation (e.g. it needs a ride that has ended): the base is
		-- a situation it does accept, found at random (its own generator: the sets of other promises do not change);
		-- none found in 1000 tries: no set (instead of trying every pair against a base that can never pass)
		if not acceptFull(baseWith(1, base[1]), accept) then
			local brng = Hunt.rng(seed or 1):fork("pairs-base")
			local found
			for _ = 1, 1000 do
				local pick = {}
				for x = 1, F do
					local okv = {}
					for a = 1, #vals[x] do if okFixed[x][a] then okv[#okv + 1] = a end end
					pick[x] = okv[brng:int(math.max(1, #okv))] or 1
				end
				local sit = Hunt.copy(fixed)
				for x = 1, F do sit[free[x]] = vals[x][pick[x]] end
				if acceptFull(sit, accept) then found = pick break end
			end
			if not found then return out, { pairs = 0, dropped = 0, nobase = true } end
			base = found
		end
		-- the pair on a few random situations (another dial's value may be what stood in its way)
		local function repaired(i, a, j, b)
			for _ = 1, 4 do
				local sit = Hunt.copy(fixed)
				for x = 1, F do sit[free[x]] = vals[x][rng:int(#vals[x])] end
				sit[free[i]], sit[free[j]] = vals[i][a], vals[j][b]
				if acceptFull(sit, accept) then return true end
			end
			return false
		end
		local single = {}
		for i = 1, F do
			single[i] = {}
			for a = 1, #vals[i] do single[i][a] = okFixed[i][a] and acceptFull(baseWith(i, a), accept) end
		end
		local bad = {}
		local unc, list, index = {}, {}, {}
		local dropped = 0
		for i = 1, F do
			for j = i + 1, F do
				for a, va in ipairs(vals[i]) do
					for b, vb in ipairs(vals[j]) do
						local k = pk(i, a, j, b)
						if not pairOk(free[i], va, free[j], vb) then bad[k] = true
						elseif not (okFixed[i][a] and okFixed[j][b]) then
							-- never possible
						elseif not (single[i][a] and single[j][b]) and not acceptFull(baseWith(i, a, j, b), accept)
							and not repaired(i, a, j, b) then
							dropped = dropped + 1
						elseif true then
							unc[k] = { i = i, a = a, j = j, b = b, fails = 0 }
							list[#list + 1] = k
							index[k] = #list
						end
					end
				end
			end
		end
		local total = #list
		local function cover(k)
			local pos = index[k]
			if not pos then return end
			local last = list[#list]
			list[pos], index[last] = last, pos
			list[#list] = nil
			index[k], unc[k] = nil, nil
		end
		local function toSit(pick)
			local sit = Hunt.copy(fixed)
			for i = 1, F do sit[free[i]] = vals[i][pick[i]] end
			return sit
		end
		local CANDIDATES = opts.candidates or 8
		local guardN = 0
		while #list > 0 do
			guardN = guardN + 1
			if guardN > 50000 then break end
			local best, bestSit, bestScore, tried = nil, nil, -1, {}
			for _ = 1, CANDIDATES do
				local k = list[rng:int(#list)]
				local pr = unc[k]
				tried[#tried + 1] = k
				local pick, set = {}, {}
				pick[pr.i], pick[pr.j] = pr.a, pr.b
				set[1], set[2] = pr.i, pr.j
				local order = {}
				for i = 1, F do if i ~= pr.i and i ~= pr.j then order[#order + 1] = i end end
				rng:shuffle(order)
				local okc = true
				for _, i in ipairs(order) do
					local bestN, ties = -1, {}
					for a = 1, #vals[i] do
						if single[i][a] then
							local c, okv = 0, true
							for _, m in ipairs(set) do
								local kk = pk(i, a, m, pick[m])
								if bad[kk] then okv = false break end
								if unc[kk] then c = c + 1 end
							end
							if okv then
								if c > bestN then bestN, ties = c, { a } elseif c == bestN then ties[#ties + 1] = a end
							end
						end
					end
					if #ties == 0 then okc = false break end
					pick[i] = rng:pick(ties)
					set[#set + 1] = i
				end
				if okc then
					local sit = toSit(pick)
					if not seen[key(sit)] and acceptFull(sit, accept) then
						local score = 0
						for i = 1, F do
							for j = i + 1, F do if unc[pk(i, pick[i], j, pick[j])] then score = score + 1 end end
						end
						if score > bestScore then best, bestSit, bestScore = pick, sit, score end
					end
				end
			end
			if best and bestScore > 0 then
				for i = 1, F do
					for j = i + 1, F do
						local kk = pk(i, best[i], j, best[j])
						if unc[kk] then cover(kk) end
					end
				end
				add(bestSit)
			else
				for _, k in ipairs(tried) do
					local pr = unc[k]
					if pr then
						pr.fails = pr.fails + 1
						if pr.fails >= 3 then cover(k) dropped = dropped + 1 end
					end
				end
			end
		end
		return out, { pairs = total, dropped = dropped }
	end


	---------------------------------------------------------------------------
	-- the set cache
	---------------------------------------------------------------------------
	local fileMemo, baseMemo = {}, nil
	local function hash3(s)
		s = tostring(s)
		return ("%08x%08x%08x"):format(Hunt.hash(s, 5381), Hunt.hash(s, 7919), Hunt.hash(s, 104729))
	end
	local function fileSig(path)
		if not fileMemo[path] then fileMemo[path] = hash3(Hunt.readFile(path) or "(missing)") end
		return fileMemo[path]
	end
	-- the dials and the hunt's own files: anything that can change a set
	local function baseSig()
		if baseMemo and baseMemo.n == #Hunt.dialOrder then return baseMemo.sig end
		local parts, seen = { "setcache-1" }, {}
		for _, dir in ipairs({ Hunt.DIR .. "/dials", Hunt.DIR .. "/fixtures", Hunt.DIR .. "/fixtures/saved" }) do
			for _, path in ipairs(Hunt.listLua(dir)) do
				if not seen[path] then seen[path] = true parts[#parts + 1] = path:match("[^/]*$") .. "=" .. fileSig(path) end
			end
		end
		parts[#parts + 1] = "lib=" .. fileSig(Hunt.SRCDIR .. "/lib.lua")
		parts[#parts + 1] = "sit=" .. fileSig(Hunt.SRCDIR .. "/situations.lua")
		for _, d in ipairs(Hunt.dialOrder) do
			local vs = {}
			for _, v in ipairs(d.values) do vs[#vs + 1] = v.id .. Hunt.ser(v.excludes or {}) end
			parts[#parts + 1] = d.name .. ":" .. tostring(d.default) .. ":" .. tostring(d.phase) .. ":" .. (d.valid and "valid" or "-") .. ":" .. table.concat(vs, "|")
		end
		local sig = hash3(table.concat(parts, "\n"))
		baseMemo = { n = #Hunt.dialOrder, sig = sig }
		return sig
	end

	-- the file a promise is in (nil for one made by a script: no cache, no resume)
	local function promiseFile(p)
		if not (p and p.file and p.file ~= "(no file)") then return nil end
		return Hunt.ROOT .. "/" .. p.file
	end

	function Sit.promiseSig(p)
		local f = promiseFile(p)
		if not f then return nil end
		return hash3(baseSig() .. "|" .. p.id .. "|" .. fileSig(f))
	end

	-- the cache key of a pairwise set: kind "pairs" (a promise's) or "walk" (the walk starts' pairs); nil = not cacheable
	local function cacheKey(kind, p, seed)
		if not Sit.useCache then return nil end
		local parts = { baseSig(), kind, tostring(seed or 1) }
		if p then
			if not p.needs and not p.when then
				parts[#parts + 1] = "plain"
			else
				local f = promiseFile(p)
				if not f then return nil end
				parts[#parts + 1] = p.id .. "|" .. Hunt.ser(p.needs or {}) .. "|" .. fileSig(f)
			end
		end
		return table.concat(parts, "/")
	end
	local function cachePath(key) return Hunt.ROOT .. "/tests/out/hunt/cache/" .. hash3(key) .. ".lua" end

	local function cacheLoad(key)
		local chunk = loadfile(cachePath(key))
		if not chunk then return nil end
		local ok, res = pcall(chunk)
		if not (ok and type(res) == "table" and res.key == key and type(res.sits) == "table" and res.n == #res.sits) then return nil end
		local list = {}
		for i, s in ipairs(res.sits) do
			local okf, full = pcall(function() return Hunt.full(Hunt.parseSit(s)) end)
			if not okf then return nil end
			list[i] = full
		end
		Sit.stats.hits = Sit.stats.hits + 1
		return list, res.info or {}
	end

	local madeDir = false
	local function cacheSave(key, list, info)
		local path = cachePath(key)
		local sits = {}
		for i, s in ipairs(list) do sits[i] = Hunt.sitString(s, false) end
		local text = "-- a pairwise set made by tests/hunt/situations.lua (the hunt's set cache; safe to delete)\nreturn "
			.. Hunt.ser({ key = key, n = #sits, info = info or {}, sits = sits }) .. "\n"
		if not madeDir then Hunt.mkdir(Hunt.ROOT .. "/tests/out/hunt/cache") madeDir = true end
		local tn = (os.tmpname() or "x"):gsub("\\", "/"):match("([^/]*)$"):gsub("[^%w]", "")
		local tmp = path .. "." .. tn .. tostring(math.floor(os.clock() * 1000)) .. ".tmp"
		local f = io.open(tmp, "wb")
		if not f then return end
		f:write(text)
		f:close()
		if os.rename(tmp, path) then Sit.stats.written = Sit.stats.written + 1 else os.remove(tmp) end
	end

	function Sit.pairs(domains, accept, seed, opts) return pairsBody(domains, accept, seed, opts) end

	-- the same set as Sit.pairs, in the same order, made as it is asked for: next() -> a situation, or nil at the end
	-- (a time-limited sweep uses the first few situations of a set; the greedy cover gives the most new pairs first)
	function Sit.pairsStream(domains, accept, seed, opts)
		local co = coroutine.create(function() pairsBody(domains, accept, seed, opts, coroutine.yield) end)
		local finished = false
		return function()
			if finished then return nil end
			local okc, sit = coroutine.resume(co)
			if not okc then finished = true error(sit, 0) end
			if coroutine.status(co) == "dead" then finished = true return nil end
			return sit
		end
	end

	function Sit.random(domains, accept, seed, n, skip)
		local rng = Hunt.rng(seed or 1):fork("random")
		local out, seen = {}, {}
		for k in pairs(skip or {}) do seen[k] = true end
		local tries = 0
		while #out < n and tries < n * 30 + 100 do
			tries = tries + 1
			local sit = {}
			for _, name in ipairs(names()) do sit[name] = rng:pick(domains[name]) end
			local k = key(sit)
			if not seen[k] and acceptFull(sit, accept) then
				seen[k] = true
				out[#out + 1] = sit
			end
		end
		return out
	end

	-- a promise's set: mode "pairs" (the pairwise set) or "random" (n samples); nil and why when it has none
	function Sit.forPromise(p, mode, seed, n, skip)
		local dom, why = Hunt.domains(p)
		if not dom then return nil, why end
		local accept = function(sit)
			local okp, full = pcall(Hunt.project, p, sit)
			if not (okp and full) then return false end
			for k, v in pairs(full) do if sit[k] ~= v then return false end end
			return true
		end
		-- a promise with no needs and no when shares one set per mode and seed (the always-promises: built once)
		local plain = not p.needs and not p.when and not skip
		local ck = plain and (mode .. "\1" .. tostring(seed) .. "\1" .. tostring(n) .. "\1" .. #Hunt.dialOrder)
		if ck and Sit.cache[ck] then return Sit.cache[ck][1], Sit.cache[ck][2] end
		local s = Hunt.hash(plain and "plain" or p.id, seed or 1)
		local list, info
		if mode == "random" then
			list = Sit.random(dom, accept, s, n or 50, skip)
		else
			local key = not skip and cacheKey("pairs", p, seed)
			if key then list, info = cacheLoad(key) end
			if not list then
				list, info = Sit.pairs(dom, accept, s)
				if key then Sit.stats.made = Sit.stats.made + 1 cacheSave(key, list, info) end
			end
		end
		if ck then Sit.cache[ck] = { list, info } end
		return list, info
	end

	-- a promise's set handed out one by one: next() -> situation or nil; nil and why when it has none
	-- (mode "pairs": Sit.pairsStream; "random": the list of Sit.forPromise)
	function Sit.forPromiseStream(p, mode, seed, n, skip)
		if mode ~= "pairs" then
			local list, why = Sit.forPromise(p, mode, seed, n, skip)
			if not list then return nil, why end
			local i = 0
			return function() i = i + 1 return list[i] end
		end
		local dom, why = Hunt.domains(p)
		if not dom then return nil, why end
		local plain = not p.needs and not p.when and not skip
		if plain then
			-- (shared with the other plain promises: Sit.forPromise's cache)
			local list = Sit.forPromise(p, mode, seed, n, skip)
			local i = 0
			return function() i = i + 1 return list[i] end
		end
		local accept = function(sit)
			local okp, full = pcall(Hunt.project, p, sit)
			if not (okp and full) then return false end
			for k, v in pairs(full) do if sit[k] ~= v then return false end end
			return true
		end
		local key = cacheKey("pairs", p, seed)
		if key then
			local cl = cacheLoad(key)
			if cl then
				local i = 0
				return function() i = i + 1 return cl[i] end
			end
		end
		local stream = Sit.pairsStream(dom, accept, Hunt.hash(p.id, seed or 1))
		if not key then return stream end
		-- (written once the set has been made in full: a time-limited run that stops early leaves nothing half-cached)
		local got, saved = {}, false
		return function()
			local s = stream()
			if s then
				got[#got + 1] = s
			elseif not saved then
				saved = true
				Sit.stats.made = Sit.stats.made + 1
				cacheSave(key, got, {})
			end
			return s
		end
	end

	-- every dial's values with no promise (for walks): random situations
	function Sit.any(seed, n) return Sit.random(Hunt.domains(nil), nil, seed, n) end

	-- the starts of long sessions: the pairwise set over every dial, then random situations (n in all, at least);
	-- walk j of n tries list[j], list[j + n], list[j + 2n] ... until one builds (the same in every shard)
	function Sit.walkStarts(seed, n)
		local ck = "walk\1" .. tostring(seed) .. "\1" .. tostring(n) .. "\1" .. #Hunt.dialOrder
		if Sit.cache[ck] then return Sit.cache[ck] end
		local dom = Hunt.domains(nil)
		local list
		local wkey = cacheKey("walk", nil, seed)
		if wkey then list = cacheLoad(wkey) end
		if not list then
			list = Sit.pairs(dom, nil, Hunt.hash("walk-pairs", seed or 1))
			if wkey then Sit.stats.made = Sit.stats.made + 1 cacheSave(wkey, list, {}) end
		end
		local skip = {}
		for _, s in ipairs(list) do skip[key(s)] = true end
		local want = math.max(n or 0, 1) * 12
		for _, s in ipairs(Sit.random(dom, nil, Hunt.hash("walk-random", seed or 1), math.max(0, want - #list) + 50, skip)) do list[#list + 1] = s end
		Sit.cache[ck] = list
		return list
	end

	return Sit
end
