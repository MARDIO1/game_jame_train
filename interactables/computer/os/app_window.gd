## 所有电脑软件共用的简单窗口。负责标题、关闭、置顶和拖动。
extends Panel

#region 依赖
@onready var title_bar: ColorRect = $TitleBar
@onready var title_label: Label = $TitleBar/Title
@onready var close_button: Button = $TitleBar/CloseButton
@onready var minimize_button: Button = $TitleBar/MinimizeButton
@onready var maximize_button: Button = $TitleBar/MaximizeButton
@onready var content: Control = $Content
#endregion

#region 状态
var is_dragging: bool = false
var is_maximized: bool = false
var drag_offset: Vector2
var restore_position: Vector2
var restore_size: Vector2
#endregion

#region 生命周期

## 连接窗口按钮；拖动由窗口级输入持续处理。
func _ready() -> void:
	close_button.pressed.connect(hide)
	minimize_button.pressed.connect(hide)
	maximize_button.pressed.connect(_toggle_maximize)


## 从标题栏起拖；鼠标在电脑画面外松开后，返回时结束拖动。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_viewport().gui_get_hovered_control() == title_bar and not is_maximized:
			is_dragging = true
			drag_offset = event.position - position
			move_to_front()
		elif not event.pressed:
			is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			is_dragging = false
			return
		_move_window(event.position - drag_offset)
#endregion

#region 窗口

## 将软件界面填充到窗口内容区域。
func set_content(app: Control) -> void:
	content.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 显示窗口、更新标题并放到其他窗口前面。
func open_window(title: String) -> void:
	title_label.text = title
	show()
	move_to_front()


## 只更新当前窗口标题。
func set_title(title: String) -> void:
	title_label.text = title


## 在普通尺寸与填满桌面的状态间切换。
func _toggle_maximize() -> void:
	if is_maximized:
		position = restore_position
		size = restore_size
		is_maximized = false
		return
	restore_position = position
	restore_size = size
	position = Vector2.ZERO
	size = (get_parent() as Control).size
	is_maximized = true


## 移动窗口，并限制在桌面可见范围内。
func _move_window(next_position: Vector2) -> void:
	var desktop_size: Vector2 = (get_parent() as Control).size
	next_position.x = clampf(next_position.x, 0.0, maxf(0.0, desktop_size.x - size.x))
	next_position.y = clampf(next_position.y, 0.0, maxf(0.0, desktop_size.y - size.y))
	position = next_position
#endregion
