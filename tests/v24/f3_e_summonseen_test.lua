-- Wuber 2.4 fix round 3, group E, part 1: the game's own word on a group member's summon (C_IncomingSummon), shown on
-- the driver's console row for a rider WITHOUT Wuber: has the summon window, summon accepted, summon declined.
-- Sources (ideas only): the addon-learning notes FAKE-GAME-HINTS 40, LEARN-REPORT lesson 2 (SteaSummonForever 1.0.3
-- summon.lua:467-473, 1008-1016). Nothing of this is proven in game (Lab check L1), so the rules are tested too:
-- a rider with Wuber keeps today's row, an answer older than the latest cast is ignored, a secret or missing
-- answer changes nothing. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"
local SPOT = "Undercity"
local DECLINED, ACCEPTED, WINDOW = "declined: summon again?", "summon accepted", "has the summon window"

-- a Warlock driver with two helpers, and Dan (no Wuber, answers his summon box by hand) in the group, far away
local function setup(opts)
	opts = opts or {}
	local w = T.newWorld({ incomingSummon = opts.api ~= false })
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	w:addBot("Bob Helper", { spot = SPOT })
	w:addBot("Bo Second", { spot = SPOT })
	w:group({ ANITA, "Bob Helper", "Bo Second" })
	w:advance(1)
	local DR = lock.W.Drive
	DR.SetOpen(true)
	w:advance(2)
	w:addBot("Dan Moss", { spot = "Orgrimmar", acceptsSummon = false })
	w:botWhisper("Dan Moss", lock, "summon pls")
	w:advance(3)
	local c = DR.Find("Dan Moss")
	ok(c and c.state == "joined", "Dan is in the group, ready to summon: " .. tostring(c and c.state))
	return w, lock, DR, c
end

-- the big button casts on Dan; both helpers click the portal; Dan has the summon box
local function summon(w, lock, DR)
	local b = lock.env.WuberDriveButton
	ok(b and H.visible(b), "the big button is shown")
	lock:click(b)
	w:advance(3)
	ok(w:clickPortal("Bob Helper"), "Bob clicks the portal")
	ok(w:clickPortal("Bo Second"), "Bo clicks the portal")
	w:advance(2.5)
	local c = DR.Find("Dan Moss")
	eq(c and c.state, "waiting", "the ritual is done: Dan has the summon window")
	return c
end

local function says(lock, c) return (lock.W.Driver.Describe(c)) end

test("v24 f3 e summon seen: a rider without Wuber who declines reads 'declined: summon again?'", function()
	local w, lock, DR = setup()
	local c = summon(w, lock, DR)
	eq(says(lock, c), WINDOW, "the box is up: today's words, the same fact")
	ok(w:answerSummon("Dan Moss", false), "Dan declines")
	w:advance(2)
	eq(c.state, "waiting", "nothing in the engine changes: the driver decides")
	eq(says(lock, c), DECLINED, "the row says he declined")
	local _, right, colour = lock.W.Driver.Describe(c)
	eq(right, "", "no stopwatch beside it")
	eq(colour, "red", "red, as a raid row's 'summon again' (design round 1: amber is only the big button)")
	-- the game stops saying it after a couple of minutes: back to what the row says today
	w:advance(H.SUMMON_STICKY + 2)
	ok(says(lock, c) ~= DECLINED, "once the game stops saying declined, so does the row: " .. tostring(says(lock, c)))
	T.clean(w)
end)

test("v24 f3 e summon seen: a rider without Wuber who accepts reads 'summon accepted' until he lands", function()
	local w, lock, DR = setup()
	local c = summon(w, lock, DR)
	ok(w:answerSummon("Dan Moss", true), "Dan accepts")
	w:advance(1.2)
	eq(c.state, "waiting", "still on his way (the loading screen)")
	eq(says(lock, c), ACCEPTED, "the row says he accepted")
	w:advance(4)
	eq(c.state, "arrived", "he landed: the row is the arrived row again")
	ok(says(lock, c) ~= ACCEPTED, "an arrived row says what it says today: " .. tostring(says(lock, c)))
	T.clean(w)
end)

test("v24 f3 e summon seen: an answer older than the driver's latest cast on that rider is ignored", function()
	local w, lock, DR = setup()
	local c = summon(w, lock, DR)
	w:answerSummon("Dan Moss", false)
	w:advance(2)
	eq(says(lock, c), DECLINED, "control: the first summon was declined")
	-- the driver summons again (a click on the row), and this ritual is dropped before anyone clicks the portal:
	-- the game still says "declined" (the first summon's answer), which says nothing about the second
	lock.W.Driver.RowAction(c, "next")
	w:advance(1)
	eq(c.state, "joined", "summon this one next")
	eq(says(lock, c), DECLINED, "still the fresh answer while nothing new was cast")
	lock:click(lock.env.WuberDriveButton)
	w:advance(1)
	eq(c.state, "summoning", "the second cast is on its way")
	w:cancelRitual()
	w:advance(3)
	eq(c.state, "joined", "the second ritual was dropped")
	eq(w:summonStatus(w:player("Dan Moss")), 3, "the game still says declined (sticky)")
	eq(says(lock, c), "summon again", "the old answer is older than the latest cast: the row says what it says today")
	T.clean(w)
end)

test("v24 f3 e summon seen: a secret answer shows nothing new, and neither does the answer it hid", function()
	local w, lock, DR = setup()
	local c = summon(w, lock, DR)
	lock:secret("IncomingSummon")
	w:advance(2)
	w:answerSummon("Dan Moss", false)
	w:advance(2)
	eq(says(lock, c), WINDOW, "secret: exactly today's row")
	eq(#w.violations, 0, "no secret value was used: " .. tostring(w.violations[1]))
	lock:unsecret()
	w:advance(2)
	eq(says(lock, c), WINDOW, "readable again, but nobody saw when he declined (it may be minutes old): today's row")
	T.clean(w)
end)

test("v24 f3 e summon seen: without the game's call nothing changes", function()
	local w, lock, DR = setup({ api = false })
	eq(lock.env.C_IncomingSummon, nil, "this client has no C_IncomingSummon")
	local c = summon(w, lock, DR)
	w:answerSummon("Dan Moss", false)
	w:advance(2)
	eq(says(lock, c), WINDOW, "today's row")
	-- and a call that goes missing later (or errors) is the same as none
	w:setIncomingSummon(true)
	w:advance(2)
	lock.env.C_IncomingSummon.IncomingSummonStatus = function() error("not on this client") end
	w:advance(2)
	eq(says(lock, c), WINDOW, "a call that raises: today's row")
	eq(#w.errors, 0, "and no error: " .. tostring(w.errors[1]))
	T.clean(w)
end)

test("v24 f3 e summon seen: a rider WITH Wuber keeps today's row (one answer per rider)", function()
	local w, lock, DR = setup()
	local c = summon(w, lock, DR)
	c.source, c.wuberRide = "wuber", "abcdef" -- booked through the app: Wuber's own path is the truth for this rider
	w:answerSummon("Dan Moss", false)
	w:advance(2)
	eq(says(lock, c), WINDOW, "the game's answer is not shown for a rider with Wuber")
	T.clean(w)
end)

test("v24 f3 e summon seen: a joined rider with a summon box from anyone reads 'has the summon window'", function()
	local w, lock, DR, c = setup()
	eq(says(lock, c), "ready to summon", "control")
	w:addBot("Wes Other", { spot = "Thunder Bluff", class = "WARLOCK", shards = 5 })
	w:group({ ANITA, "Bob Helper", "Bo Second", "Dan Moss", "Wes Other" })
	w:advance(2)
	w:summon(w:player("Wes Other"), "Dan Moss") -- another Warlock's summon, no Wuber anywhere in it
	w:advance(2)
	eq(c.state, "joined", "Wuber cast nothing")
	eq(says(lock, c), WINDOW, "the row says he has a summon window")
	-- he declines it: nothing of ours was declined, so the row is today's again
	w:answerSummon("Dan Moss", false)
	w:advance(2)
	eq(says(lock, c), "ready to summon", "no cast of ours: no 'summon again?'")
	T.clean(w)
end)

test("v24 f3 e summon seen: raid rows say it too", function()
	local w, lock, DR = setup()
	local D = lock.W.Driver
	local answer
	DR.SummonSeen = function() return answer, lock.env.GetTime() - 5 end
	local row = { name = "Dan Moss", asked = lock.env.GetTime() - 60, state = "waiting", tries = 1 }
	eq((D.DescribeRaid(row)), WINDOW, "nothing known: today's words")
	answer = "declined"
	local what, _, colour = D.DescribeRaid(row)
	eq(what, DECLINED, "a raider who declined")
	eq(colour, "red", "a declined summon warns in red (design round 1: amber is only the big button)")
	answer = "accepted"
	eq((D.DescribeRaid(row)), ACCEPTED, "a raider who accepted")
	row.state = "queued"
	answer = "waiting"
	eq((D.DescribeRaid(row)), WINDOW, "a raider nobody of ours summoned, with a summon box")
	answer = nil
	eq((D.DescribeRaid(row)), "summon again (try 2)", "nothing known: today's words")
	T.clean(w)
end)

-- the words fit the row or give way to a shorter form, never cut (the pattern of a lead's chat line)
test("v24 f3 e summon seen: the declined and accepted words fit the row at every width, never cut", function()
	local w, lock, DR = setup()
	local D = lock.W.Driver
	local answer = "declined"
	DR.SummonSeen = function() return answer, lock.env.GetTime() - 5 end
	local FORMS = { declined = { [DECLINED] = true, ["summon declined"] = true, ["declined"] = true }, accepted = { [ACCEPTED] = true, ["accepted"] = true } }
	local parent = lock.env.CreateFrame("Frame", nil, lock.env.UIParent)
	parent:SetSize(400, 200)
	parent:SetPoint("CENTER")
	parent:Show()
	local shown = {}
	for _, wdt in ipairs({ 340, 324, 284 }) do -- the console, the raid side pane, the mini console
		for _, name in ipairs({ "Dan Moss", "Zephyrine Ash", "Bartholomews Ashrender" }) do
			for _, said in ipairs({ "declined", "accepted" }) do
				-- (a raid row has a stopwatch on the right: in the mini console a 12-letter name leaves room for no words
				-- at all, "summon again" is cut there today; not this change's to mend)
				for _, raid in ipairs((wdt == 284 and #name > 20) and { false } or { false, true }) do
					answer = said
					local r = D.Row(parent, wdt)
					r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
					if raid then
						D.PaintRaidRow(r, { name = name, asked = lock.env.GetTime() - 30, state = "waiting", tries = 1 })
					else
						D.PaintRow(r, { name = name, key = name:lower(), state = "waiting", source = "whisper", endAt = lock.env.GetTime() - 30, tries = 1 })
					end
					local text = r.what:GetText() or ""
					local where = wdt .. " " .. name .. " " .. said .. (raid and " (raid row)" or "") .. ": " .. text
					ok(H.truncation(r.what) == nil, "not cut at " .. where)
					ok(not r.what:IsTruncated(), "the game says not cut at " .. where)
					ok(FORMS[said][text:gsub("^ · ", "")], "one of its forms at " .. where)
					if not raid then shown[wdt .. name .. said] = text end
					r:Hide()
				end
			end
		end
	end
	eq(shown["340Dan Mossdeclined"], " · " .. DECLINED, "the console row, a short name: the question too")
	eq(shown["340Dan Mossaccepted"], " · " .. ACCEPTED, "the console row: summon accepted")
	-- (design 3: Inter is narrower than Poppins, so the two-word form fits where only "declined" did)
	eq(shown["284Bartholomews Ashrenderdeclined"], " · summon declined", "the mini console, a 12-letter name: the two words")
	T.clean(w)
end)
