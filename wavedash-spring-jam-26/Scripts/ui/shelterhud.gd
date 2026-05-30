extends Control

@export var shelter: Shelter



func _ready() -> void:
	
	GameState.wood_changed.connect(_refresh)
	shelter.shelter_upgraded.connect(func(_s): _refresh(GameState.wood))
	shelter.shelter_complete.connect(_on_complete)
	_refresh(GameState.wood)

func _refresh(wood: int) -> void:
	if not shelter:
		return
	var max_stage := shelter.stage_textures.size() - 1
	var cost      := shelter.wood_needed_for_next()
	if shelter.is_complete():
		self.text = "YAY"
	else:
		self.text = (
			"Dam: %d / %d\nWood: %d  (need %d)"
			% [shelter.current_stage, max_stage, wood, cost]
		)

func _on_complete() -> void:
	self.text = "WOOHOOO"
