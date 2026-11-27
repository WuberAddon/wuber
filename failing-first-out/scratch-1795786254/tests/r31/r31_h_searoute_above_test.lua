local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
-- HUNT-95: the "continues by boat" arrow and label are drawn on a frame above the continent clip frames.
test("r31 h: the sea arrow's label sits on a frame above its parent's child frames", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Orgrimmar", faction = "Horde" })
	local env = r.env
	local M = r.W.Mod("UI.Rider.SeaRoute")
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	f:SetSize(300, 200)
	local clip = env.CreateFrame("Frame", nil, f)
	local spec = M.Arrow(M.Split({ { cont = 1, to = 0, kind = "boat", pts = { 5, 5, 90, 60 } } }, 1), { x = 200 })
	local o = M.Draw(f, spec)
	local home = o.label:GetParent()
	ok(home ~= f, "label is on its own frame")
	ok(home:GetFrameLevel() > clip:GetFrameLevel(), "above the clip frame")
	local o2 = M.Draw(f, spec, nil, o)
	eq(o2.label, o.label, "reused")
	eq(o2.label:GetParent(), home, "same frame again")
end)
