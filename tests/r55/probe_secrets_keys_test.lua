-- (job 2893, Fable item 4; B4, B3) the probe fixture's secrets and key rules reach the fake game with nothing else done in the test.
-- B4: the real client hands out secret values on frames the addon does not own (nameplates, unit frames). Before this job a test had to call client:secretFrame(frame)
--     for each such frame by hand, and a fixture row the probe saved with its argument ("GetPoint(1)") was silently never applied.
-- B3: IsKeyboardEnabled depends on the ORDER of EnableKeyboard and SetScript("OnKeyDown") in the real client (Rows.lua's order); the fake had one rule.
-- The fixture here is the synthetic stand-in on disk (tests/fixtures/probe/SYNTHETIC-standin.lua) with two invented truths laid over it
-- (it has no secret frames and its key rows equal the fake's own rule): NOT real client data.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local L = dofile(T.dir .. "/lib/probe_learn.lua")
local STANDIN = T.dir .. "/fixtures/probe/SYNTHETIC-standin.lua"

local function withLearning(fn)
	local saved, fixture = L.save(H), H.probeFixture
	local good, err = pcall(fn)
	L.restore(H, saved)
	H.probeFixture = fixture
	if not good then error(err, 0) end
end

local function standIn()
	local fx = assert(L.load(STANDIN))
	eq(fx.source, "sim", "the stand-in is not game data")
	-- invented truth 1 (B4): the probe's secrets part found these accessors secret on these Blizzard frames (names from the probe's own frame list)
	fx.secretAccessors = { GetWidth = { "CompactPartyFrame", "BagsBar" }, ["GetPoint(1)"] = { "CompactPartyFrame" }, ["IsEventRegistered(PLAYER_LOGIN)"] = { "BagsBar" } }
	-- invented truth 2 (B3): the real client answers the other way round from the fake for both key orders
	fx.keys.keyDownAfterDisable = { kb = false, mouse = false, prop = false }
	fx.keys.disableAfterKeyDown = { kb = true, mouse = false, prop = false }
	return fx
end

-- guard: infra (a test of tests/lib/probe_learn.lua, tools and the fake game; proved with failing-first --base-tools)
test("secrets (B4): the measured frames answer secret values with no client:secretFrame call, other frames stay plain", function()
	withLearning(function()
		L.reset(H)
		local w = T.newWorld()
		local c = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE", money = 1000 })
		local calls = 0
		local orig = c.secretFrame
		c.secretFrame = function(...) calls = calls + 1 return orig(...) end
		local party = c.env.CreateFrame("Frame", "CompactPartyFrame") party:SetSize(40, 10) party:SetPoint("CENTER")
		local bags = c.env.CreateFrame("Frame", "BagsBar") bags:SetSize(30, 12)
		local mine = c.env.CreateFrame("Frame", "WuberOwnFrame") mine:SetSize(40, 10)
		ok(not c.env.issecretvalue(party:GetWidth()), "before: the fake answers plainly (what a test saw until it called secretFrame)")
		L.apply(H, standIn())
		ok(c.env.issecretvalue(party:GetWidth()), "CompactPartyFrame:GetWidth is secret")
		ok(c.env.issecretvalue(bags:GetWidth()), "BagsBar:GetWidth is secret")
		ok(c.env.issecretvalue((party:GetPoint(1))), "the row the probe saved as GetPoint(1) reaches GetPoint")
		ok(c.env.issecretvalue(bags:IsEventRegistered("PLAYER_LOGIN")), "and IsEventRegistered(PLAYER_LOGIN) reaches IsEventRegistered")
		eq(mine:GetWidth(), 40, "an addon's own frame is untouched")
		eq(party:GetHeight(), 10, "another accessor is untouched")
		eq(calls, 0, "no client:secretFrame call anywhere")
		L.reset(H)
		eq(party:GetWidth(), 40, "reset: plain again")
		T.clean(w)
	end)
end)

-- guard: the learner already feeds key rules from a fixture (probe_test.lua pins it with hand-made tables); this pins it on the stand-in's shape, both orders (B3)
test("keys (B3): IsKeyboardEnabled follows the fixture for both orders of EnableKeyboard(false) and OnKeyDown", function()
	withLearning(function()
		L.reset(H)
		local w = T.newWorld()
		local c = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE", money = 1000 })
		local function order(disableFirst)
			local f = c.env.CreateFrame("Frame")
			if disableFirst then f:EnableKeyboard(false) f:SetScript("OnKeyDown", function() end)
			else f:SetScript("OnKeyDown", function() end) f:EnableKeyboard(false) end
			return f:IsKeyboardEnabled()
		end
		eq(order(true), true, "before: the fake's own rule, a key script turns the keyboard on")
		eq(order(false), false, "before: and a disable after it wins")
		L.apply(H, standIn())
		eq(order(true), false, "Rows.lua's order (disable, then OnKeyDown): the fixture's answer")
		eq(order(false), true, "the other order: the fixture's answer")
		L.reset(H)
		eq(order(true), true, "reset: the fake's own rule again")
		T.clean(w)
	end)
end)
