-- Promises about flights (owner MAPS/FLIGHTS/TRIPS): what flying would cost and take (prices seen at a flight master, measured
-- times, estimates labelled "about", unknown numbers hidden). Written from the Core.Flights header and the hard rules the
-- player was promised ("Unknown numbers are hidden; estimates are labelled 'about'"; "Wuber remembers how long the
-- flight actually took", "never show a number we can't back").
return function(Hunt)

	local function ui(ctx)
		local K = ctx:mod("UI.Kit")
		return K and K.ui or {}
	end
	local function shown(ctx)
		local UI = ctx.W.UI
		return type(UI.IsShown) == "function" and UI.IsShown() == true
	end
	local function clickTab(ctx, name)
		local s = ui(ctx)
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
	-- Settings, Help or the bug report on top of a page: the player clicks a tab to get out of it
	local function overlayOpen(ctx)
		local UI = ctx.W.UI
		local s = ui(ctx)
		if s.settingsOpen == true or (UI.state and UI.state.settingsOpen == true) then return true end
		if type(UI.HelpShown) == "function" and UI.HelpShown() == true then return true end
		if type(UI.Bug) == "table" and type(UI.Bug.Shown) == "function" and UI.Bug.Shown() == true then return true end
		return false
	end
	local function leaveOverlays(ctx, tab)
		if overlayOpen(ctx) then
			clickTab(ctx, tab)
			ctx:advance(0.5)
			if overlayOpen(ctx) then ctx:na("Settings, Help or the report stays on top after a tab is clicked") end
		end
	end
	-- the player opens Wuber with /wuber, lets the splash end and stands on the Ride tab's Home page
	local function atHome(ctx)
		if not shown(ctx) then
			if ctx.me.player.combat then ctx:na("in combat: the phone does not open") end
			ctx.me:slash("/wuber")
			ctx:note("/wuber")
			ctx:advance(0.3)
			if not shown(ctx) then ctx:cannot("the phone did not open on /wuber") end
			ctx:advance(2.2)
		end
		leaveOverlays(ctx, "Ride")
		local s = ui(ctx)
		if s.tab ~= "Ride" then clickTab(ctx, "Ride") end
		if s.screen ~= "home" then
			pcall(function() ctx.W.UI.Show("ride") end)
			ctx:advance(0.5)
		end
		if ui(ctx).screen ~= "home" then ctx:na("the Ride tab is not on its Home page (" .. tostring(ui(ctx).screen) .. ")") end
	end
	local function unfolded(ctx)
		local F = ctx.W.UI.Fold
		return F and type(F.IsUnfolded) == "function" and F.IsUnfolded() == true
	end
	local function worldMod(ctx)
		local m = ctx:mod("UI.Rider.WorldMap")
		if not (m and m.cache and m.cache.maps) then ctx:cannot("this Wuber has no World view (UI.Rider.WorldMap)") end
		return m
	end
	-- the world view that is on screen now (nil when none)
	local function shownWorld(ctx)
		local m = worldMod(ctx)
		for _, wm in pairs(m.cache.maps) do
			if wm.mode == "world" and wm.view and ctx:visible(wm.view) then return wm end
		end
		return nil
	end
	local function plainTexts(ctx)
		local out = {}
		for _, t in ipairs(ctx:texts()) do out[#out + 1] = (t:gsub("|T.-|t", "")) end
		return out
	end
	local function onScreen(ctx) return "on screen: " .. table.concat(plainTexts(ctx), " | ") end
	local function has(ctx, text)
		for _, t in ipairs(plainTexts(ctx)) do if t == text then return true end end
		return false
	end
	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		if type(want) == "table" then return want[v] == true end
		return v == want
	end

	local function plain(s) return (tostring(s or ""):gsub("|T.-|t", "")) end
	local function flightsOk(ctx)
		local W = ctx.W
		if not (type(W.FlightTime) == "function" and type(W.FlightCost) == "function") then ctx:cannot("this Wuber has no W.FlightTime / W.FlightCost") end
	end

	-- the flight master at Thunder Bluff lists Orgrimmar (slot 2) with a price
	local function tbMap(ctx, cost)
		ctx.w:move(ctx.name, "Thunder Bluff")
		ctx:advance(1)
		ctx.w:openTaxiMap(ctx.me, { { name = "Thunder Bluff, Mulgore", type = "CURRENT" },
			{ name = "Orgrimmar, Durotar", type = "REACHABLE", cost = cost or 50 } })
		ctx:note("open the flight map at Thunder Bluff")
		ctx:advance(0.6)
	end

	-- the player flies Thunder Bluff to Orgrimmar and it takes 'secs' seconds
	local function fly(ctx, secs)
		tbMap(ctx)
		ctx.w:fly(ctx.me, 2, secs, "Orgrimmar")
		ctx:note(("fly to Orgrimmar, %d seconds"):format(secs))
		ctx:advance(secs + 6)
	end

	Hunt.promise{
		id = "flights.flight_time_remembered",
		area = "Flights",
		text = "When you fly from one town to another, Wuber remembers how long it really took; flying it again within 10 percent keeps the shorter time.",
		source = "Core.Flights header (measured flight times); CHANGELOG 2.3.0 (your own flights)",
		kind = "scenario",
		when = function(sit) return is(sit, "ride", "none") and is(sit, "combat", "no") and is(sit, "place", "town") and is(sit, "cost", "plain") and sit.session ~= "first" end,
		check = function(ctx)
			flightsOk(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			fly(ctx, 150)
			local t, src = ctx.W.FlightTime("Thunder Bluff", "Orgrimmar")
			if not (type(t) == "number" and math.abs(t - 150) <= 3 and src == "own") then
				ctx:fail("You fly from Thunder Bluff to Orgrimmar in 150 seconds and Wuber does not remember it as your own flight time.",
					("Wuber says %s (%s)"):format(tostring(t), tostring(src)))
			end
			fly(ctx, 160)
			local t2 = ctx.W.FlightTime("Thunder Bluff", "Orgrimmar")
			if not (type(t2) == "number" and math.abs(t2 - 150) <= 3) then
				ctx:fail("You fly the same route again, ten seconds slower, and Wuber does not keep the shorter time.", ("Wuber says %s after 150 then 160"):format(tostring(t2)))
			end
		end,
	}

	Hunt.promise{
		id = "flights.measured_time_not_about",
		area = "Flights",
		text = "A flight time you measured yourself is shown as it is, without 'about'.",
		source = "hard rule: estimates are labelled 'about' (so a measured number is not)",
		kind = "scenario",
		when = function(sit) return is(sit, "ride", "none") and is(sit, "combat", "no") and is(sit, "place", "town") and is(sit, "cost", "plain") and sit.session ~= "first" end,
		check = function(ctx)
			flightsOk(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			fly(ctx, 150)
			-- a driver opens in Orgrimmar: the booking says what flying there takes
			local d = ctx.w:addClient("Mia Runner", { spot = "Orgrimmar", class = "WARLOCK" })
			if d.W.Char then d.W.Char().wizard = true end
			if not (d.W.Driver and d.W.Driver.SetOnline and d.W.Driver.SetOnline(true) ~= false) then ctx:cannot("the driver could not go online") end
			ctx:advance(15)
			if not (ctx.W.drivers and ctx.W.drivers["mia runner"]) then ctx:cannot("the driver's beacon never reached me") end
			ctx.w:move(ctx.name, "Thunder Bluff")
			ctx:advance(1)
			ctx.W.UI.Toggle(true)
			ctx:advance(2.5)
			ctx.W.UI.Show("confirm", "mia runner")
			ctx:advance(1)
			-- what flying takes the player: the walk to the flight master and the flight he measured
			local secs, how, measured = ctx.W.TravelSaved("Orgrimmar")
			if not (secs and measured) then ctx:cannot("the measured flight is not what the booking uses here") end
			local dur = ctx.W.UI.Duration and ctx.W.UI.Duration(secs) or nil
			if not dur then ctx:cannot("no UI.Duration") end
			local found, about
			for _, t in ipairs(plainTexts(ctx)) do
				if t:find(dur, 1, true) then found = t about = t:lower():find("about " .. dur:lower(), 1, true) ~= nil end
			end
			if not found then ctx:na("the booking does not show the flight time as " .. dur) end
			if about then ctx:fail("You flew to Orgrimmar yourself and the booking still says 'about " .. dur .. "'.", found) end
		end,
	}

	Hunt.promise{
		id = "flights.estimate_says_about",
		area = "Flights",
		text = "A flight time Wuber has only worked out (never flown or heard) is written with 'about' on the booking screen, unless a price sits right beside it ('4 min · costing 2s 20c').",
		source = "hard rule: estimates are labelled 'about'; Core.Flights header (est: say about)",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") and sit.net ~= "none" and is(sit, "place", "town") and is(sit, "cost", "plain") end,
		check = function(ctx)
			flightsOk(ctx)
			local list = ctx.W.UI.Drivers()
			local d
			for _, x in ipairs(list) do
				-- Wuber can say how long flying there takes, and only by working it out (never flown or heard)
				local secs, how, measured = ctx.W.TravelSaved(x.dest)
				if secs and measured ~= true then d = x break end
			end
			if not d then ctx:na("no listed driver goes somewhere with only an estimated flight time") end
			if not shown(ctx) then ctx.W.UI.Toggle(true) ctx:advance(2.5) end
			ctx.W.UI.Show("confirm", d.key)
			ctx:advance(1)
			local ok = false
			for _, t in ipairs(plainTexts(ctx)) do
				local low = t:lower()
				if low:find("about %d+ ?[hms]") then ok = true end
				-- decisions round: a time directly beside its price drops 'about' ("4 min · costing 2s")
				if low:find("%d+ ?%a+ · costing") then ok = true end
			end
			if not ok then
				ctx:fail("The booking shows what flying takes, only worked out and not flown, and does not say 'about'.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "flights.unknown_price_hidden",
		area = "Flights",
		text = "When Wuber does not know what flying there costs, the booking screen shows no flying price and no saving against flying in gold.",
		source = "hard rule: unknown numbers are hidden; never show a number we can't back (SPEC5)",
		kind = "scenario",
		needs = { place = "fm_unknown", role = "rider" },
		when = function(sit) return is(sit, "combat", "no") and sit.net ~= "none" and is(sit, "ride", "none") end,
		check = function(ctx)
			flightsOk(ctx)
			local list = ctx.W.UI.Drivers()
			local d = list[1]
			if not d then ctx:na("no driver is listed") end
			if ctx.W.FlightCost(nil, d.dest) ~= nil then ctx:cannot("what flying costs is known in this build") end
			if not shown(ctx) then ctx.W.UI.Toggle(true) ctx:advance(2.5) end
			ctx.W.UI.Show("confirm", d.key)
			ctx:advance(1)
			for _, raw in ipairs(ctx:texts()) do
				local t = plain(raw)
				local l = t:lower()
				local money = raw:find("MoneyFrame", 1, true) or t:find("%d+[gsc]%f[%A]")
				if money and (l:find("vs flying", 1, true) or l:find("cheaper", 1, true) or l:find("dearer", 1, true) or l:find("saves ", 1, true) or l:find("^fly")) then
					ctx:fail("Wuber does not know what flying costs and the booking screen still gives a flying price or a saving in gold: '" .. t .. "'.", onScreen(ctx))
				end
			end
		end,
	}

	Hunt.promise{
		id = "flights.pin_never_covers_flight_point",
		area = "Flights",
		text = "A Wuber pin never covers a flight point: whenever the flight map is open and pins show, no price tag's rectangle crosses a flight point's button rectangle, and the holder and markers have the mouse off.",
		source = "UI.FlightPins header (marker centred on flight point, clickable price tag beside it)",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") and sit.net ~= "none" and is(sit, "place", "town") and is(sit, "ride", "none") end,
		check = function(ctx)
			local FP = ctx:mod("UI.FlightPins")
			if not (FP and type(FP.Pins) == "function") then ctx:cannot("this Wuber has no UI.FlightPins") end
			if ctx.W.db and ctx.W.db.flightOffers == false then ctx:na("flight map prices are off in Settings") end
			if ctx.me.player.combat then ctx:na("in combat") end
			local env = ctx.me.env
			local function rectOf(f)
				if type(f) ~= "table" or type(f.GetLeft) ~= "function" then return nil end
				local l, r, t, b = tonumber(f:GetLeft()), tonumber(f:GetRight()), tonumber(f:GetTop()), tonumber(f:GetBottom())
				if not (l and r and t and b) then return nil end
				local fs = (type(f.GetEffectiveScale) == "function" and tonumber(f:GetEffectiveScale())) or 1
				local us = (env and env.UIParent and type(env.UIParent.GetEffectiveScale) == "function" and tonumber(env.UIParent:GetEffectiveScale())) or 1
				local k = us > 0 and fs / us or 1
				return { l = l * k, r = r * k, t = t * k, b = b * k }
			end
			local tf = env and env.TaxiFrame
			if not (type(tf) == "table" and type(tf.IsShown) == "function" and tf:IsShown() == true) then
				local hasOrg = false
				for _, d in ipairs(ctx.W.UI.Drivers() or {}) do
					if type(d) == "table" and d.state == "open" and type(d.dest) == "string" and d.dest:find("Orgrimmar", 1, true) then
						hasOrg = true
						break
					end
				end
				if not hasOrg then
					local dname = (ctx.name == "Mia Runner") and "Anita Lift" or "Mia Runner"
					local d = ctx.w:addClient(dname, { spot = "Orgrimmar", class = "WARLOCK" })
					if d.W.Char then d.W.Char().wizard = true end
					if not (d.W.Driver and d.W.Driver.SetOnline and d.W.Driver.SetOnline(true) ~= false) then ctx:cannot("the driver could not go online") end
					ctx:advance(15)
				end
				tbMap(ctx)
				tf = env and env.TaxiFrame
			end
			if not (type(tf) == "table" and type(tf.IsShown) == "function" and tf:IsShown() == true) then ctx:na("the flight map did not open") end
			local pins = FP.Pins()
			if #pins == 0 then ctx:na("no flight map pins are showing") end
			local holder = env.WuberFlightPins
			if holder and type(holder.IsMouseEnabled) == "function" and holder:IsMouseEnabled() then
				ctx:fail("The flight map pin holder WuberFlightPins has the mouse enabled and can swallow clicks on the flight map.", "")
			end
			local mr = rectOf(tf)
			if not (mr and mr.r > mr.l and mr.t > mr.b) then ctx:cannot("TaxiFrame has no readable rectangle") end
			local mapArea = mr
			local routeMap = env.TaxiRouteMap
			if type(routeMap) == "table" and type(routeMap.IsShown) == "function" and routeMap:IsShown() == true then
				local rr = rectOf(routeMap)
				if rr and rr.r > rr.l and rr.t > rr.b then mapArea = rr end
			end
			local count = type(env.NumTaxiNodes) == "function" and (tonumber(env.NumTaxiNodes()) or 0) or 0
			count = math.min(count, 200)
			local btnRects = {}
			for i = 1, count do
				local btnRect
				local btn = env["TaxiButton" .. i]
				if type(btn) == "table" and type(btn.IsShown) == "function" and btn:IsShown() == true then
					local br = rectOf(btn)
					if br and br.r > br.l and br.t > br.b then btnRect = br end
				end
				if not btnRect and type(env.TaxiNodePosition) == "function" then
					local nx, ny = env.TaxiNodePosition(i)
					nx, ny = tonumber(nx), tonumber(ny)
					if nx and ny and not (nx == 0 and ny == 0) and nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
						local cx = mapArea.l + nx * (mapArea.r - mapArea.l)
						local cy = mapArea.t - ny * (mapArea.t - mapArea.b)
						btnRect = { l = cx - 9, r = cx + 9, t = cy + 9, b = cy - 9 }
					end
				end
				if btnRect then
					local name = type(env.TaxiNodeName) == "function" and env.TaxiNodeName(i) or ("#" .. i)
					btnRects[#btnRects + 1] = { name = name, r = btnRect }
				end
			end
			for _, p in ipairs(pins) do
				if p.marker and type(p.marker.IsMouseEnabled) == "function" and p.marker:IsMouseEnabled() then
					ctx:fail(("A Wuber flight map marker for %s has the mouse enabled and can block a flight point."):format(tostring(p.node)), "")
				end
				if p.tag and type(p.tag.IsShown) == "function" and p.tag:IsShown() == true then
					local tr = rectOf(p.tag)
					if tr then
						for _, b in ipairs(btnRects) do
							if tr.l < b.r.r and b.r.l < tr.r and tr.b < b.r.t and b.r.b < tr.t then
								ctx:fail(("A Wuber price tag for %s covers flight point %s."):format(tostring(p.node), tostring(b.name)),
									("tag=(%.1f,%.1f,%.1f,%.1f) btn=(%.1f,%.1f,%.1f,%.1f)"):format(tr.l, tr.b, tr.r, tr.t, b.r.l, b.r.b, b.r.r, b.r.t))
							end
						end
					end
				end
			end
		end,
	}

end
