-- Promises about the rider's ride once a driver is found (tests/promises/ride.lua; owner RIDEPAY).
-- Written from what the player is told: the Driver-found screen and its tooltips (Wuber/UI/Rider/Ride.lua, Done.lua),
-- the Settings texts for auto-accept and Leave the group, the arrival toasts, the minimap flash.
-- The checks reach things as a player does: the phone's own buttons, the driver's own window (ctx.peers.driver), waiting.
return function(Hunt)
	-- the fold dial's "folded_click" needs a phone that is open on a wide page; a promise that takes the default
	-- (closed) phone would only get cannot-build, so it stays out of that situation
	local FOLDABLE = { home = true, trips = true, drive = true, drive_earnings = true, drive_messages = true, drive_customers = true,
		settings = true, settings_riding = true, settings_driving = true, settings_map = true, settings_sound = true,
		settings_window = true, world_view = true, here_view = true, confirm = true, wrapped = true }
	local function promise(p)
		local w = p.when
		p.when = function(sit)
			if sit.fold == "folded_click" and not FOLDABLE[sit.phone or "closed"] then return false end
			return w == nil or w(sit)
		end
		Hunt.promise(p)
	end
	local function sitIs(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		if type(want) == "table" then return want[v] == true end
		return v == want
	end
	local function isRider(sit) return sit.role == nil or sit.role == "rider" end
	local function riding(sit, set)
		return isRider(sit) and sit.net ~= "none" and sitIs(sit, "ride", set)
			and not (sit.ride == "invited" and (sit.autoAccept or "default") ~= "off")
	end
	local OPENS = { closed = true, trips_direct = true, drive_direct = true }
	local function phoneOk(sit) return sit.phone == nil or OPENS[sit.phone] == true end
	local QUIET = { closed = true, splash = true, home = true, trips = true, drive = true, trips_direct = true, drive_direct = true }
	local function phoneFor(sit)
		if sit.ride == "arrived" then return phoneOk(sit) end
		return sitIs(sit, "phone", QUIET)
	end
	local LIVE = { requested = true, invited = true, summoning = true, arrived = true }

	local function K(ctx) return ctx:mod("UI.Kit") end
	local function uiState(ctx) local k = K(ctx) return k and k.ui or {} end
	local function phoneShown(ctx) local w = uiState(ctx).win return w ~= nil and w:IsShown() == true end
	local function seen(ctx) return "on screen: " .. table.concat(ctx:texts(), " | ") end
	local function has(ctx, pat, plain)
		for _, t in ipairs(ctx:texts()) do if t:find(pat, 1, plain) then return true end end
		return false
	end
	local function hasExact(ctx, label)
		for _, t in ipairs(ctx:texts()) do if t == label then return true end end
		return false
	end
	local function inCombat(ctx) return ctx.me.player.combat and true or false end

	-- the player opens Wuber (minimap button) and, if it is not on the Ride tab, clicks that tab
	local function showRide(ctx)
		if not phoneShown(ctx) then
			ctx.W.UI.Toggle(true)
			ctx:note("open the phone")
			ctx:advance(2.5)
		end
		local s = uiState(ctx)
		if s.settingsOpen and ctx.W.UI.CloseSettings then ctx.W.UI.CloseSettings(true) ctx:advance(0.5) end
		if s.tab ~= "Ride" then
			for _, tab in ipairs(s.tabs or {}) do
				if tab.name == "Ride" and tab.button then
					ctx.me:clickOn(tab.button)
					ctx:note("click the Ride tab")
					ctx:advance(0.8)
				end
			end
		end
	end

	local function driver(ctx)
		local d = ctx.peers.driver
		if not d then ctx:cannot("no driver window") end
		return d
	end
	local function myGroup(ctx) return ctx.me.player.group and true or false end
	local function riderState(ctx) local r = ctx.W.ride return r and r.state or nil end

	-- the driver invites me (his own click on my name): hardware event on his window
	local function driverInvites(ctx)
		local d = driver(ctx)
		ctx.w.hardware = d
		ctx.w:invite(d, ctx.name)
		ctx.w.hardware = nil
		ctx:note("the driver invites me")
	end

	---------------------------------------------------------------------------
	promise{
		id = "ride.steps",
		area = "Ride",
		text = "Once a driver has taken your request, Wuber shows the five steps of your ride: Accepted, Invite, Portal, Arrived, Pay.",
		source = "Driver found screen (steps bar)",
		kind = "scenario",
		when = function(sit) return riding(sit, LIVE) and phoneFor(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			-- an old driver (net=oldpeer) only gets the request: the ride stays "requesting" until he accepts, and the steps start at his accept
			if riderState(ctx) == "requesting" then ctx:na("the ride is still requesting: no driver has taken the request yet") end
			showRide(ctx)
			local miss = {}
			for _, w in ipairs({ "Accepted", "Invite", "Portal", "Arrived", "Pay" }) do
				if not hasExact(ctx, w) then miss[#miss + 1] = w end
			end
			if #miss > 0 then
				ctx:fail(("You book a driver, he accepts (ride %s) and you open Wuber: the step %s is missing from your ride screen."):format(
					tostring(ctx.facts.rideState), table.concat(miss, ", ")), seen(ctx))
			end
		end,
	}

	promise{
		id = "ride.driver_named",
		area = "Ride",
		text = "While your ride is on, its screen names your driver and where you are going.",
		source = "Driver found screen",
		kind = "scenario",
		when = function(sit) return riding(sit, LIVE) and phoneFor(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			showRide(ctx)
			local who = tostring(ctx.facts.driverName or ""):match("^(%S+)")
			local dest = (ctx.W.ride and ctx.W.ride.destName) or "Ratchet"
			if not (who and has(ctx, who, true)) then
				ctx:fail("Your ride is on and the ride screen does not say who your driver is.", seen(ctx))
			end
			if not has(ctx, "Ratchet", true) then
				ctx:fail("Your ride is on and the ride screen does not say where you are going.", seen(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------
	-- Settings > Riding > "Auto-accept my driver's invite: When the driver you booked invites you, Wuber joins their group for you."
	promise{
		id = "ride.invite_auto",
		area = "Ride",
		text = "With Auto-accept on, when the driver you booked invites you, Wuber joins his group for you: no click and no invite box left open.",
		source = "Settings > Riding > Auto-accept my driver's invite (tooltip)",
		kind = "scenario",
		needs = { ride = "requested" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" and sit.net ~= "oldpeer" and (sit.autoAccept or "default") ~= "off" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			if myGroup(ctx) then ctx:na("already grouped") end
			if ctx.W.db and ctx.W.db.autoAccept == false then ctx:na("auto-accept is off") end
			driverInvites(ctx)
			ctx:advance(3)
			if not myGroup(ctx) then
				ctx:fail("Auto-accept is on, your driver invites you and you are still not in his group after 3 seconds (the ride says " .. tostring(riderState(ctx)) .. ").", seen(ctx))
			end
			if ctx.me.popups and ctx.me.popups.PARTY_INVITE then
				ctx:fail("Auto-accept is on and the game's invite box is still waiting on your screen after you joined.", seen(ctx))
			end
		end,
	}

	promise{
		id = "ride.auto_invite_message",
		area = "Ride",
		text = "With Auto-accept on, Wuber never tells you to accept the driver's invite: it joins you, so nothing says Accept the invite.",
		source = "Settings > Riding > Auto-accept (Wuber joins their group for you); Ride screen (Joining the group)",
		kind = "scenario",
		needs = { ride = "requested" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" and sit.net ~= "oldpeer" and (sit.autoAccept or "default") ~= "off" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			if myGroup(ctx) then ctx:na("already grouped") end
			if ctx.W.db and ctx.W.db.autoAccept == false then ctx:na("auto-accept is off") end
			driverInvites(ctx)
			ctx:advance(0.6)
			if not myGroup(ctx) then ctx:na("the invite was not taken (the other promise covers that)") end
			if not phoneShown(ctx) then ctx.W.UI.Toggle(true) ctx:note("open the phone") end
			ctx:advance(0.5)
			if has(ctx, "Accept the invite", true) or has(ctx, "Accept invite", true) then
				ctx:fail("Auto-accept is on, Wuber has already joined you to your driver's group, and a message still tells you to accept the invite.", seen(ctx))
			end
		end,
	}

	promise{
		id = "ride.invite_by_hand",
		area = "Ride",
		text = "With Auto-accept off, the driver's invite waits for you: you are not put in his group, the screen says Accept the invite, and clicking Accept invite joins you.",
		source = "Settings > Riding > Auto-accept; Driver found screen (Accept the invite)",
		kind = "scenario",
		needs = { ride = "invited", autoAccept = "off" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			ctx:advance(3)
			if myGroup(ctx) then
				ctx:fail("Auto-accept is off and Wuber put you in your driver's group before you clicked anything.", seen(ctx))
			end
			showRide(ctx)
			if not hasExact(ctx, "Accept invite") then
				ctx:fail("Your driver has invited you (auto-accept off) and the ride screen has no Accept invite button.", seen(ctx))
			end
			ctx.me:clickText("Accept invite")
			ctx:note("click Accept invite")
			ctx:advance(3)
			if not myGroup(ctx) then
				ctx:fail("You click Accept invite on the ride screen and you are still not in your driver's group.", seen(ctx))
			end
		end,
	}

	promise{
		id = "ride.stranger_invite_left",
		area = "Ride",
		text = "Auto-accept only joins the driver you booked: an invite from anyone else is left for you to answer.",
		source = "Settings > Riding > Auto-accept (Invites from anyone else are left alone)",
		kind = "scenario",
		needs = { ride = "requested" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" and sit.net ~= "oldpeer" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			if myGroup(ctx) then ctx:na("already grouped") end
			local name = "Sam Stranger"
			if not ctx.w:player(name) then
				ctx.w:addClient(name, { spot = "Orgrimmar", class = "MAGE", money = 100000 })
			end
			local c = ctx.w:clientOf(name)
			ctx.w.hardware = c
			ctx.w:invite(c, ctx.name)
			ctx.w.hardware = nil
			ctx:note("a stranger invites me")
			ctx:advance(3)
			if myGroup(ctx) then
				ctx:fail("A stranger invites you while your ride is waiting for its invite and Wuber joins you to his group.", seen(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------
	promise{
		id = "ride.summon_click",
		area = "Ride",
		text = "When the summon is up, the ride screen says so and its Accept summon button takes you to your destination.",
		source = "Driver found screen (The portal is up / Accept summon)",
		kind = "scenario",
		needs = { ride = "summoning" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			showRide(ctx)
			if not hasExact(ctx, "Accept summon") then
				ctx:fail("The portal is up and your ride screen has no Accept summon button.", seen(ctx))
			end
			ctx.me:clickText("Accept summon")
			ctx:note("click Accept summon")
			ctx:advance(4)
			local st = riderState(ctx)
			if st ~= "arrived" and st ~= "paying" and st ~= "done" then
				ctx:fail("You click Accept summon and your ride never reaches Arrived (it says " .. tostring(st) .. ").", seen(ctx))
			end
		end,
	}

	promise{
		id = "ride.summon_not_auto",
		area = "Ride",
		text = "Wuber never takes the summon for you: the summon stays on offer until you accept it.",
		source = "Driver found screen (Accept the summon; the click is the player's)",
		kind = "scenario",
		needs = { ride = "summoning" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" end,
		check = function(ctx)
			ctx:advance(10)
			local st = riderState(ctx)
			if st == "arrived" or st == "paying" or st == "done" then
				ctx:fail("The portal is up and you did not click Accept summon, yet Wuber says " .. tostring(st) .. ".", seen(ctx))
			end
		end,
	}

	promise{
		id = "ride.summon_toast_flash",
		area = "Ride",
		text = "When the summon comes up while Wuber is closed, a message tells you to accept it and the minimap button flashes until you do.",
		source = "Moments (arrival toasts and the minimap flash)",
		kind = "scenario",
		needs = { ride = "summoning", phone = "closed" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" and (sit.minimapHidden or "default") ~= "on" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			if phoneShown(ctx) then ctx:na("the phone is open") end
			if not has(ctx, "Accept the summon", true) then
				ctx:fail("The summon comes up while Wuber is closed and no message tells you to accept it.", seen(ctx))
			end
			local mm = uiState(ctx).minimap
			if not mm then ctx:cannot("no minimap button") end
			if not (mm.pulse and mm.pulse.running) then
				ctx:fail("The summon is up and Wuber is closed, yet the minimap button is not flashing.", seen(ctx))
			end
		end,
	}

	promise{
		id = "ride.arrival_opens_pay",
		area = "Ride",
		text = "When you arrive with a fare to pay, Wuber opens by itself on the screen that says what to type in the trade window.",
		source = "BRIEF (the author's test 18 Nov #1: Wuber did not open for the passenger on arrival); Pay.lua header",
		kind = "scenario",
		needs = { ride = "summoning", phone = "closed" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" and (sit.combat == nil or sit.combat == "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			if phoneShown(ctx) then ctx:na("the phone is open") end
			ctx.w.hardware = ctx.me
			ctx.W.AcceptSummon()
			ctx.w.hardware = nil
			ctx:note("accept the summon (the game's own box)")
			ctx:advance(6)
			if riderState(ctx) ~= "arrived" and riderState(ctx) ~= "paying" then ctx:na("did not arrive (" .. tostring(riderState(ctx)) .. ")") end
			if not phoneShown(ctx) then
				ctx:fail("You arrive with a fare to pay (Wuber was closed) and Wuber does not open to show what to type.", seen(ctx))
			end
			if not has(ctx, "Type in trade window", true) then
				ctx:fail("You arrive with a fare to pay and Wuber opens but not on the screen that says what to type.", seen(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------
	promise{
		id = "ride.cancel_before_summon",
		area = "Ride",
		text = "Cancel ride before the summon stops the ride and there is nothing to pay.",
		source = "Driver found screen (Cancel ride tooltip: Stop this ride before the summon. Nothing to pay.)",
		kind = "scenario",
		when = function(sit) return riding(sit, { requested = true, invited = true }) and phoneFor(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			showRide(ctx)
			local label = hasExact(ctx, "Cancel ride") and "Cancel ride" or (hasExact(ctx, "Cancel request") and "Cancel request")
			if not label then
				ctx:fail("You book a driver and the ride screen has no button to cancel the ride.", seen(ctx))
			end
			ctx.me:clickText(label)
			ctx:note("click " .. label)
			ctx:advance(3)
			if ctx.W.RideActive() then
				ctx:fail("You click Cancel ride and Wuber still says your ride is on (" .. tostring(riderState(ctx)) .. ").", seen(ctx))
			end
			if has(ctx, "Accept summon", true) or has(ctx, "Type in trade window", true) then
				ctx:fail("You cancelled your ride and its Accept summon or pay card is still on screen.", seen(ctx))
			end
		end,
	}

	local function paidWait(ctx, secs) ctx:advance(secs) end

	promise{
		id = "ride.leave_after_on",
		area = "Ride",
		text = "With Leave the group after the ride on, a few seconds after you have paid you are out of your driver's group.",
		source = "Settings > Riding > Leave the group after the ride (tooltip)",
		kind = "scenario",
		needs = { ride = "paid", group = "solo" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" and sit.net ~= "oldpeer" and phoneOk(sit) and (sit.autoLeave or "default") ~= "off" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			if not (ctx.W.db and ctx.W.db.autoLeave ~= false) then ctx:na("leave after the ride is off") end
			paidWait(ctx, 8)
			if myGroup(ctx) then
				ctx:fail("Leave the group after the ride is on, you paid your driver and eight seconds later you are still in his group.", seen(ctx))
			end
		end,
	}

	promise{
		id = "ride.leave_after_off",
		area = "Ride",
		text = "With Leave the group after the ride off, Wuber never takes you out of your driver's group after you pay.",
		source = "Settings > Riding > Leave the group after the ride",
		kind = "scenario",
		needs = { ride = "paid", group = "solo", autoLeave = "off" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" and sit.net ~= "oldpeer" and phoneOk(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			if not myGroup(ctx) then ctx:na("not in the group after paying") end
			paidWait(ctx, 8)
			if not myGroup(ctx) then
				ctx:fail("Leave the group after the ride is off, you paid and Wuber still took you out of your driver's group.", seen(ctx))
			end
		end,
	}

	promise{
		id = "ride.sorry_try_another",
		area = "Ride",
		text = "When your request gets no answer, you see that Wuber heard nothing from the driver and a Try another driver button that takes you back to the list.",
		source = "Done.lua Sorry screen (No answer from ...; Try another driver)",
		kind = "scenario",
		needs = { ride = "timedout" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" and sit.net ~= "oldpeer" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			showRide(ctx)
			if not has(ctx, "No answer from", true) then
				ctx:fail("Your request gets no answer and Wuber does not say so.", seen(ctx))
			end
			if not hasExact(ctx, "Try another driver") then
				ctx:fail("Your request gets no answer and the screen has no Try another driver button.", seen(ctx))
			end
			ctx.me:clickText("Try another driver")
			ctx:note("click Try another driver")
			ctx:advance(1.5)
			if has(ctx, "Try another one", true) or not has(ctx, "Where to?", true) then
				ctx:fail("You click Try another driver and you are not back at the list of drivers.", seen(ctx))
			end
		end,
	}
end
