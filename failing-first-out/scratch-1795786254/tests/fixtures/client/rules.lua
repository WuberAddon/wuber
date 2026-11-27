-- tests/fixtures/client/rules.lua: the evidence ledger (job 2882). One entry per fake-game rule that rests on a claim about the real client.
-- The harness (tests/harness.lua) calls H.rule("<id>") on each rule's code path; tools/evidence-report.lua joins the two: rules by evidence,
-- and which tests lean on which rule. Library: tests/lib/evidence.lua. Test: tests/fakegame/evidence_ledger_test.lua.
--
-- Fields:
--   id        the name used in H.rule("<id>")
--   what      the rule in a sentence (what the fake does, as if the real client did it)
--   evidence  one-real-case | docs | borrowed | guess      (MEASURED IS NEVER WRITTEN HERE: a rule becomes "measured" only when a WuberProbe
--                     fixture with source = "game" feeds it (fed_by below), with that fixture's build. A fixture made by the simulator
--                     ("sim") or by hand ("synthetic") never counts. The Lab's recorded samples are one-real-case, not measured.)
--     one-real-case   seen in a real client once or a few times (a Lab sample, a recording), not swept
--     docs            the game's own API documentation or interface source says so
--     borrowed        another addon's author says so (addon-learn hints), not checked by us
--     guess           nobody checked
--   source    where the claim comes from (file, report, job)
--   build     the client build the sample was taken on (nil for docs, borrowed and guess)
--   bug       the past real-game bug (B1-B10, tests/../AGENT-RULES list) or the FAKE-GAPS line that rests on this rule; "-" for none
--   was       (optional) what the ledger would have said before the fix of 25 Nov (the proof test uses it)
--   fed_by    (optional) the probe fixture field that measures this rule (dotted path; non-empty = measured)
--   names     (optional) call or method names a changed line uses when it leans on this rule (tools/pr-summary.lua lists the rule for them)
--   differs   (optional) the fake is known to disagree with what was seen; the report prints it next to the rule
return {
	-- textures
	{ id = "tex.file-id", what = "Texture:GetTexture() of an addon file gives a number (a file id), GetTextureFilePath keeps the path",
		evidence = "one-real-case", source = "Lab run 1 (REPORT-243-RUN1-FIXES): the back-arrow finder compared GetTexture() with a path; tests/backarrow/",
		build = "71139", bug = "B1", was = "guess", fed_by = "fileIds", names = { "GetTexture" } },
	-- keys and focus
	{ id = "keys.onkeydown-enables", what = "SetScript(OnKeyDown / OnKeyUp) on a plain frame turns its keyboard input on",
		evidence = "one-real-case", source = "Lab run 2: Settings/Rows.lua keyRow, EnableKeyboard(false) before SetScript(OnKeyDown) ate every key",
		build = "71139", bug = "B3", was = "guess", fed_by = "keys" },
	{ id = "keys.propagate-default-off", what = "GetPropagateKeyboardInput() is false until the addon sets it: a keyboard-enabled frame eats the key",
		evidence = "one-real-case", source = "Lab run 2 (B3: a plain frame ate every key)", build = "71139", bug = "B3", fed_by = "keys" },
	{ id = "edit.focus-outside-click", what = "a click outside a focused EditBox does not clear its focus",
		evidence = "one-real-case", source = "Lab run 2: the Settings search box kept keys after a click elsewhere", build = "71139", bug = "B2", was = "guess" },
	{ id = "keys.editbox-takes-key", what = "a focused, shown EditBox takes a key press: nothing else (no binding, no keyboard frame) sees it",
		evidence = "guess", source = "FAKE-GAPS: key routing in the fake game (tests/fakegame/key_routing_test.lua); not yet seen in a recording", bug = "-" },
	{ id = "keys.propagate-off-swallows", what = "a shown keyboard-enabled frame whose propagate flag is off swallows the key, so a binding does not fire",
		evidence = "guess", source = "FAKE-GAPS: key routing in the fake game (tests/fakegame/key_routing_test.lua); same claim as keys.propagate-default-off, now for routing", bug = "-" },
	-- hit order
	{ id = "hit.clip-ancestor-level", what = "a frame inside a SetClipsChildren ancestor competes with outside frames at the ancestor's strata and level",
		evidence = "one-real-case", source = "tests/fixtures/rec/focus-run3-back.lua: 122 of 122 Lab rows where level order and the game disagreed",
		build = "71139", bug = "B7", was = "guess", fed_by = "hit" },
	{ id = "hit.equal-level-tie", what = "at an equal level the frame outside the clipping ancestor wins",
		evidence = "one-real-case", source = "Lab run 3: the header drag strip beat the tab body (one real case, not every equal-level pair)",
		build = "71139", bug = "B7", fed_by = "hit" },
	{ id = "hit.clipped-child-no-mouse", what = "a child cut off at the point by a clipping ancestor takes no mouse",
		evidence = "one-real-case", source = "Lab run 3 focus samples", build = "71139", bug = "B7", fed_by = "hit" },
	{ id = "hit.scrollframe-rect-clip", what = "a ScrollFrame's own rect does NOT clip the mouse here (a child past its edge still takes it)",
		evidence = "guess", source = "FAKE-GAPS OPEN 'Run 3 buttons' (2): never sampled", bug = "OPEN", fed_by = "hit" },
	{ id = "hit.hitrect-insets", what = "SetHitRectInsets shrinks the rect that takes the mouse",
		evidence = "docs", source = "widget API documentation; no sample (FAKE-GAPS OPEN 'Run 3 buttons' (4))", bug = "OPEN", fed_by = "hit" },
	{ id = "hit.disabled-button-takes-mouse", what = "a disabled Button still takes the mouse (and blocks what is under it)",
		evidence = "guess", source = "FAKE-GAPS OPEN 'Run 3 buttons' (4): never sampled", bug = "OPEN", fed_by = "hit" },
	{ id = "hit.alpha-zero-takes-mouse", what = "a frame with alpha 0 still takes the mouse",
		evidence = "guess", source = "FAKE-GAPS OPEN 'Run 3 buttons' (4): never sampled", bug = "OPEN", fed_by = "hit" },
	{ id = "hit.wheel-only-frames", what = "a frame that only takes the wheel joins the frames under the mouse",
		evidence = "guess", source = "tests/harness.lua Client:framesAt comment: 'an assumption: no real sample has measured a wheel-only frame'", bug = "-" },
	{ id = "event.global-mouse-down", what = "a click fires GLOBAL_MOUSE_DOWN / GLOBAL_MOUSE_UP with the mouse already over the frame",
		evidence = "docs", source = "SystemDocumentation (fga f)", bug = "-" },
	-- text
	{ id = "font.small-width", what = "11 px text is the addon's own measure x 1.06 (H.GAME_TEXT_MARGIN)",
		evidence = "one-real-case", source = "Lab font table check (lab-latest.txt:114): 11 px was 6.7-8.7% wider in game, 14 and 22 px 4.0-4.2%",
		build = "71139", bug = "B10", was = "guess", fed_by = "widths",
		differs = "11 px is 6.7-8.7% wider in game than the flat 6%; labels that fit by under 9% can be cut" },
	{ id = "font.no-wrap", what = "text is never laid out in lines: one line, its one-line width (no wrapping, no extra line for a long word)",
		evidence = "guess", source = "FAKE-GAPS round 29 / HUNT-93 (alert banner and toast line counts are worked out, not measured)", bug = "OPEN", fed_by = "widths" },
	-- secrets
	{ id = "secret.accessor-frames", what = "a named Blizzard frame answers a ConstSecretAccessor with secret values",
		evidence = "docs", source = "API documentation flags (job 2860 API restrictions sweep); which frames: the probe's secretAccessors", bug = "B4", fed_by = "secretAccessors" },
	{ id = "secret.api-returns", what = "a call listed as SecretReturns answers a secret value (UnitGUID, GetRealmName, ...)",
		evidence = "docs", source = "API documentation flags (job 2860); the probe's secretApi measures the list", bug = "B4", fed_by = "secretApi" },
	{ id = "secret.use-raises", what = "concatenating, indexing, calling or doing arithmetic on a secret raises (a compare or a truth test cannot, in Lua 5.1)",
		evidence = "one-real-case", source = "Lab run 3: AutoKeys.lua:108 'attempt to compare a secret boolean value'", build = "71139", bug = "B4",
		differs = "compare and if-test cannot raise on a userdata in Lua 5.1: the fake misses them (FAKE-GAPS OPEN, job 2860)" },
	-- events and environment
	{ id = "event.taximap-opened", what = "opening a flight map fires TAXIMAP_OPENED (unless the world sets noTaxiOpened)",
		evidence = "one-real-case", source = "tests/fixtures/rec/lab-real-facts.lua: 18 flight-map closes on the real client, no TAXIMAP_OPENED at all",
		build = "71037", bug = "B10", was = "guess", fed_by = "events.TAXIMAP_OPENED",
		differs = "the real client never fires it; the fake still does by default (Wuber depends on the event offline)" },
	{ id = "env.realm-empty", what = "GetRealmName() gives \"\" (no realm)",
		evidence = "one-real-case", source = "REC realm.name.empty71037: 9 of 9 logins, four accounts", build = "71037", bug = "B10", fed_by = "env.realm" },
	{ id = "env.project-id", what = "WOW_PROJECT_ID is 18",
		evidence = "one-real-case", source = "Blizzard_ProjectConstants (WOW_PROJECT_CAMELOT) and the recorder's census", build = "71037", bug = "B10", fed_by = "env.project" },
	{ id = "unit.unknown-after-load", what = "a name reads \"\" or \"Unknown\" for a moment after a loading screen or a group change",
		evidence = "one-real-case", source = "Lab / AUD-28: UnitName 'Unknown' briefly after a loading screen", build = "71037", bug = "B10" },
	{ id = "timing.ticker", what = "C_Timer.NewTicker fires exactly every N seconds on the clock the test advances",
		evidence = "guess", source = "FAKE-GAPS REC-G05 / B8: a 0.25 s ticker lagged a Shift-drag in game; the fake ticks on time", bug = "B8", fed_by = "timing" },
	-- code that the client forbids
	{ id = "reload.from-addon-code", what = "ReloadUI() from addon code is blocked (ADDON_ACTION_BLOCKED) and nothing reloads",
		evidence = "one-real-case", source = "Lab run 3: 'action blocked because of taint' (Bar.lua:247, GameFacts2.lua:197)", build = "71139", bug = "B5",
		differs = "OPEN: the real client may say ADDON_ACTION_FORBIDDEN, not BLOCKED (FAKE-GAPS job 2860)" },
	{ id = "combat.secure-frozen", what = "a protected frame (a secure button, or a frame holding one) cannot be shown, hidden, moved or changed in combat",
		evidence = "one-real-case", source = "Logs/taint.log of 19 Nov: 7 blocked actions; the 'Paused during combat' label (B6)", build = "71037", bug = "B6", was = "guess" },
	{ id = "combat.protected-child", what = "a plain frame parented to a secure frame, or anchored to one, is protected too (IsProtected true, so no Show/Hide/SetPoint in a fight); only when a probe fixture taught it (H.protectRule)",
		evidence = "guess", source = "job 2908: WuberProbe protprop (own secure button, a plain child, an anchored frame); no real run yet, the stand-in is synthetic", bug = "B6", fed_by = "protect" },
	{ id = "combat.protected-propagation", what = "a plain frame becomes protected when it holds a secure child (the fake: any descendant)",
		evidence = "guess", source = "FAKE-GAPS job 2860 OPEN 'which frames count as protected'; the pay pill under TradeFrame", bug = "B6" },
	{ id = "combat.can-change-protected", what = "CanChangeProtectedState(frame) is false for a protected frame while the player is in combat",
		evidence = "guess", source = "FAKE-GAPS: protected state in the fake game (tests/fakegame); same claim as combat.secure-frozen, read through the API", bug = "B6" },
	-- frames
	{ id = "drag.anchor-center", what = "a dragged frame is re-anchored by its CENTER",
		evidence = "guess", source = "FAKE-GAPS HUNT-01: the real game picks the point nearest a screen edge or corner", bug = "-" },
	{ id = "frame.clamp-ignored", what = "SetClampedToScreen is stored but never applied (a window saved off screen stays off screen)",
		evidence = "guess", source = "FAKE-GAPS bug hunt job 072: the real game pulls it back", bug = "-" },
}
