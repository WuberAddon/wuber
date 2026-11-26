-- Tests of the developer-only flight recorder addon (WuberRec, never shipped) in the fake game: its
-- switch, its limits, its privacy rules, its error rules, every snapshot, and the sample session
-- (tests/fixtures/rec/sim-*.lua) made from a simulated ten-minute ride. Loaded by tests/run.lua with its
-- helper table T. Every test here also proves the recorder changed no frame but its own and sent nothing.
local T = ...
local H, test, eq, ok, list = T.H, T.testOutside or T.test, T.eq, T.ok, T.list -- (testOutside: not in the behaviour transcript)

local ADDON = dofile(T.dir .. "/lib/rec_addon.lua") -- where the recorder is, and which version these tests are for
local REC_DIR = ADDON.dir()
if not ADDON.have() then
	test("rec: recorder: skipped (" .. ADDON.why() .. ")", function() end)
	return
end
H.ADDONS.WuberRec = REC_DIR

local ROOT = T.dir .. "/.."
local IMP = assert(loadfile(ROOT .. "/tools/rec/import.lua"))("--lib")
local SES = IMP.SES
local OUT = T.dir .. "/out/rec"
local SIM_WTF = OUT .. "/WTF"
local SIM_FILE = SIM_WTF .. "/Account/SIM/SavedVariables/WuberRec.lua"
local FIXTURES = T.dir .. "/fixtures/rec"

-- the author's four characters keep their names; other players are someone else
local ROCKS, ANITA, FARRA = "Wuber Rocks", "Anita Lift", "Farra Way"
local OTHER = T.BOB

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function mkdir(path)
	if package.config:sub(1, 1) == "\\" then
		os.execute('if not exist "' .. path:gsub("/", "\\") .. '" mkdir "' .. path:gsub("/", "\\") .. '"')
	else
		os.execute('mkdir -p "' .. path .. '"')
	end
end

-- If the external recorder copy's Data.lua predates this tree's Wuber/ (e.g. missing UnitFullName),
-- stage a copy in tests/out/rec/addon-<process> with Data.lua generated from this tree so sim-*.lua tests this tree.
-- One folder per process: the shards run side by side and must not write the same files (Event 1 merge, from the other side's E1-17).
do
	local GEN = assert(loadfile(ROOT .. "/tools/rec/gen-data.lua"))("--lib")
	local fresh = assert(GEN.generate(ROOT))
	if T.readFile(REC_DIR .. "/Data.lua") ~= fresh then
		local tmp = os.tmpname() or ""
		pcall(os.remove, tmp)
		local stage = OUT .. "/addon-" .. tmp:gsub("[^%w]", "") .. "-" .. os.time()
		mkdir(stage)
		for _, f in ipairs({ "WuberRec.toc", "Rec.lua", "Snaps.lua" }) do
			local body = assert(T.readFile(REC_DIR .. "/" .. f))
			local fh = assert(io.open(stage .. "/" .. f, "wb"))
			fh:write(body)
			fh:close()
		end
		local fh = assert(io.open(stage .. "/Data.lua", "wb"))
		fh:write(fresh)
		fh:close()
		REC_DIR = stage
		H.ADDONS.WuberRec = stage
	end
end

local function recClient(w, name, opts)
	opts = opts or {}
	return w:addClient(name or ROCKS, { spot = opts.spot or "Orgrimmar", class = opts.class or "MAGE", money = opts.money or 100000,
		addons = opts.alone and { "WuberRec" } or { "Wuber", "WuberRec" }, allowMissing = opts.alone or not T.HAVE_UI,
		saved = opts.saved, secrets = opts.secrets })
end

local function Rec(c) return c.ns.WuberRec end
local function DB(c) return c.env.WuberRecDB end
local function sess(c)
	local db = DB(c)
	return db and db.sessions[#db.sessions]
end
local function fx(s) return SES.convert(s, "sim") end

local function eventsOf(c, name, s)
	local out = {}
	for _, e in ipairs(fx(s or sess(c)).events) do
		if not name or e.e == name then out[#out + 1] = e end
	end
	return out
end

local function snapsOf(c, id, s)
	local out = {}
	for _, r in ipairs(fx(s or sess(c)).snaps) do
		if not id or r.id == id then out[#out + 1] = r end
	end
	return out
end

-- the recorder's own chat lines
local function said(c, part)
	local n = 0
	for _, l in ipairs(c.chatLines) do
		if l:find("Wuber Rec", 1, true) and (not part or l:find(part, 1, true)) then n = n + 1 end
	end
	return n
end

local function eventsOn(c)
	local out = {}
	local f = Rec(c).frame
	for e in pairs(T.S[f].events) do out[#out + 1] = e end
	table.sort(out)
	return out
end

local function text(v) return IMP.serialize(v) end

local function has(t, v)
	for _, x in ipairs(t) do if x == v then return true end end
	return false
end

-- A real ride's first half (as tests/round2.lua's rideToArrived): book, invited, summoned, arrived.
local function rideToArrived(w, d, r, key)
	T.goOnline(d)
	r.W.RequestRide(key)
	w:advance(3)
	if not w:player(r.player.name).group then
		w.hardware = r
		r.W.AcceptInvite()
		w.hardware = nil
		w:advance(1)
	end
	w:summon(d, r.player.name)
	w:advance(1)
	w.hardware = r
	r.W.AcceptSummon()
	w.hardware = nil
	w:advance(3)
end

local function payFare(w, d, r)
	local price = r.W.ride and r.W.ride.price or 5000
	w:openTrade(d, r)
	w:advance(1)
	w:typeTradeMoney(r, 0, 0, price)
	w:advance(0.5)
	w:tradeAccept(d)
	w:tradeAccept(r)
	w:advance(2)
end

---------------------------------------------------------------------------
-- The watch: what the recorder's own code does to frames and the network
---------------------------------------------------------------------------

local function fromRec()
	for level = 3, 60 do
		local info = debug.getinfo(level, "S")
		if not info then return false end
		local src = info.source or ""
		if src:find(REC_DIR, 1, true) then return true end
	end
	return false
end

local CHANGERS = { "Show", "Hide", "SetShown", "SetPoint", "SetAllPoints", "ClearAllPoints", "SetParent", "SetAttribute", "SetAlpha",
	"SetSize", "SetWidth", "SetHeight", "SetScale", "SetFrameStrata", "SetFrameLevel", "EnableMouse", "EnableKeyboard", "Click",
	"SetScript", "HookScript", "RegisterEvent", "RegisterUnitEvent", "UnregisterEvent", "RegisterAllEvents", "UnregisterAllEvents",
	"SetText", "SetFormattedText", "SetTexture", "SetVertexColor", "SetTextColor", "Raise", "Lower", "StartMoving", "SetMovable",
	"SetToplevel", "SetClampedToScreen", "SetMapID", "SetOwner", "AddLine", "SetChecked", "SetValue", "Enable", "Disable",
	"SetFocus", "ClearFocus", "SetPropagateKeyboardInput", "Play", "Stop" }
-- on its own frame, only these (and SetScript only for OnEvent)
local OWN = { SetScript = true, RegisterEvent = true, UnregisterEvent = true }
local SENDERS = { "sendAddon", "whisper", "runMacro", "publicLine", "groupLine", "invite", "openTrade" }

local function widgetClasses()
	for i = 1, 60 do
		local name, v = debug.getupvalue(H.applyForbidden, i)
		if not name then break end
		if name == "classes" then return v end
	end
	error("the harness's widget classes were not found (H.applyForbidden's upvalue 'classes')")
end

local function watch()
	local W = { calls = {}, made = {}, sent = {} }
	local undo = {}
	for _, cls in pairs(widgetClasses()) do
		for _, m in ipairs(CHANGERS) do
			local orig = rawget(cls, m)
			if type(orig) == "function" then
				undo[#undo + 1] = { cls, m, orig }
				cls[m] = function(self, ...)
					if fromRec() then W.calls[#W.calls + 1] = { m = m, f = self, a = (...) } end
					return orig(self, ...)
				end
			end
		end
	end
	for _, m in ipairs(SENDERS) do
		local orig = H.World[m]
		if type(orig) == "function" then
			undo[#undo + 1] = { H.World, m, orig }
			H.World[m] = function(...)
				if fromRec() then W.sent[#W.sent + 1] = m end
				return orig(...)
			end
		end
	end
	local origCreate = H.createFrame
	undo[#undo + 1] = { H, "createFrame", origCreate }
	H.createFrame = function(client, ftype, name, parent, template, ...)
		local f = origCreate(client, ftype, name, parent, template, ...)
		if fromRec() then W.made[#W.made + 1] = { ftype = ftype, name = name, parent = parent, template = template, f = f } end
		return f
	end
	function W.off()
		for i = #undo, 1, -1 do
			local u = undo[i]
			u[1][u[2]] = u[3]
		end
		undo = {}
	end
	-- every frame call the recorder made was on a frame it made itself, and only OWN calls
	function W.check()
		local mine = {}
		for _, m in ipairs(W.made) do
			mine[m.f] = true
			eq(m.ftype, "Frame", "the recorder made a " .. tostring(m.ftype))
			ok(m.name == nil and m.template == nil, "the recorder's frame has no name and no template")
		end
		for _, c in ipairs(W.calls) do
			ok(mine[c.f] and OWN[c.m], "the recorder called " .. c.m .. " on " .. tostring(c.f))
			if c.m == "SetScript" then eq(c.a, "OnEvent", "SetScript only for OnEvent") end
		end
		eq(#W.sent, 0, "the recorder sent something: " .. list(W.sent))
	end
	return W
end

-- the world is clean, and the recorder set no cvar
local function recClean(w, opts)
	opts = opts or {}
	T.clean(w, opts)
	eq(#w.blocked, 0, "blocked actions (" .. list(w.blocked, "\n") .. ")")
	for _, c in ipairs(w.clients) do
		for _, s in ipairs(c.cvarSets) do
			ok(not tostring(s.by):find("WuberRec", 1, true), "the recorder set the cvar " .. tostring(s.name))
		end
		local R = c.ns and c.ns.WuberRec
		if R and not opts.recError then
			eq(R.IsDead(), false, c.player.name .. ": the recorder stopped after an error: " .. tostring(DB(c) and DB(c).lastError and DB(c).lastError.text))
		end
	end
end

-- a test with the watch on: it fails when the recorder touched a frame not its own or sent anything
local function rtest(name, fn)
	test("rec: " .. name, function()
		local W = watch()
		local okRun, err = xpcall(function() fn(W) end, function(e) return debug.traceback(tostring(e), 2) end)
		W.off()
		if not okRun then error(err, 0) end
		W.check()
	end)
end

---------------------------------------------------------------------------
-- The switch
---------------------------------------------------------------------------

rtest("recorder alone: it loads without Wuber, is off by default, then records and stops", function(W)
	local w = T.newWorld()
	local c = recClient(w, ROCKS, { alone = true })
	w:advance(5)
	local R = Rec(c)
	ok(R and R.VERSION and R.frame, "loaded")
	eq(#W.made, 1, "one frame made")
	eq(type(DB(c)), "table", "saved data made")
	eq(DB(c).on, false, "off")
	eq(#DB(c).sessions, 0, "no session")
	eq(#eventsOn(c), 0, "no event registered after the loading screen: " .. list(eventsOn(c)))
	c:slash("/rec on")
	w:advance(5)
	ok(R.on, "on")
	local s = sess(c)
	eq(s.char, ROCKS, "the character")
	ok(#snapsOf(c, "client") == 1 and #snapsOf(c, "screen") == 1, "client and screen snapshots")
	local wu = snapsOf(c, "wuber")[1]
	ok(wu and wu.d.loaded == false, "the wuber snapshot says Wuber is not loaded")
	c:slash("/rec off")
	ok(not R.on, "off")
	eq(s.stop, "off")
	eq(#eventsOn(c), 0, "no event registered when off")
	recClean(w)
end)

rtest("off by default with Wuber: no session, no rows, no event registered while Wuber's traffic flows", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	local c = recClient(w, ROCKS)
	w:advance(15)
	T.goOnline(d)
	w:advance(30)
	ok(#w.addonLog > 0, "Wuber's messages flowed")
	eq(DB(c).on, false)
	eq(#DB(c).sessions, 0, "no session")
	eq(Rec(c).sess, nil, "no session in memory")
	eq(#eventsOn(c), 0, "no event registered: " .. list(eventsOn(c)))
	eq(said(c), 0, "it said nothing")
	recClean(w)
end)

rtest("/rec on starts a session, /rec status says so, /rec off stops it and unregisters every event", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS)
	w:advance(10)
	local R = Rec(c)
	c:slash("/rec snap")
	eq(said(c, "off: /rec on first."), 1, "snap while off")
	c:slash("/rec on")
	ok(R.on, "on")
	eq(said(c, "on for 60 minutes"), 1, "said on")
	local s = sess(c)
	eq(s.why, "on")
	eq(DB(c).on, true)
	eq(DB(c)["until"], c.env.time() + 3600, "the end time")
	local on = eventsOn(c)
	for _, e in ipairs(R.EVENTS) do
		ok(has(on, e) or has(s.unknownEvents, e), e .. " registered or listed as unknown")
	end
	w:advance(3)
	c:slash("/rec status")
	eq(said(c, "on: "), 1, "status while on")
	c:slash("/rec mark the bird card")
	local m = eventsOf(c, "REC_MARK")
	eq(#m, 1, "a mark")
	eq(m[1].a[1], "the bird card")
	c:slash("/rec snap")
	ok(said(c, "snapshots taken.") == 1, "snap")
	c:slash("/rec on")
	eq(#DB(c).sessions, 1, "a second /rec on starts nothing new")
	c:slash("/rec off")
	ok(not R.on, "off")
	eq(s.stop, "off")
	eq(DB(c).on, false)
	eq(#eventsOn(c), 0, "no event registered: " .. list(eventsOn(c)))
	c:slash("/rec status")
	eq(said(c, "off. 1 session(s) saved."), 1, "status while off")
	c:slash("/rec")
	ok(said(c, "(/rec on, off, snap, mark") >= 1, "help")
	recClean(w)
end)

rtest("the 60-minute limit: it turns itself off, saves why, and a /reload then does not start it", function()
	local w = T.newWorld({ frameStep = 0.5 })
	local c = recClient(w, ROCKS)
	w:advance(10)
	c:slash("/rec on")
	w:advance(59 * 60)
	ok(Rec(c).on, "still on after 59 minutes")
	w:advance(61)
	ok(not Rec(c).on, "off after 60")
	eq(DB(c).on, false)
	local s = DB(c).sessions[1]
	eq(s.stop, "timeout")
	ok(s.ended >= 3599 and s.ended <= 3602, "ended at the hour: " .. tostring(s.ended))
	eq(said(c, "60 minutes are up"), 1)
	eq(#eventsOn(c), 0, "no event registered")
	local c2 = w:reload(c)
	w:advance(5)
	eq(#DB(c2).sessions, 1, "no new session")
	ok(not Rec(c2).on, "off after the reload")
	recClean(w)
end)

rtest("a /reload inside the hour carries on in a new session that starts with the login rows and their facts", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS)
	w:advance(10)
	c:slash("/rec on")
	w:advance(30)
	local c2 = w:reload(c)
	w:advance(5)
	local db = DB(c2)
	eq(#db.sessions, 2, "a second session")
	eq(db.sessions[1].stop, "logout", "the first one ended with the logout")
	local s = db.sessions[2]
	eq(s.why, "boot")
	ok(Rec(c2).on, "on")
	local ev = eventsOf(c2, nil, s)
	local names = {}
	for i = 1, 4 do names[i] = ev[i] and ev[i].e end
	eq(table.concat(names, ","), "ADDON_LOADED,ADDON_LOADED,PLAYER_LOGIN,PLAYER_ENTERING_WORLD", "the first rows")
	eq(ev[1].a[1], "Wuber")
	eq(ev[2].a[1], "WuberRec")
	-- a /reload is not a login: PLAYER_ENTERING_WORLD(false, true), as the real client sends it (lane B1)
	eq(ev[4].a[1], false, "PLAYER_ENTERING_WORLD isInitialLogin after a /reload")
	eq(ev[4].a[2], true, "PLAYER_ENTERING_WORLD isReloadingUi after a /reload")
	for i = 1, 4 do
		ok(ev[i].db == "table" and ev[i].wdb == "table" and type(ev[i].li) == "boolean", "row " .. i .. " has db, wdb, li")
	end
	ok(type(s.boot) == "table" and s.boot.wuber == "table", "what was there when the file loaded")
	local cl = snapsOf(c2, "client", s)
	ok(#cl >= 1 and cl[1].d.same == nil and type(cl[1].d.api) == "table", "a whole client snapshot in the new session")
	recClean(w)
end)

rtest("a login after the hour does not start it (the switch read at load is too old)", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS)
	w:advance(10)
	c:slash("/rec on")
	w:advance(20)
	local saved = w:logout(c)
	eq(saved.WuberRec.on, true, "still on when the game closed")
	w:advance(3700)
	local c2 = recClient(w, ROCKS, { saved = saved })
	w:advance(5)
	ok(not Rec(c2).on, "not started")
	eq(DB(c2).on, false, "switched off")
	eq(#DB(c2).sessions, 1, "no new session")
	eq(#eventsOn(c2), 0, "no event registered")
	recClean(w)
end)

---------------------------------------------------------------------------
-- Privacy
---------------------------------------------------------------------------

local function spellings(name)
	local out = {}
	for _, v in ipairs({ name, (name:gsub(" ", "-")), (name:gsub(" ", "")) }) do
		out[#out + 1] = v
		out[#out + 1] = v:lower()
	end
	return out
end

rtest("other players' names become P-numbers in every event argument, snapshot and Wuber message", function()
	local w = T.newWorld()
	local d = T.driver(w, OTHER)
	local c = recClient(w, ROCKS)
	w:advance(15)
	c:slash("/rec on")
	w:advance(2)
	rideToArrived(w, d, c, H.key(OTHER))
	payFare(w, d, c)
	c:fire("PARTY_INVITE_REQUEST", OTHER, true, false, false, false, false, nil, false, false)
	c:fire("CHAT_MSG_WHISPER", "see you soon", OTHER, "", "", OTHER, "", 0, 0, "", 0, 77, "Player-1-0001")
	c:fire("CHAT_MSG_SYSTEM", c.env.ERR_DECLINE_GROUP_S:format(OTHER))
	c:fire("UNIT_SPELLCAST_SENT", "player", OTHER, "Cast-1", 698)
	c:fire("CHAT_MSG_ADDON", "WUBER", "X~" .. OTHER .. "~" .. H.key(OTHER), "WHISPER", OTHER .. "-Realm", ROCKS)
	c:slash("/rec snap")
	w:advance(3)
	local all = text(DB(c))
	for _, v in ipairs(spellings(OTHER)) do
		ok(not all:find(v, 1, true), "'" .. v .. "' is in the saved data")
	end
	ok(all:find('"P1"', 1, true), "a P-number")
	for _, part in ipairs({ "Bob", "Stone" }) do
		local at = all:find("%f[%a]" .. part .. "%f[%A]")
		ok(not at, "the name's part '" .. part .. "' is in the saved data: " .. (at and all:sub(math.max(1, at - 80), at + 40) or ""))
	end
	local s = sess(c)
	eq(s.char, ROCKS, "the author's character keeps its name")
	-- the name went to the same number everywhere
	local inv = eventsOf(c, "PARTY_INVITE_REQUEST")[1]
	local p = inv.a[1]
	ok(p:match("^P%d+$"), "invite: " .. tostring(p))
	eq(eventsOf(c, "CHAT_MSG_WHISPER")[1].a[2], p, "whisper sender")
	local sys = eventsOf(c, "CHAT_MSG_SYSTEM")
	local decl
	for _, e in ipairs(sys) do if type(e.a[1]) == "table" and e.a[1].gs == "ERR_DECLINE_GROUP_S" then decl = e.a[1] end end
	ok(decl and decl.a[1] == p, "system line's name")
	local x
	for _, e in ipairs(eventsOf(c, "CHAT_MSG_ADDON")) do if tostring(e.a[2]):sub(1, 2) == "X~" then x = e end end
	ok(x, "the test message is kept")
	eq(x.a[2], "X~" .. p .. "~" .. p, "the name inside a Wuber message, before its sender was seen in that row")
	local grp = snapsOf(c, "group")
	local named = false
	for _, g in ipairs(grp) do
		for _, u in ipairs(g.d.units or {}) do if u.name == p then named = true end end
	end
	ok(named, "the group snapshot names the driver by number")
	ok(next(s.shapes) ~= nil, "name shapes counted")
	recClean(w)
end)

rtest("a first name alone (the bird card says 'Bob summons to...') becomes the P-number too", function()
	local w = T.newWorld()
	local d = T.driver(w, OTHER, { spot = "Orgrimmar" })
	local c = recClient(w, ROCKS, { spot = "Thunder Bluff" })
	w:advance(15)
	c:slash("/rec on")
	T.goOnline(d)
	w:advance(20)
	w:openTaxiMap(c, { { name = "Thunder Bluff, Mulgore", type = "CURRENT", x = 0.46, y = 0.55 },
		{ name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50, x = 0.62, y = 0.27 } })
	w:advance(4)
	local card, second
	for _, r in ipairs(snapsOf(c, "wuber")) do
		if r.d.cards and r.d.cards.bird then card, second = r.d.cards.bird[1], r.d.cards.bird[2] end
	end
	ok(card, "the bird card's text was kept")
	-- the card's short lines: "Summon 30 sec. Fly about <time>." and "<short name> · <place> · <price>"
	ok(card:find("^Summon .* Fly "), "the first line: " .. tostring(card))
	ok(second and second:find("^P%d+ · Orgrimmar"), "the first name (second line) became the P-number: " .. tostring(second))
	local all = text(DB(c))
	ok(not all:find("%f[%a]Bob%f[%A]") and not all:find("%f[%a]Stone%f[%A]"), "no part of the name anywhere")
	ok(all:find("Orgrimmar", 1, true) and all:find("Fly about", 1, true), "the rest of the text is kept")
	recClean(w)
end)

rtest("the author's four characters keep their names (a driver who is one of them)", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA)
	local c = recClient(w, FARRA)
	w:advance(15)
	c:slash("/rec on")
	rideToArrived(w, d, c, H.key(ANITA))
	w:advance(2)
	local all = text(DB(c))
	ok(all:find(ANITA, 1, true), "Anita Lift is kept")
	ok(not all:find('"P%d+"'), "no P-number at all")
	eq(sess(c).char, FARRA)
	local senders = {}
	for _, e in ipairs(eventsOf(c, "CHAT_MSG_ADDON")) do senders[tostring(e.a[4])] = true end
	ok(senders[ANITA], "the sender of Wuber's messages: " .. list((function() local o = {} for k in pairs(senders) do o[#o + 1] = k end return o end)()))
	recClean(w)
end)

rtest("chat text is never stored (whisper, say, channel, party): only its length and whether it says wuber", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS)
	w:advance(10)
	c:slash("/rec on")
	w:advance(1)
	c:fire("CHAT_MSG_WHISPER", "purple elephant marmalade", OTHER, "", "", ROCKS, "", 0, 0, "", 0, 1, "Player-1-0002")
	c:fire("CHAT_MSG_WHISPER_INFORM", "teapot lighthouse", OTHER, "", "", ROCKS, "", 0, 0, "", 0, 2, "Player-1-0002")
	c:fire("CHAT_MSG_SAY", "zebra crossing words", OTHER, "Orcish", "", "", "", 0, 0, "", 1, 3, "Player-1-0002")
	c:fire("CHAT_MSG_CHANNEL", "[Wuber] quixotic banana summons", OTHER, "", "2. Trade - City", "", "", 2, 2, "Trade - City", 0, 4, "Player-1-0002")
	c:fire("CHAT_MSG_PARTY", "xylophone tune", OTHER, "", "", "", "", 0, 0, "", 0, 5, "Player-1-0002")
	c:fire("UI_ERROR_MESSAGE", 51, "Gravel aardvark is too far away")
	w:advance(1)
	local all = text(DB(c))
	for _, word in ipairs({ "elephant", "teapot", "zebra", "quixotic", "xylophone", "aardvark", "marmalade" }) do
		ok(not all:find(word, 1, true), word .. " is in the saved data")
	end
	local wh = eventsOf(c, "CHAT_MSG_WHISPER")[1]
	eq(wh.a[1].len, #"purple elephant marmalade", "length kept")
	eq(wh.a[1].w, false)
	local ch = eventsOf(c, "CHAT_MSG_CHANNEL")[1]
	eq(ch.a[1].w, true, "says wuber")
	eq(ch.a[4], "2. Trade - City", "the channel name is kept")
	eq(ch.a[12], "<->", "the GUID is not kept (the dropped marker)")
	eq(eventsOf(c, "UI_ERROR_MESSAGE")[1].a[2].len, #"Gravel aardvark is too far away", "an unknown game line: its length")
	recClean(w)
end)

-- the WUBER / WUBERT messages of a scene, in order (with or without the recorder)
local function scene(withRec)
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	local c = withRec and recClient(w, ROCKS) or T.rider(w, ROCKS)
	w:advance(15)
	if withRec then c:slash("/rec on") end
	T.goOnline(d)
	w:advance(30)
	c:fire("CHAT_MSG_ADDON", "BigWigs", "secret payload of another addon", "PARTY", OTHER, ROCKS)
	w:advance(1)
	local log = {}
	for _, e in ipairs(w.addonLog) do log[#log + 1] = tostring(e.from or e.sender) .. "|" .. tostring(e.prefix) .. "|" .. tostring(e.text) end
	return w, c, d, log
end

rtest("Wuber's addon messages (real D beacons) are stored whole; other addons' messages are not stored", function()
	local w, c, d, log = scene(true)
	local beacons = {}
	for _, e in ipairs(eventsOf(c, "CHAT_MSG_ADDON")) do
		ok(e.a[1] == "WUBER" or e.a[1] == "WUBERT", "only Wuber's prefixes: " .. tostring(e.a[1]))
		if tostring(e.a[2]):sub(1, 2) == "D~" and e.a[4] == ANITA then beacons[#beacons + 1] = e.a[2] end
	end
	ok(#beacons >= 1, "D beacons kept")
	local sent = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBER" and tostring(e.text):sub(1, 2) == "D~" then sent[e.text] = true end
	end
	for _, b in ipairs(beacons) do ok(sent[b], "kept whole, as sent: " .. b) end
	ok((sess(c).skip.CHAT_MSG_ADDON or 0) >= 1, "another addon's message only counted")
	ok(not text(DB(c)):find("secret payload", 1, true), "its text is not kept")
	recClean(w)
	-- the same scene without the recorder: Wuber said exactly the same
	local w2, _, _, log2 = scene(false)
	eq(list(log2, "\n"), list(log, "\n"), "the recorder changed nothing Wuber sent")
	recClean(w2)
end)

rtest("system lines: a game string Wuber knows is kept as its name and values (%s, %d, %1$s, %2$d), others as a length", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS)
	-- two game strings with numbers in them, as a client could word them (set before the first line is read)
	rawset(c.env, "ERR_TRADE_MAX_COUNT_EXCEEDED", "You can only carry %d of those.")
	rawset(c.env, "ERR_TRADE_TARGET_MAX_COUNT_EXCEEDED", "%1$s cannot carry more than %2$d of those.")
	w:advance(10)
	c:slash("/rec on")
	w:advance(1)
	c:fire("CHAT_MSG_SYSTEM", c.env.ERR_DECLINE_GROUP_S:format(OTHER))
	c:fire("CHAT_MSG_SYSTEM", "Trade complete.")
	c:fire("CHAT_MSG_SYSTEM", "You can only carry 12 of those.")
	c:fire("CHAT_MSG_SYSTEM", OTHER .. " cannot carry more than -3 of those.")
	c:fire("CHAT_MSG_SYSTEM", "The wind howls over the plains.")
	c:fire("UI_INFO_MESSAGE", 0, "Trade complete.")
	w:advance(1)
	local got = {}
	for _, e in ipairs(eventsOf(c, "CHAT_MSG_SYSTEM")) do got[#got + 1] = IMP.inline(e.a[1]) end
	local all = table.concat(got, "\n")
	ok(all:find('{ a = { "P1" }, gs = "ERR_DECLINE_GROUP_S" }', 1, true), "%s: " .. all)
	ok(all:find('{ gs = "ERR_TRADE_COMPLETE" }', 1, true), "no value")
	ok(all:find('{ a = { 12 }, gs = "ERR_TRADE_MAX_COUNT_EXCEEDED" }', 1, true), "%d")
	ok(all:find('{ a = { "P1", -3 }, gs = "ERR_TRADE_TARGET_MAX_COUNT_EXCEEDED" }', 1, true), "%1$s and %2$d")
	ok(all:find('{ len = ' .. #"The wind howls over the plains." .. ', w = false }', 1, true), "another line: its length")
	ok(not all:find("howls", 1, true), "not its words")
	eq(eventsOf(c, "UI_INFO_MESSAGE")[1].a[2].gs, "ERR_TRADE_COMPLETE", "UI_INFO_MESSAGE too")
	recClean(w)
end)

---------------------------------------------------------------------------
-- Limits
---------------------------------------------------------------------------

rtest("the rings: the oldest rows are overwritten, session.n counts all, session.lua unrolls them in order", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS)
	w:advance(10)
	local R = Rec(c)
	R.C.EVENTS, R.C.SNAPS = 5, 3
	c:slash("/rec on")
	w:advance(5)
	for i = 1, 12 do c:slash("/rec mark m" .. i) end
	local s = sess(c)
	ok(s.n >= 12, "n counts every row: " .. s.n)
	eq(#s.events, 5, "five kept")
	eq(s.caps.events, 5)
	local f = fx(s)
	eq(#f.events, 5)
	eq(f.dropped.events, s.n - 5, "dropped")
	local marks = {}
	for _, e in ipairs(f.events) do marks[#marks + 1] = e.e == "REC_MARK" and e.a[1] or e.e end
	eq(table.concat(marks, ","), "m8,m9,m10,m11,m12", "the newest five, oldest first")
	w:advance(5)
	ok(s.sn > 3, "snapshots counted: " .. s.sn)
	eq(#s.snaps, 3, "three snapshots kept")
	local fs = fx(s).snaps
	for i = 2, #fs do ok(fs[i].t >= fs[i - 1].t, "snapshots in time order") end
	recClean(w)
end)

rtest("the rate limit: a burst of 200 of one event keeps C.BURST rows, counts the rest, and the next row says the gap", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS)
	w:advance(10)
	c:slash("/rec on")
	w:advance(2)
	local R = Rec(c)
	for _ = 1, 200 do c:fire("BAG_UPDATE_DELAYED") end
	eq(#eventsOf(c, "BAG_UPDATE_DELAYED"), R.C.BURST, "rows kept")
	eq(sess(c).skip.BAG_UPDATE_DELAYED, 200 - R.C.BURST, "the rest counted")
	w:advance(1)
	c:fire("BAG_UPDATE_DELAYED")
	local rows = eventsOf(c, "BAG_UPDATE_DELAYED")
	eq(#rows, R.C.BURST + 1)
	eq(rows[#rows].gap, 200 - R.C.BURST, "the gap")
	eq(rows[1].gap, nil)
	recClean(w)
end)

rtest("the change-only sampler: an event's snapshot is remembered, so the ticker adds no copy; a change adds one row", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS)
	w:advance(10)
	c:slash("/rec on")
	w:advance(12)
	local R = Rec(c)
	local function wuberRows()
		local out = {}
		for _, r in ipairs(snapsOf(c, "wuber")) do out[#out + 1] = r end
		return out
	end
	local ticks = 0
	for _, r in ipairs(wuberRows()) do if r.why == "tick" then ticks = ticks + 1 end end
	eq(ticks, 0, "no tick row while nothing changed (the snapshots at /rec on were remembered)")
	if T.HAVE_UI then
		c.W.UI.Toggle(true)
		w:advance(6)
		local rows = wuberRows()
		local last = rows[#rows]
		eq(last.why, "tick", "the ticker saw Wuber open")
		eq(last.d.open, true)
		w:advance(5)
		eq(#wuberRows(), #rows, "and nothing more while it stays open")
	end
	-- every row the ticker kept differs from the row before it
	local prev
	for _, r in ipairs(wuberRows()) do
		local sig = R.SIG.wuber(r.d)
		if r.why == "tick" then ok(sig ~= prev, "a tick row that changed nothing at " .. r.t) end
		prev = sig
	end
	recClean(w)
end)

rtest("a frame without IsEventRegistered: the session lists no unknown events (nil, not every event)", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS)
	w:advance(10)
	local f = Rec(c).frame
	rawset(f, "IsEventRegistered", false)
	c:slash("/rec on")
	eq(sess(c).unknownEvents, nil, "nothing listed")
	ok(#eventsOn(c) > 50, "the events are still registered")
	c:slash("/rec off")
	rawset(f, "IsEventRegistered", nil)
	c:slash("/rec on")
	local u = sess(c).unknownEvents
	ok(type(u) == "table" and #u < 10, "with the method: the few this client lacks: " .. list(u or {}))
	c:slash("/rec off")
	recClean(w)
end)

rtest("nothing in combat: only the two PLAYER_REGEN rows, no snapshot, the rest counted; /rec on in combat refuses", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	local c = recClient(w, ROCKS)
	w:advance(15)
	T.goOnline(d)
	c:slash("/rec on")
	w:advance(5)
	local s = sess(c)
	local n0, sn0 = s.n, s.sn
	local t0 = w.time
	w:enterCombat(c)
	c:fire("ZONE_CHANGED")
	c:fire("GROUP_ROSTER_UPDATE")
	c:fire("TAXIMAP_OPENED", 1)
	c:slash("/rec snap")
	eq(said(c, "not in combat."), 1, "/rec snap refuses")
	w:advance(10)
	w:leaveCombat(c)
	local t1 = w.time
	local inside = {}
	for i = n0 + 1, s.n do inside[#inside + 1] = s.events[i][2] end
	eq(table.concat(inside, ","), "PLAYER_REGEN_DISABLED,PLAYER_REGEN_ENABLED", "rows in combat")
	for i = sn0 + 1, s.sn do
		local r = s.snaps[i]
		ok(r[1] + s.t0 < t0 - 0.001 or r[1] + s.t0 > t1 - 0.001, "a snapshot in combat: " .. tostring(r[2]))
	end
	ok((s.skip["event in combat"] or 0) >= 3, "events counted: " .. tostring(s.skip["event in combat"]))
	c:slash("/rec off")
	w:enterCombat(c)
	c:slash("/rec on")
	eq(said(c, "not started: not in combat"), 1, "refused")
	ok(not Rec(c).on, "still off")
	eq(DB(c).on, false)
	w:leaveCombat(c)
	recClean(w)
end)

rtest("secret values become <secret> and never raise (API returns and event arguments)", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS)
	w:advance(10)
	c:slash("/rec on")
	w:advance(5)
	c:secret("UnitName", "UnitClass", "C_Map", "GetMoney", "zone", "channels")
	local SECRET = H.SECRET
	c:fire("CHAT_MSG_WHISPER", SECRET, SECRET, "", "", SECRET, "", 0, 0, "", 0, SECRET, SECRET)
	c:fire("PARTY_INVITE_REQUEST", SECRET, SECRET)
	c:fire("CHAT_MSG_SYSTEM", SECRET)
	c:fire("CHAT_MSG_ADDON", "WUBER", SECRET, "WHISPER", SECRET, SECRET)
	c:fire("CHAT_MSG_ADDON", SECRET, "x", "WHISPER", OTHER)
	c:fire("UNIT_SPELLCAST_SENT", "player", SECRET, SECRET, SECRET)
	c:fire("CONFIRM_SUMMON", SECRET, SECRET)
	c:slash("/rec snap")
	w:advance(5)
	c:unsecret()
	local s = sess(c)
	eq(s.err, nil, "no error")
	eq(s.snapErr, nil, "no snapshot error")
	ok(Rec(c).on, "still on")
	eq(eventsOf(c, "CHAT_MSG_WHISPER")[1].a[1], "<secret>")
	eq(eventsOf(c, "CHAT_MSG_WHISPER")[1].a[2], "<secret>")
	eq(eventsOf(c, "PARTY_INVITE_REQUEST")[1].a[1], "<secret>")
	eq(eventsOf(c, "CHAT_MSG_SYSTEM")[#eventsOf(c, "CHAT_MSG_SYSTEM")].a[1], "<secret>")
	local wm
	for _, e in ipairs(eventsOf(c, "CHAT_MSG_ADDON")) do if e.a[2] == "<secret>" then wm = e end end
	ok(wm and wm.a[4] == "<secret>", "a Wuber message with secrets")
	eq(eventsOf(c, "CONFIRM_SUMMON")[1].a[1], "<secret>")
	local m = snapsOf(c, "map")
	ok(text(m[#m].d):find("<secret>", 1, true) or m[#m].d.map == nil, "the map snapshot with C_Map secret")
	recClean(w)
end)

---------------------------------------------------------------------------
-- Errors
---------------------------------------------------------------------------

rtest("the first error in its own code turns it off, is written down once, and /rec on refuses until a reload", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS)
	w:advance(10)
	c:slash("/rec on")
	w:advance(2)
	local R = Rec(c)
	R.FILTER.UNIT_SPELLCAST_SENT = function() error("test: a filter that breaks") end
	c:fire("UNIT_SPELLCAST_SENT", "player", OTHER, "Cast-1", 698)
	local db, s = DB(c), sess(c)
	ok(not R.on, "off")
	ok(R.IsDead(), "dead until a reload")
	eq(db.on, false)
	ok(type(db.lastError) == "table" and db.lastError.text:find("test: a filter that breaks", 1, true), "lastError")
	ok(type(s.err) == "table" and s.err.text:find("test: a filter that breaks", 1, true), "session.err")
	eq(s.stop, "error")
	eq(said(c, "stopped after an error"), 1, "said once")
	eq(#eventsOn(c), 0, "no event registered")
	local first, firstText = db.lastError, db.lastError.text
	c:fire("UNIT_SPELLCAST_SENT", "player", OTHER, "Cast-2", 698)
	R.Fail("again", "a second error")
	eq(db.lastError, first, "a second error adds nothing")
	eq(db.lastError.text, firstText)
	eq(s.err.text, firstText)
	c:slash("/rec on")
	ok(not R.on, "/rec on refuses")
	eq(said(c, "stopped after an error this session"), 1, "and says why")
	eq(#db.sessions, 1, "no new session")
	local c2 = w:reload(c)
	w:advance(3)
	c2:slash("/rec on")
	ok(Rec(c2).on, "on again after the reload")
	c2:slash("/rec off")
	recClean(w, { recError = true })
end)

rtest("an error inside one snapshot is kept in its row and switches off only that snapshot", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS)
	w:advance(10)
	local R = Rec(c)
	for _, row in ipairs(R.SNAPS) do
		if row[1] == "group" then row[4] = function() error("test: a snapshot that breaks") end end
	end
	c:slash("/rec on")
	w:advance(3)
	local s = sess(c)
	local g = snapsOf(c, "group")
	eq(#g, 1, "one group row")
	ok(g[1].err and g[1].err:find("test: a snapshot that breaks", 1, true), "its error: " .. tostring(g[1].err))
	ok(R.snapOff.group, "that snapshot is off")
	ok(s.snapErr and s.snapErr.group, "session.snapErr")
	eq(DB(c).lastError.snap, "group", "written down once")
	ok(R.on and not R.IsDead(), "the recorder goes on")
	c:slash("/rec snap")
	c:fire("GROUP_ROSTER_UPDATE")
	w:advance(2)
	eq(#snapsOf(c, "group"), 1, "not taken again")
	ok(#snapsOf(c, "map") >= 2, "the other snapshots go on")
	eq(s.err, nil, "no recorder error")
	recClean(w)
end)

rtest("ADDON_ACTION_BLOCKED / FORBIDDEN naming WuberRec turn it off; naming Wuber is only a row", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS)
	w:advance(10)
	c:slash("/rec on")
	w:advance(1)
	c:fire("ADDON_ACTION_BLOCKED", "Wuber", "Frame:Show()")
	ok(Rec(c).on, "still on")
	local b = eventsOf(c, "ADDON_ACTION_BLOCKED")
	eq(#b, 1)
	eq(b[1].a[1], "Wuber")
	eq(b[1].a[2], "Frame:Show()")
	c:fire("ADDON_ACTION_FORBIDDEN", "WuberRec", "UNKNOWN()")
	ok(not Rec(c).on, "off")
	ok(DB(c).lastError.text:find("blocked an action of this addon: UNKNOWN()", 1, true), DB(c).lastError.text)
	local f = DB(c).sessions[1].events
	eq(f[#f][2], "ADDON_ACTION_FORBIDDEN", "its row is the last")
	local c2 = recClient(w, ANITA, { class = "WARLOCK" })
	w:advance(5)
	c2:slash("/rec on")
	c2:fire("ADDON_ACTION_BLOCKED", "WuberRec", "Frame:SetPoint()")
	ok(not Rec(c2).on, "BLOCKED too")
	eq(DB(c2).sessions[1].stop, "error")
	recClean(w, { recError = true })
end)

---------------------------------------------------------------------------
-- The sample: a whole simulated session (the rider Wuber Rocks; the driver Anita Lift)
---------------------------------------------------------------------------

local NODES = {
	{ name = "Thunder Bluff, Mulgore", type = "CURRENT", cost = 0, x = 0.4612, y = 0.5521 },
	{ name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50, x = 0.6234, y = 0.2713 },
	{ name = "Crossroads, The Barrens", type = "REACHABLE", cost = 30, x = 0.5571, y = 0.4402 },
	{ name = "Ratchet, The Barrens", type = "REACHABLE", cost = 30, x = 0.6301, y = 0.4610 },
	{ name = "Sun Rock Retreat, Stonetalon Mountains", type = "NONE", cost = 0, x = 0.3712, y = 0.3920 },
}

-- Plays the ten minutes. Returns the world, the last rider window and the driver; WuberRecDB is the rider's.
local function playStory()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	local r = recClient(w, ROCKS, { spot = "Thunder Bluff" })
	w:advance(15)                         -- login, the channels come up
	r:slash("/rec on")
	local tOn = w.time
	w:advance(5)
	if T.HAVE_UI then r.W.UI.Toggle(true) end -- open Wuber
	w:advance(10)
	if T.HAVE_UI then r.W.UI.Toggle(false) end
	T.goOnline(d)                         -- the driver goes online in Orgrimmar
	w:advance(30)
	w:openTaxiMap(r, NODES)               -- the flight master: the bird card
	w:advance(5)
	w:closeTaxiMap(r)
	w:advance(5)
	r.W.RequestRide(H.key(ANITA))         -- books
	w:advance(5)                          -- invited (auto-accept)
	if not w:player(ROCKS).group then
		w.hardware = r
		r.W.AcceptInvite()
		w.hardware = nil
		w:advance(1)
	end
	w:advance(20.3)                       -- (off the whole second: the summon helper's trade then opens between two ticker snapshots, not on one)
	r = w:reload(r)                       -- a /reload in the middle
	w:advance(20)
	w:summon(d, ROCKS)
	w:advance(2)
	w.hardware = r
	r.W.AcceptSummon()                    -- summoned
	w.hardware = nil
	w:advance(10)                         -- arrives in Orgrimmar
	payFare(w, d, r)                      -- trades the fare
	w:advance(30)                         -- the ride ends (auto-leave)
	if w:player(ROCKS).group then
		w:leave(ROCKS)
		w:advance(5)
	end
	local left = tOn + 600 - w.time        -- ten minutes after /rec on
	if left > 0 then w:advance(left) end
	w:openMap(r, 1414)                    -- the world map, at Kalimdor
	w:advance(1)
	r:slash("/rec snap")
	w:advance(5)
	r.env.WorldMapFrame:Hide()
	r:slash("/rec off")
	return w, r, d
end

local story -- { db, w } once played in this run
local function getStory(W)
	if story then return story end
	local w, r = playStory()
	story = { db = DB(r), r = r, w = w }
	recClean(w)
	return story
end

local function dumpSim(db)
	mkdir(SIM_WTF .. "/Account/SIM/SavedVariables")
	local f = assert(io.open(SIM_FILE, "wb"))
	f:write(IMP.savedText("WuberRecDB", db))
	f:close()
end

rtest("sample: the ten-minute story records two sessions (before and after the /reload) without an error", function()
	local st = getStory()
	local db = st.db
	eq(#db.sessions, 2, "two sessions")
	eq(db.sessions[1].why, "on")
	eq(db.sessions[1].stop, "logout")
	eq(db.sessions[2].why, "boot")
	eq(db.sessions[2].stop, "off")
	eq(db.lastError, nil, "no error: " .. tostring(db.lastError and db.lastError.text))
	for _, s in ipairs(db.sessions) do
		eq(s.err, nil)
		eq(s.snapErr, nil, "no snapshot error")
		eq(s.char, ROCKS)
	end
	local seen = {}
	for _, s in ipairs(db.sessions) do for k in pairs(s.seen) do seen[k] = true end end
	for _, e in ipairs({ "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "PARTY_INVITE_REQUEST", "GROUP_JOINED", "CONFIRM_SUMMON", "TRADE_SHOW",
		"TRADE_CLOSED", "GROUP_LEFT", "CHAT_MSG_ADDON", "PLAYER_LOGOUT" }) do
		ok(seen[e], e .. " in the story")
	end
end)

rtest("sample: every snapshot row in R.SNAPS ran in the fake game without err", function()
	local st = getStory()
	local ids = {}
	for _, row in ipairs(Rec(st.r).SNAPS) do ids[#ids + 1] = row[1] end
	ok(#ids >= 12, "rows: " .. #ids)
	local taken = {}
	for _, s in ipairs(st.db.sessions) do
		for _, r in ipairs(fx(s).snaps) do
			taken[r.id] = (taken[r.id] or 0) + 1
			eq(r.err, nil, r.id .. ": " .. tostring(r.err))
		end
	end
	for _, id in ipairs(ids) do ok(taken[id], id .. " was taken") end
	local wm
	for _, r in ipairs(fx(st.db.sessions[2]).snaps) do
		if r.id == "map" and r.d.wm and r.d.wm.shown then wm = r.d.wm end
	end
	ok(wm and wm.mapID == 1414 and wm.scroll and wm.canvas, "the world map, open: " .. text(wm or {}))
	-- the group round a summon, taken by its own events (not only by /rec snap)
	local why = {}
	for _, s in ipairs(st.db.sessions) do
		for _, r in ipairs(fx(s).snaps) do why[r.id .. ":" .. tostring(r.why)] = true end
	end
	for _, k in ipairs({ "taxi:TAXIMAP_OPENED", "taxi_closed:TAXIMAP_CLOSED", "summon:CONFIRM_SUMMON", "trade:PLAYER_TRADE_MONEY",
		"screen:PLAYER_ENTERING_WORLD", "pos:tick", "wuber:tick" }) do
		ok(why[k], k)
	end
	-- the once-a-session snapshots sit beside the ring (a long session cannot overwrite them); /rec snap renews them
	for _, s in ipairs(st.db.sessions) do
		for _, id in ipairs({ "client", "atlas", "settings", "screen" }) do
			ok(type(s.once) == "table" and type(s.once[id]) == "table", id .. " kept beside the ring in session " .. tostring(s.id))
		end
	end
	ok(why["group:GROUP_ROSTER_UPDATE"] or why["group:GROUP_JOINED"] or why["group:PARTY_INVITE_REQUEST"], "group by a group event")
	ok(why["map:ZONE_CHANGED_NEW_AREA"] or why["map:ZONE_CHANGED"] or why["map:PLAYER_ENTERING_WORLD"], "map by a zone event")
end)

rtest("sample: the flight map snapshot holds every node and the map frame; the wuber snapshot after it shows the bird card", function()
	local st = getStory()
	local s = st.db.sessions[1]
	local taxi
	for _, r in ipairs(fx(s).snaps) do if r.id == "taxi" and r.why == "TAXIMAP_OPENED" and r.d.nodes then taxi = taxi or r end end
	ok(taxi, "a taxi snapshot with nodes")
	local d = taxi.d
	eq(d.n, #NODES)
	for i, node in ipairs(NODES) do
		local got = d.nodes[i]
		eq(got[1], node.name, "name " .. i)
		eq(got[2], node.type, "type " .. i)
		eq(got[3], node.cost, "cost " .. i)
		eq(got[4], node.x, "x " .. i)
		eq(got[5], node.y, "y " .. i)
	end
	local tf = d.frames.TaxiFrame
	ok(tf and tf.shown, "TaxiFrame shown")
	-- the frame as measured on the real client (lane B2: 603 x 638 at 16,-118 of UIParent)
	eq(tf.w, 603)
	eq(tf.h, 638)
	eq(tf.strata, "HIGH")
	ok(type(tf.lvl) == "number", "level")
	eq(IMP.inline(tf.p), '{ "TOPLEFT", "UIParent", "TOPLEFT", 16, -118 }', "position")
	eq(d.frames.FlightMapFrame, nil, "no FlightMapFrame in this client")
	ok(d.bird and d.bird.card and d.bird.card.shown, "the taxi snapshot sees the bird card")
	eq(d.bird.pick, true, "Wuber would pick a driver")
	eq(d.bird.driver, ANITA)
	local after
	for _, r in ipairs(fx(s).snaps) do
		if r.id == "wuber" and r.why == "TAXIMAP_OPENED" and r.t > taxi.t - 1 then after = after or r end
	end
	ok(after, "a wuber snapshot after the map opened")
	ok(after.d.cards.bird and #after.d.cards.bird >= 1, "it says the bird card shows: " .. text(after.d.cards))
	ok(after.d.cards.birdAt and after.d.cards.birdAt.shown, "and where")
end)

rtest("sample: tests/fixtures/rec/sim-*.lua are what a fresh run makes (WUBER_REC_WRITE=1 writes them)", function()
	local st = getStory()
	dumpSim(st.db)
	local done = assert(IMP.importFile(SIM_FILE, { source = "sim", out = FIXTURES, write = os.getenv("WUBER_REC_WRITE") == "1" }))
	eq(#done, 2, "two fixtures")
	local names = {}
	for _, it in ipairs(done) do
		names[#names + 1] = it.name
		ok(it.text, it.name .. " made")
		local disk = T.readFile(FIXTURES .. "/" .. it.name)
		ok(disk, FIXTURES .. "/" .. it.name .. " is missing: run this test with WUBER_REC_WRITE=1")
		ok(disk == it.text, it.name .. " is stale: run this test with WUBER_REC_WRITE=1 and review the difference")
		ok(not it.text:find("[ \t]\n"), "no trailing spaces")
		eq(it.pn, 0, "the story has no other players")
	end
	local onDisk = {}
	for _, p in ipairs(H.listFiles(FIXTURES, "lua")) do
		local n = p:match("([^/]+)$")
		if n:match("^sim%-") then onDisk[#onDisk + 1] = n end
	end
	table.sort(names)
	eq(table.concat(onDisk, ","), table.concat(names, ","), "no other sim fixture")
	-- a fixture reads back as the same table
	local back = assert(loadfile(FIXTURES .. "/" .. names[1]))()
	eq(IMP.serialize(back), T.readFile(FIXTURES .. "/" .. names[1]), "reads back equal")
end)

rtest("sample: staged WuberRec Data.lua matches tools/rec/gen-data.lua for this tree", function()
	local GEN = assert(loadfile(ROOT .. "/tools/rec/gen-data.lua"))("--lib")
	local fresh = assert(GEN.generate(ROOT))
	eq(T.readFile(H.ADDONS.WuberRec .. "/Data.lua"), fresh, "WuberRec Data.lua matches this tree's Wuber/")
end)

---------------------------------------------------------------------------
-- The independent review's findings (21 Nov): each one has its test
---------------------------------------------------------------------------

rtest("review M1: a /reload inside the hour never makes Wuber write a record for an unknown character", function()
	local w = T.newWorld()
	local c = recClient(w, ROCKS, { class = "MAGE" })
	w:advance(5)
	c:slash("/rec on")
	w:advance(5)
	local c2 = w:reload(c)
	w:advance(10)
	local wdb = c2.env.WuberDB
	ok(type(wdb) == "table" and type(wdb.chars) == "table", "Wuber's saved data is there")
	eq(wdb.chars["?"], nil, "no record for the character '?' (Wuber's functions are not asked before its login)")
	eq(sess(c2).why, "boot", "the reload carried on")
	local early, late = 0, 0
	for _, r in ipairs(snapsOf(c2, "wuber")) do
		if r.d.early then early = early + 1 else late = late + 1 end
	end
	ok(late >= 1, "the wuber snapshot was taken once Wuber was ready (" .. late .. " rows, " .. early .. " before)")
	recClean(w)
end)

rtest("review M2: a blocked action blamed on WuberRec stops it in combat too", function()
	local w = T.newWorld()
	local c = recClient(w)
	w:advance(5)
	c:slash("/rec on")
	w:advance(2)
	w:enterCombat(c)
	w:advance(1)
	c:fire("ADDON_ACTION_BLOCKED", "WuberRec", "UNKNOWN()")
	eq(Rec(c).IsDead(), true, "stopped at once, in combat")
	eq(DB(c).on, false, "the switch is off")
	ok(type(DB(c).lastError) == "table", "the error is written down")
	w:leaveCombat(c)
	recClean(w, { recError = true })
end)

rtest("review S1: the once-a-session snapshots survive a full snapshot ring", function()
	local w = T.newWorld()
	local c = recClient(w)
	w:advance(5)
	local R = Rec(c)
	R.C.SNAPS = 6
	c:slash("/rec on")
	w:advance(6)
	for i = 1, 40 do
		c:fire("ZONE_CHANGED")
		w:advance(1)
	end
	local s = sess(c)
	ok(s.sn > 6, "the ring went round (" .. s.sn .. " rows)")
	local got = {}
	for _, r in ipairs(snapsOf(c)) do got[r.id] = true end
	for _, id in ipairs({ "client", "atlas", "settings", "screen" }) do ok(got[id], id .. " is still in the converted session") end
	recClean(w)
end)

rtest("review S2: another player's cast is a row but takes no snapshot", function()
	local w = T.newWorld()
	local c = recClient(w)
	w:advance(5)
	c:slash("/rec on")
	w:advance(6)
	local before = sess(c).sn
	for i = 1, 5 do c:fire("UNIT_SPELLCAST_START", "party1", "Cast-3-x", 698) end
	w:advance(0.5)
	local casts = 0
	for _, r in ipairs(snapsOf(c, "cast")) do casts = casts + 1 end
	eq(casts, 0, "no cast snapshot for party1")
	eq(#eventsOf(c, "UNIT_SPELLCAST_START"), 5, "the rows are kept")
	c:fire("UNIT_SPELLCAST_START", "player", "Cast-3-y", 698)
	w:advance(0.5)
	eq(#snapsOf(c, "cast"), 1, "the player's own cast takes one")
	recClean(w)
end)

rtest("review S4: a sender spelled with a realm tail is the same player, and is scrubbed from Wuber messages", function()
	local w = T.newWorld()
	local c = recClient(w)
	w:advance(5)
	c:slash("/rec on")
	w:advance(2)
	local R = Rec(c)
	local a1 = R.Alias("Bea Quill-SomeRealm")
	local a2 = R.Alias("Bea Quill")
	eq(a1, a2, "one player, one number")
	ok(a1:match("^P%d+$"), "a P-number: " .. tostring(a1))
	eq(R.Scrub("X~1~bea quill~Bea Quill~Bea-Quill"), "X~1~" .. a1 .. "~" .. a1 .. "~" .. a1, "every spelling inside a message")
	eq(R.Scrub("D~1~open~star"), "D~1~open~star", "a message's own words are never touched")
	eq(R.Alias("Anita Lift-SomeRealm"), "Anita Lift-SomeRealm", "the author's characters keep their names as given")
	recClean(w)
end)
