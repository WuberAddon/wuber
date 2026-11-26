-- Round 46 c: AUD-75 (the crew Warlock's lead line promised a hand-over that no longer exists) and HUNT-76 (the
-- empty Blocked screen said riders who leave without paying are blocked by themselves, also with that switch off).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA = T.ANITA

local function allText(f, out)
	out = out or {}
	if f.GetRegions then
		for _, r in ipairs({ f:GetRegions() }) do
			if r.GetText then local t = r:GetText() if t then out[#out + 1] = t end end
		end
	end
	if f.GetChildren then
		for _, ch in ipairs({ f:GetChildren() }) do allText(ch, out) end
	end
	return out
end
local function has(f, text)
	for _, t in ipairs(allText(f)) do if t:find(text, 1, true) then return true end end
	return false
end

local ON = "Shift-right-click a rider to block them. Riders who leave without paying are blocked by themselves."
local OFF = "Shift-right-click a rider to block them. Riders who leave without paying are not blocked by themselves: that switch is off in Settings."

test("r46 c: HUNT-76: the empty Blocked screen follows the autoBlock switch each time it shows", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA)
	T.settle(w)
	local W, D = d.W, d.W.Driver
	W.Drive.SetOpt("autoBlock", true)
	D.ShowScreen("blocked") w:advance(1)
	local s = W.UI.drive.screens.blocked
	ok(has(s.frame, ON), "switch on: today's sentence")
	W.Drive.SetOpt("autoBlock", false)
	D.ShowScreen("console") w:advance(1)
	D.ShowScreen("blocked") w:advance(1)
	ok(has(s.frame, OFF), "switch off: both sentences")
	ok(s.empty:GetHeight() >= 92 + (s.emptyNote.paraH or 0), "switch off: the card is tall enough for the text")
	ok(not has(s.frame, "are blocked by themselves"), "switch off: the old claim is gone")
	W.Drive.SetOpt("autoBlock", true)
	D.ShowScreen("console") w:advance(1)
	D.ShowScreen("blocked") w:advance(1)
	ok(has(s.frame, ON), "switch back on: today's sentence again")
	T.clean(w)
end)

test("r46 c: AUD-75: a crew Warlock under a trusted helper-leader is told to ask for the lead, not promised one", function()
	local ANA, MIA, SPOT = "Ana Smith", "Mia Stone", "Undercity"
	local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = { chars = { [key(ANA)] = {
		crew = { { name = MIA, role = "helper", app = true } }, captain = "", wizard = true } } } } })
	w:addClient(MIA, { spot = SPOT, class = "MAGE", saved = { Wuber = { chars = { [key(MIA)] = {
		crew = { { name = ANA, role = "lock", app = true } }, captain = ANA, wizard = true } } } } })
	w:group({ MIA, ANA })
	T.settle(w)
	local text
	for _, l in ipairs(ana.W.Drive.Readiness()) do
		if l.ok == false and l.text:find("leads the group", 1, true) then text = l.text end
	end
	eq(text, "Mia leads the group: only the leader can invite. Ask Mia to make you leader.")
	T.clean(w)
end)
