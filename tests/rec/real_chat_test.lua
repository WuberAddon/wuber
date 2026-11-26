-- Conformance (the flight recorder, lane B2): the game's system lines (CHAT_MSG_SYSTEM) of a group and a
-- trade in the fake game against the real client (fact chat.system.lines; the test addon's "sys" lines,
-- 17-21 Nov 2026; counts over the four accounts). The invite lines belong to lane B1.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local L = dofile(T.dir .. "/rec/real_lib.lua")

local RIDER = "Wuber Rocks"
local SYS = L.set({ "CHAT_MSG_SYSTEM", "GROUP_ROSTER_UPDATE", "CANCEL_SUMMON" })

local function lines(rec)
	local out = {}
	for _, e in ipairs(rec.list) do
		if e[1] == "CHAT_MSG_SYSTEM" then out[#out + 1] = e[3] else out[#out + 1] = "<" .. e[1] .. ">" end
	end
	return table.concat(out, " | ")
end

local function world()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local f = T.driver(w, "Farra Way", { spot = "Orgrimmar" })
	local r = T.rider(w, RIDER)
	T.settle(w)
	return w, d, f, r
end

-- Recorded, verbatim (a party of three, Anita Lift leading, Wuber Rocks joins; 20 Nov 12:58:07):
--   Wuber Rocks sys Looting set to Group Loot.        then GROUP_ROSTER_UPDATE (same ms)
--   Farra Way   sys Wuber Rocks joins the party.      then GROUP_ROSTER_UPDATE (same ms)
-- and the leader of a group just made (20 Nov 01:23:53, P1 joining):
--   sys Looting set to Group Loot. / sys P1 joins the party. / GROUP_ROSTER_UPDATE (same ms)
-- ("Looting set to Group Loot." 49 times, "X joins the party." about 30.)
test("rec: real: joining a group: the loot line and 'X joins the party.' (chat.system.lines)", function()
	local w, d, f, r = world()
	local rd, rf = L.record(w, d, SYS), L.record(w, f, SYS)
	w:join(d.player, f.player)
	eq(lines(rd), "Looting set to Group Loot. | Farra Way joins the party. | <GROUP_ROSTER_UPDATE>", "the leader of a new group")
	eq(lines(rf), "Looting set to Group Loot. | <GROUP_ROSTER_UPDATE>", "the one who joins")
	local rr = L.record(w, r, SYS)
	local n = #rd.list
	w:join(d.player, r.player)
	eq(lines(rr), "Looting set to Group Loot. | <GROUP_ROSTER_UPDATE>", "the rider joins")
	eq(rd.names(n + 1):gsub("%(.-%)", ""), "CHAT_MSG_SYSTEM GROUP_ROSTER_UPDATE", "the leader: one line and the roster")
	eq(rd.list[n + 1][3], "Wuber Rocks joins the party.")
	T.clean(w)
end)

-- Recorded (20 Nov 13:58:43, Wuber Rocks leaves a party of four):
--   Farra Way / Hayley Cab / Anita Lift  sys Wuber Rocks leaves the party.  then GROUP_ROSTER_UPDATE (same ms)
--   Wuber Rocks  GROUP_ROSTER_UPDATE members=0;  +37 ms  sys You leave the group.  + CANCEL_SUMMON
-- and when the leader goes (19 Nov 10:05-10:06): "X leaves the party." and "Y is now the group leader."
-- 50 ms before or 100-150 ms after it (3 samples).
test("rec: real: leaving: 'You leave the group.' and 'X leaves the party.' (chat.system.lines)", function()
	local w, d, f, r = world()
	w:group({ T.ANITA, "Farra Way", RIDER })
	w:advance(1)
	local rd, rr = L.record(w, d, SYS), L.record(w, r, SYS)
	r.env.C_PartyInfo.LeaveParty()
	w:advance(1)
	eq(lines(rr), "<GROUP_ROSTER_UPDATE> | You leave the group. | <CANCEL_SUMMON>", "the one who leaves")
	eq(lines(rd), "Wuber Rocks leaves the party. | <GROUP_ROSTER_UPDATE>", "the others")
	T.clean(w)
end)

-- Recorded: "You have been removed from the group." 13 times (each with CANCEL_SUMMON), e.g. 21 Nov 00:07:54
-- (Farra Way, Hayley Cab, Anita Lift: "Wuber Rocks leaves the party." in the same 150 ms).
test("rec: real: removed: 'You have been removed from the group.' (chat.system.lines)", function()
	local w, d, f, r = world()
	w:group({ T.ANITA, "Farra Way", RIDER })
	w:advance(1)
	local rf, rr = L.record(w, f, SYS), L.record(w, r, SYS)
	w:uninvite(d, RIDER)
	w:advance(1)
	eq(lines(rr), "<GROUP_ROSTER_UPDATE> | You have been removed from the group. | <CANCEL_SUMMON>", "the one removed")
	eq(lines(rf), "Wuber Rocks leaves the party. | <GROUP_ROSTER_UPDATE>", "the others")
	T.clean(w)
end)

-- Recorded (20 Nov 01:23:56 and 13:02:21, a party of two): the one left behind gets
--   GROUP_ROSTER_UPDATE members=0;  +50-100 ms  sys Your group has been disbanded.  + CANCEL_SUMMON
-- and no "X leaves the party." line.
test("rec: real: a group of two falls apart: 'Your group has been disbanded.' (chat.system.lines)", function()
	local w, d, f, r = world()
	w:group({ T.ANITA, RIDER })
	w:advance(1)
	local rd = L.record(w, d, SYS)
	r.env.C_PartyInfo.LeaveParty()
	w:advance(1)
	eq(lines(rd), "<GROUP_ROSTER_UPDATE> | Your group has been disbanded. | <CANCEL_SUMMON>", "the one left behind")
	T.clean(w)
end)

test("rec: real: the leader leaves: 'Y is now the group leader.' (chat.system.lines)", function()
	local w, d, f, r = world()
	w:group({ T.ANITA, "Farra Way", RIDER })
	w:advance(1)
	local rr = L.record(w, r, SYS)
	d.env.C_PartyInfo.LeaveParty()
	w:advance(1)
	eq(lines(rr), "Anita Lift leaves the party. | <GROUP_ROSTER_UPDATE> | Farra Way is now the group leader.", "the others")
	T.clean(w)
end)

-- Recorded: "You have requested to trade with X." 4 times, on the side that opened the trade, 0.17-0.36 s
-- before its TRADE_SHOW, e.g. 21 Nov 00:06:57.638 Anita Lift (TRADE_SHOW 00:06:57.838).
test("rec: real: opening a trade: 'You have requested to trade with X.' (chat.system.lines)", function()
	local w, d, f, r = world()
	local rd, rr = L.record(w, d, L.set({ "CHAT_MSG_SYSTEM", "TRADE_SHOW" })), L.record(w, r, L.set({ "CHAT_MSG_SYSTEM", "TRADE_SHOW" }))
	ok(w:openTrade(d, r), "the trade opens")
	eq(lines(rd), "You have requested to trade with Wuber Rocks. | <TRADE_SHOW>", "the side that opened it")
	eq(lines(rr), "<TRADE_SHOW>", "the other side: no line")
	w:tradeCancel(d)
	T.clean(w)
end)

test("rec: real: the system lines' global strings (chat.system.lines)", function()
	local w, d, f, r = world()
	local env = r.env
	eq(env.JOINED_PARTY, "%s joins the party.")
	eq(env.LEFT_PARTY, "%s leaves the party.")
	eq(env.ERR_UNINVITE_YOU, "You have been removed from the group.")
	eq(env.ERR_LEFT_GROUP_YOU, "You leave the group.")
	eq(env.ERR_GROUP_DISBANDED, "Your group has been disbanded.")
	eq(env.ERR_NEW_LEADER_S, "%s is now the group leader.")
	eq(env.ERR_INITIATE_TRADE_S, "You have requested to trade with %s.")
	T.clean(w)
end)
