-- r47 o3: AUD-175 (bell scroll survives the page layout) and AUD-191 (OpenSettings closes Help)
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function alertInWindow(c)
  local W = c.W
  local win = H.rect(W.UI.state.win)
  local hits = c:findText("Alert character")
  for _, fs in ipairs(hits) do
    local r = H.rect(fs)
    if r and H.visible(fs) and r.b >= win.b and r.b + r.h <= win.b + win.h then return true, r.b, win end
  end
  local r = hits[1] and H.rect(hits[1])
  return false, r and r.b, win
end

for _, wide in ipairs({ false, true }) do
  test("r47 o3: the Alert character link opens Settings at the Alert character row (" .. (wide and "unfolded" or "folded") .. ")", function()
    local w = T.newWorld()
    local c = w:addClient(T.TESTCHAR, { spot = "Ratchet", class = "WARLOCK", wide = wide })
    T.settle(w)
    local W = c.W
    W.UI.Toggle(true) w:advance(2.5)
    eq(W.UI.Fold.IsUnfolded(), false, "start folded")
    -- the driver wizard's "I have a second account to alert" button calls exactly this
    W.UI.OpenSettings("bell") w:advance(3)
    eq(W.UI.Fold.IsUnfolded() == true, wide, "window width as set up")
    local seen, y, win = alertInWindow(c)
    ok(seen, "the player asked for the Alert character row but it is not inside the window (row bottom at y=" .. tostring(y)
      .. ", window spans " .. tostring(win.b) .. ".." .. tostring(win.b + win.h) .. "); the page is at the top of Driving: " .. tostring(T.list(c:visibleTexts()):match("Driving: [%w ]+")) .. "")
    T.clean(w)
  end)
end

local function lvl(f) return tonumber(f:GetFrameLevel()) or 0 end
-- (design 2) Settings and Help are pages inside the window's pages frame (UI.settings.pages, a child of the window
-- that cuts a page on its way in off), so a panel is the window's child or that frame's child.
local function ofWin(f, win)
	local p = f:GetParent()
	return p == win or (p ~= nil and p.noEdgeFade ~= nil and p:GetParent() == win)
end

test("r47 o3: Settings opened while Help is up is not left hidden behind Help", function()
  local w = T.newWorld()
  local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = false } } })
  w:advance(2)
  local W = c.W
  local UI = W.UI
  UI.Toggle(true) w:advance(3)
  -- control: Settings alone opens on top and nothing covers it
  UI.OpenSettings("window") w:advance(3)
  ok(UI.SettingsShown(), "control: Settings opens")
  ok(not UI.HelpShown(), "control: no Help over it")
  UI.CloseSettings(true) w:advance(2)
  -- Help from Home (the "?" on Home), then the update toast's click, which is just UI.OpenSettings("window")
  ok(UI.OpenHelp("home"), "Help opens from Home")
  w:advance(3)
  ok(UI.HelpShown(), "control: Help is up")
  UI.OpenSettings("window") w:advance(3)
  local win = UI.state.win
  local settings, help
  for _, f in ipairs(c.frames or {}) do
    if ofWin(f, win) and H.visible(f) then
      if lvl(f) == lvl(win) + 40 then settings = f end
      if lvl(f) == lvl(win) + 60 then help = f end
    end
  end
  ok(settings ~= nil, "Settings panel is shown")
  ok(not (help and settings and lvl(help) > lvl(settings)),
    "Settings opened (gear tint on, ui.settingsOpen=" .. tostring(UI.state.settingsOpen) .. ") but the Help page (level win+60) is still shown over it (Settings is win+40): the player sees Help, not Settings")
  T.clean(w)
end)