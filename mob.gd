class_name Mob
extends CharacterBody3D
## Гигантский моб идёт к игроку ТОЛЬКО пока игрок его видит при включённом фонаре.
## Отвернулся или погасил свет - моб замирает (глаза тускнеют). Вплотную всё равно бьёт.
## Параметры меняются в Инспекторе у каждого моба отдельно.

@export var speed := 4.0
@export var gravity := 25.0
@export var attack_range := 2.4
@export var attack_cooldown := 1.2
@export var sight_range := 70.0
@export var hp := 6

const BODY_COLOR := Color(0.25, 0.15, 0.35)

var player: Player
var attack_timer := 0.0
var body_mat: ShaderMaterial
var eye_mat: ShaderMaterial

@onready var visual: Node3D = $Visual
@onready var body: MeshInstance3D = $Visual/Body
@onready var eye_l: MeshInstance3D = $Visual/EyeL
@onready var eye_r: MeshInstance3D = $Visual/EyeR


func _ready() -> void:
	add_to_group("mob")
	# Свои материалы для каждого моба, иначе они бы мигали все вместе
	body_mat = (body.material_override as ShaderMaterial).duplicate()
	body.material_override = body_mat
	eye_mat = (eye_l.material_override as ShaderMaterial).duplicate()
	eye_l.material_override = eye_mat
	eye_r.material_override = eye_mat


func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null:
			return

	attack_timer = max(0.0, attack_timer - delta)

	var to_p := player.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	var dir := to_p.normalized() if dist > 0.01 else Vector3.ZERO

	var active := player.lantern_on and dist < sight_range \
		and player.can_see(global_position + Vector3(0, 2.25, 0))
	eye_mat.set_shader_parameter("emission_energy", 1.5 if active else 0.0)

	if active and dist > attack_range * 0.8:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 4.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if dist < attack_range and attack_timer == 0.0:
		attack_timer = attack_cooldown
		player.take_damage(1)


func take_hit(from: Player, dmg: int = 1) -> void:
	hp -= dmg
	var away := global_position - from.global_position
	away.y = 0.0
	velocity += away.normalized() * 3.0

	body_mat.set_shader_parameter("albedo", Color(1, 1, 1))
	get_tree().create_timer(0.1).timeout.connect(
		func(): body_mat.set_shader_parameter("albedo", BODY_COLOR))

	if hp <= 0:
		queue_free()
