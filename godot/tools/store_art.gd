extends SceneTree
## 앱 아이콘·스토어 그래픽 생성. 사용:
##   xvfb-run -a -s "-screen 0 1200x600x24" godot --path . --rendering-driver opengl3 --resolution 1024x500 -s res://tools/store_art.gd
## 결과: assets/icon/*.png (앱 아이콘), ../store/feature_graphic.png (1024x500)

const SvgArt := preload("res://scripts/ui/svg_art.gd")
var step := 0
var owner_look := {}

func _init():
	owner_look = SvgArt.look({"head": "round", "hair": 0, "hc": "#2b1b12", "outfit": "apron", "oc": "#f4efe6", "oc2": "#b8473c", "fh": 4, "hat": "cap", "skin": "#eac29a", "acc": ["goldtooth"], "nose": "round"})
	_make_icons()


func _coin(cx: float, cy: float, r: float) -> String:
	return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#8a6420"/><circle cx="%s" cy="%s" r="%s" fill="#f2c230" stroke="#b8861a" stroke-width="%s"/><circle cx="%s" cy="%s" r="%s" fill="none" stroke="#fff3b0" stroke-width="%s" opacity=".6"/><path d="M%s %s l0 %s" stroke="#b8861a" stroke-width="%s" stroke-linecap="round"/>' % [cx, cy + r * 0.18, r, r, cx, cy, r, r * 0.1, cx, cy, r * 0.72, r * 0.06, cx, cy - r * 0.45, r * 0.9, r * 0.16]


func _icon_body(with_bg: bool) -> String:
	var s := ""
	if with_bg:
		s += '<defs><radialGradient id="bg" cx=".5" cy=".35" r=".75"><stop offset="0" stop-color="#e0703a"/><stop offset="1" stop-color="#7a2418"/></radialGradient></defs><rect width="512" height="512" rx="110" fill="url(#bg)"/>'
	s += '<g transform="translate(250,250) scale(2.35)">%s</g>' % SvgArt.draw_char(owner_look, "happy")
	s += _coin(402, 420, 50) + _coin(346, 448, 36)
	return s


func _make_icons():
	var full := SvgArt.rasterize(_icon_body(true), [0, 0, 512, 512], 1.0).get_image()
	full.save_png("res://assets/icon/icon_512.png")
	var i192 := full.duplicate()
	i192.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	i192.save_png("res://assets/icon/icon_192.png")
	# 적응형 아이콘: 전경(가운데 66% 안전 영역), 배경 단색
	var fg := SvgArt.rasterize('<g transform="translate(86,86) scale(0.664)">%s</g>' % _icon_body(false), [0, 0, 512, 512], 432.0 / 512.0).get_image()
	fg.save_png("res://assets/icon/adaptive_fg_432.png")
	var bg := SvgArt.rasterize('<defs><radialGradient id="bg" cx=".5" cy=".35" r=".75"><stop offset="0" stop-color="#e0703a"/><stop offset="1" stop-color="#7a2418"/></radialGradient></defs><rect width="432" height="432" fill="url(#bg)"/>', [0, 0, 432, 432], 1.0).get_image()
	bg.save_png("res://assets/icon/adaptive_bg_432.png")
	print("icons saved")


func _process(_d):
	step += 1
	if step == 1:
		_build_feature()
	elif step == 6:
		var img := root.get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../store"))
		img.save_png(ProjectSettings.globalize_path("res://../store/feature_graphic.png"))
		print("feature saved ", img.get_size())
		quit()
	return false


func _build_feature():
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1024, 500)
	var c := Control.new()
	c.size = Vector2(1024, 500)
	root.add_child(c)
	var body := '<defs><linearGradient id="w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8a4a30"/><stop offset="1" stop-color="#5a2a1c"/></linearGradient><radialGradient id="l" cx=".7" cy=".3" r=".8"><stop offset="0" stop-color="#ffe3a3" stop-opacity=".4"/><stop offset="1" stop-color="#000" stop-opacity=".3"/></radialGradient></defs><rect width="1024" height="500" fill="url(#w)"/>'
	for i in 36:
		body += '<rect x="%d" y="0" width="2" height="380" fill="#000" opacity=".15"/>' % (i * 30)
	body += '<rect y="380" width="1024" height="120" fill="#4a2018"/><rect y="374" width="1024" height="12" fill="#2a120c"/><rect width="1024" height="500" fill="url(#l)"/>'
	var specials := [["pierre", 700, "ok"], ["madam", 820, "happy"], ["duchil", 950, "ok"]]
	var data = preload("res://scripts/core/game_data.gd").new()
	for sp in specials:
		body += '<g transform="translate(%d,215) scale(0.72)">%s</g>' % [sp[1], SvgArt.draw_char(SvgArt.look(data.specials[sp[0]]["L"]), sp[2])]
	body += '<g transform="translate(585,225) scale(0.82)">%s</g>' % SvgArt.draw_char(SvgArt.look(data.specials["granny"]["L"]), "happy")
	body += '<path d="M540 392 L1000 392 L985 480 L555 480Z" fill="#2f6a52"/>' + _coin(900, 440, 30) + _coin(850, 452, 22)
	data.free()
	var tex := TextureRect.new()
	tex.texture = SvgArt.rasterize(body, [0, 0, 1024, 500], 1.0)
	tex.size = Vector2(1024, 500)
	c.add_child(tex)
	var title := Label.new()
	title.text = "흥정왕 전당포"
	title.position = Vector2(48, 120)
	title.add_theme_font_override("font", load("res://assets/fonts/NotoSansKR-Black.otf"))
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Color("#ffe8a0"))
	title.add_theme_color_override("font_outline_color", Color("#2a120c"))
	title.add_theme_constant_override("outline_size", 16)
	c.add_child(title)
	var sub := Label.new()
	sub.text = "싸게 사서 비싸게 판다.\n손님의 속마음을 읽는 흥정 시뮬레이션"
	sub.position = Vector2(54, 236)
	sub.add_theme_font_override("font", load("res://assets/fonts/NotoSansKR-Bold.otf"))
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color("#fbefd9"))
	sub.add_theme_color_override("font_outline_color", Color("#2a120c"))
	sub.add_theme_constant_override("outline_size", 8)
	c.add_child(sub)
