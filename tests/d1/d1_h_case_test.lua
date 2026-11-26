-- Design round 1, group H (audit 2.14): sentence case, and money as gold letters.
-- (1) no visible label of four letters or more is all capitals (the big button's words and acronyms are allowed);
-- (2) no visible label carries a coin texture escape: money is written in letters ("1g 20s"), like W.Money.
-- Loaded by tests/run.lua with its helper table T (the folder list near its end).
local T = ...
local test, eq, ok, list = T.test, T.eq, T.ok, T.list

-- words that stay in capitals: the driver's big button and its banner (item 19, later), key names, acronyms
local ALLOW = { ["CLICK THE PORTAL"] = true }
local function allowed(text)
	local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	if ALLOW[plain] then return true end
	if plain:find("^[A-Z]%d$") or plain:find("^[A-Z]+%-[%w%-]+$") then return true end -- a key: F5, SHIFT-1
	return false
end

-- every visible text of a client that has four letters or more and no lower-case letter
local function shouting(c)
	local bad = {}
	for _, t in ipairs(c:visibleTexts()) do
		if type(t) == "string" then
			local stripped = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
			local letters = stripped:gsub("[^%a]", "")
			if #letters >= 4 and not stripped:find("%l") and not allowed(t) then bad[#bad + 1] = t end
		end
	end
	return bad
end

local function coins(c)
	local bad = {}
	for _, t in ipairs(c:visibleTexts()) do
		if type(t) == "string" and t:find("|T", 1, true) and (t:find("Coin", 1, true) or t:find("MoneyFrame", 1, true)) then bad[#bad + 1] = t end
	end
	return bad
end

-- the main rider, driver and Settings screens (a usual ride, a crew, a day's takings)
local function scenes(visit)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { saved = { wizard = true } })
	local r = T.rider(w, T.TESTCHAR)
	w:advance(20)
	T.openDrive(d)
	local DR = d.W.Driver
	d.W.db.today = d.W.db.today
	for _, name in ipairs({ "console", "crew", "messages", "earnings", "customers", "blocked", "demand", "wizard" }) do
		d.W.UI.ShowDrive(name)
		w:advance(1)
		visit(d, "driver " .. name)
	end
	d.W.UI.ShowDrive("console")
	r.W.UI.Show("home")
	w:advance(2)
	visit(r, "rider home")
	for _, key in ipairs({ "riding", "driving", "map", "sound", "window" }) do
		r.W.UI.OpenSettings(key)
		w:advance(1)
		visit(r, "settings " .. key)
	end
	r.W.UI.OpenSettings()
	w:advance(1)
	visit(r, "settings home")
	T.clean(w)
end

test("d1 h: no visible label of four letters or more is all capitals (sentence case)", function()
	local all = {}
	scenes(function(c, name)
		for _, t in ipairs(shouting(c)) do all[#all + 1] = name .. ": " .. t end
	end)
	eq(#all, 0, "all capitals: " .. list(all, "; "))
end)

test("d1 h: no visible label shows a coin texture, money is written in letters", function()
	local all = {}
	scenes(function(c, name)
		for _, t in ipairs(coins(c)) do all[#all + 1] = name .. ": " .. t end
	end)
	eq(#all, 0, "coin textures: " .. list(all, "; "))
end)

test("d1 h: a day with money shows it in letters, and nothing earned reads 0g, never free", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { saved = { wizard = true } })
	w:advance(20)
	T.openDrive(d)
	d.W.UI.ShowDrive("console")
	w:advance(1)
	local zero = list(d:visibleTexts(), " ; ")
	ok(not zero:find("|T", 1, true), "no coin texture on the console: " .. zero)
	ok(not zero:lower():find("free", 1, true), "never free: " .. zero)
	local WM = d.W
	eq(WM.MoneyIcons(12000):find("|T", 1, true) ~= nil, true, "W.MoneyIcons itself is unchanged and still draws coins")
	T.clean(w)
end)
