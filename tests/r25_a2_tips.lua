-- Round 25 follow-up (group A), changed in Design 2: the login tip is a sheet over Home's page, folded and unfolded, at
-- UI scales 0.64, 1 and 1.4, with drivers listed and with none. Home no longer gives way to it (the page behind
-- dims and the sheet takes the clicks), so the old "clear of every row and button" check became: Home is whole behind it.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local FAKE = {
	{ id = "fly_or_summon", text = "Fly or summon? Wuber shows what flying costs and how long, before you book. It also shows the cheaper way, and so on, and on.", driver = false, screen = "home" },
	{ id = "world_view", text = "Tap World to see every driver on the whole map.", driver = false, screen = "world" },
}

local function overlaps(a, b)
	return a.l < b.l + b.w - 0.5 and b.l < a.l + a.w - 0.5 and a.b < b.b + b.h - 0.5 and b.b < a.b + a.h - 0.5
end

local function setup(w, withDriver, sc, wide)
	if withDriver then
		local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
		d.W.Driver.SetOnline(true)
		w:advance(3)
	end
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	w:advance(2)
	local W = c.W
	local m = W.Mod("UI.TipTexts")
	m.list = FAKE
	m.Show = function() return true end
	W.db.scale = sc
	W.UI.Toggle(true)
	w:advance(5)
	if wide and not W.UI.Fold.IsUnfolded() then W.UI.Fold.Toggle() w:advance(2) end
	return c, W
end

-- every visible Wuber frame under Home, and the secure buttons, other than the card itself
local function others(c, W, card)
	local out = {}
	local home = W.Mod("UI.Window").screens.home
	local function add(f, what)
		if f and f.IsShown and H.visible(f) then out[#out + 1] = { f = f, what = what } end
	end
	for k, r in pairs(W.Mod("UI.Kit").ui.cards or {}) do add(r, "row " .. tostring(k)) end
	local e = home.empty
	if e then
		for _, k in ipairs({ "ping", "watch", "bountyGo", "why", "own", "title", "sub" }) do add(e[k], "empty " .. k) end
	end
	add(home.usualNote, "usual note")
	add(home.usual, "usual card")
	for name, f in pairs(c.env) do
		if type(name) == "string" and name:find("^Wuber") and type(f) == "table" and f ~= card and f.GetObjectType
			and (name:find("Button") or name:find("Secure") or name:find("Go") or name:find("Book")) then
			add(f, name)
		end
	end
	return out
end

test("r25 T1 follow-up: the tip sheet covers Home's page, which stays whole and dimmed behind it", function()
	for _, withDriver in ipairs({ false, true }) do
		for _, sc in ipairs({ 0.64, 1, 1.4 }) do
			for _, wide in ipairs({ false, true }) do
				local w = T.newWorld({ realm = H.FOUNDER_REALM })
				local c, W = setup(w, withDriver, sc, wide)
				local Mod = W.Mod("UI.Tips")
				local tag = (withDriver and " with drivers" or " with none") .. " at " .. sc .. (wide and " unfolded" or " folded")
				ok(Mod.ShowNow("fly_or_summon"), "card shows" .. tag)
				w:advance(1)
				local card = Mod.Card()
				ok(card and H.visible(card), "card visible" .. tag)
				eq(Mod.Up(), true, "Home told the card is up" .. tag)
				local rows = 0
				for _, r in pairs(W.Mod("UI.Kit").ui.cards or {}) do if H.visible(r) then rows = rows + 1 end end
				ok((rows > 0) == withDriver, "rows listed only when a driver is online (" .. rows .. ")" .. tag)
				ok(card.sheet.dim and card.sheet.dim:GetAlpha() > 0, "the page behind is dimmed" .. tag)
				ok(card.sheet:IsMouseEnabled(), "the sheet takes the clicks" .. tag)
				local e = W.Mod("UI.Window").screens.home.empty
				if not withDriver and e and e.ping then
					ok(H.visible(e.ping), "Home's empty state stays where it was (no give-way)" .. tag)
				end
				Mod.Hide()
				w:advance(1)
				eq(Mod.Up(), false, "card gone, Home told" .. tag)
				T.clean(w)
			end
		end
	end
end)

test("r25 T1 follow-up: no tip texts table, or a non-table, does not error", function()
	local w = T.newWorld()
	local c, W = setup(w, false, 1, false)
	local Mod = W.Mod("UI.Tips")
	local m = W.Mod("UI.TipTexts")
	m.Show = nil
	ok(Mod.ShowNow("fly_or_summon"), "card shows without Show")
	eq(Mod.ShowMe(), false, "Show me without a Show function is false")
	T.clean(w)
end)
