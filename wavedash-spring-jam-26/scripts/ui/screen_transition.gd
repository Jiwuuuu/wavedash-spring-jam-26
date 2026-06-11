extends CanvasLayer

## Slide/wipe screen transition. cover() slides a full-screen panel in from the left
## to hide the screen; reveal() slides it off to the right. Both are awaitable, so the
## menu can cover -> swap the world -> reveal. Driven by Scripts/ui/main_menu.gd.
##
## We slide the whole CanvasLayer via `offset.x` instead of moving the ColorRect, so the
## panel stays full-rect (always covers the screen) and only the layer translates.

@export var duration: float = 0.35

func _ready() -> void:
	# Parked off-screen to the left = uncovered.
	offset.x = -_width()

func _width() -> float:
	return get_viewport().get_visible_rect().size.x

## Slide in from the left until the screen is fully covered.
func cover() -> void:
	offset.x = -_width()
	var t := create_tween()
	t.tween_property(self, "offset:x", 0.0, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t.finished

## Slide off to the right to reveal, then re-park off-screen left for next time.
func reveal() -> void:
	var t := create_tween()
	t.tween_property(self, "offset:x", _width(), duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	offset.x = -_width()
