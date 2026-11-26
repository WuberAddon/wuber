-- Event 3b, group H (E3b-05): the Earnings page's title is the big one (display, 28) drawn on the page under the
-- header bar's back chevron, and the page's scroll area starts below it. Other Screens users keep the heading title
-- beside the chevron. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function world()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	return a, a.W.Driver, a.W.Theme
end

test("e3b-h: the Earnings title is display size, below the back chevron, and the scroll area starts under it", function()
	local a, D, Th = world()
	local s = D.screens.earnings(a.env.UIParent)
	eq(s.title.wuberPx, Th.SIZE.display, "the title is display size")
	eq(s.title:GetText(), "Earnings", "the same word")
	local _, _, _, _, ty = s.title:GetPoint(1)
	local _, _, _, _, sy = s.scroll:GetPoint(1)
	ok(-ty >= 44, "the title starts (" .. -ty .. ") below the back chevron's bottom (44)")
	ok(-sy >= -ty + Th.DrawnSize("display"), "the scroll area starts (" .. -sy .. ") under the whole title")
end)

-- guard: the earnings page already kept its scroll top on the base; this is the neighbouring path of the title fix
test("e3b-h: guard: the Earnings page keeps its scroll top under the title when it sets the scroll area again", function()
	local a, D = world()
	local s = D.screens.earnings(a.env.UIParent)
	local _, _, _, _, before = s.scroll:GetPoint(1)
	s.frame:Show()
	s.update()
	local _, _, _, _, after = s.scroll:GetPoint(1)
	eq(after, before, "the scroll top did not move back up under the title")
end)

-- guard: the other driver screens already kept the small header title on the base; this is the neighbouring path
test("e3b-h: guard: the other driver screens keep the small title in the header bar", function()
	local a, D, Th = world()
	local s = D.screens.crew(a.env.UIParent)
	eq(s.title.wuberPx, Th.SIZE.heading, "Your crew keeps the heading size")
	local _, _, _, _, sy = s.scroll:GetPoint(1)
	eq(sy, -50, "and its scroll area still starts at 50")
end)
