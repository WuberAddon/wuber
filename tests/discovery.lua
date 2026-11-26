-- Discovery: adverts in public chat (the driver's one-click advert, "[Wuber]"-tagged lines
-- heard), rulesets and seeds, drivers announcing themselves to the founders, the founders'
-- directory, the "How Wuber finds drivers" page and the OpenMap hint. Loaded by run.lua.

local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, driver, rider, settle, goOnline, clean = T.newWorld, T.driver, T.rider, T.settle, T.goOnline, T.clean
local msgs, fields, needUI, openDrive, HAVE_UI = T.msgs, T.fields, T.needUI, T.openDrive, T.HAVE_UI
local S = H.state

local ANITA, FARRA, HAYLEY, ROCKS, TESTCHAR = "Anita Lift", "Farra Way", "Hayley Cab", "Wuber Rocks", "Wuber TestCharacter"
local BOB = "Bob Stone"
local AD = "[Wuber] Summons to Ratchet 50s - I'm a Wuber driver, get the Wuber addon on CurseForge"

local function posts(w, from)
	local out = {}
	for _, p in ipairs(w.chatPosts or {}) do
		if not from or p.from == from then out[#out + 1] = p end
	end
	return out
end

local function whispered(w, kind, from, to)
	local out = {}
	for _, e in ipairs(msgs(w, kind, from, "WHISPER")) do
		if not to or H.key(e.target) == H.key(to) then out[#out + 1] = e end
	end
	return out
end

local function fired(c, name, what)
	local n = 0
	for _, e in ipairs(c.fired or {}) do
		if e.name == name and (not what or e.args[1] == what) then n = n + 1 end
	end
	return n
end

local function visible(f) return f ~= nil and H.visible(f) end

local function goButton(d) return d.env.WuberGoButton end
local function advertButton(d) return d.env.WuberAdvertButton end

---------------------------------------------------------------------------
-- The driver's advert
---------------------------------------------------------------------------

test("advert: GO ONLINE is one click that also posts ONE line in Trade; then at most once per 15 min", function()
	local w = newWorld()
	local d = driver(w, BOB)
	local r = rider(w)
	settle(w)
	ok(HAVE_UI, "needs the UI")
	eq(#posts(w), 0, "nothing posted at login")
	openDrive(d)
	w:advance(1.5)
	ok(visible(goButton(d)), "the secure GO button lies over the Open pill while offline")
	eq(S[goButton(d)].attrs.macrotext, "", "no line set before the click")
	T.clickGo(d)
	w:advance(3)
	eq(d.W.Char().drive, true, "online by the same click")
	local p = posts(w, BOB)
	eq(#p, 1, "one line posted")
	-- SPEC3 1.1 adverts: the driver's own line (the "advert" message) with the [Wuber] tag first
	ok(p[1].text:find("^%[Wuber%] "), "tagged: " .. p[1].text)
	ok(p[1].text:find("Ratchet", 1, true) and p[1].text:find("50s", 1, true), "place and fare: " .. p[1].text)
	eq(p[1].channel, "Trade", "in Trade (Ratchet is not a capital)")
	eq(p[1].how, "macro", "by the secure macro button")
	ok(#p[1].text <= 200, "200 bytes at most")
	eq(fired(d, "ADVERT", "posted"), 1, "ADVERT posted fired")
	-- the pill counts down; clicking it says when
	w:advance(1.5)
	ok(#d:findText("^Advert 1[45]m$") > 0, "the pill shows the wait (" .. list(d:visibleTexts()) .. ")")
	ok(not visible(advertButton(d)), "no secure button over the greyed pill")
	d:clickText("^Advert 1[45]m$", { pattern = true })
	w:advance(1)
	eq(#posts(w, BOB), 1, "no second line")
	-- offline and online again within 15 min: online, no line
	T.clickGo(d)
	w:advance(2)
	eq(d.W.Char().drive, false, "offline")
	ok(not visible(goButton(d)), "no advert button over GO within the 15 min")
	T.clickGo(d)
	w:advance(2)
	eq(d.W.Char().drive, true, "online again")
	eq(#posts(w, BOB), 1, "still one line")
	-- 15 min later the pill posts
	w:advance(900)
	ok(#d:findText("Advertise") > 0, "the pill is ready")
	ok(visible(advertButton(d)), "the secure button lies over it")
	d:clickOn(d.W.Driver.ui.console.advert) -- (the pill, where it is drawn)
	w:advance(1)
	eq(#posts(w, BOB), 2, "the pill posted")
	eq(#w:whispersTo(BOB), 0, "nobody was whispered by the advert")
	clean(w)
end)

test("advert: never without a click, never in combat, never with the setting off", function()
	local w = newWorld()
	local d = driver(w, BOB)
	settle(w)
	-- the plan alone posts nothing; going online from code posts nothing
	ok(d.W.AdvertPlan("Ratchet", 5000), "a plan is ready")
	goOnline(d)
	w:advance(30)
	eq(#posts(w), 0, "no line without a click")
	d.W.Driver.SetOnline(false)
	w:advance(2)
	openDrive(d)
	w:advance(1.5)
	ok(visible(goButton(d)), "ready")
	w:enterCombat(d)
	w:advance(1)
	ok(not visible(goButton(d)), "hidden in combat")
	local plan, why = d.W.AdvertPlan("Ratchet", 5000)
	eq(plan, nil, "no plan in combat")
	eq(why, "combat", "because of combat")
	T.clickGo(d)
	w:advance(2)
	-- 2.0: opening waits for the fight to end (the engine invites and whispers), and says so
	eq(d.W.Char().drive, false, "not opened in combat")
	ok(#d:findText("after the fight") > 0, "the toast says why (" .. list(d:visibleTexts()) .. ")")
	eq(#posts(w), 0, "and no line")
	w:leaveCombat(d)
	w:advance(1)
	-- the setting off
	d.W.db.advertOnline = false
	d.W.Fire("SETTINGS", "advertOnline")
	w:advance(2)
	ok(not visible(goButton(d)), "no advert button over GO with the setting off")
	T.clickGo(d)
	w:advance(2)
	eq(d.W.Char().drive, true, "online")
	eq(#posts(w), 0, "no line with the setting off")
	-- the Advertise pill still works by its own click
	w:advance(2)
	ok(visible(advertButton(d)), "the pill's button")
	d:clickOn(d.W.Driver.ui.console.advert) -- (the pill, where it is drawn)
	w:advance(1)
	eq(#posts(w), 1, "the pill posts")
	clean(w)
end)

test("advert: channel choice (Services in a capital, else Trade, LookingForGroup, General; none)", function()
	local w = newWorld()
	local d = driver(w, BOB, { spot = "Undercity" })
	settle(w)
	local W, p = d.W, d.player
	local function set(names)
		p.channels = {}
		for i, n in ipairs(names) do p.channels[i] = { index = i, name = n } end
	end
	set({ "General", "Trade", "LocalDefense", "Services", "LookingForGroup" })
	local idx, name, base = W.AdvertChannel()
	eq(base, "services", "Services in a capital")
	eq(idx, 4, "its number")
	w:placePlayer(p, "Ratchet")
	eq(select(3, W.AdvertChannel()), "trade", "Services only in a capital: Trade")
	set({ "General", "LocalDefense", "LookingForGroup" })
	eq(select(3, W.AdvertChannel()), "lookingforgroup", "no Trade: LookingForGroup")
	set({ "General - Durotar" })
	eq(select(3, W.AdvertChannel()), "general", "only General (with its zone)")
	set({ "WuberNet" })
	eq(W.AdvertChannel(), nil, "none")
	local plan, why = W.AdvertPlan("Ratchet", 5000)
	eq(why, "channel", "no channel, no plan")
	set({ "2. Trade - City" })
	eq(W.ChannelBase("Trade (Services) - City"), "services", "the Services spelling")
	eq(W.AdvertText("uc", 15000), "[Wuber] Summons to Undercity 1g 50s - I'm a Wuber driver, get the Wuber addon on CurseForge", "place and price")
	eq(W.AdvertText("Unknown", 100), "[Wuber] Warlock summons 50s - I'm a Wuber driver, get the Wuber addon on CurseForge", "no place, the lowest fare")
	ok(not W.AdvertText("|cffff0000www.gold|r", 5000):find("|", 1, true), "no codes")
	clean(w)
end)

---------------------------------------------------------------------------
-- Hearing "[Wuber]" lines
---------------------------------------------------------------------------

test("tagged line: its sender is asked (Q) and listed once he answers with his own D; untagged adverts never", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	local d = driver(w, BOB)
	d.W.Drive.opts().autoPublic = true -- (2.3.2, BRIEF19 R4: off by default, on after a warning)
	local r = rider(w)
	w:splitChannel(d, "other")
	settle(w, 20)
	goOnline(d)
	w:advance(5)
	eq(r.W.drivers["bob stone"], nil, "Bob is on another copy of the channel: not heard")
	local q0 = #whispered(w, "Q", TESTCHAR, BOB)
	-- untagged summon and portal adverts from anyone: nothing
	for _, line in ipairs({ "WTS summons to UC 50s", "Warlock summons, any zone, 1g", "Travel for FREE - Get your portals from me",
		"LF warlock summon to Ratchet", "wuberish is cool" }) do
		w:chatFrom("Some Body", line, "CHANNEL", "Trade")
	end
	w:chatFrom(BOB, "WTS summon to Ratchet 50s", "CHANNEL", "Trade")
	w:advance(5)
	eq(#whispered(w, "Q", TESTCHAR, BOB), q0, "no Q for an untagged line")
	eq(r.W.fallback.unconfirmed["some body"], nil, "nobody taken from untagged lines")
	eq(r.W.net.advertsHeard, 0, "no adverts counted")
	-- the tag, any case, from Bob's own click
	w:chatFrom(BOB, "[WUBER] Summons to Ratchet 50s - I'm a Wuber driver", "CHANNEL", "Trade")
	w:advance(1)
	eq(r.W.net.advertsHeard, 1, "a tagged line counted")
	ok(r.W.fallback.unconfirmed["bob stone"], "Bob is a name to ask")
	eq(r.W.drivers["bob stone"], nil, "but not shown yet")
	w:advance(6)
	ok(#whispered(w, "Q", TESTCHAR, BOB) > q0, "Wuber whispered Bob a Q")
	local x = r.W.drivers["bob stone"]
	ok(x, "listed after his own D")
	eq(x.via, "WHISPER", "by whisper")
	eq(x.price, 5000, "his price from his D, not from the line")
	eq(fired(r, "ADVERT", "heard"), 1, "heard fired")
	eq(fired(r, "ADVERT", "confirmed"), 1, "confirmed fired")
	local lines = table.concat(r.W.NetStatusLines(), " ")
	ok(lines:find("[Wuber] adverts heard: 1.", 1, true), "status: " .. lines)
	ok(lines:find("Ruleset: EU-PvE.", 1, true), "status ruleset: " .. lines)
	eq(#r.W.NetStatusLines(), 2, "no more status lines than before")
	-- a tagged line from someone who never answers: asked twice at most, then dropped
	w:chatFrom("Fake Lock", "[Wuber] cheap summons", "CHANNEL", "Trade")
	w:advance(120)
	ok(#whispered(w, "Q", TESTCHAR, "Fake Lock") <= 2, "a non-answer is asked twice at most")
	eq(r.W.drivers["fake lock"], nil, "never shown")
	-- /say and /yell too; our own line is ignored
	w:chatFrom("Yell Lock", "[wuber] summons here", "YELL")
	w:advance(1)
	ok(r.W.fallback.advertHeard["yell lock"], "a yell counts")
	r.W.HeardChatLine("[Wuber] me", TESTCHAR, "Trade", "Trade")
	eq(r.W.fallback.advertHeard["wuber testcharacter"], nil, "not ourselves")
	clean(w)
end)

---------------------------------------------------------------------------
-- Rulesets and seeds
---------------------------------------------------------------------------

test("ruleset: parsed from the realm name; founders whispered only on EU-PvE; seeds by ruleset", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	local d = driver(w)
	settle(w)
	local W = d.W
	eq(W.RulesetOf("CAMWOW EU5 Realm 5 PvE"), "EU-PvE")
	eq(W.RulesetOf("CAMWOW US2 Realm 1 PvP"), "US-PvP")
	eq(W.RulesetOf("CAMWOW EU1 Realm 3 RP"), "EU-RP")
	eq(W.RulesetOf("CAMWOW US1 Realm 9 Hardcore"), "US-HC")
	eq(W.RulesetOf("CAMWOWEU5Realm5PvE"), "EU-PvE", "normalised")
	eq(W.RulesetOf("CAMWOW EU4 Realm 7"), nil, "no ruleset in it")
	eq(W.RulesetOf("Forever"), nil)
	eq(W.FOUNDER_RULESET, "EU-PvE")
	eq(W.SeedList("EU-PvE")[1], ANITA, "founders first on theirs")
	eq(#W.SeedList("US-PvP"), 0, "none elsewhere yet")
	eq(#W.SeedList(false), 0, "unknown: none")
	-- a rider on US-PvP: never a whisper to a founder; its own seeds are asked
	for _, n in ipairs({ FARRA, HAYLEY, ROCKS }) do w:addClient(n, { spot = "Orgrimmar", class = "MAGE", allowMissing = true }) end
	local us = w:addClient("Usa Rider", { spot = "Orgrimmar", class = "MAGE", realm = "CAMWOW US2 Realm 1 PvP", allowMissing = true })
	us.W.SEEDS["US-PvP"] = { "Hub Lock" }
	us.W.db.favs["anita lift"] = true -- even a favourite with a founder's name
	local unk = w:addClient("Odd Rider", { spot = "Orgrimmar", class = "MAGE", realm = "Forever", allowMissing = true })
	local eu = w:addClient("Eu Rider", { spot = "Orgrimmar", class = "MAGE", allowMissing = true })
	w:advance(20)
	us.W.WhisperRound("full", true)
	unk.W.WhisperRound("full", true)
	w:advance(10)
	for _, f in ipairs({ ANITA, FARRA, HAYLEY, ROCKS }) do
		eq(#whispered(w, nil, "Usa Rider", f), 0, "US-PvP never whispers " .. f)
		eq(#whispered(w, nil, "Odd Rider", f), 0, "an unknown ruleset never whispers " .. f)
	end
	ok(#whispered(w, "Q", "Usa Rider", "Hub Lock") >= 1, "its own ruleset's seed is asked")
	ok(#whispered(w, "Q", "Eu Rider", ANITA) >= 1, "EU-PvE asks the founders")
	eq(#whispered(w, "Q", "Eu Rider", "Hub Lock"), 0, "not another ruleset's seeds")
	ok(table.concat(unk.W.NetStatusLines(), " "):find("Ruleset: unknown.", 1, true), "status says unknown")
	-- everything else works on an unknown ruleset: the channel driver is listed
	goOnline(d)
	w:advance(5)
	ok(unk.W.drivers["anita lift"], "the driver on the channel is listed")
	clean(w)
end)

---------------------------------------------------------------------------
-- Announces and the founders' directory
---------------------------------------------------------------------------

test("announce: a driver whispers his D to the founders online at once and every 15 min; offline ones back off; never off-ruleset", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	local hay = w:addClient(HAYLEY, { spot = "Orgrimmar", class = "MAGE", allowMissing = true })
	local d = driver(w, BOB)
	local us = w:addClient("Usa Lock", { spot = "Ratchet", class = "WARLOCK", realm = "CAMWOW US2 Realm 1 PvP", allowMissing = true })
	settle(w)
	goOnline(d)
	goOnline(us)
	w:advance(5)
	eq(#whispered(w, "D", BOB, HAYLEY), 1, "announced to Hayley (online)")
	-- Anita is offline: Bob's own login round found that out ("No player named"), so no
	-- announce goes to her for 30 min
	ok(d.W.fallback.offlineUntil["anita lift"], "Anita known offline")
	eq(#whispered(w, "D", BOB, ANITA), 0, "no announce to an offline founder")
	local failed0 = w.failedAddonWhispers or 0
	for _, f in ipairs({ ANITA, FARRA, HAYLEY, ROCKS }) do eq(#whispered(w, nil, "Usa Lock", f), 0, "US-PvP never announces to " .. f) end
	w:advance(300)
	eq(#whispered(w, "D", BOB, HAYLEY), 1, "not again within 15 min")
	w:advance(620)
	eq(#whispered(w, "D", BOB, HAYLEY), 2, "again after 15 min")
	eq(#whispered(w, "D", BOB, ANITA), 0, "still none to Anita")
	eq(w.failedAddonWhispers or 0, failed0, "offline founders not tried again within 30 min")
	-- Hayley's client keeps him in its directory, with his ruleset
	local e = hay.W.db.directory["bob stone"]
	ok(e, "in the founder's directory")
	eq(e.name, BOB)
	eq(e.ruleset, "EU-PvE")
	eq(d.W.db.directory["bob stone"], nil, "a non-founder keeps no directory")
	clean(w)
end)

test("directory: opt-out respected; 30 days and 300 at most; a Q to a founder gets rotating names in a K", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	local hay = w:addClient(HAYLEY, { spot = "Orgrimmar", class = "MAGE", allowMissing = true })
	local shy = driver(w, "Shy Lock")
	settle(w)
	shy.W.Char().starter = false
	goOnline(shy)
	w:advance(5)
	local D = whispered(w, "D", "Shy Lock", HAYLEY)
	eq(#D, 1, "announced")
	eq(fields(D[1])[18], "0", "the opt-out as D's last field")
	eq(hay.W.db.directory["shy lock"], nil, "never in the directory")
	-- the directory's limits
	local dir, now = hay.W.db.directory, hay.env.time()
	for i = 1, 320 do
		dir["dir lock" .. string.char(97 + i % 26) .. i] = { name = "Dir Lock" .. string.char(97 + i % 26), lastSeen = now - i }
	end
	dir["old lock"] = { name = "Old Lock", lastSeen = now - 31 * 86400 }
	local n = hay.W.PruneDirectory()
	eq(n, 300, "300 at most")
	eq(dir["old lock"], nil, "older than 30 days: gone")
	-- rotation: two askers get different names
	for k in pairs(dir) do dir[k] = nil end
	for i = 1, 12 do
		local nm = "Lock " .. string.char(64 + i) .. "one"
		dir[H.key(nm)] = { name = nm, lastSeen = now - i, ruleset = "EU-PvE" }
	end
	local a = hay.W.DirectoryNames("x y")
	local b = hay.W.DirectoryNames("x y")
	eq(#a, 8, "8 names")
	eq(a[1], "Lock Aone", "latest first")
	ok(a[1] ~= b[1], "the next asker gets other names first (" .. list(b) .. ")")
	-- a Q by whisper to the founder: a K with directory names
	local r = w:addClient("New Rider", { spot = "Orgrimmar", class = "MAGE", allowMissing = true })
	w:advance(15)
	local K = whispered(w, "K", HAYLEY, "New Rider")
	ok(#K >= 1, "the founder answered the Q with a K")
	local f = fields(K[1])
	ok(#f >= 3 and f[3]:find("^Lock "), "directory names in it: " .. K[1].text)
	ok(r.W.fallback.unconfirmed[H.key(f[3])], "the rider asks them (shown only once they answer)")
	eq(r.W.drivers[H.key(f[3])], nil, "not shown yet")
	clean(w)
end)

---------------------------------------------------------------------------
-- The page and the hints
---------------------------------------------------------------------------

local function helpTexts(c)
	local h = c.W.UI.settings.help
	return h and h.texts or {}
end

local function measureOk(c)
	local bad = {}
	for _, e in ipairs(helpTexts(c)) do
		local fs = e.fs
		local w = e.room
		local px = (S[fs].font and S[fs].font.size) or e.px
		local need = math.ceil((fs:GetStringWidth() or 0) / w) * px * 1.2
		local need2 = 0
		if c.W.Theme.MeasureText then need2 = math.ceil(c.W.Theme.MeasureText(e.text, e.px, "regular") / w) * e.px * 1.2 end
		if (fs:GetHeight() or 0) + 0.5 < math.max(need, need2) then bad[#bad + 1] = e.text:sub(1, 30) end
	end
	return bad
end

test("How Wuber finds drivers: opens from Settings, the empty state and the signal bars; scrolls; nothing cut off", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	needUI(r)
	local UI = r.W.UI
	UI.Toggle(true)
	w:advance(2.5)
	-- the empty state
	ok(#r:findText("No drivers online") > 0, "empty (" .. list(r:visibleTexts()) .. ")")
	r:clickText("Why?")
	w:advance(1)
	ok(UI.HelpShown(), "opened from the empty state")
	ok(#r:findText("How Wuber finds drivers") > 0, "the title")
	for _, t in ipairs({ "radio network", "on your realm", "a few seconds late", "OpenMap", "ruleset", "Ping drivers" }) do
		ok(#r:findText(t) > 0, "says " .. t)
	end
	eq(#measureOk(r), 0, "text cut off: " .. list(measureOk(r)))
	ok(#helpTexts(r) >= 9, "every card's one text (no titles now), and the footer")
	ok(not visible(r.env.WuberRequestButton), "no secure button over the page")
	-- scrolls
	local h = UI.settings.help
	ok((h.scrollMax or 0) > 0, "taller than the window")
	UI.ScrollHelp(-3)
	w:advance(1)
	ok(h.scroll > 100, "scrolled: " .. tostring(h.scroll))
	UI.ScrollHelp(-100)
	w:advance(1)
	eq(h.scroll, h.scrollMax, "to the bottom at most")
	r:clickOn(h.back)
	w:advance(1)
	ok(not UI.HelpShown(), "Back closes it")
	eq(UI.state.settingsOpen, false, "back on Home")
	-- the signal bars: tip and click
	local sig = UI.state.phone.signal
	local tip = sig.wuberTip.text
	ok(tostring(type(tip) == "function" and tip(sig) or tip):find("Few drivers? Tap to see how Wuber finds them", 1, true), "the tip line")
	r:clickOn(sig)
	w:advance(1)
	ok(UI.HelpShown(), "opened from the signal bars")
	UI.CloseHelp(true)
	-- from Settings, and back to Settings
	UI.OpenSettings()
	w:advance(1)
	ok(r:scrollIntoView(UI.settings.helpRow), "the player scrolls to the help row")
	r:click(UI.settings.helpRow)
	w:advance(1)
	ok(UI.HelpShown(), "opened from Settings")
	r:clickOn(h.back)
	w:advance(1)
	ok(UI.SettingsShown() and UI.state.settingsOpen, "back in Settings")
	clean(w)
end)

test("OpenMap: the hint shows once without OpenMap, never with it; the Settings row says it's needed", function()
	local w = newWorld()
	local r = rider(w)
	local o = rider(w, "Map Fan", { openMap = { stitched = true } })
	-- (design 2) the hint is the last row of the drivers list: a driver is listed
	local d = driver(w, "Bob Stone")
	settle(w)
	goOnline(d)
	w:advance(5)
	for _, c in ipairs({ r, o }) do
		c.W.UI.Toggle(true)
	end
	w:advance(3)
	ok(#r:findText("Get OpenMap to see drivers on your world map") > 0, "shown without OpenMap")
	eq(#o:findText("Get OpenMap to see drivers on your world map"), 0, "never with OpenMap")
	r.W.UI.OpenSettings("map") -- (round 9, G1: one section at a time)
	o.W.UI.OpenSettings("map")
	w:advance(1)
	ok(#r:findText("^Best with OpenMap: not installed$") > 0, "the map row says so")
	ok(#o:findText("^Best with OpenMap: installed$") > 0, "with OpenMap: the plain description")
	r.W.UI.CloseSettings(true)
	w:advance(1)
	-- dismissed: gone, and after a reload never again
	r:click(r.W.UI.state.screens.home.mapHint.close)
	w:advance(1)
	eq(#r:findText("Get OpenMap to see drivers on your world map"), 0, "dismissed")
	local r2 = w:reload(r)
	w:advance(15)
	r2.W.UI.Toggle(true)
	w:advance(3)
	eq(#r2:findText("Get OpenMap to see drivers on your world map"), 0, "once only")
	clean(w)
end)

test("Settings: advert and starter list toggles under Driving change what happens", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	local d = driver(w, BOB)
	local hay = w:addClient(HAYLEY, { spot = "Orgrimmar", class = "MAGE", allowMissing = true })
	settle(w)
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("driving") -- (round 9, G1: one section at a time)
	w:advance(1)
	local c = d.W.UI.settings.controls
	ok(c.advertOnline and c.starter, "both toggles")
	ok(#d:findText("Post an advert when I go online") > 0, "its label")
	ok(#d:findText("List me in Wuber's starter list") > 0, "its label")
	ok(d:scrollIntoView(c.advertOnline), "the player scrolls to the advert toggle")
	d:click(c.advertOnline)
	w:advance(1)
	eq(d.W.db.advertOnline, false, "advert off")
	ok(d:scrollIntoView(c.starter), "the player scrolls to the starter toggle")
	d:click(c.starter)
	w:advance(1)
	eq(d.W.Char().starter, false, "starter off")
	d.W.UI.CloseSettings(true)
	goOnline(d)
	w:advance(3)
	local D = whispered(w, "D", BOB, HAYLEY)
	ok(#D >= 1, "announced")
	eq(fields(D[#D])[18], "0", "opted out on the wire")
	eq(hay.W.db.directory["bob stone"], nil, "not in the directory")
	clean(w)
end)
