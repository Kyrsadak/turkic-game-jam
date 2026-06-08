extends CharacterBody2D
const TextureLoader = preload("res://scenes/texture_loader.gd")

enum State { IDLE, WALKING_TO_TREE, CHOPPING, WALKING_TO_HOUSE }

@export var speed: float = 85.0
@export var chop_damage: float = 10.0
@export var chop_cooldown: float = 2.0

var gravity: float = 900.0
var wood_count: int = 0
var max_wood_carry: int = 6
var current_state: State = State.IDLE
var target_tree: Node2D = null
var home_house: Node2D = null
var chop_timer: float = 0.0

@onready var body: Node2D = $Body
@onready var axe: Node2D = $Body/Axe
@onready var wood_pile: Node2D = $WoodPile
@onready var footstep_audio: AudioStreamPlayer2D = $FootstepAudio
@onready var chop_swing_audio: AudioStreamPlayer2D = $ChopSwingAudio
@onready var chop_hit_audio: AudioStreamPlayer2D = $ChopHitAudio

var footstep_timer: float = 0.0
var footstep_base_volume_db: float = -19.4
var footstep_fadeout_speed_db: float = 38.0

func _ready() -> void:
	scale = Vector2(1.4, 1.4)
	add_to_group("lumberjack")
	update_wood_visuals()
	current_state = State.WALKING_TO_TREE
	footstep_audio.volume_db = footstep_base_volume_db
	body.position.y = 6.0
	setup_animated_sprite()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, speed * 0.3)
			body.scale.y = 1.0
			
			# Если в доме лесоруба освободилось место и есть деревья — идем рубить
			if is_instance_valid(home_house) and home_house.wood_stored < home_house.max_storage:
				current_state = State.WALKING_TO_TREE
				
		State.WALKING_TO_TREE:
			if wood_count >= max_wood_carry or (is_instance_valid(home_house) and home_house.wood_stored >= home_house.max_storage):
				current_state = State.WALKING_TO_HOUSE
			else:
				if not is_instance_valid(target_tree) or target_tree.is_felled:
					target_tree = find_closest_tree()
					
				if target_tree:
					var dist_x = target_tree.global_position.x - global_position.x
					# Останавливаемся чуть сбоку от дерева
					if abs(dist_x) > 28.0:
						velocity.x = sign(dist_x) * speed
						body.scale.x = sign(dist_x)
						animate_walk()
					else:
						velocity.x = 0
						current_state = State.CHOPPING
						chop_timer = 0.4
				else:
					# Если деревьев нет, возвращаемся к дому
					current_state = State.WALKING_TO_HOUSE
					
		State.CHOPPING:
			if not is_instance_valid(target_tree) or target_tree.is_felled:
				if wood_count >= max_wood_carry:
					current_state = State.WALKING_TO_HOUSE
				else:
					current_state = State.WALKING_TO_TREE
			else:
				velocity.x = 0
				chop_timer -= delta
				if chop_timer <= 0:
					chop_tree()
					chop_timer = chop_cooldown
					
		State.WALKING_TO_HOUSE:
			if is_instance_valid(home_house):
				var dist_x = home_house.global_position.x - global_position.x
				if abs(dist_x) > 16.0:
					velocity.x = sign(dist_x) * speed
					body.scale.x = sign(dist_x)
					animate_walk()
				else:
					velocity.x = 0
					# Разгрузка на склад
					if wood_count > 0:
						if home_house.add_wood(1):
							wood_count -= 1
							update_wood_visuals()
							
							# Небольшая пауза при разгрузке
							current_state = State.WALKING_TO_HOUSE
							chop_timer = 0.15 # Используем таймер как паузу разгрузки
							await get_tree().create_timer(0.12).timeout
						else:
							# Склад переполнен
							current_state = State.IDLE
					else:
						current_state = State.IDLE
			else:
				# Если потеряли дом, ищем новый
				var houses = get_tree().get_nodes_in_group("lumberjack_house")
				if houses.size() > 0:
					home_house = houses[0]
				else:
					current_state = State.IDLE

	move_and_slide()
	update_footsteps(delta)
	update_animations()

func chop_tree() -> void:
	if is_instance_valid(target_tree):
		var anim_sprite = body.get_node_or_null("AnimatedSprite2D")
		if anim_sprite:
			anim_sprite.play("Attack_1")
		elif is_instance_valid(axe):
			# Анимация взмаха топора для стоковой векторной графики
			var tween = create_tween()
			axe.rotation = -0.5
			tween.tween_property(axe, "rotation", 1.1, 0.12)
			tween.tween_property(axe, "rotation", 0.0, 0.18)
			
		play_chop_audio_sequence(target_tree)
		
		# Эффект покачивания лесоруба при ударе
		var tween_body = create_tween()
		tween_body.tween_property(body, "scale:y", 0.85, 0.06)
		tween_body.tween_property(body, "scale:y", 1.0, 0.12)

func play_chop_audio_sequence(tree_to_hit: Node2D) -> void:
	chop_swing_audio.stop()
	chop_hit_audio.stop()
	chop_swing_audio.pitch_scale = randf_range(0.92, 0.98)
	chop_hit_audio.pitch_scale = randf_range(0.95, 1.0)
	chop_swing_audio.play()
	if is_instance_valid(tree_to_hit):
		tree_to_hit.hit_tree(global_position.x, chop_damage)
	chop_hit_audio.play()

func add_wood(amount: int = 1) -> bool:
	if wood_count < max_wood_carry:
		wood_count = min(wood_count + amount, max_wood_carry)
		update_wood_visuals()
		return true
	return false

func update_wood_visuals() -> void:
	var children = wood_pile.get_children()
	for i in range(children.size()):
		children[i].visible = i < wood_count

func find_closest_tree() -> Node2D:
	var trees = get_tree().get_nodes_in_group("tree")
	var closest: Node2D = null
	var min_dist: float = 999999.0
	for tree in trees:
		if is_instance_valid(tree) and not tree.is_felled:
			var dist = global_position.distance_to(tree.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = tree
	return closest

func animate_walk() -> void:
	var pulse = sin(Time.get_ticks_msec() * 0.02) * 0.08
	body.scale.y = 1.0 + pulse

func update_footsteps(delta: float) -> void:
	var is_walking = is_on_floor() and abs(velocity.x) > 5.0
	if is_walking:
		footstep_audio.volume_db = move_toward(footstep_audio.volume_db, footstep_base_volume_db, footstep_fadeout_speed_db * delta)
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_audio.stop()
			footstep_audio.volume_db = footstep_base_volume_db
			footstep_audio.pitch_scale = randf_range(0.88, 0.94)
			footstep_audio.play()
			footstep_timer = 0.34
	else:
		footstep_timer = 0.0
		if footstep_audio.playing:
			footstep_audio.volume_db = move_toward(footstep_audio.volume_db, -40.0, footstep_fadeout_speed_db * delta)
			if footstep_audio.volume_db <= -39.0:
				footstep_audio.stop()
				footstep_audio.volume_db = footstep_base_volume_db

func setup_animated_sprite() -> void:
	if not FileAccess.file_exists("res://assets/textures/characters/lumberjack/Idle.png"):
		# Резервный вариант, если новые анимации не найдены
		TextureLoader.try_apply_texture(self, "res://assets/textures/lumberjack.png", Vector2(0, -14))
		return
		
	var sf = SpriteFrames.new()
	
	# 1. Анимация Idle (покой) — 4 кадра размером 128x128
	sf.add_animation("Idle")
	sf.set_animation_speed("Idle", 6.0)
	sf.set_animation_loop("Idle", true)
	var idle_tex = load("res://assets/textures/characters/lumberjack/Idle.png")
	if idle_tex:
		for i in range(4):
			var atlas = AtlasTexture.new()
			atlas.atlas = idle_tex
			atlas.region = Rect2(i * 128, 0, 128, 128)
			sf.add_frame("Idle", atlas)
			
	# 2. Анимация Walk (ходьба) — 4 кадра размером 128x128
	sf.add_animation("Walk")
	sf.set_animation_speed("Walk", 8.0)
	sf.set_animation_loop("Walk", true)
	var walk_tex = load("res://assets/textures/characters/lumberjack/Walk.png")
	if walk_tex:
		for i in range(4):
			var atlas = AtlasTexture.new()
			atlas.atlas = walk_tex
			atlas.region = Rect2(i * 128, 0, 128, 128)
			sf.add_frame("Walk", atlas)
			
	# 3. Анимация Attack_1 (рубка) — 6 кадров размером 128x128 (дубликаты вырезаны из текстуры)
	sf.add_animation("Attack_1")
	sf.set_animation_speed("Attack_1", 3.0) # Замедленная анимация под медленный удар
	sf.set_animation_loop("Attack_1", false)
	var attack_tex = load("res://assets/textures/characters/lumberjack/Attack_1.png")
	if attack_tex:
		for i in range(6):
			var atlas = AtlasTexture.new()
			atlas.atlas = attack_tex
			atlas.region = Rect2(i * 128, 0, 128, 128)
			sf.add_frame("Attack_1", atlas)
			
	var anim_sprite = AnimatedSprite2D.new()
	anim_sprite.name = "AnimatedSprite2D"
	anim_sprite.sprite_frames = sf
	anim_sprite.position = Vector2(4, -42.65) # Возвращаем оригинальное смещение для 128x128
	anim_sprite.scale = Vector2(0.646, 0.646)
	anim_sprite.autoplay = "Idle"
	
	body.add_child(anim_sprite)
	
	# Скрываем все оригинальные векторные элементы внутри Body (Legs, Shirt, Head, Hair, Axe)
	for child in body.get_children():
		if child != anim_sprite:
			if child is CanvasItem:
				child.visible = false

func update_animations() -> void:
	var anim_sprite = body.get_node_or_null("AnimatedSprite2D")
	if not anim_sprite:
		return
		
	# Если сейчас проигрывается атака и она ещё не закончилась — не перебиваем её
	if anim_sprite.animation == "Attack_1" and anim_sprite.is_playing():
		return
		
	if abs(velocity.x) > 5.0:
		anim_sprite.play("Walk")
	else:
		anim_sprite.play("Idle")

func take_damage(amount: float) -> void:
	# Лесоруб превращается обратно в бродягу
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
		
		# Лесоруб роняет все дрова на землю
		if wood_count > 0:
			var wood_scene = load("res://scenes/wood/wood.tscn")
			if wood_scene:
				for i in range(wood_count):
					var w = wood_scene.instantiate()
					get_parent().add_child(w)
					w.global_position = global_position
					var dir_x = -sign(body.scale.x) if body.scale.x != 0 else 1.0
					var target_x = global_position.x + randf_range(30.0, 70.0) * dir_x
					w.launch(target_x, global_position.y)
					
	queue_free()
