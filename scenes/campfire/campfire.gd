extends Node2D
const TextureLoader = preload("res://scenes/texture_loader.gd")

signal burned_out
signal fuel_changed(current_fuel, max_fuel)

@export var max_fuel: float = 450.0
@export var fuel_burn_rate: float = 1.0
@export var wood_fuel_value: float = 50.0

var current_fuel: float = 200.0  # Начинаем с половины

@onready var light_2d: PointLight2D = $PointLight2D
@onready var particles_flame: CPUParticles2D = get_node_or_null("ParticlesFlame")
@onready var particles_sparks: CPUParticles2D = get_node_or_null("ParticlesSparks")
@onready var label_status: Label = $LabelStatus

var light_base_scale: float = 6.0
var light_base_energy: float = 1.2
var noise_time: float = 0.0
var is_burned_out: bool = false

func _ready() -> void:
	add_to_group("campfire")
	emit_signal("fuel_changed", current_fuel, max_fuel)
	label_status.visible = false
	setup_tooltip_style(label_status)
	TextureLoader.try_apply_texture(self, "res://assets/textures/campfire.png", Vector2(0, -5))

func _process(delta: float) -> void:
	if is_burned_out:
		return
		
	if current_fuel <= 0.0:
		current_fuel = 0.0
		is_burned_out = true
		emit_signal("burned_out")
		emit_signal("fuel_changed", current_fuel, max_fuel)
		# Выключаем визуальные эффекты
		if is_instance_valid(particles_flame):
			particles_flame.emitting = false
		if is_instance_valid(particles_sparks):
			particles_sparks.emitting = false
		
		var anim_sprite = get_node_or_null("AnimatedSprite2D")
		if anim_sprite:
			anim_sprite.stop()
			anim_sprite.visible = false
		
		# Плавное затухание света
		var tween = create_tween()
		tween.tween_property(light_2d, "energy", 0.0, 1.5)
		return
		
	current_fuel -= fuel_burn_rate * delta
	if current_fuel < 0.0:
		current_fuel = 0.0
		
	emit_signal("fuel_changed", current_fuel, max_fuel)
	
	# Эффект мерцания света костра
	noise_time += delta * 15.0
	var flicker = sin(noise_time) * 0.06 + cos(noise_time * 0.7) * 0.04
	
	# Размер и яркость зависят от уровня топлива
	var fuel_ratio = current_fuel / max_fuel
	light_2d.texture_scale = light_base_scale * (0.4 + 0.6 * fuel_ratio) + flicker
	light_2d.energy = light_base_energy * (0.5 + 0.5 * fuel_ratio) + flicker * 0.5
	
	# Масштабируем частицы огня
	if is_instance_valid(particles_flame):
		particles_flame.amount = int(clamp(40 * fuel_ratio, 10, 50))
		particles_flame.scale_amount_min = 3.0 * (0.5 + 0.5 * fuel_ratio)
		particles_flame.scale_amount_max = 6.0 * (0.5 + 0.5 * fuel_ratio)
		particles_flame.initial_velocity_min = 40.0 * (0.5 + 0.5 * fuel_ratio)
		particles_flame.initial_velocity_max = 70.0 * (0.5 + 0.5 * fuel_ratio)
		
	# Масштабируем спрайт огня
	var anim_sprite = get_node_or_null("AnimatedSprite2D")
	if anim_sprite:
		var fire_scale = 0.5 + 0.6 * fuel_ratio
		anim_sprite.scale = Vector2(fire_scale, fire_scale)
	
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
