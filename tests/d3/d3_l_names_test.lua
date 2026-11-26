-- Design round 3, group L: no number is a text size any more. The big per-hour figure steps hero, display, title as its
-- text grows (and fits its 160 px room); a pill's label is named by its height; opts.size callers draw what they drew.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function rider()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	return w, r, r.W.Theme
end
local function sizeOf(fs)
	local _, size = fs:GetFont()
	return size
end

test("d3 l: the Earnings big number steps hero, display, title as its text grows, and always fits its room", function()
	local _, r, Th = rider()
	local figureSize = r.W.Mod("UI.Driver.Earnings").figureSize
	eq(type(figureSize), "function", "Earnings exports figureSize")
	eq(figureSize("5g"), "hero", "a short figure is hero")
	local order = { hero = 3, display = 2, title = 1 }
	local last, seen = 3, {}
	local text, band = "", nil
	for n = 1, 14 do
		text = text .. "8"
		local name = figureSize(text)
		ok(order[name], "a scale name: " .. tostring(name))
		ok(order[name] <= last, "a longer figure never gets a bigger size (" .. n .. " digits)")
		last = order[name]
		seen[name] = true
		if name ~= "title" then
			ok(Th.MeasureText(text, name, "bold") * 1.08 <= 160, n .. " digits at " .. name .. " fit the 160 px room")
		end
		-- the old rule: floor(40 * 160 / need) between 35 and 39 was snapped UP to 40 and overflowed
		local need = Th.MeasureText(text, "hero", "bold") * 1.08
		if need > 160 then
			local old = math.max(22, math.floor(40 * 160 / need))
			if old >= 35 and old <= 39 then band = text end
		end
	end
	ok(seen.hero and seen.display and seen.title, "all three names are used as the text grows")
	ok(band, "a figure in the old in-between band exists")
	eq(Th.Snap(35), 40, "the old size for it snapped up to hero")
	ok(Th.MeasureText(band, "hero", "bold") * 1.08 > 160, "hero overflows there")
	eq(figureSize(band), "display", "now it takes display, which fits")
	ok(Th.MeasureText(band, "display", "bold") * 1.08 <= 160, "and it fits")
end)

test("d3 l: a pill's label is named by its height: 50 high heading, 40 high body, 30 high sub", function()
	local _, r, Th = rider()
	local P = r.env.UIParent
	for h, want in pairs({ [50] = "heading", [40] = "body", [30] = "sub" }) do
		local b = Th.Pill(P, "Go", "dark", 160, h)
		eq(sizeOf(b.label), Th.SIZE[want], h .. " high: " .. want)
		eq(b.label.wuberPx, Th.SIZE[want], h .. " high: remembered as " .. want)
	end
end)

test("d3 l: opts.size callers draw what they drew (a tag, a field, a paragraph) and names work as numbers did", function()
	local _, r, Th = rider()
	local P = r.env.UIParent
	local tag = Th.Tag(P, "Time saved", { size = "sub" })
	eq(sizeOf(tag.label), 12, "tag sub")
	local small = Th.Tag(P, "You", { size = "caption" })
	eq(sizeOf(small.label), 11, "tag caption (10 drew 11)")
	local plain = Th.Tag(P, "Plain", {})
	eq(sizeOf(plain.label), 12, "a tag with no size is sub")
	local f = Th.Field(P, 200, 30, { size = "caption" })
	eq(sizeOf(f.edit), 11, "field caption")
	local g = Th.Field(P, 200, 30, {})
	eq(sizeOf(g.edit), 14, "a field with no size is body")
	local p = Th.Para(P, "body", "muted", 200)
	eq(sizeOf(p), 14, "paragraph body")
	local h = p:SetPara("one two three")
	ok(type(h) == "number" and h > 0, "a paragraph's height is a number")
	eq(Th.ROW.title, "body", "a row's title is body")
	eq(Th.ROW.sub, "caption", "a row's sub is caption")
end)
