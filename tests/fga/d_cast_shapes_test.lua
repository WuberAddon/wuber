-- fga d: cast, unit and client shapes (round fga, job 2611, from proposal 15). Names start "fga d ".
--
-- Real client (Blizzard UI source, branch forever, commit 734f065; base = https://github.com/Gethe/wow-ui-source/blob/734f065/Interface/AddOns/Blizzard_APIDocumentationGenerated):
--   UnitCastingInfo, 11 returns, castingSpellID 9th:  base/UnitDocumentation.lua#L827-L852   (name, displayName, textureID, startTimeMs, endTimeMs, isTradeskill, castID,
--                                                       notInterruptible, castingSpellID, castBarID, delayTimeMs)
--   UnitChannelInfo, 11 returns, spellID 8th:         base/UnitDocumentation.lua#L869-L894   (name, displayName, textureID, startTimeMs, endTimeMs, isTradeskill,
--                                                       notInterruptible, spellID, isEmpowered, numEmpowerStages, castBarID)
--   UNIT_SPELLCAST_START / SUCCEEDED / CHANNEL_START (unitTarget, castGUID, spellID, castBarID): UnitDocumentation.lua#L4816-L4829, #L4844-L4857, #L4612-L4625
--   UNIT_SPELLCAST_CHANNEL_STOP / INTERRUPTED add interruptedBy before castBarID: #L4626-L4640, #L4741-L4755
--   GROUP_JOINED / GROUP_LEFT (category, partyGUID): PartyInfoDocumentation.lua#L655-L676;  ADDON_LOADED (addOnName, containsBindings): AddOnsDocumentation.lua#L388-L398
--   GetBuildInfo, 6 returns: BuildDocumentation.lua#L9-L22;  WOW_PROJECT_CAMELOT = 18, WOW_PROJECT_ID = WOW_PROJECT_CAMELOT:
--   https://github.com/Gethe/wow-ui-source/blob/734f065/Interface/AddOns/Blizzard_ProjectConstants/Camelot/ProjectConstants.lua#L1-L2 (loaded for the camelot game type: Blizzard_ProjectConstants.toc#L7)
--   The summon box of a dead player: .../Blizzard_StaticPopup_Game/GameDialog.lua#L907-L912 and .../Blizzard_StaticPopup/StaticPopup.lua#L332-L338, CONFIRM_SUMMON has no whileDead:
--   .../Blizzard_StaticPopup_Game/GameDialogDefs.lua#L2453-L2479 (OnCancel calls C_SummonInfo.CancelSummon)
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function pack(...) return { n = select("#", ...), ... } end

-- problems of one list of values against a list of wanted types; "boolean?" means a boolean or nil. required = the last non-optional slot.
local function shapeBad(label, p, want, exact)
	local out = {}
	local req = 0
	for i, t in ipairs(want) do if t:sub(-1) ~= "?" then req = i end end
	if exact and p.n ~= #want then
		out[#out + 1] = label .. ": " .. p.n .. " values, wants " .. #want
	elseif p.n < req then
		out[#out + 1] = label .. ": " .. p.n .. " values, wants at least " .. req
	end
	for i, t in ipairs(want) do
		local optional = t:sub(-1) == "?"
		local base = optional and t:sub(1, -2) or t
		local v = p[i]
		if not (type(v) == base or (optional and v == nil)) then out[#out + 1] = label .. " #" .. i .. " is " .. type(v) .. " (wants " .. t .. ")" end
	end
	return out
end

-- a Warlock (Anita Lift, Ratchet) in a group with Dan Miller (Orgrimmar), ready to cast the ritual on him
local function ritualWorld()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:group({ T.ANITA, "Dan Miller" })
	T.settle(w)
	w:player(T.ANITA).target = w:player("Dan Miller")
	return w, d
end

local CASTING = { "string", "string", "number", "number", "number", "boolean", "string", "boolean?", "number", "number?", "number" }
local CHANNEL = { "string", "string", "number", "number", "number", "boolean", "boolean?", "number", "boolean", "number", "number?" }

-- -- (tests/harness.lua:5516-5527). Real-game support: other addons on this client read it the same way (Polestar Core/Engine.lua:14318-14320 select(9, UnitCastingInfo("player")); ConsolePort
-- Targetring.lua:452-453 positions 1, 4, 5), and our own recorder reads the 9th (WuberRec/Snaps.lua:464). Wuber: DR.Travelling reads the 8th and 9th (Wuber/Drive/Queue.lua:1474-1479).
test("fga d UnitCastingInfo and UnitChannelInfo return the documented 11 values with the spell id in the 9th / 8th", function()
	local w, d = ritualWorld()
	local env = d.env
	w:cast(d, w.ritualName)
	w:advance(0.2) -- the cast stage lasts 0.5 s (tests/harness.lua:4255)
	local cast = pack(env.UnitCastingInfo("player"))
	local bad = shapeBad("UnitCastingInfo", cast, CASTING, true)
	if #bad == 0 then
		eq(cast[9], 698, "UnitCastingInfo castingSpellID (9th)")
		ok(cast[5] > cast[4], "UnitCastingInfo endTimeMs is after startTimeMs")
	end
	w:advance(0.6) -- now the channel stage
	local chan = pack(env.UnitChannelInfo("player"))
	local bad2 = shapeBad("UnitChannelInfo", chan, CHANNEL, false)
	if #bad2 == 0 then eq(chan[8], 698, "UnitChannelInfo spellID (8th)") end
	for _, b in ipairs(bad2) do bad[#bad + 1] = b end
	ok(#bad == 0, table.concat(bad, "; "))
	T.clean(w)
end)

-- PROOF (fails today: FAKE MISSING World:castTravel). The behaviour a player relies on: a driver who casts Hearthstone (or a teleport) is about to leave, and Wuber must see it by the spell id
-- (Wuber/Drive/Queue.lua:1469-1483 DR.Travelling; the name path only works for English clients: "hearthstone", "astral recall", "teleport:"). A German client's Hearthstone is "Ruhestein".
-- The fake has no way to make a client cast anything but the ritual. Proposed: World:castTravel(client, spellID, seconds, localizedName): UnitCastingInfo("player") returns the 11 values
-- with that id and name for that long, UNIT_SPELLCAST_SENT / START at the start and SUCCEEDED at the end (or INTERRUPTED if the player moves: not needed here).
test("fga d a driver casting Hearthstone is seen as travelling by Wuber, by the spell id, whatever the client's language", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	local DR = d.W.Drive
	eq(DR.Travelling(), false, "control: nobody casts anything")
	ok(type(w.castTravel) == "function", "FAKE MISSING: World:castTravel(client, spellID, seconds, localizedName) (README of 15, item e)")
	w:castTravel(d, 8690, 10, "Ruhestein")
	w:advance(0.5)
	eq(DR.Travelling(), true, "DR.Travelling() while the driver casts Hearthstone (8690) under a name Wuber does not know")
	w:advance(11)
	eq(DR.Travelling(), false, "the cast is over")
	T.clean(w)
	-- the cast ends by a timer: seen at 1 s and at 5 s steps
	for _, step in ipairs({ 1, 5 }) do
		local w2 = T.newWorld()
		local d2 = T.driver(w2, T.ANITA)
		T.settle(w2)
		w2:castTravel(d2, 556, 9, "Astralrückruf")
		w2:advance(step)
		eq(d2.W.Drive.Travelling(), true, "still casting after the first " .. step .. " s step")
		for _ = 1, 12 / step do w2:advance(step) end
		eq(d2.W.Drive.Travelling(), false, "cast over after steps of " .. step .. " s")
		T.clean(w2)
	end
end)

-- -- in their label and pass today (UNIT_SPELLCAST_SENT / START / SUCCEEDED / CHANNEL_START, GROUP_LEFT). The failing rows (today): WOW_PROJECT_ID / WOW_PROJECT_CAMELOT, GetBuildInfo count,
-- ADDON_LOADED's second value, GROUP_JOINED's two values, CHANNEL_STOP / INTERRUPTED's interruptedBy.
-- NOT asserted: PARTY_INVITE_REQUEST's slot order (contested, see the README and the fixture test below); GROUP_FORMED (the fake never fires it; when the real client does is unknown).
test("fga d constants and payloads have the documented shapes", function()
	local bad = {}
	local function add(list) for _, b in ipairs(list) do bad[#bad + 1] = b end end
	-- A. WOW_PROJECT_ID and GetBuildInfo, ADDON_LOADED (a frame made before the addons load), GROUP_JOINED / GROUP_LEFT
	local loaded = {}
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR, { prepare = function(env)
		local f = env.CreateFrame("Frame")
		f:RegisterEvent("ADDON_LOADED")
		f:SetScript("OnEvent", function(_, _, ...) loaded[#loaded + 1] = pack(...) end)
	end })
	local env = r.env
	if env.WOW_PROJECT_ID ~= 18 then bad[#bad + 1] = "WOW_PROJECT_ID is " .. tostring(env.WOW_PROJECT_ID) .. ", wants 18 (WOW_PROJECT_CAMELOT)" end
	if env.WOW_PROJECT_CAMELOT ~= 18 then bad[#bad + 1] = "WOW_PROJECT_CAMELOT is " .. tostring(env.WOW_PROJECT_CAMELOT) .. ", wants 18" end
	add(shapeBad("GetBuildInfo", pack(env.GetBuildInfo()), { "string", "string", "string", "number", "string", "string" }, true))
	if #loaded == 0 then bad[#bad + 1] = "ADDON_LOADED: the test saw none" end
	for i, p in ipairs(loaded) do add(shapeBad("ADDON_LOADED #" .. i, p, { "string", "boolean" }, true)) end
	local group = {}
	local gf = env.CreateFrame("Frame")
	gf:RegisterEvent("GROUP_JOINED")
	gf:RegisterEvent("GROUP_LEFT")
	gf:SetScript("OnEvent", function(_, ev, ...) group[ev] = group[ev] or pack(...) end)
	T.settle(w)
	w:group({ T.TESTCHAR, T.ANITA })
	w:advance(0.2)
	w:leave(T.ANITA)
	w:advance(0.2)
	if group.GROUP_JOINED then add(shapeBad("GROUP_JOINED", group.GROUP_JOINED, { "number", "string" }, true)) else bad[#bad + 1] = "GROUP_JOINED: never fired" end
	if group.GROUP_LEFT then add(shapeBad("GROUP_LEFT (guard: the real capture of 22 Nov gave 1, '<->')", group.GROUP_LEFT, { "number", "string" }, true)) else bad[#bad + 1] = "GROUP_LEFT: never fired" end
	T.clean(w)
	-- B. the cast events of a ritual: one cut short while it is cast, one cut short while it channels
	local w2, d2 = ritualWorld()
	local got = {}
	local f = d2.env.CreateFrame("Frame")
	for _, ev in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START",
		"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED" }) do f:RegisterEvent(ev) end
	f:SetScript("OnEvent", function(_, ev, ...) got[ev] = got[ev] or pack(...) end)
	w2:cast(d2, w2.ritualName)
	w2:advance(0.2)
	w2:cancelRitual(T.ANITA) -- stage "cast": UNIT_SPELLCAST_INTERRUPTED
	w2:advance(1)
	w2:cast(d2, w2.ritualName)
	w2:advance(0.7)
	w2:cancelRitual(T.ANITA) -- stage "channel": UNIT_SPELLCAST_CHANNEL_STOP
	w2:advance(0.2)
	local ROWS = {
		{ "UNIT_SPELLCAST_SENT (guard)", { "string", "string", "string", "number" } }, -- unitTarget, target, castGUID, spellID (UnitDocumentation.lua#L4805-L4815)
		{ "UNIT_SPELLCAST_START (guard)", { "string", "string", "number", "number?" } },
		{ "UNIT_SPELLCAST_SUCCEEDED (guard)", { "string", "string", "number", "number?" } },
		{ "UNIT_SPELLCAST_CHANNEL_START (guard)", { "string", "string", "number", "number?" } },
		{ "UNIT_SPELLCAST_CHANNEL_STOP", { "string", "string", "number", "string", "number?" } },
		{ "UNIT_SPELLCAST_INTERRUPTED", { "string", "string", "number", "string", "number?" } },
	}
	for _, row in ipairs(ROWS) do
		local ev = row[1]:match("^(%S+)")
		if got[ev] then add(shapeBad(row[1], got[ev], row[2], false)) else bad[#bad + 1] = ev .. ": never fired" end
	end
	T.clean(w2)
	ok(#bad == 0, #bad .. " shape problem(s): " .. table.concat(bad, "; "))
end)


-- guard: the rider's side of the neighbouring paths (the first value of the cast getters is still the name; an English-named Hearthstone is still seen)
test("fga d guard: UnitCastingInfo and UnitChannelInfo still answer the ritual name first and nothing when idle", function()
	local w, d = ritualWorld()
	eq(d.env.UnitCastingInfo("player"), nil, "idle: no cast")
	eq(d.env.UnitChannelInfo("player"), nil, "idle: no channel")
	w:cast(d, w.ritualName)
	w:advance(0.2)
	eq((d.env.UnitCastingInfo("player")), w.ritualName, "casting: the name first")
	w:advance(1)
	eq((d.env.UnitChannelInfo("player")), w.ritualName, "channelling: the name first")
	eq(d.env.UnitCastingInfo("player"), nil, "no longer casting")
	T.clean(w)
end)

-- the 11 values are the same at steps of 1 s and 5 s: the cast stage is gone, the channel stage answers
test("fga d channel stage is seen after one 1 s step and after one 5 s step", function()
	for _, step in ipairs({ 1, 5 }) do
		local w, d = ritualWorld()
		w:cast(d, w.ritualName)
		w:advance(step)
		local c = pack(d.env.UnitChannelInfo("player"))
		eq(c.n, 11, "UnitChannelInfo values after a " .. step .. " s step")
		eq(c[8], 698, "spell id")
		T.clean(w)
	end
end)

-- guard: GetBuildInfo's first four values are unchanged (Wuber reads the 2nd and 4th)
test("fga d guard: GetBuildInfo still starts 1.60.1 / 71037 / date / 16001", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local v, b, _, i = r.env.GetBuildInfo()
	eq(v, "1.60.1", "version")
	eq(b, "71037", "build")
	eq(i, 16001, "interface")
	T.clean(w)
end)

-- TAXIMAP_OPENED carries the system number; TRADE_TARGET_ITEM_CHANGED carries the slot only
test("fga d TAXIMAP_OPENED has one value and TRADE_TARGET_ITEM_CHANGED has one value", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	local got = {}
	local f = r.env.CreateFrame("Frame")
	f:RegisterEvent("TAXIMAP_OPENED")
	f:RegisterEvent("TRADE_TARGET_ITEM_CHANGED")
	f:SetScript("OnEvent", function(_, ev, ...) got[ev] = got[ev] or pack(...) end)
	T.settle(w)
	w:openTaxi(r, { { name = "Ratchet, The Barrens", type = "CURRENT", cost = 0 } })
	ok(got.TAXIMAP_OPENED, "TAXIMAP_OPENED fired")
	if got.TAXIMAP_OPENED then
		eq(got.TAXIMAP_OPENED.n, 1, "TAXIMAP_OPENED values")
		eq(type(got.TAXIMAP_OPENED[1]), "number", "system is a number")
	end
	w:openTrade(w:player(T.ANITA), w:player(T.TESTCHAR))
	w:advance(0.5)
	ok(got.TRADE_TARGET_ITEM_CHANGED, "TRADE_TARGET_ITEM_CHANGED fired")
	if got.TRADE_TARGET_ITEM_CHANGED then
		eq(got.TRADE_TARGET_ITEM_CHANGED.n, 1, "TRADE_TARGET_ITEM_CHANGED values")
		ok(got.TRADE_TARGET_ITEM_CHANGED[1] >= 1 and got.TRADE_TARGET_ITEM_CHANGED[1] <= 7, "a slot index")
	end
	T.clean(w)
end)
