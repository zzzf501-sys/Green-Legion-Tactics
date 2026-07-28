extends Node

const GameDatabaseScript = preload("res://scripts/core/game_database.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const BoardViewScript = preload("res://scripts/view/board_view.gd")
const TacticalAIScript = preload("res://scripts/ai/tactical_ai.gd")
const PLAYER_COLORS = [
	Color(0.95, 0.18, 0.22),
	Color(0.25, 0.48, 1.0),
	Color(0.20, 0.78, 0.25),
	Color(1.0, 0.82, 0.22)
]

const ERA_NAMES = {
	1: "部落战争",
	2: "冷兵器战争",
	3: "火药战争",
	4: "机械化战争",
	5: "信息化战争"
}
const ERA_OPEN_TURNS = {1: 1, 2: 14, 3: 28, 4: 43, 5: 59}
const GRAND_WAR_TURN = 75
const ERA_END_TURNS = {1: 13, 2: 27, 3: 42, 4: 58, 5: 74}
const ERA_COMMAND_CAPACITY = {1: 22, 2: 24, 3: 26, 4: 28, 5: 30}
const UNIT_EVOLUTION = {
	"战团": "方阵", "方阵": "火枪连", "火枪连": "士兵", "士兵": "网络化步兵",
	"斥候": "骑兵", "骑兵": "龙骑兵", "龙骑兵": "主战坦克", "主战坦克": "无人战车",
	"投石队": "弓弩/投石车", "弓弩/投石车": "野战炮", "野战炮": "自行火炮", "自行火炮": "精确火箭",
	"部落侦察": "轻骑侦察", "轻骑侦察": "工兵/观测队", "工兵/观测队": "吉普", "吉普": "无人机/电子战",
	"坦克": "无人战车", "军用吉普": "无人机/电子战"
}
const UNIT_ROLES = {
	"战团": "战线", "方阵": "战线", "火枪连": "战线", "士兵": "战线", "网络化步兵": "战线",
	"斥候": "机动", "骑兵": "机动", "龙骑兵": "机动", "主战坦克": "机动", "坦克": "机动", "无人战车": "机动",
	"投石队": "火力", "弓弩/投石车": "火力", "野战炮": "火力", "自行火炮": "火力", "精确火箭": "火力",
	"部落侦察": "支援", "轻骑侦察": "支援", "工兵/观测队": "支援", "吉普": "支援", "军用吉普": "支援", "无人机/电子战": "支援"
}
const ERA_UNIT_ROWS = [
	[1, "战团", 1.5, 0.0, 1.0, 3, 1, 4, 1.0, "战线", "相邻战团攻击+0.25，最多+0.5"],
	[1, "斥候", 1.75, 0.0, 1.0, 5, 1, 5, 1.5, "机动", "移动至少3格后首次突袭+0.5"],
	[1, "投石队", 1.0, 0.0, 1.0, 2, 3, 5, 1.5, "火力", "相邻部落侦察时射程+1"],
	[1, "部落侦察", 1.0, 0.0, 0.5, 6, 1, 8, 1.0, "支援", "相邻友军视野+1，可标记"],
	[2, "方阵", 5.5, 0.75, 2.25, 2, 1, 5, 3.0, "战线", "相邻方阵护甲+0.75；对机动+1.5"],
	[2, "骑兵", 5.5, 0.25, 3.0, 5, 1, 6, 5.0, "机动", "直线移动至少4格后首次冲锋+1.5"],
	[2, "弓弩/投石车", 3.5, 0.0, 3.5, 2, 5, 7, 4.5, "火力", "最小射程2；相邻方阵射程+1"],
	[2, "轻骑侦察", 3.5, 0.25, 2.0, 8, 2, 10, 3.5, "支援", "相邻骑兵视野+2，可标记"],
	[3, "火枪连", 6.5, 0.5, 4.5, 3, 4, 6, 4.0, "战线", "相邻火枪连攻击、护甲各+0.5"],
	[3, "龙骑兵", 10.0, 1.0, 6.0, 6, 2, 7, 10.0, "机动", "孤立或侧后目标攻击+3"],
	[3, "野战炮", 9.0, 1.0, 12.0, 2, 7, 9, 12.0, "火力", "最小射程2；移动超过1格不能开火"],
	[3, "工兵/观测队", 6.0, 0.5, 3.0, 4, 2, 11, 6.0, "支援", "相邻炮兵射程+2，可标记/修复/爆破"],
	[4, "士兵", 7.5, 0.0, 5.0, 3, 2, 5, 5.0, "战线", "相邻士兵攻击+1"],
	[4, "主战坦克", 40.0, 8.0, 20.0, 4, 3, 5, 35.0, "机动", "低视野；裸装坦克互射4炮"],
	[4, "自行火炮", 15.0, 5.0, 25.0, 3, 6, 9, 25.0, "火力", "相邻吉普射程+2"],
	[4, "吉普", 15.0, 0.0, 10.0, 8, 3, 11, 15.0, "支援", "相邻单位视野+2，可标记"],
	[5, "网络化步兵", 11.5, 2.0, 7.5, 4, 3, 8, 8.0, "战线", "共享视野；攻击标记目标射程+1"],
	[5, "无人战车", 48.0, 10.0, 24.0, 5, 4, 7, 45.0, "机动", "每架相邻无人机护甲+1，最多+2"],
	[5, "精确火箭", 25.0, 2.0, 36.0, 3, 14, 13, 55.0, "火力", "最小射程3；装填1回合；共享视野攻击"],
	[5, "无人机/电子战", 10.0, 0.0, 0.0, 12, 0, 15, 16.0, "支援", "半径6共享情报；装备决定自杀或干扰"]
]
const ERA_TECH_ROWS = [
	[1, "燧石武器", 3, 1, "解锁投石队及E1武器装备"], [1, "狩猎编组", 3, 1, "解锁斥候与部落侦察"], [1, "有组织采集", 4, 1, "解锁资源采集器"], [1, "木栅工事", 4, 1, "解锁建筑回血与驻扎"],
	[2, "常备方阵", 6, 1, "解锁方阵及其装备"], [2, "驯马术", 6, 1, "解锁骑兵和轻骑侦察"], [2, "复合弓与配重", 7, 2, "解锁弓弩/投石车"], [2, "道路驿站", 9, 2, "后勤倍率升至1.10"],
	[3, "标准化火器", 10, 2, "解锁火枪连"], [3, "龙骑战术", 10, 2, "解锁龙骑兵"], [3, "弹道学", 12, 2, "解锁野战炮"], [3, "野战工兵", 10, 2, "解锁工兵、观测、维修和爆破"], [3, "工业化后勤", 14, 2, "后勤倍率升至1.20"],
	[4, "机械化作战", 18, 2, "解锁士兵"], [4, "装甲战争", 30, 3, "解锁主战坦克"], [4, "自行火力", 24, 2, "解锁自行火炮"], [4, "摩托化侦察", 18, 2, "解锁吉普"], [4, "无线电火控", 22, 2, "后勤倍率升至1.30"],
	[5, "网络化步兵", 30, 2, "解锁网络化步兵和共享视野"], [5, "自主装甲系统", 40, 3, "解锁无人战车"], [5, "精确制导", 45, 3, "解锁精确火箭"], [5, "无人侦察系统", 32, 2, "解锁无人机/电子战"], [5, "电子战", 35, 2, "解锁干扰与反标记"], [5, "智能后勤", 28, 2, "后勤倍率升至1.40"], [5, "SpaceX 星链计划", 85, 3, "全图探索、共享视野与周期扫描"]
]

class StatsChart:
	extends Control
	var game_state
	var metric = ""
	var title = ""
	var colors = [
		Color(0.95, 0.18, 0.22),
		Color(0.25, 0.48, 1.0),
		Color(0.20, 0.78, 0.25),
		Color(1.0, 0.82, 0.22)
	]

	func setup(state_ref, metric_name: String, chart_title: String) -> void:
		game_state = state_ref
		metric = metric_name
		title = chart_title
		custom_minimum_size = Vector2(380, 220)

	func _draw() -> void:
		if game_state == null:
			return
		var rect = Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.07, 0.07, 0.12, 0.96), true)
		draw_rect(rect, Color(0.18, 0.18, 0.28), false, 1.0)
		var pad_l = 46.0
		var pad_t = 30.0
		var pad_r = 14.0
		var pad_b = 28.0
		var chart = Rect2(Vector2(pad_l, pad_t), Vector2(max(1.0, size.x - pad_l - pad_r), max(1.0, size.y - pad_t - pad_b)))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 36.0, 18.0), title, HORIZONTAL_ALIGNMENT_LEFT, 180.0, 14, Color(0.80, 0.72, 0.38))
		for i in range(5):
			var y = chart.position.y + chart.size.y * float(i) / 4.0
			draw_line(Vector2(chart.position.x, y), Vector2(chart.end.x, y), Color(0.18, 0.18, 0.30), 1.0)
		var max_val = 1.0
		var max_count = 1
		for player in game_state.players:
			var turn_data: Array = player.get("stats", {}).get("turn_data", [])
			max_count = max(max_count, turn_data.size())
			for point in turn_data:
				max_val = max(max_val, float(point.get(metric, 0.0)))
		max_val *= 1.15
		for i in range(5):
			var val = max_val - max_val * float(i) / 4.0
			var y = chart.position.y + chart.size.y * float(i) / 4.0
			draw_string(ThemeDB.fallback_font, Vector2(4.0, y + 4.0), str(roundi(val)), HORIZONTAL_ALIGNMENT_RIGHT, pad_l - 8.0, 10, Color(0.48, 0.48, 0.56))
		for pid in range(game_state.players.size()):
			var turn_data: Array = game_state.players[pid].get("stats", {}).get("turn_data", [])
			if turn_data.is_empty():
				continue
			var points: PackedVector2Array = []
			for i in range(turn_data.size()):
				var x = chart.position.x + chart.size.x * float(i) / max(1.0, float(turn_data.size() - 1))
				var y = chart.end.y - chart.size.y * clampf(float(turn_data[i].get(metric, 0.0)) / max_val, 0.0, 1.0)
				points.append(Vector2(x, y))
			if points.size() >= 2:
				draw_polyline(points, colors[pid], 2.0)
			for point in points:
				draw_circle(point, 3.0, colors[pid])

class TechTreeGraph:
	extends Control
	var links: Array[Dictionary] = []

	func set_links(value: Array[Dictionary]) -> void:
		links = value
		queue_redraw()

	func _draw() -> void:
		for link in links:
			var from_rect: Rect2 = link["from"]
			var to_rect: Rect2 = link["to"]
			var color: Color = link.get("color", Color(0.48, 0.62, 0.38, 0.9))
			var start = Vector2(from_rect.end.x, from_rect.get_center().y)
			var finish = Vector2(to_rect.position.x, to_rect.get_center().y)
			if absf(finish.x - start.x) < 16.0:
				start = Vector2(from_rect.get_center().x, from_rect.end.y)
				finish = Vector2(to_rect.get_center().x, to_rect.position.y)
			var mid_x = (start.x + finish.x) * 0.5
			var points = PackedVector2Array([start, Vector2(mid_x, start.y), Vector2(mid_x, finish.y), finish])
			draw_polyline(points, color, 2.0, true)
			var direction = (finish - points[points.size() - 2]).normalized()
			if direction.length_squared() < 0.1:
				direction = Vector2.RIGHT
			var side = Vector2(-direction.y, direction.x)
			var arrow = PackedVector2Array([finish, finish - direction * 11.0 + side * 5.0, finish - direction * 11.0 - side * 5.0])
			draw_colored_polygon(arrow, color)

var db
var state
var board
var ai_controller
var selected_unit_id = -1
var selected_building_id = -1
var hud_top_panel: PanelContainer
var hud_bottom_panel: HBoxContainer
var action_container_panel: PanelContainer
var status_label: Label
var info_panel: Control
var info_label: Label
var action_panel: VBoxContainer
var action_scroll: ScrollContainer
var end_turn_button: Button
var undo_button: Button
var restart_button: Button
var main_menu_button: Button
var surrender_button: Button
var formations_button: Button
var tech_tree_button: Button
var unit_bottom_actions: HBoxContainer
var game_encyclopedia_button: Button
var game_settings_button: Button
var game_over_panel: PanelContainer
var game_over_status_label: Label
var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var player_count = 2
var online_socket: WebSocketPeer
var online_connected = false
var online_room_id = ""
var online_player_id = -1
var online_is_host = false
var online_applying_remote = false
var online_manual_leave = false
var online_reconnect_active = false
var online_inline_panel: VBoxContainer
var online_url_input: LineEdit
var online_room_input: LineEdit
var online_status_label: Label
var menu_layer: Control
var player_select_panel: PanelContainer
var local_fog_checkbox: CheckBox
var encyclopedia_panel: PanelContainer
var online_menu_panel: PanelContainer
var settings_panel: PanelContainer
var controls_panel: PanelContainer
var tech_tree_overlay: Control
var tech_tree_graph: TechTreeGraph
var research_notice_panel: PanelContainer
var research_notice_label: Label
var research_notice_serial = 0
var settings_game_actions: VBoxContainer
var settings_back_button: Button
var menu_buttons: VBoxContainer
var encyclopedia_content: RichTextLabel
var encyclopedia_nav: VBoxContainer
var game_started = false
var bgm_volume_percent = 65
var sfx_volume_percent = 80
var selected_resolution = Vector2i(1280, 720)
var action_panel_width = 232
var show_legacy_equipment = false
var fullscreen_enabled = false
var local_fog_enabled = true
var build_mode = ""
var build_origin_id = -1
var undo_history: Array = []
var selected_group_unit_ids: Array[int] = []
var formations: Array[Dictionary] = []
var formation_menu_open = false
var pending_formation_unit_ids: Array[int] = []
var formation_dialog: ConfirmationDialog
var formation_name_input: LineEdit
var vs_ai = false
var ai_player_id = 1
var ai_thinking = false

func _ready() -> void:
	db = GameDatabaseScript.new()
	db.load_data()
	ai_controller = TacticalAIScript.new()
	ai_controller.setup(db)
	state = GameStateScript.new()
	_setup_state()
	_create_audio()
	_create_board()
	_create_ui()
	_create_menu_ui()
	_refresh_ui()
	_set_game_visible(false)
	call_deferred("_layout_game_ui")

func _process(_delta: float) -> void:
	_poll_online()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_set_fullscreen(not fullscreen_enabled)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and game_started:
		if tech_tree_overlay != null and tech_tree_overlay.visible:
			_close_tech_tree()
			return
		_clear_selection()
		_refresh_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_game_ui()

func _layout_game_ui() -> void:
	var size = get_viewport().get_visible_rect().size
	if board != null:
		board.set_viewport_size(size)
	if hud_top_panel != null:
		hud_top_panel.position = Vector2.ZERO
		hud_top_panel.size = Vector2(size.x, 28)
	if game_encyclopedia_button != null:
		game_encyclopedia_button.position = Vector2(max(0.0, size.x - 74.0), 0.0)
		game_encyclopedia_button.size = Vector2(74.0, 28.0)
	if game_settings_button != null:
		game_settings_button.position = Vector2(max(0.0, size.x - 110.0), 0.0)
		game_settings_button.size = Vector2(36.0, 28.0)
	if action_container_panel != null:
		action_container_panel.position = Vector2(0, 28)
		action_container_panel.size = Vector2(action_panel_width, max(120.0, size.y - 56))
	if action_scroll != null:
		action_scroll.custom_minimum_size = Vector2(action_panel_width - 8, max(120.0, size.y - 68))
	if hud_bottom_panel != null:
		hud_bottom_panel.position = Vector2(max(190.0, size.x * 0.5 - 170.0), max(40.0, size.y - 42.0))
	if info_panel != null:
		info_panel.size = Vector2(min(380.0, max(280.0, size.x - 24.0)), 112.0)

func _setup_state() -> void:
	var map_size = Vector2i(48, 24)
	if player_count == 3:
		map_size = Vector2i(48, 48)
	elif player_count == 4:
		map_size = Vector2i(60, 60)
	state.setup(db, map_size.x, map_size.y, player_count)
	state.fog_enabled = true if (online_connected or online_is_host or online_player_id >= 0) else local_fog_enabled
	state.update_vision()

func _create_audio() -> void:
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	var bgm_path = str(db.audio.get("bgm", ""))
	if not bgm_path.is_empty():
		var bgm_stream = load(bgm_path)
		if bgm_stream != null:
			bgm_player.stream = bgm_stream
			bgm_player.volume_db = _percent_to_db(bgm_volume_percent)
			bgm_player.play()
	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = _percent_to_db(sfx_volume_percent)
	add_child(sfx_player)

func _create_board() -> void:
	board = BoardViewScript.new()
	board.position = Vector2.ZERO
	add_child(board)
	board.setup(state, db)
	_sync_board_view_player()
	board.set_viewport_size(get_viewport().get_visible_rect().size)
	board.tile_clicked.connect(_on_tile_clicked)
	board.tile_hovered.connect(_on_tile_hovered)
	board.group_box_selected.connect(_on_group_box_selected)
	board.group_move_requested.connect(_on_group_move_requested)

func _create_ui() -> void:
	hud_top_panel = PanelContainer.new()
	hud_top_panel.position = Vector2.ZERO
	hud_top_panel.size = Vector2(1280, 28)
	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color(0.04, 0.04, 0.08, 0.82)
	top_style.border_width_bottom = 1
	top_style.border_color = Color(0.18, 0.18, 0.28, 0.65)
	hud_top_panel.add_theme_stylebox_override("panel", top_style)
	add_child(hud_top_panel)

	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	hud_top_panel.add_child(top_bar)

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(1020, 24)
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_bar.add_child(status_label)

	game_encyclopedia_button = Button.new()
	game_encyclopedia_button.text = "百科"
	game_encyclopedia_button.position = Vector2(1206, 0)
	game_encyclopedia_button.size = Vector2(74, 28)
	game_encyclopedia_button.pressed.connect(_open_encyclopedia_overlay)
	add_child(game_encyclopedia_button)

	game_settings_button = Button.new()
	game_settings_button.text = "⚙"
	game_settings_button.tooltip_text = "设置"
	game_settings_button.position = Vector2(1170, 0)
	game_settings_button.size = Vector2(36, 28)
	game_settings_button.pressed.connect(_toggle_game_settings)
	add_child(game_settings_button)


	hud_bottom_panel = HBoxContainer.new()
	hud_bottom_panel.position = Vector2(530, 682)
	hud_bottom_panel.add_theme_constant_override("separation", 8)
	add_child(hud_bottom_panel)

	undo_button = Button.new()
	undo_button.text = "撤回"
	undo_button.pressed.connect(_on_undo_pressed)
	hud_bottom_panel.add_child(undo_button)

	end_turn_button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	hud_bottom_panel.add_child(end_turn_button)

	formations_button = Button.new()
	formations_button.text = "编队"
	formations_button.pressed.connect(_toggle_formation_menu)
	hud_bottom_panel.add_child(formations_button)

	tech_tree_button = Button.new()
	tech_tree_button.text = "科技树"
	tech_tree_button.tooltip_text = "打开科技树并研究科技"
	tech_tree_button.pressed.connect(_open_tech_tree)
	hud_bottom_panel.add_child(tech_tree_button)

	unit_bottom_actions = HBoxContainer.new()
	unit_bottom_actions.add_theme_constant_override("separation", 6)
	unit_bottom_actions.visible = false
	hud_bottom_panel.add_child(unit_bottom_actions)

	formation_dialog = ConfirmationDialog.new()
	formation_dialog.title = "新建编队"
	formation_dialog.ok_button_text = "保存"
	formation_dialog.cancel_button_text = "取消"
	formation_name_input = LineEdit.new()
	formation_name_input.placeholder_text = "输入编队名称"
	formation_name_input.custom_minimum_size = Vector2(300, 34)
	formation_dialog.add_child(formation_name_input)
	formation_dialog.confirmed.connect(_confirm_formation_name)
	add_child(formation_dialog)

	info_panel = PanelContainer.new()
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.visible = false
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.025, 0.03, 0.055, 0.94)
	hover_style.border_color = Color(0.38, 0.48, 0.72, 0.9)
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(4)
	hover_style.content_margin_left = 10
	hover_style.content_margin_right = 10
	hover_style.content_margin_top = 7
	hover_style.content_margin_bottom = 7
	info_panel.add_theme_stylebox_override("panel", hover_style)
	add_child(info_panel)

	info_label = Label.new()
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_panel.add_child(info_label)

	action_container_panel = PanelContainer.new()
	action_container_panel.position = Vector2(0, 28)
	action_container_panel.size = Vector2(action_panel_width, 652)
	var side_style = StyleBoxFlat.new()
	side_style.bg_color = Color(0.035, 0.035, 0.08, 0.82)
	side_style.border_width_right = 1
	side_style.border_color = Color(0.20, 0.22, 0.32, 0.72)
	action_container_panel.add_theme_stylebox_override("panel", side_style)
	add_child(action_container_panel)

	action_scroll = ScrollContainer.new()
	action_scroll.custom_minimum_size = Vector2(action_panel_width - 8, 640)
	action_container_panel.add_child(action_scroll)

	action_panel = VBoxContainer.new()
	action_panel.add_theme_constant_override("separation", 6)
	action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_scroll.add_child(action_panel)

	_create_game_over_panel()
	_create_controls_panel()
	_create_tech_tree_overlay()
	_create_research_notice()

func _create_game_over_panel() -> void:
	game_over_panel = PanelContainer.new()
	game_over_panel.visible = false
	game_over_panel.anchor_left = 0.08
	game_over_panel.anchor_top = 0.08
	game_over_panel.anchor_right = 0.92
	game_over_panel.anchor_bottom = 0.92
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.94)
	style.border_color = Color(0.33, 0.28, 0.18, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	game_over_panel.add_theme_stylebox_override("panel", style)
	add_child(game_over_panel)

	_layout_game_ui()

func _create_tech_tree_overlay() -> void:
	tech_tree_overlay = Control.new()
	tech_tree_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	tech_tree_overlay.visible = false
	tech_tree_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tech_tree_overlay)

	var shade = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.018, 0.025, 0.94)
	tech_tree_overlay.add_child(shade)

	var frame = PanelContainer.new()
	frame.anchor_left = 0.025
	frame.anchor_top = 0.045
	frame.anchor_right = 0.975
	frame.anchor_bottom = 0.96
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.035, 0.045, 0.055, 0.98)
	frame_style.border_color = Color(0.36, 0.48, 0.30, 0.95)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(5)
	frame_style.content_margin_left = 12
	frame_style.content_margin_right = 12
	frame_style.content_margin_top = 8
	frame_style.content_margin_bottom = 12
	tech_tree_overlay.add_child(frame)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	frame.add_child(layout)

	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 42)
	layout.add_child(header)
	var title = Label.new()
	title.text = "科技树"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.90, 0.80, 0.44))
	header.add_child(title)
	var hint = Label.new()
	hint.text = "   大本营升级开放对应时代研究 · 绿色已完成 · 金色研究中 · 灰色未满足时代或前置"
	hint.modulate = Color(0.68, 0.72, 0.70)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hint)
	var close = Button.new()
	close.text = "×"
	close.tooltip_text = "关闭科技树"
	close.custom_minimum_size = Vector2(44, 38)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(_close_tech_tree)
	header.add_child(close)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	tech_tree_graph = TechTreeGraph.new()
	tech_tree_graph.custom_minimum_size = Vector2(1510, 1630)
	scroll.add_child(tech_tree_graph)

func _create_research_notice() -> void:
	research_notice_panel = PanelContainer.new()
	research_notice_panel.anchor_left = 0.5
	research_notice_panel.anchor_right = 0.5
	research_notice_panel.offset_left = -250
	research_notice_panel.offset_right = 250
	research_notice_panel.offset_top = 42
	research_notice_panel.offset_bottom = 104
	research_notice_panel.visible = false
	research_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.12, 0.065, 0.97)
	style.border_color = Color(0.48, 0.78, 0.34, 0.98)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	research_notice_panel.add_theme_stylebox_override("panel", style)
	add_child(research_notice_panel)
	research_notice_label = Label.new()
	research_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	research_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	research_notice_label.add_theme_font_size_override("font_size", 19)
	research_notice_label.add_theme_color_override("font_color", Color(0.90, 0.96, 0.72))
	research_notice_panel.add_child(research_notice_label)

func _show_pending_research_notifications() -> void:
	if state == null or not state.has_method("take_research_notifications"):
		return
	var pid = _local_view_player()
	var completed: Array[String] = state.take_research_notifications(pid)
	if completed.is_empty():
		return
	research_notice_serial += 1
	var serial = research_notice_serial
	research_notice_label.text = "科技研究完成：%s" % "、".join(completed)
	research_notice_panel.visible = true
	get_tree().create_timer(4.0).timeout.connect(func():
		if research_notice_serial == serial and research_notice_panel != null:
			research_notice_panel.visible = false
	)

func _open_tech_tree() -> void:
	if not game_started or tech_tree_overlay == null:
		return
	if encyclopedia_panel != null:
		encyclopedia_panel.visible = false
	if settings_panel != null:
		settings_panel.visible = false
	_rebuild_tech_tree()
	tech_tree_overlay.visible = true

func _close_tech_tree() -> void:
	if tech_tree_overlay != null:
		tech_tree_overlay.visible = false
	_hide_hover_info()

func _rebuild_tech_tree() -> void:
	if tech_tree_graph == null:
		return
	for child in tech_tree_graph.get_children():
		child.queue_free()
	var techs = _core_tech_dictionary()
	var node_rects: Dictionary = {}
	var links: Array[Dictionary] = []
	var column_x = {1: 55.0, 2: 345.0, 3: 635.0, 4: 925.0, 5: 1215.0}
	var route_y = {"line": 95.0, "mobile": 375.0, "firepower": 655.0, "support": 935.0, "development": 1215.0}
	var route_titles = {"line": "战线", "mobile": "机动", "firepower": "火力", "support": "支援", "development": "建设与后勤"}
	for era in range(1, 6):
		var era_label = Label.new()
		era_label.text = "E%d  %s" % [era, ERA_NAMES[era]]
		era_label.position = Vector2(column_x[era], 34)
		era_label.size = Vector2(220, 36)
		era_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		era_label.add_theme_font_size_override("font_size", 20)
		era_label.add_theme_color_override("font_color", Color(0.86, 0.76, 0.38))
		tech_tree_graph.add_child(era_label)
	for route in route_y.keys():
		var route_label = Label.new()
		route_label.text = route_titles[route]
		route_label.position = Vector2(4, route_y[route] - 28)
		route_label.size = Vector2(180, 24)
		route_label.add_theme_color_override("font_color", Color(0.58, 0.68, 0.62))
		tech_tree_graph.add_child(route_label)

	var slot_counts: Dictionary = {}
	for raw_id in techs.keys():
		var tech_id = str(raw_id)
		var tech: Dictionary = techs[raw_id]
		if bool(tech.get("strategic", false)):
			continue
		var era = _era_number(tech.get("era", 1))
		var routes: Array = tech.get("routes", [])
		var route = str(routes[0]) if not routes.is_empty() else "development"
		if not route_y.has(route):
			route = "development"
		var slot_key = "%d|%s" % [era, route]
		var slot = int(slot_counts.get(slot_key, 0))
		slot_counts[slot_key] = slot + 1
		var rect = Rect2(Vector2(column_x[era], route_y[route] + slot * 70.0), Vector2(220, 58))
		node_rects[tech_id] = rect
		_add_core_tech_graph_node(tech_id, tech, rect)

	for raw_id in techs.keys():
		var tech_id = str(raw_id)
		if not node_rects.has(tech_id):
			continue
		for prerequisite in techs[raw_id].get("prerequisites", []):
			var prerequisite_id = str(prerequisite)
			if node_rects.has(prerequisite_id):
				links.append(_tech_tree_link(node_rects[prerequisite_id], node_rects[tech_id], _player_has_technology(prerequisite_id)))

	for route in ["line", "mobile", "firepower", "support"]:
		var units: Array = db.units_for_route(route) if db.has_method("units_for_route") else []
		for era in range(1, mini(6, units.size() + 1)):
			var unit_type = str(units[era - 1])
			var unlock_id = db.technology_unlocking(unit_type) if db.has_method("technology_unlocking") else ""
			var equips = db.equipment_for(unit_type)
			for index in range(mini(2, equips.size())):
				var equip: Dictionary = equips[index]
				var equip_id = "equip|%s|%s" % [unit_type, str(equip.get("name", ""))]
				var rect = Rect2(Vector2(column_x[era] + index * 112.0, route_y[route] + 150.0), Vector2(106, 50))
				node_rects[equip_id] = rect
				_add_equipment_graph_node(unit_type, equip, rect)
				if node_rects.has(unlock_id):
					links.append(_tech_tree_link(node_rects[unlock_id], rect, _player_has_technology(unlock_id)))

	var strategic_y = 1495.0
	var strategic_title = Label.new()
	strategic_title.text = "战略科技"
	strategic_title.position = Vector2(4, strategic_y - 28)
	strategic_title.add_theme_color_override("font_color", Color(0.58, 0.68, 0.62))
	tech_tree_graph.add_child(strategic_title)
	var strategic_index = 0
	for tech_name in db.strategic_techs.keys():
		var tech: Dictionary = db.strategic_techs[tech_name]
		var era = _era_number(tech.get("era", tech.get("tier", 5)))
		var strategic_id = str(tech.get("id", "strategic|%s" % tech_name))
		var rect = Rect2(Vector2(column_x[era], strategic_y + strategic_index * 66.0), Vector2(220, 58))
		node_rects[strategic_id] = rect
		_add_strategic_graph_node(str(tech_name), tech, rect)
		for prerequisite in tech.get("prerequisites", []):
			var prerequisite_id = str(prerequisite)
			if node_rects.has(prerequisite_id):
				links.append(_tech_tree_link(node_rects[prerequisite_id], rect, _player_has_technology(prerequisite_id)))
		strategic_index += 1
	tech_tree_graph.set_links(links)

func _tech_tree_link(from_rect: Rect2, to_rect: Rect2, active: bool) -> Dictionary:
	return {"from": from_rect, "to": to_rect, "color": Color(0.42, 0.72, 0.34, 0.95) if active else Color(0.28, 0.31, 0.34, 0.82)}

func _tech_tree_node_button(text: String, rect: Rect2, state_name: String) -> Button:
	var button = Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 13)
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.set_border_width_all(2)
	style.content_margin_left = 6
	style.content_margin_right = 6
	if state_name == "done":
		style.bg_color = Color(0.07, 0.22, 0.10, 0.98)
		style.border_color = Color(0.30, 0.72, 0.34)
	elif state_name == "researching":
		style.bg_color = Color(0.26, 0.20, 0.05, 0.98)
		style.border_color = Color(0.88, 0.68, 0.20)
	elif state_name == "available":
		style.bg_color = Color(0.08, 0.18, 0.22, 0.98)
		style.border_color = Color(0.30, 0.68, 0.78)
	else:
		style.bg_color = Color(0.09, 0.10, 0.12, 0.98)
		style.border_color = Color(0.28, 0.30, 0.34)
	button.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("disabled", style)
	tech_tree_graph.add_child(button)
	return button

func _add_core_tech_graph_node(tech_id: String, tech: Dictionary, rect: Rect2) -> void:
	var name = str(tech.get("name", tech_id))
	var terms = _technology_research_terms_for_ui(tech_id, tech)
	var active = state.research_entry(state.current_player, name)
	var state_name = "locked"
	var text = "%s\n%.1f金 · %d回合" % [name, float(terms.get("cost", 0.0)), int(terms.get("research_time", 1))]
	if _player_has_technology(tech_id):
		state_name = "done"
		text = "✓ %s\n已完成" % name
	elif not active.is_empty():
		state_name = "researching"
		text = "%s\n研究中 · 剩%d回合" % [name, int(active.get("timer", 0))]
	elif state.can_research_technology(state.current_player, tech_id) and _can_control_current_turn():
		state_name = "available"
	var button = _tech_tree_node_button(text, rect, state_name)
	_bind_action_hover(button, _tech_info_text(tech_id, tech, terms))
	button.disabled = state_name != "available"
	if state_name == "available":
		button.pressed.connect(func(): _on_core_tech_pressed(tech_id, tech))

func _add_equipment_graph_node(unit_type: String, equip: Dictionary, rect: Rect2) -> void:
	var name = str(equip.get("name", ""))
	var key = state.equipment_key(unit_type, name)
	var active = state.research_entry(state.current_player, name)
	var state_name = "locked"
	var text = "%s\n%.1f金 · %d回合" % [name, float(equip.get("research_cost", 0.0)), int(equip.get("research_time", 1))]
	if state.players[state.current_player]["equipment"].has(key):
		state_name = "done"
		text = "✓ %s\n已完成" % name
	elif not active.is_empty():
		state_name = "researching"
		text = "%s\n研究中 · 剩%d" % [name, int(active.get("timer", 0))]
	elif state.can_research_equipment(state.current_player, unit_type, name) and _can_control_current_turn():
		state_name = "available"
	var button = _tech_tree_node_button(text, rect, state_name)
	_bind_action_hover(button, "%s装备\n%s" % [unit_type, _equipment_info_text(unit_type, equip)])
	button.disabled = state_name != "available"
	if state_name == "available":
		button.pressed.connect(func(): _on_equipment_pressed(unit_type, name))

func _add_strategic_graph_node(tech_name: String, tech: Dictionary, rect: Rect2) -> void:
	var active = state.research_entry(state.current_player, tech_name)
	var state_name = "locked"
	var text = "%s\n%.1f金 · %d回合" % [tech_name, float(tech.get("cost", 0.0)), int(tech.get("research_time", 1))]
	if state.players[state.current_player]["strategic"].has(tech_name):
		state_name = "done"
		text = "✓ %s\n已完成" % tech_name
	elif not active.is_empty():
		state_name = "researching"
		text = "%s\n研究中 · 剩%d" % [tech_name, int(active.get("timer", 0))]
	elif state.can_research_strategic(state.current_player, tech_name) and _can_control_current_turn():
		state_name = "available"
	var button = _tech_tree_node_button(text, rect, state_name)
	_bind_action_hover(button, _strategic_info_text(tech_name, tech))
	button.disabled = state_name != "available"
	if state_name == "available":
		button.pressed.connect(func(): _on_strategic_pressed(tech_name))

func _create_menu_ui() -> void:
	menu_layer = Control.new()
	menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu_layer)

	var bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var bg_texture = load("res://assets/images/初始界面.png")
	if bg_texture != null:
		bg.texture = bg_texture
	menu_layer.add_child(bg)

	menu_buttons = VBoxContainer.new()
	menu_buttons.anchor_left = 0.5
	menu_buttons.anchor_top = 0.5
	menu_buttons.anchor_right = 0.5
	menu_buttons.anchor_bottom = 0.5
	menu_buttons.offset_left = -130
	menu_buttons.offset_top = -20
	menu_buttons.offset_right = 130
	menu_buttons.offset_bottom = 230
	menu_buttons.add_theme_constant_override("separation", 10)
	menu_layer.add_child(menu_buttons)

	var start_btn = _make_menu_image_button("res://assets/images/开始游戏按钮.png", "开始游戏")
	start_btn.pressed.connect(_show_player_select)
	menu_buttons.add_child(start_btn)

	var online_btn = Button.new()
	online_btn.text = "远程联机"
	online_btn.custom_minimum_size = Vector2(260, 42)
	online_btn.pressed.connect(_show_online_menu)
	menu_buttons.add_child(online_btn)

	var ai_btn = Button.new()
	ai_btn.text = "人机对战"
	ai_btn.custom_minimum_size = Vector2(260, 42)
	ai_btn.tooltip_text = "与普通难度电脑进行 1 对 1 对战"
	ai_btn.pressed.connect(_start_ai_game)
	menu_buttons.add_child(ai_btn)

	var encyclopedia_btn = _make_menu_image_button("res://assets/images/百科全书按钮.png", "百科全书")
	encyclopedia_btn.pressed.connect(_show_encyclopedia)
	menu_buttons.add_child(encyclopedia_btn)

	var settings_btn = Button.new()
	settings_btn.text = "设置"
	settings_btn.custom_minimum_size = Vector2(260, 42)
	settings_btn.pressed.connect(_show_settings)
	menu_buttons.add_child(settings_btn)

	var exit_btn = Button.new()
	exit_btn.text = "退出游戏"
	exit_btn.custom_minimum_size = Vector2(260, 42)
	exit_btn.pressed.connect(func(): get_tree().quit())
	menu_buttons.add_child(exit_btn)

	_create_player_select_panel()
	_create_online_menu_panel()
	_create_encyclopedia_panel()
	_create_settings_panel()

func _make_menu_image_button(path: String, fallback_text: String) -> BaseButton:
	var text_btn = Button.new()
	text_btn.text = fallback_text
	text_btn.custom_minimum_size = Vector2(260, 46)
	return text_btn

func _create_player_select_panel() -> void:
	player_select_panel = PanelContainer.new()
	player_select_panel.visible = false
	player_select_panel.anchor_left = 0.5
	player_select_panel.anchor_top = 0.5
	player_select_panel.anchor_right = 0.5
	player_select_panel.anchor_bottom = 0.5
	player_select_panel.offset_left = -170
	player_select_panel.offset_top = -90
	player_select_panel.offset_right = 170
	player_select_panel.offset_bottom = 90
	menu_layer.add_child(player_select_panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	player_select_panel.add_child(box)
	var title = Label.new()
	title.text = "选择人数"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for count in [2, 3, 4]:
		var captured_count = int(count)
		var btn = Button.new()
		btn.text = "%d 人" % captured_count
		btn.custom_minimum_size = Vector2(86, 36)
		btn.pressed.connect(func(): _start_local_game(captured_count))
		row.add_child(btn)
	local_fog_checkbox = CheckBox.new()
	local_fog_checkbox.text = "启用战争迷雾"
	local_fog_checkbox.button_pressed = true
	local_fog_checkbox.tooltip_text = "线下共用一块屏幕时可以关闭，关闭后全图单位和建筑都可见。"
	box.add_child(local_fog_checkbox)
	var back = Button.new()
	back.text = "返回"
	back.pressed.connect(_show_menu_home)
	box.add_child(back)

func _create_online_menu_panel() -> void:
	online_menu_panel = PanelContainer.new()
	online_menu_panel.visible = false
	online_menu_panel.anchor_left = 0.5
	online_menu_panel.anchor_top = 0.5
	online_menu_panel.anchor_right = 0.5
	online_menu_panel.anchor_bottom = 0.5
	online_menu_panel.offset_left = -230
	online_menu_panel.offset_top = -190
	online_menu_panel.offset_right = 230
	online_menu_panel.offset_bottom = 190
	menu_layer.add_child(online_menu_panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	online_menu_panel.add_child(box)
	var title = Label.new()
	title.text = "远程联机"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var server_label = Label.new()
	server_label.text = "服务器地址"
	box.add_child(server_label)
	online_url_input = LineEdit.new()
	online_url_input.text = _saved_online_url()
	online_url_input.placeholder_text = "ws://服务器IP:3000"
	online_url_input.custom_minimum_size = Vector2(420, 34)
	box.add_child(online_url_input)
	var room_label = Label.new()
	room_label.text = "房间号"
	box.add_child(room_label)
	online_room_input = LineEdit.new()
	online_room_input.placeholder_text = "输入房间号，例如 AB12CD"
	online_room_input.custom_minimum_size = Vector2(420, 34)
	online_room_input.text_submitted.connect(func(_text): _on_online_join_pressed())
	box.add_child(online_room_input)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for count in [2, 3, 4]:
		var captured_count = int(count)
		var btn = Button.new()
		btn.text = "%d 人" % captured_count
		btn.pressed.connect(func(): player_count = captured_count)
		row.add_child(btn)
	var create_btn = Button.new()
	create_btn.text = "创建房间"
	create_btn.pressed.connect(_on_online_create_pressed)
	box.add_child(create_btn)
	var join_btn = Button.new()
	join_btn.text = "加入房间"
	join_btn.pressed.connect(_on_online_join_pressed)
	box.add_child(join_btn)
	online_status_label = Label.new()
	online_status_label.text = "输入房间号即可加入"
	online_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(online_status_label)
	var back = Button.new()
	back.text = "返回"
	back.pressed.connect(_show_menu_home)
	box.add_child(back)

func _create_settings_panel() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.visible = false
	settings_panel.anchor_left = 0.5
	settings_panel.anchor_top = 0.5
	settings_panel.anchor_right = 0.5
	settings_panel.anchor_bottom = 0.5
	settings_panel.offset_left = -210
	settings_panel.offset_top = -260
	settings_panel.offset_right = 210
	settings_panel.offset_bottom = 260
	add_child(settings_panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	settings_panel.add_child(box)
	var title = Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resolution_label = Label.new()
	resolution_label.text = "分辨率"
	box.add_child(resolution_label)
	var resolution = OptionButton.new()
	resolution.custom_minimum_size = Vector2(360, 34)
	var sizes = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
	for size in sizes:
		resolution.add_item("%d × %d" % [size.x, size.y])
	resolution.selected = 0
	resolution.item_selected.connect(func(index: int): _apply_resolution(sizes[index]))
	box.add_child(resolution)

	var fullscreen = CheckBox.new()
	fullscreen.text = "全屏（也可以按 F11 切换）"
	fullscreen.button_pressed = fullscreen_enabled
	fullscreen.toggled.connect(func(enabled: bool): _set_fullscreen(enabled))
	box.add_child(fullscreen)

	var bgm_label = Label.new()
	bgm_label.text = "音乐音量：%d%%" % bgm_volume_percent
	box.add_child(bgm_label)
	var bgm_slider = HSlider.new()
	bgm_slider.min_value = 0
	bgm_slider.max_value = 100
	bgm_slider.step = 1
	bgm_slider.value = bgm_volume_percent
	bgm_slider.value_changed.connect(func(value: float):
		bgm_volume_percent = int(value)
		bgm_label.text = "音乐音量：%d%%" % bgm_volume_percent
		if bgm_player != null:
			bgm_player.volume_db = _percent_to_db(bgm_volume_percent)
	)
	box.add_child(bgm_slider)

	var sfx_label = Label.new()
	sfx_label.text = "音效音量：%d%%" % sfx_volume_percent
	box.add_child(sfx_label)
	var sfx_slider = HSlider.new()
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.step = 1
	sfx_slider.value = sfx_volume_percent
	sfx_slider.value_changed.connect(func(value: float):
		sfx_volume_percent = int(value)
		sfx_label.text = "音效音量：%d%%" % sfx_volume_percent
		if sfx_player != null:
			sfx_player.volume_db = _percent_to_db(sfx_volume_percent)
	)
	box.add_child(sfx_slider)

	var separator = HSeparator.new()
	box.add_child(separator)

	var controls_btn = Button.new()
	controls_btn.text = "操作说明"
	controls_btn.tooltip_text = "查看按键操作"
	controls_btn.pressed.connect(_toggle_controls_panel)
	box.add_child(controls_btn)
	settings_game_actions = VBoxContainer.new()
	settings_game_actions.visible = false
	settings_game_actions.add_theme_constant_override("separation", 8)
	box.add_child(settings_game_actions)

	restart_button = Button.new()
	restart_button.text = "重新开始"
	restart_button.tooltip_text = "放弃当前对局并用相同人数重新生成地图"
	restart_button.pressed.connect(func():
		settings_panel.visible = false
		_on_restart_pressed()
	)
	settings_game_actions.add_child(restart_button)

	surrender_button = Button.new()
	surrender_button.text = "投降"
	surrender_button.tooltip_text = "当前玩家立即退出本局"
	surrender_button.pressed.connect(func():
		settings_panel.visible = false
		_on_surrender_pressed()
	)
	settings_game_actions.add_child(surrender_button)

	main_menu_button = Button.new()
	main_menu_button.text = "返回主菜单"
	main_menu_button.tooltip_text = "结束当前连接并返回主菜单"
	main_menu_button.pressed.connect(func():
		settings_panel.visible = false
		_return_to_main_menu()
	)
	settings_game_actions.add_child(main_menu_button)

	settings_back_button = Button.new()
	settings_back_button.text = "返回"
	settings_back_button.pressed.connect(_close_settings_panel)
	box.add_child(settings_back_button)

func _create_controls_panel() -> void:
	controls_panel = PanelContainer.new()
	controls_panel.visible = false
	controls_panel.anchor_left = 0.5
	controls_panel.anchor_top = 0.5
	controls_panel.anchor_right = 0.5
	controls_panel.anchor_bottom = 0.5
	controls_panel.offset_left = -220
	controls_panel.offset_top = -170
	controls_panel.offset_right = 220
	controls_panel.offset_bottom = 170
	add_child(controls_panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	controls_panel.add_child(box)
	var title = Label.new()
	title.text = "操作说明"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.custom_minimum_size = Vector2(400, 280)
	text.text = \
"[b]视角操作[/b]
放大/缩小：鼠标滚轮（以光标为中心）
平移地图：WASD / 方向键 / 鼠标左键拖拽

[b]选择操作[/b]
选择单位/建筑：鼠标左键点击
框选单位：Ctrl + 按住鼠标左键拖框
编队框选：Alt + 按住鼠标左键拖框（松开后弹出命名对话框）
选中编队：点击底部「编队」按钮

[b]单位操作[/b]
移动：选中单位 → 点击蓝色高亮格
攻击：选中单位 → 点击红色高亮目标
跳过行动：选中单位 → 底部「待机」按钮
驻扎回血：选中单位 → 底部「驻扎」

[b]其他[/b]
取消选中：ESC
结束回合：底部「结束回合」或按 Enter
全屏切换：F11"
	box.add_child(text)
	var close = Button.new()
	close.text = "关闭"
	close.pressed.connect(_close_controls_panel)
	box.add_child(close)

func _toggle_controls_panel() -> void:
	if controls_panel == null:
		return
	var opening = not controls_panel.visible
	controls_panel.visible = opening
	if settings_panel != null:
		settings_panel.visible = false
	if encyclopedia_panel != null:
		encyclopedia_panel.visible = false

func _close_controls_panel() -> void:
	if controls_panel != null:
		controls_panel.visible = false

func _create_encyclopedia_panel() -> void:
	encyclopedia_panel = PanelContainer.new()
	encyclopedia_panel.visible = false
	encyclopedia_panel.anchor_left = 0.04
	encyclopedia_panel.anchor_top = 0.04
	encyclopedia_panel.anchor_right = 0.96
	encyclopedia_panel.anchor_bottom = 0.96
	add_child(encyclopedia_panel)

	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	encyclopedia_panel.add_child(outer)

	var header = HBoxContainer.new()
	outer.add_child(header)
	var title = Label.new()
	title.text = "战争百科"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close = Button.new()
	close.text = "关闭"
	close.pressed.connect(_close_encyclopedia_panel)
	header.add_child(close)

	var body = HBoxContainer.new()
	body.custom_minimum_size = Vector2(1100, 600)
	body.add_theme_constant_override("separation", 12)
	outer.add_child(body)

	encyclopedia_nav = VBoxContainer.new()
	encyclopedia_nav.custom_minimum_size = Vector2(190, 580)
	encyclopedia_nav.add_theme_constant_override("separation", 8)
	body.add_child(encyclopedia_nav)

	var nav_title = Label.new()
	nav_title.text = "章节导航"
	encyclopedia_nav.add_child(nav_title)
	var chapters = [
		["ch0", "CH.0 五时代规则"],
		["ch1", "CH.1 E1-E5 兵种"],
		["ch2", "CH.2 建筑大全"],
		["ch3", "CH.3 科技与装备"],
		["ch4", "CH.4 状态与容量"]
	]
	for item in chapters:
		var chapter_id = str(item[0])
		var button = Button.new()
		button.text = str(item[1])
		button.custom_minimum_size = Vector2(180, 38)
		button.pressed.connect(func(): _render_encyclopedia_chapter(chapter_id))
		encyclopedia_nav.add_child(button)

	encyclopedia_content = RichTextLabel.new()
	encyclopedia_content.bbcode_enabled = true
	encyclopedia_content.fit_content = false
	encyclopedia_content.scroll_active = true
	encyclopedia_content.selection_enabled = true
	encyclopedia_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encyclopedia_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var encyclopedia_font := SystemFont.new()
	encyclopedia_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	encyclopedia_font.font_weight = 400
	encyclopedia_content.add_theme_font_override("normal_font", encyclopedia_font)
	encyclopedia_content.add_theme_font_override("bold_font", encyclopedia_font)
	var content_background := StyleBoxFlat.new()
	content_background.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	content_background.content_margin_left = 16
	content_background.content_margin_right = 16
	content_background.content_margin_top = 12
	content_background.content_margin_bottom = 12
	encyclopedia_content.add_theme_stylebox_override("normal", content_background)
	body.add_child(encyclopedia_content)
	_render_encyclopedia_chapter("ch1")

func _render_encyclopedia_chapter(chapter_id: String) -> void:
	if encyclopedia_content == null:
		return
	encyclopedia_content.clear()
	if chapter_id == "ch0":
		encyclopedia_content.parse_bbcode(_era_rules_bbcode())
		_add_terrain_images_to_encyclopedia()
	elif chapter_id == "ch1":
		_render_era_units_content()
	elif chapter_id == "ch2":
		_render_encyclopedia_buildings_content()
	elif chapter_id == "ch3":
		encyclopedia_content.parse_bbcode(_era_tech_bbcode())
	else:
		encyclopedia_content.parse_bbcode(_era_status_bbcode())

func _set_game_visible(visible: bool) -> void:
	if board != null:
		board.visible = visible
	for node in [hud_top_panel, hud_bottom_panel, action_container_panel, game_encyclopedia_button, game_settings_button]:
		if node != null:
			node.visible = visible
	if not visible:
		_hide_hover_info()
	if not visible and settings_panel != null:
		settings_panel.visible = false
	if not visible and controls_panel != null:
		controls_panel.visible = false
	if not visible and tech_tree_overlay != null:
		tech_tree_overlay.visible = false
	if not visible and research_notice_panel != null:
		research_notice_panel.visible = false
	for node in [online_url_input, online_room_input, online_status_label]:
		if node != null:
			node.visible = false
	if online_inline_panel != null:
		online_inline_panel.visible = false
	game_started = visible

func _show_player_select() -> void:
	menu_buttons.visible = false
	player_select_panel.visible = true
	online_menu_panel.visible = false
	encyclopedia_panel.visible = false
	settings_panel.visible = false
	_set_online_inputs_visible(false)

func _show_online_menu() -> void:
	menu_buttons.visible = false
	online_menu_panel.visible = true
	player_select_panel.visible = false
	encyclopedia_panel.visible = false
	settings_panel.visible = false
	_set_online_inputs_visible(true)

func _show_encyclopedia() -> void:
	menu_buttons.visible = false
	encyclopedia_panel.visible = true
	player_select_panel.visible = false
	online_menu_panel.visible = false
	settings_panel.visible = false
	_set_online_inputs_visible(false)

func _open_encyclopedia_overlay() -> void:
	encyclopedia_panel.visible = true
	if player_select_panel != null:
		player_select_panel.visible = false
	if online_menu_panel != null:
		online_menu_panel.visible = false
	if settings_panel != null:
		settings_panel.visible = false
	if controls_panel != null:
		controls_panel.visible = false

func _toggle_game_settings() -> void:
	if not game_started or settings_panel == null:
		return
	var opening = not settings_panel.visible
	settings_panel.visible = opening
	if not opening:
		return
	if encyclopedia_panel != null:
		encyclopedia_panel.visible = false
	settings_game_actions.visible = true
	if controls_panel != null:
		controls_panel.visible = false
	settings_back_button.text = "关闭"

func _close_settings_panel() -> void:
	settings_panel.visible = false
	if not game_started:
		_show_menu_home()
func _close_encyclopedia_panel() -> void:

	encyclopedia_panel.visible = false
	if menu_layer != null and menu_layer.visible and not game_started:
		menu_buttons.visible = true

func _show_settings() -> void:
	menu_buttons.visible = false
	settings_panel.visible = true
	settings_game_actions.visible = false
	settings_back_button.text = "返回"
	player_select_panel.visible = false
	online_menu_panel.visible = false
	encyclopedia_panel.visible = false
	_set_online_inputs_visible(false)

func _show_menu_home() -> void:
	menu_layer.visible = true
	menu_buttons.visible = true
	player_select_panel.visible = false
	online_menu_panel.visible = false
	encyclopedia_panel.visible = false
	settings_panel.visible = false
	encyclopedia_panel.visible = false
	_set_online_inputs_visible(false)

func _set_online_inputs_visible(visible: bool) -> void:
	if online_inline_panel != null:
		online_inline_panel.visible = visible
	for node in [online_url_input, online_room_input, online_status_label]:
		if node != null:
			node.visible = visible

func _return_to_main_menu() -> void:
	vs_ai = false
	ai_thinking = false
	_clear_selection()
	_clear_undo_history()
	_on_online_leave_pressed()
	if game_over_panel != null:
		game_over_panel.visible = false
	_set_game_visible(false)
	_show_menu_home()

func _start_local_game(count: int) -> void:
	vs_ai = false
	ai_thinking = false
	_start_match(count)

func _start_ai_game() -> void:
	vs_ai = true
	ai_player_id = 1
	ai_thinking = false
	local_fog_enabled = true
	_start_match(2)

func _start_match(count: int) -> void:
	player_count = clampi(count, 2, 4)
	if not vs_ai:
		local_fog_enabled = local_fog_checkbox == null or local_fog_checkbox.button_pressed
	formations.clear()
	selected_group_unit_ids.clear()
	formation_menu_open = false
	_clear_selection()
	_setup_state()
	board.setup(state, db)
	_sync_board_view_player()
	board.set_viewport_size(get_viewport().get_visible_rect().size)
	menu_layer.visible = false
	for node in [online_url_input, online_room_input, online_status_label]:
		if node != null:
			node.visible = false
	_set_game_visible(true)
	_refresh_ui()
	board.queue_redraw()

func _on_tile_clicked(pos: Vector2i) -> void:
	if state.game_over:
		return
	if not _can_control_current_turn():
		return
	if build_mode == "资源采集器":
		_push_undo_state()
		if state.build_collector(build_origin_id, pos):
			_play_sfx("upgrade")
			_notify_online("build-collector")
			build_mode = ""
			build_origin_id = -1
			_clear_selection()
			_refresh_ui()
			board.queue_redraw()
		else:
			_pop_failed_undo()
			var origin = state.get_building_by_id(build_origin_id)
			info_label.text = "这里不能建资源采集器：必须在大本营 5 格内空地，且金币足够。"
			board.set_build_tiles(state.collector_build_tiles(origin), Color(0.15, 0.72, 1.0), state.next_collector_income(state.current_player))
		return
	var clicked_unit: Dictionary = state.unit_at(pos)
	if not clicked_unit.is_empty() and state.is_current_players_unit(clicked_unit):
		selected_group_unit_ids.clear()
		_select_unit(clicked_unit)
		return
	if selected_unit_id >= 0:
		if board.attack_tiles.has(pos):
			_push_undo_state()
			if state.attack(selected_unit_id, pos):
				_play_sfx("cannon")
				_notify_online("attack")
			else:
				_pop_failed_undo()
			_clear_selection()
			_refresh_ui()
			return
		if board.move_tiles.has(pos):
			_push_undo_state()
			if state.move_unit(selected_unit_id, pos):
				_notify_online("move")
			else:
				_pop_failed_undo()
			_clear_selection()
			_refresh_ui()
			return
	var clicked_building: Dictionary = state.building_at(pos)
	if not clicked_building.is_empty() and int(clicked_building.get("pid", -1)) == state.current_player:
		_select_building(clicked_building)
		return
	if not clicked_building.is_empty() and clicked_building.get("type", "") == "据点" and int(clicked_building.get("pid", -1)) == -1 and state.is_explored(state.current_player, pos):
		_select_building(clicked_building)
		return
	if selected_unit_id >= 0:
		_clear_selection()
	elif selected_building_id >= 0:
		_clear_selection()
	_refresh_ui()

func _on_tile_hovered(pos: Vector2i) -> void:
	if not state.in_bounds(pos):
		_hide_hover_info()
		return
	var empty_tiles: Array[Vector2i] = []
	board.set_hover_threat(empty_tiles, "")
	var viewer = _local_view_player()
	var terrain: Dictionary = db.terrain_data(state.terrain_at(pos))
	var lines = ["地形：%s  高度 %s  移动 %.1f" % [terrain.get("name", "未知"), terrain.get("height", 0), terrain.get("move_cost", 1.0)]]
	var show_card = false
	if build_mode == "资源采集器":
		show_card = true
		var origin = state.get_building_by_id(build_origin_id)
		if state.can_build_collector(origin, pos):
			lines.append("可建造资源采集器：12 金 / 2 回合")
		else:
			lines.append("资源采集器需建在大本营 5 格内空地")
	var unit: Dictionary = state.unit_at(pos)
	if not unit.is_empty() and (int(unit["pid"]) == viewer or state.is_visible(viewer, pos)):
		show_card = true
		lines.append("单位：%s / %s" % [unit["type"], _player_name(int(unit["pid"]))])
		lines.append("HP：%.1f / %.1f" % [unit["hp"], unit["max_hp"]])
		var unit_type = str(unit.get("type", ""))
		var unit_data = db.unit_data(unit_type)
		var effective_stats = _effective_stats_ui(unit)
		lines.append("%s / %s  指挥 %d" % [_era_label(_unit_era(unit_type, unit_data)), _unit_role(unit_type, unit_data), _unit_command_cost(unit_type, unit_data)])
		lines.append("护甲：%.1f  伤害：%.1f  射程：%.1f  移速：%d  视野：%d" % [effective_stats.get("armor", 0.0), effective_stats.get("damage", 0.0), effective_stats.get("range", 0.0), int(effective_stats.get("speed", unit.get("speed", 0))), int(effective_stats.get("vision", unit.get("vision", unit_data.get("vision", 0))))])
		var equip_name = str(unit.get("equip", ""))
		if not equip_name.is_empty():
			lines.append("装备：%s" % equip_name)
		var status_parts = _status_texts(unit)
		if not status_parts.is_empty():
			lines.append("状态：%s" % "、".join(status_parts))
		var bonus_text = _bonus_source_text(unit)
		if not bonus_text.is_empty():
			lines.append("生效加成：%s" % bonus_text)
		if int(unit["pid"]) != viewer and int(unit["pid"]) >= 0:
			var threat = state.hover_threat_tiles_for_unit(unit)
			var radius = float(unit.get("speed", 0)) + state.max_possible_range_for(unit, unit["pos"])
			board.set_hover_threat(threat, "威胁范围(%.1f)" % radius)
	var building: Dictionary = state.building_at(pos)
	if not building.is_empty() and state.is_explored(viewer, pos):
		show_card = true
		var building_visible = state.is_visible(viewer, pos)
		var display = building
		if not building_visible:
			var memory = state.building_memory_for(viewer, pos)
			if not memory.is_empty():
				display = memory
		lines.append("建筑：%s / %s" % [display.get("type", building["type"]), _player_name(int(display.get("pid", building["pid"])))])
		if building_visible:
			var extra = ""
			if bool(building.get("under_construction", false)):
				extra = "  建造中：%d 回合" % int(building.get("build_timer", 0))
			elif bool(building.get("upgrading", false)):
				extra = "  升级中：%d 回合" % int(building.get("up_timer", 0))
			elif building["type"] == "据点" and int(building.get("outpost_tier", 0)) > 0:
				extra = "  %s" % _outpost_branch_label(str(building.get("outpost_branch", "")))
			lines.append("HP：%.1f / %.1f  护甲：%.1f  收入：%.1f%s" % [building["hp"], building["max_hp"], building["armor"], building["gold"], extra])
			var building_statuses = _status_texts(building)
			if not building_statuses.is_empty():
				lines.append("状态：%s" % "、".join(building_statuses))
		else:
			var seen_turn = int(display.get("turn", state.turn))
			lines.append("上次侦察：回合 %d" % seen_turn)
			lines.append("HP：%.1f / %.1f  护甲：%.1f  收入：%.1f" % [float(display.get("hp", 0.0)), float(display.get("max_hp", 0.0)), float(display.get("armor", 0.0)), float(display.get("gold", 0.0))])
	if show_card:
		_show_hover_info(lines)
	else:
		_hide_hover_info()

func _show_hover_info(lines) -> void:
	if info_panel == null or info_label == null:
		return
	info_label.text = "\n".join(lines)
	var viewport_size = get_viewport().get_visible_rect().size
	var card_width = min(380.0, max(280.0, viewport_size.x - 24.0))
	var card_height = clamp(30.0 + lines.size() * 22.0, 74.0, 242.0)
	info_panel.size = Vector2(card_width, card_height)
	var mouse = get_viewport().get_mouse_position()
	var desired = mouse + Vector2(18.0, 18.0)
	if desired.x + card_width > viewport_size.x - 8.0:
		desired.x = mouse.x - card_width - 18.0
	if desired.y + card_height > viewport_size.y - 8.0:
		desired.y = mouse.y - card_height - 18.0
	info_panel.position = Vector2(clamp(desired.x, 8.0, max(8.0, viewport_size.x - card_width - 8.0)), clamp(desired.y, 36.0, max(36.0, viewport_size.y - card_height - 8.0)))
	info_panel.visible = game_started
	info_panel.move_to_front()

func _hide_hover_info() -> void:
	if info_panel != null:
		info_panel.visible = false

func _select_unit(unit: Dictionary) -> void:
	selected_building_id = -1
	selected_unit_id = int(unit["id"])
	var empty_hover: Array[Vector2i] = []
	var empty_build_tiles: Array[Vector2i] = []
	board.set_hover_threat(empty_hover, "")
	board.set_build_tiles(empty_build_tiles, PLAYER_COLORS[state.current_player])
	board.set_selection(selected_unit_id, -1, state.move_tiles_for(unit), state.attack_targets_for(unit))
	var empty_threats: Array[Vector2i] = []
	board.set_tactical_overlays(state.attack_range_tiles_for(unit), empty_threats)
	_refresh_ui()

func _select_building(building: Dictionary) -> void:
	selected_group_unit_ids.clear()
	selected_unit_id = -1
	selected_building_id = int(building["id"])
	var empty_moves: Array[Vector2i] = []
	var empty_attacks: Array[Vector2i] = []
	var empty_build_tiles: Array[Vector2i] = []
	board.set_selection(-1, selected_building_id, empty_moves, empty_attacks)
	board.set_tactical_overlays(empty_moves, empty_attacks)
	board.set_build_tiles(empty_build_tiles, PLAYER_COLORS[state.current_player])
	_refresh_ui()

func _clear_selection() -> void:
	selected_unit_id = -1
	selected_building_id = -1
	build_mode = ""
	build_origin_id = -1
	selected_group_unit_ids.clear()
	formation_menu_open = false
	board.clear_selection()

func _on_group_box_selected(bounds: Rect2i, create_formation: bool) -> void:
	if not _can_control_current_turn() or state.game_over:
		return
	var ids: Array[int] = []
	for unit in state.units:
		if int(unit.get("pid", -1)) != state.current_player:
			continue
		if bounds.has_point(unit["pos"]):
			ids.append(int(unit["id"]))
	if ids.is_empty():
		_clear_selection()
		_refresh_ui()
		return
	_select_unit_group(ids)
	if create_formation:
		pending_formation_unit_ids = ids.duplicate()
		formation_name_input.text = "编队 %d" % (formations.size() + 1)
		formation_dialog.popup_centered()

func _select_unit_group(unit_ids: Array[int]) -> void:
	selected_unit_id = -1
	selected_building_id = -1
	build_mode = ""
	build_origin_id = -1
	formation_menu_open = false
	selected_group_unit_ids.clear()
	for unit_id in unit_ids:
		var unit = state.get_unit_by_id(unit_id)
		if not unit.is_empty() and int(unit.get("pid", -1)) == state.current_player:
			selected_group_unit_ids.append(unit_id)
	board.set_group_selection(selected_group_unit_ids)
	_refresh_ui()

func _on_group_move_requested(target: Vector2i) -> void:
	if selected_group_unit_ids.is_empty() or not _can_control_current_turn():
		return
	_push_undo_state()
	var moved_count = state.move_unit_group(selected_group_unit_ids, target)
	if moved_count <= 0:
		_pop_failed_undo()
		info_label.text = "编队中没有单位能在本回合抵达目标附近。"
		return
	_notify_online("group-move")
	_select_unit_group(selected_group_unit_ids)
	board.queue_redraw()

func _confirm_formation_name() -> void:
	var name = formation_name_input.text.strip_edges()
	if name.is_empty():
		name = "编队 %d" % (formations.size() + 1)
	formations.append({"name": name, "unit_ids": pending_formation_unit_ids.duplicate()})
	pending_formation_unit_ids.clear()
	formation_menu_open = true
	_refresh_ui()

func _toggle_formation_menu() -> void:
	formation_menu_open = not formation_menu_open
	selected_unit_id = -1
	selected_building_id = -1
	_refresh_ui()

func _select_formation(index: int) -> void:
	if index < 0 or index >= formations.size():
		return
	var alive_ids: Array[int] = []
	var center = Vector2.ZERO
	for raw_id in formations[index].get("unit_ids", []):
		var unit = state.get_unit_by_id(int(raw_id))
		if unit.is_empty() or int(unit.get("pid", -1)) != state.current_player:
			continue
		alive_ids.append(int(raw_id))
		center += Vector2(unit["pos"])
	formations[index]["unit_ids"] = alive_ids
	if alive_ids.is_empty():
		formations.remove_at(index)
		_refresh_ui()
		return
	_select_unit_group(alive_ids)
	board.center_on_tile(Vector2i((center / float(alive_ids.size())).round()))

func _push_undo_state() -> void:
	if not _can_control_current_turn():
		return
	undo_history.append(state.to_dict())
	if undo_history.size() > 20:
		undo_history.pop_front()

func _pop_failed_undo() -> void:
	if not undo_history.is_empty():
		undo_history.pop_back()

func _clear_undo_history() -> void:
	undo_history.clear()

func _on_undo_pressed() -> void:
	if undo_history.is_empty() or not _can_control_current_turn():
		return
	var previous = undo_history.pop_back()
	online_applying_remote = true
	state.load_from_dict(previous)
	online_applying_remote = false
	_clear_selection()
	_after_turn_state_changed(false)
	board.queue_redraw()
	_notify_online("undo")

func _on_end_turn_pressed() -> void:
	if state.game_over:
		return
	if not _can_control_current_turn():
		return
	_clear_selection()
	var automatic_attacks = state.end_turn()
	if automatic_attacks > 0:
		_play_sfx("cannon")
	_clear_undo_history()
	_after_turn_state_changed(not online_connected and not vs_ai)
	_notify_online("end-turn")
	if vs_ai and not state.game_over and state.current_player == ai_player_id:
		call_deferred("_run_ai_turn")

func _run_ai_turn() -> void:
	if not vs_ai or ai_thinking or state.game_over or state.current_player != ai_player_id:
		return
	ai_thinking = true
	_clear_selection()
	_after_turn_state_changed(false)
	await get_tree().create_timer(0.25).timeout
	var report = ai_controller.take_turn(state, ai_player_id)
	state.last_event = "电脑：生产 %d，移动 %d，攻击 %d，发展 %d" % [
		int(report.get("produced", 0)),
		int(report.get("moved", 0)),
		int(report.get("attacked", 0)),
		int(report.get("developed", 0))
	]
	_after_turn_state_changed(false)
	await get_tree().create_timer(0.25).timeout
	if not state.game_over and state.current_player == ai_player_id:
		var automatic_attacks = state.end_turn()
		if automatic_attacks > 0 or int(report.get("attacked", 0)) > 0:
			_play_sfx("cannon")
	ai_thinking = false
	_clear_undo_history()
	_after_turn_state_changed(not state.game_over)

func _on_restart_pressed() -> void:
	ai_thinking = false
	_clear_selection()
	formations.clear()
	if game_over_panel != null:
		game_over_panel.visible = false
	_clear_undo_history()
	state.new_game()
	state.fog_enabled = local_fog_enabled and not online_connected
	_after_turn_state_changed(true)

func _on_player_count_pressed(count: int) -> void:
	if online_connected or vs_ai:
		return
	player_count = clampi(count, 2, 4)
	_clear_selection()
	formations.clear()
	_clear_undo_history()
	_setup_state()
	board.setup(state, db)
	_sync_board_view_player()
	board.set_viewport_size(get_viewport().get_visible_rect().size)
	_after_turn_state_changed(true)

func _after_turn_state_changed(center_camera: bool) -> void:
	state.update_vision()
	_sync_board_view_player()
	if center_camera and board != null:
		board.center_on_current_player()
	_refresh_ui()
	_show_pending_research_notifications()
	if board != null:
		board.queue_redraw()

func _sync_board_view_player() -> void:
	if board == null:
		return
	board.set_view_player(_local_view_player())

func _local_view_player() -> int:
	if online_connected and online_player_id >= 0:
		return online_player_id
	if vs_ai:
		return 0
	return state.current_player

func _object_property(source, property_name: String, fallback = null):
	if source == null:
		return fallback
	for property in source.get_property_list():
		if str(property.get("name", "")) == property_name:
			var value = source.get(property_name)
			return fallback if value == null else value
	return fallback

func _era_number(value, fallback: int = 1) -> int:
	if value is String:
		var text = str(value).strip_edges().to_upper()
		if text.begins_with("E") or text.begins_with("T"):
			return clampi(int(text.substr(1)), 1, 5)
	return clampi(int(value) if value != null else fallback, 1, 5)

func _player_era(pid: int) -> int:
	if pid < 0 or pid >= state.players.size():
		return 1
	if state.has_method("player_era"):
		return _era_number(state.call("player_era", pid), 1)
	var player: Dictionary = state.players[pid]
	var resolved_era := 1
	for key in ["era", "current_era", "age", "tier"]:
		if player.has(key):
			resolved_era = maxi(resolved_era, _era_number(player.get(key, 1)))
	return resolved_era

func _global_open_era() -> int:
	for method_name in ["global_era", "global_open_era", "get_global_open_era", "current_global_era"]:
		if state.has_method(method_name):
			return _era_number(state.call(method_name), 1)
	for property_name in ["global_open_era", "open_era", "global_era"]:
		var value = _object_property(state, property_name, null)
		if value != null:
			return _era_number(value, 1)
	var round_number = int(_object_property(state, "turn", 1))
	if round_number >= 45:
		return 5
	if round_number >= 31:
		return 4
	if round_number >= 19:
		return 3
	if round_number >= 9:
		return 2
	return 1

func _era_label(era: int) -> String:
	var safe_era = clampi(era, 1, 5)
	return "E%d %s" % [safe_era, str(ERA_NAMES.get(safe_era, "未知时代"))]

func _next_global_era_text() -> String:
	var era = _global_open_era()
	if era >= 5:
		var war_remaining = maxi(0, GRAND_WAR_TURN - int(state.turn))
		return "总体战已开始" if war_remaining == 0 else "距总体战还剩 %d 个完整回合" % war_remaining
	var next_era = era + 1
	var remaining = maxi(0, int(ERA_OPEN_TURNS[next_era]) - int(state.turn))
	return "距 E%d %s开放还剩 %d 个完整回合" % [next_era, str(ERA_NAMES.get(next_era, "")), remaining]

func _unit_era(unit_type: String, data: Dictionary = {}) -> int:
	for key in ["era", "age", "tier"]:
		if data.has(key):
			return _era_number(data.get(key, 1))
	for row in ERA_UNIT_ROWS:
		if str(row[1]) == unit_type:
			return int(row[0])
	for tech_id in db.techs.keys():
		var tech: Dictionary = db.techs.get(tech_id, {})
		if tech.get("unlocks", []).has(unit_type):
			return _era_number(str(tech_id), 1)
	return 1

func _unit_role(unit_type: String, data: Dictionary = {}) -> String:
	for key in ["role", "combat_role", "route"]:
		if data.has(key):
			var role = str(data.get(key, ""))
			return {"frontline": "战线", "line": "战线", "mobile": "机动", "firepower": "火力", "support": "支援"}.get(role, role)
	return str(UNIT_ROLES.get(unit_type, "战线"))

func _unit_command_cost(unit_type: String, data: Dictionary = {}) -> int:
	if state != null and state.has_method("command_cost_for"):
		return int(state.call("command_cost_for", unit_type))
	if db != null and db.has_method("command_cost_for_unit"):
		return int(db.call("command_cost_for_unit", unit_type))
	for key in ["command_cost", "command", "capacity_cost"]:
		if data.has(key):
			return maxi(0, int(data.get(key, 1)))
	return 2 if ["机动", "火力"].has(_unit_role(unit_type, data)) else 1

func _command_used(pid: int) -> int:
	for method_name in ["command_used", "get_command_used", "command_usage_for"]:
		if state.has_method(method_name):
			return int(state.call(method_name, pid))
	if pid >= 0 and pid < state.players.size():
		var player: Dictionary = state.players[pid]
		for key in ["command_used", "command_usage", "capacity_used"]:
			if player.has(key):
				return int(player.get(key, 0))
	var used = 0
	for unit in state.units:
		if int(unit.get("pid", -1)) == pid:
			var unit_type = str(unit.get("type", ""))
			used += _unit_command_cost(unit_type, db.unit_data(unit_type))
	return used

func _command_capacity(pid: int) -> int:
	for method_name in ["command_capacity", "get_command_capacity", "command_capacity_for"]:
		if state.has_method(method_name):
			return int(state.call(method_name, pid))
	if pid >= 0 and pid < state.players.size():
		var player: Dictionary = state.players[pid]
		for key in ["command_capacity", "command_cap", "capacity"]:
			if player.has(key):
				return int(player.get(key, 0))
	var capacity = int(ERA_COMMAND_CAPACITY.get(_player_era(pid), 12))
	for building in state.buildings:
		if int(building.get("pid", -1)) != pid or str(building.get("type", "")) != "据点":
			continue
		if str(building.get("outpost_branch", "")) == "economic":
			continue
		capacity += 2 if str(building.get("outpost_branch", "")) == "combat" else 1
	return capacity

func _campaign_advantage(pid: int) -> int:
	if pid >= 0 and pid < state.players.size():
		var player: Dictionary = state.players[pid]
		for key in ["campaign_advantage", "advantage", "campaign_points"]:
			if player.has(key):
				return clampi(int(player.get(key, 0)), 0, 3)
	var values = _object_property(state, "campaign_advantage", null)
	if values is Array and pid >= 0 and pid < values.size():
		return clampi(int(values[pid]), 0, 3)
	if values is Dictionary:
		return clampi(int(values.get(pid, values.get(str(pid), 0))), 0, 3)
	return 0

func _campaign_window_text(pid: int) -> String:
	if pid >= 0 and pid < state.players.size():
		var player: Dictionary = state.players[pid]
		for key in ["assault_window", "offensive_window", "campaign_window"]:
			if int(player.get(key, 0)) > 0:
				return " 总攻%d" % int(player.get(key, 0))
	if state.has_method("is_total_war") and bool(state.call("is_total_war")):
		return " 总体战"
	return ""

func _status_texts(entity: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if entity.has("remaining_attacks") and state != null and state.has_method("unit_statuses"):
		for status_name in state.call("unit_statuses", entity):
			result.append(str(status_name))
	var raw_statuses = entity.get("statuses", entity.get("status", []))
	if raw_statuses is Dictionary:
		for key in raw_statuses.keys():
			var value = raw_statuses[key]
			result.append("%s%s" % [str(key), "(%s)" % str(value) if value != true else ""])
	elif raw_statuses is Array:
		for value in raw_statuses:
			if value is Dictionary:
				result.append("%s%s" % [str(value.get("name", value.get("id", "状态"))), "(%d)" % int(value.get("turns", value.get("timer", 0))) if int(value.get("turns", value.get("timer", 0))) > 0 else ""])
			else:
				result.append(str(value))
	elif not str(raw_statuses).is_empty():
		result.append(str(raw_statuses))
	if int(entity.get("rl", entity.get("reload_remaining", 0))) > 0:
		result.append("装填(%d)" % int(entity.get("rl", entity.get("reload_remaining", 0))))
	if bool(entity.get("under_construction", false)):
		result.append("建造中(%d)" % int(entity.get("build_timer", 0)))
	if bool(entity.get("upgrading", false)):
		result.append("升级中(%d)" % int(entity.get("up_timer", 0)))
	if bool(entity.get("garrisoned", false)):
		result.append("驻扎")
	if bool(entity.get("jammed", false)):
		result.append("干扰")
	if bool(entity.get("marked", false)):
		result.append("标记")
	if bool(entity.get("done", false)) and not result.has("已行动"):
		result.append("已行动")
	return result

func _effective_stats_ui(unit: Dictionary) -> Dictionary:
	if state != null and state.has_method("effective_unit_stats"):
		var value = state.call("effective_unit_stats", unit)
		if value is Dictionary:
			return value
	return {
		"armor": unit.get("effective_armor", unit.get("armor", 0.0)),
		"damage": unit.get("effective_damage", unit.get("damage", 0.0)),
		"range": unit.get("effective_range", unit.get("range", 0.0)),
		"speed": unit.get("effective_speed", unit.get("speed", 0)),
		"vision": unit.get("effective_vision", unit.get("vision", 0))
	}

func _bonus_source_text(entity: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["active_bonuses", "adjacency_bonuses", "stat_sources", "bonuses"]:
		var raw = entity.get(key, null)
		if raw is Dictionary:
			for source in raw.keys():
				parts.append("%s:%s" % [str(source), str(raw[source])])
		elif raw is Array:
			for source in raw:
				parts.append(str(source.get("name", source.get("source", "加成"))) if source is Dictionary else str(source))
	if entity.has("remaining_attacks") and state != null and state.has_method("adjacent_friendly_units"):
		var adjacent_types: Array[String] = []
		for friend in state.call("adjacent_friendly_units", entity):
			var friend_type = str(friend.get("type", "友军"))
			if not adjacent_types.has(friend_type):
				adjacent_types.append(friend_type)
		if not adjacent_types.is_empty():
			parts.append("相邻:" + "/".join(adjacent_types))
		var effective = _effective_stats_ui(entity)
		var deltas: Array[String] = []
		for key in ["damage", "armor", "range", "vision"]:
			var base = float(entity.get(key, db.unit_data(str(entity.get("type", ""))).get(key, 0.0)))
			var actual = float(effective.get(key, base))
			if not is_equal_approx(base, actual):
				deltas.append("%s%+.1f" % [{"damage": "攻", "armor": "甲", "range": "射", "vision": "视"}[key], actual - base])
		if not deltas.is_empty():
			parts.append("实际修正:" + " ".join(deltas))
	return "、".join(parts)

func _call_state_entity_method(method_name: String, entity: Dictionary, target: String = ""):
	if not state.has_method(method_name):
		return null
	var method_args: Array = []
	for method in state.get_method_list():
		if str(method.get("name", "")) == method_name:
			method_args = method.get("args", [])
			break
	var args: Array = []
	if method_args.size() >= 1:
		var first_name = str(method_args[0].get("name", "")).to_lower()
		args.append(int(entity.get("id", -1)) if first_name.contains("id") else entity)
	if method_args.size() >= 2:
		args.append(target)
	return state.callv(method_name, args)

func _call_state_research_method(method_name: String, tech_id: String, tech: Dictionary):
	if not state.has_method(method_name):
		return null
	var method_args: Array = []
	for method in state.get_method_list():
		if str(method.get("name", "")) == method_name:
			method_args = method.get("args", [])
			break
	var args: Array = []
	for argument in method_args:
		var arg_name = str(argument.get("name", "")).to_lower()
		if arg_name.contains("pid") or arg_name.contains("player"):
			args.append(state.current_player)
		elif arg_name.contains("data") or arg_name.contains("tech") and arg_name.contains("dict"):
			args.append(tech)
		else:
			args.append(tech_id)
	return state.callv(method_name, args)

func _next_unit_type(unit: Dictionary) -> String:
	if state != null and state.has_method("next_unit_upgrade"):
		return str(state.call("next_unit_upgrade", unit))
	if db != null and db.has_method("next_unit_in_route"):
		return str(db.call("next_unit_in_route", str(unit.get("type", ""))))
	for key in ["evolution_to", "evolve_to", "next_unit", "next_type"]:
		if unit.has(key) and not str(unit.get(key, "")).is_empty():
			return str(unit.get(key, ""))
	var data = db.unit_data(str(unit.get("type", "")))
	for key in ["evolution_to", "evolve_to", "next_unit", "next_type"]:
		if data.has(key) and not str(data.get(key, "")).is_empty():
			return str(data.get(key, ""))
	return str(UNIT_EVOLUTION.get(str(unit.get("type", "")), ""))

func _can_evolve_unit_ui(unit: Dictionary, next_type: String) -> bool:
	if next_type.is_empty() or _player_era(int(unit.get("pid", -1))) < _unit_era(next_type, db.unit_data(next_type)):
		return false
	for method_name in ["can_evolve_unit", "can_upgrade_unit", "can_promote_unit"]:
		if state.has_method(method_name):
			return bool(_call_state_entity_method(method_name, unit, next_type))
	return false

func _refresh_ui() -> void:
	if state.game_over:
		status_label.text = "游戏结束：%s 胜利" % _player_name(state.winner)
		_show_game_over_panel()
		return
	var player: Dictionary = state.players[state.current_player]
	var online_text = ""
	if online_connected:
		online_text = "   联机房间 %s   你是%s" % [online_room_id, _player_name(online_player_id)]
	elif vs_ai:
		online_text = "   人机对战%s" % ("   电脑思考中" if ai_thinking else "")
	var era = _player_era(state.current_player)
	var global_era = _global_open_era()
	var command_used = _command_used(state.current_player)
	var command_cap = _command_capacity(state.current_player)
	var advantage = _campaign_advantage(state.current_player)
	var campaign_window = _campaign_window_text(state.current_player)
	var era_countdown = _next_global_era_text()
	status_label.text = "%s玩家%d  完整回合 %d  金币 %.2f (+%.2f)  %s  %s  指挥 %d/%d  优势 %d/3%s" % [
		_player_color_prefix(state.current_player), state.current_player + 1, state.turn,
		float(player.get("gold", 0.0)), _current_income(state.current_player), _era_label(era), era_countdown,
		command_used, command_cap, advantage, campaign_window + online_text
	]
	status_label.tooltip_text = "%s\n%s；完整回合%d起进入总体战" % [era_countdown, "总攻窗口可用" if advantage >= 3 else "控制战略点积累战役优势", GRAND_WAR_TURN]
	if surrender_button != null:
		surrender_button.disabled = not _can_control_current_turn()
	if end_turn_button != null:
		end_turn_button.disabled = not _can_control_current_turn()
	if undo_button != null:
		undo_button.disabled = undo_history.is_empty() or not _can_control_current_turn()
	if tech_tree_button != null:
		tech_tree_button.disabled = not _can_control_current_turn()
	if tech_tree_overlay != null and tech_tree_overlay.visible:
		if _can_control_current_turn():
			_rebuild_tech_tree()
		else:
			_close_tech_tree()
	_refresh_unit_bottom_actions()
	_refresh_action_panel()

func _current_income(pid: int) -> float:
	var income = 0.0
	for building in state.buildings:
		if int(building.get("pid", -1)) == pid:
			income += float(building.get("gold", 0.0))
	return income

func _player_color_prefix(pid: int) -> String:
	if pid == 0:
		return "红方 "
	if pid == 1:
		return "蓝方 "
	if pid == 2:
		return "绿方 "
	return "黄方 "

func _next_hq_upgrade_cost(building: Dictionary) -> float:
	if state.has_method("hq_upgrade_cost"):
		return float(state.call("hq_upgrade_cost", int(building.get("pid", state.current_player))))
	if state.has_method("next_hq_upgrade_cost"):
		return float(_call_state_entity_method("next_hq_upgrade_cost", building))
	var tier = int(building.get("tier", 0))
	var hq = db.building_data("大本营")
	var tiers = hq.get("tiers", [])
	if tier >= tiers.size() - 1:
		return 0.0
	return float(tiers[tier].get("upgrade_cost", 0.0))

func _make_action_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(action_panel_width - 26, 28)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.18, 0.08, 0.92)
	normal.border_color = Color(0.18, 0.42, 0.20, 0.95)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3
	var hover = normal.duplicate()
	hover.bg_color = Color(0.10, 0.30, 0.12, 0.96)
	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.08, 0.08, 0.10, 0.72)
	disabled.border_color = Color(0.20, 0.20, 0.24, 0.7)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	return btn

func _bind_action_hover(control: Control, text: String) -> void:
	control.tooltip_text = ""
	control.mouse_entered.connect(func():
		_show_hover_info(text.split("\n"))
	)
	control.mouse_exited.connect(_hide_hover_info)

func _refresh_unit_bottom_actions() -> void:
	if unit_bottom_actions == null:
		return
	for child in unit_bottom_actions.get_children():
		unit_bottom_actions.remove_child(child)
		child.queue_free()
	unit_bottom_actions.visible = false
	if selected_unit_id < 0 or not _can_control_current_turn():
		return
	var unit = state.get_unit_by_id(selected_unit_id)
	if unit.is_empty() or int(unit.get("pid", -1)) != state.current_player:
		return
	unit_bottom_actions.visible = true
	var unit_type = str(unit.get("type", ""))
	var current_equip = str(unit.get("equip", ""))
	var summary = Label.new()
	var unit_statuses = _status_texts(unit)
	summary.text = "%s %s  指挥%d%s" % [
		_era_label(_unit_era(unit_type, db.unit_data(unit_type))),
		_unit_role(unit_type, db.unit_data(unit_type)),
		_unit_command_cost(unit_type, db.unit_data(unit_type)),
		"  状态：" + "、".join(unit_statuses) if not unit_statuses.is_empty() else ""
	]
	summary.tooltip_text = _unit_info_text(unit_type)
	unit_bottom_actions.add_child(summary)
	if not current_equip.is_empty():
		var equipped = Label.new()
		equipped.text = "装备：%s" % current_equip
		equipped.tooltip_text = _unit_info_text(unit_type)
		unit_bottom_actions.add_child(equipped)
	else:
		var unlocked: Array = []
		for equip in db.equipment_for(unit_type):
			var equip_name = str(equip.get("name", ""))
			if state.players[state.current_player]["equipment"].has(state.equipment_key(unit_type, equip_name)):
				unlocked.append(equip)
		if unlocked.is_empty():
			var none = Label.new()
			none.text = "装备：无"
			unit_bottom_actions.add_child(none)
		else:
			for equip in unlocked:
				var equip_name = str(equip.get("name", ""))
				var equip_button = Button.new()
				equip_button.text = "%s  %.1f 金" % [equip_name, float(equip.get("cost", 0.0))]
				equip_button.tooltip_text = _equipment_info_text(unit_type, equip)
				equip_button.disabled = not state.can_equip_unit(unit, equip_name)
				var captured_unit_id = int(unit["id"])
				var captured_equip_name = equip_name
				equip_button.pressed.connect(func(): _on_equip_unit_pressed(captured_unit_id, captured_equip_name))
				unit_bottom_actions.add_child(equip_button)
	var next_type = _next_unit_type(unit)
	if not next_type.is_empty():
		var evolve = Button.new()
		var evolve_cost = float(db.unit_data(next_type).get("upgrade_cost", db.unit_data(next_type).get("evolution_cost", 0.0)))
		evolve.text = "进化为%s%s" % [next_type, "  %.1f金" % evolve_cost if evolve_cost > 0.0 else ""]
		evolve.tooltip_text = "需位于己方大本营或战斗据点驻扎范围；消耗本回合行动并保留生命比例。"
		evolve.disabled = not _can_evolve_unit_ui(unit, next_type)
		var captured_evolve_id = int(unit.get("id", -1))
		var captured_next_type = next_type
		evolve.pressed.connect(func(): _on_evolve_unit_pressed(captured_evolve_id, captured_next_type))
		unit_bottom_actions.add_child(evolve)
	var skip = Button.new()
	skip.text = "待机"
	skip.tooltip_text = "结束该单位本回合的行动"
	skip.pressed.connect(func(): _on_skip_unit_pressed(int(unit["id"])))
	unit_bottom_actions.add_child(skip)

func _refresh_action_panel() -> void:
	for child in action_panel.get_children():
		child.queue_free()
	var should_show = selected_building_id >= 0 or not selected_group_unit_ids.is_empty() or formation_menu_open or not _can_control_current_turn()
	if action_container_panel != null:
		action_container_panel.visible = game_started and should_show
	if not should_show:
		return
	var title = Label.new()
	title.text = "操作"
	action_panel.add_child(title)
	if formation_menu_open:
		var help = Label.new()
		help.text = "编队列表\nAlt + 左键拖框可新建编队"
		action_panel.add_child(help)
		if formations.is_empty():
			var empty = Label.new()
			empty.text = "暂无编队"
			action_panel.add_child(empty)
		for index in range(formations.size()):
			var formation = formations[index]
			var captured_index = index
			var btn = _make_action_button("%s（%d）" % [formation.get("name", "编队"), formation.get("unit_ids", []).size()])
			btn.pressed.connect(func(): _select_formation(captured_index))
			action_panel.add_child(btn)
		return
	if not selected_group_unit_ids.is_empty():
		var group_label = Label.new()
		group_label.text = "已选中 %d 个单位\n左键点击目标格，部队将向目标周围推进。" % selected_group_unit_ids.size()
		group_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action_panel.add_child(group_label)
		return
	if online_connected and not _can_control_current_turn():
		var wait = Label.new()
		wait.text = "联机中，等待 %s 操作。" % _player_name(state.current_player)
		action_panel.add_child(wait)
		return
	if vs_ai and not _can_control_current_turn():
		var wait = Label.new()
		wait.text = "电脑正在行动……"
		action_panel.add_child(wait)
		return
	if selected_building_id >= 0:
		var building = state.get_building_by_id(selected_building_id)
		if building.is_empty():
			return
		var building_label = Label.new()
		building_label.text = "%s  %s\nHP %.1f / %.1f  护甲 %.1f\n收入 %.1f / 回合  指挥 %d/%d  优势 %d/3" % [
			building["type"],
			_era_label(_player_era(state.current_player)),
			float(building["hp"]),
			float(building["max_hp"]),
			float(building.get("armor", 0.0)),
			float(building.get("gold", 0.0)),
			_command_used(state.current_player),
			_command_capacity(state.current_player),
			_campaign_advantage(state.current_player)
		]
		if bool(building.get("under_construction", false)):
			building_label.text += "\n建造中：%d 回合" % int(building.get("build_timer", 0))
		if bool(building.get("upgrading", false)):
			building_label.text += "\n升级中：%d 回合" % int(building.get("up_timer", 0))
		if building["type"] == "据点" and int(building.get("outpost_tier", 0)) > 0:
			building_label.text += "\n%s" % _outpost_branch_label(str(building.get("outpost_branch", "")))
		action_panel.add_child(building_label)
		if building["type"] == "大本营":
			_add_hq_upgrade_button(building)
			_add_production_buttons(building)
			_add_collector_button(building)
		elif building["type"] == "据点":
			_add_outpost_buttons(building)
			if int(building.get("pid", -1)) == state.current_player:
				_add_production_buttons(building)
		return
	if build_mode == "资源采集器":
		var build_label = Label.new()
		build_label.text = "选择资源采集器位置"
		action_panel.add_child(build_label)

func _add_unit_equip_buttons(unit: Dictionary) -> void:
	var unit_type = str(unit.get("type", ""))
	var current_equip = str(unit.get("equip", ""))
	if not current_equip.is_empty():
		var equipped = Label.new()
		equipped.text = "已装备：%s" % current_equip
		action_panel.add_child(equipped)
		return
	var unlocked: Array = []
	for equip in db.equipment_for(unit_type):
		var name = str(equip.get("name", ""))
		if state.players[state.current_player]["equipment"].has(state.equipment_key(unit_type, name)):
			unlocked.append(equip)
	if unlocked.is_empty():
		return
	var sep = Label.new()
	sep.text = "\n装备"
	action_panel.add_child(sep)
	for equip in unlocked:
		var name = str(equip.get("name", ""))
		var captured_unit_id = int(unit["id"])
		var captured_name = name
		var btn = _make_action_button("%s  🪙 %.1f" % [name, float(equip.get("cost", 0.0))])
		_bind_action_hover(btn, _equipment_info_text(unit_type, equip))
		btn.disabled = not state.can_equip_unit(unit, name)
		btn.pressed.connect(func(): _on_equip_unit_pressed(captured_unit_id, captured_name))
		action_panel.add_child(btn)

func _add_production_buttons(building: Dictionary) -> void:
	var units: Array = []
	if state.has_method("available_units_for_player"):
		units = state.available_units_for_player(state.current_player)
	var player_era = _player_era(state.current_player)
	var sep = Label.new()
	sep.text = "\n生产单位（已解锁至 E%d）" % player_era
	action_panel.add_child(sep)
	for unit_type in units:
		var data = db.unit_data(unit_type)
		if _unit_era(str(unit_type), data) > player_era:
			continue
		var captured_building_id = int(building["id"])
		var captured_unit_type = str(unit_type)
		var command_cost = _unit_command_cost(captured_unit_type, data)
		var btn = _make_action_button("E%d %s  %.1f金  指挥%d" % [_unit_era(captured_unit_type, data), unit_type, float(data.get("price", 0.0)), command_cost])
		_bind_action_hover(btn, _unit_info_text(captured_unit_type))
		btn.disabled = not state.can_produce(building, unit_type) or _command_used(state.current_player) + command_cost > _command_capacity(state.current_player)
		btn.pressed.connect(func(): _on_produce_pressed(captured_building_id, captured_unit_type))
		action_panel.add_child(btn)

func _add_hq_upgrade_button(building: Dictionary) -> void:
	if bool(building.get("upgrading", false)):
		var label = Label.new()
		label.text = "大本营升级中：%d 回合" % int(building.get("up_timer", 0))
		action_panel.add_child(label)
		return
	var current_era = _player_era(state.current_player)
	var next_era = mini(5, current_era + 1)
	var btn = _make_action_button("升级至 E%d %s  %.1f金" % [next_era, ERA_NAMES.get(next_era, ""), _next_hq_upgrade_cost(building)])
	var can_queue_by_round = current_era >= 5 or int(state.turn) >= int(ERA_OPEN_TURNS.get(next_era, 999)) - 1
	btn.disabled = not state.can_upgrade_hq(building) or not can_queue_by_round
	if current_era >= 5:
		btn.text = "大本营已达 E5"
	elif _global_open_era() < next_era:
		btn.tooltip_text = "%s；可提前1回合排队，不能提前完成。" % _next_global_era_text()
	_bind_action_hover(btn, _building_action_info_text("hq-upgrade"))
	btn.pressed.connect(func(): _on_hq_upgrade_pressed(int(building["id"])))
	action_panel.add_child(btn)

func _core_tech_dictionary() -> Dictionary:
	for property_name in ["core_techs", "technologies", "military_techs"]:
		var value = _object_property(db, property_name, null)
		if value is Dictionary and not value.is_empty():
			return value
	var result: Dictionary = {}
	for key in db.techs.keys():
		if not str(key).to_upper().begins_with("T"):
			result[str(key)] = db.techs[key]
	return result

func _can_research_core_tech_fallback(tech_id: String, tech: Dictionary) -> bool:
	var player: Dictionary = state.players[state.current_player]
	var display_name = str(tech.get("name", tech_id))
	if player.get("researched", []).has(tech_id) or player.get("researched", []).has(display_name):
		return false
	if _is_researching_fallback(str(tech.get("name", tech_id))):
		return false
	if _era_number(tech.get("era", tech.get("tier", 1))) > _player_era(state.current_player):
		return false
	for prerequisite_id in tech.get("prerequisites", []):
		if not _player_has_technology(str(prerequisite_id)):
			return false
	return float(player.get("gold", 0.0)) >= float(_technology_research_terms_for_ui(tech_id, tech).get("cost", INF))

func _is_researching_fallback(name: String) -> bool:
	for entry in state.players[state.current_player].get("researching", []):
		if str(entry.get("name", "")) == name:
			return true
	return false

func _player_has_technology(tech_id: String) -> bool:
	if tech_id.is_empty():
		return true
	var player: Dictionary = state.players[state.current_player]
	if player.get("technology", []).has(tech_id) or player.get("researched", []).has(tech_id):
		return true
	var tech = _core_tech_dictionary().get(tech_id, {})
	return not tech.is_empty() and player.get("researched", []).has(str(tech.get("name", tech_id)))

func _technology_missing_prerequisites(tech_id: String, tech: Dictionary = {}) -> Array[String]:
	if state.has_method("missing_technology_prerequisites"):
		return state.missing_technology_prerequisites(state.current_player, tech_id)
	var data = tech if not tech.is_empty() else _core_tech_dictionary().get(tech_id, {})
	var result: Array[String] = []
	for prerequisite_id in data.get("prerequisites", []):
		if not _player_has_technology(str(prerequisite_id)):
			result.append(str(prerequisite_id))
	return result

func _technology_name(tech_id: String) -> String:
	var tech = _core_tech_dictionary().get(tech_id, {})
	return str(tech.get("name", tech_id))

func _prerequisite_names(tech_id: String, tech: Dictionary = {}) -> String:
	var names: Array[String] = []
	for prerequisite_id in _technology_missing_prerequisites(tech_id, tech):
		names.append(_technology_name(prerequisite_id))
	return "、".join(names)

func _technology_research_terms_for_ui(tech_id: String, tech: Dictionary) -> Dictionary:
	if state.has_method("technology_research_terms"):
		return state.technology_research_terms(state.current_player, tech_id)
	var terms = {
		"cost": float(tech.get("cost", tech.get("research_cost", 0.0))),
		"research_time": int(tech.get("research_time", tech.get("turns", 1))),
		"soft_prerequisite_applied": false
	}
	var soft_prerequisite = tech.get("soft_prerequisite", {})
	if soft_prerequisite is Dictionary:
		var prerequisite_id = str(soft_prerequisite.get("technology", ""))
		var researched = state.players[state.current_player].get("researched", [])
		var technology = state.players[state.current_player].get("technology", [])
		if researched.has(prerequisite_id) or technology.has(prerequisite_id):
			terms["cost"] = float(soft_prerequisite.get("cost", terms["cost"]))
			terms["research_time"] = int(soft_prerequisite.get("research_time", terms["research_time"]))
			terms["soft_prerequisite_applied"] = true
	return terms

func _start_core_tech_fallback(tech_id: String, tech: Dictionary) -> bool:
	if not _can_research_core_tech_fallback(tech_id, tech):
		return false
	var player: Dictionary = state.players[state.current_player]
	var terms = _technology_research_terms_for_ui(tech_id, tech)
	var cost = float(terms.get("cost", 0.0))
	player["gold"] = float(player.get("gold", 0.0)) - cost
	player["researching"].append({
		"id": tech_id,
		"name": str(tech.get("name", tech_id)),
		"kind": "technology",
		"timer": int(terms.get("research_time", 1))
	})
	return true

func _add_core_tech_buttons() -> void:
	var current_era = _player_era(state.current_player)
	var techs = _core_tech_dictionary()
	var sep = Label.new()
	sep.text = "\n科技树（硬前置 · 并行研究）"
	action_panel.add_child(sep)
	if techs.is_empty():
		return
	var route_titles = {"line": "战线路线", "mobile": "机动路线", "firepower": "火力路线", "support": "支援路线"}
	for route in ["line", "mobile", "firepower", "support"]:
		var route_label = Label.new()
		route_label.text = "\n%s" % route_titles[route]
		action_panel.add_child(route_label)
		for tech_id in _technology_ids_for_route(route, current_era):
			_add_technology_tree_node(tech_id, techs[tech_id])
		var route_units: Array = db.units_for_route(route) if db.has_method("units_for_route") else []
		if current_era - 1 < route_units.size():
			var current_unit = str(route_units[current_era - 1])
			_add_equipment_branch_for_unit(current_unit, current_era)
	var development = Label.new()
	development.text = "\n建设与后勤路线"
	action_panel.add_child(development)
	for tech_id in _technology_ids_for_route("development", current_era):
		_add_technology_tree_node(tech_id, techs[tech_id])

func _technology_ids_for_route(route: String, max_era: int) -> Array[String]:
	var result: Array[String] = []
	for raw_id in _core_tech_dictionary().keys():
		var tech_id = str(raw_id)
		var tech: Dictionary = _core_tech_dictionary()[raw_id]
		if bool(tech.get("strategic", false)) or _era_number(tech.get("era", 1)) > max_era:
			continue
		var routes: Array = tech.get("routes", [])
		if routes.has(route):
			result.append(tech_id)
	result.sort_custom(func(a: String, b: String):
		var era_a = _era_number(_core_tech_dictionary()[a].get("era", 1))
		var era_b = _era_number(_core_tech_dictionary()[b].get("era", 1))
		return era_a < era_b if era_a != era_b else a < b
	)
	return result

func _add_technology_tree_node(tech_id: String, tech: Dictionary) -> void:
	var display_name = str(tech.get("name", tech_id))
	var era = _era_number(tech.get("era", tech.get("tier", 1)))
	if _player_has_technology(tech_id):
		var completed = Label.new()
		completed.text = "  ✓ E%d %s" % [era, display_name]
		completed.modulate = Color(0.55, 0.82, 0.58)
		action_panel.add_child(completed)
		return
	var active = state.research_entry(state.current_player, display_name) if state.has_method("research_entry") else {}
	if not active.is_empty():
		var progress = Label.new()
		progress.text = "  ↓ E%d %s（剩%d回合）" % [era, display_name, int(active.get("timer", active.get("turns", 0)))]
		progress.modulate = Color(0.90, 0.75, 0.30)
		action_panel.add_child(progress)
		return
	var captured_id = tech_id
	var captured_tech = tech
	var terms = _technology_research_terms_for_ui(captured_id, captured_tech)
	var missing = _prerequisite_names(captured_id, captured_tech)
	var prefix = "  ↓ " if missing.is_empty() else "  × "
	var btn = _make_action_button("%sE%d %s  %.1f金/%d回合" % [prefix, era, display_name, float(terms.get("cost", 0.0)), int(terms.get("research_time", 1))])
	var hover = _tech_info_text(captured_id, captured_tech, terms)
	if not missing.is_empty():
		hover += "\n硬性前置：%s" % missing
	_bind_action_hover(btn, hover)
	var can_research = false
	var found_research_method = false
	for method_name in ["can_research_tech", "can_research_core_tech", "can_start_research"]:
		if state.has_method(method_name):
			found_research_method = true
			can_research = bool(_call_state_research_method(method_name, captured_id, captured_tech))
			break
	if not found_research_method:
		can_research = _can_research_core_tech_fallback(captured_id, captured_tech)
	btn.disabled = not can_research
	btn.pressed.connect(func(): _on_core_tech_pressed(captured_id, captured_tech))
	action_panel.add_child(btn)

func _add_equipment_branch_for_unit(unit_type: String, era: int) -> void:
	var equips = db.equipment_for(unit_type)
	if equips.is_empty():
		return
	if not state.target_unlocked(state.current_player, unit_type):
		var locked = Label.new()
		locked.text = "      └─ %s装备（先解锁单位）" % unit_type
		locked.modulate = Color(0.45, 0.45, 0.52)
		action_panel.add_child(locked)
		return
	var pending: Array[Dictionary] = []
	for equip in equips:
		if _era_number(equip.get("era", equip.get("tier", 1))) != era:
			continue
		var key = state.equipment_key(unit_type, str(equip.get("name", "")))
		if not state.players[state.current_player]["equipment"].has(key):
			pending.append(equip)
	for index in range(pending.size()):
		_add_equipment_tree_node(unit_type, pending[index], "      └→ " if index == pending.size() - 1 else "      ├→ ")

func _add_equipment_tree_node(unit_type: String, equip: Dictionary, prefix: String) -> void:
	var name = str(equip.get("name", ""))
	var active = state.research_entry(state.current_player, name)
	if not active.is_empty():
		var label = Label.new()
		label.text = "%s%s（剩%d回合）" % [prefix, name, int(active.get("timer", 0))]
		label.modulate = Color(0.90, 0.75, 0.30)
		action_panel.add_child(label)
		return
	var captured_unit_type = unit_type
	var captured_name = name
	var btn = _make_action_button("%s%s  %.1f金/%d回合" % [prefix, name, float(equip.get("research_cost", 0.0)), int(equip.get("research_time", 1))])
	_bind_action_hover(btn, _equipment_info_text(captured_unit_type, equip))
	btn.disabled = not state.can_research_equipment(state.current_player, captured_unit_type, captured_name)
	btn.pressed.connect(func(): _on_equipment_pressed(captured_unit_type, captured_name))
	action_panel.add_child(btn)

func _add_equipment_buttons() -> void:
	var current_tier = _player_era(state.current_player)
	var visible_equipment: Array[Dictionary] = []
	for unit_type in db.equipment.keys():
		if db.unit_aliases.has(str(unit_type)):
			continue
		for equip in db.equipment_for(unit_type):
			if _era_number(equip.get("era", equip.get("tier", 1))) < current_tier:
				var key = state.equipment_key(str(unit_type), str(equip.get("name", "")))
				if not state.players[state.current_player]["equipment"].has(key):
					visible_equipment.append({"unit_type": str(unit_type), "equip": equip})
	if visible_equipment.is_empty():
		return
	var toggle = _make_action_button("▸ 旧时代可选装备（%d）" % visible_equipment.size())
	toggle.pressed.connect(func():
		show_legacy_equipment = not show_legacy_equipment
		_refresh_action_panel()
	)
	action_panel.add_child(toggle)
	if not show_legacy_equipment:
		return
	for visible_entry in visible_equipment:
		var unit_type = str(visible_entry["unit_type"])
		var equip: Dictionary = visible_entry["equip"]
		_add_equipment_tree_node(unit_type, equip, "  └→ ")

func _add_strategic_buttons() -> void:
	var current_tier = _player_era(state.current_player)
	var visible_techs: Array[String] = []
	for tech_name in db.strategic_techs.keys():
		if _era_number(db.strategic_techs[tech_name].get("era", db.strategic_techs[tech_name].get("tier", 1))) <= current_tier:
			visible_techs.append(str(tech_name))
	if visible_techs.is_empty():
		return
	var sep = Label.new()
	sep.text = "\n战略科技"
	action_panel.add_child(sep)
	var any = false
	for tech_name in visible_techs:
		if state.players[state.current_player]["strategic"].has(tech_name):
			continue
		var active_research = state.research_entry(state.current_player, str(tech_name))
		if not active_research.is_empty():
			var label = Label.new()
			label.text = "%s 研究中：%d 回合" % [tech_name, int(active_research.get("timer", 0))]
			action_panel.add_child(label)
			any = true
			continue
		any = true
		var tech = db.strategic_techs[tech_name]
		var captured_tech_name = str(tech_name)
		var btn = _make_action_button("%s  🪙 %.1f" % [tech_name, float(tech.get("cost", 0.0))])
		_bind_action_hover(btn, _strategic_info_text(captured_tech_name, tech))
		btn.disabled = not state.can_research_strategic(state.current_player, tech_name)
		btn.pressed.connect(func(): _on_strategic_pressed(captured_tech_name))
		action_panel.add_child(btn)
	if not any:
		var done = Label.new()
		done.text = "战略科技已完成"
		action_panel.add_child(done)

func _add_collector_button(building: Dictionary) -> void:
	if state.has_method("target_unlocked") and not state.target_unlocked(state.current_player, "资源采集器"):
		return
	var sep = Label.new()
	sep.text = "\n建筑"
	action_panel.add_child(sep)
	var data = db.building_data("资源采集器")
	var btn = _make_action_button("⛏ 资源采集器  🪙 %.1f" % float(data.get("cost", 12.0)))
	_bind_action_hover(btn, _building_action_info_text("collector"))
	btn.disabled = float(state.players[state.current_player]["gold"]) < float(data.get("cost", 12.0))
	btn.pressed.connect(func(): _on_build_collector_pressed(int(building["id"])))
	action_panel.add_child(btn)

func _add_outpost_buttons(building: Dictionary) -> void:
	if int(building.get("pid", -1)) != state.current_player:
		var note = Label.new()
		note.text = "中立据点：移动单位到这里可占领。"
		action_panel.add_child(note)
		return
	var sep = Label.new()
	sep.text = "\n据点升级"
	action_panel.add_child(sep)
	if bool(building.get("upgrading", false)):
		var upgrading = Label.new()
		upgrading.text = "升级中... %d 回合" % int(building.get("up_timer", 0))
		action_panel.add_child(upgrading)
		return
	if int(building.get("outpost_tier", 0)) > 0:
		var done = Label.new()
		done.text = "已升级：%s" % _outpost_branch_label(str(building.get("outpost_branch", "")))
		action_panel.add_child(done)
		return
	if _player_era(state.current_player) < 2:
		var locked = Label.new()
		locked.text = "需要大本营升级到 E2 后才能分化据点。"
		action_panel.add_child(locked)
		return
	var combat = _make_action_button("⚔ 战斗型据点  🪙 10.0")
	_bind_action_hover(combat, _building_action_info_text("outpost-combat"))
	combat.disabled = not state.can_upgrade_outpost(building, "combat")
	combat.pressed.connect(func(): _on_outpost_upgrade_pressed(int(building["id"]), "combat"))
	action_panel.add_child(combat)
	var economic = _make_action_button("💰 经济型据点  🪙 10.0")
	_bind_action_hover(economic, _building_action_info_text("outpost-economic"))
	economic.disabled = not state.can_upgrade_outpost(building, "economic")
	economic.pressed.connect(func(): _on_outpost_upgrade_pressed(int(building["id"]), "economic"))
	action_panel.add_child(economic)

func _on_produce_pressed(building_id: int, unit_type: String) -> void:
	if not _can_control_current_turn():
		return
	_push_undo_state()
	if state.produce_unit(building_id, unit_type):
		_play_sfx("upgrade")
		_notify_online("produce")
	else:
		_pop_failed_undo()
	_refresh_ui()
	board.queue_redraw()

func _on_build_collector_pressed(building_id: int) -> void:
	if not _can_control_current_turn():
		return
	if state.has_method("target_unlocked") and not state.target_unlocked(state.current_player, "资源采集器"):
		_show_hover_info(["资源采集器尚未解锁", "需要先完成核心科技：有组织采集"])
		return
	_clear_selection()
	build_mode = "资源采集器"
	build_origin_id = building_id
	var origin = state.get_building_by_id(building_id)
	var income = state.next_collector_income(state.current_player)
	info_label.text = "建造资源采集器：点击大本营 5 格内空地。\n费用 12 金，2 回合完工；当前采集器完工后每回合 +%.2f 金。" % income
	board.set_build_tiles(state.collector_build_tiles(origin), Color(0.15, 0.72, 1.0), income)
	_refresh_ui()

func _on_outpost_upgrade_pressed(building_id: int, branch: String) -> void:
	if not _can_control_current_turn():
		return
	_push_undo_state()
	if state.upgrade_outpost(building_id, branch):
		_play_sfx("upgrade")
		_notify_online("outpost-upgrade")
	else:
		_pop_failed_undo()
	_refresh_ui()
	board.queue_redraw()

func _on_surrender_pressed() -> void:
	if state.game_over or not _can_control_current_turn():
		return
	_push_undo_state()
	state.surrender(state.current_player)
	_clear_selection()
	if state.game_over:
		_play_sfx("victory")
	_notify_online("surrender")
	_after_turn_state_changed(true)

func _on_hq_upgrade_pressed(building_id: int) -> void:
	if not _can_control_current_turn():
		return
	_push_undo_state()
	if state.upgrade_hq(building_id):
		_play_sfx("upgrade")
		_notify_online("upgrade-hq")
	else:
		_pop_failed_undo()
	_refresh_ui()
	board.queue_redraw()

func _on_core_tech_pressed(tech_id: String, tech: Dictionary) -> void:
	if not _can_control_current_turn():
		return
	_push_undo_state()
	var started = false
	var found_research_method = false
	for method_name in ["research_tech", "research_core_tech", "start_research"]:
		if state.has_method(method_name):
			found_research_method = true
			started = bool(_call_state_research_method(method_name, tech_id, tech))
			break
	if not found_research_method:
		started = _start_core_tech_fallback(tech_id, tech)
	if started:
		_play_sfx("upgrade")
		_notify_online("research-core-tech")
	else:
		_pop_failed_undo()
	_refresh_ui()

func _on_equipment_pressed(unit_type: String, equip_name: String) -> void:
	if not _can_control_current_turn():
		return
	_push_undo_state()
	if state.research_equipment(state.current_player, unit_type, equip_name):
		_play_sfx("upgrade")
		_notify_online("research-equipment")
	else:
		_pop_failed_undo()
	_refresh_ui()

func _on_equip_unit_pressed(unit_id: int, equip_name: String) -> void:
	if not _can_control_current_turn():
		return
	_push_undo_state()
	if state.equip_unit(unit_id, equip_name):
		_play_sfx("upgrade")
		_notify_online("equip")
	else:
		_pop_failed_undo()
	_refresh_ui()
	board.queue_redraw()

func _on_evolve_unit_pressed(unit_id: int, next_type: String) -> void:
	if not _can_control_current_turn():
		return
	var unit = state.get_unit_by_id(unit_id)
	if unit.is_empty():
		return
	_push_undo_state()
	var evolved = false
	for method_name in ["evolve_unit", "upgrade_unit", "promote_unit"]:
		if state.has_method(method_name):
			evolved = bool(_call_state_entity_method(method_name, unit, next_type))
			break
	if evolved:
		_play_sfx("upgrade")
		_notify_online("evolve-unit")
		_clear_selection()
	else:
		_pop_failed_undo()
	_refresh_ui()
	board.queue_redraw()

func _on_strategic_pressed(tech_name: String) -> void:
	if not _can_control_current_turn():
		return
	_push_undo_state()
	if state.research_strategic(state.current_player, tech_name):
		_play_sfx("upgrade")
		_notify_online("research-strategic")
	else:
		_pop_failed_undo()
	_refresh_ui()
	board.queue_redraw()

func _on_skip_unit_pressed(unit_id: int) -> void:
	if not _can_control_current_turn():
		return
	_push_undo_state()
	if state.skip_unit(unit_id):
		_clear_selection()
		_notify_online("skip")
	else:
		_pop_failed_undo()
	_refresh_ui()
	board.queue_redraw()

func _show_game_over_panel() -> void:
	if game_over_panel == null or game_over_panel.visible:
		return
	_play_sfx("victory")
	_notify_online("game-over")
	if board != null:
		_center_on_player_hq(state.winner)
	game_over_panel.visible = true
	for child in game_over_panel.get_children():
		child.queue_free()
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	game_over_panel.add_child(outer)
	var victory = TextureRect.new()
	victory.custom_minimum_size = Vector2(520, 150)
	victory.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	victory.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	victory.texture = load(_victory_image_path(state.winner))
	outer.add_child(victory)
	var charts = GridContainer.new()
	charts.columns = 2
	charts.add_theme_constant_override("h_separation", 12)
	charts.add_theme_constant_override("v_separation", 12)
	outer.add_child(charts)
	for spec in [
		["army_value", "军队价值"],
		["gold", "金币总数"],
		["kill_value", "累计击杀"],
		["income", "回合收入"]
	]:
		var chart = StatsChart.new()
		chart.setup(state, spec[0], spec[1])
		charts.add_child(chart)
	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	outer.add_child(buttons)
	var save_btn = Button.new()
	save_btn.text = "保存结算 PNG"
	save_btn.pressed.connect(_save_settlement_png)
	buttons.add_child(save_btn)
	var again_btn = Button.new()
	again_btn.text = "再来一局"
	again_btn.pressed.connect(_on_restart_pressed)
	buttons.add_child(again_btn)
	var menu_btn = Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.pressed.connect(_return_to_main_menu)
	buttons.add_child(menu_btn)
	game_over_status_label = Label.new()
	game_over_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(game_over_status_label)

func _victory_image_path(pid: int) -> String:
	var names = ["红方胜利.png", "蓝方胜利.png", "绿方胜利.png", "黄方胜利.png"]
	if pid < 0 or pid >= names.size():
		return ""
	return "res://assets/images/%s" % names[pid]

func _center_on_player_hq(pid: int) -> void:
	if board == null:
		return
	for building in state.buildings:
		if building.get("type", "") == "大本营" and int(building.get("pid", -1)) == pid:
			board.center_on_tile(building["pos"])
			return

func _save_settlement_png() -> void:
	await get_tree().process_frame
	var image = get_viewport().get_texture().get_image()
	var path = "user://green_legion_settlement_%d.png" % Time.get_unix_time_from_system()
	var err = image.save_png(path)
	if game_over_status_label != null:
		if err == OK:
			game_over_status_label.text = "已保存：" + ProjectSettings.globalize_path(path)
		else:
			game_over_status_label.text = "保存失败：" + str(err)

func _can_control_current_turn() -> bool:
	if online_connected:
		return online_player_id == state.current_player
	if vs_ai:
		return not ai_thinking and state.current_player != ai_player_id
	return true

func _notify_online(reason: String) -> void:
	if not online_connected or online_socket == null or online_player_id < 0:
		return
	if online_applying_remote:
		return
	if online_socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var msg = {
		"type": "state",
		"roomId": online_room_id,
		"playerId": online_player_id,
		"reason": reason,
		"state": state.to_dict()
	}
	online_socket.send_text(JSON.stringify(msg))
	_update_online_status("已同步：" + reason)

func _on_online_create_pressed() -> void:
	online_is_host = true
	online_manual_leave = false
	_online_connect_and_send({"type": "create", "players": player_count})

func _on_online_join_pressed() -> void:
	var room_id = online_room_input.text.strip_edges().to_upper()
	if room_id.is_empty():
		_update_online_status("先输入房间号")
		return
	online_is_host = false
	online_manual_leave = false
	_online_connect_and_send({"type": "join", "roomId": room_id})

func _on_online_leave_pressed() -> void:
	online_manual_leave = true
	if online_socket != null:
		online_socket.close()
	online_connected = false
	online_room_id = ""
	online_player_id = -1
	online_is_host = false
	online_reconnect_active = false
	_clear_online_session()
	_sync_board_view_player()
	_update_online_status("本地热座")
	_refresh_ui()

func _online_connect_and_send(msg: Dictionary) -> void:
	if online_socket == null or online_socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		online_socket = WebSocketPeer.new()
		var err = online_socket.connect_to_url(online_url_input.text.strip_edges())
		if err != OK:
			_update_online_status("连接失败：" + str(err))
			return
		_update_online_status("连接服务器中")
	for _i in range(20):
		online_socket.poll()
		if online_socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			break
		await get_tree().create_timer(0.1).timeout
	if online_socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		online_socket.send_text(JSON.stringify(msg))
	else:
		_update_online_status("服务器未连接")

func _saved_online_url() -> String:
	var cfg = ConfigFile.new()
	if cfg.load("user://online_reconnect.cfg") == OK:
		return str(cfg.get_value("online", "url", "ws://175.178.173.76:3000"))
	return "ws://175.178.173.76:3000"

func _remember_online_session() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("online", "url", online_url_input.text.strip_edges())
	cfg.set_value("online", "room_id", online_room_id)
	cfg.set_value("online", "player_id", online_player_id)
	cfg.save("user://online_reconnect.cfg")

func _clear_online_session() -> void:
	var cfg = ConfigFile.new()
	cfg.save("user://online_reconnect.cfg")

func _schedule_online_reconnect() -> void:
	if online_reconnect_active:
		return
	online_reconnect_active = true
	call_deferred("_attempt_online_reconnect")

func _attempt_online_reconnect() -> void:
	await get_tree().create_timer(1.0).timeout
	if online_manual_leave or online_room_id.is_empty() or online_player_id < 0:
		online_reconnect_active = false
		return
	_update_online_status("尝试重连房间 " + online_room_id)
	online_socket = WebSocketPeer.new()
	var err = online_socket.connect_to_url(online_url_input.text.strip_edges())
	if err != OK:
		online_reconnect_active = false
		_schedule_online_reconnect()
		return
	for _i in range(30):
		online_socket.poll()
		if online_socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			break
		await get_tree().create_timer(0.1).timeout
	if online_socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		online_connected = true
		online_reconnect_active = false
		online_socket.send_text(JSON.stringify({"type": "rejoin", "roomId": online_room_id, "playerId": online_player_id}))
		_update_online_status("已发送重连请求")
	else:
		online_reconnect_active = false
		_schedule_online_reconnect()

func _poll_online() -> void:
	if online_socket == null:
		return
	online_socket.poll()
	var ready = online_socket.get_ready_state()
	if ready == WebSocketPeer.STATE_OPEN:
		online_connected = true
		while online_socket.get_available_packet_count() > 0:
			var text = online_socket.get_packet().get_string_from_utf8()
			var msg = JSON.parse_string(text)
			if msg is Dictionary:
				_handle_online_message(msg)
	elif ready == WebSocketPeer.STATE_CLOSING:
		_update_online_status("连接关闭中")
	elif ready == WebSocketPeer.STATE_CLOSED and online_connected:
		online_connected = false
		_update_online_status("连接已断开")
		if not online_manual_leave and not online_room_id.is_empty() and online_player_id >= 0:
			_schedule_online_reconnect()
		_refresh_ui()

func _handle_online_message(msg: Dictionary) -> void:
	var msg_type = str(msg.get("type", ""))
	if msg_type == "error":
		_update_online_status("错误：" + str(msg.get("message", "")))
	elif msg_type == "room-created":
		online_room_id = str(msg.get("roomId", ""))
		online_player_id = int(msg.get("playerId", 0))
		player_count = int(msg.get("players", player_count))
		_setup_state()
		board.setup(state, db)
		_sync_board_view_player()
		board.center_on_current_player()
		menu_layer.visible = false
		_set_game_visible(true)
		online_room_input.text = online_room_id
		_remember_online_session()
		_update_online_status("房间 " + online_room_id + " 已创建，你是 " + _player_name(online_player_id))
		_notify_online("initial")
	elif msg_type == "joined":
		online_room_id = str(msg.get("roomId", ""))
		online_player_id = int(msg.get("playerId", 0))
		player_count = int(msg.get("players", player_count))
		if msg.has("state") and msg["state"] is Dictionary:
			online_applying_remote = true
			state.load_from_dict(msg["state"])
			online_applying_remote = false
		else:
			_setup_state()
		board.setup(state, db)
		_sync_board_view_player()
		board.center_on_current_player()
		menu_layer.visible = false
		_set_game_visible(true)
		online_room_input.text = online_room_id
		_remember_online_session()
		_update_online_status("加入 " + online_room_id + "，你是 " + _player_name(online_player_id))
	elif msg_type == "peer-joined":
		_update_online_status("玩家加入：" + _player_name(int(msg.get("playerId", -1))))
		if online_is_host:
			_notify_online("peer-joined")
	elif msg_type == "peer-left":
		_update_online_status("有玩家断开，等待重连")
	elif msg_type == "state":
		if int(msg.get("playerId", -1)) == online_player_id:
			return
		if msg.has("state") and msg["state"] is Dictionary:
			_apply_remote_state(msg["state"])
			_update_online_status("收到同步：" + str(msg.get("reason", "state")))
	_refresh_ui()
	board.queue_redraw()

func _apply_remote_state(remote_state: Dictionary) -> void:
	var previous_offset = board.camera_offset if board != null else Vector2.ZERO
	var previous_zoom = board.zoom if board != null else 1.0
	online_applying_remote = true
	state.load_from_dict(remote_state)
	online_applying_remote = false
	player_count = int(state.player_count)
	board.setup(state, db)
	_sync_board_view_player()
	board.zoom = previous_zoom
	board.camera_offset = previous_offset
	board._clamp_camera()
	state.update_vision()

func _update_online_status(text: String) -> void:
	if online_status_label != null:
		online_status_label.text = text

func _count_player_units(pid: int) -> int:
	var count = 0
	for unit in state.units:
		if int(unit["pid"]) == pid:
			count += 1
	return count

func _count_player_buildings(pid: int) -> int:
	var count = 0
	for building in state.buildings:
		if int(building["pid"]) == pid:
			count += 1
	return count

func _player_name(pid: int) -> String:
	if pid < 0:
		return "中立"
	return str(state.players[pid]["name"])

func _unit_info_text(unit_type: String) -> String:
	var data = db.unit_data(unit_type)
	if data.is_empty():
		return unit_type
	var tags = []
	if bool(data.get("is_air", false)):
		tags.append("空军")
	if bool(data.get("can_target_air", false)):
		tags.append("可对空")
	if bool(data.get("self_destruct", false)):
		tags.append("自爆")
	if float(data.get("blast", 0.0)) > 0.0:
		tags.append("范围 %.1f" % float(data.get("blast", 0.0)))
	var lines = [
		unit_type,
		"%s  %s  指挥 %d" % [_era_label(_unit_era(unit_type, data)), _unit_role(unit_type, data), _unit_command_cost(unit_type, data)],
		"价格 %.1f  HP %.1f  护甲 %.1f" % [float(data.get("price", 0.0)), float(data.get("hp", 0.0)), float(data.get("armor", 0.0))],
		"伤害 %.1f  射程 %.1f  移速 %d  攻击次数 %d" % [float(data.get("damage", 0.0)), float(data.get("range", 0.0)), int(data.get("speed", 0)), int(data.get("attacks", 0))],
		"视野 %d" % int(data.get("vision", 0))
	]
	if data.has("air_damage"):
		lines.append("对空伤害 %.1f  对空射程 %.1f" % [float(data.get("air_damage", 0.0)), float(data.get("air_range", 0.0))])
	if not tags.is_empty():
		lines.append("特性：" + "、".join(tags))
	return "\n".join(lines)

func _equipment_info_text(unit_type: String, equip: Dictionary) -> String:
	var data = db.unit_data(unit_type)
	var lines = [
		"%s：%s" % [unit_type, str(equip.get("name", ""))],
		"研究 %.1f 金  需求 E%d" % [float(equip.get("research_cost", 0.0)), _era_number(equip.get("era", equip.get("tier", 1)))]
	]
	_add_delta_line(lines, "价格", data.get("price", 0.0), equip.get("cost", null))
	_add_delta_line(lines, "HP", data.get("hp", 0.0), equip.get("hp", null))
	_add_delta_line(lines, "护甲", data.get("armor", 0.0), equip.get("armor", null))
	_add_delta_line(lines, "伤害", data.get("damage", 0.0), equip.get("dmg", null))
	_add_delta_line(lines, "射程", data.get("range", 0.0), equip.get("range", null))
	_add_delta_line(lines, "移速", data.get("speed", 0.0), equip.get("speed", null))
	if equip.has("blast"):
		lines.append("范围伤害：%.1f → %.1f" % [float(data.get("blast", 0.0)), float(equip.get("blast", 0.0))])
	if bool(equip.get("can_target_air", false)):
		lines.append("新增：可以攻击空军")
	return "\n".join(lines)

func _add_delta_line(lines: Array, label: String, base_value, delta_value) -> void:
	if delta_value == null:
		return
	var base = float(base_value)
	var delta = float(delta_value)
	lines.append("%s：%.1f → %.1f" % [label, base, base + delta])

func _strategic_info_text(tech_name: String, tech: Dictionary) -> String:
	var text = "%s\n研究 %.1f 金  需求 E%d\n%s" % [
		tech_name,
		float(tech.get("cost", 0.0)),
		_era_number(tech.get("era", tech.get("tier", 1))),
		str(tech.get("desc", ""))
	]
	var tech_id = str(tech.get("id", ""))
	var missing = _prerequisite_names(tech_id) if not tech_id.is_empty() else ""
	if not missing.is_empty():
		text += "\n硬性前置：%s" % missing
	return text

func _tech_info_text(tech_id: String, tech: Dictionary, terms: Dictionary = {}) -> String:
	var unlocks = []
	for unit_type in tech.get("unlocks", []):
		unlocks.append(str(unit_type))
	var resolved_terms = terms if not terms.is_empty() else _technology_research_terms_for_ui(tech_id, tech)
	var lines = [
		"%s  E%d" % [str(tech.get("name", tech_id)), _era_number(tech.get("era", tech.get("tier", 1)))],
		"研究 %.1f 金 / %d 回合" % [float(resolved_terms.get("cost", tech.get("cost", 0.0))), int(resolved_terms.get("research_time", tech.get("research_time", 1)))],
		"解锁：%s" % ("、".join(unlocks) if not unlocks.is_empty() else "无直接解锁")
	]
	var prerequisites: Array[String] = []
	for prerequisite_id in tech.get("prerequisites", []):
		prerequisites.append(_technology_name(str(prerequisite_id)))
	if not prerequisites.is_empty():
		lines.append("硬性前置：%s" % "、".join(prerequisites))
	var description = str(tech.get("desc", tech.get("effect", ""))).strip_edges()
	if not description.is_empty():
		lines.append(description)
	var effects = tech.get("effects", {})
	if effects is Dictionary:
		for effect_name in effects.keys():
			if str(effect_name) == "logistics_multiplier":
				lines.append("资源采集器收入倍率：×%.2f（只取最高倍率）" % float(effects[effect_name]))
			else:
				lines.append("%s：%s" % [str(effect_name), str(effects[effect_name])])
	if bool(resolved_terms.get("soft_prerequisite_applied", false)):
		lines.append("已应用前置科技优惠")
	return "\n".join(lines)

func _building_action_info_text(kind: String) -> String:
	if kind == "collector":
		return "资源采集器\n建造 12 金 / 2 回合\n点击大本营 5 格内空地建造。\n完工后按编号产金：4.5 × 0.8^编号。"
	if kind == "outpost-combat":
		var combat_era := maxi(2, _player_era(state.current_player))
		var combat: Dictionary = db.building_data("据点").get("eras", {}).get("E%d" % combat_era, {}).get("combat", {})
		return "战斗据点\n升级 %.1f 金 / %d 回合\nHP %.1f，护甲 %.1f，每回合 +%.1f。\n当前时代战线/机动；编制+2；驻扎恢复35%%。" % [float(combat.get("upgrade_cost", 0.0)), int(combat.get("upgrade_time", 1)), float(combat.get("hp", 0.0)), float(combat.get("armor", 0.0)), float(combat.get("gold", 0.0))]
	if kind == "outpost-economic":
		var economic_era := maxi(2, _player_era(state.current_player))
		var economic: Dictionary = db.building_data("据点").get("eras", {}).get("E%d" % economic_era, {}).get("economic", {})
		return "经济据点\n升级 %.1f 金 / %d 回合\nHP %.1f，护甲 %.1f，每回合 +%.1f。\n上一时代战线；编制+0；驻扎恢复10%%。" % [float(economic.get("upgrade_cost", 0.0)), int(economic.get("upgrade_time", 1)), float(economic.get("hp", 0.0)), float(economic.get("armor", 0.0)), float(economic.get("gold", 0.0))]
	if kind == "hq-upgrade":
		return "大本营升级\n提升大本营 HP、护甲、收入、视野；升级倒计时完成后解锁下一时代兵种和科技条件。"
	return ""

func _outpost_branch_label(branch: String) -> String:
	if branch == "combat":
		return "%s 战斗据点" % _era_label(_player_era(state.current_player))
	if branch == "economic":
		return "%s 经济据点" % _era_label(_player_era(state.current_player))
	return "%s 基础据点" % _era_label(_player_era(state.current_player))

func _encyclopedia_text() -> String:
	var lines = ["绿色军团战术百科", ""]
	lines.append("单位")
	for unit_type in db.units.keys():
		lines.append(_unit_info_text(str(unit_type)))
		lines.append("")
	lines.append("装备研究")
	for unit_type in db.equipment.keys():
		for equip in db.equipment_for(str(unit_type)):
			lines.append(_equipment_info_text(str(unit_type), equip))
			lines.append("")
	lines.append("战略科技")
	for tech_name in db.strategic_techs.keys():
		lines.append(_strategic_info_text(str(tech_name), db.strategic_techs[tech_name]))
		lines.append("")
	lines.append("地形")
	for terrain_id in db.terrain.keys():
		var terrain = db.terrain_data(str(terrain_id))
		lines.append("%s：高度 %d，基础移动 %.1f" % [
			str(terrain.get("name", terrain_id)),
			int(terrain.get("height", 0)),
			float(terrain.get("move_cost", 1.0))
		])
	return "\n".join(lines)

func _era_rules_bbcode() -> String:
	var lines = [
		"[font_size=26][color=#f0e6c0]E1-E5 五时代规则[/color][/font_size]",
		"[color=#8a8a9a]从部落战争进化到信息化战争；未来时代不会提前出现在生产栏。[/color]", "",
		"[b]全局开放与玩家升级[/b]",
		"时代按完整回合开放：E1 1-13，E2 14-27，E3 28-42，E4 43-58，E5 59-74；75回合起总体战。玩家仍需支付大本营升级费用，最多可提前1回合排队，但不能提前完成。落后全局2个时代时，下一次时代升级费用降低20%。", "",
		"[table=4][cell][b]时代[/b][/cell][cell][b]名称[/b][/cell][cell][b]开放回合[/b][/cell][cell][b]战争逻辑[/b][/cell]",
		"[cell]E1[/cell][cell]部落战争[/cell][cell]1[/cell][cell]数量、探索、地形[/cell]",
		"[cell]E2[/cell][cell]冷兵器战争[/cell][cell]9[/cell][cell]方阵、冲锋、掩护[/cell]",
		"[cell]E3[/cell][cell]火药战争[/cell][cell]19[/cell][cell]列阵、侧击、炮兵观测[/cell]",
		"[cell]E4[/cell][cell]机械化战争[/cell][cell]31[/cell][cell]装甲阈值、机动穿插[/cell]",
		"[cell]E5[/cell][cell]信息化战争[/cell][cell]45[/cell][cell]共享视野、无人作战、精确打击[/cell][/table]", "",
		"[b]战斗与相邻加成[/b]",
		"[code]有效伤害 = max(0, 攻击力 + 目标类型修正 - 目标护甲)[/code]",
		"允许伤害为0。相邻指周围八格。战团、方阵、火枪连和士兵的同类阵型加成，以及无人战车获得的无人机支援，最多叠加2层；投石队、弓弩/投石车、野战炮、自行火炮及侦察视野支援只判定是否存在，不随相同支援单位数量叠加。实际攻击、护甲、射程修正及来源显示在单位悬停卡。高地射程修正限制在-2至+2。", "",
		"[b]单位进化[/b]",
		"旧单位不会自动消失。单位位于己方大本营或战斗据点驻扎范围时，可沿战线、机动、火力、支援路线进化；进化消耗本回合行动，保留生命比例与经验。旧装备仅在存在兼容装备时转换。", "",
		"[b]生产与指挥容量[/b]",
		"战线/支援单位占1点，机动/火力单位占2点。基础容量E1至E5依次为12/14/16/18/20；基础据点+1，战斗据点+2，经济据点不增加。达到上限不能生产，但仍可进化。", "",
		"[b]战役优势与终局[/b]",
		"每个完整回合结束时，控制至少2个战略点且领先的一方获得1点战役优势，最多3点。达到3点触发2回合总攻窗口：目标大本营停止回血，己方火力攻击其时忽略一半护甲。第75回合起所有大本营永久暴露并停止回血，火力攻击建筑+25%。", "",
		"[b]战争迷雾与操作[/b]",
		"敌方单位只有当前可见时才能查看和攻击；已探索建筑保留最后已知位置但不显示实时HP。单位可先移动后攻击，新造单位当回合不能行动；结束回合时仍有合法目标的单位自动攻击。"
	]
	return "\n".join(lines)

func _render_era_units_content() -> void:
	encyclopedia_content.append_text("[font_size=26][color=#f0e6c0]E1-E5 核心兵种[/color][/font_size]\n")
	encyclopedia_content.append_text("[color=#9a9aa8]四条路线各时代连续进化；基础形态与两套装备变体均已收录。[/color]\n\n")
	var current_era = 0
	for row in ERA_UNIT_ROWS:
		var era = int(row[0])
		var unit_type = str(row[1])
		if era != current_era:
			current_era = era
			encyclopedia_content.append_text("\n[color=#caba6a][font_size=22]%s[/font_size][/color]\n" % _era_label(era))
		var data = db.unit_data(unit_type)
		_add_encyclopedia_image(db.texture_path_for_unit(unit_type), unit_type)
		var hp = float(data.get("hp", row[2]))
		var armor = float(data.get("armor", row[3]))
		var damage = float(data.get("damage", row[4]))
		var speed = int(data.get("speed", row[5]))
		var attack_range = float(data.get("range", row[6]))
		var vision = int(data.get("vision", row[7]))
		var price = float(data.get("price", row[8]))
		var role = str(data.get("role", row[9]))
		encyclopedia_content.append_text("[color=#f2c14e][font_size=20]%s[/font_size][/color]  %s / 指挥%d\n" % [unit_type, role, _unit_command_cost(unit_type, data)])
		encyclopedia_content.append_text("HP %.2f  甲 %.2f  攻 %.2f  移 %d  射 %.1f  视 %d  新造 %.1f金\n" % [hp, armor, damage, speed, attack_range, vision, price])
		encyclopedia_content.append_text("[color=#a8b8a8]%s[/color]\n" % str(data.get("trait", row[10])))
		var equips = db.equipment_for(unit_type)
		if not equips.is_empty():
			for equip in equips:
				var equip_name := str(equip.get("name", ""))
				_add_encyclopedia_image(db.texture_path_for_equipment(equip), "%s：%s" % [unit_type, equip_name])
				_append_equipment_encyclopedia_stats(unit_type, equip)
	encyclopedia_content.append_text("\n[b]进化路线[/b]\n战线：战团 → 方阵 → 火枪连 → 士兵 → 网络化步兵\n机动：斥候 → 骑兵 → 龙骑兵 → 主战坦克 → 无人战车\n火力：投石队 → 弓弩/投石车 → 野战炮 → 自行火炮 → 精确火箭\n支援：部落侦察 → 轻骑侦察 → 工兵/观测队 → 吉普 → 无人机/电子战\n")

func _era_tech_bbcode() -> String:
	var lines = ["[font_size=26][color=#f0e6c0]科技与装备[/color][/font_size]", "大本营升级完成后开放对应时代的科技、装备研究和单位生产；全局时代开放只允许排队升级大本营，不会直接提升玩家时代。科技、装备与战略项目允许并行研究；同一项目不能重复研究。", "科技采用硬前置树：战线、机动、火力、支援沿上一时代对应路线连续进化；先完成单位解锁科技，才会开放该单位的两条装备分支。旧时代未完成的核心前置仍可补研。建设后勤路线为：有组织采集 → 道路驿站 → 工业化后勤 → 无线电火控 → 智能后勤。装备研究只解锁安装资格，每个单位仍需支付安装费，且只有1个互斥主装备槽。", ""]
	var current_era = 0
	for row in ERA_TECH_ROWS:
		var era = int(row[0])
		if era != current_era:
			current_era = era
			lines.append("[color=#caba6a][font_size=20]%s[/font_size][/color]" % _era_label(era))
		lines.append("[b]%s[/b]  %d金 / %d回合  %s" % [str(row[1]), int(row[2]), int(row[3]), str(row[4])])
	lines.append("")
	lines.append("[b]装备路线速查[/b]")
	lines.append("E1：石斧/兽皮盾；骨矛/轻装行囊；编织投索/重石袋；信号号角/伪装")
	lines.append("E2：长枪阵/塔盾阵；轻骑鞍具/具装甲胄；长弓/配重机构；信号旗/袭扰装备")
	lines.append("E3：线膛枪/刺刀工事包；连发卡宾枪/胸甲；霰弹/实心弹；光学观测镜/爆破工具")
	lines.append("E4：射手步枪/反器械枪；高爆炮/穿甲炮；轻量化/巨炮；重甲吉普/火箭助推")
	lines.append("E5：智能反坦克弹/自适应迷彩；主动防御系统/电磁炮；钻地弹/巡飞子弹药；聚能战斗部/干扰吊舱")
	return "\n".join(lines)

func _era_status_bbcode() -> String:
	return "\n".join([
		"[font_size=26][color=#f0e6c0]状态、容量与信息[/color][/font_size]", "",
		"[table=3][cell][b]状态[/b][/cell][cell][b]规则[/b][/cell][cell][b]UI信息[/b][/cell]",
		"[cell]标记[/cell][cell]目标进入共享攻击信息，相关火力获得射程加成[/cell][cell]名称、剩余回合、来源[/cell]",
		"[cell]冲锋[/cell][cell]连续移动达到要求后，仅强化第一次攻击[/cell][cell]触发距离与加成[/cell]",
		"[cell]侧击[/cell][cell]目标孤立或攻击者位于后侧时触发[/cell][cell]攻击修正[/cell]",
		"[cell]装填[/cell][cell]数字大于0不能攻击，己方回合开始-1[/cell][cell]剩余回合[/cell]",
		"[cell]隐蔽[/cell][cell]超过侦察距离不显示，近距或侦察可揭露[/cell][cell]揭露条件[/cell]",
		"[cell]干扰[/cell][cell]降低视野，关闭标记与共享视野[/cell][cell]范围与来源[/cell]",
		"[cell]驻扎[/cell][cell]消耗本回合，在建筑范围内恢复生命[/cell][cell]恢复量[/cell]",
		"[cell]升级中[/cell][cell]建筑可继续生产，新功能等待完成[/cell][cell]剩余回合[/cell]",
		"[cell]后勤[/cell][cell]只提高已完工资源采集器的每回合金币；最高已研究倍率生效，倍率不叠加[/cell][cell]当前倍率、采集器预计收入[/cell]",
		"[cell]占领中断[/cell][cell]据点易手后升级清零并进入收入恢复期[/cell][cell]恢复阶段[/cell][/table]", "",
		"所有状态必须同时显示文字、剩余回合和悬停说明，不能只依靠颜色。悬停卡中的“生效加成”会列出相邻阵型、装备、标记或干扰来源。", "",
		"[color=#f2c14e][font_size=20]后勤是什么意思[/font_size][/color]",
		"后勤代表采集、运输和分配资源的效率。在当前版本中，它只影响资源采集器收入，不影响单位移动、攻击、视野、驻扎回血、生产时间或编制容量。", "",
		"[code]第 n 座采集器收入 = 4.5 × 0.8^(n-1) × 当前后勤倍率[/code]",
		"同一玩家的采集器按编号计算边际递减：第一座基础4.50金，第二座3.60金，第三座2.88金。后勤科技取已完成研究中的最高倍率，不会把1.10、1.20等倍率相乘。", "",
		"[table=4][cell][b]阶段[/b][/cell][cell][b]后勤科技[/b][/cell][cell][b]倍率[/b][/cell][cell][b]第一/第二座收入[/b][/cell]",
		"[cell]E1[/cell][cell]基础后勤[/cell][cell]×1.00[/cell][cell]4.50 / 3.60[/cell]",
		"[cell]E2[/cell][cell]道路驿站[/cell][cell]×1.10[/cell][cell]4.95 / 3.96[/cell]",
		"[cell]E3[/cell][cell]工业化后勤[/cell][cell]×1.20[/cell][cell]5.40 / 4.32[/cell]",
		"[cell]E4[/cell][cell]无线电火控[/cell][cell]×1.30[/cell][cell]5.85 / 4.68[/cell]",
		"[cell]E5[/cell][cell]智能后勤[/cell][cell]×1.40[/cell][cell]6.30 / 5.04[/cell][/table]", "",
		"[b]指挥容量[/b]  E1-E5基础上限：22 / 24 / 26 / 28 / 30。战线和支援占1；机动和火力占2；基础据点+1，战斗据点+2。", "[b]战役优势[/b]  0-3点显示在顶部栏；3点触发总攻窗口。"
	])

func _encyclopedia_rules_bbcode() -> String:
	var lines = [
		"[font_size=26][color=#f0e6c0]游戏规则[/color][/font_size]",
		"[color=#6a6a7a]第零章 · 基础机制[/color]",
		"",
		"[color=#e8dcc8][b]胜利条件[/b][/color]",
		"占领或摧毁敌方所有大本营，或者消灭敌方所有可行动单位。",
		"",
		"[color=#e8dcc8][b]伤害计算[/b][/color]",
		"[code]真实伤害 = max(0, 攻击方伤害 - 防守方护甲)[/code]",
		"护甲直接减免每次攻击的伤害值，最低为 0。距离使用欧几里得距离。",
		"多次攻击单位每次点击消耗 1 次攻击；爆炸伤害会影响目标周围敌方单位；自杀无人机攻击后自毁。",
		"",
		"[color=#e8dcc8][b]高度地形[/b][/color]",
		"地形分为平地、丘陵、高地、山脉四级。上坡更耗行动力，下坡更省。高处攻击低处增加有效射程，低处攻击高处降低有效射程；高度差 1 修正 1，差 2 或以上封顶为 2。",
		"",
		"[table=4][cell][b]地形[/b][/cell][cell][b]高度[/b][/cell][cell][b]移动[/b][/cell][cell][b]战术效果[/b][/cell]"
	]
	for terrain_id in db.terrain.keys():
		var t = db.terrain_data(str(terrain_id))
		lines.append("[cell]%s[/cell][cell]%d[/cell][cell]%.1f[/cell][cell]%s[/cell]" % [str(t.get("name", terrain_id)), int(t.get("height", 0)), float(t.get("move_cost", 1.0)), _terrain_effect_text(int(t.get("height", 0)))])
	lines.append("[/table]")
	lines.append("")
	lines.append("[color=#e8dcc8][b]战争迷雾[/b][/color]")
	lines.append("视野外地图会被暗雾覆盖。敌方单位只有进入视野后才会显示、被鼠标提示或被攻击锁定。已探索的敌方建筑保留已知位置但会压暗。地面单位站在高地形上视野增加地形高度；空军不吃地形视野加成。")
	lines.append("")
	lines.append("[color=#e8dcc8][b]视野来源[/b][/color]")
	lines.append("[table=3][cell][b]来源[/b][/cell][cell][b]视野[/b][/cell][cell][b]说明[/b][/cell]")
	for unit_type in db.units.keys():
		var unit = db.unit_data(str(unit_type))
		lines.append("[cell]%s[/cell][cell]%d[/cell][cell]射程 %.1f + 移速 %d[/cell]" % [str(unit_type), int(unit.get("vision", 0)), float(unit.get("range", 0.0)), int(unit.get("speed", 0))])
	lines.append("[cell]大本营[/cell][cell]7 / 8 / 9[/cell][cell]随等级提升[/cell]")
	lines.append("[cell]据点 / 资源采集器[/cell][cell]5 / 3[/cell][cell]据点收入按时代与分支计算；采集器造价12金，按 4.5 × 0.8^编号产金[/cell]")
	lines.append("[cell]SpaceX 星链计划[/cell][cell]全图[/cell][cell]T3 战略科技[/cell][/table]")
	lines.append("")
	lines.append("[color=#e8dcc8][b]耐打计算[/b][/color]")
	lines.append("[code]所需伤害 = 生命 / 攻击次数 + 护甲[/code]")
	lines.append("[table=6][cell][b]兵种[/b][/cell][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]1 下[/b][/cell][cell][b]2 下[/b][/cell][cell][b]3 下[/b][/cell]")
	for unit_type in db.units.keys():
		var unit = db.unit_data(str(unit_type))
		var hp = float(unit.get("hp", 0.0))
		var armor = float(unit.get("armor", 0.0))
		lines.append("[cell]%s[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell]" % [str(unit_type), hp, armor, hp + armor, hp / 2.0 + armor, hp / 3.0 + armor])
	lines.append("[/table]")
	lines.append("")
	lines.append("[color=#e8dcc8][b]经典兵种测试矩阵[/b][/color]")
	lines.append("行是攻击方，列是防守方；√ 表示一轮换血明显赚，○ 表示接近均势，× 表示打不到或明显亏。")
	lines.append(_matchup_matrix_bbcode())
	return "\n".join(lines)

func _encyclopedia_units_bbcode() -> String:
	var lines = ["[font_size=26][color=#f0e6c0]兵种大全[/color][/font_size]", "[color=#6a6a7a]第一章 · 已收录 %d 个兵种，包含基础属性、装备研究与定位说明[/color]" % db.units.size(), ""]
	for unit_type in db.units.keys():
		var unit = db.unit_data(str(unit_type))
		lines.append("[color=#f0e6c0][font_size=20]%s[/font_size][/color]" % str(unit_type))
		lines.append(_unit_quote(str(unit_type)))
		lines.append("[table=8][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]移速[/b][/cell][cell][b]价格[/b][/cell][cell][b]伤害[/b][/cell][cell][b]射程[/b][/cell][cell][b]攻击[/b][/cell][cell][b]视野[/b][/cell]")
		lines.append("[cell]%.1f[/cell][cell]%.1f[/cell][cell]%d[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%d[/cell][cell]%d[/cell][/table]" % [float(unit.get("hp", 0.0)), float(unit.get("armor", 0.0)), int(unit.get("speed", 0)), float(unit.get("price", 0.0)), float(unit.get("damage", 0.0)), float(unit.get("range", 0.0)), int(unit.get("attacks", 0)), int(unit.get("vision", 0))])
		var traits = _unit_traits(unit)
		if not traits.is_empty():
			lines.append("[color=#caba6a]特性：[/color]" + "、".join(traits))
		var equips = db.equipment_for(str(unit_type))
		if not equips.is_empty():
			lines.append("[color=#a0a0b0][b]装备[/b][/color]")
			for equip in equips:
				lines.append("  [color=#e0d4c0]%s[/color]  研究 %.1f 金 / 需求 T%d" % [str(equip.get("name", "")), float(equip.get("research_cost", 0.0)), int(equip.get("tier", 1))])
				for line in _equipment_delta_lines(str(unit_type), equip):
					lines.append("    " + line)
		lines.append("")
	lines.append("[color=#e8dcc8][b]兵种数据速查[/b][/color]")
	lines.append("[table=9][cell][b]兵种[/b][/cell][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]移速[/b][/cell][cell][b]价格[/b][/cell][cell][b]伤害[/b][/cell][cell][b]射程[/b][/cell][cell][b]解锁[/b][/cell][cell][b]装备[/b][/cell]")
	for unit_type in db.units.keys():
		var unit = db.unit_data(str(unit_type))
		lines.append("[cell]%s[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%d[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%s[/cell][cell]%s[/cell]" % [str(unit_type), float(unit.get("hp", 0.0)), float(unit.get("armor", 0.0)), int(unit.get("speed", 0)), float(unit.get("price", 0.0)), float(unit.get("damage", 0.0)), float(unit.get("range", 0.0)), _unlock_tier_for_unit(str(unit_type)), _equipment_names(str(unit_type))])
	lines.append("[/table]")
	return "\n".join(lines)

func _encyclopedia_buildings_bbcode() -> String:
	var lines = ["[font_size=26][color=#f0e6c0]建筑大全[/color][/font_size]", "[color=#6a6a7a]第二章 · 大本营、据点与资源建筑[/color]", ""]
	var hq = db.building_data("大本营")
	lines.append("[color=#f0e6c0][font_size=20]大本营[/font_size][/color]")
	lines.append("核心建筑，提供收入、视野和单位生产。大本营升级完成后推进 T2/T3 解锁；被摧毁会直接影响胜负。")
	lines.append("[table=6][cell][b]等级[/b][/cell][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]收入[/b][/cell][cell][b]视野[/b][/cell][cell][b]升级费用[/b][/cell]")
	var idx = 1
	for tier in hq.get("tiers", []):
		lines.append("[cell]T%d[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%d[/cell][cell]%s[/cell]" % [idx, float(tier.get("hp", 0.0)), float(tier.get("armor", 0.0)), float(tier.get("gold", 0.0)), int(tier.get("vision", 0)), str(tier.get("upgrade_cost", "满级"))])
		idx += 1
	lines.append("[/table]")
	for building_type in db.buildings.keys():
		if str(building_type) == "大本营":
			continue
		var building = db.building_data(str(building_type))
		lines.append("")
		lines.append("[color=#f0e6c0][font_size=20]%s[/font_size][/color]" % str(building_type))
		lines.append("[table=5][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]收入[/b][/cell][cell][b]视野[/b][/cell][cell][b]说明[/b][/cell]")
		lines.append("[cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%d[/cell][cell]%s[/cell][/table]" % [float(building.get("hp", 0.0)), float(building.get("armor", 0.0)), float(building.get("gold", 0.0)), int(building.get("vision", 0)), _building_note(str(building_type))])
	lines.append(_outpost_rules_bbcode())
	return "\n".join(lines)

func _encyclopedia_tech_bbcode() -> String:
	var lines = ["[font_size=26][color=#f0e6c0]科技树[/color][/font_size]", "[color=#6a6a7a]第三章 · T1 到 T3 战争科技[/color]", "", "科技是第一战斗力，每一级突破都会改变可生产兵种、装备研究和战略能力。", ""]
	for tech_id in ["T1", "T2", "T3"]:
		var tech = db.techs.get(tech_id, {})
		if tech.is_empty():
			continue
		lines.append("[color=%s][font_size=20]%s — %s[/font_size][/color]" % [_tier_color(tech_id), tech_id, str(tech.get("name", ""))])
		if tech_id == "T1":
			lines.append("开局默认拥有。")
		else:
			lines.append("通过大本营升级到 %s 解锁，不再单独研究。升级费用见建筑章节。" % tech_id)
		lines.append("解锁兵种：" + "、".join(tech.get("unlocks", [])))
		lines.append("可用装备：" + _equipment_names_by_tier(int(tech_id.substr(1, 1))))
		lines.append("")
	lines.append("[color=#f0e6c0][font_size=20]战略科技[/font_size][/color]")
	for tech_name in db.strategic_techs.keys():
		var tech = db.strategic_techs[tech_name]
		lines.append("[table=4][cell][b]名称[/b][/cell][cell][b]需求[/b][/cell][cell][b]费用[/b][/cell][cell][b]效果[/b][/cell]")
		lines.append("[cell]%s[/cell][cell]T%d[/cell][cell]%.1f[/cell][cell]%s[/cell][/table]" % [str(tech_name), int(tech.get("tier", 1)), float(tech.get("cost", 0.0)), str(tech.get("desc", ""))])
	lines.append("")
	lines.append("[color=#e8dcc8][b]科技总览[/b][/color]")
	lines.append("[table=4][cell][b]T 级[/b][/cell][cell][b]兵种[/b][/cell][cell][b]装备[/b][/cell][cell][b]建筑[/b][/cell]")
	lines.append("[cell]T1[/cell][cell]士兵、军用吉普、装甲车[/cell][cell]射手步枪、重甲吉普[/cell][cell]T1 大本营[/cell]")
	lines.append("[cell]T2[/cell][cell]坦克、野战炮、自杀无人机、侦察机[/cell][cell]反器械枪、火箭助推、轻量化、高爆炮[/cell][cell]T2 大本营[/cell]")
	lines.append("[cell]T3[/cell][cell]火箭炮、战斗机、轰炸机、防空车[/cell][cell]穿甲炮、对空雷达、巨炮[/cell][cell]T3 大本营、SpaceX 星链计划[/cell][/table]")
	return "\n".join(lines)

func _terrain_effect_text(height_value: int) -> String:
	if height_value == 0:
		return "基准射程"
	if height_value == 1:
		return "高打低射程 +1，低打高最多 -1"
	if height_value == 2:
		return "高打低射程 +2，低打高最多 -2"
	return "最高地形，射程修正封顶 ±2，通行昂贵"

func _unit_traits(unit: Dictionary) -> Array:
	var traits = []
	if bool(unit.get("is_air", false)):
		traits.append("空中单位")
	if bool(unit.get("can_target_air", false)):
		traits.append("可对空")
	if bool(unit.get("self_destruct", false)):
		traits.append("自爆")
	if float(unit.get("blast", 0.0)) > 0.0:
		traits.append("爆炸半径 %.1f" % float(unit.get("blast", 0.0)))
	if unit.has("air_damage"):
		traits.append("对空 %.1f / 射程 %.1f" % [float(unit.get("air_damage", 0.0)), float(unit.get("air_range", 0.0))])
	return traits

func _unit_quote(unit_type: String) -> String:
	var quotes = {"士兵": "最低造价的基础步兵，可通过装备获得长射程和对空能力。", "坦克": "重装甲突击力量，适合突破和承伤。", "军用吉普": "高速侦察和机动单位，可改装为极速或重甲路线。", "火箭炮": "T3 超远程火力，依赖视野单位提供目标。", "野战炮": "曲射支援平台，可选择轻量化或巨炮路线。", "装甲车": "多次攻击、可对空，是步兵和轻单位的压制工具。", "战斗机": "高速空中格斗单位，对空对地皆可。", "轰炸机": "高伤害范围轰炸，仅对地，适合打密集阵地和建筑。", "防空车": "双模式单位，对空伤害和射程远高于对地。", "自杀无人机": "低价高速自爆单位，星链后伤害提升。", "侦察机": "T2 空中侦察单位，无法攻击，专门提供视野。"}
	return str(quotes.get(unit_type, ""))

func _equipment_delta_lines(unit_type: String, equip: Dictionary) -> Array:
	var unit = db.unit_data(unit_type)
	var lines = []
	_collect_delta_line(lines, "生命", unit.get("hp", 0.0), equip.get("hp", null))
	_collect_delta_line(lines, "护甲", unit.get("armor", 0.0), equip.get("armor", null))
	_collect_delta_line(lines, "伤害", unit.get("damage", 0.0), equip.get("dmg", null))
	_collect_delta_line(lines, "射程", unit.get("range", 0.0), equip.get("range", null))
	_collect_delta_line(lines, "移速", unit.get("speed", 0.0), equip.get("speed", null))
	_collect_delta_line(lines, "视野", unit.get("vision", 0.0), equip.get("vision", null))
	_collect_delta_line(lines, "攻击次数", unit.get("attacks", 1), equip.get("attacks", null))
	if equip.has("blast"):
		lines.append("爆炸范围：%.1f → %.1f" % [float(unit.get("blast", 0.0)), float(equip.get("blast", 0.0))])
	if equip.has("reload"):
		lines.append("攻击后装填：%d 回合" % int(equip.get("reload", 0)))
	if bool(equip.get("can_target_air", false)):
		lines.append("新增：可以攻击空军")
	if bool(equip.get("self_destruct", false)):
		lines.append("新增：攻击后自毁")
	var effects = equip.get("effects", {})
	if effects is Dictionary:
		for key in effects.keys():
			lines.append(_equipment_effect_text(str(key), effects[key]))
	return lines

func _append_equipment_encyclopedia_stats(unit_type: String, equip: Dictionary) -> void:
	encyclopedia_content.append_text("[color=#d8cda8]研究 %.1f 金 / %d 回合　安装 %.1f 金[/color]\n" % [float(equip.get("research_cost", 0.0)), int(equip.get("research_time", 1)), float(equip.get("cost", 0.0))])
	var delta_lines = _equipment_delta_lines(unit_type, equip)
	if delta_lines.is_empty():
		encyclopedia_content.append_text("　无直接属性变化\n")
		return
	for line in delta_lines:
		encyclopedia_content.append_text("　%s\n" % str(line))

func _equipment_effect_text(key: String, value) -> String:
	var number = float(value) if value is int or value is float else 0.0
	match key:
		"charge_damage": return "冲锋首次攻击额外伤害：+%.1f" % number
		"vs_armored_damage": return "对装甲目标额外伤害：+%.1f" % number
		"vs_building_damage": return "对建筑额外伤害：+%.1f" % number
		"vs_line_damage": return "对战线单位额外伤害：+%.1f" % number
		"vs_mobile_damage": return "对机动单位额外伤害：+%.1f" % number
		"range_one_vs_building_damage": return "距离1攻击建筑额外伤害：+%.1f" % number
		"range_one_vs_mobile_damage": return "距离1攻击机动单位额外伤害：+%.1f" % number
		"damage_per_attack": return "每次攻击伤害修正：%+.1f" % number
		"attacks_set": return "攻击次数设为：%d" % int(value)
		"mark_duration": return "标记持续时间：%d 回合" % int(value)
		"marked_target_artillery_range": return "攻击已标记目标时炮兵射程：+%.1f" % number
		"marked_target_firepower_range": return "攻击已标记目标时火力射程：+%.1f" % number
		"stationary_armor": return "静止时护甲：+%.1f" % number
		"stationary_vision": return "静止时视野：+%.1f" % number
		"first_effective_damage_reduction_per_turn": return "每回合首次有效伤害减免：%.1f" % number
		"conceal_beyond": return "与敌军距离超过 %d 格时隐蔽" % int(value)
		"reveal_distance": return "被近距离揭露的距离：%d 格" % int(value)
		"radius": return "作用半径：%d 格" % int(value)
		"enemy_vision": return "范围内敌军视野：%+.1f" % number
		"concealed_when_stationary": return "静止时进入隐蔽" if bool(value) else "静止隐蔽关闭"
		"disable_shared_vision": return "范围内阻断敌方共享视野" if bool(value) else "不阻断共享视野"
		"disable_mark": return "范围内阻断敌方标记" if bool(value) else "不阻断标记"
		"ignore_building_armor": return "攻击建筑时无视护甲" if bool(value) else "攻击建筑不无视护甲"
		_: return "%s：%s" % [key, str(value)]

func _collect_delta_line(lines: Array, label: String, base_value, delta_value) -> void:
	if delta_value == null:
		return
	var base = float(base_value)
	var delta = float(delta_value)
	lines.append("%s：%.1f → %.1f" % [label, base, base + delta])

func _unlock_tier_for_unit(unit_type: String) -> String:
	for tech_id in ["T1", "T2", "T3"]:
		var tech = db.techs.get(tech_id, {})
		if tech.get("unlocks", []).has(unit_type):
			return tech_id
	return "T?"

func _equipment_names(unit_type: String) -> String:
	var names = []
	for equip in db.equipment_for(unit_type):
		names.append(str(equip.get("name", "")))
	return "、".join(names) if not names.is_empty() else "无"

func _equipment_names_by_tier(tier: int) -> String:
	var names = []
	for unit_type in db.equipment.keys():
		for equip in db.equipment_for(str(unit_type)):
			if int(equip.get("tier", 1)) == tier:
				names.append("%s：%s" % [str(unit_type), str(equip.get("name", ""))])
	return "、".join(names) if not names.is_empty() else "无"

func _building_note(building_type: String) -> String:
	if building_type == "据点":
		return "中立地图目标，占领后提供收入和视野。"
	if building_type == "资源采集器":
		return "资源型建筑，占领后提供稳定金币。"
	return ""

func _tier_color(tech_id: String) -> String:
	if tech_id == "T1":
		return "#6aaa6a"
	if tech_id == "T2":
		return "#6a8ada"
	return "#da8a6a"

func _render_encyclopedia_units_content() -> void:
	encyclopedia_content.append_text("[font_size=26][color=#f0e6c0]兵种大全[/color][/font_size]\n")
	encyclopedia_content.append_text("[color=#6a6a7a]第一章 · 已收录 %d 个兵种，包含基础属性、装备研究与定位说明[/color]\n\n" % db.units.size())
	for unit_type in db.units.keys():
		var unit = db.unit_data(str(unit_type))
		_add_encyclopedia_image(db.texture_path_for_unit(str(unit_type)), str(unit_type))
		encyclopedia_content.append_text("[color=#f2c14e][font_size=20]%s[/font_size][/color]\n" % str(unit_type))
		encyclopedia_content.append_text(_unit_quote(str(unit_type)) + "\n")
		encyclopedia_content.append_text("[table=8][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]移速[/b][/cell][cell][b]价格[/b][/cell][cell][b]伤害[/b][/cell][cell][b]射程[/b][/cell][cell][b]攻击[/b][/cell][cell][b]视野[/b][/cell]")
		encyclopedia_content.append_text("[cell]%.1f[/cell][cell]%.1f[/cell][cell]%d[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%d[/cell][cell]%d[/cell][/table]\n" % [float(unit.get("hp", 0.0)), float(unit.get("armor", 0.0)), int(unit.get("speed", 0)), float(unit.get("price", 0.0)), float(unit.get("damage", 0.0)), float(unit.get("range", 0.0)), int(unit.get("attacks", 0)), int(unit.get("vision", 0))])
		var traits = _unit_traits(unit)
		if not traits.is_empty():
			encyclopedia_content.append_text("[color=#caba6a]特性：[/color]" + "、".join(traits) + "\n")
		var equips = db.equipment_for(str(unit_type))
		if not equips.is_empty():
			encyclopedia_content.append_text("[color=#a0a0b0][b]装备研究[/b][/color]\n")
			for equip in equips:
				_add_encyclopedia_image(db.texture_path_for_equipment(equip), "%s：%s" % [str(unit_type), str(equip.get("name", ""))])
				_append_equipment_encyclopedia_stats(str(unit_type), equip)
		encyclopedia_content.append_text("\n")
	encyclopedia_content.append_text("[color=#e8dcc8][b]兵种数据速查[/b][/color]\n")
	encyclopedia_content.append_text(_unit_quick_table_bbcode())

func _render_encyclopedia_buildings_content() -> void:
	encyclopedia_content.append_text("[font_size=26][color=#f0e6c0]建筑大全[/color][/font_size]\n")
	encyclopedia_content.append_text("[color=#9a9aa8]第二章 · 30张时代建筑、据点分支与战略设施贴图[/color]\n")
	_add_building_images_to_encyclopedia()
	encyclopedia_content.append_text("\n")
	encyclopedia_content.append_text("[color=#f0e6c0][font_size=20]大本营[/font_size][/color]\n")
	encyclopedia_content.append_text("核心建筑，提供收入、视野、指挥容量和单位生产。升级完成后推进E1-E5，被摧毁会直接影响胜负。\n")
	encyclopedia_content.append_text("[table=6][cell][b]等级[/b][/cell][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]收入[/b][/cell][cell][b]视野[/b][/cell][cell][b]升级费用[/b][/cell]")
	var hq_tiers: Array = db.building_data("大本营").get("tiers", [])
	for index in range(hq_tiers.size()):
		var tier: Dictionary = hq_tiers[index]
		var upgrade_text := "满级" if index == hq_tiers.size() - 1 else "%.1f金 / %d回合" % [float(tier.get("upgrade_cost", 0.0)), int(tier.get("upgrade_time", 1))]
		encyclopedia_content.append_text("[cell]E%d[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%d[/cell][cell]%s[/cell]" % [index + 1, float(tier.get("hp", 0.0)), float(tier.get("armor", 0.0)), float(tier.get("gold", 0.0)), int(tier.get("vision", 0)), upgrade_text])
	encyclopedia_content.append_text("[/table]\n")
	for building_type in db.buildings.keys():
		if str(building_type) == "大本营":
			continue
		var building = db.building_data(str(building_type))
		encyclopedia_content.append_text("\n")
		encyclopedia_content.append_text("[color=#f0e6c0][font_size=20]%s[/font_size][/color]\n" % str(building_type))
		encyclopedia_content.append_text("[table=5][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]收入[/b][/cell][cell][b]视野[/b][/cell][cell][b]说明[/b][/cell]")
		encyclopedia_content.append_text("[cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%d[/cell][cell]%s[/cell][/table]\n" % [float(building.get("hp", 0.0)), float(building.get("armor", 0.0)), float(building.get("gold", 0.0)), int(building.get("vision", 0)), _building_note(str(building_type))])
	encyclopedia_content.append_text(_outpost_rules_bbcode())

func _outpost_rules_bbcode() -> String:
	var lines: Array[String] = [
		"\n[color=#f2c14e][font_size=22]据点完整功能[/font_size][/color]",
		"据点是可争夺的前线建筑，提供视野、回合收入、编制容量、驻扎和有限生产；它不能完全代替大本营。中立据点被打到0生命后归攻击者，并以当前玩家时代的基础据点形态和50%生命重新投入使用。", "",
		"[color=#e8dcc8][b]为什么刚占领不能造兵[/b][/color]",
		"占领当回合及紧接的一回合处于接管期，不能生产。收入恢复为：接管期0%，下一阶段50%，之后100%；接管期间也不会回血。这样可防止一夺取前线据点就立刻刷兵滚雪球。", "",
		"[color=#e8dcc8][b]三种据点的生产范围[/b][/color]",
		"[table=5][cell][b]类型[/b][/cell][cell][b]可生产[/b][/cell][cell][b]不可生产[/b][/cell][cell][b]编制[/b][/cell][cell][b]定位[/b][/cell]",
		"[cell]基础据点[/cell][cell]当前时代或上一时代的战线单位；E1只有战团[/cell][cell]机动、火力、支援[/cell][cell]+1[/cell][cell]普通补员与区域控制[/cell]",
		"[cell]战斗据点[/cell][cell]当前时代的战线、机动单位[/cell][cell]火力、支援[/cell][cell]+2[/cell][cell]前线扩军、完整驻扎和单位进化[/cell]",
		"[cell]经济据点[/cell][cell]上一时代的战线单位[/cell][cell]当前时代、机动、火力、支援[/cell][cell]+0[/cell][cell]高收入、低军事能力[/cell][/table]",
		"火力和支援单位始终只能从大本营生产。所有据点生产仍要求：对应兵种科技已完成、金币足够、编制未满，并且据点周围8格至少有一个空位。新造单位当回合不能移动或攻击。", "",
		"[color=#e8dcc8][b]分化、驻扎与易手[/b][/color]",
		"玩家大本营达到E2后，基础据点才能分化为战斗或经济据点。木栅工事科技解锁驻扎：单位需在据点相邻格，基础据点驻扎恢复20%最大生命、战斗据点驻扎恢复35%、经济据点驻扎恢复10%，并消耗本回合行动。只有大本营和战斗据点允许单位沿路线进化。",
		"据点易手后，分支、升级进度和现代化全部清零，退回新占领者当前时代的基础据点；升级中被夺取不会退款。", "",
		"[color=#e8dcc8][b]各时代据点数值[/b][/color]",
		"[table=7][cell][b]时代[/b][/cell][cell][b]形态[/b][/cell][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]收入[/b][/cell][cell][b]升级费[/b][/cell][cell][b]时间[/b][/cell]"
	]
	var eras: Dictionary = db.building_data("据点").get("eras", {})
	var branch_names := {"base": "基础", "combat": "战斗", "economic": "经济"}
	for era in range(1, 6):
		var era_stats: Dictionary = eras.get("E%d" % era, {})
		for branch in ["base", "combat", "economic"]:
			if not era_stats.has(branch):
				continue
			var stats: Dictionary = era_stats[branch]
			lines.append("[cell]E%d[/cell][cell]%s[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%s[/cell][cell]%s[/cell]" % [era, branch_names[branch], float(stats.get("hp", 0.0)), float(stats.get("armor", 0.0)), float(stats.get("gold", 0.0)), "占领获得" if branch == "base" else "%.1f金" % float(stats.get("upgrade_cost", 0.0)), "-" if branch == "base" else "%d回合" % int(stats.get("upgrade_time", 1))])
	lines.append("[/table]")
	lines.append("同一玩家控制的据点收入按数量递减：第1座100%、第2座75%、第3座55%、第4座及以后40%。")
	return "\n".join(lines)

func _unit_quick_table_bbcode() -> String:
	var lines = ["[table=9][cell][b]兵种[/b][/cell][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]移速[/b][/cell][cell][b]价格[/b][/cell][cell][b]伤害[/b][/cell][cell][b]射程[/b][/cell][cell][b]解锁[/b][/cell][cell][b]装备[/b][/cell]"]
	for unit_type in db.units.keys():
		var unit = db.unit_data(str(unit_type))
		lines.append("[cell]%s[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%d[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%s[/cell][cell]%s[/cell]" % [str(unit_type), float(unit.get("hp", 0.0)), float(unit.get("armor", 0.0)), int(unit.get("speed", 0)), float(unit.get("price", 0.0)), float(unit.get("damage", 0.0)), float(unit.get("range", 0.0)), _unlock_tier_for_unit(str(unit_type)), _equipment_names(str(unit_type))])
	lines.append("[/table]")
	return "\n".join(lines)

func _matchup_matrix_bbcode() -> String:
	var order: Array = db.unit_order
	var lines = ["[table=%d]" % (order.size() + 1), "[cell][b]攻\\守[/b][/cell]"]
	for defender_type in order:
		lines.append("[cell][b]%s[/b][/cell]" % _short_unit_name(str(defender_type)))
	for attacker_type in order:
		lines.append("[cell][b]%s[/b][/cell]" % _short_unit_name(str(attacker_type)))
		for defender_type in order:
			if str(attacker_type) == str(defender_type):
				lines.append("[cell]—[/cell]")
			else:
				var symbol = _matchup_symbol(str(attacker_type), str(defender_type))
				var color = "#63d968" if symbol == "√" else ("#d8b340" if symbol == "○" else "#e35a5a")
				lines.append("[cell][color=%s]%s[/color][/cell]" % [color, symbol])
	lines.append("[/table]")
	return "\n".join(lines)

func _matchup_symbol(attacker_type: String, defender_type: String) -> String:
	var attacker = db.unit_data(attacker_type)
	var defender = db.unit_data(defender_type)
	if attacker.is_empty() or defender.is_empty():
		return "×"
	if float(attacker.get("range", 0.0)) <= 0.0 or int(attacker.get("attacks", 0)) <= 0:
		return "×"
	var defender_is_air = bool(defender.get("is_air", false))
	if defender_is_air and not bool(attacker.get("can_target_air", false)):
		return "×"
	var attack_damage = float(attacker.get("air_damage", attacker.get("damage", 0.0))) if defender_is_air and float(attacker.get("air_damage", 0.0)) > 0.0 else float(attacker.get("damage", 0.0))
	var attack_total = max(0.0, attack_damage - float(defender.get("armor", 0.0))) * float(attacker.get("attacks", 1))
	if attack_total <= 0.0:
		return "×"
	var attack_value = attack_total / max(0.1, float(defender.get("hp", 1.0))) * max(0.5, float(defender.get("price", 1.0)))
	var retaliation_value = 0.0
	var attacker_is_air = bool(attacker.get("is_air", false))
	if float(defender.get("range", 0.0)) > 0.0 and int(defender.get("attacks", 0)) > 0 and (not attacker_is_air or bool(defender.get("can_target_air", false))):
		var return_damage = float(defender.get("air_damage", defender.get("damage", 0.0))) if attacker_is_air and float(defender.get("air_damage", 0.0)) > 0.0 else float(defender.get("damage", 0.0))
		var return_total = max(0.0, return_damage - float(attacker.get("armor", 0.0))) * float(defender.get("attacks", 1))
		retaliation_value = return_total / max(0.1, float(attacker.get("hp", 1.0))) * max(0.5, float(attacker.get("price", 1.0)))
	var score = attack_value - retaliation_value
	if score >= 1.4:
		return "√"
	if score >= -0.5:
		return "○"
	return "×"

func _short_unit_name(unit_type: String) -> String:
	var names = {
		"军用吉普": "吉普",
		"自杀无人机": "无人机"
	}
	return str(names.get(unit_type, unit_type))

func _add_unit_images_to_encyclopedia() -> void:
	encyclopedia_content.append_text("\n\n[b]图片图鉴[/b]\n")
	for unit_type in db.units.keys():
		_add_encyclopedia_image(db.texture_path_for_unit(str(unit_type)), str(unit_type))
		for equip in db.equipment_for(str(unit_type)):
			_add_encyclopedia_image(db.texture_path_for_equipment(equip), "%s：%s" % [str(unit_type), str(equip.get("name", ""))])

func _add_building_images_to_encyclopedia() -> void:
	encyclopedia_content.append_text("\n[b]建筑图片[/b]\n")
	var catalog: Dictionary = db.building_texture_catalog()
	for key in catalog.keys():
		_add_encyclopedia_image(str(catalog[key]), _building_art_label(str(key)))

func _building_art_label(key: String) -> String:
	var parts := key.split(":")
	if key.begins_with("hq:"):
		return "%s 大本营" % parts[1]
	if key.begins_with("outpost:"):
		var branch_names := {"base": "基础据点", "combat": "战斗据点", "economic": "经济据点"}
		return "%s %s" % [parts[1], branch_names.get(parts[2], parts[2])]
	if key.begins_with("collector:"):
		return "%s 资源采集器" % parts[1]
	if key.begins_with("fortification:"):
		return "%s 防御工事" % parts[1]
	if key == "command_point:neutral":
		return "中央指挥点：中立"
	if key == "command_point:active":
		return "中央指挥点：激活"
	return key

func _add_terrain_images_to_encyclopedia() -> void:
	encyclopedia_content.append_text("\n\n[b]地形贴图[/b]\n")
	for terrain_id in db.terrain.keys():
		var terrain = db.terrain_data(str(terrain_id))
		_add_encyclopedia_image(str(terrain.get("texture", "")), str(terrain.get("name", terrain_id)))

func _add_encyclopedia_image(path: String, label: String) -> void:
	if path.is_empty():
		encyclopedia_content.append_text("[color=#777783][贴图待补：%s][/color]\n" % label)
		return
	var texture = load(path)
	if texture == null:
		encyclopedia_content.append_text("[color=#777783][贴图待补：%s][/color]\n" % label)
		return
	encyclopedia_content.append_text("\n[color=#f2c14e][font_size=18]%s[/font_size][/color]\n" % label)
	encyclopedia_content.add_image(texture, 96, 96)
	encyclopedia_content.append_text("\n")

func _apply_resolution(size: Vector2i) -> void:
	selected_resolution = size
	fullscreen_enabled = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	var screen = DisplayServer.screen_get_size()
	DisplayServer.window_set_position(Vector2i(max(0, (screen.x - size.x) / 2), max(0, (screen.y - size.y) / 2)))
	_layout_game_ui()

func _set_fullscreen(enabled: bool) -> void:
	fullscreen_enabled = enabled
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(selected_resolution)
		var screen = DisplayServer.screen_get_size()
		DisplayServer.window_set_position(Vector2i(max(0, (screen.x - selected_resolution.x) / 2), max(0, (screen.y - selected_resolution.y) / 2)))
	_layout_game_ui()

func _percent_to_db(percent: int) -> float:
	if percent <= 0:
		return -80.0
	return linear_to_db(clampf(float(percent) / 100.0, 0.001, 1.0))

func _play_sfx(key: String) -> void:
	var path = str(db.audio.get(key, ""))
	if path.is_empty() or sfx_player == null:
		return
	var stream = load(path)
	if stream == null:
		return
	sfx_player.stream = stream
	sfx_player.volume_db = _percent_to_db(sfx_volume_percent)
	sfx_player.play()
