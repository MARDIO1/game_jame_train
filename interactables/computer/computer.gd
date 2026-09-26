## 世界中的可控制电脑。负责交互、控制切换、3D 屏幕和鼠标映射。


#region 依赖
extends Node3D
#什么鬼玩意，player自己不是InteractableType，为什么要依赖？
# player自己也不需要管理computeros，为什么要computeros?
#computer应该管理自己的subviwer!
#所有的viewer丢给界，世界给player看什么就看什么！

signal control_requested(controller: Node)
const InteractableType = preload("res://interactables/interactable.gd")
const ComputerOSType = preload("res://interactables/computer/os/computer_os.gd")

@export var control_camera: Camera3D
@export var computer_view: SubViewportContainer
@export_dir var disk_root: String = "res://computer_content/computer_01/C"
@export var admin_password: String = "admin"

@onready var interactable: InteractableType = $Interactable
@onready var screen: MeshInstance3D = $Visual/Screen
@onready var sub_viewport: SubViewport = $ComputerLayer/ComputerView/SubViewport
@onready var computer_os: ComputerOSType = $ComputerLayer/ComputerView/SubViewport/ComputerOS
#endregion

#region 生命周期

## 连接电脑自己的交互节点，并初始化它的内部系统。
func _ready() -> void:
	interactable.interacted.connect(_on_interactable_interacted)
	computer_os.setup(disk_root, admin_password)
	_setup_screen_texture()


## 鼠标离开电脑画面时只隐藏虚拟指针，不移动真实鼠标。
func _input(event: InputEvent) -> void:
	if computer_os.is_active and event is InputEventMouseMotion:
		_update_cursor((event as InputEventMouseMotion).position)
#endregion

#region 显示

## 将本机 SubViewport 的实时纹理绑定到自己的 3D 屏幕。
func _setup_screen_texture() -> void:
	var screen_material: StandardMaterial3D = screen.get_active_material(0).duplicate() as StandardMaterial3D
	screen_material.albedo_texture = sub_viewport.get_texture()
	screen.material_override = screen_material


## 根据 3D 屏幕投影对齐可交互的高清界面显示层。这个也应该交给computer自己！
func _update_view_rect() -> void:
	var screen_size_m: Vector3 = screen.mesh.get_aabb().size
	var top_left_world: Vector3 = screen.to_global(Vector3(-screen_size_m.x / 2.0, screen_size_m.y / 2.0, screen_size_m.z / 2.0))
	var bottom_right_world: Vector3 = screen.to_global(Vector3(screen_size_m.x / 2.0, -screen_size_m.y / 2.0, screen_size_m.z / 2.0))
	var top_left: Vector2 = control_camera.unproject_position(top_left_world)
	var bottom_right: Vector2 = control_camera.unproject_position(bottom_right_world)
	var projected_size: Vector2 = bottom_right - top_left
	computer_view.size = Vector2(sub_viewport.size)
	var uniform_scale: float = minf(projected_size.x / computer_view.size.x, projected_size.y / computer_view.size.y)
	computer_view.scale = Vector2.ONE * uniform_scale
	computer_view.position = top_left + (projected_size - computer_view.size * uniform_scale) / 2.0


## 把窗口坐标换成电脑内部坐标，并标记指针是否仍在屏幕内。
func _update_cursor(mouse_position: Vector2) -> void:
	var view_rect: Rect2 = Rect2(computer_view.position, computer_view.size * computer_view.scale)
	computer_os.set_cursor((mouse_position - view_rect.position) / computer_view.scale, view_rect.has_point(mouse_position))
#endregion

#region Controller

## 开关电脑输入和高清界面；未控制时仍刷新 3D 屏幕。
func set_controlled(active: bool) -> void:
	if active:
		_update_view_rect()
	computer_view.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	computer_os.set_active(active)
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_update_cursor(get_viewport().get_mouse_position())


## 将通用交互转换为 Root 可处理的 Controller 请求。
func _on_interactable_interacted(_interactor: Node3D) -> void:
	control_requested.emit(self)
#endregion
