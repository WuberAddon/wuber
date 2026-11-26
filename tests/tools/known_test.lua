-- tests/tools/known_test.lua: what the hunt calls KNOWN (tests/hunt/lib/shrink.lua Hunt.knownFind, used by markKnown in
-- tools/hunt/sweep.lua). A finding is known only for the same promise AND the same line; the same promise with another line
-- is NEW (but linked); a known-elsewhere.tsv row with a line covers only that line, a row without one covers the promise.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local Hunt = dofile(T.dir .. "/hunt/lib.lua").init()
local root = T.dir .. "/out/known-selftest"

local function put(path, text)
	local f = assert(io.open(path, "wb"))
	f:write(text)
	f:close()
end
local function mkdir(path)
	if package.config:sub(1, 1) == "\\" then os.execute('mkdir "' .. path:gsub("/", "\\") .. '" 2>nul')
	else os.execute('mkdir -p "' .. path .. '"') end
end

local PROMISE, LINE, OTHER = "bell.crewmate_refused", "You tap the bell and nothing rings.", "You tap the bell and a crewmate is refused."
local function setup()
	mkdir(root .. "/repro")
	put(root .. "/repro/bell.crewmate_refused--one.lua", "-- KNOWN\nos.exit(Hunt.repro({\n\tid = \"bell.crewmate_refused--one\",\n\tpromise = \"" .. PROMISE .. "\",\n\tseed = 1,\n\tseen = \"" .. LINE .. "\",\n\tsituation = {},\n}))\n")
	put(root .. "/known-elsewhere.tsv", "# header\n"
		.. "p.with_line\tAUD-1\tone bug\t" .. LINE .. "\n"
		.. "p.digits\tAUD-3\tdigits blanked\tThe card says it saves 5 gold.\n"
		.. "p.whole\tAUD-2\twhole promise\n")
	return Hunt.knownMap(root .. "/repro"), Hunt.knownElsewhere(root .. "/known-elsewhere.tsv")
end

test("hunt known: same promise and same line is known; the same promise with another line is NEW and linked", function()
	local map, else_ = setup()
	local e, how = Hunt.knownFind(map, PROMISE, LINE, else_)
	ok(e, "the same line is known")
	eq(how, "same line")
	local e2, how2, link = Hunt.knownFind(map, PROMISE, OTHER, else_)
	eq(e2, nil, "another line of the same promise is not known")
	eq(how2, nil)
	ok(link and link.id == "bell.crewmate_refused--one", "but it names the repro of the same promise")
end)

test("hunt known: a known-elsewhere row with a line covers only that line; without a line it covers the promise (marked)", function()
	local map, else_ = setup()
	local e, how = Hunt.knownFind(map, "p.with_line", LINE, else_)
	ok(e and how == "elsewhere", "its own line is known elsewhere")
	eq(e.whole, nil, "a row with a line is not marked whole-promise")
	eq((Hunt.knownFind(map, "p.with_line", OTHER, else_)), nil, "another line of that promise is new")
	ok(Hunt.knownFind(map, "p.digits", "The card says it saves 7 gold.", else_), "a line differing only in digits is the same line")
	eq((Hunt.knownFind(map, "p.digits", "The card says it saves nothing.", else_)), nil, "another wording is new")
	local w, how3 = Hunt.knownFind(map, "p.whole", OTHER, else_)
	ok(w and how3 == "elsewhere", "a row without a line keeps the whole promise")
	eq(w.whole, true, "marked: whole promise, line not checked")
end)
