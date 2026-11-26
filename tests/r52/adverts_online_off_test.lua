local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- guard: switching "Post an advert when I go online" off while the Open overlay is already up must stop the advert:
-- the secure GO overlay was drawn for the setting as it stood then.

local function setup()
	local w = T.newWorld()
	local m = w:addClient("Wil Lock", { spot = "Orgrimmar", class = "WARLOCK" })
	T.settle(w)
	w:joinChannel(m, "Trade - City")
	w:advance(2)
	m.W.Char().wizard = true
	m.W.UI.Toggle(true) w:advance(2.5)
	m:clickText("Drive") w:advance(1.5)
	return w, m
end

local function posts(w, m)
	local n = 0
	for _, p in ipairs(w.chatPosts or {}) do if p.from == "Wil Lock" then n = n + 1 end end
	return n
end

-- guard: the Open overlay re-reads the setting in its own click, so a stale one cannot post (the overlay click handler's overlayTarget re-check in UI/Secure.lua, advertOn() in UI/Driver/State.lua)
test("adverts: control, advertOnline on, Open posts one advert", function()
	local w, m = setup()
	local go = m.env.WuberGoButton
	ok(go and H.visible(go), "control: the GO overlay is up")
	local before = posts(w, m)
	m:clickOn(m.W.Driver.ui.console.open) w:advance(3)
		eq(posts(w, m) - before, 1, "one advert")
	T.clean(w)
end)

-- guard: pins that a switched-off setting wins over an overlay drawn while it was on
test("adverts: advertOnline switched off with the GO overlay already up, tap Open posts nothing", function()
	local w, m = setup()
	local go = m.env.WuberGoButton
	ok(go and H.visible(go), "control: the GO overlay is up")
	m.W.db.advertOnline = false
	local before = posts(w, m)
	m:clickOn(m.W.Driver.ui.console.open) w:advance(3)
	eq(posts(w, m) - before, 0, "no advert with the setting off")
	T.clean(w)
end)
