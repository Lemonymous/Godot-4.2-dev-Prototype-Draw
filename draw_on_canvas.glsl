#[compute]
#version 450

const ivec2 VEC_ZERO = ivec2(0, 0);

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Our textures
layout(r8, set = 0, binding = 0) uniform restrict readonly image2D brush_image;
layout(r32f, set = 1, binding = 0) uniform restrict readonly image2D current_image;
layout(r32f, set = 2, binding = 0) uniform restrict writeonly image2D output_image;

// Our push PushConstant
layout(push_constant, std430) uniform Params {
	// chunk #1
	vec2 texture_size;		// 8 bytes (2 floats)
	vec2 brush_size;		// 8 bytes (2 floats)
	// chunk #2
	vec2 brush_position;	// 8 bytes (2 floats)
	//vec2 _1;				// 8 bytes (2 floats)
	// chunk #3
	vec3 brush_color;		// 12 bytes (3 floats)
	//float _2;				// 4 bytes (1 float)
} params;

// The code we want to execute in each invocation
void main() {
	// Calculate the position in the current image to sample from
	vec2 uv = clamp(gl_GlobalInvocationID.xy, VEC_ZERO, params.texture_size);

	// Calculate the position in the brush image to sample from
	vec2 brush_half_size = params.brush_size / 2.0;
	vec2 brush_uv = clamp(uv - params.brush_position + brush_half_size, VEC_ZERO, params.brush_size);

	// Sample the color from the brush image
	float brush_alpha = imageLoad(brush_image, ivec2(brush_uv)).r;

	// Sample the color from the current image
	vec4 current_color = imageLoad(current_image, ivec2(uv));

	// Merge the colors by using the alpha channel of the brush as a blend factor
	vec4 result = vec4(mix(current_color.rgb, params.brush_color.rgb, brush_alpha), current_color.a);
	imageStore(output_image, ivec2(uv), result);
}