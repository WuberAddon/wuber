-- The layout checker's allow-list (tools/layout-check.lua).
-- Each entry matches a problem by its kind (cut, overlap, under, boxes, windows, clipped, spill, offscreen, tooltip,
-- emptycue, words) and Lua patterns on the shot ("trips/unfolded"), the problem's key (the frames' names: the Wuber file
-- and line that made them, e.g. "Earnings.lua:883(Tokens.lua) hours.1 clipped"), and its detail.
--   reason = "...": meant to be so (an intended overlap). Shown only with --all.
--   known = "...":  a real problem, reported to the lead and not fixed yet: printed as "known", but it does not fail the
--                   check, so the gate stays usable. Delete the entry when the fix lands (the check then guards it).
-- A string Wuber cuts on purpose says so itself (fs.wuberEllipsis) and needs no entry here.
return {
	-------------------------------------------------------------------------
	-- intended
	-------------------------------------------------------------------------
	{ kind = "boxes", detail = "half over HomeMap%.lua:%d+", reason = "rider home and Confirm: the sheet, the filter tags and the cards sit on the map strip on purpose" },
	{ kind = "boxes", screen = "^tipcard", key = "^Tips%.lua:%d+%(Forms%.lua%) fill", detail = "half over Home%.lua:%d+", reason = "the login tip is a sheet over Home's page (design round 2): the page behind it is dimmed and covered on purpose" },
	{ kind = "boxes", key = " over WorldMap%.lua:%d+", reason = "World view: price tags sit beside the pins and the OpenMap hint lies on the map strip on purpose" },
	{ kind = "clipped", key = "^WorldMap%.lua", detail = "view WorldMap%.lua", reason = "World view: a pin's count at the map's edge is cut by the map, as on the game's own map" },
	{ kind = "boxes", key = "^Earnings%.lua:%d+ empty over Earnings%.lua:%d+ cells", reason = "empty Earnings: the 'Open for a few hours' note is drawn on the empty heatmap on purpose" },
	{ kind = "straddle", key = "^Earnings%.lua:%d+.- straddles Earnings%.lua:%d+.-cells", reason = "empty Earnings: the 'Open for a few hours' note is drawn on the empty heatmap on purpose" },
	{ kind = "boxes", screen = "^bug_window", key = "^Bug%.lua:%d+", detail = "half over Home%.lua:%d+", reason = "Report a bug is a full-height sheet over the phone (design round 2): the Home card under it is hidden whole by the sheet's solid fill, which the box check does not know" },
	-- (job 211, the covered kind: a button covered at its centre by another frame that takes the mouse)
	{ kind = "covered", key = "^WuberMinimapButton covered by", reason = "the phone window lies over the minimap button at a big window size (ordinary window layering, as the windows entry below: the button stays on the minimap's rim)" },
	{ kind = "covered", screen = "^tipcard", reason = "the login tip is a sheet over Home's page (design round 2): the Home buttons under it are covered on purpose, the sheet takes the clicks" },
	{ kind = "covered", key = "^WorldMap%.lua:712 Button covered by WorldMap%.lua:765 Button", reason = "World view: a pin's price tag lies on the pin's own button and takes its click (same target)" },
	{ kind = "windows", key = " over Minimap$", reason = "a Wuber window over the minimap button is ordinary window layering (the button stays on the minimap's rim)" },
	{ kind = "boxes", screen = "^finding_grouped", key = "^Booking%.lua:%d+ Frame", detail = "half over Confirm%.lua:%d+ Frame", reason = "Waiting for the driver: the route header sits at the radar's top left corner on purpose" },
	{ kind = "boxes", screen = "^finding", key = "^Confirm%.lua:%d+%(Widgets%.lua%) Frame", detail = "half over Confirm%.lua:%d+ Frame", reason = "Waiting for the driver: the rider level chip sits at the top right corner of the radar's square holder on purpose (the rings are round and do not reach it); seen by the checker since design round 1 gave chips a solid fill" },
	{ kind = "clipped", screen = "^help", detail = "view Panel%.lua:%d+", reason = "Help is one long scrolled page, like Settings: a paragraph at its bottom edge is cut as in any scrolled list (design round 1 moved the text to the card margin, so a paragraph now crosses the edge at the page's top)" },
	{ kind = "clipped", screen = "/folded$", key = "^Build%.lua:%d+%(Tokens%.lua%) ", detail = "view Build%.lua:%d+%(Forms%.lua%) scroll %(bottom", reason = "the Drive console's page scrolls (riders, crew, the community card, Your business): the view's bottom edge cuts what comes next, by design; the soft bottom edge and the thin scroll bar say there is more" },
	{ kind = "clipped", screen = "^raid/unfolded", key = "^Build%.lua:%d+%(Tokens%.lua%) title", detail = "view Build%.lua:%d+%(Forms%.lua%) scroll %(bottom", reason = "the Drive console's page scrolls in the wide view too: since design round 3 (text a size larger) the raid page is a little longer than its view, and the view's bottom edge crosses the next heading (Customers) as on the folded console; whole once scrolled" },
	{ kind = "clipped", screen = "^console_join", key = "^Build%.lua:%d+%(Tokens%.lua%) ", detail = "view Build%.lua:%d+%(Forms%.lua%) scroll %(top", reason = "the Drive console's page scrolls: this scene scrolls it to the join card, so the heading above crosses the view's top edge, as in any scrolled list" },
	{ kind = "clipped", screen = "^wuber_test", detail = "view Panel%.lua:%d+", reason = "Settings is one long scrolled list: the tour scrolls it to the Check my game row, and the row label above crosses the view's top edge, as on every ^settings screen" },
	{ kind = "clipped", screen = "^settings", detail = "view Panel%.lua:%d+", reason = "Settings is one long scrolled list (no cue): rows at its top and bottom edge are cut as in any scrolled list, and the tour scrolls it to a row" },
	{ kind = "clipped", key = "^Cards%.lua:%d+", detail = "view Home%.lua:%d+ Frame", reason = "rider's list (design 2): the drivers are rows of one scrolled card; a row at the list's top or bottom edge is cut there as in any scrolled list (the edge fades) and is whole once scrolled into view" },

	-- (design 2, C: the header's buttons lie over the pages, the tab bar is under them)
	{ kind = "boxes", screen = "^finding", detail = "half over Confirm%.lua:%d+ Frame", reason = "Waiting for the driver: the window's round buttons lie over the top right corner of the radar's square holder; the rings are round and do not reach it" },
	{ kind = "chrome", screen = "^finding", key = "^Confirm%.lua:%d+ Frame", reason = "Waiting for the driver: the radar's square holder (see above)" },
	{ kind = "boxes", screen = "^confirm_dial_low", detail = "half over Confirm%.lua:%d+ Frame", reason = "Confirm, the destination far to the top right of the map strip: the destination pin is part of the map the buttons lie on" },
	{ kind = "chrome", screen = "^confirm_dial_low", key = "^Confirm%.lua:%d+ Frame", reason = "the destination pin on the map strip (see above)" },
	{ kind = "clipped", key = "^Rows%.lua:%d+", detail = "view Build%.lua:%d+%(Forms%.lua%) scroll %(bottom", reason = "the driver's queue is a scrolled list: since its page starts under the window's buttons (44 lower) the tour's last row crosses its bottom edge, as in any scrolled list" },
	{ kind = "clipped", key = "^Earnings%.lua:%d+%(Tokens%.lua%) days%.", detail = "view Console%.lua:%d+%(Forms%.lua%) Frame %(bottom", reason = "the wide Drive page's side pane (Console.lua sidePane: a T.Scroll) holds the title card, today's takings and the heatmap: its last day label is cut by the pane's bottom edge until scrolled; the pane's content height is the sum of every card it lays (Console.lua: p.scroll:SetContentHeight(y + 6), y including the heatmap's height and the top-window line), so the wheel reaches the end and the label is whole once scrolled into view" },
	{ kind = "clipped", screen = "^crew", key = "^Crew%.lua:%d+", detail = "view Screens%.lua:%d+%(Forms%.lua%) Frame %(bottom", reason = "the Crew page is one long scrolled page (Screens.lua: T.Scroll): with the fair split rows (Casters' part, the rule, Run the setup again) a row at the bottom edge is cut until scrolled; Crew.lua adds every row's height to y and ends with s.scroll:SetContentHeight(y + 10), so the wheel reaches the last row whole" },
	{ kind = "clipped", screen = "^earnings_tips", key = "^Earnings%.lua:%d+", detail = "view Screens%.lua:%d+%(Forms%.lua%) Frame %(top", reason = "the Earnings page is a scrolled page (Screens.lua: T.Scroll, content height set from the last row, Earnings.lua s.scroll:SetContentHeight(y)): the tour scrolls it down to the tips, so the chart's legend above crosses the view's top edge, as in any scrolled list; scrolling back up shows it whole" },
	{ kind = "clipped", screen = "^trips", key = "^Trips%.lua:%d+", detail = "view Trips%.lua:%d+ Frame %(bottom", reason = "Trips is a scrolled page with a Scroll for your trips cue: since it starts under the window's buttons the first trip row crosses its bottom edge" },

	-------------------------------------------------------------------------
	-- known: real (or likely real) problems found by the first sweep on 20 Nov (master 68ff797), reported to the lead
	-------------------------------------------------------------------------

	-- (job 2885, #238) text the real game draws wider than the old fake game did: each one has its issue and a fix PR that removes its line.
	{ kind = "windows", screen = "^toast_longword/", known = "#271: a long-word toast lies over the window's buttons at the real game's measured text width (#238); the fix removes this entry" },
	{ kind = "covered", screen = "^toast_longword/", known = "#271: a long-word toast lies over the window's buttons at the real game's measured text width (#238); the fix removes this entry" },

	-- the word rule (tests/layout/words.lua): shots over their word budget on 22 Nov, the most words at any size.
	-- Delete an entry when its rewrite lands (the rule then guards it). Never raise a budget to hide a shot.
	{ kind = "words", screen = "^bird/", known = "17 words today, budget 12: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^button_portal/", known = "126 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^button_summoning/", known = "123 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^button_waiting/", known = "128 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^pay_trade/", known = "43 words today, budget 40: the rider's pay page with the trade open (job 2858's new tour screen); waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^chat_home/", known = "74 words today, budget 70: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^confirm/", known = "53 words today, budget 40: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^confirm_avg", known = "99 words today, budget 40: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^confirm_dial", known = "123 words today, budget 40: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^confirm_usual_", known = "140 words today, budget 40: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^console_open/", known = "125 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^console_summon", known = "135 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^crew/", known = "122 words today, budget 70: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^crew_noanswer_long/", known = "77 words today, budget 70: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^customers/", known = "157 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^customers_serve/", known = "the Customers screen's word count over its budget (as ^customers/), plus the six words of the Don't serve again until pill (design 4, H): waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^note_serve/", known = "the Note sheet's word count over its budget (as ^note/), plus the six words of the Don't serve again until pill (design 4, H): waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^settings_driving/", known = "88 words, budget 70: the two quiet lines of what Wuber won't do (quick wins; the author's own picks of 22 Nov, 25 and 22 words) stand on this page: the author's words are never shortened, so the page is over its budget until he moves them or lets them stand (FOR-TESTCHAR, Design round 4)" },
	{ kind = "words", screen = "^settings_opened/", known = "88 words, budget 70: the two quiet lines of what Wuber won't do (quick wins; the author's own picks of 22 Nov, 25 and 22 words) stand on this page: the author's words are never shortened, so the page is over its budget until he moves them or lets them stand (FOR-TESTCHAR, Design round 4)" },
	{ kind = "words", screen = "^settings_invite/", known = "82 words, budget 70: the two quiet lines of what Wuber won't do (quick wins; the author's own picks of 22 Nov, 25 and 22 words) stand on this page: the author's words are never shortened, so the page is over its budget until he moves them or lets them stand (FOR-TESTCHAR, Design round 4)" },
	{ kind = "words", screen = "^settings_invite_warning/", known = "88 words, budget 70: the two quiet lines of what Wuber won't do (quick wins; the author's own picks of 22 Nov, 25 and 22 words) stand on this page: the author's words are never shortened, so the page is over its budget until he moves them or lets them stand (FOR-TESTCHAR, Design round 4)" },
	{ kind = "words", screen = "^simple_settings_driving/", known = "76 words, budget 70: the two quiet lines of what Wuber won't do (quick wins; the author's own picks of 22 Nov, 25 and 22 words) stand on this page: the author's words are never shortened, so the page is over its budget until he moves them or lets them stand (FOR-TESTCHAR, Design round 4)" },
	{ kind = "words", screen = "^customers_mail/", known = "203 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^customers_queued/", known = "155 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^demand/", known = "145 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^earnings_empty/", known = "71 words today, budget 70: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^earnings_heatmap/", known = "74 words today, budget 70: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^finding_grouped/", known = "141 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^float_", known = "59 words today, budget 40: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^home_usual/", known = "141 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^inflight/", known = "95 words today, budget 12: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^menu_chat/", known = "116 words today, budget 70: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^messages/", known = "132 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^messages_edit/", known = "132 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^messages_line_", known = "94 words today, budget 70: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^note/", known = "86 words today, budget 70: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^pass_driver/", known = "127 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^pass_rider/", known = "42 words today, budget 40: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^rank_card/", known = "57 words today, budget 12: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^rank_own/", known = "130 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^pay/", known = "41 words today, budget 40: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^pay_part/", known = "113 words today, budget 40: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^pvp/", known = "128 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "cut", screen = "^tip_whole", key = "^Rows%.lua:%d+", reason = "design round 4: the scene gives one rider a name too long for its place on purpose, to show the hover tip carrying the name whole" },
	{ kind = "words", screen = "^tip_", reason = "design round 4: the scenes show the console (row_marks, itself over its budget until its rewrite) with a tooltip up; tip_long picks the tip with the MOST words on purpose, to see it wrap. Hover text is read on demand, one tip at a time" },
	{ kind = "words", screen = "^row_marks/", known = "125 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^settings/", known = "129 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^settings_check_long/", known = "158 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^settings_sending/", known = "133 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^settings_undo/", known = "82 words today, budget 70: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^settings_undo_news/", known = "112 words today, budget 120: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^sheet_places/", known = "88 words today, budget 70: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^tipcard/", known = "59 words today, budget 12: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^tracker/", known = "46 words today, budget 40: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^whatsnew/", known = "101 words today, budget 12: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^whatsnew_list/unfolded", known = "177 words today, budget 150 (Reading): in a whole sweep the unfolded phone's own words stand behind the list card (the card itself is three lines); on its own (--screen whatsnew_list) the shot is clean. Test configuration, not the card's text" },
	{ kind = "words", screen = "^wrapped/", known = "66 words today, budget 40: waits for its rewrite (the word rule, plan 3)" },
	{ kind = "words", screen = "^wrapped_summary/", known = "71 words today, budget 40: waits for its rewrite (the word rule, plan 3)" },
}
