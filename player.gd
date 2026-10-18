class_name Player
extends CharacterBody3D
## Волчонок. WASD - ходьба, мышь - камера, F - фонарь,
## ЛКМ (зажать и держать) - заряд лазера из глаз, отпустить - выстрел. Esc - отпустить мышь.
## Все числа ниже можно менять прямо в Инспекторе у узла Player.

signal lantern_toggled(on: bool)
signal hurt(hp: int)

@export_group("Движение")
@export var speed := 4.5
@export var accel := 35.0
@export var friction := 45.0
@export var gravity := 25.0
@export_group("Камера")
@export var mouse_sens := 0.003
## Сглаживание поворота камеры (больше = резче, 0 = без сглаживания)
@export var look_smooth := 30.0
## Скорость, с которой камера догоняет игрока
@export var cam_follow := 12.0
@export var cam_distance := 2.6
@export var cam_height := 0.95
## Смещение камеры вправо от плеча
@export var cam_shoulder := 0.3
@export var pitch_min := -1.2
@export var pitch_max := 0.45
@export_group("Лазер")
## Сколько секунд держать кнопку для полного заряда
@export var charge_max := 1.5
## Минимальная сила быстрого выстрела (без зарядки)
@export var min_power := 0.1
@export var shot_cooldown := 0.3
@export var shot_range := 120.0
## Урон мобам при полном заряде (слабый выстрел бьёт на 1)
@export var max_damage := 4
@export var max_hp := 5

const FUR_COLOR := Color(0.7, 0.62, 0.6)
const LASER_COLOR := Color(0.7, 1.0, 0.75)

var yaw := 0.0
var pitch := -0.25
var target_yaw := 0.0
var target_pitch := -0.25
var lantern_on := true
var hp := 5
var shot_timer := 0.0
var face_timer := 0.0
var charging := false
var charge_time := 0.0
var charge_ratio := 0.0
var spawn_pos := Vector3.ZERO
var fur_mat: ShaderMaterial
var eye_mat: ShaderMaterial
var lantern_base := Vector3.ZERO
var walk_time := 0.0
var tail_time := 0.0

@onready var model: Node3D = $Model
@onready var body: MeshInstance3D = $Model/Body
@onready var lantern: Lantern = $Model/Lantern
@onready var leg_fl: Node3D = $Model/LegFL
@onready var leg_fr: Node3D = $Model/LegFR
@onready var leg_bl: Node3D = $Model/LegBL
@onready var leg_br: Node3D = $Model/LegBR
@onready var tail: Node3D = $Model/Tail
@onready var eye_l: MeshInstance3D = $Model/EyeL
@onready var eye_r: MeshInstance3D = $Model/EyeR
@onready var eye_light: OmniLight3D = $Model/EyeLight
@onready var pivot: Node3D = $CameraPivot
@onready var arm: SpringArm3D = $CameraPivot/SpringArm
@onready var cam: Camera3D = $CameraPivot/SpringArm/Camera


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	spawn_pos = global_position
	lantern_base = lantern.position
	target_yaw = yaw
	target_pitch = pitch

	arm.add_excluded_object(get_rid())
	arm.spring_length = cam_distance

	# Свои материалы: шерсть (для вспышки при ударе) и глаза (для свечения при зарядке)
	var fur_orig := body.material_override
	fur_mat = (fur_orig as ShaderMaterial).duplicate()
	for m in model.find_children("*", "MeshInstance3D", true, false):
		if m.material_override == fur_orig:
			m.material_override = fur_mat
	eye_mat = (eye_l.material_override as ShaderMaterial).duplicate()
	eye_l.material_override = eye_mat
	eye_r.material_override = eye_mat

	# Камера двигается сама и плавно догоняет игрока, а не жёстко прикреплена к телу
	pivot.top_level = true
	_snap_camera()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_look()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		target_yaw -= event.relative.x * mouse_sens
		target_pitch = clamp(target_pitch - event.relative.y * mouse_sens, pitch_min, pitch_max)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F:
			lantern_on = not lantern_on
			lantern.set_on(lantern_on)
			lantern_toggled.emit(lantern_on)
		elif event.physical_keycode == KEY_ESCAPE:
			_cancel_charge()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				_start_charge()
		else:
			_release_charge()
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _start_charge() -> void:
	if shot_timer > 0.0:
		return
	charging = true
	charge_time = 0.0
	charge_ratio = 0.0


func _cancel_charge() -> void:
	charging = false
	charge_time = 0.0
	charge_ratio = 0.0


func _release_charge() -> void:
	if not charging:
		return
	var power: float = clamp(charge_ratio, min_power, 1.0)
	_cancel_charge()
	_fire(power)


func _camera_target() -> Vector3:
	var right := Vector3.RIGHT.rotated(Vector3.UP, yaw)
	return global_position + Vector3(0, cam_height, 0) + right * cam_shoulder


func _snap_camera() -> void:
	pivot.global_position = _camera_target()


func _apply_look() -> void:
	pivot.rotation = Vector3(pitch, yaw, 0.0)


func _process(delta: float) -> void:
	# Сглаженный поворот камеры
	var k := 1.0 - exp(-look_smooth * delta) if look_smooth > 0.0 else 1.0
	yaw = lerp_angle(yaw, target_yaw, k)
	pitch = lerp(pitch, target_pitch, k)
	_apply_look()

	# Плавное следование за игроком (экспоненциальное сглаживание, не зависит от FPS)
	pivot.global_position = pivot.global_position.lerp(
		_camera_target(), 1.0 - exp(-cam_follow * delta))

	# Анимация волчонка: лапы, корпус, хвост
	var moving: float = Vector2(velocity.x, velocity.z).length() / speed
	walk_time += delta * (3.0 + 11.0 * moving)
	tail_time += delta * (3.0 + 6.0 * moving)
	var swing: float = sin(walk_time) * 0.75 * moving
	leg_fl.rotation.x = swing
	leg_br.rotation.x = swing
	leg_fr.rotation.x = -swing
	leg_bl.rotation.x = -swing
	body.position.y = 0.38 + abs(sin(walk_time)) * 0.03 * moving
	tail.rotation.y = sin(tail_time) * (0.25 + 0.4 * moving)

	# Фонарик в зубах покачивается
	lantern.position = lantern_base + Vector3(0, sin(walk_time * 2.0) * 0.015 * moving, 0)
	lantern.rotation = Vector3(sin(walk_time) * 0.15 * moving, 0, sin(walk_time * 0.5) * 0.2 * moving)

	# Заряд лазера: глаза разгораются, волчонок дрожит от напряжения
	eye_mat.set_shader_parameter("emission_energy", 1.0 + 8.0 * charge_ratio)
	eye_light.visible = charge_ratio > 0.01
	eye_light.light_energy = charge_ratio * 3.0
	model.rotation.z = sin(Time.get_ticks_msec() * 0.05) * 0.03 * charge_ratio


func _physics_process(delta: float) -> void:
	shot_timer = max(0.0, shot_timer - delta)
	face_timer = max(0.0, face_timer - delta)

	if charging:
		charge_time = min(charge_time + delta, charge_max)
		charge_ratio = charge_time / charge_max
		face_timer = 0.2  # во время зарядки смотрим туда же, куда камера

	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.y -= 1
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1
	if Input.is_physical_key_pressed(KEY_S): input.y += 1
	if Input.is_physical_key_pressed(KEY_D): input.x += 1
	input = input.normalized()

	# Пока копим выстрел, двигаемся медленнее
	var move_speed := speed * (1.0 - 0.5 * charge_ratio)
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
	var target := dir * move_speed
	var rate := accel if dir.length() > 0.1 else friction
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if face_timer > 0.0:
		model.rotation.y = lerp_angle(model.rotation.y, yaw, 15.0 * delta)
	elif dir.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)


func _fire(power: float) -> void:
	shot_timer = shot_cooldown
	face_timer = 0.6

	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var to := from + dir * shot_range

	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	q.collision_mask = 3  # мир (1) + мобы (2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if not hit.is_empty():
		end = hit.position
		var target: Object = hit.collider
		if target is Mob:
			target.take_hit(self, 1 + int(round(power * (max_damage - 1))))
		elif target.has_method("on_laser"):
			target.on_laser(power)

	_spawn_laser_fx(end, dir, power)


func _beam(from: Vector3, to: Vector3, width: float, life: float) -> void:
	var length := from.distance_to(to)
	if length < 0.2:
		return
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width, length)
	beam.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = LASER_COLOR
	beam.material_override = m
	get_parent().add_child(beam)
	beam.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	get_tree().create_timer(life).timeout.connect(beam.queue_free)


func _spawn_laser_fx(end: Vector3, dir: Vector3, power: float) -> void:
	var width := 0.03 + 0.12 * power
	var life := 0.1 + 0.25 * power
	_beam(eye_l.global_position, end, width, life)
	_beam(eye_r.global_position, end, width, life)

	# Вспышка в точке попадания, сильнее при большем заряде
	var flash := OmniLight3D.new()
	flash.light_color = LASER_COLOR
	flash.light_energy = 4.0 + 12.0 * power
	flash.omni_range = 8.0 + 10.0 * power
	get_parent().add_child(flash)
	flash.global_position = end - dir * 0.5
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.2 + 0.3 * power)
	tw.tween_callback(flash.queue_free)


func take_damage(amount: int) -> void:
	hp -= amount
	fur_mat.set_shader_parameter("albedo", Color(1, 0.2, 0.2))
	get_tree().create_timer(0.15).timeout.connect(
		func(): fur_mat.set_shader_parameter("albedo", FUR_COLOR))
	if hp <= 0:
		# Мягкое "поражение": возвращаемся на старт с полным здоровьем
		hp = max_hp
		global_position = spawn_pos
		velocity = Vector3.ZERO
		_cancel_charge()
		_snap_camera()
	hurt.emit(hp)


## Видит ли игрок эту точку (в кадре и без стены на пути).
func can_see(world_pos: Vector3) -> bool:
	if cam.is_position_behind(world_pos):
		return false
	if not cam.is_position_in_frustum(world_pos):
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, world_pos)
	q.exclude = [get_rid()]
	q.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.position.distance_to(world_pos) < 1.5
