extends ParallaxBackground


var speed_scene = 100

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	scroll_base_offset.x -= speed_scene * delta
