-- r53 B: "You're already in <city>" says what to do. Promise: when the request is blocked because the rider
-- already stands in the driver's place, the confirm page shows the disabled pill AND one visible line saying
-- where this driver goes and to pick another. No line when the request is not blocked for that reason.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local KEY = "mia runner"
local function setup(opts, over)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, opts)
	w:advance(15)
	local d = { name = "Mia Runner", key = KEY, dest = "Orgrimmar", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" }
	for k, v in pairs(over or {}) do d[k] = v end
	r.W.drivers = r.W.drivers or {}
	r.W.drivers[d.key] = d
	w:addBot(d.name)
	return w, r, d
end
local function open(w, r)
	T.openConfirm(r, KEY)
	w:advance(1)
	return r.W.UI.state.screens.confirm
end
local function has(r, text) return #r:findText(text, nil, true) > 0 end
local LINE = "This driver summons to Orgrimmar, where you are now. Go back and pick a driver going somewhere else."

for _, v in ipairs({
	{ "folded Advanced", {} },
	{ "folded Simple", { simple = true } },
	{ "wide Advanced", { screenW = 1920, screenH = 1080 } },
	{ "wide Simple", { screenW = 1920, screenH = 1080, simple = true } },
}) do
	test("r53 B: already in the driver's place, " .. v[1] .. ": the pill stays and a line says what to do", function()
		local o = { spot = "Orgrimmar" }
		for k, x in pairs(v[2]) do o[k] = x end
		local w, r = setup(o)
		local s = open(w, r)
		ok(has(r, "You're already in Orgrimmar."), "the pill keeps its words")
		ok(has(r, LINE), "the what-to-do line shows: " .. T.list(r:visibleTexts()):sub(1, 500))
		ok(H.visible(s.warn), "the line's frame is visible")
		T.clean(w)
	end)
end

test("r53 B: a longest place name still shows the line", function()
	local w, r = setup({ spot = "Thunder Bluff" }, { dest = "Thunder Bluff" })
	open(w, r)
	ok(has(r, "This driver summons to Thunder Bluff, where you are now."), "line with the long place")
	T.clean(w)
end)

-- guard: another driver, not where the rider stands, gets no such line (the line has a job only when blocked as "here")
test("r53 B: a driver elsewhere gets no what-to-do line", function()
	local w, r = setup({ spot = "Orgrimmar" }, { dest = "Undercity" })
	open(w, r)
	ok(not has(r, "where you are now"), "no line")
	ok(has(r, "Request summon"), "the pill is the normal one")
	T.clean(w)
end)

-- guard: the group block keeps its own words and Leave group pill
test("r53 B: a grouped rider still sees the group warning, not the here line", function()
	local w, r = setup({ spot = "Orgrimmar" }, { dest = "Undercity" })
	w:addBot("Bob Other")
	w:group({ T.TESTCHAR, "Bob Other" })
	w:advance(1)
	open(w, r)
	r.W.UI.RefreshNow() w:advance(0.5)
	ok(not has(r, "where you are now"), "no here line")
	ok(has(r, "You're in a group. Leave it so the driver can invite you."), "the group warning")
	T.clean(w)
end)
