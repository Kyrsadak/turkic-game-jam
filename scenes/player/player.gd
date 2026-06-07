extends CharacterBody2D
const TextureLoader = preload("res://scenes/texture_loader.gd")

signal wood_count_changed(count)

@export var speed: float = 110.0
@export var max_wood_carry: int = 5

var gravity: float = 900.0
var wood_count: int = 0
var is_hitting: bool = false

@onready var body: Node2D = $Body
@onready var wood_pile: Node2D = $WoodPile
@onready var hit_cooldown: Timer = $HitCooldown
@onready var camera: Camera2D = $Camera2D
@onready var footstep_audio: AudioStreamPlayer2D = $FootstepAudio
@onready var chop_swing_audio: AudioStreamPlayer2D = $ChopSwingAudio
@onready var chop_hit_audio: AudioStreamPlayer2D = $ChopHitAudio

var shake_strength: float = 0.0
var shake_decay: float = 24.0
var footstep_timer: float = 0.0
var footstep_base_volume_db: float = -6.4
var footstep_fadeout_speed_db: float = 42.0
var chop_sound_sequence: int = 0
var chop_hit_impact_delay_sec: float = 0.16
var is_mining: bool = false

const AXE_HITBOX_OFFSET: Vector2 = Vector2(14.0, -16.0)
const AXE_HITBOX_SIZE: Vector2 = Vector2(24.0, 26.0)

func _ready() -> void:
	add_to_group("player")
	update_wood_visuals()
	footstep_audio.volume_db = footstep_base_volume_db
	chop_swing_audio.max_polyphony = 3
	chop_hit_audio.max_polyphony = 4
	
	if has_node("AnimatedSprite2D"):
		var anim_sprite = $AnimatedSprite2D
		anim_sprite.reparent(body, false)
	else:
		TextureLoader.try_apply_texture(self, "res://assets/textures/player.png", Vector2(0, -16))
		
	if has_node("WoodPile"):
		var wp = $WoodPile
		wp.reparent(body, false)

func _physics_process(delta: float) -> void:
	# Гравитация
	if not is_on_floor():
		velocity.y += gravity * delta

	# Затухание тряски камеры
	if shake_strength > 0.0:
		shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)
		camera.offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
	else:
		camera.offset = Vector2.ZERO


	# Движение влево-вправо (A/D или Стрелки)
	var direction = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0
		
	if direction != 0.0:
		velocity.x = direction * speed
		body.scale.x = sign(direction) # Поворачиваем лицо игрока
		
		# Микро-анимация покачивания при беге
		if is_on_floor() and not is_hitting:
			var pulse = sin(Time.get_ticks_msec() * 0.015) * 0.08
			body.scale.y = 1.0 + pulse
			body.position.y = pulse * 1.5
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 0.25)
		if is_on_floor() and not is_hitting:
			body.scale.y = 1.0
			body.position = Vector2(0, 0)

	move_and_slide()
	update_footsteps(delta)
	update_animations()

	# Обработка клавиши E или клика мыши для взаимодействия
	var wants_to_interact = Input.is_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if wants_to_interact and not is_hitting:
		perform_interaction()

func perform_interaction() -> void:
	# 1. Проверяем, есть ли рядом костер и хотим ли закинуть дерево
	var campfire = get_closest_in_group("campfire", 60.0)
	if campfire and wood_count > 0:
		if campfire.current_fuel < campfire.max_fuel - 2.0:
			if campfire.add_wood():
				wood_count -= 1
				emit_signal("wood_count_changed", wood_count)
				update_wood_visuals()
				
				# Анимация отдачи
				var tween = create_tween()
				tween.tween_property(wood_pile, "position:y", -5.0, 0.1)
				tween.tween_property(wood_pile, "position:y", 0.0, 0.1)
				
				apply_camera_shake(0.25)
				is_hitting = true
				await get_tree().create_timer(0.25).timeout
				is_hitting = false
				return

	# 2. Проверяем, касается ли хитбокс топора дерева
	var tree = get_tree_in_axe_hitbox()
	if tree:
		start_hit_animation(tree)
		return

	# 3. Проверяем здания для сдачи дров / найма
	var building = get_closest_in_group("buildings", 55.0)
	if building:
		if wood_count > 0 and building.has_method("deposit_wood"):
			if building.deposit_wood():
				wood_count -= 1
				emit_signal("wood_count_changed", wood_count)
				update_wood_visuals()
				
				apply_camera_shake(0.25)
				is_hitting = true
				await get_tree().create_timer(0.2).timeout
				is_hitting = false
				return
		if building.has_method("interact") and building.interact(self):
			return

	# 4. Проверяем бродяг для найма (цена 1 дерево)
	var vagrant = get_closest_in_group("vagrant", 50.0)
	if vagrant and not vagrant.is_hired and wood_count >= 1:
		if vagrant.hire():
			wood_count -= 1
			emit_signal("wood_count_changed", wood_count)
			update_wood_visuals()
			
			start_hit_animation()
			return

	# 5. Если рядом нет цели для взаимодействия — всё равно делаем взмах
	start_hit_animation()

func start_hit_animation(tree_to_hit: Node = null) -> void:
	is_hitting = true
	is_mining = true

	var anim_sprite = body.get_node_or_null("AnimatedSprite2D")
	if anim_sprite:
		anim_sprite.frame = 0
		anim_sprite.play("Mining")

	if tree_to_hit != null:
		apply_camera_shake(0.4)
	else:
		apply_camera_shake(0.2)

	hit_cooldown.start()
	play_chop_audio_sequence(tree_to_hit)

	# Эффект удара (маленький наклон тела, без выворачивания)
	# Сбрасываем scale.y в 1 чтобы пульс-эффект ходьбы не мешал
	var dir_sign = sign(body.scale.x) if body.scale.x != 0 else 1
	body.scale = Vector2(dir_sign, 1.0)
	body.position = Vector2.ZERO

	# Пустой замах длится дольше, чтобы успел отыграть полный цикл анимации рубки.
	# При рубке дерева оставляем быстрый темп, чтобы ритм ударов не замедлялся.
	var swing_duration: float = 0.20 if tree_to_hit != null else 0.55
	var tween = create_tween()
	var orig_rot = body.rotation
	var hit_rot = 0.15 * dir_sign
	tween.tween_property(body, "rotation", hit_rot, swing_duration * 0.4)
	tween.tween_property(body, "rotation", orig_rot, swing_duration * 0.6)

	await tween.finished
	is_hitting = false
	is_mining = false

func play_chop_audio_sequence(tree_to_hit: Node = null) -> void:
	chop_sound_sequence += 1
	var current_sequence: int = chop_sound_sequence

	if tree_to_hit == null:
		chop_swing_audio.pitch_scale = randf_range(0.72, 0.82)
		chop_swing_audio.play()
		return

	chop_hit_audio.pitch_scale = randf_range(0.74, 0.84)
	await get_tree().create_timer(chop_hit_impact_delay_sec).timeout
	if current_sequence != chop_sound_sequence:
		return
	if is_instance_valid(tree_to_hit):
		tree_to_hit.hit_tree(global_position.x)
	chop_hit_audio.play()

func get_tree_in_axe_hitbox() -> Node2D:
	var axe_hitbox_rect := get_axe_hitbox_rect()
	var trees = get_tree().get_nodes_in_group("tree")
	var closest_tree: Node2D = null
	var closest_dist := INF

	for tree in trees:
		if not (tree is Node2D):
			continue
		var tree_node := tree as Node2D
		if tree_node.get("is_felled") == true:
			continue
		var tree_rect := get_tree_contact_rect(tree_node)
		if not axe_hitbox_rect.intersects(tree_rect):
			continue
		var dist := global_position.distance_to(tree_node.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_tree = tree_node

	return closest_tree

func get_axe_hitbox_rect() -> Rect2:
	var character_scale := scale.abs()
	var center := global_position + Vector2(
		AXE_HITBOX_OFFSET.x * character_scale.x * body.scale.x,
		AXE_HITBOX_OFFSET.y * character_scale.y
	)
	var size := Vector2(
		AXE_HITBOX_SIZE.x * character_scale.x,
		AXE_HITBOX_SIZE.y * character_scale.y
	)
	return Rect2(center - size * 0.5, size)

func get_tree_contact_rect(tree_node: Node2D) -> Rect2:
	var collision_shape := tree_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var shape := collision_shape.shape as RectangleShape2D
		var global_scale := tree_node.scale.abs()
		var center := tree_node.global_position + Vector2(
			collision_shape.position.x * global_scale.x,
			collision_shape.position.y * global_scale.y
		)
		var size := Vector2(
			shape.size.x * global_scale.x,
			shape.size.y * global_scale.y
		)
		return Rect2(center - size * 0.5, size)

	# Fallback, если форма дерева изменилась или отсутствует.
	var fallback_size := Vector2(44.0, 74.0)
	return Rect2(tree_node.global_position - fallback_size * 0.5, fallback_size)

func add_wood(amount: int = 1) -> bool:
	if wood_count < max_wood_carry:
		wood_count = min(wood_count + amount, max_wood_carry)
		emit_signal("wood_count_changed", wood_count)
		update_wood_visuals()
		return true
	return false

func update_wood_visuals() -> void:
	var children = wood_pile.get_children()
	for i in range(children.size()):
		children[i].visible = i < wood_count

func get_closest_in_group(group_name: String, max_dist: float) -> Node:
	var nodes = get_tree().get_nodes_in_group(group_name)
	var closest_node: Node = null
	var closest_dist: float = max_dist
	for node in nodes:
		var dist = global_position.distance_to(node.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_node = node
	return closest_node

func _on_hit_cooldown_timeout() -> void:
	pass

func apply_camera_shake(strength: float) -> void:
	shake_strength = strength

func update_footsteps(delta: float) -> void:
	var is_walking = is_on_floor() and abs(velocity.x) > 5.0 and not is_hitting
	if is_walking:
		footstep_audio.volume_db = move_toward(footstep_audio.volume_db, footstep_base_volume_db, footstep_fadeout_speed_db * delta)
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_audio.stop()
			footstep_audio.volume_db = footstep_base_volume_db
			footstep_audio.pitch_scale = randf_range(0.92, 0.98)
			footstep_audio.play()
			footstep_timer = 0.36
	else:
		footstep_timer = 0.0
		if footstep_audio.playing:
			footstep_audio.volume_db = move_toward(footstep_audio.volume_db, -40.0, footstep_fadeout_speed_db * delta)
			if footstep_audio.volume_db <= -39.0:
				footstep_audio.stop()
				footstep_audio.volume_db = footstep_base_volume_db

func update_animations() -> void:
	var anim_sprite = body.get_node_or_null("AnimatedSprite2D")
	if not anim_sprite:
		return
		
	if is_mining:
		if anim_sprite.animation != "Mining":
			anim_sprite.play("Mining")
	elif abs(velocity.x) > 5.0:
		if anim_sprite.animation != "walk":
			anim_sprite.play("walk")
	else:
		if anim_sprite.animation != "Idle":
			anim_sprite.play("Idle")
