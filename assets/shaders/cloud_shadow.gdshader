shader_type canvas_item;
render_mode unshaded, blend_mix;

/// Discrete world-space cloud shadows. UV is the explore pane.
/// Positions wrap in `cloud_period` so walking does not drag or empty the field.

uniform vec2 cam_tile = vec2(0.0);
uniform vec2 view_tiles = vec2(25.0, 11.0);
uniform vec2 cloud_period = vec2(30.0, 16.0);
uniform int cloud_count = 0;
uniform vec4 clouds_a[8];
uniform vec4 clouds_b[8];
uniform float overcast : hint_range(0.0, 1.0) = 0.0;
uniform float dim : hint_range(0.0, 1.0) = 0.0;
uniform float rain_amt : hint_range(0.0, 1.0) = 0.0;
uniform vec3 rain_col = vec3(0.86, 0.90, 0.96);
uniform vec2 rain_wind = vec2(0.2, 1.0);
uniform vec2 rain_cam = vec2(0.0);
uniform vec2 cover_cam = vec2(0.0);
uniform vec2 party_tile = vec2(0.0);
uniform float hide_edge = 0.0;

float hash11(float p) {
	return fract(sin(p * 127.1) * 43758.5453123);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 wrap_delta(vec2 a, vec2 b, vec2 period) {
	vec2 d = a - b;
	d -= period * floor(d / period + 0.5);
	return d;
}

float lobe(vec2 p, vec2 c, vec2 axes) {
	vec2 q = (p - c) / max(axes, vec2(0.08));
	float d2 = dot(q, q);
	/// Soft lip only — fill stays even, rim is ~3× the previous blur.
	return 1.0 - smoothstep(0.68, 1.22, d2);
}

float shape_bank(vec2 p, float seed) {
	float s0 = hash11(seed + 1.1);
	float s1 = hash11(seed + 2.3);
	float s2 = hash11(seed + 3.7);
	float m = 0.0;
	m = max(m, lobe(p, vec2(-0.16 + s0 * 0.08, -0.06), vec2(0.60, 0.32)));
	m = max(m, lobe(p, vec2(0.24 - s1 * 0.08, -0.04), vec2(0.56, 0.30)));
	m = max(m, lobe(p, vec2(-0.54 + s2 * 0.08, 0.08), vec2(0.38, 0.34)));
	m = max(m, lobe(p, vec2(0.54, 0.06), vec2(0.36, 0.32)));
	m = max(m, lobe(p, vec2(-0.18, 0.36), vec2(0.34, 0.32)));
	m = max(m, lobe(p, vec2(0.20, 0.40), vec2(0.38, 0.34)));
	return m;
}

float shape_stratus(vec2 p, float seed) {
	float s0 = hash11(seed + 4.4);
	float m = 0.0;
	m = max(m, lobe(p, vec2(-0.42, -0.02 + s0 * 0.06), vec2(0.48, 0.24)));
	m = max(m, lobe(p, vec2(0.00, 0.00), vec2(0.58, 0.26)));
	m = max(m, lobe(p, vec2(0.44, -0.04), vec2(0.46, 0.22)));
	m = max(m, lobe(p, vec2(-0.18, 0.18), vec2(0.28, 0.22)));
	m = max(m, lobe(p, vec2(0.22, 0.16), vec2(0.26, 0.20)));
	return m;
}

float shape_triple(vec2 p, float seed) {
	float s0 = hash11(seed + 6.1);
	float m = 0.0;
	m = max(m, lobe(p, vec2(-0.48, 0.04), vec2(0.40, 0.36)));
	m = max(m, lobe(p, vec2(0.02, 0.10 + s0 * 0.08), vec2(0.44, 0.40)));
	m = max(m, lobe(p, vec2(0.50, 0.00), vec2(0.38, 0.34)));
	m = max(m, lobe(p, vec2(-0.16, -0.16), vec2(0.34, 0.22)));
	m = max(m, lobe(p, vec2(0.20, -0.14), vec2(0.32, 0.20)));
	return m;
}

float shape_comma(vec2 p, float seed) {
	float s0 = hash11(seed + 7.8);
	float m = 0.0;
	m = max(m, lobe(p, vec2(-0.10, 0.18), vec2(0.50, 0.42)));
	m = max(m, lobe(p, vec2(0.28, 0.08), vec2(0.36, 0.30)));
	m = max(m, lobe(p, vec2(0.46, -0.18 + s0 * 0.06), vec2(0.30, 0.24)));
	m = max(m, lobe(p, vec2(-0.36, 0.02), vec2(0.32, 0.28)));
	m = max(m, lobe(p, vec2(-0.06, -0.16), vec2(0.28, 0.20)));
	return m;
}

float shape_stack(vec2 p, float seed) {
	float s0 = hash11(seed + 9.2);
	float m = 0.0;
	m = max(m, lobe(p, vec2(-0.08, -0.18), vec2(0.58, 0.28)));
	m = max(m, lobe(p, vec2(0.30, -0.10), vec2(0.36, 0.26)));
	m = max(m, lobe(p, vec2(-0.06, 0.16 + s0 * 0.06), vec2(0.42, 0.32)));
	m = max(m, lobe(p, vec2(0.18, 0.36), vec2(0.30, 0.26)));
	m = max(m, lobe(p, vec2(-0.32, 0.08), vec2(0.28, 0.24)));
	return m;
}

float cloud_body(vec2 world, vec4 pr, vec4 sh) {
	vec2 d = wrap_delta(world, pr.xy, cloud_period);
	float r = max(pr.z, 0.01);
	vec2 p = d / r;
	p.x /= max(sh.x, 0.8);
	int style = int(floor(sh.w + 0.5));
	if (style == 1) {
		return shape_stratus(p, sh.y);
	}
	if (style == 2) {
		return shape_triple(p, sh.y);
	}
	if (style == 3) {
		return shape_comma(p, sh.y);
	}
	if (style == 4) {
		return shape_stack(p, sh.y);
	}
	return shape_bank(p, sh.y);
}

float overcast_field(vec2 world) {
	/// Keep the storm sheet moving while the party stands still (talk / menus).
	vec2 drift = vec2(rain_wind.x, 0.55) * TIME * 0.28;
	vec2 p = world - drift;
	float n = noise(p * 0.11);
	n = n * 0.62 + noise(p * 0.23 + vec2(9.1, 3.4)) * 0.38;
	return smoothstep(0.22, 0.58, n) * overcast;
}

/// Fixed map-tile spawn cells. A drop starts there, falls 1–3 tiles, then dies.
/// Positions use rain_cam so walking does not drag the field.
float rain_from_spawns(vec2 tp, vec2 dir, vec2 perp, float layer, vec2 cell) {
	vec2 base = floor(tp / cell);
	float acc = 0.0;
	for (int oy = -2; oy <= 1; oy++) {
		for (int ox = -1; ox <= 1; ox++) {
			vec2 sid = base + vec2(float(ox), float(oy));
			vec2 hid = sid + vec2(layer * 31.1, layer * 7.3);
			float h = hash21(hid);
			if (h < 0.50 - rain_amt * 0.38) {
				continue;
			}
			vec2 jitter = vec2(hash21(hid + vec2(3.2, 1.1)), hash21(hid + vec2(8.8, 2.4)));
			vec2 spawn = (sid + vec2(0.18, 0.12) + jitter * 0.64) * cell;
			float travel = mix(1.0, 3.0, hash21(hid + vec2(0.7, 5.5)));
			float freq = mix(0.55, 0.95, hash21(hid + vec2(4.4, 0.9))) * 1.3;
			float phase = hash21(hid + vec2(1.6, 9.2));
			float cycle = fract(TIME * freq + phase);
			float fall_frac = 0.42;
			if (cycle > fall_frac) {
				continue;
			}
			float progress = cycle / fall_frac;
			vec2 drop = spawn + dir * (progress * travel);
			vec2 d = tp - drop;
			float across = abs(dot(d, perp));
			float behind = -dot(d, dir);
			float dash = mix(0.28, 0.48, hash21(hid + vec2(6.1, 3.3)));
			float line = 1.0 - smoothstep(0.0, 0.055, across);
			float tail = step(0.0, behind) * (1.0 - smoothstep(0.0, dash, behind));
			acc = max(acc, line * tail);
		}
	}
	return acc;
}

float rain_streaks(vec2 tp) {
	if (rain_amt <= 0.001) {
		return 0.0;
	}
	vec2 dir = normalize(vec2(rain_wind.x * 0.45, 1.0));
	vec2 perp = vec2(dir.y, -dir.x);
	float acc = 0.0;
	acc = max(acc, rain_from_spawns(tp, dir, perp, 0.0, vec2(2.2, 2.6)));
	acc = max(acc, rain_from_spawns(tp, dir, perp, 1.0, vec2(2.7, 3.1)));
	acc = max(acc, rain_from_spawns(tp, dir, perp, 2.0, vec2(1.95, 2.35)));
	acc = max(acc, rain_from_spawns(tp, dir, perp, 3.0, vec2(2.45, 2.85)));
	/// Peak storm: four more fields → about 2× the previous maximum.
	if (rain_amt > 0.45) {
		acc = max(acc, rain_from_spawns(tp, dir, perp, 4.0, vec2(2.05, 2.55)));
		acc = max(acc, rain_from_spawns(tp, dir, perp, 5.0, vec2(2.55, 2.95)));
		acc = max(acc, rain_from_spawns(tp, dir, perp, 6.0, vec2(1.85, 2.25)));
		acc = max(acc, rain_from_spawns(tp, dir, perp, 7.0, vec2(2.35, 3.15)));
	}
	return acc;
}

void fragment() {
	vec2 tiles = max(view_tiles, vec2(1.0));
	vec2 rain_tp = rain_cam + (UV - 0.5) * tiles;
	/// Same cell as the map blit: tile = floor(cam + UV * view - view/2).
	/// Odd views put the party on a true center tile; floor(rain_tp) split that cell.
	vec2 cell = floor(rain_cam + UV * tiles - floor(tiles * 0.5));
	/// TEXTURE is a view-centered hide mask (white = no weather): indoor and LOS fog.
	vec2 hide_sz = vec2(textureSize(TEXTURE, 0));
	float hide = 0.0;
	if (hide_sz.x > 0.5 && hide_sz.y > 0.5) {
		vec2 hide_idx = cell - party_tile + floor(hide_sz * 0.5);
		if (hide_idx.x < 0.0 || hide_idx.y < 0.0 || hide_idx.x >= hide_sz.x || hide_idx.y >= hide_sz.y) {
			hide = hide_edge;
		} else {
			hide = texture(TEXTURE, (hide_idx + vec2(0.5)) / hide_sz).r;
		}
	}
	vec2 world = cam_tile + (UV - 0.5) * view_tiles;
	vec2 cover_world = cover_cam + (UV - 0.5) * view_tiles;
	float shade = 0.0;
	int n = clamp(cloud_count, 0, 8);
	for (int i = 0; i < 8; i++) {
		if (i >= n) {
			break;
		}
		vec4 pr = clouds_a[i];
		if (pr.w <= 0.001 || pr.z <= 0.01) {
			continue;
		}
		shade = max(shade, cloud_body(world, pr, clouds_b[i]) * pr.w);
	}
	/// Whole-view storm gloom. Stays on indoor tiles; only blobs + rain hide.
	float cover = max(overcast_field(cover_world) * 0.48, dim * 0.26);
	if (hide > 0.5) {
		shade = max(overcast * 0.40, dim * 0.26);
	} else {
		shade = max(shade, cover);
	}
	float rain = hide > 0.5 ? 0.0 : rain_streaks(rain_tp);
	vec3 col = vec3(0.02, 0.02, 0.03);
	col = mix(col, rain_col, rain);
	float a = clamp(max(shade, rain * 0.62), 0.0, 0.78);
	COLOR = vec4(col, a);
}
