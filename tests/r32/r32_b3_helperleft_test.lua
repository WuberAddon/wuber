local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local SPOT = "Undercity"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end
local function team()
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, n in ipairs(names) do
		cs[i] = w:addClient(n, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(n, names, ANA) } })
	end
	w:group(names)
	w:advance(1)
	cs[1].W.Drive.SetOpen(true)
	w:advance(2)
	return w, cs[1], cs[2], cs[3]
end
local function press(c)
	local b = c.env.WuberDriveButton
	ok(b and H.visible(b), c.player.name .. ": big button not there")
	return c:click(b)
end
local function ask(w, to, name)
	if not w:player(name) then w:addBot(name) end
	w:botWhisper(name, to, "summon pls")
	w:advance(3)
end
local function summon(w, caster, h1, h2)
	press(caster) w:advance(3)
	ok(w:clickPortal(h1)) ok(w:clickPortal(h2)) w:advance(1.5)
end
local function blocked(c, k) return c.W.Drive.BlockEntry(k) end

test("r32 b3: AUD-20: control, a rider who walks out owing is blocked (the crew's normal rule)", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller") summon(w, ana, bea, cal) w:advance(8)
	w:tradeCancel(w:player("Dan Miller"))
	w:leave("Dan Miller")
	w:advance(14)
	ok(blocked(ana, "dan miller"), "the rider who left owing is blocked")
	T.clean(w)
end)

test("r32 b3: AUD-20: a helper who leaves the party mid-trade does not block the rider who is still there", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller") summon(w, ana, bea, cal) w:advance(8)
	-- Dan has landed and is about to pay Ana; Bea (a helper) leaves the party
	ok(w:player("Dan Miller").trade ~= nil, "Dan's trade with the caster is open")
	eq(bea.W.Drive.customers["dan miller"].state, "arrived", "Bea's window sees Dan arrived")
	w:leave(BEA)
	w:advance(14)
	for _, c in ipairs({ ana, bea, cal }) do
		eq(blocked(c, "dan miller"), nil, c.player.name .. ": Dan is still in the party and about to pay, yet shows blocked as a non-payer")
	end
	T.clean(w)
end)

test("r32 b3: AUD-20: the last rider who walks out of a two-person party owing is still blocked", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller") summon(w, ana, bea, cal) w:advance(8)
	w:tradeCancel(w:player("Dan Miller"))
	-- the helpers go first; then Dan walks out, which ends Ana's party (she is out of a group, but did not leave)
	w:leave(BEA) w:advance(1)
	w:leave(CAL) w:advance(1)
	eq(blocked(ana, "dan miller"), nil, "Dan is still in the party: not blocked yet")
	w:leave("Dan Miller")
	w:advance(14)
	ok(blocked(ana, "dan miller"), "the rider who left a two-person party owing is blocked")
	T.clean(w)
end)
