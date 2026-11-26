local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("e1-06: first-open tip card (Tip 1 of 5) background fill is fully opaque (alpha=1)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	r.W.UI.Toggle(true)
	w:advance(3)
	ok(#r:findText("Tip 1 of 5") > 0, "Tip 1 of 5 is shown")
	local c = r.W.UI.state.coach
	ok(c and c.card and c.card.bg and c.card.bg.parts, "coach card and bg parts exist")
	eq(c:GetEffectiveAlpha(), 1, "coach frame effective alpha is 1")
	eq(c.card:GetEffectiveAlpha(), 1, "coach card effective alpha is 1")
	for k, tex in pairs(c.card.bg.parts) do
		local _, _, _, va = tex:GetVertexColor()
		eq(va, 1, "coach bg part " .. k .. " vertex alpha must be 1 (opaque)")
		eq(tex:GetEffectiveAlpha(), 1, "coach bg part " .. k .. " effective alpha must be 1")
	end
	T.clean(w)
end)
