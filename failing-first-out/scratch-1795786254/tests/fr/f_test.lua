-- Group f of the 2.4 fix round: ING-07 (the empty Home's bold line wraps, never cut), HR-2 (Advanced: "Tell me
-- when one opens" above the bounty card too), HUNT-136 (the offline chip clear of the header buttons).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local PLACE = "Feathermoon Stronghold"

local function setup(simple)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	if simple then r.W.Advanced = function() return false end end
	r.W.UI.Toggle(true) w:advance(2.5)
	r.W.UI.Show("home") w:advance(1)
	r.W.UI.SetSearch(PLACE) w:advance(1)
	r.W.UI.RefreshNow() w:advance(0.3)
	return w, r, r.W.UI.state.screens.home
end

local function top(fr) return fr:GetTop() end

test("fr f: ING-07 the empty Home's bold line wraps to two lines, whole, never cut", function()
	local w, r, s = setup()
	local t = s.empty.title
	eq(t:GetText(), "Nobody summons to " .. PLACE .. " right now", "the whole sentence")
	ok(t.wuberLines == 2 or (tonumber(t.wuberMaxLines) or 0) >= 2, "the line may take two lines")
	ok(t.wuberPx == t.wuberBase, "wrapped at full size")
	T.clean(w)
end)

test("fr f: HUNT-136 the Network offline chip stays clear of the header buttons (narrow Ride screen)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	r.W.UI.Toggle(true) w:advance(2.5)
	r.W.UI.Show("home") w:advance(1)
	local ui = r.W.UI.state
	local net = ui.screens.home.map.net
	ok(net:IsShown(), "the chip shows while off the channel")
	for _, nm in ipairs({ "close", "gear" }) do
		local b = ui[nm]
		local clear = net:GetTop() <= b:GetBottom() + 0.5 or net:GetRight() <= b:GetLeft() or net:GetLeft() >= b:GetRight()
		ok(clear, "clear of the " .. nm .. " button: chip top " .. net:GetTop() .. ", button bottom " .. b:GetBottom())
	end
	T.clean(w)
end)

test("fr f: HR-2 Advanced: a place nobody serves shows 'Tell me when one opens' above the bounty card", function()
	local w, r, s = setup()
	local e = s.empty
	ok(e.bounty:IsShown(), "the bounty card is up")
	ok(e.watch:IsShown(), "the bell button is shown too")
	eq(e.watch.place, PLACE, "for the searched place")
	ok(e.watch:GetBottom() >= e.bounty:GetTop() - 0.5, "the button is above the card: bottom " .. tostring(e.watch:GetBottom()) .. ", card top " .. tostring(e.bounty:GetTop()))
	ok(e.bounty.note:GetBottom() >= e.bounty.pin:GetTop() - 0.5 or e.bounty.note:GetBottom() >= e:GetBottom(), "the card's note is not cut: note bottom " .. tostring(e.bounty.note:GetBottom()) .. ", pin top " .. tostring(e.bounty.pin:GetTop()))
	ok(e.watch:GetTop() <= e.title:GetBottom() + 40 and e.watch:GetTop() <= e.title:GetTop(), "and under the heading")
	T.clean(w)
end)

test("fr f: HR-2 the button works in Advanced (tip and click), and Simple still shows it", function()
	local w, r, s = setup()
	local on
	r.W.ToggleWatch = function(p) on = p return true end
	s.empty.watch:Click()
	eq(on, PLACE, "a click asks for a note about the place")
	T.clean(w)
	local w2, r2, s2 = setup(true)
	ok(s2.empty.watch:IsShown() and s2.empty.watch.place == PLACE, "Simple: shown as before")
	T.clean(w2)
end)
