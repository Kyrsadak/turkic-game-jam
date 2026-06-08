extends StaticBody2D
const TextureLoader = preload("res://scenes/texture_loader.gd")

@export var build_cost: int = 5
@export var max_storage: int = 20

var is_built: bool = false
var current_construction_wood: int = 0
var wood_stored: int = 0

@onready var label_status: Label = $LabelStatus
@onready var visual_site: Node2D = $VisualSite
@onready var visual_built: Node2D = $VisualBuilt
@onready var storage_node: Node2D = $VisualBuilt/Storage

var lumberjack_scene = preload("res://scenes/units/lumberjack.tscn")

func _ready() -> void:
	add_to_group("buildings")
	add_to_group("lumberjack_house")
	update_visuals()
	setup_tooltip_style(label_status)

func _process(delta: float) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var dist = global_position.distance_to(player.global_position)
		if dist < 55.0:
			label_status.visible = true
			if not is_built:
				if player.wood_count > 0:
					label_status.text = "[E] Построить дом лесоруба (%d/%d)" % [current_construction_wood, build_cost]
				else:
					label_status.text = "Дом лесоруба (%d/%d дров)" % [current_construction_wood, build_cost]
			else:
				var follow_citizen = get_closest_citizen(120.0)
				if wood_stored > 0 and player.wood_count < player.max_wood_carry:
					label_status.text = "[E] Забрать дрова (%d/%d)" % [wood_stored, max_storage]
				elif follow_citizen:
					label_status.text = "[E] Обучить лесоруба"
				else:
					label_status.text = "Дом лесоруба (Склад: %d/%d)" % [wood_stored, max_storage]
		else:
			label_status.visible = false

func deposit_wood() -> bool:
	if is_built:
		return false
		
	if current_construction_wood < build_cost:
		current_construction_wood += 1
		update_visuals()
		if current_construction_wood >= build_cost:
			complete_construction()
		return true
	return false

func complete_construction() -> void:
	is_built = true
	update_visuals()
	
	# Эффект постройки
	var tween = create_tween()
	visual_built.scale = Vector2(1.2, 0.8)
	tween.tween_property(visual_built, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BOUNCE)

func interact(player: Node2D) -> bool:
	if not is_built:
		return false
		
	# 1. Сначала отдаем дрова игроку, если есть
	if wood_stored > 0 and player.wood_count < player.max_wood_carry:
		if player.add_wood(1):
			wood_stored -= 1
			update_storage_visuals()
			return true
			
	# 2. Если дров нет или у игрока полные руки, обучаем гражданина
	var follow_citizen = get_closest_citizen(120.0)
	if follow_citizen:
		follow_citizen.queue_free()
		spawn_lumberjack()
		return true
		
	return false

func spawn_lumberjack() -> void:
	var lj = lumberjack_scene.instantiate()
	get_parent().add_child(lj)
	lj.global_position = global_position + Vector2(0, -10)
	lj.home_house = self
	
	# Эффект спавна
	var tween = create_tween()
	lj.scale = Vector2(0.5, 1.5) * 1.12
	tween.tween_property(lj, "scale", Vector2(1.12, 1.12), 0.2)

func add_wood(amount: int = 1) -> bool:
	if wood_stored < max_storage:
		wood_stored = min(wood_stored + amount, max_storage)
		update_storage_visuals()
		return true
	return false

func update_visuals() -> void:
	visual_site.visible = not is_built
	visual_built.visible = is_built
	update_storage_visuals()
	
	if is_built:
		var sprite = TextureLoader.try_apply_texture(self, "res://assets/textures/lumberjack_house.png", Vector2(0, -108))
		if sprite:
			visual_built.visible = false
		label_status.position.y = -240.0
	else:
		label_status.position.y = -65.0

func update_storage_visuals() -> void:
	if not is_built:
		return
	var logs = storage_node.get_children()
	for i in range(logs.size()):
		logs[i].visible = i < wood_stored

func get_closest_citizen(max_dist: float) -> Node2D:
	var citizens = get_tree().get_nodes_in_group("citizen")
	var closest: Node2D = null
	var min_dist: float = max_dist
	for cit in citizens:
		if is_instance_valid(cit) and cit.is_hired:
			var dist = global_position.distance_to(cit.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = cit
	return closest

func setup_tooltip_style(label: Label) -> void:
	var style = StyleBoxEmpty.new()
	label.add_theme_stylebox_override("normal", style)
