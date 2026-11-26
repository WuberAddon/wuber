-- r50 a: H24-10, the auto-reply follows "How whispers leave". Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function run(mode)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().watchPublic = true
	if mode then DR.opts().whisperMode = mode end
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	local faction = (a.player and a.player.faction) or "Horde"
	w:addBot("Dan Miller", { spot = "Ratchet", acceptsInvites = false, faction = faction })
	w:chatFrom("Dan Miller", "WTB summon to Orgrimmar", "CHANNEL", "Trade", faction)
	w:advance(0.5)
	local n = #w:whispersTo("Dan Miller", "reply")
	T.clean(w)
	return n
end

test("r50 a: whispers set to Off send no auto-reply", function()
	eq(run("off"), 0, "nothing sent with Off")
end)

test("r50 a: whispers set to Chat box send no auto-reply (only the player's Enter sends)", function()
	eq(run("box"), 0, "nothing sent with Chat box")
end)

-- guard: the whisper mode (and the default) still auto-replies as before
test("r50 a: the whisper modes still auto-reply once", function()
	eq(run("macro"), 1, "macro replies")
	eq(run(nil), 1, "default replies")
end)
