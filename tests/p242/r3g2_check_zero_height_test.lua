-- p242 r3 G2 (a review, fitLine): a font that has not loaded reports a string height of 0, and 0 is truthy in Lua:
-- the row stayed 20 high under a wrapped line. 0 is unknown: the row is sized from the words.
local T = ...
local test, ok = T.test, T.ok
local H = T.H
local TL = dofile("tools/preview/textlayout.lua")
local function withMetrics(fn)
	local old, s1, s2 = H.textMetrics, TL.SNAP, TL.SIZE_SNAP
	TL.SNAP, TL.SIZE_SNAP = "round", "round"
	H.textMetrics = TL
	local good, err = pcall(fn)
	H.textMetrics, TL.SNAP, TL.SIZE_SNAP = old, s1, s2
	if not good then error(err, 0) end
end

local function run(name)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	local line = name .. " leads the group: only the leader can invite. Ask " .. name .. " to make you leader."
	W.Drive.Readiness = function() return { { text = line, ok = false }, { text = "Short line", ok = true } } end
	W.UI.OpenSettings("window") w:advance(1)
	local st = W.UI.settings
	-- every label reports 0 high at first, as a font not yet loaded does
	st.controls.check:Click() w:advance(1.5) -- the first press makes the labels
	for _, l in ipairs(st.results.lines) do l.text.GetStringHeight = function() return 0 end end
	st.controls.check:Click() w:advance(1.5)
	local long, short
	for _, l in ipairs(st.results.lines or {}) do
		if l:IsShown() then
			local t = l.text:GetText() or ""
			if t == line then long = l elseif t == "Short line" then short = l end
		end
	end
	T.clean(w)
	return long, short
end

-- long name: the row is taller than one line, and the next line starts below it
test("r3g2: with the font reporting height 0, a wrapped Check my game line still gets a tall row", function() withMetrics(function()
	local long, short = run("Danfieldlongnamed")
	ok(long and short, "control: both lines are listed")
	ok(long:GetHeight() > 20, "row is " .. long:GetHeight() .. " high for a wrapped line")
	local lt, st = long:GetTop(), short:GetTop()
	ok(lt - long:GetHeight() >= st - 0.5, "the next line starts at " .. st .. ", under the row's bottom " .. (lt - long:GetHeight()))
end) end)

-- guard: a short line keeps its one-line 20 row even when the height is 0
test("r3g2 guard: a short line keeps its 20-high row when the font reports 0", function() withMetrics(function()
	local _, short = run("Dan")
	ok(short and short:GetHeight() == 20, "short row is " .. tostring(short and short:GetHeight()))
end) end)
