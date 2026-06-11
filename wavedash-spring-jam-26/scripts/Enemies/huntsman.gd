extends CharacterBody3D

@export_group("Movement")
@export var move_speed: float = 1.5
@export var turn_speed: float = 6.0

@export_group("Wander")
@export var wander_radius: float = 8.0
@export var wander_jitter: float = 3.0
@export var wander_time_min: float = 3.0
@export var wander_time_max: float = 6.0
@export var idle_time_min: float = 1.0
@export var idle_time_max: float = 3.0

@export_group("Hearing")
@export var player: Node3D                      
@export var hearing_radius: float = 12.0       
@export var sprint_speed_threshold: float = 2.5 
@export var proximity_radius: float = 3.0     
@export var hearing_fill: float = 40.0         
@export var proximity_fill: float = 60.0       
@export var detection_decay: float = 30.0   

@export_group("Combat")
@export var preferred_distance: float = 8.0   
@export var distance_buffer: float = 1.5     
@export var reposition_speed: float = 2.5    
@export var fire_interval: float = 1.2        
@export var muzzle_height: float = 1.6   
@export var spread_degrees: float = 4.0   
@export var shot_range: float = 30.0         

signal detection_changed(level: float)
signal player_detected

enum State { IDLE, WANDER, ENGAGED }
var _state: State = State.IDLE
var _home_position: Vector3
var _idle_timer: float = 0.0
var _wander_timer: float = 0.0
var _wander_angle: float = 0.0
var _detection_level: float = 0.0
var _detected: bool = false
var _fire_timer: float = 0.0

func _ready() -> void:
	_home_position = global_position
	_start_idle()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	$SubViewport/ProgressBar.value = _detection_level
	if _is_player_hidden():
		_detection_level = 0.0
		_detected = false
	elif _detected:
		_detection_level = 100.0
	else:
		var rate: float = _sense_rate()
		if rate > 0.0:
			_detection_level = minf(_detection_level + rate * delta, 100.0)
			if _detection_level >= 100.0 and not _detected:
				_detected = true
				player_detected.emit()
				print("Huntsman heard the player!")
		else:
			_detection_level = maxf(_detection_level - detection_decay * delta, 0.0)
			if _detection_level <= 0.0:
				_detected = false
	detection_changed.emit(_detection_level)

	if _detected and (_state == State.IDLE or _state == State.WANDER):
		_start_engaged()
	elif not _detected and _state == State.ENGAGED:
		_start_idle()

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.WANDER:
			_process_wander(delta)
		State.ENGAGED:
			_process_engaged(delta)

	move_and_slide()

func _is_player_hidden() -> bool:
	return player != null and player.get_meta("hidden_count", 0) > 0

func _sense_rate() -> float:
	if player == null:
		return 0.0
	if _is_player_hidden():
		return 0.0
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	if dist <= proximity_radius:
		return proximity_fill
	if dist <= hearing_radius:
		var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
		if speed > sprint_speed_threshold:
			return hearing_fill
	return 0.0

func _process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	velocity.z = move_toward(velocity.z, 0.0, move_speed)
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_start_wander()

func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_start_idle()
		return
	_wander_angle += randf_range(-1.0, 1.0) * wander_jitter * delta
	var direction: Vector3 = Vector3(-sin(_wander_angle), 0.0, -cos(_wander_angle))
	var from_home: Vector3 = global_position - _home_position
	from_home.y = 0.0
	var dist: float = from_home.length()
	if dist > wander_radius:
		var home_dir: Vector3 = -from_home.normalized()
		var pull: float = clampf((dist - wander_radius) / wander_radius, 0.0, 1.0)
		direction = direction.lerp(home_dir, pull).normalized()
		_wander_angle = atan2(-direction.x, -direction.z)
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	_face_direction(direction, delta)

func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var target_yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

func _start_idle() -> void:
	_state = State.IDLE
	_idle_timer = randf_range(idle_time_min, idle_time_max)

func _start_wander() -> void:
	_state = State.WANDER
	_wander_timer = randf_range(wander_time_min, wander_time_max)
	_wander_angle = rotation.y
	
	
	#combat
	
func _start_engaged() -> void:
	_state = State.ENGAGED
	_fire_timer = fire_interval   

func _process_engaged(delta: float) -> void:
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	var dir: Vector3 = to_player.normalized() if dist > 0.001 else Vector3.FORWARD

	if dist < preferred_distance - distance_buffer:
		velocity.x = -dir.x * reposition_speed
		velocity.z = -dir.z * reposition_speed
	elif dist > preferred_distance + distance_buffer:
		velocity.x = dir.x * reposition_speed
		velocity.z = dir.z * reposition_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, reposition_speed)
		velocity.z = move_toward(velocity.z, 0.0, reposition_speed)

	_face_direction(dir, delta)   

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_shoot()

func _shoot() -> void:
	var muzzle: Vector3 = global_position + Vector3.UP * muzzle_height
	var base_dir: Vector3 = (player.global_position - muzzle).normalized()

	var right: Vector3 = base_dir.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up: Vector3 = right.cross(base_dir).normalized()
	var spin: float = randf() * TAU
	var mag: float = randf_range(0.0, deg_to_rad(spread_degrees))
	var axis: Vector3 = (right * cos(spin) + up * sin(spin)).normalized()
	var dir: Vector3 = base_dir.rotated(axis, mag)

	var ray_end: Vector3 = muzzle + dir * shot_range
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(muzzle, ray_end)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)

	var endpoint: Vector3 = ray_end
	if not hit.is_empty():
		endpoint = hit.position
		if hit.collider == player:
			print("shot")
	_spawn_tracer(muzzle, endpoint)

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	if from.distance_to(to) < 0.01:
		return
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.03, from.distance_to(to))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	box.material = mat
	beam.mesh = box
	get_tree().current_scene.add_child(beam)
	beam.global_position = (from + to) * 0.5
	beam.look_at(to, Vector3.UP)

	var tween := create_tween()
	tween.tween_interval(0.15)                            
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.08)
	tween.tween_callback(beam.queue_free)
