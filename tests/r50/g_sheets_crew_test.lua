-- r50 group G: shift card share tip in a fight (H24-15), full-crew Add anyway (AU24-21)
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function shiftWorld()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	w:addBot("Vex Shade", { spot = "Orgrimmar" })
	w:group({ T.ANITA, "Vex Shade" })
	w:advance(1)
	W.Driver.lastShift = { rides = 5, copper = 20000, tips = 0, open = 3600, crewRides = 2, crewCopper = 10000, at = 1,
		cut = { rows = {
			{ key = W.myKey, name = T.ANITA, casts = 3, clicks = 0, share = 18000 },
			{ key = "vex shade", name = "Vex Shade", casts = 0, clicks = 2, share = 12000 },
		}, rule = "clicks", pct = 40 } }
	W.Driver.ShowSheet("shift")
	w:advance(1)
	return w, a, W.UI.drive.screens.shift.split.post
end
local function tipOf(p)
	local t = p.wuberTip.text
	if type(t) == "function" then t = t() end
	return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- the promise: the tip says only what the click does now (in a fight: posts after it; out of it: once, on the click)
test("r50 G: the share pill tip says it posts after the fight, then reads as before", function()
	local w, a, p = shiftWorld()
	eq(tipOf(p):find("Posts the split in party chat (raid chat in a raid), once, on your click.", 1, true) ~= nil, true, "out of combat: old wording")
	w:enterCombat(a) w:advance(1)
	eq(tostring(p.label:GetText()), "Share after combat", "the pill waits")
	ok(tipOf(p):find("fight", 1, true), "in combat: " .. tipOf(p):sub(1, 80))
	w:leaveCombat(a) w:advance(1)
	ok(tipOf(p):find("Posts the split", 1, true) and not tipOf(p):find("fight", 1, true), "after the fight: old wording again")
	T.clean(w)
end)

-- guard: a crew with room still toasts the add
test("r50 G: Add anyway with room in the crew still toasts that the helper was added", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	local extra = "Ninth Guy"
	w:addBot(extra, { spot = "Undercity", class = "WARRIOR" })
	w:group({ T.ANITA, extra })
	w:advance(15)
	local W = a.W
	T.openDrive(a)
	local key = W.Key(extra)
	W.Drive.offers[key] = { name = extra, at = a.env.GetTime(), state = "noapp" }
	local seen = {}
	local orig = W.UI.Toast
	W.UI.Toast = function(text, kind, f) seen[#seen + 1] = tostring(text) return orig(text, kind, f) end
	W.Driver.ShowScreen("crew")
	w:advance(1)
	local s = W.Mod("UI.Driver.Screens").st.screens.crew
	s.update()
	local row
	for i = 1, 12 do
		local r = s.others.get(i)
		if r and H.visible(r) and r.person and W.Key(r.person.name) == key then row = r break end
	end
	ok(row and row.anyway, "Add anyway shows")
	a:clickOn(row.btn)
	w:advance(1)
	local said
	for _, t in ipairs(seen) do if t:find("added as a helper", 1, true) then said = t end end
	ok(said, "toast says added")
	ok(W.Drive.CrewEntry(key), "and he is in the crew")
	T.clean(w)
end)
