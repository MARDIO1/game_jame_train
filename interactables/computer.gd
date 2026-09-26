## 可控制电脑。负责交互请求、SubViewport 鼠标开关和内部测试界面。


#region 依赖
extends Node3D
signal control_requested(controller: Node)
const InteractableType = preload("res://interactables/interactable.gd")

@export var control_camera: Camera3D
@export var computer_view: SubViewportContainer
@export var test_clicked: bool = false

@onready var interactable: InteractableType = $Interactable
@onready var screen: MeshInstance3D = $Visual/Screen
@onready var sub_viewport: SubViewport = $ComputerLayer/ComputerView/SubViewport
@onready var test_label: Label = $ComputerLayer/ComputerView/SubViewport/ComputerUI/TestLabel
@onready var test_button: Button = $ComputerLayer/ComputerView/SubViewport/ComputerUI/TestButton
#endregion

#region 生命周期

## 连接电脑内部信号并恢复可存档的界面状态。
func _ready() -> void:
	interactable.interacted.connect(_on_interactable_interacted)
	test_button.pressed.connect(_on_test_button_pressed)
	_setup_screen_texture()
	_update_test_label()
#endregion

#region 显示

## 将 SubViewport 的实时画面设置到3D屏幕材质。
func _setup_screen_texture() -> void:
	var screen_material: StandardMaterial3D = screen.get_active_material(0).duplicate() as StandardMaterial3D
	screen_material.albedo_texture = sub_viewport.get_texture()
	screen.material_override = screen_material


## 根据3D屏幕投影自动对齐鼠标输入层。
func _update_view_rect() -> void:
	var screen_size_m: Vector3 = screen.mesh.get_aabb().size
	var top_left_world: Vector3 = screen.to_global(Vector3(-screen_size_m.x / 2.0, screen_size_m.y / 2.0, screen_size_m.z / 2.0))
	var bottom_right_world: Vector3 = screen.to_global(Vector3(screen_size_m.x / 2.0, -screen_size_m.y / 2.0, screen_size_m.z / 2.0))
	var top_left: Vector2 = control_camera.unproject_position(top_left_world)
	var bottom_right: Vector2 = control_camera.unproject_position(bottom_right_world)
	computer_view.position = top_left
	computer_view.size = bottom_right - top_left
#endregion

#region Controller

## 开关电脑鼠标输入；未控制时继续刷新 SubViewport。
func set_controlled(active: bool) -> void:
	if active:
		_update_view_rect()
	computer_view.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	computer_view.modulate.a = 1.0 if active else 0.0
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
#endregion

#region 交互请求

## 将通用交互转换为 Root 可处理的 Controller 请求。
func _on_interactable_interacted(_interactor: Node3D) -> void:
	control_requested.emit(self)
#endregion

#region 内部界面

## 切换可存档的测试按钮状态。
func _on_test_button_pressed() -> void:
	test_clicked = not test_clicked
	_update_test_label()


## 根据测试状态更新电脑界面文字。
func _update_test_label() -> void:
	test_label.text = "点击成功" if test_clicked else "等待点击"
#endregion
