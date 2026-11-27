-- The real client's mouse focus over the back arrow, Settings over Ride, in-game Lab run 3 (job 2748b, 24 Nov 2026, issue #36).
-- Written by hand from two real GetMouseFoci rows of the Lab's run 3 (WuberLab.lua samples). Rects are screen units, as the
-- Lab printed them (l = left, b = bottom). Nothing here is invented: a field with no source says so.
--   strip  = the header drag strip: Frame, level 2, strata HIGH, child of WuberFrame, clips nothing
--   arrow  = the back arrow: Button, level 42, strata HIGH, inside body, a child of WuberFrame (level 2) that clips its children
--   body   = the clipping child of WuberFrame (the tab body), level 2, rect l310.5 b194.5 w414 h690
-- The mouse stood at the two points below; the game's focus was the strip both times (so the arrow got no click).
-- Not recorded (chosen here): the strata of WuberFrame and body (HIGH, as the two rows' strata), WuberFrame's own rect (taken as
-- the body's and the strip's union), and that body takes no mouse (the Lab's rows list only the strip and the arrow as candidates).
return {
	root = { name = "WuberFrame", strata = "HIGH", level = 1, l = 310.5, b = 194.5, w = 414, h = 690 },
	body = { name = "body", level = 2, l = 310.5, b = 194.5, w = 414, h = 690, clips = true },
	strip = { name = "strip", level = 2, l = 310.5, b = 820.1, w = 414, h = 64.4, clips = false },
	arrow = { name = "arrow", level = 42, l = 328.9, b = 833.9, w = 36.8, h = 36.8 },
	mouse = { { x = 352.9, y = 855.8 }, { x = 350.8, y = 850.7 } },
	focus = "strip",
}
