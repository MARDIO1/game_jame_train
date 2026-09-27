## 电脑 U 盘插槽。只接受当前玩家背包中选中的 U 盘。
extends Interactable

#region 节点
@onready var computer_os: Control = $"../ComputerLayer/ComputerView/SubViewport/ComputerOS"
#endregion

#region 交互

## 仅当玩家已选中 U 盘时返回插入提示。
func get_interact_hint(interactor: Node3D = null) -> String:
	if interactor == null:
		return ""
	var inventory: Inventory = interactor.get_node("Inventory") as Inventory
	return "插入U盘" if inventory.get_selected_item() is UsbDrive else ""


## 把当前选中的 U 盘移动到此插槽。
func interact(interactor: Node3D) -> void:
	var inventory: Inventory = interactor.get_node("Inventory") as Inventory
	var usb_drive: UsbDrive = inventory.get_selected_item() as UsbDrive
	if usb_drive == null:
		return
	super.interact(interactor)
	usb_drive.insert_at(self, inventory)
	computer_os.call("mount_usb", usb_drive.disk_root)
	if not usb_drive.interactable.interacted.is_connected(_on_usb_removed):
		usb_drive.interactable.interacted.connect(_on_usb_removed, CONNECT_ONE_SHOT)


## U 盘被拔回背包后卸载电脑中的 D 盘。
func _on_usb_removed(_interactor: Node3D) -> void:
	computer_os.call("unmount_usb")
#endregion
