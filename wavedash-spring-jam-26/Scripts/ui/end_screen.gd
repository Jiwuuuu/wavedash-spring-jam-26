extends CanvasLayer

## Full-screen Win/Lose overlay. The main menu owns the world instance, so it
## drives this: call show_win()/show_lose() and listen to the two signals.

signal retry_pressed
signal menu_pressed

@onready var title: Label = $Root/Panel/VBox/Title

func _ready() -> void:
	visible = false

func show_win() -> void:
	title.text = "You successfully built the dam!"
	visible = true

func show_lose() -> void:
	title.text = "You got caught!"
	visible = true

func _on_retry_pressed() -> void:
	visible = false
	retry_pressed.emit()

func _on_menu_pressed() -> void:
	visible = false
	menu_pressed.emit()
