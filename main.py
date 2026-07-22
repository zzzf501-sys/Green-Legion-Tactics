#!/usr/bin/env python3
"""
绿色军团 — 热座回合制策略游戏 (v2.0)
======================================
基于 Pygame 的单机热座回合制策略游戏。
80x80 网格、摄像机缩放、9 种兵种、3 级大本营、据点占领。

运行: python main.py
"""

import pygame
import math
import heapq
import os
import webbrowser
import warnings
from collections import deque
warnings.filterwarnings('ignore', category=UserWarning, module='pygame')

# ============================================================
# 常量
# ============================================================
TILE_SIZE = 64
SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
FPS = 60
MIN_ZOOM = 0.4
MAX_ZOOM = 2.5
MAP_WIDTH = 80
MAP_HEIGHT = 80

COLOR_BG = (30, 30, 40)
COLOR_GRID_LIGHT = (60, 65, 50)
COLOR_GRID_DARK = (50, 55, 40)
COLOR_HIGHLIGHT_MOVE = (255, 255, 0, 80)
COLOR_HIGHLIGHT_ATTACK = (255, 0, 0, 80)
COLOR_HIGHLIGHT_HEAL = (0, 255, 0, 80)
COLOR_WHITE = (255, 255, 255)
COLOR_BLACK = (0, 0, 0)
COLOR_RED = (255, 50, 50)
COLOR_GREEN = (50, 255, 50)
COLOR_BLUE = (60, 120, 255)
COLOR_GOLD = (255, 215, 0)
COLOR_GRAY = (100, 100, 100)
COLOR_DARK = (20, 20, 30)

PLAYER_COLORS = [(60, 120, 255), (255, 60, 60), (60, 220, 60), (255, 220, 60)]

# ============================================================
# 数据字典
# ============================================================
UNIT_DATA = {
    '士兵':   {'hp': 1.5, 'armor': 0, 'speed': 3, 'damage': 1, 'range': 2, 'price': 1, 'attacks': 1},
    '坦克':   {'hp': 10, 'armor': 2, 'speed': 5, 'damage': 4, 'range': 3, 'price': 7, 'attacks': 1},
    '军用吉普': {'hp': 3, 'armor': 0, 'speed': 8, 'damage': 2, 'range': 3, 'price': 3, 'attacks': 1},
    '火箭炮': {'hp': 8, 'armor': 0.5, 'speed': 2, 'damage': 7, 'range': 15, 'price': 15, 'attacks': 1},
    '野战炮': {'hp': 4, 'armor': 1, 'speed': 3, 'damage': 5.5, 'range': 8, 'price': 5, 'attacks': 1},
    '装甲车': {'hp': 7, 'armor': 1, 'speed': 5, 'damage': 1.5, 'range': 3, 'price': 6, 'attacks': 3, 'can_target_air': True},
    '战斗机': {'hp': 5, 'armor': 1, 'speed': 10, 'damage': 5.5, 'range': 3, 'price': 8, 'attacks': 1, 'is_air': True, 'can_target_air': True},
    '轰炸机': {'hp': 20, 'armor': 3, 'speed': 5, 'damage': 12, 'range': 1, 'price': 15, 'attacks': 1, 'is_air': True, 'blast': 3, 'reload': 2},
    '防空车': {'hp': 5, 'armor': 1, 'speed': 5, 'damage': 3, 'range': 4, 'price': 10, 'attacks': 1, 'can_target_air': True, 'air_damage': 8, 'air_range': 14},
}
UNIT_NAMES = list(UNIT_DATA.keys())

EQUIP_DATA = {
    '士兵': [{'name':'射手步枪','cost':0.5,'dmg':0.5,'range':4,'speed':-1,'can_target_air':True,'tier':'T2','research_cost':5,'research_time':2},
             {'name':'反器械枪','cost':1.5,'dmg':4,'range':2,'can_target_air':True,'tier':'T2','research_cost':5,'research_time':2}],
    '坦克': [{'name':'穿甲炮','cost':2,'dmg':3,'range':1,'tier':'T3','research_cost':10,'research_time':3},
             {'name':'高爆炮','cost':1,'dmg':-2,'range':0,'blast':3,'tier':'T3','research_cost':10,'research_time':3}],
    '军用吉普': [{'name':'火箭助推','cost':1,'speed':5,'hp':1,'tier':'T2','research_cost':5,'research_time':2}],
    '火箭炮': [{'name':'对空雷达','cost':3,'range':1,'can_target_air':True,'tier':'T3','research_cost':10,'research_time':3}],
    '野战炮': [{'name':'轻量化','cost':-2,'dmg':-1,'hp':-1,'tier':'T2','research_cost':5,'research_time':2},
               {'name':'巨炮','cost':6,'dmg':7,'range':4,'speed':-1,'hp':3,'tier':'T3','research_cost':10,'research_time':3}],
}

BUILDING_DATA = {
    '大本营': {'tiers': [
        {'hp':20,'armor':0,'gold':3,'upgrade_cost':10,'upgrade_time':3},
        {'hp':50,'armor':0.5,'gold':5,'upgrade_cost':30,'upgrade_time':8,'turret':{'damage':2,'attacks':2,'range':5}},
        {'hp':120,'armor':1,'gold':8,'upgrade_cost':None,'upgrade_time':None,'turret':{'damage':3,'attacks':3,'range':8}},
    ]},
    '资源采集器': {'hp':15,'armor':0,'gold':3,'cost':8},
    '据点': {'hp':20,'armor':0,'gold':3,'capture_turret':{'damage':2,'attacks':2,'range':5}},
}

# ============================================================
# 字体加载
# ============================================================
_FONT_CACHE = {}
def load_font(size):
    if size in _FONT_CACHE:
        return _FONT_CACHE[size]
    paths = [
        'C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/simhei.ttf',
        'C:/Windows/Fonts/simsun.ttc', 'C:/Windows/Fonts/msyhbd.ttc',
        'C:/Windows/Fonts/yahei.ttf', 'C:/Windows/Fonts/msyhl.ttc',
    ]
    for fp in paths:
        if os.path.exists(fp):
            try:
                f = pygame.font.Font(fp, size)
                _FONT_CACHE[size] = f
                return f
            except:
                continue
    f = pygame.font.Font(None, size)
    _FONT_CACHE[size] = f
    return f

def load_image(path, size=None):
    try:
        img = pygame.image.load(path).convert_alpha()
        if size: img = pygame.transform.scale(img, size)
        return img
    except:
        return None

def apply_equip(stats, equip):
    if not equip: return dict(stats)
    s = dict(stats)
    s['damage'] = s.get('damage',0) + equip.get('dmg',0)
    s['range'] = s.get('range',0) + equip.get('range',0)
    s['speed'] = s.get('speed',0) + equip.get('speed',0)
    s['hp'] = max(0.5, s.get('hp',1) + equip.get('hp',0))
    s['price'] = s.get('price',0) + equip.get('cost',0)
    s['can_target_air'] = s.get('can_target_air',False) or equip.get('can_target_air',False)
    if equip.get('blast'): s['blast'] = equip['blast']
    return s

def neighbors(gx, gy):
    for dx, dy in [(0,1),(0,-1),(1,0),(-1,0)]: yield gx+dx, gy+dy

def manhattan(a, b):
    return abs(a[0]-b[0]) + abs(a[1]-b[1])

# ============================================================
# 按钮
# ============================================================
class Button:
    def __init__(self, x, y, w, h, text, color=COLOR_DARK, text_color=COLOR_WHITE, font_size=16):
        self.rect = pygame.Rect(x, y, w, h)
        self.text = text
        self.color = color
        self.text_color = text_color
        self.visible = True
        self.font_size = font_size
        self._click_flash = 0

    def click(self):
        self._click_flash = 8

    def draw(self, screen):
        if not self.visible: return
        c = self.color
        if self._click_flash > 0:
            br = min(60, self._click_flash * 8)
            c = tuple(min(255, v+br) for v in self.color)
            self._click_flash -= 1
        pygame.draw.rect(screen, c, self.rect, border_radius=4)
        pygame.draw.rect(screen, COLOR_GRAY, self.rect, 1, border_radius=4)
        label = load_font(self.font_size).render(self.text, True, self.text_color)
        lr = label.get_rect(center=self.rect.center)
        screen.blit(label, lr)

    def is_hovered(self, pos):
        return self.visible and self.rect.collidepoint(pos)

# ============================================================
# 摄像机
# ============================================================
class Camera:
    def __init__(self, map_pixels_w, map_pixels_h, scr_w=SCREEN_WIDTH, scr_h=SCREEN_HEIGHT):
        self.map_w = map_pixels_w
        self.map_h = map_pixels_h
        self.scr_w = scr_w
        self.scr_h = scr_h
        self.offset_x = 0; self.offset_y = 0
        self.zoom = 1.0; self.target_zoom = 1.0
        self.target_offset_x = 0; self.target_offset_y = 0
        self._dragging = False; self._drag_start = (0,0); self._drag_offset = (0,0)

    def world_to_screen(self, wx, wy):
        return wx*self.zoom+self.offset_x, wy*self.zoom+self.offset_y
    def screen_to_world(self, sx, sy):
        return (sx-self.offset_x)/self.zoom, (sy-self.offset_y)/self.zoom
    def screen_to_grid(self, sx, sy):
        wx,wy = self.screen_to_world(sx,sy); return int(wx//TILE_SIZE), int(wy//TILE_SIZE)
    def grid_to_screen(self, gx, gy):
        return self.world_to_screen(gx*TILE_SIZE, gy*TILE_SIZE)

    def center_on(self, gx, gy):
        """将摄像机中心对准网格坐标"""
        wx, wy = gx * TILE_SIZE, gy * TILE_SIZE
        self.target_offset_x = self.scr_w/2 - wx*self.zoom
        self.target_offset_y = self.scr_h/2 - wy*self.zoom
        self._clamp_offset(self.scr_w, self.scr_h)

    def pan(self, dx, dy):
        self.target_offset_x += dx; self.target_offset_y += dy
        self._clamp_offset(self.scr_w, self.scr_h)

    def start_drag(self, sx, sy):
        self._dragging = True; self._drag_start = (sx,sy); self._drag_offset = (self.offset_x,self.offset_y)

    def update_drag(self, sx, sy):
        if self._dragging:
            self.target_offset_x = self._drag_offset[0] + (sx-self._drag_start[0])
            self.target_offset_y = self._drag_offset[1] + (sy-self._drag_start[1])
            self._clamp_offset(self.scr_w, self.scr_h)

    def end_drag(self): self._dragging = False

    def zoom_at(self, sx, sy, delta):
        wx = (sx-self.offset_x)/self.zoom; wy = (sy-self.offset_y)/self.zoom
        self.target_zoom = max(MIN_ZOOM, min(MAX_ZOOM, self.target_zoom+delta))
        self.target_offset_x = sx - wx*self.target_zoom
        self.target_offset_y = sy - wy*self.target_zoom
        self._clamp_offset(self.scr_w, self.scr_h)

    def get_visible_rect(self):
        l,t = self.screen_to_world(0,0); r,b = self.screen_to_world(self.scr_w,self.scr_h)
        return max(0,int(l//TILE_SIZE)), max(0,int(t//TILE_SIZE)), min(MAP_WIDTH-1,int(r//TILE_SIZE)+1), min(MAP_HEIGHT-1,int(b//TILE_SIZE)+1)

    def update(self):
        lr = 0.15
        self.zoom += (self.target_zoom-self.zoom)*lr
        self.offset_x += (self.target_offset_x-self.offset_x)*lr
        self.offset_y += (self.target_offset_y-self.offset_y)*lr

    def _clamp_offset(self, scr_w=None, scr_h=None):
        sw = scr_w or SCREEN_WIDTH; sh = scr_h or SCREEN_HEIGHT
        max_ox = self.map_w*self.zoom-sw; max_oy = self.map_h*self.zoom-sh
        self.target_offset_x = max(min(self.target_offset_x, 10), -max_ox-10)
        self.target_offset_y = max(min(self.target_offset_y, 10), -max_oy-10)

# ============================================================
# 瓦片与网格
# ============================================================
class Tile:
    def __init__(self, gx, gy, terrain='grass'):
        self.gx = gx; self.gy = gy; self.terrain = terrain; self.occupant = None
    @property
    def movement_cost(self):
        return {'grass':1,'road':0.5,'forest':2,'water':99,'mountain':3}.get(self.terrain,1)

class Grid:
    def __init__(self, w, h):
        self.width = w; self.height = h
        self.tiles = [[Tile(x,y) for y in range(h)] for x in range(w)]
        import random; random.seed(42)
        for x in range(w):
            for y in range(h):
                r = random.random()
                if r < 0.03: self.tiles[x][y].terrain='water'
                elif r < 0.08: self.tiles[x][y].terrain='forest'
                elif r < 0.10: self.tiles[x][y].terrain='mountain'
    def in_bounds(self, x, y): return 0<=x<self.width and 0<=y<self.height
    def get_tile(self, x, y): return self.tiles[x][y] if self.in_bounds(x,y) else None
    def place(self, e, x, y):
        t = self.get_tile(x,y)
        if t: t.occupant = e; e.grid_x, e.grid_y = x, y
    def remove(self, e):
        t = self.get_tile(e.grid_x, e.grid_y)
        if t and t.occupant is e: t.occupant = None

# ============================================================
# 实体
# ============================================================
class Entity:
    def __init__(self, name, gx, gy, pid):
        self.name = name; self.grid_x = gx; self.grid_y = gy; self.player_id = pid; self.sprite = None

class Unit(Entity):
    def __init__(self, utype, gx, gy, pid, equip=None):
        super().__init__(utype, gx, gy, pid)
        self.unit_type = utype
        s = apply_equip(UNIT_DATA[utype], equip)
        self.max_hp = s['hp']; self.hp = s['hp']; self.armor = s['armor']
        self.speed = s['speed']; self.damage = s['damage']; self.attack_range = s['range']
        self.attacks_per_turn = s.get('attacks',1); self.price = s['price']
        self.is_air = s.get('is_air',False); self.can_target_air = s.get('can_target_air',False)
        self.blast = s.get('blast',1); self.reload = s.get('reload',0); self.equip = equip
        self.has_moved=False; self.has_attacked=False; self.is_action_done=False
        self.is_stationed=False; self._reload_counter=0
    def reset_turn(self):
        self.has_moved=False; self.has_attacked=False; self.is_action_done=False
        if self._reload_counter>0: self._reload_counter-=1
    def can_move(self): return not self.has_moved and not self.is_action_done
    def can_attack(self): return self.has_moved and not self.has_attacked and not self.is_action_done and self._reload_counter==0
    def can_skip(self): return not self.is_action_done
    def move_to(self, gx, gy): self.grid_x=gx; self.grid_y=gy; self.has_moved=True
    def get_effective_range(self, t): return self.air_range if t and t.is_air and hasattr(self,'air_range') and self.air_range else self.attack_range
    def get_effective_damage(self, t): return self.air_damage if t and t.is_air and hasattr(self,'air_damage') and self.air_damage else self.damage
    def attack_target(self, t):
        dmg = max(0, self.get_effective_damage(t)-t.armor)
        total = dmg*self.attacks_per_turn*self.blast
        t.take_damage(total)
        self.has_attacked=True; self.is_action_done=True
        if self.reload>0: self._reload_counter=self.reload
        return total
    def take_damage(self, a): a=min(a,self.hp); self.hp-=a; return a
    @property
    def is_dead(self): return self.hp<=0

class Building(Entity):
    def __init__(self, bt, gx, gy, pid, tier=0):
        super().__init__(bt, gx, gy, pid)
        self.building_type=bt; self.tier=tier; self.is_upgrading=False; self.upgrade_timer=0
        self.is_captured=False; self.turns_since_damaged=0; self._damaged_this_turn=False
        self.gold_per_turn=0; self.turret=None; self._update_tier_stats()
    def _update_tier_stats(self):
        d=BUILDING_DATA.get(self.building_type,{})
        if self.building_type=='大本营':
            t=d['tiers'][self.tier]; self.max_hp=t['hp']; self.hp=getattr(self,'hp',t['hp'])
            self.armor=t['armor']; self.gold_per_turn=t['gold']
            self.upgrade_cost=t.get('upgrade_cost'); self.upgrade_time=t.get('upgrade_time')
            self.turret=t.get('turret')
        elif self.building_type=='据点':
            self.max_hp=d['hp']; self.hp=getattr(self,'hp',d['hp']); self.armor=d['armor']
            self.gold_per_turn=d['gold'] if self.is_captured else 0
            self.upgrade_cost=None; self.upgrade_time=None
            self.turret=d.get('capture_turret') if self.is_captured else None
        else:
            self.max_hp=d['hp']; self.hp=getattr(self,'hp',d['hp']); self.armor=d['armor']
            self.gold_per_turn=d['gold']; self.upgrade_cost=None; self.upgrade_time=None; self.turret=None
    def capture(self, pid):
        self.player_id=pid; self.is_captured=True
        self.hp=min(self.max_hp, self.hp+int(self.max_hp*0.3))
        self._update_tier_stats(); self.turns_since_damaged=0
    def take_damage(self, a):
        a=min(a,self.hp); self.hp-=a; self._damaged_this_turn=True; self.turns_since_damaged=0; return a
    def on_turn_start(self):
        if self._damaged_this_turn: self.turns_since_damaged=0
        else: self.turns_since_damaged+=1
        self._damaged_this_turn=False
        if self.turns_since_damaged>=3 and self.hp<self.max_hp:
            self.hp=min(self.max_hp, self.hp+2)
    @property
    def is_dead(self): return self.hp<=0
    def can_upgrade(self): return self.building_type=='大本营' and self.tier<2 and not self.is_upgrading
    def start_upgrade(self):
        if self.can_upgrade(): self.is_upgrading=True; self.upgrade_timer=self.upgrade_time
    def tick_upgrade(self):
        if self.is_upgrading:
            self.upgrade_timer-=1
            if self.upgrade_timer<=0:
                self.tier+=1; self.is_upgrading=False; self.hp=self.max_hp; self._update_tier_stats(); return True
        return False
    def in_heal_range(self, gx, gy): return manhattan((self.grid_x,self.grid_y),(gx,gy))<=2

# ============================================================
# 寻路
# ============================================================
class Pathfinder:
    @staticmethod
    def compute_move_range(grid, start, max_moves, unit=None):
        sx,sy=start
        if not grid.in_bounds(sx,sy): return set()
        cost={(sx,sy):0}; q=deque([(sx,sy)])
        while q:
            cx,cy=q.popleft(); c=cost[(cx,cy)]
            for nx,ny in neighbors(cx,cy):
                if not grid.in_bounds(nx,ny): continue
                t=grid.get_tile(nx,ny); occ=t.occupant
                if occ and occ!=unit and occ.player_id!=unit.player_id: continue
                nc=c+t.movement_cost
                if nc<=max_moves and (nx,ny) not in cost: cost[(nx,ny)]=nc; q.append((nx,ny))
        r=set(cost.keys()); r.discard(start); return r
    @staticmethod
    def find_path(grid, start, goal, unit=None):
        sx,sy=start; gx,gy=goal
        if not grid.in_bounds(sx,sy) or not grid.in_bounds(gx,gy): return []
        q=[(0,sx,sy)]; came={(sx,sy):None}; cost={(sx,sy):0}
        while q:
            _,cx,cy=heapq.heappop(q)
            if (cx,cy)==(gx,gy): break
            for nx,ny in neighbors(cx,cy):
                if not grid.in_bounds(nx,ny): continue
                t=grid.get_tile(nx,ny); occ=t.occupant
                if (nx,ny)!=(gx,gy) and occ and occ.player_id!=(unit.player_id if unit else -2): continue
                nc=cost[(cx,cy)]+t.movement_cost
                if (nx,ny) not in cost or nc<cost[(nx,ny)]:
                    cost[(nx,ny)]=nc; heapq.heappush(q,(nc+abs(nx-gx)+abs(ny-gy),nx,ny)); came[(nx,ny)]=(cx,cy)
        if (gx,gy) not in came: return []
        p=[]; cur=(gx,gy)
        while cur!=(sx,sy): p.append(cur); cur=came[cur]
        p.reverse(); return p
    @staticmethod
    def get_tiles_in_range(grid, center, radius):
        cx,cy=center; r=set()
        for dx in range(-radius,radius+1):
            for dy in range(-radius,radius+1):
                if abs(dx)+abs(dy)<=radius:
                    nx,ny=cx+dx,cy+dy
                    if grid.in_bounds(nx,ny): r.add((nx,ny))
        return r

# ============================================================
# 选择管理器
# ============================================================
class SelectionManager:
    def __init__(self):
        self.selected_unit=None; self.selected_building=None
        self.highlight_tiles=set(); self.highlight_color=COLOR_HIGHLIGHT_MOVE
        self.action_phase='SELECT_UNIT'
    def clear(self):
        self.selected_unit=None; self.selected_building=None; self.highlight_tiles.clear(); self.action_phase='SELECT_UNIT'
    def select_unit(self, unit, grid):
        self.selected_unit=unit; self.selected_building=None
        if unit.can_move():
            self.highlight_tiles=Pathfinder.compute_move_range(grid,(unit.grid_x,unit.grid_y),unit.speed,unit)
            self.highlight_color=COLOR_HIGHLIGHT_MOVE; self.action_phase='MOVE_PHASE'
        else: self._show_attack_range(unit,grid); self.action_phase='ATTACK_PHASE'
    def _show_attack_range(self, unit, grid):
        if unit.can_attack():
            self.highlight_tiles=Pathfinder.get_tiles_in_range(grid,(unit.grid_x,unit.grid_y),unit.attack_range)
            self.highlight_color=COLOR_HIGHLIGHT_ATTACK
        else: self.highlight_tiles.clear()
    def handle_click(self, gx, gy, engine, grid):
        p=engine.get_current_player(); t=grid.get_tile(gx,gy)
        if not t: return
        occ=t.occupant
        if self.action_phase=='SELECT_UNIT':
            if occ and occ.player_id==p.player_id:
                if isinstance(occ,Building) and occ.building_type=='大本营': self.selected_building=occ; return
                elif isinstance(occ,Unit): self.select_unit(occ,grid); return
            self.clear()
        elif self.action_phase=='MOVE_PHASE':
            u=self.selected_unit
            if not u: return
            if (gx,gy) in self.highlight_tiles:
                ot=grid.get_tile(u.grid_x,u.grid_y)
                if ot: ot.occupant=None
                u.move_to(gx,gy); t.occupant=u
                if u.can_attack():
                    at=Pathfinder.get_tiles_in_range(grid,(gx,gy),u.attack_range); en=set()
                    for tx,ty in at:
                        tt=grid.get_tile(tx,ty)
                        if tt and tt.occupant and tt.occupant.player_id!=p.player_id: en.add((tx,ty))
                    if en: self.highlight_tiles=en; self.highlight_color=COLOR_HIGHLIGHT_ATTACK; self.action_phase='ATTACK_PHASE'; return
                u.is_action_done=True; self.clear()
            elif occ and isinstance(occ,Unit) and occ.player_id==p.player_id: self.select_unit(occ,grid)
            else: self.clear()
        elif self.action_phase=='ATTACK_PHASE':
            u=self.selected_unit
            if not u: return
            if (gx,gy) in self.highlight_tiles:
                tt=grid.get_tile(gx,gy)
                if tt and tt.occupant and tt.occupant.player_id!=p.player_id:
                    target=tt.occupant; u.attack_target(target)
                    if isinstance(target,Unit) and target.is_dead: grid.remove(target); p.remove_unit(target)
                    elif isinstance(target,Building):
                        if target.is_dead and target.building_type=='据点' and not target.is_captured:
                            target.capture(p.player_id); p.add_building(target)
                            for pp in engine.players:
                                if pp.player_id!=p.player_id and target in pp.buildings: pp.remove_building(target)
                        elif target.is_dead:
                            grid.remove(target)
                            for pp in engine.players:
                                if target in pp.buildings: pp.remove_building(target); break
                    self.clear(); engine.auto_end_if_no_actions(); return
            self.clear()
    def skip_unit(self):
        if self.selected_unit and self.selected_unit.can_skip(): self.selected_unit.is_action_done=True; self.clear()

# ============================================================
# 玩家
# ============================================================
class Player:
    def __init__(self, pid, name):
        self.player_id=pid; self.name=name; self.gold=10; self.units=[]; self.buildings=[]; self.is_alive=True
    def add_unit(self, u): self.units.append(u)
    def remove_unit(self, u):
        if u in self.units: self.units.remove(u)
        if not self.units and not any(b.building_type=='大本营' for b in self.buildings): self.is_alive=False
    def add_building(self, b): self.buildings.append(b)
    def remove_building(self, b):
        if b in self.buildings: self.buildings.remove(b)
        if b.building_type=='大本营' and not any(b2.building_type=='大本营' for b2 in self.buildings): self.is_alive=False
    def collect_income(self):
        for b in self.buildings: self.gold+=b.gold_per_turn
    def on_turn_start(self):
        for u in self.units:
            u.reset_turn()
            if u.is_stationed:
                for b in self.buildings:
                    if b.building_type=='大本营' and b.in_heal_range(u.grid_x,u.grid_y): u.hp=min(u.max_hp,u.hp+1); break
            u.is_stationed=False
        for b in self.buildings: b.on_turn_start()
        self.collect_income()
    def get_hq(self):
        for b in self.buildings:
            if b.building_type=='大本营': return b
        return None

# ============================================================
# 游戏引擎
# ============================================================
class GameEngine:
    def __init__(self, count=2):
        self.players=[]; self.current_player_index=0; self.turn_number=1; self.game_state='PLAYING'
        for i in range(count): self.players.append(Player(i,f'玩家{i+1}'))
    def get_current_player(self): return self.players[self.current_player_index]
    def next_turn(self):
        self.turn_number+=1
        for _ in range(len(self.players)):
            self.current_player_index=(self.current_player_index+1)%len(self.players)
            if self.get_current_player().is_alive: break
        self.get_current_player().on_turn_start()
        return self.check_win_condition()
    def check_win_condition(self):
        alive=[p for p in self.players if p.is_alive]
        if len(alive)<=1: self.game_state='GAME_OVER'; return alive[0] if alive else None
        return None
    def auto_end_if_no_actions(self):
        return all(u.is_action_done for u in self.get_current_player().units)

# ============================================================
# 渲染器
# ============================================================
class Renderer:
    def __init__(self, screen, camera, grid, selection, engine):
        self.screen=screen; self.cam=camera; self.grid=grid; self.sel=selection; self.engine=engine
        self._sprite_cache={}; self._hover_gx=-1; self._hover_gy=-1
        self.buttons={}; self.hq_buttons=[]
    def set_hover(self, gx, gy): self._hover_gx=gx; self._hover_gy=gy
    def _get_sprite(self, name, size=(TILE_SIZE,TILE_SIZE)):
        if name not in self._sprite_cache:
            self._sprite_cache[name]=load_image(f'picture/{name}.png',size)
        return self._sprite_cache[name]
    def sw(self): return self.cam.scr_w
    def sh(self): return self.cam.scr_h
    def render(self):
        self.screen.fill(COLOR_BG); vr=self.cam.get_visible_rect()
        for gx in range(vr[0],vr[2]):
            for gy in range(vr[1],vr[3]): self._draw_tile(gx,gy)
        for gx,gy in self.sel.highlight_tiles:
            if vr[0]<=gx<=vr[2] and vr[1]<=gy<=vr[3]: self._draw_highlight(gx,gy,self.sel.highlight_color)
        for p in self.engine.players:
            for b in p.buildings:
                if vr[0]<=b.grid_x<=vr[2] and vr[1]<=b.grid_y<=vr[3]: self._draw_building(b)
        for p in self.engine.players:
            for u in p.units:
                if vr[0]<=u.grid_x<=vr[2] and vr[1]<=u.grid_y<=vr[3]: self._draw_unit(u)
        if self.sel.selected_building and self.sel.selected_building.building_type=='大本营':
            self._draw_hq_panel(self.sel.selected_building)
            for btn in self.hq_buttons: btn.draw(self.screen)
        self._draw_hud(); self._draw_tooltip()
    def _draw_tile(self, gx, gy):
        sx,sy=self.cam.grid_to_screen(gx,gy); t=self.grid.get_tile(gx,gy)
        if not t: return
        base=COLOR_GRID_LIGHT if (gx+gy)%2==0 else COLOR_GRID_DARK
        tc={'water':(40,50,80),'forest':(30,60,30),'mountain':(60,55,40),'road':(55,50,45)}
        c=tc.get(t.terrain,base); sz=TILE_SIZE*self.cam.zoom
        r=pygame.Rect(sx,sy,sz,sz); pygame.draw.rect(self.screen,c,r); pygame.draw.rect(self.screen,(40,40,40),r,1)
    def _draw_highlight(self, gx, gy, color):
        sx,sy=self.cam.grid_to_screen(gx,gy); sz=TILE_SIZE*self.cam.zoom
        s=pygame.Surface((sz,sz),pygame.SRCALPHA); s.fill(color); self.screen.blit(s,(sx,sy))
    def _draw_unit(self, unit):
        sx,sy=self.cam.grid_to_screen(unit.grid_x,unit.grid_y); sz=TILE_SIZE*self.cam.zoom
        sp=self._get_sprite(unit.unit_type)
        if sp:
            sc=pygame.transform.scale(sp,(int(sz),int(sz))); self.screen.blit(sc,(sx,sy))
        else:
            c=PLAYER_COLORS[unit.player_id]; pygame.draw.circle(self.screen,c,(int(sx+sz/2),int(sy+sz/2)),int(sz/2.5))
            pygame.draw.circle(self.screen,COLOR_WHITE,(int(sx+sz/2),int(sy+sz/2)),int(sz/2.5),1)
        if not unit.is_action_done:
            pygame.draw.circle(self.screen,COLOR_WHITE,(int(sx+sz/2),int(sy+sz/2)),int(sz/2.2),2)
        bw=int(sz*0.8); bh=max(3,int(sz*0.08)); bx=sx+(sz-bw)/2; by=sy+sz-bh-2
        r=unit.hp/unit.max_hp; hc=COLOR_GREEN if r>0.5 else COLOR_GOLD if r>0.25 else COLOR_RED
        pygame.draw.rect(self.screen,COLOR_DARK,(bx,by,bw,bh)); pygame.draw.rect(self.screen,hc,(bx,by,bw*r,bh))
    def _draw_building(self, building):
        sx,sy=self.cam.grid_to_screen(building.grid_x,building.grid_y); sz=TILE_SIZE*self.cam.zoom
        if building.building_type=='大本营': sp=self._get_sprite(f'大本营 T{building.tier+1}')
        elif building.building_type=='据点': sp=self._get_sprite('据点')
        else: sp=self._get_sprite(building.building_type)
        if sp:
            sc=pygame.transform.scale(sp,(int(sz*1.2),int(sz*1.2)))
            self.screen.blit(sc,(sx-sz*0.1,sy-sz*0.1))
        else:
            c=PLAYER_COLORS[max(0,building.player_id)] if building.player_id>=0 else COLOR_GRAY
            r=pygame.Rect(sx,sy,sz,sz); pygame.draw.rect(self.screen,c,r); pygame.draw.rect(self.screen,COLOR_WHITE,r,2)
            self.screen.blit(load_font(16).render(building.building_type[:2],True,COLOR_WHITE),(sx+4,sy+4))
        spr_x=sx-sz*0.1; spr_w=sz*1.2; bw=int(spr_w*0.7); bh=max(3,int(sz*0.08))
        bx=spr_x+(spr_w-bw)/2; by=sy-8
        r=building.hp/building.max_hp; hc=COLOR_GREEN if r>0.5 else COLOR_GOLD if r>0.25 else COLOR_RED
        pygame.draw.rect(self.screen,COLOR_DARK,(bx,by,bw,bh)); pygame.draw.rect(self.screen,hc,(bx,by,bw*r,bh))
    def _draw_hq_panel(self, building):
        pygame.draw.rect(self.screen,(15,15,25,220),(0,30,204,self.sh()-30))
        pygame.draw.rect(self.screen,COLOR_GRAY,(0,30,204,self.sh()-30),1)
    def _draw_hud(self):
        p=self.engine.get_current_player(); pc=PLAYER_COLORS[p.player_id]
        pygame.draw.rect(self.screen,COLOR_DARK,(0,0,self.sw(),34))
        load_font(24).render(f' {p.name}  |  回合 {self.engine.turn_number}  |  🪙{p.gold}',True,pc)
        for name,btn in self.buttons.items():
            if self.engine.game_state!='PLAYING': btn.visible=False; continue
            if name=='skip': btn.visible=bool(self.sel.selected_unit and self.sel.selected_unit.can_skip())
            elif name=='station':
                u=self.sel.selected_unit; can=False
                if u and not u.is_action_done:
                    for b in p.buildings:
                        if b.building_type=='大本营' and b.in_heal_range(u.grid_x,u.grid_y): can=True; break
                btn.visible=can
            btn.draw(self.screen)
        if self.sel.selected_unit:
            u=self.sel.selected_unit
            t2=f'{u.unit_type}  HP:{u.hp:.1f}/{u.max_hp:.1f}  伤害:{u.damage}  射程:{u.attack_range}'+('  [Done]' if u.is_action_done else '')
            self.screen.blit(load_font(16).render(t2,True,COLOR_WHITE),(10,40))
        if self.engine.game_state=='GAME_OVER':
            w=self.engine.check_win_condition()
            if w:
                s=pygame.Surface((self.sw(),self.sh())); s.set_alpha(160); s.fill(COLOR_BLACK); self.screen.blit(s,(0,0))
                t=load_font(32).render(f'{w.name} 获胜！',True,COLOR_GOLD)
                self.screen.blit(t,t.get_rect(center=(self.sw()//2,self.sh()//2)))
    def _draw_tooltip(self):
        gx,gy=self._hover_gx,self._hover_gy
        if gx<0 or gy<0: return
        t=self.grid.get_tile(gx,gy)
        if not t or not t.occupant: return
        e=t.occupant; lines=[]
        if isinstance(e,Unit):
            lines.append(f'玩家{e.player_id+1} | {e.unit_type}')
            if e.equip: lines.append(f'装备: {e.equip.get("name","")}')
            lines.append(f'HP:{e.hp:.1f}/{e.max_hp:.1f} 护甲:{e.armor}')
            lines.append(f'伤害:{e.damage} 射程:{e.attack_range} 速:{e.speed}')
            lines.append('[Done]' if e.is_action_done else '[Ready]')
        elif isinstance(e,Building):
            lines.append(('玩家'+str(e.player_id+1) if e.player_id>=0 else '中立')+' | '+e.building_type)
            lines.append(f'HP:{int(e.hp)}/{int(e.max_hp)} 护甲:{e.armor}')
            if e.building_type=='大本营': lines.append(f'T{e.tier+1} +{e.gold_per_turn}🪙')
            elif e.building_type=='据点': lines.append(f'+{e.gold_per_turn}🪙' if e.is_captured else '中立 可占领')
        mx,my=pygame.mouse.get_pos(); bw,bh=220,24+len(lines)*18
        bx=max(10,min(mx+15,self.sw()-bw-10)); by=max(10,min(my-10,self.sh()-bh-10))
        pygame.draw.rect(self.screen,(20,20,30),(bx,by,bw,bh),border_radius=4)
        pygame.draw.rect(self.screen,COLOR_GRAY,(bx,by,bw,bh),1,border_radius=4)
        for i,ln in enumerate(lines):
            self.screen.blit(load_font(16).render(ln,True,COLOR_WHITE if i else PLAYER_COLORS[e.player_id] if isinstance(e,Unit) and e.player_id>=0 else COLOR_GRAY),(bx+6,by+4+i*18))

# ============================================================
# 主游戏
# ============================================================
class Game:
    def __init__(self):
        pygame.init()
        self.screen=pygame.display.set_mode((SCREEN_WIDTH,SCREEN_HEIGHT),pygame.RESIZABLE)
        pygame.display.set_caption('绿色军团 — 热座回合制策略游戏')
        self._fullscreen=False; self.clock=pygame.time.Clock(); self.running=True; self.game_state='MENU'
        self.screen_w=SCREEN_WIDTH; self.screen_h=SCREEN_HEIGHT
        self.camera=None; self.grid=None; self.selection=None; self.engine=None; self.renderer=None
        self.buttons={}; self.hq_menu_buttons=[]; self.hq_menu_open=False
        self._setup_menu()
    def _setup_menu(self):
        bw,bh=260,50; cx=(SCREEN_WIDTH-bw)//2; cy=SCREEN_HEIGHT//2-60
        self._menu_buttons=[Button(cx,cy,bw,bh,'🎮 开始游戏',(40,80,40),font_size=22),
            Button(cx,cy+70,bw,bh,'📖 百科全书',(40,40,80),font_size=22)]
        self._player_sel_buttons=[]
        for i,n in enumerate([2,3,4]): self._player_sel_buttons.append(Button(cx-90+i*90,cy+70,80,50,f'{n}人',(60,60,60),font_size=22))
        self._menu_state='MAIN'
    def _start_game(self, count):
        mp=MAP_WIDTH*TILE_SIZE,MAP_HEIGHT*TILE_SIZE
        self.camera=Camera(*mp,self.screen_w,self.screen_h)
        self.grid=Grid(MAP_WIDTH,MAP_HEIGHT); self.selection=SelectionManager()
        self.engine=GameEngine(count)
        self.renderer=Renderer(self.screen,self.camera,self.grid,self.selection,self.engine)
        self._setup_buttons(); self.renderer.buttons=self.buttons; self.renderer.hq_buttons=self.hq_menu_buttons
        self.selection._get_player_buildings=lambda pid:[b for p in self.engine.players if p.player_id==pid for b in p.buildings]
        self._place_initial_entities(); self._center_on_current_player(); self.game_state='PLAYING'
    def _place_initial_entities(self):
        corners=[(2,2),(MAP_WIDTH-3,2),(2,MAP_HEIGHT-3),(MAP_WIDTH-3,MAP_HEIGHT-3)]
        for i,p in enumerate(self.engine.players):
            if i<len(corners):
                cx,cy=corners[i]; b=Building('大本营',cx,cy,i)
                self.grid.place(b,cx,cy); p.add_building(b); p.gold=10
        for ox,oy in [(MAP_WIDTH//2,MAP_HEIGHT//2),(MAP_WIDTH//4,MAP_HEIGHT//4*3),(MAP_WIDTH//4*3,MAP_HEIGHT//4)]:
            if not self.grid.get_tile(ox,oy).occupant:
                self.grid.place(Building('据点',ox,oy,-1),ox,oy)
    def _center_on_current_player(self):
        if not self.camera: return
        p=self.engine.get_current_player(); hq=p.get_hq()
        if hq: self.camera.center_on(hq.grid_x,hq.grid_y)
    def _setup_buttons(self):
        self.buttons={'skip':Button(10,SCREEN_HEIGHT-50,120,32,'跳过',COLOR_DARK),
            'station':Button(140,SCREEN_HEIGHT-50,120,32,'驻扎',(0,60,0)),
            'end_turn':Button(SCREEN_WIDTH-140,SCREEN_HEIGHT-50,130,32,'结束回合',COLOR_BLUE)}
        self.hq_menu_buttons=[]; self.hq_menu_open=False
    def _update_hq_menu(self, building):
        self.hq_menu_buttons.clear()
        if not building: return
        p=self.engine.get_current_player(); pw,bw,bh=200,180,30; yo=36
        self.hq_menu_buttons.append(Button(10,yo,pw,36,f'T{building.tier+1} HQ  🪙{p.gold}',COLOR_DARK,COLOR_GOLD))
        yo+=40
        if building.can_upgrade():
            cost=building.upgrade_cost
            self.hq_menu_buttons.append(Button(10,yo,bw,bh,f'⬆ T{building.tier+2} 🪙{cost}',COLOR_BLUE if p.gold>=cost else COLOR_GRAY))
            self.hq_menu_buttons[-1].action=('upgrade',building); yo+=bh+4
        pool=['士兵']
        if building.tier>=1: pool+=['坦克','军用吉普','野战炮','装甲车']
        if building.tier>=2: pool+=['火箭炮','战斗机','轰炸机','防空车']
        for ut in pool:
            cost=UNIT_DATA[ut]['price']; txt=ut[:4] if ut in('战斗机','轰炸机','军用吉普','火箭炮','装甲车')else ut
            self.hq_menu_buttons.append(Button(10,yo,bw,bh,f'{txt} 🪙{int(cost)}',COLOR_DARK if p.gold>=cost else COLOR_GRAY))
            self.hq_menu_buttons[-1].action=('recruit',building,ut); yo+=bh+3
        self.hq_menu_buttons.append(Button(10,yo+4,bw,bh,'❌ 关闭',COLOR_RED)); self.hq_menu_buttons[-1].action=('close',)
    def _execute_hq_action(self, action):
        if not action: return
        p=self.engine.get_current_player()
        if action[0]=='upgrade':
            b=action[1]
            if p.gold>=b.upgrade_cost: p.gold-=b.upgrade_cost; b.start_upgrade(); self.hq_menu_open=False; self._update_hq_menu(b)
        elif action[0]=='recruit':
            b=action[1]; ut=action[2]; cost=UNIT_DATA[ut]['price']
            if p.gold>=cost:
                p.gold-=cost; pos=self._find_spawn_pos(b.grid_x,b.grid_y)
                if pos:
                    u=Unit(ut,*pos,p.player_id); self.grid.place(u,*pos); p.add_unit(u)
                self._update_hq_menu(b)
        elif action[0]=='close': self.hq_menu_open=False; self.selection.clear()
    def _find_spawn_pos(self, bx, by):
        for r in range(1,4):
            for dx in range(-r,r+1):
                for dy in range(-r,r+1):
                    if abs(dx)+abs(dy)==r:
                        nx,ny=bx+dx,by+dy
                        if self.grid.in_bounds(nx,ny):
                            t=self.grid.get_tile(nx,ny)
                            if t and not t.occupant: return nx,ny
        return None
    def handle_event(self, event):
        if event.type==pygame.QUIT: self.running=False
        elif event.type==pygame.KEYDOWN:
            if event.key==pygame.K_F11:
                self._fullscreen=not self._fullscreen
                if self._fullscreen:
                    info=pygame.display.Info(); self.screen_w,self.screen_h=info.current_w,info.current_h
                    self.screen=pygame.display.set_mode((self.screen_w,self.screen_h),pygame.FULLSCREEN)
                else:
                    self.screen_w,self.screen_h=SCREEN_WIDTH,SCREEN_HEIGHT
                    self.screen=pygame.display.set_mode((self.screen_w,self.screen_h),pygame.RESIZABLE)
                if self.renderer: self.renderer.screen=self.screen
                if self.camera: self.camera.scr_w,self.camera.scr_h=self.screen_w,self.screen_h
            if self.game_state=='MENU': return
            if event.key==pygame.K_ESCAPE: self.selection.clear(); self.hq_menu_open=False
            if event.key in (pygame.K_RETURN,pygame.K_SPACE):
                if self.selection.selected_unit and self.selection.selected_unit.can_skip(): self.selection.skip_unit()
                else: self._end_turn()
        elif event.type==pygame.MOUSEBUTTONDOWN:
            if self.game_state=='MENU' or not self.camera:
                if event.button==1: self._handle_menu_click(*event.pos)
                return
            if event.button==1:
                mx,my=event.pos
                if self.hq_menu_open:
                    for btn in self.hq_menu_buttons:
                        if btn.is_hovered((mx,my)): btn.click(); self._execute_hq_action(btn.action); return
                for name,btn in self.buttons.items():
                    if btn.is_hovered((mx,my)):
                        btn.click()
                        if name=='skip' and self.selection.selected_unit: self.selection.skip_unit()
                        elif name=='station' and self.selection.selected_unit: self._try_station()
                        elif name=='end_turn': self._end_turn()
                        return
                gx,gy=self.camera.screen_to_grid(mx,my)
                self.selection.handle_click(gx,gy,self.engine,self.grid)
                self.camera.start_drag(mx,my)
            elif event.button==4: self.camera.zoom_at(*event.pos,0.15)
            elif event.button==5: self.camera.zoom_at(*event.pos,-0.15)
        elif event.type==pygame.MOUSEBUTTONUP:
            if self.game_state=='MENU' or not self.camera: return
            if event.button==1: self.camera.end_drag()
        elif event.type==pygame.MOUSEMOTION:
            if self.game_state=='MENU' or not self.camera: return
            gx,gy=self.camera.screen_to_grid(*event.pos); self.renderer.set_hover(gx,gy)
            if event.buttons[0]: self.camera.update_drag(*event.pos)
        elif event.type==pygame.MOUSEWHEEL:
            if self.game_state=='MENU' or not self.camera: return
            mx,my=pygame.mouse.get_pos()
            if event.y>0: self.camera.zoom_at(mx,my,0.15)
            else: self.camera.zoom_at(mx,my,-0.15)
    def _end_turn(self):
        self.selection.clear(); self.hq_menu_open=False
        self.engine.next_turn(); self._center_on_current_player()
    def _try_station(self):
        u=self.selection.selected_unit
        if not u or u.is_action_done: return
        for b in self.engine.get_current_player().buildings:
            if b.building_type=='大本营' and b.in_heal_range(u.grid_x,u.grid_y):
                u.is_stationed=True; u.is_action_done=True; self.selection.clear(); return
    def _handle_menu_click(self, mx, my):
        if self._menu_state=='MAIN':
            for btn in self._menu_buttons:
                if btn.is_hovered((mx,my)):
                    if '开始游戏' in btn.text: self._menu_state='PLAYER_SEL'
                    elif '百科全书' in btn.text: webbrowser.open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'encyclopedia','index.html'))
                    return
        elif self._menu_state=='PLAYER_SEL':
            for btn in self._player_sel_buttons:
                if btn.is_hovered((mx,my)): self._start_game(int(btn.text[0])); return
    def _draw_menu(self):
        self.screen.fill(COLOR_BG)
        self.screen.blit(load_font(48).render('绿色军团',True,(200,220,160)),load_font(48).render('绿色军团',True,(200,220,160)).get_rect(center=(self.screen_w//2,self.screen_h//2-150)))
        self.screen.blit(load_font(20).render('热座回合制策略游戏',True,COLOR_GRAY),load_font(20).render('热座回合制策略游戏',True,COLOR_GRAY).get_rect(center=(self.screen_w//2,self.screen_h//2-100)))
        btns=self._menu_buttons if self._menu_state=='MAIN' else self._player_sel_buttons
        for btn in btns: btn.draw(self.screen)
    def update(self):
        self.camera.update()
        for p in self.engine.players:
            for b in p.buildings:
                if b.tick_upgrade(): self.selection.clear()
        if self.selection.selected_building:
            if self.selection.selected_building.building_type=='大本营':
                self._update_hq_menu(self.selection.selected_building); self.hq_menu_open=True
        if self.selection.selected_unit:
            u=self.selection.selected_unit
            if not u.is_action_done:
                for b in self.engine.get_current_player().buildings:
                    if b.building_type=='大本营' and b.in_heal_range(u.grid_x,u.grid_y):
                        self.selection.highlight_color=COLOR_HIGHLIGHT_HEAL; break
        self.engine.auto_end_if_no_actions()
        keys=pygame.key.get_pressed(); sp=10/self.camera.zoom
        if keys[pygame.K_w] or keys[pygame.K_UP]: self.camera.pan(0,sp)
        if keys[pygame.K_s] or keys[pygame.K_DOWN]: self.camera.pan(0,-sp)
        if keys[pygame.K_a] or keys[pygame.K_LEFT]: self.camera.pan(sp,0)
        if keys[pygame.K_d] or keys[pygame.K_RIGHT]: self.camera.pan(-sp,0)
    def run(self):
        while self.running:
            for event in pygame.event.get(): self.handle_event(event)
            if self.game_state=='MENU': self._draw_menu()
            elif self.game_state=='PLAYING': self.update(); self.renderer.render()
            pygame.display.flip(); self.clock.tick(FPS)
        pygame.quit()

# ============================================================
# 入口
# ============================================================
if __name__=='__main__':
    Game().run()
