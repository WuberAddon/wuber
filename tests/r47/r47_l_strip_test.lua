local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function strip(spot, today, badge, helper)
  local w = T.newWorld()
  local a = T.driver(w, T.ANITA, { spot = spot })
  w:advance(15)
  local W = a.W
  W.Drive.Shards = function() return 10 end
  if badge then W.PIONEERS = { riders = { ["EU-PvE"] = {} }, drivers = { ["EU-PvE"] = { W.myKey } } } end
  W.Drive.Today = function() return today[1], today[2] end
  W.Driver.Today = W.Drive.Today
  if helper then W.Drive.Role = function() return "helper" end end
  T.openDrive(a)
  W.UI.ShowDrive("console")
  w:advance(2)
  return w, W, W.Driver.ui.console
end

local function sample(w, v, n)
  local seen = {}
  for i = 1, n do
    w:advance(1) -- the console's own 1 s refresh
    seen[#seen + 1] = ("gold %spt, fare %s line(s)"):format(tostring(v.status.gold.wuberPx), tostring(v.fare.text.wuberLines or 1))
  end
  return seen
end

test("r47 l: C53r-1: control: a small take never flickers the status strip", function()
  local w, W, v = strip("Ratchet", { 3, 0 }, true)
  local s = sample(w, v, 6)
  for i = 2, #s do eq(s[i], s[1], "control: tick " .. i .. " differs: " .. table.concat(s, " | ")) end
  T.clean(w)
end)

test("r47 l: C53r-1: the take and the fare pill flicker every second when shrinking the take just makes room", function()
  local w, W, v = strip("Ratchet", { 16, 4605500 }, true)
  local s = sample(w, v, 8)
  local same = true
  for i = 2, #s do if s[i] ~= s[1] then same = false end end
  ok(same, "the take's size and the fare's line count change from one second to the next: " .. table.concat(s, " | "))
  T.clean(w)
end)

test("r47 l: C53r-2: control: a driver (fare shown) with a big take shrinks the take to make room for the fare", function()
  local w, W, v = strip("Thunder Bluff", { 16, 46055 }, true)
  ok(v.fare:IsShown(), "control: the driver sees the fare pill")
  ok((v.status.gold.wuberPx or 16) < 16, "control: take shrunk for the fare, px " .. tostring(v.status.gold.wuberPx))
  T.clean(w)
end)

test("r47 l: C53r-2: a crew helper (no fare pill shown) still gets the take shrunk and 'today' dropped for it", function()
  local w, W, v = strip("Thunder Bluff", { 16, 46055 }, true, true)
  ok(W.Driver.Role() == "helper", "setup: this window is a helper's")
  ok(not v.fare:IsShown(), "setup: the fare pill is hidden for a helper")
  local gold = v.status.gold
  local rides = v.status.rides:GetText()
  local full = W.Theme.SIZE.heading -- (design 3) the take's own size is the heading, 17 (it was 16)
  ok((gold.wuberPx or full) == full and rides == "today (16)",
    "the fare pill is hidden, yet the strip made room for it: take drawn at " .. tostring(gold.wuberPx) .. "pt (" .. full .. " wanted), ride count reads '" .. tostring(rides) .. "' (wanted 'today (16)')")
  T.clean(w)
end)
