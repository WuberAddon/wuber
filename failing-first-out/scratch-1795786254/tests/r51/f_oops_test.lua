-- r51 group F (R50-03): words a driver marked as a wrong invite (DR.Oops) never invite anyone by themselves again,
-- from a whisper or from public chat, however they are capitalised or punctuated; the driver's own click still invites.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function openDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar", shards = 10 })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().kickAfter = false
	DR.opts().watchPublic, DR.opts().autoPublic = true, true
	ok(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	return w, a, DR
end

local function invitesTo(w, name)
	local n = 0
	for _, i in ipairs(w.invites) do if key(i.to) == key(name) then n = n + 1 end end
	return n
end

local function say(w, a, DR, path, name, text)
	if path == "whisper" then
		w:botWhisper(name, a, text)
	else
		DR.PublicLine(text, name, true)
	end
end

-- mark "summ pls" as wrong with a first rider (via whisper), then try the path x form
local FORMS = { "summ pls", "Summ pls!", "summ  pls", "SUMM PLS.", "  summ pls  " }
local function sweep(path, step)
	for i, form in ipairs(FORMS) do
		local w, a, DR = openDriver()
		w:addBot("Kay Pine", { spot = "Ratchet", acceptsInvites = false })
		w:addBot("Lou Reed", { spot = "Ratchet", acceptsInvites = false })
		w:advance(1)
		w:botWhisper("Kay Pine", a, "summ pls")
		w:advance(4)
		local kay = DR.customers[key("Kay Pine")]
		eq(kay and kay.auto, "whisper", "control: Kay was invited by herself")
		eq(DR.Oops(kay), true, "Oops works")
		w:advance(step)
		local before = invitesTo(w, "Lou Reed")
		say(w, a, DR, path, "Lou Reed", form)
		w:advance(step); w:advance(step); w:advance(step)
		local lou = DR.customers[key("Lou Reed")]
		eq(invitesTo(w, "Lou Reed"), before, path .. " form " .. i .. " (" .. form .. "): Lou was not invited by itself")
		ok(not (lou and lou.auto), path .. " form " .. i .. ": Lou is no automatic row")
		-- the driver's own click still invites
		if lou and lou.state == "lead" then
			local made = DR.Invite(lou)
			w:advance(step); w:advance(step)
			ok(made and made.state ~= "lead", "the driver's click makes Lou a rider")
			eq(invitesTo(w, "Lou Reed"), before + 1, "the driver's own click invited Lou")
		end
		T.clean(w)
	end
end
for _, path in ipairs({ "whisper", "public" }) do
	for _, step in ipairs({ 1, 5 }) do
		-- guard: R50-03 was already fixed on this base (prep-242 r3i: Oops clears c.auto); this sweeps path x form x step
		test("r51 F R50-03: marked words from a " .. path .. " never invite by themselves (" .. step .. " s steps)", function()
			sweep(path, step)
		end)
	end
end

-- guard: the app-shaped booking (R~ line) still queues and invites after an Oops
-- guard: neighbouring path, unchanged by R50-03
test("r51 F R50-03 guard: a rider who books in the app still queues after an Oops", function()
	local w, a, DR = openDriver()
	w:addBot("Kay Pine", { spot = "Ratchet", acceptsInvites = false })
	w:advance(1)
	w:botWhisper("Kay Pine", a, "summ pls")
	w:advance(4)
	eq(DR.Oops(DR.customers[key("Kay Pine")]), true, "Oops works")
	w:advance(1)
	w:addBot("Gil Moss", { spot = "Durotar" })
	w:inject("Gil Moss", "R~1~gilrid~Orgrimmar~5000", "WHISPER", a)
	w:advance(3)
	eq(invitesTo(w, "Gil Moss"), 1, "a Wuber ride for Orgrimmar: invited")
	T.clean(w)
end)

-- guard: other clear words still invite by themselves after the Oops
-- guard: neighbouring path, unchanged by R50-03
test("r51 F R50-03 guard: a clear whisper with other words still invites", function()
	local w, a, DR = openDriver()
	w:addBot("Kay Pine", { spot = "Ratchet", acceptsInvites = false })
	w:addBot("Max Dale", { spot = "Ratchet", acceptsInvites = false })
	w:advance(1)
	w:botWhisper("Kay Pine", a, "summ pls")
	w:advance(4)
	eq(DR.Oops(DR.customers[key("Kay Pine")]), true, "Oops works")
	w:advance(1)
	w:botWhisper("Max Dale", a, "summ to org pls")
	w:advance(4)
	eq(invitesTo(w, "Max Dale"), 1, "Max was invited by himself")
	T.clean(w)
end)

-- guard: an Oops needs the group's leader
-- guard: neighbouring path, unchanged by R50-03
test("r51 F R50-03 guard: DR.CanOops refuses a helper in a crew", function()
	local w, a, DR = openDriver()
	local saved = DR.IsLeader
	local c = { auto = "whisper", state = "invited", name = "Kay Pine" }
	eq(DR.CanOops(c), true, "alone, the driver may Oops")
	w:addBot("Bob Helper", { spot = "Orgrimmar" })
	w:group({ T.ANITA, "Bob Helper" })
	w:advance(1)
	DR.IsLeader = function() return false end
	eq(DR.CanOops(c), false, "a helper cannot Oops")
	DR.IsLeader = saved
	T.clean(w)
end)
