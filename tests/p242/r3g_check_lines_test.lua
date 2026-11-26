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

local function press(w, W, ctx)
	W.UI.OpenSettings("window") w:advance(1)
	local st = W.UI.settings
	local b = st.controls.check
	ok(b, "control: the Check my game button exists")
	b:Click() w:advance(1.5)
	return st
end

local function sweep(st, wantLong)
	local seen
	for _, l in ipairs(st.results.lines or {}) do
		if l:IsShown() and l.text then
			local t = tostring(l.text:GetText() or "")
			local sw, w = l.text:GetStringWidth(), l.text:GetWidth()
			ok(not (l.text.IsTruncated and l.text:IsTruncated()), "line cut: " .. t)
			ok(not t:find("~", 1, true) and not t:find("...", 1, true), "line cut with dots: " .. t)
			-- the promise: a line is whole, so the row is as tall as the lines it takes
			ok(l:GetHeight() >= (l.text:GetStringHeight() or 0), "row " .. l:GetHeight() .. " high but its text needs " .. tostring(l.text:GetStringHeight()) .. ": " .. t)
			ok(l.text:GetNumLines() >= 1 and (sw <= w + 1 or l.text:GetNumLines() >= 2), "text " .. sw .. " wide in " .. w .. " neither fits nor wraps: " .. t)
			if t == wantLong then seen = l end
		end
	end
	return seen
end

-- the promise: every Check my game line wraps (never cut), whatever the leader's name
test("r3g: Check my game shows a long 'leads the group' line whole, wrapped in a taller row", function() withMetrics(function()
	for _, name in ipairs({ "Dan", "Danfieldlongnamed" }) do
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
		T.settle(w)
		local W = d.W
		local line = name .. " leads the group: only the leader can invite. Ask " .. name .. " to make you leader."
		local old = W.Drive.Readiness
		W.Drive.Readiness = function() return { { text = line, ok = false } } end
		local st = press(w, W)
		local l = sweep(st, line)
		ok(l, "the leads line is listed: " .. name)
		ok(l.text:GetStringHeight() <= l:GetHeight(), "the wrapped text lies inside its row")
		if #name > 5 then ok(l.text:GetNumLines() >= 2 and l:GetHeight() > 20, "control: the long name takes " .. l.text:GetNumLines() .. " lines in a " .. l:GetHeight() .. " row") end
		W.Drive.Readiness = old
		T.clean(w)
	end
end) end)

-- guard: a short line keeps the one-line row (20 high), unchanged by the fix
test("r3g guard: a short Check my game line keeps its one-line row", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	local st = press(w, W)
	local n = 0
	for _, l in ipairs(st.results.lines or {}) do
		if l:IsShown() and #tostring(l.text:GetText() or "") < 30 then n = n + 1; ok(l:GetHeight() == 20, "short row is 20, got " .. l:GetHeight()) end
	end
	ok(n > 0, "control: some short lines are shown")
	T.clean(w)
end)
