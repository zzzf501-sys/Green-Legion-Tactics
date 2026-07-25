extends SceneTree

const GameDatabaseScript = preload("res://scripts/core/game_database.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")

var server_pid = -1

func _initialize() -> void:
	server_pid = OS.create_process("node", ["server/server.js"])
	await create_timer(0.5).timeout
	var ws = WebSocketPeer.new()
	var err = ws.connect_to_url("ws://127.0.0.1:3000")
	if err != OK:
		push_error("Online smoke connect failed: " + str(err))
		_finish(1)
		return
	var opened = false
	for _i in range(30):
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			opened = true
			break
		await create_timer(0.1).timeout
	if not opened:
		push_error("Online smoke socket did not open")
		_finish(1)
		return
	ws.send_text(JSON.stringify({"type": "create", "players": 2}))
	var created = false
	var room_id = ""
	var player_id = -1
	for _i in range(30):
		ws.poll()
		while ws.get_available_packet_count() > 0:
			var msg = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if msg is Dictionary and msg.get("type", "") == "room-created":
				created = true
				room_id = str(msg.get("roomId", ""))
				player_id = int(msg.get("playerId", -1))
		if created:
			break
		await create_timer(0.1).timeout
	if not created or room_id.is_empty() or player_id != 0:
		push_error("Online smoke room creation failed")
		_finish(1)
		return
	var db = GameDatabaseScript.new()
	db.load_data()
	var state = GameStateScript.new()
	state.setup(db, 60, 30, 2)
	ws.send_text(JSON.stringify({
		"type": "state",
		"roomId": room_id,
		"playerId": player_id,
		"reason": "online-smoke",
		"state": state.to_dict()
	}))
	var rejoin = WebSocketPeer.new()
	err = rejoin.connect_to_url("ws://127.0.0.1:3000")
	if err != OK:
		push_error("Online smoke rejoin connect failed: " + str(err))
		_finish(1)
		return
	opened = false
	for _i in range(30):
		rejoin.poll()
		if rejoin.get_ready_state() == WebSocketPeer.STATE_OPEN:
			opened = true
			break
		await create_timer(0.1).timeout
	if not opened:
		push_error("Online smoke rejoin socket did not open")
		_finish(1)
		return
	rejoin.send_text(JSON.stringify({"type": "rejoin", "roomId": room_id, "playerId": player_id}))
	var rejoined = false
	for _i in range(30):
		rejoin.poll()
		while rejoin.get_available_packet_count() > 0:
			var msg = JSON.parse_string(rejoin.get_packet().get_string_from_utf8())
			if msg is Dictionary and msg.get("type", "") == "joined" and msg.has("state"):
				rejoined = true
		if rejoined:
			break
		await create_timer(0.1).timeout
	if not rejoined:
		push_error("Online smoke rejoin failed")
		_finish(1)
		return
	print("Godot online smoke test passed")
	ws.close()
	rejoin.close()
	_finish(0)

func _finish(code: int) -> void:
	if server_pid > 0:
		OS.kill(server_pid)
	quit(code)
