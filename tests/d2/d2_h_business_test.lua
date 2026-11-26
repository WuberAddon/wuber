-- Design round 2, group H (item 11, the second half of audit 2.2): the Drive console has no icon bar of its own at
-- the bottom; Crew, Messages, Blocked, Earnings and Customers are one grouped list, "Your business", at the end
-- of the console's scrolling page, after the riders.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function plain(t) return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function console(o)
	o = o or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	if o.wide then
		a.wide = true
		W.db.coach = true
		W.UI.WindowWide(true)
	elseif W.UI and W.UI.WindowWide then
		W.UI.WindowWide(false)
	end
	if o.blocked then DR.BlockedList = function() return o.blocked end end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	if o.raid then
		DR.SetMode("raid")
		w:advance(1)
	end
	W.Driver.RefreshNow()
	w:advance(1)
	return w, a, W, DR
end

local function inside(frame, holder)
	local p = frame
	for _ = 1, 30 do
		if p == holder then return true end
		p = p and p.GetParent and p:GetParent()
		if not p then return false end
	end
	return false
end

local KINDS = { { name = "folded" }, { name = "unfolded", wide = true }, { name = "raid mode", raid = true }, { name = "raid mode unfolded", raid = true, wide = true } }

test("d2 h: the console has no icon bar at its bottom; its scrolling page ends at the body's bottom", function()
	for _, k in ipairs(KINDS) do
		local w, _, W = console(k)
		local v = W.Driver.ui.console
		eq(v.footer, nil, k.name .. ": no footer bar")
		ok(math.abs(v.scroll:GetBottom() - v:GetBottom()) < 0.5, k.name .. ": the scroll area ends at the body's bottom ("
			.. tostring(v.scroll:GetBottom()) .. " / " .. tostring(v:GetBottom()) .. ")")
		T.clean(w)
	end
end)

test("d2 h: five rows under 'Your business' in one card, inside the scroll area, each with icon, word and chevron", function()
	for _, k in ipairs(KINDS) do
		local w, a, W = console(k)
		local v = W.Driver.ui.console
		local g = v.business
		ok(type(g) == "table" and type(g.rows) == "table", k.name .. ": the list is a row group")
		eq(#g.rows, 5, k.name .. ": five rows")
		eq(plain(v.businessHead:GetText()), "Your business", k.name .. ": the heading")
		ok(v.businessHead:IsVisible(), k.name .. ": the heading shows")
		ok(inside(g, v.scroll.content), k.name .. ": the card is in the scrolling page")
		local words = {}
		for i, l in ipairs(v.links) do
			eq(l, g.rows[i], k.name .. ": link " .. i .. " is row " .. i .. " of the one card")
			eq(l.group, g, k.name .. ": the same card")
			ok(l.icon and l.chevron, k.name .. ": " .. l.what .. " has an icon and a chevron")
			ok(l:IsVisible(), k.name .. ": " .. l.what .. " shows")
			ok(l:GetHeight() >= 44, k.name .. ": " .. l.what .. " is a row (" .. l:GetHeight() .. " high)")
			ok(type(l.SetLabel) == "function" and l.dot and l.badge, k.name .. ": " .. l.what .. " keeps SetLabel, dot and badge")
			words[#words + 1] = l.what .. "=" .. l.titleText
		end
		eq(table.concat(words, " "), "crew=Crew messages=Messages blocked=Blocked earnings=Earnings customers=Customers", k.name .. ": the words")
		-- the heading sits above the card and the card's rows follow each other
		ok(v.businessHead:GetBottom() >= g:GetTop(), k.name .. ": the heading is above the card")
		for i = 2, 5 do ok(g.rows[i]:GetTop() <= g.rows[i - 1]:GetBottom() + 0.5, k.name .. ": row " .. i .. " under row " .. (i - 1)) end
		-- the page is as long as the list: its last row can be scrolled to
		local contentTop = v.scroll.content:GetTop()
		ok((v.scroll.content:GetHeight() or 0) >= contentTop - g:GetBottom(), k.name .. ": the page reaches the list's end")
		T.clean(w)
	end
end)

test("d2 h: the list comes after the riders, the crew and everything else on the page", function()
	for _, k in ipairs(KINDS) do
		local w, _, W = console(k)
		local v = W.Driver.ui.console
		local top = v.businessHead:GetTop()
		local seen = 0
		local function above(f, what)
			if type(f) == "table" and f.IsShown and f:IsShown() and f.GetBottom and f:GetBottom() then
				seen = seen + 1
				ok(f:GetBottom() >= top - 0.5, k.name .. ": " .. what .. " is above 'Your business'")
			end
		end
		for i, r in ipairs(v.rows or {}) do above(r, "rider row " .. i) end
		for i, c in ipairs(v.chips or {}) do above(c, "crew chip " .. i) end
		above(v.crewHead, "the crew heading")
		above(v.ready, "the ready card")
		above(v.more, "the more line")
		T.clean(w)
	end
end)

test("d2 h: each row opens what its link opened", function()
	for _, k in ipairs({ KINDS[1], KINDS[2] }) do
		local w, a, W = console(k)
		local v = W.Driver.ui.console
		local asked = {}
		W.Driver.ShowScreen = function(name) asked[#asked + 1] = tostring(name) end
		v.scroll:ScrollTo(100000, true)
		w:advance(1)
		for _, l in ipairs(v.links) do a:clickOn(l) end
		eq(table.concat(asked, " "), "crew messages blocked earnings customers", k.name .. ": the five pages")
		T.clean(w)
	end
end)

test("d2 h: the Messages dot until Messages was opened once; the Blocked count in the row's words and tooltip", function()
	local w, a, W = console({ blocked = { { name = "Ann" }, { name = "Ben" } } })
	local v = W.Driver.ui.console
	local m, b = v.links.messages, v.links.blocked
	w:advance(0.7)
	ok(m.glow and m.glow:IsShown(), "the dot shows on Messages")
	ok(m.glow:GetWidth() <= 10, "a small dot")
	ok(inside(m.glow, m) or m.glow:GetParent() == m.lead, "on the Messages row")
	eq(b.count, 2, "the count")
	eq(b.titleText, "Blocked (2)", "the row says Blocked (2)")
	local found = false
	for _, t in ipairs(a:visibleTexts()) do if plain(t) == "Blocked (2)" then found = true end end
	ok(found, "Blocked (2) is on the page")
	eq(#v.business.rows, 5, "still five rows")
	W.Driver.ShowScreen("messages")
	w:advance(1)
	W.UI.ShowDrive("console")
	w:advance(1)
	ok(not m.glow:IsShown(), "no dot once Messages was opened")
	T.clean(w)
end)

test("d2 h: a helper's list has no Messages and no Blocked row, and the card closes up", function()
	local w, _, W = console()
	local D = W.Driver
	local v = D.ui.console
	local full = v.business:GetHeight()
	D.Role = function() return "helper" end
	D.RefreshNow()
	w:advance(1)
	ok(not v.links.messages:IsShown() and not v.links.blocked:IsShown(), "Messages and Blocked are hidden")
	ok(v.links.crew:IsShown() and v.links.earnings:IsShown() and v.links.customers:IsShown(), "the other three show")
	ok(v.business:GetHeight() < full, "the card is shorter: " .. v.business:GetHeight() .. " / " .. full)
	T.clean(w)
end)

-- (H2) the page scrolls like every phone list: what comes next follows the riders, and the view's bottom edge may cut it
local function riders(open)
	local w, a, W, DR = console({})
	local t0 = (w.now and w.now()) or (a.W.Now and a.W.Now()) or 0
	local cs = {}
	if open then
		for i, n in ipairs({ "Dan Rider", "Eve Night", "Gus Hill" }) do
			cs[i] = { name = n, key = n:lower(), state = i == 1 and "lead" or "queued", at = t0 - 10 * i, wantsPrice = true }
		end
	end
	W.Char().wizard = true
	W.db.holdTip = true
	DR.SkipTarget = function() return cs[1], "cast" end
	DR.Active = function() return open end
	DR.RideCount = function(n) return n == "Dan Rider" and 2 or 0 end
	W.Driver.Today = function() return open and 16 or 0, open and 80000 or 0 end
	DR.Plan = function() return open and { marks = {}, type = "macro", macrotext = "/target Dan Rider\n/cast Ritual of Summoning", color = "go", title = "Summon Dan", sub = "click: targets and casts  -  12 shards" } or { marks = {}, color = "off", title = "Closed", sub = "tap Open to take riders" } end
	DR.Sorted = function() return cs end
	DR.customers = {}
	for _, c in ipairs(cs) do DR.customers[c.key] = c end
	DR.IsOpen = function() return open end
	W.Driver.RefreshNow()
	w:advance(2)
	return w, a, W
end

test("d2 h2: folded console, open with three riders and closed: the page goes on inside the view; scrolled to the end all five rows show", function()
	for _, open in ipairs({ true, false }) do
		local w, _, W = riders(open)
		local v = W.Driver.ui.console
		local name = open and "open" or "closed"
		local edge = v.scroll:GetBottom()
		ok(v.scroll:GetHeight() > 100, name .. ": the view has a height")
		local head = v.businessHead:GetTop()
		local crew = v.crewHead and v.crewHead:IsShown() and v.crewHead:GetTop() or nil
		ok(head > edge or (crew and crew > edge), name .. ": the heading of what follows the riders starts inside the view (heading top "
			.. tostring(head) .. ", view bottom " .. tostring(edge) .. ")")
		-- nothing is pushed below the edge: the heading starts where the page naturally goes on (16 under what is above)
		local lowest = 1e9
		local above = {}
		for _, f in pairs({ empty = v.empty, more = v.more, ready = v.ready, coach = v.coach, crewHead = v.crewHead, comm = v.comm, commHint = v.commHint }) do above[#above + 1] = f end
		for _, f in ipairs(v.rows or {}) do above[#above + 1] = f end
		for _, f in ipairs(v.chips or {}) do above[#above + 1] = f end
		for _, f in ipairs(above) do
			if type(f) == "table" and f.IsShown and f:IsShown() and f.GetBottom and f:GetBottom() and f:GetBottom() >= head - 0.5 and f:GetBottom() < lowest then lowest = f:GetBottom() end
		end
		ok(lowest < 1e9 and lowest - head <= 34, name .. ": nothing is pushed below the edge, the heading follows the riders at once (gap " .. tostring(lowest - head) .. ")")
		v.scroll:ScrollTo(100000, true)
		w:advance(1)
		for _, l in ipairs(v.links) do
			if l:IsShown() then
				ok(l:GetBottom() >= edge - 0.5 and l:GetTop() <= v.scroll:GetTop() + 0.5, name .. ": row " .. l.what .. " is inside the view when scrolled to the end")
			end
		end
		T.clean(w)
	end
end)
