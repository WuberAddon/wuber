local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local ANA, BEA, DAN = "Ana Smith", "Bea Jones", "Dan Miller"
local function saved(me, other, captain)
  return { chars = { [key(me)] = { crew = { { name = other, role = "lock", app = true } },
    captain = (me == captain) and "" or captain, wizard = true } } }
end
local function build()
  local w = H.NewWorld({})
  local ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = saved(ANA, BEA, ANA) } })
  local bea = w:addClient(BEA, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = saved(BEA, ANA, ANA) } })
  w:group({ ANA, BEA })
  w:advance(15)
  return w, ana, bea
end
test("r34 e: control - Bea marks Ana 40 s after Ana marked Bea: Bea gets Ana's note", function()
  local w, ana, bea = build()
  ok(ana.W.Drive.SetNote(DAN, "regular"), "Ana notes Dan")
  ok(ana.W.Drive.SetBookOwn(key(BEA), true), "Ana marks Bea")
  w:advance(40)
  ok(bea.W.Drive.SetBookOwn(key(ANA), true), "Bea marks Ana")
  w:advance(15)
  local rec = bea.W.Drive.BookEntry(DAN)
  ok(rec and rec.note == "regular", "control: after 40 s apart Bea has the note")
  T.clean(w)
end)
test("r34 e: Bea marks Ana 3 s after Ana marked Bea: Bea still gets Ana's note soon", function()
  local w, ana, bea = build()
  ok(ana.W.Drive.SetNote(DAN, "regular"), "Ana notes Dan")
  ok(ana.W.Drive.SetBookOwn(key(BEA), true), "Ana marks Bea") -- Ana's BKH goes out, Bea drops it
  w:advance(3)
  ok(bea.W.Drive.SetBookOwn(key(ANA), true), "Bea marks Ana")
  w:advance(30)
  local rec = bea.W.Drive.BookEntry(DAN)
  ok(rec and rec.note == "regular", "Bea marked Ana's window as her own but Ana's notes did not arrive in 30 s (Ana holds her answer back for 10 s after her own unsolicited hello; next try in 5 minutes)")
  T.clean(w)
end)
