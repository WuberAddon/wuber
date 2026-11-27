local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

test("r47 e3: audit C27r-6: the empty Home's ring pulse runs again after a search is cleared", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768, saved = { Wuber = { coach = false, openMapHint = true } } })
	w:advance(15)
	local W = r.W
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Show("home")
	w:advance(3)
	local e = W.UI.state.screens.home.empty
	ok(H.visible(e) and H.visible(e.disc), "control: the empty state and its disc show")
	ok(e.pulse.running, "control: the pulse rings run on the fresh empty Home")
	W.UI.SetSearch("Gadgetzan")
	w:advance(2)
	ok(not H.visible(e.disc) or not e.pulse.running, "(search: bounty layout, disc hidden or pulse stopped)")
	W.UI.SetSearch("")
	w:advance(3)
	ok(H.visible(e.disc), "the disc is back after clearing the search")
	ok(e.pulse.running, "the disc is back on the empty Home but its pulse rings never restarted (the player sees a still disc)")
	T.clean(w)
end)
