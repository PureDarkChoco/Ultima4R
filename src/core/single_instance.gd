extends Node

## Allow only one Ultima4R process. Binds a localhost UDP port for the
## lifetime of this node; a second launch fails to bind and quits immediately.

const LOCK_PORT := 47144
const LOCK_ADDR := "127.0.0.1"

var _sock: PacketPeerUDP


func _enter_tree() -> void:
	_sock = PacketPeerUDP.new()
	var err := _sock.bind(LOCK_PORT, LOCK_ADDR)
	if err == OK:
		return
	push_error(
		"Ultima4R is already running (single-instance lock on %s:%d, error %s)."
		% [LOCK_ADDR, LOCK_PORT, error_string(err)]
	)
	# Quit before other autoloads / boot do meaningful work.
	get_tree().quit()
