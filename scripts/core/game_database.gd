extends RefCounted
class_name GameDatabase

const DATA_PATH = "res://data/game_data.json"

var terrain: Dictionary = {}
var units: Dictionary = {}
var buildings: Dictionary = {}
var techs: Dictionary = {}
var equipment: Dictionary = {}
var strategic_techs: Dictionary = {}
var production: Dictionary = {}
var audio: Dictionary = {}
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
	terrain = parsed.get("terrain", {})
	techs = parsed.get("techs", {})
	equipment = parsed.get("equipment", {})
	strategic_techs = parsed.get("strategic_techs", {})
	units = parsed.get("units", {})
	buildings = parsed.get("buildings", {})
	production = parsed.get("production", {})
	audio = parsed.get("audio", {})
	unit_order.clear()
	for key in units.keys():
		unit_order.append(str(key))

func unit_data(unit_type: String) -> Dictionary:
	return units.get(unit_type, {})

func building_data(building_type: String) -> Dictionary:
	return buildings.get(building_type, {})

func terrain_data(terrain_id: String) -> Dictionary:
	return terrain.get(terrain_id, terrain.get("plain", {}))

func texture_path_for_unit(unit_type: String) -> String:
	return unit_data(unit_type).get("texture", "")

func texture_path_for_building(building_type: String) -> String:
	return building_data(building_type).get("texture", "")

func texture_path_for_terrain(terrain_id: String) -> String:
	return terrain_data(terrain_id).get("texture", "")

func production_for(building_type: String, tier_name: String) -> Array:
	return production.get(building_type, {}).get(tier_name, [])

func equipment_for(unit_type: String) -> Array:
	return equipment.get(unit_type, [])


