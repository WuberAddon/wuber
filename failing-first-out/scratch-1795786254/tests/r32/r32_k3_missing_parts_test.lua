local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Round 32, group K, HUNT-38: a /reload after an update that added files leaves some newer part unloaded;
-- only a missing driver part (or UI.ShowDrive) used to make login say "Restart the game".

local function listed(W)
	local s = ","
	for _, n in ipairs(W.MissingParts()) do s = s .. n .. "," end
	return s
end

test("r32 k3: a fresh load has nothing missing", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	eq(#r.W.MissingParts(), 0, "nothing missing: " .. listed(r.W))
	T.clean(w)
end)

test("r32 k3: an unloaded rider screen part is named as missing", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local W = r.W
	for _, m in ipairs({ { "UI.Bird", "Show" }, { "UI.Tips", "ShowNow" } }) do
		local mod = W.Mod(m[1])
		local keep = mod[m[2]]
		ok(type(keep) == "function", m[1] .. " is loaded")
		mod[m[2]] = nil
		ok(#W.MissingParts() > 0, m[1] .. " gone is noticed: " .. listed(W))
		mod[m[2]] = keep
	end
	for _, name in ipairs({ "Bug", "Fold", "Share" }) do
		local keep = W.UI[name]
		ok(type(keep) == "table", "UI." .. name .. " is loaded in a fresh world")
		W.UI[name] = nil
		ok(#W.MissingParts() > 0, "UI." .. name .. " gone is noticed: " .. listed(W))
		W.UI[name] = keep
	end
	T.clean(w)
end)

test("r32 k3: a missing newer driver part is named", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local W = r.W
	for _, fn in ipairs({ "RaincheckTick", "BookTick", "CutTick", "DangerTick", "KitchenSend", "RaidTick", "CastWatch", "Readiness" }) do
		local keep = W.Drive[fn]
		ok(type(keep) == "function", "Drive." .. fn .. " is loaded")
		W.Drive[fn] = nil
		ok(#W.MissingParts() > 0, "Drive." .. fn .. " gone is noticed")
		W.Drive[fn] = keep
	end
	T.clean(w)
end)

test("r32 k3: login toasts the restart notice when a rider part is missing", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { prepare = function(env) end })
	T.settle(w)
	local W = r.W
	local said
	local keep = W.UI.Toast
	W.UI.Toast = function(text) said = text end
	W.UI.Bug = nil
	r:fire("PLAYER_LOGIN")
	w:advance(5)
	W.UI.Toast = keep
	ok(said and said:find("Restart the game"), "restart notice shown: " .. tostring(said))
	T.clean(w)
end)
