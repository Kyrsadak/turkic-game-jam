extends ParallaxBackground

var speed_scene = 100

@export var moon_speed: float = 35.0
var moon_x: float = -63.0

@onready var moon: Sprite2D = get_node_or_null("ParallaxLayer2/Луна")

func _ready() -> void:
	# Отключаем автоматический параллакс для слоя луны, так как мы управляем ею вручную
	var layer2 = get_node_or_null("ParallaxLayer2")
	if layer2:
		layer2.motion_scale = Vector2.ZERO
	
	# Начинаем с точной позиции из редактора (-63.0)
	moon_x = -63.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	scroll_base_offset.x -= speed_scene * delta
	
	# Движение луны по параболе (арке)
	if moon:
		moon_x += moon_speed * delta
		if moon_x > 1300.0:
			moon_x = -63.0 # Сброс к начальной координате из редактора
			
		# Вычисляем Y по параболе: y = a * (x - h)^2 + k
		# Чтобы траектория проходила ровно через точку (-63, 466) при пике в (576, 100):
		# a = (466 - 100) / (-63 - 576)^2 = 366 / 408321 ≈ 0.0008964
		var h = 576.0 # середина экрана по X
		var k = 100.0 # пик высоты по Y
		var a = 0.0008964
		var moon_y = a * pow(moon_x - h, 2) + k
		
		moon.position = Vector2(moon_x, moon_y)
