local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local clean, settle = T.clean, T.settle
local ANA, BEA = "Ana Smith", "Bea Jones"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function DRof(c) return c.W.Drive end
local function customer(c, name) return c.W.Drive.customers[key(name)] end
local function state(c, name)
	local x = customer(c, name)
	return x and x.state or nil
end

-- saved data: the runner (captain) with its crew; extra = more W.Char() keys
local function runnerSaved(me, crew, extra)
	local ch = { crew = crew, captain = "", wizard = true }
	for k, v in pairs(extra or {}) do ch[k] = v end
	return { Wuber = { chars = { [key(me)] = ch } } }
end

-- a member of `captain`'s crew; all = every crew name { name, role }
local function memberSaved(me, captain, all)
	local crew = {}
	for _, m in ipairs(all) do
		if m.name ~= me then crew[#crew + 1] = { name = m.name, role = m.role, app = m.app ~= false } end
	end
	return { Wuber = { chars = { [key(me)] = { crew = crew, captain = captain, wizard = true } } } }
end

local function press(c)
	local b = c.env.WuberDriveButton
	ok(b, c.player.name .. ": no WuberDriveButton")
	ok(H.visible(b), c.player.name .. ": the big button is hidden")
	return c:click(b)
end

-- WUBERT messages of a kind (from a player)

local UCH1, UCH2, OGH1, OGH2 = "Una Helper", "Uli Helper", "Ola Helper", "Oto Helper"
local function twoStations()
	local w = T.newWorld()
	local all = {
		{ name = ANA, role = "lock" }, { name = BEA, role = "lock" },
		{ name = UCH1, role = "helper" }, { name = UCH2, role = "helper" },
		{ name = OGH1, role = "helper" }, { name = OGH2, role = "helper" },
	}
	local crew = {}
	for i = 2, #all do crew[#crew + 1] = { name = all[i].name, role = all[i].role, app = true } end
	local c = {}
	c.ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK", saved = runnerSaved(ANA, crew) })
	c.bea = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK", saved = memberSaved(BEA, ANA, all) })
	c.u1 = w:addClient(UCH1, { spot = "Undercity", class = "PRIEST", saved = memberSaved(UCH1, ANA, all) })
	c.u2 = w:addClient(UCH2, { spot = "Undercity", class = "MAGE", saved = memberSaved(UCH2, ANA, all) })
	c.o1 = w:addClient(OGH1, { spot = "Orgrimmar", class = "PRIEST", saved = memberSaved(OGH1, ANA, all) })
	c.o2 = w:addClient(OGH2, { spot = "Orgrimmar", class = "MAGE", saved = memberSaved(OGH2, ANA, all) })
	w:group({ ANA, BEA, UCH1, UCH2, OGH1, OGH2 })
	settle(w)
	return w, c
end

test("the big button's tooltip for the 'where to?' whisper reads as a sentence", function()
	local w, c = twoStations()
	local DA = DRof(c.ana)
	ok(DA.SetOpen(true))
	w:advance(2)
	-- a rider who names no place: the driver's window owes the 'where to?' whisper
	w:addBot("Fay Moon", { spot = "Thunder Bluff" })
	w:botWhisper("Fay Moon", c.ana, "summon pls")
	w:advance(30)
	local fay = customer(c.ana, "Fay Moon")
	ok(fay and fay.askWhere and not fay.whereTold, "setup: Fay is owed the 'where to?' whisper")
	local pend = DA.Pending()
	local kinds = {}
	for _, p in ipairs(pend) do kinds[#kinds + 1] = p.kind .. ":" .. p.c.name end
	ok(#pend >= 1 and pend[1].kind == "where", "setup: the first whisper owed is 'where': " .. table.concat(kinds, ","))
	local p = DA.Plan()
	local say = p.say or ""
	ok(say:find("Fay", 1, true), "control: the tooltip names the rider: " .. say)
	ok(not say:find("whispers Fay where", 1, true),
		"the tooltip reads 'A click " .. say .. "' (the raw word 'where' for the question about the place)")
	clean(w)
end)

test("the chat-box tooltip for the 'where to?' whisper reads as a sentence", function()
	local w, c = twoStations()
	local DA = DRof(c.ana)
	ok(DA.SetOpen(true))
	w:advance(2)
	c.ana.W.Drive.opts().whisperMode = "box"
	w:addBot("Fay Moon", { spot = "Thunder Bluff" })
	w:botWhisper("Fay Moon", c.ana, "summon pls")
	w:advance(30)
	local fay = customer(c.ana, "Fay Moon")
	ok(fay and fay.askWhere, "setup: Fay is owed the 'where to?' whisper")
	local p = DA.Plan()
	ok(p.box and p.box.kind == "where", "setup: the chat box is for the 'where' whisper")
	local say = p.say or ""
	ok(say:find("Fay", 1, true), "control: the tooltip names the rider: " .. say)
	ok(not say:find("puts where for", 1, true), "the tooltip reads: 'A click " .. say .. "'")
	clean(w)
end)
