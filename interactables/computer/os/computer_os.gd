## 电脑内部系统。负责桌面、鼠标、窗口和文件后缀关联。
extends Control

#region 依赖
const AppWindowType = preload("res://interactables/computer/os/app_window.gd")
const APP_WINDOW_SCENE: PackedScene = preload("res://interactables/computer/os/app_window.tscn")
const FILE_MANAGER_SCENE: PackedScene = preload("res://interactables/computer/os/apps/file_manager.tscn")
const TEXT_VIEWER_SCENE: PackedScene = preload("res://interactables/computer/os/apps/text_viewer.tscn")
const IMAGE_VIEWER_SCENE: PackedScene = preload("res://interactables/computer/os/apps/image_viewer.tscn")
const CHAT_APP_SCENE: PackedScene = preload("res://interactables/computer/os/apps/chat_app.tscn")
const GAME_SETUP_SCENE: PackedScene = preload("res://interactables/computer/os/apps/game_setup.tscn")
const GAME_APP_SCENE: PackedScene = preload("res://interactables/computer/os/apps/game_app.tscn")
const FOLDER_ICON: Texture2D = preload("res://interactables/computer/os/art/folder.svg")
const TEXT_ICON: Texture2D = preload("res://interactables/computer/os/art/text.svg")
const IMAGE_ICON: Texture2D = preload("res://interactables/computer/os/art/image.svg")
const INSTALLER_NAME: String = "Game jam游戏day3v2.0测试版3安装器.exe"
const GAME_DIRECTORY: String = "Games/Game jam游戏day3v2.0测试版3"
const GAME_EXECUTABLE: String = GAME_DIRECTORY + "/Game jam游戏day3v2.0测试版3.exe"
const DESKTOP_EXTENSIONS: PackedStringArray = ["txt", "png", "jpg", "jpeg", "webp"]
const BOOT_TEXT: String = """BIOS v1.04

正在启动...

[0.000000]核心:正在启动系统
[0.012843]内存:检测到 16384MB
[0.031552]CPU:初始化处理器
[0.084231]PCI:扫描硬件设备
[0.126742]存储:检测到 SATA SSD

[0.243891]加载核心模块
[0.354221]初始化设备管理器
[0.498312]初始化随机数生成器
[0.621883]挂载根文件系统 /

[OK]文件系统检查完成
[OK]设备管理服务启动
[OK]网络服务启动
[OK]时间同步服务启动
[OK]用户管理服务启动

正在启动用户空间...

[OK]加载系统配置
[OK]加载用户数据
[OK]加载窗口管理器
[OK]加载图形界面

玩家是否加载完毕?[Y/N]"""
const BOOT_QUESTION: String = "玩家是否加载完毕?[Y/N]"
const BOOT_DURATION_S: float = 6.0

signal game_installed
signal game_launch_requested
signal power_off_requested
signal boot_finished

@onready var file_manager_button: Button = $Desktop/FileManagerButton
@onready var chat_button: Button = $Desktop/ChatButton
@onready var game_button: Button = $Desktop/GameButton
@onready var desktop_files: GridContainer = $Desktop/DesktopFilesScroll/DesktopFiles
@onready var window_layer: Control = $WindowLayer
@onready var taskbar: Panel = $Taskbar
@onready var start_button: Button = $Taskbar/StartButton
@onready var start_menu: Panel = $StartMenu
@onready var boot_screen: ColorRect = $BootScreen
@onready var boot_text: RichTextLabel = $BootScreen/Text
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
var is_game_installed: bool = false
var is_powered_on: bool = false
var is_booting: bool = false
var is_waiting_for_boot_input: bool = false
var typing_target: String
var typed_character_count: int = 0
var typing_interval_s: float = 0.02
var typing_elapsed_s: float = 0.0
var finish_after_typing: bool = false
var desktop_pause_remaining_s: float = 0.0
#endregion

#region 生命周期

## 连接桌面入口，并在电脑未接管控制时隐藏自定义鼠标。
func _ready() -> void:
	file_manager_button.pressed.connect(_open_file_manager)
	chat_button.pressed.connect(_open_chat)
	game_button.pressed.connect(_open_game)
	start_button.pressed.connect(_toggle_start_menu)
	$StartMenu/Shutdown.pressed.connect(power_off_requested.emit)
	custom_cursor.hide()
	start_menu.hide()


## 接收所属 Computer 的硬盘目录和管理员密码。
func setup(root_path: String, password: String, installed: bool, powered_on: bool) -> void:
	disk_root = root_path.trim_suffix("/")
	admin_password = password
	is_game_installed = installed
	game_button.visible = installed
	story = get_tree().get_first_node_in_group("story") as Story
	assert(story != null, "ComputerOS 找不到跨世界 Story")
	assert(DirAccess.open(disk_root) != null, "Computer 硬盘目录不存在: %s" % disk_root)
	if powered_on:
		_show_desktop(false)
	else:
		_show_powered_off()


## 在场景未暂停时推进启动文字；RichTextLabel 自动滚动到最新一行。
func _process(delta: float) -> void:
	if not is_booting or is_waiting_for_boot_input:
		return
	if desktop_pause_remaining_s > 0.0:
		desktop_pause_remaining_s -= delta
		if desktop_pause_remaining_s <= 0.0:
			_show_desktop(true)
		return
	typing_elapsed_s += delta
	while typing_elapsed_s >= typing_interval_s and typed_character_count < typing_target.length():
		typing_elapsed_s -= typing_interval_s
		typed_character_count += 1
		boot_text.text = typing_target.left(typed_character_count)
	if typed_character_count == typing_target.length():
		if finish_after_typing:
			finish_after_typing = false
			desktop_pause_remaining_s = 1.0
		else:
			is_waiting_for_boot_input = true


## 启动确认阶段把 N 与其他键分流；Esc 始终留给 World HUD。
func _input(event: InputEvent) -> void:
	if start_menu.visible and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var hovered: Control = get_viewport().gui_get_hovered_control()
		if hovered != start_button and (hovered == null or not start_menu.is_ancestor_of(hovered)):
			start_menu.hide()
	if not is_active or not is_waiting_for_boot_input or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE or event.is_action_pressed("escape"):
		return
	get_viewport().set_input_as_handled()
	if key_event.keycode == KEY_N or key_event.physical_keycode == KEY_N:
		_append_boot_text("\nN\n\n" + BOOT_QUESTION, false)
	else:
		_append_boot_text("\nY\n\nfakeos启动。", true)
#endregion

#region 控制

## 开关电脑内部输入和自定义鼠标显示。
func set_active(active: bool) -> void:
	is_active = active
	custom_cursor.visible = false


## 只在鼠标位于电脑屏幕内时显示虚拟指针。
func set_cursor(cursor_position: Vector2, inside_screen: bool) -> void:
	custom_cursor.position = cursor_position
	custom_cursor.visible = is_active and is_powered_on and not is_booting and inside_screen
#endregion

#region 电源

## 从纯黑屏开始完整启动；每次开机都重新播放文字。
func boot() -> void:
	is_powered_on = true
	is_booting = true
	is_waiting_for_boot_input = false
	finish_after_typing = false
	typing_target = BOOT_TEXT
	typed_character_count = 0
	typing_elapsed_s = 0.0
	desktop_pause_remaining_s = 0.0
	typing_interval_s = BOOT_DURATION_S / float(typing_target.length())
	boot_text.text = ""
	boot_screen.show()
	start_menu.hide()
	custom_cursor.hide()


## 关机时关闭所有软件窗口并保留一块持续渲染的黑屏。
func shutdown() -> void:
	is_powered_on = false
	is_booting = false
	is_waiting_for_boot_input = false
	desktop_pause_remaining_s = 0.0
	for app_window: Control in windows.values():
		app_window.queue_free()
	windows.clear()
	apps.clear()
	_show_powered_off()


## 当前是否处于禁止存档的启动过程。
func is_busy() -> bool:
	return is_booting


## 在已有启动输出后继续逐字打印一段文字。
func _append_boot_text(text: String, finish: bool) -> void:
	typing_target += text
	is_waiting_for_boot_input = false
	finish_after_typing = finish
	typing_interval_s = 0.018


## 显示桌面；真正完成启动时通知 Computer 播放两秒启动音。
func _show_desktop(play_sound: bool) -> void:
	is_powered_on = true
	is_booting = false
	is_waiting_for_boot_input = false
	_refresh_desktop_files()
	boot_screen.hide()
	if play_sound:
		boot_finished.emit()


## 黑屏仍由 SubViewport 持续渲染，实体屏幕不会更换纹理或变形。
func _show_powered_off() -> void:
	boot_text.text = ""
	boot_screen.show()
	start_menu.hide()
	custom_cursor.hide()


## 开始按钮显示或收起简单关机菜单。
func _toggle_start_menu() -> void:
	start_menu.visible = not start_menu.visible
	if start_menu.visible:
		start_menu.move_to_front()
#endregion

#region 桌面文件

## 从真实 C:\Desktop 读取文件夹和支持的文件，无需在场景中逐个添加节点。
func _refresh_desktop_files() -> void:
	for child: Node in desktop_files.get_children():
		desktop_files.remove_child(child)
		child.queue_free()
	var desktop_path: String = disk_root.path_join("Desktop")
	var directory: DirAccess = DirAccess.open(desktop_path)
	assert(directory != null, "电脑桌面目录不存在: %s" % desktop_path)
	var directories: PackedStringArray = directory.get_directories()
	directories.sort()
	for directory_name: String in directories:
		_add_desktop_entry(directory_name, desktop_path.path_join(directory_name), true)
	var files: PackedStringArray = directory.get_files()
	files.sort()
	for file_name: String in files:
		if file_name.get_extension().to_lower() in DESKTOP_EXTENSIONS:
			_add_desktop_entry(file_name, desktop_path.path_join(file_name), false)


## 创建桌面文件按钮；过长名称省略，悬停时由提示显示完整名称。
func _add_desktop_entry(file_name: String, path: String, is_directory: bool) -> void:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(176.0, 64.0)
	button.theme_type_variation = &"FileEntryButton"
	button.add_theme_font_size_override("font_size", 20)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon = FOLDER_ICON if is_directory else _get_desktop_file_icon(path)
	button.text = file_name
	button.tooltip_text = file_name
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(_open_desktop_entry.bind(path, is_directory))
	desktop_files.add_child(button)


## 桌面文件夹进入文件管理器，普通文件交给现有后缀关联。
func _open_desktop_entry(path: String, is_directory: bool) -> void:
	if is_directory:
		_open_file_manager()
		(apps["file_manager"] as Control).call("open_directory", path)
	else:
		_open_file(path)


## 返回桌面文件使用的现有像素图标。
func _get_desktop_file_icon(path: String) -> Texture2D:
	return IMAGE_ICON if path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"] else TEXT_ICON
#endregion

#region 软件

## 打开或重新显示唯一的文件管理器窗口。
func _open_file_manager() -> void:
	var file_manager: Control = _get_or_create_app("file_manager", "文件管理器", FILE_MANAGER_SCENE)
	var hidden_paths: PackedStringArray = PackedStringArray()
	if not is_game_installed:
		hidden_paths.append(disk_root.path_join("Games"))
	file_manager.call("set_hidden_paths", hidden_paths)
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


## 打开已经安装的游戏入口，并把启动请求转发给世界控制层。
func _open_game() -> void:
	assert(is_game_installed)
	var game_app: Control = _get_or_create_app("game", "Game jam游戏", GAME_APP_SCENE)
	var launch_signal: Signal = game_app.get("launch_requested")
	if not launch_signal.is_connected(_request_game_launch):
		launch_signal.connect(_request_game_launch)


## 安装器只记录安装状态，随后显示游戏桌面图标。
func _install_game() -> void:
	if is_game_installed:
		return
	is_game_installed = true
	game_button.show()
	(apps["game_setup"] as Control).call("set_installed", true)
	if apps.has("file_manager"):
		(apps["file_manager"] as Control).call("set_hidden_paths", PackedStringArray())
	game_installed.emit()


## 把游戏启动请求作为接口发给所属 Computer。
func _request_game_launch() -> void:
	game_launch_requested.emit()


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
	if extension == "exe" and is_game_installed and path == disk_root.path_join(GAME_EXECUTABLE):
		_open_game()
		return
	if extension == "exe" and not usb_root.is_empty() and path == usb_root.path_join(INSTALLER_NAME):
		var installer: Control = _get_or_create_app("game_setup", "软件安装", GAME_SETUP_SCENE, Vector2(600.0, 340.0))
		installer.call("set_installed", is_game_installed)
		var install_signal: Signal = installer.get("install_requested")
		if not install_signal.is_connected(_install_game):
			install_signal.connect(_install_game)
		return
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
