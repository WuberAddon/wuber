-- Wuber Lab's Pioneer emblem check (WuberLab/Emblem.lua, BRIEF15 agent B): the scene asks the tester Yes/No
-- about each look of Wuber's local emblem preview and puts his own look back. Developer only; loaded
-- by tests/run.lua, skipped when the lab (or its Emblem.lua) isn't there.
local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, settle, clean, HAVE_UI = T.newWorld, T.settle, T.clean, T.HAVE_UI

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not (H.exists(LAB_DIR .. "/WuberLab.toc") and H.exists(LAB_DIR .. "/Emblem.lua")) then
	test("lab emblem: this Wuber Lab has no Emblem.lua - skipped", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local ANITA, FARRA = "Anita Lift", "Farra Way"
local IDS = { "em_look1", "em_look2", "em_look3", "em_driver", "em_plate" }

local function result(c, id)
	local run = c.env.WuberLabDB.run
	return run and run.results[id]
end
local function step(c)
	local run = c.env.WuberLabDB.run
	return run and not run.ended and run.steps[run.index] or nil
end

local function labWorld()
	local w = newWorld()
	local c = w:addClient(ANITA, { spot = "Orgrimmar", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	w:addBot(FARRA, { spot = "Orgrimmar", class = "MAGE" })
	settle(w)
	return w, c, c.ns.WuberLab
end

test("lab emblem: five Yes/No checks in one loose, one-window scene of its own ('/lab run emblem', not in Start test run), judged where the tester answers", function()
	local w, c, L = labWorld()
	local S = L.RUN_SCENE_BY_ID.emblem
	ok(S and not S.linked and S.loc and S.only, "scene emblem: loose, one window, its own tool")
	local all = L.RunWanted({ all = true, online = function() return true end })
	for _, id in ipairs(all) do ok(L.RUN_BY_ID[id].scene ~= "emblem", id .. " is not in Start test run") end
	local n = 0
	for _, ch in ipairs(L.RUN_CHECKS) do if ch.scene == "emblem" then n = n + 1 end end
	eq(n, #IDS, "the emblem's checks")
	for _, id in ipairs(IDS) do
		local ch = L.RUN_BY_ID[id]
		ok(ch and ch.ask, id .. " asks the tester")
		eq(ch and ch.who, "driver", id .. " on Anita's window")
		eq(ch and ch.judge, "driver", id .. " judged there")
	end
	clean(w)
end)

test("lab emblem: each look is previewed and asked; the answers are kept with the model; the tester's own look comes back; nothing is sent", function()
	local w, c, L = labWorld()
	local W = c.W
	W.db.emblemLook = 3 -- The tester's own pick
	local sent = #w.addonLog
	ok(L.RunStart({ scene = "emblem", sim = false }), "started")
	eq(step(c), "em_look1")
	w:advance(1)
	local h = W.Emblem.SelfHolder()
	ok(h and h:IsShown(), "the preview over Anita's head")
	eq(W.Emblem.Look(), 1, "look 1 shown")
	ok(L.RunAnswer(true), "answered Yes")
	eq(result(c, "em_look1") and result(c, "em_look1").r, "pass")
	ok(tostring(result(c, "em_look1").why):find("look 1 (Ring)", 1, true), "the note names the look: " .. tostring(result(c, "em_look1").why))
	ok(tostring(result(c, "em_look1").why):find("model:", 1, true), "and the model")
	w:advance(1)
	eq(step(c), "em_look2")
	w:advance(1)
	eq(W.Emblem.Look(), 2, "look 2 shown")
	ok(L.RunAnswer(false), "answered No")
	eq(result(c, "em_look2").r, "fail", "a No fails it")
	w:advance(1)
	eq(step(c), "em_look3")
	w:advance(1)
	ok(L.RunAnswer(true))
	w:advance(1)
	eq(step(c), "em_driver")
	w:advance(1)
	eq(W.Emblem.SelfHolder().kind, "driver", "the drivers' colour")
	ok(L.RunAnswer(true))
	w:advance(1)
	eq(step(c), "em_plate")
	w:advance(1)
	c.player.target = w:player(FARRA)
	c:showPlate(FARRA, { force = true })
	w:advance(3)
	ok(W.Emblem.Count() > 0, "the preview on Farra's plate")
	ok(L.RunAnswer(true))
	eq(result(c, "em_plate").r, "pass")
	w:advance(1)
	ok(not W.Emblem.SelfHolder():IsShown(), "the preview is off at the end")
	eq(W.Emblem.Count(), 0)
	eq(W.db.emblemLook, 3, "The tester's look kept")
	local extra = {}
	for i = sent + 1, #w.addonLog do extra[#extra + 1] = w.addonLog[i].prefix .. " " .. w.addonLog[i].text end
	local lab = 0
	for _, e in ipairs(extra) do if not e:find("^WUBER ") then lab = lab + 1 end end
	eq(lab, 0, "the lab sent nothing (one window): " .. list(extra, "; "))
	clean(w)
end)

test("lab emblem: '/lab run emblem' starts the scene alone", function()
	local w, c, L = labWorld()
	c:slash("/lab run emblem")
	w:advance(1)
	eq(step(c), "em_look1", "the emblem scene started")
	ok(c.W.Emblem.SelfHolder() and c.W.Emblem.SelfHolder():IsShown(), "the preview shows")
	ok(L.RunStop("test over"), "stopped")
	clean(w)
end)

test("lab emblem: in test mode every emblem check is skipped (only the tester can see it)", function()
	local w, c, L = labWorld()
	ok(L.RunStart({ scene = "emblem", sim = true }), "started")
	w:advance(5)
	for _, id in ipairs(IDS) do eq(result(c, id) and result(c, id).r, "skip", id) end
	ok(not c.W.Emblem.SelfHolder() or not c.W.Emblem.SelfHolder():IsShown(), "no preview")
	clean(w)
end)
