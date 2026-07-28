extends RefCounted
class_name TacticalAI

const ERA_OPEN_ROUNDS = {1: 1, 2: 14, 3: 28, 4: 43, 5: 59}
const ERA_CAPACITY = {1: 22, 2: 24, 3: 26, 4: 28, 5: 30}
const ROLE_FRONTLINE = "frontline"
const ROLE_MOBILE = "mobile"
const ROLE_FIREPOWER = "firepower"
const ROLE_SUPPORT = "support"
const ROLE_ORDER = [ROLE_FRONTLINE, ROLE_MOBILE, ROLE_FIREPOWER, ROLE_SUPPORT]
const UNIT_ROLES = {
	"战团": ROLE_FRONTLINE, "方阵": ROLE_FRONTLINE, "火枪连": ROLE_FRONTLINE, "士兵": ROLE_FRONTLINE, "网络化步兵": ROLE_FRONTLINE,
	"斥候": ROLE_MOBILE, "骑兵": ROLE_MOBILE, "龙骑兵": ROLE_MOBILE, "主战坦克": ROLE_MOBILE, "坦克": ROLE_MOBILE, "无人战车": ROLE_MOBILE,
	"投石队": ROLE_FIREPOWER, "弓弩/投石车": ROLE_FIREPOWER, "野战炮": ROLE_FIREPOWER, "自行火炮": ROLE_FIREPOWER, "精确火箭": ROLE_FIREPOWER,
	"部落侦察": ROLE_SUPPORT, "轻骑侦察": ROLE_SUPPORT, "工兵/观测队": ROLE_SUPPORT, "军用吉普": ROLE_SUPPORT, "吉普": ROLE_SUPPORT, "无人机/电子战": ROLE_SUPPORT
}
const UNIT_ERAS = {
	"战团": 1, "斥候": 1, "投石队": 1, "部落侦察": 1,
	"方阵": 2, "骑兵": 2, "弓弩/投石车": 2, "轻骑侦察": 2,
	"火枪连": 3, "龙骑兵": 3, "野战炮": 3, "工兵/观测队": 3,
	"士兵": 4, "主战坦克": 4, "坦克": 4, "自行火炮": 4, "军用吉普": 4, "吉普": 4,
	"网络化步兵": 5, "无人战车": 5, "精确火箭": 5, "无人机/电子战": 5
}

var db

func setup(database) -> void:
	db = database

func take_turn(state, pid: int) -> Dictionary:
	var report = {"produced": 0, "moved": 0, "attacked": 0, "developed": 0}
	if db == null or state.game_over or state.current_player != pid:
		return report
	_develop(state, pid, report)
	_equip_available_units(state, pid, report)
	var unit_ids: Array[int] = []
	for unit in state.units:
		if int(unit.get("pid", -1)) == pid:
			unit_ids.append(int(unit["id"]))
	unit_ids.sort_custom(func(a: int, b: int): return _unit_action_priority(state.get_unit_by_id(a)) > _unit_action_priority(state.get_unit_by_id(b)))
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
	_try_era_upgrade(state, pid, hq, report)
	var reserve = _era_upgrade_reserve(state, pid, hq)
	_build_collector(state, pid, hq, reserve, report)
	_upgrade_owned_outpost(state, pid, hq["pos"], reserve, report)
	_research_useful_technology(state, pid, reserve, report)
	_produce_army(state, pid, reserve, report)

func _ensure_minimum_force(state, pid: int, hq: Dictionary, report: Dictionary) -> void:
	var unit_count = _owned_units(state, pid).size()
	while unit_count < 2:
		var unit_type = _best_available_type_for_role(state, pid, hq, ROLE_FRONTLINE)
		if unit_type.is_empty() or not state.produce_unit(int(hq["id"]), unit_type):
			break
		unit_count += 1
		report["produced"] += 1

func _try_era_upgrade(state, pid: int, hq: Dictionary, report: Dictionary) -> void:
	var next_era = _player_era(state, pid) + 1
	if next_era > 5 or not _era_upgrade_window_open(state, next_era):
		return
	if state.has_method("can_upgrade_era") and state.has_method("upgrade_era"):
		if bool(state.call("can_upgrade_era", pid)) and bool(state.call("upgrade_era", pid)):
			report["developed"] += 1
		return
	if state.has_method("can_upgrade_hq") and state.has_method("upgrade_hq"):
		if bool(state.call("can_upgrade_hq", hq)) and bool(state.call("upgrade_hq", int(hq["id"]))):
			report["developed"] += 1

func _era_upgrade_window_open(state, next_era: int) -> bool:
	if not _uses_five_era_rules():
		return true
	return int(state.turn) >= int(ERA_OPEN_ROUNDS.get(next_era, 999)) - 1

func _era_upgrade_reserve(state, pid: int, hq: Dictionary) -> float:
	var next_era = _player_era(state, pid) + 1
	if next_era > 5:
		return 0.0
	if _uses_five_era_rules() and int(state.turn) < int(ERA_OPEN_ROUNDS.get(next_era, 999)) - 2:
		return 0.0
	var data: Dictionary = db.building_data("大本营")
	var tiers = data.get("tiers", [])
	var tier_index = int(hq.get("tier", max(0, _player_era(state, pid) - 1)))
	if tier_index >= 0 and tier_index < tiers.size():
		return float(tiers[tier_index].get("upgrade_cost", 0.0))
	return 0.0

func _build_collector(state, pid: int, hq: Dictionary, reserve: float, report: Dictionary) -> void:
	var collector_count = 0
	for building in state.buildings:
		if int(building.get("pid", -1)) == pid and str(building.get("type", "")) == "资源采集器":
			collector_count += 1
	var desired = mini(2, _player_era(state, pid))
	var cost = float(db.building_data("资源采集器").get("cost", 12.0))
	if collector_count >= desired or float(state.players[pid].get("gold", 0.0)) < cost + reserve:
		return
	var choices = state.collector_build_tiles(hq)
	if choices.is_empty():
		return
	var enemy_hq = _nearest_known_enemy_hq(state, pid, hq["pos"])
	var best = choices[0]
	var best_score = -INF
	for pos in choices:
		var score = _distance(pos, enemy_hq) - _distance(pos, hq["pos"]) * 0.1 if enemy_hq.x >= 0 else -_distance(pos, hq["pos"])
		if score > best_score:
			best_score = score
			best = pos
	if state.build_collector(int(hq["id"]), best):
		report["developed"] += 1

func _upgrade_owned_outpost(state, pid: int, hq_pos: Vector2i, reserve: float, report: Dictionary) -> void:
	if _player_era(state, pid) < 2 or float(state.players[pid].get("gold", 0.0)) < reserve + 10.0:
		return
	var enemy_hq = _nearest_known_enemy_hq(state, pid, hq_pos)
	var candidates: Array[Dictionary] = []
	for building in state.buildings:
		if int(building.get("pid", -1)) == pid and str(building.get("type", "")) == "据点" and int(building.get("outpost_tier", 0)) <= 0 and not bool(building.get("upgrading", false)):
			candidates.append(building)
	if candidates.is_empty():
		return
	if enemy_hq.x >= 0:
		candidates.sort_custom(func(a: Dictionary, b: Dictionary): return _distance(a["pos"], enemy_hq) < _distance(b["pos"], enemy_hq))
	var outpost = candidates[0]
	var branch = "combat" if enemy_hq.x >= 0 and _distance(outpost["pos"], enemy_hq) < _distance(outpost["pos"], hq_pos) else "economic"
	if state.upgrade_outpost(int(outpost["id"]), branch):
		report["developed"] += 1

func _research_useful_technology(state, pid: int, reserve: float, report: Dictionary) -> void:
	var gold = float(state.players[pid].get("gold", 0.0))
	var current_era = _player_era(state, pid)
	if _try_core_research(state, pid, reserve, report):
		return
	if current_era >= 5:
		for tech_name in db.strategic_techs.keys():
			var tech: Dictionary = db.strategic_techs[tech_name]
			var cost = float(tech.get("cost", 0.0))
			if gold >= cost + reserve and state.can_research_strategic(pid, str(tech_name)):
				if state.research_strategic(pid, str(tech_name)):
					report["developed"] += 1
				return
	var priorities = _equipment_research_priorities(state, pid)
	for item in priorities:
		var equip = state.equipment_data(str(item[0]), str(item[1]))
		var cost = float(equip.get("research_cost", 0.0))
		if gold >= cost + reserve and state.can_research_equipment(pid, str(item[0]), str(item[1])):
			if state.research_equipment(pid, str(item[0]), str(item[1])):
				report["developed"] += 1
			return

func _try_core_research(state, pid: int, reserve: float, report: Dictionary) -> bool:
	var can_method = ""
	var research_method = ""
	for pair in [["can_research_technology", "research_technology"], ["can_research_core", "research_core"]]:
		if state.has_method(pair[0]) and state.has_method(pair[1]):
			can_method = pair[0]
			research_method = pair[1]
			break
	if can_method.is_empty():
		return false
	var scored: Array[Dictionary] = []
	var technology_table: Dictionary = db.technologies if not db.technologies.is_empty() else db.techs
	for tech_id in technology_table.keys():
		var tech: Dictionary = technology_table[tech_id]
		var era = _era_number(tech.get("era", tech.get("tier", 1)))
		var cost = float(tech.get("cost", tech.get("research_cost", 0.0)))
		if era > _player_era(state, pid) or float(state.players[pid].get("gold", 0.0)) < cost + reserve:
			continue
		var score = float(era) * 20.0 + float(tech.get("unlocks", []).size()) * 5.0
		scored.append({"id": str(tech_id), "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["score"]) > float(b["score"]))
	for candidate in scored:
		if bool(state.call(can_method, pid, candidate["id"])) and bool(state.call(research_method, pid, candidate["id"])):
			report["developed"] += 1
			return true
	return false

func _equipment_research_priorities(state, pid: int) -> Array:
	var visible_enemy_roles = _visible_enemy_role_counts(state, pid)
	var scored: Array[Dictionary] = []
	for unit_type in db.equipment.keys():
		for equip in db.equipment_for(str(unit_type)):
			var era = int(equip.get("era", equip.get("tier", _unit_era(str(unit_type)))))
			if era > _player_era(state, pid):
				continue
			var role = _role_for_type(str(unit_type))
			var score = float(era) * 10.0
			score += float(equip.get("dmg", equip.get("damage", 0.0))) * 2.0
			score += float(equip.get("range", 0.0))
			if role == ROLE_FRONTLINE and int(visible_enemy_roles.get(ROLE_MOBILE, 0)) > 0:
				score += 18.0
			elif role == ROLE_MOBILE and int(visible_enemy_roles.get(ROLE_FIREPOWER, 0)) > 0:
				score += 14.0
			elif role == ROLE_FIREPOWER and int(visible_enemy_roles.get(ROLE_FRONTLINE, 0)) > 0:
				score += 12.0
			scored.append({"unit": str(unit_type), "equip": str(equip.get("name", "")), "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["score"]) > float(b["score"]))
	var result = []
	for entry in scored:
		result.append([entry["unit"], entry["equip"]])
	return result

func _equip_available_units(state, pid: int, report: Dictionary) -> void:
	var reserve = _era_upgrade_reserve(state, pid, _owned_hq(state, pid))
	for unit in state.units.duplicate():
		if int(unit.get("pid", -1)) != pid or not str(unit.get("equip", "")).is_empty():
			continue
		var choices: Array[Dictionary] = []
		for equip in db.equipment_for(str(unit.get("type", ""))):
			if state.can_equip_unit(unit, str(equip.get("name", ""))):
				choices.append(equip)
		choices.sort_custom(func(a: Dictionary, b: Dictionary): return _equipment_value(a) > _equipment_value(b))
		for equip in choices:
			var cost = max(0.0, float(equip.get("cost", 0.0)))
			if float(state.players[pid].get("gold", 0.0)) < cost + reserve:
				continue
			if state.equip_unit(int(unit["id"]), str(equip.get("name", ""))):
				report["developed"] += 1
			break

func _equipment_value(equip: Dictionary) -> float:
	return float(equip.get("dmg", equip.get("damage", 0.0))) * 3.0 + float(equip.get("armor", 0.0)) * 4.0 + float(equip.get("range", 0.0)) * 1.5 + float(equip.get("speed", 0.0)) + float(equip.get("hp", 0.0))

func _produce_army(state, pid: int, reserve: float, report: Dictionary) -> void:
	if _capacity_usage(state, pid) >= _capacity_limit(state, pid):
		return
	var producers: Array[Dictionary] = []
	for building in state.buildings:
		if int(building.get("pid", -1)) == pid and ["大本营", "据点"].has(str(building.get("type", ""))):
			producers.append(building)
	for building in producers:
		if _capacity_usage(state, pid) >= _capacity_limit(state, pid):
			break
		var unit_type = _choose_unit_to_produce(state, pid, building, reserve)
		if not unit_type.is_empty() and state.produce_unit(int(building["id"]), unit_type):
			report["produced"] += 1

func _choose_unit_to_produce(state, pid: int, building: Dictionary, reserve: float = 0.0) -> String:
	var available = state.available_units_for_player(pid)
	var role_counts = _owned_role_capacity(state, pid)
	var enemy_roles = _visible_enemy_role_counts(state, pid)
	var total_capacity = max(1.0, _capacity_usage(state, pid))
	var desired_ratios = {ROLE_FRONTLINE: 0.40, ROLE_MOBILE: 0.25, ROLE_FIREPOWER: 0.25, ROLE_SUPPORT: 0.10}
	var best = ""
	var best_score = -INF
	for raw_type in available:
		var unit_type = str(raw_type)
		if not state.can_produce(building, unit_type):
			continue
		var data: Dictionary = db.unit_data(unit_type)
		var price = float(data.get("price", 0.0))
		if float(state.players[pid].get("gold", 0.0)) < price + reserve and _owned_units(state, pid).size() >= 2:
			continue
		var capacity_cost = _capacity_cost_for_type(unit_type)
		if _capacity_usage(state, pid) + capacity_cost > _capacity_limit(state, pid):
			continue
		var role = _role_for_type(unit_type)
		var current_ratio = float(role_counts.get(role, 0.0)) / total_capacity
		var score = (float(desired_ratios.get(role, 0.15)) - current_ratio) * 100.0
		score += float(_unit_era(unit_type)) * 8.0
		score += _counter_role_score(role, enemy_roles)
		score += (float(data.get("damage", 0.0)) * max(1.0, float(data.get("attacks", 1))) + float(data.get("hp", 0.0)) * 0.35 + float(data.get("armor", 0.0)) * 2.0) / max(1.0, price)
		if role == ROLE_SUPPORT and int(role_counts.get(ROLE_SUPPORT, 0)) >= 2:
			score -= 20.0
		if score > best_score:
			best_score = score
			best = unit_type
	return best

func _counter_role_score(role: String, enemy_roles: Dictionary) -> float:
	if role == ROLE_FRONTLINE:
		return float(enemy_roles.get(ROLE_MOBILE, 0)) * 10.0
	if role == ROLE_MOBILE:
		return float(enemy_roles.get(ROLE_FIREPOWER, 0)) * 12.0 + float(enemy_roles.get(ROLE_SUPPORT, 0)) * 8.0
	if role == ROLE_FIREPOWER:
		return float(enemy_roles.get(ROLE_FRONTLINE, 0)) * 10.0
	return float(enemy_roles.get(ROLE_FIREPOWER, 0)) * 2.0

func _run_unit(state, pid: int, unit_id: int, report: Dictionary) -> void:
	var unit = state.get_unit_by_id(unit_id)
	if unit.is_empty() or int(unit.get("pid", -1)) != pid or bool(unit.get("done", false)) or int(unit.get("rl", unit.get("reload_left", 0))) > 0:
		return
	while _attack_best_target(state, unit_id):
		report["attacked"] += 1
		unit = state.get_unit_by_id(unit_id)
		if unit.is_empty() or bool(unit.get("done", false)):
			return
	unit = state.get_unit_by_id(unit_id)
	if unit.is_empty() or bool(unit.get("moved", false)):
		return
	var objective = _choose_objective(state, pid, unit)
	if objective.x < 0:
		return
	var move_target = _choose_move_tile(state, pid, unit, objective)
	if move_target.x >= 0 and state.move_unit(unit_id, move_target):
		report["moved"] += 1
	while not state.game_over and _attack_best_target(state, unit_id):
		report["attacked"] += 1

func _attack_best_target(state, unit_id: int) -> bool:
	var unit = state.get_unit_by_id(unit_id)
	if unit.is_empty():
		return false
	var role = _role_for_type(str(unit.get("type", "")))
	var best = Vector2i(-1, -1)
	var best_score = -INF
	for pos in state.attack_targets_for(unit):
		var target = state.occupant_at(pos)
		if target.is_empty():
			continue
		var dealt = _estimated_damage(state, unit, target)
		if dealt <= 0.0:
			continue
		var score = dealt * 100.0 - float(target.get("hp", 0.0))
		if float(target.get("hp", 0.0)) <= dealt:
			score += 5000.0
		if target.has("speed"):
			var target_role = _role_for_type(str(target.get("type", "")))
			score += float(db.unit_data(str(target.get("type", ""))).get("price", 0.0)) * 80.0
			if role == ROLE_MOBILE and target_role in [ROLE_FIREPOWER, ROLE_SUPPORT]:
				score += 1800.0
			elif role == ROLE_FRONTLINE and target_role == ROLE_MOBILE:
				score += 900.0
			elif role == ROLE_FIREPOWER and target_role == ROLE_FRONTLINE:
				score += 700.0
		else:
			score += 3000.0 if str(target.get("type", "")) == "大本营" else 300.0
		if score > best_score:
			best_score = score
			best = pos
	return best.x >= 0 and state.attack(unit_id, best)

func _estimated_damage(state, unit: Dictionary, target: Dictionary) -> float:
	if state.has_method("_effective_attack_damage"):
		return max(0.0, float(state.call("_effective_attack_damage", unit, target, false)))
	for method_name in ["effective_damage_against", "estimated_damage", "damage_against"]:
		if state.has_method(method_name):
			return max(0.0, float(state.call(method_name, unit, target)))
	var raw = float(unit.get("air_damage", unit.get("damage", 0.0))) if bool(target.get("is_air", false)) else float(unit.get("damage", 0.0))
	if state.has_method("_unit_damage_against"):
		raw = float(state.call("_unit_damage_against", unit, target))
	return max(0.0, raw - float(target.get("armor", 0.0)))

func _choose_objective(state, pid: int, unit: Dictionary) -> Vector2i:
	var origin: Vector2i = unit["pos"]
	var role = _role_for_type(str(unit.get("type", "")))
	var best = Vector2i(-1, -1)
	var best_score = INF
	for enemy in state.units:
		if int(enemy.get("pid", -1)) == pid or not state.is_visible(pid, enemy["pos"]):
			continue
		var enemy_role = _role_for_type(str(enemy.get("type", "")))
		var score = _distance(origin, enemy["pos"]) - float(db.unit_data(str(enemy.get("type", ""))).get("price", 0.0)) * 0.05
		if role == ROLE_MOBILE and enemy_role in [ROLE_FIREPOWER, ROLE_SUPPORT]:
			score -= 8.0
		if role == ROLE_FRONTLINE and enemy_role == ROLE_MOBILE:
			score -= 4.0
		if role == ROLE_FIREPOWER and enemy_role == ROLE_FRONTLINE:
			score -= 3.0
		if score < best_score:
			best_score = score
			best = enemy["pos"]
	for building in state.buildings:
		var owner = int(building.get("pid", -1))
		if owner == pid or not state.is_explored(pid, building["pos"]):
			continue
		var score = _distance(origin, building["pos"])
		if owner < 0:
			score -= 5.0
		elif str(building.get("type", "")) == "大本营":
			score -= 2.0 if role == ROLE_FIREPOWER else -3.0
		if score < best_score:
			best_score = score
			best = building["pos"]
	if best.x < 0:
		best = _exploration_objective(state, pid, origin)
	return best

func _exploration_objective(state, pid: int, origin: Vector2i) -> Vector2i:
	var center = Vector2i(int(state.width / 2), int(state.height / 2))
	var best = center
	var best_score = INF
	var stride = maxi(3, int(min(state.width, state.height) / 8))
	for y in range(int(stride / 2), state.height, stride):
		for x in range(int(stride / 2), state.width, stride):
			var pos = Vector2i(x, y)
			if state.is_explored(pid, pos):
				continue
			var score = _distance(origin, pos) + _distance(pos, center) * 0.15
			if score < best_score:
				best_score = score
				best = pos
	return best

func _choose_move_tile(state, pid: int, unit: Dictionary, objective: Vector2i) -> Vector2i:
	var choices = state.move_tiles_for(unit)
	if choices.is_empty():
		return Vector2i(-1, -1)
	var role = _role_for_type(str(unit.get("type", "")))
	var target = state.occupant_at(objective)
	var desired_range = max(1.0, float(unit.get("range", 1.0)) * (0.75 if role == ROLE_FIREPOWER else 0.20))
	var threats: Array[Vector2i] = state.threat_tiles_against(pid) if state.has_method("threat_tiles_against") else []
	var current_score = _movement_score(state, pid, unit, unit["pos"], objective, target, role, desired_range, threats)
	var best = Vector2i(-1, -1)
	var best_score = current_score
	for pos in choices:
		var score = _movement_score(state, pid, unit, pos, objective, target, role, desired_range, threats)
		if score < best_score:
			best_score = score
			best = pos
	return best

func _movement_score(state, pid: int, unit: Dictionary, pos: Vector2i, objective: Vector2i, target: Dictionary, role: String, desired_range: float, threats: Array[Vector2i]) -> float:
	var distance = _distance(pos, objective)
	var score = abs(distance - desired_range) if role == ROLE_FIREPOWER else distance
	if not bool(unit.get("is_air", false)):
		score -= float(state.terrain_height(pos)) * (0.35 if role == ROLE_FIREPOWER else 0.08)
	if role in [ROLE_FIREPOWER, ROLE_SUPPORT] and threats.has(pos):
		score += 8.0
	if role == ROLE_MOBILE:
		score += float(_enemy_neighbors(state, pid, pos)) * 1.5
		if not target.is_empty() and _role_for_type(str(target.get("type", ""))) in [ROLE_FIREPOWER, ROLE_SUPPORT]:
			score -= 2.5
	if role == ROLE_SUPPORT:
		var ally_distance = _nearest_allied_combat_distance(state, pid, pos, int(unit.get("id", -1)))
		score += abs(ally_distance - 2.0) * 0.6
	return score

func _unit_action_priority(unit: Dictionary) -> float:
	var role = _role_for_type(str(unit.get("type", "")))
	if role == ROLE_SUPPORT:
		return 4.0
	if role == ROLE_FIREPOWER:
		return 3.0
	if role == ROLE_FRONTLINE:
		return 2.0
	return 1.0

func _player_era(state, pid: int) -> int:
	return clampi(int(state.players[pid].get("era", state.players[pid].get("tier", 1))), 1, 5)

func _era_number(value) -> int:
	if value is int or value is float:
		return clampi(int(value), 1, 5)
	var text = str(value).strip_edges().to_upper()
	if text.begins_with("E") or text.begins_with("T"):
		text = text.substr(1)
	return clampi(int(text) if text.is_valid_int() else 1, 1, 5)

func _unit_era(unit_type: String) -> int:
	var data: Dictionary = db.unit_data(unit_type)
	return _era_number(data.get("era", data.get("tier", UNIT_ERAS.get(unit_type, 1))))

func _role_for_type(unit_type: String) -> String:
	var data: Dictionary = db.unit_data(unit_type)
	var role = str(data.get("role", data.get("route", UNIT_ROLES.get(unit_type, "")))).to_lower()
	if role in ["战线", "战线单位", "line", "frontline"]:
		return ROLE_FRONTLINE
	if role in ["机动", "机动单位", "mobile", "mobility"]:
		return ROLE_MOBILE
	if role in ["火力", "火力单位", "firepower", "artillery"]:
		return ROLE_FIREPOWER
	if role in ["支援", "支援单位", "support", "recon"]:
		return ROLE_SUPPORT
	if bool(data.get("is_air", false)) or float(data.get("vision", 0.0)) > float(data.get("damage", 0.0)) + float(data.get("range", 0.0)):
		return ROLE_SUPPORT
	return ROLE_FRONTLINE

func _capacity_cost_for_type(unit_type: String) -> int:
	var data: Dictionary = db.unit_data(unit_type)
	if data.has("capacity") or data.has("command_cost"):
		return maxi(1, int(data.get("capacity", data.get("command_cost", 1))))
	return 2 if _role_for_type(unit_type) in [ROLE_MOBILE, ROLE_FIREPOWER] else 1

func _capacity_usage(state, pid: int) -> int:
	for method_name in ["command_used", "command_usage_for", "command_usage", "used_command_capacity"]:
		if state.has_method(method_name):
			return int(state.call(method_name, pid))
	var used = 0
	for unit in state.units:
		if int(unit.get("pid", -1)) == pid:
			used += _capacity_cost_for_type(str(unit.get("type", "")))
	return used

func _capacity_limit(state, pid: int) -> int:
	for method_name in ["command_capacity_for", "command_capacity", "max_command_capacity"]:
		if state.has_method(method_name):
			return int(state.call(method_name, pid))
	var player: Dictionary = state.players[pid]
	for key in ["command_capacity", "capacity", "capacity_max"]:
		if player.has(key):
			return int(player[key])
	var bonus = 0
	for building in state.buildings:
		if int(building.get("pid", -1)) != pid or str(building.get("type", "")) != "据点":
			continue
		bonus += 2 if str(building.get("outpost_branch", "")) == "combat" and int(building.get("outpost_tier", 0)) > 0 else 1
	return int(ERA_CAPACITY.get(_player_era(state, pid), 12)) + bonus

func _owned_role_capacity(state, pid: int) -> Dictionary:
	var result = {ROLE_FRONTLINE: 0, ROLE_MOBILE: 0, ROLE_FIREPOWER: 0, ROLE_SUPPORT: 0}
	for unit in state.units:
		if int(unit.get("pid", -1)) != pid:
			continue
		var role = _role_for_type(str(unit.get("type", "")))
		result[role] = int(result.get(role, 0)) + _capacity_cost_for_type(str(unit.get("type", "")))
	return result

func _visible_enemy_role_counts(state, pid: int) -> Dictionary:
	var result = {ROLE_FRONTLINE: 0, ROLE_MOBILE: 0, ROLE_FIREPOWER: 0, ROLE_SUPPORT: 0}
	for unit in state.units:
		if int(unit.get("pid", -1)) == pid or not state.is_visible(pid, unit["pos"]):
			continue
		var role = _role_for_type(str(unit.get("type", "")))
		result[role] = int(result.get(role, 0)) + 1
	return result

func _best_available_type_for_role(state, pid: int, building: Dictionary, role: String) -> String:
	var best = ""
	var best_era = -1
	var best_price = INF
	for raw_type in state.available_units_for_player(pid):
		var unit_type = str(raw_type)
		if _role_for_type(unit_type) != role or not state.can_produce(building, unit_type):
			continue
		var era = _unit_era(unit_type)
		var price = float(db.unit_data(unit_type).get("price", 0.0))
		if era > best_era or (era == best_era and price < best_price):
			best = unit_type
			best_era = era
			best_price = price
	return best

func _enemy_neighbors(state, pid: int, pos: Vector2i) -> int:
	var count = 0
	for unit in state.units:
		if int(unit.get("pid", -1)) != pid and state.is_visible(pid, unit["pos"]) and maxi(abs(unit["pos"].x - pos.x), abs(unit["pos"].y - pos.y)) <= 1:
			count += 1
	return count

func _nearest_allied_combat_distance(state, pid: int, pos: Vector2i, ignored_id: int) -> float:
	var best = 6.0
	for unit in state.units:
		if int(unit.get("pid", -1)) != pid or int(unit.get("id", -1)) == ignored_id or _role_for_type(str(unit.get("type", ""))) == ROLE_SUPPORT:
			continue
		best = min(best, _distance(pos, unit["pos"]))
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

func _nearest_known_enemy_hq(state, pid: int, origin: Vector2i) -> Vector2i:
	var best = Vector2i(-1, -1)
	var best_distance = INF
	for building in state.buildings:
		if int(building.get("pid", -1)) == pid or str(building.get("type", "")) != "大本营" or not state.is_explored(pid, building["pos"]):
			continue
		var distance = _distance(origin, building["pos"])
		if distance < best_distance:
			best_distance = distance
			best = building["pos"]
	return best

func _uses_five_era_rules() -> bool:
	return db.units.has("战团") and db.units.has("无人战车")

func _distance(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b))
