## 世界中的可控制电脑。负责交互、控制切换、3D 屏幕和鼠标映射。


#region 依赖
extends Node3D

signal control_requested(controller: Node)
signal game_launch_requested(computer: Node)
const InteractableType = preload("res://interactables/interactable.gd")
const ComputerOSType = preload("res://interactables/computer/os/computer_os.gd")

@export var control_camera: Camera3D
@export var computer_view: SubViewportContainer
@export_dir var disk_root: String = "res://interactables/computer/computer_content/computer_01/C"
@export var admin_password: String = "admin"
@export var game_installed: bool = false
@export var is_powered_on: bool = false
@export var auto_start_once: bool = false

@onready var interactable: InteractableType = $Interactable
@onready var screen: MeshInstance3D = $Visual/Screen
@onready var sub_viewport: SubViewport = $ComputerLayer/ComputerView/SubViewport
@onready var computer_os: ComputerOSType = $ComputerLayer/ComputerView/SubViewport/ComputerOS
@onready var boot_audio: AudioStreamPlayer3D = $BootAudio

var auto_power_on_pending: bool = false
#endregion

#region 生命周期

## 连接电脑自己的交互节点，并初始化它的内部系统。
func _ready() -> void:
	interactable.interacted.connect(_on_interactable_interacted)
	computer_os.game_installed.connect(func() -> void: game_installed = true)
	computer_os.game_launch_requested.connect(func() -> void: game_launch_requested.emit(self))
	computer_os.power_off_requested.connect(power_off)
	computer_os.boot_finished.connect(boot_audio.play)
	computer_os.setup(disk_root, admin_password, game_installed, is_powered_on)
	_setup_screen_texture()
	if auto_start_once:
		auto_start_once = false
		auto_power_on_pending = true
		_request_initial_control.call_deferred()


## 等 Root 连接控制请求后，再触发新游戏唯一一次自动进入电脑。
func _request_initial_control() -> void:
	control_requested.emit(self)


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
		if auto_power_on_pending:
			auto_power_on_pending = false
			power_on()


## 将通用交互转换为 Root 可处理的 Controller 请求。
func _on_interactable_interacted(_interactor: Node3D) -> void:
	control_requested.emit(self)
#endregion

#region 电源

## 实体电源按钮使用同一入口切换开关机状态。
func toggle_power() -> void:
	if is_powered_on:
		power_off()
	else:
		power_on()


## 通电并让 OS 播放完整启动过程。
func power_on() -> void:
	if is_powered_on:
		return
	is_powered_on = true
	computer_os.boot()


## 关机但不改变当前 Controller；屏幕与相机继续存在。
func power_off() -> void:
	if not is_powered_on:
		return
	is_powered_on = false
	boot_audio.stop()
	computer_os.shutdown()


## Root 保存前查询启动过渡是否已经结束。
func is_busy() -> bool:
	return computer_os.is_busy()
#endregion
