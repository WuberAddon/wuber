-- Mutation run guards for Wuber/Drive/Commands.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setupDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	return w, a, a.W.Drive
end

-- guards Wuber/Drive/Commands.lua:57 (swap and->or: show() indexes nil W.Driver when UI.ShowDrive is absent)
-- guards Wuber/Drive/Commands.lua:58 (return false->true: show() returns true when UI.ShowDrive is absent)
test("mutation b5 drive commands: team command handles missing ShowDrive and Driver cleanly", function()
	local w, a, DR = setupDriver()
	local origUI, origDriver = a.W.UI, a.W.Driver
	a.W.UI = nil
	a.W.Driver = nil
	DR.Command("team")
	a.W.UI, a.W.Driver = origUI, origDriver
	ok(a:said("The crew wizard isn't loaded."), "team prints fallback when ShowDrive is absent")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:129 (swap and->or: open() omits trailing period on reason without punctuation)
test("mutation b5 drive commands: on command appends a period when SetOpen reason lacks punctuation", function()
	local w, a, DR = setupDriver()
	local origSetOpen = DR.SetOpen
	local origOpenWhy = a.W.Driver and a.W.Driver.OPEN_WHY
	if a.W.Driver then a.W.Driver.OPEN_WHY = nil end
	DR.SetOpen = function() return false, "missing_stuff" end
	DR.Command("on")
	DR.SetOpen = origSetOpen
	if a.W.Driver then a.W.Driver.OPEN_WHY = origOpenWhy end
	ok(a:said("missing_stuff."), "period appended to SetOpen failure reason")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:153 (return false->true: helper is allowed to pause/resume)
test("mutation b5 drive commands: helper cannot pause or resume via slash command", function()
	local w = T.newWorld()
	local h = T.rider(w, T.BEA, { spot = "Orgrimmar", class = "MAGE", saved = {
		Wuber = { chars = { ["bea jones"] = { captain = T.ANITA } } },
	} })
	T.settle(w)
	local DR = h.W.Drive
	local origSetPaused = DR.SetPaused
	local called = false
	DR.SetPaused = function() called = true end
	DR.Command("pause")
	DR.SetPaused = origSetPaused
	eq(called, false, "SetPaused not called for helper")
	ok(h:said("can pause or resume"), "helper told only Warlock can pause")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:176 (drop statement: price below MIN_PRICE does not tell player lowest fare)
test("mutation b5 drive commands: price below minimum prints lowest fare notice", function()
	local w, a, DR = setupDriver()
	DR.Command("price 1s")
	ok(a:said("lowest fare is"), "prints lowest fare notice when price is below minimum")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:215 (drop statement: ad <channels> does not confirm advert channels)
-- guards Wuber/Drive/Commands.lua:221 (cmp ==->~=: ad command drops NextAd channel index)
test("mutation b5 drive commands: ad command confirms channels and passes NextAd channel to AdvertPlan", function()
	local w, a, DR = setupDriver()
	local origNextAd = DR.NextAd
	local origPlan = a.W.AdvertPlan
	local gotChannel
	DR.NextAd = function() return { index = 3, name = "Trade" } end
	a.W.AdvertPlan = function(d, p, opts)
		gotChannel = opts and opts.channel
		return nil, "other"
	end
	DR.Command("ad trade")
	DR.NextAd = origNextAd
	a.W.AdvertPlan = origPlan
	ok(a:said("Adverts go to: trade, in turn."), "adverts channels confirmed")
	eq(gotChannel, 3, "NextAd channel index passed to AdvertPlan")
	ok(a:said("There's no advert to post."), "prints fallback when AdvertPlan fails")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:381 (drop statement: mode command does not confirm new whisper mode)
test("mutation b5 drive commands: mode command confirms whisper mode change", function()
	local w, a, DR = setupDriver()
	DR.Command("mode box")
	ok(a:said("Whispers: box."), "mode confirms whisper mode")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:392 (swap or->and: max command prints nil when DR.MaxGroup is absent)
test("mutation b5 drive commands: max command falls back to opts().maxGroup when DR.MaxGroup is nil", function()
	local w, a, DR = setupDriver()
	local origMax = DR.MaxGroup
	DR.MaxGroup = function() return nil end
	DR.Command("max 10")
	DR.MaxGroup = origMax
	ok(a:said("Largest group: 10."), "max prints opts().maxGroup fallback")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:396 (swap and->or: msgs crashes when W.db.drive is nil)
-- guards Wuber/Drive/Commands.lua:398 (drop statement: msgs does not print template lines)
-- guards Wuber/Drive/Commands.lua:400 (swap or->and: msgs crashes or prints wrong placeholders when PLACEHOLDERS is nil)
test("mutation b5 drive commands: msgs prints templates and placeholders even without drive db or PLACEHOLDERS", function()
	local w, a, DR = setupDriver()
	DR.Command("msgs")
	ok(a:said("Placeholders:"), "msgs prints placeholders")
	ok(a:said("greet"), "msgs prints template kind")
	local origDB = a.W.db
	local origPH = DR.PLACEHOLDERS
	a.W.db = nil
	DR.PLACEHOLDERS = nil
	DR.Command("msgs")
	a.W.db = origDB
	DR.PLACEHOLDERS = origPH
	ok(a:said("Placeholders: {}"), "msgs handles nil PLACEHOLDERS")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:405 (drop statement: msg command does not lowercase kind)
-- guards Wuber/Drive/Commands.lua:407 (drop statement: msg command does not list valid kinds on unknown kind)
test("mutation b5 drive commands: msg command lowercases kind and lists kinds on unknown kind", function()
	local w, a, DR = setupDriver()
	DR.Command("msg GREET")
	ok(a:said("greet:"), "uppercase kind lowercased and shown")
	DR.Command("msg nosuchkind hello")
	ok(a:said("the kinds:"), "unknown kind lists valid template kinds")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:437 (drop statement: keywords command does not save keywords option)
test("mutation b5 drive commands: keywords command saves cleaned keywords", function()
	local w, a, DR = setupDriver()
	DR.Command("keywords port, taxi")
	eq(table.concat(DR.opts().keywords, " "), "port taxi", "keywords saved in opts")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:476 (drop statement: bell off does not call BellSet(''))
-- guards Wuber/Drive/Commands.lua:477 (drop statement: bell off does not print 'No alert character.')
-- guards Wuber/Drive/Commands.lua:482 (drop statement: bell forget does not call BellForget)
-- guards Wuber/Drive/Commands.lua:483 (drop statement: bell forget does not print confirmation)
test("mutation b5 drive commands: bell off and bell forget call engine helpers and confirm", function()
	local w, a, DR = setupDriver()
	local setArg, forgot = "unset", false
	local origSet, origForget = DR.BellSet, DR.BellForget
	DR.BellSet = function(v) setArg = v end
	DR.BellForget = function() forgot = true end
	DR.Command("bell off")
	eq(setArg, "", "bell off calls BellSet('')")
	ok(a:said("No alert character."), "bell off prints confirmation")
	DR.Command("bell forget")
	eq(forgot, true, "bell forget calls BellForget")
	ok(a:said("forgot the crews"), "bell forget prints confirmation")
	DR.BellSet, DR.BellForget = origSet, origForget
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:492 (drop statement: stats reset does not call ResetStats)
-- guards Wuber/Drive/Commands.lua:493 (drop statement: stats reset does not print 'Counts reset.')
test("mutation b5 drive commands: stats reset calls ResetStats and confirms", function()
	local w, a, DR = setupDriver()
	local resetCalled = false
	local origReset = DR.ResetStats
	DR.ResetStats = function() resetCalled = true end
	DR.Command("stats reset")
	DR.ResetStats = origReset
	eq(resetCalled, true, "stats reset calls ResetStats")
	ok(a:said("Counts reset."), "stats reset prints confirmation")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:510 (drop statement: raid prints nothing when SetMode is absent)
-- guards Wuber/Drive/Commands.lua:520 (swap and->or: raid prints CanRunRaid reason even when can is true)
test("mutation b5 drive commands: raid handles missing SetMode and omits Not yet when CanRunRaid is true", function()
	local w, a, DR = setupDriver()
	local origSetMode, origCan = DR.SetMode, DR.CanRunRaid
	DR.SetMode = nil
	DR.Command("raid")
	ok(a:said("This version can't switch modes."), "prints unsupported message when SetMode is nil")
	DR.SetMode = function() return true end
	DR.CanRunRaid = function() return true, "ignored reason" end
	DR.Command("raid")
	DR.SetMode, DR.CanRunRaid = origSetMode, origCan
	ok(a:said("Raid summons: raiders who say 123 in raid chat are summoned at no charge."), "prints raid line without Not yet")
	eq(a:said("Not yet:"), false, "does not print Not yet when CanRunRaid is true")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:613 (swap and->or: hide crashes when DR.Button is nil)
-- guards Wuber/Drive/Commands.lua:614 (drop statement: hide does not print hidden notice)
-- guards Wuber/Drive/Commands.lua:618 (drop statement: lock does not print locked notice)
-- guards Wuber/Drive/Commands.lua:622 (drop statement: unlock does not print unlocked notice)
-- guards Wuber/Drive/Commands.lua:626 (drop statement: resetpos does not print centered notice)
test("mutation b5 drive commands: hide, lock, unlock, and resetpos print notices and handle nil Button", function()
	local w, a, DR = setupDriver()
	local origBtn = DR.Button
	DR.Button = nil
	DR.Command("hide")
	DR.Button = origBtn
	ok(a:said("The big button is hidden."), "hide prints notice")
	DR.Command("lock")
	ok(a:said("The big button stays where it is."), "lock prints notice")
	DR.Command("unlock")
	ok(a:said("to move it."), "unlock prints notice")
	DR.Command("resetpos")
	ok(a:said("The big button is back in the middle."), "resetpos prints notice")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:671 (cmp ==->~=: market on stays silent when SetAutoPublic returns nil)
test("mutation b5 drive commands: market on reports when warning cannot be shown", function()
	local w, a, DR = setupDriver()
	local origAuto = DR.SetAutoPublic
	DR.SetAutoPublic = function() return nil end
	DR.Command("market on")
	DR.SetAutoPublic = origAuto
	ok(a:said("the warning can't be shown right now"), "prints warning unavailable notice")
	T.clean(w)
end)
