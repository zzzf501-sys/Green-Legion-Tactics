#!/usr/bin/env python3
"""
绿色军团（Toy Plastic Soldiers）— 热座回合制策略游戏
====================================================
基于 Pygame 的单机本地热座（Hotseat）策略游戏。
80x80 网格地图，支持摄像机缩放平移、单位行动、
建筑升级、热座多人轮流操作。

运行方式: python main.py
"""

import pygame
import math
import heapq
from collections import deque

# ============================================================
# 常量与配置
# ============================================================
TILE_SIZE = 64
SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
FPS = 60
MIN_ZOOM = 0.4
MAX_ZOOM = 2.5
MAP_WIDTH = 80
MAP_HEIGHT = 80

# 颜色
COLOR_BG = (30, 30, 40)
COLOR_GRID_LIGHT = (60, 65, 50)
COLOR_GRID_DARK = (50, 55, 40)
COLOR_HIGHLIGHT_MOVE = (255, 255, 0, 80)     # 黄色移动
COLOR_HIGHLIGHT_ATTACK = (255, 0, 0, 80)      # 红色攻击
COLOR_HIGHLIGHT_HEAL = (0, 255, 0, 80)        # 绿色驻扎
COLOR_WHITE = (255, 255, 255)
COLOR_BLACK = (0, 0, 0)
COLOR_RED = (255, 50, 50)
COLOR_GREEN = (50, 255, 50)
COLOR_BLUE = (60, 120, 255)
COLOR_GOLD = (255, 215, 0)
COLOR_GRAY = (100, 100, 100)
COLOR_DARK = (20, 20, 30)

PLAYER_COLORS = [
    (60, 120, 255),   # 蓝
    (255, 60, 60),    # 红
    (60, 220, 60),    # 绿
    (255, 220, 60),   # 黄
]

# ============================================================
# 数据字典（来自百科设计）
# ============================================================
UNIT_DATA = {
    '士兵':   {'hp': 1.5, 'armor': 0, 'speed': 3, 'damage': 1, 'range': 2, 'price': 1, 'attacks': 1},
    '坦克':   {'hp': 10, 'armor': 2, 'speed': 5, 'damage': 4, 'range': 3, 'price': 7, 'attacks': 1},
    '军用吉普': {'hp': 3, 'armor': 0, 'speed': 8, 'damage': 2, 'range': 3, 'price': 3, 'attacks': 1},
    '火箭炮': {'hp': 8, 'armor': 0.5, 'speed': 2, 'damage': 7, 'range': 15, 'price': 15, 'attacks': 1},
    '野战炮': {'hp': 4, 'armor': 1, 'speed': 3, 'damage': 5.5, 'range': 8, 'price': 5, 'attacks': 1},
    '装甲车': {'hp': 7, 'armor': 1, 'speed': 5, 'damage': 1.5, 'range': 3, 'price': 6, 'attacks': 3,
               'can_target_air': True},
    '战斗机': {'hp': 5, 'armor': 1, 'speed': 10, 'damage': 5.5, 'range': 3, 'price': 8, 'attacks': 1,
               'is_air': True, 'can_target_air': True},
    '轰炸机': {'hp': 20, 'armor': 3, 'speed': 5, 'damage': 12, 'range': 1, 'price': 15, 'attacks': 1,
               'is_air': True, 'blast': 3, 'reload': 2},
    '防空车': {'hp': 5, 'armor': 1, 'speed': 5, 'damage': 3, 'range': 4, 'price': 10, 'attacks': 1,
               'can_target_air': True, 'air_damage': 8, 'air_range': 14},
}

EQUIP_DATA = {
    '士兵': [
        {'name': '射手步枪', 'cost': 0.5, 'dmg': 0.5, 'range': 4, 'speed': -1, 'can_target_air': True},
        {'name': '反器械枪', 'cost': 1.5, 'dmg': 4, 'range': 2, 'can_target_air': True},
    ],
    '坦克': [
        {'name': '穿甲炮', 'cost': 2, 'dmg': 3, 'range': 1},
        {'name': '高爆炮', 'cost': 1, 'dmg': -2, 'range': 0, 'blast': 3},
    ],
    '军用吉普': [{'name': '火箭助推', 'cost': 1, 'speed': 5, 'hp': 1}],
    '火箭炮': [{'name': '对空雷达', 'cost': 3, 'range': 1, 'can_target_air': True}],
    '野战炮': [
        {'name': '轻量化', 'cost': -2, 'dmg': -1, 'hp': -1},
        {'name': '巨炮', 'cost': 6, 'dmg': 7, 'range': 4, 'speed': -1, 'hp': 3},
    ],
}

BUILDING_DATA = {
    '大本营': {
        'tiers': [
            {'hp': 20, 'armor': 0, 'gold': 3, 'upgrade_cost': 10, 'upgrade_time': 3},
            {'hp': 50, 'armor': 0.5, 'gold': 5, 'upgrade_cost': 30, 'upgrade_time': 8, 'turret': {'damage': 2, 'attacks': 2, 'range': 5}},
            {'hp': 120, 'armor': 1, 'gold': 8, 'upgrade_cost': None, 'upgrade_time': None, 'turret': {'damage': 3, 'attacks': 3, 'range': 8}},
        ]
    },
    '资源采集器': {'hp': 15, 'armor': 0, 'gold': 3, 'cost': 8},
    '据点': {'hp': 20, 'armor': 0, 'gold': 3, 'capture_turret': {'damage': 2, 'attacks': 2, 'range': 5}},
}

# ============================================================
# 辅助函数
# ============================================================

def neighbors(gx, gy):
    """返回四方向相邻坐标"""
    for dx, dy in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
        yield gx + dx, gy + dy

def manhattan(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1])

def load_font(size):
    """加载支持中文的字体"""
    import os
    # Windows 常见中文字体路径
    font_paths = [
        'C:/Windows/Fonts/msyh.ttc',     # Microsoft YaHei
        'C:/Windows/Fonts/simhei.ttf',    # SimHei
        'C:/Windows/Fonts/simsun.ttc',    # SimSun
        'C:/Windows/Fonts/msyhbd.ttc',   # Microsoft YaHei Bold
    ]
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                return pygame.font.Font(fp, size)
            except pygame.error:
                continue
    return pygame.font.Font(None, size)  # 回退默认字体

def load_image(path, size=None):
    """加载并缩放图片"""
    try:
        img = pygame.image.load(path).convert_alpha()
        if size:
            img = pygame.transform.scale(img, size)
        return img
    except (pygame.error, FileNotFoundError):
        return None

def apply_equip(stats, equip):
    """应用装备加成到基础属性"""
    if not equip:
        return dict(stats)
    s = dict(stats)
    s['damage'] = s.get('damage', 0) + equip.get('dmg', 0)
    s['range'] = s.get('range', 0) + equip.get('range', 0)
    s['speed'] = s.get('speed', 0) + equip.get('speed', 0)
    s['hp'] = max(0.5, s.get('hp', 1) + equip.get('hp', 0))
    s['price'] = s.get('price', 0) + equip.get('cost', 0)
    s['can_target_air'] = s.get('can_target_air', False) or equip.get('can_target_air', False)
    if equip.get('blast'):
        s['blast'] = equip['blast']
    return s


# ============================================================
# 摄像机
# ============================================================
class Camera:
    """处理视口平移与缩放"""

    def __init__(self, map_pixels_w, map_pixels_h):
        self.map_w = map_pixels_w
        self.map_h = map_pixels_h
        self.offset_x = 0
        self.offset_y = 0
        self.zoom = 1.0
        self.target_zoom = 1.0
        self.target_offset_x = 0
        self.target_offset_y = 0
        self._dragging = False
        self._drag_start = (0, 0)
        self._drag_offset = (0, 0)

    def world_to_screen(self, wx, wy):
        return (wx * self.zoom + self.offset_x,
                wy * self.zoom + self.offset_y)

    def screen_to_world(self, sx, sy):
        return ((sx - self.offset_x) / self.zoom,
                (sy - self.offset_y) / self.zoom)

    def screen_to_grid(self, sx, sy):
        wx, wy = self.screen_to_world(sx, sy)
        return int(wx // TILE_SIZE), int(wy // TILE_SIZE)

    def grid_to_screen(self, gx, gy):
        return self.world_to_screen(gx * TILE_SIZE, gy * TILE_SIZE)

    def pan(self, dx, dy):
        self.target_offset_x += dx
        self.target_offset_y += dy
        self._clamp_offset()

    def start_drag(self, sx, sy):
        self._dragging = True
        self._drag_start = (sx, sy)
        self._drag_offset = (self.offset_x, self.offset_y)

    def update_drag(self, sx, sy):
        if self._dragging:
            self.target_offset_x = self._drag_offset[0] + (sx - self._drag_start[0])
            self.target_offset_y = self._drag_offset[1] + (sy - self._drag_start[1])
            self._clamp_offset()

    def end_drag(self):
        self._dragging = False

    def zoom_at(self, sx, sy, delta):
        """以屏幕坐标 (sx,sy) 为中心缩放"""
        wx = (sx - self.offset_x) / self.zoom
        wy = (sy - self.offset_y) / self.zoom
        self.target_zoom = max(MIN_ZOOM, min(MAX_ZOOM, self.target_zoom + delta))
        self.target_offset_x = sx - wx * self.target_zoom
        self.target_offset_y = sy - wy * self.target_zoom
        self._clamp_offset()

    def get_visible_rect(self):
        """返回可视区域的网格范围 (min_gx, min_gy, max_gx, max_gy)"""
        left, top = self.screen_to_world(0, 0)
        right, bottom = self.screen_to_world(SCREEN_WIDTH, SCREEN_HEIGHT)
        return (max(0, int(left // TILE_SIZE)),
                max(0, int(top // TILE_SIZE)),
                min(MAP_WIDTH - 1, int(right // TILE_SIZE) + 1),
                min(MAP_HEIGHT - 1, int(bottom // TILE_SIZE) + 1))

    def update(self):
        """平滑插值"""
        lerp = 0.15
        self.zoom += (self.target_zoom - self.zoom) * lerp
        self.offset_x += (self.target_offset_x - self.offset_x) * lerp
        self.offset_y += (self.target_offset_y - self.offset_y) * lerp

    def _clamp_offset(self):
        """防止摄像机越界"""
        max_ox = self.map_w * self.zoom - SCREEN_WIDTH
        max_oy = self.map_h * self.zoom - SCREEN_HEIGHT
        self.target_offset_x = max(min(self.target_offset_x, 10), -max_ox - 10)
        self.target_offset_y = max(min(self.target_offset_y, 10), -max_oy - 10)


# ============================================================
# 瓦片与网格
# ============================================================
class Tile:
    def __init__(self, gx, gy, terrain='grass'):
        self.gx = gx
        self.gy = gy
        self.terrain = terrain
        self.occupant = None  # Unit or Building

    @property
    def movement_cost(self):
        return {'grass': 1, 'road': 0.5, 'forest': 2, 'water': 99, 'mountain': 3}.get(self.terrain, 1)

    @property
    def blocks_vision(self):
        return self.terrain in ('mountain', 'forest')


class Grid:
    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.tiles = [[Tile(x, y) for y in range(height)] for x in range(width)]
        self._init_terrain()

    def _init_terrain(self):
        """生成简单地形"""
        import random
        random.seed(42)
        for x in range(self.width):
            for y in range(self.height):
                r = random.random()
                if r < 0.03:
                    self.tiles[x][y].terrain = 'water'
                elif r < 0.08:
                    self.tiles[x][y].terrain = 'forest'
                elif r < 0.10:
                    self.tiles[x][y].terrain = 'mountain'

    def in_bounds(self, gx, gy):
        return 0 <= gx < self.width and 0 <= gy < self.height

    def get_tile(self, gx, gy):
        if self.in_bounds(gx, gy):
            return self.tiles[gx][gy]
        return None

    def place(self, entity, gx, gy):
        tile = self.get_tile(gx, gy)
        if tile:
            tile.occupant = entity
            entity.grid_x, entity.grid_y = gx, gy

    def remove(self, entity):
        tile = self.get_tile(entity.grid_x, entity.grid_y)
        if tile and tile.occupant is entity:
            tile.occupant = None


# ============================================================
# 实体基类
# ============================================================
class Entity:
    def __init__(self, name, grid_x, grid_y, player_id):
        self.name = name
        self.grid_x = grid_x
        self.grid_y = grid_y
        self.player_id = player_id
        self.sprite = None


class Unit(Entity):
    def __init__(self, unit_type, grid_x, grid_y, player_id, equip=None):
        super().__init__(unit_type, grid_x, grid_y, player_id)
        self.unit_type = unit_type
        stats = apply_equip(UNIT_DATA[unit_type], equip)
        self.max_hp = stats['hp']
        self.hp = stats['hp']
        self.armor = stats['armor']
        self.speed = stats['speed']
        self.damage = stats['damage']
        self.attack_range = stats['range']
        self.attacks_per_turn = stats.get('attacks', 1)
        self.price = stats['price']
        self.is_air = stats.get('is_air', False)
        self.can_target_air = stats.get('can_target_air', False)
        self.blast = stats.get('blast', 1)
        self.reload = stats.get('reload', 0)
        self.equip = equip

        # 状态机
        self.has_moved = False
        self.has_attacked = False
        self.is_action_done = False
        self.is_stationed = False
        self._reload_counter = 0

    def reset_turn(self):
        self.has_moved = False
        self.has_attacked = False
        self.is_action_done = False
        if self._reload_counter > 0:
            self._reload_counter -= 1

    def can_move(self):
        return not self.has_moved and not self.is_action_done

    def can_attack(self):
        return self.has_moved and not self.has_attacked and not self.is_action_done and self._reload_counter == 0

    def can_skip(self):
        return not self.is_action_done

    def move_to(self, gx, gy):
        self.grid_x, self.grid_y = gx, gy
        self.has_moved = True

    def get_effective_range(self, target):
        """对空目标时使用对空射程"""
        if target and target.is_air and hasattr(self, 'air_range') and self.air_range:
            return self.air_range
        return self.attack_range

    def get_effective_damage(self, target):
        """对空目标时使用对空伤害"""
        if target and target.is_air and hasattr(self, 'air_damage') and self.air_damage:
            return self.air_damage
        return self.damage

    def attack_target(self, target):
        """攻击一个目标，返回造成的总伤害"""
        dmg_per = max(0, self.get_effective_damage(target) - target.armor)
        total = dmg_per * self.attacks_per_turn * self.blast
        actual = target.take_damage(total)
        self.has_attacked = True
        self.is_action_done = True
        if self.reload > 0:
            self._reload_counter = self.reload
        return actual

    def take_damage(self, amount):
        """承受伤害，返回实际扣除的HP"""
        actual = min(amount, self.hp)
        self.hp -= actual
        return actual

    @property
    def is_dead(self):
        return self.hp <= 0


class Building(Entity):
    def __init__(self, building_type, grid_x, grid_y, player_id, tier=0):
        super().__init__(building_type, grid_x, grid_y, player_id)
        self.building_type = building_type
        self.tier = tier  # 0-based: 0=T1, 1=T2, 2=T3
        self.is_upgrading = False
        self.upgrade_timer = 0
        self.is_captured = False  # 据点是否被占领
        self.turns_since_damaged = 0  # 自回血计数
        self._damaged_this_turn = False
        self._update_tier_stats()

    def _update_tier_stats(self):
        data = BUILDING_DATA.get(self.building_type, {})
        if self.building_type == '大本营':
            t = data['tiers'][self.tier]
            self.max_hp = t['hp']
            self.hp = getattr(self, 'hp', t['hp'])
            self.armor = t['armor']
            self.gold_per_turn = t['gold']
            self.upgrade_cost = t.get('upgrade_cost')
            self.upgrade_time = t.get('upgrade_time')
            self.turret = t.get('turret')
        elif self.building_type == '据点':
            d = data
            self.max_hp = d['hp']
            self.hp = getattr(self, 'hp', d['hp'])
            self.armor = d['armor']
            self.gold_per_turn = d['gold'] if self.is_captured else 0
            self.upgrade_cost = None
            self.upgrade_time = None
            self.turret = d.get('capture_turret') if self.is_captured else None
        else:  # 资源采集器
            self.max_hp = data['hp']
            self.hp = getattr(self, 'hp', data['hp'])
            self.armor = data['armor']
            self.gold_per_turn = data['gold']
            self.upgrade_cost = None
            self.upgrade_time = None
            self.turret = None

    def capture(self, new_player_id):
        """据点被占领"""
        self.player_id = new_player_id
        self.is_captured = True
        heal = int(self.max_hp * 0.3)
        self.hp = min(self.max_hp, self.hp + heal)
        self._update_tier_stats()
        self.turns_since_damaged = 0

    def take_damage(self, amount):
        """承受伤害，标记受击"""
        actual = min(amount, self.hp)
        self.hp -= actual
        self._damaged_this_turn = True
        self.turns_since_damaged = 0
        return actual

    def on_turn_start(self):
        """回合开始：自回血 + 标记清除"""
        if self._damaged_this_turn:
            self.turns_since_damaged = 0
        else:
            self.turns_since_damaged += 1
        self._damaged_this_turn = False

        # 连续两回合未受击 → 第三回合起每回合回2血
        if self.turns_since_damaged >= 3 and self.hp < self.max_hp:
            self.hp = min(self.max_hp, self.hp + 2)

    def can_upgrade(self):
        return (self.building_type == '大本营' and self.tier < 2
                and not self.is_upgrading)

    def start_upgrade(self):
        if self.can_upgrade():
            self.is_upgrading = True
            self.upgrade_timer = self.upgrade_time

    def tick_upgrade(self):
        if self.is_upgrading:
            self.upgrade_timer -= 1
            if self.upgrade_timer <= 0:
                self.tier += 1
                self.is_upgrading = False
                self.hp = self.max_hp  # 升级回满血
                self._update_tier_stats()
                return True
        return False

    @property
    def is_dead(self):
        return self.hp <= 0

    def in_heal_range(self, gx, gy):
        """半径2格内可驻扎回血"""
        return manhattan((self.grid_x, self.grid_y), (gx, gy)) <= 2


# ============================================================
# 寻路与范围计算
# ============================================================
class Pathfinder:
    @staticmethod
    def compute_move_range(grid, start, max_moves, unit=None):
        """BFS 计算移动范围"""
        sx, sy = start
        if not grid.in_bounds(sx, sy):
            return set()
        cost_so_far = {(sx, sy): 0}
        frontier = deque([(sx, sy)])
        while frontier:
            cx, cy = frontier.popleft()
            current = cost_so_far[(cx, cy)]
            for nx, ny in neighbors(cx, cy):
                if not grid.in_bounds(nx, ny):
                    continue
                tile = grid.get_tile(nx, ny)
                occ = tile.occupant
                if occ and occ != unit and occ.player_id != unit.player_id:
                    continue  # 敌方单位或建筑阻挡
                new_cost = current + tile.movement_cost
                if new_cost <= max_moves and (nx, ny) not in cost_so_far:
                    cost_so_far[(nx, ny)] = new_cost
                    frontier.append((nx, ny))
        result = set(cost_so_far.keys())
        result.discard(start)
        return result

    @staticmethod
    def find_path(grid, start, goal, unit=None):
        """A* 寻路"""
        sx, sy = start
        gx, gy = goal
        if not grid.in_bounds(sx, sy) or not grid.in_bounds(gx, gy):
            return []
        frontier = [(0, sx, sy)]
        came_from = {(sx, sy): None}
        cost_so_far = {(sx, sy): 0}
        while frontier:
            _, cx, cy = heapq.heappop(frontier)
            if (cx, cy) == (gx, gy):
                break
            for nx, ny in neighbors(cx, cy):
                if not grid.in_bounds(nx, ny):
                    continue
                tile = grid.get_tile(nx, ny)
                occ = tile.occupant
                if (nx, ny) != (gx, gy) and occ and occ.player_id != (unit.player_id if unit else -2):
                    continue
                new_cost = cost_so_far[(cx, cy)] + tile.movement_cost
                if (nx, ny) not in cost_so_far or new_cost < cost_so_far[(nx, ny)]:
                    cost_so_far[(nx, ny)] = new_cost
                    priority = new_cost + abs(nx - gx) + abs(ny - gy)
                    heapq.heappush(frontier, (priority, nx, ny))
                    came_from[(nx, ny)] = (cx, cy)
        if (gx, gy) not in came_from:
            return []
        path = []
        cur = (gx, gy)
        while cur != (sx, sy):
            path.append(cur)
            cur = came_from[cur]
        path.reverse()
        return path

    @staticmethod
    def get_tiles_in_range(grid, center, radius):
        """曼哈顿距离范围内的格子"""
        cx, cy = center
        result = set()
        for dx in range(-radius, radius + 1):
            for dy in range(-radius, radius + 1):
                if abs(dx) + abs(dy) <= radius:
                    nx, ny = cx + dx, cy + dy
                    if grid.in_bounds(nx, ny):
                        result.add((nx, ny))
        return result


# ============================================================
# 选择管理器
# ============================================================
class SelectionManager:
    def __init__(self):
        self.selected_unit = None
        self.selected_building = None
        self.highlight_tiles = set()
        self.highlight_color = COLOR_HIGHLIGHT_MOVE
        self.action_phase = 'SELECT_UNIT'  # SELECT_UNIT, MOVE_PHASE, ATTACK_PHASE

    def clear(self):
        self.selected_unit = None
        self.selected_building = None
        self.highlight_tiles.clear()
        self.action_phase = 'SELECT_UNIT'

    def select_unit(self, unit, grid):
        self.selected_unit = unit
        self.selected_building = None
        if unit.can_move():
            self.highlight_tiles = Pathfinder.compute_move_range(
                grid, (unit.grid_x, unit.grid_y), unit.speed, unit)
            self.highlight_color = COLOR_HIGHLIGHT_MOVE
            self.action_phase = 'MOVE_PHASE'
        else:
            self._show_attack_range(unit, grid)
            self.action_phase = 'ATTACK_PHASE'

    def _show_attack_range(self, unit, grid):
        if unit.can_attack():
            self.highlight_tiles = Pathfinder.get_tiles_in_range(
                grid, (unit.grid_x, unit.grid_y), unit.attack_range)
            self.highlight_color = COLOR_HIGHLIGHT_ATTACK
        else:
            self.highlight_tiles.clear()

    def select_building(self, building):
        self.clear()
        self.selected_building = building

    def handle_click(self, gx, gy, engine, grid):
        player = engine.get_current_player()
        tile = grid.get_tile(gx, gy)
        if not tile:
            return

        occ = tile.occupant

        # 检查UI按钮点击
        if self.action_phase == 'SELECT_UNIT':
            if occ and occ.player_id == player.player_id:
                if isinstance(occ, Building) and occ.building_type == '大本营':
                    self.select_building(occ)
                    return
                elif isinstance(occ, Unit):
                    self.select_unit(occ, grid)
                    return
            self.clear()

        elif self.action_phase == 'MOVE_PHASE':
            unit = self.selected_unit
            if not unit:
                return
            if (gx, gy) in self.highlight_tiles:
                # 执行移动
                old_tile = grid.get_tile(unit.grid_x, unit.grid_y)
                if old_tile:
                    old_tile.occupant = None
                unit.move_to(gx, gy)
                tile.occupant = unit

                # 移动后检查攻击范围
                if unit.can_attack():
                    atk_tiles = Pathfinder.get_tiles_in_range(
                        grid, (gx, gy), unit.attack_range)
                    enemies = set()
                    for tx, ty in atk_tiles:
                        t = grid.get_tile(tx, ty)
                        if t and t.occupant:
                            occ = t.occupant
                            if occ.player_id != player.player_id:
                                enemies.add((tx, ty))
                    if enemies:
                        self.highlight_tiles = enemies
                        self.highlight_color = COLOR_HIGHLIGHT_ATTACK
                        self.action_phase = 'ATTACK_PHASE'
                        return
                # 无目标可打 → 自动结束
                unit.is_action_done = True
                self.clear()
            elif occ and isinstance(occ, Unit) and occ.player_id == player.player_id:
                self.select_unit(occ, grid)
            else:
                self.clear()

        elif self.action_phase == 'ATTACK_PHASE':
            unit = self.selected_unit
            if not unit:
                return
            if (gx, gy) in self.highlight_tiles:
                target_tile = grid.get_tile(gx, gy)
                if target_tile and target_tile.occupant:
                    target = target_tile.occupant
                    if target.player_id != player.player_id:
                        unit.attack_target(target)
                        if isinstance(target, Unit) and target.is_dead:
                            grid.remove(target)
                            player.remove_unit(target)
                        elif isinstance(target, Building):
                            if target.is_dead:
                                if target.building_type == '据点' and not target.is_captured:
                                    # 据点被占领
                                    target.capture(player.player_id)
                                    grid.get_tile(gx, gy).occupant = target
                                    player.add_building(target)
                                    # 移除原拥有者（中立无玩家）
                                else:
                                    grid.remove(target)
                                    # 从玩家移除
                                    for p in engine.players:
                                        if target in p.buildings:
                                            p.remove_building(target)
                                            break
                        self.clear()
                        engine.auto_end_if_no_actions()
                        return
            self.clear()

    def skip_unit(self):
        if self.selected_unit and self.selected_unit.can_skip():
            self.selected_unit.is_action_done = True
            self.clear()

    def station_unit(self):
        unit = self.selected_unit
        if unit and unit.can_skip():
            player_hq = None
            # 检查是否有本方大本营在半径2内
            for b in self._get_player_buildings(unit.player_id):
                if b.building_type == '大本营' and b.in_heal_range(unit.grid_x, unit.grid_y):
                    player_hq = b
                    break
            if player_hq:
                unit.is_stationed = True
                unit.is_action_done = True
                self.clear()

    def _get_player_buildings(self, pid):
        """临时方法，由外部设置"""
        return []


# ============================================================
# 玩家
# ============================================================
class Player:
    def __init__(self, player_id, name):
        self.player_id = player_id
        self.name = name
        self.gold = 10
        self.units = []
        self.buildings = []
        self.is_alive = True

    def add_unit(self, unit):
        self.units.append(unit)

    def remove_unit(self, unit):
        if unit in self.units:
            self.units.remove(unit)
        if len(self.units) == 0 and len([b for b in self.buildings if b.building_type == '大本营']) == 0:
            self.is_alive = False

    def add_building(self, building):
        self.buildings.append(building)

    def remove_building(self, building):
        if building in self.buildings:
            self.buildings.remove(building)
        if building.building_type == '大本营' and len([b for b in self.buildings if b.building_type == '大本营']) == 0:
            self.is_alive = False

    def collect_income(self):
        for b in self.buildings:
            self.gold += b.gold_per_turn

    def on_turn_start(self):
        """回合开始刷新"""
        for u in self.units:
            u.reset_turn()
            # 驻扎回血
            if u.is_stationed:
                for b in self.buildings:
                    if b.building_type == '大本营' and b.in_heal_range(u.grid_x, u.grid_y):
                        u.hp = min(u.max_hp, u.hp + 1)
                        break
            u.is_stationed = False
        # 建筑自回血
        for b in self.buildings:
            b.on_turn_start()
        self.collect_income()

    def get_hq(self):
        for b in self.buildings:
            if b.building_type == '大本营':
                return b
        return None


# ============================================================
# 游戏引擎
# ============================================================
class GameEngine:
    def __init__(self, player_count=2):
        self.players = []
        self.current_player_index = 0
        self.turn_number = 1
        self.game_state = 'PLAYING'
        self._init_players(player_count)

    def _init_players(self, count):
        for i in range(count):
            self.players.append(Player(i, f'玩家{i + 1}'))

    def get_current_player(self):
        return self.players[self.current_player_index]

    def next_turn(self):
        self.turn_number += 1
        # 跳过已阵亡玩家
        for _ in range(len(self.players)):
            self.current_player_index = (self.current_player_index + 1) % len(self.players)
            if self.get_current_player().is_alive:
                break
        self.get_current_player().on_turn_start()
        self.check_win_condition()

    def check_win_condition(self):
        alive = [p for p in self.players if p.is_alive]
        if len(alive) <= 1:
            self.game_state = 'GAME_OVER'
            return alive[0] if alive else None
        return None

    def auto_end_if_no_actions(self):
        """检查当前玩家是否还有可行动单位，全部完成则自动结束回合"""
        player = self.get_current_player()
        for u in player.units:
            if not u.is_action_done:
                return False
        return True


# ============================================================
# UI 按钮
# ============================================================
class Button:
    def __init__(self, x, y, w, h, text, color=COLOR_DARK, text_color=COLOR_WHITE):
        self.rect = pygame.Rect(x, y, w, h)
        self.text = text
        self.color = color
        self.text_color = text_color
        self.visible = True

    def draw(self, screen, font):
        if not self.visible:
            return
        pygame.draw.rect(screen, self.color, self.rect, border_radius=4)
        pygame.draw.rect(screen, COLOR_GRAY, self.rect, 1, border_radius=4)
        label = font.render(self.text, True, self.text_color)
        lr = label.get_rect(center=self.rect.center)
        screen.blit(label, lr)

    def is_hovered(self, pos):
        return self.visible and self.rect.collidepoint(pos)
# 渲染器
# ============================================================
class Renderer:
    def __init__(self, screen, camera, grid, selection, engine):
        self.screen = screen
        self.cam = camera
        self.grid = grid
        self.sel = selection
        self.engine = engine
        self.font = load_font(16)
        self.font_big = load_font(24)
        self.font_title = load_font(32)
        self._sprite_cache = {}
        self._hover_gx = -1
        self._hover_gy = -1

    def set_hover(self, gx, gy):
        self._hover_gx = gx
        self._hover_gy = gy

    def _get_sprite(self, name, size=(TILE_SIZE, TILE_SIZE)):
        if name not in self._sprite_cache:
            path = f'picture/{name}.png'
            img = load_image(path, size)
            self._sprite_cache[name] = img
        return self._sprite_cache[name]

    def render(self):
        self.screen.fill(COLOR_BG)
        vr = self.cam.get_visible_rect()

        # 绘制地图瓦片
        for gx in range(vr[0], vr[2]):
            for gy in range(vr[1], vr[3]):
                self._draw_tile(gx, gy)

        # 绘制高亮
        for gx, gy in self.sel.highlight_tiles:
            if vr[0] <= gx <= vr[2] and vr[1] <= gy <= vr[3]:
                self._draw_highlight(gx, gy, self.sel.highlight_color)

        # 绘制建筑
        for p in self.engine.players:
            for b in p.buildings:
                if vr[0] <= b.grid_x <= vr[2] and vr[1] <= b.grid_y <= vr[3]:
                    self._draw_building(b)

        # 绘制单位 + 白色光圈
        for p in self.engine.players:
            for u in p.units:
                if vr[0] <= u.grid_x <= vr[2] and vr[1] <= u.grid_y <= vr[3]:
                    self._draw_unit(u)

        # 绘制 HQ 菜单（含按钮）
        if self.sel.selected_building and self.sel.selected_building.building_type == '大本营':
            self._draw_hq_menu(self.sel.selected_building)
            for btn in getattr(self, 'hq_buttons', []):
                btn.draw(self.screen, self.font)
        self._draw_hud()
        self._draw_tooltip()

    def _draw_tooltip(self):
        gx, gy = self._hover_gx, self._hover_gy
        if gx < 0 or gy < 0: return
        tile = self.grid.get_tile(gx, gy)
        if not tile or not tile.occupant: return
        ent = tile.occupant
        lines = []
        if isinstance(ent, Unit):
            pcolor = PLAYER_COLORS[ent.player_id]
            lines.append(f'玩家{ent.player_id+1} | {ent.unit_type}')
            if ent.equip: lines.append(f'装备: {ent.equip.get("name","")}')
            lines.append(f'HP: {ent.hp:.1f}/{ent.max_hp:.1f} 护甲:{ent.armor}')
            lines.append(f'伤害:{ent.damage} 射程:{ent.attack_range} 速:{ent.speed}')
            lines.append('状态:'+('[已行动]' if ent.is_action_done else '[待行动]'))
        elif isinstance(ent, Building):
            pcolor = PLAYER_COLORS[ent.player_id] if ent.player_id >= 0 else COLOR_GRAY
            lines.append(('玩家'+str(ent.player_id+1) if ent.player_id>=0 else '中立')+' | '+ent.building_type)
            lines.append(f'HP:{int(ent.hp)}/{int(ent.max_hp)} 护甲:{ent.armor}')
            if ent.building_type=='大本营': lines.append(f'T{ent.tier+1} +{ent.gold_per_turn}🪙')
            elif ent.building_type=='据点': lines.append('已占领 +'+str(ent.gold_per_turn)+'🪙' if ent.is_captured else '中立 可占领')
        mx,my=pygame.mouse.get_pos();bw,bh=220,24+len(lines)*18
        bx=max(10,min(mx+15,SCREEN_WIDTH-bw-10));by=max(10,min(my-10,SCREEN_HEIGHT-bh-10))
        pygame.draw.rect(self.screen,(20,20,30),(bx,by,bw,bh),border_radius=4)
        pygame.draw.rect(self.screen,COLOR_GRAY,(bx,by,bw,bh),1,border_radius=4)
        for i,ln in enumerate(lines):
            self.screen.blit(self.font.render(ln,True,pcolor if i==0 else COLOR_WHITE),(bx+6,by+4+i*18))

    def _draw_tile(self, gx, gy):
        sx, sy = self.cam.grid_to_screen(gx, gy)
        tile = self.grid.get_tile(gx, gy)
        if not tile:
            return
        base = COLOR_GRID_LIGHT if (gx + gy) % 2 == 0 else COLOR_GRID_DARK
        terrain_colors = {
            'water': (40, 50, 80),
            'forest': (30, 60, 30),
            'mountain': (60, 55, 40),
            'road': (55, 50, 45),
        }
        color = terrain_colors.get(tile.terrain, base)
        rect = pygame.Rect(sx, sy, TILE_SIZE * self.cam.zoom, TILE_SIZE * self.cam.zoom)
        pygame.draw.rect(self.screen, color, rect)
        pygame.draw.rect(self.screen, (40, 40, 40), rect, 1)

    def _draw_highlight(self, gx, gy, color):
        sx, sy = self.cam.grid_to_screen(gx, gy)
        size = TILE_SIZE * self.cam.zoom
        surf = pygame.Surface((size, size), pygame.SRCALPHA)
        surf.fill(color)
        self.screen.blit(surf, (sx, sy))

    def _draw_unit(self, unit):
        sx, sy = self.cam.grid_to_screen(unit.grid_x, unit.grid_y)
        size = TILE_SIZE * self.cam.zoom
        sprite = self._get_sprite(unit.unit_type)
        if sprite:
            scaled = pygame.transform.scale(sprite, (int(size), int(size)))
            self.screen.blit(scaled, (sx, sy))
        else:
            # 无贴图时绘制圆
            color = PLAYER_COLORS[unit.player_id]
            pygame.draw.circle(self.screen, color,
                               (int(sx + size / 2), int(sy + size / 2)),
                               int(size / 2.5))
            pygame.draw.circle(self.screen, COLOR_WHITE,
                               (int(sx + size / 2), int(sy + size / 2)),
                               int(size / 2.5), 1)

        # 白色光圈（未行动标记）
        if not unit.is_action_done:
            pygame.draw.circle(self.screen, COLOR_WHITE,
                               (int(sx + size / 2), int(sy + size / 2)),
                               int(size / 2.2), 2)

        # HP 条
        bar_w = int(size * 0.8)
        bar_h = max(3, int(size * 0.08))
        bar_x = sx + (size - bar_w) / 2
        bar_y = sy + size - bar_h - 2
        ratio = unit.hp / unit.max_hp
        hp_color = COLOR_GREEN if ratio > 0.5 else COLOR_GOLD if ratio > 0.25 else COLOR_RED
        pygame.draw.rect(self.screen, COLOR_DARK, (bar_x, bar_y, bar_w, bar_h))
        pygame.draw.rect(self.screen, hp_color, (bar_x, bar_y, bar_w * ratio, bar_h))

    def _draw_building(self, building):
        sx, sy = self.cam.grid_to_screen(building.grid_x, building.grid_y)
        size = TILE_SIZE * self.cam.zoom
        if building.building_type == '大本营':
            name = f'大本营 T{building.tier + 1}'
            sprite = self._get_sprite(name)
        elif building.building_type == '据点':
            sprite = self._get_sprite('据点')
        else:
            sprite = self._get_sprite(building.building_type)
        if sprite:
            scaled = pygame.transform.scale(sprite, (int(size * 1.2), int(size * 1.2)))
            self.screen.blit(scaled, (sx - size * 0.1, sy - size * 0.1))
        else:
            color = PLAYER_COLORS[max(0, building.player_id)] if building.player_id >= 0 else COLOR_GRAY
            rect = pygame.Rect(sx, sy, size, size)
            pygame.draw.rect(self.screen, color, rect)
            pygame.draw.rect(self.screen, COLOR_WHITE, rect, 2)
            text = self.font.render(building.building_type[:2], True, COLOR_WHITE)
            self.screen.blit(text, (sx + 4, sy + 4))

        # 建筑HP条（以精灵实际位置计算）
        spr_x = sx - size * 0.1
        spr_w = size * 1.2
        bar_w = int(spr_w * 0.7)
        bar_h = max(3, int(size * 0.08))
        bar_x = spr_x + (spr_w - bar_w) / 2
        bar_y = sy - 8
        ratio = building.hp / building.max_hp
        hp_color = COLOR_GREEN if ratio > 0.5 else COLOR_GOLD if ratio > 0.25 else COLOR_RED
        pygame.draw.rect(self.screen, COLOR_DARK, (bar_x, bar_y, bar_w, bar_h))
        pygame.draw.rect(self.screen, hp_color, (bar_x, bar_y, bar_w * ratio, bar_h))

    def _draw_hud(self):
        player = self.engine.get_current_player()
        pcolor = PLAYER_COLORS[player.player_id]

        # 顶部状态栏
        pygame.draw.rect(self.screen, COLOR_DARK, (0, 0, SCREEN_WIDTH, 34))
        info = f' {pcolor[0]}  {player.name}  |  回合 {self.engine.turn_number}  |  🪙 {player.gold}'
        text = self.font_big.render(info, True, pcolor)
        self.screen.blit(text, (10, 6))

        # 底部按钮（由外部通过 renderer.buttons 传入）
        for name, btn in getattr(self, 'buttons', {}).items():
            if self.engine.game_state != 'PLAYING':
                btn.visible = False
                continue
            if name == 'skip':
                btn.visible = bool(self.sel.selected_unit and
                                   self.sel.selected_unit.can_skip())
            elif name == 'station':
                unit = self.sel.selected_unit
                can_station = False
                if unit and not unit.is_action_done:
                    for b in player.buildings:
                        if b.building_type == '大本营' and b.in_heal_range(
                                unit.grid_x, unit.grid_y):
                            can_station = True
                            break
                btn.visible = can_station
            btn.draw(self.screen, self.font)

        # 选中的单位信息
        if self.sel.selected_unit:
            u = self.sel.selected_unit
            info2 = f'{u.unit_type}  HP: {u.hp:.1f}/{u.max_hp:.1f}  伤害: {u.damage}  射程: {u.attack_range}'
            if u.is_action_done:
                info2 += '  [已行动]'
            t2 = self.font.render(info2, True, COLOR_WHITE)
            self.screen.blit(t2, (10, 40))

        # HQ 菜单（由 Game 触发绘制）
        pass  # 由 Game 在事件循环中绘制

        # Game Over
        if self.engine.game_state == 'GAME_OVER':
            winner = self.engine.check_win_condition()
            if winner:
                msg = f'{winner.name} 获胜！'
                overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT))
                overlay.set_alpha(160)
                overlay.fill(COLOR_BLACK)
                self.screen.blit(overlay, (0, 0))
                t = self.font_title.render(msg, True, COLOR_GOLD)
                r = t.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2))
                self.screen.blit(t, r)

    def _draw_hq_menu(self, building):
        """在建筑旁绘制菜单"""
        sx, sy = self.cam.grid_to_screen(building.grid_x, building.grid_y)
        cx, cy = int(sx), int(sy - 80)
        # 背景
        bw, bh = 144, 200
        pygame.draw.rect(self.screen, (20, 20, 30, 200),
                         (cx - 2, cy - 2, bw + 4, bh + 4))
        pygame.draw.rect(self.screen, COLOR_GRAY,
                         (cx - 2, cy - 2, bw + 4, bh + 4), 1)
        # 标题
        t = self.font.render(f'T{building.tier + 1} 大本营', True, COLOR_GOLD)
        self.screen.blit(t, (cx + 4, cy + 4))


# ============================================================
# 主游戏类
# ============================================================
class Game:
    def __init__(self, player_count=2):
        pygame.init()
        self.screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.RESIZABLE)
        pygame.display.set_caption('绿色军团 — 热座回合制策略游戏')
        self._fullscreen = False
        self.clock = pygame.time.Clock()
        self.running = True

        map_pixels = MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE
        self.camera = Camera(*map_pixels)
        self.grid = Grid(MAP_WIDTH, MAP_HEIGHT)
        self.selection = SelectionManager()
        self.engine = GameEngine(player_count)
        self.renderer = Renderer(
            self.screen, self.camera, self.grid, self.selection, self.engine)

        # 初始化地图实体
        self._place_initial_entities()

        self._setup_buttons()
        self.renderer.buttons = self.buttons
        self.renderer.hq_buttons = self.hq_menu_buttons

        # 连接选择管理器到玩家建筑列表
        self.selection._get_player_buildings = lambda pid: [
            b for p in self.engine.players if p.player_id == pid
            for b in p.buildings
        ]

    def _place_initial_entities(self):
        """放置初始大本营和据点"""
        corners = [(2, 2), (MAP_WIDTH - 3, 2), (2, MAP_HEIGHT - 3), (MAP_WIDTH - 3, MAP_HEIGHT - 3)]
        for i, p in enumerate(self.engine.players):
            if i < len(corners):
                cx, cy = corners[i]
                b = Building('大本营', cx, cy, i)
                self.grid.place(b, cx, cy)
                p.add_building(b)
                p.gold = 10  # 初始资金

        # 放置中立据点
        outposts = [(MAP_WIDTH // 2, MAP_HEIGHT // 2),
                    (MAP_WIDTH // 4, MAP_HEIGHT // 4 * 3),
                    (MAP_WIDTH // 4 * 3, MAP_HEIGHT // 4)]
        for ox, oy in outposts:
            if not self.grid.get_tile(ox, oy).occupant:
                op = Building('据点', ox, oy, -1)  # -1 = 中立
                self.grid.place(op, ox, oy)

    def _setup_buttons(self):
        bw, bh = 120, 32
        self.buttons = {
            'skip': Button(10, SCREEN_HEIGHT - 50, bw, bh, '跳过', COLOR_DARK),
            'station': Button(140, SCREEN_HEIGHT - 50, bw, bh, '驻扎', (0, 60, 0)),
            'end_turn': Button(SCREEN_WIDTH - 140, SCREEN_HEIGHT - 50, 130, bh, '结束回合', COLOR_BLUE),
        }
        self.hq_menu_buttons = []
        self.hq_menu_open = False

    def _update_hq_menu(self, building):
        """生成大本营菜单按钮"""
        self.hq_menu_buttons.clear()
        if not building:
            return
        player = self.engine.get_current_player()
        bx, by = building.grid_x, building.grid_y
        sx, sy = self.camera.grid_to_screen(bx, by)
        cx, cy = int(sx), int(sy - 80)
        bw, bh = 140, 28
        y_off = 0

        # 升级按钮
        if building.can_upgrade():
            cost = building.upgrade_cost
            can_afford = player.gold >= cost
            self.hq_menu_buttons.append(
                Button(cx, cy + y_off, bw, bh,
                       f'T{building.tier + 2} (🪙{cost})',
                       COLOR_BLUE if can_afford else COLOR_GRAY)
            )
            self.hq_menu_buttons[-1].action = ('upgrade', building)
            y_off += bh + 4

        # 招募按钮（当前Tier解锁的单位）
        recruit_pool = ['士兵']
        if building.tier >= 1:
            recruit_pool.extend(['坦克', '军用吉普', '野战炮', '装甲车'])
        if building.tier >= 2:
            recruit_pool.extend(['火箭炮', '战斗机', '轰炸机', '防空车'])
        for utype in recruit_pool:
            cost = UNIT_DATA[utype]['price']
            can_afford = player.gold >= cost
            self.hq_menu_buttons.append(
                Button(cx, cy + y_off, bw, bh,
                       f'{utype} (🪙{int(cost)})',
                       COLOR_DARK if can_afford else COLOR_GRAY)
            )
            self.hq_menu_buttons[-1].action = ('recruit', building, utype)
            y_off += bh + 4

        # 关闭按钮
        self.hq_menu_buttons.append(
            Button(cx, cy + y_off, bw, bh, '关闭', COLOR_RED)
        )
        self.hq_menu_buttons[-1].action = ('close',)

    def _execute_hq_action(self, action):
        if not action:
            return
        player = self.engine.get_current_player()
        if action[0] == 'upgrade':
            b = action[1]
            if player.gold >= b.upgrade_cost:
                player.gold -= b.upgrade_cost
                b.start_upgrade()
                self.hq_menu_open = False
        elif action[0] == 'recruit':
            b = action[1]
            utype = action[2]
            cost = UNIT_DATA[utype]['price']
            if player.gold >= cost:
                player.gold -= cost
                # 在大本营旁边生成单位
                spawn_pos = self._find_spawn_pos(b.grid_x, b.grid_y)
                if spawn_pos:
                    u = Unit(utype, *spawn_pos, player.player_id)
                    self.grid.place(u, *spawn_pos)
                    player.add_unit(u)
        elif action[0] == 'close':
            self.hq_menu_open = False

    def _find_spawn_pos(self, bx, by):
        """在大本营附近找空位"""
        for r in range(1, 4):
            for dx in range(-r, r + 1):
                for dy in range(-r, r + 1):
                    if abs(dx) + abs(dy) == r:
                        nx, ny = bx + dx, by + dy
                        if self.grid.in_bounds(nx, ny):
                            tile = self.grid.get_tile(nx, ny)
                            if tile and not tile.occupant:
                                return nx, ny
        return None

    def handle_event(self, event):
        if event.type == pygame.QUIT:
            self.running = False

        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.selection.clear()
                self.hq_menu_open = False
            if event.key == pygame.K_F11:
                self._fullscreen = not self._fullscreen
                if self._fullscreen:
                    self.screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
                else:
                    self.screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.RESIZABLE)
                self.renderer.screen = self.screen
            if event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                if self.selection.selected_unit and self.selection.selected_unit.can_skip():
                    self.selection.skip_unit()
                else:
                    self.engine.next_turn()

        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # 左键
                mx, my = event.pos

                # 检查 HQ 菜单按钮
                if self.hq_menu_open:
                    for btn in self.hq_menu_buttons:
                        if btn.is_hovered((mx, my)):
                            self._execute_hq_action(btn.action)
                            return

                # 检查主 UI 按钮
                for name, btn in self.buttons.items():
                    if btn.is_hovered((mx, my)):
                        if name == 'skip' and self.selection.selected_unit:
                            self.selection.skip_unit()
                        elif name == 'station' and self.selection.selected_unit:
                            self._try_station()
                        elif name == 'end_turn':
                            self.engine.next_turn()
                            self.selection.clear()
                        return

                # 地图点击
                gx, gy = self.camera.screen_to_grid(mx, my)
                self.selection.handle_click(gx, gy, self.engine, self.grid)
                self.camera.start_drag(mx, my)

            elif event.button == 4:  # 滚轮上（放大）
                self.camera.zoom_at(*event.pos, 0.15)
            elif event.button == 5:  # 滚轮下（缩小）
                self.camera.zoom_at(*event.pos, -0.15)

        elif event.type == pygame.MOUSEBUTTONUP:
            if event.button == 1:
                self.camera.end_drag()

        elif event.type == pygame.MOUSEMOTION:
            gx, gy = self.camera.screen_to_grid(*event.pos)
            self.renderer.set_hover(gx, gy)
            if event.buttons[0]:
                self.camera.update_drag(*event.pos)

        elif event.type == pygame.MOUSEWHEEL:
            mx, my = pygame.mouse.get_pos()
            if event.y > 0:
                self.camera.zoom_at(mx, my, 0.15)
            else:
                self.camera.zoom_at(mx, my, -0.15)

    def _try_station(self):
        unit = self.selection.selected_unit
        if not unit or unit.is_action_done:
            return
        player = self.engine.get_current_player()
        for b in player.buildings:
            if b.building_type == '大本营' and b.in_heal_range(unit.grid_x, unit.grid_y):
                unit.is_stationed = True
                unit.is_action_done = True
                self.selection.clear()
                return

    def update(self):
        self.camera.update()

        # 更新建筑升级计时
        for p in self.engine.players:
            for b in p.buildings:
                if b.tick_upgrade():
                    self.selection.clear()

        # HQ 菜单更新
        if self.selection.selected_building:
            if self.selection.selected_building.building_type == '大本营':
                self._update_hq_menu(self.selection.selected_building)
                self.hq_menu_open = True

        # 自动结束回合检查
        if self.engine.auto_end_if_no_actions():
            pass  # 玩家可手动点结束回合

        # 选中单位时显示驻扎范围
        if self.selection.selected_unit:
            unit = self.selection.selected_unit
            if not unit.is_action_done:
                player = self.engine.get_current_player()
                for b in player.buildings:
                    if b.building_type == '大本营' and b.in_heal_range(unit.grid_x, unit.grid_y):
                        self.selection.highlight_color = COLOR_HIGHLIGHT_HEAL
                        break

        # WASD 平移
        keys = pygame.key.get_pressed()
        speed = 10 / self.camera.zoom
        if keys[pygame.K_w] or keys[pygame.K_UP]:
            self.camera.pan(0, speed)
        if keys[pygame.K_s] or keys[pygame.K_DOWN]:
            self.camera.pan(0, -speed)
        if keys[pygame.K_a] or keys[pygame.K_LEFT]:
            self.camera.pan(speed, 0)
        if keys[pygame.K_d] or keys[pygame.K_RIGHT]:
            self.camera.pan(-speed, 0)

    def run(self):
        while self.running:
            for event in pygame.event.get():
                self.handle_event(event)
            self.update()
            self.renderer.render()
            pygame.display.flip()
            self.clock.tick(FPS)
        pygame.quit()


# ============================================================
# 渲染 HP 条的临时修补
# ============================================================
# (已在 Renderer._draw_unit 中实现)


# ============================================================
# 入口
# ============================================================
if __name__ == '__main__':
    game = Game(player_count=2)
    game.run()
