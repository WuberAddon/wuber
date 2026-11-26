local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r47 c3: Settings 'Turn on friendly nameplates' hides the Shift+V hint toast", function()
  local w = T.newWorld()
  local c = T.rider(w)
  T.settle(w)
  c.W.db.coach = true
  c.W.UI.Toggle(true) w:advance(3)
  c.W.UI.OpenSettings() w:advance(1)
  local b = c.W.UI.settings.controls.nameplates
  ok(b, "button exists")
  b:GetScript("OnClick")(b)
  w:advance(0.6)
  local shown = T.list(c:visibleTexts())
  ok(#c:findText("Friendly nameplates are on", false, true) > 0, "control: some 'on' toast shows: " .. shown:sub(1, 300))
  ok(#c:findText("Shift+V", false, true) > 0, "the player never sees the 'Shift+V turns them off' hint; only the short toast. Visible: " .. shown:sub(1, 300))
  T.clean(w)
end)


test("r47 c3: key capture stays armed after Settings closes / combat starts / Clear", function()
  local w = T.newWorld()
  local c = T.driver(w, T.BOB)
  T.settle(w)
  c.W.UI.Toggle(true) w:advance(3)
  c.W.UI.OpenSettings("drive") w:advance(1)
  local st = c.W.UI.settings
  local set = st.controls["drive.key"]
  ok(set, "Set button found")
  local clear
  for _, f in ipairs(c:findText("Clear", true, true)) do local p = f:GetParent() if p and p.fill and p.SetLabel and p:GetParent() == set:GetParent() then clear = p end end
  ok(clear, "Clear found")
  local cap
  for _, ch in ipairs({set:GetParent():GetChildren()}) do if ch.GetScript and ch:GetScript("OnKeyDown") then cap = ch end end
  ok(cap, "capture frame found")
  -- control: Set then a key binds it
  set:GetScript("OnClick")(set)
  eq(set.label:GetText(), "Press...", "control: Set arms")
  cap:GetScript("OnKeyDown")(cap, "F5")
  eq(set.label:GetText(), "Set", "control: a key ends the capture")
  -- bug: arm, then Clear (the player changes their mind)
  set:GetScript("OnClick")(set)
  clear:GetScript("OnClick")(clear)
  eq(set.label:GetText(), "Set", "after Clear the Set button still reads '" .. tostring(set.label:GetText()) .. "' and the next key press is swallowed and bound")
  T.clean(w)
end)
test("r47 c3: combat starting while capturing leaves the next key to be bound", function()
  local w = T.newWorld()
  local c = T.driver(w, T.BOB)
  T.settle(w)
  c.W.UI.Toggle(true) w:advance(3)
  c.W.UI.OpenSettings("drive") w:advance(1)
  local st = c.W.UI.settings
  local set = st.controls["drive.key"]
  set:GetScript("OnClick")(set)
  w:enterCombat(c) w:advance(1)
  eq(set.label:GetText(), "Set", "combat started: the capture should be off, but Set still reads '" .. tostring(set.label:GetText()) .. "'")
  T.clean(w)
end)
test("r47 c3: closing Settings while capturing ends the capture", function()
  local w = T.newWorld()
  local c = T.driver(w, T.BOB)
  T.settle(w)
  c.W.UI.Toggle(true) w:advance(3)
  c.W.UI.OpenSettings("drive") w:advance(1)
  local set = c.W.UI.settings.controls["drive.key"]
  set:GetScript("OnClick")(set)
  c.W.UI.CloseSettings(true) w:advance(1)
  eq(set.label:GetText(), "Set", "closed: Set reads '" .. tostring(set.label:GetText()) .. "'")
  T.clean(w)
end)
