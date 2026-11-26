-- The word budget of the layout sweep (the author's answer V-A and V-B of the word rule, plan 3): every picture of the
-- sweep may show only so many words, by its kind. A picture over its budget is a layout hit of kind "words" (key
-- "words"), like a cut text is one; tests/layout/allow.lua can allow it (reason = ...) or list it (known = ...).
-- Edit THIS table to change a budget or to put a shot in another kind. The first row whose pattern matches the shot id
-- (the part before the "/", e.g. "confirm_dial_low") wins; the last row (no pattern) is the default, Working.
--   { kind, pattern (Lua pattern on the shot id, nil = everything else), budget folded, budget unfolded }
-- Counting (tests/layout/engine.lua, E.countWords): the words of every text that shows (not hidden under an opaque
-- box, not clipped away), split on whitespace; "50s" is one word; a text of only punctuation or symbols is 0; the
-- phone's clock is not counted; colour codes and texture escapes are not words.
local Words = {}

Words.TABLE = {
	-- the floating big button and its console, and the chat-frame shot of it
	{ "Float",   "^float_",       40, 40 },
	{ "Float",   "^chat_float",   40, 40 },
	-- Card: appears by itself (tip card, What's new, Skip the bird, the mid-flight offer)
	{ "Card",    "^tipcard",      12, 12 },
	{ "Reading", "^whatsnew_list", 150, 150 }, -- the list the pop-up's [See what's new] opens: a page you chose to read (the 20 rewrites, W-20)
	{ "Card",    "^whatsnew",     12, 12 },
	{ "Card",    "^bird",         12, 12 },
	{ "Card",    "^inflight",     12, 12 },
	{ "Card",    "^rank_card",    12, 12 },
	-- Action: one decision, mid-ride
	{ "Action",  "^confirm",      40, 40 },
	{ "Action",  "^portal",       40, 40 },
	{ "Action",  "^tracker",      40, 40 },
	{ "Action",  "^pass_rider",   40, 40 },
	{ "Action",  "^pay",          40, 40 },
	{ "Action",  "^stranger",     40, 40 },
	{ "Action",  "^done",         40, 40 },
	{ "Action",  "^raincheck",    40, 40 },
	{ "Action",  "^wrapped",      40, 40 },
	{ "Action",  "^simple_confirm", 40, 40 },
	{ "Action",  "^simple_ride",  40, 40 },
	{ "Action",  "^simple_pay",   40, 40 },
	{ "Action",  "^simple_done",  40, 40 },
	-- Reading: you chose to read it
		{ "Reading", "^help",         150, 190 }, -- unfolded 190 (job 2889: the footer also names the Messages lines you switch on; wraps, never cut); was 156: issue #5, the Help footer now carries the approved auto-reply exception ("...without your click, except the short auto-reply to riders who ask in public (Settings can turn it off).")
	{ "Reading", "^bug_window",   150, 150 },
	{ "Reading", "^sheet_",       150, 150 }, -- (job 2525, E) the bug sheet over a page: the sheet is what is read
	{ "Reading", "^wuber_test",   150, 150 },
	-- Working: everything else
	{ "Working", nil,             70, 120 },
}

-- shot: "id/view" (view "folded" or "unfolded") or just the id -> kind, budget
function Words.budget(shot)
	local id, view = tostring(shot):match("^([^/]*)/?(.*)$")
	for _, row in ipairs(Words.TABLE) do
		if row[2] == nil or id:find(row[2]) then
			return row[1], (view == "unfolded") and row[4] or row[3]
		end
	end
	return "Working", 70
end

return Words
