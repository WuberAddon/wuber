-- Mutation run guards for Wuber/Drive/Core.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setupDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	T.openDrive(a)
	return w, a, a.W.Drive
end

local function makePopup(a, opts)
	opts = opts or {}
	local pop = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	pop:SetSize(opts.w or 400, opts.h or 200)
	if opts.noGetScale then pop.GetScale = function() return nil end else pop:SetScale(opts.scale or 1) end
	if opts.noGetAlpha then pop.GetAlpha = function() return nil end else pop:SetAlpha(opts.alpha or 0.5) end
	if not opts.noText then
		local fs = pop:CreateFontString(nil, "OVERLAY")
		if opts.noGetFont then
			fs.GetFont = function() return nil end
		elseif opts.font then
			fs:SetFont(opts.font, opts.fontSize or 10, opts.flags or "")
		end
		if opts.strH ~= nil then
			fs.GetStringHeight = function() return opts.strH end
		end
		pop.text = fs
	end
	return pop
end

-- Skipped: Wuber/Drive/Core.lua:155 (return -> nil: unreachable fallback because all keys in DR.OPT_DEFAULTS and DR.OPT_LATE are special-cased, boolean, or string)

-- guards Wuber/Drive/Core.lua:247 (drop statement: wuberPublicOrig not cleared on restore)
test("mutation b5 drive core: RestorePublicWarning clears snapshot so a second restore returns false", function()
	local w, a, DR = setupDriver()
	local pop = makePopup(a, { font = "Fonts\\FRIZQT__.TTF", fontSize = 10, strH = 40 })
	ok(DR.PlacePublicWarning(pop), "places warning")
	ok(DR.RestorePublicWarning(pop), "first restore succeeds")
	eq(DR.RestorePublicWarning(pop), false, "second restore returns false when snapshot cleared")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:249 (swap and->or: nil wuberBack crashes on restore)
test("mutation b5 drive core: RestorePublicWarning handles missing wuberBack without error", function()
	local w, a, DR = setupDriver()
	local pop = makePopup(a, { font = "Fonts\\FRIZQT__.TTF", fontSize = 10, strH = 40 })
	ok(DR.PlacePublicWarning(pop), "places warning")
	pop.wuberBack = nil
	ok(DR.RestorePublicWarning(pop), "restores cleanly without wuberBack")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:250 (swap and->or: nil saved alpha calls SetAlpha(nil))
test("mutation b5 drive core: RestorePublicWarning does not call SetAlpha when original alpha was nil", function()
	local w, a, DR = setupDriver()
	local pop = makePopup(a, { noGetAlpha = true })
	ok(DR.PlacePublicWarning(pop), "places warning")
	local setAlphaCalled = false
	pop.SetAlpha = function() setAlphaCalled = true end
	ok(DR.RestorePublicWarning(pop), "restores warning")
	eq(setAlphaCalled, false, "SetAlpha not called when original alpha was nil")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:251 (swap and->or: nil saved scale calls SetScale(nil))
test("mutation b5 drive core: RestorePublicWarning does not call SetScale when original scale was nil", function()
	local w, a, DR = setupDriver()
	local pop = makePopup(a, { noGetScale = true })
	ok(DR.PlacePublicWarning(pop), "places warning")
	local setScaleCalled = false
	pop.SetScale = function() setScaleCalled = true end
	ok(DR.RestorePublicWarning(pop), "restores warning")
	eq(setScaleCalled, false, "SetScale not called when original scale was nil")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:252 (local value -> nil: pop.text font not restored)
test("mutation b5 drive core: RestorePublicWarning restores original popup text font and size", function()
	local w, a, DR = setupDriver()
	local pop = makePopup(a, { font = "Fonts\\FRIZQT__.TTF", fontSize = 10, flags = "OUTLINE", strH = 40 })
	ok(DR.PlacePublicWarning(pop), "places warning")
	local _, placedSize = pop.text:GetFont()
	ok(placedSize ~= 10, "font size changed while placed")
	ok(DR.RestorePublicWarning(pop), "restores warning")
	local font, size, flags = pop.text:GetFont()
	eq(font, "Fonts\\FRIZQT__.TTF", "font restored")
	eq(size, 10, "font size restored")
	eq(flags, "OUTLINE", "font flags restored")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:253 (swap and->or: missing pop.text with saved font crashes on restore)
test("mutation b5 drive core: RestorePublicWarning handles pop.text removed before restore", function()
	local w, a, DR = setupDriver()
	local pop = makePopup(a, { font = "Fonts\\FRIZQT__.TTF", fontSize = 10, strH = 40 })
	ok(DR.PlacePublicWarning(pop), "places warning")
	pop.text = nil
	ok(DR.RestorePublicWarning(pop), "restores cleanly when pop.text is nil")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:281 (drop statement: wuberBack not anchored to popup)
test("mutation b5 drive core: PlacePublicWarning anchors opaque backdrop to popup", function()
	local w, a, DR = setupDriver()
	local pop = makePopup(a, { font = "Fonts\\FRIZQT__.TTF", fontSize = 10, strH = 40 })
	ok(DR.PlacePublicWarning(pop), "places warning")
	ok(pop.wuberBack ~= nil, "backdrop created")
	ok(pop.wuberBack:GetNumPoints() > 0, "backdrop anchored to popup")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:282 (drop statement: wuberBack has no opaque color)
test("mutation b5 drive core: PlacePublicWarning colors opaque backdrop", function()
	local w, a, DR = setupDriver()
	local pop = makePopup(a, { font = "Fonts\\FRIZQT__.TTF", fontSize = 10, strH = 40 })
	local origCreate = pop.CreateTexture
	local colorArgs = nil
	pop.CreateTexture = function(self, ...)
		local tex = origCreate(self, ...)
		local origSetColor = tex.SetColorTexture
		tex.SetColorTexture = function(t, r, g, b, al)
			colorArgs = { r, g, b, al }
			if origSetColor then origSetColor(t, r, g, b, al) end
		end
		return tex
	end
	ok(DR.PlacePublicWarning(pop), "places warning")
	ok(colorArgs ~= nil, "SetColorTexture called on backdrop")
	eq(colorArgs[4], 1, "backdrop alpha is 1")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:288 (drop statement: popup width not set to fit phone)
test("mutation b5 drive core: PlacePublicWarning sets popup width to fit inside phone", function()
	local w, a, DR = setupDriver()
	local pop = makePopup(a, { w = 500, font = "Fonts\\FRIZQT__.TTF", fontSize = 10, strH = 40 })
	ok(DR.PlacePublicWarning(pop), "places warning")
	local pw = a.env.WuberFrame:GetWidth()
	local expected = math.min(340, pw - 40)
	eq(pop:GetWidth(), expected, "popup width matches phone-fitted width")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:292 (swap and->or: nil font calls SetFont(nil, ...))
test("mutation b5 drive core: PlacePublicWarning skips SetFont when text has no font", function()
	local w, a, DR = setupDriver()
	local pop = makePopup(a, { noGetFont = true, strH = 40 })
	local setFontCalled = false
	pop.text.SetFont = function() setFontCalled = true end
	ok(DR.PlacePublicWarning(pop), "places warning")
	eq(setFontCalled, false, "SetFont not called when GetFont is absent")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:293 (local value -> nil: popup height not resized to string height)
-- guards Wuber/Drive/Core.lua:294 (swap and->or: nil string height crashes comparing nil > 0)
test("mutation b5 drive core: PlacePublicWarning resizes popup height to text height and survives nil height", function()
	local w, a, DR = setupDriver()
	local pop1 = makePopup(a, { h = 200, font = "Fonts\\FRIZQT__.TTF", fontSize = 10, strH = 40 })
	ok(DR.PlacePublicWarning(pop1), "places warning with height")
	eq(pop1:GetHeight(), 130, "popup height set to string height + 90")
	local pop2 = makePopup(a, { h = 200, font = "Fonts\\FRIZQT__.TTF", fontSize = 10 })
	pop2.text.GetStringHeight = function() return nil end
	ok(DR.PlacePublicWarning(pop2), "places warning without error when string height is nil")
	eq(pop2:GetHeight(), 200, "popup height unchanged when string height is nil")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:302 (swap or->and: SetAutoPublic(false) before InitDB does not record publicChosen)
test("mutation b5 drive core: SetAutoPublic(false) initializes Drive DB and marks publicChosen", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local DR = a.W.Drive
	DR.db = nil
	eq(DR.SetAutoPublic(false), false, "returns false")
	ok(DR.db ~= nil, "Drive DB initialized")
	eq(DR.db.publicChosen, true, "publicChosen recorded")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:304 (cmp ==->~=: SetAutoPublic(false) skips DR.SetOpt when DR.SetOpt is a function)
test("mutation b5 drive core: SetAutoPublic(false) calls DR.SetOpt when available", function()
	local w, a, DR = setupDriver()
	local origSetOpt = DR.SetOpt
	local calledKey, calledVal
	DR.SetOpt = function(k, v)
		calledKey, calledVal = k, v
		return origSetOpt(k, v)
	end
	DR.SetAutoPublic(false)
	DR.SetOpt = origSetOpt
	eq(calledKey, "autoPublic", "SetOpt called with autoPublic")
	eq(calledVal, false, "SetOpt called with false")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:623 (swap and->or: AddPlainHelper calls AddSummoner even when crew is full)
test("mutation b5 drive core: AddPlainHelper does not add summoner when crew is already full", function()
	local w, a, DR = setupDriver()
	for i = 1, DR.CREW_MAX do
		ok(DR.SetCrewMember("Crew Member" .. i, "helper", true), "added crew " .. i)
	end
	local origAdd = DR.AddSummoner
	local called = false
	DR.AddSummoner = function(name) called = name end
	local res = DR.AddPlainHelper("Extra Lock", "L")
	DR.AddSummoner = origAdd
	eq(res, nil, "crew full rejects 9th member")
	eq(called, false, "AddSummoner not called when SetCrewMember failed")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:624 (if cond negated: AddPlainHelper does not mark existing offer as yes)
test("mutation b5 drive core: AddPlainHelper marks matching offer state as yes", function()
	local w, a, DR = setupDriver()
	DR.offers = DR.offers or {}
	DR.offers["bea jones"] = { name = "Bea Jones", state = "pending" }
	local m = DR.AddPlainHelper("Bea Jones", "helper")
	ok(m ~= nil, "member added")
	eq(DR.offers["bea jones"].state, "yes", "offer marked yes")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:900 (return -> nil: mergeLines breaks tie order when timestamps match)
test("mutation b5 drive core: ImportRR preserves order of log lines with identical timestamps", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local DR = a.W.Drive
	DR.db.imported = nil
	DR.char().rrChar = false
	a.env.RitualRidesDB = {
		log = {
			rides = {
				"2026-11-20 12:00 First Rider",
				"2026-11-20 12:00 Second Rider",
				"2026-11-20 12:00 Third Rider",
				"2026-11-20 12:00 Fourth Rider",
				"2026-11-20 12:00 Fifth Rider",
				"2026-11-20 12:00 Sixth Rider",
			},
		},
	}
	ok(DR.ImportRR(), "import succeeds")
	local rides = DR.db.log.rides
	eq(rides[1], "2026-11-20 12:00 First Rider", "first line stays first")
	eq(rides[2], "2026-11-20 12:00 Second Rider", "second line stays second")
	eq(rides[3], "2026-11-20 12:00 Third Rider", "third line stays third")
	eq(rides[4], "2026-11-20 12:00 Fourth Rider", "fourth line stays fourth")
	eq(rides[5], "2026-11-20 12:00 Fifth Rider", "fifth line stays fifth")
	eq(rides[6], "2026-11-20 12:00 Sixth Rider", "sixth line stays sixth")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:983 (cmp ==->~=: ImportRR skips bellLead string)
-- guards Wuber/Drive/Core.lua:984 (cmp ==->~=: ImportRR skips bellService string)
-- guards Wuber/Drive/Core.lua:994 (cmp ==->~=: ImportRR skips button scale)
-- guards Wuber/Drive/Core.lua:996 (cmp ==->~=: ImportRR skips button boolean flags)
-- guards Wuber/Drive/Core.lua:1038 (cmp ==->~=: ImportRR skips char dest)
-- guards Wuber/Drive/Core.lua:1039 (cmp ==->~=: ImportRR skips char destWords)
-- guards Wuber/Drive/Core.lua:1044 (cmp ==->~=: ImportRR skips char paused)
test("mutation b5 drive core: ImportRR copies bell, button and character fields from RitualRidesDB", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local DR = a.W.Drive
	DR.db.imported = nil
	DR.char().rrChar = false
	a.env.RitualRidesDB = {
		bellLead = "Bea Jones",
		bellService = "Fast Locks",
		scale = 1.5,
		sizeSet = true,
		locked = true,
		shown = false,
		dest = "Undercity",
		destWords = "uc, under",
		paused = true,
	}
	ok(DR.ImportRR(), "import succeeds")
	eq(DR.db.bell.lead, "Bea Jones", "bellLead imported")
	eq(DR.db.bell.service, "Fast Locks", "bellService imported")
	eq(DR.db.button.scale, 1.5, "button scale imported")
	eq(DR.db.button.sizeSet, true, "button sizeSet imported")
	eq(DR.db.button.locked, true, "button locked imported")
	eq(DR.db.button.shown, false, "button shown imported")
	eq(DR.char().dest, "Undercity", "char dest imported")
	eq(DR.char().destWords, "uc, under", "char destWords imported")
	eq(DR.char().paused, true, "char paused imported")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:1019 (return -> nil: empty rr.team does not fall back to RitualRides_Team)
test("mutation b5 drive core: ImportRR falls back to RitualRides_Team when rr.team is empty", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local DR = a.W.Drive
	DR.db.imported = nil
	DR.char().rrChar = false
	a.env.RitualRidesDB = { team = {} }
	a.env.RitualRides_Team = { "Bea Jones" }
	ok(DR.ImportRR(), "import succeeds")
	local crew = DR.char().crew
	eq(#crew, 1, "crew imported from RitualRides_Team")
	eq(crew[1].name, "Bea Jones", "crew member name matches")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:1022 (cmp ==->~=: empty RitualRides_Team skips GigaLocksTeam fallback)
test("mutation b5 drive core: ImportRR falls back to GigaLocksTeam when RitualRides_Team is empty", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local DR = a.W.Drive
	DR.db.imported = nil
	DR.char().rrChar = false
	a.env.RitualRidesDB = { team = {} }
	a.env.RitualRides_Team = {}
	a.env.GigaLocksTeam = { "Cal Brown" }
	ok(DR.ImportRR(), "import succeeds")
	local crew = DR.char().crew
	eq(#crew, 1, "crew imported from GigaLocksTeam")
	eq(crew[1].name, "Cal Brown", "crew member name matches")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:1172 (return true->false: ImportRR returns false on fresh charSeed import)
-- guards Wuber/Drive/Core.lua:1200 (if cond negated: ImportRR does not fire DRIVE_CREW when did is true)
test("mutation b5 drive core: ImportRR returns true on charSeed import and fires DRIVE_CREW on full import", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local DR = a.W.Drive
	-- Full import with DRIVE_CREW listener
	local fired = 0
	a.W.Listen("DRIVE_CREW", function() fired = fired + 1 end)
	DR.db.imported = nil
	DR.char().rrChar = false
	a.env.RitualRidesDB = { dest = "Orgrimmar" }
	eq(DR.ImportRR(), true, "full import returns true")
	ok(fired > 0, "DRIVE_CREW fired on full import")
	-- Fresh charSeed import without RitualRidesDB
	a.env.RitualRidesDB = nil
	DR.db.imported = { at = a.env.time(), charSeed = { dest = "Thunder Bluff" } }
	DR.char().rrChar = false
	eq(DR.ImportRR(), true, "charSeed import returns true")
	eq(DR.char().dest, "Thunder Bluff", "charSeed dest applied")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:1226 (swap and->or: Snapshot saves lead customers into queue.list)
test("mutation b5 drive core: Snapshot does not save lead-only customers in queue", function()
	local w, a, DR = setupDriver()
	DR.on = true
	DR.customers = {
		["dan miller"] = { key = "dan miller", name = "Dan Miller", state = "lead", order = 1 },
	}
	DR.Snapshot()
	eq(DR.char().queue, nil, "lead-only customer is not saved in queue snapshot")
	T.clean(w)
end)

-- guards Wuber/Drive/Core.lua:1284 (cmp ==->~=: RestoreQueue skips arrivedAt for arrived customers)
test("mutation b5 drive core: RestoreQueue sets arrivedAt when restoring an arrived rider", function()
	local w, a, DR = setupDriver()
	w:addBot("Dan Miller", { spot = "Undercity", acceptsInvites = true })
	a.env.InviteUnit("Dan Miller")
	w:advance(3)
	DR.char().queue = {
		at = a.env.time(),
		list = {
			{ key = "dan miller", name = "Dan Miller", state = "arrived", source = "group", order = 1 },
		},
	}
	DR.customers = {}
	DR.RestoreQueue()
	local cust = DR.customers["dan miller"]
	ok(cust ~= nil, "arrived customer restored")
	ok(cust.arrivedAt ~= nil, "arrivedAt set for restored arrived rider")
	T.clean(w)
end)
