extends ImportSceneTransformer

class_name ImportSceneTransformerRoads

# Apply any scene tree adjustmenets before creating a Prefab
# In:
# Node3D
# - Node3D
# - - StaticBody3D
# - - - CollisionShape3D
# - - MeshInstance3D
# - - [MeshInstance3D]
#
# Out:
# MeshInstance3D
# - [MeshInstance3D]
# - StaticBody3D
# - - CollisionShape3D
func transform(scene: Node) -> Node:
	# Find our MeshInstance
	var mis: Array[Node] = scene.find_children('*', 'MeshInstance3D', true, false)
	# Pick the first one as our new scene root
	var new_root: MeshInstance3D = mis.pop_front()
	# Reparent its siblings to it
	for child in new_root.get_parent().get_children():
		if child != new_root:
			# Everything will get reparented later but this hides a warning message.
			child.owner = null
			# All children will have zeroed transforms so the second argument
			# will just hide an invalid error message.
			child.reparent(new_root, false)

	# Assign the new root as the scenes owner
	recursively_reparent(new_root, new_root)

	return new_root
