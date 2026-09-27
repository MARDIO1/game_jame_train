## 可交互台灯。E 键在开灯和关灯之间切换。
extends Node3D

#region 节点
@export var is_on: bool = true

@onready var interactable: Interactable = $Interactable
@onready var light: SpotLight3D = $Visual/SpotLight3D
#endregion

#region 生命周期

## 连接通用交互信号并应用 Inspector 中的初始开关状态。
func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	_apply_state()
#endregion

#region 开关

## 接收 E 键交互并切换台灯状态。
func _on_interacted(_interactor: Node3D) -> void:
	is_on = not is_on
	_apply_state()


## 同步光源可见性和下一次交互提示。
func _apply_state() -> void:
	light.visible = is_on
	interactable.interact_hint = "关闭台灯" if is_on else "打开台灯"
#endregion
