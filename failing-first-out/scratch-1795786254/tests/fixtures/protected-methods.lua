-- tests/fixtures/protected-methods.lua: widget methods the 1.60.1 client's API documentation marks protected
-- (IsProtectedFunction on Simple*API / FrameAPICooldown, swept 26 Nov 2026; names only). They are protected only on a
-- PROTECTED frame (a secure button or a frame holding one) IN COMBAT: out of combat, or on an addon's own plain frame, they
-- are free. So this is a fake-game rule (tests/harness.lua: the call is a violation and ADDON_ACTION_BLOCKED fires), never
-- a global ban in tools/forbidden.lua.
return {
	"AddRoleset", "AdjustPointsOffset", "Clear", "ClearAllPoints", "ClearAttribute",
	"ClearAttributes", "ClearPoint", "ClearPointsOffset", "Disable", "Enable",
	"EnableGamePadButton", "EnableGamePadStick", "EnableKeyboard", "EnableMouse", "EnableMouseMotion",
	"EnableMouseWheel", "FocusEnter", "FocusExit", "Hide", "Lower",
	"MouseDown", "MouseUp", "Raise", "RegisterForClicks", "RegisterForMouse",
	"RemoveRoleset", "ResizeToBoundsRect", "SetAllPoints", "SetClampRectInsets", "SetClampedToScreen",
	"SetCollapsesLayout", "SetCooldown", "SetCooldownDuration", "SetCooldownFromDurationObject", "SetCooldownFromExpirationTime",
	"SetCooldownUNIX", "SetEnabled", "SetFixedFrameLevel", "SetFixedFrameStrata", "SetFrameLevel",
	"SetFrameStrata", "SetHeight", "SetHitRectInsets", "SetHorizontalScroll", "SetHyperlinksEnabled",
	"SetID", "SetIgnoreParentScale", "SetMouseClickEnabled", "SetMouseMotionEnabled", "SetParent",
	"SetPassThroughButtons", "SetPoint", "SetPointsOffset", "SetPropagateMouseClicks", "SetPropagateMouseMotion",
	"SetRolesets", "SetRoundLayoutToNearestPixel", "SetScale", "SetScrollChild", "SetShown",
	"SetSize", "SetToDefaults", "SetToplevel", "SetUsingParentLevel", "SetVerticalScroll",
	"SetWidth", "Show", "StartMoving", "StartSizing", "StopMovingOrSizing",
}
