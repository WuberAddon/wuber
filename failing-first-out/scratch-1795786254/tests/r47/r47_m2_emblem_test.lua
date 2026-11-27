local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("r47 m2: AUD-236  the founder's emblem preview sits on top of the founder's own crown", function()
	local w = T.newWorld()
	local r = T.rider(w, T.ANITA)
	local W = r.W
	T.settle(w)
	local crown = W.Plates.SelfCrown()
	ok(crown and crown:IsShown(), "control: the founder's own crown is over her head")
	local _, _, _, _, cy = crown:GetPoint(1)
	eq(cy, 34, "control: crown bottom is 34 on foot")
	W.SlashCommand("emblem preview")
	w:advance(1)
	local h = W.Emblem.SelfHolder()
	ok(h and h:IsShown(), "control: the preview is over her head")
	local _, _, _, _, ey = h:GetPoint(1)
	-- both frames are scaled by the same zoom factor; the crown frame is 46 high
	ok(ey >= cy + 46, "the preview emblem starts at y=" .. tostring(ey) .. " but the crown covers y=" .. cy .. " to " .. (cy + 46) .. ": the emblem is drawn over the crown")
	T.clean(w)
end)

local TESTCHAR, BOB = T.TESTCHAR, T.BOB
test("r47 m2: AUD-237  with crowns and badges off the emblem preview on a Pioneer's plate still floats 28 px too high", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	local W = r.W
	w:addBot(BOB, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)
	W.PIONEERS = { riders = { ["EU-PvE"] = { BOB, TESTCHAR } }, drivers = {} }
	r:showPlate(BOB, { force = true })
	r.player.target = w:player(BOB)
	W.SlashCommand("emblem preview")
	w:advance(2.5)
	local function emb()
		for _, f in ipairs(r:onPlate(BOB)) do if f.orb and f.halo and f.ring then return f end end
	end
	local a = emb()
	ok(a, "control: the preview shows over my target")
	local _, _, _, _, y1 = a:GetPoint(1)
	W.db.plates = false
	W.SlashCommand("emblem preview stop")
	W.SlashCommand("emblem preview")
	w:advance(2.5)
	local b = emb()
	ok(b, "preview still shows with plates off")
	local _, _, _, _, y2 = b:GetPoint(1)
	local want = 2 + W.Emblem.LOOKS[2].lift
	eq(y2, want, "no badge is drawn with crowns and badges off, but the emblem floats at y=" .. tostring(y2) .. " (with badges on " .. tostring(y1) .. "), not " .. want)
	T.clean(w)
end)