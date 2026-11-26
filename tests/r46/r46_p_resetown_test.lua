-- Round 46 p: HUNT-15 the Reset stats tooltip says the totals on Earnings come from the hour-by-hour log, which stays
-- (the toast and the counters' reset are unchanged); HUNT-66 the Crew card's "my account" offer is hidden while
-- Settings "Share notes with my own accounts" is off, and comes back when it is on.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function tipOf(c, f)
	local S = H.state
	local gt = c.env.GameTooltip
	S[gt].tipLines = {}
	local fn = S[f].scripts and S[f].scripts.OnEnter
	ok(fn, "the control has a tooltip")
	fn(f)
	local out = {}
	for _, l in ipairs(S[gt].tipLines or {}) do out[#out + 1] = type(l) == "table" and tostring(l.text or l[1]) or tostring(l) end
	return table.concat(out, "\n")
end

local function driver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	return w, a, a.W
end

test("r46 p: HUNT-15 Reset stats says the totals here come from the hour-by-hour log, which stays", function()
	local w, a, W = driver()
	T.openDrive(a)
	W.UI.ShowDrive("earnings")
	w:advance(1)
	local e = W.UI.drive.screens.earnings
	local tip = tipOf(a, e.reset)
	ok(tip:find("Sets the counters of /wuber drive stats and of this session back to zero (click twice). The totals here come from the hour-by-hour log, which stays.", 1, true), "the tooltip: " .. tip)
	ok(not tip:find("ride and gold counters", 1, true), "the old words are gone")
	local before = (e.tot or {}).copper
	-- the player scrolls down to the foot of Earnings
	ok(a:scrollIntoView(e.reset), "Reset stats scrolls into view")
	a:click(e.reset)
	a:click(e.reset)
	w:advance(1)
	eq((e.tot or {}).copper, before, "the totals from the log stay after a reset")
	T.clean(w)
end)

test("r46 p: HUNT-66 the Crew card offers 'my account' only while notes are shared with own accounts", function()
	local w, a, W = driver()
	local D, DR = W.Driver, W.Drive
	DR.Crew = function()
		return { { name = a.player.name, key = W.myKey, role = "lock", app = true, me = true, here = true },
			{ name = "Bea Jones", key = "bea jones", role = "lock", app = true, here = true } }
	end
	local on = true
	DR.BookShareOn = function() return on end
	T.openDrive(a)
	D.ShowScreen("crew")
	w:advance(1)
	local bea = D.ui.subs.crew.members.list[1]
	ok(bea.own and H.visible(bea.own) and H.visible(bea.ownLabel), "sharing on: the switch and 'my account' show")
	on = false
	D.RefreshNow()
	w:advance(1)
	ok(not H.visible(bea.own), "sharing off: the switch is hidden")
	ok(not H.visible(bea.ownLabel), "sharing off: 'my account' is hidden")
	on = true
	D.RefreshNow()
	w:advance(1)
	ok(H.visible(bea.own) and H.visible(bea.ownLabel), "sharing on again: both are back")
	T.clean(w)
end)
