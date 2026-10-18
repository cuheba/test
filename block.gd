@tool
class_name Block
extends StaticBody3D
## Коробка с коллизией (стена, пол, колонна). Размер и цвет меняются в Инспекторе,
## и результат сразу виден в редакторе. Рисуется PS1-шейдером.

const PS1_SHADER := preload("res://ps1_object.gdshader")

@export var size := Vector3(2, 2, 2):
	set = set_size
@export var color := Color(0.5, 0.5, 0.5):
	set = set_color

var col: CollisionShape3D
var mesh: MeshInstance3D


func _ready() -> void:
	if col == null:
		col = CollisionShape3D.new()
		col.shape = BoxShape3D.new()
		add_child(col)
		mesh = MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		var mat := ShaderMaterial.new()
		mat.shader = PS1_SHADER
		mesh.material_override = mat
		add_child(mesh)
	_apply()


func set_size(v: Vector3) -> void:
	size = v
	_apply()


func set_color(v: Color) -> void:
	color = v
	_apply()


func _apply() -> void:
	if col == null:
		return
	(col.shape as BoxShape3D).size = size
	(mesh.mesh as BoxMesh).size = size
	(mesh.material_override as ShaderMaterial).set_shader_parameter("albedo", color)
