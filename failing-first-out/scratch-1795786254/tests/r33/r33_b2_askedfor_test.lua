local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local clean = T.clean
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function customer(c, name) return c.W.Drive.customers[key(name)] end
local LOADING = { mapID = 0, x = 0.5, y = 0.5, zone = "", sub = "" }

test("r33 b2: a rider asking uc to org while the driver is on a loading screen is invited later, not made a lead", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.goOnline(d) w:advance(5)
	d.W.Drive.char().dest = ""
	w:move(T.ANITA, LOADING) w:advance(1)       -- a loading screen: the driver's place is not known
	for _, n in ipairs{"Fay Moon", "Eve Long"} do w:addBot(n, { spot = "Undercity" }) end
	w:botWhisper("Fay Moon", d, "uc > org summon pls")      -- from Undercity TO Orgrimmar, where the driver is
	w:botWhisper("Eve Long", d, "summon to org pls")        -- control: names only Orgrimmar
	w:advance(2)
	w:move(T.ANITA, "Orgrimmar") w:advance(8)               -- the screen is gone: the driver serves Orgrimmar
	local f, e = customer(d, "Fay Moon"), customer(d, "Eve Long")
	ok(e and e.state ~= "lead" and e.state ~= nil, "control: Eve (Orgrimmar) is invited/joined, state " .. tostring(e and e.state))
	ok(f and f.state ~= "lead" and f.state ~= nil,
		"Fay asked to go to Orgrimmar and the driver is in Orgrimmar, but she is only a lead (state " .. tostring(f and f.state)
		.. ", asked-for place remembered as '" .. tostring(f and f.askedFor) .. "', the origin)")
	clean(w)
end)
