extends CharacterBody2D

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

func _ready() -> void:
	add_to_group("vagrant")
	spawn_x = global_position.x
	choose_new_wander_target()
	label_status.visible = false

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
				
		# Показываем статус игроку
		var player = get_closest_player()
		if player and global_position.distance_to(player.global_position) < 80.0:
			label_status.visible = true
			label_status.text = "Свободный рабочий\nИдите к дому лесоруба/казарме"
		else:
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
