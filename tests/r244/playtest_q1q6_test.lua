-- Q1: Simple mode shows ONE "My advert line" row (the rest of Messages and Customers stays Advanced).
-- Q6: the "Waiting for riders" pulse is one soft ring every 3 s.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function console(adv)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.SetAdvanced(adv)
	T.openDrive(a)
	if W.UI and W.UI.ShowDrive then W.UI.ShowDrive("console") end
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	return w, a, W, W.Driver.ui.console
end

local function vis(f) return f and H.visible(f) end

test("playtest Q1: Simple mode shows My advert line and not Messages or Customers", function()
	local w, a, W, v = console(false)
	ok(v.links.advert, "the advert row exists")
	ok(vis(v.links.advert), "Simple: My advert line shows")
	ok(not vis(v.links.messages), "Simple: Messages stays hidden")
	ok(not vis(v.links.customers), "Simple: Customers stays hidden")
	eq(v.links.advert.title:GetText(), "My advert line", "its words")
	T.clean(w)
end)

-- guard: Advanced keeps the whole Messages row and has no second advert row
test("playtest Q1: Advanced shows Messages and Customers, not the single advert row", function()
	local w, a, W, v = console(true)
	ok(vis(v.links.messages) and vis(v.links.customers), "Advanced: Messages and Customers")
	ok(not vis(v.links.advert), "Advanced: no extra advert row")
	T.clean(w)
end)

test("playtest Q1: clicking My advert line opens the advert editor, and Back leaves in Simple", function()
	local w, a, W, v = console(false)
	a:clickOn(v.links.advert)
	w:advance(1)
	eq(W.Driver.CurrentScreen(), "messages", "the Messages screen is open")
	local s = W.Driver.ui.subs.messages
	eq(s.kind, "advert", "on the advert line")
	ok(s.editor and s.editor.field, "the editor is there")
	ok(s.onBack() == false, "Back in Simple leaves the screen, it does not list the other messages")
	T.clean(w)
end)

-- guard: Advanced Back still shows the list of messages
test("playtest Q1: in Advanced, Back from an editor shows the list", function()
	local w, a, W, v = console(true)
	W.Driver.ShowScreen("messages", "advert")
	w:advance(1)
	local s = W.Driver.ui.subs.messages
	ok(s.onBack() == true, "Back shows the list")
	T.clean(w)
end)

test("playtest Q6: the Waiting for riders pulse is one soft ring every 3 seconds", function()
	local w, a, W, v = console(false)
	local p = v.empty.pulse
	eq(p.period, 3, "one cycle every 3 s")
	eq(#p.rings, 1, "one ring")
	ok(p.alpha <= 0.4, "a softer start than 0.5: " .. tostring(p.alpha))
	T.clean(w)
end)
