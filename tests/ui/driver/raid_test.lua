-- Tests of UI.Driver.Raid (the raid summons console). Loaded by tests/run.lua with its helper table T.
-- Round 17 (BRIEF17 S6): the folded (narrow) raid page says when raiders or "Not here" are below
-- the list's edge ("+N more below", "Not here (N) below"), and a tap scrolls to them.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local SPOT = "Undercity"
local NAMES = { "Dan Rider", "Gus Hill", "Ivy Moss", "Jo King", "Kim Lane", "Lou Park" }

test("ui.driver.raid: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Driver.Raid", "tests/ui/driver/raid_test.lua", {
		["D.RaidSummoners"] = "function", ["D.ClassColour"] = "function", ["D.DrawRaidSide"] = "function",
		["D.FOLD.raid"] = "table", ["Mod.drawRaid"] = "function", ["Mod.hideRaid"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Driver.Raid\")")
	T.clean(w)
end)

-- Anita runs raid summons (folded unless wide), n raiders queued, two raid members not here
local function raidPage(n, wide)
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
	DR.Role = function() return "driver" end
	DR.IsOpen = function() return true end
	DR.CanRunRaid = function() return true end
	DR.RaidQueue = function()
		local q = {}
		for i = 1, n do q[i] = { name = NAMES[i], asked = a.env.GetTime() - 10 * i, state = "queued", tries = 0 } end
		return q
	end
	DR.NotHere = function() return { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" }, "Hal Stone" } end
	W.Driver.RefreshNow()
	w:advance(1)
	return w, a, W
end

-- how many of these frames lie wholly inside the console's list (the scroll's clip)
local function inside(v, f)
	local vt, vb = v.scroll:GetTop(), v.scroll:GetBottom()
	local ft, fb = f:GetTop(), f:GetBottom()
	return H.visible(f) and ft and fb and ft <= vt + 1 and fb >= vb - 1
end

-- raider rows that reach past the list's bottom edge
local function rowsBelow(v, n)
	local hidden, vb = 0, v.scroll:GetBottom()
	for i = 1, n do if v.rows[i]:GetBottom() < vb - 1 then hidden = hidden + 1 end end
	return hidden
end

test("ui.driver.raid: S6 folded: raiders below the edge show '+N more below'; a tap scrolls; then 'Not here (N) below'", function()
	local w, a, W = raidPage(6)
	local v = W.Driver.ui.console
	local R = v.raid
	local hidden = rowsBelow(v, 6)
	ok(hidden > 0, "the folded list can't show six raiders at once")
	ok(R.cue and H.visible(R.cue), "a cue shows")
	ok(R.cue.label.wuberText:find("^%+%d+ more below · Not here %(2%)$"), "it counts the raiders below and names Not here: " .. R.cue.label.wuberText)
	local cb, ct = R.cue:GetBottom(), R.cue:GetTop()
	for i = 1, 6 do
		local r = v.rows[i]
		if H.visible(r) and r:GetAlpha() > 0 then
			ok(r:GetBottom() >= ct or r:GetTop() <= cb, "no drawn row sits under the pill (row " .. i .. ")")
		end
	end
	ok(inside(v, R.cue), "the cue sits inside the list")
	local faded, shown = 0, 0
	for i = 1, 6 do
		local r = v.rows[i]
		if H.visible(r) then
			if r:GetAlpha() == 0 then
				faded = faded + 1
				ok(not r:IsMouseEnabled(), "a row faded under the cue takes no mouse (row " .. i .. ")")
				if r.more then ok(not r.more:IsMouseEnabled(), "nor its menu button (row " .. i .. ")") end
			else
				shown = shown + 1
				ok(r:IsMouseEnabled(), "a drawn row takes the mouse (row " .. i .. ")")
			end
		end
	end
	ok(faded > 0 and shown > 0, "both kinds seen")
	local bad = dofile(T.dir .. "/lib/listfade.lua")(H)(a, "raid folded")
	eq(#bad, 0, "no hard-cut rows, no cut labels: " .. table.concat(bad, "; "))
	-- tap it until every raider is in view
	for _ = 1, 8 do
		if rowsBelow(v, 6) == 0 then break end
		a:clickOn(R.cue)
		w:advance(1)
	end
	for i = 1, 6 do
		eq(v.rows[i]:GetAlpha(), 1, "row " .. i .. " drawn once in view")
		ok(v.rows[i]:IsMouseEnabled(), "row " .. i .. " takes the mouse again")
	end
	eq(rowsBelow(v, 6), 0, "every raider in view after the taps")
	-- (HUNT-145) a header under the pill's strip counts as below: the cue says so until a tap brings it up
	if not inside(v, R.nhHead) or H.visible(R.cue) then
		ok(H.visible(R.cue), "Not here still below: the cue says so")
		eq(R.cue.label.wuberText, "Not here (2) below")
		a:clickOn(R.cue)
		w:advance(1)
	end
	ok(inside(v, R.nhHead), "Not here (2) is in view")
	eq(R.nhHead.label.wuberText, "Not here (2)")
	ok(not H.visible(R.cue), "nothing below: no cue")
	-- scrolled back up: the cue is back
	v.scroll:ScrollTo(0, true)
	w:advance(1)
	ok(H.visible(R.cue), "back at the top: the cue again")
	T.clean(w)
end)

test("ui.driver.raid: S6 folded with one raider: Not here in view, no cue; unfolded: no cue", function()
	local w, a, W = raidPage(1)
	local v = W.Driver.ui.console
	local R = v.raid
	ok(inside(v, v.rows[1]), "the raider shows")
	ok(inside(v, R.nhHead), "Not here (2) shows: " .. tostring(R.nhHead.label.wuberText))
	ok(not (R.cue and H.visible(R.cue)), "no cue")
	T.clean(w)
	w, a, W = raidPage(6, true)
	R = W.Driver.ui.console.raid
	ok(W.Driver.Wide("raid"), "unfolded")
	ok(not (R and R.cue and H.visible(R.cue)), "unfolded: the side pane lists them all, no cue")
	T.clean(w)
end)

test("ui.driver.raid: F1 Not here with nobody away says everyone is here while a raid console runs, 'Join a raid' only when idle", function()
	local w, a, W = raidPage(2, false)
	local DR = W.Drive
	DR.NotHere = function() return {} end
	DR.InRaid = function() return false end
	local v = W.Driver.ui.console
	v.raid.open = true
	W.Driver.RefreshNow()
	w:advance(1)
	eq(v.raid.nhMore.wuberText, "Nobody to wait for", "console open but not in a raid")
	DR.InRaid = function() return true end
	W.Driver.RefreshNow()
	w:advance(1)
	eq(v.raid.nhMore.wuberText, "Everyone in your raid is here", "really in a raid")
	DR.InRaid = function() return false end
	DR.RaidQueue = function() return {} end
	DR.IsOpen = function() return false end
	W.Driver.RefreshNow()
	w:advance(1)
	eq(v.raid.nhMore.wuberText, "Join a raid to see who isn't here", "idle, no raid")
	T.clean(w)
end)

test("ui.driver.raid: E1-13 narrow empty card wraps sub text without cutting or overlapping Not here", function()
	local w, a, W = raidPage(0, false)
	local v = W.Driver.ui.console
	local R = v.raid
	ok(H.visible(R.empty), "empty card shows when nobody is waiting")
	eq(R.empty.sub.wuberText, "Raiders type 123 in raid chat, or tap Request a summon", "full sub text kept")
	ok(not R.empty.sub:IsTruncated(), "sub text is not truncated")
	ok(R.empty.sub:GetBottom() >= R.empty:GetBottom() - 1, "wrapped sub text stays inside empty card")
	ok(R.empty:GetBottom() >= R.nhHead:GetTop(), "empty card does not overlap Not here header")
	T.clean(w)
end)
