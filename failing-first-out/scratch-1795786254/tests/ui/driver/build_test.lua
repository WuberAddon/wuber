-- Tests of UI.Driver.Build (round 13, agent B: a reviewer's in-game screenshot findings). Loaded by
-- tests/run.lua with its helper table T. The console's footer (no second Settings) and the raid
-- controls' summoner picker (its label fits its pill).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function plain(t) return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function count(a, text)
	local n = 0
	for _, t in ipairs(a:visibleTexts()) do if plain(t) == text then n = n + 1 end end
	return n
end

local function console(o)
	o = o or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Sorted = function() return {} end
	if o.wide then
		a.wide = true
		W.db.coach = true
		W.UI.WindowWide(true)
	elseif W.UI and W.UI.WindowWide then
		W.UI.WindowWide(false)
	end
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

---------------------------------------------------------------------------
-- I20: Settings is the top bar's gear; the driver footer no longer repeats it
---------------------------------------------------------------------------

test("ui.driver.build: I20 the console footer has no Settings (the top bar's gear opens it); its links share the room", function()
	for _, wide in ipairs({ false, true }) do
		local w, a, W = console({ wide = wide })
		local v = W.Driver.ui.console
		local what = wide and "unfolded" or "folded"
		eq(v.links.settings, nil, what .. ": no Settings link")
		eq(count(a, "Settings"), 0, what .. ": no 'Settings' label on the page")
		local names = {}
		for _, l in ipairs(v.links) do names[#names + 1] = l.what end
		eq(table.concat(names, " "), "crew messages advert blocked earnings customers", what .. ": the six links (My advert line shows in Simple only)")
		for _, l in ipairs(v.links) do
			ok(l:GetWidth() >= 68, what .. ": " .. l.what .. " is " .. l:GetWidth() .. " wide")
			if l.what ~= "advert" then ok(l:IsVisible(), what .. ": " .. l.what .. " shows") end
		end
		T.clean(w)
	end
end)

test("ui.driver.build: I20 from the Drive tab the top bar's gear opens Settings at Driving", function()
	local w, a, W = console()
	local UI = W.UI
	local asked = "none"
	UI.OpenSettings = function(section) asked = tostring(section) end
	UI.CloseSettings = function() end
	a:clickOn(UI.state.gear or error("no gear"))
	eq(asked, "drive", "Driving opens")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- I17: the raid's summoner picker reads whole in its pill (it was "Summone...")
---------------------------------------------------------------------------

test("ui.driver.build: I17 raid controls - the summoner picker's label fits its pill at full size, folded and unfolded", function()
	for _, wide in ipairs({ false, true }) do
		local w, a, W = console({ wide = wide, raid = true })
		local v = W.Driver.ui.console
		local T2 = W.Theme
		local what = wide and "unfolded" or "folded"
		ok(v.pick:IsVisible(), what .. ": the picker shows")
		local l = v.pick.label
		local text = l.wuberText or ""
		local room = v.pick:GetWidth() - v.pick:GetHeight()
		local need = T2.MeasureText(text, l.wuberBase or l.wuberPx, l.wuberWeight)
		ok(need <= room, what .. ": '" .. text .. "' needs " .. need .. " of " .. room)
		eq(l.wuberPx, l.wuberBase, what .. ": not shrunk")
		ok(not text:find("...", 1, true), what .. ": no ...")
		for _, p in ipairs({ v.open, v.pause }) do
			local need2 = T2.MeasureText(p.label.wuberText or "", p.label.wuberBase or p.label.wuberPx, p.label.wuberWeight)
			ok(need2 <= p:GetWidth() - p:GetHeight(), what .. ": '" .. tostring(p.label.wuberText) .. "' fits")
		end
		T.clean(w)
	end
end)

---------------------------------------------------------------------------
-- E1-12: status strip gold ("4g 60s 55c") never runs under long fare pill ("50s to Thunder Bluff")
---------------------------------------------------------------------------

test("ui.driver.build: E1-12 status strip gold and fare pill stay clear in folded raid->sell transition", function()
	local w, a, W, DR = console({ wide = false, raid = true })
	W.Drive.Shards = function() return 10 end
	local copper = 46055
	W.Drive.Today = function() return 16, copper end
	if W.Driver then W.Driver.Today = W.Drive.Today end
	W.Drive.Dest = function() return "Thunder Bluff" end
	DR.SetMode("sell")
	if DR.SetOpen then DR.SetOpen(false) end
	w:advance(1)
	W.Driver.RefreshNow()
	w:advance(1)
	local v = W.Driver.ui.console
	local s = v.status
	ok(v.fare:IsShown(), "fare pill is shown")
	ok(v.fare:GetRight() <= s.gold:GetLeft(), ("fare right (%.1f) <= gold left (%.1f)"):format(v.fare:GetRight(), s.gold:GetLeft()))
	ok(v.fare:GetRight() <= s.rides:GetLeft(), ("fare right (%.1f) <= rides left (%.1f)"):format(v.fare:GetRight(), s.rides:GetLeft()))
	ok(not v.fare.text:IsTruncated(), "fare text is not truncated")
	ok(not s.gold:IsTruncated(), "gold text is not truncated")
	ok(not s.rides:IsTruncated(), "rides text is not truncated")
	if s.stacked then
		ok(s.gold:GetBottom() >= s.rides:GetTop(), ("stacked gold bottom (%.1f) >= rides top (%.1f)"):format(s.gold:GetBottom(), s.rides:GetTop()))
	end
	-- switching to a short take unstacks back to side-by-side
	copper = 5000
	W.Driver.RefreshNow()
	w:advance(1)
	ok(not s.stacked, "short take unstacks")
	ok(s.gold:GetRight() <= s.rides:GetLeft(), ("unstaked gold right (%.1f) <= rides left (%.1f)"):format(s.gold:GetRight(), s.rides:GetLeft()))
	T.clean(w)
end)

---------------------------------------------------------------------------
-- E3b-03: the Close tooltip says Wuber asks first when riders are still with you
---------------------------------------------------------------------------

test("ui.driver.build: E3b-03 Close tooltip does not promise riders their summon; says Wuber asks first", function()
	local w, a, W, DR = console()
	if not DR.IsOpen() then
		W.Driver.SetOnline(true)
		w:advance(1)
	end
	ok(DR.IsOpen(), "driver is open")
	local v = W.Driver.ui.console
	local tip = v.open.wuberTip
	ok(tip, "Open/Close button has a tooltip")
	local title = type(tip.title) == "function" and tip.title() or tip.title
	local body = type(tip.text) == "function" and tip.text() or tip.text
	eq(title, "Close", "tooltip title is Close")
	ok(body:find("Stop taking riders.", 1, true), "keeps 'Stop taking riders.': " .. tostring(body))
	ok(body:find("If riders are still with you, Wuber asks first.", 1, true), "says Wuber asks first: " .. tostring(body))
	ok(body:lower():find("you vanish from the map.", 1, true), "keeps 'you vanish from the map.': " .. tostring(body))
	ok(not body:find("still get their summon", 1, true), "no false summon promise: " .. tostring(body))
	v.open:GetScript("OnEnter")(v.open)
	v.open:GetScript("OnLeave")(v.open)
	eq(#w.errors, 0, "no Lua errors on hover")
	T.clean(w)
end)
