-- Promises about "Skip the bird" (owner CORE: the starter set). From what the player was told: Settings > Riding >
-- Flight master tip ("When you open a flight master's map and an open driver summons somewhere you could fly to,
-- faster, a small card beside the map says so"), and round 26 (the card shows when the flight is longer than the
-- summon wait, 2 minutes).
-- Stand-in: the check builds the flight-master state itself (a real driver window advertising from Orgrimmar, my
-- player at Thunder Bluff's flight master), so it does not depend on the world dial's flight map.
return function(Hunt)
	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		if type(want) == "table" then return want[v] == true end
		return v == want
	end

	local DRIVERS = { "Mia Runner", "Bea Jones", "Cal Brown", "Dee Price" }

	Hunt.promise{
		id = "bird.skip_card",
		area = "Bird",
		text = "At a flight master, when a Wuber driver is open at a place you can fly to and the flight takes longer than the summon wait, the Skip the bird card shows.",
		source = "Settings > Riding > Flight master tip; round 26 (flights longer than the 2 min wait)",
		kind = "scenario",
		when = function(sit)
			return is(sit, "place", "town") and is(sit, "ride", "none") and is(sit, "combat", "no") and sit.birdTip ~= "off"
				and is(sit, "phone", { closed = true, home = true, splash = true })
		end,
		check = function(ctx)
			local W = ctx.W
			local Bird = ctx:mod("UI.Bird")
			if not (Bird and type(Bird.Card) == "function") then ctx:cannot("this Wuber has no Skip the bird card (UI.Bird)") end
			if ctx.me.player.combat then ctx:na("in combat") end
			if type(W.db) == "table" and W.db.birdTip == false then ctx:na("the Flight master tip is off") end
			local K = ctx:mod("UI.Kit")
			if K and type(K.rideActive) == "function" then
				local ok, active = pcall(K.rideActive)
				if ok and active then ctx:na("a ride is on") end
			end
			-- a Wuber driver opens for business in Orgrimmar (another window: its beacon reaches me by addon message)
			local name
			for _, n in ipairs(DRIVERS) do if not ctx.w:player(n) then name = n break end end
			if not name then ctx:cannot("no free name for the driver") end
			local d = ctx.w:addClient(name, { spot = "Orgrimmar", class = "WARLOCK" })
			ctx.peers.birdDriver = d
			if d.W.Char then d.W.Char().wizard = true end
			if not (d.W.Driver and type(d.W.Driver.SetOnline) == "function") then ctx:cannot("the driver window has no Driver.SetOnline") end
			if d.W.Driver.SetOnline(true) == false then ctx:cannot("the driver could not go online") end
			ctx:note(name .. " opens in Orgrimmar")
			ctx:advance(15)
			local key = name:lower()
			local heard = type(W.drivers) == "table" and W.drivers[key]
			if not heard then ctx:cannot("the driver's beacon never reached me (W.drivers has no " .. key .. ")") end
			-- I stand at Thunder Bluff's flight master and open the map: Orgrimmar is a place I can fly to (about 3 min)
			ctx.w:move(ctx.name, "Thunder Bluff")
			ctx:advance(1)
			ctx.facts.flightSecs = 197
			ctx.w:openTaxiMap(ctx.me, { { name = "Thunder Bluff, Mulgore", type = "CURRENT" },
				{ name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50 } })
			ctx:note("open the flight map at Thunder Bluff")
			ctx:advance(0.6)
			local c = Bird.Card()
			if c and ctx:visible(c) then return end
			ctx:advance(1)
			c = Bird.Card()
			if c and ctx:visible(c) then return end
			ctx:fail("At the Thunder Bluff flight master, with a Wuber driver open in Orgrimmar and a 3-minute flight, no Skip the bird card shows.",
				("the driver heard: dest %s, state %s; on screen: %s"):format(tostring(heard.dest), tostring(heard.state), table.concat(ctx:texts(), " | ")))
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- More promises about the Skip the bird card (owner MAPS/FLIGHTS/TRIPS). From the Settings tooltip ("Never over the
	-- map, never in combat or during a ride, at most once each time you open it"), the card's own words and tooltips, the
	-- 2.3.3 changelog ("shows on every flight-map open where a summon beats flying, ... stays up for 10 seconds, its Don't
	-- show again says where to turn it back on") and BRIEF26 item 2 (also just after a ride).
	---------------------------------------------------------------------------------------------------------------
	local function plain(s) return (tostring(s or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	local function plainTexts(ctx)
		local out = {}
		for _, t in ipairs(ctx:texts()) do out[#out + 1] = plain(t) end
		return out
	end
	local function onScreen(ctx) return "on screen: " .. table.concat(plainTexts(ctx), " | ") end

	local function birdMod(ctx)
		local Bird = ctx:mod("UI.Bird")
		if not (Bird and type(Bird.Card) == "function") then ctx:cannot("this Wuber has no Skip the bird card (UI.Bird)") end
		return Bird
	end

	-- A Wuber driver opens in Orgrimmar (another window); I stand at Thunder Bluff's flight master. Returns the
	-- driver's name and key. The flight map is not opened here (open(ctx) does it).
	local function stage(ctx)
		local name
		for _, n in ipairs(DRIVERS) do if not ctx.w:player(n) then name = n break end end
		if not name then ctx:cannot("no free name for the driver") end
		local d = ctx.w:addClient(name, { spot = "Orgrimmar", class = "WARLOCK" })
		ctx.peers.birdDriver = d
		if d.W.Char then d.W.Char().wizard = true end
		if not (d.W.Driver and type(d.W.Driver.SetOnline) == "function") then ctx:cannot("the driver window has no Driver.SetOnline") end
		if d.W.Driver.SetOnline(true) == false then ctx:cannot("the driver could not go online") end
		ctx:note(name .. " opens in Orgrimmar")
		ctx:advance(15)
		local key = name:lower()
		if not (type(ctx.W.drivers) == "table" and ctx.W.drivers[key]) then ctx:cannot("the driver's beacon never reached me") end
		ctx.w:move(ctx.name, "Thunder Bluff")
		ctx:advance(1)
		return name, key
	end
	local function openMap(ctx)
		ctx.w:openTaxiMap(ctx.me, { { name = "Thunder Bluff, Mulgore", type = "CURRENT" },
			{ name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50 } })
		ctx:note("open the flight map at Thunder Bluff")
		ctx:advance(0.8)
	end
	local function closeMap(ctx)
		ctx.w:closeTaxiMap(ctx.me)
		ctx:note("close the flight map")
		ctx:advance(0.5)
	end
	local function cardUp(ctx, Bird)
		local c = Bird.Card()
		if c and ctx:visible(c) then return c end
		return nil
	end
	-- First tap as a player makes it: tap away the cards that can sit on top (the What's new card's Got it, the first-run
	-- tip sheet's x) before reaching for the Skip the bird card.
	local function clearCards(ctx)
		for _ = 1, 4 do
			local hit = false
			local Tips = ctx:mod("UI.Tips")
			local tc = Tips and type(Tips.Card) == "function" and Tips.Card()
			if tc and tc.close and ctx:visible(tc.close) then
				ctx.me:clickOn(tc.close) ctx:note("tap the tip sheet's close") ctx:advance(0.6) hit = true
			end
			local b = ctx.me:button("Got it")
			if b and ctx:visible(b) then ctx.me:clickOn(b) ctx:note("tap Got it") ctx:advance(0.5) hit = true end
			if not hit then break end
		end
	end
	-- the common conditions of the promises that need the tip on
	local function gate(ctx)
		if ctx.me.player.combat then ctx:na("in combat") end
		if type(ctx.W.db) == "table" and ctx.W.db.birdTip == false then ctx:na("the Flight master tip is off") end
		local K = ctx:mod("UI.Kit")
		if K and type(K.rideActive) == "function" then
			local ok, active = pcall(K.rideActive)
			if ok and active then ctx:na("a ride is on") end
		end
	end
	local function tipOnNoRide(sit)
		return is(sit, "place", "town") and is(sit, "ride", "none") and is(sit, "combat", "no") and sit.birdTip ~= "off"
			and is(sit, "phone", { closed = true, home = true, splash = true })
	end

	Hunt.promise{
		id = "bird.every_open",
		area = "Bird",
		text = "The Skip the bird card shows every time you open the flight map where a summon beats flying, not only the first time.",
		source = "CHANGELOG 2.3.3 (shows on every flight-map open where a summon beats flying); BRIEF25 B1",
		kind = "scenario",
		when = tipOnNoRide,
		check = function(ctx)
			gate(ctx)
			local Bird = birdMod(ctx)
			stage(ctx)
			for round = 1, 3 do
				openMap(ctx)
				if not cardUp(ctx, Bird) then
					ctx:fail(("You open the flight map %s time at Thunder Bluff with a Wuber driver open in Orgrimmar and the Skip the bird card does not show."):format(({ "the first", "the second", "the third" })[round]), onScreen(ctx))
				end
				closeMap(ctx)
			end
		end,
	}

	Hunt.promise{
		id = "bird.says_the_numbers",
		area = "Bird",
		text = "The Skip the bird card shows the summon and flight times on its first line, and names the driver, the place and the summon's price on its second line.",
		source = "UI.Bird.Show (Summon <wait>. Fly <time>. / <driver> · <place> · <price>)",
		kind = "scenario",
		when = tipOnNoRide,
		check = function(ctx)
			gate(ctx)
			local Bird = birdMod(ctx)
			local name, key = stage(ctx)
			openMap(ctx)
			local c = cardUp(ctx, Bird)
			if not c then ctx:na("no card showed (bird.skip_card says so)") end
			local line1 = plain(c.text:GetText())
			local line2 = plain(c.sub and c.sub:GetText() or "")
			local d = c.key and ctx.W.UI.Driver(c.key) or nil
			if not d then ctx:cannot("the card names no driver") end
			if not line1:find("Summon ", 1, true) or not line1:find("Fly ", 1, true) then
				ctx:fail("The Skip the bird card does not show the summon and flight times.", "line1: " .. line1)
			end
			if not line1:find("%d+ ?sec") and not line1:find("%d+ ?s") and not line1:find("%d+ ?min") and not line1:find("%d+ ?h") then
				ctx:fail("The Skip the bird card does not say how long the flight takes.", "line1: " .. line1)
			end
			for _, need in ipairs({ d.short, d.dest }) do
				if not line2:find(need, 1, true) then
					ctx:fail(("The Skip the bird card does not say '%s'."):format(need), "line2: " .. line2)
				end
			end
			if d and d.price then
				local price = plain(ctx.W.Money(d.price))
				if not line2:find(price, 1, true) then ctx:fail("The Skip the bird card does not say what the summon costs.", "wanted " .. price .. "; line2: " .. line2) end
			end
			-- (2.4.2 merge) the tooltip check went with the hunt's F010 mend (the promise no longer names the tooltip); its
			-- leftover read of an unset 'tip' made every run a broken check
		end,
	}

	Hunt.promise{
		id = "bird.beside_the_map",
		area = "Bird",
		text = "The Skip the bird card is beside the flight map, never over it, and fully on the screen.",
		source = "Settings > Riding > Flight master tip tooltip (never over the map); CHANGELOG 2.3.3",
		kind = "scenario",
		when = function(sit) return tipOnNoRide(sit) end,
		check = function(ctx)
			gate(ctx)
			local Bird = birdMod(ctx)
			stage(ctx)
			openMap(ctx)
			local c = cardUp(ctx, Bird)
			if not c then ctx:na("no card showed (bird.skip_card says so)") end
			local env = ctx.me.env
			local map = (env.TaxiFrame and env.TaxiFrame:IsShown() and env.TaxiFrame) or (env.FlightMapFrame and env.FlightMapFrame:IsShown() and env.FlightMapFrame) or nil
			if not map then ctx:cannot("the flight map frame is not shown") end
			local function rect(f) return { l = f:GetLeft(), r = f:GetRight(), t = f:GetTop(), b = f:GetBottom() } end
			local a, m = rect(c), rect(map)
			local sw, sh = env.UIParent:GetWidth(), env.UIParent:GetHeight()
			if a.l < m.r - 0.5 and m.l < a.r - 0.5 and a.b < m.t - 0.5 and m.b < a.t - 0.5 then
				ctx:fail("The Skip the bird card sits on top of the flight map.", ("card %.0f %.0f %.0f %.0f over map %.0f %.0f %.0f %.0f"):format(a.l, a.b, a.r, a.t, m.l, m.b, m.r, m.t))
			end
			if a.l < -0.5 or a.b < -0.5 or a.r > sw + 0.5 or a.t > sh + 0.5 then
				ctx:fail("The Skip the bird card is partly off the screen.", ("card %.0f %.0f %.0f %.0f on a screen %.0f x %.0f"):format(a.l, a.b, a.r, a.t, sw, sh))
			end
		end,
	}

	Hunt.promise{
		id = "bird.off_means_off",
		area = "Bird",
		text = "With the Flight master tip switched off, the Skip the bird card never shows.",
		source = "Settings > Riding > Flight master tip",
		kind = "scenario",
		needs = { birdTip = "off" },
		when = function(sit) return is(sit, "ride", "none") and is(sit, "combat", "no") and sit.session ~= "first" end,
		check = function(ctx)
			local Bird = birdMod(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			if not (type(ctx.W.db) == "table" and ctx.W.db.birdTip == false) then ctx:cannot("the saved birdTip = false did not reach Wuber") end
			stage(ctx)
			openMap(ctx)
			if cardUp(ctx, Bird) then ctx:fail("You switched the Flight master tip off and the Skip the bird card shows at the flight master.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "bird.short_flight_no_card",
		area = "Bird",
		text = "When the flight does not beat the driver's summon wait by at least a minute, there is no Skip the bird card.",
		source = "UI.Bird.Pick (secs - UI.SummonWait(d) >= 60; W.SUMMON_SECS = 30 or driver's average)",
		kind = "scenario",
		when = tipOnNoRide,
		check = function(ctx)
			gate(ctx)
			local Bird = birdMod(ctx)
			stage(ctx)
			-- a 45-second flight to Orgrimmar does not beat the 30-second summon wait by a minute
			ctx.W.FlightTime = function() return 45, "own" end
			openMap(ctx)
			if cardUp(ctx, Bird) then
				ctx:fail("A 45-second flight to Orgrimmar and a driver there, and the Skip the bird card tells you to skip the bird.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "bird.none_in_combat",
		area = "Bird",
		text = "You never see the Skip the bird card while you are in combat.",
		source = "Settings > Riding > Flight master tip tooltip (never in combat)",
		kind = "scenario",
		when = function(sit) return is(sit, "place", "town") and is(sit, "ride", "none") and sit.birdTip ~= "off" and is(sit, "phone", { closed = true, home = true, splash = true }) end,
		check = function(ctx)
			local Bird = birdMod(ctx)
			if type(ctx.W.db) == "table" and ctx.W.db.birdTip == false then ctx:na("the Flight master tip is off") end
			stage(ctx)
			if not ctx.me.player.combat then ctx.w:enterCombat(ctx.me) ctx:note("enter combat") end
			openMap(ctx)
			ctx:advance(1)
			if cardUp(ctx, Bird) then ctx:fail("You are in combat, open the flight map, and the Skip the bird card shows.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "bird.none_during_ride",
		area = "Bird",
		text = "While a ride of yours is under way (requested, invited or summoning), the Skip the bird card does not show.",
		source = "Settings > Riding > Flight master tip tooltip (never ... during a ride)",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return is(sit, "ride", { requested = true, invited = true, summoning = true }) and is(sit, "place", "town") and is(sit, "combat", "no") and sit.birdTip ~= "off" end,
		check = function(ctx)
			local Bird = birdMod(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			if type(ctx.W.db) == "table" and ctx.W.db.birdTip == false then ctx:na("the Flight master tip is off") end
			local K = ctx:mod("UI.Kit")
			local ok, active = pcall(K.rideActive)
			if not (ok and active) then ctx:na("no ride is on") end
			local state = ctx.facts.rideState
			stage(ctx)
			openMap(ctx)
			if cardUp(ctx, Bird) then
				ctx:fail(("You have a ride on (%s), open the flight map, and the Skip the bird card shows."):format(tostring(state)), onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "bird.after_a_ride",
		area = "Bird",
		text = "Just after you have paid for a ride, the Skip the bird card shows again at the next flight master where a summon beats flying.",
		source = "BRIEF26 item 2 (including when the rider has just finished a ride)",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return is(sit, "ride", { paid = true, ended = true }) and is(sit, "place", "town") and is(sit, "combat", "no") and sit.birdTip ~= "off" end,
		check = function(ctx)
			gate(ctx)
			local Bird = birdMod(ctx)
			stage(ctx)
			openMap(ctx)
			if not cardUp(ctx, Bird) then
				ctx:fail("You have just paid for a ride, open the flight map at Thunder Bluff with a Wuber driver open in Orgrimmar, and no Skip the bird card shows.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "bird.card_buttons",
		area = "Bird",
		text = "On the Skip the bird card, the close button only hides it, Don't show again turns the tip off and says where to turn it back on (Settings > Riding > Flight offers), and clicking the card opens the booking screen with the flight map still open.",
		source = "CHANGELOG 2.3.3 (Don't show again says where to turn it back on); the card's tooltips",
		kind = "scenario",
		when = tipOnNoRide,
		check = function(ctx)
			gate(ctx)
			local Bird = birdMod(ctx)
			local name, key = stage(ctx)
			-- 1. the close button
			openMap(ctx)
			clearCards(ctx)
			local c = cardUp(ctx, Bird)
			if not c then ctx:na("no card showed (bird.skip_card says so)") end
			ctx.me:clickOn(c.x)
			ctx:note("click the card's close button")
			ctx:advance(0.6)
			if cardUp(ctx, Bird) then ctx:fail("You click the close button on the Skip the bird card and it stays.", onScreen(ctx)) end
			if ctx.W.db.birdTip == false then ctx:fail("You close the Skip the bird card with its close button and the Flight master tip is switched off for good.", "birdTip is off") end
			closeMap(ctx)
			-- 2. clicking the card
			openMap(ctx)
			clearCards(ctx)
			c = cardUp(ctx, Bird)
			if not c then ctx:fail("You closed the Skip the bird card once and it never comes back when you open the flight map again.", onScreen(ctx)) end
			ctx.me:clickOn(c)
			ctx:note("click the card")
			ctx:advance(1)
			local K = ctx:mod("UI.Kit")
			if not (K and K.ui and K.ui.screen == "confirm") then
				ctx:fail("You click the Skip the bird card and the booking screen does not open.", "now on " .. tostring(K and K.ui and K.ui.screen) .. "; " .. onScreen(ctx))
			end
			if not (ctx.me.env.TaxiFrame and ctx.me.env.TaxiFrame:IsShown()) then
				ctx:fail("You click the Skip the bird card and the flight map closes.", onScreen(ctx))
			end
			closeMap(ctx)
			-- 3. Don't show again
			openMap(ctx)
			clearCards(ctx)
			c = cardUp(ctx, Bird)
			if not c then ctx:na("the card did not come back after a click (skip_card says so)") end
			ctx.me:clickOn(c.never)
			ctx:note("click Don't show again")
			ctx:advance(0.6)
			if ctx.W.db.birdTip ~= false then ctx:fail("You click Don't show again on the Skip the bird card and the Flight master tip stays on.", onScreen(ctx)) end
			local told = false
			for _, t in ipairs(plainTexts(ctx)) do if t:find("Settings > Riding > Flight offers", 1, true) then told = true end end
			if not told then ctx:fail("You click Don't show again and Wuber does not tell you where to turn the tip back on.", onScreen(ctx)) end
			closeMap(ctx)
			openMap(ctx)
			if cardUp(ctx, Bird) then ctx:fail("You clicked Don't show again and the Skip the bird card comes back at the next flight map.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "bird.goes_by_itself",
		area = "Bird",
		text = "The Skip the bird card stays up until you close it or close the flight map (no timer hides it), and it goes at once when you close the flight map.",
		source = "UI.Bird (no timed hide; stays until closed or TAXIMAP_CLOSED)",
		kind = "scenario",
		when = tipOnNoRide,
		check = function(ctx)
			gate(ctx)
			local Bird = birdMod(ctx)
			stage(ctx)
			openMap(ctx)
			if not cardUp(ctx, Bird) then ctx:na("no card showed (bird.skip_card says so)") end
			ctx:advance(12)
			if not cardUp(ctx, Bird) then ctx:fail("The Skip the bird card went away by itself after twelve seconds while the flight map was still open.", onScreen(ctx)) end
			closeMap(ctx)
			if cardUp(ctx, Bird) then ctx:fail("You close the flight map and the Skip the bird card stays on the screen.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "bird.no_empty_saving",
		area = "Bird",
		text = "When flying costs exactly what the summon costs, the Skip the bird card does not say the summon saves 'free' or nothing of gold.",
		source = "CHANGELOG 2.3.3 (the card spells out the saving); inferred (a card must make sense)",
		kind = "scenario",
		when = tipOnNoRide,
		check = function(ctx)
			gate(ctx)
			local Bird = birdMod(ctx)
			stage(ctx)
			-- the flight master's price is the same as each driver's price (as the real table could be)
			local W = ctx.W
			W.FlightCost = function(_, to)
				for _, d in ipairs(W.UI.Drivers()) do
					if type(d.dest) == "string" and type(to) == "string" and d.dest:lower() == to:lower() then return d.price, 1, "own" end
				end
				return nil
			end
			openMap(ctx)
			local c = cardUp(ctx, Bird)
			if not c then ctx:na("no card showed") end
			local text = plain(c.text:GetText())
			if text:find("saves[%w%s]-free") or text:find("saves[%w%s]- 0[gsc]") then
				ctx:fail("The summon costs the same as flying and the Skip the bird card says the summon saves 'free' of gold.", "card: " .. text)
			end
		end,
	}
end
