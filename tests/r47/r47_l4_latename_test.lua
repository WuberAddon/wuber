-- r47 l4 (AUD-223): Settings built while the player's name was unknown still offers the name-based rows once it is known
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function world(late, class, who)
  local w = T.newWorld()
  local c = w:addClient(who, { spot = "Ratchet", class = class, saved = { Wuber = { coach = false } },
    prepare = function(env)
      if not late then return end
      local orig = env.UnitName
      env.UnitName = function(u, ...)
        if env.__hideName and u == "player" then return nil end
        return orig(u, ...)
      end
      env.__hideName = true
    end })
  T.settle(w)
  return w, c
end

local function hasText(c, s)
  for _, fs in ipairs(c:findText(s, true, true)) do
    if fs.GetText and (fs:GetText() or ""):find(s, 1, true) then return true end
  end
  return false
end

for _, late in ipairs({ false, true }) do
  test("r47 l4: the founder's badge picker offers the Founder crown (" .. (late and "name late" or "name ready") .. ")", function()
    local w, c = world(late, "WARLOCK", T.ANITA)
    local W = c.W
    W.UI.Toggle(true) w:advance(2.5)
    if late then
      eq(W.myKey, "?", "name not ready at login")
      c.env.__hideName = false
      c:fire("PLAYER_ENTERING_WORLD") w:advance(1)
    end
    ok(W.IsCreator(W.myKey) == true, "founder key " .. tostring(W.myKey))
    W.UI.OpenSettings() w:advance(2)
    ok(hasText(c, "Founder (automatic)"), "Founder (automatic) tile is offered")
    T.clean(w)
  end)

  test("r47 l4: a Pioneer finds 'Show my Pioneer emblem' (" .. (late and "name late" or "name ready") .. ")", function()
    local w, c = world(late, "MAGE", T.TESTCHAR)
    local W = c.W
    if late then W.myName, W.myKey = "?", "?" end
    W.PIONEERS = { riders = { ["EU-PvE"] = { T.TESTCHAR } }, drivers = { ["EU-PvE"] = {} } }
    W.UI.settings.panel = nil
    W.UI.BuildSettings(W.UI.state.win)
    if late then
      c.env.__hideName = false
      c:fire("PLAYER_ENTERING_WORLD") w:advance(1)
    end
    W.UI.Toggle(true) w:advance(2)
    ok(W.Emblem.Mine() == "rider", "rider Pioneer (control)")
    W.UI.OpenSettings() w:advance(2)
    ok(W.UI.settings.controls.myEmblem ~= nil, "the 'Show my Pioneer emblem' switch exists")
    T.clean(w)
  end)
end
