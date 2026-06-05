extends Node2D

@export var day_duration: float = 165.0
@export var night_duration: float = 75.0

var current_day: int = 1
var is_day: bool = true
var time_in_state: float = 0.0
var game_over_active: bool = false

var vagrant_spawn_timer: float = 30.0
var wolf_spawn_queue: int = 0
var wolf_spawn_timer: float = 0.0

@onready var campfire: Node2D = $Campfire
@onready var player: CharacterBody2D = $Player
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var hud: CanvasLayer = $HUD
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var label_day_status: Label = $HUD/MarginContainer/VBoxContainer/LabelDayStatus
@onready var progress_fuel: ProgressBar = $HUD/MarginContainer/VBoxContainer/ProgressFuel
@onready var label_wood: Label = $HUD/MarginContainer/VBoxContainer/LabelWood

var vagrant_scene = preload("res://scenes/vagrant/vagrant.tscn")
var wolf_scene = preload("res://scenes/enemy/enemy.tscn")
var tree_scene = preload("res://scenes/tree/tree.tscn")
var bear_scene = preload("res://scenes/enemy/bear.tscn")

var bear_spawn_queue: int = 0

# Цвета для дня и ночи
var day_color = Color(1.0, 1.0, 1.0, 1.0)
var night_color = Color(0.28, 0.28, 0.45, 1.0)
var transition_duration: float = 24.0

func _ready() -> void:
	game_over_screen.visible = false
	campfire.connect("burned_out", Callable(self, "_on_campfire_burned_out"))
	campfire.connect("fuel_changed", Callable(self, "_on_campfire_fuel_changed"))
	player.connect("wood_count_changed", Callable(self, "_on_player_wood_changed"))
	
	# Генерируем леса и пещеры
	generate_forests()
	create_cave_at(-7300.0, false)
	create_cave_at(7300.0, true)
	
	# Начальные значения интерфейса
	_on_player_wood_changed(player.wood_count)
	_on_campfire_fuel_changed(campfire.current_fuel, campfire.max_fuel)
	update_hud_text()

func _process(delta: float) -> void:
	if game_over_active:
		if Input.is_key_pressed(KEY_R):
			restart_game()
		return

	# Игровое время
	time_in_state += delta
	
	# Логика смены дня и ночи
	if is_day:
		if time_in_state >= day_duration:
			start_night()
		else:
			# Плавный переход в сумерки к концу дня
			var time_left = day_duration - time_in_state
			if time_left < transition_duration:
				var t = (transition_duration - time_left) / transition_duration
				canvas_modulate.color = day_color.lerp(night_color, t)
			else:
				canvas_modulate.color = day_color
	else:
		if time_in_state >= night_duration:
			start_day()
		else:
			# Плавный переход в рассвет к концу ночи
			var time_left = night_duration - time_in_state
			if time_left < transition_duration:
				var t = (transition_duration - time_left) / transition_duration
				canvas_modulate.color = night_color.lerp(day_color, t)
			else:
				canvas_modulate.color = night_color

	# Спавн бродяг (днем)
	if is_day:
		vagrant_spawn_timer -= delta
		if vagrant_spawn_timer <= 0:
			spawn_vagrant_if_needed()
			vagrant_spawn_timer = randf_range(45.0, 75.0)

	# Спавн волков и медведей (ночью)
	if not is_day and (wolf_spawn_queue > 0 or bear_spawn_queue > 0):
		wolf_spawn_timer -= delta
		if wolf_spawn_timer <= 0:
			if bear_spawn_queue > 0 and (wolf_spawn_queue == 0 or randf() > 0.6):
				spawn_bear()
				bear_spawn_queue -= 1
			elif wolf_spawn_queue > 0:
				spawn_wolf()
				wolf_spawn_queue -= 1
			wolf_spawn_timer = randf_range(4.0, 8.0)

	update_hud_text()

func start_day() -> void:
	is_day = true
	time_in_state = 0.0
	current_day += 1
	
	# Убираем оставшихся волков
	var remaining_wolves = get_tree().get_nodes_in_group("enemy")
	for wolf in remaining_wolves:
		if is_instance_valid(wolf) and not wolf.is_dead:
			wolf.take_damage(999.0) # Сгорают на солнце

func start_night() -> void:
	is_day = false
	time_in_state = 0.0
	
	# Вычисляем размер волны волков и медведей
	if current_day == 1:
		wolf_spawn_queue = 2
		bear_spawn_queue = 0
	elif current_day == 2:
		wolf_spawn_queue = 3
		bear_spawn_queue = 0
	elif current_day == 3:
		wolf_spawn_queue = 4
		bear_spawn_queue = 1
	elif current_day == 4:
		wolf_spawn_queue = 5
		bear_spawn_queue = 2
	else:
		wolf_spawn_queue = int(current_day * 1.5 + 1)
		bear_spawn_queue = int(current_day - 2)
	wolf_spawn_timer = 4.0 # Небольшая задержка перед первой атакой

func spawn_vagrant_if_needed() -> void:
	var total_vagrants = get_tree().get_nodes_in_group("vagrant").size()
	var total_citizens = get_tree().get_nodes_in_group("citizen").size()
	
	# Ограничиваем количество свободных жителей в мире
	if total_vagrants + total_citizens < 10:
		# Выбираем случайную сторону спавна бродяг (далеко в лесу)
		var spawn_side = 1.0 if randf() > 0.5 else -1.0
		var spawn_x = spawn_side * randf_range(4000.0, 6800.0)
		
		var vagrant = vagrant_scene.instantiate()
		add_child(vagrant)
		vagrant.global_position = Vector2(spawn_x, -10)
		
		# Эффект плавного появления
		vagrant.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(vagrant, "modulate:a", 1.0, 1.0)

func spawn_wolf() -> void:
	# Волки спавнятся из пещер по краям карты
	var spawn_side = 1.0 if randf() > 0.5 else -1.0
	var spawn_x = spawn_side * 7300.0
	
	var wolf = wolf_scene.instantiate()
	add_child(wolf)
	wolf.global_position = Vector2(spawn_x, -10)
	
	wolf.max_health = 20.0 + current_day * 4.0
	wolf.health = wolf.max_health
	wolf.speed = 90.0 + current_day * 2.0

func spawn_bear() -> void:
	# Медведи спавнятся из пещер по краям карты
	var spawn_side = 1.0 if randf() > 0.5 else -1.0
	var spawn_x = spawn_side * 7300.0
	
	var bear = bear_scene.instantiate()
	add_child(bear)
	bear.global_position = Vector2(spawn_x, -10)
	
	bear.max_health = 70.0 + current_day * 10.0
	bear.health = bear.max_health
	bear.speed = 40.0 + current_day * 1.5

func generate_forests() -> void:
	# Левый лес: от -7200 до -650
	var current_x = -650.0
	while current_x > -7200.0:
		spawn_tree_at(current_x, $ForestLeft)
		current_x -= randf_range(80.0, 130.0)
		
	# Правый лес: от 650 до 7200
	current_x = 650.0
	while current_x < 7200.0:
		spawn_tree_at(current_x, $ForestRight)
		current_x += randf_range(80.0, 130.0)

func spawn_tree_at(x_pos: float, container: Node2D) -> void:
	var tree_instance = tree_scene.instantiate()
	container.add_child(tree_instance)
	tree_instance.global_position = Vector2(x_pos, 0)

func create_cave_at(x_pos: float, is_right_side: bool) -> void:
	var cave_node = Node2D.new()
	cave_node.name = "CaveRight" if is_right_side else "CaveLeft"
	cave_node.global_position = Vector2(x_pos, 0)
	
	# Архитектура пещеры с использованием полигона
	var poly = Polygon2D.new()
	poly.color = Color(0.06, 0.05, 0.08, 1.0)
	
	var points = PackedVector2Array()
	var steps = 12
	var radius = 35.0
	for i in range(steps + 1):
		var angle = PI + (PI * i / steps)
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	points.append(Vector2(radius, 0))
	points.append(Vector2(-radius, 0))
	
	poly.polygon = points
	cave_node.add_child(poly)
	
	# Текстовая подсказка
	var label = Label.new()
	label.text = "Пещера"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -55)
	label.size = Vector2(100, 20)
	
	var settings = LabelSettings.new()
	settings.font_size = 9
	settings.outline_size = 2
	settings.outline_color = Color(0, 0, 0, 1)
	label.label_settings = settings
	
	cave_node.add_child(label)
	add_child(cave_node)

func _on_campfire_burned_out() -> void:
	game_over_active = true
	game_over_screen.visible = true
	
	# Показываем финальную статистику
	var label_stats = game_over_screen.get_node("MarginContainer/VBoxContainer/LabelStats")
	label_stats.text = "Вы прожили дней: %d" % current_day
	
	# Затемняем мир драматично
	var tween = create_tween()
	tween.tween_property(canvas_modulate, "color", Color(0, 0, 0, 1), 2.0)

func _on_campfire_fuel_changed(current_fuel: float, max_fuel: float) -> void:
	progress_fuel.value = (current_fuel / max_fuel) * 100.0

func _on_player_wood_changed(count: int) -> void:
	label_wood.text = "Дров у Короля: %d/%d" % [count, player.max_wood_carry]

func update_hud_text() -> void:
	var state_name = "ДЕНЬ" if is_day else "НОЧЬ"
	var time_left = int((day_duration if is_day else night_duration) - time_in_state)
	label_day_status.text = "День %d | %s (%d сек)" % [current_day, state_name, time_left]

func restart_game() -> void:
	get_tree().reload_current_scene()
