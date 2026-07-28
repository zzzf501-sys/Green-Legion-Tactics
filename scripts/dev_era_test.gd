extends SceneTree

const GameDatabaseScript = preload("res://scripts/core/game_database.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const BoardViewScript = preload("res://scripts/view/board_view.gd")
const TacticalAIScript = preload("res://scripts/ai/tactical_ai.gd")

const ERA_UNITS = {
	1: ["战团", "斥候", "投石队", "部落侦察"],
	2: ["方阵", "骑兵", "弓弩/投石车", "轻骑侦察"],
	3: ["火枪连", "龙骑兵", "野战炮", "工兵/观测队"],
	4: ["士兵", "主战坦克", "自行火炮", "吉普"],
	5: ["网络化步兵", "无人战车", "精确火箭", "无人机/电子战"]
}
const ERA_OPEN_ROUNDS = {1: 1, 2: 14, 3: 28, 4: 43, 5: 59}
const GRAND_WAR_ROUND = 75
const ERA_CAPACITY = {1: 22, 2: 24, 3: 26, 4: 28, 5: 30}
const MOBILE_VALUES = {
	"斥候": {"hp": 1.75, "armor": 0.0, "damage": 1.0, "speed": 5, "range": 1.0, "vision": 5, "price": 1.5},
	"骑兵": {"hp": 5.5, "armor": 0.25, "damage": 3.0, "speed": 5, "range": 1.0, "vision": 6, "price": 5.0},
	"龙骑兵": {"hp": 10.0, "armor": 1.0, "damage": 6.0, "speed": 6, "range": 2.0, "vision": 7, "price": 10.0},
	"主战坦克": {"hp": 40.0, "armor": 8.0, "damage": 20.0, "speed": 4, "range": 3.0, "vision": 5, "price": 35.0},
	"无人战车": {"hp": 48.0, "armor": 10.0, "damage": 24.0, "speed": 5, "range": 4.0, "vision": 7, "price": 45.0}
}

var checks = 0
var failures = 0

func _initialize() -> void:
	var db = GameDatabaseScript.new()
	db.load_data()
	_check_five_era_data(db)
	_check_art_manifest(db)
	_check_era_thresholds(db)
	_check_technology_gates(db)
	_check_parallel_research_and_notifications(db)
	_check_economy_contract(db)
	_check_support_technology_effects(db)
	_check_mobile_balance_values(db)
	_check_capacity_contract(db)
	_check_adjacency_combat(db)
	_check_reload_and_status(db)
	_check_endgame_contract(db)
	_check_board_fallbacks(db)
	_check_ai_adaptation(db)
	if failures == 0:
		print("ERA TEST PASS: %d checks" % checks)
		quit(0)
	else:
		push_error("ERA TEST FAIL: %d/%d checks failed" % [failures, checks])
		quit(1)

func _check_five_era_data(db) -> void:
	for era in range(1, 6):
		for unit_type in ERA_UNITS[era]:
			var data: Dictionary = db.unit_data(unit_type)
			_expect(not data.is_empty(), "E%d data exists: %s" % [era, unit_type])
			if data.is_empty():
				continue
			_expect(_parse_era(data.get("era", era)) == era, "%s belongs to E%d" % [unit_type, era])
			for key in ["hp", "armor", "damage", "speed", "range", "vision", "price"]:
				_expect(data.has(key), "%s has %s" % [unit_type, key])
			var expected_role = ["frontline", "mobile", "firepower", "support"][ERA_UNITS[era].find(unit_type)]
			_expect(_normalized_role(str(data.get("role", data.get("route", "")))) == expected_role, "%s role is %s" % [unit_type, expected_role])

func _check_art_manifest(db) -> void:
	var unit_art: Dictionary = db.art.get("units", {})
	var equipment_art: Dictionary = db.art.get("equipment", {})
	var building_art: Dictionary = db.art.get("buildings", {})
	_expect(unit_art.size() == 20, "art manifest contains 20 base unit sprites")
	_expect(equipment_art.size() == 40, "art manifest contains 40 equipment variants")
	_expect(building_art.size() == 30, "art manifest contains 30 building variants")
	var paths: Array[String] = db.art_paths()
	var unique_paths: Dictionary = {}
	for path in paths:
		unique_paths[path] = true
		_expect(ResourceLoader.exists(path), "art resource exists: %s" % path)
	_expect(paths.size() == 90 and unique_paths.size() == 90, "all 90 art resources are uniquely mapped")
	for unit_type in db.units.keys():
		_expect(not db.texture_path_for_unit(str(unit_type)).is_empty(), "%s has base sprite mapping" % unit_type)
		for item in db.equipment_for(str(unit_type)):
			_expect(not db.texture_path_for_equipment(item).is_empty(), "%s equipment has sprite mapping" % item.get("name", ""))
	var board = BoardViewScript.new()
	board.db = db
	board._load_textures()
	_expect(board.unit_textures.size() == 60, "board loads 20 base and 40 equipment unit sprites")
	_expect(board.building_textures.size() == 30, "board loads all 30 building sprites")
	for texture in board.unit_textures.values():
		_expect(texture != null, "unit sprite decodes as Texture2D")
	for texture in board.building_textures.values():
		_expect(texture != null, "building sprite decodes as Texture2D")
	board.unit_textures.clear()
	board.building_textures.clear()
	board.terrain_textures.clear()
	board.free()

func _check_era_thresholds(db) -> void:
	var state = _fresh_state(db)
	for era in range(1, 6):
		var actual = _era_open_round(state, db, era)
		_expect(actual == int(ERA_OPEN_ROUNDS[era]), "E%d opens on round %d" % [era, ERA_OPEN_ROUNDS[era]])
	var ai = TacticalAIScript.new()
	ai.setup(db)
	state.turn = 12
	_expect(not ai._era_upgrade_window_open(state, 2), "AI does not queue E2 too early")
	state.turn = 13
	_expect(ai._era_upgrade_window_open(state, 2), "AI queues E2 one round before opening")

func _check_parallel_research_and_notifications(db) -> void:
	var state = _fresh_state(db)
	state.players[0]["gold"] = 100.0
	_expect(state.research_technology(0, "e1_flint_weapons"), "first E1 technology starts")
	_expect(state.research_technology(0, "e1_hunting_groups"), "second E1 technology starts concurrently")
	_expect(state.players[0]["researching"].size() == 2, "two technologies remain in the concurrent research list")
	_expect(not state.research_technology(0, "e1_flint_weapons"), "the same technology cannot be queued twice")
	state._tick_player_research(0)
	_expect(state.players[0]["researching"].is_empty(), "both one-round technologies finish together")
	var notices = state.take_research_notifications(0)
	_expect(notices.has("燧石武器") and notices.has("狩猎编组"), "completed technologies emit player notifications")
	_expect(state.take_research_notifications(0).is_empty(), "research notifications are consumed once")

func _check_economy_contract(db) -> void:
	var expected_hq_income = [3.0, 5.5, 9.0, 16.0, 25.0]
	var expected_hq_upgrade = [15.0, 27.0, 48.0, 78.0]
	var hq_data: Dictionary = db.building_data("大本营")
	var tiers: Array = hq_data.get("tiers", [])
	_expect(tiers.size() == 5, "hq has five economy tiers")
	for index in range(mini(tiers.size(), 5)):
		_expect(is_equal_approx(float(tiers[index].get("gold", -1.0)), expected_hq_income[index]), "E%d hq income is %.1f" % [index + 1, expected_hq_income[index]])
		if index < 4:
			_expect(is_equal_approx(float(tiers[index].get("upgrade_cost", -1.0)), expected_hq_upgrade[index]), "E%d hq upgrade costs %.1f" % [index + 1, expected_hq_upgrade[index]])
	var collector_data: Dictionary = db.building_data("资源采集器")
	_expect(is_equal_approx(float(collector_data.get("cost", -1.0)), 12.0), "collector base price is 12")
	for era in range(1, 6):
		var era_collector: Dictionary = collector_data.get("eras", {}).get("E%d" % era, {})
		_expect(is_equal_approx(float(era_collector.get("cost", -1.0)), 12.0), "E%d collector price is 12" % era)
	var expected_outpost_income = {
		"E1": {"base": 1.0},
		"E2": {"base": 1.0, "combat": 1.0, "economic": 3.0},
		"E3": {"base": 3.0, "combat": 2.0, "economic": 4.0},
		"E4": {"base": 4.0, "combat": 3.0, "economic": 7.0},
		"E5": {"base": 6.0, "combat": 4.0, "economic": 10.0}
	}
	var outpost_eras: Dictionary = db.building_data("据点").get("eras", {})
	for era_key in expected_outpost_income.keys():
		for branch in expected_outpost_income[era_key].keys():
			var actual = float(outpost_eras.get(era_key, {}).get(branch, {}).get("gold", -1.0))
			var expected = float(expected_outpost_income[era_key][branch])
			_expect(is_equal_approx(actual, expected), "%s %s outpost income is %.1f" % [era_key, branch, expected])

func _check_technology_gates(db) -> void:
	var state = _fresh_state(db)
	state.players[0]["gold"] = 100.0
	_expect(state.available_units_for_player(0) == ["战团"], "E1 starts with only the baseline warband unlocked")
	_expect(state.can_research_technology(0, "e1_hunting_groups"), "hunting groups can be researched in E1")
	_expect(state.research_technology(0, "e1_hunting_groups"), "hunting groups research starts")
	state._tick_player_research(0)
	_expect(state.available_units_for_player(0).has("斥候") and state.available_units_for_player(0).has("部落侦察"), "hunting groups unlock scout and recon production")
	var hq: Dictionary = {}
	for building in state.buildings:
		if str(building.get("type", "")) == "大本营" and int(building.get("pid", -1)) == 0:
			hq = building
			break
	var collector_pos: Vector2i = hq.get("pos", Vector2i(5, 5)) + Vector2i(2, 0)
	_expect(not state.can_build_collector(hq, collector_pos), "collector requires organized gathering")
	state.players[0]["technology"].append("e1_organized_gathering")
	state.players[0]["researched"].append("e1_organized_gathering")
	_expect(state.can_build_collector(hq, collector_pos), "organized gathering unlocks collectors")
	_set_player_era(state, 0, 2)
	_expect(not state.available_units_for_player(0).has("骑兵"), "new era does not bypass unit technology")
	_expect(state.can_research_technology(0, "e1_palisade"), "legacy E1 technology remains researchable in E2")
	var discounted_terms = state.technology_research_terms(0, "e2_horsemanship")
	_expect(is_equal_approx(float(discounted_terms.get("cost", -1.0)), 6.0) and int(discounted_terms.get("research_time", -1)) == 1, "hard-linked horsemanship costs 6 gold and 1 turn")
	var gold_before_discounted_research = float(state.players[0]["gold"])
	_expect(state.research_technology(0, "e2_horsemanship"), "discounted horsemanship research starts")
	_expect(is_equal_approx(float(state.players[0]["gold"]), gold_before_discounted_research - 6.0) and int(state.players[0]["researching"][0]["timer"]) == 1, "discounted horsemanship deducts 6 gold and takes 1 turn")
	state._tick_player_research(0)
	_expect(state.available_units_for_player(0).has("骑兵") and state.available_units_for_player(0).has("轻骑侦察"), "horsemanship unlocks both mounted units")
	var independent_state = _fresh_state(db)
	_set_player_era(independent_state, 0, 2)
	independent_state.players[0]["gold"] = 100.0
	var standard_terms = independent_state.technology_research_terms(0, "e2_horsemanship")
	_expect(is_equal_approx(float(standard_terms.get("cost", -1.0)), 6.0) and int(standard_terms.get("research_time", -1)) == 1, "horsemanship has fixed hard-tree terms")
	_expect(not independent_state.research_technology(0, "e2_horsemanship"), "E2 horsemanship is blocked without E1 hunting groups")
	independent_state.players[0]["technology"].append("e1_hunting_groups")
	independent_state.players[0]["researched"].append("e1_hunting_groups")
	_expect(independent_state.research_technology(0, "e2_horsemanship"), "horsemanship unlocks after its hard prerequisite")
	_expect(is_equal_approx(float(independent_state.players[0]["gold"]), 94.0) and int(independent_state.players[0]["researching"][0]["timer"]) == 1, "hard-tree horsemanship cost and timer are applied")
	var route_state = _fresh_state(db)
	_set_player_era(route_state, 0, 5)
	route_state.players[0]["gold"] = 1000.0
	_expect(not route_state.can_research_technology(0, "e5_autonomous_systems"), "E5 unmanned armor requires the prior mobile-route technology")
	for prerequisite in ["e1_hunting_groups", "e2_horsemanship", "e3_dragoon_tactics", "e4_armored_warfare"]:
		route_state.players[0]["technology"].append(prerequisite)
		route_state.players[0]["researched"].append(prerequisite)
	_expect(route_state.can_research_technology(0, "e5_autonomous_systems"), "E5 unmanned armor opens after the complete mobile route")
	var hq_gate_state = _fresh_state(db)
	hq_gate_state.players[0]["gold"] = 100.0
	hq_gate_state.turn = 14
	_expect(hq_gate_state.player_era(0) == 1 and hq_gate_state.global_era() == 2, "global E2 can open while the player HQ remains E1")
	_expect(not hq_gate_state.can_research_technology(0, "e2_standing_phalanx"), "E2 research remains locked until the player HQ reaches E2")
	_set_player_era(hq_gate_state, 0, 2)
	_expect(hq_gate_state.can_research_technology(0, "e2_standing_phalanx"), "HQ E2 unlocks E2 research")
	_expect(hq_gate_state.research_technology(0, "e2_standing_phalanx"), "HQ-unlocked E2 technology enters the research queue")
	hq_gate_state._tick_player_research(0)
	_expect(hq_gate_state.can_research_equipment(0, "方阵", "长枪阵"), "completed E2 unit technology unlocks its equipment at HQ E2")
	_expect(is_equal_approx(state._logistics_multiplier(0), 1.0), "era alone does not grant logistics multiplier")
	state.players[0]["technology"].append("e2_road_stations")
	state.players[0]["researched"].append("e2_road_stations")
	_expect(is_equal_approx(state._logistics_multiplier(0), 1.1), "road stations grant E2 logistics multiplier")

func _check_support_technology_effects(db) -> void:
	var state = _fresh_state(db)
	state.players[0]["gold"] = 100.0
	state.buildings.clear()
	var hq = state._add_building("大本营", 0, Vector2i(5, 5), 0)
	hq["hp"] = 5.0
	hq["max_hp"] = 15.0
	hq["turns_since_damage"] = 3
	state._building_turn_start(hq)
	_expect(is_equal_approx(float(hq["hp"]), 5.0), "buildings do not regenerate before palisade research")
	var unit = state._add_unit("战团", 0, Vector2i(6, 5))
	unit["hp"] = 0.5
	_expect(not state.garrison_unit(int(unit["id"])), "units cannot garrison before palisade research")
	state.players[0]["technology"].append("e1_palisade")
	state.players[0]["researched"].append("e1_palisade")
	state._building_turn_start(hq)
	_expect(float(hq["hp"]) > 5.0, "palisade enables delayed building regeneration")
	_expect(state.garrison_unit(int(unit["id"])) and float(unit["hp"]) > 0.5, "palisade enables unit garrison healing")
	var logistics = [
		["e2_road_stations", 1.1, 4.95],
		["e3_industrial_logistics", 1.2, 5.40],
		["e4_radio_fire_control", 1.3, 5.85],
		["e5_smart_logistics", 1.4, 6.30]
	]
	for entry in logistics:
		state.players[0]["technology"].append(str(entry[0]))
		state.players[0]["researched"].append(str(entry[0]))
		_expect(is_equal_approx(state._logistics_multiplier(0), float(entry[1])), "%s applies logistics multiplier %.2f" % [str(entry[0]), float(entry[1])])
		_expect(is_equal_approx(state.next_collector_income(0), float(entry[2])), "%s changes first collector income to %.2f" % [str(entry[0]), float(entry[2])])
	_expect(not db.technology_data("e4_radio_fire_control").get("unlocks", []).has("共享标记"), "radio fire control no longer advertises an already-baseline mark unlock")

func _check_mobile_balance_values(db) -> void:
	for unit_type in MOBILE_VALUES.keys():
		var data: Dictionary = db.unit_data(unit_type)
		for key in MOBILE_VALUES[unit_type].keys():
			_expect(is_equal_approx(float(data.get(key, -999.0)), float(MOBILE_VALUES[unit_type][key])), "%s %s uses weakened value %s" % [unit_type, key, MOBILE_VALUES[unit_type][key]])
	_expect(float(db.unit_data("主战坦克").get("hp", 0.0)) == 40.0 and float(db.unit_data("主战坦克").get("armor", 0.0)) == 8.0, "E4 tank HP/armor are reduced 20 percent")
	_expect(float(db.unit_data("无人战车").get("hp", 0.0)) == 48.0 and float(db.unit_data("无人战车").get("armor", 0.0)) == 10.0, "E5 unmanned tank uses approved HP/armor")

func _check_capacity_contract(db) -> void:
	var state = _fresh_state(db)
	var ai = TacticalAIScript.new()
	ai.setup(db)
	for era in range(1, 6):
		_set_player_era(state, 0, era)
		_expect(ai._capacity_limit(state, 0) >= int(ERA_CAPACITY[era]), "E%d base command capacity is at least %d" % [era, ERA_CAPACITY[era]])
	for unit_type in ERA_UNITS[1] + ERA_UNITS[2] + ERA_UNITS[3] + ERA_UNITS[4] + ERA_UNITS[5]:
		var expected = 2 if _normalized_role(str(db.unit_data(unit_type).get("role", db.unit_data(unit_type).get("route", "")))) in ["mobile", "firepower"] else 1
		_expect(ai._capacity_cost_for_type(unit_type) == expected, "%s command cost is %d" % [unit_type, expected])

func _check_adjacency_combat(db) -> void:
	if not _has_all_units(db, ["战团", "方阵", "骑兵", "无人战车", "精确火箭", "无人机/电子战"]):
		_expect(false, "adjacency fixtures have required units")
		return
	var state = _fresh_state(db)
	var attacker = state._add_unit("战团", 0, Vector2i(5, 5))
	state._add_unit("战团", 0, Vector2i(5, 6))
	state._add_unit("战团", 0, Vector2i(6, 6))
	var target = state._add_unit("战团", 1, Vector2i(6, 5))
	state.update_vision()
	var before = float(target["hp"])
	_expect(state.attack(int(attacker["id"]), target["pos"]), "E1 adjacent warband can attack")
	_expect(is_equal_approx(before - float(target.get("hp", 0.0)), 1.5), "two adjacent warbands add +0.5 attack")

	state = _fresh_state(db)
	attacker = state._add_unit("骑兵", 0, Vector2i(5, 5))
	target = state._add_unit("方阵", 1, Vector2i(6, 5))
	state._add_unit("方阵", 1, Vector2i(6, 6))
	state._add_unit("方阵", 1, Vector2i(7, 6))
	state.update_vision()
	before = float(target["hp"])
	_expect(state.attack(int(attacker["id"]), target["pos"]), "E2 cavalry can attack formed phalanx")
	_expect(is_equal_approx(before - float(target.get("hp", 0.0)), 0.75), "two adjacent phalanxes raise armor to 2.25")

	state = _fresh_state(db)
	attacker = state._add_unit("精确火箭", 0, Vector2i(3, 5))
	target = state._add_unit("无人战车", 1, Vector2i(7, 5))
	state._add_unit("无人机/电子战", 1, Vector2i(7, 6))
	state._add_unit("无人机/电子战", 1, Vector2i(8, 6))
	state.update_vision()
	before = float(target["hp"])
	_expect(state.attack(int(attacker["id"]), target["pos"]), "E5 precision rocket can attack supported unmanned tank")
	_expect(is_equal_approx(before - float(target.get("hp", 0.0)), 24.0), "two drones add capped +2 armor")

func _check_reload_and_status(db) -> void:
	var rocket: Dictionary = db.unit_data("精确火箭")
	_expect(int(rocket.get("reload", 0)) == 1, "precision rocket has one-turn reload")
	var state = _fresh_state(db)
	if rocket.is_empty():
		return
	var attacker = state._add_unit("精确火箭", 0, Vector2i(3, 5))
	var target = state._add_unit("网络化步兵", 1, Vector2i(7, 5))
	state.update_vision()
	_expect(state.attack(int(attacker["id"]), target["pos"]), "reload fixture attacks")
	_expect(int(attacker.get("rl", attacker.get("reload_left", 0))) > 0, "attack enters reload state")
	_expect(state.attack_targets_for(attacker).is_empty(), "reloading unit has no legal attack")
	var serialized = state.to_dict()
	var restored = GameStateScript.new()
	restored.db = db
	restored.load_from_dict(serialized)
	var restored_attacker = restored.get_unit_by_id(int(attacker["id"]))
	_expect(int(restored_attacker.get("rl", restored_attacker.get("reload_left", 0))) > 0, "reload status survives save/load")

func _check_endgame_contract(db) -> void:
	var state = _fresh_state(db)
	var total_war_round = _total_war_round(state, db)
	_expect(total_war_round == GRAND_WAR_ROUND, "total war begins on round %d" % GRAND_WAR_ROUND)
	state.turn = GRAND_WAR_ROUND
	_expect(_total_war_active(state), "total war is active at round %d" % GRAND_WAR_ROUND)
	var hq0 = _owned_hq(state, 0)
	var hq1 = _owned_hq(state, 1)
	hq0["hp"] = float(hq0["max_hp"]) - 5.0
	hq0["turns_since_damage"] = 3
	hq0["damaged_this_turn"] = false
	var hp_before = float(hq0["hp"])
	state._building_turn_start(hq0)
	_expect(is_equal_approx(float(hq0["hp"]), hp_before), "total war disables HQ healing")
	state.fog_enabled = true
	state.update_vision()
	_expect(state.is_visible(0, hq1["pos"]), "total war reveals enemy HQ")
	var artillery = state._add_unit("自行火炮", 0, Vector2i(5, 10))
	state.turn = GRAND_WAR_ROUND - 1
	var normal_damage = float(state._effective_attack_damage(artillery, hq1, false))
	state.turn = GRAND_WAR_ROUND
	var total_war_damage = float(state._effective_attack_damage(artillery, hq1, false))
	_expect(total_war_damage > normal_damage and is_equal_approx(total_war_damage, normal_damage * 1.25), "total war grants firepower +25 percent vs buildings")
	state.buildings.clear()
	state._add_building("大本营", 0, Vector2i(2, 10), 0)
	state._add_building("大本营", 1, Vector2i(17, 10), 0)
	for pos in [Vector2i(8, 8), Vector2i(10, 10)]:
		var point = state._add_building("据点", 0, pos, 0)
		point["strategic_point"] = true
	for _i in range(3):
		state._resolve_campaign_round()
	_expect(int(state.players[0].get("assault_window", 0)) == 2, "three campaign advantage points open a two-round assault window")

func _check_board_fallbacks(db) -> void:
	var board = BoardViewScript.new()
	get_root().add_child(board)
	board.db = db
	_expect(board._unit_short_name({"type": "无人战车"}) == "战车", "missing sprite fallback uses clear Chinese abbreviation")
	_expect(board._unit_era({"type": "无人战车"}) == 5, "missing sprite fallback shows E5")
	var labels = board._unit_status_labels({"rl": 1, "marked": true, "jammed_turns": 2})
	_expect(labels.has("装1") and labels.has("标") and labels.has("扰"), "board exposes reload, mark and jam statuses")
	labels = board._unit_status_labels({"charged": true, "flanking": true, "concealed": true})
	_expect(labels.has("冲") and labels.has("侧") and labels.has("隐"), "board exposes charge, flank and conceal statuses")
	board.state = _fresh_state(db)
	labels = board._unit_status_labels({"marked_by": {"0": board.state.turn + 1}})
	_expect(labels.has("标"), "board reads live marked_by state")
	var building_labels = board._building_status_labels({"type": "大本营", "upgrading": true, "up_timer": 2})
	_expect(building_labels.has("升2"), "board shows building upgrade countdown")
	board.queue_free()

func _check_ai_adaptation(db) -> void:
	var state = _fresh_state(db)
	state.fog_enabled = true
	state.update_vision()
	var ai = TacticalAIScript.new()
	ai.setup(db)
	_expect(ai._role_for_type("主战坦克") == "mobile", "AI recognizes tank as mobile role")
	_expect(ai._role_for_type("精确火箭") == "firepower", "AI recognizes precision rocket as firepower role")
	_expect(ai._role_for_type("无人机/电子战") == "support", "AI recognizes drone/EW as support role")
	var own_hq = _owned_hq(state, 0)
	var enemy_hq = _owned_hq(state, 1)
	_expect(ai._nearest_known_enemy_hq(state, 0, own_hq["pos"]) == Vector2i(-1, -1), "AI cannot read unexplored enemy HQ")
	state.players[0]["explored"]["%d,%d" % [enemy_hq["pos"].x, enemy_hq["pos"].y]] = true
	_expect(ai._nearest_known_enemy_hq(state, 0, own_hq["pos"]) == enemy_hq["pos"], "AI uses enemy HQ after exploration")
	if _has_all_units(db, ["骑兵", "弓弩/投石车", "方阵"]):
		state.units.clear()
		state.buildings.clear()
		state.fog_enabled = false
		var mobile = state._add_unit("骑兵", 0, Vector2i(5, 5))
		var firepower = state._add_unit("弓弩/投石车", 1, Vector2i(9, 5))
		state._add_unit("方阵", 1, Vector2i(5, 9))
		state.update_vision()
		_expect(ai._choose_objective(state, 0, mobile) == firepower["pos"], "mobile AI prioritizes exposed firepower")

func _fresh_state(db):
	var state = GameStateScript.new()
	state.setup(db, 20, 20, 2)
	state.fog_enabled = false
	state.units.clear()
	state.buildings.clear()
	for y in range(state.height):
		for x in range(state.width):
			state.terrain_grid[y][x] = "plain"
	state._add_building("大本营", 0, Vector2i(2, 10), 0)
	state._add_building("大本营", 1, Vector2i(17, 10), 0)
	state.current_player = 0
	state.update_vision()
	return state

func _era_open_round(state, db, era: int) -> int:
	for method_name in ["era_open_round", "open_round_for_era", "era_unlock_round"]:
		if state.has_method(method_name):
			return int(state.call(method_name, era))
	if state.has_method("global_era"):
		var original_turn = int(state.turn)
		for round_number in range(1, 60):
			state.turn = round_number
			if int(state.call("global_era")) >= era:
				state.turn = original_turn
				return round_number
		state.turn = original_turn
	var eras = _object_property(db, "eras")
	if eras is Dictionary:
		var data: Dictionary = eras.get("E%d" % era, eras.get(str(era), {}))
		return int(data.get("open_round", data.get("round", -1)))
	return -1

func _total_war_round(state, db) -> int:
	for method_name in ["total_war_round", "final_war_round"]:
		if state.has_method(method_name):
			return int(state.call(method_name))
	if state.has_method("is_total_war"):
		var original_turn = int(state.turn)
		for round_number in range(1, 80):
			state.turn = round_number
			if bool(state.call("is_total_war")):
				state.turn = original_turn
				return round_number
		state.turn = original_turn
	var rules = _object_property(db, "rules")
	if rules is Dictionary:
		return int(rules.get("total_war_round", rules.get("final_war_round", -1)))
	return -1

func _total_war_active(state) -> bool:
	for method_name in ["is_total_war", "total_war_active", "is_final_war"]:
		if state.has_method(method_name):
			return bool(state.call(method_name))
	for key in ["total_war", "final_war", "total_war_active"]:
		var value = _object_property(state, key)
		if value != null:
			return bool(value) or int(state.turn) >= GRAND_WAR_ROUND
	return false

func _endgame_rule_present(state, db, rule_name: String) -> bool:
	if state.has_method("has_endgame_rule"):
		return bool(state.call("has_endgame_rule", rule_name))
	var rules = _object_property(db, "rules")
	if rules is Dictionary:
		if rules.has(rule_name):
			return true
		var endgame = rules.get("endgame", rules.get("total_war", {}))
		if endgame is Dictionary and endgame.has(rule_name):
			return true
	for key in [rule_name, "campaign_advantage", "assault_window", "firepower_building_bonus"]:
		if _object_property(state, key) != null:
			return true
	return false

func _object_property(object, property_name: String):
	for info in object.get_property_list():
		if str(info.get("name", "")) == property_name:
			return object.get(property_name)
	return null

func _set_player_era(state, pid: int, era: int) -> void:
	if state.players[pid].has("era"):
		state.players[pid]["era"] = era
	else:
		state.players[pid]["tier"] = era

func _owned_hq(state, pid: int) -> Dictionary:
	for building in state.buildings:
		if str(building.get("type", "")) == "大本营" and int(building.get("pid", -1)) == pid:
			return building
	return {}

func _has_all_units(db, unit_types: Array) -> bool:
	for unit_type in unit_types:
		if db.unit_data(str(unit_type)).is_empty():
			return false
	return true

func _normalized_role(role: String) -> String:
	var normalized = role.to_lower()
	if normalized in ["frontline", "line", "战线", "战线单位"]:
		return "frontline"
	if normalized in ["mobile", "mobility", "机动", "机动单位"]:
		return "mobile"
	if normalized in ["firepower", "artillery", "火力", "火力单位"]:
		return "firepower"
	if normalized in ["support", "recon", "支援", "支援单位"]:
		return "support"
	return normalized

func _parse_era(value) -> int:
	var text = str(value).to_upper()
	if text.begins_with("E"):
		text = text.trim_prefix("E")
	return int(text)

func _expect(condition: bool, label: String) -> bool:
	checks += 1
	if condition:
		print("PASS: " + label)
		return true
	failures += 1
	push_error("FAIL: " + label)
	return false
