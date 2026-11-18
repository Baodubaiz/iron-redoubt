class_name MatchCamera
extends Node
## Zoom + pan over the fixed 1280x720 map (2026-11-18, user: map fixed, screen zooms / scrolls).
## Moves and scales the MatchController node itself, so every screen<->world conversion (placement,
## selection, HUD floaters) keeps working through its canvas transform.
##   phone: pinch with two fingers = zoom, drag one finger on the map = pan
##   desktop: mouse wheel = zoom at the cursor, drag on the map = pan
## A drag never counts as a tap (no tower selection / ghost move on its release). Dragging a tower from
## the palette is left alone (PlacementController PRESS / DRAG).

const MAX_ZOOM := 2.0
const PAN_THRESHOLD := 12.0
const WHEEL_STEP := 1.12

var world: Node2D ## the MatchController
var placement: PlacementController
var play_rect := Rect2(0, 0, 1280, 720) ## screen area the map may use (left of the palette)
var zoom := 1.0
var shake := Vector2.ZERO ## added on top (screen shake)

var _pos := Vector2.ZERO ## screen position of the world origin
var _press := false
var _panning := false
var _swallow_release := false
var _press_at := Vector2.ZERO
var _last := Vector2.ZERO
var _touches := {} ## index -> screen pos
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO


## Default view: zoom 1 at `origin` (the old fixed layout), clamped into the play area.
func reset(origin: Vector2, area: Rect2) -> void:
	play_rect = area
	zoom = 1.0
	_pos = origin
	_apply()


func min_zoom() -> float:
	var z := minf(play_rect.size.x / ScreenLayout.WORLD_SIZE.x, play_rect.size.y / ScreenLayout.WORLD_SIZE.y)
	return clampf(z, 0.3, 1.0)


func zoom_at(screen_pt: Vector2, new_zoom: float) -> void:
	var z := clampf(new_zoom, min_zoom(), MAX_ZOOM)
	var world_pt := (screen_pt - _pos) / zoom
	zoom = z
	_pos = screen_pt - world_pt * zoom
	_apply()


func pan_by(delta: Vector2) -> void:
	_pos += delta
	_apply()


func _apply() -> void:
	var size := ScreenLayout.WORLD_SIZE * zoom
	for axis in [0, 1]:
		var lo: float = play_rect.position[axis]
		var span: float = play_rect.size[axis]
		if size[axis] <= span:
			_pos[axis] = lo + (span - size[axis]) * 0.5 # smaller than the view: keep it centred
		else:
			_pos[axis] = clampf(_pos[axis], lo + span - size[axis], lo) # never show past the map edge
	if world != null:
		world.scale = Vector2(zoom, zoom)
		world.position = (_pos + shake).round() if shake != Vector2.ZERO else _pos


func refresh() -> void:
	_apply()


func _placing_by_drag() -> bool:
	return placement != null and (placement.mode == PlacementController.Mode.PRESS or placement.mode == PlacementController.Mode.DRAG)


## A press that reached here was not taken by any HUD control: it is on the map.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT] and not _placing_by_drag():
			_press = true
			_panning = false
			_press_at = mb.position
			_last = mb.position
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(mb.position, zoom * WHEEL_STEP)
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(mb.position, zoom / WHEEL_STEP)
			get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture: # trackpads
		var g := event as InputEventMagnifyGesture
		zoom_at(g.position, zoom * g.factor)
	elif event is InputEventPanGesture:
		pan_by(-(event as InputEventPanGesture).delta * 8.0)


func _input(event: InputEvent) -> void:
	# --- two-finger pinch (raw touches; the first finger is also emulated as a mouse)
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() >= 2:
			_start_pinch()
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _touches.has(sd.index):
			_touches[sd.index] = sd.position
		if _touches.size() >= 2 and not _placing_by_drag():
			_update_pinch()
			get_viewport().set_input_as_handled()
		return
	# --- one-finger / mouse pan
	if event is InputEventMouseMotion and _press:
		var mm := event as InputEventMouseMotion
		if _touches.size() >= 2 or _placing_by_drag():
			return
		if not _panning and mm.position.distance_to(_press_at) > PAN_THRESHOLD:
			_panning = true
			_swallow_release = true
		if _panning:
			pan_by(mm.position - _last)
			get_viewport().set_input_as_handled()
		_last = mm.position
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			return
		_press = false
		_panning = false
		if _swallow_release:
			_swallow_release = false
			get_viewport().set_input_as_handled() # a drag / pinch is not a tap


func _start_pinch() -> void:
	var pts: Array = _touches.values()
	_pinch_dist = maxf((pts[0] as Vector2).distance_to(pts[1]), 1.0)
	_pinch_mid = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
	_panning = false
	_swallow_release = true


func _update_pinch() -> void:
	var pts: Array = _touches.values()
	var d := maxf((pts[0] as Vector2).distance_to(pts[1]), 1.0)
	var mid := ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
	pan_by(mid - _pinch_mid)
	zoom_at(mid, zoom * d / _pinch_dist)
	_pinch_dist = d
	_pinch_mid = mid
