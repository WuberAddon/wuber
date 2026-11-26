-- Tests of T.Segmented's lit part (BRIEF20 B1). Loaded by tests/run.lua with its helper table T.
-- In the game a pill's fill kept its alpha when the choice changed while it was not drawn (the top nav,
-- tour #1-17: a clear part stayed clear, a lit one turned solid white). Every segmented choice (the
-- plain gold one, the calm one of the Drive tab and Earnings, the violet Here | World) is lit by a pill
-- that is shown or hidden, never by an alpha change.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- every alpha change after the build is not drawn, as in the game; one on a texture that shows is noted
local function asGame(seg, changed)
	for _, b in ipairs(seg.buttons) do
		for _, r in ipairs({ b:GetRegions() }) do
			if r:GetObjectType() == "Texture" then
				local orig = r.SetVertexColor
				r.SetVertexColor = function(self, cr, cg, cb, ca)
					local _, _, _, a0 = self:GetVertexColor()
					if self:IsShown() and math.abs((ca or 1) - (a0 or 1)) > 0.01 then changed[#changed + 1] = ("%s %.2f -> %.2f"):format(tostring(b.value), a0 or 1, ca or 1) end
					return orig(self, cr, cg, cb, a0)
				end
			end
		end
	end
end

-- the parts that show a fill as the game draws it (a visible texture, alpha over 0.3), and any white one
local function lit(seg)
	local out, white = {}, {}
	for _, b in ipairs(seg.buttons) do
		for _, r in ipairs({ b:GetRegions() }) do
			if r:GetObjectType() == "Texture" and r:IsVisible() then
				local cr, cg, cb, al = r:GetVertexColor()
				if (al or 1) > 0.3 then
					out[#out + 1] = b.value
					if cr > 0.9 and cg > 0.9 and cb > 0.9 then white[#white + 1] = b.value end
					break
				end
			end
		end
	end
	return table.concat(out, ","), table.concat(white, ",")
end

test("theme.segmented: B1 the chosen part is lit as the game draws it (plain, calm, violet; changed while shut, tap, hover)", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	local Th, env = W.Theme, a.env
	local looks = {
		plain = function(s) return s end,
		calm = function(s) return W.Driver.CalmSegmented(s) end,
		violet = function(s) return W.Mod("UI.Rider.WorldMap").calmSeg(s) end,
	}
	for _, look in ipairs({ "plain", "calm", "violet" }) do
		local holder = env.CreateFrame("Frame", nil, env.UIParent)
		holder:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
		holder:SetSize(300, 40)
		local seg = Th.Segmented(holder, {
			{ value = "a", label = "One" }, { value = "b", label = "Two" }, { value = "c", label = "Three" },
		}, "a", nil, 240, 28)
		seg:SetPoint("CENTER", holder, "CENTER", 0, 0)
		looks[look](seg)
		w:advance(0.2)
		local changed = {}
		asGame(seg, changed)
		local function check(want, when)
			local on, white = lit(seg)
			eq(on, want, look .. ", " .. when .. ": the lit part, as the game draws it")
			if look ~= "plain" then eq(white, "", look .. ", " .. when .. ": no solid white part") end
		end
		check("a", "first")
		-- changed while not drawn, then shown again
		holder:Hide()
		seg:SetValue("c")
		holder:Show()
		check("c", "set while shut")
		-- a tap
		a:clickOn(seg.buttons[2])
		w:advance(0.2)
		eq(seg.value, "b", look .. ": the tap chose Two")
		check("b", "a tap")
		-- hover over another part and away; over the chosen one and away
		for _, i in ipairs({ 1, 2 }) do
			local b = seg.buttons[i]
			b:GetScript("OnEnter")(b)
			check("b", "hover " .. i)
			b:GetScript("OnLeave")(b)
			check("b", "after hover " .. i)
		end
		eq(#changed, 0, look .. ": no alpha change on a drawn texture after the build: " .. table.concat(changed, ", "))
		holder:Hide()
	end
	T.clean(w)
end)
