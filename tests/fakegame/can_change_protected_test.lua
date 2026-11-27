-- Frame:CanChangeProtectedState() (fake-game conformance): the client answers whether an addon may change a frame's protected state
-- now: false for a protected frame (a secure one, or one holding a secure child) while the player is in combat lockdown, true
-- otherwise (out of combat, or an ordinary frame). The fake had no such method, so an addon that asks first (the careful way to
-- touch a frame that may hold a secure button) raised "attempt to call method 'CanChangeProtectedState' (a nil value)".
-- Hand-written from the documented behaviour; no outside code or lists copied.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function world()
	local w = T.newWorld()
	local c = w:addClient("Ana Smith", { spot = "Orgrimmar", class = "MAGE" })
	return w, c, c.env
end

test("CanChangeProtectedState: true for every frame out of combat", function()
	local w, c, env = world()
	local plain = env.CreateFrame("Frame", "CcpPlain", env.UIParent)
	local secure = env.CreateFrame("Button", "CcpSecure", env.UIParent, "SecureActionButtonTemplate")
	eq(plain:CanChangeProtectedState(), true, "plain frame")
	eq(secure:CanChangeProtectedState(), true, "secure button, no fight")
	T.clean(w)
end)

test("CanChangeProtectedState: in combat a secure frame (or its parent) answers false, a plain frame true", function()
	local w, c, env = world()
	local plain = env.CreateFrame("Frame", "CcpPlain2", env.UIParent)
	local holder = env.CreateFrame("Frame", "CcpHolder", env.UIParent)
	local secure = env.CreateFrame("Button", "CcpSecure2", holder, "SecureActionButtonTemplate")
	w:enterCombat(c)
	eq(plain:CanChangeProtectedState(), true, "a plain frame can still change")
	eq(secure:CanChangeProtectedState(), false, "a secure button cannot")
	eq(holder:CanChangeProtectedState(), false, "nor the frame that holds it")
	w:leaveCombat(c)
	eq(secure:CanChangeProtectedState(), true, "the fight is over")
	T.clean(w)
end)
