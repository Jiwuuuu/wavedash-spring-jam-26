class_name InteractableBody extends StaticBody3D

@export var is_interactable: bool = true

func _ready() -> void:
	# Setting the collision layer to be the same as the Interaction Area on the player.
	collision_layer = 2

# This is a placeholder function and will be overriten in the inherited classes of the InteractableBody
func on_interact():
	pass
