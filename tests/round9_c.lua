-- Round 9 (the 2.3.0 fix round, BRIEF9), agent C (driver): tests of the driver-side fixes that have no
-- module test of their own. Test names start "r9 c:". Loaded by run.lua with the module tests' helpers.
local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list

local ANA, BEA, CAL, TESTCHAR = "Ana Smith", "Bea Jones", "Cal Brown", "Wuber TestCharacter"
local SPOT = "Undercity"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end

-- Three Warlocks of one crew (Ana leads, the window on the network), open; Wuber (a 2.3.0 app rider)
-- books Ana and joins
local function crewScene()
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(name, names, ANA) } })
	end
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE", money = 1000000 })
	w:group(names)
	w:advance(15)
	local DR = cs[1].W.Drive
	local engine = DR.ENGINE
	local onRequest = engine.onRequest
	engine.onRequest = function(x)
		x.riderVer = "2.3.0"
		return onRequest(x)
	end
	DR.SetOpen(true)
	w:advance(8)
	return { w = w, ana = cs[1], bea = cs[2], cal = cs[3], r = r, DR = DR }
end

---------------------------------------------------------------------------
-- C4: crew windows show the rider's passphrase (only while the passphrase setting is on)
---------------------------------------------------------------------------

test("r9 c: C4 a crew window shows the rider's passphrase when the setting is on, the same words as the driver's", function()
	local s = crewScene()
	local w = s.w
	ok(s.r.W.RequestRide(key(ANA)), "requested")
	w:advance(9)
	local ca = s.DR.customers[key(TESTCHAR)]
	ok(ca and ca.wuberRide, "Ana took the Wuber ride")
	local cb = s.bea.W.Drive.customers[key(TESTCHAR)]
	ok(cb, "Bea's window lists Wuber")
	ok(cb and cb.rideId == ca.wuberRide and not cb.wuberRide, "Bea knows the ride only from ST field 9")
	-- the setting on (Agent D's W.PassphraseOn, following the captain)
	s.bea.W.PassphraseOn = function() return true end
	s.ana.W.PassphraseOn = function() return true end
	local words = s.ana.W.Driver.Passphrase(ca)
	ok(words, "the driver's window has the words")
	eq(s.bea.W.Driver.Passphrase(cb), words, "the crew window: the same words")
	eq(s.ana.W.Driver.Passphrase(ca), words, "the driver's window still")
	-- the setting off: no window shows them (the rider doesn't see them either)
	s.bea.W.PassphraseOn = function() return false end
	s.ana.W.PassphraseOn = function() return false end
	eq(s.bea.W.Driver.Passphrase(cb), nil, "off: not on the crew window")
	eq(s.ana.W.Driver.Passphrase(ca), nil, "off: not on the driver's window")
	-- no setting at all (an older build): crew windows stay quiet, the driver's window as in 2.3.0
	s.bea.W.PassphraseOn = nil
	s.ana.W.PassphraseOn = nil
	eq(s.bea.W.Driver.Passphrase(cb), nil, "no setting: not on the crew window")
	eq(s.ana.W.Driver.Passphrase(ca), words, "no setting: the driver's window")
	-- a rider who never booked through the app has no ride id: never words
	eq(s.bea.W.Driver.Passphrase({ name = "Dan Miller", source = "group" }), nil, "no ride id: none")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- C2: the shift card's Post to party shows (and its secure button docks) the moment the card opens
---------------------------------------------------------------------------

local FARRA = "Farra Moon"
local CUT = {
	{ name = T.ANITA, key = key(T.ANITA), casts = 5, clicks = 0, share = 21000 },
	{ name = FARRA, key = key(FARRA), casts = 0, clicks = 9, share = 14000 },
}

test("r9 c: C2 the shift card opens with Post to party beside Nice and the share button docked over it once the card has risen", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = SPOT })
	w:addBot(FARRA, { spot = SPOT, class = "WARLOCK" })
	w:group({ T.ANITA, FARRA })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Sorted = function() return {} end
	DR.IsOpen = function() return true end
	DR.Shards = function() return 12 end
	DR.Cut = function() return CUT, { rule = "clicks", pct = 40 } end
	DR.CutText = function() return "Shift split: Anita 2g 10s, Farra 1g 40s" end
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	local D = W.Driver
	D.ShiftEnded({ rides = 3, copper = 48000, crewRides = 2, crewCopper = 20000 })
	-- no tick yet: what the player sees the moment the card opens
	local s = W.UI.drive.screens.shift
	ok(s and s.frame.open, "the shift card opened")
	local p = s.split
	ok(p and p.post:IsShown(), "Post to party shows at once")
	eq(s.done:GetWidth(), 156, "Nice makes room for it (never under it)")
	-- (#16) the share button may not sit below the window while the card rises (the pill is under the window's foot
	-- then): it docks over the pill as soon as the pill lies inside the window, so it is checked after the rise (0.32 s)
	w:advance(0.4)
	local sb = a.env.WuberShareButton
	ok(sb and sb:IsShown(), "the share button is docked once the card has risen")
	local br, pr = H.rect(sb), H.rect(p.post)
	ok(math.abs(br.l - pr.l) < 1 and math.abs(br.b - pr.b) < 1, "over the pill")
	-- a second later, nothing moved: the pill and Nice never overlap
	w:advance(1.1)
	ok(p.post:IsShown(), "still there")
	eq(s.done:GetWidth(), 156, "Nice still beside it")
	local dr = H.rect(s.done)
	pr = H.rect(p.post)
	ok(pr.l + pr.w <= dr.l + 0.5 or dr.l + dr.w <= pr.l + 0.5, "Post to party and Nice side by side")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- S4: the Closed / Raid stopped card in the Drive tab never says "in Wuber's Drive tab"; the
-- Riders card under it doesn't repeat how to open
---------------------------------------------------------------------------

local function plain(s) return ((s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

test("r9 c: S4 the closed card in the Drive tab says Tap Open below; floating over its console, tap Open below", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = SPOT })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	local b = DR.button
	ok(b, "the big button")
	eq(plain(b.title.wuberText), "Closed", "closed")
	eq(plain(b.sub.wuberText), "Tap Open below to start taking riders", "docked: no 'in Wuber's Drive tab'")
	local v = W.Driver.ui.console
	ok(v.empty and v.empty:IsShown(), "the Riders card")
	ok(not v.empty.sub.wuberText:find("Open", 1, true), "the Riders card doesn't repeat it: " .. v.empty.sub.wuberText)
	-- raid summons stopped
	W.Drive.SetMode("raid")
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	eq(plain(b.title.wuberText), "Raid summons stopped", "raid")
	eq(plain(b.sub.wuberText), "Tap Start below to begin raid summons", "docked: Start below")
	-- the floating button (Wuber's window closed): (BRIEF20 B5) its console with the Open pill is right
	-- under it, so "tap Open below"; the button alone (B.Solo) names the Drive tab (tests/drive/button_test.lua)
	W.Drive.SetMode("sell")
	W.UI.Toggle(false)
	w:advance(2)
	DR.Changed()
	w:advance(2)
	eq(plain(b.sub.wuberText), "tap Open below", "floating")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- S5: the Drive footer's Messages looks like the other links (no filled circle, a speech bubble)
---------------------------------------------------------------------------

test("r9 c: S5 the footer's Messages is a speech bubble with a small new dot, never a selected-looking circle", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = SPOT })
	w:advance(15)
	local W = a.W
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	local v = W.Driver.ui.console
	local m, c = v.links.messages, v.links.crew
	ok(m and T.H.visible(m), "Messages shows")
	ok((m.icon.wuberTexture or m.icon:GetTextureFilePath() or ""):find("chat", 1, true), "a speech bubble: " .. tostring(m.icon:GetTextureFilePath()))
	local cr = { m.icon:GetVertexColor() }
	local mr = { c.icon:GetVertexColor() }
	w:advance(0.7)
	cr = { m.icon:GetVertexColor() }
	for i = 1, 3 do ok(math.abs(cr[i] - mr[i]) < 0.01, "the icon is muted like the others") end
	ok(m.glow, "the new-messages dot exists")
	ok(m.glow and m.glow:GetWidth() <= 10, "the new hint is a small dot, not a circle behind the icon: " .. tostring(m.glow and m.glow:GetWidth()))
	ok(m.glow and m.glow:IsShown(), "and shows before Messages is opened")
	-- opened once: the dot goes
	W.Driver.ShowScreen("messages")
	w:advance(1)
	W.UI.ShowDrive("console")
	w:advance(1)
	ok(not (m.glow and m.glow:IsShown()), "no dot once seen")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- S2: Earnings never says "free": nothing earned is 0g (the game's gold coin icon)
---------------------------------------------------------------------------

test("r9 c: S2 Earnings with nothing earned says 0 gold (coin icon), never free; amounts carry coin icons", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = SPOT })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	W.Driver.ShowScreen("earnings")
	w:advance(2)
	local s = W.UI.drive.screens.earnings
	local line = s.stats.wuberText
	ok(not line:lower():find("free", 1, true), "never free: " .. line)
	ok(line:find("0g", 1, true) and not line:find("|T", 1, true), "0g, no coin: " .. line)
	-- some earned: letters (design 1 H)
	DR.LogTotals = function() return { rides = 2, copper = 52500, tips = 0, open = 30, asks = 3 } end
	s.update()
	line = s.stats.wuberText
	ok(line:find("5g 25s", 1, true) and not line:find("|T", 1, true), line)
	T.clean(w)
end)

---------------------------------------------------------------------------
-- S7 / S10: raid summons. Not in a raid: nobody claims everyone is here. "Ready to summon?",
-- hidden while raid summons run. "You · 10 shards". One summoner picker. Raiders listed once.
---------------------------------------------------------------------------

local function vis(a) return a:visibleTexts() end
local function countText(a, text)
	local n = 0
	for _, t in ipairs(vis(a)) do if plain(t) == text then n = n + 1 end end
	return n
end
local function hasText(a, text)
	for _, t in ipairs(vis(a)) do if plain(t):find(text, 1, true) then return true end end
	return false
end

-- (design 2) the tab bar is at the bottom of the window, so the end of a long page lies under it until the player
-- scrolls: brings a region of a T.Scroll list well inside the list's view (the wheel does the same in the game),
-- clear of a toast that may lie over the view's last line
local function scrollTo(sc, region)
	local view, r = T.H.rect(sc), T.H.rect(region)
	local scale = view.w / sc:GetWidth()
	if r.b < view.b then sc:ScrollTo((sc.offset or 0) + (view.b - r.b) / scale + 60, true) end
end

local function raidConsole(wide)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = SPOT })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Shards = function() return 10 end
	if wide then
		a.wide = true
		W.db.coach = true
		W.UI.WindowWide(true)
	elseif W.UI.WindowWide then
		W.UI.WindowWide(false)
	end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	W.Drive.SetMode("raid")
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	return w, a, W, DR
end

test("r9 c: S7 raid folded: Ready to summon?, one picker, You · 10 shards, no 'everyone is here' without a raid; hidden while running", function()
	local w, a, W, DR = raidConsole(false)
	local D = W.Driver
	local v = D.ui.console
	eq(DR.InRaid(), false, "not in a raid")
	ok(T.H.visible(v.ready), "the checklist shows while stopped")
	eq(v.ready.title.wuberText, "Ready to summon?", "raid words, not 'Ready to drive?'")
	ok(not hasText(a, "Ready to drive"), "no driving words")
	ok(T.H.visible(v.pick), "the Summoners pill")
	ok(not hasText(a, "Change"), "no second picker (Change)")
	ok(not hasText(a, "Nobody summons yet"), "the checklist says it; the strip doesn't repeat it")
	for _, l in ipairs(v.ready.lines) do
		if l:IsShown() then ok(not l.fix:IsShown() or l.fix.label.wuberText ~= "Pick", "no Pick button: the Summoners pill does it") end
	end
	-- Not here: open it; without a raid it doesn't say everyone is here
	local R = v.raid
	ok(R and R.nhHead and R.nhHead:IsShown(), "Not here (0) shows for the runner")
	scrollTo(v.scroll, R.nhHead) -- (design 2) the tab bar is at the bottom: a row below the list's view is scrolled to
	a:clickOn(R.nhHead)
	w:advance(1)
	D.RefreshNow()
	w:advance(1)
	ok(not hasText(a, "Everyone in your raid is here"), "no 'everyone is here' without a raid")
	ok(hasText(a, "Join a raid to see who isn't here"), "says why: " .. table.concat(vis(a), " | "))
	-- a summoner chip: "You · 10 shards"
	W.Driver.RaidSummoners = function() return { { key = W.myKey, name = T.ANITA, role = "lock", shards = 10, app = true } } end
	D.RefreshNow()
	w:advance(1)
	ok(hasText(a, "· 10 shards"), "You · 10 shards: " .. table.concat(vis(a), " | "))
	-- raid summons running: the checklist goes (unless it can't run: see "r9 c review")
	DR.IsOpen = function() return true end
	DR.CanRunRaid = function() return true end
	D.RefreshNow()
	w:advance(1)
	ok(not v.ready:IsShown(), "no checklist while raid summons run")
	T.clean(w)
end)

test("r9 c: S10 raid unfolded: Raiders once (the side pane), one summoner picker, no 'everyone is here' without a raid", function()
	local w, a, W, DR = raidConsole(true)
	local D = W.Driver
	ok(D.Wide("raid"), "unfolded")
	eq(countText(a, "Raiders"), 0, "the left has no Raiders heading")
	ok(hasText(a, "Raiders ("), "the side pane lists them")
	ok(not hasText(a, "Summoned tonight:"), "tonight's count is the status line's")
	ok(not hasText(a, "Change"), "no Change: the Summoners pill picks")
	ok(T.H.visible(D.ui.console.pick), "the Summoners pill")
	ok(not hasText(a, "Everyone in your raid is here"), "no 'everyone is here' without a raid")
	ok(hasText(a, "Join a raid to see who isn't here"), "says why the list is empty")
	T.clean(w)
end)

test("r9 c: S10 console unfolded: 'nobody here' once (the side pane), crew cards full width", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = SPOT })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Shards = function() return 10 end
	a.wide = true
	W.db.coach = true
	W.UI.WindowWide(true)
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	local D = W.Driver
	ok(D.Wide("console"), "unfolded")
	local v = D.ui.console
	ok(v.empty:IsShown(), "the left has the one empty Riders card (r18)")
	ok(v.qhead:IsShown(), "and its heading")
	ok(not hasText(a, "Queue (0)"), "no second queue on the right")
	eq(countText(a, "You're closed"), 1, "says it once, with the state: " .. table.concat(vis(a), " | "))
	eq(countText(a, "Nobody waiting"), 0, "no second 'nobody'")
	-- the crew card: the side pane's full width
	local you
	for _, fs in ipairs(a:findText("You", false, true)) do
		local p = fs:GetParent()
		if p and p.cut and p:IsVisible() then you = p end
	end
	ok(you, "the You card")
	ok(you and you:GetWidth() >= 320, "full width: " .. tostring(you and you:GetWidth()))
	ok(you and hasText(a, "10 shards"), "with its shards")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- S13: the empty heatmap's note is centred on the squares, and not repeated under the heatmap
---------------------------------------------------------------------------

test("r9 c: S13 empty Earnings: the heatmap note sits centred on the squares; no second note under it", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = SPOT })
	w:advance(15)
	local W = a.W
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	W.Driver.ShowScreen("earnings")
	w:advance(2)
	local s = W.UI.drive.screens.earnings
	local hm = s.heat
	ok(hm and T.H.visible(hm.empty), "the note over the squares")
	local first, last = hm.cells[1], hm.cells[24]
	local gl, gr = first:GetLeft(), last:GetRight()
	local el, er = hm.empty:GetLeft(), hm.empty:GetRight()
	ok(el >= gl - 0.5 and er <= gr + 0.5, ("inside the squares: note %.1f..%.1f, squares %.1f..%.1f"):format(el, er, gl, gr))
	ok(math.abs((el + er) / 2 - (gl + gr) / 2) <= 1, "centred on them")
	for _, d in ipairs(hm.days) do ok(d:GetRight() <= el + 0.5, "clear of the day names") end
	ok(not (s.top and s.top:IsShown()), "no 'Open a few hours...' again under the heatmap")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- S17: each placeholder chip's tooltip shows what it becomes
---------------------------------------------------------------------------

local function tipOf(c, f)
	local St = H.state
	local gt = c.env.GameTooltip
	St[gt].tipLines = {}
	local fn = St[f].scripts and St[f].scripts.OnEnter
	ok(fn, "the control has a tooltip")
	fn(f)
	local out = {}
	for _, l in ipairs(St[gt].tipLines or {}) do out[#out + 1] = type(l) == "table" and tostring(l.text or l[1]) or tostring(l) end
	return table.concat(out, "\n")
end

test("r9 c: S17 Messages: every placeholder chip's tooltip gives an example of what it becomes", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = SPOT })
	w:advance(15)
	local W = a.W
	a.wide = true
	W.db.coach = true
	W.UI.WindowWide(true)
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	W.Driver.ShowScreen("messages")
	w:advance(1)
	local s = W.UI.drive.screens.messages
	local e = s.editor
	ok(e and #e.chips >= 9, "the chips")
	local byCode = {}
	for _, b in ipairs(e.chips) do byCode[b.code] = b end
	local tip = tipOf(a, byCode["{name}"])
	ok(tip:find("For example: Dan", 1, true), "{name}: " .. tip)
	tip = tipOf(a, byCode["{price}"])
	ok(tip:find("For example: ", 1, true), "{price}: " .. tip)
	tip = tipOf(a, byCode["{payto}"])
	ok(tip:find("For example: ", 1, true) and tip:find("trade the gold to", 1, true), "{payto}: " .. tip)
	tip = tipOf(a, byCode["{summoner}"])
	ok(tip:find("For example: Ana", 1, true) or tip:find("For example: Anita", 1, true), "{summoner}: " .. tip)
	tip = tipOf(a, byCode["{places}"])
	ok(tip:find("Every place your crew summons to", 1, true), "{places}: " .. tip)
	ok(tip:find("For example: " .. SPOT, 1, true), "{places}: the example names the crew's place: " .. tip)
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Lead (A's clipcheck): words in the driver pages that were cut short ("...")
---------------------------------------------------------------------------

-- a one-line label fits when its words, at the size drawn now, are no wider than its room
local function fitsRoom(W, fs)
	local room = fs:GetRight() - fs:GetLeft()
	local need = W.Theme.MeasureText(fs.wuberText or "", fs.wuberPx, fs.wuberWeight)
	return need <= room + 1, ("%q needs %.1f, has %.1f"):format(fs.wuberText or "", need, room)
end

test("r9 c: nothing cut short: the status row's fare, a checklist line with no Fix button, the heatmap's sub (folded and unfolded)", function()
	for _, wide in ipairs({ false, true }) do
		local w = T.newWorld()
		local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
		w:advance(15)
		local W = a.W
		W.Drive.Shards = function() return 10 end
		a.wide = wide or nil
		if W.UI.WindowWide then W.UI.WindowWide(wide) end
		T.openDrive(a)
		W.UI.ShowDrive("console")
		w:advance(2)
		W.Driver.RefreshNow()
		w:advance(1)
		local v = W.Driver.ui.console
		ok(v.fare.text.wuberText:find("to Orgrimmar", 1, true), "the fare names the place: " .. tostring(v.fare.text.wuberText))
		ok(fitsRoom(W, v.fare.text))
		W.Driver.ShowScreen("earnings")
		w:advance(2)
		local hm = W.UI.drive.screens.earnings.heat
		ok(fitsRoom(W, hm.sub))
		T.clean(w)
	end
	local w, a, W = raidConsole(false)
	local v = W.Driver.ui.console
	local seen = false
	for _, l in ipairs(v.ready.lines) do
		if l:IsShown() and not l.fix:IsShown() and (l.text.wuberText or ""):find("Pick who summons", 1, true) then
			seen = true
			ok(l.text.wuberWrapped or fitsRoom(W, l.text))
		end
	end
	ok(seen, "the 'Pick who summons' line")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Review fixes (round 9): the checklist while raid summons run, the side pane's whisper word, the
-- fare's arrow, the summoner strip for a non-runner, one spelling for a chip's count
---------------------------------------------------------------------------

test("r9 c review: raid summons running: the checklist keeps 'You need lead or assist' (only that); hides when there is nothing", function()
	local w, a, W, DR = raidConsole(false)
	local D = W.Driver
	local v = D.ui.console
	DR.IsOpen = function() return true end
	DR.CanRunRaid = function() return false, "You need lead or assist" end
	D.RefreshNow()
	w:advance(1)
	ok(T.H.visible(v.ready), "the checklist stays while it can't run")
	local shown = {}
	for _, l in ipairs(v.ready.lines) do if l:IsShown() then shown[#shown + 1] = l.text.wuberText end end
	eq(#shown, 1, "one line: " .. table.concat(shown, " | "))
	eq(shown[1], "You need lead or assist", "the lead/assist line")
	DR.CanRunRaid = function() return true end
	D.RefreshNow()
	w:advance(1)
	ok(not v.ready:IsShown(), "able to run: hidden while running")
	T.clean(w)
end)

test("r9 c review: unfolded, open, nobody waiting: the side pane gives the whisper word and the app", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = SPOT })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Shards = function() return 10 end
	a.wide = true
	W.db.coach = true
	W.UI.WindowWide(true)
	T.openDrive(a)
	W.UI.ShowDrive("console")
	DR.IsOpen = function() return true end
	DR.IsPaused = function() return false end
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	ok(W.Driver.Wide("console"), "unfolded")
	local word = W.Driver.WhisperWord()
	ok(word and word ~= "", "a whisper word: " .. tostring(word))
	ok(hasText(a, "Whisper word: " .. word .. " · or the Wuber app"), "the left card says how to ask: " .. table.concat(vis(a), " | "))
	T.clean(w)
end)

test("r9 c review: a click by the fare's arrow opens the price sheet (the fare is above the take's frame)", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:advance(15)
	local W = a.W
	W.Drive.Shards = function() return 10 end
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	local v = W.Driver.ui.console
	local fl, fr = v.fare:GetLeft(), v.fare:GetRight()
	local fb, ft = v.fare:GetBottom(), v.fare:GetTop()
	ok(fr > v.today:GetLeft(), "the fare's room reaches under the take's frame (that is the case here)")
	local sc = v.fare:GetEffectiveScale() -- (GetLeft and the rest are in the fare's own scale; the mouse is in screen pixels)
	local f = a:frameAt((fr - 2) * sc, (fb + ft) / 2 * sc)
	ok(f == v.fare, "by the arrow: the fare takes the click, not the take (" .. tostring(f and f:GetName()) .. ")")
	T.clean(w)
end)

test("r9 c review: a helper on the raid page still sees 'Nobody summons yet' (the checklist's Pick line is the runner's)", function()
	local w, a, W, DR = raidConsole(false)
	local D = W.Driver
	local v = D.ui.console
	D.Role = function() return "helper" end
	DR.Readiness = function() return { { ok = false, text = "Something else to put right" } } end
	D.RefreshNow()
	w:advance(1)
	ok(T.H.visible(v.ready), "a checklist shows (another line)")
	ok(not hasText(a, "Pick who summons"), "no Pick line for a helper")
	ok(hasText(a, "Nobody summons yet"), "so the strip says it: " .. table.concat(vis(a), " | "))
	T.clean(w)
end)

test("r9 c review: a summoner chip's count is spelled the same folded and unfolded (D.ChipCount)", function()
	local w, a, W = raidConsole(false)
	local D = W.Driver
	ok(type(D.ChipCount) == "function", "one place for the words")
	eq((D.ChipCount({ role = "lock", app = false, shards = 7 })), "no Wuber", "no app")
	eq((D.ChipCount({ role = "lock", shards = 10 })), "10 shards", "shards")
	eq(select(2, D.ChipCount({ role = "lock", shards = 0 })), "red", "none left: red")
	eq((D.ChipCount({ role = "ride" })), "", "a clicker: nothing")
	T.clean(w)
end)
