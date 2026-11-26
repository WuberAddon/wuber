-- Proof tests of job 2620 (audit-241), area E: secure clicks, casting, chat, auto replies.
local T = ...
local test = T.test
-- r50 (job 2609): these bugs are fixed in 2.4.1; their proofs now run as normal tests
local FIXED = { ["AU24-01"] = true, ["AU24-02"] = true, ["AU24-03"] = true, ["AU24-06"] = true, ["AU24-09"] = true, ["AU24-10"] = true, ["AU24-12"] = true, ["AU24-13"] = true, ["AU24-15"] = true, ["AU24-17"] = true, ["AU24-18"] = true, ["AU24-19"] = true, ["AU24-20"] = true, ["AU24-21"] = true, ["AU24-22"] = true, ["AU24-26"] = true, ["AU24-27"] = true, ["AU24-28"] = true, ["AU24-29"] = true, ["AU24-31"] = true, ["AU24-33"] = true, ["AU24-34"] = true, ["AU24-35"] = true }
local function proof(id, name, fn)
	if os.getenv("WUBER_AU24_PROOF") or FIXED[id] then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end

local H = T.H

local function printed(W)
	local out = {}
	W.Print = function(t) out[#out + 1] = tostring(t) end
	return out
end

-- AU24-27: the "raid" command's answer when no raid exists yet.
proof("AU24-27", "/wuber drive raid with no raid yet: the answer has no doubled full stop", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local out = printed(a.W)
	a.W.Drive.Command("raid")
	local all = table.concat(out, "\n")
	assert(all:find("Not yet", 1, true), "the test needs the 'Not yet' answer: " .. all)
	assert(not all:find("..", 1, true), "a sentence ends in two full stops: " .. all)
	T.clean(w)
end)

-- AU24-15: typed on / off while raid summons are the mode.
local function raidRunner()
	local DRU, LEA, CAL = "Dru Oak", "Lea Dorn", T.CAL
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = "Blackrock Mountain", class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = "Blackrock Mountain", class = "DRUID" })
	local cal = w:addClient(CAL, { spot = "Blackrock Mountain", class = "WARLOCK" })
	local names = { LEA, DRU, CAL }
	for i = 1, 5 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	local DD = dru.W.Drive
	assert(DD.SetMode("raid"))
	assert(DD.RaidPick(CAL, true))
	w:advance(1)
	cal.W.Drive.AnswerOffer(DRU, true)
	w:advance(3)
	return w, dru, DD
end

-- AU24-15: the proof is in verify_v4_test.lua (verifier V4 corrected it: the "off" line, "Closed. Nobody is invited or asked
-- to pay.", is true in raid mode, so only the "on" line is tested).

-- AU24-06: a group member's OTHER channelled spell is not a portal click.
local function castSetup()
	local ANITA, SPOT = T.ANITA or "Anita Lift", "Undercity"
	local w = T.newWorld()
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	w:addBot("Bob Helper", { spot = SPOT })
	w:group({ ANITA, "Bob Helper" })
	w:advance(1)
	local DR = lock.W.Drive
	DR.SetOpen(true)
	w:advance(2)
	w:addBot("Dan Moss", { spot = "Orgrimmar" })
	w:botWhisper("Dan Moss", lock, "summon pls")
	w:advance(3)
	local helped = {}
	lock.W.Listen("DRIVE_RITUAL", function(name, phase, data)
		if phase == "h" and type(data) == "table" then helped[#helped + 1] = tostring(data.helperName or data.helper) end
	end)
	local b = lock.env.WuberDriveButton
	assert(b and H.visible(b), "the big button is not shown")
	lock:click(b)
	w:advance(1)
	return w, lock, helped
end
local function token(lock, name)
	for i = 1, 4 do
		local t = "party" .. i
		if lock.W.UnitName(t) == name then return t end
	end
	error("no party token for " .. name)
end

proof("AU24-06", "a group member channelling another spell for 3 s is not credited as a portal helper", function()
	local w, lock, helped = castSetup()
	-- Bob (no Wuber) channels Mind Flay (not the ritual) for 3 s while my summon channel runs
	lock:fire("UNIT_SPELLCAST_CHANNEL_START", token(lock, "Bob Helper"), "Bob-mf", 15407)
	w:advance(3)
	lock:fire("UNIT_SPELLCAST_CHANNEL_STOP", token(lock, "Bob Helper"), "Bob-mf", 15407)
	w:advance(3)
	for _, h in ipairs(helped) do
		assert(not h:lower():find("bob", 1, true), "Bob channelled Mind Flay, not the portal, but is credited as a helper: " .. table.concat(helped, ","))
	end
	T.clean(w)
end)

-- AU24-22: a size typed above the biggest is never read as a tiny percentage.
proof("AU24-22", "/wuber drive scale with a number just above 3 does not shrink the big button to its smallest", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local out = printed(a.W)
	local DR = a.W.Drive
	for _, arg in ipairs({ "3.5", "4", "5" }) do
		DR.Command("scale 1.5")
		DR.Command("scale " .. arg)
		assert(DR.Scale() >= 1.5, "'scale " .. arg .. "' (1.5 before) left the button at " .. DR.Scale() .. ": " .. table.concat(out, " | "))
	end
	T.clean(w)
end)

-- AU24-28: every typed command that needs a name says what to type when none is given.
proof("AU24-28", "/wuber drive unblock with no name says how to use it, like block does", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local out = printed(a.W)
	a.W.Drive.Command("block")
	assert(#out > 0, "control: block with no name prints its usage")
	for i = #out, 1, -1 do out[i] = nil end
	a.W.Drive.Command("unblock")
	assert(#out > 0, "unblock with no name printed nothing at all")
	T.clean(w)
end)

-- ---------------------------------------------------------------------------------------------------------------
-- second pass
-- ---------------------------------------------------------------------------------------------------------------
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function openOrgDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().watchPublic = true
	assert(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	return w, a, DR, (a.player and a.player.faction) or "Horde"
end

local function sayInTrade(w, faction, name, text)
	if not w:player(name) then
		w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = faction })
	end
	w:chatFrom(name, text, "CHANNEL", "Trade", faction)
	w:advance(0.5)
end

-- AU24-11: a reply the game refused to send is not remembered as sent.
test("AU24-11: an auto-reply the game blocked does not silence the asker for an hour once sending works again", function()
	local w, a, DR, faction = openOrgDriver()
	local ci = a.env.C_ChatInfo
	local real = ci.SendChatMessage
	-- the client refuses the call, as it does for any addon chat ("only available to the Blizzard UI")
	ci.SendChatMessage = function() a:fire("ADDON_ACTION_BLOCKED", "Wuber", "SendChatMessage()") end
	sayInTrade(w, faction, "Dan Miller", "WTB summon to Orgrimmar")
	assert(#w:whispersTo("Dan Miller", "reply") == 0, "control: nothing was whispered while blocked")
	assert(a.W.IsBlocked("chat"), "control: the refusal was noted")
	-- the player taps Retry (Settings / "/wuber drive retry") and the game lets the call through again
	ci.SendChatMessage = real
	DR.Command("retry")
	assert(not a.W.IsBlocked("chat"), "control: retry cleared the refusal")
	w:advance(30)
	sayInTrade(w, faction, "Dan Miller", "WTB summon to Orgrimmar")
	assert(#w:whispersTo("Dan Miller", "reply") == 1,
		"Dan asked again after Retry and still got no reply (the blocked send was written down as sent for an hour): " .. #w:whispersTo("Dan Miller", "reply"))
	T.clean(w)
end)

-- AU24-10: a boxed reminder is marked sent by an unrelated whisper to the same person.
proof("AU24-10", "a line waiting in the chat box is not marked sent by a different whisper to the same rider", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	w:addBot("Dan Moss", { spot = "Undercity" })
	local DR = a.W.Drive
	local c = { name = "Dan Moss", key = "dan moss" }
	assert(DR.OpenBox(c, "pay") ~= false, "the reminder went to the chat box")
	assert(DR.boxed and DR.boxed.c == c, "control: it waits for Enter")
	-- 20 s later the driver cancels it (Escape) and whispers Dan about something else
	w:advance(20)
	a:fire("CHAT_MSG_WHISPER_INFORM", "sure, one minute", "Dan Moss")
	assert(not c.reminded, "Dan's pay reminder was marked as sent although the driver only whispered 'sure, one minute'")
	T.clean(w)
end)
