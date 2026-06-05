extends StaticBody2D

signal tree_felled(wood_count)

@export var max_health: float = 10.0
@export var regrow_time: float = 180.0

var health: float = 10.0
var is_felled: bool = false
var regrow_timer: float = 0.0
var feller_was_lumberjack: bool = false

@onready var visual: Node2D = $Visual
@onready var crown: Polygon2D = $Visual/Crown
@onready var trunk: ColorRect = $Visual/Trunk
@onready var particles: CPUParticles2D = $Particles
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var wood_drop_scene = preload("res://scenes/wood/wood.tscn")

@onready var label_health: Label = $LabelHealth

func _ready() -> void:
	add_to_group("tree")
	health = max_health
	visual.modulate.a = 1.0
	label_health.visible = false

func _process(delta: float) -> void:
	if is_felled:
		label_health.visible = false
		regrow_timer -= delta
		if regrow_timer <= 0:
			regrow()
	else:
		# Отображаем подсказку при приближении игрока
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			var dist = global_position.distance_to(player.global_position)
			if dist < 65.0:
				label_health.visible = true
				if health == max_health:
					label_health.text = "Рубить дерево [E]"
				else:
					label_health.text = "Срубить: %d / 10" % int(health)
			else:
				label_health.visible = false
		else:
			label_health.visible = false

func hit_tree(hitter_x: float, damage: float = 1.0) -> void:
	if is_felled:
		return
		
	# Если дамаг больше 1.5, значит рубит лесоруб
	if damage > 1.5:
		feller_was_lumberjack = true
	else:
		feller_was_lumberjack = false

	health -= damage
	
	# Активация щепок
	particles.emitting = true
	particles.restart()
	
	# Направление покачивания при ударе
	var shake_dir = 1.0 if hitter_x < global_position.x else -1.0
	
	var tween = create_tween()
	tween.tween_property(visual, "rotation", shake_dir * 0.06, 0.05)
	tween.tween_property(visual, "rotation", -shake_dir * 0.03, 0.05)
	tween.tween_property(visual, "rotation", 0.0, 0.1)
	
	if health <= 0:
		fell_tree(hitter_x)

func fell_tree(feller_x: float) -> void:
	is_felled = true
	collision_shape.disabled = true
	
	# Направление падения (от лесоруба)
	var fall_dir = 1.0 if feller_x < global_position.x else -1.0
	
	# Анимация падения дерева
	var tween = create_tween()
	tween.set_parallel(true)
	# Поворачиваем вокруг основания (ось X=0, Y=0 локально находится у корней)
	tween.tween_property(visual, "rotation", fall_dir * (PI / 2.2), 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "modulate:a", 0.0, 1.2)
	
	# Количество выпадающих дров: лесоруб -> 6, игрок -> 4-5
	var drop_count = 6 if feller_was_lumberjack else randi_range(4, 5)
	
	for i in range(drop_count):
		# Откладываем спавн, чтобы избежать конфликтов в дереве сцен
		call_deferred("spawn_wood", fall_dir)
		
	regrow_timer = regrow_time
	emit_signal("tree_felled", drop_count)

func spawn_wood(fall_dir: float) -> void:
	var wood = wood_drop_scene.instantiate()
	get_parent().add_child(wood)
	
	# Спавним чуть выше корней
	wood.global_position = global_position + Vector2(0, -12)
	
	# Разбрасываем дрова
	var target_x = global_position.x + fall_dir * randf_range(30, 80) + randf_range(-10, 10)
	wood.launch(target_x, global_position.y)

func regrow() -> void:
	is_felled = false
	health = max_health
	collision_shape.disabled = false
	visual.rotation = 0.0
	feller_was_lumberjack = false
	
	# Плавное появление
	var tween = create_tween()
	tween.tween_property(visual, "modulate:a", 1.0, 1.5)
