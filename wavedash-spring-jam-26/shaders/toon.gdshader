shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Banded toon lighting for lit surfaces (ground, props).

uniform vec4 albedo : source_color = vec4(0.36, 0.55, 0.34, 1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform int bands : hint_range(1, 8) = 3;
uniform float band_softness : hint_range(0.0, 0.5, 0.01) = 0.02;
uniform vec3 ambient_tint : source_color = vec3(0.35, 0.4, 0.45);

// Wind sway. Off by default; set > 0 only on tree materials. Base stays, canopy sways.
uniform float wind_strength : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float sway_speed : hint_range(0.0, 10.0, 0.1) = 1.5;
uniform float wind_direction : hint_range(0.0, 360.0, 1.0) = 90.0;
// World Y of the object's base, set by the tree script / TerrainSnap. Keeps sway
// the same on a hilltop as on flat ground. 0 == the original "above world zero" look.
uniform float base_y = 0.0;

void vertex() {
	if (wind_strength > 0.0) {
		// World height = canopy sways more than base; world XZ phase desyncs neighbours.
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		// Height above the tree's BASE — same sway on a peak as on flat ground.
		float h = max(world_pos.y - base_y, 0.0);
		float phase = TIME * sway_speed + world_pos.x + world_pos.z;
		float sway = sin(phase) * wind_strength * h;
		float rad = wind_direction * (3.14159265 / 180.0);
		VERTEX.x += sway * cos(rad);
		VERTEX.z += sway * sin(rad);
	}
}

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
}

void light() {
	// Quantise N·L into `bands` discrete steps.
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float scaled = ndl * float(bands);
	float lower = floor(scaled);
	float soft = max(band_softness, 0.12);
	float frac_part = smoothstep(0.5 - soft, 0.5 + soft, fract(scaled));
	float stepped = (lower + frac_part) / float(bands);

	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * stepped * ALBEDO;
	// Ambient tint lifts the banded darks.
	DIFFUSE_LIGHT += ambient_tint * ALBEDO * (1.0 - stepped) * 0.28;
}
