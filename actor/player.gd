## 玩家移动与第一人称视角。依赖场景中的 Head 节点和项目的 move_*、escape 输入动作。

#region 依赖
extends CharacterBody3D
@onready var head: Node3D = $Head
#endregion

#region 状态机
enum game_state{UI,WORLD1}
var current_game_state:game_state= game_state.WORLD1
#endregion

#region 视角
const MOUSE_SENSITIVITY_RAD_PER_PIXEL: float = 0.002
## 进入场景时捕获鼠标。
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## 处理鼠标视角；Esc 释放鼠标，左键重新捕获。
func _unhandled_input(event: InputEvent) -> void:
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
	if not is_on_floor():
		velocity += get_gravity() * delta
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_world: Vector3 = transform.basis * Vector3(move_input.x, 0, move_input.y)
	velocity.x = move_world.x * SPEED_MPS
	velocity.z = move_world.z * SPEED_MPS
	move_and_slide()
#endregion
