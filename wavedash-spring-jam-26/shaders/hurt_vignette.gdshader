shader_type canvas_item;

// Full-screen red "hurt" vignette for the player HUD. player_hud.gd pulses
// `intensity` from a peak back to 0 each time the player takes a hit. Red is
// concentrated at the screen edges so the centre stays readable.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.65, 0.0, 0.0, 1.0);

void fragment() {
	// Distance from screen centre: ~0 in the middle, ~1 toward the corners.
	float d = length(UV - vec2(0.5)) * 1.4;
	float vig = smoothstep(0.35, 0.85, d);
	COLOR = vec4(vignette_color.rgb, vig * intensity);
}
