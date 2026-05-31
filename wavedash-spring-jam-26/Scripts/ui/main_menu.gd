extends Control

@export_file("*.tscn") var game_scene: String

@export var button_box : Control
@export var settings_box : Control
@export var credits_box : Control

var scene = preload("res://Scenes/world.tscn")
var instance

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("escape"):
		if self.visible == true:
			self.hide()
			instance.process_mode = ProcessMode.PROCESS_MODE_ALWAYS
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			self.show()
			instance.process_mode = ProcessMode.PROCESS_MODE_DISABLED
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_play_pressed() -> void:
	#get_tree().change_scene_to_file(game_scene)
	instance = scene.instantiate()
	add_child(instance)
	$ButtonBox/Play.hide()
	hide()

func _on_settings_pressed() -> void:
	button_box.hide()
	settings_box.show()

func _on_credits_pressed() -> void:
	button_box.hide()
	credits_box.show()


func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_back_button_pressed() -> void:
	button_box.show()
	credits_box.hide()



func _on_back_button_2_pressed() -> void:
	button_box.show()
	settings_box.hide()
