## 跨世界剧情状态。保存聊天记录，并把玩家选择与世界事件统一转成剧情事件。
class_name Story
extends Node

#region 接口
signal changed
signal event_reported(event_id: StringName, data: Dictionary)
signal message_sent(contact_id: StringName, option_id: StringName)

const LI: StringName = &"li"
const UNKNOWN: StringName = &"unknown"

@export var initialized: bool = false
@export var messages: Dictionary = {}
@export var unread_counts: Dictionary = {}
@export var chat_steps: Dictionary = {}
#endregion

#region 生命周期

## 首次创建存档时填入参考聊天内容，读取存档时保留已有数据。
func _ready() -> void:
	if initialized:
		return
	initialized = true
	messages = {
		LI: [
			{"time": "1:14", "sender": "李哥", "text": "通讯软件左侧联系人可以交互。每个联系人有名字，在线状态对应其UI，鼠标悬停使其蓝底白字，点击后，右侧主页切换为对应人物及其对话历史记录。右侧有滑动条。"},
			{"time": "1:15", "sender": "李哥", "text": "发送栏不应该是打字，而是选项。选项不应该超过2个。"},
			{"time": "17:20", "sender": "李哥", "text": "我美术赶工做完了，你测一下"},
		],
		UNKNOWN: [],
	}
	unread_counts = {LI: 1, UNKNOWN: 0}
	chat_steps = {LI: 0, UNKNOWN: 0}
#endregion

#region 聊天

## 返回固定联系人信息；在线状态以后由剧情事件修改。
func get_contacts() -> Array[Dictionary]:
	return [
		{"id": LI, "name": "李哥", "online": false},
		{"id": UNKNOWN, "name": "???", "online": false},
	]


## 返回联系人的全部聊天记录。
func get_messages(contact_id: StringName) -> Array:
	return messages.get(contact_id, []) as Array


## 返回当前剧情步骤允许发送的零到两个选项。
func get_options(contact_id: StringName) -> Array[Dictionary]:
	if contact_id == LI and int(chat_steps.get(LI, 0)) == 0:
		return [
			{"id": &"tutorial_send", "text": "点击预选项高亮后，点击发送可以发送"},
			{"id": &"tutorial_story", "text": "对话应该对应一个剧情有关的状态机"},
		]
	return []


## 将外部触发的新消息立即写入记录，并增加对应联系人的未读数。
func add_message(contact_id: StringName, sender: String, text: String, time: String = "17:20") -> void:
	var contact_messages: Array = messages.get(contact_id, []) as Array
	contact_messages.append({"time": time, "sender": sender, "text": text})
	messages[contact_id] = contact_messages
	unread_counts[contact_id] = int(unread_counts.get(contact_id, 0)) + 1
	changed.emit()


## 清除指定联系人的未读数量。
func mark_read(contact_id: StringName) -> void:
	if int(unread_counts.get(contact_id, 0)) == 0:
		return
	unread_counts[contact_id] = 0
	changed.emit()


## 立即记录玩家选择、推进聊天步骤，并把选择作为剧情事件发出。
func send_option(contact_id: StringName, option_id: StringName) -> void:
	for option: Dictionary in get_options(contact_id):
		if option.id != option_id:
			continue
		var contact_messages: Array = messages.get(contact_id, []) as Array
		contact_messages.append({"time": "17:20", "sender": "我", "text": option.text})
		messages[contact_id] = contact_messages
		chat_steps[contact_id] = int(chat_steps.get(contact_id, 0)) + 1
		changed.emit()
		message_sent.emit(contact_id, option_id)
		report_event(&"chat_message_sent", {"contact_id": contact_id, "option_id": option_id})
		return
	assert(false, "当前聊天状态不存在选项: %s/%s" % [contact_id, option_id])
#endregion

#region 剧情事件

## 接收世界或软件产生的事件；主线和支线后续统一监听这个接口。
func report_event(event_id: StringName, data: Dictionary = {}) -> void:
	event_reported.emit(event_id, data)
#endregion
