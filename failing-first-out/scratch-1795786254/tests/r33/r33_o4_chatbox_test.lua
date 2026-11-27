-- Round 33 o4: AUD-101 (chat-box mode: a rider asked for by a Warlock without Wuber still gets the greeting in the chat box) and AUD-102 (a paid rider is removed 60 s after paying even after a /reload).
local T = ...
do
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local MIA, BEA, PAT = "Mia Stone", "Bea Jones", "Pat Wood"
local SPOT = "Undercity"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function saved(me, names, extra, roles, apps)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = (roles and roles[n]) or "lock", app = not (apps and apps[n] == false) } end
	end
	local ch = { crew = crew, captain = "", wizard = true }
	for k, v in pairs(extra or {}) do ch[k] = v end
	return { chars = { [key(me)] = ch } }
end

-- A Mage runner; Bea is a Warlock friend without Wuber (so the runner asks her in party chat to summon Dan)
local function setup(boxMode)
	local w = T.newWorld()
	local mia = w:addClient(MIA, { spot = SPOT, class = "MAGE",
		saved = { Wuber = saved(MIA, { MIA, BEA }, { runner = true, summoners = { BEA } }, { [BEA] = "lock" }, { [BEA] = false }) } })
	w:addBot(BEA, { spot = SPOT, class = "WARLOCK", shards = 10 })
	w:addBot(PAT, { spot = SPOT, class = "PRIEST" })
	w:group({ MIA, BEA, PAT })
	w:advance(2)
	local DR = mia.W.Drive
	if boxMode then DR.opts().whisperMode = "box" end
	local okOpen, why = DR.SetOpen(true)
	ok(okOpen, "the Mage opens: " .. tostring(why))
	w:advance(2)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:botWhisper("Dan Miller", mia, "summon pls")
	w:advance(4)
	eq(DR.customers["dan miller"].state, "joined")
	return w, mia, DR
end

local function press(c)
	local b = c.env.WuberDriveButton
	ok(b and H.visible(b), "the big button is hidden")
	return c:click(b)
end

test("r33 o4 AUD-101: control, whispers on (macro): the call line goes with Dan's greeting", function()
	local w, mia, DR = setup(false)
	local p = DR.Plan()
	ok(p.macrotext:find("/p Bea: please summon Dan", 1, true), "the call line: " .. tostring(p.macrotext))
	press(mia)
	w:advance(1)
	ok(#w:whispersTo("Dan Miller") >= 1, "Dan got the greeting whisper")
	T.clean(w)
end)

test("r33 o4 AUD-101: whispers by chat box: Dan, summoned by a Warlock without Wuber, still gets his greeting", function()
	local w, mia, DR = setup(true)
	eq(DR.ChatMode(), "box")
	local p = DR.Plan()
	ok(p.macrotext and p.macrotext:find("/p Bea: please summon Dan", 1, true), "setup: the click asks Bea in party chat: " .. tostring(p.macrotext))
	local boxFor = p.box and p.box.kind
	press(mia)
	w:advance(1)
	local waiting = mia.chatBox and mia.chatBox:find("/w Dan", 1, true)
	local sent = #w:whispersTo("Dan Miller")
	ok(waiting or sent >= 1 or boxFor == "greet",
		"the click asked Bea but Dan's greeting was never put in the chat box and never sent (box: " .. tostring(boxFor) .. ", chat box: " .. tostring(mia.chatBox) .. ", whispers to Dan: " .. sent .. "); Dan is summoned with no word from the driver")
	-- and it does not come later either: Bea casts, Dan is summoned
	w:botCast(BEA, "Dan Miller")
	w:advance(2)
	ok(DR.customers["dan miller"].greeted or (mia.chatBox and mia.chatBox:find("/w Dan", 1, true)) or #w:whispersTo("Dan Miller") >= 1,
		"even after Bea's summon, Dan was never greeted")
	T.clean(w)
end)

end
do
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local count = T.count
local newWorld, clean = T.newWorld, T.clean
local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local SPOT = "Undercity"
local FARE = 5000

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- WuberDB with this character's crew agreed (as the wizard or the import leaves it)
local function crewSaved(me, names, captain, extra, roles)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = (roles and roles[n]) or "lock", app = true } end
	end
	local ch = { crew = crew, captain = (me == captain) and "" or captain, wizard = true }
	for k, v in pairs(extra or {}) do ch[k] = v end
	return { chars = { [key(me)] = ch } }
end

-- Three Warlocks (Ana leads and is the captain), the crew agreed, grouped, open.
local function team(opts)
	opts = opts or {}
	local w = H.NewWorld({ restricted = opts.restricted, senderFormat = opts.senderFormat })
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, n in ipairs(names) do
		local saved = opts.named ~= false and { Wuber = crewSaved(n, names, ANA) } or nil
		cs[i] = w:addClient(n, { spot = opts.spot or SPOT, class = "WARLOCK", shards = (i == 1 and opts.anaShards) or nil,
			prepare = opts.prepare, saved = saved })
	end
	w:group(names)
	w:advance(1)
	if opts.open ~= false then cs[1].W.Drive.SetOpen(true) end
	w:advance(2)
	return w, cs[1], cs[2], cs[3]
end

local function DRof(c) return c.W.Drive end
local function customer(c, name) return c.W.Drive.customers[key(name)] end
local function state(c, name)
	local x = customer(c, name)
	return x and x.state or nil
end
local function plan(c) return c.W.Drive.Plan() end
local function nCustomers(c) return count(c.W.Drive.customers) end

-- One click on the big button (WuberDriveButton) where it is drawn.
local function press(c)
	local b = c.env.WuberDriveButton
	ok(b, c.player.name .. ": no WuberDriveButton")
	ok(H.visible(b), c.player.name .. ": the big button is hidden")
	return c:click(b)
end

-- A bot whispers a request (and joins the group the invite brings).
local function ask(w, to, name, opts)
	if not w:player(name) then w:addBot(name, opts) end
	w:botWhisper(name, to, (opts and opts.text) or "summon pls")
	w:advance(3)
end

local function whisperFrom(w, to, name, text)
	if not w:player(name) then w:addBot(name) end
	w:botWhisper(name, to, text)
end

-- a whisper from a name the world doesn't know (no such player online)
local function ghostWhisper(to, name, text)
	to:chatEvent("CHAT_MSG_WHISPER", text, name, "", "", name, "", 0, 0, "", 0, 0, "")
end

-- how often W.Fire(name) happened on a window (and the last one's args)
local function fired(c, name)
	local n, last = 0, nil
	for _, f in ipairs(c.fired) do
		if f.name == name then n, last = n + 1, f.args end
	end
	return n, last
end

-- One click on the caster, a human's pause, then the other two click the portal.
local function summon(w, caster, helper1, helper2)
	press(caster)
	w:advance(3)
	ok(w:clickPortal(helper1), "the first helper clicks the portal")
	ok(w:clickPortal(helper2), "the second helper clicks the portal")
	w:advance(1.5)
end

-- The rider takes the summon, lands, and the caster's trade window opens.
local function land(w) w:advance(8) end

-- The rider types the fare into the trade and accepts (the addon never puts gold in).
local function pays(w, name, copper)
	local p = w:player(name)
	ok(p.trade, name .. " has no trade open")
	w:typeTradeMoney(p, math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100)
	w:tradeAccept(p)
	w:advance(0.3)
end


-- A paid rider (Dan) in the leader's group; whispers go through the chat box (the leader's setting)
local function paidRider(box)
	local w, ana, bea, cal = team()
	if box then DRof(ana).opts().whisperMode = "box" end
	ask(w, ana, "Dan Miller")
	summon(w, ana, bea, cal)
	land(w)
	pays(w, "Dan Miller", FARE)
	press(ana)
	w:advance(1.5)
	eq(state(ana, "Dan Miller"), "paid")
	return w, ana
end

local function kicks(ana) return (plan(ana).macrotext or ""):find("/uninvite Dan Miller", 1, true) ~= nil end

test("r33 o4 AUD-102: control, a paid rider who is still in the group after 60 s is removed (no reload)", function()
	local w, ana = paidRider(true)
	w:advance(90)
	ok(kicks(ana), "after 90 s the big button removes Dan: " .. tostring(plan(ana).macrotext))
	clean(w)
end)

test("r33 o4 AUD-102: after a /reload, a paid rider still in the group is removed after 60 s too", function()
	local w, ana = paidRider(true)
	ana = w:reload(ana)
	w:advance(3)
	eq(state(ana, "Dan Miller"), "paid", "setup: Dan is still paid after the reload")
	w:advance(90)
	ok(kicks(ana), "90 s after the reload Dan, who paid long ago, is still in the group and the button never offers to remove him: " .. tostring(plan(ana).macrotext) .. " (title: " .. tostring(plan(ana).title) .. ")")
	clean(w)
end)

end
