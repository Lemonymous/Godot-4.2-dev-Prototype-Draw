class_name Compute
extends Node


static func pipeline(_shader: RID, rendering_device: RenderingDevice = RenderingServer.get_rendering_device()):
	return rendering_device.compute_pipeline_create(_shader)


static func shader(shader_file: RDShaderFile, rendering_device: RenderingDevice = RenderingServer.get_rendering_device()):
	var shader_spirv := shader_file.get_spirv()
	return rendering_device.shader_create_from_spirv(shader_spirv)
