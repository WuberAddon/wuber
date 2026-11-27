-- tests/speed/text_refresh_test.lua (job 2749, speed): re-setting every label (T.RefreshText: the window's first opens,
-- the font arriving, the end of a page move) lays each list card (T.RowGroup) out ONCE with its final words, not once per
-- label it holds. Before: 40 drivers on Home made every open re-lay the card 2 x 40 times (about 150,000 SetPoint calls,
-- 1.8 s of Lua in the fake game).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local P = dofile(T.dir .. "/lib/screenprof.lua")(H)
local Scenes = dofile(T.dir .. "/speed/scenes.lua")

-- every shown Wuber text: its words and where it is drawn
local function snapshot(c)
	local out = {}
	for _, f in ipairs(c.widgets) do
		local s = H.state[f]
		if s and s.otype == "FontString" and H.visible(f) then
			local r = H.rect(f)
			out[#out + 1] = tostring(f:GetText()) .. "@" .. (r and ("%.1f,%.1f,%.1f,%.1f"):format(r.l, r.b, r.w, r.h) or "?")
		end
	end
	table.sort(out)
	return out
end

local function openOnHome()
	local w, c = Scenes.world(H)
	c.W.UI.Toggle(true)
	w:advance(2)
	return w, c
end

test("speed: re-setting every label (T.RefreshText) lays each list card out once: under 2,000 SetPoint calls and 10 MB with 40 drivers", function()
	local w, c = openOnHome()
	local sess = P.session(c)
	local m = sess:measure(function() c.W.Theme.RefreshText() end, { settle = 0 })
	sess:close()
	ok((m.calls.setPoint or 0) < 2000, ("T.RefreshText made %d SetPoint calls (budget 2,000; 50,602 before the fix)"):format(m.calls.setPoint or 0))
	ok(m.kb < 10000, ("T.RefreshText allocated %.0f KB (budget 10,000; 62,098 before the fix)"):format(m.kb))
	eq(#w.errors, 0, "no Lua error")
end)

test("speed: opening the window again (with its text refresh) stays under 5,000 SetPoint calls with 40 drivers", function()
	local w, c = openOnHome()
	c.W.UI.Toggle(false)
	w:advance(2)
	local sess = P.session(c)
	local m = sess:measure(function() c.W.UI.Toggle(true) end, { settle = 1 })
	sess:close()
	ok((m.calls.setPoint or 0) < 5000, ("the second open made %d SetPoint calls (budget 5,000; 152,119 before the fix)"):format(m.calls.setPoint or 0))
	eq(#w.errors, 0, "no Lua error")
end)

-- guard: the refresh must draw exactly what was there (same words, same places), only faster
test("speed: T.RefreshText leaves every shown text with the same words in the same place (Home with 40 drivers, Settings)", function()
	local w, c = openOnHome()
	w:advance(8) -- (the open's own delayed refresh and the list's settling are over)
	local before = snapshot(c)
	c.W.Theme.RefreshText()
	w:advance(0.2)
	local after = snapshot(c)
	eq(#after, #before, "as many shown texts")
	local diff = {}
	for i = 1, math.max(#before, #after) do if before[i] ~= after[i] then diff[#diff + 1] = tostring(before[i]) .. " -> " .. tostring(after[i]) if #diff >= 5 then break end end end
	eq(#diff, 0, "the same texts in the same places: " .. table.concat(diff, " | "))
	c.W.UI.OpenSettings()
	w:advance(8)
	local s0 = snapshot(c)
	c.W.Theme.RefreshText()
	w:advance(0.2)
	local s1 = snapshot(c)
	local d2 = 0
	for i = 1, math.max(#s0, #s1) do if s0[i] ~= s1[i] then d2 = d2 + 1 end end
	eq(d2, 0, "Settings: the same texts in the same places")
	eq(#w.errors, 0, "no Lua error")
end)
