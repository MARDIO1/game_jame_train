## 电脑内部系统。负责桌面、鼠标、窗口和文件后缀关联。
extends Control

#region 依赖
const AppWindowType = preload("res://interactables/computer/os/app_window.gd")
const APP_WINDOW_SCENE: PackedScene = preload("res://interactables/computer/os/app_window.tscn")
const FILE_MANAGER_SCENE: PackedScene = preload("res://interactables/computer/os/apps/file_manager.tscn")
const TEXT_VIEWER_SCENE: PackedScene = preload("res://interactables/computer/os/apps/text_viewer.tscn")
const IMAGE_VIEWER_SCENE: PackedScene = preload("res://interactables/computer/os/apps/image_viewer.tscn")
const CHAT_APP_SCENE: PackedScene = preload("res://interactables/computer/os/apps/chat_app.tscn")

@onready var file_manager_button: Button = $Desktop/FileManagerButton
@onready var chat_button: Button = $Desktop/ChatButton
@onready var window_layer: Control = $WindowLayer
@onready var custom_cursor: TextureRect = $CustomCursor
#endregion

#region 状态
#是否是活动状态，root控制，关联虚拟鼠标
var is_active: bool = false
#
var disk_root: String
var usb_root: String
#管理员密码
var admin_password: String
#窗口数组
var windows: Dictionary = {}
#内置程序数组
var apps: Dictionary = {}
var story: Story
#endregion

#region 生命周期

## 连接桌面入口，并在电脑未接管控制时隐藏自定义鼠标。
func _ready() -> void:
	file_manager_button.pressed.connect(_open_file_manager)
	chat_button.pressed.connect(_open_chat)
	custom_cursor.hide()


## 接收所属 Computer 的硬盘目录和管理员密码。
func setup(root_path: String, password: String) -> void:
	disk_root = root_path.trim_suffix("/")
	admin_password = password
	story = get_tree().get_first_node_in_group("story") as Story
	assert(story != null, "ComputerOS 找不到跨世界 Story")
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
	if not usb_root.is_empty():
		file_manager.call("mount_usb", usb_root)
	var open_signal: Signal = file_manager.get("file_open_requested")
	if not open_signal.is_connected(_open_file):
		open_signal.connect(_open_file)


## 打开初始安装的聊天软件，并绑定跨世界聊天记录。
func _open_chat() -> void:
	var chat_app: Control = _get_or_create_app("chat", "聊天软件", CHAT_APP_SCENE, Vector2(760.0, 420.0))
	chat_app.call("setup", story)


## 创建软件及通用窗口；同一软件再次打开时复用原窗口。
func _get_or_create_app(app_id: String, title: String, app_scene: PackedScene, window_size: Vector2 = Vector2(450.0, 300.0)) -> Control:
	if apps.has(app_id):
		var existing_window: AppWindowType = windows[app_id] as AppWindowType
		existing_window.open_window(title)
		return apps[app_id] as Control
	var app_window: AppWindowType = APP_WINDOW_SCENE.instantiate() as AppWindowType
	var app: Control = app_scene.instantiate() as Control
	window_layer.add_child(app_window)
	app_window.size = window_size
	var window_index: int = windows.size() % 4
	var next_position: Vector2 = Vector2(
		16.0 + float(window_index % 2) * 478.0,
		12.0 + float(floori(float(window_index) / 2.0)) * 184.0
	)
	next_position.x = minf(next_position.x, window_layer.size.x - window_size.x)
	next_position.y = minf(next_position.y, window_layer.size.y - window_size.y)
	app_window.position = next_position
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

## 挂载 U 盘目录；文件管理器已打开时立即显示 D 盘。
func mount_usb(root_path: String) -> void:
	usb_root = root_path.trim_suffix("/")
	assert(DirAccess.open(usb_root) != null, "U盘目录不存在: %s" % usb_root)
	if apps.has("file_manager"):
		(apps["file_manager"] as Control).call("mount_usb", usb_root)


## 卸载 U 盘，并同步已经打开的文件管理器。
func unmount_usb() -> void:
	usb_root = ""
	if apps.has("file_manager"):
		(apps["file_manager"] as Control).call("unmount_usb")
#endregion
