extends Button

## Drop-in button that grows slightly when hovered or focused, for juicy menus.

@export var hover_scale: float = 1.12
@export var tween_time: float = 0.12

var _base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	_recenter_pivot()
	resized.connect(_recenter_pivot)
	mouse_entered.connect(_grow)
	mouse_exited.connect(_shrink)
	focus_entered.connect(_grow)
	focus_exited.connect(_shrink)

func _recenter_pivot() -> void:
	# Scale from the centre so the button doesn't drift while growing.
	pivot_offset = size * 0.5

func _grow() -> void:
	_tween_to(_base_scale * hover_scale)

func _shrink() -> void:
	_tween_to(_base_scale)

func _tween_to(target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target, tween_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
