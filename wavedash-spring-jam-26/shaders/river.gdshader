shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

// Flowing toon river water for a generated ribbon mesh (see Scripts/river.gd). The
// mesh UVs run U=0..1 across the width and V along the river's length, so the foam
// flows down the curve. Unshaded + flat colours to match the pixel-toon art
// (toon.gdshader / tree_sway_sprite.gdshader / pixel_outline post-process):
//  - layered flowing value-noise ripples scrolling downstream (V),
//  - crisp foam crests on the brightest ripples,
//  - a soft shoreline foam band hugging both banks,
//  - a gentle sine surface bob (needs the mesh tessellated along its length).

uniform vec4 water_color : source_color = vec4(0.12, 0.45, 0.6, 0.85);
uniform vec4 foam_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float flow_speed : hint_range(0.0, 5.0) = 1.0;
uniform float wave_count : hint_range(1.0, 60.0) = 12.0;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.6;

uniform float bob_amplitude : hint_range(0.0, 0.5) = 0.05;
uniform float bob_speed : hint_range(0.0, 10.0) = 1.6;
uniform float wave_freq : hint_range(0.0, 20.0) = 4.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Smooth value noise.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	// Gentle bob on the surface (Y up). Needs the ribbon tessellated to have verts.
	float b = sin(VERTEX.x * wave_freq + TIME * bob_speed) * bob_amplitude;
	b += sin(VERTEX.z * wave_freq * 1.3 + TIME * bob_speed * 0.8) * bob_amplitude * 0.6;
	VERTEX.y += b;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * flow_speed;

	// Two layers of flowing value-noise scrolling downstream (along V) for ripples.
	float n1 = noise(vec2(uv.x * wave_count, uv.y * wave_count - t));
	float n2 = noise(vec2(uv.x * wave_count * 0.6 + 3.7, uv.y * wave_count * 0.6 - t * 0.6));
	float ripple = n1 * 0.65 + n2 * 0.35;

	// Crisp foam crests on the brightest ripples (toon/pixel: tight edge).
	float foam = smoothstep(foam_threshold, foam_threshold + 0.08, ripple);

	// Shoreline foam: a soft band hugging both banks, gently pulsing along flow.
	float bank = 1.0 - smoothstep(0.0, 0.14, min(uv.x, 1.0 - uv.x));
	float shore = bank * (0.6 + 0.4 * sin(uv.y * wave_count * 0.4 - t * 2.0));
	foam = max(foam, smoothstep(0.45, 0.75, shore));

	// Subtle cross-stream toon shade so the slab isn't perfectly flat.
	vec3 base = mix(water_color.rgb * 0.82, water_color.rgb, smoothstep(0.0, 0.6, 1.0 - bank));

	ALBEDO = mix(base, foam_color.rgb, foam);
	ALPHA = water_color.a;
}
