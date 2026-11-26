-- Fix round 2.4, group c (ING-12): the empty Home's ring pulse.
-- Where the quiet OpenMap line only fits once the round disc gives way, the disc is hidden, and the rings
-- (drawn inside the disc) with it. The pulse was then stopped and started again on every refresh: with each
-- letter typed in "Where to?" and about once a second while the page stood still. Rings nobody can see are
-- never started; when the disc is back (the line fits beside it, or is off) they run, started once.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function emptyHome(opts)
	local w = T.newWorld()
	opts = opts or {}
	opts.saved = { Wuber = { coach = false } }
	local r = T.rider(w, T.TESTCHAR, opts)
	w:advance(15)
	local W = r.W
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Show("home")
	w:advance(3)
	local s = W.UI.state.screens.home
	local e = s.empty
	local n = { starts = 0 }
	local real = e.pulse.Start
	e.pulse.Start = function(self, ...)
		n.starts = n.starts + 1
		return real(self, ...)
	end
	return w, W, s, e, n
end

-- types the word a letter at a time through the search box's own handler, a refresh after each
local function typeWord(w, s, word)
	for i = 1, #word do
		s.search.edit:SetText(word:sub(1, i))
		w:advance(0.6)
	end
end

test("fr c ING-12: the disc gave way to the OpenMap line: its hidden rings are not started again by a letter or a refresh", function()
	local w, _, s, e, n = emptyHome()
	ok(H.visible(e.mapHint), "this window shows the OpenMap line on the empty Home")
	ok(not H.visible(e.disc), "and the round disc gave way to it")
	eq(e.pulse.running, false, "rings nobody can see stand still")
	typeWord(w, s, "xqzwv")
	eq(n.starts, 0, "starts while five letters were typed")
	w:advance(30)
	eq(n.starts, 0, "starts while the page stood still for 30 s")
	eq(e.pulse.running, false, "still standing")
	T.clean(w)
end)

test("fr c ING-12: the disc is back (the OpenMap line off): the rings run, started once, and typing does not start them again", function()
	local w, W, s, e, n = emptyHome()
	W.db.openMapHint = true -- the line was dismissed: the disc has its room again
	W.UI.Refresh(true)
	w:advance(2)
	ok(H.visible(e.disc), "the disc shows")
	eq(e.pulse.running, true, "its rings run")
	eq(n.starts, 1, "started once, when the disc came back")
	typeWord(w, s, "xqzwv")
	w:advance(30)
	eq(n.starts, 1, "no start while typing or standing still")
	eq(e.pulse.running, true, "still running")
	ok(H.visible(e.disc), "the disc still shows")
	T.clean(w)
end)
