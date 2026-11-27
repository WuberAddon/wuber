-- The default advert line says the driver SELLS summons, when to pay and both ways to book (maintainer's wording).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("playtest Q2: the default advert line is the agreed text", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	eq(W.AdvertText("Orgrimmar", 5000),
		"[Wuber] Selling summons to Orgrimmar, 50s. Pay after you land. /w me or use my Wuber addon (on curse), you can also set it up and become a driver",
		"the agreed words")
	T.clean(w)
end)

test("playtest Q2: the default line stays under the 200-letter limit for every place and a large price", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	local longest, n = 0, 0
	for _, dest in ipairs({ "Orgrimmar", "Undercity", "Thunder Bluff", "Stormwind City", "Booty Bay", "Gadgetzan", "Ratchet", "Shattrath City", "Dalaran", "Blackrock Mountain" }) do
		local line = W.AdvertText(dest, 123456789)
		n = n + 1
		longest = math.max(longest, #line)
		ok(#line <= 200, dest .. ": " .. #line .. " letters")
		ok(line:find("you can also set it up and become a driver", 1, true), dest .. ": the line is not cut off")
	end
	ok(n > 0 and longest > 100, "control: lines were measured (" .. longest .. ")")
	T.clean(w)
end)

-- guard: a custom line the driver saved is posted as it is (the new default never replaces it)
test("playtest Q2: a saved custom advert line is untouched", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	local line = W.AdvertOwnText("my own words to Org")
	eq(line, "[Wuber] my own words to Org", "own text keeps its words")
	T.clean(w)
end)

test("playtest Q2: the default line passes the driver's advert checks and can be posted", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	local W = d.W
	w:splitChannel(d, "other")
	T.settle(w, 5)
	local line = W.AdvertText("Orgrimmar", 5000)
	local own, why = W.AdvertOwnText(line)
	eq(own, line, "kept as it is (" .. tostring(why) .. ")")
	local plan, pwhy = W.AdvertPlan("Orgrimmar", 5000, { text = line })
	ok(plan and plan.text == line, "a plan with the default line (" .. tostring(pwhy) .. ")")
	T.clean(w)
end)

-- guard: only the fixed default words are let through; a place or fare that is spam still is refused
test("playtest Q2: the default words do not let a spammy place through", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	local tail = W.AdvertText("Orgrimmar", 5000):match("%.( Pay after.*)$")
	local own = W.AdvertOwnText("[Wuber] Selling summons to buy gold at gold shop, 50s." .. tail)
	eq(own, nil, "refused")
	T.clean(w)
end)
