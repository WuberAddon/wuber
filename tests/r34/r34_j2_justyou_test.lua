local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- HUNT-64: a player who is not a Warlock and has no crew is not shown the Warlock role or the
-- "Riders bring two friends" sentence on the Crew screen's Just you card.

local function card(isLock)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.IsOpen = function() return true end
	DR.IsWarlock = function() return isLock end
	DR.Crew = function() return { { name = a.player.name, key = W.myKey, role = isLock and "lock" or "helper", app = true, me = true, here = true } } end
	T.openDrive(a)
	W.Driver.ShowScreen("crew")
	w:advance(2)
	local row = W.Driver.ui.subs.crew.members.list[1]
	return w, row
end

test("r34 j2: a non-Warlock with no crew sees 'Clicks the portal', not the Warlock sentence", function()
	local w, row = card(false)
	eq(row.sub:GetText(), "Clicks the portal")
	T.clean(w)
end)

test("r34 j2: a Warlock with no crew still sees the Riders sentence", function()
	local w, row = card(true)
	eq(row.sub:GetText(), "Riders bring two friends to click the portal")
	T.clean(w)
end)
