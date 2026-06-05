extends CharacterBody2D

signal enemy_died

@export var speed: float = 45.0
@export var max_health: float = 80.0
@export var damage: float = 24.0
@export var attack_cooldown: float = 1.6

var gravity: float = 900.0
var health: float = 80.0
var is_dead: bool = false
var attack_timer: float = 0.0

@onready var body: Node2D = $Body
@onready var detection_area: Area2D = $DetectionArea

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("bear")
	health = max_health

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	if not is_on_floor():
		velocity.y += gravity * delta

	var target = get_target_to_attack()
	
	if target:
		velocity.x = 0
		attack_timer -= delta
		if attack_timer <= 0:
			bite_target(target)
			attack_timer = attack_cooldown
	else:
		var campfire = get_tree().get_first_node_in_group("campfire")
		var target_x = campfire.global_position.x if campfire else 0.0
		var dist_x = target_x - global_position.x
		
		if abs(dist_x) > 20.0:
			velocity.x = sign(dist_x) * speed
			body.scale.x = sign(dist_x)
			
			# Анимация бега медведя (тяжелые шаги)
			var pulse = sin(Time.get_ticks_msec() * 0.012) * 0.06
			body.scale.y = 1.0 + pulse
			body.scale.x = sign(dist_x) * (1.0 - pulse)
		else:
			velocity.x = 0
			if campfire:
				extinguish_campfire(campfire, delta)
				
	move_and_slide()

func get_target_to_attack() -> Node2D:
	var overlapping = detection_area.get_overlapping_bodies()
	
	var closest_wall: Node2D = null
	var closest_unit: Node2D = null
	var min_dist_wall: float = 9999.0
	var min_dist_unit: float = 9999.0
	
	for ob in overlapping:
		if ob.is_in_group("wall") and ob.level > 0:
			var dist = global_position.distance_to(ob.global_position)
			if dist < min_dist_wall:
				min_dist_wall = dist
				closest_wall = ob
		elif ob.is_in_group("spearman") or ob.is_in_group("lumberjack") or ob.is_in_group("player") or ob.is_in_group("citizen"):
			var dist = global_position.distance_to(ob.global_position)
			if dist < min_dist_unit:
				min_dist_unit = dist
				closest_unit = ob
				
	if closest_wall:
		return closest_wall
	return closest_unit

func bite_target(target: Node2D) -> void:
	if is_instance_valid(target):
		if target.has_method("take_damage"):
			target.take_damage(damage)
			
		var tween = create_tween()
		var dir = sign(body.scale.x)
		tween.tween_property(body, "position:x", 12.0 * dir, 0.1)
		tween.tween_property(body, "position:x", 0.0, 0.15)
		
		if target.is_in_group("wall") and target.level == 3:
			take_damage(8.0)

func extinguish_campfire(campfire: Node2D, delta: float) -> void:
	campfire.current_fuel = max(0.0, campfire.current_fuel - 25.0 * delta)
	var pulse = sin(Time.get_ticks_msec() * 0.02) * 0.05
	body.scale.y = 1.0 + pulse
	body.scale.x = sign(body.scale.x) * (1.0 - pulse)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	
	var tween = create_tween()
	body.modulate = Color(1.0, 0.3, 0.3)
	tween.tween_property(body, "modulate", Color(1, 1, 1), 0.12)
	
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	emit_signal("enemy_died")
	detection_area.set_deferred("monitoring", false)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(body, "rotation", PI / 2.0 * sign(body.scale.x), 0.55)
	tween.tween_property(body, "modulate:a", 0.0, 0.6)
	
	await get_tree().create_timer(0.6).timeout
	queue_free()
