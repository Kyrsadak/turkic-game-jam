extends StaticBody2D

@export var build_cost: int = 4
@export var lvl2_cost: int = 8
@export var lvl3_cost: int = 12

var current_construction_wood: int = 0
var level: int = 0 # 0 = не построена, 1 = дерево, 2 = камень, 3 = шипы
var max_health: float = 80.0
var health: float = 80.0

@onready var label_status: Label = $LabelStatus
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_site: Node2D = $VisualSite
@onready var visual_lvl1: Node2D = $VisualLvl1
@onready var visual_lvl2: Node2D = $VisualLvl2
@onready var visual_lvl3: Node2D = $VisualLvl3

func _ready() -> void:
	add_to_group("buildings")
	add_to_group("wall")
	update_visuals()

func _process(delta: float) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var dist = global_position.distance_to(player.global_position)
		if dist < 60.0:
			label_status.visible = true
			if level == 0:
				if player.wood_count > 0:
					label_status.text = "Деревянная стена [E]\nПостройка (%d/%d дров)" % [current_construction_wood, build_cost]
				else:
					label_status.text = "Стена (Требуется %d дров)\nНужны дрова" % build_cost
			else:
				# Проверяем прочность
				if health < max_health:
					if player.wood_count > 0:
						label_status.text = "Починить стену [E]\nПрочность: %d/%d" % [int(health), int(max_health)]
					else:
						label_status.text = "Стена повреждена!\nПрочность: %d/%d" % [int(health), int(max_health)]
				elif level == 1:
					if player.wood_count > 0:
						label_status.text = "Каменное улучшение [E]\nСтоимость (%d/%d дров)" % [current_construction_wood, lvl2_cost]
					else:
						label_status.text = "Каменная стена\nНужно %d дров для улучшения" % lvl2_cost
				elif level == 2:
					if player.wood_count > 0:
						label_status.text = "Шипастое улучшение [E]\nСтоимость (%d/%d дров)" % [current_construction_wood, lvl3_cost]
					else:
						label_status.text = "Шипастая стена\nНужно %d дров для улучшения" % lvl3_cost
				elif level == 3:
					label_status.text = "Шипастая стена (макс.)\nПрочность: %d/%d" % [int(health), int(max_health)]
		else:
			label_status.visible = false

func deposit_wood() -> bool:
	# Если стена повреждена — чиним за 1 дерево (+30 HP)
	if level > 0 and health < max_health:
		health = min(health + 30.0, max_health)
		
		# Вспышка зеленого цвета при починке
		var tween = create_tween()
		var current_vis = get_current_visual()
		if current_vis:
			current_vis.modulate = Color(0.6, 1.0, 0.6)
			tween.tween_property(current_vis, "modulate", Color(1, 1, 1), 0.2)
		return true
		
	# Если цела — улучшаем
	if level == 3:
		return false
		
	var target_cost = build_cost if level == 0 else (lvl2_cost if level == 1 else lvl3_cost)
	
	if current_construction_wood < target_cost:
		current_construction_wood += 1
		if current_construction_wood >= target_cost:
			upgrade_wall()
		return true
		
	return false

func upgrade_wall() -> void:
	level += 1
	current_construction_wood = 0
	
	if level == 1:
		max_health = 90.0
		health = max_health
	elif level == 2:
		max_health = 220.0
		health = max_health
	elif level == 3:
		max_health = 450.0
		health = max_health
		
	update_visuals()
	
	# Подпрыгивание при улучшении
	var current_vis = get_current_visual()
	if current_vis:
		var tween = create_tween()
		current_vis.scale = Vector2(1.2, 0.8)
		tween.tween_property(current_vis, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE)

func take_damage(amount: float) -> void:
	if level == 0:
		return
		
	health -= amount
	
	# Вспышка красного
	var current_vis = get_current_visual()
	if current_vis:
		var tween = create_tween()
		current_vis.modulate = Color(1.0, 0.4, 0.4)
		tween.tween_property(current_vis, "modulate", Color(1, 1, 1), 0.15)
		
		# Тряска стены при ударе
		var shake_tween = create_tween()
		shake_tween.tween_property(current_vis, "position:x", 3.0, 0.04)
		shake_tween.tween_property(current_vis, "position:x", -3.0, 0.04)
		shake_tween.tween_property(current_vis, "position:x", 0.0, 0.04)
		
	if health <= 0:
		destroy_wall()

func destroy_wall() -> void:
	level = 0
	health = 0
	current_construction_wood = 0
	update_visuals()

func update_visuals() -> void:
	# Коллизия включена только если стена построена
	collision_shape.disabled = (level == 0)
	visual_site.visible = (level == 0)
	visual_lvl1.visible = (level == 1)
	visual_lvl2.visible = (level == 2)
	visual_lvl3.visible = (level == 3)

func get_current_visual() -> Node2D:
	if level == 1: return visual_lvl1
	if level == 2: return visual_lvl2
	if level == 3: return visual_lvl3
	return null
