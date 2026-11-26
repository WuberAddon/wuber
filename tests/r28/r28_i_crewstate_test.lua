local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, CAL = "Ana Smith", "Cal Brown"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function crewSaved(me, crewList, captain)
	return { chars = { [key(me)] = { crew = crewList, captain = captain or "", wizard = true } } }
end
local function build()
	local w = H.NewWorld({})
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = crewSaved(ANA, {
		{ name = CAL, role = "helper", app = true } }) } })
	local cal = w:addClient(CAL, { spot = "Orgrimmar", class = "MAGE", saved = { Wuber = crewSaved(CAL, {}, ANA) } })
	w:group({ ANA, CAL })
	w:advance(3)
	return w, ana, cal
end
-- Queue.lua's gift logging asks DR.Selling(), so a window that is not Selling logs no Wuber payment.
local function notOpen(cal, why)
	local D = cal.W.Drive
	ok(not D.IsOpen(), why .. ": not Open")
	ok(not D.Selling(), why .. ": not Selling (no gold gift is logged as a payment)")
	ok(not D.BellActive(), why .. ": bell off duty")
	eq(D.crewOpen, nil, why .. ": crewOpen forgotten")
	eq(D.crewStations, nil, why .. ": crewStations forgotten")
	eq(D.crewSummoners, nil, why .. ": crewSummoners forgotten")
end

test("r28 AUD-48: a helper who left the crew is not still open for business", function()
	local w, ana, cal = build()
	ok(ana.W.Drive.SetOpen(true), "captain opens")
	w:advance(5)
	eq(cal.W.Drive.IsOpen(), true, "control: the helper's window shows the crew open")
	cal.W.Drive.LeaveCrew()
	w:advance(2)
	eq(cal.W.Drive.Role(), nil, "no role after leaving")
	notOpen(cal, "left")
	T.clean(w)
end)

test("r28 AUD-48: a helper the captain removed is not still open for business", function()
	local w, ana, cal = build()
	ok(ana.W.Drive.SetOpen(true), "captain opens")
	w:advance(5)
	eq(cal.W.Drive.IsOpen(), true, "control: the helper's window shows the crew open")
	ana.W.Drive.RemoveCrew(CAL)
	w:advance(3)
	eq(cal.W.Drive.Role(), nil, "no role after removal")
	notOpen(cal, "removed")
	T.clean(w)
end)

test("r28 AUD-48: the captain's own Open switch is untouched by the crew clear", function()
	local w, ana = build()
	ok(ana.W.Drive.SetOpen(true), "captain opens")
	w:advance(5)
	eq(ana.W.Drive.IsOpen(), true, "captain open")
	ana.W.Drive.RemoveCrew(CAL)
	w:advance(3)
	eq(ana.W.Drive.IsOpen(), true, "captain still open after removing a helper")
	T.clean(w)
end)
