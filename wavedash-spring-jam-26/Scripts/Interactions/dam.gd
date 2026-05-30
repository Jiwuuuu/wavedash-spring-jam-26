class_name Shelter extends InteractableBody


signal shelter_upgraded(new_stage: int)
signal shelter_complete


@export var stage_textures: Array[Texture2D] = []


@export var wood_costs: Array[int] = [5, 10, 15]

var current_stage: int = 0

@onready var _sprite: Sprite3D = $Sprite3D


func _ready() -> void:
	super()                       
	is_interactable = true
	_apply_stage_visual()


func on_interact() -> void:
	if not is_interactable:
		return

	var max_stage := stage_textures.size() - 1

	if current_stage >= max_stage:
		return

	var cost: int = wood_costs[current_stage]

	if GameState.wood < cost:
		_flash_not_enough_wood()
		return

	GameState.add_wood(-cost)
	current_stage += 1
	_apply_stage_visual()
	shelter_upgraded.emit(current_stage)

	if current_stage >= max_stage:
		is_interactable = false      
		shelter_complete.emit()

func _apply_stage_visual() -> void:
	if stage_textures.is_empty():
		return
	var idx := clampi(current_stage, 0, stage_textures.size() - 1)
	_sprite.texture = stage_textures[idx]

func _flash_not_enough_wood() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1, 0.2, 0.2), 0.1)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)


func wood_needed_for_next() -> int:
	if current_stage >= wood_costs.size():
		return 0
	return wood_costs[current_stage]

func is_complete() -> bool:
	return current_stage >= stage_textures.size() - 1
