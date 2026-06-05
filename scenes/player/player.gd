extends CharacterBody2D

signal wood_count_changed(count)

@export var speed: float = 160.0
@export var jump_velocity: float = -320.0
@export var max_wood_carry: int = 5

var gravity: float = 900.0
var wood_count: int = 0
var is_hitting: bool = false

@onready var body: Node2D = $Body
@onready var wood_pile: Node2D = $WoodPile
@onready var hit_cooldown: Timer = $HitCooldown

func _ready() -> void:
	add_to_group("player")
	update_wood_visuals()

func _physics_process(delta: float) -> void:
	# Гравитация
	if not is_on_floor():
		velocity.y += gravity * delta

	# Прыжок (W, Space, Up или ui_accept)
	var wants_to_jump = Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	if wants_to_jump and is_on_floor():
		velocity.y = jump_velocity
		
		# Эффект сплющивания при прыжке
		var tween = create_tween()
		tween.tween_property(body, "scale", Vector2(0.8, 1.2), 0.1)
		tween.tween_property(body, "scale", Vector2(1.0, 1.0), 0.15)

	# Движение влево-вправо (A/D или Стрелки)
	var direction = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0
		
	if direction != 0.0:
		velocity.x = direction * speed
		body.scale.x = sign(direction) # Поворачиваем лицо игрока
		
		# Микро-анимация покачивания при беге
		if is_on_floor() and not is_hitting:
			var pulse = sin(Time.get_ticks_msec() * 0.015) * 0.08
			body.scale.y = 1.0 + pulse
			body.position.y = pulse * 1.5
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 0.25)
		if is_on_floor() and not is_hitting:
			body.scale = Vector2(1, 1)
			body.position = Vector2(0, 0)

	move_and_slide()

	# Обработка клавиши E для взаимодействия
	if Input.is_key_pressed(KEY_E) and not is_hitting:
		perform_interaction()

func perform_interaction() -> void:
	# 1. Проверяем, есть ли рядом костер и хотим ли закинуть дерево
	var campfire = get_closest_in_group("campfire", 60.0)
	if campfire and wood_count > 0:
		if campfire.current_fuel < campfire.max_fuel - 2.0:
			if campfire.add_wood():
				wood_count -= 1
				emit_signal("wood_count_changed", wood_count)
				update_wood_visuals()
				
				# Анимация отдачи
				var tween = create_tween()
				tween.tween_property(wood_pile, "position:y", -5.0, 0.1)
				tween.tween_property(wood_pile, "position:y", 0.0, 0.1)
				
				is_hitting = true
				await get_tree().create_timer(0.25).timeout
				is_hitting = false
				return

	# 2. Проверяем, есть ли рядом дерево для рубки
	var tree = get_closest_in_group("tree", 45.0)
	if tree and not tree.is_felled:
		start_hit_animation()
		tree.hit_tree(global_position.x)
		return

	# 3. Проверяем здания для сдачи дров / найма
	var building = get_closest_in_group("buildings", 55.0)
	if building:
		if wood_count > 0 and building.has_method("deposit_wood"):
			if building.deposit_wood():
				wood_count -= 1
				emit_signal("wood_count_changed", wood_count)
				update_wood_visuals()
				
				is_hitting = true
				await get_tree().create_timer(0.2).timeout
				is_hitting = false
				return
		if building.has_method("interact") and building.interact(self):
			return

	# 4. Проверяем бродяг для найма (цена 2 дерева)
	var vagrant = get_closest_in_group("vagrant", 50.0)
	if vagrant and not vagrant.is_hired and wood_count >= 2:
		if vagrant.hire():
			wood_count -= 2
			emit_signal("wood_count_changed", wood_count)
			update_wood_visuals()
			
			start_hit_animation()
			return

func start_hit_animation() -> void:
	is_hitting = true
	hit_cooldown.start()
	
	# Эффект удара (наклон тела)
	var tween = create_tween()
	var orig_rot = body.rotation
	var hit_rot = 0.35 * sign(body.scale.x)
	tween.tween_property(body, "rotation", hit_rot, 0.08)
	tween.tween_property(body, "rotation", orig_rot, 0.12)
	
	await tween.finished
	is_hitting = false

func add_wood(amount: int = 1) -> bool:
	if wood_count < max_wood_carry:
		wood_count = min(wood_count + amount, max_wood_carry)
		emit_signal("wood_count_changed", wood_count)
		update_wood_visuals()
		return true
	return false

func update_wood_visuals() -> void:
	var children = wood_pile.get_children()
	for i in range(children.size()):
		children[i].visible = i < wood_count

func get_closest_in_group(group_name: String, max_dist: float) -> Node:
	var nodes = get_tree().get_nodes_in_group(group_name)
	var closest_node: Node = null
	var closest_dist: float = max_dist
	for node in nodes:
		var dist = global_position.distance_to(node.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_node = node
	return closest_node

func _on_hit_cooldown_timeout() -> void:
	pass
