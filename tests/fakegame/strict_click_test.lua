-- A direct Client:click is strict (job 2790, the #36 lesson): the test may only click a frame that a player's mouse reaches at its
-- centre (Client:topAt). Covered, clipped out (scrolled away) or off screen fails the test, and the frame's click scripts do not run.
-- A frame with no position at all cannot be judged and is still clicked (tests/README.md, What tests cannot prove).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function bare()
	local w = T.newWorld()
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "MAGE", addons = {}, allowMissing = true })
	return w, c, c.env
end
local function mk(env, parent, level, l, b, wd, ht, o)
	o = o or {}
	local f = env.CreateFrame(o.kind or "Button", nil, parent or env.UIParent)
	f:SetFrameLevel(level)
	f:SetSize(wd, ht)
	f:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", l, b)
	if o.mouse ~= false then f:EnableMouse(true) end
	if o.clips then f:SetClipsChildren(true) end
	return f
end
local function counter(f)
	local n = { 0 }
	f:SetScript("OnClick", function() n[1] = n[1] + 1 end)
	return n
end

test("strict click: a click on a covered button fails, names what is on top, and its OnClick does not run", function()
	local w, c, env = bare()
	local under = mk(env, nil, 3, 100, 100, 100, 100)
	mk(env, nil, 9, 100, 100, 100, 100)
	local n = counter(under)
	local good, err = pcall(c.click, c, under)
	ok(not good, "the click fails")
	ok(tostring(err):find("cannot reach", 1, true), "the message says why: " .. tostring(err))
	eq(n[1], 0, "no OnClick")
end)

test("strict click: a click on a button scrolled out of its clipping parent fails; after scrolling it into view it works", function()
	local w, c, env = bare()
	local view = mk(env, nil, 1, 100, 100, 200, 100, { kind = "Frame", clips = true, mouse = false })
	view:EnableMouseWheel(true)
	local inner = env.CreateFrame("Frame", nil, view)
	inner:SetSize(200, 400)
	local off = 0
	local function place() inner:ClearAllPoints() inner:SetPoint("TOPLEFT", view, "TOPLEFT", 0, off) end
	place()
	view:SetScript("OnMouseWheel", function(_, d) off = math.max(0, math.min(300, off - d * 50)) place() end)
	local b = env.CreateFrame("Button", nil, inner)
	b:SetSize(80, 20)
	b:SetPoint("TOPLEFT", inner, "TOPLEFT", 10, -330)
	b:EnableMouse(true)
	local n = counter(b)
	ok(not pcall(c.click, c, b), "scrolled out: the click fails")
	eq(n[1], 0)
	ok(c:scrollIntoView(b), "the wheel brings it into view")
	c:click(b)
	eq(n[1], 1, "now the click goes through")
end)

test("strict click: a click on a button off the screen fails; the top button and a button with no position are clicked", function()
	local w, c, env = bare()
	local far = mk(env, nil, 3, -5000, -5000, 50, 50)
	local top = mk(env, nil, 3, 400, 400, 50, 50)
	local loose = env.CreateFrame("Button", nil, env.UIParent)
	loose:SetSize(40, 20)
	loose:EnableMouse(true)
	local nf, nt, nl = counter(far), counter(top), counter(loose)
	ok(not pcall(c.click, c, far), "off screen: fails")
	c:click(top)
	c:click(loose)
	eq(nf[1] .. nt[1] .. nl[1], "011")
end)
