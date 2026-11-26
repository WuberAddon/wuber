local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r47 l2: a dimmed Pause pill, clicked while closed pauses the driver", function()
  local w = T.newWorld()
  local a = T.driver(w, T.ANITA, { spot = "Ratchet" })
  w:advance(15)
  local W = a.W
  T.openDrive(a)
  W.UI.ShowDrive("console")
  w:advance(2)
  local v = W.Driver.ui.console
  ok(not W.Drive.IsOpen(), "setup: closed")
  eq(v.pause:GetAlpha(), 0.5, "setup: the Pause pill is dimmed while closed")
  eq(v.pause.label:GetText(), "Pause", "control: it reads Pause")
  ok(not W.Char().paused, "control: not paused before the click")
  a:click(v.pause)
  w:advance(1)
  ok(not W.Char().paused, "the dimmed Pause pill (closed) was clicked and it paused anyway (paused=" .. tostring(W.Char().paused) .. "); the pill now reads '" .. tostring(v.pause.label:GetText()) .. "' and the next Open starts paused")
  T.clean(w)
end)
