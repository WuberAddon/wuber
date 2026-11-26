local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Round 34 n3 (HUNT-65): on the alert character itself the banner is the answer, so the button must not also say "Test sent".
test("r34 n3: Test the alert on the alert character itself shows the banner and no 'Test sent' note", function()
	local w = T.newWorld()
	local c = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE" })
	w:advance(5)
	c:slash("/wuber drive bell Wuber Rocks")
	w:advance(3)
	local U = c.W.UI
	local toasts = {}
	local old = U.Toast
	U.Toast = function(msg, kind) toasts[#toasts + 1] = tostring(msg) return old and old(msg, kind) end
	U.OpenSettings("drive")
	w:advance(1.2)
	local b = U.settings and U.settings.controls and U.settings.controls["drive.bellTest"]
	ok(b, "control: the Test the alert button exists")
	local fn = b:GetScript("OnClick")
	ok(fn, "control: it has a click handler")
	fn(b, "LeftButton")
	w:advance(1)
	U.Toast = old
	local b2 = c.env.WuberBell
	ok(b2 and b2:IsShown(), "control: the banner shows on this window")
	for _, t in ipairs(toasts) do ok(t ~= "Test sent", "no 'Test sent' note on the alert character itself") end
	T.clean(w)
end)
