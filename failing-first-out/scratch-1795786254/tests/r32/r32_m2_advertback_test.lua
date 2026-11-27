local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H

-- Round 32, group M: HUNT-110. Going back to the Drive console from Customers (or Messages) must
-- lay the secure Advertise button over its pill at once, not a second later.

test("r32 m2: back from Customers, the secure Advertise button is over its pill at once", function()
	local w = T.newWorld()
	local d = T.driver(w, "Bob Stone")
	T.rider(w)
	T.settle(w)
	ok(T.HAVE_UI, "needs the UI")
	T.openDrive(d)
	w:advance(1.5)
	T.clickGo(d)
	w:advance(3)
	-- the first advert went out with Go; let the 15 minute wait pass so Advertise is allowed
	w:advance(16 * 60)
	w:advance(1.5)
	local btn = d.env.WuberAdvertButton
	ok(btn and H.visible(btn), "the Advertise button is over its pill before leaving the console")
	d.W.Driver.ShowScreen("customers")
	w:advance(1)
	d.W.Driver.ShowScreen("console")
	-- (design 2) the page slides away first: a secure overlay is laid when the travel ends, by the move's own end
	-- (not a second later at the tick). Frame by frame to the move's last frame, and not one frame more.
	ok(d.W.Driver.pageMoving, "the page is on its way out")
	ok(not H.visible(btn), "no Advertise button over a console that is still moving")
	local frames = 0
	while d.W.Driver.pageMoving and frames < 40 do
		w:advance(0.02)
		frames = frames + 1
	end
	ok(frames * 0.02 <= 0.32, "the travel takes the page time (0.28 s), not a second: " .. frames * 0.02)
	ok(H.visible(btn), "the Advertise button is shown the moment the page has left")
	ok((H.state[btn].attrs.macrotext or "") == "" and btn.sig ~= nil, "and it is placed over the pill")
	w:advance(1)
end)
