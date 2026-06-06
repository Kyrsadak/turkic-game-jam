extends Node2D

# Ссылка на главный узел для получения is_day и time_in_state
var main_node: Node = null

# Спрайты слоёв
@onready var sky: Sprite2D = $SkyLayer/Небо
@onready var mountains_back: Sprite2D = $MountainsBackLayer/ГорыЗадний
@onready var mountains_front: Sprite2D = $MountainsFrontLayer/Горы
@onready var trees_bg: Sprite2D = $TreesLayer/ДеревьяЗаднийфон
@onready var moon_sprite: Sprite2D = $MoonLayer/Луна

# Вертикальные позиции каждого слоя (от горизонта земли = 0)
const SKY_Y: float = -270.0
const MOUNTAINS_BACK_Y: float = -130.0
const MOUNTAINS_FRONT_Y: float = -80.0
const TREES_Y: float = -40.0

# Коэффициенты параллакса (насколько медленнее слой движется, чем камера)
const SKY_PARALLAX: float = 0.05
const MOUNTAINS_BACK_PARALLAX: float = 0.15
const MOUNTAINS_FRONT_PARALLAX: float = 0.25
const TREES_PARALLAX: float = 0.4

# Отслеживаем предыдущую X позицию игрока
var last_player_x: float = 0.0

# Смещения слоёв (тайлинг)
var sky_offset: float = 0.0
var mountains_back_offset: float = 0.0
var mountains_front_offset: float = 0.0
var trees_offset: float = 0.0
const TILE_WIDTH: float = 1150.0

# Состояние луны
var is_night_active: bool = false

func _ready() -> void:
	# Ищем главный узел
	main_node = get_parent()
	
	last_player_x = _get_player_x()
	
	# Ставим вертикальные позиции
	sky.position.y = SKY_Y
	mountains_back.position.y = MOUNTAINS_BACK_Y
	mountains_front.position.y = MOUNTAINS_FRONT_Y
	trees_bg.position.y = TREES_Y
	moon_sprite.visible = false

func _process(delta: float) -> void:
	var player_x = _get_player_x()
	var move_delta = player_x - last_player_x
	last_player_x = player_x

	# Сдвигаем каждый слой на свою долю от движения игрока
	sky_offset -= move_delta * SKY_PARALLAX
	mountains_back_offset -= move_delta * MOUNTAINS_BACK_PARALLAX
	mountains_front_offset -= move_delta * MOUNTAINS_FRONT_PARALLAX
	trees_offset -= move_delta * TREES_PARALLAX

	# Бесшовный тайлинг — зацикливаем смещения
	sky_offset = fposmod(sky_offset, TILE_WIDTH)
	mountains_back_offset = fposmod(mountains_back_offset, TILE_WIDTH)
	mountains_front_offset = fposmod(mountains_front_offset, TILE_WIDTH)
	trees_offset = fposmod(trees_offset, TILE_WIDTH)

	# Устанавливаем X позиции слоёв в мировых координатах
	# Привязываем фон к камере: позиция = позиция игрока + параллакс смещение
	# Спрайты с texture_repeat=2 будут бесконечно тайлиться
	sky.position.x = player_x + sky_offset - TILE_WIDTH / 2.0
	mountains_back.position.x = player_x + mountains_back_offset - TILE_WIDTH / 2.0
	mountains_front.position.x = player_x + mountains_front_offset - TILE_WIDTH / 2.0
	trees_bg.position.x = player_x + trees_offset - TILE_WIDTH / 2.0

	# Анимация луны — привязана к таймеру ночи из main
	_update_moon()

func _update_moon() -> void:
	if not main_node:
		return

	var currently_night = main_node.get("is_day") == false
	var night_time: float = main_node.get("time_in_state") if main_node.get("time_in_state") != null else 0.0
	var night_duration: float = main_node.get("night_duration") if main_node.get("night_duration") != null else 75.0

	if currently_night:
		if not is_night_active:
			is_night_active = true
			moon_sprite.visible = true

		# Прогресс 0.0 = восход слева, 1.0 = закат справа
		var t = clamp(night_time / night_duration, 0.0, 1.0)

		# Экранные координаты луны (по ширине 1152 пикселя, как в viewport)
		var screen_width = 1152.0
		var screen_height = 648.0

		var moon_screen_x = t * (screen_width + 200.0) - 100.0
		var h = screen_width / 2.0
		var k = -screen_height * 0.55 # пик — примерно середина экрана по высоте
		var base_y = -screen_height * 0.05 # линия горизонта снизу
		var a = (base_y - k) / pow(h, 2)
		var moon_screen_y = a * pow(moon_screen_x - h, 2) + k

		# Переводим в мировые координаты (камера смотрит на игрока)
		var player_x = _get_player_x()
		moon_sprite.position = Vector2(
			player_x - h + moon_screen_x,
			moon_screen_y
		)
	else:
		if is_night_active:
			is_night_active = false
			moon_sprite.visible = false

func _get_player_x() -> float:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node2D:
		return (players[0] as Node2D).global_position.x
	return 0.0
