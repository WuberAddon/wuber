-- Wuber Lab (developer only, never ship): what gets logged.
--   * game events: invites, group, summons, trades, money, whispers, system lines, blocked
--     actions, Wuber's addon messages in and out
--   * Wuber: every internal event (W.Fire), the rider's ride stage by stage with durations,
--     errors (W.Error), W.Try results, requests, payments, the window, tooltips, the map
--   * Ritual Rides: the Wuber provider calls, WuberAPI calls, its log calls, customer states
--   * client probes the code review asked for (raw inviter names, UnitName returns, protected
--     calls and the trade state, the summon box after accepting, channel joins, the font)
-- Every hook calls the original and returns its results unchanged.

local _, L = ...

local show, str, num, call, plain = L.show, L.str, L.num, L.call, L.plain
if type(L.KINDS) == "table" and not L.KINDS.advert then L.KINDS.advert = "chat advert (posted, heard, confirmed)" end

-- Fake drivers (Tools.lua) all have the surname "Labfake": recognised by key even after a /reload.
function L.IsFakeKey(key)
	return type(key) == "string" and key:match(" labfake$") ~= nil
end

local function lower(s) return type(s) == "string" and s:lower() or "" end

local function short(text, max)
	text = show(text)
	max = max or 160
	if #text > max then return text:sub(1, max - 3) .. "..." end
	return text
end

---------------------------------------------------------------------------
-- Game events
---------------------------------------------------------------------------

local tradeOpen, tradeClosedAt = false, -100
local lastMoney

local function unitFullName(unit)
	local W = L.W()
	if W and type(W.UnitName) == "function" then
		local n = call(W.UnitName, unit)
		if str(n) then return n end
	end
	local a, b = call(UnitName, unit)
	a, b = str(a), str(b)
	if a and b then return a .. " " .. b end
	return a
end

function L.TradeState()
	local shown = false
	if type(TradeFrame) == "table" and type(TradeFrame.IsShown) == "function" then
		shown = plain(call(TradeFrame.IsShown, TradeFrame)) == true
	end
	return ("trade=%s my=%s their=%s"):format(shown and "shown" or "hidden", show(call(GetPlayerTradeMoney)), show(call(GetTargetTradeMoney)))
end

-- PARTY_INVITE_REQUEST: the raw inviter argument exactly (probe 1), then whether Wuber took it.
L.On("PARTY_INVITE_REQUEST", function(inviter, ...)
	local raw = L.IsSecret(inviter) and "<secret>" or ("'" .. tostring(inviter) .. "'")
	L.Log("ev", "PARTY_INVITE_REQUEST inviter=" .. raw .. " type=" .. type(inviter) .. " extra=" .. select("#", ...))
	L.Signal("invite_req", inviter)
	L.After(0.6, function()
		local W = L.W()
		local r = W and W.ride
		local inGroup = W and type(W.InGroup) == "function" and call(W.InGroup) or false
		L.Log("probe", ("invite 0.6s later: wuberAutoAccepted=%s inGroup=%s rideState=%s autoAcceptSetting=%s blocked=%s"):format(
			show(r and r.autoAccepted), show(inGroup), show(r and r.state), show(W and W.db and W.db.autoAccept),
			show(W and type(W.IsBlocked) == "function" and call(W.IsBlocked, "accept"))))
	end)
end)

local lastRoster
L.On("GROUP_ROSTER_UPDATE", function()
	local names = {}
	for i = 1, 4 do
		local n = unitFullName("party" .. i)
		if n then names[#names + 1] = n end
	end
	if #names == 0 then
		for i = 1, 40 do
			local n = unitFullName("raid" .. i)
			if n then names[#names + 1] = n end
		end
	end
	local sig = table.concat(names, ",")
	if sig == lastRoster then return end
	local wasIn = lastRoster ~= nil and lastRoster ~= ""
	lastRoster = sig
	L.Log("ev", "GROUP_ROSTER_UPDATE members=" .. #names .. " " .. sig)
	if #names == 0 and wasIn then L.Signal("left_group") end
	if #names > 0 then L.Signal("in_group", names) end
end)

L.On("CONFIRM_SUMMON", function()
	local S = type(C_SummonInfo) == "table" and C_SummonInfo or {}
	local who = call(S.GetSummonConfirmSummoner) or call(GetSummonConfirmSummoner)
	local area = call(S.GetSummonConfirmAreaName) or call(GetSummonConfirmAreaName)
	L.Log("ev", "CONFIRM_SUMMON summoner=" .. show(who) .. " area=" .. show(area))
	L.Signal("summon_popup")
end)

L.On("CANCEL_SUMMON", function() L.Log("ev", "CANCEL_SUMMON") end)

L.On("TRADE_SHOW", function()
	tradeOpen = true
	lastMoney = num(call(GetMoney)) or lastMoney
	L.Log("ev", "TRADE_SHOW with=" .. show(unitFullName("npc")) .. " " .. L.TradeState())
	L.Signal("trade_show")
end)

L.On("TRADE_CLOSED", function()
	if tradeOpen then tradeClosedAt = L.Now() end
	tradeOpen = false
	L.Log("ev", "TRADE_CLOSED")
end)

L.On("TRADE_REQUEST_CANCEL", function()
	tradeOpen = false
	L.Log("ev", "TRADE_REQUEST_CANCEL")
end)

L.On("TRADE_ACCEPT_UPDATE", function(me, them)
	L.Log("ev", "TRADE_ACCEPT_UPDATE me=" .. show(me) .. " them=" .. show(them) .. " " .. L.TradeState())
end)

L.On("TRADE_MONEY_CHANGED", function()
	L.Log("ev", "TRADE_MONEY_CHANGED " .. L.TradeState())
end)

L.On("PLAYER_MONEY", function()
	local m = num(call(GetMoney))
	if not m then
		L.Log("ev", "PLAYER_MONEY (unreadable)")
		return
	end
	local delta = lastMoney and (m - lastMoney) or 0
	lastMoney = m
	L.Log("ev", ("PLAYER_MONEY %+d now=%d%s"):format(delta, m, tradeOpen and " (trade open)" or ""))
	if delta > 0 and (tradeOpen or L.Now() - tradeClosedAt < 3) then L.Signal("cashier", delta) end
	if delta < 0 and (tradeOpen or L.Now() - tradeClosedAt < 3) then L.Signal("paid_trade", -delta) end
end)

local function isCast(name)
	local k = L.Key(name)
	return k ~= nil and L.CAST[k] ~= nil
end

local function interesting(text, who)
	local t = lower(str(text))
	return isCast(who) or t:find("summon", 1, true) ~= nil or t:find("wtb", 1, true) ~= nil
end

L.On("CHAT_MSG_WHISPER", function(text, sender)
	if L.IsSecret(text) or L.IsSecret(sender) then
		L.Log("whsp", "< (secret whisper)")
		return
	end
	if not interesting(text, sender) then return end
	L.Log("whsp", "< " .. show(sender) .. ": " .. short(text, 200))
	L.Signal("whisper_in", text)
	if lower(text):find("wtb summon", 1, true) then L.Signal("whisper_wtb_in", text) end
end)

L.On("CHAT_MSG_WHISPER_INFORM", function(text, target)
	if L.IsSecret(text) or L.IsSecret(target) then
		L.Log("whsp", "> (secret whisper)")
		return
	end
	if not interesting(text, target) then return end
	L.Log("whsp", "> " .. show(target) .. ": " .. short(text, 200))
	if lower(text):find("wtb summon", 1, true) then L.Signal("whisper_wtb", text) end
end)

local SYSTEM_WORDS = { "player named", "not found", "cannot find", "invite", "group", "party", "summon", "trade", "channel" }
L.On("CHAT_MSG_SYSTEM", function(text)
	local t = lower(str(text))
	if t == "" then return end
	if L.PlanNotFound and L.PlanNotFound(text) then return end -- our own plan sync to a teammate who is offline
	local W = L.W()
	if W and type(W.SystemFilter) == "function" and call(W.SystemFilter, nil, nil, text) == true then return end -- Wuber's own whisper to someone offline
	for _, w in ipairs(SYSTEM_WORDS) do
		if t:find(w, 1, true) then
			L.Log("sys", short(text, 200))
			return
		end
	end
end)

local function blocked(event)
	return function(addon, func)
		L.Log("block", event .. " addon=" .. show(addon) .. " func=" .. show(func) .. " combat=" .. show(L.InCombat()))
		L.Signal("blocked", func)
	end
end
L.On("ADDON_ACTION_BLOCKED", blocked("ADDON_ACTION_BLOCKED"))
L.On("ADDON_ACTION_FORBIDDEN", blocked("ADDON_ACTION_FORBIDDEN"))

L.On("ZONE_CHANGED_NEW_AREA", function()
	L.Log("ev", "ZONE_CHANGED_NEW_AREA zone=" .. show(call(GetZoneText)) .. " sub=" .. show(call(GetSubZoneText)))
end)

L.On("PLAYER_REGEN_DISABLED", function() L.Log("ev", "combat on") end)
L.On("PLAYER_REGEN_ENABLED", function() L.Log("ev", "combat off") end)

-- Probe 2: UnitName on other players: both returns, once per new player, 20 a session.
local namesSeen, nameProbes = {}, 0
local function probeUnit(unit)
	if nameProbes >= 20 or type(unit) ~= "string" then return end
	if plain(call(UnitIsPlayer, unit)) ~= true then return end
	local ok, a, b = pcall(UnitName, unit)
	if not ok then return end
	if plain(call(UnitIsUnit, unit, "player")) == true then return end
	local sa, sb = show(a), show(b)
	local k = sa .. "\1" .. sb
	if namesSeen[k] then return end
	namesSeen[k] = true
	nameProbes = nameProbes + 1
	L.Log("probe", ("UnitName(%s) -> 1st='%s' 2nd='%s' (%d/20)"):format(unit, sa, sb, nameProbes))
end
L.On("PLAYER_TARGET_CHANGED", function() probeUnit("target") end)
L.On("UPDATE_MOUSEOVER_UNIT", function() probeUnit("mouseover") end)
L.On("NAME_PLATE_UNIT_ADDED", function(unit) probeUnit(plain(unit)) end)

-- Probe 6: channels this character has, logged when the count changes.
local lastChannels
local function noteChannels(why)
	local n = L.ChannelCount()
	local W = L.W()
	local idx = W and type(W.ChannelIndex) == "function" and call(W.ChannelIndex) or nil
	local sig = show(n) .. "/" .. show(idx)
	if sig == lastChannels then return end
	lastChannels = sig
	L.Log("probe", ("channels=%s wuberIndex=%s (%s)"):format(show(n), show(idx), why))
end
L.On("CHANNEL_UI_UPDATE", function() noteChannels("CHANNEL_UI_UPDATE") end)

-- Wuber's addon messages, in.
local lastIn = {}
local scanTruncated

-- Cut-off text in Wuber's window: every 4 s while it is open, any shown FontString the client
-- says is truncated ("..."), logged once per text (FontString:IsTruncated, when the client has it).
local truncSeen, truncCount = {}, 0
scanTruncated = function()
	local win = _G.WuberFrame
	if not win or truncCount >= 60 then return end
	local okShown, shown = pcall(win.IsVisible, win)
	if not okShown or shown ~= true then return end
	local visited = 0
	local function walk(f, depth)
		if depth > 14 or visited > 4000 then return end
		visited = visited + 1
		local okv, vis = pcall(f.IsVisible, f)
		if not okv or vis ~= true then return end
		local okr, regions = pcall(function() return { f:GetRegions() } end)
		if okr then
			for _, r in ipairs(regions) do
				if type(r) == "table" and type(r.IsTruncated) == "function" then
					local okT, cut = pcall(r.IsTruncated, r)
					local okS, rv = pcall(r.IsVisible, r)
					if okT and cut == true and okS and rv == true then
						local okx, txt = pcall(r.GetText, r)
						txt = okx and type(txt) == "string" and txt or "?"
						if not truncSeen[txt] then
							truncSeen[txt] = true
							truncCount = truncCount + 1
							local okw, w = pcall(r.GetWidth, r)
							L.Log("truncated", short(txt, 140) .. " (width " .. tostring(okw and math.floor((tonumber(w) or 0) + 0.5) or "?") .. ")")
							if L.Signal then pcall(L.Signal, "text_truncated", txt) end
						end
					end
				end
			end
		end
		local okc, kids = pcall(function() return { f:GetChildren() } end)
		if okc then for _, k in ipairs(kids) do walk(k, depth + 1) end end
	end
	walk(win, 0)
end

L.On("CHAT_MSG_ADDON", function(prefix, text, chan, sender, _, _, localID, chanName)
	local W = L.W()
	local want = (W and W.PREFIX) or "WUBER"
	if str(prefix) ~= want then return end
	text, chan, sender = str(text) or show(text), show(chan), show(sender)
	-- over the Wuber community's channel (Wuber 1.2+), guarded
	local viaComm = chan == "CHANNEL" and W and type(W.IsCommunityChannel) == "function"
		and call(W.IsCommunityChannel, localID, chanName) == true
	if viaComm then
		L.Log("comm", ("< %s from %s via community: %s"):format(text:match("^(%a)~") or "?", sender, short(text, 140)))
		L.Signal("comm_in", text:match("^(%a)~"))
	end
	local kind = text:match("^(%a)~") or "?"
	if kind == "D" then
		-- the same beacon again (a driver standing still) is counted, not logged
		local prev = lastIn[sender]
		if prev and prev.text == text then
			prev.n = prev.n + 1
			return
		end
		lastIn[sender] = { text = text, n = 0 }
	end
	L.Log("msg<", ("%s %s<%s %s"):format(kind, chan == "WHISPER" and "W" or "C", sender, short(text, 170)))
	L.Signal("msg_in", kind)
end)

-- ...and out: every SendAddonMessage with Wuber's prefix (a post-hook; never changes it).
local function outgoing(prefix, text, chan, target)
	if str(prefix) == (L.PLAN_PREFIX or "WLAB") and L.RunSpent then L.RunSpent() end -- (the run's share of the allowance)
	local W = L.W()
	local want = (W and W.PREFIX) or "WUBER"
	if str(prefix) ~= want then return end
	text = str(text) or show(text)
	local kind = text:match("^(%a)~") or "?"
	L.Log("msg>", ("%s %s>%s %s"):format(kind, show(chan) == "WHISPER" and "W" or "C", show(target), short(text, 170)))
	local tk = L.Key(str(target))
	if tk and L.IsFakeKey(tk) then L.Log("err", "FAKE LEAK: an addon message went to fake driver " .. show(target)) end
	if kind == "Q" then L.Signal("ping_out") end
	if kind == "D" then
		local f = {}
		for field in (text .. "~"):gmatch("(.-)~") do f[#f + 1] = field end
		L.Signal("beacon_sent", { state = f[9], price = f[7] })
	end
end
if type(C_ChatInfo) == "table" then L.Hook(C_ChatInfo, "SendAddonMessage", outgoing) end
if type(SendAddonMessage) == "function" and not (type(C_ChatInfo) == "table" and C_ChatInfo.SendAddonMessage == SendAddonMessage) then
	L.Hook("SendAddonMessage", outgoing)
end

-- Probe 3: protected calls (whoever makes them) and the trade state just after.
local function probeCall(name, withTrade)
	return function(...)
		local args = {}
		for i = 1, math.min(3, select("#", ...)) do args[#args + 1] = show((select(i, ...))) end
		L.Log("probe", name .. "(" .. table.concat(args, ",") .. ") called combat=" .. show(L.InCombat())
			.. (withTrade and (" " .. L.TradeState()) or ""))
	end
end
for _, n in ipairs({ "AcceptGroup", "LeaveParty", "InviteUnit", "ConfirmSummon", "JoinTemporaryChannel", "JoinChannelByName" }) do
	if type(_G[n]) == "function" then L.Hook(n, probeCall(n)) end
end
for _, n in ipairs({ "SetTradeMoney", "AcceptTrade" }) do
	if type(_G[n]) == "function" then L.Hook(n, probeCall(n, true)) end
end
if type(C_PartyInfo) == "table" then
	for _, n in ipairs({ "LeaveParty", "InviteUnit", "ConfirmLeaveParty" }) do
		if type(C_PartyInfo[n]) == "function" then L.Hook(C_PartyInfo, n, probeCall("C_PartyInfo." .. n)) end
	end
end
if type(C_SummonInfo) == "table" and type(C_SummonInfo.ConfirmSummon) == "function" then
	L.Hook(C_SummonInfo, "ConfirmSummon", probeCall("C_SummonInfo.ConfirmSummon"))
end

---------------------------------------------------------------------------
-- Wuber: internal events and the rider's ride
---------------------------------------------------------------------------

local RIDE_FLAGS = { "acceptedAt", "position", "autoAccepted", "payClicked", "autoLeft", "rated", "stars", "paid", "reason",
	"summonAccepted", "inviter", "waitingOut", "summonUp", "doneByTimeout" }
local FLAG_SIGNAL = { acceptedAt = "accept_msg", position = "ride_position", autoAccepted = "auto_accept", payClicked = "pay_clicked",
	autoLeft = "auto_left", rated = "rated" }

local rides = {}     -- [rideId] = { start, at, state, flags, busy, combat, fake }
L.rides = rides
L.bookCtx = nil      -- set just before W.RequestRide runs: { key, combat, state, at }

local function onRide(r)
	if type(r) ~= "table" then
		L.Log("ride", "-;cleared")
		return
	end
	local id = str(r.id) or "?"
	local t = L.Epoch()
	local st = rides[id]
	if not st then
		st = { start = t, at = t, flags = {} }
		rides[id] = st
		local ctx = L.bookCtx
		if ctx and ctx.key == r.driverKey and L.Now() - (ctx.at or -100) < 2 then
			st.combat, st.busy = ctx.combat, ctx.state == "busy"
		end
		st.fake = L.IsFakeKey(r.driverKey)
	end
	local state = str(r.state) or "?"
	if state ~= st.state then
		local prev = st.state
		local dt, tot = t - st.at, t - st.start
		st.state, st.at = state, t
		L.Log("ride", ("%s;%s;from=%s;dt=%.1f;tot=%.1f;drv=%s;dest=%s;price=%s;fake=%s%s"):format(id, state, prev or "-", dt, tot,
			show(r.driver), show(r.dest), show(r.price), st.fake and "yes" or "no", r.reason and (";reason=" .. show(r.reason)) or ""))
		local info = { r = r, prev = prev, dt = dt, fake = st.fake, combat = st.combat, busy = st.busy }
		L.Signal("ride_" .. state, info)
		if state == "requesting" then
			if st.combat then L.Signal("combat_request", info) end
		elseif state == "cancelled" and (prev == "requesting" or prev == nil) then
			L.Signal("cancel_early", info)
		elseif state == "done" and (r.payClicked or r.paid) then
			L.Signal("pay_done", info)
			local paid, price = num(r.paid), num(r.price)
			if paid and price and math.abs(paid - price) < 1 then L.Signal("pay_exact", info) end
		elseif (state == "declined" or state == "failed" or state == "timeout") and not st.fake then
			local W = L.W()
			if W and type(W.drivers) == "table" and r.driverKey and W.drivers[r.driverKey] == nil then
				L.Log("ridef", id .. ";driverGone=true")
				L.Signal("driver_offline", info)
			end
		end
	end
	for _, f in ipairs(RIDE_FLAGS) do
		local v = r[f]
		if type(v) == "table" then v = "{table}" end
		if v ~= nil and v ~= st.flags[f] then
			st.flags[f] = v
			L.Log("ridef", ("%s;%s=%s%s"):format(id, f, show(v), f == "position" and (";eta=" .. show(r.eta)) or ""))
			if FLAG_SIGNAL[f] and v ~= false then L.Signal(FLAG_SIGNAL[f], { r = r, value = v, fake = st.fake, busy = st.busy }) end
			if f == "position" and st.busy then L.Signal("busy_queue", { r = r, value = v, fake = st.fake }) end
		end
	end
end
L.OnRide = onRide

local lastDrivers, lastDriversAt, spamSeen = nil, -100, {}
local function onDrivers(W)
	local keys, n = {}, 0
	for k, d in pairs(W.drivers or {}) do
		n = n + 1
		keys[#keys + 1] = tostring(k)
		if type(d) == "table" and d.serviceRefused and not spamSeen[k] then
			spamSeen[k] = true
			L.Log("fire", "spam filter: " .. show(k) .. " shown as '" .. show(d.service) .. "'")
			L.Signal("spam_filtered", k)
		end
	end
	table.sort(keys)
	local sig = table.concat(keys, ",")
	if sig ~= lastDrivers or L.Now() - lastDriversAt > 300 then
		lastDrivers, lastDriversAt = sig, L.Now()
		L.Log("fire", "DRIVERS n=" .. n .. " " .. short(sig, 200))
	end
	if n > 0 then L.Signal("drivers_seen", n) end
end

local lastRequests
local function onFire(name, ...)
	local W = L.W()
	if not W then return end
	name = tostring(name)
	if L.RunFire then L.RunFire(name, ...) end -- (the test run's judges: "wuber:<name>")
	if L.TrailFire then L.TrailFire(name, ...) end -- (the usage trail: settings, page changes; Trail.lua)
	if name == "RIDE" then
		onRide((...))
	elseif name == "DRIVERS" then
		onDrivers(W)
	elseif name == "REQUESTS" then
		local n = type(W.incoming) == "table" and #W.incoming or 0
		if n ~= lastRequests then
			lastRequests = n
			L.Log("fire", "REQUESTS n=" .. n)
		end
	elseif name == "SETTINGS" then
		local key = ...
		local v = W.db and key and W.db[key]
		L.Log("fire", "SETTINGS " .. show(key) .. "=" .. (type(v) == "table" and "{table}" or show(v)))
		L.Signal("setting", key)
		if key == "timeValue" or key == "scale" then L.Signal("slider", key) end
		if key == "hidden" and type(W.db.hidden) == "table" and next(W.db.hidden) ~= nil then L.Signal("hidden", key) end
	elseif name == "MILESTONE" then
		local main, ids = ...
		L.Log("fire", "MILESTONE main=" .. show(main) .. " ids=" .. (type(ids) == "table" and table.concat(ids, ",") or show(ids)))
		L.Signal("milestone", main)
	elseif name == "FAV_ONLINE" or name == "WATCH_HIT" then
		local d, count = ...
		L.Log("fire", name .. " driver=" .. show(type(d) == "table" and d.name or d) .. " count=" .. show(count))
		L.Signal(name == "FAV_ONLINE" and "fav_toast" or "watch_toast", d)
	elseif name == "PROVIDER" then
		local p = ...
		L.Log("fire", "PROVIDER " .. show(type(p) == "table" and p.name or p))
		if type(p) == "table" then
			L.WrapProvider(p)
			L.Signal("provider", p.name)
		end
	elseif name == "BLOCKED" then
		local cap, func = ...
		L.Log("block", "W BLOCKED cap=" .. show(cap) .. " func=" .. show(func))
	elseif name == "ADVERT" then
		-- adverts in public chat: ours posted (channel, text), "[Wuber]" lines heard (who,
		-- where, text), and a heard sender confirmed by his own D
		local what, a1, a2, a3 = ...
		if what == "posted" then
			L.Log("advert", "posted in " .. show(a1) .. ": " .. short(a2, 200))
			L.Signal("advert_posted", a1)
		elseif what == "heard" then
			L.Log("advert", "heard from " .. show(a1) .. " in " .. show(a2) .. ": " .. short(a3, 200))
			L.Signal("advert_heard", a1)
		elseif what == "confirmed" then
			L.Log("advert", "confirmed " .. show(a1) .. " (answered our Q with his own D)")
			L.Signal("advert_confirmed", a1)
		else
			L.Log("advert", show(what) .. " " .. show(a1))
		end
	else
		local args = {}
		for i = 1, math.min(3, select("#", ...)) do
			local v = (select(i, ...))
			args[#args + 1] = type(v) == "table" and (v.name and show(v.name) or "{table}") or show(v)
		end
		L.Log("fire", name .. " " .. table.concat(args, " "))
		if name == "RATING" then L.Signal("rating_in", ...) end
	end
end

---------------------------------------------------------------------------
-- Ritual Rides' provider (wrapped where Wuber keeps it) and WuberAPI
---------------------------------------------------------------------------

local drvRides = {} -- driver side: [rideId] = { start, at }
local function drvStep(id, step, extra)
	id = str(id) or "?"
	local t = L.Epoch()
	local d = drvRides[id]
	if not d then
		d = { start = t, at = t }
		drvRides[id] = d
	end
	L.Log("drv", ("%s;%s;dt=%.1f;tot=%.1f%s"):format(id, step, t - d.at, t - d.start, extra and (";" .. extra) or ""))
	d.at = t
end

local wrappedProviders = setmetatable({}, { __mode = "k" })
local lastBeaconSig, lastBeaconPrice
function L.WrapProvider(p)
	if type(p) ~= "table" or wrappedProviders[p] then return end
	wrappedProviders[p] = true
	L.Wrap(p, "onRequest", function(ride)
		if type(ride) ~= "table" then return end
		L.Log("prov", ("onRequest id=%s buyer=%s dest=%s price=%s tier=%s rides=%s"):format(show(ride.id), show(ride.buyer),
			show(ride.dest), show(ride.price), show(ride.tier), show(ride.rides)))
		drvStep(ride.id, "request", "buyer=" .. show(ride.buyer) .. ";dest=" .. show(ride.dest) .. ";price=" .. show(ride.price))
		L.Signal("prov_request", ride)
	end)
	L.Wrap(p, "onCancel", function(id, buyer)
		L.Log("prov", "onCancel id=" .. show(id) .. " buyer=" .. show(buyer))
		drvStep(id, "cancelled", "buyer=" .. show(buyer))
		L.Signal("prov_cancel", id)
	end)
	L.Wrap(p, "onRating", function(id, buyer, stars)
		L.Log("prov", "onRating id=" .. show(id) .. " buyer=" .. show(buyer) .. " stars=" .. show(stars))
		drvStep(id, "rated", "stars=" .. show(stars))
		L.Signal("prov_rating", stars)
	end)
	L.Wrap(p, "beacon", nil, function(_, b)
		local sig = "off"
		if type(b) == "table" then
			sig = table.concat({ show(b.dest), show(b.price), show(b.state), show(b.team), show(b.seats), show(b.queue) }, "/")
		end
		if sig == lastBeaconSig then return end
		lastBeaconSig = sig
		L.Log("prov", "beacon " .. sig)
		if type(b) == "table" then
			if b.state == "open" then L.Signal("beacon_open") end
			if b.state == "busy" then L.Signal("beacon_busy") end
			if b.state == "paused" then L.Signal("beacon_paused") end
			local price = num(b.price)
			if price and lastBeaconPrice and price ~= lastBeaconPrice then L.Signal("beacon_price", price) end
			lastBeaconPrice = price or lastBeaconPrice
		end
	end)
end

local function wrapAPI(api)
	if type(api) ~= "table" then return end
	L.Wrap(api, "SetDriver", function(p)
		L.Log("api", "SetDriver " .. show(type(p) == "table" and p.name or p))
		if type(p) == "table" then L.WrapProvider(p) end
	end)
	L.Wrap(api, "Accept", function(id, buyer, eta, price)
		L.Log("api", ("Accept id=%s buyer=%s eta=%s price=%s"):format(show(id), show(buyer), show(eta), show(price)))
		drvStep(id, "accepted", "eta=" .. show(eta) .. ";price=" .. show(price))
		L.Signal("api_accept", id)
	end)
	L.Wrap(api, "Decline", function(id, buyer, reason)
		L.Log("api", ("Decline id=%s buyer=%s reason=%s"):format(show(id), show(buyer), show(reason)))
		drvStep(id, "declined", "reason=" .. show(reason))
		L.Signal("api_decline", reason)
		if reason == "closed" then L.Signal("api_decline_closed") end
	end)
	L.Wrap(api, "Status", function(id, buyer, stage)
		L.Log("api", ("Status id=%s buyer=%s stage=%s"):format(show(id), show(buyer), show(stage)))
		drvStep(id, "stage:" .. show(stage))
		L.Signal("stage_" .. show(stage), id)
	end)
	L.Wrap(api, "Queue", function(id, buyer, position, eta)
		L.Log("api", ("Queue id=%s buyer=%s position=%s eta=%s"):format(show(id), show(buyer), show(position), show(eta)))
		drvStep(id, "queue", "position=" .. show(position) .. ";eta=" .. show(eta))
		L.Signal("api_queue", position)
	end)
	L.Wrap(api, "Beacon", function() L.Log("api", "Beacon") end)
end

---------------------------------------------------------------------------
-- Wuber's own functions
---------------------------------------------------------------------------

local tipsSeen, tipCount, tipLast = {}, 0, {}
local function tipTitle(frame)
	local tip = type(frame) == "table" and frame.wuberTip
	if type(tip) ~= "table" then return nil end
	local title = tip.title
	if type(title) == "function" then title = call(title, frame) end
	return str(title) or "?"
end

local function onTip(frame)
	local title = tipTitle(frame)
	if not title then return end
	local t = L.Now()
	if t - (tipLast[title] or -100) < 10 then return end
	tipLast[title] = t
	if not tipsSeen[title] then
		tipsSeen[title] = true
		tipCount = tipCount + 1
	end
	L.Log("ui", "tooltip '" .. short(title, 60) .. "' (" .. tipCount .. " different)")
	L.Signal("tip", tipCount)
end

local function wrapUI(W)
	local UI = W.UI
	if type(UI) ~= "table" then return end
	L.Wrap(UI, "Toggle", nil, function()
		local shown = type(UI.IsShown) == "function" and call(UI.IsShown) == true
		L.Log("ui", "window " .. (shown and "open" or "closed"))
		if shown then L.Signal("app_open") end
	end)
	L.Wrap(UI, "Show", function(screen, arg)
		L.Log("ui", "Show " .. show(screen) .. " " .. show(type(arg) == "table" and arg.name or arg))
		if screen == "confirm" then L.Signal("confirm_shown", arg) end
	end)
	L.Wrap(UI, "SelectTab", function(name)
		L.Log("ui", "tab " .. show(name))
		if name == "Trips" then L.Signal("trips_tab") end
	end)
	L.Wrap(UI, "Toast", function(text, kind) L.Log("ui", "toast [" .. show(kind) .. "] " .. short(text, 120)) end)
	L.Wrap(UI, "Celebrate", function(main, ids)
		L.Log("ui", "milestone pop " .. show(main))
		L.Signal("milestone_pop", main)
	end)
	L.Wrap(UI, "OpenSettings", function() L.Log("ui", "Settings opened") end)
end

local function wrapWuber(W)
	L.Wrap(W, "Fire", onFire)
	L.Wrap(W, "Error", function(where, err) L.Log("werr", show(where) .. ": " .. short(err, 220)) end)
	-- the community transport's notes (found / not found, its channel, the first send's
	-- result, switched off, invites): Wuber keeps them out of chat
	if type(W.Debug) == "function" then
		L.Wrap(W, "Debug", function(kind, text)
			if kind ~= "community" then return end
			L.Log("comm", short(text, 220))
			local t = str(text) or ""
			if t:find("^found") then L.Signal("comm_found") end
			if t:find("^switched off") then L.Signal("comm_off") end
		end)
	end
	L.Wrap(W, "Try", nil, function(a, okv, result)
		L.Log("try", ("cap=%s ok=%s result=%s combat=%s"):format(show(a[1]), show(okv), show(result), show(L.InCombat())))
		if okv and a[1] == "accept" then L.Signal("auto_accept_try") end
		if okv and a[1] == "leave" then L.Signal("auto_left") end
	end)
	L.Wrap(W, "SelfTest", nil, function(_, list)
		if L.inOwnSelfTest then return end
		L.StoreSelfTest(list, "Check my game")
		L.Signal("selftest_ui")
	end)
	L.Wrap(W, "RequestRide", function(key)
		local d = W.drivers and (W.drivers[key] or (type(W.Key) == "function" and W.drivers[call(W.Key, key) or ""]))
		L.bookCtx = { key = d and d.key or key, combat = L.InCombat(), state = d and d.state, at = L.Now() }
	end, function(a, ride, why)
		L.Log("ui", ("RequestRide %s -> %s%s combat=%s"):format(show(a[1]), ride and "ride" or "refused", why and (" " .. show(why)) or "",
			show(L.bookCtx and L.bookCtx.combat)))
	end)
	L.Wrap(W, "CancelRide", function()
		local r = W.ride
		L.Log("ui", "CancelRide state=" .. show(r and r.state))
	end)
	L.Wrap(W, "ClearRide", function() L.Log("ui", "ClearRide") end)
	L.Wrap(W, "Rate", nil, function(a, sent) L.Log("ui", "Rate " .. show(a[1]) .. " sent=" .. show(sent)) end)
	L.Wrap(W, "PayFare", nil, function(_, okv, line)
		L.Log("ui", "PayFare ok=" .. show(okv) .. " '" .. short(line, 100) .. "' " .. L.TradeState())
		if okv then L.Signal("pay_clicked") end
	end)
	L.Wrap(W, "AcceptInvite", nil, function(_, okv, line) L.Log("ui", "AcceptInvite ok=" .. show(okv) .. " " .. show(line)) end)
	-- probe 4: is the game's summon box still up a second after Wuber accepted the summon?
	L.Wrap(W, "AcceptSummon", nil, function(_, okv, line)
		L.Log("ui", "AcceptSummon ok=" .. show(okv) .. " " .. show(line))
		L.After(1, function()
			local visible = false
			if type(StaticPopup_FindVisible) == "function" then
				visible = call(StaticPopup_FindVisible, "CONFIRM_SUMMON") ~= nil
			end
			if not visible then
				for i = 1, 4 do
					local f = rawget(_G, "StaticPopup" .. i)
					if type(f) == "table" and f.which == "CONFIRM_SUMMON" and type(f.IsShown) == "function" and plain(call(f.IsShown, f)) == true then
						visible = true
					end
				end
			end
			L.Log("probe", "summon box 1s after AcceptSummon: visible=" .. show(visible))
		end)
	end)
	L.Wrap(W, "LeaveGroup", nil, function(_, okv) L.Log("ui", "LeaveGroup ok=" .. show(okv)) end)
	L.Wrap(W, "Ping", nil, function(_, okv, why) L.Log("ui", "Ping ok=" .. show(okv) .. " " .. show(why)) end)
	L.Wrap(W, "HideDriver", nil, function(a)
		L.Log("ui", "HideDriver " .. show(a[1]) .. " on=" .. show(a[2]))
		if a[2] ~= false then L.Signal("hidden", a[1]) end
	end)
	L.Wrap(W, "ToggleFav", nil, function(a, on) L.Log("ui", "ToggleFav " .. show(a[1]) .. " -> " .. show(on)) end)
	-- probe 6: channel join attempts and results
	local lastCheck
	L.Wrap(W, "CheckChannel", nil, function(a, on)
		local tryJoin = a[1] == true
		if on ~= lastCheck or (tryJoin and not on) then
			lastCheck = on
			L.Log("probe", ("CheckChannel(%s) -> %s index=%s channels=%s fails=%s"):format(show(a[1]), show(on),
				show(type(W.ChannelIndex) == "function" and call(W.ChannelIndex)), show(L.ChannelCount()),
				show(W.net and W.net.joinFails)))
		end
	end)
	if type(W.Map) == "table" then
		L.Wrap(W.Map, "BookPlace", function(place)
			local ctrl = plain(call(IsControlKeyDown)) == true
			L.Log("ui", "map book " .. show(type(place) == "table" and place.name or place) .. (ctrl and " (Ctrl-click)" or " (Ride here button)"))
			if L.TrailNote then
				L.TrailNote(("click map place \"%s\" (%s) on map"):format(L.TrailClean and L.TrailClean(type(place) == "table" and place.name or place) or "?",
					ctrl and "Ctrl-click" or "Ride here"))
			end
			L.Signal(ctrl and "map_ctrl" or "map_button", place)
		end)
	end
	if type(W.Theme) == "table" then
		L.Wrap(W.Theme, "Tip", nil, function(a)
			local frame = a[1]
			if type(frame) ~= "table" or frame.wuberLabTip or type(frame.HookScript) ~= "function" then return end
			frame.wuberLabTip = true
			pcall(frame.HookScript, frame, "OnEnter", function(self) pcall(onTip, self) end)
		end)
	end
	if type(W.FX) == "table" then
		L.Wrap(W.FX, "Fullscreen", nil, function(a, h)
			L.Log("fx", "Fullscreen " .. show(a[1]) .. (h and " played" or " not played (fx off, combat or unknown)"))
			if h then L.Signal("fx_" .. show(a[1])) end
		end)
	end
	wrapUI(W)
	wrapAPI(rawget(_G, "WuberAPI"))
end

local function wrapRR(RR)
	for _, n in ipairs({ "LogRide", "LogAsk", "LogWuber" }) do
		L.Wrap(RR, n, function(...)
			local args = {}
			for i = 1, math.min(4, select("#", ...)) do args[#args + 1] = short((select(i, ...)), 60) end
			L.Log("rr", n .. " " .. table.concat(args, " "))
			if n == "LogRide" then L.Signal("rr_logride") end
		end)
	end
	L.Wrap(RR, "BellAlert", function(text)
		L.Log("rr", "bell rang: " .. short(text, 120) .. " (role " .. tostring(L.Role()) .. ")")
		-- only the bell's own window (Wuber Rocks, the rider) counts: a banner on a Warlock is a fallback
		if L.Role() == "rider" then L.Signal("bell_rang", text) end
	end)
	L.Wrap(RR, "Ring", function(text) L.Log("rr", "bell sent: " .. short(text, 120)) end)
	local lastRivals
	L.Wrap(RR, "LogRivals", function(n)
		if n == lastRivals then return end
		lastRivals = n
		L.Log("rr", "LogRivals " .. show(n))
	end)
	L.Wrap(RR, "Request", nil, function(a, c)
		L.Log("rr", ("Request %s source=%s msg='%s' -> %s"):format(show(a[1]), show(a[2]), short(a[3], 80),
			type(c) == "table" and ("customer " .. show(c.state)) or "nil"))
	end)
	local was = setmetatable({}, { __mode = "k" })
	L.Wrap(RR, "SetState", function(c) if type(c) == "table" then was[c] = c.state or false end end, function(a)
		local c = a[1]
		if type(c) ~= "table" then return end
		local before = was[c]
		was[c] = nil
		if before ~= false and before == c.state then return end
		L.Log("rr", ("customer %s %s>%s%s"):format(show(c.name), show(before or "-"), show(c.state),
			c.wuberRide and (" wuber=" .. show(c.wuberRide)) or ""))
	end)
	L.Wrap(RR, "Error", function(where, err) L.Log("werr", "RR " .. show(where) .. ": " .. short(err, 220)) end)
	L.Wrap(RR, "Print", function(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[#parts + 1] = show((select(i, ...))) end
		local said = table.concat(parts, " ")
		L.Log("rr", "says: " .. short(said, 200))
		if said:find("at least 50s", 1, true) then L.Signal("rr_lowfare") end
	end)
end

do
	local W = L.W()
	if W then wrapWuber(W) end
	local RR = L.RR()
	if RR then wrapRR(RR) end
end

---------------------------------------------------------------------------
-- After login: the provider, the minimap button, probes, frame rate and memory
---------------------------------------------------------------------------

-- Self-test results kept per character: { at, source, list = { { name, ok, detail } } }
function L.StoreSelfTest(list, source)
	local c = L.Char()
	if type(list) ~= "table" then
		L.Log("self", "[" .. tostring(source) .. "] no results")
		return
	end
	local copy, failed = {}, {}
	for _, item in ipairs(list) do
		if type(item) == "table" then
			copy[#copy + 1] = { name = show(item.name), ok = item.ok == true, detail = item.detail and show(item.detail) or nil }
			if item.ok ~= true then failed[#failed + 1] = show(item.name) .. (item.detail and (" (" .. show(item.detail) .. ")") or "") end
		end
	end
	if c then c.selftest = { at = L.Epoch(), source = source, list = copy } end
	L.Log("self", ("[%s] %d of %d passed%s"):format(tostring(source), #copy - #failed, #copy,
		#failed > 0 and ("; failed: " .. table.concat(failed, "; ")) or ""))
	if #failed == 0 and #copy > 0 then L.Signal("selftest_ok") end
end

function L.RunSelfTest(source)
	local W = L.W()
	if not W or type(W.SelfTest) ~= "function" then
		L.Log("self", "[" .. tostring(source) .. "] Wuber isn't loaded")
		return nil
	end
	L.inOwnSelfTest = true
	local ok, list = pcall(W.SelfTest)
	L.inOwnSelfTest = false
	if not ok then
		L.Log("self", "[" .. tostring(source) .. "] W.SelfTest raised: " .. show(list))
		return nil
	end
	L.StoreSelfTest(list, source)
	return list
end

---------------------------------------------------------------------------
-- The big button (WuberDriveButton): every click, what it held and what it noted
---------------------------------------------------------------------------
-- (the author 18 Nov: a raid-summon click "did nothing" and the log could not say whether the button
-- got the click at all.) PreClick (after Wuber's own, so the plan is the one this click runs):
-- the title, where the button is, the macro. PostClick: the marks Wuber applied. A click that
-- lands on the console's slot under the button (the button not over it) is logged as a miss.

if type(L.KINDS) == "table" and not L.KINDS.click then L.KINDS.click = "big button click (what it ran, what it noted)" end

local function markList(marks)
	local out = {}
	for _, m in ipairs(type(marks) == "table" and marks or {}) do
		if type(m) == "table" then
			local who = type(m.c) == "table" and str(m.c.name) or nil
			out[#out + 1] = show(m.kind) .. (who and (" " .. who) or "") .. (m.sim and " (pretend)" or "")
				.. (str(m.summoner) and (" by " .. m.summoner) or "")
		end
	end
	return #out > 0 and table.concat(out, ", ") or "none"
end

local function placeOf(f)
	if type(f) ~= "table" then return "?" end
	return show(call(f.GetFrameStrata, f)) .. "/" .. show(call(f.GetFrameLevel, f))
end

local function buttonWhere(b)
	local W = L.W()
	local B = W and W.Drive and W.Drive.Button
	local docked = type(B) == "table" and call(B.Docked) == true
	return (docked and "docked " or "floating ") .. placeOf(b) .. ", window " .. placeOf(rawget(_G, "WuberFrame"))
end

local clickMarks -- the marks of the click under way (PreClick -> PostClick)

local function onBigPre(self)
	local plan = type(self.plan) == "table" and self.plan or {}
	clickMarks = markList(plan.marks)
	local kind = str(call(self.GetAttribute, self, "type"))
	L.Log("click", ("big button: '%s' (%s) type=%s; %s"):format(short(plan.title, 60), short(plan.sub, 70), show(kind), buttonWhere(self)))
	local macro = str(call(self.GetAttribute, self, "macrotext"))
	if kind == "macro" then L.Log("click", "macro: " .. (macro and macro:gsub("\n", " ; ") or "(empty)")) end
end

local function onBigPost()
	L.Log("click", "noted: " .. (clickMarks or "none"))
	clickMarks = nil
end

local bigHooked
local function hookBigButton()
	if bigHooked then return true end
	if L.InCombat() then return false end -- (a secure button: never touched in combat)
	local b = rawget(_G, "WuberDriveButton")
	if type(b) ~= "table" or type(b.HookScript) ~= "function" then return false end
	local okPre = pcall(b.HookScript, b, "PreClick", function(self, _, down)
		if down then return end
		local ok, err = pcall(onBigPre, self)
		if not ok then L.Bug("big click", err) end
	end)
	local okPost = pcall(b.HookScript, b, "PostClick", function(_, _, down)
		if down then return end
		local ok, err = pcall(onBigPost)
		if not ok then L.Bug("big click", err) end
	end)
	bigHooked = okPre and okPost
	return bigHooked
end
L.HookBigButton = hookBigButton

-- the console's slot: under the docked button, so a click there is one the button never got
local slotHooked
local function hookSlot()
	if slotHooked then return true end
	local W = L.W()
	local D = W and W.Driver
	local slot = type(D) == "table" and type(D.ui) == "table" and type(D.ui.console) == "table" and D.ui.console.slot
	if type(slot) ~= "table" or type(slot.HookScript) ~= "function" then return false end
	slotHooked = pcall(slot.HookScript, slot, "OnMouseDown", function()
		local b = rawget(_G, "WuberDriveButton")
		L.Log("click", "MISSED: the click fell on the slot under the big button, not on the button (" .. buttonWhere(b) .. ", slot " .. placeOf(slot) .. ")")
		L.Signal("big_missed")
	end)
	return slotHooked
end
L.HookBigSlot = hookSlot

L.OnLogin(function()
	local tries = 0
	local t
	t = L.Every(2, function()
		tries = tries + 1
		local a, b = hookBigButton(), hookSlot()
		if (a and b) or tries > 1800 then
			if t and t.Cancel then pcall(t.Cancel, t) end
		end
	end)
end)

local function hookMinimap()
	local b = rawget(_G, "WuberMinimapButton")
	if type(b) ~= "table" or b.wuberLabHooked or type(b.HookScript) ~= "function" then return b ~= nil end
	b.wuberLabHooked = true
	pcall(b.HookScript, b, "OnClick", function(_, button)
		L.Log("ui", "minimap button " .. show(button))
		L.Signal("minimap", button)
	end)
	pcall(b.HookScript, b, "OnDragStop", function()
		L.Log("ui", "minimap button dragged")
		L.Signal("minimap_drag")
	end)
	return true
end

local function fontProbe()
	local W = L.W()
	local T = W and W.Theme
	if type(T) ~= "table" or type(T.FONTS) ~= "table" then return end
	local fs = L.frame:CreateFontString(nil, "OVERLAY")
	local okSet, ret = pcall(fs.SetFont, fs, T.FONTS.regular, 14, "")
	local path = okSet and call(fs.GetFont, fs) or nil
	L.Log("probe", ("font Poppins SetFont ok=%s returned=%s GetFont=%s T.poppins=%s"):format(show(okSet), show(ret), show(path), show(T.poppins)))
	pcall(fs.Hide, fs)
end

local function perf()
	local W = L.W()
	if not (W and type(W.UI) == "table" and type(W.UI.IsShown) == "function" and call(W.UI.IsShown) == true) then return end
	local fps = num(call(GetFramerate))
	local mem, labMem = nil, nil
	if not L.InCombat() then
		local A = type(C_AddOns) == "table" and C_AddOns or {}
		call(UpdateAddOnMemoryUsage or A.UpdateAddOnMemoryUsage)
		local get = GetAddOnMemoryUsage or A.GetAddOnMemoryUsage
		mem, labMem = num(call(get, "Wuber")), num(call(get, L.ADDON))
	end
	L.Log("perf", ("fps=%s wuberKB=%s labKB=%s"):format(fps and ("%.1f"):format(fps) or "?", mem and ("%.0f"):format(mem) or "?",
		labMem and ("%.0f"):format(labMem) or "?"))
end

L.OnLogin(function()
	local W = L.W()
	if W then
		if type(W.provider) == "table" then
			L.WrapProvider(W.provider)
			L.Log("fire", "provider at login: " .. show(W.provider.name))
			L.Signal("provider", W.provider.name)
		end
		-- probe 5: what the game refused before (kept per client build by W.Try)
		local bb = W.db and W.db.blockedBuild
		if type(bb) == "table" then
			for build, caps in pairs(bb) do
				if type(caps) == "table" then
					local list = {}
					for cap in pairs(caps) do list[#list + 1] = tostring(cap) end
					table.sort(list)
					L.Log("probe", "W.db.blockedBuild[" .. tostring(build) .. "] = " .. table.concat(list, ","))
				end
			end
		end
		L.After(8, function() L.RunSelfTest("login") end)
		L.After(3, fontProbe)
	else
		L.Log("login", "Wuber is not loaded: only game events are logged")
	end
	noteChannels("login")
	L.After(12, function() noteChannels("login+12s") end)
	-- the community at a glance once Wuber had its look (about 15 s after login)
	L.After(22, function()
		local W2 = L.W()
		if W2 and type(W2.CommunityStatus) == "function" then
			local c = type(W2.community) == "table" and W2.community or {}
			L.Log("comm", ("status: %s state=%s index=%s off=%s sent=%s heard=%s"):format(show(call(W2.CommunityStatus)),
				show(c.state), show(c.index), show(c.off), show(c.sent), show(c.heard)))
		end
	end)
	lastMoney = num(call(GetMoney))
	local tries = 0
	local t
	t = L.Every(5, function()
		tries = tries + 1
		if hookMinimap() or tries > 24 then
			if t and t.Cancel then pcall(t.Cancel, t) end
		end
	end)
	L.Every(60, perf)
	L.Every(4, scanTruncated)
end)
