-- New promises for Rider Booking flow (Wuber/UI/Rider/Booking.lua, Confirm.lua, Done.lua).
-- Prefix: b4booking. Written from source contracts, tooltips, and player-visible screen behaviour.
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

	local function screens(ctx)
		local WM = ctx:mod("UI.Window")
		return WM and type(WM.screens) == "table" and WM.screens or {}
	end

	local function joined(ctx) return table.concat(ctx:texts(), " | ") end

	local function has(ctx, text)
		for _, t in ipairs(ctx:texts()) do
			if t:find(text, 1, true) then return t end
		end
		return nil
	end

	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end

	local function cards(ctx)
		local out = {}
		for k, c in pairs(kit(ctx).cards or {}) do
			if c.key and c.view and ctx:visible(c) then
				out[#out + 1] = { key = k, card = c, y = c.targetY or c.curY or 0 }
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

	local function openPhone(ctx)
		local UI = ctx.W.UI
		if not UI.IsShown() then
			ctx.me:slash("/wuber")
			ctx:advance(0.3)
			ctx:note("/wuber")
		end
		ctx:advance(2.5)
		clearOverlays(ctx)
	end

	local function openRideTab(ctx)
		openPhone(ctx)
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
		for _ = 1, 3 do
			local b = ctx.me:button("Got it")
			local nn = ctx.me:button("Not now")
			if not (b and ctx:visible(b)) and nn and ctx:visible(nn) then b = nn end
			if b and ctx:visible(b) then
				ctx.me:clickOn(b)
				ctx:advance(0.6)
				ctx:note("close the overlay card")
			else
				break
			end
		end
	end

	local function openHome(ctx)
		conditions(ctx)
		openPhone(ctx)
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
				ctx:note("close the What's new card")
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
		return screens(ctx).home
	end

	local function cardOf(ctx, name)
		for _, c in ipairs(cards(ctx)) do
			if key(c.card.view.name) == key(name) then return c.card end
		end
		return nil
	end

	local function tapDriver(ctx, d)
		dismissTip(ctx)
		local c = cardOf(ctx, d.name)
		if not c then ctx:na(d.name .. " has no card on Home here") end
		if c.view.state == "paused" then ctx:na(d.name .. " is paused") end
		intoView(ctx, c)
		local function hitIsCard()
			local okc, cx, cy = pcall(c.title.GetCenter, c.title)
			if not (okc and cx) then return true end
			local ratio = c.title:GetEffectiveScale() / ctx.me.env.UIParent:GetEffectiveScale()
			local hit = ctx.me:frameAt(cx * ratio, cy * ratio)
			local f = hit
			while f do
				if f == c then return true end
				f = f.GetParent and f:GetParent() or nil
			end
			return false
		end
		for _ = 1, 8 do
			if hitIsCard() then break end
			local clip = c:GetParent() and c:GetParent():GetParent()
			local fn = clip and clip.GetScript and clip:GetScript("OnMouseWheel")
			if not fn then break end
			local r, cr = ctx.H.rect(c), ctx.H.rect(clip)
			local dir = (r and cr and (r.b + r.h / 2) < (cr.b + cr.h / 2)) and -1 or 1
			fn(clip, dir)
			ctx:advance(0.6)
			ctx:note("scroll the list until the row is clear of the bars")
		end
		if not hitIsCard() then ctx:na(d.name .. "'s card cannot be scrolled clear of the bars here") end
		ctx.me:clickOn(c.title)
		ctx:advance(1)
		ctx:note("tap " .. d.name .. "'s card")
		if kit(ctx).screen ~= "confirm" then
			ctx:na("Confirm did not open (" .. tostring(kit(ctx).screen) .. ")")
		end
		return screens(ctx).confirm
	end

	local function firstDriver(ctx)
		local d = ctx.facts.drivers and ctx.facts.drivers[1]
		if not (d and ctx.W.drivers and ctx.W.drivers[key(d.name)]) then ctx:na("the driver was not heard") end
		return { name = d.name, dest = d.dest, price = math.max(d.price, tonumber(ctx.W.MIN_PRICE) or 5000) }
	end

	local function setAdvanced(ctx, want)
		if ctx.W.Advanced() ~= want then
			ctx.me:slash("/wuber advanced")
			ctx:advance(0.6)
			ctx:note("toggle advanced mode " .. (want and "on" or "off"))
		end
		if ctx.W.Advanced() ~= want then ctx:cannot("could not switch advanced mode") end
	end

	local function setFold(ctx, wantUnfolded)
		local FM = ctx:mod("UI.Fold")
		if not (FM and type(FM.IsUnfolded) == "function") then ctx:na("fold module unavailable") end
		if FM.IsUnfolded() ~= wantUnfolded then
			local WM = ctx:mod("UI.Window")
			local foldBtn = WM and WM.foldBtn
			if not (foldBtn and ctx:visible(foldBtn)) then ctx:na("fold button is not visible") end
			ctx.me:clickOn(foldBtn)
			ctx:advance(1.0)
			ctx:note(wantUnfolded and "unfold the window" or "fold the window")
		end
		if FM.IsUnfolded() ~= wantUnfolded then ctx:na("could not change fold state") end
	end

	local function riderOnly(sit) return is(sit, "role", "rider") and is(sit, "ride", "none") and is(sit, "combat", "no") end
	local LIST_NETS = { one = true, many = true, late = true }

	-- 1. Back button on Confirm returns to Home
	Hunt.promise{
		id = "b4booking.back_returns_home",
		area = "Booking",
		text = "Clicking the back button on the booking screen returns you to the list of drivers on Home.",
		source = "Wuber/UI/Rider/Confirm.lua:235,394 (safeScript(s.back, OnClick -> UI.Show('home')))",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			local s = tapDriver(ctx, d)
			if not (s and s.back and ctx:visible(s.back)) then
				ctx:fail("The booking screen has no visible back button.", joined(ctx))
			end
			ctx.me:clickOn(s.back)
			ctx:advance(0.8)
			ctx:note("click the back button")
			if kit(ctx).screen ~= "home" then
				ctx:fail("You click the back button on the booking screen and it does not return to Home (shows " .. tostring(kit(ctx).screen) .. ").", joined(ctx))
			end
		end,
	}

	-- 2. Favourite heart toggles on Confirm
	Hunt.promise{
		id = "b4booking.favourite_heart_toggles",
		area = "Booking",
		text = "Clicking Favourite on the booking screen toggles the driver's heart on, and clicking it again toggles it off.",
		source = "Wuber/UI/Rider/Confirm.lua:287-303,479-480 (card.heart toggles favourite)",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			local s = tapDriver(ctx, d)
			local heart = s and s.card and s.card.heart
			if not (heart and ctx:visible(heart)) then
				ctx:fail("The booking screen has no visible Favourite heart button.", joined(ctx))
			end
			local CM = ctx:mod("UI.Rider.Cards")
			local k = key(d.name)
			local before = CM and CM.isFav and CM.isFav(k) or false
			ctx.me:clickOn(heart)
			ctx:advance(0.6)
			ctx:note("click Favourite heart")
			local mid = CM and CM.isFav and CM.isFav(k) or false
			if mid == before then
				ctx:fail("You click Favourite on the booking screen and the driver's favourite state does not change.", joined(ctx))
			end
			ctx.me:clickOn(heart)
			ctx:advance(0.6)
			ctx:note("click Favourite heart again")
			local after = CM and CM.isFav and CM.isFav(k) or false
			if after ~= before then
				ctx:fail("You click Favourite a second time on the booking screen and it does not toggle back.", joined(ctx))
			end
		end,
	}

	-- 3. Driver goes offline while Confirm is open
	Hunt.promise{
		id = "b4booking.driver_goes_offline_on_confirm",
		area = "Booking",
		text = "If the driver you are viewing on the booking screen goes offline, the screen says the driver went offline and disables Request.",
		source = "Wuber/UI/Rider/Confirm.lua:455-466 (not d -> 'This driver went offline', request:SetActive(false))",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and is(sit, "net", { one = true, many = true }) end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			local peer = ctx.peers and ctx.peers.driver
			if not (peer and peer.W and peer.W.Driver and type(peer.W.Driver.SetOnline) == "function") then
				ctx:na("no controllable driver peer")
			end
			local s = tapDriver(ctx, d)
			peer.W.Driver.SetOnline(false)
			ctx:note(d.name .. " goes offline")
			ctx:advance(5)
			-- Clear driver cache if needed by advancing past beacon drop or checking if offline notice arrived
			if ctx.W.drivers and ctx.W.drivers[key(d.name)] then
				ctx:advance(185)
			end
			if kit(ctx).screen ~= "confirm" then ctx:na("screen left confirm (" .. tostring(kit(ctx).screen) .. ")") end
			if not has(ctx, "This driver went offline") then
				ctx:fail("The driver went offline while you were on the booking screen, and it does not say 'This driver went offline'.", joined(ctx))
			end
			if not (s.request and s.request.inactive) then
				ctx:fail("The driver went offline on the booking screen, and Request is still active.", joined(ctx))
			end
		end,
	}

	-- 4. Raincheck toggle updates payment note on Confirm
	Hunt.promise{
		id = "b4booking.raincheck_toggle_updates_pay",
		area = "Booking",
		text = "Switching Use raincheck off on the booking screen changes the payment note back to paying the full fare by trade.",
		source = "Wuber/UI/Rider/Confirm.lua:343-353,571-618 (rc.toggle updates Raincheck.Use and s.note)",
		kind = "scenario",
		needs = { ride = "raincheck" },
		when = function(sit) return is(sit, "role", "rider") and is(sit, "combat", "no") and is(sit, "net", { one = true, many = true }) end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			local s = tapDriver(ctx, d)
			if not (s.rc and ctx:visible(s.rc) and s.rc.toggle and ctx:visible(s.rc.toggle)) then
				ctx:na("no raincheck row on Confirm")
			end
			if not has(ctx, "Raincheck covers") then
				ctx:fail("You have a raincheck for this driver, and the booking screen does not say what it covers.", joined(ctx))
			end
			ctx.me:clickOn(s.rc.toggle)
			ctx:advance(0.6)
			ctx:note("toggle Use raincheck off")
			if not has(ctx, "Trade ") then
				ctx:fail("You switch Use raincheck off on the booking screen and the payment note does not switch back to 'Trade ... after you arrive'.", joined(ctx))
			end
		end,
	}

	-- 5. In combat on Confirm labels Request and clicking still sends request
	Hunt.promise{
		id = "b4booking.in_combat_request_no_whisper",
		area = "Booking",
		text = "Entering combat on the booking screen labels Request summon with '(in combat: no whisper)' and clicking it still sends the request.",
		source = "Wuber/UI/Rider/Confirm.lua:369-380,627-632 (inCombat -> '(in combat: no whisper)' and W.RequestRide)",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] and is(sit, "group", "solo") end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			local s = tapDriver(ctx, d)
			if not (s.request and ctx:visible(s.request)) then ctx:na("Request button not visible") end
			if s.request.inactive then ctx:na("Request button is inactive here") end
			ctx.w:enterCombat(ctx.me)
			ctx:advance(0.5)
			ctx:note("enter combat on Confirm")
			if not has(ctx, "(in combat: no whisper)") then
				ctx:fail("You enter combat on the booking screen and Request summon does not say '(in combat: no whisper)'.", joined(ctx))
			end
			ctx.me:clickOn(s.request)
			ctx:advance(1.5)
			ctx:note("click Request summon in combat")
			ctx.w:leaveCombat(ctx.me)
			if not ctx.W.ride then
				ctx:fail("You click Request summon in combat and no ride request is started.", joined(ctx))
			end
		end,
	}

	-- 6. PvP warning shown on Confirm when driver has danger
	Hunt.promise{
		id = "b4booking.pvp_warning_shown_when_danger",
		area = "Booking",
		text = "When a driver's summon spot has PvP danger nearby, the booking screen shows the PvP warning card.",
		source = "Wuber/UI/Rider/Confirm.lua:326-329,558-569 (UI.DangerOf -> s.pvp shown)",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and is(sit, "net", { one = true, many = true }) end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			local drv = ctx.W.drivers and ctx.W.drivers[key(d.name)]
			if not drv then ctx:na("driver record missing") end
			drv.danger = 2
			drv.dangerAt = ctx.me.env.time and ctx.me.env.time() or 1000
			local s = tapDriver(ctx, d)
			if not (s.pvp and ctx:visible(s.pvp)) then
				ctx:fail("The driver's summon spot has PvP danger nearby, and the booking screen does not show the PvP warning card.", joined(ctx))
			end
		end,
	}

	-- 7. Simple mode replaces Fly or summon dial with plain text summary
	Hunt.promise{
		id = "b4booking.simple_mode_replaces_dial",
		area = "Booking",
		text = "In Simple mode, the booking screen replaces the Fly or summon dial with a plain text summary of summon and flight times.",
		source = "Wuber/UI/Rider/Confirm.lua:161-179,529-550 (not adv and info -> simpleDialLine)",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] end,
		check = function(ctx)
			openHome(ctx)
			setAdvanced(ctx, false)
			local d = firstDriver(ctx)
			local s = tapDriver(ctx, d)
			if not s.dialSimple then ctx:na("no simple dial frame") end
			local info = ctx:mod("UI.Rider.Booking").DialInfo(ctx.W.drivers[key(d.name)], d.price)
			if not info then ctx:na("no flight time known to this destination") end
			if ctx:visible(s.dial) then
				ctx:fail("In Simple mode, the Fly or summon dial is still visible instead of the plain text summary.", joined(ctx))
			end
			if not ctx:visible(s.dialSimple) then
				ctx:fail("In Simple mode with a known flight time, the plain text summon/fly summary is hidden.", joined(ctx))
			end
		end,
	}

	-- 8. Unfolded Confirm in Advanced mode shows 'About this driver'
	Hunt.promise{
		id = "b4booking.unfolded_shows_about_driver",
		area = "Booking",
		text = "In Advanced mode when unfolded, the booking screen shows 'About this driver' with your ride history and who clicks the portal.",
		source = "Wuber/UI/Rider/Confirm.lua:867-894,1046-1085 (wideBlocks -> About this driver)",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] and sit.fold ~= "narrow" end,
		check = function(ctx)
			openHome(ctx)
			setAdvanced(ctx, true)
			setFold(ctx, true)
			local d = firstDriver(ctx)
			tapDriver(ctx, d)
			if not has(ctx, "About this driver") then
				ctx:fail("Unfolded in Advanced mode, the booking screen does not show the 'About this driver' card.", joined(ctx))
			end
			if not (has(ctx, "clicks the portal") or has(ctx, "click the portal")) then
				ctx:fail("The 'About this driver' card does not say who clicks the portal.", joined(ctx))
			end
		end,
	}

	-- 9. Returning rider sees ride count chip on Confirm
	Hunt.promise{
		id = "b4booking.returning_rider_again_chip",
		area = "Booking",
		text = "In Advanced mode, booking a driver you have ridden with before shows your ride count with them on the driver card.",
		source = "Wuber/UI/Rider/Confirm.lua:481-485,858-863 (againLine -> 'Nth ride with ...')",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] end,
		check = function(ctx)
			openHome(ctx)
			setAdvanced(ctx, true)
			local d = firstDriver(ctx)
			ctx.W.db.rides = ctx.W.db.rides or {}
			table.insert(ctx.W.db.rides, { driver = d.name, driverKey = key(d.name), dest = d.dest, price = d.price, at = 100 })
			local s = tapDriver(ctx, d)
			if not (s.card and s.card.again and ctx:visible(s.card.again)) then
				ctx:fail("You have ridden with " .. d.name .. " before, and the booking driver card does not show your ride count chip.", joined(ctx))
			end
			if not has(ctx, "2nd ride with") and not has(ctx, "ride with") then
				ctx:fail("The returning-rider chip on Confirm does not show 'Nth ride with ...'.", joined(ctx))
			end
		end,
	}

	-- 10. Route header updates when rider changes zone while Confirm is open
	Hunt.promise{
		id = "b4booking.route_header_updates_on_zone_change",
		area = "Booking",
		text = "When you move to a different zone while the booking screen is open, the route header updates its origin to your new location.",
		source = "Wuber/UI/Rider/Booking.lua:539-546 (ZONE_CHANGED -> refreshHeaders)",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			local s = tapDriver(ctx, d)
			if not (s.route and ctx:visible(s.route)) then ctx:na("route header hidden (already at destination)") end
			local beforeFrom = s.route.fromText
			ctx.w:move(ctx.name, { mapID = 1412, x = 0.5, y = 0.5, zone = "Mulgore", sub = "Bloodhoof Village" })
			ctx:advance(0.6)
			ctx:note("move to Bloodhoof Village in Mulgore")
			local afterFrom = s.route.fromText
			if afterFrom == beforeFrom then
				ctx:fail("You moved to Bloodhoof Village while the booking screen was open, and the route header still says '" .. tostring(beforeFrom) .. "'.", joined(ctx))
			end
		end,
	}

	-- 11. Clicking Done on the post-ride Done screen dismisses it and returns to Home
	Hunt.promise{
		id = "b4booking.done_button_returns_home",
		area = "Booking",
		text = "Clicking Done on the post-ride Done screen dismisses the completed ride and returns you to Home.",
		source = "Wuber/UI/Rider/Done.lua:220-226 (s.done -> UI.Dismiss())",
		kind = "scenario",
		needs = { ride = "ended" },
		when = function(sit) return is(sit, "role", "rider") and is(sit, "combat", "no") and sit.net ~= "none" end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			openRideTab(ctx)
			if kit(ctx).screen ~= "done" then ctx:na("not on Done screen (" .. tostring(kit(ctx).screen) .. ")") end
			local s = screens(ctx).done
			if not (s and s.done and ctx:visible(s.done)) then
				ctx:fail("The Done screen has no visible Done button.", joined(ctx))
			end
			ctx.me:clickOn(s.done)
			ctx:advance(0.8)
			ctx:note("click Done")
			if kit(ctx).screen ~= "home" then
				ctx:fail("You click Done on the Done screen and it does not return to Home (shows " .. tostring(kit(ctx).screen) .. ").", joined(ctx))
			end
		end,
	}

	-- 12. Ending a ride without paying shows 'Ride ended' warning and hides stars
	Hunt.promise{
		id = "b4booking.unpaid_done_shows_warning_no_stars",
		area = "Booking",
		text = "Ending a ride without paying shows 'Ride ended' with the non-payment warning and hides the star rating.",
		source = "Wuber/UI/Rider/Done.lua:294-334 (unpaid -> 'Ride ended', warning, stars hidden)",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return is(sit, "role", "rider") and is(sit, "combat", "no") and sit.net ~= "none" end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			openRideTab(ctx)
			local rv = ctx.W.ride
			if not rv then ctx:na("no active ride") end
			rv.unpaid = true
			rv.state = "done"
			ctx.W.UI.Refresh(true)
			ctx:advance(0.6)
			ctx:note("ride ends unpaid")
			if kit(ctx).screen ~= "done" then ctx:na("not on Done screen (" .. tostring(kit(ctx).screen) .. ")") end
			local s = screens(ctx).done
			if not has(ctx, "Ride ended") then
				ctx:fail("An unpaid ride ended and the Done screen does not say 'Ride ended'.", joined(ctx))
			end
			if not has(ctx, "Drivers can block riders who don't pay.") then
				ctx:fail("An unpaid ride ended and the Done screen does not warn that drivers can block riders who don't pay.", joined(ctx))
			end
			if s and s.stars and s.stars[1] and ctx:visible(s.stars[1]) then
				ctx:fail("An unpaid ride ended and the star rating buttons are still visible.", joined(ctx))
			end
		end,
	}

	-- 13. Sorry screen offers 'Ask for a raincheck' when a paid ride failed
	Hunt.promise{
		id = "b4booking.sorry_ask_raincheck_when_paid_failed",
		area = "Booking",
		text = "If a ride fails after you already paid, the Sorry screen offers 'Ask for a raincheck' and clicking it asks the driver.",
		source = "Wuber/UI/Rider/Done.lua:43-78,482-483 (UI.RaincheckAskable -> s.ask)",
		kind = "scenario",
		needs = { ride = "summoning" },
		when = function(sit) return is(sit, "role", "rider") and is(sit, "combat", "no") and is(sit, "net", { one = true, many = true }) end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			openRideTab(ctx)
			local rv = ctx.W.ride
			if not rv then ctx:na("no active ride") end
			local nowT = ctx.me.env.time and ctx.me.env.time() or 1000
			rv.paid = rv.price or 5000
			rv.paidAt = nowT
			rv.endedAt = nowT
			rv.arrived = false
			rv.arrivedAt = nil
			rv.state = "failed"
			ctx.W.UI.Refresh(true)
			ctx:advance(0.6)
			ctx:note("paid ride fails before arrival")
			if kit(ctx).screen ~= "sorry" then ctx:na("not on Sorry screen (" .. tostring(kit(ctx).screen) .. ")") end
			local s = screens(ctx).sorry
			if not (s and s.ask and ctx:visible(s.ask)) then
				ctx:fail("A paid ride failed before arrival and the Sorry screen does not show 'Ask for a raincheck'.", joined(ctx))
			end
			ctx.me:clickOn(s.ask)
			ctx:advance(0.8)
			ctx:note("click Ask for a raincheck")
			if ctx:visible(s.ask) then
				ctx:fail("You clicked 'Ask for a raincheck' on the Sorry screen and the button stayed visible.", joined(ctx))
			end
		end,
	}
end
