## 只读文件管理器。负责 Windows 风格路径显示、文件夹导航和文件打开请求。
extends Control

signal file_open_requested(path: String)

#region 依赖
const SUPPORTED_EXTENSIONS: PackedStringArray = ["txt", "png", "jpg", "jpeg", "webp", "exe"]
const FOLDER_ICON: Texture2D = preload("res://interactables/computer/os/art/folder.svg")
const TEXT_ICON: Texture2D = preload("res://interactables/computer/os/art/text.svg")
const IMAGE_ICON: Texture2D = preload("res://interactables/computer/os/art/image.svg")
const SETUP_ICON: Texture2D = preload("res://interactables/computer/os/art/setup.svg")
const GAME_ICON: Texture2D = preload("res://interactables/computer/os/art/game.svg")
const GAME_EXECUTABLE_NAME: String = "Game jam游戏day3v2.0测试版3.exe"
@onready var back_button: Button = $Toolbar/BackButton
@onready var path_label: Label = $Toolbar/Path
@onready var c_drive_button: Button = $Drives/CDriveButton
@onready var d_drive_button: Button = $Drives/DDriveButton
@onready var entries: VBoxContainer = $EntriesScroll/Entries
@onready var hover_name: Label = $HoverName
#endregion

#region 文件
var disk_root: String
var usb_root: String
var current_path: String
var hidden_paths: PackedStringArray


## 设置 C 盘真实目录，并打开根目录。
func set_disk_root(path: String) -> void:
	var next_root: String = path.trim_suffix("/")
	if next_root == disk_root and not current_path.is_empty():
		return
	disk_root = next_root
	current_path = disk_root
	_refresh_entries()


## 从桌面图标直接打开 C 盘内的指定文件夹。
func open_directory(path: String) -> void:
	assert(path == disk_root or path.begins_with(disk_root + "/"), "文件夹不属于当前电脑硬盘: %s" % path)
	current_path = path
	_refresh_entries()


## 由 OS 隐藏尚未安装的软件目录；路径重新可见时立即刷新列表。
func set_hidden_paths(paths: PackedStringArray) -> void:
	hidden_paths = paths
	for hidden_path: String in hidden_paths:
		if current_path == hidden_path or current_path.begins_with(hidden_path + "/"):
			current_path = disk_root
			break
	if not current_path.is_empty():
		_refresh_entries()


## 显示 D 盘并记录当前 U 盘真实目录。
func mount_usb(path: String) -> void:
	usb_root = path.trim_suffix("/")
	d_drive_button.show()
	d_drive_button.disabled = false


## 隐藏 D 盘；正在浏览 U 盘时先返回 C 盘。
func unmount_usb() -> void:
	if not usb_root.is_empty() and current_path.begins_with(usb_root):
		_open_disk_root()
	usb_root = ""
	d_drive_button.hide()
	d_drive_button.disabled = true


## 读取当前真实目录，先显示文件夹，再显示支持的文件。
func _refresh_entries() -> void:
	hover_name.hide()
	for child: Node in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	var directory: DirAccess = DirAccess.open(current_path)
	assert(directory != null, "无法打开目录: %s" % current_path)
	var directories: PackedStringArray = directory.get_directories()
	directories.sort()
	for directory_name: String in directories:
		var directory_path: String = current_path.path_join(directory_name)
		if directory_path not in hidden_paths:
			_add_entry(directory_name, directory_path, true)
	var files: PackedStringArray = directory.get_files()
	files.sort()
	for file_name: String in files:
		if file_name.get_extension().to_lower() in SUPPORTED_EXTENSIONS:
			_add_entry(file_name, current_path.path_join(file_name), false)
	_update_path()


## 创建一个单击即可打开的文件或文件夹按钮。
func _add_entry(text: String, path: String, is_directory: bool) -> void:
	var button: Button = Button.new()
	button.text = text
	button.icon = _get_file_icon(path, is_directory)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 64.0
	button.theme_type_variation = &"FileEntryButton"
	button.add_theme_font_size_override("font_size", 24)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.mouse_entered.connect(_show_hover_name.bind(button, text))
	button.mouse_exited.connect(hover_name.hide)
	button.pressed.connect(_open_entry.bind(path, is_directory))
	entries.add_child(button)


## 长文件名平时省略；悬停时在列表上方向右展开完整名称。
func _show_hover_name(button: Button, full_name: String) -> void:
	var text_width: float = button.get_theme_font("font").get_string_size(full_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	if text_width <= button.size.x - 72.0:
		return
	hover_name.text = full_name
	hover_name.position = Vector2($EntriesScroll.position.x + 64.0, button.global_position.y - global_position.y)
	hover_name.size = Vector2(text_width + 16.0, button.size.y)
	hover_name.show()


## 按文件类型返回裁剪自原图的像素图标。
func _get_file_icon(path: String, is_directory: bool) -> Texture2D:
	if is_directory:
		return FOLDER_ICON
	if path.get_extension().to_lower() == "exe":
		return GAME_ICON if path.get_file() == GAME_EXECUTABLE_NAME else SETUP_ICON
	if path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
		return IMAGE_ICON
	return TEXT_ICON


## 进入文件夹，或把文件路径交给 ComputerOS 选择查看器。
func _open_entry(path: String, is_directory: bool) -> void:
	if is_directory:
		current_path = path
		_refresh_entries()
	else:
		file_open_requested.emit(path)
#endregion

#region 导航

## 连接返回按钮；真实磁盘目录由 ComputerOS 随后注入。
func _ready() -> void:
	back_button.pressed.connect(_go_back)
	c_drive_button.pressed.connect(_open_disk_root)
	d_drive_button.pressed.connect(_open_usb_root)


## 从任意子目录直接返回 C 盘根目录。
func _open_disk_root() -> void:
	current_path = disk_root
	_refresh_entries()


## 打开当前插入 U 盘的根目录。
func _open_usb_root() -> void:
	current_path = usb_root
	_refresh_entries()


## 返回上一级，但不允许离开当前 C 盘根目录。
func _go_back() -> void:
	var current_root: String = usb_root if not usb_root.is_empty() and current_path.begins_with(usb_root) else disk_root
	if current_path == current_root:
		return
	current_path = current_path.get_base_dir()
	_refresh_entries()


## 将真实 res 路径转换为用户看到的 Windows C 盘路径。
func _update_path() -> void:
	var on_usb: bool = not usb_root.is_empty() and current_path.begins_with(usb_root)
	var current_root: String = usb_root if on_usb else disk_root
	var relative_path: String = current_path.trim_prefix(current_root).trim_prefix("/").replace("/", "\\")
	path_label.text = ("D:\\" if on_usb else "C:\\") + relative_path
#endregion
