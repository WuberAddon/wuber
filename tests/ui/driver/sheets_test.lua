-- Tests of UI.Driver.Sheets (round 13, agent B: Google's in-game screenshot findings). Loaded by
-- tests/run.lua with its helper table T. The end-of-shift card: its sums agree with the fair split
-- under it (the split shares the whole crew's takings, so the headline is that total).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function plain(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function driver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	return w, a, W
end

test("ui.driver.sheets: I11 the shift card's headline is the crew's takings the split shares; its words add up", function()
	local w, a, W = driver()
	local D = W.Driver
	local me = W.myKey
	-- 7 rides paid to me (3g 10s), 2 to my crew (1g): the split shares all 4g 10s
	local rows = { { key = me, name = T.ANITA, casts = 5, clicks = 0, share = 21000 },
		{ key = "vex shade", name = "Vex Shade", casts = 2, clicks = 1, share = 12000 },
		{ key = "nyla dusk", name = "Nyla Dusk", casts = 0, clicks = 8, share = 8000 } }
	D.lastShift = { rides = 7, copper = 31000, tips = 0, open = 7200, crewRides = 2, crewCopper = 10000, at = 1,
		cut = { rows = rows, rule = "clicks", pct = 40 } }
	ok(D.ShowSheet("shift"), "the card opens")
	w:advance(1)
	local s = W.UI.drive.screens.shift
	local total = 0
	for _, r in ipairs(rows) do total = total + r.share end
	eq(plain(s.gold.wuberText), plain(W.Money(total)), "the headline is what the split shares (" .. W.Money(total) .. ")")
	local sub = plain(s.goldSub.wuberText)
	-- (word rule) the crew's takings left this line: they are in the Rides tile ("2 crew")
	ok(not sub:find("your crew took", 1, true), "the crew's takings are in the Rides tile, not this line: " .. sub)
	ok(not sub:find("to your crew", 1, true), "never 'to your crew' (it read as their share): " .. sub)
	ok(sub:find("· 2g an hour", 1, true), "the hourly rate is the whole takings' (4g 10s in 2 h, not 3g 10s): " .. sub)
	eq(plain(s.tiles[1].value.wuberText), "9", "9 rides")
	eq(plain(s.tiles[1].sub.wuberText), "7 yours · 2 crew", "7 + 2")
	-- design 2: the phone is shorter (tab bar), so the card may show two rows and lead the rule with "+1 more in Earnings."
	local rule = plain(s.split and s.split.rule.wuberText):gsub("^%+%d+ more in Earnings%. ", "")
	eq(rule, "Casters 40%, clickers 60%.", "the rule names both parts (short; the long sentence is the tooltip of Fair split)")
	ok(not rule:find("the rest", 1, true), "no 'the rest' meaning two things")
	ok(plain(s.goldSub.wuberText):find("^this shift"), "with a crew the line is just 'this shift': " .. plain(s.goldSub.wuberText))
	-- alone: as before
	D.lastShift = { rides = 3, copper = 15000, tips = 0, open = 3600, crewRides = 0, crewCopper = 0, at = 2 }
	s.update()
	eq(plain(s.gold.wuberText), plain(W.Money(15000)), "alone: my takings")
	ok(not plain(s.goldSub.wuberText):find("crew", 1, true), "alone: no crew words")
	ok(plain(s.goldSub.wuberText):find("^this shift"), "alone: this shift")
	T.clean(w)
end)

test("ui.driver.sheets: review 13, the rule line says what the split did when nobody clicked or cast", function()
	local w, a, W = driver()
	local D, DR = W.Driver, W.Drive
	local me = W.myKey
	-- nobody clicked: CutSplit gives the casters all of it, so the line must not say "clickers 60%"
	local rows = { { key = me, name = T.ANITA, casts = 3, clicks = 0, share = 9000 },
		{ key = "vex shade", name = "Vex Shade", casts = 2, clicks = 0, share = 6000 } }
	local want = DR.CutSplit(15000, { [me] = 3, ["vex shade"] = 2 }, {}, "clicks", 40, me)
	eq(want[me] + want["vex shade"], 15000, "the split gives the casters it all")
	D.lastShift = { rides = 5, copper = 9000, tips = 0, open = 3600, crewRides = 2, crewCopper = 6000, at = 1,
		cut = { rows = rows, rule = "clicks", pct = 40 } }
	ok(D.ShowSheet("shift"), "the card opens")
	w:advance(1)
	local s = W.UI.drive.screens.shift
	local rule = plain(s.split and s.split.rule.wuberText)
	eq(rule, "Nobody clicked, so casters share it all by casts, in whole silver; any silver left goes to the runner.", "nobody clicked")
	ok(not rule:find("60%", 1, true), "no clickers' 60%: " .. rule)
	-- the words alone, for the other cases
	local function r(casts, clicks) return { { key = me, casts = casts, clicks = clicks } } end
	eq(D.CutRuleText("clicks", 40, r(0, 4)), "Nobody cast, so clickers share it all by clicks, in whole silver; any silver left goes to the runner.", "nobody cast")
	eq(D.CutRuleText("clicks", 40, r(0, 0)), "Nobody cast or clicked, so it all goes to the runner.", "nothing at all")
	eq(D.CutRuleText("equal", 40, r(0, 0)), "Nobody cast or clicked, so it all goes to the runner.", "equal, nothing at all")
	eq(D.CutRuleText("clicks", 40, r(2, 3)), "Casters share 40% by casts, clickers 60% by clicks, in whole silver; any silver left goes to the runner.", "both: as before")
	eq(D.CutRuleText("clicks", 40), "Casters share 40% by casts, clickers 60% by clicks, in whole silver; any silver left goes to the runner.", "no rows: the rule as set")
	T.clean(w)
end)

-- (BRIEF20 B8) the shift card clears the driver status strip (the real client drew its top edge over the strip)
test("ui.driver.sheets: B8 the shift card's top sits below the status strip, however many rows", function()
	local w, a, W = driver()
	local D = W.Driver
	local me = W.myKey
	local rows = { { key = me, name = T.ANITA, casts = 7, clicks = 2, share = 18200 },
		{ key = "vex", name = "Vex", casts = 2, clicks = 7, share = 15400 },
		{ key = "nyla", name = "Nyla", casts = 0, clicks = 9, share = 14400 },
		{ key = "a", name = "Ayla", casts = 1, clicks = 1, share = 100 },
		{ key = "b", name = "Bram", casts = 1, clicks = 1, share = 100 },
		{ key = "c", name = "Cora", casts = 1, clicks = 1, share = 100 } }
	for _, n in ipairs({ 3, 6 }) do
		local use = {}
		for i = 1, n do use[i] = rows[i] end
		D.lastShift = { rides = 7, copper = 40000, tips = 300, open = 7200, crewRides = 2, crewCopper = 10000, at = n,
			cut = { rows = use, rule = "clicks", pct = 40 } }
		ok(D.ShowSheet("shift"), "opens")
		w:advance(1)
		local s = W.UI.drive.screens.shift
		local strip = D.ui.console.statusBox
		local card = s.frame.card
		ok(card:GetTop() <= strip:GetBottom() - 2, n .. " rows: the card's top " .. tostring(card:GetTop()) .. " is below the strip's bottom " .. tostring(strip:GetBottom()))
		local lastShown
		for _, l in ipairs(s.split.lines) do if l.name:IsShown() then lastShown = l end end
		ok(lastShown and lastShown.name:GetBottom() >= card:GetBottom(), n .. " rows: the rows stay inside the card")
		s.frame:Close(true)
	end
	T.clean(w)
end)

test("ui.driver.sheets: B8 every split row is one font size", function()
	local w, a, W = driver()
	local D = W.Driver
	D.lastShift = { rides = 7, copper = 40000, tips = 0, open = 7200, crewRides = 2, crewCopper = 10000, at = 1,
		cut = { rows = { { key = W.myKey, name = T.ANITA, casts = 7, clicks = 2, share = 18200 },
			{ key = "vex", name = "Vex Shade", casts = 12, clicks = 17, share = 154000 },
			{ key = "n", name = "Nyla", casts = 0, clicks = 9, share = 14400 } }, rule = "clicks", pct = 40 } }
	ok(D.ShowSheet("shift"), "opens")
	w:advance(1)
	local s = W.UI.drive.screens.shift
	local px = s.split.lines[1].name.wuberPx
	for i, l in ipairs(s.split.lines) do
		eq(l.name.wuberPx, px, "row " .. i .. " name size")
		eq(l.what.wuberPx, px, "row " .. i .. " money size")
	end
	T.clean(w)
end)

test("ui.driver.sheets: E3b-08 share pill and Nice never overlap in or out of combat", function()
	local w, a, W = driver()
	local D = W.Driver
	w:addBot("Vex Shade", { spot = "Orgrimmar" })
	w:group({ T.ANITA, "Vex Shade" })
	w:advance(1)
	D.lastShift = { rides = 5, copper = 20000, tips = 0, open = 3600, crewRides = 2, crewCopper = 10000, at = 1,
		cut = { rows = {
			{ key = W.myKey, name = T.ANITA, casts = 3, clicks = 0, share = 18000 },
			{ key = "vex shade", name = "Vex Shade", casts = 0, clicks = 2, share = 12000 },
		}, rule = "clicks", pct = 40 } }
	ok(D.ShowSheet("shift"), "the card opens out of combat")
	w:advance(1)
	local s = W.UI.drive.screens.shift
	local p = s.split and s.split.post
	ok(p and p:IsShown() and s.done:IsShown(), "both share pill and Nice show in a group")
	eq(plain(p.label:GetText()), "Post to party", "out of combat label")
	ok(p:GetRight() <= s.done:GetLeft() - 2, "out of combat: share pill (" .. tostring(p:GetRight()) .. ") clears Nice (" .. tostring(s.done:GetLeft()) .. ")")
	-- enter combat while the card is open: the pill switches to "Share after combat" without overlapping Nice
	w:enterCombat(a)
	w:advance(1)
	eq(plain(p.label:GetText()), "Share after combat", "in combat label is not cut or shortened")
	ok(p:GetRight() <= s.done:GetLeft() - 2, "in combat (while open): share pill (" .. tostring(p:GetRight()) .. ") clears Nice (" .. tostring(s.done:GetLeft()) .. ")")
	ok(not a.env.WuberShareButton:IsShown(), "secure share overlay stays hidden in combat")
	-- reopen while already in combat
	s.frame:Close(true)
	ok(D.ShowSheet("shift"), "the card reopens in combat")
	w:advance(1)
	eq(plain(p.label:GetText()), "Share after combat", "reopened in combat label")
	ok(p:GetRight() <= s.done:GetLeft() - 2, "reopened in combat: share pill (" .. tostring(p:GetRight()) .. ") clears Nice (" .. tostring(s.done:GetLeft()) .. ")")
	w:leaveCombat(a)
	w:advance(1)
	eq(plain(p.label:GetText()), "Post to party", "back out of combat label")
	ok(p:GetRight() <= s.done:GetLeft() - 2, "after combat: share pill (" .. tostring(p:GetRight()) .. ") clears Nice (" .. tostring(s.done:GetLeft()) .. ")")
	T.clean(w)
end)
