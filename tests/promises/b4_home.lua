-- New promises for Rider Home (Wuber/UI/Rider/Home.lua, Wuber/UI/Rider/Cards.lua).
-- Prefix: b4home. Written from docs/PLAYER-GUIDE.md, tooltips/help text, and inferred UI contracts.
return function(Hunt)
	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		if type(want) == "table" then return want[v] == true end
		return v == want
	end

	local function kit(ctx)
		local K = ctx:mod("UI.Kit")
		return K and K.ui or {}
	end

	local function homeScr(ctx)
		local WM = ctx:mod("UI.Window")
		return WM and type(WM.screens) == "table" and WM.screens.home or nil
	end

	local function joined(ctx) return table.concat(ctx:texts(), " | ") end

	local function has(ctx, text)
		for _, t in ipairs(ctx:texts()) do
			if t:find(text, 1, true) then return t end
		end
		return nil
	end

	local function hasPat(ctx, pat)
		for _, t in ipairs(ctx:texts()) do
			if t:find(pat) then return t end
		end
		return nil
	end

	local function cards(ctx)
		local out = {}
		for key, c in pairs(kit(ctx).cards or {}) do
			if c.key and c.view and ctx:visible(c) then
				out[#out + 1] = { key = key, card = c, y = c.targetY or c.curY or 0 }
			end
		end
		table.sort(out, function(a, b) if a.y ~= b.y then return a.y > b.y end return a.key < b.key end)
		return out
	end

	local function intoView(ctx, card)
		local function where()
			local r = ctx.H.rect(card)
			local par = card:GetParent()
			local clip = par and par:GetParent()
			local cr = clip and ctx.H.rect(clip)
			if not (r and cr) then return true end
			local cy = r.b + r.h / 2
			if cy < cr.b then return false, -1, clip end
			if cy > cr.b + cr.h then return false, 1, clip end
			return true
		end
		for _ = 1, 12 do
			local ok, dir, clip = where()
			if ok then return end
			local fn = clip.GetScript and clip:GetScript("OnMouseWheel")
			if not fn then break end
			fn(clip, dir)
			ctx:advance(0.6)
			ctx:note("scroll the list " .. (dir < 0 and "down" or "up"))
		end
		if not where() then ctx:na("the driver's card is outside the Home list and could not be scrolled into view") end
	end

	local function conditions(ctx)
		if ctx.me.player.combat then ctx:na("in combat") end
		local db = ctx.W.db
		if type(db) ~= "table" or db.coach ~= true then ctx:na("the first-open coach marks are not done") end
		local K = ctx:mod("UI.Kit")
		if K and type(K.rideActive) == "function" then
			local ok, active = pcall(K.rideActive)
			if ok and active then ctx:na("a ride is on") end
		end
	end

	local function dismissTip(ctx)
		local Tips = ctx:mod("UI.Tips")
		if Tips and type(Tips.Card) == "function" then
			local ok, c = pcall(Tips.Card)
			if ok and type(c) == "table" and ctx:visible(c) then
				pcall(Tips.Hide)
				ctx:advance(0.5)
				ctx:note("the tip card is tapped away")
			end
		end
	end

	local function clearOverlays(ctx)
		local UI = ctx.W.UI
		for _ = 1, 3 do
			local ui = kit(ctx)
			local WM = ctx:mod("UI.Rider.Wrapped")
			if WM and type(WM.Shown) == "function" and WM.Shown() then ctx:na("the Wrapped story is open over the screen") end
			local over = ui.settingsOpen or (type(UI.HelpShown) == "function" and UI.HelpShown())
				or (type(UI.Bug) == "table" and type(UI.Bug.Shown) == "function" and UI.Bug.Shown())
				or (WM and type(WM.Shown) == "function" and WM.Shown())
			if not over then return end
			if ui.settingsOpen and type(UI.CloseSettings) == "function" then pcall(UI.CloseSettings, true) end
			ctx.me:pressEscape()
			ctx:advance(0.8)
			ctx:note("press Escape over what is open")
			if not UI.IsShown() then
				ctx.me:slash("/wuber")
				ctx:advance(2.5)
				ctx:note("/wuber again")
			end
		end
	end

	local function openHome(ctx)
		conditions(ctx)
		local UI = ctx.W.UI
		if not UI.IsShown() then
			ctx.me:slash("/wuber")
			ctx:advance(0.3)
			ctx:note("/wuber")
		end
		ctx:advance(2.5)
		clearOverlays(ctx)
		local ui = kit(ctx)
		if ui.tab ~= "Ride" then
			for _, tab in ipairs(ui.tabs or {}) do
				if tab.name == "Ride" and tab.button then
					ctx.me:clickOn(tab.button)
					ctx:advance(0.8)
					ctx:note("click the Ride tab")
					break
				end
			end
		end
		if ui.screen ~= "home" then ctx:na("Home is not reachable from this screen (" .. tostring(ui.screen) .. ")") end
		dismissTip(ctx)
		ctx:advance(1.5)
		for _ = 1, 3 do
			local b = ctx.me:button("Got it")
			local nn = ctx.me:button("Not now")
			if not (b and ctx:visible(b)) and nn and ctx:visible(nn) then b = nn end
			if b and ctx:visible(b) then
				ctx.me:clickOn(b)
				ctx:advance(0.6)
				ctx:note("close the What's new card (Got it / Not now)")
			else
				break
			end
		end
		local BirdM = ctx:mod("UI.Bird")
		local okc, bc = pcall(BirdM and BirdM.Card or function() end)
		if okc and type(bc) == "table" and ctx:visible(bc) and bc.x and ctx:visible(bc.x) then
			ctx.me:clickOn(bc.x)
			ctx:advance(0.6)
			ctx:note("close the Skip the bird card")
		end
		dismissTip(ctx)
		return homeScr(ctx)
	end

	local function setAdvanced(ctx, want)
		if ctx.W.Advanced() ~= want then
			ctx.me:slash("/wuber advanced")
			ctx:advance(0.6)
			ctx:note("toggle advanced mode " .. (want and "on" or "off"))
		end
		if ctx.W.Advanced() ~= want then ctx:cannot("could not switch advanced mode") end
	end

	local function hoverTip(ctx, frame)
		local gt = ctx.me.env.GameTooltip
		if gt and gt.Hide then gt:Hide() end
		local fn = frame.GetScript and frame:GetScript("OnEnter")
		if fn then fn(frame) end
		local out = {}
		if gt and gt.IsShown and gt:IsShown() then
			for i = 1, 8 do
				local fs = ctx.me.env["GameTooltipTextLeft" .. i]
				local txt = fs and fs.GetText and fs:GetText()
				if type(txt) == "string" and txt:match("%S") then
					out[#out + 1] = txt
				end
			end
		end
		return table.concat(out, " | ")
	end

	local function wdb(ctx)
		local s = ctx.saved
		if type(s) ~= "table" then s = {} ctx.saved = s end
		if type(s.Wuber) == "table" then return s.Wuber end
		if s.chars ~= nil or s.rides ~= nil or s.fx ~= nil then return s end
		s.Wuber = {}
		return s.Wuber
	end

	local function riderish(sit) return is(sit, "ride", "none") and is(sit, "combat", "no") end

	local function search(ctx, text)
		local s = homeScr(ctx)
		ctx.me:type(s.search.edit, text)
		ctx:advance(1.2)
		ctx:note("type " .. text .. " in Where to?")
	end

	local NEW_NAMES = { "Eli Marsh", "Fay Doyle", "Gus Hale", "Hal Nash", "Ivy Cole" }
	local function addDriver(ctx, spot, price)
		local name
		for _, n in ipairs(NEW_NAMES) do
			if not ctx.w:player(n) then name = n break end
		end
		if not name then ctx:cannot("no free name for a driver") end
		local d = ctx.w:addClient(name, { spot = spot, class = "WARLOCK", shards = 10, money = 100000 })
		if d.W.Char then
			d.W.Char().welcomed = true
			if price then d.W.Char().price = price end
		end
		if not (d.W.Driver and type(d.W.Driver.SetOnline) == "function") then
			ctx:cannot("the driver window has no Driver.SetOnline")
		end
		if d.W.Driver.SetOnline(true) == false then ctx:cannot("the driver could not open") end
		ctx:note(name .. " opens in " .. spot)
		return d, name
	end

	-- 1. Search clear button
	Hunt.promise{
		id = "b4home.search_clear_restores_all",
		area = "Home",
		text = "Typing in Where to? shows a clear button, and clicking it clears the search and brings back every online driver.",
		source = "Wuber/UI/Rider/Cards.lua:681 (Clear the search and show every driver.)",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { one = true, many = true }) end,
		check = function(ctx)
			local s = openHome(ctx)
			local before = cards(ctx)
			if #before == 0 then ctx:na("no drivers listed") end
			search(ctx, "zzzznotaplace")
			if #cards(ctx) ~= 0 then ctx:na("search did not filter out the drivers") end
			local clr = s.search and s.search.clear
			if not (clr and ctx:visible(clr)) then
				ctx:fail("You type in Where to? and no clear button appears.", joined(ctx))
			end
			ctx.me:clickOn(clr)
			ctx:advance(0.8)
			ctx:note("click the search clear button")
			local after = cards(ctx)
			if #after ~= #before then
				ctx:fail(("You click the clear button and Home shows %d drivers instead of %d."):format(#after, #before), joined(ctx))
			end
		end,
	}

	-- 2. Clicking a paused driver's row
	Hunt.promise{
		id = "b4home.paused_driver_toast",
		area = "Home",
		text = "Clicking a paused driver's row on Home does not open the booking screen and tells you they have paused for now.",
		source = "Wuber/UI/Rider/Cards.lua:272,291 (Paused for now. / has paused for now)",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { none = true, one = true, many = true }) and is(sit, "role", "rider") end,
		check = function(ctx)
			openHome(ctx)
			local d, name = addDriver(ctx, "Gadgetzan", 5000)
			ctx:advance(6)
			d.W.Driver.SetPaused(true)
			ctx:advance(6)
			ctx:note(name .. " pauses")
			openHome(ctx)
			local found
			for _, item in ipairs(cards(ctx)) do
				if item.card.view and item.card.view.name == name then found = item.card break end
			end
			if not found then ctx:na("the paused driver is not listed on Home") end
			intoView(ctx, found)
			ctx.me:clickOn(found)
			ctx:advance(0.8)
			ctx:note("click the paused driver " .. name)
			if kit(ctx).screen == "confirm" then
				ctx:fail(("You click a paused driver (%s) and Wuber opens the booking screen."):format(name), joined(ctx))
			end
			if not has(ctx, "paused for now") then
				ctx:fail(("You click a paused driver (%s) and Wuber does not tell you they have paused for now."):format(name), joined(ctx))
			end
		end,
	}

	-- 3. Ping drivers 20s cooldown
	Hunt.promise{
		id = "b4home.ping_cooldown_blocks_repeat",
		area = "Home",
		text = "Clicking Ping drivers when nobody is online asks drivers to check in and puts Ping drivers on a 20-second cooldown showing seconds left.",
		source = "Wuber/UI/Rider/Home.lua:648,655,661 (Asked every driver to check in / Ping again in <N> s)",
		kind = "scenario",
		needs = { net = "none", role = "rider" },
		when = function(sit) return riderish(sit) end,
		check = function(ctx)
			local s = openHome(ctx)
			ctx:advance(21)
			s = openHome(ctx)
			local ping = s.empty and s.empty.ping
			if not (ping and ctx:visible(ping)) then ctx:na("Ping drivers is not shown on the empty screen") end
			ctx.me:clickOn(ping)
			ctx:advance(0.6)
			ctx:note("click Ping drivers")
			if not (has(ctx, "Asked every driver to check in") or has(ctx, "Drivers were just asked")) then
				ctx:fail("You click Ping drivers and Wuber does not say it asked drivers to check in.", joined(ctx))
			end
			if not hasPat(ctx, "Ping again in %d+ s") then
				ctx:fail("You click Ping drivers and the button does not show the cooldown in seconds.", joined(ctx))
			end
			ctx:advance(21)
			if not has(ctx, "Ping drivers") then
				ctx:fail("After 21 seconds the Ping drivers button is still on cooldown.", joined(ctx))
			end
		end,
	}

	-- 4. Why? link opens Help
	Hunt.promise{
		id = "b4home.why_opens_help",
		area = "Home",
		text = "Clicking Why? when no drivers are online opens the Help page explaining how Wuber finds drivers.",
		source = "Wuber/UI/Rider/Home.lua:686 (Why can't I see anyone?: How Wuber finds drivers, and what helps when the list is short.)",
		kind = "scenario",
		needs = { net = "none", role = "rider" },
		when = function(sit) return riderish(sit) end,
		check = function(ctx)
			local s = openHome(ctx)
			local why = s.empty and s.empty.why
			if not (why and ctx:visible(why)) then ctx:na("Why? link is not shown") end
			ctx.me:clickOn(why)
			ctx:advance(0.8)
			ctx:note("click Why?")
			local UI = ctx.W.UI
			if not (type(UI.HelpShown) == "function" and UI.HelpShown()) then
				ctx:fail("You click Why? on empty Home and the Help page does not open.", joined(ctx))
			end
		end,
	}

	-- 5. Own driver chip opens Drive tab
	Hunt.promise{
		id = "b4home.own_chip_opens_drive",
		area = "Home",
		text = "When you are open as a driver and other drivers are online, Home shows your own status chip above the list and clicking it opens the Drive tab.",
		source = "Wuber/UI/Rider/Home.lua:482 (Click to open the Drive tab.)",
		kind = "scenario",
		needs = { role = "warlock", net = "one" },
		when = function(sit) return riderish(sit) end,
		check = function(ctx)
			local s = openHome(ctx)
			if not (ctx.W.Drive and ctx.W.Drive.IsOpen()) then ctx:na("not open as a driver") end
			local oc = s.ownChip
			if not (oc and ctx:visible(oc)) then
				ctx:fail("You are open as a driver with another driver online and Home shows no status chip for you.", joined(ctx))
			end
			ctx.me:clickOn(oc)
			ctx:advance(0.8)
			ctx:note("click own driver chip")
			if kit(ctx).tab ~= "Drive" then
				ctx:fail("You click your own driver chip on Home and Wuber does not open the Drive tab.", joined(ctx))
			end
		end,
	}

	-- 6. Your usual hidden when already at that city
	Hunt.promise{
		id = "b4home.usual_already_there_hidden",
		area = "Home",
		text = "When you are already standing in your usual destination, Home does not offer Your usual or Ride again to that city.",
		source = "docs/PLAYER-GUIDE.md:38; Wuber/UI/Rider/Home.lua:1597 (Your usual: you are already there.)",
		kind = "scenario",
		needs = { saved = "fresh", net = "one", role = "rider" },
		when = function(sit) return riderish(sit) end,
		pre = function(ctx)
			local d = wdb(ctx)
			d.rides = d.rides or {}
			local t = 1700000000 - 5 * 86400
			for i = 1, 3 do
				d.rides[#d.rides + 1] = { dest = "Ratchet", driver = "Ana Smith", driverKey = "ana smith", price = 5000, at = t + i * 3600, stars = 5 }
			end
		end,
		check = function(ctx)
			ctx.w:move(ctx.name, "Ratchet")
			ctx:advance(2)
			openHome(ctx)
			local t = joined(ctx):lower()
			if t:find("your usual", 1, true) or t:find("ride again", 1, true) then
				ctx:fail("You are already standing in Ratchet and Home still offers Your usual / Ride again to Ratchet.", joined(ctx))
			end
		end,
	}

	-- 7. Your usual nobody's there note
	Hunt.promise{
		id = "b4home.usual_nobody_note",
		area = "Home",
		text = "When other drivers are online but nobody is serving your usual destination, Home shows a quiet note saying nobody is there right now.",
		source = "inferred",
		kind = "scenario",
		needs = { saved = "fresh", net = "one", role = "rider" },
		when = function(sit) return riderish(sit) end,
		pre = function(ctx)
			local d = wdb(ctx)
			d.rides = d.rides or {}
			local t = 1700000000 - 5 * 86400
			for i = 1, 3 do
				d.rides[#d.rides + 1] = { dest = "Ironforge", driver = "Ghost Driver", driverKey = "ghost driver", price = 5000, at = t + i * 3600, stars = 5 }
			end
		end,
		check = function(ctx)
			openHome(ctx)
			ctx:advance(16)
			if not has(ctx, "Your usual: Ironforge - nobody's there right now") then
				ctx:fail("Your usual place is Ironforge, nobody serves Ironforge while another driver is online, and Home does not show the nobody's there note.", joined(ctx))
			end
		end,
	}

	-- 8. Your usual main button books
	Hunt.promise{
		id = "b4home.usual_main_button_books",
		area = "Home",
		text = "When Your usual is shown on Home, the main button reads Ride again · <place> · <price> and clicking it opens that driver's booking screen.",
		source = "docs/PLAYER-GUIDE.md:36 ('Your usual' shows 'Ride again · <place> · <price>' for the ride you take most.)",
		kind = "scenario",
		needs = { saved = "fresh", net = "one", role = "rider" },
		when = function(sit) return riderish(sit) end,
		pre = function(ctx)
			local d = wdb(ctx)
			d.rides = d.rides or {}
			local t = 1700000000 - 5 * 86400
			for i = 1, 3 do
				d.rides[#d.rides + 1] = { dest = "Ratchet", driver = "Ana Smith", driverKey = "ana smith", price = 5000, at = t + i * 3600, stars = 5 }
			end
		end,
		check = function(ctx)
			local s = openHome(ctx)
			if not (s.main and ctx:visible(s.main)) then
				ctx:na("Ride again main button is not shown")
			end
			local lbl = s.main.label and s.main.label:GetText() or ""
			if not lbl:find("^Ride again · Ratchet · 50s") then
				ctx:fail(("The Ride again main button reads '%s' instead of 'Ride again · Ratchet · 50s'."):format(lbl), joined(ctx))
			end
			ctx.me:clickOn(s.main)
			ctx:advance(0.8)
			ctx:note("click Ride again main button")
			if kit(ctx).screen ~= "confirm" then
				ctx:fail("You click the Ride again main button and Wuber does not open the booking screen.", joined(ctx))
			end
		end,
	}

	-- 9. Right-click card menu only in Advanced mode
	Hunt.promise{
		id = "b4home.right_click_menu_advanced_only",
		area = "Home",
		text = "Right-clicking a driver's row opens the Favourite / Hide this driver menu in Advanced mode, and does not open it in Simple mode.",
		source = "docs/PLAYER-GUIDE.md:34,75; Wuber/UI/Rider/Cards.lua:292 (Right-click to favourite or hide.)",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { one = true, many = true }) and is(sit, "role", "rider") end,
		check = function(ctx)
			openHome(ctx)
			setAdvanced(ctx, false)
			local list = cards(ctx)
			if not list[1] then ctx:na("no driver row to right-click") end
			intoView(ctx, list[1].card)
			ctx.me:clickOn(list[1].card, "RightButton")
			ctx:advance(0.6)
			ctx:note("right-click driver row in Simple mode")
			if has(ctx, "Hide this driver") then
				ctx:fail("In Simple mode, right-clicking a driver row opens the Hide this driver menu.", joined(ctx))
			end
			setAdvanced(ctx, true)
			list = cards(ctx)
			if not list[1] then ctx:na("no driver row after switching to Advanced") end
			intoView(ctx, list[1].card)
			ctx.me:clickOn(list[1].card, "RightButton")
			ctx:advance(0.6)
			ctx:note("right-click driver row in Advanced mode")
			if not has(ctx, "Hide this driver") then
				ctx:fail("In Advanced mode, right-clicking a driver row does not open the Favourite / Hide this driver menu.", joined(ctx))
			end
		end,
	}

	-- 10. Raid card request and cancel
	Hunt.promise{
		id = "b4home.raid_card_request_and_cancel",
		area = "Home",
		text = "When your raid runs raid summons, Home shows the raid card and Request a summon; clicking it puts you on the summon list and offers Cancel request, which removes you.",
		source = "docs/PLAYER-GUIDE.md:36; Wuber/UI/Rider/Home.lua:245,944",
		kind = "scenario",
		needs = { group = "raid", role = "rider" },
		when = function(sit) return riderish(sit) end,
		check = function(ctx)
			local rname
			for _, n in ipairs(NEW_NAMES) do
				if not ctx.w:player(n) then rname = n break end
			end
			if not rname then ctx:cannot("no free name for raid Warlock") end
			local spot = (tostring(ctx.me.player.zone or "") == "Orgrimmar") and "Undercity" or "Orgrimmar"
			local runner = ctx.w:addClient(rname, { spot = spot, class = "WARLOCK", shards = 10, money = 100000 })
			if runner.W.Char then runner.W.Char().welcomed = true end
			ctx.me.env.InviteUnit(rname)
			ctx:advance(0.2)
			runner.env.AcceptGroup()
			ctx:advance(0.5)
			ctx.me.env.PromoteToLeader(rname)
			ctx:advance(0.5)
			if not (runner.W.Drive and runner.W.Drive.SetMode and runner.W.Drive.SetRaidRun) then
				ctx:cannot("no SetMode/SetRaidRun on raid Warlock")
			end
			runner.W.Drive.SetMode("raid")
			local ok, why = runner.W.Drive.SetRaidRun(true)
			if not ok then ctx:cannot("raid Warlock could not start raid summons: " .. tostring(why)) end
			ctx:advance(6)
			local s = openHome(ctx)
			if not (s.raidCard and ctx:visible(s.raidCard)) then
				ctx:fail("Your raid is running raid summons and Home shows no raid card.", joined(ctx))
			end
			if not (s.main and ctx:visible(s.main) and has(ctx, "Request a summon")) then
				ctx:fail("Your raid is running raid summons and Home does not offer Request a summon.", joined(ctx))
			end
			ctx.me:clickOn(s.main)
			ctx:advance(8)
			ctx:note("click Request a summon")
			if not has(ctx, "Cancel request") then
				ctx:fail("You click Request a summon and the raid card does not offer Cancel request.", joined(ctx))
			end
			ctx.me:clickText("Cancel request")
			ctx:advance(8)
			ctx:note("click Cancel request")
			if has(ctx, "Cancel request") then
				ctx:fail("You click Cancel request and you are still on the raid summon list.", joined(ctx))
			end
		end,
	}

	-- 11. Bounty custom amount
	Hunt.promise{
		id = "b4home.bounty_custom_amount_pins",
		area = "Home",
		text = "In Advanced mode, searching a town nobody summons to lets you choose Custom, type an amount like 60s, and pin a bounty for 60s.",
		source = "Wuber/UI/Rider/Home.lua:389 (Type an amount like 60s or 1g 20s, then press Enter.)",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { none = true, one = true, many = true }) and is(sit, "role", "rider") end,
		check = function(ctx)
			local s = openHome(ctx)
			setAdvanced(ctx, true)
			s = openHome(ctx)
			search(ctx, "Ironforge")
			local customBtn = ctx.me:button("Custom")
			if not (customBtn and ctx:visible(customBtn)) then
				ctx:fail("You search Ironforge in Advanced mode and no Custom bounty amount pill shows.", joined(ctx))
			end
			ctx.me:clickOn(customBtn)
			ctx:advance(0.4)
			ctx:note("click Custom")
			local bb = s.empty and s.empty.bounty
			if not (bb and bb.custom and bb.custom.edit and ctx:visible(bb.custom.edit)) then
				ctx:fail("You click Custom on the bounty card and no amount input box appears.", joined(ctx))
			end
			ctx.me:type(bb.custom.edit, "60s")
			ctx:advance(0.6)
			ctx:note("type 60s in custom bounty box")
			if not has(ctx, "Pin 60s") then
				ctx:fail("You type 60s in Custom and the button does not update to Pin 60s.", joined(ctx))
			end
			ctx.me:clickText("Pin 60s")
			ctx:advance(1)
			ctx:note("click Pin 60s")
			if not hasPat(ctx, "Your bounty: 60s for Ironforge") then
				ctx:fail("You pin a 60s custom bounty for Ironforge and Home does not show Your bounty: 60s for Ironforge.", joined(ctx))
			end
		end,
	}

	-- 12. Simple mode hides bounty card
	Hunt.promise{
		id = "b4home.bounty_not_in_simple_mode",
		area = "Home",
		text = "In Simple mode, searching a town nobody summons to does not show the bounty pinning card.",
		source = "docs/PLAYER-GUIDE.md:75 (In Simple mode, Riders see the map, the drivers and one main button.)",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { none = true, one = true, many = true }) and is(sit, "role", "rider") end,
		check = function(ctx)
			openHome(ctx)
			setAdvanced(ctx, false)
			search(ctx, "Ironforge")
			for _, t in ipairs(ctx:texts()) do
				if t:match("^Pin %d") or t == "Pin a bounty so drivers see you want it:" then
					ctx:fail("In Simple mode, searching a town nobody summons to still shows the bounty pinning card.", joined(ctx))
				end
			end
		end,
	}

	-- 13. PvP shield shown and tooltip
	Hunt.promise{
		id = "b4home.pvp_shield_shown_and_tooltip",
		area = "Home",
		text = "When a driver's summon spot has PvP danger reported, their row on Home shows a shield whose tooltip warns PvP near the summon.",
		source = "Wuber/UI/Rider/Cards.lua:464-491 (PvP near the summon / You may land in a fight.)",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { one = true, many = true }) and is(sit, "role", "rider") end,
		check = function(ctx)
			openHome(ctx)
			local list = cards(ctx)
			if not list[1] then ctx:na("no driver row on Home") end
			local c = list[1].card
			local k = c.key
			local drv = ctx.W.drivers and ctx.W.drivers[k]
			if not drv then ctx:na("driver record not found") end
			drv.danger = 2
			drv.dangerAt = ctx.W.Now and ctx.W.Now() or time()
			ctx.W.UI.Refresh(true)
			ctx:advance(0.6)
			ctx:note("mark driver spot with PvP danger")
			intoView(ctx, c)
			if not (c.shield and ctx:visible(c.shield)) then
				ctx:fail("A driver has PvP danger at their summon spot and no shield shows on their row.", joined(ctx))
			end
			local tip = hoverTip(ctx, c.shield)
			if not (tip:find("PvP near the summon", 1, true) and tip:find("You may land in a fight", 1, true)) then
				ctx:fail(("Hovering the PvP shield shows '%s' instead of the PvP warning."):format(tip), joined(ctx))
			end
		end,
	}

	-- 14. Rank chip and busy / group full states
	Hunt.promise{
		id = "b4home.rank_chip_and_busy_states",
		area = "Home",
		text = "A driver with 10 or more verified summons shows their rank title and count on their row, and a busy driver shows Busy or Group full.",
		source = "docs/PLAYER-GUIDE.md:69 (Cabbie starts at 10 confirmed summons); inferred",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { one = true, many = true }) end,
		check = function(ctx)
			openHome(ctx)
			local list = cards(ctx)
			if not list[1] then ctx:na("no driver row on Home") end
			local c = list[1].card
			local drv = ctx.W.drivers and ctx.W.drivers[c.key]
			if not drv then ctx:na("driver record not found") end
			drv.rank = 10
			drv.state = "busy"
			drv.queue = 2
			drv.seats = 0
			ctx.W.UI.Refresh(true)
			ctx:advance(0.6)
			ctx:note("set driver rank 10, busy queue 2, group full")
			if not (c.rankChip and ctx:visible(c.rankChip)) then
				ctx:fail("A driver with 10 verified summons shows no rank badge on their row.", joined(ctx))
			end
			local tip = hoverTip(ctx, c.rankChip)
			if not tip:find("Cabbie", 1, true) then
				ctx:fail(("A driver with 10 verified summons shows '%s' instead of Cabbie."):format(tip), joined(ctx))
			end
			if not has(ctx, "Busy · 2 waiting") then
				ctx:fail("A busy driver with 2 waiting does not show 'Busy · 2 waiting' on their row.", joined(ctx))
			end
			if not has(ctx, "Group full") then
				ctx:fail("A driver with 0 seats left does not show 'Group full' on their row.", joined(ctx))
			end
		end,
	}
end
