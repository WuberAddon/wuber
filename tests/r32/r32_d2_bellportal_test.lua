local T = ...
-- Round 32 group D wave 2 (AUD-108, Google C48b-2): with two open stations the portal call is rung
-- by the first helper at the casting station, not by a crew member standing at the other one.
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local BEA, CAL, WUB = "Bea Jones", "Cal Brown", "Wuber Rocks"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function press(c)
	local b = c.env.WuberDriveButton
	ok(b and H.visible(b), c.player.name .. ": big button not visible")
	return c:click(b)
end
local function bes(w, from)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.chatType == "WHISPER" and e.result == 0 and (not from or e.from == from) and (e.text or ""):match("^BE~") then
			out[#out + 1] = e.text:match("^BE~1~[^~]*~(.*)$")
		end
	end
	return out
end

local function scenario(ANA)
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = { chars = { [key(ANA)] = {
		crew = { { name = BEA, role = "lock", app = true }, { name = CAL, role = "helper", app = true } },
		captain = "", wizard = true, runner = true, summoners = { ANA, BEA } } } } } })
	local bea = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = { chars = { [key(BEA)] = {
		crew = { { name = ANA, role = "lock", app = true }, { name = CAL, role = "helper", app = true } }, captain = ANA, wizard = true } } } } })
	local cal = w:addClient(CAL, { spot = "Orgrimmar", class = "MAGE", saved = { Wuber = { chars = { [key(CAL)] = {
		crew = { { name = ANA, role = "lock", app = true }, { name = BEA, role = "lock", app = true } }, captain = ANA, wizard = true } } } } })
	local wub = w:addClient(WUB, { spot = "Orgrimmar", class = "MAGE" })
	w:addBot("Oda One", { spot = "Orgrimmar" })
	w:group({ ANA, BEA, CAL, "Oda One" })
	w:advance(20)
	for _, c in ipairs({ ana, bea, cal }) do c:slash("/wuber drive bell " .. WUB) end
	w:advance(3)
	ok(ana.W.Drive.SetOpen(true))
	w:advance(20)
	eq(ana.W.Drive.MultiStation(), true, "control: two stations are open")
	w:addBot("Dan Miller", { spot = "Thunder Bluff" })
	w:botWhisper("Dan Miller", ana, "summon to org pls")
	w:advance(8)
	local dan = bea.W.Drive.customers["dan miller"]
	ok(dan and dan.state == "joined", "control: Dan is queued: " .. tostring(dan and dan.state))
	press(bea)
	w:advance(3)
	ok(#bes(w, BEA) + #bes(w, CAL) + #bes(w, ANA) >= 1, "control: the bell rings for something while Bea summons: " .. table.concat(bes(w), " | "))
	local portal
	for _, t in ipairs(bes(w)) do if t:find("summoning portal", 1, true) then portal = t end end
	T.clean(w)
	return portal, table.concat(bes(w), " | ")
end

test("r32 d2: two stations: the alert character hears the portal call from the casting station", function()
	local p0 = scenario("Zed Smith") -- control: the Undercity Warlock sorts AFTER Cal, so Cal is the first helper
	ok(p0, "control: when the crew member at the other station sorts after Cal, the alert character hears the portal call")
	local portal, heard = scenario("Ana Smith")
	ok(portal, "Bea (Orgrimmar) is casting and Cal (helper, same station) should click the portal, but the alert character heard: [" .. heard .. "] - no portal call, because Ana (Undercity, never told) sorts first among the helpers")
end)
