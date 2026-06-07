extends CharacterBody2D
const TextureLoader = preload("res://scenes/texture_loader.gd")
const AudioUtilsScript = preload("res://scenes/audio_utils.gd")

@export var speed: float = 70.0
@export var walk_range: float = 140.0

var gravity: float = 900.0
var is_hired: bool = false
var target_position: Vector2
var wander_timer: float = 0.0
var spawn_x: float = 0.0

@onready var body: Node2D = $Body
@onready var robe: ColorRect = $Body/Robe
@onready var label_status: Label = $LabelStatus
@onready var footstep_audio: AudioStreamPlayer2D = $FootstepAudio
@onready var wood_audio: AudioStreamPlayer2D = $WoodAudio

var footstep_timer: float = 0.0
var footstep_base_volume_db: float = -14.0
var footstep_fadeout_speed_db: float = 36.0

func _ready() -> void:
	scale = Vector2(2.5, 2.5)
	add_to_group("vagrant")
	spawn_x = global_position.x
	choose_new_wander_target()
	footstep_audio.volume_db = footstep_base_volume_db
	label_status.visible = false
	setup_tooltip_style(label_status)
	TextureLoader.try_apply_texture(self, "res://assets/textures/vagrant.png", Vector2(0, -14))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if is_hired:
		# Следуем за игроком
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			var dist_x = player.global_position.x - global_position.x
			
			if abs(dist_x) > 60.0:
				velocity.x = sign(dist_x) * speed * 1.3
				body.scale.x = sign(dist_x)
				# Анимация бега
				var pulse = sin(Time.get_ticks_msec() * 0.02) * 0.08
				body.scale.y = 1.0 + pulse
			else:
				velocity.x = move_toward(velocity.x, 0, speed * 0.3)
				body.scale = Vector2(1, 1)
				
		# Нанятые рабочие ходят за игроком молча, не создавая надписей
		label_status.visible = false
	else:
		# Бродим у костра
		wander_timer -= delta
		if wander_timer <= 0:
			choose_new_wander_target()
			
		var dist_x = target_position.x - global_position.x
		if abs(dist_x) > 15.0:
			velocity.x = sign(dist_x) * speed
			body.scale.x = sign(dist_x)
			var pulse = sin(Time.get_ticks_msec() * 0.015) * 0.05
			body.scale.y = 1.0 + pulse
		else:
			velocity.x = move_toward(velocity.x, 0, speed * 0.35)
			body.scale = Vector2(1, 1)
			
		# Показываем статус найма
		var player = get_closest_player()
		if player and global_position.distance_to(player.global_position) < 50.0:
			label_status.visible = true
			if player.wood_count >= 1:
				label_status.text = "Нанять: [E]\n(1 дерево)"
			else:
				label_status.text = "Требуется 1 дерево"
		else:
			label_status.visible = false

	move_and_slide()
	update_footsteps(delta)

func choose_new_wander_target() -> void:
	var campfire = get_tree().get_first_node_in_group("campfire")
	var center_x = campfire.global_position.x if campfire else spawn_x
	target_position = Vector2(center_x + randf_range(-walk_range, walk_range), global_position.y)
	wander_timer = randf_range(2.0, 5.0)

func hire() -> bool:
	if is_hired:
		return false
	is_hired = true
	
	# Меняем одежду на более чистую
	robe.color = Color(0.6, 0.45, 0.35, 1.0)
	
	# Звук передачи дров бродяге (только если игрок видит сцену найма)
	if wood_audio:
		wood_audio.pitch_scale = randf_range(0.95, 1.08)
		AudioUtilsScript.play_if_visible(wood_audio)
	
	# Эффект найма
	var tween = create_tween()
	tween.tween_property(body, "scale", Vector2(1.3, 0.7), 0.1)
	tween.tween_property(body, "scale", Vector2(1.0, 1.0), 0.15)
	
	remove_from_group("vagrant")
	add_to_group("citizen")
	return true

func get_closest_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func setup_tooltip_style(label: Label) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.45, 0.55, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	label.add_theme_stylebox_override("normal", style)

func update_footsteps(delta: float) -> void:
	var is_walking = is_on_floor() and abs(velocity.x) > 5.0
	if is_walking:
		footstep_audio.volume_db = move_toward(footstep_audio.volume_db, footstep_base_volume_db, footstep_fadeout_speed_db * delta)
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_audio.stop()
			footstep_audio.volume_db = footstep_base_volume_db
			footstep_audio.pitch_scale = randf_range(0.90, 0.97)
			AudioUtilsScript.play_if_visible(footstep_audio)
			footstep_timer = 0.4
	else:
		footstep_timer = 0.0
		if footstep_audio.playing:
			footstep_audio.volume_db = move_toward(footstep_audio.volume_db, -40.0, footstep_fadeout_speed_db * delta)
			if footstep_audio.volume_db <= -39.0:
				footstep_audio.stop()
				footstep_audio.volume_db = footstep_base_volume_db
