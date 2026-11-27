local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local DRU, LEA, CAL = "Dru Oak", "Lea Dorn", T.CAL
local PLAIN = "Aaa Plain"
local RAIDSPOT = "Blackrock Mountain"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function raid()
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = RAIDSPOT, class = "WARRIOR" })
	w:addBot(PLAIN, { spot = RAIDSPOT, class = "WARLOCK" })
	local dru = w:addClient(DRU, { spot = RAIDSPOT, class = "DRUID" })
	local cal = w:addClient(CAL, { spot = RAIDSPOT, class = "WARLOCK" })
	local names = { LEA, DRU, CAL, PLAIN }
	for i = 1, 4 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	local DD = dru.W.Drive
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick(CAL, true))
	w:advance(1)
	cal.W.Drive.AnswerOffer(DRU, true)
	w:advance(3)
	ok(DD.AddPlainSummoner(PLAIN), "plain summoner added")
	ok(DD.SetOpen(true), "Start")
	w:advance(20)
	return w, dru, cal
end

test("r33 AUD-84: a losing summoner's channel start does not keep a plain summoner's dead claim alive past 40 s", function()
	local w, dru, cal = raid()
	local DD, CD = dru.W.Drive, cal.W.Drive
	ok(DD.RaidAdd("Raider Ra"), "Ra queued")
	ok(DD.RaidAdd("Raider Rb"), "Rb queued")
	w:advance(3)
	-- the runner asks the plain summoner in chat for both raiders: their claims (lower key than Cal)
	DD.Do("CAST", "Raider Ra", PLAIN)
	DD.Do("CAST", "Raider Rb", PLAIN)
	w:advance(1)
	local ra, rb = DD.raidRows[key("Raider Ra")], DD.raidRows[key("Raider Rb")]
	eq(ra.claimedBy, key(PLAIN), "Ra claimed by the plain summoner")
	-- Cal's window also begins Ra: loses the tie, but its immediate CH is still taken
	CD.Do("CAST", "Raider Ra")
	CD.Do("CH", "Raider Ra")
	w:advance(1)
	eq(ra.claimedBy, key(PLAIN), "the lower key still holds Ra")
	-- the plain summoner never casts; the claim has no channel
	w:advance(60)
	ra, rb = DD.raidRows[key("Raider Ra")], DD.raidRows[key("Raider Rb")]
	ok(rb and rb.state == "queued", "control: Rb (nobody channelled) is free again after 40 s: " .. tostring(rb and rb.state))
	ok(ra and ra.state == "queued", "Ra is free again after 40 s (state=" .. tostring(ra and ra.state) .. ")")
	T.clean(w)
end)
