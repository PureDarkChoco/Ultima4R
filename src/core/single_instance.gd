extends Node

## Allow only one Ultima4R process in release exports. Binds a localhost UDP
## port for this node's lifetime. Editor / debug / headless never hard-quit on
## a busy lock (stale agent/editor Godot processes often hold the port).

const LOCK_PORT := 47144
const LOCK_ADDR := "127.0.0.1"

var _sock: PacketPeerUDP


func _enter_tree() -> void:
	if OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return
	_sock = PacketPeerUDP.new()
	var err := _sock.bind(LOCK_PORT, LOCK_ADDR)
	if err == OK:
		return
	var msg := (
		"Ultima4R is already running (single-instance lock on %s:%d, error %s)."
		% [LOCK_ADDR, LOCK_PORT, error_string(err)]
	)
	# Release export only — otherwise a leftover Godot makes the game "start then die".
	if OS.has_feature("release") and OS.has_feature("template"):
		push_error(msg)
		get_tree().quit()
		return
	push_warning(msg + " Continuing anyway (non-release).")
	_sock = null
