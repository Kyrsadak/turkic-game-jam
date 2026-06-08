extends Control

@onready var slot1: Control = $Background/SlotsContainer/HBoxContainer/Slot1
@onready var wood_icon: Control = $Background/SlotsContainer/HBoxContainer/Slot1/WoodIcon
@onready var count_label: Label = $Background/SlotsContainer/HBoxContainer/Slot1/CountLabel

var last_count: int = 0

func _ready() -> void:
	# Ждем один кадр, чтобы HBoxContainer выровнял размеры слотов, и мы могли выставить центр для pivot_offset
	await get_tree().process_frame
	if is_instance_valid(slot1):
		slot1.pivot_offset = slot1.size / 2.0
	update_wood(0, 5)

func update_wood(count: int, _max_carry: int) -> void:
	if is_instance_valid(count_label):
		count_label.text = str(count)
		count_label.visible = count > 0
	
	if is_instance_valid(wood_icon):
		# Дерево отображается, если оно есть в наличии
		wood_icon.visible = count > 0
	
	if count > last_count:
		play_pulse_animation()
		
	last_count = count

func play_pulse_animation() -> void:
	if not is_instance_valid(slot1):
		return
		
	var tween = create_tween()
	# Легкий импульс увеличения и покачивание
	tween.tween_property(slot1, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot1, "rotation", 0.06, 0.04)
	tween.tween_property(slot1, "rotation", -0.06, 0.04)
	tween.tween_property(slot1, "rotation", 0.0, 0.04)
	tween.tween_property(slot1, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
