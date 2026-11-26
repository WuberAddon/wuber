-- Wuber 2.4, p2: careful auto-invite gate and Drive.Queue wiring. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function invitesTo(w, name)
	local n, k = 0, key(name)
	for _, inv in ipairs(w.invites) do
		if key(inv.to) == k then n = n + 1 end
	end
	return n
end

local function openOrgDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	ok(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	return w, a, DR
end

test("v24 careful: the verdict table", function()
	local w, a, DR = openOrgDriver()
	local cases = {
		-- the author's four examples
		{ "Port Orgrimmar", "public", "ignore" },
		{ "whisper me invite for summon to Orgrimmar", "whisper", "lead" },
		{ "WTS summons to Orgrimmar 1g, whisper me inv", "whisper", "lead" },
		{ "WTS summons to Orgrimmar 1g, whisper me inv", "public", "ignore" },
		{ "LF sleeping bag summons", "whisper", "lead" },
		-- clear whisper requests
		{ "summon pls", "whisper", "invite" },
		{ "inv pls", "whisper", "invite" },
		{ "summ to org pls", "whisper", "invite" },
		{ "can i get a summon to org please", "whisper", "invite" },
		{ "hi, could you summon me pls", "whisper", "invite" },
		{ "need a summon", "whisper", "invite" },
		{ "WTB summon to Orgrimmar for 50s", "whisper", "invite" },
		{ "lf summon to org, paying 5g", "whisper", "invite" },
		{ "can i get a summon?", "whisper", "invite" },
		{ "could you summon me to org pls?", "whisper", "invite" },
		{ "can u inv me?", "whisper", "invite" },
		{ "summon to org pls ty", "whisper", "invite" },
		{ "summon pls, I'm at the bank in Ironforge", "whisper", "invite" },
		{ "summon pls, I'm in Durotar", "whisper", "invite" },
		{ "summon to org", "whisper", "invite" },
		-- offers
		{ "summ u", "whisper", "lead" },
		{ "summon you to org", "whisper", "lead" },
		{ "inv u", "whisper", "lead" },
		{ "i can summon to org", "whisper", "lead" },
		{ "can summon you", "whisper", "lead" },
		-- thanks about the past
		{ "thx for the summ", "whisper", "lead" },
		{ "ty for summon earlier", "whisper", "lead" },
		-- bare questions about the service
		{ "summon 2 org?", "whisper", "lead" },
		{ "summons?", "whisper", "lead" },
		{ "do you do summons?", "whisper", "lead" },
		{ "got a summon?", "whisper", "lead" },
		{ "any summon to undercity?", "whisper", "lead" },
		-- sellers and adverts
		{ "selling summons to org 3g", "whisper", "lead" },
		{ "cheap summons to org, w me", "whisper", "lead" },
		{ "summon service to org 2g pst", "whisper", "lead" },
		{ "summon 5g", "whisper", "lead" },
		{ "inv for summ", "whisper", "lead" },
		-- unknown or foreign words
		{ "summon pls earlier", "whisper", "lead" },
		{ "summon for guild pls", "whisper", "lead" },
		{ "brauche summon nach org", "whisper", "lead" },
		-- long line, [Wuber] advert, price question
		{ "can i get a summon to orgrimmar please please please please please please please please", "whisper", "lead" },
		{ "[Wuber] Summons to Orgrimmar 50s", "whisper", "lead" },
		{ "[Wuber] Summons to Orgrimmar 50s", "public", "ignore" },
		{ "how much for a summon to org?", "whisper", "lead" },
		{ "what is the price for a summon", "whisper", "lead" },
		-- public chat verdicts
		{ "WTB summon to Orgrimmar", "public", "invite" },
		{ "summon to org pls", "public", "invite" },
		{ "summon 2 org?", "public", "lead" },
		{ "Any summons to org?", "public", "lead" },
		{ "LF sleeping bag summons", "public", "lead" },
		{ "WTB summon to Undercity", "public", "ignore" },
		{ "summon to org", "public", "ignore" },
	}
	for _, row in ipairs(cases) do
		local verdict, reason = DR.Careful(row[1], row[2])
		eq(verdict, row[3], row[2] .. " verdict for: " .. row[1] .. " (reason: " .. tostring(reason) .. ")")
		ok(type(reason) == "string" and reason ~= "", row[2] .. " reason present for: " .. row[1])
	end
	T.clean(w)
end)

test("v24 careful: end to end", function()
	local w, a, DR = openOrgDriver()
	DR.opts().watchPublic = true
	DR.opts().autoPublic = true
	local names = { "Dan Miller", "Eve Stone", "Fay Wood", "Gil Moss", "Hal Reed", "Ida Frost" }
	for _, n in ipairs(names) do
		w:addBot(n, { spot = "Ratchet", acceptsInvites = false })
	end
	-- clear whisper: invited and marked auto = "whisper" with the message
	w:botWhisper("Dan Miller", a, "summ to org pls")
	w:advance(3)
	eq(invitesTo(w, "Dan Miller"), 1, "clear whisper invited")
	local dan = DR.customers[key("Dan Miller")]
	ok(dan and dan.state == "invited", "Dan is invited")
	eq(dan and dan.auto, "whisper", "Dan marked auto whisper")
	eq(dan and dan.autoMsg, "summ to org pls", "Dan keeps autoMsg")

	-- unclear whisper: lead, nobody invited; clicking the lead invites without auto mark
	w:botWhisper("Eve Stone", a, "LF sleeping bag summons")
	w:advance(3)
	eq(invitesTo(w, "Eve Stone"), 0, "unclear whisper not invited")
	local eve = DR.customers[key("Eve Stone")]
	eq(eve and eve.state, "lead", "Eve is a lead")
	eq(eve and eve.auto, nil, "lead has no auto mark")
	local made = DR.Invite(eve)
	w:advance(3)
	ok(made and made.state ~= "lead", "clicked lead becomes a rider")
	eq(invitesTo(w, "Eve Stone"), 1, "clicked lead invited")
	eq(made and made.auto, nil, "clicked lead is not marked auto")
	eq(made and made.autoMsg, nil, "clicked lead has no autoMsg")

	-- Wuber app whisper line: invited, NOT marked auto
	w:botWhisper("Fay Wood", a, "WTB summon to Orgrimmar for 50s")
	w:advance(3)
	eq(invitesTo(w, "Fay Wood"), 1, "Wuber app line invited")
	local fay = DR.customers[key("Fay Wood")]
	eq(fay and fay.auto, nil, "Wuber app line is not marked auto")

	-- "Port Orgrimmar" in Trade with watchPublic and autoPublic on: ignored completely
	DR.PublicLine("Port Orgrimmar", "Gil Moss", true)
	w:advance(3)
	eq(DR.customers[key("Gil Moss")], nil, "Port Orgrimmar makes no customer")
	eq(invitesTo(w, "Gil Moss"), 0, "Port Orgrimmar sends no invite")

	-- clear public request in Trade with autoPublic on: invited and marked auto = "public"
	DR.PublicLine("WTB summon to org", "Hal Reed", true)
	w:advance(3)
	eq(invitesTo(w, "Hal Reed"), 1, "clear public request invited with autoPublic on")
	local hal = DR.customers[key("Hal Reed")]
	eq(hal and hal.auto, "public", "Hal marked auto public")
	eq(hal and hal.autoMsg, "WTB summon to org", "Hal keeps autoMsg")

	-- same clear public request with autoPublic off: listed as a lead, not invited, not marked auto
	DR.opts().autoPublic = false
	DR.PublicLine("WTB summon to org", "Ida Frost", true)
	w:advance(3)
	eq(invitesTo(w, "Ida Frost"), 0, "autoPublic off sends no invite")
	local ida = DR.customers[key("Ida Frost")]
	eq(ida and ida.state, "lead", "autoPublic off makes a lead")
	eq(ida and ida.auto, nil, "public lead is not marked auto")

	-- resetting ride fields clears auto and autoMsg
	DR.ResetRide(dan)
	eq(dan.auto, nil, "ResetRide clears auto")
	eq(dan.autoMsg, nil, "ResetRide clears autoMsg")
	T.clean(w)
end)

test("v24 careful: a seller word never invites, whatever the options", function()
	local w, a, DR = openOrgDriver()
	DR.opts().autoInvite = true
	DR.opts().watchPublic = true
	DR.opts().autoPublic = true
	local sellers = {
		"WTS summons to Orgrimmar 1g, whisper me inv",
		"whisper me invite for summon to Orgrimmar",
		"selling summons to org 2g pst",
		"cheap summon service to org, w me",
		"summon available to org 3g dm me",
		"[Wuber] Summons to Orgrimmar 50s",
	}
	for i, line in ipairs(sellers) do
		local wName = "Sel W" .. string.char(64 + i)
		local pName = "Sel P" .. string.char(64 + i)
		w:addBot(wName, { spot = "Ratchet", acceptsInvites = false })
		w:addBot(pName, { spot = "Ratchet", acceptsInvites = false })
		w:botWhisper(wName, a, line)
		DR.PublicLine(line, pName, true)
		w:advance(2)
		eq(invitesTo(w, wName), 0, "whisper seller never invited: " .. line)
		eq(invitesTo(w, pName), 0, "public seller never invited: " .. line)
		eq(DR.customers[key(pName)], nil, "public seller not listed: " .. line)
	end
	T.clean(w)
end)
