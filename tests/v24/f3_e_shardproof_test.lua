-- Wuber 2.4 fix round 3, group E, part 3: the Soul Shard as a second proof that a summon went out. The ritual watcher
-- (Drive/Cast.lua) has one verdict it gets wrong for want of proof: on a client that has told it before when a helper
-- clicks the portal (opts.helpSeen), a channel that ends with no helper heard is "nothing was summoned". Two helpers
-- without Wuber who click within a moment of each other are never heard (a hold counts from 2 s), so a summon that DID
-- go out was reported failed: the rider went back to "summon again" with a summon box up. A shard that was still in
-- the bag a second into the channel and is gone when the channel ends settles it: the summon went out.
-- Sources (ideas only): the addon-learning notes FAKE-GAME-HINTS 39, LEARN-REPORT lesson 9 (TimbersRaidSummoner.lua:3100-3112,
-- implied by its code, not proven): so a game where the shard goes with the cast must prove nothing (tested).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"
local SPOT = "Undercity"

local function setup(worldOpts)
	local w = T.newWorld(worldOpts)
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
	-- this account heard a helper's click on this build before: from now on "no helper heard" means "nothing summoned"
	DR.opts().helpSeen = lock.W.Build()
	local c = DR.Find("Dan Moss")
	ok(c and c.state == "joined", "Dan is in the group, ready to summon: " .. tostring(c and c.state))
	local b = lock.env.WuberDriveButton
	ok(b and H.visible(b), "the big button is shown")
	return w, lock, DR, c, b
end

-- the END fact this window told its crew about Dan's summon ("1" it went out, "0" it failed), in order
local function ends(w)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		local f = e.text:match("^END~[^~]*~Dan Moss~(%d)")
		if f then out[#out + 1] = f end
	end
	return table.concat(out, ",")
end

test("v24 f3 e shard proof: two quick helpers without Wuber, nobody heard, but the shard went: the summon is reported sent", function()
	local w, lock, DR, c, b = setup()
	local shards = w:player(ANITA).shards
	lock:click(b)
	w:advance(3) -- the cast, then the channel has run for over a second with the shard still in the bag
	eq(c.state, "summoning", "the ritual runs")
	eq(w:player(ANITA).shards, shards, "the shard is still there mid-channel")
	ok(w:clickPortal("Bob Helper"), "Bob clicks the portal")
	ok(w:clickPortal("Bo Second"), "Bo clicks at once: neither held it for 2 s, neither has Wuber")
	w:advance(2.5)
	eq(#w.summons, 1, "the summon went out")
	eq(w:player(ANITA).shards, shards - 1, "and its shard is gone")
	eq(c.state, "waiting", "the row says Dan has the summon window, not 'summon again'")
	eq(ends(w), "1", "and the crew was told the summon went")
	T.clean(w)
end)

test("v24 f3 e shard proof: no shard gone, no proof: a channel dropped with nobody heard is still 'nothing summoned'", function()
	local w, lock, DR, c, b = setup()
	local shards = w:player(ANITA).shards
	lock:click(b)
	w:advance(3)
	w:cancelRitual()
	w:advance(2.5)
	eq(#w.summons, 0, "nothing was summoned")
	eq(w:player(ANITA).shards, shards, "no shard went")
	eq(c.state, "joined", "Dan is to be summoned again")
	eq(ends(w), "0", "the crew was told it failed")
	T.clean(w)
end)

test("v24 f3 e shard proof: a game that takes the shard with the cast proves nothing by it", function()
	local w, lock, DR, c, b = setup({ shardAtCast = true })
	local shards = w:player(ANITA).shards
	lock:click(b)
	w:advance(3)
	eq(w:player(ANITA).shards, shards - 1, "this game took the shard as the channel began")
	w:cancelRitual() -- nobody clicked: nothing was summoned, though the shard is gone
	w:advance(2.5)
	eq(#w.summons, 0, "nothing was summoned")
	eq(c.state, "joined", "a shard that went before the channel was a second old is no proof: summon again")
	eq(ends(w), "0", "the crew was told it failed")
	T.clean(w)
end)

test("v24 f3 e shard proof: a secret shard count, or a channel under a second old, leaves today's verdict", function()
	local w, lock, DR, c, b = setup()
	lock:secret("GetItemCount")
	lock:click(b)
	w:advance(3)
	w:clickPortal("Bob Helper")
	w:clickPortal("Bo Second")
	w:advance(2.5)
	eq(#w.summons, 1, "the summon went out")
	eq(c.state, "joined", "but the count could not be read: the verdict is today's (no helper heard)")
	eq(#w.violations, 0, "no secret value was used: " .. tostring(w.violations[1]))
	T.clean(w)
	-- helpers so quick that the channel ends before anybody saw the shard still there mid-channel
	local w2, lock2, DR2, c2, b2 = setup()
	lock2:click(b2)
	w2:advance(0.7) -- the cast is over, the channel is 0.2 s old
	w2:clickPortal("Bob Helper")
	w2:clickPortal("Bo Second")
	w2:advance(2.5)
	eq(#w2.summons, 1, "the summon went out")
	eq(c2.state, "joined", "no look at the shard mid-channel, so no proof: today's verdict stays")
	T.clean(w2)
end)
