class_name Brush
extends Node


const MIN_BRUSH_SIZE = 3


@export var brush_size_increment := 1
@export var brush_size := Vector2i(12, 12)


var rd : RenderingDevice
var compute : Compute
var compute_contour : Compute
var uniform : RDUniform
var texture_format : RDTextureFormat
var paint_brush_rd : RID
var brush_outline_rd : RID


func _ready():
	rd = RenderingServer.get_rendering_device()
	
	compute = Compute.new("res://circle_brush.glsl")
	compute.push_constant = PackedFloat32Array()
	compute.push_constant.push_back(brush_size.x)
	compute.push_constant.push_back(brush_size.y)
	compute.push_constant.push_back(0.0)
	compute.push_constant.push_back(0.0)
	compute.descriptor_sets.append(RID())
	
	compute_contour = Compute.new("res://circle_brush_contour.glsl")
	compute_contour.push_constant = PackedFloat32Array()
	compute_contour.push_constant.push_back(brush_size.x)
	compute_contour.push_constant.push_back(brush_size.y)
	compute_contour.push_constant.push_back(0.0)
	compute_contour.push_constant.push_back(0.0)
	compute_contour.descriptor_sets.append(RID())
	
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
	
	paint_brush_rd = _create_brush(compute)
	brush_outline_rd = _create_brush(compute_contour)
	EventBus.on_brush_changed.emit(paint_brush_rd, brush_outline_rd, brush_size)


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
		
		if rd.texture_is_valid(paint_brush_rd):
			rd.free_rid.call_deferred(paint_brush_rd)
		if rd.texture_is_valid(brush_outline_rd):
			rd.free_rid.call_deferred(brush_outline_rd)
		
		paint_brush_rd = _create_brush(compute)
		brush_outline_rd = _create_brush(compute_contour)
		EventBus.on_brush_changed.emit(paint_brush_rd, brush_outline_rd, brush_size)


func _create_brush(_compute: Compute):
	texture_format.width = brush_size.x
	texture_format.height = brush_size.y
	
	# Create paint brush
	var new_brush = rd.texture_create(texture_format, RDTextureView.new())
	rd.texture_clear(new_brush, Color.TRANSPARENT, 0, 1, 0, 1)
	uniform.clear_ids()
	uniform.add_id(new_brush)
	_compute.descriptor_sets[0] = rd.uniform_set_create([uniform], _compute.shader, 0)
	
	_compute_brush(_compute)
	
	return new_brush


func _compute_brush(_compute: Compute):
	_compute.push_constant[0] = brush_size.x
	_compute.push_constant[1] = brush_size.y
	
	# Run our compute shader
	var workgroup_count = Vector2i(ceili(brush_size.x / 8.0), ceili(brush_size.y / 8.0))
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, _compute.pipeline)
	for i in range(_compute.descriptor_sets.size()):
		rd.compute_list_bind_uniform_set(compute_list, _compute.descriptor_sets[i], i)
	rd.compute_list_set_push_constant(compute_list, _compute.push_constant.to_byte_array(), _compute.push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, workgroup_count.x, workgroup_count.y, 1)
	rd.compute_list_end()
