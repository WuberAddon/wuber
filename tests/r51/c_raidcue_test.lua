-- r51 C (RUN1-6): the raid page's "more below" cue never covers a raider's name or a "Your business" row title (Crew, Customers).
local T = ...
local test, H = T.test, T.H

local function page(nq, wide)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Shards = function() return 10 end
	if wide then a.wide = true W.db.coach = true W.UI.WindowWide(true) elseif W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	W.Drive.SetMode("raid")
	w:advance(2)
	local q = {}
	for i = 1, nq do q[i] = { name = "Raider" .. i .. "-Realm", class = "MAGE", zone = "Orgrimmar", t = 1 } end
	DR.Role = function() return "driver" end
	DR.IsOpen = function() return true end
	DR.CanRunRaid = function() return true end
	DR.RaidQueue = function() return q end
	DR.NotHere = function() return { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" } } end
	W.Driver.RefreshNow()
	return w, a, W
end

local function meets(a, b)
	local at, ab, bt, bb = a:GetTop(), a:GetBottom(), b:GetTop(), b:GetBottom()
	return at and ab and bt and bb and ab < bt - 0.5 and bb < at - 0.5
end

for _, nq in ipairs({ 0, 1, 2, 3, 4, 5, 6 }) do
	for _, step in ipairs({ 1, 5 }) do
		-- guard: sweep found no cover on the base (RUN1-6 not reproduced in the fake)
		test("r51 C: raid page, " .. nq .. " raiders, step " .. step .. ": the cue covers no name or business title at any scroll", function()
			local w, a, W = page(nq, false)
			local v = W.Driver.ui.console
			local R = v.raid
			local seen = 0
			local max = v.scroll.max or v.scroll.maxScroll or 400
			for pos = 0, max + 40, 20 do
				v.scroll:ScrollTo(pos)
				for _ = 1, 8 do w:advance(step) end
				if R.cue and H.visible(R.cue) then
					seen = seen + 1
					for i, r in ipairs(v.rows) do
						if H.visible(r) and r:GetAlpha() > 0 and r.name then
							T.ok(not meets(R.cue, r.name), "cue over raider row " .. i .. " at scroll " .. pos)
						end
					end
					for k, l in pairs(v.links or {}) do
						if type(k) == "string" and H.visible(l) then
							T.ok(not meets(R.cue, l), "cue over business row " .. k .. " at scroll " .. pos)
						end
					end
					for _, h in ipairs({ v.businessHead, v.crewHead }) do
						if h and H.visible(h) then T.ok(not meets(R.cue, h), "cue over a section title at scroll " .. pos) end
					end
				end
			end
			if nq >= 3 then T.ok(seen > 0, "control: the cue showed at some scroll position (" .. nq .. " raiders)") end
			T.clean(w)
		end)
	end
end

-- guard: the cue still scrolls to the hidden rows on a tap (unchanged neighbouring path)
test("r51 C guard: a tap on the cue scrolls down", function()
	local w, a, W = page(6, false)
	local v = W.Driver.ui.console
	local R = v.raid
	v.scroll:ScrollTo(0)
	for _ = 1, 8 do w:advance(1) end
	if H.visible(R.cue) then
		local before = v.scroll.offset or 0
		R.cue:GetScript("OnClick")(R.cue)
		for _ = 1, 20 do w:advance(0.1) end
		T.ok((v.scroll.offset or 0) > before, "the page scrolled")
	end
	T.clean(w)
end)
