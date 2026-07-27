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
	ok = _expect(not main.game_settings_button.visible, "in-game settings button stays hidden on main menu") and ok
	var viewport_width = main.get_viewport().get_visible_rect().size.x
	ok = _expect(absf(main.game_encyclopedia_button.get_global_rect().end.x - viewport_width) <= 2.0, "encyclopedia button aligns with top-right edge") and ok
	ok = _expect(absf(main.game_settings_button.get_global_rect().end.x - main.game_encyclopedia_button.get_global_rect().position.x) <= 2.0, "settings button sits directly left of encyclopedia") and ok
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
	var building_text = main.encyclopedia_content.get_parsed_text()
	ok = _expect(building_text.find("战斗型") >= 0 and building_text.find("30") >= 0 and building_text.find("0.5") >= 0, "encyclopedia shows combat outpost stats") and ok
	ok = _expect(building_text.find("经济型") >= 0 and building_text.find("20") >= 0, "encyclopedia shows economic outpost stats") and ok
	ok = _expect(main._building_action_info_text("outpost-combat").find("HP 30，护甲 0.5") >= 0, "combat outpost tooltip matches stats") and ok
	ok = _expect(main._building_action_info_text("outpost-economic").find("HP 20，护甲 0") >= 0, "economic outpost tooltip matches stats") and ok
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
	ok = _expect(main.game_settings_button.visible, "in-game settings button is visible") and ok
	ok = _expect(main.hud_bottom_panel.get_child_count() == 3, "bottom bar only keeps tactical controls") and ok
	main._toggle_game_settings()
	ok = _expect(main.settings_panel.visible and main.settings_game_actions.visible, "gear opens in-game settings and match controls") and ok
	var in_game_settings_text = _collect_text(main.settings_panel)
	ok = _expect(in_game_settings_text.find("分辨率") >= 0 and in_game_settings_text.find("音乐音量") >= 0 and in_game_settings_text.find("音效音量") >= 0, "in-game settings include display and audio controls") and ok
	ok = _expect(in_game_settings_text.find("重新开始") >= 0 and in_game_settings_text.find("返回主菜单") >= 0 and in_game_settings_text.find("投降") >= 0, "in-game settings include match management controls") and ok
	main._close_settings_panel()
	ok = _expect(not main.settings_panel.visible, "in-game settings can be closed") and ok
	ok = _expect(not main.state.fog_enabled, "local hotseat can disable fog of war") and ok
	ok = _expect(main.state.is_visible(0, Vector2i(main.state.width - 1, main.state.height - 1)), "disabled fog reveals full map") and ok
	ok = _expect(main.state.width == 48 and main.state.height == 24, "two-player map uses the fast-match size") and ok
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
		var tier1_actions = _collect_text(main.action_panel)
		ok = _expect(tier1_actions.find("反器械枪") < 0 and tier1_actions.find("穿甲炮") < 0, "locked equipment remains hidden before hq upgrade") and ok
		ok = _expect(tier1_actions.find("SpaceX") < 0, "locked strategic technology remains hidden before hq upgrade") and ok
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
			main.sfx_player.stop()
			main.sfx_player.stream = null
			main._on_tile_clicked(move_target)
			var moved_unit = main.state.get_unit_by_id(int(own_unit["id"]))
			ok = _expect(not moved_unit.is_empty() and moved_unit["pos"] == move_target, "ui click moves unit") and ok
			ok = _expect(main.sfx_player.stream == null, "unit movement does not play a sound effect") and ok
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
			main.sfx_player.stop()
			main.sfx_player.stream = null
			main._on_tile_clicked(target_pos)
			ok = _expect(float(neutral.get("hp", 5.0)) < 5.0, "ui click attacks neutral building") and ok
			ok = _expect(main.sfx_player.stream != null, "unit attack plays a sound effect") and ok
	var group_units: Array[int] = []
	var group_anchor = own_hq["pos"] + Vector2i(2, 2)
	for offset in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var spawn_pos: Vector2i = group_anchor + offset
		if main.state.in_bounds(spawn_pos) and main.state.occupant_at(spawn_pos).is_empty():
			var group_unit = main.state._add_unit("士兵", main.state.current_player, spawn_pos)
			group_units.append(int(group_unit["id"]))
	if group_units.size() >= 2:
		var select_start = main.board.tile_rect(group_anchor).position + Vector2(2, 2)
		var select_end = main.board.tile_rect(group_anchor + Vector2i(1, 1)).end - Vector2(2, 2)
		_send_left_drag(main.board, select_start, select_end, true, false)
		ok = _expect(main.board.selected_group_unit_ids.size() == group_units.size(), "box selection is shown on board") and ok
		var before_positions: Array[Vector2i] = []
		for unit_id in group_units:
			before_positions.append(main.state.get_unit_by_id(unit_id)["pos"])
		var group_target = group_anchor + Vector2i(5, 0)
		_send_left_click(main.board, main.board.tile_rect(group_target).get_center())
		var after_positions: Array[Vector2i] = []
		for unit_id in group_units:
			after_positions.append(main.state.get_unit_by_id(unit_id)["pos"])
		ok = _expect(after_positions != before_positions, "group move advances units toward target") and ok
		var unique_positions = {}
		for pos in after_positions:
			unique_positions["%d,%d" % [pos.x, pos.y]] = true
		ok = _expect(unique_positions.size() == after_positions.size(), "group move assigns non-overlapping destinations") and ok
		var min_pos: Vector2i = after_positions[0]
		var max_pos: Vector2i = after_positions[0]
		for pos in after_positions:
			min_pos = Vector2i(min(min_pos.x, pos.x), min(min_pos.y, pos.y))
			max_pos = Vector2i(max(max_pos.x, pos.x), max(max_pos.y, pos.y))
		_send_left_drag(main.board, main.board.tile_rect(min_pos).position + Vector2(2, 2), main.board.tile_rect(max_pos).end - Vector2(2, 2), false, true)
		ok = _expect(main.pending_formation_unit_ids.size() == group_units.size(), "alt-left box selection starts formation creation") and ok
		main.formation_name_input.text = "测试编队"
		main._confirm_formation_name()
		ok = _expect(main.formations.size() == 1 and main.formations[0]["name"] == "测试编队", "formation can be named and saved") and ok
		main._select_formation(0)
		ok = _expect(main.selected_group_unit_ids.size() == group_units.size(), "formation menu reselects living units") and ok
	main._clear_selection()
	ok = _expect(main.selected_unit_id == -1 and main.selected_building_id == -1, "main selection clears") and ok
	main._on_surrender_pressed()
	ok = _expect(main.state.game_over, "surrender ends two-player game") and ok
	ok = _expect(main.game_over_panel.visible, "game over settlement opens") and ok
	ok = _expect(main.game_over_panel.get_child_count() > 0, "settlement panel has content") and ok
	main._on_restart_pressed()
	ok = _expect(not main.state.game_over and not main.game_over_panel.visible, "restart clears settlement") and ok
	main._on_player_count_pressed(3)
	ok = _expect(main.state.players.size() == 3, "main switches to three players") and ok
	ok = _expect(main.state.width == 48 and main.state.height == 48, "three-player map uses the fast-match size") and ok
	main._on_player_count_pressed(4)
	ok = _expect(main.state.players.size() == 4, "main switches to four players") and ok
	ok = _expect(main.state.width == 60 and main.state.height == 60, "four-player map uses the fast-match size") and ok
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

func _send_left_drag(board, start: Vector2, finish: Vector2, ctrl: bool, alt: bool) -> void:
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	press.ctrl_pressed = ctrl
	press.alt_pressed = alt
	board._unhandled_input(press)
	var motion = InputEventMouseMotion.new()
	motion.position = finish
	motion.ctrl_pressed = ctrl
	motion.alt_pressed = alt
	board._unhandled_input(motion)
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = finish
	release.ctrl_pressed = ctrl
	release.alt_pressed = alt
	board._unhandled_input(release)

func _send_left_click(board, position: Vector2) -> void:
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	board._unhandled_input(press)
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	board._unhandled_input(release)
