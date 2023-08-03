class_name PaintBrush
extends Sprite2D


var brush_size := Vector2.ONE


func _init():
	texture = Texture2DRD.new()
	centered = false
	EventBus.on_brush_changed.connect(_on_brush_changed)


func _process(delta):
	# Adjust the position by half a pixel if brush size is odd
	var odd_adjustment = fmod(brush_size.x, 2.0) * Vector2(0.5, 0.5)
	global_position = Vector2i(get_global_mouse_position() - brush_size / 2.0 + odd_adjustment)


func _on_brush_changed(paint_brush_rd: RID, brush_contour_rd: RID, new_brush_size: Vector2i):
	texture.texture_rd_rid = brush_contour_rd
	brush_size = new_brush_size
