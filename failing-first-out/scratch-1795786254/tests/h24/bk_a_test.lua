-- Group A break-it guards (job 415): the sheets (T.Sheet opts.head, Report a bug, raincheck), E3b-01 and E3b-09.
-- Each test passes on the real code and fails when the line named above it is broken.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function near(a, b) return math.abs(a - b) <= 0.6 end

local function openWin()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768 })
	T.settle(w)
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state, r.W.UI
end

local function ride(r, w, st)
	r.W.ride = { id = "h24bk", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = st,
		at = r.env.GetTime(), service = "Bea's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.RefreshNow()
	w:advance(2)
end

local nrc = 0
local function raincheck(r)
	nrc = nrc + 1
	r.W.Raincheck.Mine = function()
		return { { id = "h24bk" .. nrc, state = "offered", driver = "Anita Lift", cover = 5000, expires = os.time() + 6 * 86400 } }
	end
	return r.W.UI.RaincheckOffer()
end

-- every shown, mouse-enabled frame under root that holds the point (x, y), in walk order
local function catchers(f, x, y, out, seen)
	out, seen = out or {}, seen or {}
	if seen[f] then return out end
	seen[f] = true
	if f.IsShown and f:IsShown() then
		local rc = H.rect(f)
		if rc and f.IsMouseEnabled and f:IsMouseEnabled() and rc.l <= x and x <= rc.l + rc.w and rc.b <= y and y <= rc.b + rc.h then
			out[#out + 1] = f
		end
		for _, c in ipairs({ f:GetChildren() }) do catchers(c, x, y, out, seen) end
	end
	return out
end

-- the one the mouse reaches: the highest frame level (the later one on a tie)
local function topmost(list)
	local best
	for _, f in ipairs(list) do
		if not best or f:GetFrameLevel() >= best:GetFrameLevel() then best = f end
	end
	return best
end

local function plainSheet(head)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	local host = d.env.CreateFrame("Frame", nil, d.env.UIParent)
	host:SetSize(300, 600)
	host:SetPoint("CENTER")
	host:Show()
	local sh = d.W.Theme.Sheet(host, 200, "Title", { head = head })
	sh:Open()
	return w, host, sh
end

-- guard: break-it, Wuber/Theme/Forms.lua:546 the catcher starts 20 lower (head - 20 below the strip is left open to the page)
test("h24 a bk: T.Sheet head strip: the point just under the strip is caught, the strip itself is not", function()
	local w, host, sh = plainSheet(56)
	w:advance(1)
	local hr = H.rect(host)
	local top = hr.b + hr.h
	local x = hr.l + hr.w / 2
	eq(#catchers(sh, x, top - 28), 0, "nothing of the sheet takes the mouse in the head strip")
	ok(#catchers(sh, x, top - 59) > 0, "the point 3 under the strip is caught")
	ok(#catchers(sh, x, top - 100) > 0, "the middle of the dim is caught")
	T.clean(w)
end)

-- guard: break-it, Wuber/Theme/Forms.lua:547 the catcher stops 30 above the bottom (the dim's foot strip is open while the card is still down)
test("h24 a bk: T.Sheet head strip: while the card rises the dim's foot is caught too", function()
	local w, host, sh = plainSheet(56)
	local hr = H.rect(host)
	ok(#catchers(sh, hr.l + hr.w / 2, hr.b + 3) > 0, "the dim's bottom edge is caught at the start of the rise")
	T.clean(w)
end)

-- guard: break-it, Wuber/Theme/Forms.lua:548 the catcher takes no mouse (EnableMouse(false))
test("h24 a bk: T.Sheet head strip: the dim under the strip takes the mouse (nothing under it is clickable)", function()
	local w, host, sh = plainSheet(56)
	w:advance(1)
	local hr = H.rect(host)
	local x, y = hr.l + hr.w / 2, hr.b + hr.h - 100
	ok(topmost(catchers(sh, x, y)) ~= nil, "a frame of the sheet is the one the mouse reaches in the dim")
	T.clean(w)
end)

-- guard: break-it, Wuber/Theme/Forms.lua:550 a click on the catcher no longer closes the sheet
test("h24 a bk: T.Sheet head strip: a click on the dim below the strip closes the sheet", function()
	local w, host, sh = plainSheet(56)
	w:advance(1)
	local hr = H.rect(host)
	local hit = topmost(catchers(sh, hr.l + hr.w / 2, hr.b + hr.h - 100))
	ok(hit, "something takes the click")
	local down = hit:GetScript("OnMouseDown")
	ok(down, "and it has a mouse-down handler")
	down(hit, "LeftButton")
	w:advance(1)
	ok(not sh:IsShown(), "the sheet closed")
	T.clean(w)
end)

-- guard: break-it, Wuber/Theme/Forms.lua:549 the catcher's frame level goes 20 above the card (a click on the card's rows would close the sheet)
test("h24 a bk: T.Sheet head strip: a click on the card is the card's, not the dim's", function()
	local w, host, sh = plainSheet(56)
	w:advance(1)
	local cr = H.rect(sh.card)
	local hit = topmost(catchers(sh, cr.l + cr.w / 2, cr.b + cr.h / 2))
	ok(hit, "something takes the click")
	local f = hit
	local inCard = false
	while f do if f == sh.card then inCard = true break end f = f:GetParent() end
	ok(inCard, "the frame the mouse reaches over the card is the card or a part of it, not the dim's catcher")
	T.clean(w)
end)

-- guard: break-it, Wuber/Theme/Forms.lua:551 the catcher loses wuberNoTip (a tooltip over empty dim)
test("h24 a bk: T.Sheet head strip: the dim's catcher shows no tooltip on empty space", function()
	local w, host, sh = plainSheet(56)
	ok(sh.catch and sh.catch.wuberNoTip == true, "the catcher is marked as a click blocker")
	ok(sh.wuberNoTip == true, "so is the sheet")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Bug.lua:439 and Bug.lua:446 the open report does not move when the tab bar goes away (no re-place, no re-layout)
test("h24 a bk: Report a bug open on Home follows the phone's foot down when a ride starts, and its card grows to fill", function()
	local w, r, ui, UI = openWin()
	ok(UI.Bug.Open(), "the report opens")
	w:advance(1)
	local f = UI.Bug.frame
	local h0 = f.card:GetHeight()
	ride(r, w, "summoning")
	ok(UI.TabsHidden(), "the tab bar is away")
	local wr, hr, cr = H.rect(ui.win), H.rect(f.holder), H.rect(f.card)
	ok(near(hr.b, wr.b), ("the holder reaches the window's foot (holder %.1f, window %.1f)"):format(hr.b, wr.b))
	ok(near(cr.b, wr.b), ("the card rests on the foot (card %.1f, window %.1f)"):format(cr.b, wr.b))
	local k = wr.h / ui.win:GetHeight()
	ok(f.card:GetHeight() > h0 + 40, ("the card grew by the bar's height (was %.0f, now %.0f)"):format(h0, f.card:GetHeight()))
	ok(near(cr.b + cr.h, wr.b + wr.h - UI.HEAD_H * k), "its top still sits under the header zone")
	eq(#w.errors, 0, "Lua errors")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Bug.lua:498-499 Bug.Open does not place or lay out again (a sheet opened after the foot changed is right at once)
test("h24 a bk: Report a bug opened again after the tab bar went away is placed on the foot at once, full height", function()
	local w, r, ui, UI = openWin()
	ok(UI.Bug.Open(), "the report opens")
	w:advance(1)
	UI.Bug.Close()
	w:advance(1)
	ride(r, w, "summoning")
	ok(UI.TabsHidden(), "the tab bar is away")
	ok(UI.Bug.Open(), "the report opens again")
	local f = UI.Bug.frame
	local wr, hr = H.rect(ui.win), H.rect(f.holder)
	ok(near(hr.b, wr.b), ("the holder reaches the window's foot with no frame in between (holder %.1f, window %.1f)"):format(hr.b, wr.b))
	local want = ui.win:GetHeight() - UI.HEAD_H
	ok(near(f.sheetH, want), ("the sheet height is the room under the header zone (%.0f, want %.0f)"):format(f.sheetH, want))
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Moments.lua:403 the open raincheck sheet does not move when the tab bar goes away
test("h24 a bk: the raincheck sheet open on Home follows the foot down when a ride starts", function()
	local w, r, ui, UI = openWin()
	local f = raincheck(r)
	w:advance(1)
	ok(f and f.open, "the offer is open")
	ride(r, w, "summoning")
	ok(UI.TabsHidden(), "the tab bar is away")
	local wr, hr, cr = H.rect(ui.win), H.rect(f.holder), H.rect(f.card)
	ok(near(hr.b, wr.b), ("the holder reaches the window's foot (holder %.1f, window %.1f)"):format(hr.b, wr.b))
	ok(near(cr.b, wr.b), ("the card rests on the foot (card %.1f, window %.1f)"):format(cr.b, wr.b))
	eq(#w.errors, 0, "Lua errors")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Moments.lua:451 a new offer does not place the holder (it waits a frame for the OnUpdate)
test("h24 a bk: a raincheck offer shown after the tab bar went away is on the foot at once", function()
	local w, r, ui, UI = openWin()
	local f = raincheck(r)
	w:advance(1)
	f:Close(true)
	w:advance(1)
	ride(r, w, "summoning")
	ok(UI.TabsHidden(), "the tab bar is away")
	local g = raincheck(r)
	ok(g == f, "the same sheet comes back")
	local wr, hr = H.rect(ui.win), H.rect(g.holder)
	ok(near(hr.b, wr.b), ("the holder reaches the window's foot with no frame in between (holder %.1f, window %.1f)"):format(hr.b, wr.b))
	T.clean(w)
end)
