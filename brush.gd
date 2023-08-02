class_name Brush
extends Node


@export var brush_size_increment := 1
@export var brush_size := Vector2i(12, 12)


var rd : RenderingDevice
var uniform : RDUniform
var texture_format : RDTextureFormat
var shader : RID
var pipeline : RID
var brush_rd : RID
var brush_set : RID
var clone_brush_rd : RID


func _ready():
	rd = RenderingServer.get_rendering_device()
	shader = Compute.shader(load("res://circle_brush.glsl"), rd)
	pipeline = Compute.pipeline(shader, rd)
	
	texture_format = RDTextureFormat.new()
	texture_format.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.depth = 1
	texture_format.array_layers = 1
	texture_format.mipmaps = 1
	texture_format.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + \
		RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	
	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	
	_create_brush()


func _input(event: InputEvent):
	if event is InputEventMouseButton and event.is_pressed():
		if event.is_action_pressed("scroll_wheel_up"):
			grow_brush(brush_size_increment)
		elif event.is_action_pressed("scroll_wheel_down"):
			grow_brush(-brush_size_increment)


func grow_brush(inc):
	var new_brush_size := Vector2i(brush_size.x + inc, brush_size.y + inc)
	if new_brush_size.x < 1:
		new_brush_size.x = 1
		new_brush_size.y = 1
	
	if brush_size != new_brush_size:
		brush_size = new_brush_size
		_create_brush()


func _create_brush():
	var binned_brush_rd = brush_rd
	brush_rd = RID()
	
	texture_format.width = brush_size.x
	texture_format.height = brush_size.y
	
	# Create paint brush
	var new_brush_rd = rd.texture_create(texture_format, RDTextureView.new())
	rd.texture_clear(new_brush_rd, Color.TRANSPARENT, 0, 1, 0, 1)
	uniform.clear_ids()
	uniform.add_id(new_brush_rd)
	var new_brush_set = rd.uniform_set_create([uniform], shader, 0)
	
	# Create clone brush
	var new_clone_brush_rd = rd.texture_create(texture_format, RDTextureView.new())
	rd.texture_clear(new_clone_brush_rd, Color.BLACK, 0, 1, 0, 1)
	
	await _compute_brush(new_brush_set)
	
	brush_rd = new_brush_rd
	brush_set = new_brush_set
	clone_brush_rd = new_clone_brush_rd
	EventBus.on_brush_changed.emit(brush_rd, clone_brush_rd, brush_size)
	
	#var sprite = $Sprite2D
	#if sprite.texture == null:
		#sprite.texture = Texture2DRD.new()
	#sprite.texture.texture_rd_rid = brush_rd
	
	if rd.texture_is_valid(binned_brush_rd):
		rd.free_rid(binned_brush_rd)


func _compute_brush(new_brush_set: RID):
	var push_constant := PackedFloat32Array()
	push_constant.push_back(brush_size.x)
	push_constant.push_back(brush_size.y)
	push_constant.push_back(1.0)
	push_constant.push_back(0.0)
	
	# Run our compute shader
	var workgroup_count = Vector2i(ceili(brush_size.x / 8.0), ceili(brush_size.y / 8.0))
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, new_brush_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, workgroup_count.x, workgroup_count.y, 1)
	rd.compute_list_add_barrier(compute_list)
	rd.compute_list_end()
	
	#await get_tree().create_timer(1.0).timeout
