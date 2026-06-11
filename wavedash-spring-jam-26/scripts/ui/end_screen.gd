extends CanvasLayer

## Full-screen Win/Lose overlay. The main menu owns the world instance, so it
## drives this: call show_win()/show_lose() and listen to the two signals.

signal retry_pressed
signal menu_pressed

const WIN_SFX := preload("uid://ck4s5bgjcr4at")   # win_sfx.mp3
const LOSE_SFX := preload("uid://c65nivnewutis")  # lose_sfx.mp3

## Loudness of the win/lose stingers, in decibels.
@export var sfx_volume_db: float = 0.0

@onready var title: Label = $Root/Panel/VBox/Title

var _sfx: AudioStreamPlayer

func _ready() -> void:
	visible = false
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = sfx_volume_db
	add_child(_sfx)

func show_win() -> void:
	title.text = "You successfully built the dam!"
	visible = true
	_play(WIN_SFX)

func show_lose() -> void:
	title.text = "You got caught!"
	visible = true
	_play(LOSE_SFX)

func _play(stream: AudioStream) -> void:
	if _sfx == null:
		return
	_sfx.stream = stream
	_sfx.play()

func _on_retry_pressed() -> void:
	# main_menu hides this once the wipe covers the screen, so the swap stays hidden.
	retry_pressed.emit()

func _on_menu_pressed() -> void:
	menu_pressed.emit()
