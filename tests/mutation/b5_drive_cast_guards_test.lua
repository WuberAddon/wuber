-- Mutation run guards for Wuber/Drive/Cast.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setupDriver(opts)
	opts = opts or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar", saved = opts.saved })
	T.settle(w)
	if opts.online ~= false then
		T.goOnline(a, { price = opts.price or 5000 })
	end
	return w, a, a.W.Drive
end

-- guards Wuber/Drive/Cast.lua:87 (drop statement: call() swallows DR helper error without W.Error)
test("mutation b5 drive cast: call() reports errors from DR helpers via W.Error", function()
	local w, a, DR = setupDriver()
	w:addBot("Dan Miller", { spot = "Ratchet", acceptsInvites = true })
	w:botWhisper("Dan Miller", a, "summon from orgrimmar to ratchet pls")
	w:advance(5)
	w:group({ T.ANITA, "Dan Miller" })
	w:advance(1)
	local origPending = DR.SummonPending
	local origErr = a.W.Error
	local errTag, errMsg
	a.W.Error = function(tag, msg)
		errTag, errMsg = tag, msg
		if origErr then return origErr(tag, msg) end
	end
	DR.SummonPending = function() error("pending boom") end
	DR.NextSummon()
	DR.SummonPending = origPending
	a.W.Error = origErr
	a.W.lastError = nil
	eq(errTag, "drive SummonPending", "W.Error called with drive helper tag")
	ok(tostring(errMsg):find("pending boom", 1, true) ~= nil, "W.Error received error message")
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:308 (if cond negated: waiting status not persisted in summonWait)
-- guards Wuber/Drive/Cast.lua:309 (drop statement: waitStore(true) not created when saving wait)
-- guards Wuber/Drive/Cast.lua:310 (if cond negated: waitStore save skipped when store exists)
-- guards Wuber/Drive/Cast.lua:312 (cmp ~=->==: stale entries in summonWait not pruned)
-- guards Wuber/Drive/Cast.lua:314 (drop statement: current waiting entry not written to summonWait)
-- guards Wuber/Drive/Cast.lua:317 (drop statement: summonWait entry not cleared when status leaves waiting)
test("mutation b5 drive cast: SummonLook persists waiting status, prunes stale entries, and clears on status change", function()
	local w, a, DR = setupDriver()
	w:addBot("Dan Miller", { spot = "Ratchet", acceptsInvites = true })
	w:botWhisper("Dan Miller", a, "summon from orgrimmar to ratchet pls")
	w:advance(5)
	w:group({ T.ANITA, "Dan Miller" })
	w:advance(1)
	local status = 0 -- "none" first so transition to "waiting" is seen by this window
	a.env.C_IncomingSummon = {
		IncomingSummonStatus = function() return status end,
	}
	a.W.db.drive.summonWait = nil
	local t0 = a.W.Now() + 1000
	DR.SummonLook(t0)
	status = 1 -- Enum.SummonStatus.Pending -> "waiting"
	DR.SummonLook(t0 + 1)
	local sw = a.W.db.drive.summonWait
	ok(sw ~= nil and sw["dan miller"] ~= nil, "waiting rider persisted in summonWait when summonWait started nil")
	sw["stale rider"] = { at = 1, look = 1 }
	DR.SummonLook(t0 + 2)
	eq(sw["stale rider"], nil, "stale entry pruned from summonWait")
	-- Status changes to Accepted (2): entry cleared from summonWait
	status = 2
	DR.SummonLook(t0 + 3)
	eq(a.W.db.drive.summonWait["dan miller"], nil, "entry cleared when status leaves waiting")
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:446 (swap and->or: NextSummon marks un-summonable rider as summon pending)
test("mutation b5 drive cast: NextSummon keeps real reason when rider is not summonable even if SummonPending is true", function()
	local w, a, DR = setupDriver()
	w:addBot("Dan Miller", { spot = "Orgrimmar", acceptsInvites = true })
	w:botWhisper("Dan Miller", a, "summon from orgrimmar to ratchet pls")
	w:advance(5)
	w:group({ T.ANITA, "Dan Miller" })
	w:advance(1)
	local origPending = DR.SummonPending
	DR.SummonPending = function() return true end
	local best = DR.NextSummon()
	DR.SummonPending = origPending
	eq(best, nil, "no summonable rider")
	eq(DR.whyNoSummon["dan miller"], "state arrived", "real reason preserved over summon pending")
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:451 (local value -> nil: NextSummon records whyNoSummon without crashing when key is nil)
test("mutation b5 drive cast: NextSummon records whyNoSummon by name when customer lacks .key", function()
	local w, a, DR = setupDriver()
	DR.customers = {
		["dan miller"] = { name = "Dan Miller", state = "joined", order = 1, dest = "Ratchet" },
	}
	local best = DR.NextSummon()
	eq(best, nil, "not in group so not summonable")
	eq(DR.whyNoSummon["dan miller"], "not found in the group", "whyNoSummon keyed via riderKey(c)")
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:456 (cmp >-><=: whyNoSummonText is not "nobody listed" when no riders are listed)
-- guards Wuber/Drive/Cast.lua:457 (return -> nil: NextSummon returns non-priority summonable rider)
test("mutation b5 drive cast: NextSummon returns non-priority rider and reports nobody listed when empty", function()
	local w, a, DR = setupDriver()
	eq(DR.NextSummon(), nil, "no rider when empty")
	eq(DR.whyNoSummonText, "nobody listed", "whyNoSummonText reports nobody listed when empty")
	w:addBot("Dan Miller", { spot = "Ratchet", acceptsInvites = true })
	w:botWhisper("Dan Miller", a, "summon from orgrimmar to ratchet pls")
	w:advance(5)
	w:group({ T.ANITA, "Dan Miller" })
	w:advance(1)
	local best = DR.NextSummon()
	ok(best ~= nil, "non-priority rider returned")
	eq(best.name, "Dan Miller", "correct rider returned")
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:473 (return -> nil: ritualName returns nil when DR.Ritual returns empty)
-- guards Wuber/Drive/Cast.lua:481 (cmp ==->~=: isRitual skips C_Spell.GetSpellName)
-- guards Wuber/Drive/Cast.lua:483 (cmp ==->~=: isRitual rejects spell matching ritualName)
test("mutation b5 drive cast: isRitual recognizes spell by ritualName fallback when DR.Ritual is empty", function()
	local w, a, DR = setupDriver()
	local origRitual = DR.Ritual
	local origCSpell = a.env.C_Spell
	DR.Ritual = function() return "" end
	a.env.C_Spell = {
		GetSpellName = function(id)
			if id == 99999 then return "Ritual of Summoning" end
			return "Fireball"
		end,
	}
	DR.cast = nil
	a:fire("UNIT_SPELLCAST_START", "player", "cast-1", 99999)
	ok(DR.cast ~= nil, "cast started for spell matching fallback Ritual of Summoning")
	DR.cast = nil
	DR.Ritual = origRitual
	a.env.C_Spell = origCSpell
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:477 (drop statement: string spellID not converted to number in isRitual)
-- Skipped: Wuber/Drive/Cast.lua:485 (return -> nil: unobservable because nil and false are both falsy in isRitual)
test("mutation b5 drive cast: isRitual handles string RITUAL_ID and rejects non-ritual spellID even with castIntent", function()
	local w, a, DR = setupDriver()
	DR.cast = nil
	DR.castIntent = { name = "Dan Miller", at = a.W.Now() }
	-- Non-ritual numeric spellID must return false, NOT fall through to castIntent
	a:fire("UNIT_SPELLCAST_START", "player", "cast-other", 116)
	eq(DR.cast, nil, "non-ritual spellID rejected despite recent castIntent")
	-- String spellID "698" must be converted via num() and recognized as RITUAL_ID
	a:fire("UNIT_SPELLCAST_START", "player", "cast-str", tostring(DR.RITUAL_ID))
	ok(DR.cast ~= nil, "string RITUAL_ID recognized")
	DR.cast = nil
	DR.castIntent = nil
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:490 (swap and->or: nil spellID ignores recent castIntent)
-- guards Wuber/Drive/Cast.lua:492 (return -> nil: nil spellID does not match open non-channel DR.cast)
test("mutation b5 drive cast: nil spellID matches recent castIntent or open non-channel cast", function()
	local w, a, DR = setupDriver()
	local t0 = a.W.Now()
	DR.cast = nil
	DR.castIntent = { name = "Dan Miller", at = t0 }
	a:fire("UNIT_SPELLCAST_START", "player", "cast-nil", nil)
	ok(DR.cast ~= nil, "nil spellID matched recent castIntent")
	DR.castIntent = nil
	-- Now DR.cast is open without channel: nil spellID on CHANNEL_START must attach channel
	a:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-nil", nil)
	ok(DR.cast.channel ~= nil, "nil spellID matched open non-channel DR.cast")
	DR.cast = nil
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:535 (if cond negated: existing DR.cast overwritten on channel start)
-- guards Wuber/Drive/Cast.lua:536 (swap and->or: channel start overwrites already-set cast.channel)
-- guards Wuber/Drive/Cast.lua:540 (drop statement: DR.cast not created on cast start)
-- guards Wuber/Drive/Cast.lua:544 (drop statement: seen[rk] not created when recording cast time)
-- guards Wuber/Drive/Cast.lua:550 (drop statement: DR.Changed not called on cast start)
test("mutation b5 drive cast: begin creates DR.cast, updates channel once, and notifies DRIVE", function()
	local w, a, DR = setupDriver()
	w:addBot("Dan Miller", { spot = "Ratchet", acceptsInvites = true })
	w:botWhisper("Dan Miller", a, "summon from orgrimmar to ratchet pls")
	w:advance(5)
	w:group({ T.ANITA, "Dan Miller" })
	w:advance(1)
	local changed = 0
	local origChanged = DR.Changed
	local origDo = DR.Do
	DR.Do = nil
	DR.Changed = function()
		changed = changed + 1
		return origChanged()
	end
	DR.castIntent = { name = "Fresh Rider", at = a.W.Now() }
	DR.cast = nil
	a:fire("UNIT_SPELLCAST_START", "player", "cast-1", DR.RITUAL_ID)
	ok(DR.cast ~= nil, "DR.cast created")
	eq(DR.cast.name, "Fresh Rider", "DR.cast targets Fresh Rider")
	ok(changed > 0, "DR.Changed called on cast start")
	a:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-1", DR.RITUAL_ID)
	local ch1 = DR.cast.channel
	ok(ch1 ~= nil, "cast.channel set on channel start")
	w:advance(2)
	a:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-1", DR.RITUAL_ID)
	eq(DR.cast.channel, ch1, "second channel start does not overwrite cast.channel")
	DR.Do = origDo
	DR.Changed = origChanged
	DR.cast = nil
	DR.castIntent = nil
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:640 (if cond negated: UNIT_SPELLCAST_SENT fires DRIVE_RITUAL in raid mode or skips in sell mode)
test("mutation b5 drive cast: UNIT_SPELLCAST_SENT fires DRIVE_RITUAL in sell mode and not in raid mode", function()
	local w, a, DR = setupDriver()
	w:addBot("Dan Miller", { spot = "Ratchet", acceptsInvites = true })
	w:botWhisper("Dan Miller", a, "summon from orgrimmar to ratchet pls")
	w:advance(5)
	w:group({ T.ANITA, "Dan Miller" })
	w:advance(1)
	local fired = 0
	a.W.Listen("DRIVE_RITUAL", function(_, kind)
		if kind == "t" then fired = fired + 1 end
	end)
	a:fire("UNIT_SPELLCAST_SENT", "player", "Dan Miller", "cast-s1", DR.RITUAL_ID)
	eq(fired, 1, "DRIVE_RITUAL 't' fired in sell mode")
	a.W.Char().mode = "raid"
	a:fire("UNIT_SPELLCAST_SENT", "player", "Dan Miller", "cast-s2", DR.RITUAL_ID)
	eq(fired, 1, "DRIVE_RITUAL 't' not fired in raid mode")
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:465 (swap and->or: SummonHeld returns un-summonable rider or non-pending rider)
test("mutation b5 drive cast: SummonHeld returns only a summonable rider with SummonPending", function()
	local w, a, DR = setupDriver()
	w:addBot("Dan Miller", { spot = "Orgrimmar", acceptsInvites = true })
	w:botWhisper("Dan Miller", a, "summon from orgrimmar to ratchet pls")
	w:advance(5)
	w:group({ T.ANITA, "Dan Miller" })
	w:advance(1)
	-- Dan is already here (Orgrimmar), so even if SummonPending is true, SummonHeld must return nil
	local origPending = DR.SummonPending
	DR.SummonPending = function() return true end
	eq(DR.SummonHeld(), nil, "already-here rider not returned by SummonHeld")
	-- Add Bea in Ratchet with SummonPending = false -> SummonHeld must still return nil
	w:addBot("Bea Jones", { spot = "Ratchet", acceptsInvites = true })
	w:botWhisper("Bea Jones", a, "summon from orgrimmar to ratchet pls")
	w:advance(5)
	w:group({ T.ANITA, "Dan Miller", "Bea Jones" })
	w:advance(1)
	DR.SummonPending = function() return false end
	eq(DR.SummonHeld(), nil, "non-pending rider not returned by SummonHeld")
	DR.SummonPending = function(c) return c.name == "Bea Jones" end
	local held = DR.SummonHeld()
	ok(held ~= nil and held.name == "Bea Jones", "pending summonable rider returned by SummonHeld")
	DR.SummonPending = origPending
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:527 (swap and->or: shardProof fails when shards/shardsMid nil or drops)
-- guards Wuber/Drive/Cast.lua:528 (local value -> nil: shardProof ignores current shard count)
-- guards Wuber/Drive/Cast.lua:529 (swap and->or: shardProof returns true when shard count did not drop)
test("mutation b5 drive cast: shardProof requires shard still present mid-channel and spent after channel", function()
	local w, a, DR = setupDriver()
	w:addBot("Dan Miller", { spot = "Ratchet", acceptsInvites = true })
	w:botWhisper("Dan Miller", a, "summon from orgrimmar to ratchet pls")
	w:advance(5)
	w:group({ T.ANITA, "Dan Miller" })
	w:advance(1)
	DR.opts().helpSeen = a.W.Build()
	local shards = 5
	local origShards = DR.Shards
	DR.Shards = function() return shards end
	local finished = nil
	a.W.Listen("DRIVE_RITUAL", function(_, kind)
		if kind == "s" or kind == "f" then finished = kind end
	end)
	-- Case 1: shard count stays 5 throughout -> shardProof is false -> finish(false)
	DR.castIntent = { name = "Dan Miller", at = a.W.Now() }
	DR.cast = nil
	a:fire("UNIT_SPELLCAST_START", "player", "cast-sp1", DR.RITUAL_ID)
	a:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-sp1", DR.RITUAL_ID)
	w:advance(1.5)
	DR.CastWatch(a.W.Now())
	a:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-sp1", DR.RITUAL_ID)
	w:advance(1.5)
	eq(finished, "f", "no shard spent -> summon failed")
	-- Case 2: shard count drops from 5 to 4 after channel stop -> shardProof is true -> finish(true)
	finished = nil
	DR.castIntent = { name = "Dan Miller", at = a.W.Now() }
	DR.cast = nil
	a:fire("UNIT_SPELLCAST_START", "player", "cast-sp2", DR.RITUAL_ID)
	a:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-sp2", DR.RITUAL_ID)
	w:advance(1.5)
	DR.CastWatch(a.W.Now())
	shards = 4
	a:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-sp2", DR.RITUAL_ID)
	w:advance(1.5)
	eq(finished, "s", "shard spent after mid-channel -> summon succeeded")
	-- Case 3: channel stops before mid-channel check (shardsMid is nil) -> shardProof returns false cleanly
	finished = nil
	shards = 5
	DR.castIntent = { name = "Dan Miller", at = a.W.Now() }
	DR.cast = nil
	a:fire("UNIT_SPELLCAST_START", "player", "cast-sp3", DR.RITUAL_ID)
	a:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-sp3", DR.RITUAL_ID)
	a:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-sp3", DR.RITUAL_ID)
	w:advance(1.5)
	eq(finished, "f", "no mid-channel shard check -> summon not proven")
	DR.Shards = origShards
	DR.cast = nil
	DR.castIntent = nil
	T.clean(w)
end)
