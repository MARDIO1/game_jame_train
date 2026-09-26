## 玩家移动、第一人称视角与交互检测。依赖场景中的 Head、Camera3D 和 RayCast3D。

#region 依赖
extends CharacterBody3D

signal interact_hint_changed(text: String)

const InteractableType = preload("res://interactables/interactable.gd")

@onready var head: Node3D = $Head
@onready var interact_ray: RayCast3D = $Head/Camera3D/RayCast3D
#endregion

#region 交互
var current_interactable: InteractableType


## 检测相机中心当前指向的交互物，并同步高光与 HUD 提示。
func _update_interactable() -> void:
	var next_interactable: InteractableType = interact_ray.get_collider() as InteractableType
	if next_interactable == current_interactable:
		return
	if current_interactable != null:
		current_interactable.set_highlighted(false)
	current_interactable = next_interactable
	if current_interactable == null:
		interact_hint_changed.emit("")
	else:
		current_interactable.set_highlighted(true)
		interact_hint_changed.emit(current_interactable.get_interact_hint())
#endregion

#region 视角
const MOUSE_SENSITIVITY_RAD_PER_PIXEL: float = 0.002
## 进入场景时捕获鼠标。
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## 优先处理鼠标视角；Esc 释放鼠标，左键重新捕获。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY_RAD_PER_PIXEL)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * MOUSE_SENSITIVITY_RAD_PER_PIXEL, -PI / 2, PI / 2)
#endregion

#region 物理,移动
const SPEED_MPS: float = 5.0
## 每个物理帧读取 WASD，施加重力并移动玩家。
func _physics_process(delta: float) -> void:
	_update_interactable()
	if Input.is_action_just_pressed("interact") and current_interactable != null:
		current_interactable.interact(self)
	if not is_on_floor():
		velocity += get_gravity() * delta
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_world: Vector3 = transform.basis * Vector3(move_input.x, 0, move_input.y)
	velocity.x = move_world.x * SPEED_MPS
	velocity.z = move_world.z * SPEED_MPS
	move_and_slide()
#endregion
