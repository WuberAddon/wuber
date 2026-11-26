-- Every mouse input of the fake game answers by the real client's hit rule (Client:frameAt: frames that take the mouse,
-- clipped out where an ancestor clips, ranked by strata / level / clipping ancestor), not only Client:clickOn.
-- The inputs: Client:moveMouse / hoverOn (OnEnter, OnLeave, GetMouseFoci, IsMouseOver), Client:wheel / wheelOn /
-- scrollIntoView (OnMouseWheel), Client:drag (OnDragStart), and the audit of a direct Client:click (WUBER_CLICK_AUDIT).
-- Caveats (tests/README.md, What tests cannot prove): IsMouseOver is plain geometry here, as in the game (no hit order, no clipping);
-- a frame that only enables the wheel (no EnableMouse) is taken to receive the wheel, which no real sample has measured.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function bare()
	local w = T.newWorld()
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "MAGE", addons = {}, allowMissing = true })
	return w, c, c.env
end
local function mk(env, parent, level, l, b, wd, ht, o)
	o = o or {}
	local f = env.CreateFrame(o.kind or "Frame", nil, parent or env.UIParent)
	if o.strata then f:SetFrameStrata(o.strata) end
	f:SetFrameLevel(level)
	f:SetSize(wd, ht)
	f:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", l, b)
	if o.mouse ~= false then f:EnableMouse(true) end
	if o.clips then f:SetClipsChildren(true) end
	if o.wheel then f:EnableMouseWheel(true) end
	return f
end
-- records what a frame heard into log, as "<tag>:<event>"
local function listen(f, tag, log, events)
	for _, e in ipairs(events) do
		f:SetScript(e, function(_, d) log[#log + 1] = tag .. ":" .. e .. (d ~= nil and (":" .. tostring(d)) or "") end)
	end
end
local function names(list, tags)
	local out = {}
	for i, f in ipairs(list) do out[i] = tags[f] or "?" end
	return table.concat(out, ",")
end

-- GetMouseFoci --------------------------------------------------------------------------------------------------------

-- assumption: GetMouseFoci lists every frame under the cursor top-first by the same rank as Client:frameAt (the Lab measured only the first entry, run 3); no real sample of the full list. See tests/README.md.
test("fakegame mouse: GetMouseFoci lists the frames under the cursor top-first, without covered-by-rank, clipped-out or mouse-less ones", function()
	local w, c, env = bare()
	local low = mk(env, nil, 3, 100, 100, 300, 300)
	local high = mk(env, nil, 9, 100, 100, 300, 300)
	local ghost = mk(env, nil, 20, 100, 100, 300, 300, { mouse = false })
	local clipper = mk(env, nil, 1, 100, 100, 50, 50, { clips = true, mouse = false })
	local cut = mk(env, clipper, 30, 200, 200, 80, 80) -- inside the clipper's frame but out of its rect at (250, 250)
	c:moveMouse(250, 250)
	eq(names(env.GetMouseFoci(), { [low] = "low", [high] = "high", [ghost] = "ghost", [cut] = "cut" }), "high,low", "top first; no ghost, no cut")
	c:moveMouse(900, 900)
	eq(#env.GetMouseFoci(), 0, "nothing under the cursor")
end)

-- IsMouseOver ---------------------------------------------------------------------------------------------------------

-- the game's IsMouseOver is plain geometry: it does not rank (a covered frame is still "over") and the fake keeps it so
-- assumption: the game's IsMouseOver is plain geometry (no hit order, no clipping); not measured in the real client for a covered or clipped-out frame.
test("fakegame mouse: IsMouseOver is geometry only: a covered frame and a clipped-out frame still answer true, a frame elsewhere false", function()
	local w, c, env = bare()
	local low = mk(env, nil, 3, 100, 100, 300, 300)
	local high = mk(env, nil, 9, 100, 100, 300, 300)
	local clipper = mk(env, nil, 1, 100, 100, 50, 50, { clips = true, mouse = false })
	local cut = mk(env, clipper, 30, 200, 200, 80, 80)
	local away = mk(env, nil, 9, 600, 600, 50, 50)
	c:moveMouse(250, 250)
	ok(high:IsMouseOver(), "the top frame")
	ok(low:IsMouseOver(), "covered by high, still geometrically under the cursor")
	ok(cut:IsMouseOver(), "clipped out, still geometry (the game does not know clipping here)")
	ok(not away:IsMouseOver(), "a frame elsewhere")
	c:moveMouse(110, 110)
	ok(not cut:IsMouseOver(), "the cursor left it")
end)

-- OnEnter / OnLeave ---------------------------------------------------------------------------------------------------

-- assumption: OnEnter goes to the top frame only; not measured in the real client for covered or clipped-out frames.
test("fakegame mouse: hovering reaches the top frame only: not a frame covered by another, not one clipped out", function()
	local w, c, env = bare()
	local log = {}
	local low = mk(env, nil, 3, 100, 100, 300, 300)
	local high = mk(env, nil, 9, 100, 100, 300, 300)
	local clipper = mk(env, nil, 1, 100, 100, 50, 50, { clips = true, mouse = false })
	local cut = mk(env, clipper, 30, 200, 200, 80, 80)
	for tag, f in pairs({ low = low, high = high, cut = cut }) do listen(f, tag, log, { "OnEnter", "OnLeave" }) end
	c:moveMouse(250, 250)
	eq(table.concat(log, " "), "high:OnEnter:true", "only the top frame hears OnEnter")
	log = {}
	listen(low, "low", log, { "OnEnter", "OnLeave" }) listen(high, "high", log, { "OnEnter", "OnLeave" })
	c:moveMouse(260, 260)
	eq(#log, 0, "still on the same frame: nothing")
	c:moveMouse(900, 900)
	eq(table.concat(log, " "), "high:OnLeave:true", "leaving")
end)

-- assumption: moveMouse fires OnLeave of the old frame before OnEnter of the new; the order is not measured in the real client.
test("fakegame mouse: hoverOn a covered frame enters the frame that covers it, and moving between two frames leaves one then enters the other", function()
	local w, c, env = bare()
	local log = {}
	local under = mk(env, nil, 3, 100, 100, 100, 100)
	local over = mk(env, nil, 9, 100, 100, 100, 100)
	local side = mk(env, nil, 3, 400, 100, 100, 100)
	for tag, f in pairs({ under = under, over = over, side = side }) do listen(f, tag, log, { "OnEnter", "OnLeave" }) end
	eq(c:hoverOn(under), over, "the frame that took the mouse")
	eq(table.concat(log, " "), "over:OnEnter:true", "the covered frame heard nothing")
	for i = #log, 1, -1 do log[i] = nil end
	c:hoverOn(side)
	eq(table.concat(log, " "), "over:OnLeave:true side:OnEnter:true", "leave first, then enter")
end)

-- the mouse wheel -----------------------------------------------------------------------------------------------------

-- assumption: a frame that only enables the wheel (no EnableMouse) takes it, and the wheel goes to the top such frame; not measured in the real client.
test("fakegame mouse: the wheel goes to the top wheel-enabled frame under the cursor, not a covered one, not one clipped out", function()
	local w, c, env = bare()
	local log = {}
	local low = mk(env, nil, 3, 100, 100, 300, 300, { wheel = true })
	local high = mk(env, nil, 9, 100, 100, 300, 300, { wheel = true })
	local clipper = mk(env, nil, 1, 100, 100, 50, 50, { clips = true, mouse = false })
	local cut = mk(env, clipper, 30, 200, 200, 80, 80, { wheel = true })
	for tag, f in pairs({ low = low, high = high, cut = cut }) do listen(f, tag, log, { "OnMouseWheel" }) end
	eq(c:wheel(250, 250, -1), high, "returns the frame that heard it")
	eq(table.concat(log, " "), "high:OnMouseWheel:-1", "only the top frame")
end)

-- assumption: the wheel passes from a frame with no handler to its nearest ancestor with one; not measured in the real client.
test("fakegame mouse: a top frame that does not take the wheel is skipped; one with no handler passes it to its nearest ancestor that does", function()
	local w, c, env = bare()
	local log = {}
	local scroll = mk(env, nil, 3, 100, 100, 300, 300, { wheel = true })
	local cover = mk(env, nil, 9, 100, 100, 300, 300) -- takes clicks, not the wheel
	listen(scroll, "scroll", log, { "OnMouseWheel" })
	eq(c:wheel(250, 250, 1), scroll, "the covering frame does not take the wheel")
	local parent = mk(env, nil, 3, 500, 100, 200, 200, { wheel = true })
	local child = mk(env, parent, 4, 520, 120, 50, 50, { wheel = true }) -- wheel on, no handler
	listen(parent, "parent", log, { "OnMouseWheel" })
	for i = #log, 1, -1 do log[i] = nil end
	eq(c:wheel(530, 130, -1), parent, "no handler on the child: the parent")
	eq(table.concat(log, " "), "parent:OnMouseWheel:-1")
	eq(c:wheel(900, 900, 1), nil, "nothing under the cursor")
	local _ = { cover, child }
end)

test("fakegame mouse: scrollIntoView turns the wheel over the scroll frame, so a wheel frame covering it gets the notches", function()
	local w, c, env = bare()
	local log = {}
	local clip = mk(env, nil, 3, 100, 100, 200, 100, { wheel = true, clips = true })
	local row = mk(env, clip, 4, 120, 20, 50, 20, { mouse = false }) -- below the clip: out of view
	listen(clip, "clip", log, { "OnMouseWheel" })
	local cover = mk(env, nil, 9, 100, 100, 200, 100, { wheel = true })
	listen(cover, "cover", log, { "OnMouseWheel" })
	c:scrollIntoView(row, 3)
	eq(table.concat(log, " "), "cover:OnMouseWheel:-1 cover:OnMouseWheel:-1 cover:OnMouseWheel:-1", "the covering frame took every notch; the clip heard none")
end)

-- guard: infra (the scroll frame with nothing over it still turns, as before the wheel was routed)
test("fakegame mouse: scrollIntoView still scrolls the clip when nothing covers it", function()
	local w, c, env = bare()
	local clip = mk(env, nil, 3, 100, 100, 200, 100, { wheel = true, clips = true })
	local row = mk(env, clip, 4, 120, 20, 50, 20, { mouse = false })
	local content = mk(env, clip, 4, 100, 100, 1, 1, { mouse = false })
	local offset = 0
	clip:SetScript("OnMouseWheel", function(_, d)
		offset = offset - d * 40
		row:ClearAllPoints()
		row:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 120, 20 + offset)
	end)
	ok(c:scrollIntoView(row, 20), "the row came into view")
	local _ = content
end)

-- drag ----------------------------------------------------------------------------------------------------------------

-- assumption: a covering frame that is not registered for drag swallows the press: WoW sends the press to the top frame and does not pass mouse events to parents unless SetPropagateMouseClicks; not measured in the real client.
test("fakegame mouse: drag presses where the frame is drawn: a frame covered by another that takes the mouse cannot be dragged", function()
	local w, c, env = bare()
	local log = {}
	local bar = mk(env, nil, 3, 100, 100, 200, 30)
	bar:RegisterForDrag("LeftButton")
	listen(bar, "bar", log, { "OnDragStart" })
	local cover = mk(env, nil, 9, 100, 100, 200, 30)
	local okc, err = pcall(function() c:drag(bar, 40, 0) end)
	ok(not okc, "the press lands on the covering frame, which is not registered for drag")
	ok(tostring(err):find("covered", 1, true), "the message says why: " .. tostring(err))
	eq(#log, 0, "the covered bar heard no drag")
	local _ = cover
end)

-- guard: infra (the plain drag of a frame that is on top)
-- assumption: a covering frame registered for drag takes the drag (WoW sends the press to the top frame); not measured in the real client.
test("fakegame mouse: the top frame at the press, when registered for drag, is the one that starts the drag", function()
	local w, c, env = bare()
	local log = {}
	local bar = mk(env, nil, 3, 100, 100, 200, 30)
	bar:RegisterForDrag("LeftButton")
	listen(bar, "bar", log, { "OnDragStart", "OnDragStop" })
	c:drag(bar, 40, 0)
	eq(table.concat(log, " "), "bar:OnDragStart:LeftButton bar:OnDragStop")
end)

-- the audit of a direct Client:click ----------------------------------------------------------------------------------

test("fakegame mouse: with WUBER_CLICK_AUDIT set, a direct click on a covered, clipped-out or off-screen frame is logged (and fails), a click on the top frame is not", function()
	local w, c, env = bare()
	local H = T.H
	local path = "tests/out/click-audit-" .. os.time() .. ".txt" -- tests/out is git-ignored (.gitignore line 2)
	os.execute("mkdir tests\\out 2> nul || mkdir -p tests/out 2>/dev/null")
	H.clickAuditFile = path
	local clicked = 0
	local covered = mk(env, nil, 3, 100, 100, 100, 100, { kind = "Button" })
	local cover = mk(env, nil, 9, 100, 100, 100, 100, { kind = "Button" })
	local clipper = mk(env, nil, 1, 400, 100, 50, 50, { clips = true, mouse = false })
	local cut = mk(env, clipper, 30, 450, 150, 80, 80, { kind = "Button" })
	local top = mk(env, nil, 3, 700, 100, 100, 100, { kind = "Button" })
	for _, f in ipairs({ covered, cover, cut, top }) do f:SetScript("OnClick", function() clicked = clicked + 1 end) end
	c:click(top)
	local okCovered = pcall(c.click, c, covered)
	local okCut = pcall(c.click, c, cut)
	H.clickAuditFile = nil
	local fh = io.open(path, "r")
	local text = fh:read("*a")
	fh:close()
	os.remove(path)
	ok(not okCovered and not okCut, "Client:click is strict: the covered and the clipped-out clicks fail")
	eq(clicked, 1, "only the top frame's click ran")
	local lines = {}
	for line in text:gmatch("[^\n]+") do lines[#lines + 1] = line end
	eq(#lines, 2, "two lines: " .. text)
	local test1, who1, top1 = lines[1]:match("^([^\t]*)\t([^\t]*)\t([^\t]*)$")
	ok(test1 and test1:find("with WUBER_CLICK_AUDIT set", 1, true), "the test's name leads the line: " .. lines[1])
	ok(who1 and who1:find("Button", 1, true), "the frame: " .. tostring(who1))
	ok(top1 and top1:find("Button", 1, true), "what is on top: " .. tostring(top1))
	ok(lines[2]:match("\tnothing$"), "a clipped-out frame: nothing takes the mouse at its centre: " .. lines[2])
end)
