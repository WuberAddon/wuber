local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- a crew member (not the captain) ticks a Warlock on the raid "Pick summoners" sheet: the ask is refused
-- ("Couldn't ask ..."), the refresh puts the switch back OFF with a quiet SetOn(false), but the click's own
-- slide to ON is still running in T.Tween and carries the knob to the ON side.
test("r47 g5: AUD-234 a refused tick on Pick summoners leaves the knob on the ON side of an OFF switch", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	local DR, D = W.Drive, W.Driver
	local FARRA, HAYLEY = "Farra Lock", "Hayley Lock"
	DR.RaidWarlocks = function()
		return { { key = W.Key(FARRA), name = FARRA, shards = 9, app = true }, { key = W.Key(HAYLEY), name = HAYLEY, shards = 9, app = true } }
	end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	D.ShowSheet("raidpick")
	w:advance(1)
	local sh = D.ui.sheets.raidpick
	ok(sh, "the Pick summoners sheet opened")
	local rows = {}
	for i = 1, 6 do
		local ok2, r = pcall(sh.rows.get, i)
		if ok2 and r and r.p and r.toggle then rows[#rows + 1] = r end
	end
	ok(#rows >= 2, "two Warlock rows are drawn, got " .. #rows)
	-- control: the captain ticks the first one: the ask goes out and the switch ends ON, knob on the ON side
	local t1 = rows[1].toggle
	a:click(t1)
	w:advance(1)
	eq(t1.on, true, "control: the ticked switch is on")
	eq(t1.pos, 1, "control: its knob is on the ON side")
	-- now the ask is refused (this window is only a member of another crew)
	DR.IsCaptain = function() return false end
	local t2 = rows[2].toggle
	a:click(t2)
	w:advance(1)
	eq(t2.on, false, "the refused switch is OFF (the toast says Couldn't ask)")
	eq(t2.pos, 0, "the player sees the knob of an OFF switch on the ON side (pos " .. tostring(t2.pos) .. ")")
	T.clean(w)
end)
