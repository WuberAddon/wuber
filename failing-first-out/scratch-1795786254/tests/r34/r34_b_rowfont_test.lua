local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function paint(D, r, state, extra)
	local c = { name = "Dan Test", state = state, at = 1000, paid = 0, price = 5000 }
	for k, v in pairs(extra or {}) do c[k] = v end
	D.PaintRow(r, c, 1030)
end

test("r34 b: a row that showed no right-hand text then 'owes ...' draws the amount smaller than a fresh row", function()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift")
	T.settle(w)
	local W, D = d.W, d.W.Driver
	local Tm = W.Mod and W.Mod("Theme.Tokens") or nil
	local parent = d.env.CreateFrame("Frame", "WuberAuditHolder", d.env.UIParent)
	parent:SetSize(300, 100)
	local fresh = D.Row(parent, 284)
	local used = D.Row(parent, 284)
	-- control: a fresh row painted straight to the arrived state keeps the amount at its base size
	paint(D, fresh, "arrived", { source = "wuber" })
	local ft = fresh.right:GetText()
	ok(ft and ft:find("owes"), "control: right text reads owes: " .. tostring(ft))
	eq(fresh.right.wuberPx, fresh.right.wuberBase, "control: a fresh row draws 'owes' at its requested size")
	-- the same row after the rider walked through states with an empty right-hand text
	paint(D, used, "joined")
	eq(used.right:GetText(), "", "control: no right-hand text while joined")
	paint(D, used, "arrived", { source = "wuber" })
	eq(used.right:GetText(), ft, "control: same words")
	eq(used.right.wuberPx, used.right.wuberBase, "the 'owes' amount is drawn at size " .. tostring(used.right.wuberPx) .. " instead of " .. tostring(used.right.wuberBase) .. " on a row that came from an empty right-hand text")
	T.clean(w)
end)
