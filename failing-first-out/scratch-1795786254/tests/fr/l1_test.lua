-- Fix round 2.4, group l1: what a solo driver's /reload must keep (HUNT-120, HUNT-126). Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANITA, DAN, BO, BI = "Anita Lift", "Dan Moss", "Bo Helper", "Bi Helper"
local SPOT = "Undercity"
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local function row(c, name) return c.W.Drive.customers[key(name)] end

local function press(c)
	local b = c.env.WuberDriveButton
	ok(b and H.visible(b), "the big button is drawn")
	return c:click(b)
end

-- World:reload with a look at the saved data (edit) while the window is closed
local function reloadWith(w, client, edit)
	local p = client.player
	client:fire("PLAYER_LOGOUT")
	local saved = {}
	for _, addon in ipairs(client.allAddons or client.addons) do
		local sv = addon == "Wuber" and "WuberDB" or (addon .. "DB")
		local v = rawget(client.env, sv)
		if v == nil then v = client.saved[addon] end
		saved[addon] = v
	end
	if edit then edit(saved) end
	w:closeClient(client, false)
	p.online = true
	return w:addClient(p.name, { saved = saved, addons = client.allAddons or client.addons, class = p.class,
		reload = true, keepChannels = true, realm = client.realm, addonDirs = client.addonDirs, allowMissing = true })
end

---------------------------------------------------------------------------
-- HUNT-120: an automatic invite is still one after a /reload
---------------------------------------------------------------------------

-- Auto mode invites Dan after a clear whisper; he joins the group
local function autoStory()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar", shards = 10 })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().kickAfter = false
	ok(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = true })
	w:advance(1)
	w:botWhisper(DAN, a, "summ to org pls")
	w:advance(4)
	local dan = DR.customers[key(DAN)]
	eq(dan and dan.state, "joined", "control: Dan joined the group")
	eq(dan and dan.auto, "whisper", "control: Dan was invited automatically")
	eq(DR.CanOops(dan), true, "control: Oops is offered before the /reload")
	return w, a, DR, dan
end

test("fr l1 HUNT-120: a rider Wuber invited by itself can still be oopsed after a /reload, and his words are still learnt", function()
	local w, a, _, dan = autoStory()
	local words = dan.autoMsg
	a = w:reload(a)
	w:advance(3)
	local DR = a.W.Drive
	local c = DR.customers[key(DAN)]
	eq(c and c.state, "joined", "Dan is still a waiting rider after the /reload")
	eq(c and c.auto, "whisper", "Dan is still an automatic invite")
	eq(c and c.autoMsg, words, "the words he was invited for are kept")
	eq(DR.CanOops(c), true, "Oops is still offered")
	eq(DR.Oops(c), true, "Oops works")
	local o = DR.db and DR.db.oops
	local n = 0
	for _ in pairs(type(o) == "table" and type(o.lines) == "table" and o.lines or {}) do n = n + 1 end
	eq(n, 1, "his words are marked as a wrong invite")
	T.clean(w)
end)

test("fr l1 HUNT-120: Oops clicked, then a /reload before the big button: the sorry and the removal are still owed", function()
	local w, a, DR0, dan = autoStory()
	eq(DR0.Oops(dan), true, "control: Oops clicked")
	eq(DR0.Plan().title, "Oops: remove Dan", "control: the big button offers the removal before the /reload")
	a = w:reload(a)
	w:advance(3)
	local DR = a.W.Drive
	local c = DR.customers[key(DAN)]
	eq(c and c.oops, true, "the oops is still owed after the /reload")
	eq(DR.CanOops(c), false, "Oops is not offered a second time")
	eq(DR.Plan().title, "Oops: remove Dan", "the big button still offers the removal")
	eq(#w:whispersTo(DAN), 0, "control: nothing whispered yet")
	press(a)
	w:advance(2)
	eq(#w:whispersTo(DAN), 1, "one click says sorry")
	eq(w:player(DAN).group, nil, "and takes Dan out of the group")
	eq(DR.customers[key(DAN)], nil, "Dan's row is gone")
	T.clean(w)
end)

test("fr l1 HUNT-120: a saved queue from before (no auto, autoMsg or oops fields) still loads", function()
	local w, a = autoStory()
	local had
	a = reloadWith(w, a, function(saved)
		for _, ch in pairs(saved.Wuber.chars or {}) do
			if type(ch) == "table" and type(ch.queue) == "table" then
				for _, s in ipairs(ch.queue.list or {}) do
					had = true
					s.auto, s.autoMsg, s.oops, s.gone = nil, nil, nil, nil
				end
			end
		end
	end)
	ok(had, "control: the queue was saved at logout")
	w:advance(3)
	local DR = a.W.Drive
	local c = DR.customers[key(DAN)]
	eq(c and c.state, "joined", "Dan is still a waiting rider")
	eq(DR.CanOops(c), false, "old data: not known as an automatic invite, so no Oops")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- HUNT-126: a paid rider who left, his friends still in the group
---------------------------------------------------------------------------

-- Dan asks, is summoned and pays; Bo and Bi clicked the portal ("came with Dan?"); Dan leaves the group
local function paidStory()
	local w = T.newWorld()
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	w:addBot(BO, { spot = SPOT })
	w:addBot(BI, { spot = SPOT })
	lock.W.Drive.SetOpen(true)
	w:advance(2)
	w:addBot(DAN)
	w:botWhisper(DAN, lock, "summon pls")
	w:advance(3)
	press(lock)
	w:advance(1)
	w:group({ ANITA, DAN, BO, BI })
	w:clickPortal(BO)
	w:clickPortal(BI)
	w:advance(11.5)
	local dan = row(lock, DAN)
	eq(dan and dan.state, "arrived", "control: Dan has arrived")
	local d, r = lock.player, w:player(DAN)
	w:openTrade(d, r) w:advance(0.5) w:tradeMoney(r, tonumber(dan.price) or 5000) w:tradeAccept(d) w:tradeAccept(r) w:advance(1)
	eq(dan.state, "paid", "control: Dan has paid")
	w:leave(DAN)
	w:advance(1)
	dan = row(lock, DAN)
	eq(dan and dan.state, "paid", "control: Dan's paid row stays after he left")
	eq(dan and dan.gone, true, "control: Dan is marked as gone")
	for _, n in ipairs({ BO, BI }) do
		local c = row(lock, n)
		eq(c and c.state, "lead", "control: " .. n .. " is a 'came with' row before the /reload")
		eq(c and c.cameWith, DAN, "control: " .. n .. " came with Dan before the /reload")
	end
	return w, lock
end

test("fr l1 HUNT-126: a paid rider has left, his friends stay: after a /reload his row and their 'came with Dan?' are still there", function()
	local w, lock = paidStory()
	lock = w:reload(lock)
	w:advance(3)
	local dan = row(lock, DAN)
	eq(dan and dan.state, "paid", "Dan's paid row is back")
	eq(dan and dan.gone, true, "Dan is still marked as gone")
	for _, n in ipairs({ BO, BI }) do
		local c = row(lock, n)
		ok(c, n .. " is still on the list")
		eq(c and c.state, "lead", n .. " is not a rider")
		eq(c and c.cameWith, DAN, n .. " still 'came with Dan?'")
	end
	T.clean(w)
end)

test("fr l1 HUNT-126: a rider who was still waiting and is out of the group after the /reload is not put back", function()
	local w = T.newWorld()
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	lock.W.Drive.SetOpen(true)
	w:advance(2)
	w:addBot(DAN)
	w:botWhisper(DAN, lock, "summon pls")
	w:advance(3)
	w:group({ ANITA, DAN })
	w:advance(3.5)
	eq(row(lock, DAN) and row(lock, DAN).state, "joined", "control: Dan waits in the group")
	local p = lock.player
	lock:fire("PLAYER_LOGOUT")
	local saved = {}
	for _, addon in ipairs(lock.allAddons or lock.addons) do
		local sv = addon == "Wuber" and "WuberDB" or (addon .. "DB")
		local v = rawget(lock.env, sv)
		if v == nil then v = lock.saved[addon] end
		saved[addon] = v
	end
	w:closeClient(lock, false)
	w:leave(DAN)
	p.online = true
	lock = w:addClient(p.name, { saved = saved, addons = lock.allAddons or lock.addons, class = p.class,
		reload = true, keepChannels = true, realm = lock.realm, addonDirs = lock.addonDirs, allowMissing = true })
	w:advance(3)
	eq(row(lock, DAN), nil, "Dan, gone from the group and not paid, is not listed")
	T.clean(w)
end)
