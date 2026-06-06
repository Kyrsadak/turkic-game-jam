extends Control

@onready var btn_start = $MenuContainer/Buttons/BtnStart
@onready var btn_settings = $MenuContainer/Buttons/BtnSettings
@onready var btn_quit = $MenuContainer/Buttons/BtnQuit

@onready var cur_start = $MenuContainer/Buttons/BtnStart/HBoxStart/CurStart
@onready var cur_settings = $MenuContainer/Buttons/BtnSettings/HBoxSettings/CurSettings
@onready var cur_quit = $MenuContainer/Buttons/BtnQuit/HBoxQuit/CurQuit

@onready var label_start = $MenuContainer/Buttons/BtnStart/HBoxStart/LabelStart
@onready var label_settings = $MenuContainer/Buttons/BtnSettings/HBoxSettings/LabelSettings
@onready var label_quit = $MenuContainer/Buttons/BtnQuit/HBoxQuit/LabelQuit

@onready var hbox_start = $MenuContainer/Buttons/BtnStart/HBoxStart
@onready var hbox_settings = $MenuContainer/Buttons/BtnSettings/HBoxSettings
@onready var hbox_quit = $MenuContainer/Buttons/BtnQuit/HBoxQuit

@onready var settings_panel = $SettingsPanel
@onready var close_settings_btn = $SettingsPanel/VBox/CloseSettingsBtn

const COLOR_NORMAL = Color(0.85, 0.85, 0.85)
const COLOR_HOVER = Color(0.95, 0.8, 0.3)

func _ready() -> void:

	# Настройка сигналов кнопок
	setup_button(btn_start, cur_start, label_start, hbox_start)
	setup_button(btn_settings, cur_settings, label_settings, hbox_settings)
	setup_button(btn_quit, cur_quit, label_quit, hbox_quit)
	
	btn_start.pressed.connect(_on_start_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	close_settings_btn.pressed.connect(_on_close_settings_pressed)
	settings_panel.visible = false

func setup_button(btn: Button, cur: Label, label: Label, hbox: HBoxContainer) -> void:
	cur.visible = true
	cur.modulate.a = 0.0
	label.self_modulate = COLOR_NORMAL
	
	# Подключаем события наведения мыши
	btn.mouse_entered.connect(func(): animate_hover(btn, cur, label, hbox, true))
	btn.mouse_exited.connect(func(): animate_hover(btn, cur, label, hbox, false))
	btn.focus_entered.connect(func(): animate_hover(btn, cur, label, hbox, true))
	btn.focus_exited.connect(func(): animate_hover(btn, cur, label, hbox, false))

func animate_hover(btn: Button, cur: Label, label: Label, hbox: HBoxContainer, is_hover: bool) -> void:
	var tween = create_tween().set_parallel(true)
	if is_hover:
		# Анимация проявления золотого ромбика
		tween.tween_property(cur, "modulate:a", 1.0, 0.15)
		# Плавный переход цвета текста к золотому
		tween.tween_property(label, "self_modulate", COLOR_HOVER, 0.15)
		# Плавный сдвиг вправо на 12 пикселей
		tween.tween_property(hbox, "position:x", 12.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		# Плавный возврат в исходное положение
		tween.tween_property(hbox, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(cur, "modulate:a", 0.0, 0.15)
		tween.tween_property(label, "self_modulate", COLOR_NORMAL, 0.15)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_settings_pressed() -> void:
	settings_panel.visible = true
	# Анимация появления окна настроек в стиле Zelda
	var tween = create_tween()
	settings_panel.scale = Vector2(0.8, 0.8)
	settings_panel.modulate.a = 0.0
	tween.set_parallel(true)
	tween.tween_property(settings_panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(settings_panel, "modulate:a", 1.0, 0.2)

func _on_close_settings_pressed() -> void:
	# Анимация закрытия окна настроек
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(settings_panel, "scale", Vector2(0.8, 0.8), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(settings_panel, "modulate:a", 0.0, 0.18)
	await tween.finished
	settings_panel.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()
