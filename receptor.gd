@tool
class_name Receptor
extends StaticBody3D
## Кристалл-мишень. Зажигается лазером, если сила выстрела не меньше needed_power.
## Цвет подсказывает нужную силу: бирюзовый = слабый выстрел, розовый = почти полный заряд.

const PS1_SHADER := preload("res://ps1_object.gdshader")

## Кристаллы и плиты с одним каналом открывают дверь с тем же каналом
@export var channel := "A"
@export_range(0.0, 1.0) var needed_power := 0.3:
	set = set_needed_power
## Сколько секунд кристалл горит после попадания (0 = горит навсегда)
@export var hold_time := 0.0

var active := false
var _timer := 0.0
var col: CollisionShape3D
var mesh: MeshInstance3D
var light: OmniLight3D
var mat: ShaderMaterial


func _ready() -> void:
	if col == null:
		col = CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 1.4
		col.shape = sh
		add_child(col)

		mesh = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radial_segments = 6
		sm.rings = 3
		sm.radius = 1.2
		sm.height = 3.0
		mesh.mesh = sm
		mat = ShaderMaterial.new()
		mat.shader = PS1_SHADER
		mesh.material_override = mat
		add_child(mesh)

		light = OmniLight3D.new()
		light.omni_range = 14.0
		light.light_energy = 0.0
		add_child(light)
	_apply()
	if not Engine.is_editor_hint():
		add_to_group("ch_" + channel)


func set_needed_power(v: float) -> void:
	needed_power = v
	_apply()


func _base_color() -> Color:
	return Color(0.4, 0.85, 0.75).lerp(Color(0.95, 0.4, 0.6), needed_power)


func _apply() -> void:
	if mat == null:
		return
	var c := _base_color()
	mat.set_shader_parameter("albedo", c * (1.0 if active else 0.55))
	mat.set_shader_parameter("emission_color", c)
	mat.set_shader_parameter("emission_energy", 3.5 if active else 0.0)
	light.light_color = c
	light.light_energy = 2.5 if active else 0.0


## Вызывается игроком, когда лазер попал в кристалл
func on_laser(power: float) -> void:
	if power < needed_power:
		return
	active = true
	_timer = hold_time
	_apply()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or mesh == null:
		return
	mesh.rotation.y += delta * 0.6
	if active and hold_time > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			active = false
			_apply()
