extends Node3D
## Логика уровня. Сам уровень (стены, двери, кристаллы, плиты, мобы) лежит в main.tscn как обычные узлы.

var goal_reached := false

@onready var player: Player = $Player
@onready var status: Label = $HUD/Status
@onready var charge_bar: ProgressBar = $HUD/ChargeBar


func _ready() -> void:
	player.lantern_toggled.connect(_on_lantern_toggled)
	$Level/Goal.body_entered.connect(_on_goal)


func _process(_delta: float) -> void:
	charge_bar.value = player.charge_ratio
	if goal_reached:
		return
	var mobs := get_tree().get_nodes_in_group("mob").size()
	status.text = "HP: %d / %d     Фонарь: %s     Мобов: %d" % [
		player.hp, player.max_hp, "ВКЛ" if player.lantern_on else "ВЫКЛ", mobs]


func _on_lantern_toggled(on: bool) -> void:
	if on:
		return
	# Фонарь выключен: всё, что игрок сейчас НЕ видит, перестраивается
	for s in get_tree().get_nodes_in_group("shifter"):
		if not player.can_see(s.global_position):
			s.flip()


func _on_goal(body: Node3D) -> void:
	if body == player and not goal_reached:
		goal_reached = true
		status.text = "Уровень пройден!"
