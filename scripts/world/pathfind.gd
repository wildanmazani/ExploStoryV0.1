class_name Pathfind
extends RefCounted
## Grid BFS for tap-to-walk. `world` must provide is_walkable(cell).

const DIRS := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
const LIMIT := 2500  ## max cells explored (keeps taps on far-away tiles cheap)


## Cells to step through from `from` to `to` (excluding `from`). [] if unreachable.
static func find(world: Node, from: Vector2i, to: Vector2i) -> Array:
	if from == to or not world.is_walkable(to):
		return []
	return _bfs(world, from, func(c): return c == to)


## Path to any walkable tile next to `target` (for talking to it).
static func to_neighbour(world: Node, from: Vector2i, target: Vector2i) -> Array:
	return _bfs(world, from, func(c): return (c - target).length_squared() == 1)


static func _bfs(world: Node, from: Vector2i, goal: Callable) -> Array:
	if goal.call(from):
		return []
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size() and head < LIMIT:
		var c := queue[head]
		head += 1
		for d in DIRS:
			var n: Vector2i = c + d
			if prev.has(n) or not world.is_walkable(n):
				continue
			prev[n] = c
			if goal.call(n):
				var path := [n]
				while prev[path[0]] != from:
					path.push_front(prev[path[0]])
				return path
			queue.append(n)
	return []
