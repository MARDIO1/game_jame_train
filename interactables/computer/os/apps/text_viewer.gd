## 只读记事本。负责读取并显示 UTF-8 文本文件。
extends Control

@onready var text_view: TextEdit = $Text


## 读取指定真实文件，并替换当前只读文本内容。
func open_file(path: String) -> void:
	assert(FileAccess.file_exists(path), "文本文件不存在: %s" % path)
	text_view.text = FileAccess.get_file_as_string(path)
