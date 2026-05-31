shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled;

// Stylized cartoon grass blade. Adapted from the Landscaper grass shader
// (godotshaders.com/shader/stylized-cartoon-grass) to be WEB / Compatibility
// (WebGL2) safe. Variants live in a sampler2DArray and the layer is chosen
// PER INSTANCE via MultiMesh custom data (INSTANCE_CUSTOM.x). A texture array
// layer is just a coordinate, so per-instance selection is legal on WebGL2 —
// unlike an array-of-samplers or Vulkan-only `instance uniform`.
//
// Top/root recolor comes from UV.y (QuadMesh: y=0 top, y=1 base) instead of a
// painted world-space color map, so it works standalone with autumn colors.

uniform sampler2DArray variants : filter_linear_mipmap;
varying flat float v_layer;

uniform vec3 top_color : source_color = vec3(0.694, 0.40, 0.239);   // autumn leaf (matches 3D trees)
uniform vec3 root_color : source_color = vec3(0.45, 0.31, 0.20);    // bark/dry-grass brown
uniform vec3 detail_color : source_color = vec3(0.30, 0.22, 0.15);  // darker vein/detail tint
uniform bool enable_details = true;
uniform bool billboard_y = true;

uniform float wind_strength : hint_range(0.0, 0.5, 0.001) = 0.10;
uniform float sway_speed : hint_range(0.0, 8.0, 0.1) = 1.0;
uniform float alpha_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;

void vertex() {
	// 1 at the blade tip, 0 at the base. Wind sways the tip, leaves the root planted.
	float tip = 1.0 - UV.y;

	// Per-instance phase from the blade's world origin (MODEL_MATRIX works per
	// MultiMesh instance, unlike NODE_POSITION_WORLD).
	float wx = MODEL_MATRIX[3].x;
	float wz = MODEL_MATRIX[3].z;
	float t = TIME * sway_speed;
	vec3 sway = vec3(
		sin(wx + t + UV.y) * tip * wind_strength,
		0.0,
		cos(wz + t * 0.7 + UV.y) * tip * wind_strength * 1.2
	);
	VERTEX += sway;

	// Per-instance variant layer from MultiMesh custom data (0 if not instanced).
	v_layer = INSTANCE_CUSTOM.x;

	if (billboard_y) {
		// Y-axis billboard: blade always faces the camera, stays upright.
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
	}

	COLOR.rgb = mix(root_color, top_color, tip);
}

void fragment() {
	vec4 v = texture(variants, vec3(UV, v_layer));
	vec3 albedo = COLOR.rgb;
	if (enable_details) {
		// `.r` of the variant darkens veins/detail; vertex color drives the base hue.
		albedo = mix(detail_color, albedo, v.r);
	}
	ALBEDO = albedo;
	// `.a` is the blade silhouette; binary cutout keeps crisp cartoon edges.
	ALPHA = v.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_threshold;
}
