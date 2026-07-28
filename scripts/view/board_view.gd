extends Node2D
class_name BoardView

signal tile_clicked(pos: Vector2i)
signal tile_hovered(pos: Vector2i)
signal group_box_selected(tile_bounds: Rect2i, create_formation: bool)
signal group_move_requested(target: Vector2i)

const BASE_TILE_SIZE = 48
const MIN_ZOOM = 0.35
const MAX_ZOOM = 2.6
const PLAYER_COLORS = [
	Color(0.95, 0.18, 0.22),
	Color(0.25, 0.48, 1.0),
	Color(0.20, 0.78, 0.25),
	Color(1.0, 0.82, 0.22)
]
const UNIT_SHORT_NAMES = {
	"战团": "战团", "斥候": "斥候", "投石队": "投石", "部落侦察": "侦察",
	"方阵": "方阵", "骑兵": "骑兵", "弓弩/投石车": "弓弩", "轻骑侦察": "轻侦",
	"火枪连": "火枪", "龙骑兵": "龙骑", "野战炮": "野炮", "工兵/观测队": "观测",
	"士兵": "士兵", "主战坦克": "坦克", "坦克": "坦克", "自行火炮": "自火", "军用吉普": "吉普", "吉普": "吉普",
	"网络化步兵": "网步", "无人战车": "战车", "精确火箭": "火箭", "无人机/电子战": "无人机"
}
const UNIT_ERA_BY_NAME = {
	"战团": 1, "斥候": 1, "投石队": 1, "部落侦察": 1,
	"方阵": 2, "骑兵": 2, "弓弩/投石车": 2, "轻骑侦察": 2,
	"火枪连": 3, "龙骑兵": 3, "野战炮": 3, "工兵/观测队": 3,
	"士兵": 4, "主战坦克": 4, "坦克": 4, "自行火炮": 4, "军用吉普": 4, "吉普": 4,
	"网络化步兵": 5, "无人战车": 5, "精确火箭": 5, "无人机/电子战": 5
}

var state
var db
var selected_unit_id = -1
var selected_building_id = -1
var selected_group_unit_ids: Array[int] = []
var move_tiles: Array[Vector2i] = []
var attack_tiles: Array[Vector2i] = []
var range_tiles: Array[Vector2i] = []
var threat_tiles: Array[Vector2i] = []
var hover_threat_tiles: Array[Vector2i] = []
var hover_threat_label = ""
var build_tiles: Array[Vector2i] = []
var build_color = Color(0.2, 0.8, 1.0, 0.42)
var build_tile_income = -1.0
var terrain_textures: Dictionary = {}
var unit_textures: Dictionary = {}
var building_textures: Dictionary = {}
var hover_tile = Vector2i(-1, -1)
var zoom = 1.0
var camera_offset = Vector2.ZERO
var viewport_size = Vector2(1280, 720)
var dragging = false
var drag_start = Vector2.ZERO
var drag_origin = Vector2.ZERO
var view_player_id = -1
var box_selecting = false
var box_select_start = Vector2.ZERO
var box_select_current = Vector2.ZERO
var box_select_for_formation = false

func setup(game_state, database) -> void:
	state = game_state
	db = database
	zoom = 1.0
	camera_offset = Vector2.ZERO
	_load_textures()
	center_on_current_player()
	queue_redraw()

func _ready() -> void:
	set_process_unhandled_input(true)

func _load_textures() -> void:
	terrain_textures.clear()
	unit_textures.clear()
	building_textures.clear()
	for terrain_id in db.terrain.keys():
		terrain_textures[terrain_id] = _load_texture(db.texture_path_for_terrain(str(terrain_id)))
	for unit_type in db.units.keys():
		unit_textures[unit_type] = _load_texture(db.texture_path_for_unit(str(unit_type)))
		for equip in db.equipment_for(str(unit_type)):
			var equip_name = str(equip.get("name", ""))
			var equip_key = "%s-%s" % [str(unit_type), equip_name]
			unit_textures[equip_key] = _load_texture(db.texture_path_for_equipment(equip))
	for texture_key in db.building_texture_catalog().keys():
		building_textures[texture_key] = _load_texture(str(db.building_texture_catalog()[texture_key]))

func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)

func set_selection(unit_id: int, building_id: int, moves: Array[Vector2i], attacks: Array[Vector2i]) -> void:
	selected_unit_id = unit_id
	selected_building_id = building_id
	move_tiles = moves
	attack_tiles = attacks
	queue_redraw()

func set_group_selection(unit_ids: Array[int]) -> void:
	selected_group_unit_ids = unit_ids.duplicate()
	selected_unit_id = -1
	selected_building_id = -1
	move_tiles.clear()
	attack_tiles.clear()
	range_tiles.clear()
	threat_tiles.clear()
	queue_redraw()

func set_tactical_overlays(ranges: Array[Vector2i], threats: Array[Vector2i]) -> void:
	range_tiles = ranges
	threat_tiles = threats
	queue_redraw()

func set_hover_threat(tiles: Array[Vector2i], label: String = "") -> void:
	hover_threat_tiles = tiles
	hover_threat_label = label
	queue_redraw()

func set_build_tiles(tiles: Array[Vector2i], color: Color, income: float = -1.0) -> void:
	build_tiles = tiles
	build_color = color
	build_tile_income = income
	queue_redraw()

func build_preview_tile() -> Vector2i:
	if build_tiles.has(hover_tile):
		return hover_tile
	return Vector2i(-1, -1)

func clear_selection() -> void:
	selected_group_unit_ids.clear()
	var empty_moves: Array[Vector2i] = []
	var empty_attacks: Array[Vector2i] = []
	set_selection(-1, -1, empty_moves, empty_attacks)
	set_tactical_overlays(empty_moves, empty_attacks)
	set_hover_threat(empty_moves, "")
	set_build_tiles(empty_moves, Color(0.2, 0.8, 1.0, 0.42))

func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(to_local(event.position), 1.12)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(to_local(event.position), 1.0 / 1.12)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local_mouse = to_local(event.position)
		if event.pressed:
			if event.ctrl_pressed or event.alt_pressed:
				box_selecting = true
				box_select_start = local_mouse
				box_select_current = local_mouse
				box_select_for_formation = event.alt_pressed
				dragging = false
			else:
				dragging = true
				drag_start = local_mouse
				drag_origin = camera_offset
		else:
			if box_selecting:
				var was_box_drag = box_select_start.distance_to(local_mouse) >= 8.0
				box_selecting = false
				box_select_current = local_mouse
				if was_box_drag:
					var start_tile = screen_to_tile(box_select_start)
					var end_tile = screen_to_tile(local_mouse)
					var min_tile = Vector2i(min(start_tile.x, end_tile.x), min(start_tile.y, end_tile.y))
					var max_tile = Vector2i(max(start_tile.x, end_tile.x), max(start_tile.y, end_tile.y))
					var bounds = Rect2i(min_tile, max_tile - min_tile + Vector2i.ONE)
					group_box_selected.emit(bounds, box_select_for_formation)
				queue_redraw()
				return
			var clicked = drag_start.distance_to(local_mouse) < 6.0
			dragging = false
			if clicked:
				var tile = screen_to_tile(local_mouse)
				if state.in_bounds(tile):
					if selected_group_unit_ids.is_empty():
						tile_clicked.emit(tile)
					else:
						group_move_requested.emit(tile)
		return
	if event is InputEventMouseMotion:
		var local_mouse = to_local(event.position)
		if box_selecting:
			box_select_current = local_mouse
			queue_redraw()
			return
		if dragging:
			camera_offset = drag_origin + (local_mouse - drag_start)
			_clamp_camera()
			queue_redraw()
			return
		var pos = screen_to_tile(local_mouse)
		if pos != hover_tile:
			hover_tile = pos
			tile_hovered.emit(pos)
			queue_redraw()

func screen_to_tile(local_pos: Vector2) -> Vector2i:
	var world = (local_pos - camera_offset) / _tile_size()
	return Vector2i(floori(world.x), floori(world.y))

func tile_rect(pos: Vector2i) -> Rect2:
	var size = _tile_size()
	return Rect2(camera_offset + Vector2(pos.x * size, pos.y * size), size * Vector2.ONE)

func set_viewport_size(size: Vector2) -> void:
	viewport_size = size
	_clamp_camera()
	queue_redraw()

func center_on_current_player() -> void:
	if state == null:
		return
	var target_player = _view_player()
	for building in state.buildings:
		if building["type"] == "大本营" and int(building["pid"]) == target_player:
			center_on_tile(building["pos"])
			return

func set_view_player(pid: int) -> void:
	view_player_id = pid
	queue_redraw()

func _view_player() -> int:
	if view_player_id >= 0 and state != null and view_player_id < state.players.size():
		return view_player_id
	return state.current_player

func center_on_tile(pos: Vector2i) -> void:
	var size = _tile_size()
	camera_offset = viewport_size * 0.5 - (Vector2(pos) + Vector2(0.5, 0.5)) * size
	_clamp_camera()
	queue_redraw()

func _tile_size() -> float:
	return BASE_TILE_SIZE * zoom

func _zoom_at(local_pos: Vector2, factor: float) -> void:
	var old_size = _tile_size()
	var world = (local_pos - camera_offset) / old_size
	zoom = clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	camera_offset = local_pos - world * _tile_size()
	_clamp_camera()
	queue_redraw()

func _clamp_camera() -> void:
	if state == null:
		return
	var map_size = Vector2(state.width, state.height) * _tile_size()
	if map_size.x <= viewport_size.x:
		camera_offset.x = (viewport_size.x - map_size.x) * 0.5
	else:
		camera_offset.x = clampf(camera_offset.x, viewport_size.x - map_size.x, 0.0)
	if map_size.y <= viewport_size.y:
		camera_offset.y = (viewport_size.y - map_size.y) * 0.5
	else:
		camera_offset.y = clampf(camera_offset.y, viewport_size.y - map_size.y, 0.0)

func _draw() -> void:
	if state == null or db == null:
		return
	_draw_terrain()
	_draw_overlays()
	_draw_buildings()
	_draw_units()
	_draw_fog()
	_draw_grid()
	_draw_group_selection_box()

func _draw_terrain() -> void:
	var visible = _visible_tile_rect()
	for y in range(visible.position.y, visible.end.y):
		for x in range(visible.position.x, visible.end.x):
			var pos = Vector2i(x, y)
			var terrain_id = state.terrain_at(pos)
			var rect = tile_rect(pos)
			var data = db.terrain_data(terrain_id)
			var color = Color(data.get("color", "#2d3a2d"))
			draw_rect(rect, color, true)
			var texture: Texture2D = terrain_textures.get(terrain_id)
			if texture != null:
				draw_texture_rect(texture, rect, false)

func _draw_overlays() -> void:
	var preview_tile = build_preview_tile()
	if preview_tile.x >= 0:
		var pos = preview_tile
		var rect = tile_rect(pos).grow(-3)
		draw_rect(rect, Color(build_color.r, build_color.g, build_color.b, 0.10), true)
		draw_rect(rect, Color(build_color.r, build_color.g, build_color.b, 0.96), false, max(2.0, 2.0 * zoom))
		if build_tile_income >= 0.0:
			_draw_build_income_badge(rect, build_tile_income)
	for pos in threat_tiles:
		draw_rect(tile_rect(pos).grow(-6), Color(0.72, 0.20, 1.0, 0.16), true)
		draw_rect(tile_rect(pos).grow(-6), Color(0.72, 0.20, 1.0, 0.72), false, 2.0)
	for pos in hover_threat_tiles:
		draw_rect(tile_rect(pos).grow(-7), Color(0.72, 0.20, 1.0, 0.20), true)
		draw_rect(tile_rect(pos).grow(-7), Color(0.88, 0.36, 1.0, 0.92), false, 3.0)
	for pos in range_tiles:
		draw_rect(tile_rect(pos).grow(-5), Color(1.0, 0.16, 0.18, 0.13), true)
		draw_rect(tile_rect(pos).grow(-5), Color(1.0, 0.16, 0.18, 0.78), false, 2.0)
	for pos in move_tiles:
		draw_rect(tile_rect(pos).grow(-4), Color(0.18, 0.54, 1.0, 0.20), true)
		draw_rect(tile_rect(pos).grow(-4), Color(0.18, 0.54, 1.0, 0.78), false, 2.0)
	for pos in attack_tiles:
		draw_rect(tile_rect(pos).grow(-8), Color(1.0, 0.08, 0.10, 0.38), true)
		draw_rect(tile_rect(pos).grow(-8), Color(1.0, 0.08, 0.10, 0.95), false, 3.0)
	if state.in_bounds(hover_tile):
		draw_rect(tile_rect(hover_tile).grow(-2), Color(1.0, 1.0, 1.0, 0.25), false, 2.0)
	if not hover_threat_label.is_empty() and not hover_threat_tiles.is_empty():
		_draw_overlay_label(hover_threat_tiles, hover_threat_label, Color(0.88, 0.74, 1.0))

func _draw_build_income_badge(tile: Rect2, income: float) -> void:
	var badge_height = clampf(17.0 * zoom, 14.0, 20.0)
	var font_size = int(clampf(11.0 * zoom, 9.0, 13.0))
	var income_text = _format_build_income(income)
	var text_width = ThemeDB.fallback_font.get_string_size(income_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var badge_width = max(tile.size.x - 4.0, 21.0 + text_width)
	var badge_x = clampf(tile.position.x + 2.0, 2.0, max(2.0, viewport_size.x - badge_width - 2.0))
	var badge = Rect2(Vector2(badge_x, tile.position.y + 2.0), Vector2(badge_width, badge_height))
	draw_rect(badge, Color(0.025, 0.03, 0.06, 0.88), true)
	draw_rect(badge, Color(0.92, 0.70, 0.18, 0.92), false, 1.0)
	var coin_center = Vector2(badge.position.x + 8.0, badge.position.y + badge.size.y * 0.5)
	draw_circle(coin_center, clampf(4.0 * zoom, 3.0, 5.0), Color(0.96, 0.73, 0.16))
	draw_circle(coin_center, clampf(2.0 * zoom, 1.5, 3.0), Color(1.0, 0.88, 0.38), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(badge.position.x + 15.0, badge.position.y + badge.size.y - 4.0), income_text, HORIZONTAL_ALIGNMENT_LEFT, text_width + 2.0, font_size, Color(1.0, 0.91, 0.56))

func _format_build_income(income: float) -> String:
	var text = "+%.2f" % income
	text = text.trim_suffix("0").trim_suffix("0").trim_suffix(".")
	return text

func _draw_buildings() -> void:
	var viewer = _view_player()
	for building in state.buildings:
		var visible = state.is_visible(viewer, building["pos"])
		var explored = state.is_explored(viewer, building["pos"])
		if not visible and not explored:
			continue
		var display = building
		if not visible:
			var memory = state.building_memory_for(viewer, building["pos"])
			if not memory.is_empty():
				display = memory
		var rect = tile_rect(building["pos"]).grow(-5)
		if bool(display.get("strategic_point", false)):
			var command_key = "command_point:active" if int(display.get("pid", -1)) >= 0 else "command_point:neutral"
			var command_texture: Texture2D = building_textures.get(command_key)
			if command_texture != null:
				draw_texture_rect(command_texture, rect.grow(3), false)
				rect = rect.grow(-2)
		var texture: Texture2D = building_textures.get(_texture_key_for_building(display))
		if texture != null:
			draw_texture_rect(texture, rect, false)
		else:
			_draw_missing_building_placeholder(rect, display)
		if not visible:
			draw_rect(rect, Color(0, 0, 0, 0.45), true)
		_draw_owner_frame(rect, int(display.get("pid", building["pid"])))
		_draw_building_status_badges(rect, building)
		if visible or not display.is_empty():
			_draw_health_bar(rect, float(display.get("hp", building["hp"])), float(display.get("max_hp", building["max_hp"])))
		if int(building["id"]) == selected_building_id:
			draw_rect(tile_rect(building["pos"]).grow(-3), Color(1.0, 1.0, 0.2), false, 3.0)

func _texture_key_for_building(building: Dictionary) -> String:
	var building_type = str(building.get("type", ""))
	if building_type == "大本营":
		return "hq:E%d" % clampi(int(building.get("tier", 0)) + 1, 1, 5)
	var era = clampi(int(building.get("era", 1)), 1, 5)
	if building_type == "据点":
		var branch = str(building.get("outpost_branch", "base")) if int(building.get("outpost_tier", 0)) > 0 else "base"
		if branch.is_empty():
			branch = "base"
		return "outpost:E%d:%s" % [era, branch]
	if building_type == "资源采集器":
		return "collector:E%d" % era
	if building_type == "防御工事":
		return "fortification:E%d" % era
	return building_type

func _draw_units() -> void:
	var viewer = _view_player()
	for unit in state.units:
		if int(unit["pid"]) != viewer and not state.is_visible(viewer, unit["pos"]):
			continue
		var rect = tile_rect(unit["pos"]).grow(-8)
		var texture: Texture2D = unit_textures.get(_texture_key_for_unit(unit))
		if texture != null:
			draw_texture_rect(texture, rect, false)
		else:
			_draw_missing_unit_placeholder(rect, unit)
		_draw_owner_frame(rect, int(unit["pid"]))
		if not bool(unit.get("moved", false)) and not bool(unit.get("done", false)) and int(unit.get("rl", 0)) <= 0:
			var ring_color = PLAYER_COLORS[int(unit["pid"])]
			draw_arc(rect.get_center(), rect.size.x * 0.43, 0.0, TAU, 48, Color(ring_color.r, ring_color.g, ring_color.b, 0.95), max(2.0, _tile_size() * 0.06))
		_draw_unit_status_badges(rect, unit)
		_draw_health_bar(rect, float(unit["hp"]), float(unit["max_hp"]))
		if int(unit["id"]) == selected_unit_id:
			draw_rect(tile_rect(unit["pos"]).grow(-3), Color(1.0, 1.0, 0.2), false, 3.0)
		elif selected_group_unit_ids.has(int(unit["id"])):
			draw_rect(tile_rect(unit["pos"]).grow(-3), Color(0.15, 0.82, 1.0), false, 3.0)

func _draw_group_selection_box() -> void:
	if not box_selecting:
		return
	var box = Rect2(box_select_start, box_select_current - box_select_start).abs()
	var color = Color(0.72, 0.28, 1.0) if box_select_for_formation else Color(0.15, 0.72, 1.0)
	draw_rect(box, Color(color.r, color.g, color.b, 0.12), true)
	draw_rect(box, Color(color.r, color.g, color.b, 0.95), false, 2.0)

func _texture_key_for_unit(unit: Dictionary) -> String:
	var unit_type = str(unit.get("type", ""))
	var equip_name = str(unit.get("equip", ""))
	if not equip_name.is_empty():
		var equip_key = "%s-%s" % [unit_type, equip_name]
		if unit_textures.has(equip_key) and unit_textures[equip_key] != null:
			return equip_key
	return unit_type

func _unit_era(unit: Dictionary) -> int:
	if unit.has("era"):
		return _parse_era_value(unit.get("era", 1))
	var data: Dictionary = db.unit_data(str(unit.get("type", ""))) if db != null else {}
	if data.has("era"):
		return _parse_era_value(data.get("era", 1))
	return int(UNIT_ERA_BY_NAME.get(str(unit.get("type", "")), 1))

func _parse_era_value(value) -> int:
	var text = str(value).to_upper()
	if text.begins_with("E"):
		text = text.trim_prefix("E")
	return clampi(int(text), 1, 5)

func _unit_short_name(unit: Dictionary) -> String:
	var unit_type = str(unit.get("type", "单位"))
	if UNIT_SHORT_NAMES.has(unit_type):
		return str(UNIT_SHORT_NAMES[unit_type])
	return unit_type.substr(0, mini(3, unit_type.length()))

func _draw_missing_unit_placeholder(rect: Rect2, unit: Dictionary) -> void:
	var pid = clampi(int(unit.get("pid", 0)), 0, PLAYER_COLORS.size() - 1)
	var color: Color = PLAYER_COLORS[pid]
	draw_rect(rect, Color(0.035, 0.045, 0.055, 0.94), true)
	draw_rect(rect.grow(-2.0), Color(color.r, color.g, color.b, 0.20), true)
	var era_size = int(clampf(10.0 * zoom, 8.0, 13.0))
	var name_size = int(clampf(14.0 * zoom, 10.0, 18.0))
	var era_text = "E%d" % _unit_era(unit)
	var short_name = _unit_short_name(unit)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(3.0, max(era_size + 1.0, rect.size.y * 0.30)), era_text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6.0, era_size, Color(0.84, 0.89, 0.95))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(2.0, rect.size.y * 0.76), short_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 4.0, name_size, Color.WHITE)

func _draw_missing_building_placeholder(rect: Rect2, building: Dictionary) -> void:
	var pid = int(building.get("pid", -1))
	var color = Color(0.72, 0.72, 0.68) if pid < 0 else PLAYER_COLORS[clampi(pid, 0, PLAYER_COLORS.size() - 1)]
	draw_rect(rect, Color(0.09, 0.085, 0.07, 0.96), true)
	draw_rect(rect.grow(-2.0), Color(color.r, color.g, color.b, 0.18), true)
	var era = clampi(int(building.get("era", building.get("tier", 0) + 1)), 1, 5)
	var name = "总部" if str(building.get("type", "")) == "大本营" else ("据点" if str(building.get("type", "")) == "据点" else "建筑")
	var font_size = int(clampf(12.0 * zoom, 9.0, 16.0))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(2.0, rect.size.y * 0.38), "E%d" % era, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 4.0, font_size, Color(0.88, 0.90, 0.92))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(2.0, rect.size.y * 0.76), name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 4.0, font_size, Color.WHITE)

func _unit_status_labels(unit: Dictionary) -> Array[String]:
	var labels: Array[String] = []
	if int(unit.get("rl", unit.get("reload_left", 0))) > 0:
		labels.append("装%d" % int(unit.get("rl", unit.get("reload_left", 0))))
	_append_status_if(labels, unit, ["marked", "is_marked", "marked_turns"], "标")
	_append_status_if(labels, unit, ["charged", "charge_ready", "charging"], "冲")
	_append_status_if(labels, unit, ["flanking", "is_flanking"], "侧")
	_append_status_if(labels, unit, ["concealed", "hidden", "stealthed"], "隐")
	_append_status_if(labels, unit, ["jammed", "interfered", "jammed_turns"], "扰")
	_append_status_if(labels, unit, ["garrisoned", "garrisoning"], "驻")
	var marks = unit.get("marked_by", {})
	if marks is Dictionary:
		for expiry in marks.values():
			if state == null or int(expiry) >= int(state.turn):
				if not labels.has("标"):
					labels.append("标")
				break
	if state != null and state.has_method("_is_jammed") and bool(state.call("_is_jammed", int(unit.get("pid", -1)), unit.get("pos", Vector2i.ZERO))):
		if not labels.has("扰"):
			labels.append("扰")
	if state != null and state.has_method("_equipment_for_unit") and not bool(unit.get("moved", false)):
		var equip: Dictionary = state.call("_equipment_for_unit", unit)
		if int(equip.get("conceal_distance", 0)) > 0 and not labels.has("隐"):
			labels.append("隐")
	var raw_status = unit.get("statuses", unit.get("status", []))
	if raw_status is Dictionary:
		for key in raw_status.keys():
			_add_named_status(labels, str(key), raw_status[key])
	elif raw_status is Array:
		for entry in raw_status:
			_add_named_status(labels, str(entry), true)
	if labels.is_empty():
		if bool(unit.get("done", false)):
			labels.append("已")
		elif bool(unit.get("moved", false)):
			labels.append("移")
	return labels.slice(0, 3)

func _append_status_if(labels: Array[String], unit: Dictionary, keys: Array[String], label: String) -> void:
	for key in keys:
		if unit.has(key) and _status_value_active(unit[key]):
			if not labels.has(label):
				labels.append(label)
			return

func _status_value_active(value) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return float(value) > 0.0
	return not str(value).is_empty()

func _add_named_status(labels: Array[String], status_name: String, value) -> void:
	if not _status_value_active(value):
		return
	var normalized = status_name.to_lower()
	var label = ""
	if normalized.contains("mark") or status_name.contains("标记"):
		label = "标"
	elif normalized.contains("charg") or status_name.contains("冲锋"):
		label = "冲"
	elif normalized.contains("flank") or status_name.contains("侧击"):
		label = "侧"
	elif normalized.contains("conceal") or normalized.contains("hidden") or status_name.contains("隐蔽"):
		label = "隐"
	elif normalized.contains("jam") or normalized.contains("interfer") or status_name.contains("干扰"):
		label = "扰"
	elif normalized.contains("garrison") or status_name.contains("驻扎"):
		label = "驻"
	elif normalized.contains("reload") or status_name.contains("装填"):
		label = "装"
	if not label.is_empty() and not labels.has(label):
		labels.append(label)

func _draw_unit_status_badges(rect: Rect2, unit: Dictionary) -> void:
	var labels = _unit_status_labels(unit)
	if labels.is_empty():
		return
	var badge_size = clampf(13.0 * zoom, 10.0, 17.0)
	var font_size = int(clampf(9.0 * zoom, 7.0, 11.0))
	for i in range(labels.size()):
		var badge = Rect2(rect.position + Vector2(rect.size.x - badge_size, float(i) * (badge_size + 1.0)), Vector2(badge_size, badge_size))
		draw_rect(badge, Color(0.02, 0.025, 0.035, 0.92), true)
		draw_rect(badge, Color(0.95, 0.76, 0.25, 0.95), false, 1.0)
		draw_string(ThemeDB.fallback_font, badge.position + Vector2(1.0, badge.size.y - 2.0), labels[i], HORIZONTAL_ALIGNMENT_CENTER, badge.size.x - 2.0, font_size, Color(1.0, 0.92, 0.62))

func _building_status_labels(building: Dictionary) -> Array[String]:
	var labels: Array[String] = []
	if bool(building.get("under_construction", false)):
		labels.append("建%d" % int(building.get("build_timer", 0)))
	if bool(building.get("upgrading", false)):
		labels.append("升%d" % int(building.get("up_timer", 0)))
	if str(building.get("type", "")) == "据点" and state != null:
		var age = int(state.turn) - int(building.get("capture_turn", -99))
		if age <= 1:
			labels.append("断")
		elif age == 2:
			labels.append("复")
	return labels

func _draw_building_status_badges(rect: Rect2, building: Dictionary) -> void:
	var labels = _building_status_labels(building)
	if labels.is_empty():
		return
	var font_size = int(clampf(9.0 * zoom, 7.0, 11.0))
	var badge_height = clampf(13.0 * zoom, 10.0, 16.0)
	var text = "/".join(labels)
	var badge = Rect2(rect.position + Vector2(1.0, 1.0), Vector2(max(22.0, rect.size.x - 2.0), badge_height))
	draw_rect(badge, Color(0.03, 0.035, 0.045, 0.90), true)
	draw_string(ThemeDB.fallback_font, badge.position + Vector2(2.0, badge.size.y - 2.0), text, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x - 4.0, font_size, Color(1.0, 0.87, 0.50))

func _draw_fog() -> void:
	if not state.fog_enabled:
		return
	var viewer = _view_player()
	var visible = _visible_tile_rect()
	for y in range(visible.position.y, visible.end.y):
		for x in range(visible.position.x, visible.end.x):
			var pos = Vector2i(x, y)
			if state.is_visible(viewer, pos):
				continue
			var alpha = 0.72 if not state.is_explored(viewer, pos) else 0.42
			draw_rect(tile_rect(pos), Color(0.02, 0.025, 0.04, alpha), true)

func _draw_owner_frame(rect: Rect2, pid: int) -> void:
	if pid < 0:
		draw_rect(rect, Color(0.85, 0.85, 0.85), false, 2.0)
		return
	draw_rect(rect, PLAYER_COLORS[pid], false, 3.0)

func _draw_health_bar(rect: Rect2, hp: float, max_hp: float) -> void:
	var ratio = clampf(hp / max(0.1, max_hp), 0.0, 1.0)
	var bar = Rect2(rect.position + Vector2(0, rect.size.y + 2), Vector2(rect.size.x, max(3.0, _tile_size() * 0.06)))
	draw_rect(bar, Color(0, 0, 0, 0.65), true)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color(0.2, 0.9, 0.25), true)

func _draw_grid() -> void:
	var size = _tile_size()
	var visible = _visible_tile_rect()
	for x in range(visible.position.x, visible.end.x + 1):
		draw_line(camera_offset + Vector2(x * size, visible.position.y * size), camera_offset + Vector2(x * size, visible.end.y * size), Color(0, 0, 0, 0.35), 1.0)
	for y in range(visible.position.y, visible.end.y + 1):
		draw_line(camera_offset + Vector2(visible.position.x * size, y * size), camera_offset + Vector2(visible.end.x * size, y * size), Color(0, 0, 0, 0.35), 1.0)

func _draw_overlay_label(tiles: Array[Vector2i], label: String, color: Color) -> void:
	var min_x = state.width
	var max_x = 0
	var min_y = state.height
	for pos in tiles:
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_y = min(min_y, pos.y)
	var label_tile = Vector2i((min_x + max_x) / 2, max(0, min_y - 1))
	var rect = tile_rect(label_tile)
	var text_width = max(72.0, float(label.length()) * 13.0)
	var box = Rect2(Vector2(rect.get_center().x - text_width * 0.5 - 5.0, rect.position.y - 24.0), Vector2(text_width + 10.0, 20.0))
	draw_rect(box, Color(0.02, 0.02, 0.04, 0.75), true)
	draw_string(ThemeDB.fallback_font, Vector2(box.position.x + 5.0, box.position.y + 15.0), label, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 10.0, 13, color)

func _visible_tile_rect() -> Rect2i:
	var size = _tile_size()
	var top_left = (-camera_offset / size).floor()
	var bottom_right = ((viewport_size - camera_offset) / size).ceil()
	var x0 = clampi(int(top_left.x) - 1, 0, state.width)
	var y0 = clampi(int(top_left.y) - 1, 0, state.height)
	var x1 = clampi(int(bottom_right.x) + 1, 0, state.width)
	var y1 = clampi(int(bottom_right.y) + 1, 0, state.height)
	return Rect2i(Vector2i(x0, y0), Vector2i(max(0, x1 - x0), max(0, y1 - y0)))

