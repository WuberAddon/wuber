-- Wuber 2.4, Settings diet step A: Advanced mode switch, rows behind Advanced, removed rows, search and typed commands. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function openSettings(c, w, where)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings(where)
	w:advance(1)
	return c.W.UI.settings
end

local function hasText(c, text)
	return #c:findText(text, false, true) > 0
end

local function inside(a, b, slack)
	slack = slack or 1
	return a.l >= b.l - slack and a.l + a.w <= b.l + b.w + slack and a.b >= b.b - slack and a.b + a.h <= b.b + b.h + slack
end

local function hasInClip(c, st, text)
	local clip = H.rect(st.clip)
	for _, fs in ipairs(c:findText(text, false, true)) do
		if inside(H.rect(fs), clip, 2) then return true end
	end
	return false
end

local function findResult(st, lbl)
	for _, b in ipairs(st.find.items) do
		if H.visible(b) and b.m and b.m.label == lbl then return b end
	end
	return nil
end

local function deepCopy(v, skipTop)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, val in pairs(v) do
		if not (skipTop and k == "advanced") then
			out[k] = deepCopy(val, false)
		end
	end
	return out
end

local function deepEqual(a, b, path, skipTop)
	path = path or "WuberDB"
	if type(a) ~= type(b) then return false, path .. ": type " .. type(a) .. " vs " .. type(b) end
	if type(a) ~= "table" then
		if a ~= b then return false, path .. ": " .. tostring(a) .. " vs " .. tostring(b) end
		return true
	end
	for k, v in pairs(a) do
		if not (skipTop and k == "advanced") then
			local same, why = deepEqual(v, b[k], path .. "." .. tostring(k), false)
			if not same then return false, why end
		end
	end
	for k in pairs(b) do
		if not (skipTop and k == "advanced") and a[k] == nil then
			return false, path .. "." .. tostring(k) .. ": extra key"
		end
	end
	return true
end

test("v24 diet: Warlock in Simple sees the four always Driving rows, then Advanced rows after SetAdvanced(true) with no reopen", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB, { simple = true })
	T.settle(w)
	openSettings(d, w, "driving")
	for _, lbl in ipairs({ "Invite riders who whisper me", "Post an advert when I go online", "Your badge", "Key for the big button" }) do
		ok(hasText(d, lbl), "always visible in Driving: " .. lbl)
	end
	for _, lbl in ipairs({ "Request words", "Group size", "Alert character" }) do
		eq(#d:findText(lbl, false, true), 0, "hidden in Simple: " .. lbl)
	end
	d.W.SetAdvanced(true)
	for _, lbl in ipairs({ "Request words", "Group size", "Alert character" }) do
		ok(hasText(d, lbl), "visible in Advanced without reopening: " .. lbl)
	end
	T.clean(w)
end)

test("v24 diet: non-Warlock rider in Simple sees Riding always rows, not My time is worth, and no Driving rows", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	openSettings(r, w, "riding")
	ok(hasText(r, "Tips"), "Tips visible")
	ok(hasText(r, "Flight offers"), "Flight offers visible")
	eq(#r:findText("My time is worth", false, true), 0, "My time is worth hidden in Simple")
	for _, lbl in ipairs({ "Invite riders who whisper me", "Post an advert when I go online", "Your badge", "Key for the big button", "Request words" }) do
		eq(#r:findText(lbl, false, true), 0, "no Driving row for a non-Warlock: " .. lbl)
	end
	r.W.UI.OpenSettings()
	w:advance(0.5)
	eq(#r:findText("Driving", false, true), 0, "no Driving card on the home for a non-Warlock")
	T.clean(w)
end)

test("v24 diet: Advanced mode quick switch on folded home toggles W.Advanced() and autoAccept quick switch", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	r.W.db.fold = { v = 1, pages = {}, narrow = true }
	local st = openSettings(r, w)
	eq(r.W.Advanced(), false, "starts in Simple")
	ok(st.find.advQuick and H.visible(st.find.advQuick), "Advanced mode quick switch is shown on home")
	ok(hasText(r, "Advanced mode"), "Advanced mode label visible")
	eq(#r:findText("Auto-accept my driver's invite", false, true), 0, "autoAccept quick switch hidden in Simple")
	r:click(st.find.advQuick.switch)
	w:advance(0.5)
	eq(r.W.Advanced(), true, "clicking turns Advanced on")
	ok(hasText(r, "Auto-accept my driver's invite"), "autoAccept quick switch appears in Advanced")
	r:click(st.find.advQuick.switch)
	w:advance(0.5)
	eq(r.W.Advanced(), false, "clicking again turns Advanced off")
	eq(#r:findText("Auto-accept my driver's invite", false, true), 0, "autoAccept quick switch hidden again")
	T.clean(w)
end)

test("v24 diet: switching Advanced mode on and off changes no other saved value", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB, {
		simple = true,
		saved = { Wuber = { sound = false, fx = "light", timeValue = 250000, autoLeave = false, drive = { opts = { autoTrade = false, lowShards = 5 } } } },
	})
	T.settle(w)
	openSettings(d, w)
	local before = deepCopy(d.env.WuberDB, true)
	d.W.SetAdvanced(true)
	w:advance(0.5)
	d.W.SetAdvanced(false)
	w:advance(0.5)
	local same, why = deepEqual(before, d.env.WuberDB, "WuberDB", true)
	ok(same, why or "saved values unchanged")
	T.clean(w)
end)

test("v24 diet: removed rows never appear in Settings pages in Simple or Advanced", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB, { simple = true })
	T.settle(w)
	d.W.db.fold = { v = 1, pages = {}, narrow = true }
	openSettings(d, w)
	local gone = {
		"Accept my crew's invites",
		"List people asking in public chat",
		"Open the trade when they land",
		"Remind riders who haven't paid",
		"Pause me if I'm away",
		"Only cast with a Soul Shard",
		"Show what riders want",
		"Share notes with my own accounts",
		"Tell me about updates",
		"Your message templates",
		"Who summons",
		"Retry blocked actions",
		"My target per hour",
		"Where to get Wuber",
	}
	local pages = { "riding", "driving", "map", "sound", "window" }
	for _, adv in ipairs({ false, true }) do
		d.W.SetAdvanced(adv)
		for _, page in ipairs(pages) do
			d.W.UI.OpenSettings(page)
			w:advance(0.5)
			for _, lbl in ipairs(gone) do
				eq(#d:findText(lbl, false, true), 0, (adv and "Advanced " or "Simple ") .. page .. ": no " .. lbl)
			end
		end
	end
	d.W.UI.OpenSettings("window")
	w:advance(0.5)
	eq(#d:findText("Report a bug", false, true), 0, "Report a bug row gone from This window")
	T.clean(w)
end)

test("v24 diet: saved autoTrade false stays off after login and after opening Settings", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB, { simple = true, saved = { Wuber = { drive = { opts = { autoTrade = false } } } } })
	T.settle(w)
	eq(d.W.Drive.opts().autoTrade, false, "autoTrade stays false after login")
	eq(d.env.WuberDB.drive.opts.autoTrade, false, "saved autoTrade stays false after login")
	openSettings(d, w, "driving")
	d.W.SetAdvanced(true)
	w:advance(0.5)
	eq(d.W.Drive.opts().autoTrade, false, "autoTrade stays false after opening Settings")
	eq(d.env.WuberDB.drive.opts.autoTrade, false, "saved autoTrade stays false after opening Settings")
	T.clean(w)
end)

test("v24 diet: typed commands toggle away, wants, sharenotes and updates", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d:slash("/wuber drive away off")
	eq(d.W.Drive.opts().awayGuard, false, "awayGuard off")
	ok(d:said("Pausing you when you are away: off%."), "away off printed")
	d:slash("/wuber drive wants off")
	eq(d.W.Drive.opts().watchBounty, false, "watchBounty off")
	ok(d:said("Showing what riders want: off%."), "wants off printed")
	d:slash("/wuber drive sharenotes off")
	eq(d.W.Drive.opts().shareNotes, false, "shareNotes off")
	ok(d:said("Sharing notes with your own accounts: off%."), "sharenotes off printed")
	d:slash("/wuber updates off")
	eq(d.env.WuberDB.updateNotes, false, "updateNotes false")
	ok(d:said("Update notes: off%."), "updates off printed")
	d:slash("/wuber updates on")
	ok(d.env.WuberDB.updateNotes ~= false, "updateNotes back on")
	ok(d:said("Update notes: on%."), "updates on printed")
	T.clean(w)
end)

test("v24 diet: Hidden drivers row hides when empty and shows after hiding a driver", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	openSettings(r, w, "riding")
	eq(#r:findText("Hidden drivers", false, true), 0, "Hidden drivers not shown when nobody is hidden")
	r.env.WuberDB.hidden = r.env.WuberDB.hidden or {}
	r.env.WuberDB.hidden["bob-realm"] = true
	r.W.UI.UpdateSettings()
	ok(hasText(r, "Hidden drivers"), "Hidden drivers shown after hiding a driver")
	T.clean(w)
end)

test("v24 diet: search in Simple tags Advanced rows and clicking shows the home switch; Advanced opens the row", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB, { simple = true })
	T.settle(w)
	d.W.db.fold = { v = 1, pages = {}, narrow = true }
	local st = openSettings(d, w)
	d:type(st.find.box.edit, "request words", false)
	w:advance(0.5)
	local b = findResult(st, "Request words")
	ok(b, "Request words matched in Simple")
	ok(b.where:GetText():find("Advanced", 1, true), "result carries Advanced: " .. tostring(b.where:GetText()))
	d:click(b)
	w:advance(0.5)
	eq(d.W.Advanced(), false, "mode stays Simple")
	eq(st.view, "home", "shows the folded home")
	ok(hasText(d, "Advanced mode"), "home shows Advanced mode")
	ok(st.find.flashing and st.find.flashing.frame == st.find.advQuick, "Advanced mode switch is washed")
	d.W.SetAdvanced(true)
	w:advance(0.5)
	d:type(st.find.box.edit, "request words", false)
	w:advance(0.5)
	local b2 = findResult(st, "Request words")
	ok(b2, "Request words matched in Advanced")
	ok(not b2.where:GetText():find("Advanced", 1, true), "no Advanced tag in Advanced mode")
	d:click(b2)
	w:advance(0.5)
	eq(st.view, "section", "opens the section")
	eq(st.sec, "driving", "opens Driving")
	ok(hasText(d, "Request words"), "Request words row is visible")
	T.clean(w)
end)

test("v24 diet: Badges over heads is on Sound and effects, not on Map", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	local st = openSettings(r, w, "map")
	eq(hasInClip(r, st, "Badges over heads"), false, "not on Map")
	ok(hasInClip(r, st, "Drivers on the world map"), "Map keeps Drivers on the world map")
	r.W.UI.OpenSettings("sound")
	w:advance(0.5)
	ok(hasInClip(r, st, "Badges over heads"), "on Sound and effects")
	ok(hasInClip(r, st, "Turn on friendly nameplates"), "nameplates button on Sound and effects")
	T.clean(w)
end)

test("v24 diet: Check my game runs and clears refused actions for this build", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	local st = openSettings(r, w, "window")
	local ver, bld, _, toc
	if type(r.env.GetBuildInfo) == "function" then ver, bld, _, toc = r.env.GetBuildInfo() end
	local candidates = {}
	local function add(k) if k ~= nil and k ~= "" then candidates[#candidates + 1] = k end end
	add(bld)
	add(bld and tostring(bld))
	add(ver)
	if ver and bld then
		add(tostring(ver) .. "." .. tostring(bld))
		add(tostring(ver) .. ":" .. tostring(bld))
		add(tostring(ver) .. "-" .. tostring(bld))
		add(tostring(ver) .. " " .. tostring(bld))
		add(tostring(ver) .. "/" .. tostring(bld))
		add(tostring(ver) .. "_" .. tostring(bld))
	end
	if toc and bld then
		add(tostring(toc) .. ":" .. tostring(bld))
		add(tostring(toc) .. "-" .. tostring(bld))
		add(tostring(toc) .. "." .. tostring(bld))
	end
	add(toc)
	add(toc and tostring(toc))
	add("unknown")
	local buildKey
	for _, k in ipairs(candidates) do
		r.env.WuberDB.blockedBuild = { [k] = { accept = true } }
		if r.W.IsBlocked("accept") then
			buildKey = k
			break
		end
	end
	if not buildKey then
		buildKey = (bld and tostring(bld)) or (ver and tostring(ver)) or "unknown"
		r.env.WuberDB.blockedBuild = { [buildKey] = { accept = true } }
	end
	r:click(st.controls.check)
	w:advance(0.5)
	eq(r.W.IsBlocked("accept"), false, "refused action is cleared")
	eq(r.env.WuberDB.blockedBuild and r.env.WuberDB.blockedBuild[buildKey], nil, "the entry for this build is gone")
	ok(st.results and st.results:IsShown(), "Check my game results shown")
	T.clean(w)
end)
