extends StaticBody2D
const TextureLoader = preload("res://scenes/texture_loader.gd")

@export var build_cost: int = 5
@export var shoot_cooldown: float = 1.5
@export var attack_range: float = 350.0

var is_built: bool = false
var current_construction_wood: int = 0
var shoot_timer: float = 0.0

@onready var label_status: Label = $LabelStatus
@onready var visual_site: Node2D = $VisualSite
@onready var visual_built: Node2D = $VisualBuilt
@onready var range_area: Area2D = $RangeArea
@onready var range_collision: CollisionShape2D = $RangeArea/CollisionShape2D

var arrow_scene = preload("res://scenes/buildings/arrow.tscn")

func _ready() -> void:
	add_to_group("buildings")
	add_to_group("archer_tower")
	
	# Set range collision radius dynamically
	if range_collision and range_collision.shape is CircleShape2D:
		range_collision.shape.radius = attack_range
		
	update_visuals()
	setup_tooltip_style(label_status)

func _process(delta: float) -> void:
	# Show tooltip to player when close
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var dist = global_position.distance_to(player.global_position)
		if dist < 55.0:
			label_status.visible = true
			if not is_built:
				if player.wood_count > 0:
					label_status.text = "[E] Построить башню лучников (%d/%d)" % [current_construction_wood, build_cost]
				else:
					label_status.text = "Башня лучников (%d/%d дров)" % [current_construction_wood, build_cost]
			else:
				label_status.text = "Башня лучников"
		else:
			label_status.visible = false

	# shooting logic
	if is_built:
		shoot_timer -= delta
		if shoot_timer <= 0:
			var target = find_target()
			if target:
				shoot_at(target)
				shoot_timer = shoot_cooldown

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
	return false

func find_target() -> Node2D:
	var bodies = range_area.get_overlapping_bodies()
	var closest: Node2D = null
	var min_dist: float = 999999.0
	for body in bodies:
		if body.is_in_group("enemy") and not body.is_dead:
			var dist = global_position.distance_to(body.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = body
	return closest

func shoot_at(target: Node2D) -> void:
	var arrow = arrow_scene.instantiate()
	get_parent().add_child(arrow)
	# Spawn from the top of the tower
	var spawn_pos = global_position + Vector2(0, -60)
	arrow.launch(spawn_pos, target)

func update_visuals() -> void:
	visual_site.visible = not is_built
	visual_built.visible = is_built
	
	if is_built:
		var sprite = TextureLoader.try_apply_texture(self, "res://assets/textures/archer_tower.png", Vector2(0, -55))
		if sprite:
			visual_built.visible = false

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
