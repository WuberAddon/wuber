-- #233 The fake game answers secret values as the 1.60.1 client does (tests/fixtures/secret-api.lua, from the
-- client's own API documentation: SecretReturns*, ConstSecretAccessor): a foreign frame with a secret aspect and the
-- global functions the client flags hand back a secret value; using it (compare with <, concatenate, index, call,
-- length, arithmetic) raises. issecretvalue tells it from a plain value. A plain Lua "==" and "if v" cannot be made to
-- fail on a userdata, so a secret boolean's use is read from the source too (the last test).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function world()
	local w = T.newWorld()
	local c = w:addClient("Ana Smith", { spot = "Orgrimmar", class = "MAGE", addons = { "Wuber" } })
	return w, c
end

-- plain Lua raises its own message for a userdata compared with a number; the others say "secret value"
local function raises(f, what, own)
	local good, err = pcall(f)
	ok(not good, what .. ": raises")
	if not own then ok(tostring(err):find("secret value", 1, true), what .. ": says why: " .. tostring(err)) end
end

test("#233 secret frame: IsEventRegistered, GetScript, HasScript, GetChildren answer a secret; an own frame answers plainly", function()
	local w, c = world()
	local env = c.env
	local foreign = env.CreateFrame("Frame", "ForeignProbe233", env.UIParent)
	foreign:RegisterEvent("PLAYER_LOGIN")
	eq(foreign:IsEventRegistered("PLAYER_LOGIN"), true, "control: a plain frame answers true")
	c:secretFrame(foreign)
	for _, m in ipairs({ "IsEventRegistered", "GetScript", "HasScript", "GetChildren", "GetWidth", "IsMouseOver" }) do
		local v = foreign[m](foreign, "PLAYER_LOGIN")
		ok(env.issecretvalue(v), m .. " on a foreign frame with a secret aspect: a secret value")
	end
	local own = env.CreateFrame("Frame", "OwnProbe233", env.UIParent)
	own:RegisterEvent("PLAYER_LOGIN")
	eq(own:IsEventRegistered("PLAYER_LOGIN"), true, "an own frame still answers true")
	eq(env.issecretvalue(own:IsEventRegistered("PLAYER_LOGIN")), false, "not secret")
	c:secretFrame(foreign, false)
	eq(foreign:IsEventRegistered("PLAYER_LOGIN"), true, "aspect off: plain again")
	T.clean(w)
end)

test("#233 secret value: concat, index, call, length, arithmetic, ordered compare all raise; issecretvalue is the way out", function()
	local w, c = world()
	local env = c.env
	local f = env.CreateFrame("Frame", "ForeignProbe233b", env.UIParent)
	c:secretFrame(f)
	local s = f:IsEventRegistered("X")
	raises(function() return "a" .. s end, "concat")
	raises(function() return s.x end, "index")
	raises(function() return s() end, "call")
	raises(function() return #s end, "length")
	raises(function() return s + 1 end, "arithmetic")
	raises(function() return s < 2 end, "order compare", true)
	eq(env.issecretvalue(s), true, "issecretvalue(secret)")
	eq(env.issecretvalue(true), false, "issecretvalue(true)")
	eq(env.issecretvalue(nil), false, "issecretvalue(nil)")
	eq(env.issecretvalue("x"), false, "issecretvalue(string)")
	eq(env.canaccessvalue(s), false, "canaccessvalue(secret)")
	eq(env.canaccessvalue(5), true, "canaccessvalue(5)")
	T.clean(w)
end)

test("#233 secret returns: client:secret(name) makes the flagged global and namespaced functions answer a secret", function()
	local w, c = world()
	local env = c.env
	eq(env.issecretvalue(env.UnitIsGroupLeader("player")), false, "control: plain by default")
	c:secret("UnitIsGroupLeader")
	eq(env.issecretvalue(env.UnitIsGroupLeader("player")), true, "UnitIsGroupLeader: secret when the test says so")
	c:unsecret()
	eq(env.issecretvalue(env.UnitIsGroupLeader("player")), false, "unsecret: plain")
	c:secret("*")
	eq(env.issecretvalue(env.UnitIsGroupLeader("player")), true, "'*': every flagged function")
	eq(env.issecretvalue(env.C_Spell.GetSpellCooldown(1)), true, "'*': namespaced too")
	c:unsecret()
	c:secret("C_Spell")
	eq(env.issecretvalue(env.C_Spell.GetSpellCooldown(1)), true, "a whole namespace")
	eq(env.issecretvalue(env.UnitIsGroupLeader("player")), false, "other functions stay plain")
	T.clean(w)
end)

-- A secret boolean cannot fail "== true" or "if v" in plain Lua, so the source is read: no Wuber or lab line may
-- compare the answer of IsEventRegistered or HasScript (secret on a foreign frame) with true / false / nil unless
-- issecretvalue (or the lab's isSecret, Wuber's W.Plain) is on that line or the three above it. lab/WuberLab/AutoKeys.lua
-- line 108 was the real one (the API sweep of 26 Nov 2026).
local function sources(dir, out)
	for _, path in ipairs(H.listFiles(dir)) do
		local name = path:match("([^/\\]+)$")
		if name:find("%.lua$") then out[#out + 1] = path
		elseif not name:find("%.") then sources(path, out) end
	end
	return out
end

test("#233 secret boolean: no Wuber or lab line compares IsEventRegistered / HasScript with true, false or nil unguarded", function()
	local root = T.dir .. "/.."
	local files = sources(root .. "/Wuber", {})
	for _, f in ipairs(sources(root .. "/lab", {})) do files[#files + 1] = f end
	ok(#files > 50, "found the sources: " .. #files)
	local bad = {}
	for _, path in ipairs(files) do
		local lines, prev = {}, {}
		for l in io.lines(path) do lines[#lines + 1] = l end
		for i, l in ipairs(lines) do
			local code = l:gsub("%-%-.*$", "")
			if (code:find("IsEventRegistered", 1, true) or code:find("HasScript", 1, true))
				and code:find("%)%s*[=~]=%s*[tfn][ro][ul][el]") then
				local guarded = false
				for j = math.max(1, i - 3), i do
					if lines[j]:find("issecretvalue", 1, true) or lines[j]:find("isSecret", 1, true) or lines[j]:find("Plain", 1, true) or lines[j]:find("plain(", 1, true) then guarded = true end
				end
				if not guarded then bad[#bad + 1] = path:match("([^/\\]+/[^/\\]+)$") .. ":" .. i .. ": " .. l:gsub("^%s+", "") end
			end
		end
	end
	eq(#bad, 0, "unguarded compare of a secret boolean: " .. table.concat(bad, " | "))
end)
