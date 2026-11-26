-- Design round 3, group H1: heights that follow the text. A paragraph, the Messages preview bubble and the
-- Wizard's crew row are at least as tall as their lines need (n x drawn size + (n - 1) x spacing, plus padding).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local TEXTS = {
	"Hi.",
	"Hello Dan, I am a Wuber driver and I can summon you to the Undercity portal right now, whenever you are ready for it.",
	string.rep("Hello Dan, I can summon you to the portal when you are ready, just say so and I will start. ", 3),
}

test("d3 h1: the Messages preview bubble and its paragraph are as tall as their lines need, for 1, 2 and 3+ lines", function()
	local w = T.newWorld()
	local d = T.driver(w, T.TESTCHAR)
	T.settle(w)
	local W, D = d.W, d.W.Driver
	D.ShowScreen("messages") w:advance(1)
	local s = W.UI.drive.screens.messages
	local Th = W.Theme
	local e = s.editor
	for i, text in ipairs(TEXTS) do
		s.edit("advert") w:advance(1)
		e.field:SetText(text)
		s.preview()
		local n = math.max(1, Th.ParaLines(e.prev:GetText() or "", "caption", "regular", e.iw - 24))
		local need = n * Th.DrawnSize("caption") + (n - 1) * Th.Spacing("caption")
		ok(e.prev.paraH >= need, "text " .. i .. ": the paragraph holds its " .. n .. " lines")
		ok(e.bubble:GetHeight() >= 22 + need, "text " .. i .. ": the bubble holds them plus its padding")
	end
end)
