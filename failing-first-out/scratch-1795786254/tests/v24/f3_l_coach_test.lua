-- Wuber 2.4 fix round 3, group L (stage B, surface 4): a coach mark takes its height from its text.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- about twice the longest real mark
local LONG = "Nothing up front. After the summon your driver opens a trade: type the fare yourself and click Trade. "
	.. "Nothing up front. After the summon your driver opens a trade: type the fare yourself and click Trade. "
	.. "Wuber only tells you what to type."
local LONG_TITLE = "Pay when you land, in your own time, and only when you are happy"

local function rectOf(f) return { l = f:GetLeft(), r = f:GetRight(), t = f:GetTop(), b = f:GetBottom() } end

local function start(text, title)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local UI = r.W.UI
	if text then UI.COACH[1].text = text end
	if title then UI.COACH[1].title = title end
	UI.Toggle(true)
	for _ = 1, 400 do
		if UI.state.coach and UI.state.coaching then break end
		w:advance(0.05)
	end
	w:advance(1)
	return w, r, UI.state.coach
end

test("v24 f3l: a coach mark with twice the longest text and a long title shows both whole, the card grown, inside the phone", function()
	local w, r, b = start(LONG, LONG_TITLE)
	ok(b and H.visible(b), "the mark shows")
	eq(b.text:GetText(), LONG, "the text is whole")
	eq(b.title:GetText(), LONG_TITLE, "the title is whole")
	ok(H.truncation(b.text, true) == nil, "the text is not cut")
	ok(H.truncation(b.title, true) == nil, "the title is not cut")
	local _, size = b.text:GetFont()
	ok(size and size >= 11, "no shrunk text: " .. tostring(size))
	local _, tsize = b.title:GetFont()
	ok(tsize and tsize >= 14, "no shrunk title (the body size, 14 since design 3; it was 15): " .. tostring(tsize))
	local t, nx, br = rectOf(b.text), rectOf(b.next), rectOf(b)
	ok(t.b >= nx.t - 0.5, "the text stays above the buttons: text bottom " .. t.b .. ", buttons top " .. nx.t)
	ok(nx.b >= br.b - 0.5, "Next is inside the card")
	ok(b:GetHeight() > 126, "the card grew: " .. b:GetHeight())
	local win = rectOf(r.env.WuberFrame)
	ok(br.t <= win.t + 0.5 and br.b >= win.b - 0.5, "inside the phone: " .. br.b .. ".." .. br.t .. " in " .. win.b .. ".." .. win.t)
	T.clean(w)
end)

test("v24 f3l: a real coach mark keeps the card at 126 (two lines of the 12 px text; it was 124 with 11 px)", function()
	local w, _, b = start()
	ok(b and H.visible(b), "the mark shows")
	eq(b:GetHeight(), 126, "unchanged height")
	T.clean(w)
end)
