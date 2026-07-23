const http = require("http");
const fs = require("fs");
const path = require("path");
const { WebSocketServer } = require("ws");

const ROOT = path.resolve(__dirname, "..");
const PORT = Number(process.env.PORT || 3000);
const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".mp3": "audio/mpeg",
  ".ico": "image/x-icon"
};

const rooms = new Map();

function send(ws, msg) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(msg));
}

function roomCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  for (let tries = 0; tries < 100; tries++) {
    let code = "";
    for (let i = 0; i < 5; i++) code += chars[Math.floor(Math.random() * chars.length)];
    if (!rooms.has(code)) return code;
  }
  return String(Date.now()).slice(-5);
}

function broadcast(room, msg, except) {
  room.clients.forEach(client => {
    if (client.ws !== except) send(client.ws, msg);
  });
}

function staticFile(req, res) {
  let urlPath;
  try {
    urlPath = decodeURIComponent(req.url.split("?")[0]);
  } catch (err) {
    res.writeHead(400);
    res.end("bad request");
    return;
  }
  if (urlPath === "/") urlPath = "/game.html";
  const file = path.normalize(path.join(ROOT, urlPath));
  if (!file.startsWith(ROOT)) {
    res.writeHead(403);
    res.end("forbidden");
    return;
  }
  fs.readFile(file, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end("not found");
      return;
    }
    res.writeHead(200, { "Content-Type": MIME[path.extname(file).toLowerCase()] || "application/octet-stream" });
    res.end(data);
  });
}

const server = http.createServer(staticFile);
const wss = new WebSocketServer({ server });

wss.on("connection", ws => {
  const client = { ws, roomId: "", playerId: -1 };

  ws.on("message", raw => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch (err) {
      send(ws, { type: "error", message: "消息格式错误" });
      return;
    }

    if (msg.type === "create") {
      const players = Math.max(2, Math.min(4, Number(msg.players || 2)));
      const id = roomCode();
      const room = { id, players, state: null, clients: [] };
      rooms.set(id, room);
      client.roomId = id;
      client.playerId = 0;
      room.clients.push(client);
      send(ws, { type: "room-created", roomId: id, playerId: 0, players });
      console.log("room created", id, "players", players);
      return;
    }

    if (msg.type === "join") {
      const id = String(msg.roomId || "").trim().toUpperCase();
      const room = rooms.get(id);
      if (!room) {
        send(ws, { type: "error", message: "房间不存在" });
        return;
      }
      if (room.clients.length >= room.players) {
        send(ws, { type: "error", message: "房间已满" });
        return;
      }
      const used = new Set(room.clients.map(c => c.playerId));
      let playerId = 0;
      while (used.has(playerId)) playerId++;
      client.roomId = id;
      client.playerId = playerId;
      room.clients.push(client);
      send(ws, { type: "joined", roomId: id, playerId, players: room.players, state: room.state });
      broadcast(room, { type: "peer-joined", roomId: id, playerId, count: room.clients.length }, ws);
      console.log("player joined", id, playerId);
      return;
    }

    if (msg.type === "state") {
      const room = rooms.get(client.roomId || msg.roomId);
      if (!room || client.playerId < 0) {
        send(ws, { type: "error", message: "尚未加入房间" });
        return;
      }
      if (Number(msg.playerId) !== client.playerId) {
        send(ws, { type: "error", message: "玩家编号不匹配" });
        return;
      }
      room.state = msg.state;
      broadcast(room, { type: "state", roomId: room.id, playerId: client.playerId, reason: msg.reason, state: room.state }, ws);
      return;
    }
  });

  ws.on("close", () => {
    if (!client.roomId) return;
    const room = rooms.get(client.roomId);
    if (!room) return;
    room.clients = room.clients.filter(c => c !== client);
    broadcast(room, { type: "peer-left", roomId: room.id, playerId: client.playerId });
    if (!room.clients.length) rooms.delete(room.id);
    console.log("player left", client.roomId, client.playerId);
  });
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Green Legion server running on http://0.0.0.0:${PORT}`);
});
