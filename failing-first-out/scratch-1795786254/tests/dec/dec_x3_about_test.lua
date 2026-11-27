-- Decisions round, group X3. Reading the round's behaviour transcript showed a line players see gone from Confirm:
-- the About this driver card's last line ("Bring friends to click the portal" / "Their crew clicks the portal").
-- The cause: "Favourite" under the heart made the driver card's grey line a few pixels narrower, a line such as
-- "Ratchet · Bring 2 friends · Open · Founder" wrapped, the card grew 13, and the folded sheet (full already)
-- let About's crew line go. Now every line stays while the sheet can make the room (the tighter card, then the
-- short Fly or summon card); a line leaves only after that. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function plain(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- the About card's shown lines, in order
local function aboutShown(r)
	local a = r.W.Mod("UI.Rider.Confirm").side.about
	local out = {}
	if a and H.visible(a) then
		for _, fs in ipairs(a.lines) do
			if H.visible(fs) then out[#out + 1] = fs.wuberText end
		end
	end
	return out, a
end

-- the stack ends over the Request pill (nothing was pushed under it to keep the lines)
local function fitsSheet(s, how)
	ok(s.stackEnd - 10 <= 544 - s.cardTop - (54 + 16 + 8), "the stack ends over the Request pill (" .. how .. "): ends " .. tostring(s.stackEnd) .. ", sheet top " .. tostring(s.cardTop))
end

local function bothSides(s)
	local d = s.dial
	ok(H.visible(d), "the Fly or summon card shows")
	ok(plain(d.flyText.wuberText):find("^%d+ min · costing "), "the fly side: " .. plain(d.flyText.wuberText))
	ok(plain(d.summonText.wuberText):find("^%d+ %a+ · costing "), "the summon side: " .. plain(d.summonText.wuberText))
	ok(not H.truncation(d.summonText) and not H.truncation(d.flyText), "neither side is cut")
end

test("dec x3: folded Confirm keeps About this driver's last line when the driver card's grey line wraps", function()
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local d = T.driver(w)
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	T.needUI(r)
	r.W.db.fold = { v = 1, pages = {}, narrow = true }
	r.W.UI.Toggle(true)
	w:advance(3)
	local key
	for k in pairs(r.W.drivers) do key = k end
	ok(key, "the driver is listed")
	r.W.UI.Show("confirm", key)
	w:advance(1.5)
	local s = r.W.UI.state.screens.confirm
	ok(not s.wide, "folded")
	bothSides(s)
	ok(s.card.driver.wuberWrapped, "the grey line wrapped (the case that lost the line): " .. tostring(s.card.driver.wuberText))
	ok(not H.truncation(s.card.driver), "and is not cut")
	local lines, a = aboutShown(r)
	ok(a and H.visible(a), "About this driver shows")
	eq(lines[#lines], "Bring friends to click the portal", "its last line (" .. table.concat(lines, " | ") .. ")")
	eq(#lines, #r.W.Mod("UI.Rider.Confirm").aboutLines(r.W.UI.Driver(key)), "no line left out")
	ok(#r:findText("Bring friends to click the portal") > 0, "the rider can read it")
	ok(#r:findText("Favourite") > 0, "Favourite is still written with the heart")
	fitsSheet(s, "folded")
	T.clean(w)
end)

test("dec x3: unfolded Confirm with time and price on both sides shows About this driver down to its last line", function()
	local w = T.newWorld()
	local d = T.driver(w)
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	T.needUI(r)
	r.wide = true
	r.W.UI.Toggle(true)
	w:advance(3)
	local key
	for k in pairs(r.W.drivers) do key = k end
	r.W.UI.Show("confirm", key)
	w:advance(1.5)
	local s = r.W.UI.state.screens.confirm
	ok(s.wide, "unfolded")
	bothSides(s)
	local lines, a = aboutShown(r)
	ok(a and H.visible(a), "About this driver shows")
	eq(lines[#lines], "Bring friends to click the portal", "its last line (" .. table.concat(lines, " | ") .. ")")
	eq(#lines, #r.W.Mod("UI.Rider.Confirm").aboutLines(r.W.UI.Driver(key)), "no line left out")
	fitsSheet({ stackEnd = s.stackEnd, cardTop = s.cardTop }, "unfolded")
	T.clean(w)
end)
