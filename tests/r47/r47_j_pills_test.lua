local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok


local function open()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	T.openDrive(a)
	W.Driver.ShowSheet("sheet") w:advance(2)
	local s = W.UI.drive.screens.sheet
	s.mode = "choose" s.layout() w:advance(1)
	return w, a, s
end

-- the right edge of the right-most visible suggestion pill, and of the card, in screen pixels
local function edges(s)
	local pr, names = nil, {}
	for _, h in ipairs(s.hits) do
		if h:IsShown() then
			local r = H.rect(h)
			local right = r.l + r.w
			if not pr or right > pr then pr = right end
			names[#names + 1] = tostring(h.place)
		end
	end
	local c = H.rect(s.frame.card)
	return pr, c.l + c.w, table.concat(names, ", ")
end

test("r47 j: C59r-3: control: three short place matches fit inside the card", function()
	local w, a, s = open()
	a:type(s.search.edit, "o", false)
	local pill, card, names = edges(s)
	ok(pill and pill <= card, "control: pills (" .. names .. ") end at " .. tostring(pill) .. ", card at " .. tostring(card))
	T.clean(w)
end)

test("r47 j: C59r-3: typing 'ea' shows three place pills and the last one hangs out over the card's right edge", function()
	local w, a, s = open()
	a:type(s.search.edit, "ea", false)
	local pill, card, names = edges(s)
	ok(pill, "control: pills are shown")
	ok(pill <= card, "the pills (" .. names .. ") run to x=" .. string.format("%.0f", pill) .. " but the Price and place card ends at x=" ..
		string.format("%.0f", card) .. ": the last place name hangs outside the sheet")
	T.clean(w)
end)

local function open4() local w,a,s=open() return w,a,s,a.W.Theme end


-- what each shown pill's width should be if its label were measured at its normal size (the sheet's own formula)
local function check(s, Th)
	local bad, n = {}, 0
	for _, h in ipairs(s.hits) do
		if h:IsShown() then
			n = n + 1
			local want = math.min(150, math.floor(Th.MeasureText(h.place, h.label.wuberBase, h.label.wuberWeight) + 28))
			local got = math.floor(h:GetWidth())
			if got < want then bad[#bad + 1] = h.place .. " is " .. got .. " wide, its name needs " .. want .. " (label drawn at " .. tostring(h.label.wuberPx) .. " not " .. tostring(h.label.wuberBase) .. ")" end
		end
	end
	return n, bad
end

test("r47 j: C59r-4: control: a short place name gets a pill as wide as its name needs", function()
	local w, a, s, Th = open4()
	a:type(s.search.edit, "undercity", false)
	local n, bad = check(s, Th)
	ok(n >= 1, "control: a pill is shown")
	eq(#bad, 0, "control: " .. table.concat(bad, "; "))
	T.clean(w)
end)

test("r47 j: C59r-4: typing 'ea' gives long place names pills narrower than their text needs and the text is drawn smaller", function()
	local w, a, s, Th = open4()
	a:type(s.search.edit, "ea", false)
	local n, bad = check(s, Th)
	ok(n >= 2, "control: several pills are shown")
	ok(#bad == 0, "pills too narrow after fitting into the old 100 px width: " .. table.concat(bad, "; "))
	T.clean(w)
end)
