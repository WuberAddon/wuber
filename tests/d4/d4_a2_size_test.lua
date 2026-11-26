-- Design round 4, group A2: the live ride page draws the portal LARGE (the room the hidden tab bar left), never under the
-- dark header bar, the headline under it, everything below in the same order; as large as fits, from the room.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup(opts)
	opts = opts or {}
	local w = T.newWorld()
	local r = T.rider(w, opts.who or T.TESTCHAR, { screenW = opts.sw or 1024, screenH = opts.sh or 768 })
	w:advance(15)
	r.W.db.coach = true
	if opts.simple then r.W.Advanced = function() return false end end
	if opts.founder then r.W.FounderSummon = function() return true end end
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state, r.W.UI
end

local function ride(r, w, t)
	local base = { id = "d4a2", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = "accepted",
		at = r.env.GetTime(), service = "Bea's Rides" }
	for k, v in pairs(t or {}) do base[k] = v end
	r.W.ride = base
	r.W.Fire("RIDE")
	r.W.UI.Show("found")
	r.W.UI.RefreshNow()
	w:advance(3)
end

-- every live box in the page's own units (y up from the page's foot), nil when not shown
local function boxes(r, ui)
	local s = ui.screens.found
	local f = s.frame
	local pr = H.rect(f)
	local k = pr.w / f:GetWidth()
	local out = {}
	local function add(name, obj, force)
		local shown = force
		if shown == nil then shown = H.visible(obj) end
		if not shown then return end
		local o = H.rect(obj)
		out[name] = { l = (o.l - pr.l) / k, b = (o.b - pr.b) / k, w = o.w / k, h = o.h / k }
		out[name].t = out[name].b + out[name].h
		out[name].r = out[name].l + out[name].w
	end
	add("art", s.hero.art, s.hero.art:IsShown() and s.hero:IsShown())
	add("title", s.title)
	add("sub", s.sub)
	add("prog", s.prog)
	add("card", s.card)
	add("queue", s.queue)
	add("tip", s.tip)
	add("kitchen", s.kitchen)
	add("alert", s.alert)
	add("pass", s.pass)
	add("cancel", s.cancel)
	add("action", s.action)
	add("bar", s.bar)
	if out.prog then out.prog.h = 42 out.prog.b = out.prog.t - 42 end -- its dots and labels; the frame's lower edge is slack
	out.page = { t = pr.h / k }
	return out
end

local function dump(b)
	local keys = {}
	for key in pairs(b) do keys[#keys + 1] = key end
	table.sort(keys)
	local t = {}
	for _, key in ipairs(keys) do
		local v = b[key]
		t[#t + 1] = string.format("%s t%.0f b%.0f", key, v.t or 0, v.b or 0)
	end
	return table.concat(t, " | ")
end

-- the live states: name, the ride's fields, and CROWDED when the amber card, the queue line and more fill the page so that
-- even the picture's wanted minimum cannot fit without overlap (the largest that fits is drawn)
local STATES = {
	{ "accepted", { state = "accepted" } },
	{ "accepted, queue line", { state = "accepted", position = 2, eta = 50 } },
	{ "invited, a long driver's name", { state = "invited", driver = "Bartholomewlongname", driverKey = "bartholomewlongname" } },
	{ "ingroup (no second line)", { state = "ingroup" } },
	{ "ingroup, pass phrase", { state = "ingroup", showPass = true } },
	{ "summoning, a long place", { state = "summoning", dest = "Feathermoon Stronghold" } },
	{ "portal", { state = "portal" } },
	{ "tracker", { state = "summoning", ritual = { phase = "h", tapped = 1, need = 2 } } },
	{ "pvp card", { state = "accepted", ritual = { danger = 3 } } },
	{ "pvp card, queue line", { state = "accepted", position = 2, eta = 50, ritual = { danger = 3 }, crowded = true } },
	{ "pvp card, queue line, pass phrase", { state = "ingroup", position = 2, eta = 50, showPass = true, ritual = { danger = 3 }, crowded = true } },
}
local NAMES = { "art", "title", "sub", "prog", "card", "queue", "tip", "kitchen", "alert", "pass", "cancel", "action" }

-- every check of one live state; label says where we are
local function checkState(r, w, ui, label, spec)
	local s = ui.screens.found
	local b = boxes(r, ui)
	local P = s.portalPx
	ok(b.art, label .. ": the portal picture shows")
	if not b.art then return end
	ok(math.abs(b.art.w - P) < 0.6 and math.abs(b.art.h - P) < 0.6, label .. ": the picture is a square of " .. P .. ", got " .. b.art.w .. " x " .. b.art.h)
	ok(math.abs(b.art.l + b.art.w / 2 - (b.bar.l + b.bar.w / 2)) < 0.6, label .. ": centred")
	ok(b.art.t <= b.bar.b - 7.4, label .. ": its top is 8 under the dark header bar (art " .. b.art.t .. ", bar " .. b.bar.b .. ")")
	ok(b.title.t <= b.art.b - 7.4, label .. ": the headline is 8 under it (title " .. b.title.t .. ", art " .. b.art.b .. ")")
	-- (lead) 104 and 56, not 120 and 72: the picture starts 16 lower so the rider's "you" dot shows above it (nothing is hidden)
	ok(P >= (spec.crowded and 56 or 104), label .. ": the size " .. P .. " is at least " .. (spec.crowded and 56 or 104))
	ok(P <= 200, label .. ": at most 200")
	-- no box touches another
	for i = 1, #NAMES do
		for j = i + 1, #NAMES do
			local x, y = b[NAMES[i]], b[NAMES[j]]
			if x and y then
				local apart = (NAMES[i] == "title" and NAMES[j] == "sub") -- the two line boxes meet by design (the lines never touch)
					or x.b >= y.t - 0.3 or y.b >= x.t - 0.3 or x.l >= y.r - 0.3 or y.l >= x.r - 0.3
				ok(apart, label .. ": " .. NAMES[i] .. " and " .. NAMES[j] .. " overlap (" .. dump({ [NAMES[i]] = x, [NAMES[j]] = y }) .. ")")
			end
		end
	end
	-- everything stays above the link, and the picture is as large as the room allows
	local low = math.huge
	for _, nm in ipairs({ "card", "queue", "tip", "kitchen", "alert", "pass" }) do
		if b[nm] then low = math.min(low, b[nm].b) end
	end
	ok(low >= b.cancel.t - 0.3 + 0, label .. ": the lowest card (" .. low .. ") is above the link (" .. b.cancel.t .. ")")
	ok(P == 200 or low - b.cancel.t < 10, label .. ": as large as fits: " .. P .. ", the slack above the link is " .. (low - b.cancel.t))
	return P
end

local function run(label, opts, fold)
	local w, r, ui = setup(opts)
	if fold then ui.screens.found.frame:GetWidth() end
	local sizes = {}
	for _, st in ipairs(STATES) do
		ride(r, w, st[2])
		sizes[st[1]] = checkState(r, w, ui, label .. ", " .. st[1], st[2])
	end
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
	return sizes
end

test("d4 a2: the live ride page draws the portal large, clear of the header, the headline under it, nothing touching (every state)", function()
	local sizes = run("violet")
	ok(sizes["portal"] >= 180, "with the room the portal is drawn at 180 or more: " .. tostring(sizes["portal"]))
	-- (lead) 134, not 150: the picture starts 16 lower, under the rider's "you" dot
	ok(sizes["tracker"] >= 134 and sizes["accepted, queue line"] >= 134, "with a line and the driver card: 134 or more: " .. tostring(sizes["tracker"]) .. ", " .. tostring(sizes["accepted, queue line"]))
end)

test("d4 a2: the same for a founder's gold summon", function()
	run("founder", { founder = true })
end)

test("d4 a2: and in Simple mode", function()
	run("simple", { simple = true })
end)

test("d4 a2: the size follows the room: a fuller page gets a smaller picture, never a typed number per state", function()
	local w, r, ui = setup()
	local s = ui.screens.found
	ride(r, w, { state = "portal" })
	local roomy = s.portalPx
	ride(r, w, { state = "accepted", position = 2, eta = 50, ritual = { danger = 3 } })
	local full = s.portalPx
	ok(roomy > full + 40, "portal " .. roomy .. " against the warning with a queue line " .. full)
	ride(r, w, { state = "portal" })
	eq(s.portalPx, roomy, "and back to the same size when the page empties again")
	T.clean(w)
end)

test("d4 a2: the unfolded window's ride page keeps the same rule", function()
	-- the ride page (UI.Fold.Page() is nil for it) is one pane, the phone's size, whether the window is unfolded or not
	local w, r, ui, UI = setup({ sw = 3840, sh = 2160 })
	UI.Fold.IsUnfolded = function() return true end
	UI.Show("home")
	w:advance(1)
	for _, st in ipairs(STATES) do
		ride(r, w, st[2])
		checkState(r, w, ui, "unfolded, " .. st[1], st[2])
	end
	T.clean(w)
end)

test("d4 a2: the turn is group A's: still the same 8 s anticlockwise spin on the larger picture", function()
	local w, r, ui = setup()
	ride(r, w, { state = "portal" })
	local art = ui.screens.found.hero.art
	local a0 = art:GetRotation() or 0
	w:advance(2)
	ok(math.abs(((art:GetRotation() or 0) - a0 - math.pi / 2 + math.pi) % (2 * math.pi) - math.pi) < 0.1, "a quarter turn in 2 s")
	T.clean(w)
end)
