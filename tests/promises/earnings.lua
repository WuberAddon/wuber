-- Promises about the driver's MONEY: the Earnings screen, the earnings log, the end-of-shift card, the stats.
-- (owner crewearn). Written from what a driver is told: Earnings tooltips ("Gold earned divided by the hours you
-- were open", "Sets the ride and gold counters back to zero (click twice). The hour-by-hour log stays for the
-- heatmap", "Every ride your crew took, whoever was paid", "Rainchecks: given n . used n"), the Shift complete card,
-- CHANGELOG 2.3.x, and "every amount of gold shown must equal what the log holds".
return function(Hunt)

-- helpers shared by this crew's files (each file has its own copy: a file owner edits only its own)
local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")) end
-- money written with the game's coin icons or as 1g 2s 3c: every amount in a text, in copper
local function amounts(text)
	local t = tostring(text or "")
	t = t:gsub("(%d+)|TInterface\\MoneyFrame\\UI%-(%a+)Icon[^|]*|t", function(n, k) return n .. k:sub(1, 1):lower() end)
	t = strip(t)
	local out, pos = {}, 1
	while true do
		local s1, e1, n1, u1 = t:find("(%d+)([gsc])%f[%A]", pos)
		if not s1 then break end
		local sum, cur = 0, e1
		local mult = { g = 10000, s = 100, c = 1 }
		sum = sum + tonumber(n1) * mult[u1]
		while true do
			local s2, e2, n2, u2 = t:find("^%s?(%d+)([gsc])%f[%A]", cur + 1)
			if not s2 then break end
			sum = sum + tonumber(n2) * mult[u2]
			cur = e2
		end
		out[#out + 1] = sum
		pos = cur + 1
	end
	return out
end
local function say(ctx, fmt, ...) ctx:fail((select("#", ...) > 0 and fmt:format(...) or fmt)) end
local function texts(ctx) return ctx:texts() end
local function find(ctx, pat) for _, t in ipairs(ctx:texts()) do local p = strip(t) if p:find(pat) then return p, t end end return nil end
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

	local function dr(ctx) return ctx.W.Drive end
	local function logOf(ctx) local d = ctx.W.db and ctx.W.db.drive return d and d.log end
	local function env(ctx) return ctx.me.env end

	local function midnight(ctx)
		local t = env(ctx).time()
		local d = env(ctx).date("*t", t)
		return t - (d.hour * 3600 + d.min * 60 + d.sec)
	end

	-- what the log holds since `since`: rides, copper (my payments), and the crew's too
	local function logHolds(ctx, since, withTeam)
		local l = logOf(ctx)
		local rides, copper = 0, 0
		if not l then return 0, 0 end
		for _, list in ipairs(withTeam and { l.rides or {}, l.team or {} } or { l.rides or {} }) do
			for _, line in ipairs(list) do
				local at, c = tostring(line):match("^(%d+),(%d+),")
				if at and tonumber(at) >= since then rides, copper = rides + 1, copper + tonumber(c) end
			end
		end
		return rides, copper
	end

	-- the Earnings screen's totals line: "1 ride . 50s . 0 min open . 0 buyers asked" -> rides, copper (first amount)
	local function shown(ctx)
		local p, raw = find(ctx, "^%d+ rides? ")
		if not p then return nil end
		local n = tonumber(p:match("^(%d+)"))
		local seg = raw:match("^%d+ rides? [^%d]*(.-) open") or raw
		local first = raw:gsub("%(.-tips%)", "")
		local am = amounts(first)
		return n, am[1] or 0, p
	end

	local function onEarnings(ctx)
		if not find(ctx, "^Earnings$") and not find(ctx, "per open hour") then
			ctx:cannot("the Earnings screen is not up")
		end
	end

	-- the Me | Crew choice on the Earnings dashboard
	local function whoShown(ctx)
		local S = ctx:mod("UI.Driver.Screens")
		local e = S and S.st and S.st.screens and S.st.screens.earnings
		if not (e and e.who) then ctx:cannot("no Me | Crew control found") end
		return ctx:visible(e.who) == true
	end

	local function clickWho(ctx, i)
		local S = ctx:mod("UI.Driver.Screens")
		local e = S.st.screens.earnings
		ctx.me:clickOn(e.who.buttons[i])
		ctx:note("click " .. (i == 2 and "Crew" or "Me") .. " on Earnings")
	end

	local function isDriver(sit) return sit.role == "warlock" or sit.role == "friend" or sit.role == "crew" end

	Hunt.promise{
		id = "earnings.total_matches_log",
		area = "Earnings",
		text = "The rides and gold in the Earnings screen's Today line are exactly the rides and gold your earnings log holds for today.",
		source = "tooltip (Gold per open hour); inferred: every amount of gold shown must equal what the log holds",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			onEarnings(ctx)
			local n, c, line = shown(ctx)
			if not n then ctx:fail("You open Earnings and there is no totals line (rides, gold, minutes open).") end
			local er, ec = logHolds(ctx, midnight(ctx), false)
			if n ~= er or c ~= ec then
				say(ctx, "You open Earnings: it says %d rides and %s today but your earnings log holds %d rides and %s (line: %s).", n, ctx.W.Money(c), er, ctx.W.Money(ec), line)
			end
		end,
	}

	-- the rider (a window) pays the whole fare by trade, as a player does
	local function riderPays(ctx)
		local w = ctx.w
		local rider = ctx.peers.rider
		if not rider then ctx:cannot("no rider window") end
		local rp, pp = rider.player, w:player(ctx.name)
		local tr = rp.trade
		if tr and not (tr.a == pp or tr.b == pp) then w:tradeCancel(rp) tr = nil end
		if not tr and not w:openTrade(pp, rp) then ctx:cannot("no trade between me and the rider") end
		local fare = rider.W.ride and rider.W.ride.price
		if not fare then ctx:cannot("the rider has no ride") end
		w:tradeMoney(rp, fare)
		w:tradeAccept(pp)
		w:tradeAccept(rider.player)
		waitFor(ctx, function() return rider.W.ride and (rider.W.ride.paid or 0) >= fare end, 4, 0.1)
		ctx:note("the rider pays " .. fare .. " copper by trade")
		ctx:advance(3)
		return fare
	end

	local function statsLine(ctx, which)
		local before = #ctx.me.chatLines
		ctx.me:slash("/wuber drive stats")
		local rides, copper
		for i = before + 1, #ctx.me.chatLines do
			local l = strip(ctx.me.chatLines[i])
			local r, rest = l:match(which .. ": (%d+) rides?, (.*)%.$")
			if r then rides, copper = tonumber(r), amounts(rest)[1] or 0 end
		end
		return rides, copper
	end

	Hunt.promise{
		id = "earnings.payment_counted",
		area = "Earnings",
		text = "When a rider pays you by trade while Earnings is open, the same ride and the same gold show in Today, in /wuber stats and in the earnings log.",
		source = "tooltip (Earnings); CHANGELOG 2.3.2; inferred",
		kind = "scenario",
		needs = { phone = "drive_earnings", ride = "arrived" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			onEarnings(ctx)
			local n0, c0 = shown(ctx)
			local s0, sc0 = statsLine(ctx, "This session")
			local l0 = #(logOf(ctx).rides or {})
			local fare = riderPays(ctx)
			local n1, c1, line = shown(ctx)
			if not n1 then ctx:fail("A rider pays you and the Earnings screen no longer shows a totals line.") end
			if n1 ~= (n0 or 0) + 1 or c1 ~= (c0 or 0) + fare then
				say(ctx, "A rider pays you %s by trade while Earnings is open and the Today line says %d rides and %s (it said %d rides and %s before).", ctx.W.Money(fare), n1, ctx.W.Money(c1), n0 or 0, ctx.W.Money(c0 or 0))
			end
			local added = #(logOf(ctx).rides or {}) - l0
			if added ~= 1 then say(ctx, "A rider pays you %s by trade and your earnings log gained %d lines (one expected).", ctx.W.Money(fare), added) end
			local s1, sc1 = statsLine(ctx, "This session")
			if s0 and s1 and (s1 ~= s0 + 1 or sc1 ~= sc0 + fare) then
				say(ctx, "A rider pays you %s by trade and /wuber stats says %d rides, %s this session (it said %d rides, %s).", ctx.W.Money(fare), s1, ctx.W.Money(sc1), s0, ctx.W.Money(sc0))
			end
		end,
	}

	-- history a driver who has driven before has (saved data: a payment 3 days and 20 days ago)
	local function addHistory(ctx)
		local l = logOf(ctx)
		if not l then ctx:cannot("no log") end
		local t = env(ctx).time()
		table.insert(l.rides, (t - 3 * 86400) .. ",30000,Old Customer,Ratchet,t,30000")
		table.insert(l.rides, (t - 20 * 86400) .. ",50000,Older Customer,Ratchet,t,50000")
		ctx:note("saved history: a 3g ride 3 days ago and a 5g ride 20 days ago")
	end

	Hunt.promise{
		id = "earnings.ranges",
		area = "Earnings",
		text = "The Today, 7 days and 30 days buttons on Earnings change the totals to the rides and gold of that period.",
		source = "tooltips (Since midnight. / The last seven days. / The last thirty days.)",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			onEarnings(ctx)
			addHistory(ctx)
			local t = env(ctx).time()
			for _, r in ipairs({ { "7 days", 7 }, { "30 days", 30 }, { "Today", 0 } }) do
				do
					local S = ctx:mod("UI.Driver.Screens")
					local e = S.st.screens.earnings
					ctx.me:clickOn(e.seg.buttons[r[1] == "Today" and 1 or (r[1] == "7 days" and 2 or 3)])
				end
				ctx:note("click " .. r[1])
				ctx:advance(0.5)
				local since = r[2] == 0 and midnight(ctx) or (t - r[2] * 86400)
				local er, ec = logHolds(ctx, since, false)
				local n, c, line = shown(ctx)
				if not n then ctx:fail("You click " .. r[1] .. " on Earnings and the totals line goes.") end
				if n ~= er or c ~= ec then
					say(ctx, "You click %s on Earnings and it shows %d rides and %s but the log holds %d rides and %s for that period.", r[1], n, ctx.W.Money(c), er, ctx.W.Money(ec))
				end
			end
		end,
	}

	Hunt.promise{
		id = "earnings.reset_twice",
		area = "Earnings",
		text = "Reset stats asks you to click again; the second click sets this session's counters (and /wuber drive stats) back to zero rides and gold, and keeps the hour-by-hour log and the ever-on-this-account totals. (job 146: the ever totals stay after a reset, HUNT-15, Earnings.lua:653 tooltip.)",
		source = "tooltip (Reset stats)",
		kind = "scenario",
		needs = { phone = "drive_earnings", ride = "paid" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			onEarnings(ctx)
			local logBefore = #(logOf(ctx).rides or {})
			local sess0 = statsLine(ctx, "This session")
			local ever0 = statsLine(ctx, "Ever, on this account")
			if not sess0 or sess0 < 1 then ctx:na("no ride counted this session") end
			-- (job 146: a player closes the "What's new in Wuber 2.4" card first; it can lie over the button and take the click)
			if find(ctx, "What's new in Wuber") then
				pcall(function() ctx.me:clickText("Got it") end)
				ctx:advance(0.5)
			end
			-- (job 146: the button is at the bottom of the page, under the tab bar until a player scrolls down; the wheel is ScrollTo)
			do
				local Sc = ctx:mod("UI.Driver.Screens")
				local e = Sc and Sc.st and Sc.st.screens and Sc.st.screens.earnings
				if e and e.scroll and e.scroll.ScrollTo then
					pcall(e.scroll.ScrollTo, e.scroll, e.scroll.max or 0, true)
					ctx:advance(0.5)
					ctx:note("scroll Earnings to the bottom")
				end
			end
			ctx.me:clickText("Reset stats")
			ctx:advance(0.3)
			if not find(ctx, "Click again to reset") then ctx:fail("You click Reset stats once and it does not ask you to click again.") end
			if statsLine(ctx, "This session") ~= sess0 then ctx:fail("You click Reset stats once and the counters already changed.") end
			ctx.me:clickText("Click again to reset")
			ctx:advance(0.5)
			local s1, c1 = statsLine(ctx, "This session")
			local e1, ec1 = statsLine(ctx, "Ever, on this account")
			-- (job 146: only the session counters go to zero; "Ever, on this account" comes from the log and stays)
			if s1 ~= 0 or (c1 or 0) ~= 0 then
				say(ctx, "You click Reset stats twice and /wuber stats still says %s rides this session.", tostring(s1))
			end
			if ever0 and e1 ~= ever0 then
				ctx:note("ever-on-this-account rides went from " .. tostring(ever0) .. " to " .. tostring(e1) .. " (they come from the log, so they may change only if the log did)")
			end
			if #(logOf(ctx).rides or {}) ~= logBefore then ctx:fail("You click Reset stats twice and the hour-by-hour earnings log lost rides.") end
		end,
	}

	Hunt.promise{
		id = "earnings.crew_toggle",
		area = "Earnings",
		text = "Earnings offers Me and Crew only when you have crew mates; alone you see just your own totals.",
		source = "tooltip (Me / Crew: Every ride your crew took, whoever was paid)",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return isDriver(sit) end,
		check = function(ctx)
			onEarnings(ctx)
			local mates = 0
			for _, m in ipairs(dr(ctx).Crew() or {}) do if not m.me then mates = mates + 1 end end
			local hasToggle = whoShown(ctx)
			if mates > 0 and not hasToggle then say(ctx, "You have %d crew mates and Earnings offers no Me | Crew choice.", mates) end
			if mates == 0 and hasToggle then ctx:fail("You drive alone and Earnings offers a Crew choice.") end
		end,
	}

	Hunt.promise{
		id = "earnings.crew_view_total",
		area = "Earnings",
		text = "In the Crew view of Earnings the rides and gold are every ride your crew took, whoever was paid.",
		source = "tooltip (Crew: Every ride your crew took, whoever was paid)",
		kind = "scenario",
		needs = { phone = "drive_earnings", ride = "paid" },
		when = function(sit) return sit.role == "friend" or sit.role == "warlock" end,
		check = function(ctx)
			onEarnings(ctx)
			local hasToggle = whoShown(ctx)
			if not hasToggle then ctx:na("no crew mates: no Crew view") end
			clickWho(ctx, 2)
			ctx:advance(0.5)
			local n, c, line = shown(ctx)
			if not n then ctx:fail("You click Crew on Earnings and the totals line goes.") end
			local er, ec = logHolds(ctx, midnight(ctx), true)
			local fare = ctx.facts.paid
			if n ~= er or c ~= ec then
				say(ctx, "You click Crew on Earnings after a rider paid %s: it says %d rides and %s but your crew's takings today are %d rides and %s.", ctx.W.Money(fare or 0), n, ctx.W.Money(c), er, ctx.W.Money(ec))
			end
			if fare and (n < 1 or c < fare) then
				say(ctx, "A rider paid %s to your crew today and the Crew view of Earnings says %d rides and %s.", ctx.W.Money(fare), n, ctx.W.Money(c))
			end
		end,
	}

	Hunt.promise{
		id = "earnings.raincheck_given",
		area = "Earnings",
		text = "A rain check you gave shows on Earnings as Rainchecks: given 1.",
		source = "tooltip (Rainchecks); SPEC7 5.8",
		kind = "scenario",
		needs = { phone = "drive_earnings", ride = "raincheck" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			onEarnings(ctx)
			if not find(ctx, "^Rainchecks: given 1") then
				ctx:fail("You gave a rider a rain check (they took it) and Earnings does not say Rainchecks: given 1.")
			end
		end,
	}

	Hunt.promise{
		id = "earnings.open_minutes",
		area = "Earnings",
		text = "While you are open and not paused, Earnings counts the minutes you were open.",
		source = "tooltip (Gold per open hour: the hours you were open (not paused))",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return sit.role == "warlock" and (sit.ride or "none") == "none" and sit.day ~= "midnight_soon" and sit.day ~= "month_end_soon" and sit.day ~= "year_end_soon" end,
		check = function(ctx)
			onEarnings(ctx)
			local function minutes()
				local p = find(ctx, "^%d+ rides? ")
				if not p then return nil end
				local h, m = p:match("(%d+)h (%d+) min open")
				if h then return tonumber(h) * 60 + tonumber(m) end
				local mm = p:match("(%d+) min open")
				if mm then return tonumber(mm) end
				local hh = p:match("(%d+)h open")
				return hh and tonumber(hh) * 60 or nil
			end
			local m0 = minutes()
			if not m0 then ctx:cannot("no minutes on the totals line: " .. tostring(find(ctx, "^%d+ rides? "))) end
			if not dr(ctx).IsOpen() then ctx:na("not open") end
			ctx:advance(600)
			local m1 = minutes()
			if not m1 or m1 - m0 < 8 or m1 - m0 > 12 then
				say(ctx, "You stay open for ten minutes and Earnings shows %s minutes open (it showed %s).", tostring(m1 and (m1 - m0)), tostring(m0))
			end
		end,
	}

	Hunt.promise{
		id = "earnings.shift_card",
		area = "Earnings",
		text = "When you close after a paid ride, the Shift complete card shows the gold and the rides of that shift, as your log holds them.",
		source = "CHANGELOG 2.2.x (end-of-shift card); Sheets; inferred",
		kind = "scenario",
		needs = { phone = "drive", ride = "paid" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local l = logOf(ctx)
			local sh = l and l.shift
			if not (sh and sh.start) then ctx:cannot("no shift") end
			local ok = pcall(ctx.me.clickText, ctx.me, "^Close$", { pattern = true })
			if not ok then ctx:cannot("no Close button on the console") end
			ctx:advance(1)
			ctx:note("click Close")
			local env = ctx.me and ctx.me.env
			if env and env.StaticPopup_FindVisible and env.StaticPopup_FindVisible("WUBER_CLOSE_RIDERS") then
				local dlg = env.StaticPopupDialogs and env.StaticPopupDialogs.WUBER_CLOSE_RIDERS
				env.StaticPopup_Hide("WUBER_CLOSE_RIDERS")
				if dlg and dlg.OnAccept then dlg.OnAccept() end
				ctx:advance(1)
			end
			-- what the log holds for the shift: payments from its start to its stop
			local rides, copper = 0, 0
			for _, line in ipairs(logOf(ctx).rides or {}) do
				local at, c = tostring(line):match("^(%d+),(%d+),")
				if at and tonumber(at) >= sh.start and tonumber(at) <= (sh.stop or env(ctx).time()) then rides, copper = rides + 1, copper + tonumber(c) end
			end
			if rides < 1 then ctx:na("no ride in this shift") end
			if not find(ctx, "Shift complete") then
				ctx:fail(("You close after a shift with %d paid ride(s) and no Shift complete card shows."):format(rides))
			end
			local gold
			do
				local S = ctx:mod("UI.Driver.Screens")
				local card = S and S.st and S.st.screens and S.st.screens.shift
				if not (card and card.gold) then ctx:cannot("no Shift complete card found") end
				gold = amounts(card.gold:GetText() or "")[1]
			end
			if gold ~= copper then
				say(ctx, "You close after %d paid ride(s) worth %s and the Shift complete card says %s.", rides, ctx.W.Money(copper), gold and ctx.W.Money(gold) or "nothing")
			end
		end,
	}
end
