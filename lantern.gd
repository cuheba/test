class_name Lantern
extends Node3D
## Фонарь с живым пламенем. Свет идёт от самого фонаря во все стороны.
## Мерцание задаётся строкой-паттерном в стиле Quake: 'a' = темно, 'm' = норма, 'q' = ярче.
## Все числа можно менять в Инспекторе.

@export var base_energy := 3.5
@export var fill_energy := 0.6
## 0 = ровное свечение, 1 = полное мерцание по паттерну
@export_range(0.0, 1.0) var flicker_amount := 0.35
## Сколько символов паттерна проходит за секунду
@export var flicker_speed := 10.0
@export var fade_speed := 8.0
@export var light_range := 14.0
@export var pattern := "mmnmmommommnonmmonqnmmo"

var is_on := true
var level := 1.0
var _time := 0.0
var _base_pos := Vector3.ZERO

@onready var light: OmniLight3D = $Light
@onready var fill: OmniLight3D = $Fill
@onready var flame: MeshInstance3D = $Flame


func _ready() -> void:
	light.omni_range = light_range
	fill.omni_range = light_range * 1.6
	_base_pos = light.position
	_time = randf() * 10.0


func set_on(on: bool) -> void:
	is_on = on


func _style(t: float) -> float:
	var n := pattern.length()
	var i := int(floor(t)) % n
	var j := (i + 1) % n
	var a := float(pattern.unicode_at(i) - 97) / 12.0
	var b := float(pattern.unicode_at(j) - 97) / 12.0
	return lerp(a, b, t - floor(t))


func _process(delta: float) -> void:
	# Плавное зажигание и затухание
	level = move_toward(level, 1.0 if is_on else 0.0, fade_speed * delta)

	_time += delta * flicker_speed
	var s: float = lerpf(1.0, _style(_time), flicker_amount)

	light.light_energy = base_energy * level * s
	fill.light_energy = fill_energy * level * s
	# Источник чуть "дышит", поэтому тени живые
	light.position = _base_pos + Vector3(sin(_time * 1.7), cos(_time * 1.3) * 0.5, sin(_time * 0.9 + 1.0)) * 0.015

	var lit := level > 0.01
	light.visible = lit
	fill.visible = lit
	flame.visible = lit
	flame.scale = Vector3(1.0 + (s - 1.0) * 0.3, s, 1.0 + (s - 1.0) * 0.3) * max(level, 0.01)
