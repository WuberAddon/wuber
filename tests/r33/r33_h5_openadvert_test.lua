local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- Round 33, group h5 (AUD-130, AUD-131): a non-Warlock runner with nobody to summon clicks Open. The shop
-- refuses to open, so no public advert may be armed (130), and a post that did go is always recorded
-- for the 15-minute wait (131).

local function setup()
	local w = T.newWorld()
	local m = w:addClient("Mia Cast", { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)
	m.W.Drive.SetRunner(true)
	m.W.Char().wizard = true
	m.W.UI.Toggle(true) w:advance(2.5)
	m:clickText("Drive") w:advance(1.5)
	return w, m
end

test("r33 h5 AUD-130: Open with nobody to summon arms no public advert", function()
	local w, m = setup()
	local D = m.W.Driver
	eq(D.Role(), "driver", "control: a runner counts as a driver")
	local pill = D.ui and D.ui.console and D.ui.console.open
	ok(pill and H.visible(pill), "control: the Open pill is on screen")
	eq(D.AdvertTarget("go"), nil, "no secure advert over Open while opening would be refused")
	local before = #(w.chatPosts or {})
	m:clickOn(pill) w:advance(3)
	eq(#(w.chatPosts or {}) - before, 0, "no public advert went to chat")
	T.clean(w)
end)

test("r33 h5 AUD-131: a posted advert is recorded for the cooldown even when the open is refused", function()
	local w, m = setup()
	local D = m.W.Driver
	local got = {}
	m.W.AdvertPosted = function(plan) got[#got + 1] = plan end
	local plan = { channel = "1. General", text = "Wuber" }
	D.AdvertClicked("go", plan)
	eq(#got, 1, "AdvertPosted called once for the line that went out")
	D.AdvertClicked("go", nil)
	eq(#got, 1, "nothing recorded when no line went")
	T.clean(w)
end)
