extends StaticBody2D

@export var build_cost: int = 8

var is_built: bool = false
var current_construction_wood: int = 0

@onready var label_status: Label = $LabelStatus
@onready var visual_site: Node2D = $VisualSite
@onready var visual_built: Node2D = $VisualBuilt

var spearman_scene = preload("res://scenes/units/spearman.tscn")

func _ready() -> void:
	add_to_group("buildings")
	add_to_group("barracks")
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
					label_status.text = "[E] Построить казарму (%d/%d)" % [current_construction_wood, build_cost]
				else:
					label_status.text = "Казарма (%d/%d дров)" % [current_construction_wood, build_cost]
			else:
				var follow_citizen = get_closest_citizen(120.0)
				if follow_citizen:
					label_status.text = "[E] Обучить копейщика"
				else:
					label_status.text = "Казарма (%d воинов)" % get_spearmen_count()
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
	
	var tween = create_tween()
	visual_built.scale = Vector2(1.2, 0.8)
	tween.tween_property(visual_built, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BOUNCE)

func interact(player: Node2D) -> bool:
	if not is_built:
		return false
		
	var follow_citizen = get_closest_citizen(120.0)
	if follow_citizen:
		follow_citizen.queue_free()
		spawn_spearman()
		return true
		
	return false

func spawn_spearman() -> void:
	var sm = spearman_scene.instantiate()
	get_parent().add_child(sm)
	sm.global_position = global_position + Vector2(0, -10)
	
	# Эффект спавна
	var tween = create_tween()
	sm.scale = Vector2(0.5, 1.5)
	tween.tween_property(sm, "scale", Vector2(1.0, 1.0), 0.2)

func update_visuals() -> void:
	visual_site.visible = not is_built
	visual_built.visible = is_built

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

func get_spearmen_count() -> int:
	var count = 0
	var sm_nodes = get_tree().get_nodes_in_group("spearman")
	# Подсчитываем тех копейщиков, что привязаны к этой казарме или просто всех
	return sm_nodes.size()

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
