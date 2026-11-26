local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function login(w)
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	w:advance(2)
	return c, c.W, c.W.Mod("UI.Tips")
end
local function open(w, W) W.UI.Toggle(true) w:advance(5) end

test("r27 AUD-10: after Show me the gold ring stays on screen when the player leaves the screen", function()
	local w = T.newWorld()
	local c, W, Mod = login(w)
	open(w, W)
	local card = Mod.Card()
	ok(H.visible(card), "the tip card shows")
	local target = W.Mod("UI.TipTexts").Target(Mod.state.current.id)
	ok(target and H.visible(target), "its target (Home search) shows")
	card.show:Click()
	w:advance(1)
	local ring = Mod.state.ring
	ok(ring and H.visible(ring), "control: the ring shows round the target after Show me")
	W.UI.Show("trips") -- the player goes to Trips within the 3 s
	w:advance(0.5)
	ok(not H.visible(target), "control: the old target is gone with its screen")
	ok(not H.visible(ring), "the gold ring still pulses over the Trips screen after its target went away")
	T.clean(w)
end)
