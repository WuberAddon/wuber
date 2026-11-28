-- Tests of saved theme choice (missing, unknown, valid), live recolouring without /reload,
-- and clicking each theme choice in Settings through Client:clickOn.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function near(a, b)
	return math.abs((a or 0) - (b or 0)) < 0.002
end

local function sameRGB(r, g, b, col)
	return near(r, col[1]) and near(g, col[2]) and near(b, col[3])
end

test("themeswitcher: saved choice handles missing, unknown and valid values safely", function()
	-- Missing saved value -> classic
	local w = T.newWorld()
	local c1 = T.rider(w, T.ANA)
	T.settle(w)
	eq(c1.W.db.theme, "classic", "missing saved theme defaults to classic")
	eq(c1.W.Theme.ThemeId(), "classic", "ThemeId is classic")
	T.clean(w)

	-- Unknown saved value -> falls back to classic
	local w2 = T.newWorld()
	local c2 = T.rider(w2, T.ANA, { saved = { Wuber = { theme = "rainbow" } } })
	T.settle(w2)
	eq(c2.W.db.theme, "classic", "unknown saved theme falls back to classic in InitDB")
	eq(c2.W.Theme.ThemeId(), "classic", "ThemeId falls back to classic")
	eq(c2.W.Theme.ThemeId("nonexistent"), "classic", "ThemeId(unknown) returns classic")
	eq(c2.W.Theme.ThemeId(123), "classic", "ThemeId(number) returns classic")
	T.clean(w2)

	-- Valid saved value -> preserved and applied at login
	local w3 = T.newWorld()
	local c3 = T.rider(w3, T.ANA, { saved = { Wuber = { theme = "daylight" } } })
	T.settle(w3)
	eq(c3.W.db.theme, "daylight", "valid saved theme 'daylight' is preserved")
	eq(c3.W.Theme.ThemeId(), "daylight", "ThemeId is daylight at login")
	eq(c3.W.Theme.activeTheme, "daylight", "activeTheme is daylight at login")
	ok(sameRGB(c3.W.Theme.C.card[1], c3.W.Theme.C.card[2], c3.W.Theme.C.card[3], c3.W.Theme.THEMES.daylight.c.card),
		"T.C.card matches daylight at login")
	T.clean(w3)
end)

test("themeswitcher: live switching recolours existing widgets and backdrops without /reload", function()
	local w = T.newWorld()
	local c = T.rider(w, T.ANA)
	T.settle(w)
	local Th = c.W.Theme
	local env = c.env

	local holder = env.CreateFrame("Frame", nil, env.UIParent)
	local card = Th.Card(holder, 120, 40, { colour = "card" })
	local label = Th.Text(card, "body", "white", "LEFT", "medium")
	label:SetText("Sample")
	local custom = Th.Text(card, "body", "white", "LEFT", "medium")
	custom:SetText("Custom")
	custom:SetTextColor(0.12, 0.77, 0.33, 1) -- literal custom colour (not a token)
	local pill = Th.Pill(holder, "Go", "primary", 100, 32)
	local field = Th.Field(holder, 120, 28, { placeholder = "Type" })

	local events = {}
	c.W.Listen("THEME", function(id) events[#events + 1] = id end)

	-- Switch to daylight
	Th.SetTheme("daylight")
	eq(c.W.db.theme, "daylight", "saved to W.db.theme")
	eq(events[#events], "daylight", "THEME event fired")
	local r, g, b = label:GetTextColor()
	ok(sameRGB(r, g, b, Th.THEMES.daylight.c.white), "T.Text label recoloured to daylight white (dark ink)")
	local cr, cg, cb = custom:GetTextColor()
	ok(near(cr, 0.12) and near(cg, 0.77) and near(cb, 0.33), "literal custom RGB colour is preserved")
	local pr, pg, pb = pill.label:GetTextColor()
	ok(sameRGB(pr, pg, pb, Th.THEMES.daylight.c.ink), "T.Pill primary label recoloured to daylight ink")
	local fr, fg, fb = field.hint:GetTextColor()
	ok(sameRGB(fr, fg, fb, Th.THEMES.daylight.c.off), "T.Field placeholder text recoloured to daylight off")
	local wr, wg, wb = field.bg.parts[1]:GetVertexColor()
	ok(sameRGB(wr, wg, wb, Th.THEMES.daylight.c.well), "T.Field inset well recoloured to daylight well")
	ok(not c.W.UI.state.win.slices.left:IsShown(), "pre-baked winbg/screen art hidden on daylight")

	-- Switch back to classic
	Th.SetTheme("classic")
	local r2, g2, b2 = label:GetTextColor()
	ok(sameRGB(r2, g2, b2, Th.THEMES.classic.c.white), "T.Text label restored to classic white")
	ok(c.W.UI.state.win.slices.left:IsShown(), "pre-baked winbg/screen art restored on classic")

	T.clean(w)
end)

test("themeswitcher: clicking each theme choice in Settings via Client:clickOn switches live and saves", function()
	local w = T.newWorld()
	local c = T.rider(w, T.ANA)
	T.settle(w)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings("window")
	w:advance(1)

	local st = c.W.UI.settings
	local ctl = st.controls.theme
	ok(type(ctl) == "table" and type(ctl.buttons) == "table", "theme control exists in Settings")
	eq(#ctl.buttons, #c.W.Theme.THEME_ORDER, "one button per theme")

	-- Row tooltip documents non-live-recoloured elements
	ok(st.themeRow and st.themeRow.wuberTip, "Theme row has a tooltip")
	local tipBody = tostring(st.themeRow.wuberTip.text or st.themeRow.wuberTip[2] or "")
	ok(tipBody:find("bezel", 1, true) and tipBody:find("floating driver button", 1, true),
		"Theme tooltip notes pre-baked bezel art and floating driver button")

	-- Search finds Theme row
	local Find = c.W.Mod("UI.Settings.Find")
	local hits = Find.match("theme")
	local foundTheme = false
	for _, m in ipairs(hits or {}) do if m.label == "Theme" then foundTheme = true end end
	ok(foundTheme, "Settings search for 'theme' finds the Theme row")

	-- Click each choice through the topmost frame (Client:clickOn)
	for _, id in ipairs({ "daylight", "night", "fel", "classic" }) do
		local btn = ctl.byId[id]
		ok(btn ~= nil, id .. ": button exists")
		ok(btn.swatch and btn.swatch.bg and btn.swatch.card and btn.swatch.accent and btn.swatch.gold,
			id .. ": has live preview swatch")
		c:clickOn(btn)
		w:advance(0.2)
		eq(c.W.db.theme, id, id .. ": saved to WuberDB.theme after clickOn")
		eq(c.W.Theme.activeTheme, id, id .. ": activeTheme updated after clickOn")
		eq(ctl.value, id, id .. ": control value updated")
		ok(btn.chosen == true, id .. ": clicked button marked chosen")
		-- No text cut on any theme button
		for _, other in ipairs(ctl.buttons) do
			ok(other.label:IsTruncated() ~= true, id .. ": button label not truncated: " .. tostring(other.label:GetText()))
		end
	end

	T.clean(w)
end)
