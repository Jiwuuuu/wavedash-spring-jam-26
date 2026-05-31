extends CharacterBody3D

@export_group("Movement Variables")
@export var walking_speed: float = 2.0
@export var sprinting_speed: float = 3.5
@export var acceleration: float = 5.0
@export var friction: float = 7.0

# 8-way facing swap: +Z is toward the camera, -Z away.
@export_group("Sprite")
@export var facing_deadzone: float = 0.2

# Higher = snappier follow, lower = floatier.
@export_group("Camera")
@export var camera_follow_speed: float = 6.0
@export var mouse_sensitivity: float = 0.0025
## Where the camera looks vertically (world-Y above the player origin).
@export var look_height: float = 1.0


const TEX := {
	"down": "BeaverDownWalk",
	"down_right": "BeaverDownRight",
	"right": "BeaverRight",
	"up_right": "BeaverUpRight",
	"up": "BeaverUpWalk",
	"up_left": "BeaverUpLeft",
	"left": "BeaverLeft",
	"down_left": "BeaverDownLeft",
}

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var camera: Camera3D = $Camera3D


var current_speed: float = 0
var movement_direction: Vector3
var _camera_offset: Vector3   # captured from the editor Camera3D position
var _cam_yaw: float
var _follow_pos: Vector3

# Set by River.gd while in water; inert defaults (no current, full speed) on land.
var water_current: Vector3 = Vector3.ZERO
var water_drag: float = 1.0

func _ready() -> void:
	current_speed = walking_speed
	_setup_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)

func _setup_camera() -> void:
	# Capture the Camera3D's local position set in the editor as the follow
	# offset. Moving the Camera3D node in the Godot viewport directly
	# controls the in-game camera angle and distance.
	_camera_offset = camera.position
	camera.top_level = true
	_cam_yaw = global_rotation.y
	_follow_pos = global_position
	_place_camera()

func _place_camera() -> void:
	var off: Vector3 = Basis(Vector3.UP, _cam_yaw) * _camera_offset
	camera.global_position = _follow_pos + off
	camera.look_at(_follow_pos + Vector3.UP * look_height, Vector3.UP)

func _update_camera(delta: float) -> void:
	var weight: float = 1.0 - exp(-camera_follow_speed * delta)
	_follow_pos = _follow_pos.lerp(global_position, weight)
	_cam_yaw = lerp_angle(_cam_yaw, global_rotation.y, weight)
	_place_camera()
	
func _process(_delta: float) -> void:
	_update_facing_sprite()
	
func _update_facing_sprite() -> void:
	# Cosmetic facing from horizontal velocity. Idle keeps the last-faced sprite.
	var local_vel: Vector3 = global_transform.basis.inverse() * velocity

	if absf(local_vel.x) < facing_deadzone and absf(local_vel.z) < facing_deadzone:
		return

	var up: bool = local_vel.z < -facing_deadzone
	var down: bool = local_vel.z > facing_deadzone
	var right: bool = local_vel.x > facing_deadzone
	var left: bool = local_vel.x < -facing_deadzone

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

	sprite.play(TEX[key])

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Lerp the input direction for smoother movement.
	var input_dir : Vector2 = Input.get_vector("left", "right", "forward", "backward")
	movement_direction = lerp(movement_direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), acceleration * delta)
	
	if Input.is_action_just_pressed("sprint"):
		current_speed = sprinting_speed
	elif Input.is_action_just_released("sprint"):
		current_speed = walking_speed
	
	var target_speed: float = current_speed * water_drag
	if movement_direction:
		velocity.x = movement_direction.x * target_speed
		velocity.z = movement_direction.z * target_speed
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)

	# Downstream current from a River (zero elsewhere).
	velocity.x += water_current.x
	velocity.z += water_current.z

	move_and_slide()
	_update_camera(delta)
