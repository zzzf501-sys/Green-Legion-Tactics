extends SceneTree

const MainScript = preload("res://scripts/main.gd")

func _initialize() -> void:
	var ok = true
	var main = MainScript.new()
	get_root().add_child(main)
	await process_frame
	await process_frame
	ok = _expect(main.state != null, "main state exists") and ok
	ok = _expect(main.board != null, "main board exists") and ok
	ok = _expect(main.info_panel != null and not (main.info_panel is PanelContainer), "bottom info text holder has no panel background") and ok
	ok = _expect(main.menu_layer != null and main.menu_layer.visible, "main menu visible on boot") and ok
	ok = _expect(main.menu_buttons != null and main.menu_buttons.visible, "main menu buttons visible on boot") and ok
	ok = _expect(not main.board.visible, "board hidden behind menu on boot") and ok
	main._show_encyclopedia()
	ok = _expect(main.encyclopedia_panel.visible, "encyclopedia opens") and ok
	ok = _expect(not main.menu_buttons.visible, "menu buttons hidden behind encyclopedia") and ok
	main._render_encyclopedia_chapter("ch0")
	ok = _expect(main.encyclopedia_content.get_parsed_text().find("游戏规则") >= 0, "encyclopedia has rules chapter") and ok
	ok = _expect(main.encyclopedia_content.get_parsed_text().find("经典兵种测试矩阵") >= 0, "encyclopedia has matchup matrix") and ok
	main._render_encyclopedia_chapter("ch1")
	ok = _expect(main.encyclopedia_content.get_parsed_text().find("兵种大全") >= 0, "encyclopedia has units chapter") and ok
	ok = _expect(main.encyclopedia_content.get_parsed_text().find("装备研究") >= 0, "encyclopedia has equipment details") and ok
	main._render_encyclopedia_chapter("ch2")
	ok = _expect(main.encyclopedia_content.get_parsed_text().find("建筑大全") >= 0, "encyclopedia has buildings chapter") and ok
	main._render_encyclopedia_chapter("ch3")
	ok = _expect(main.encyclopedia_content.get_parsed_text().find("科技树") >= 0, "encyclopedia has tech chapter") and ok
	ok = _expect(main.encyclopedia_content.get_parsed_text().find("SpaceX") >= 0, "encyclopedia has strategic tech") and ok
	main._show_menu_home()
	ok = _expect(main.menu_buttons.visible and not main.encyclopedia_panel.visible, "return to menu home") and ok
	main._show_settings()
	ok = _expect(main.settings_panel.visible, "settings opens") and ok
	ok = _expect(not main.menu_buttons.visible, "menu buttons hidden behind settings") and ok
	main._apply_resolution(Vector2i(1280, 720))
	ok = _expect(main.selected_resolution == Vector2i(1280, 720), "resolution setting applies") and ok
	main._set_fullscreen(true)
	ok = _expect(main.fullscreen_enabled, "fullscreen can be enabled") and ok
	main._set_fullscreen(false)
	ok = _expect(not main.fullscreen_enabled, "fullscreen can be disabled") and ok
	main._show_menu_home()
	ok = _expect(main.menu_buttons.visible and not main.settings_panel.visible, "return from settings") and ok
	main._show_player_select()
	ok = _expect(main.player_select_panel.visible, "player select opens") and ok
	ok = _expect(not main.menu_buttons.visible, "menu buttons hidden behind player select") and ok
	main.local_fog_checkbox.button_pressed = false
	main._start_local_game(2)
	ok = _expect(not main.menu_layer.visible and main.board.visible, "local game starts from menu") and ok
	ok = _expect(not main.state.fog_enabled, "local hotseat can disable fog of war") and ok
	ok = _expect(main.state.is_visible(0, Vector2i(main.state.width - 1, main.state.height - 1)), "disabled fog reveals full map") and ok
	ok = _expect(main.state.width == 60 and main.state.height == 30, "two-player map size matches original") and ok
	ok = _expect(main.state.units.size() == 0, "local game starts without free units") and ok
	var player0_hq = _player_hq(main, 0)
	var player1_hq = _player_hq(main, 1)
	main.online_connected = true
	main.online_player_id = 0
	main.state.fog_enabled = true
	main.state.current_player = 0
	main.state.update_vision()
	main._sync_board_view_player()
	var online_offset_before = main.board.camera_offset
	var online_zoom_before = main.board.zoom
	ok = _expect(main.state.is_visible(0, player0_hq["pos"]), "online player sees own hq before ending turn") and ok
	ok = _expect(not main.state.is_visible(0, player1_hq["pos"]), "online player does not reveal enemy hq before ending turn") and ok
	main._on_end_turn_pressed()
	ok = _expect(main.state.current_player == 1, "online end turn advances to opponent") and ok
	ok = _expect(main.board.view_player_id == 0, "online board keeps local player viewpoint after ending turn") and ok
	ok = _expect(main.board.camera_offset == online_offset_before and main.board.zoom == online_zoom_before, "online end turn keeps camera position") and ok
	ok = _expect(main.state.is_visible(0, player0_hq["pos"]), "online player keeps own fog vision after ending turn") and ok
	ok = _expect(not main.state.is_visible(0, player1_hq["pos"]), "online end turn does not reveal opponent hq") and ok
	ok = _expect(not main._can_control_current_turn(), "online player cannot control opponent turn") and ok
	main.online_connected = false
	main.online_player_id = -1
	main.state.current_player = 0
	main.state.fog_enabled = false
	main.state.update_vision()
	main._sync_board_view_player()
	var old_zoom = main.board.zoom
	main.board._zoom_at(Vector2(640, 360), 1.2)
	ok = _expect(main.board.zoom > old_zoom, "board zooms in") and ok
	var old_offset = main.board.camera_offset
	main.board.camera_offset += Vector2(-80, -40)
	main.board._clamp_camera()
	ok = _expect(main.board.camera_offset != old_offset, "board camera pans") and ok
	var own_hq: Dictionary = {}
	for building in main.state.buildings:
		if building["type"] == "大本营" and int(building["pid"]) == main.state.current_player:
			own_hq = building
			break
	ok = _expect(not own_hq.is_empty(), "own hq exists") and ok
	if not own_hq.is_empty():
		main._on_tile_clicked(own_hq["pos"])
		ok = _expect(main.selected_building_id == int(own_hq["id"]), "click hq selects building") and ok
		ok = _expect(main.board.selected_building_id == int(own_hq["id"]), "board building selection set") and ok
		main.state.players[main.state.current_player]["gold"] = 30.0
		main._on_produce_pressed(int(own_hq["id"]), "士兵")
		ok = _expect(main.state.units.size() == 1 and not main.undo_history.is_empty(), "produce action creates undo snapshot") and ok
		main._on_undo_pressed()
		ok = _expect(main.state.units.size() == 0, "undo restores unit production") and ok
		ok = _expect(main.state.produce_unit(int(own_hq["id"]), "士兵"), "produce first soldier from hq") and ok
		var collector_pos = own_hq["pos"] + Vector2i(2, 0)
		if not main.state.occupant_at(collector_pos).is_empty():
			collector_pos = own_hq["pos"] + Vector2i(0, 2)
		main.state.players[main.state.current_player]["gold"] = 30.0
		ok = _expect(main.state.build_collector(int(own_hq["id"]), collector_pos), "build resource collector near hq") and ok
		var collector = main.state.building_at(collector_pos)
		ok = _expect(not collector.is_empty() and bool(collector.get("under_construction", false)), "collector starts under construction") and ok
		main.state.end_turn()
		main.state.end_turn()
		main.state.end_turn()
		main.state.end_turn()
		ok = _expect(not bool(collector.get("under_construction", false)) and float(collector.get("gold", 0.0)) > 0.0, "collector completes and produces income") and ok
		main.board.setup(main.state, main.db)
	var own_outpost: Dictionary = {}
	for building in main.state.buildings:
		if building["type"] == "据点":
			own_outpost = building
			own_outpost["pid"] = main.state.current_player
			own_outpost["captured"] = true
			break
	if not own_outpost.is_empty():
		main.state.players[main.state.current_player]["tier"] = 2
		main.state.players[main.state.current_player]["gold"] = 30.0
		ok = _expect(main.state.upgrade_outpost(int(own_outpost["id"]), "combat"), "start combat outpost upgrade") and ok
		ok = _expect(main.state.can_produce(own_outpost, "士兵"), "selected outpost can produce while upgrading") and ok
		main.state.end_turn()
		main.state.end_turn()
		ok = _expect(int(own_outpost.get("outpost_tier", 0)) == 1 and str(own_outpost.get("outpost_branch", "")) == "combat", "combat outpost upgrade completes") and ok
	var own_unit: Dictionary = {}
	for unit in main.state.units:
		if int(unit["pid"]) == main.state.current_player:
			unit["done"] = false
			unit["moved"] = false
			unit["remaining_attacks"] = int(unit.get("attacks", 1))
			own_unit = unit
			break
	ok = _expect(not own_unit.is_empty(), "own unit exists") and ok
	if not own_unit.is_empty():
		main._on_tile_clicked(own_unit["pos"])
		ok = _expect(main.selected_unit_id == int(own_unit["id"]), "click unit selects unit") and ok
		ok = _expect(main.board.move_tiles.size() > 0, "unit selection has move tiles") and ok
		ok = _expect(main.board.threat_tiles.is_empty(), "own unit selection does not show global threat overlay") and ok
		ok = _expect(_collect_text(main.action_panel).find("护甲") >= 0, "selected unit panel shows armor") and ok
		main._on_tile_hovered(own_unit["pos"])
		ok = _expect(main.info_label.text.find("护甲") >= 0, "unit hover tooltip shows armor") and ok
		var enemy_hover_pos = own_unit["pos"] + Vector2i(4, 0)
		if not main.state.in_bounds(enemy_hover_pos) or not main.state.occupant_at(enemy_hover_pos).is_empty():
			enemy_hover_pos = own_unit["pos"] + Vector2i(0, 4)
		if main.state.in_bounds(enemy_hover_pos) and main.state.occupant_at(enemy_hover_pos).is_empty():
			var enemy_hover_unit = main.state._add_unit("士兵", 1, enemy_hover_pos)
			main.state.update_vision()
			main._on_tile_hovered(enemy_hover_unit["pos"])
			ok = _expect(main.board.hover_threat_tiles.size() > 0, "enemy hover shows threat range") and ok
			ok = _expect(main.board.hover_threat_label.find("威胁范围") >= 0, "enemy hover labels threat range") and ok
		main._on_tile_clicked(own_unit["pos"])
		ok = _expect(main.board.hover_threat_tiles.is_empty(), "selecting own unit clears hover threat range") and ok
		var original_pos: Vector2i = own_unit["pos"]
		var move_target: Vector2i = Vector2i(-1, -1)
		if not main.board.move_tiles.is_empty():
			move_target = main.board.move_tiles[0]
		if main.state.in_bounds(move_target):
			main._on_tile_clicked(move_target)
			var moved_unit = main.state.get_unit_by_id(int(own_unit["id"]))
			ok = _expect(not moved_unit.is_empty() and moved_unit["pos"] == move_target, "ui click moves unit") and ok
			ok = _expect(not main.undo_history.is_empty(), "unit move creates undo snapshot") and ok
			main._on_undo_pressed()
			var undone_unit = main.state.get_unit_by_id(int(own_unit["id"]))
			ok = _expect(not undone_unit.is_empty() and undone_unit["pos"] == original_pos, "undo restores unit move") and ok
			own_unit = undone_unit
		var target_pos = own_unit["pos"] + Vector2i(1, 0)
		if not main.state.in_bounds(target_pos) or not main.state.occupant_at(target_pos).is_empty():
			target_pos = own_unit["pos"] + Vector2i(-1, 0)
		if main.state.in_bounds(target_pos) and main.state.occupant_at(target_pos).is_empty():
			var neutral = main.state._add_building("据点", -1, target_pos, 0)
			neutral["hp"] = 5.0
			main.state.update_vision()
			own_unit["remaining_attacks"] = 1
			main._on_tile_clicked(own_unit["pos"])
			ok = _expect(main.board.attack_tiles.has(target_pos), "ui marks adjacent neutral building attackable") and ok
			main._on_tile_clicked(target_pos)
			ok = _expect(float(neutral.get("hp", 5.0)) < 5.0, "ui click attacks neutral building") and ok
	main._clear_selection()
	ok = _expect(main.selected_unit_id == -1 and main.selected_building_id == -1, "main selection clears") and ok
	main._on_surrender_pressed()
	ok = _expect(main.state.game_over, "surrender ends two-player game") and ok
	ok = _expect(main.game_over_panel.visible, "game over settlement opens") and ok
	ok = _expect(main.game_over_panel.get_child_count() > 0, "settlement panel has content") and ok
	main._on_restart_pressed()
	ok = _expect(not main.state.game_over and not main.game_over_panel.visible, "restart clears settlement") and ok
	main._on_player_count_pressed(4)
	ok = _expect(main.state.players.size() == 4, "main switches to four players") and ok
	ok = _expect(main.state.width == 80 and main.state.height == 80, "four-player map size matches original") and ok
	main._return_to_main_menu()
	ok = _expect(main.menu_layer.visible and main.menu_buttons.visible and not main.board.visible, "return to main menu from game") and ok
	main.queue_free()
	if ok:
		print("Godot main interaction test passed")
		quit(0)
	else:
		push_error("Godot main interaction test failed")
		quit(1)

func _expect(condition: bool, label: String) -> bool:
	if not condition:
		push_error("Interaction check failed: " + label)
	return condition

func _player_hq(main, pid: int) -> Dictionary:
	for building in main.state.buildings:
		if str(building.get("type", "")) == "大本营" and int(building.get("pid", -1)) == pid:
			return building
	return {}

func _collect_text(node: Node) -> String:
	var parts: Array[String] = []
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_collect_text(child))
	return "\n".join(parts)
