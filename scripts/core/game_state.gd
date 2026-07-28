extends RefCounted
class_name GameState

const PLAYER_NAMES = ["红方", "蓝方", "绿方", "黄方"]
const PLAYER_COLORS = [
	Color(0.95, 0.18, 0.22),
	Color(0.25, 0.48, 1.0),
	Color(0.20, 0.78, 0.25),
	Color(1.0, 0.82, 0.22)
]

const RULESET_VERSION = 5
const ERA_NAMES = ["", "E1 部落战争", "E2 冷兵器战争", "E3 火药战争", "E4 机械化战争", "E5 信息化战争"]
const ERA_UNLOCK_TURNS = [0, 1, 14, 28, 43, 59]
const GRAND_WAR_TURN = 75
const ERA_COMMAND_CAP = [0, 22, 24, 26, 28, 30]
const HQ_STATS = [
	{},
	{"hp": 15.0, "armor": 0.0, "gold": 3.0, "vision": 7, "heal": 2.0, "upgrade_cost": 15.0, "upgrade_time": 2},
	{"hp": 26.0, "armor": 1.0, "gold": 5.5, "vision": 8, "heal": 3.5, "upgrade_cost": 27.0, "upgrade_time": 2},
	{"hp": 45.0, "armor": 3.0, "gold": 9.0, "vision": 9, "heal": 6.0, "upgrade_cost": 48.0, "upgrade_time": 3},
	{"hp": 75.0, "armor": 5.0, "gold": 16.0, "vision": 10, "heal": 10.0, "upgrade_cost": 78.0, "upgrade_time": 3},
	{"hp": 112.5, "armor": 8.0, "gold": 25.0, "vision": 12, "heal": 15.0}
]
const OUTPOST_STATS = [
	{},
	{"base": {"hp": 20.0, "armor": 0.0, "gold": 1.0}},
	{"base": {"hp": 34.0, "armor": 0.5, "gold": 1.0}, "combat": {"hp": 51.0, "armor": 1.5, "gold": 1.0, "cost": 10.0, "time": 1}, "economic": {"hp": 34.0, "armor": 0.5, "gold": 3.0, "cost": 12.0, "time": 2}},
	{"base": {"hp": 60.0, "armor": 1.5, "gold": 3.0}, "combat": {"hp": 90.0, "armor": 3.0, "gold": 2.0, "cost": 18.0, "time": 1}, "economic": {"hp": 60.0, "armor": 1.0, "gold": 4.0, "cost": 22.0, "time": 2}},
	{"base": {"hp": 100.0, "armor": 3.0, "gold": 4.0}, "combat": {"hp": 150.0, "armor": 5.0, "gold": 3.0, "cost": 30.0, "time": 1}, "economic": {"hp": 100.0, "armor": 2.0, "gold": 7.0, "cost": 38.0, "time": 2}},
	{"base": {"hp": 150.0, "armor": 5.0, "gold": 6.0}, "combat": {"hp": 225.0, "armor": 8.0, "gold": 4.0, "cost": 45.0, "time": 1}, "economic": {"hp": 150.0, "armor": 3.0, "gold": 10.0, "cost": 58.0, "time": 2}}
]
const LOGISTICS_MULTIPLIER = [0.0, 1.0, 1.1, 1.2, 1.3, 1.4]
const OUTPOST_INCOME_DECAY = [1.0, 0.75, 0.55, 0.40]

const UNIT_ROUTES = {
	"frontline": ["战团", "方阵", "火枪连", "士兵", "网络化步兵"],
	"mobile": ["斥候", "骑兵", "龙骑兵", "主战坦克", "无人战车"],
	"firepower": ["投石队", "弓弩/投石车", "野战炮", "自行火炮", "精确火箭"],
	"support": ["部落侦察", "轻骑侦察", "工兵/观测队", "吉普", "无人机/电子战"]
}
const UNIT_UPGRADE_COSTS = {
	"方阵": 2.25, "火枪连": 1.9, "士兵": 2.2, "网络化步兵": 4.5,
	"骑兵": 4.0, "龙骑兵": 6.5, "主战坦克": 28.0, "无人战车": 17.5,
	"弓弩/投石车": 3.5, "野战炮": 9.0, "自行火炮": 16.5, "精确火箭": 37.5,
	"轻骑侦察": 2.8, "工兵/观测队": 3.5, "吉普": 10.8, "无人机/电子战": 5.5
}
const UNIT_DEFS = {
	"战团": {"era": 1, "role": "frontline", "hp": 1.5, "armor": 0.0, "damage": 1.0, "speed": 3, "range": 1.0, "vision": 4, "price": 1.0, "attacks": 1},
	"斥候": {"era": 1, "role": "mobile", "hp": 1.75, "armor": 0.0, "damage": 1.0, "speed": 5, "range": 1.0, "vision": 5, "price": 1.5, "attacks": 1, "charge_distance": 3.0, "charge_bonus": 0.5},
	"投石队": {"era": 1, "role": "firepower", "hp": 1.0, "armor": 0.0, "damage": 1.0, "speed": 2, "range": 3.0, "vision": 5, "price": 1.5, "attacks": 1},
	"部落侦察": {"era": 1, "role": "support", "hp": 1.0, "armor": 0.0, "damage": 0.5, "speed": 6, "range": 1.0, "vision": 8, "price": 1.0, "attacks": 1, "can_mark": true},
	"方阵": {"era": 2, "role": "frontline", "hp": 5.5, "armor": 0.75, "damage": 2.25, "speed": 2, "range": 1.0, "vision": 5, "price": 3.0, "attacks": 1, "target_mods": {"mobile": 1.5}},
	"骑兵": {"era": 2, "role": "mobile", "hp": 5.5, "armor": 0.25, "damage": 3.0, "speed": 5, "range": 1.0, "vision": 6, "price": 5.0, "attacks": 1, "charge_distance": 4.0, "charge_bonus": 1.5, "charge_straight": true},
	"弓弩/投石车": {"era": 2, "role": "firepower", "hp": 3.5, "armor": 0.0, "damage": 3.5, "speed": 2, "range": 5.0, "min_range": 2.0, "vision": 7, "price": 4.5, "attacks": 1},
	"轻骑侦察": {"era": 2, "role": "support", "hp": 3.5, "armor": 0.25, "damage": 2.0, "speed": 8, "range": 2.0, "vision": 10, "price": 3.5, "attacks": 1, "can_mark": true},
	"火枪连": {"era": 3, "role": "frontline", "hp": 6.5, "armor": 0.5, "damage": 4.5, "speed": 3, "range": 4.0, "vision": 6, "price": 4.0, "attacks": 1},
	"龙骑兵": {"era": 3, "role": "mobile", "hp": 10.0, "armor": 1.0, "damage": 6.0, "speed": 6, "range": 2.0, "vision": 7, "price": 10.0, "attacks": 1, "flank_bonus": 3.0},
	"野战炮": {"era": 3, "role": "firepower", "hp": 9.0, "armor": 1.0, "damage": 12.0, "speed": 2, "range": 7.0, "min_range": 2.0, "vision": 9, "price": 12.0, "attacks": 1, "setup_move_limit": 1.0},
	"工兵/观测队": {"era": 3, "role": "support", "hp": 6.0, "armor": 0.5, "damage": 3.0, "speed": 4, "range": 2.0, "vision": 11, "price": 6.0, "attacks": 1, "can_mark": true, "can_repair": true},
	"士兵": {"era": 4, "role": "frontline", "hp": 7.5, "armor": 0.0, "damage": 5.0, "speed": 3, "range": 2.0, "vision": 5, "price": 5.0, "attacks": 1},
	"主战坦克": {"era": 4, "role": "mobile", "hp": 40.0, "armor": 8.0, "damage": 20.0, "speed": 4, "range": 3.0, "vision": 5, "price": 35.0, "attacks": 1, "tags": ["armored"]},
	"自行火炮": {"era": 4, "role": "firepower", "hp": 15.0, "armor": 5.0, "damage": 25.0, "speed": 3, "range": 6.0, "vision": 9, "price": 25.0, "attacks": 1, "tags": ["armored"]},
	"吉普": {"era": 4, "role": "support", "hp": 15.0, "armor": 0.0, "damage": 10.0, "speed": 8, "range": 3.0, "vision": 11, "price": 15.0, "attacks": 1, "can_mark": true},
	"网络化步兵": {"era": 5, "role": "frontline", "hp": 11.5, "armor": 2.0, "damage": 7.5, "speed": 4, "range": 3.0, "vision": 8, "price": 8.0, "attacks": 1, "shared_vision": true},
	"无人战车": {"era": 5, "role": "mobile", "hp": 48.0, "armor": 10.0, "damage": 24.0, "speed": 5, "range": 4.0, "vision": 7, "price": 45.0, "attacks": 1, "tags": ["armored"], "shared_vision": true},
	"精确火箭": {"era": 5, "role": "firepower", "hp": 25.0, "armor": 2.0, "damage": 36.0, "speed": 3, "range": 14.0, "min_range": 3.0, "vision": 13, "price": 55.0, "attacks": 1, "reload": 1, "shared_vision": true},
	"无人机/电子战": {"era": 5, "role": "support", "hp": 10.0, "armor": 0.0, "damage": 0.0, "speed": 12, "range": 0.0, "vision": 15, "price": 16.0, "attacks": 0, "shared_vision": true, "is_drone": true}
}
const LEGACY_UNIT_ALIASES = {"坦克": "主战坦克", "军用吉普": "吉普"}

var db
var width = 60
var height = 30
var turn = 1
var current_player = 0
var next_unit_id = 1
var next_building_id = 1
var terrain_grid: Array = []
var players: Array[Dictionary] = []
var units: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var game_over = false
var winner = -1
var last_event = ""
var research_notifications: Array[Dictionary] = []
var player_count = 2
var fog_enabled = true

func setup(database, map_width = 60, map_height = 30, count = 2) -> void:
	db = database
	_install_e1_e5_runtime_data()
	width = map_width
	height = map_height
	player_count = clampi(int(count), 2, 4)
	new_game()

func _install_e1_e5_runtime_data() -> void:
	# The vertical slice is intentionally self-contained here so old data files,
	# clients and saves can still be loaded by the existing database facade.
	if db == null:
		return
	if db.units.has("战团") and db.units.has("无人战车"):
		return
	var old_units: Dictionary = db.units.duplicate(true)
	for unit_type in UNIT_DEFS:
		var data: Dictionary = Dictionary(UNIT_DEFS[unit_type]).duplicate(true)
		var texture_source = str(unit_type)
		if unit_type == "主战坦克":
			texture_source = "坦克"
		elif unit_type == "吉普":
			texture_source = "军用吉普"
		elif unit_type == "自行火炮":
			texture_source = "野战炮"
		if old_units.has(texture_source):
			data["texture"] = str(old_units[texture_source].get("texture", ""))
		else:
			data["texture"] = ""
		db.units[unit_type] = data
	for old_name in LEGACY_UNIT_ALIASES:
		var canonical = str(LEGACY_UNIT_ALIASES[old_name])
		var alias_data: Dictionary = Dictionary(db.units[canonical]).duplicate(true)
		if old_units.has(old_name):
			alias_data["texture"] = old_units[old_name].get("texture", "")
		db.units[old_name] = alias_data
	db.unit_order.clear()
	for role in ["frontline", "mobile", "firepower", "support"]:
		for unit_type in UNIT_ROUTES[role]:
			db.unit_order.append(str(unit_type))
	db.production["大本营"] = {}
	for era in range(1, 6):
		var era_units: Array = []
		for role in UNIT_ROUTES:
			era_units.append(UNIT_ROUTES[role][era - 1])
		db.production["大本营"]["T%d" % era] = era_units
	var hq_data: Dictionary = Dictionary(db.buildings.get("大本营", {})).duplicate(true)
	hq_data["tiers"] = []
	for era in range(1, 6):
		hq_data["tiers"].append(Dictionary(HQ_STATS[era]).duplicate(true))
	db.buildings["大本营"] = hq_data
	db.techs = {
		"T1": {"name": ERA_NAMES[1], "cost": 0.0},
		"T2": {"name": ERA_NAMES[2], "cost": 10.0},
		"T3": {"name": ERA_NAMES[3], "cost": 18.0},
		"T4": {"name": ERA_NAMES[4], "cost": 32.0},
		"T5": {"name": ERA_NAMES[5], "cost": 52.0}
	}
	var starlink: Dictionary = Dictionary(db.strategic_techs.get("SpaceX 星链计划", {})).duplicate(true)
	starlink.merge({
		"tier": 5,
		"cost": 85.0,
		"research_time": 3,
		"desc": "全图探索、共享视野与周期卫星扫描。",
		"prerequisites": ["e5_electronic_warfare", "e5_smart_logistics"]
	}, true)
	db.strategic_techs["SpaceX 星链计划"] = starlink
	_install_runtime_equipment()

func _install_runtime_equipment() -> void:
	var entries = {
		"部落侦察": [{"name": "信号号角", "tier": 1, "research_cost": 3.0, "research_time": 1, "cost": 0.5}, {"name": "伪装", "tier": 1, "research_cost": 3.0, "research_time": 1, "cost": 0.5, "conceal_distance": 2}],
		"斥候": [{"name": "骨矛", "tier": 1, "research_cost": 3.0, "research_time": 1, "cost": 0.5, "charge_bonus": 0.75}, {"name": "轻装行囊", "tier": 1, "research_cost": 3.0, "research_time": 1, "cost": 0.5, "speed": 2, "vision": 1, "hp": -0.25}],
		"方阵": [{"name": "长枪阵", "tier": 2, "research_cost": 6.0, "research_time": 1, "cost": 1.5, "range": 1, "target_mods": {"mobile": 1.5}}, {"name": "塔盾阵", "tier": 2, "research_cost": 6.0, "research_time": 1, "cost": 1.5, "armor": 1.0, "dmg": -0.5, "speed": -1}],
		"骑兵": [{"name": "轻骑鞍具", "tier": 2, "research_cost": 6.0, "research_time": 1, "cost": 1.5, "speed": 2, "vision": 2, "hp": -1.0}, {"name": "具装甲胄", "tier": 2, "research_cost": 8.0, "research_time": 2, "cost": 2.5, "armor": 1.5, "hp": 2.0, "speed": -2}],
		"弓弩/投石车": [{"name": "长弓", "tier": 2, "research_cost": 6.0, "research_time": 1, "cost": 1.5, "dmg": 1.0, "range": 2, "speed": -1}, {"name": "配重机构", "tier": 2, "research_cost": 8.0, "research_time": 2, "cost": 2.5, "building_bonus": 4.0, "blast": 1.5, "reload": 1}],
		"火枪连": [{"name": "线膛枪", "tier": 3, "research_cost": 10.0, "research_time": 2, "cost": 2.0, "dmg": 2.0, "range": 2, "speed": -1}, {"name": "刺刀工事包", "tier": 3, "research_cost": 8.0, "research_time": 1, "cost": 2.0, "armor": 1.0, "close_mobile_bonus": 2.0}],
		"龙骑兵": [{"name": "连发卡宾枪", "tier": 3, "research_cost": 12.0, "research_time": 2, "cost": 3.0, "attacks": 2}, {"name": "胸甲", "tier": 3, "research_cost": 12.0, "research_time": 2, "cost": 3.0, "armor": 2.0, "hp": 3.0, "speed": -2}],
		"野战炮": [{"name": "霰弹", "tier": 3, "research_cost": 10.0, "research_time": 2, "cost": 2.0, "dmg": -3.0, "range": -3, "blast": 2.0, "target_mods": {"frontline": 4.0}}, {"name": "实心弹", "tier": 3, "research_cost": 14.0, "research_time": 2, "cost": 4.0, "dmg": 6.0, "building_bonus": 4.0}],
		"工兵/观测队": [{"name": "光学观测镜", "tier": 3, "research_cost": 10.0, "research_time": 2, "cost": 2.0, "vision": 4}, {"name": "爆破工具", "tier": 3, "research_cost": 10.0, "research_time": 2, "cost": 2.0, "close_building_bonus": 10.0, "disable_mark": true}],
		"士兵": [{"name": "射手步枪", "tier": 4, "research_cost": 15.0, "research_time": 1, "cost": 2.5, "dmg": 2.5, "range": 4, "speed": -1, "can_target_air": true}, {"name": "反器械枪", "tier": 4, "research_cost": 25.0, "research_time": 2, "cost": 7.5, "dmg": 20.0, "range": 2, "can_target_air": true}],
		"主战坦克": [{"name": "高爆炮", "tier": 4, "research_cost": 25.0, "research_time": 2, "cost": 5.0, "dmg": -10.0, "blast": 2.0}, {"name": "穿甲炮", "tier": 4, "research_cost": 50.0, "research_time": 3, "cost": 10.0, "dmg": 15.0, "range": 1}],
		"自行火炮": [{"name": "轻量化", "tier": 4, "research_cost": 25.0, "research_time": 2, "cost": 0.0, "dmg": -5.0, "hp": -5.0, "speed": 2}, {"name": "巨炮", "tier": 4, "research_cost": 50.0, "research_time": 3, "cost": 30.0, "dmg": 35.0, "range": 4, "hp": 10.0, "speed": -1}],
		"吉普": [{"name": "重甲吉普", "tier": 4, "research_cost": 15.0, "research_time": 1, "cost": 5.0, "armor": 5.0, "dmg": 2.5, "hp": 2.5, "speed": -2}, {"name": "火箭助推", "tier": 4, "research_cost": 25.0, "research_time": 2, "cost": 5.0, "speed": 5, "hp": 5.0}],
		"网络化步兵": [{"name": "智能反坦克弹", "tier": 5, "research_cost": 40.0, "research_time": 3, "cost": 6.0, "target_mods": {"armored": 24.0}, "reload": 1}, {"name": "自适应迷彩", "tier": 5, "research_cost": 30.0, "research_time": 2, "cost": 4.0, "stationary_armor": 3.0, "vision": 2, "conceal_distance": 3}],
		"无人战车": [{"name": "主动防御系统", "tier": 5, "research_cost": 45.0, "research_time": 3, "cost": 10.0, "active_defense": 15.0}, {"name": "电磁炮", "tier": 5, "research_cost": 50.0, "research_time": 3, "cost": 12.0, "dmg": 16.0, "range": 2, "reload": 1}],
		"精确火箭": [{"name": "钻地弹", "tier": 5, "research_cost": 50.0, "research_time": 3, "cost": 15.0, "building_bonus": 20.0, "building_armor_ignore": 8.0}, {"name": "巡飞子弹药", "tier": 5, "research_cost": 45.0, "research_time": 3, "cost": 12.0, "dmg": -8.0, "blast": 3.0, "target_mods": {"frontline": 10.0}, "reload_add": 1}],
		"无人机/电子战": [{"name": "聚能战斗部", "tier": 5, "research_cost": 35.0, "research_time": 2, "cost": 5.0, "set_damage": 20.0, "set_range": 1.0, "self_destruct": true}, {"name": "干扰吊舱", "tier": 5, "research_cost": 35.0, "research_time": 2, "cost": 5.0, "jam_radius": 6, "jam_vision": 3}]
	}
	for unit_type in entries:
		db.equipment[unit_type] = entries[unit_type]
	# Old public names remain valid for UI actions and old saves.
	db.equipment["坦克"] = db.equipment["主战坦克"]
	db.equipment["军用吉普"] = db.equipment["吉普"]

func new_game() -> void:
	turn = 1
	current_player = 0
	next_unit_id = 1
	next_building_id = 1
	game_over = false
	winner = -1
	research_notifications.clear()
	players = []
	for pid in range(player_count):
		players.append({
			"id": pid,
			"name": PLAYER_NAMES[pid],
			"gold": 12.0,
			"tier": 1,
			"era": 1,
			"researched": ["T1"],
			"technology": [],
			"researching": [],
			"equipment": [],
			"strategic": [],
			"visible": {},
			"explored": {},
			"last_seen": {},
			"alive": true,
			"campaign_advantage": 0,
			"assault_window": 0,
			"satellite_scan_turn": -1,
			"stats": {
				"turn_data": [],
				"total_kill_value": 0.0
			}
		})
	units.clear()
	buildings.clear()
	_generate_terrain()
	_spawn_initial_state()
	_flatten_around_buildings()
	update_vision()

func global_era() -> int:
	for era in range(5, 0, -1):
		if turn >= ERA_UNLOCK_TURNS[era]:
			return era
	return 1

func global_era_name() -> String:
	return ERA_NAMES[global_era()]

func player_era(pid: int) -> int:
	if pid < 0 or pid >= players.size():
		return 1
	return clampi(maxi(int(players[pid].get("era", 1)), int(players[pid].get("tier", 1))), 1, 5)

func is_total_war() -> bool:
	return turn >= GRAND_WAR_TURN

func is_assault_window_active(pid: int) -> bool:
	return pid >= 0 and pid < players.size() and int(players[pid].get("assault_window", 0)) > 0

func unit_role(unit_or_type) -> String:
	var unit_type = str(unit_or_type.get("type", "")) if unit_or_type is Dictionary else str(unit_or_type)
	unit_type = str(LEGACY_UNIT_ALIASES.get(unit_type, unit_type))
	return str(UNIT_DEFS.get(unit_type, {}).get("role", "frontline"))

func unit_era(unit_or_type) -> int:
	var unit_type = str(unit_or_type.get("type", "")) if unit_or_type is Dictionary else str(unit_or_type)
	unit_type = str(LEGACY_UNIT_ALIASES.get(unit_type, unit_type))
	return int(UNIT_DEFS.get(unit_type, {}).get("era", 1))

func command_cost_for(unit_or_type) -> int:
	return 2 if unit_role(unit_or_type) in ["mobile", "firepower"] else 1

func command_used(pid: int) -> int:
	var used = 0
	for unit in units:
		if int(unit.get("pid", -1)) == pid:
			used += command_cost_for(unit)
	return used

func command_capacity(pid: int) -> int:
	var capacity = ERA_COMMAND_CAP[player_era(pid)]
	for building in buildings:
		if int(building.get("pid", -1)) != pid or str(building.get("type", "")) != "据点":
			continue
		if str(building.get("outpost_branch", "")) == "economic" and int(building.get("outpost_tier", 0)) > 0:
			continue
		capacity += 2 if str(building.get("outpost_branch", "")) == "combat" and int(building.get("outpost_tier", 0)) > 0 else 1
	return capacity

func command_capacity_remaining(pid: int) -> int:
	return maxi(0, command_capacity(pid) - command_used(pid))

func _technology_unlocking(target: String) -> String:
	if db != null and db.has_method("technology_unlocking"):
		return str(db.technology_unlocking(target))
	for technology_id in db.technologies.keys():
		if db.technologies[technology_id].get("unlocks", []).has(target):
			return str(technology_id)
	return ""

func _has_technology(pid: int, technology_id: String) -> bool:
	if technology_id.is_empty():
		return true
	if pid < 0 or pid >= players.size():
		return false
	var player: Dictionary = players[pid]
	if player.get("technology", []).has(technology_id) or player.get("researched", []).has(technology_id):
		return true
	var technology = _technology_data(technology_id)
	return not technology.is_empty() and player.get("researched", []).has(str(technology.get("name", technology_id)))

func _target_unlocked(pid: int, target: String) -> bool:
	return _has_technology(pid, _technology_unlocking(target))

func target_unlocked(pid: int, target: String) -> bool:
	return _target_unlocked(pid, target)

func technology_prerequisites(tech_id: String) -> Array[String]:
	var result: Array[String] = []
	var tech = _technology_data(tech_id)
	for prerequisite in tech.get("prerequisites", []):
		result.append(str(prerequisite))
	return result

func missing_technology_prerequisites(pid: int, tech_id: String) -> Array[String]:
	var result: Array[String] = []
	for prerequisite_id in technology_prerequisites(tech_id):
		if not _has_technology(pid, prerequisite_id):
			result.append(prerequisite_id)
	return result

func technology_prerequisites_met(pid: int, tech_id: String) -> bool:
	return missing_technology_prerequisites(pid, tech_id).is_empty()

func _logistics_multiplier(pid: int) -> float:
	var multiplier = 1.0
	for entry in [
		["e2_road_stations", 1.1],
		["e3_industrial_logistics", 1.2],
		["e4_radio_fire_control", 1.3],
		["e5_smart_logistics", 1.4]
	]:
		if _has_technology(pid, str(entry[0])):
			multiplier = max(multiplier, float(entry[1]))
	return multiplier

func _generate_terrain() -> void:
	terrain_grid.clear()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for y in range(height):
		var row = []
		for x in range(width):
			var id = "plain" if rng.randf() < 0.55 else "grass"
			row.append(id)
		terrain_grid.append(row)
	var ridge_count = 2 if player_count >= 3 else 1
	for _i in range(ridge_count):
		var vertical = rng.randf() < 0.5
		var major = height if vertical else width
		var minor = width if vertical else height
		var edge_a = 4 + rng.randi_range(0, max(1, minor - 8))
		var edge_b = 4 + rng.randi_range(0, max(1, minor - 8))
		var amp = 3 + rng.randi_range(0, 4 if player_count >= 3 else 3)
		var amp2 = 1 + rng.randi_range(0, 2)
		var phase = rng.randf() * TAU
		var phase2 = rng.randf() * TAU
		var waves = 1.5 + rng.randf() * 1.5
		var pts: Array[Vector2i] = []
		for a in range(major):
			var t = float(a) / max(1.0, float(major - 1))
			var b = roundi(
				lerpf(float(edge_a), float(edge_b), t)
				+ sin(t * TAU * waves + phase) * float(amp)
				+ sin(t * PI * 6.0 + phase2) * float(amp2)
			)
			b = clampi(b, 2, minor - 3)
			pts.append(Vector2i(b, a) if vertical else Vector2i(a, b))
		_paint_ridge(pts, rng)
		var mirrored: Array[Vector2i] = []
		for p in pts:
			mirrored.append(Vector2i(width - 1 - p.x, height - 1 - p.y))
		_paint_ridge(mirrored, rng)
	_scatter_terrain(rng)

func _paint_ridge(pts: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(pts.size()):
		var center = pts[i]
		var peak_roll = rng.randf()
		var peak = 3 if peak_roll < 0.08 else (2 if peak_roll < 0.26 else 1)
		if i % 4 == 0 and rng.randf() < 0.50:
			continue
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if abs(dx) + abs(dy) > 1:
					continue
				if (dx != 0 or dy != 0) and rng.randf() < 0.55:
					continue
				var pos = center + Vector2i(dx, dy)
				if not in_bounds(pos):
					continue
				var dist = sqrt(float(dx * dx + dy * dy))
				var height_value = peak if dist <= 0.45 else (2 if peak >= 3 else 1)
				_set_terrain_height_if_higher(pos, height_value)

func _scatter_terrain(rng: RandomNumberGenerator) -> void:
	var count = int(width * height / 150)
	for _i in range(count):
		var pos = Vector2i(rng.randi_range(2, max(2, width - 3)), rng.randi_range(2, max(2, height - 3)))
		var roll = rng.randf()
		var height_value = 3 if roll < 0.08 else (2 if roll < 0.28 else 1)
		_set_terrain_height_if_higher(pos, height_value)
		if height_value <= 2 and rng.randf() < 0.45:
			var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			_set_terrain_height_if_higher(pos + dirs[rng.randi_range(0, dirs.size() - 1)], 1)
		if rng.randf() < 0.22:
			var mirror = Vector2i(width - 1 - pos.x, height - 1 - pos.y)
			_set_terrain_height_if_higher(mirror, max(1, height_value - rng.randi_range(0, 1)))

func _set_terrain_height_if_higher(pos: Vector2i, height_value: int) -> void:
	if not in_bounds(pos):
		return
	var current_height = terrain_height(pos)
	if height_value <= current_height:
		return
	if height_value >= 3:
		terrain_grid[pos.y][pos.x] = "mountain"
	elif height_value == 2:
		terrain_grid[pos.y][pos.x] = "highland"
	else:
		terrain_grid[pos.y][pos.x] = "hill"

func _spawn_initial_state() -> void:
	var spawns = _player_spawns()
	for pid in range(player_count):
		var hq_pos: Vector2i = spawns[pid]
		_add_building("大本营", pid, hq_pos, 0)
	for pos in _neutral_outpost_positions(spawns):
		if in_bounds(pos) and occupant_at(pos).is_empty():
			var building = _add_building("据点", -1, pos, 0)
			building["hp"] = max(1.0, float(building.get("max_hp", 1.0)) * 0.5)

func _player_spawns() -> Array[Vector2i]:
	if player_count == 2:
		var mid_y = int(height / 2)
		return [Vector2i(8, mid_y), Vector2i(width - 9, mid_y)]
	if player_count == 3:
		var center_x = int(width / 2)
		var top_y = maxi(6, int(round(height * 0.17)))
		var bottom_y = mini(height - 7, int(round(height * 0.82)))
		var half_span = mini(center_x - 6, int(round((bottom_y - top_y) / sqrt(3.0))))
		return [
			Vector2i(center_x, top_y),
			Vector2i(center_x - half_span, bottom_y),
			Vector2i(center_x + half_span, bottom_y)
		]
	return [
		Vector2i(8, 8),
		Vector2i(width - 9, 8),
		Vector2i(8, height - 9),
		Vector2i(width - 9, height - 9)
	]

func _neutral_outpost_positions(spawns: Array[Vector2i]) -> Array[Vector2i]:
	if player_count == 2:
		var mid_x = int((spawns[0].x + spawns[1].x) / 2)
		var mid_y = int(height / 2)
		var vertical_offset = mini(12, maxi(4, int(height / 3)))
		var horizontal_offset = mini(5, maxi(2, int(width / 10)))
		return [
			Vector2i(mid_x - horizontal_offset, mid_y - vertical_offset),
			Vector2i(mid_x, mid_y),
			Vector2i(mid_x + horizontal_offset, mid_y + vertical_offset)
		]
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	if player_count == 3:
		var centroid = Vector2.ZERO
		for spawn in spawns:
			centroid += Vector2(spawn)
		centroid /= float(spawns.size())
		var inward_ratio = rng.randf_range(0.40, 0.56)
		var positions: Array[Vector2i] = []
		for spawn in spawns:
			positions.append(Vector2i(Vector2(spawn).lerp(centroid, inward_ratio).round()))
		positions.append(Vector2i(centroid.round()))
		return positions
	if player_count == 4:
		var left = spawns[0].x
		var right = spawns[1].x
		var top = spawns[0].y
		var bottom = spawns[2].y
		var inset_x = rng.randi_range(maxi(7, int(width * 0.16)), maxi(8, int(width * 0.27)))
		var inset_y = rng.randi_range(maxi(7, int(height * 0.16)), maxi(8, int(height * 0.27)))
		return [
			Vector2i(left + inset_x, top + inset_y),
			Vector2i(right - inset_x, top + inset_y),
			Vector2i(left + inset_x, bottom - inset_y),
			Vector2i(right - inset_x, bottom - inset_y),
			Vector2i(int((left + right + 1) / 2), int((top + bottom + 1) / 2))
		]
	var positions: Array[Vector2i] = []
	var top_mid = Vector2i(int((spawns[0].x + spawns[1].x) / 2), int((spawns[0].y + spawns[1].y) / 2))
	positions.append(top_mid)
	if player_count > 2:
		positions.append(Vector2i(int(width / 2), int(height / 2)))
	return positions

func _flatten_around_buildings() -> void:
	for building in buildings:
		var center: Vector2i = building["pos"]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var pos = center + Vector2i(dx, dy)
				if in_bounds(pos):
					terrain_grid[pos.y][pos.x] = "plain"

func _nearest_free_tile(origin: Vector2i) -> Vector2i:
	if in_bounds(origin) and occupant_at(origin).is_empty():
		return origin
	for radius in range(1, 5):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				var pos = Vector2i(x, y)
				if in_bounds(pos) and occupant_at(pos).is_empty():
					return pos
	return Vector2i(-1, -1)

func _add_unit(unit_type: String, pid: int, pos: Vector2i) -> Dictionary:
	if not in_bounds(pos) or not occupant_at(pos).is_empty():
		pos = _nearest_free_unit_tile(pos)
		if pos == Vector2i(-1, -1):
			return {}
	var data = db.unit_data(unit_type)
	if data.is_empty() and LEGACY_UNIT_ALIASES.has(unit_type):
		data = db.unit_data(str(LEGACY_UNIT_ALIASES[unit_type]))
	var unit = {
		"id": next_unit_id,
		"type": unit_type,
		"pid": pid,
		"pos": pos,
		"hp": float(data.get("hp", 1.0)),
		"max_hp": float(data.get("hp", 1.0)),
		"armor": float(data.get("armor", 0.0)),
		"speed": int(data.get("speed", 3)),
		"damage": float(data.get("damage", 1.0)),
		"range": float(data.get("range", 1.0)),
		"attacks": int(data.get("attacks", 1)),
		"remaining_attacks": int(data.get("attacks", 1)),
		"moved": false,
		"done": false,
		"is_air": bool(data.get("is_air", false)),
		"can_target_air": bool(data.get("can_target_air", false)),
		"air_damage": float(data.get("air_damage", 0.0)),
		"air_range": float(data.get("air_range", 0.0)),
		"blast": float(data.get("blast", 0.0)),
		"min_range": float(data.get("min_range", 0.0)),
		"vision": int(data.get("vision", 4)),
		"role": str(data.get("role", unit_role(unit_type))),
		"era": int(data.get("era", unit_era(unit_type))),
		"reload": int(data.get("reload", 0)),
		"rl": 0,
		"self_destruct": bool(data.get("self_destruct", false)),
		"applied_equipment": [],
		"equip": "",
		"move_origin": pos,
		"moved_distance": 0.0,
		"facing": Vector2i(0, 0),
		"charge_ready": false,
		"marked_by": {},
		"status": [],
		"aps_used": false,
		"experience": 0.0
	}
	next_unit_id += 1
	units.append(unit)
	return unit

func _add_building(building_type: String, pid: int, pos: Vector2i, tier: int) -> Dictionary:
	if not in_bounds(pos) or not occupant_at(pos).is_empty():
		return {}
	var data = db.building_data(building_type)
	var stats = data
	if data.has("tiers"):
		stats = data["tiers"][tier]
	elif building_type == "据点":
		stats = OUTPOST_STATS[1]["base"]
	var building = {
		"id": next_building_id,
		"type": building_type,
		"pid": pid,
		"pos": pos,
		"tier": tier,
		"hp": float(stats.get("hp", 10.0)),
		"max_hp": float(stats.get("hp", 10.0)),
		"armor": float(stats.get("armor", 0.0)),
		"gold": float(stats.get("gold", 0.0)),
		"captured": pid >= 0,
		"under_construction": false,
		"build_timer": 0,
		"collector_id": -1,
		"outpost_tier": 0,
		"outpost_branch": "",
		"upgrading": false,
		"up_timer": 0,
		"turns_since_damage": 0,
		"damaged_this_turn": false,
		"capture_turn": turn if pid >= 0 else -1,
		"income_recovery": 3 if pid >= 0 else 0,
		"era": 1,
		"strategic_point": building_type == "据点"
	}
	next_building_id += 1
	buildings.append(building)
	return building

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func terrain_at(pos: Vector2i) -> String:
	if not in_bounds(pos):
		return "plain"
	return str(terrain_grid[pos.y][pos.x])

func unit_at(pos: Vector2i) -> Dictionary:
	for unit in units:
		if unit["pos"] == pos:
			return unit
	return {}

func building_at(pos: Vector2i) -> Dictionary:
	for building in buildings:
		if building["pos"] == pos:
			return building
	return {}

func occupant_at(pos: Vector2i) -> Dictionary:
	var unit = unit_at(pos)
	if not unit.is_empty():
		return unit
	return building_at(pos)

func is_unit_blocked(pos: Vector2i) -> bool:
	return not unit_at(pos).is_empty()

func get_unit_by_id(id: int) -> Dictionary:
	for unit in units:
		if unit["id"] == id:
			return unit
	return {}

func _canonical_unit_type(unit_type: String) -> String:
	return str(LEGACY_UNIT_ALIASES.get(unit_type, unit_type))

func _rules_for_unit(unit: Dictionary) -> Dictionary:
	var canonical = _canonical_unit_type(str(unit.get("type", "")))
	return Dictionary(UNIT_DEFS.get(canonical, db.unit_data(str(unit.get("type", "")))))

func _equipment_for_unit(unit: Dictionary) -> Dictionary:
	var equip_name = str(unit.get("equip", ""))
	return _normalized_equipment(equipment_data(str(unit.get("type", "")), equip_name)) if not equip_name.is_empty() else {}

func _normalized_equipment(raw_equip: Dictionary) -> Dictionary:
	if raw_equip.is_empty():
		return {}
	var equip: Dictionary = raw_equip.duplicate(true)
	var effects: Dictionary = equip.get("effects", {})
	var mappings = {
		"vs_building_damage": "building_bonus", "charge_damage": "charge_bonus",
		"mark_duration": "mark_duration", "reveal_distance": "conceal_distance",
		"conceal_beyond": "conceal_distance", "stationary_armor": "stationary_armor",
		"stationary_vision": "stationary_vision", "first_effective_damage_reduction_per_turn": "active_defense",
		"ignore_building_armor": "building_armor_ignore", "radius": "jam_radius",
		"attacks_set": "attacks", "disable_mark": "disable_mark"
	}
	for source_key in mappings:
		if effects.has(source_key) and not equip.has(mappings[source_key]):
			equip[mappings[source_key]] = effects[source_key]
	var target_mods: Dictionary = Dictionary(equip.get("target_mods", {})).duplicate(true)
	for pair in [["vs_mobile_damage", "mobile"], ["vs_armored_damage", "armored"], ["vs_line_damage", "frontline"]]:
		if effects.has(pair[0]): target_mods[pair[1]] = float(effects[pair[0]])
	if not target_mods.is_empty(): equip["target_mods"] = target_mods
	if bool(effects.get("concealed_when_stationary", false)) and not equip.has("conceal_distance"):
		equip["conceal_distance"] = int(effects.get("reveal_distance", 2))
	if bool(effects.get("disable_shared_vision", false)):
		equip["disable_shared_vision"] = true
	return equip

func adjacent_friendly_units(unit: Dictionary, type_filter: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if unit.is_empty():
		return result
	for other in units:
		if other == unit or int(other.get("pid", -1)) != int(unit.get("pid", -1)):
			continue
		var delta: Vector2i = other["pos"] - unit["pos"]
		if maxi(abs(delta.x), abs(delta.y)) != 1:
			continue
		if not type_filter.is_empty() and _canonical_unit_type(str(other.get("type", ""))) != type_filter:
			continue
		result.append(other)
	return result

func effective_unit_stats(unit: Dictionary) -> Dictionary:
	var stats = {
		"damage": float(unit.get("damage", 0.0)),
		"armor": float(unit.get("armor", 0.0)),
		"range": float(unit.get("range", 0.0)),
		"vision": int(unit.get("vision", _rules_for_unit(unit).get("vision", 4)))
	}
	var unit_type = _canonical_unit_type(str(unit.get("type", "")))
	var same_count = mini(2, adjacent_friendly_units(unit, unit_type).size())
	match unit_type:
		"战团":
			stats["damage"] += 0.25 * same_count
		"投石队":
			if not adjacent_friendly_units(unit, "部落侦察").is_empty(): stats["range"] += 1.0
		"方阵":
			stats["armor"] += 0.75 * same_count
		"弓弩/投石车":
			if not adjacent_friendly_units(unit, "方阵").is_empty(): stats["range"] += 1.0
		"火枪连":
			stats["damage"] += 0.5 * same_count
			stats["armor"] += 0.5 * same_count
		"野战炮":
			if not adjacent_friendly_units(unit, "工兵/观测队").is_empty(): stats["range"] += 2.0
		"士兵":
			stats["damage"] += 1.0 * same_count
		"自行火炮":
			if not adjacent_friendly_units(unit, "吉普").is_empty(): stats["range"] += 2.0
		"无人战车":
			stats["armor"] += float(mini(2, adjacent_friendly_units(unit, "无人机/电子战").size()))
	var vision_bonus = 0
	for support in adjacent_friendly_units(unit):
		var support_type = _canonical_unit_type(str(support.get("type", "")))
		if support_type == "部落侦察": vision_bonus = max(vision_bonus, 1)
		elif support_type == "轻骑侦察" and unit_type == "骑兵": vision_bonus = max(vision_bonus, 2)
		elif support_type == "吉普": vision_bonus = max(vision_bonus, 2)
	stats["vision"] += vision_bonus
	var equip = _equipment_for_unit(unit)
	if float(equip.get("stationary_armor", 0.0)) > 0.0 and not bool(unit.get("moved", false)):
		stats["armor"] += float(equip.get("stationary_armor", 0.0))
	if float(equip.get("stationary_vision", 0.0)) > 0.0 and not bool(unit.get("moved", false)):
		stats["vision"] += int(equip.get("stationary_vision", 0))
	return stats

func effective_damage(unit: Dictionary) -> float:
	return float(effective_unit_stats(unit)["damage"])

func effective_armor(unit: Dictionary) -> float:
	return float(effective_unit_stats(unit)["armor"])

func effective_vision(unit: Dictionary) -> int:
	var vision = int(effective_unit_stats(unit)["vision"])
	if _is_jammed(int(unit.get("pid", -1)), unit.get("pos", Vector2i.ZERO)):
		vision -= 3
	return maxi(1, vision)

func is_current_players_unit(unit: Dictionary) -> bool:
	return not unit.is_empty() and int(unit.get("pid", -1)) == current_player and not bool(unit.get("done", false))

func move_tiles_for(unit: Dictionary, ignore_moved: bool = false, ignored_unit_ids: Array[int] = []) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit.is_empty() or (bool(unit.get("moved", false)) and not ignore_moved):
		return result
	var budget = float(unit.get("speed", 0))
	var frontier: Array[Vector2i] = [unit["pos"]]
	var costs = {unit["pos"]: 0.0}
	var dirs = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for dir in dirs:
			var next: Vector2i = current + dir
			if not in_bounds(next):
				continue
			var blocking_unit = unit_at(next)
			if not blocking_unit.is_empty() and not ignored_unit_ids.has(int(blocking_unit.get("id", -1))):
				continue
			if not building_at(next).is_empty():
				continue
			var next_cost = float(costs[current]) + _step_cost(unit, current, next)
			if next_cost > budget:
				continue
			if not costs.has(next) or next_cost < float(costs[next]):
				costs[next] = next_cost
				frontier.append(next)
	for pos in costs.keys():
		if pos != unit["pos"]:
			result.append(pos)
	return result

func move_unit_group(unit_ids: Array[int], target: Vector2i) -> int:
	if not in_bounds(target):
		return 0
	var movable_units: Array[Dictionary] = []
	var movable_ids: Array[int] = []
	var selected_positions: Array[Vector2i] = []
	for unit_id in unit_ids:
		var unit = get_unit_by_id(unit_id)
		if unit.is_empty() or int(unit.get("pid", -1)) != current_player:
			continue
		selected_positions.append(unit["pos"])
		if not is_current_players_unit(unit) or bool(unit.get("moved", false)):
			continue
		movable_units.append(unit)
		movable_ids.append(unit_id)
	if movable_units.is_empty():
		return 0
	var assignments: Dictionary = {}
	var reserved: Dictionary = {}
	var proposals: Array[Dictionary] = []
	for unit in movable_units:
		var reachable = move_tiles_for(unit, false, movable_ids)
		var current_distance = _distance(unit["pos"], target)
		var best_reachable_distance = INF
		for pos in reachable:
			if not selected_positions.has(pos):
				best_reachable_distance = min(best_reachable_distance, _distance(pos, target))
		if current_distance <= best_reachable_distance:
			var current_pos: Vector2i = unit["pos"]
			assignments[int(unit["id"])] = current_pos
			reserved["%d,%d" % [current_pos.x, current_pos.y]] = true
			continue
		for pos in reachable:
			if selected_positions.has(pos):
				continue
			var occupant = unit_at(pos)
			if not occupant.is_empty() and not movable_ids.has(int(occupant.get("id", -1))):
				continue
			proposals.append({
				"unit_id": int(unit["id"]),
				"pos": pos,
				"score": _distance(pos, target) * 1000.0 + _distance(unit["pos"], pos)
			})
	proposals.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["score"]) < float(b["score"]))
	for proposal in proposals:
		var unit_id = int(proposal["unit_id"])
		var pos: Vector2i = proposal["pos"]
		var key = "%d,%d" % [pos.x, pos.y]
		if assignments.has(unit_id) or reserved.has(key):
			continue
		assignments[unit_id] = pos
		reserved[key] = true
	var moved_count = 0
	for unit in movable_units:
		var unit_id = int(unit["id"])
		if not assignments.has(unit_id):
			continue
		var destination: Vector2i = assignments[unit_id]
		if destination == unit["pos"]:
			continue
		if not building_at(destination).is_empty():
			continue
		_record_unit_move(unit, destination)
		unit["pos"] = destination
		unit["moved"] = true
		moved_count += 1
	if moved_count > 0:
		update_vision()
	return moved_count

func attack_targets_for(unit: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit.is_empty() or bool(unit.get("done", false)) or int(unit.get("remaining_attacks", 0)) <= 0 or int(unit.get("rl", 0)) > 0:
		return result
	var rules = _rules_for_unit(unit)
	if float(rules.get("setup_move_limit", INF)) < float(unit.get("moved_distance", 0.0)):
		return result
	var origin: Vector2i = unit["pos"]
	var origin_height = terrain_height(origin)
	var min_range = float(unit.get("min_range", rules.get("min_range", 0.0)))
	for other in units:
		if int(other["pid"]) == int(unit["pid"]):
			continue
		if not is_visible(int(unit["pid"]), other["pos"]):
			continue
		if not _unit_has_direct_vision(unit, other["pos"]) and not is_target_marked(other, int(unit["pid"])) and not shared_vision_available(int(unit["pid"]), unit["pos"], other["pos"]):
			continue
		if bool(other.get("is_air", false)) and not bool(unit.get("can_target_air", false)):
			continue
		var distance = _distance(origin, other["pos"])
		if distance >= min_range and distance <= effective_range(unit, origin_height, terrain_height(other["pos"]), bool(other.get("is_air", false))) + _marked_range_bonus(unit, other):
			result.append(other["pos"])
	for building in buildings:
		if int(building["pid"]) == int(unit["pid"]):
			continue
		if not is_explored(int(unit["pid"]), building["pos"]):
			continue
		var distance = _distance(origin, building["pos"])
		if distance >= min_range and distance <= effective_range(unit, origin_height, terrain_height(building["pos"])) + _marked_range_bonus(unit, building):
			result.append(building["pos"])
	return result

func _unit_has_direct_vision(unit: Dictionary, pos: Vector2i) -> bool:
	var radius = effective_vision(unit) + (0 if bool(unit.get("is_air", false)) else terrain_height(unit["pos"]))
	return _distance(unit["pos"], pos) <= float(radius)

func shared_vision_available(pid: int, receiver_pos: Vector2i = Vector2i(-1, -1), target_pos: Vector2i = Vector2i(-1, -1)) -> bool:
	if pid < 0 or pid >= players.size():
		return false
	if (receiver_pos.x >= 0 and _is_jammed(pid, receiver_pos)) or (target_pos.x >= 0 and _is_jammed(pid, target_pos)):
		return false
	if _has_strategic(pid, "SpaceX 星链计划"):
		return true
	for unit in units:
		if int(unit.get("pid", -1)) == pid and bool(_rules_for_unit(unit).get("shared_vision", false)) and not _is_jammed(pid, unit["pos"]):
			return true
	return false

func attack_range_tiles_for(unit: Dictionary) -> Array[Vector2i]:
	if unit.is_empty():
		var empty: Array[Vector2i] = []
		return empty
	return _attack_range_tiles_from(unit, unit["pos"])

func hover_threat_tiles_for_unit(unit: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit.is_empty():
		return result
	var origin: Vector2i = unit["pos"]
	var radius = float(unit.get("speed", 0)) + max_possible_range_for(unit, origin)
	var bound = ceili(radius)
	for y in range(max(0, origin.y - bound), min(height, origin.y + bound + 1)):
		for x in range(max(0, origin.x - bound), min(width, origin.x + bound + 1)):
			var pos = Vector2i(x, y)
			if _distance(origin, pos) <= radius:
				result.append(pos)
	return result

func max_possible_range_for(unit: Dictionary, origin: Vector2i) -> float:
	if unit.is_empty():
		return 0.0
	var terrain_bonus = 0 if bool(unit.get("is_air", false)) else terrain_height(origin)
	return max(float(effective_unit_stats(unit).get("range", unit.get("range", 0.0))), float(unit.get("air_range", 0.0))) + float(terrain_bonus)

func _attack_range_tiles_from(unit: Dictionary, origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit.is_empty():
		return result
	var origin_height = terrain_height(origin)
	var max_range = max(float(unit.get("range", 1.0)), float(unit.get("air_range", 0.0)))
	max_range += min(3, terrain_height(origin))
	var radius = ceili(max_range + 2.0)
	for y in range(max(0, origin.y - radius), min(height, origin.y + radius + 1)):
		for x in range(max(0, origin.x - radius), min(width, origin.x + radius + 1)):
			var pos = Vector2i(x, y)
			if pos == origin:
				continue
			if _distance(origin, pos) <= effective_range(unit, origin_height, terrain_height(pos)):
				result.append(pos)
	return result

func threat_tiles_against(pid: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen = {}
	for unit in units:
		if int(unit.get("pid", -1)) == pid:
			continue
		if not is_visible(pid, unit["pos"]):
			continue
		var origins: Array[Vector2i] = [unit["pos"]]
		origins.append_array(move_tiles_for(unit, true))
		for origin in origins:
			for pos in _attack_range_tiles_from(unit, origin):
				var key = "%d,%d" % [pos.x, pos.y]
				if seen.has(key):
					continue
				seen[key] = true
				result.append(pos)
	return result

func collector_build_tiles(building: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if building.is_empty() or building.get("type", "") != "大本营":
		return result
	var origin: Vector2i = building["pos"]
	for y in range(max(0, origin.y - 5), min(height, origin.y + 6)):
		for x in range(max(0, origin.x - 5), min(width, origin.x + 6)):
			var pos = Vector2i(x, y)
			if can_build_collector(building, pos):
				result.append(pos)
	return result

func move_unit(unit_id: int, target: Vector2i) -> bool:
	var unit = get_unit_by_id(unit_id)
	if not is_current_players_unit(unit):
		return false
	if not building_at(target).is_empty():
		return false
	if not move_tiles_for(unit).has(target):
		return false
	_record_unit_move(unit, target)
	unit["pos"] = target
	unit["moved"] = true
	update_vision()
	return true

func _record_unit_move(unit: Dictionary, target: Vector2i) -> void:
	var origin: Vector2i = unit.get("pos", target)
	var delta = target - origin
	var distance = _distance(origin, target)
	unit["move_origin"] = origin
	unit["moved_distance"] = distance
	unit["facing"] = Vector2i(signi(delta.x), signi(delta.y))
	var data = _rules_for_unit(unit)
	var threshold = float(data.get("charge_distance", 0.0))
	var straight = delta.x == 0 or delta.y == 0 or abs(delta.x) == abs(delta.y)
	unit["charge_ready"] = threshold > 0.0 and distance >= threshold and (not bool(data.get("charge_straight", false)) or straight)

func skip_unit(unit_id: int) -> bool:
	var unit = get_unit_by_id(unit_id)
	if not is_current_players_unit(unit):
		return false
	unit["moved"] = true
	unit["done"] = true
	unit["remaining_attacks"] = 0
	return true

func can_mark_target(marker: Dictionary, target: Dictionary) -> bool:
	if marker.is_empty() or target.is_empty() or not is_current_players_unit(marker):
		return false
	var rules = _rules_for_unit(marker)
	var equip = _equipment_for_unit(marker)
	if not bool(rules.get("can_mark", false)) or bool(equip.get("disable_mark", false)):
		return false
	if int(target.get("pid", -1)) == int(marker.get("pid", -1)):
		return false
	if _is_jammed(int(marker.get("pid", -1)), marker.get("pos", Vector2i.ZERO)):
		return false
	return is_visible(int(marker["pid"]), target["pos"]) and _distance(marker["pos"], target["pos"]) <= float(effective_vision(marker))

func mark_target(marker_id: int, target_id: int, target_is_building: bool = false) -> bool:
	var marker = get_unit_by_id(marker_id)
	var target = get_building_by_id(target_id) if target_is_building else get_unit_by_id(target_id)
	if not can_mark_target(marker, target):
		return false
	if not target.has("marked_by") or not (target["marked_by"] is Dictionary):
		target["marked_by"] = {}
	var duration = int(_equipment_for_unit(marker).get("mark_duration", 1))
	target["marked_by"][str(marker["pid"])] = turn + duration
	marker["moved"] = true
	marker["done"] = true
	marker["remaining_attacks"] = 0
	last_event = "%s 标记了 %s" % [str(marker.get("type", "单位")), str(target.get("type", "目标"))]
	return true

func is_target_marked(target: Dictionary, pid: int) -> bool:
	if target.is_empty() or _is_jammed(pid, target.get("pos", Vector2i.ZERO)):
		return false
	var marks = target.get("marked_by", {})
	return marks is Dictionary and int(marks.get(str(pid), -1)) >= turn

func _marked_range_bonus(unit: Dictionary, target: Dictionary) -> float:
	if not is_target_marked(target, int(unit.get("pid", -1))):
		return 0.0
	var unit_type = _canonical_unit_type(str(unit.get("type", "")))
	if unit_type == "网络化步兵" or unit_role(unit) == "firepower":
		return 1.0
	return 0.0

func attack(unit_id: int, target_pos: Vector2i) -> bool:
	var unit = get_unit_by_id(unit_id)
	if not is_current_players_unit(unit):
		return false
	if not attack_targets_for(unit).has(target_pos):
		return false
	var target = occupant_at(target_pos)
	if target.is_empty():
		return false
	_apply_damage(target, _effective_attack_damage(unit, target), int(unit["pid"]))
	if float(unit.get("blast", 0.0)) > 0.0:
		_apply_blast(unit, target_pos)
	if bool(unit.get("self_destruct", false)):
		units.erase(unit)
	else:
		unit["charge_ready"] = false
		unit["remaining_attacks"] = int(unit.get("remaining_attacks", 1)) - 1
		unit["moved"] = true
		if int(unit.get("reload", 0)) > 0:
			# Reload is decremented at turn start, so retain one full blocked turn.
			unit["rl"] = int(unit.get("reload", 0)) + 1
		if int(unit["remaining_attacks"]) <= 0:
			unit["done"] = true
	_check_victory()
	update_vision()
	return true

func _apply_damage(target: Dictionary, damage: float, killer_pid: int = -1) -> void:
	if target.has("type") and not target.has("speed"):
		target["damaged_this_turn"] = true
		target["turns_since_damage"] = 0
	target["hp"] = float(target.get("hp", 0.0)) - damage
	if float(target["hp"]) > 0:
		return
	if target.has("type") and target.has("speed"):
		_record_kill_value(killer_pid, str(target.get("type", "")))
		units.erase(target)
	elif str(target.get("type", "")) == "据点" and killer_pid >= 0:
		_capture_defeated_outpost(target, killer_pid)
	else:
		buildings.erase(target)

func _effective_attack_damage(attacker: Dictionary, target: Dictionary, allow_active_defense: bool = true) -> float:
	var raw_damage = _unit_damage_against(attacker, target)
	var armor = effective_armor(target) if target.has("speed") else float(target.get("armor", 0.0))
	var equip = _equipment_for_unit(attacker)
	if not target.has("speed"):
		if is_total_war() and unit_role(attacker) == "firepower":
			raw_damage *= 1.25
		if str(target.get("type", "")) == "大本营" and is_assault_window_active(int(attacker.get("pid", -1))) and unit_role(attacker) == "firepower":
			armor *= 0.5
		armor = max(0.0, armor - float(equip.get("building_armor_ignore", 0.0)))
	var dealt = max(0.0, raw_damage - armor)
	if allow_active_defense and dealt > 0.0 and target.has("speed"):
		var target_equip = _equipment_for_unit(target)
		var reduction = float(target_equip.get("active_defense", 0.0))
		if reduction > 0.0 and not bool(target.get("aps_used", false)):
			dealt = max(0.0, dealt - reduction)
			target["aps_used"] = true
	return dealt

func _capture_defeated_outpost(outpost: Dictionary, new_pid: int) -> void:
	# Outposts change hands instead of being destroyed. A defeated T2 outpost
	# first falls back to its original T1 form, matching the HTML rules.
	outpost["upgrading"] = false
	outpost["up_timer"] = 0
	outpost["outpost_tier"] = 0
	outpost["outpost_branch"] = ""
	var era = player_era(new_pid)
	var stats: Dictionary = OUTPOST_STATS[era]["base"]
	outpost["tier"] = 0
	outpost["max_hp"] = float(stats.get("hp", 20.0))
	outpost["armor"] = float(stats.get("armor", 0.0))
	outpost["gold"] = float(stats.get("gold", 4.5))
	outpost["pid"] = new_pid
	outpost["captured"] = true
	outpost["hp"] = float(outpost["max_hp"]) * 0.5
	outpost["era"] = era
	outpost["capture_turn"] = turn
	outpost["income_recovery"] = 0
	outpost["turns_since_damage"] = 0
	# Preserve the hit marker so the newly captured outpost cannot heal on its
	# first owner turn immediately after being defeated.
	outpost["damaged_this_turn"] = true

func _apply_blast(attacker: Dictionary, center: Vector2i) -> void:
	var radius = float(attacker.get("blast", 0.0))
	var victims: Array[Dictionary] = []
	for unit in units:
		if int(unit["pid"]) == int(attacker["pid"]):
			continue
		if unit["pos"] == center:
			continue
		if _distance(center, unit["pos"]) <= radius:
			victims.append(unit)
	for victim in victims:
		_apply_damage(victim, _effective_attack_damage(attacker, victim), int(attacker["pid"]))
	var damaged_buildings: Array[Dictionary] = []
	for building in buildings:
		if int(building.get("pid", -1)) == int(attacker["pid"]):
			continue
		if building["pos"] == center:
			continue
		if _distance(center, building["pos"]) <= radius:
			damaged_buildings.append(building)
	for building in damaged_buildings:
		_apply_damage(building, _effective_attack_damage(attacker, building), int(attacker["pid"]))

func auto_attack_remaining_units(pid: int) -> int:
	if pid != current_player or game_over:
		return 0
	var attack_count = 0
	var unit_ids: Array[int] = []
	for unit in units:
		if int(unit.get("pid", -1)) == pid:
			unit_ids.append(int(unit["id"]))
	unit_ids.sort()
	for unit_id in unit_ids:
		while not game_over:
			var unit = get_unit_by_id(unit_id)
			if unit.is_empty() or not is_current_players_unit(unit):
				break
			if int(unit.get("remaining_attacks", 0)) <= 0 or int(unit.get("rl", 0)) > 0:
				break
			var target_pos = _best_auto_attack_target(unit)
			if target_pos.x < 0:
				break
			if not attack(unit_id, target_pos):
				break
			attack_count += 1
	if attack_count > 0:
		last_event = "%s 自动完成 %d 次攻击" % [players[pid]["name"], attack_count]
	return attack_count

func _best_auto_attack_target(unit: Dictionary) -> Vector2i:
	var best_pos = Vector2i(-1, -1)
	var best_score = -INF
	for pos in attack_targets_for(unit):
		var target = occupant_at(pos)
		if target.is_empty():
			continue
		var target_pid = int(target.get("pid", -1))
		if target_pid < 0 or target_pid == int(unit.get("pid", -1)):
			continue
		var dealt_damage = _effective_attack_damage(unit, target, false)
		if dealt_damage <= 0.0:
			continue
		var hp = float(target.get("hp", 0.0))
		var lethal_bonus = 6000.0 if hp <= dealt_damage else 0.0
		var score = lethal_bonus - hp
		if target.has("speed"):
			var unit_value = float(db.unit_data(str(target.get("type", ""))).get("price", 0.0))
			score += 2500.0 + unit_value * 100.0 + float(target.get("damage", 0.0)) * 10.0
		else:
			score += 4000.0 if str(target.get("type", "")) == "大本营" else 500.0
		score -= _distance(unit["pos"], pos) * 0.01
		if score > best_score:
			best_score = score
			best_pos = pos
	return best_pos

func end_turn() -> int:
	var automatic_attacks = auto_attack_remaining_units(current_player)
	if game_over:
		return automatic_attacks
	var alive_count = 0
	for player in players:
		if bool(player.get("alive", true)):
			alive_count += 1
	if alive_count <= 1:
		_check_victory()
		return automatic_attacks
	var was = current_player
	for _i in range(players.size()):
		current_player = (current_player + 1) % players.size()
		if bool(players[current_player].get("alive", true)):
			break
	var wrapped = (current_player <= was and was != current_player) or (was == players.size() - 1 and current_player == 0)
	if wrapped:
		turn += 1
		_resolve_campaign_round()
		for pid in range(players.size()):
			if not bool(players[pid].get("alive", true)):
				continue
			for building in buildings:
				if int(building.get("pid", -1)) == pid:
					_tick_building_progress(building)
			_tick_player_research(pid)
			players[pid]["gold"] = float(players[pid]["gold"]) + _income_for(pid)
			_record_turn_stats(pid)
		for building in buildings:
			if int(building.get("pid", -1)) == -1:
				_building_turn_start(building)
	_start_player_turn(current_player)
	update_vision()
	return automatic_attacks

func _start_player_turn(pid: int) -> void:
	for unit in units:
		if int(unit["pid"]) == pid:
			unit["moved"] = false
			unit["done"] = false
			unit["remaining_attacks"] = int(unit.get("attacks", 1))
			unit["move_origin"] = unit["pos"]
			unit["moved_distance"] = 0.0
			unit["charge_ready"] = false
			unit["aps_used"] = false
			if int(unit.get("rl", 0)) > 0:
				unit["rl"] = int(unit.get("rl", 0)) - 1
	for building in buildings:
		if int(building.get("pid", -1)) == pid:
			_building_turn_start(building)

func _building_turn_start(building: Dictionary) -> void:
	if bool(building.get("damaged_this_turn", false)):
		building["turns_since_damage"] = 0
	else:
		building["turns_since_damage"] = int(building.get("turns_since_damage", 0)) + 1
	building["damaged_this_turn"] = false
	if int(building["turns_since_damage"]) < 3 or float(building.get("hp", 0.0)) >= float(building.get("max_hp", 1.0)):
		return
	var building_type = str(building.get("type", ""))
	var owner = int(building.get("pid", -1))
	if owner >= 0 and not _has_technology(owner, "e1_palisade"):
		return
	if is_total_war() and building_type in ["大本营", "据点"]:
		return
	if building_type == "大本营" and _hq_healing_blocked(int(building.get("pid", -1))):
		return
	var heal = 2.0
	if building_type == "大本营":
		heal = float(HQ_STATS[clampi(int(building.get("tier", 0)) + 1, 1, 5)].get("heal", 2.0))
	elif building_type == "据点":
		if turn - int(building.get("capture_turn", -99)) < 3:
			return
		heal = max(2.0, float(building.get("max_hp", 20.0)) * 0.08)
	building["hp"] = min(float(building.get("max_hp", 1.0)), float(building.get("hp", 0.0)) + heal)

func _hq_healing_blocked(pid: int) -> bool:
	for player in players:
		if int(player.get("id", -1)) != pid and is_assault_window_active(int(player.get("id", -1))):
			return true
	return false

func _resolve_campaign_round() -> void:
	for player in players:
		player["assault_window"] = maxi(0, int(player.get("assault_window", 0)) - 1)
	var counts: Dictionary = {}
	for player in players:
		counts[int(player.get("id", -1))] = 0
	for building in buildings:
		if str(building.get("type", "")) == "据点" and bool(building.get("strategic_point", true)) and int(building.get("pid", -1)) >= 0:
			var pid = int(building["pid"])
			counts[pid] = int(counts.get(pid, 0)) + 1
	var leader = -1
	var highest = 1
	var tied = false
	for pid in counts:
		var controlled = int(counts[pid])
		if controlled > highest:
			highest = controlled
			leader = int(pid)
			tied = false
		elif controlled == highest and controlled >= 2:
			tied = true
	if leader < 0 or tied:
		return
	players[leader]["campaign_advantage"] = mini(3, int(players[leader].get("campaign_advantage", 0)) + 1)
	if int(players[leader]["campaign_advantage"]) >= 3:
		players[leader]["campaign_advantage"] = 0
		players[leader]["assault_window"] = 2
		last_event = "%s 发起总攻，窗口持续 2 回合" % players[leader]["name"]

func surrender(pid: int) -> void:
	if pid < 0 or pid >= players.size() or game_over:
		return
	players[pid]["alive"] = false
	last_event = "%s 投降" % players[pid]["name"]
	_check_victory()
	update_vision()

func current_tier_name() -> String:
	return "T%d" % int(players[current_player].get("tier", 1))

func can_produce(building: Dictionary, unit_type: String) -> bool:
	if building.is_empty() or not ["大本营", "据点"].has(str(building.get("type", ""))):
		return false
	if int(building.get("pid", -1)) != current_player:
		return false
	if bool(building.get("under_construction", false)):
		return false
	if not db.unit_data(unit_type):
		return false
	if turn - int(building.get("capture_turn", -99)) <= 1 and str(building.get("type", "")) == "据点":
		return false
	var allowed = available_units_for_player(current_player)
	if not allowed.has(unit_type):
		return false
	var role = unit_role(unit_type)
	var era = unit_era(unit_type)
	if str(building.get("type", "")) == "据点":
		var branch = str(building.get("outpost_branch", ""))
		if branch == "combat" and int(building.get("outpost_tier", 0)) > 0:
			if era != player_era(current_player) or role not in ["frontline", "mobile"]:
				return false
		elif branch == "economic" and int(building.get("outpost_tier", 0)) > 0:
			if role != "frontline" or era != maxi(1, player_era(current_player) - 1):
				return false
		elif role != "frontline" or era < maxi(1, player_era(current_player) - 1):
			return false
	if command_used(current_player) + command_cost_for(unit_type) > command_capacity(current_player):
		return false
	var price = float(db.unit_data(unit_type).get("price", 0.0))
	return float(players[current_player]["gold"]) >= price

func produce_unit(building_id: int, unit_type: String) -> bool:
	var building = get_building_by_id(building_id)
	if not can_produce(building, unit_type):
		return false
	var spawn = _find_spawn_tile(building["pos"])
	if spawn == Vector2i(-1, -1):
		return false
	var price = float(db.unit_data(unit_type).get("price", 0.0))
	players[current_player]["gold"] = float(players[current_player]["gold"]) - price
	var unit = _add_unit(unit_type, current_player, spawn)
	unit["moved"] = true
	unit["done"] = true
	unit["remaining_attacks"] = 0
	update_vision()
	return true

func next_unit_upgrade(unit: Dictionary) -> String:
	if unit.is_empty():
		return ""
	var canonical = _canonical_unit_type(str(unit.get("type", "")))
	var role = unit_role(canonical)
	var route: Array = UNIT_ROUTES.get(role, [])
	var index = route.find(canonical)
	return str(route[index + 1]) if index >= 0 and index + 1 < route.size() else ""

func can_upgrade_unit(unit: Dictionary) -> bool:
	if unit.is_empty() or int(unit.get("pid", -1)) != current_player or bool(unit.get("done", false)):
		return false
	var next_type = next_unit_upgrade(unit)
	if next_type.is_empty() or unit_era(next_type) > player_era(current_player):
		return false
	if not _target_unlocked(current_player, next_type):
		return false
	if not _friendly_garrison_at(unit, true):
		return false
	return float(players[current_player].get("gold", 0.0)) >= float(UNIT_UPGRADE_COSTS.get(next_type, INF))

func upgrade_unit(unit_id: int) -> bool:
	var unit = get_unit_by_id(unit_id)
	if not can_upgrade_unit(unit):
		return false
	var next_type = next_unit_upgrade(unit)
	var cost = float(UNIT_UPGRADE_COSTS[next_type])
	var old_ratio = float(unit.get("hp", 1.0)) / max(0.1, float(unit.get("max_hp", 1.0)))
	var experience = float(unit.get("experience", 0.0))
	players[current_player]["gold"] = float(players[current_player]["gold"]) - cost
	var data: Dictionary = db.unit_data(next_type)
	unit["type"] = next_type
	unit["max_hp"] = float(data.get("hp", 1.0))
	unit["hp"] = max(0.5, float(unit["max_hp"]) * old_ratio)
	unit["armor"] = float(data.get("armor", 0.0))
	unit["speed"] = int(data.get("speed", 3))
	unit["damage"] = float(data.get("damage", 1.0))
	unit["range"] = float(data.get("range", 1.0))
	unit["min_range"] = float(data.get("min_range", 0.0))
	unit["vision"] = int(data.get("vision", 4))
	unit["attacks"] = int(data.get("attacks", 1))
	unit["remaining_attacks"] = 0
	unit["reload"] = int(data.get("reload", 0))
	unit["rl"] = 0
	unit["blast"] = float(data.get("blast", 0.0))
	unit["role"] = str(data.get("role", unit_role(next_type)))
	unit["era"] = int(data.get("era", unit_era(next_type)))
	unit["equip"] = ""
	unit["applied_equipment"] = []
	unit["experience"] = experience
	unit["moved"] = true
	unit["done"] = true
	unit["charge_ready"] = false
	last_event = "%s 进化为 %s" % [players[current_player]["name"], next_type]
	update_vision()
	return true

func _friendly_garrison_at(unit: Dictionary, require_full: bool = false) -> bool:
	if not _has_technology(int(unit.get("pid", -1)), "e1_palisade"):
		return false
	for building in buildings:
		if int(building.get("pid", -1)) != int(unit.get("pid", -1)) or _distance(building["pos"], unit["pos"]) > 1.5:
			continue
		if str(building.get("type", "")) == "大本营":
			return true
		if str(building.get("type", "")) == "据点" and (not require_full or str(building.get("outpost_branch", "")) == "combat"):
			return true
	return false

func garrison_unit(unit_id: int) -> bool:
	var unit = get_unit_by_id(unit_id)
	if not is_current_players_unit(unit) or not _friendly_garrison_at(unit):
		return false
	var ratio = 0.20
	for building in buildings:
		if int(building.get("pid", -1)) == current_player and _distance(building["pos"], unit["pos"]) <= 1.5:
			if str(building.get("type", "")) == "大本营" or str(building.get("outpost_branch", "")) == "combat": ratio = 0.35
			elif str(building.get("outpost_branch", "")) == "economic": ratio = 0.10
	unit["hp"] = min(float(unit.get("max_hp", 1.0)), float(unit.get("hp", 0.0)) + float(unit.get("max_hp", 1.0)) * ratio)
	unit["moved"] = true
	unit["done"] = true
	unit["remaining_attacks"] = 0
	return true

func repair_target(engineer_id: int, target_id: int, target_is_building: bool = false) -> bool:
	var engineer = get_unit_by_id(engineer_id)
	var target = get_building_by_id(target_id) if target_is_building else get_unit_by_id(target_id)
	if not is_current_players_unit(engineer) or target.is_empty() or int(target.get("pid", -1)) != current_player:
		return false
	if not bool(_rules_for_unit(engineer).get("can_repair", false)) or str(engineer.get("equip", "")) == "爆破工具":
		return false
	if _distance(engineer["pos"], target["pos"]) > 1.5 or float(target.get("hp", 0.0)) >= float(target.get("max_hp", 1.0)):
		return false
	target["hp"] = min(float(target.get("max_hp", 1.0)), float(target.get("hp", 0.0)) + float(target.get("max_hp", 1.0)) * 0.20)
	engineer["moved"] = true
	engineer["done"] = true
	engineer["remaining_attacks"] = 0
	return true

func unit_statuses(unit: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if bool(unit.get("charge_ready", false)): result.append("冲锋")
	if int(unit.get("rl", 0)) > 0: result.append("装填 %d" % int(unit["rl"]))
	for expiry in unit.get("marked_by", {}).values():
		if int(expiry) >= turn:
			result.append("已标记")
			break
	if int(_equipment_for_unit(unit).get("conceal_distance", 0)) > 0 and not bool(unit.get("moved", false)): result.append("隐蔽")
	if _is_jammed(int(unit.get("pid", -1)), unit.get("pos", Vector2i.ZERO)): result.append("受干扰")
	if float(_equipment_for_unit(unit).get("active_defense", 0.0)) > 0.0 and not bool(unit.get("aps_used", false)): result.append("主动防御就绪")
	return result

func can_build_collector(building: Dictionary, pos: Vector2i) -> bool:
	if building.is_empty() or building.get("type", "") != "大本营":
		return false
	if int(building.get("pid", -1)) != current_player:
		return false
	if not _has_technology(current_player, "e1_organized_gathering"):
		return false
	var data = db.building_data("资源采集器")
	if not in_bounds(pos) or not occupant_at(pos).is_empty():
		return false
	if _distance(building["pos"], pos) > 5.0:
		return false
	return float(players[current_player]["gold"]) >= float(data.get("cost", 12.0))

func build_collector(building_id: int, pos: Vector2i) -> bool:
	var building = get_building_by_id(building_id)
	if not can_build_collector(building, pos):
		return false
	var data = db.building_data("资源采集器")
	players[current_player]["gold"] = float(players[current_player]["gold"]) - float(data.get("cost", 12.0))
	var collector = _add_building("资源采集器", current_player, pos, 0)
	collector["under_construction"] = true
	collector["build_timer"] = 2
	collector["collector_id"] = _next_collector_id(current_player)
	collector["gold"] = 0.0
	update_vision()
	return true

func get_building_by_id(id: int) -> Dictionary:
	for building in buildings:
		if int(building["id"]) == id:
			return building
	return {}

func available_units_for_player(pid: int) -> Array:
	var tier = player_era(pid)
	var result: Array = []
	for t in range(1, tier + 1):
		for unit_type in db.production_for("大本营", "T%d" % t):
			if not result.has(unit_type) and _target_unlocked(pid, str(unit_type)):
				result.append(unit_type)
	return result

func can_research_next_tier(pid: int) -> bool:
	if pid != current_player:
		return false
	for building in buildings:
		if str(building.get("type", "")) == "大本营" and int(building.get("pid", -1)) == pid:
			return can_upgrade_hq(building)
	return false

func research_next_tier(pid: int) -> bool:
	if pid != current_player:
		return false
	for building in buildings:
		if str(building.get("type", "")) == "大本营" and int(building.get("pid", -1)) == pid:
			return upgrade_hq(int(building["id"]))
	return false

func _set_player_tier_from_hq(pid: int, hq_tier: int) -> void:
	if pid < 0 or pid >= players.size():
		return
	var player_tier = clampi(hq_tier + 1, 1, 5)
	players[pid]["tier"] = max(int(players[pid].get("tier", 1)), player_tier)
	players[pid]["era"] = max(int(players[pid].get("era", 1)), player_tier)
	for tier_id in range(1, int(players[pid]["tier"]) + 1):
		var tech_id = "T%d" % tier_id
		if db.techs.has(tech_id) and not players[pid]["researched"].has(tech_id):
			players[pid]["researched"].append(tech_id)

func can_upgrade_hq(building: Dictionary) -> bool:
	if building.is_empty() or building.get("type", "") != "大本营":
		return false
	if int(building.get("pid", -1)) != current_player:
		return false
	if bool(building.get("upgrading", false)):
		return false
	var tier = int(building.get("tier", 0))
	var data = db.building_data("大本营")
	if tier >= data.get("tiers", []).size() - 1:
		return false
	var next_era = tier + 2
	if turn + 1 < ERA_UNLOCK_TURNS[next_era]:
		return false
	var cost = hq_upgrade_cost(int(building.get("pid", -1)))
	return float(players[current_player]["gold"]) >= cost

func hq_upgrade_cost(pid: int) -> float:
	var era = player_era(pid)
	if era >= 5:
		return INF
	var cost = float(HQ_STATS[era].get("upgrade_cost", 0.0))
	if global_era() - era >= 2:
		cost *= 0.8
	return snapped(cost, 0.01)

func upgrade_hq(building_id: int) -> bool:
	var building = get_building_by_id(building_id)
	if not can_upgrade_hq(building):
		return false
	var tier = int(building.get("tier", 0))
	var cost = hq_upgrade_cost(current_player)
	players[current_player]["gold"] = float(players[current_player]["gold"]) - cost
	building["upgrading"] = true
	building["up_timer"] = int(HQ_STATS[tier + 1].get("upgrade_time", 1))
	building["upgrade_target_era"] = tier + 2
	update_vision()
	return true

func can_upgrade_outpost(building: Dictionary, branch: String) -> bool:
	if building.is_empty() or building.get("type", "") != "据点":
		return false
	if int(building.get("pid", -1)) != current_player:
		return false
	if int(building.get("outpost_tier", 0)) > 0 or bool(building.get("upgrading", false)):
		return false
	if player_era(current_player) < 2:
		return false
	if not ["combat", "economic"].has(branch):
		return false
	var branch_stats: Dictionary = OUTPOST_STATS[player_era(current_player)].get(branch, {})
	return not branch_stats.is_empty() and float(players[current_player]["gold"]) >= float(branch_stats.get("cost", INF))

func upgrade_outpost(building_id: int, branch: String) -> bool:
	var building = get_building_by_id(building_id)
	if not can_upgrade_outpost(building, branch):
		return false
	var branch_stats: Dictionary = OUTPOST_STATS[player_era(current_player)][branch]
	players[current_player]["gold"] = float(players[current_player]["gold"]) - float(branch_stats["cost"])
	building["upgrading"] = true
	building["up_timer"] = int(branch_stats["time"])
	building["outpost_branch"] = branch
	building["upgrade_target_era"] = player_era(current_player)
	return true

func can_research_equipment(pid: int, unit_type: String, equip_name: String) -> bool:
	if pid != current_player:
		return false
	var equip = equipment_data(unit_type, equip_name)
	if equip.is_empty() or players[pid]["equipment"].has(equipment_key(unit_type, equip_name)):
		return false
	if _is_researching(pid, equip_name):
		return false
	if player_era(pid) < int(equip.get("tier", 1)):
		return false
	if not _target_unlocked(pid, _canonical_unit_type(unit_type)):
		return false
	return float(players[pid]["gold"]) >= float(equip.get("research_cost", 0.0))

func _era_number(value) -> int:
	if value is int or value is float:
		return clampi(int(value), 1, 5)
	var text = str(value).to_upper()
	if text.begins_with("E") or text.begins_with("T"):
		text = text.substr(1)
	return clampi(int(text) if text.is_valid_int() else 1, 1, 5)

func _technology_data(tech_id: String) -> Dictionary:
	if db.has_method("technology_data"):
		return db.technology_data(tech_id)
	return db.techs.get(tech_id, {})

func technology_research_terms(pid: int, tech_id: String) -> Dictionary:
	var tech = _technology_data(tech_id)
	if tech.is_empty():
		return {}
	var terms = {
		"cost": float(tech.get("cost", tech.get("research_cost", 0.0))),
		"research_time": int(tech.get("research_time", tech.get("turns", 1))),
		"soft_prerequisite_applied": false
	}
	var soft_prerequisite = tech.get("soft_prerequisite", {})
	if soft_prerequisite is Dictionary:
		var prerequisite_id = str(soft_prerequisite.get("technology", ""))
		if not prerequisite_id.is_empty() and _has_technology(pid, prerequisite_id):
			terms["cost"] = float(soft_prerequisite.get("cost", terms["cost"]))
			terms["research_time"] = int(soft_prerequisite.get("research_time", terms["research_time"]))
			terms["soft_prerequisite_applied"] = true
	return terms

func can_research_technology(pid: int, tech_id: String) -> bool:
	if pid != current_player or pid < 0 or pid >= players.size():
		return false
	var tech = _technology_data(tech_id)
	if tech.is_empty():
		return false
	var name = str(tech.get("name", tech_id))
	if _is_researching(pid, name):
		return false
	if players[pid].get("researched", []).has(tech_id) or players[pid].get("researched", []).has(name):
		return false
	if player_era(pid) < _era_number(tech.get("era", tech.get("tier", 1))):
		return false
	if not technology_prerequisites_met(pid, tech_id):
		return false
	var terms = technology_research_terms(pid, tech_id)
	return float(players[pid].get("gold", 0.0)) >= float(terms.get("cost", INF))

func research_technology(pid: int, tech_id: String) -> bool:
	if not can_research_technology(pid, tech_id):
		return false
	var tech = _technology_data(tech_id)
	var name = str(tech.get("name", tech_id))
	var terms = technology_research_terms(pid, tech_id)
	players[pid]["gold"] = float(players[pid]["gold"]) - float(terms.get("cost", 0.0))
	players[pid]["researching"].append({"name": name, "tech_id": tech_id, "kind": "technology", "timer": int(terms.get("research_time", 1))})
	return true

func can_research_tech(tech_id: String) -> bool:
	return can_research_technology(current_player, tech_id)

func research_tech(tech_id: String) -> bool:
	return research_technology(current_player, tech_id)

func can_research_core_tech(tech_id: String) -> bool:
	return can_research_technology(current_player, tech_id)

func research_core_tech(tech_id: String) -> bool:
	return research_technology(current_player, tech_id)

func can_upgrade_era(pid: int) -> bool:
	return can_research_next_tier(pid)

func upgrade_era(pid: int) -> bool:
	return research_next_tier(pid)

func research_equipment(pid: int, unit_type: String, equip_name: String) -> bool:
	if not can_research_equipment(pid, unit_type, equip_name):
		return false
	var equip = equipment_data(unit_type, equip_name)
	players[pid]["gold"] = float(players[pid]["gold"]) - float(equip.get("research_cost", 0.0))
	players[pid]["researching"].append({
		"name": equip_name,
		"kind": "equipment",
		"unit_type": unit_type,
		"timer": int(equip.get("research_time", 1))
	})
	return true

func equipment_key(unit_type: String, equip_name: String) -> String:
	return "%s:%s" % [unit_type, equip_name]

func equipment_data(unit_type: String, equip_name: String) -> Dictionary:
	for equip in db.equipment_for(unit_type):
		if str(equip.get("name", "")) == equip_name:
			return equip
	var canonical = _canonical_unit_type(unit_type)
	if canonical != unit_type:
		for equip in db.equipment_for(canonical):
			if str(equip.get("name", "")) == equip_name:
				return equip
	return {}

func research_entry(pid: int, name: String) -> Dictionary:
	if pid < 0 or pid >= players.size():
		return {}
	for entry in players[pid].get("researching", []):
		if str(entry.get("name", "")) == name:
			return entry
	return {}

func _is_researching(pid: int, name: String) -> bool:
	return not research_entry(pid, name).is_empty()

func _tick_player_research(pid: int) -> void:
	if pid < 0 or pid >= players.size():
		return
	var remaining = []
	for raw_entry in players[pid].get("researching", []):
		var entry = Dictionary(raw_entry)
		entry["timer"] = max(0, int(entry.get("timer", 0)) - 1)
		if int(entry["timer"]) > 0:
			remaining.append(entry)
			continue
		var name = str(entry.get("name", ""))
		if str(entry.get("kind", "")) == "equipment":
			var unit_type = str(entry.get("unit_type", ""))
			var key = equipment_key(unit_type, name)
			if not players[pid]["equipment"].has(key):
				players[pid]["equipment"].append(key)
		elif str(entry.get("kind", "")) == "strategic":
			if not players[pid]["strategic"].has(name):
				players[pid]["strategic"].append(name)
		elif str(entry.get("kind", "")) == "technology":
			var tech_id = str(entry.get("tech_id", name))
			if not players[pid]["researched"].has(tech_id): players[pid]["researched"].append(tech_id)
			if not players[pid]["researched"].has(name): players[pid]["researched"].append(name)
			if not players[pid].get("technology", []).has(tech_id): players[pid]["technology"].append(tech_id)
		else:
			if not players[pid]["researched"].has(name):
				players[pid]["researched"].append(name)
		last_event = "%s 研究完成：%s" % [players[pid]["name"], name]
		research_notifications.append({"pid": pid, "name": name})
	players[pid]["researching"] = remaining

func take_research_notifications(pid: int) -> Array[String]:
	var names: Array[String] = []
	var remaining: Array[Dictionary] = []
	for notice in research_notifications:
		if int(notice.get("pid", -1)) == pid:
			names.append(str(notice.get("name", "")))
		else:
			remaining.append(notice)
	research_notifications = remaining
	return names

func can_equip_unit(unit: Dictionary, equip_name: String) -> bool:
	if unit.is_empty() or int(unit.get("pid", -1)) != current_player:
		return false
	if not str(unit.get("equip", "")).is_empty():
		return false
	var equip = equipment_data(str(unit.get("type", "")), equip_name)
	if equip.is_empty():
		return false
	if not players[current_player]["equipment"].has(equipment_key(str(unit.get("type", "")), equip_name)):
		return false
	return float(players[current_player]["gold"]) >= float(equip.get("cost", 0.0))

func equip_unit(unit_id: int, equip_name: String) -> bool:
	var unit = get_unit_by_id(unit_id)
	if not can_equip_unit(unit, equip_name):
		return false
	var equip = equipment_data(str(unit.get("type", "")), equip_name)
	players[current_player]["gold"] = float(players[current_player]["gold"]) - float(equip.get("cost", 0.0))
	var old_hp = float(unit.get("hp", 1.0))
	var old_max = max(1.0, float(unit.get("max_hp", 1.0)))
	_apply_equipment_to_unit(unit, equip)
	unit["equip"] = equip_name
	unit["hp"] = min(float(unit.get("max_hp", old_max)), float(unit.get("max_hp", old_max)) * (1.0 + old_hp / old_max) / 2.0)
	update_vision()
	return true

func can_research_strategic(pid: int, tech_name: String) -> bool:
	if pid != current_player:
		return false
	var tech = db.strategic_techs.get(tech_name, {})
	if tech.is_empty() or players[pid]["strategic"].has(tech_name):
		return false
	if _is_researching(pid, tech_name):
		return false
	if player_era(pid) < int(tech.get("tier", 1)):
		return false
	var strategic_id = str(tech.get("id", ""))
	if not strategic_id.is_empty() and not technology_prerequisites_met(pid, strategic_id):
		return false
	return float(players[pid]["gold"]) >= float(tech.get("cost", 0.0))

func research_strategic(pid: int, tech_name: String) -> bool:
	if not can_research_strategic(pid, tech_name):
		return false
	var tech = db.strategic_techs[tech_name]
	players[pid]["gold"] = float(players[pid]["gold"]) - float(tech.get("cost", 0.0))
	players[pid]["researching"].append({
		"name": tech_name,
		"kind": "strategic",
		"timer": int(tech.get("research_time", 1))
	})
	return true

func _find_spawn_tile(origin: Vector2i) -> Vector2i:
	var candidates = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	for offset in candidates:
		var pos = origin + offset
		if in_bounds(pos) and occupant_at(pos).is_empty():
			return pos
	return Vector2i(-1, -1)

func _tick_building_progress(building: Dictionary) -> void:
	if bool(building.get("under_construction", false)):
		building["build_timer"] = max(0, int(building.get("build_timer", 0)) - 1)
		if int(building["build_timer"]) <= 0:
			building["under_construction"] = false
			var collector_id = max(0, int(building.get("collector_id", 0)))
			building["gold"] = collector_income_for_id(collector_id)
	if bool(building.get("upgrading", false)):
		building["up_timer"] = max(0, int(building.get("up_timer", 0)) - 1)
		if int(building["up_timer"]) <= 0:
			if str(building.get("type", "")) == "大本营" and int(building.get("upgrade_target_era", int(building.get("tier", 0)) + 2)) > global_era():
				building["up_timer"] = 1
				return
			building["upgrading"] = false
			if building.get("type", "") == "大本营":
				_finish_hq_upgrade(building)
			elif building.get("type", "") == "据点":
				_finish_outpost_upgrade(building)

func _finish_hq_upgrade(building: Dictionary) -> void:
	var data = db.building_data("大本营")
	var tier = int(building.get("tier", 0))
	if tier >= data.get("tiers", []).size() - 1:
		return
	var old_max = float(building.get("max_hp", 1.0))
	var old_hp = clamp(float(building.get("hp", old_max)), 1.0, old_max)
	var hp_ratio = old_hp / max(1.0, old_max)
	tier += 1
	var stats = data["tiers"][tier]
	building["tier"] = tier
	building["max_hp"] = float(stats.get("hp", old_max))
	building["hp"] = max(1.0, float(building["max_hp"]) * (1.0 + hp_ratio) / 2.0)
	building["armor"] = float(stats.get("armor", 0.0))
	building["gold"] = float(stats.get("gold", 0.0))
	_set_player_tier_from_hq(int(building.get("pid", -1)), tier)

func _finish_outpost_upgrade(building: Dictionary) -> void:
	var old_max = max(1.0, float(building.get("max_hp", 1.0)))
	var old_hp = clamp(float(building.get("hp", old_max)), 1.0, old_max)
	var era = clampi(int(building.get("upgrade_target_era", player_era(int(building.get("pid", -1))))), 2, 5)
	var branch = str(building.get("outpost_branch", "combat"))
	var stats: Dictionary = OUTPOST_STATS[era].get(branch, OUTPOST_STATS[era]["base"])
	building["outpost_tier"] = 1
	building["era"] = era
	building["max_hp"] = float(stats["hp"])
	building["hp"] = float(stats["hp"]) if branch == "combat" else min(float(stats["hp"]), float(stats["hp"]) * (1.0 + old_hp / old_max) / 2.0)
	building["armor"] = float(stats["armor"])
	building["gold"] = float(stats["gold"])

func _next_collector_id(pid: int) -> int:
	var used: Array[int] = []
	for building in buildings:
		if int(building.get("pid", -1)) == pid and building.get("type", "") == "资源采集器":
			used.append(int(building.get("collector_id", -1)))
	var id = 0
	while used.has(id):
		id += 1
	return id

func collector_income_for_id(collector_id: int) -> float:
	return snapped(4.5 * pow(0.8, maxi(0, collector_id)), 0.01)

func next_collector_income(pid: int) -> float:
	return snapped(collector_income_for_id(_next_collector_id(pid)) * _logistics_multiplier(pid), 0.01)

func _apply_researched_equipment_to_unit(unit: Dictionary) -> void:
	var pid = int(unit.get("pid", -1))
	if pid < 0 or pid >= players.size():
		return
	for equip in db.equipment_for(unit["type"]):
		if players[pid]["equipment"].has(equipment_key(unit["type"], str(equip.get("name", "")))):
			_apply_equipment_to_unit(unit, equip)

func _apply_equipment_to_unit(unit: Dictionary, equip: Dictionary) -> void:
	equip = _normalized_equipment(equip)
	var key = str(equip.get("name", ""))
	if not unit.has("applied_equipment"):
		unit["applied_equipment"] = []
	if unit["applied_equipment"].has(key):
		return
	unit["applied_equipment"].append(key)
	unit["damage"] = float(unit.get("damage", 0.0)) + float(equip.get("dmg", 0.0))
	unit["range"] = float(unit.get("range", 0.0)) + float(equip.get("range", 0.0))
	unit["speed"] = int(unit.get("speed", 0)) + int(equip.get("speed", 0))
	unit["armor"] = float(unit.get("armor", 0.0)) + float(equip.get("armor", 0.0))
	unit["vision"] = int(unit.get("vision", _rules_for_unit(unit).get("vision", 4))) + int(equip.get("vision", 0))
	if equip.has("attacks"):
		unit["attacks"] = int(equip.get("attacks", unit.get("attacks", 1)))
		unit["remaining_attacks"] = mini(int(unit.get("remaining_attacks", 0)), int(unit["attacks"]))
	if equip.has("reload"):
		unit["reload"] = int(equip.get("reload", unit.get("reload", 0)))
	if equip.has("reload_add"):
		unit["reload"] = int(unit.get("reload", 0)) + int(equip.get("reload_add", 0))
	if equip.has("set_damage"):
		unit["damage"] = float(equip["set_damage"])
	if equip.has("set_range"):
		unit["range"] = float(equip["set_range"])
	if bool(equip.get("self_destruct", false)):
		unit["self_destruct"] = true
	if equip.has("hp"):
		unit["max_hp"] = max(0.5, float(unit.get("max_hp", 1.0)) + float(equip.get("hp", 0.0)))
		unit["hp"] = min(float(unit["max_hp"]), max(0.5, float(unit.get("hp", 1.0)) + float(equip.get("hp", 0.0))))
	if equip.has("blast"):
		unit["blast"] = float(equip.get("blast", unit.get("blast", 0.0)))
	if bool(equip.get("can_target_air", false)):
		unit["can_target_air"] = true

func _unit_damage_against(unit: Dictionary, target: Dictionary) -> float:
	if bool(target.get("is_air", false)) and float(unit.get("air_damage", 0.0)) > 0.0:
		return float(unit["air_damage"])
	var damage = effective_damage(unit)
	var rules = _rules_for_unit(unit)
	var equip = _equipment_for_unit(unit)
	var target_role = unit_role(target) if target.has("speed") else "building"
	var target_tags: Array = []
	if target.has("speed"):
		target_tags = Array(_rules_for_unit(target).get("tags", []))
	var modifiers: Dictionary = Dictionary(rules.get("target_mods", {})).duplicate(true)
	for key in equip.get("target_mods", {}):
		modifiers[key] = float(modifiers.get(key, 0.0)) + float(equip["target_mods"][key])
	damage += float(modifiers.get(target_role, 0.0))
	for tag in target_tags:
		damage += float(modifiers.get(str(tag), 0.0))
	var unit_type = _canonical_unit_type(str(unit.get("type", "")))
	if unit_type == "斥候" and target_role in ["firepower", "support"]:
		damage += 0.5
	if bool(unit.get("charge_ready", false)):
		damage += float(rules.get("charge_bonus", 0.0)) + float(equip.get("charge_bonus", 0.0))
	if float(rules.get("flank_bonus", 0.0)) > 0.0 and _is_flanking(unit, target):
		damage += float(rules.get("flank_bonus", 0.0))
	if target_role == "mobile" and _distance(unit["pos"], target["pos"]) <= 1.5:
		damage += float(equip.get("close_mobile_bonus", 0.0))
	if target_role == "building":
		damage += float(equip.get("building_bonus", 0.0))
		if _distance(unit["pos"], target["pos"]) <= 1.5:
			damage += float(equip.get("close_building_bonus", 0.0))
	if unit["type"] == "自杀无人机" and players[int(unit["pid"])]["strategic"].has("SpaceX 星链计划"):
		damage += 1.0
	if unit_type == "无人机/电子战" and str(unit.get("equip", "")) == "聚能战斗部" and _has_strategic(int(unit.get("pid", -1)), "SpaceX 星链计划"):
		damage += 5.0
	return damage

func _is_flanking(attacker: Dictionary, target: Dictionary) -> bool:
	if not target.has("speed"):
		return false
	if adjacent_friendly_units(target).is_empty():
		return true
	var facing: Vector2i = target.get("facing", Vector2i.ZERO)
	if facing == Vector2i.ZERO:
		return false
	var toward_attacker = Vector2(attacker["pos"] - target["pos"]).normalized()
	return toward_attacker.dot(Vector2(facing).normalized()) < -0.35

func _has_strategic(pid: int, tech_name: String) -> bool:
	return pid >= 0 and pid < players.size() and players[pid].get("strategic", []).has(tech_name)

func _record_kill_value(pid: int, unit_type: String) -> void:
	if pid < 0 or pid >= players.size():
		return
	var stats: Dictionary = players[pid].get("stats", {})
	stats["total_kill_value"] = float(stats.get("total_kill_value", 0.0)) + float(db.unit_data(unit_type).get("price", 0.0))
	players[pid]["stats"] = stats

func _record_turn_stats(pid: int) -> void:
	if pid < 0 or pid >= players.size():
		return
	var stats: Dictionary = players[pid].get("stats", {})
	var turn_data: Array = stats.get("turn_data", [])
	turn_data.append({
		"turn": turn,
		"army_value": _army_value(pid),
		"gold": float(players[pid].get("gold", 0.0)),
		"kill_value": float(stats.get("total_kill_value", 0.0)),
		"income": _income_for(pid)
	})
	stats["turn_data"] = turn_data
	players[pid]["stats"] = stats

func _army_value(pid: int) -> float:
	var value = 0.0
	for unit in units:
		if int(unit.get("pid", -1)) == pid:
			value += float(db.unit_data(str(unit.get("type", ""))).get("price", 0.0))
	return value

func _income_for(pid: int) -> float:
	var income = 0.0
	var owned_outposts: Array[Dictionary] = []
	for building in buildings:
		if int(building.get("pid", -1)) != pid or bool(building.get("under_construction", false)):
			continue
		if str(building.get("type", "")) == "据点":
			owned_outposts.append(building)
		elif str(building.get("type", "")) == "资源采集器":
			income += collector_income_for_id(int(building.get("collector_id", 0))) * _logistics_multiplier(pid)
		else:
			income += float(building.get("gold", 0.0))
	owned_outposts.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("id", 0)) < int(b.get("id", 0)))
	for index in range(owned_outposts.size()):
		var outpost = owned_outposts[index]
		var age = turn - int(outpost.get("capture_turn", -99))
		var recovery = 0.0 if age <= 1 else (0.5 if age == 2 else 1.0)
		var decay = OUTPOST_INCOME_DECAY[mini(index, OUTPOST_INCOME_DECAY.size() - 1)]
		income += float(outpost.get("gold", 0.0)) * recovery * decay
	return income

func terrain_height(pos: Vector2i) -> int:
	return int(db.terrain_data(terrain_at(pos)).get("height", 0))

func _step_cost(unit: Dictionary, from_pos: Vector2i, to_pos: Vector2i) -> float:
	var diagonal = 1.4 if from_pos.x != to_pos.x and from_pos.y != to_pos.y else 1.0
	if bool(unit.get("is_air", false)):
		return diagonal
	var base = float(db.terrain_data(terrain_at(to_pos)).get("move_cost", 1.0))
	var diff = terrain_height(to_pos) - terrain_height(from_pos)
	var slope = float(diff) * (0.8 if diff > 0 else 0.35)
	return max(0.6, base + slope) * diagonal

func effective_range(unit: Dictionary, from_height: int, to_height: int, target_is_air: bool = false) -> float:
	if target_is_air and float(unit.get("air_range", 0.0)) > 0.0:
		return float(unit["air_range"])
	if bool(unit.get("is_air", false)):
		return max(1.0, float(effective_unit_stats(unit).get("range", unit.get("range", 1.0))))
	var mod = clamp(from_height - to_height, -2, 2)
	return max(1.0, float(effective_unit_stats(unit).get("range", unit.get("range", 1.0))) + float(mod))

func update_vision() -> void:
	for player in players:
		player["visible"] = {}
		if not player.has("explored") or not (player["explored"] is Dictionary):
			player["explored"] = {}
		if not player.has("last_seen") or not (player["last_seen"] is Dictionary):
			player["last_seen"] = {}
		if player["strategic"].has("SpaceX 星链计划"):
			for y in range(height):
				for x in range(width):
					var pos = Vector2i(x, y)
					_mark_explored(player, pos)
					if turn % 3 == 0 and not _is_jammed(int(player["id"]), pos):
						_mark_visible(player, pos)
		for unit in units:
			if int(unit["pid"]) == int(player["id"]):
				_mark_radius(player, unit["pos"], effective_vision(unit) + (0 if bool(unit.get("is_air", false)) else terrain_height(unit["pos"])))
		for building in buildings:
			if int(building.get("pid", -1)) == int(player["id"]):
				var vision = 3
				if building["type"] == "大本营":
					vision = int(HQ_STATS[clampi(int(building.get("tier", 0)) + 1, 1, 5)].get("vision", 7))
				elif building["type"] == "据点" and str(building.get("outpost_branch", "")) == "combat" and int(building.get("outpost_tier", 0)) > 0:
					vision = 6
				else:
					vision = int(db.building_data(building["type"]).get("vision", 3))
				_mark_radius(player, building["pos"], vision)
		if is_total_war():
			for building in buildings:
				if str(building.get("type", "")) == "大本营":
					_mark_visible(player, building["pos"])
		_update_last_seen_for_player(player)

func _mark_explored(player: Dictionary, pos: Vector2i) -> void:
	player["explored"]["%d,%d" % [pos.x, pos.y]] = true

func _mark_radius(player: Dictionary, origin: Vector2i, radius: int) -> void:
	for y in range(max(0, origin.y - radius), min(height, origin.y + radius + 1)):
		for x in range(max(0, origin.x - radius), min(width, origin.x + radius + 1)):
			var pos = Vector2i(x, y)
			if _distance(origin, pos) <= float(radius):
				_mark_visible(player, pos)

func _mark_visible(player: Dictionary, pos: Vector2i) -> void:
	var key = "%d,%d" % [pos.x, pos.y]
	player["visible"][key] = true
	player["explored"][key] = true

func is_visible(pid: int, pos: Vector2i) -> bool:
	if not fog_enabled:
		return true
	if pid < 0 or pid >= players.size():
		return true
	if not players[pid].get("visible", {}).has("%d,%d" % [pos.x, pos.y]):
		return false
	var target = unit_at(pos)
	if target.is_empty() or int(target.get("pid", -1)) == pid:
		return true
	var conceal_distance = int(_equipment_for_unit(target).get("conceal_distance", 0))
	if conceal_distance <= 0 or bool(target.get("moved", false)):
		return true
	for observer in units:
		if int(observer.get("pid", -1)) != pid:
			continue
		var reveal = conceal_distance
		if unit_role(observer) == "support":
			reveal += 1
		if _distance(observer["pos"], pos) <= float(reveal):
			return true
	return false

func _is_jammed(pid: int, pos: Vector2i) -> bool:
	if pid < 0:
		return false
	for jammer in units:
		if int(jammer.get("pid", -1)) < 0 or int(jammer.get("pid", -1)) == pid:
			continue
		var equip = _equipment_for_unit(jammer)
		var radius = float(equip.get("jam_radius", 0.0))
		if radius > 0.0 and _distance(jammer["pos"], pos) <= radius:
			return true
	return false

func is_explored(pid: int, pos: Vector2i) -> bool:
	if not fog_enabled:
		return true
	if pid < 0 or pid >= players.size():
		return true
	return players[pid].get("explored", {}).has("%d,%d" % [pos.x, pos.y])

func building_memory_for(pid: int, pos: Vector2i) -> Dictionary:
	if pid < 0 or pid >= players.size():
		return {}
	return Dictionary(players[pid].get("last_seen", {}).get("%d,%d" % [pos.x, pos.y], {}))

func _update_last_seen_for_player(player: Dictionary) -> void:
	var memory: Dictionary = player.get("last_seen", {})
	for building in buildings:
		var pos: Vector2i = building["pos"]
		var key = "%d,%d" % [pos.x, pos.y]
		if not player["visible"].has(key):
			continue
		if int(building.get("pid", -1)) == int(player["id"]):
			continue
		memory[key] = {
			"type": building.get("type", ""),
			"pid": int(building.get("pid", -1)),
			"hp": float(building.get("hp", 0.0)),
			"max_hp": float(building.get("max_hp", 0.0)),
			"armor": float(building.get("armor", 0.0)),
			"tier": int(building.get("tier", 0)),
			"outpost_tier": int(building.get("outpost_tier", 0)),
			"outpost_branch": str(building.get("outpost_branch", "")),
			"gold": float(building.get("gold", 0.0)),
			"turn": turn
		}
	var visible_keys: Array = player["visible"].keys()
	for key in visible_keys:
		var parts = key.split(",")
		var pos = Vector2i(int(parts[0]), int(parts[1]))
		if building_at(pos).is_empty() and memory.has(key):
			memory.erase(key)
	player["last_seen"] = memory

func to_dict() -> Dictionary:
	return {
		"ruleset_version": RULESET_VERSION,
		"width": width,
		"height": height,
		"turn": turn,
		"current_player": current_player,
		"next_unit_id": next_unit_id,
		"next_building_id": next_building_id,
		"player_count": player_count,
		"terrain_grid": terrain_grid.duplicate(true),
		"players": players.duplicate(true),
		"units": _pack_entities(units),
		"buildings": _pack_entities(buildings),
		"game_over": game_over,
		"winner": winner,
		"last_event": last_event,
		"research_notifications": research_notifications.duplicate(true),
		"fog_enabled": fog_enabled
	}

func load_from_dict(data: Dictionary) -> void:
	width = int(data.get("width", width))
	height = int(data.get("height", height))
	turn = int(data.get("turn", 1))
	current_player = int(data.get("current_player", 0))
	next_unit_id = int(data.get("next_unit_id", 1))
	next_building_id = int(data.get("next_building_id", 1))
	player_count = int(data.get("player_count", 2))
	fog_enabled = bool(data.get("fog_enabled", true))
	terrain_grid = []
	for row in data.get("terrain_grid", []):
		terrain_grid.append(Array(row))
	players = []
	for player in data.get("players", []):
		var unpacked_player = Dictionary(player)
		if not unpacked_player.has("researching"):
			unpacked_player["researching"] = []
		if not unpacked_player.has("technology"):
			unpacked_player["technology"] = []
		if not unpacked_player.has("equipment"):
			unpacked_player["equipment"] = []
		if not unpacked_player.has("strategic"):
			unpacked_player["strategic"] = []
		if not unpacked_player.has("alive"):
			unpacked_player["alive"] = true
		if not unpacked_player.has("era"):
			unpacked_player["era"] = clampi(int(unpacked_player.get("tier", 1)), 1, 5)
		unpacked_player["tier"] = int(unpacked_player["era"])
		if not unpacked_player.has("campaign_advantage"):
			unpacked_player["campaign_advantage"] = 0
		if not unpacked_player.has("assault_window"):
			unpacked_player["assault_window"] = 0
		if not unpacked_player.has("satellite_scan_turn"):
			unpacked_player["satellite_scan_turn"] = -1
		players.append(unpacked_player)
	units = _unpack_entities(data.get("units", []))
	buildings = _unpack_entities(data.get("buildings", []))
	for unit in units:
		if not unit.has("equip"):
			unit["equip"] = ""
		if not unit.has("applied_equipment"):
			unit["applied_equipment"] = []
		var rules = _rules_for_unit(unit)
		if not unit.has("vision"): unit["vision"] = int(rules.get("vision", 4))
		if not unit.has("role"): unit["role"] = unit_role(unit)
		if not unit.has("era"): unit["era"] = unit_era(unit)
		if not unit.has("min_range"): unit["min_range"] = float(rules.get("min_range", 0.0))
		if not unit.has("move_origin"): unit["move_origin"] = unit["pos"]
		if not unit.has("moved_distance"): unit["moved_distance"] = 0.0
		if not unit.has("facing"): unit["facing"] = Vector2i.ZERO
		if not unit.has("charge_ready"): unit["charge_ready"] = false
		if not unit.has("marked_by"): unit["marked_by"] = {}
		if not unit.has("status"): unit["status"] = []
		if not unit.has("aps_used"): unit["aps_used"] = false
		if not unit.has("experience"): unit["experience"] = 0.0
	for building in buildings:
		if not building.has("turns_since_damage"):
			building["turns_since_damage"] = 0
		if not building.has("damaged_this_turn"):
			building["damaged_this_turn"] = false
		if not building.has("capture_turn"): building["capture_turn"] = -99 if int(building.get("pid", -1)) >= 0 else -1
		if not building.has("income_recovery"): building["income_recovery"] = 3
		if not building.has("era"): building["era"] = clampi(int(building.get("tier", 0)) + 1, 1, 5)
		if not building.has("strategic_point"): building["strategic_point"] = str(building.get("type", "")) == "据点"
	_resolve_unit_building_overlaps()
	game_over = bool(data.get("game_over", false))
	winner = int(data.get("winner", -1))
	last_event = str(data.get("last_event", ""))
	research_notifications = []
	for notice in data.get("research_notifications", []):
		research_notifications.append(Dictionary(notice))
	update_vision()

func _resolve_unit_building_overlaps() -> void:
	var stranded: Array[Dictionary] = []
	for unit in units:
		if building_at(unit["pos"]).is_empty():
			continue
		var replacement = _nearest_free_unit_tile(unit["pos"])
		if replacement != Vector2i(-1, -1):
			unit["pos"] = replacement
		else:
			stranded.append(unit)
	for unit in stranded:
		units.erase(unit)

func _nearest_free_unit_tile(origin: Vector2i) -> Vector2i:
	var max_radius = max(width, height)
	for radius in range(1, max_radius + 1):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				if abs(x - origin.x) != radius and abs(y - origin.y) != radius:
					continue
				var pos = Vector2i(x, y)
				if in_bounds(pos) and unit_at(pos).is_empty() and building_at(pos).is_empty():
					return pos
	return Vector2i(-1, -1)

func _pack_entities(source: Array) -> Array:
	var result = []
	for item in source:
		var packed = Dictionary(item).duplicate(true)
		for key in ["pos", "move_origin", "facing"]:
			if packed.has(key) and packed[key] is Vector2i:
				var vector: Vector2i = packed[key]
				packed[key] = [vector.x, vector.y]
		result.append(packed)
	return result

func _unpack_entities(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in source:
		var unpacked = Dictionary(item)
		for key in ["pos", "move_origin", "facing"]:
			if unpacked.has(key) and unpacked[key] is Array:
				var vector = unpacked[key]
				unpacked[key] = Vector2i(int(vector[0]), int(vector[1]))
		result.append(unpacked)
	return result

func _check_victory() -> void:
	var alive_hq = {}
	for building in buildings:
		var pid = int(building["pid"])
		if building["type"] == "大本营" and pid >= 0 and bool(players[pid].get("alive", true)):
			alive_hq[int(building["pid"])] = true
	if alive_hq.size() == 1:
		game_over = true
		winner = int(alive_hq.keys()[0])

func _distance(a: Vector2i, b: Vector2i) -> float:
	return a.distance_to(b)

