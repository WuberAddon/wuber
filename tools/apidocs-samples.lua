-- tools/apidocs-samples.lua (DRAFT): sample calls for tools/apidocs-check.lua checks "returns" and "mrn".
-- name = { args = <list, or function(env) returning one>, empty = <the same, for the case where the game answers nothing> }
-- The checker calls the fake with args and compares the NUMBER of values with the docs' Returns (and, for a MayReturnNothing
-- function, 0 is allowed); with empty it asks a MayReturnNothing function for its no-answer case and expects 0.
-- Only functions listed here are called. Add a line when the fake learns a new function.
local NO = 999999
return {
	-- docs: 11 values (UnitDocumentation.lua#L828, #L870). The fake answers nothing while nothing is cast, so each sample casts first
	-- (a Hearthstone cast, World:castTravel; the ritual in its channel stage, as tests/fga/d_cast_shapes_test.lua does)
	["UnitCastingInfo"] = { args = { "player" }, setup = function(w, c) w:castTravel(c, 8690, 30, "Hearthstone") end },
	["UnitChannelInfo"] = { args = { "player" }, setup = function(w, c)
		local me = w:player(c.player.name)
		me.knowsRitual, me.shards = true, math.max(me.shards or 0, 3) -- a Warlock who knows the ritual and holds a shard
		w:addBot("Dan Miller", { spot = "Ratchet" }) -- another zone than ours, or the cast is refused
		w:group({ c.player.name, "Dan Miller" })
		w:advance(1)
		me.target = w:player("Dan Miller")
		w:cast(c, w.ritualName)
		w:advance(1.2) -- the cast stage lasts 0.5 s, then the channel stage
	end },
	["UnitClass"] = { args = { "player" }, empty = { "party4" } },
	["C_ChatInfo.RegisterAddonMessagePrefix"] = { args = { "WuberChk" } }, -- docs: a RegisterAddonMessagePrefixResult number; the fake gives true
	["C_ChatInfo.SendAddonMessage"] = { args = { "WuberChk", "x", "PARTY" } },
	["C_Map.GetBestMapForUnit"] = { args = { "player" } },
	["C_Map.GetMapInfo"] = { args = { 1454 }, empty = { NO } },
	["C_Map.GetMapChildrenInfo"] = { args = { 1454 }, empty = { NO } },
	["C_Map.GetMapArtLayers"] = { args = { 1454 }, empty = { NO } },
	["C_Map.GetMapArtLayerTextures"] = { args = { 1454, 1 }, empty = { NO, 1 } },
	["C_Map.GetMapInfoAtPosition"] = { args = { 1454, 0.5, 0.5 }, empty = { NO, 0.5, 0.5 } },
	["C_Map.GetWorldPosFromMapPos"] = { args = function(env) return { 1454, env.CreateVector2D(0.5, 0.5) } end,
		empty = function(env) return { NO, env.CreateVector2D(0.5, 0.5) } end },
	["C_Map.GetMapPosFromWorldPos"] = { args = function(env) return { 1, env.CreateVector2D(1000, 1000) } end,
		empty = function(env) return { NO, env.CreateVector2D(0.5, 0.5) } end },
	["C_Spell.GetSpellName"] = { args = { 698 }, empty = { 1 } },
	["C_Spell.GetSpellInfo"] = { args = { 698 }, empty = { 1 } },
	["C_Spell.GetSpellCooldown"] = { args = { 698 }, empty = { 1 } },
}
