local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("r34 d: /wuber drive msg thanks reset puts the default message back", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:advance(15)
	local DR = d.W.Drive
	d:slash("/wuber drive msg thanks Cheers {name}, safe travels!")
	eq(DR.Template("thanks"), "Cheers {name}, safe travels!", "control: a custom message is saved")
	d:slash("/wuber drive msg thanks reset")
	ok(DR.Template("thanks") == DR.TEMPLATES.thanks, "reset left '" .. tostring(DR.Template("thanks")) .. "'")
	T.clean(w)
end)

test("r34 d: /wuber drive spell with no word keeps the saved spell", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:advance(15)
	local DR = d.W.Drive
	d:slash("/wuber drive spell Ritual of Summoning")
	eq(DR.opts().ritual, "Ritual of Summoning", "control: a spell name is saved")
	d:slash("/wuber drive spell")
	eq(DR.opts().ritual, "Ritual of Summoning", "the saved spell was erased")
	d:slash("/wuber drive spell reset")
	eq(DR.opts().ritual, "", "reset still clears it")
	T.clean(w)
end)
