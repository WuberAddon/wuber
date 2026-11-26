-- r51 G, SEC-M2: the whisper-back has an overall limit (one every 8 s, 30 an hour). Loaded by tests/run.lua with T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function openOrgDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().watchPublic = true
	ok(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	return w, a, DR, (a.player and a.player.faction) or "Horde"
end

local L = "abcdefghijklmnopqrstuvwxyz"
local function askerName(i)
	local a, b = math.floor((i - 1) / 26) + 1, (i - 1) % 26 + 1
	return "Ask" .. L:sub(a, a) .. L:sub(b, b) .. " Botx"
end

local function ask(w, faction, name)
	if not w:player(name) then
		w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = faction })
	end
	w:chatFrom(name, "WTB summon to Orgrimmar", "CHANNEL", "Trade", faction)
end

local function replied(w, n)
	local c = 0
	for i = 1, n do
		c = c + #w:whispersTo(askerName(i), "reply")
	end
	return c
end

for _, step in ipairs({ 1, 5 }) do
	test("r51 G SEC-M2: 40 askers in 60 s get at most 8 whispers (steps of " .. step .. " s)", function()
		local w, a, DR, faction = openOrgDriver()
		local per = 60 / 40
		local t, nextAsk, i = 0, 0, 0
		while t < 60 do
			while i < 40 and nextAsk <= t do
				i = i + 1
				ask(w, faction, askerName(i))
				nextAsk = nextAsk + per
			end
			w:advance(step)
			t = t + step
		end
		while i < 40 do i = i + 1; ask(w, faction, askerName(i)) end
		w:advance(0.5)
		local n = replied(w, 40)
		ok(n >= 1 and n <= 8, "whispers sent in about a minute: " .. n)
		T.clean(w)
	end)
end

test("r51 G SEC-M2: an asker skipped by the gap is not recorded and is answered when they ask again later", function()
	local w, a, DR, faction = openOrgDriver()
	ask(w, faction, askerName(1))
	w:advance(0.5)
	ask(w, faction, askerName(2))
	w:advance(0.5)
	eq(#w:whispersTo(askerName(1), "reply"), 1, "first asker answered")
	eq(#w:whispersTo(askerName(2), "reply"), 0, "second asker, a second later, is skipped by the gap")
	local saved = a.env.WuberDB.drive.replied or {}
	ok(saved[(askerName(2):lower())] == nil, "the skipped asker is not recorded as answered")
	w:advance(9)
	ask(w, faction, askerName(2))
	w:advance(0.5)
	eq(#w:whispersTo(askerName(2), "reply"), 1, "answered when they ask again after the gap")
	T.clean(w)
end)

test("r51 G SEC-M2: never more than 30 whispers in an hour", function()
	local w, a, DR, faction = openOrgDriver()
	for i = 1, 40 do
		ask(w, faction, askerName(i))
		w:advance(9)
	end
	local n = replied(w, 40)
	eq(n, 30, "thirty whispers in the first six minutes, then the hourly cap: " .. n)
	T.clean(w)
end)

-- guard: unchanged neighbour: the same asker is still answered once an hour
test("r51 G SEC-M2: the same asker still gets one reply an hour and another after it", function()
	local w, a, DR, faction = openOrgDriver()
	ask(w, faction, askerName(1))
	w:advance(20)
	ask(w, faction, askerName(1))
	w:advance(20)
	eq(#w:whispersTo(askerName(1), "reply"), 1, "second ask inside the hour gets nothing")
	w:advance(3700)
	ask(w, faction, askerName(1))
	w:advance(1)
	eq(#w:whispersTo(askerName(1), "reply"), 2, "asks again after the hour and is answered")
	T.clean(w)
end)

-- guard: unchanged neighbour: How whispers leave = Off sends nothing
test("r51 G SEC-M2: with whispers set to Off nothing is sent", function()
	local w, a, DR, faction = openOrgDriver()
	DR.opts().whisperMode = "off"
	ok(DR.ChatMode() ~= "macro", "control: the chat mode is not macro")
	ask(w, faction, askerName(1))
	w:advance(1)
	eq(#w:whispersTo(askerName(1), "reply"), 0, "no whisper")
	T.clean(w)
end)
