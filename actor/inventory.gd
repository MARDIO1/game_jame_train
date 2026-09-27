## 玩家持有的六格背包数据，不负责绘制界面。
class_name Inventory
extends Node

#region 数据
const SLOT_COUNT: int = 6

signal changed

@export var items: Array[Node] = []
@export_range(0, SLOT_COUNT - 1) var selected_index: int = 0
#endregion

#region 生命周期

## 保证存档与新场景中的背包始终为固定六格。
func _ready() -> void:
	items.resize(SLOT_COUNT)
#endregion

#region 物品

## 第 0 格固定表示空手；物品放入后五格中的第一个空格。
func add_item(item: Node) -> bool:
	for index: int in range(1, SLOT_COUNT):
		if items[index] == null:
			items[index] = item
			changed.emit()
			return true
	return false


## 从背包移除指定物品；找到并移除时返回 true。
func remove_item(item: Node) -> bool:
	var index: int = items.find(item)
	if index < 0:
		return false
	items[index] = null
	if selected_index == index:
		selected_index = 0
	changed.emit()
	return true


## 返回当前选中格中的物品，空格返回 null。
func get_selected_item() -> Node:
	return items[selected_index]


## 修改当前选中格；再次选择同一格时返回 true。
func select(index: int) -> bool:
	var selected_again: bool = selected_index == index
	selected_index = index
	changed.emit()
	return selected_again
#endregion
