class_name WoodChewable extends InteractableBody

## A fallen log the beaver chews to gain wood, then it poofs away. Uses the same chew
## interface as trees (player_interaction_component calls chew()/cancel_chew() while E
## is held) and the same floating chew bar.

const CHEW_BAR: PackedScene = preload("res://scenes/ui/chew_bar.tscn")
const CHEW_FX: PackedScene = preload("res://scenes/fx/chew_fx.tscn")

@export var wood_amount: int = 2
@export var chew_duration: float = 1.2
@export var decay_rate: float = 1.5
@export var bar_height: float = 1.0
@export var fx_offset: Vector3 = Vector3(0.0, 0.15, 0.0)

var chew_progress: float = 0.0
var _decaying: bool = false
var _consumed: bool = false
var _bar: Node3D
var _bar_fill: Range
var _fx: Node3D
var _chips: CPUParticles3D


func _ready() -> void:
	if prompt_text == "":
		prompt_text = "Hold E to chew"
	prompt_height = 1.2
	super._ready()


func chew(delta: float) -> void:
	if _consumed:
		return
	_decaying = false
	suppress_prompt(true)
	chew_progress += delta
	_ensure_bar()
	_ensure_fx()
	_set_emitting(true)
	_update_bar()
	if chew_progress >= chew_duration:
		_consume()


func cancel_chew() -> void:
	_decaying = true
	_set_emitting(false)


func _process(delta: float) -> void:
	if _consumed or not _decaying:
		return
	chew_progress = maxf(chew_progress - decay_rate * delta, 0.0)
	_update_bar()
	if chew_progress <= 0.0:
		_decaying = false
		_free_bar()
		suppress_prompt(false)


func _update_bar() -> void:
	if _bar_fill != null:
		_bar_fill.value = clampf(chew_progress / chew_duration, 0.0, 1.0) * 100.0


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


func _ensure_fx() -> void:
	if _chips != null:
		return
	_fx = CHEW_FX.instantiate()
	add_child(_fx)
	_fx.position = fx_offset
	_chips = _fx.get_node_or_null("WoodChips")


func _set_emitting(on: bool) -> void:
	if _chips != null:
		_chips.emitting = on


func _consume() -> void:
	if _consumed:
		return
	_consumed = true
	is_interactable = false
	_free_bar()
	_set_emitting(false)
	GameState.add_wood(wood_amount)
	# Sink + shrink away.
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 0.6, 0.4).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", scale * 0.2, 0.4)
	tw.tween_callback(queue_free)
