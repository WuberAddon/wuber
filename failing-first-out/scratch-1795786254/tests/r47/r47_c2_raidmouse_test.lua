local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local NAMES = { "Dan Rider", "Gus Hill", "Ivy Moss", "Jo King", "Kim Lane", "Lou Park" }

test("r47 c2: after a folded raid queue with a cue, the Sell summons rider rows take no clicks", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Shards = function() return 10 end
	W.UI.WindowWide(false)
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	DR.SetMode("raid")
	w:advance(2)
	local realRole, realOpen, realRun = DR.Role, DR.IsOpen, DR.CanRunRaid
	DR.Role = function() return "driver" end
	DR.IsOpen = function() return true end
	DR.CanRunRaid = function() return true end
	local realQ, realNH = DR.RaidQueue, DR.NotHere
	DR.RaidQueue = function()
		local q = {}
		for i = 1, 6 do q[i] = { name = NAMES[i], asked = a.env.GetTime() - 10 * i, state = "queued", tries = 0 } end
		return q
	end
	DR.NotHere = function() return { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" }, "Hal Stone" } end
	W.Driver.RefreshNow()
	w:advance(1)
	local v = W.Driver.ui.console
	local faded = 0
	for i = 1, 6 do
		local r = v.rows[i]
		if H.visible(r) and r:GetAlpha() == 0 then faded = faded + 1 end
	end
	ok(faded > 0, "setup: the cue fades some raid rows (faded=" .. faded .. ")")
	-- back to selling: the raid stubs go, three riders ask
	DR.RaidQueue, DR.NotHere = realQ, realNH
	DR.SetMode("sell")
	DR.Role = function() return "driver" end
	DR.Sorted = function()
		local q = {}
		for i = 1, 6 do q[i] = { key = "k" .. i, name = NAMES[i], state = "asking", asked = a.env.GetTime() - 10 * i, ts = a.env.GetTime() - 10 * i } end
		return q
	end
	W.Driver.RefreshNow()
	w:advance(2)
	local shownRows, dead = 0, {}
	for i = 1, 6 do
		local r = v.rows[i]
		if H.visible(r) then
			shownRows = shownRows + 1
			if r:GetAlpha() > 0 and not r:IsMouseEnabled() then dead[#dead + 1] = i end
		end
	end
	ok(shownRows >= 2, "control: the Sell summons list shows rider rows (shown=" .. shownRows .. ")")
	eq(#dead, 0, "rider rows " .. table.concat(dead, ",") .. " are drawn but take no clicks and show no tooltip (mouse left off by the raid cue)")
	T.clean(w)
end)