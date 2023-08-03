#[compute]
#version 450

const vec2 VEC_ZERO = vec2(0, 0);

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Our textures
layout(r32f, set = 0, binding = 0) uniform restrict readonly image2D input_image;
layout(r32f, set = 1, binding = 0) uniform restrict writeonly image2D output_image;

// Our push PushConstant
layout(push_constant, std430) uniform Params {
	// chunk #1
	vec2 texture_size;		// 8 bytes (2 floats)
	vec2 region_top_left;	// 8 bytes (2 floats)
} params;

// The code we want to execute in each invocation
void main() {
	// Calculate the position in the input image to write to
	vec2 uv = clamp(gl_GlobalInvocationID.xy + params.region_top_left, VEC_ZERO, params.texture_size);

	// Sample the color from the input image
	vec4 input_color = imageLoad(input_image, ivec2(uv));

	imageStore(output_image, ivec2(uv), input_color);
}
