extends CharacterBody3D

# Movement Variables
@export_group("Movement Variables")
@export var walking_speed: float = 2.0
@export var sprinting_speed: float = 3.5
@export var acceleration: float = 5.0
@export var friction: float = 7.0

# Beaver sprite facing-swap. The Sprite3D's texture/billboard/filter are baked
# into player.tscn (visible in editor); here we only swap the directional art.
# 8-way: world +Z is toward the camera (down/front), -Z is away (up/back).
@export_group("Sprite")
@export var facing_deadzone: float = 0.2

# Smooth "delay follow" camera. Higher = snappier, lower = floatier/more delay.
@export_group("Camera")
@export var camera_follow_speed: float = 6.0

const TEX := {
	"down": preload("res://assets/sprites/Beaver/BeaveDOWN.png"),
	"down_right": preload("res://assets/sprites/Beaver/BeaveDownRight.png"),
	"right": preload("res://assets/sprites/Beaver/BeaverRight.png"),
	"up_right": preload("res://assets/sprites/Beaver/BeaverUpRight.png"),
	"up": preload("res://assets/sprites/Beaver/BeaverUp.png"),
	"up_left": preload("res://assets/sprites/Beaver/BeaverUpLeft.png"),
	"left": preload("res://assets/sprites/Beaver/BeaverLeft.png"),
	"down_left": preload("res://assets/sprites/Beaver/BeaverDownLeft.png"),
}

@onready var sprite: Sprite3D = $Sprite3D
@onready var camera: Camera3D = $Camera3D

var current_speed: float = 0
var movement_direction: Vector3
var _camera_offset: Vector3

func _ready() -> void:
	current_speed = walking_speed
	_setup_camera()

func _setup_camera() -> void:
	# Decouple the camera from the player so it can trail smoothly, while keeping
	# the exact offset / tilt / fov authored in player.tscn.
	_camera_offset = camera.position
	var tilt: Basis = camera.global_transform.basis
	camera.top_level = true
	camera.global_transform = Transform3D(tilt, global_position + _camera_offset)

func _process(_delta: float) -> void:
	_update_facing_sprite()

func _update_camera(delta: float) -> void:
	# Framerate-independent lerp toward the player (Godot's recommended formula),
	# leaving a little delay so the camera feels alive. Tilt/angle stay fixed.
	# Runs in _physics_process so it stays in lockstep with the player's movement
	# (avoids the sprite jittering against a per-frame camera).
	var target: Vector3 = global_position + _camera_offset
	var weight: float = 1.0 - exp(-camera_follow_speed * delta)
	camera.global_position = camera.global_position.lerp(target, weight)

func _update_facing_sprite() -> void:
	# Cosmetic facing from horizontal velocity. Idle keeps the last-faced sprite.
	if absf(velocity.x) < facing_deadzone and absf(velocity.z) < facing_deadzone:
		return

	var up: bool = velocity.z < -facing_deadzone    # moving away from camera
	var down: bool = velocity.z > facing_deadzone    # moving toward camera
	var right: bool = velocity.x > facing_deadzone
	var left: bool = velocity.x < -facing_deadzone

	var key: String
	if up and right:
		key = "up_right"
	elif up and left:
		key = "up_left"
	elif down and right:
		key = "down_right"
	elif down and left:
		key = "down_left"
	elif up:
		key = "up"
	elif down:
		key = "down"
	elif right:
		key = "right"
	else:
		key = "left"

	sprite.texture = TEX[key]

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Getting the Input direction of the player.
	var input_dir : Vector2 = Input.get_vector("left", "right", "forward", "backward")
	# Using the Input direction and lerping it to get a movement direction, This will make for a smoother movement input.
	movement_direction = lerp(movement_direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), acceleration * delta)
	
	if Input.is_action_just_pressed("sprint"):
		current_speed = sprinting_speed
	elif Input.is_action_just_released("sprint"):
		current_speed = walking_speed
	
	if movement_direction:
		velocity.x = movement_direction.x * current_speed
		velocity.z = movement_direction.z * current_speed
	else:
		# Lerping the velocity to 0 if there is no input.
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)

	move_and_slide()
	_update_camera(delta)
