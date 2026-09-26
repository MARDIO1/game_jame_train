## 游戏根控制器。负责世界保存与切换，以及当前 Controller 的切换。
extends Node3D

#region 依赖
const SaveDataType = preload("res://save/save_data.gd")
const SAVE_DIRECTORY: String = "user://save"
const SAVE_DATA_PATH: String = "user://save/save.tres"
const WORLD_SAVE_PATH: String = "user://save/world_%d.tscn"
const WORLD_SOURCE_PATH: String = "res://map/world_%d.tscn"

@export var current_world_number: int = 1
@export var current_world: Node3D
@export var current_controller: Node
@export var previous_controller: Node
@export_range(0.0, 5.0, 0.1, "suffix:s") var transition_duration_s: float = 0.6

var is_transitioning: bool = false
#endregion

#region 生命周期

## 初始化当前世界中的 Controller 及其摄像机。
func _ready() -> void:
	_initialize_controllers()


## 使用 E 返回上一个 Controller；普通玩家状态下的 E 仍用于交互。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and previous_controller != null and not is_transitioning:
		get_viewport().set_input_as_handled()
		_return_to_previous_controller()
#endregion

#region Controller

## 连接当前世界内所有 Controller，并只启用当前 Controller。
func _initialize_controllers() -> void:
	assert(current_world != null, "Root 需要 current_world")
	assert(current_controller != null, "Root 需要 current_controller")
	for controller: Node in get_tree().get_nodes_in_group("controller"):
		if not current_world.is_ancestor_of(controller):
			continue
		var camera: Camera3D = _get_control_camera(controller)
		camera.current = controller == current_controller
		controller.set_controlled(controller == current_controller)
		if controller.has_signal("control_requested") and not controller.control_requested.is_connected(_on_control_requested):
			controller.control_requested.connect(_on_control_requested)


## 返回 Controller 导出的控制摄像机。
func _get_control_camera(controller: Node) -> Camera3D:
	var camera: Camera3D = controller.get("control_camera") as Camera3D
	assert(camera != null, "%s 缺少 control_camera" % controller.name)
	return camera


## 接收任意 Controller 发出的控制请求。
func _on_control_requested(controller: Node) -> void:
	if controller != current_controller and not is_transitioning:
		previous_controller = current_controller
		await switch_controller(controller)


## 当前相机先移动到目标相机位置，再交接镜头与输入。
func switch_controller(next_controller: Node) -> void:
	is_transitioning = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var source_camera: Camera3D = _get_control_camera(current_controller)
	var target_camera: Camera3D = _get_control_camera(next_controller)
	var source_transform: Transform3D = source_camera.global_transform
	var source_fov_deg: float = source_camera.fov
	var target_transform: Transform3D = target_camera.global_transform
	var target_fov_deg: float = target_camera.fov
	current_controller.set_controlled(false)
	next_controller.set_controlled(false)
	var tween: Tween = create_tween()
	tween.set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(source_camera, "global_transform", target_transform, transition_duration_s)
	tween.tween_property(source_camera, "fov", target_fov_deg, transition_duration_s)
	await tween.finished
	target_camera.reset_physics_interpolation()
	source_camera.current = false
	target_camera.current = true
	source_camera.global_transform = source_transform
	source_camera.fov = source_fov_deg
	source_camera.reset_physics_interpolation()
	current_controller = next_controller
	current_controller.set_controlled(true)
	is_transitioning = false


## 返回进入当前 Controller 前使用的 Controller。
func _return_to_previous_controller() -> void:
	var next_controller: Node = previous_controller
	previous_controller = null
	await switch_controller(next_controller)
#endregion

#region 世界

## 将当前世界和 Root 的全局状态写入唯一存档。
func save_game() -> Error:
	if is_transitioning:
		return ERR_BUSY
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))
	if directory_error != OK:
		return directory_error
	var world_error: Error = _save_current_world()
	if world_error != OK:
		return world_error
	var save_data: SaveDataType = SaveDataType.new()
	save_data.current_world_number = current_world_number
	save_data.current_controller_path = current_world.get_path_to(current_controller)
	if previous_controller != null and current_world.is_ancestor_of(previous_controller):
		save_data.previous_controller_path = current_world.get_path_to(previous_controller)
	return ResourceSaver.save(save_data, SAVE_DATA_PATH)


## 从唯一存档恢复当前世界及 Controller 引用。
func load_game() -> Error:
	if is_transitioning:
		return ERR_BUSY
	if not ResourceLoader.exists(SAVE_DATA_PATH):
		return ERR_FILE_NOT_FOUND
	var save_data: SaveDataType = ResourceLoader.load(SAVE_DATA_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as SaveDataType
	return _replace_world(save_data.current_world_number, save_data.current_controller_path, save_data.previous_controller_path)


## 保存旧世界并切换到指定世界入口 Controller。
func switch_world(world_number: int, controller_path: NodePath) -> Error:
	if is_transitioning:
		return ERR_BUSY
	var save_error: Error = _save_current_world()
	if save_error != OK:
		return save_error
	return _replace_world(world_number, controller_path, NodePath())


## 将当前世界场景写入用户存档目录。
func _save_current_world() -> Error:
	var packed_world: PackedScene = PackedScene.new()
	var pack_error: Error = packed_world.pack(current_world)
	if pack_error != OK:
		return pack_error
	return ResourceSaver.save(packed_world, WORLD_SAVE_PATH % current_world_number)


## 用存档世界或项目原始世界替换当前世界。
func _replace_world(world_number: int, controller_path: NodePath, previous_path: NodePath) -> Error:
	var save_path: String = WORLD_SAVE_PATH % world_number
	var source_path: String = WORLD_SOURCE_PATH % world_number
	var world_path: String = save_path if ResourceLoader.exists(save_path) else source_path
	if not ResourceLoader.exists(world_path):
		return ERR_FILE_NOT_FOUND
	var packed_world: PackedScene = ResourceLoader.load(world_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	var next_world: Node3D = packed_world.instantiate() as Node3D
	remove_child(current_world)
	current_world.queue_free()
	add_child(next_world)
	current_world = next_world
	current_world_number = world_number
	current_controller = current_world.get_node(controller_path)
	previous_controller = current_world.get_node_or_null(previous_path) if not previous_path.is_empty() else null
	_initialize_controllers()
	return OK
#endregion
