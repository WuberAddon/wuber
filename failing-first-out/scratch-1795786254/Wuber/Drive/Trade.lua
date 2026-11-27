-- Module: Drive.Trade
-- Purpose: Reading payment in the trade window (was Drive_Trade.lua).
-- API: W.Drive, DR.trade, DR.TradeUpdate, DR.TradeDone, DR.PumpTrade
-- Internals: (none)
-- Uses: (none)
-- Later: (none)
-- Events: listens On TRADE_SHOW, On TRADE_MONEY_CHANGED, On PLAYER_TRADE_MONEY, On
--   TRADE_TARGET_ITEM_CHANGED, On TRADE_PLAYER_ITEM_CHANGED, On TRADE_UPDATE, On TRADE_ACCEPT_UPDATE,
--   On TRADE_CLOSED, On UI_INFO_MESSAGE, On UI_ERROR_MESSAGE, Listen DRIVE_STATE; fires -
-- Standalone: no
-- Test: tests/drive/trade_test.lua
-- From: Drive_Trade.lua 1-261 (Wuber 2.2.1)
--
-- Wuber Drive: the payment (agent B). Ported from Ritual Rides 1.4.1's Trade.lua.
--
-- A rider pays through the trade window, typing the gold by hand (WoW Forever lets no addon
-- put money in a trade). This file reads what they put in, tells the big button when the
-- amount is right (the button then presses the game's own Trade button on your click:
-- accepting a trade needs a hardware event), and records the payment when the game says
-- "Trade complete". Nothing here accepts a trade or puts gold in one.

local ADDON, W = ...
local Mod = W.Module("Drive.Trade", {})
W.Drive = W.Drive or {}
local DR = W.Drive

local plain, num, str = W.Plain, W.Num, W.Str

DR.trade = nil -- the open trade: { name, key, money, due, ready, giving, mine, theirs, start, at }

local function now() return W.Now() end

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

local function opts()
	local o = call("opts")
	return type(o) == "table" and o or {}
end

local function customer(key)
	local list = DR.customers
	return key and type(list) == "table" and list[key] or nil
end

local function exists(v)
	if type(issecretvalue) == "function" then
		local ok, hidden = pcall(issecretvalue, v)
		if not ok or hidden == true then return true end -- a hidden answer is still there
	end
	return v ~= nil
end

local function theirMoney()
	if type(GetTargetTradeMoney) ~= "function" then return 0 end
	local ok, m = pcall(GetTargetTradeMoney)
	return ok and (num(m) or tonumber(plain(m))) or 0
end

-- Do we put anything into this trade ourselves? Then it is not a plain payment.
local function giving()
	if type(GetPlayerTradeMoney) == "function" then
		local ok, m = pcall(GetPlayerTradeMoney)
		if ok and ((num(m) or tonumber(plain(m)) or 0) > 0) then return true end
	end
	if type(GetTradePlayerItemInfo) == "function" then
		for i = 1, (tonumber(MAX_TRADABLE_ITEMS) or 6) do
			local ok, name = pcall(GetTradePlayerItemInfo, i)
			if ok and exists(name) then return true end
		end
	end
	return false
end

-- What the driver puts into the trade (change given back); read only, never set.
local function myMoney()
	if type(GetPlayerTradeMoney) ~= "function" then return 0 end
	local ok, m = pcall(GetPlayerTradeMoney)
	return ok and (num(m) or tonumber(plain(m))) or 0
end

local function purse()
	if type(GetMoney) ~= "function" then return nil end
	local ok, m = pcall(GetMoney)
	return ok and num(m) or nil
end

local function update()
	local t = DR.trade
	if not t then return end
	t.money = theirMoney() or 0
	t.mine_money = myMoney()
	t.giving = giving()
	local c = customer(t.key)
	if c then
		t.due = tonumber(call("Due", c)) or 0
		t.ready = t.money > 0 and not t.giving and (t.money >= t.due or opts().acceptUnder == true)
	else
		t.due, t.ready = 0, false
	end
	call("Changed")
end
DR.TradeUpdate = update

local function resolve(name)
	if not name then return nil end
	local k = call("ResolveKey", name)
	if type(k) == "string" then return k end
	return W.Key(name)
end

-- Raid summons are free: no trade is read while a raid runs (DR.Mode "raid").
local function raidMode() return call("Mode") == "raid" end

W.On("TRADE_SHOW", function()
	if raidMode() then
		DR.trade = nil
		return
	end
	local name = W.UnitName("NPC") -- the trade partner's unit token
	DR.trade = { name = name, key = resolve(name), money = 0, due = 0, mine = 0, theirs = 0, start = purse(), at = now() }
	update()
end)

W.On("TRADE_MONEY_CHANGED", update)
W.On("PLAYER_TRADE_MONEY", update)
W.On("TRADE_TARGET_ITEM_CHANGED", update)
W.On("TRADE_PLAYER_ITEM_CHANGED", update)
W.On("TRADE_UPDATE", update)

-- The trade went through: who paid what. Only a COMPLETED trade counts (2.2, review #3): the
-- game said "Trade complete", or both sides had accepted when the window closed and no
-- failure line came. What the purse gained stands in for an amount never read, and only right
-- after such a trade (a vendor sale or a mail a moment later is not a payment).
local FALLBACK_WINDOW = 3 -- seconds after the close the purse may still speak for the trade

local function completed(t)
	if t.failed then return false end
	return t.complete == true or t.closedBoth == true
end

local function tradeDone(t)
	if t.counted or not completed(t) then return end
	local amount = (t.money or 0) - (t.mine_money or 0) -- change the driver gave back is not a payment
	if amount <= 0 and (t.money or 0) <= 0 and t.start and t.closedAt and now() - t.closedAt <= FALLBACK_WINDOW then
		-- the window closed before its last amount was read: what the purse gained
		local m = purse()
		if m and m > t.start then amount = m - t.start end
	end
	if amount <= 0 then return end -- (AUD-68) not counted yet: the 1 s timer or a later call may still read the purse
	t.counted = true
	if t.key and call("IsCrewKey", t.key) then return end -- gold moved inside the crew
	if t.key and call("IsBellKey", t.key) then return end -- or from the alert character
	local c = customer(t.key)
	if not c and t.key and type(DR.owing) == "table" and DR.owing[t.key] then
		c = DR.owing[t.key].c -- (AUD-67) paid and left a moment ago: the fare still counts
	end
	if c then
		call("Do", "PAID", c.name, amount)
		local payee = DR.PayeeKey and DR.PayeeKey(c)
		if payee and payee ~= W.myKey and DR.ShortOf then
			-- any crew member may take it; the rider was told to pay the payee
			W.Print(c.name .. " paid you instead of " .. tostring(DR.ShortOf(payee)) .. ": it counts.")
		end
		local left = tonumber(call("Due", c)) or 0
		if left > 0 and not opts().acceptUnder then
			W.Print(c.name .. " paid " .. W.Money(amount) .. ": " .. W.Money(left) .. " still due.")
		else
			W.Print(c.name .. " paid " .. W.Money(amount) .. ".")
		end
	elseif call("IsOpen") and not t.giving then -- a sale (we put something in) is no summon takings
		call("Do", "PAID", t.name or "?", amount)
		W.Print((t.name or "Somebody") .. " gave you " .. W.Money(amount) .. ".")
	end
end
DR.TradeDone = tradeDone

W.On("TRADE_ACCEPT_UPDATE", function(mine, theirs)
	local t = DR.trade
	if not t then return end
	t.mine, t.theirs = num(mine) or 0, num(theirs) or 0
	update()
end)

W.On("TRADE_CLOSED", function()
	local t = DR.trade
	if not t then return end
	DR.trade = nil
	t.closedAt = now()
	DR.lastTrade = t
	if t.mine == 1 and t.theirs == 1 then
		-- both sides had accepted: the trade happened unless the game says it failed (its
		-- "Trade complete" line may not reach us)
		t.closedBoth = true
		W.After(1, function() tradeDone(t) end)
	end
	call("Changed")
end)

-- The game's lines about a trade: "Trade complete", or why it did not go through.
local FAILS = { "ERR_TRADE_CANCELLED", "ERR_TRADE_BAG_FULL", "ERR_TRADE_TARGET_BAG_FULL", "ERR_TRADE_TOO_FAR",
	"ERR_TRADE_TARGET_DEAD", "ERR_TRADE_MAX_COUNT_EXCEEDED", "ERR_TRADE_TARGET_MAX_COUNT_EXCEEDED",
	"ERR_TRADE_NOT_ON_TAPLIST", "ERR_TRADE_QUEST_ITEM", "ERR_TRADE_SELF", "ERR_TRADE_WRONG_REALM",
	"ERR_TRADE_EQUIPPED_BAG", "ERR_TRADE_GROUND_ITEM", "ERR_TRADE_BOUND_ITEM", "ERR_TRADE_TEMP_ENCHANT_BOUND" }

local function isFail(message)
	for _, k in ipairs(FAILS) do
		local v = rawget(_G, k)
		if type(v) == "string" and v ~= "" and message == v then return true end
	end
	return false
end

-- (messageType, message) on this client; an older client sends the message alone
local function tradeLine(a, b)
	local message = str(b)
	if not message and type(a) == "string" then message = str(a) end
	if not message then return end
	local t = DR.trade or DR.lastTrade
	if not t or t.counted then return end
	if t.closedAt and now() - t.closedAt > 5 then return end
	if message == ERR_TRADE_COMPLETE then
		t.complete, t.failed = true, nil
		W.After(0.3, function() tradeDone(t) end)
	elseif isFail(message) then
		t.failed = true
	end
end

W.On("UI_INFO_MESSAGE", tradeLine)
W.On("UI_ERROR_MESSAGE", tradeLine)

---------------------------------------------------------------------------
-- Opening the trade for a rider who has landed
---------------------------------------------------------------------------

local function inTradeRange(unit)
	if type(CheckInteractDistance) ~= "function" then return false end
	local ok, near = pcall(CheckInteractDistance, unit, 2) -- 2 = trade distance
	return ok and plain(near) == true
end

-- Once a second. The one who cast the summon opens the trade (the leader when that one is
-- gone): twice at most per rider, 20 s apart, 3 s after landing, never in combat, never
-- over another trade.
-- The payee opens it (2.1: the summoner who cast the rider); nobody does when the payee has
-- no Wuber: the rider trades them by hand and the runner marks it paid.
function DR.PumpTrade()
	local o, t = opts(), now()
	if not call("IsOpen") or o.autoTrade == false or DR.trade or W.InCombat() or raidMode() then return end
	if W.IsBlocked("trade-open") or type(InitiateTrade) ~= "function" then return end
	local last = DR.lastTrade
	if last and last.closedAt and t - last.closedAt < 3 then return end
	local list = call("Sorted")
	if type(list) ~= "table" then return end
	for _, c in ipairs(list) do
		local unit = DR.units and DR.units[c.key]
		if c.state == "arrived" and unit and not c.walked and (c.tries or 0) > 0 and (tonumber(call("Due", c)) or 0) > 0
			and not (DR.PayeeBlind and DR.PayeeBlind(c))
			and DR.Speaks and DR.Speaks((DR.PayeeKey and DR.PayeeKey(c)) or c.caster)
			and (c.tradeTries or 0) < 2 and t - (c.arrivedAt or t) >= 3 and t - (c.tradeAt or -100) >= 20
			and inTradeRange(unit) then
			c.tradeTries = (c.tradeTries or 0) + 1
			c.tradeAt = t
			W.Try("trade-open", InitiateTrade, unit)
			return
		end
	end
end

-- A rider whose payee has no Wuber: nobody can watch them pay, so nobody may auto-block them
-- (A's DR.NonPayer reads c.payeeBlind; the console row says "paid? ask Bea").
W.Listen("DRIVE_STATE", function(c)
	if type(c) ~= "table" or not DR.PayeeBlind then return end
	local blind = DR.PayeeBlind(c) or nil
	if c.payeeBlind ~= blind then c.payeeBlind = blind end
end)
