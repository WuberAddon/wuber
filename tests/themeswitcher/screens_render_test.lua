-- Tests that every Wuber screen (rider, driver, settings, help) renders cleanly under every theme
-- with zero Lua errors.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("themeswitcher: every rider, settings, help and driver screen renders under every theme without errors", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	local r = T.rider(w, T.ANA)
	T.settle(w)
	T.goOnline(d, w, { dest = "Orgrimmar", price = 50000 })
	w:advance(2)

	r.W.db.coach = true
	d.W.db.coach = true
	r.W.UI.Toggle(true)
	d.W.UI.Toggle(true)
	w:advance(3)

	local ThR = r.W.Theme
	local ThD = d.W.Theme

	for _, id in ipairs(ThR.THEME_ORDER) do
		local errBeforeR = #(r.W.errorLog or {})
		local errBeforeD = #(d.W.errorLog or {})

		ThR.SetTheme(id)
		ThD.SetTheme(id)
		w:advance(0.5)

		-- Rider screens: Home, Confirm, Trips, Settings (home + window section), Help
		r.W.UI.Show("home")
		w:advance(0.5)
		r.W.UI.Show("confirm", T.BOB)
		w:advance(0.5)
		r.W.UI.SelectTab("Trips")
		w:advance(0.5)
		r.W.UI.OpenSettings()
		w:advance(0.5)
		r.W.UI.OpenSettings("window")
		w:advance(0.5)
		r.W.UI.OpenHelp("settings")
		w:advance(0.5)
		r.W.UI.CloseHelp(true)
		r.W.UI.CloseSettings(true)
		r.W.UI.SelectTab("Ride")
		r.W.UI.Show("home")
		w:advance(0.5)

		-- Driver screens: Console + sub-screens
		T.openDrive(d, w)
		w:advance(0.5)
		for _, scr in ipairs({ "crew", "messages", "earnings", "customers", "demand" }) do
			if d.W.Driver and d.W.Driver.screens and d.W.Driver.screens[scr] then
				d.W.Driver.ShowScreen(scr)
				w:advance(0.2)
			end
		end
		d.W.Driver.ShowScreen("console")
		w:advance(0.2)

		eq(#(r.W.errorLog or {}), errBeforeR, id .. ": 0 rider Lua errors across all screens")
		eq(#(d.W.errorLog or {}), errBeforeD, id .. ": 0 driver Lua errors across all screens")
	end

	T.clean(w)
end)
