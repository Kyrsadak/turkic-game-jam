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
var builder_house_scene = preload("res://scenes/buildings/builder_house.tscn")
var archer_tower_scene = preload("res://scenes/buildings/archer_tower.tscn")

var bear_spawn_queue: int = 0

# Цвета для дня и ночи
var day_color = Color(1.0, 1.0, 1.0, 1.0)
var night_color = Color(0.28, 0.28, 0.45, 1.0)
var transition_duration: float = 24.0

# Ссылки на фоновые спрайты и небесные тела
var bg_day_sprite: Sprite2D
var bg_night_sprite: Sprite2D
var sun_sprite: Sprite2D
var moon_sprite: Sprite2D

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
	
	# Настраиваем новый фон с горами
	setup_background()
	
	# Настраиваем текстуру земли под ногами
	setup_ground()

func _process(delta: float) -> void:
	if game_over_active:
		if Input.is_key_pressed(KEY_R):
			restart_game()
		return

	# Игровое время
	time_in_state += delta
	
	# Обновляем фон и небесные тела
	update_background_and_celestial(delta)
	
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
	# Левый лес: от -7200 до -350
	var current_x = -350.0
	while current_x > -7200.0:
		spawn_tree_at(current_x, $ForestLeft)
		current_x -= randf_range(50.0, 95.0)
		
	# Правый лес: от 350 до 7200
	current_x = 350.0
	while current_x < 7200.0:
		spawn_tree_at(current_x, $ForestRight)
		current_x += randf_range(50.0, 95.0)

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

func setup_background() -> void:
	# Скрываем старый векторный фон
	var bg_forest = get_node_or_null("BackgroundForest")
	if bg_forest:
		bg_forest.visible = false
		
	# Создаем ParallaxBackground для гор
	var pb = ParallaxBackground.new()
	pb.layer = -100 # Отрисовывается позади всех элементов
	add_child(pb)
	
	# Добавляем ParallaxLayer
	var pl = ParallaxLayer.new()
	pl.motion_scale = Vector2(0.15, 0.05) # Медленный параллакс по горизонтали, почти статичный по вертикали
	pl.motion_mirroring = Vector2(1024, 0)
	pb.add_child(pl)
	
	# Дневной фон
	bg_day_sprite = Sprite2D.new()
	var tex_day = load("res://assets/textures/background_mountains_day.png")
	if tex_day:
		bg_day_sprite.texture = tex_day
		bg_day_sprite.centered = false
		bg_day_sprite.position = Vector2(0, -120)
		bg_day_sprite.modulate.a = 1.0
		pl.add_child(bg_day_sprite)
		
	# Ночной фон
	bg_night_sprite = Sprite2D.new()
	var tex_night = load("res://assets/textures/background_mountains.png")
	if tex_night:
		bg_night_sprite.texture = tex_night
		bg_night_sprite.centered = false
		bg_night_sprite.position = Vector2(0, -120)
		bg_night_sprite.modulate.a = 0.0 # Начинаем с дневного
		pl.add_child(bg_night_sprite)
		
	# Создаем отдельный CanvasLayer для небесных тел (Солнце, Луна)
	# Позиционируем их за игровыми элементами, но перед дальними горами
	var celestial_layer = CanvasLayer.new()
	celestial_layer.layer = -95
	add_child(celestial_layer)
	
	# Солнце
	sun_sprite = Sprite2D.new()
	var tex_sun = load("res://assets/textures/sun.png")
	if tex_sun:
		sun_sprite.texture = tex_sun
		sun_sprite.modulate.a = 1.0
		celestial_layer.add_child(sun_sprite)
		
	# Луна
	moon_sprite = Sprite2D.new()
	var tex_moon = load("res://assets/textures/moon.png")
	if tex_moon:
		moon_sprite.texture = tex_moon
		moon_sprite.modulate.a = 0.0
		celestial_layer.add_child(moon_sprite)

func update_background_and_celestial(delta: float) -> void:
	if not is_instance_valid(bg_day_sprite) or not is_instance_valid(bg_night_sprite):
		return
		
	# 1. Вычисляем степень перехода (transition_factor) от 0.0 (день) до 1.0 (ночь)
	var transition_factor: float = 0.0
	if is_day:
		var time_left = day_duration - time_in_state
		if time_left < transition_duration:
			transition_factor = (transition_duration - time_left) / transition_duration
		else:
			transition_factor = 0.0
	else:
		var time_left = night_duration - time_in_state
		if time_left < transition_duration:
			transition_factor = 1.0 - ((transition_duration - time_left) / transition_duration)
		else:
			transition_factor = 1.0
			
	# 2. Плавно смешиваем прозрачность фонов гор
	bg_day_sprite.modulate.a = 1.0 - transition_factor
	bg_night_sprite.modulate.a = transition_factor
	
	# 3. Получаем размеры экрана для расчета траектории
	var viewport_size = get_viewport_rect().size
	var w = viewport_size.x
	var h = viewport_size.y
	
	# 4. Движение солнца и луны по дуге
	if is_day:
		var sun_prog = time_in_state / day_duration
		var sun_angle = PI * (1.0 - sun_prog)
		if is_instance_valid(sun_sprite):
			sun_sprite.position = Vector2(
				w * 0.5 + cos(sun_angle) * (w * 0.45),
				h * 0.7 - sin(sun_angle) * (h * 0.55)
			)
			sun_sprite.modulate.a = 1.0 - transition_factor
			
		if is_instance_valid(moon_sprite):
			var moon_angle = PI * (1.0 - transition_factor * 0.1)
			moon_sprite.position = Vector2(
				w * 0.5 + cos(moon_angle) * (w * 0.45),
				h * 0.7 - sin(moon_angle) * (h * 0.55)
			)
			moon_sprite.modulate.a = transition_factor
	else:
		var night_prog = time_in_state / night_duration
		var moon_angle = PI * (1.0 - night_prog)
		if is_instance_valid(moon_sprite):
			moon_sprite.position = Vector2(
				w * 0.5 + cos(moon_angle) * (w * 0.45),
				h * 0.7 - sin(moon_angle) * (h * 0.55)
			)
			moon_sprite.modulate.a = transition_factor
			
		if is_instance_valid(sun_sprite):
			var sun_angle = PI * (1.0 - (1.0 - transition_factor) * 0.1)
			sun_sprite.position = Vector2(
				w * 0.5 + cos(sun_angle) * (w * 0.45),
				h * 0.7 - sin(sun_angle) * (h * 0.55)
			)
			sun_sprite.modulate.a = 1.0 - transition_factor

func setup_ground() -> void:
	var ground = get_node_or_null("Ground")
	if ground:
		var visual = ground.get_node_or_null("Visual")
		if visual:
			visual.visible = false
		var border = ground.get_node_or_null("GrassBorder")
		if border:
			border.visible = false
			
		var tex = load("res://assets/textures/ground_snowy.png")
		if tex:
			var sprite = Sprite2D.new()
			sprite.name = "SnowyGroundSprite"
			sprite.texture = tex
			sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, 15000, 128)
			sprite.centered = false
			sprite.position = Vector2(-7500, 0)
			ground.add_child(sprite)



