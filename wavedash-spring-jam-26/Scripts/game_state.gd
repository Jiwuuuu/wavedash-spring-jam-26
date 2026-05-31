extends Node

## Autoload "GameState". Tracks run-wide resources; the HUD listens to the signal.

signal wood_changed(wood: int)

var wood: int = 0

func add_wood(amount: int = 1) -> void:
	wood += amount
	wood_changed.emit(wood)
