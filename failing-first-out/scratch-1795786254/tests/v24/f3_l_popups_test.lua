-- Wuber 2.4 fix round 3, group L (stage B, surface 2): the crew offer popup takes its height from its text.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- a driver's service line about twice as long as a real one
local SERVICE = "Orgrimmar to Stormwind, Ironforge, Darnassus and the Exodar, any hour, tips welcome, whisper me first. "
	.. "Orgrimmar to Stormwind, Ironforge, Darnassus and the Exodar, any hour, tips welcome, whisper me first"

local function rectOf(f) return { l = f:GetLeft(), r = f:GetRight(), t = f:GetTop(), b = f:GetBottom() } end

test("v24 f3l: the crew offer holds a very long service line whole; the card grows, the buttons stay inside, on screen", function()
	local w = T.newWorld()
	local wub = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "WARLOCK" })
	w:advance(5)
	local UI = wub.W.UI
	ok(UI.CrewOffer("Anaid-Realm", SERVICE), "the offer shows")
	w:advance(2)
	local f = wub.env.WuberCrewOffer
	ok(f and f:IsShown(), "the card is up")
	ok(f.text:GetText():find(SERVICE, 1, true), "the text is whole")
	local tr = H.truncation(f.text, true)
	ok(tr == nil, "the game does not cut it")
	local text, yes = rectOf(f.text), rectOf(f.yes)
	local card = rectOf(f)
	ok(text.b >= yes.t - 0.5 or text.l >= yes.r or text.r <= yes.l, "the text stays above the Yes button: text bottom " .. text.b .. ", button top " .. yes.t)
	ok(yes.b >= card.b - 0.5, "Yes is inside the card: " .. yes.b .. " vs " .. card.b)
	local top, bottom = f:GetTop(), f:GetBottom()
	ok(top <= wub.env.UIParent:GetHeight() + 0.5 and bottom >= 0, "on screen")
	T.clean(w)
end)

test("v24 f3l: a real crew offer keeps its size (168 high)", function()
	local w = T.newWorld()
	local wub = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "WARLOCK" })
	w:advance(5)
	wub.W.UI.CrewOffer("Anaid-Realm", "Orgrimmar to Stormwind")
	w:advance(2)
	eq(wub.env.WuberCrewOffer:GetHeight(), 168, "unchanged height")
	T.clean(w)
end)
