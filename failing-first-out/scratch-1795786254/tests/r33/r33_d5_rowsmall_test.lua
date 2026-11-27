-- Round 33 d5: AUD-117 (accented initial), AUD-122 (paid by hand shows no "free"), AUD-123 (mini station chip)

local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function validUtf8(s)
	local i, n = 1, #s
	while i <= n do
		local b = s:byte(i)
		local len = b < 128 and 1 or (b >= 194 and b <= 223) and 2 or (b >= 224 and b <= 239) and 3 or (b >= 240 and b <= 244) and 4 or 0
		if len == 0 or i + len - 1 > n then return false end
		for j = i + 1, i + len - 1 do
			local c = s:byte(j)
			if c < 128 or c > 191 then return false end
		end
		i = i + len
	end
	return true
end

local function initialOf(a, name)
	local mini = a.env.WuberDriveMini
	if not mini or not mini:IsShown() then return nil, "mini not shown" end
	for _, r in ipairs(mini.rows) do
		if r:IsShown() and r.c and r.c.name and r.c.name:find(name, 1, true) then return r.initial:GetText() end
	end
	return nil, "no row for " .. name
end

test("r33 d5 AUD-C52b-6: a rider whose name starts with an accented letter gets half a character on the row's disc", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local PLAIN, ACC = "Dan", "\195\137lodie" -- Elodie with E-acute (UTF-8 C3 89)
	w:addBot(PLAIN, { spot = "Ratchet", acceptsInvites = true })
	w:addBot(ACC, { spot = "Ratchet", acceptsInvites = true })
	w:advance(15)
	local DR = a.W.Drive
	DR.Shards = function() return 10 end
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper(PLAIN, a, "summon pls")
	w:botWhisper(ACC, a, "summon pls")
	w:advance(4)
	w:advance(3)
	local p, why = initialOf(a, PLAIN)
	ok(p, "control: the plain rider has a row on the mini console: " .. tostring(why))
	eq(p, "D", "control: plain name gives its capital letter")
	local e, why2 = initialOf(a, ACC)
	ok(e, "the accented rider has a row: " .. tostring(why2))
	ok(validUtf8(e), "the disc's letter is the broken byte(s) " .. e:gsub(".", function(c) return string.format("\\%d", c:byte()) end) .. ": the game draws a box or nothing instead of E-acute")
	T.clean(w)
end)


test("r33 d5 AUD-C52b-8: a rider the driver marks as paid by hand shows 'paid' with 'free' beside it", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local bot = "Dan Miller"
	w:addBot(bot, { spot = "Ratchet", acceptsInvites = true })
	w:advance(15)
	local W = a.W
	local DR = W.Drive
	DR.Shards = function() return 10 end
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper(bot, a, "summon pls")
	w:advance(20)
	local c = DR.customers["dan miller"]
	ok(c, "control: the rider is listed")
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	local D = W.Driver
	D.RefreshNow() w:advance(1)
	local what, right = D.Describe(c, 0)
	ok(right ~= "free", "control: before paying the row does not say free (" .. tostring(what) .. " / " .. tostring(right) .. ")")
	-- Ctrl-click on the row = mark as paid
	DR.MarkPaid(c)
	w:advance(2)
	D.RefreshNow() w:advance(1)
	eq(c.state, "paid", "state after Mark as paid")
	eq(c.paid or 0, 0, "no gold was seen")
	local what2, right2 = D.Describe(c)
	ok(right2 ~= "free", "the row reads '" .. tostring(what2) .. "' with '" .. tostring(right2) .. "' beside it: no gold was seen, so 'free' is wrong")
	T.clean(w)
end)

local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local ANA, BEA, DAN = "Ana Smith", "Bea Jones", "Dan Miller"

-- Ana summons at Ratchet, Bea at Orgrimmar (two stations). Dan asks for Ratchet. Returns the mini row for Dan.
local function scenario(openConsole)
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = "Ratchet", class = "WARLOCK",
		saved = { Wuber = { chars = { [key(ANA)] = { wizard = true, captain = "", runner = true,
			summoners = { ANA, BEA }, crew = { { name = BEA, role = "lock", app = true } } } } } } })
	w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK",
		saved = { Wuber = { chars = { [key(BEA)] = { wizard = true, captain = ANA, crew = { { name = ANA, role = "lock", app = true } } } } } } })
	w:group({ ANA, BEA })
	w:advance(10)
	local DR = ana.W.Drive
	ok(DR.SetOpen(true))
	w:advance(10)
	if openConsole then
		T.openDrive(ana)
		ana.W.UI.ShowDrive("console")
		w:advance(2)
		ana.W.Driver.RefreshNow() w:advance(1)
		ana.W.UI.Toggle(false) -- close the phone again: the console is now the floating mini
		w:advance(2)
	end
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = true })
	w:botWhisper(DAN, ana, "summon to ratchet pls")
	w:advance(10)
	ok(DR.MultiStation(), "two stations")
	local c = DR.customers[key(DAN)]
	ok(c, "Dan is a rider")
	ok(c.station, "Dan has a station: " .. tostring(c and c.station))
	return w, ana, c
end

local function miniChip(ana)
	local mini = ana.env.WuberDriveMini
	if not mini or not mini:IsShown() then return nil, "mini not shown" end
	for _, r in ipairs(mini.rows) do
		if r:IsShown() and r.c and r.c.name and r.c.name:find("Dan") then return r.station:IsShown() end
	end
	return nil, "no Dan row"
end

test("r33 d5 AUD-C52b-9: the floating mini console shows no station chip until the Drive tab has been opened (two stations)", function()
	-- control: the Drive tab was drawn once while two stations stood: the mini shows the chip
	local w1, a1 = scenario(true)
	local shown1, why1 = miniChip(a1)
	ok(shown1 ~= nil, "control: " .. tostring(why1))
	ok(shown1 == true, "control: after the Drive tab was drawn, the mini's row shows its station chip")
	-- bug: never opened
	local w2, a2 = scenario(false)
	w2:advance(3)
	local shown2, why2 = miniChip(a2)
	ok(shown2 ~= nil, "mini row exists: " .. tostring(why2))
	ok(shown2 == true, "two stations stand but the floating mini's rider row shows no station chip (Drive tab never opened)")
	T.clean(w2)
end)
