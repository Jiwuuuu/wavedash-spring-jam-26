extends InteractableBody

var cut_down: bool = false

func on_interact():
	cut_down = true
	print("Cut Down Tree")
