extends Label3D

## Floating "Get inside to hide" hint. Shows when the player is nearby and NOT yet
## hidden (inside a HideArea). Hiding makes wolves unable to detect the player — see
## hide_area.gd (sets the player's `hidden_count` meta) and wolf.gd._is_player_hidden().

@export var show_distance: float = 5.0

var _player: Node3D


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	visible = false


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var near: bool = global_position.distance_to(_player.global_position) <= show_distance
	var hidden: bool = int(_player.get_meta("hidden_count", 0)) > 0
	visible = near and not hidden
