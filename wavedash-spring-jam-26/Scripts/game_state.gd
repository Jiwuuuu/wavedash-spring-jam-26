extends Node

## Autoload "GameState". Tracks run-wide resources; the HUD listens to the signal.

signal wood_changed(wood: int)

var wood: int = 0

func _ready() -> void:
	# Opt into Wavedash platform features. Safe no-op off the web (init() is
	# guarded by OS.get_name() == "Web" inside the SDK). WavedashSDK is loaded
	# before GameState via autoload order so it is in the tree by now.
	WavedashSDK.init({})

func add_wood(amount: int = 1) -> void:
	wood += amount
	wood_changed.emit(wood)
