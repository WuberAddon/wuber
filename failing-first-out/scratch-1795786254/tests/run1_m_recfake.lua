-- Run 1, group m: the fake game matches today's WuberRec recording (22 Nov 2026).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local L = dofile(T.dir .. "/rec/real_lib.lua")

test("run1 m: leaving a group fires GROUP_LEFT(1, <->), CHANNEL_UI_UPDATE, GROUP_ROSTER_UPDATE", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local r = T.rider(w, "Wuber Rocks")
	w:advance(2)
	w:group({ d.player.name, r.player.name })
	w:advance(1)
	local g = r.player.group
	ok(g, "in a group")
	local rec = L.record(w, r, L.set({ "GROUP_LEFT", "CHANNEL_UI_UPDATE", "GROUP_ROSTER_UPDATE" }))
	w:leave(r.player.name)
	eq(rec.names(), "GROUP_LEFT(1,<->) CHANNEL_UI_UPDATE GROUP_ROSTER_UPDATE", "exit events")
end)

test("run1 m: a trade opens with PLAYER_TRADE_MONEY, TRADE_SHOW, 3 more, then 14 TRADE_TARGET_ITEM_CHANGED", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local r = T.rider(w, "Wuber Rocks")
	w:advance(2)
	local rec = L.record(w, d, L.set({ "PLAYER_TRADE_MONEY", "TRADE_SHOW", "TRADE_TARGET_ITEM_CHANGED" }))
	ok(w:openTrade(r, d), "opens")
	w:advance(0.5)
	local want = { "PLAYER_TRADE_MONEY", "TRADE_SHOW", "PLAYER_TRADE_MONEY", "PLAYER_TRADE_MONEY", "PLAYER_TRADE_MONEY" }
	for i = 1, 7 do want[#want + 1] = "TRADE_TARGET_ITEM_CHANGED(" .. i .. ")" end
	for i = 1, 7 do want[#want + 1] = "TRADE_TARGET_ITEM_CHANGED(" .. i .. ")" end
	eq(rec.names(), table.concat(want, " "), "open events")
	local first, last = rec.list[5], rec.list[6]
	ok(last[2] - first[2] >= 0.1, "the item events come about 0.11 s later")
end)

test("run1 m: a cancelled trade ends with PLAYER_TRADE_MONEY and UI_INFO_MESSAGE ERR_TRADE_CANCELLED", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local r = T.rider(w, "Wuber Rocks")
	w:advance(2)
	ok(w:openTrade(r, d), "opens")
	w:advance(0.5)
	local rec = L.record(w, r, L.set({ "PLAYER_MONEY", "TRADE_REQUEST_CANCEL", "PLAYER_TRADE_MONEY", "TRADE_CLOSED", "UI_INFO_MESSAGE" }))
	w:tradeCancel(r)
	eq(rec.names(), "PLAYER_MONEY TRADE_REQUEST_CANCEL PLAYER_TRADE_MONEY TRADE_CLOSED TRADE_CLOSED UI_INFO_MESSAGE(250,Trade cancelled.)", "canceller")
end)

test("run1 m: w.noTaxiOpened opens the flight map without TAXIMAP_OPENED (the real client never fired it)", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	w:advance(4)
	local nodes = { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 } }
	local rec = L.record(w, r, L.set({ "TAXIMAP_OPENED", "TAXIMAP_CLOSED" }))
	w:openTaxiMap(r, nodes)
	eq(rec.names(), "TAXIMAP_OPENED(1)", "default: fires")
	w:closeTaxiMap(r)
	w.noTaxiOpened = true
	local n = #rec.list
	w:openTaxiMap(r, nodes)
	eq(#rec.list, n, "no TAXIMAP_OPENED")
	ok(r.env.TaxiFrame:IsShown(), "the map is up")
	eq(r.env.NumTaxiNodes(), 1, "nodes answer")
end)
