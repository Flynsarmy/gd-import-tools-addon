@tool
extends EditorPlugin

var scene_import_plugin := preload("scene_importer.gd").new()

func _enter_tree() -> void:
	add_scene_post_import_plugin(scene_import_plugin)


func _exit_tree() -> void:
	remove_scene_post_import_plugin(scene_import_plugin)
