extends Node

## Allow only one GUI process. Exclusive localhost TCP bind for this node's life.
## Headless (CI / --script) skips the lock.

const LOCK_PORT := 47144
const LOCK_ADDR := "127.0.0.1"

var _server: TCPServer


func _enter_tree() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_server = TCPServer.new()
	var err := _server.listen(LOCK_PORT, LOCK_ADDR)
	if err == OK:
		return
	var title := str(ProjectSettings.get_setting("application/config/name", "Ultima IV++"))
	var msg := "%s is already running.\n%s는 이미 실행 중입니다." % [title, title]
	push_error(
		"Single-instance lock busy on %s:%d (%s)."
		% [LOCK_ADDR, LOCK_PORT, error_string(err)]
	)
	OS.alert(msg, title)
	get_tree().quit()
	_server = null
