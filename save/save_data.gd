## 唯一存档的全局数据。各世界的具体状态分别保存在对应 TSCN 中。
class_name SaveData
extends Resource

@export var current_world_number: int = 1
@export var current_controller_path: NodePath
@export var previous_controller_path: NodePath
