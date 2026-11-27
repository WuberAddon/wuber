-- c2807 #4: the raid-mode "Open:" line and the "Raid summons:" line both say "at no charge", never "free".
local T = ...
local test = T.test
local H = T.H

local function printed(W)
	local out = {}
	W.Print = function(t) out[#out + 1] = tostring(t) end
	return out
end

test("c2807 #4 raid mode: the Open line says summoned at no charge and no raid line says free", function()
	local DRU, LEA, CAL = "Dru Oak", "Lea Dorn", T.CAL
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = "Blackrock Mountain", class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = "Blackrock Mountain", class = "DRUID" })
	local cal = w:addClient(CAL, { spot = "Blackrock Mountain", class = "WARLOCK" })
	local names = { LEA, DRU, CAL }
	for i = 1, 5 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	local DD = dru.W.Drive
	local out = printed(dru.W)
	DD.Command("raid")
	DD.Command("on")
	w:advance(3)
	local all = table.concat(out, "\n")
	assert(all:find("Open: raid summons. Raiders who say 123 in raid chat are summoned at no charge.", 1, true), "the Open line, in:\n" .. all)
	assert(all:find("Raid summons: raiders who say 123 in raid chat are summoned at no charge.", 1, true), "the Raid summons line, in:\n" .. all)
	assert(not all:lower():find("free", 1, true), "a raid line says free, in:\n" .. all)
end)
