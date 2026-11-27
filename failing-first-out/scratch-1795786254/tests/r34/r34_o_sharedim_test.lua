local T = ...
-- Round 34 group O, HUNT-83: the shift card reopened after a fight must not show Post to party dimmed.
local test, eq, ok = T.test, T.eq, T.ok
test("r34 o: the shift card's share pill is worded and lit again when the card is painted after a fight", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:addBot("Sly Fox", { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	local D = W.Driver
	W.UI.Toggle(true)
	w:advance(3)
	local pill = W.Theme.Pill(W.UI.GetTab("Ride") or UIParent, "Post to party", "violet", 92, 30)
	local line = "a line"
	W.UI.Share.Register(pill, function() return line end, { label = "Post to party" })
	w:group({ T.ANITA, "Sly Fox" })
	w:advance(1.5)
	W.UI.RefreshNow()
	w:enterCombat(d)
	w:advance(1.2)
	eq(pill.label:GetText(), "Share after combat", "worded for the fight")
	-- the fight ends while the card is closed: no refresh has run yet
	w:leaveCombat(d)
	eq(W.UI.Share.State(pill), "ok", "state is ok")
	local function stub() local f = {} setmetatable(f, { __index = function() return function() end end }) return f end
	local s = { split = { head = stub(), rule = stub(), note = stub(), post = pill, lines = { { name = stub(), what = stub() } } }, done = stub(), tiles = {}, sharedAt = nil }
	local sh = { body = pill:GetParent(), SetSheetHeight = function() end }
	D.lastShift = { at = 1, cut = { rows = { { name = "Fay", amount = 5 } }, rule = "x", pct = 10 } }
	local okp, err = xpcall(function() D.PaintSplit(s, sh) end, debug.traceback)
	ok(okp, tostring(err))
	eq(pill.label:GetText(), "Post to party", "plain words back")
	T.clean(w)
end)
