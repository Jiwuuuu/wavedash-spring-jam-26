class_name InteractableBody extends StaticBody3D

@export var is_interactable: bool = true

## Floating world-space prompt shown above this object while the player is in range
## (empty = no prompt). Chewables suppress it while the chew bar is showing.
@export var prompt_text: String = ""
@export var prompt_height: float = 2.5

var _prompt: Label3D
var _focused: bool = false
var _prompt_suppressed: bool = false


func _ready() -> void:
	# Layer 1 = solid world, layer 2 = interactable (player's InteractionArea mask).
	collision_layer = 1 | 2
	_ensure_prompt()


func _ensure_prompt() -> void:
	if _prompt != null or prompt_text == "":
		return
	_prompt = Label3D.new()
	_prompt.text = prompt_text
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.pixel_size = 0.007
	_prompt.outline_size = 8
	_prompt.modulate = Color(1, 1, 1)
	_prompt.outline_modulate = Color(0, 0, 0, 0.7)
	_prompt.no_depth_test = true
	_prompt.position = Vector3(0.0, prompt_height, 0.0)
	add_child(_prompt)
	_prompt.visible = false


## Called by the player's interaction component as it gains/loses focus on this body.
func set_focused(focused: bool) -> void:
	_focused = focused
	_refresh_prompt()


func set_prompt_text(text: String) -> void:
	prompt_text = text
	_ensure_prompt()
	if _prompt != null:
		_prompt.text = text


## Hide the prompt without losing focus (e.g. while a chew bar is on screen).
func suppress_prompt(suppress: bool) -> void:
	_prompt_suppressed = suppress
	_refresh_prompt()


func _refresh_prompt() -> void:
	if _prompt != null:
		_prompt.visible = _focused and is_interactable and not _prompt_suppressed


# Overridden by inheriting classes.
func on_interact():
	pass
