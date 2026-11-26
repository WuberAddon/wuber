-- Wuber Lab (developer only, never ship): the pretend rider. In the driver's own window, a fake
-- rider ("Pretend Labfake") books a ride: the lab feeds the very messages a real rider's Wuber
-- sends (the "WTB summon to ..." whisper, then R; later C) into Wuber's own event handler, so
-- The tester can step through the driver screens and the big button's states with one window.
--
-- Nothing is sent to anyone, and no real player can be touched:
--   * refused while a real ride, rider, request, raid row, ritual or trade is going on, in
--     combat, or on any window but the driver's (Anita), and only while selling;
--   * the name ends in "Labfake" (like the fake drivers): every addon whisper to it is kept here
--     (W.SendTo, Tools.lua), its invite is pretended (W.Try), crew messages, bell rings and
--     whispers naming it are dropped (DR.Send, DR.Whisper, DR.Ring), and the big button never
--     holds a line naming it (DR.Plan: such lines are taken out, so a click sends nothing);
--   * a real rider who asks meanwhile stops it at once, before Wuber hears them (DR.Request,
--     DR.Lead, the engine's onRequest), and everything is put back first;
--   * at the end (or a stop, an abort, a logout): the fake riders leave every list and
--     WuberDB is put back exactly as it was (the photo tour's snapshot), then checked for leftovers.
-- Steps a real second player is needed for (joining the group, the summon, the trade) are
-- skipped and marked "needs the rider account".

local _, L = ...

local show, str, num, call = L.show, L.str, L.num, L.call

L.PRETEND_NAME = "Pretend Labfake"
L.PRETEND_ASKER = "Asking Labfake"
L.pretend = nil -- { at, snap, wdb, rideId }

local function W_() return L.W() end
local function DR_()
	local W = W_()
	return W and W.Drive or nil
end

local function fake(v) return type(v) == "string" and v:lower():find("labfake", 1, true) ~= nil end

local function mentions(...)
	for i = 1, select("#", ...) do
		if fake((select(i, ...))) then return true end
	end
	return false
end
L.MentionsFake = mentions

-- One event into Wuber's own handler only (as if the game sent it).
function L.FeedWuber(event, ...)
	local W = W_()
	local f = W and W.frame
	if type(f) ~= "table" or type(f.GetScript) ~= "function" then return false end
	local handler = call(f.GetScript, f, "OnEvent")
	if type(handler) ~= "function" then return false end
	local ok, err = pcall(handler, f, event, ...)
	if not ok then L.Bug("pretend " .. tostring(event), err) end
	return ok
end

---------------------------------------------------------------------------
-- When it may run
---------------------------------------------------------------------------

-- A real player in the way: why (text), or nil.
function L.PretendReal()
	local W, DR = W_(), DR_()
	if not (W and DR) then return nil end
	if type(W.RideActive) == "function" and call(W.RideActive) then return "a ride of your own is going on" end
	for k, c in pairs(DR.customers or {}) do
		if not fake(k) then return (type(c) == "table" and tostring(c.name) or k) .. " is in the queue" end
	end
	for _, r in ipairs(W.incoming or {}) do
		if type(r) == "table" and not fake(r.buyerKey) then return "a request from " .. tostring(r.name or r.buyer) .. " is open" end
	end
	if next(DR.raidRows or {}) then return "raid summons have raiders listed" end
	if type(DR.cast) == "table" then return "a summon is going on" end
	local tf = rawget(_G, "TradeFrame")
	if type(tf) == "table" and call(tf.IsShown, tf) == true then return "a trade window is open" end
	return nil
end

function L.PretendCan()
	if L.pretend then return false, "a pretend ride is going already" end
	local W, DR = W_(), DR_()
	if not W or type(W.db) ~= "table" then return false, "Wuber isn't loaded" end
	if not DR or not DR.on then return false, "Wuber's driving isn't on here" end
	if L.RunMyRole() ~= "driver" or call(DR.Role) ~= "driver" then return false, "only in the driver's own window (" .. L.RunName("driver") .. ")" end
	if L.InCombat() then return false, "not in combat" end
	if L.photo then return false, "the photo tour is running" end
	if call(DR.RaidOn) == true then return false, "raid summons are on: Stop them first" end
	local why = L.PretendReal()
	if why then return false, why end
	for _, n in ipairs({ "Try", "SendTo", "Encode", "NewRideId" }) do
		if type(W[n]) ~= "function" then return false, "W." .. n .. " is missing" end
	end
	for _, n in ipairs({ "Plan", "Send", "Request", "Remove" }) do
		if type(DR[n]) ~= "function" then return false, "W.Drive." .. n .. " is missing" end
	end
	return true
end

---------------------------------------------------------------------------
-- The guards (installed once; they only ever act on a name ending in "Labfake")
---------------------------------------------------------------------------

local function strip(plan)
	if type(plan) ~= "table" then return plan end
	local held = false
	if type(plan.macrotext) == "string" and fake(plan.macrotext) then
		local keep, aimed = {}, false
		for l in (plan.macrotext .. "\n"):gmatch("(.-)\n") do
			if fake(l) then
				held = true
				if l:match("^%s*/tar") then aimed = true end
			elseif not (aimed and l:match("^%s*/cast")) then
				keep[#keep + 1] = l
			end
		end
		plan.macrotext = #keep > 0 and table.concat(keep, "\n") or nil
		if not plan.macrotext then plan.type = nil end
	end
	if type(plan.box) == "table" and type(plan.box.c) == "table" and fake(plan.box.c.name) then
		plan.box, held = nil, true
	end
	if held then
		plan.pretendHeld = true
		plan.sub = tostring(plan.sub or "") .. "  (pretend: nothing is sent)"
	end
	return plan
end
L.PretendStrip = strip

local guarded = false
local function installGuards()
	if guarded then return true end
	local W, DR = W_(), DR_()
	local G = L.Guard
	if not (W and DR and G) then return false end
	G(W, "Try", function(orig, cap, fn, ...)
		if mentions(...) then
			L.Log("fake", "kept local: " .. tostring(cap) .. " " .. show((...)))
			if cap == "invite" then return true end
			return false
		end
		return orig(cap, fn, ...)
	end)
	G(DR, "Send", function(orig, kind, ...)
		if mentions(...) then
			L.Log("fake", "kept local: crew message " .. tostring(kind) .. " about " .. show((...)))
			return nil
		end
		return orig(kind, ...)
	end)
	G(DR, "Whisper", function(orig, target, ...)
		if mentions(target, ...) then return nil end
		return orig(target, ...)
	end)
	G(DR, "Ring", function(orig, text, ...)
		if mentions(text) then return false end
		return orig(text, ...)
	end)
	G(DR, "Plan", function(orig, ...)
		return strip(orig(...))
	end)
	-- a real player asking stops the pretend ride first
	local function abortFor(name)
		if L.pretend and str(name) and not fake(name) then L.PretendAbort("a real player asked: " .. tostring(name)) end
	end
	G(DR, "Request", function(orig, name, ...)
		abortFor(name)
		return orig(name, ...)
	end)
	G(DR, "Lead", function(orig, name, ...)
		abortFor(name)
		return orig(name, ...)
	end)
	if type(DR.ENGINE) == "table" then
		G(DR.ENGINE, "onRequest", function(orig, ride, ...)
			if type(ride) == "table" then abortFor(ride.buyer) end
			return orig(ride, ...)
		end)
	end
	guarded = true
	return true
end

---------------------------------------------------------------------------
-- Begin, the rider's messages, the end
---------------------------------------------------------------------------

function L.PretendBegin()
	local ok, why = L.PretendCan()
	if not ok then return false, why end
	if not installGuards() then return false, "could not guard Wuber" end
	local W = W_()
	L.pretend = { at = L.Now(), snap = L.PhotoSnapshot(rawget(_G, "WuberDB") or W.db), wdb = W.db }
	L.Log("fake", "pretend rider ON (" .. L.PRETEND_NAME .. "): nothing is sent; WuberDB is put back afterwards")
	return true
end

-- The rider's Request click: the visible whisper, then R (rideId, dest, price, tier, rides).
function L.PretendBook()
	local p = L.pretend
	local W, DR = W_(), DR_()
	if not (p and W and DR) then return nil, "no pretend ride" end
	local b = call(DR.NetBeacon)
	if type(b) ~= "table" then return nil, "Anita isn't open to riders (no beacon)" end
	local id = call(W.NewRideId)
	p.rideId = id
	local money = str(call(W.Money, b.price)) or "50s"
	L.FeedWuber("CHAT_MSG_WHISPER", ("WTB summon to %s for %s"):format(tostring(b.dest), money), L.PRETEND_NAME)
	L.FeedWuber("CHAT_MSG_ADDON", W.PREFIX or "WUBER", call(W.Encode, "R", id, b.dest, b.price, 1, 3), "WHISPER", L.PRETEND_NAME)
	L.Log("fake", ("pretend rider booked: %s to %s for %s (ride %s)"):format(L.PRETEND_NAME, tostring(b.dest), money, tostring(id)))
	return id
end

-- The rider's Cancel ride: C.
function L.PretendCancel()
	local p = L.pretend
	local W = W_()
	if not (p and p.rideId and W) then return false end
	L.FeedWuber("CHAT_MSG_ADDON", W.PREFIX or "WUBER", call(W.Encode, "C", p.rideId), "WHISPER", L.PRETEND_NAME)
	L.Log("fake", "pretend rider cancelled ride " .. tostring(p.rideId))
	return true
end

-- A second pretend player only asks the price.
function L.PretendAsk()
	if not L.pretend then return false end
	L.FeedWuber("CHAT_MSG_WHISPER", "how much for a summon?", L.PRETEND_ASKER)
	L.Log("fake", "pretend player asked the price: " .. L.PRETEND_ASKER)
	return true
end

-- Every place a pretend rider could still be (memory and WuberDB): a list of where.
function L.PretendLeftovers()
	local W, DR = W_(), DR_()
	local out = {}
	if not W then return out end
	local function keys(t, where)
		if type(t) ~= "table" then return end
		for k in pairs(t) do if fake(k) then out[#out + 1] = where .. "." .. tostring(k) end end
	end
	if DR then
		keys(DR.customers, "customers")
		keys(DR.units, "units")
		keys(DR.ignored, "ignored")
		keys(DR.owing, "owing")
		local net = DR.net
		if type(net) == "table" then
			keys(net.rides, "net.rides")
			keys(net.held, "net.held")
			keys(net.cancelled, "net.cancelled")
		end
	end
	for _, r in ipairs(W.incoming or {}) do
		if type(r) == "table" and fake(r.buyerKey) then out[#out + 1] = "incoming." .. tostring(r.id) end
	end
	local seen, visits = {}, 0
	local function scan(t, path, depth)
		if type(t) ~= "table" or seen[t] or depth > 12 or visits > 20000 or #out > 20 then return end
		seen[t] = true
		for k, v in pairs(t) do
			visits = visits + 1
			if fake(k) or fake(v) then out[#out + 1] = path .. "." .. tostring(k) end
			if type(v) == "table" then scan(v, path .. "." .. tostring(k), depth + 1) end
		end
	end
	scan(rawget(_G, "WuberDB") or W.db, "WuberDB", 0)
	return out
end

-- Ends the pretend ride: the fakes off every list, WuberDB as it was. Returns the leftovers.
function L.PretendEnd(why)
	local p = L.pretend
	if not p then return nil end
	L.pretend = nil
	local W, DR = W_(), DR_()
	if W and DR then
		local gone = {}
		for k, c in pairs(DR.customers or {}) do if fake(k) then gone[#gone + 1] = c end end
		for _, c in ipairs(gone) do L.Safe("pretend remove", DR.Remove, c, "drop") end
		for i = #(W.incoming or {}), 1, -1 do
			local r = W.incoming[i]
			if type(r) == "table" and fake(r.buyerKey) then table.remove(W.incoming, i) end
		end
		local function sweep(t)
			if type(t) ~= "table" then return end
			local ks = {}
			for k in pairs(t) do if fake(k) then ks[#ks + 1] = k end end
			for _, k in ipairs(ks) do t[k] = nil end
		end
		sweep(DR.ignored)
		sweep(DR.helpers)
		sweep(DR.owing)
		sweep(DR.refusals)
		if type(DR.net) == "table" then
			sweep(DR.net.rides)
			sweep(DR.net.held)
			sweep(DR.net.cancelled)
		end
		if type(W.fallback) == "table" then sweep(W.fallback.booked) end
	end
	local ok, err = pcall(function()
		L.PhotoRestore(p.snap)
		if rawget(_G, "WuberDB") ~= p.snap.ref then _G.WuberDB = p.snap.ref end
		if W and W.db ~= p.wdb then W.db = p.wdb end
	end)
	if not ok then L.Bug("pretend restore", err) end
	if W then
		if type(W.Fire) == "function" then L.Safe("pretend fire", W.Fire, "REQUESTS", W.incoming) end
		if DR and type(DR.Changed) == "function" then L.Safe("pretend changed", DR.Changed) end
		local B = DR and DR.Button
		if type(B) == "table" and type(B.Refresh) == "function" and not L.InCombat() then L.Safe("pretend button", B.Refresh) end
	end
	local left = L.PretendLeftovers()
	L.Log("fake", ("pretend rider OFF (%s): %s"):format(tostring(why), #left == 0 and "nothing left behind" or ("LEFT: " .. table.concat(left, ", "))))
	return left
end

-- A real player turned up: everything back at once, the pretend run stops.
function L.PretendAbort(why)
	if not L.pretend then return end
	L.PretendEnd(why)
	local run = L.RunCurrent and L.RunCurrent()
	if run and run.scene == "pretend" then L.RunStop("pretend stopped: " .. tostring(why)) end
	if L.Say then L.Say("pretend rider stopped: " .. tostring(why) .. " (everything put back)") end
end

-- The Tools button and /lab pretend: the pretend run (one window, nothing sent).
function L.PretendStart()
	local ok, why = L.PretendCan()
	if not ok then
		if L.Say then L.Say("pretend rider: " .. tostring(why)) end
		L.Log("fake", "pretend rider refused: " .. tostring(why))
		return false, why
	end
	return L.RunStart({ scene = "pretend" })
end

L.runEndFns = L.runEndFns or {}
L.runEndFns[#L.runEndFns + 1] = function(run, why)
	if run.scene == "pretend" and L.pretend then L.PretendEnd(why == "done" and "the run is over" or tostring(why)) end
end

L.On("PLAYER_LOGOUT", function() if L.pretend then pcall(L.PretendEnd, "logout") end end)
L.On("PLAYER_REGEN_DISABLED", function() if L.pretend then L.PretendAbort("combat") end end)

---------------------------------------------------------------------------
-- The pretend run: Anita's window only
---------------------------------------------------------------------------

local NEEDS = "needs the rider account: "

L.AddScene({ id = "pretend", title = "Pretend rider (one window)", prio = 0, only = true, loc = true })

L.AddCheck({ id = "pr_open", title = "Open (selling)", scene = "pretend", who = "driver", secs = 10, timeout = 90,
	click = "Drive tab: choose Sell summons and press Open",
	begin = function() if L.J.selling() then return "pass", "already open, selling" end end,
	poll = function() if L.J.selling() then return "pass", "open, selling" end end })

L.AddCheck({ id = "pr_console", title = "The console", scene = "pretend", who = "driver", secs = 5, timeout = 60,
	click = "keep Wuber's window open on the Drive tab",
	poll = function() if L.J.onDrive() then return "pass", "Wuber's window is on the Drive tab" end end })

L.AddCheck({ id = "pr_book", title = "A pretend rider books", scene = "pretend", who = "driver", secs = 5, hold = 3, timeout = 15,
	say = "the lab plays the rider: 'WTB summon to ...' and the Wuber request (nothing is sent)",
	begin = function()
		local ok, why = L.PretendBegin()
		if not ok then
			L.After(0, function() L.RunStop("pretend refused: " .. tostring(why)) end)
			return "fail", why
		end
		local id, why2 = L.PretendBook()
		if not id then return "fail", why2 end
	end,
	poll = function()
		local W = L.W()
		local c = L.J.cust and L.Key(L.PRETEND_NAME) and W.Drive.customers[L.Key(L.PRETEND_NAME)]
		local inc
		for _, r in ipairs(W.incoming or {}) do if fake(r.buyerKey) then inc = r end end
		if c and inc and inc.state == "accepted" then
			return "pass", "in the queue (" .. tostring(c.state) .. "), accepted at " .. L.J.money(inc.price) .. " (the answer stayed here)"
		end
	end })

L.AddCheck({ id = "pr_row", title = "Queue row", scene = "pretend", who = "driver", secs = 3, hold = 4, timeout = 15,
	say = "the console lists the pretend rider",
	poll = function()
		local t = L.J.textShown("Pretend")
		if t then return "pass", "the console shows '" .. t:sub(1, 60) .. "'" end
	end })

L.AddCheck({ id = "pr_invited", title = "Invite (pretend)", scene = "pretend", who = "driver", secs = 3, hold = 3, timeout = 15,
	say = "Wuber invites by itself (the invite is pretended: nothing goes out)",
	poll = function()
		local c = W_() and DR_().customers[L.Key(L.PRETEND_NAME)]
		if c and c.state == "invited" then return "pass", "invited (kept here)" end
	end })

L.AddCheck({ id = "pr_button", title = "Big button: invited", scene = "pretend", who = "driver", secs = 3, hold = 5, timeout = 15,
	say = "the big button says who is invited",
	poll = function(ctx)
		local t = L.J.title() or ""
		if t:find("Pretend", 1, true) then
			local ok, why = L.J.button()
			if not ok then return "fail", why end
			return "pass", "it says '" .. t .. "' (" .. why .. ")"
		end
		ctx.data.waitWhy = "the big button says '" .. t .. "'"
	end })

L.AddCheck({ id = "pr_join", title = "Rider joins", scene = "pretend", who = "driver", kind = "skip", secs = 0,
	say = NEEDS .. "accepting the group invite" })
L.AddCheck({ id = "pr_summon", title = "Summon", scene = "pretend", who = "driver", kind = "skip", secs = 0,
	say = NEEDS .. "the summon and the portal" })
L.AddCheck({ id = "pr_trade", title = "Trade", scene = "pretend", who = "driver", kind = "skip", secs = 0,
	say = NEEDS .. "paying by trade" })

L.AddCheck({ id = "pr_cancel", title = "Rider cancels", scene = "pretend", who = "driver", secs = 5, hold = 3, timeout = 15,
	say = "the pretend rider cancels (Wuber's C)",
	begin = function() if not L.PretendCancel() then return "fail", "no pretend ride to cancel" end end,
	poll = function()
		local W = L.W()
		local c = W.Drive.customers[L.Key(L.PRETEND_NAME)]
		local inc
		for _, r in ipairs(W.incoming or {}) do if fake(r.buyerKey) and r.buyerKey == L.Key(L.PRETEND_NAME) then inc = r end end
		if not c and not inc then return "pass", "off the queue and the requests" end
	end })

L.AddCheck({ id = "pr_price", title = "Price question", scene = "pretend", who = "driver", secs = 5, hold = 5, timeout = 15,
	say = "a pretend player whispers 'how much for a summon?'",
	begin = function() if not L.PretendAsk() then return "fail", "no pretend ride" end end,
	poll = function(ctx)
		local p = L.J.plan()
		local t = p and str(p.title) or ""
		if t:find("Asking", 1, true) then
			if fake(p.macrotext) or (type(p.box) == "table") then return "fail", "the button would send to the pretend player" end
			return "pass", "it says '" .. t .. "' (its whisper held back: nothing is sent)"
		end
		ctx.data.waitWhy = "the big button says '" .. t .. "'"
	end })

L.AddCheck({ id = "pr_clean", title = "Cleaned up", scene = "pretend", who = "driver", secs = 3, timeout = 10,
	say = "the pretend riders go and WuberDB is put back",
	begin = function()
		local left = L.PretendEnd("done")
		if not left then return "fail", "the pretend ride had already ended" end
		if #left > 0 then return "fail", "left behind: " .. table.concat(left, ", "):sub(1, 100) end
		return "pass", "nothing left behind, WuberDB as before"
	end })
