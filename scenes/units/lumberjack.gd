extends CharacterBody2D
const TextureLoader = preload("res://scenes/texture_loader.gd")

enum State { IDLE, WALKING_TO_TREE, CHOPPING, WALKING_TO_HOUSE }

@export var speed: float = 85.0
@export var chop_damage: float = 10.0
@export var chop_cooldown: float = 1.1

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
var footstep_base_volume_db: float = -14.0
var footstep_fadeout_speed_db: float = 38.0
var chop_sound_sequence: int = 0
var chop_hit_overlap_before_end_sec: float = 0.06

func _ready() -> void:
	scale = Vector2(2.5, 2.5)
	add_to_group("lumberjack")
	update_wood_visuals()
	current_state = State.WALKING_TO_TREE
	footstep_audio.volume_db = footstep_base_volume_db
	TextureLoader.try_apply_texture(self, "res://assets/textures/lumberjack.png", Vector2(0, -14))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, speed * 0.3)
			body.scale = Vector2(1, 1)
			
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

func chop_tree() -> void:
	if is_instance_valid(target_tree):
		# Анимация взмаха топора
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
	chop_sound_sequence += 1
	var current_sequence: int = chop_sound_sequence
	chop_swing_audio.stop()
	chop_hit_audio.stop()
	chop_swing_audio.pitch_scale = randf_range(0.92, 0.98)
	chop_hit_audio.pitch_scale = randf_range(0.95, 1.0)
	chop_swing_audio.play()

	var swing_length_sec: float = 0.2
	if chop_swing_audio.stream:
		swing_length_sec = chop_swing_audio.stream.get_length() / max(chop_swing_audio.pitch_scale, 0.01)
	var impact_delay_sec: float = max(0.0, swing_length_sec - chop_hit_overlap_before_end_sec)
	await get_tree().create_timer(impact_delay_sec).timeout
	if current_sequence != chop_sound_sequence:
		return
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
