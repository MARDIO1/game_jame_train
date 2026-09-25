## 通用交互组件。提供提示文字、交互信号和共享白色轮廓。
class_name Interactable
extends Area3D

signal interacted(interactor: Node3D)

const OUTLINE_SHADER: Shader = preload("res://interactables/outline.gdshader")

@export var interact_hint: String = "交互"
@export var highlight_root: Node3D
@export_range(0.001, 0.1, 0.001, "suffix:m") var outline_width_m: float = 0.005

var outline_material: ShaderMaterial = ShaderMaterial.new()
var highlight_meshes: Array[GeometryInstance3D] = []


## 初始化共享描边材质，并收集模型根节点下的所有网格。
func _ready() -> void:
	assert(highlight_root != null, "Interactable 需要指定 highlight_root")
	outline_material.shader = OUTLINE_SHADER
	outline_material.set_shader_parameter("outline_width_m", outline_width_m)
	if highlight_root is GeometryInstance3D:
		highlight_meshes.append(highlight_root as GeometryInstance3D)
	else:
		for node: Node in highlight_root.find_children("*", "GeometryInstance3D", true, false):
			highlight_meshes.append(node as GeometryInstance3D)
	assert(not highlight_meshes.is_empty(), "highlight_root 下没有 GeometryInstance3D")


## 返回 HUD 应显示的动作文字。
func get_interact_hint() -> String:
	return interact_hint


## 开关当前交互物全部网格的白色轮廓。
func set_highlighted(active: bool) -> void:
	for mesh: GeometryInstance3D in highlight_meshes:
		mesh.material_overlay = outline_material if active else null


## 接收交互者并发出供具体物体监听的交互信号。
func interact(interactor: Node3D) -> void:
	interacted.emit(interactor)
