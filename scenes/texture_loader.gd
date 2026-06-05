extends Object
class_name TextureLoader

static func try_apply_texture(node: Node2D, texture_path: String, offset: Vector2 = Vector2.ZERO) -> Sprite2D:
	if FileAccess.file_exists(texture_path):
		var tex = load(texture_path)
		if tex:
			# Скрываем стандартную векторную графику
			var visual = node.get_node_or_null("Visual")
			if visual:
				visual.visible = false
			else:
				var body = node.get_node_or_null("Body")
				if body:
					body.visible = false
				else:
					var logs = node.get_node_or_null("Logs")
					if logs:
						logs.visible = false
			
			# Проверяем, не был ли спрайт уже добавлен
			var existing_sprite = node.get_node_or_null("DesignerSprite")
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
					
			node.add_child(sprite)
			return sprite
	return null
