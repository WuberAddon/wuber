local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function at(y, m, d, h) return os.time({ year = y, month = m, day = d, hour = h or 12, min = 0, sec = 0 }) end
test("r34 f: a ride booked inside the zone it goes to is not a 'Longest hop: X to X'", function()
  local w = T.newWorld()
  local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
  w:advance(15)
  local W = r.W
  local here = W.ZoneHere()
  local dest = "The Barrens"
  -- reachable: standing in Ratchet, the booking to the zone is not refused as 'already there'
  eq(W.AlreadyAt(dest), nil, "booking The Barrens from Ratchet is allowed (zone here: " .. tostring(here) .. ")")
  ok(W.ValidDest(dest), "The Barrens is a valid destination")
  W.db.rides = {
    { at = at(2026, 10, 3), dest = dest, driver = "Mia Runner", driverKey = "mia runner", price = 5000, fromZone = here },
  }
  local m = W.Mod("Core.Wrapped").Month(2026, 10)
  eq(m.rides, 1, "control: the October ride is counted")
  local hop = m.longestHop
  ok(not (hop and hop.from == hop.to), "slide 3 would read 'Longest hop: " .. tostring(hop and hop.from) .. " to " .. tostring(hop and hop.to) .. "' (" .. tostring(hop and hop.yards) .. " yards)")
  T.clean(w)
end)
