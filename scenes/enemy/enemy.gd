extends CharacterBody2D
const TextureLoader = preload("res://scenes/texture_loader.gd")

signal enemy_died

@export var speed: float = 100.0
@export var max_health: float = 30.0
@export var damage: float = 10.0
@export var attack_cooldown: float = 0.95

var gravity: float = 900.0
var health: float = 30.0
var is_dead: bool = false
var attack_timer: float = 0.0

@onready var body: Node2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea

var current_anim: String = ""
var base_scale_x: float = 1.54
var base_scale_y: float = 1.69
var base_pos_x: float = -2.0

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	
	if body:
		base_scale_x = abs(body.scale.x)
		base_scale_y = abs(body.scale.y)
		base_pos_x = body.position.x
		if body is AnimatedSprite2D:
			body.connect("animation_finished", Callable(self, "_on_animation_finished"))
		
	play_anim("idle")
	
	# Эффект плавного выхода из пещеры
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

func _physics_process(delta: float) -> void:
	if is_dead:
		play_anim("death")
		return
		
	if not is_on_floor():
		velocity.y += gravity * delta

	# Сканируем цели перед нами
	var target = get_target_to_attack()
	
	if target:
		velocity.x = 0
		attack_timer -= delta
		if attack_timer <= 0:
			bite_target(target)
			attack_timer = attack_cooldown
	else:
		# Бежим к костру (центр карты)
		var campfire = get_tree().get_first_node_in_group("campfire")
		var target_x = campfire.global_position.x if campfire else 0.0
		var dist_x = target_x - global_position.x
		
		if abs(dist_x) > 20.0:
			velocity.x = sign(dist_x) * speed
			if body:
				body.scale.x = sign(dist_x) * base_scale_x
				body.scale.y = base_scale_y
			detection_area.scale.x = sign(dist_x) # Зона коллизии поворачивается в сторону движения
		else:
			# Если добежал до костра — тушит его
			velocity.x = 0
			if campfire:
				extinguish_campfire(campfire, delta)
				
	# Обновление анимаций движения
	if current_anim != "attack":
		var campfire = get_tree().get_first_node_in_group("campfire")
		var reached_fire = campfire and abs(campfire.global_position.x - global_position.x) <= 20.0
		if reached_fire:
			play_anim("attack") # Волк копает костер (анимация атаки)
		elif abs(velocity.x) > 5.0:
			play_anim("walk")
		else:
			play_anim("idle")
			
	move_and_slide()

func play_anim(anim_name: String) -> void:
	if current_anim == anim_name:
		return
	current_anim = anim_name
	
	if body and body is AnimatedSprite2D:
		if anim_name == "walk":
			if body.sprite_frames.has_animation("Walk"):
				body.play("Walk")
			else:
				body.play("walk")
		elif anim_name == "idle":
			if body.sprite_frames.has_animation("Idle"):
				body.play("Idle")
			else:
				body.play("idle")
		elif anim_name == "attack":
			if body.sprite_frames.has_animation("Attack"):
				body.play("Attack")
			elif body.sprite_frames.has_animation("attack"):
				body.play("attack")
			else:
				if body.sprite_frames.has_animation("Idle"):
					body.play("Idle")

func _on_animation_finished() -> void:
	if current_anim == "attack":
		play_anim("idle")

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
		elif ob.is_in_group("spearman") or ob.is_in_group("lumberjack") or ob.is_in_group("citizen") or ob.is_in_group("player"):
			var dist = global_position.distance_to(ob.global_position)
			if dist < min_dist_unit:
				min_dist_unit = dist
				closest_unit = ob
				
	# Стена имеет более высокий приоритет преграды, чем ИИ юнитов
	if closest_wall:
		return closest_wall
	return closest_unit

func bite_target(target: Node2D) -> void:
	if is_instance_valid(target):
		play_anim("attack")
		if target.has_method("take_damage"):
			target.take_damage(damage)
			
		# Анимация выпада при укусе
		var tween = create_tween()
		var dir = sign(body.scale.x)
		tween.tween_property(body, "position:x", base_pos_x + 8.0 * dir, 0.07)
		tween.tween_property(body, "position:x", base_pos_x, 0.12)
		
		# Определяем, нужно ли сбросить анимацию по таймеру
		var needs_timer_reset = true
		if body and body is AnimatedSprite2D:
			var anim_name = "Attack" if body.sprite_frames.has_animation("Attack") else ("attack" if body.sprite_frames.has_animation("attack") else "")
			if anim_name != "" and not body.sprite_frames.get_animation_loop(anim_name):
				needs_timer_reset = false
				
		if needs_timer_reset:
			tween.tween_callback(Callable(self, "_on_attack_finished"))
		
		# Если стена 3-го уровня (шипастая) — волк получает ответный урон
		if target.is_in_group("wall") and target.level == 3:
			take_damage(5.0)

func _on_attack_finished() -> void:
	if current_anim == "attack":
		play_anim("idle")

func extinguish_campfire(campfire: Node2D, delta: float) -> void:
	# Волк тушит костер, отнимая топливо
	campfire.current_fuel = max(0.0, campfire.current_fuel - 15.0 * delta)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	
	# Вспышка красного при получении урона
	var tween = create_tween()
	body.modulate = Color(1.0, 0.3, 0.3)
	tween.tween_property(body, "modulate", Color(1, 1, 1), 0.12)
	
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	emit_signal("enemy_died")
	
	# Отключаем детекторы
	detection_area.set_deferred("monitoring", false)
	
	# Анимация смерти волка: поворот на бок и затухание
	if body:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(body, "rotation", PI / 2.0 * sign(body.scale.x), 0.5)
		tween.tween_property(body, "modulate:a", 0.0, 0.8)
	
	await get_tree().create_timer(0.8).timeout
	queue_free()
