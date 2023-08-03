#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Our textures
layout(r8, set = 0, binding = 0) uniform restrict writeonly image2D output_image;

// Our push PushConstant
layout(push_constant, std430) uniform Params {
	// chunk #1
	vec2 texture_size;			// 8 bytes (2 floats)
	float border_fade;			// 4 bytes (1 float)
	float fade_start_radius;	// 4 bytes (1 float)
} params;

// The code we want to execute in each invocation
void main() {
	vec2 uv = gl_GlobalInvocationID.xy;

	// Calculate the center of the texture
	vec2 circle_center = params.texture_size * 0.5 - 0.5;
	float circle_radius = circle_center.x;

	// Calculate distance from the center of the circle
	vec2 delta = uv - circle_center;
	float distance_squared = delta.x * delta.x + delta.y * delta.y;

	// Calculate alpha value based on distance from the center
	float alpha = 0.0;
	if (distance_squared < circle_radius * circle_radius) {
		// Outside the circle, apply border fading
		float border_distance = circle_radius - sqrt(distance_squared);
		float border_distance_adjusted = border_distance - params.fade_start_radius;
		float border_distance_normalized = border_distance_adjusted / circle_radius;
		alpha = 1.0 - smoothstep(params.border_fade, 0.0, border_distance_normalized);
	}

	// Set the pixel color with the calculated alpha value
	imageStore(output_image, ivec2(uv), vec4(alpha, 0.0, 0.0, 0.0));
}
