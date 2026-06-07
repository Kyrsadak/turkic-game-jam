extends Node2D

const TreeScene = preload("res://scenes/tree/tree.tscn")

@export var tree_count: int = 20
@export var sections_count: int = 5
@export var cooldown_duration: float = 120.0
@export var tree_spacing: float = 32.0

var trees: Array = []
var section_cooldowns: Array = [] # Array of floats (remaining cooldown)
var section_labels: Array = []    # Array of Labels

@onready var trees_container: Node2D = $TreesContainer
@onready var labels_container: Node2D = $LabelsContainer

func _ready() -> void:
	# Инициализируем массивы под секции
	for s in range(sections_count):
		section_cooldowns.append(0.0)
		section_labels.append(null)
	
	# Создаем деревья и метки
	spawn_forest()

func is_forest_biome() -> bool:
	return true

func spawn_forest() -> void:
	# Сначала очистим контейнеры (на всякий случай)
	for child in trees_container.get_children():
		child.queue_free()
	for child in labels_container.get_children():
		child.queue_free()
		
	trees.clear()
	
	# 1. Генерируем 20 деревьев
	for i in range(tree_count):
		var tree_instance = TreeScene.instantiate()
		trees_container.add_child(tree_instance)
		
		# Распределяем симметрично вокруг центра ForestBiome (local x = 0)
		var local_x = (i - (tree_count - 1) / 2.0) * tree_spacing
		# Добавляем небольшую естественную случайность
		local_x += randf_range(-6.0, 6.0)
		var local_y = randf_range(-3.0, 3.0)
		
		tree_instance.position = Vector2(local_x, local_y)
		trees.append(tree_instance)
		
	# 2. Создаем метки кулдауна для каждого сектора
	var trees_per_section = tree_count / sections_count
	
	# Настройки шрифта и обводки для меток
	var label_settings = LabelSettings.new()
	label_settings.font_size = 9
	label_settings.outline_size = 2
	label_settings.outline_color = Color(0, 0, 0, 1)
	
	for s in range(sections_count):
		var label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.label_settings = label_settings
		label.visible = false
		
		# Вычисляем центральную X-позицию для этой секции
		var start_idx = s * trees_per_section
		var end_idx = start_idx + trees_per_section - 1
		var sum_x = 0.0
		for t_idx in range(start_idx, end_idx + 1):
			sum_x += trees[t_idx].position.x
		var center_x = sum_x / trees_per_section
		
		label.position = Vector2(center_x - 50.0, -115.0)
		label.size = Vector2(100.0, 20.0)
		
		labels_container.add_child(label)
		section_labels[s] = label

func _process(delta: float) -> void:
	var trees_per_section = tree_count / sections_count
	
	for s in range(sections_count):
		var start_idx = s * trees_per_section
		var end_idx = start_idx + trees_per_section - 1
		
		# Проверяем, идет ли сейчас кулдаун для этого сектора
		if section_cooldowns[s] > 0.0:
			section_cooldowns[s] -= delta
			var label = section_labels[s]
			if label:
				label.text = "Вырастает: %d с." % int(ceil(section_cooldowns[s]))
				
			if section_cooldowns[s] <= 0.0:
				# Кулдаун завершен, регенерируем все деревья сектора
				section_cooldowns[s] = 0.0
				if label:
					label.visible = false
				for t_idx in range(start_idx, end_idx + 1):
					if is_instance_valid(trees[t_idx]):
						trees[t_idx].regrow()
		else:
			# Проверяем, не срублены ли все деревья в секторе
			var all_felled = true
			for t_idx in range(start_idx, end_idx + 1):
				if is_instance_valid(trees[t_idx]) and not trees[t_idx].is_felled:
					all_felled = false
					break
			
			if all_felled:
				# Запускаем перезарядку сектора
				section_cooldowns[s] = cooldown_duration
				var label = section_labels[s]
				if label:
					label.visible = true
					label.text = "Вырастает: %d с." % int(ceil(cooldown_duration))
