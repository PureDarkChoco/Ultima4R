class_name VirtueQuestionTree
extends RefCounted

## Faithful port of xu4 IntroController question tournament.
## Final winning virtue index == avatar class (0..7).

var question_tree: Array[int] = []
var answer_ind: int = 8
var question_round: int = 0
var rng := RandomNumberGenerator.new()


func start(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	question_tree.clear()
	question_tree.resize(15)
	for i in 8:
		question_tree[i] = i

	# Shuffle first eight (xu4 uses 8 swaps with random indices).
	for i in 8:
		var r := rng.randi_range(0, 7)
		var tmp := question_tree[r]
		question_tree[r] = question_tree[i]
		question_tree[i] = tmp

	answer_ind = 8
	question_round = 0
	_order_pair(0)


func current_pair() -> Vector2i:
	var i1 := question_round * 2
	return Vector2i(question_tree[i1], question_tree[i1 + 1])


## answer: 0 = first virtue, 1 = second virtue.
## Returns true when all 7 rounds are done.
func answer(choice: int) -> bool:
	if choice == 0:
		question_tree[answer_ind] = question_tree[question_round * 2]
	else:
		question_tree[answer_ind] = question_tree[question_round * 2 + 1]

	var rejected := question_tree[question_round * 2 + (0 if choice else 1)]
	var selected: int = question_tree[answer_ind]
	# selected/rejected available for abacus beads later
	var _beads := Vector2i(selected, rejected)

	answer_ind += 1
	question_round += 1

	if question_round > 6:
		return true

	_order_pair(question_round)
	return false


func winning_class() -> int:
	return question_tree[14]


func selected_virtues() -> Array[int]:
	## Indices 8..14 are the chosen virtues each round (xu4 karma bumps).
	var out: Array[int] = []
	for i in range(8, 15):
		out.append(question_tree[i])
	return out


func _order_pair(round_i: int) -> void:
	var a := round_i * 2
	if question_tree[a] > question_tree[a + 1]:
		var tmp := question_tree[a]
		question_tree[a] = question_tree[a + 1]
		question_tree[a + 1] = tmp
