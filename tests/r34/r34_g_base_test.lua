local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- The client does not know the player's name at PLAYER_LOGIN (UnitName gives "Unknown"), knows it at PLAYER_ENTERING_WORLD.
local function login(w, name, saved, unknownAtLogin)
	return T.rider(w, name, { spot = "Orgrimmar", saved = saved, prepare = function(env)
		if not unknownAtLogin then return end
		local known = false
		local real = env.UnitName
		env.UnitName = function(u, ...)
			if u == "player" and not known then return "Unknown" end
			return real(u, ...)
		end
		local f = env.CreateFrame("Frame")
		f:RegisterEvent("PLAYER_ENTERING_WORLD")
		f:SetScript("OnEvent", function() known = true end)
	end })
end

local function seed(key)
	return { WuberDB = { chars = { [key] = { price = 7000, queue = { at = 1, list = {} } } } } }
end

test("r34 g: AUD-142 character settings and saved queue missed when the name is unknown at login", function()
	local key = T.TESTCHAR:lower()
	-- control: name known at login: the saved queue is taken (consumed) by restore() and no "?" entry appears
	local w0 = T.newWorld()
	local r0 = login(w0, T.TESTCHAR, seed(key), false)
	T.settle(w0)
	eq(r0.W.myKey, key, "control: key known")
	ok(r0.W.db.chars["?"] == nil, "control: no stray '?' character")
	ok(r0.W.db.chars[key].queue == nil, "control: saved queue consumed at login")
	-- bug path
	local w = T.newWorld()
	local r = login(w, T.TESTCHAR, seed(key), true)
	T.settle(w)
	eq(r.W.myKey, key, "the name is learnt at PLAYER_ENTERING_WORLD")
	ok(r.W.db.chars["?"] == nil, "a stray '?' character was saved in WuberDB.chars (Drive.Core ran W.Char() at login with key '?')")
	ok(r.W.db.chars[key].queue == nil, "the character's saved rider queue was not restored at login: it was looked up under '?'")
end)

local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r34 g: AUD-143 a space-free Hardcore realm name gives no ruleset", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local env = r.env
	-- the client's realm name has no spaces (the normalised form), as W.Ruleset falls back to
	env.GetRealmName = function() return nil end
	env.GetNormalizedRealmName = function() return "CAMWOWEU1Realm1PvE" end
	eq(r.W.Ruleset(), "EU-PvE", "control: a space-free PvE realm name is read")
	env.GetNormalizedRealmName = function() return "CAMWOWEU1Realm1HC" end
	eq(r.W.Ruleset(), "EU-HC", "a Hardcore realm named ...HC has no ruleset: no seed drivers, no Pioneer credits for this player")
	T.clean(w)
end)
