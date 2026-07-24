window.ONLINE={
  connected:false,
  socket:null,
  roomId:'',
  myPlayerId:-1,
  playerCount:2,
  applyingRemote:false,
  isHost:false
}

function onlineDefaultUrl(){
  if(location.protocol==='http:'||location.protocol==='https:'){
    return (location.protocol==='https:'?'wss://':'ws://')+location.host
  }
  return localStorage.getItem('onlineUrl')||'ws://175.178.173.76:3000'
}

function showOnlinePanel(){
  startBGM()
  document.getElementById('menu').style.display='none'
  document.getElementById('online-panel').style.display='flex'
  let url=document.getElementById('onlineUrl')
  if(url&&!url.value)url.value=onlineDefaultUrl()
  onlineSelectPlayers(window.ONLINE.playerCount||2)
}

function hideOnlinePanel(){
  document.getElementById('online-panel').style.display='none'
  if(!window.ONLINE.connected)document.getElementById('menu').style.display='flex'
}

function onlineSelectPlayers(n){
  window.ONLINE.playerCount=n
  document.querySelectorAll('.online-players .btn').forEach(function(btn){
    btn.classList.toggle('selected',btn.textContent.indexOf(String(n))>=0)
  })
}

function onlineSetStatus(text){
  let el=document.getElementById('onlineStatus')
  if(el)el.textContent=text
  let hud=document.getElementById('onlineHud')
  if(hud&&window.ONLINE.connected){
    let mine=window.ONLINE.myPlayerId>=0?'P'+(window.ONLINE.myPlayerId+1):'未入座'
    let turn=ENGINE&&ENGINE.players&&ENGINE.players.length?(window.ONLINE.myPlayerId===ENGINE.cur?'轮到你':'等 P'+(ENGINE.cur+1)):'等待开局'
    hud.textContent='联机 '+window.ONLINE.roomId+' · '+mine+' · '+turn
  }else if(hud){
    hud.textContent=''
  }
}
window.onlineSetStatus=onlineSetStatus

function onlineTurnText(){
  if(!isOnlineGame())return ''
  let turn='第 '+ENGINE.turn+' 回合，当前玩家 '+(ENGINE.cur+1)
  if(window.ONLINE.myPlayerId===ENGINE.cur)return turn+'：轮到你操作'
  return turn+'：等待玩家 '+(ENGINE.cur+1)
}

function onlineConnect(){
  return new Promise(function(resolve,reject){
    let url=(document.getElementById('onlineUrl').value||onlineDefaultUrl()).trim()
    localStorage.setItem('onlineUrl',url)
    onlineSetStatus('连接服务器中...\n'+url)
    let ws
    try{ws=new WebSocket(url)}catch(e){reject(e);return}
    ws.onopen=function(){
      window.ONLINE.socket=ws
      window.ONLINE.connected=true
      resolve(ws)
    }
    ws.onerror=function(){reject(new Error('连接失败，请确认服务器已启动并开放端口'))}
    ws.onclose=function(){
      window.ONLINE.connected=false
      onlineSetStatus('连接已断开')
    }
    ws.onmessage=function(ev){
      let msg
      try{msg=JSON.parse(ev.data)}catch(e){return}
      onlineHandleMessage(msg)
    }
  })
}

function onlineSend(msg){
  let ws=window.ONLINE.socket
  if(!ws||ws.readyState!==WebSocket.OPEN)return false
  ws.send(JSON.stringify(msg))
  return true
}

async function onlineCreateRoom(){
  try{
    let ws=window.ONLINE.socket
    if(!ws||ws.readyState!==WebSocket.OPEN)await onlineConnect()
    window.ONLINE.isHost=true
    onlineSend({type:'create',players:window.ONLINE.playerCount})
  }catch(e){
    onlineSetStatus(e.message)
  }
}

async function onlineJoinRoom(){
  try{
    let roomId=(document.getElementById('onlineRoom').value||'').trim().toUpperCase()
    if(!roomId){onlineSetStatus('请输入房间号');return}
    let ws=window.ONLINE.socket
    if(!ws||ws.readyState!==WebSocket.OPEN)await onlineConnect()
    window.ONLINE.isHost=false
    onlineSend({type:'join',roomId:roomId})
  }catch(e){
    onlineSetStatus(e.message)
  }
}

function onlineHandleMessage(msg){
  if(msg.type==='error'){
    onlineSetStatus('错误：'+msg.message)
    return
  }
  if(msg.type==='room-created'){
    window.ONLINE.roomId=msg.roomId
    window.ONLINE.myPlayerId=msg.playerId
    window.ONLINE.playerCount=msg.players
    document.getElementById('onlineRoom').value=msg.roomId
    document.getElementById('online-panel').style.display='none'
    startGame(msg.players)
    onlineSendState('initial')
    onlineSetStatus('房间 '+msg.roomId+' 已创建\n你是玩家 1\n把房间号发给朋友加入')
    return
  }
  if(msg.type==='joined'){
    window.ONLINE.roomId=msg.roomId
    window.ONLINE.myPlayerId=msg.playerId
    window.ONLINE.playerCount=msg.players
    document.getElementById('online-panel').style.display='none'
    document.getElementById('menu').style.display='none'
    if(msg.state){
      window.ONLINE.applyingRemote=true
      deserializeGameState(msg.state,{center:true})
      window.ONLINE.applyingRemote=false
      showTurnNotify()
    }
    onlineSetStatus('已加入房间 '+msg.roomId+'\n你是玩家 '+(msg.playerId+1)+'\n'+onlineTurnText())
    return
  }
  if(msg.type==='peer-joined'){
    onlineSetStatus('房间 '+window.ONLINE.roomId+'\n玩家 '+(msg.playerId+1)+' 已加入\n'+onlineTurnText())
    if(window.ONLINE.isHost)onlineSendState('peer-joined')
    return
  }
  if(msg.type==='state'){
    if(msg.playerId===window.ONLINE.myPlayerId)return
    var _oldCur=ENGINE.cur
    window.ONLINE.applyingRemote=true
    deserializeGameState(msg.state,{center:true})
    window.ONLINE.applyingRemote=false
    if(ENGINE.state!=='GAME_OVER'&&ENGINE.cur!==_oldCur)showTurnNotify()
    onlineSetStatus('房间 '+window.ONLINE.roomId+'\n你是玩家 '+(window.ONLINE.myPlayerId+1)+'\n'+onlineTurnText())
    return
  }
}

function onlineSendState(reason){
  if(window.ONLINE.applyingRemote||!window.ONLINE.connected||!G||!ENGINE.players.length)return
  onlineSend({
    type:'state',
    roomId:window.ONLINE.roomId,
    playerId:window.ONLINE.myPlayerId,
    reason:reason||'state',
    state:serializeGameState()
  })
  onlineSetStatus('房间 '+window.ONLINE.roomId+'\n你是玩家 '+(window.ONLINE.myPlayerId+1)+'\n'+onlineTurnText())
}
window.onlineSendState=onlineSendState
