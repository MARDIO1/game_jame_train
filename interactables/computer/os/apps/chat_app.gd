## 聊天软件界面。只显示 Story 的数据并提交玩家选择，不判断剧情结果。
extends Control

#region 依赖
const LI: StringName = &"li"
const UNKNOWN: StringName = &"unknown"

@onready var history: TextEdit = $History
@onready var option_buttons: Array[Button] = [$Options/Option0, $Options/Option1]
@onready var send_button: Button = $Send

var story: Story
var current_contact_id: StringName
var selected_option_id: StringName
#endregion

#region 生命周期

## 连接联系人、选项和发送按钮。
func _ready() -> void:
	$Contacts/Li.pressed.connect(_select_contact.bind(LI, true))
	$Contacts/Unknown.pressed.connect(_select_contact.bind(UNKNOWN, true))
	for index: int in option_buttons.size():
		option_buttons[index].pressed.connect(_select_option.bind(index))
	send_button.pressed.connect(_send_selected)


## 绑定跨世界 Story；初始不选联系人，玩家点击后才显示右侧内容。
func setup(next_story: Story) -> void:
	if story != null and story.changed.is_connected(_refresh):
		story.changed.disconnect(_refresh)
	story = next_story
	story.changed.connect(_refresh)
	_refresh()
#endregion

#region 联系人

## 切换联系人；玩家主动点击时清除该联系人的未读数量。
func _select_contact(contact_id: StringName, mark_as_read: bool) -> void:
	current_contact_id = contact_id
	selected_option_id = &""
	if mark_as_read:
		story.mark_read(contact_id)
	_refresh()


## 刷新联系人、记录、选项和发送按钮。
func _refresh() -> void:
	if story == null:
		return
	_refresh_contact($Contacts/Li, LI)
	_refresh_contact($Contacts/Unknown, UNKNOWN)
	var has_contact: bool = not current_contact_id.is_empty()
	$Header.visible = has_contact
	history.visible = has_contact
	$Options.visible = has_contact
	send_button.visible = has_contact
	if not has_contact:
		return
	var contact: Dictionary = story.get_contacts()[0 if current_contact_id == LI else 1]
	$Header/Portrait.texture = $Contacts/Li/Portrait.texture if current_contact_id == LI else $Contacts/Unknown/Portrait.texture
	$Header/Name.text = contact.name
	$Header/Status.text = "○ 离线"
	history.text = _format_history(story.get_messages(current_contact_id))
	_refresh_options(story.get_options(current_contact_id))


## 更新单个联系人按钮的选中配色和未读徽标。
func _refresh_contact(button: Button, contact_id: StringName) -> void:
	var selected: bool = current_contact_id == contact_id
	button.button_pressed = selected
	var font_color: Color = Color.WHITE if selected else Color.BLACK
	(button.get_node("Name") as Label).add_theme_color_override("font_color", font_color)
	(button.get_node("Status") as Label).add_theme_color_override("font_color", font_color)
	var unread: int = int(story.unread_counts.get(contact_id, 0))
	button.get_node("Unread").visible = unread > 0
	button.get_node("Unread/Count").text = str(unread)
#endregion

#region 消息

## 把结构化消息转换成只读聊天记录。
func _format_history(chat_messages: Array) -> String:
	var lines: PackedStringArray = []
	for message: Dictionary in chat_messages:
		lines.append("[%s]%s：%s" % [message.time, message.sender, message.text])
	return "\n".join(lines)


## 选择一个发送选项，并取消另一个选项的高亮。
func _select_option(index: int) -> void:
	var options: Array[Dictionary] = story.get_options(current_contact_id)
	selected_option_id = options[index].id
	for button_index: int in option_buttons.size():
		option_buttons[button_index].button_pressed = button_index == index
	send_button.disabled = false


## 显示最多两个选项；没有选项时保持区域为空。
func _refresh_options(options: Array[Dictionary]) -> void:
	for index: int in option_buttons.size():
		var button: Button = option_buttons[index]
		button.visible = index < options.size()
		button.button_pressed = false
		if button.visible:
			button.text = "%d. %s" % [index + 1, options[index].text]
	selected_option_id = &""
	send_button.disabled = options.is_empty()


## 发送当前选项；Story 会立即写入“我”的消息并发出剧情事件。
func _send_selected() -> void:
	if selected_option_id.is_empty():
		return
	story.send_option(current_contact_id, selected_option_id)
#endregion
