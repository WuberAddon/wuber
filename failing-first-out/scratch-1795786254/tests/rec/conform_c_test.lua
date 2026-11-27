-- Conformance of the fake game to the facts the real client showed in Lab game-facts runs 1 to 3
-- (the Lab's proven-facts list PF-041..065 and run 3 "Game facts"). Each test failed on the fake before its fix.
local T = ...
local test, eq, ok = T.testOutside or T.test, T.eq, T.ok
local L = dofile(T.dir .. "/rec/real_lib.lua")

-- K4 (build 71037): GetCVar("screenshotFormat") is "jpeg" and its default is "jpeg"
test("rec conform c: screenshotFormat reads jpeg, default jpeg (K4)", function()
	local w = T.newWorld()
	local r = T.rider(w, "Wuber Rocks", { spot = "Orgrimmar" })
	w:advance(1)
	eq(r.env.GetCVar("screenshotFormat"), "jpeg", "the real game answers jpeg")
	eq(r.env.GetCVarDefault("screenshotFormat"), "jpeg", "its default is jpeg")
end)

-- L5.notice (PF-046): the one who creates a channel is told OWNER_CHANGED and SET_MODERATOR (NOTICE_USER)
test("rec conform c: creating a channel brings OWNER_CHANGED and SET_MODERATOR notices (L5.notice)", function()
	local w = T.newWorld()
	local r = T.rider(w, "Wuber Rocks", { spot = "Orgrimmar" })
	w:advance(6)
	local e = r.env
	local rec = L.record(w, r, L.set({ "CHAT_MSG_CHANNEL_NOTICE_USER" }))
	e.JoinTemporaryChannel("ConformNet")
	w:advance(2)
	local seen = {}
	for _, x in ipairs(rec.list) do
		if tostring(x[6]):find("ConformNet", 1, true) then seen[#seen + 1] = x[3] end -- (Wuber's own channel joins on its own clock)
	end
	eq(table.concat(seen, ","), "OWNER_CHANGED,SET_MODERATOR", "the creator's notices")
	-- a second client joining the existing channel gets none
	local r2 = T.rider(w, "Farra Way", { spot = "Orgrimmar" })
	w:advance(6)
	local rec2 = L.record(w, r2, L.set({ "CHAT_MSG_CHANNEL_NOTICE_USER" }))
	r2.env.JoinTemporaryChannel("ConformNet")
	w:advance(2)
	local n2 = 0
	for _, x in ipairs(rec2.list) do if tostring(x[6]):find("ConformNet", 1, true) then n2 = n2 + 1 end end
	eq(n2, 0, "a later joiner is not made owner")
end)
