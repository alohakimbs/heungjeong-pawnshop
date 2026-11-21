extends SceneTree
const SvgArt := preload("res://scripts/ui/svg_art.gd")
const GD := preload("res://scripts/core/game_data.gd")
func _init():
	var data = GD.new()
	var out := Image.create(880, 720, false, Image.FORMAT_RGBA8)
	out.fill(Color("#7a2e2a"))
	var looks := []
	for k in ["pierre", "tanghan", "madam", "duchil"]:
		looks.append([SvgArt.look(data.specials[k]["L"]), "ok"])
	looks.append([SvgArt.customer_look("granny", ["naive"], 5), "happy"])
	looks.append([SvgArt.customer_look("office", ["hasty"], 9), "angry"])
	looks.append([SvgArt.customer_look("hipster", ["greedy"], 3), "meh"])
	looks.append([SvgArt.customer_look("ajussi", ["stingy","calm"], 11), "ok"])
	for i in looks.size():
		var t: ImageTexture = SvgArt.char_texture(looks[i][0], looks[i][1], 1.0)
		var img := t.get_image()
		out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % 4) * 220, (i / 4) * 360))
	out.save_png("/tmp/chars.png")
	print("ok ", out.get_size())
	data.free()
	quit()
