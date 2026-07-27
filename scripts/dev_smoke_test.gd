extends SceneTree

const GameDatabaseScript = preload("res://scripts/core/game_database.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const BoardViewScript = preload("res://scripts/view/board_view.gd")

func _initialize() -> void:
	var ok = true
	var db = GameDatabaseScript.new()
	db.load_data()
	ok = _expect(not db.units.is_empty(), "unit data loaded") and ok
	ok = _expect(db.units.has("士兵"), "soldier exists") and ok
	ok = _expect(db.buildings.has("大本营"), "hq exists") and ok

	var state = GameStateScript.new()
	state.setup(db, 48, 24, 2)
	ok = _expect(state.players.size() == 2, "two players spawned") and ok
	ok = _expect(state.width == 48 and state.height == 24, "two-player map uses the fast-match size") and ok
	ok = _expect(state.units.size() == 0, "no free starting units") and ok
	ok = _expect(state.buildings.size() == 5, "starting buildings spawned") and ok
	var terrain_signature = JSON.stringify(state.terrain_grid)
	var terrain_counts = _terrain_counts(state)
	ok = _expect(int(terrain_counts.get("hill", 0)) + int(terrain_counts.get("highland", 0)) + int(terrain_counts.get("mountain", 0)) > 0, "random height terrain spawned") and ok
	ok = _expect(is_equal_approx(state.next_collector_income(0), 4.5), "first collector preview shows 4.50 gold") and ok
	state.new_game()
	ok = _expect(JSON.stringify(state.terrain_grid) != terrain_signature, "terrain changes between games") and ok

	var old_player = state.current_player
	state.end_turn()
	ok = _expect(state.current_player != old_player, "turn advances") and ok
	ok = _expect(float(state.players[state.current_player]["gold"]) == 12.0, "income waits until full round") and ok
	state.end_turn()
	ok = _expect(state.turn == 2 and float(state.players[0]["gold"]) > 12.0, "income added on round wrap") and ok
	var hq: Dictionary = {}
	for building in state.buildings:
		if building["type"] == "大本营" and int(building["pid"]) == state.current_player:
			hq = building
			break
	ok = _expect(not hq.is_empty(), "current hq found") and ok
	ok = _expect(state.can_produce(hq, "士兵"), "can produce soldier") and ok
	var old_unit_count = state.units.size()
	ok = _expect(state.produce_unit(int(hq["id"]), "士兵"), "produce soldier") and ok
	ok = _expect(state.units.size() == old_unit_count + 1, "unit count increased") and ok
	var first_unit: Dictionary = state.units[0]
	first_unit["done"] = false
	first_unit["moved"] = false
	first_unit["remaining_attacks"] = int(first_unit.get("attacks", 1))
	var moves: Array[Vector2i] = state.move_tiles_for(first_unit)
	ok = _expect(not moves.is_empty(), "move range exists") and ok
	if not moves.is_empty():
		ok = _expect(state.move_unit(int(first_unit["id"]), moves[0]), "unit can move") and ok
	state.players[state.current_player]["gold"] = 99.0
	ok = _expect(state.upgrade_hq(int(hq["id"])), "upgrade hq to T2") and ok
	ok = _expect(bool(hq.get("upgrading", false)) and int(hq.get("up_timer", 0)) == 3, "hq T2 upgrade starts timer") and ok
	ok = _expect(state.can_produce(hq, "士兵"), "hq can produce while upgrading") and ok
	_advance_full_rounds(state, 3)
	ok = _expect(int(state.players[state.current_player]["tier"]) == 2, "tier is T2") and ok
	ok = _expect(int(hq["tier"]) == 1, "hq is T2") and ok
	ok = _expect(state.research_equipment(state.current_player, "军用吉普", "火箭助推"), "research jeep boost") and ok
	ok = _expect(not state.players[state.current_player]["equipment"].has("军用吉普:火箭助推"), "equipment waits for research timer") and ok
	_advance_full_rounds(state, 2)
	ok = _expect(state.players[state.current_player]["equipment"].has("军用吉普:火箭助推"), "equipment recorded") and ok
	ok = _expect(state.upgrade_hq(int(hq["id"])), "upgrade hq to T3") and ok
	_advance_full_rounds(state, 5)
	ok = _expect(int(state.players[state.current_player]["tier"]) == 3, "tier is T3") and ok
	ok = _expect(state.research_strategic(state.current_player, "SpaceX 星链计划"), "research starlink") and ok
	_advance_full_rounds(state, 3)
	ok = _expect(state.players[state.current_player]["strategic"].has("SpaceX 星链计划"), "starlink recorded") and ok
	ok = _expect(state.is_visible(state.current_player, Vector2i(state.width - 1, state.height - 1)), "starlink full vision") and ok
	ok = _expect(_check_action_order_rules(db), "move-then-attack and attack-then-no-move rules") and ok
	ok = _expect(_check_blast_splashes_from_building_target(db), "blast hits units around building target") and ok
	ok = _expect(_check_outpost_produces_while_upgrading(db), "outpost can produce while upgrading") and ok
	ok = _expect(_check_collector_income_sequence(db), "collector income preview follows diminishing sequence") and ok
	ok = _expect(_check_air_units_ignore_terrain_range(db), "air units ignore terrain range modifier") and ok
	ok = _expect(_check_outpost_upgrade_resets_on_recapture(db), "outpost upgrade resets on recapture") and ok
	ok = _expect(_check_outpost_balance_values(db), "outpost tier stats match balance rules") and ok
	ok = _expect(_check_end_turn_auto_attack(db), "end turn automatically uses remaining attacks") and ok
	var state3 = GameStateScript.new()
	state3.setup(db, 48, 48, 3)
	ok = _expect(state3.buildings.size() == 7, "three-player map spawns four neutral outposts") and ok
	ok = _expect(_check_neutral_outpost_access_balance(state3, 1.5), "three-player outposts are equally accessible") and ok
	var state4 = GameStateScript.new()
	state4.setup(db, 60, 60, 4)
	ok = _expect(state4.players.size() == 4, "four players spawned") and ok
	ok = _expect(state4.width == 60 and state4.height == 60, "four-player map uses the fast-match size") and ok
	ok = _expect(state4.buildings.size() == 9, "four-player map spawns five neutral outposts") and ok
	ok = _expect(_check_neutral_outpost_access_balance(state4, 1.0), "four-player outposts are equally accessible") and ok
	ok = _expect(state4.units.size() == 0, "four-player no free starting units") and ok
	var board = BoardViewScript.new()
	get_root().add_child(board)
	board.setup(state, db)
	var empty_moves: Array[Vector2i] = []
	var empty_attacks: Array[Vector2i] = []
	ok = _expect(board._texture_key_for_building({"type": "大本营", "tier": 0}) == "大本营", "hq T1 texture key") and ok
	ok = _expect(board._texture_key_for_building({"type": "大本营", "tier": 1}) == "大本营 T2", "hq T2 texture key") and ok
	ok = _expect(board._texture_key_for_building({"type": "大本营", "tier": 2}) == "大本营T3", "hq T3 texture key") and ok
	ok = _expect(board._texture_key_for_building({"type": "据点", "outpost_tier": 1, "outpost_branch": "combat"}) == "战斗型T2据点", "combat outpost texture key") and ok
	ok = _expect(board._texture_key_for_building({"type": "据点", "outpost_tier": 1, "outpost_branch": "economic"}) == "资源型T2据点", "economic outpost texture key") and ok
	ok = _expect(board._texture_key_for_unit({"type": "士兵", "equip": "射手步枪"}) == "士兵-射手步枪", "equipped soldier texture key") and ok
	ok = _expect(board._texture_key_for_unit({"type": "军用吉普", "equip": "重甲吉普"}) == "军用吉普-重甲吉普", "equipped jeep texture key") and ok
	ok = _expect(board._texture_key_for_unit({"type": "坦克", "equip": ""}) == "坦克", "plain unit texture key") and ok
	board.set_selection(-1, int(hq["id"]), empty_moves, empty_attacks)
	ok = _expect(board.selected_building_id == int(hq["id"]), "building selection accepts typed empty ranges") and ok
	var preview_tiles: Array[Vector2i] = [Vector2i(1, 1)]
	board.set_build_tiles(preview_tiles, Color(0.15, 0.72, 1.0), state.next_collector_income(0))
	ok = _expect(is_equal_approx(board.build_tile_income, 4.5), "collector build overlay receives gold income") and ok
	board.clear_selection()
	ok = _expect(board.selected_unit_id == -1 and board.selected_building_id == -1, "board selection clears") and ok
	board.queue_free()

	if ok:
		print("Godot smoke test passed")
		quit(0)
	else:
		push_error("Godot smoke test failed")
		quit(1)

func _expect(condition: bool, label: String) -> bool:
	if not condition:
		push_error("Smoke check failed: " + label)
	return condition

func _terrain_counts(state) -> Dictionary:
	var counts = {}
	for row in state.terrain_grid:
		for id in row:
			counts[id] = int(counts.get(id, 0)) + 1
	return counts

func _advance_full_rounds(state, count: int) -> void:
	for _i in range(count * state.players.size()):
		state.end_turn()

func _check_action_order_rules(db) -> bool:
	var state = GameStateScript.new()
	state.setup(db, 20, 20, 2)
	state.units.clear()
	state.buildings.clear()
	for y in range(state.height):
		for x in range(state.width):
			state.terrain_grid[y][x] = "plain"
	state.current_player = 0
	var mover = state._add_unit("士兵", 0, Vector2i(5, 5))
	var target_after_move = state._add_building("据点", 1, Vector2i(9, 5), 0)
	state.update_vision()
	if not state.move_unit(int(mover["id"]), Vector2i(7, 5)):
		return false
	if bool(mover.get("done", false)) or int(mover.get("remaining_attacks", 0)) <= 0:
		return false
	if not state.attack(int(mover["id"]), target_after_move["pos"]):
		return false
	if not bool(mover.get("done", false)):
		return false
	if state.move_unit(int(mover["id"]), Vector2i(8, 5)):
		return false

	var attacker = state._add_unit("士兵", 0, Vector2i(5, 10))
	var target_before_move = state._add_building("据点", 1, Vector2i(7, 10), 0)
	state.update_vision()
	if not state.attack(int(attacker["id"]), target_before_move["pos"]):
		return false
	if state.move_unit(int(attacker["id"]), Vector2i(6, 10)):
		return false
	return true

func _check_blast_splashes_from_building_target(db) -> bool:
	var state = GameStateScript.new()
	state.setup(db, 20, 20, 2)
	state.fog_enabled = false
	state.units.clear()
	state.buildings.clear()
	for y in range(state.height):
		for x in range(state.width):
			state.terrain_grid[y][x] = "plain"
	state.current_player = 0
	var bomber = state._add_unit("轰炸机", 0, Vector2i(5, 5))
	var target_building = state._add_building("据点", 1, Vector2i(6, 5), 0)
	var nearby_unit = state._add_unit("士兵", 1, Vector2i(6, 6))
	state.update_vision()
	if not state.attack_targets_for(bomber).has(target_building["pos"]):
		return false
	if not state.attack(int(bomber["id"]), target_building["pos"]):
		return false
	if float(target_building.get("hp", 20.0)) >= float(target_building.get("max_hp", 20.0)):
		return false
	if state.units.has(nearby_unit):
		return false
	return true

func _check_outpost_produces_while_upgrading(db) -> bool:
	var state = GameStateScript.new()
	state.setup(db, 20, 20, 2)
	state.units.clear()
	state.buildings.clear()
	for y in range(state.height):
		for x in range(state.width):
			state.terrain_grid[y][x] = "plain"
	state.current_player = 0
	state.players[0]["tier"] = 2
	state.players[0]["gold"] = 50.0
	var outpost = state._add_building("据点", 0, Vector2i(6, 6), 0)
	outpost["captured"] = true
	state.update_vision()
	if not state.upgrade_outpost(int(outpost["id"]), "combat"):
		return false
	if not bool(outpost.get("upgrading", false)):
		return false
	return state.can_produce(outpost, "士兵")

func _check_collector_income_sequence(db) -> bool:
	var state = GameStateScript.new()
	state.setup(db, 20, 20, 2)
	state.players[0]["gold"] = 50.0
	var hq: Dictionary = {}
	for building in state.buildings:
		if building["type"] == "大本营" and int(building["pid"]) == 0:
			hq = building
			break
	if hq.is_empty() or not is_equal_approx(state.next_collector_income(0), 4.5):
		return false
	var build_pos: Vector2i = hq["pos"] + Vector2i(2, 0)
	if not state.build_collector(int(hq["id"]), build_pos):
		return false
	return is_equal_approx(state.next_collector_income(0), 3.6)

func _check_air_units_ignore_terrain_range(db) -> bool:
	var state = GameStateScript.new()
	state.setup(db, 20, 20, 2)
	state.fog_enabled = false
	state.units.clear()
	state.buildings.clear()
	for y in range(state.height):
		for x in range(state.width):
			state.terrain_grid[y][x] = "plain"
	state.terrain_grid[5][5] = "mountain"
	state.terrain_grid[5][9] = "plain"
	state.current_player = 0
	var fighter = state._add_unit("战斗机", 0, Vector2i(5, 5))
	var target = state._add_unit("战斗机", 1, Vector2i(9, 5))
	state.update_vision()
	if state.attack_targets_for(fighter).has(target["pos"]):
		return false
	return is_equal_approx(state.effective_range(fighter, state.terrain_height(fighter["pos"]), state.terrain_height(target["pos"]), true), float(fighter["range"]))

func _check_outpost_upgrade_resets_on_recapture(db) -> bool:
	var state = GameStateScript.new()
	state.setup(db, 20, 20, 2)
	state.units.clear()
	state.buildings.clear()
	for y in range(state.height):
		for x in range(state.width):
			state.terrain_grid[y][x] = "plain"
	state.current_player = 0
	state.players[0]["tier"] = 2
	state.players[0]["gold"] = 50.0
	var outpost = state._add_building("据点", 0, Vector2i(6, 6), 0)
	outpost["captured"] = true
	state.update_vision()
	if not state.upgrade_outpost(int(outpost["id"]), "economic"):
		return false
	if not bool(outpost.get("upgrading", false)) or int(outpost.get("up_timer", 0)) <= 0:
		return false
	state.current_player = 1
	var enemy = state._add_unit("士兵", 1, Vector2i(5, 6))
	state.update_vision()
	if not state.move_unit(int(enemy["id"]), outpost["pos"]):
		return false
	return int(outpost.get("pid", -1)) == 1 and not bool(outpost.get("upgrading", false)) and int(outpost.get("up_timer", -1)) == 0 and str(outpost.get("outpost_branch", "")) == ""

func _check_outpost_balance_values(db) -> bool:
	var state = GameStateScript.new()
	state.setup(db, 20, 20, 2)
	state.units.clear()
	state.buildings.clear()
	state.current_player = 0
	state.players[0]["tier"] = 2
	state.players[0]["gold"] = 50.0
	var tier1 = state._add_building("据点", 0, Vector2i(4, 4), 0)
	if not is_equal_approx(float(tier1["max_hp"]), 20.0) or not is_equal_approx(float(tier1["armor"]), 0.0):
		return false
	var combat = state._add_building("据点", 0, Vector2i(6, 4), 0)
	combat["outpost_branch"] = "combat"
	state._finish_outpost_upgrade(combat)
	if not is_equal_approx(float(combat["max_hp"]), 30.0) or not is_equal_approx(float(combat["armor"]), 0.5):
		return false
	var economic = state._add_building("据点", 0, Vector2i(8, 4), 0)
	economic["outpost_branch"] = "economic"
	state._finish_outpost_upgrade(economic)
	return is_equal_approx(float(economic["max_hp"]), 20.0) and is_equal_approx(float(economic["armor"]), 0.0)

func _check_end_turn_auto_attack(db) -> bool:
	var state = GameStateScript.new()
	state.setup(db, 20, 20, 2)
	state.fog_enabled = false
	state.units.clear()
	state.buildings.clear()
	for y in range(state.height):
		for x in range(state.width):
			state.terrain_grid[y][x] = "plain"
	state.current_player = 0
	var attacker = state._add_unit("士兵", 0, Vector2i(5, 5))
	var enemy = state._add_unit("士兵", 1, Vector2i(6, 5))
	var neutral = state._add_building("据点", -1, Vector2i(5, 6), 0)
	state.update_vision()
	var enemy_hp = float(enemy["hp"])
	var neutral_hp = float(neutral["hp"])
	var attacks = state.end_turn()
	return attacks == 1 and float(enemy.get("hp", 0.0)) < enemy_hp and is_equal_approx(float(neutral["hp"]), neutral_hp) and bool(attacker.get("done", false))

func _check_neutral_outpost_access_balance(state, tolerance: float) -> bool:
	var nearest_distances: Array[float] = []
	for pid in range(state.player_count):
		var hq_pos = Vector2i(-1, -1)
		for building in state.buildings:
			if building["type"] == "大本营" and int(building["pid"]) == pid:
				hq_pos = building["pos"]
				break
		if hq_pos.x < 0:
			return false
		var nearest = INF
		for building in state.buildings:
			if building["type"] == "据点" and int(building["pid"]) < 0:
				nearest = minf(nearest, Vector2(hq_pos).distance_to(Vector2(building["pos"])))
		if is_inf(nearest):
			return false
		nearest_distances.append(nearest)
	return nearest_distances.max() - nearest_distances.min() <= tolerance
