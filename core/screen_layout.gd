class_name ScreenLayout
extends RefCounted
## Landscape layout helpers: safe-area insets (notches / rounded corners / gesture bars) in canvas
## units, and centring of the fixed 1280x720 world inside whatever aspect ratio the device has.
## Dev/test override: run with `-- --fake-safe-area=L,T,R,B` (canvas units).

const WORLD_SIZE := Vector2(1280, 720)


static func zero() -> Dictionary:
	return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}


static func _fake() -> Variant:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fake-safe-area="):
			var p := a.substr(17).split(",")
			if p.size() == 4:
				return {"left": float(p[0]), "top": float(p[1]), "right": float(p[2]), "bottom": float(p[3])}
	return null


## Insets of the unsafe screen edges, converted to canvas units of `vp`.
static func insets(vp: Viewport) -> Dictionary:
	var fake: Variant = _fake()
	if fake != null:
		return fake
	if vp == null or not OS.has_feature("mobile"):
		return zero() # desktop window: whole window is safe
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return zero()
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var pos := Vector2(DisplayServer.window_get_position())
	return from_rects(Rect2(pos, win), safe, vp.get_visible_rect().size)


## Pure conversion (unit-tested): window rect + safe rect in screen pixels -> canvas-unit insets.
static func from_rects(window: Rect2, safe: Rect2, visible: Vector2) -> Dictionary:
	var sx := visible.x / window.size.x
	var sy := visible.y / window.size.y
	return {
		"left": maxf(0.0, safe.position.x - window.position.x) * sx,
		"top": maxf(0.0, safe.position.y - window.position.y) * sy,
		"right": maxf(0.0, window.end.x - safe.end.x) * sx,
		"bottom": maxf(0.0, window.end.y - safe.end.y) * sy,
	}


## Where to put the world's origin so it is centred inside the safe area (never negative).
static func world_offset(visible: Vector2, ins: Dictionary) -> Vector2:
	var avail := Vector2(visible.x - ins["left"] - ins["right"], visible.y - ins["top"] - ins["bottom"])
	return Vector2(
		ins["left"] + maxf(0.0, (avail.x - WORLD_SIZE.x) * 0.5),
		ins["top"] + maxf(0.0, (avail.y - WORLD_SIZE.y) * 0.5))


static func apply_to_control(c: Control, ins: Dictionary) -> void:
	c.offset_left = ins["left"]
	c.offset_top = ins["top"]
	c.offset_right = -ins["right"]
	c.offset_bottom = -ins["bottom"]
