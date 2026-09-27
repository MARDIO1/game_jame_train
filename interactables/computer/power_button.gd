## 电脑实体电源按钮。提示和开关状态均由父级 Computer 决定。
extends Interactable

#region 交互

## 根据电脑当前电源状态显示相反操作。
func get_interact_hint(_interactor: Node3D = null) -> String:
	return "关机" if get_parent().get("is_powered_on") else "开机"


## 播放通用交互声并切换电脑电源。
func interact(interactor: Node3D) -> void:
	super.interact(interactor)
	get_parent().call("toggle_power")
#endregion
