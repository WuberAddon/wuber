local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

local function scene(city, rspot)
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = city, class = "WARLOCK", allowMissing = true })
	local A = a.W.Drive
	A.SetOpen(true)
	w:addBot("Dan Miller", { spot = rspot })
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
	w:advance(3)
	return w, a, A
end

test("r27 AUD-01: control, the rider stays while the driver stays in Orgrimmar; Undercity and Tirisfal Glades count as one place", function()
	local w, a, A = scene("Orgrimmar", "Undercity")
	local c = A.customers["dan miller"]
	ok(c and (c.state == "joined" or c.state == "queued"), "Dan is on the list, state " .. tostring(c and c.state))
	w:advance(12)
	ok(A.customers["dan miller"], "Dan is still on the driver's list")
	ok(A.PlaceOK({ forPlace = "Undercity" }, { "Tirisfal Glades" }), "Undercity and the zone outside it are the same place")
	T.clean(w)
end)

test("r27 AUD-01: the driver steps out of Orgrimmar into Durotar: the waiting rider stays", function()
	local w, a, A = scene("Orgrimmar", "Undercity")
	local c = A.customers["dan miller"]
	ok(c and (c.state == "joined" or c.state == "queued"), "Dan is on the list, state " .. tostring(c and c.state))
	w:move(ANITA, "Durotar")
	w:advance(12)
	ok(A.customers["dan miller"],
		"the driver walked out of the Orgrimmar gate into Durotar, and Dan, who was waiting for his summon, is dropped as 'moved'")
	ok(A.PlaceOK({ forPlace = "Orgrimmar" }, { "Durotar" }), "Orgrimmar and Durotar (outside the gate) should be the same place, as Undercity and Tirisfal Glades are")
	T.clean(w)
end)

-- (lead) the towns the bug named: a town and the zone it stands in are one place too, and two
-- places that only share a zone are not
test("r27 AUD-01: Auberdine and Darkshore, Menethil Harbor and Wetlands count as one place; two towns of one zone do not", function()
	local w, a, A = scene("Orgrimmar", "Undercity")
	ok(A.PlaceOK({ forPlace = "Auberdine" }, { "Darkshore" }), "Auberdine and Darkshore (outside the town)")
	ok(A.PlaceOK({ forPlace = "Menethil Harbor" }, { "Wetlands" }), "Menethil Harbor and Wetlands")
	ok(A.PlaceOK({ forPlace = "Stormwind" }, { "Elwynn Forest" }), "Stormwind and Elwynn Forest")
	ok(not A.PlaceOK({ forPlace = "Undercity" }, { "Scarlet Monastery" }), "Undercity and Scarlet Monastery share a zone but are different places")
	ok(not A.PlaceOK({ forPlace = "Orgrimmar" }, { "Tirisfal Glades" }), "Orgrimmar is not Tirisfal Glades")
	ok(not A.PlaceOK({ forPlace = "Orgrimmar" }, { "" }), "an empty place is no match")
	T.clean(w)
end)
