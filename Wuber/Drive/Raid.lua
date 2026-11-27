-- Module: Drive.Raid
-- Purpose: Raid summons engine: raid queue, claims, summoner picks, raid chat lines.
-- API: DR.raidRows, DR.CLAIM_TTL, DR.RAID_GIVE_UP, DR.RaidWords, DR.CanRunRaid, DR.SetMode,
--   DR.SetRaidRun, DR.RaidSpot, DR.CLAIM_SILENT, DR.ClaimGone, DR.RaidQueue, DR.RaidOrderKey,
--   DR.RaidApply, DR.RaidMirror, DR.RaidAdd, DR.RaidDrop, DR.RaidTop, DR.RaidNext, DR.RaidTick,
--   DR.NotHere, DR.RaidWarlocks, DR.RaidPick, DR.RaidHeard, DR.RaidHere, DR.RaidAsk, DR.RaidCancel,
--   DR.RaidSync (the raid rows on the bulk lane, for a window that reloaded: RA, CAST with a sync mark, END),
--   DR.RAID_KEEPER_GONE (a crew window stops raid summons this long after the runner left and no window keeps the queue)
-- Internals: (none)
-- Uses: Drive.Service
-- Later: (none)
-- Events: listens On (loop over several events), On CHAT_MSG_WHISPER, On GROUP_LEFT; fires DRIVE_MODE, DRIVE_RAID,
--   DRIVE_RAID_DONE, SETTINGS
-- Standalone: no
-- Test: tests/drive/raid_test.lua
-- From: Drive_Service.lua 940-1435 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("Drive.Raid", { "Drive.Service" })
local ServiceMod = W.Mod("Drive.Service")
local myKey = ServiceMod.myKey
local DR = W.Drive

local plain, str, num = W.Plain, W.Str, W.Num

---------------------------------------------------------------------------
-- Raid summons: free summons for the runner's own raid
---------------------------------------------------------------------------
-- A raid member asks (raid/party chat, a whisper, or their Wuber's "Request a summon": RQ),
-- or the runner adds them by hand; the picked Warlocks' buttons take the next raider (the
-- CAST fact is the claim). No price, trade, invites, kicks, adverts or beacon. Rows:
-- DR.raidRows[key] = { key, name, asked, order, state = "queued"|"summoning"|"waiting",
-- claimedBy, claimAt, channelAt, endAt, tries, fails, failedAt }.

DR.raidRows = DR.raidRows or {}
DR.CLAIM_TTL = 40       -- a claim with no channel start is let go after this
DR.RAID_GIVE_UP = 300   -- dropped this long after the second failed summon
DR.RAID_KEEPER_GONE = 5 -- (AU24-30) a crew window stops raid summons this long after nobody keeps the queue
local RAID = { order = 0 }

local REQ_WORDS = { ["123"] = true, summ = true, sum = true, summon = true, summons = true, summs = true, sums = true }
local CANCEL_WORDS = { no = true, nvm = true, cancel = true, walking = true, here = true, nevermind = true }

-- What a raid, party or whispered line asks: "request", "cancel" or nil (40 characters at most;
-- "inv" is not a request).
function DR.RaidWords(text)
	text = str(text)
	if not text or #text > 40 then return nil end
	local lower = text:lower()
	local req, cancel, hard = lower:find("need%s+a?%s*summ") ~= nil, false, false
	local prev
	for w in lower:gmatch("[%a%d]+") do
		local asks = REQ_WORDS[w] or (#w >= 5 and DR.Summonish and DR.Summonish(w))
		if asks then req = true end
		if CANCEL_WORDS[w] then
			cancel = true
			-- ("summon here" still asks, and so does "summon pls, no mount"; nvm, cancel, walking win)
			if w ~= "here" and w ~= "no" then hard = true end
		end
		if asks and prev == "no" then hard = true end -- ("no summon": the no is about the summon)
		prev = w
	end
	if req and not hard then return "request" end
	if cancel or req then return "cancel" end
	return nil
end

-- Lead or assist (in a party: lead) lets this character run raid summons. ok, why.
function DR.CanRunRaid()
	if not W.InGroup() then return false, "Make or join a raid first." end
	if DR.IsLeader() then return true end
	if DR.InRaid() then
		for _, fname in ipairs({ "UnitIsGroupAssistant", "UnitIsRaidOfficer" }) do
			local fn = rawget(_G, fname)
			if type(fn) == "function" then
				local ok, v = pcall(fn, "player")
				if ok and plain(v) == true then return true end
			end
		end
		-- (2.1 on the real client: neither of those may exist on 1.60.1; the raid roster's rank
		-- - 1 assist, 2 lead - is the classic way to read it)
		local roster = rawget(_G, "GetRaidRosterInfo")
		if type(roster) == "function" then
			local me = W.myKey
			for i = 1, 40 do
				local ok, name, rank = pcall(roster, i)
				name = ok and str(name) or nil
				if name and W.Key(name) and me and (W.Key(name) == me or me:match("^(%S+)") == W.Key(name)) then
					if (num(rank) or 0) >= 1 then return true end
					break
				end
			end
		end
	end
	return false, "You need lead or assist"
end

-- Sell or raid summons (the console's segmented control). The runner only.
function DR.SetMode(m)
	m = m == "raid" and "raid" or "sell"
	local ch = DR.char()
	if ch.captain ~= "" then return false end
	if ch.mode == m then return true end
	if m == "raid" then
		if ch.drive then ch.drive = false end -- selling closes: raid summons never beacon
		if not DR.IsWarlock() then ch.runner = true end
	elseif ch.raidRun then
		ch.raidRun = false
		DR.Alert("Raid summons stopped: you're back to selling summons.", "raid")
	end
	ch.mode = m
	for k in pairs(DR.raidRows) do DR.raidRows[k] = nil end
	DR.SendConfig()
	if W.InGroup() then DR.Hello() end
	W.Fire("DRIVE_MODE", m)
	W.Fire("DRIVE_RAID")
	W.Fire("SETTINGS", "drive")
	DR.Changed()
	return true
end

-- Start / Stop raid summons (DR.SetOpen in raid mode). ok, why ("lead", "member").
function DR.SetRaidRun(on)
	local ch = DR.char()
	if ch.captain ~= "" then return false, "member" end
	if on then
		local ok = DR.CanRunRaid()
		if not ok then return false, "lead" end
		ch.paused = false
		DR.raidLostTold = nil
	end
	ch.raidRun = on and true or false
	if not on then
		for k in pairs(DR.raidRows) do DR.raidRows[k] = nil end
	end
	DR.SendConfig()
	DR.Send("PAU", ch.paused and 1 or 0)
	if W.InGroup() then DR.Hello() end
	W.Fire("SETTINGS", "drive")
	W.Fire("DRIVE_RAID")
	DR.Changed()
	return true
end

-- Where the summoners stand (the first picked summoner with a known map; else me).
function DR.RaidSpot()
	for _, k in ipairs(DR.Summoners()) do
		if k == myKey() or DR.units[k] then
			local place, map = DR.PlaceOf(k)
			if map then return place, map end
		end
	end
	return DR.PlaceOf("player")
end

local function atSpot(unit, spotMap)
	local sim = DR.SimHooks -- the test addon's shard-free test mode: see DR.Here
	if sim and sim.here and unit then
		local ok, v = pcall(sim.here, unit)
		if ok and v == true then return true end
	end
	if not spotMap or not unit then return false end
	if DR.MapOf(unit) ~= spotMap then return false end
	-- (FAB-04) as when selling: here means in sight of the summoner, not just the same zone map. Only when I
	-- stand on that map myself can I judge sight; otherwise (the summoner is elsewhere) the map decides.
	if DR.MapOf("player") == spotMap then return DR.Visible(unit) end
	return true
end

-- A summoner's claim has gone stale (review 2.2 #4): they left the group, or (a Wuber
-- summoner) their HI has been silent for over CLAIM_SILENT seconds. Never for my own.
DR.CLAIM_SILENT = 45
function DR.ClaimGone(k, now)
	if type(k) ~= "string" or k == "" or k == myKey() then return false end
	if not DR.units[k] then return true end
	local a, p = DR.apps[k], DR.peers[k]
	local at = math.max(tonumber(a and a.at) or -1, tonumber(p and p.at) or -1)
	return at >= 0 and (now or GetTime()) - at > DR.CLAIM_SILENT
end

-- A claim still holds: the channel began, or it is younger than CLAIM_TTL.
local function claimAlive(row, now)
	return row.claimedBy ~= nil and (row.channelAt ~= nil or now - (row.claimAt or 0) < DR.CLAIM_TTL)
end

local function raidChanged()
	W.Fire("DRIVE_RAID")
	DR.Changed()
end

-- The rows in queue order (first asked first; "Move to top" puts one ahead).
function DR.RaidQueue()
	local out = {}
	local _, spotMap = DR.RaidSpot()
	for _, row in pairs(DR.raidRows) do
		row.here = atSpot(DR.units[row.key], spotMap)
		out[#out + 1] = row
	end
	table.sort(out, function(a, b) return a.order < b.order end)
	return out
end

local function rowKey(name)
	local k = DR.ResolveKey and DR.ResolveKey(name) or W.Key(name)
	return k
end

-- A summoner key a crew window names (CAST b): a crew Warlock or me.
local function summonerKey(v)
	local k = v and W.Key(v)
	if not k then return nil end
	if k == myKey() then return DR.IsWarlock() and k or nil end
	local m = DR.CrewEntry(k)
	return (m and m.role == "lock") and k or nil
end

-- One raid fact on the rows. `mirror`: a raider's own window following the runner's queue.
local function applyRow(kind, from, a, b, now, mirror, c3)
	local k = a and rowKey(a)
	if not k then return end
	local row = DR.raidRows[k]
	if kind == "RA" then
		if row then return end
		if not mirror and (not DR.units[k] or DR.NeverRider(k)) then return end
		RAID.order = RAID.order + 1
		local unit = DR.units[k]
		DR.raidRows[k] = { key = k, name = (unit and W.UnitName(unit)) or W.Clean(a, 48), asked = now, order = RAID.order,
			state = "queued", tries = 0, fails = 0 }
	elseif not row then
		return
	elseif kind == "RD" then
		DR.raidRows[k] = nil
		-- the order keeper saw the raider land before this window's own tick did: count it here too
		-- (DR.LogRaid counts a raider once; a hand, cancel or gave-up drop never counts)
		if b == "here" and not mirror and row.tries > 0 then W.Fire("DRIVE_RAID_DONE", row.name, row.claimedBy) end
	elseif kind == "RT" then
		local low = row.order
		for _, r in pairs(DR.raidRows) do if r.order < low then low = r.order end end
		row.order = low - 1
	elseif kind == "CH" then
		-- (AUD-84) only the claimer's own channel counts: a losing summoner's CH never keeps a claim alive
		if row.state == "summoning" and (not row.claimedBy or row.claimedBy == from or row.claimedBy == (a and rowKey(from))) then
			row.channelAt = row.channelAt or now
		end
	elseif kind == "CAST" then
		local claimer = summonerKey(b) or from
		-- (AU24-04/05) a sync's copy of a claim this window already holds changes nothing (no extra try, no fresh clock)
		if c3 == "s" and row.claimedBy == claimer and (row.state == "summoning" or row.state == "waiting") then return end
		local stopTold = false
		if row.claimedBy and row.claimedBy ~= claimer and claimAlive(row, now) then
			-- two summoners took the same raider at once: the lower key keeps it, everywhere
			local winner, loser = row.claimedBy, claimer
			if claimer < row.claimedBy then winner, loser = claimer, row.claimedBy end
			-- (review 2.2 #5: my own ritual on the raider I lost: stop it, keep the shard)
			local mine = DR.cast and DR.cast.name and rowKey(DR.cast.name) == k
			if loser == myKey() and mine and not mirror then
				DR.Alert((DR.WhoIs and DR.WhoIs(winner) or winner) .. " has " .. W.Short(row.name) .. ": stop your summon.", "raid")
				stopTold = true
			end
			if winner ~= claimer then return end
		else
			row.tries = row.tries + 1
		end
		row.claimedBy, row.claimAt, row.channelAt, row.state, row.endAt = claimer, now, nil, "summoning", nil
		local _, spotMap = DR.RaidSpot()
		-- (round 17, C2) only the crew's windows: a raider's own window (a mirror) is never told
		if not mirror and claimer ~= myKey() and not stopTold and (not spotMap or DR.MapOf("player") == spotMap) then
			DR.Alert("Click the summoning portal - " .. W.Short(row.name) .. " is on the way!", "portal")
		end
	elseif kind == "END" then
		if row.state ~= "summoning" then return end
		-- (review 2.2 #5: only the claimer's END counts; a loser's cancel never frees the row)
		local ender = summonerKey(c3) or from
		if row.claimedBy and ender ~= row.claimedBy then return end
		if b == "1" then
			row.state, row.endAt = "waiting", now
		else
			row.state, row.claimedBy, row.claimAt, row.channelAt = "queued", nil, nil, nil
			row.fails = row.fails + 1
			if row.fails >= 2 then row.failedAt = now end
		end
	else
		return
	end
	raidChanged()
end

local RAID_KINDS = { RA = true, RD = true, RT = true, CH = true }

-- The window that keeps the queue's order (the runner when in the group, else the leader):
-- every RA goes through it, so all windows list the raiders in the same order.
local function orderKey()
	local cap = DR.CaptainKey()
	if cap == myKey() or (cap and DR.units[cap]) then return cap end
	if DR.IsLeader() then return myKey() end
	return (DR.LeaderOf()) or cap
end
DR.RaidOrderKey = orderKey

-- From DR.Apply: true when the fact was a raid one (handled here).
function DR.RaidApply(kind, from, mine, a, b, c3, now)
	if RAID_KINDS[kind] then
		if DR.Mode() ~= "raid" then return true end
		if kind == "RA" and from ~= orderKey() then
			-- a crew window heard a request: the order keeper lists it (for everyone)
			if orderKey() == myKey() and a and not DR.raidRows[rowKey(a) or "?"] then DR.Do("RA", a) end
			return true
		end
		applyRow(kind, from, a, b, now)
		return true
	end
	if (kind == "CAST" or kind == "END") and DR.Mode() == "raid" then
		applyRow(kind, from, a, b, now, nil, c3)
		return true
	end
	return false
end

-- (AU24-04, AU24-05) Raid rows live in memory only, so a window that reloads mid-raid has none. The order
-- keeper sends its rows to a crew window that asks for a sync (DR.SyncNow); a crew window sends its rows
-- to the order keeper when that keeper reloads (`keeper`: its key, from its HI asking for a sync), and the
-- keeper lists them again for everyone (DR.RaidApply). On the bulk lane, in queue order: RA per raider,
-- then for a claimed row CAST name, claimer, "s" (and END name, 1, claimer once that summon went).
function DR.RaidSync(keeper)
	if not DR.RaidOn() or next(DR.raidRows) == nil then return end
	if keeper then
		if keeper == myKey() or orderKey() ~= keeper then return end
	elseif orderKey() ~= myKey() then
		return
	end
	for _, row in ipairs(DR.RaidQueue()) do
		DR.SendBulk("RA", row.name)
		if row.claimedBy and (row.state == "summoning" or row.state == "waiting") then
			DR.SendBulk("CAST", row.name, row.claimedBy, "s")
			if row.state == "waiting" then DR.SendBulk("END", row.name, 1, row.claimedBy) end
		end
	end
end

-- A raider's window (not crew): the queue of a raid running raid summons, for its own
-- "Request a summon" line. Only from a runner or summoner whose HI says raid summons run.
-- (SEC-M5) Any group member can say so in its own HI, so a crew window (a member, or a runner with raid
-- summons on) never takes a mirrored row: its queue changes only through its crew's facts (DR.RaidApply).
function DR.RaidMirror(kind, key, a, b, c3)
	if DR.char().captain ~= "" or DR.RaidOn() then return end
	local app = DR.apps[key]
	if not (app and app.mode) then return end
	if kind == "RA" and app.mode ~= "R" then return end -- the runner's order only
	if RAID_KINDS[kind] or kind == "CAST" or kind == "END" then applyRow(kind, key, a, b, GetTime(), true, c3) end
end

-- Add a raid member to the queue (the console's +, or anyone who asked).
function DR.RaidAdd(name)
	if not DR.RaidOn() then return nil end
	local k = rowKey(name)
	if not k or not DR.units[k] or DR.NeverRider(k) then return nil end
	if DR.raidRows[k] then return DR.raidRows[k] end
	local who = W.UnitName(DR.units[k]) or name
	if orderKey() == myKey() then
		DR.Do("RA", who)
	else
		DR.Send("RA", who) -- the order keeper lists it for everyone
	end
	return DR.raidRows[k] or { key = k, name = who, state = "asked" }
end

-- Off the queue (why: "hand", "cancel", ...).
function DR.RaidDrop(name, why)
	local k = rowKey(name)
	local row = k and DR.raidRows[k]
	if not row then return false end
	DR.Do("RD", row.name, why or "hand")
	return true
end

function DR.RaidTop(name)
	local k = rowKey(name)
	local row = k and DR.raidRows[k]
	if not row then return false end
	DR.Do("RT", row.name)
	return true
end

-- The raider this window's button summons next: unclaimed, not at the spot, online. With
-- several summoners free, each takes a different one (the n-th free summoner the n-th row).
function DR.RaidNext()
	if not DR.RaidOn() or DR.IsPaused() or not DR.IsWarlock() then return nil end
	local now = GetTime()
	for _, row in pairs(DR.raidRows) do
		if row.claimedBy == myKey() and row.state == "summoning" and claimAlive(row, now) then return nil end
	end
	if not DR.CanCast(myKey()) then return nil end
	local free = {}
	for _, row in ipairs(DR.RaidQueue()) do
		local unit = DR.units[row.key]
		if unit and not row.here and DR.Online(unit) and (row.state == "queued" or (row.state == "summoning" and not claimAlive(row, now))) then
			free[#free + 1] = row
		end
	end
	if #free == 0 then return nil end
	local n = 0
	local busy = {}
	for _, row in pairs(DR.raidRows) do
		if row.state == "summoning" and claimAlive(row, now) then busy[row.claimedBy] = true end
	end
	for _, k in ipairs(DR.Summoners()) do
		if k == myKey() then return free[n + 1] end -- (review 2.2 #8: never another's raider)
		if DR.units[k] and DR.SummonerHasApp(k) and not busy[k] and DR.CanCast(k) then n = n + 1 end
	end
	return free[1]
end

-- Once a second on every crew window while raid summons run: arrivals, leavers, claims.
function DR.RaidTick(now)
	local _, spotMap = DR.RaidSpot()
	local changed = false
	for k, row in pairs(DR.raidRows) do
		local unit = DR.units[k]
		if not unit then
			DR.raidRows[k], changed = nil, true
		elseif atSpot(unit, spotMap) then
			DR.raidRows[k], changed = nil, true
			if row.tries > 0 then W.Fire("DRIVE_RAID_DONE", row.name, row.claimedBy) end
			-- the raiders' own windows (mirrors) never run this tick: the order keeper tells them
			if orderKey() == myKey() then DR.Send("RD", row.name, "here") end
		elseif row.state == "summoning" and (not claimAlive(row, now) or now - (row.claimAt or now) > DR.CAST_TTL
			or DR.ClaimGone(row.claimedBy, now)) then
			row.state, row.claimedBy, row.claimAt, row.channelAt, changed = "queued", nil, nil, nil, true
		elseif row.state == "waiting" and now - (row.endAt or row.claimAt or now) > DR.WAIT_TTL then
			row.state, row.claimedBy, changed = "queued", nil, true
			row.fails = row.fails + 1
			if row.fails >= 2 then row.failedAt = now end
		end
		if DR.raidRows[k] and row.state == "waiting" and not row.endAt and not row.claimAt then row.endAt = now end -- (REV-r32-1) no end time came with it: the wait starts now, so it ends
		if DR.raidRows[k] and row.failedAt and now - row.failedAt > DR.RAID_GIVE_UP then
			DR.raidRows[k], changed = nil, true
			if orderKey() == myKey() then DR.Send("RD", row.name, "gaveup") end
		end
	end
	-- (review 2.2 #9) the runner left the raid: raid summons stop (not just pause: raidRun is
	-- saved, and the next party would see "Request a summon")
	if DR.IsRunner() and not W.InGroup() and DR.char().captain == "" then
		DR.SetRaidRun(false)
		DR.Alert("Raid summons stopped: you left the raid.", "raid")
		return
	end
	-- (AU24-30) a crew window: the runner left the group and no window keeps the queue (not me, not another
	-- crew window that leads): a raider's 123 would reach nobody, so raid summons stop here too, said once
	if DR.char().captain ~= "" then
		local cap, keeper = DR.CaptainKey(), orderKey()
		local kept = keeper == myKey() or (keeper ~= nil and DR.units[keeper] ~= nil and DR.peers[keeper] ~= nil)
		if cap and not DR.units[cap] and not kept then
			DR.raidKeeperGoneAt = DR.raidKeeperGoneAt or now
			if now - DR.raidKeeperGoneAt >= DR.RAID_KEEPER_GONE then
				DR.raidKeeperGoneAt = nil
				DR.crewRaidRun = false
				for k in pairs(DR.raidRows) do DR.raidRows[k] = nil end
				DR.Alert("Raid summons stopped: the crew captain left the group.", "raid")
				if W.InGroup() then DR.Hello() end
				W.Fire("DRIVE_RAID")
				W.Fire("SETTINGS", "drive")
				DR.Changed()
				return
			end
		else
			DR.raidKeeperGoneAt = nil
		end
	end
	-- the runner lost lead or assist: raid summons pause (told once)
	if DR.IsRunner() and not DR.IsPaused() and not DR.CanRunRaid() then
		DR.SetPaused(true)
		if not DR.raidLostTold then
			DR.raidLostTold = true
			DR.Alert("Raid summons paused: you need lead or assist.", "raid")
		end
	end
	if changed then raidChanged() end
end

-- Raid members not at the spot and not queued: { name, key, class, zone, unit }.
function DR.NotHere()
	local out = {}
	if DR.Mode() ~= "raid" then return out end
	local _, spotMap = DR.RaidSpot()
	for _, m in ipairs(DR.Roster()) do
		if not DR.NeverRider(m.key) and not DR.raidRows[m.key] and not atSpot(m.unit, spotMap) then
			out[#out + 1] = { name = m.name, key = m.key, class = m.class, zone = (DR.PlaceOf(m.unit)), unit = m.unit }
		end
	end
	table.sort(out, function(a, b) return a.key < b.key end)
	return out
end

-- The raid's Warlocks for the picker: { key, name, shards, app, picked, offer, unit }.
function DR.RaidWarlocks()
	local out = {}
	local picked = {}
	for _, k in ipairs(DR.Summoners()) do picked[k] = true end
	if DR.IsWarlock() then
		out[1] = { key = myKey(), name = W.myName or W.Me(), shards = DR.Shards(), app = true, picked = picked[myKey()] == true,
			unit = "player", me = true }
	end
	for _, m in ipairs(DR.Roster()) do
		if m.class == "WARLOCK" then
			local app, peer = DR.apps[m.key], DR.peers[m.key]
			local shards = (peer and (peer.shards or -1) >= 0 and peer.shards) or (app and (app.shards or -1) >= 0 and app.shards) or nil
			local o = DR.offers[m.key]
			out[#out + 1] = { key = m.key, name = m.name, shards = shards, app = app ~= nil, picked = picked[m.key] == true,
				offer = o and o.state or nil, unit = m.unit }
		end
	end
	return out
end

-- Tick or untick a raid Warlock: with Wuber the crew offer ("raid"), without it a plain
-- summoner; untick takes them off.
function DR.RaidPick(name, on)
	local k = W.Key(name)
	if not k then return false end
	if not on then
		DR.RemoveSummoner(name)
		if k ~= myKey() and DR.CrewEntry(k) then DR.RemoveCrew(name) end
		return true
	end
	if k == myKey() then return DR.AddSummoner(name) end
	if DR.apps[k] then return DR.OfferCrew(name, "raid") end
	return DR.AddPlainSummoner(name) ~= nil
end

-- A raider asks or cancels with their own Wuber (RQ / RN): heard by the window that answers.
function DR.RaidHeard(kind, key, name)
	if not DR.RaidOn() or not DR.SyncAnswerer() then return end
	if kind == "RQ" then
		if DR.IsPaused() then return end -- (a pause stops new requests, not cancels)
		DR.RaidAdd(name)
	elseif DR.raidRows[key] then
		DR.RaidDrop(name, "cancel")
	end
end

-- Raid or party chat (the answering window) and whispers (any crew window): request words.
local function raidLine(text, sender, whisper)
	if not DR.on or not DR.RaidOn() then return end
	if not whisper and not DR.SyncAnswerer() then return end
	sender = str(sender)
	local k = sender and rowKey(sender)
	if not k or not DR.units[k] or DR.NeverRider(k) then return end
	local what = DR.RaidWords(text)
	if what == "request" then
		if DR.IsPaused() then return end -- (review 2.2 #9: no new requests while paused; cancels still count)
		DR.RaidAdd(sender)
	elseif what == "cancel" and DR.raidRows[k] then
		DR.RaidDrop(sender, "cancel")
	end
end
for _, ev in ipairs({ "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" }) do
	W.On(ev, function(text, sender) raidLine(text, sender, false) end)
end
W.On("CHAT_MSG_WHISPER", function(text, sender) raidLine(text, sender, true) end)

-- (round 17, C2) I left the group: no raid queue to follow any more. A raider's window (a mirror)
-- never runs DR.RaidTick, so its rows would stay and show in the next raid. (GROUP_LEFT also comes
-- when an instance group, a battleground say, ends while I'm still in my raid: then the rows stay.)
W.On("GROUP_LEFT", function()
	if W.InGroup() or next(DR.raidRows) == nil then return end
	for k in pairs(DR.raidRows) do DR.raidRows[k] = nil end
	raidChanged()
end)

-- The rider's side: raid summons running in my group? { runner, summoners, queued, position,
-- state } or nil.
function DR.RaidHere()
	if DR.RaidOn() then return nil end -- the crew runs the summons: never a rider of them
	local runner, summoners = nil, {}
	for k, app in pairs(DR.apps) do
		if DR.units[k] and app.mode == "R" then runner = app.name
		elseif DR.units[k] and app.mode == "r" then summoners[#summoners + 1] = app.name end
	end
	if not runner then return nil end
	table.sort(summoners)
	local mine = DR.raidRows[myKey()]
	local position
	if mine and mine.state == "queued" then
		position = 1
		for _, row in pairs(DR.raidRows) do
			if row ~= mine and row.state == "queued" and row.order < mine.order then position = position + 1 end
		end
	end
	return { runner = runner, summoners = summoners, queued = mine ~= nil, position = position, state = mine and mine.state or nil }
end

-- "Request a summon" (the Ride tab in a raid running raid summons). ok, why.
function DR.RaidAsk()
	if not DR.RaidHere() then return false, "Nobody runs raid summons in your group." end
	DR.Send("RQ")
	return true
end

function DR.RaidCancel()
	DR.raidRows[myKey()] = nil
	DR.Send("RN")
	W.Fire("DRIVE_RAID")
	return true
end
