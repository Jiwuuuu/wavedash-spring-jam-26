extends Node

## Autoload singleton (register as "GameState"). Tracks run-wide resources.
## Everything that grants/spends wood goes through here; the HUD listens to the
## signal. Dam progress will read from here in the next slice.

signal wood_changed(wood: int)

var wood: int = 0

func add_wood(amount: int = 1) -> void:
	wood += amount
	wood_changed.emit(wood)
