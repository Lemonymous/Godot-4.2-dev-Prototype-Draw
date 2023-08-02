extends Camera2D


const MIN_ZOOM_FACTOR := 0.3
const MAX_ZOOM_FACTOR := 3.0
const CURVE_MAX := 25.0
const CURVE_MIN := 0.0
const EASE_SPEED := 50.0


var target_camera := position
var target_zoom := zoom.x
var curve := CurveInput.new(MIN_ZOOM_FACTOR, MAX_ZOOM_FACTOR, CURVE_MAX, CURVE_MIN)
var middle_mouse_down := false


func _input(event: InputEvent):
	_handle_mouse_wheel(event)
	_handle_middle_mouse_button(event)
	_handle_mouse_motion(event)


func _process(delta):
	position.x = easing_func(position.x, target_camera.x, delta)
	position.y = easing_func(position.y, target_camera.y, delta)
	zoom.x = easing_func(zoom.x, target_zoom, delta)
	zoom.y = easing_func(zoom.y, target_zoom, delta)


func _handle_mouse_wheel(event: InputEvent):
	if event is InputEventMouseButton and event.is_pressed():
		var zoom_change = event.get_action_strength("zoom_in") - event.get_action_strength("zoom_out")
		
		if Input.is_action_pressed("modifier_ctrl"):
			zoom_change = 0.0
		if zoom_change == 0.0: return
		
		var mapped = curve.map(target_zoom, CurveInput.decreasing_exponential_curve)
		mapped += zoom_change
		mapped = clampf(mapped, CURVE_MIN, CURVE_MAX)
		var inverse_mapped = curve.inverse_map(mapped, CurveInput.inverse_decreasing_exponential_curve)
		inverse_mapped = clampf(inverse_mapped, MIN_ZOOM_FACTOR, MAX_ZOOM_FACTOR)
		if zoom.x != inverse_mapped:
			target_zoom = inverse_mapped
			target_camera = calculate_target_camera_position()


func _handle_middle_mouse_button(event: InputEvent):
	var is_panning = Input.is_action_pressed("toggle_pan_camera") and Input.is_action_pressed("left_mouse")
	is_panning = is_panning or Input.is_action_pressed("pan_camera")
	
	if is_panning:
		middle_mouse_down = true
	else:
		middle_mouse_down = false


func _handle_mouse_motion(event: InputEvent):
	if event is InputEventMouseMotion and middle_mouse_down:
		target_camera -= event.relative / zoom.x


func calculate_target_camera_position() -> Vector2:
	return get_global_mouse_position() - get_local_mouse_position() * zoom.x / target_zoom


func easing_func(from: float, to: float, delta: float) -> float:
	var rng = to - from
	var easedValue = from + rng * delta * EASE_SPEED
	
	if rng > 0:
		easedValue = min(easedValue, to)
	else:
		easedValue = max(easedValue, to)
	
	return easedValue
