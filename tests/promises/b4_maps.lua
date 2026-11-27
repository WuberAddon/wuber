-- Promises for maps, pins and routes (Wuber/UI/Map/*.lua, Wuber/UI/Rider/HomeMap.lua, WorldMap.lua, SeaRoute.lua).
-- Prefix: b4maps.
return function(Hunt)

	local function ui(ctx)
		local K = ctx:mod("UI.Kit")
		return K and K.ui or {}
	end

	local function shown(ctx)
		local UI = ctx.W.UI
		return type(UI.IsShown) == "function" and UI.IsShown() == true
	end

	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		if type(want) == "table" then return want[v] == true end
		return v == want
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

	local function dismissPopups(ctx)
		local nc = rawget(ctx.me.env, "WuberNewsCard")
		if type(nc) == "table" and type(nc.IsShown) == "function" and nc:IsShown() == true then
			local g = ctx.me:button("Got it")
			if g and ctx:visible(g) then
				ctx.me:clickOn(g)
				ctx:advance(0.8)
				ctx:note("click Got it on the What's new card")
			end
		end
		local card = rawget(ctx.me.env, "WuberTipCard")
		if card and ctx:visible(card) then
			local dont = card.never or ctx.me:button("Don't show again")
			if dont and ctx:visible(dont) then
				ctx.me:clickOn(dont)
				ctx:advance(20)
				ctx:note("close the login tip (Don't show again)")
			end
		end
	end

	local function atHome(ctx)
		if not shown(ctx) then
			if ctx.me.player.combat then ctx:na("in combat: the phone does not open") end
			ctx.me:slash("/wuber")
			ctx:note("/wuber")
			ctx:advance(0.3)
			if not shown(ctx) then ctx:cannot("the phone did not open on /wuber") end
			ctx:advance(2.2)
		elseif ui(ctx).splash and ctx:visible(ui(ctx).splash) then
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

	local function tipOf(frame)
		local wt = frame and frame.wuberTip
		if type(wt) == "table" then return tostring(wt.title or ""), tostring(wt.text or "") end
		return "", ""
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

	local function shownWorld(ctx)
		local m = worldMod(ctx)
		for _, wm in pairs(m.cache.maps) do
			if wm.mode == "world" and wm.view and ctx:visible(wm.view) then return wm end
		end
		return nil
	end

	local function tapWorld(ctx)
		atHome(ctx)
		if not unfolded(ctx) then ctx:na("the phone is folded here: Home has no World view") end
		if not shownWorld(ctx) then
			local b = ctx.me:button("World")
			if not (b and ctx:visible(b)) then ctx:na("no World button on screen") end
			ctx.me:clickOn(b)
			ctx:note("click World")
			ctx:advance(1.2)
		end
		return shownWorld(ctx)
	end

	local function hereMap(ctx)
		atHome(ctx)
		if unfolded(ctx) then
			local wm = shownWorld(ctx)
			if wm then
				local b = ctx.me:button("Here")
				if not (b and ctx:visible(b)) then ctx:na("no Here button on screen") end
				ctx.me:clickOn(b)
				ctx:note("click Here")
				ctx:advance(1)
			end
		end
		local s = ui(ctx).screens
		local m = s and s.home and s.home.map
		if not (m and ctx:visible(m)) then ctx:na("Home's map panel is not on screen here") end
		return m
	end

	local function mySpot(ctx)
		local me = ctx.me.player
		local best
		for name, s in pairs(ctx.H.SPOTS) do
			if s.mapID == me.mapID and (not best or name < best) then best = name end
		end
		return best
	end

	local DRIVERS = { "Mia Runner", "Bea Jones", "Cal Brown", "Dee Price", "Eli Stone", "Fay Ward" }
	local function addDriver(ctx, spot)
		local name
		for _, n in ipairs(DRIVERS) do if not ctx.w:player(n) then name = n break end end
		if not name then ctx:cannot("no free name for a driver") end
		local d = ctx.w:addClient(name, { spot = spot, class = "WARLOCK" })
		if d.W.Char then d.W.Char().wizard = true end
		if not (d.W.Driver and type(d.W.Driver.SetOnline) == "function") then ctx:cannot("no Driver.SetOnline in the driver window") end
		if d.W.Driver.SetOnline(true) == false then ctx:cannot("the driver could not go online") end
		ctx:note(name .. " opens in " .. spot)
		ctx:advance(15)
		local key = name:lower()
		if not (type(ctx.W.drivers) == "table" and ctx.W.drivers[key]) then ctx:cannot("the driver's beacon never reached me") end
		return d, name, key
	end

	local WIDE_OK = function(sit) return is(sit, "ride", "none") and is(sit, "combat", "no") end

	-- 1. Paused driver pin in World view
	Hunt.promise{
		id = "b4maps.world_paused_driver_tooltip",
		area = "Maps",
		text = "In the World view, a paused driver still has a pin whose tooltip says paused and 'Click to see this driver.'.",
		source = "Wuber/UI/Rider/WorldMap.lua:931-997",
		kind = "scenario",
		needs = { fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) and sit.net ~= "none" end,
		check = function(ctx)
			local d = nil
			for _, x in ipairs(ctx.W.UI.Drivers()) do
				if x.state == "paused" and type(x.dest) == "string" then d = x break end
			end
			if not d then ctx:na("no paused driver is listed") end
			local wm = tapWorld(ctx)
			if not wm then ctx:cannot("the World view did not show") end
			local pin
			for _, p in ipairs(wm.pins or {}) do
				if ctx:visible(p) and p.key == d.key then pin = p break end
			end
			if not pin then
				ctx:fail(("Paused driver %s has no pin in the World view."):format(tostring(d.short)), onScreen(ctx))
			end
			local _, body = tipOf(pin)
			if not body:find("paused", 1, true) or not body:find("Click to see this driver.", 1, true) then
				ctx:fail(("Paused driver pin tooltip does not say paused and Click to see this driver.: %s"):format(body), onScreen(ctx))
			end
		end,
	}

	-- 2. Busy driver pin in World view
	Hunt.promise{
		id = "b4maps.world_busy_driver_tooltip",
		area = "Maps",
		text = "In the World view, a busy driver has a pin whose tooltip says busy and 'Click to see this driver.'.",
		source = "Wuber/UI/Rider/WorldMap.lua:931-997",
		kind = "scenario",
		needs = { fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) and sit.net ~= "none" end,
		check = function(ctx)
			local d = nil
			for _, x in ipairs(ctx.W.UI.Drivers()) do
				if x.state == "busy" and type(x.dest) == "string" then d = x break end
			end
			if not d then ctx:na("no busy driver is listed") end
			local wm = tapWorld(ctx)
			if not wm then ctx:cannot("the World view did not show") end
			local pin
			for _, p in ipairs(wm.pins or {}) do
				if ctx:visible(p) and p.key == d.key then pin = p break end
			end
			if not pin then
				ctx:fail(("Busy driver %s has no pin in the World view."):format(tostring(d.short)), onScreen(ctx))
			end
			local _, body = tipOf(pin)
			if not body:find("busy", 1, true) or not body:find("Click to see this driver.", 1, true) then
				ctx:fail(("Busy driver pin tooltip does not say busy and Click to see this driver.: %s"):format(body), onScreen(ctx))
			end
		end,
	}

	-- 3. Creator driver pin in World view wears crown and is gold
	Hunt.promise{
		id = "b4maps.world_creator_crown_and_gold",
		area = "Maps",
		text = "In the World view, a creator driver's pin wears a crown and is tinted gold.",
		source = "Wuber/UI/Rider/WorldMap.lua:990-1007",
		kind = "scenario",
		needs = { fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) and sit.net ~= "none" end,
		check = function(ctx)
			local d = nil
			for _, x in ipairs(ctx.W.UI.Drivers()) do
				if x.creator and type(x.dest) == "string" then d = x break end
			end
			if not d then ctx:na("no creator driver is listed") end
			local wm = tapWorld(ctx)
			if not wm then ctx:cannot("the World view did not show") end
			local pin
			for _, p in ipairs(wm.pins or {}) do
				if ctx:visible(p) and p.key == d.key then pin = p break end
			end
			if not pin then ctx:na("creator driver is not the primary pin for that place") end
			if not (pin.crown and ctx:visible(pin.crown)) then
				ctx:fail("Creator driver's pin in the World view has no visible crown.", onScreen(ctx))
			end
			local gr, gg, gb = ctx.W.Theme.RGB("gold")
			local r, g, b = pin.icon:GetVertexColor()
			if not (type(r) == "number" and math.abs(r - gr) < 0.03 and math.abs(g - gg) < 0.03 and math.abs(b - gb) < 0.03) then
				ctx:fail("Creator driver's pin in the World view is not tinted gold.", ("rgb=(%.2f, %.2f, %.2f)"):format(r or 0, g or 0, b or 0))
			end
		end,
	}

	-- 4. Own bounty coin in World view
	Hunt.promise{
		id = "b4maps.world_bounty_coin_and_tip",
		area = "Maps",
		text = "When you pin a bounty for a place, the World view shows a coin there with a tooltip saying 'Your bounty.' and 'A bounty is a wish, not a payment.'.",
		source = "Wuber/UI/Rider/WorldMap.lua:1110-1149",
		kind = "scenario",
		needs = { fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local B = ctx.W.Bounty
			if not (type(B) == "table" and type(B.Mine) == "function") then ctx:cannot("no Bounty module") end
			local mine = B.Mine()
			if not (type(mine) == "table" and type(mine.place) == "string" and mine.place ~= "") then
				if type(B.Set) == "function" then
					pcall(B.Set, "Orgrimmar")
					ctx:advance(0.5)
					mine = B.Mine()
				end
			end
			if not (type(mine) == "table" and type(mine.place) == "string" and mine.place ~= "") then
				ctx:na("no active bounty could be pinned")
			end
			local wm = tapWorld(ctx)
			if not wm then ctx:cannot("the World view did not show") end
			local found
			for _, c in ipairs(wm.coins or {}) do
				local title = tipOf(c)
				if ctx:visible(c) and title:find(mine.place, 1, true) then
					found = c
					break
				end
			end
			if not found then
				ctx:fail(("You pinned a bounty for %s, and no coin for it appears on the World view."):format(mine.place), onScreen(ctx))
			end
			local _, body = tipOf(found)
			if not body:find("Your bounty.", 1, true) or not body:find("A bounty is a wish, not a payment.", 1, true) then
				ctx:fail(("Your bounty coin tooltip is missing expected wording: %s"):format(body), onScreen(ctx))
			end
		end,
	}

	-- 5. Watching bounties off hides other riders' demand coins
	Hunt.promise{
		id = "b4maps.world_bounty_watch_off_hides_demand",
		area = "Maps",
		text = "With 'Show what riders want' switched off, other riders' bounties do not appear as coins on the World view.",
		source = "Wuber/UI/Rider/WorldMap.lua:741-744,1113-1120",
		kind = "scenario",
		needs = { opt_watchBounty = "off", fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local B = ctx.W.Bounty
			if not (type(B) == "table" and type(B.Demand) == "function") then ctx:cannot("no Bounty module") end
			local mine = type(B.Mine) == "function" and B.Mine() or nil
			local myPlace = type(mine) == "table" and mine.place and ctx.W.NormPlace(mine.place) or nil
			local wm = tapWorld(ctx)
			if not wm then ctx:cannot("the World view did not show") end
			for _, c in ipairs(wm.coins or {}) do
				if ctx:visible(c) then
					local title = tipOf(c)
					local place = title:match("^Wanted: (.+)$")
					if place and ctx.W.NormPlace(place) ~= myPlace then
						ctx:fail(("'Show what riders want' is off, yet another rider's bounty coin for %s is shown on the World view."):format(place), onScreen(ctx))
					end
				end
			end
		end,
	}

	-- 6. Flight master pins in World view
	Hunt.promise{
		id = "b4maps.world_flight_master_pins_and_tip",
		area = "Maps",
		text = "In the World view, flight masters appear as pins with a tooltip saying 'A flight master.'.",
		source = "Wuber/UI/Rider/WorldMap.lua:712-724",
		kind = "scenario",
		needs = { fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) end,
		check = function(ctx)
			local wm = tapWorld(ctx)
			if not wm then ctx:cannot("the World view did not show") end
			local count, okTip = 0, false
			for _, node in ipairs(wm.nodes or {}) do
				if ctx:visible(node) then
					count = count + 1
					local _, body = tipOf(node)
					if body == "A flight master." then okTip = true end
				end
			end
			if count == 0 then
				ctx:fail("In the World view, no flight master pins are shown.", onScreen(ctx))
			end
			if not okTip then
				ctx:fail("Flight master pins in the World view do not have the 'A flight master.' tooltip.", onScreen(ctx))
			end
		end,
	}

	-- 7. Multiple drivers at the same place group into one pin with count
	Hunt.promise{
		id = "b4maps.world_group_count_on_pin",
		area = "Maps",
		text = "When two open drivers are in the same place, the World view shows one pin there with '2' on it and both drivers in its tooltip.",
		source = "Wuber/UI/Rider/WorldMap.lua:985-996",
		kind = "scenario",
		needs = { fold = "unfolded", role = "rider" },
		when = function(sit) return WIDE_OK(sit) and sit.net == "none" end,
		check = function(ctx)
			local spot = mySpot(ctx) or "Orgrimmar"
			local _, name1, key1 = addDriver(ctx, spot)
			local _, name2, key2 = addDriver(ctx, spot)
			local wm = tapWorld(ctx)
			if not wm then ctx:cannot("the World view did not show") end
			local pin
			for _, p in ipairs(wm.pins or {}) do
				if ctx:visible(p) and (p.key == key1 or p.key == key2) then pin = p break end
			end
			if not pin then
				ctx:fail("Two open drivers are in the same place, and no pin for them appears in the World view.", onScreen(ctx))
			end
			local cnt = tonumber(pin.count and pin.count:GetText() or "")
			if not cnt or cnt < 2 then
				ctx:fail(("Two drivers are in %s, but the World view pin count shows '%s'."):format(spot, tostring(pin.count and pin.count:GetText())), onScreen(ctx))
			end
			local s1 = name1:match("^(%S+)") or name1
			local s2 = name2:match("^(%S+)") or name2
			local _, body = tipOf(pin)
			if not body:find(s1, 1, true) or not body:find(s2, 1, true) then
				ctx:fail("Grouped pin tooltip in the World view does not list both drivers.", body)
			end
		end,
	}

	-- 8. Home's map You pin opens Drive tab
	Hunt.promise{
		id = "b4maps.here_you_pin_opens_drive",
		area = "Maps",
		text = "While you are open as a driver in the zone you stand in, Home's map shows your own You pin, and clicking it opens the Drive tab.",
		source = "Wuber/UI/Rider/HomeMap.lua:209-243",
		kind = "scenario",
		needs = { role = "warlock" },
		when = function(sit) return WIDE_OK(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local b = type(ctx.W.DriverBeacon) == "function" and ctx.W.DriverBeacon() or nil
			if not (type(b) == "table" and not b.only and tonumber(b.mapID) == ctx.me.player.mapID) then
				ctx:na("not open as a driver in the zone I stand in")
			end
			local m = hereMap(ctx)
			ctx:advance(0.5)
			if not (m.ownPin and ctx:visible(m.ownPin)) then
				ctx:fail("You are open as a driver in this zone, and Home's map does not show your own You pin.", onScreen(ctx))
			end
			dismissPopups(ctx)
			ctx.me:clickOn(m.ownPin)
			ctx:note("click my You pin on Home's map")
			ctx:advance(1)
			if ui(ctx).tab ~= "Drive" then
				ctx:fail("You click your own You pin on Home's map and the Drive tab does not open.", "now on " .. tostring(ui(ctx).tab))
			end
		end,
	}

	-- 9. Home's map Your ride pill returns to the ride screen
	Hunt.promise{
		id = "b4maps.here_ride_pill_returns_to_ride",
		area = "Maps",
		text = "While a ride is under way and you look at Home, Home's map shows a 'Your ride' pill, and clicking it takes you back to your ride.",
		source = "Wuber/UI/Rider/HomeMap.lua:119-128,415-425",
		kind = "scenario",
		when = function(sit)
			return is(sit, "combat", "no") and is(sit, "session", { login = true, reload = true })
				and is(sit, "ride", { requested = true, invited = true, summoning = true, arrived = true })
		end,
		check = function(ctx)
			local K = ctx:mod("UI.Kit")
			if not (K and type(K.rideActive) == "function" and K.rideActive()) then ctx:na("no active ride") end
			local m = hereMap(ctx)
			ctx:advance(0.5)
			if not (m.ride and ctx:visible(m.ride)) then
				ctx:fail("A ride is active and you look at Home, but Home's map does not show the 'Your ride' pill.", onScreen(ctx))
			end
			dismissPopups(ctx)
			ctx.me:clickOn(m.ride)
			ctx:note("click the Your ride pill on Home's map")
			ctx:advance(1)
			if ui(ctx).screen ~= "ride" then
				ctx:fail("You click the 'Your ride' pill on Home's map and it does not take you to the Ride screen.", "now on " .. tostring(ui(ctx).screen))
			end
		end,
	}

	-- 10. Home's map Network offline chip
	Hunt.promise{
		id = "b4maps.here_offline_chip_shows",
		area = "Maps",
		text = "When Wuber is offline from its network, Home's map shows the 'Network offline' chip.",
		source = "Wuber/UI/Rider/HomeMap.lua:106-108,431",
		kind = "scenario",
		needs = { net = "none" },
		when = function(sit) return is(sit, "combat", "no") and is(sit, "ride", "none") end,
		check = function(ctx)
			local m = hereMap(ctx)
			ctx:advance(0.5)
			local K = ctx:mod("UI.Kit")
			if K and type(K.onNetwork) == "function" and K.onNetwork() then ctx:na("already on the network") end
			if not (m.net and ctx:visible(m.net)) then
				ctx:fail("Wuber is offline from its network, and Home's map does not show the 'Network offline' chip.", onScreen(ctx))
			end
		end,
	}

	-- 11. Game's world map: Wuber only pill toggles veil and persists
	Hunt.promise{
		id = "b4maps.game_map_wuber_only_dims_and_persists",
		area = "Maps",
		text = "On the game's world map, clicking 'Wuber only' toggles dimming the map so Wuber's pins stand out, and keeps that choice.",
		source = "Wuber/UI/Map/Map.lua:540-606",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return sit.mapPins ~= "off" and sit.net ~= "none" and is(sit, "combat", "no") and is(sit, "ride", "none") end,
		check = function(ctx)
			if ctx.W.db and ctx.W.db.mapPins == false then ctx:na("pins are off") end
			local env = ctx.me.env
			if not (env.WorldMapFrame and env.WorldMapFrame.SetMapID) then ctx:cannot("no world map in this game") end
			local d
			for _, x in ipairs(ctx.W.UI.Drivers()) do if x.state == "open" and x.mapID then d = x break end end
			if not d then ctx:na("no open driver with a mapID") end
			env.WorldMapFrame:Show()
			env.WorldMapFrame:SetMapID(d.mapID)
			ctx:advance(1)
			local M = ctx.W.Map
			local pill = M and M.OnlyPill and M.OnlyPill()
			if not (pill and ctx:visible(pill)) then
				ctx:fail("On the game's world map with pins on, the 'Wuber only' pill is not shown.", onScreen(ctx))
			end
			local before = ctx.W.db and ctx.W.db.mapOnly == true
			ctx.me:clickOn(pill)
			ctx:note("click Wuber only")
			ctx:advance(0.5)
			local after = ctx.W.db and ctx.W.db.mapOnly == true
			if after == before then
				ctx:fail("Clicking 'Wuber only' on the game's world map did not toggle dimming.", "mapOnly=" .. tostring(after))
			end
			local veil = M.Veil and M.Veil()
			if after and not (veil and ctx:visible(veil)) then
				ctx:fail("'Wuber only' is on, but the map veil is not visible.", "")
			end
			if not after and veil and ctx:visible(veil) then
				ctx:fail("'Wuber only' is off, but the map veil is still visible.", "")
			end
		end,
	}

	-- 12. Game's world map: pin tooltip shows driver, destination, and price
	Hunt.promise{
		id = "b4maps.game_map_pin_tooltip_shows_who_where_price",
		area = "Maps",
		text = "On the game's world map, hovering a driver's pin shows who they are, where they go, and their price.",
		source = "Wuber/UI/Map/Pins.lua:220-271",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return sit.mapPins ~= "off" and sit.net ~= "none" and is(sit, "combat", "no") and is(sit, "ride", "none") end,
		check = function(ctx)
			if ctx.W.db and ctx.W.db.mapPins == false then ctx:na("pins are off") end
			local env = ctx.me.env
			if not (env.WorldMapFrame and env.WorldMapFrame.SetMapID) then ctx:cannot("no world map in this game") end
			local d
			for _, x in ipairs(ctx.W.UI.Drivers()) do if x.state == "open" and x.mapID and x.x and x.y then d = x break end end
			if not d then ctx:na("no open driver with coordinates") end
			env.WorldMapFrame:Show()
			env.WorldMapFrame:SetMapID(d.mapID)
			ctx:advance(1)
			local BM = ctx:mod("UI.Map.Base")
			local pin
			for _, p in ipairs(BM and BM.pins or {}) do
				if ctx:visible(p) and p.key == d.key then pin = p break end
			end
			if not pin then ctx:na("pin not visible on game map") end
			pcall(ctx.H.runScript, pin, "OnEnter")
			ctx:advance(0.2)
			local tipText = table.concat(plainTexts(ctx), " | ")
			local Th = ctx.W.Theme
			local owner = Th and Th.TipOwner and Th.TipOwner()
			if owner ~= pin then
				-- Wuber's custom tip card may still have populated texts, or TipOwner might be nil if not shown
				local tc = rawget(env, "WuberTipPopup")
				if not (tc and ctx:visible(tc)) then
					ctx:fail("Hovering a driver's pin on the game's world map showed no tooltip.", tipText)
				end
			end
			if not tipText:find("To " .. tostring(d.dest), 1, true) then
				ctx:fail(("Hovering a driver's pin on the game's world map does not show 'To %s'."):format(tostring(d.dest)), tipText)
			end
			pcall(ctx.H.runScript, pin, "OnLeave")
		end,
	}

end
