shader_type spatial;
render_mode unshaded, cull_disabled;

// Wind sway for the Sprite3D billboard trees. As material_override it reimplements
// fixed-Y billboard + binary alpha cutout, plus a canopy sway. Shares wind uniforms
// with toon.gdshader. Pass the sprite's texture into `tex`.

uniform sampler2D tex : source_color, filter_nearest;
uniform float alpha_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;

uniform float wind_strength : hint_range(0.0, 1.0, 0.001) = 0.06;
uniform float sway_speed : hint_range(0.0, 10.0, 0.1) = 1.5;
uniform float wind_direction : hint_range(0.0, 360.0, 1.0) = 90.0;

void vertex() {
	// UV.y is 0 at the top, 1 at the bottom, so (1 - UV.y) is 0 at base, 1 at crown.
	float mask = 1.0 - UV.y;
	float phase = TIME * sway_speed + (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z);
	float sway = sin(phase) * wind_strength * mask;
	float rad = wind_direction * (3.14159265 / 180.0);
	VERTEX.x += sway * cos(rad);
	VERTEX.z += sway * sin(rad);

	// Fixed-Y billboard, preserving world scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	// Binary cutout keeps crisp pixel edges + depth.
	ALPHA_SCISSOR_THRESHOLD = alpha_threshold;
}
