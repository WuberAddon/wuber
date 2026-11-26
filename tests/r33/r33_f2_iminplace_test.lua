local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Round 33, group F2 (AUD-57): "I'm in the badlands" says where the rider stands, like "in badlands".
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local ANA = "Ana Smith"

test("r33 f2: 'summon pls, I'm in the badlands' is invited, not read as a place to go to", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK",
		saved = { Wuber = { chars = { [key(ANA)] = { wizard = true, captain = "", runner = true, crew = {} } } } } })
	w:advance(10)
	local DR = ana.W.Drive
	ok(DR.SetOpen(true))
	w:advance(5)
	w:addBot("Dan Miller", { spot = "Durotar" })
	w:botWhisper("Dan Miller", ana, "summon pls, I'm in the badlands")
	w:advance(3)
	local n = 0
	for _, i in ipairs(w.invites) do if key(i.to) == key("Dan Miller") then n = n + 1 end end
	eq(n, 1, "invited")
	eq(#DR.AskedPlaces("summon pls, I'm in the badlands"), 0, "no place asked for")
	local p = DR.AskedPlaces("summon pls to the badlands")
	ok(p[1] and p[1].to, "to the badlands is still a place to go to")
	T.clean(w)
end)
