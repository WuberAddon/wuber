local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Round 46 R (HUNT-108): Check my game's heading says so when a line under the game checks needs a look.
local function runCheck(setup)
	local w = T.newWorld()
	local r = w:addClient(T.TESTCHAR, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local UI = r.W.UI
	UI.OpenSettings()
	local st = UI.settings
	if setup then setup(r) end
	st.controls.check:GetScript("OnClick")(st.controls.check, "LeftButton", false)
	for _ = 1, 30 do w:advance(0.1) end
	return st.results
end

local function lines(n) local t = {} for i = 1, n do t[i] = { text = "Driver line " .. i, ok = false } end return t end

test("r46 r: HUNT-108: one crossed driver line", function()
	local res = runCheck(function(r) r.W.Drive.Readiness = function() return lines(1) end; r.W.Drive.comm = { sent = 1, failed = 0, heard = 1 } end)
	local head = res.head:GetText() or ""
	ok(head:find("^All %d+ game checks passed%. 1 driver line needs a look: see your Drive tab%.$"), head)
end)

test("r46 r: HUNT-108: two crossed driver lines", function()
	local res = runCheck(function(r) r.W.Drive.Readiness = function() return lines(2) end; r.W.Drive.comm = { sent = 1, failed = 0, heard = 1 } end)
	local head = res.head:GetText() or ""
	ok(head:find("^All %d+ game checks passed%. 2 driver lines need a look: see your Drive tab%.$"), head)
end)

test("r46 r: HUNT-108: only the crew messages line crossed", function()
	local res = runCheck(function(r) r.W.Drive.Readiness = function() return {} end; r.W.Drive.comm = { sent = 1, failed = 2, heard = 1 } end)
	local head = res.head:GetText() or ""
	ok(head:find("^All %d+ game checks passed%. 1 line below needs a look%.$"), head)
end)

test("r46 r: HUNT-108: both kinds crossed", function()
	local res = runCheck(function(r) r.W.Drive.Readiness = function() return lines(2) end; r.W.Drive.comm = { sent = 1, failed = 2, heard = 1 } end)
	local head = res.head:GetText() or ""
	ok(head:find("^All %d+ game checks passed%. 3 lines below need a look%.$"), head)
end)

test("r46 r: HUNT-108: no crossed extra line keeps the old heading", function()
	local res = runCheck(function(r) r.W.Drive.Readiness = function() return {} end; r.W.Drive.comm = { sent = 1, failed = 0, heard = 1 } end)
	local head = res.head:GetText() or ""
	ok(head:find("^All %d+ checks passed%. Your game runs Wuber fully%.$"), head)
end)
