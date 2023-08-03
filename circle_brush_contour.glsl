// Compute shader to generate a circle contour line
#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Output image
layout(r8, set = 0, binding = 0) uniform restrict writeonly image2D output_image;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 texture_size;		// 8 bytes (2 floats)
} params;

// Returns 1.0 if the pixel at uv is inside the circle with the specified center and radius; otherwise 0.0
float is_pixel_inside_circle(vec2 uv, vec2 circle_center, float circle_radius_squared) {
	// Calculate the squared distance from the pixel to the center of the circle
	vec2 delta = uv - circle_center;
	float distance_squared = dot(delta, delta);

	// Check if the squared distance is within the squared radius of the circle
	return 1.0 - step(circle_radius_squared, distance_squared);
}

// The code we want to execute in each invocation
void main() {
	vec2 uv = gl_GlobalInvocationID.xy;
	vec2 circle_center = params.texture_size * 0.5 - 0.5;
	float circle_radius = circle_center.x;
	float circle_radius_squared = circle_radius * circle_radius;

	// Calculate the distance from the pixel to the center of the circle
	vec2 delta = uv - circle_center;

	// Determine the quadrant of the pixel with respect to the circle center
	float is_right_half = step(0.0, delta.x); // 1 if delta.x > 0.0; otherwise 0
	float is_top_half = step(0.0, delta.y); // 1 if delta.y > 0.0; otherwise 0

	// Shift the result from the step functions to the range [-1, 1],
	// and use that to find the neighbours we want to look at
	float neighbour_offset_x = is_right_half * 2.0 - 1.0;
	float neighbour_offset_y = is_top_half * 2.0 - 1.0;

	// Find the immediate neighbours in the direction of the quadrant we are in
	vec2 horizontal_neighbour_uv = uv + vec2(neighbour_offset_x, 0.0);
	vec2 vertical_neighbour_uv = uv + vec2(0.0, neighbour_offset_y);

	float is_horizontal_neighbour_inside = is_pixel_inside_circle(horizontal_neighbour_uv, circle_center, circle_radius_squared);
	float is_vertical_neighbour_inside = is_pixel_inside_circle(vertical_neighbour_uv, circle_center, circle_radius_squared);
	float is_current_pixel_inside_circle = is_pixel_inside_circle(uv, circle_center, circle_radius_squared);

	// Check if the current pixel is within the circle, and either of its two neighbours are outside the circle
	float is_edge_pixel = is_current_pixel_inside_circle * (1.0 - min(is_horizontal_neighbour_inside, is_vertical_neighbour_inside));

	// Set the pixel color with the calculated alpha value
	imageStore(output_image, ivec2(uv), vec4(is_edge_pixel, 0.0, 0.0, 0.0));
}
