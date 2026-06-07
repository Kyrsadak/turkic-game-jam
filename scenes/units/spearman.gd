extends CharacterBody2D
const TextureLoader = preload("res://scenes/texture_loader.gd")
const AudioUtilsScript = preload("res://scenes/audio_utils.gd")

# Мини-мозг копейщика для обороны базы:
#   PATROLLING — ходит между левой и правой стеной (периметр базы)
#   CHASING    — заметил врага, бежит к нему
#   ATTACKING  — ударяет копьем когда враг в радиусе удара
#   RETURNING  — возвращается к ближайшей точке периметра после боя
enum State { PATROLLING, CHASING, ATTACKING, RETURNING }

@export var patrol_speed: float = 60.0
@export var combat_speed: float = 110.0
@export var damage: float = 14.0
@export var attack_cooldown: float = 0.75
@export var attack_range: float = 30.0
@export var detection_range: float = 230.0
@export var leash_range: float = 380.0
@export var patrol_pause_min: float = 0.6
@export var patrol_pause_max: float = 1.4
# Запас вертикали при поиске врагов: ловим тех, что стоят на одной «полке»
# с базой, и не ведёмся на тех, что прыгают где-то в небе.
@export var vertical_threat_range: float = 80.0
# Защитный буфер от стен при погоне: копейщик не выходит за периметр базы
# дальше чем на это расстояние, чтобы не уходить в чистое поле.
@export var leash_outside_buffer: float = 60.0

var gravity: float = 900.0
var current_state: State = State.PATROLLING
var target_enemy: Node2D = null
var attack_timer: float = 0.0
var patrol_dir: float = 1.0
var patrol_pause_timer: float = 0.0
var patrol_left_x: float = -280.0
var patrol_right_x: float = 280.0
var patrol_target_x: float = 0.0
# «Якорь» базы — центр периметра. К нему возвращаемся после боя.
var base_center_x: float = 0.0

# Кэш периметра базы — обновляем периодически, чтобы реагировать на стены,
# которые игрок строит/чинит во время игры.
var perimeter_refresh_timer: float = 0.0

@onready var body: Node2D = $Body
@onready var spear: Node2D = $Body/Spear
@onready var footstep_audio: AudioStreamPlayer2D = $FootstepAudio

static var spearman_count: int = 0
var footstep_timer: float = 0.0
var footstep_base_volume_db: float = -14.0
var footstep_fadeout_speed_db: float = 38.0

func _ready() -> void:
	add_to_group("spearman")
	footstep_audio.volume_db = footstep_base_volume_db
	
	spearman_count += 1
	
	refresh_patrol_bounds()
	# Чередуем стартовое направление, чтобы копейщики патрулировали в разные
	# стороны и быстрее покрывали периметр базы.
	patrol_dir = 1.0 if (spearman_count % 2 == 1) else -1.0
	patrol_target_x = patrol_right_x if patrol_dir > 0 else patrol_left_x
	
	TextureLoader.try_apply_texture(self, "res://assets/textures/spearman.png", Vector2(0, -14))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	perimeter_refresh_timer -= delta
	if perimeter_refresh_timer <= 0.0:
		refresh_patrol_bounds()
		perimeter_refresh_timer = 1.5

	# Поиск врагов в зависимости от состояния:
	# на патруле — широкий радиус; в бою — дольше «удерживаем» цель.
	var search_radius: float = detection_range
	if current_state == State.CHASING or current_state == State.ATTACKING:
		search_radius = leash_range
	target_enemy = find_closest_enemy(search_radius)

	match current_state:
		State.PATROLLING:
			tick_patrolling(delta)
		State.CHASING:
			tick_chasing(delta)
		State.ATTACKING:
			tick_attacking(delta)
		State.RETURNING:
			tick_returning(delta)

	move_and_slide()
	update_footsteps(delta)

# ---------------------------------------------------------------------------
# Состояния мини-мозга
# ---------------------------------------------------------------------------

func tick_patrolling(_delta: float) -> void:
	# Заметили врага — погоня.
	if is_instance_valid(target_enemy):
		current_state = State.CHASING
		patrol_pause_timer = 0.0
		return

	# Стоим на паузе на конце маршрута.
	if patrol_pause_timer > 0.0:
		velocity.x = 0.0
		patrol_pause_timer -= _delta
		# Смотрим наружу базы во время паузы.
		body.scale.x = patrol_dir
		return

	var dist_x = patrol_target_x - global_position.x
	if abs(dist_x) < 6.0:
		# Достигли конца маршрута — пауза, разворот.
		velocity.x = 0.0
		patrol_pause_timer = randf_range(patrol_pause_min, patrol_pause_max)
		patrol_dir = -patrol_dir
		patrol_target_x = patrol_right_x if patrol_dir > 0 else patrol_left_x
		return

	velocity.x = sign(dist_x) * patrol_speed
	body.scale.x = sign(dist_x)
	animate_walk()

func tick_chasing(_delta: float) -> void:
	if not is_instance_valid(target_enemy):
		current_state = State.RETURNING
		return

	var dist = global_position.distance_to(target_enemy.global_position)
	# Враг ушёл далеко — возвращаемся на периметр.
	if dist > leash_range:
		current_state = State.RETURNING
		return

	# Если копейщик уже сильно за периметром базы — отзываем на защиту.
	# Это защищает от выманивания в чистое поле.
	if global_position.x < patrol_left_x - leash_outside_buffer or \
			global_position.x > patrol_right_x + leash_outside_buffer:
		current_state = State.RETURNING
		return

	# В радиусе удара — атакуем.
	if dist <= attack_range:
		velocity.x = 0.0
		current_state = State.ATTACKING
		attack_timer = 0.1
		return

	# Бежим к врагу.
	var dist_x = target_enemy.global_position.x - global_position.x
	if dist_x != 0.0:
		velocity.x = sign(dist_x) * combat_speed
		body.scale.x = sign(dist_x)
	animate_walk()

func tick_attacking(delta: float) -> void:
	if not is_instance_valid(target_enemy):
		current_state = State.RETURNING
		return

	var dist = global_position.distance_to(target_enemy.global_position)
	if dist > attack_range + 6.0:
		current_state = State.CHASING
		return

	# Поворачиваемся к врагу.
	var dist_x = target_enemy.global_position.x - global_position.x
	if dist_x != 0.0:
		body.scale.x = sign(dist_x)

	velocity.x = 0.0

	attack_timer -= delta
	if attack_timer <= 0.0:
		stab_enemy()
		attack_timer = attack_cooldown

func tick_returning(_delta: float) -> void:
	# Если по дороге снова появился враг — гонимся.
	if is_instance_valid(target_enemy):
		current_state = State.CHASING
		return

	# Возвращаемся к ближайшей точке периметра базы.
	var return_x = clamp(global_position.x, patrol_left_x, patrol_right_x)
	var dist_x = return_x - global_position.x

	if abs(dist_x) < 8.0:
		velocity.x = 0.0
		current_state = State.PATROLLING
		# Свежая цель патруля — продолжаем в текущем направлении.
		patrol_target_x = patrol_right_x if patrol_dir > 0 else patrol_left_x
		return

	velocity.x = sign(dist_x) * combat_speed
	body.scale.x = sign(dist_x)
	animate_walk()

# ---------------------------------------------------------------------------
# Помощники
# ---------------------------------------------------------------------------

func refresh_patrol_bounds() -> void:
	# Левая и правая границы патрулирования вычисляются по позициям всех
	# узлов в группе "wall" (наша база ограничена забором). Если стен
	# вообще нет — используем периметр вокруг костра.
	var walls = get_tree().get_nodes_in_group("wall")
	var min_x: float = INF
	var max_x: float = -INF
	for wall in walls:
		if not is_instance_valid(wall):
			continue
		var wx: float = wall.global_position.x
		if wx < min_x:
			min_x = wx
		if wx > max_x:
			max_x = wx

	if min_x == INF or max_x == -INF or max_x - min_x < 30.0:
		# Резервный периметр вокруг костра.
		var campfire = get_tree().get_first_node_in_group("campfire")
		var center_x: float = campfire.global_position.x if campfire else 0.0
		min_x = center_x - 240.0
		max_x = center_x + 240.0

	# Сужаем периметр на пару пикселей внутрь, чтобы копейщик не упирался
	# в коллизии стен и не «дёргался» на самой границе.
	patrol_left_x = min_x + 12.0
	patrol_right_x = max_x - 12.0
	if patrol_left_x > patrol_right_x:
		var mid = (min_x + max_x) * 0.5
		patrol_left_x = mid - 1.0
		patrol_right_x = mid + 1.0
	base_center_x = (patrol_left_x + patrol_right_x) * 0.5

func stab_enemy() -> void:
	if is_instance_valid(target_enemy):
		if target_enemy.has_method("take_damage"):
			target_enemy.take_damage(damage)
			
		# Анимация выпада копья
		var tween = create_tween()
		var orig_pos = spear.position
		var target_pos = orig_pos + Vector2(14.0, 0)
		tween.tween_property(spear, "position", target_pos, 0.07)
		tween.tween_property(spear, "position", orig_pos, 0.12)

func find_closest_enemy(max_dist: float) -> Node2D:
	# Берём только тех, кто на той же «полке» земли (по Y) — копейщик не
	# гоняется за теми, кто на другой высоте, и не реагирует на врагов вне
	# зоны защиты базы.
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest: Node2D = null
	var min_dist: float = max_dist
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var dy: float = abs(enemy.global_position.y - global_position.y)
		if dy > vertical_threat_range:
			continue
		# Не уходим далеко за периметр базы за врагами.
		var ex: float = enemy.global_position.x
		if ex < patrol_left_x - leash_range or ex > patrol_right_x + leash_range:
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = enemy
	return closest

func animate_walk() -> void:
	var pulse = sin(Time.get_ticks_msec() * 0.022) * 0.08
	body.scale.y = 1.0 + pulse

func update_footsteps(delta: float) -> void:
	var is_walking = is_on_floor() and abs(velocity.x) > 5.0
	if is_walking:
		footstep_audio.volume_db = move_toward(footstep_audio.volume_db, footstep_base_volume_db, footstep_fadeout_speed_db * delta)
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_audio.stop()
			footstep_audio.volume_db = footstep_base_volume_db
			footstep_audio.pitch_scale = randf_range(0.90, 0.96)
			AudioUtilsScript.play_if_visible(footstep_audio)
			footstep_timer = 0.28
	else:
		footstep_timer = 0.0
		if footstep_audio.playing:
			footstep_audio.volume_db = move_toward(footstep_audio.volume_db, -40.0, footstep_fadeout_speed_db * delta)
			if footstep_audio.volume_db <= -39.0:
				footstep_audio.stop()
				footstep_audio.volume_db = footstep_base_volume_db
