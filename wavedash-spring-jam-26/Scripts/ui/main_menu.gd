extends Control

## Autumn main menu. Owns the gameplay world instance and drives the run lifecycle:
## start / pause-resume / win / lose / retry / return-to-menu.

@export var button_box: Control
@export var settings_box: Control
@export var credits_box: Control
@export var asset_credits_box: Control
@export var end_screen: Node   # end_screen.tscn (CanvasLayer)

var scene = preload("res://scenes/world.tscn")
var instance

@onready var play_button: Button = button_box.get_node("Play")


func _ready() -> void:
	if end_screen != null:
		end_screen.retry_pressed.connect(_on_retry)
		end_screen.menu_pressed.connect(_on_return_to_menu)


func _physics_process(_delta: float) -> void:
	if not Input.is_action_just_pressed("escape"):
		return
	# No pause toggling while a win/lose screen is up.
	if instance == null or (end_screen != null and end_screen.visible):
		return
	if visible:
		_resume_game()
	else:
		_pause_to_menu()


# --- Run lifecycle ----------------------------------------------------------------

func _start_game() -> void:
	_reset_wood()
	instance = scene.instantiate()
	add_child(instance)
	instance.dam.shelter_complete.connect(_on_shelter_complete)
	var player: Node = instance.get_node_or_null("Player")
	if player != null and player.has_signal("died"):
		player.died.connect(_on_player_died)
	play_button.text = "Resume"
	_resume_game()


func _resume_game() -> void:
	hide()
	instance.process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pause_to_menu() -> void:
	_show_main_buttons()
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _clear_instance() -> void:
	if instance != null:
		instance.queue_free()
		instance = null


func _reset_wood() -> void:
	GameState.add_wood(-GameState.wood)


func _show_main_buttons() -> void:
	show()
	button_box.show()
	settings_box.hide()
	credits_box.hide()
	asset_credits_box.hide()


# --- Win / lose -------------------------------------------------------------------

func _on_shelter_complete() -> void:
	_freeze_world()
	end_screen.show_win()


func _on_player_died() -> void:
	_freeze_world()
	end_screen.show_lose()


func _freeze_world() -> void:
	if instance != null:
		instance.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_retry() -> void:
	_clear_instance()
	_start_game()


func _on_return_to_menu() -> void:
	_clear_instance()
	_reset_wood()
	play_button.text = "Play"
	_show_main_buttons()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Buttons ----------------------------------------------------------------------

func _on_play_pressed() -> void:
	if instance == null:
		_start_game()
	else:
		_resume_game()


func _on_settings_pressed() -> void:
	button_box.hide()
	settings_box.show()


func _on_credits_pressed() -> void:
	button_box.hide()
	credits_box.show()


func _on_asset_credits_pressed() -> void:
	credits_box.hide()
	asset_credits_box.show()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_back_button_pressed() -> void:    # Credits -> main
	button_box.show()
	credits_box.hide()


func _on_back_button_2_pressed() -> void:  # Settings -> main
	button_box.show()
	settings_box.hide()


func _on_asset_back_pressed() -> void:     # Asset credits -> credits
	asset_credits_box.hide()
	credits_box.show()
