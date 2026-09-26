## 只读看图器。负责加载图片资源并保持比例显示。
extends Control

@onready var image_view: TextureRect = $Image


## 加载指定真实图片文件，并替换当前显示内容。
func open_file(path: String) -> void:
	var texture: Texture2D = load(path) as Texture2D
	assert(texture != null, "无法加载图片: %s" % path)
	image_view.texture = texture
