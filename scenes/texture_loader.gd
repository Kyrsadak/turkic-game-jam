extends Object
class_name TextureLoader

static func try_apply_texture(node: Node2D, texture_path: String, offset: Vector2 = Vector2.ZERO) -> Sprite2D:
	if FileAccess.file_exists(texture_path):
		var tex = load(texture_path)
		if tex:
			# Находим контейнер для векторной графики
			var container: Node2D = null
			var visual = node.get_node_or_null("Visual")
			var body = node.get_node_or_null("Body")
			var logs = node.get_node_or_null("Logs")
			
			if visual:
				container = visual
			elif body:
				container = body
			elif logs:
				container = logs
				
			var parent_node = container if container else node
			
			# Скрываем все оригинальные векторные элементы внутри контейнера
			if container:
				for child in container.get_children():
					if child.name != "DesignerSprite":
						if child is CanvasItem:
							child.visible = false
			
			# Проверяем, не был ли спрайт уже добавлен
			var existing_sprite = parent_node.get_node_or_null("DesignerSprite")
			if existing_sprite:
				existing_sprite.texture = tex
				existing_sprite.position = offset
				existing_sprite.visible = true
				return existing_sprite
			
			# Создаем новый спрайт
			var sprite = Sprite2D.new()
			sprite.name = "DesignerSprite"
			sprite.texture = tex
			sprite.position = offset
			
			# Для дерева переносим шейдерный материал покачивания от ветра
			if visual and visual.has_node("Crown"):
				var crown = visual.get_node("Crown")
				if crown and crown.material:
					sprite.material = crown.material
					
			parent_node.add_child(sprite)
			return sprite
	return null
