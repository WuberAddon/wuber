-- Design round 3, group F1 (the fix wave): the mini console's foot (Pause | shards | Close) holds its words.
-- With the pill label at 12 "Resume" was cut under a narrow button (the console's 240 floor), and the 11 pt shard
-- words stood in a 12-high gauge. The console takes the width its foot needs; the gauge is 16 high.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function mini(shards)
	local w = T.newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR, D = a.W.Drive, a.W.Driver
	DR.Button = DR.Button or {}
	DR.Button.Floating = function() return true end
	DR.Button.docked = nil
	DR.button = DR.button or a.env.WuberDriveButton
	H.state[DR.button].shown = true
	D.FuelInfo = function() return shards, "accent", "tip", 1 end
	return w, a, DR, D
end

test("d3 f1 mini: Pause and Resume are whole at their own size under the narrowest button, the gauge between the pills", function()
	local w, a, DR, D = mini(12)
	local paused = false
	DR.IsOpen = function() return true end
	DR.IsPaused = function() return paused end
	D.CanPause = function() return true end
	for _, width in ipairs({ 40, 240, 340 }) do
		for _, p in ipairs({ false, true }) do
			paused = p
			DR.button:SetWidth(width)
			local m0 = a.W.UI.drive.mini
			if m0 then m0.dirty = true end
			D.UpdateMini()
			local m = a.W.UI.drive.mini
			local tag = (p and "Resume" or "Pause") .. " at " .. width
			ok(m and m:IsShown() and m.pause:IsShown(), "the console and its Pause pill: " .. tag)
			eq(m.pause.label:GetText(), p and "Resume" or "Pause", "the word: " .. tag)
			ok(not m.pause.label:IsTruncated(), "not cut: " .. tag)
			ok(H.truncation(m.pause.label) == nil, "drawn whole: " .. tag)
			eq(m.pause.label.wuberPx, a.W.Theme.SIZE.sub, "at the pill's own size, not shrunk: " .. tag)
			ok(not m.close.label:IsTruncated(), "Close not cut: " .. tag)
			-- (fix wave Q1) equal pills where both labels fit in them; "Resume" under the 240 floor has the wider pill
			if not (p and width < 340) then ok(math.abs(m.pause:GetWidth() - m.close:GetWidth()) <= 0.5, "equal pills: " .. tag) end
			ok(m.fuel:GetLeft() - m.pause:GetRight() >= 8 and m.close:GetLeft() - m.fuel:GetRight() >= 8, "8 clear each side of the gauge: " .. tag)
			ok(m.pause:GetLeft() >= m:GetLeft() and m.close:GetRight() <= m:GetRight(), "inside the console: " .. tag)
			if width == 340 then ok(math.abs(m:GetWidth() - 340) < 0.01, "under the real button the console keeps its width: " .. m:GetWidth()) end
		end
	end
	T.clean(w)
end)

test("d3 f1 mini: the shard gauge is as tall as its 11 pt words", function()
	local w, a, DR, D = mini(5)
	D.UpdateMini()
	local m = a.W.UI.drive.mini
	ok(m and m.fuel, "the gauge")
	eq(m.fuel.num.wuberText, "5 shards", "its words")
	eq(m.fuel.num.wuberPx, a.W.Theme.SIZE.caption, "the caption size")
	ok(m.fuel.num:GetStringHeight() <= m.fuel:GetHeight() + 0.01, "words " .. tostring(m.fuel.num:GetStringHeight()) .. " in a gauge " .. tostring(m.fuel:GetHeight()))
	T.clean(w)
end)
