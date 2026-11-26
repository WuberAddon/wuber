local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

-- a driver at Undercity, open, with rider Dan (arrived, fare 50s) in the list
local function landed(opts)
	local w = T.newWorld(opts)
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local A = a.W.Drive
	A.SetOpt("autoTrade", false)
	A.SetOpen(true)
	w:addBot("Dan Miller", { spot = "Undercity" })
	local c = { name = "Dan Miller", key = "dan miller", state = "arrived", price = 5000, paid = 0, at = 0, tries = 1 }
	A.customers["dan miller"] = c
	return w, a, A, c
end

test("r33 AUD-70: control, a manual whisper to a rider with no box left open marks nothing as sent", function()
	local w, a, A, c = landed()
	a.chatBox = "/w Dan-Miller hello there"
	a:enter()
	w:advance(1)
	ok(not c.reminded, "control: pay reminder not marked sent")
end)

test("r33 AUD-70: a pay reminder cancelled with Escape is not marked sent by a chat minutes later", function()
	local w, a, A, c = landed()
	ok(A.OpenBox(c, "pay"), "the pay reminder goes into the chat box")
	w:advance(0.2)
	ok(a.chatBox and a.chatBox:find("^/w Dan%-Miller"), "it waits in the chat box: " .. tostring(a.chatBox))
	a.chatBox = nil                         -- the driver presses Escape: nothing was sent
	w:advance(1)
	ok(not c.reminded, "nothing sent yet, so not marked")
	w:advance(300)                          -- five minutes pass
	a.chatBox = "/w Dan-Miller hello there"  -- the driver whispers Dan about something else
	a:enter()
	w:advance(1)
	eq(c.reminded, nil, "the pay reminder was cancelled 5 minutes ago and never sent, yet Wuber now counts it as sent (reminded=" .. tostring(c.reminded) .. ")")
	T.clean(w)
end)
