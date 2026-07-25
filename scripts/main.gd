extends Node

const GameDatabaseScript = preload("res://scripts/core/game_database.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const BoardViewScript = preload("res://scripts/view/board_view.gd")
const PLAYER_COLORS = [
	Color(0.95, 0.18, 0.22),
	Color(0.25, 0.48, 1.0),
	Color(0.20, 0.78, 0.25),
	Color(1.0, 0.82, 0.22)
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

var db
var state
var board
var selected_unit_id = -1
var selected_building_id = -1
var hud_top_panel: PanelContainer
var hud_bottom_panel: HBoxContainer
var action_container_panel: PanelContainer
var status_label: Label
var info_panel: PanelContainer
var info_label: Label
var action_panel: VBoxContainer
var action_scroll: ScrollContainer
var end_turn_button: Button
var undo_button: Button
var restart_button: Button
var main_menu_button: Button
var surrender_button: Button
var game_encyclopedia_button: Button
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
var menu_buttons: VBoxContainer
var encyclopedia_content: RichTextLabel
var encyclopedia_nav: VBoxContainer
var game_started = false
var bgm_volume_percent = 65
var sfx_volume_percent = 80
var selected_resolution = Vector2i(1280, 720)
var action_panel_width = 232
var fullscreen_enabled = false
var local_fog_enabled = true
var build_mode = ""
var build_origin_id = -1
var undo_history: Array = []

func _ready() -> void:
	db = GameDatabaseScript.new()
	db.load_data()
	state = GameStateScript.new()
	_setup_state()
	_create_audio()
	_create_board()
	_create_ui()
	_create_menu_ui()
	_refresh_ui()
	_set_game_visible(false)

func _process(_delta: float) -> void:
	_poll_online()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_set_fullscreen(not fullscreen_enabled)

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
	if action_container_panel != null:
		action_container_panel.position = Vector2(0, 28)
		action_container_panel.size = Vector2(action_panel_width, max(120.0, size.y - 56))
	if action_scroll != null:
		action_scroll.custom_minimum_size = Vector2(action_panel_width - 8, max(120.0, size.y - 68))
	if hud_bottom_panel != null:
		hud_bottom_panel.position = Vector2(max(190.0, size.x * 0.5 - 170.0), max(40.0, size.y - 42.0))
	if info_panel != null:
		var info_width = min(520.0, max(300.0, size.x - action_panel_width - 560.0))
		info_panel.position = Vector2(action_panel_width + 12.0, max(42.0, size.y - 136.0))
		info_panel.size = Vector2(info_width, 84.0)
	if info_label != null:
		info_label.size = Vector2(max(280.0, info_panel.size.x - 20.0), 72.0)

func _setup_state() -> void:
	var map_size = Vector2i(60, 30)
	if player_count == 3:
		map_size = Vector2i(60, 60)
	elif player_count == 4:
		map_size = Vector2i(80, 80)
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
	status_label.custom_minimum_size = Vector2(430, 24)
	top_bar.add_child(status_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	game_encyclopedia_button = Button.new()
	game_encyclopedia_button.text = "百科"
	game_encyclopedia_button.custom_minimum_size = Vector2(74, 24)
	game_encyclopedia_button.pressed.connect(_open_encyclopedia_overlay)
	top_bar.add_child(game_encyclopedia_button)

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

	restart_button = Button.new()
	restart_button.text = "重新开始"
	restart_button.pressed.connect(_on_restart_pressed)
	hud_bottom_panel.add_child(restart_button)

	main_menu_button = Button.new()
	main_menu_button.text = "返回主菜单"
	main_menu_button.pressed.connect(_return_to_main_menu)
	hud_bottom_panel.add_child(main_menu_button)

	surrender_button = Button.new()
	surrender_button.text = "投降"
	surrender_button.pressed.connect(_on_surrender_pressed)
	hud_bottom_panel.add_child(surrender_button)

	info_panel = PanelContainer.new()
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_style = StyleBoxFlat.new()
	info_style.bg_color = Color(0.04, 0.04, 0.08, 0.58)
	info_style.border_color = Color(0.18, 0.20, 0.30, 0.55)
	info_style.border_width_left = 1
	info_style.border_width_top = 1
	info_style.border_width_right = 1
	info_style.border_width_bottom = 1
	info_style.content_margin_left = 10
	info_style.content_margin_top = 6
	info_style.content_margin_right = 10
	info_style.content_margin_bottom = 6
	info_panel.add_theme_stylebox_override("panel", info_style)
	add_child(info_panel)

	info_label = Label.new()
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.size = Vector2(420, 72)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.clip_text = true
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

	_create_online_ui()
	_layout_game_ui()

func _create_online_ui() -> void:
	var box = VBoxContainer.new()
	online_inline_panel = box
	box.visible = false
	box.position = Vector2(900, 650)
	box.size = Vector2(360, 58)
	add_child(box)
	var row = HBoxContainer.new()
	box.add_child(row)
	online_url_input = LineEdit.new()
	online_url_input.text = _saved_online_url()
	online_url_input.placeholder_text = "ws://服务器IP:3000"
	online_url_input.custom_minimum_size = Vector2(150, 28)
	row.add_child(online_url_input)
	online_room_input = LineEdit.new()
	online_room_input.placeholder_text = "房号"
	online_room_input.custom_minimum_size = Vector2(54, 28)
	row.add_child(online_room_input)
	var create_btn = Button.new()
	create_btn.text = "建房"
	create_btn.pressed.connect(_on_online_create_pressed)
	row.add_child(create_btn)
	var join_btn = Button.new()
	join_btn.text = "加入"
	join_btn.pressed.connect(_on_online_join_pressed)
	row.add_child(join_btn)
	var leave_btn = Button.new()
	leave_btn.text = "断开"
	leave_btn.pressed.connect(_on_online_leave_pressed)
	row.add_child(leave_btn)
	online_status_label = Label.new()
	online_status_label.text = "本地热座"
	box.add_child(online_status_label)

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
	online_menu_panel.offset_top = -120
	online_menu_panel.offset_right = 230
	online_menu_panel.offset_bottom = 120
	menu_layer.add_child(online_menu_panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	online_menu_panel.add_child(box)
	var title = Label.new()
	title.text = "远程联机"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var url = Label.new()
	url.text = "服务器地址在右下角填写，默认 ws://175.178.173.76:3000"
	url.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(url)
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
	join_btn.text = "加入右下角房号"
	join_btn.pressed.connect(_on_online_join_pressed)
	box.add_child(join_btn)
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
	settings_panel.offset_top = -150
	settings_panel.offset_right = 210
	settings_panel.offset_bottom = 150
	menu_layer.add_child(settings_panel)
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

	var back = Button.new()
	back.text = "返回"
	back.pressed.connect(_show_menu_home)
	box.add_child(back)

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
		["ch0", "CH.0 游戏规则"],
		["ch1", "CH.1 兵种大全"],
		["ch2", "CH.2 建筑大全"],
		["ch3", "CH.3 科技树"]
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
	body.add_child(encyclopedia_content)
	_render_encyclopedia_chapter("ch1")

func _render_encyclopedia_chapter(chapter_id: String) -> void:
	if encyclopedia_content == null:
		return
	encyclopedia_content.clear()
	if chapter_id == "ch0":
		encyclopedia_content.parse_bbcode(_encyclopedia_rules_bbcode())
		_add_terrain_images_to_encyclopedia()
	elif chapter_id == "ch1":
		_render_encyclopedia_units_content()
	elif chapter_id == "ch2":
		_render_encyclopedia_buildings_content()
	else:
		encyclopedia_content.parse_bbcode(_encyclopedia_tech_bbcode())

func _set_game_visible(visible: bool) -> void:
	if board != null:
		board.visible = visible
	for node in [hud_top_panel, hud_bottom_panel, info_panel, action_container_panel]:
		if node != null:
			node.visible = visible
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

func _close_encyclopedia_panel() -> void:
	encyclopedia_panel.visible = false
	if menu_layer != null and menu_layer.visible and not game_started:
		menu_buttons.visible = true

func _show_settings() -> void:
	menu_buttons.visible = false
	settings_panel.visible = true
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
	_clear_selection()
	_clear_undo_history()
	_on_online_leave_pressed()
	if game_over_panel != null:
		game_over_panel.visible = false
	_set_game_visible(false)
	_show_menu_home()

func _start_local_game(count: int) -> void:
	player_count = clampi(count, 2, 4)
	local_fog_enabled = local_fog_checkbox == null or local_fog_checkbox.button_pressed
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
			board.set_build_tiles(state.collector_build_tiles(origin), PLAYER_COLORS[state.current_player])
		return
	var clicked_unit: Dictionary = state.unit_at(pos)
	if not clicked_unit.is_empty() and state.is_current_players_unit(clicked_unit):
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
				_play_sfx("mg")
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
		return
	var empty_tiles: Array[Vector2i] = []
	board.set_hover_threat(empty_tiles, "")
	var viewer = _local_view_player()
	var terrain: Dictionary = db.terrain_data(state.terrain_at(pos))
	var lines = ["地形：%s  高度 %s  移动 %.1f" % [terrain.get("name", "未知"), terrain.get("height", 0), terrain.get("move_cost", 1.0)]]
	if build_mode == "资源采集器":
		var origin = state.get_building_by_id(build_origin_id)
		lines.append("")
		if state.can_build_collector(origin, pos):
			lines.append("可建造资源采集器：8 金 / 2 回合")
		else:
			lines.append("资源采集器需建在大本营 5 格内空地")
	var unit: Dictionary = state.unit_at(pos)
	if not unit.is_empty() and (int(unit["pid"]) == viewer or state.is_visible(viewer, pos)):
		lines.append("")
		lines.append("单位：%s / %s" % [unit["type"], _player_name(int(unit["pid"]))])
		lines.append("HP：%.1f / %.1f" % [unit["hp"], unit["max_hp"]])
		lines.append("护甲：%.1f  伤害：%.1f  射程：%.1f  移速：%d" % [unit["armor"], unit["damage"], unit["range"], unit["speed"]])
		if int(unit["pid"]) != viewer and int(unit["pid"]) >= 0:
			var threat = state.hover_threat_tiles_for_unit(unit)
			var radius = float(unit.get("speed", 0)) + state.max_possible_range_for(unit, unit["pos"])
			board.set_hover_threat(threat, "威胁范围(%.1f)" % radius)
	var building: Dictionary = state.building_at(pos)
	if not building.is_empty() and state.is_explored(viewer, pos):
		var building_visible = state.is_visible(viewer, pos)
		var display = building
		if not building_visible:
			var memory = state.building_memory_for(viewer, pos)
			if not memory.is_empty():
				display = memory
		lines.append("")
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
		else:
			var seen_turn = int(display.get("turn", state.turn))
			lines.append("上次侦察：回合 %d" % seen_turn)
			lines.append("HP：%.1f / %.1f  护甲：%.1f  收入：%.1f" % [float(display.get("hp", 0.0)), float(display.get("max_hp", 0.0)), float(display.get("armor", 0.0)), float(display.get("gold", 0.0))])
	info_label.text = "\n".join(lines)

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
	board.clear_selection()

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
	state.end_turn()
	_clear_undo_history()
	_after_turn_state_changed(not online_connected)
	_notify_online("end-turn")

func _on_restart_pressed() -> void:
	_clear_selection()
	if game_over_panel != null:
		game_over_panel.visible = false
	_clear_undo_history()
	state.new_game()
	state.fog_enabled = local_fog_enabled and not online_connected
	_after_turn_state_changed(true)

func _on_player_count_pressed(count: int) -> void:
	if online_connected:
		return
	player_count = clampi(count, 2, 4)
	_clear_selection()
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
	if board != null:
		board.queue_redraw()

func _sync_board_view_player() -> void:
	if board == null:
		return
	board.set_view_player(_local_view_player())

func _local_view_player() -> int:
	if online_connected and online_player_id >= 0:
		return online_player_id
	return state.current_player

func _refresh_ui() -> void:
	if state.game_over:
		status_label.text = "游戏结束：%s 胜利" % _player_name(state.winner)
		_show_game_over_panel()
		return
	var player: Dictionary = state.players[state.current_player]
	var online_text = ""
	if online_connected:
		online_text = "   联机房间 %s   你是%s" % [online_room_id, _player_name(online_player_id)]
	status_label.text = "%s玩家%d   回合 %d   🪙 %.2f (+%.2f/回合)%s" % [_player_color_prefix(state.current_player), state.current_player + 1, state.turn, float(player["gold"]), _current_income(state.current_player), online_text]
	if surrender_button != null:
		surrender_button.disabled = not _can_control_current_turn()
	if end_turn_button != null:
		end_turn_button.disabled = not _can_control_current_turn()
	if undo_button != null:
		undo_button.disabled = undo_history.is_empty() or not _can_control_current_turn()
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
	control.tooltip_text = text
	control.mouse_entered.connect(func():
		info_label.text = text
	)

func _refresh_action_panel() -> void:
	for child in action_panel.get_children():
		child.queue_free()
	var should_show = selected_unit_id >= 0 or selected_building_id >= 0 or build_mode == "资源采集器" or (online_connected and not _can_control_current_turn())
	if action_container_panel != null:
		action_container_panel.visible = game_started and should_show
	if not should_show:
		return
	var title = Label.new()
	title.text = "操作"
	action_panel.add_child(title)
	if selected_unit_id >= 0:
		var unit = state.get_unit_by_id(selected_unit_id)
		if not unit.is_empty():
			var label = Label.new()
			label.text = "已选单位：%s\nHP %.1f / %.1f  护甲 %.1f\n伤害 %.1f  射程 %.1f  移速 %d\n剩余攻击：%d / %d" % [
				unit["type"],
				float(unit["hp"]),
				float(unit["max_hp"]),
				float(unit["armor"]),
				float(unit["damage"]),
				float(unit["range"]),
				int(unit["speed"]),
				int(unit["remaining_attacks"]),
				int(unit["attacks"])
			]
			action_panel.add_child(label)
			_add_unit_equip_buttons(unit)
			var skip = _make_action_button("待机")
			skip.pressed.connect(func(): _on_skip_unit_pressed(int(unit["id"])))
			action_panel.add_child(skip)
		return
	if online_connected and not _can_control_current_turn():
		var wait = Label.new()
		wait.text = "联机中，等待 %s 操作。" % _player_name(state.current_player)
		action_panel.add_child(wait)
		return
	if selected_building_id >= 0:
		var building = state.get_building_by_id(selected_building_id)
		if building.is_empty():
			return
		var building_label = Label.new()
		building_label.text = "%s\nHP %.1f / %.1f  护甲 %.1f\n收入 %.1f / 回合" % [
			building["type"],
			float(building["hp"]),
			float(building["max_hp"]),
			float(building.get("armor", 0.0)),
			float(building.get("gold", 0.0))
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
			_add_equipment_buttons()
			_add_strategic_buttons()
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
	var units = state.available_units_for_player(state.current_player)
	var sep = Label.new()
	sep.text = "\n生产单位"
	action_panel.add_child(sep)
	for unit_type in units:
		var data = db.unit_data(unit_type)
		var captured_building_id = int(building["id"])
		var captured_unit_type = str(unit_type)
		var btn = _make_action_button("%s  🪙 %.1f" % [unit_type, float(data.get("price", 0.0))])
		_bind_action_hover(btn, _unit_info_text(captured_unit_type))
		btn.disabled = not state.can_produce(building, unit_type)
		btn.pressed.connect(func(): _on_produce_pressed(captured_building_id, captured_unit_type))
		action_panel.add_child(btn)

func _add_hq_upgrade_button(building: Dictionary) -> void:
	if bool(building.get("upgrading", false)):
		var label = Label.new()
		label.text = "大本营升级中：%d 回合" % int(building.get("up_timer", 0))
		action_panel.add_child(label)
		return
	var btn = _make_action_button("⬆ T%d  🪙 %.1f" % [int(building.get("tier", 0)) + 2, _next_hq_upgrade_cost(building)])
	btn.disabled = not state.can_upgrade_hq(building)
	if int(building.get("tier", 0)) >= 2:
		btn.text = "大本营已满级"
	_bind_action_hover(btn, _building_action_info_text("hq-upgrade"))
	btn.pressed.connect(func(): _on_hq_upgrade_pressed(int(building["id"])))
	action_panel.add_child(btn)

func _add_equipment_buttons() -> void:
	var sep = Label.new()
	sep.text = "\n装备研究"
	action_panel.add_child(sep)
	var any = false
	for unit_type in db.equipment.keys():
		for equip in db.equipment_for(unit_type):
			var name = str(equip.get("name", ""))
			var key = state.equipment_key(str(unit_type), name)
			if state.players[state.current_player]["equipment"].has(key):
				continue
			var active_research = state.research_entry(state.current_player, name)
			if not active_research.is_empty():
				var label = Label.new()
				label.text = "%s：%s 研究中：%d 回合" % [unit_type, name, int(active_research.get("timer", 0))]
				action_panel.add_child(label)
				any = true
				continue
			any = true
			var captured_unit_type = str(unit_type)
			var captured_name = name
			var btn = _make_action_button("%s：%s  🪙 %.1f" % [unit_type, name, float(equip.get("research_cost", 0.0))])
			_bind_action_hover(btn, _equipment_info_text(captured_unit_type, equip))
			btn.disabled = not state.can_research_equipment(state.current_player, str(unit_type), name)
			btn.pressed.connect(func(): _on_equipment_pressed(captured_unit_type, captured_name))
			action_panel.add_child(btn)
	if not any:
		var done = Label.new()
		done.text = "装备研究已完成"
		action_panel.add_child(done)

func _add_strategic_buttons() -> void:
	var sep = Label.new()
	sep.text = "\n战略科技"
	action_panel.add_child(sep)
	var any = false
	for tech_name in db.strategic_techs.keys():
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
	var sep = Label.new()
	sep.text = "\n建筑"
	action_panel.add_child(sep)
	var data = db.building_data("资源采集器")
	var btn = _make_action_button("⛏ 资源采集器  🪙 %.1f" % float(data.get("cost", 8.0)))
	_bind_action_hover(btn, _building_action_info_text("collector"))
	btn.disabled = float(state.players[state.current_player]["gold"]) < float(data.get("cost", 8.0))
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
	if int(state.players[state.current_player].get("tier", 1)) < 2:
		var locked = Label.new()
		locked.text = "需要大本营升级到 T2 后才能升级据点。"
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
	_clear_selection()
	build_mode = "资源采集器"
	build_origin_id = building_id
	var origin = state.get_building_by_id(building_id)
	info_label.text = "建造资源采集器：点击大本营 5 格内空地。\n费用 8 金，2 回合完工，完工后按编号产金：4.5 × 0.8^编号。"
	board.set_build_tiles(state.collector_build_tiles(origin), PLAYER_COLORS[state.current_player])
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
	return not online_connected or online_player_id == state.current_player

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
		"研究 %.1f 金  需求 T%d" % [float(equip.get("research_cost", 0.0)), int(equip.get("tier", 1))]
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
	return "%s\n研究 %.1f 金  需求 T%d\n%s" % [
		tech_name,
		float(tech.get("cost", 0.0)),
		int(tech.get("tier", 1)),
		str(tech.get("desc", ""))
	]

func _tech_info_text(tech_id: String, tech: Dictionary) -> String:
	var unlocks = []
	for unit_type in tech.get("unlocks", []):
		unlocks.append(str(unit_type))
	return "%s %s\n研究 %.1f 金\n解锁：%s" % [
		tech_id,
		str(tech.get("name", tech_id)),
		float(tech.get("cost", 0.0)),
		"、".join(unlocks)
	]

func _building_action_info_text(kind: String) -> String:
	if kind == "collector":
		return "资源采集器\n建造 8 金 / 2 回合\n点击大本营 5 格内空地建造。\n完工后按编号产金：4.5 × 0.8^编号。"
	if kind == "outpost-combat":
		return "战斗型据点\n升级 10 金 / 1 回合\nHP 30，护甲 0.5，每回合 +6，驻扎范围 3。"
	if kind == "outpost-economic":
		return "经济型据点\n升级 10 金 / 3 回合\nHP 20，护甲 0，每回合 +9，驻扎范围 2。"
	if kind == "hq-upgrade":
		return "大本营升级\n提升大本营 HP、护甲、收入、视野；升级倒计时完成后解锁下一时代兵种和科技条件。"
	return ""

func _outpost_branch_label(branch: String) -> String:
	if branch == "combat":
		return "T2 战斗型据点"
	if branch == "economic":
		return "T2 经济型据点"
	return "T1 据点"

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
	lines.append("[cell]据点 / 资源采集器[/cell][cell]5 / 3[/cell][cell]据点 4.5 金/回合；采集器按 4.5 × 0.8^编号产金[/cell]")
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
	lines.append("")
	lines.append("[color=#e8dcc8][b]据点 T2 分支[/b][/color]")
	lines.append("[table=6][cell][b]分支[/b][/cell][cell][b]升级[/b][/cell][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]收入[/b][/cell][cell][b]说明[/b][/cell]")
	lines.append("[cell]战斗型[/cell][cell]10 金 / 1 回合[/cell][cell]30[/cell][cell]0.5[/cell][cell]6[/cell][cell]更适合前线驻扎[/cell]")
	lines.append("[cell]经济型[/cell][cell]10 金 / 3 回合[/cell][cell]20[/cell][cell]0[/cell][cell]9[/cell][cell]更适合后方滚经济[/cell][/table]")
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
	_collect_delta_line(lines, "价格", unit.get("price", 0.0), equip.get("cost", null))
	_collect_delta_line(lines, "生命", unit.get("hp", 0.0), equip.get("hp", null))
	_collect_delta_line(lines, "护甲", unit.get("armor", 0.0), equip.get("armor", null))
	_collect_delta_line(lines, "伤害", unit.get("damage", 0.0), equip.get("dmg", null))
	_collect_delta_line(lines, "射程", unit.get("range", 0.0), equip.get("range", null))
	_collect_delta_line(lines, "移速", unit.get("speed", 0.0), equip.get("speed", null))
	if equip.has("blast"):
		lines.append("爆炸范围：%.1f → %.1f" % [float(unit.get("blast", 0.0)), float(equip.get("blast", 0.0))])
	if bool(equip.get("can_target_air", false)):
		lines.append("新增：可以攻击空军")
	return lines

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
		_add_encyclopedia_image(str(unit.get("texture", "")), str(unit_type))
		encyclopedia_content.append_text("[color=#f0e6c0][font_size=20]%s[/font_size][/color]\n" % str(unit_type))
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
				var equip_path = "res://assets/images/%s-%s.png" % [str(unit_type), str(equip.get("name", ""))]
				_add_encyclopedia_image(equip_path, "%s-%s" % [str(unit_type), str(equip.get("name", ""))])
				encyclopedia_content.append_text("  [color=#e0d4c0]%s[/color]  研究 %.1f 金 / 需求 T%d\n" % [str(equip.get("name", "")), float(equip.get("research_cost", 0.0)), int(equip.get("tier", 1))])
				for line in _equipment_delta_lines(str(unit_type), equip):
					encyclopedia_content.append_text("    " + line + "\n")
		encyclopedia_content.append_text("\n")
	encyclopedia_content.append_text("[color=#e8dcc8][b]兵种数据速查[/b][/color]\n")
	encyclopedia_content.append_text(_unit_quick_table_bbcode())

func _render_encyclopedia_buildings_content() -> void:
	encyclopedia_content.append_text("[font_size=26][color=#f0e6c0]建筑大全[/color][/font_size]\n")
	encyclopedia_content.append_text("[color=#6a6a7a]第二章 · 大本营、据点与资源建筑[/color]\n\n")
	_add_encyclopedia_image("res://assets/images/大本营 T1.png", "大本营 T1")
	encyclopedia_content.append_text("[color=#f0e6c0][font_size=20]大本营[/font_size][/color]\n")
	encyclopedia_content.append_text("核心建筑，提供收入、视野和单位生产。大本营升级完成后推进 T2/T3 解锁；被摧毁会直接影响胜负。\n")
	var hq = db.building_data("大本营")
	encyclopedia_content.append_text("[table=6][cell][b]等级[/b][/cell][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]收入[/b][/cell][cell][b]视野[/b][/cell][cell][b]升级费用[/b][/cell]")
	var idx = 1
	for tier in hq.get("tiers", []):
		encyclopedia_content.append_text("[cell]T%d[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%d[/cell][cell]%s[/cell]" % [idx, float(tier.get("hp", 0.0)), float(tier.get("armor", 0.0)), float(tier.get("gold", 0.0)), int(tier.get("vision", 0)), str(tier.get("upgrade_cost", "满级"))])
		idx += 1
	encyclopedia_content.append_text("[/table]\n")
	_add_encyclopedia_image("res://assets/images/大本营 T2.png", "大本营 T2")
	_add_encyclopedia_image("res://assets/images/大本营T3.png", "大本营 T3")
	for building_type in db.buildings.keys():
		if str(building_type) == "大本营":
			continue
		var building = db.building_data(str(building_type))
		encyclopedia_content.append_text("\n")
		_add_encyclopedia_image(str(building.get("texture", "")), str(building_type))
		encyclopedia_content.append_text("[color=#f0e6c0][font_size=20]%s[/font_size][/color]\n" % str(building_type))
		encyclopedia_content.append_text("[table=5][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]收入[/b][/cell][cell][b]视野[/b][/cell][cell][b]说明[/b][/cell]")
		encyclopedia_content.append_text("[cell]%.1f[/cell][cell]%.1f[/cell][cell]%.1f[/cell][cell]%d[/cell][cell]%s[/cell][/table]\n" % [float(building.get("hp", 0.0)), float(building.get("armor", 0.0)), float(building.get("gold", 0.0)), int(building.get("vision", 0)), _building_note(str(building_type))])
	_add_encyclopedia_image("res://assets/images/资源型T2据点.png", "资源型 T2 据点")
	_add_encyclopedia_image("res://assets/images/战斗型T2据点.jpg", "战斗型 T2 据点")
	encyclopedia_content.append_text("\n[color=#e8dcc8][b]据点 T2 分支[/b][/color]\n")
	encyclopedia_content.append_text("[table=6][cell][b]分支[/b][/cell][cell][b]升级[/b][/cell][cell][b]生命[/b][/cell][cell][b]护甲[/b][/cell][cell][b]收入[/b][/cell][cell][b]说明[/b][/cell]")
	encyclopedia_content.append_text("[cell]战斗型[/cell][cell]10 金 / 1 回合[/cell][cell]30[/cell][cell]0.5[/cell][cell]6[/cell][cell]更适合前线驻扎[/cell]")
	encyclopedia_content.append_text("[cell]经济型[/cell][cell]10 金 / 3 回合[/cell][cell]20[/cell][cell]0[/cell][cell]9[/cell][cell]更适合后方滚经济[/cell][/table]\n")

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
		var unit = db.unit_data(str(unit_type))
		_add_encyclopedia_image(str(unit.get("texture", "")), str(unit_type))
		for equip in db.equipment_for(str(unit_type)):
			var equip_path = "res://assets/images/%s-%s.png" % [str(unit_type), str(equip.get("name", ""))]
			_add_encyclopedia_image(equip_path, "%s-%s" % [str(unit_type), str(equip.get("name", ""))])

func _add_building_images_to_encyclopedia() -> void:
	encyclopedia_content.append_text("\n\n[b]建筑图片[/b]\n")
	for building_type in db.buildings.keys():
		var building = db.building_data(str(building_type))
		_add_encyclopedia_image(str(building.get("texture", "")), str(building_type))
	_add_encyclopedia_image("res://assets/images/大本营 T2.png", "大本营 T2")
	_add_encyclopedia_image("res://assets/images/大本营T3.png", "大本营 T3")
	_add_encyclopedia_image("res://assets/images/资源型T2据点.png", "资源型 T2 据点")
	_add_encyclopedia_image("res://assets/images/战斗型T2据点.jpg", "战斗型 T2 据点")

func _add_terrain_images_to_encyclopedia() -> void:
	encyclopedia_content.append_text("\n\n[b]地形贴图[/b]\n")
	for terrain_id in db.terrain.keys():
		var terrain = db.terrain_data(str(terrain_id))
		_add_encyclopedia_image(str(terrain.get("texture", "")), str(terrain.get("name", terrain_id)))

func _add_encyclopedia_image(path: String, label: String) -> void:
	if path.is_empty():
		return
	var texture = load(path)
	if texture == null:
		return
	encyclopedia_content.append_text("\n%s\n" % label)
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
