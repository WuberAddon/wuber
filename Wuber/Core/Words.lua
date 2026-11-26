-- Module: Core.Words
-- Purpose: the one editable data file of blocked words: what a driver's service name or sentence may not
--   contain, and the place nicknames a sentence may use although a service name may not.
-- API: W.Words (BLOCKED, ANYWHERE, ALLOWED_PLACES, ALLOWED_OWN), W.SPAM_WORDS (the same table as W.Words.BLOCKED)
-- Internals: (none)
-- Uses: (none)
-- Later: (none)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/p242/i_words_test.lua
-- From: Core/Places.lua (anti-spam lists, 2.4.2)
--
-- HOW TO EDIT (for the dev team): these are plain lists of lowercase words; Core.Places reads them on every
-- check, so a word added here (or at run time) takes effect at once. Nothing else needs to change.
--
--   ALLOWED_OWN     words refused in a service name and in lines Wuber builds, but let through in a driver's OWN advert
--                   line and own messages ("WTS summons to Ratchet" is their sales line in trade chat). WTB, gold
--                   amounts and links stay refused. Add a word only if it is also in BLOCKED.
--   BLOCKED         whole words a driver's service name may not contain (any case; a plural "s" is ignored;
--                   "g o l d" is caught by joining short pieces). Add a word to block it.
--   ANYWHERE        pieces refused anywhere in the text, even inside another word ("www", "http").
--   ALLOWED_PLACES  place nicknames let through in a driver's own SENTENCE (advert line, messages) although
--                   BLOCKED holds them for service names ("org" is also the web suffix). Not let through when
--                   written as a web address (".org"). Add a nickname only if it is also in BLOCKED.

local _, W = ...
local Mod = W.Module("Core.Words", {})

W.Words = {
	BLOCKED = {
		"gold", "g0ld", "wts", "wtb", "www", "http", "https", "com", "net", "org", "cheap",
		"cheapest", "sell", "selling", "seller", "buy", "buying", "discount", "boost", "boosting",
		"usd", "eur", "dot", "paypal", "powerlevel", "powerleveling",
	},
	ANYWHERE = { "www", "http" },
	ALLOWED_PLACES = { "org" },
	ALLOWED_OWN = { "wts" },
}

-- public name kept: the same table as the blocked list
W.SPAM_WORDS = W.Words.BLOCKED
