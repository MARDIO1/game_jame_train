## 通用交互组件。提供提示文字、交互信号、确认音效和共享白色轮廓。
#region 依赖
class_name Interactable
extends Area3D
#endregion

#region 生命周期

## 初始化互不依赖的高亮与音效模块。
func _ready() -> void:
	_setup_highlight()
	_setup_audio()
#endregion

#region 高亮
const OUTLINE_SHADER: Shader = preload("res://interactables/outline.gdshader")

@export var highlight_root: Node3D
@export_range(0.5, 10.0, 0.5, "suffix:px") var outline_width_px: float = 3.0

var outline_material: ShaderMaterial = ShaderMaterial.new()
var highlight_meshes: Array[GeometryInstance3D] = []


## 初始化共享描边材质，并收集模型根节点下的所有网格。
func _setup_highlight() -> void:
	assert(highlight_root != null, "Interactable 需要指定 highlight_root")
	outline_material.shader = OUTLINE_SHADER
	outline_material.set_shader_parameter("outline_width_px", outline_width_px)
	if highlight_root is GeometryInstance3D:
		highlight_meshes.append(highlight_root as GeometryInstance3D)
	else:
		for node: Node in highlight_root.find_children("*", "GeometryInstance3D", true, false):
			highlight_meshes.append(node as GeometryInstance3D)
	assert(not highlight_meshes.is_empty(), "highlight_root 下没有 GeometryInstance3D")


## 开关当前交互物全部网格的白色轮廓。
func set_highlighted(active: bool) -> void:
	for mesh: GeometryInstance3D in highlight_meshes:
		mesh.material_overlay = outline_material if active else null
#endregion

#region 音效
const DEFAULT_INTERACT_SOUND: AudioStream = preload("res://interactables/interact.wav")

@export var interact_sound: AudioStream
@export_range(-80.0, 6.0, 1.0, "suffix:dB") var interact_sound_volume_db: float = -8.0

var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()


## 配置通用的 3D 交互音效播放器。
func _setup_audio() -> void:
	audio_player.stream = interact_sound if interact_sound != null else DEFAULT_INTERACT_SOUND
	audio_player.volume_db = interact_sound_volume_db
	audio_player.max_distance = 4.0
	add_child(audio_player)
#endregion

#region 交互接口
signal interacted(interactor: Node3D)

@export var interact_hint: String = "交互"


## 返回 HUD 应显示的动作文字。
func get_interact_hint(_interactor: Node3D = null) -> String:
	return interact_hint

## 接收交互者并发出供具体物体监听的交互信号。
func interact(interactor: Node3D) -> void:
	audio_player.play()
	interacted.emit(interactor)
#endregion
