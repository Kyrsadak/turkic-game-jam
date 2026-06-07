extends CharacterBody2D
const TextureLoader = preload("res://scenes/texture_loader.gd")

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

var sprite: Sprite2D = null
var current_anim: String = ""
var anim_frame: float = 0.0
var anim_speed: float = 12.0

var anims = {
	"idle": [1, 8, true],
	"walk": [9, 16, true],
	"death": [27, 34, false], # death 2
	"attack": [43, 52, false] # attack 2
}

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("bear")
	health = max_health
	
	# Загружаем спрайт-лист и настраиваем его для медведя (увеличиваем масштаб и красим в бурый цвет)
	sprite = TextureLoader.try_apply_texture(self, "res://assets/textures/monster pack 2 free/pack 2 m1.png", Vector2(0, -24))
	if sprite:
		sprite.hframes = 10
		sprite.vframes = 9
		sprite.frame = 1
		sprite.modulate = Color(0.65, 0.45, 0.4) # Бурый медведь
		
	body.scale = Vector2(1.8, 1.8)
	play_anim("idle")
	
	# Эффект плавного выхода из пещеры
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

func _physics_process(delta: float) -> void:
	if is_dead:
		play_anim("death")
		update_sprite_animation(delta)
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
			body.scale.x = sign(dist_x) * 1.8
			body.scale.y = 1.8
			detection_area.scale.x = sign(dist_x) # Зона коллизии поворачивается в сторону движения
		else:
			velocity.x = 0
			if campfire:
				extinguish_campfire(campfire, delta)
				
	# Обновление анимаций движения
	if current_anim != "attack":
		var campfire = get_tree().get_first_node_in_group("campfire")
		var reached_fire = campfire and abs(campfire.global_position.x - global_position.x) <= 20.0
		if reached_fire:
			play_anim("attack") # Медведь бьет лапой костер (анимация атаки)
		elif abs(velocity.x) > 5.0:
			play_anim("walk")
		else:
			play_anim("idle")
			
	update_sprite_animation(delta)
	move_and_slide()

func play_anim(anim_name: String) -> void:
	if current_anim == anim_name:
		return
	current_anim = anim_name
	var anim_info = anims.get(anim_name)
	if anim_info:
		anim_frame = anim_info[0]
		if sprite:
			sprite.frame = int(anim_frame)

func update_sprite_animation(delta: float) -> void:
	if not sprite:
		return
	var anim_info = anims.get(current_anim)
	if not anim_info:
		return
		
	var start_f = anim_info[0]
	var end_f = anim_info[1]
	var loops = anim_info[2]
	
	anim_frame += delta * anim_speed
	if anim_frame > end_f + 0.99:
		if loops:
			anim_frame = start_f
		else:
			anim_frame = end_f
			if current_anim == "attack":
				play_anim("idle")
				
	sprite.frame = clamp(int(anim_frame), start_f, end_f)

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
		elif ob.is_in_group("spearman") or ob.is_in_group("lumberjack") or ob.is_in_group("citizen"):
			var dist = global_position.distance_to(ob.global_position)
			if dist < min_dist_unit:
				min_dist_unit = dist
				closest_unit = ob
				
	if closest_wall:
		return closest_wall
	return closest_unit

func bite_target(target: Node2D) -> void:
	if is_instance_valid(target):
		play_anim("attack")
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

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	
	var tween = create_tween()
	body.modulate = Color(1.0, 0.3, 0.3)
	# Медведь должен возвращать свою бурую окраску, а не чисто белый цвет
	tween.tween_property(body, "modulate", Color(1, 1, 1), 0.12)
	
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	emit_signal("enemy_died")
	detection_area.set_deferred("monitoring", false)
	
	play_anim("death")
	
	var tween = create_tween()
	tween.tween_property(body, "modulate:a", 0.0, 0.8)
	
	await get_tree().create_timer(0.8).timeout
	queue_free()

