local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
-- r47 i: Help opened over unfolded Settings search results: the results' scroll bar / soft edges draw over Help

local function lvl(f) return tonumber(f:GetFrameLevel()) or 0 end
local function under(f, root)
  while f do if f == root then return true end f = f:GetParent() end
  return false
end
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

test("r47 i: no search-results scroll bar draws over Help (unfolded Settings, results showing)", function()
  local w = T.newWorld()
  local c = w:addClient(T.TESTCHAR, { spot = "Ratchet", class = "WARLOCK", wide = true, saved = { Wuber = { coach = false } } })
  T.settle(w)
  local W, UI = c.W, c.W.UI
  UI.Toggle(true) w:advance(2.5)
  UI.OpenSettings() w:advance(3)
  ok(UI.Fold.IsUnfolded(), "window is unfolded")
  local FindMod = W.Mod("UI.Settings.Find")
  -- the player types into the search box
  local box
  for _, f in ipairs(c.frames or {}) do
    if f.GetObjectType and f:GetObjectType() == "EditBox" and H.visible(f) and f.HasFocus then box = f end
  end
  ok(box ~= nil, "found the visible search box")
  c:type(box, "a", false) w:advance(1.5)
  local win = UI.state.win
  local settings = panelAt(c, win, 40)
  ok(settings ~= nil, "found Settings panel")
  local resultsBars = 0
  for _, f in ipairs(c.frames or {}) do
    local fd = f.edgeFade
    if fd and fd.holder and H.visible(fd.holder) and under(f, settings) and lvl(fd.holder) > lvl(win) + 60 then resultsBars = resultsBars + 1 end
  end
  ok(resultsBars >= 1, "control: the search results list has its scroll bar drawn (holders above win+60 under Settings: " .. resultsBars .. ")")
  UI.OpenHelp("settings") w:advance(4)
  local hp = panelAt(c, win, 60)
  ok(hp ~= nil, "found the Help panel")
  local bad = offenders(c, hp)
  local own = 0
  for _, f in ipairs(c.frames or {}) do
    local fd = f.edgeFade
    if fd and fd.holder and H.visible(fd.holder) and under(f, settings) and lvl(fd.holder) >= lvl(hp) then own = own + 1 end
  end
  eq(own, 0, "the Settings search results' scroll bar and soft edges still draw over the Help page (" .. own .. " holder(s) at or above Help's level " .. lvl(hp) .. ")")
  T.clean(w)
end)



for _, unfold in ipairs({ true }) do
test("r47 i: search results scroll bar does not draw over Help (" .. (unfold and "unfolded" or "folded") .. ")", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = false } } })
	w:advance(2)
	local W = c.W
	local UI = W.UI
	UI.Toggle(true)
	pcall(UI.SelectTab, "Ride")
	w:advance(3)
	if unfold and UI.Fold and UI.Fold.Toggle and not UI.Fold.IsUnfolded() then UI.Fold.Toggle() w:advance(2) end
	UI.OpenSettings()
	w:advance(3)
	local st = UI.settings
	c:type(st.find.box.edit, "e", false)
	w:advance(1)
	local res = st.find.results
	ok(H.visible(res), "control: the search results show")
	local fd = res.edgeFade
	local win = UI.state.win
	-- control: the Settings clip's holder is handled
	UI.OpenHelp("settings")
	w:advance(5)
	local hp
	for _, f in ipairs(c.frames or {}) do
		if ofWin(f, win) and lvl(f) == lvl(win) + 60 and H.visible(f) then hp = f end
	end
	ok(hp ~= nil, "control: Help panel is open")
	ok(fd:BarShown() or fd:Shown("bottom"), "control: the results are long enough to show a scroll bar or fade")
	ok(not H.visible(fd.holder), "the results scroll bar holder is hidden while Help is open")
	UI.CloseHelp(true)
	w:advance(3)
	ok(H.visible(fd.holder), "the results scroll bar comes back when Help closes")
	T.clean(w)
end)
end
