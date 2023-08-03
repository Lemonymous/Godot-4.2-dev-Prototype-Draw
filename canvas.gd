extends Node2D


class DetectionArea extends Area2D:
	func _init(size):
		var shape = RectangleShape2D.new()
		shape.size = size
		
		var collision = CollisionShape2D.new()
		collision.shape = shape
		collision.position = size / 2.0
		
		add_child(collision)


class Canvas extends Sprite2D:
	func _init():
		texture = Texture2DRD.new()
		centered = false


@onready var is_ready := true
var is_inited := false
var is_drawing := false

var area : Area2D
var collision : CollisionShape2D
var sprite : Sprite2D

# Compute shader necessities
var rd : RenderingDevice
var compute_brush_stroke : Compute
var compute_copy_region : Compute
var brush_uniform : RDUniform

# This node is responsible for this RIDs
# Remember to clean them up after use.
var brush_rd : RID
var current_rd : RID
var next_rd : RID
var current_uniform_set : RID
var next_uniform_set : RID
var brush_uniform_set : RID

# Various 
var canvas_size := Vector2()
var brush_size := Vector2i()
var mouse_position := Vector2i()
var prev_mouse_position := Vector2i()
var dirty_bounds := Rect2i()
var brush_color := Color.WHITE


func _notification(what):
	match what:
		NOTIFICATION_PREDELETE:
			_free_resources()


func _init():
	EventBus.on_color_button_pressed.connect(_on_color_changed)
	EventBus.on_brush_changed.connect(_on_brush_changed)


func _ready():
	mouse_position = get_local_mouse_position()
	prev_mouse_position = mouse_position
	_init_children()
	_init_shaders_and_pipelines()
	_update_brush()


func _free_resources():
	# Sets and pipeline are cleaned up automatically as they are dependencies
	if rd.texture_is_valid(current_rd):
		rd.free_rid(current_rd)
	if rd.texture_is_valid(next_rd):
		rd.free_rid(next_rd)
	if rd.uniform_set_is_valid(brush_uniform_set):
		rd.free_rid(brush_uniform_set)
	if rd.uniform_set_is_valid(current_uniform_set):
		rd.free_rid(current_uniform_set)
	if rd.uniform_set_is_valid(next_uniform_set):
		rd.free_rid(next_uniform_set)


func _input(event: InputEvent):
	if event.is_action_released("left_mouse"):
		is_drawing = false
	
	if event is InputEventMouseMotion:
		prev_mouse_position = mouse_position
		mouse_position = get_local_mouse_position()


func _process(_delta):
	if !rd.texture_is_valid(brush_rd):
		return
	
	if is_drawing:
		_brush_draw(prev_mouse_position, mouse_position)
	elif dirty_bounds.size != Vector2i.ZERO:
		# Always attempt to copy dirty bounds
		_compute_region_copy(dirty_bounds)
		dirty_bounds = Rect2i()


func _init_children():
	# Create nodes
	canvas_size = $reference_rect.size
	area = DetectionArea.new(canvas_size)
	sprite = Canvas.new()
	
	# Add nodes
	add_child(sprite)
	add_child(area)
	
	# Connect to events
	area.input_event.connect(_on_area_input_event)


func _init_shaders_and_pipelines():
	if !is_ready:
		return
	if is_inited:
		return
	is_inited = true
	
	# Fetch global rendering device
	rd = RenderingServer.get_rendering_device()
	
	# Create our compute shaders and pipelines
	compute_brush_stroke = Compute.new("res://draw_brushe_strokes.glsl")
	compute_copy_region = Compute.new("res://copy_region.glsl")
	
	# Create our textures
	var tf := RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = canvas_size.x
	tf.height = canvas_size.y
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
	var current_image_uniform = _create_image_uniform(current_rd, 0)
	var next_image_uniform = _create_image_uniform(next_rd, 0)
	current_uniform_set = rd.uniform_set_create([current_image_uniform], compute_brush_stroke.shader, 1)
	next_uniform_set = rd.uniform_set_create([next_image_uniform], compute_brush_stroke.shader, 2)
	
	sprite.texture.texture_rd_rid = current_rd


func _brush_draw(from: Vector2, to: Vector2):
	# Copy dirty bounds from current buffer to the next
	_compute_region_copy(dirty_bounds)
	dirty_bounds = Rect2i()
	
	# Calculate region covered by the current stroke,
	# including the extents of the brush radius
	var brush_radius = Vector2(brush_size).x / 2.0
	var left = min(from.x, to.x)
	var top = min(from.y, to.y)
	var right = max(from.x, to.x)
	var bot = max(from.y, to.y)
	left -= brush_radius
	top -= brush_radius
	right += brush_radius
	bot += brush_radius
	left = clamp(left, 0.0, canvas_size.x)
	top = clamp(top, 0.0, canvas_size.y)
	right = clamp(right, 0.0, canvas_size.x)
	bot = clamp(bot, 0.0, canvas_size.y)
	var width = right - left
	var height = bot - top
	var region = Rect2i(left, top, width, height)
	
	# Return if the brush stroke has no extent
	if region.size.x == 0 or region.size.y == 0:
		return
	
	# Add region to dirty bounds
	_update_dirty_bounds(region)
	
	# Calculate draw positions in our brush stroke
	var fine_steps = 5.0 # number of steps between each separate brush
	var distance = to - from
	var num_steps = max(1, ceili(fine_steps * distance.length_squared() / (brush_radius * brush_radius)))
	var step_vector = distance / num_steps
	
	# Create array to hold each brush position in our stroke
	var brush_positions := PackedVector2Array()
	
	# Loop through the steps and populate the brush positions
	var point = from
	for i in range(num_steps):
		brush_positions.append(point)
		point += step_vector
	
	# Clean up previous brush uniform set
	if rd.uniform_set_is_valid(brush_uniform_set):
		rd.free_rid(brush_uniform_set)
	
	# Create a storage buffer
	var input_bytes := brush_positions.to_byte_array()
	var buffer_rd := rd.storage_buffer_create(input_bytes.size(), input_bytes)
	var buffer_uniform = _create_buffer_uniform(buffer_rd, 1)
	brush_uniform_set = rd.uniform_set_create([brush_uniform, buffer_uniform], compute_brush_stroke.shader, 0)
	
	# Draw the brush stroke onto the canvas
	_compute_region_brush_stroke(region)
	
	# Update texture
	sprite.texture.texture_rd_rid = next_rd
	
	# Cycle buffers
	var swap_rd : RID = current_rd
	current_rd = next_rd
	next_rd = swap_rd
	var swap_uniform_set : RID = current_uniform_set
	current_uniform_set = next_uniform_set
	next_uniform_set = swap_uniform_set


func _compute_region_copy(region: Rect2i):
	if region.size == Vector2i.ZERO:
		return
	
	#print(region.size)
	
	var push_constant := PackedFloat32Array()
	# Push constant must be made up of 16 byte chunks
	# Structures like vectors cannot be split between chunks
	# Chunk1
	push_constant.push_back(canvas_size.x)
	push_constant.push_back(canvas_size.y)
	push_constant.push_back(region.position.x)
	push_constant.push_back(region.position.y)
	
	# Run our compute shader
	var workgroup_count = Vector2i(ceili(region.size.x / 8.0), ceili(region.size.y / 8.0))
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, compute_copy_region.pipeline)
	rd.compute_list_bind_uniform_set(compute_list, current_uniform_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, next_uniform_set, 1)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, workgroup_count.x, workgroup_count.y, 1)
	rd.compute_list_end()


func _compute_region_brush_stroke(region: Rect2i):
	# Create our push constants
	var push_constant := PackedFloat32Array()
	# Push constant must be made up of 16 byte chunks
	# Structures like vectors cannot be split between chunks
	# Chunk1
	push_constant.push_back(canvas_size.x)
	push_constant.push_back(canvas_size.y)
	push_constant.push_back(region.position.x)
	push_constant.push_back(region.position.y)
	# Chunk2
	push_constant.push_back(brush_size.x)
	push_constant.push_back(brush_size.y)
	push_constant.push_back(0.0)
	push_constant.push_back(0.0)
	# Chunk3
	push_constant.push_back(brush_color.r)
	push_constant.push_back(brush_color.g)
	push_constant.push_back(brush_color.b)
	push_constant.push_back(0.0)
	
	# Run our compute shader
	var workgroup_count = Vector2i(ceili(region.size.x / 8.0), ceili(region.size.y / 8.0))
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, compute_brush_stroke.pipeline)
	rd.compute_list_bind_uniform_set(compute_list, brush_uniform_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, current_uniform_set, 1)
	rd.compute_list_bind_uniform_set(compute_list, next_uniform_set, 2)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, workgroup_count.x, workgroup_count.y, 1)
	rd.compute_list_end()


func _update_dirty_bounds(bounds: Rect2i):
	if dirty_bounds.size == Vector2i.ZERO:
		dirty_bounds = bounds
	else:
		dirty_bounds = dirty_bounds.merge(bounds)


func _update_brush():
	if !is_inited:
		return
	if !rd.texture_is_valid(brush_rd):
		return
	brush_uniform = _create_image_uniform(brush_rd, 0)


func _create_image_uniform(texture_rd : RID, binding : int = 0) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(texture_rd)
	return uniform


func _create_buffer_uniform(buffer_rd : RID, binding : int = 0) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer_rd)
	return uniform


func _on_area_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	if event.is_action("left_mouse"):
		if event.is_pressed():
			is_drawing = true
			_brush_draw(mouse_position, mouse_position)


func _on_color_changed(color: Color):
	brush_color = color


func _on_brush_changed(new_brush_rd: RID, new_brush_contour_rd: RID, new_brush_size: Vector2i):
	brush_rd = new_brush_rd
	brush_size = new_brush_size
	_update_brush()
