## 当前世界的 HUD。统一管理交互提示、Meta 菜单和玩家背包界面。
extends CanvasLayer

#region 依赖
const InventoryType = preload("res://actor/inventory.gd")

@export var empty_hand_icon: Texture2D
@export_multiline var empty_hand_description: String = "你的手，选择它的时候你可以保持空手。"

@onready var meta_menu: Control = $MetaMenu
@onready var inventory_panel: Control = $InventoryPanel
@onready var slots_actions: Control = $InventoryPanel/SlotsActions
@onready var inspect_page: Control = $InventoryPanel/InspectPage
@onready var slots: Array[Node] = $InventoryPanel/Slots.get_children()

var inventory: InventoryType
var player: CharacterBody3D
var previous_mouse_mode: Input.MouseMode
var hovered_index: int = -1
#endregion

#region 生命周期

## 连接六个格子，并初始化两个互斥菜单。
func _ready() -> void:
	for index: int in slots.size():
		var button: Button = slots[index] as Button
		button.pressed.connect(_on_slot_pressed.bind(index))
		button.mouse_entered.connect(_on_slot_hovered.bind(index, true))
		button.mouse_exited.connect(_on_slot_hovered.bind(index, false))
	$MetaMenu/Menu/Exit.pressed.connect(_on_exit_pressed)
	$MetaMenu/Menu/Settings.pressed.connect(_on_settings_pressed)
	$InventoryPanel/InspectPage/Use.pressed.connect(_on_use_pressed)
	$InventoryPanel/InspectPage/Back.pressed.connect(_show_slots_page)
	meta_menu.hide()
	inventory_panel.hide()
	_refresh_inventory()


## Esc 管理 Meta 菜单，bag 动作只在 Player 受控时管理背包。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		if inventory_panel.visible:
			if inspect_page.visible:
				_show_slots_page()
			else:
				_close_overlay()
		else:
			_toggle_meta_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("bag") and not meta_menu.visible:
		if inventory_panel.visible:
			_close_overlay()
		elif _bind_controlled_player():
			_open_overlay(inventory_panel)
		get_viewport().set_input_as_handled()
#endregion

#region 菜单

## 退出当前游戏进程。
func _on_exit_pressed() -> void:
	var game_root: Node = get_tree().current_scene
	assert(game_root.has_method("quit_game"), "当前主场景缺少 quit_game 接口")
	game_root.call("quit_game")


## 设置入口暂不执行任何效果。
func _on_settings_pressed() -> void:
	pass

## 打开或关闭暂停整个场景树的 Meta 菜单。
func _toggle_meta_menu() -> void:
	if meta_menu.visible:
		_close_overlay()
	else:
		_open_overlay(meta_menu)


## 显示指定覆盖层、暂停世界并释放鼠标。
func _open_overlay(overlay: Control) -> void:
	previous_mouse_mode = Input.mouse_mode
	if overlay == inventory_panel:
		_show_slots_page()
	overlay.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if overlay == meta_menu:
		$MetaMenu/Menu/Exit.grab_focus()


## 隐藏所有覆盖层、恢复世界和进入菜单前的鼠标模式。
func _close_overlay() -> void:
	meta_menu.hide()
	inventory_panel.hide()
	inspect_page.hide()
	get_tree().paused = false
	Input.mouse_mode = previous_mouse_mode


## 在当前 world 中绑定唯一未冻结的 Player；没有时返回 false。
func _bind_controlled_player() -> bool:
	for node: Node in get_tree().get_nodes_in_group("player"):
		if get_parent().is_ancestor_of(node) and node.process_mode != Node.PROCESS_MODE_DISABLED:
			player = node as CharacterBody3D
			var next_inventory: InventoryType = player.get_node("Inventory") as InventoryType
			if inventory != next_inventory:
				if inventory != null and inventory.changed.is_connected(_refresh_inventory):
					inventory.changed.disconnect(_refresh_inventory)
				inventory = next_inventory
				inventory.changed.connect(_refresh_inventory)
			_refresh_inventory()
			return true
	return false
#endregion

#region 背包

## 用背包数据刷新六个格子的名称与选中边框。
func _refresh_inventory() -> void:
	for index: int in slots.size():
		var button: Button = slots[index] as Button
		var item: Node = inventory.items[index] if inventory != null else null
		var icon: Texture2D = empty_hand_icon if index == 0 else _get_item_icon(item)
		button.icon = icon
		button.text = ("空手" if index == 0 else item.get_inventory_name()) if icon == null and (index == 0 or item != null) else ""
		button.button_pressed = inventory != null and index == inventory.selected_index
		var inner_frame: Panel = button.get_node("InnerFrame")
		inner_frame.visible = hovered_index == index or button.button_pressed
		inner_frame.self_modulate = Color.BLACK if button.button_pressed else Color.WHITE


## 首次点击选择格子，再次点击当前格子打开“检视”二级菜单。
func _on_slot_pressed(index: int) -> void:
	if index > 0 and inventory.items[index] == null:
		_refresh_inventory()
		return
	var selected_again: bool = inventory.select(index)
	if selected_again:
		_show_inspect_page()


## 更新悬停格的双层白框。
func _on_slot_hovered(index: int, active: bool) -> void:
	hovered_index = index if active else -1
	_refresh_inventory()


## 返回物品提供的背包图片；未提供时返回 null。
func _get_item_icon(item: Node) -> Texture2D:
	return item.get_inventory_icon() if item != null and item.has_method("get_inventory_icon") else null


## 从检视页返回六格列表。
func _show_slots_page() -> void:
	$InventoryPanel/Slots.show()
	slots_actions.show()
	inspect_page.hide()


## 用当前选中项填充完整检视页。
func _show_inspect_page() -> void:
	var item: Node = inventory.get_selected_item()
	var is_empty_hand: bool = inventory.selected_index == 0
	var icon: Texture2D = empty_hand_icon if is_empty_hand else _get_item_icon(item)
	var fallback: String = "空手" if is_empty_hand else item.get_inventory_name()
	var description: String = empty_hand_description if is_empty_hand else item.get_inventory_description()
	var preview: TextureRect = $InventoryPanel/InspectPage/Preview/Icon
	preview.texture = icon
	$InventoryPanel/InspectPage/Preview/Fallback.text = fallback
	$InventoryPanel/InspectPage/Preview/Fallback.visible = icon == null
	$InventoryPanel/InspectPage/Description.text = description
	$InventoryPanel/Slots.hide()
	slots_actions.hide()
	inspect_page.show()


## 使用当前选择并关闭背包；具体物品效果由世界交互处理。
func _on_use_pressed() -> void:
	_close_overlay()
#endregion
