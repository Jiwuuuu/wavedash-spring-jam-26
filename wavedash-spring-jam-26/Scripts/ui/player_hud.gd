extends CanvasLayer

## In-world player HUD: health bar + carried-wood counter + eat hint, plus a wolf
## danger meter (mirrors the wolf's detection) and a start-of-game controls hint.
## Reads health from the Player (via the exported ref) and wood/threat from GameState.

@export var player: Node

## Danger-bar fill ramps from yellow (just noticed) to red (about to pounce).
const DANGER_LOW := Color(0.95, 0.82, 0.2)
const DANGER_HIGH := Color(0.9, 0.1, 0.08)
## Controls hint: seconds fully shown, then fade length.
const HINT_HOLD := 5.0
const HINT_FADE := 0.6
## Hurt vignette: floor brightness for any hit, extra per fraction of max HP lost,
## and how long the red flash takes to fade out.
const HURT_MIN := 0.45
const HURT_FADE := 0.5

@onready var health_bar: ProgressBar = $Root/Health/HealthBar
@onready var wood_label: Label = $Root/WoodLabel
@onready var danger: VBoxContainer = $Root/Danger
@onready var danger_bar: ProgressBar = $Root/Danger/DangerBar
@onready var controls_hint: Control = $Root/ControlsHint
@onready var hurt_vignette: ColorRect = $Root/HurtVignette

var _hint_dismissed: bool = false
var _danger_pulse: Tween
var _hurt_tween: Tween
var _hint_tween: Tween
var _prev_health: float = -1.0

func _ready() -> void:
	# The menu re-instances the world on retry, but GameState (autoload) persists and
	# the hurt material can carry a leftover flash, so clear stale state up front.
	_reset_hurt_vignette()
	GameState.set_threat(0.0)

	if player != null and player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
		# Player emits an initial health_changed in its _ready; in case we
		# connected after that fired, seed from current values.
		if "health" in player and "max_health" in player:
			_on_health_changed(player.health, player.max_health)

	GameState.wood_changed.connect(_on_wood_changed)
	_on_wood_changed(GameState.wood)

	GameState.threat_changed.connect(_on_threat_changed)
	_on_threat_changed(GameState.threat_level)

	_show_controls_hint()

func _reset_hurt_vignette() -> void:
	if _hurt_tween != null and _hurt_tween.is_valid():
		_hurt_tween.kill()
	var mat := hurt_vignette.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("intensity", 0.0)

func _on_health_changed(health: float, max_health: float) -> void:
	# A drop in health = a hit: flash the hurt vignette, harder for bigger hits.
	# Guarded so the initial full-health seed in _ready doesn't flash.
	if _prev_health >= 0.0 and health < _prev_health and max_health > 0.0:
		_flash_hurt((_prev_health - health) / max_health)
	_prev_health = health
	health_bar.max_value = max_health
	health_bar.value = health

func _flash_hurt(damage_fraction: float) -> void:
	var mat := hurt_vignette.material as ShaderMaterial
	if mat == null:
		return
	var peak: float = clampf(HURT_MIN + damage_fraction * 1.2, HURT_MIN, 1.0)
	if _hurt_tween != null and _hurt_tween.is_valid():
		_hurt_tween.kill()
	mat.set_shader_parameter("intensity", peak)
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(mat, "shader_parameter/intensity", 0.0, HURT_FADE) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _on_wood_changed(wood: int) -> void:
	wood_label.text = "Wood: %d" % wood

func _on_threat_changed(level: float) -> void:
	danger.visible = level > 0.0
	danger_bar.value = level
	var fill := danger_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = DANGER_LOW.lerp(DANGER_HIGH, clampf(level / 100.0, 0.0, 1.0))
	if level >= 80.0:
		_start_danger_pulse()
	else:
		_stop_danger_pulse()

func _start_danger_pulse() -> void:
	if _danger_pulse != null and _danger_pulse.is_valid():
		return
	_danger_pulse = create_tween().set_loops()
	_danger_pulse.tween_property(danger, "modulate:a", 0.45, 0.3)
	_danger_pulse.tween_property(danger, "modulate:a", 1.0, 0.3)

func _stop_danger_pulse() -> void:
	if _danger_pulse != null and _danger_pulse.is_valid():
		_danger_pulse.kill()
		_danger_pulse = null
	danger.modulate.a = 1.0

func _show_controls_hint() -> void:
	controls_hint.visible = true
	controls_hint.modulate.a = 0.0
	# Wait a frame so the container has computed its size, then pop in from centre.
	await get_tree().process_frame
	if _hint_dismissed:
		return
	controls_hint.pivot_offset = controls_hint.size * 0.5
	controls_hint.scale = Vector2(0.92, 0.92)
	_hint_tween = create_tween().set_parallel()
	_hint_tween.tween_property(controls_hint, "modulate:a", 1.0, 0.25)
	_hint_tween.tween_property(controls_hint, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(HINT_HOLD).timeout
	_fade_out_hint()

func _fade_out_hint() -> void:
	if _hint_dismissed:
		return
	_hint_dismissed = true
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(controls_hint, "modulate:a", 0.0, HINT_FADE)
	_hint_tween.tween_callback(controls_hint.hide)

func _input(event: InputEvent) -> void:
	# The first real keypress/click dismisses the hint early.
	if _hint_dismissed:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_fade_out_hint()
	elif event is InputEventMouseButton and event.pressed:
		_fade_out_hint()
