extends Control
## 메인 화면 (세로 540x1170 설계 좌표). 딜러스라이프2의 흐름을 세로로 옮긴 「동양풍 우주 전당포」.
##   위: 대들보(장부 버튼 · 날짜 · 돈) → 말풍선 → 달문 창(우주) 앞의 손님 → 카운터(보자기 위 물건, 궤짝 창고)
##   아래 책상: 평소엔 선택지만. 흥정 중에만 물건 두루마리 · 가격 명패 · 도장(제안/최종/거절)이 나온다.
##   아침엔 「은하 일보」 방문(榜文) + 「문 열기」 현판. 메뉴는 「장부」 하나로 합쳤다.
## 그림·이름·대사는 전부 자체 제작. 게임 규칙은 GameState에 있고 여기는 그리기·입력만.

const GameState := preload("res://scripts/core/game_state.gd")
const SvgArt := preload("res://scripts/ui/svg_art.gd")
const ItemArt := preload("res://scripts/ui/item_art.gd")
const SfxScript := preload("res://scripts/ui/sfx.gd")
const W := 540.0
const H := 1170.0
const INK := Color("#2a1a10")
const CREAM := Color("#f3e8cc")
const HANJI := Color("#f1e6cb")
const LACQUER := Color("#2b1d1f")
const GOLD := Color("#d9a441")
const SEAL := Color("#b8322a")
const PRICE_POS := Vector2(110, 912)
const COUNTER_Y := 640.0
const DESK_Y := 800.0

var g: GameState
var D
var font_r: Font = preload("res://assets/fonts/NotoSansKR-Regular.otf")
var font_b: Font = preload("res://assets/fonts/NotoSerifKR-Bold.otf")
var font_k: Font = preload("res://assets/fonts/NotoSerifKR-Black.otf")
var font_sb: Font = preload("res://assets/fonts/NotoSansKR-Bold.otf")

var stage: Control
var back_tex: TextureRect
var queue_tex: Array = []
var cust_tex: TextureRect
var front_tex: TextureRect
var dyn: Control
var modal: Control
var toast_lbl: Label
var bob_tween: Tween
var _cache := {}
var _px := 2.0
var sfx
var _snap := {}  # 효과음 판단용 직전 상태


func _ready() -> void:
	D = get_node_or_null("/root/GameData")
	if D == null:
		D = preload("res://scripts/core/game_data.gd").new()
		add_child(D)
	g = GameState.new(D)
	if not g.load_game():
		g.start_day()
	_build()
	sfx = SfxScript.new()
	add_child(sfx)
	sfx.muted = bool(g.stats.get("muted", false))
	get_viewport().size_changed.connect(_layout)
	_layout()
	render()
	if g.phase == "night":
		show_receipt()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if g:
			g.save_game()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and modal and modal.visible:
		close_modal()


# ================================================================ 뼈대
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#120c14")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	stage = Control.new()
	stage.size = Vector2(W, H)
	stage.clip_contents = true
	add_child(stage)
	back_tex = _tex_rect(Vector2(0, 0), Vector2(W, H))
	for i in 2:
		queue_tex.append(_tex_rect(Vector2.ZERO, Vector2(100, 214)))
	cust_tex = _tex_rect(Vector2(120, 170), Vector2(300, 484))
	front_tex = _tex_rect(Vector2(0, COUNTER_Y - 12), Vector2(W, DESK_Y - COUNTER_Y + 12))
	dyn = Control.new()
	dyn.size = Vector2(W, H)
	dyn.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.add_child(dyn)
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	add_child(modal)
	toast_lbl = Label.new()
	toast_lbl.add_theme_font_override("font", font_b)
	toast_lbl.add_theme_font_size_override("font_size", 17)
	toast_lbl.add_theme_color_override("font_color", INK)
	toast_lbl.add_theme_stylebox_override("normal", _box(Color("#f6e7b8"), 3, Color("#6a3a22"), 4, 12))
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_lbl.visible = false
	toast_lbl.z_index = 50
	add_child(toast_lbl)


func _tex_rect(pos: Vector2, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.position = pos
	t.size = sz
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(t)
	return t


func _layout() -> void:
	var vs := get_viewport_rect().size
	var s := minf(vs.x / W, vs.y / H)
	stage.scale = Vector2(s, s)
	stage.position = Vector2((vs.x - W * s) / 2.0, (vs.y - H * s) / 2.0)
	var win := DisplayServer.window_get_size()
	var real := minf(win.x / W, win.y / H) if win.x > 0 else 2.0
	var px := clampf(snappedf(real, 0.5), 1.0, 3.0)
	if px != _px:
		_px = px
		_cache.clear()
		render()
	toast_lbl.position = Vector2(vs.x * 0.08, vs.y * 0.075)
	toast_lbl.size = Vector2(vs.x * 0.84, 0)


func _box(c: Color, border := 0, bc := Color.BLACK, radius := 8, pad := 8) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_border_width_all(border)
	b.border_color = bc
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(pad)
	return b


## 한지 판: 각진 모서리 + 먹선 테두리 + 아래쪽 그림자 (웹 카드처럼 둥글지 않게)
func _hanji(c := HANJI, bc := INK, border := 3, pad := 10) -> StyleBoxFlat:
	var b := _box(c, border, bc, 2, pad)
	b.shadow_color = Color(0, 0, 0, 0.35)
	b.shadow_size = 0
	b.shadow_offset = Vector2(0, 4)
	b.shadow_size = 1
	return b


func _raster(key: String, body: String, vb: Array) -> Texture2D:
	var k := "%s|%s|%s" % [key, body.hash(), _px]
	if _cache.has(k):
		return _cache[k]
	if _cache.size() > 60:
		_cache.clear()
	var t := SvgArt.rasterize(body, vb, _px)
	_cache[k] = t
	return t


func _icon(key: String) -> Texture2D:
	return _raster("ic_" + key, ItemArt.svg(key), [0, 0, 100, 100])


func lbl(text: String, pos: Vector2, size: Vector2, fs := 16, color := INK, font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, rot := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font if font else font_r)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.rotation_degrees = rot
	dyn.add_child(l)
	return l


func pic(tex: Texture2D, pos: Vector2, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture = tex
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dyn.add_child(r)
	return r


func hot(rect: Rect2, label: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.flat = true
	b.tooltip_text = label
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_stylebox_override("pressed", _box(Color(1, 1, 1, 0.15), 0, Color.BLACK, 6))
	b.pressed.connect(func(): _act(cb))
	dyn.add_child(b)
	return b


func _act(cb: Callable) -> void:
	var before := _state_snap()
	cb.call()
	_play_for(before, _state_snap())
	g.save_game()
	render()


func _state_snap() -> Dictionary:
	return {"name": g.cur.get("name", ""), "gone": g.cur.get("gone", false), "mood": g.cur.get("mood", ""), "money": g.money, "lv": g.lv, "rounds": g.neg.rounds if g.neg != null else 0}


func _play_for(a: Dictionary, b: Dictionary) -> void:
	if sfx == null:
		return
	if b["lv"] > a["lv"]:
		sfx.play("fanfare")
	elif b["gone"] and not a["gone"]:
		sfx.play("coin" if b["mood"] == "happy" else "buzz")
	elif b["name"] != a["name"] and b["name"] != "":
		sfx.play("door")
	elif b["rounds"] > a["rounds"]:
		sfx.play("tap")


func _flush_toasts() -> void:
	if g.messages.is_empty():
		return
	toast(g.messages[-1])
	g.messages.clear()


func toast(m: String) -> void:
	toast_lbl.text = m
	toast_lbl.visible = true
	var t := create_tween()
	t.tween_interval(2.4)
	t.tween_callback(func(): toast_lbl.visible = false)


# ================================================================ 렌더링
func render() -> void:
	if stage == null:
		return
	for c in dyn.get_children():
		c.queue_free()
	back_tex.texture = _raster("back", _back_svg(), [0, 0, W, H])
	_render_queue()
	_render_customer()
	front_tex.texture = _raster("front", _front_svg(), [0, COUNTER_Y - 12, W, DESK_Y - COUNTER_Y + 12])
	_render_counter()
	match g.phase:
		"morning":
			_render_morning()
		"night":
			_render_night()
		_:
			if not g.cur.is_empty():
				_render_dialog()
	_render_hud()
	_flush_toasts()


func _look_of(c: Dictionary) -> Dictionary:
	if c.has("look"):
		return SvgArt.look(c["look"])
	return SvgArt.customer_look2(c.get("arch", "seonbi"), c.get("tr", []), int(c.get("look_seed", 1)))


func _render_queue() -> void:
	var waiting: Array = g.upcoming if g.phase == "open" else []
	var spots := [Vector2(434, 418), Vector2(6, 418)]
	for i in 2:
		var t: TextureRect = queue_tex[i]
		if i < waiting.size():
			t.texture = _raster("q%d" % i, SvgArt.draw_char(_look_of(waiting[i]), "ok", true), SvgArt.STAND_VB)
			t.position = spots[i]
			t.size = Vector2(100, 214)
			t.modulate = Color(0.62, 0.6, 0.78)
			t.visible = true
		else:
			t.visible = false


func _render_customer() -> void:
	var c := g.cur
	if c.is_empty() or g.phase != "open":
		cust_tex.visible = false
		if bob_tween:
			bob_tween.kill()
		return
	var md := g.mood()
	cust_tex.texture = _raster("cust", SvgArt.draw_char(_look_of(c), md), SvgArt.CHAR_VB)
	cust_tex.visible = true
	if bob_tween:
		bob_tween.kill()
	cust_tex.position = Vector2(120, 170)
	bob_tween = create_tween().set_loops()
	if md == "angry" and not c.get("gone", false):
		bob_tween.tween_property(cust_tex, "position:x", 112.0, 0.06)
		bob_tween.tween_property(cust_tex, "position:x", 128.0, 0.12)
		bob_tween.tween_property(cust_tex, "position:x", 120.0, 0.06)
		bob_tween.tween_interval(1.6)
	else:
		bob_tween.tween_property(cust_tex, "position:y", 175.0, 1.7).set_trans(Tween.TRANS_SINE)
		bob_tween.tween_property(cust_tex, "position:y", 170.0, 1.7).set_trans(Tween.TRANS_SINE)
	if not c.get("visitor", false):
		hot(Rect2(160, 300, 220, 320), "손님 성향 보기", func(): show_traits())


## 뒷배경: 한옥 전당포 안쪽. 가운데 달문(둥근 창) 너머로 우주가 보이고, 양옆은 창호지 문과 기둥.
func _back_svg() -> String:
	var wall: String = g.shop_info().get("wall", "#3a3458")
	var s := '<defs>'
	s += '<radialGradient id="sky" cx=".5" cy=".45" r=".6"><stop offset="0" stop-color="#4a3a8a"/><stop offset=".55" stop-color="#1e1a48"/><stop offset="1" stop-color="#0a0a1c"/></radialGradient>'
	s += '<radialGradient id="neb" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#e86aa8" stop-opacity=".55"/><stop offset="1" stop-color="#e86aa8" stop-opacity="0"/></radialGradient>'
	s += '<radialGradient id="neb2" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#5ad8e8" stop-opacity=".45"/><stop offset="1" stop-color="#5ad8e8" stop-opacity="0"/></radialGradient>'
	s += '<linearGradient id="paper" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f6dca0"/><stop offset="1" stop-color="#d9a868"/></linearGradient>'
	s += '<linearGradient id="wood" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#4a2a1a"/><stop offset=".5" stop-color="#6a3e26"/><stop offset="1" stop-color="#3a2014"/></linearGradient>'
	s += '<linearGradient id="desk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5a3420"/><stop offset="1" stop-color="#2e1a10"/></linearGradient>'
	s += '<radialGradient id="glow" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#ffd890" stop-opacity=".55"/><stop offset="1" stop-color="#ffd890" stop-opacity="0"/></radialGradient>'
	s += '</defs>'
	# 벽
	s += '<rect width="540" height="%d" fill="%s"/>' % [int(DESK_Y), wall]
	# 창호지 문 (양옆)
	for x in [0, 430]:
		s += '<rect x="%d" y="96" width="110" height="560" fill="url(#paper)"/>' % x
		for i in 7:
			s += '<path d="M%d %d L%d %d" stroke="#5a3420" stroke-width="4"/>' % [x, 96 + i * 80, x + 110, 96 + i * 80]
		for j in 3:
			s += '<path d="M%d 96 L%d 656" stroke="#5a3420" stroke-width="4"/>' % [x + 10 + j * 45, x + 10 + j * 45]
	# 대기 손님이 서는 문틈(어두운 틈)
	s += '<rect x="440" y="400" width="90" height="250" fill="#1a1020" opacity=".55"/><rect x="10" y="400" width="90" height="250" fill="#1a1020" opacity=".55"/>'
	# 달문(둥근 창) 너머 우주
	s += '<circle cx="270" cy="360" r="196" fill="#3a2014"/><circle cx="270" cy="360" r="184" fill="url(#sky)"/>'
	s += '<ellipse cx="200" cy="300" rx="150" ry="80" fill="url(#neb)" transform="rotate(-20 200 300)"/><ellipse cx="350" cy="420" rx="120" ry="70" fill="url(#neb2)"/>'
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for i in 70:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * 178.0
		s += '<circle cx="%s" cy="%s" r="%s" fill="#fff" opacity="%s"/>' % [SvgArt.n(270 + cos(a) * d), SvgArt.n(360 + sin(a) * d), SvgArt.n(r.randf_range(0.6, 2.2)), SvgArt.n(r.randf_range(0.4, 1.0))]
	# 고리 행성 + 작은 달 + 떠다니는 등롱
	s += '<circle cx="372" cy="250" r="38" fill="#e8a060"/><path d="M340 240 Q372 230 404 248" stroke="#c87840" stroke-width="5" fill="none" opacity=".6"/><ellipse cx="372" cy="254" rx="66" ry="14" fill="none" stroke="#f6d8a0" stroke-width="5" transform="rotate(-14 372 254)"/>'
	s += '<circle cx="160" cy="240" r="14" fill="#d8d8e8"/><circle cx="155" cy="236" r="3" fill="#a8a8c0"/>'
	for p in [[205, 420], [330, 470], [140, 470]]:
		s += '<g transform="translate(%d,%d)"><circle r="22" fill="url(#glow)"/><rect x="-6" y="-10" width="12" height="18" rx="5" fill="#e8503a"/><rect x="-6" y="-1" width="12" height="3" fill="#2a1a14"/></g>' % p
	# 달문 창살 테두리
	s += '<circle cx="270" cy="360" r="184" fill="none" stroke="#5a3420" stroke-width="10"/><circle cx="270" cy="360" r="196" fill="none" stroke="#2a1a14" stroke-width="4"/>'
	# 기둥과 대들보
	s += '<rect x="108" y="60" width="22" height="600" fill="url(#wood)"/><rect x="410" y="60" width="22" height="600" fill="url(#wood)"/>'
	s += '<rect x="0" y="60" width="540" height="36" fill="url(#wood)"/><path d="M0 96 L540 96" stroke="#2a1a14" stroke-width="4"/>'
	for x in [40, 150, 270, 390, 500]:
		s += '<rect x="%d" y="66" width="22" height="24" fill="#2a6a5a"/><rect x="%d" y="70" width="14" height="16" fill="#d8a840"/>' % [x - 11, x - 7]
	# 처마 등롱 (양옆 위)
	for x in [60, 480]:
		s += '<path d="M%d 96 L%d 118" stroke="#2a1a14" stroke-width="3"/><circle cx="%d" cy="150" r="46" fill="url(#glow)"/><rect x="%d" y="118" width="40" height="56" rx="18" fill="#d8402e" stroke="#2a1a14" stroke-width="3"/><path d="M%d 134 L%d 134 M%d 158 L%d 158" stroke="#2a1a14" stroke-width="3"/><path d="M%d 174 L%d 190" stroke="#e0b040" stroke-width="4"/>' % [x, x, x, x - 20, x - 20, x + 20, x - 20, x + 20, x, x]
	# 아래 책상(손님 앞 작업대)
	s += '<rect y="%d" width="540" height="%d" fill="url(#desk)"/>' % [int(DESK_Y), int(H - DESK_Y)]
	for i in 9:
		s += '<path d="M0 %d Q270 %d 540 %d" stroke="#1e1008" stroke-opacity=".35" stroke-width="2" fill="none"/>' % [int(DESK_Y) + 30 + i * 40, int(DESK_Y) + 20 + i * 40 + (i % 3) * 8, int(DESK_Y) + 34 + i * 40]
	return s


## 카운터(손님 아랫몸을 가림): 짙은 나무 + 놋쇠 장식 + 가운데 보자기
func _front_svg() -> String:
	var it := g.cur_item()
	var y0 := COUNTER_Y
	var s := '<defs><linearGradient id="ct" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7a4426"/><stop offset="1" stop-color="#3a1e10"/></linearGradient></defs>'
	s += '<rect y="%s" width="540" height="18" fill="#9a5a32" stroke="#2a1a14" stroke-width="3"/>' % SvgArt.n(y0 - 10)
	s += '<rect y="%s" width="540" height="160" fill="url(#ct)"/>' % SvgArt.n(y0 + 8)
	for x in [20, 520]:
		s += '<rect x="%d" y="%s" width="10" height="150" fill="#2a1a14" opacity=".4"/>' % [x - 5, SvgArt.n(y0 + 8)]
	for x in [150, 390]:
		s += '<circle cx="%d" cy="%s" r="9" fill="#d8a840" stroke="#2a1a14" stroke-width="2"/>' % [x, SvgArt.n(y0 + 90)]
	# 보자기
	var cloth := "#2a4a8a" if it.is_empty() else str(D.items["rarity"][int(it["r"])]["c"])
	s += '<path d="M190 %s L350 %s L370 %s L170 %s Z" fill="%s" stroke="#2a1a14" stroke-width="3"/>' % [SvgArt.n(y0 - 8), SvgArt.n(y0 - 8), SvgArt.n(y0 + 70), SvgArt.n(y0 + 70), cloth]
	s += '<path d="M200 %s L340 %s" stroke="#fff" stroke-opacity=".35" stroke-width="3" stroke-dasharray="6 5"/>' % [SvgArt.n(y0 + 8), SvgArt.n(y0 + 8)]
	# 궤짝(창고)
	s += '<rect x="22" y="%s" width="120" height="96" rx="4" fill="#6a3a1e" stroke="#2a1a14" stroke-width="3"/><path d="M22 %s L142 %s" stroke="#2a1a14" stroke-width="3"/><rect x="70" y="%s" width="24" height="18" rx="3" fill="#d8a840" stroke="#2a1a14" stroke-width="2"/>' % [SvgArt.n(y0 + 20), SvgArt.n(y0 + 46), SvgArt.n(y0 + 46), SvgArt.n(y0 + 38)]
	# 주판(장식)
	s += '<g transform="translate(400,%s)"><rect width="118" height="60" rx="4" fill="none" stroke="#5a3420" stroke-width="6"/>' % SvgArt.n(y0 + 30)
	for c in 7:
		s += '<path d="M%d 0 L%d 60" stroke="#2a1a14" stroke-width="2"/><circle cx="%d" cy="12" r="5" fill="#d8402e"/><circle cx="%d" cy="%d" r="5" fill="#e8d8b0"/>' % [12 + c * 16, 12 + c * 16, 12 + c * 16, 12 + c * 16, 34 + (c % 3) * 7]
	s += '</g>'
	return s


func _render_hud() -> void:
	# 대들보 위: [장부] · 날짜/가게 · 돈
	var top := ColorRect.new()
	top.color = Color("#1e1218")
	top.position = Vector2.ZERO
	top.size = Vector2(W, 60)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dyn.add_child(top)
	var line := ColorRect.new()
	line.color = GOLD.darkened(0.3)
	line.position = Vector2(0, 58)
	line.size = Vector2(W, 2)
	dyn.add_child(line)
	_stamp(Rect2(10, 6, 96, 48), "장부" + (" ●" if g.sp > 0 else ""), SEAL, func(): pass, 19)
	(dyn.get_child(dyn.get_child_count() - 1) as Button).pressed.connect(func(): show_menu())
	lbl("%d일째" % g.day, Vector2(150, 4), Vector2(170, 30), 21, HANJI, font_k, HORIZONTAL_ALIGNMENT_CENTER)
	lbl(g.shop_info()["n"], Vector2(130, 32), Vector2(210, 22), 13, GOLD, font_b, HORIZONTAL_ALIGNMENT_CENTER)
	pic(_icon("coins"), Vector2(352, 10), Vector2(40, 40))
	lbl(GameState.fmt(g.money), Vector2(392, 10), Vector2(140, 40), 21, Color("#ff8a6a") if g.money < 0 else Color("#ffe2a0"), font_k, HORIZONTAL_ALIGNMENT_RIGHT)


func _render_counter() -> void:
	var it := g.cur_item()
	lbl("창고 %d/%d" % [g.inv.size(), g.cap()], Vector2(22, COUNTER_Y + 70), Vector2(120, 40), 16, Color("#ff9a7a") if g.inv.size() >= g.cap() else HANJI, font_k, HORIZONTAL_ALIGNMENT_CENTER)
	hot(Rect2(16, COUNTER_Y + 10, 132, 120), "창고 열기", func(): show_inv())
	if not it.is_empty() and g.phase == "open":
		pic(_icon(it["e"]), Vector2(200, COUNTER_Y - 70), Vector2(140, 140))
		if it["known"] and it["fake"]:
			lbl("가품", Vector2(220, COUNTER_Y - 30), Vector2(100, 44), 28, SEAL, font_k, HORIZONTAL_ALIGNMENT_CENTER, -14)
		hot(Rect2(180, COUNTER_Y - 80, 180, 160), "물건 살펴보기", func(): show_inspect(it))


func _on_sign_drag(ev: InputEvent) -> void:
	if not g.is_haggling():
		return
	var dx := 0.0
	if ev is InputEventScreenDrag:
		dx = ev.relative.x
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		dx = ev.relative.x
	if dx == 0.0:
		return
	var step := maxf(10.0, g.their_price() * 0.005)
	g.draft = maxi(10, GameState.r10(g.draft + dx * step / 2.0))
	_refresh_price()


func _refresh_price() -> void:
	for c in dyn.get_children():
		if c is Label and c.position == PRICE_POS:
			c.text = GameState.fmt(g.draft)


# ---------------------------------------------------------------- 말풍선 + 아래 책상
func _tag_style() -> Array:
	var c := g.cur
	if c.get("visitor", false):
		return ["손님 · " + c["name"], Color("#d9a441")]
	if c.get("pawn", false):
		return ["전당 · " + c["name"], Color("#d9a441")]
	if c.get("sk", "") != "":
		return ["단골 · " + c["name"], Color("#9a7ad8")]
	return [("사러 옴 · " if c["buy"] else "팔러 옴 · ") + c["name"], Color("#6aa85a") if c["buy"] else Color("#c8604a")]


func _render_dialog() -> void:
	var c := g.cur
	var ts := _tag_style()
	# 말풍선 (한지 + 먹선, 아래로 꼬리)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _hanji(HANJI, INK, 3, 12))
	box.position = Vector2(18, 72)
	box.size = Vector2(504, 0)
	box.custom_minimum_size = Vector2(504, 92)
	var bl := Label.new()
	bl.text = c["msg"]
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bl.custom_minimum_size = Vector2(478, 66)
	bl.add_theme_font_override("font", font_b)
	bl.add_theme_font_size_override("font_size", 18)
	bl.add_theme_color_override("font_color", INK)
	box.add_child(bl)
	dyn.add_child(box)
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(250, 0), Vector2(290, 0), Vector2(268, 22)])
	tail.color = HANJI
	dyn.add_child(tail)
	box.resized.connect(func(): tail.position = Vector2(0, box.position.y + box.size.y - 3))
	tail.position = Vector2(0, 72 + 92 - 3)
	# 이름표 (말풍선 왼쪽 위에 걸친 붉은 띠)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", _box(ts[1], 2, INK, 2, 3))
	tag.position = Vector2(30, 60)
	var tl := Label.new()
	tl.text = "  %s  " % ts[0]
	tl.add_theme_font_override("font", font_k)
	tl.add_theme_font_size_override("font_size", 14)
	tl.add_theme_color_override("font_color", Color("#fff8e8"))
	tag.add_child(tl)
	dyn.add_child(tag)
	if c.get("stage", "") == "haggle" and not c["gone"] and not c.get("visitor", false):
		_render_haggle_desk()
	else:
		var y := DESK_Y + 34.0
		for o in _choices():
			_choice(Rect2(40, y, 460, 58), o[0], o[1], o.size() > 2 and o[2])
			y += 70.0


## [표시 문구, 동작, 특수 선택지 여부]
func _choices() -> Array:
	var c := g.cur
	if c.get("visitor", false):
		if c["gone"]:
			return [["계속", func(): g.open_shop()]]
		var out: Array = []
		for i in c["opts"].size():
			out.append([c["opts"][i], func(): g.visit_pick(i)])
		return out
	if c["gone"]:
		return [["다음 손님", func(): g.next_customer()]]
	match c.get("stage", "intro"):
		"intro":
			return [["한번 봅시다", func():
				g.look_item()
				show_inspect(g.cur_item())], ["관심 없소", func(): g.refuse()]]
		"look":
			return [["흥정해 봅시다!", func(): g.start_haggle()], ["관심 없소", func(): g.refuse()]]
		_:
			var out: Array = [[("%s 빌려드리리다" if c.get("pawn", false) else "%s에 하리다") % GameState.fmt(g.their_price()), func(): g.accept()]]
			var it := g.cur_item()
			if not c["buy"] and not it.is_empty() and (it["suspect"] or (it["known"] and it["fake"])) and not c["accused"]:
				out.append(["가짜 같은데?", func(): g.accuse(), true])
			for sp in g.special_options():
				var sid: String = sp[0]
				out.append([sp[1], func(): g.use_special(sid), true])
			out.append(["관심 없소", func(): g.refuse()])
			return out


func _choice(rect: Rect2, text: String, cb: Callable, special := false, fs := 19) -> void:
	var paper := "#dfe6f2" if special else "#f1e6cb"
	var skin := pic(_raster("slip", _slip_svg(rect.size, paper, text.hash()), [0, 0, rect.size.x, rect.size.y]), rect.position, rect.size)
	var b := _skinned_button(rect, text, cb, skin, font_b, fs, Color("#23306a") if special else INK)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## 그림 위에 투명 버튼을 얹는다. 누르면 그림이 살짝 눌린다.
func _skinned_button(rect: Rect2, text: String, cb: Callable, skin: TextureRect, font: Font, fs: int, fg: Color, raw := false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", fs)
	for st in ["font_color", "font_pressed_color", "font_hover_color"]:
		b.add_theme_color_override(st, fg)
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	b.button_down.connect(func():
		skin.modulate = Color(0.82, 0.82, 0.82)
		skin.position.y += 2)
	b.button_up.connect(func():
		skin.modulate = Color.WHITE
		skin.position.y = rect.position.y)
	if raw:
		b.pressed.connect(cb)
	else:
		b.pressed.connect(func(): _act(cb))
	dyn.add_child(b)
	return b


## 결이 있는 한지 쪽지: 들쭉날쭉한 가장자리, 붓 테두리, 섬유 무늬
func _slip_svg(sz: Vector2, paper: String, seed_v: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var w := sz.x
	var h := sz.y
	var pts: Array = []
	var step := 14.0
	var x := 2.0
	while x < w - 2:
		pts.append([x, 2 + rng.randf_range(-1.2, 1.6)])
		x += step
	pts.append([w - 2, 2.5])
	var y := 2.0
	while y < h - 2:
		pts.append([w - 2 + rng.randf_range(-1.4, 0.8), y])
		y += step
	pts.append([w - 2.5, h - 4])
	x = w - 2
	while x > 2:
		pts.append([x, h - 4 + rng.randf_range(-1.2, 1.4)])
		x -= step
	pts.append([2.5, h - 4])
	y = h - 4
	while y > 2:
		pts.append([2 + rng.randf_range(-0.8, 1.4), y])
		y -= step
	var d := "M"
	for p in pts:
		d += "%s,%s " % [SvgArt.n(p[0]), SvgArt.n(p[1])]
	d += "Z"
	var out := '<path d="%s" transform="translate(1.5,3)" fill="#000" opacity="0.32"/>' % d
	out += '<path d="%s" fill="%s"/>' % [d, paper]
	for i in int(w / 18):
		var fx := rng.randf_range(6, w - 6)
		var fy := rng.randf_range(6, h - 8)
		out += '<path d="M%s,%s q%s,%s %s,%s" stroke="#a08a60" stroke-width="0.7" fill="none" opacity="0.35"/>' % [SvgArt.n(fx), SvgArt.n(fy), SvgArt.n(rng.randf_range(3, 8)), SvgArt.n(rng.randf_range(-3, 3)), SvgArt.n(rng.randf_range(8, 16)), SvgArt.n(rng.randf_range(-2, 2))]
	out += '<path d="%s" fill="none" stroke="#2a1a10" stroke-width="2.6" stroke-linejoin="round" opacity="0.9"/>' % d
	out += '<rect x="7" y="7" width="%s" height="%s" fill="none" stroke="#8a6a40" stroke-width="0.8" opacity="0.5"/>' % [SvgArt.n(w - 14), SvgArt.n(h - 17)]
	return out


## 인주 도장: 거친 테두리, 안쪽 이중선, 인주가 덜 묻은 얼룩
func _seal_svg(sz: Vector2, col: String, seed_v: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var w := sz.x
	var h := sz.y
	var d := "M%s,%s L%s,%s L%s,%s L%s,%s Z" % [SvgArt.n(3 + rng.randf()), SvgArt.n(3 + rng.randf()), SvgArt.n(w - 3 - rng.randf()), SvgArt.n(3 + rng.randf()), SvgArt.n(w - 3 - rng.randf()), SvgArt.n(h - 6 - rng.randf()), SvgArt.n(3 + rng.randf()), SvgArt.n(h - 6 - rng.randf())]
	var out := '<path d="%s" transform="translate(1,4)" fill="#000" opacity="0.4"/>' % d
	out += '<path d="%s" fill="%s" stroke="#1a0e08" stroke-width="2" stroke-linejoin="round"/>' % [d, col]
	out += '<rect x="8" y="8" width="%s" height="%s" rx="2" fill="none" stroke="#fff1d8" stroke-width="2.2" opacity="0.85"/>' % [SvgArt.n(w - 16), SvgArt.n(h - 20)]
	out += '<rect x="12" y="12" width="%s" height="%s" rx="1" fill="none" stroke="#fff1d8" stroke-width="0.9" opacity="0.6"/>' % [SvgArt.n(w - 24), SvgArt.n(h - 28)]
	for i in int(w * h / 900.0):
		out += '<circle cx="%s" cy="%s" r="%s" fill="#fff1d8" opacity="%s"/>' % [SvgArt.n(rng.randf_range(6, w - 6)), SvgArt.n(rng.randf_range(6, h - 10)), SvgArt.n(rng.randf_range(0.6, 2.2)), SvgArt.n(rng.randf_range(0.12, 0.3))]
	out += '<path d="M10,%s h%s" stroke="#000" stroke-width="3" opacity="0.15"/>' % [SvgArt.n(h - 12), SvgArt.n(w - 20)]
	return out


## 나무 현판: 결무늬 + 금박 테두리
func _board_svg(sz: Vector2, wood: String, rim: String) -> String:
	var w := sz.x
	var h := sz.y
	var out := '<rect x="3" y="7" width="%s" height="%s" rx="6" fill="#000" opacity="0.45"/>' % [SvgArt.n(w - 4), SvgArt.n(h - 8)]
	out += '<rect x="2" y="2" width="%s" height="%s" rx="6" fill="%s" stroke="#120a06" stroke-width="3"/>' % [SvgArt.n(w - 4), SvgArt.n(h - 8), wood]
	for i in 7:
		var yy := 10.0 + i * (h - 20) / 7.0
		out += '<path d="M10,%s C%s,%s %s,%s %s,%s" stroke="#000" stroke-width="1" fill="none" opacity="0.18"/>' % [SvgArt.n(yy), SvgArt.n(w * 0.3), SvgArt.n(yy - 4 + i % 3 * 3), SvgArt.n(w * 0.6), SvgArt.n(yy + 5), SvgArt.n(w - 10), SvgArt.n(yy + 1)]
	out += '<rect x="9" y="9" width="%s" height="%s" rx="3" fill="none" stroke="%s" stroke-width="3"/>' % [SvgArt.n(w - 18), SvgArt.n(h - 22), rim]
	for c in [[14, 14], [w - 14, 14], [14, h - 19], [w - 14, h - 19]]:
		out += '<circle cx="%s" cy="%s" r="3" fill="%s"/>' % [SvgArt.n(c[0]), SvgArt.n(c[1]), rim]
	return out


## 흥정 중 아래 책상: 두루마리(물건 정보) · 가격 명패 · 도장 세 개 · 수 선택지
func _render_haggle_desk() -> void:
	var it := g.cur_item()
	if it.is_empty() or g.neg == null:
		return
	var pawn: bool = g.cur.get("pawn", false)
	# 두루마리
	pic(_raster("scroll", _slip_svg(Vector2(508, 100), "#f1e6cb", 7), [0, 0, 508, 100]), Vector2(16, DESK_Y + 4), Vector2(508, 100))
	for x in [8.0, 524.0]:
		var rod := ColorRect.new()
		rod.color = Color("#5a3420")
		rod.position = Vector2(x, DESK_Y + 2)
		rod.size = Vector2(8, 104)
		dyn.add_child(rod)
	var rar: Dictionary = D.items["rarity"][int(it["r"])]
	var e := g.est(it)
	var est_s: String = GameState.fmt(g.val(it, false)) if it["known"] else "%s~%s" % [GameState.fmt(e[0]), GameState.fmt(e[1])]
	lbl(it["name"], Vector2(34, DESK_Y + 14), Vector2(260, 26), 17, INK, font_k)
	lbl("%s · %s" % [rar["n"], D.items["condition"][int(it["c"])]["n"]], Vector2(34, DESK_Y + 40), Vector2(260, 22), 14, Color(rar["c"]).darkened(0.25), font_sb)
	var extra := ""
	if g.cur.has("read"):
		extra = "  속마음 %s~%s" % [GameState.fmt(g.cur["read"][0]), GameState.fmt(g.cur["read"][1])]
	if pawn:
		extra = "  %d일 · 상환 %d%%" % [g.cur["days"], int(round((1.1 + 0.03 * g.cur["days"]) * 100))]
	lbl("견적 %s%s" % [est_s, extra], Vector2(34, DESK_Y + 64), Vector2(470, 24), 14, Color("#1f5a56"), font_sb)
	lbl("빌려 달라는 돈" if pawn else ("손님 부른 값"), Vector2(300, DESK_Y + 12), Vector2(206, 20), 12, Color("#6a5a4a"), font_sb, HORIZONTAL_ALIGNMENT_RIGHT)
	lbl(GameState.fmt(g.their_price()), Vector2(290, DESK_Y + 30), Vector2(216, 34), 24, SEAL, font_k, HORIZONTAL_ALIGNMENT_RIGHT)
	# 인내심: 타들어 가는 향
	var m := g.neg.patience_ratio()
	var stick := ColorRect.new()
	stick.color = Color("#7a5a3a")
	stick.position = Vector2(34, DESK_Y + 88)
	stick.size = Vector2(472, 5)
	dyn.add_child(stick)
	var burn := ColorRect.new()
	burn.color = Color("#6aa85a") if m > 0.66 else (Color("#d9a441") if m > 0.33 else Color("#d8402e"))
	burn.position = Vector2(34, DESK_Y + 88)
	burn.size = Vector2(472 * clampf(m, 0, 1), 5)
	dyn.add_child(burn)
	if g.has_staff("profiler"):
		lbl("인내심 %d/%d" % [maxi(0, int(g.neg.patience)), int(g.neg.max_patience)], Vector2(380, DESK_Y + 64), Vector2(126, 24), 12, Color("#6a5a4a"), font_sb, HORIZONTAL_ALIGNMENT_RIGHT)
	# 가격 명패: [-] 명패 [+]
	var py := DESK_Y + 112.0
	_stamp(Rect2(16, py, 84, 60), "−", Color("#5a3420"), func():
		g.draft = maxi(10, GameState.r10(g.draft - maxf(10.0, g.their_price() * 0.05))), 30)
	_stamp(Rect2(440, py, 84, 60), "+", Color("#5a3420"), func():
		g.draft = GameState.r10(g.draft + maxf(10.0, g.their_price() * 0.05)), 30)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _box(Color("#e8c890"), 4, INK, 3, 2))
	plate.position = Vector2(108, py)
	plate.custom_minimum_size = Vector2(324, 60)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dyn.add_child(plate)
	lbl(GameState.fmt(g.draft), PRICE_POS, Vector2(320, 58), 30, INK, font_k, HORIZONTAL_ALIGNMENT_CENTER)
	var pb := hot(Rect2(108, py, 324, 60), "내 제시 가격: 좌우로 끌어 조정, 눌러서 직접 입력", func(): show_keypad())
	pb.gui_input.connect(_on_sign_drag)
	lbl("내 제시 값 · 끌거나 눌러서 입력", Vector2(108, py + 60), Vector2(324, 18), 11, Color("#e8c890"), font_sb, HORIZONTAL_ALIGNMENT_CENTER)
	# 도장 세 개
	var sy := py + 84.0
	_stamp(Rect2(16, sy, 160, 72), "제안", SEAL, func(): g.propose(g.draft))
	_stamp(Rect2(190, sy, 160, 72), "최종 제안", Color("#8a6a1a"), func():
		sfx.play("bell")
		g.propose(g.draft, true))
	_stamp(Rect2(364, sy, 160, 72), "거절", Color("#2a2a34"), func(): g.refuse())
	# 수(특수 선택지 + 손님 값 수락) — 2열
	var opts := _choices().filter(func(o): return o[0] != "관심 없소")
	var oy := sy + 86.0
	var rows := int(ceil(opts.size() / 2.0))
	var hgt := clampf((H - 8 - oy) / maxf(1, rows) - 8, 34, 54)
	for i in opts.size():
		var o: Array = opts[i]
		_choice(Rect2(16 + (i % 2) * 258, oy + (i / 2) * (hgt + 8), 250, hgt), o[0], o[1], o.size() > 2 and o[2], 15)


## 도장 모양 버튼 (인주 그림 위에 글자)
func _stamp(rect: Rect2, text: String, c: Color, cb: Callable, fs := 22) -> void:
	var skin := pic(_raster("seal", _seal_svg(rect.size, "#" + c.to_html(false), text.hash()), [0, 0, rect.size.x, rect.size.y]), rect.position, rect.size)
	var b := _skinned_button(rect, text, cb, skin, font_k, fs, Color("#fff4dc"))
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))


## 나무 현판 버튼 (문 열기 · 마감)
func _board(rect: Rect2, text: String, cb: Callable, fs := 40, raw := false) -> Button:
	var skin := pic(_raster("board", _board_svg(rect.size, "#3a2418", "#d9a441"), [0, 0, rect.size.x, rect.size.y]), rect.position, rect.size)
	var b := _skinned_button(rect, text, cb, skin, font_k, fs, Color("#f6d27a"), raw)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_color_override("font_outline_color", Color("#120a06"))
	return b


# ---------------------------------------------------------------- 아침·밤
func _render_morning() -> void:
	_render_newspaper()
	_board(Rect2(110, DESK_Y + 150, 320, 116), "문 열기", func(): g.flip_open(), 44)
	lbl("현판을 눌러 가게 문을 엽니다", Vector2(60, DESK_Y + 268), Vector2(420, 24), 14, HANJI, font_b, HORIZONTAL_ALIGNMENT_CENTER)


## 아침 방문(榜文): 「은하 일보」. 시세·경매·구인·팁을 붙인 종이 쪽지.
func _render_newspaper() -> void:
	var n := g.news
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", _hanji(Color("#efe2c2"), INK, 4, 12))
	paper.position = Vector2(24, 108)
	paper.custom_minimum_size = Vector2(492, 0)
	dyn.add_child(paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	paper.add_child(v)
	var mast := Label.new()
	mast.text = "은하 일보"
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mast.add_theme_font_override("font", font_k)
	mast.add_theme_font_size_override("font_size", 36)
	mast.add_theme_color_override("font_color", Color("#1d1915"))
	v.add_child(mast)
	var sub := Label.new()
	sub.text = "%d일째 ─ %s" % [g.day, n.get("head", "")]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(460, 0)
	sub.add_theme_font_override("font", font_b)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color("#1d1915"))
	v.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var cats: Dictionary = D.items["categories"]
	var items: Array = []
	if n.has("up"):
		items.append(["▲ %s" % cats[n["up"]]["n"], cats[n["up"]]["up"], func(): g.toast("%s 시세 상승! 이 종류는 비싸게 팔 수 있어요." % cats[n["up"]]["n"]), Color("#1d6a3a"), false])
		items.append(["▼ %s" % cats[n["dn"]]["n"], cats[n["dn"]]["dn"], func(): g.toast("%s 시세 하락. 싸게 사 두기 좋은 날일지도." % cats[n["dn"]]["n"]), Color("#a0301e"), false])
	if g.is_auction_today():
		items.append(["경매 방", "오늘 은하 경매장 · 참가비 %s" % GameState.fmt(g.auction_fee()), func(): _open_auction(), Color("#8a1a2a"), true])
	if g.has_staff("analyst"):
		items.append(["시세꾼 쪽지", "내일은 %s이(가) 뜹니다" % cats[g.next_up]["n"], func(): pass, Color("#6b4126"), false])
	var ads: Array = D.staff.keys().filter(func(k): return not g.has_staff(k))
	for ai in mini(2, ads.size()):
		var k: String = ads[(g.day + ai) % ads.size()]
		if true:
			items.append(["%s 구함" % D.staff[k]["n"], "%s · 일급 %s" % [D.staff[k]["pn"], GameState.fmt(D.staff[k]["w"])], func(): show_hire(k), Color("#2a5a6a"), true])
	if D.tips.size() > 0:
		var tip_i: int = int(n.get("tip", 0)) % D.tips.size()
		items.append(["오늘의 비결 #%d" % (tip_i + 1), "눌러서 읽기", func(): g.toast(D.tips[tip_i]), Color("#5a3a8a"), true])
	for i in mini(items.size(), 6):
		var it: Array = items[i]
		var b := Button.new()
		b.text = "%s\n%s" % [it[0], it[1]]
		b.custom_minimum_size = Vector2(230, 84)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", font_b)
		b.add_theme_font_size_override("font_size", 15)
		for st in ["font_color", "font_pressed_color", "font_hover_color"]:
			b.add_theme_color_override(st, it[3])
		var ad: bool = it[4]
		var bc := SEAL if ad else Color("#b8ad94")
		b.add_theme_stylebox_override("normal", _box(Color("#efe2c2"), 3 if ad else 1, bc, 2, 4))
		b.add_theme_stylebox_override("hover", _box(Color("#f6ecd4"), 3 if ad else 1, bc, 2, 4))
		b.add_theme_stylebox_override("pressed", _box(Color("#e0d2b0"), 3 if ad else 1, bc, 2, 4))
		var cb: Callable = it[2]
		b.pressed.connect(func():
			cb.call()
			g.save_game()
			_flush_toasts())
		grid.add_child(b)


func _render_night() -> void:
	lbl("오늘 장사는 여기까지", Vector2(40, 300), Vector2(460, 60), 30, HANJI, font_k, HORIZONTAL_ALIGNMENT_CENTER)
	_board(Rect2(70, DESK_Y + 120, 400, 106), "마감 · 영수증 보기", func(): show_receipt(), 28, true)


## 장부: 모든 메뉴를 한곳에
func show_menu() -> void:
	var v := sheet(HANJI, INK, INK, true, 500)
	t(v, "장부", 30, font_k, null, HORIZONTAL_ALIGNMENT_CENTER)
	t(v, "Lv.%d · 평판 %d · 금고 %s" % [g.lv, g.rep, GameState.fmt(g.money)], 15, font_b, null, HORIZONTAL_ALIGNMENT_CENTER)
	for e in [["창고", "사들인 물건 · 감정 · 수리 · 도매 처분", func(): show_inv()], ["사장 수첩", "기술 올리기 · 가게 이전 · 단골 · 설정" + (" ●" if g.sp > 0 else ""), func(): show_ledger()], ["셈판", "오늘 · 최근 7일 · 전체 수입과 지출", func(): show_stats("today")], ["보물 도감", "모은 물건 %d/%d" % [g.collection.size(), g.collection_total()], func(): show_collection()], ["일꾼", "고용한 직원 %d/%d" % [g.staff.size(), g.staff_slots()], func(): show_staff()]]:
		var b := btn(v, "%s\n%s" % [e[0], e[1]], e[2], Color("#3a2430"), HANJI)
		b.custom_minimum_size = Vector2(0, 74)


# ================================================================ 오버레이
func close_modal() -> void:
	modal.visible = false
	for c in modal.get_children():
		c.queue_free()
	render()


func sheet(bgc: Color, ink: Color, border := Color("#6b4126"), closable := true, wdt := 720.0) -> VBoxContainer:
	for c in modal.get_children():
		c.queue_free()
	modal.visible = true
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.02, 0.01, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var vs := get_viewport_rect().size
	var ww := minf(vs.x - 24, wdt)
	# 밝은 판은 한지, 어두운 판은 옻칠(검붉은 칠 + 금테)로 통일
	var dark := bgc.get_luminance() < 0.4
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(LACQUER if dark else HANJI, 6, GOLD.darkened(0.1) if dark else Color("#5a3420"), 3, 16))
	panel.position = Vector2((vs.x - ww) / 2, 14)
	panel.size = Vector2(ww, vs.y - 28)
	modal.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	v.set_meta("ink", ink)
	sc.add_child(v)
	if closable:
		var x := Button.new()
		x.text = "닫기 ✕"
		x.flat = true
		x.add_theme_font_override("font", font_b)
		x.add_theme_font_size_override("font_size", 17)
		x.add_theme_color_override("font_color", ink)
		x.size_flags_horizontal = Control.SIZE_SHRINK_END
		x.pressed.connect(close_modal)
		v.add_child(x)
	return v


func t(v: Control, text: String, fs := 16, font: Font = null, color = null, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = align
	l.add_theme_font_override("font", font if font else font_r)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color if color != null else v.get_meta("ink"))
	v.add_child(l)
	return l


func btn(parent: Control, text: String, cb: Callable, bg := Color("#6b4126"), fg := Color("#fbefd9"), enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_k)
	b.add_theme_font_size_override("font_size", 17)
	for st in ["font_color", "font_pressed_color", "font_hover_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", fg.darkened(0.4))
	b.add_theme_stylebox_override("normal", _box(bg, 2, INK, 3, 6))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.08), 2, INK, 3, 6))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.2), 2, INK, 3, 6))
	b.add_theme_stylebox_override("disabled", _box(bg.darkened(0.3), 2, INK, 3, 6))
	b.pressed.connect(func():
		cb.call()
		g.save_game()
		_flush_toasts())
	parent.add_child(b)
	return b


func row(v: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.set_meta("ink", v.get_meta("ink") if v.has_meta("ink") else INK)
	v.add_child(h)
	return h


func _vbox(parent: Control, ink: Color) -> VBoxContainer:
	var cv := VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.set_meta("ink", ink)
	parent.add_child(cv)
	return cv


func _portrait(key: String, L: Dictionary, mood: String, sz: Vector2) -> TextureRect:
	var pic := TextureRect.new()
	pic.texture = _raster(key, SvgArt.draw_char(SvgArt.look(L), mood), [-80, -100, 160, 175])
	pic.custom_minimum_size = sz
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return pic


## 물건 살펴보기: 왼쪽 조명 아래 물건, 오른쪽 정보 카드
func show_inspect(it: Dictionary) -> void:
	if it.is_empty():
		return
	g.inspect(it)
	var v := sheet(Color("#26262a"), Color("#f6efdc"), Color("#4a4a52"), true, 900)
	var h := v
	var left := _vbox(h, Color("#f6efdc"))
	var spot := PanelContainer.new()
	spot.add_theme_stylebox_override("panel", _box(Color("#1a1224"), 2, GOLD.darkened(0.3), 3, 10))
	spot.custom_minimum_size = Vector2(0, 220)
	left.add_child(spot)
	var em := TextureRect.new()
	em.texture = _icon(it["e"])
	em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spot.add_child(em)
	t(left, it["name"], 28, font_k, Color("#e09a7a"), HORIZONTAL_ALIGNMENT_CENTER)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color("#efe2c4"), 0, Color.BLACK, 14, 16))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(card)
	var cv := VBoxContainer.new()
	cv.set_meta("ink", INK)
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	var rar: Dictionary = D.items["rarity"][int(it["r"])]
	t(cv, it["name"], 22, font_k, null, HORIZONTAL_ALIGNMENT_CENTER)
	t(cv, "희귀도: %s" % rar["n"], 17, font_b, Color(rar["c"]).darkened(0.15), HORIZONTAL_ALIGNMENT_CENTER)
	t(cv, "상태: %s" % D.items["condition"][int(it["c"])]["n"], 17, font_b, null, HORIZONTAL_ALIGNMENT_CENTER)
	var tr := g.trend_of(it["cat"])
	t(cv, "종류: %s%s" % [D.items["categories"][it["cat"]]["n"], "  ▲시세 상승" if tr > 1.12 else ("  ▼시세 하락" if tr < 0.88 else "")], 17, font_b, null, HORIZONTAL_ALIGNMENT_CENTER)
	var e := g.est(it)
	t(cv, "견적액: %s" % (GameState.fmt(g.val(it, false)) if it["known"] else "%s ~ %s" % [GameState.fmt(e[0]), GameState.fmt(e[1])]), 19, font_k, Color("#1f6a66"), HORIZONTAL_ALIGNMENT_CENTER)
	if int(it["paid"]) > 0:
		t(cv, "지불액: %s" % GameState.fmt(it["paid"]), 17, font_b, null, HORIZONTAL_ALIGNMENT_CENTER)
	if g.is_pawned(it):
		t(cv, "담보: %s님 · %d일차까지 · 상환 %s" % [it["pawn"]["owner"], int(it["pawn"]["due"]), GameState.fmt(it["pawn"]["repay"])], 16, font_b, Color("#8a5a10"), HORIZONTAL_ALIGNMENT_CENTER)
	if it["known"] and it["fake"]:
		t(cv, "정밀 감정 결과: 가품!", 18, font_k, Color("#c4402a"), HORIZONTAL_ALIGNMENT_CENTER)
	elif it["suspect"]:
		t(cv, "감정사 메모: 가품이 의심됩니다", 16, font_b, Color("#c4402a"), HORIZONTAL_ALIGNMENT_CENTER)
	if not it["known"]:
		var id = it["id"]
		btn(cv, "정밀 감정  %s" % GameState.fmt(g.appr_fee(it)), func():
			g.appraise(id)
			show_inspect(g.find_item(id)), Color("#2a6a5a"))
	btn(v, "확인", close_modal)


func show_traits() -> void:
	var c := g.cur
	if c.is_empty() or c.get("visitor", false):
		return
	var v := sheet(CREAM, INK, INK, true, 560)
	t(v, "%s · %s" % [c["name"], c["role"]], 24, font_k)
	if c.get("sk", "") != "":
		var r: Dictionary = g.rel.get(c["sk"], {})
		t(v, "단골 손님 · 방문 %d회" % int(r.get("visits", 0)), 15, font_b, Color("#6a4aa0"))
	for k in c["tr"]:
		if c["seen"].has(k):
			t(v, "■ %s — %s" % [D.traits["traits"][k]["n"], D.traits["traits"][k]["d"]], 17, font_b)
		else:
			t(v, "■ ??? — 심리 스킬을 올리거나 프로파일러를 고용하면 보입니다", 15, null, Color("#777777"))
	btn(v, "확인", close_modal)


func show_keypad() -> void:
	var v := sheet(Color("#3c424a"), Color.WHITE, Color("#2e3238"), true, 420)
	var disp := t(v, GameState.fmt(g.draft), 34, font_k, Color("#14200c"), HORIZONTAL_ALIGNMENT_RIGHT)
	disp.add_theme_stylebox_override("normal", _box(Color("#b7c8a4"), 0, Color.BLACK, 6, 8))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	var their := g.their_price()
	for k in ["7", "8", "9", "⌫", "4", "5", "6", "-10%", "1", "2", "3", "+10%", "0", "00", "C", "확인"]:
		var b := Button.new()
		b.text = k
		b.custom_minimum_size = Vector2(88, 50)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", font_k)
		b.add_theme_font_size_override("font_size", 20)
		var light: bool = not (k in ["⌫", "-10%", "+10%", "C", "확인"])
		var bgc := Color("#1f8a86") if k == "확인" else (Color("#e8e2d4") if light else Color("#5a636e"))
		for st in ["font_color", "font_pressed_color", "font_hover_color"]:
			b.add_theme_color_override(st, INK if light else Color.WHITE)
		b.add_theme_stylebox_override("normal", _box(bgc, 0, Color.BLACK, 8, 4))
		b.add_theme_stylebox_override("hover", _box(bgc.lightened(0.1), 0, Color.BLACK, 8, 4))
		b.add_theme_stylebox_override("pressed", _box(bgc.darkened(0.2), 0, Color.BLACK, 8, 4))
		b.pressed.connect(func():
			match k:
				"확인":
					close_modal()
					return
				"⌫":
					g.draft = g.draft / 10
				"C":
					g.draft = 0
				"-10%":
					g.draft = GameState.r10((g.draft if g.draft > 0 else their) * 0.9)
				"+10%":
					g.draft = GameState.r10((g.draft if g.draft > 0 else their) * 1.1)
				_:
					g.draft = mini(99999999, int(str(g.draft if g.draft > 0 else "") + k))
			disp.text = GameState.fmt(g.draft))
		grid.add_child(b)


func show_hire(k: String) -> void:
	var s: Dictionary = D.staff[k]
	var v := sheet(CREAM, INK, INK, true, 640)
	var h := row(v)
	h.add_child(_portrait("staff_" + k, s["L"], "ok", Vector2(170, 186)))
	var cv := _vbox(h, INK)
	t(cv, "%s 고용" % s["n"], 24, font_k)
	t(cv, s["d"], 15)
	t(cv, s["pn"], 18, font_b)
	t(cv, s["q"], 14, null, Color("#666666"))
	t(cv, "일급: %s · 자리 %d/%d" % [GameState.fmt(s["w"]), g.staff.size(), g.staff_slots()], 15, font_b)
	var hh := row(v)
	btn(hh, "고용하기", func():
		if g.hire(k):
			close_modal()
		else:
			g.toast("직원 자리가 없어요. 가게를 넓히거나 다른 직원을 내보내세요."), Color("#1f8a86"), Color.WHITE, not g.has_staff(k))
	btn(hh, "취소", close_modal, Color("#8a8178"), Color.WHITE)


func show_receipt() -> void:
	var r := g.receipt
	if r.is_empty():
		return
	var v := sheet(Color("#fffdf6"), Color("#222222"), Color("#cccccc"), false, 520)
	t(v, "흥정왕 전당포", 24, font_k, null, HORIZONTAL_ALIGNMENT_CENTER)
	t(v, "%s · %d일차 마감" % [r["shop"], r["day"]], 15, null, null, HORIZONTAL_ALIGNMENT_CENTER)
	var good: bool = r["d"] >= 0
	for pair in [["거래", "%d건" % r["deals"]], ["매입", GameState.fmt(-r["bought"])], ["판매", GameState.fmt(r["sold"])], ["대출", GameState.fmt(-int(r.get("lent", 0)))], ["상환 받음", GameState.fmt(int(r.get("repaid", 0)))], ["임대료", GameState.fmt(-r["rent"])], ["직원 급여", GameState.fmt(-r["wages"])], ["현금 변화", GameState.fmt(r["d"])], ["경험치", "+%d XP" % r["xp"]]]:
		var h := row(v)
		var a := t(h, pair[0], 16)
		a.autowrap_mode = TextServer.AUTOWRAP_OFF
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := t(h, pair[1], 16, font_b, (Color("#2f8a4a") if good else Color("#c4402a")) if pair[0] == "현금 변화" else null, HORIZONTAL_ALIGNMENT_RIGHT)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
	for nt in r["notes"]:
		t(v, "· " + nt, 15)
	t(v, "*창고 물건은 현금이 아니라 재고입니다. 파산선: %s" % GameState.fmt(g.bankrupt_line()), 13, null, Color("#777777"))
	btn(v, "결과 보기" if g.is_bankrupt() else "불 끄고 퇴근 → 다음 날", func():
		if not g.next_day():
			_show_bankrupt()
			return
		close_modal())


func _show_bankrupt() -> void:
	var v := sheet(Color("#f3ead4"), Color("#1d1915"), Color("#1d1915"), false, 520)
	t(v, "파산!", 34, font_k)
	t(v, "%d일 동안 버텼습니다. 빚쟁이들이 셔터를 두드립니다." % g.day, 17)
	btn(v, "새로 시작", func():
		g = GameState.new(D)
		g.start_day()
		g.save_game()
		close_modal())


func show_inv() -> void:
	var v := sheet(Color("#2a2a2e"), Color("#e8eaf0"), Color("#4a4e58"))
	t(v, "창고 %d/%d" % [g.inv.size(), g.cap()], 26, font_k)
	t(v, "사러 온 손님은 여기서 물건을 고릅니다. 도매상은 흥정 없이 바로 사 가지만 실제 가치의 절반만 쳐주고, 가품은 귀신같이 알아봅니다.", 14)
	if g.inv.is_empty():
		t(v, "텅 비었다... 손님에게 물건을 사들이자.", 17, font_b)
	var items := g.inv.duplicate()
	items.sort_custom(func(a, b): return g.val(a, true) > g.val(b, true))
	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for it in items:
		g.inspect(it)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(Color("#efe2c4"), 0, Color.BLACK, 10, 10))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var cv := VBoxContainer.new()
		cv.set_meta("ink", INK)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(cv)
		var rar: Dictionary = D.items["rarity"][int(it["r"])]
		var hd := row(cv)
		var icn := TextureRect.new()
		icn.texture = _icon(it["e"])
		icn.custom_minimum_size = Vector2(56, 56)
		icn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hd.add_child(icn)
		t(hd, it["name"], 18, font_k).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var flags := ""
		if it["restoring"]:
			flags += " · 수리 중"
		if it["suspect"] or (it["known"] and it["fake"]):
			flags += " · 가품 확정" if it["known"] else " · 가품 의심"
		t(cv, "%s · %s · %s%s" % [rar["n"], D.items["condition"][int(it["c"])]["n"], D.items["categories"][it["cat"]]["n"], flags], 14, null, Color(rar["c"]).darkened(0.2))
		if g.is_pawned(it):
			t(cv, "담보 — %s님 · %d일차까지 · 상환 %s" % [it["pawn"]["owner"], int(it["pawn"]["due"]), GameState.fmt(it["pawn"]["repay"])], 14, font_b, Color("#8a5a10"))
		var e := g.est(it)
		t(cv, ("감정가 %s · 지불 %s" % [GameState.fmt(g.val(it, false)), GameState.fmt(it["paid"])]) if it["known"] else "견적 %s~%s · 지불 %s" % [GameState.fmt(e[0]), GameState.fmt(e[1]), GameState.fmt(it["paid"])], 15, font_b, Color("#1f6a66"))
		var h := row(cv)
		var id = it["id"]
		if not it["known"]:
			btn(h, "감정 %s" % GameState.fmt(g.appr_fee(it)), func():
				g.appraise(id)
				show_inv(), Color("#8a5a10"))
		if g.has_staff("restorer") and int(it["c"]) < 4 and not it["restoring"]:
			btn(h, "수리 %s" % GameState.fmt(g.restore_cost(it)), func():
				g.restore(id)
				show_inv(), Color("#1f8a86"))
		btn(h, "도매 처분", func():
			g.dump(id)
			show_inv(), Color("#c4402a"), Color.WHITE, not it["restoring"] and not g.is_pawned(it))


func show_staff() -> void:
	var v := sheet(Color("#b98a55"), INK, Color("#6b4126"))
	t(v, "직원", 26, font_k)
	t(v, "자리 %d/%d · 새 직원은 아침 신문 구인 광고로 고용합니다. 가게를 넓히면 자리가 늘어요." % [g.staff.size(), g.staff_slots()], 15, font_b)
	if g.staff.is_empty():
		t(v, "아직 직원이 없습니다.", 17, font_b)
	for k in g.staff:
		var s: Dictionary = D.staff[k]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(Color.WHITE, 0, Color.BLACK, 4, 8))
		v.add_child(card)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		card.add_child(h)
		h.add_child(_portrait("staff_" + k + "h", s["L"], "happy", Vector2(100, 110)))
		var cv := _vbox(h, INK)
		t(cv, "%s · %s" % [s["pn"], s["n"]], 18, font_k)
		t(cv, "%s 일급 %s" % [s["d"], GameState.fmt(s["w"])], 14)
		btn(cv, "내보내기", func():
			g.fire(k)
			show_staff(), Color("#c4402a"), Color.WHITE)


func show_ledger() -> void:
	var v := sheet(Color("#fbf6e9"), Color("#22201c"), Color("#5a2a1c"))
	t(v, "사장 장부", 26, font_k)
	t(v, "Lv.%d 딜러 · 경험치 %d/%d · 스킬 포인트 %d · 평판 %d" % [g.lv, g.xp, g.lv * 120, g.sp, g.rep], 16, font_b)
	var sk := {"haggle": ["흥정", "판매자는 더 싸게, 구매자는 더 비싸게"], "appraise": ["감정", "견적이 좁아지고 가품이 보임"], "psych": ["심리", "손님 성향을 읽음 (1레벨 1개, 3레벨 전부)"], "charm": ["화술", "손님 인내심 증가"]}
	for k in sk:
		var h := row(v)
		var cv := _vbox(h, Color("#22201c"))
		t(cv, "%s  %s%s" % [sk[k][0], "●".repeat(g.skills[k]), "○".repeat(5 - g.skills[k])], 18, font_k)
		t(cv, sk[k][1], 13)
		var b := btn(h, "+1", func():
			g.skill_up(k)
			show_ledger(), Color("#1f8a86"), Color.WHITE, g.sp > 0 and g.skills[k] < 5)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.custom_minimum_size = Vector2(70, 46)
	var cs := g.shop_info()
	t(v, "가게", 21, font_k)
	t(v, "지금: %s · 임대료 %s/일 · 창고 %d칸 · 손님 %d명" % [cs["n"], GameState.fmt(cs["rent"]), g.cap(), int(cs["cust"])], 15)
	if g.shop + 1 < D.shops.size():
		var nx: Dictionary = D.shops[g.shop + 1]
		t(v, "다음: %s · 창고 %d칸 · 손님 %d명 · 임대료 %s/일" % [nx["n"], int(nx["st"]), int(nx["cust"]), GameState.fmt(nx["rent"])], 14)
		btn(v, "%s에 이전 계약" % GameState.fmt(nx["cost"]), func():
			g.move_shop()
			show_ledger(), Color("#d9a441"), INK, g.can_move())
	else:
		t(v, "최고의 가게! 이 거리의 흥정왕입니다.", 16, font_b)
	t(v, "단골 수첩", 21, font_k)
	if g.rel.is_empty():
		t(v, "아직 단골이 없습니다. 단골 손님은 지난 거래를 기억합니다.", 14)
	var outcome := {"steal": "내가 이득", "fair": "공정 거래", "angry": "화내고 떠남", "scam": "가품을 팔았음"}
	for k in g.rel:
		t(v, "%s — 방문 %d회, 지난번: %s" % [D.specials[k]["n"], int(g.rel[k]["visits"]), outcome.get(g.rel[k].get("last", ""), "-")], 15)
	t(v, "누적 거래 %d건 · 판매 차익 %s" % [int(g.stats["deals"]), GameState.fmt(g.stats["profit"])], 14)
	btn(v, "효과음 켜기" if sfx.muted else "효과음 끄기", func():
		sfx.muted = not sfx.muted
		g.stats["muted"] = sfx.muted
		show_ledger(), Color("#5a636e"), Color.WHITE)
	btn(v, "처음부터 다시 하기", func():
		var w := sheet(Color("#f3ead4"), Color("#1d1915"), Color("#1d1915"), true, 480)
		t(w, "처음부터 다시?", 24, font_k)
		t(w, "지금 진행 상황이 사라집니다.", 16)
		btn(w, "다시 시작", func():
			g = GameState.new(D)
			g.start_day()
			g.save_game()
			close_modal(), Color("#c4402a"), Color.WHITE), Color("#8a8178"), Color.WHITE)


func _open_auction() -> void:
	if g.start_auction():
		show_auction()
	else:
		_flush_toasts()


func show_auction() -> void:
	if g.auction.is_empty():
		close_modal()
		return
	var v := sheet(Color("#24161a"), Color("#f6e7d0"), Color("#a8823a"), false, 900)
	var it := g.lot()
	var a := g.auction
	t(v, "은하 경매장 · %d/%d번 물건" % [int(a["i"]) + 1, a["lots"].size()], 24, font_k)
	var top := v
	var left := _vbox(top, Color("#f6e7d0"))
	var aic := TextureRect.new()
	aic.texture = _icon(it["e"])
	aic.custom_minimum_size = Vector2(130, 130)
	aic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	aic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(aic)
	var rar: Dictionary = D.items["rarity"][int(it["r"])]
	var e := g.est(it, not g.has_staff("expert"))
	t(left, it["name"], 22, font_k, null, HORIZONTAL_ALIGNMENT_CENTER)
	t(left, "%s · %s%s" % [rar["n"], D.items["condition"][int(it["c"])]["n"] if g.has_staff("expert") else "상태 ?", " · 가품 의심" if it["suspect"] else ""], 15, font_b, Color(rar["c"]).lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	t(left, "견적 %s ~ %s" % [GameState.fmt(e[0]), GameState.fmt(e[1])], 15, null, null, HORIZONTAL_ALIGNMENT_CENTER)
	var right := _vbox(top, Color("#f6e7d0"))
	var bh := row(right)
	for b in D.text["auction_npcs"]:
		var cv := _vbox(bh, Color("#f6e7d0"))
		var lead: bool = a["leader"] == b["n"]
		cv.add_child(_portrait("npc_" + b["n"] + str(lead), b["L"], "happy" if lead else "ok", Vector2(90, 98)))
		t(cv, ("▲ " if lead else "") + b["n"], 12, font_b, Color("#ffd77a") if lead else null, HORIZONTAL_ALIGNMENT_CENTER)
	t(right, GameState.fmt(a["price"]), 40, font_k, Color("#ffd77a"), HORIZONTAL_ALIGNMENT_CENTER)
	t(right, ("내가 최고가" if a["leader"] == "me" else a["leader"] + " 최고가") if a["leader"] != "" else "아직 입찰 없음", 15, null, null, HORIZONTAL_ALIGNMENT_CENTER)
	t(right, "내 금고 %s · 창고 %d/%d" % [GameState.fmt(g.money), g.inv.size(), g.cap()], 14, null, null, HORIZONTAL_ALIGNMENT_CENTER)
	if a["over"]:
		t(v, a["res"], 18, font_b, null, HORIZONTAL_ALIGNMENT_CENTER)
		btn(v, "다음 물건" if int(a["i"]) < a["lots"].size() - 1 else "경매장 나가기", func():
			if not g.auction_next():
				close_modal()
			else:
				show_auction(), Color("#d9a441"), INK)
	else:
		var h := row(v)
		btn(h, "번호판 들기  %s" % GameState.fmt(g.next_bid_price()), func():
			g.auction_bid()
			show_auction(), Color("#d9a441"), Color("#3a2108"))
		btn(h, "이번 물건 포기", func():
			g.auction_pass()
			show_auction(), Color("#4a3a3e"), Color("#f6e7d0"), a["leader"] != "me")
	for l in a["log"].slice(0, 4):
		t(v, l, 13, null, Color("#d9c3a5"))


func show_stats(mode: String) -> void:
	var v := sheet(Color("#f3d98a"), INK, Color("#8a6420"))
	t(v, "통계", 26, font_k)
	var tabs := row(v)
	for m in [["today", "오늘"], ["week", "최근 7일"], ["all", "전체"]]:
		var mm: String = m[0]
		btn(tabs, m[1], func(): show_stats(mm), Color("#8a6420") if mm == mode else Color("#c9a85a"), Color.WHITE if mm == mode else INK)
	var d: Dictionary
	if mode == "today":
		d = g.today.duplicate()
		d["rent"] = int(g.shop_info()["rent"])
		d["wages"] = g.wages()
		d["cash"] = g.money - int(g.today.get("start", g.money))
		t(v, "오늘은 아직 마감 전입니다. 임대료·급여는 마감 때 나갑니다.", 13, null, Color("#6b4a10"))
	else:
		d = g.stats_sum(7 if mode == "week" else 0)
		t(v, "마감한 날 %d일 기준" % int(d.get("days", 0)), 13, null, Color("#6b4a10"))
	var rows := [["수입 · 판매", "sold", 1], ["수입 · 대출 상환", "repaid", 1], ["수입 · 도감 상금", "prize", 1], ["지출 · 매입", "bought", -1], ["지출 · 대출", "lent", -1], ["지출 · 감정·수리·참가비", "fees", -1], ["지출 · 벌금·사고", "penalty", -1], ["지출 · 임대료", "rent", -1], ["지출 · 직원 급여", "wages", -1]]
	for r in rows:
		var h := row(v)
		var a := t(h, r[0], 16)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a.autowrap_mode = TextServer.AUTOWRAP_OFF
		var amt: int = int(d.get(r[1], 0)) * int(r[2])
		var b := t(h, GameState.fmt(amt), 16, font_b, Color("#2f6a2a") if amt > 0 else (Color("#a02a1a") if amt < 0 else INK), HORIZONTAL_ALIGNMENT_RIGHT)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
	var hh := row(v)
	var a2 := t(hh, "현금 변화", 19, font_k)
	a2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t(hh, GameState.fmt(int(d.get("cash", 0))), 19, font_k, Color("#2f6a2a") if int(d.get("cash", 0)) >= 0 else Color("#a02a1a"), HORIZONTAL_ALIGNMENT_RIGHT)
	t(v, "거래 %d건 · 누적 판매 차익 %s · 도감 %d/%d" % [int(d.get("deals", 0)), GameState.fmt(g.stats["profit"]), g.collection.size(), g.collection_total()], 14)


func show_collection() -> void:
	var v := sheet(Color("#2a2a3a"), Color("#eceaf6"), Color("#4a4a6a"))
	t(v, "아이템 도감  %d / %d" % [g.collection.size(), g.collection_total()], 26, font_k)
	t(v, "한 번이라도 손에 넣은 물건이 기록됩니다. 한 종류를 모두 모으면 은하 골동 동호회 상금과 평판을 받습니다.", 14)
	var cats: Dictionary = D.items["categories"]
	for ck in cats:
		var done: bool = g.col_done.has(ck)
		var items: Array = cats[ck]["items"]
		var have := 0
		for it in items:
			if g.collection.has("%s/%s" % [ck, it[0]]):
				have += 1
		t(v, "%s  %d/%d%s" % [cats[ck]["n"], have, items.size(), "  ★ 완성" if done else ""], 18, font_k, Color("#ffd77a") if done else null)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		v.add_child(grid)
		for it in items:
			var key := "%s/%s" % [ck, it[0]]
			var owned := g.collection.has(key)
			var card := PanelContainer.new()
			var rc := Color(D.items["rarity"][int(g.collection[key])]["c"]) if owned else Color("#4a4a5a")
			card.add_theme_stylebox_override("panel", _box(Color("#3a3a4e") if owned else Color("#2e2e3c"), 3, rc, 10, 6))
			card.custom_minimum_size = Vector2(96, 96)
			grid.add_child(card)
			var cv := VBoxContainer.new()
			cv.set_meta("ink", Color("#eceaf6"))
			card.add_child(cv)
			var cic := TextureRect.new()
			cic.texture = _icon(it[1])
			cic.custom_minimum_size = Vector2(56, 56)
			cic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cic.modulate = Color.WHITE if owned else Color(0, 0, 0, 0.55)
			cv.add_child(cic)
			t(cv, it[0] if owned else "???", 11, font_b, null, HORIZONTAL_ALIGNMENT_CENTER)
