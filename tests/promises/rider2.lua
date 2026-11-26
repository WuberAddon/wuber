-- Promises about the rider's deeper parts, second wave (owner rider2): favourites and hidden drivers, the bell for places,
-- wishes (bounties), milestones, Azeroth Wrapped, learned flight times, and the driver-found screen's smaller promises.
-- Written from what the player is told: the heart's and the bell's tooltips and toasts ("We'll tell you when they're online",
-- "X is hidden. Show them again in Settings"), the Help page, the Net.Favourites / Net.Bounty / Core.Wrapped / UI.Rider.Wrapped
-- headers, BRIEF25 and the 2.3.2 changelog. The checks reach things the way a player does where they can: /wuber, real clicks,
-- other players' windows. Where a check uses the handler a click runs (the heart's, the bell's) it says so in a note.
return function(Hunt)
	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		if type(want) == "table" then return want[v] == true end
		return v == want
	end
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function kit(ctx)
		local K = ctx:mod("UI.Kit")
		return K and K.ui or {}
	end
	local function plain(ctx)
		local out = {}
		for _, t in ipairs(ctx:texts()) do out[#out + 1] = (t:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
		return out
	end
	local function onScreen(ctx) return "on screen: " .. table.concat(plain(ctx), " | ") end
	local function has(ctx, pat, isPlain)
		for _, t in ipairs(plain(ctx)) do
			if t:find(pat, 1, isPlain ~= false) then return t end
		end
		return nil
	end
	-- the rider's ordinary day: a rider, no ride, no fight, not the very first run
	local function riderDay(sit)
		return is(sit, "role", "rider") and is(sit, "ride", "none") and is(sit, "combat", "no") and sit.session ~= "first"
	end
	local LIST_NETS = { one = true, many = true, late = true }

	local NEW_NAMES = { "Eli Marsh", "Fay Doyle", "Gus Hale", "Hal Nash", "Ivy Cole" }
	-- a new Wuber driver opens for business at a place (another window; its beacon reaches me by addon message)
	local function driverOpens(ctx, spot, price)
		local name
		for _, n in ipairs(NEW_NAMES) do if not ctx.w:player(n) then name = n break end end
		if not name then ctx:cannot("no free name for a driver") end
		local d = ctx.w:addClient(name, { spot = spot, class = "WARLOCK", shards = 10, money = 100000 })
		if d.W.Char then d.W.Char().welcomed = true if price then d.W.Char().price = price end end
		if not (d.W.Driver and type(d.W.Driver.SetOnline) == "function") then ctx:cannot("the driver window has no Driver.SetOnline") end
		if d.W.Driver.SetOnline(true) == false then ctx:cannot("the driver could not open") end
		ctx:note(name .. " opens in " .. spot)
		return d, name
	end
	local function firstDriver(ctx)
		local d = ctx.facts.drivers and ctx.facts.drivers[1]
		local c = ctx.peers and ctx.peers.driver
		if not (d and c and ctx.W.drivers and ctx.W.drivers[key(d.name)]) then ctx:na("the driver was not heard") end
		return c, d
	end
	local function closes(ctx, c, name)
		c.W.Driver.SetOnline(false)
		ctx:note(name .. " closes")
		ctx:advance(15)
	end
	local function opens(ctx, c, name)
		c.W.Driver.SetOnline(true)
		ctx:note(name .. " opens again")
	end
	-- the player's phone shows Wuber's toasts whatever tab it is on; a toast lives a few seconds: look every half second
	-- and count each time one with this text appears (a new sighting after it was gone)
	local function toastEdges(ctx, pat, secs)
		local n, was = 0, false
		for _ = 1, math.floor(secs * 2) do
			ctx:advance(0.5)
			local now = has(ctx, pat) ~= nil
			if now and not was then n = n + 1 end
			was = now
		end
		return n
	end
	local function waitToast(ctx, pat, secs)
		for _ = 1, math.floor(secs * 2) do
			ctx:advance(0.5)
			local t = has(ctx, pat)
			if t then return t end
		end
		return nil
	end
	local function conditions(ctx)
		if ctx.me.player.combat then ctx:na("in combat") end
		-- after a /reload the game takes a few seconds to put the player back in Wuber's channel (the fake game; a real /reload keeps it)
		if ctx.facts.reloaded or ctx.facts.session == "reload" then ctx:advance(6) end
		local K = ctx:mod("UI.Kit")
		if K and type(K.rideActive) == "function" then
			local ok, active = pcall(K.rideActive)
			if ok and active then ctx:na("a ride is on") end
		end
	end
	local function UIof(ctx) return ctx.W.UI end
	-- the player has Wuber open already (so the first-open tip is not what the tap meets: that is HUNT-13)
	local function openPhone(ctx)
		if not UIof(ctx).IsShown() then
			ctx.me:slash("/wuber")
			ctx:advance(3)
			ctx:note("/wuber")
		end
	end
	-- the heart's handler (what a tap on a heart runs): the driver becomes a favourite
	local function heart(ctx, k, name)
		local UI = UIof(ctx)
		if type(UI.ToggleFav) ~= "function" then ctx:cannot("no favourites in this Wuber") end
		if not ctx.W.IsFav(k) then UI.ToggleFav(k, name) end
		ctx:note("tap the heart on " .. name)
		ctx:advance(0.5)
	end
	local function bell(ctx, place, want)
		local UI = UIof(ctx)
		if type(UI.ToggleWatch) ~= "function" then ctx:cannot("no bell in this Wuber") end
		if UI.IsWatching(place) ~= want then UI.ToggleWatch(place) end
		ctx:note("tap the bell for " .. place .. (want and " (on)" or " (off)"))
		ctx:advance(0.5)
	end

	---------------------------------------------------------------------------------------------------------------
	-- Favourites and hidden drivers
	---------------------------------------------------------------------------------------------------------------

	Hunt.promise{
		id = "favs.online_note_once_in_ten_minutes",
		area = "Favourites",
		text = "A favourite who keeps closing and opening again tells you only once: the same driver is not announced twice within ten minutes.",
		source = "Net.Favourites header (each driver at most once per 10 min)",
		kind = "scenario",
		when = function(sit) return riderDay(sit) and LIST_NETS[sit.net or "one"] == true end,
		check = function(ctx)
			conditions(ctx)
			local c, d = firstDriver(ctx)
			heart(ctx, key(d.name), d.name)
			closes(ctx, c, d.name)
			opens(ctx, c, d.name)
			if not waitToast(ctx, "is online", 14) then ctx:na("the first note never came (home.favourite_online_note says so)") end
			ctx:advance(12)
			closes(ctx, c, d.name)
			opens(ctx, c, d.name)
			local n = toastEdges(ctx, "is online", 14)
			if n > 0 then
				ctx:fail(("Your favourite %s is announced online, closes and opens again a minute later, and you are told again."):format(d.name), onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "favs.online_note_not_repeated_after_reload",
		area = "Favourites",
		text = "A favourite you were told about is not announced again after a /reload if they close and open again within ten minutes.",
		source = "Net.Favourites header (kept in the saved data so a /reload doesn't repeat them)",
		kind = "scenario",
		when = function(sit) return riderDay(sit) and LIST_NETS[sit.net or "one"] == true and sit.session ~= "reload" end,
		check = function(ctx)
			conditions(ctx)
			local c, d = firstDriver(ctx)
			heart(ctx, key(d.name), d.name)
			closes(ctx, c, d.name)
			opens(ctx, c, d.name)
			if not waitToast(ctx, "is online", 14) then ctx:na("the first note never came") end
			ctx:reload()
			ctx:advance(8)
			if not ctx.W.IsFav(key(d.name)) then ctx:na("the favourite was lost on /reload (home.favourite_saved says so)") end
			closes(ctx, c, d.name)
			opens(ctx, c, d.name)
			local n = toastEdges(ctx, "is online", 14)
			if n > 0 then
				ctx:fail(("You are told your favourite %s is online, /reload, they close and open again a minute later, and you are told again."):format(d.name), onScreen(ctx))
			end
		end,
	}


	Hunt.promise{
		id = "favs.several_one_note_cheapest",
		area = "Favourites",
		text = "When several favourites come online together you get one note that counts them and names the cheapest.",
		source = "Net.Favourites header (3 favourites online; the cheapest in the list)",
		kind = "scenario",
		needs = { net = "many" },
		when = function(sit) return riderDay(sit) end,
		check = function(ctx)
			conditions(ctx)
			local clients, facts = ctx.peers.drivers or {}, ctx.facts.drivers or {}
			if #facts < 3 then ctx:cannot("fewer than three drivers") end
			local rows = {}
			for i = 1, 3 do
				local f = facts[i]
				local price = math.max(f.price, tonumber(ctx.W.MIN_PRICE) or 5000)
				rows[i] = { name = f.name, client = clients[i], price = price, dest = f.dest }
				if not ctx.W.drivers[key(f.name)] then ctx:na(f.name .. " was not heard") end
			end
			for _, r in ipairs(rows) do heart(ctx, key(r.name), r.name) end
			for _, r in ipairs(rows) do r.client.W.Driver.SetOnline(false) end
			ctx:note("all three favourites close")
			ctx:advance(15)
			for _, r in ipairs(rows) do r.client.W.Driver.SetOnline(true) end
			ctx:note("all three open again")
			local t = waitToast(ctx, " online · ", 14)
			if not t then ctx:fail("Three of your favourites come online together and you are told nothing.", onScreen(ctx)) end
			if not t:find("3 favourites online", 1, true) then
				ctx:fail("Three of your favourites come online together and the note does not say 3 favourites are online.", t)
			end
			table.sort(rows, function(a, b) if a.price ~= b.price then return a.price < b.price end return key(a.name) < key(b.name) end)
			local short = ctx.W.Short and ctx.W.Short(rows[1].name) or rows[1].name
			if not t:find(short, 1, true) then
				ctx:fail(("Three favourites come online together and the note does not name the cheapest, %s."):format(short), t)
			end
			ctx:advance(1)
			local more = toastEdges(ctx, "is online", 8)
			if more > 0 then ctx:fail("Three favourites come online together and you get a second note for one of them.", onScreen(ctx)) end
		end,
	}


	Hunt.promise{
		id = "favs.hidden_gets_no_note",
		area = "Favourites",
		text = "A driver you hid never tells you they are online, even if they were a favourite.",
		source = "Net.Favourites header (a hidden driver has no card, pin, toast or nameplate badge); card menu tooltip",
		kind = "scenario",
		when = function(sit) return riderDay(sit) and LIST_NETS[sit.net or "one"] == true end,
		check = function(ctx)
			conditions(ctx)
			local c, d = firstDriver(ctx)
			heart(ctx, key(d.name), d.name)
			UIof(ctx).HideDriver(key(d.name), d.name)
			ctx:note("right-click " .. d.name .. " and Hide this driver")
			ctx:advance(1)
			closes(ctx, c, d.name)
			opens(ctx, c, d.name)
			local n = toastEdges(ctx, "is online", 14)
			if n > 0 then ctx:fail(("You hide %s, a favourite, and when they open again you are told they are online."):format(d.name), onScreen(ctx)) end
		end,
	}


	---------------------------------------------------------------------------------------------------------------
	-- The bell (watched places)
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "watch.bell_saved",
		area = "Watch",
		text = "A place you tapped the bell for is still watched after a /reload, and a tap again switches it off and says so.",
		source = "bell tooltip / toasts (We'll tell you when a driver to X comes online; No more alerts for X); Net.Favourites (stays on until turned off)",
		kind = "scenario",
		when = function(sit) return riderDay(sit) end,
		check = function(ctx)
			conditions(ctx)
			bell(ctx, "Ironforge", true)
			if not has(ctx, "tell you when a driver to Ironforge") then
				ctx:fail("You tap the bell for Ironforge and Wuber does not say it will tell you.", onScreen(ctx))
			end
			ctx:reload()
			ctx:advance(4)
			if not ctx.W.UI.IsWatching("Ironforge") then
				ctx:fail("You tap the bell for Ironforge, /reload, and Ironforge is no longer watched.", onScreen(ctx))
			end
			ctx.W.UI.ToggleWatch("Ironforge")
			ctx:note("tap the bell for Ironforge again")
			ctx:advance(0.5)
			if not has(ctx, "No more alerts for Ironforge") then
				ctx:fail("You tap the bell for Ironforge a second time and Wuber does not say there are no more alerts.", onScreen(ctx))
			end
			if ctx.W.UI.IsWatching("Ironforge") then ctx:fail("You tap the bell for Ironforge off and it is still watched.", onScreen(ctx)) end
		end,
	}



	Hunt.promise{
		id = "watch.note_names_place_driver_price",
		area = "Watch",
		text = "The note for a watched place names the place, the driver and what they charge, and tapping it opens that driver's booking screen.",
		source = "bell toast; Net.Favourites header (A driver to Ratchet is online); Moments (tap opens the booking)",
		kind = "scenario",
		when = function(sit) return riderDay(sit) and is(sit, "group", "solo") end,
		check = function(ctx)
			conditions(ctx)
			openPhone(ctx)
			bell(ctx, "Ironforge", true)
			local _, name = driverOpens(ctx, "Ironforge", 9000)
			local t = waitToast(ctx, "to Ironforge is online", 14)
			if not t then ctx:fail(("You watch Ironforge and %s opens there and fourteen seconds later you are not told."):format(name), onScreen(ctx)) end
			local short = ctx.W.Short and ctx.W.Short(name) or name
			if not t:find(short, 1, true) then ctx:fail("The note for your watched place does not name the driver.", t) end
			if not t:find("%d+[gsc]") then ctx:fail("The note for your watched place does not say what the driver charges.", t) end
			local ok = pcall(ctx.me.clickText, ctx.me, "to Ironforge is online", { pattern = true })
			if not ok then ctx:na("the note could not be clicked where it is drawn") end
			ctx:advance(1.5)
			ctx:note("tap the note")
			if kit(ctx).screen ~= "confirm" or not has(ctx, name) then
				ctx:fail(("You tap the note about %s at Ironforge and their booking screen does not open."):format(short), onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "watch.note_once_in_ten_minutes",
		area = "Watch",
		text = "A driver to a place you watch who closes and opens again within ten minutes does not tell you a second time.",
		source = "Net.Favourites header (each driver per destination at most once per 10 min)",
		kind = "scenario",
		when = function(sit) return riderDay(sit) end,
		check = function(ctx)
			conditions(ctx)
			bell(ctx, "Ironforge", true)
			local d, name = driverOpens(ctx, "Ironforge", 9000)
			if not waitToast(ctx, "to Ironforge is online", 14) then ctx:na("the first note never came (home.bell_tells_me says so)") end
			ctx:advance(12)
			closes(ctx, d, name)
			opens(ctx, d, name)
			local n = toastEdges(ctx, "to Ironforge is online", 14)
			if n > 0 then ctx:fail(("You watch Ironforge, %s opens there, closes and opens again a minute later, and you are told twice."):format(name), onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "watch.favourite_and_place_one_note",
		area = "Watch",
		text = "A favourite who opens at a place you watch tells you once, not once as a favourite and again as a driver to that place.",
		source = "Net.Favourites header (one toast at a time; a favourite already told is not told again as a place hit)",
		kind = "scenario",
		when = function(sit) return riderDay(sit) and LIST_NETS[sit.net or "one"] == true end,
		check = function(ctx)
			conditions(ctx)
			local c, d = firstDriver(ctx)
			heart(ctx, key(d.name), d.name)
			bell(ctx, d.dest, true)
			closes(ctx, c, d.name)
			opens(ctx, c, d.name)
			local n = toastEdges(ctx, " online · ", 20)
			if n > 1 then
				ctx:fail(("%s is your favourite and goes to %s, a place you watch, and when they open you are told twice."):format(d.name, d.dest), onScreen(ctx))
			end
			if n == 0 then ctx:fail(("%s is your favourite and goes to a place you watch, opens, and you are told nothing."):format(d.name), onScreen(ctx)) end
		end,
	}


	---------------------------------------------------------------------------------------------------------------
	-- Milestones and rider level
	---------------------------------------------------------------------------------------------------------------
	local FAR = { "Ratchet", "Orgrimmar", "Undercity", "Thunder Bluff", "Booty Bay", "Gadgetzan", "Tarren Mill", "Everlook",
		"Stormwind City", "Ironforge", "Darnassus", "Crossroads", "Menethil Harbor", "Auberdine", "Theramore Isle",
		"Southshore", "Astranaar", "Sentinel Hill", "Goldshire", "Kharanos", "Lakeshire", "Aerie Peak", "Hammerfall",
		"Splintertree Post", "Zoram'gar Outpost" }
	-- the last step of a paid ride, as the ride's own payment runs it: the trip is saved and the milestones are checked
	-- (the check stands in for the whole ride: a ride's end cannot be repeated in every situation)
	local function paidRide(ctx, o)
		o = o or {}
		local env = ctx.me.env
		local W = ctx.W
		W.AddTrip({ at = o.at or env.time(), driver = o.driver or "Real Driver", driverKey = key(o.driver or "Real Driver"),
			dest = o.dest or "Ratchet", price = 5000, stars = 4, saved = o.saved or 600, unpaid = o.unpaid })
		local new = W.CheckMilestones()
		ctx:note("a ride is paid for (" .. (o.dest or "Ratchet") .. ")")
		return new
	end
	-- the player rides (paid) until Wuber gives something new; returns the ids
	local function rideUntilNew(ctx)
		local W = ctx.W
		for i = 1, 130 do
			local dest = FAR[((i - 1) % #FAR) + 1]
			local new = paidRide(ctx, { dest = dest, driver = "Driver " .. (i % 7) })
			if #new > 0 then return new end
		end
		ctx:cannot("no new milestone in 130 rides")
	end
	local function popOf(ctx)
		local f = kit(ctx).pop
		if f and ctx:visible(f) then return f end
		return nil
	end
	local function popTitle(ctx)
		local f = popOf(ctx)
		return f and f.title and f.title:GetText() or nil
	end
	local function whyNot(ctx)
		return onScreen(ctx)
	end
	local RIDER_OK = function(sit) return is(sit, "role", "rider") and is(sit, "ride", "none") and is(sit, "combat", "no") and sit.session ~= "first" end

	Hunt.promise{
		id = "miles.card_pops_and_goes",
		area = "Milestones",
		text = "When you earn a new milestone or rider level a card pops up near the top of the screen saying what you unlocked, and it goes by itself after a few seconds.",
		source = "Moments header (a celebration card); Trips (milestones: nice one!)",
		kind = "scenario",
		when = RIDER_OK,
		check = function(ctx)
			conditions(ctx)
			local new = rideUntilNew(ctx)
			ctx:advance(1)
			local t = popTitle(ctx)
			if not t then
				ctx:fail(("You pay for a ride that earns you %s and no celebration card pops up."):format(table.concat(new, ", ")), whyNot(ctx))
			end
			local want = nil
			for _, id in ipairs(new) do if id:match("^tier%d$") then want = ctx.W.TierName(ctx.W.Tier()) end end
			if not want then
				local m = ctx.W.MilestoneInfo(new[1])
				want = m and m.name
			end
			if want and not t:find(want, 1, true) then
				ctx:fail(("You earn %s and the celebration card says '%s'."):format(want, t), whyNot(ctx))
			end
			ctx:advance(11)
			if popOf(ctx) then ctx:fail("The celebration card is still on screen eleven seconds after it popped up.", whyNot(ctx)) end
		end,
	}

	Hunt.promise{
		id = "miles.card_tap_opens_trips",
		area = "Milestones",
		text = "Tapping the celebration card opens Wuber on your trips and milestones.",
		source = "Moments (card tooltip: Click to see your trips and milestones)",
		kind = "scenario",
		when = function(sit) return RIDER_OK(sit) and is(sit, "group", "solo") end,
		check = function(ctx)
			conditions(ctx)
			local new = rideUntilNew(ctx)
			ctx:advance(1)
			local f = popOf(ctx)
			if not f then ctx:na("no card popped up (miles.card_pops_and_goes says so)") end
			local ok = pcall(ctx.me.clickOn, ctx.me, f)
			if not ok then ctx:na("the card could not be clicked where it is drawn") end
			ctx:note("tap the celebration card")
			ctx:advance(1.5)
			if not ctx.W.UI.IsShown() then ctx:fail("You tap the celebration card and Wuber does not open.", whyNot(ctx)) end
			if kit(ctx).tab ~= "Trips" then
				ctx:fail(("You tap the celebration card and Wuber opens on the %s tab, not on your trips."):format(tostring(kit(ctx).tab)), whyNot(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "miles.card_waits_for_the_fight",
		area = "Milestones",
		text = "A milestone you earn while you are in a fight does not pop up in the middle of it: the card comes once the fight is over.",
		source = "Moments header (a card waits for combat to end)",
		kind = "scenario",
		when = RIDER_OK,
		check = function(ctx)
			conditions(ctx)
			ctx.w:enterCombat(ctx.me)
			ctx:note("combat starts")
			local new = rideUntilNew(ctx)
			ctx:advance(4)
			if popOf(ctx) then
				ctx:fail("You earn a milestone in the middle of a fight and the celebration card pops up over the fight.", whyNot(ctx))
			end
			ctx.w:leaveCombat(ctx.me)
			ctx:note("combat ends")
			for _ = 1, 16 do
				ctx:advance(0.5)
				if popOf(ctx) then return end
			end
			ctx:fail(("You earned %s in a fight and eight seconds after the fight the card has not come."):format(table.concat(new, ", ")), whyNot(ctx))
		end,
	}

	Hunt.promise{
		id = "miles.card_not_again_after_reload",
		area = "Milestones",
		text = "A milestone is given once: after you have seen its card, a /reload and some time later bring no card for it again.",
		source = "Core.Stats (each milestone is marked when earned; one celebration per new achievement)",
		kind = "scenario",
		when = function(sit) return RIDER_OK(sit) and sit.session ~= "reload" end,
		check = function(ctx)
			conditions(ctx)
			local new = rideUntilNew(ctx)
			ctx:advance(10)
			ctx:reload()
			ctx:advance(30)
			conditions(ctx)
			local t = popTitle(ctx)
			if t then
				ctx:fail(("You earned %s, saw the card, /reload, and a card for '%s' comes again."):format(table.concat(new, ", "), t), whyNot(ctx))
			end
			local again = ctx.W.CheckMilestones()
			if #again > 0 then ctx:fail(("After a /reload Wuber gives you %s a second time."):format(table.concat(again, ", ")), whyNot(ctx)) end
		end,
	}

	Hunt.promise{
		id = "miles.bronze_at_three_rides",
		area = "Milestones",
		text = "Your third paid ride makes you a Bronze rider: the card says so, and drivers are told you are one.",
		source = "Trips (Bronze at 3 rides); Moments (You're a Bronze rider! Drivers now see you as a Bronze rider)",
		kind = "scenario",
		needs = { saved = "fresh" },
		when = RIDER_OK,
		check = function(ctx)
			conditions(ctx)
			if (ctx.W.Stats().rides or 0) ~= 0 then ctx:na("this player already has rides") end
			paidRide(ctx, { dest = "Ratchet" })
			paidRide(ctx, { dest = "Orgrimmar" })
			if ctx.W.Tier() ~= 0 then ctx:fail("After two paid rides Wuber already calls you a rider level.", whyNot(ctx)) end
			ctx:advance(12)
			paidRide(ctx, { dest = "Undercity" })
			ctx:advance(1)
			local t = popTitle(ctx)
			if not (t and t:find("Bronze", 1, true)) then
				ctx:fail("You pay for your third ride and no card says you are a Bronze rider.", t or whyNot(ctx))
			end
			if ctx.W.TierName(ctx.W.Tier()) ~= "Bronze" then ctx:fail("You have paid for three rides and your level is not Bronze.", whyNot(ctx)) end
			local label = ctx.W.RiderLabel(ctx.W.Tier(), ctx.W.Stats().rides)
			if not label:find("Bronze", 1, true) then ctx:fail("You are a Bronze rider and drivers are told only '" .. label .. "'.", whyNot(ctx)) end
		end,
	}

	-- local time of a day and hour in the harness clock
	local function at(ctx, y, m, d, h)
		return ctx.me.env.time({ year = y, month = m, day = d, hour = h, min = 30, sec = 0 })
	end
	local function hasMilestone(ctx, id) return ctx.W.db.milestones and ctx.W.db.milestones[id] ~= nil end

	Hunt.promise{
		id = "miles.night_owl_between_midnight_and_five",
		area = "Milestones",
		text = "A ride between midnight and 5 am earns Night Owl, and a ride at 5 am or in the daytime does not.",
		source = "Trips (milestone: Take a ride between midnight and 5 am); Core.Stats",
		kind = "scenario",
		when = RIDER_OK,
		check = function(ctx)
			conditions(ctx)
			if hasMilestone(ctx, "nightowl") then ctx:na("this player is already a Night Owl") end
			-- 5:30 am, 10:30, 23:30: no
			paidRide(ctx, { at = at(ctx, 2026, 11, 10, 5), dest = "Ratchet" })
			paidRide(ctx, { at = at(ctx, 2026, 11, 11, 10), dest = "Ratchet" })
			paidRide(ctx, { at = at(ctx, 2026, 11, 12, 23), dest = "Ratchet" })
			if hasMilestone(ctx, "nightowl") then
				ctx:fail("You take rides at half past five in the morning, mid-morning and late evening and Wuber calls you a Night Owl.", whyNot(ctx))
			end
			paidRide(ctx, { at = at(ctx, 2026, 11, 13, 2), dest = "Ratchet" })
			if not hasMilestone(ctx, "nightowl") then
				ctx:fail("You take a ride at half past two in the morning and Wuber does not give you Night Owl.", whyNot(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "miles.weekend_needs_saturday_then_sunday",
		area = "Milestones",
		text = "Weekend Warrior needs a ride on a Saturday and one on the Sunday right after it: a Saturday with a Monday, or a Sunday alone, does not earn it.",
		source = "Trips (milestone: Ride on a Saturday and the Sunday after it); Core.Stats",
		kind = "scenario",
		when = RIDER_OK,
		check = function(ctx)
			conditions(ctx)
			if hasMilestone(ctx, "weekend") then ctx:na("this player already has Weekend Warrior") end
			-- 2026-11-14 is a Saturday, 15 a Sunday, 16 a Monday, 22 the next Sunday
			paidRide(ctx, { at = at(ctx, 2026, 11, 14, 12), dest = "Ratchet" })
			paidRide(ctx, { at = at(ctx, 2026, 11, 16, 12), dest = "Ratchet" })
			paidRide(ctx, { at = at(ctx, 2026, 11, 22, 12), dest = "Ratchet" })
			if hasMilestone(ctx, "weekend") then
				ctx:fail("You ride on a Saturday, then on the Monday, then on a Sunday a week later, and Wuber gives you Weekend Warrior.", whyNot(ctx))
			end
			paidRide(ctx, { at = at(ctx, 2026, 11, 15, 12), dest = "Ratchet" })
			if not hasMilestone(ctx, "weekend") then
				ctx:fail("You ride on a Saturday and on the Sunday after it and Wuber does not give you Weekend Warrior.", whyNot(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "miles.explorer_counts_different_places",
		area = "Milestones",
		text = "Explorer comes at five different places: many rides to the same place do not count more than once.",
		source = "Trips (milestone: Ride to 5 different places); Core.Stats",
		kind = "scenario",
		needs = { saved = "fresh" },
		when = RIDER_OK,
		check = function(ctx)
			conditions(ctx)
			if (ctx.W.Stats().rides or 0) ~= 0 then ctx:na("this player already has rides") end
			for i = 1, 6 do paidRide(ctx, { dest = "Ratchet", driver = "Driver " .. i }) end
			if hasMilestone(ctx, "explorer") then
				ctx:fail("You ride to Ratchet six times and Wuber says you have been to five different places.", whyNot(ctx))
			end
			for i = 2, 4 do paidRide(ctx, { dest = FAR[i] }) end
			if hasMilestone(ctx, "explorer") then ctx:fail("You have ridden to four different places and Wuber gives you Explorer.", whyNot(ctx)) end
			paidRide(ctx, { dest = FAR[5] })
			if not hasMilestone(ctx, "explorer") then
				ctx:fail("You have ridden to five different places and Wuber does not give you Explorer.", whyNot(ctx))
			end
		end,
	}



	---------------------------------------------------------------------------------------------------------------
	-- Azeroth Wrapped
	---------------------------------------------------------------------------------------------------------------
	local function shown(ctx)
		local UI = ctx.W.UI
		return type(UI.IsShown) == "function" and UI.IsShown() == true
	end
	local function clickTab(ctx, name)
		local s = kit(ctx)
		for _, tab in ipairs(s.tabs or {}) do
			if tab.name == name and tab.button then
				ctx.me:clickOn(tab.button)
				ctx:advance(0.8)
				ctx:note("click the " .. name .. " tab")
				return s.tab == name
			end
		end
		return false
	end
	local function overlayOpen(ctx)
		local UI = ctx.W.UI
		local s = kit(ctx)
		if s.settingsOpen == true or (UI.state and UI.state.settingsOpen == true) then return true end
		if type(UI.HelpShown) == "function" and UI.HelpShown() == true then return true end
		if type(UI.Bug) == "table" and type(UI.Bug.Shown) == "function" and UI.Bug.Shown() == true then return true end
		return false
	end
	local function WR(ctx)
		local m = ctx:mod("UI.Rider.Wrapped")
		if not (m and type(m.Due) == "function") then ctx:cannot("this Wuber has no Wrapped (UI.Rider.Wrapped)") end
		return m
	end
	-- the player has the phone open on the Trips tab, on a fresh visit (the story closed, Settings left)
	local function atTrips(ctx)
		if not shown(ctx) then
			if ctx.me.player.combat then ctx:na("in combat: the phone does not open") end
			ctx.me:slash("/wuber")
			ctx:note("/wuber")
			ctx:advance(0.3)
			if not shown(ctx) then ctx:cannot("the phone did not open on /wuber") end
			ctx:advance(2.2)
		end
		local w = WR(ctx)
		if w.Shown() then w.Close() ctx:note("close the Wrapped story") ctx:advance(0.5) end
		local was = overlayOpen(ctx)
		if was then
			clickTab(ctx, "Trips")
			ctx:advance(0.5)
			if overlayOpen(ctx) then ctx:na("Settings, Help or the report stays on top after a tab is clicked") end
		end
		if not was and kit(ctx).tab == "Trips" then clickTab(ctx, "Ride") end
		if kit(ctx).tab ~= "Trips" then clickTab(ctx, "Trips") end
		if kit(ctx).tab ~= "Trips" then ctx:cannot("the Trips tab did not open") end
		ctx:advance(2)
	end
	local function tripsView(ctx)
		local m = ctx:mod("UI.Rider.Trips")
		if not (m and type(m.view) == "function") then ctx:cannot("this Wuber has no Trips tab") end
		return m.view()
	end
	-- n paid rides last month, the card not yet seen (the rides are in the saved data; riding in an earlier month cannot be done now)
	local function ridesLastMonth(ctx, n, dest)
		local env = ctx.me.env
		local t = env.date("*t", env.time())
		local at = env.time() - (t.day + 10) * 86400
		local rides = ctx.W.db.rides
		for i = 1, n do
			rides[#rides + 1] = { dest = dest or "Ratchet", driver = "Real Driver", driverKey = "real driver", price = 5000, at = at + i * 3600, stars = 4, saved = 600 }
		end
		ctx.W.db.wrapped = ctx.W.db.wrapped or {}
		ctx.W.db.wrapped.seen = nil
		ctx:note(n .. " paid rides last month are in the trip history, the card not yet seen")
		return env.date("%Y-%m", at), env.date("*t", at)
	end
	local function cardUp(ctx)
		local tr = tripsView(ctx)
		return tr.wrapCard ~= nil and ctx:visible(tr.wrapCard), tr
	end
	-- the player taps the card, else the chip (the way to the story)
	local function openStory(ctx)
		local w = WR(ctx)
		local _, tr = cardUp(ctx)
		local target = (tr.wrapCard and ctx:visible(tr.wrapCard)) and tr.wrapCard or (tr.wrapChip and ctx:visible(tr.wrapChip) and tr.wrapChip) or nil
		if not target then ctx:na("neither the Wrapped card nor the chip is on Trips") end
		pcall(function() ctx.me:click(target) end)
		ctx:note("tap the Wrapped " .. (target == tr.wrapCard and "card" or "chip"))
		ctx:advance(1)
		if not w.Shown() then ctx:cannot("the story did not play") end
		return w, w.Story()
	end
	local WRAP_WHEN = function(sit) return is(sit, "role", "rider") and is(sit, "combat", "no") and sit.session ~= "first" and is(sit, "ride", "none") end

	Hunt.promise{
		id = "wrapped.two_rides_no_card",
		area = "Wrapped",
		text = "With only two rides last month, Trips does not offer the Wrapped card.",
		source = "Wrapped header (the month before with 3 or more rides gives the card)",
		kind = "scenario",
		needs = { day = "next_month" },
		when = WRAP_WHEN,
		check = function(ctx)
			WR(ctx)
			local env = ctx.me.env
			-- only the two rides of last month: drop what the saved data may hold from that month
			local t = env.date("*t", env.time())
			local first = env.time() - (t.day + 40) * 86400
			local last = env.time() - t.day * 86400
			for i = #ctx.W.db.rides, 1, -1 do
				local at = tonumber(ctx.W.db.rides[i].at)
				if at and at > first and at <= last then table.remove(ctx.W.db.rides, i) end
			end
			ridesLastMonth(ctx, 2)
			atTrips(ctx)
			if cardUp(ctx) then ctx:fail("It is the 2nd of the month, you had two rides last month, and Trips offers the Wrapped card.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "wrapped.not_after_the_tenth",
		area = "Wrapped",
		text = "Late in a month, the Wrapped card for the month before is not offered any more: it is for the first ten days.",
		source = "Wrapped header (first 10 days)",
		kind = "scenario",
		needs = { day = "same" },
		when = WRAP_WHEN,
		check = function(ctx)
			WR(ctx)
			ridesLastMonth(ctx, 4)
			atTrips(ctx)
			if cardUp(ctx) then ctx:fail("It is the 17th, you had four rides last month, and Trips offers the Wrapped card.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "wrapped.card_shows_once_if_ignored",
		area = "Wrapped",
		text = "The Wrapped card is shown once: if you leave Trips without tapping it, it is not shown again that month, and the small Wrapped chip is there instead.",
		source = "Wrapped header (the card once; afterwards the chip)",
		kind = "scenario",
		needs = { day = "next_month" },
		when = WRAP_WHEN,
		check = function(ctx)
			WR(ctx)
			ridesLastMonth(ctx, 3)
			atTrips(ctx)
			if not cardUp(ctx) then ctx:na("no card was offered (trips.wrapped_card_due says so)") end
			clickTab(ctx, "Ride")
			ctx:advance(1)
			atTrips(ctx)
			local up, tr = cardUp(ctx)
			if up then ctx:fail("You leave Trips without tapping the Wrapped card, come back, and the same card is offered again.", onScreen(ctx)) end
			if not (tr.wrapChip and ctx:visible(tr.wrapChip)) then
				ctx:fail("You leave Trips without tapping the Wrapped card, come back, and there is no way to see your month.", onScreen(ctx))
			end
		end,
	}


	Hunt.promise{
		id = "wrapped.driver_slide_when_you_drove",
		area = "Wrapped",
		text = "If you also gave rides as a driver that month, your Wrapped has a Behind the portal slide with how many rides you gave and what you took.",
		source = "Wrapped header (the driver's slide when they drove that month; sentence-case kicker)",
		kind = "scenario",
		needs = { day = "next_month" },
		when = WRAP_WHEN,
		check = function(ctx)
			local month, tm = ridesLastMonth(ctx, 3)
			local env = ctx.me.env
			local db = ctx.W.db
			db.drive = db.drive or {}
			db.drive.log = db.drive.log or {}
			db.drive.log.rides = db.drive.log.rides or {}
			local at = env.time({ year = tm.year, month = tm.month, day = 12, hour = 20, min = 0, sec = 0 })
			table.insert(db.drive.log.rides, ("%d,%d,%s,%s,%s,%d"):format(at, 20000, "Some Rider", "Ratchet", "paid", 20000))
			table.insert(db.drive.log.rides, ("%d,%d,%s,%s,%s,%d"):format(at + 600, 30000, "Other Rider", "Ratchet", "paid", 30000))
			ctx:note("two rides given as a driver last month are in the driver's log")
			atTrips(ctx)
			local w, st = openStory(ctx)
			for _ = 1, #st.slides - 1 do
				if has(ctx, "Behind the portal") then break end
				w.Next() ctx:advance(0.8)
			end
			if not has(ctx, "Behind the portal") then
				ctx:fail("You gave two rides as a driver last month and your Wrapped has no Behind the portal slide.", onScreen(ctx))
			end
			if not has(ctx, "2 rides given") then
				ctx:fail("You gave two rides as a driver last month and the Behind the portal slide does not say 2 rides given.", onScreen(ctx))
			end
			if not has(ctx, "5g") then
				ctx:fail("You took 3g and 2g driving last month and the Behind the portal slide does not say 5g taken.", onScreen(ctx))
			end
		end,
	}


	Hunt.promise{
		id = "wrapped.summary_one_is_singular",
		area = "Wrapped",
		text = "Wrapped says '1 place' and '1 summon' for one, not '1 places' or '1 summons', on every slide including the last.",
		source = "inferred (the first slide already says 1 place)",
		kind = "scenario",
		needs = { day = "next_month" },
		when = WRAP_WHEN,
		check = function(ctx)
			ridesLastMonth(ctx, 3)
			atTrips(ctx)
			local w, st = openStory(ctx)
			for _ = 1, #st.slides do
				for _, t in ipairs(plain(ctx)) do
					if t:find("%f[%d]1 places") or t:find("%f[%d]1 summons") or t:find("%f[%d]1 rides") then
						ctx:fail("Your Wrapped says '" .. t .. "' for a single place.", onScreen(ctx))
					end
				end
				w.Next() ctx:advance(0.8)
			end
		end,
	}

	Hunt.promise{
		id = "wrapped.hover_pauses_the_story",
		area = "Wrapped",
		text = "While you hold the mouse over your Wrapped story it stays on the slide, and it moves on about six seconds after you move away.",
		source = "Wrapped header and tooltip (Hover to pause)",
		kind = "scenario",
		needs = { day = "next_month" },
		when = WRAP_WHEN,
		check = function(ctx)
			ridesLastMonth(ctx, 3)
			atTrips(ctx)
			local w, st = openStory(ctx)
			local half = st.right
			if not half then ctx:cannot("no right half to hover") end
			local enter, leave = half:GetScript("OnEnter"), half:GetScript("OnLeave")
			if not (enter and leave) then ctx:cannot("the half does not listen to the mouse") end
			local at = st.index
			enter(half)
			ctx:note("the mouse rests on the story")
			ctx:advance(20)
			if st.index ~= at then
				ctx:fail("You rest the mouse on your Wrapped story to read a slide and it moves on anyway.", ("slide %d then %d"):format(at, st.index))
			end
			leave(half)
			ctx:note("the mouse moves away")
			ctx:advance(7)
			if st.index == at then
				ctx:fail("You move the mouse off your Wrapped story and it never moves on again.", ("still slide %d seven seconds later"):format(at))
			end
		end,
	}

	Hunt.promise{
		id = "wrapped.tap_halves_with_the_mouse",
		area = "Wrapped",
		text = "Clicking the right half of your Wrapped story goes to the next slide and clicking the left half goes back.",
		source = "Wrapped header and tooltip (Tap the left or right half to move through your month)",
		kind = "scenario",
		needs = { day = "next_month" },
		when = WRAP_WHEN,
		check = function(ctx)
			ridesLastMonth(ctx, 3)
			atTrips(ctx)
			local w, st = openStory(ctx)
			local at = st.index
			local ok = pcall(ctx.me.clickOn, ctx.me, st.right)
			if not ok then ctx:na("the right half could not be clicked where it is drawn") end
			ctx:note("click the right half")
			ctx:advance(0.5)
			if st.index ~= at + 1 then
				ctx:fail("You click the right half of your Wrapped story and it does not go to the next slide.", ("slide %d then %d"):format(at, st.index))
			end
			local ok2 = pcall(ctx.me.clickOn, ctx.me, st.left)
			if not ok2 then ctx:na("the left half could not be clicked where it is drawn") end
			ctx:note("click the left half")
			ctx:advance(0.5)
			if st.index ~= at then
				ctx:fail("You click the left half of your Wrapped story and it does not go back a slide.", ("slide %d then %d"):format(at + 1, st.index))
			end
		end,
	}

	Hunt.promise{
		id = "wrapped.share_pill_in_a_group",
		area = "Wrapped",
		text = "On the last Wrapped slide Share is there when you are in a party or raid, and not when you are alone; your click posts one line to your group, and it cannot be posted again within a minute.",
		source = "Wrapped header (Share: the player's click posts to party or raid, at most once a minute per month)",
		kind = "scenario",
		needs = { day = "next_month" },
		when = function(sit) return WRAP_WHEN(sit) and is(sit, "group", { solo = true, party = true, raid = true }) end,
		check = function(ctx)
			ridesLastMonth(ctx, 3)
			atTrips(ctx)
			local w, st = openStory(ctx)
			for _ = 1, #st.slides - 1 do w.Next() ctx:advance(0.8) end
			ctx:advance(0.5)
			local grouped = (ctx.facts.groupKind == "party" or ctx.facts.groupKind == "raid")
			local up = st.share ~= nil and ctx:visible(st.share)
			if not grouped then
				if up then ctx:fail("You are alone and the last Wrapped slide offers Share.", onScreen(ctx)) end
				return
			end
			if not up then ctx:fail("You are in a group and the last Wrapped slide has no Share button.", onScreen(ctx)) end
			local btn = ctx.me.env.WuberShareButton
			if not (btn and btn:IsShown()) then ctx:cannot("the share overlay is not there") end
			local before = #(ctx.w.groupPosts or {})
			ctx.me:click(btn)
			ctx:note("click Share")
			ctx:advance(1)
			local posts = ctx.w.groupPosts or {}
			if #posts ~= before + 1 then
				ctx:fail(("You click Share on your Wrapped and %d lines go to your group, not one."):format(#posts - before), onScreen(ctx))
			end
			local line = posts[#posts] and posts[#posts].text or ""
			if not line:find("on Wuber", 1, true) then ctx:fail("The line Share posts for your Wrapped does not say it is about Wuber.", line) end
			ctx:advance(1)
			if st.share and ctx:visible(st.share) then
				ctx:fail("You have just shared your Wrapped and Share is still there to post it again.", onScreen(ctx))
			end
			ctx:advance(65)
			w.Close() ctx:advance(0.5)
			atTrips(ctx)
			local w2, st2 = openStory(ctx)
			for _ = 1, #st2.slides - 1 do w2.Next() ctx:advance(0.8) end
			ctx:advance(0.5)
			if not (st2.share and ctx:visible(st2.share)) then
				ctx:fail("A minute after sharing your Wrapped, Share is not there again.", onScreen(ctx))
			end
		end,
	}


	---------------------------------------------------------------------------------------------------------------
	-- Wishes (bounties), from the rider's side
	---------------------------------------------------------------------------------------------------------------
	local function atHome(ctx)
		if not shown(ctx) then
			if ctx.me.player.combat then ctx:na("in combat: the phone does not open") end
			ctx.me:slash("/wuber")
			ctx:note("/wuber")
			ctx:advance(0.3)
			if not shown(ctx) then ctx:cannot("the phone did not open on /wuber") end
			ctx:advance(2.2)
		end
		local w = ctx:mod("UI.Rider.Wrapped")
		if w and type(w.Shown) == "function" and w.Shown() then ctx:na("the Wrapped story is open over Home") end
		if overlayOpen(ctx) then
			clickTab(ctx, "Ride")
			ctx:advance(0.5)
			if overlayOpen(ctx) then ctx:na("Settings, Help or the report stays on top after a tab is clicked") end
		end
		if kit(ctx).tab ~= "Ride" then clickTab(ctx, "Ride") end
		if kit(ctx).screen ~= "home" then
			pcall(function() ctx.W.UI.Show("ride") end)
			ctx:advance(0.5)
		end
		if kit(ctx).screen ~= "home" then ctx:na("Home is not reachable (" .. tostring(kit(ctx).screen) .. ")") end
		ctx:advance(1)
	end
	-- the pin button's handler: a bounty for a place nobody serves
	local function pin(ctx, place, copper)
		local UI = ctx.W.UI
		if type(UI.PinBounty) ~= "function" then ctx:cannot("no bounty in this Wuber") end
		UI.PinBounty(place, copper)
		ctx:note("pin a bounty for " .. place .. " at " .. tostring(copper))
		ctx:advance(1.5)
		if not ctx.W.Bounty.Mine() then ctx:cannot("the bounty could not be pinned") end
	end
	local function demandOf(ctx, c, place)
		for _, d in ipairs(c.W.Bounty.Demand()) do
			if d.place == place then return d end
		end
		return nil
	end
	-- drivers hear a wish within a few seconds; the network's pacing can make it a quarter of a minute
	local function waitDemand(ctx, c, place, secs)
		for _ = 1, secs do
			local d = demandOf(ctx, c, place)
			if d then return d end
			ctx:advance(1)
		end
		return demandOf(ctx, c, place)
	end
	local WISH_WHEN = function(sit) return riderDay(sit) and is(sit, "net", { one = true, many = true, late = true, none = true }) end
	local function peerDriver(ctx)
		local c = ctx.peers and ctx.peers.driver
		if not c then ctx:na("no driver window to look through") end
		return c
	end

	Hunt.promise{
		id = "wish.drivers_see_it",
		area = "Wish",
		text = "When you pin a bounty for a place, the Wuber drivers on your realm see that a rider wants that place, and what you offer.",
		source = "Net.Bounty header (so drivers see the demand); CHANGELOG 2.3.2 (bounties)",
		kind = "scenario",
		when = function(sit) return riderDay(sit) and is(sit, "net", { one = true, many = true, late = true }) end,
		check = function(ctx)
			conditions(ctx)
			local c = peerDriver(ctx)
			pin(ctx, "Ironforge", 8000)
			local d = waitDemand(ctx, c, "Ironforge", 30)
			if not d then ctx:fail("You pin a bounty for Ironforge and a driver on your realm, open for business, does not see that anyone wants it.", onScreen(ctx)) end
			if d.riders ~= 1 then ctx:fail(("One rider wants Ironforge and a driver sees %d riders."):format(d.riders)) end
			if d.low ~= 8000 then ctx:fail(("You offer 80s for Ironforge and the driver sees %d copper."):format(d.low)) end
		end,
	}

	Hunt.promise{
		id = "wish.chip_counts_down",
		area = "Wish",
		text = "Your bounty's chip on Home says how many minutes are left, and the number goes down as time passes.",
		source = "Home chip (Your bounty: 60s for Gadgetzan / 24 min); Net.Bounty header (30 minutes)",
		kind = "scenario",
		when = WISH_WHEN,
		check = function(ctx)
			conditions(ctx)
			atHome(ctx)
			pin(ctx, "Ironforge", 8000)
			local function left()
				if not (has(ctx, "Your bounty:", true) and has(ctx, "for Ironforge", true)) then return nil end
				local s = ctx:mod("UI.Window")
				local home = s and s.screens and s.screens.home
				local sub = home and home.bountyChip and home.bountyChip.row and home.bountyChip.row.sub
				if sub and ctx:visible(sub) then
					local m = tostring(sub:GetText() or ""):match("^(%d+) min$")
					if m then return tonumber(m) end
				end
				local t = has(ctx, "^%d+ min$", false)
				return t and tonumber(t:match("^(%d+) min$"))
			end
			local a = left()
			if not a then ctx:fail("You pin a bounty on Home and the chip does not say how many minutes are left.", onScreen(ctx)) end
			if a < 28 or a > 30 then ctx:fail(("A bounty you pinned a moment ago says %d minutes left, not about 30."):format(a), onScreen(ctx)) end
			ctx:advance(600)
			local b = left()
			if not b then ctx:fail("Ten minutes after you pinned a bounty its chip is gone or does not say the minutes left.", onScreen(ctx)) end
			if b < 18 or b > 21 then ctx:fail(("Ten minutes after you pinned a bounty its chip says %d minutes left, not about 20."):format(b), onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "wish.ends_after_thirty_minutes",
		area = "Wish",
		text = "A bounty ends by itself after 30 minutes: the chip goes and drivers stop seeing it.",
		source = "Net.Bounty header (ends by time, 30 min); chip tooltip",
		kind = "scenario",
		when = function(sit) return riderDay(sit) and is(sit, "net", { one = true, many = true, late = true }) end,
		check = function(ctx)
			conditions(ctx)
			local c = peerDriver(ctx)
			atHome(ctx)
			pin(ctx, "Ironforge", 8000)
			ctx:advance(1850)
			if ctx.W.Bounty.Mine() or has(ctx, "Your bounty: .- for Ironforge", false) then
				ctx:fail("Thirty-one minutes after you pinned a bounty it is still yours: its chip is still up.", onScreen(ctx))
			end
			if demandOf(ctx, c, "Ironforge") then
				ctx:fail("Thirty-one minutes after a rider pinned a bounty, drivers still see that they want the place.", "demand still listed")
			end
		end,
	}

	Hunt.promise{
		id = "wish.newer_replaces_older",
		area = "Wish",
		text = "You have one bounty at a time: pinning another place replaces the first, on your Home and for the drivers.",
		source = "Net.Bounty header (one at a time; a newer one replaces the older)",
		kind = "scenario",
		when = function(sit) return riderDay(sit) and is(sit, "net", { one = true, many = true, late = true }) end,
		check = function(ctx)
			conditions(ctx)
			local c = peerDriver(ctx)
			atHome(ctx)
			pin(ctx, "Ironforge", 8000)
			ctx:advance(70)
			pin(ctx, "Darnassus", 9000)
			ctx:advance(70)
			waitDemand(ctx, c, "Darnassus", 30)
			local mine = ctx.W.Bounty.Mine()
			if not (mine and mine.place == "Darnassus") then
				ctx:fail("You pin Ironforge and then Darnassus and your bounty is not for Darnassus.", onScreen(ctx))
			end
			if has(ctx, "Your bounty: .- for Ironforge", false) then ctx:fail("You pin Ironforge and then Darnassus and Home still shows the Ironforge bounty.", onScreen(ctx)) end
			if not demandOf(ctx, c, "Darnassus") then
				ctx:fail("You replace your bounty with one for Darnassus and the drivers never see Darnassus wanted.", "no demand for Darnassus")
			end
			if demandOf(ctx, c, "Ironforge") then
				ctx:fail("You replace your Ironforge bounty with one for Darnassus and the drivers still see Ironforge wanted too.", "demand for Ironforge and Darnassus")
			end
		end,
	}


	Hunt.promise{
		id = "wish.replaced_within_a_minute_reaches_drivers",
		area = "Wish",
		text = "You pin one place and, about 20 seconds later, change your mind and pin another: within a minute and a half every driver shows the second place, not the first.",
		source = "Net.Bounty header (one at a time; a newer one replaces the older); HUNT-104",
		kind = "scenario",
		when = function(sit) return riderDay(sit) and is(sit, "net", { one = true, many = true, late = true }) end,
		check = function(ctx)
			conditions(ctx)
			local c = peerDriver(ctx)
			atHome(ctx)
			pin(ctx, "Ironforge", 8000)
			ctx:advance(18.5)
			pin(ctx, "Darnassus", 9000)
			ctx:advance(90)
			local mine = ctx.W.Bounty.Mine()
			if not (mine and mine.place == "Darnassus") then ctx:cannot("the bounty is not for Darnassus on the rider side") end
			if not demandOf(ctx, c, "Darnassus") then
				ctx:fail("You pin Ironforge, change it to Darnassus 20 seconds later, and ninety seconds after that the drivers do not see Darnassus wanted.",
					demandOf(ctx, c, "Ironforge") and "drivers still show Ironforge" or "no demand")
			end
			if demandOf(ctx, c, "Ironforge") then
				ctx:fail("You change your bounty to Darnassus within a minute and the drivers still show Ironforge wanted.", "demand for Ironforge")
			end
		end,
	}

	Hunt.promise{
		id = "wish.served_ends_it_and_says_so",
		area = "Wish",
		text = "When a driver opens for the place you pinned, your bounty ends and Wuber tells you the driver now goes there.",
		source = "Moments (X now summons to Ironforge. Your bounty ended.); Net.Bounty header (ends when an open driver serves the place)",
		kind = "scenario",
		when = WISH_WHEN,
		check = function(ctx)
			conditions(ctx)
			atHome(ctx)
			pin(ctx, "Ironforge", 8000)
			local _, name = driverOpens(ctx, "Ironforge", 9000)
			local t = waitToast(ctx, "Your bounty ended", 16)
			if not t then
				ctx:fail(("You pin a bounty for Ironforge, %s opens there, and Wuber does not tell you your bounty ended."):format(name), onScreen(ctx))
			end
			if ctx.W.Bounty.Mine() then ctx:fail("A driver opens for your bounty's place and the bounty is still yours.", onScreen(ctx)) end
			ctx:advance(3)
			if has(ctx, "Bounty: Ironforge", true) then ctx:fail("A driver opens for your bounty's place and its chip stays on Home.", onScreen(ctx)) end
		end,
	}



	---------------------------------------------------------------------------------------------------------------
	-- Learned flight times, shared between Wuber users
	---------------------------------------------------------------------------------------------------------------
	local FLY_WHEN = function(sit) return is(sit, "role", "rider") and is(sit, "ride", "none") and is(sit, "combat", "no") and is(sit, "place", "town") and is(sit, "cost", "plain") and sit.session ~= "first" end
	local function flightsOk(ctx)
		local W = ctx.W
		if not (type(W.FlightTime) == "function" and W.FLY) then ctx:cannot("this Wuber has no W.FlightTime") end
		if W.Faction and W.Faction() ~= "H" then ctx:cannot("the shared flights below are Horde ones") end
	end
	-- another Wuber user tells me (a whisper of the pool's kind) what a flight took
	local function hearsAbout(ctx, from, a, b, secs, ageMinutes)
		ctx.w:inject(from, ("F~1~H~%s:%s::%d:%d"):format(a, b, ageMinutes or 0, secs), "WHISPER", ctx.me)
		ctx:note(("%s tells me %s to %s took %d s (%d min ago)"):format(from, a, b, secs, ageMinutes or 0))
		ctx:advance(1)
	end
	local function strangerName(ctx, n) return "Wuber Friend " .. n end


	Hunt.promise{
		id = "flyshare.own_flight_beats_heard",
		area = "Flight times",
		text = "A flight you flew yourself is the time Wuber keeps, even when another user later tells you a different one.",
		source = "Core.Flights header (own always wins over shared)",
		kind = "scenario",
		when = FLY_WHEN,
		check = function(ctx)
			flightsOk(ctx)
			ctx.w:move(ctx.name, "Thunder Bluff")
			ctx:advance(1)
			ctx.w:openTaxiMap(ctx.me, { { name = "Thunder Bluff, Mulgore", type = "CURRENT" },
				{ name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50 } })
			ctx:advance(0.6)
			ctx.w:fly(ctx.me, 2, 150, "Orgrimmar")
			ctx:note("fly to Orgrimmar, 150 seconds")
			ctx:advance(156)
			local own, src = ctx.W.FlightTime("Thunder Bluff", "Orgrimmar")
			if src ~= "own" then ctx:na("the flight was not recorded (flights.flight_time_remembered says so)") end
			hearsAbout(ctx, strangerName(ctx, 2), "thunder bluff", "orgrimmar", 60)
			local t, s = ctx.W.FlightTime("Thunder Bluff", "Orgrimmar")
			if s ~= "own" or math.abs(t - own) > 1 then
				ctx:fail("You flew Thunder Bluff to Orgrimmar yourself in 150 seconds, another user says 60, and Wuber stops using the time you flew.", ("Wuber says %s (%s)"):format(tostring(t), tostring(s)))
			end
		end,
	}



	Hunt.promise{
		id = "flyshare.heard_time_not_about_on_booking",
		area = "Flight times",
		text = "On the booking screen, a flight time that another user measured is written as it is, without 'about'.",
		source = "hard rule: estimates are labelled 'about' (a heard time is not an estimate)",
		kind = "scenario",
		when = FLY_WHEN,
		check = function(ctx)
			flightsOk(ctx)
			local d = ctx.w:addClient("Mia Runner", { spot = "Orgrimmar", class = "WARLOCK" })
			if d.W.Char then d.W.Char().wizard = true end
			if not (d.W.Driver and d.W.Driver.SetOnline and d.W.Driver.SetOnline(true) ~= false) then ctx:cannot("the driver could not go online") end
			ctx:advance(15)
			if not (ctx.W.drivers and ctx.W.drivers["mia runner"]) then ctx:cannot("the driver's beacon never reached me") end
			ctx.w:move(ctx.name, "Thunder Bluff")
			ctx:advance(1)
			hearsAbout(ctx, strangerName(ctx, 6), "thunder bluff", "orgrimmar", 95)
			ctx.W.UI.Toggle(true)
			ctx:advance(2.5)
			ctx.W.UI.Show("confirm", "mia runner")
			ctx:advance(1)
			local secs, how, measured = ctx.W.TravelSaved("Orgrimmar")
			if not secs then ctx:cannot("no travel time for the booking") end
			local dur = ctx.W.UI.Duration and ctx.W.UI.Duration(secs) or nil
			if not dur then ctx:cannot("no UI.Duration") end
			local found, about
			for _, t in ipairs(plain(ctx)) do
				if t:find(dur, 1, true) then found = t about = t:lower():find("about " .. dur:lower(), 1, true) ~= nil end
			end
			if not found then ctx:na("the booking does not show the flight time as " .. dur) end
			if measured and about then
				ctx:fail("Another user told you how long the flight to Orgrimmar takes and the booking still says 'about " .. dur .. "'.", found)
			end
			if not measured then ctx:fail("Another user told you how long the flight to Orgrimmar takes and the booking does not use it.", found) end
		end,
	}


	---------------------------------------------------------------------------------------------------------------
	-- The driver-found screen and the booking screen's smaller promises
	---------------------------------------------------------------------------------------------------------------
	local ASRIDER = function(sit) return is(sit, "role", "rider") and is(sit, "combat", "no") and sit.session ~= "first" end
	local function peerOf(ctx)
		local c = ctx.peers and ctx.peers.driver
		if not c then ctx:na("no driver window") end
		return c
	end
	-- the player opens Wuber on the ride screen
	local function openRide(ctx)
		if not shown(ctx) then
			ctx.me:slash("/wuber")
			ctx:note("/wuber")
			ctx:advance(3)
		end
		if overlayOpen(ctx) then
			-- Settings, Help or the report are over the ride: the player presses Escape
			ctx.me:pressEscape()
			ctx:note("press Escape over Settings")
			ctx:advance(1)
			if not shown(ctx) then ctx.me:slash("/wuber") ctx:advance(2.5) end
			if overlayOpen(ctx) then ctx:na("Settings, Help or the report stays on top after Escape") end
		end
		if kit(ctx).tab ~= "Ride" then clickTab(ctx, "Ride") end
		ctx:advance(0.5)
		if kit(ctx).screen ~= "found" then ctx:na("the ride screen is not what Wuber shows (" .. tostring(kit(ctx).screen) .. ")") end
	end

	Hunt.promise{
		id = "found.passphrase_when_driver_shows_it",
		area = "Found",
		text = "When your driver has Show ride passphrase on, once you are in their group you see two words under their card, and they are the same two words the driver sees.",
		source = "Ride screen (Passphrase: X Y - your driver sees the same words); Settings > Driving > Show ride passphrase",
		kind = "scenario",
		needs = { ride = "summoning" },
		when = ASRIDER,
		check = function(ctx)
			local c = peerOf(ctx)
			if not (c.W.Drive and type(c.W.Drive.SetOpt) == "function") then ctx:na("this driver's Wuber has no Show ride passphrase setting") end
			c.W.Drive.SetOpt("showPass", true)
			ctx:note("the driver turns Show ride passphrase on")
			ctx:advance(70)
			openRide(ctx)
			local line = has(ctx, "Passphrase:", true)
			if not line then
				ctx:fail("Your driver has Show ride passphrase on, you are in their group waiting for the summon, and no passphrase is on your ride screen.", onScreen(ctx))
			end
			local words = line:match("Passphrase:%s*(%a+ %a+)")
			if not words then ctx:fail("The passphrase line on your ride screen does not hold two words.", line) end
			local id = ctx.W.ride and ctx.W.ride.id
			local theirs = id and c.W.Passphrase(id, ctx.W.myKey)
			if theirs and theirs ~= words then
				ctx:fail(("Your ride screen says the passphrase is '%s' and your driver's side says '%s'."):format(words, theirs), line)
			end
		end,
	}

	Hunt.promise{
		id = "found.passphrase_hidden_when_driver_does_not_show",
		area = "Found",
		text = "When your driver does not have Show ride passphrase on (the usual), your ride screen shows no passphrase.",
		source = "Settings > Driving > Show ride passphrase (off unless a driver turns it on)",
		kind = "scenario",
		needs = { ride = "summoning" },
		when = ASRIDER,
		check = function(ctx)
			local c = peerOf(ctx)
			if not (c.W.Drive and type(c.W.PassphraseOn) == "function") then ctx:na("this driver's Wuber has no passphrase") end
			if c.W.PassphraseOn() == true then ctx:na("this driver shows the passphrase") end
			ctx:advance(70)
			openRide(ctx)
			local line = has(ctx, "Passphrase", true)
			if line then ctx:fail("Your driver does not show a ride passphrase and your ride screen has one.", line) end
		end,
	}

	-- an enemy player stands by the driver, who sees the nameplate
	local function enemyAtDriver(ctx, c, fight)
		local me = ctx.me.player
		local faction = (me.faction or "Horde") == "Horde" and "Alliance" or "Horde"
		local spot = ctx.facts.drivers and ctx.facts.drivers[1] and ctx.facts.drivers[1].dest or "Ratchet"
		local p = ctx.w:addBot("Ally Foe", { faction = faction, class = "WARRIOR", spot = spot })
		c:showPlate(p.name)
		if fight then ctx.w:pvpFight(c, p.name) end
		ctx:note(fight and "an enemy player fights the driver" or "an enemy player stands by the driver")
		ctx:advance(70)
	end
	local function openConfirm(ctx, d)
		if not shown(ctx) then
			ctx.me:slash("/wuber")
			ctx:advance(3)
		end
		ctx.W.UI.Show("confirm", key(d.name))
		ctx:advance(1.5)
		if kit(ctx).screen ~= "confirm" then ctx:na("the booking screen is not what shows (" .. tostring(kit(ctx).screen) .. ")") end
	end

	Hunt.promise{
		id = "found.hot_drop_warned_before_booking",
		area = "Found",
		text = "When enemy players are by the driver you are about to book, the booking screen warns you of a hot drop, and says more when they have been fighting.",
		source = "Cards (Hot drop: Enemy players were seen near the summon spot / fought enemy players); BRIEF17 (hot-drop shield)",
		kind = "scenario",
		when = function(sit) return ASRIDER(sit) and is(sit, "ride", "none") and LIST_NETS[sit.net or "one"] == true and is(sit, "enemies", "none") and is(sit, "group", "solo") end,
		check = function(ctx)
			conditions(ctx)
			local c, d = firstDriver(ctx)
			if (tonumber(ctx.W.drivers[key(d.name)].danger) or 0) > 0 then ctx:na("the driver already shows danger") end
			openConfirm(ctx, d)
			if has(ctx, "Hot drop", true) then ctx:fail("The driver has no enemies near and the booking screen warns of a hot drop.", onScreen(ctx)) end
			enemyAtDriver(ctx, c, false)
			if not (ctx.W.drivers[key(d.name)] and (tonumber(ctx.W.drivers[key(d.name)].danger) or 0) > 0) then
				ctx:cannot("the driver's warning never reached me")
			end
			openConfirm(ctx, d)
			if not has(ctx, "Hot drop", true) then
				ctx:fail(("An enemy player stands by %s, you open their booking screen, and it does not warn of a hot drop."):format(d.name), onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "found.hot_drop_never_blocks_the_request",
		area = "Found",
		text = "A hot-drop warning never stops you: with it on screen you can still request the summon and your request reaches the driver.",
		source = "Cards (a warning, never blocks); BRIEF17 (hot-drop shield)",
		kind = "scenario",
		when = function(sit) return ASRIDER(sit) and is(sit, "ride", "none") and LIST_NETS[sit.net or "one"] == true and is(sit, "enemies", "none") and is(sit, "group", "solo") end,
		check = function(ctx)
			conditions(ctx)
			local c, d = firstDriver(ctx)
			enemyAtDriver(ctx, c, true)
			if not (ctx.W.drivers[key(d.name)] and (tonumber(ctx.W.drivers[key(d.name)].danger) or 0) > 0) then
				ctx:cannot("the driver's warning never reached me")
			end
			openConfirm(ctx, d)
			if not has(ctx, "Hot drop", true) then ctx:na("no hot-drop warning is up") end
			local ok = pcall(ctx.me.clickText, ctx.me, "^Request summon", { pattern = true })
			if not ok then ctx:fail("A hot-drop warning is up on the booking screen and there is no Request summon button.", onScreen(ctx)) end
			ctx:note("click Request summon")
			ctx:advance(4)
			if not (ctx.W.ride and ctx.W.ride.driverKey == key(d.name)) then
				ctx:fail(("You click Request summon with a hot-drop warning up and no ride with %s starts."):format(d.name), onScreen(ctx))
			end
		end,
	}

end
