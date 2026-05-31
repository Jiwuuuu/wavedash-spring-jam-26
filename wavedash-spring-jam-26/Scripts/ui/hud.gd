extends Control

## Resource HUD. Reads wood from the GameState autoload via /root.

@onready var wood_label: Label = $WoodLabel

func _ready() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.wood_changed.connect(_on_wood_changed)
		_on_wood_changed(gs.wood)
	else:
		wood_label.text = "Wood: 0"

func _on_wood_changed(wood: int) -> void:
	wood_label.text = "Wood: %d" % wood
