-- Module: Drive.Core
-- Purpose: Driver engine core (was Drive_Core.lua).
-- API: W.Drive, DR.SHARD_ITEM, DR.RITUAL_ID, DR.RITUAL_NAME, DR.MACRO_MAX, DR.TEXT_MAX, DR.customers,
--   DR.units, DR.peers, DR.apps, DR.session, DR.ignored, DR.helpers, DR.comm, DR.KEYWORDS,
--   DR.OPT_DEFAULTS, DR.OPT_LATE, DR.Opt, DR.CHAR_KEYS, DR.CleanOpt, DR.InitDB, DR.opts, DR.char, DR.Changed, DR.Alert,
--   DR.PUBLIC_POPUP, DR.PUBLIC_WARNING, DR.SetAutoPublic, DR.PlacePublicWarning, DR.RestorePublicWarning,
--   DR.Lock, DR.Class, DR.IsWarlock, DR.InCrew, DR.Role, DR.Active, DR.SetRunner, DR.IsRunner,
--   DR.CaptainKey, DR.Captain, DR.IsCaptain, DR.CrewEntry, DR.IsCrewKey, DR.IsCrew, DR.TrustKey,
--   DR.IsBellKey, DR.Crew, DR.SetCrewMember, DR.DropCrewMember, DR.AddPlainHelper, DR.AddPlainSummoner, DR.CREW_MAX,
--   DR.SummonerHasApp, DR.InRaid, DR.InGroup, DR.GroupSize, DR.IsLeader, DR.IsLeaderKey, DR.Roster,
--   DR.Visible, DR.SameMap, DR.Here, DR.Online, DR.UnitClassKey, DR.Shards, DR.Ritual,
--   DR.RitualCooldown, DR.Dest, DR.MaxGroup, DR.MergeRetired, DR.ImportRR, DR.Snapshot,
--   DR.RestoreQueue, DR.on
-- Internals: (none)
-- Uses: (none)
-- Later: Drive.Raincheck (DR.RecentPaidSave/Load with the queue snapshot), Drive.Service (DR.SetOpt)
-- Saves: W.Char().queue = { at, list, paid, with }; list holds joined+ riders and (AU24-36) riders still "queued",
--   restored as queued with a fresh time (state "queued" in a list row is the new field value; old data has none).
-- Events: listens On PLAYER_LOGOUT, SPELLS_CHANGED, login; fires DRIVE, DRIVE_ALERT, DRIVE_CREW, DRIVE_REMOVED
-- Standalone: no
-- Test: tests/drive/core_test.lua
-- From: Drive_Core.lua 1-1043 (Wuber 2.2.1)
--
-- Drive_Core: the driver engine's core (Ritual Rides 1.4.1, ported into Wuber 2.0).
--
--   W.db.drive      account-wide: habits (opts), messages, blocklist, log, the button
--   W.Char()        per character: open, price, place, crew, caster, captain
--   DR.Lock()       "rr" while an old Ritual Rides drives, "provider" with a third party
--   DR.ImportRR()   RitualRidesDB -> W.db.drive / W.Char(), once per account (and character)
--   the crew        who summons with this window: consent per member (Drive_Team.lua)
--   the group       roster, leader, here, online; Soul Shards and the ritual
--
-- No function here calls another Drive file at load time: only from W.OnLogin, events,
-- timers and clicks, always nil-guarded.

local _, W = ...
local Mod = W.Module("Drive.Core", {})
W.Drive = W.Drive or {}
local DR = W.Drive

local plain, str, num = W.Plain, W.Str, W.Num

DR.SHARD_ITEM = 6265
DR.RITUAL_ID = 698
DR.RITUAL_NAME = "Ritual of Summoning"
DR.MACRO_MAX = 255
DR.TEXT_MAX = 190

DR.customers = DR.customers or {} -- [key] = customer
DR.units = DR.units or {}         -- [key] = unit token of everyone else in my group
DR.peers = DR.peers or {}         -- [key] = crew windows heard in this group (HI)
DR.apps = DR.apps or {}           -- [key] = { class, role, version, at }: group members running Wuber
DR.session = DR.session or { rides = 0, copper = 0 }
DR.ignored = DR.ignored or {}     -- [key] = true: in the group, taken off the list by hand
DR.helpers = DR.helpers or {}     -- [key] = true: in the group, marked "Not a rider"
DR.comm = DR.comm or { sent = 0, failed = 0, heard = 0 }

---------------------------------------------------------------------------
-- Saved settings
---------------------------------------------------------------------------

DR.KEYWORDS = { "summon", "summons", "summ", "sum", "inv", "invite", "ride", "taxi" }

DR.OPT_DEFAULTS = {
	autoInvite = true, oneAtATime = false, maxGroup = 0, autoAccept = true,
	-- autoPublic: off from 2.3.2; turned on only through the warning (DR.SetAutoPublic)
	watchPublic = true, autoPublic = false,
	-- (2.4, the author's yes of 21 Nov 2026) one whisper back to a clear public request for your place
	-- (Drive.AutoReply); off: such a line only waits as a lead
	autoReply = true,
	watchChannels = "services, trade, lookingforgroup, world, general",
	keywords = DR.KEYWORDS,
	whisperMode = "auto", autoTrade = true, acceptUnder = false, remindPay = true, kickAfter = true,
	autoBlock = true, tellBlocked = true, needShards = true, lowShards = 3,
	adEvery = 15, adChannels = "services, trade, lookingforgroup", awayGuard = true,
	target = 100000, ritual = "", inviteCap = 8, inviteTimeout = 90, helpSeen = "",
	raidsum = true, raidclick = true, -- 2.1 raid summons: whisper the raider, raid line "click the portal"
}

-- 2.3.0 options: defaults InitDB never writes, so saved data from before stays
-- as it was until the player changes one. Read them with DR.Opt(key); DR.SetOpt cleans them too.
-- 2.3.0 round 9: showPass (riders see the ride passphrase; off by default, the author), shareNotes (customer
-- notes go to this driver's own crew windows, Drive.Book)
DR.OPT_LATE = { cutRule = "clicks", cutCaster = 40, watchBounty = true, showPass = false, shareNotes = true }

function DR.Opt(key)
	local v = DR.opts()[key]
	if v == nil then return DR.OPT_LATE[key] end
	return v
end

DR.CHAR_KEYS = {
	paused = false, dest = "", destWords = "", caster = "", captain = "", wizard = false,
	-- 2.1: "sell" | "raid"; a non-Warlock who runs the service; raid summons running
	mode = "sell", runner = false, raidRun = false, alertWindow = false,
}

local MODES = { auto = true, macro = true, box = true, off = true }

local function copyList(t)
	local out = {}
	for i, v in ipairs(t) do out[i] = v end
	return out
end

local function clampInt(v, lo, hi, def)
	v = tonumber(v)
	if not v or v ~= v then return def end
	v = math.floor(v + 0.5)
	if v < lo then v = lo elseif v > hi then v = hi end
	return v
end

-- The value of an option made sane (type, range). Shared by InitDB, SetOpt and the import.
function DR.CleanOpt(key, v)
	local def = DR.OPT_DEFAULTS[key]
	if def == nil then def = DR.OPT_LATE[key] end
	if def == nil then return nil end
	if key == "cutRule" then return (v == "equal") and "equal" or "clicks"
	elseif key == "cutCaster" then return math.floor(clampInt(v, 0, 100, def) / 5 + 0.5) * 5
	elseif key == "keywords" then
		local list = {}
		if type(v) == "string" then
			for w in v:lower():gmatch("[%a%d]+") do if #list < 20 then list[#list + 1] = w:sub(1, 20) end end
		elseif type(v) == "table" then
			for _, w in ipairs(v) do
				w = tostring(w):lower():match("^[%a%d]+$")
				if w and #list < 20 then list[#list + 1] = w:sub(1, 20) end
			end
		end
		if #list == 0 then return copyList(DR.KEYWORDS) end
		return list
	elseif key == "whisperMode" then
		if v == "direct" then return "auto" end
		return MODES[v] and v or "auto"
	elseif key == "maxGroup" then
		v = tonumber(v)
		if not v or v ~= v or v < 3 then return 0 end
		return clampInt(v, 3, 40, 0)
	elseif key == "lowShards" then return clampInt(v, 0, 10, def)
	elseif key == "adEvery" then
		v = clampInt(v, 0, 60, def)
		if v > 0 and v < 15 then v = 15 end
		return v
	elseif key == "inviteCap" then return clampInt(v, 1, 20, def)
	elseif key == "inviteTimeout" then return clampInt(v, 30, 300, def)
	elseif key == "target" then return clampInt(v, 10000, 500000, def)
	elseif type(def) == "boolean" then
		if type(v) == "boolean" then return v end
		return def
	elseif type(def) == "string" then
		if type(v) ~= "string" then return def end
		return W.Clean(v, 120)
	end
	return def
end

local function newDrive()
	return {
		v = 1, opts = {}, templates = {}, blocklist = {},
		log = { v = 1, rides = {}, team = {}, asks = {}, open = {}, seen = {}, wreq = {}, wdec = {}, rivals = {} },
		stats = { rides = 0, copper = 0, tips = 0 },
		bell = { name = "", team = {}, lead = "", service = "", count = 0 },
		button = { pos = nil, scale = 1, sizeSet = false, locked = false, shown = true, key = nil, keepClosed = false },
	}
end

function DR.InitDB()
	local db = W.db or (W.InitDB and W.InitDB())
	if type(db) ~= "table" then return nil end
	local d = db.drive
	if type(d) ~= "table" then
		d = newDrive()
		db.drive = d
	end
	d.v = 1
	local fresh = newDrive()
	for _, k in ipairs({ "opts", "templates", "blocklist", "log", "stats", "bell", "button" }) do
		if type(d[k]) ~= "table" then d[k] = fresh[k] end
	end
	for k in pairs(DR.OPT_DEFAULTS) do
		local v = d.opts[k]
		if v == nil then
			local def = DR.OPT_DEFAULTS[k]
			d.opts[k] = type(def) == "table" and copyList(def) or def
		else
			d.opts[k] = DR.CleanOpt(k, v)
		end
	end
	local l = d.log
	l.v = 1
	for _, k in ipairs({ "rides", "team", "asks", "open", "seen", "wreq", "wdec", "rivals" }) do
		if type(l[k]) ~= "table" then l[k] = {} end
	end
	for _, k in ipairs({ "rides", "copper", "tips" }) do
		if type(d.stats[k]) ~= "number" then d.stats[k] = 0 end
	end
	local b = d.bell
	for k, def in pairs(fresh.bell) do
		if type(b[k]) ~= type(def) then b[k] = type(def) == "table" and {} or def end
	end
	local bt = d.button
	for k, def in pairs(fresh.button) do
		if def ~= nil and type(bt[k]) ~= type(def) then bt[k] = def end
	end
	if type(bt.scale) ~= "number" or bt.scale ~= bt.scale then bt.scale = 1 end
	-- 2.3.2: "Invite public chat buyers" is off by default. Up to 2.3.1 this function
	-- stored the old default (true) for every player, so a saved true can't be told from a player's
	-- own choice: there was no "changed by the player" marker. The one-time migration (d.publicV)
	-- turns every saved true off, unless d.publicChosen says the player set it after the warning
	-- (DR.SetAutoPublic writes it; nothing before 2.3.2 did). Someone who wants it back turns it
	-- on once more, through the warning. A saved false (the author's) stays false.
	if d.publicV ~= 1 then
		if d.publicChosen ~= true then d.opts.autoPublic = false end
		d.publicV = 1
	end
	DR.db = d
	return d
end

---------------------------------------------------------------------------
-- Inviting public chat buyers: on only after a warning
---------------------------------------------------------------------------

DR.PUBLIC_POPUP = "WUBER_AUTO_PUBLIC"
DR.PUBLIC_WARNING = "Wuber reads public chat channels (Trade, LookingForGroup, Services, World, General) and invites players who seem to want your place. It can misread"
	.. " messages, so set your place and stations correctly first, and expect the odd wrong invite. Turn it on?"

-- (2.3.2, E1) The warning is the game's own popup, which opens at the top of the screen, over the
-- phone's back arrow, title and search, in small text. OnShow centres it on the open phone,
-- inside it. (2.3.3, H2) The popup is scaled by UIParent, not by the phone, so at a small UI scale
-- its text was still small. It is now scaled once to the phone's effective scale (popup scale =
-- phone effective scale / UIParent's) and its text set to Wuber's body size, so the text is as big
-- as the phone's body text at any UI scale. The popup frames are shared with the game: the scale
-- and font are put back when it hides (DR.RestorePublicWarning) or is placed with no phone.
-- Without an open phone it is left where the game put it.
local function bodySize()
	local TM = W.Theme
	local sz = type(TM) == "table" and type(TM.SIZE) == "table" and W.Num(TM.SIZE.body)
	return sz or 13
end

function DR.RestorePublicWarning(pop)
	if type(pop) ~= "table" then return false end
	local o = pop.wuberPublicOrig
	if type(o) ~= "table" then return false end
	pop.wuberPublicOrig = nil
	-- (run 1, group o) the opaque backdrop and the alpha go back with the rest
	if pop.wuberBack and pop.wuberBack.Hide then pop.wuberBack:Hide() end
	if o.alpha and pop.SetAlpha then pop:SetAlpha(o.alpha) end
	if o.scale and pop.SetScale then pop:SetScale(o.scale) end
	local text = pop.text
	if type(text) == "table" and o.font and text.SetFont then text:SetFont(o.font, o.size, o.flags) end
	return true
end

function DR.PlacePublicWarning(pop)
	local phone = rawget(_G, "WuberFrame")
	if type(pop) ~= "table" or type(phone) ~= "table" or not phone:IsShown() then
		DR.RestorePublicWarning(pop)
		return false
	end
	local pw = W.Num(phone:GetWidth()) or 0
	local w = math.min(340, pw - 40)
	if w < 200 then DR.RestorePublicWarning(pop) return false end
	local text = pop.text
	if type(pop.wuberPublicOrig) ~= "table" then
		local o = { scale = W.Num(pop.GetScale and pop:GetScale()), alpha = W.Num(pop.GetAlpha and pop:GetAlpha()) }
		if type(text) == "table" and text.GetFont then o.font, o.size, o.flags = text:GetFont() end
		pop.wuberPublicOrig = o
	end
	-- the popup's scale makes one popup unit the same size on screen as one phone unit
	local pe = W.Num(phone.GetEffectiveScale and phone:GetEffectiveScale())
	local ue = W.Num(UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale())
	if pe and ue and pe > 0 and ue > 0 and pop.SetScale then pop:SetScale(pe / ue) end
	-- (run 1, group o) the game's popup (a skin may thin its backdrop) let the chips behind the phone's text show
	-- through the warning: an opaque panel behind its own words, and the popup itself fully opaque
	if pop.SetAlpha then pop:SetAlpha(1) end
	if not pop.wuberBack and pop.CreateTexture then
		local back = pop:CreateTexture(nil, "BACKGROUND", nil, -8)
		back:SetAllPoints(pop)
		back:SetColorTexture(0.07, 0.06, 0.16, 1)
		pop.wuberBack = back
	end
	if pop.wuberBack then pop.wuberBack:Show() end
	pop:ClearAllPoints()
	pop:SetPoint("CENTER", phone, "CENTER", 0, 0)
	pop:SetWidth(w)
	if type(text) == "table" then
		text:SetWidth(w - 40)
		local o = pop.wuberPublicOrig
		if o.font and text.SetFont then text:SetFont(o.font, bodySize(), o.flags or "") end
		local h = W.Num(text:GetStringHeight())
		if h and h > 0 then pop:SetHeight(h + 90) end
	end
	return true
end

local publicAsk = { waiting = nil } -- the callers waiting on the warning on screen

local function putAutoPublic(on)
	local d = DR.db or DR.InitDB()
	if d then d.publicChosen = true end
	if type(DR.SetOpt) == "function" then DR.SetOpt("autoPublic", on) else DR.opts().autoPublic = on end
end

-- Turns "Invite public chat buyers" on or off; done(on) is told the result. Off happens at once.
-- On asks first (DR.PUBLIC_WARNING, Yes / Cancel; Cancel leaves it off). Returns true or false
-- when it is settled now, "asked" while the question is on screen, nil when it can't be asked
-- (then it stays off). Settings and /wuber drive market both come here.
function DR.SetAutoPublic(on, done)
	local function tell(v) if type(done) == "function" then W.Safe("public invites", done, v) end end
	if not on then
		putAutoPublic(false)
		tell(false)
		return false
	end
	if DR.opts().autoPublic == true then tell(true) return true end
	local dialogs, show = rawget(_G, "StaticPopupDialogs"), rawget(_G, "StaticPopup_Show")
	if type(dialogs) ~= "table" or type(show) ~= "function" then return nil end
	-- Asked again while the warning is up (Settings, then the slash command): the same question
	-- answers both. Registering it again would make StaticPopup_Show reuse the visible popup and
	-- call the new entry's OnCancel, so the second caller heard "off" before Yes (review #5).
	local find = rawget(_G, "StaticPopup_FindVisible")
	if publicAsk.waiting and dialogs[DR.PUBLIC_POPUP] and type(find) == "function" and find(DR.PUBLIC_POPUP) then
		publicAsk.waiting[#publicAsk.waiting + 1] = done
		return "asked"
	end
	local waiting = { done }
	publicAsk.waiting = waiting
	local function answer(v)
		if publicAsk.waiting == waiting then publicAsk.waiting = nil end
		if v then putAutoPublic(true) end
		for _, fn in ipairs(waiting) do
			if type(fn) == "function" then W.Safe("public invites", fn, v) end
		end
	end
	dialogs[DR.PUBLIC_POPUP] = {
		text = DR.PUBLIC_WARNING, button1 = "Yes", button2 = "Cancel",
		OnAccept = function() W.Safe("public invites", answer, true) end,
		OnCancel = function() W.Safe("public invites", answer, false) end,
		OnShow = function(self) W.Safe("public invites", DR.PlacePublicWarning, self) end,
		OnHide = function(self) W.Safe("public invites", DR.RestorePublicWarning, self) end,
		timeout = 0, whileDead = 1, hideOnEscape = 1, noCancelOnReuse = 1, preferredIndex = 3,
	}
	-- The game returns nil (no error) when all its popup slots are taken: that is not shown either.
	local ok, dlg = pcall(show, DR.PUBLIC_POPUP)
	if not ok or dlg == nil then publicAsk.waiting = nil return nil end
	return "asked"
end

function DR.opts()
	local d = DR.db or DR.InitDB()
	return d and d.opts or {}
end

-- This character's driver settings (W.Char(), with the engine's keys made sane).
function DR.char()
	local c = W.Char()
	for k, def in pairs(DR.CHAR_KEYS) do
		if type(c[k]) ~= type(def) then c[k] = def end
	end
	if type(c.crew) ~= "table" then c.crew = {} end
	local bad = #c.crew > 8
	for _, m in ipairs(c.crew) do
		if type(m) ~= "table" or type(m.name) ~= "string" or (m.role ~= "lock" and m.role ~= "helper") or type(m.app) ~= "boolean" then
			bad = true
			break
		end
	end
	if bad then
		local clean = {}
		for _, m in ipairs(c.crew) do
			if type(m) == "table" and W.Key(m.name) and #clean < 8 then
				if m.role ~= "lock" and m.role ~= "helper" then m.role = "helper" end
				m.app = m.app ~= false
				clean[#clean + 1] = m
			end
		end
		c.crew = clean
	end
	local price = tonumber(c.price)
	if not price or price ~= price or price < (W.MIN_PRICE or 5000) then c.price = W.MIN_PRICE or 5000 end
	if c.mode ~= "sell" and c.mode ~= "raid" then c.mode = "sell" end
	-- the chosen summoners (full names, cast order) and the stations switched off
	if type(c.summoners) ~= "table" then c.summoners = {} end
	if type(c.stations) ~= "table" then c.stations = {} end
	return c
end

---------------------------------------------------------------------------
-- Changed: redraws coalesced
---------------------------------------------------------------------------

local dirty = false
function DR.Changed()
	if dirty then return end
	dirty = true
	W.After(0.05, function()
		dirty = false
		W.Fire("DRIVE")
	end)
end

-- data (optional, 2.3.0): what the alert is about, for the toast's click (kind "raincheck":
-- { rideId, name })
function DR.Alert(text, kind, data)
	if data ~= nil then
		W.Fire("DRIVE_ALERT", text, kind or "info", data)
	else
		W.Fire("DRIVE_ALERT", text, kind or "info")
	end
end

---------------------------------------------------------------------------
-- The lock: one engine at a time
---------------------------------------------------------------------------

local rrLock = nil -- decided once at login

local function rrDriving()
	local rr = rawget(_G, "RitualRides")
	return type(rr) == "table" and rr.retired ~= true
end

function DR.Lock()
	-- (before PLAYER_LOGIN the old addon is read live: Wuber has no load-order tie to it any
	-- more, SPEC5 rrmentions; the answer is fixed at login)
	local lock = rrLock
	if lock == nil then lock = rrDriving() end
	if lock then return "rr" end
	if type(W.provider) == "table" then return "provider" end
	return nil
end

function DR.Class()
	if type(UnitClass) ~= "function" then return nil end
	local ok, _, file = pcall(UnitClass, "player")
	return ok and str(file) or nil
end

function DR.IsWarlock() return DR.Class() == "WARLOCK" end

-- Whether this character is in someone's crew (or leads one).
function DR.InCrew()
	local c = DR.char()
	return c.captain ~= "" or #c.crew > 0
end

-- "driver" (a Warlock, or since 2.1 any class that set up running the service: a "runner"),
-- "helper" (another class in someone's crew), "alert" (an alert character that heard a
-- crew), or nil.
function DR.Role()
	if DR.IsWarlock() then return "driver" end
	local c = DR.char()
	if c.captain ~= "" then return "helper" end
	if c.runner == true or #c.summoners > 0 then return "driver" end
	if #c.crew > 0 then return "helper" end
	local d = DR.db or DR.InitDB()
	if d and type(d.bell.team) == "table" and #d.bell.team > 0 then return "alert" end
	return nil
end

-- The engine may run here: no lock, and a Warlock or a crew member.
function DR.Active()
	if DR.Lock() then return false end
	local role = DR.Role()
	return role == "driver" or role == "helper"
end

-- This character runs the service (any class): it opens, prices and is the captain. A
-- non-Warlock runner needs a Warlock summoner (DR.SetSummoners) before it can open.
function DR.SetRunner(on)
	local c = DR.char()
	c.runner = on and true or false
	if c.runner then
		c.captain = ""
		if DR.RestoreOwnConfig then DR.RestoreOwnConfig() end -- (out of a crew: my own price, place and group come back)
	end
	W.Fire("DRIVE_CREW")
	DR.Changed()
	return c.runner
end

function DR.IsRunner()
	return DR.Role() == "driver" and DR.char().captain == ""
end

---------------------------------------------------------------------------
-- The crew
---------------------------------------------------------------------------

local function me() return W.myKey end

function DR.CaptainKey()
	local c = DR.char()
	if c.captain == "" then return me() end
	return W.Key(c.captain)
end
DR.Captain = DR.CaptainKey

function DR.IsCaptain() return DR.char().captain == "" end

-- The crew entry of a key, or nil.
function DR.CrewEntry(k)
	if not k then return nil end
	for _, m in ipairs(DR.char().crew) do
		if W.Key(m.name) == k then return m end
	end
	return nil
end

-- Me, a full name in my crew, or (as a member) my captain. No first-name matching.
function DR.IsCrewKey(k)
	if not k then return false end
	if k == me() then return true end
	if DR.CrewEntry(k) then return true end
	local c = DR.char()
	return c.captain ~= "" and W.Key(c.captain) == k
end

function DR.IsCrew(name) return DR.IsCrewKey(W.Key(name)) end

-- Crew whose word counts over the wire ("Add anyway" helpers without Wuber never do).
function DR.TrustKey(k)
	if not DR.IsCrewKey(k) or k == me() then return false end
	local m = DR.CrewEntry(k)
	return not m or m.app ~= false
end

function DR.IsBellKey(k)
	if not k then return false end
	local d = DR.db or DR.InitDB()
	local b = d and W.Key(d.bell.name)
	return b ~= nil and k == b
end

-- The crew as the UI shows it, me first:
-- { { name, key, role, app, here, heard, shards, silent, me, captain } }
function DR.Crew()
	local out, now = {}, GetTime()
	local c = DR.char()
	local capKey = DR.CaptainKey()
	out[1] = {
		name = W.myName or W.Me(), key = me(), role = DR.IsWarlock() and "lock" or "helper", app = true,
		here = true, heard = true, shards = DR.IsWarlock() and DR.Shards() or nil, silent = false, me = true,
		captain = capKey == me(),
	}
	local seen = { [me() or "?"] = true }
	local function add(name, role, app)
		local k = W.Key(name)
		if not k or seen[k] then return end
		seen[k] = true
		local peer = DR.peers[k]
		local heard = peer ~= nil
		local r = role
		if peer and peer.role == "L" then r = "lock" elseif peer and peer.role == "H" then r = "helper" end
		out[#out + 1] = {
			name = (peer and peer.name) or name, key = k, role = r or "helper", app = app ~= false,
			here = DR.units[k] ~= nil, heard = heard,
			shards = (r == "lock" and peer and (peer.shards or -1) >= 0) and peer.shards or nil,
			silent = not peer or now - (peer.at or 0) > 45, captain = k == capKey,
		}
	end
	if c.captain ~= "" then
		local ce = DR.CrewEntry(capKey)
		add(c.captain, ce and ce.role, true)
	end
	for _, m in ipairs(c.crew) do add(m.name, m.role, m.app) end
	return out
end

-- The most crew members beside the captain.
DR.CREW_MAX = 8

-- Adds or updates a member (captain side and CRW). Returns the entry.
function DR.SetCrewMember(name, role, app)
	local k = W.Key(name)
	if not k or k == me() then return nil end
	local c = DR.char()
	local m = DR.CrewEntry(k)
	if not m then
		if #c.crew >= DR.CREW_MAX then return nil end
		m = { name = name }
		c.crew[#c.crew + 1] = m
	end
	m.name = name
	m.role = role == "lock" and "lock" or "helper"
	m.app = app ~= false
	-- a crew member is never a customer
	local cust = DR.customers[k]
	if cust then
		DR.customers[k] = nil
		W.Fire("DRIVE_REMOVED", cust, "crew")
	end
	W.Fire("DRIVE_CREW")
	DR.Changed()
	return m
end

-- Drops a member from my list (no messages; Drive_Team's RemoveCrew tells them).
function DR.DropCrewMember(k)
	local c = DR.char()
	for i, m in ipairs(c.crew) do
		if W.Key(m.name) == k then
			table.remove(c.crew, i)
			DR.peers[k] = nil
			W.Fire("DRIVE_CREW")
			DR.Changed()
			return true
		end
	end
	return false
end

-- "Add anyway": a helper without Wuber, trusted locally only (never a customer). role "L"
-- (or "lock"): a Warlock without Wuber who summons when the runner's button calls them.
function DR.AddPlainHelper(name, role)
	name = W.Clean(name, 48)
	if not W.Key(name) then return nil end
	local lock = role == "L" or role == "lock"
	local m = DR.SetCrewMember(name, lock and "lock" or "helper", false)
	if m and lock and DR.AddSummoner then DR.AddSummoner(name) end
	if m and DR.offers then
		local o = DR.offers[W.Key(name)]
		if o then o.state = "yes" end
	end
	-- the member windows learn it too (CRW carries plain helpers as P, plain summoners as S:
	-- never riders there)
	if m and DR.IsCaptain() and type(DR.SendCrew) == "function" then DR.SendCrew() end
	return m
end

function DR.AddPlainSummoner(name) return DR.AddPlainHelper(name, "L") end

-- Whether a crew member runs Wuber (a summoner without it is called in chat by the runner).
function DR.SummonerHasApp(k)
	if not k then return false end
	if k == me() then return true end
	local m = DR.CrewEntry(k)
	if m then return m.app ~= false end
	return DR.peers[k] ~= nil
end

---------------------------------------------------------------------------
-- The group
---------------------------------------------------------------------------

function DR.InRaid() return type(IsInRaid) == "function" and plain(IsInRaid()) == true end
function DR.InGroup() return W.InGroup() end

function DR.GroupSize()
	local n = type(GetNumGroupMembers) == "function" and tonumber(plain(GetNumGroupMembers())) or 0
	if not n or n < 1 then n = 1 end
	return n
end

-- Leading, or alone: this window is the one that invites.
function DR.IsLeader()
	if not W.InGroup() then return true end
	return type(UnitIsGroupLeader) == "function" and plain(UnitIsGroupLeader("player")) == true
end

-- Whether a group member (by key) leads the group.
function DR.IsLeaderKey(k)
	if not k then return false end
	if k == me() then return DR.IsLeader() end
	local unit = DR.units[k]
	if not unit or type(UnitIsGroupLeader) ~= "function" then return false end
	local ok, v = pcall(UnitIsGroupLeader, unit)
	return ok and plain(v) == true
end

-- Everyone else in the group: { unit, name, key }.
function DR.Roster()
	local out = {}
	local mine = me()
	local function add(unit)
		local name = W.UnitName(unit)
		local key = W.Key(name)
		if key and key ~= mine then
			local class
			if type(UnitClass) == "function" then
				local ok, _, file = pcall(UnitClass, unit)
				class = ok and str(file) or nil
			end
			out[#out + 1] = { unit = unit, name = name, key = key, class = class }
		end
	end
	if DR.InRaid() then
		for i = 1, DR.GroupSize() do add("raid" .. i) end
	elseif W.InGroup() then
		local n = type(GetNumSubgroupMembers) == "function" and tonumber(plain(GetNumSubgroupMembers())) or 0
		for i = 1, (n or 0) do add("party" .. i) end
	end
	return out
end

function DR.Visible(unit)
	if not unit or type(UnitIsVisible) ~= "function" then return false end
	local ok, v = pcall(UnitIsVisible, unit)
	return ok and plain(v) == true
end

-- The same map as us (Undercity is right under the Ruins of Lordaeron). Unknown: the same.
function DR.SameMap(unit)
	local CM = rawget(_G, "C_Map")
	if not unit or type(CM) ~= "table" or type(CM.GetBestMapForUnit) ~= "function" then return true end
	local ok1, a = pcall(CM.GetBestMapForUnit, "player")
	local ok2, b = pcall(CM.GetBestMapForUnit, unit)
	a, b = ok1 and num(a) or nil, ok2 and num(b) or nil
	if not a or not b then return true end
	return a == b
end

-- DR.SimHooks (SPEC5, the test addon's shard-free test mode only): a table the test addon may set; nil in
-- normal play. Check points: SimHooks.here(unit) -> true = that rider counts as arrived;
-- SimHooks.shards(name) -> a number used as the Soul Shard count (for summoning `name`, when
-- given: the test mode stands in only for riders who run it too; nil = the real count);
-- SimHooks.castLine(line, name), SimHooks.peers() -> { [key] = name } (Drive_Net: while set,
-- this driver is off the public network and seen only by those), SimHooks.groupChat() -> true
-- when everyone in the group runs the test mode (Drive_Button: raid lines).
function DR.Here(unit)
	local sim = DR.SimHooks
	if sim and sim.here and unit then
		local ok, v = pcall(sim.here, unit)
		if ok and v == true then return true end
	end
	return DR.Visible(unit) and DR.SameMap(unit)
end

function DR.Online(unit)
	if not unit or type(UnitIsConnected) ~= "function" then return true end
	local ok, v = pcall(UnitIsConnected, unit)
	if not ok then return true end
	return plain(v) ~= false
end

-- The class file of a group member ("WARLOCK"), or nil.
function DR.UnitClassKey(k)
	local unit = k and DR.units[k]
	if not unit or type(UnitClass) ~= "function" then return nil end
	local ok, _, file = pcall(UnitClass, unit)
	return ok and str(file) or nil
end

---------------------------------------------------------------------------
-- Soul Shards and the ritual
---------------------------------------------------------------------------

function DR.Shards(forName)
	local sim = DR.SimHooks
	if sim and sim.shards then
		local ok, n = pcall(sim.shards, forName)
		if ok and num(n) then return num(n) end
	end
	local count = (C_Item and C_Item.GetItemCount) or rawget(_G, "GetItemCount")
	if type(count) ~= "function" then return nil end
	local ok, n = pcall(count, DR.SHARD_ITEM)
	return ok and num(n) or nil
end

local function knownSpell(name)
	if type(name) ~= "string" or name == "" then return false end
	local info = C_Spell and C_Spell.GetSpellInfo
	if type(info) ~= "function" then return false end
	local ok, found = pcall(info, name)
	if not ok then return false end
	if issecretvalue then
		local okS, is = pcall(issecretvalue, found)
		if not okS or is == true then return true end
	end
	return found ~= nil
end

-- Spellbook just after login (LRN-08): the game may not have loaded it for a few seconds, and an
-- unread book answers "no" to everything. A "no" is only believed once the book proves readable
-- (a spell every Warlock has is known) or 10 s have passed since login; before that DR.Ritual gives
-- a third value, true: "not sure yet", and the callers say nothing about it.
local BOOK_WAIT, BOOK_PROBE = 10, 686 -- (686: Shadow Bolt, a Warlock's first spell)
local loginAt, bookSig

local function bookReadable()
	local known = rawget(_G, "IsPlayerSpell") or rawget(_G, "IsSpellKnown")
	if type(known) ~= "function" then return false end
	local ok, yes = pcall(known, BOOK_PROBE)
	return ok and plain(yes) == true
end

local function bookDoubt()
	return loginAt ~= nil and GetTime() - loginAt < BOOK_WAIT and not bookReadable()
end

-- The summoning spell's name for /cast, whether this Warlock knows it, and (when not) whether
-- that "no" is too early to trust.
function DR.Ritual()
	local byId
	local getName = C_Spell and C_Spell.GetSpellName
	if type(getName) == "function" then
		local ok, n = pcall(getName, DR.RITUAL_ID)
		byId = ok and str(n) or nil
	end
	local o = DR.opts()
	local names = { type(o.ritual) == "string" and o.ritual or "", DR.RITUAL_NAME, byId or "" }
	for _, n in ipairs(names) do
		if knownSpell(n) then return n, true end
	end
	local doubt = bookDoubt() or nil
	for _, n in ipairs(names) do
		if n ~= "" then return n, false, doubt end
	end
	return DR.RITUAL_NAME, false, doubt
end

-- Ask again (2 s, 5 s, the end of the window, and SPELLS_CHANGED); screens refresh only when the answer changed.
local function askBookAgain()
	local _, known, doubt = DR.Ritual()
	local sig = known and "yes" or (doubt and "wait" or "no")
	if sig ~= bookSig then
		bookSig = sig
		W.Fire("DRIVE")
	end
end

W.On("SPELLS_CHANGED", askBookAgain)

W.OnLogin(function()
	loginAt = GetTime()
	local _, known, doubt = DR.Ritual()
	bookSig = known and "yes" or (doubt and "wait" or "no")
	for _, s in ipairs({ 2, 5, BOOK_WAIT + 0.1 }) do W.After(s, askBookAgain) end
end)

-- Seconds until this Warlock can cast the ritual again (0: ready; the GCD does not count).
function DR.RitualCooldown()
	local spell = DR.Ritual()
	local start, duration
	if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
		local ok, info = pcall(C_Spell.GetSpellCooldown, spell)
		if ok and type(plain(info)) == "table" then start, duration = num(info.startTime), num(info.duration) end
	elseif type(rawget(_G, "GetSpellCooldown")) == "function" then
		local ok, s, d = pcall(GetSpellCooldown, spell)
		if ok then start, duration = num(s), num(d) end
	end
	if not (start and duration) or duration <= 1.5 or start <= 0 then return 0 end
	return math.max(0, start + duration - GetTime())
end

---------------------------------------------------------------------------
-- The destination
---------------------------------------------------------------------------

-- The driver's set place, else where the driver stands.
function DR.Dest()
	local d = DR.char().dest
	if type(d) == "string" and d ~= "" then return d end
	local ok, name = pcall(W.DestHere)
	name = ok and str(name) or nil
	return name or "our spot"
end

-- The default max group: a party for a small crew, a raid of 10 once me + crew >= 3, 20
-- with two or more stations.
function DR.MaxGroup()
	local m = tonumber(DR.opts().maxGroup) or 0
	if m >= 3 then return math.min(40, m) end
	if DR.MultiStation and DR.MultiStation() then return 20 end
	return (#DR.char().crew + 1 >= 3) and 10 or 5
end

---------------------------------------------------------------------------
-- The import of RitualRidesDB (once per account, and per character)
---------------------------------------------------------------------------

-- (2.3.2: not autoPublic: Ritual Rides' "on" was its default too; inviting public chat
-- buyers is turned on only through Wuber's warning)
local IMPORT_OPTS = {
	"keywords", "autoInvite", "oneAtATime", "autoAccept", "maxGroup", "inviteCap", "inviteTimeout", "autoTrade",
	"acceptUnder", "kickAfter", "watchPublic", "remindPay", "needShards", "lowShards", "adEvery",
	"adChannels", "watchChannels", "autoBlock", "tellBlocked", "ritual", "helpSeen", "whisperMode",
}
local TEMPLATE_KINDS = { advert = true, greet = true, price = true, offer = true, pay = true, thanks = true,
	tip = true, short = true, busy = true, refuse = true }

local function lineTime(line) return tonumber(tostring(line):match("^(%d+),")) or 0 end

-- Appends the lines of `from` to `into`, sorted by time, exact duplicates once.
local function mergeLines(into, from)
	if type(from) ~= "table" then return end
	local seen, all = {}, {}
	for _, line in ipairs(into) do
		if type(line) == "string" and not seen[line] then seen[line] = true all[#all + 1] = line end
	end
	for _, line in ipairs(from) do
		if type(line) == "string" and #line < 400 and not seen[line] then seen[line] = true all[#all + 1] = line end
	end
	for i, line in ipairs(all) do all[i] = { t = lineTime(line), i = i, line = line } end
	table.sort(all, function(a, b)
		if a.t ~= b.t then return a.t < b.t end
		return a.i < b.i
	end)
	for i = #into, 1, -1 do into[i] = nil end
	for i, e in ipairs(all) do into[i] = e.line end
end

local function mergeHours(into, from)
	if type(from) ~= "table" then return end
	for k, v in pairs(from) do
		v = tonumber(v)
		if type(k) == "string" and k:match("^%d%d%d%d%d%d%d%d%d%d$") and v and v == v and v >= 0 then
			into[k] = math.max(tonumber(into[k]) or 0, math.floor(v))
		end
	end
end

-- RR's blocked names into Wuber's list (entries already there are kept). `skip`: keys not to
-- take (blocked in RR at the import: unblocking one in Wuber since then stays done).
local function mergeBlocklist(rr, d, skip)
	if type(rr.blocklist) ~= "table" then return end
	for k, v in pairs(rr.blocklist) do
		local key = type(k) == "string" and W.Key(k)
		if key and d.blocklist[key] == nil and not (skip and skip[key]) then
			local reason, at = "", ""
			if type(v) == "table" then
				reason = type(v.reason) == "string" and v.reason or ""
				at = type(v.at) == "string" and v.at or ""
			elseif type(v) == "string" then
				reason = v
			end
			d.blocklist[key] = { reason = W.Clean(reason, 80), at = W.Clean(at, 20) }
		end
	end
end

local function mergeLog(rr, d)
	if type(rr.log) ~= "table" then return end
	local l = d.log
	mergeLines(l.rides, rr.log.rides)
	mergeLines(l.asks, rr.log.asks)
	for _, k in ipairs({ "open", "seen", "wreq", "wdec", "rivals" }) do mergeHours(l[k], rr.log[k]) end
end

local function rrStats(rr)
	local s = type(rr.stats) == "table" and rr.stats or {}
	local r, c = tonumber(s.rides), tonumber(s.copper)
	r = (r and r == r and r > 0) and math.floor(r) or 0
	c = (c and c == c and c > 0) and math.floor(c) or 0
	return r, c
end

local function importAccount(rr, d)
	local o = d.opts
	for _, k in ipairs(IMPORT_OPTS) do
		local v = rr[k]
		if v ~= nil then
			local ok, clean = pcall(DR.CleanOpt, k, v)
			if ok and clean ~= nil then o[k] = clean end
		end
	end
	if type(rr.templates) == "table" then
		for kind, text in pairs(rr.templates) do
			if TEMPLATE_KINDS[kind] and type(text) == "string" and text ~= "" then
				local t = W.Clean(text, DR.TEXT_MAX)
				local spam = DR.TemplateSpam or W.SentenceSpam
				local okS, why = pcall(spam, t)
				if okS and not why then d.templates[kind] = t end
			end
		end
	end
	mergeBlocklist(rr, d)
	mergeLog(rr, d)
	local r, c = rrStats(rr)
	d.stats.rides = d.stats.rides + r
	d.stats.copper = d.stats.copper + c
	local b = d.bell
	if type(rr.bell) == "string" then b.name = W.Clean(rr.bell, 48) end
	if type(rr.bellTeam) == "table" then
		for _, k in ipairs(rr.bellTeam) do
			k = type(k) == "string" and W.Key(k)
			if k and #b.team < 8 then b.team[#b.team + 1] = k end
		end
	end
	if type(rr.bellLead) == "string" then b.lead = W.Clean(rr.bellLead, 48) end
	if type(rr.bellService) == "string" then b.service = W.Clean(rr.bellService, 48) end
	local bt = d.button
	if type(rr.pos) == "table" then
		local p = {}
		for k, v in pairs(rr.pos) do
			if type(v) == "string" or type(v) == "number" then p[k] = v end
		end
		bt.pos = p
	end
	local sc = tonumber(rr.scale)
	if sc and sc == sc then bt.scale = math.max(0.5, math.min(3, sc)) end
	for _, k in ipairs({ "sizeSet", "locked", "shown" }) do
		if type(rr[k]) == "boolean" then bt[k] = rr[k] end
	end
	if type(rr.key) == "string" and rr.key ~= "" then bt.key = W.Clean(rr.key, 40) end
end

-- The team of RR: full names only (first-name entries skipped with one note).
local function rrTeam(rr)
	local names, skipped, seen = {}, 0, {}
	local function add(list)
		if type(list) ~= "table" then return 0 end
		local n = 0
		for _, name in ipairs(list) do
			local k = type(name) == "string" and W.Key(name)
			if k then
				n = n + 1
				if not k:find(" ", 1, true) then
					skipped = skipped + 1
				elseif not seen[k] then
					seen[k] = true
					names[#names + 1] = W.Clean(name, 48)
				end
			end
		end
		return n
	end
	if add(rr.team) == 0 then
		if add(rawget(_G, "RitualRides_Team")) == 0 then add(rawget(_G, "GigaLocksTeam")) end
	end
	return names, skipped
end

local function importChar(rr)
	local c = DR.char()
	local price = tonumber(rr.price)
	if price and price == price then
		c.price = math.max(W.MIN_PRICE or 5000, math.min(99999999, math.floor(price)))
	end
	-- (the old addon's default service name is never taken)
	if type(rr.service) == "string" and rr.service ~= "" and not rr.service:lower():find("ritual%s*rides") then
		local name, why = W.CleanService(rr.service, W.myName)
		if not why then c.service = name end
	end
	if type(rr.dest) == "string" then c.dest = W.Clean(rr.dest, 32) end
	if type(rr.destWords) == "string" then c.destWords = W.Clean(rr.destWords, 120) end
	if type(rr.caster) == "string" then
		-- RR: "" = whoever clicks; Wuber: "" = me, "-" = whoever clicks
		c.caster = rr.caster == "" and "-" or W.Clean(rr.caster, 48)
	end
	if type(rr.paused) == "boolean" then c.paused = rr.paused end

	c.rrChar = true
	-- a crew only for a Warlock: an alt of another class on the same account stays a rider
	if not DR.IsWarlock() then return end
	local names, skipped = rrTeam(rr)
	local mine = me()
	local crew = {}
	for _, name in ipairs(names) do
		if W.Key(name) ~= mine then crew[#crew + 1] = { name = name, role = "lock", app = true } end
	end
	if skipped > 0 then
		W.Print("Your old summoning addon's team had " .. skipped .. " first name" .. (skipped == 1 and "" or "s")
			.. " only: left out. Add them in Drive > Crew.")
	end
	if #crew > 0 then
		c.crew = crew
		-- the captain: the caster if set and in the team, else the first of me + team by key
		local all = { { key = mine, name = W.myName } }
		for _, m in ipairs(crew) do all[#all + 1] = { key = W.Key(m.name), name = m.name } end
		local cap
		local want = W.Key(c.caster)
		if want then
			for _, e in ipairs(all) do
				if e.key == want then cap = e end
			end
			if not cap and not want:find(" ", 1, true) then
				local found, many = nil, false
				for _, e in ipairs(all) do
					if e.key and e.key:match("^(%S+)") == want then
						if found then many = true end
						found = e
					end
				end
				if not many then cap = found end
			end
		end
		if not cap then
			table.sort(all, function(a, b) return (a.key or "") < (b.key or "") end)
			cap = all[1]
		end
		c.captain = (cap.key == mine) and "" or (cap.name or "")
		c.wizard = true
	end
	c.rrChar = true
end

-- What RR recorded between the import and its retirement (the retire card's "Later", or
-- logging in with RR still on): the first login after RR stops driving merges it once.
-- Blocked names new since the import, log lines (duplicates once, hours the max), and the
-- stats RR added since the import's snapshot.
local function mergeRetired(rr, d)
	local imp = d.imported
	mergeBlocklist(rr, d, type(imp.rrBlocked) == "table" and imp.rrBlocked or nil)
	mergeLog(rr, d)
	if type(imp.rrStats) == "table" then
		local r, c = rrStats(rr)
		local r0, c0 = tonumber(imp.rrStats.rides) or 0, tonumber(imp.rrStats.copper) or 0
		if r > r0 then d.stats.rides = d.stats.rides + (r - r0) end
		if c > c0 then d.stats.copper = d.stats.copper + (c - c0) end
	end
end

-- What the import saw of RR (for the merge at retirement).
local function importSnapshot(rr, imp)
	local r, c = rrStats(rr)
	imp.rrStats = { rides = r, copper = c }
	local keys = {}
	for k in pairs(type(rr.blocklist) == "table" and rr.blocklist or {}) do
		local key = type(k) == "string" and W.Key(k)
		if key then keys[key] = true end
	end
	imp.rrBlocked = keys
end

-- Once, when RR stops driving (the retire click, or the first login without it driving).
function DR.MergeRetired()
	local rr = rawget(_G, "RitualRidesDB")
	local d = DR.db or DR.InitDB()
	if type(rr) ~= "table" or not d or type(d.imported) ~= "table" or d.imported.retiredMerge then return false end
	local ok, err = pcall(mergeRetired, rr, d)
	if not ok then W.Error("import", err) end
	d.imported.retiredMerge = (type(time) == "function" and time()) or 0
	return true
end

-- The old addon's per-character settings (account-wide in its saved data), kept in WuberDB
-- whenever its data is loaded: a Warlock alt that logs in after
-- the old addon was switched off still gets them. 90 days.
local SEED_KEYS = { "price", "service", "dest", "destWords", "caster", "paused" }
local SEED_KEEP = 90 * 86400

local function seedOf(rr)
	local seed = {}
	for _, k in ipairs(SEED_KEYS) do
		local v = rr[k]
		if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then seed[k] = v end
	end
	local names = rrTeam(rr)
	seed.team = names
	seed.at = (type(time) == "function" and time()) or 0
	return seed
end

local function freshSeed(d)
	local imp = type(d.imported) == "table" and d.imported or nil
	local seed = imp and imp.charSeed
	if type(seed) ~= "table" then return nil end
	local t = (type(time) == "function" and time()) or 0
	if tonumber(seed.at) and t - seed.at > SEED_KEEP then return nil end
	return seed
end

-- One-time import of RitualRidesDB (or, once the old addon is switched off, of the settings
-- seed kept from it). true when anything came over.
function DR.ImportRR()
	local rr = rawget(_G, "RitualRidesDB")
	local d = DR.db or DR.InitDB()
	if not d then return false end
	if type(rr) ~= "table" then
		-- the old addon is off: its seed for a character that never imported
		local seed = freshSeed(d)
		if not seed or DR.char().rrChar == true then return false end
		local ok, err = pcall(importChar, seed)
		if not ok then W.Error("import", err) end
		DR.char().rrChar = true
		W.Fire("DRIVE_CREW")
		DR.Changed()
		return true
	end
	local did = false
	if d.imported == nil then
		local ok, err = pcall(importAccount, rr, d)
		if not ok then W.Error("import", err) end
		local rrv = rawget(_G, "RitualRides")
		local from = type(rrv) == "table" and type(rrv.VERSION) == "string" and rrv.VERSION or "1.4.1"
		d.imported = { at = (type(time) == "function" and time()) or 0, from = W.Clean(from, 12) }
		pcall(importSnapshot, rr, d.imported)
		-- imported with RR already retired: nothing more can come later
		if DR.Lock() ~= "rr" then d.imported.retiredMerge = d.imported.at end
		did = true
	elseif DR.Lock() ~= "rr" and DR.MergeRetired() then
		did = true
	end
	if type(d.imported) == "table" then
		local okS, seed = pcall(seedOf, rr)
		if okS and type(seed) == "table" then d.imported.charSeed = seed end
	end
	if DR.char().rrChar ~= true then
		local ok, err = pcall(importChar, rr)
		if not ok then
			W.Error("import", err)
			DR.char().rrChar = true
		end
		did = true
	end
	if did then
		W.Fire("DRIVE_CREW")
		DR.Changed()
	end
	return did
end

---------------------------------------------------------------------------
-- The queue snapshot (a /reload mid-ride, solo)
---------------------------------------------------------------------------

local SNAP = { "key", "name", "state", "source", "order", "paid", "price", "tries", "caster", "cashier",
	"greeted", "thanked", "reminded", "walked", "wuberRide", "wuberBuyer", "wuberLabel", "wuberPrice", "dest", "station", "wuberVer", "prepaid",
	"voucher", "cover", "fullFare", "paidAt", -- (round 9) a redeemed raincheck: paid on arrival after a /reload
	-- (2.4 fix round, HUNT-120) an automatic invite stays one (Oops is still offered, an Oops clicked is still owed);
	-- (HUNT-126) "gone": a paid rider who has left the group (his row stays for the thanks). Old saved data has none of them.
	"auto", "autoMsg", "oops", "gone",
	-- (r54 FAB-11) the place the rider booked: without it a restored rider took whatever place the window read first
	-- after the login (the continent, "Kalimdor") and was dropped as "moved" once the real place came back
	"forPlace" }

local function snapshot()
	if not DR.on then return end
	local list = {}
	for _, c in pairs(DR.customers) do
		-- (AU24-36) a rider still waiting in the queue (not invited yet) is saved too
		if DR.Rank and (DR.Rank(c.state) >= DR.Rank("joined") or c.state == "queued") then
			local s = {}
			for _, k in ipairs(SNAP) do
				local v = c[k]
				if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then s[k] = v end
			end
			list[#list + 1] = s
		end
	end
	-- (r28 AUD-49b) the friends in the group who came with a rider ("came with Dan?"), in order:
	-- read back from the roster they would look like riders once that rider has arrived
	local with = {}
	for k, c in pairs(DR.customers) do
		if c.cameWith and c.state == "lead" and DR.units[k] then
			with[#with + 1] = { key = k, name = c.name, cameWith = c.cameWith, order = c.order }
		end
	end
	table.sort(with, function(x, y) return (tonumber(x.order) or 0) < (tonumber(y.order) or 0) end)
	-- 2.3.0: the rides paid by trade (a raincheck may still be asked for)
	local paid = DR.RecentPaidSave and DR.RecentPaidSave() or nil
	DR.char().queue = (#list > 0 or paid) and { at = (type(time) == "function" and time()) or 0, list = list, paid = paid,
		with = #with > 0 and with or nil } or nil
end
DR.Snapshot = snapshot

local function restore()
	local c = DR.char()
	local q = c.queue
	c.queue = nil
	if type(q) == "table" and DR.RecentPaidLoad then DR.RecentPaidLoad(q.paid) end
	if type(q) ~= "table" or type(q.list) ~= "table" then return end
	local t = (type(time) == "function" and time()) or 0
	if not tonumber(q.at) or t - q.at > 600 or t < q.at then return end
	-- (r28 AUD-49) the saved riders are back on the list before the roster is read: read
	-- first, the second of them looked like a friend who "came with" the first (DROP to the crew)
	local units = {}
	for _, m in ipairs(DR.Roster()) do units[m.key] = m.unit end
	DR.units = units
	local list = {} -- in the order they came (the saved list is in no order)
	for _, s in ipairs(q.list) do if type(s) == "table" then list[#list + 1] = s end end
	table.sort(list, function(x, y) return (tonumber(x.order) or 0) < (tonumber(y.order) or 0) end)
	for _, s in ipairs(list) do
		local k = type(s) == "table" and W.Key(s.key)
		-- (HUNT-126) a paid rider who had already left the group when the queue was saved comes back as the live
		-- list kept him (DR.SyncRoster leaves a "gone" row alone); anybody else must still be in the group
		local waiting = s.state == "queued" -- (AU24-36) not invited yet: not in the group, back as queued with a fresh time
		local here = k and (waiting or DR.units[k] or (s.state == "paid" and s.gone == true))
		if here and not DR.IsCrewKey(k) and DR.Rank and (waiting or DR.Rank(s.state) >= DR.Rank("joined")) and not (waiting and DR.units[k]) then
			local cust = DR.customers[k]
			if not cust and DR.Create then cust = DR.Create(s.name or k, waiting and "queued" or "joined", s.source or "group") end
			if cust then
				for _, key in ipairs(SNAP) do
					if key ~= "key" and key ~= "order" and s[key] ~= nil then cust[key] = s[key] end
				end
				if waiting then cust.state = "queued"
				elseif DR.Rank(cust.state) < DR.Rank("joined") then cust.state = "joined" end
				cust.cameWith, cust.helperOf = nil, nil
				cust.at = GetTime()
				if cust.state == "arrived" then cust.arrivedAt = GetTime() end
			end
		end
	end
	-- (r28 AUD-49b) the friends who came with a rider, still in the group, are "came with" rows
	-- again, as DR.SyncRoster makes them (only the leader decides; the crew is told, DROP).
	-- Old saved data has no such list.
	local open = DR.Selling and DR.Selling() and DR.Role() == "driver"
	if type(q.with) == "table" and open and DR.IsLeader() and DR.Create then
		for _, s in ipairs(q.with) do
			local k = type(s) == "table" and W.Key(s.key)
			local by = k and type(s.cameWith) == "string" and s.cameWith or nil
			local rider = by and DR.customers[W.Key(by)]
			-- (HUNT-126) the rider they came with may be a paid rider who has left: the question stays open
			if rider and (DR.units[rider.key] or rider.gone) and DR.units[k] and not DR.customers[k] and not DR.IsCrewKey(k)
				and not DR.ignored[k] and not (DR.NeverRider and DR.NeverRider(k)) then
				local cust = DR.Create(type(s.name) == "string" and s.name or k, "lead", "group")
				if cust then
					cust.cameWith, cust.helperOf, cust.heardBy, cust.msg = by, by, me(), nil
					if DR.Send then DR.Send("DROP", cust.name) end
				end
			end
		end
	end
	if DR.SyncRoster then DR.SyncRoster() end
	DR.Changed()
end
DR.RestoreQueue = restore

W.On("PLAYER_LOGOUT", function() snapshot() end)

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

DR.on = false

W.OnLogin(function()
	DR.InitDB()
	rrLock = rrDriving()
	DR.char()
	-- (the old addon's data, or the seed kept from it: read here, at login, never at load)
	if type(rawget(_G, "RitualRidesDB")) == "table" or freshSeed(DR.db) then DR.ImportRR() end
	DR.helpSeen = DR.opts().helpSeen == W.Build()
	if rrLock then return end -- an old Ritual Rides drives: nothing of the engine runs
	DR.on = true
	if DR.StartTeam then DR.StartTeam() end
	restore() -- (r28 AUD-49) before the roster is read, so the saved riders are riders again
	if DR.SyncRoster then DR.SyncRoster() end
	if W.InGroup() and DR.Hello then DR.Hello(true) end
	W.Every(1, function() if DR.Tick then DR.Tick() end end)
	DR.Changed()
end)
