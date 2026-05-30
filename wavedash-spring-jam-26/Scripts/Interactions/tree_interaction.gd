class_name TreeInteraction extends InteractableBody

## Hold-to-chew harvesting. The player's InteractionComponent calls chew(delta)
## each frame while E is held and this is the closest tree; cancel_chew() when it
## stops. Visuals (floating bar, trunk gnaw, shake, chips, topple) are driven here
## so all tree scenes get them for free. Works on the 3D trees (which have a
## "Trunk" mesh) and the legacy sprite trees (Trunk lookup just returns null).

signal harvested

const CHEW_BAR: PackedScene = preload("res://scenes/ui/chew_bar.tscn")
# Fallback only — trees should carry an authored "ChewFx" child positioned at the
# beaver's gnaw point. If one is missing, we instantiate this at _fallback_offset.
const CHEW_FX: PackedScene = preload("res://scenes/fx/chew_fx.tscn")

@export var chew_duration: float = 2.0
@export var decay_rate: float = 1.5
@export var min_trunk_scale: float = 0.45
@export var bar_height: float = 3.2
@export var leaf_color: Color = Color(0.33, 0.55, 0.33)
## Where a fallback ChewFx is spawned when the tree scene has no authored one.
@export var fallback_fx_offset: Vector3 = Vector3(0.0, 0.4, 0.0)

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

func _ready() -> void:
	super._ready() # InteractableBody sets collision_layer (solid + interactable)

func chew(delta: float) -> void:
	if _cutting:
		return
	_decaying = false
	chew_progress += delta
	_ensure_bar()
	_ensure_fx()
	_set_emitting(true) # steady stream while chewing; chips fly off and fall
	_update_visuals()

	_shake_cooldown -= delta
	if _shake_cooldown <= 0.0:
		_shake_cooldown = 0.16
		_shake()

	if chew_progress >= chew_duration:
		_cut()

func cancel_chew() -> void:
	# Player stopped / switched away — let progress decay back down (see _process).
	# Stop spawning new particles, but leave the airborne ones to fall (no restart).
	_decaying = true
	_set_emitting(false)

func _process(delta: float) -> void:
	if _cutting or not _decaying:
		return
	chew_progress = maxf(chew_progress - decay_rate * delta, 0.0)
	_update_visuals()
	if chew_progress <= 0.0:
		_decaying = false
		_free_bar()

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
	# Prefer the authored, editor-placed emitter; fall back to a spawned one.
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
	if _collision != null:
		_collision.set_deferred("disabled", true)
	_free_bar()
	_ensure_fx()
	# Stop the gnaw chip stream; airborne chips finish their fall on their own.
	if _chips != null:
		_chips.emitting = false
	# One bigger leaf shower as the tree comes down (single burst, not per-frame).
	if _leaves != null:
		_leaves.amount = 22
		_leaves.one_shot = true
		_leaves.restart()
	if _game_state != null:
		_game_state.add_wood(1)
	harvested.emit()

	var tw: Tween = create_tween()
	if _trunk != null:
		# Topple about the base, then sink + shrink away.
		tw.tween_property(self, "rotation:x", deg_to_rad(82.0), 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(0.15)
	tw.tween_property(self, "position:y", position.y - 2.5, 0.6).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", scale * 0.5, 0.6)
	tw.tween_callback(queue_free)

# Kept for non-chew interactables (single-press). Trees use chew() instead.
func on_interact() -> void:
	pass
