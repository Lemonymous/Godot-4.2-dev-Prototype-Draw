@tool
extends Button


@export var color: Color = Color.WHITE :
	set(value):
		color = value
		_update_stylebox_override()
	get:
		return color


func _init():
	if Engine.is_editor_hint():
		return
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _update_stylebox_override():
	var stylebox_empty = StyleBoxEmpty.new()
	var stylebox_hover = StyleBoxFlat.new()
	stylebox_hover.bg_color = color
	stylebox_hover.border_width_bottom = 2
	stylebox_hover.border_width_left = 2
	stylebox_hover.border_width_right = 2
	stylebox_hover.border_width_top = 2
	stylebox_hover.border_color = Color.BLACK
	stylebox_hover.expand_margin_bottom = 4
	stylebox_hover.expand_margin_left = 4
	stylebox_hover.expand_margin_right = 4
	stylebox_hover.expand_margin_top = 4
	
	var stylebox_normal = StyleBoxFlat.new()
	stylebox_normal.bg_color = color.darkened(0.2)
	
	var stylebox_pressed = StyleBoxFlat.new()
	stylebox_pressed.bg_color = color
	stylebox_pressed.border_width_bottom = 2
	stylebox_pressed.border_width_left = 2
	stylebox_pressed.border_width_right = 2
	stylebox_pressed.border_width_top = 2
	stylebox_pressed.border_color = Color.WHITE
	stylebox_pressed.expand_margin_bottom = 4
	stylebox_pressed.expand_margin_left = 4
	stylebox_pressed.expand_margin_right = 4
	stylebox_pressed.expand_margin_top = 4
	
	var stylebox_focus = StyleBoxFlat.new()
	stylebox_focus.bg_color = color
	stylebox_focus.expand_margin_left = 2
	
	begin_bulk_theme_override()
	add_theme_stylebox_override("disabled", stylebox_empty)
	add_theme_stylebox_override("focus", stylebox_focus)
	add_theme_stylebox_override("hover", stylebox_hover)
	add_theme_stylebox_override("normal", stylebox_normal)
	add_theme_stylebox_override("pressed", stylebox_pressed)
	end_bulk_theme_override()


func _ready():
	_update_stylebox_override()


func _on_pressed():
	if Engine.is_editor_hint():
		return
	EventBus.on_color_button_pressed.emit(color)


func _on_mouse_entered():
	z_index = 1


func _on_mouse_exited():
	z_index = 0
