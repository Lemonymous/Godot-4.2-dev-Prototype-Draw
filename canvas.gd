extends Sprite2D


class Dirty:
	var rid: RID
	var size: Vector2i
	var point: Vector2
	
	func _init(_rid: RID, _size: Vector2i, _point: Vector2):
		rid = _rid
		size = _size
		point = _point


@export var texture_size := Vector2i(320, 180)
@onready var is_ready := true
var is_inited := false


var rd : RenderingDevice

var shader : RID
var shader_inverse : RID
var pipeline : RID
var pipeline_inverse : RID

var brush_size : Vector2i
var brush_rd : RID
var brush_set : RID
var clone_brush_rd : RID
var clone_brush_set : RID
var current_rd : RID
var current_set : RID
var next_rd : RID
var next_set : RID
var dirty_draws: Array[Dirty] = []
var brush_color := Color.WHITE


func _notification(what):
	match what:
		NOTIFICATION_PREDELETE:
			_free()


func _init():
	EventBus.on_color_button_pressed.connect(_on_color_changed)
	EventBus.on_brush_changed.connect(_on_brush_changed)


func _ready():
	_init_shaders_and_pipelines()
	_update_brush()


func _free():
	# Free rids
	var texture2DRD = texture as Texture2DRD
	if texture2DRD:
		texture2DRD.texture_rd_rid = RID()
	
	# Sets and pipeline are cleaned up automatically as they are dependencies
	if current_rd:
		rd.free_rid(current_rd)
	if next_rd:
		rd.free_rid(next_rd)
	if shader:
		rd.free_rid(shader)


func _input(event: InputEvent):
	if event.is_action_pressed("left_mouse"):
		_brush_draw()
	else:
		var global_mouse_position = get_global_mouse_position()
		
		if centered:
			# If the texture is centered, adjust the mouse
			var texture_half_size = texture.get_size() / 2.0
			global_mouse_position += texture_half_size
		
		var bush_half_size = brush_size / 2.0
		var rect = Rect2(global_position - bush_half_size, texture.get_size() + 2 * bush_half_size)
		if Input.is_action_pressed("left_mouse") and rect.has_point(global_mouse_position):
			_brush_draw()


func _process(_delta):
	pass


func _brush_draw():
	if !rd.texture_is_valid(brush_rd):
		return
	var mouse_position = get_local_mouse_position()
	#var global_mouse_position = get_global_mouse_position()
	
	if centered:
		# If the texture is centered, adjust the mouse
		var texture_half_size = texture.get_size() / 2.0
		mouse_position += texture_half_size
		#global_mouse_position += texture_half_size
	
	#var bush_half_size = brush_size / 2.0
	#var rect = Rect2(global_position - bush_half_size, texture.get_size() + 2 * bush_half_size)
	
	#if Input.is_action_pressed("left_mouse") and rect.has_point(global_mouse_position):
	for dirty in dirty_draws:
		_compute_image(dirty.rid, dirty.size, dirty.point)
	dirty_draws.clear()
	compute_image(brush_set, brush_size, mouse_position)
	
	# Update texture
	texture.texture_rd_rid = next_rd
	
	# Cycle buffers
	var swap_rd : RID = current_rd
	var swap_set : RID = current_set
	current_rd = next_rd
	current_set = next_set
	next_rd = swap_rd
	next_set = swap_set


func _init_shaders_and_pipelines():
	if !is_ready:
		return
	if is_inited:
		return
	is_inited = true
	
	# Fetch global rendering device
	rd = RenderingServer.get_rendering_device()
	
	# Create display texture
	var texture2DRD = texture as Texture2DRD
	if !texture2DRD:
		texture = Texture2DRD.new()
	
	# Create our compute shaders and pipelines
	shader = Compute.shader(load("res://draw_on_canvas.glsl"), rd)
	pipeline = Compute.pipeline(shader, rd)
	shader_inverse = Compute.shader(load("res://draw_on_canvas_inverse.glsl"), rd)
	pipeline_inverse = Compute.pipeline(shader_inverse, rd)
	
	# Create our textures
	var tf := RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = texture_size.x
	tf.height = texture_size.y
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + \
		RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	
	# Create rd textures
	current_rd = rd.texture_create(tf, RDTextureView.new())
	next_rd = rd.texture_create(tf, RDTextureView.new())
	
	# Clear textures
	rd.texture_clear(current_rd, Color.BLACK, 0, 1, 0, 1)
	rd.texture_clear(next_rd, Color.BLACK, 0, 1, 0, 1)
	
	# Create uniform sets for use in compute shaders
	current_set = _create_uniform_set(current_rd)
	next_set = _create_uniform_set(next_rd)
	
	var texture_2DRD = texture as Texture2DRD
	texture_2DRD.texture_rd_rid = current_rd


func _update_brush():
	if !is_inited:
		return
	if !rd.texture_is_valid(brush_rd):
		return
	brush_set = _create_uniform_set(brush_rd)
	clone_brush_set = _create_uniform_set(clone_brush_rd)


func _create_uniform_set(texture_rd : RID) -> RID:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture_rd)
	return rd.uniform_set_create([uniform], shader, 0)


func _compute_image(drawer_set: RID, drawer_size: Vector2i, point: Vector2):
	if !rd.uniform_set_is_valid(drawer_set):
		return
	# Create our push constants
	var is_inverse := texture_size.x * texture_size.y > drawer_size.x * drawer_size.y
	var push_constant := PackedFloat32Array()
	# Push constant must be made up of 16 byte chunks
	# Structures like vectors cannot be split between chunks
	# Chunk1
	push_constant.push_back(texture_size.x)
	push_constant.push_back(texture_size.y)
	push_constant.push_back(drawer_size.x)
	push_constant.push_back(drawer_size.y)
	# Chunk2
	push_constant.push_back(point.x)
	push_constant.push_back(point.y)
	push_constant.push_back(0.0)
	push_constant.push_back(0.0)
	# Chunk3
	push_constant.push_back(brush_color.r)
	push_constant.push_back(brush_color.g)
	push_constant.push_back(brush_color.b)
	push_constant.push_back(0.0)
	
	# Run our compute shader
	var compute_list := rd.compute_list_begin()
	if is_inverse:
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline_inverse)
	else:
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, drawer_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, current_set, 1)
	rd.compute_list_bind_uniform_set(compute_list, next_set, 2)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	var workgroup_count: Vector2i
	if is_inverse:
		workgroup_count = Vector2i(ceili(drawer_size.x / 8.0), ceili(drawer_size.y / 8.0))
	else:
		workgroup_count = Vector2i(ceili(texture_size.x / 8.0), ceili(texture_size.y / 8.0))
	rd.compute_list_dispatch(compute_list, workgroup_count.x, workgroup_count.y, 1)
	rd.compute_list_end()


func compute_image(drawer_set: RID, drawer_size: Vector2i, point: Vector2):
	_compute_image(drawer_set, drawer_size, point)
	dirty_draws.append(Dirty.new(clone_brush_set, drawer_size, point))


func _on_color_changed(color: Color):
	brush_color = color


func _on_brush_changed(new_brush_rd: RID, new_clone_brush_rd: RID, new_brush_size: Vector2i):
	brush_rd = new_brush_rd
	brush_size = new_brush_size
	clone_brush_rd = new_clone_brush_rd
	_update_brush()
