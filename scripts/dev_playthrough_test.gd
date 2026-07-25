extends SceneTree

const MainScript = preload("res://scripts/main.gd")

func _initialize() -> void:
	var ok = true
	var main = MainScript.new()
	get_root().add_child(main)
	await process_frame
	await process_frame
	main._start_local_game(2)
	ok = _expect(main.board.visible, "game board visible") and ok
	ok = _expect(not main.action_container_panel.visible, "left action panel hidden without selection") and ok
	ok = _expect(main.action_panel_width >= 220, "left action panel is wide enough") and ok
	main._apply_resolution(Vector2i(1600, 900))
	ok = _expect(main.selected_resolution == Vector2i(1600, 900), "resolution setting applied") and ok
	ok = _expect(main.hud_top_panel.size.x > 0 and main.board.viewport_size.x > 0, "layout remains valid after resolution change") and ok
	ok = _expect(main.info_panel.position.y + main.info_panel.size.y <= main.hud_bottom_panel.position.y - 4.0, "info panel stays above bottom buttons") and ok
	ok = _expect(main.info_label.size.y >= 70.0, "info label has enough vertical room") and ok

	var hq: Dictionary = _find_hq(main, 0)
	ok = _expect(not hq.is_empty(), "player hq exists") and ok
	if hq.is_empty():
		_finish(ok)
		return
	main._on_tile_clicked(hq["pos"])
	ok = _expect(main.selected_building_id == int(hq["id"]), "hq selectable") and ok
	ok = _expect(main.action_container_panel.visible, "left action panel visible after selecting hq") and ok
	ok = _expect(main.state.produce_unit(int(hq["id"]), "士兵"), "produce soldier") and ok
	ok = _expect(main.state.units.size() == 1, "soldier spawned") and ok

	main.state.end_turn()
	main.state.end_turn()
	var soldier = main.state.units[0]
	ok = _expect(not bool(soldier.get("done", true)), "soldier refreshed next round") and ok
	var moves: Array[Vector2i] = main.state.move_tiles_for(soldier)
	ok = _expect(not moves.is_empty(), "soldier has legal moves") and ok
	if not moves.is_empty():
		ok = _expect(main.state.move_unit(int(soldier["id"]), moves[0]), "soldier moves") and ok

	soldier["moved"] = false
	soldier["done"] = false
	soldier["remaining_attacks"] = int(soldier.get("attacks", 1))
	var enemy_pos = Vector2i(int(soldier["pos"].x) + 1, int(soldier["pos"].y))
	if not main.state.in_bounds(enemy_pos) or not main.state.occupant_at(enemy_pos).is_empty():
		enemy_pos = Vector2i(int(soldier["pos"].x) - 1, int(soldier["pos"].y))
	var enemy = main.state._add_unit("士兵", 1, enemy_pos)
	enemy["done"] = false
	main.state.update_vision()
	ok = _expect(main.state.attack_targets_for(soldier).has(enemy_pos), "enemy is attackable") and ok
	ok = _expect(main.state.attack(int(soldier["id"]), enemy_pos), "soldier attacks enemy") and ok
	ok = _expect(float(enemy.get("hp", 0.0)) < float(enemy.get("max_hp", 1.0)), "enemy took damage") and ok

	main.board._zoom_at(Vector2(800, 450), 1.15)
	ok = _expect(main.board.zoom > 1.0, "zoom during playthrough works") and ok
	var before = main.board.camera_offset
	main.board.camera_offset += Vector2(-120, -80)
	main.board._clamp_camera()
	ok = _expect(main.board.camera_offset != before, "camera pan during playthrough works") and ok
	main.queue_free()
	_finish(ok)

func _find_hq(main, pid: int) -> Dictionary:
	for building in main.state.buildings:
		if building["type"] == "大本营" and int(building["pid"]) == pid:
			return building
	return {}

func _nearest_attackable_enemy_tile(main, unit: Dictionary) -> Vector2i:
	var origin: Vector2i = unit["pos"]
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var pos = origin + Vector2i(dx, dy)
			if pos == origin or not main.state.in_bounds(pos):
				continue
			if main.state.occupant_at(pos).is_empty():
				return pos
	return origin + Vector2i(1, 0)

func _finish(ok: bool) -> void:
	if ok:
		print("Godot playthrough test passed")
		quit(0)
	else:
		push_error("Godot playthrough test failed")
		quit(1)

func _expect(condition: bool, label: String) -> bool:
	if not condition:
		push_error("Playthrough check failed: " + label)
	return condition
