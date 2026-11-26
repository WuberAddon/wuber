-- Wuber 2.4 fix round 3, group L (stage B, surface 3): the login tip card takes its height from its text.
-- (Design 2, group E: the card is a sheet at the foot of the phone; "the card" below is its sheet card.)
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- about twice the longest real tip
local LONG = "Drivers can show a two-word passphrase, so you know you have got the right Warlock before you accept anything at all. "
	.. "Drivers can show a two-word passphrase, so you know you have got the right Warlock before you accept anything at all."
local REAL = "Tap World to see every driver on the whole map, with flight routes and boats."

local function rectOf(f) return { l = f:GetLeft(), r = f:GetRight(), t = f:GetTop(), b = f:GetBottom() } end

local function open(text)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	w:advance(2)
	local W = c.W
	W.Mod("UI.TipTexts").list = { { id = "long_one", text = text, driver = false, screen = "home" } }
	local Fold = W.UI and W.UI.Fold
	if Fold then Fold.Fits = function() return true end end
	W.UI.Toggle(true)
	w:advance(5)
	return w, c, W, W.Mod("UI.Tips")
end

local heightOfLong

test("v24 f3l: the tip card with twice the longest tip shows it whole, at full size, the card grown and inside the phone", function()
	local w, c, W, Mod = open(LONG)
	local host = Mod.Card()
	local card = host
	ok(H.visible(card), "the card shows")
	eq(card.text:GetText(), LONG, "the text is whole")
	ok(H.truncation(card.text, true) == nil, "the game does not cut it")
	local _, size = card.text:GetFont()
	ok(size and size >= 12, "no shrunk font: " .. tostring(size))
	local t, show, cr = rectOf(card.text), rectOf(card.show), rectOf(host.sheet.card)
	ok(t.b >= show.t - 0.5, "the text stays above the buttons: text bottom " .. t.b .. ", buttons top " .. show.t)
	ok(show.b >= cr.b - 0.5 and cr.t >= t.t, "the buttons and text are inside the card")
	heightOfLong = host.sheet.card:GetHeight()
	ok(heightOfLong > 243, "the card grew: " .. heightOfLong)
	local win = rectOf(c.env.WuberFrame)
	ok(cr.t <= win.t + 0.5 and cr.b >= win.b - 0.5, "inside the phone")
	T.clean(w)
end)

test("v24 f3l: a real tip's sheet is shorter than the long one (its height follows its text)", function()
	local w, _, _, Mod = open(REAL)
	local h = Mod.Card().sheet.card:GetHeight()
	ok(heightOfLong == nil or h < heightOfLong, "real " .. h .. " against long " .. tostring(heightOfLong))
	ok(h >= 44 + 19 + 12 + 134 - 0.5, "it holds its title block, a line of words and the foot: " .. h)
	T.clean(w)
end)
