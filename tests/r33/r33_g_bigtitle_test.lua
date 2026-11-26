local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- Round 33, group G (HUNT-117): with three jobs owed the big Drive button's title is all of them joined
-- ("Thank Elm, Wuber tip for Birch, Remove Elm") and was cut at the smallest size (14): the third job was
-- lost. The title now wraps onto a second line (still at 14) instead of being cut.

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	W.UI.Toggle(true)
	w:advance(2)
	W.UI.SelectTab("Drive")
	w:advance(2)
	return w, d, W, d.env.WuberDriveButton
end

test("r33 g: a three-job title on the big Drive button is whole, on two lines, never cut", function()
	local w, d, W, b = setup()
	local DR = W.Drive
	local was = H.TEXT_PIXELS
	H.TEXT_PIXELS = { px = 0.75, snap = "round", track = 0 }
	local real = DR.Plan
	local function show(title)
		DR.Plan = function()
			return { marks = {}, color = "go", title = title, sub = "click", doing = {}, says = {}, lines = 0, paused = false }
		end
		DR.Button.Refresh()
	end
	local long = "Thank Elm, Wuber tip for Birch, Remove Elm"
	show(long)
	eq(b.title:GetText(), long, "the whole title is set")
	local tr = H.truncation(b.title)
	ok(not tr, "not cut: " .. (tr and ("needs " .. tostring(tr.need) .. " of " .. tostring(tr.room)) or ""))
	local n = H.textLines(b.title)
	ok(not n or n <= 2, "at most two lines (" .. tostring(n) .. ")")
	-- a short title keeps its big single line
	show("Summon Dan")
	ok((b.title.wuberPx or 0) > 14, "a short title stays big (" .. tostring(b.title.wuberPx) .. ")")
	show(long)
	ok(not H.truncation(b.title), "long again: not cut")
	DR.Plan = real
	H.TEXT_PIXELS = was
	T.clean(w)
end)
