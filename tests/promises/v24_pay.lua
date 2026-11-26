-- Promises about money and trades on the 2.4 code (tests/promises/v24_pay.lua; job 146, the logic half).
-- What the driver and the rider are told about money and what Wuber records: part payments, tips over the fare,
-- a trade cancelled or closed without gold, paying before the summon, gold from somebody who is not a customer,
-- two riders paying close together, the earnings record (the amount recorded is the amount traded, once).
-- Logic only: what happens, what is sent, what is saved, what number is shown. Nothing about layout.
return function(Hunt)
	local BORDER = { mapID = 1411, x = 0.04, y = 0.45, zone = "The Barrens", sub = "" } -- a trade with Ratchet, not arrived
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function asRider(sit)
		return (sit.role == nil or sit.role == "rider") and sit.net ~= "none" and sit.net ~= "oldpeer" and sit.net ~= "layers"
			and sit.net ~= "late" and (sit.group == nil or sit.group == "solo")
	end
	-- the fold dial's "folded_click" needs a phone that is open on a wide page; elsewhere it only gives cannot-build
	local FOLDABLE = { home = true, trips = true, drive = true, drive_earnings = true, drive_messages = true, drive_customers = true,
		settings = true, settings_riding = true, settings_driving = true, settings_map = true, settings_sound = true,
		settings_window = true, world_view = true, here_view = true, confirm = true, wrapped = true }
	local function promise(p)
		p.area = "Payment 2.4"
		p.kind = "scenario"
		p.needs = p.needs or { ride = "none" }
		local w = p.when or asRider
		p.when = function(sit)
			if sit.fold == "folded_click" and not FOLDABLE[sit.phone or "closed"] then return false end
			return w(sit)
		end
		Hunt.promise(p)
	end
	local function waitFor(ctx, pred, max, step)
		step = step or 0.25
		local t = 0
		while not pred() do
			if t >= max then return false end
			ctx:advance(step)
			t = t + step
		end
		return true
	end
	local function must(ctx, v, why) if not v then ctx:cannot("payv: " .. why) end end
	local function click(ctx, r, fn)
		local w = ctx.w
		if w.huntU then w.huntU.lastHW[r.name or ctx.name] = w.time end
		w.hardware = r
		local res = { pcall(fn) }
		w.hardware = nil
		if not res[1] then error(res[2], 0) end
		return unpack(res, 2)
	end

	-- the rider r (a client) books the driver d and joins the group; nothing is paid yet.
	-- returns { r, d, key, id, fare, c = the driver's row for the rider }
	local function book(ctx, r, d)
		local W = r.W
		local t = { r = r, d = d, key = key(d.player.name), rkey = key(r.player.name) }
		ctx.w:move(r.player.name, BORDER)
		if not waitFor(ctx, function() return W.drivers[t.key] ~= nil end, 240, 1) then
			local ks = {}
			for k in pairs(W.drivers) do ks[#ks + 1] = k end
			ctx:cannot("payv: the rider never saw the driver (drivers: " .. table.concat(ks, ",") .. "; chan " .. tostring(W.channelNum or W.chan) .. "; open " .. tostring(d.W.Drive.IsOpen and d.W.Drive.IsOpen()) .. ")")
		end
		local ride, why = click(ctx, r, function()
			local x, y = W.RequestRide(t.key)
			local text = x and W.RequestWhisper(t.key)
			if text then ctx.w:whisper(r, d.player.name, text, "macro") end
			return x, y
		end)
		must(ctx, ride, "the request was refused: " .. tostring(why))
		must(ctx, waitFor(ctx, function()
			local p = r.player
			if not p.group and p.pendingInvite then
				ctx.w.hardware = r
				r.env.AcceptGroup()
				ctx.w.hardware = nil
				r.popups.PARTY_INVITE = nil
			end
			return W.ride and W.RIDE_RANK[W.ride.state] >= W.RIDE_RANK.ingroup
		end, 12), "the rider never joined the group")
		t.fare = W.ride.price
		t.id = W.ride.id
		must(ctx, waitFor(ctx, function()
			t.c = d.W.Drive.customers[t.rkey]
			return t.c ~= nil
		end, 8), "the driver's list never got the rider")
		return t
	end

	-- the rider types copper in a trade the driver opens, both accept
	local function pay(ctx, t, copper)
		local rp, dp = t.r.player, t.d.player
		if rp.trade then ctx.w:tradeCancel(rp) end
		if dp.trade then ctx.w:tradeCancel(dp) end
		ctx:advance(0.5)
		must(ctx, ctx.w:openTrade(dp, rp), "no trade between the two")
		ctx.w:tradeMoney(rp, copper)
		ctx.w:tradeAccept(dp)
		ctx.w:tradeAccept(rp)
		ctx:note(t.r.player.name .. " pays " .. copper .. " copper by trade")
		ctx:advance(2.5)
	end

	local function snap(d)
		local life, sess = d.W.Drive.Stats()
		return { copper = life.copper, tips = life.tips, rides = life.rides, scopper = sess.copper, stips = sess.tips, srides = sess.rides }
	end
	local function logSum(d)
		local sum, n = 0, 0
		for _, line in ipairs(d.W.Drive.Log().rides or {}) do
			local c = tonumber(line:match("^[^,]*,(%d+),"))
			if c then sum = sum + c n = n + 1 end
		end
		return sum, n
	end
	local function setup(ctx)
		local d = ctx.peers.driver
		must(ctx, d, "no driver window")
		if ctx.me.player.combat then ctx:na("combat") end
		local before = snap(d)
		local lb, nb = logSum(d)
		return d, before, lb, nb
	end
	local function M(ctx, c) return ctx.W.Money(c) end

	---------------------------------------------------------------------------
	promise{
		id = "payv.part_then_rest_once",
		text = "If a rider pays part of the fare and then the rest, the driver's earnings grow by the fare once (not twice), the ride counts once, and the ride is paid.",
		source = "Drive/Trade.lua (a completed trade records its amount); Queue.lua applyPaid (paid adds up)",
		check = function(ctx)
			local d, b = setup(ctx)
			local t = book(ctx, ctx.me, d)
			local half = math.floor(t.fare / 200) * 100
			if half <= 0 or half >= t.fare then ctx:na("fare too small to split") end
			pay(ctx, t, half)
			pay(ctx, t, t.fare - half)
			local a = snap(d)
			local c = d.W.Drive.customers[t.rkey]
			if a.copper - b.copper ~= t.fare then
				ctx:fail(("A rider pays a %s fare in two trades and the driver's lifetime earnings grow by %s."):format(M(ctx, t.fare), M(ctx, a.copper - b.copper)))
			end
			if a.scopper - b.scopper ~= t.fare then
				ctx:fail(("A rider pays a %s fare in two trades and the driver's session earnings grow by %s."):format(M(ctx, t.fare), M(ctx, a.scopper - b.scopper)))
			end
			if c and (c.paid or 0) ~= t.fare then
				ctx:fail(("A rider pays a %s fare in two trades and the driver's queue shows %s paid."):format(M(ctx, t.fare), M(ctx, c.paid or 0)))
			end
			if a.tips - b.tips ~= 0 then
				ctx:fail(("A rider pays exactly the fare in two trades and the driver is told of a %s tip."):format(M(ctx, a.tips - b.tips)))
			end
		end,
	}

	promise{
		id = "payv.tip_over_fare",
		text = "If a rider pays more than the fare, the part over the fare is recorded as a tip, and the earnings grow by what was traded.",
		source = "Queue.lua applyPaid (tip = paid over price); Log.lua (tips and copper)",
		check = function(ctx)
			local d, b = setup(ctx)
			local t = book(ctx, ctx.me, d)
			local tip = 1500
			pay(ctx, t, t.fare + tip)
			local a = snap(d)
			if a.tips - b.tips ~= tip then
				ctx:fail(("A rider pays the %s fare plus a %s tip in one trade and the driver's tips grow by %s."):format(M(ctx, t.fare), M(ctx, tip), M(ctx, a.tips - b.tips)))
			end
			if a.copper - b.copper ~= t.fare + tip then
				ctx:fail(("A rider trades %s and the driver's earnings grow by %s."):format(M(ctx, t.fare + tip), M(ctx, a.copper - b.copper)))
			end
		end,
	}

	promise{
		id = "payv.tip_on_second_part",
		text = "If a rider pays part of the fare and then more than what is left, only the part over the whole fare is a tip.",
		source = "Queue.lua applyPaid (tip = over-price part of the running total)",
		check = function(ctx)
			local d, b = setup(ctx)
			local t = book(ctx, ctx.me, d)
			local first = math.floor(t.fare * 0.6 / 100) * 100
			local second = first + 300
			local tip = first + second - t.fare
			if first <= 0 or tip <= 0 then ctx:na("fare too small") end
			pay(ctx, t, first)
			pay(ctx, t, second)
			local a = snap(d)
			if a.tips - b.tips ~= tip then
				ctx:fail(("A rider pays %s then %s on a %s fare (%s over) and the driver's tips grow by %s."):format(
					M(ctx, first), M(ctx, second), M(ctx, t.fare), M(ctx, tip), M(ctx, a.tips - b.tips)))
			end
		end,
	}

	promise{
		id = "payv.cancelled_trade_no_gold",
		text = "A trade that is cancelled after the rider typed gold records nothing: no earnings, no payment, the fare is still due.",
		source = "Drive/Trade.lua (only a COMPLETED trade counts)",
		check = function(ctx)
			local d, b, lb, nb = setup(ctx)
			local t = book(ctx, ctx.me, d)
			local rp, dp = ctx.me.player, d.player
			must(ctx, ctx.w:openTrade(dp, rp), "no trade")
			ctx.w:tradeMoney(rp, t.fare)
			ctx.w:tradeAccept(dp)
			ctx:advance(0.5)
			ctx.w:tradeCancel(rp)
			ctx:note("the rider cancels the trade with the gold typed")
			ctx:advance(6)
			local a = snap(d)
			local c = d.W.Drive.customers[t.rkey]
			local la, na = logSum(d)
			if a.copper ~= b.copper or a.scopper ~= b.scopper or la ~= lb or na ~= nb then
				ctx:fail(("A rider types the whole %s fare and cancels the trade, and the driver's earnings record grows by %s."):format(M(ctx, t.fare), M(ctx, a.copper - b.copper)))
			end
			if c and (c.paid or 0) ~= 0 then
				ctx:fail(("A rider cancels a trade and the driver's queue shows %s paid."):format(M(ctx, c.paid)))
			end
			if (ctx.W.ride and ctx.W.ride.paid or 0) ~= 0 then
				ctx:fail(("You cancel the trade and your own ride says %s paid."):format(M(ctx, ctx.W.ride.paid)))
			end
		end,
	}

	promise{
		id = "payv.empty_trade_closed",
		text = "A trade both sides accept with no gold in it is not a payment: nothing is recorded and the ride is not paid.",
		source = "Drive/Trade.lua (amount must be above zero)",
		check = function(ctx)
			local d, b, lb, nb = setup(ctx)
			local t = book(ctx, ctx.me, d)
			pay(ctx, t, 0)
			ctx:advance(4)
			local a = snap(d)
			local c = d.W.Drive.customers[t.rkey]
			local la, na = logSum(d)
			if a.copper ~= b.copper or na ~= nb or la ~= lb then
				ctx:fail("A rider and a driver close a trade with no gold in it and the driver's earnings record a payment.")
			end
			if c and (c.paid or 0) > 0 then
				ctx:fail("A rider and a driver close a trade with no gold in it and the driver's queue shows the rider as paid.")
			end
			if (ctx.W.ride and ctx.W.ride.paid or 0) > 0 then
				ctx:fail("You close a trade with no gold in it and your own ride says you have paid.")
			end
		end,
	}

	promise{
		id = "payv.prepaid_recorded_not_asked",
		text = "A rider who pays the fare by trade before the summon is recorded as paid once, and nothing is still due.",
		source = "Drive/Trade.lua + Queue.lua (prepaid); Raincheck.lua (paid by trade before the rider arrived)",
		check = function(ctx)
			local d, b = setup(ctx)
			local t = book(ctx, ctx.me, d)
			pay(ctx, t, t.fare)
			local c = d.W.Drive.customers[t.rkey]
			if not c then ctx:na("the driver's row is gone") end
			local a = snap(d)
			if a.copper - b.copper ~= t.fare then
				ctx:fail(("A rider pays the %s fare before the summon and the driver's earnings grow by %s."):format(M(ctx, t.fare), M(ctx, a.copper - b.copper)))
			end
			if d.W.Drive.Due(c) ~= 0 then
				ctx:fail(("A rider pays the whole fare before the summon and the driver still has %s due."):format(M(ctx, d.W.Drive.Due(c))))
			end
			if (ctx.W.ride and ctx.W.ride.paid or 0) ~= t.fare then
				ctx:fail(("You pay the %s fare before the summon and your own ride says %s paid."):format(M(ctx, t.fare), M(ctx, ctx.W.ride and ctx.W.ride.paid or 0)))
			end
			-- the driver does not open another trade for a ride that is paid
			ctx:advance(45)
			for _ = 1, 20 do
				if ctx.me.player.trade then
					ctx:fail("You paid the whole fare before the summon and the driver opens another trade with you.")
				end
				ctx:advance(2)
			end
			local a2 = snap(d)
			if a2.copper ~= a.copper then
				ctx:fail("A paid ride's earnings keep changing after the trade: " .. M(ctx, a2.copper - a.copper) .. " more with no new trade.")
			end
		end,
	}

	promise{
		id = "payv.stranger_gold_no_ride",
		text = "Gold from somebody who is not a customer never marks a rider as paid and never counts as a ride.",
		source = "Drive/Trade.lua (a gift is recorded as a payment from a name, not a customer)",
		check = function(ctx)
			local d, b = setup(ctx)
			local t = book(ctx, ctx.me, d)
			local name = "Sam Stranger"
			if not ctx.w:player(name) then ctx.w:addClient(name, { spot = BORDER, class = "MAGE", money = 500000 }) end
			ctx.w:move(name, BORDER)
			local sp = ctx.w:player(name)
			ctx:advance(1)
			if d.player.trade then ctx.w:tradeCancel(d.player) ctx:advance(1) end
			must(ctx, ctx.w:openTrade(d.player, sp), "no trade with the stranger")
			ctx.w:tradeMoney(sp, t.fare)
			ctx.w:tradeAccept(d.player)
			ctx.w:tradeAccept(sp)
			ctx:advance(4)
			local a = snap(d)
			local c = d.W.Drive.customers[t.rkey]
			if c and (c.paid or 0) > 0 then
				ctx:fail("A stranger gives the driver gold and the driver's queue shows the waiting rider as paid.")
			end
			if a.rides ~= b.rides or a.srides ~= b.srides then
				ctx:fail("A stranger gives the driver gold and it counts as a ride.")
			end
			if (ctx.W.ride and ctx.W.ride.paid or 0) > 0 then
				ctx:fail("A stranger gives your driver gold and your own ride says you have paid.")
			end
		end,
	}

	promise{
		id = "payv.two_riders_close",
		text = "If two riders pay close together, each one is recorded as paid their own fare and the earnings are the sum of the two trades.",
		source = "Drive/Trade.lua (one trade at a time, one record each)",
		check = function(ctx)
			local d, b, lb, nb = setup(ctx)
			local name = "Rob Rider"
			if not ctx.w:player(name) then ctx.w:addClient(name, { spot = BORDER, class = "MAGE", money = 500000 }) end
			local r2 = ctx.w:clientOf(name)
			must(ctx, r2 and r2.W, "no second rider window")
			local t1 = book(ctx, ctx.me, d)
			local t2 = book(ctx, r2, d)
			pay(ctx, t1, t1.fare)
			-- the second rider's trade comes right behind the first
			local rp, dp = r2.player, d.player
			ctx:advance(0.2)
			must(ctx, ctx.w:openTrade(dp, rp), "no trade with the second rider")
			ctx.w:tradeMoney(rp, t2.fare)
			ctx.w:tradeAccept(dp)
			ctx.w:tradeAccept(rp)
			ctx:advance(4)
			local a = snap(d)
			local c1, c2 = d.W.Drive.customers[t1.rkey], d.W.Drive.customers[t2.rkey]
			if a.copper - b.copper ~= t1.fare + t2.fare then
				ctx:fail(("Two riders pay %s and %s close together and the driver's earnings grow by %s."):format(M(ctx, t1.fare), M(ctx, t2.fare), M(ctx, a.copper - b.copper)))
			end
			if (c1 and (c1.paid or 0) ~= t1.fare) or (c2 and (c2.paid or 0) ~= t2.fare) then
				ctx:fail(("Two riders pay their fares close together and the queue shows %s and %s paid, not %s and %s."):format(
					M(ctx, c1 and c1.paid or 0), M(ctx, c2 and c2.paid or 0), M(ctx, t1.fare), M(ctx, t2.fare)))
			end
			local la, na = logSum(d)
			if na - nb ~= 2 or la - lb ~= t1.fare + t2.fare then
				ctx:fail(("Two riders pay close together and the earnings log gains %d lines worth %s."):format(na - nb, M(ctx, la - lb)))
			end
		end,
	}

	promise{
		id = "payv.log_matches_total",
		text = "The earnings log and the earnings total agree: after part payments and a tip, the amounts in the log add up to what the total grew by.",
		source = "Log.lua (one line per payment; stats.copper)",
		check = function(ctx)
			local d, b, lb, nb = setup(ctx)
			local t = book(ctx, ctx.me, d)
			local p1 = math.floor(t.fare * 0.5 / 100) * 100
			if p1 <= 0 then ctx:na("fare too small") end
			pay(ctx, t, p1)
			pay(ctx, t, t.fare - p1 + 700)
			local a = snap(d)
			local la = logSum(d)
			if a.copper - b.copper ~= la - lb then
				ctx:fail(("The driver's earnings total grew by %s and the earnings log adds up to %s."):format(M(ctx, a.copper - b.copper), M(ctx, la - lb)))
			end
			if a.copper - b.copper ~= t.fare + 700 then
				ctx:fail(("A rider traded %s in all and the driver's earnings grew by %s."):format(M(ctx, t.fare + 700), M(ctx, a.copper - b.copper)))
			end
		end,
	}

	promise{
		id = "payv.sides_agree_part_paid",
		text = "After a part payment the rider's own ride and the driver's queue agree on how much is paid, and it survives the rider's /reload.",
		source = "Net.Rides (part payments add up); saved ride state",
		check = function(ctx)
			local d = setup(ctx)
			local t = book(ctx, ctx.me, d)
			local half = math.floor(t.fare / 200) * 100
			if half <= 0 or half >= t.fare then ctx:na("fare too small to split") end
			pay(ctx, t, half)
			local c = d.W.Drive.customers[t.rkey]
			local mine = ctx.W.ride and (ctx.W.ride.paidSoFar or ctx.W.ride.paid) or 0
			if c and (c.paid or 0) ~= mine then
				ctx:fail(("You pay %s of a %s fare and your ride says %s paid while the driver's queue says %s."):format(M(ctx, half), M(ctx, t.fare), M(ctx, mine), M(ctx, c.paid or 0)))
			end
			ctx:reload()
			ctx:advance(5)
			local after = ctx.W.ride and (ctx.W.ride.paidSoFar or ctx.W.ride.paid) or 0
			if ctx.W.ride and after ~= half then
				ctx:fail(("You pay %s of a %s fare, then /reload, and your ride says %s paid."):format(M(ctx, half), M(ctx, t.fare), M(ctx, after)))
			end
		end,
	}
end
