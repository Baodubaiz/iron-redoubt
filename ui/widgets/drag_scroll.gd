class_name DragScroll
extends ScrollContainer
## ScrollContainer that can be dragged from anywhere inside it, including on top of cards and buttons
## (2026-11-18, user: on phones you could only drag the empty gaps between cards). A press that moves
## more than DEADZONE px becomes a scroll and cancels the press on whatever was under the finger, so a
## drag never buys / opens anything; a short tap still clicks normally.

const DEADZONE := 10.0

var _down := false
var _dragging := false
var _start := Vector2.ZERO
var _last := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if get_global_rect().has_point(mb.position) and _top_scroll_at(mb.position):
				_down = true
				_dragging = false
				_start = mb.position
				_last = mb.position
		else:
			if _dragging:
				get_viewport().set_input_as_handled() # the drag's release must not click anything
			_down = false
			_dragging = false
	elif event is InputEventMouseMotion and _down:
		var mm := event as InputEventMouseMotion
		if not _dragging and mm.position.distance_to(_start) > DEADZONE:
			_dragging = true
			_cancel_press()
		if _dragging:
			scroll_vertical -= int(round(mm.position.y - _last.y))
			if horizontal_scroll_mode != SCROLL_MODE_DISABLED:
				scroll_horizontal -= int(round(mm.position.x - _last.x))
			_last = mm.position
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _dragging:
		get_viewport().set_input_as_handled() # we already scroll from the emulated mouse motion


## Only the innermost DragScroll under the pointer reacts (nested lists).
func _top_scroll_at(p: Vector2) -> bool:
	var n := get_viewport().gui_get_hovered_control()
	while n != null:
		if n is DragScroll:
			return n == self
		n = n.get_parent() as Control
	return true


## Move the pointer off the pressed button, then release it there: it unpresses without emitting `pressed`.
func _cancel_press() -> void:
	var away := Vector2(-10000, -10000)
	var mv := InputEventMouseMotion.new()
	mv.position = away
	mv.global_position = away
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = away
	up.global_position = away
	set_process_input(false)
	get_viewport().push_input(mv)
	get_viewport().push_input(up)
	set_process_input(true)
