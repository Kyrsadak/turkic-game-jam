extends StaticBody2D
const TextureLoader = preload("res://scenes/texture_loader.gd")

@export var build_cost: int = 4
@export var lvl2_cost: int = 8
@export var lvl3_cost: int = 12

var current_construction_wood: int = 0
var level: int = 0 # 0 = не построена, 1 = дерево, 2 = камень, 3 = шипы
var max_health: float = 120.0
var health: float = 120.0

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
	setup_tooltip_style(label_status)

func _process(delta: float) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var dist = global_position.distance_to(player.global_position)
		if dist < 55.0:
			label_status.visible = true
			if level == 0:
				if player.wood_count > 0:
					label_status.text = "[E] Построить стену (%d/%d)" % [current_construction_wood, build_cost]
				else:
					label_status.text = "Стена (Нужно %d дров)" % build_cost
			else:
				# Проверяем прочность
				if health < max_health:
					if player.wood_count > 0:
						label_status.text = "[E] Починить (HP: %d/%d)" % [int(health), int(max_health)]
					else:
						label_status.text = "Повреждена (HP: %d/%d)" % [int(health), int(max_health)]
				elif level == 1:
					if player.wood_count > 0:
						label_status.text = "[E] Каменное улучшение (%d/%d)" % [current_construction_wood, lvl2_cost]
					else:
						label_status.text = "Каменная стена (Нужно %d дров)" % lvl2_cost
				elif level == 2:
					if player.wood_count > 0:
						label_status.text = "[E] Шипастое улучшение (%d/%d)" % [current_construction_wood, lvl3_cost]
					else:
						label_status.text = "Шипастая стена (Нужно %d дров)" % lvl3_cost
				elif level == 3:
					label_status.text = "Шипастая стена (HP: %d/%d)" % [int(health), int(max_health)]
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
		max_health = 120.0
		health = max_health
	elif level == 2:
		max_health = 300.0
		health = max_health
	elif level == 3:
		max_health = 600.0
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
		
		# Тряска камеры при ударе по стене (зависит от близости игрока)
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var p = players[0]
			var dist = global_position.distance_to(p.global_position)
			if dist < 400.0:
				p.apply_camera_shake(remap(dist, 0.0, 400.0, 3.0, 0.5))
		
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
	
	# Проверяем текстуру для текущего уровня стены
	var texture_name = "wall_lvl" + str(level) + ".png"
	if level == 0:
		texture_name = "wall_construction.png"
	
	var path = "res://assets/textures/" + texture_name
	var sprite = TextureLoader.try_apply_texture(self, path, Vector2(0, -30))
	if sprite:
		visual_site.visible = false
		visual_lvl1.visible = false
		visual_lvl2.visible = false
		visual_lvl3.visible = false

func get_current_visual() -> Node2D:
	if level == 1: return visual_lvl1
	if level == 2: return visual_lvl2
	if level == 3: return visual_lvl3
	return null

func setup_tooltip_style(label: Label) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.45, 0.55, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	label.add_theme_stylebox_override("normal", style)
