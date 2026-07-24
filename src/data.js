// ==================== 鏁版嵁 ====================
const UNIT_DATA={
  '士兵':{hp:1.5,armor:0,speed:3,damage:1,range:2,price:1,attacks:1,vision:5},
  '坦克':{hp:10,armor:2,speed:5,damage:4,range:3,price:7,attacks:1,vision:8},
  '军用吉普':{hp:3,armor:0,speed:8,damage:2,range:3,price:3,attacks:1,vision:11},
  '火箭炮':{hp:10,armor:0,speed:2,damage:7,range:15,price:18,attacks:1,vision:17},
  '野战炮':{hp:3,armor:1,speed:3,damage:5,range:6,price:5,attacks:1,vision:9},
  '装甲车':{hp:6,armor:1,speed:5,damage:1.5,range:3,price:6,attacks:3,canTargetAir:true,vision:8},
  '战斗机':{hp:5,armor:1,speed:10,damage:5.5,range:3,price:8,attacks:1,isAir:true,canTargetAir:true,vision:13},
  '轰炸机':{hp:16,armor:3,speed:5,damage:12,range:1.5,price:15,attacks:1,isAir:true,blast:1.5,reload:1,vision:7},
  '防空车':{hp:5,armor:1,speed:5,damage:3,range:4,price:10,attacks:1,canTargetAir:true,airDamage:8,airRange:14,vision:9},
  '自杀无人机':{hp:2,armor:0,speed:8,damage:4,range:1,price:2,attacks:1,selfDestruct:true,vision:9},
  '侦察机':{hp:2.5,armor:0,speed:12,damage:0,range:0,price:5,attacks:0,isAir:true,vision:11},
}
const U_NAMES=Object.keys(UNIT_DATA)
const BUILDING_DATA={
  '大本营':{tiers:[
    {hp:15,armor:0,gold:4.5,upgradeCost:10,upgradeTime:3,vision:7},
    {hp:30,armor:0.5,gold:7.5,upgradeCost:30,upgradeTime:5,vision:8},
    {hp:50,armor:1,gold:12,vision:9},
  ]},
  '据点':{hp:20,armor:0,gold:4.5,vision:5},
  '资源采集器':{hp:15,armor:0,gold:3,cost:8,vision:3},
}
const EQUIP_DATA={
  '士兵':[{name:'射手步枪',cost:0.5,dmg:0.5,range:4,speed:-1,canTargetAir:true,tier:'T1',researchCost:3,researchTime:1},
          {name:'反器械枪',cost:1.5,dmg:4,range:2,canTargetAir:true,tier:'T2',researchCost:5,researchTime:2}],
  '坦克':[{name:'穿甲炮',cost:2,dmg:3,range:1,tier:'T3',researchCost:10,researchTime:3},
          {name:'高爆炮',cost:1,dmg:-2,blast:2,tier:'T2',researchCost:5,researchTime:2}],
  '军用吉普':[{name:'火箭助推',cost:1,speed:5,hp:1,tier:'T2',researchCost:5,researchTime:2},
            {name:'重甲吉普',cost:1,armor:1,speed:-2,dmg:0.5,hp:0.5,tier:'T1',researchCost:3,researchTime:1}],
  '火箭炮':[{name:'对空雷达',cost:3,range:1,canTargetAir:true,tier:'T3',researchCost:10,researchTime:3}],
  '野战炮':[{name:'轻量化',cost:-1,dmg:-1,range:0,speed:2,hp:-1,tier:'T2',researchCost:5,researchTime:2},
            {name:'巨炮',cost:6,dmg:7,range:4,speed:-1,hp:2,tier:'T3',researchCost:10,researchTime:3}],
}
const STRATEGIC_TECH_DATA=[
  {name:'SpaceX 星链计划',tier:'T3',researchCost:30,researchTime:3,desc:'解锁全图视野，并使自杀无人机伤害 +1。'}
]

const TERRAIN_DATA=[
  {name:'平地',height:0,moveCost:1,color:'#2d3a2d',label:''},
  {name:'丘陵',height:1,moveCost:1.4,color:'#4a5a32',label:'丘'},
  {name:'高地',height:2,moveCost:1.8,color:'#68623f',label:'高'},
  {name:'山脉',height:3,moveCost:2.6,color:'#7b7770',label:'山'},
]

