-- Wuber 2.4, the word rule on four more screens: the shift card, Earnings, Help, one Settings tooltip. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function plain(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- how many visible texts on the client's screen contain s
local function count(a, s)
	local n = 0
	for _, t in ipairs(a:visibleTexts()) do
		if plain(t):find(s, 1, true) then n = n + 1 end
	end
	return n
end

-- a tooltip part: the text, or what its function says
local function part(x, frame)
	if type(x) == "function" then return x(frame) end
	return x
end

local LONG = "Casters share 40% by casts, clickers 60% by clicks, in whole silver; any silver left goes to the runner."

local function shiftCard(last)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	local D = W.Driver
	last.at = 1
	D.lastShift = last
	ok(D.ShowSheet("shift"), "the card opens")
	w:advance(1)
	return w, a, W, D, W.UI.drive.screens.shift
end

local function crewShift(W)
	local rows = { { key = W.myKey, name = T.ANITA, casts = 5, clicks = 0, share = 21000 },
		{ key = "vex shade", name = "Vex Shade", casts = 2, clicks = 1, share = 12000 },
		{ key = "nyla dusk", name = "Nyla Dusk", casts = 0, clicks = 8, share = 8000 } }
	return { rides = 7, copper = 31000, tips = 300, open = 7200, crewRides = 2, crewCopper = 10000,
		cut = { rows = rows, rule = "clicks", pct = 40 } }
end

test("v24 words c: 1 the shift card with a crew says 'this shift', '<n> yours · <m> crew', and the short rule", function()
	local w, a, W, D, s = shiftCard({ rides = 7, copper = 31000, tips = 300, open = 7200, crewRides = 2, crewCopper = 10000,
		cut = { rule = "clicks", pct = 40, rows = {
			{ key = "me", name = T.ANITA, casts = 5, clicks = 0, share = 21000 },
			{ key = "vex shade", name = "Vex Shade", casts = 2, clicks = 1, share = 12000 },
			{ key = "nyla dusk", name = "Nyla Dusk", casts = 0, clicks = 8, share = 8000 } } } })
	local sub = plain(s.goldSub.wuberText)
	ok(sub:find("^this shift · 2g an hour$"), "the line under the gold: " .. sub)
	ok(not sub:find("taken this shift", 1, true), "no 'taken this shift'")
	ok(not sub:find("your crew took", 1, true), "no 'your crew took'")
	ok(not sub:find("crew", 1, true), "no crew word at all")
	eq(plain(s.tiles[1].sub.wuberText), "7 yours · 2 crew", "the Rides tile")
	for _, gone in ipairs({ "on top of fares", "that hour", "open, not paused", "no tips this time", "your crew's", "never moves gold" }) do
		eq(count(a, gone), 0, "no visible text with '" .. gone .. "'")
	end
	local rule = plain(s.split.rule.wuberText):gsub("^%+%d+ more in Earnings%. ", "")
	eq(rule, "Casters 40%, clickers 60%.", "the rule line")
	eq(plain(s.split.note.wuberText), "Pay your helpers by trade.", "the note")
	local hit = s.split.headHit
	ok(hit and hit.wuberTip, "the heading has a tooltip")
	eq(plain(s.split.head.wuberText), "Fair split", "the heading")
	eq(hit.wuberTip.title, "Fair split", "its title")
	eq(part(hit.wuberTip.text, hit), LONG, "its body is the long sentence")
	ok(part(hit.wuberTip.text, hit):find("Casters share 40% by casts", 1, true) == 1, "and starts as it did")
	T.clean(w)
end)

test("v24 words c: 2 the shift card without a crew still says rider paid or riders paid", function()
	local w, a, W, D, s = shiftCard({ rides = 3, copper = 15000, tips = 0, open = 3600, crewRides = 0, crewCopper = 0 })
	eq(plain(s.tiles[1].sub.wuberText), "riders paid", "three riders paid")
	eq(plain(s.goldSub.wuberText):find("^this shift"), 1, "alone: this shift")
	D.lastShift = { rides = 1, copper = 5000, tips = 0, open = 3600, crewRides = 0, crewCopper = 0, at = 2 }
	s.update()
	eq(plain(s.tiles[1].sub.wuberText), "rider paid", "one rider paid")
	T.clean(w)
end)

test("v24 words c: 3 D.CutRuleText without the short argument is the old long sentence; equal is unchanged", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local D = a.W.Driver
	eq(D.CutRuleText("clicks", 40), LONG, "no argument: the long sentence")
	eq(D.CutRuleText("clicks", 40, nil, false), LONG, "false: the long sentence")
	eq(D.CutRuleText("clicks", 40, nil, true), "Casters 40%, clickers 60%.", "true: the short one")
	eq(D.CutRuleText("clicks", 25, nil, true), "Casters 25%, clickers 75%.", "the numbers follow the setting")
	local equal = "Everyone who cast or clicked gets the same, in whole silver; any silver left goes to the runner."
	eq(D.CutRuleText("equal", 40), equal, "equal: as before")
	eq(D.CutRuleText("equal", 40, nil, true), equal, "equal: the short argument changes nothing")
	T.clean(w)
end)

local function earnings(tot)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.Drive.LogTotals = function() return tot end
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("earnings")
	w:advance(2)
	return w, a, W, W.UI.drive.screens.earnings
end

test("v24 words c: 4 Earnings: 'an hour' line, short stats line with its tooltip, legend, heatmap", function()
	local w, a, W, e = earnings({ rides = 65, copper = 354000, tips = 29000, open = 1260, asks = 88 })
	local sub = plain(e.perSub:GetText())
	ok(sub:find("^an hour · "), "the line under the number starts 'an hour · ': " .. sub)
	ok(not sub:find("per open hour", 1, true), "no 'per open hour'")
	local stats = plain(e.stats:GetText())
	ok(not stats:find("tips)", 1, true), "the stats line has no tips: " .. stats)
	ok(not stats:find("buyers asked", 1, true), "nor buyers asked")
	ok(stats:find("^65 rides · "), "rides first: " .. stats)
	ok(stats:find(" open$"), "ends open: " .. stats)
	local tip = e.statsHit.wuberTip
	ok(tip, "the stats line has a tooltip")
	eq(plain(part(tip.title, e.statsHit)), stats, "its title is the short line")
	local body = plain(part(tip.text, e.statsHit))
	ok(body:find("88 buyers asked", 1, true), "the body has the buyers asked: " .. body)
	ok(body:find(" tips", 1, true), "and the tips: " .. body)
	-- no tips: only the buyers
	W.Drive.LogTotals = function() return { rides = 1, copper = 5000, tips = 0, open = 60, asks = 1 } end
	e.update()
	body = plain(part(e.statsHit.wuberTip.text, e.statsHit))
	eq(body, "1 buyer asked", "no tips: no tips part")
	-- below the target
	W.Drive.LogTotals = function() return { rides = 1, copper = 100, tips = 0, open = 600, asks = 0 } end
	e.update()
	ok(plain(e.perSub:GetText()):find("^an hour · target "), "under target: 'an hour · target <x>': " .. e.perSub:GetText())
	eq(plain(e.perSub:GetText()):find("your target", 1, true), nil, "no 'your target'")
	-- the legend
	eq(plain(e.chart.legend:GetText()), "Gold an hour, by time of day", "the legend")
	local lt = e.chart.legendHit.wuberTip
	ok(lt, "the legend has a tooltip")
	eq(lt.title, "Gold an hour, by time of day", "its title")
	eq(lt.text, "Hollow: under 30 min open", "its body")
	eq(count(a, "hollow: under 30"), 0, "the rule is not on the screen")
	-- the heatmap
	eq(plain(e.heat.title:GetText()), "Best hours, last 7 days", "the heatmap title")
	eq(plain(e.heat.sub:GetText()), "tap a square", "its second line")
	eq(count(a, "peak hours"), 0, "no 'peak hours'")
	T.clean(w)
end)

test("v24 words c: 5 Help shows the eight new short cards, no title lines, no overlap", function()
	local NEW = {
		"Wuber is a radio network. Drivers call out; every Wuber on your realm hears them.",
		"It reaches every Wuber on your realm.",
		"Whispers are the backup, so a driver may show a few seconds late. A driver's price comes only from that driver's own character.",
		"More users, more drivers. Your list grows with every ride and favourite.",
		"Drivers: Wuber adds the [Wuber] tag to your advert for you. Other players' Wuber reads it.",
		"Each ruleset is its own world. You only see your own.",
		"World map: best with the free OpenMap addon.",
		"Nobody there? Wait a minute. Tap Ping drivers. Tap Tell me.",
	}
	local w = T.newWorld()
	local c = T.rider(w)
	T.settle(w)
	c.wide = true
	c.W.db.fold = { v = 1, pages = {}, narrow = false }
	local UI = c.W.UI
	UI.Toggle(true)
	w:advance(3)
	UI.OpenHelp("settings")
	w:advance(1)
	local help = UI.settings.help
	eq(#UI.HELP, 8, "eight entries")
	for i, e in ipairs(UI.HELP) do
		ok(type(e.icon) == "string" and e.icon ~= "", i .. ": an icon")
		eq(type(e.title), "string", i .. ": a title field")
		eq(e.text, NEW[i], i .. ": the text")
		eq(count(c, NEW[i]) >= 1, true, i .. ": on screen: " .. NEW[i])
	end
	eq(#help.cards, 8, "eight cards")
	for i = 1, 8 do
		for _, r in ipairs({ help.cards[i]:GetRegions() }) do
			if r.GetText and r:GetText() then
				ok(not plain(r:GetText()):find("^%d+%. "), "card " .. i .. ": no numbered title line: " .. plain(r:GetText()))
			end
		end
	end
	eq(help.nav, nil, "no contents list in wide Help")
	for i = 2, 8 do
		ok(help.cards[i]:GetTop() < help.cards[i - 1]:GetBottom() + 0.01, "card " .. i .. " starts below card " .. (i - 1))
	end
	T.clean(w)
end)

test("v24 words c: 6 Settings: the advert tooltip is the short one and none says GO ONLINE", function()
	local w = T.newWorld()
	local c = T.driver(w, T.BOB)
	T.settle(w)
	c.W.db.coach = true
	c.W.db.fold = { v = 1, pages = {}, narrow = true }
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings("driving")
	w:advance(1)
	local st = c.W.UI.settings
	local want = "Opening also posts one advert line in public chat. At most once every 15 minutes. Never in combat, never without your click. Change the words in Messages."
	local r = st.controls.advertOnline
	ok(r and r.wuberTip, "the control has a tooltip")
	eq(r.wuberTip.text, want, "the control's tooltip body")
	eq(r.row.wuberTip.text, want, "the row's tooltip body")
	local seen = 0
	local function check(f, what)
		if type(f) == "table" and type(f.wuberTip) == "table" then
			seen = seen + 1
			local tx = tostring(part(f.wuberTip.text, f)) .. " " .. tostring(part(f.wuberTip.title, f))
			ok(not tx:find("GO ONLINE", 1, true), what .. " says GO ONLINE")
		end
	end
	for i, row in ipairs(st.rows) do check(row, "row " .. i) check(row.button, "row " .. i .. " button") check(row.switch, "row " .. i .. " switch") end
	for k, ctl in pairs(st.controls) do check(ctl, "control " .. tostring(k)) end
	ok(seen > 40, "many tooltips checked: " .. seen)
	T.clean(w)
end)
