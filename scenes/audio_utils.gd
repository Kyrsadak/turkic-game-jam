class_name AudioUtils
extends RefCounted

# Дополнительный отступ за границей экрана, в пределах которого звуки ещё считаются слышимыми.
# Помогает избежать резких "обрывов" звука прямо у кромки кадра.
const DEFAULT_VISIBILITY_MARGIN: float = 96.0

# Возвращает мировой прямоугольник, видимый камерой игрока.
# Если камеры нет — возвращает пустой Rect2 (звуки тогда играем без ограничений).
static func get_visible_world_rect(node: Node) -> Rect2:
	if node == null:
		return Rect2()
	var viewport: Viewport = node.get_viewport()
	if viewport == null:
		return Rect2()
	var cam: Camera2D = viewport.get_camera_2d()
	if cam == null:
		return Rect2()
	var size := viewport.get_visible_rect().size
	if cam.zoom.x != 0.0 and cam.zoom.y != 0.0:
		size = size / cam.zoom
	var center := cam.get_screen_center_position()
	return Rect2(center - size * 0.5, size)

# Видна ли точка мира игроку (с учётом отступа).
static func is_position_visible(node: Node, global_pos: Vector2, margin: float = -1.0) -> bool:
	var rect := get_visible_world_rect(node)
	if rect.size == Vector2.ZERO:
		return true
	var m := DEFAULT_VISIBILITY_MARGIN if margin < 0.0 else margin
	return rect.grow(m).has_point(global_pos)

# Проиграть AudioStreamPlayer2D только если его позиция в кадре игрока.
static func play_if_visible(audio: AudioStreamPlayer2D, margin: float = -1.0) -> bool:
	if audio == null:
		return false
	if is_position_visible(audio, audio.global_position, margin):
		audio.play()
		return true
	return false
