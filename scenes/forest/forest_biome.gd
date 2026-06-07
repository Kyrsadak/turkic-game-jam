extends Node2D

@export var cooldown_duration: float = 120.0

var trees: Array = []
var section_cooldowns: Array = [] # Array of floats (remaining cooldown)
var section_labels: Array = []    # Array of Labels
var sections_count: int = 5

@onready var trees_container: Node2D = $TreesContainer
@onready var labels_container: Node2D = $LabelsContainer

func _ready() -> void:
	# Инициализируем массивы под секции
	for s in range(sections_count):
		section_cooldowns.append(0.0)
		section_labels.append(null)
	
	# Получаем список заранее размещенных деревьев из сцены
	for child in trees_container.get_children():
		trees.append(child)
		
	# Сортируем деревья по X-координате, чтобы секции шли слева направо
	trees.sort_custom(func(a, b): return a.position.x < b.position.x)
	
	# Создаем метки кулдауна для каждого сектора
	setup_labels()

func is_forest_biome() -> bool:
	return true

func setup_labels() -> void:
	# Очистим старые метки, если они были
	for child in labels_container.get_children():
		child.queue_free()
		
	var tree_count = trees.size()
	if tree_count == 0:
		return
		
	var trees_per_section = tree_count / sections_count
	if trees_per_section == 0:
		trees_per_section = 1
	
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
		var end_idx = min(start_idx + trees_per_section - 1, tree_count - 1)
		var sum_x = 0.0
		var count = 0
		for t_idx in range(start_idx, end_idx + 1):
			sum_x += trees[t_idx].position.x
			count += 1
		var center_x = sum_x / count
		
		label.position = Vector2(center_x - 50.0, -115.0)
		label.size = Vector2(100.0, 20.0)
		
		labels_container.add_child(label)
		section_labels[s] = label

func _process(delta: float) -> void:
	var tree_count = trees.size()
	if tree_count == 0:
		return
		
	var trees_per_section = tree_count / sections_count
	if trees_per_section == 0:
		trees_per_section = 1
	
	for s in range(sections_count):
		var start_idx = s * trees_per_section
		var end_idx = min(start_idx + trees_per_section - 1, tree_count - 1)
		
		if section_cooldowns[s] > 0.0:
			section_cooldowns[s] -= delta
			var label = section_labels[s]
			if label:
				label.text = "Вырастает: %d с." % int(ceil(section_cooldowns[s]))
				
			if section_cooldowns[s] <= 0.0:
				section_cooldowns[s] = 0.0
				if label:
					label.visible = false
				for t_idx in range(start_idx, end_idx + 1):
					if is_instance_valid(trees[t_idx]):
						trees[t_idx].regrow()
		else:
			var all_felled = true
			for t_idx in range(start_idx, end_idx + 1):
				if is_instance_valid(trees[t_idx]) and not trees[t_idx].is_felled:
					all_felled = false
					break
			
			if all_felled:
				section_cooldowns[s] = cooldown_duration
				var label = section_labels[s]
				if label:
					label.visible = true
					label.text = "Вырастает: %d с." % int(ceil(cooldown_duration))
