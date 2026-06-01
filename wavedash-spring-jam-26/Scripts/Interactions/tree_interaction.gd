class_name TreeInteraction extends InteractableBody

## Hold-to-chew harvesting. The InteractionComponent calls chew(delta) while held,
## cancel_chew() when it stops. Drives the bar, trunk gnaw, shake, chips and topple.

signal harvested

const CHEW_BAR: PackedScene = preload("res://scenes/ui/chew_bar.tscn")
# Fallback when a tree has no authored "ChewFx" child.
const CHEW_FX: PackedScene = preload("res://scenes/fx/chew_fx.tscn")
const FALL_SFX: AudioStream = preload("uid://byqi77m1l3b1c")  # tree-falling.wav — uid ref is case-proof for web export
const CHEW_SFX: AudioStream = preload("uid://cq7tni0j48bxn")  # chewing_sfx.wav — loops while the player gnaws

@export var chew_duration: float = 2.0
@export var decay_rate: float = 1.5
@export var min_trunk_scale: float = 0.45
@export var bar_height: float = 3.2
@export var leaf_color: Color = Color(0.8, 0.35, 0.08)
## Uniform tree size. Applied in code so it overrides every placed instance.
@export var size_scale: float = 2.0
## Spawn offset for a fallback ChewFx.
@export var fallback_fx_offset: Vector3 = Vector3(0.0, 0.4, 0.0)

@export_group("Topple")

@export var fall_time: float = 1.2
@export var fall_rest: float = 0.8
@export var sink_time: float = 0.7
@export var fall_volume_db: float = 0.0
@export var fall_sfx_start: float = 3.6
## Loudness of the looping chew sound, in decibels.
@export var chew_volume_db: float = -6.0

var chew_progress: float = 0.0

var _decaying: bool = false
var _cutting: bool = false
var _shake_cooldown: float = 0.0

@onready var _trunk: Node3D = get_node_or_null("Trunk")
@onready var _collision: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var _game_state: Node = get_node_or_null("/root/GameState")

var _bar: Node3D
var _bar_fill: Range
var _fx: Node3D
var _chips: CPUParticles3D
var _leaves: CPUParticles3D
var _chew_player: AudioStreamPlayer3D

func _ready() -> void:
	if prompt_text == "":
		prompt_text = "Hold E to chew"
	super._ready()
	scale = Vector3.ONE * size_scale
	_apply_sway_base()
	_chew_player = AudioStreamPlayer3D.new()
	_chew_player.stream = CHEW_SFX
	_chew_player.volume_db = chew_volume_db
	add_child(_chew_player)

func _apply_sway_base() -> void:
	# Tell the toon sway shader where this tree's base is, so the canopy sways the
	# same whether the tree sits on flat ground or high on a mountain. Needs the
	# bark/leaf materials to be resource_local_to_scene (per tree instance).
	var by: float = global_position.y
	for child in get_children():
		var gi := child as GeometryInstance3D
		if gi == null:
			continue
		var mat := gi.material_override as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("base_y", by)

func chew(delta: float) -> void:
	if _cutting:
		return
	_decaying = false
	suppress_prompt(true)
	chew_progress += delta
	_ensure_bar()
	_ensure_fx()
	_set_emitting(true)
	# Re-arm the chew loop as soon as the one-shot clip ends, so it repeats while held.
	if _chew_player != null and not _chew_player.playing:
		_chew_player.play()
	_update_visuals()

	_shake_cooldown -= delta
	if _shake_cooldown <= 0.0:
		_shake_cooldown = 0.16
		_shake()

	if chew_progress >= chew_duration:
		_cut()

func cancel_chew() -> void:
	# Let progress decay (see _process); stop new particles but let airborne ones fall.
	_decaying = true
	_set_emitting(false)
	if _chew_player != null:
		_chew_player.stop()

func _process(delta: float) -> void:
	if _cutting or not _decaying:
		return
	chew_progress = maxf(chew_progress - decay_rate * delta, 0.0)
	_update_visuals()
	if chew_progress <= 0.0:
		_decaying = false
		_free_bar()
		suppress_prompt(false)

func _update_visuals() -> void:
	var ratio: float = clampf(chew_progress / chew_duration, 0.0, 1.0)
	if _bar_fill != null:
		_bar_fill.value = ratio * 100.0
	if _trunk != null:
		var s: float = lerpf(1.0, min_trunk_scale, ratio)
		_trunk.scale = Vector3(s, 1.0, s)

func _ensure_bar() -> void:
	if _bar == null:
		_bar = CHEW_BAR.instantiate()
		add_child(_bar)
		_bar.position = Vector3(0.0, bar_height, 0.0)
		_bar_fill = _bar.get_node_or_null("SubViewport/ProgressBar")

func _free_bar() -> void:
	if _bar != null:
		_bar.queue_free()
		_bar = null
		_bar_fill = null

func _shake() -> void:
	var t: Tween = create_tween()
	t.tween_property(self, "rotation:z", deg_to_rad(3.0), 0.05)
	t.tween_property(self, "rotation:z", deg_to_rad(-3.0), 0.05)
	t.tween_property(self, "rotation:z", 0.0, 0.05)

func _ensure_fx() -> void:
	if _chips != null or _leaves != null:
		return
	# Prefer the authored emitter; fall back to a spawned one.
	_fx = get_node_or_null("ChewFx")
	if _fx == null:
		_fx = CHEW_FX.instantiate()
		add_child(_fx)
		_fx.position = fallback_fx_offset
	_chips = _fx.get_node_or_null("WoodChips")
	_leaves = _fx.get_node_or_null("LeafBurst")
	if _leaves != null:
		_leaves.color = leaf_color

func _set_emitting(on: bool) -> void:
	if _chips != null:
		_chips.emitting = on
	if _leaves != null:
		_leaves.emitting = on

func _cut() -> void:
	if _cutting:
		return
	_cutting = true
	is_interactable = false
	if _chew_player != null:
		_chew_player.stop()
	if _collision != null:
		_collision.set_deferred("disabled", true)
	_free_bar()
	_ensure_fx()
	# Stop the chip stream; airborne chips finish falling on their own.
	if _chips != null:
		_chips.emitting = false
	# One bigger leaf shower as the tree comes down.
	if _leaves != null:
		_leaves.amount = 22
		_leaves.one_shot = true
		_leaves.restart()
	if _game_state != null:
		_game_state.add_wood(1)
	_play_fall_sfx()
	harvested.emit()

	var tw: Tween = create_tween()
	if _trunk != null:
		# Swing down with an accelerating (gravity-like) ease so it lands hard, then
		# lie on the ground a beat before sinking + shrinking away.
		tw.tween_property(self, "rotation:x", deg_to_rad(88.0), fall_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tw.tween_interval(fall_rest)
	tw.tween_property(self, "position:y", position.y - 2.5, sink_time).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", scale * 0.5, sink_time)
	tw.tween_callback(queue_free)

# Spawn the topple sound on a node that outlives this tree (it queue_frees after the
# topple, which would cut the clip short). Positional 3D so it fades with distance.
# Self-frees when the clip finishes.
func _play_fall_sfx() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = FALL_SFX
	p.volume_db = fall_volume_db
	host.add_child(p)
	p.global_position = global_position
	p.finished.connect(p.queue_free)
	p.play(fall_sfx_start)


# Trees use chew() instead of single-press.
func on_interact() -> void:
	pass
