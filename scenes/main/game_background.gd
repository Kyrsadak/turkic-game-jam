extends Node2D

# Ссылка на главный узел для получения is_day и time_in_state
var main_node: Node = null

# Спрайты слоёв
@onready var sky: Sprite2D = $SkyLayer/Небо
@onready var mountains_back: Sprite2D = $MountainsBackLayer/ГорыЗадний
@onready var mountains_front: Sprite2D = $MountainsFrontLayer/Горы
@onready var trees_bg: Sprite2D = $TreesLayer/ДеревьяЗаднийфон
@onready var moon_sprite: Sprite2D = $MoonLayer/Луна

# Вертикальные позиции каждого слоя относительно земли (y=0)
const SKY_Y: float = -260.0
const MOUNTAINS_BACK_Y: float = -120.0
const MOUNTAINS_FRONT_Y: float = -65.0
const TREES_Y: float = -30.0

# Коэффициенты параллакса:
# 0 = слой не двигается совсем, 1 = слой движется как игрок
const SKY_PARALLAX: float = 0.05
const MOUNTAINS_BACK_PARALLAX: float = 0.15
const MOUNTAINS_FRONT_PARALLAX: float = 0.25
const TREES_PARALLAX: float = 0.40

# Ширина одного тайла каждого слоя (реальный размер текстуры в пикселях * scale)
# Текстуры ~1152px, scale=1.0 в tscn — подбираем точный тайл-шаг
const TILE_WIDTH: float = 1152.0

# Смещения каждого слоя накапливаются неограниченно (нет fposmod!)
# Спрайт сам бесшовно тайлится (texture_repeat=2) — нам нужна только его X позиция
var sky_scroll: float = 0.0
var mtn_back_scroll: float = 0.0
var mtn_front_scroll: float = 0.0
var trees_scroll: float = 0.0

# Предыдущий X игрока
var last_player_x: float = 0.0

# Луна
var is_night_active: bool = false

func _ready() -> void:
	main_node = get_parent()
	last_player_x = _get_player_x()

	# Вертикальные позиции — фиксированные
	sky.position.y = SKY_Y
	mountains_back.position.y = MOUNTAINS_BACK_Y
	mountains_front.position.y = MOUNTAINS_FRONT_Y
	trees_bg.position.y = TREES_Y
	moon_sprite.visible = false

func _process(_delta: float) -> void:
	var player_x = _get_player_x()
	var dx = player_x - last_player_x
	last_player_x = player_x

	# Каждый слой накапливает своё собственное смещение (без fposmod — без прыжков!)
	sky_scroll        -= dx * SKY_PARALLAX
	mtn_back_scroll   -= dx * MOUNTAINS_BACK_PARALLAX
	mtn_front_scroll  -= dx * MOUNTAINS_FRONT_PARALLAX
	trees_scroll      -= dx * TREES_PARALLAX

	# Позиция спрайта = текущий скролл (в мировых координатах)
	# Спрайт стоит в origin мира и тайлится автоматически по texture_repeat
	# Центрируем по X относительно игрока + параллакс смещение
	sky.position.x        = player_x + sky_scroll
	mountains_back.position.x = player_x + mtn_back_scroll
	mountains_front.position.x = player_x + mtn_front_scroll
	trees_bg.position.x   = player_x + trees_scroll

	_update_moon()

func _update_moon() -> void:
	if not main_node:
		return

	var currently_night: bool = main_node.get("is_day") == false
	var night_time: float = main_node.get("time_in_state") if main_node.get("time_in_state") != null else 0.0
	var night_duration: float = main_node.get("night_duration") if main_node.get("night_duration") != null else 75.0

	if currently_night:
		if not is_night_active:
			is_night_active = true
			moon_sprite.visible = true

		var t: float = clamp(night_time / night_duration, 0.0, 1.0)
		var screen_w: float = 1152.0
		var screen_h: float = 648.0

		# Луна проходит от (-100) до (screen_w+100) по экрану
		var mx: float = t * (screen_w + 200.0) - 100.0
		var h: float  = screen_w / 2.0
		var peak_y: float = -screen_h * 0.55
		var base_y: float = -screen_h * 0.05
		var a: float = (base_y - peak_y) / pow(h, 2)
		var my: float = a * pow(mx - h, 2) + peak_y

		var player_x = _get_player_x()
		moon_sprite.position = Vector2(player_x - h + mx, my)
	else:
		if is_night_active:
			is_night_active = false
			moon_sprite.visible = false

func _get_player_x() -> float:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node2D:
		return (players[0] as Node2D).global_position.x
	return 0.0
