extends Resource

class_name ImportSceneTransformer

# Apply any scene tree adjustmenets before creating a Prefab
func transform(scene: Node) -> Node:
	return scene

# Recursively iterate through a scene replacing each node's owner with the given Node
func recursively_reparent(node: Node, owner: Node):
	for child in node.get_children():
		child.owner = owner
		recursively_reparent(child, owner)
