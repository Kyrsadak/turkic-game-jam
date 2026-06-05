extends Node2D
const TextureLoader = preload("res://scenes/texture_loader.gd")

signal burned_out
signal fuel_changed(current_fuel, max_fuel)

@export var max_fuel: float = 450.0
@export var fuel_burn_rate: float = 1.0
@export var wood_fuel_value: float = 50.0

var current_fuel: float = 200.0  # Начинаем с половины

@onready var light_2d: PointLight2D = $PointLight2D
@onready var particles_flame: CPUParticles2D = $ParticlesFlame
@onready var particles_sparks: CPUParticles2D = $ParticlesSparks
@onready var label_status: Label = $LabelStatus

var light_base_scale: float = 6.0
var light_base_energy: float = 1.2
var noise_time: float = 0.0
var is_burned_out: bool = false

# Анимация костра
@export var animation_frame_delay: float = 0.35 # Время отображения одного кадра в секундах (350 ms)
var campfire_textures: Array[Texture2D] = []
var current_frame: int = 0
var animation_time: float = 0.0
var campfire_sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("campfire")
	emit_signal("fuel_changed", current_fuel, max_fuel)
	label_status.visible = false
	setup_tooltip_style(label_status)
	
	# Загружаем анимированные кадры (campfire1.png - campfire6.png) из отдельной директории
	for i in range(1, 7):
		var path = "res://assets/textures/campfire/campfire%d.png" % i
		if FileAccess.file_exists(path):
			var tex = load(path)
			if tex:
				campfire_textures.append(tex)
	
	if campfire_textures.size() > 0:
		# Скрываем стандартные бревна
		var logs = get_node_or_null("Logs")
		if logs:
			logs.visible = false
			
		# Проверяем, не был ли спрайт уже добавлен
		var existing_sprite = get_node_or_null("DesignerSprite")
		if existing_sprite:
			campfire_sprite = existing_sprite
			campfire_sprite.texture = campfire_textures[0]
			campfire_sprite.position = Vector2(0, -5)
			campfire_sprite.visible = true
		else:
			# Создаем новый спрайт
			campfire_sprite = Sprite2D.new()
			campfire_sprite.name = "DesignerSprite"
			campfire_sprite.texture = campfire_textures[0]
			campfire_sprite.position = Vector2(0, -5)
			add_child(campfire_sprite)
	else:
		# Резервный вариант со статической текстурой
		campfire_sprite = TextureLoader.try_apply_texture(self, "res://assets/textures/campfire.png", Vector2(0, -5))

func _process(delta: float) -> void:
	if is_burned_out:
		return
		
	if current_fuel > 0:
		current_fuel -= fuel_burn_rate * delta
		if current_fuel <= 0:
			current_fuel = 0
			is_burned_out = true
			emit_signal("burned_out")
			# Выключаем визуальные эффекты
			particles_flame.emitting = false
			particles_sparks.emitting = false
			
			# Показываем стандартные бревна при затухании
			if campfire_textures.size() > 0:
				if campfire_sprite:
					campfire_sprite.visible = false
				var logs = get_node_or_null("Logs")
				if logs:
					logs.visible = true
			
			# Плавное затухание света
			var tween = create_tween()
			tween.tween_property(light_2d, "energy", 0.0, 1.5)
			return

		emit_signal("fuel_changed", current_fuel, max_fuel)
		
		# Анимация спрайта костра
		if campfire_textures.size() > 0 and campfire_sprite:
			animation_time += delta
			if animation_time >= animation_frame_delay:
				current_frame = (current_frame + 1) % campfire_textures.size()
				campfire_sprite.texture = campfire_textures[current_frame]
				animation_time = fmod(animation_time, animation_frame_delay)
		
		# Эффект мерцания света костра
		noise_time += delta * 15.0
		var flicker = sin(noise_time) * 0.06 + cos(noise_time * 0.7) * 0.04
		
		# Размер и яркость зависят от уровня топлива
		var fuel_ratio = current_fuel / max_fuel
		light_2d.texture_scale = light_base_scale * (0.4 + 0.6 * fuel_ratio) + flicker
		light_2d.energy = light_base_energy * (0.5 + 0.5 * fuel_ratio) + flicker * 0.5
		
		# Масштабируем спрайт костра в зависимости от топлива
		if campfire_sprite:
			var scale_val = 0.6 + 0.4 * fuel_ratio
			campfire_sprite.scale = Vector2(scale_val, scale_val)
		
		# Масштабируем частицы огня
		particles_flame.amount = int(clamp(40 * fuel_ratio, 10, 50))
		particles_flame.scale_amount_min = 3.0 * (0.5 + 0.5 * fuel_ratio)
		particles_flame.scale_amount_max = 6.0 * (0.5 + 0.5 * fuel_ratio)
		particles_flame.initial_velocity_min = 40.0 * (0.5 + 0.5 * fuel_ratio)
		particles_flame.initial_velocity_max = 70.0 * (0.5 + 0.5 * fuel_ratio)
		
		# Показываем статус при подходе игрока (только если есть дрова в руках)
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			var dist = global_position.distance_to(player.global_position)
			if dist < 60.0 and player.wood_count > 0:
				label_status.visible = true
				if current_fuel >= max_fuel - 2.0:
					label_status.text = "[Костер полон]"
				else:
					label_status.text = "[E] Подбросить дрова (%d%%)" % int(fuel_ratio * 100)
			else:
				label_status.visible = false
	else:
		label_status.visible = false

func add_wood() -> bool:
	if is_burned_out:
		return false
		
	if current_fuel < max_fuel:
		current_fuel = min(current_fuel + wood_fuel_value, max_fuel)
		emit_signal("fuel_changed", current_fuel, max_fuel)
		
		# Вспышка искр
		particles_sparks.emitting = true
		particles_sparks.one_shot = true
		particles_sparks.restart()
		
		# Небольшое покачивание/вспышка света
		var tween = create_tween()
		var orig_energy = light_2d.energy
		tween.tween_property(light_2d, "energy", orig_energy * 1.4, 0.1)
		tween.tween_property(light_2d, "energy", orig_energy, 0.3)
		
		return true
	return false

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
