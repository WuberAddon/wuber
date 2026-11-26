-- Wuber Lab (developer only, never ship): the checks of a test run and the login checks.
-- Each one judges itself from what really happens (Wuber's state and events, the game's events,
-- the big button's words, frame strata and visibility). README "How to add a check" explains the
-- fields; L.J holds the helpers the judges share.
--
-- Scenes (a run takes a scene whole, in order):
--   ride   a full paid ride, Wuber Rocks to Anita's crew (selling)
--   raid   raid summons with Wuber's window open: 123 in raid chat or Request, the big button
--          summons, two summoners never take the same raider (the test still outstanding)
--   end    the photo tour (one click), for the reviewer to check the visuals
-- Login checks run by themselves a few seconds after login on every window.

local _, L = ...

local show, str, num, call, plain = L.show, L.str, L.num, L.call, L.plain

---------------------------------------------------------------------------
-- Judge helpers
---------------------------------------------------------------------------

local J = {}
L.J = J

function J.W() return L.W() end
function J.DR() local W = L.W() return W and W.Drive or nil end
function J.key(role) return L.Key(L.RunName(role)) end

-- the rider's queue entry on this (driver/crew) window
function J.cust(role)
	local DR = J.DR()
	return DR and type(DR.customers) == "table" and DR.customers[J.key(role)] or nil
end

function J.rank(state)
	local DR = J.DR()
	local R = DR and DR.RANK
	return type(R) == "table" and R[state or ""] or 0
end

function J.ride()
	local W = L.W()
	return W and type(W.ride) == "table" and W.ride or nil
end

function J.rideRank(state)
	local W = L.W()
	local R = W and W.RIDE_RANK
	return type(R) == "table" and R[state or ""] or 0
end

function J.plan()
	local b = rawget(_G, "WuberDriveButton")
	return type(b) == "table" and type(b.plan) == "table" and b.plan or nil
end

function J.title()
	local p = J.plan()
	return p and str(p.title) or nil
end

function J.call(t, name, ...)
	if type(t) ~= "table" or type(t[name]) ~= "function" then return nil end
	return call(t[name], ...)
end

function J.selling()
	local DR = J.DR()
	return J.call(DR, "Mode") == "sell" and J.call(DR, "Selling") == true
end

function J.inGroupWith(role)
	local k = J.key(role)
	for _, u in ipairs({ "party1", "party2", "party3", "party4" }) do
		local a, b = call(UnitName, u)
		a, b = str(a), str(b)
		if a and L.Key(b and (a .. " " .. b) or a) == k then return true end
	end
	for i = 1, 40 do
		local a, b = call(UnitName, "raid" .. i)
		a, b = str(a), str(b)
		if a and L.Key(b and (a .. " " .. b) or a) == k then return true end
	end
	return false
end

function J.inGroup() return type(IsInGroup) == "function" and plain(call(IsInGroup)) == true end
function J.inRaid() return type(IsInRaid) == "function" and plain(call(IsInRaid)) == true end

function J.appOpen()
	local W = L.W()
	return W ~= nil and type(W.UI) == "table" and J.call(W.UI, "IsShown") == true
end

function J.onDrive()
	local W = L.W()
	return J.appOpen() and type(W.UI.state) == "table" and W.UI.state.tab == "Drive"
end

local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
function J.strata(f) return type(f) == "table" and str(call(f.GetFrameStrata, f)) or "?" end

-- The big button: shown, visible, and (docked in the console) a strata above Wuber's window.
-- ok, why
function J.button()
	local b = rawget(_G, "WuberDriveButton")
	if type(b) ~= "table" then return false, "there is no big button (WuberDriveButton)" end
	if call(b.IsVisible, b) ~= true then return false, "the big button is hidden" end
	local W = L.W()
	local B = W and W.Drive and W.Drive.Button
	local win = rawget(_G, "WuberFrame")
	local docked = type(B) == "table" and J.call(B, "Docked") == true
	if docked and type(win) == "table" and call(win.IsVisible, win) == true then
		local bs, ws = J.strata(b), J.strata(win)
		if (STRATA[bs] or 0) <= (STRATA[ws] or 0) then
			return false, "docked but under Wuber's window (" .. bs .. " vs " .. ws .. ")"
		end
		return true, "docked on top (" .. bs .. " over " .. ws .. ")"
	end
	return true, (docked and "docked" or "floating") .. ", " .. J.strata(b)
end

-- A visible text in Wuber's window that contains `part` (plain, any case).
function J.textShown(part)
	local win = rawget(_G, "WuberFrame")
	if type(win) ~= "table" or call(win.IsVisible, win) ~= true then return nil end
	part = part:lower()
	local found, visited
	visited = 0
	local function walk(f, depth)
		if found or depth > 14 or visited > 4000 then return end
		visited = visited + 1
		if call(f.IsVisible, f) ~= true then return end
		local ok, regions = pcall(function() return { f:GetRegions() } end)
		for _, r in ipairs(ok and regions or {}) do
			if type(r) == "table" and type(r.GetText) == "function" and call(r.IsVisible, r) == true then
				local t = str(call(r.GetText, r))
				if t and t:lower():find(part, 1, true) then found = t return end
			end
		end
		local okc, kids = pcall(function() return { f:GetChildren() } end)
		for _, k in ipairs(okc and kids or {}) do walk(k, depth + 1) end
	end
	walk(win, 0)
	return found
end

function J.money(c)
	local W = L.W()
	return W and type(W.Money) == "function" and str(call(W.Money, c)) or tostring(c)
end

-- A helper's portal click. In test mode the pretend ritual needs no clicks (it ends by itself in
-- 3 s, far too soon for the tester to swap windows), so the step is skipped there.
local function portalClick() return "right-click the summoning portal" end
local function realOnly(ctx) if ctx.sim then return "skip", "test mode: the pretend ritual needs no portal clicks" end return true end

-- A helper clicked the portal. The tester's test (18 Nov): the clicks on Farra and Hayley were never
-- seen by a judge that only heard UNIT_SPELLCAST_CHANNEL_START. Now any of these counts, on the
-- helper's window: a spell of its own starting, succeeding or channelling (any spell: the portal
-- is a game object; not this window's own ritual), the game saying it channels or casts, or
-- Wuber's own click detection (HELP: the rider's queue entry lists this window as a helper),
-- here or on Anita's window (who tells the judge as a fact).
local PORTAL_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START" }
local PORTAL_WORD = { UNIT_SPELLCAST_START = "a cast started", UNIT_SPELLCAST_SUCCEEDED = "a cast went",
	UNIT_SPELLCAST_CHANNEL_START = "a channel started" }

-- this window's own ritual (Wuber's DR.cast): its spell events are not a portal click
local function ownRitual()
	local DR = J.DR()
	return DR ~= nil and type(DR.cast) == "table"
end

-- the queue entry (any rider: a raid's row has none) whose helpers include `key`, as Wuber saw it
function J.helpedBy(key)
	local DR = J.DR()
	local list = DR and type(DR.customers) == "table" and DR.customers or {}
	local rider = list[J.key("rider")]
	if type(rider) == "table" and type(rider.helps) == "table" and rider.helps[key] then return rider end
	for _, c in pairs(list) do
		if type(c) == "table" and type(c.helps) == "table" and c.helps[key] then return c end
	end
	return nil
end

-- (a fact: unit is the window that told, guid the text)
local function helperTest(ctx, event, unit, guid, spellID)
	if event == "fact" then return "pass", tostring(guid) end
	if plain(unit) ~= "player" then return end
	L.Log("run", ("portal step %s: %s, spell %s%s"):format(ctx.check.id, tostring(event), show(spellID), ownRitual() and " (own ritual)" or ""))
	if ownRitual() then return end
	return "pass", "clicked the portal (" .. (PORTAL_WORD[event] or tostring(event)) .. ")"
end

local function helperPoll(ctx)
	if ownRitual() then return end
	for _, fn in ipairs({ "UnitChannelInfo", "UnitCastingInfo" }) do
		local f = rawget(_G, fn)
		local name = type(f) == "function" and str(call(f, "player")) or nil
		if name then return "pass", "clicked the portal (the game says it " .. (fn == "UnitChannelInfo" and "channels " or "casts ") .. name .. ")" end
	end
	local c = J.helpedBy(L.myKey)
	if c then return "pass", "clicked the portal (Wuber counted the click for " .. tostring(c.name) .. ")" end
	ctx.data.waitWhy = "no spell, channel or Wuber click seen on this window"
end

-- Anita's window (the caster's): Wuber heard this helper's click (HELP from their window, or
-- its own count of a helper without Wuber); told to the judge once
local function helperObserve(o)
	if o.sim then return true end -- (test mode: the step is skipped)
	local c = J.helpedBy(J.key(o.check.who))
	if c then
		o.Tell("Anita's Wuber counted " .. L.RunShort(o.check.who) .. "'s click for " .. tostring(c.name))
		return true
	end
end

local function portalCheck(id, title, scene, who)
	L.AddCheck({ id = id, title = title, scene = scene, who = who, secs = 20, timeout = 45,
		click = portalClick, when = realOnly, watch = PORTAL_EVENTS, test = helperTest, poll = helperPoll,
		also = { "driver" }, observe = function() end, observePoll = helperObserve })
end

---------------------------------------------------------------------------
-- Scene: a full ride (selling)
---------------------------------------------------------------------------

L.AddScene({ id = "ride", title = "A full ride: Wuber Rocks to Anita's crew", prio = 2,
	intro = function(ctx)
		return ctx.sim and "Wuber Rocks in a zone next to Anita's (test mode: it walks up to pay)" or "Wuber Rocks in another zone than Anita (Orgrimmar)"
	end })

L.AddCheck({ id = "ride_open", title = "Anita open", scene = "ride", who = "driver", secs = 20, timeout = 90,
	click = "open Wuber (/wuber), Drive tab, choose Sell summons and press Open",
	begin = function(ctx) if J.selling() then return "pass", "already open, selling" end end,
	poll = function(ctx)
		local DR = ctx.DR
		if J.call(DR, "Mode") == "raid" then ctx.data.waitWhy = "still on Raid summons: choose Sell summons" end
		if J.selling() then return "pass", "open, selling at " .. J.money(L.W().Char().price) end
	end })

L.AddCheck({ id = "ride_beacon", title = "Beacon open", scene = "ride", who = "driver", secs = 5, timeout = 20,
	say = "Wuber tells riders Anita is open",
	poll = function(ctx)
		local W = ctx.W
		local b = J.call(ctx.DR, "NetBeacon")
		if type(b) ~= "table" then ctx.data.waitWhy = "no beacon (not open, or another crew window beacons)" return end
		if b.state == "paused" then ctx.data.waitWhy = "the beacon says paused: nobody here can invite" return end
		if W.engine == nil then ctx.data.waitWhy = "Wuber's driver isn't on the network" return end
		return "pass", ("beacon %s: %s to %s"):format(tostring(b.state), J.money(b.price), tostring(b.dest))
	end })

L.AddCheck({ id = "ride_seen", title = "Anita on Home", scene = "ride", who = "rider", secs = 15, timeout = 60,
	click = "type /wuber: Anita's card is on Home",
	poll = function(ctx)
		local W = ctx.W
		local d = W and type(W.drivers) == "table" and W.drivers[J.key("driver")]
		if not d then ctx.data.waitWhy = "Anita isn't on Wuber Rocks' list" return end
		if J.appOpen() then return "pass", "Anita listed (" .. tostring(d.state) .. ", " .. J.money(d.price) .. ")" end
	end })

L.AddCheck({ id = "ride_confirm", title = "Confirm screen", scene = "ride", who = "rider", secs = 10, timeout = 60,
	click = "tap Anita's card", watch = { "confirm_shown" },
	poll = function(ctx)
		local st = ctx.UI and ctx.UI.state
		if type(st) == "table" and st.manual == "confirm" and st.confirmKey == J.key("driver") then return "pass", "the confirm screen for Anita" end
	end })

L.AddCheck({ id = "ride_request", title = "Request", scene = "ride", who = "rider", secs = 12, timeout = 60,
	click = "press Request summon", watch = { "CHAT_MSG_WHISPER_INFORM" },
	test = function(ctx, _, text)
		if type(text) == "string" and text:lower():find("wtb summon", 1, true) then ctx.data.whisper = text end
	end,
	poll = function(ctx)
		local r = J.ride()
		if not (r and r.driverKey == J.key("driver")) then return end
		ctx.data.rideAt = ctx.data.rideAt or ctx.t
		if ctx.data.whisper then return "pass", "booked; whispered '" .. ctx.data.whisper:sub(1, 50) .. "'" end
		if ctx.t - ctx.data.rideAt > 5 then return "fail", "booked, but no 'WTB summon' whisper went out" end
	end })

L.AddCheck({ id = "ride_taken", title = "Request reaches Anita", scene = "ride", who = "driver", secs = 5, timeout = 20,
	say = "Anita's Wuber takes the request",
	poll = function()
		local c = J.cust("rider")
		if c and c.wuberRide then return "pass", "Wuber Rocks is in Anita's queue (" .. tostring(c.state) .. ")" end
	end })

L.AddCheck({ id = "ride_invited", title = "Invite taken", scene = "ride", who = "rider", secs = 10, timeout = 30,
	say = "the invite arrives and is taken with no click",
	poll = function()
		local r = J.ride()
		if r and r.autoAccepted then return "pass", "joined Anita's group with no click" end
		if r and J.inGroupWith("driver") and J.rideRank(r.state) >= J.rideRank("ingroup") then return "pass", "in Anita's group" end
	end })

local function summonButton(ctx)
	local t = J.title() or ""
	if t:find("^Summon Wuber") then
		local ok, why = J.button()
		if not ok then return "fail", why end
		return "pass", "it says '" .. t .. "' (" .. why .. ")"
	end
	if t:find("Soul Shard", 1, true) then
		local p = J.plan()
		return "fail", t .. ": " .. tostring(p and p.sub)
	end
	ctx.data.waitWhy = "the big button says '" .. t .. "'"
end

L.AddCheck({ id = "ride_button", title = "Big button: Summon", scene = "ride", who = "driver", secs = 3, timeout = 20,
	say = "the big button offers the summon", poll = summonButton })

local function castOn(role)
	local DR = J.DR()
	local c = DR and type(DR.cast) == "table" and DR.cast
	return c and L.Key(c.name) == J.key(role)
end

L.AddCheck({ id = "ride_cast", title = "The summon starts", scene = "ride", who = "driver", secs = 15, timeout = 45,
	click = "click the big button (it says {button})", buttonText = "Summon Wuber",
	poll = function(ctx)
		if castOn("rider") then return "pass", "the ritual started on Wuber Rocks" .. (ctx.sim and " (pretend)" or "") end
	end })

portalCheck("ride_portal1", "Farra clicks", "ride", "crew1")
portalCheck("ride_portal2", "Hayley clicks", "ride", "crew2")

L.AddCheck({ id = "ride_arrive", title = "Summon accepted", scene = "ride", who = "rider", secs = 20, timeout = 90,
	click = function(ctx) return ctx.sim and "click Accept on the TEST MODE summon card" or "accept the summon (Wuber's Accept summon, or the game's box)" end,
	watch = { "CONFIRM_SUMMON" },
	test = function(ctx) ctx.data.box = true end,
	poll = function(ctx)
		local r = J.ride()
		if r and J.rideRank(r.state) >= J.rideRank("arrived") then
			return "pass", "arrived (" .. tostring(r.state) .. ")" .. (ctx.data.box and ", after the game's summon box" or "")
		end
	end })

L.AddCheck({ id = "ride_landed", title = "Anita sees the arrival", scene = "ride", who = "driver", secs = 5, timeout = 25,
	say = "Anita's Wuber sees Wuber Rocks arrive",
	poll = function()
		local c = J.cust("rider")
		if c and J.rank(c.state) >= J.rank("arrived") then return "pass", "Wuber Rocks counts as here (" .. c.state .. ")" end
	end })

L.AddCheck({ id = "ride_trade", title = "Rider pays", scene = "ride", who = "rider", secs = 40, timeout = 150,
	click = function(ctx) return (ctx.sim and "stand next to Anita, " or "") .. "open a trade with Anita, type the fare Wuber shows, click Trade" end,
	watch = { "TRADE_ACCEPT_UPDATE" },
	test = function(ctx, _, me)
		if num(plain(me)) ~= 1 then return end
		local put = num(call(GetPlayerTradeMoney)) or 0
		local r = J.ride()
		local price = r and num(r.price) or 0
		if put < price then return "fail", "put in " .. J.money(put) .. ", the fare is " .. J.money(price) end
		return "pass", "put in " .. J.money(put) .. " and pressed Trade"
	end })

-- Only the full fare passes (the tester's test, 18 Nov: 55c passed for a 50s fare). Less is "part
-- paid": the step waits for the rest, and fails with that reason when Wuber takes it as paid
-- anyway or the time runs out (data.waitWhy is the timeout's reason).
local function partPaid(ctx)
	local d = ctx.data
	return "fail", "part paid: " .. J.money(d.paid or 0) .. " of the " .. J.money(d.fare or 0) .. " fare"
end

L.AddCheck({ id = "ride_paid", title = "Anita takes the fare", scene = "ride", who = "driver", secs = 15, timeout = 60,
	click = "click the big button (it says {button})", buttonText = "Accept ... from Wuber", watch = { "wuber:DRIVE_PAID" },
	-- DRIVE_PAID: name, copper, tip, cashierKey, mine, how, price (the fare)
	test = function(ctx, _, name, copper, _, _, _, _, price)
		if L.Key(str(name) or "") ~= J.key("rider") then return end
		local d = ctx.data
		d.paid = (d.paid or 0) + (num(copper) or 0)
		d.fare = num(price) or d.fare
		if d.fare and d.fare > 0 and d.paid >= d.fare then
			return "pass", "paid " .. J.money(d.paid) .. " by " .. tostring(name)
		end
		d.waitWhy = d.fare and ("part paid: " .. J.money(d.paid) .. " of the " .. J.money(d.fare) .. " fare") or nil
	end,
	poll = function(ctx)
		local c = J.cust("rider")
		if not c then return end
		local d = ctx.data
		local paid, fare = num(c.paid) or 0, num(c.price) or 0
		if paid > (d.paid or 0) then d.paid = paid end
		if fare > 0 then d.fare = fare end
		if fare > 0 and paid >= fare then return "pass", "paid " .. J.money(paid) end
		if paid > 0 and fare > 0 then d.waitWhy = "part paid: " .. J.money(paid) .. " of the " .. J.money(fare) .. " fare" end
		if J.rank(c.state) >= J.rank("paid") then
			if fare <= 0 then return "pass", "paid " .. J.money(paid) .. " (no fare known)" end
			local v, why = partPaid(ctx)
			return v, why .. " (Wuber took it as paid)"
		end
	end })

L.AddCheck({ id = "ride_done", title = "Rider's ride paid", scene = "ride", who = "rider", secs = 5, timeout = 25,
	say = "Wuber Rocks' Wuber marks the ride paid",
	poll = function()
		local r = J.ride()
		if r and r.state == "done" and (num(r.paid) or r.payClicked) then return "pass", "done, paid " .. J.money(num(r.paid) or 0) end
		if r and r.state == "done" and r.unpaid then return "fail", "the ride ended as not paid" end
	end })

L.AddCheck({ id = "ride_left", title = "Left the group", scene = "ride", who = "rider", secs = 8, timeout = 30,
	say = "Wuber Rocks leaves the group by itself",
	poll = function() if not J.inGroup() then return "pass", "left the group with no click" end end })

L.AddCheck({ id = "ride_rate", title = "Rating", scene = "ride", who = "rider", secs = 15, timeout = 90,
	click = "tap 5 stars on the Done screen",
	poll = function()
		local r = J.ride()
		if r and r.rated then return "pass", "rated " .. tostring(r.stars or "?") .. " stars" end
	end })

L.AddCheck({ id = "ride_thanks", title = "Thank-you whisper", scene = "ride", who = "driver", secs = 15, timeout = 60,
	click = "click the big button (it says {button})", buttonText = "Thank Wuber", watch = { "CHAT_MSG_WHISPER_INFORM" },
	test = function(_, _, _, target)
		if L.Key(str(target) or "") == J.key("rider") then return "pass", "thank-you whisper sent to Wuber Rocks" end
	end,
	poll = function(ctx)
		local c = J.cust("rider")
		if c and c.thanked then return "pass", "thanked" end
		if not c and ctx.t > 3 then return "pass", "Wuber Rocks is off the list (thanked and done)" end
	end })

L.AddCheck({ id = "ride_earnings", title = "Earnings (look)", scene = "ride", who = "driver", kind = "look", secs = 25, timeout = 120,
	click = "Drive tab: open Earnings, then click Snap (below)",
	button = { label = "Snap", run = function()
		if L.Snap and L.Snap() then return "look", "screenshot " .. tostring(L.photoShots) .. ": Earnings with today's ride" end
		return "fail", "the screenshot didn't work"
	end } })

---------------------------------------------------------------------------
-- Scene: raid summons with Wuber's window open (outstanding)
---------------------------------------------------------------------------

L.AddScene({ id = "raid", title = "Raid summons with Wuber's window open", prio = 1, after = "ride",
	intro = "raid summons with Wuber's window open: Wuber Rocks asks, Anita's big button summons, Farra and Hayley keep off" })

L.AddCheck({ id = "raid_invite", title = "Invite the rider", scene = "raid", who = "driver", judge = "rider", secs = 20, timeout = 60,
	click = "type /invite Wuber Rocks", watch = { "PARTY_INVITE_REQUEST" },
	begin = function() if J.inGroupWith("driver") then return "pass", "already in Anita's group" end end,
	test = function() return "pass", "the invite reached Wuber Rocks" end,
	poll = function() if J.inGroupWith("driver") then return "pass", "in Anita's group" end end })

L.AddCheck({ id = "raid_join", title = "Rider joins", scene = "raid", who = "rider", secs = 15, timeout = 60,
	click = "click Accept on the group invite", watch = { "GROUP_ROSTER_UPDATE" },
	test = function() if J.inGroupWith("driver") then return "pass", "in Anita's group" end end,
	poll = function() if J.inGroupWith("driver") then return "pass", "in Anita's group" end end })

L.AddCheck({ id = "raid_convert", title = "Make it a raid", scene = "raid", who = "driver", secs = 20, timeout = 60,
	click = "right-click your portrait, Convert to Raid",
	poll = function() if J.inRaid() then return "pass", "a raid" end end })

L.AddCheck({ id = "raid_start", title = "Raid summons on", scene = "raid", who = "driver", secs = 30, timeout = 120,
	click = "Drive tab: Raid summons, tick Anita, Farra and Hayley as summoners, press Start",
	poll = function(ctx)
		local DR = ctx.DR
		if J.call(DR, "Mode") == "raid" and J.call(DR, "RaidOn") == true then
			local s = J.call(DR, "Summoners")
			return "pass", "raid summons on, " .. (type(s) == "table" and #s or "?") .. " summoners"
		end
	end })

L.AddCheck({ id = "raid_window", title = "Window open, button on top", scene = "raid", who = "driver", secs = 10, timeout = 60,
	click = "keep Wuber's window open on the Drive tab (open it if it closed)",
	poll = function(ctx)
		if not J.onDrive() then ctx.data.waitWhy = "Wuber's window isn't open on the Drive tab" return end
		local ok, why = J.button()
		if ok then return "pass", "window open, big button " .. why end
		ctx.data.waitWhy = why
	end })

L.AddCheck({ id = "raid_away", title = "Rider away from the spot", scene = "raid", who = "rider", judge = "driver", secs = 30, timeout = 180,
	click = "take Wuber Rocks out of Anita's zone (hearth or walk out), staying in the raid",
	begin = function(ctx) return L.RaidAwayVerdict(ctx) end,
	poll = function(ctx) return L.RaidAwayVerdict(ctx) end })

-- On Anita's window: Wuber Rocks is in the raid and not at the raid spot (Wuber's own "not here").
function L.RaidAwayVerdict(ctx)
	local k = J.key("rider")
	for _, m in ipairs(J.call(J.DR(), "NotHere") or {}) do
		if m.key == k then return "pass", "Wuber Rocks is away from the spot (" .. tostring(m.zone or "?") .. ")" end
	end
	ctx.data.waitWhy = J.inGroupWith("rider") and "Wuber Rocks still counts as at the raid spot" or "Wuber Rocks isn't in the raid"
end

L.AddCheck({ id = "raid_tap", title = "Request from the app", scene = "raid", who = "rider", judge = "driver", secs = 20, timeout = 60,
	click = "type /wuber and tap Request a summon",
	poll = function(ctx)
		local rows = ctx.DR and ctx.DR.raidRows
		if type(rows) == "table" and rows[J.key("rider")] then return "pass", "queued from the app (Request a summon)" end
	end })

L.AddCheck({ id = "raid_nvm", title = "nvm drops", scene = "raid", who = "rider", judge = "driver", secs = 15, timeout = 30,
	click = "type nvm in raid chat",
	poll = function(ctx)
		local rows = ctx.DR and ctx.DR.raidRows
		if type(rows) ~= "table" then return end
		if rows[J.key("rider")] then ctx.data.had = true return end
		if ctx.data.had then return "pass", "dropped from the list" end
		ctx.data.waitWhy = "Wuber Rocks wasn't on the list when the step began"
	end })

L.AddCheck({ id = "raid_ask", title = "123 in raid chat", scene = "raid", who = "rider", judge = "driver", secs = 15, timeout = 45,
	click = "type 123 in raid chat",
	poll = function(ctx)
		local rows = ctx.DR and ctx.DR.raidRows
		local row = type(rows) == "table" and rows[J.key("rider")]
		if row then return "pass", "Wuber Rocks queued (" .. tostring(row.state) .. ")" end
	end })

L.AddCheck({ id = "raid_button", title = "Big button: Summon", scene = "raid", who = "driver", secs = 3, timeout = 20,
	say = "the big button offers the summon", poll = summonButton })

-- Two summoners never take the same raider: while a run is in the raid scene, Farra's and
-- Hayley's windows watch their own big button and ritual whenever another summoner holds Wuber
-- Rocks' row, and remember any clash; at "raid_one" they tell Anita's judge what they saw.
local watch = { seen = false }
L.raidWatch = watch

function L.RaidWatchTick(now)
	local run = L.RunCurrent and L.RunCurrent()
	local c = run and L.RUN_BY_ID[run.steps[run.index] or ""]
	local me = L.RunMyRole()
	if not (c and c.scene == "raid" and (me == "crew1" or me == "crew2")) then
		if not run then watch.sid = nil end
		return
	end
	if watch.sid ~= run.sid then
		watch.sid, watch.seen, watch.clash, watch.claimAt = run.sid, false, nil, nil
	end
	local DR = J.DR()
	local rows = DR and DR.raidRows
	local row = type(rows) == "table" and rows[J.key("rider")]
	local by = row and row.claimedBy
	if not by or by == L.myKey then
		if by == L.myKey and not watch.clash then watch.clash = "this window claimed Wuber Rocks as well" end
		watch.claimAt = nil
		return
	end
	watch.seen = true
	watch.claimAt = watch.claimAt or now
	if watch.clash then return end
	if castOn("rider") then
		watch.clash = "it was casting on Wuber Rocks too"
	elseif now - watch.claimAt > 1.5 and (J.title() or ""):find("^Summon Wuber") then
		watch.clash = "its big button still offered '" .. J.title() .. "'"
	end
end

L.OnLogin(function() L.Every(0.5, function() L.RaidWatchTick(L.Now()) end) end)

L.AddCheck({ id = "raid_cast", title = "Anita summons the raider", scene = "raid", who = "driver", secs = 15, timeout = 45,
	click = "click the big button (it says {button})", buttonText = "Summon Wuber",
	poll = function(ctx)
		if castOn("rider") then return "pass", "Anita's ritual started on Wuber Rocks" .. (ctx.sim and " (pretend)" or "") end
	end })

portalCheck("raid_portal1", "Farra clicks", "raid", "crew1")
portalCheck("raid_portal2", "Hayley clicks", "raid", "crew2")

L.AddCheck({ id = "raid_arrive", title = "Raider summoned", scene = "raid", who = "rider", judge = "driver", secs = 20, timeout = 90,
	click = function(ctx) return ctx.sim and "click Accept on the TEST MODE summon card" or "accept the summon" end,
	watch = { "wuber:DRIVE_RAID_DONE" },
	test = function() return "pass", "summoned, counted, off the list" end,
	poll = function(ctx)
		local rows = ctx.DR and ctx.DR.raidRows
		if type(rows) == "table" and not rows[J.key("rider")] and ctx.t > 1 then return "pass", "off the list" end
	end })

L.AddCheck({ id = "raid_one", title = "Nobody else took the raider", scene = "raid", who = "driver", secs = 3, timeout = 15,
	say = "Farra's and Hayley's Wuber left Wuber Rocks to Anita", also = { "crew1", "crew2" },
	observe = function(o)
		if watch.clash then o.Tell("clash: " .. watch.clash)
		elseif watch.seen then o.Tell("clear")
		else o.Tell("unseen") end
	end,
	watch = { "fact" },
	test = function(ctx, _, from, text)
		text = tostring(text or "")
		local who = L.RunShort(L.RunRoleOf(tostring(from)) or "") or tostring(from)
		if text:find("^clash") then return "fail", who .. ": " .. text:sub(8) end
		ctx.data.heard = ctx.data.heard or {}
		ctx.data.heard[who] = text
		local n, unseen = 0, {}
		for name, t in pairs(ctx.data.heard) do
			n = n + 1
			if t == "unseen" then unseen[#unseen + 1] = name end
		end
		if n < 2 then return end
		table.sort(unseen)
		if #unseen == 2 then return "fail", "neither crew window saw Anita's claim (their Wuber missed the raid row)" end
		return "pass", "Farra's and Hayley's buttons and rituals left Wuber Rocks alone" .. (#unseen == 1 and (" (" .. unseen[1] .. " never saw the claim)") or "")
	end,
	onTimeout = function(ctx)
		local got = {}
		for name in pairs(ctx.data.heard or {}) do got[#got + 1] = name end
		return "fail", #got == 0 and "no word from Farra's or Hayley's window" or ("only " .. table.concat(got, ", ") .. " answered")
	end })

L.AddCheck({ id = "raid_stop", title = "Stop", scene = "raid", who = "driver", secs = 15, timeout = 60,
	click = "press Stop on the Drive tab",
	poll = function(ctx) if J.call(ctx.DR, "RaidOn") ~= true then return "pass", "raid summons stopped" end end })

---------------------------------------------------------------------------
-- The end: the photo tour (the tester's one click), for the reviewer to check the visuals
---------------------------------------------------------------------------

L.AddScene({ id = "end", title = "Photo tour", prio = 99, last = true, always = true })

L.AddCheck({ id = "photo_tour", title = "Photo tour", scene = "end", who = "driver", secs = 90, timeout = 420,
	click = "press Close on the Drive tab if open, then click Start photo tour (below): hands off for about 2 minutes",
	button = { label = "Start photo tour", run = function(ctx)
		local ok, why = L.TourStart and L.TourStart()
		if not ok then return "fail", "the tour didn't start: " .. tostring(why) end
		ctx.data.on = true
	end },
	poll = function(ctx)
		if L.Touring and L.Touring() then ctx.data.on = true return end
		if not ctx.data.on then return end
		local t = L.lastTour or {}
		if (t.shots or 0) > 0 then
			return "pass", t.shots .. " screenshots" .. (t.reason and (", stopped: " .. t.reason) or "") .. (#(t.skipped or {}) > 0 and (", skipped " .. #t.skipped) or "")
		end
		return "fail", "no screenshots" .. (t.reason and (" (" .. t.reason .. ")") or "")
	end })

---------------------------------------------------------------------------
-- Login checks: no click, every window, a few seconds after login
---------------------------------------------------------------------------

L.AddCheck({ id = "login_wuber", login = true, who = "any", timeout = 10,
	poll = function()
		local W = L.W()
		if not W then return "fail", "Wuber isn't loaded" end
		return "pass", "Wuber " .. tostring(W.VERSION) .. ", lab " .. L.VERSION
	end })

L.AddCheck({ id = "login_old_addon", login = true, who = "cast", timeout = 5,
	poll = function()
		if (L.AddonInfo("RitualRides")) then return "fail", "the old summoning addon is still on: it locks Wuber's driving" end
		return "pass", "the old summoning addon is off"
	end })

L.AddCheck({ id = "login_prefixes", login = true, who = "cast", timeout = 15,
	poll = function(ctx)
		local CI = C_ChatInfo
		if type(CI) ~= "table" or type(CI.IsAddonMessagePrefixRegistered) ~= "function" then return "skip", "this client can't tell" end
		local DR = J.DR()
		local missing = {}
		for _, p in ipairs({ (L.W() or {}).PREFIX or "WUBER", DR and DR.TPREFIX or "WUBERT", L.PLAN_PREFIX or "WLAB" }) do
			if call(CI.IsAddonMessagePrefixRegistered, p) ~= true then missing[#missing + 1] = p end
		end
		if #missing == 0 then return "pass", "WUBER, WUBERT and WLAB registered" end
		if ctx.t > 10 then return "fail", "not registered: " .. table.concat(missing, ", ") end
	end })

L.AddCheck({ id = "login_channel", login = true, who = "cast", timeout = 60,
	poll = function()
		local W = L.W()
		local idx = W and J.call(W, "ChannelIndex")
		if idx then return "pass", "on Wuber's channel (/" .. tostring(idx) .. ")" end
	end,
	onTimeout = function() return "fail", "not on Wuber's channel after 60 s" end })

L.AddCheck({ id = "login_community", login = true, who = "cast", timeout = 60,
	poll = function(ctx)
		local W = L.W()
		if ctx.t < 25 or not W then return end
		local s = str(J.call(W, "CommunityStatus")) or "?"
		if s:find("not available", 1, true) then return "skip", s end
		if s:find("joined,", 1, true) or s:find("joined%.$") then return "pass", s end
		return "fail", s
	end })

L.AddCheck({ id = "login_flights", login = true, who = "cast", timeout = 10,
	poll = function()
		local W = L.W()
		if not (W and type(W.FlightCost) == "function") then return "fail", "W.FlightCost is missing" end
		for _, pair in ipairs({ { "Orgrimmar", "Thunder Bluff" }, { "Orgrimmar", "Crossroads" }, { "Ironforge", "Stormwind" } }) do
			local ok, c = pcall(W.FlightCost, pair[1], pair[2])
			if ok and num(c) then return "pass", ("flight prices loaded (%s to %s: %s)"):format(pair[1], pair[2], J.money(c)) end
		end
		return "fail", "no flight price known (the flight table didn't load)"
	end })

L.AddCheck({ id = "login_button", login = true, who = "cast", timeout = 20,
	poll = function(ctx)
		local b = rawget(_G, "WuberDriveButton")
		if ctx.t < 5 then return end
		if type(b) ~= "table" then return "pass", "no big button here (not driving)" end
		if call(b.IsShown, b) ~= true then return "pass", "the big button is hidden (closed)" end
		local ok, why = J.button()
		return ok and "pass" or "fail", why
	end })

L.AddCheck({ id = "login_settings", login = true, who = "cast", timeout = 10,
	poll = function()
		local W = L.W()
		if not (W and type(W.db) == "table") then return "fail", "WuberDB isn't loaded" end
		local bad = {}
		local ch = J.call(W, "Char")
		local price = type(ch) == "table" and num(ch.price)
		if price and price < (W.MIN_PRICE or 5000) then bad[#bad + 1] = "price " .. J.money(price) .. " is under " .. J.money(W.MIN_PRICE or 5000) end
		local scale = num(W.db.scale)
		if scale and (scale < 0.5 or scale > 2.5) then bad[#bad + 1] = "window size " .. scale end
		local b = type(W.db.blockedBuild) == "table" and W.db.blockedBuild[J.call(W, "Build") or ""]
		if type(b) == "table" and next(b) then
			local caps = {}
			for cap in pairs(b) do caps[#caps + 1] = tostring(cap) end
			table.sort(caps)
			bad[#bad + 1] = "the game refused " .. table.concat(caps, ", ") .. " before (Settings: Try again)"
		end
		if #bad > 0 then return "fail", table.concat(bad, "; ") end
		return "pass", "settings look sane" .. (price and (" (price " .. J.money(price) .. ")") or "")
	end })

-- Wuber's self-test runs 8 s after login, often before Wuber has joined its network channel
-- (the tester's test, 18 Nov: "Network channel joined" failed on every window). A fail of a LATE item
-- runs the self-test again about 60 s after login before it counts.
local SELFTEST_LATE = { ["Network channel joined"] = true }
local SELFTEST_AGAIN = 60 -- seconds after login

L.AddCheck({ id = "login_selftest", login = true, who = "cast", timeout = 90,
	poll = function(ctx)
		local c = L.Char()
		local st = c and c.selftest
		if type(st) ~= "table" or type(st.list) ~= "table" then return end
		if L.loginAt and (num(st.at) or 0) < L.loginAt then return end -- (the last session's)
		local failed, late = {}, false
		for _, x in ipairs(st.list) do
			if not x.ok then
				failed[#failed + 1] = tostring(x.name)
				if SELFTEST_LATE[x.name] then late = true end
			end
		end
		if late and not ctx.data.again then
			local since = L.loginAt and (L.Epoch() - L.loginAt) or (ctx.t + 8)
			if since < SELFTEST_AGAIN then
				ctx.data.waitWhy = "waiting to run the self-test again " .. SELFTEST_AGAIN .. " s after login"
				return
			end
			ctx.data.again = true
			L.RunSelfTest("login +" .. SELFTEST_AGAIN .. " s")
			return
		end
		local note = ctx.data.again and (" (again " .. SELFTEST_AGAIN .. " s after login)") or ""
		if #failed > 0 then return "fail", #failed .. " of " .. #st.list .. " failed: " .. table.concat(failed, ", ") .. note end
		return "pass", "Wuber's self-test: all " .. #st.list .. " passed" .. note
	end })

L.AddCheck({ id = "login_versions", login = true, who = "cast", timeout = 40, watch = { "version" },
	poll = function(ctx)
		local mine = L.RunVersionText():gsub("~", "/")
		local n, names = 0, {}
		for _, v in pairs(L.RunHeardVersions()) do
			local theirs = ("%s/%s/%s"):format(tostring(v.wuber), tostring(v.lab), tostring(v.proto))
			if theirs ~= mine then return "fail", tostring(v.name) .. " runs " .. theirs .. ", this window " .. mine end
			n = n + 1
			names[#names + 1] = L.RunShort(L.RunRoleOf(v.name) or "?") or tostring(v.name)
		end
		local want = 0
		for _, role in ipairs(L.RUN_ROLE_ORDER) do
			if role ~= L.RunMyRole() and L.RunOnline(role) then want = want + 1 end
		end
		table.sort(names)
		if n > 0 and (n >= want or ctx.t > 30) then return "pass", "same versions as " .. table.concat(names, ", ") .. " (" .. mine .. ")" end
	end,
	onTimeout = function() return "skip", "no other window answered (alone?)" end })

L.AddCheck({ id = "login_errors", login = true, who = "cast", timeout = 30,
	poll = function(ctx)
		if ctx.t < 25 then return end
		local n, first, others = 0, nil, {}
		for _, l in ipairs(L.Tail(400)) do
			local at, kind, text = l:match("^([%d%.]+)|[^|]*|([^|]*)|(.*)$")
			if (kind == "err" or kind == "werr") and (tonumber(at) or 0) >= (L.loginAt or 0) then
				-- another addon's error (its file path names it) is said, not failed (BRIEF18)
				local from = kind == "err" and L.ErrorAddon(text) or nil
				if from and from ~= "Wuber" and from ~= "WuberLab" then
					if not others[from] then others[#others + 1], others[from] = from, true end
				else
					n = n + 1
					first = first or text
				end
			end
		end
		if n == 0 then
			if #others > 0 then return "pass", "no Wuber Lua errors since login (other addon: " .. table.concat(others, ", ") .. ")" end
			return "pass", "no Lua errors since login"
		end
		return "fail", n .. " Lua error" .. (n == 1 and "" or "s") .. ": " .. tostring(first):sub(1, 90)
	end })

-- Saved settings survived a restart: at logout (or /reload) the lab writes a marker and a
-- fingerprint of WuberDB into WuberLabDB; at the next login both must come back as written.
-- (Another Forever addon reports the client sometimes doesn't load saved variables back.)
local function wuberPrint(db)
	if type(db) ~= "table" then return nil end
	local n = 0
	for _ in pairs(type(db.chars) == "table" and db.chars or {}) do n = n + 1 end
	return { rides = type(db.rides) == "table" and #db.rides or 0, total = type(db.totals) == "table" and num(db.totals.rides) or 0,
		chars = n, time = num(db.timeValue) or 0, fx = str(db.fx) or "", ready = db.progressReady == true }
end
L.WuberPrint = wuberPrint

local PRINT_WORDS = { rides = "trips", total = "lifetime rides", chars = "characters", time = "'my time is worth'", fx = "effects", ready = "set-up flag" }

L.On("ADDON_LOADED", function(name)
	if plain(name) ~= L.ADDON or L.wuberAtLoad ~= nil then return end
	L.wuberAtLoad = wuberPrint(rawget(_G, "WuberDB")) or false
end)

-- At logout: the marker (not while the photo tour or the pretend rider hold demo data in WuberDB).
function L.RestartMark()
	local d, me = L.db, L.me
	if not (d and me) then return nil end
	if type(d.restart) ~= "table" then d.restart = {} end
	local busy = L.photo or L.pretend
	local m = { token = ("%x%04d"):format(math.floor(L.Epoch()), math.random(0, 9999)), at = L.Epoch(),
		wuber = not busy and wuberPrint(rawget(_G, "WuberDB")) or nil }
	d.restart[me] = m
	return m
end
L.On("PLAYER_LOGOUT", function() pcall(L.RestartMark) end)

-- ok, why: what the last logout wrote, against what came off disk this time.
function L.RestartVerdict(ctx)
	local d, me = L.db, L.me
	local now = L.wuberAtLoad
	if L.dbLoadedEmpty then
		local wit = L.runState and L.runState.witness
		if wit and wit.at < (L.loginAt or L.Epoch()) - 1 then
			return "fail", "WuberLabDB came back empty, yet the lab on " .. tostring(wit.name) .. " saw this one at "
				.. (date and date("%H:%M", math.floor(wit.at)) or "?") .. ": the game didn't load it back"
		end
		if ctx and ctx.t < 25 then return end -- (waiting for another window to say it saw this one)
		return "skip", "WuberLabDB came back empty and no other window remembers this one: a first start here"
	end
	local m = d and type(d.restart) == "table" and d.restart[me]
	if type(m) ~= "table" or not m.token then
		return "skip", "no marker from a logout yet: it is written at logout or /reload, checked at the next login"
	end
	local when = date and ("logout at " .. date("%H:%M", math.floor(num(m.at) or 0))) or "the last logout"
	if type(m.wuber) ~= "table" then return "pass", "the lab's marker from " .. when .. " came back (Wuber's was not taken: tour or pretend ride at logout)" end
	if not now then return "fail", "WuberDB wasn't there when the lab loaded (Wuber's saved variables didn't load)" end
	local diff = {}
	for _, k in ipairs({ "rides", "total", "chars", "time", "fx", "ready" }) do
		if tostring(m.wuber[k]) ~= tostring(now[k]) then
			diff[#diff + 1] = PRINT_WORDS[k] .. " " .. tostring(m.wuber[k]) .. " -> " .. tostring(now[k])
		end
	end
	if #diff > 0 then return "fail", "the game didn't load Wuber's saved settings back: " .. table.concat(diff, ", ") end
	return "pass", "the marker from " .. when .. " came back, and Wuber's settings (" .. now.rides .. " trips, " .. now.chars .. " characters)"
end

L.AddCheck({ id = "login_saved", login = true, who = "cast", timeout = 30, poll = function(ctx) return L.RestartVerdict(ctx) end })

L.AddCheck({ id = "login_sound", login = true, who = "rider", timeout = 5,
	poll = function()
		local v = L.PROBES and L.PROBES.sound and L.PROBES.sound()
		if v == nil then return "skip", "this client can't tell" end
		return v and "pass" or "fail", v and "Sound in Background is on (the bell is heard)" or "Sound in Background is off: the bell won't be heard"
	end })

L.AddCheck({ id = "login_f1", login = true, who = "cast", timeout = 5,
	poll = function()
		local v = L.PROBES and L.PROBES.f1 and L.PROBES.f1()
		if v == nil then return "skip", "this client can't tell" end
		local strict = L.db and L.db.requireF1Free
		return v and "pass" or "fail", v and (strict and "F1 is unbound (the swap key does nothing in game)" or "F1 may be bound (the multibox swap key; /lab f1 require to insist it is free)") or "F1 is bound in game: unbind it"
	end })

L.OnLogin(function() L.loginAt = L.Epoch() end)
