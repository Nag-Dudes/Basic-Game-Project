
extends CharacterBody3D

# MOVEMENT SETTINGS
@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 5.0
@export var rotation_speed: float = 8.0

# CAMERA SETTINGS
@export var mouse_sensitivity: float = 0.003
@export var min_zoom: float = 0.5
@export var max_zoom: float = 8.0
@export var zoom_step: float = 0.5

# CAMERA REFERENCES
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

# MODEL AND ANIMATION REFERENCES
@onready var model: Node3D = $Model
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")

# CAMERA MODE
var first_person: bool = false
var third_person_zoom: float = 5.0

# GRAVITY
var gravity: float = ProjectSettings.get_setting(
    "physics/3d/default_gravity"
)


func _ready() -> void:
	third_person_zoom = spring_arm.spring_length
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true

	animation_tree.active = true


func _unhandled_input(event: InputEvent) -> void:

	# MOUSE MOVEMENT
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			camera_pivot.rotate_y(
				-event.relative.x * mouse_sensitivity
			)

			camera_pivot.rotation.x -= (
				event.relative.y * mouse_sensitivity
			)

			camera_pivot.rotation.x = clampf(
				camera_pivot.rotation.x,
				deg_to_rad(-85),
				deg_to_rad(85)
			)

	# MOUSE WHEEL ZOOM
	if event is InputEventMouseButton and event.pressed:

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if not first_person:
				spring_arm.spring_length = clampf(
					spring_arm.spring_length - zoom_step,
					min_zoom,
					max_zoom
				)
				third_person_zoom = spring_arm.spring_length

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not first_person:
				spring_arm.spring_length = clampf(
					spring_arm.spring_length + zoom_step,
					min_zoom,
					max_zoom
				)
				third_person_zoom = spring_arm.spring_length

	# CAMERA TOGGLE
	if event.is_action_pressed("toggle_camera"):
		toggle_camera_mode()

	# ESCAPE TO RELEASE MOUSE
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# CLICK TO CAPTURE MOUSE AGAIN
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_camera_mode() -> void:

	first_person = not first_person

	if first_person:
		spring_arm.spring_length = 0.05
		model.visible = false
	else:
		spring_arm.spring_length = third_person_zoom
		model.visible = true


func _physics_process(delta: float) -> void:

	# APPLY GRAVITY
	if not is_on_floor():
		velocity.y -= gravity * delta

	# JUMP
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# GET WASD INPUT
	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
        "move_back"
	)

	# CONVERT INPUT INTO 3D MOVEMENT
	var direction := Vector3(
		input_direction.x,
		0,
		input_direction.y
	)

	# MAKE MOVEMENT RELATIVE TO CAMERA DIRECTION
	direction = direction.rotated(
		Vector3.UP,
		camera_pivot.rotation.y
	)

	direction = direction.normalized()

	# CHECK SPRINTING
	var is_sprinting := (
		Input.is_action_pressed("sprint")
		and input_direction.length() > 0.01
	)

	var current_speed := sprint_speed if is_sprinting else move_speed

	# APPLY HORIZONTAL MOVEMENT
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	# SMOOTHLY ROTATE CHARACTER TOWARD MOVEMENT DIRECTION
	if direction.length() > 0.01:

		var target_rotation: float = atan2(
			-direction.x,
			-direction.z
		) + PI

		model.rotation.y = rotate_toward(
			model.rotation.y,
			target_rotation,
			rotation_speed * delta
		)

	# MOVE CHARACTER AND HANDLE COLLISIONS
	move_and_slide()

	# UPDATE ANIMATION
	update_animation(input_direction, is_sprinting)


func update_animation(input_direction: Vector2, is_sprinting: bool) -> void:

	var target_animation: String

	# AIRBORNE
	if not is_on_floor():
		target_animation = "Jumping"

	# STANDING STILL
	elif input_direction.length() < 0.01:
		target_animation = "Idle"

	# SPRINTING
	elif is_sprinting:
		target_animation = "Fast Run"

	# NORMAL MOVEMENT
	else:
		target_animation = "Slow Run"

	# ONLY CHANGE ANIMATION WHEN NEEDED
	if animation_playback.get_current_node() != target_animation:
		animation_playback.travel(target_animation)
