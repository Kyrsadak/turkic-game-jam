extends CharacterBody2D
const TextureLoader = preload("res://scenes/texture_loader.gd")

enum State { IDLE, WALKING_TO_WOOD, WALKING_TO_SITE, BUILDING }

@export var speed: float = 80.0
@export var build_cooldown: float = 1.0

var gravity: float = 900.0
var wood_count: int = 0
var max_wood_carry: int = 1
var current_state: State = State.IDLE

var target_wood_source: Node2D = null
var target_site: Node2D = null
var build_timer: float = 0.0
var wander_timer: float = 0.0
var wander_target_x: float = 0.0

@onready var body: Node2D = $Body
@onready var hammer: Node2D = $Body/Hammer
@onready var wood_pile: Node2D = $WoodPile

func _ready() -> void:
	scale = Vector2(1.4, 1.4)
	add_to_group("builder")
	update_wood_visuals()
	choose_wander_target()
	body.position.y = 6.0
	TextureLoader.try_apply_texture(self, "res://assets/textures/builder.png", Vector2(0, -14))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	match current_state:
		State.IDLE:
			# Ищем задачи для постройки
			var site = find_closest_construction_site()
			if site:
				target_site = site
				if wood_count > 0:
					current_state = State.WALKING_TO_SITE
				else:
					current_state = State.WALKING_TO_WOOD
			else:
				# Если строить нечего — праздно шатаемся у костра
				wander_timer -= delta
				if wander_timer <= 0:
					choose_wander_target()
				
				var dist_x = wander_target_x - global_position.x
				if abs(dist_x) > 15.0:
					velocity.x = sign(dist_x) * speed * 0.7
					body.scale.x = sign(dist_x)
					animate_walk()
				else:
					velocity.x = move_toward(velocity.x, 0, speed * 0.35)
					body.scale.y = 1.0

		State.WALKING_TO_WOOD:
			# Проверяем, не нашел ли уже дерево на земле
			if wood_count >= max_wood_carry:
				current_state = State.WALKING_TO_SITE
				return
				
			# Ищем ближайший источник дерева
			if not is_instance_valid(target_wood_source):
				target_wood_source = find_closest_wood_source()
				
			if is_instance_valid(target_wood_source):
				var dist_x = target_wood_source.global_position.x - global_position.x
				if abs(dist_x) > 15.0:
					velocity.x = sign(dist_x) * speed
					body.scale.x = sign(dist_x)
					animate_walk()
				else:
					velocity.x = 0
					# Если дошли до дома лесоруба, забираем дерево
					if target_wood_source.is_in_group("lumberjack_house"):
						if target_wood_source.wood_stored > 0:
							target_wood_source.wood_stored -= 1
							target_wood_source.update_storage_visuals()
							add_wood(1)
							current_state = State.WALKING_TO_SITE
						else:
							target_wood_source = null
			else:
				# Источников дерева нет, возвращаемся в IDLE
				velocity.x = move_toward(velocity.x, 0, speed * 0.3)
				current_state = State.IDLE

		State.WALKING_TO_SITE:
			if wood_count == 0:
				current_state = State.WALKING_TO_WOOD
				return
				
			if not is_instance_valid(target_site) or target_site.is_built:
				target_site = find_closest_construction_site()
				
			if is_instance_valid(target_site):
				var dist_x = target_site.global_position.x - global_position.x
				if abs(dist_x) > 35.0:
					velocity.x = sign(dist_x) * speed
					body.scale.x = sign(dist_x)
					animate_walk()
				else:
					velocity.x = 0
					current_state = State.BUILDING
					build_timer = 0.5
			else:
				current_state = State.IDLE

		State.BUILDING:
			if wood_count == 0:
				current_state = State.WALKING_TO_WOOD
				return
				
			if not is_instance_valid(target_site) or target_site.is_built:
				current_state = State.IDLE
				return
				
			velocity.x = 0
			build_timer -= delta
			if build_timer <= 0:
				hammer_site()
				build_timer = build_cooldown

	move_and_slide()

func hammer_site() -> void:
	if is_instance_valid(target_site) and wood_count > 0:
		if target_site.has_method("deposit_wood"):
			if target_site.deposit_wood():
				wood_count -= 1
				update_wood_visuals()
				
				# Анимация удара молотка
				var tween = create_tween()
				hammer.rotation = -0.6
				tween.tween_property(hammer, "rotation", 1.0, 0.1)
				tween.tween_property(hammer, "rotation", 0.0, 0.15)
				
				# Покачивание строителя при строительстве
				var tween_body = create_tween()
				tween_body.tween_property(body, "scale:y", 0.85, 0.05)
				tween_body.tween_property(body, "scale:y", 1.0, 0.1)
				
				if wood_count == 0:
					current_state = State.WALKING_TO_WOOD
				elif target_site.is_built:
					current_state = State.IDLE

func add_wood(amount: int = 1) -> bool:
	if wood_count < max_wood_carry:
		wood_count = min(wood_count + amount, max_wood_carry)
		update_wood_visuals()
		return true
	return false

func update_wood_visuals() -> void:
	var children = wood_pile.get_children()
	for i in range(children.size()):
		children[i].visible = i < wood_count

func find_closest_construction_site() -> Node2D:
	var buildings = get_tree().get_nodes_in_group("buildings")
	var closest: Node2D = null
	var min_dist: float = 999999.0
	for b in buildings:
		if is_instance_valid(b) and not b.is_built:
			if "current_construction_wood" in b and "build_cost" in b:
				if b.current_construction_wood < b.build_cost:
					var dist = global_position.distance_to(b.global_position)
					if dist < min_dist:
						min_dist = dist
						closest = b
	return closest

func find_closest_wood_source() -> Node2D:
	# 1. Сначала ищем дрова на земле
	var drops = get_tree().get_nodes_in_group("wood_drop")
	var closest_drop: Node2D = null
	var min_drop_dist: float = 999999.0
	for drop in drops:
		if is_instance_valid(drop) and drop.is_on_ground and not drop.is_flying_to_target:
			var dist = global_position.distance_to(drop.global_position)
			if dist < min_drop_dist:
				min_drop_dist = dist
				closest_drop = drop
				
	if closest_drop and min_drop_dist < 400.0:
		return closest_drop
		
	# 2. Если дров на земле нет, ищем склад лесорубов с деревом
	var houses = get_tree().get_nodes_in_group("lumberjack_house")
	var closest_house: Node2D = null
	var min_house_dist: float = 999999.0
	for house in houses:
		if is_instance_valid(house) and house.is_built and house.wood_stored > 0:
			var dist = global_position.distance_to(house.global_position)
			if dist < min_house_dist:
				min_house_dist = dist
				closest_house = house
				
	if closest_house:
		return closest_house
		
	# Если на складе нет, возвращаем далекие дрова на земле (если есть)
	return closest_drop

func choose_wander_target() -> void:
	var campfire = get_tree().get_first_node_in_group("campfire")
	var center_x = campfire.global_position.x if campfire else global_position.x
	wander_target_x = center_x + randf_range(-120.0, 120.0)
	wander_timer = randf_range(3.0, 6.0)

func animate_walk() -> void:
	var pulse = sin(Time.get_ticks_msec() * 0.02) * 0.08
	body.scale.y = 1.0 + pulse

func take_damage(amount: float) -> void:
	# Строитель превращается обратно в бродягу
	var vagrant_scene = load("res://scenes/vagrant/vagrant.tscn")
	if vagrant_scene:
		var v = vagrant_scene.instantiate()
		get_parent().add_child(v)
		v.global_position = global_position
		v.is_hired = false
		
		# Отскок назад для нового бродяги
		var knock_dir = -sign(body.scale.x) if body.scale.x != 0 else -1.0
		v.velocity = Vector2(knock_dir * 120.0, -100.0)
		
		var v_body = v.get_node_or_null("Body")
		if v_body:
			v_body.modulate = Color(1.0, 0.3, 0.3)
			var tween = create_tween()
			tween.tween_property(v_body, "modulate", Color(1, 1, 1), 0.15)
		
		# Строитель роняет дерево (если нес) на землю
		if wood_count > 0:
			var wood_scene = load("res://scenes/wood/wood.tscn")
			if wood_scene:
				var w = wood_scene.instantiate()
				get_parent().add_child(w)
				w.global_position = global_position
				var dir_x = -sign(body.scale.x) if body.scale.x != 0 else 1.0
				var target_x = global_position.x + randf_range(30.0, 70.0) * dir_x
				w.launch(target_x, global_position.y)
				
	queue_free()

