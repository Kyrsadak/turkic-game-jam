extends Node2D

var target: Node2D = null
var start_pos: Vector2
var last_target_pos: Vector2
var speed: float = 350.0
var arc_height: float = 60.0

var t: float = 0.0
var duration: float = 1.0
var damage: float = 10.0

func launch(p_start: Vector2, p_target: Node2D) -> void:
	start_pos = p_start
	target = p_target
	global_position = start_pos
	
	if is_instance_valid(target):
		last_target_pos = target.global_position + Vector2(0, -10) # Aim at body center
	else:
		last_target_pos = start_pos + Vector2(100, 0)
		
	var distance = start_pos.distance_to(last_target_pos)
	duration = max(0.1, distance / speed)
	arc_height = clamp(distance * 0.25, 20.0, 100.0)

func _process(delta: float) -> void:
	if t >= 1.0:
		hit_target()
		return
		
	t += delta / duration
	t = min(t, 1.0)
	
	if is_instance_valid(target) and not target.is_dead:
		last_target_pos = target.global_position + Vector2(0, -10)
		
	var prev_pos = global_position
	
	# Interpolate along standard path + add arc offset
	var linear_pos = start_pos.lerp(last_target_pos, t)
	var arc_y = -arc_height * sin(t * PI)
	global_position = linear_pos + Vector2(0, arc_y)
	
	var move_dir = global_position - prev_pos
	if move_dir.length_squared() > 0.01:
		rotation = move_dir.angle()

func hit_target() -> void:
	if is_instance_valid(target) and not target.is_dead:
		if target.has_method("take_damage"):
			target.take_damage(damage)
	queue_free()
