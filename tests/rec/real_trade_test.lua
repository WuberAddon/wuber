-- Conformance (the flight recorder, lane B2): a trade's events in the fake game against the real client.
-- Evidence: the test addon's event lines (kind "ev"), 21 trade windows on the real client, 17-21 Nov 2026
-- (tests/fixtures/rec/lab-real-facts.lua, ids trade.*). The addon logs only TRADE_SHOW, TRADE_ACCEPT_UPDATE,
-- TRADE_MONEY_CHANGED, TRADE_CLOSED, TRADE_REQUEST_CANCEL and PLAYER_MONEY, so only those are compared.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local L = dofile(T.dir .. "/rec/real_lib.lua")

local LOGGED = L.set({ "TRADE_SHOW", "TRADE_ACCEPT_UPDATE", "TRADE_MONEY_CHANGED", "TRADE_CLOSED",
	"TRADE_REQUEST_CANCEL", "PLAYER_MONEY" })

-- the rider (Wuber Rocks) and the driver (Anita Lift) side by side in Orgrimmar, a trade open
local function setup(opts)
	local w = T.newWorld(opts)
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local r = T.rider(w, "Wuber Rocks")
	w:advance(2)
	local rd, rr = L.record(w, d, LOGGED), L.record(w, r, LOGGED)
	ok(w:openTrade(r, d), "the trade opens")
	return w, d, r, rd, rr
end

-- trade.close.double + trade.complete.order + trade.accept.update. The one trade both sides logged
-- (20 Nov 13:58, the driver accepted first, the rider last), verbatim:
--   13:58:24.421 Anita Lift  TRADE_MONEY_CHANGED trade=shown my=0 their=500
--   13:58:25.271 Anita Lift  TRADE_MONEY_CHANGED trade=shown my=0 their=5000
--   13:58:35.527 Anita Lift  TRADE_ACCEPT_UPDATE me=1 them=0 trade=shown my=0 their=5000
--   13:58:35.591 Wuber Rocks TRADE_ACCEPT_UPDATE me=0 them=1 trade=shown my=5000 their=0
--   13:58:39.511 Wuber Rocks TRADE_ACCEPT_UPDATE me=1 them=1 trade=shown my=5000 their=0
--   13:58:39.732 Wuber Rocks TRADE_CLOSED, TRADE_CLOSED (same millisecond)
--   13:58:39.780 Anita Lift  TRADE_CLOSED, TRADE_CLOSED (same millisecond)
--   13:58:39.985 Wuber Rocks PLAYER_MONEY -5000 now=4545   (+0.253 s)
--   13:58:39.999 Anita Lift  PLAYER_MONEY +5000 now=37559  (+0.219 s)
-- All 8 completed windows had the close twice and the purse 0.10-0.45 s after it.
test("rec: real: a completed trade: accept updates, TRADE_CLOSED twice, then the purse (trade.complete.order)", function()
	local w, d, r, rd, rr = setup()
	local dMoney, rMoney = d.player.money, r.player.money
	w:tradeMoney(r, 500)
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	local closedAt = w.time
	eq(r.env.GetMoney(), rMoney, "the rider's purse is the same until PLAYER_MONEY")
	w:advance(1)
	eq(rr.names(), "TRADE_SHOW TRADE_ACCEPT_UPDATE(0,1) TRADE_ACCEPT_UPDATE(1,1) TRADE_CLOSED TRADE_CLOSED PLAYER_MONEY",
		"the last accepter (rider)")
	eq(rd.names(), "TRADE_SHOW TRADE_MONEY_CHANGED TRADE_MONEY_CHANGED TRADE_ACCEPT_UPDATE(1,0) TRADE_CLOSED TRADE_CLOSED PLAYER_MONEY",
		"the first accepter (driver) never sees (1,1)")
	for _, rec in ipairs({ rr, rd }) do
		local c1, i1 = rec.find("TRADE_CLOSED")
		local c2 = rec.list[i1 + 1]
		eq(c1[2], closedAt, "the close comes as the last one accepts")
		eq(c2[1] .. "@" .. c2[2], "TRADE_CLOSED@" .. closedAt, "the second close in the same instant")
		local m = rec.find("PLAYER_MONEY")
		local dt = m[2] - closedAt
		ok(dt >= 0.1 and dt <= 0.45, "the purse 0.10-0.45 s after the close: " .. dt)
	end
	eq(r.env.GetMoney(), rMoney - 5000, "the rider paid")
	eq(d.env.GetMoney(), dMoney + 5000, "the driver got it")
	T.clean(w)
end)

-- trade.accept.update, the other 6 samples: the rider accepted first and saw only (1,0), e.g.
--   20 Nov 13:04:59.178 Wuber Rocks TRADE_ACCEPT_UPDATE me=1 them=0 trade=shown my=5000 their=0
--   13:05:05.529 TRADE_CLOSED, 13:05:05.529 TRADE_CLOSED, 13:05:05.929 PLAYER_MONEY -5000 now=14545
test("rec: real: the first to accept sees only (1,0) (trade.accept.update)", function()
	local w, d, r, rd, rr = setup()
	w:tradeMoney(r, 5000)
	w:tradeAccept(r)
	w:tradeAccept(d)
	w:advance(1)
	eq(rr.names(), "TRADE_SHOW TRADE_ACCEPT_UPDATE(1,0) TRADE_CLOSED TRADE_CLOSED PLAYER_MONEY", "rider, first")
	eq(rd.names(), "TRADE_SHOW TRADE_MONEY_CHANGED TRADE_ACCEPT_UPDATE(0,1) TRADE_ACCEPT_UPDATE(1,1) TRADE_CLOSED TRADE_CLOSED PLAYER_MONEY",
		"driver, last")
	T.clean(w)
end)

-- trade.money.changed: one TRADE_MONEY_CHANGED on the watching side per edit (their=500, their=5000)
test("rec: real: one TRADE_MONEY_CHANGED per edit of the other side's gold (trade.money.changed)", function()
	local w, d, r, rd = setup()
	w:tradeMoney(r, 500)
	w:tradeMoney(r, 5000)
	eq(rd.names(), "TRADE_SHOW TRADE_MONEY_CHANGED TRADE_MONEY_CHANGED")
	w:tradeCancel(r)
	T.clean(w)
end)

-- trade.cancel.sequence: TRADE_REQUEST_CANCEL in all 13 cancelled windows, with PLAYER_MONEY +0. The one
-- cancel both sides logged (21 Nov), verbatim:
--   00:06:59.317 Anita Lift  PLAYER_MONEY +0 now=27529 (trade open), TRADE_REQUEST_CANCEL, TRADE_CLOSED, TRADE_CLOSED
--   00:06:59.331 Wuber Rocks TRADE_CLOSED, TRADE_CLOSED
--   00:06:59.438 Wuber Rocks PLAYER_MONEY +0 now=14545, TRADE_REQUEST_CANCEL   (+0.107 s)
-- The first pattern (all at once, the purse while the trade is still open) is read as the side that
-- cancelled (it comes first; 5 windows), the second as the other side (4 windows with two closes,
-- 4 older ones on build 70938 with one). Who pressed Cancel is not in the log: an inference.
test("rec: real: a cancelled trade: the canceller and the other side (trade.cancel.sequence)", function()
	local w, d, r, rd, rr = setup()
	local dMoney, rMoney = d.player.money, r.player.money
	w:tradeCancel(d)
	local at = w.time
	eq(rd.names(), "TRADE_SHOW PLAYER_MONEY TRADE_REQUEST_CANCEL TRADE_CLOSED TRADE_CLOSED", "the canceller, at once")
	w:advance(1)
	eq(rr.names(), "TRADE_SHOW TRADE_CLOSED TRADE_CLOSED PLAYER_MONEY TRADE_REQUEST_CANCEL", "the other side")
	local m = rr.find("PLAYER_MONEY")
	ok(m[2] - at >= 0.05 and m[2] - at <= 0.15, "the other side's purse line 0.05-0.15 s later: " .. (m[2] - at))
	eq(rr.find("TRADE_CLOSED")[2], at, "its closes at once")
	eq(d.env.GetMoney(), dMoney, "no gold moved")
	eq(r.env.GetMoney(), rMoney, "no gold moved")
	T.clean(w)
end)

test("rec: real: the old trade orders stay on request (tradeOrder = \"old\")", function()
	local w, d, r, rd, rr = setup({ tradeOrder = "old" })
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	eq(rr.names(), "TRADE_SHOW TRADE_ACCEPT_UPDATE(0,1) TRADE_ACCEPT_UPDATE(1,1) PLAYER_MONEY TRADE_CLOSED", "money, then one close")
	T.clean(w)
end)
