shader_type canvas_item;

// Sample the screen texture
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear, repeat_enable;

void fragment() {
	float alpha = texture(TEXTURE, UV).r;
	// Sample the screen texture at the current UV
	vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	COLOR = vec4(vec3(1.0) - screen_color.rgb, alpha);
}
