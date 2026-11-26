-- A toast holds its whole text: a long message (or one long word) makes the toast taller, never cuts the words.
-- Found by a hunt walk: "No place called xxxxxxxxxxxx~" (Wuber/UI/Rider/Cards.lua, UI.Toast("No place called " .. text))
-- read "Text is cut off". Judged with the layout engine's own rules (tests/layout/engine.lua: kinds cut, clipped, offscreen).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local root = T.root or H.root
local E = assert(loadfile(root .. "/tests/layout/engine.lua"))(H)

local function toastWorld(text, kind)
	local untag = E.tag({ Wuber = H.ADDONS.Wuber }) -- widgets made from now on are tagged Wuber's, as the sweep does
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	local t = r.W.UI.Toast(text, kind or "warn")
	w:advance(1)
	untag()
	return w, r, t
end

-- the problems of the toast's own text and card: what the sweep would report about them
local function toastProblems(r, t)
	local bad = {}
	for _, h in ipairs(E.check(r)) do
		local s = tostring(h.what) .. " " .. tostring(h.detail)
		if (h.kind == "cut" or h.kind == "clipped" or h.kind == "offscreen" or h.kind == "straddle" or h.kind == "under") and s:find("No place called", 1, true) then
			bad[#bad + 1] = h.kind .. ": " .. s
		end
	end
	return bad
end

-- guard: this already passed before the fix (a toast always grew taller for wrapped lines); it keeps that so
test("d3 toast fit: a long message of several words is shown whole, the toast taller", function()
	local text = "No place called " .. string.rep("Stormwind Harbour Crossing ", 6) .. "Inn"
	local w, r, t = toastWorld(text)
	ok(type(t) == "table", "the toast shows")
	eq(t.text:GetText(), text, "the words are not changed")
	local bad = toastProblems(r, t)
	eq(#bad, 0, "the text is cut or off its card:\n  " .. table.concat(bad, "\n  "))
	ok(t.text:GetHeight() <= t:GetHeight(), "the text fits inside the toast")
	T.clean(w)
end)

test("d3 toast fit: a long unbroken word is shown whole, the toast taller", function()
	local text = "No place called " .. string.rep("x", 60) .. "~"
	local w, r, t = toastWorld(text)
	ok(type(t) == "table", "the toast shows")
	eq(t.text:GetText(), text, "the characters are not changed")
	local bad = toastProblems(r, t)
	eq(#bad, 0, "the text is cut or off its card:\n  " .. table.concat(bad, "\n  "))
	T.clean(w)
end)

test("d3 toast fit: a short toast keeps its size; a word wider than the screen is the one case left as it is", function()
	local w, r, t = toastWorld("No place called Orgrimmar", "warn")
	eq(t:GetWidth(), 320, "a short message: the usual width")
	eq(t:GetHeight(), 56, "and the usual height")
	T.clean(w)
	local text = "No place called " .. string.rep("x", 400)
	local w2, r2, t2 = toastWorld(text, "warn")
	eq(t2.text:GetText(), text, "the characters are not changed")
	ok(t2:GetWidth() <= r2.env.UIParent:GetWidth(), "never wider than the screen")
	T.clean(w2)
end)

-- the phone open at the left of a narrow screen, room above it: the toast is centred on the phone, and must stay on the screen
local function phoneLeft(text)
	local untag = E.tag({ Wuber = H.ADDONS.Wuber })
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	r.W.db.coach = true
	H.state[r.env.UIParent].w = 1024
	r.W.UI.Toggle(true)
	w:advance(3)
	local wf = r.env.WuberFrame
	wf:ClearAllPoints()
	wf:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 20, -74) -- its top just under the room a toast needs above it
	w:advance(1)
	local t = r.W.UI.Toast(text, "warn")
	w:advance(1)
	untag()
	return w, r, t, wf
end

test("d3 toast fit: a wide toast beside an off-centre open phone stays wholly on the screen", function()
	local text = "No place called " .. string.rep("x", 60) .. "~"
	local w, r, t = phoneLeft(text)
	ok(type(t) == "table" and t:GetWidth() > 400, "the toast is wide: " .. tostring(t and t:GetWidth()))
	local box = H.rect(t)
	ok(box.l >= 12 - 0.5, "left edge on the screen with a margin: " .. box.l)
	ok(box.l + box.w <= 1024 - 12 + 0.5, "right edge on the screen with a margin: " .. (box.l + box.w))
	T.clean(w)
end)

test("d3 toast fit: a normal toast with the phone open is placed exactly as before (beside it, as on the unchanged code)", function()
	local w, r, t, wf = phoneLeft("No place called Orgrimmar")
	eq(t:GetWidth(), 320, "usual width")
	local box = H.rect(t)
	-- 618.2 is where the unchanged code puts it (the same setup, run on origin/main)
	ok(math.abs(box.l + box.w / 2 - 618.2) < 1, "centre at " .. (box.l + box.w / 2))
	T.clean(w)
end)
