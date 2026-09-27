## 固定路径的游戏安装界面；实际安装状态由 Computer 保存。
extends Control

#region 接口
signal install_requested

@onready var action_button: Button = $Action
@onready var path_field: LineEdit = $Path
@onready var progress_bar: ProgressBar = $Progress

const INSTALL_DURATION_S: float = 3.0

var is_installing: bool = false
#endregion

#region 生命周期

## 连接安装按钮。
func _ready() -> void:
	action_button.pressed.connect(_on_action_pressed)
	set_process(false)


## 安装时推进固定目录位置上的读条，完成后才提交安装事件。
func _process(delta: float) -> void:
	progress_bar.value = minf(progress_bar.value + 100.0 * delta / INSTALL_DURATION_S, 100.0)
	action_button.text = "%d%%" % roundi(progress_bar.value)
	if progress_bar.value >= 100.0:
		is_installing = false
		set_process(false)
		install_requested.emit()
#endregion

#region 安装

## 更新已安装状态和按钮文字。
func set_installed(installed: bool) -> void:
	if is_installing and not installed:
		return
	is_installing = false
	set_process(false)
	path_field.visible = not installed
	progress_bar.visible = installed
	progress_bar.value = 100.0 if installed else 0.0
	action_button.text = "已安装" if installed else "安装"
	action_button.disabled = installed


## 未安装时请求安装；已安装时请求启动游戏。
func _on_action_pressed() -> void:
	if is_installing:
		return
	is_installing = true
	path_field.hide()
	progress_bar.value = 0.0
	progress_bar.show()
	action_button.text = "0%"
	action_button.disabled = true
	set_process(true)
#endregion
