local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("b4 api frames: inventory and fake-game conformance", function()
	local rows = assert(loadfile(T.dir .. "/fixtures/client/api/frames.lua"))()
	ok(type(rows) == "table" and #rows >= 140, "frames inventory loaded: " .. tostring(#rows))

	local VALID_EV = { ["one-real-case"] = true, docs = true, borrowed = true, guess = true }
	local seen = {}
	for i, r in ipairs(rows) do
		ok(type(r.name) == "string" and r.name ~= "", "row " .. i .. " has name")
		ok(not seen[r.name], "duplicate name: " .. tostring(r.name))
		seen[r.name] = true
		ok(type(r.calls) == "number" and r.calls >= 1, r.name .. " calls >= 1")
		ok(type(r.first) == "string" and r.first:find("^Wuber/.+:%d+$") ~= nil, r.name .. " first path:line")
		ok(type(r.fake) == "string" and r.fake ~= "", r.name .. " fake description")
		ok(VALID_EV[r.evidence], r.name .. " valid evidence: " .. tostring(r.evidence))
		ok(type(r.source) == "string" and r.source ~= "", r.name .. " source")
		if r.evidence == "one-real-case" then
			ok(type(r.build) == "string" and r.build ~= "", r.name .. " one-real-case has build")
			ok(r.source:find("tests/.+:%d+") ~= nil, r.name .. " one-real-case cites repo path:line")
		else
			ok((type(r.game) == "string" and r.game ~= "") or (type(r.offline) == "string" and r.offline ~= ""),
				r.name .. " non-one-real-case has game or offline")
		end
	end

	local w = T.newWorld()
	local c = w:addClient("Rider", { spot = "Orgrimmar", class = "MAGE" })
	w:advance(1)
	local env = c.env

	local f = env.CreateFrame("Frame", "B4TestFrame", env.UIParent)
	f:SetSize(100, 40)
	f:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
	local b = env.CreateFrame("Button", "B4TestButton", f)
	b:SetSize(80, 24)
	local eb = env.CreateFrame("EditBox", "B4TestEditBox", f)
	eb:SetSize(80, 20)
	eb:SetFont("Fonts\\ARIALN.TTF", 12, "")
	eb:SetText("hi")
	local sf = env.CreateFrame("ScrollFrame", "B4TestScroll", f)
	local sb = env.CreateFrame("Slider", "B4TestSlider", f)
	local ms = env.CreateFrame("ModelScene", "B4TestModelScene", f)
	local actor = ms:CreateActor()
	local tex = f:CreateTexture()
	tex:SetSize(16, 16)
	local line = f:CreateLine()
	local fs = f:CreateFontString()
	fs:SetFont("Fonts\\ARIALN.TTF", 12, "")
	fs:SetText("hello")
	local ag = f:CreateAnimationGroup()
	local animAlpha = ag:CreateAnimation("Alpha")
	local animTrans = ag:CreateAnimation("Translation")
	local animScale = ag:CreateAnimation("Scale")
	local animFlip = ag:CreateAnimation("FlipBook")

	local sampleWidgets = { f, b, eb, sf, sb, ms, actor, tex, line, fs, ag, animAlpha, animTrans, animScale, animFlip }
	local function findWidget(m)
		for _, obj in ipairs(sampleWidgets) do
			if type(obj[m]) == "function" then return obj end
		end
		return nil
	end

	local shapeChecks = {
		["C_NamePlate.GetNamePlateForUnit"] = function()
			eq(type(env.C_NamePlate.GetNamePlateForUnit), "function", "C_NamePlate.GetNamePlateForUnit fn")
			eq(env.C_NamePlate.GetNamePlateForUnit("nameplate1"), nil, "C_NamePlate.GetNamePlateForUnit nil when hidden")
		end,
		["ClearOverrideBindings"] = function()
			eq(type(env.ClearOverrideBindings), "function", "ClearOverrideBindings is function")
		end,
		["CreateColor"] = function()
			local col = env.CreateColor(1, 0.5, 0.25, 1)
			eq(type(col), "table", "CreateColor returns table")
			eq(type(col.GetRGBA), "function", "CreateColor has GetRGBA")
		end,
		["CreateFont"] = function()
			local fnt = env.CreateFont("B4TestFontObj")
			eq(type(fnt), "table", "CreateFont returns table")
		end,
		["CreateFrame"] = function()
			eq(type(f), "table", "CreateFrame returns table")
			eq(f:GetObjectType(), "Frame", "CreateFrame GetObjectType")
		end,
		["GetCursorPosition"] = function()
			local x, y = env.GetCursorPosition()
			ok(type(x) == "number" and type(y) == "number", "GetCursorPosition returns two numbers")
		end,
		["GetMouseFoci"] = function()
			local foci = env.GetMouseFoci()
			eq(type(foci), "table", "GetMouseFoci returns table")
		end,
		["GetMouseFocus"] = function()
			eq(env.GetMouseFocus, nil, "GetMouseFocus is nil (not modelled)")
		end,
		["GetPhysicalScreenSize"] = function()
			local w1, h1 = env.GetPhysicalScreenSize()
			ok(type(w1) == "number" and type(h1) == "number", "GetPhysicalScreenSize returns two numbers")
		end,
		["IsAltKeyDown"] = function()
			eq(type(env.IsAltKeyDown()), "boolean", "IsAltKeyDown returns boolean")
		end,
		["IsControlKeyDown"] = function()
			eq(type(env.IsControlKeyDown()), "boolean", "IsControlKeyDown returns boolean")
		end,
		["IsShiftKeyDown"] = function()
			eq(type(env.IsShiftKeyDown()), "boolean", "IsShiftKeyDown returns boolean")
		end,
		["SetOverrideBindingClick"] = function()
			eq(type(env.SetOverrideBindingClick), "function", "SetOverrideBindingClick is function")
		end,
		["ShowUIPanel"] = function()
			eq(type(env.ShowUIPanel), "function", "ShowUIPanel is function")
		end,
		["StaticPopup_FindVisible"] = function()
			eq(type(env.StaticPopup_FindVisible), "function", "StaticPopup_FindVisible is function")
			eq(env.StaticPopup_FindVisible("NONEXISTENT_POPUP"), nil, "StaticPopup_FindVisible nil when hidden")
		end,
		["StaticPopup_Hide"] = function()
			eq(type(env.StaticPopup_Hide), "function", "StaticPopup_Hide is function")
			eq(env.StaticPopup_Hide("NONEXISTENT_POPUP"), nil, "StaticPopup_Hide returns nil")
		end,
		["StaticPopup_Show"] = function()
			eq(type(env.StaticPopup_Show), "function", "StaticPopup_Show is function")
		end,
	}

	local methodChecks = {
		GetAlpha = function() eq(type(f:GetAlpha()), "number", ":GetAlpha") end,
		GetEffectiveAlpha = function() eq(type(f:GetEffectiveAlpha()), "number", ":GetEffectiveAlpha") end,
		GetScale = function() eq(type(f:GetScale()), "number", ":GetScale") end,
		GetEffectiveScale = function() eq(type(f:GetEffectiveScale()), "number", ":GetEffectiveScale") end,
		GetFrameLevel = function() eq(type(f:GetFrameLevel()), "number", ":GetFrameLevel") end,
		GetFrameStrata = function() eq(type(f:GetFrameStrata()), "string", ":GetFrameStrata") end,
		GetHeight = function() eq(type(f:GetHeight()), "number", ":GetHeight") end,
		GetWidth = function() eq(type(f:GetWidth()), "number", ":GetWidth") end,
		GetLeft = function() eq(type(f:GetLeft()), "number", ":GetLeft") end,
		GetRight = function() eq(type(f:GetRight()), "number", ":GetRight") end,
		GetTop = function() eq(type(f:GetTop()), "number", ":GetTop") end,
		GetBottom = function() eq(type(f:GetBottom()), "number", ":GetBottom") end,
		GetCenter = function()
			local cx, cy = f:GetCenter()
			ok(type(cx) == "number" and type(cy) == "number", ":GetCenter")
		end,
		GetDuration = function() eq(type(animAlpha:GetDuration()), "number", ":GetDuration") end,
		GetFont = function()
			local p, sz = fs:GetFont()
			ok(type(p) == "string" and type(sz) == "number", ":GetFont")
		end,
		GetName = function() eq(f:GetName(), "B4TestFrame", ":GetName") end,
		GetNumLines = function() eq(type(fs:GetNumLines()), "number", ":GetNumLines") end,
		GetNumPoints = function() eq(type(f:GetNumPoints()), "number", ":GetNumPoints") end,
		GetObjectType = function() eq(f:GetObjectType(), "Frame", ":GetObjectType") end,
		GetParent = function() eq(b:GetParent(), f, ":GetParent") end,
		GetPoint = function()
			local pt = f:GetPoint(1)
			eq(type(pt), "string", ":GetPoint")
		end,
		GetSpacing = function() eq(type(fs:GetSpacing()), "number", ":GetSpacing") end,
		GetStringHeight = function() eq(type(fs:GetStringHeight()), "number", ":GetStringHeight") end,
		GetStringWidth = function() eq(type(fs:GetStringWidth()), "number", ":GetStringWidth") end,
		GetUnboundedStringWidth = function() eq(type(fs:GetUnboundedStringWidth()), "number", ":GetUnboundedStringWidth") end,
		GetText = function() eq(fs:GetText(), "hello", ":GetText") end,
		GetVertexColor = function()
			local r1, g1, b1, a1 = tex:GetVertexColor()
			ok(type(r1) == "number" and type(g1) == "number" and type(b1) == "number" and type(a1) == "number", ":GetVertexColor")
		end,
		DoesClipChildren = function() eq(type(f:DoesClipChildren()), "boolean", ":DoesClipChildren") end,
		HasFocus = function() eq(type(eb:HasFocus()), "boolean", ":HasFocus") end,
		IsEnabled = function() eq(type(b:IsEnabled()), "boolean", ":IsEnabled") end,
		IsForbidden = function() eq(type(f:IsForbidden()), "boolean", ":IsForbidden") end,
		IsMouseEnabled = function() eq(type(f:IsMouseEnabled()), "boolean", ":IsMouseEnabled") end,
		IsMouseOver = function() eq(type(f:IsMouseOver()), "boolean", ":IsMouseOver") end,
		IsPlaying = function() eq(type(ag:IsPlaying()), "boolean", ":IsPlaying") end,
		IsProtected = function() eq(type(f:IsProtected()), "boolean", ":IsProtected") end,
		IsShown = function() eq(type(f:IsShown()), "boolean", ":IsShown") end,
		IsTruncated = function() eq(type(fs:IsTruncated()), "boolean", ":IsTruncated") end,
		IsVisible = function() eq(type(f:IsVisible()), "boolean", ":IsVisible") end,
		SetFont = function() eq(type(fs:SetFont("Fonts\\ARIALN.TTF", 12, "")), "boolean", ":SetFont") end,
	}

	for _, r in ipairs(rows) do
		if r.name:sub(1, 1) == ":" then
			local m = r.name:sub(2)
			if r.fake:find("^not modelled: returns nil") then
				eq(f[m], nil, r.name .. " absent on Frame")
				eq(b[m], nil, r.name .. " absent on Button")
			else
				local obj = findWidget(m)
				ok(obj ~= nil, r.name .. " exists on a widget")
				if methodChecks[m] then methodChecks[m]() end
			end
		elseif shapeChecks[r.name] then
			shapeChecks[r.name]()
		else
			error("unhandled API row: " .. r.name)
		end
	end

	T.clean(w)
end)
