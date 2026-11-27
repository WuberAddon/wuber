-- Module: Net.Update
-- Purpose: "A newer Wuber is out" (round 11). Learns other players' Wuber versions from
--   messages that already arrive (driver beacons D field 11, ride requests R field 6, crew HI field
--   3: no new traffic), trusts a newer one when the founder says it (W.IsCreator on the message's
--   real sender key, never a name in a payload) or when 2 different players said it or higher in the
--   last 24 h, keeps the newest trusted one in WuberDB.newer = { ver, at }, and shows one quiet toast
--   per session once the player is idle. /wuber updates off (WuberDB.updateNotes, nil = on)
--   turns the toast off. A saved version not heard again for 14 days is forgotten.
-- API: W.ParseVersion, W.CompareVersions, W.HeardVersion, W.NewerVersion, W.UPDATE_URL, Mod.Why
--   Why(): nil, or the line /wuber why prints while a known newer version's notice is held back; read-only.
-- Internals: U, parse, mine, saved, trust, agreed, prune, busy, noticeOn, tryNotice, schedule; for
--   tests: Mod.count, Mod.shown, Mod.tryNotice, Mod.U
-- Uses: (none)
-- Later: UI.Toasts (UI.Toast), UI.Settings.Panel (UI.OpenHelp), Net.Rides (W.RideActive),
--   Drive.Queue (DR.Busy)
-- Events: listens Listen SETTINGS (updateNotes), login; fires NEWER_VERSION
-- Standalone: no
-- Test: tests/net/update_test.lua
-- From: new in round 11
--
-- Who is believed: Net.Inbox, Net.Requests and Drive.Team pass the key of the message's sender (the
-- game's own sender field). A version newer than ours from one ordinary player is only remembered
-- (at most U.MAX players, each for U.KEEP seconds); a second player saying it (or higher) makes it
-- trusted. Nothing is sent, nothing plays a sound, and the saved part is one small table.
-- Crew windows are usually one person's own characters: two of them count as two players (the brief
-- allows it; the founder's word or two senders is the rule).
-- Release rule: the founder's characters announce their own W.VERSION to every EU-PvE player, so bump
-- W.VERSION to a plain number only in the build that goes up on CurseForge; a test build says
-- "a.b.c-dev", which parse() rejects: nothing here runs for it, and a peer's "-dev" is never heard.

local _, W = ...
local Mod = W.Module("Net.Update", {})

local U = {
	KEEP = 86400,  -- a player's report counts for 24 h
	MAX = 50,      -- at most 50 players remembered (a new one pushes out the oldest report)
	NEED = 2,      -- different players needed (the founder alone is enough)
	FIRST = 20,    -- seconds after login before a saved notice may show
	SOON = 5,      -- seconds after a newer version is first trusted
	FORGET = 14 * 86400, -- a saved version nobody repeated for 14 days is dropped (a forged one dies out)
	RETRY = 15,    -- while in combat, on a ride or summoning: look again this often
	URL = "curseforge.com/wow/addons/wuber",
}
Mod.U = U
W.UPDATE_URL = U.URL

-- "2.3.1" -> "2.3.1", 20301. Only three parts of digits, each 0..99 ("2.10.0" > "2.9.0");
-- anything else (letters, two or four parts, "100.0.0", spaces) -> nil.
local function parse(v)
	v = W.Str(v)
	if type(v) ~= "string" or #v > 8 then return nil end
	local a, b, c = v:match("^(%d%d?)%.(%d%d?)%.(%d%d?)$")
	if not a then return nil end
	a, b, c = tonumber(a), tonumber(b), tonumber(c)
	return a .. "." .. b .. "." .. c, a * 10000 + b * 100 + c
end

function W.ParseVersion(v) return parse(v) end

-- -1, 0 or 1 (a older, the same, newer than b); nil when either isn't a version
function W.CompareVersions(a, b)
	local _, x = parse(a)
	local _, y = parse(b)
	if not (x and y) then return nil end
	if x == y then return 0 end
	return x > y and 1 or -1
end

-- this copy's version as a number (nil: W.VERSION isn't one, and nothing here runs)
local function mine()
	local _, n = parse(W.VERSION)
	return n
end

local function clock() return W.Now() end
local function wall()
	local ok, t = pcall(time)
	return ok and W.Num(t) or 0
end

-- The saved newer version, while it is still newer than this copy (updated: it is cleared).
local function saved()
	local d = W.db
	if type(d) ~= "table" or d.newer == nil then return nil end
	local s, v, n = d.newer, nil, nil
	if type(s) == "table" then v, n = parse(s.ver) end
	local my = mine()
	local at = type(s) == "table" and W.Num(s.at) or nil
	local t = wall()
	if not (v and my and n > my) or not at or (t > 0 and t - at > U.FORGET) then
		d.newer = nil
		return nil
	end
	return v, n
end

-- The newer version to tell the player about, or nil.
function W.NewerVersion() return (saved()) end

local function noticeOn()
	local d = W.db
	return type(d) == "table" and d.updateNotes ~= false
end

-- Busy: in combat, on a ride (rider), summoning / serving riders (driver), or another toast is up.
local function busy()
	if W.InCombat() then return "combat" end
	local UI = W.UI
	if type(UI) == "table" and type(UI.ToastShowing) == "function" and UI.ToastShowing() == true then return "toast" end
	if type(W.RideActive) == "function" and W.RideActive() == true then return "ride" end
	local DR = W.Drive
	if type(DR) == "table" and type(DR.Busy) == "function" and DR.Busy() == true then return "summoning" end
	if type(W.incoming) == "table" and #W.incoming > 0 then return "summoning" end
	return nil
end

local shown, waiting = false, false
local schedule

-- The toast, once per session, only when idle and the setting is on.
local function tryNotice()
	if shown or not noticeOn() then return false end
	local v = saved()
	if not v then return false end
	if busy() then
		schedule(U.RETRY)
		return false
	end
	local UI = W.UI
	if type(UI) ~= "table" or type(UI.Toast) ~= "function" then return false end
	local t = UI.Toast("Wuber " .. v .. " is out. Get it on CurseForge.", "update", function()
		if type(UI.OpenHelp) == "function" then UI.OpenHelp("settings", "address") end
	end)
	if type(t) ~= "table" then
		-- another toast that must stay (the portal) is up: try again later
		schedule(U.RETRY)
		return false
	end
	t.tip = "A newer Wuber is out. Click to open Help at \"Where to get Wuber\", which shows the address and how to turn this note off (/wuber updates off)."
	shown = true
	return true
end

schedule = function(secs)
	if waiting or shown then return end
	waiting = true
	W.After(secs, function()
		waiting = false
		tryNotice()
	end)
end

local function trust(v, n)
	local d = W.db
	if type(d) ~= "table" then return end
	local _, have = saved()
	if have and have > n then return end
	if have == n then
		d.newer.at = wall() -- heard again: kept another 14 days
		return
	end
	d.newer = { ver = v, at = wall() }
	W.Fire("NEWER_VERSION", v)
	schedule(U.SOON)
end

-- the reports: heard[key] = { v, n, at, seq }; count of them; arrived counts the reports in order, so two heard in
-- the same clock tick still have an order (the oldest is never picked by table walk order)
local heard, count, arrived = {}, 0, 0

local function prune()
	local cut = clock() - U.KEEP
	for k, e in pairs(heard) do
		if e.at < cut then
			heard[k] = nil
			count = count - 1
		end
	end
end

-- the newest version at least U.NEED different players said (it or higher)
local function agreed()
	local list = {}
	for _, e in pairs(heard) do list[#list + 1] = e end
	if #list < U.NEED then return nil end
	table.sort(list, function(a, b) return a.n > b.n end)
	local e = list[U.NEED]
	return e.v, e.n
end

-- W.HeardVersion(key, ver): a message from the player with this key (the game's sender) said this
-- version. true when it was newer than ours and counted.
function W.HeardVersion(key, ver)
	local v, n = parse(ver)
	local my = mine()
	if not (v and my) or n <= my then return false end
	key = W.Str(key)
	if not key or key == "" or key == W.myKey then return false end
	if W.IsCreator(key) then
		trust(v, n)
		return true
	end
	prune()
	if not heard[key] then
		if count >= U.MAX then
			local oldK, oldAt, oldSeq
			for k, e in pairs(heard) do
				if not oldAt or e.at < oldAt or (e.at == oldAt and e.seq < oldSeq) then
					oldK, oldAt, oldSeq = k, e.at, e.seq
				end
			end
			if oldK then
				heard[oldK] = nil
				count = count - 1
			end
		end
		count = count + 1
	end
	arrived = arrived + 1
	heard[key] = { v = v, n = n, at = clock(), seq = arrived }
	local av, an = agreed()
	if av then trust(av, an) end
	return true
end

-- after a relog: a saved notice shows once more (updated since: it is cleared)
W.OnLogin(function()
	if saved() then schedule(U.FIRST) end
end)

-- the setting turned back on: the toast may still come this session
W.Listen("SETTINGS", function(key)
	if key == "updateNotes" and noticeOn() and saved() then schedule(U.SOON) end
end)

-- /wuber why: nil when no newer version is known (or the notice is due to show), else one line naming
-- the first of tryNotice's rules that holds it back. Read-only (saved() would clear a stale field).
function Mod.Why()
	local d = W.db
	local s = type(d) == "table" and d.newer or nil
	if type(s) ~= "table" then return nil end
	local v, n = parse(s.ver)
	local my, at, t = mine(), W.Num(s.at), wall()
	if not (v and my and n > my) or not at or (t > 0 and t - at > U.FORGET) then return nil end
	if shown then return "Update notice: already shown this session (Wuber " .. v .. " is out)." end
	if not noticeOn() then return "Update notice: off (type /wuber updates on)." end
	local why = busy()
	if why == "combat" then return "Update notice: not in combat." end
	if why == "toast" then return "Update notice: waits for another message to close." end
	if why == "ride" then return "Update notice: not during a ride." end
	if why == "summoning" then return "Update notice: not while you are summoning." end
	return nil
end

-- for tests
function Mod.count() return count end
function Mod.shown() return shown end
Mod.tryNotice = tryNotice
