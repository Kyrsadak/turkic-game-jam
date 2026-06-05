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

@onready var body: Node2D = $Body
@onready var detection_area: Area2D = $DetectionArea

func _ready() -> void:
	scale = Vector2(2.5, 2.5)
	add_to_group("enemy")
	health = max_health
	TextureLoader.try_apply_texture(self, "res://assets/textures/wolf.png", Vector2(0, -9))

func _physics_process(delta: float) -> void:
	if is_dead:
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
			body.scale.x = sign(dist_x)
			
			# Анимация бега волка (сплющивание по фазам)
			var pulse = sin(Time.get_ticks_msec() * 0.022) * 0.08
			body.scale.y = 1.0 + pulse
			body.scale.x = sign(dist_x) * (1.0 - pulse)
		else:
			# Если добежал до костра — тушит его
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
				
	# Стена имеет более высокий приоритет преграды, чем ИИ юнитов
	if closest_wall:
		return closest_wall
	return closest_unit

func bite_target(target: Node2D) -> void:
	if is_instance_valid(target):
		if target.has_method("take_damage"):
			target.take_damage(damage)
			
		# Анимация выпада при укусе
		var tween = create_tween()
		var dir = sign(body.scale.x)
		tween.tween_property(body, "position:x", 8.0 * dir, 0.07)
		tween.tween_property(body, "position:x", 0.0, 0.12)
		
		# Если стена 3-го уровня (шипастая) — волк получает ответный урон
		if target.is_in_group("wall") and target.level == 3:
			take_damage(5.0)

func extinguish_campfire(campfire: Node2D, delta: float) -> void:
	# Волк тушит костер, отнимая топливо
	campfire.current_fuel = max(0.0, campfire.current_fuel - 15.0 * delta)
	
	# Визуальное рытье когтями
	var pulse = sin(Time.get_ticks_msec() * 0.03) * 0.06
	body.scale.y = 1.0 + pulse
	body.scale.x = sign(body.scale.x) * (1.0 - pulse)

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
	
	# Анимация смерти волка
	var tween = create_tween()
	tween.set_parallel(true)
	# Опрокидывание на бок
	tween.tween_property(body, "rotation", PI / 2.0 * sign(body.scale.x), 0.45)
	tween.tween_property(body, "modulate:a", 0.0, 0.5)
	
	await get_tree().create_timer(0.5).timeout
	queue_free()
