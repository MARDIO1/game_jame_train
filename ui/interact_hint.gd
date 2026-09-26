## HUD 交互提示。非空文字显示提示，空文字隐藏提示。
class_name InteractHint
extends PanelContainer

#region 节点
@onready var hint_label: Label = $Content/HintLabel
#endregion

#region 生命周期

## 进入场景时隐藏尚无目标的交互提示。
func _ready() -> void:
	hide()
#endregion

#region 提示

## 更新动作文字；空字符串表示当前没有交互目标。
func set_hint(text: String) -> void:
	if text.is_empty():
		hide()
		return
	hint_label.text = text
	show()
#endregion
