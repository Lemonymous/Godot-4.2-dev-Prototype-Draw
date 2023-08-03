class_name PaintBrush
extends Sprite2D


var size := Vector2.ONE


func _init():
	texture = Texture2DRD.new()
	centered = false
	EventBus.on_brush_changed.connect(_on_brush_changed)


func _process(delta):
	global_position = get_global_mouse_position() - size / 2.0


func _on_brush_changed(paint_brush_rd: RID, brush_contour_rd: RID, brush_size: Vector2i):
	texture.texture_rd_rid = brush_contour_rd
	size = brush_size
