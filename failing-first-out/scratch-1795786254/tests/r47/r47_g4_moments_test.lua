local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H


test("r47 g4: a bounty served by a driver at a watched place gives two toasts for the one driver", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	W.db.watch[W.WatchKey("Ratchet")] = true
	eq(W.Bounty.Pin("Ratchet", 7500), true, "control: the bounty is pinned")
	w:advance(2)
	local toasts = {}
	local orig = W.UI.Toast
	W.UI.Toast = function(text, ...) toasts[#toasts + 1] = tostring(text) return orig(text, ...) end
	T.goOnline(d)
	for _ = 1, 40 do w:advance(0.5) end
	local about = {}
	for _, t in ipairs(toasts) do if t:find("Ratchet", 1, true) then about[#about + 1] = t end end
	ok(#about >= 1, "control: a toast about Ratchet shows: " .. table.concat(toasts, " | "))
	ok(#about == 1, "the player gets " .. #about .. " toasts for the one driver: " .. table.concat(about, " | "))
	T.clean(w)
end)


local function setup(openSettings)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { money = 100000 })
	T.settle(w)
	local UI = r.W.UI
	UI.Toggle(true) w:advance(3)
	if openSettings then UI.OpenSettings() w:advance(1) end
	UI.Celebrate("first", { "first" })
	w:advance(2)
	return w, r, UI
end

test("r47 g4: control: clicking the milestone card with Settings closed shows the Trips tab", function()
	local w, r, UI = setup(false)
	local f = r:findText("unlocked", nil, true)
	ok(#f > 0, "control: the milestone card shows: " .. T.list(r:visibleTexts()):sub(1, 150))
	r:clickOn(f[1]) w:advance(1)
	eq(UI.state.tab, "Trips", "control: the Trips tab is selected")
	eq(UI.state.settingsOpen == true, false, "control: no Settings")
	T.clean(w)
end)

test("r47 g4: with Settings open, clicking the milestone card leaves Settings covering the window", function()
	local w, r, UI = setup(true)
	ok(UI.state.settingsOpen == true, "control: Settings are open")
	local f = r:findText("unlocked", nil, true)
	ok(#f > 0, "control: the milestone card shows: " .. T.list(r:visibleTexts()):sub(1, 150))
	r:clickOn(f[1]) w:advance(1)
	ok(not UI.state.settingsOpen and #r:findText("Search settings", nil, true) == 0, "the player clicked the milestone card to see their trips but the Settings panel (Search settings box) is still open over the window (settingsOpen=" .. tostring(UI.state.settingsOpen) .. ")")
	T.clean(w)
end)
