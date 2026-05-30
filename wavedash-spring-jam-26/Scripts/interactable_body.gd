class_name InteractableBody extends StaticBody3D

@export var is_interactable: bool = true

func _ready() -> void:
	# Layer 1 = solid world (so the player's body collides with us), layer 2 =
	# interactable (so the player's InteractionArea, mask 2, still detects us).
	collision_layer = 1 | 2

# This is a placeholder function and will be overriten in the inherited classes of the InteractableBody
func on_interact():
	pass
