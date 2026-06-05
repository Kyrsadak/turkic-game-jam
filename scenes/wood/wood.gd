extends Area2D
const TextureLoader = preload("res://scenes/texture_loader.gd")

var is_on_ground: bool = false
var is_flying_to_target: bool = false
var target_collector: Node2D = null
var fly_speed: float = 14.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("wood_drop")
	TextureLoader.try_apply_texture(self, "res://assets/textures/wood.png", Vector2(0, 0))

func launch(target_x: float, ground_y: float) -> void:
	var start_pos = global_position
	var peak_height = randf_range(30, 50)
	var duration = randf_range(0.4, 0.6)
	
	# Выключаем коллизию во время полета
	collision_shape.disabled = true
	
	var tween = create_tween().set_parallel(true)
	# Движение по горизонтали
	tween.tween_property(self, "global_position:x", target_x, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Арка по вертикали
	var y_tween = create_tween()
	y_tween.tween_property(self, "global_position:y", start_pos.y - peak_height, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	y_tween.tween_property(self, "global_position:y", ground_y, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	# Легкий отскок при приземлении
	var bounce_tween = create_tween()
	bounce_tween.tween_property(self, "global_position:y", ground_y - 6, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(self, "global_position:y", ground_y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await bounce_tween.finished
	
	is_on_ground = true
	collision_shape.disabled = false

func _process(delta: float) -> void:
	if not is_on_ground:
		return
		
	if is_flying_to_target:
		if is_instance_valid(target_collector):
			# Летим к коллектору (чуть выше его ног)
			var target_pos = target_collector.global_position + Vector2(0, -12)
			global_position = global_position.lerp(target_pos, fly_speed * delta)
			
			if global_position.distance_to(target_pos) < 10.0:
				if target_collector.has_method("add_wood") and target_collector.add_wood(1):
					queue_free()
				else:
					# Если коллектор уже заполнен, падаем обратно на землю
					is_flying_to_target = false
					target_collector = null
		else:
			is_flying_to_target = false
			target_collector = null
	else:
		# Поиск ближайшего персонажа (Игрок или Лесоруб), у которого есть место под дерево
		var players = get_tree().get_nodes_in_group("player")
		var lumberjacks = get_tree().get_nodes_in_group("lumberjack")
		
		var collectors = []
		collectors.append_array(players)
		collectors.append_array(lumberjacks)
		
		var closest: Node2D = null
		var min_dist: float = 50.0 # Радиус притяжения
		
		for col in collectors:
			if is_instance_valid(col) and col.has_method("add_wood"):
				var has_space = false
				if "wood_count" in col and "max_wood_carry" in col:
					has_space = col.wood_count < col.max_wood_carry
				else:
					has_space = true
					
				if has_space:
					var dist = global_position.distance_to(col.global_position)
					if dist < min_dist:
						min_dist = dist
						closest = col
						
		if closest:
			target_collector = closest
			is_flying_to_target = true
