-- Wuber Lab (developer only, never ship): local test helpers. Nothing here sends anything:
-- no chat, no addon message. Fake drivers live only inside this window's own Wuber.
--
--   L.FakesOn() / L.FakesOff()  five simulated drivers fed straight into Wuber's own message
--                               handler (no network). Requests to them are answered here.
--   L.PlayAllFX()               every Wuber effect in turn, with its name on screen
--   L.FreshRider() / L.RestoreRider()   back up and clear the rider's trips and milestones
--   L.Mark(text)                a bookmark line in the timeline
--   L.RunChecks()               W.SelfTest again, results logged

local _, L = ...

local show, str, num, call, plain = L.show, L.str, L.num, L.call, L.plain

---------------------------------------------------------------------------
-- Fake drivers
---------------------------------------------------------------------------
-- Every fake is "<First> Labfake": L.IsFakeKey knows them even after a /reload.
-- script: what the fake "answers" to a request: { seconds after R, kind, fields... }
-- (A: price, eta; P: position, eta; N: reason). "$price" is the ride's price.

L.FAKES = {
	{ id = "cheap", name = "Cheap Labfake", dest = "Ratchet", price = 5000, service = "Lab Cheap Rides", state = "open", team = 3, seats = 5,
		badge = "bolt", queue = 0,
		script = { { 1.5, "A", "$price", 60 }, { 3, "P", 2, 60 }, { 9, "P", 1, 30 }, { 15, "N", "busy" } },
		does = "accepts, queue 2 then 1, then declines" },
	{ id = "mid", name = "Mid Labfake", dest = "Orgrimmar", price = 7500, service = "Lab Express", state = "open", team = 1, seats = 4,
		badge = "star", queue = 0, script = { { 2, "N", "closed" } }, does = "declines (closed)" },
	{ id = "busy", name = "Busy Labfake", dest = "Undercity", price = 10000, service = "Lab Busy Cabs", state = "busy", team = 2, seats = 2,
		badge = "flame", queue = 2,
		script = { { 1.5, "A", "$price", 180 }, { 2.5, "P", 3, 180 }, { 8, "P", 2, 120 }, { 14, "P", 1, 60 }, { 20, "N", "busy" } },
		does = "busy: accepts, queue 3, 2, 1, then declines" },
	{ id = "spam", name = "Spam Labfake", dest = "Booty Bay", price = 15000, service = "Cheap Gold Sale", state = "open", team = 3, seats = 6,
		badge = "moon", queue = 0, script = {}, does = "spammy name; never answers (timeout)" },
	{ id = "dear", name = "Dear Labfake", dest = "Gadgetzan", price = 25000, service = "Lab Luxury", state = "open", team = 2, seats = 3,
		badge = "crystal", queue = 0, script = { { 2, "N", "price" } }, does = "declines (price)" },
}
local FAKE_BY_KEY = {}
for _, f in ipairs(L.FAKES) do FAKE_BY_KEY[f.name:lower()] = f end

L.fakesOn = false
local fakeRides = {}   -- [rideId] = generation (a running script)
local generation = 0

local function W_() return L.W() end

-- Delivers a message to this window's Wuber only (its own event handler), as if heard.
local function deliver(sender, chan, text)
	local W = W_()
	local f = W and W.frame
	if type(f) ~= "table" or type(f.GetScript) ~= "function" then return false end
	local handler = call(f.GetScript, f, "OnEvent")
	if type(handler) ~= "function" then return false end
	local ok, err = pcall(handler, f, "CHAT_MSG_ADDON", W.PREFIX or "WUBER", text, chan, sender)
	if not ok then L.Bug("fake deliver", err) end
	return ok
end

local function encode(kind, ...)
	local W = W_()
	if not W or type(W.Encode) ~= "function" then return nil end
	return call(W.Encode, kind, ...)
end

local function beacon(f)
	local W = W_()
	local p = W and type(W.FindPlace) == "function" and call(W.FindPlace, f.dest) or nil
	local mapID = type(p) == "table" and num(p.mapID) or 1413
	local x = type(p) == "table" and num(p.x) or 0.5
	local y = type(p) == "table" and num(p.y) or 0.5
	local text = encode("D", f.dest, mapID, math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5), f.price, f.service, f.state,
		f.team, f.seats, "", "lab", f.badge, f.queue)
	if text then deliver(f.name, "CHANNEL", text) end
end

local function beaconAll()
	if not L.fakesOn then return end
	for _, f in ipairs(L.FAKES) do beacon(f) end
end

function L.FakesOn()
	local W = W_()
	if not W then
		L.Log("tool", "fake drivers: Wuber isn't loaded")
		return false
	end
	L.fakesOn = true
	beaconAll()
	L.Log("fake", "fake drivers ON (local only, never sent): " .. #L.FAKES .. " drivers")
	if not L.fakeTicker then
		L.fakeTicker = L.Every(50, beaconAll) -- before Wuber's 150 s expiry
	end
	return true
end

-- Removes fake drivers and everything Wuber remembered about them (favourites, hidden,
-- toast times, a saved ride with one).
function L.PurgeFakes(quiet)
	local W = W_()
	if not W then return 0 end
	local n = 0
	local function sweep(t, anywhere)
		if type(t) ~= "table" then return end
		local gone = {}
		for k in pairs(t) do
			if type(k) == "string" and ((anywhere and k:find("labfake", 1, true)) or L.IsFakeKey(k)) then gone[#gone + 1] = k end
		end
		for _, k in ipairs(gone) do
			t[k] = nil
			n = n + 1
		end
	end
	sweep(W.drivers)
	sweep(W.hiddenDrivers)
	if type(W.db) == "table" then
		sweep(W.db.favs)
		sweep(W.db.hidden)
		sweep(W.db.toastAt, true)
		local saved = W.db.ride
		if type(saved) == "table" and L.IsFakeKey(saved.driverKey) and not (W.ride and W.ride.driverKey == saved.driverKey) then
			W.db.ride = nil
			n = n + 1
		end
	end
	if not quiet and n > 0 then L.Log("fake", "purged " .. n .. " fake entries") end
	return n
end

function L.FakesOff()
	local W = W_()
	L.fakesOn = false
	if L.fakeTicker and L.fakeTicker.Cancel then pcall(L.fakeTicker.Cancel, L.fakeTicker) end
	L.fakeTicker = nil
	fakeRides = {}
	if not W then return false end
	if W.ride and L.IsFakeKey(W.ride.driverKey) then
		if type(W.ClearRide) == "function" then L.Safe("clear fake ride", W.ClearRide) end
	end
	for _, f in ipairs(L.FAKES) do
		local text = encode("X")
		if text then deliver(f.name, "CHANNEL", text) end
	end
	L.PurgeFakes(true)
	if type(W.Fire) == "function" then L.Safe("fire DRIVERS", W.Fire, "DRIVERS") end
	L.Log("fake", "fake drivers OFF and cleared")
	return true
end

-- A request (or cancel, rating) "sent" to a fake: answered here by its script.
local function fakeHeard(key, name, kind, ...)
	local f = FAKE_BY_KEY[key]
	local args = { ... }
	L.Log("fake", ("kept local: %s to %s %s"):format(show(kind), show(name), show(args[1])))
	if not f then return end
	local id = args[1]
	if kind == "C" then
		fakeRides[id] = nil
		return
	end
	if kind ~= "R" or not id or fakeRides[id] then return end
	generation = generation + 1
	local gen = generation
	fakeRides[id] = gen
	local price = num(args[3]) or f.price
	for _, step in ipairs(f.script) do
		L.After(step[1], function()
			local W = W_()
			if fakeRides[id] ~= gen or not W or not (W.ride and W.ride.id == id) then return end
			if type(W.RideActive) == "function" and not call(W.RideActive) then return end
			local fields = {}
			for i = 3, #step do fields[#fields + 1] = step[i] == "$price" and price or step[i] end
			local text = encode(step[2], id, unpack(fields))
			if text then
				L.Log("fake", ("%s answers %s %s"):format(f.name, step[2], table.concat(fields, " ")))
				deliver(f.name, "WHISPER", text)
			end
			if step[2] == "N" then fakeRides[id] = nil end
		end)
	end
end

-- Replaces tbl[name] with fn(orig, ...) (once). For the few places a fake must be stopped.
local function guard(tbl, name, fn)
	if type(tbl) ~= "table" or type(tbl[name]) ~= "function" then return false end
	L.wrapped[tbl] = L.wrapped[tbl] or {}
	if L.wrapped[tbl]["guard:" .. name] then return false end
	local orig = tbl[name]
	L.wrapped[tbl]["guard:" .. name] = orig
	tbl[name] = function(...) return fn(orig, ...) end
	return true
end
L.Guard = guard

local function keyOf(name)
	local W = W_()
	if W and type(W.Key) == "function" then return call(W.Key, name) end
	return L.Key(name)
end

local function rideIsFake()
	local W = W_()
	return W and type(W.ride) == "table" and L.IsFakeKey(W.ride.driverKey)
end

L.fakeAsk = nil -- { key, at }: the Request button was pressed for a fake (no whisper armed)

do
	local W = W_()
	if W then
		-- addon whispers to a fake never leave the window
		guard(W, "SendTo", function(orig, name, kind, ...)
			local key = keyOf(name)
			if key and L.IsFakeKey(key) then
				local ok, err = pcall(fakeHeard, key, name, kind, ...)
				if not ok then L.Bug("fake heard", err) end
				return true
			end
			return orig(name, kind, ...)
		end)
		-- no chat whisper to a fake: the secure Request/Cancel buttons get no macro
		guard(W, "RequestMacro", function(orig, key, ...)
			local k = keyOf(key)
			if k and L.IsFakeKey(k) then
				L.fakeAsk = { key = k, at = L.Now() }
				return nil
			end
			return orig(key, ...)
		end)
		guard(W, "RequestWhisper", function(orig, key, ...)
			local k = keyOf(key)
			if k and L.IsFakeKey(k) then return nil end
			return orig(key, ...)
		end)
		guard(W, "CancelMacro", function(orig, ...)
			if rideIsFake() then return nil end
			return orig(...)
		end)
		guard(W, "CancelWhisper", function(orig, ...)
			if rideIsFake() then return nil end
			return orig(...)
		end)
	end
end

-- A fake asked for from Wuber's own Request button: no macro was armed (so no whisper), so the
-- request goes out locally here, right after the button's own PostClick.
local function hookRequestButton()
	local b = rawget(_G, "WuberRequestButton")
	if type(b) ~= "table" or b.wuberLabHooked or L.InCombat() or type(b.HookScript) ~= "function" then return end
	b.wuberLabHooked = true
	pcall(b.HookScript, b, "PostClick", function(_, _, down)
		if down then return end
		local ask = L.fakeAsk
		if not ask or L.Now() - ask.at > 0.25 then return end
		L.fakeAsk = nil
		L.BookFake(ask.key)
	end)
end
L.HookRequestButton = hookRequestButton

-- Books a fake driver (no whisper, nothing sent).
function L.BookFake(keyOrId)
	local W = W_()
	if not W or type(W.RequestRide) ~= "function" then return false end
	local key = keyOrId
	for _, f in ipairs(L.FAKES) do
		if f.id == keyOrId then key = f.name:lower() end
	end
	if not L.IsFakeKey(key) then return false end
	local r, why = W.RequestRide(key)
	L.Log("fake", "booked " .. show(key) .. " -> " .. (r and "requesting" or ("refused " .. show(why))))
	if type(W.UI) == "table" then
		if r and type(W.UI.Toggle) == "function" then L.Safe("open", W.UI.Toggle, true) end
		if type(W.UI.Toast) == "function" then
			L.Safe("toast", W.UI.Toast, r and "Lab: fake request (local only, no whisper)" or ("Lab: refused (" .. show(why) .. ")"), "info")
		end
		if type(W.UI.Refresh) == "function" then L.Safe("refresh", W.UI.Refresh, true) end
	end
	return r ~= nil
end

L.signalFns[#L.signalFns + 1] = function(name)
	if name == "ping_out" and L.fakesOn then L.After(1, beaconAll) end
end

L.On("ADDON_LOADED", function(name)
	if plain(name) == L.ADDON then L.PurgeFakes() end -- leftovers of an earlier session
end)

L.OnLogin(function()
	L.Every(2, hookRequestButton)
end)

---------------------------------------------------------------------------
-- Play every effect
---------------------------------------------------------------------------

local stage, label
local made = {}  -- crown / badge frames made by an earlier run, shown again
local playing = false

local function stageFrame()
	if stage then return stage end
	stage = CreateFrame("Frame", "WuberLabFxStage", UIParent)
	stage:SetSize(260, 260)
	stage:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	pcall(stage.SetFrameStrata, stage, "HIGH")
	pcall(stage.EnableMouse, stage, false)
	label = stage:CreateFontString(nil, "OVERLAY")
	if not pcall(label.SetFont, label, "Fonts\\ARIALN.TTF", 22, "OUTLINE") then
		pcall(label.SetFontObject, label, GameFontNormalLarge or GameFontNormal)
	end
	label:SetPoint("BOTTOM", stage, "TOP", 0, 8)
	label:SetTextColor(0.976, 0.773, 0.243)
	label:SetText("")
	stage:Hide()
	return stage
end

local function effectList(FX)
	local list = {
		{ "portal_open", "screen" }, { "portal_loop", "screen" }, { "arrival", "screen" }, { "milestone", "stage" },
		{ "paid", "screen" }, { "coins", "screen" }, { "crown", "token" },
	}
	for _, id in ipairs(type(FX.BADGE_IDS) == "table" and FX.BADGE_IDS or {}) do list[#list + 1] = { "badge_" .. id, "token" } end
	return list
end

function L.PlayAllFX()
	local W = W_()
	local FX = W and W.FX
	if type(FX) ~= "table" then
		L.Log("fx", "W.FX isn't there")
		return false
	end
	if playing then return false end
	if L.InCombat() then
		L.Log("fx", "not in combat")
		return false
	end
	local list = effectList(FX)
	local s = stageFrame()
	s:Show()
	playing = true
	L.Log("fx", "playing " .. #list .. " effects, fx mode=" .. show(type(FX.Mode) == "function" and call(FX.Mode)))
	local i, current = 0, nil
	local function nextOne()
		if current and type(current) == "table" and type(current.Hide) == "function" and not current.Stop then pcall(current.Hide, current) end
		current = nil
		i = i + 1
		local e = list[i]
		if not e or L.InCombat() then
			label:SetText("")
			s:Hide()
			playing = false
			L.Log("fx", "done")
			L.Signal("fx_all")
			return
		end
		local name, how = e[1], e[2]
		label:SetText(("Effect %d/%d: %s"):format(i, #list, name))
		local h
		if how == "screen" then
			h = call(FX.Fullscreen, name, name == "portal_loop" and { loop = true, hold = 2 } or nil)
		elseif how == "stage" then
			h = call(FX.Play, name, s, { size = 220 })
		else
			h = made[name]
			if h then
				pcall(h.Show, h)
			else
				h = call(FX.Play, name, s, { size = name == "crown" and 128 or 96, seed = 1 })
				made[name] = h
			end
			current = h
		end
		L.Log("fx", ("%d/%d %s -> %s"):format(i, #list, name, h and "shown" or "nothing (fx off?)"))
		L.After(3, nextOne)
	end
	nextOne()
	return true
end

---------------------------------------------------------------------------
-- Fresh rider / Restore rider
---------------------------------------------------------------------------

local function deepCopy(v, seen)
	if type(v) ~= "table" then return v end
	seen = seen or {}
	if seen[v] then return seen[v] end
	local out = {}
	seen[v] = out
	for k, x in pairs(v) do out[deepCopy(k, seen)] = deepCopy(x, seen) end
	return out
end
L.DeepCopy = deepCopy

local PROGRESS = { "rides", "totals", "milestones", "tierSeen" }

local function refreshWuber(W)
	if type(W.Fire) == "function" then L.Safe("fire SETTINGS", W.Fire, "SETTINGS", "milestones") end
	if type(W.UI) == "table" and type(W.UI.Refresh) == "function" then L.Safe("refresh", W.UI.Refresh, true) end
end

-- Backs up the rider's trips, totals, milestones and level into WuberLabDB.riderBackup and
-- clears them, so "First Ride" can be tested. Refused while a backup exists or a ride runs.
function L.FreshRiderNow()
	local W = W_()
	if not W or type(W.db) ~= "table" then return false, "Wuber isn't loaded" end
	if not L.db then return false, "not ready" end
	if type(L.db.riderBackup) == "table" then return false, "a backup is already kept: Restore rider first" end
	if type(W.RideActive) == "function" and call(W.RideActive) then return false, "a ride is under way" end
	local b = { at = L.Epoch(), char = L.me, data = {} }
	for _, k in ipairs(PROGRESS) do b.data[k] = deepCopy(W.db[k]) end
	b.count = type(W.db.rides) == "table" and #W.db.rides or 0
	L.db.riderBackup = b
	W.db.rides, W.db.milestones, W.db.tierSeen, W.db.totals = {}, {}, nil, nil
	W.db.progressReady = true -- no silent backfill: the next ride earns First Ride for real
	if type(W.RebuildTotals) == "function" then L.Safe("rebuild totals", W.RebuildTotals) end
	refreshWuber(W)
	L.Log("tool", "fresh rider: backed up " .. b.count .. " trips and cleared trips, totals, milestones, level")
	return true
end

function L.RestoreRiderNow()
	local W = W_()
	if not W or type(W.db) ~= "table" then return false, "Wuber isn't loaded" end
	local b = L.db and L.db.riderBackup
	if type(b) ~= "table" or type(b.data) ~= "table" then return false, "no backup kept" end
	local tested = type(W.db.rides) == "table" and #W.db.rides or 0
	for _, k in ipairs(PROGRESS) do W.db[k] = deepCopy(b.data[k]) end
	if type(W.db.rides) ~= "table" then W.db.rides = {} end
	if type(W.db.milestones) ~= "table" then W.db.milestones = {} end
	if type(W.db.totals) ~= "table" and type(W.RebuildTotals) == "function" then L.Safe("rebuild totals", W.RebuildTotals) end
	L.db.riderBackup = nil
	refreshWuber(W)
	L.Log("tool", ("restore rider: %d trips back (%d test trips dropped)"):format(#W.db.rides, tested))
	return true
end

-- A yes/no box (the game's StaticPopup); without one, asks nothing and does it.
local function confirm(text, fn)
	if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then return fn() end
	StaticPopupDialogs.WUBERLAB_CONFIRM = {
		text = "%s", button1 = YES or "Yes", button2 = NO or "No", timeout = 0, whileDead = 1, hideOnEscape = 1,
		OnAccept = function() L.Safe("confirm", fn) end,
	}
	call(StaticPopup_Show, "WUBERLAB_CONFIRM", text)
end
L.Confirm = confirm

local function say(text)
	L.Log("tool", text)
	local f = DEFAULT_CHAT_FRAME
	if f and type(f.AddMessage) == "function" then pcall(f.AddMessage, f, "|cffcd7df5Wuber Lab|r: " .. text) end
end
L.Say = say

function L.FreshRider()
	confirm("Wuber Lab: back up and clear this rider's trips, milestones and level?", function()
		local ok, why = L.FreshRiderNow()
		say(ok and "Fresh rider ready. Restore rider puts the history back." or ("Fresh rider: " .. tostring(why)))
	end)
end

function L.RestoreRider()
	confirm("Wuber Lab: put the backed-up trips and milestones back? Test trips since then are dropped.", function()
		local ok, why = L.RestoreRiderNow()
		say(ok and "Rider history restored." or ("Restore rider: " .. tostring(why)))
	end)
end

---------------------------------------------------------------------------
-- Mark and Run checks
---------------------------------------------------------------------------

function L.Mark(text)
	text = str(text) or "mark"
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then text = "mark" end
	local c = L.Char()
	if c then c.marks = (tonumber(c.marks) or 0) + 1 end
	L.Log("mark", text)
	return true
end

function L.RunChecks()
	local list = L.RunSelfTest("Run checks")
	if type(list) ~= "table" then return false end
	local failed = 0
	for _, item in ipairs(list) do if type(item) == "table" and item.ok ~= true then failed = failed + 1 end end
	say(failed == 0 and ("all " .. #list .. " checks passed") or (failed .. " of " .. #list .. " checks failed (see the log)"))
	return true
end

---------------------------------------------------------------------------
-- /lab nettest: which chat channels carry addon messages between server nodes.
-- For 60 s, every 5 s, sends a tiny addon message (prefix WLABN) on every channel this
-- character has joined, by WHISPER to the other three test characters, and on PARTY when
-- grouped. Every window with the lab logs what it hears ("net heard ..."), so the merged log
-- shows exactly which routes reach which character. Addon messages are invisible in chat.
---------------------------------------------------------------------------
local NT_PREFIX = "WLABN"
local NT_TEAM = { "Anita Lift", "Farra Way", "Hayley Cab", "Wuber Rocks" }
if type(C_ChatInfo) == "table" and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
	pcall(C_ChatInfo.RegisterAddonMessagePrefix, NT_PREFIX)
end
local function ntSend(text, chan, target)
	local fn = type(C_ChatInfo) == "table" and C_ChatInfo.SendAddonMessage or SendAddonMessage
	if type(fn) ~= "function" then return false, "no SendAddonMessage" end
	local ok, res = pcall(fn, NT_PREFIX, text, chan, target)
	return ok and res ~= false, ok and tostring(res) or tostring(res)
end
local function ntChannels()
	local list = {}
	if type(GetChannelList) ~= "function" then return list end
	local t = { GetChannelList() }
	for i = 1, #t, 3 do
		local idx, name = tonumber(t[i]), t[i + 1]
		if idx and type(name) == "string" then list[#list + 1] = { idx = idx, name = name } end
	end
	return list
end
local ntRound = 0
function L.NetTest()
	local me = L.me or "?"
	local realm = (type(GetRealmName) == "function" and GetRealmName()) or "?"
	ntRound = 0
	L.Log("net", "nettest start on " .. me .. " (" .. realm .. ")")
	-- communities: does this client have the C_Club API, which clubs, and who's online in them
	local okC = pcall(function()
		if type(C_Club) ~= "table" then L.Log("net", "C_Club missing") return end
		local clubs = type(C_Club.GetSubscribedClubs) == "function" and C_Club.GetSubscribedClubs() or {}
		L.Log("net", "C_Club present, clubs=" .. #clubs)
		for _, c in ipairs(clubs) do
			local online, total, names = 0, 0, {}
			local ids = type(C_Club.GetClubMembers) == "function" and C_Club.GetClubMembers(c.clubId) or {}
			for _, mid in ipairs(ids) do
				total = total + 1
				local info = type(C_Club.GetMemberInfo) == "function" and C_Club.GetMemberInfo(c.clubId, mid) or nil
				if info and info.presence and info.presence ~= (Enum and Enum.ClubMemberPresence and Enum.ClubMemberPresence.Offline or 4) then
					online = online + 1
					if #names < 6 then names[#names + 1] = tostring(info.name) .. "@" .. tostring(info.presence) end
				end
			end
			L.Log("net", "club " .. tostring(c.name) .. " type=" .. tostring(c.clubType) .. " members=" .. total .. " online=" .. online .. " " .. table.concat(names, ","))
			local streams = type(C_Club.GetStreams) == "function" and C_Club.GetStreams(c.clubId) or {}
			for _, st in ipairs(streams) do
				local chName = type(Chat_GetCommunitiesChannelName) == "function" and Chat_GetCommunitiesChannelName(c.clubId, st.streamId) or "?"
				local idx = type(GetChannelName) == "function" and GetChannelName(chName) or "?"
				L.Log("net", "  stream " .. tostring(st.name) .. " channel=" .. tostring(chName) .. " index=" .. tostring(idx))
			end
		end
	end)
	if not okC then L.Log("net", "C_Club probe failed") end
	L.Say("network test: 60 s. Leave all four windows logged in, then /reload them all and tell the person running the test.")
	local t
	t = L.Every(5, function()
		ntRound = ntRound + 1
		for _, c in ipairs(ntChannels()) do
			local ok, res = ntSend(table.concat({ "C", c.name, ntRound, realm }, "~"), "CHANNEL", tostring(c.idx))
			if ntRound == 1 then L.Log("net", "send CHANNEL " .. c.idx .. " " .. c.name .. " ok=" .. tostring(ok) .. " " .. res) end
		end
		for _, n in ipairs(NT_TEAM) do
			if n:lower() ~= tostring(me):lower() then ntSend(table.concat({ "W", "whisper", ntRound, realm }, "~"), "WHISPER", n) end
		end
		if type(IsInGroup) == "function" and IsInGroup() then ntSend(table.concat({ "P", "party", ntRound, realm }, "~"), "PARTY") end
		if ntRound >= 12 and t and t.Cancel then
			pcall(t.Cancel, t)
			L.Log("net", "nettest done")
		end
	end)
end
local ntHeard = {}
L.On("CHAT_MSG_ADDON", function(prefix, text, chan, sender, _, _, _, chanIndex, chanName)
	if prefix ~= NT_PREFIX then return end
	text = type(text) == "string" and text or "?"
	local kind, route, round, realm = strsplit("~", text)
	local key = tostring(sender) .. "|" .. tostring(route) .. "|" .. tostring(chan)
	ntHeard[key] = (ntHeard[key] or 0) + 1
	if ntHeard[key] == 1 or ntHeard[key] % 6 == 0 then
		L.Log("net", "heard " .. tostring(route) .. " via " .. tostring(chan) .. " from " .. tostring(sender) .. " (" .. tostring(realm) .. ") x" .. ntHeard[key] .. " chanName=" .. tostring(chanName))
	end
end)
