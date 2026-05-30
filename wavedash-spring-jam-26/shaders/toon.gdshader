shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Stepped/banded toon lighting for lit surfaces (ground, props). Sprites stay
// unshaded and are unaffected. Clean Godot 4.6 spatial shader (light() banding).

uniform vec4 albedo : source_color = vec4(0.36, 0.55, 0.34, 1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform int bands : hint_range(1, 8) = 3;
uniform float band_softness : hint_range(0.0, 0.5, 0.01) = 0.02;
uniform vec3 ambient_tint : source_color = vec3(0.35, 0.4, 0.45);

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
}

void light() {
	// Stepped diffuse: quantise N·L into `bands` discrete steps.
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float scaled = ndl * float(bands);
	float lower = floor(scaled);
	// soft edge between bands so it isn't strictly aliased at low-res
	float frac_part = smoothstep(0.5 - band_softness, 0.5 + band_softness, fract(scaled));
	float stepped = (lower + frac_part) / float(bands);

	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * stepped * ALBEDO;
	// lift shadows slightly with an ambient tint so banded darks don't go pure black
	DIFFUSE_LIGHT += ambient_tint * ALBEDO * (1.0 - stepped) * 0.15;
}
