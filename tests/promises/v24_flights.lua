-- Promises about flight prices (job 146, owner FLIGHT PRICES): the price tags on the flight master's map and the
-- mid-flight offer. Logic and numbers only: what number is shown, which driver it names, what a click does, how many times.
-- What the player is told (FlightPins and InFlight headers, the Flight offers tooltip, CHANGELOG 2.4.0): "a flight master's
-- map shows a price tag beside each place an open driver summons to, and while you fly Wuber may offer a faster summon, once
-- a flight"; the tag is the driver's price; the card says "Book . <price>" and "You still click Request yourself".
return function(Hunt)
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function isRider(sit) return sit.role == nil or sit.role == "rider" end
	local function onMap(sit)
		return isRider(sit) and (sit.net == nil or sit.net == "one" or sit.net == "many") and (sit.place == nil or sit.place == "town")
			and (sit.combat == nil or sit.combat == "no")
	end
	local function must(ctx, v, why) if not v then ctx:cannot("fprice: " .. why) end end
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
	local KNOWN = { "Ratchet", "Crossroads", "Gadgetzan", "Everlook", "Orgrimmar" }
	local function pinsMod(ctx)
		local m = ctx:mod("UI.FlightPins")
		if not m then ctx:cannot("this Wuber has no UI.FlightPins") end
		return m
	end
	local function flightMod(ctx)
		local m = ctx:mod("UI.InFlight")
		if not m then ctx:cannot("this Wuber has no UI.InFlight") end
		return m
	end
	local function nodes(ctx)
		return ctx.H.realTaxi("Kalimdor", "Thunder Bluff", { known = KNOWN })
	end
	local function slotOf(list, town)
		for i, n in ipairs(list) do if (n.name:match("^([^,]+)") or n.name) == town then return i end end
	end
	local function openMap(ctx)
		if ctx.me.player.combat then ctx:na("in combat") end
		ctx.w:move(ctx.name, "Thunder Bluff")
		ctx:advance(1)
		ctx.w:closeTaxiMap(ctx.me)
		ctx.w:openTaxiMap(ctx.me, nodes(ctx))
		ctx:note("open the flight map at Thunder Bluff")
		ctx:advance(0.6)
	end
	local function head(node) return (tostring(node):match("^([^,]+)") or tostring(node)) end
	local function driverFacts(ctx)
		local f = ctx.facts.drivers
		must(ctx, f and #f > 0, "no driver in this situation")
		must(ctx, ctx.peers.drivers and #ctx.peers.drivers == #f, "the driver windows are missing")
		return f
	end
	local function factAt(ctx, town)
		for i, d in ipairs(ctx.facts.drivers or {}) do
			if d.dest == town then return d, ctx.peers.drivers[i] end
		end
	end
	local function seenList(ctx)
		return table.concat(ctx:texts(), " | ")
	end

	---------------------------------------------------------------------------
	-- The flight map
	---------------------------------------------------------------------------
	Hunt.promise{
		id = "fprice.tag_is_price",
		area = "Flight prices",
		text = "At a flight master, each place an open driver summons to carries a price tag, and the number is that driver's real price.",
		source = "FlightPins header; Flight offers tooltip (a price tag beside each place an open driver summons to)",
		kind = "scenario",
		needs = { ride = "none" },
		when = onMap,
		check = function(ctx)
			driverFacts(ctx)
			local M = pinsMod(ctx)
			openMap(ctx)
			local pins = M.Pins()
			local want = 0
			for _, d in ipairs(ctx.facts.drivers) do
				for _, k in ipairs(KNOWN) do if d.dest == k then want = want + 1 end end
				if d.dest == "Thunder Bluff" then want = want + 1 end -- the map's own town is on it too
			end
			for _, p in ipairs(pins) do
				local f, fc = factAt(ctx, head(p.node))
				if f and fc then f = { name = f.name, price = fc.W.Char().price } end -- his real price now (his shop may have raised a too-low one to the minimum)
				if not f then ctx:fail("The flight map shows a price tag at " .. head(p.node) .. " but no driver summons there.", seenList(ctx)) end
				if p.price ~= f.price then
					ctx:fail("The flight map tag at " .. head(p.node) .. " says " .. ctx.W.Money(p.price) .. " but that driver's price is " .. ctx.W.Money(f.price) .. ".", seenList(ctx))
				end
				if p.tag and ctx:visible(p.tag) then
					local txt = p.tag.text and p.tag.text:GetText() or ""
					if not tostring(txt):find(ctx.W.Money(f.price), 1, true) then
						ctx:fail("The tag at " .. head(p.node) .. " reads " .. tostring(txt) .. " not " .. ctx.W.Money(f.price) .. ".", seenList(ctx))
					end
				end
			end
			if #pins ~= want then
				ctx:fail("An open driver summons to " .. want .. " places on this flight map and it shows " .. #pins .. " price tags.", seenList(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "fprice.closed_no_tag",
		area = "Flight prices",
		text = "A driver who has closed his shop has no price tag on the flight map.",
		source = "FlightPins (state open only); Flight offers tooltip (an open driver)",
		kind = "scenario",
		needs = { ride = "none" },
		when = onMap,
		check = function(ctx)
			driverFacts(ctx)
			local M = pinsMod(ctx)
			local town
			for _, d in ipairs(ctx.facts.drivers) do
				for _, k in ipairs(KNOWN) do if d.dest == k and not town then town = k end end
			end
			must(ctx, town, "no driver at a place on this map")
			local f, c = factAt(ctx, town)
			openMap(ctx)
			local had
			for _, p in ipairs(M.Pins()) do if head(p.node) == town then had = true end end
			must(ctx, had, "the driver had no tag to begin with")
			c.W.Drive.SetOpen(false)
			ctx:note(f.name .. " closes his shop")
			ctx:advance(8)
			openMap(ctx)
			for _, p in ipairs(M.Pins()) do
				if head(p.node) == town and p.driver == key(f.name) then
					ctx:fail("A driver closed his shop and the flight map still has his price tag at " .. town .. ".", seenList(ctx))
				end
			end
		end,
	}

	Hunt.promise{
		id = "fprice.price_follows",
		area = "Flight prices",
		text = "When a driver changes his price, the tag on the flight map shows his new price.",
		source = "FlightPins (price of the driver now); Flight offers tooltip",
		kind = "scenario",
		needs = { ride = "none" },
		when = onMap,
		check = function(ctx)
			driverFacts(ctx)
			local M = pinsMod(ctx)
			local town
			for _, d in ipairs(ctx.facts.drivers) do
				for _, k in ipairs(KNOWN) do if d.dest == k and not town then town = k end end
			end
			must(ctx, town, "no driver at a place on this map")
			local f, c = factAt(ctx, town)
			local newp = (f.price == 12300) and 12400 or 12300
			local okp = c.W.Drive.SetPrice(newp)
			must(ctx, okp ~= false, "the driver's new price was refused")
			ctx:note(f.name .. " sets his price to " .. newp)
			ctx:advance(10)
			openMap(ctx)
			for _, p in ipairs(M.Pins()) do
				if head(p.node) == town and p.driver == key(f.name) then
					local real = c.W.Char().price
					if p.price ~= real then
						ctx:fail("A driver set his price to " .. ctx.W.Money(real) .. " and his tag on the flight map still says " .. ctx.W.Money(p.price) .. ".", seenList(ctx))
					end
					return
				end
			end
			ctx:na("the driver has no tag after the change")
		end,
	}

	Hunt.promise{
		id = "fprice.tag_click_books",
		area = "Flight prices",
		text = "Clicking a price tag opens Wuber on that driver's Confirm page and sends nothing: you still click Request yourself.",
		source = "FlightPins tag click (openDriver); InFlight Book tooltip (You still click Request yourself)",
		kind = "scenario",
		needs = { ride = "none" },
		when = onMap,
		check = function(ctx)
			driverFacts(ctx)
			local M = pinsMod(ctx)
			-- a player closes what is in the way first: the Settings page and the What's new card (Got it)
			do
				local UI = ctx.W.UI
				if UI.state and UI.state.settingsOpen and type(UI.CloseSettings) == "function" then
					pcall(UI.CloseSettings, true)
					ctx:note("close Settings")
					ctx:advance(0.5)
				end
				for _ = 1, 3 do
					local b = ctx.me:button("Got it")
					if b and ctx:visible(b) then
						pcall(function() ctx.me:click(b) end)
						ctx:note("tap Got it on the card in the way")
						ctx:advance(0.5)
					else
						break
					end
				end
			end
			openMap(ctx)
			local pin
			for _, p in ipairs(M.Pins()) do if p.tag and ctx:visible(p.tag) then pin = p break end end
			must(ctx, pin, "no visible tag")
			ctx.me:clickOn(pin.tag)
			ctx:note("click the tag at " .. head(pin.node))
			ctx:advance(0.5)
			local st = ctx.W.UI.state or {}
			if st.confirmKey ~= pin.driver then
				ctx:fail("You click the price tag at " .. head(pin.node) .. " and Wuber does not open on that driver (opened: " .. tostring(st.confirmKey) .. ").", seenList(ctx))
			end
			if ctx.W.RideActive() then
				ctx:fail("You only clicked a price tag and a ride request was already sent.", seenList(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "fprice.cheapest_per_place",
		area = "Flight prices",
		text = "When two open drivers summon to one place, the tag shows the cheaper one's price and a click opens the cheaper driver.",
		source = "FlightPins (cheapest open driver per place); CHANGELOG 2.4.0 flight map prices",
		kind = "scenario",
		needs = { ride = "none", net = "one" },
		when = function(sit) return isRider(sit) and sit.net == "one" and (sit.place == nil or sit.place == "town") and (sit.combat == nil or sit.combat == "no") end,
		check = function(ctx)
			driverFacts(ctx)
			local M = pinsMod(ctx)
			local f1, c1 = factAt(ctx, "Ratchet")
			must(ctx, f1, "no driver at Ratchet")
			-- a second driver at the same place with a lower price
			local name = "Zed Rival"
			must(ctx, not ctx.w:player(name), "name taken")
			ctx.w:addClient(name, { spot = "Ratchet", class = "WARLOCK", shards = 10, money = 100000 })
			local c2 = ctx.w:clientOf(name)
			c2.W.Char().welcomed = true
			c2.W.Char().price = 6000
			must(ctx, c2.W.Driver.SetOnline(true) ~= false, "second driver could not open")
			c2.W.Drive.SetPrice(6000)
			c1.W.Drive.SetPrice(9000)
			ctx:note(name .. " opens at Ratchet for 6000, " .. f1.name .. " asks 9000")
			ctx:advance(8)
			openMap(ctx)
			for _, p in ipairs(M.Pins()) do
				if head(p.node) == "Ratchet" then
					if p.price ~= 6000 or p.driver ~= key(name) then
						local lst = {}
						for _, d in ipairs(ctx.W.UI.Drivers()) do lst[#lst + 1] = d.name .. "=" .. d.price .. "/" .. d.state .. "@" .. d.dest end
						ctx:fail("Two open drivers summon to Ratchet and the tag does not show the cheaper one (shows " .. ctx.W.Money(p.price) .. ").", table.concat(lst, "; "))
					end
					return
				end
			end
			ctx:na("no Ratchet tag")
		end,
	}

	---------------------------------------------------------------------------
	-- The mid-flight offer
	---------------------------------------------------------------------------
	local function fly(ctx, secs)
		local list = nodes(ctx)
		local slot = slotOf(list, "Ratchet")
		must(ctx, slot, "no Ratchet node")
		ctx.w:closeTaxiMap(ctx.me)
		ctx.w:openTaxiMap(ctx.me, list)
		ctx.w:fly(ctx.me, slot, secs, "Ratchet")
		ctx:note(("fly to Ratchet, %d seconds"):format(secs))
	end
	-- one earlier flight so Wuber knows how long it takes (the way a player has flown it before)
	local function warm(ctx, secs)
		openMap(ctx)
		fly(ctx, secs)
		ctx:advance(secs + 6)
		ctx.w:move(ctx.name, "Thunder Bluff")
		ctx:advance(2)
		openMap(ctx)
	end
	local function midOk(sit) return onMap(sit) and sit.session ~= "first" end
	local function card(ctx)
		local M = flightMod(ctx)
		local c = M.Card()
		if c and ctx:visible(c) then return c, M end
		return nil, M
	end

	Hunt.promise{
		id = "fprice.mid_names_driver",
		area = "Flight prices",
		text = "With 90 seconds or more of the flight left and an open driver at the place you fly to, the offer card appears and names that driver's real price.",
		source = "InFlight header; Book button (Book . <price>)",
		kind = "scenario",
		needs = { ride = "none", net = "one" },
		when = function(sit) return midOk(sit) and sit.net == "one" end,
		check = function(ctx)
			local f, c = factAt(ctx, "Ratchet")
			must(ctx, f, "no driver at Ratchet")
			flightMod(ctx)
			warm(ctx, 240)
			fly(ctx, 240)
			ctx:advance(6)
			local cd, M = card(ctx)
			if not cd and tostring(M.Why()):find("no room", 1, true) then ctx:na("no room beside Wuber's window (placement, not logic)") end
			if not cd then
				ctx:fail("You fly 240 seconds to Ratchet where an open driver summons and no offer card appears.", seenList(ctx) .. " / Why: " .. tostring(M.Why()))
			end
			if M.Driver() ~= key(f.name) then
				ctx:fail("The mid-flight offer names a different driver than the one who summons to Ratchet.", tostring(M.Driver()))
			end
			local want = "Book · " .. ctx.W.Money(c.W.Char().price)
			local found
			for _, t in ipairs(ctx:texts()) do if t:find(want, 1, true) then found = true end end
			if not found then
				ctx:fail("The offer card's button does not say " .. want .. ", the driver's price.", seenList(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "fprice.mid_short_flight",
		area = "Flight prices",
		text = "A flight with under 90 seconds left gets no mid-flight offer.",
		source = "InFlight header (at least 90 s left); Why: under 90 seconds left",
		kind = "scenario",
		needs = { ride = "none", net = "one" },
		when = function(sit) return midOk(sit) and sit.net == "one" end,
		check = function(ctx)
			flightMod(ctx)
			warm(ctx, 70)
			fly(ctx, 70)
			ctx:advance(5)
			if card(ctx) then
				ctx:fail("You fly a 70 second flight and Wuber offers a summon mid-flight, with under 90 seconds left.", seenList(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "fprice.mid_once",
		area = "Flight prices",
		text = "The mid-flight offer comes once per flight: after you close it with the x it does not come back, and the next flight gets a new one.",
		source = "InFlight header (once per flight; the x hides it for this flight)",
		kind = "scenario",
		needs = { ride = "none", net = "one" },
		when = function(sit) return midOk(sit) and sit.net == "one" end,
		check = function(ctx)
			flightMod(ctx)
			warm(ctx, 300)
			fly(ctx, 300)
			ctx:advance(6)
			local cd, M = card(ctx)
			must(ctx, cd, "no card on the first flight")
			ctx.me:clickOn(cd.x)
			ctx:note("click the x on the offer card")
			ctx:advance(1)
			ctx:advance(60)
			if card(ctx) then
				ctx:fail("You closed the mid-flight offer with the x and it came back on the same flight.", seenList(ctx))
			end
			ctx:advance(260) -- land
			ctx.w:move(ctx.name, "Thunder Bluff")
			ctx:advance(2)
			openMap(ctx)
			fly(ctx, 300)
			ctx:advance(6)
			if not card(ctx) then
				ctx:fail("After landing, the next flight gets no mid-flight offer.", seenList(ctx) .. " / Why: " .. tostring(M.Why()))
			end
		end,
	}

	Hunt.promise{
		id = "fprice.mid_book_sends_nothing",
		area = "Flight prices",
		text = "Clicking Book on the mid-flight offer opens that driver's Confirm page and sends nothing: no ride starts until you click Request yourself.",
		source = "InFlight Book tooltip (Opens Wuber on this driver. You still click Request yourself.)",
		kind = "scenario",
		needs = { ride = "none", net = "one" },
		when = function(sit) return midOk(sit) and sit.net == "one" end,
		check = function(ctx)
			local f = factAt(ctx, "Ratchet")
			must(ctx, f, "no driver at Ratchet")
			flightMod(ctx)
			warm(ctx, 240)
			fly(ctx, 240)
			ctx:advance(6)
			local cd = card(ctx)
			must(ctx, cd, "no card")
			ctx.me:clickOn(cd.book.btn or cd.book.button or cd.book)
			ctx:note("click Book on the offer card")
			ctx:advance(1)
			local st = ctx.W.UI.state or {}
			if st.confirmKey ~= key(f.name) then
				ctx:fail("You click Book on the mid-flight offer and Wuber does not open on that driver (opened: " .. tostring(st.confirmKey) .. ").", seenList(ctx))
			end
			if ctx.W.RideActive() then
				ctx:fail("You clicked Book on the mid-flight offer and a ride was requested without your Request click.", seenList(ctx))
			end
			if card(ctx) then
				ctx:fail("You clicked Book and the offer card is still up.", seenList(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "fprice.mid_dont_show",
		area = "Flight prices",
		text = "Don't show on the mid-flight offer turns the offers off: the next flight gets none.",
		source = "InFlight Don't show link (No more offers while you fly)",
		kind = "scenario",
		needs = { ride = "none", net = "one" },
		when = function(sit) return midOk(sit) and sit.net == "one" end,
		check = function(ctx)
			flightMod(ctx)
			warm(ctx, 300)
			fly(ctx, 300)
			ctx:advance(6)
			must(ctx, card(ctx), "no card")
			ctx.me:clickText("Don't show")
			ctx:note("click Don't show")
			ctx:advance(1)
			if card(ctx) then ctx:fail("You click Don't show and the card is still up.", seenList(ctx)) end
			ctx:advance(300)
			ctx.w:move(ctx.name, "Thunder Bluff")
			ctx:advance(2)
			openMap(ctx)
			fly(ctx, 300)
			ctx:advance(8)
			if card(ctx) then
				ctx:fail("You said Don't show and the next flight still gets a mid-flight offer.", seenList(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "fprice.mid_driver_closes",
		area = "Flight prices",
		text = "The mid-flight offer never keeps naming a driver who has closed his shop.",
		source = "InFlight header (an open driver at the destination)",
		kind = "scenario",
		needs = { ride = "none", net = "one" },
		when = function(sit) return midOk(sit) and sit.net == "one" end,
		check = function(ctx)
			local f, c = factAt(ctx, "Ratchet")
			must(ctx, f, "no driver at Ratchet")
			flightMod(ctx)
			warm(ctx, 300)
			fly(ctx, 300)
			ctx:advance(6)
			must(ctx, card(ctx), "no card")
			c.W.Drive.SetOpen(false)
			ctx:note(f.name .. " closes his shop mid-flight")
			ctx:advance(15)
			local cd, M = card(ctx)
			local seenD = ctx.W.UI.Driver(key(f.name))
			if seenD and seenD.state == "open" then ctx:na("my list still has him open (the close did not arrive)") end
			if cd and M.Driver() == key(f.name) then
				ctx:fail("The driver closed his shop and your mid-flight offer still says Book for him.", seenList(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "fprice.mid_price_changes",
		area = "Flight prices",
		text = "The mid-flight offer's Book price is the driver's price when you click it, not an old one.",
		source = "InFlight Book button (Book . <price>)",
		kind = "scenario",
		needs = { ride = "none", net = "one" },
		when = function(sit) return midOk(sit) and sit.net == "one" end,
		check = function(ctx)
			local f, c = factAt(ctx, "Ratchet")
			must(ctx, f, "no driver at Ratchet")
			flightMod(ctx)
			warm(ctx, 300)
			fly(ctx, 300)
			ctx:advance(6)
			must(ctx, card(ctx), "no card")
			local newp = f.price + 2200
			must(ctx, c.W.Drive.SetPrice(newp) ~= false, "price refused")
			ctx:note(f.name .. " raises his price to " .. newp .. " mid-flight")
			ctx:advance(12)
			local cd, M = card(ctx)
			if not cd then ctx:na("the card went") end
			local seenD = ctx.W.UI.Driver(key(f.name))
			if not (seenD and seenD.price == newp) then ctx:na("my list does not have the new price") end
			local old = "Book · " .. ctx.W.Money(f.price)
			for _, t in ipairs(ctx:texts()) do
				if t:find(old, 1, true) then
					ctx:fail("The driver raised his price to " .. ctx.W.Money(newp) .. " and the offer card still says " .. old .. ".", seenList(ctx))
				end
			end
		end,
	}
end
