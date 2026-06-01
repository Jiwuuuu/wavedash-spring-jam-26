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

# Survival: the wolf bites chunks off; eat carried wood (F) to heal.
@export_group("Health")
@export var max_health: float = 100.0
## HP restored per wood eaten (press "eat"). Costs 1 wood from the shared pool.
@export var eat_heal: float = 25.0
## Seconds of damage immunity after a hit (prevents multi-hit pounce chains).
@export var invuln_time: float = 0.6

## Emitted whenever health changes (HUD listens). Also fired once on _ready.
signal health_changed(health: float, max_health: float)
## Emitted once when health reaches 0.
signal died

var health: float = 0.0
var _invuln_timer: float = 0.0
var _dead: bool = false

@export_group("Audio")
@export var footstep_volume_db: float = -6.0
## Seconds between footsteps while walking / sprinting.
@export var footstep_interval_walk: float = 0.45
@export var footstep_interval_run: float = 0.30

const STEP_SFX := preload("res://assets/sfx/grass_step.wav")
var _footstep_player: AudioStreamPlayer3D
var _step_timer: float = 0.0


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
	health = max_health
	health_changed.emit(health, max_health)
	_setup_camera()
	_setup_footsteps()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# The pixel-outline post-process reads Forward+-only screen buffers
	# (normal-roughness/depth) that don't exist on the web Compatibility
	# renderer, so its camera-facing quad fails to compile and renders gray
	# over the whole view. Disable the effect on web; the game is unaffected.
	if OS.has_feature("web"):
		$Camera3D/Postprocess.hide()


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

# --- Health ----------------------------------------------------------------------

func take_damage(amount: float) -> void:
	if _dead or _invuln_timer > 0.0:
		return
	health = maxf(health - amount, 0.0)
	_invuln_timer = invuln_time
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_dead = true
		died.emit()


func heal(amount: float) -> void:
	if _dead:
		return
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)


# Spend one carried wood to heal. Trades dam-building progress for survival.
func _try_eat() -> void:
	if Input.is_action_just_pressed("eat") and GameState.wood > 0 and health < max_health:
		GameState.add_wood(-1)
		heal(eat_heal)


func _physics_process(delta: float) -> void:
	if _invuln_timer > 0.0:
		_invuln_timer -= delta
	_try_eat()

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
	_update_footsteps(delta)


# --- Footstep audio ---------------------------------------------------------------

func _setup_footsteps() -> void:
	_footstep_player = AudioStreamPlayer3D.new()
	_footstep_player.stream = STEP_SFX
	_footstep_player.volume_db = footstep_volume_db
	add_child(_footstep_player)


func _update_footsteps(delta: float) -> void:
	var planar_speed: float = Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or planar_speed < 0.3:
		_step_timer = 0.0   # so the next step fires immediately on the move
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = footstep_interval_run if current_speed >= sprinting_speed else footstep_interval_walk
		_footstep_player.pitch_scale = randf_range(0.9, 1.1)
		_footstep_player.play()
