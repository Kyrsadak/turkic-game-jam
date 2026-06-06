extends Node2D

func _ready() -> void:
	# Подключаем сигнал наведения мыши к кнопке Quit
	$Quit.mouse_entered.connect(_on_quit_mouse_entered)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_quit_pressed() -> void:
	# Если игрок всё-таки смог нажать (например, с клавиатуры) — выходим из игры!
	get_tree().quit()

func _on_quit_mouse_entered() -> void:
	var viewport_size = get_viewport_rect().size
	var btn_size = $Quit.size
	
	# Получаем область кнопки Play
	var play_rect = $Play.get_global_rect()
	
	# Будущие координаты
	var new_x = $Quit.position.x
	var new_y = $Quit.position.y
	
	# 100 попыток найти свободное место без наложения на Play
	for i in range(100):
		var temp_x = randf_range(10, viewport_size.x - btn_size.x - 10)
		var temp_y = randf_range(10, viewport_size.y - btn_size.y - 10)
		
		var quit_rect = Rect2(temp_x, temp_y, btn_size.x, btn_size.y)
		
		# Если не пересекается с кнопкой Play, выбираем эту позицию
		if not quit_rect.intersects(play_rect):
			new_x = temp_x
			new_y = temp_y
			break
			
	# Перемещаем кнопку
	$Quit.position = Vector2(new_x, new_y)
