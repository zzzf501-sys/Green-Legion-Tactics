extends RefCounted
class_name TacticalAI

var db

func setup(database) -> void:
	db = database

func take_turn(state, pid: int) -> Dictionary:
	var report = {
		"produced": 0,
		"moved": 0,
		"attacked": 0,
		"developed": 0
	}
	if db == null or state.game_over or state.current_player != pid:
		return report
	_develop(state, pid, report)
	_equip_available_units(state, pid, report)
	var unit_ids: Array[int] = []
	for unit in state.units:
		if int(unit.get("pid", -1)) == pid:
			unit_ids.append(int(unit["id"]))
	unit_ids.sort()
	for unit_id in unit_ids:
		if state.game_over:
			break
		_run_unit(state, pid, unit_id, report)
	return report

func _develop(state, pid: int, report: Dictionary) -> void:
	var hq = _owned_hq(state, pid)
	if hq.is_empty():
		return
	_ensure_minimum_force(state, pid, hq, report)
	if state.can_upgrade_hq(hq) and state.upgrade_hq(int(hq["id"])):
		report["developed"] += 1
	_build_collector(state, pid, hq, report)
	_upgrade_owned_outpost(state, pid, hq["pos"], report)
	_research_useful_technology(state, pid, report)
	_produce_army(state, pid, report)

func _ensure_minimum_force(state, pid: int, hq: Dictionary, report: Dictionary) -> void:
	var unit_count = _owned_units(state, pid).size()
	while unit_count < 2 and state.can_produce(hq, "士兵"):
		if not state.produce_unit(int(hq["id"]), "士兵"):
			break
		unit_count += 1
		report["produced"] += 1

func _build_collector(state, pid: int, hq: Dictionary, report: Dictionary) -> void:
	var collector_count = 0
	for building in state.buildings:
		if int(building.get("pid", -1)) == pid and str(building.get("type", "")) == "资源采集器":
			collector_count += 1
	var desired = mini(2, int(state.players[pid].get("tier", 1)))
	if collector_count >= desired or float(state.players[pid].get("gold", 0.0)) < 10.0:
		return
	var choices = state.collector_build_tiles(hq)
	if choices.is_empty():
		return
	var enemy_hq = _nearest_enemy_hq(state, pid, hq["pos"])
	var best = choices[0]
	var best_score = -INF
	for pos in choices:
		var score = _distance(pos, enemy_hq) - _distance(pos, hq["pos"]) * 0.1
		if score > best_score:
			best_score = score
			best = pos
	if state.build_collector(int(hq["id"]), best):
		report["developed"] += 1

func _upgrade_owned_outpost(state, pid: int, hq_pos: Vector2i, report: Dictionary) -> void:
	if int(state.players[pid].get("tier", 1)) < 2 or float(state.players[pid].get("gold", 0.0)) < 14.0:
		return
	var enemy_hq = _nearest_enemy_hq(state, pid, hq_pos)
	var candidates: Array[Dictionary] = []
	for building in state.buildings:
		if int(building.get("pid", -1)) == pid and str(building.get("type", "")) == "据点" and int(building.get("outpost_tier", 0)) <= 0:
			candidates.append(building)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return _distance(a["pos"], enemy_hq) < _distance(b["pos"], enemy_hq))
	var outpost = candidates[0]
	var branch = "combat" if _distance(outpost["pos"], enemy_hq) < _distance(outpost["pos"], hq_pos) else "economic"
	if state.upgrade_outpost(int(outpost["id"]), branch):
		report["developed"] += 1

func _research_useful_technology(state, pid: int, report: Dictionary) -> void:
	var gold = float(state.players[pid].get("gold", 0.0))
	if int(state.players[pid].get("tier", 1)) >= 3 and gold >= 36.0 and state.can_research_strategic(pid, "SpaceX 星链计划"):
		if state.research_strategic(pid, "SpaceX 星链计划"):
			report["developed"] += 1
			return
	var priorities = [
		["士兵", "射手步枪"],
		["军用吉普", "重甲吉普"],
		["野战炮", "轻量化"],
		["坦克", "高爆炮"],
		["士兵", "反器械枪"],
		["火箭炮", "对空雷达"],
		["坦克", "穿甲炮"],
		["野战炮", "巨炮"]
	]
	for item in priorities:
		var equip = state.equipment_data(str(item[0]), str(item[1]))
		var reserve = float(equip.get("research_cost", 0.0)) + 5.0
		if float(state.players[pid].get("gold", 0.0)) >= reserve and state.can_research_equipment(pid, str(item[0]), str(item[1])):
			if state.research_equipment(pid, str(item[0]), str(item[1])):
				report["developed"] += 1
			return

func _equip_available_units(state, pid: int, report: Dictionary) -> void:
	for unit in state.units.duplicate():
		if int(unit.get("pid", -1)) != pid or not str(unit.get("equip", "")).is_empty():
			continue
		for equip in db.equipment_for(str(unit.get("type", ""))):
			var equip_name = str(equip.get("name", ""))
			if state.can_equip_unit(unit, equip_name) and float(state.players[pid].get("gold", 0.0)) >= float(equip.get("cost", 0.0)) + 2.0:
				if state.equip_unit(int(unit["id"]), equip_name):
					report["developed"] += 1
				break

func _produce_army(state, pid: int, report: Dictionary) -> void:
	var tier = int(state.players[pid].get("tier", 1))
	var cap = 4 + tier * 4
	var owned = _owned_units(state, pid)
	if owned.size() >= cap:
		return
	var producers: Array[Dictionary] = []
	for building in state.buildings:
		if int(building.get("pid", -1)) == pid and ["大本营", "据点"].has(str(building.get("type", ""))):
			producers.append(building)
	for building in producers:
		if _owned_units(state, pid).size() >= cap:
			break
		var unit_type = _choose_unit_to_produce(state, pid, building)
		if not unit_type.is_empty() and state.produce_unit(int(building["id"]), unit_type):
			report["produced"] += 1

func _choose_unit_to_produce(state, pid: int, building: Dictionary) -> String:
	var available = state.available_units_for_player(pid)
	var counts = {}
	for unit in state.units:
		if int(unit.get("pid", -1)) == pid:
			var key = str(unit.get("type", ""))
			counts[key] = int(counts.get(key, 0)) + 1
	var enemy_air = 0
	for unit in state.units:
		if int(unit.get("pid", -1)) != pid and state.is_visible(pid, unit["pos"]) and bool(unit.get("is_air", false)):
			enemy_air += 1
	var desired = {
		"士兵": 3, "军用吉普": 2, "装甲车": 2, "坦克": 3,
		"野战炮": 2, "自杀无人机": 2, "侦察机": 1,
		"火箭炮": 2, "战斗机": 2, "轰炸机": 1, "防空车": 2
	}
	var best = ""
	var best_score = -INF
	for raw_type in available:
		var unit_type = str(raw_type)
		if not state.can_produce(building, unit_type):
			continue
		var data = db.unit_data(unit_type)
		var count = int(counts.get(unit_type, 0))
		var score = float(int(desired.get(unit_type, 1)) - count) * 10.0
		score += (float(data.get("damage", 0.0)) * float(data.get("attacks", 1)) + float(data.get("hp", 0.0))) / max(1.0, float(data.get("price", 1.0)))
		if enemy_air > 0 and unit_type in ["防空车", "战斗机", "装甲车"]:
			score += 30.0
		if unit_type == "侦察机" and count >= 1:
			score -= 100.0
		if score > best_score:
			best_score = score
			best = unit_type
	return best

func _run_unit(state, pid: int, unit_id: int, report: Dictionary) -> void:
	var unit = state.get_unit_by_id(unit_id)
	if unit.is_empty() or int(unit.get("pid", -1)) != pid or bool(unit.get("done", false)):
		return
	if _attack_best_target(state, unit_id):
		report["attacked"] += 1
		return
	unit = state.get_unit_by_id(unit_id)
	if unit.is_empty() or bool(unit.get("moved", false)):
		return
	var objective = _choose_objective(state, pid, unit)
	if objective.x < 0:
		return
	var move_target = _choose_move_tile(state, unit, objective)
	if move_target.x >= 0 and state.move_unit(unit_id, move_target):
		report["moved"] += 1
	while not state.game_over and _attack_best_target(state, unit_id):
		report["attacked"] += 1

func _attack_best_target(state, unit_id: int) -> bool:
	var unit = state.get_unit_by_id(unit_id)
	if unit.is_empty():
		return false
	var targets = state.attack_targets_for(unit)
	var best = Vector2i(-1, -1)
	var best_score = -INF
	for pos in targets:
		var target = state.occupant_at(pos)
		if target.is_empty():
			continue
		var damage = float(unit.get("air_damage", unit.get("damage", 0.0))) if bool(target.get("is_air", false)) else float(unit.get("damage", 0.0))
		var dealt = max(0.0, damage - float(target.get("armor", 0.0)))
		var score = dealt * 100.0 - float(target.get("hp", 0.0))
		if float(target.get("hp", 0.0)) <= dealt:
			score += 5000.0
		if target.has("speed"):
			score += float(db.unit_data(str(target.get("type", ""))).get("price", 0.0)) * 80.0
		elif str(target.get("type", "")) == "大本营":
			score += 3000.0
		if score > best_score:
			best_score = score
			best = pos
	return best.x >= 0 and state.attack(unit_id, best)

func _choose_objective(state, pid: int, unit: Dictionary) -> Vector2i:
	var origin: Vector2i = unit["pos"]
	var best = Vector2i(-1, -1)
	var best_score = INF
	for enemy in state.units:
		if int(enemy.get("pid", -1)) == pid or not state.is_visible(pid, enemy["pos"]):
			continue
		var score = _distance(origin, enemy["pos"]) - float(db.unit_data(str(enemy.get("type", ""))).get("price", 0.0)) * 0.05
		if score < best_score:
			best_score = score
			best = enemy["pos"]
	for building in state.buildings:
		var owner = int(building.get("pid", -1))
		if owner == pid:
			continue
		if owner >= 0 and str(building.get("type", "")) != "大本营" and not state.is_explored(pid, building["pos"]):
			continue
		var score = _distance(origin, building["pos"])
		if owner < 0:
			score -= 5.0
		elif str(building.get("type", "")) == "大本营":
			score += 3.0
		if score < best_score:
			best_score = score
			best = building["pos"]
	return best

func _choose_move_tile(state, unit: Dictionary, objective: Vector2i) -> Vector2i:
	var choices = state.move_tiles_for(unit)
	if choices.is_empty():
		return Vector2i(-1, -1)
	var current_score = _distance(unit["pos"], objective)
	var best = Vector2i(-1, -1)
	var best_score = current_score
	for pos in choices:
		var score = _distance(pos, objective)
		if not bool(unit.get("is_air", false)):
			score -= float(state.terrain_height(pos)) * 0.08
		if score < best_score:
			best_score = score
			best = pos
	return best

func _owned_hq(state, pid: int) -> Dictionary:
	for building in state.buildings:
		if int(building.get("pid", -1)) == pid and str(building.get("type", "")) == "大本营":
			return building
	return {}

func _owned_units(state, pid: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit in state.units:
		if int(unit.get("pid", -1)) == pid:
			result.append(unit)
	return result

func _nearest_enemy_hq(state, pid: int, origin: Vector2i) -> Vector2i:
	var best = Vector2i(int(state.width / 2), int(state.height / 2))
	var best_distance = INF
	for building in state.buildings:
		if int(building.get("pid", -1)) == pid or str(building.get("type", "")) != "大本营":
			continue
		var distance = _distance(origin, building["pos"])
		if distance < best_distance:
			best_distance = distance
			best = building["pos"]
	return best

func _distance(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b))
