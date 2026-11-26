-- Tests of UI.Driver.Rows (round 13, agent B: Google's in-game screenshot findings). Loaded by
-- tests/run.lua with its helper table T. What a queue row says: waits read as a clock ("0:30"),
-- never like a price ("30s" looked like 30 silver next to "owes 50s" and on free raid summons).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function driver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	return w, a, a.W
end

test("ui.driver.rows: I17 waits read as a stopwatch (0:30, 1:10, 12 min), never like silver (30s)", function()
	local w, a, W = driver()
	local D = W.Driver
	local t = 10000
	local _, r1 = D.DescribeRaid({ name = "Dan Rider", asked = t - 30, state = "queued", tries = 0 }, t)
	eq(r1, "0:30", "a raider who asked 30 s ago")
	local _, r2 = D.DescribeRaid({ name = "Gus Hill", asked = t - 70, state = "queued", tries = 1 }, t)
	eq(r2, "1:10", "70 s")
	local _, r3 = D.DescribeRaid({ name = "Ivy Moss", asked = t - 5, state = "summoning", claimedBy = W.myKey }, t)
	eq(r3, "0:05", "5 s, two digits")
	local _, q1 = D.Describe({ name = "Eve Night", state = "queued", at = t - 725 }, t)
	eq(q1, "12 min", "a queued rider: 12 min 5 s (from 10 min, minutes: 12:05 looked like a time of day)")
	local _, q4 = D.Describe({ name = "Eve Night", state = "queued", at = t - 245 }, t)
	eq(q4, "4:05", "4 min 5 s")
	local _, q2 = D.Describe({ name = "Eve Night", state = "invited", invitedAt = t - 50 }, t)
	eq(q2, "0:50", "invited 50 s ago")
	local _, q3 = D.Describe({ name = "Eve Night", state = "waiting", endAt = t - 9 }, t)
	eq(q3, "0:09", "the summon window")
	for _, x in ipairs({ r1, r2, r3, q1, q2, q3, q4 }) do ok(not x:find("%ds$"), x .. " has no s for seconds") end
	T.clean(w)
end)


-- (BRIEF22 P2) a lead's row: '"Any summons to loch modan?" · in...' was cut (the lab: width 219). The words
-- fit at every row width, the whole quote or a shorter form, never cut
test("ui.driver.rows: P2 a lead's chat line fits its row at every width, never cut", function()
	local w, a, W = driver()
	local D, H = W.Driver, T.H
	local parent = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	parent:SetSize(400, 200)
	parent:SetPoint("CENTER")
	parent:Show()
	local msgs = { "Any summons to loch modan?", "LF summon to Orgrimmar please, anyone around? paying well" }
	local shown = {}
	for _, wdt in ipairs({ 340, 284, 260, 240 }) do
		for _, msg in ipairs(msgs) do
			for _, src in ipairs({ "public", "whisper" }) do
				local r = D.Row(parent, wdt)
				r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
				local c = { name = "Zep Ashrender", state = "lead", source = src, msg = msg, at = 1000 }
				D.PaintRow(r, c, 1000)
				local text = r.what:GetText() or ""
				local where = wdt .. " " .. src .. " " .. msg .. ": " .. text
				ok(H.truncation(r.what) == nil, "not cut at " .. where)
				ok(not r.what:IsTruncated(), "the game says not cut at " .. where)
				ok(not text:find("...", 1, true), "no dots at " .. where)
				local quoted = text:match('"(.*)"')
				ok(quoted == nil or quoted == msg, "a quote is the whole line, never a part: " .. where)
				shown[wdt .. src .. msg] = text
				r:Hide()
			end
		end
	end
	-- (design 3: Inter is narrower than Poppins, so the quote and where it was said now fit the row's full width)
	eq(shown["340public" .. msgs[1]], ' · "Any summons to loch modan?" · in chat', "the console row: the whole quote and where it was said")
	eq(shown["284public" .. msgs[1]], ' · "Any summons to loch modan?"', "the mini console: the whole quote (design 1 J: the Options button drops to the second line, the words keep the width; design 3: in Inter the quote fits it)")
	eq(shown["260public" .. msgs[2]], " · asked for Orgrimmar", "a long line: the place it asks for")
	eq(shown["240public" .. msgs[2]], " · asked for Orgrimmar", "the narrowest: the place (design 1 J: the Options button drops to the second line, the words keep the width)")
	T.clean(w)
end)
