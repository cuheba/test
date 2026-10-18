@tool
class_name PressurePlate
extends Area3D
## Нажимная плита. По умолчанию её нажимают только мобы (requires_mob), игрок слишком лёгкий.
## При latch = включено плита остаётся нажатой навсегда после первого касания.

const PS1_SHADER := preload("res://ps1_object.gdshader")

@export var channel := "B"
@export var size := Vector3(10, 0.4, 10):
	set = set_size
@export var requires_mob := true
@export var latch := true

var active := false
var col: CollisionShape3D
var mesh: MeshInstance3D
var mat: ShaderMaterial


func _ready() -> void:
	if col == null:
		col = CollisionShape3D.new()
		col.shape = BoxShape3D.new()
		add_child(col)
		mesh = MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mat = ShaderMaterial.new()
		mat.shader = PS1_SHADER
		mesh.material_override = mat
		add_child(mesh)
	collision_layer = 0
	collision_mask = 3
	_apply()
	if not Engine.is_editor_hint():
		add_to_group("ch_" + channel)


func set_size(v: Vector3) -> void:
	size = v
	_apply()


func _apply() -> void:
	if col == null:
		return
	(col.shape as BoxShape3D).size = size
	(mesh.mesh as BoxMesh).size = size
	mat.set_shader_parameter("albedo", Color(0.9, 0.7, 0.35) if active else Color(0.5, 0.33, 0.3))
	mat.set_shader_parameter("emission_color", Color(1.0, 0.7, 0.3))
	mat.set_shader_parameter("emission_energy", 1.5 if active else 0.0)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or (active and latch):
		return
	var pressed := false
	for b in get_overlapping_bodies():
		if b is Mob or (not requires_mob and b is Player):
			pressed = true
			break
	if pressed != active:
		active = pressed
		_apply()
