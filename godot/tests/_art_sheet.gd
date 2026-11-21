extends SceneTree
## 미술 확인용: 물건 아이콘 전부 + 손님 유형별 얼굴을 한 장에 그린다 → /tmp/art_items.png, /tmp/art_chars.png
func _init() -> void:
	var keys: Array = ItemArt.MAP.keys()
	var cols := 10
	var cell := 110
	var img := Image.create(cols * cell, int(ceil(keys.size() / float(cols))) * cell, false, Image.FORMAT_RGBA8)
	img.fill(Color("#efe4cc"))
	for i in keys.size():
		var t := ItemArt.texture(keys[i], 100).get_image()
		t.convert(Image.FORMAT_RGBA8)
		img.blend_rect(t, Rect2i(0, 0, t.get_width(), t.get_height()), Vector2i((i % cols) * cell + 5, (i / cols) * cell + 5))
	img.save_png("/tmp/art_items.png")
	var archs := ["seonbi", "rabbit", "fox", "dokkaebi", "granny", "doryeong", "robot"]
	var traits := [[], ["rich"], ["scammer"], ["naive", "chatty"]]
	var cw := 180
	var ch := 290
	var img2 := Image.create(cw * archs.size(), ch * traits.size(), false, Image.FORMAT_RGBA8)
	img2.fill(Color("#1c1836"))
	for a in archs.size():
		for k in traits.size():
			var L := SvgArt.customer_look2(archs[a], traits[k], 7 + a * 13 + k)
			var t2 := SvgArt.char_texture(L, ["idle", "happy", "angry", "shock"][k], 0.8).get_image()
			t2.convert(Image.FORMAT_RGBA8)
			img2.blend_rect(t2, Rect2i(0, 0, t2.get_width(), t2.get_height()), Vector2i(a * cw, k * ch))
	var D = load("res://scripts/core/game_data.gd").new()
	if D.has_method("load_all"):
		D.load_all()
	img2.save_png("/tmp/art_chars.png")
	print("ok")
	quit()
