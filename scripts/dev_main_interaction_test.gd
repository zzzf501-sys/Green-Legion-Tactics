extends SceneTree

const MainScript = preload("res://scripts/main.gd")

func _initialize() -> void:
	var ok = true
	var main = MainScript.new()
	get_root().add_child(main)
	await process_frame
	await process_frame
	main.bgm_player.stop()
	main.bgm_player.stream = null
	ok = _expect(main.state != null, "main state exists") and ok
	ok = _expect(main.board != null, "main board exists") and ok
	ok = _expect(main.info_panel is PanelContainer and not main.info_panel.visible, "hover information card starts hidden") and ok
	var encyclopedia_background = main.encyclopedia_content.get_theme_stylebox("normal")
	ok = _expect(encyclopedia_background is StyleBoxFlat and encyclopedia_background.bg_color == Color(0.0, 0.0, 0.0, 1.0), "encyclopedia body uses an opaque pure-black background") and ok
	var encyclopedia_font = main.encyclopedia_content.get_theme_font("normal_font")
	ok = _expect(encyclopedia_font is SystemFont and encyclopedia_font.font_names.has("Microsoft YaHei UI"), "encyclopedia uses a readable regular Chinese UI font") and ok
	var action_hover_fixture := Button.new()
	main.add_child(action_hover_fixture)
	action_hover_fixture.tooltip_text = "legacy delayed tooltip"
	main._bind_action_hover(action_hover_fixture, "即时详情")
	ok = _expect(action_hover_fixture.tooltip_text.is_empty(), "action hover disables the delayed native tooltip") and ok
	main.game_started = true
	action_hover_fixture.mouse_entered.emit()
	ok = _expect(main.info_panel.visible and main.info_label.text.find("即时详情") >= 0, "action hover keeps the immediate information card") and ok
	action_hover_fixture.mouse_exited.emit()
	ok = _expect(not main.info_panel.visible, "immediate information card hides when hover ends") and ok
	main.game_started = false
	action_hover_fixture.queue_free()
	ok = _expect(main.menu_layer != null and main.menu_layer.visible, "main menu visible on boot") and ok
	ok = _expect(main.menu_buttons != null and main.menu_buttons.visible, "main menu buttons visible on boot") and ok
	ok = _expect(_collect_text(main.menu_buttons).find("人机对战") >= 0, "main menu exposes AI battle mode") and ok
	ok = _expect(not main.board.visible, "board hidden behind menu on boot") and ok
	ok = _expect(not main.game_settings_button.visible, "in-game settings button stays hidden on main menu") and ok
	main._start_ai_game()
	ok = _expect(main.vs_ai and main.player_count == 2, "AI battle starts as a two-player match") and ok
	ok = _expect(main._local_view_player() == 0, "AI battle keeps the human fog perspective") and ok
	main._on_end_turn_pressed()
	await create_timer(0.8).timeout
	ok = _expect(main.state.current_player == 0 and not main.ai_thinking, "AI completes its turn and returns control") and ok
	ok = _expect(_count_units_for(main, 1) >= 2, "AI produces an opening force") and ok
	ok = _expect(main._can_control_current_turn(), "human can act after AI turn") and ok
	main._return_to_main_menu()
	ok = _expect(not main.vs_ai and main.menu_buttons.visible, "leaving AI battle returns to normal menu state") and ok
	main._show_online_menu()
	ok = _expect(main.online_menu_panel.visible, "online menu opens") and ok
	ok = _expect(main.online_room_input.visible and main.online_room_input.placeholder_text.find("输入房间号") >= 0, "online menu exposes room id input") and ok
	main.online_room_input.text = ""
	main._on_online_join_pressed()
	ok = _expect(main.online_status_label.text == "先输入房间号", "empty room id is rejected with a visible message") and ok
	main._show_menu_home()
	var viewport_width = main.get_viewport().get_visible_rect().size.x
	ok = _expect(absf(main.game_encyclopedia_button.get_global_rect().end.x - viewport_width) <= 2.0, "encyclopedia button aligns with top-right edge") and ok
	ok = _expect(absf(main.game_settings_button.get_global_rect().end.x - main.game_encyclopedia_button.get_global_rect().position.x) <= 2.0, "settings button sits directly left of encyclopedia") and ok
	main._show_encyclopedia()
	ok = _expect(main.encyclopedia_panel.visible, "encyclopedia opens") and ok
	ok = _expect(not main.menu_buttons.visible, "menu buttons hidden behind encyclopedia") and ok
	main._render_encyclopedia_chapter("ch0")
	await process_frame
	var rules_text = main._era_rules_bbcode()
	ok = _expect(rules_text.find("E1-E5 五时代规则") >= 0, "encyclopedia has five-era rules chapter") and ok
	ok = _expect(rules_text.find("战役优势与终局") >= 0, "encyclopedia explains campaign and endgame rules") and ok
	main._render_encyclopedia_chapter("ch1")
	await process_frame
	var unit_chapter_text: String = main.encyclopedia_content.get_parsed_text()
	ok = _expect(unit_chapter_text.find("战团：石斧") >= 0 and unit_chapter_text.find("无人机/电子战：干扰吊舱") >= 0, "unit encyclopedia renders all-era equipment image labels") and ok
	ok = _expect(unit_chapter_text.find("研究 3.0 金 / 1 回合　安装 0.5 金") >= 0 and unit_chapter_text.find("冲锋首次攻击额外伤害：+0.8") >= 0, "unit encyclopedia shows equipment costs and numeric effects") and ok
	ok = _expect(unit_chapter_text.find("作用半径：6 格") >= 0 and unit_chapter_text.find("范围内敌军视野：-3.0") >= 0, "unit encyclopedia shows electronic warfare numeric effects") and ok
	ok = _expect(unit_chapter_text.find("贴图待补") < 0, "unit encyclopedia has no missing mapped sprites") and ok
	ok = _expect(main.db.units.has("战团") and main.db.units.has("无人战车"), "encyclopedia unit chapter spans E1-E5") and ok
	ok = _expect(main.db.equipment_for("战团").size() == 2 and main.db.equipment_for("无人战车").size() == 2, "encyclopedia unit data includes equipment details") and ok
	main._render_encyclopedia_chapter("ch2")
	await process_frame
	var building_chapter_text: String = main.encyclopedia_content.get_parsed_text()
	ok = _expect(building_chapter_text.find("E1 大本营") >= 0 and building_chapter_text.find("E5 防御工事") >= 0 and building_chapter_text.find("中央指挥点：激活") >= 0, "building encyclopedia renders all building asset groups") and ok
	ok = _expect(building_chapter_text.find("贴图待补") < 0, "building encyclopedia has no missing mapped sprites") and ok
	ok = _expect(building_chapter_text.find("据点完整功能") >= 0 and building_chapter_text.find("E1只有战团") >= 0 and building_chapter_text.find("周围8格") >= 0, "encyclopedia explains base outpost production and spawn restrictions") and ok
	ok = _expect(building_chapter_text.find("火力和支援单位始终只能从大本营生产") >= 0 and building_chapter_text.find("驻扎恢复35%") >= 0, "encyclopedia explains outpost branch and garrison roles") and ok
	ok = _expect(building_chapter_text.find("占领当回合及紧接的一回合") >= 0 and building_chapter_text.find("升级进度和现代化全部清零") >= 0, "encyclopedia explains outpost capture recovery and reset") and ok
	var building_text = main._encyclopedia_buildings_bbcode()
	ok = _expect(building_text.find("建筑大全") >= 0, "encyclopedia has buildings chapter") and ok
	ok = _expect(building_text.find("51.0") >= 0 and building_text.find("1.5") >= 0, "encyclopedia shows current E2 combat outpost stats") and ok
	ok = _expect(building_text.find("34.0") >= 0 and building_text.find("3.0") >= 0, "encyclopedia shows current E2 economic outpost stats") and ok
	ok = _expect(main._building_action_info_text("outpost-combat").find("HP 51.0，护甲 1.5") >= 0, "combat outpost tooltip matches data") and ok
	ok = _expect(main._building_action_info_text("outpost-economic").find("HP 34.0，护甲 0.5") >= 0, "economic outpost tooltip matches data") and ok
	main._render_encyclopedia_chapter("ch3")
	await process_frame
	var tech_text = main._era_tech_bbcode()
	ok = _expect(tech_text.find("科技与装备") >= 0, "encyclopedia has tech chapter") and ok
	ok = _expect(tech_text.find("大本营升级完成后开放对应时代") >= 0 and tech_text.find("全局时代开放只允许排队升级大本营") >= 0, "encyclopedia explains the HQ era research gate") and ok
	ok = _expect(tech_text.find("科技采用硬前置树") >= 0 and tech_text.find("有组织采集 → 道路驿站") >= 0, "encyclopedia explains the hard prerequisite tree") and ok
	ok = _expect(main.db.strategic_techs.has("SpaceX 星链计划"), "encyclopedia data has strategic tech") and ok
	var logistics_hover = main._tech_info_text("e3_industrial_logistics", main.db.technology_data("e3_industrial_logistics"))
	ok = _expect(logistics_hover.find("×1.20") >= 0 and logistics_hover.find("只取最高倍率") >= 0, "logistics technology hover explains its effective multiplier") and ok
	main._render_encyclopedia_chapter("ch4")
	await process_frame
	var status_text: String = main.encyclopedia_content.get_parsed_text()
	ok = _expect(status_text.find("后勤是什么意思") >= 0 and status_text.find("4.5 × 0.8^(n-1)") >= 0, "status encyclopedia explains the logistics formula") and ok
	ok = _expect(status_text.find("只影响资源采集器收入") >= 0 and status_text.find("不会把1.10、1.20等倍率相乘") >= 0, "status encyclopedia defines logistics scope and non-stacking") and ok
	ok = _expect(status_text.find("智能后勤") >= 0 and status_text.find("6.30 / 5.04") >= 0, "status encyclopedia lists E1-E5 logistics examples") and ok
	ok = _expect(status_text.find("22 / 24 / 26 / 28 / 30") >= 0, "status encyclopedia uses current command capacity values") and ok
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
	var era_test_player: Dictionary = main.state.players[main.state.current_player]
	var saved_player_era = era_test_player.get("era", 1)
	var saved_player_tier = era_test_player.get("tier", 1)
	era_test_player["era"] = 1
	era_test_player["tier"] = 2
	main._refresh_ui()
	ok = _expect(main._player_era(main.state.current_player) == 2 and main.status_label.text.find("E2 冷兵器战争") >= 0, "top status follows the upgraded HQ era instead of the stale era field") and ok
	era_test_player["era"] = saved_player_era
	era_test_player["tier"] = saved_player_tier
	main._refresh_ui()
	main.state.research_notifications.append({"pid": 0, "name": "测试科技"})
	main._show_pending_research_notifications()
	ok = _expect(main.research_notice_panel.visible and main.research_notice_label.text.find("科技研究完成：测试科技") >= 0, "completed research shows a visible notification") and ok
	main.research_notice_panel.visible = false
	ok = _expect(main.game_settings_button.visible, "in-game settings button is visible") and ok
	ok = _expect(main.hud_bottom_panel.get_child_count() == 5 and not main.unit_bottom_actions.visible, "bottom bar includes formations, technology tree and contextual unit actions") and ok
	ok = _expect(main.tech_tree_button != null and main.tech_tree_button.text == "科技树", "bottom bar exposes the technology tree button") and ok
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
		main.state.players[main.state.current_player]["gold"] = 30.0
		main._on_tile_clicked(own_hq["pos"])
		var locked_actions = _collect_text(main.action_panel)
		ok = _expect(locked_actions.find("资源采集器") < 0, "collector action stays hidden before organized gathering") and ok
		ok = _expect(locked_actions.find("有组织采集") < 0, "technology nodes no longer clutter the hq action panel") and ok
		main._open_tech_tree()
		await process_frame
		var tree_text = _collect_text(main.tech_tree_graph)
		ok = _expect(main.tech_tree_overlay.visible and tree_text.find("E1  部落战争") >= 0 and tree_text.find("E5  信息化战争") >= 0, "technology overlay opens with all five era columns") and ok
		ok = _expect(main.tech_tree_graph.links.size() >= 20, "technology overlay draws prerequisite arrows") and ok
		var gathering_button = _find_button_containing(main.tech_tree_graph, "有组织采集")
		ok = _expect(gathering_button != null and not gathering_button.disabled, "organized gathering is directly purchasable in the technology tree") and ok
		var saved_turn = main.state.turn
		main.state.turn = 14
		main._rebuild_tech_tree()
		await process_frame
		var global_e2_button = _find_button_containing(main.tech_tree_graph, "常备方阵")
		ok = _expect(main.state.player_era(main.state.current_player) == 1 and global_e2_button != null and global_e2_button.disabled, "global E2 does not bypass the HQ E2 research gate") and ok
		main.state.turn = saved_turn
		main._rebuild_tech_tree()
		await process_frame
		gathering_button = _find_button_containing(main.tech_tree_graph, "有组织采集")
		if gathering_button != null:
			gathering_button.mouse_entered.emit()
			ok = _expect(main.info_panel.visible and main.info_label.text.find("4.0 金 / 1 回合") >= 0 and main.info_label.text.find("解锁：资源采集器") >= 0, "core technology hover shows research terms and unlocks") and ok
			gathering_button.mouse_exited.emit()
			gathering_button.pressed.emit()
			ok = _expect(not main.state.research_entry(main.state.current_player, "有组织采集").is_empty(), "clicking a technology node purchases its research") and ok
			main.state.players[main.state.current_player]["researching"].clear()
		main._on_build_collector_pressed(int(own_hq["id"]))
		ok = _expect(main.build_mode.is_empty(), "collector placement cannot start before organized gathering") and ok
		main.state.players[main.state.current_player]["technology"].append("e1_organized_gathering")
		main.state.players[main.state.current_player]["researched"].append("e1_organized_gathering")
		main._rebuild_tech_tree()
		await process_frame
		var unlocked_tree_text = _collect_text(main.tech_tree_graph)
		ok = _expect(unlocked_tree_text.find("✓ 有组织采集") >= 0 and unlocked_tree_text.find("木栅工事") >= 0, "technology tree shows completed nodes and their newly available child") and ok
		main._close_tech_tree()
		ok = _expect(not main.tech_tree_overlay.visible, "top-right close action hides the technology tree") and ok
		main._on_tile_clicked(own_hq["pos"])
		ok = _expect(main.selected_building_id == int(own_hq["id"]), "click hq selects building") and ok
		ok = _expect(main.board.selected_building_id == int(own_hq["id"]), "board building selection set") and ok
		main._on_tile_hovered(own_hq["pos"])
		ok = _expect(main.info_panel.visible and main.info_label.text.find("建筑") >= 0 and main.info_label.text.find("HP") >= 0, "own building hover shows building stats") and ok
		var tier1_actions = _collect_text(main.action_panel)
		ok = _expect(tier1_actions.find("反器械枪") < 0 and tier1_actions.find("穿甲炮") < 0, "locked equipment remains hidden before hq upgrade") and ok
		ok = _expect(tier1_actions.find("SpaceX") < 0, "locked strategic technology remains hidden before hq upgrade") and ok
		main._on_build_collector_pressed(int(own_hq["id"]))
		ok = _expect(main.build_mode == "资源采集器" and not main.action_container_panel.visible, "collector placement hides the blocking action panel") and ok
		ok = _expect(not main.board.build_tiles.is_empty(), "collector placement keeps valid tiles for hit testing") and ok
		if not main.board.build_tiles.is_empty():
			var valid_preview: Vector2i = main.board.build_tiles[0]
			main.board.hover_tile = valid_preview
			ok = _expect(main.board.build_preview_tile() == valid_preview, "collector preview follows the hovered valid tile") and ok
			main.board.hover_tile = own_hq["pos"]
			ok = _expect(main.board.build_preview_tile() == Vector2i(-1, -1), "collector preview stays hidden on invalid tiles") and ok
		main._clear_selection()
		main._refresh_ui()
		main._on_produce_pressed(int(own_hq["id"]), "战团")
		ok = _expect(main.state.units.size() == 1 and not main.undo_history.is_empty(), "produce action creates undo snapshot") and ok
		main._on_undo_pressed()
		ok = _expect(main.state.units.size() == 0, "undo restores unit production") and ok
		ok = _expect(main.state.produce_unit(int(own_hq["id"]), "战团"), "produce first warband from hq") and ok
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
	var enemy_building: Dictionary = {}
	for building in main.state.buildings:
		if int(building.get("pid", -1)) != main.state.current_player and int(building.get("pid", -1)) >= 0:
			enemy_building = building
			break
	if not enemy_building.is_empty():
		main._on_tile_hovered(enemy_building["pos"])
		ok = _expect(main.info_panel.visible and main.info_label.text.find("建筑") >= 0 and main.info_label.text.find("HP") >= 0, "visible enemy building hover shows owner and stats") and ok
	var own_outpost: Dictionary = {}
	for building in main.state.buildings:
		if building["type"] == "据点":
			own_outpost = building
			own_outpost["pid"] = main.state.current_player
			own_outpost["captured"] = true
			own_outpost["capture_turn"] = -99
			break
	if not own_outpost.is_empty():
		main.state.players[main.state.current_player]["tier"] = 2
		main.state.players[main.state.current_player]["era"] = 2
		main.state.players[main.state.current_player]["gold"] = 30.0
		ok = _expect(main.state.upgrade_outpost(int(own_outpost["id"]), "combat"), "start combat outpost upgrade") and ok
		ok = _expect(main.state.can_produce(own_outpost, "战团"), "selected outpost can produce while upgrading") and ok
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
		ok = _expect(not main.action_container_panel.visible, "selected unit no longer opens the blocking left panel") and ok
		ok = _expect(main.unit_bottom_actions.visible and _collect_text(main.unit_bottom_actions).find("待机") >= 0, "selected unit actions sit beside formations") and ok
		main._on_tile_hovered(own_unit["pos"])
		ok = _expect(main.info_panel.visible and main.info_label.text.find("护甲") >= 0, "own unit hover card shows armor") and ok
		var enemy_hover_pos = own_unit["pos"] + Vector2i(4, 0)
		if not main.state.in_bounds(enemy_hover_pos) or not main.state.occupant_at(enemy_hover_pos).is_empty():
			enemy_hover_pos = own_unit["pos"] + Vector2i(0, 4)
		if main.state.in_bounds(enemy_hover_pos) and main.state.occupant_at(enemy_hover_pos).is_empty():
			var enemy_hover_unit = main.state._add_unit("战团", 1, enemy_hover_pos)
			main.state.update_vision()
			main._on_tile_hovered(enemy_hover_unit["pos"])
			ok = _expect(main.info_panel.visible and main.info_label.text.find("单位") >= 0 and main.info_label.text.find("HP") >= 0, "visible enemy hover shows unit stats") and ok
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
			var group_unit = main.state._add_unit("战团", main.state.current_player, spawn_pos)
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
	# Avoid retaining headless MP3 playback objects while still testing the game-over UI.
	main.db.audio["victory"] = ""
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
	main.bgm_player.stop()
	main.sfx_player.stop()
	await process_frame
	main.bgm_player.stream = null
	main.sfx_player.stream = null
	await process_frame
	main.free()
	main = null
	await process_frame
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

func _count_units_for(main, pid: int) -> int:
	var count = 0
	for unit in main.state.units:
		if int(unit.get("pid", -1)) == pid:
			count += 1
	return count

func _collect_text(node: Node) -> String:
	var parts: Array[String] = []
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_collect_text(child))
	return "\n".join(parts)

func _find_button_containing(node: Node, needle: String) -> Button:
	if node is Button and (node as Button).text.find(needle) >= 0:
		return node as Button
	for child in node.get_children():
		var found = _find_button_containing(child, needle)
		if found != null:
			return found
	return null

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
