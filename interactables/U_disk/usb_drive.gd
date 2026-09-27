## 可拾取和插入电脑的 U 盘实体。
class_name UsbDrive
extends Node3D

#region 状态
@export var inventory_name: String = "U盘"
@export_multiline var inventory_description: String = "舍友给了的U盘，看上去很有年代感。\n插入电脑应该可以拷贝一个游戏。"
@export var inventory_icon: Texture2D
@export_dir var disk_root: String = "res://interactables/computer/computer_content/usb_01"
@export var in_inventory: bool = false
@export var inserted: bool = false

@onready var interactable: Interactable = $Interactable
@onready var visual: Node3D = $Visual
#endregion

#region 生命周期

## 连接通用交互，并恢复场景中保存的携带状态。
func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	_set_world_enabled(not in_inventory)
#endregion

#region 背包接口

## 返回背包格显示的短名称。
func get_inventory_name() -> String:
	return inventory_name


## 返回背包格和检视页使用的图片。
func get_inventory_icon() -> Texture2D:
	return inventory_icon


## 返回检视页中的物品说明。
func get_inventory_description() -> String:
	return inventory_description


## E 拾取地面 U 盘；插入状态下 E 将它拔回当前玩家背包。
func _on_interacted(interactor: Node3D) -> void:
	var inventory: Inventory = interactor.get_node("Inventory") as Inventory
	if not inventory.add_item(self):
		return
	in_inventory = true
	inserted = false
	_set_world_enabled(false)


## 从背包移除并把 U 盘显示在电脑插槽位置。
func insert_at(port: Node3D, inventory: Inventory) -> void:
	if not inventory.remove_item(self):
		return
	in_inventory = false
	inserted = true
	global_transform = port.global_transform
	interactable.interact_hint = "拔出U盘"
	_set_world_enabled(true)


## 同时开关模型与射线交互碰撞。
func _set_world_enabled(active: bool) -> void:
	visual.visible = active
	interactable.monitorable = active
	$Interactable/CollisionShape3D.set_deferred("disabled", not active)
#endregion
