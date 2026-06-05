extends CharacterBody2D

enum State { WALKING_TO_POST, DEFENDING, ATTACKING }

@export var speed: float = 90.0
@export var damage: float = 14.0
@export var attack_cooldown: float = 0.75

var gravity: float = 900.0
var current_state: State = State.WALKING_TO_POST
var target_enemy: Node2D = null
var attack_timer: float = 0.0
var flank: float = 1.0 # 1.0 = правый фланг, -1.0 = левый фланг
var target_post_x: float = 0.0

@onready var body: Node2D = $Body
@onready var spear: Node2D = $Body/Spear

func _ready() -> void:
	add_to_group("spearman")
	
	# Определяем фланг по положению спавна относительно костра
	var campfire = get_tree().get_first_node_in_group("campfire")
	var campfire_x = campfire.global_position.x if campfire else 0.0
	flank = 1.0 if global_position.x > campfire_x else -1.0
	
	choose_post_position()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	# Поиск врагов поблизости
	target_enemy = find_closest_enemy(90.0)

	match current_state:
		State.WALKING_TO_POST:
			choose_post_position()
			var dist_x = target_post_x - global_position.x
			if abs(dist_x) > 15.0:
				velocity.x = sign(dist_x) * speed
				body.scale.x = sign(dist_x)
				animate_walk()
			else:
				velocity.x = 0
				current_state = State.DEFENDING
				
		State.DEFENDING:
			velocity.x = 0
			body.scale.x = flank # Смотрим наружу базы
			
			if target_enemy:
				current_state = State.ATTACKING
				attack_timer = 0.1
			else:
				choose_post_position()
				if abs(target_post_x - global_position.x) > 20.0:
					current_state = State.WALKING_TO_POST

		State.ATTACKING:
			if not is_instance_valid(target_enemy) or global_position.distance_to(target_enemy.global_position) > 110.0:
				current_state = State.DEFENDING
			else:
				# Поворачиваемся к врагу
				var dist_x = target_enemy.global_position.x - global_position.x
				if dist_x != 0:
					body.scale.x = sign(dist_x)
				
				velocity.x = 0
				
				attack_timer -= delta
				if attack_timer <= 0:
					stab_enemy()
					attack_timer = attack_cooldown

	move_and_slide()

func choose_post_position() -> void:
	var walls = get_tree().get_nodes_in_group("wall")
	var flank_wall: Node2D = null
	
	var campfire = get_tree().get_first_node_in_group("campfire")
	var campfire_x = campfire.global_position.x if campfire else 0.0
	
	for wall in walls:
		if is_instance_valid(wall) and wall.level > 0:
			var wall_is_right = wall.global_position.x > campfire_x
			if (flank == 1.0 and wall_is_right) or (flank == -1.0 and not wall_is_right):
				flank_wall = wall
				break
				
	if flank_wall:
		# Встаем чуть позади стены, чтобы бить сквозь нее
		target_post_x = flank_wall.global_position.x - flank * 24.0
	else:
		# Пост по умолчанию, если стены нет
		target_post_x = campfire_x + flank * 240.0

func stab_enemy() -> void:
	if is_instance_valid(target_enemy):
		if target_enemy.has_method("take_damage"):
			target_enemy.take_damage(damage)
			
		# Анимация выпада копья
		var tween = create_tween()
		var orig_pos = spear.position
		var target_pos = orig_pos + Vector2(14.0, 0)
		tween.tween_property(spear, "position", target_pos, 0.07)
		tween.tween_property(spear, "position", orig_pos, 0.12)

func find_closest_enemy(max_dist: float) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest: Node2D = null
	var min_dist: float = max_dist
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest

func animate_walk() -> void:
	var pulse = sin(Time.get_ticks_msec() * 0.022) * 0.08
	body.scale.y = 1.0 + pulse
