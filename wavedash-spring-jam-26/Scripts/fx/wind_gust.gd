extends CPUParticles3D

## Periodically fires a one-shot sideways burst of leaves so the ambient drift
## occasionally gets a livelier gust sweeping through the view.

@export var min_interval: float = 4.0
@export var max_interval: float = 8.0

var _timer: float = 0.0

func _ready() -> void:
	_timer = randf_range(min_interval, max_interval)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(min_interval, max_interval)
		restart()
