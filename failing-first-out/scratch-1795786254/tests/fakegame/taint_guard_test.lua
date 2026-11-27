-- The fake game's taint guard (tests/harness.lua H.taint, allow list tests/fakegame/taint-allow.lua): a planted write is caught,
-- and the cases Wuber is allowed to do are not. The planted code is run from a file under the Wuber folder's name through the
-- addon's own environment, so the guard sees it as addon code where it must (a frame parent), and compares tables where it cannot know who wrote.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function world()
	local w = T.newWorld()
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "MAGE", addons = {}, allowMissing = true })
	return w, c, c.env
end
local function says(w, text)
	for _, v in ipairs(w.violations or w) do if tostring(v):find(text, 1, true) then return true end end
	return false
end
local function scanned(w, c)
	T.H.taint.scan(c)
	return w.violations
end
local function forgive(w) w.violations = {} end -- the test planted it on purpose

-- guard: infra (tests the guard itself; a base with no guard has nothing to run)
test("fakegame taint guard: an entry in the allow file with no reason is refused", function()
	local path = os.tmpname()
	local f = assert(io.open(path, "w"))
	f:write('return { tables = { Foo = { append = "^x" } }, parents = {} }')
	f:close()
	local okLoad, err = pcall(T.H.taint.load, path)
	os.remove(path)
	ok(not okLoad and tostring(err):find("needs a reason", 1, true), "refused: " .. tostring(err))
	ok(pcall(T.H.taint.load), "the real allow file loads: every entry has a reason")
end)

-- guard: infra
test("fakegame taint guard: UISpecialFrames may only get one of our own names appended", function()
	local w, c, env = world()
	table.insert(env.UISpecialFrames, "WuberFrame")
	eq(#scanned(w, c), 0, "appending WuberFrame is allowed")
	table.insert(env.UISpecialFrames, "SomeBlizzardPanel")
	ok(says(scanned(w, c), "UISpecialFrames[2]"), "appending another name is a write into the game's table")
	forgive(w)
end)

-- guard: infra (#99: Escape closes the top sheet first; a window's slot is swapped for its sheet's name and back)
test("fakegame taint guard: UISpecialFrames swap of our window and our sheet name is allowed, any other swap is not", function()
	local w, c, env = world()
	table.insert(env.UISpecialFrames, "SomeBlizzardPanel")
	forgive(w)
	table.insert(env.UISpecialFrames, "WuberFrame")
	T.H.taint.snap(c) -- (as if both were there before this test's writes)
	local i = #env.UISpecialFrames
	env.UISpecialFrames[i] = "WuberSheet1"
	eq(#scanned(w, c), 0, "our window -> our sheet name passes")
	env.UISpecialFrames[i] = "WuberFrame"
	eq(#scanned(w, c), 0, "and back")
	env.UISpecialFrames[i - 1] = "WuberSheet1"
	ok(says(scanned(w, c), "UISpecialFrames[" .. (i - 1) .. "]"), "a game entry overwritten by a sheet name fails")
	forgive(w)
end)
test("fakegame taint guard: a Wuber name written over a non-Wuber entry, or a removal, is caught", function()
	local w, c, env = world()
	table.insert(env.UISpecialFrames, "SomeBlizzardPanel")
	forgive(w)
	T.H.taint.snap(c)
	local i = #env.UISpecialFrames
	env.UISpecialFrames[i] = "WuberFrame"
	ok(says(scanned(w, c), "UISpecialFrames[" .. i .. "]"), "WuberFrame over a game entry fails")
	forgive(w)
end)
test("fakegame taint guard: removing an entry from UISpecialFrames is caught", function()
	local w, c, env = world()
	table.insert(env.UISpecialFrames, "SomeBlizzardPanel")
	forgive(w)
	T.H.taint.snap(c)
	table.remove(env.UISpecialFrames, #env.UISpecialFrames)
	ok(says(scanned(w, c), "removed"), "a removal fails")
	forgive(w)
end)

-- Not covered, and said so in tests/README.md: the game's C_* tables are proxies in the fake (a write goes through their own __newindex), so a
-- write into C_Map and its kind is not seen.
-- guard: infra
test("fakegame taint guard: a new key or a changed value in a Blizzard table is caught", function()
	local w, c, env = world()
	env.StaticPopupDialogs.SOMETHING_ELSE = { text = "x" }
	ok(says(scanned(w, c), "StaticPopupDialogs[SOMETHING_ELSE]"), "a key in StaticPopupDialogs not named for us")
	forgive(w)
	env.RAID_CLASS_COLORS.MAGE = { r = 1, g = 0, b = 0 }
	ok(says(scanned(w, c), "RAID_CLASS_COLORS[MAGE]"), "a value changed inside a game table")
	forgive(w)
end)

-- guard: infra
test("fakegame taint guard: hooksecurefunc on a plain game table is not the addon's write either", function()
	local w, c, env = world()
	local called = 0
	env.Constants = env.Constants or {}
	env.Constants.Plain = function() end
	T.H.taint.snap(c) -- (a game table that has a function in it, as the game's own tables do)
	env.hooksecurefunc(env.Constants, "Plain", function() called = called + 1 end)
	env.Constants.Plain()
	eq(called, 1, "the hook runs")
	eq(#scanned(w, c), 0, "installing it is the game's own write")
	env.Constants.Plain = function() end
	ok(says(scanned(w, c), "game's table Constants[Plain]"), "an assignment over it is still caught")
	forgive(w)
end)

-- guard: infra
test("fakegame taint guard: hooksecurefunc by the game's own installer is not the addon's write", function()
	local w, c, env = world()
	env.hooksecurefunc(env.WorldMapFrame, "Show", function() end)
	eq(#scanned(w, c), 0, "a hook through hooksecurefunc is the sanctioned way")
end)

test("fakegame taint guard: Wuber's code writing a method onto a game frame is caught with its line; a test doing it is not judged", function()
	local w, c, env = world()
	env.Minimap.OnShow = function() end -- the test's own write
	eq(#w.violations, 0, "a test may stub a game frame")
	local dir = T.H.ADDONS.Wuber:gsub("\\", "/")
	local chunk = assert(loadstring("Minimap.Show = function() end", "@" .. dir .. "/UI/Planted3.lua"))
	setfenv(chunk, env)
	chunk()
	ok(says(w, "game frame Minimap.Show (Wuber/UI/Planted3.lua:1"), "caught: " .. table.concat(w.violations, " | "))
	forgive(w)
end)

-- guard: infra (parenting is judged on addon code only: a test building frames under a game window is the test's business)
test("fakegame taint guard: a test making a frame under a game window is not judged; UIParent, Minimap and our own frames are fine for all", function()
	local w, c, env = world()
	env.CreateFrame("Frame", nil, env.TradeFrame)
	eq(#w.violations, 0, "made by the test itself")
	local mine = env.CreateFrame("Frame", "WuberTestMine", env.UIParent)
	env.CreateFrame("Frame", nil, mine)
	env.CreateFrame("Frame", nil, env.Minimap)
	eq(#w.violations, 0, "own and allowed parents")
end)

test("fakegame taint guard: Wuber's code hanging a frame under a game window is caught with its line", function()
	local w, c, env = world()
	-- a chunk named like a file of the Wuber folder, loaded as the addon would run it
	local dir = T.H.ADDONS.Wuber:gsub("\\", "/")
	local chunk = assert(loadstring("local env = ... CreateFrame('Frame', nil, GameTooltip)", "@" .. dir .. "/UI/Planted.lua"))
	setfenv(chunk, env)
	chunk(env)
	ok(says(w.violations, "a frame was put under the game window GameTooltip (Wuber/UI/Planted.lua:1)"), "caught: " .. table.concat(w.violations, " | "))
	forgive(w)
	w.violations = {}
	-- the same through SetParent, and a game window the allow list names is let through
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	local chunk2 = assert(loadstring("local f = ... f:SetParent(GameTooltip) f:SetParent(Minimap)", "@" .. dir .. "/UI/Planted2.lua"))
	setfenv(chunk2, env)
	chunk2(f)
	ok(says(w.violations, "under the game window GameTooltip (Wuber/UI/Planted2.lua:1)"), "SetParent under a game window is caught")
	ok(not says(w.violations, "game window Minimap"), "Minimap is allowed")
	forgive(w)
end)

test("fakegame taint guard: Wuber's code replacing a game global is caught", function()
	local w, c, env = world()
	local dir = T.H.ADDONS.Wuber:gsub("\\", "/")
	local chunk = assert(loadstring("UnitName = function() return 'x' end", "@" .. dir .. "/Core/Planted.lua"))
	setfenv(chunk, env)
	chunk()
	ok(says(scanned(w, c), "replaced the game's global UnitName (Wuber/Core/Planted.lua:1)"), "caught: " .. table.concat(w.violations, " | "))
	forgive(w)
end)
