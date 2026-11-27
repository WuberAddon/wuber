-- Decisions round, group H. Design round 1, point 7: a price directly beside a worked-out time in one sentence reads
-- time first, then "costing" and the price in gold, with no "about" ("2 min · costing 23s"). Point 5: three of the six
-- icons get their words: "Favourite" beside the heart on Confirm, the chosen badge's name under the badge row, a
-- tooltip on the founder's floating crown. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local GOLD = "|cff" .. "%x%x%x%x%x%x"
local function plain(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function riderWorld(fly, cost)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local t0 = r.env.GetTime()
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = t0, queue = 0, ver = "2.3.0" }
	r.W.FlightCost = function() if cost then return cost, 1 end return nil end
	r.W.TravelSaved = function() return fly end
	r.W.db.tipPct = 10
	r.W.db.fold = { v = 1, pages = {}, narrow = true }
	return w, r
end
local function show(w, r, screen, key)
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.Show(screen, key)
	w:advance(1.5)
	return r.W.UI.state.screens[screen]
end

test("dec h: the Fly or summon card's sides read time, then costing and the gold price, without about", function()
	local w, r = riderWorld(540, 2300)
	local s = show(w, r, "confirm", "mia runner")
	local d = s.dial
	eq(plain(d.summonText.wuberText), "30 sec · costing 55s", "the summon side's words")
	ok(d.summonText.wuberText:find("^30 sec · costing " .. GOLD .. "55s|r"), "the summon price is gold: " .. d.summonText.wuberText)
	ok(plain(d.flyText.wuberText):find("^%d+ min · costing 23s$"), "the fly side's words: " .. plain(d.flyText.wuberText))
	ok(d.flyText.wuberText:find("costing " .. GOLD .. "23s|r$"), "the fly price is gold: " .. d.flyText.wuberText)
	ok(not H.truncation(d.summonText) and not H.truncation(d.flyText), "neither side is cut")
	T.clean(w)
end)

test("dec h: a time alone keeps about, a price alone gets no costing", function()
	local w, r = riderWorld(540, nil)
	local Mod = r.W.Mod("UI.Rider.Booking")
	local dial = Mod.Dial(r.env.UIParent, 324, 88)
	dial:SetPoint("CENTER", r.env.UIParent, "CENTER")
	dial:Set({ flySecs = 300, flyAbout = true, fare = 5000, wait = 30, waitKnown = false })
	eq(dial.flyText.wuberText, "about 5 min", "a flight time with no price: about stays")
	eq(plain(dial.summonText.wuberText), "50s", "a price with no wait we can back: the price alone")
	dial:Set({ flySecs = 300, flyAbout = true, flightCost = 0, fare = 5000, wait = 30, waitKnown = true })
	ok(dial.flyText.wuberText:find("^about 5 min"), "a crossing without a price: about stays: " .. dial.flyText.wuberText)
	ok(not dial.flyText.wuberText:find("costing", 1, true), "and no costing")
	dial:Set({ flightCost = 2300, fare = 5000, wait = 120, waitKnown = true })
	eq(plain(dial.flyText.wuberText), "23s", "a flight price with no time: the price alone")
	ok(plain(dial.summonText.wuberText):find("^2 min · costing 50s"), "minutes: " .. plain(dial.summonText.wuberText))
	T.clean(w)
end)

local function readTip(r, btn)
	local onEnter = btn:GetScript("OnEnter")
	if onEnter then onEnter(btn) end
	local gt = r.env.GameTooltip
	local parts = {}
	if gt and type(gt.NumLines) == "function" then
		for i = 1, gt:NumLines() do
			local fs = r.env["GameTooltipTextLeft" .. i]
			local txt = fs and type(fs.GetText) == "function" and fs:GetText()
			if txt and txt ~= "" then parts[#parts + 1] = txt end
		end
	end
	if #parts == 0 and gt and type(gt.lines) == "table" then
		for _, ln in ipairs(gt.lines) do
			if type(ln) == "string" then parts[#parts + 1] = ln
			elseif type(ln) == "table" and type(ln.text) == "string" then parts[#parts + 1] = ln.text
			elseif type(ln) == "table" and type(ln[1]) == "string" then parts[#parts + 1] = ln[1] end
		end
	end
	if #parts == 0 and type(btn.wuberTip) == "table" then
		local t = btn.wuberTip
		parts[1] = tostring(type(t.title) == "function" and t.title(btn) or t.title or "")
		parts[2] = tostring(type(t.text) == "function" and t.text(btn) or t.text or "")
	end
	return table.concat(parts, "\n")
end

test("dec h: the flight map tag's tooltip reads the wait, then costing and the gold price; the flying sentence keeps about", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Orgrimmar", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime() }
	r.W.FlightTime = function() return 540, "est" end
	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)
	local pins = Mod.Pins()
	eq(#pins, 1, "one pin")
	local tip = readTip(r, pins[1].tag)
	ok(plain(tip):find("Mia's Rides · summon to Orgrimmar · 30 sec · costing 50s. Flying: about 9 min.", 1, true), "the line: " .. plain(tip))
	ok(tip:find("costing " .. GOLD .. "50s|r"), "the price is gold: " .. tip)
	T.clean(w)
end)

test("dec h: Confirm writes Favourite with the heart, and the driver card's words stop short of it", function()
	local w, r = riderWorld(540, 2300)
	local s = show(w, r, "confirm", "mia runner")
	local card = s.card
	local heart = card.heart
	ok(heart and heart.word, "the heart carries its word")
	eq(heart.word.wuberText or heart.word:GetText(), "Favourite", "the word")
	ok(H.visible(heart.word), "the word shows")
	local hw, wr, sv, dr = H.rect(heart), H.rect(heart.word), H.rect(card.service), H.rect(card.driver)
	ok(wr.b + wr.h <= hw.b + 3, "the word sits under the heart")
	ok(math.abs((wr.l + wr.w / 2) - (hw.l + hw.w / 2)) <= 1, "centred on it")
	local row = H.rect(card.row)
	ok(wr.l >= row.l and wr.l + wr.w <= row.l + row.w and wr.b >= row.b, "inside the driver card")
	ok(sv.l + sv.w <= wr.l + 1 and dr.l + dr.w <= wr.l + 1, "the service and driver lines end before the word: " .. (sv.l + sv.w) .. ", " .. (dr.l + dr.w) .. " against " .. wr.l)
	ok(heart.wuberTip ~= nil, "the heart keeps its tooltip")
	T.clean(w)
end)

local function openSettings(c, w, where)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings(where)
	w:advance(1)
	return c.W.UI.settings
end

test("dec h: Settings writes the chosen badge's name under the badge row", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local W = d.W
	local first = W.BADGES[1]
	W.Char().badge = first.id
	local st = openSettings(d, w, "driving")
	ok(st.badgeName, "the name line exists")
	eq(st.badgeName.wuberText or st.badgeName:GetText(), first.name, "it names the chosen badge")
	ok(H.visible(st.badgeName), "it shows")
	local nr = H.rect(st.badgeName)
	for _, b in ipairs(st.badges) do
		local br = H.rect(b)
		ok(nr.b + nr.h <= br.b + 1, "the name is under every badge")
	end
	local none
	for _, b in ipairs(st.badges) do if b.id == "" and not b.founder then none = b end end
	d:click(none)
	w:advance(0.5)
	eq(st.badgeName.wuberText or st.badgeName:GetText(), "None", "no badge: None, the tile's own name")
	T.clean(w)
end)

test("dec h: the founder's floating crown has a tooltip and takes no click", function()
	local w = T.newWorld()
	local r = T.rider(w, "Anita Lift", { spot = "Orgrimmar" })
	T.settle(w)
	local P = r.W.Plates
	P.EnsureSelf() w:advance(1)
	local h = P.SelfCrown()
	ok(h ~= nil, "the founder's own crown exists")
	local tip = h.wuberTip
	ok(type(tip) == "table", "it has a tooltip")
	eq(tip and tip.title, "Wuber founder", "the title")
	ok(tip and tostring(tip.text):find("Your founder's crown", 1, true), "the words")
	ok(not h:IsMouseEnabled(), "a click goes through it to the game world")
	T.clean(w)
end)
