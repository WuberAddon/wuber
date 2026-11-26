-- Round 28, group N (REC-01 part 1): /wuber why, and the Why lines of the login tip card (UI.Tips),
-- Skip the bird (UI.Bird), the first-open guide (UI.Coach) and the update notice (Net.Update).
-- For each rule: the world in that state, the surface really not shown, and the line naming that rule.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local WHY = {
	{ "UI.Tips", "Why" }, { "UI.Bird", "Why" }, { "UI.Driver.Customers", "WhyInvite" }, { "UI.Rider.Home", "WhyUsual" },
	{ "UI.Rider.Home", "WhyBounty" }, { "UI.Coach", "Why" }, { "Net.Update", "Why" }, { "UI.Moments", "WhyMilestone" },
	{ "UI.WhatsNew", "Why" },
}

-- every surface says nil, except the ones in over (name .. "." .. fn = function)
local function stubAll(W, over)
	for _, e in ipairs(WHY) do
		local m = W.Mod(e[1])
		m[e[2]] = over[e[1] .. "." .. e[2]] or function() return nil end
	end
end

-- the chat lines printed since mark
local function printed(c, mark)
	local out = {}
	for i = mark + 1, #c.chatLines do out[#out + 1] = tostring(c.chatLines[i]) end
	return out
end
local function has(lines, text)
	for _, l in ipairs(lines) do if l:find(text, 1, true) then return true end end
	return false
end
local function index(lines, text)
	for i, l in ipairs(lines) do if l:find(text, 1, true) then return i end end
	return nil
end

local function rider(w, saved, opts)
	opts = opts or {}
	local c = T.rider(w, T.TESTCHAR, { saved = saved or { Wuber = { coach = true } }, version = opts.version,
		screenW = opts.screenW, screenH = opts.screenH })
	w:advance(2)
	return c, c.W
end

---------------------------------------------------------------------------
-- The command
---------------------------------------------------------------------------

test("r28 REC-01: /wuber why with nothing hidden says Nothing is hidden right now.", function()
	local w = T.newWorld()
	local c, W = rider(w)
	stubAll(W, {})
	local mark = #c.chatLines
	W.SlashCommand("why")
	local lines = printed(c, mark)
	eq(#lines, 1, "one line: " .. table.concat(lines, " / "))
	ok(has(lines, "Nothing is hidden right now."), "the nothing line")
	T.clean(w)
end)

test("r28 REC-01: /wuber why lists each hidden thing under the top line, in the list's order", function()
	local w = T.newWorld()
	local c, W = rider(w)
	stubAll(W, {
		["Net.Update.Why"] = function() return "Update notice: not in combat." end,
		["UI.Tips.Why"] = function() return "Login tip: not in combat." end,
		["UI.Bird.Why"] = function() return "Skip the bird: no flight map is open." end,
	})
	local mark = #c.chatLines
	W.SlashCommand("why")
	local lines = printed(c, mark)
	eq(#lines, 4, "top line and three: " .. table.concat(lines, " / "))
	ok(lines[1]:find("Hidden right now, and why:", 1, true), "the top line first")
	ok(index(lines, "Login tip") == 2 and index(lines, "Skip the bird") == 3 and index(lines, "Update notice") == 4,
		"in the list's order: " .. table.concat(lines, " / "))
	T.clean(w)
end)

test("r28 REC-01: a surface whose Why throws is skipped and the others still print", function()
	local w = T.newWorld()
	local c, W = rider(w)
	stubAll(W, {
		["UI.Tips.Why"] = function() error("boom") end,
		["UI.Coach.Why"] = function() return "First-open guide: not during a ride." end,
	})
	local mark = #c.chatLines
	W.SlashCommand("why")
	local lines = printed(c, mark)
	eq(#lines, 2, "top line and one: " .. table.concat(lines, " / "))
	ok(has(lines, "First-open guide: not during a ride."), "the coach line prints")
	ok(not has(lines, "boom"), "the error is not printed")
	T.clean(w)
end)

test("r28 REC-01: surfaces with no Why function (group O's, absent) are skipped silently", function()
	local w = T.newWorld()
	local c, W = rider(w)
	stubAll(W, { ["UI.Bird.Why"] = function() return "Skip the bird: no flight map is open." end })
	W.Mod("UI.Driver.Customers").WhyInvite = nil
	W.Mod("UI.Rider.Home").WhyUsual = nil
	W.Mod("UI.Rider.Home").WhyBounty = 42 -- not a function
	W.Mod("UI.Moments").WhyMilestone = nil
	local mark = #c.chatLines
	W.SlashCommand("why")
	local lines = printed(c, mark)
	eq(#lines, 2, "top line and one: " .. table.concat(lines, " / "))
	ok(has(lines, "Skip the bird: no flight map is open."), "the bird line")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- UI.Tips.Why: the login tip card
---------------------------------------------------------------------------

local function tipUp(W)
	local card = W.Mod("UI.Tips").Card()
	return card and H.visible(card) and W.Mod("UI.Tips").state.current ~= nil
end
local function open(w, W) W.UI.Toggle(true) w:advance(5) end

test("r28 REC-01: the login tip shows and Why says nothing; closed, it says already shown this login", function()
	local w = T.newWorld()
	local c, W = rider(w)
	local Tips = W.Mod("UI.Tips")
	eq(Tips.Why(), "Login tip: it shows on the Ride tab's first screen.", "before the first open (the phone shut)")
	open(w, W)
	ok(tipUp(W), "control: the tip shows on the first open")
	eq(Tips.Why(), nil, "showing: nothing to say")
	Tips.Card().close:Click()
	w:advance(1)
	ok(not tipUp(W), "closed")
	eq(Tips.Why(), "Login tip: already shown this login. /wuber tips shows it again.", "the line")
	T.clean(w)
end)

test("r28 REC-01: login tips off: no card, Why names the Login tips switch", function()
	local w = T.newWorld()
	local c, W = rider(w, { Wuber = { coach = true, tipsOn = false } })
	open(w, W)
	ok(not tipUp(W), "no tip card")
	eq(W.Mod("UI.Tips").Why(), "Login tip: off in Settings (Riding, Tips).", "the line")
	T.clean(w)
end)

test("r28 REC-01: first-open guide not yet run: no tip card, Why says it waits for the guide", function()
	local w = T.newWorld()
	local c, W = rider(w, { Wuber = {} })
	open(w, W)
	ok(not tipUp(W), "no tip card")
	eq(W.Mod("UI.Tips").Why(), "Login tip: waits until the first-open guide has run.", "the line")
	T.clean(w)
end)

test("r28 REC-01: in combat the login tip waits and Why says not in combat", function()
	local w = T.newWorld()
	local c, W = rider(w)
	w:enterCombat(c)
	open(w, W)
	ok(not tipUp(W), "no tip card in combat")
	eq(W.Mod("UI.Tips").Why(), "Login tip: not in combat.", "the line")
	T.clean(w)
end)

test("r28 REC-01: during a ride the login tip waits and Why says not during a ride", function()
	local w = T.newWorld()
	local c, W = rider(w)
	W.ride = { id = "b1", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = "accepted", at = c.env.GetTime() }
	open(w, W)
	ok(not tipUp(W), "no tip card during a ride")
	eq(W.Mod("UI.Tips").Why(), "Login tip: not during a ride.", "the line")
	T.clean(w)
end)

test("r28 REC-01: every tip seen: no card, Why says you have seen every tip", function()
	local w = T.newWorld()
	local c, W = rider(w)
	local Tips = W.Mod("UI.Tips")
	W.db.tipsSeen = {}
	for _, tip in ipairs(Tips.Eligible()) do W.db.tipsSeen[tip.id] = true end
	ok(#Tips.Eligible() > 0, "control: there are tips")
	open(w, W)
	ok(not tipUp(W), "no tip card")
	eq(Tips.Why(), "Login tip: you have seen every tip.", "the line")
	T.clean(w)
end)

test("r28 REC-01: the tip's Why writes no saved data (tipsSeen stays missing)", function()
	local w = T.newWorld()
	local c, W = rider(w)
	W.db.tipsSeen = nil
	W.Mod("UI.Tips").Why()
	eq(W.db.tipsSeen, nil, "nothing written")
	T.clean(w)
end)

-- What it does today (reported, not changed): ShowNow only refuses while the guide is on screen, so
-- with the phone shut it opens the phone, shows a tip, and the guide starts over it as well.
test("r28 REC-01: Help's Show a tip before the first-open guide has run shows a tip; the guide waits (r32 REV-r28-2)", function()
	local w = T.newWorld()
	local c, W = rider(w, { Wuber = {} })
	local mark = #c.chatLines
	local shown, why = W.Mod("UI.Settings.Panel").showTip()
	w:advance(2)
	eq(shown, true, "Show a tip says it showed")
	eq(why, nil, "no reason given")
	ok(tipUp(W), "the tip card shows")
	ok(W.UI.state.coaching ~= true, "the first-open guide waits while the tip card shows")
	eq(#printed(c, mark), 0, "nothing in chat")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- UI.Bird.Why: Skip the bird
---------------------------------------------------------------------------

local NODES = { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 580, x = 0.47, y = 0.44 } }

local function bird()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Tarren Mill", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime() }
	W.FlightCost = function() return 2300, 1 end
	W.FlightTime = function() return 540, "est" end
	return w, r, W, W.Mod("UI.Bird")
end
local function birdUp(Mod) return Mod.Card() and H.visible(Mod.Card()) end
local function openMap(w, r) w:openTaxiMap(r, NODES) w:advance(0.5) end

test("r28 REC-01: Skip the bird shows and Why says nothing; closed, already shown for this flight map", function()
	local w, r, W, Mod = bird()
	eq(Mod.Why(), "Skip the bird: no flight map is open.", "no map yet")
	openMap(w, r)
	ok(birdUp(Mod), "control: the card shows")
	eq(Mod.Why(), nil, "showing: nothing to say")
	Mod.Card().x:Click()
	w:advance(0.5)
	ok(not birdUp(Mod), "closed")
	eq(Mod.Why(), "Skip the bird: already shown for this flight map.", "the line")
	T.clean(w)
end)

test("r28 REC-01: Skip the bird off in Settings, in combat, during a ride: no card, Why names each", function()
	local w, r, W, Mod = bird()
	W.db.birdTip = false
	openMap(w, r)
	ok(not birdUp(Mod), "off: no card")
	eq(Mod.Why(), "Skip the bird: off in Settings (Riding, Flight offers).", "off")
	w:closeTaxiMap(r)
	W.db.birdTip = nil
	r.player.combat = true
	openMap(w, r)
	ok(not birdUp(Mod), "combat: no card")
	eq(Mod.Why(), "Skip the bird: not in combat.", "combat")
	w:closeTaxiMap(r)
	r.player.combat = false
	W.ride = { id = "b1", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = "accepted", at = r.env.GetTime() }
	openMap(w, r)
	ok(not birdUp(Mod), "ride: no card")
	eq(Mod.Why(), "Skip the bird: your ride is waiting for its summon.", "ride")
	T.clean(w)
end)

test("r28 REC-01: Skip the bird with no open driver, an unknown flight, a short flight: no card, Why names each", function()
	local w, r, W, Mod = bird()
	W.drivers["mia runner"].state = "paused"
	openMap(w, r)
	ok(not birdUp(Mod), "nobody open: no card")
	eq(Mod.Why(), "Skip the bird: no driver is open.", "nobody open")
	w:closeTaxiMap(r)
	W.drivers["mia runner"].state = "open"
	W.FlightCost = function() return nil end
	openMap(w, r)
	ok(not birdUp(Mod), "unknown flight: no card")
	eq(Mod.Why(), "Skip the bird: Wuber does not know the flight from here to Tarren Mill yet.", "unknown")
	w:closeTaxiMap(r)
	W.FlightCost = function() return 2300, 1 end
	W.FlightTime = function() return 80, "own" end
	openMap(w, r)
	ok(not birdUp(Mod), "80 s flight (50 s back): no card")
	eq(Mod.Why(), "Skip the bird: the flight to Tarren Mill is about 1 min, so a summon gives under a minute back.", "short")
	w:closeTaxiMap(r)
	W.FlightTime = function() return 25, "own" end
	openMap(w, r)
	ok(not birdUp(Mod), "25 s flight: no card")
	eq(Mod.Why(), "Skip the bird: the flight to Tarren Mill is under a minute, shorter than a summon's wait.", "shorter than the wait")
	T.clean(w)
end)

test("r28 REC-01: Skip the bird with no room beside the map: no card, Why says no room", function()
	local w, r, W, Mod = bird()
	Mod.Place = function() return false end
	openMap(w, r)
	ok(not birdUp(Mod), "no room: no card")
	eq(Mod.Why(), "Skip the bird: no room beside the flight map.", "the line")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- UI.Coach.Why: the first-open guide
---------------------------------------------------------------------------

test("r28 REC-01: the first-open guide: shut phone, showing, Settings on top, done", function()
	local w = T.newWorld()
	local c, W = rider(w, { Wuber = {} })
	local Coach = W.Mod("UI.Coach")
	local ui = W.UI.state
	eq(Coach.Why(), "First-open guide: it shows when you open Wuber.", "the phone shut")
	open(w, W)
	ok(ui.coaching and ui.coach and H.visible(ui.coach), "control: the guide shows")
	eq(Coach.Why(), nil, "showing: nothing to say")
	W.UI.Show("settings")
	w:advance(1)
	ok(not (ui.coach and H.visible(ui.coach)), "Settings on top: the guide is not shown")
	eq(Coach.Why(), "First-open guide: it shows on the Ride tab's first screen.", "the line")
	W.UI.EndCoach()
	eq(Coach.Why(), nil, "done: nothing to say")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Net.Update.Why: the update notice
---------------------------------------------------------------------------

local function upd(saved)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { saved = saved, version = "2.3.0" })
	T.settle(w)
	return w, r, r.W, r.W.Mod("Net.Update")
end
local NEWER = function() return { Wuber = { coach = true, newer = { ver = "2.3.1", at = H.EPOCH } } } end

test("r28 REC-01: update notice: nothing known says nothing; known and shown says already shown", function()
	local w, r, W, Mod = upd({ Wuber = { coach = true } })
	eq(Mod.Why(), nil, "no newer version known")
	local w2, r2, W2, Mod2 = upd(NEWER())
	w2:advance(30)
	ok(Mod2.shown(), "control: the notice showed")
	eq(Mod2.Why(), "Update notice: already shown this session (Wuber 2.3.1 is out).", "the line")
	T.clean(w)
	T.clean(w2)
end)

test("r28 REC-01: update notice off, in combat, while summoning: not shown, Why names each", function()
	local saved = NEWER()
	saved.Wuber.updateNotes = false
	local w, r, W, Mod = upd(saved)
	w:advance(30)
	ok(not Mod.shown(), "off: not shown")
	eq(Mod.Why(), "Update notice: off (type /wuber updates on).", "off")
	T.clean(w)
	local w2, r2, W2, Mod2 = upd(NEWER())
	w2:enterCombat(r2)
	w2:advance(30)
	ok(not Mod2.shown(), "combat: not shown")
	eq(Mod2.Why(), "Update notice: not in combat.", "combat")
	w2:leaveCombat(r2)
	local DR = W2.Drive
	DR.Busy = function() return true end
	eq(Mod2.Why(), "Update notice: not while you are summoning.", "summoning")
	w2:advance(30)
	ok(not Mod2.shown(), "summoning: not shown")
	T.clean(w2)
end)
