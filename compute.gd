class_name Compute
extends RefCounted


var rd : RenderingDevice
var shader : RID
var pipeline : RID
var push_constant
var descriptor_sets : Array[RID]
	#set(i, value):
		#descriptor_sets[i] = value
	#get(i):
		#return descriptor_sets[i]


func _init(shader_file_path: String, rendering_device: RenderingDevice = RenderingServer.get_rendering_device()):
	var shader_file := load(shader_file_path) as RDShaderFile
	if !shader_file:
		printerr("invalid shader file")
		print_stack()
		return
	var shader_spirv := shader_file.get_spirv()
	rd = rendering_device
	shader = rendering_device.shader_create_from_spirv(shader_spirv)
	pipeline = rendering_device.compute_pipeline_create(shader)


func _notification(what):
	match what:
		NOTIFICATION_PREDELETE:
			if rd:
				# Free rids - pipeline will automatically be freed along with the shader
				rd.free_rid(shader)
				print("freeing object")
