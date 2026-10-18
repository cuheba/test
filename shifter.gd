@tool
class_name Shifter
extends "res://block.gd"
## Блок, который "есть" или "нет". Меняется, когда игрок гасит фонарь и не смотрит на него.
## В редакторе блок со Start Present = выключено рисуется призраком (сеткой точек).

@export var start_present := true:
	set = set_start_present

var present := true


func _ready() -> void:
	super()
	add_to_group("shifter")
	if not Engine.is_editor_hint():
		set_present(start_present)


func set_start_present(v: bool) -> void:
	start_present = v
	_apply()


func _apply() -> void:
	super()
	if col == null:
		return
	var ghost := Engine.is_editor_hint() and not start_present
	(mesh.material_override as ShaderMaterial).set_shader_parameter("ghost", 1.0 if ghost else 0.0)


func set_present(p: bool) -> void:
	present = p
	mesh.visible = p
	col.set_deferred("disabled", not p)


func flip() -> void:
	set_present(not present)
