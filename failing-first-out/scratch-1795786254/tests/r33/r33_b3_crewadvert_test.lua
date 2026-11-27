local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, BEA = "Ana Smith", "Bea Jones"
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end
local function team()
	local w = T.newWorld()
	local names = { ANA, BEA }
	local cs = {}
	for i, n in ipairs(names) do
		cs[i] = w:addClient(n, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = crewSaved(n, names, ANA) } })
	end
	w:group(names)
	w:advance(3)
	return w, cs[1], cs[2]
end

test("r33 b3 AUD-69: resetting the advert to default clears it on the crew window too", function()
	local w, ana, bea = team()
	local D, B = ana.W.Drive, bea.W.Drive
	ok(D.SetTemplate("advert", "Fast portals to Orgrimmar, whisper summon"), "own advert saved")
	w:advance(3)
	eq(B.db.templates.advert, "Fast portals to Orgrimmar, whisper summon", "crew got the own advert")
	ok(D.SetTemplate("advert", nil), "reset to default")
	w:advance(3)
	eq(B.db.templates.advert, nil, "crew window back on the default")
	eq(B.AdvertText():find("Wuber addon", 1, true) ~= nil, true, "Wuber's own line again: " .. B.AdvertText())
	T.clean(w)
end)

test("r33 b3 HUNT-54: a 198 character advert reaches the crew window whole", function()
	local w, ana, bea = team()
	local D, B = ana.W.Drive, bea.W.Drive
	local line = ("Fast portals to Orgrimmar and more, whisper summon. "):rep(4):sub(1, 198)
	ok(D.SetTemplate("advert", line), "saved")
	w:advance(3)
	eq(#(B.db.templates.advert or ""), 198, "crew length")
	eq(B.db.templates.advert, D.db.templates.advert, "same text")
	T.clean(w)
end)
