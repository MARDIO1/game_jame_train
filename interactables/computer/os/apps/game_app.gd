## 已安装游戏的入口界面；世界切换由外部接收请求后实现。
extends Control

#region 接口
signal launch_requested
#endregion

#region 生命周期

## 连接游戏启动按钮。
func _ready() -> void:
	$Launch.pressed.connect(func() -> void: launch_requested.emit())
#endregion
