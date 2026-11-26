-- Multibox safety, the mention ping (Net.Outreach mentionHeard): a hidden Q to a name that says "wuber" in public chat.
-- The author's own windows must together send ONE Q per stranger per hour (also after a /reload, a relog or a lost window),
-- never ping their own characters or crew, and hold the hourly cap together. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local M = dofile(T.dir .. "/multibox/mb.lua")(T)
local ANITA, ANA, BEA = T.ANITA, T.ANA, T.BEA

local function qTo(w, to)
	local n = 0
	for _, e in ipairs(w:messages("Q", nil, "WHISPER")) do
		if e.target and M.key(e.target) == M.key(to) then n = n + 1 end
	end
	return n
end

local function qTotal(w) return #w:messages("Q", nil, "WHISPER") end

local function say(w, who, text)
	if not w:player(who) then w:addBot(who, { spot = "Ratchet", acceptsInvites = false, faction = "Horde" }) end
	w:chatFrom(who, text or "does anyone use wuber?", "CHANNEL", "Trade", "Horde")
end

-- windows past the login quiet minute; Q traffic from setup (login rounds) is counted away by the callers using before/after
local function crewWindows(names)
	local w, cs = M.windows(names, { settle = 90 })
	for i = 2, #cs do
		ok(cs[1].W.Drive.OfferCrew(names[i]), "setup: crew offer to " .. names[i])
		w:advance(3)
		cs[i].W.Drive.AnswerOffer(names[1], true)
		w:advance(3)
	end
	w:advance(30)
	return w, cs
end

test("multibox mention: three own windows, one stranger says wuber: one hidden Q in all", function()
	local w = crewWindows({ ANITA, ANA, BEA })
	say(w, "Eve Vile")
	w:advance(40)
	eq(qTo(w, "Eve Vile"), 1, "one Q to the stranger from three windows")
	T.clean(w)
end)

test("multibox mention: two own windows reload after the Q: the stranger speaks again, no second Q within the hour", function()
	local w, cs = crewWindows({ ANITA, ANA })
	say(w, "Eve Vile")
	w:advance(40)
	eq(qTo(w, "Eve Vile"), 1, "setup: one Q")
	local a = w:reload(cs[1])
	local b = w:reload(cs[2])
	a.W.Drive.SetOpen(true)
	b.W.Drive.SetOpen(true)
	w:advance(90)
	say(w, "Eve Vile")
	w:advance(40)
	eq(qTo(w, "Eve Vile"), 1, "still one Q after both windows reloaded")
	T.clean(w)
end)

test("multibox mention: a relog of one window and a lost sister window: no second Q to the same stranger within the hour", function()
	local w, cs = crewWindows({ ANITA, ANA })
	say(w, "Eve Vile")
	w:advance(40)
	eq(qTo(w, "Eve Vile"), 1, "setup: one Q")
	local rc = M.relog(w, cs[1])
	M.crash(w, cs[2])
	rc.W.Drive.SetOpen(true)
	w:advance(90)
	say(w, "Eve Vile")
	w:advance(40)
	eq(qTo(w, "Eve Vile"), 1, "still one Q after a relog and a lost window")
	T.clean(w)
end)

test("multibox mention: an own character or a crew member who says wuber is never pinged", function()
	local w, cs = crewWindows({ ANITA, ANA, BEA })
	local before = qTotal(w)
	say(w, ANA)
	say(w, BEA)
	say(w, ANITA)
	w:advance(60)
	eq(qTotal(w), before, "no Q to any own window")
	eq(qTo(w, ANA) + qTo(w, BEA) + qTo(w, ANITA), 0, "none addressed to an own name")
	T.clean(w)
end)

test("multibox mention: an own window that is no crew member (a second account) but sends the line is not pinged by the others when it is a known peer", function()
	local w, cs = M.windows({ ANITA, ANA }, { settle = 90 })
	-- each window has heard the other's beacon, so they are known to each other as Wuber users
	say(w, ANA)
	w:advance(40)
	eq(qTo(w, ANA), 0, "a known Wuber window of the author gets no Q")
	T.clean(w)
end)

test("multibox mention: the hourly cap holds across three crew windows together", function()
	local w = crewWindows({ ANITA, ANA, BEA })
	local before = qTotal(w)
	for i = 1, 40 do
		say(w, "Stranger" .. string.char(64 + (i % 26) + 1) .. " Name" .. string.char(97 + (i % 26)) .. i)
		w:advance(11)
	end
	w:advance(60)
	local sent = qTotal(w) - before
	ok(sent <= 12, "at most 12 mention Qs an hour across all own windows (" .. sent .. ")")
	T.clean(w)
end)

test("multibox mention: three crew windows in one party: one hidden Q, also after one of them reloads", function()
	local w, cs = crewWindows({ ANITA, ANA, BEA })
	w:group({ ANITA, ANA, BEA })
	w:advance(30)
	say(w, "Eve Vile")
	w:advance(40)
	eq(qTo(w, "Eve Vile"), 1, "one Q from three grouped windows")
	local nc = w:reload(cs[3])
	nc.W.Drive.SetOpen(true)
	w:advance(90)
	say(w, "Eve Vile")
	w:advance(40)
	eq(qTo(w, "Eve Vile"), 1, "still one")
	T.clean(w)
end)

-- the crew offer: whispered once by the click, never again by a reload, a relog or the other windows
local function offers(w)
	local n = 0
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.result == 0 and not e.dropped and e.text:match("^TO~") then n = n + 1 end
	end
	return n
end

test("multibox crew offer: one click sends one offer; reloads and relogs of both windows send none", function()
	local w, cs = M.windows({ ANITA, ANA }, { settle = 30 })
	local before = offers(w)
	ok(cs[1].W.Drive.OfferCrew(ANA), "setup: the offer goes out")
	w:advance(10)
	local sent = offers(w) - before
	ok(sent >= 1, "setup: an offer message was seen (" .. sent .. ")")
	local a = w:reload(cs[1])
	local b = M.relog(w, cs[2])
	a.W.Drive.SetOpen(true)
	b.W.Drive.SetOpen(true)
	w:advance(120)
	a = M.relog(w, a)
	w:advance(120)
	eq(offers(w) - before, sent, "no new offer after reloads and relogs")
	T.clean(w)
end)
