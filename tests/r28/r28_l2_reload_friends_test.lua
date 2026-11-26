local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
-- (r28 L2) a solo driver's /reload keeps the friends who came with a rider as "came with" rows
-- (the story of round4's scenario 19: Dan Moss rides, Bo and Bi Helper click the portal)
local ANITA, DAN, BO, BI = "Anita Lift", "Dan Moss", "Bo Helper", "Bi Helper"
local SPOT = "Undercity"
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end

local function drops(w, from)
	local out = {}
	for i = (from or 0) + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBERT" and e.result == 0 and e.text:match("^DROP~") then out[#out + 1] = e.text end
	end
	return out
end

local function row(c, name) return c.W.Drive.customers[key(name)] end

local function press(c)
	local b = c.env.WuberDriveButton
	ok(b and H.visible(b), "the big button is drawn")
	return c:click(b)
end

-- World:reload with a step while the window is closed (between) and a look at the saved data (edit)
local function reloadWith(w, client, between, edit)
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
	if between then between() end
	p.online = true
	return w:addClient(p.name, { saved = saved, addons = client.allAddons or client.addons, class = p.class,
		reload = true, keepChannels = true, realm = client.realm, addonDirs = client.addonDirs, allowMissing = true })
end

-- Dan asks, the driver casts (or not), Bo and Bi are in the group and click the portal
local function story(arrive)
	local w = T.newWorld()
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	w:addBot(BO, { spot = SPOT })
	w:addBot(BI, { spot = SPOT })
	lock.W.Drive.SetOpen(true)
	w:advance(2)
	w:addBot(DAN)
	w:botWhisper(DAN, lock, "summon pls")
	w:advance(3)
	if arrive then press(lock) end
	w:advance(1)
	w:group({ ANITA, DAN, BO, BI })
	if arrive then
		w:clickPortal(BO)
		w:clickPortal(BI)
	end
	w:advance(3.5)
	if arrive then w:advance(8) end
	local want = arrive and "arrived" or "joined"
	eq(row(lock, DAN) and row(lock, DAN).state, want, "control: Dan is " .. want)
	for _, n in ipairs({ BO, BI }) do
		local c = row(lock, n)
		eq(c and c.state, "lead", "control: " .. n .. " is a 'came with' row before the /reload")
		eq(c and c.cameWith, DAN, "control: " .. n .. " came with Dan before the /reload")
	end
	return w, lock
end

local function friendsCameWithDan(lock, names, when)
	for _, n in ipairs(names) do
		local c = row(lock, n)
		ok(c, n .. " is still on the list " .. when)
		eq(c and c.state, "lead", n .. " is not a rider (no 'is here (no ride)' row) " .. when)
		eq(c and c.cameWith, DAN, n .. " still 'came with Dan?' " .. when)
	end
end

test("r28 AUD-49b: after a solo driver's /reload the friends who came with an arrived rider are still 'came with Dan?' rows", function()
	local w, lock = story(true)
	local mark = #w.addonLog
	lock = w:reload(lock)
	w:advance(3)
	eq(row(lock, DAN) and row(lock, DAN).state, "arrived", "Dan is still arrived, still owing")
	friendsCameWithDan(lock, { BO, BI }, "after the /reload")
	local d = drops(w, mark)
	for _, t in ipairs(d) do ok(not t:find(DAN, 1, true), "Dan is never dropped: " .. t) end
	T.clean(w)
end)

test("r28 AUD-49b: after a solo driver's /reload the friends who came with a waiting rider are still 'came with Dan?' rows", function()
	local w, lock = story(false)
	lock = w:reload(lock)
	w:advance(3)
	eq(row(lock, DAN) and row(lock, DAN).state, "joined", "Dan is still waiting (joined)")
	friendsCameWithDan(lock, { BO, BI }, "after the /reload")
	T.clean(w)
end)

test("r28 AUD-49b: a friend who left the group while the driver reloaded is not put back on the list", function()
	local w, lock = story(true)
	lock = reloadWith(w, lock, function() w:leave(BI) end)
	w:advance(3)
	eq(row(lock, DAN) and row(lock, DAN).state, "arrived", "Dan is still arrived")
	friendsCameWithDan(lock, { BO }, "after the /reload")
	eq(row(lock, BI), nil, "Bi, gone from the group, is not listed")
	T.clean(w)
end)

test("r28 AUD-49b: a saved queue from before (no came-with list) still brings the rider back after a /reload", function()
	local w, lock = story(true)
	local had
	lock = reloadWith(w, lock, nil, function(saved)
		for _, ch in pairs(saved.Wuber.chars or {}) do
			if type(ch) == "table" and type(ch.queue) == "table" then had = true; ch.queue.with = nil end
		end
	end)
	ok(had, "control: the queue was saved at logout")
	w:advance(3)
	eq(row(lock, DAN) and row(lock, DAN).state, "arrived", "Dan is still arrived, still owing")
	ok(row(lock, BO) and row(lock, BI), "both friends are listed again (as the roster finds them)")
	eq(row(lock, DAN) and row(lock, DAN).cameWith, nil, "Dan is a rider, not 'came with'")
	T.clean(w)
end)
