-- r50 group I: AU24-03, a buying line is a buyer even with "whisper me" / "ready".
local T = ...
local test, eq = T.test, T.eq

local function reader()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	return a.W.Drive
end

test("r50 I: a line that asks to buy is a buyer even with whisper me or ready", function()
	local DR = reader()
	for _, l in ipairs({ "wtb summon to org, whisper me", "LF summon to org, whisper me", "LFS org whisper me",
		"wtb summon org, ready now", "lf summon to org, I'm ready", "WTB summon to Orgrimmar, whisp me" }) do
		eq(DR.PublicWant(l), "match", l)
	end
end)

-- guard: sellers and [Wuber] lines were never buyers on the base
test("r50 I: a seller advert stays a seller, and a [Wuber] line is never a buyer", function()
	local DR = reader()
	for _, l in ipairs({ "WTS summons to org, whisper me", "Selling summons to org ready, whisper me",
		"summons to org ready, whisper me", "LFM summon to org, whisper me",
		"[Wuber] wtb summon to org, whisper me", "[Wuber] LF summon to org ready" }) do
		eq(DR.PublicWant(l), nil, l)
	end
end)

-- guard: the pst me and w me lines were buyers already
test("r50 I: guard, pst me and w me buyer lines still match", function()
	local DR = reader()
	eq(DR.PublicWant("wtb summon to org, pst me"), "match", "pst")
	eq(DR.PublicWant("wtb summon to org w me"), "match", "w me")
end)

test("r50 I: Careful keeps a buyer in Trade who says whisper me, not a seller or [Wuber] line", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	eq(DR.Careful("wtb summon to orgrimmar, whisper me", "public"), "lead", "buyer is a lead, not ignored")
	for _, l in ipairs({ "WTS summon to orgrimmar, whisper me", "selling summons orgrimmar ready, whisper me",
		"[Wuber] wtb summon to orgrimmar, whisper me" }) do
		eq(DR.Careful(l, "public"), "ignore", l)
	end
end)
