#[compute]
#version 450

const vec2 VEC_ZERO = vec2(0, 0);

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Our textures
layout(r8, set = 0, binding = 0) uniform restrict readonly image2D brush_image;
layout(r32f, set = 1, binding = 0) uniform restrict readonly image2D current_image;
layout(r32f, set = 2, binding = 0) uniform restrict writeonly image2D output_image;

// Buffer to hold brush positions
layout(std430, set = 0, binding = 1) buffer BrushPositions {
	vec2 brush_positions[];
};

// Our push PushConstants
layout(push_constant, std430) uniform Params {
	// chunk #1
	vec2 texture_size;      // 8 bytes (2 floats)
	vec2 region_top_left;   // 8 bytes (2 floats)
	// chunk #2
	vec2 brush_size;        // 8 bytes (2 floats)
	//vec2 padding			// 8 bytes
	// chunk #3
	vec3 brush_color;       // 12 bytes (3 floats)
	//float padding			// 4 bytes
} params;

// The code we want to execute in each invocation
void main() {
	int num_brushes = int(brush_positions.length());

	vec2 uv = clamp(gl_GlobalInvocationID.xy + params.region_top_left, VEC_ZERO, params.texture_size);

	vec4 result = imageLoad(current_image, ivec2(uv));

	float brush_radius = params.brush_size.x / 2.0;

	for (int i = 0; i < num_brushes; i++) {

		vec2 brush_uv = clamp(uv - brush_positions[i] + brush_radius, VEC_ZERO, params.brush_size);

		float brush_alpha = imageLoad(brush_image, ivec2(brush_uv)).r;

		result = vec4(mix(params.brush_color.rgb, result.rgb, 1.0 - brush_alpha), result.a);
	}

	imageStore(output_image, ivec2(uv), result);
}
