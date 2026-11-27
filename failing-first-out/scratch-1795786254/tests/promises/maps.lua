-- Promises about the maps (owner MAPS): Home's map panel and its driver pins, the World view (both continents whole at one
-- scale, yours marked, pins and price tags), the Sea route words, and the pins on the game's own world map.
-- Written from what the player was told (CHANGELOG 2.3.3, the tip "Tap World to see every driver on the whole map, with
-- flight routes and boats", the legend and tooltips on the map, BRIEF25 M1/M2, BRIEF26 items 3 and 4), never from the code's
-- own early returns. Wide pages unfold only where there is room: a folded phone has no World view, so those promises are
-- "not applicable" there (the Here map is the Home page itself).
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

	local DRIVERS = { "Mia Runner", "Bea Jones", "Cal Brown", "Dee Price", "Eli Stone", "Fay Ward" }

	-- another window: a Wuber driver opens for business where I stand (his beacon reaches me by addon message)
	local function addDriver(ctx, spot, tag)
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
		return name, key
	end

	-- the spot name of the place I stand in (H.SPOTS)
	local function mySpot(ctx)
		local me = ctx.me.player
		local best
		for name, s in pairs(ctx.H.SPOTS) do
			if s.mapID == me.mapID and (not best or name < best) then best = name end
		end
		return best
	end

	-- the Home map panel (the Here view) on screen; clicks Here where the phone is wide
	local function hereMap(ctx)
		atHome(ctx)
		if unfolded(ctx) then
			local wm = shownWorld(ctx)
			if wm then
				if not has(ctx, "Here") then ctx:na("no Here button on screen") end
				ctx.me:clickText("Here")
				ctx:note("click Here")
				ctx:advance(1)
			end
		end
		local s = ui(ctx).screens
		local m = s and s.home and s.home.map
		if not (m and ctx:visible(m)) then ctx:na("Home's map panel is not on screen here") end
		return m
	end

	-- tap World (needs the wide phone); returns the world view
	local function tapWorld(ctx)
		atHome(ctx)
		if not unfolded(ctx) then ctx:na("the phone is folded here: Home has no World view") end
		if not shownWorld(ctx) then
			if not has(ctx, "World") then ctx:na("no World button on screen") end
			ctx.me:clickText("World")
			ctx:note("click World")
			ctx:advance(1.2)
		end
		return shownWorld(ctx)
	end

	local function rectOf(f)
		local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
		if type(l) ~= "number" or type(r) ~= "number" or type(t) ~= "number" or type(b) ~= "number" then return nil end
		return { l = l, r = r, t = t, b = b }
	end
	local function overlap(a, b)
		return a and b and a.l < b.r - 0.5 and b.l < a.r - 0.5 and a.b < b.t - 0.5 and b.b < a.t - 0.5
	end

	local WIDE_OK = function(sit) return is(sit, "ride", "none") and is(sit, "combat", "no") end

	---------------------------------------------------------------------------------------------------------------
	-- The World view
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "maps.world_tap",
		area = "Maps",
		text = "Tap World on Home and you see Kalimdor and the Eastern Kingdoms, each named.",
		source = "tip \"Tap World to see every driver on the whole map\"; CHANGELOG 2.3.3",
		kind = "scenario",
		needs = { fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) end,
		check = function(ctx)
			local wm = tapWorld(ctx)
			if not wm then ctx:fail("You tap World on Home and no world map shows.", onScreen(ctx)) end
			if not (has(ctx, "Kalimdor") and has(ctx, "Eastern Kingdoms")) then
				ctx:fail("You tap World on Home and the world map does not name both Kalimdor and the Eastern Kingdoms.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "maps.world_whole",
		area = "Maps",
		text = "In the World view both continents are drawn whole inside the view, Kalimdor on the left, at the same scale.",
		source = "CHANGELOG 2.3.3 (World map); BRIEF26 item 3 (every continent must fit wholly, at the same scale, at every size)",
		kind = "scenario",
		needs = { fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) end,
		check = function(ctx)
			local wm = tapWorld(ctx)
			if not wm then ctx:cannot("the World view did not show (maps.world_tap says so)") end
			local Mod = worldMod(ctx)
			local vw, vh = wm.view:GetWidth(), wm.view:GetHeight()
			if type(vw) ~= "number" or vw <= 0 then vw, vh = Mod.WM.PANE_W, Mod.WM.PANE_H end
			local box = {}
			for _, cont in ipairs({ 1, 0 }) do
				local x, y, w, h = Mod.Box(cont)
				if not x then ctx:fail("You tap World and one of the two continents is missing from the map.", "continent " .. cont .. " has no box") end
				box[cont] = { x, y, w, h }
				local name = cont == 1 and "Kalimdor" or "The Eastern Kingdoms"
				if x < 2 or y < 2 or x + w > vw - 2 or y + h > vh - 2 then
					ctx:fail(("You tap World and %s is cut off at the edge of the map."):format(name),
						("%s box %.1f %.1f %.1f %.1f in a view %.0f x %.0f"):format(name, x, y, w, h, vw, vh))
				end
			end
			if box[1][1] + box[1][3] > box[0][1] + 0.5 then
				ctx:fail("You tap World and Kalimdor is not on the left of the Eastern Kingdoms, or the two overlap.", "boxes " .. box[1][1] .. "+" .. box[1][3] .. " and " .. box[0][1])
			end
			-- one scale: the same pixels per square yard on both (the geometric mean of the two directions)
			local function per(cont, wx, wy)
				local x0, y0 = Mod.Project(cont, wx, wy)
				local x1, y1 = Mod.Project(cont, wx + 1000, wy)
				local x2, y2 = Mod.Project(cont, wx, wy + 1000)
				if not (x0 and x1 and x2) then return nil end
				return math.sqrt(math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) * math.sqrt((x2 - x0) ^ 2 + (y2 - y0) ^ 2))
			end
			local k, e = per(1, 1677, -4315), per(0, -8913, 554)
			if k and e and math.abs(k - e) > 0.03 * math.max(k, e) then
				ctx:fail("You tap World and Kalimdor and the Eastern Kingdoms are drawn at different sizes.",
					("pixels per 1000 yards: Kalimdor %.3f, Eastern Kingdoms %.3f"):format(k, e))
			end
		end,
	}

	Hunt.promise{
		id = "maps.world_mine_marked",
		area = "Maps",
		text = "In the World view the continent you are on has its name in violet and the other one does not.",
		source = "CHANGELOG 2.3.3 (World map: the continent you are on is brighter); design round 4 (its name in the accent violet, the other muted; gold is for price tags only)",
		kind = "scenario",
		needs = { fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) end,
		check = function(ctx)
			local wm = tapWorld(ctx)
			if not wm then ctx:cannot("the World view did not show (maps.world_tap says so)") end
			local here = ctx.facts.continent
			if here == nil then ctx:na("the player is not on either continent") end
			local ar, ag, ab = ctx.W.Theme.RGB("accent")
			local function gold(label) -- (the name kept from 2.3: now "is in the accent violet")
				local r, g, b = label:GetTextColor()
				return type(r) == "number" and math.abs(r - ar) < 0.02 and math.abs(g - ag) < 0.02 and math.abs(b - ab) < 0.02
			end
			local mine, other = wm.boxes[here], wm.boxes[here == 1 and 0 or 1]
			if not (mine and other) then ctx:cannot("the world view has no continent labels") end
			local myName = here == 1 and "Kalimdor" or "the Eastern Kingdoms"
			if not gold(mine.label) then
				ctx:fail(("You stand on %s, tap World, and its name is not in violet."):format(myName), onScreen(ctx))
			end
			if gold(other.label) then
				ctx:fail(("You stand on %s, tap World, and the other continent's name is violet too, so you cannot tell where you are."):format(myName), onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "maps.world_pins",
		area = "Maps",
		text = "In the World view every place where an open driver goes has a pin, inside the map.",
		source = "tip \"Tap World to see every driver on the whole map\"; WorldMap header (driver pins)",
		kind = "scenario",
		needs = { fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) and sit.net ~= "none" end,
		check = function(ctx)
			local wm = tapWorld(ctx)
			if not wm then ctx:cannot("the World view did not show (maps.world_tap says so)") end
			local Mod = worldMod(ctx)
			local places, want = {}, 0
			for _, d in ipairs(ctx.W.UI.Drivers()) do
				if d.state == "open" and type(d.dest) == "string" then
					local p = type(ctx.W.ExactPlace) == "function" and ctx.W.ExactPlace(d.dest) or nil
					if type(p) ~= "table" and type(ctx.W.FindPlace) == "function" then p = ctx.W.FindPlace(d.dest) end
					if type(p) == "table" then
						local cont, wx, wy = ctx.W.PlaceWorld(p)
						if cont and Mod.Project(cont, wx, wy) then
							local k = ctx.W.NormPlace(p.name)
							if not places[k] then places[k] = d.dest want = want + 1 end
						end
					end
				end
			end
			if want == 0 then ctx:na("no open driver goes to a place the map can draw") end
			local got, vw, vh = 0, wm.view:GetWidth(), wm.view:GetHeight()
			local v = rectOf(wm.view)
			for _, p in ipairs(wm.pins or {}) do
				if ctx:visible(p) then
					got = got + 1
					local r = rectOf(p)
					if r and v and (r.l < v.l - 1 or r.r > v.r + 1 or r.t > v.t + 1 or r.b < v.b - 1) then
						ctx:fail("You tap World and a driver's pin sits outside the map.", onScreen(ctx))
					end
				end
			end
			if got < math.min(want, 40) then
				ctx:fail(("You tap World and %d places have an open driver going there, but the map shows %d pins."):format(want, got), onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "maps.world_pin_books",
		area = "Maps",
		text = "In the World view, clicking a driver's pin opens the booking screen for that driver.",
		source = "WorldMap header; pin tooltip \"Click to book\"",
		kind = "scenario",
		needs = { fold = "unfolded", role = "rider" },
		when = function(sit) return WIDE_OK(sit) and sit.net ~= "none" end,
		check = function(ctx)
			local wm = tapWorld(ctx)
			if not wm then ctx:cannot("the World view did not show (maps.world_tap says so)") end
			local pin
			for _, p in ipairs(wm.pins or {}) do if ctx:visible(p) and p.key then pin = p break end end
			if not pin then ctx:na("no driver pin is on the map") end
			local d = ctx.W.UI.Driver(pin.key)
			-- which other pin (if any) is on top of the middle of this one
			local under
			local pr = ctx.H.rect(pin)
			local hit = pr and ctx.me:frameAt(pr.l + pr.w / 2, pr.b + pr.h / 2)
			if hit and hit ~= pin then
				for _, q in ipairs(wm.pins or {}) do if q == hit then under = q.key end end
			end
			ctx.me:clickOn(pin)
			ctx:note("click the pin of " .. tostring(pin.key))
			ctx:advance(1)
			local s = ui(ctx)
			if s.screen ~= "confirm" then
				ctx:fail("You click a driver's pin in the World view and the booking screen does not open.", "now on " .. tostring(s.tab) .. "/" .. tostring(s.screen) .. "; " .. onScreen(ctx))
			end
			local name = d and (d.short or d.name)
			if name and not has(ctx, name) then
				local found = false
				for _, t in ipairs(plainTexts(ctx)) do if t:find(name, 1, true) then found = true break end end
				if not found then
					ctx:fail("You click a driver's pin in the World view and the booking screen shows a different driver.",
						"wanted " .. tostring(name) .. (under and ("; the pin of " .. under .. " sits on top of it") or "") .. "; " .. onScreen(ctx))
				end
			end
		end,
	}

	Hunt.promise{
		id = "maps.world_price_tags",
		area = "Maps",
		text = "In the World view at most three price tags show, and a price tag never covers a pin, your dot or a continent's name.",
		source = "CHANGELOG 2.3.3 (price tags never cover a pin, your dot or a name); WorldMap header",
		kind = "scenario",
		needs = { fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) and sit.net ~= "none" end,
		check = function(ctx)
			local wm = tapWorld(ctx)
			if not wm then ctx:cannot("the World view did not show (maps.world_tap says so)") end
			local tags = {}
			for _, p in ipairs(wm.pins or {}) do
				if ctx:visible(p) and p.tag and ctx:visible(p.tag) then tags[#tags + 1] = p end
			end
			if #tags > 3 then ctx:fail(("You tap World and %d price tags show on the map, not three at most."):format(#tags), onScreen(ctx)) end
			local names = {}
			for _, box in pairs(wm.boxes or {}) do
				local r = rectOf(box.label)
				if r and ctx:visible(box.label) then
					local sw = box.label:GetStringWidth()
					if type(sw) == "number" and sw > 0 then r.r = math.min(r.r, r.l + sw) end
					names[#names + 1] = r
				end
			end
			for _, p in ipairs(tags) do
				local tr = rectOf(p.tag)
				if tr then
					for _, q in ipairs(wm.pins) do
						if ctx:visible(q) and q.icon then
							local ir = rectOf(q.icon)
							if ir and overlap(tr, ir) then
								ctx:fail("You tap World and a price tag sits on top of a driver's pin.", ("tag of %s over the pin of %s"):format(tostring(p.key), tostring(q.key)))
							end
						end
					end
					if wm.me and ctx:visible(wm.me) and overlap(tr, rectOf(wm.me)) then
						ctx:fail("You tap World and a price tag sits on top of the dot that shows where you stand.", "tag of " .. tostring(p.key))
					end
					for _, nr in ipairs(names) do
						if overlap(tr, nr) then ctx:fail("You tap World and a price tag sits on top of a continent's name.", "tag of " .. tostring(p.key)) end
					end
				end
			end
		end,
	}

	Hunt.promise{
		id = "maps.world_choice_kept",
		area = "Maps",
		text = "Tap Here, close Wuber, even /reload and open it again: it opens on Here, not World.",
		source = "WorldMap header (your Here/World choice is remembered)",
		kind = "scenario",
		needs = { fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) and sit.session ~= "first" end,
		check = function(ctx)
			atHome(ctx)
			if not unfolded(ctx) then ctx:na("the phone is folded here: no Here/World choice") end
			if not has(ctx, "Here") then ctx:na("no Here button on screen") end
			ctx.me:clickText("Here")
			ctx:note("click Here")
			ctx:advance(1)
			if shownWorld(ctx) then ctx:cannot("tapping Here left the World view on screen") end
			ctx.W.UI.Toggle(false)
			ctx:advance(1)
			ctx:reload()
			ctx:advance(3)
			atHome(ctx)
			ctx:advance(1)
			if not unfolded(ctx) then ctx:na("the phone is folded after the reload") end
			if shownWorld(ctx) then
				ctx:fail("You tap Here, /reload, open Wuber and it shows the World view again.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "maps.world_you_pin",
		area = "Maps",
		text = "While you are open as a driver, the World view shows your own gold You pin, and clicking it opens the Drive tab.",
		source = "CHANGELOG 2.3.2 (your own pin); WorldMap header",
		kind = "scenario",
		needs = { role = "warlock", fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) end,
		check = function(ctx)
			local wm = tapWorld(ctx)
			if not wm then ctx:cannot("the World view did not show (maps.world_tap says so)") end
			if not (type(ctx.W.DriverBeacon) == "function" and ctx.W.DriverBeacon()) then ctx:na("I am not advertising as an open driver") end
			local p = wm.ownPin
			if not (p and ctx:visible(p)) then
				ctx:fail("You are open as a driver, tap World, and your own You pin is not on the map.", onScreen(ctx))
			end
			ctx.me:clickOn(p)
			ctx:note("click my You pin")
			ctx:advance(1)
			if ui(ctx).tab ~= "Drive" then
				ctx:fail("You click your own You pin in the World view and the Drive tab does not open.", "now on " .. tostring(ui(ctx).tab))
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- Home's map panel (the Here view)
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "maps.here_pin_books",
		area = "Maps",
		text = "A driver who is open in the town you stand in shows as a pin on Home's map, and clicking it opens the booking screen for him.",
		source = "tooltip on the pin (\"Click to request\"); HomeMap header",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return WIDE_OK(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local spot = mySpot(ctx)
			if not spot then ctx:cannot("no spot name for where I stand") end
			local name, key = addDriver(ctx, spot)
			local m = hereMap(ctx)
			ctx:advance(1)
			local pin
			for _, p in ipairs(m.pins or {}) do if p.key == key and ctx:visible(p) then pin = p break end end
			if not pin then
				ctx:fail(("%s is open in the town you stand in and Home's map shows no pin for him."):format(name), onScreen(ctx))
			end
			-- (2.4) the What's new card takes the click while it is up: a player taps Got it first
			do
				local nc = rawget(ctx.me.env, "WuberNewsCard")
				if type(nc) == "table" and type(nc.IsShown) == "function" and nc:IsShown() == true then
					local g = ctx.me:button("Got it")
					if g and ctx:visible(g) then
						ctx.me:clickOn(g)
						ctx:advance(0.8)
						ctx:note("click Got it on the What's new card")
					end
				end
			end
			-- (2.4) the login tip is a sheet that rises over the page and takes the click: a player taps "Don't show again" on it first
			do
				local card = rawget(ctx.me.env, "WuberTipCard")
				if card and ctx:visible(card) then
					local dont = card.never or ctx.me:button("Don't show again")
					if dont and ctx:visible(dont) then
						ctx.me:click(dont)
						ctx:advance(20) -- the "Tips are off" line stays a few seconds by itself, then the sheet is gone
						ctx:note("close the login tip (Don't show again)")
					end
				end
			end
			ctx.me:clickOn(pin)
			ctx:note("click the pin of " .. name)
			ctx:advance(1)
			if ui(ctx).screen ~= "confirm" then
				ctx:fail("You click a driver's pin on Home's map and the booking screen does not open.", "now on " .. tostring(ui(ctx).screen))
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- Sea routes: the words must agree
	---------------------------------------------------------------------------------------------------------------
	-- the boat or zeppelin words the screen says about the trip (the legend's own words left out)
	local function seaWords(ctx)
		local words, lines = {}, {}
		for _, t in ipairs(plainTexts(ctx)) do
			local l = t:lower()
			if l ~= "boat" and l ~= "boat or zeppelin" or false then
				if l:find("zeppelin", 1, true) then words.zeppelin = true lines[#lines + 1] = t end
				if l:find("boat", 1, true) then words.boat = true lines[#lines + 1] = t end
			end
		end
		return words, lines
	end
	local function arrowText(ctx)
		local Mod = worldMod(ctx)
		for _, wm in pairs(Mod.cache.maps) do
			local a = wm.seaArrow
			if a and a.label and ctx:visible(a.label) then return a.label:GetText() end
		end
		return nil
	end

	-- opens the booking screen of every driver in turn by their pins; calls fn(driver, words, lines, arrow)
	local function eachBooking(ctx, fn)
		local wm = tapWorld(ctx)
		if not wm then ctx:cannot("the World view did not show (maps.world_tap says so)") end
		local keys = {}
		for _, p in ipairs(wm.pins or {}) do if ctx:visible(p) and p.key then keys[#keys + 1] = p.key end end
		if #keys == 0 then ctx:na("no driver pin is on the map") end
		local seen = 0
		for _, key in ipairs(keys) do
			ctx.W.UI.Show("confirm", key)
			ctx:advance(1)
			if ui(ctx).screen == "confirm" then
				seen = seen + 1
				local words, lines = seaWords(ctx)
				fn(ctx.W.UI.Driver(key), words, lines, arrowText(ctx))
			end
		end
		if seen == 0 then ctx:cannot("no booking screen opened") end
	end

	Hunt.promise{
		id = "maps.sea_words_agree",
		area = "Maps",
		text = "On a booking that crosses the sea, the route, the price card and the map's arrow all say the same, boat or zeppelin.",
		source = "BRIEF26 item 4; CHANGELOG 2.3.3 (World map: continues by zeppelin or boat)",
		kind = "scenario",
		needs = { net = "many", fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) end,
		check = function(ctx)
			eachBooking(ctx, function(d, words, lines, arrow)
				if words.boat and words.zeppelin then
					ctx:fail(("You book %s (to %s) and the screen says boat in one place and zeppelin in another."):format(tostring(d and d.short), tostring(d and d.dest)),
						table.concat(lines, " | "))
				end
			end)
		end,
	}

	Hunt.promise{
		id = "maps.sea_arrow_when_crossing",
		area = "Maps",
		text = "The map shows the arrow \"continues by boat\" or \"continues by zeppelin\" when the trip crosses the sea, and no arrow when it does not.",
		source = "CHANGELOG 2.3.3; BRIEF25 M2; BRIEF26 item 4",
		kind = "scenario",
		needs = { net = "many", fold = "unfolded" },
		when = function(sit) return WIDE_OK(sit) end,
		check = function(ctx)
			eachBooking(ctx, function(d, words, lines, arrow)
				local crossing = words.boat or words.zeppelin
				local who = ("%s (to %s)"):format(tostring(d and d.short), tostring(d and d.dest))
				if arrow and not crossing then
					ctx:fail(("You book %s and the map says \"%s\" but the booking says nothing about a boat or zeppelin."):format(who, arrow), onScreen(ctx))
				end
				if crossing and not arrow then
					ctx:fail(("You book %s, the booking says the trip goes by %s, and the map shows no \"continues by\" arrow."):format(who, words.boat and "boat" or "zeppelin"), onScreen(ctx))
				end
				if arrow then
					local w = arrow:match("continues by (%a+)")
					if w and not words[w] then
						ctx:fail(("You book %s and the map says \"%s\" but the booking says the other one."):format(who, arrow), table.concat(lines, " | "))
					end
				end
			end)
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- The game's own world map
	---------------------------------------------------------------------------------------------------------------
	-- opens the game's world map on a zone where an open driver stands; returns the driver and the pins on screen
	local function gameMapAt(ctx)
		local list = ctx.W.UI.Drivers()
		local d
		for _, x in ipairs(list) do if x.state == "open" and x.mapID and x.x and x.y then d = x break end end
		if not d then ctx:na("no open driver has a place on a zone map") end
		local env = ctx.me.env
		if not (env.WorldMapFrame and env.WorldMapFrame.SetMapID) then ctx:cannot("no world map in this game") end
		env.WorldMapFrame:Show()
		env.WorldMapFrame:SetMapID(d.mapID)
		ctx:note("open the game's world map on map " .. tostring(d.mapID))
		ctx:advance(1)
		local BM = ctx:mod("UI.Map.Base")
		local pins = {}
		for _, p in ipairs(BM and BM.pins or {}) do if ctx:visible(p) then pins[#pins + 1] = p end end
		return d, pins
	end

	Hunt.promise{
		id = "maps.game_map_pin",
		area = "Maps",
		text = "With Drivers on the world map on, opening the game's world map on a zone where an open driver stands shows his pin, and clicking it opens the booking screen.",
		source = "Settings > Map (Drivers on the world map); Map/Base header",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return sit.mapPins ~= "off" and sit.net ~= "none" and is(sit, "combat", "no") and is(sit, "ride", "none") end,
		check = function(ctx)
			if ctx.W.db and ctx.W.db.mapPins == false then ctx:na("pins are off") end
			local d, pins = gameMapAt(ctx)
			local mine
			for _, p in ipairs(pins) do if p.key == d.key then mine = p end end
			if not mine then
				ctx:fail(("You open the game's world map on %s, where %s is open, and his pin is not there."):format(tostring(d.dest), tostring(d.short)),
					"pins shown: " .. #pins)
			end
			-- the pin can sit under Wuber's own open window (Settings, Help, the bug card): a click lands on that, as in the game
			do
				local pr = ctx.H.rect(mine)
				local hit = pr and ctx.me:frameAt(pr.l + pr.w / 2, pr.b + pr.h / 2)
				if hit and hit ~= mine then
					local cur, n, inside = hit, 0, false
					while cur and n < 40 do
						if cur == mine then inside = true break end
						local okp, par = pcall(cur.GetParent, cur)
						if not okp then break end
						cur, n = par, n + 1
					end
					if not inside then ctx:na("the pin is under another open window (Wuber's own, drawn over the map)") end
				end
			end
			ctx.me:clickOn(mine)
			ctx:note("click the pin of " .. d.key)
			ctx:advance(1)
			if ui(ctx).screen ~= "confirm" then
				ctx:fail("You click a driver's pin on the game's world map and the booking screen does not open.", "now on " .. tostring(ui(ctx).screen))
			end
		end,
	}

	Hunt.promise{
		id = "maps.game_map_pins_off",
		area = "Maps",
		text = "With Drivers on the world map switched off, the game's world map shows no Wuber pins.",
		source = "Settings > Map (Drivers on the world map); /wuber map",
		kind = "scenario",
		needs = { mapPins = "off" },
		when = function(sit) return sit.net ~= "none" and sit.session ~= "first" end,
		check = function(ctx)
			if not (ctx.W.db and ctx.W.db.mapPins == false) then ctx:cannot("the saved mapPins = false did not reach Wuber") end
			local d, pins = gameMapAt(ctx)
			if #pins > 0 then
				ctx:fail("You switched Drivers on the world map off and the game's world map still shows Wuber pins.", "pins shown: " .. #pins)
			end
		end,
	}
end
