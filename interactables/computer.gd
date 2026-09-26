## 电脑交互物。具体的打开界面、动画和音效从交互回调继续实现。
extends Node3D

#region 依赖
const InteractableType = preload("res://interactables/interactable.gd")

@onready var interactable: InteractableType = $Interactable
#endregion

#region 生命周期

## 连接电脑内部的通用交互组件。
func _ready() -> void:
	interactable.interacted.connect(_on_interactable_interacted)
#endregion

#region 交互

## 接收通用交互组件的信号，预留电脑效果入口。
func _on_interactable_interacted(_interactor: Node3D) -> void:
	pass
#endregion
