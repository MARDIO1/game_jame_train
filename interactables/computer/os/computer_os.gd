## 电脑内部系统。负责桌面、鼠标、窗口和文件后缀关联。
extends Control

#region 依赖
const AppWindowType = preload("res://interactables/computer/os/app_window.gd")
const APP_WINDOW_SCENE: PackedScene = preload("res://interactables/computer/os/app_window.tscn")
const FILE_MANAGER_SCENE: PackedScene = preload("res://interactables/computer/os/apps/file_manager.tscn")
const TEXT_VIEWER_SCENE: PackedScene = preload("res://interactables/computer/os/apps/text_viewer.tscn")
const IMAGE_VIEWER_SCENE: PackedScene = preload("res://interactables/computer/os/apps/image_viewer.tscn")

@onready var file_manager_button: Button = $Desktop/FileManagerButton
@onready var window_layer: Control = $WindowLayer
@onready var custom_cursor: TextureRect = $CustomCursor
#endregion

#region 状态
#是否是活动状态，root控制，关联虚拟鼠标
var is_active: bool = false
#
var disk_root: String
#管理员密码
var admin_password: String
#窗口数组
var windows: Dictionary = {}
#内置程序数组
var apps: Dictionary = {}
#endregion

#region 生命周期

## 连接桌面入口，并在电脑未接管控制时隐藏自定义鼠标。
func _ready() -> void:
	file_manager_button.pressed.connect(_open_file_manager)
	custom_cursor.hide()


## 接收所属 Computer 的硬盘目录和管理员密码。
func setup(root_path: String, password: String) -> void:
	disk_root = root_path.trim_suffix("/")
	admin_password = password
	assert(DirAccess.open(disk_root) != null, "Computer 硬盘目录不存在: %s" % disk_root)
#endregion

#region 控制

## 开关电脑内部输入和自定义鼠标显示。
func set_active(active: bool) -> void:
	is_active = active
	custom_cursor.visible = false


## 只在鼠标位于电脑屏幕内时显示虚拟指针。
func set_cursor(cursor_position: Vector2, inside_screen: bool) -> void:
	custom_cursor.position = cursor_position
	custom_cursor.visible = is_active and inside_screen
#endregion

#region 软件

## 打开或重新显示唯一的文件管理器窗口。
func _open_file_manager() -> void:
	var file_manager: Control = _get_or_create_app("file_manager", "文件管理器", FILE_MANAGER_SCENE)
	file_manager.call("set_disk_root", disk_root)
	var open_signal: Signal = file_manager.get("file_open_requested")
	if not open_signal.is_connected(_open_file):
		open_signal.connect(_open_file)


## 创建软件及通用窗口；同一软件再次打开时复用原窗口。
func _get_or_create_app(app_id: String, title: String, app_scene: PackedScene) -> Control:
	if apps.has(app_id):
		var existing_window: AppWindowType = windows[app_id] as AppWindowType
		existing_window.open_window(title)
		return apps[app_id] as Control
	var app_window: AppWindowType = APP_WINDOW_SCENE.instantiate() as AppWindowType
	var app: Control = app_scene.instantiate() as Control
	window_layer.add_child(app_window)
	var window_index: int = windows.size() % 4
	app_window.position = Vector2(
		16.0 + float(window_index % 2) * 478.0,
		12.0 + float(floori(float(window_index) / 2.0)) * 184.0
	)
	app_window.set_content(app)
	app_window.open_window(title)
	windows[app_id] = app_window
	apps[app_id] = app
	return app
#endregion

#region 文件关联

## 根据真实文件后缀选择只读文本或图片查看器。
func _open_file(path: String) -> void:
	var extension: String = path.get_extension().to_lower()
	if extension == "txt":
		var text_viewer: Control = _get_or_create_app("text_viewer", path.get_file(), TEXT_VIEWER_SCENE)
		text_viewer.call("open_file", path)
		return
	if extension in ["png", "jpg", "jpeg", "webp"]:
		var image_viewer: Control = _get_or_create_app("image_viewer", path.get_file(), IMAGE_VIEWER_SCENE)
		image_viewer.call("open_file", path)
#endregion

#region 插U盘

## 预留 U 盘挂载接口；安装功能实现时接入文件管理器。
func mount_usb(_root_path: String) -> void:
	pass


## 预留 U 盘卸载接口。
func unmount_usb() -> void:
	pass
#endregion
