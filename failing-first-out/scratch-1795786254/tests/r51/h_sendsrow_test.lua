-- r51 h: R50-04, the row "What Wuber sends" says never in combat, in a raid, in an instance or during a ride in its
-- tooltip; here each of the four is proved true (Wuber sends nothing by itself there). Loaded by tests/run.lua with T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

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

local n = 0
local function ask(w, faction, DR)
	n = n + 1
	local name = "Hunt Asker" .. string.char(64 + n)
	w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = faction })
	w:chatFrom(name, "WTB summon to Orgrimmar", "CHANNEL", "Trade", faction)
	w:advance(1)
	return name
end

local function sent(w, name) return #w:whispersTo(name, "reply") end

-- guard: the base already holds these limits (tests/v24/autoreply_test.lua); this ties them to the row's tooltip words
test("r51 h: the tooltip's four never-situations each send nothing, and the open case does send", function()
	local w, a, DR, faction = openOrgDriver()
	local tip = w and a.W.Mod("UI.Settings.Rows").SENDING.tip
	for _, never in ipairs({ "in combat", "in a raid", "in an instance", "during a ride" }) do
		ok(tip:find(never, 1, true), "the tooltip says never " .. never)
	end
	-- the unchanged neighbouring path: with none of the four, the one whisper back does go
	local open = ask(w, faction, DR)
	eq(sent(w, open), 1, "outside all four situations the one whisper back is sent")
	-- combat
	w:enterCombat(a)
	eq(sent(w, ask(w, faction, DR)), 0, "nothing in combat")
	w:advance(5)
	w:leaveCombat(a)
	-- instance
	a.player.instance = true
	eq(sent(w, ask(w, faction, DR)), 0, "nothing in an instance")
	w:advance(5)
	a.player.instance = false
	-- raid
	w:addBot("Ora Dunn", { spot = "Ratchet", acceptsInvites = false, faction = faction })
	w:group({ T.ANITA, "Ora Dunn" })
	w:advance(1)
	a.player.group.raid = true
	eq(sent(w, ask(w, faction, DR)), 0, "nothing in a raid")
	w:advance(5)
	a.player.group.raid = false
	w:advance(1)
	-- ride in progress
	w:addBot("Leo Marsh", { spot = "Ratchet", acceptsInvites = false, faction = faction })
	w:botWhisper("Leo Marsh", a, "summ to org pls")
	w:advance(3)
	ok(DR.Busy(), "a ride is in progress")
	eq(sent(w, ask(w, faction, DR)), 0, "nothing during a ride")
	w:advance(5)
	T.clean(w)
end)

-- F004 (issue 17): the short line a player reads says "never in combat"; the maintainer approved these exact words
test("r51 h: the short line of 'What Wuber sends' says never in combat, in the approved words", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local text = a.W.Mod("UI.Settings.Rows").SENDING.text
	ok(text:find("never in combat", 1, true), "the short line says never in combat: " .. text)
	eq(text, "Hidden messages: at most 12 at once, then 2 a second. One whisper back to a public request, once an hour for each person, never in combat. Every other line waits for your click, unless you switched it on in Messages.")
end)
