shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float outer_glow : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Sample neighbors for outer glow
	float glow_alpha = 0.0;
	vec2 ps = TEXTURE_PIXEL_SIZE;
	for (float x = -2.0; x <= 2.0; x += 1.0) {
		for (float y = -2.0; y <= 2.0; y += 1.0) {
			glow_alpha += texture(TEXTURE, UV + vec2(x, y) * ps).a;
		}
	}
	glow_alpha = clamp(glow_alpha / 25.0, 0.0, 1.0);

	// Base sprite with glow
	COLOR = tex;
	COLOR.rgb += glow_color.rgb * glow_intensity * tex.a;
	// Outer glow halo
	float halo = glow_alpha * outer_glow * (1.0 - tex.a);
	COLOR.rgb += glow_color.rgb * halo;
	COLOR.a = max(tex.a, halo);
}
