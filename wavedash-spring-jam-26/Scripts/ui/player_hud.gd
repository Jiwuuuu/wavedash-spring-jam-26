extends CanvasLayer

## In-world player HUD: health bar + carried-wood counter + eat hint.
## Reads health from the Player (via the exported ref) and wood from GameState.

@export var player: Node

@onready var health_bar: ProgressBar = $Root/Health/HealthBar
@onready var wood_label: Label = $Root/WoodLabel

func _ready() -> void:
	if player != null and player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
		# Player emits an initial health_changed in its _ready; in case we
		# connected after that fired, seed from current values.
		if "health" in player and "max_health" in player:
			_on_health_changed(player.health, player.max_health)

	GameState.wood_changed.connect(_on_wood_changed)
	_on_wood_changed(GameState.wood)

func _on_health_changed(health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = health

func _on_wood_changed(wood: int) -> void:
	wood_label.text = "Wood: %d" % wood
