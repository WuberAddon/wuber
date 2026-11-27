-- Proof tests of job 2620 (audit-241), area A: Core data and flights.
local T = ...
local test = T.test
-- r50 (job 2609): these bugs are fixed in 2.4.1; their proofs now run as normal tests
local FIXED = { ["AU24-01"] = true, ["AU24-02"] = true, ["AU24-03"] = true, ["AU24-06"] = true, ["AU24-09"] = true, ["AU24-10"] = true, ["AU24-12"] = true, ["AU24-13"] = true, ["AU24-15"] = true, ["AU24-17"] = true, ["AU24-18"] = true, ["AU24-19"] = true, ["AU24-20"] = true, ["AU24-21"] = true, ["AU24-22"] = true, ["AU24-26"] = true, ["AU24-27"] = true, ["AU24-28"] = true, ["AU24-29"] = true, ["AU24-31"] = true, ["AU24-33"] = true, ["AU24-34"] = true, ["AU24-35"] = true }
local function proof(id, name, fn)
	if os.getenv("WUBER_AU24_PROOF") or FIXED[id] then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end

local function world()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	return w, r
end

-- Promise: the anti-spam word list (gold selling, web addresses) never refuses a driver for naming a place by a
-- nickname Wuber itself accepts for it (W.PLACES names: "uc", "org", "bb"...). "Org" is the game's everyday word
-- for Orgrimmar, and W.FindPlace("org") is Orgrimmar, yet "org" is also a spam word (for ".org" addresses).
test("AU24-23: a driver's advert or message naming a city by its nickname (Org) is not refused as spam", function()
	local w, r = world()
	local W = r.W
	local refused = {}
	for _, p in ipairs(W.PLACES) do
		local names = { p.name }
		for _, a in ipairs(p.names) do names[#names + 1] = a end
		for _, n in ipairs(names) do
			local why = W.SentenceSpam("Summons to " .. n .. " and UC")
			if why then refused[#refused + 1] = n .. "=" .. why end
		end
	end
	assert(#refused == 0, "place names refused as spam in a driver's own sentence: " .. table.concat(refused, ", "))
	-- the real path: the driver's "My advert line"
	local line, why = W.AdvertOwnText("Summons to Org, UC and SW, tips welcome")
	assert(line, "the advert line was refused (" .. tostring(why) .. ")")
end)
