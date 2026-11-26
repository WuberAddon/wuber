-- Wuber Lab (developer only, never ship): AutoSteps5.lua, the Auto check screen "a_census" (job 2630, item 13). DRAFT.
-- One press (it runs inside the Auto check, or  /lab auto a_census ) settles a long list of cheap unknowns, with no step for the player:
--   1 existence roll-call of the game globals the source cannot prove (and the text of the ERR_* strings)
--   2 constants: WOW_PROJECT_ID, GetBuildInfo, realm name calls (type and length only), UnitName("player") (types only), the addon-chat restriction call
--   3 RegisterEvent's return value for every event Wuber registers (a throwaway frame; each one is unregistered at once), plus one made-up name
--   4 geometry: what the edge getters give on a brand-new unplaced Frame, FontString and Texture (how many values), the size of a two-anchor frame
--     in the frame it was anchored and one frame and 0.3 s later, SetClampedToScreen far off screen, GetLeft's units under SetScale(2), strata names, level bounds
--   5 text: GetText fresh / after SetText("") / after SetText(nil), SetFont's return for Wuber's files and a missing one, SetMaxLines 0/1/2, one line's height
--   6 texture: SetGradient / SetGradientAlpha, 4- and 8-value SetTexCoord, SetRotation / GetRotation
-- The measuring is in CensusCore.lua (the same file the fake game's test runs, tests/lib/census_core.lua): this file only starts it, reads the answers
-- and writes them down. Which kind of check, and why: an AUTO CHECK screen, like a_keybinding (AutoSteps3.lua): it needs nothing from the player,
-- takes a second or two (frames and a 0.3 s wait), and the Auto check's report already reads its results.
--
-- Safety: read-only; throwaway frames under two holders it makes itself (never Wuber's), hidden and their scripts cleared at the end; every game call
-- through pcall and type checks; no protected call, no hook, no cvar, nothing sent; it stops with the Auto check in combat. RegisterEvent on a throwaway
-- frame with no OnEvent script does nothing the game could notice, and each event is unregistered at once.
--
-- Where the answer goes: ONE Game facts entry "CENSUS" (G.Put in GameFacts.lua): WuberLabDB.facts.CENSUS[n].a = the flat answers (key -> short string);
-- plus one "info" line per section in the Auto check results (stored because it is not a pass) and a pass / look for the two lines the source already proves.
-- Fixture: ../13-facts-census/import_facts.lua --id CENSUS --out tests/fixtures/rec writes census-<build>.lua = { build, a = {...} }.
-- Needs WuberLab.toc: CensusCore.lua and AutoSteps5.lua after AutoSteps3.lua (AutoSteps5.lua uses L.CensusCore).

local _, L = ...

local K = L.PhotoKit
local str, num, plain = L.str, L.num, L.plain

local SCREENS = L.AUTO_SCREENS
local function screen(s)
	s.auto = true
	SCREENS[#SCREENS + 1] = s
	return s
end
local function data()
	local t = K.tour()
	if not t then return {} end
	t.autoData = t.autoData or {}
	return t.autoData
end
local function result(name, status, detail, step)
	return { name = name, status = status, detail = detail, steps = step and { step } or nil }
end

-- the answers of one section, as one short line (a result's detail is cut at 900 characters)
local function line(a, prefix, keys, max)
	local out = {}
	for _, k in ipairs(keys) do
		local v = a[prefix .. k]
		if v ~= nil then out[#out + 1] = k .. "=" .. tostring(v) end
	end
	local text = table.concat(out, "; ")
	return #text > (max or 600) and (text:sub(1, max or 600) .. "~") or text
end

local function start(d)
	local core = L.CensusCore
	if type(core) ~= "table" then d.startErr = "CensusCore.lua is not loaded" d.done = true return end
	local W = L.W()
	local fonts = type(W) == "table" and type(W.Theme) == "table" and type(W.Theme.FONTS) == "table" and W.Theme.FONTS or nil
	local ok, err = pcall(core.run, _G, function(a)
		d.a = a
		d.done = true
	end, { fonts = fonts })
	if not ok then d.startErr = tostring(err):sub(1, 200) d.done = true end
	L.After(6, function()
		if not d.done then
			d.timeout, d.done = true, true
			pcall(core.cleanup)
		end
	end)
end

screen({ id = "a_census", side = "rider", maxWait = 8,
	title = "Facts census: which game calls exist, constants, event refusals, geometry of unplaced frames, text and texture calls (measured, nothing judged)",
	run = function() return true end,
	ready = function()
		local D = data()
		D.census = D.census or { phase = 0 }
		local d = D.census
		if d.phase == 0 then
			d.phase = 1
			start(d)
			return false
		end
		return d.done == true
	end,
	verify = function()
		local d = data().census or {}
		if d.startErr then return { result("census", "look", "the check itself broke: " .. d.startErr) } end
		local a = d.a
		if type(a) ~= "table" then return "skip", "the census gave no answers" .. (d.timeout and " (it did not finish in 6 s)" or "") end
		local out = {}
		local G = L.GameFacts
		-- the two lines the source already proves
		if a["const.WOW_PROJECT_ID"] == "number:18" then
			out[#out + 1] = result("WOW_PROJECT_ID", "pass", "WOW_PROJECT_ID is 18 (WOW_PROJECT_CAMELOT): the source says so (Blizzard_ProjectConstants/Camelot/ProjectConstants.lua)")
		else
			out[#out + 1] = result("WOW_PROJECT_ID", "look", "WOW_PROJECT_ID is " .. tostring(a["const.WOW_PROJECT_ID"]) .. ", the Blizzard source for this build says 18")
		end
		local bad = {}
		for _, kind in ipairs({ "frame", "fontstring", "texture" }) do
			for _, g in ipairs({ "GetLeft", "GetRight", "GetTop", "GetBottom", "GetCenter", "GetRect", "GetScaledRect" }) do
				local v = a["geo." .. kind .. "." .. g]
				if v ~= nil and v ~= "missing" and not tostring(v):find("^n=0:") then bad[#bad + 1] = kind .. "." .. g .. "=" .. tostring(v) end
			end
		end
		if #bad == 0 then
			out[#out + 1] = result("unplaced edge getters", "pass", "an unplaced frame, font string and texture answer GetLeft/Right/Top/Bottom/Center/Rect/ScaledRect with no value (the docs flag them MayReturnNothing)")
		else
			out[#out + 1] = result("unplaced edge getters", "look", "these gave a value although unplaced: " .. table.concat(bad, "; "):sub(1, 600))
		end
		-- the sections, as lines
		local ex = {}
		for _, name in ipairs(L.CensusCore.EXIST) do ex[#ex + 1] = name .. "=" .. tostring(a["ex." .. name]) end
		out[#out + 1] = result("1 existence", "info", table.concat(ex, "; "):sub(1, 850))
		out[#out + 1] = result("2 constants", "info", line(a, "const.", { "WOW_PROJECT_ID", "WOW_PROJECT_CAMELOT", "GetBuildInfo.sig", "GetBuildInfo.values", "GetRealmName.sig",
			"GetRealmName.len", "GetNormalizedRealmName.sig", "GetNormalizedRealmName.len", "UnitName.sig", "AreOutgoingAddonChatMessagesRestricted" }, 850))
		local refused = {}
		for _, ev in ipairs(L.CensusCore.EVENTS) do
			local v = a["ev." .. ev]
			if v ~= "n=1:boolean:true" then refused[#refused + 1] = ev .. "=" .. tostring(v) end
		end
		out[#out + 1] = result("3 events", "info", (#refused == 0 and "every event answered n=1:boolean:true" or ("not the plain true: " .. table.concat(refused, "; "))):sub(1, 850))
		out[#out + 1] = result("4 geometry", "info", line(a, "geo.", { "two.now.GetWidth", "two.frame1.GetWidth", "two.t0.3.GetWidth", "clamp.now", "clamp.frame1", "clamp.t0.3",
			"scale.now.leftRatio", "scale.now.scaledRectRatio", "frame.GetWidth", "frame.GetPoint" }, 850))
		out[#out + 1] = result("5 text", "info", line(a, "text.", { "GetText.fresh", "GetText.afterEmpty", "SetText.nil", "SetFont.medium", "SetFont.missing", "MaxLines.0", "MaxLines.1", "line.medium.16" }, 850))
		out[#out + 1] = result("6 texture", "info", line(a, "tex.", { "type.SetGradient", "type.SetGradientAlpha", "SetGradient", "SetTexCoord8", "SetRotation", "GetRotation" }, 850))
		if type(G) == "table" and type(G.Put) == "function" then
			local n = 0
			for _ in pairs(a) do n = n + 1 end
			G.Put("CENSUS", ("census: %d answers; WOW_PROJECT_ID %s; SetGradientAlpha %s; edge getters on a new frame %s"):format(n,
				tostring(a["const.WOW_PROJECT_ID"]), tostring(a["tex.type.SetGradientAlpha"]), tostring(a["geo.frame.GetLeft"])), a)
		else
			out[#out + 1] = result("saved", "skip", "no Game facts store (GameFacts.lua not loaded): only the lines above were kept")
		end
		return out
	end })
