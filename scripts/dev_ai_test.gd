extends SceneTree

const GameDatabaseScript = preload("res://scripts/core/game_database.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const TacticalAIScript = preload("res://scripts/ai/tactical_ai.gd")

func _initialize() -> void:
	var ok = true
	var db = GameDatabaseScript.new()
	db.load_data()
	var state = GameStateScript.new()
	state.setup(db, 48, 24, 2)
	var ai = TacticalAIScript.new()
	ai.setup(db)
	state.current_player = 1
	var opening = ai.take_turn(state, 1)
	ok = _expect(int(opening.get("produced", 0)) >= 2, "AI produces an opening force") and ok
	ok = _expect(_owned_units(state, 1).size() >= 2, "AI owns its produced units") and ok
	ok = _expect(_owned_hq(state, 1).get("upgrading", false), "AI starts HQ progression") and ok

	var total_moved = 0
	var total_attacked = 0
	for _round in range(24):
		if state.game_over:
			break
		if state.current_player == 1:
			var report = ai.take_turn(state, 1)
			total_moved += int(report.get("moved", 0))
			total_attacked += int(report.get("attacked", 0))
		state.end_turn()
	ok = _expect(total_moved > 0, "AI advances units across the map") and ok
	ok = _expect(int(_owned_hq(state, 1).get("tier", 0)) >= 1, "AI completes at least one HQ upgrade") and ok
	ok = _expect(float(state.players[1].get("gold", 0.0)) >= 0.0, "AI never spends below zero gold") and ok
	ok = _expect(_valid_unit_positions(state), "AI units remain in bounds without overlap") and ok
	ok = _expect(total_attacked > 0 or state.game_over, "AI eventually attacks or ends the match") and ok

	if ok:
		print("Godot AI test passed")
		quit(0)
	else:
		quit(1)

func _owned_units(state, pid: int) -> Array:
	var result = []
	for unit in state.units:
		if int(unit.get("pid", -1)) == pid:
			result.append(unit)
	return result

func _owned_hq(state, pid: int) -> Dictionary:
	for building in state.buildings:
		if int(building.get("pid", -1)) == pid and str(building.get("type", "")) == "大本营":
			return building
	return {}

func _valid_unit_positions(state) -> bool:
	var occupied = {}
	for unit in state.units:
		var pos: Vector2i = unit["pos"]
		if not state.in_bounds(pos):
			return false
		var key = "%d,%d" % [pos.x, pos.y]
		if occupied.has(key):
			return false
		occupied[key] = true
	return true

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("AI test failed: " + message)
	return false
