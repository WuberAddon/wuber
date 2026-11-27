-- Multibox safety, cooldowns kept in the saved variables: the advert gap, the auto-reply hour and the self-sent lines
-- must survive a /reload and a relog of an own window, and no automatic action may exist that the tests do not know.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local M = dofile(T.dir .. "/multibox/mb.lua")(T)
local ANITA, ANA = T.ANITA, T.ANA

test("multibox cooldown: the advert gap is saved: a reload or relog does not open a second advert", function()
	local w, cs = M.windows({ ANITA })
	local W1 = cs[1].W
	local plan = W1.AdvertPlan("Orgrimmar", 50000, {})
	ok(plan, "setup: the first advert can be planned")
	W1.AdvertPosted(plan)
	local nc = w:reload(cs[1])
	w:advance(20)
	local plan2, why, wait = nc.W.AdvertPlan("Orgrimmar", 50000, {})
	ok(plan2 == nil and (tonumber(wait) or 0) > 0, "after a reload the advert still waits (" .. tostring(why) .. ", " .. tostring(wait) .. ")")
	local rc = M.relog(w, nc)
	w:advance(20)
	local plan3, why3, wait3 = rc.W.AdvertPlan("Orgrimmar", 50000, {})
	ok(plan3 == nil and (tonumber(wait3) or 0) > 0, "after a relog the advert still waits (" .. tostring(why3) .. ", " .. tostring(wait3) .. ")")
	T.clean(w)
end)

test("multibox cooldown: the auto-reply hour is in the saved variables and stays after relog", function()
	local w, cs = M.windows({ ANITA })
	M.ask(w, "Dan Miller")
	eq(M.replies(w, "Dan Miller"), 1, "setup: one whisper")
	local rc = M.relog(w, cs[1])
	w:advance(20)
	rc.W.Drive.SetOpen(true)
	w:advance(3)
	local r = rc.env.WuberDB.drive.replied
	ok(type(r) == "table" and type(r[M.key("Dan Miller")]) == "number", "the stamp survived the relog")
	M.ask(w, "Dan Miller")
	eq(M.replies(w, "Dan Miller"), 1, "no second whisper after the relog")
	w:advance(3600)
	M.ask(w, "Dan Miller")
	eq(M.replies(w, "Dan Miller"), 2, "an hour later the stranger may be answered again")
	T.clean(w)
end)

test("multibox cooldown: two reloads in a row never whisper the same stranger twice", function()
	local w, cs = M.windows({ ANITA })
	M.ask(w, "Dan Miller")
	eq(M.replies(w, "Dan Miller"), 1, "setup: one whisper")
	-- the same window reloads twice in a row, the second time without the stranger asking in between
	local nc = w:reload(cs[1])
	w:advance(20)
	nc = w:reload(nc)
	w:advance(20)
	nc.W.Drive.SetOpen(true)
	w:advance(3)
	M.ask(w, "Dan Miller")
	eq(M.replies(w, "Dan Miller"), 1, "two reloads in a row: still one whisper")
	T.clean(w)
end)

test("multibox cooldown: Wuber has no auto-emote: no DoEmote anywhere in the addon", function()
	local found, n = {}, 0
	local toc = T.readFile(T.dir .. "/../Wuber/Wuber.toc") or ""
	for line in toc:gmatch("[^\r\n]+") do
		if line:match("%.lua%s*$") then
			local src = T.readFile(T.dir .. "/../Wuber/" .. line:gsub("\\", "/"):gsub("%s+$", ""))
			if src then
				n = n + 1
				if src:find("DoEmote", 1, true) or src:find("\"EMOTE\"", 1, true) then found[#found + 1] = line end
			end
		end
	end
	ok(n > 50, "the test read the TOC's files (" .. n .. ")")
	eq(#found, 0, "files with an emote call: " .. table.concat(found, ", "))
end)
