class_name InteractableBody extends StaticBody3D

@export var is_interactable: bool = true

func _ready() -> void:
	# Layer 1 = solid world, layer 2 = interactable (player's InteractionArea mask).
	collision_layer = 1 | 2

# Overridden by inheriting classes.
func on_interact():
	pass
