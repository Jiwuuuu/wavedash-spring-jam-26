class_name TreeInteraction extends InteractableBody

# Sprite (texture / species / frame) is baked into each tree .tscn so it is
# visible in the editor. This script only handles the harvest interaction.

var cut_down: bool = false

func on_interact():
	cut_down = true
	print("Cut Down Tree")
