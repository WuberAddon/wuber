local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- (the Settings diet) the Who summons row, with its Change button, left Settings; the point stays: a button on a row keeps its
-- raised fill after the mouse leaves it (the row's card colour would make it vanish). Guarded on the buttons that are there now.
test("r47 b: AUD-148  the buttons on Settings rows (Replay, Reset place, Test the alert, Forget) keep their raised fill after the mouse leaves", function()
  local w = T.newWorld()
  local c = T.driver(w, T.BOB)
  T.settle(w)
  c.W.UI.Toggle(true) w:advance(3)
  c.W.UI.OpenSettings("drive") w:advance(1)
  local ctl = c.W.UI.settings.controls
  local function hoverAndLeave(b) b:GetScript("OnEnter")(b) b:GetScript("OnLeave")(b) end
  for _, key in ipairs({ "coach", "drive.resetPos", "drive.bellTest", "drive.bellForget" }) do
    local b = ctl[key]
    ok(b and b.fill, key .. ": the button is found")
    if b and b.fill then
      hoverAndLeave(b)
      eq(b.fill.colour, "raised", key .. ": after the mouse leaves its fill is " .. tostring(b.fill.colour) .. " (the row's own card colour: the button vanishes into the row)")
    end
  end
  T.clean(w)
end)
