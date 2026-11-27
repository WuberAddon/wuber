-- r51 group L: release guard tests REL-1 (a stale file list), REL-2 (a first install), REL-3 (an upgrade).
local T = ...
local test, ok, eq = T.test, T.ok, T.eq
local H = T.H

local ROOT = (T.dir or "."):gsub("\\", "/")
local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end
local function dirOf(p) return (p:gsub("/[^/]*$", "")) end
local HERE = (debug.getinfo(1, "S").source or ""):gsub("^@", ""):gsub("\\", "/")
local TESTS = dirOf(dirOf(HERE))

-- 2.3.2's file list (git show release-2.3.2:Wuber/Wuber.toc, comments dropped): tests/r51/l_toc232.txt
local function oldList()
	local set = {}
	for line in (slurp(dirOf(HERE) .. "/l_toc232.txt") or ""):gmatch("[^\r\n]+") do
		line = line:gsub("\\", "/"):gsub("^%s+", ""):gsub("%s+$", "")
		if line ~= "" then set[line] = true end
	end
	return set
end

-- a client option: the files the game would load from an old list; every other file is an empty chunk
local function onlyFiles(set)
	return function(addon, file, text)
		if addon == "Wuber" and file:match("%.lua$") and not set[file] then return "" end
		return text
	end
end

local function without(name)
	return function(addon, file, text)
		if addon == "Wuber" and file == name then return "" end
		return text
	end
end

local function listed(W)
	local s = ","
	for _, n in ipairs(W.MissingParts()) do s = s .. n .. "," end
	return s
end

-- the player's four first steps: boot (done), a service name, a first open, hearing a driver
local function useIt(w, r, d)
	local W = r.W
	local good = pcall(W.CleanService, "Fast Cabs", "Wuber")
	ok(good, "saving a service name does not throw")
	ok(pcall(W.SpamReason, "Fast Cabs"), "the spam check does not throw")
	ok(pcall(W.SentenceSpam, "Cheap gold here"), "the sentence check does not throw")
	if type(W.UI.ShowDrive) == "function" then ok(pcall(W.UI.ShowDrive), "the driver screen opens") end
	T.goOnline(d)
	w:advance(10)
end

for _, spec in ipairs({
	{ "2.3.2's whole file list", function() return onlyFiles(oldList()) end, false },
	{ "only Core/Words.lua left out", function() return without("Core/Words.lua") end, true },
}) do
	test("r51 L REL-1: a reload with " .. spec[1] .. " shows the restart notice and no Lua error", function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA, { netOnly = true, prepare = function(_, c) c.rewrite = spec[2]() end })
		local r = T.rider(w, T.TESTCHAR, { prepare = function(_, c) c.rewrite = spec[2]() end })
		T.settle(w)
		local said
		local keep = r.W.UI.Toast
		r.W.UI.Toast = function(text) said = text end
		r:fire("PLAYER_LOGIN")
		w:advance(5)
		r.W.UI.Toast = keep
		ok(#r.W.MissingParts() > 0, "something is named as missing")
		if spec[3] then ok(listed(r.W):find("Core_Words"), "Core.Words is named: " .. listed(r.W)) end
		ok(said and said:find("Restart the game to finish updating Wuber.", 1, true), "restart notice: " .. tostring(said))
		useIt(w, r, d)
		-- the module loader's own "needs X, which is not loaded" and "no module named X" lines are the expected records; nothing else
		for _, c in ipairs({ r, d }) do
			local e = c.W.lastError
			ok(e == nil or tostring(e):find("is not loaded", 1, true) or tostring(e):find("no module named", 1, true), "only a not-loaded line: " .. tostring(e))
			c.W.lastError = nil
		end
		T.clean(w)
	end)
end

-- guard: release path, with every file loaded nothing is missing and no notice shows (tests/r32/r32_k3_missing_parts_test.lua)
test("r51 L REL-1: with every file loaded nothing is missing and no notice shows", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local said
	r.W.UI.Toast = function(text) said = text end
	T.settle(w)
	r:fire("PLAYER_LOGIN")
	w:advance(5)
	eq(#r.W.MissingParts(), 0, "nothing missing: " .. listed(r.W))
	ok(not (said and said:find("Restart")), "no notice")
	T.clean(w)
end)

-- guard: release path, a first install is the game's real start (Simple, no saved data, no realm)
test("r51 L REL-2: a first install opens in Simple, books a heard driver, shows no error and no What's new card", function()
	local w = T.newWorld({ realm = "" })
	local d = T.driver(w, T.ANITA, { netOnly = true })
	local r = T.rider(w, T.TESTCHAR, { simple = true, realm = "", saved = {} })
	T.settle(w)
	T.goOnline(d)
	w:advance(30)
	ok(r.W.Advanced() == false, "Simple mode on a first install")
	local news = r.W.Mod("UI.WhatsNew")
	local c = news.Card()
	ok(not (c and H.visible(c)), "no What's new card on a first install")
	local ride = r.W.RequestRide("anita lift")
	ok(ride and ride.id, "a heard driver can be booked")
	w:advance(3)
	c = news.Card()
	ok(not (c and H.visible(c)), "still no What's new card")
	T.clean(w)
end)

-- guard: release path, a saved install keeps the page it had (the neighbouring path of REL-2)
test("r51 L REL-2: an install with saved data keeps its mode", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { simple = true, saved = { Wuber = { coach = true, advanced = true } } })
	T.settle(w)
	ok(r.W.Advanced() == true, "stays Advanced")
	T.clean(w)
end)

-- REL-3: every saved file we hold
local FILES = {
	{ "old1", TESTS .. "/hunt/fixtures/saved/old1.lua" },
	{ "acct1", TESTS .. "/hunt/fixtures/saved/acct1.lua" },
	{ "acct2", TESTS .. "/hunt/fixtures/saved/acct2.lua" },
	{ "acct3", TESTS .. "/hunt/fixtures/saved/acct3.lua" },
	{ "acct4", TESTS .. "/hunt/fixtures/saved/acct4.lua" },
	{ "ACCOUNT1", TESTS .. "/fixtures/seeds/wtf-root/Account/ACCOUNT1/SavedVariables/Wuber.lua" },
	{ "ACCOUNT2", TESTS .. "/fixtures/seeds/wtf-root/Account/ACCOUNT2/SavedVariables/Wuber.lua" },
}
local function loadSaved(path)
	local text = assert(slurp(path), "no file " .. path)
	local fn = assert(loadstring(text, "@" .. path))
	local env = {}
	setfenv(fn, env)
	local ret = fn()
	return ret or env.WuberDB or env.Wuber, text
end

for _, f in ipairs(FILES) do
	-- guard: release path, every saved file we hold boots and keeps its settings
	test("r51 L REL-3: 2.4.2 boots on saved file " .. f[1] .. " with no error and keeps its settings", function()
		local saved, before = loadSaved(f[2])
		ok(type(saved) == "table", "the file holds a table")
		local want = {}
		for k, v in pairs(saved) do
			local t = type(v)
			if (t == "boolean" or t == "string" or t == "number") and k ~= "advanced" and k ~= "timeValue" and k ~= "fx" and k ~= "ruleset" then want[k] = v end
		end
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, { simple = true, saved = { Wuber = saved } })
		T.settle(w)
		w:advance(20)
		for k, v in pairs(want) do
			if k ~= "newsSeen" and k ~= "simpleNote" and k ~= "progressReady" then eq(r.W.db[k], v, "kept " .. k) end
		end
		eq(slurp(f[2]), before, "the file is read, never written back")
		T.clean(w)
	end)
end

-- guard: release path, a saved newsSeen of 2.3.2 shows the What's new card once
test("r51 L REL-3: a newsSeen of 2.3.2 shows the What's new card once", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true, newsSeen = "2.3.2" } } })
	local news = r.W.Mod("UI.WhatsNew")
	local seen = 0
	for _ = 1, 40 do
		w:advance(1)
		local c = news.Card()
		if c and H.visible(c) then seen = seen + 1 break end
	end
	eq(seen, 1, "the card showed")
	news.Card().close:Click()
	w:advance(30)
	local c = news.Card()
	ok(not (c and H.visible(c)), "not again after it was closed")
	local r2 = w:reload(r)
	w:advance(30)
	local c2 = r2.W.Mod("UI.WhatsNew").Card()
	ok(not (c2 and H.visible(c2)), "not again after a reload")
	T.clean(w)
end)
