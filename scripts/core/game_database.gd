extends RefCounted
class_name GameDatabase

const DATA_PATH = "res://data/game_data.json"
const ART_MANIFEST_PATH = "res://data/art_manifest.json"

var terrain: Dictionary = {}
var eras: Dictionary = {}
var units: Dictionary = {}
var side_units: Dictionary = {}
var buildings: Dictionary = {}
var techs: Dictionary = {}
var technologies: Dictionary = {}
var equipment: Dictionary = {}
var side_equipment: Dictionary = {}
var strategic_techs: Dictionary = {}
var production: Dictionary = {}
var unit_routes: Dictionary = {}
var unit_aliases: Dictionary = {}
var command: Dictionary = {}
var economy: Dictionary = {}
var rules: Dictionary = {}
var meta: Dictionary = {}
var audio: Dictionary = {}
var art: Dictionary = {}
var unit_order: Array[String] = []


func load_data() -> void:
	var file = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open game data: %s" % DATA_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid game data JSON")
		return
	meta = parsed.get("meta", {})
	rules = parsed.get("rules", {})
	terrain = parsed.get("terrain", {})
	eras = parsed.get("eras", {})
	techs = parsed.get("techs", {})
	technologies = parsed.get("technologies", {})
	equipment = parsed.get("equipment", {})
	side_equipment = parsed.get("side_equipment", {})
	strategic_techs = parsed.get("strategic_techs", {})
	units = parsed.get("units", {})
	side_units = parsed.get("side_units", {})
	unit_aliases = parsed.get("unit_aliases", {})
	unit_routes = parsed.get("unit_routes", {})
	buildings = parsed.get("buildings", {})
	production = parsed.get("production", {})
	command = parsed.get("command", {})
	economy = parsed.get("economy", {})
	audio = parsed.get("audio", {})
	_load_art_manifest()
	for unit_type in equipment.keys():
		for item in equipment[unit_type]:
			if not item.has("tier"):
				item["tier"] = int(_era_id(item.get("era", "E1")).substr(1))
	unit_order.clear()
	for era_id in era_ids():
		for unit_type in units_for_era(era_id):
			if not unit_order.has(unit_type):
				unit_order.append(unit_type)
	for key in units.keys():
		var unit_type := str(key)
		if not unit_order.has(unit_type):
			unit_order.append(unit_type)


func _load_art_manifest() -> void:
	art.clear()
	var file := FileAccess.open(ART_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_warning("Cannot open art manifest: %s" % ART_MANIFEST_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid art manifest JSON")
		return
	art = parsed


func _era_id(value: Variant) -> String:
	if value is int or value is float:
		return "E%d" % clampi(int(value), 1, 5)
	var text := str(value).strip_edges().to_upper()
	if text.begins_with("T"):
		text = "E" + text.substr(1)
	if text.is_valid_int():
		text = "E%d" % clampi(text.to_int(), 1, 5)
	return text


func _tier_id(value: Variant) -> String:
	var era_id := _era_id(value)
	return "T" + era_id.substr(1) if era_id.begins_with("E") else str(value)


func _resolved_unit_type(unit_type: String) -> String:
	return str(unit_aliases.get(unit_type, unit_type))


func era_ids() -> Array[String]:
	var result: Array[String] = []
	for index in range(1, 6):
		var era_id := "E%d" % index
		if eras.has(era_id):
			result.append(era_id)
	return result


func era_data(era: Variant) -> Dictionary:
	return eras.get(_era_id(era), {})


func era_for_round(round_number: int) -> String:
	if round_number >= int(meta.get("grand_war_round", 35)):
		return "E5"
	var active := "E1"
	for era_id in era_ids():
		if round_number >= int(era_data(era_id).get("open_round", 1)):
			active = era_id
	return active


func era_open_round(era: Variant) -> int:
	return int(era_data(era).get("open_round", 1))


func unit_data(unit_type: String) -> Dictionary:
	var resolved := _resolved_unit_type(unit_type)
	return units.get(resolved, side_units.get(resolved, {}))


func side_unit_data(unit_type: String) -> Dictionary:
	return side_units.get(_resolved_unit_type(unit_type), {})


func all_unit_types(include_side_units: bool = false) -> Array[String]:
	var result := unit_order.duplicate()
	if include_side_units:
		for key in side_units.keys():
			var unit_type := str(key)
			if not result.has(unit_type):
				result.append(unit_type)
	return result


func units_for_era(era: Variant) -> Array:
	return era_data(era).get("units", [])


func units_for_route(route: String) -> Array:
	return unit_routes.get(route, [])


func route_for_unit(unit_type: String) -> String:
	return str(unit_data(unit_type).get("route", ""))


func next_unit_in_route(unit_type: String) -> String:
	var resolved := _resolved_unit_type(unit_type)
	var route: Array = units_for_route(route_for_unit(resolved))
	var index := route.find(resolved)
	return str(route[index + 1]) if index >= 0 and index + 1 < route.size() else ""


func unit_upgrade_cost(unit_type: String) -> float:
	var next_type := next_unit_in_route(unit_type)
	return float(unit_data(next_type).get("upgrade_cost", 0.0)) if not next_type.is_empty() else 0.0


func building_data(building_type: String) -> Dictionary:
	return buildings.get(building_type, {})


func building_stats(building_type: String, era: Variant = "E1", branch: String = "base") -> Dictionary:
	var data := building_data(building_type)
	if data.is_empty():
		return {}
	var era_id := _era_id(era)
	if data.has("tiers"):
		var index := clampi(int(era_id.substr(1)) - 1, 0, data.get("tiers", []).size() - 1)
		return data.get("tiers", [])[index]
	if data.has("eras"):
		var era_stats: Dictionary = data.get("eras", {}).get(era_id, {})
		if building_type == "据点":
			return era_stats.get(branch, era_stats.get("base", {}))
		return era_stats
	return data


func terrain_data(terrain_id: String) -> Dictionary:
	return terrain.get(terrain_id, terrain.get("plain", {}))


func technology_data(technology_id: String) -> Dictionary:
	if technologies.has(technology_id):
		return technologies[technology_id]
	for value in technologies.values():
		if str(value.get("name", "")) == technology_id:
			return value
	return techs.get(technology_id, {})


func technologies_for_era(era: Variant) -> Array:
	var result: Array = []
	var era_id := _era_id(era)
	for technology_id in technologies.keys():
		var data: Dictionary = technologies[technology_id]
		if str(data.get("era", "")) == era_id:
			var entry := data.duplicate(true)
			entry["id"] = str(technology_id)
			result.append(entry)
	return result


func technology_unlocking(target: String) -> String:
	for technology_id in technologies.keys():
		var data: Dictionary = technologies[technology_id]
		for unlocked in data.get("unlocks", []):
			if str(unlocked) == target:
				return str(technology_id)
	return ""


func texture_path_for_unit(unit_type: String) -> String:
	var data := unit_data(unit_type)
	var unit_art: Dictionary = art.get("units", {})
	return str(unit_art.get(str(data.get("id", "")), data.get("texture", "")))


func texture_path_for_equipment(item: Dictionary) -> String:
	var equipment_art: Dictionary = art.get("equipment", {})
	return str(equipment_art.get(str(item.get("id", "")), item.get("texture", "")))


func texture_path_for_building(building_type: String, era: Variant = "E1", branch: String = "base") -> String:
	var era_id := _era_id(era)
	var key := ""
	match building_type:
		"大本营": key = "hq:%s" % era_id
		"据点": key = "outpost:%s:%s" % [era_id, branch]
		"资源采集器": key = "collector:%s" % era_id
		"防御工事": key = "fortification:%s" % era_id
	var building_art: Dictionary = art.get("buildings", {})
	if not key.is_empty() and building_art.has(key):
		return str(building_art[key])
	var stats := building_stats(building_type, era, branch)
	return str(stats.get("texture", building_data(building_type).get("texture", "")))


func building_texture_catalog() -> Dictionary:
	return art.get("buildings", {}).duplicate()


func art_paths() -> Array[String]:
	var result: Array[String] = []
	for section_name in ["units", "equipment", "buildings"]:
		for path in art.get(section_name, {}).values():
			result.append(str(path))
	return result


func texture_path_for_terrain(terrain_id: String) -> String:
	return str(terrain_data(terrain_id).get("texture", ""))


func production_for(building_type: String, tier_or_era: String) -> Array:
	var table: Dictionary = production.get(building_type, {})
	if table.has(tier_or_era):
		return table[tier_or_era]
	var era_id := _era_id(tier_or_era)
	if table.has(era_id):
		return table[era_id]
	return table.get(_tier_id(era_id), [])


func equipment_for(unit_type: String) -> Array:
	var resolved := _resolved_unit_type(unit_type)
	return equipment.get(resolved, side_equipment.get(resolved, []))


func equipment_data(unit_type: String, equipment_name_or_id: String) -> Dictionary:
	for item in equipment_for(unit_type):
		if str(item.get("name", "")) == equipment_name_or_id or str(item.get("id", "")) == equipment_name_or_id:
			return item
	return {}


func command_capacity_for_era(era: Variant) -> int:
	var era_id := _era_id(era)
	return int(command.get("base_capacity", {}).get(era_id, era_data(era_id).get("command_capacity", 0)))


func command_cost_for_unit(unit_type: String) -> int:
	var data := unit_data(unit_type)
	if data.has("command_cost"):
		return int(data["command_cost"])
	return int(command.get("route_cost", {}).get(str(data.get("route", "")), 1))


func logistics_multiplier_for_era(era: Variant) -> float:
	var era_id := _era_id(era)
	return float(economy.get("logistics_multiplier", {}).get(era_id, era_data(era_id).get("logistics_multiplier", 1.0)))


func collector_income(collector_number: int, era: Variant) -> float:
	if collector_number < 1:
		return 0.0
	var base := float(economy.get("collector_base_income", 4.5))
	var decay := float(economy.get("collector_decay", 0.8))
	return base * pow(decay, collector_number - 1) * logistics_multiplier_for_era(era)
