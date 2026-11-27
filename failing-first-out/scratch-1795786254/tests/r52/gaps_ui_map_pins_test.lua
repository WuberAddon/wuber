-- Final home: tests/ui/map/pins_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: the contract (Mod.* names); CanvasMetrics (size, scale, bad canvas -> nil); Place (1 / canvas scale, chosen 1.25, hover 1.15, creator 1.3, offsets); SetLevels (stack order).
-- Pins: Paint for open / busy / paused (aura ring, pulse), chosen (halo, price tag), creator (gold ring, sparkle, crown, and Stop on repaint), rank 1000 gold boundary.
-- Pins: Aura ring (size fallback, Start / Stop / host hide, gold); a real pin of an online driver: hover scale, tooltip lines, favourite heart, click opens Confirm, paused pin does nothing.
-- Why it matters to a player: the pins are how a rider sees which drivers are open, cheap, favourite or the founder, and clicking one is how they request a ride.
-- If this broke they would see wrong sizes at other zoom levels, a paused driver that looks bookable, missing price tags, or clicks that do nothing (or open the wrong driver).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function near(a, b, what)
	ok(type(a) == "number" and math.abs(a - b) < 1e-6, (what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

-- a lone rider and a stand-in canvas under UIParent (never under the world map: no map-taint rule applies)
local function standalone()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local W = r.W
	local Mod = W.Mod("UI.Map.Pins")
	local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	parent:SetSize(1000, 600)
	return w, r, W, Mod, parent
end

-- a driver as Paint reads it (the fields of a W.drivers entry)
local function entry(over)
	local d = { key = "zed", name = "Zed", service = "Zed Rides", state = "open", price = 5000, dest = "Ratchet", team = 1, seats = 4 }
	for k, v in pairs(over or {}) do d[k] = v end
	return d
end

-- Bob drives (online), Wuber rides with the map open on Bob: pins[1] is Bob's (tests/dec/dec_j_maptaint_test.lua's setup)
local function bobMap()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	ok(r.W.Map.ShowDriver("bob stone"), "the map opens on Bob")
	w:advance(1)
	local pin = r.W.Mod("UI.Map.Base").pins[1]
	ok(pin and pin:IsShown(), "Bob's pin is drawn")
	return w, r, pin
end

local function windowShown(r)
	local f = r.env.WuberFrame
	return f ~= nil and f:IsShown() == true
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.pins: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Map.Pins", "tests/ui/map/pins_test.lua", {
		["Mod.AURA"] = "table",
		["Mod.Aura"] = "function",
		["Mod.CanvasMetrics"] = "function",
		["Mod.NewPin"] = "function",
		["Mod.Paint"] = "function",
		["Mod.Place"] = "function",
		["Mod.SetLevels"] = "function",
		["Mod.StopCreator"] = "function",
		["Mod.StopPulse"] = "function",
		["Mod.Tooltip"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Map.Pins\")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.pins: CanvasMetrics gives width, height and scale; a canvas with no size, or none at all, gives nothing; a bad scale counts as 1", function()
	local w, r, W, Mod, parent = standalone()
	parent:SetSize(1000, 500)
	parent:SetScale(2)
	local cw, ch, cs = Mod.CanvasMetrics(parent)
	eq(cw, 1000, "width")
	eq(ch, 500, "height")
	eq(cs, 2, "scale")
	local function plain(width, height, scale)
		return { GetWidth = function() return width end, GetHeight = function() return height end, GetScale = function() return scale end }
	end
	local pw, ph, ps = Mod.CanvasMetrics(plain(800, 400, -3))
	eq(pw, 800, "plain canvas width")
	eq(ps, 1, "a scale below zero counts as 1") -- Pins.lua CanvasMetrics
	eq(Mod.CanvasMetrics(plain(0, 400, 1)), nil, "no width: nothing")
	eq(Mod.CanvasMetrics(plain(800, 0, 1)), nil, "no height: nothing")
	eq(Mod.CanvasMetrics(nil), nil, "no canvas: nothing")
	eq(Mod.CanvasMetrics({}), nil, "a canvas that cannot say its size: nothing")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.pins: Place keeps a pin the same size on screen at any zoom, and grows chosen, hovered and founder pins", function()
	local w, r, W, Mod, parent = standalone()
	local pin = Mod.NewPin(parent)
	pin.nx, pin.ny = 0.5, 0.25
	Mod.Place(pin, parent, 1000, 600, 2)
	near(pin:GetScale(), 0.5, "scale 1 / canvas scale") -- Pins.lua Place
	local point, rel, relPoint, x, y = pin:GetPoint(1)
	eq(point, "CENTER", "centred on its spot")
	eq(rel, parent, "relative to the canvas")
	eq(relPoint, "TOPLEFT", "from the top left")
	near(x, 0.5 * 1000 / 0.5, "x in the pin's own scaled units")
	near(y, -0.25 * 600 / 0.5, "y goes down")
	pin.chosen = true
	Mod.Place(pin, parent, 1000, 600, 2)
	near(pin:GetScale(), 0.5 * 1.25, "chosen: x 1.25")
	pin.hover = true
	Mod.Place(pin, parent, 1000, 600, 2)
	near(pin:GetScale(), 0.5 * 1.25 * 1.15, "chosen and hovered: x 1.15 more")
	pin.creator = true
	Mod.Place(pin, parent, 1000, 600, 2)
	near(pin:GetScale(), 0.5 * 1.25 * 1.15 * W.Mod("UI.Map.Base").CREATOR_SCALE, "founder: x CREATOR_SCALE more")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.pins: SetLevels stacks a pin's parts in order (aura under body under decorations under heart under tag)", function()
	local w, r, W, Mod, parent = standalone()
	local pin = Mod.NewPin(parent)
	Mod.SetLevels(pin, 100)
	eq(pin:GetFrameLevel(), 100, "pin") -- Pins.lua SetLevels
	eq(pin.aura:GetFrameLevel(), 100, "glow")
	eq(pin.pulse:GetFrameLevel(), 101, "pulse")
	eq(pin.auraRing.frame:GetFrameLevel(), 101, "aura ring")
	eq(pin.body:GetFrameLevel(), 102, "body")
	eq(pin.deco:GetFrameLevel(), 103, "decorations")
	eq(pin.heart:GetFrameLevel(), 104, "heart")
	eq(pin.glints[1]:GetFrameLevel(), 105, "glints")
	eq(pin.tag:GetFrameLevel(), 106, "price tag on top")
	Mod.SetLevels(pin, 300)
	eq(pin.tag:GetFrameLevel(), 306, "restacked at another level")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.pins: Paint shows an open driver's ring, not a busy or paused one's; only the chosen open driver pulses and carries the price tag", function()
	local w, r, W, Mod, parent = standalone()
	local pin = Mod.NewPin(parent)
	pin.key, pin.nx, pin.ny = "zed", 0.5, 0.5
	Mod.Paint(pin, entry(), false, 0, false)
	ok(pin.auraRing.frame:IsShown(), "open: the aura ring shows") -- Paint: state == "open"
	ok(not pin.pulsing, "an ordinary open driver does not pulse")
	ok(not pin.tag:IsShown() and not pin.halo:IsShown(), "no tag, no halo when not chosen")
	ok(not pin.aura:IsShown(), "no glow at glow 0")
	Mod.Paint(pin, entry({ state = "busy" }), false, 0.5, false)
	ok(not pin.auraRing.frame:IsShown(), "busy: ring gone")
	ok(pin.aura:IsShown(), "glow above 0 shows the glow")
	Mod.Paint(pin, entry({ state = "paused" }), false, 0, false)
	ok(not pin.auraRing.frame:IsShown(), "paused: ring gone")
	ok(not pin.aura:IsShown(), "paused: glow gone")
	Mod.Paint(pin, entry(), true, 1, false)
	ok(pin.pulsing, "chosen and open: pulses")
	ok(pin.halo:IsShown(), "chosen: the violet halo")
	ok(pin.tag:IsShown(), "chosen: the price tag")
	local price = W.Money(5000)
	eq(pin.tagText:GetText(), price, "the tag says the fare")
	near(pin.tag:GetWidth(), math.max(36, #price * 6 + 18), "tag width follows the text") -- Paint
	Mod.Paint(pin, entry({ state = "busy" }), true, 0, false)
	ok(not pin.pulsing, "chosen but busy: no pulse (StopPulse)")
	ok(pin.tag:IsShown(), "chosen but busy: still has its tag")
	Mod.Paint(pin, entry(), false, 0, false)
	ok(not pin.halo:IsShown() and not pin.tag:IsShown(), "no longer chosen: halo and tag go")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.pins: Paint gives the founder a gold ring, sparkle and crown, and takes them away again; Stop on a fresh pin is harmless", function()
	local w, r, W, Mod, parent = standalone()
	local pin = Mod.NewPin(parent)
	pin.key, pin.nx, pin.ny = "zed", 0.5, 0.5
	Mod.StopPulse(pin)
	Mod.StopCreator(pin)
	ok(not pin.pulsing and not pin.creatorOn, "nothing to stop on a fresh pin")
	Mod.Paint(pin, entry(), false, 1, true)
	eq(pin.creator, true, "marked as the founder")
	ok(pin.creatorOn, "founder effects on")
	ok(pin.goldRing:IsShown(), "gold ring")
	ok(pin.sparkle:IsShown(), "sparkle")
	ok(pin.crown ~= nil, "a crown (the FX crown, else a plain star)") -- ShowCrown
	ok(pin.pulsing, "an open founder pulses without being chosen") -- Paint: creator or chosen
	Mod.Paint(pin, entry(), false, 0, false)
	ok(not pin.creatorOn, "founder effects off")
	ok(not pin.goldRing:IsShown() and not pin.sparkle:IsShown(), "ring and sparkle gone")
	eq(pin.crown, nil, "crown gone")
	ok(not pin.pulsing, "pulse gone")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.pins: Paint's rank decides the gold aura at 1000 and keeps no rank for nonsense", function()
	local w, r, W, Mod, parent = standalone()
	local pin = Mod.NewPin(parent)
	pin.key, pin.nx, pin.ny = "zed", 0.5, 0.5
	Mod.Paint(pin, entry({ rank = 1000 }), false, 0, false)
	eq(pin.rank, 1000, "rank kept")
	eq(pin.auraRing.gold, true, "1000: gold") -- Paint: pin.rank >= 1000
	Mod.Paint(pin, entry({ rank = 999.9 }), false, 0, false)
	eq(pin.rank, 999, "rounded down")
	eq(pin.auraRing.gold, false, "999: not gold")
	Mod.Paint(pin, entry({ rank = 0 }), false, 0, false)
	eq(pin.rank, nil, "rank 0: none")
	Mod.Paint(pin, entry({ rank = -5 }), false, 0, false)
	eq(pin.rank, nil, "negative rank: none")
	Mod.Paint(pin, entry({ rank = nil }), false, 0, false)
	eq(pin.rank, nil, "no rank: none")
	eq(pin.auraRing.gold, false, "no rank: not gold")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.pins: the aura ring falls back to the pin size, starts, stops, and stops when its host hides", function()
	local w, r, W, Mod, parent = standalone()
	local PIN = W.Mod("UI.Map.Base").PIN
	local host = r.env.CreateFrame("Frame", nil, parent)
	local aura = Mod.Aura(host, 40)
	eq(aura.size, 40, "the size asked for")
	aura:SetSize(0)
	eq(aura.size, PIN, "zero: the pin size") -- Pins.lua ApplyAuraSizes
	aura:SetSize(nil)
	eq(aura.size, PIN, "nil: the pin size")
	aura:SetSize(30)
	eq(aura.size, 30, "a real size")
	aura:Start()
	eq(aura.wantTurn, true, "wants to turn")
	ok(aura.frame:IsShown(), "shown")
	aura:Stop()
	eq(aura.wantTurn, false, "stopped")
	eq(aura:Turning(), false, "not turning")
	aura:Start()
	host:Hide()
	eq(aura.wantTurn, false, "the host hid: it stops") -- Aura: host HookScript OnHide
	aura:SetGold(true)
	eq(aura.gold, true, "gold")
	aura:SetGold(nil)
	eq(aura.gold, false, "back to the three colours")
	aura:Hide()
	ok(not aura.frame:IsShown(), "hidden")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.pins: an online driver's pin grows under the cursor, tells the driver's story in its tip, and the tip goes on leave", function()
	local w, r, pin = bobMap()
	local W = r.W
	local bob = W.drivers["bob stone"]
	ok(pin.tag:IsShown() and pin.halo:IsShown(), "Bob is the chosen driver (ShowDriver): halo and price tag")
	eq(pin.tagText:GetText(), W.Money(W.Num(bob.price) or 0), "the tag is Bob's fare")
	ok(pin.pulsing, "an open chosen driver pulses")
	local before = pin:GetScale()
	pin:GetScript("OnEnter")(pin)
	near(pin:GetScale(), before * 1.15, "hover: x 1.15")
	ok(#r:findText("Click to request", false, true) > 0, "the tip says Click to request") -- Pins.lua Tooltip
	ok(#r:findText("To " .. tostring(bob.dest), false, true) > 0, "and where Bob goes")
	local team = W.Num(bob.team) or 1
	local want = team >= 3 and "No helpers needed" or ("Bring " .. (3 - math.max(1, math.floor(team))) .. ((3 - math.max(1, math.floor(team))) == 1 and " helper" or " helpers"))
	ok(#r:findText(want, false, true) > 0, "the helpers line: " .. want)
	pin:GetScript("OnLeave")(pin)
	near(pin:GetScale(), before, "leave: back to size")
	w:advance(1)
	eq(#r:findText("Click to request", false, true), 0, "the tip is gone")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.pins: a favourite driver's pin shows the heart and says so in the tip; the heart goes when the favourite does", function()
	local w, r, pin = bobMap()
	local W = r.W
	ok(not pin.heart:IsShown(), "control: no heart yet")
	eq(W.ToggleFav("bob stone"), true, "Bob is a favourite")
	w:advance(0.5)
	ok(pin.heart:IsShown(), "heart on the pin") -- Paint: IsFav(d.key)
	pin:GetScript("OnEnter")(pin)
	ok(#r:findText("One of your favourites", false, true) > 0, "the tip says so")
	pin:GetScript("OnLeave")(pin)
	eq(W.ToggleFav("bob stone"), false, "not a favourite any more")
	w:advance(0.5)
	ok(not pin.heart:IsShown(), "heart gone")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.pins: clicking an open driver's pin opens Confirm on that driver", function()
	local w, r, pin = bobMap()
	ok(not windowShown(r), "control: Wuber starts shut")
	r:clickOn(pin)
	w:advance(3) -- the first open plays a splash (tests/run.lua openConfirm)
	ok(windowShown(r), "Wuber opened")
	ok(#r:findText("^Request") > 0, "on the Confirm screen (its Request pill)") -- run.lua clickRequest
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.pins: a paused driver's pin says Paused and cannot be requested: the click does nothing", function()
	local w, r, pin = bobMap()
	local W = r.W
	W.drivers["bob stone"].state = "paused" -- Bob pauses (the rider's view of his beacon)
	W.Map.Refresh()
	pin:GetScript("OnEnter")(pin)
	ok(#r:findText("Paused", false, true) > 0, "the tip says Paused") -- Tooltip: d.state == "paused"
	ok(#r:findText("Can't take requests now", false, true) > 0, "and why a click does nothing")
	eq(#r:findText("Click to request", false, true), 0, "no invitation to click")
	pin:GetScript("OnLeave")(pin)
	r:clickOn(pin)
	w:advance(3)
	ok(not windowShown(r), "the click opened nothing") -- OnClick: d.state == "paused" -> return
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.pins: a tooltip for a pin with no driver behind it shows nothing and raises no error", function()
	local w, r, W, Mod, parent = standalone()
	local pin = Mod.NewPin(parent)
	pin.key = "nobody at all"
	Mod.Tooltip(pin)
	w:advance(1)
	eq(#r:findText("Click to request", false, true), 0, "no tip") -- Tooltip: not d -> return
	pin:GetScript("OnClick")(pin)
	w:advance(1)
	ok(not windowShown(r), "and a click on it opens nothing")
	T.clean(w)
end)
