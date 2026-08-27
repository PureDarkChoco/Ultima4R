class_name MenuHoldRepeat
extends RefCounted

## Shared held-direction repeater for menus and list cursors.
## Call poll() every frame with the currently held direction.

const INITIAL_DELAY := 0.5
const REPEAT_INTERVAL := 0.15

var _held := Vector2i.ZERO
var _elapsed := 0.0
var _repeating := false


func reset() -> void:
	_held = Vector2i.ZERO
	_elapsed = 0.0
	_repeating = false


func poll(delta: float, direction: Vector2i) -> Vector2i:
	var held := _cardinal(direction)
	if held == Vector2i.ZERO:
		reset()
		return Vector2i.ZERO
	if held != _held:
		_held = held
		_elapsed = 0.0
		_repeating = false
		return held
	_elapsed += maxf(delta, 0.0)
	var wait := REPEAT_INTERVAL if _repeating else INITIAL_DELAY
	if _elapsed < wait:
		return Vector2i.ZERO
	_elapsed = fmod(_elapsed - wait, REPEAT_INTERVAL)
	_repeating = true
	return held


func _cardinal(direction: Vector2i) -> Vector2i:
	## Vertical wins when both axes are held, matching existing list behavior.
	if direction.y != 0:
		return Vector2i(0, signi(direction.y))
	if direction.x != 0:
		return Vector2i(signi(direction.x), 0)
	return Vector2i.ZERO
