-- Tests of the floating mini console (UI.Driver.Mini, BRIEF18 item 2, test 3b). Loaded by tests/run.lua
-- with its helper table T. The row between the rows and the foot: Pause | shard gauge | Close must never
-- overlap for any label pair, any scale, folded or docked, and each pill's label must fit (no "...").
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local PAUSE = { "Pause", "Resume", "Warlocks pause" }
local CLOSE = { "Close", "Open", "Stop", "Start" }

local function rect(f)
	return { l = f:GetLeft(), r = f:GetRight(), t = f:GetTop(), b = f:GetBottom() }
end

local function apart(a, b)
	return a.r <= b.l + 0.01 or b.r <= a.l + 0.01 or a.t <= b.b + 0.01 or b.t <= a.b + 0.01
end

test("mini console: the shard gauge never overlaps Pause or Close, and both labels fit (3b)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR, D = a.W.Drive, a.W.Driver
	DR.Button = DR.Button or {}
	DR.Button.Floating = function() return true end
	DR.button = DR.button or a.env.WuberDriveButton
	ok(DR.button, "the big button")
	H.state[DR.button].shown = true
	local st = { paused = false, open = false, can = true, raid = false }
	local realPaused, realOpen, realCan = DR.IsPaused, DR.IsOpen, D.CanPause
	local realRaid = D.kit and D.kit.RaidMode
	DR.IsPaused = function() return st.paused end
	DR.IsOpen = function() return st.open end
	D.CanPause = function() return st.can end
	if D.kit then D.kit.RaidMode = function() return st.raid end end
	local combos, bad = 0, {}
	for _, scale in ipairs({ 0.8, 1, 1.5, 2 }) do
		-- 240 is the floor; 340 is the floating button's own width (Drive.Cast WIDTH), the only one
		-- the console takes in game (BRIEF20: 120 was under the floor, so no wider bar was drawn)
		for _, width in ipairs({ 40, 340 }) do
			for _, folded in ipairs({ false, true }) do
				DR.button:SetScale(scale)
				DR.button:SetWidth(width)
				for _, p in ipairs(PAUSE) do
					for _, c in ipairs(CLOSE) do
						st.can = p ~= "Warlocks pause"
						st.paused = p == "Resume"
						st.raid = c == "Stop" or c == "Start"
						st.open = c == "Close" or c == "Stop"
						DR.Button.docked = folded and nil
						-- (BRIEF20) repainted for each combination: without dirty the console keeps its last
						-- paint for a second, so this loop checked one label pair only
						local m0 = a.W.UI.drive.mini
						if m0 then m0.dirty = true end
						D.UpdateMini()
						local m = a.W.UI.drive.mini
						if m and m:IsShown() and m.fuel and not st.open then
							-- (BRIEF20 B5) closed or stopped: no Pause pill; gauge | Open (or Start)
							combos = combos + 1
							local tag = p .. "/" .. c .. " x" .. scale .. " w" .. width .. (folded and " folded" or "")
							local fr, cr, mr = rect(m.fuel), rect(m.close), rect(m)
							if m.pause:IsShown() then bad[#bad + 1] = tag .. ": a Pause pill while closed" end
							if not apart(fr, cr) or cr.l - fr.r < 8 then bad[#bad + 1] = tag .. ": gauge on the pill (" .. (cr.l - fr.r) .. ")" end
							if not (fr.l >= mr.l and cr.r <= mr.r) then bad[#bad + 1] = tag .. ": outside" end
							if m.close.label:IsTruncated() then bad[#bad + 1] = tag .. ": Close label cut" end
						elseif m and m:IsShown() and m.fuel then
							combos = combos + 1
							local tag = p .. "/" .. c .. " x" .. scale .. " w" .. width .. (folded and " folded" or "")
							if not m.pause:IsShown() then bad[#bad + 1] = tag .. ": no Pause pill while open" end
							local pr, fr, cr, mr = rect(m.pause), rect(m.fuel), rect(m.close), rect(m)
							if not (apart(pr, fr) and apart(fr, cr) and apart(pr, cr)) then bad[#bad + 1] = tag .. ": overlap" end
							if fr.l - pr.r < 8 or cr.l - fr.r < 8 then bad[#bad + 1] = tag .. ": gap under 8 (" .. (fr.l - pr.r) .. "/" .. (cr.l - fr.r) .. ")" end
							if not (fr.l >= mr.l and fr.r <= mr.r and pr.l >= mr.l and cr.r <= mr.r) then bad[#bad + 1] = tag .. ": outside" end
							-- (BRIEF20: the loop now repaints each pair) "Warlocks pause" needs the real width, not the floor
							if m.pause.label:IsTruncated() and (width >= 340 or p ~= "Warlocks pause") then bad[#bad + 1] = tag .. ": Pause label cut" end
							if m.close.label:IsTruncated() then bad[#bad + 1] = tag .. ": Close label cut" end
							-- (design 3, fix wave Q1) the pills are equal where both labels fit in equal pills; a label too long
							-- for that ("Warlocks pause"; "Resume" under the 240 floor) has the wider pill, so that the console
							-- keeps the button's width. The gauge is always in the middle of the room between the pills
							local long = p == "Warlocks pause" or (p == "Resume" and width < 340)
							if not long and math.abs(m.pause:GetWidth() - m.close:GetWidth()) > 0.5 then bad[#bad + 1] = tag .. ": pills unequal" end
							local mid = (fr.l + fr.r) / 2
							if math.abs(mid - (pr.r + cr.l) / 2) > 1 then bad[#bad + 1] = tag .. ": gauge off centre" end
							if not long and math.abs(mid - (mr.l + mr.r) / 2) > 1 then bad[#bad + 1] = tag .. ": gauge off the console's centre" end
							if width >= 340 and math.abs((mr.r - mr.l) - 340) > 0.01 then bad[#bad + 1] = tag .. ": wider than the button (" .. (mr.r - mr.l) .. ")" end
						end
					end
				end
			end
		end
	end
	DR.IsPaused, DR.IsOpen, D.CanPause = realPaused, realOpen, realCan
	if D.kit then D.kit.RaidMode = realRaid end
	ok(combos >= 48, "the console was drawn for the combinations: " .. combos)
	eq(#bad, 0, table.concat(bad, "; ", 1, math.min(#bad, 6)))
	T.clean(w)
end)

-- (BRIEF20 B5, shots 83 and 88) Closed (or raid summons stopped) the console's Pause pill did nothing
-- but still showed, dimmed, beside Open: it is hidden (a Hide, not a faded alpha the client may not
-- draw), and back as soon as the driver opens. The Open / Start pill takes its room, gauge first.
test("mini console BRIEF20 B5: no Pause pill while Closed or Stopped, back when open", function()
	local w = T.newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR, D = a.W.Drive, a.W.Driver
	DR.Button = DR.Button or {}
	local realFloating = DR.Button.Floating
	DR.Button.Floating = function() return true end
	DR.button = DR.button or a.env.WuberDriveButton
	H.state[DR.button].shown = true
	local open, raid = false, false
	local realOpen, realRaid = DR.IsOpen, D.kit and D.kit.RaidMode
	DR.IsOpen = function() return open end
	if D.kit then D.kit.RaidMode = function() return raid end end
	local function draw()
		local m = a.W.UI.drive.mini
		if m then m.dirty = true end
		D.UpdateMini()
		return a.W.UI.drive.mini
	end
	local m = draw()
	ok(m and m:IsVisible(), "the console shows")
	ok(not m.pause:IsShown(), "Closed: no Pause pill")
	ok(m.close:IsVisible(), "Closed: the Open pill")
	eq(m.close.label:GetText(), "Open", "it says Open")
	ok(m.fuel:IsVisible(), "the shard gauge stays")
	local fr, cr, mr = rect(m.fuel), rect(m.close), rect(m)
	ok(fr.l - mr.l < (mr.r - mr.l) / 4, "the gauge moves to the left, where Pause was")
	ok(cr.r - cr.l > (mr.r - mr.l) / 2, "Open takes the room")
	open = true
	m = draw()
	ok(m.pause:IsVisible(), "Open: the Pause pill is back")
	eq(m.close.label:GetText(), "Close", "Close")
	open, raid = false, true
	m = draw()
	ok(not m.pause:IsShown(), "raid summons stopped: no Pause pill")
	eq(m.close.label:GetText(), "Start", "Start")
	DR.IsOpen, DR.Button.Floating = realOpen, realFloating
	if D.kit then D.kit.RaidMode = realRaid end
	T.clean(w)
end)

-- (E1-11) When the floating button sits near the bottom of the screen, the mini console's
-- Pause/Close foot must stay on screen (>= 0) by showing only as many rows as fit above it.
test("mini console E1-11: Pause and Close stay on screen when room below the button is tight", function()
	local w = T.newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR, D = a.W.Drive, a.W.Driver
	DR.Button = DR.Button or {}
	local realFloating, realOpen, realMiniRows = DR.Button.Floating, DR.IsOpen, DR.Button.MiniRows
	local realSorted = DR.Sorted
	DR.Button.Floating = function() return true end
	DR.Button.MiniRows = function() return nil end
	DR.IsOpen = function() return true end
	DR.Sorted = function()
		return {
			{ key = "r1", name = "RiderOne", class = "MAGE", state = "waiting" },
			{ key = "r2", name = "RiderTwo", class = "PRIEST", state = "waiting" },
			{ key = "r3", name = "RiderThree", class = "ROGUE", state = "waiting" },
			{ key = "r4", name = "RiderFour", class = "WARRIOR", state = "waiting" },
		}
	end
	DR.button = DR.button or a.env.WuberDriveButton
	H.state[DR.button].shown = true
	DR.button:SetScale(1)
	DR.button:SetWidth(340)
	DR.button:ClearAllPoints()
	-- 150 px from bottom: console top at 146; 4 rows + foot would be 238 (> 146),
	-- while 1 row (48) + "+3 more" (16) + foot (38) + 8 top = 110 <= 146.
	DR.button:SetPoint("BOTTOMLEFT", a.env.UIParent, "BOTTOMLEFT", 40, 150)
	local m0 = a.W.UI.drive.mini
	if m0 then m0.dirty = true end
	D.UpdateMini()
	local m = a.W.UI.drive.mini
	ok(m and m:IsShown(), "mini console is shown")
	ok(m:GetBottom() >= -0.01, "console bottom stays on screen (" .. tostring(m:GetBottom()) .. ")")
	ok(m.pause:GetBottom() >= -0.01, "Pause pill stays on screen (" .. tostring(m.pause:GetBottom()) .. ")")
	ok(m.close:GetBottom() >= -0.01, "Close pill stays on screen (" .. tostring(m.close:GetBottom()) .. ")")
	ok(m.more:IsShown(), "+N more line is shown when rows are omitted")
	DR.Button.Floating, DR.IsOpen, DR.Button.MiniRows, DR.Sorted = realFloating, realOpen, realMiniRows, realSorted
	T.clean(w)
end)
