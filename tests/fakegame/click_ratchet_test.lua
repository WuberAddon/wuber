-- Fable item 5, the click-path ratchet, and its proof on the real past bug B7 / #36 ("the back arrow does nothing in the game").
-- The tests of tests/r53/a_confirm_back_test.lua called the arrow's OnClick script directly and passed while the drag strip
-- (UI/Window.lua before UI.HeadHit, PR #62) lay over the arrow and took every real click. Three proofs:
--   (1) tools/click-ratchet.lua flags that old file's direct calls, and a new direct click or a rise fails its check;
--   (2) the same back-arrow check through Client:clickOn FAILS on the old Window.lua (tests/fixtures/old/Window_pre36.lua = the file
--       as of b6afe54^, before any #36 fix) and PASSES on the current one;
--   (3) the old direct-call check PASSES on the old Window.lua: the blind spot the ratchet closes.
-- Which harness rule catches it: the hit test of Client:topAt as it is now (run 3: a frame in a clipping body ranks at the body's
-- level, and the equal-level header strip wins). The harness before that rule is not rebuilt here; see NOTES in the job folder.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local R = dofile("tools/click-ratchet.lua")

local function slurp(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

-- (1) the ratchet --------------------------------------------------------------------------------------------------
-- guard: the counter sees what it must and nothing else (a comment, a clickOn, a reasoned line)
test("click ratchet: counts GetScript OnClick, :Click and :click, not clickOn, comments, or a line with a direct-click reason", function()
	local n = R.count('b:GetScript("OnClick")(b)\nlocal x = c:clickOn(b)\n-- b:Click()\nf:Click()\nc:click(f)\nc:clickText("x")\n') -- direct-click: sample text for the counter, nothing is clicked
	eq(n, 3, "GetScript OnClick, :Click and :click each count once; clickOn, clickText and the comment do not")
	eq(R.count('f:Click() -- direct-click: the test is about the click script itself\n'), 0, "a line with a reason is free")
	eq(R.count('f:Click() -- direct-click:\n'), 1, "an empty reason is not a reason")
end)

test("click ratchet: flags the direct OnClick calls of the old r53 back-arrow test (B7 / #36)", function()
	local old = slurp("tests/fixtures/old/a_confirm_back_test.lua.txt")
	local n, lines = R.count(old)
	eq(n, 2, "the old file calls GetScript OnClick twice (the Ride tab and the back chevron), at lines " .. table.concat(lines, ","))
	local back = false
	for _, l in ipairs(lines) do
		local i, text = 0, nil
		for line in (old .. "\n"):gmatch("(.-)\n") do i = i + 1 if i == l then text = line end end
		if text and text:find("back:", 1, true) then back = true end
	end
	ok(back, "one of the flagged lines is the back chevron's call")
	-- a store that says 0 for that file: the check fails on the file; a store with its 2: passes
	local problems = R.compare({ ["tests/r53/a_confirm_back_test.lua"] = 2 }, {})
	eq(#problems, 1, "a file with a direct click and no entry in the store fails: " .. tostring(problems[1]))
	problems = R.compare({ ["tests/r53/a_confirm_back_test.lua"] = 3 }, { ["tests/r53/a_confirm_back_test.lua"] = 2 })
	eq(#problems, 1, "a rise 2 -> 3 fails")
	problems = R.compare({ ["tests/r53/a_confirm_back_test.lua"] = 2 }, { ["tests/r53/a_confirm_back_test.lua"] = 2 })
	eq(#problems, 0, "the same count passes")
	local _, falls = R.compare({ ["tests/r53/a_confirm_back_test.lua"] = 1 }, { ["tests/r53/a_confirm_back_test.lua"] = 2 })
	eq(#falls, 1, "a fall is reported, never a failure")
end)

-- the store matches the tests as they are: a direct click added to any test file raises its count and fails here and in quick-check
test("click ratchet: no test file has more direct clicks than tests/click-ratchet.txt allows", function()
	local stored, exists = R.load("tests/click-ratchet.txt")
	ok(exists, "tests/click-ratchet.txt exists")
	local problems = R.compare(R.scan("."), stored)
	eq(#problems, 0, "the ratchet: " .. tostring(problems[1]) .. (#problems > 1 and (" (+" .. (#problems - 1) .. " more)") or ""))
end)

-- (2) and (3) the proof on the old Window.lua ------------------------------------------------------------------------
local OLD = "tests/fixtures/old/Window_pre36.lua"
local function openConfirm(old)
	local w = T.newWorld()
	local prepare = old and function(_, c)
		local text = slurp(OLD)
		c.rewrite = function(addon, file) if addon == "Wuber" and file:gsub("\\", "/") == "UI/Window.lua" then return text end end
	end or nil
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080, prepare = prepare })
	w:advance(15)
	local UI = c.W.UI
	local K = c.W.Mod("UI.Kit")
	UI.Toggle(true) w:advance(3)
	local key = "Mia Runner-Test"
	c.W.drivers = c.W.drivers or {}
	c.W.drivers[key] = { name = "Mia Runner", key = key, dest = "Undercity", price = 5000, state = "open", team = 3, service = "Mia's Rides", heard = c.env.GetTime() }
	UI.Show("confirm", key) w:advance(1)
	eq(K.ui.screen, "confirm", "control: on confirm")
	if old then eq(UI.HeadHit, nil, "control: this Window.lua is the old one (no UI.HeadHit)") else ok(UI.HeadHit, "control: the current Window.lua has UI.HeadHit") end
	local back = K.ui.screens and K.ui.screens.confirm and K.ui.screens.confirm.back
	ok(back, "control: the chevron exists")
	return w, c, K, back
end

-- the back-arrow check, the way a player does it: the hit test decides who gets the click
local function realBackCheck(w, c, K, back)
	local hit = c:clickOn(back) w:advance(1)
	return hit == back and K.ui.screen == "home", hit
end

test("click ratchet proof: a REAL click on the back chevron of Ride/confirm reaches it on the current Window.lua", function()
	local w, c, K, back = openConfirm(false)
	local good, hit = realBackCheck(w, c, K, back)
	ok(good, "the real click landed on " .. tostring(hit and hit:GetDebugName()) .. " and the screen is " .. tostring(K.ui.screen))
	T.clean(w)
end)

test("click ratchet proof: the same REAL click FAILS on the old Window.lua (before UI.HeadHit): the drag strip takes it", function()
	local w, c, K, back = openConfirm(true)
	local good, hit = realBackCheck(w, c, K, back)
	ok(not good, "on the old Window.lua the real click must not reach the back chevron")
	ok(hit ~= back, "something else took it: " .. tostring(hit and hit:GetDebugName()))
	eq(K.ui.screen, "confirm", "the screen did not change: the arrow is dead, as in the game")
end)

-- guard: the blind spot. The old direct-call check goes green on the very Window.lua that has the dead arrow.
test("click ratchet proof: the OLD direct-call check passes on the old Window.lua (why the bug reached the game)", function()
	local w, c, K, back = openConfirm(true)
	back:GetScript("OnClick")(back) w:advance(1) -- direct-click: this IS the old blind spot being shown
	eq(K.ui.screen, "home", "the direct call leads home although a player's click could not reach the arrow")
end)
