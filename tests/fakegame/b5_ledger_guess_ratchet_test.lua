-- Client API ledger guess ratchet (issue #129):
-- Counts rows with evidence = "guess" per family in tests/fixtures/client/api/*.lua
-- and compares against tests/fixtures/client/guess-ratchet.txt so guesses can only go down.
local T = ...
local test, eq, ok = T.testOutside or T.test, T.eq, T.ok

local ROOT = T.dir .. "/.."
local API_DIR = ROOT .. "/tests/fixtures/client/api"
local RATCHET_PATH = ROOT .. "/tests/fixtures/client/guess-ratchet.txt"
local FAMILIES = { "chat", "frames", "units", "world" }

local function countGuesses(apiDir)
	local counts = {}
	for _, fam in ipairs(FAMILIES) do
		local path = apiDir .. "/" .. fam .. ".lua"
		local rows = assert(dofile(path), "failed to load " .. path)
		local n = 0
		for _, r in ipairs(rows) do
			if type(r) == "table" and r.evidence == "guess" then n = n + 1 end
		end
		counts[fam] = n
	end
	return counts
end

local function loadRatchet(path)
	local f = io.open(path, "rb")
	if not f then return nil, "missing ratchet file: " .. path end
	local text = f:read("*a")
	f:close()
	local stored = {}
	for line in (text .. "\n"):gmatch("(.-)\n") do
		local clean = line:gsub("#.*$", ""):match("^%s*(.-)%s*$")
		if clean ~= "" then
			local fam, num = clean:match("^([%a_][%w_]*)%s*=%s*(%d+)$")
			if not fam then return nil, "malformed ratchet line: " .. line end
			stored[fam] = tonumber(num)
		end
	end
	return stored, nil
end

local function checkRatchet(actual, stored)
	local problems = {}
	for _, fam in ipairs(FAMILIES) do
		local got = actual[fam]
		local allow = stored[fam]
		if allow == nil then
			problems[#problems + 1] = fam .. ": missing from guess-ratchet.txt (actual " .. tostring(got) .. ")"
		elseif got > allow then
			problems[#problems + 1] = fam .. ": has " .. got .. " 'guess' rows, above ratchet " .. allow .. " (do not add guesses)"
		elseif got < allow then
			problems[#problems + 1] = fam .. ": has " .. got .. " 'guess' rows, below ratchet " .. allow
				.. " — lower " .. fam .. " to " .. got .. " in tests/fixtures/client/guess-ratchet.txt"
		end
	end
	for fam in pairs(stored) do
		if actual[fam] == nil then
			problems[#problems + 1] = fam .. ": unknown family in guess-ratchet.txt"
		end
	end
	return problems
end

test("guess ratchet: each client API ledger family matches tests/fixtures/client/guess-ratchet.txt", function()
	local stored, err = loadRatchet(RATCHET_PATH)
	ok(stored ~= nil, tostring(err))
	local actual = countGuesses(API_DIR)
	local problems = checkRatchet(actual, stored)
	eq(#problems, 0, table.concat(problems, "; "))
end)

test("guess ratchet: fails when a family has more 'guess' rows than the ratchet allows", function()
	local actual = { chat = 8, frames = 31, units = 15, world = 38 }
	local stored = { chat = 7, frames = 31, units = 15, world = 38 }
	local problems = checkRatchet(actual, stored)
	eq(#problems, 1, "rising guess count must fail")
	ok(problems[1]:find("above ratchet 7", 1, true) ~= nil, "explains the rise: " .. tostring(problems[1]))
end)

test("guess ratchet: fails with a clear message when a family has fewer 'guess' rows, asking to lower the ratchet", function()
	local actual = { chat = 6, frames = 31, units = 15, world = 38 }
	local stored = { chat = 7, frames = 31, units = 15, world = 38 }
	local problems = checkRatchet(actual, stored)
	eq(#problems, 1, "falling guess count must fail until ratchet is lowered")
	ok(problems[1]:find("lower chat to 6", 1, true) ~= nil, "asks to lower ratchet: " .. tostring(problems[1]))
	ok(problems[1]:find("guess-ratchet.txt", 1, true) ~= nil, "names ratchet file: " .. tostring(problems[1]))
end)
