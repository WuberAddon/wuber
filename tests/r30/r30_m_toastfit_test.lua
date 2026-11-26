local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- HUNT-93 (advert tip) and HUNT-96 (no more flight master tips): a toast holds its whole sentence
local TEXTS = {
	"Tip: put the word Wuber in any advert you type yourself. Wuber players' addons hear it and find you.",
	"No more flight master tips. Turn them back on in Settings > Riding > Flight master tip.",
}
local ROOM = 251

test("toast fit: a long toast grows taller so its whole text shows, and a short one stays 56 high", function()
	local w = T.newWorld()
	local wub = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "WARLOCK" })
	w:advance(5)
	local UI = wub.W.UI
	local short = UI.Toast("Hello", "info")
	ok(short, "control: a toast is made")
	eq(short:GetHeight(), 56, "a short toast keeps its height")
	for _, text in ipairs(TEXTS) do
		w:advance(6)
		local t = UI.Toast(text, "info")
		ok(t, "toast made")
		local lines = math.ceil(t.text:GetUnboundedStringWidth() / ROOM)
		ok(lines >= 3, "control: the sentence needs 3 or more lines in 251 px (" .. lines .. ")")
		ok(t:GetHeight() >= 56 + 14 * (lines - 2), "the toast grows for " .. lines .. " lines, height " .. t:GetHeight())
		ok(t.text.GetMaxLines == nil or (t.text:GetMaxLines() or 0) == 0 or t.text:GetMaxLines() >= lines, "the text is not limited to 2 lines")
		eq(t.text:GetText(), text, "the text is not shortened")
	end
	T.clean(w)
end)
