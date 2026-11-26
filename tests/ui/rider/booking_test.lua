-- Tests of UI.Rider.Booking (SPEC7 5.1, 5.2; owner C). Loaded by tests/run.lua with its helper table T.
-- The dial's score (sign, clamping, three knob fixtures), hidden with no data, "about" for
-- estimates, the knob moved along the arc without scale; the route header's names, truncation
-- at 324 px, the unknown origin, the zone-only fallback and ZONE_CHANGED.
local T = ...
local SI = "s" -- (design 1 H: money is letters, "23s", no coin icons)
local function G(s) return "|cfff9c53e" .. s .. "|r" end -- (design 1 P) an amount beside a time is gold letters
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function near(a, b, eps) return math.abs(a - b) <= (eps or 0.01) end

test("ui.rider.booking: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Rider.Booking", "tests/ui/rider/booking_test.lua", {
		["Mod.Dial"] = "function", ["Mod.RouteHeader"] = "function", ["Mod.Score"] = "function",
		["Mod.DialInfo"] = "function", ["Mod.Verdict"] = "function", ["Mod.RouteFrom"] = "function", ["Mod.Via"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Rider.Booking\")")
	T.clean(w)
end)

test("ui.rider.booking: dial score (sign, clamping, three fixtures) and its words", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local Mod = r.W.Mod("UI.Rider.Booking")
	-- 10 min saved at 10g/h = 1g 66s 67c of time; fare 50s, flight 23s: summon wins
	local p, b = Mod.Score({ timeSaved = 600, fare = 5000, flightCost = 2300, rate = 100000 })
	ok(b > 0 and p > 0.95 and p <= 1, "summon wins: " .. p)
	ok(near(b, 600 / 3600 * 100000 - 2700, 0.5), "benefit maths: " .. b)
	-- no time saved, 27s dearer: flying wins
	p, b = Mod.Score({ timeSaved = 0, fare = 5000, flightCost = 2300, rate = 100000 })
	ok(b < 0 and near(p, 0.5 + 0.5 * math.tanh(-2700 / 5000), 0.001), "fly wins: " .. p)
	-- even
	p, b = Mod.Score({ timeSaved = 0, fare = 2300, flightCost = 2300 })
	eq(p, 0.5, "even: the middle")
	-- clamped
	p = Mod.Score({ timeSaved = 1e9, fare = 0, flightCost = 0 })
	ok(p <= 1 and p > 0.999, "clamped high")
	p = Mod.Score({ timeSaved = 0, fare = 1e9, flightCost = 0 })
	ok(p >= 0 and p < 0.001, "clamped low")
	eq(Mod.Score(nil), nil, "no info, no score")
	eq(Mod.Verdict({ timeSaved = 420 }, 9000), "Summon wins by 7 min", "verdict: summon")
	eq(Mod.Verdict({ timeSaved = 420, flyAbout = true }, 9000), "Summon wins by about 7 min", "verdict: about")
	eq(Mod.Verdict({ timeSaved = 420, fare = 5000, flightCost = 2300 }, -9000), "Flying is 27s cheaper, 7 min slower", "verdict: fly")
	eq(Mod.Verdict({ timeSaved = 0 }, 200), "About the same", "verdict: even")
	T.clean(w)
end)

test("ui.rider.booking: the dial hides with no data, says about for estimates, moves its knob without scale", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local Mod = W.Mod("UI.Rider.Booking")
	local d = { dest = "Undercity", price = 5000, queue = 0 }
	W.TravelSaved = function() return nil end
	W.FlightCost = function() return nil end
	eq(Mod.DialInfo(d, 5000), nil, "nothing known about flying: no dial")
	W.TravelSaved = function() return 540 end
	W.FlightCost = function() return 2300, 1 end
	local info = Mod.DialInfo(d, 5000)
	ok(info and info.flyAbout, "the speed model is an estimate")
	eq(info.wait, W.SUMMON_SECS, "an empty queue: a ready driver, W.SUMMON_SECS")
	local dial = Mod.Dial(r.env.UIParent, 324, 88)
	dial:SetPoint("CENTER", r.env.UIParent, "CENTER")
	dial:Set(info)
	ok(H.visible(dial), "shown")
	eq(dial.flyText.wuberText, "9 min · costing " .. G("23" .. SI), "fly label")
	-- (2.3.2) "~2 min · 50s (net 27s)" doesn't fit a side even at its smallest: "(net 27s)" steps aside
	-- (the game cut it with "...")
	eq(dial.summonText.wuberText, "30 sec · costing " .. G("50" .. SI), "summon label")
	ok(not H.truncation(dial.summonText), "not cut")
	eq(dial.verdict.wuberText, "Summon wins by about 9 min", "verdict")
	-- the knob sits on the arc where p says
	local p = Mod.Score(info)
	local kr, dr = H.rect(dial.knob), H.rect(dial)
	local a = math.pi * (1 - p)
	ok(near(kr.l + kr.w / 2 - dr.l, 162 + 38 * math.cos(a), 0.6), "knob x on the arc")
	-- measured flight: no "about"
	W.TravelSaved = function() return 540, "same continent", true end
	W.FlightTime = function() return 480, "own" end
	info = Mod.DialInfo(d, 5000)
	eq(info.flyAbout, false, "own time: no about")
	-- a busy driver: the wait isn't shown
	info = Mod.DialInfo({ dest = "Undercity", price = 5000, queue = 3 }, 5000)
	dial:Set(info)
	eq(dial.summonText.wuberText, G("50" .. SI) .. " (net " .. G("27" .. SI) .. ")", "no wait we can't back")
	ok(not H.truncation(dial.summonText), "the net fits without the wait")
	w:advance(1)
	for _, f in ipairs({ dial, dial.knob }) do
		local sc = H.state[f].scale
		ok(sc == nil or sc == 1, "no scale on the dial")
	end
	dial:Set(nil)
	ok(not dial:IsShown(), "hidden again")
	-- the unfolded size keeps every text inside
	dial:SetSize(324, 120)
	dial:Set(Mod.DialInfo(d, 5000))
	for _, fs in ipairs({ dial.flyHead, dial.flyText, dial.sumHead, dial.summonText, dial.verdict }) do
		local fr = H.rect(fs)
		local rr = H.rect(dial)
		ok(fr.b >= rr.b - 0.5 and fr.b + fr.h <= rr.b + rr.h + 0.5, "inside the wide dial: " .. tostring(fs.wuberText))
	end
	-- (2.3.2) the wide dial's narrower sides: no "(net 27s)" there either, nothing cut
	eq(dial.summonText.wuberText, "30 sec · costing " .. G("50" .. SI), "wide: no (net) on the summon side")
	ok(not H.truncation(dial.summonText), "not cut")
	dial:Set(Mod.DialInfo({ dest = "Undercity", price = 5000, queue = 3 }, 5000))
	ok(not H.truncation(dial.summonText), "wide, no wait: not cut (" .. tostring(dial.summonText.wuberText) .. ")")
	T.clean(w)
end)

test("ui.rider.booking: route header (names, truncation, unknown origin, zone fallback, ZONE_CHANGED)", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local Mod = W.Mod("UI.Rider.Booking")
	local h = Mod.RouteHeader(r.env.UIParent, 324)
	h:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 10, -10)
	h:Set("Brill", "Undercity")
	eq(h.from.wuberText, "Brill", "from")
	eq(h.to.wuberText, "Undercity", "to")
	ok(H.rect(h).w <= 324, "fits")
	h:Set("The Stranglethorn Vale Rebel Camp Of The Long Name", "Undercity", "zeppelin")
	eq(h.fromShown, "The Stranglethorn Vale Rebel Camp Of The Long Name", "the origin wraps whole, never cut (2.4 fix round 3)")
	eq(h.to.wuberText, "Undercity", "the destination stays whole")
	ok(H.rect(h).w <= 324.5, "still 324 at most: " .. H.rect(h).w)
	ok(h.via:IsShown() and h.via.label.wuberText == "zeppelin", "the zeppelin tag")
	-- origin from where the rider stands
	W.DestHere = function() return "Brill", { name = "Brill", kind = "town" } end
	eq(Mod.RouteFrom(), "Brill", "the subzone place")
	W.DestHere = function() return "Tirisfal Glades", nil end
	W.ZoneHere = function() return "Tirisfal Glades" end
	eq(Mod.RouteFrom(), "Tirisfal Glades", "zone only")
	W.ZoneHere = function() return "Unknown" end
	eq(Mod.RouteFrom(), "Here", "unknown: Here")
	h:Update("Undercity")
	eq(h.from.wuberText, "Here", "Here -> Undercity")
	W.DestHere = function() return "Brill", { name = "Brill", kind = "town" } end
	r:fire("ZONE_CHANGED")
	w:advance(0.1)
	eq(h.from.wuberText, "Brill", "follows ZONE_CHANGED")
	T.clean(w)
end)

test("ui.rider.booking: round 9 S18 - W.MoneyIcons: the game's coin icons for money next to times", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
	local GI = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
	local CI = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
	eq(W.MoneyIcons(2300), "23" .. SILVER_ICON, "23 silver: a coin, never '23s'")
	eq(W.MoneyIcons(12345), "1" .. GI .. " 23" .. SILVER_ICON .. " 45" .. CI, "gold, silver, copper")
	eq(W.MoneyIcons(0), "0" .. GI, "nothing: 0 gold")
	eq(W.Money(2300), "23s", "W.Money keeps the game's normal s")
	T.clean(w)
end)

test("ui.rider.booking 2.3.2 C8: the route header tooltip has a title, one text and the default anchor", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local Mod = r.W.Mod("UI.Rider.Booking")
	local h = Mod.RouteHeader(r.env.UIParent, 324)
	h:Set("Orgrimmar", "Undercity", nil)
	local tip = h.wuberTip
	ok(tip, "has a tooltip")
	eq(tip.title, "Your trip", "title")
	eq(tip.anchor, nil, "anchor is not a function")
	eq(type(tip.text), "function", "text")
	ok(tip.text():find("Orgrimmar to Undercity", 1, true), "route in the text: " .. tostring(tip.text()))
	ok(tip.text():find("summons you", 1, true), "plain wording")
	h:Set("Orgrimmar", "Undercity", "zeppelin")
	ok(tip.text():find("zeppelin", 1, true), "via in the text: " .. tostring(tip.text()))
	T.clean(w)
end)

test("ui.rider.booking: a long verdict (Flying is 49s 50c cheaper, about 3 min slower) is plain money and wraps to two full lines", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local Mod = r.W.Mod("UI.Rider.Booking")
	local info = { timeSaved = 180, fare = 9000, flightCost = 4050, flyAbout = true, flySecs = 600, wait = 120, rate = 1 }
	local text = Mod.Verdict(info, -9000)
	eq(text, "Flying is 49s 50c cheaper, about 3 min slower", "two amounts read as one money, no coin icons")
	for _, size in ipairs({ { 324, 88 }, { 324, 96 }, { 324, 62 } }) do
		local tag = size[1] .. "x" .. size[2]
		local dial = Mod.Dial(r.env.UIParent, size[1], size[2])
		dial:SetPoint("CENTER", r.env.UIParent, "CENTER")
		dial:SetSize(size[1], size[2])
		dial:Set(info)
		eq(dial.verdict.wuberText, text, "verdict at " .. tag)
		ok(not H.truncation(dial.verdict), "verdict not cut at " .. tag)
		ok(dial.verdict.wuberWrapped, "wraps rather than shrinks at " .. tag)
		ok(dial.verdict.wuberPx >= 11, "not shrunk below 11 at " .. tag)
		ok((dial.extra or 0) > 0 and near(dial:GetHeight(), size[2] + dial.extra, 0.01), "the dial grew by the second line at " .. tag)
		local dr, vr, lr = H.rect(dial), H.rect(dial.verdict), H.rect(dial.line)
		ok(vr.b >= dr.b - 0.5 and lr.b >= dr.b - 0.5, "verdict and line inside the dial at " .. tag .. ": " .. vr.b .. " / " .. lr.b .. " vs " .. dr.b .. " (verdict h " .. vr.h .. ")")
		-- (the fake game draws a label one line tall: work out where two lines of verdict and the line end)
		local need = dial.top + dial.r + 6 + 2 * dial.verdict.wuberPx * 1.2 + 3 + 10 * 1.2
		ok(need <= dial:GetHeight() + 0.5, "two verdict lines and the line fit the dial at " .. tag .. ": " .. need .. " vs " .. dial:GetHeight())
	end
	T.clean(w)
end)
