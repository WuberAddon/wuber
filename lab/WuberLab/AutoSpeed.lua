-- Wuber Lab (developer only, never ship): AutoSpeed.lua, the Auto check's TIMING PASS (speed job 2749, step 4).
-- Screen "a_speed" of the Auto check (L.AUTO_SCREENS; it runs inside  /lab auto  and the Lab bar's Auto check button, or alone as
-- /lab auto a_speed): the real game times each screen change of Wuber and the Lab saves the rows. Nothing for the player to do.
--   For each change (open the window, close, open again, Ride > Trips > Ride, Ride > Drive, Drive console > Earnings and back,
--   cog > Settings and back, Help and back, a driver's page and back to Home, unfold and fold) it writes down:
--     ms      the Lua time of the call itself (debugprofilestop before and after)
--     frame   the worst frame time (ms) over the next second: one OnUpdate on a Lab frame adds up elapsed, per frame
--     kb      Wuber's memory a second after the change minus just before it (UpdateAddOnMemoryUsage + GetAddOnMemoryUsage("Wuber"),
--             read outside the watched frames); kbEnd the same (kept for older reports)
--     shown, unfolded, fits  the window after the change (proof the change happened; fits: room to unfold)
--   plus Wuber's total memory at the start and the end.
-- Where it goes: WuberLabDB.autoCheck.speed = { v, rows = { { id, label, ms, frame, frames, kb, kbEnd, note } }, startKB, endKB };
-- tools/labreport.js prints the "Speed" section from it.
--
-- Safety: Wuber is only driven through its own public calls (UI.Toggle, UI.SelectTab, UI.Show, UI.OpenSettings, UI.OpenHelp,
-- Driver.ShowScreen, UI.Fold.Apply), the same ones the tour's screens use. The tour has every sender of Wuber's stubbed (Photo.lua)
-- and puts WuberDB back; the fold choice is put back here too. Nothing is sent: no chat, no addon message. The Lab's one small frame
-- carries its OnUpdate only while a change is being watched. A click, a fight or the end of the tour stops the pass at once
-- (the rows so far are kept). Off for everything but the Auto check: it is only an Auto check screen.
-- New file: restart the game once (WuberLab.toc lists it after AutoSteps6.lua).

local _, L = ...

local K = L.PhotoKit
local num = L.num
local fn = K.fn
local SCREENS = L.AUTO_SCREENS

local WATCH = 1.0        -- seconds each change is watched for its worst frame
local GAP = 0.15         -- seconds between the end of one watch and the next change

L.speedRows = nil        -- the pass's result until the Auto check saves it (AutoCheck.lua: hooks.done); nil when no pass ran

local function tourScreen(id)
	for _, s in ipairs(L.PHOTO_SCREENS or {}) do if s.id == id then return s end end
	return nil
end

local function profNow()
	local f = rawget(_G, "debugprofilestop")
	return type(f) == "function" and num(f()) or nil
end

-- Wuber's memory in KB (nil when this game has no such call)
local function memKB()
	local ca = rawget(_G, "C_AddOns")
	local upd = rawget(_G, "UpdateAddOnMemoryUsage")
	local get = rawget(_G, "GetAddOnMemoryUsage")
	if type(get) ~= "function" and type(ca) == "table" and type(ca.GetAddOnMemoryUsage) == "function" then get = ca.GetAddOnMemoryUsage end
	if type(get) ~= "function" then return nil end
	if type(upd) == "function" then pcall(upd) end
	local ok, v = pcall(get, "Wuber")
	return ok and num(v) or nil
end

local function tabs(W, name) if type(W.UI) == "table" and fn(W.UI, "SelectTab") then W.UI.SelectTab(name) end end
local function ui(W, name, ...) if type(W.UI) == "table" and fn(W.UI, name) then return W.UI[name](...) end end
local function driver(W, screenName)
	if type(W.Driver) == "table" and fn(W.Driver, "ShowScreen") then W.Driver.ShowScreen(screenName) end
end
-- (review) fold = nil lets the window unfold where it has room; a table with narrow = true keeps it narrow
local function setFold(W, fold)
	if type(W.db) ~= "table" then return end
	W.db.fold = fold
	local F = W.UI and W.UI.Fold
	if fn(F, "Apply") then F.Apply() end
end
-- the fold button (UI.Fold.Toggle: flips this page's choice; nothing without room or in combat), as the player presses it
local function foldButton(W)
	local F = type(W.UI) == "table" and W.UI.Fold
	if fn(F, "Toggle") then F.Toggle() end
end
local function copy(t)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in pairs(t) do o[k] = copy(v) end
	return o
end
-- what a change did, for the report and the test: the window shown, unfolded
local function stateOf(W)
	local UI = type(W.UI) == "table" and W.UI or {}
	local F = UI.Fold
	local shown = fn(UI, "IsShown") and UI.IsShown() == true or false
	local unfolded = fn(F, "IsUnfolded") and F.IsUnfolded() == true or false
	local fits = fn(F, "Fits") and F.Fits() == true or false
	return shown, unfolded, fits
end

-- a driver key from the demo data on Home (the first one that is there)
local function anyDriver(W)
	local best
	for k in pairs(type(W.drivers) == "table" and W.drivers or {}) do
		if not best or tostring(k) < tostring(best) then best = k end
	end
	return best
end

-- { id, label, call(W) }; the ids are stable (labreport prints them in this order)
local CHANGES = {
	-- (review) the tour's home screen has the window open already: close it first, so open1 is a real open
	{ "close0", "close the window (open from the tour)", function(W) ui(W, "Toggle", false) end },
	{ "open1", "open the window", function(W) ui(W, "Toggle", true) end },
	{ "close1", "close the window", function(W) ui(W, "Toggle", false) end },
	{ "open2", "open the window again", function(W) ui(W, "Toggle", true) end },
	{ "trips1", "Ride > Trips", function(W) tabs(W, "Trips") end },
	{ "ride1", "Trips > Ride", function(W) tabs(W, "Ride") end },
	{ "drive1", "Ride > Drive", function(W) tabs(W, "Drive") end },
	{ "earn1", "Drive console > Earnings", function(W) driver(W, "earnings") end },
	{ "earn_back", "Earnings > back to the console", function(W) driver(W, "console") end },
	{ "ride2", "Drive > Ride", function(W) tabs(W, "Ride") end },
	{ "settings1", "cog > Settings", function(W) ui(W, "OpenSettings") end },
	{ "settings_back", "Settings > back", function(W) ui(W, "CloseSettings") end },
	{ "help1", "Help", function(W) ui(W, "OpenHelp") end },
	{ "help_back", "Help > back", function(W) ui(W, "CloseHelp") end },
	{ "confirm1", "Home > a driver's page", function(W) ui(W, "Show", "confirm", anyDriver(W)) end },
	{ "confirm_home", "driver's page > Home", function(W) ui(W, "Show", "home") end },
	{ "unfold", "the fold button: unfold the window", function(W) foldButton(W) end },
	{ "fold", "the fold button: fold it again", function(W) foldButton(W) end },
}
L.SPEED_CHANGES = CHANGES

local d -- the pass in progress: { W, i, rows, frame, ... }

local function stop(why)
	if not d then return end
	local f = d.frame
	if f then
		pcall(f.SetScript, f, "OnUpdate", nil)
		pcall(f.Hide, f)
	end
	d.over = true
	d.why = why
	d.done = true
	d.out.endKB, d.out.stopped = d.endKB or memKB(), why
end

local function alive()
	if not d or d.over then return false end
	if not K.tour() then stop("the tour ended") return false end
	if L.InCombat() then stop("combat") return false end
	return true
end

local nextChange

-- one change: measure the call, then watch WATCH seconds of frames. (review) Wuber's memory is read one frame before the
-- change and after the watch, never in a watched frame: UpdateAddOnMemoryUsage is slow in the real game and would be counted
-- in the worst frame.
local function runChange(c, m0)
	local W = d.W
	local row = { id = c[1], label = c[2] }
	local t0 = profNow()
	local ok, err = pcall(c[3], W)
	local t1 = profNow()
	row.ms = (t0 and t1) and math.max(0, t1 - t0) or 0
	if not ok then row.note = "error: " .. tostring(err):sub(1, 120) end
	row.frame, row.frames = 0, 0
	d.rows[#d.rows + 1] = row
	local f = d.frame
	local sum = 0
	f:SetScript("OnUpdate", function(_, elapsed)
		elapsed = num(elapsed) or 0
		row.frames = row.frames + 1
		if elapsed * 1000 > row.frame then row.frame = elapsed * 1000 end
		sum = sum + elapsed
		if sum >= WATCH then
			f:SetScript("OnUpdate", nil)
			-- what the change left once its animation is over
			local okS, shown, unfolded, fits = pcall(stateOf, W)
			if okS then row.shown, row.unfolded, row.fits = shown, unfolded, fits end
			local m2 = memKB()
			row.kb = (m0 and m2) and (m2 - m0) or 0
			row.kbEnd = row.kb
			if d and not d.over then L.After(GAP, nextChange) end
		end
	end)
end

function nextChange()
	if not alive() then return end
	d.i = d.i + 1
	local c = CHANGES[d.i]
	if not c then
		-- leave Wuber's window on Home (the tour sets each next screen up itself), the fold choice as it was
		pcall(setFold, d.W, d.fold)
		pcall(ui, d.W, "Show", "home")
		d.endKB = memKB()
		stop(nil)
		return
	end
	local m0 = memKB() -- (in the gap: the change runs on the next frame)
	L.After(0, function()
		if not alive() then return end
		local ok, err = pcall(runChange, c, m0)
		if not ok then
			d.rows[#d.rows + 1] = { id = c[1], label = c[2], ms = 0, frame = 0, frames = 0, kb = 0, kbEnd = 0, note = "error: " .. tostring(err):sub(1, 120) }
			L.After(GAP, nextChange)
		end
	end)
end

local function begin(W)
	local f = rawget(_G, "CreateFrame")("Frame", nil, rawget(_G, "UIParent"))
	f:SetSize(1, 1)
	f:SetPoint("BOTTOMLEFT", rawget(_G, "UIParent"), "BOTTOMLEFT", 0, 0)
	f:Show()
	d = { W = W, i = 0, rows = {}, frame = f, startKB = memKB(), fold = copy(W.db.fold) }
	-- what the Auto check saves: the table is filled as the pass goes, so a pass stopped early keeps its rows
	d.out = { v = 1, rows = d.rows, startKB = d.startKB }
	L.speedRows = d.out
	L.After(0.2, nextChange)
end

-- what hooks.done saves: nil when no pass started
function L.SpeedTake()
	local x = L.speedRows
	L.speedRows = nil
	return x
end

local function data()
	local t = K.tour()
	if not t then return {} end
	t.autoData = t.autoData or {}
	return t.autoData
end

local function s_ready(W)
	local dd = data()
	if not dd.speedStarted then
		dd.speedStarted = true
		local ok, err = pcall(begin, W)
		if not ok then
			d = nil
			dd.speedErr = tostring(err):sub(1, 160)
			return true
		end
		return false
	end
	if d and d.done then return true end
	return d == nil
end

local screen = { id = "a_speed", side = "rider", maxWait = 90, wait = 0.3, auto = true,
	title = "Speed: the Lua ms, the worst frame in the next second and the memory of each screen change (Wuber's own calls; nothing to do)",
	run = function(W, view)
		local s = tourScreen("home")
		if not s then return "the tour has no screen home" end
		return s.run(W, view)
	end,
	ready = s_ready,
	verify = function()
		local dd = data()
		if dd.speedErr then return "look", "the timing pass broke: " .. dd.speedErr end
		if not d then return "skip", "the timing pass did not start" end
		if not d.done then
			stop("too slow")
			return "look", ("the timing pass did not finish (%d of %d changes)"):format(#d.rows, #CHANGES)
		end
		local worst, wid = 0, "-"
		for _, r in ipairs(d.rows) do if r.frame > worst then worst, wid = r.frame, r.id end end
		local text = ("%d changes timed; worst frame %.0f ms (%s); Wuber's memory %s KB at the start, %s KB at the end%s"):format(#d.rows, worst, wid,
			d.startKB and ("%.0f"):format(d.startKB) or "?", d.endKB and ("%.0f"):format(d.endKB) or "?", d.why and (" (stopped: " .. tostring(d.why) .. ")") or "")
		d = nil
		return "info", text
	end }
SCREENS[#SCREENS + 1] = screen
