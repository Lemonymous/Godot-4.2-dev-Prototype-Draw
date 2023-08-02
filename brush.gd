class_name Brush
extends Node


const MIN_BRUSH_SIZE = 4


@export var brush_size_increment := 1
@export var brush_size := Vector2i(12, 12)


var rd : RenderingDevice
var compute : Compute
var uniform : RDUniform
var texture_format : RDTextureFormat
var paint_brush_rd : RID
var paint_brush_set : RID


func _ready():
	rd = RenderingServer.get_rendering_device()
	compute = Compute.new("res://circle_brush.glsl")
	
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
		if event.is_action_pressed("brush_size_increase"):
			grow_brush(brush_size_increment)
		elif event.is_action_pressed("brush_size_decrease"):
			grow_brush(-brush_size_increment)


func grow_brush(inc):
	var new_brush_size := Vector2i(brush_size.x + inc, brush_size.y + inc)
	if new_brush_size.x < MIN_BRUSH_SIZE:
		new_brush_size.x = MIN_BRUSH_SIZE
		new_brush_size.y = MIN_BRUSH_SIZE
	
	if brush_size != new_brush_size:
		brush_size = new_brush_size
		_create_brush()


func _create_brush():
	var binned_brush_rd = paint_brush_rd
	paint_brush_rd = RID()
	
	texture_format.width = brush_size.x
	texture_format.height = brush_size.y
	
	# Create paint brush
	var new_paint_brush_rd = rd.texture_create(texture_format, RDTextureView.new())
	rd.texture_clear(new_paint_brush_rd, Color.TRANSPARENT, 0, 1, 0, 1)
	uniform.clear_ids()
	uniform.add_id(new_paint_brush_rd)
	var new_paint_brush_set = rd.uniform_set_create([uniform], compute.shader, 0)
	
	_compute_brush(new_paint_brush_set)
	
	paint_brush_rd = new_paint_brush_rd
	paint_brush_set = new_paint_brush_set
	EventBus.on_brush_changed.emit(paint_brush_rd, brush_size)
	
	if rd.texture_is_valid(binned_brush_rd):
		rd.free_rid(binned_brush_rd)


func _compute_brush(new_paint_brush_set: RID):
	var push_constant := PackedFloat32Array()
	push_constant.push_back(brush_size.x)
	push_constant.push_back(brush_size.y)
	push_constant.push_back(1.0)
	push_constant.push_back(0.0)
	
	# Run our compute shader
	var workgroup_count = Vector2i(ceili(brush_size.x / 8.0), ceili(brush_size.y / 8.0))
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, compute.pipeline)
	rd.compute_list_bind_uniform_set(compute_list, new_paint_brush_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, workgroup_count.x, workgroup_count.y, 1)
	rd.compute_list_end()
