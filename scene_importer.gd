@tool
extends EditorScenePostImportPlugin

## List of GLB paths to import (subfolders allowed) -> target Prefab folder
const ASSET_PATHS: Dictionary[String, String] = {
	"res://Assets/Flynsarmy/Models": "res://Assets/Flynsarmy/Prefabs"
}

# Cache of the filepath we're importing
var import_filepath: String = ""
var import_path: String = ""
var import_models_path: String = ""

# Hack to cache the filepath of the scene GLB we're importing
func _get_import_options(path: String) -> void:
	import_filepath = path
	import_path = import_filepath.get_base_dir()
	# Reset caches for new file import
	_meshes_path = ""
	_materials_path = ""
	_animations_path = ""
	import_models_path = ""

func _pre_process(scene: Node) -> void:
	for base_path in ASSET_PATHS:
		if import_path.begins_with(base_path):
			import_models_path = base_path

			var subresources: Dictionary = get_option_value("_subresources");
			if not subresources.has('meshes'):
				subresources['meshes'] = {}
			if not subresources.has('materials'):
				subresources['materials'] = {}
			if not subresources.has('animations'):
				subresources['animations'] = {}

			save_resources(scene, subresources)
			break

# Create prefabs
func _post_process(scene: Node) -> void:
	# Path to our output prefab
	var abs_filepath: String = ""
	var abs_path: String = ""

	if not import_models_path.length() > 0:
		return

	# Determine our prefab filepath
	# Out file will have the same subdir in Prefabs as we have in Models
	abs_filepath = import_filepath.replace(import_models_path, ASSET_PATHS[import_models_path]).get_basename() + ".tscn"
	abs_path = abs_filepath.get_base_dir()

	# Create it if it doesn't exist
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)

	# `scene` is passed by reference and manipulating its children will change the GLB scene but
	# setting new node owners doesn't work correctly and the GLB scene will lose its children.
	# Create a separate `prefab_scene` for our prefab.
	var prefab_scene: Node = scene.duplicate()

	# Scene Transformers
	# - Roads
	if import_path == ("%s/Roads" % import_models_path):
		prefab_scene = ImportSceneTransformerRoads.new().transform(prefab_scene)
	# - Removes Node3D parent from scenes that are just a single MeshInstance3D (with optional StaticBody3D children)
	else:
		prefab_scene = ImportSceneTransformerMeshInstanceRoots.new().transform(prefab_scene)

	# Not sure why this is necessary but it is or only the root node will save.
	recursively_reparent(prefab_scene, prefab_scene)

	# Save the prefab if this file
	var packed: PackedScene = PackedScene.new()
	var error_code: Error = packed.pack(prefab_scene)
	if error_code != OK:
		push_error("Failed to pack scene %s. Error code %s." % [import_filepath, error_code])
		return
	error_code = ResourceSaver.save(packed, abs_filepath)
	if error_code != OK:
		push_error(
			"Failed to save scene to path '%s'. Error code %s." % [abs_filepath, error_code]
		)
		return

# Recursively iterate through a scene replacing each node's owner with the given Node
func recursively_reparent(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		recursively_reparent(child, owner)

# Iterate through a pre-process scene tree saving out meshes, materials etc
func save_resources(node: Node, subresources: Dictionary) -> void:
	if node is ImporterMeshInstance3D:
		var mesh: ImporterMesh = node.mesh
		set_mesh_import_path(mesh, subresources)

		for index in mesh.get_surface_count():
			var material: Material = mesh.get_surface_material(index)
			set_material_import_path(material, subresources)
	elif node is AnimationPlayer:
		for anim_name in node.get_animation_list():
			var animation: Animation = node.get_animation(anim_name)
			set_animation_import_path(animation, subresources)

	for child in node.get_children():
		save_resources(child, subresources)

# Sets the 'Save to' path for Meshes. This will be reflected in the Advanced Import window.
func set_mesh_import_path(resource: ImporterMesh, subresources: Dictionary) -> void:
	subresources['meshes'][resource.resource_name] = {
		'save_to_file/enabled': true,
		'save_to_file/path': "%s/%s.res" % [_get_abs_meshes_path(), resource.resource_name]
	}

func set_animation_import_path(resource: Animation, subresources: Dictionary) -> void:
	subresources['animations'][resource.resource_name] = {
		'save_to_file/enabled': true,
		'save_to_file/keep_custom_tracks': true,
		'save_to_file/path': "%s/%s.res" % [_get_abs_animations_path(), resource.resource_name]
	}

# Sets the 'use external' path for Materials. This will be reflected in the Advanced Import window.
# Creates the material on disk if it doesn't already exist.
func set_material_import_path(resource: Material, subresources: Dictionary) -> void:
	var abs_filepath: String = "%s/%s.res" % [_get_abs_materials_path(), resource.resource_name]

	# Material swaps
	if resource.resource_name.ends_with('OneSided-PixPal'):
		abs_filepath = "%s/Materials/Imphenzia/PixPal/Materials/M_OneSidedImphenziaPixPal.tres" % import_models_path
	elif resource.resource_name.ends_with('PixPal'):
		abs_filepath = "%s/Materials/Imphenzia/PixPal/Materials/M_ImphenziaPixPal.tres" % import_models_path
	elif resource.resource_name.ends_with('CreativeTrio'):
		abs_filepath = "%s/Materials/CreativeTrio/Materials/M_CreativeTrio.tres" % import_models_path
	elif resource.resource_name.begins_with('TSP_Atlas_Vegetation_1A_'):
		abs_filepath = "%s/Materials/Sics/Materials/M_TSP_Atlas_Vegetation_1A_D.tres" % import_models_path
	elif resource.resource_name.begins_with('TSP_Atlas_1A_'):
		abs_filepath = "%s/Materials/Sics/Materials/M_TSP_Atlas_1A_D.tres" % import_models_path

	# Create the material if it doesn't exist
	if not FileAccess.file_exists(abs_filepath):
		var error_code: Error = ResourceSaver.save(resource, abs_filepath)
		if error_code != OK:
			push_error(
				"Failed to save material resource at path '%s'. Error code %s." %
				[abs_filepath, error_code]
			)
			return

	subresources['materials'][resource.resource_name] = {
		'use_external/enabled': true,
		'use_external/path': abs_filepath
	}

# Returns "$import_filepath/Meshes". This will be an absolute folder path.
var _meshes_path: String = ""
func _get_abs_meshes_path() -> String:
	if _meshes_path.length() == 0:
		# Get the import_filepath/meshes dir
		var abs_path: String = "%s/Meshes" % import_path
		# Create it if it doesn't exist
		if not DirAccess.dir_exists_absolute(abs_path):
			DirAccess.make_dir_recursive_absolute(abs_path)
		_meshes_path = abs_path

	return _meshes_path

# Returns "MODELS_BASEPATH/Meshes". This will be an absolute folder path.
var _materials_path: String = ""
func _get_abs_materials_path() -> String:
	if _materials_path.length() == 0:
		# Get the import_filepath/meshes dir
		var abs_path: String = "%s/Materials" % import_models_path
		# Create it if it doesn't exist
		if not DirAccess.dir_exists_absolute(abs_path):
			DirAccess.make_dir_recursive_absolute(abs_path)
		_materials_path = abs_path

	return _materials_path

# Returns "MODELS_BASEPATH/Meshes". This will be an absolute folder path.
var _animations_path: String = ""
func _get_abs_animations_path() -> String:
	if _animations_path.length() == 0:
		# Get the import_filepath/meshes dir
		var abs_path: String = "%s/Animations" % import_path
		# Create it if it doesn't exist
		if not DirAccess.dir_exists_absolute(abs_path):
			DirAccess.make_dir_recursive_absolute(abs_path)
		_animations_path = abs_path

	return _animations_path
