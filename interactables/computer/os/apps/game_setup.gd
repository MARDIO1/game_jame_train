## 固定路径的游戏安装界面；实际安装状态由 Computer 保存。
extends Control

#region 接口
signal install_requested

@onready var action_button: Button = $Action
#endregion

#region 生命周期

## 连接安装按钮。
func _ready() -> void:
	action_button.pressed.connect(_on_action_pressed)
#endregion

#region 安装

## 更新已安装状态和按钮文字。
func set_installed(installed: bool) -> void:
	action_button.text = "已安装" if installed else "安装"
	action_button.disabled = installed


## 未安装时请求安装；已安装时请求启动游戏。
func _on_action_pressed() -> void:
	install_requested.emit()
#endregion
