shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Autumn ground material — procedural colour patches that complement
// the warm-orange trees.  Uses the same toon banding as the rest of
// the scene so it blends visually.

// ── Base colour ──────────────────────────────────────────────────────
// A warm olive-gold base for the overall grass.
uniform vec4 base_color : source_color = vec4(0.52, 0.48, 0.26, 1.0);

// ── Autumn patch colours ─────────────────────────────────────────────
// Dry amber grass patches.
uniform vec4 dry_grass_color : source_color = vec4(0.62, 0.50, 0.28, 1.0);
// Fallen-leaf ground cover — warm orange to match the oak/birch trees.
uniform vec4 leaf_litter_color : source_color = vec4(0.65, 0.38, 0.22, 1.0);
// Earthy dark patches for dirt peeking through.
uniform vec4 earth_color : source_color = vec4(0.38, 0.28, 0.18, 1.0);

// ── Pattern controls ─────────────────────────────────────────────────
// Scale of the large noise that drives the colour patches.
uniform float pattern_scale : hint_range(0.5, 20.0, 0.1) = 4.0;
// Scale of the small detail noise layered on top.
uniform float detail_scale : hint_range(1.0, 40.0, 0.1) = 12.0;
// How much the detail noise perturbs the result (0 = smooth blobs).
uniform float detail_strength : hint_range(0.0, 1.0, 0.01) = 0.35;

// ── Toon banding ─────────────────────────────────────────────────────
uniform int bands : hint_range(1, 8) = 3;
uniform float band_softness : hint_range(0.0, 0.5, 0.01) = 0.02;
uniform vec3 ambient_tint : source_color = vec3(0.35, 0.32, 0.28);

// ── Hash / noise helpers (no textures required) ──────────────────────
// Simple 2-D value noise via hash → smooth interpolation.

float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Two octaves of value noise for richer variation.
float fbm2(vec2 p) {
	float v = 0.0;
	v += value_noise(p) * 0.6;
	v += value_noise(p * 2.13 + vec2(5.3, 1.7)) * 0.4;
	return v;
}

void fragment() {
	// World-space XZ from the built-in vertex varying.
	vec2 world_xz = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;

	// Large-scale pattern → which "zone" this pixel belongs to.
	float n_large = fbm2(world_xz * pattern_scale * 0.1);
	// Small-scale detail → breaks up edges.
	float n_detail = value_noise(world_xz * detail_scale * 0.1);

	// Combine.
	float n = clamp(n_large + (n_detail - 0.5) * detail_strength, 0.0, 1.0);

	// Map noise to four colour zones.
	vec3 col;
	if (n < 0.30) {
		col = mix(earth_color.rgb, base_color.rgb, n / 0.30);
	} else if (n < 0.55) {
		col = mix(base_color.rgb, dry_grass_color.rgb, (n - 0.30) / 0.25);
	} else if (n < 0.78) {
		col = mix(dry_grass_color.rgb, leaf_litter_color.rgb, (n - 0.55) / 0.23);
	} else {
		col = mix(leaf_litter_color.rgb, base_color.rgb, (n - 0.78) / 0.22);
	}

	ALBEDO = col;
}

void light() {
	// Same toon banding as toon.gdshader.
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float scaled = ndl * float(bands);
	float lower = floor(scaled);
	float soft = max(band_softness, 0.12);
	float frac_part = smoothstep(0.5 - soft, 0.5 + soft, fract(scaled));
	float stepped = (lower + frac_part) / float(bands);

	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * stepped * ALBEDO;
	DIFFUSE_LIGHT += ambient_tint * ALBEDO * (1.0 - stepped) * 0.28;
}
