-- The hunt's RIDE dial (owner RIDE): the state of a ride when the check starts.
-- For the rider role it is MY ride as a customer, with the net dial's first driver (ctx.peers.driver). For the
-- warlock, friend and crew roles it is a customer's ride on my queue (the shop's queue: mine, or my captain's that
-- my window mirrors): the customer is a second window, ctx.peers.rider, a Mage at Orgrimmar.
--   none       (default) no ride
--   requested  the rider clicked Request and the driver has it in his queue, no invite yet. A rider's driver invites by
--              hand (his "Invite riders who whisper me" off): W.ride "accepted", his queue "queued" (a round-one driver:
--              "requesting", in his W.incoming). A driver: the customer hasn't taken any invite: "queued" when my own
--              auto-invite is off, else "invited" (the engine invites at once)
--   invited    the driver's invite is out, the rider hasn't joined yet (rider: "invited"; a driver: "invited"). The
--              customer leaves the invite box open; MY invite stays open only with my auto-accept off (settings dial
--              autoAccept=off): otherwise this value is cannot-build for the rider role
--   summoning  the ritual is done, the summon box is up for the rider (rider: "portal"; a driver: "waiting", "has the
--              summon window"; the box lasts 120 s)
--   arrived    the rider took the summon and stands at Ratchet, nothing paid yet (rider: "arrived", then "paying" when the
--              driver's window opens the trade a moment later; a driver: "arrived")
--   paid       the rider has just paid the whole fare by trade (rider: "done", paid; a driver: "paid", not thanked)
--   ended      paid, thanked and out of the group a few seconds ago (rider: "done"; a driver: off the queue)
--   timedout   rider: the request got no answer (its R and the resend lost, no chat line): "timeout" after 40 s;
--              a driver: the rider never took the invite: the rider's ride "failed" after 60 s and left my queue
--   raincheck  a rain check is owed: the rider paid by trade before the summon, the driver closed, the rider
--              cancelled, asked, the driver gave one and the rider took it; the driver is open again (V ask/give/ok)
-- Every step is what a player does: the Request click (W.RequestRide and the button's chat whisper), the invite box,
-- the big summon button (WuberDriveButton), two portal clicks (bots stand in for the friends who click), the summon
-- box (W.AcceptSummon on a hardware click), the trade (the rider types the money; both accept), the thank click.
-- Facts: rideState (the addon's name: the rider's W.ride.state, or the customer's state on MY window, nil when off
-- it), riderState, rideId, price (copper), driverName, riderName, payee, paid (copper), raincheckId, raincheckCover,
-- autoAccept (the rider's own switch).
return function(Hunt)

local BORDER = { mapID = 1411, x = 0.04, y = 0.45, zone = "The Barrens", sub = "" } -- a trade with Ratchet, not arrived
local RIDER_NAMES = { "Dan Miller", "Una Hale", "Vic Moor", "Wes Kerr" }
local BOT_NAMES = { "Kim Ford", "Lou Grey", "Mo Pratt", "Nia Cross" }

local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end

local function freeName(ctx, pool)
	for _, n in ipairs(pool) do
		if key(n) ~= key(ctx.name) and not (ctx.w and ctx.w:player(n)) then return n end
	end
	error("ride: no free name left")
end

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

local function driverRole(ctx) return ctx.sit.role and ctx.sit.role ~= "rider" end

-- who is who for this ride
local function team(ctx)
	local w = ctx.w
	local t = {}
	if not driverRole(ctx) then
		local d = ctx.peers.driver
		if not d then ctx:cannot("ride: no driver on the network to ride with") end
		t.rider, t.riderName = ctx.me, ctx.name
		t.shop, t.caster, t.payee = d, d, d.player.name
		t.clickers = {}
		t.old = d.W.Drive == nil
	else
		local tm = ctx.facts.team
		if not tm then ctx:cannot("ride: the role dial set up no team") end
		t.rider = ctx.peers.rider
		t.riderName = t.rider.player.name
		t.shop = w:clientOf(tm.service)
		t.caster = w:clientOf(tm.caster)
		t.payee = tm.payee
		t.clickers = { unpack(tm.clickers) }
	end
	t.shopName = t.shop.player.name
	t.shopKey = key(t.shopName)
	t.riderKey = key(t.riderName)
	return t
end

local function rstate(t) return t.rider.W.ride and t.rider.W.ride.state end
local function rank(t) local s = rstate(t) return s and t.rider.W.RIDE_RANK[s] or 0 end
local function R(t, s) return t.rider.W.RIDE_RANK[s] end
-- the customer on a window's queue
local function cust(c, t) return c and c.W.Drive and c.W.Drive.customers[t.riderKey] end
local function shopState(t) local c = cust(t.shop, t) return c and c.state end

local function facts(ctx, t)
	local f = ctx.facts
	local r = t.rider.W.ride
	f.riderState = r and r.state or nil
	if driverRole(ctx) then
		local c = cust(ctx.me, t)
		f.rideState = c and c.state or nil
	else
		f.rideState = f.riderState
	end
	f.rideId = r and r.id or f.rideId
	f.price = r and r.price or f.price
	f.driverName, f.riderName, f.payee = t.shopName, t.riderName, t.payee
	f.paid = r and r.paid or nil
	f.autoAccept = t.rider.W.db and t.rider.W.db.autoAccept == true
	f.rideAt = ctx.w.time -- (the clock when the state was reached: later dials may run it on)
end

local function must(ctx, okv, why) if not okv then ctx:cannot("ride: " .. why) end end

-- the Request click: W.RequestRide and the button's chat whisper (skipped: the click came in combat)
local function request(ctx, t, noWhisper)
	must(ctx, waitFor(ctx, function() return t.rider.W.drivers[t.shopKey] ~= nil end, 45), t.riderName .. " never saw " .. t.shopName .. " in the list")
	local ride, why = t.rider.W.RequestRide(t.shopKey)
	must(ctx, ride, "the request was refused: " .. tostring(why))
	if not noWhisper then
		local text = t.rider.W.RequestWhisper(t.shopKey)
		if text then ctx.w:whisper(t.rider, t.shopName, text, "macro") end
	end
	t.ride = ride
	return ride
end

-- a round-one driver's Accept card (requests wait in W.incoming)
local function oldAccept(ctx, t)
	if not t.old then return end
	local inc
	must(ctx, waitFor(ctx, function() inc = t.shop.W.incoming and t.shop.W.incoming[1] return inc ~= nil end, 10, 0.1), "the old driver never got the request")
	t.shop.W.Driver.Accept(inc.id)
end

local function acceptInvite(ctx, t)
	local p = t.rider.player
	if p.group or not p.pendingInvite then return end
	ctx.w.hardware = t.rider
	t.rider.env.AcceptGroup()
	ctx.w.hardware = nil
	t.rider.popups.PARTY_INVITE = nil -- (the box closes on Accept)
end

-- a driver who invites by hand ("Invite riders who whisper me" off): the row's Invite click
-- (the row's menu "Invite" does nothing for a queued rider: then the game's own invite, a right-click on the name)
local function inviteByHand(ctx, t)
	if t.old or t.gameInvite then return end
	local c = cust(t.shop, t)
	if not (c and c.state == "queued" and t.shop.W.Drive.opts().autoInvite == false) then return end
	if not t.invitedByHand then
		t.invitedByHand = ctx.w.time
		local D = t.shop.W.Driver
		if D and type(D.RowAction) == "function" then D.RowAction(c, "invite") else t.shop.W.Drive.Invite(c) end
	elseif ctx.w.time - t.invitedByHand >= 1 then
		t.gameInvite = true
		if type(ctx.note) == "function" then ctx:note("ride: the row's Invite left " .. t.riderName .. " queued; the game's own invite instead") end
		ctx.w.hardware = t.shop
		ctx.w:invite(t.shop, t.riderName)
		ctx.w.hardware = nil
	end
end

local function toGroup(ctx, t)
	must(ctx, waitFor(ctx, function() inviteByHand(ctx, t) acceptInvite(ctx, t) return rank(t) >= R(t, "ingroup") end, 12, 0.25),
		"the rider never joined the group (" .. tostring(rstate(t)) .. ")")
	if not t.old then
		must(ctx, waitFor(ctx, function() local s = shopState(t) return s == "joined" or s == "waiting" end, 6), "the driver never saw the rider join (" .. tostring(shopState(t)) .. ")")
	end
end

-- the ritual: the big button on the caster's window, then two portal clicks (crew windows, bots for the rest)
local function summon(ctx, t)
	local w = ctx.w
	if t.old then
		w:summon(t.shop, t.riderName) -- (the round-one driver casts by hand; the fake's finished ritual)
	else
		local cp = t.caster.player
		local need = 2 - #t.clickers
		for i = 1, need do
			local n = freeName(ctx, BOT_NAMES)
			w:addBot(n, { spot = cp.mapID and { mapID = cp.mapID, x = cp.x, y = cp.y, zone = cp.zone, sub = cp.subZone } or "Ratchet", class = "PRIEST" })
			local g = cp.group
			local leader = g and w:player(g.leader) or cp
			w:join(leader, w:player(n))
			t.clickers[#t.clickers + 1] = n
			t.bots = t.bots or {}
			t.bots[#t.bots + 1] = n
		end
		ctx:advance(0.5)
		-- (with slow messages, net=late, the caster's window learns of the rider a few seconds later)
		local b = t.caster.env.WuberDriveButton
		waitFor(ctx, function() b = t.caster.env.WuberDriveButton return b and ctx.H.visible(b) end, 6, 0.25)
		-- "Show the big button" off hides only the FLOATING button; the docked one is on the Drive tab: a driver with
		-- that setting opens Wuber on the Drive tab and clicks it there
		local openedPhone = false
		if not (b and ctx.H.visible(b)) then
			local UIc = t.caster.W and t.caster.W.UI
			if UIc and type(UIc.ShowDrive) == "function" and not (type(UIc.IsShown) == "function" and UIc.IsShown()) then
				openedPhone = pcall(UIc.ShowDrive) or false
				if type(ctx.note) == "function" then ctx:note("ride: the big button is hidden (floating off); the Drive tab opened for the docked one") end
				waitFor(ctx, function() b = t.caster.env.WuberDriveButton return b and ctx.H.visible(b) end, 4, 0.25)
			end
		end
		must(ctx, b and ctx.H.visible(b), "the big button is not shown on " .. t.caster.player.name .. "'s window")
		local cast = false
		for _ = 1, 4 do
			t.caster:click(b)
			if waitFor(ctx, function() local r = w.rituals and w.rituals[cp.name] return r and r.stage == "channel" end, 3, 0.25) then cast = true break end
		end
		must(ctx, cast, "the big button never cast the ritual (" .. tostring(shopState(t)) .. ")")
		if openedPhone then pcall(t.caster.W.UI.Toggle, false) end -- (the window goes back as it was)
		-- the two friends step up and click a moment later (as people do; a ritual that stops within 2 s of the channel
		-- with no helper seen counts as dropped: Drive.Cast)
		ctx:advance(2.5)
		for _, n in ipairs(t.clickers) do
			local c = w:clientOf(n)
			must(ctx, w:clickPortal(c or n), n .. " could not click the portal")
		end
	end
	must(ctx, waitFor(ctx, function() return rstate(t) == "portal" end, 6, 0.1), "the summon box never came up (" .. tostring(rstate(t)) .. ")")
end

local function land(ctx, t)
	ctx.w.hardware = t.rider
	t.rider.W.AcceptSummon()
	ctx.w.hardware = nil
	must(ctx, waitFor(ctx, function() return rank(t) >= R(t, "arrived") end, 8, 0.25), "the rider never arrived (" .. tostring(rstate(t)) .. ")")
	if not t.old then
		waitFor(ctx, function() return shopState(t) == "arrived" end, 4)
	end
end

-- the rider pays the whole fare by trade (he types it; Wuber never puts gold in)
local function pay(ctx, t)
	local w = ctx.w
	local rp, pp = t.rider.player, w:player(t.payee)
	local tr = rp.trade
	if tr and not (tr.a == pp or tr.b == pp) then w:tradeCancel(rp) tr = nil end
	if not tr then must(ctx, w:openTrade(pp, rp), "no trade between " .. t.payee .. " and the rider") end
	local fare = t.rider.W.ride.price
	w:tradeMoney(rp, fare)
	w:tradeAccept(pp)
	w:tradeAccept(rp)
	must(ctx, waitFor(ctx, function() return t.rider.W.ride and (t.rider.W.ride.paid or 0) >= fare end, 4, 0.1), "the rider's Wuber never saw the fare go")
	return fare
end

-- the thank click on the caster's big button (whispers thanks, uninvites)
local function thank(ctx, t)
	if t.old then
		ctx.w:leave(t.riderName) -- (the round-one driver: the rider leaves the group himself)
		ctx:advance(2)
		return
	end
	-- (paid, or already off the queue: with slow messages the rider can leave the group first, "paid, left")
	must(ctx, waitFor(ctx, function() return shopState(t) == "paid" or cust(t.shop, t) == nil end, 6), "the driver never marked it paid (" .. tostring(shopState(t)) .. ")")
	local b = t.caster.env.WuberDriveButton
	for _ = 1, 3 do
		if b and ctx.H.visible(b) then t.caster:click(b) end
		if waitFor(ctx, function() return cust(t.shop, t) == nil end, 2) then break end
	end
	must(ctx, cust(t.shop, t) == nil, "the thank click never took the rider off the queue")
	-- the friends who clicked the portal leave the group too
	for _, n in ipairs(t.bots or {}) do ctx.w:leave(n) end
	ctx:advance(2)
end

local ORDER = { "requested", "invited", "summoning", "arrived", "paid", "ended" }
local AT = {} for i, s in ipairs(ORDER) do AT[s] = i end

-- the happy path up to a state
local function upTo(ctx, target)
	local t = team(ctx)
	local n = AT[target]
	local stopInvite = target == "invited"
	-- the states before the group must hold while later dials run the clock: the customer hasn't clicked Accept yet
	if (stopInvite or target == "requested") and driverRole(ctx) then t.rider.W.db.autoAccept = false end
	if target == "requested" and not driverRole(ctx) and not t.old then
		t.shop.W.Drive.opts().autoInvite = false -- the driver invites by hand ("Invite riders who whisper me" off)
	end
	request(ctx, t)
	if target == "requested" then
		if driverRole(ctx) then
			-- (the shop's queue: a crew window learns its captain's queue a moment later, by WUBERT)
			must(ctx, waitFor(ctx, function() return cust(t.shop, t) ~= nil end, 8, 0.05), "the request never reached the driver's queue")
			waitFor(ctx, function() return cust(ctx.me, t) ~= nil and rank(t) >= R(t, "accepted") end, 4, 0.1)
		elseif t.old then
			must(ctx, waitFor(ctx, function() return t.shop.W.incoming and t.shop.W.incoming[1] ~= nil end, 10, 0.1), "the old driver never got the request")
		else
			must(ctx, waitFor(ctx, function() return cust(t.shop, t) ~= nil and rank(t) >= R(t, "accepted") end, 10, 0.1),
				"the driver never put the request in his queue (" .. tostring(rstate(t)) .. ")")
		end
		return facts(ctx, t)
	end
	oldAccept(ctx, t)
	if stopInvite then
		must(ctx, waitFor(ctx, function() inviteByHand(ctx, t) return rank(t) >= R(t, "invited") end, 10, 0.05), "the invite never came (" .. tostring(rstate(t)) .. ")")
		if driverRole(ctx) then waitFor(ctx, function() local c = cust(ctx.me, t) return c and c.state == "invited" end, 4, 0.1) end
		return facts(ctx, t)
	end
	toGroup(ctx, t)
	summon(ctx, t)
	if n >= AT.arrived then land(ctx, t) end
	if n >= AT.paid then pay(ctx, t) end
	if n >= AT.ended then thank(ctx, t) end
	if driverRole(ctx) and n < AT.ended then
		-- (summoning: the queue moves on to "waiting", has the summon window, a moment after the ritual: the state that lasts)
		local want = ({ summoning = "waiting", arrived = "arrived", paid = "paid" })[target]
		waitFor(ctx, function() local c = cust(ctx.me, t) return c and c.state == want end, 4)
	end
	facts(ctx, t)
end

local function timedOut(ctx)
	local t = team(ctx)
	local w = ctx.w
	if not driverRole(ctx) then
		-- the R and its resend are lost on the way and no chat line went (a click in combat sends none)
		w.drop = w.drop or {}
		w.drop.R = (w.drop.R or 0) + 2
		request(ctx, t, true)
		must(ctx, waitFor(ctx, function() return rstate(t) == "timeout" end, 45, 1), "the request never timed out (" .. tostring(rstate(t)) .. ")")
	else
		t.rider.W.db.autoAccept = false -- the rider never takes the invite
		request(ctx, t)
		must(ctx, waitFor(ctx, function() inviteByHand(ctx, t) local c = cust(ctx.me, t) return c and c.state == "invited" end, 8, 0.25), "the rider was never invited")
		must(ctx, waitFor(ctx, function() return rstate(t) == "failed" and cust(t.shop, t) == nil end, 70, 1),
			"the ignored invite never ran out (" .. tostring(rstate(t)) .. " / " .. tostring(shopState(t)) .. ")")
		waitFor(ctx, function() return cust(ctx.me, t) == nil end, 6, 0.5) -- (a crew window hears it by WUBERT)
	end
	facts(ctx, t)
end

local function raincheck(ctx)
	local t = team(ctx)
	must(ctx, not t.old, "the round-one Wuber has no rainchecks")
	local w = ctx.w
	local home = t.rider.player
	local back = home.mapID and { mapID = home.mapID, x = home.x, y = home.y, zone = home.zone, sub = home.subZone }
	if not driverRole(ctx) then w:move(t.riderName, BORDER) end -- (I walk to the Barrens border to pay; the customer stands there)
	local ride = request(ctx, t)
	toGroup(ctx, t)
	-- the whole fare by trade before the summon
	local rp, pp = t.rider.player, w:player(t.payee)
	if rp.trade then w:tradeCancel(rp) end
	must(ctx, w:openTrade(rp, pp), "no trade between the rider and " .. t.payee)
	local fare = t.rider.W.ride.price
	w:tradeMoney(rp, fare)
	w:tradeAccept(pp)
	w:tradeAccept(rp)
	must(ctx, waitFor(ctx, function() return t.rider.W.ride and (t.rider.W.ride.paid or 0) >= fare end, 4, 0.1), "the rider's Wuber never saw the fare go")
	-- the driver closes before casting; the rider gives up
	local DR = t.shop.W.Drive
	DR.SetOpen(false)
	ctx:advance(2)
	if t.rider.W.RideActive() then t.rider.W.CancelRide() end
	must(ctx, waitFor(ctx, function() return not t.rider.W.RideActive() end, 5), "the ride never ended")
	must(ctx, waitFor(ctx, function() return DR.RaincheckEligible(ride.id) == true end, 5), "the driver's book says no raincheck: "
		.. tostring((select(2, DR.RaincheckEligible(ride.id)))))
	local okA, whyA = t.rider.W.Raincheck.CanAsk(ride.id)
	must(ctx, okA, "the rider may not ask: " .. tostring(whyA))
	must(ctx, t.rider.W.Raincheck.Ask(ride.id), "the ask was not sent")
	ctx:advance(1)
	local okG, id = DR.GiveRaincheck(ride.id) -- the driver's Give click
	must(ctx, okG, "the driver could not give one: " .. tostring(id))
	must(ctx, waitFor(ctx, function() local m = t.rider.W.Raincheck.Mine()[1] return m and m.id == id end, 5), "the offer never reached the rider")
	must(ctx, t.rider.W.Raincheck.Accept(id), "the rider could not take it")
	must(ctx, waitFor(ctx, function() local b = t.shop.W.db.drive.iou return b and b[id] and b[id].state == "active" end, 5), "the book never made it active")
	-- the rider leaves the group and clicks Done; walks home; the driver opens again
	w:leave(t.riderName)
	t.rider.W.ClearRide()
	if back and not driverRole(ctx) then w:move(t.riderName, back) end
	DR.SetOpen(true)
	waitFor(ctx, function() local d = t.rider.W.drivers[t.shopKey] return d and d.state == "open" end, 10)
	facts(ctx, t)
	-- the place dial (phase 60) left a driver where the trade was made; now he walks to his place (world.lua)
	if ctx.facts.latePlace then ctx.facts.latePlace() end
	local m = t.rider.W.Raincheck.Mine()[1]
	ctx.facts.raincheckId, ctx.facts.raincheckCover, ctx.facts.price = id, m and m.cover, fare
end

-- the customer for a driver (world hook): a Mage with gold at Orgrimmar (or at the border, to pay first)
local function addCustomer(ctx, spot)
	if not driverRole(ctx) then return end
	local n = freeName(ctx, RIDER_NAMES)
	ctx.w:addClient(n, { spot = spot or "Orgrimmar", class = "MAGE", money = 1000000 })
	ctx.facts.riderName = n
end
local function bindCustomer(ctx)
	if driverRole(ctx) then ctx.peers.rider = ctx.w:clientOf(ctx.facts.riderName) end
end

-- the states a rider cannot be in without a driver to ride with (role x net x ride: a triple, so no excludes)
local function needDriver(ctx)
	if not driverRole(ctx) and ctx.sit.net == "none" then ctx:cannot("ride: a rider's ride needs a driver and the net dial has none") end
end

-- my own invite stays open only when I accept it by hand (Settings > Riding: auto-accept off); with it on (the
-- addon's default) Wuber takes it at once and "invited" is gone before the check looks
local function needOwnAccept(ctx)
	needDriver(ctx)
	if not driverRole(ctx) and (ctx.sit.autoAccept or "default") ~= "off" then
		ctx:cannot("ride: with auto-accept on (the default) my invite is taken at once; invited needs autoAccept=off")
	end
end

local function value(id, about, build, spot, pre)
	return { id = id, about = about,
		pre = pre or needDriver,
		world = function(ctx) addCustomer(ctx, spot) end,
		apply = function(ctx) bindCustomer(ctx) build(ctx) end }
end

Hunt.dial{
	name = "ride",
	about = "the ride's state: mine as a rider, or a customer's on my queue as a driver",
	phase = 70,
	default = "none",
	-- the core's hook (called with the FULL situation; false = this situation cannot exist, never generated)
	valid = function(sit)
		local role = sit.role or "rider"
		local ride = sit.ride or "none"
		if role == "rider" and ride ~= "none" and sit.net == "none" then
			return false, "a rider's ride needs a driver and net=none has none"
		end
		if role == "rider" and ride == "invited" and (sit.autoAccept or "default") ~= "off" then
			return false, "with auto-accept on my invite is taken at once, so invited needs autoAccept=off"
		end
		-- fold=folded_click needs a page that is unfolded with a fold button: a rider's Drive tab landing ("Run a
		-- summoning service") and the Drive screens are not (a pair with the role, so excludes cannot say it)
		if role == "rider" and sit.fold == "folded_click" then
			local ph = sit.phone
			if ph == "drive" or ph == "drive_earnings" or ph == "drive_messages" or ph == "drive_customers" then
				return false, "a rider's Drive pages have no fold button"
			end
		end
		if sit.fold == "folded_click" then
			local ph = sit.phone
			local ridePage = ph == "home" or ph == "world_view" or ph == "here_view"
			if sit.saved == "acct3_rider" and (ridePage or ph == "confirm") then
				return false, "that saved data has the ride and confirm pages folded already: nothing to fold"
			end
			if sit.coach == "not_done" and ridePage then
				return false, "the first-open coach marks cover Home's fold button"
			end
		end
		-- a friend's rider cannot join the group of a friend on the other continent (world.lua)
		if role == "friend" and sit.place == "other_continent" and ride ~= "none" and ride ~= "requested" then
			return false, "the friend's rider cannot join a group on the other continent"
		end
		return true
	end,
	values = {
		{ id = "none", about = "no ride" },
		value("requested", "the request is in the driver's queue, no invite yet (a rider's driver invites by hand)", function(ctx) upTo(ctx, "requested") end),
		value("invited", "the invite is out, the rider hasn't joined (a rider: only with my auto-accept off)", function(ctx)
			if not driverRole(ctx) and ctx.W.db and ctx.W.db.autoAccept ~= false then
				ctx:cannot("ride: my auto-accept is on, so my invite would be taken at once")
			end
			upTo(ctx, "invited")
		end, nil, needOwnAccept),
		value("summoning", "the ritual is done and the summon box is up for the rider", function(ctx) upTo(ctx, "summoning") end),
		value("arrived", "the rider took the summon and stands at Ratchet, unpaid", function(ctx) upTo(ctx, "arrived") end),
		value("paid", "the rider has just paid the fare by trade", function(ctx) upTo(ctx, "paid") end),
		value("ended", "paid, thanked and out of the group a few seconds ago", function(ctx) upTo(ctx, "ended") end),
		value("timedout", "the request (rider) or the invite (driver) got no answer and ran out", timedOut),
		value("raincheck", "a rain check is owed to the rider; the driver is open again", raincheck, BORDER),
	},
}

end
