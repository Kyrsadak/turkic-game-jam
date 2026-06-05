shader_type canvas_item;

uniform float speed : hint_range(0.1, 10.0) = 2.0;
uniform float strength : hint_range(0.0, 1.0) = 0.1;
uniform float detail : hint_range(0.1, 10.0) = 1.0;

void vertex() {
	// В Godot 2D UV.y = 0 — верх, UV.y = 1 — низ.
	// Мы покачиваем только верхнюю часть объекта (где UV.y близко к 0)
	float sway_factor = 1.0 - UV.y;
	
	// Движение волны с использованием времени
	float wave = sin(TIME * speed + VERTEX.x * detail) * strength;
	
	VERTEX.x += wave * sway_factor * 20.0;
}
