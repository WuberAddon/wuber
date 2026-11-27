local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r47 j4: Check my game reuses its secure button and animation group", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local secure, groups = 0, 0
	local real = r.env.CreateFrame
	r.env.CreateFrame = function(kind, name, parent, tmpl, ...)
		local f = real(kind, name, parent, tmpl, ...)
		if tmpl == "SecureActionButtonTemplate" then secure = secure + 1 end
		if type(f) == "table" and type(f.CreateAnimationGroup) == "function" and not f._cnt then
			f._cnt = true
			local mk = f.CreateAnimationGroup
			f.CreateAnimationGroup = function(...) groups = groups + 1 return mk(...) end
		end
		return f
	end
	-- AUD-221: the hidden test button is made at login (before this hook), so no run makes one
	r.W.SelfTest()
	local s1, g1 = secure, groups
	r.W.SelfTest() r.W.SelfTest()
	eq(s1, 0, "control: the first run makes no secure button, the login one is reused (" .. s1 .. ")")
	ok(secure == s1, "two more /wuber test runs made " .. (secure - s1) .. " more secure buttons that the game never frees (and secure frames are for login only)")
	ok(groups == g1, "and " .. (groups - g1) .. " more animation groups")
	T.clean(w)
end)