extends Node

@export var can_interact: bool = true

@onready var interaction_area: Area3D = $"../InteractionArea"

var player: CharacterBody3D
var area_bodies: Array
var _chew_target: Node = null
var _focused: InteractableBody = null

func _ready() -> void:
	player = get_parent()

func _process(delta: float) -> void:
	area_bodies = _get_area_bodies()
	_update_focus()
	_handle_hold_chew(delta)
	_handle_press_interact()

# Show the floating prompt on the closest in-range interactable; clear the previous.
func _update_focus() -> void:
	var body: InteractableBody = _get_closest_interactable() if can_interact else null
	if body == _focused:
		return
	if _focused != null and is_instance_valid(_focused):
		_focused.set_focused(false)
	_focused = body
	if _focused != null:
		_focused.set_focused(true)

# Hold "interact" to chew the closest chewable interactable (trees).
func _handle_hold_chew(delta: float) -> void:
	var target: Node = _get_chew_target()
	if target != _chew_target:
		# Stopped or switched trees: reset the old one.
		if _chew_target != null and is_instance_valid(_chew_target) and _chew_target.has_method("cancel_chew"):
			_chew_target.cancel_chew()
		_chew_target = target
	if _chew_target != null and _chew_target.has_method("chew"):
		_chew_target.chew(delta)

func _get_chew_target() -> Node:
	if not can_interact or not Input.is_action_pressed("interact"):
		return null
	if !area_bodies:
		return null
	var body: InteractableBody = _get_closest_interactable()
	if body != null and body.is_interactable and body.has_method("chew"):
		return body
	return null

# Single-press still works for non-chew interactables.
func _handle_press_interact() -> void:
	if not Input.is_action_just_pressed("interact") or not can_interact:
		return
	if !area_bodies:
		return
	var body: InteractableBody = _get_closest_interactable()
	if body == null or not body.is_interactable:
		return
	if body.has_method("chew"):
		return # handled by hold-to-chew
	body.on_interact()

func _get_area_bodies() -> Array:
	if !interaction_area.has_overlapping_bodies(): return []
	return interaction_area.get_overlapping_bodies()


func _get_closest_interactable() -> InteractableBody:
	var closest_body: Node3D
	var closest_distance: float = INF

	for body in area_bodies:
		if !body is InteractableBody: continue

		var distance_to_body: float = player.global_position.distance_to(body.global_position)
		if distance_to_body < closest_distance:
			closest_distance = distance_to_body
			closest_body = body

	return closest_body
