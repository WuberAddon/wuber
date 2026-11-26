-- Wuber 2.4 fix round 3, group L (stage B, surface 1): a toast takes its height from its text.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- about twice the longest real toast sentence
local LONG = "Tip: put the word Wuber in any advert you type yourself. Wuber players' addons hear it and find you. "
	.. "Tip: put the word Wuber in any advert you type yourself. Wuber players' addons hear it and find you."

test("v24 f3l: a toast with twice the longest text shows it whole, at full size, grown, on screen", function()
	local w = T.newWorld()
	local wub = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "WARLOCK" })
	w:advance(5)
	local UI = wub.W.UI
	local t = UI.Toast(LONG, "info")
	ok(t, "toast made")
	eq(t.text:GetText(), LONG, "the text is whole")
	ok(not t.text:IsTruncated(), "the text is not cut")
	local tr = H.truncation(t.text, true)
	ok(tr == nil, "the game would not cut it (" .. tostring(tr and (tr.lines .. "/" .. tr.max)) .. ")")
	local _, size = t.text:GetFont()
	ok(size and size >= 12, "no shrunk font: " .. tostring(size))
	local lines = H.textLines(t.text)
	ok(lines and lines >= 5, "control: it needs many lines (" .. tostring(lines) .. ")")
	local need = lines * size * 1.2
	ok(t:GetHeight() >= need, "the toast is tall enough: " .. t:GetHeight() .. " for " .. need)
	w:advance(2) -- the slide settles
	local top, bottom = t:GetTop(), t:GetBottom()
	ok(top and bottom, "placed")
	ok(top <= wub.env.UIParent:GetHeight() + 0.5 and bottom >= 0, "on screen: " .. tostring(bottom) .. ".." .. tostring(top))
	T.clean(w)
end)
