shader_type canvas_item;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	if (all(greaterThan(pixel.rgb, vec3(0.99)))) {
		discard;
	}
	COLOR = pixel;
}
