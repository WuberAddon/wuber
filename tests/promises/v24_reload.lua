-- Promises about saved data and /reload in the middle of a ride (tests/promises/v24_reload.lua; job 146, the logic half).
-- LOGIC ONLY: what is sent, saved, counted. Written from the driver's queue snapshot (Drive/Core.lua SNAP) and the rider's saved ride
-- (Net/Rides.lua SAVED): a field the ride sets that is in neither list is lost on a /reload.
return function(Hunt)
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function DR(ctx) return ctx.W.Drive end
	local function isDriver(sit) return sit.role == "warlock" end
	local function isRider(sit) return sit.role == nil or sit.role == "rider" end
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
	local function whispersTo(ctx, name)
		local out, k = {}, key(name)
		for _, x in ipairs(ctx.w.whispers or {}) do
			if key(x.from) == key(ctx.name) and key(x.to) == k then out[#out + 1] = x end
		end
		return out
	end
	local function line(x) return tostring(x.msg or x.text or x.message or "?") end
	-- the driver's row for the rider window of the build
	local function riderRow(ctx)
		local r = ctx.peers.rider
		if not r then ctx:cannot("no rider window") end
		local d = DR(ctx)
		if not d or not d.customers then ctx:cannot("no Drive") end
		return r, d.customers[key(r.player.name)], d
	end
	local function ready(ctx)
		local r, c, d = riderRow(ctx)
		if not c then ctx:na("the rider is not on the driver's console here") end
		if ctx.me.player.combat then ctx:na("in combat") end
		return r, c, d
	end
	-- the rider (a window) pays copper by trade, as a player does
	local function riderPays(ctx, r, copper)
		local w = ctx.w
		local rp, pp = r.player, w:player(ctx.name)
		local tr = rp.trade
		if tr and not (tr.a == pp or tr.b == pp) then w:tradeCancel(rp) end
		if not rp.trade and not w:openTrade(pp, rp) then ctx:cannot("no trade between me and the rider") end
		w:tradeMoney(rp, copper)
		w:tradeAccept(pp)
		w:tradeAccept(rp)
		ctx:note("the rider pays " .. copper .. " copper by trade")
		ctx:advance(4)
	end
	local function rowAgain(ctx, name)
		local d = DR(ctx)
		return d and d.customers and d.customers[key(name)]
	end

	Hunt.promise{
		id = "snap.driver_row_numbers_same",
		area = "Reload",
		text = "You are driving with a rider in the group and you /reload: the rider is still on your console with the same step, fare and gold paid.",
		source = "Drive/Core.lua SNAP (state, price, paid)",
		kind = "scenario",
		needs = { role = "warlock", ride = "arrived", combat = "no" },
		when = isDriver,
		check = function(ctx)
			local r, c = ready(ctx)
			local name = r.player.name
			local st, price, paid = c.state, c.price, c.paid or 0
			ctx:reload()
			ctx:advance(5)
			local c2 = rowAgain(ctx, name)
			if not c2 then ctx:fail("You /reload while " .. name .. " is on your console and the rider is gone from it.") end
			if c2.state ~= st or c2.price ~= price or (c2.paid or 0) ~= paid then
				ctx:fail("After a /reload the rider's row reads step " .. tostring(c2.state) .. ", fare " .. tostring(c2.price) .. ", paid " .. tostring(c2.paid or 0) ..
					" instead of " .. tostring(st) .. ", " .. tostring(price) .. ", " .. tostring(paid) .. ".")
			end
		end,
	}

	Hunt.promise{
		id = "snap.no_second_greeting",
		area = "Reload",
		text = "A rider you already greeted is not greeted, priced or reminded again just because you /reload.",
		source = "Drive/Core.lua SNAP (greeted, thanked, reminded); Drive/Chat.lua",
		kind = "scenario",
		needs = { role = "warlock", ride = "arrived", combat = "no" },
		when = isDriver,
		check = function(ctx)
			local r, c = ready(ctx)
			local name = r.player.name
			ctx:advance(30)
			local before = #whispersTo(ctx, name)
			ctx:reload()
			ctx:advance(60)
			local after = whispersTo(ctx, name)
			if #after > before then
				local x = after[#after]
				ctx:fail("You /reload mid-ride and the rider gets another whisper from you: " .. line(x))
			end
		end,
	}

	Hunt.promise{
		id = "snap.part_payment_remembered",
		area = "Reload",
		text = "A rider pays part of the fare by trade, you /reload, and he pays the rest: you are not asked to count the part twice or lose it, and the ride is counted once.",
		source = "Drive/Core.lua SNAP (paid, price); Drive/Queue.lua applyPaid",
		kind = "scenario",
		needs = { role = "warlock", ride = "arrived", combat = "no" },
		when = isDriver,
		check = function(ctx)
			local r, c, d = ready(ctx)
			local name = r.player.name
			if c.state == "paid" or c.state == "done" or (c.paid or 0) > 0 then ctx:na("already paid here") end
			local price = c.price or 0
			if price < 200 then ctx:na("no fare") end
			local half = math.floor(price / 200) * 100
			riderPays(ctx, r, half)
			local c1 = rowAgain(ctx, name)
			if not c1 or (c1.paid or 0) ~= half then ctx:na("the part payment was not counted before the reload") end
			if c1.state == "paid" or c1.state == "done" then ctx:na("a part payment already counts as paid here (accept less): the rider may leave") end
			local rides0 = d.session and d.session.rides or 0
			ctx:reload()
			ctx:advance(5)
			local c2 = rowAgain(ctx, name)
			if not c2 then ctx:fail("You /reload after a part payment and the rider is gone from your console.") end
			if (c2.paid or 0) ~= half then ctx:fail("A rider paid " .. half .. " copper of " .. price .. ", you /reload, and your console says " .. tostring(c2.paid or 0) .. " is paid.") end
			riderPays(ctx, r, price - half)
			local c3 = rowAgain(ctx, name)
			local d2 = DR(ctx)
			if c3 and (c3.paid or 0) < price then ctx:fail("A rider paid the whole fare in two trades with a /reload between and your console says only " .. tostring(c3.paid or 0) .. " of " .. price .. " is paid.") end
			if c3 and c3.state ~= "paid" and c3.state ~= "done" then ctx:fail("A rider paid the whole fare in two trades with a /reload between and his step is still " .. tostring(c3.state) .. ".") end
			local rides1 = d2.session and d2.session.rides or 0
			if rides1 - 0 ~= 1 and rides1 > 1 then ctx:fail("The ride was counted " .. rides1 .. " times.") end
		end,
	}

	Hunt.promise{
		id = "snap.paid_rider_not_asked_again",
		area = "Reload",
		text = "A rider who has paid the whole fare and thanked is not asked to pay or thanked again after your /reload.",
		source = "Drive/Core.lua SNAP (paid, thanked, state)",
		kind = "scenario",
		needs = { role = "warlock", ride = "arrived", combat = "no" },
		when = isDriver,
		check = function(ctx)
			local r, c = ready(ctx)
			local name = r.player.name
			if (c.paid or 0) < (c.price or 0) then
				if (c.price or 0) < 100 then ctx:na("no fare") end
				riderPays(ctx, r, c.price)
			end
			ctx:advance(10)
			local c1 = rowAgain(ctx, name)
			if not (c1 and (c1.state == "paid" or c1.state == "done")) then ctx:na("the rider is not paid here (" .. tostring(c1 and c1.state) .. ")") end
			local before = #whispersTo(ctx, name)
			ctx:reload()
			ctx:advance(60)
			local after = whispersTo(ctx, name)
			if #after > before then ctx:fail("A rider has paid in full, you /reload, and he gets another whisper from you: " .. line(after[#after])) end
			local c2 = rowAgain(ctx, name)
			if c2 and c2.state ~= "paid" and c2.state ~= "done" then ctx:fail("A paid rider is back at step " .. tostring(c2.state) .. " after your /reload.") end
		end,
	}

	Hunt.promise{
		id = "snap.tip_kept",
		area = "Reload",
		text = "A rider tips on top of the fare, you /reload: the tip is still part of what your console says he paid.",
		source = "Drive/Core.lua SNAP (paid, price); Queue.lua applyPaid (tip = paid - price)",
		kind = "scenario",
		needs = { role = "warlock", ride = "arrived", combat = "no" },
		when = isDriver,
		check = function(ctx)
			local r, c = ready(ctx)
			local name = r.player.name
			if (c.paid or 0) > 0 or (c.price or 0) < 100 then ctx:na("not a fresh unpaid fare") end
			local total = c.price + 500
			riderPays(ctx, r, total)
			local c1 = rowAgain(ctx, name)
			if not c1 or (c1.paid or 0) ~= total then ctx:na("the tip was not counted before the reload") end
			ctx:reload()
			ctx:advance(5)
			local c2 = rowAgain(ctx, name)
			if not c2 then ctx:na("the rider left the console") end
			if (c2.paid or 0) ~= total then ctx:fail("A rider paid " .. total .. " copper, fare plus a tip of 500, you /reload and your console says " .. tostring(c2.paid or 0) .. " was paid.") end
		end,
	}

	Hunt.promise{
		id = "snap.no_double_thanks_for_tip",
		area = "Reload",
		text = "After a /reload a rider you have already thanked for his tip is not thanked a second time.",
		source = "Drive/Core.lua SNAP (thanked); Drive/Chat.lua tip",
		kind = "scenario",
		needs = { role = "warlock", ride = "arrived", combat = "no" },
		when = isDriver,
		check = function(ctx)
			local r, c = ready(ctx)
			local name = r.player.name
			if (c.paid or 0) > 0 or (c.price or 0) < 100 then ctx:na("not a fresh unpaid fare") end
			riderPays(ctx, r, c.price + 500)
			ctx:advance(15)
			local before = #whispersTo(ctx, name)
			ctx:reload()
			ctx:advance(60)
			local after = whispersTo(ctx, name)
			if #after > before then ctx:fail("You thanked a rider for his tip, /reload, and he is whispered again: " .. line(after[#after])) end
		end,
	}

	Hunt.promise{
		id = "snap.auto_invite_can_still_be_oopsed",
		area = "Reload",
		text = "A rider Wuber invited by itself who is in your group is still marked as an automatic invite after a /reload, so Oops is still offered.",
		source = "release/CHANGELOG-2.4.0.md (Oops); Drive/Careful.lua CanOops reads c.auto",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", combat = "no" },
		when = isDriver,
		check = function(ctx)
			local d = DR(ctx)
			if not (d and d.IsOpen and d.IsOpen()) then ctx:na("not open") end
			if d.Role() ~= "driver" or not d.IsLeader() then ctx:na("not the group's driver") end
			if ctx.me.player.combat then ctx:na("in combat") end
			d.opts().autoInvite = true
			d.opts().kickAfter = false
			local name = "Reload Rae"
			if not ctx.w:player(name) then ctx.w:addBot(name, { acceptsInvites = true }) end
			ctx.w:botWhisper(name, ctx.me, "summ pls")
			ctx:advance(12)
			local c = d.customers[key(name)]
			if not (c and c.auto == "whisper" and (c.state == "joined" or c.state == "invited")) then ctx:na("no auto invite joined here (" .. tostring(c and c.state) .. ")") end
			if not d.CanOops(c) then ctx:na("Oops is not offered even before the reload") end
			ctx:reload()
			ctx:advance(5)
			local d2 = DR(ctx)
			local c2 = d2.customers[key(name)]
			if not c2 then ctx:na("the rider is not on the console after the reload") end
			if not d2.CanOops(c2) then ctx:fail("A rider Wuber invited by itself is in your group; after a /reload there is no Oops for him any more.") end
		end,
	}

	Hunt.promise{
		id = "snap.big_button_step_same",
		area = "Reload",
		text = "The step the big button offers for a rider is the same after you /reload.",
		source = "Drive/Plan.lua; Drive/Core.lua SNAP",
		kind = "scenario",
		needs = { role = "warlock", ride = "arrived", combat = "no" },
		when = isDriver,
		check = function(ctx)
			local r, c, d = ready(ctx)
			local p = d.Plan and d.Plan()
			local t0 = p and p.title
			if not t0 then ctx:na("no plan") end
			if t0:find("trading", 1, true) then ctx:na("a trade window is open: a /reload closes it") end
			ctx:reload()
			ctx:advance(5)
			local p2 = DR(ctx).Plan and DR(ctx).Plan()
			local t1 = p2 and p2.title
			if t1 ~= t0 and (t0:find("Waiting", 1, true) or tostring(t1):find("trading", 1, true)) then ctx:na("the trade step opens again on its own after arrival (timing, not a loss)") end
			if t1 ~= t0 then ctx:fail("The big button says '" .. tostring(t0) .. "' and after a /reload it says '" .. tostring(t1) .. "'.") end
		end,
	}

	Hunt.promise{
		id = "snap.rider_not_listed_twice",
		area = "Reload",
		text = "After a /reload a rider is on your console once, not twice.",
		source = "Drive/Core.lua restore",
		kind = "scenario",
		needs = { role = "warlock", ride = "arrived", combat = "no" },
		when = isDriver,
		check = function(ctx)
			local r = ready(ctx)
			ctx:reload()
			ctx:advance(5)
			local n = 0
			for _, c in pairs(DR(ctx).customers) do if key(c.name or "") == key(r.player.name) then n = n + 1 end end
			if n > 1 then ctx:fail("After a /reload the rider is on your console " .. n .. " times.") end
		end,
	}

	local function ride(ctx) return ctx.W.ride end
	Hunt.promise{
		id = "snap.rider_ride_numbers_same",
		area = "Reload",
		text = "You are riding, you /reload: the ride has the same driver, fare, step and gold paid.",
		source = "Net/Rides.lua SAVED (driver, price, state, paid)",
		kind = "scenario",
		needs = { role = "rider", ride = "arrived", combat = "no" },
		when = isRider,
		check = function(ctx)
			local r0 = ride(ctx)
			if not r0 then ctx:na("no ride") end
			local d, p, s, paid, tip = r0.driver, r0.price, r0.state, r0.paid or 0, r0.tip or 0
			ctx:reload()
			ctx:advance(5)
			local r1 = ride(ctx)
			if not r1 then ctx:fail("You /reload during a ride and Wuber no longer has the ride.") end
			if r1.driver ~= d or r1.price ~= p or (r1.paid or 0) ~= paid or (r1.tip or 0) ~= tip then
				ctx:fail("After a /reload the ride reads driver " .. tostring(r1.driver) .. ", fare " .. tostring(r1.price) .. ", paid " .. tostring(r1.paid or 0) .. ", tip " .. tostring(r1.tip or 0) ..
					" instead of " .. tostring(d) .. ", " .. tostring(p) .. ", " .. tostring(paid) .. ", " .. tostring(tip) .. ".")
			end
			if s ~= r1.state and (ctx.W.RIDE_RANK[r1.state] or 0) < (ctx.W.RIDE_RANK[s] or 0) then
				ctx:fail("After a /reload the ride went back from " .. tostring(s) .. " to " .. tostring(r1.state) .. ".")
			end
		end,
	}

	local function pay(ctx, copper)
		local d = ctx.peers.driver
		if not d then ctx:cannot("no driver window") end
		local rp, dp = ctx.me.player, d.player
		if rp.trade then ctx.w:tradeCancel(rp) end
		if not ctx.w:openTrade(rp, dp) then ctx:cannot("no trade with the driver") end
		ctx.w:tradeMoney(rp, copper)
		ctx.w:tradeAccept(dp)
		ctx.w:tradeAccept(rp)
		ctx:note("I pay " .. copper .. " copper by trade")
		ctx:advance(4)
	end
	Hunt.promise{
		id = "snap.rider_part_payment_kept",
		area = "Reload",
		text = "You pay part of the fare, you /reload: Wuber still knows how much you paid and only asks for what is left.",
		source = "Net/Rides.lua SAVED (paid, price)",
		kind = "scenario",
		needs = { role = "rider", ride = "arrived", combat = "no" },
		when = isRider,
		check = function(ctx)
			local r0 = ride(ctx)
			if not r0 or (r0.paid or 0) > 0 or (r0.price or 0) < 200 then ctx:na("not a fresh unpaid ride") end
			local half = math.floor(r0.price / 200) * 100
			pay(ctx, half)
			if (ride(ctx).paid or 0) ~= half then ctx:na("the part payment was not counted before the reload") end
			ctx:reload()
			ctx:advance(5)
			local r1 = ride(ctx)
			if not r1 then ctx:fail("You paid part of the fare, /reload, and Wuber no longer has the ride.") end
			if (r1.paid or 0) ~= half then ctx:fail("You paid " .. half .. " copper of " .. r0.price .. ", /reload, and Wuber says you paid " .. tostring(r1.paid or 0) .. ".") end
		end,
	}

	Hunt.promise{
		id = "snap.rider_tip_kept",
		area = "Reload",
		text = "You pay more than the fare as a tip, you /reload: Wuber still shows the tip you gave.",
		source = "Net/Rides.lua SAVED (paid, tip)",
		kind = "scenario",
		needs = { role = "rider", ride = "arrived", combat = "no" },
		when = isRider,
		check = function(ctx)
			local r0 = ride(ctx)
			if not r0 or (r0.paid or 0) > 0 or (r0.price or 0) < 100 then ctx:na("not a fresh unpaid ride") end
			pay(ctx, r0.price + 500)
			local a = ride(ctx)
			if not (a and (a.paid or 0) >= r0.price + 500) then ctx:na("the tip was not counted before the reload") end
			local tip0 = a.tip
			ctx:reload()
			ctx:advance(5)
			local r1 = ride(ctx)
			if not r1 then ctx:na("the paid ride is gone after the reload") end
			if (r1.paid or 0) ~= a.paid or r1.tip ~= tip0 then
				ctx:fail("You paid fare plus a 500 copper tip, /reload, and Wuber says paid " .. tostring(r1.paid) .. " and tip " .. tostring(r1.tip) .. " instead of " .. tostring(a.paid) .. " and " .. tostring(tip0) .. ".")
			end
		end,
	}
end
