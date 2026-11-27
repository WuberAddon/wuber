-- Daylight UI mode addon/hook for the fake game (no edits to harness.lua). Loaded by tests/bs/bs2_daylight_test.lua.
-- Checked against the real code: DaylightUI_Skins/Packs/NPC.lua taxiLayout (margin 12, header 36, window grows to
-- 24 + map width / 60 + map height; only InsetBg is re-anchored, TaxiButtonN hang from it), Engine.lua (OnShow: layout
-- now and next frame), DaylightUI_QoL/Flight.lua (DaylightUIFlightTimer 320x74 at TOP 0,-88, mouse off).
-- Simulates DaylightUI_Skins (TaxiFrame resize/re-layout after open, optional omitted TAXIMAP_OPENED),
-- DaylightUI_QoL (DaylightUIFlightTimer bar overlapping WuberInFlight's default spot),
-- and DaylightUI_UnitFrames (hiding Blizzard PartyFrame and showing DaylightUIPartyHeader).

local M = {}

local function ensureInsetAndButtons(H, client, tf, nodes)
	local env = client.env
	local bg = tf.InsetBg
	if not bg then
		bg = H.createFrame(client, "Frame", "TaxiFrameInsetBg", tf)
		tf.InsetBg = bg
	end
	bg:ClearAllPoints()
	-- Blizzard default TaxiFrame layout: 4px left, 6px right/bottom, 24px header
	bg:SetPoint("TOPLEFT", tf, "TOPLEFT", 4, -24)
	bg:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", -6, 6)
	bg:Show()

	local bw = (tf:GetWidth() or 603) - 10
	local bh = (tf:GetHeight() or 638) - 30
	for i, n in ipairs(nodes or {}) do
		local btnName = "TaxiButton" .. i
		local btn = rawget(env, btnName)
		if not btn then
			btn = H.createFrame(client, "Button", btnName, tf)
			btn:SetSize(18, 18)
		end
		local nx = n.x or 0.5
		local ny = n.y or 0.5
		btn:ClearAllPoints()
		btn:SetPoint("CENTER", bg, "TOPLEFT", nx * bw, -ny * bh)
		btn:Show()
	end
end

local function applyDaylightTaxiLayout(tf, nodes, opts)
	local bg = tf.InsetBg
	if not bg then return end
	local mapW = (tf:GetWidth() or 603) - 10
	local mapH = (tf:GetHeight() or 638) - 30
	local margin = 12 -- TAXI_MARGIN (Packs/NPC.lua:348)
	local head = 36   -- Win.COMPACT (Windows/Frame.lua:25)
	local newW = margin + mapW + margin
	local newH = head + margin + mapH + margin

	bg:ClearAllPoints()
	bg:SetPoint("TOPLEFT", tf, "TOPLEFT", margin, -(head + margin))
	bg:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", -margin, margin)

	tf:SetSize(newW, newH)
	if opts.moveTo then
		tf:ClearAllPoints()
		tf:SetPoint("TOPLEFT", tf:GetParent(), "TOPLEFT", opts.moveTo[1], opts.moveTo[2])
	end

	-- TaxiButtons hang from InsetBg, so update their positions in the resized map
	local env = opts.env
	for i, n in ipairs(nodes or {}) do
		local btn = env and rawget(env, "TaxiButton" .. i)
		if btn then
			local nx = n.x or 0.5
			local ny = n.y or 0.5
			btn:ClearAllPoints()
			btn:SetPoint("CENTER", bg, "TOPLEFT", nx * mapW, -ny * mapH)
		end
	end

	local onSize = tf:GetScript("OnSizeChanged")
	if onSize then onSize(tf, newW, newH) end
end

local function showFlightTimer(H, client, dest)
	local env = client.env
	local ft = rawget(env, "DaylightUIFlightTimer")
	if not ft then
		ft = H.createFrame(client, "Frame", "DaylightUIFlightTimer", env.UIParent)
		ft:SetSize(320, 74) -- DaylightUI_QoL/Flight.lua:17,22
		ft:SetPoint("TOP", env.UIParent, "TOP", 0, -88) -- Flight.lua:323
		ft:SetFrameStrata("MEDIUM")
		ft:EnableMouse(false)
		ft.label = ft:CreateFontString(nil, "OVERLAY")
		ft.label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
		ft.label:SetText("FLYING TO")
		ft.name = ft:CreateFontString(nil, "OVERLAY")
		ft.name:SetFont("Fonts\\FRIZQT__.TTF", 22, "")
	end
	ft.name:SetText(tostring(dest or ""))
	ft:Show()
	return ft
end

local function hideFlightTimer(client)
	local ft = rawget(client.env, "DaylightUIFlightTimer")
	if ft then ft:Hide() end
end

function M.attach(H, world, client, opts)
	opts = opts or {}
	if opts.unitFrames then
		if rawget(client.env, "PartyFrame") then client.env.PartyFrame:Hide() end
		local ph = rawget(client.env, "DaylightUIPartyHeader")
		if not ph then
			ph = H.createFrame(client, "Frame", "DaylightUIPartyHeader", client.env.UIParent)
			ph:SetSize(150, 220)
			ph:SetPoint("TOPLEFT", client.env.UIParent, "LEFT", 16, 160)
			ph:Show()
		end
	end

	-- The real TaxiFrame exists from login (Wuber hooks its OnShow then; hookMaps runs at PLAYER_ENTERING_WORLD).
	if rawget(client.env, "TaxiFrame") == nil then
		local g = world.TAXI_FRAMES_FALLBACK or { w = 603, h = 638, x = 16, y = -118 } -- as tests/lib/fakes8.lua FRAMES.TaxiFrame
		local f0 = H.createFrame(client, "Frame", "TaxiFrame", client.env.UIParent)
		f0:SetSize(g.w, g.h)
		f0:SetPoint("TOPLEFT", client.env.UIParent, "TOPLEFT", g.x, g.y)
		f0:SetFrameStrata("HIGH")
		f0:Hide()
		client:fire("PLAYER_ENTERING_WORLD", false, false)
	end

	-- Wrap world.openTaxiMap for this world to simulate Daylight's post-open TaxiFrame layout
	local origOpen = world.openTaxiMap
		world.openTaxiMap = function(self, c, nodes, openOpts)
		if c ~= client then
			return origOpen(self, c, nodes, openOpts)
		end
		-- (REC 22 Nov) the real client never fired TAXIMAP_OPENED: the harness flag w.noTaxiOpened
		local wasOmit = self.noTaxiOpened
		if opts.omitTaximapOpened then self.noTaxiOpened = true end
		origOpen(self, c, nodes, openOpts)
		self.noTaxiOpened = wasOmit

		local tf = rawget(c.env, (openOpts and openOpts.frame) or "TaxiFrame")
		if tf and (not openOpts or openOpts.frame == nil or openOpts.frame == "TaxiFrame") then
			ensureInsetAndButtons(H, c, tf, nodes)
			-- the fake's openTaxiMap sets the frame shown without its OnShow; the real client runs OnShow
			-- (Daylight's and Wuber's hooks), so run it: hidden, then shown
			tf:Hide()
			tf:Show()
			local delay = opts.taxiDelay or 0.2
			self:after(delay, function()
				if tf:IsShown() then
					applyDaylightTaxiLayout(tf, nodes, { moveTo = opts.moveTo, env = c.env })
				end
			end, c, "daylight taxiLayout")
		end
	end

	-- Show/hide DaylightUIFlightTimer on taxi take-off and landing
	if opts.flightTimer ~= false then
		if type(client.env.hooksecurefunc) == "function" then
			client.env.hooksecurefunc("TakeTaxiNode", function(slot)
				local t = client.taxi
				local dest = t and t.nodes and t.nodes[slot] and t.nodes[slot].name
				local takeoff = (t and t.takeoff) or 1
				world:after(takeoff, function()
					if client.player.onTaxi then
						showFlightTimer(H, client, dest)
					end
				end, client, "daylight flightTimer show")
			end)
		end
		local origLand = world.landTaxi
		world.landTaxi = function(self, c, spot, lag)
			origLand(self, c, spot, lag)
			if c == client then hideFlightTimer(client) end
		end
	end
end

return M
