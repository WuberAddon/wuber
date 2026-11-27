-- tools/forbidden.lua: what this game client forbids to addons. ONE list for the whole repo.
-- Touching any of these shows the player the "blocked from an action only available to the
-- Blizzard UI" popup (ADDON_ACTION_FORBIDDEN, function "UNKNOWN()").
--
-- HOW TO ADD A RESTRICTION FROM taint.log (the day it is found):
--   1. In game, /console taintLog 1, play until the popup shows; the file is
--      World of Warcraft\_forever_\Logs\taint.log (copy it: the next game start begins it again).
--   2. lua5.1 tools/taint.lua "<that taint.log>"   (read-only) lists each blocked action, the addon
--      lines on its stack and the names on them not on this list, with a ready line for each.
--   3. Check by hand which name the game really blocks; add ONE line below with the evidence in why.
--      That is all: check.lua then fails on the name in Wuber and the lab, and the fake client raises
--      ADDON_ACTION_FORBIDDEN on it (event, api or method) and fails the test (tests/tools/forbidden_test.lua).
--   4. Fix the addon code check.lua points at; run the suite.
--
-- Read by:
--   tools/check.lua   fails when a Wuber file, or the lab addon's (WUBER_LAB_DIR, default
--                     lab/WuberLab when there), names one outside a comment
--   tests/harness.lua the fake client raises ADDON_ACTION_FORBIDDEN, records a violation and errors
--                     when addon code registers/unregisters an event here, calls an API here or
--                     calls a frame method here
--
-- name: the event or function name as code spells it; kind: "event" (RegisterEvent,
-- RegisterUnitEvent, UnregisterEvent), "api" (a call; path = where it lives in the globals) or
-- "method" (a frame method, frame:Name()); fake = false: only check.lua uses the entry, the fake client does not replace it;
-- why: the evidence. Add to the list when the game forbids something new; never remove without proof.
-- (#234) The client's own API documentation (1.60.1, swept 26 Nov 2026) marks these SecureOnly or protected: an addon
-- may not call them. Families are listed by name below, each as a dotted name, so check.lua and the fake client see
-- every one.
local function family(ns, names, why)
	local out = {}
	for _, n in ipairs(names) do out[#out + 1] = { name = ns .. "." .. n, kind = "api", path = { ns, n }, why = why } end
	return out
end

local list = {
	{ name = "COMBAT_LOG_EVENT_UNFILTERED", kind = "event",
		why = "client build 70959 (Nov 2026): registering or unregistering it is forbidden (taint.log, round 12)" },
	{ name = "CombatLogGetCurrentEventInfo", kind = "api", path = { "CombatLogGetCurrentEventInfo" },
		why = "the combat log's reader: no use without the event (round 12)" },
	{ name = "SendCharacterInvitation", kind = "api", path = { "C_Club", "SendCharacterInvitation" },
		why = "client build 70959: community invites from addons are forbidden (taint.log, round 12)" },
	{ name = "RegisterAllEvents", kind = "method",
		why = "a frame registered for every event gets COMBAT_LOG_EVENT_UNFILTERED too (round 12 review)" },
	-- Wuber's OWN rule, not the client's (payment by mail, the author's decision of 21 Nov 2026): Wuber
	-- prepares and explains, the player sends the mail himself. Wuber never fills the mail window, never
	-- sets its money box, never sends a mail and never takes anything out of one; it only reads the
	-- inbox headers (Drive.Mail). Like the trade's money call (the fake client raises on that one in
	-- tests/harness.lua), none of these may be named in a Wuber file.
	{ name = "SetSendMailMoney", kind = "api", path = { "SetSendMailMoney" },
		why = "Wuber's rule: never puts gold in a mail; the player types the amount" },
	{ name = "SetSendMailCOD", kind = "api", path = { "SetSendMailCOD" },
		why = "Wuber's rule: never asks for gold by a cash-on-delivery mail" },
	{ name = "SendMail", kind = "api", path = { "SendMail" },
		why = "Wuber's rule: never sends a mail; the player clicks Send" },
	{ name = "ClickSendMailItemButton", kind = "api", path = { "ClickSendMailItemButton" },
		why = "Wuber's rule: never attaches anything to a mail" },
	{ name = "TakeInboxMoney", kind = "api", path = { "TakeInboxMoney" },
		why = "Wuber's rule: never takes gold out of a mail; the driver does" },
	{ name = "TakeInboxItem", kind = "api", path = { "TakeInboxItem" },
		why = "Wuber's rule: never takes anything out of a mail" },
	{ name = "AutoLootMailItem", kind = "api", path = { "AutoLootMailItem" },
		why = "Wuber's rule: never empties a mail" },
	{ name = "ReturnInboxItem", kind = "api", path = { "ReturnInboxItem" },
		why = "Wuber's rule: never sends a mail back" },
	{ name = "DeleteInboxItem", kind = "api", path = { "DeleteInboxItem" },
		why = "Wuber's rule: never deletes a mail" },
	-- (#234) the client says no (API documentation 1.60.1, Environment = "SecureOnly" or IsProtectedFunction)
	{ name = "GetForbiddenObjectTable", kind = "api", path = { "GetForbiddenObjectTable" },
		why = "client 1.60.1 API documentation: Environment SecureOnly (job 2855, 26 Nov 2026)" },
	{ name = "C_TooltipComparison.CompareItem", kind = "api", path = { "C_TooltipComparison", "CompareItem" },
		why = "client 1.60.1 API documentation: IsProtectedFunction (job 2855, 26 Nov 2026)" },
	-- ReloadUI from addon code: the client blocks it (taint; the maintainer's report of 25 Nov 2026, PF-050 L13.blocked;
	-- still called by the lab bar and the old Sheets pill until #230). The player types /reload or clicks a secure button.
	-- fake = false: check.lua bans the name in Wuber and the lab; the fake client keeps its own answer (it blocks the
	-- call and records it in client.reloadForbidden, tests/fakegame/reload_forbidden_test.lua)
	{ name = "ReloadUI", kind = "api", path = { "ReloadUI" }, fake = false,
		why = "ReloadUI called from addon code is blocked as tainted (PF-050 L13.blocked, job 2855; #230)" },
}
for _, f in ipairs(family("C_CombatLogSecure", {"AddEventFilter","ClearEventFilters","CombatLogApplyFilterSettings","CombatLogMessage","CombatLogRefilterEntries","CreateCombatLogMessage","GetCurrentEntryInfo","GetCurrentEventInfo","GetEntryCount","SeekToNewestEntry","SeekToPreviousEntry","ShouldShowCurrentEntry"}, "client 1.60.1 API documentation: Environment SecureOnly: the combat log's secure API is closed to addons (job 2855, 26 Nov 2026)")) do list[#list + 1] = f end
for _, f in ipairs(family("C_PingSecure", {"ClearHitTestPingInfo","CreateFrame","DisplayError","GetTargetPingReceiver","SendHitTestPing","SendPingResult","SendPlayerItemPing","SendPlayerSpellCategoryPing","SendPlayerSpellPing","SendUnitPing","SetHitTestPingTarget","SetHitTestTargetAndSendPing","SetPendingPingOffScreenCallback","SetPingCooldownStartedCallback","SetPingPinFrameAddedCallback","SetPingPinFrameRemovedCallback","SetPingPinFrameScreenClampStateUpdatedCallback","SetPingRadialWheelCreatedCallback","SetSendMacroPingCallback","SetTogglePingListenerCallback"}, "client 1.60.1 API documentation: Environment SecureOnly: the ping system's secure API is closed to addons (job 2855, 26 Nov 2026)")) do list[#list + 1] = f end
return list
