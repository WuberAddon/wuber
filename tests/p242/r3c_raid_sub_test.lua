-- r3 C: the raid card's lines are whole, and the "Not here (N) below" pill never lies over them (folded or not).
local T = ...
local test, H = T.test, T.H

local function page(open, runner, wide)
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
	DR.Role = function() return runner and "driver" or "rider" end
	DR.IsOpen = function() return open end
	DR.CanRunRaid = function() return runner end
	DR.RaidQueue = function() return {} end
	DR.NotHere = function() return { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" } } end
	W.Driver.RefreshNow()
	return w, a, W
end

local function meets(a, b)
	local at, ab, bt, bb = a:GetTop(), a:GetBottom(), b:GetTop(), b:GetBottom()
	return at and ab and bt and bb and ab < bt - 0.5 and bb < at - 0.5
end

for _, step in ipairs({ 1, 5 }) do
	for _, open in ipairs({ false, true }) do
		for _, runner in ipairs({ true }) do
			test("r3 C: folded empty raid card (open " .. tostring(open) .. ", runner " .. tostring(runner) .. ", step " .. step .. "): no pill over its words", function()
				local w, a, W = page(open, runner, false)
				for _ = 1, 6 do w:advance(step) end
				local R = W.Driver.ui.console.raid
				local e = R.empty
				T.ok(H.visible(e), "control: the empty card shows")
				for _, fs in ipairs({ e.text, e.sub }) do
					if H.visible(R.cue) then
						T.ok(not meets(R.cue, fs), "the pill lies over " .. tostring(fs.wuberText))
					end
				end
				T.clean(w)
			end)
		end
	end
end

-- guard: the same pill still comes up for queued raiders (unchanged path); the existing raid tests cover its rows
test("r3 C guard: the empty card scrolled clear of the strip lets the pill back", function()
	local w, a, W = page(false, true, false)
	local v = W.Driver.ui.console
	local R = v.raid
	T.ok(R.cueItems and R.cueItems.card, "the empty card is an item of the cue")
	-- scroll so the card is well above the strip: the pill then names Not here
	v.scroll:ScrollTo(v.scroll.max or 400)
	for _ = 1, 10 do w:advance(1) end
	local card = R.cueItems.card
	local edge = (v.scroll.offset or 0) + (v.scroll:GetHeight() or 0) + 1
	if card <= edge - 34 and R.cueItems.nh and R.cueItems.nh > edge - 34 then
		T.ok(H.visible(R.cue), "the pill shows once the card is above the strip")
	end
	T.clean(w)
end)

-- guard: the unfolded (wide) raid page has its own side list, no cue
test("r3 C guard: wide raid page: the empty card is whole", function()
	local w, a, W = page(false, true, true)
	for _ = 1, 3 do w:advance(1) end
	local R = W.Driver.ui.console.raid
	T.ok(R and (not R.cue or not H.visible(R.cue)), "no pill in the wide page")
	T.clean(w)
end)
