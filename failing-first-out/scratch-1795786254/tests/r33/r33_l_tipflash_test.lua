local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function login(w)
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	w:advance(2)
	return c, c.W, c.W.Mod("UI.Tips")
end
local function open(w, W) W.UI.Toggle(true) w:advance(5) end

test("r33 l AUD-26: a tip asked for 0.1 s after Close stays up", function()
	local w = T.newWorld()
	local c, W, Mod = login(w)
	open(w, W)
	local card = Mod.Card()
	ok(H.visible(card), "the tip card shows")
	card.close:Click()
	w:advance(1)
	ok(not H.visible(card), "control: Close hides it")
	-- control: asking again after the fade finished brings it back
	W.SlashCommand("tips") w:advance(1)
	ok(H.visible(card), "control: /wuber tips later shows the tip")
	card.close:Click()
	w:advance(0.1) -- still fading out
	W.SlashCommand("tips")
	w:advance(1)
	ok(H.visible(card), "/wuber tips 0.1 s after Close: the player asked for the tip and it vanishes at once")
	T.clean(w)
end)
