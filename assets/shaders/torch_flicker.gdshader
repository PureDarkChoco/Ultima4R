shader_type canvas_item;
render_mode unshaded, blend_mix;

/// Torch-only: one 암영 % for the whole dungeon pane. No UV warp.
/// Wanders ±8% from baseline; one change is at most 4%.

uniform float enabled : hint_range(0.0, 1.0) = 1.0;
/// xy = field origin in UV, zw = field size in UV (center 11×11 pane).
uniform vec4 field_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform float swing_pct : hint_range(1.0, 20.0) = 8.0;
uniform float max_step_pct : hint_range(1.0, 10.0) = 4.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float walk_pct(float tick) {
	float p = 0.0;
	for (int i = 0; i < 8; i++) {
		float raw = (hash21(vec2(tick - 7.0 + float(i), 4.2)) * 2.0 - 1.0) * swing_pct;
		p = clamp(clamp(raw, p - max_step_pct, p + max_step_pct), -swing_pct, swing_pct);
	}
	return p;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 local = (UV - field_uv.xy) / max(field_uv.zw, vec2(1e-5));
	float in_field = step(0.0, local.x) * step(0.0, local.y)
			* step(local.x, 1.0) * step(local.y, 1.0);

	float pct = walk_pct(floor(TIME / 0.4));
	float scale = 1.0 + pct * 0.01 * in_field * enabled;
	COLOR = vec4(c.rgb * scale, c.a);
}
