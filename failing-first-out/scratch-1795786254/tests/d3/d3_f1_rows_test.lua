-- Design round 3, group F1 (the fix wave): a rider row's chips and its Options button never sit on each other.
-- With the caption at 11 the "Invite to Wuber" chip ran under the Options button where that sits on the row's
-- second line (the float_* shots). The chips flow onto another line and the row grows; the lists place the next
-- row by the row's height. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function rect(f)
	return { l = f:GetLeft(), r = f:GetRight(), t = f:GetTop(), b = f:GetBottom() }
end
local function apart(a, b)
	return a.r <= b.l + 0.01 or b.r <= a.l + 0.01 or a.t <= b.b + 0.01 or b.t <= a.b + 0.01
end
local function inside(a, b)
	return a.l >= b.l - 0.01 and a.r <= b.r + 0.01 and a.t <= b.t + 0.01 and a.b >= b.b - 0.01
end

local function driver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.Drive.GetAppState = function() return "ok" end
	W.Drive.RideCount = function() return 1 end
	return w, a, W
end

test("d3 f1 rows: the chips and the Options button never overlap at any width; the row grows for a third line", function()
	local w, a, W = driver()
	local D = W.Driver
	local parent = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	parent:SetSize(400, 300)
	parent:SetPoint("CENTER")
	parent:Show()
	local realStations = D.Stations
	local bad, grew = {}, 0
	for _, stations in ipairs({ false, true }) do
		D.Stations = stations and function() return { "Undercity", "Orgrimmar" } end or realStations
		for _, wdt in ipairs({ 340, 324, 284, 260, 240, 224 }) do
			for _, base in ipairs({ 44, 52 }) do
				for _, c in ipairs({
					{ name = "Gus Hill", state = "lead", source = "public", wantsPrice = true, at = 1000 },
					{ name = "Dan Rider", state = "joined", source = "whisper", at = 1000 },
					{ name = "Zep Ashrender", state = "lead", source = "public", msg = "Any summons to loch modan?", at = 1000 },
					{ name = "Eve Night", state = "arrived", source = "public", price = 5000, at = 1000 },
				}) do
					c.station = stations and "Undercity" or nil
					local r = D.Row(parent, wdt)
					r:SetHeight(base)
					r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
					for pass = 1, 2 do -- painted twice: a repaint keeps the height (the base is not counted twice)
						D.PaintRow(r, c, 1000)
						local tag = wdt .. "/" .. base .. (stations and " stations " or " ") .. c.name .. " pass " .. pass
						local rr, more = rect(r), rect(r.more)
						ok(r.getapp and r.getapp:IsShown(), "setup: the Invite chip shows at " .. tag)
						local chips = { r.getapp, r.again }
						if stations then chips[#chips + 1] = r.station end
						for i, chip in ipairs(chips) do
							local cr = rect(chip)
							if not apart(cr, more) then bad[#bad + 1] = tag .. ": chip " .. i .. " on Options" end
							if not inside(cr, rr) then bad[#bad + 1] = tag .. ": chip " .. i .. " outside the row" end
							if not apart(cr, rect(r.name)) then bad[#bad + 1] = tag .. ": chip " .. i .. " on the name" end
							for j = i + 1, #chips do
								if not apart(cr, rect(chips[j])) then bad[#bad + 1] = tag .. ": chips " .. i .. " and " .. j end
							end
						end
						if not inside(more, rr) then bad[#bad + 1] = tag .. ": Options outside the row" end
						if not inside(rect(r.disc), rr) then bad[#bad + 1] = tag .. ": the initial outside the row" end
						if r.more.label:IsTruncated() then bad[#bad + 1] = tag .. ": Options cut" end
						if r.getapp.label:GetText() ~= "Invite to Wuber" then bad[#bad + 1] = tag .. ": the chip's words" end
						local h = r:GetHeight()
						if h ~= base + (r.grown or 0) or (h - base) % 22 ~= 0 then bad[#bad + 1] = tag .. ": height " .. h end
						if pass == 2 and h > base then grew = grew + 1 end
					end
					-- the same row painted for a raider (no chips) is its base height again
					D.PaintRaidRow(r, { name = "Ivy Moss", asked = 990, state = "queued", tries = 0 }, 1000)
					if r:GetHeight() ~= base then bad[#bad + 1] = wdt .. ": a raid row keeps " .. r:GetHeight() end
					r:Hide()
				end
			end
		end
	end
	D.Stations = realStations
	eq(#bad, 0, table.concat(bad, "; ", 1, math.min(#bad, 6)))
	ok(grew > 0, "some rows grew a line for their chips")
	T.clean(w)
end)

test("d3 f1 rows: the mini console places each row under the one before, whatever its height", function()
	local w, a, W = driver()
	local DR, D = W.Drive, W.Driver
	DR.Button = DR.Button or {}
	DR.Button.Floating = function() return true end
	DR.Button.docked = nil
	DR.Button.MiniRows = nil
	DR.button = DR.button or a.env.WuberDriveButton
	H.state[DR.button].shown = true
	local list = {
		{ name = "Dan Rider", key = "dan rider", state = "joined", source = "whisper", at = 1000 },
		{ name = "Gus Hill", key = "gus hill", state = "lead", source = "public", wantsPrice = true, at = 1000 },
		{ name = "Eve Night", key = "eve night", state = "lead", source = "public", wantsPrice = true, at = 1000 },
	}
	DR.Sorted = function() return list end
	DR.customers = nil
	DR.button:SetWidth(300)
	D.UpdateMini()
	local m = W.UI.drive.mini
	ok(m and m:IsShown(), "the mini console")
	local mr = rect(m)
	local tall = 0
	for i = 1, 3 do
		local r = m.rows[i]
		ok(r:IsShown(), "row " .. i)
		ok(inside(rect(r), mr), "row " .. i .. " inside the console")
		if r:GetHeight() > 44 then tall = tall + 1 end
		ok(apart(rect(r.getapp), rect(r.more)), "row " .. i .. ": the Invite chip clear of Options")
		if i > 1 then
			local gap = m.rows[i - 1]:GetBottom() - r:GetTop()
			ok(math.abs(gap - 4) < 0.01, "row " .. i .. " starts 4 under row " .. (i - 1) .. " (gap " .. gap .. ")")
		end
	end
	ok(tall > 0, "setup: a row grew")
	ok(m.rows[3]:GetBottom() - m.pause:GetTop() >= 3.99, "Pause sits under the last row")
	-- room for two rows only (the button's place): a row that would pass it stays out
	DR.Button.MiniRows = function() return 2 end
	m.dirty = true
	D.UpdateMini()
	local used = m.rows[1]:GetTop() - m.pause:GetTop()
	ok(used <= 2 * 48 + 0.01 or not m.rows[2]:IsShown(), "the rows keep to the room of two (used " .. used .. ")")
	T.clean(w)
end)
