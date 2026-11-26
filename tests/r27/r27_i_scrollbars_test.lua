-- Round 27 group I: a scroll bar (T.EdgeFade holder) never draws above a panel that covers its screen.
-- REV-r25-1: Home's list bar was over Settings/Help cards. REV-r26-1: Settings' bar was over unfolded Help.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function lvl(f) return tonumber(f:GetFrameLevel()) or 0 end
local function under(f, root)
	while f do
		if f == root then return true end
		f = f:GetParent()
	end
	return false
end

-- every shown bar holder that is not part of the panel must sit below the panel's level
local function offenders(c, panel)
	local bad = {}
	for _, f in ipairs(c.frames or {}) do
		local fd = f.edgeFade
		if fd and fd.holder and H.visible(fd.holder) and not under(f, panel) and lvl(fd.holder) >= lvl(panel) then
			bad[#bad + 1] = (f:GetName() or "?") .. "@" .. lvl(fd.holder) .. ">=" .. lvl(panel)
		end
	end
	return bad
end

-- (design 2) Settings and Help are pages inside the window's pages frame (UI.settings.pages, a child of the window
-- that cuts a page on its way in off), so a panel is the window's child or that frame's child.
local function ofWin(f, win)
	local p = f:GetParent()
	return p == win or (p ~= nil and p.noEdgeFade ~= nil and p:GetParent() == win)
end
local function panelAt(c, win, d)
	for _, f in ipairs(c.frames or {}) do
		if ofWin(f, win) and lvl(f) == lvl(win) + d and H.visible(f) then return f end
	end
end

local function rig(unfold)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = false } } })
	w:advance(2)
	local W = c.W
	local UI = W.UI
	UI.Toggle(true)
	for _, tab in ipairs({ "Ride", "Chat", "Map" }) do
		pcall(UI.SelectTab, tab)
		w:advance(2)
	end
	pcall(UI.SelectTab, "Ride")
	w:advance(2)
	if unfold and UI.Fold and UI.Fold.Set then pcall(UI.Fold.Toggle) w:advance(2) end
	return w, c, W
end

for _, unfold in ipairs({ false, true }) do
	test("r27 REV-r25-1/REV-r26-1: no scroll bar draws over Settings or Help (" .. (unfold and "unfolded" or "folded") .. ")", function()
		local w, c, W = rig(unfold)
		local UI = W.UI
		UI.OpenSettings()
		w:advance(5)
		local win = UI.state.win
		local panel = panelAt(c, win, 40)
		ok(panel ~= nil, "found the Settings panel")
		eq(#offenders(c, panel), 0, "over Settings: " .. table.concat(offenders(c, panel), ", "))
		UI.OpenHelp("settings")
		w:advance(5)
		local hp = panelAt(c, win, 60)
		ok(hp ~= nil, "found the Help panel")
		eq(#offenders(c, hp), 0, "over Help: " .. table.concat(offenders(c, hp), ", "))
	end)
end

-- REV-r25-1 follow-up: with Home's lift at 12, its bar and soft edges must still draw above every frame of Home's own list.
for _, unfold in ipairs({ false, true }) do
	test("r27 REV-r25-1: Home's scroll bar and soft edges stay above Home's own list (" .. (unfold and "unfolded" or "folded") .. ")", function()
		local w = T.newWorld()
		for _, who in ipairs({ T.ANITA, T.BOB }) do
			local d = T.driver(w, who, { spot = "Orgrimmar" })
			d.W.Driver.SetOnline(true)
			w:advance(3)
		end
		local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = false } } })
		w:advance(2)
		local W = c.W
		local UI = W.UI
		UI.Toggle(true)
		pcall(UI.SelectTab, "Ride")
		w:advance(5)
		if unfold and UI.Fold and UI.Fold.Toggle and not (UI.Fold.IsUnfolded and UI.Fold.IsUnfolded()) then pcall(UI.Fold.Toggle) w:advance(2) end
		w:advance(5)
		local clip = W.Mod("UI.Window").screens.home.clip
		local fd = clip and clip.edgeFade
		ok(fd ~= nil, "found Home's edge fade")
		local hl = lvl(fd.holder)
		local top, n, topName = -1, 0, "?"
		for _, f in ipairs(c.frames or {}) do
			if f ~= fd.holder and not under(fd.holder, f) and under(f, clip) and f ~= clip and not under(f, fd.holder) then
				n = n + 1
				if lvl(f) > top then top, topName = lvl(f), tostring(f:GetName() or "?") end
			end
		end
		ok(n > 3, "Home's list has frames in it (" .. n .. ")")
		ok(top < hl, "highest Home content level " .. top .. " (" .. topName .. ") must be below the holder at " .. hl)
	end)
end
