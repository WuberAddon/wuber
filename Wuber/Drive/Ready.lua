-- Module: Drive.Ready
-- Purpose: Guild, blocklist, ready-to-drive checks (DR.Readiness), provider hand-off, the once-a-second
--   DR.Tick.
-- API: DR.NONPAY_REASON, DR.BlockEntry, DR.Blacklist, DR.Unblacklist, DR.BlockedList, DR.NonPayer,
--   DR.Refuse, DR.BlockedAskToast, DR.Readiness, DR.Ready, DR.Tick
-- Internals: (none)
-- Uses: Drive.Service
-- Later: Drive.Danger, Drive.Cut, Drive.Raincheck (DR.DangerTick, DR.CutTick, DR.RaincheckTick from DR.Tick),
--   Drive.Mail (DR.MailOwes from DR.NonPayer: the rider is listed as owing and may be told "you can still pay by mail")
-- Events: listens Listen PROVIDER; fires DRIVE_BLOCKED, SETTINGS
-- Standalone: no
-- Test: tests/drive/ready_test.lua
-- From: Drive_Service.lua 603-939 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("Drive.Ready", { "Drive.Service" })
local ServiceMod = W.Mod("Drive.Service")
local myKey, o = ServiceMod.myKey, ServiceMod.o
local DR = W.Drive

---------------------------------------------------------------------------
-- The guild ({guild} in messages)
---------------------------------------------------------------------------

-- (DR.Guild lives in Drive_Chat only: SPEC5 guild, review #25 - this copy added brackets)

---------------------------------------------------------------------------
-- Blocked players
---------------------------------------------------------------------------
-- W.db.drive.blocklist[key] = { reason, at }. Account-wide, shared by the crew.

DR.NONPAY_REASON = "you left without paying last time"
local askedToastAt = {} -- [key] = GetTime() of last blocked-for-not-paying toast

local function stamp()
	local ok, d = pcall(date, "%d %b")
	return ok and type(d) == "string" and d or ""
end

function DR.BlockEntry(key)
	local list = DR.db and DR.db.blocklist
	local v = key and list and list[key]
	if not v then return nil end
	if type(v) == "table" then
		if type(v.reason) ~= "string" then v.reason = "" end
		if type(v.at) ~= "string" then v.at = "" end
		return v
	end
	local e = { reason = type(v) == "string" and v or "", at = "" }
	list[key] = e
	return e
end

-- Blocks a player (or changes the reason). `remote`: a crew window said. Returns key, new.
function DR.Blacklist(name, reason, remote, at, auto)
	local key = W.Key(name)
	if not key or DR.IsCrewKey(key) or not DR.db then return nil end
	local c = DR.customers[key]
	if c then key = c.key end
	local had = DR.BlockEntry(key)
	reason = W.Clean((reason and reason ~= "") and reason or (had and had.reason) or "", 80)
	DR.db.blocklist[key] = { reason = reason, at = W.Clean(at or (had and had.at) or stamp(), 20) }
	if c and DR.customers[key] == c then
		if DR.units[key] then DR.ignored[key] = true end
		DR.Remove(c, "blocked")
	end
	if not remote then DR.Send("BLK", key, reason, DR.db.blocklist[key].at) end
	if not had then W.Fire("DRIVE_BLOCKED", (c and c.name) or name, reason, auto == true, remote == true) end
	DR.Changed()
	return key, not had
end

-- Unblocks a player (a first name unblocks every blocked name that starts with it).
function DR.Unblacklist(name, remote)
	local key = W.Key(name)
	if not key or not DR.db then return 0 end
	local n = 0
	for k in pairs(DR.db.blocklist) do
		if k == key or k:match("^(%S+)") == key then
			DR.db.blocklist[k] = nil
			DR.refusals[k] = nil
			askedToastAt[k] = nil
			n = n + 1
			if not remote then DR.Send("UBL", k) end
		end
	end
	DR.Changed()
	return n
end

function DR.BlockedList()
	local out = {}
	if not DR.db then return out end
	for k in pairs(DR.db.blocklist) do
		local e = DR.BlockEntry(k)
		out[#out + 1] = { key = k, reason = e.reason or "", at = e.at or "" }
	end
	table.sort(out, function(a, b) return a.key < b.key end)
	return out
end

-- A rider who was summoned and left with money owed. Never blocked when the payee has no
-- Wuber (nobody could watch them pay): the runner is told instead. Blocked or not, the rider can still
-- pay by mail (Drive.Mail): they go on its list, and the driver's next click may tell them how.
function DR.NonPayer(c)
	local due = DR.Due(c)
	if due <= 0 then return end
	if DR.MailOwes then DR.MailOwes(c, due) end
	local blind = c.payeeBlind or (c.caster and not DR.SummonerHasApp(c.caster))
	if o().autoBlock and not blind then
		DR.Blacklist(c.name, DR.NONPAY_REASON .. " (" .. W.Money(due) .. ")", false, nil, true)
	else
		local ask = blind and c.caster and (" Ask " .. DR.WhoIs(c.caster) .. " if they paid.") or ""
		DR.Alert(W.Short(c.name) .. " left without paying " .. W.Money(due) .. "." .. ask, "nonpayer")
	end
end

-- A blocked player who asks again is told why not, once in ten minutes.
function DR.Refuse(name, text)
	local key = W.Key(name)
	local e = key and DR.BlockEntry(key)
	if not e or not o().tellBlocked then return end
	if DR.Classify(text or "") ~= "request" then return end
	local r = DR.refusals[key]
	local now = GetTime()
	if r and now - r.at < 600 then return end
	DR.refusals[key] = { name = DR.CleanName(name) or name, key = key, reason = e.reason ~= "" and e.reason or "you are on our blocked list", at = now }
	DR.Changed()
end

-- (2.4.4) A rider blocked for not paying who asks for a summon again: toast the driver at most once a minute.
function DR.BlockedAskToast(name)
	local key = W.Key(name)
	local e = key and DR.BlockEntry(key)
	if type(e) ~= "table" or type(e.reason) ~= "string" then return false end
	if not e.reason:find(DR.NONPAY_REASON, 1, true) then return false end
	local now = (type(GetTime) == "function" and GetTime()) or 0
	local last = askedToastAt[key]
	if last and now - last < 60 then return false end
	askedToastAt[key] = now
	local who = W.Short(DR.CleanName(name) or name)
	if not who or who == "" then return false end
	DR.Alert(who .. " asked again: blocked for not paying.", "nonpayer")
	return true
end

---------------------------------------------------------------------------
-- Ready to drive
---------------------------------------------------------------------------

local function showWizard()
	local UI = W.UI
	if UI and UI.ShowDrive then UI.ShowDrive("wizard") end
end

-- { { ok = true|false|nil (information), text, fix = { label, run } } }
function DR.Readiness()
	local out = {}
	local function add(ok, text, fix) out[#out + 1] = { ok = ok, text = text, fix = fix } end
	local ch = DR.char()
	local lock = DR.Lock()
	if lock == "rr" then add(false, "Your old summoning addon is still on: it drives until you switch it off.") end
	if lock == "provider" then add(false, "Another addon drives for Wuber now.") end
	local runner = DR.Role() == "driver" and ch.captain == ""
	if not DR.IsWarlock() and not runner then
		add(ch.captain ~= "", ch.captain ~= "" and ("In " .. W.Short(ch.captain) .. "'s crew: you click the portal.")
			or "Set up driving to run a summoning service with a Warlock friend.")
		local _, to = DR.LeadTarget()
		if to then
			add(false, "You lead the group: only the leader can invite riders.",
				{ "Make " .. W.Short(to) .. " leader", function() DR.HandLead(true) end })
		end
		return out
	end

	-- who summons (SPEC4 1.1): a runner who is no Warlock must pick a Warlock
	local chosen = DR.Summoners()
	if runner and not DR.IsWarlock() and #chosen == 0 then
		add(false, "Choose who summons", { "Choose", function()
			local UI = W.UI
			if UI and UI.ShowDrive then UI.ShowDrive("wizard", 3) end
		end })
	end
	if DR.Mode() == "raid" and runner then
		local okRaid, why = DR.CanRunRaid()
		if not okRaid then add(false, why) end
	end
	if #chosen > 0 and runner then
		local parts = {}
		for _, k in ipairs(chosen) do
			local s = DR.WhoIs(k)
			local peer = DR.peers[k]
			if k == myKey() then
				local n = DR.Shards()
				s = s .. " " .. tostring(n or "?")
			elseif not DR.SummonerHasApp(k) then
				s = s .. " (no Wuber)"
			elseif peer and (peer.shards or -1) >= 0 then
				s = s .. " " .. peer.shards
			end
			if k ~= myKey() and not DR.units[k] then s = s .. " - not in your group" end
			parts[#parts + 1] = s
		end
		add(nil, "Summoners: " .. table.concat(parts, ", ") .. ".")
	end

	-- the crew
	local crew = DR.Crew()
	local here, heard, members = 0, 0, #crew - 1
	local now = GetTime()
	for i = 2, #crew do
		local m = crew[i]
		if m.here then here = here + 1 end
		if m.app and DR.peers[m.key] and now - (DR.peers[m.key].at or 0) <= 45 then heard = heard + 1 end
	end
	if not ch.wizard and members == 0 then
		-- Raid mode picks its Warlocks with the Warlocks pill, not the crew wizard
		if DR.Mode() ~= "raid" then
			add(false, "Crew not set up yet: who summons with you?", { "Set up my crew", showWizard })
		end
	elseif members == 0 then
		add(true, "Driving alone: riders bring 2 helpers.")
	else
		add(here >= members, here >= members and ("Crew: all " .. members .. " in your group.")
			or ("Crew: " .. here .. " of " .. members .. " in your group - invite them."), here < members and { "Crew", function()
				local UI = W.UI
				if UI and UI.ShowDrive then UI.ShowDrive("crew") end
			end } or nil)
		local apps = 0
		for i = 2, #crew do if crew[i].app and crew[i].here then apps = apps + 1 end end
		if apps > 0 then
			add(heard >= apps, heard >= apps and "Hearing Wuber from all of them."
				or ("Heard Wuber from " .. heard .. " of " .. apps .. ": is it on there?"))
		end
	end

	-- the spell and the shards (a Warlock who summons)
	local summons = DR.IsWarlock() and #chosen == 0
	for _, k in ipairs(chosen) do if k == myKey() then summons = true end end
	if summons then
		local spell, known, early = DR.Ritual()
		if known or not early then -- (early: the spellbook may not be loaded yet: say nothing)
			add(known, known and "Knows the summoning spell." or "The summoning spell isn't known yet: a Warlock trainer teaches it at level 20.")
		end
		local shards = DR.Shards()
		if o().needShards then
			add(shards ~= nil and shards > 0, shards == nil and "The Soul Shard count can't be read."
				or (shards > 0 and (shards .. " Soul Shard" .. (shards == 1 and "" or "s") .. " (one per summon).")
				or "No Soul Shards: Drain Soul a mob as it dies to make one."))
		end
	end

	-- several stations (SPEC4 2.1)
	local stations = DR.Stations and DR.Stations() or {}
	if #stations >= 2 then
		local parts = {}
		for _, st in ipairs(stations) do
			parts[#parts + 1] = st.place .. (st.open and "" or " (off)") .. (st.ready and "" or " - riders bring a friend")
		end
		add(nil, "Stations: " .. table.concat(parts, ", ") .. ".")
	end

	-- who casts
	local order = DR.CastOrder()
	if #order > 1 and DR.IsWarlock() then
		local main = DR.MainCaster()
		if main then
			local _, turn = DR.MayCast()
			local okMain, why = DR.CanCast(main)
			if okMain then
				add(true, "Main caster: " .. DR.WhoIs(main) .. ". The others click the portal.")
			elseif turn and DR.CanCast(turn) then
				add(true, DR.WhoIs(main) .. " " .. why .. ": " .. DR.WhoIs(turn) .. " summons instead.")
			else
				add(false, "Nobody can summon now (" .. DR.WhoIs(main) .. " " .. tostring(why) .. ").")
			end
		else
			add(nil, "Whoever clicks casts.", { "Me as caster", function() DR.SetCaster(W.myName or "") end })
		end
	end

	if W.InGroup() then
		if DR.CanInvite() then
			add(nil, DR.IsLeader() and "You lead the group: this window invites riders."
				or "Another window leads and invites; this one helps.")
		elseif DR.Mode() ~= "raid" then -- raid summons never invite, so the lead does not matter
			local lk, lname = DR.LeaderOf()
			local who = lname and W.Short(lname) or "Someone else"
			add(false, who .. " leads the group: only the leader can invite. Ask " .. who .. " to make you leader.")
		end
	end
	local mode = DR.ChatMode and DR.ChatMode() or o().whisperMode
	local how = ({
		macro = "Whispers go out when you click the big button.",
		box = "Whispers go in the chat box: Enter sends each one.",
		off = "Whispers are off: riders are told nothing.",
	})[mode] or "Whispers go out when you click the big button."
	if mode == "off" then add(false, how) else add(nil, how) end
	return out
end

function DR.Ready()
	for _, line in ipairs(DR.Readiness()) do
		if line.ok == false then return false end
	end
	return true
end

---------------------------------------------------------------------------
-- A third-party provider: the engine steps aside
---------------------------------------------------------------------------

W.Listen("PROVIDER", function(provider)
	if type(provider) ~= "table" and type(W.provider) ~= "table" then return end
	if DR.char().drive and DR.Role() == "driver" and DR.on then
		DR.char().drive = false
		DR.SendConfig()
		W.Fire("SETTINGS", "drive")
		if not DR.providerTold then
			DR.providerTold = true
			DR.Alert("Another addon now drives for Wuber: your driving is closed.", "info")
		end
		DR.Changed()
	end
end)

---------------------------------------------------------------------------
-- Once a second
---------------------------------------------------------------------------

local function call(name, ...)
	local f = DR[name]
	if type(f) == "function" then W.Safe("drive " .. name, f, ...) end
end

function DR.Tick()
	if not DR.on or not DR.db then return end
	local now = GetTime()
	if DR.FlushComm then DR.FlushComm() end
	if DR.OfferTick then DR.OfferTick() end
	if not DR.Active() then return end
	if DR.OwingTick then DR.OwingTick(now) end
	-- HI every 15 s; every 20 s with five or more crew windows (SPEC4 2.3: the WUBERT budget)
	local hiEvery = (#DR.char().crew + 1 >= 5) and 20 or 15
	if W.InGroup() and now - (DR.lastHi or -100) >= hiEvery then DR.Hello() end
	DR.SyncRoster()
	-- (SPEC5 promote: no DR.HandLead from this timer; PromoteToLeader only from a click, see
	-- DR.LeadFix)
	call("CastWatch", now)
	call("LogTick")
	-- 2.3.0 (SPEC7 5.6, 5.5, 5.8): PvP danger, the cut ledger's shift, the raincheck book's clocks
	call("DangerTick", now)
	call("CutTick", now)
	call("RaincheckTick", now)
	-- round 9: the customer book's sync to my own crew windows (Drive.Book)
	call("BookTick", now)
	if DR.IsWarlock() then
		local cd = DR.RitualCooldown() > 0
		if W.InGroup() and cd ~= (DR.lastCd or false) then DR.Hello() end
		DR.ShardsChanged()
	end
	if DR.Mode() == "raid" and DR.RaidOn() then
		-- raid summons (SPEC4 3): no invites, adverts, trades or riders' clocks
		call("RaidTick", now)
		call("PumpChat")
		DR.Changed()
		return
	end
	if not DR.Selling() then
		-- closed: the console only needs the odd redraw (crew going silent, shards)
		if now - (DR.lastIdleDraw or -100) >= 5 then
			DR.lastIdleDraw = now
			DR.Changed()
		end
		return
	end
	if DR.QueueTick then DR.QueueTick(now) end
	DR.CheckAdvert()
	DR.PumpInvites()
	call("PumpChat")
	call("PumpTrade")
	DR.Changed()
end
