-- Module: Drive.Kitchen
-- Purpose: the live portal tracker's driver side: in the network driver's window, turns DRIVE_RITUAL
--   phases into W.SendRitual for riders that came through the app.
-- API: DR.CLICKERS, DR.kitchen, DR.KitchenSend, DR.RiderVersionOk
-- Internals: (none)
-- Uses: (none)
-- Later: (none)
-- Events: listens Listen DRIVE_RITUAL, Listen DRIVE_STATE; fires (none). Also sends the joining app
--   rider's ST (DR.SendState: ride id, flag v) to the crew windows, once per ride (2.3.0 riders only)
-- Standalone: no
-- Test: tests/drive/kitchen_test.lua
-- From: new in Wuber 2.3.0 (SPEC7 section 5.10; owner F)
--
-- Every crew window hears the same DRIVE_RITUAL(name, phase, data) (Drive.Queue's facts, Drive.Cast's
-- target); only the window on the network (DR.NetDriver()) tells the rider, and only a rider who
-- came through the app (c.wuberRide) with Wuber 2.3.0 or later (R field 6, c.wuberVer):
--   q  in the group, waiting for the summon (DRIVE_STATE joined)
--   t  greeted / targeted        c  casting (the caster's name)
--   h  a helper clicked (tapped = unique helpers, the heuristic ones too)
--   s  summoned                  f  the rift closed (trying again)
-- G (Net.Portal's W.SendRitual: rideId, buyer, phase, tapped, need, caster, danger) goes on a change
-- only, at least 1.5 s apart per ride (s and f at once; a held change goes out when the gap ends,
-- the latest state only), at most 15 per ride.
--   DR.CLICKERS = 2: the clickers a summoning portal needs besides the caster

local _, W = ...
local Mod = W.Module("Drive.Kitchen", {})
W.Drive = W.Drive or {}
local DR = W.Drive

DR.CLICKERS = 2

local GAP = 1.5   -- seconds between two G of one ride (s and f excepted)
local MAX = 15    -- G per ride
local MIN_VERSION = "2.3.0"

-- [rideId] = { sig, at, n, held = { args } , timer }
local rides = {}
DR.kitchen = rides

local function now() return GetTime() end

local function call(name, ...)
	local fn = DR[name]
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		W.Error("drive " .. name, a)
		return nil
	end
	return a, b
end

-- "2.3.0" or later (major.minor.patch, missing parts 0)
function DR.RiderVersionOk(v, want)
	v = type(v) == "string" and v or ""
	local a = { v:match("^(%d+)%.?(%d*)%.?(%d*)") }
	local b = { (want or MIN_VERSION):match("^(%d+)%.?(%d*)%.?(%d*)") }
	if not a[1] then return false end
	for i = 1, 3 do
		local x, y = tonumber(a[i]) or 0, tonumber(b[i]) or 0
		if x ~= y then return x > y end
	end
	return true
end

local function nameOf(key)
	if not key then return "" end
	if key == W.myKey then return W.myName or W.Me() or "" end
	local n = call("NameOf", key)
	if type(n) == "string" and n ~= "" then return n end
	local unit = DR.units and DR.units[key]
	return (unit and W.UnitName(unit)) or ""
end

local function helpers(c)
	local n = 0
	for k in pairs(type(c.helps) == "table" and c.helps or {}) do
		if k ~= c.caster then n = n + 1 end
	end
	return math.min(9, n)
end

local function send(r, args)
	r.sig, r.at, r.n, r.held = args.sig, now(), r.n + 1, nil
	if type(W.SendRitual) == "function" then
		W.Safe("kitchen send", W.SendRitual, args.ride, args.buyer, args.phase, args.tapped, args.need, args.caster, args.danger)
	end
end

-- Tells the rider of customer c the phase (nil when it doesn't go: not mine to tell, an old or
-- whisper rider, no change, the cap). Returns true when sent now, "held" when it waits.
function DR.KitchenSend(c, phase, data)
	if type(c) ~= "table" or not c.wuberRide or not c.wuberBuyer then return nil end
	if not call("NetDriver") then return nil end
	if not DR.RiderVersionOk(c.wuberVer) then return nil end
	data = data or {}
	local level = tonumber((call("DangerLevel"))) or 0
	local args = {
		ride = c.wuberRide, buyer = c.wuberBuyer, phase = phase,
		tapped = (phase == "h" or phase == "c" or phase == "s") and helpers(c) or 0,
		need = DR.CLICKERS, caster = W.Short(nameOf(data.caster or c.caster)) or "", danger = math.max(0, math.min(2, level)),
	}
	if phase == "q" or phase == "t" then args.caster = "" end
	args.caster = W.Clean(args.caster, 24)
	args.sig = table.concat({ args.phase, args.tapped, args.caster, args.danger }, "|")
	local r = rides[c.wuberRide]
	if not r then
		r = { n = 0, at = -1000 }
		rides[c.wuberRide] = r
	end
	if r.sig == args.sig or r.n >= MAX then return nil end
	local t = now()
	if phase == "s" or phase == "f" or t - r.at >= GAP then
		send(r, args)
		return true
	end
	-- too soon: the latest state goes when the gap ends
	r.held = args
	if not r.timer then
		r.timer = true
		W.After(GAP - (t - r.at) + 0.01, function()
			r.timer = nil
			local h = r.held
			if h and h.sig ~= r.sig and r.n < MAX then send(r, h) end
			r.held = nil
		end)
	end
	return "held"
end

W.Listen("DRIVE_RITUAL", function(name, phase, data)
	if type(data) ~= "table" then return end
	local c = DR.customers and data.key and DR.customers[data.key]
	if type(c) ~= "table" or not c.wuberRide then return end
	DR.KitchenSend(c, phase, data)
end)

-- Whether a crew window with Wuber is in the group (it needs the ride id: ST field 9).
local function crewHere()
	for k in pairs(DR.peers or {}) do
		if DR.units and DR.units[k] then return true end
	end
	return false
end

-- In the group and waiting for the summon: "In the queue" becomes the live look's first step; the
-- crew windows learn the ride id (the passphrase) and a fare a raincheck lowered, once per ride.
W.Listen("DRIVE_STATE", function(c, was)
	if type(c) ~= "table" or not c.wuberRide then return end
	if c.state == "joined" and (was == "invited" or was == "queued" or was == "lead" or was == nil) then
		if c.stTold ~= c.wuberRide and W.VerAtLeast and W.VerAtLeast(c.wuberVer, "2.3.0") and call("NetDriver") and crewHere() then
			c.stTold = c.wuberRide
			call("SendState", c)
		end
		DR.KitchenSend(c, "q")
	end
end)
