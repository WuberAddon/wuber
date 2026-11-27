-- fga a calls the real client documents as MayReturnNothing return NOTHING in their empty case, not a single nil.
-- Loaded by tests/run.lua with its helper table T.
--
-- Real client (Blizzard_APIDocumentationGenerated, commit 734f065; MayReturnNothing = true means the call may return no values at all):
--   SimpleScriptRegionAPIDocumentation.lua: GetBottom #L130, GetCenter #L145, GetLeft #L178, GetRect #L193, GetRight #L211,
--     GetScaledRect #L239, GetTop #L308; SimpleScriptRegionResizingAPIDocumentation.lua: GetPoint #L65, GetPointByName #L88;
--   MapDocumentation.lua: GetMapArtLayerTextures #L135, GetMapArtLayers #L152, GetMapChildrenInfo #L198, GetMapInfo #L312,
--     GetMapInfoAtPosition #L328, GetMapPosFromWorldPos #L381, GetWorldPosFromMapPos #L506;
--   SpellDocumentation.lua: GetSpellCooldown #L309, GetSpellInfo #L416, GetSpellName #L518 (its comment says "Returns nil if spell is
--     not found"; the flag is what the generator derives from the engine, so the flag is trusted: tonumber()/select() tell them apart);
--   UnitDocumentation.lua: UnitClass #L911.
--   (all as https://github.com/Gethe/wow-ui-source/blob/734f065/Interface/AddOns/Blizzard_APIDocumentationGenerated/<file>#L<n>)
-- In game: 21 Nov 2026, "bad argument #1 to 'tonumber' (value expected)" at every login, 41 times: tonumber(t:GetLeft()) on a label
-- the game had not placed yet. The fake returned one nil there, so every offline test passed (w1-ingame-failures.md row 1;
-- Wuber/Drive/Button.lua:64-66 carries the fix).
-- Fake: Region:GetLeft/Right/Top/Bottom "return r and r.l" (tests/harness.lua:959-962: one nil), GetCenter 954-958, GetRect and
-- GetScaledRect "return nil" (963-972), GetPoint "return nil" (852-856), env.UnitClass "return nil" (5422-5424),
-- C_Spell.GetSpellInfo "return nil" (5538-5542), GetSpellCooldown ignores its argument and always answers a table (5544-5548),
-- C_Map.* "return nil" or {} (5957-5995: GetMapChildrenInfo gives {} for an unknown map), C_Map.GetMapInfoAtPosition and
-- GetPointByName are not defined at all. C_Spell.GetSpellName (5543) already falls off its end: nothing, so it passes today.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function count(...) return select("#", ...) end

-- runs every case, collects the ones that did not answer nothing, fails once with the whole list
local function allNothing(cases)
	local bad = {}
	for _, c in ipairs(cases) do
		local good, n = pcall(function() return count(c[2]()) end)
		if not good then bad[#bad + 1] = c[1] .. ": raised " .. tostring(n)
		elseif n ~= 0 then bad[#bad + 1] = c[1] .. ": " .. n .. " value(s), the game gives none" end
	end
	ok(#bad == 0, #bad .. " of " .. #cases .. " calls answered a value where the game answers nothing:\n  " .. table.concat(bad, "\n  "))
end

local function world()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	return w, r
end

-- guard: infra, failed before because the fake harness answered one nil (or a table) where the game answers no values
test("fga a a region the game has not placed answers GetLeft, GetRight, GetTop, GetBottom, GetCenter, GetRect, GetScaledRect and GetPoint with nothing", function()
	local w, r = world()
	local env = r.env
	local f = env.CreateFrame("Frame", nil, env.UIParent) -- no SetPoint: unplaced
	local fs = f:CreateFontString(nil, "OVERLAY")
	local tex = f:CreateTexture(nil, "ARTWORK")
	local placed = env.CreateFrame("Frame", nil, env.UIParent)
	placed:SetPoint("CENTER")
	local cases = {}
	for _, o in ipairs({ { "Frame", f }, { "FontString", fs }, { "Texture", tex } }) do
		for _, m in ipairs({ "GetLeft", "GetRight", "GetTop", "GetBottom", "GetCenter", "GetRect", "GetScaledRect", "GetPoint" }) do
			local obj = o[2]
			cases[#cases + 1] = { o[1] .. ":" .. m, function() return obj[m](obj, 1) end }
		end
	end
	-- a placed frame has no second anchor: GetPoint(2) is the same empty case
	cases[#cases + 1] = { "placed Frame:GetPoint(2)", function() return placed:GetPoint(2) end }
	allNothing(cases)
	T.clean(w)
end)

-- guard: a placed region still answers numbers (the empty case is the only one that changes)
test("fga a guard: a placed region still answers its edges, its centre and its anchor", function()
	local w, r = world()
	local env = r.env
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	f:SetSize(100, 50)
	f:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 10, 20)
	eq(f:GetLeft(), 10, "GetLeft")
	eq(f:GetBottom(), 20, "GetBottom")
	eq(count(f:GetRect()), 4, "GetRect gives four values")
	eq(count(f:GetCenter()), 2, "GetCenter gives two values")
	eq(count(f:GetPoint(1)), 5, "GetPoint gives five values")
	T.clean(w)
end)

-- guard: infra, failed before because the fake harness answered one nil (or a table) where the game answers no values
test("fga a C_Map answers nothing for a map the game does not know", function()
	local w, r = world()
	local CM, vec = r.env.C_Map, r.env.CreateVector2D
	local NO = 999999
	allNothing({
		{ "C_Map.GetMapInfo", function() return CM.GetMapInfo(NO) end },
		{ "C_Map.GetMapChildrenInfo", function() return CM.GetMapChildrenInfo(NO) end },
		{ "C_Map.GetMapArtLayers", function() return CM.GetMapArtLayers(NO) end },
		{ "C_Map.GetMapArtLayerTextures", function() return CM.GetMapArtLayerTextures(NO, 1) end },
		{ "C_Map.GetMapInfoAtPosition", function() return CM.GetMapInfoAtPosition(NO, 0.5, 0.5) end },
		{ "C_Map.GetWorldPosFromMapPos", function() return CM.GetWorldPosFromMapPos(NO, vec(0.5, 0.5)) end },
		{ "C_Map.GetMapPosFromWorldPos", function() return CM.GetMapPosFromWorldPos(NO, vec(0.5, 0.5)) end },
	})
	T.clean(w)
end)

-- guard: infra, failed before because the fake harness answered one nil (or a table) where the game answers no values
test("fga a C_Spell answers nothing for a spell the game does not know", function()
	local w, r = world()
	local CS = r.env.C_Spell
	local NO = 1 -- (not a spell id of this game)
	allNothing({
		{ "C_Spell.GetSpellName", function() return CS.GetSpellName(NO) end },
		{ "C_Spell.GetSpellInfo", function() return CS.GetSpellInfo(NO) end },
		{ "C_Spell.GetSpellCooldown", function() return CS.GetSpellCooldown(NO) end },
	})
	T.clean(w)
end)

-- guard: infra, failed before because the fake harness answered one nil (or a table) where the game answers no values
test("fga a UnitClass answers nothing for a unit that is not there", function()
	local w, r = world()
	allNothing({ { "UnitClass('party4')", function() return r.env.UnitClass("party4") end } })
	T.clean(w)
end)

-- guard: the known cases still answer (a unit that is there, the map the player is on, the ritual spell the Warlock knows)
test("fga a guard: UnitClass of the player and C_Map.GetMapInfo of the player's map still answer", function()
	local w, r = world()
	eq(count(r.env.UnitClass("player")), 3, "UnitClass(player): name, file, id")
	local map = r.env.C_Map.GetBestMapForUnit("player")
	ok(type(map) == "number", "the player is on a map")
	eq(count(r.env.C_Map.GetMapInfo(map)), 1, "GetMapInfo(that map): one table")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- The sweep: the test that would have caught 21 Nov
---------------------------------------------------------------------------

-- Every position getter of every region the addon makes answers NOTHING when the region is not placed (the game's way), for the
-- whole of a login, every tab of both windows, Settings, and one ride. Wuber must raise no Lua error. The wrapper is installed on
-- the fake's widget factory before the world exists, so UIParent and every region the addon creates carry it; it changes only
-- the empty case, so nothing else in the run differs. (When tests/harness.lua gets the switch H.noValueGetters the wrapper
-- below is the switch's own code and this test only turns it on.)
local GETTERS = { "GetLeft", "GetRight", "GetTop", "GetBottom", "GetCenter", "GetRect", "GetScaledRect", "GetPoint" }
local function pack(...) return { n = select("#", ...), ... } end

local function installNoValue(fired)
	local real = H.newWidget
	H.newWidget = function(...)
		local obj = real(...)
		for _, name in ipairs(GETTERS) do
			local orig = obj[name]
			if type(orig) == "function" then
				rawset(obj, name, function(self, ...)
					local r = pack(orig(self, ...))
					if r[1] == nil then
						fired[name] = (fired[name] or 0) + 1
						return
					end
					return unpack(r, 1, r.n)
				end)
			end
		end
		return obj
	end
	return function() H.newWidget = real end
end

-- guard: the sweep's own wrapper really makes tonumber(f:GetLeft()) throw, as it did in game on 21 Nov
test("fga a guard: with the sweep's wrapper tonumber(unplacedFrame:GetLeft()) raises 'value expected', as in the game", function()
	local fired = {}
	local restore = installNoValue(fired)
	local good, err = pcall(function()
		local w, r = world()
		local f = r.env.CreateFrame("Frame", nil, r.env.UIParent)
		local okCall, msg = pcall(function() return tonumber(f:GetLeft()) end)
		ok(not okCall and tostring(msg):find("value expected", 1, true), "tonumber of nothing raises: " .. tostring(msg))
		eq(count(f:GetLeft()), 0, "GetLeft gives nothing")
		T.clean(w)
	end)
	restore()
	if not good then error(err, 0) end
end)

-- guard: today Wuber is clean (the 21 Nov bug is fixed in code); this keeps it so, and finds the next unguarded call at once
test("fga a sweep: Wuber's login, every tab, Settings and one ride raise no Lua error while every position getter answers nothing when unplaced", function()
	local fired = {}
	local restore = installNoValue(fired)
	local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA)
		local r = T.rider(w, T.TESTCHAR)
		T.settle(w)
		for _, c in ipairs({ r, d }) do
			local UI = c.W.UI
			UI.Toggle(true)
			w:advance(2)
			for _, tab in ipairs((UI.state and UI.state.tabs) or {}) do
				UI.SelectTab(tab.name)
				w:advance(1)
			end
			if UI.OpenSettings then UI.OpenSettings() w:advance(1) UI.CloseSettings() w:advance(1) end
		end
		T.goOnline(d)
		T.requestVia(r, "anita lift")
		w:advance(2)
		T.take(d)
		w:advance(30)
		local n = 0
		for _, v in pairs(fired) do n = n + v end
		-- (a note, not a failure: whether Wuber asks an unplaced region in this run is Wuber's business)
		print(("      sweep: the wrapper answered nothing %d times (%s)"):format(n, (function() local t = {} for k, v in pairs(fired) do t[#t + 1] = k .. " " .. v end table.sort(t) return table.concat(t, ", ") end)()))
		T.clean(w)
	end)
	restore()
	if not good then error(err, 0) end
end)

-- guard: infra, failed before because the fake harness answered one nil (or a table) where the game answers no values
test("fga a C_Map.GetMapInfoAtPosition names the child map under a point and nothing elsewhere; GetPointByName answers a set anchor, nothing otherwise", function()
	local w, r = world()
	local env = r.env
	local CM = env.C_Map
	local l, rt, t, b = CM.GetMapRectOnMap(1411, 1414)
	local info = CM.GetMapInfoAtPosition(1414, (l + rt) / 2, (t + b) / 2)
	ok(info and info.mapID, "a point inside Durotar's rect finds a child map")
	eq(count(CM.GetMapInfoAtPosition(1414, -5, -5)), 0, "a point outside every child gives nothing")
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	eq(count(f:GetPointByName("CENTER")), 0, "unplaced frame: nothing")
	f:SetPoint("CENTER", env.UIParent, "CENTER", 3, 4)
	eq(select(3, f:GetPointByName("CENTER")), "CENTER", "relative point")
	eq(count(f:GetPointByName("TOP")), 0, "an anchor that is not set: nothing")
	T.clean(w)
end)
