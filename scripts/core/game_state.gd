extends RefCounted
class_name GameState

const PLAYER_NAMES = ["红方", "蓝方", "绿方", "黄方"]
const PLAYER_COLORS = [
	Color(0.95, 0.18, 0.22),
	Color(0.25, 0.48, 1.0),
	Color(0.20, 0.78, 0.25),
	Color(1.0, 0.82, 0.22)
]

var db
var width = 60
var height = 30
var turn = 1
var current_player = 0
var next_unit_id = 1
var next_building_id = 1
var terrain_grid: Array = []
var players: Array[Dictionary] = []
var units: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var game_over = false
var winner = -1
var last_event = ""
var player_count = 2
var fog_enabled = true

func setup(database, map_width = 60, map_height = 30, count = 2) -> void:
	db = database
	width = map_width
	height = map_height
	player_count = clampi(int(count), 2, 4)
	new_game()

func new_game() -> void:
	turn = 1
	current_player = 0
	next_unit_id = 1
	next_building_id = 1
	game_over = false
	winner = -1
	players = []
	for pid in range(player_count):
		players.append({
			"id": pid,
			"name": PLAYER_NAMES[pid],
			"gold": 12.0,
			"tier": 1,
			"researched": ["T1"],
			"researching": [],
			"equipment": [],
			"strategic": [],
			"visible": {},
			"explored": {},
			"last_seen": {},
			"alive": true,
			"stats": {
				"turn_data": [],
				"total_kill_value": 0.0
			}
		})
	units.clear()
	buildings.clear()
	_generate_terrain()
	_spawn_initial_state()
	_flatten_around_buildings()
	update_vision()

func _generate_terrain() -> void:
	terrain_grid.clear()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for y in range(height):
		var row = []
		for x in range(width):
			var id = "plain" if rng.randf() < 0.55 else "grass"
			row.append(id)
		terrain_grid.append(row)
	var ridge_count = 2 if player_count >= 3 else 1
	for _i in range(ridge_count):
		var vertical = rng.randf() < 0.5
		var major = height if vertical else width
		var minor = width if vertical else height
		var edge_a = 4 + rng.randi_range(0, max(1, minor - 8))
		var edge_b = 4 + rng.randi_range(0, max(1, minor - 8))
		var amp = 3 + rng.randi_range(0, 4 if player_count >= 3 else 3)
		var amp2 = 1 + rng.randi_range(0, 2)
		var phase = rng.randf() * TAU
		var phase2 = rng.randf() * TAU
		var waves = 1.5 + rng.randf() * 1.5
		var pts: Array[Vector2i] = []
		for a in range(major):
			var t = float(a) / max(1.0, float(major - 1))
			var b = roundi(
				lerpf(float(edge_a), float(edge_b), t)
				+ sin(t * TAU * waves + phase) * float(amp)
				+ sin(t * PI * 6.0 + phase2) * float(amp2)
			)
			b = clampi(b, 2, minor - 3)
			pts.append(Vector2i(b, a) if vertical else Vector2i(a, b))
		_paint_ridge(pts, rng)
		var mirrored: Array[Vector2i] = []
		for p in pts:
			mirrored.append(Vector2i(width - 1 - p.x, height - 1 - p.y))
		_paint_ridge(mirrored, rng)
	_scatter_terrain(rng)

func _paint_ridge(pts: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(pts.size()):
		var center = pts[i]
		var peak_roll = rng.randf()
		var peak = 3 if peak_roll < 0.08 else (2 if peak_roll < 0.26 else 1)
		if i % 4 == 0 and rng.randf() < 0.50:
			continue
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if abs(dx) + abs(dy) > 1:
					continue
				if (dx != 0 or dy != 0) and rng.randf() < 0.55:
					continue
				var pos = center + Vector2i(dx, dy)
				if not in_bounds(pos):
					continue
				var dist = sqrt(float(dx * dx + dy * dy))
				var height_value = peak if dist <= 0.45 else (2 if peak >= 3 else 1)
				_set_terrain_height_if_higher(pos, height_value)

func _scatter_terrain(rng: RandomNumberGenerator) -> void:
	var count = int(width * height / 150)
	for _i in range(count):
		var pos = Vector2i(rng.randi_range(2, max(2, width - 3)), rng.randi_range(2, max(2, height - 3)))
		var roll = rng.randf()
		var height_value = 3 if roll < 0.08 else (2 if roll < 0.28 else 1)
		_set_terrain_height_if_higher(pos, height_value)
		if height_value <= 2 and rng.randf() < 0.45:
			var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			_set_terrain_height_if_higher(pos + dirs[rng.randi_range(0, dirs.size() - 1)], 1)
		if rng.randf() < 0.22:
			var mirror = Vector2i(width - 1 - pos.x, height - 1 - pos.y)
			_set_terrain_height_if_higher(mirror, max(1, height_value - rng.randi_range(0, 1)))

func _set_terrain_height_if_higher(pos: Vector2i, height_value: int) -> void:
	if not in_bounds(pos):
		return
	var current_height = terrain_height(pos)
	if height_value <= current_height:
		return
	if height_value >= 3:
		terrain_grid[pos.y][pos.x] = "mountain"
	elif height_value == 2:
		terrain_grid[pos.y][pos.x] = "highland"
	else:
		terrain_grid[pos.y][pos.x] = "hill"

func _spawn_initial_state() -> void:
	var spawns = _player_spawns()
	for pid in range(player_count):
		var hq_pos: Vector2i = spawns[pid]
		_add_building("大本营", pid, hq_pos, 0)
	for pos in _neutral_outpost_positions(spawns):
		if in_bounds(pos) and occupant_at(pos).is_empty():
			var building = _add_building("据点", -1, pos, 0)
			building["hp"] = max(1.0, float(building.get("max_hp", 1.0)) * 0.5)

func _player_spawns() -> Array[Vector2i]:
	if player_count == 2:
		var mid_y = int(height / 2)
		return [Vector2i(8, mid_y), Vector2i(51, mid_y)]
	return [
		Vector2i(8, 8),
		Vector2i(width - 9, 8),
		Vector2i(8, height - 9),
		Vector2i(width - 9, height - 9)
	]

func _neutral_outpost_positions(spawns: Array[Vector2i]) -> Array[Vector2i]:
	if player_count == 2:
		var mid_x = int((spawns[0].x + spawns[1].x) / 2)
		var mid_y = int(height / 2)
		return [
			Vector2i(mid_x - 5, mid_y - 12),
			Vector2i(mid_x, mid_y),
			Vector2i(mid_x + 5, mid_y + 12)
		]
	var positions: Array[Vector2i] = []
	var top_mid = Vector2i(int((spawns[0].x + spawns[1].x) / 2), int((spawns[0].y + spawns[1].y) / 2))
	positions.append(top_mid)
	if player_count > 2:
		positions.append(Vector2i(int(width / 2), int(height / 2)))
	return positions

func _flatten_around_buildings() -> void:
	for building in buildings:
		var center: Vector2i = building["pos"]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var pos = center + Vector2i(dx, dy)
				if in_bounds(pos):
					terrain_grid[pos.y][pos.x] = "plain"

func _nearest_free_tile(origin: Vector2i) -> Vector2i:
	if in_bounds(origin) and occupant_at(origin).is_empty():
		return origin
	for radius in range(1, 5):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				var pos = Vector2i(x, y)
				if in_bounds(pos) and occupant_at(pos).is_empty():
					return pos
	return Vector2i(-1, -1)

func _add_unit(unit_type: String, pid: int, pos: Vector2i) -> Dictionary:
	var data = db.unit_data(unit_type)
	var unit = {
		"id": next_unit_id,
		"type": unit_type,
		"pid": pid,
		"pos": pos,
		"hp": float(data.get("hp", 1.0)),
		"max_hp": float(data.get("hp", 1.0)),
		"armor": float(data.get("armor", 0.0)),
		"speed": int(data.get("speed", 3)),
		"damage": float(data.get("damage", 1.0)),
		"range": float(data.get("range", 1.0)),
		"attacks": int(data.get("attacks", 1)),
		"remaining_attacks": int(data.get("attacks", 1)),
		"moved": false,
		"done": false,
		"is_air": bool(data.get("is_air", false)),
		"can_target_air": bool(data.get("can_target_air", false)),
		"air_damage": float(data.get("air_damage", 0.0)),
		"air_range": float(data.get("air_range", 0.0)),
		"blast": float(data.get("blast", 0.0)),
		"reload": int(data.get("reload", 0)),
		"rl": 0,
		"self_destruct": bool(data.get("self_destruct", false)),
		"applied_equipment": [],
		"equip": ""
	}
	next_unit_id += 1
	units.append(unit)
	return unit

func _add_building(building_type: String, pid: int, pos: Vector2i, tier: int) -> Dictionary:
	var data = db.building_data(building_type)
	var stats = data
	if data.has("tiers"):
		stats = data["tiers"][tier]
	var building = {
		"id": next_building_id,
		"type": building_type,
		"pid": pid,
		"pos": pos,
		"tier": tier,
		"hp": float(stats.get("hp", 10.0)),
		"max_hp": float(stats.get("hp", 10.0)),
		"armor": float(stats.get("armor", 0.0)),
		"gold": float(stats.get("gold", 0.0)),
		"captured": pid >= 0,
		"under_construction": false,
		"build_timer": 0,
		"collector_id": -1,
		"outpost_tier": 0,
		"outpost_branch": "",
		"upgrading": false,
		"up_timer": 0,
		"turns_since_damage": 0,
		"damaged_this_turn": false
	}
	next_building_id += 1
	buildings.append(building)
	return building

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func terrain_at(pos: Vector2i) -> String:
	if not in_bounds(pos):
		return "plain"
	return str(terrain_grid[pos.y][pos.x])

func unit_at(pos: Vector2i) -> Dictionary:
	for unit in units:
		if unit["pos"] == pos:
			return unit
	return {}

func building_at(pos: Vector2i) -> Dictionary:
	for building in buildings:
		if building["pos"] == pos:
			return building
	return {}

func occupant_at(pos: Vector2i) -> Dictionary:
	var unit = unit_at(pos)
	if not unit.is_empty():
		return unit
	return building_at(pos)

func is_unit_blocked(pos: Vector2i) -> bool:
	return not unit_at(pos).is_empty()

func get_unit_by_id(id: int) -> Dictionary:
	for unit in units:
		if unit["id"] == id:
			return unit
	return {}

func is_current_players_unit(unit: Dictionary) -> bool:
	return not unit.is_empty() and int(unit.get("pid", -1)) == current_player and not bool(unit.get("done", false))

func move_tiles_for(unit: Dictionary, ignore_moved: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit.is_empty() or (bool(unit.get("moved", false)) and not ignore_moved):
		return result
	var budget = float(unit.get("speed", 0))
	var frontier: Array[Vector2i] = [unit["pos"]]
	var costs = {unit["pos"]: 0.0}
	var dirs = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for dir in dirs:
			var next: Vector2i = current + dir
			if not in_bounds(next) or is_unit_blocked(next):
				continue
			var building = building_at(next)
			if not building.is_empty() and building["type"] == "大本营" and int(building["pid"]) != int(unit["pid"]):
				continue
			var next_cost = float(costs[current]) + _step_cost(unit, current, next)
			if next_cost > budget:
				continue
			if not costs.has(next) or next_cost < float(costs[next]):
				costs[next] = next_cost
				frontier.append(next)
	for pos in costs.keys():
		if pos != unit["pos"]:
			result.append(pos)
	return result

func attack_targets_for(unit: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit.is_empty() or bool(unit.get("done", false)) or int(unit.get("remaining_attacks", 0)) <= 0 or int(unit.get("rl", 0)) > 0:
		return result
	var origin: Vector2i = unit["pos"]
	var origin_height = terrain_height(origin)
	for other in units:
		if int(other["pid"]) == int(unit["pid"]):
			continue
		if not is_visible(int(unit["pid"]), other["pos"]):
			continue
		if bool(other.get("is_air", false)) and not bool(unit.get("can_target_air", false)):
			continue
		if _distance(origin, other["pos"]) <= effective_range(unit, origin_height, terrain_height(other["pos"]), bool(other.get("is_air", false))):
			result.append(other["pos"])
	for building in buildings:
		if int(building["pid"]) == int(unit["pid"]):
			continue
		if not is_explored(int(unit["pid"]), building["pos"]):
			continue
		if _distance(origin, building["pos"]) <= effective_range(unit, origin_height, terrain_height(building["pos"])):
			result.append(building["pos"])
	return result

func attack_range_tiles_for(unit: Dictionary) -> Array[Vector2i]:
	if unit.is_empty():
		var empty: Array[Vector2i] = []
		return empty
	return _attack_range_tiles_from(unit, unit["pos"])

func hover_threat_tiles_for_unit(unit: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit.is_empty():
		return result
	var origin: Vector2i = unit["pos"]
	var radius = float(unit.get("speed", 0)) + max_possible_range_for(unit, origin)
	var bound = ceili(radius)
	for y in range(max(0, origin.y - bound), min(height, origin.y + bound + 1)):
		for x in range(max(0, origin.x - bound), min(width, origin.x + bound + 1)):
			var pos = Vector2i(x, y)
			if _distance(origin, pos) <= radius:
				result.append(pos)
	return result

func max_possible_range_for(unit: Dictionary, origin: Vector2i) -> float:
	if unit.is_empty():
		return 0.0
	var terrain_bonus = 0 if bool(unit.get("is_air", false)) else terrain_height(origin)
	return max(float(unit.get("range", 0.0)), float(unit.get("air_range", 0.0))) + float(terrain_bonus)

func _attack_range_tiles_from(unit: Dictionary, origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit.is_empty():
		return result
	var origin_height = terrain_height(origin)
	var max_range = max(float(unit.get("range", 1.0)), float(unit.get("air_range", 0.0)))
	max_range += min(3, terrain_height(origin))
	var radius = ceili(max_range + 2.0)
	for y in range(max(0, origin.y - radius), min(height, origin.y + radius + 1)):
		for x in range(max(0, origin.x - radius), min(width, origin.x + radius + 1)):
			var pos = Vector2i(x, y)
			if pos == origin:
				continue
			if _distance(origin, pos) <= effective_range(unit, origin_height, terrain_height(pos)):
				result.append(pos)
	return result

func threat_tiles_against(pid: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen = {}
	for unit in units:
		if int(unit.get("pid", -1)) == pid:
			continue
		if not is_visible(pid, unit["pos"]):
			continue
		var origins: Array[Vector2i] = [unit["pos"]]
		origins.append_array(move_tiles_for(unit, true))
		for origin in origins:
			for pos in _attack_range_tiles_from(unit, origin):
				var key = "%d,%d" % [pos.x, pos.y]
				if seen.has(key):
					continue
				seen[key] = true
				result.append(pos)
	return result

func collector_build_tiles(building: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if building.is_empty() or building.get("type", "") != "大本营":
		return result
	var origin: Vector2i = building["pos"]
	for y in range(max(0, origin.y - 5), min(height, origin.y + 6)):
		for x in range(max(0, origin.x - 5), min(width, origin.x + 6)):
			var pos = Vector2i(x, y)
			if can_build_collector(building, pos):
				result.append(pos)
	return result

func move_unit(unit_id: int, target: Vector2i) -> bool:
	var unit = get_unit_by_id(unit_id)
	if not is_current_players_unit(unit):
		return false
	if not move_tiles_for(unit).has(target):
		return false
	unit["pos"] = target
	unit["moved"] = true
	_capture_building_at(target, int(unit["pid"]))
	update_vision()
	return true

func skip_unit(unit_id: int) -> bool:
	var unit = get_unit_by_id(unit_id)
	if not is_current_players_unit(unit):
		return false
	unit["moved"] = true
	unit["done"] = true
	unit["remaining_attacks"] = 0
	return true

func _capture_building_at(pos: Vector2i, pid: int) -> void:
	var building = building_at(pos)
	if building.is_empty():
		return
	if building["type"] == "大本营":
		return
	if int(building.get("pid", -1)) == pid:
		return
	building["pid"] = pid
	building["captured"] = true
	building["hp"] = max(1.0, float(building.get("max_hp", 1.0)) * 0.5)
	building["turns_since_damage"] = 0
	building["damaged_this_turn"] = false
	update_vision()

func attack(unit_id: int, target_pos: Vector2i) -> bool:
	var unit = get_unit_by_id(unit_id)
	if not is_current_players_unit(unit):
		return false
	if not attack_targets_for(unit).has(target_pos):
		return false
	var target = occupant_at(target_pos)
	if target.is_empty():
		return false
	_apply_damage(target, max(0.0, _unit_damage_against(unit, target) - float(target.get("armor", 0.0))), int(unit["pid"]))
	if float(unit.get("blast", 0.0)) > 0.0:
		_apply_blast(unit, target_pos)
	if bool(unit.get("self_destruct", false)):
		units.erase(unit)
	else:
		unit["remaining_attacks"] = int(unit.get("remaining_attacks", 1)) - 1
		unit["moved"] = true
		if int(unit.get("reload", 0)) > 0:
			unit["rl"] = int(unit.get("reload", 0))
		if int(unit["remaining_attacks"]) <= 0:
			unit["done"] = true
	_check_victory()
	update_vision()
	return true

func _apply_damage(target: Dictionary, damage: float, killer_pid: int = -1) -> void:
	if target.has("type") and not target.has("speed"):
		target["damaged_this_turn"] = true
		target["turns_since_damage"] = 0
	target["hp"] = float(target.get("hp", 0.0)) - damage
	if float(target["hp"]) > 0:
		return
	if target.has("type") and target.has("speed"):
		_record_kill_value(killer_pid, str(target.get("type", "")))
		units.erase(target)
	else:
		buildings.erase(target)

func _apply_blast(attacker: Dictionary, center: Vector2i) -> void:
	var radius = float(attacker.get("blast", 0.0))
	var victims: Array[Dictionary] = []
	for unit in units:
		if int(unit["pid"]) == int(attacker["pid"]):
			continue
		if unit["pos"] == center:
			continue
		if _distance(center, unit["pos"]) <= radius:
			victims.append(unit)
	for victim in victims:
		_apply_damage(victim, max(0.0, _unit_damage_against(attacker, victim) - float(victim.get("armor", 0.0))), int(attacker["pid"]))
	var damaged_buildings: Array[Dictionary] = []
	for building in buildings:
		if int(building.get("pid", -1)) == int(attacker["pid"]):
			continue
		if building["pos"] == center:
			continue
		if _distance(center, building["pos"]) <= radius:
			damaged_buildings.append(building)
	for building in damaged_buildings:
		_apply_damage(building, max(0.0, float(attacker.get("damage", 0.0)) - float(building.get("armor", 0.0))), int(attacker["pid"]))

func end_turn() -> void:
	var alive_count = 0
	for player in players:
		if bool(player.get("alive", true)):
			alive_count += 1
	if alive_count <= 1:
		_check_victory()
		return
	var was = current_player
	for _i in range(players.size()):
		current_player = (current_player + 1) % players.size()
		if bool(players[current_player].get("alive", true)):
			break
	var wrapped = (current_player <= was and was != current_player) or (was == players.size() - 1 and current_player == 0)
	if wrapped:
		turn += 1
		for pid in range(players.size()):
			if not bool(players[pid].get("alive", true)):
				continue
			for building in buildings:
				if int(building.get("pid", -1)) == pid:
					_tick_building_progress(building)
			_tick_player_research(pid)
			players[pid]["gold"] = float(players[pid]["gold"]) + _income_for(pid)
			_record_turn_stats(pid)
		for building in buildings:
			if int(building.get("pid", -1)) == -1:
				_building_turn_start(building)
	_start_player_turn(current_player)
	update_vision()

func _start_player_turn(pid: int) -> void:
	for unit in units:
		if int(unit["pid"]) == pid:
			unit["moved"] = false
			unit["done"] = false
			unit["remaining_attacks"] = int(unit.get("attacks", 1))
			if int(unit.get("rl", 0)) > 0:
				unit["rl"] = int(unit.get("rl", 0)) - 1
	for building in buildings:
		if int(building.get("pid", -1)) == pid:
			_building_turn_start(building)

func _building_turn_start(building: Dictionary) -> void:
	if bool(building.get("damaged_this_turn", false)):
		building["turns_since_damage"] = 0
	else:
		building["turns_since_damage"] = int(building.get("turns_since_damage", 0)) + 1
	building["damaged_this_turn"] = false
	if int(building["turns_since_damage"]) >= 3 and float(building.get("hp", 0.0)) < float(building.get("max_hp", 1.0)):
		building["hp"] = min(float(building.get("max_hp", 1.0)), float(building.get("hp", 0.0)) + 2.0)

func surrender(pid: int) -> void:
	if pid < 0 or pid >= players.size() or game_over:
		return
	players[pid]["alive"] = false
	last_event = "%s 投降" % players[pid]["name"]
	_check_victory()
	update_vision()

func current_tier_name() -> String:
	return "T%d" % int(players[current_player].get("tier", 1))

func can_produce(building: Dictionary, unit_type: String) -> bool:
	if building.is_empty() or not ["大本营", "据点"].has(str(building.get("type", ""))):
		return false
	if int(building.get("pid", -1)) != current_player:
		return false
	if bool(building.get("under_construction", false)):
		return false
	if not db.unit_data(unit_type):
		return false
	var allowed = available_units_for_player(current_player)
	if not allowed.has(unit_type):
		return false
	var price = float(db.unit_data(unit_type).get("price", 0.0))
	return float(players[current_player]["gold"]) >= price

func produce_unit(building_id: int, unit_type: String) -> bool:
	var building = get_building_by_id(building_id)
	if not can_produce(building, unit_type):
		return false
	var spawn = _find_spawn_tile(building["pos"])
	if spawn == Vector2i(-1, -1):
		return false
	var price = float(db.unit_data(unit_type).get("price", 0.0))
	players[current_player]["gold"] = float(players[current_player]["gold"]) - price
	var unit = _add_unit(unit_type, current_player, spawn)
	unit["moved"] = true
	unit["done"] = true
	unit["remaining_attacks"] = 0
	update_vision()
	return true

func can_build_collector(building: Dictionary, pos: Vector2i) -> bool:
	if building.is_empty() or building.get("type", "") != "大本营":
		return false
	if int(building.get("pid", -1)) != current_player:
		return false
	var data = db.building_data("资源采集器")
	if not in_bounds(pos) or not occupant_at(pos).is_empty():
		return false
	if _distance(building["pos"], pos) > 5.0:
		return false
	return float(players[current_player]["gold"]) >= float(data.get("cost", 8.0))

func build_collector(building_id: int, pos: Vector2i) -> bool:
	var building = get_building_by_id(building_id)
	if not can_build_collector(building, pos):
		return false
	var data = db.building_data("资源采集器")
	players[current_player]["gold"] = float(players[current_player]["gold"]) - float(data.get("cost", 8.0))
	var collector = _add_building("资源采集器", current_player, pos, 0)
	collector["under_construction"] = true
	collector["build_timer"] = 2
	collector["collector_id"] = _next_collector_id(current_player)
	collector["gold"] = 0.0
	update_vision()
	return true

func get_building_by_id(id: int) -> Dictionary:
	for building in buildings:
		if int(building["id"]) == id:
			return building
	return {}

func available_units_for_player(pid: int) -> Array:
	var tier = int(players[pid].get("tier", 1))
	var result: Array = []
	for t in range(1, tier + 1):
		for unit_type in db.production_for("大本营", "T%d" % t):
			if not result.has(unit_type):
				result.append(unit_type)
	return result

func can_research_next_tier(pid: int) -> bool:
	var next_tier = int(players[pid].get("tier", 1)) + 1
	return db.techs.has("T%d" % next_tier)

func research_next_tier(pid: int) -> bool:
	if pid != current_player or not can_research_next_tier(pid):
		return false
	var next_tier = int(players[pid].get("tier", 1)) + 1
	var tech_id = "T%d" % next_tier
	var cost = float(db.techs[tech_id].get("cost", 0.0))
	if float(players[pid]["gold"]) < cost:
		return false
	players[pid]["gold"] = float(players[pid]["gold"]) - cost
	players[pid]["tier"] = next_tier
	players[pid]["researched"].append(tech_id)
	last_event = "%s 研究完成：%s" % [players[pid]["name"], db.techs[tech_id].get("name", tech_id)]
	return true

func _set_player_tier_from_hq(pid: int, hq_tier: int) -> void:
	if pid < 0 or pid >= players.size():
		return
	var player_tier = clampi(hq_tier + 1, 1, 3)
	players[pid]["tier"] = max(int(players[pid].get("tier", 1)), player_tier)
	for tier_id in range(1, int(players[pid]["tier"]) + 1):
		var tech_id = "T%d" % tier_id
		if db.techs.has(tech_id) and not players[pid]["researched"].has(tech_id):
			players[pid]["researched"].append(tech_id)

func can_upgrade_hq(building: Dictionary) -> bool:
	if building.is_empty() or building.get("type", "") != "大本营":
		return false
	if int(building.get("pid", -1)) != current_player:
		return false
	if bool(building.get("upgrading", false)):
		return false
	var tier = int(building.get("tier", 0))
	var data = db.building_data("大本营")
	if tier >= data.get("tiers", []).size() - 1:
		return false
	var cost = float(data["tiers"][tier].get("upgrade_cost", 0.0))
	return float(players[current_player]["gold"]) >= cost

func upgrade_hq(building_id: int) -> bool:
	var building = get_building_by_id(building_id)
	if not can_upgrade_hq(building):
		return false
	var data = db.building_data("大本营")
	var tier = int(building.get("tier", 0))
	var cost = float(data["tiers"][tier].get("upgrade_cost", 0.0))
	players[current_player]["gold"] = float(players[current_player]["gold"]) - cost
	building["upgrading"] = true
	building["up_timer"] = int(data["tiers"][tier].get("upgrade_time", 1))
	update_vision()
	return true

func can_upgrade_outpost(building: Dictionary, branch: String) -> bool:
	if building.is_empty() or building.get("type", "") != "据点":
		return false
	if int(building.get("pid", -1)) != current_player:
		return false
	if int(building.get("outpost_tier", 0)) > 0 or bool(building.get("upgrading", false)):
		return false
	if int(players[current_player].get("tier", 1)) < 2:
		return false
	if not ["combat", "economic"].has(branch):
		return false
	return float(players[current_player]["gold"]) >= 10.0

func upgrade_outpost(building_id: int, branch: String) -> bool:
	var building = get_building_by_id(building_id)
	if not can_upgrade_outpost(building, branch):
		return false
	players[current_player]["gold"] = float(players[current_player]["gold"]) - 10.0
	building["upgrading"] = true
	building["up_timer"] = 1 if branch == "combat" else 3
	building["outpost_branch"] = branch
	return true

func can_research_equipment(pid: int, unit_type: String, equip_name: String) -> bool:
	if pid != current_player:
		return false
	var equip = equipment_data(unit_type, equip_name)
	if equip.is_empty() or players[pid]["equipment"].has(equipment_key(unit_type, equip_name)):
		return false
	if _is_researching(pid, equip_name):
		return false
	if int(players[pid].get("tier", 1)) < int(equip.get("tier", 1)):
		return false
	return float(players[pid]["gold"]) >= float(equip.get("research_cost", 0.0))

func research_equipment(pid: int, unit_type: String, equip_name: String) -> bool:
	if not can_research_equipment(pid, unit_type, equip_name):
		return false
	var equip = equipment_data(unit_type, equip_name)
	players[pid]["gold"] = float(players[pid]["gold"]) - float(equip.get("research_cost", 0.0))
	players[pid]["researching"].append({
		"name": equip_name,
		"kind": "equipment",
		"unit_type": unit_type,
		"timer": int(equip.get("research_time", 1))
	})
	return true

func equipment_key(unit_type: String, equip_name: String) -> String:
	return "%s:%s" % [unit_type, equip_name]

func equipment_data(unit_type: String, equip_name: String) -> Dictionary:
	for equip in db.equipment_for(unit_type):
		if str(equip.get("name", "")) == equip_name:
			return equip
	return {}

func research_entry(pid: int, name: String) -> Dictionary:
	if pid < 0 or pid >= players.size():
		return {}
	for entry in players[pid].get("researching", []):
		if str(entry.get("name", "")) == name:
			return entry
	return {}

func _is_researching(pid: int, name: String) -> bool:
	return not research_entry(pid, name).is_empty()

func _tick_player_research(pid: int) -> void:
	if pid < 0 or pid >= players.size():
		return
	var remaining = []
	for raw_entry in players[pid].get("researching", []):
		var entry = Dictionary(raw_entry)
		entry["timer"] = max(0, int(entry.get("timer", 0)) - 1)
		if int(entry["timer"]) > 0:
			remaining.append(entry)
			continue
		var name = str(entry.get("name", ""))
		if str(entry.get("kind", "")) == "equipment":
			var unit_type = str(entry.get("unit_type", ""))
			var key = equipment_key(unit_type, name)
			if not players[pid]["equipment"].has(key):
				players[pid]["equipment"].append(key)
		elif str(entry.get("kind", "")) == "strategic":
			if not players[pid]["strategic"].has(name):
				players[pid]["strategic"].append(name)
		else:
			if not players[pid]["researched"].has(name):
				players[pid]["researched"].append(name)
		last_event = "%s 研究完成：%s" % [players[pid]["name"], name]
	players[pid]["researching"] = remaining

func can_equip_unit(unit: Dictionary, equip_name: String) -> bool:
	if unit.is_empty() or int(unit.get("pid", -1)) != current_player:
		return false
	if not str(unit.get("equip", "")).is_empty():
		return false
	var equip = equipment_data(str(unit.get("type", "")), equip_name)
	if equip.is_empty():
		return false
	if not players[current_player]["equipment"].has(equipment_key(str(unit.get("type", "")), equip_name)):
		return false
	return float(players[current_player]["gold"]) >= float(equip.get("cost", 0.0))

func equip_unit(unit_id: int, equip_name: String) -> bool:
	var unit = get_unit_by_id(unit_id)
	if not can_equip_unit(unit, equip_name):
		return false
	var equip = equipment_data(str(unit.get("type", "")), equip_name)
	players[current_player]["gold"] = float(players[current_player]["gold"]) - float(equip.get("cost", 0.0))
	var old_hp = float(unit.get("hp", 1.0))
	var old_max = max(1.0, float(unit.get("max_hp", 1.0)))
	_apply_equipment_to_unit(unit, equip)
	unit["equip"] = equip_name
	unit["hp"] = min(float(unit.get("max_hp", old_max)), float(unit.get("max_hp", old_max)) * (1.0 + old_hp / old_max) / 2.0)
	update_vision()
	return true

func can_research_strategic(pid: int, tech_name: String) -> bool:
	if pid != current_player:
		return false
	var tech = db.strategic_techs.get(tech_name, {})
	if tech.is_empty() or players[pid]["strategic"].has(tech_name):
		return false
	if _is_researching(pid, tech_name):
		return false
	if int(players[pid].get("tier", 1)) < int(tech.get("tier", 1)):
		return false
	return float(players[pid]["gold"]) >= float(tech.get("cost", 0.0))

func research_strategic(pid: int, tech_name: String) -> bool:
	if not can_research_strategic(pid, tech_name):
		return false
	var tech = db.strategic_techs[tech_name]
	players[pid]["gold"] = float(players[pid]["gold"]) - float(tech.get("cost", 0.0))
	players[pid]["researching"].append({
		"name": tech_name,
		"kind": "strategic",
		"timer": int(tech.get("research_time", 1))
	})
	return true

func _find_spawn_tile(origin: Vector2i) -> Vector2i:
	var candidates = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	for offset in candidates:
		var pos = origin + offset
		if in_bounds(pos) and occupant_at(pos).is_empty():
			return pos
	return Vector2i(-1, -1)

func _tick_building_progress(building: Dictionary) -> void:
	if bool(building.get("under_construction", false)):
		building["build_timer"] = max(0, int(building.get("build_timer", 0)) - 1)
		if int(building["build_timer"]) <= 0:
			building["under_construction"] = false
			var base_gold = 4.5
			var collector_id = max(0, int(building.get("collector_id", 0)))
			building["gold"] = snapped(base_gold * pow(0.8, collector_id), 0.01)
	if bool(building.get("upgrading", false)):
		building["up_timer"] = max(0, int(building.get("up_timer", 0)) - 1)
		if int(building["up_timer"]) <= 0:
			building["upgrading"] = false
			if building.get("type", "") == "大本营":
				_finish_hq_upgrade(building)
			elif building.get("type", "") == "据点":
				_finish_outpost_upgrade(building)

func _finish_hq_upgrade(building: Dictionary) -> void:
	var data = db.building_data("大本营")
	var tier = int(building.get("tier", 0))
	if tier >= data.get("tiers", []).size() - 1:
		return
	var old_max = float(building.get("max_hp", 1.0))
	var old_hp = clamp(float(building.get("hp", old_max)), 1.0, old_max)
	var hp_ratio = old_hp / max(1.0, old_max)
	tier += 1
	var stats = data["tiers"][tier]
	building["tier"] = tier
	building["max_hp"] = float(stats.get("hp", old_max))
	building["hp"] = max(1.0, float(building["max_hp"]) * (1.0 + hp_ratio) / 2.0)
	building["armor"] = float(stats.get("armor", 0.0))
	building["gold"] = float(stats.get("gold", 0.0))
	_set_player_tier_from_hq(int(building.get("pid", -1)), tier)

func _finish_outpost_upgrade(building: Dictionary) -> void:
	var old_max = max(1.0, float(building.get("max_hp", 1.0)))
	var old_hp = clamp(float(building.get("hp", old_max)), 1.0, old_max)
	building["outpost_tier"] = 1
	if str(building.get("outpost_branch", "")) == "combat":
		building["max_hp"] = 30.0
		building["hp"] = 30.0
		building["armor"] = 0.5
		building["gold"] = 6.0
	else:
		building["outpost_branch"] = "economic"
		building["max_hp"] = 20.0
		building["hp"] = min(20.0, 20.0 * (1.0 + old_hp / old_max) / 2.0)
		building["armor"] = 0.0
		building["gold"] = 9.0

func _next_collector_id(pid: int) -> int:
	var used: Array[int] = []
	for building in buildings:
		if int(building.get("pid", -1)) == pid and building.get("type", "") == "资源采集器":
			used.append(int(building.get("collector_id", -1)))
	var id = 0
	while used.has(id):
		id += 1
	return id

func _apply_researched_equipment_to_unit(unit: Dictionary) -> void:
	var pid = int(unit.get("pid", -1))
	if pid < 0 or pid >= players.size():
		return
	for equip in db.equipment_for(unit["type"]):
		if players[pid]["equipment"].has(equipment_key(unit["type"], str(equip.get("name", "")))):
			_apply_equipment_to_unit(unit, equip)

func _apply_equipment_to_unit(unit: Dictionary, equip: Dictionary) -> void:
	var key = str(equip.get("name", ""))
	if not unit.has("applied_equipment"):
		unit["applied_equipment"] = []
	if unit["applied_equipment"].has(key):
		return
	unit["applied_equipment"].append(key)
	unit["damage"] = float(unit.get("damage", 0.0)) + float(equip.get("dmg", 0.0))
	unit["range"] = float(unit.get("range", 0.0)) + float(equip.get("range", 0.0))
	unit["speed"] = int(unit.get("speed", 0)) + int(equip.get("speed", 0))
	unit["armor"] = float(unit.get("armor", 0.0)) + float(equip.get("armor", 0.0))
	if equip.has("hp"):
		unit["max_hp"] = max(0.5, float(unit.get("max_hp", 1.0)) + float(equip.get("hp", 0.0)))
		unit["hp"] = min(float(unit["max_hp"]), max(0.5, float(unit.get("hp", 1.0)) + float(equip.get("hp", 0.0))))
	if equip.has("blast"):
		unit["blast"] = float(equip.get("blast", unit.get("blast", 0.0)))
	if bool(equip.get("can_target_air", false)):
		unit["can_target_air"] = true

func _unit_damage_against(unit: Dictionary, target: Dictionary) -> float:
	if bool(target.get("is_air", false)) and float(unit.get("air_damage", 0.0)) > 0.0:
		return float(unit["air_damage"])
	var damage = float(unit.get("damage", 0.0))
	if unit["type"] == "自杀无人机" and players[int(unit["pid"])]["strategic"].has("SpaceX 星链计划"):
		damage += 1.0
	return damage

func _record_kill_value(pid: int, unit_type: String) -> void:
	if pid < 0 or pid >= players.size():
		return
	var stats: Dictionary = players[pid].get("stats", {})
	stats["total_kill_value"] = float(stats.get("total_kill_value", 0.0)) + float(db.unit_data(unit_type).get("price", 0.0))
	players[pid]["stats"] = stats

func _record_turn_stats(pid: int) -> void:
	if pid < 0 or pid >= players.size():
		return
	var stats: Dictionary = players[pid].get("stats", {})
	var turn_data: Array = stats.get("turn_data", [])
	turn_data.append({
		"turn": turn,
		"army_value": _army_value(pid),
		"gold": float(players[pid].get("gold", 0.0)),
		"kill_value": float(stats.get("total_kill_value", 0.0)),
		"income": _income_for(pid)
	})
	stats["turn_data"] = turn_data
	players[pid]["stats"] = stats

func _army_value(pid: int) -> float:
	var value = 0.0
	for unit in units:
		if int(unit.get("pid", -1)) == pid:
			value += float(db.unit_data(str(unit.get("type", ""))).get("price", 0.0))
	return value

func _income_for(pid: int) -> float:
	var income = 0.0
	for building in buildings:
		if int(building.get("pid", -1)) == pid and not bool(building.get("under_construction", false)):
			income += float(building.get("gold", 0.0))
	return income

func terrain_height(pos: Vector2i) -> int:
	return int(db.terrain_data(terrain_at(pos)).get("height", 0))

func _step_cost(unit: Dictionary, from_pos: Vector2i, to_pos: Vector2i) -> float:
	var diagonal = 1.4 if from_pos.x != to_pos.x and from_pos.y != to_pos.y else 1.0
	if bool(unit.get("is_air", false)):
		return diagonal
	var base = float(db.terrain_data(terrain_at(to_pos)).get("move_cost", 1.0))
	var diff = terrain_height(to_pos) - terrain_height(from_pos)
	var slope = float(diff) * (0.8 if diff > 0 else 0.35)
	return max(0.6, base + slope) * diagonal

func effective_range(unit: Dictionary, from_height: int, to_height: int, target_is_air: bool = false) -> float:
	if target_is_air and float(unit.get("air_range", 0.0)) > 0.0:
		return float(unit["air_range"])
	var mod = clamp(from_height - to_height, -2, 2)
	return max(1.0, float(unit.get("range", 1.0)) + float(mod))

func update_vision() -> void:
	for player in players:
		player["visible"] = {}
		if not player.has("explored") or not (player["explored"] is Dictionary):
			player["explored"] = {}
		if not player.has("last_seen") or not (player["last_seen"] is Dictionary):
			player["last_seen"] = {}
		if player["strategic"].has("SpaceX 星链计划"):
			for y in range(height):
				for x in range(width):
					_mark_visible(player, Vector2i(x, y))
		else:
			for unit in units:
				if int(unit["pid"]) == int(player["id"]):
					_mark_radius(player, unit["pos"], int(db.unit_data(unit["type"]).get("vision", 4)) + (0 if bool(unit.get("is_air", false)) else terrain_height(unit["pos"])))
			for building in buildings:
				if int(building.get("pid", -1)) == int(player["id"]):
					var vision = 3
					if building["type"] == "大本营":
						var data = db.building_data("大本营")
						vision = int(data["tiers"][int(building.get("tier", 0))].get("vision", 7))
					elif building["type"] == "据点" and str(building.get("outpost_branch", "")) == "combat" and int(building.get("outpost_tier", 0)) > 0:
						vision = 6
					else:
						vision = int(db.building_data(building["type"]).get("vision", 3))
					_mark_radius(player, building["pos"], vision)
		_update_last_seen_for_player(player)

func _mark_radius(player: Dictionary, origin: Vector2i, radius: int) -> void:
	for y in range(max(0, origin.y - radius), min(height, origin.y + radius + 1)):
		for x in range(max(0, origin.x - radius), min(width, origin.x + radius + 1)):
			var pos = Vector2i(x, y)
			if _distance(origin, pos) <= float(radius):
				_mark_visible(player, pos)

func _mark_visible(player: Dictionary, pos: Vector2i) -> void:
	var key = "%d,%d" % [pos.x, pos.y]
	player["visible"][key] = true
	player["explored"][key] = true

func is_visible(pid: int, pos: Vector2i) -> bool:
	if not fog_enabled:
		return true
	if pid < 0 or pid >= players.size():
		return true
	return players[pid].get("visible", {}).has("%d,%d" % [pos.x, pos.y])

func is_explored(pid: int, pos: Vector2i) -> bool:
	if not fog_enabled:
		return true
	if pid < 0 or pid >= players.size():
		return true
	return players[pid].get("explored", {}).has("%d,%d" % [pos.x, pos.y])

func building_memory_for(pid: int, pos: Vector2i) -> Dictionary:
	if pid < 0 or pid >= players.size():
		return {}
	return Dictionary(players[pid].get("last_seen", {}).get("%d,%d" % [pos.x, pos.y], {}))

func _update_last_seen_for_player(player: Dictionary) -> void:
	var memory: Dictionary = player.get("last_seen", {})
	for building in buildings:
		var pos: Vector2i = building["pos"]
		var key = "%d,%d" % [pos.x, pos.y]
		if not player["visible"].has(key):
			continue
		if int(building.get("pid", -1)) == int(player["id"]):
			continue
		memory[key] = {
			"type": building.get("type", ""),
			"pid": int(building.get("pid", -1)),
			"hp": float(building.get("hp", 0.0)),
			"max_hp": float(building.get("max_hp", 0.0)),
			"armor": float(building.get("armor", 0.0)),
			"tier": int(building.get("tier", 0)),
			"outpost_tier": int(building.get("outpost_tier", 0)),
			"outpost_branch": str(building.get("outpost_branch", "")),
			"gold": float(building.get("gold", 0.0)),
			"turn": turn
		}
	var visible_keys: Array = player["visible"].keys()
	for key in visible_keys:
		var parts = key.split(",")
		var pos = Vector2i(int(parts[0]), int(parts[1]))
		if building_at(pos).is_empty() and memory.has(key):
			memory.erase(key)
	player["last_seen"] = memory

func to_dict() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"turn": turn,
		"current_player": current_player,
		"next_unit_id": next_unit_id,
		"next_building_id": next_building_id,
		"player_count": player_count,
		"terrain_grid": terrain_grid.duplicate(true),
		"players": players.duplicate(true),
		"units": _pack_entities(units),
		"buildings": _pack_entities(buildings),
		"game_over": game_over,
		"winner": winner,
		"last_event": last_event,
		"fog_enabled": fog_enabled
	}

func load_from_dict(data: Dictionary) -> void:
	width = int(data.get("width", width))
	height = int(data.get("height", height))
	turn = int(data.get("turn", 1))
	current_player = int(data.get("current_player", 0))
	next_unit_id = int(data.get("next_unit_id", 1))
	next_building_id = int(data.get("next_building_id", 1))
	player_count = int(data.get("player_count", 2))
	fog_enabled = bool(data.get("fog_enabled", true))
	terrain_grid = []
	for row in data.get("terrain_grid", []):
		terrain_grid.append(Array(row))
	players = []
	for player in data.get("players", []):
		var unpacked_player = Dictionary(player)
		if not unpacked_player.has("researching"):
			unpacked_player["researching"] = []
		if not unpacked_player.has("equipment"):
			unpacked_player["equipment"] = []
		if not unpacked_player.has("strategic"):
			unpacked_player["strategic"] = []
		if not unpacked_player.has("alive"):
			unpacked_player["alive"] = true
		players.append(unpacked_player)
	units = _unpack_entities(data.get("units", []))
	buildings = _unpack_entities(data.get("buildings", []))
	for unit in units:
		if not unit.has("equip"):
			unit["equip"] = ""
		if not unit.has("applied_equipment"):
			unit["applied_equipment"] = []
	for building in buildings:
		if not building.has("turns_since_damage"):
			building["turns_since_damage"] = 0
		if not building.has("damaged_this_turn"):
			building["damaged_this_turn"] = false
	game_over = bool(data.get("game_over", false))
	winner = int(data.get("winner", -1))
	last_event = str(data.get("last_event", ""))
	update_vision()

func _pack_entities(source: Array) -> Array:
	var result = []
	for item in source:
		var packed = Dictionary(item).duplicate(true)
		if packed.has("pos"):
			var pos: Vector2i = packed["pos"]
			packed["pos"] = [pos.x, pos.y]
		result.append(packed)
	return result

func _unpack_entities(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in source:
		var unpacked = Dictionary(item)
		if unpacked.has("pos") and unpacked["pos"] is Array:
			var pos = unpacked["pos"]
			unpacked["pos"] = Vector2i(int(pos[0]), int(pos[1]))
		result.append(unpacked)
	return result

func _check_victory() -> void:
	var alive_hq = {}
	for building in buildings:
		var pid = int(building["pid"])
		if building["type"] == "大本营" and pid >= 0 and bool(players[pid].get("alive", true)):
			alive_hq[int(building["pid"])] = true
	if alive_hq.size() == 1:
		game_over = true
		winner = int(alive_hq.keys()[0])

func _distance(a: Vector2i, b: Vector2i) -> float:
	return a.distance_to(b)

