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

@onready var campfire: Node2D = get_node_or_null("Campfire")
@onready var player: CharacterBody2D = $Player
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var hud: CanvasLayer = $HUD
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var label_day_status: Label = $HUD/MarginContainer/VBoxContainer/LabelDayStatus
@onready var progress_fuel: ProgressBar = $HUD/MarginContainer/VBoxContainer/ProgressFuel
@onready var label_wood: Label = $HUD/MarginContainer/VBoxContainer/LabelWood
var inventory_ui: Control = null

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
var bg_sky_day: Sprite2D
var bg_sky_night: Sprite2D
var bg_mountains_far: Sprite2D
var bg_mountains_close: Sprite2D
var bg_forest_back: Sprite2D

var base_sky_day_pos: Vector2
var base_sky_night_pos: Vector2
var base_mountains_far_pos: Vector2
var base_mountains_close_pos: Vector2
var base_forest_back_pos: Vector2

var sun_sprite: Sprite2D
var moon_sprite: Sprite2D
var bg_parallax_ref: ParallaxBackground = null  # кэш ссылки на ParallaxBackground

func _ready() -> void:
	game_over_screen.visible = false
	if is_instance_valid(campfire):
		campfire.connect("burned_out", Callable(self, "_on_campfire_burned_out"))
		campfire.connect("fuel_changed", Callable(self, "_on_campfire_fuel_changed"))
		_on_campfire_fuel_changed(campfire.current_fuel, campfire.max_fuel)
	else:
		progress_fuel.value = 0
		
	# Скрываем текстовый счетчик дерева и находим графический инвентарь на сцене
	if is_instance_valid(label_wood):
		label_wood.visible = false
	inventory_ui = hud.get_node_or_null("InventoryUI")

	player.connect("wood_count_changed", Callable(self, "_on_player_wood_changed"))
	
	if not has_node("CaveLeft") and not has_node("CaveRight"):
		var limits = get_ground_x_limits()
		create_cave_at(limits.x + 80.0, false)
		create_cave_at(limits.y - 80.0, true)
	
	# Начальные значения интерфейса
	_on_player_wood_changed(player.wood_count)
	update_hud_text()
	
	# Настраиваем новый фон с горами
	setup_background()
	
	# (Отключено, чтобы использовать только бродяг, расставленных вручную на сцене)
	# Спавним начальных бродяг поближе к костру на старте игры
	# for i in range(2):
	# 	spawn_vagrant_if_needed()


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
		var ground_y = 0.0
		var campfire_x = 0.0
		if is_instance_valid(campfire):
			ground_y = campfire.global_position.y
			campfire_x = campfire.global_position.x
		elif is_instance_valid(player):
			ground_y = player.global_position.y
			campfire_x = player.global_position.x
			
		# Выбираем случайную координату спавна бродяг в пределах видимости от костра
		var spawn_x = campfire_x + randf_range(-600.0, 600.0)
		
		# Но убедимся, что координаты спавна лежат в пределах реальной земли
		var limits = get_ground_x_limits()
		spawn_x = clamp(spawn_x, limits.x + 100.0, limits.y - 100.0)
		
		var vagrant = vagrant_scene.instantiate()
		add_child(vagrant)
		vagrant.global_position = Vector2(spawn_x, ground_y - 20.0)
		
		# Эффект плавного появления
		vagrant.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(vagrant, "modulate:a", 1.0, 1.0)

func spawn_wolf() -> void:
	# Волки спавнятся по краям карты на реальной земле
	var ground_y = 0.0
	if is_instance_valid(campfire):
		ground_y = campfire.global_position.y
	elif is_instance_valid(player):
		ground_y = player.global_position.y

	var limits = get_ground_x_limits()
	var spawn_side = 1.0 if randf() > 0.5 else -1.0
	var spawn_x = limits.y - 80.0 if spawn_side > 0 else limits.x + 80.0
	
	var cave_name = "CaveRight" if spawn_side > 0 else "CaveLeft"
	var cave = get_node_or_null(cave_name)
	if cave:
		spawn_x = cave.global_position.x
		ground_y = cave.global_position.y
	
	var wolf = wolf_scene.instantiate()
	add_child(wolf)
	wolf.global_position = Vector2(spawn_x, ground_y - 10)
	
	wolf.max_health = 20.0 + current_day * 4.0
	wolf.health = wolf.max_health
	wolf.speed = 90.0 + current_day * 2.0

func spawn_bear() -> void:
	# Медведи спавнятся по краям карты на реальной земле
	var ground_y = 0.0
	if is_instance_valid(campfire):
		ground_y = campfire.global_position.y
	elif is_instance_valid(player):
		ground_y = player.global_position.y

	var limits = get_ground_x_limits()
	var spawn_side = 1.0 if randf() > 0.5 else -1.0
	var spawn_x = limits.y - 80.0 if spawn_side > 0 else limits.x + 80.0
	
	var cave_name = "CaveRight" if spawn_side > 0 else "CaveLeft"
	var cave = get_node_or_null(cave_name)
	if cave:
		spawn_x = cave.global_position.x
		ground_y = cave.global_position.y
	
	var bear = bear_scene.instantiate()
	add_child(bear)
	bear.global_position = Vector2(spawn_x, ground_y - 10)
	
	bear.max_health = 70.0 + current_day * 10.0
	bear.health = bear.max_health
	bear.speed = 40.0 + current_day * 1.5



func create_cave_at(x_pos: float, is_right_side: bool) -> void:
	var cave_node = Node2D.new()
	cave_node.name = "CaveRight" if is_right_side else "CaveLeft"
	
	var ground_y = 0.0
	if is_instance_valid(campfire):
		ground_y = campfire.global_position.y
	elif is_instance_valid(player):
		ground_y = player.global_position.y
		
	cave_node.global_position = Vector2(x_pos, ground_y)
	
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
	if is_instance_valid(label_wood):
		label_wood.text = "Дров у Короля: %d/%d" % [count, player.max_wood_carry]
	if is_instance_valid(inventory_ui):
		inventory_ui.update_wood(count, player.max_wood_carry)

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
		
	# Ищем ParallaxBackground
	var parallax_bg = get_node_or_null("ParallaxBackground")
	if not is_instance_valid(parallax_bg):
		return
	
	# Убедимся, что ParallaxBackground на правильном слое (-100) и поднят на 20px
	parallax_bg.layer = -100
	parallax_bg.offset = Vector2(0, -20)
	parallax_bg.visible = true
	
	# Игнорируем зум камеры, чтобы фон рендерился 1:1 по размерам экрана (как в меню)
	parallax_bg.scroll_ignore_camera_zoom = true
	
	bg_parallax_ref = parallax_bg
	
	# 1. Небо — ТОЧНЫЕ значения из background_bg.tscn (меню)
	var sky_layer = parallax_bg.get_node_or_null("ParallaxLayer")
	if sky_layer:
		sky_layer.motion_scale = Vector2(0.2, 0)   # 0 по Y = небо не сдвигается вертикально
		sky_layer.motion_mirroring = Vector2(1135.345, 0)
		sky_layer.motion_offset = Vector2.ZERO
		
		var nebo = sky_layer.get_node_or_null("Небо")
		if nebo:
			bg_sky_night = nebo
			nebo.region_enabled = false
			nebo.position = Vector2(579.5494, 323.75)     # ТОЧНО как в меню
			nebo.scale = Vector2(1.1824627, 1.2651663)    # ТОЧНО как в меню
			
			var sky_day = sky_layer.get_node_or_null("SkyDay")
			if not sky_day:
				sky_day = Sprite2D.new()
				sky_day.name = "SkyDay"
				sky_day.texture = load("res://assets/textures/небо_день.png")
				sky_layer.add_child(sky_day)
			bg_sky_day = sky_day
			bg_sky_day.region_enabled = false
			bg_sky_day.centered = nebo.centered
			bg_sky_day.position = nebo.position
			bg_sky_day.scale = Vector2(1.108735, 1.2651663)
	
	# 2. ГорыЗадний — ТОЧНЫЕ значения из меню
	var layer_mountains_far = parallax_bg.get_node_or_null("ParallaxLayer5")
	if layer_mountains_far:
		layer_mountains_far.motion_scale = Vector2(0.33, 0)
		layer_mountains_far.motion_mirroring = Vector2(1110.355, 0)
		layer_mountains_far.motion_offset = Vector2.ZERO
		bg_mountains_far = layer_mountains_far.get_node_or_null("ГорыЗадний")
		if bg_mountains_far:
			bg_mountains_far.region_enabled = false
			bg_mountains_far.position = Vector2(561, 384)        # ТОЧНО как в меню
			bg_mountains_far.scale = Vector2(1.1930894, 1.0)     # ТОЧНО как в меню
	
	# 3. Горы — ТОЧНЫЕ значения из меню
	var layer_mountains_close = parallax_bg.get_node_or_null("ParallaxLayer3")
	if layer_mountains_close:
		layer_mountains_close.motion_scale = Vector2(0.4, 0)
		layer_mountains_close.motion_mirroring = Vector2(1150.14, 0)
		layer_mountains_close.motion_offset = Vector2.ZERO
		bg_mountains_close = layer_mountains_close.get_node_or_null("Горы")
		if bg_mountains_close:
			bg_mountains_close.region_enabled = false
			bg_mountains_close.position = Vector2(576, 438.9706)      # ТОЧНО как в меню
			bg_mountains_close.scale = Vector2(1.171922, 1.7901362)   # ТОЧНО как в меню
	
	# 4. ДеревьяЗаднийфон — ТОЧНЫЕ значения из меню
	var layer_forest_back = parallax_bg.get_node_or_null("ParallaxLayer4")
	if layer_forest_back:
		layer_forest_back.motion_scale = Vector2(0.6, 0)
		layer_forest_back.motion_mirroring = Vector2(1150.14, 0)
		layer_forest_back.motion_offset = Vector2.ZERO
		bg_forest_back = layer_forest_back.get_node_or_null("ДеревьяЗаднийфон")
		if bg_forest_back:
			bg_forest_back.region_enabled = false
			bg_forest_back.position = Vector2(580.9025, 539)    # ТОЧНО как в меню
			bg_forest_back.scale = Vector2(1.172677, 1.0)       # ТОЧНО как в меню
	
	# 5. Луна и солнце — управляются скриптом, не движутся с параллаксом
	var moon_layer = parallax_bg.get_node_or_null("ParallaxLayer2")
	if moon_layer:
		moon_layer.motion_scale = Vector2(0, 0)
		moon_layer.motion_offset = Vector2.ZERO
		var moon = moon_layer.get_node_or_null("Луна")
		if moon:
			moon_sprite = moon
		var sun = moon_layer.get_node_or_null("SunSprite")
		if not sun:
			sun = Sprite2D.new()
			sun.name = "SunSprite"
			sun.texture = load("res://assets/textures/sun.png")
			sun.position = moon.position if moon else Vector2.ZERO
			moon_layer.add_child(sun)
		sun_sprite = sun

func update_background_and_celestial(delta: float) -> void:
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
			
	# 2. Плавно перекрестно накладываем видимость неба дня и неба ночи
	if is_instance_valid(bg_sky_day):
		bg_sky_day.modulate.a = 1.0 - transition_factor
	if is_instance_valid(bg_sky_night):
		bg_sky_night.modulate.a = transition_factor
	
	# Если нет ParallaxBackground, двигаем фон вручную (старая система)
	var parallax_bg = bg_parallax_ref
	if not is_instance_valid(parallax_bg):
		if not is_instance_valid(bg_mountains_far) or not is_instance_valid(bg_mountains_close) or not is_instance_valid(bg_forest_back):
			return
			
		var cam_pos = Vector2.ZERO
		var camera = player.get_node_or_null("Camera2D")
		if camera:
			cam_pos = camera.get_screen_center_position()
		else:
			cam_pos = player.global_position
			
		if is_instance_valid(bg_sky_day):
			bg_sky_day.global_position = Vector2(
				cam_pos.x * 0.98 + base_sky_day_pos.x,
				cam_pos.y * 1.0 + base_sky_day_pos.y
			)
		if is_instance_valid(bg_sky_night):
			bg_sky_night.global_position = Vector2(
				cam_pos.x * 0.98 + base_sky_night_pos.x,
				cam_pos.y * 1.0 + base_sky_night_pos.y
			)
		bg_mountains_far.global_position = Vector2(
			cam_pos.x * 0.9 + base_mountains_far_pos.x,
			cam_pos.y * 0.98 + base_mountains_far_pos.y
		)
		bg_mountains_close.global_position = Vector2(
			cam_pos.x * 0.75 + base_mountains_close_pos.x,
			cam_pos.y * 0.95 + base_mountains_close_pos.y
		)
		bg_forest_back.global_position = Vector2(
			cam_pos.x * 0.5 + base_forest_back_pos.x,
			cam_pos.y * 0.9 + base_forest_back_pos.y
		)
	
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



func get_ground_x_limits() -> Vector2:
	var tilemap = get_node_or_null("CanvasModulate/TileMapLayer")
	if tilemap and tilemap is TileMapLayer:
		var cells = tilemap.get_used_cells()
		if cells.size() > 0:
			var min_x = INF
			var max_x = -INF
			for cell in cells:
				var global_cell_x = tilemap.to_global(tilemap.map_to_local(cell)).x
				if global_cell_x < min_x:
					min_x = global_cell_x
				if global_cell_x > max_x:
					max_x = global_cell_x
			return Vector2(min_x, max_x)
	
	# Резервный вариант, если тайлмап пустой или не найден
	if is_instance_valid(campfire):
		return Vector2(campfire.global_position.x - 2000.0, campfire.global_position.x + 2000.0)
	return Vector2(-2000.0, 4000.0)
