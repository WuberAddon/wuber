local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function mkcard(r, extra)
	local CM = r.W.Mod("UI.Rider.Cards")
	local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	local c = CM.buildCard(parent)
	local d = { name = "Farra Way", key = "farra way", dest = "Ratchet", price = 5000, state = "open", team = 3,
		service = "Farra's Rides", heard = r.env.GetTime() }
	for k, v in pairs(extra or {}) do d[k] = v end
	c.view = d
	CM.fillCard(c, d)
	return c, d, parent
end

test("r47 c: C26r-1: Hide this driver loses its red warning colour after the first hover", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:advance(15)
	local c = mkcard(r)
	c:GetScript("OnClick")(c, "RightButton")
	w:advance(0.6)
	local fs = r:findText("Hide this driver")[1]
	ok(fs, "the right-click menu shows Hide this driver")
	local pill = fs:GetParent()
	local red = { r.W.Mod("Theme.Core") and 0 }
	local function col() local a, b, cc = fs:GetTextColor() return { a, b, cc } end
	local before = col()
	ok(before[1] > 0.6 and before[2] < 0.5, "control: before hover the label is red, got " .. table.concat(before, ","))
	pill:GetScript("OnEnter")(pill)
	pill:GetScript("OnLeave")(pill)
	local after = col()
	ok(after[1] > 0.6 and after[2] < 0.5, "after one hover the red Hide this driver label is " .. table.concat(after, ",") .. " (white) and stays that way")
	T.clean(w)
end)


local function rgb(fs) local r, g, b = fs:GetTextColor() return { r or -1, g or -1, b or -1 } end

test("r47 c: C53r-5: the muted 'Just open the console' link turns white after one hover and stays white", function()
  local w = T.newWorld()
  local a = T.driver(w, T.ANITA, { spot = "Ratchet" })
  w:advance(15)
  local W = a.W
  T.openDrive(a)
  w:advance(2)
  local v
  for k, f in pairs(W.Driver.ui) do if type(f) == "table" and f.skip and f.go and f.skip.label and f.skip.label:GetText() == "Just open the console" then v = f end end
  ok(v, "setup: the welcome screen exists (ui keys)")
  local sk = v.skip
  local m = rgb(sk.label)
  local white = { T.WHITE and 1 or 1, 1, 1 }
  ok(not (m[1] == 1 and m[2] == 1 and m[3] == 1), "control: before hovering the link is muted, rgb " .. table.concat(m, ","))
  sk:GetScript("OnEnter")(sk)
  sk:GetScript("OnLeave")(sk)
  local after = rgb(sk.label)
  local same = math.abs(after[1] - m[1]) < 0.01 and math.abs(after[2] - m[2]) < 0.01 and math.abs(after[3] - m[3]) < 0.01
  ok(same, "after the pointer touched and left the link it is no longer muted: rgb " .. table.concat(after, ",") .. " (was " .. table.concat(m, ",") .. ")")
  T.clean(w)
end)
