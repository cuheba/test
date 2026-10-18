@tool
class_name Door
extends "res://block.gd"
## Дверь. Открывается (уходит в пол), когда ВСЕ кристаллы и плиты с тем же каналом (channel) горят.
## Размер и цвет задаются как у обычного блока.

@export var channel := "A"
@export var open_time := 1.5

var is_open := false
var _closed_y := 0.0


func _ready() -> void:
	super()
	_closed_y = position.y
	if not Engine.is_editor_hint():
		add_to_group("door")


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or is_open:
		return
	var triggers := get_tree().get_nodes_in_group("ch_" + channel)
	if triggers.is_empty():
		return
	for t in triggers:
		if not t.active:
			return
	_open()


func _open() -> void:
	is_open = true
	col.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(self, "position:y", _closed_y - size.y, open_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): mesh.visible = false)
