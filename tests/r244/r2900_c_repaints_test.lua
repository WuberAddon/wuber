-- tests/r244/r2900_c_repaints_test.lua (job 2900 group C, perf audit 26 Nov 2026 items 2 and 3): the scroll bar of a
-- list does its work when something changed, not on every frame. (The floating console half was dropped: a
-- repaint skipped on an unchanged signature left a stale Invite to Wuber pill, tests/r28/r28_o_why_test.lua:230.)
-- Nothing a player sees changes: the same bar and the same rows, painted when their inputs moved.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- the frame-by-frame bar follow of a T.EdgeFade list: how many times it measures its view in 60 idle frames
test("r2900 c: a scroll list that stands still does not measure its view again every frame", function()
	local w = T.newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(5)
	local Th = a.W.Theme
	local off, max = 0, 300
	local clip = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	clip:SetSize(200, 100)
	clip:SetPoint("CENTER")
	local reads = 0
	local fd = Th.EdgeFade(clip, { source = function() reads = reads + 1 return off, max end })
	local heights = 0
	local real = clip.GetHeight
	clip.GetHeight = function(self, ...) heights = heights + 1 return real(self, ...) end
	w:advance(1)
	heights = 0
	for _ = 1, 60 do w:advance(0.05) end
	ok(heights <= 20, "the view measured " .. heights .. " (source read " .. reads .. ")" .. " times in 60 idle frames (budget 20)")
	-- and the bar still follows a scroll the very next frame
	local before = fd.thumb:GetTop()
	off = 150
	w:advance(1 / 60)
	ok(math.abs((fd.thumb:GetTop() or 0) - (before or 0)) > 1, "the thumb moved with the scroll in the next frame")
	T.clean(w)
end)

-- the floating console: a repaint of its rows costs; with the same riders and words it is skipped
local function console()
	local w = T.newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR, D = a.W.Drive, a.W.Driver
	DR.Button = DR.Button or {}
	DR.Button.Floating = function() return true end
	DR.Button.docked = nil
	DR.Button.MiniRows = nil
	DR.button = DR.button or a.env.WuberDriveButton
	H.state[DR.button].shown = true
	DR.button:SetWidth(300)
	-- the world's own ticks put the button back as it likes: the stubs are set again before each update
	local function step(dt)
		w:advance(dt)
		DR.Button.Floating = function() return true end
		DR.Button.docked = nil
		H.state[DR.button].shown = true
		D.UpdateMini()
	end
	return w, a, DR, D, step
end

-- guard: the one-second timers of a row keep counting (the words change, so the row is painted)
test("r2900 c: a row's seconds still count up in the floating console", function()
	local w, a, DR, D, step = console()
	local t0 = a.env.GetTime()
	local list = { { name = "Dan Rider", key = "dan rider", state = "invited", source = "whisper", at = t0, invitedAt = t0 } }
	DR.Sorted = function() return list end
	D.UpdateMini()
	local m = a.W.UI.drive.mini
	local first = m.rows[1].right:GetText()
	step(5)
	step(1.2)
	ok(m.rows[1].right:GetText() ~= first, "shown " .. tostring(m:IsShown()) .. " now " .. a.env.GetTime() .. " t0 " .. t0 .. " desc " .. tostring(D.Describe(list[1])) .. " " .. tostring(select(2, D.Describe(list[1]))) .. " ticking " .. tostring(D.MiniTicking()) .. ";" .. "the timer moved from " .. tostring(first) .. " to " .. tostring(m.rows[1].right:GetText()))
	T.clean(w)
end)
