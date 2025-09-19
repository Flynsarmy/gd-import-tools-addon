extends ImportSceneTransformer

class_name ImportSceneTransformerMeshInstanceRoots

# Apply any scene tree adjustmenets before creating a Prefab
# In:
# Node3D
# - MeshInstance3D
# - - [Children]
#
# Out:
# MeshInstance3D
# - [Children]
func transform(scene: Node) -> Node:
	if scene.get_child_count() != 1 or scene.get_child(0) is not MeshInstance3D:
		return scene

	# Make the MeshInstance the new scene root
	var new_root: MeshInstance3D = scene.get_child(0)

	# Assign the new root as the scenes owner
	recursively_reparent(new_root, new_root)

	return new_root
