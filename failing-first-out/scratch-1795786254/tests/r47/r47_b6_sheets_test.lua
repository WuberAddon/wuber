local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local DRU, LEA, WAR = "Dru Oak", "Lea Dorn", "Wick Lock"


test("r47 b6: C59r-5: Pick summoners: scroll range is computed against the old sheet height when more Warlocks appear", function()
	local w = H.NewWorld({})
	local names = { DRU }
	local function lock(i)
		local n = "Lock L" .. string.char(96 + i)
		w:addBot(n, { spot = "Blackrock Mountain", class = "WARLOCK" })
		return n
	end
	names[#names + 1] = lock(1)
	local dru = w:addClient(DRU, { spot = "Blackrock Mountain", class = "DRUID" })
	for i = 1, 3 do w:addBot("Raider R" .. string.char(96 + i), { spot = "Orgrimmar", class = "WARRIOR" }) names[#names + 1] = "Raider R" .. string.char(96 + i) end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	ok(dru.W.Drive.SetMode("raid"))
	T.openDrive(dru)
	dru.W.Driver.ShowSheet("raidpick") w:advance(2)
	local s = dru.W.UI.drive.screens.raidpick
	local function stale()
		local view = s.scroll:GetHeight()
		local want = math.max(0, s.scroll.content:GetHeight() - view)
		return s.scroll.max, want, view
	end
	local m0, want0 = stale()
	eq(m0, want0, "control: scroll range is right with one Warlock")
	-- five more Warlocks join the raid while the sheet is open
	for i = 2, 7 do names[#names + 1] = lock(i) end
	w:group(names)
	local bad, lastBad
	for step = 1, 40 do
		w:advance(0.1)
		local m, want, view = stale()
		if m ~= want then lastBad = step * 0.1 end
		if m ~= want then bad = bad or ("after " .. step * 0.1 .. " s the scroll can move " .. tostring(m) .. " px but the list is " .. tostring(want) .. " px longer than the view (view " .. tostring(view) .. ")") end
	end
	w:advance(3)
	local m2, want2 = stale()
	eq(m2, want2, "control: after a few seconds the scroll range is right again")
	ok(not bad, tostring(bad) .. " (still wrong until " .. tostring(lastBad) .. " s)")
	T.clean(w)
end)


test("r47 b6: C15r-2: Pick summoners with a big raid lets the list scroll past its last row into empty space", function()
	local w = T.newWorld()
	local d = w:addClient("Dru Lead", { spot = "Orgrimmar", class = "DRUID" })
	w:advance(15)
	local DR = d.W.Drive
	d.W.Char().runner = true
	d.W.Char().wizard = true
	DR.Role = function() return "driver" end
	DR.Mode = function() return "raid" end
	DR.IsOpen = function() return false end
	DR.CanRunRaid = function() return true end
	DR.Summoners = function() return {} end
	DR.RaidQueue = function() return {} end
	DR.NotHere = function() return {} end
	DR.RaidCount = function() return 14 end
	local n = 12
	DR.RaidWarlocks = function()
		local t = {}
		for i = 1, n do local nm = "Lock " .. string.char(64 + i) t[i] = { key = key(nm), name = nm, shards = 3, app = true } end
		return t
	end
	d.W.UI.Toggle(true) w:advance(2.5)
	d:clickText("Drive") w:advance(1)
	pcall(d.W.Driver.ShowScreen, "raidpick")
	local s = d.W.UI.drive.screens.raidpick
	local sc = s.scroll
	local view = sc:GetHeight()
	local contentH = sc.content:GetHeight()
	local trueMax = math.max(0, contentH - view)
	ok(view > 0 and contentH > view, "control: the list is taller than its window (" .. tostring(contentH) .. " vs " .. tostring(view) .. ")")
	-- the instant the sheet opens (before the next refresh) how far may the list scroll?
	ok(sc.max <= trueMax + 0.5, ("right after Pick summoners opens, the list may scroll %.0f units but only %.0f are real: the player can drag the last row up and leave empty space under it (until the next refresh)"):format(sc.max, trueMax))
	T.clean(w)
end)



local function setup(crewN)
	local w = H.NewWorld({})
	local crew = {}
	for i = 1, crewN do crew[i] = { name = "Helper H" .. string.char(96 + i), role = "helper", app = true } end
	w:addBot(LEA, { spot = "Blackrock Mountain", class = "WARRIOR" })
	w:addBot(WAR, { spot = "Blackrock Mountain", class = "WARLOCK" }) -- a Warlock with no Wuber
	local dru = w:addClient(DRU, { spot = "Blackrock Mountain", class = "DRUID",
		saved = { Wuber = { chars = { [key(DRU)] = { crew = crew, captain = "", wizard = true } } } } })
	local names = { LEA, DRU, WAR }
	for i = 1, 5 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	ok(dru.W.Drive.SetMode("raid"))
	T.openDrive(dru)
	dru.W.Driver.ShowSheet("raidpick") w:advance(1)
	local s = dru.W.UI.drive.screens.raidpick
	local row
	for _, r in ipairs(s.rows.list) do if r:IsShown() and r.p and r.p.key == key(WAR) then row = r end end
	ok(row, "control: the Warlock without Wuber is listed")
	return w, dru, row
end

test("r47 b6: C59r-6: control: ticking a Warlock without Wuber with room in the crew adds him and says so", function()
	local w, dru, row = setup(0)
	dru:clickOn(row.toggle) w:advance(1)
	ok(dru.W.Drive.CrewEntry(key(WAR)), "control: he is in the crew")
	ok(#dru:findText("Wick summons", false, true) > 0, "control: toast says he summons: " .. T.list(dru:visibleTexts()):sub(1, 300))
	T.clean(w)
end)

test("r47 b6: C59r-6: the crew is full (8): ticking a Warlock without Wuber toasts that he summons but he is not added", function()
	local w, dru, row = setup(8)
	eq(#dru.W.Char().crew, 8, "control: the crew is full")
	dru:clickOn(row.toggle) w:advance(1)
	local added = dru.W.Drive.CrewEntry(key(WAR)) ~= nil
	local toast = #dru:findText("Wick summons", false, true) > 0
	ok(not (toast and not added), "the toast reads 'Wick summons (no Wuber...)' but he was not added (crew full): the switch flipped back off: " ..
		T.list(dru:visibleTexts()):sub(1, 400))
	T.clean(w)
end)
