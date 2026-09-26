## 只读文件管理器。负责 Windows 风格路径显示、文件夹导航和文件打开请求。
extends Control

signal file_open_requested(path: String)

#region 依赖
const SUPPORTED_EXTENSIONS: PackedStringArray = ["txt", "png", "jpg", "jpeg", "webp"]
const FOLDER_ICON: Texture2D = preload("res://interactables/computer/os/art/folder.svg")
const TEXT_ICON: Texture2D = preload("res://interactables/computer/os/art/text.svg")
const IMAGE_ICON: Texture2D = preload("res://interactables/computer/os/art/image.svg")
@onready var back_button: Button = $Toolbar/BackButton
@onready var path_label: Label = $Toolbar/Path
@onready var c_drive_button: Button = $Drives/CDriveButton
@onready var entries: VBoxContainer = $EntriesScroll/Entries
#endregion

#region 文件
var disk_root: String
var current_path: String


## 设置 C 盘真实目录，并打开根目录。
func set_disk_root(path: String) -> void:
	var next_root: String = path.trim_suffix("/")
	if next_root == disk_root and not current_path.is_empty():
		return
	disk_root = next_root
	current_path = disk_root
	_refresh_entries()


## 读取当前真实目录，先显示文件夹，再显示支持的文件。
func _refresh_entries() -> void:
	for child: Node in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	var directory: DirAccess = DirAccess.open(current_path)
	assert(directory != null, "无法打开目录: %s" % current_path)
	var directories: PackedStringArray = directory.get_directories()
	directories.sort()
	for directory_name: String in directories:
		_add_entry(directory_name, current_path.path_join(directory_name), true)
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
	button.pressed.connect(_open_entry.bind(path, is_directory))
	entries.add_child(button)


## 按文件类型返回裁剪自原图的像素图标。
func _get_file_icon(path: String, is_directory: bool) -> Texture2D:
	if is_directory:
		return FOLDER_ICON
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


## 从任意子目录直接返回 C 盘根目录。
func _open_disk_root() -> void:
	current_path = disk_root
	_refresh_entries()


## 返回上一级，但不允许离开当前 C 盘根目录。
func _go_back() -> void:
	if current_path == disk_root:
		return
	current_path = current_path.get_base_dir()
	_refresh_entries()


## 将真实 res 路径转换为用户看到的 Windows C 盘路径。
func _update_path() -> void:
	var relative_path: String = current_path.trim_prefix(disk_root).trim_prefix("/").replace("/", "\\")
	path_label.text = "C:\\" + relative_path
#endregion
