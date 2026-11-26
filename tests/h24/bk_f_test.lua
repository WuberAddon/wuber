-- tests/h24 group F: break-it guards for the 2.4.1 changes in UI/Settings/Panel.lua and Find.lua (E3b-05, E3b-06).
-- Each passes on the real code and fails on the break named above it.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function R(f) return H.rect(f) end
local function top(r) return r.b + r.h end

local function open(wide, adv)
	local w = T.newWorld()
	local c = T.rider(w)
	T.settle(w)
	c.wide = wide
	c.W.db.fold = { v = 1, pages = {}, narrow = not wide }
	c.W.SetAdvanced(adv)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings()
	w:advance(2)
	return w, c, c.W.UI.settings, c.W.Mod("UI.Settings.Panel")
end

-- the root page: a display-size "Settings" under the back arrow (never over it), the hint under the title, the search
-- box under the hint, the list of sections under the box; the same Simple and Advanced, folded and unfolded.
-- guard: break-it, Panel.lua:206 the title made heading size (T.Text(p, "display", ...) -> "heading") and Panel.lua:219 (SetFont always "display")
-- guard: break-it, Panel.lua:208 the title anchored -20 instead of -48 (it sits on the back arrow)
-- guard: break-it, Panel.lua:214 the hint anchored beside the back arrow instead of under the title
-- guard: break-it, Find.lua:42 fieldY 102 -> 50 (the box under the title), listY 144 -> 92 (the list under the box)
test("h24 f bk: Settings root - display title under the back arrow, hint under it, box under the hint, list under the box", function()
	for _, wide in ipairs({ false, true }) do
		for _, adv in ipairs({ false, true }) do
			local w, c, st = open(wide, adv)
			local what = (wide and "unfolded " or "folded ") .. (adv and "Advanced" or "Simple")
			local back, title, hint, box = R(st.back), R(st.title), R(st.hint), R(st.find.box)
			ok(title.h >= 34, what .. ": the title is display size (height " .. title.h .. ")")
			ok(top(title) <= back.b + 1, what .. ": the title is under the back arrow, not over it")
			ok(math.abs(title.l - back.l) <= 6, what .. ": the title is on the page's left edge")
			ok(H.visible(st.hint), what .. ": the hint shows on the root page")
			ok(top(hint) <= title.b + 3 and top(hint) >= title.b - 6, what .. ": the hint sits right under the title")
			ok(math.abs(hint.l - title.l) <= 1, what .. ": the hint starts under the title")
			ok(top(box) <= hint.b + 1, what .. ": the search box is under the hint")
			if not wide then
				local home = R(st.find.home)
				ok(top(home) <= box.b + 1, what .. ": the section list is under the search box")
			end
			T.clean(w)
		end
	end
end)

-- a folded section page keeps its name small beside the back arrow (the header bar), no hint, and the root page
-- gets its big title back on Back
-- guard: break-it, Panel.lua:218 sub = false (a section would show the big title at the root place) and :222/:224 the two anchors swapped
test("h24 f bk: folded section page - heading-size name beside the back arrow, no hint; Back restores the big title", function()
	local w, c, st, P = open(false, true)
	P.openSection("riding")
	w:advance(2)
	local back, title = R(st.back), R(st.title)
	ok(title.h < 30, "the section name is heading size (height " .. title.h .. ")")
	ok(title.l >= back.l + back.w, "the name is right of the back arrow")
	ok(math.abs((title.b + title.h / 2) - (back.b + back.h / 2)) <= 8, "the name is level with the back arrow")
	ok(not H.visible(st.hint), "no hint on a section page")
	P.back()
	w:advance(2)
	title = R(st.title)
	ok(title.h >= 34, "back at the root the title is display size again")
	ok(top(title) <= R(st.back).b + 1, "and under the back arrow")
	T.clean(w)
end)

-- Help unfolded reads as the folded page: its text starts at the panel's left edge, not in a right half
-- guard: break-it, Panel.lua:1644 the wide clip moved to the right half (on and WIN_W or 0)
test("h24 f bk: unfolded Help text starts at the panel's left edge (no empty left half)", function()
	local w, c = open(true, true)
	local UI = c.W.UI
	UI.CloseSettings()
	w:advance(1)
	UI.OpenHelp("settings")
	w:advance(2)
	local help = UI.settings.help
	ok(help.wide, "Help is in wide mode")
	local pl, cl = R(help.panel), R(help.clip)
	ok(math.abs(cl.l - pl.l) <= 1, "the text clip starts at the panel's left edge (clip " .. cl.l .. ", panel " .. pl.l .. ")")
	T.clean(w)
end)
