extends CharacterBody2D
const TextureLoader = preload("res://scenes/texture_loader.gd")

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
@onready var footstep_audio: AudioStreamPlayer2D = $FootstepAudio

static var spearman_count: int = 0
var footstep_timer: float = 0.0
var footstep_base_volume_db: float = -14.0
var footstep_fadeout_speed_db: float = 38.0

func _ready() -> void:
	scale = Vector2(1.75, 1.75)
	add_to_group("spearman")
	footstep_audio.volume_db = footstep_base_volume_db
	body.position.y = 6.0
	
	# Чередуем фланги: нечётные → правый (+1), чётные → левый (-1)
	spearman_count += 1
	flank = 1.0 if (spearman_count % 2 == 1) else -1.0
	
	choose_post_position()
	setup_animated_sprite()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	# Поиск врагов
	if not is_instance_valid(target_enemy) or target_enemy.is_dead:
		target_enemy = find_closest_enemy(350.0)
	else:
		if global_position.distance_to(target_enemy.global_position) > 400.0:
			target_enemy = find_closest_enemy(350.0)

	match current_state:
		State.WALKING_TO_POST:
			if target_enemy:
				current_state = State.ATTACKING
				attack_timer = 0.1
			else:
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
			if not is_instance_valid(target_enemy) or target_enemy.is_dead:
				current_state = State.DEFENDING
			else:
				var enemy_pos_x = target_enemy.global_position.x
				
				# Проверяем наличие стены на нашем фланге
				var campfire = get_tree().get_first_node_in_group("campfire")
				var campfire_x = campfire.global_position.x if campfire else 0.0
				var walls = get_tree().get_nodes_in_group("wall")
				var flank_wall: Node2D = null
				for wall in walls:
					if is_instance_valid(wall):
						var wall_is_right = wall.global_position.x > campfire_x
						if (flank == 1.0 and wall_is_right) or (flank == -1.0 and not wall_is_right):
							flank_wall = wall
							break
				
				# Если есть стена, мы не должны заходить за неё
				var target_x = enemy_pos_x
				if flank_wall:
					if flank == 1.0:
						target_x = min(target_x, flank_wall.global_position.x - 16.0)
					else:
						target_x = max(target_x, flank_wall.global_position.x + 16.0)
						
				var dist_x = target_x - global_position.x
				
				# Если мы еще не подошли на дистанцию удара к нашей цели (target_x)
				if abs(dist_x) > 20.0:
					velocity.x = sign(dist_x) * speed
					body.scale.x = sign(dist_x)
					animate_walk()
				else:
					velocity.x = 0
					# Поворачиваемся лицом к фактическому врагу
					var actual_dist_x = target_enemy.global_position.x - global_position.x
					if actual_dist_x != 0:
						body.scale.x = sign(actual_dist_x)
					
					attack_timer -= delta
					if attack_timer <= 0:
						stab_enemy()
						attack_timer = attack_cooldown

	move_and_slide()
	update_footsteps(delta)
	update_animations()

func choose_post_position() -> void:
	var walls = get_tree().get_nodes_in_group("wall")
	var flank_wall: Node2D = null
	
	var campfire = get_tree().get_first_node_in_group("campfire")
	var campfire_x = campfire.global_position.x if campfire else 0.0
	
	for wall in walls:
		if is_instance_valid(wall):
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
		if global_position.distance_to(target_enemy.global_position) <= 110.0:
			if target_enemy.has_method("take_damage"):
				target_enemy.take_damage(damage)
				
			var anim_sprite = body.get_node_or_null("AnimatedSprite2D")
			if anim_sprite and anim_sprite.sprite_frames.has_animation("Attack"):
				anim_sprite.play("Attack")
			else:
				# Анимация выпада копья (для векторной графики)
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

func update_footsteps(delta: float) -> void:
	var is_walking = is_on_floor() and abs(velocity.x) > 5.0
	if is_walking:
		footstep_audio.volume_db = move_toward(footstep_audio.volume_db, footstep_base_volume_db, footstep_fadeout_speed_db * delta)
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_audio.stop()
			footstep_audio.volume_db = footstep_base_volume_db
			footstep_audio.pitch_scale = randf_range(0.90, 0.96)
			footstep_audio.play()
			footstep_timer = 0.28
	else:
		footstep_timer = 0.0
		if footstep_audio.playing:
			footstep_audio.volume_db = move_toward(footstep_audio.volume_db, -40.0, footstep_fadeout_speed_db * delta)
			if footstep_audio.volume_db <= -39.0:
				footstep_audio.stop()
				footstep_audio.volume_db = footstep_base_volume_db

func take_damage(amount: float) -> void:
	# Копейщик превращается обратно в бродягу
	var vagrant_scene = load("res://scenes/vagrant/vagrant.tscn")
	if vagrant_scene:
		var v = vagrant_scene.instantiate()
		get_parent().add_child(v)
		v.global_position = global_position
		v.is_hired = false
		
		# Отскок назад для нового бродяги
		var knock_dir = -sign(body.scale.x) if body.scale.x != 0 else -1.0
		v.velocity = Vector2(knock_dir * 120.0, -100.0)
		
		var v_body = v.get_node_or_null("Body")
		if v_body:
			v_body.modulate = Color(1.0, 0.3, 0.3)
			var tween = create_tween()
			tween.tween_property(v_body, "modulate", Color(1, 1, 1), 0.15)
		
	queue_free()

func setup_animated_sprite() -> void:
	if not FileAccess.file_exists("res://assets/textures/characters/spearman/Idle.png"):
		# Резервный вариант: если текстуры не найдены, используем оригинальный векторный вид
		return
		
	var sf = SpriteFrames.new()
	
	# 1. Анимация Idle (покой)
	sf.add_animation("Idle")
	sf.set_animation_speed("Idle", 6.0)
	sf.set_animation_loop("Idle", true)
	var idle_tex = load("res://assets/textures/characters/spearman/Idle.png")
	if idle_tex:
		for i in range(4):
			var atlas = AtlasTexture.new()
			atlas.atlas = idle_tex
			atlas.region = Rect2(i * 128, 0, 128, 128)
			sf.add_frame("Idle", atlas)
			
	# 2. Анимация Attack (удар)
	sf.add_animation("Attack")
	sf.set_animation_speed("Attack", 6.5)
	sf.set_animation_loop("Attack", false)
	var attack_tex = load("res://assets/textures/characters/spearman/Attack.png")
	if attack_tex:
		for i in range(5):
			var atlas = AtlasTexture.new()
			atlas.atlas = attack_tex
			atlas.region = Rect2(i * 128, 0, 128, 128)
			sf.add_frame("Attack", atlas)
			
	var anim_sprite = AnimatedSprite2D.new()
	anim_sprite.name = "AnimatedSprite2D"
	anim_sprite.sprite_frames = sf
	anim_sprite.position = Vector2(4, -42.65)
	anim_sprite.scale = Vector2(0.646, 0.646)
	anim_sprite.autoplay = "Idle"
	
	body.add_child(anim_sprite)
	
	# Скрываем все оригинальные векторные элементы внутри Body (Legs, Armor, Cape, Head, Helmet, Spear)
	for child in body.get_children():
		if child != anim_sprite:
			if child is CanvasItem:
				child.visible = false

func update_animations() -> void:
	var anim_sprite = body.get_node_or_null("AnimatedSprite2D")
	if not anim_sprite:
		return
		
	if anim_sprite.animation == "Attack" and anim_sprite.is_playing():
		return
		
	anim_sprite.play("Idle")


