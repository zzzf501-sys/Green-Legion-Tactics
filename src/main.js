// ==================== 常量 ====================
const TS=64; let MAP_W=80; let MAP_H=80; const FPS=60
const MIN_Z=0.4; const MAX_Z=2.5
const PLAYER_COLORS=['#ff3c3c','#3c78ff','#3cdc3c','#ffdc3c']
const COL_BG='#1a1a2a'; const COL_GL='#2a2f22'; const COL_GD='#22271c'
const COL_WHITE='#ffffff'; const COL_GOLD='#caba6a'; const COL_GRAY='#6a6a7a'
const COL_DARK='#14141e'
const r2=v=>Math.round(v*100)/100
const r1=v=>Math.round(v*10)/10

// ==================== 数据 ====================
function eDist(a,b){return Math.sqrt((a[0]-b[0])**2+(a[1]-b[1])**2)}
function neighbors(gx,gy){return[[0,1],[0,-1],[1,0],[-1,0]].map(d=>[gx+d[0],gy+d[1]])}
function clamp(v,lo,hi){return Math.max(lo,Math.min(hi,v))}
function lerp(a,b,t){return a+(b-a)*t}
function applyEquip(d,eq){
  if(!eq)return Object.assign({},d)
  let r=Object.assign({},d)
  if(eq.dmg!==undefined)r.damage=r2((r.damage||0)+eq.dmg)
  if(eq.range!==undefined)r.range=r2((r.range||0)+eq.range)
  if(eq.speed!==undefined)r.speed=r2((r.speed||0)+eq.speed)
  if(eq.armor!==undefined)r.armor=r2(Math.max(0,(r.armor||0)+eq.armor))
  if(eq.hp!==undefined)r.hp=Math.max(.5,r2((r.hp||1)+eq.hp))
  if(eq.cost!==undefined)r.price=r2((r.price||0)+eq.cost)
  if(eq.canTargetAir)r.canTargetAir=true
  if(eq.blast!==undefined)r.blast=eq.blast
  return r
}
function getTilesInEuclidean(cx,cy,rad){
  let r=new Set()
  let bound=Math.ceil(rad)
  for(let dx=-bound;dx<=bound;dx++)for(let dy=-bound;dy<=bound;dy++)
    if(eDist([0,0],[dx,dy])<=rad)r.add((cx+dx)+','+(cy+dy))
  return r
}
function getBoundaryTiles(tiles,center,inside=true){
  // 返回在tiles集合中但在其边界上的格子（有邻居不在集合中）
  let set=new Set(tiles)
  let bound=new Set()
  for(let k of tiles){
    let [sx,sy]=k.split(',').map(Number)
    for(let[nx,ny] of neighbors(sx,sy)){
      if(!set.has(nx+','+ny)){bound.add(k);break}
    }
  }
  return bound
}

function terrainAt(gx,gy){
  if(!G||!G.grid)return TERRAIN_DATA[0]
  let t=G.grid.get(gx,gy)
  return TERRAIN_DATA[(t&&t.terrain)||0]||TERRAIN_DATA[0]
}
function terrainHeightAt(gx,gy){return terrainAt(gx,gy).height||0}
function getEffectiveRange(att,target,fromX=att.gx,fromY=att.gy){
  let base=att.eR(target)
  let attH=att.isAir?0:terrainHeightAt(fromX,fromY)
  let tgtH=target.isAir?0:terrainHeightAt(target.gx,target.gy)
  let heightMod=clamp(attH-tgtH,-2,2)
  return Math.max(1,r1(base+heightMod))
}
function canTarget(att,target,fromX=att.gx,fromY=att.gy){
  if(target.isAir&&!att.canTargetAir)return false
  return eDist([fromX,fromY],[target.gx,target.gy])<=getEffectiveRange(att,target,fromX,fromY)
}
function getMaxPossibleRange(u,gx=u.gx,gy=u.gy){
  let terrainBonus=u.isAir?0:terrainHeightAt(gx,gy)
  return Math.max(u.range,u.airRange||0)+terrainBonus
}
function getAttackTargets(u,gx=u.gx,gy=u.gy,pid=curP().id){
  let maxR=getMaxPossibleRange(u,gx,gy)
  let at=getTilesInEuclidean(gx,gy,maxR)
  let en=new Set()
  for(let k of at){
    let[tx,ty]=k.split(',').map(Number)
    let tt=G.grid.get(tx,ty)
    if(tt&&tt.occ&&tt.occ.pid!==pid&&(tt.occ instanceof Unit||tt.occ instanceof Building)&&canSeeEntity(tt.occ,pid)&&canTarget(u,tt.occ,gx,gy))en.add(k)
  }
  return en
}
function markVision(set,gx,gy,rad){
  let bound=Math.ceil(rad)
  for(let dx=-bound;dx<=bound;dx++)for(let dy=-bound;dy<=bound;dy++){
    if(eDist([0,0],[dx,dy])<=rad)set.add((gx+dx)+','+(gy+dy))
  }
}
function getUnitVision(u){
  let base=UNIT_DATA[u.type]&&UNIT_DATA[u.type].vision!==undefined?UNIT_DATA[u.type].vision:4
  let heightBonus=u.isAir?0:terrainHeightAt(u.gx,u.gy)
  return base+heightBonus
}
function hasStrategicTech(pid,name){
  return ENGINE&&ENGINE.players[pid]&&ENGINE.players[pid].researched&&ENGINE.players[pid].researched[name]
}
function getBuildingVision(b){
  if(b.type==='大本营'){
    let tiers=BUILDING_DATA['大本营'].tiers
    return (tiers[b.tier]&&tiers[b.tier].vision)||7
  }
  if(b.type==='据点'){
    let base=(BUILDING_DATA['据点']&&BUILDING_DATA['据点'].vision)||5
    return base+(b.outpostBranch==='combat'?1:0)
  }
  return (BUILDING_DATA[b.type]&&BUILDING_DATA[b.type].vision)||3
}
function isTileVisible(gx,gy,pid=curP().id){
  let p=ENGINE.players[pid]
  return !p||!p.visible?p&&p.id===pid:p.visible.has(gx+','+gy)
}
function isTileExplored(gx,gy,pid=curP().id){
  let p=ENGINE.players[pid]
  return !p||!p.explored?p&&p.id===pid:p.explored.has(gx+','+gy)
}
function canSeeEntity(ent,pid=curP().id){
  if(!ent)return false
  if(ent.pid===pid||ent.pid===-1)return true
  if(ent instanceof Building)return isTileExplored(ent.gx,ent.gy,pid)
  return isTileVisible(ent.gx,ent.gy,pid)
}
function getTerrainStepCost(grid,fromX,fromY,toX,toY,unit){
  let to=grid.get(toX,toY),from=grid.get(fromX,fromY)
  if(!to||!from)return Infinity
  let diag=(fromX!==toX&&fromY!==toY)?1.4:1
  if(unit&&unit.isAir)return diag
  let td=TERRAIN_DATA[to.terrain||0]||TERRAIN_DATA[0]
  let up=(td.height||0)-((TERRAIN_DATA[from.terrain||0]||TERRAIN_DATA[0]).height||0)
  let slope=up>0?up*0.8:up*0.35
  return Math.max(0.6,td.moveCost+slope)*diag
}

// ==================== 贴图加载 ====================
let GROUND_TILES=[null,null,null]
let GROUND_COLORS=['#2d3a2d','#1e2a1e','#3a3528']
let TERRAIN_TEXTURES=[null,null,null,null]
function loadGroundTiles(){
  let files=['浅绿色地皮.jpg','深绿色地皮.jpg','黄色地皮.jpg']
  files.forEach((f,i)=>{
    let img=new Image()
    img.onload=function(){GROUND_TILES[i]=this}
    img.onerror=function(){GROUND_TILES[i]=null}
    try{img.src='assets/images/'+f}catch(e){GROUND_TILES[i]=null}
  })
}
loadGroundTiles()
function loadTerrainTextures(){
  let files=[null,'terrain/terrain-hill.jpg','terrain/terrain-highland.jpg','terrain/terrain-mountain.jpg']
  files.forEach((f,i)=>{
    if(!f)return
    let img=new Image()
    img.onload=function(){TERRAIN_TEXTURES[i]=this}
    img.onerror=function(){TERRAIN_TEXTURES[i]=null}
    try{img.src='assets/images/'+f}catch(e){TERRAIN_TEXTURES[i]=null}
  })
}
loadTerrainTextures()
function tileNoise(x,y,n){
  let v=Math.sin(x*127.1+y*311.7+n*74.7)*43758.5453
  return v-Math.floor(v)
}
function drawTerrainDetail(td,sx,sy,sz,x,y){
  let h=td.height||0
  if(h<=0)return
  ctx.save()
  ctx.lineCap='round';ctx.lineJoin='round'
  if(h===1){
    ctx.fillStyle='rgba(58,69,35,0.72)'
    ctx.strokeStyle='rgba(205,196,126,0.26)'
    ctx.lineWidth=Math.max(1,sz*.02)
    for(let i=0;i<3;i++){
      let ox=(.26+tileNoise(x,y,i)*.48)*sz
      let oy=(.28+tileNoise(x+3,y-2,i)*.42)*sz
      let rw=(.09+tileNoise(x-1,y+5,i)*.05)*sz
      let rh=(.035+tileNoise(x+7,y+1,i)*.025)*sz
      ctx.beginPath();ctx.ellipse(sx+ox,sy+oy,rw,rh,0,0,Math.PI*2);ctx.fill();ctx.stroke()
    }
  }else if(h===2){
    ctx.strokeStyle='rgba(235,221,151,0.52)'
    ctx.lineWidth=Math.max(1.2,sz*.025)
    for(let i=0;i<3;i++){
      let y0=sy+sz*(.34+i*.16)
      ctx.beginPath()
      ctx.moveTo(sx+sz*.22,y0)
      ctx.quadraticCurveTo(sx+sz*(.44+tileNoise(x,y,i)*.12),y0-sz*.10,sx+sz*.78,y0+sz*.02)
      ctx.stroke()
    }
    ctx.fillStyle='rgba(83,75,52,0.58)'
    ctx.beginPath();ctx.moveTo(sx+sz*.22,sy+sz*.72);ctx.lineTo(sx+sz*.44,sy+sz*.48);ctx.lineTo(sx+sz*.78,sy+sz*.72);ctx.closePath();ctx.fill()
  }else{
    function peak(cx,base,w,ph,shade){
      ctx.fillStyle=shade
      ctx.beginPath();ctx.moveTo(cx-w*.5,base);ctx.lineTo(cx,base-ph);ctx.lineTo(cx+w*.5,base);ctx.closePath();ctx.fill()
      ctx.strokeStyle='rgba(236,229,198,0.42)';ctx.lineWidth=Math.max(1,sz*.018);ctx.stroke()
      ctx.fillStyle='rgba(228,221,187,0.32)'
      ctx.beginPath();ctx.moveTo(cx,base-ph);ctx.lineTo(cx+w*.16,base-ph*.58);ctx.lineTo(cx-w*.04,base-ph*.46);ctx.closePath();ctx.fill()
    }
    let base=sy+sz*.74
    peak(sx+sz*.36,base,sz*.44,sz*.46,'rgba(72,68,57,0.86)')
    peak(sx+sz*.58,base,sz*.52,sz*.58,'rgba(58,56,51,0.92)')
    peak(sx+sz*.72,base,sz*.34,sz*.40,'rgba(87,79,62,0.78)')
    ctx.strokeStyle='rgba(35,32,28,0.38)';ctx.lineWidth=Math.max(1,sz*.018)
    ctx.beginPath();ctx.moveTo(sx+sz*.20,base);ctx.lineTo(sx+sz*.84,base);ctx.stroke()
  }
  ctx.restore()
}

// ==================== 游戏状态 ====================
let G=null,ctx=null,cvs=null
let W=window.innerWidth,H=window.innerHeight
let lastFrameTime=0

function resize(){
  W=window.innerWidth;H=window.innerHeight
  if(cvs){cvs.width=W;cvs.height=H}
  if(G&&G.cam)G.cam.sw=W,G.cam.sh=H
}

// ==================== 摄像机 ====================
class Camera{
  constructor(mpw,mph,sw,sh){
    this.mpw=mpw;this.mph=mph;this.sw=sw;this.sh=sh
    this.ox=0;this.oy=0;this.z=1;this.tz=1;this.tox=0;this.toy=0
    this.drag=false;this.dsx=0;this.dsy=0;this.dox=0;this.doy=0
  }
  w2s(wx,wy){return[wx*this.z+this.ox,wy*this.z+this.oy]}
  s2w(sx,sy){return[(sx-this.ox)/this.z,(sy-this.oy)/this.z]}
  s2g(sx,sy){let[wxx,wyy]=this.s2w(sx,sy);return[Math.floor(wxx/TS),Math.floor(wyy/TS)]}
  g2s(gx,gy){return this.w2s(gx*TS,gy*TS)}
  centerOn(gx,gy){
    this.tox=this.sw/2-gx*TS*this.z;this.toy=this.sh/2-gy*TS*this.z
    this._clamp()
  }
  pan(dx,dy){this.tox+=dx;this.toy+=dy;this._clamp()}
  startDrag(sx,sy){this.drag=true;this.dsx=sx;this.dsy=sy;this.dox=this.ox;this.doy=this.oy}
  endDrag(){this.drag=false}
  updateDrag(sx,sy){if(this.drag){let dx=sx-this.dsx,dy=sy-this.dsy;this.tox=this.dox+dx;this.toy=this.doy+dy;this._clamp()}}
  zoomAt(sx,sy,dz){
    let[wx,wy]=this.s2w(sx,sy)
    this.tz=clamp(this.tz+dz,MIN_Z,MAX_Z)
    this.tox=sx-wx*this.tz;this.toy=sy-wy*this.tz;this._clamp()
  }
  getVR(){
    let[l,t]=this.s2w(0,0);let[r,b]=this.s2w(this.sw,this.sh)
    return[clamp(Math.floor(l/TS),0,MAP_W-1),clamp(Math.floor(t/TS),0,MAP_H-1),clamp(Math.ceil(r/TS)+1,0,MAP_W),clamp(Math.ceil(b/TS)+1,0,MAP_H)]
  }
  update(){
    this.z=lerp(this.z,this.tz,.15);this.ox=lerp(this.ox,this.tox,.15);this.oy=lerp(this.oy,this.toy,.15)
  }
  _clamp(){
    let mx=this.mpw*this.z-this.sw,my=this.mph*this.z-this.sh
    this.tox=clamp(this.tox,-Math.max(mx,0),0);this.toy=clamp(this.toy,-Math.max(my,0),0)
  }
}

// ==================== 网格 ====================
class Grid{
  constructor(){
    this.tiles=[]
    for(let x=0;x<MAP_W;x++){
      this.tiles[x]=[]
      for(let y=0;y<MAP_H;y++){
        this.tiles[x][y]={gx:x,gy:y,occ:null,terrain:0}
      }
    }
  }
  ib(x,y){return x>=0&&x<MAP_W&&y>=0&&y<MAP_H}
  get(x,y){return this.ib(x,y)?this.tiles[x][y]:null}
  place(e,x,y){let t=this.get(x,y);if(t){t.occ=e;e.gx=x;e.gy=y}}
  remove(e){let t=this.get(e.gx,e.gy);if(t&&t.occ===e)t.occ=null}
}

// ==================== 实体 ====================
class Unit{
  constructor(type,gx,gy,pid,equip){
    let d=applyEquip(UNIT_DATA[type],equip)
    this.type=type;this.gx=gx;this.gy=gy;this.pid=pid;this.equip=equip||null
    this.hp=d.hp;this.maxHp=d.hp;this.armor=d.armor;this.speed=d.speed
    this.damage=d.damage;this.range=d.range;this.attacks=d.attacks||1;this.price=d.price
    this.vision=d.vision||4
    this.isAir=d.isAir||false;this.canTargetAir=d.canTargetAir||false
    this.airDamage=d.airDamage||0;this.airRange=d.airRange||0
    this.blast=d.blast||0;this.reload=d.reload||0
    this.selfDestruct=d.selfDestruct||false
    this.moved=false;this.attacked=false;this.done=false;this.stationed=false;this.rl=0
    this.remainingAttacks=d.attacks||1
  }
  reset(){this.moved=false;this.attacked=false;this.done=false;this.remainingAttacks=this.attacks;if(this.rl>0)this.rl--}
  canMove(){return!this.moved&&!this.done}
  canAttack(){return !this.done&&this.rl===0&&this.remainingAttacks>0}
  canAction(){return !this.done}
  moveTo(x,y){this.gx=x;this.gy=y;this.moved=true}
  eR(t){return t&&t.isAir&&this.airRange?this.airRange:this.range}
  eD(t){
    let dmg=t&&t.isAir&&this.airDamage?this.airDamage:this.damage
    if(this.type==='自杀无人机'&&hasStrategicTech(this.pid,'SpaceX 星链计划'))dmg+=1
    return dmg
  }
  attack(t){
    this._pendingDmg=r2(Math.max(0,this.eD(t)-t.armor))
    this.moved=true
    this.remainingAttacks--
    if(this.remainingAttacks<=0)this.done=true
    if(this.reload>0)this.rl=this.reload
    if(this.selfDestruct)this.hp=0
    return this._pendingDmg
  }
  applyPendingDmg(t){
    if(!this._pendingDmg)return
    t.takeDamage(this._pendingDmg)
    this._pendingDmg=null
  }
  takeDamage(a){a=Math.min(a,this.hp);this.hp=r2(this.hp-a);return a}
  get dead(){return this.hp<=0}
}
class Building{
  constructor(type,gx,gy,pid,tier=0){
    this.type=type;this.gx=gx;this.gy=gy;this.pid=pid;this.tier=tier
    this.upgrading=false;this.upTimer=0;this.captured=false;this.tsd=0;this.dmgThisTurn=false
    // 据点专属
    this.outpostTier=0;this.outpostBranch=null
    // 资源采集器专属
    this.collectorId=-1;this.underConstruction=false;this.buildTimer=0
    this._updateStats()
  }
  _updateStats(){
    if(this.type==='大本营'){
      let t=BUILDING_DATA['大本营'].tiers[this.tier]
      this.maxHp=t.hp;this.hp=this.hp||t.hp;this.armor=t.armor;this.gold=t.gold
      this.upgradeCost=t.upgradeCost;this.upgradeTime=t.upgradeTime;this.vision=t.vision||7
    }else if(this.type==='据点'){
      if(this.outpostTier===0){
        let d=BUILDING_DATA['据点']
        this.maxHp=d.hp;this.armor=d.armor;this.gold=this.captured?d.gold:0;this.vision=d.vision||5
      }else if(this.outpostBranch==='combat'){
        this.maxHp=50;this.armor=0.5;this.gold=4;this.vision=6
      }else if(this.outpostBranch==='economic'){
        this.maxHp=30;this.armor=0;this.gold=6;this.vision=5
      }
    }else{
      let d=BUILDING_DATA[this.type]
      if(d){this.maxHp=d.hp;this.hp=this.hp||d.hp;this.armor=d.armor;this.gold=this.underConstruction?0:d.gold;this.vision=d.vision||3}
    }
  }
  capture(pid){
    this.pid=pid;this.captured=true
    this.hp=r2(this.maxHp*0.5)
    this._updateStats();this.tsd=0
  }
  takeDamage(a){
    a=Math.min(a,this.hp);this.hp=r2(this.hp-a);this.dmgThisTurn=true;this.tsd=0;return a
  }
  turnStart(){
    this.tsd=this.dmgThisTurn?0:this.tsd+1;this.dmgThisTurn=false
    if(this.tsd>=3&&this.hp<this.maxHp)this.hp=r2(Math.min(this.maxHp,this.hp+2))
  }
  canUpgrade(){return this.type==='大本营'&&this.tier<2&&!this.upgrading}
  startUpgrade(){this.upgrading=true;this.upTimer=this.upgradeTime}
  tickUpgrade(){
    if(!this.upgrading)return false
    this.upTimer--
    if(this.upTimer<=0){
      this.upgrading=false
      var _oh=this.hp,_om=this.maxHp
      if(this.type==='大本营'){
        this.tier++;this._updateStats();playSE('upgrade')
        if(G)G.addEffect(this.gx,this.gy,'equip')
        this.hp=r2(Math.min(this.maxHp,this.maxHp*(1+_oh/_om)/2))
      }else if(this.type==='据点'){
        this.outpostTier=1;this._updateStats();playSE('upgrade')
        if(G)G.addEffect(this.gx,this.gy,'equip')
        if(this.outpostBranch==='combat'){
          this.hp=this.maxHp  // 战斗型升级回满
        }else{
          this.hp=r2(Math.min(this.maxHp,this.maxHp*(1+_oh/_om)/2))
        }
      }
      return true
    }
    return false
  }
  inHeal(gx,gy){
    var r=2
    if(this.type==='大本营')r=this.tier>=2?5:3
    else if(this.type==='据点'&&this.outpostBranch==='combat')r=3
    return eDist([this.gx,this.gy],[gx,gy])<=r
  }
  get dead(){return this.hp<=0}
}

// ==================== 寻路 ====================
function computeMoveRange(grid,sx,sy,mv,unit){
  let r=new Set()
  let best=new Map([[sx+','+sy,0]])
  let q=[{x:sx,y:sy,c:0}]
  let dirs=[[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]]
  while(q.length){
    q.sort((a,b)=>a.c-b.c)
    let cur=q.shift()
    if(cur.c>(best.get(cur.x+','+cur.y)||Infinity))continue
    for(let d of dirs){
      let nx=cur.x+d[0],ny=cur.y+d[1]
      if(!grid.ib(nx,ny))continue
      let t=grid.get(nx,ny)
      if(t.occ&&t.occ!==unit)continue
      let nc=r2(cur.c+getTerrainStepCost(grid,cur.x,cur.y,nx,ny,unit))
      if(nc>mv)continue
      let key=nx+','+ny
      if(nc<(best.get(key)??Infinity)){
        best.set(key,nc);q.push({x:nx,y:ny,c:nc});r.add(key)
      }
    }
  }
  return r
}

// ==================== 选择管理器 ====================
let SEL={u:null,b:null,hl:new Set(),hc:'#ff69b440',phase:'SEL',rangeLabel:''}

function clearSel(){
  SEL.u=null;SEL.b=null;SEL.hl.clear();SEL.phase='SEL';SEL.rangeLabel=''
  if(G){G.movePreviewPos=null;G.movePreviewTargets=null}
  document.getElementById('hq-panel').style.display='none'
}
function escAttr(v){
  return String(v==null?'':v).replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
}
function unitInfoText(type){
  let d=UNIT_DATA[type]
  if(!d)return type
  let tags=[]
  tags.push(type)
  tags.push('价格 '+d.price)
  tags.push('HP '+d.hp)
  tags.push('护甲 '+d.armor)
  tags.push('移速 '+d.speed)
  tags.push('伤害 '+(d.attacks>1?d.damage+'×'+d.attacks:d.damage))
  tags.push('射程 '+d.range)
  tags.push('视野 '+(d.vision||4))
  if(d.airDamage)tags.push('对空 '+d.airDamage+' / 射程 '+d.airRange)
  if(d.isAir)tags.push('空中单位')
  if(d.canTargetAir)tags.push('可对空')
  if(d.selfDestruct)tags.push('攻击后自毁')
  if(d.blast)tags.push('爆炸半径 '+d.blast)
  if(d.reload)tags.push('装弹 '+d.reload+' 回合')
  return tags.join('\n')
}
function equipInfoText(unitType,eq){
  let d=UNIT_DATA[unitType]
  let lines=[unitType+'：'+eq.name+'（'+(eq.tier||'T?')+'）','研究 '+(eq.researchCost||0)+' 金 / '+(eq.researchTime||1)+' 回合']
  let buffs=[]
  let deltaText=(label,base,delta)=>label+'：'+r2(base)+' → '+r2(base+delta)+'（'+(delta>0?'+':'')+r2(delta)+'）'
  if(eq.dmg)buffs.push(deltaText('伤害',d.damage||0,eq.dmg))
  if(eq.range)buffs.push(deltaText('射程',d.range||0,eq.range))
  if(eq.speed)buffs.push(deltaText('移速',d.speed||0,eq.speed))
  if(eq.hp)buffs.push(deltaText('HP',d.hp||0,eq.hp))
  if(eq.armor)buffs.push(deltaText('护甲',d.armor||0,eq.armor))
  if(eq.canTargetAir)buffs.push('获得对空能力')
  if(eq.blast)buffs.push('爆炸半径 '+eq.blast)
  if(eq.cost!==undefined)buffs.push('装备价格：'+(eq.cost>=0?'+':'')+eq.cost+' 金')
  if(buffs.length)lines.push(buffs.join('\n'))
  return lines.join('\n')
}
function strategicTechInfoText(tech){
  return [tech.name+'（'+tech.tier+'）','研究 '+tech.researchCost+' 金 / '+tech.researchTime+' 回合',tech.desc||''].join('\n')
}
function buildingActionInfoText(kind){
  if(kind==='collector')return '资源采集器\n建造 8 金 / 2 回合\n完成后按编号产金：3 × 0.8^编号'
  if(kind==='hq-upgrade')return '大本营升级\n提升 HP、护甲、每回合收入和驻扎范围\n升级完成时恢复部分失去血量'
  if(kind==='outpost-combat')return '战斗型据点\n升级 10 金 / 1 回合\nHP 50，护甲 0.5，每回合 +4，驻扎范围 3'
  if(kind==='outpost-economic')return '经济型据点\n升级 10 金 / 3 回合\nHP 30，护甲 0，每回合 +6，驻扎范围 2'
  return ''
}

function serializeUnit(u){
  return {
    type:u.type,gx:u.gx,gy:u.gy,pid:u.pid,equip:u.equip,
    hp:u.hp,maxHp:u.maxHp,armor:u.armor,speed:u.speed,damage:u.damage,range:u.range,attacks:u.attacks,price:u.price,
    vision:u.vision,isAir:u.isAir,canTargetAir:u.canTargetAir,airDamage:u.airDamage,airRange:u.airRange,
    blast:u.blast,reload:u.reload,selfDestruct:u.selfDestruct,moved:u.moved,attacked:u.attacked,done:u.done,
    stationed:u.stationed,rl:u.rl,remainingAttacks:u.remainingAttacks
  }
}
function restoreUnit(d){
  let u=new Unit(d.type,d.gx,d.gy,d.pid,d.equip)
  Object.assign(u,d)
  return u
}
function serializeBuilding(b){
  return {
    type:b.type,gx:b.gx,gy:b.gy,pid:b.pid,tier:b.tier,hp:b.hp,maxHp:b.maxHp,armor:b.armor,gold:b.gold,vision:b.vision,
    upgradeCost:b.upgradeCost,upgradeTime:b.upgradeTime,upgrading:b.upgrading,upTimer:b.upTimer,captured:b.captured,
    tsd:b.tsd,dmgThisTurn:b.dmgThisTurn,outpostTier:b.outpostTier,outpostBranch:b.outpostBranch,
    collectorId:b.collectorId,underConstruction:b.underConstruction,buildTimer:b.buildTimer
  }
}
function restoreBuilding(d){
  let b=new Building(d.type,d.gx,d.gy,d.pid,d.tier||0)
  Object.assign(b,d)
  return b
}
function serializeGameState(){
  return {
    mapW:MAP_W,mapH:MAP_H,
    engine:{cur:ENGINE.cur,turn:ENGINE.turn,state:ENGINE.state},
    terrain:G&&G.grid?G.grid.tiles.map(col=>col.map(t=>t.terrain||0)):[],
    neutralBuildings:G&&G.neutralBuildings?G.neutralBuildings.map(serializeBuilding):[],
    players:ENGINE.players.map(p=>({
      id:p.id,name:p.name,gold:p.gold,alive:p.alive,
      researched:p.researched,researching:p.researching,
      collectorCount:p.collectorCount,freedCollectorIds:p.freedCollectorIds,
      stats:p.stats,
      units:p.units.map(serializeUnit),
      buildings:p.buildings.map(serializeBuilding)
    }))
  }
}
function deserializeGameState(state,opts={}){
  if(!state||!state.players)return
  MAP_W=state.mapW;MAP_H=state.mapH
  initEngine(state.players.length)
  ENGINE.cur=state.engine.cur
  ENGINE.turn=state.engine.turn
  ENGINE.state=state.engine.state
  clearSel()
  G=new Game({skipInit:true})
  if(state.terrain&&state.terrain.length){
    for(let x=0;x<MAP_W;x++)for(let y=0;y<MAP_H;y++){
      let t=G.grid.get(x,y)
      if(t)t.terrain=(state.terrain[x]&&state.terrain[x][y])||0
    }
  }
  state.players.forEach(pd=>{
    let p=ENGINE.players[pd.id]
    if(!p)return
    p.name=pd.name;p.gold=pd.gold;p.alive=pd.alive
    p.researched=pd.researched||{};p.researching=pd.researching||[]
    p.collectorCount=pd.collectorCount||0;p.freedCollectorIds=pd.freedCollectorIds||[]
    p.stats=pd.stats||{turnData:[],totalKillValue:0}
    p.units=[];p.buildings=[]
    ;(pd.buildings||[]).forEach(bd=>{
      let b=restoreBuilding(bd)
      G.grid.place(b,b.gx,b.gy);p.addBuilding(b)
    })
    ;(pd.units||[]).forEach(ud=>{
      let u=restoreUnit(ud)
      G.grid.place(u,u.gx,u.gy);p.addUnit(u)
    })
  })
  G.neutralBuildings=[]
  ;(state.neutralBuildings||[]).forEach(bd=>{
    let b=restoreBuilding(bd)
    G.grid.place(b,b.gx,b.gy);G.neutralBuildings.push(b)
  })
  G.updateVision()
  G._updateButtons()
  if(opts.center!==false){
    let centerPlayer=ENGINE.players[(window.ONLINE&&window.ONLINE.myPlayerId>=0)?window.ONLINE.myPlayerId:ENGINE.cur]||curP()
    let hq=centerPlayer&&centerPlayer.getHQ?centerPlayer.getHQ():curP().getHQ()
    if(hq)G.cam.centerOn(hq.gx,hq.gy)
  }
  document.getElementById('menu').style.display='none'
  document.getElementById('player-sel').style.display='none'
  document.getElementById('gameOver').style.display=ENGINE.state==='GAME_OVER'?'flex':'none'
}

// ==================== 玩家 ====================
class Player{
  constructor(id,name){
    this.id=id;this.name=name;this.gold=10;this.units=[];this.buildings=[];this.alive=true
    this.researched={}
    this.researching=[]
    this.collectorCount=0
    this.freedCollectorIds=[]
    this.visible=new Set()
    this.explored=new Set()
    this.stats={turnData:[],totalKillValue:0}
  }
  nextCollectorId(){
    if(this.freedCollectorIds.length>0)return this.freedCollectorIds[0]
    return this.collectorCount
  }
  consumeCollectorId(){
    if(this.freedCollectorIds.length>0){
      let id=this.freedCollectorIds.shift()
      return id
    }
    return this.collectorCount++
  }
  freeCollectorId(id){
    this.freedCollectorIds.push(id)
    this.freedCollectorIds.sort((a,b)=>a-b)
  }
  addUnit(u){if(u&&!this.units.includes(u))this.units.push(u)}
  removeUnit(u){
    let i=this.units.indexOf(u);if(i>=0)this.units.splice(i,1)
    if(!this.units.length&&!this.buildings.some(b=>b.type==='大本营'))this.alive=false
  }
  addBuilding(b){if(b&&!this.buildings.includes(b))this.buildings.push(b)}
  removeBuilding(b){
    let i=this.buildings.indexOf(b);if(i>=0)this.buildings.splice(i,1)
    if(b.type==='大本营'&&!this.buildings.some(b2=>b2.type==='大本营'))this.alive=false
    if(b.type==='资源采集器'&&b.collectorId>=0)this.freeCollectorId(b.collectorId)
  }
  getIncome(){
    let t=0
    this.buildings.forEach(b=>{
      if(b.type==='资源采集器'&&!b.underConstruction){
        t+=r2(3*Math.pow(0.8,b.collectorId))
      }else t+=b.gold||0
    })
    return t
  }
  collectIncome(){this.gold=r2(this.gold+this.getIncome())}
  turnStart(){
    this.units.forEach(u=>{
      u.reset()
      if(u.stationed){
        this.buildings.some(b=>(b.type==='大本营'||b.type==='据点')&&b.inHeal(u.gx,u.gy))&&(u.hp=r1(Math.min(u.maxHp,u.hp+1)))
      }
      u.stationed=false
    })
    this.buildings.forEach(b=>b.turnStart())
  }
  getHQ(){return this.buildings.find(b=>b.type==='大本营')}
}

// ==================== 游戏引擎 ====================
let ENGINE={players:[],cur:0,turn:1,state:'MENU'}
function initEngine(n){
  ENGINE.players=[];ENGINE.cur=0;ENGINE.turn=1;ENGINE.state='PLAYING'
  for(let i=0;i<n;i++)ENGINE.players.push(new Player(i,'玩家'+(i+1)))
}
function curP(){return ENGINE.players[ENGINE.cur]}
function isOnlineGame(){return !!(window.ONLINE&&window.ONLINE.connected)}
function onlineCanControl(){return !isOnlineGame()||window.ONLINE.myPlayerId===ENGINE.cur}
function notifyOnlineState(reason){
  if(isOnlineGame()&&onlineCanControl()&&typeof window.onlineSendState==='function'){
    setTimeout(function(){window.onlineSendState(reason||'state')},0)
  }
}
function showGameOver(winner){
  stopBGM()
  setTimeout(function(){playSE('victory')},500)
  ENGINE.state='GAME_OVER'
  let el=document.getElementById('gameOver')
  el.style.display='flex'
  var winImgs=['红方胜利.png','蓝方胜利.png','绿方胜利.png','黄方胜利.png']
  var goTxt=document.getElementById('goTxt')
  if(winner){goTxt.innerHTML='<img src="assets/images/'+winImgs[winner.id]+'" style="max-width:500px;width:80vw;height:auto;display:block;margin:0 auto">'}
  else{goTxt.textContent='?'}
  showStatsChart()
  if(G&&G.cam){
    let hq=winner?winner.getHQ():null
    if(hq)G.cam.centerOn(hq.gx,hq.gy)
  }
  setTimeout(function(){
    let btn=document.createElement('button')
    btn.className='btn btn-primary';btn.style.cssText='position:absolute;bottom:40px;left:50%;transform:translateX(-50%);padding:12px 40px;font-size:18px;z-index:60'
    btn.textContent='再来一局';btn.onclick=function(){location.reload()}
    document.body.appendChild(btn)
  },2000)
}

// ==================== 统计图表 ====================
function showStatsChart(){
  let box=document.getElementById('statsBox')
  if(!box)return
  box.innerHTML=''
  let players=ENGINE.players
  let metrics=[
    {key:'armyValue',label:'军队价值',unit:'🪙'},
    {key:'gold',label:'金币总数',unit:'🪙'},
    {key:'killValue',label:'累计击杀',unit:'🪙'},
    {key:'income',label:'回合收入',unit:'🪙'},
  ]
  metrics.forEach(m=>{
    let cvs=document.createElement('canvas')
    cvs.width=380;cvs.height=220
    cvs.style.cssText='border:1px solid #2a2a3e;border-radius:6px;background:#12121e'
    box.appendChild(cvs)
    drawChart(cvs,m.label,m.key,players)
  })
}
function drawChart(cvs,title,metric,players){
  let ctx=cvs.getContext('2d')
  let W=cvs.width,H=cvs.height
  let pt={top:28,right:12,bottom:28,left:44}
  let cw=W-pt.left-pt.right,ch=H-pt.top-pt.bottom
  let dataSets=[]
  players.forEach((p,i)=>{
    let vals=p.stats.turnData.map(d=>d[metric]||0)
    if(vals.length>0)dataSets.push({pid:i,label:p.name,color:PLAYER_COLORS[i],vals:vals})
  })
  if(!dataSets.length)return
  let maxTurns=Math.max(...dataSets.map(d=>d.vals.length))
  let maxVal=Math.max(...dataSets.flatMap(d=>d.vals),1)*1.15
  ctx.fillStyle='#12121e';ctx.fillRect(0,0,W,H)
  ctx.fillStyle='#caba6a';ctx.font='bold 13px sans-serif';ctx.textAlign='center';ctx.textBaseline='top'
  ctx.fillText(title,W/2,5)
  ctx.strokeStyle='#22223a';ctx.lineWidth=1
  for(let i=0;i<=4;i++){let y=pt.top+ch*i/4;ctx.beginPath();ctx.moveTo(pt.left,y);ctx.lineTo(W-pt.right,y);ctx.stroke()}
  ctx.fillStyle='#5a5a6a';ctx.font='10px sans-serif';ctx.textAlign='right';ctx.textBaseline='middle'
  for(let i=0;i<=4;i++){
    let val=maxVal-maxVal*i/4
    ctx.fillText(val>=1?Math.round(val):val.toFixed(1),pt.left-4,pt.top+ch*i/4)
  }
  ctx.textAlign='center';ctx.textBaseline='top'
  let step=Math.max(1,Math.floor(maxTurns/8))
  for(let t=0;t<maxTurns;t+=step){
    ctx.fillText('R'+(t+1),pt.left+cw*t/(maxTurns-1||1),H-pt.bottom+5)
  }
  dataSets.forEach(ds=>{
    ctx.strokeStyle=ds.color;ctx.lineWidth=2;ctx.beginPath()
    ds.vals.forEach((v,i)=>{
      let x=pt.left+cw*i/(ds.vals.length-1||1)
      let y=pt.top+ch*(1-v/maxVal)
      i===0?ctx.moveTo(x,y):ctx.lineTo(x,y)
    })
    ctx.stroke()
    ds.vals.forEach((v,i)=>{
      let x=pt.left+cw*i/(ds.vals.length-1||1)
      let y=pt.top+ch*(1-v/maxVal)
      ctx.fillStyle=ds.color;ctx.beginPath();ctx.arc(x,y,3,0,Math.PI*2);ctx.fill()
      ctx.strokeStyle='#fff';ctx.lineWidth=1;ctx.stroke()
    })
  })
  ctx.textAlign='left';ctx.textBaseline='top';let lx=pt.left,ly=2
  dataSets.forEach(ds=>{
    ctx.fillStyle=ds.color;ctx.fillRect(lx,ly+3,10,10)
    ctx.fillStyle='#b0b0b8';ctx.font='10px sans-serif';ctx.fillText(ds.label,lx+14,ly)
    lx+=ctx.measureText(ds.label).width+30
  })
}

function killUnit(target){
  let killVal=r2(target.price||0)
  if(target.selfDestruct){
    // 自毁击杀不计入击杀者（自杀无人机）
  }else{
    ENGINE.players.forEach(pp=>{
      if(pp.units.includes(target)||pp.buildings.includes(target)){
        // 找到包含该单位的玩家，击杀价值给攻击者
      }
    })
  }
  let grid=G.grid
  grid.remove(target)
  ENGINE.players.forEach(pp=>{pp.removeUnit(target);pp.removeBuilding(target)})
  G.dying.push({ent:target,alpha:255})
}

function applyBlastDamage(cx,cy,radius,damage,attackerPid,excludeTarget){
  let hit=new Set()
  ENGINE.players.forEach(p=>{
    p.units.forEach(u=>{
      if(excludeTarget&&u===excludeTarget)return
      let dist=eDist([cx,cy],[u.gx,u.gy])
      if(dist<=radius&&u.pid!==attackerPid){
        let dmg=r2(Math.max(0,damage-u.armor))
        u.takeDamage(dmg)
        if(u.dead)hit.add(u)
      }
    })
  })
  return hit
}

function nextTurn(){
  let alive=ENGINE.players.filter(p=>p.alive)
  if(alive.length<=1){showGameOver(alive[0]||null);return}
  let was=ENGINE.cur
  for(let i=0;i<ENGINE.players.length;i++){ENGINE.cur=(ENGINE.cur+1)%ENGINE.players.length;if(curP().alive)break}
  let wrapped=(ENGINE.cur<=was&&was!==ENGINE.cur)||(was===ENGINE.players.length-1&&ENGINE.cur===0)
  if(wrapped){
    ENGINE.turn++
    ENGINE.players.forEach(p=>{if(p.alive){
      p.buildings.forEach(b=>{b.tickUpgrade()})
      // 采集器建造计时
      p.buildings.forEach(b=>{
        if(b.underConstruction){
          b.buildTimer--
          if(b.buildTimer<=0){b.underConstruction=false;console.log('Building complete:',b.type)}
        }
      })
      let done=[]
      p.researching.forEach(r=>{r.timer--;if(r.timer<=0){p.researched[r.name]=true;done.push(r)}})
      done.forEach(r=>{let i=p.researching.indexOf(r);if(i>=0)p.researching.splice(i,1);playSE('upgrade');if(G){var hq=p.getHQ();if(hq)G.addEffect(hq.gx,hq.gy,'research')}})
      p.collectIncome()
      p.stats.turnData.push({turn:ENGINE.turn,armyValue:r2(p.units.reduce((s,u)=>s+(u.price||0),0)),gold:p.gold,killValue:p.stats.totalKillValue,income:p.getIncome()})
    }})
    // 中立据点回血
    if(G&&G.neutralBuildings)G.neutralBuildings.forEach(function(b){b.turnStart()})
  }
  curP().turnStart()
  showTurnNotify()
  if(G&&G.cam){let hq=curP().getHQ();if(hq)G.cam.centerOn(hq.gx,hq.gy)}
}
function allDone(){return curP().units.every(u=>u.done)}

// ==================== 主游戏 ====================
class Game{
  constructor(opts={}){
    G=this
    this.grid=new Grid()
    this.cam=new Camera(MAP_W*TS,MAP_H*TS,W,H)
    this.dying=[];this.neutralBuildings=[];this.buildMode=null;this.ghostPos=null
    this.selUnit=null;this.selBuilding=null
    // 鼠标悬停显示的额外范围
    this.hoverRangeUnit=null
    this.hoverRangeType=''
    this.movePreviewPos=null;this.movePreviewTargets=null
    this.effects=[];this.attackLock=false
    if(!opts.skipInit)this._placeInit()
    this.updateVision()
    if(!opts.skipInit)this._centerOnCur()
    this._updateButtons()
  }
  _placeInit(){
    console.log('=== _placeInit ===')
    let n=ENGINE.players.length
    let cs
    if(n===2){
      // 2人模式：60×30，大本营间距比原50×50多10格
      let midY=Math.floor(MAP_H/2)
      cs=[[8,midY],[51,midY]]  // 间距43（原33+10）
    }else{
      cs=[[8,8],[MAP_W-9,8],[8,MAP_H-9],[MAP_W-9,MAP_H-9]]
    }
    for(let i=0;i<n&&i<cs.length;i++){
      let[cx,cy]=cs[i];let b=new Building('大本营',cx,cy,i)
      this.grid.place(b,cx,cy);ENGINE.players[i].addBuilding(b)
    }
    ENGINE.players.forEach(p=>p.gold=10)
    let placed=0
    function placeOp(gx,gy){
      let b=new Building('据点',gx,gy,-1)
      b.hp=r2(b.maxHp*0.5)  // 初始50%血量
      this.grid.place(b,gx,gy);this.neutralBuildings.push(b);placed++
    }
    if(n===2){
      // 2人：据点水平偏移5，竖直间距12
      let midX=Math.floor((cs[0][0]+cs[1][0])/2)
      let midY=Math.floor(MAP_H/2)
      for(let dy of[-12,0,12]){
        let x=midX+(dy===-12?-5:dy===12?5:0)
        let y=midY+dy
        if(this.grid.ib(x,y))placeOp.call(this,x,y)
      }
    }else{
      let mx=(cs[0][0]+cs[1][0])>>1
      let my=(cs[0][1]+cs[1][1])>>1
      let t=this.grid.get(mx,my)
      if(t&&!t.occ){placeOp.call(this,mx,my)}
      else{
        for(let d of[[1,0],[-1,0],[0,1],[0,-1]]){
          let t2=this.grid.get(mx+d[0],my+d[1])
          if(t2&&!t2.occ){placeOp.call(this,mx+d[0],my+d[1]);break}
        }
      }
      if(n>2){let cx=MAP_W/2|0,cy=MAP_H/2|0
        let t=this.grid.get(cx,cy)
        if(t&&!t.occ)placeOp.call(this,cx,cy)
      }
    }
    console.log('Total outposts placed:',placed)
    this._generateTerrain(cs)
    this._flattenAroundBuildings()
  }
  _generateTerrain(cs){
    let ridgeCount=ENGINE.players.length>=3?2:1
    for(let i=0;i<ridgeCount;i++){
      let vertical=Math.random()<0.5
      let major=vertical?MAP_H:MAP_W
      let minor=vertical?MAP_W:MAP_H
      let edgeA=4+Math.floor(Math.random()*(minor-8))
      let edgeB=4+Math.floor(Math.random()*(minor-8))
      let amp=3+Math.floor(Math.random()*(ENGINE.players.length>=3?5:4))
      let amp2=1+Math.floor(Math.random()*3)
      let phase=Math.random()*Math.PI*2
      let phase2=Math.random()*Math.PI*2
      let waves=1.5+Math.random()*1.5
      let pts=[]
      for(let a=0;a<major;a++){
        let t=a/(major-1)
        let b=Math.round(
          lerp(edgeA,edgeB,t)+
          Math.sin(t*Math.PI*2*waves+phase)*amp+
          Math.sin(t*Math.PI*6+phase2)*amp2
        )
        b=clamp(b,2,minor-3)
        pts.push(vertical?[b,a]:[a,b])
      }
      this._paintRidge(pts)
      this._paintRidge(pts.map(p=>[MAP_W-1-p[0],MAP_H-1-p[1]]))
    }
    this._scatterTerrain()
  }
  _paintRidge(pts){
    for(let i=0;i<pts.length;i++){
      let[cx,cy]=pts[i]
      let peakRoll=Math.random()
      let peak=peakRoll<0.08?3:peakRoll<0.26?2:1
      let gap=i%4===0&&Math.random()<0.5
      if(gap)continue
      for(let dx=-1;dx<=1;dx++)for(let dy=-1;dy<=1;dy++){
        if(Math.abs(dx)+Math.abs(dy)>1)continue
        if((dx||dy)&&Math.random()<0.55)continue
        let x=cx+dx,y=cy+dy
        if(!this.grid.ib(x,y))continue
        let dist=Math.sqrt(dx*dx+dy*dy)
        let h=dist<=0.45?peak:(peak>=3?2:1)
        if(h>(this.grid.get(x,y).terrain||0))this.grid.get(x,y).terrain=h
      }
    }
  }
  _scatterTerrain(){
    let count=Math.floor(MAP_W*MAP_H/180)
    for(let i=0;i<count;i++){
      let x=2+Math.floor(Math.random()*(MAP_W-4))
      let y=2+Math.floor(Math.random()*(MAP_H-4))
      let roll=Math.random()
      let h=roll<0.08?3:roll<0.28?2:1
      let t=this.grid.get(x,y)
      if(t&&!t.occ)t.terrain=Math.max(t.terrain||0,h)
      if(h<=2&&Math.random()<0.45){
        let d=[[1,0],[-1,0],[0,1],[0,-1]][Math.floor(Math.random()*4)]
        let nt=this.grid.get(x+d[0],y+d[1])
        if(nt&&!nt.occ)nt.terrain=Math.max(nt.terrain||0,1)
      }
    }
  }
  _flattenAroundBuildings(){
    let bs=[]
    ENGINE.players.forEach(p=>p.buildings.forEach(b=>bs.push(b)))
    if(this.neutralBuildings)bs.push(...this.neutralBuildings)
    bs.forEach(b=>{
      for(let dx=-1;dx<=1;dx++)for(let dy=-1;dy<=1;dy++){
        let t=this.grid.get(b.gx+dx,b.gy+dy)
        if(t)t.terrain=0
      }
    })
  }
  _centerOnCur(){let hq=curP().getHQ();if(hq)this.cam.centerOn(hq.gx,hq.gy)}
  _handleClick(gx,gy){
    if(this.attackLock)return
    if(isOnlineGame()&&!onlineCanControl()){
      clearSel()
      if(typeof window.onlineSetStatus==='function')window.onlineSetStatus('现在是玩家 '+(ENGINE.cur+1)+' 的回合，等待对方操作')
      return
    }
    let p=curP();let t=this.grid.get(gx,gy);if(!t)return
    // 建造模式
    if(this.buildMode){
      let hq=p.getHQ()
      if(hq&&!t.occ&&eDist([gx,gy],[hq.gx,hq.gy])<=5&&p.gold>=8){
        p.gold-=8
        let b=new Building('资源采集器',gx,gy,p.id)
        b.underConstruction=true;b.buildTimer=2;b.gold=0
        b.collectorId=p.consumeCollectorId()
        this.grid.place(b,gx,gy);p.addBuilding(b)
        console.log('Building resource collector #'+b.collectorId+', ready in 2 rounds')
        notifyOnlineState('build')
      }
      this.buildMode=null;this.ghostPos=null;this._updateButtons();return
    }
    let o=t.occ
    if(o&&!canSeeEntity(o,p.id))o=null
    if(SEL.phase==='SEL'){
      if(o&&o.pid===p.id){
        if(o instanceof Building&&o.type==='大本营'){SEL.b=o;this._showHQ(o);return}
        if(o instanceof Building&&o.type==='据点'&&o.pid===p.id){SEL.b=o;this._showOutpost(o);return}
        if(o instanceof Unit){this._selUnit(o);return}
      }
      if(o instanceof Building&&o.type==='据点'&&o.pid===-1){SEL.b=o;this._showOutpost(o);return}
      clearSel()
    }else if(SEL.phase==='MOVE'){
      let u=SEL.u;if(!u)return
      if(SEL.hl.has(gx+','+gy)){
        if(t.occ&&t.occ!==u){clearSel();return}
        this.grid.remove(u);u.moveTo(gx,gy);t.occ=u
        notifyOnlineState('move')
        if(u.canAttack()){
          let en=getAttackTargets(u,gx,gy,p.id)
          if(en.size){SEL.hl=en;SEL.hc='#ff000060';SEL.phase='ATK';SEL.rangeLabel='攻击目标';return}
        }
        u.done=true;clearSel()
      }else if(o instanceof Unit&&o.pid===p.id){this._selUnit(o)}
      else clearSel()
    }else if(SEL.phase==='ATK'){
      let u=SEL.u;if(!u)return
      if(o===u&&u.canMove()){this._showMoveRange(u);this._updateButtons();return}
      if(SEL.hl.has(gx+','+gy)){
        let tt=this.grid.get(gx,gy)
        if(tt&&tt.occ&&tt.occ.pid!==p.id){
          let target=tt.occ
          if(!canTarget(u,target,u.gx,u.gy)){clearSel();return}
          if(target instanceof Unit){
            if(target.isAir&&!u.canTargetAir){clearSel();return}
            playAttackSE(u)
            u.attack(target)
            var soundLen=u.attacks>1?400:600
            var _this=this,_p=curP(),_u=u,_target=target,_bb=u.blast>0?applyBlastDamage(target.gx,target.gy,u.blast,u.eD(target),u.pid,target):null
            _this.attackLock=true
            // 音效播完→扣血
            setTimeout(function(){
              _u.applyPendingDmg(_target)
              // 爆炸范围受害者死亡
              if(_bb&&_bb.size){_bb.forEach(function(u2){
                if(u2.dead){killUnit(u2);_p.stats.totalKillValue=r2(_p.stats.totalKillValue+(u2.price||0))}
              })}
              // 再等0.2s→死亡结算+音效
              setTimeout(function(){
                var _killed=false,_sd=false
                if(_target.dead){killUnit(_target);_sd=true;_p.stats.totalKillValue=r2(_p.stats.totalKillValue+(_target.price||0));_killed=true}
                if(_u.dead){killUnit(_u);_sd=true;_killed=true}
                if(_sd)playSE('destroyed')
                _this.attackLock=false
                if(!_killed&&SEL.u===_u)_this._recalcAttackRange(_u)
                if(!_u.canAttack()&&!_u.canMove()){clearSel()}
                else if(!_killed){_this._selUnit(_u)}
                notifyOnlineState('attack')
              },200)
            },soundLen)
          }else if(target instanceof Building){
            let _bb=u.blast>0?applyBlastDamage(target.gx,target.gy,u.blast,u.eD(target),u.pid,target):null
            u.attack(target);u.applyPendingDmg(target)
            if(_bb&&_bb.size){_bb.forEach(function(u2){
              if(u2.dead){killUnit(u2);p.stats.totalKillValue=r2(p.stats.totalKillValue+(u2.price||0))}
            })}
            if(u.dead){killUnit(u);playSE('destroyed')}
            if(target.dead&&target.type==='据点'){
              ENGINE.players.forEach(pp=>pp.removeBuilding(target))
              let i=this.neutralBuildings.indexOf(target)
              if(i>=0)this.neutralBuildings.splice(i,1)
              if(target.outpostTier>0){
                // T2据点打爆→退回T1
                target.outpostTier=0;target.outpostBranch=null
                target._updateStats()
                target.hp=r2(target.maxHp*0.5)
                target.pid=u.pid;target.captured=true
                ENGINE.players[u.pid].addBuilding(target)
                console.log('T2 outpost reverted to T1, captured by',p.name)
              }else{
                target.capture(u.pid)
                ENGINE.players[u.pid].addBuilding(target)
                console.log('Outpost captured by',p.name)
              }
            }
            else if(target.dead){
              this.grid.remove(target);ENGINE.players.forEach(pp=>pp.removeBuilding(target))
              let al=ENGINE.players.filter(pp=>pp.alive)
              if(al.length<=1){clearSel();showGameOver(al[0]||null);return}
            }
            if(!u.canAttack()&&!u.canMove()){clearSel()}
            else{this._selUnit(u)}
            notifyOnlineState('attack-building')
          }
        }
      }else clearSel()
    }
    this._updateButtons()
  }
  _recalcAttackRange(u){
    // 重新计算当前选中单位的攻击范围
    if(!u||!SEL.u||SEL.u!==u)return
    let p=curP()
    let en=getAttackTargets(u,u.gx,u.gy,p.id)
    if(en.size){SEL.hl=en;SEL.hc='#ff000060';SEL.phase='ATK';SEL.rangeLabel='攻击目标'}
    else{SEL.hl.clear();SEL.phase='SEL'}
  }
  _showMoveRange(u){
    SEL.u=u;SEL.b=null
    SEL.hl=computeMoveRange(this.grid,u.gx,u.gy,u.speed,u)
    SEL.hc='#ff69b440'
    SEL.phase='MOVE'
    SEL.rangeLabel='移动范围'
  }
  _selUnit(u){
    SEL.u=u;SEL.b=null;SEL.rangeLabel=''
    if(u.canAttack()){
      let en=getAttackTargets(u,u.gx,u.gy,curP().id)
      if(en.size){SEL.hl=en;SEL.hc='#ff000060';SEL.phase='ATK';SEL.rangeLabel='攻击目标'}
      else if(u.canMove())this._showMoveRange(u)
      else{SEL.phase='SEL';SEL.hl.clear()}
    }else if(u.canMove()){
      this._showMoveRange(u)
    }else{SEL.phase='SEL';SEL.hl.clear()}
    this._updateButtons()
  }
  _equipUnit(eqName){
    if(isOnlineGame()&&!onlineCanControl())return
    let u=SEL.u;if(!u)return
    let pp=curP()
    if(!pp.researched[eqName]||u.equip)return
    let eqList=EQUIP_DATA[u.type]
    if(!eqList)return
    let eq=eqList.find(e=>e.name===eqName)
    if(!eq||pp.gold<eq.cost)return
    pp.gold=r2(pp.gold-eq.cost)
    let _oldHp=u.hp,_oldMax=u.maxHp
    let nu=new Unit(u.type,u.gx,u.gy,u.pid,eq)
    nu.moved=u.moved;nu.attacked=u.attacked;nu.done=u.done;nu.stationed=u.stationed;nu.hp=u.hp;nu.remainingAttacks=u.remainingAttacks
    nu.hp=r1(Math.min(nu.maxHp,nu.maxHp*(1+_oldHp/_oldMax)/2))
    this.grid.remove(u);let idx=pp.units.indexOf(u)
    if(idx>=0)pp.units[idx]=nu
    this.grid.place(nu,nu.gx,nu.gy)
    SEL.u=nu;playSE('upgrade');if(G)G.addEffect(nu.gx,nu.gy,'equip')
    this._updateButtons()
    notifyOnlineState('equip')
  }
  _showHQ(b){
    let p=document.getElementById('hq-panel');p.style.display='flex'
    let pp=curP()
    let html='<div class="title">🏰 T'+(b.tier+1)+' HQ  🪙'+pp.gold+'</div>'
    if(b.upgrading){
      html+='<div class="hq-btn" style="color:#caba6a;text-align:center">⬆ 升级中... '+b.upTimer+'回合</div>'
    }else if(b.canUpgrade()){
      let af=pp.gold>=b.upgradeCost
      html+='<button class="hq-btn'+(af?' afford':'')+'" title="'+escAttr(buildingActionInfoText('hq-upgrade'))+'" onclick="G._hqUpgrade()">⬆ T'+(b.tier+2)+' 🪙'+b.upgradeCost+'</button>'
    }
    // 研究装备
    for(let ut in EQUIP_DATA){
      if(!EQUIP_DATA[ut])continue
      EQUIP_DATA[ut].forEach(eq=>{
        let eqTier=(eq.tier==='T2'?1:eq.tier==='T3'?2:0)
        if(eqTier>b.tier)return
        if(pp.researched[eq.name])return
        let actR=pp.researching.find(r=>r.name===eq.name)
        if(actR){
          html+='<div class="hq-btn" title="'+escAttr(equipInfoText(ut,eq))+'" style="color:#7acc7a;text-align:center">🔬 '+ut+'：'+eq.name+' 研究中... '+actR.timer+'回合</div>'
          return
        }
        let af=pp.gold>=(eq.researchCost||99)
        html+='<button class="hq-btn'+(af?' afford':'')+'" title="'+escAttr(equipInfoText(ut,eq))+'" onclick="G._research(\''+eq.name+'\','+(eq.researchCost||0)+','+(eq.researchTime||1)+')">🔬 '+ut+'：'+eq.name+' 🪙'+(eq.researchCost||0)+'</button>'
      })
    }
    // 研究战略科技
    if(typeof STRATEGIC_TECH_DATA!=='undefined'){
      STRATEGIC_TECH_DATA.forEach(tech=>{
        let techTier=(tech.tier==='T2'?1:tech.tier==='T3'?2:0)
        if(techTier>b.tier)return
        if(pp.researched[tech.name])return
        let actR=pp.researching.find(r=>r.name===tech.name)
        if(actR){
          html+='<div class="hq-btn" style="color:#7acc7a;text-align:center">🛰️ '+tech.name+' 研究中... '+actR.timer+'回合</div>'
          return
        }
        let af=pp.gold>=(tech.researchCost||99)
        html+='<button class="hq-btn'+(af?' afford':'')+'" title="'+escAttr(strategicTechInfoText(tech))+'" onclick="G._research(\''+tech.name+'\','+(tech.researchCost||0)+','+(tech.researchTime||1)+')">🛰️ '+tech.name+' 🪙'+(tech.researchCost||0)+'</button>'
      })
    }
    // 招募
    let pool=['士兵','军用吉普','装甲车']
    if(b.tier>=1)pool.push('坦克','野战炮','自杀无人机','侦察机')
    if(b.tier>=2)pool.push('火箭炮','战斗机','轰炸机','防空车')
    pool.forEach(ut=>{
      let d=UNIT_DATA[ut]
      if(!d)return
      let cost=d.price;let af=pp.gold>=cost
      html+='<button class="hq-btn'+(af?' afford':'')+'" title="'+escAttr(unitInfoText(ut))+'" onclick="G._recruit(\''+ut+'\')">'+ut+' 🪙'+cost+'</button>'
    })
    html+='<button class="hq-btn'+(pp.gold>=8?' afford':'')+'" title="'+escAttr(buildingActionInfoText('collector'))+'" onclick="G._startBuild()">⛏️ 资源采集器 🪙8</button>'
    html+='<button class="hq-btn close" onclick="clearSel()">❌ 关闭</button>'
    p.innerHTML=html
  }
  _showOutpost(b){
    let p=document.getElementById('hq-panel');p.style.display='flex'
    let pp=curP()
    let branchLabel=b.outpostBranch==='combat'?'战斗型':b.outpostBranch==='economic'?'经济型':''
    let tierLabel=b.outpostTier>0?'T2 '+branchLabel:'T1'
    let hpText=b.pid===pp.id?' ❤️'+Math.floor(b.hp)+'/'+Math.floor(b.maxHp):''
    let html='<div class="title">⚑ '+(b.pid===pp.id?'已占领':b.pid>=0?'敌方':'中立')+tierLabel+hpText+'  🪙'+pp.gold+'</div>'
    if(b.pid===pp.id){
      if(b.upgrading){
        html+='<div class="hq-btn" style="color:#caba6a;text-align:center">⬆ 升级中... '+b.upTimer+'回合</div>'
      }else if(b.outpostTier===0){
        // 检查T2科技（HQ T2自动解锁）
        let hq=pp.getHQ()
        if(hq&&hq.tier>=1){
          html+='<div style="color:#7a7a8a;font-size:11px;padding:4px 6px">⬆ 升级T2（需🪙10）</div>'
          html+='<button class="hq-btn'+(pp.gold>=10?' afford':'')+'" title="'+escAttr(buildingActionInfoText('outpost-combat'))+'" onclick="G._upgradeOutpost(\'combat\')">⚔️ 战斗型 ⬆1回合 ❤️50 🛡️0.5 🪙4</button>'
          html+='<button class="hq-btn'+(pp.gold>=10?' afford':'')+'" title="'+escAttr(buildingActionInfoText('outpost-economic'))+'" onclick="G._upgradeOutpost(\'economic\')">💰 经济型 ⬆3回合 ❤️30 🛡️0 🪙6</button>'
        }else{
          html+='<div class="hq-btn" style="color:#6a6a7a;text-align:center">需要大本营T2解锁升级</div>'
        }
      }else{
        html+='<div class="hq-btn" style="color:#7acc7a;text-align:center">T2 '+branchLabel+' 已升级</div>'
      }
      // 从据点招募
      let pool=['士兵','军用吉普','装甲车']
      if(pp.getHQ()&&pp.getHQ().tier>=1)pool.push('坦克','野战炮','自杀无人机','侦察机')
      if(pp.getHQ()&&pp.getHQ().tier>=2)pool.push('火箭炮','战斗机','轰炸机','防空车')
      pool.forEach(ut=>{
        let d=UNIT_DATA[ut]
        if(!d)return
        let cost=d.price;let af=pp.gold>=cost
        html+='<button class="hq-btn'+(af?' afford':'')+'" title="'+escAttr(unitInfoText(ut))+'" onclick="G._recruitFrom(\''+ut+'\','+b.gx+','+b.gy+')">'+ut+' 🪙'+cost+'</button>'
      })
      html+='<button class="hq-btn close" onclick="clearSel()">❌ 关闭</button>'
    }else if(b.pid===-1){
      html+='<div class="hq-btn" style="color:#8a8a8a;text-align:center">❤️ '+Math.floor(b.hp)+'/'+Math.floor(b.maxHp)+' 中立据点 — 攻占后归你</div>'
      html+='<button class="hq-btn close" onclick="clearSel()">❌ 关闭</button>'
    }
    p.innerHTML=html
  }
  _upgradeOutpost(branch){
    if(isOnlineGame()&&!onlineCanControl())return
    let b=SEL.b
    if(!b||b.type!=='据点'||!b.captured||b.outpostTier!==0||b.upgrading)return
    let pp=curP()
    if(pp.gold<10)return
    pp.gold-=10
    b.upgrading=true;b.outpostBranch=branch
    b.upTimer=branch==='combat'?1:3
    this._showOutpost(b);this._updateButtons()
    notifyOnlineState('outpost-upgrade')
  }
  _research(name,cost,time){
    if(isOnlineGame()&&!onlineCanControl())return
    let pp=curP()
    if(pp.gold<cost||pp.researched[name]||pp.researching.some(r=>r.name===name))return
    pp.gold-=cost;pp.researching.push({name:name,timer:time})
    if(SEL.b)this._showHQ(SEL.b);this._updateButtons()
    notifyOnlineState('research')
  }
  _hqUpgrade(){
    if(isOnlineGame()&&!onlineCanControl())return
    let b=SEL.b;if(!b)return
    let p=curP()
    if(b.canUpgrade()&&p.gold>=b.upgradeCost){p.gold-=b.upgradeCost;b.startUpgrade();this._showHQ(b);this._updateButtons();notifyOnlineState('hq-upgrade')}
  }
  addEffect(gx,gy,type){
    this.effects.push({gx:gx,gy:gy,type:type,life:120})
  }
  _recruitFrom(ut,bx,by){
    if(isOnlineGame()&&!onlineCanControl())return
    let p=curP();let cost=UNIT_DATA[ut]?UNIT_DATA[ut].price:0
    if(!cost||p.gold<cost)return
    let pos=this._findSpawn(bx,by)
    if(!pos)return
    p.gold-=cost
    let u=new Unit(ut,pos[0],pos[1],p.id);u.done=true;this.grid.place(u,pos[0],pos[1]);p.addUnit(u)
    this._updateButtons()
    notifyOnlineState('recruit-outpost')
  }
  _recruit(ut){
    if(isOnlineGame()&&!onlineCanControl())return
    let b=SEL.b;if(!b)return;let p=curP();let cost=UNIT_DATA[ut]?UNIT_DATA[ut].price:0
    if(!cost||p.gold<cost)return
    let pos=this._findSpawn(b.gx,b.gy)
    if(!pos)return
    p.gold-=cost
    let u=new Unit(ut,pos[0],pos[1],p.id);u.done=true;this.grid.place(u,pos[0],pos[1]);p.addUnit(u)
    this._showHQ(b);this._updateButtons()
    notifyOnlineState('recruit')
  }
  _startBuild(){
    if(isOnlineGame()&&!onlineCanControl())return
    let p=curP()
    if(p.gold<8||!SEL.b)return
    this.buildMode='资源采集器';this.ghostPos=null
    clearSel()
  }
  _findSpawn(bx,by){
    for(let r=1;r<4;r++)for(let dx=-r;dx<=r;dx++)for(let dy=-r;dy<=r;dy++)
      if(Math.abs(dx)+Math.abs(dy)===r){let t=this.grid.get(bx+dx,by+dy);if(t&&!t.occ)return[bx+dx,by+dy]}
    return null
  }
  updateVision(){
    ENGINE.players.forEach(p=>{
      if(!p.visible)p.visible=new Set()
      if(!p.explored)p.explored=new Set()
      p.visible.clear()
      if(p.researched&&p.researched['SpaceX 星链计划']){
        for(let x=0;x<MAP_W;x++)for(let y=0;y<MAP_H;y++)p.visible.add(x+','+y)
      }else{
        p.units.forEach(u=>markVision(p.visible,u.gx,u.gy,getUnitVision(u)))
        p.buildings.forEach(b=>markVision(p.visible,b.gx,b.gy,getBuildingVision(b)))
      }
      p.visible.forEach(k=>p.explored.add(k))
    })
  }
  update(){
    this.cam.update()
    this.updateVision()
    let nd=[]
    this.dying.forEach(d=>{d.alpha-=5;if(d.alpha>0)nd.push(d)})
    this.dying=nd
    this.effects=this.effects.filter(function(e){e.life--;return e.life>0})
    this._updateHUD()
  }
  _updateHUD(){
    try{
      let p=curP();if(!p)return
      document.getElementById('hudName').textContent=p.name
      document.getElementById('hudName').style.color=PLAYER_COLORS[p.id]
      document.getElementById('hudTurn').textContent='回合 '+ENGINE.turn
      let income=p.getIncome()
      document.getElementById('hudGold').textContent='🪙'+Number(p.gold).toFixed(2)+'  (+'+Number(income).toFixed(2)+'/回合)'
      let infoTxt=''
      if(SEL.u){
        let u=SEL.u
        let shownDmg=u.eD?u.eD({isAir:false,armor:0,gx:u.gx,gy:u.gy}):u.damage
        infoTxt=u.type+' HP:'+u.hp.toFixed(1)+'/'+u.maxHp+' 伤害:'+shownDmg+' 射程:'+getMaxPossibleRange(u)
        if(u.airRange)infoTxt+=' 对空:'+u.airDamage+'/'+getEffectiveRange(u,{isAir:true,gx:u.gx,gy:u.gy},u.gx,u.gy)
        if(u.attacks>1)infoTxt+=' 攻击:'+u.remainingAttacks+'/'+u.attacks
        if(u.done)infoTxt+=' [Done]'
      }
      document.getElementById('info').textContent=infoTxt
    }catch(e){}
  }
  _updateButtons(){
    try{
      let bb=document.getElementById('bottom-btns')
      let ud=document.getElementById('unit-detail')
      let ui=document.getElementById('udInfo')
      let ua=document.getElementById('udActions')
      let ic=document.getElementById('udIcon')
      if(!bb)return
      bb.innerHTML='<button class="btn btn-blue" onclick="endTurn()">结束回合</button>'
      let u=SEL.u
      if(u){
        ud.style.display='flex'
        let iconUrl='assets/images/'+u.type+'.png'
        let img=new Image()
        img.onload=function(){ic.innerHTML='';ic.style.overflow='hidden';ic.appendChild(img);img.style.cssText='width:100%;height:100%;object-fit:cover;border-radius:50%'}
        img.onerror=function(){
          let cvs=document.createElement('canvas');cvs.width=64;cvs.height=64;cvs.style.cssText='width:100%;height:100%;border-radius:50%'
          ic.innerHTML='';ic.appendChild(cvs)
          let cx=cvs.getContext('2d');cx.clearRect(0,0,64,64)
          cx.fillStyle=PLAYER_COLORS[u.pid];cx.strokeStyle='#444';cx.lineWidth=2
          if(u.type==='士兵'||u.type==='军用吉普'||u.type==='自杀无人机'){cx.beginPath();cx.arc(32,32,24,0,Math.PI*2);cx.fill();cx.stroke()}
          else if(u.type==='坦克'||u.type==='装甲车'){cx.fillRect(8,10,48,44);cx.strokeRect(8,10,48,44)}
          else if(u.isAir){cx.beginPath();cx.moveTo(32,8);cx.lineTo(56,32);cx.lineTo(32,56);cx.lineTo(8,32);cx.closePath();cx.fill();cx.stroke()}
          else{cx.beginPath();cx.arc(32,32,24,0,Math.PI*2);cx.fill();cx.stroke()}
        }
        try{img.src=iconUrl}catch(e){img.onerror()}
        let hpPct=Math.round(u.hp/u.maxHp*100)
        let hpColor=hpPct>50?'ud-hp':hpPct>25?'#d4c040':'ud-ap'
        let rows='<div class="ud-row"><span>'+u.type+'</span><span style="color:'+PLAYER_COLORS[u.pid]+'">玩家'+(u.pid+1)+'</span></div>'
        let shownDmg=u.eD?u.eD({isAir:false,armor:0,gx:u.gx,gy:u.gy}):u.damage
        rows+='<div class="ud-row"><span>❤️ <span class="ud-val" style="color:'+hpColor+'">'+u.hp.toFixed(1)+'/'+u.maxHp.toFixed(1)+'</span></span><span>🛡️ <span class="ud-val">'+u.armor+'</span></span><span>💨 <span class="ud-val">'+u.speed+'</span></span><span>🔫 <span class="ud-val">'+shownDmg+'</span></span><span>🎯 <span class="ud-val">'+getMaxPossibleRange(u)+'</span></span></div>'
        if(u.airRange)rows+='<div class="ud-row"><span>🔫 对地 <span class="ud-val">'+u.damage+'/'+getEffectiveRange(u,{isAir:false,gx:u.gx,gy:u.gy},u.gx,u.gy)+'</span></span><span>🛩️ 对空 <span class="ud-val">'+u.airDamage+'/'+getEffectiveRange(u,{isAir:true,gx:u.gx,gy:u.gy},u.gx,u.gy)+'</span></span></div>'
        if(u.attacks>1)rows+='<div class="ud-row"><span>⚔️ 攻击次数 <span class="ud-val">'+u.remainingAttacks+'/'+u.attacks+'</span></span></div>'
        if(u.equip)rows+='<div class="ud-row"><span>🛠️ <span class="ud-val">'+u.equip.name+'</span></span></div>'
        if(u.selfDestruct)rows+='<div class="ud-row"><span style="color:#ff6464">💥 攻击后自毁</span></div>'
        if(u.done)rows+='<div class="ud-row"><span style="color:#6a6a7a">[已行动]</span></div>'
        ui.innerHTML=rows
        let acts=''
        if(!u.done){
          acts+='<button class="btn" onclick="skipUnit()" style="font-size:12px;padding:4px 12px">跳过</button>'
          if(curP().buildings.some(b=>(b.type==='大本营'||b.type==='据点')&&b.inHeal(u.gx,u.gy)))
            acts+='<button class="btn btn-primary" onclick="stationUnit()" style="font-size:12px;padding:4px 12px">驻扎</button>'
          if(!u.equip){
            let eqs=EQUIP_DATA[u.type]
            if(eqs)eqs.forEach(eq=>{
              if(curP().researched[eq.name]&&curP().gold>=eq.cost)
                acts+='<button class="btn btn-primary" onclick="G._equipUnit(\''+eq.name+'\')" style="font-size:11px;padding:4px 8px">'+eq.name+'</button>'
            })
          }
        }
        acts+='<button class="btn btn-danger" onclick="clearSel();if(G)G._updateButtons()" style="font-size:12px;padding:4px 12px">取消</button>'
        ua.innerHTML=acts
      }else{
        ud.style.display='none'
      }
    }catch(e){console.error(e)}
  }
}
function skipUnit(){
  if(isOnlineGame()&&!onlineCanControl())return
  if(SEL.u&&!SEL.u.done){SEL.u.done=true;clearSel();G._updateButtons();notifyOnlineState('skip')}
}
function stationUnit(){
  if(isOnlineGame()&&!onlineCanControl())return
  let u=SEL.u;if(!u||u.done)return
  if(curP().buildings.some(b=>(b.type==='大本营'||b.type==='据点')&&b.inHeal(u.gx,u.gy))){u.stationed=true;u.done=true;clearSel();G._updateButtons();notifyOnlineState('station')}
}
function endTurn(){
  if(isOnlineGame()&&!onlineCanControl())return
  try{
    clearSel()
    // 结束回合时清除所有光圈
    SEL.hl.clear();SEL.phase='SEL';SEL.rangeLabel=''
    if(G){G.hoverRangeUnit=null;G.hoverRangeType=''}
    nextTurn()
    if(G)G._centerOnCur()
    notifyOnlineState('end-turn')
  }catch(e){
    console.error('endTurn error:',e.message,e.stack)
    alert('结束回合出错: '+e.message)
  }
}

// ==================== 渲染 ====================
function render(){
  if(!G||!ctx||!G.cam)return
  let fast=G.cam.drag
  ctx.fillStyle=COL_BG;ctx.fillRect(0,0,W,H)
  let vr=G.cam.getVR()
  for(let x=vr[0];x<vr[2];x++)for(let y=vr[1];y<vr[3];y++)drawTile(x,y,fast)
  // 悬停范围显示（在覆盖层下方）
  if(!fast)drawHoverRange()
  // 移动预览：MOVE阶段悬停可移动格时显示攻击范围
  if(!fast)drawMovePreview()
  // 选中高亮
  drawSelectionHighlights()
  ENGINE.players.forEach(p=>p.buildings.forEach(b=>{if(b.gx>=vr[0]&&b.gx<vr[2]&&b.gy>=vr[1]&&b.gy<vr[3]&&canSeeEntity(b))drawBuilding(b)}))
  if(G.neutralBuildings)G.neutralBuildings.forEach(b=>{if(b.gx>=vr[0]&&b.gx<vr[2]&&b.gy>=vr[1]&&b.gy<vr[3])drawBuilding(b)})
  ENGINE.players.forEach(p=>p.units.forEach(u=>{if(u.gx>=vr[0]&&u.gx<vr[2]&&u.gy>=vr[1]&&u.gy<vr[3]&&canSeeEntity(u))drawUnit(u)}))
  G.dying.forEach(d=>drawDying(d))
  drawEffects()
  drawFogOverlay(vr,fast)
  if(G.buildMode&&G.ghostPos){
    let[gx,gy]=G.ghostPos;let hq=curP().getHQ()
    if(hq&&eDist([gx,gy],[hq.gx,hq.gy])<=5){
      let[sx,sy]=G.cam.g2s(gx,gy);let sz=TS*G.cam.z
      ctx.globalAlpha=0.4;ctx.fillStyle='#4a4a8a';ctx.fillRect(sx+2,sy+2,sz-4,sz-4);ctx.strokeStyle='#aaa';ctx.lineWidth=2;ctx.strokeRect(sx+2,sy+2,sz-4,sz-4);ctx.globalAlpha=1
      let n=curP().nextCollectorId()  // peek,不会消耗编号
      let expGold=r2(3*Math.pow(0.8,n))
      ctx.fillStyle='#caba6a';ctx.font='bold 14px sans-serif';ctx.textAlign='center';ctx.textBaseline='bottom'
      ctx.fillText('🪙'+expGold.toFixed(1)+'/回合',sx+sz/2,sy-4)
    }
  }
}

function drawTile(x,y,fast=false){
  let[sx,sy]=G.cam.g2s(x,y);let sz=TS*G.cam.z
  let seed=x*1000+y;let r=((seed*9301+49297)%233280)/233280;let tileIdx=Math.floor(r*3)
  let tile=G.grid.get(x,y)
  let td=TERRAIN_DATA[(tile&&tile.terrain)||0]||TERRAIN_DATA[0]
  let img=GROUND_TILES[tileIdx]
  if(img&&img.complete&&img.naturalWidth>0){
    try{ctx.drawImage(img,sx,sy,sz,sz)}catch(e){}
  }else{
    ctx.fillStyle=GROUND_COLORS[tileIdx]
    ctx.fillRect(sx,sy,sz,sz)
  }
  if(td.height>0){
    let terrainImg=TERRAIN_TEXTURES[td.height]
    if(terrainImg&&terrainImg.complete&&terrainImg.naturalWidth>0){
      try{ctx.drawImage(terrainImg,sx,sy,sz,sz)}catch(e){}
    }else{
      ctx.fillStyle=td.height===1?'rgba(94,112,52,0.48)':td.height===2?'rgba(118,104,62,0.58)':'rgba(125,121,112,0.72)'
      ctx.fillRect(sx,sy,sz,sz)
    }
    if(!terrainImg&&!fast&&sz>18){
      drawTerrainDetail(td,sx,sy,sz,x,y)
    }
  }
  if(!fast||sz>28){ctx.strokeStyle='#282828';ctx.lineWidth=1;ctx.strokeRect(sx,sy,sz,sz)}
  ctx.fillStyle='rgba(0,0,0,0.3)';ctx.fillRect(sx,sy,sz,sz)
}

function drawFogOverlay(vr,fast=false){
  if(!G||!ENGINE.players.length)return
  let p=curP()
  let t=Date.now()*0.001
  for(let x=vr[0];x<vr[2];x++)for(let y=vr[1];y<vr[3];y++){
    let vis=isTileVisible(x,y,p.id)
    if(vis)continue
    let exp=isTileExplored(x,y,p.id)
    let[sx,sy]=G.cam.g2s(x,y);let sz=TS*G.cam.z
    let wave=fast?0:(Math.sin(x*.65+y*.42+t*1.6)+Math.sin(x*.27-y*.58+t*1.1))*0.035
    ctx.fillStyle=exp?'rgba(4,6,12,'+(0.42+wave)+')':'rgba(2,3,8,'+(0.68+wave)+')'
    ctx.fillRect(sx,sy,sz,sz)
    if(!fast&&sz>18){
      ctx.strokeStyle=exp?'rgba(170,185,200,0.06)':'rgba(170,185,210,0.11)'
      ctx.lineWidth=Math.max(1,sz*.018)
      ctx.beginPath()
      ctx.moveTo(sx+sz*((x%3)*.18),sy+sz*.24)
      ctx.quadraticCurveTo(sx+sz*.52,sy+sz*(.06+((x+y)%4)*.08),sx+sz*.96,sy+sz*.32)
      ctx.stroke()
    }
  }
}

function drawRangeOutline(tiles,fillStyle,borderStyle,lineW){
  // 填充所有格子
  for(let k of tiles){
    let[gx,gy]=k.split(',').map(Number)
    if(!G.grid.ib(gx,gy))continue
    let[sx,sy]=G.cam.g2s(gx,gy);let sz=TS*G.cam.z
    ctx.fillStyle=fillStyle;ctx.fillRect(sx,sy,sz,sz)
  }
  // 外轮廓描边：只画朝外的边
  ctx.strokeStyle=borderStyle;ctx.lineWidth=lineW
  for(let k of tiles){
    let[gx,gy]=k.split(',').map(Number)
    if(!G.grid.ib(gx,gy))continue
    let[sx,sy]=G.cam.g2s(gx,gy);let sz=TS*G.cam.z
    // 上边
    if(!tiles.has(gx+','+(gy-1))){ctx.beginPath();ctx.moveTo(sx,sy);ctx.lineTo(sx+sz,sy);ctx.stroke()}
    // 下边
    if(!tiles.has(gx+','+(gy+1))){ctx.beginPath();ctx.moveTo(sx,sy+sz);ctx.lineTo(sx+sz,sy+sz);ctx.stroke()}
    // 左边
    if(!tiles.has((gx-1)+','+gy)){ctx.beginPath();ctx.moveTo(sx,sy);ctx.lineTo(sx,sy+sz);ctx.stroke()}
    // 右边
    if(!tiles.has((gx+1)+','+gy)){ctx.beginPath();ctx.moveTo(sx+sz,sy);ctx.lineTo(sx+sz,sy+sz);ctx.stroke()}
  }
}

function drawSelectionHighlights(){
  if(!SEL.hl.size)return
  var bc=''
  if(SEL.hc.includes('ff69b4'))bc='#c04080'
  else if(SEL.hc.includes('ff0000'))bc='#800000'
  else if(SEL.hc.includes('ffff00'))bc='#808000'
  else bc='#666'
  drawRangeOutline(SEL.hl,SEL.hc,bc,Math.max(3,TS*G.cam.z*0.08))
  // 标注范围文字
  if(SEL.rangeLabel&&SEL.hl.size>0){
    let pts=[...SEL.hl].map(k=>k.split(',').map(Number))
    let minX=Math.min(...pts.map(p=>p[0])),maxX=Math.max(...pts.map(p=>p[0]))
    let minY=Math.min(...pts.map(p=>p[1]))
    let labelX=Math.floor((minX+maxX)/2)
    let[sx,sy]=G.cam.g2s(labelX,minY-1);let sz=TS*G.cam.z
    ctx.fillStyle='rgba(0,0,0,0.7)';let tw=ctx.measureText(SEL.rangeLabel).width||60
    ctx.fillRect(sx+sz/2-tw/2-4,sy-22,tw+8,18)
    ctx.fillStyle='#fff';ctx.font='bold 12px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle'
    ctx.fillText(SEL.rangeLabel,sx+sz/2,sy-13)
  }
}

function drawHoverRange(){
  let hr=G.hoverRangeUnit
  if(!hr)return
  let rad=0,label='',fillColor=''
  if(G.hoverRangeType==='threat'){
    rad=hr.speed+getMaxPossibleRange(hr)
    label='威胁范围('+rad+')'
    fillColor='rgba(128,0,128,0.15)'
  }else if(G.hoverRangeType==='selfRange'){
    rad=getMaxPossibleRange(hr)
    label='射程('+rad+')'
    fillColor='rgba(0,128,255,0.15)'
  }else if(G.hoverRangeType==='selfThreat'){
    rad=hr.speed+getMaxPossibleRange(hr)
    label='最大威胁('+rad+')'
    fillColor='rgba(128,0,128,0.15)'
  }
  if(rad<=0)return
  let tiles=getTilesInEuclidean(hr.gx,hr.gy,rad)
  let bc=G.hoverRangeType==='threat'?'rgba(128,0,128,0.8)':'rgba(0,80,200,0.8)'
  drawRangeOutline(tiles,fillColor,bc,Math.max(3,TS*G.cam.z*0.08))
  // 标注文字
  if(label){
    let[sx,sy]=G.cam.g2s(hr.gx,hr.gy-1);let sz=TS*G.cam.z
    ctx.fillStyle='rgba(0,0,0,0.7)';let tw=ctx.measureText(label).width||80
    ctx.fillRect(sx+sz/2-tw/2-4,sy-22,tw+8,18)
    ctx.fillStyle='#d0b0ff';ctx.font='bold 12px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle'
    ctx.fillText(label,sx+sz/2,sy-13)
  }
}

function drawMovePreview(){
  if(!G||!G.movePreviewPos)return
  var[gx,gy]=G.movePreviewPos
  var u=SEL.u
  var rad=u?getMaxPossibleRange(u,gx,gy):0
  if(rad<=0)return
  var tiles=getTilesInEuclidean(gx,gy,rad)
  var targets=G.movePreviewTargets||new Set()
  // 有目标时用深蓝，无目标时用浅蓝
  var fc=targets.size?'rgba(0,120,220,0.25)':'rgba(0,80,180,0.1)'
  drawRangeOutline(tiles,fc,'rgba(0,80,200,0.7)',Math.max(3,TS*G.cam.z*0.08))
  // 有目标时再标红目标位置
  if(targets.size){
    for(var k of targets){
      var[tx,ty]=k.split(',').map(Number);if(!G.grid.ib(tx,ty))continue
      var[tsx,tsy]=G.cam.g2s(tx,ty);var tsz=TS*G.cam.z
      ctx.fillStyle='rgba(220,50,50,0.3)';ctx.fillRect(tsx,tsy,tsz,tsz)
      // 目标外边框
      ctx.strokeStyle='rgba(220,50,50,0.9)';ctx.lineWidth=Math.max(2,tsz*0.06)
      ctx.beginPath();ctx.moveTo(tsx+2,tsy);ctx.lineTo(tsx+tsz-2,tsy);ctx.stroke()
      ctx.beginPath();ctx.moveTo(tsx+2,tsy+tsz);ctx.lineTo(tsx+tsz-2,tsy+tsz);ctx.stroke()
      ctx.beginPath();ctx.moveTo(tsx,tsy+2);ctx.lineTo(tsx,tsy+tsz-2);ctx.stroke()
      ctx.beginPath();ctx.moveTo(tsx+tsz,tsy+2);ctx.lineTo(tsx+tsz,tsy+tsz-2);ctx.stroke()
    }
  }
  // 标注
  var label='有效射程'+rad+(targets.size?' · '+targets.size+'目标':'')
  var[sx,sy]=G.cam.g2s(gx,gy-1);var sz=TS*G.cam.z
  ctx.fillStyle='rgba(0,0,0,0.7)';var tw=ctx.measureText(label).width||80
  ctx.fillRect(sx+sz/2-tw/2-4,sy-22,tw+8,18)
  ctx.fillStyle='#80c0ff';ctx.font='bold 12px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle'
  ctx.fillText(label,sx+sz/2,sy-13)
}

function drawUnit(u){
  let[sx,sy]=G.cam.g2s(u.gx,u.gy);let sz=TS*G.cam.z;let hsz=sz/2;let cx=sx+hsz,cy=sy+hsz
  let sprKey=u.equip?u.type+'-'+u.equip.name:u.type
  let img=SPR[sprKey]
  if(img===undefined){
    let impath='assets/images/'+sprKey+'.png'
    SPR[sprKey]=null
    let testImg=new Image()
    testImg.onload=function(){SPR[sprKey]=testImg}
    testImg.onerror=function(){SPR[sprKey]=null}
    try{testImg.src=impath}catch(e){SPR[sprKey]=null}
    img=null
  }
  if(img&&img.complete&&img.naturalWidth>0){
    try{ctx.drawImage(img,sx,sy,sz,sz)}catch(e){}
  }else{
    let fallback=SPR[u.type]
    if(fallback&&fallback.complete&&fallback.naturalWidth>0){
      try{ctx.drawImage(fallback,sx,sy,sz,sz)}catch(e){}
    }else{
      ctx.fillStyle=PLAYER_COLORS[u.pid];ctx.strokeStyle='#222';ctx.lineWidth=Math.max(1,sz*.04)
      if(u.type==='士兵'||u.type==='军用吉普'||u.type==='自杀无人机'){
        ctx.beginPath();ctx.arc(cx,cy,hsz*.5,0,Math.PI*2);ctx.fill();ctx.stroke()
      }else if(u.type==='坦克'||u.type==='装甲车'){
        ctx.fillRect(sx+sz*.1,sy+sz*.15,sz*.8,sz*.7);ctx.strokeRect(sx+sz*.1,sy+sz*.15,sz*.8,sz*.7)
      }else if(u.isAir){
        ctx.beginPath();ctx.moveTo(cx,sy+sz*.15);ctx.lineTo(cx+sz*.5,cy);ctx.lineTo(cx,sy+sz*.85);ctx.lineTo(cx-sz*.5,cy);ctx.closePath();ctx.fill();ctx.stroke()
      }else{
        ctx.beginPath();ctx.arc(cx,cy,hsz*.5,0,Math.PI*2);ctx.fill();ctx.stroke()
      }
    }
  }
  // 归属玩家方框（一直显示）
  ctx.strokeStyle=PLAYER_COLORS[u.pid];ctx.lineWidth=Math.max(3,sz*0.06);ctx.strokeRect(sx+1,sy+1,sz-2,sz-2)
  // 可行动小圈（仅当前玩家可行动单位显示）
  if(!u.done&&ENGINE&&u.pid===ENGINE.cur){ctx.beginPath();ctx.arc(cx,cy,sz*0.2,0,Math.PI*2);ctx.strokeStyle=PLAYER_COLORS[u.pid];ctx.lineWidth=Math.max(2,sz*0.05);ctx.stroke()}
  let bw=sz*.7,bh=Math.max(3,sz*.06),bx=sx+(sz-bw)/2,by=sy+sz-bh-3
  let ratio=Math.max(0,u.hp/u.maxHp)
  ctx.fillStyle='#14141e';ctx.fillRect(bx,by,bw,bh)
  ctx.fillStyle=ratio>.5?'#32dc32':ratio>.25?'#d4c040':'#dc3232';ctx.fillRect(bx,by,bw*ratio,bh)
  // 显示剩余攻击次数
  if(u.attacks>1&&!u.done){
    ctx.fillStyle='#fff';ctx.font='bold '+(sz*.2)+'px sans-serif';ctx.textAlign='center';ctx.textBaseline='bottom'
    ctx.fillText('⚔️'+u.remainingAttacks,cx,by-2)
  }
  // 自毁标记
  if(u.selfDestruct){
    ctx.fillStyle='#ff4444';ctx.font='bold '+(sz*.2)+'px sans-serif';ctx.textAlign='right';ctx.textBaseline='top'
    ctx.fillText('💥',sx+sz-2,sy+2)
  }
}

function drawBuilding(b){
  let[sx,sy]=G.cam.g2s(b.gx,b.gy);let sz=TS*G.cam.z
  let name=''
  if(b.type==='大本营')name=b.tier>=2?'大本营T3':'大本营 T'+(b.tier+1)
  else if(b.type==='据点'&&b.outpostTier>0)name=b.outpostBranch==='combat'?'战斗型T2据点':'资源型T2据点'
  else name=b.type
  let img=SPR[name]
  if(!img){
    img=new Image()
    let loaded=false
    img.onload=function(){SPR[name]=this;loaded=true}
    img.onerror=function(){
      if(!loaded){
        let img2=new Image()
        img2.onload=function(){SPR[name]=img2}
        img2.onerror=function(){SPR[name]=null}
        try{img2.src='assets/images/'+name+'.jpg'}catch(e){SPR[name]=null}
      }
    }
    try{img.src='assets/images/'+name+'.png'}catch(e){SPR[name]=null}
  }
  if(img&&img.complete&&img.naturalWidth>0){
    try{ctx.drawImage(img,sx,sy,sz,sz)}catch(e){}
    // 归属玩家方框
    if(b.pid>=0){ctx.strokeStyle=PLAYER_COLORS[b.pid];ctx.lineWidth=Math.max(3,sz*0.06);ctx.strokeRect(sx+2,sy+2,sz-4,sz-4)}
    let bw=sz*.6,bh=Math.max(3,sz*.06),bx=sx+(sz-bw)/2,by=sy+sz-bh-3
    let ratio=Math.max(0,b.hp/b.maxHp)
    ctx.fillStyle='#14141e';ctx.fillRect(bx,by,bw,bh)
    ctx.fillStyle=ratio>.5?'#32dc32':ratio>.25?'#d4c040':'#dc3232';ctx.fillRect(bx,by,bw*ratio,bh)
    return
  }
  // 回退图标
  if(b.type==='大本营'){
    let colors=['#3a6a3a','#3a5a8a','#8a5a3a'];let icons=['▲','◆','⬟']
    ctx.fillStyle=colors[b.tier]||'#3a5a3a'
    ctx.fillRect(sx+2,sy+2,sz-4,sz-4);ctx.strokeStyle='#888';ctx.lineWidth=2;ctx.strokeRect(sx+2,sy+2,sz-4,sz-4)
    ctx.fillStyle=COL_WHITE;ctx.font='bold '+Math.floor(sz*.4)+'px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle'
    ctx.fillText(icons[b.tier]||'▲',sx+sz/2,sy+sz/2)
  }else if(b.type==='据点'){
    ctx.fillStyle=b.pid>=0?PLAYER_COLORS[b.pid]:'#6a6a7a'
    ctx.fillRect(sx+2,sy+2,sz-4,sz-4);ctx.strokeStyle='#888';ctx.lineWidth=2;ctx.strokeRect(sx+2,sy+2,sz-4,sz-4)
    ctx.fillStyle=COL_WHITE;ctx.font='bold '+Math.floor(sz*.4)+'px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle'
    let icon=b.outpostTier>0?(b.outpostBranch==='combat'?'⚔️':'💰'):'⚑'
    ctx.fillText(icon,sx+sz/2,sy+sz/2)
  }
  let bw=sz*.6,bh=Math.max(3,sz*.06),bx=sx+(sz-bw)/2,by=sy+sz-bh-3
  let ratio=Math.max(0,b.hp/b.maxHp)
  ctx.fillStyle='#14141e';ctx.fillRect(bx,by,bw,bh)
  ctx.fillStyle=ratio>.5?'#32dc32':ratio>.25?'#d4c040':'#dc3232';ctx.fillRect(bx,by,bw*ratio,bh)
  if(b.underConstruction){
    ctx.fillStyle='#8888ff80';ctx.fillRect(sx+2,sy+2,sz-4,4)
    let pct=1-(b.buildTimer||4)/4
    ctx.fillStyle='#4444ff';ctx.fillRect(sx+2,sy+2,(sz-4)*pct,4)
  }
}

function drawDying(d){
  let u=d.ent;if(!u)return
  if(u.pid!==curP().id&&!isTileVisible(u.gx,u.gy,curP().id))return
  ctx.globalAlpha=Math.max(0,d.alpha/200)
  drawUnit(u)
  let[sx,sy]=G.cam.g2s(u.gx,u.gy);let sz=TS*G.cam.z
  ctx.fillStyle='#ff000080';ctx.fillRect(sx,sy,sz,sz)
  ctx.globalAlpha=1
}
function drawEffects(){
  if(!G||!G.effects)return
  G.effects.forEach(function(e){
    var alpha=1
    if(e.life>90)alpha=(120-e.life)/30     // 前30帧渐入
    else if(e.life>30)alpha=1               // 中间60帧保持
    else alpha=e.life/30                    // 后30帧渐出
    var sx=G.cam.g2s(e.gx,e.gy)[0],sy=G.cam.g2s(e.gx,e.gy)[1],sz=TS*G.cam.z
    ctx.globalAlpha=alpha
    ctx.font='bold '+(sz*0.5)+'px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle'
    if(e.type==='research'){
      ctx.fillText('🔬',sx+sz/2,sy+sz/2-8)
    }else{
      ctx.fillStyle='#4488ff'
      var ax=sx+sz-8,ay=sy+4,s=1.3
      ctx.beginPath();ctx.moveTo(ax,ay-s*10);ctx.lineTo(ax-s*8,ay+s*3);ctx.lineTo(ax+s*8,ay+s*3);ctx.closePath();ctx.fill()
    }
    ctx.globalAlpha=1
  })
}

// ==================== 回合提示 ====================
let notifyTimer=0
function showTurnNotify(){
  let el=document.getElementById('turn-notify');let p=curP()
  document.getElementById('notifyTxt').textContent='第 '+ENGINE.turn+' 回合 — '+p.name
  document.getElementById('notifyTxt').style.color=PLAYER_COLORS[p.id]
  el.style.display='flex';notifyTimer=50
}

// ==================== 菜单函数 ====================
function showPlayerSel(){
  startBGM()
  document.getElementById('menu').style.display='none'
  document.getElementById('player-sel').style.display='flex'
}
function backToMenu(){
  document.getElementById('player-sel').style.display='none'
  document.getElementById('menu').style.display='flex'
}
function openEncyclopedia(){
  try{window.open('encyclopedia/index.html','_blank')}catch(e){}
}
function startGame(n){
  console.log('startGame called with n='+n)
  document.getElementById('player-sel').style.display='none'
  document.getElementById('gameOver').style.display='none'
  document.getElementById('menu').style.display='none'
  if(n<=2){MAP_W=60;MAP_H=30}else if(n===3){MAP_W=60;MAP_H=60}else{MAP_W=80;MAP_H=80}
  console.log('Map:',MAP_W,'x',MAP_H)
  initEngine(n)
  try{
    new Game()
  }catch(e){
    console.error('Game constructor error:',e.message,e.stack)
    alert('游戏初始化失败: '+e.message)
    return
  }
  startBGM()
  showTurnNotify()
}

// ==================== 音效 ====================
function playSE(name,cut){
  try{
    var a=new Audio('assets/audio/'+name+'.mp3');a.volume=0.5
    var t=cut||600
    if(name==='upgrade'){a.playbackRate=2.0;t=2600}
    if(name==='victory'){a.currentTime=1;t=3500}
    a.play()
    setTimeout(function(){try{a.pause()}catch(e){}},t)
  }catch(e){}
}
function playAttackSE(u){
  var heavy=['坦克','野战炮','火箭炮','轰炸机']
  var sd=heavy.includes(u.type)?'cannon':'mg'
  var cut=u.attacks>1?400:600
  playSE(sd,cut)
}

// ==================== 背景音乐 ====================
var BGM_AUDIO=null
function startBGM(){
  try{
    if(BGM_AUDIO)return
    BGM_AUDIO=new Audio('assets/audio/bgm.mp3')
    BGM_AUDIO.loop=true
    BGM_AUDIO.volume=0.4
    BGM_AUDIO.play()
  }catch(e){console.log('BGM:',e.message)}
}
function stopBGM(){
  try{if(BGM_AUDIO){BGM_AUDIO.pause();BGM_AUDIO=null}}catch(e){}
}

// ==================== 主循环 ====================
function gameLoop(ts=0){
  try{
    let minFrame=G&&G.cam&&G.cam.drag?33:16
    if(ts-lastFrameTime>=minFrame){
      lastFrameTime=ts
      if(G&&ENGINE.state==='PLAYING'){
        G.update();render()
      }else if(ctx){
        ctx.fillStyle='#1a1a2a';ctx.fillRect(0,0,W,H)
        ctx.fillStyle='#6a6a7a';ctx.font='18px sans-serif';ctx.textAlign='center'
        ctx.fillText('G='+(!!G)+' ST='+ENGINE.state+' P='+ENGINE.players.length,W/2,H/2)
      }
    }else if(ctx){
    }
  }catch(e){}
  if(notifyTimer>0){
    notifyTimer--
    if(notifyTimer===0)document.getElementById('turn-notify').style.display='none'
  }
  requestAnimationFrame(gameLoop)
}

// ==================== 初始化 ====================
function boot(){
  cvs=document.getElementById('gc')
  if(!cvs){setTimeout(boot,50);return}
  ctx=cvs.getContext('2d')
  resize()
  let md=false
  cvs.addEventListener('mousedown',e=>{
    if(!G)return
    if(e.button===0){md=true;G.cam.startDrag(e.clientX,e.clientY);let[gx,gy]=G.cam.s2g(e.clientX,e.clientY);G._handleClick(gx,gy)}
    if(e.button===2)e.preventDefault()
  })
  cvs.addEventListener('mousemove',e=>{
    if(!G)return
    if(md){
      G.cam.updateDrag(e.clientX,e.clientY)
      G.hoverRangeUnit=null;G.hoverRangeType=''
      G.movePreviewPos=null;G.movePreviewTargets=null
      let tip=document.getElementById('tooltip');if(tip)tip.style.display='none'
      return
    }
    let[gx,gy]=G.cam.s2g(e.clientX,e.clientY)
    if(G.buildMode)G.ghostPos=[gx,gy]
    let t=G.grid.get(gx,gy);let tip=document.getElementById('tooltip')
    // 更新悬停范围
    G.hoverRangeUnit=null;G.hoverRangeType=''
    if(t&&t.occ&&canSeeEntity(t.occ,curP().id)){
      let o=t.occ;let lines=''
      let td=terrainAt(gx,gy)
      let terrainTxt=' | 地形:'+td.name+' H'+td.height
      if(o instanceof Unit){
        let pidLabel=o.pid>=0?'玩家'+(o.pid+1):'中立'
        let shownDmg=o.eD?o.eD({isAir:false,armor:0,gx:o.gx,gy:o.gy}):o.damage
        lines=pidLabel+' | '+o.type+' HP:'+o.hp.toFixed(1)+'/'+o.maxHp+' 护甲:'+o.armor+' 伤害:'+shownDmg+' 射程:'+getMaxPossibleRange(o,gx,gy)+terrainTxt+(o.done?' [Done]':' [Ready]')
        if(o.attacks>1)lines+=' 攻击:'+o.remainingAttacks+'/'+o.attacks
        // 悬停敌方→显示最大威胁范围
        if(o.pid!==curP().id&&o.pid>=0){
          G.hoverRangeUnit=o;G.hoverRangeType='threat'
        }else if(o.pid===curP().id){
          // 悬停自己单位→显示自己的射程
          G.hoverRangeUnit=o;G.hoverRangeType='selfRange'
        }
      }else{
        let pidLabel=o.pid>=0?'玩家'+(o.pid+1):'中立'
        lines=pidLabel+' | '+o.type+' HP:'+Math.floor(o.hp)+'/'+Math.floor(o.maxHp)+' 护甲:'+o.armor+terrainTxt+(o.type==='大本营'?' T'+(o.tier+1):'')
        if(o.type==='据点'&&o.outpostTier>0)lines+=' '+(o.outpostBranch==='combat'?'战斗型':'经济型')
      }
      tip.textContent=lines;tip.style.display='block';tip.style.left=Math.max(10,Math.min(e.clientX+15,W-280))+'px';tip.style.top=Math.min(e.clientY-10,H-60)+'px'
    }else if(t){
      let td=terrainAt(gx,gy)
      tip.textContent='地形:'+td.name+' | 高度:'+td.height+' | 移动消耗:'+td.moveCost
      tip.style.display='block';tip.style.left=Math.max(10,Math.min(e.clientX+15,W-280))+'px';tip.style.top=Math.min(e.clientY-10,H-60)+'px'
    }else tip.style.display='none'
    // 移动预览：MOVE阶段悬停可移动格子时显示攻击范围
    G.movePreviewPos=null;G.movePreviewTargets=null
    if(SEL.phase==='MOVE'&&SEL.u&&SEL.hl.has(gx+','+gy)){
      let u=SEL.u
      if(!u.done&&u.rl===0&&u.remainingAttacks>0){
        G.movePreviewPos=[gx,gy]
        G.movePreviewTargets=getAttackTargets(u,gx,gy,curP().id)
        if(G.movePreviewTargets.size)console.log('movePreview: '+G.movePreviewTargets.size+' targets from '+gx+','+gy)
      }
    }
  })
  cvs.addEventListener('mouseup',e=>{if(e.button===0&&G&&G.cam){md=false;G.cam.endDrag()}})
  cvs.addEventListener('wheel',e=>{e.preventDefault();if(!G||!G.cam)return;if(e.deltaY<0)G.cam.zoomAt(e.clientX,e.clientY,.15);else G.cam.zoomAt(e.clientX,e.clientY,-.15)},{passive:false})
  cvs.addEventListener('contextmenu',e=>e.preventDefault())
  document.addEventListener('keydown',e=>{
    if(e.key==='F11'){e.preventDefault();if(!document.fullscreenElement)document.body.requestFullscreen();else document.exitFullscreen();return}
    if(!G)return;let sp=8/Math.max(.1,G.cam.z)
    if(e.key==='w'||e.key==='W'||e.key==='ArrowUp')G.cam.pan(0,sp)
    if(e.key==='s'||e.key==='S'||e.key==='ArrowDown')G.cam.pan(0,-sp)
    if(e.key==='a'||e.key==='A'||e.key==='ArrowLeft')G.cam.pan(sp,0)
    if(e.key==='d'||e.key==='D'||e.key==='ArrowRight')G.cam.pan(-sp,0)
    if(e.key==='Escape')clearSel()
    if(e.key==='Enter'&&ENGINE.state==='PLAYING')endTurn()
  })
  gameLoop()
}
window.addEventListener('resize',resize)
// 贴图缓存
let SPR={}
setTimeout(boot,10)


