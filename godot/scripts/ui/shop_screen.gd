extends Control
## 메인 화면 (가로 1170x540 설계 좌표). 딜러스라이프2와 같은 화면 구성·흐름:
##   왼쪽 위 대화창 + 선택지 / 가운데 손님 / 오른쪽 뒤 대기 줄 / 흥정 중 오른쪽 칠판
##   카운터: 태블릿(창고) · 펠트 매트 위 물건 · 나무 가격표 + ✓/✗ + 망치(최종 제안)
##   오른쪽 위 돈·달력. 아침엔 신문 + 「열기」 팻말.
## 그림·이름·대사는 전부 자체 제작. 게임 규칙은 GameState에 있고 여기는 그리기·입력만.

const GameState := preload("res://scripts/core/game_state.gd")
const SvgArt := preload("res://scripts/ui/svg_art.gd")
const W := 1170.0
const H := 540.0
const INK := Color("#2a1a10")
const CREAM := Color("#f6efdc")
const PRICE_POS := Vector2(830, 404)

var g: GameState
var D
var font_r: Font = preload("res://assets/fonts/NotoSansKR-Regular.otf")
var font_b: Font = preload("res://assets/fonts/NotoSansKR-Bold.otf")
var font_k: Font = preload("res://assets/fonts/NotoSansKR-Black.otf")

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


func _ready() -> void:
	D = get_node_or_null("/root/GameData")
	if D == null:
		D = preload("res://scripts/core/game_data.gd").new()
		add_child(D)
	g = GameState.new(D)
	if not g.load_game():
		g.start_day()
	_build()
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
	bg.color = Color("#1a0e0a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	stage = Control.new()
	stage.size = Vector2(W, H)
	stage.clip_contents = true
	add_child(stage)
	back_tex = _tex_rect(Vector2(0, 0), Vector2(W, H))
	for i in 2:
		queue_tex.append(_tex_rect(Vector2.ZERO, Vector2(121, 259)))
	cust_tex = _tex_rect(Vector2(459, 18), Vector2(253, 408))
	front_tex = _tex_rect(Vector2(0, 380), Vector2(W, 160))
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
	toast_lbl.add_theme_font_size_override("font_size", 18)
	toast_lbl.add_theme_color_override("font_color", INK)
	toast_lbl.add_theme_stylebox_override("normal", _box(Color("#fff6a8"), 2, INK, 8, 10))
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
	toast_lbl.position = Vector2(vs.x * 0.3, 12)
	toast_lbl.size = Vector2(vs.x * 0.4, 0)


func _box(c: Color, border := 0, bc := Color.BLACK, radius := 8, pad := 8) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_border_width_all(border)
	b.border_color = bc
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(pad)
	return b


func _raster(key: String, body: String, vb: Array) -> Texture2D:
	var k := "%s|%s|%s" % [key, body.hash(), _px]
	if _cache.has(k):
		return _cache[k]
	if _cache.size() > 40:
		_cache.clear()
	var t := SvgArt.rasterize(body, vb, _px)
	_cache[k] = t
	return t


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
	b.add_theme_stylebox_override("pressed", _box(Color(1, 1, 1, 0.15), 0, Color.BLACK, 10))
	b.pressed.connect(func(): _act(cb))
	dyn.add_child(b)
	return b


func _act(cb: Callable) -> void:
	cb.call()
	g.save_game()
	render()


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
	front_tex.texture = _raster("front", _front_svg(), [0, 380, W, 160])
	_render_counter()
	match g.phase:
		"morning":
			_render_morning()
		"night":
			_render_night()
		_:
			if not g.cur.is_empty():
				_render_dialog()
				if g.cur.get("stage", "") == "haggle":
					_render_chalkboard()
	_render_hud()
	_flush_toasts()


func _look_of(c: Dictionary) -> Dictionary:
	if c.has("look"):
		return SvgArt.look(c["look"])
	return SvgArt.customer_look(c.get("arch", "student"), c.get("tr", []), int(c.get("look_seed", 1)))


func _render_queue() -> void:
	var waiting: Array = g.upcoming if g.phase == "open" else []
	for i in 2:
		var t: TextureRect = queue_tex[i]
		if i < waiting.size():
			t.texture = _raster("q%d" % i, SvgArt.draw_char(_look_of(waiting[i]), "ok", true), SvgArt.STAND_VB)
			t.position = Vector2(905 + i * 120, 132)
			t.size = Vector2(121, 259)
			t.modulate = Color(0.9, 0.88, 0.85)
			t.visible = true
		else:
			t.visible = false


func _render_customer() -> void:
	var c := g.cur
	if c.is_empty():
		cust_tex.visible = false
		if bob_tween:
			bob_tween.kill()
		return
	var md := g.mood()
	cust_tex.texture = _raster("cust", SvgArt.draw_char(_look_of(c), md), SvgArt.CHAR_VB)
	cust_tex.visible = true
	if bob_tween:
		bob_tween.kill()
	cust_tex.position = Vector2(459, 18)
	bob_tween = create_tween().set_loops()
	if md == "angry" and not c.get("gone", false):
		bob_tween.tween_property(cust_tex, "position:x", 452.0, 0.06)
		bob_tween.tween_property(cust_tex, "position:x", 466.0, 0.12)
		bob_tween.tween_property(cust_tex, "position:x", 459.0, 0.06)
		bob_tween.tween_interval(1.6)
	else:
		bob_tween.tween_property(cust_tex, "position:y", 22.0, 1.7).set_trans(Tween.TRANS_SINE)
		bob_tween.tween_property(cust_tex, "position:y", 18.0, 1.7).set_trans(Tween.TRANS_SINE)
	if not c.get("visitor", false):
		hot(Rect2(500, 40, 170, 340), "손님 성향 보기", func(): show_traits())


func _back_svg() -> String:
	var wall: String = g.shop_info().get("wall", "#6a4a3a")
	var s := '<defs><linearGradient id="fl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8a6a4c"/><stop offset="1" stop-color="#5a3e2a"/></linearGradient><radialGradient id="lamp" cx=".5" cy=".15" r=".8"><stop offset="0" stop-color="#ffe3a3" stop-opacity=".35"/><stop offset="1" stop-color="#000" stop-opacity=".35"/></radialGradient><linearGradient id="gl" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#d8eef5"/><stop offset="1" stop-color="#9ccbd9"/></linearGradient></defs>'
	s += '<rect width="1170" height="330" fill="%s"/>' % wall
	for i in 40:
		s += '<rect x="%d" y="0" width="2" height="330" fill="#000" opacity=".18"/>' % (i * 30)
	s += '<rect width="1170" height="14" fill="#000" opacity=".25"/><rect y="318" width="1170" height="14" fill="#3a2416"/>'
	s += '<path d="M0 330 L1170 330 L1170 540 L0 540Z" fill="url(#fl)"/>'
	for i in range(-6, 14):
		s += '<path d="M%d 330 L%d 540" stroke="#000" stroke-opacity=".15" stroke-width="2"/>' % [585 + i * 70, 585 + i * 130]
	s += '<ellipse cx="760" cy="372" rx="120" ry="20" fill="#c9b38a" opacity=".55"/>'
	s += '<rect x="955" y="50" width="180" height="170" fill="#4a3020"/><rect x="965" y="60" width="160" height="150" fill="url(#gl)"/><path d="M1045 60 L1045 210 M965 135 L1125 135" stroke="#4a3020" stroke-width="7"/><rect x="950" y="216" width="190" height="12" fill="#5a3a24"/>'
	s += '<rect x="770" y="80" width="120" height="250" fill="#5a3a24"/><rect x="780" y="90" width="100" height="240" fill="#7a5034"/><circle cx="866" cy="215" r="6" fill="#d9a441"/><rect x="795" y="105" width="70" height="60" rx="4" fill="#3a2a20" opacity=".4"/>'
	s += '<rect x="560" y="40" width="80" height="62" fill="#c9a227"/><rect x="566" y="46" width="68" height="50" fill="#2e4a5a"/><circle cx="615" cy="60" r="7" fill="#ffd77a"/><path d="M566 96 L590 70 L606 86 L618 76 L634 96Z" fill="#4a7a5a"/>'
	s += '<rect x="670" y="50" width="62" height="50" fill="#c9a227"/><rect x="675" y="55" width="52" height="40" fill="#5a2e3a"/><path d="M690 90 L700 62 L712 90Z" fill="#e6c870"/>'
	s += '<rect x="40" y="120" width="300" height="10" fill="#4a2e1c"/><rect x="40" y="210" width="300" height="10" fill="#4a2e1c"/>'
	var cols := ["#c8a070", "#a08060", "#d9b080", "#8a6a4a", "#b89060"]
	for i in 6:
		s += '<rect x="%d" y="%d" width="38" height="%d" fill="%s" stroke="#5a3e2a" stroke-width="2"/>' % [55 + i * 46, 80 + (i % 2) * 8, 40 - (i % 2) * 8, cols[i % cols.size()]]
		s += '<rect x="%d" y="%d" width="34" height="%d" fill="%s" stroke="#5a3e2a" stroke-width="2"/>' % [60 + i * 45, 172 + (i % 3) * 6, 38 - (i % 3) * 6, cols[(i + 2) % cols.size()]]
	s += '<rect x="20" y="270" width="110" height="90" fill="#b08a5a" stroke="#6a4a2a" stroke-width="3"/><rect x="60" y="225" width="80" height="50" fill="#c89a6a" stroke="#6a4a2a" stroke-width="3"/>'
	s += '<rect width="1170" height="540" fill="url(#lamp)"/>'
	return s


func _front_svg() -> String:
	var it := g.cur_item()
	var s := '<defs><linearGradient id="ct" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7a3a2a"/><stop offset="1" stop-color="#4a2018"/></linearGradient><linearGradient id="wd" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#a0704a"/><stop offset="1" stop-color="#6a4426"/></linearGradient><radialGradient id="felt" cx=".5" cy=".4" r=".65"><stop offset="0" stop-color="#4a8a5a"/><stop offset="1" stop-color="#2a5a3a"/></radialGradient></defs>'
	s += '<path d="M0 398 L1170 398 L1170 540 L0 540Z" fill="url(#ct)"/><path d="M0 392 L1170 392 L1170 404 L0 404Z" fill="#2a120c"/>'
	s += '<g transform="rotate(-4 150 470)"><rect x="80" y="420" width="150" height="104" rx="12" fill="#2a2a2e"/><rect x="90" y="430" width="130" height="84" rx="6" fill="#4a4e58"/><circle cx="224" cy="472" r="3" fill="#c4402a"/></g>'
	s += '<path d="M300 410 L790 410 L770 530 L320 530Z" fill="url(#felt)"/><path d="M300 410 L790 410" stroke="#d9c070" stroke-width="3"/>'
	if not it.is_empty():
		s += '<ellipse cx="545" cy="470" rx="70" ry="22" fill="%s" opacity=".35"/>' % D.items["rarity"][int(it["r"])]["c"]
	var haggling: bool = g.is_haggling() and g.cur.get("stage", "") == "haggle"
	s += '<g opacity="%s"><rect x="830" y="404" width="230" height="44" rx="6" fill="url(#wd)" stroke="#4a2a14" stroke-width="3"/>' % ("1" if haggling else ".55")
	s += '<rect x="830" y="458" width="100" height="70" rx="6" fill="#8a5a36" stroke="#4a2a14" stroke-width="3"/><path d="M858 492 L874 508 L904 474" stroke="#2f8a4a" stroke-width="10" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
	s += '<rect x="944" y="458" width="100" height="70" rx="6" fill="#8a5a36" stroke="#4a2a14" stroke-width="3"/><path d="M974 474 L1014 512 M1014 474 L974 512" stroke="#c4402a" stroke-width="10" stroke-linecap="round"/>'
	s += '<g transform="rotate(-30 1100 490)"><rect x="1094" y="452" width="12" height="70" rx="4" fill="#a0704a"/><rect x="1072" y="440" width="56" height="26" rx="6" fill="#6a6a72"/></g></g>'
	return s


func _render_hud() -> void:
	var money := PanelContainer.new()
	money.add_theme_stylebox_override("panel", _box(Color("#efe2a0"), 3, Color("#5a4a1a"), 18, 4))
	money.position = Vector2(860, 8)
	money.custom_minimum_size = Vector2(190, 38)
	var ml := Label.new()
	ml.text = "  " + GameState.fmt(g.money)
	ml.add_theme_font_override("font", font_k)
	ml.add_theme_font_size_override("font_size", 22)
	ml.add_theme_color_override("font_color", Color("#c4402a") if g.money < 0 else INK)
	money.add_child(ml)
	dyn.add_child(money)
	var cal := PanelContainer.new()
	cal.add_theme_stylebox_override("panel", _box(Color("#3a4aa0"), 2, Color("#1a2060"), 4, 2))
	cal.position = Vector2(1060, 4)
	cal.custom_minimum_size = Vector2(100, 48)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", -4)
	cal.add_child(cv)
	for pair in [["%d일차" % g.day, true], [g.shop_info()["n"], false]]:
		var l := Label.new()
		l.text = pair[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", font_k if pair[1] else font_b)
		l.add_theme_font_size_override("font_size", 18 if pair[1] else 11)
		l.add_theme_color_override("font_color", Color.WHITE)
		cv.add_child(l)
	dyn.add_child(cal)
	_round_button(Vector2(510, 27), "도감", func(): show_collection())
	_round_button(Vector2(600, 27), "통계", func(): show_stats("today"))
	_round_button(Vector2(690, 27), "장부" + (" ●" if g.sp > 0 else ""), func(): show_ledger())
	_round_button(Vector2(780, 27), "직원", func(): show_staff())


func _round_button(center: Vector2, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.size = Vector2(80, 40)
	b.position = center - Vector2(40, 20)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_k)
	b.add_theme_font_size_override("font_size", 15)
	for st in ["font_color", "font_pressed_color", "font_hover_color"]:
		b.add_theme_color_override(st, INK)
	b.add_theme_stylebox_override("normal", _box(CREAM, 3, INK, 20, 4))
	b.add_theme_stylebox_override("hover", _box(CREAM.lightened(0.2), 3, INK, 20, 4))
	b.add_theme_stylebox_override("pressed", _box(CREAM.darkened(0.15), 3, INK, 20, 4))
	b.pressed.connect(func(): cb.call())
	dyn.add_child(b)


func _render_counter() -> void:
	var it := g.cur_item()
	lbl("창고", Vector2(92, 432), Vector2(126, 28), 16, Color("#d8dce6"), font_b, HORIZONTAL_ALIGNMENT_CENTER)
	lbl("%d/%d" % [g.inv.size(), g.cap()], Vector2(92, 458), Vector2(126, 44), 30, Color("#ff9a7a") if g.inv.size() >= g.cap() else Color.WHITE, font_k, HORIZONTAL_ALIGNMENT_CENTER)
	hot(Rect2(76, 414, 160, 116), "창고 열기", func(): show_inv())
	if not it.is_empty():
		lbl(it["e"], Vector2(470, 412), Vector2(150, 100), 64, Color.WHITE, null, HORIZONTAL_ALIGNMENT_CENTER)
		if it["known"] and it["fake"]:
			lbl("가품", Vector2(500, 440), Vector2(90, 40), 24, Color("#ff5a4a"), font_k, HORIZONTAL_ALIGNMENT_CENTER, -14)
		hot(Rect2(420, 410, 250, 120), "물건 살펴보기", func(): show_inspect(it))
	var haggling: bool = g.is_haggling() and g.cur.get("stage", "") == "haggle"
	lbl(GameState.fmt(g.draft) if haggling else "$ ---", PRICE_POS, Vector2(230, 44), 24, Color("#2a1408"), font_k, HORIZONTAL_ALIGNMENT_CENTER)
	if haggling:
		var price_btn := hot(Rect2(830, 400, 230, 52), "가격표: 좌우로 끌어 조정, 눌러서 직접 입력", func(): show_keypad())
		price_btn.gui_input.connect(_on_sign_drag)
		hot(Rect2(830, 456, 100, 74), "제안하기 ✓", func(): g.propose(g.draft))
		hot(Rect2(944, 456, 100, 74), "거절 ✗", func(): g.refuse())
		hot(Rect2(1062, 436, 80, 96), "망치: 최종 제안", func(): g.propose(g.draft, true))
		lbl("최종", Vector2(1066, 512), Vector2(70, 22), 13, Color("#ffd77a"), font_k, HORIZONTAL_ALIGNMENT_CENTER)
		lbl("◀ 끌어서 조정 · 눌러서 입력 ▶", Vector2(830, 446), Vector2(230, 14), 11, Color("#ffd77a"), font_b, HORIZONTAL_ALIGNMENT_CENTER)


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
	for c in dyn.get_children():
		if c is Label and c.position == PRICE_POS:
			c.text = GameState.fmt(g.draft)


# ---------------------------------------------------------------- 대화창
func _tag_style() -> Array:
	var c := g.cur
	if c.get("visitor", false):
		return ["방문객 · " + c["name"], Color("#e6c06a")]
	if c.get("pawn", false):
		return ["전당포 의뢰인 · " + c["name"], Color("#e6c06a")]
	if c.get("sk", "") != "":
		return ["단골 · " + c["name"], Color("#b49ae0")]
	return [("구매자 · " if c["buy"] else "판매자 · ") + c["name"], Color("#9cc878") if c["buy"] else Color("#e08a7a")]


func _render_dialog() -> void:
	var c := g.cur
	var ts := _tag_style()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _box(CREAM, 4, ts[1].darkened(0.35), 14, 14))
	box.position = Vector2(40, 30)
	box.custom_minimum_size = Vector2(380, 150)
	var bl := Label.new()
	bl.text = c["msg"]
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bl.custom_minimum_size = Vector2(350, 120)
	bl.add_theme_font_override("font", font_b)
	bl.add_theme_font_size_override("font_size", 17)
	bl.add_theme_color_override("font_color", INK)
	box.add_child(bl)
	dyn.add_child(box)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", _box(ts[1], 3, ts[1].darkened(0.4), 14, 4))
	tag.position = Vector2(110, 12)
	tag.custom_minimum_size = Vector2(240, 30)
	var tl := Label.new()
	tl.text = ts[0]
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_font_override("font", font_k)
	tl.add_theme_font_size_override("font_size", 15)
	tl.add_theme_color_override("font_color", INK)
	tag.add_child(tl)
	dyn.add_child(tag)
	var y := 196.0
	var opts := _choices()
	var step := 46.0 if opts.size() <= 4 else 38.0
	for o in opts:
		_choice(Vector2(40, y), o[0], o[1], o.size() > 2 and o[2])
		y += step


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
		return [["계속", func(): g.next_customer()]]
	match c.get("stage", "intro"):
		"intro":
			return [["한 번 볼게요…", func():
				g.look_item()
				show_inspect(g.cur_item())], ["관심 없어요.", func(): g.refuse()]]
		"look":
			return [["거래합시다!", func(): g.start_haggle()], ["관심 없어요.", func(): g.refuse()]]
		_:
			var out: Array = [[("%s 빌려드릴게요." if c.get("pawn", false) else "%s에 할게요.") % GameState.fmt(g.their_price()), func(): g.accept()]]
			var it := g.cur_item()
			if not c["buy"] and not it.is_empty() and (it["suspect"] or (it["known"] and it["fake"])) and not c["accused"]:
				out.append(["[감정] 이거 가짜 같은데요?", func(): g.accuse(), true])
			for sp in g.special_options():
				var sid: String = sp[0]
				out.append([sp[1], func(): g.use_special(sid), true])
			out.append(["관심 없어요.", func(): g.refuse()])
			return out


func _choice(pos: Vector2, text: String, cb: Callable, special := false) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(380, 36)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_b)
	b.add_theme_font_size_override("font_size", 16)
	var bg := Color("#c9d4f0") if special else CREAM
	for st in ["font_color", "font_pressed_color", "font_hover_color"]:
		b.add_theme_color_override(st, Color("#2a3a7a") if special else INK)
	b.add_theme_stylebox_override("normal", _box(bg, 3, INK, 14, 4))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.15), 3, INK, 14, 4))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.15), 3, INK, 14, 4))
	b.pressed.connect(func(): _act(cb))
	dyn.add_child(b)


# ---------------------------------------------------------------- 칠판
func _render_chalkboard() -> void:
	var it := g.cur_item()
	if it.is_empty() or g.neg == null:
		return
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color("#2c302c"), 10, Color("#7a4a26"), 8, 14))
	frame.position = Vector2(840, 70)
	frame.custom_minimum_size = Vector2(300, 250)
	dyn.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	frame.add_child(v)
	var rar: Dictionary = D.items["rarity"][int(it["r"])]
	var e := g.est(it)
	var chalk := Color("#ecebe4")
	var rows := [["희귀도", rar["n"], Color(rar["c"]).lightened(0.3)], ["상태", D.items["condition"][int(it["c"])]["n"], Color("#f0a090") if int(it["c"]) <= 1 else Color("#a0e0a0")], ["종류", D.items["categories"][it["cat"]]["n"], chalk], ["견적액", GameState.fmt(g.val(it, false)) if it["known"] else "%s~%s" % [GameState.fmt(e[0]), GameState.fmt(e[1])], chalk]]
	if int(it["paid"]) > 0:
		rows.append(["지불액", GameState.fmt(it["paid"]), chalk])
	if g.cur.has("read"):
		rows.append(["속마음", "%s~%s" % [GameState.fmt(g.cur["read"][0]), GameState.fmt(g.cur["read"][1])], Color("#9ac4ff")])
	if g.cur.get("pawn", false):
		rows.append(["맡기는 기간", "%d일 · 상환액은 대출금의 %d%%" % [g.cur["days"], int(round((1.1 + 0.03 * g.cur["days"]) * 100))], Color("#ffd77a")])
	for r in rows:
		var l := Label.new()
		l.text = "%s: %s" % [r[0], r[1]]
		l.add_theme_font_override("font", font_b)
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", r[2])
		v.add_child(l)
	var curl := Label.new()
	curl.text = ("대출 요청: %s" if g.cur.get("pawn", false) else "현재: %s") % GameState.fmt(g.their_price())
	curl.add_theme_font_override("font", font_k)
	curl.add_theme_font_size_override("font_size", 30)
	curl.add_theme_color_override("font_color", Color.WHITE)
	v.add_child(curl)
	var m := g.neg.patience_ratio()
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.max_value = 1.0
	bar.value = m
	bar.add_theme_stylebox_override("background", _box(Color("#4a4e48"), 0, Color.BLACK, 5, 0))
	bar.add_theme_stylebox_override("fill", _box(Color("#7ac47a") if m > 0.66 else (Color("#e6b85a") if m > 0.33 else Color("#e0604a")), 0, Color.BLACK, 5, 0))
	v.add_child(bar)
	var pl := Label.new()
	pl.text = ("인내심 %d/%d" % [maxi(0, int(g.neg.patience)), int(g.neg.max_patience)]) if g.has_staff("profiler") else "인내심"
	pl.add_theme_font_override("font", font_r)
	pl.add_theme_font_size_override("font_size", 12)
	pl.add_theme_color_override("font_color", Color("#b8b8b0"))
	v.add_child(pl)


# ---------------------------------------------------------------- 아침·밤
func _render_morning() -> void:
	var sb := Button.new()
	sb.text = "열기"
	sb.position = Vector2(70, 150)
	sb.size = Vector2(190, 150)
	sb.rotation_degrees = -3
	sb.focus_mode = Control.FOCUS_NONE
	sb.add_theme_font_override("font", font_k)
	sb.add_theme_font_size_override("font_size", 56)
	for st in ["font_color", "font_pressed_color", "font_hover_color"]:
		sb.add_theme_color_override(st, Color("#fbefd9"))
	sb.add_theme_stylebox_override("normal", _box(Color("#9a6434"), 6, Color("#4a2a14"), 18, 8))
	sb.add_theme_stylebox_override("hover", _box(Color("#a8703c"), 6, Color("#4a2a14"), 18, 8))
	sb.add_theme_stylebox_override("pressed", _box(Color("#7a4a24"), 6, Color("#4a2a14"), 18, 8))
	sb.pressed.connect(func(): _act(func(): g.flip_open()))
	dyn.add_child(sb)
	lbl("가게 문 열기", Vector2(70, 306), Vector2(190, 24), 15, Color("#fbefd9"), font_b, HORIZONTAL_ALIGNMENT_CENTER)
	_render_newspaper()


func _render_newspaper() -> void:
	var n := g.news
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", _box(Color("#efe6cf"), 3, Color("#3a3428"), 4, 14))
	paper.position = Vector2(300, 60)
	paper.custom_minimum_size = Vector2(740, 330)
	paper.rotation_degrees = -1.2
	dyn.add_child(paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	paper.add_child(v)
	var mast := Label.new()
	mast.text = "흥정 일보"
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mast.add_theme_font_override("font", font_k)
	mast.add_theme_font_size_override("font_size", 38)
	mast.add_theme_color_override("font_color", Color("#1d1915"))
	v.add_child(mast)
	var sub := Label.new()
	sub.text = "%d일차 ─ %s" % [g.day, n.get("head", "")]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_override("font", font_b)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color("#1d1915"))
	v.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var cats: Dictionary = D.items["categories"]
	var items: Array = []
	if n.has("up"):
		items.append(["▲ %s" % cats[n["up"]]["n"], cats[n["up"]]["up"], func(): g.toast("%s 시세 상승! 이 종류는 비싸게 팔 수 있어요." % cats[n["up"]]["n"]), Color("#1d7a3a"), false])
		items.append(["▼ %s" % cats[n["dn"]]["n"], cats[n["dn"]]["dn"], func(): g.toast("%s 시세 하락. 싸게 사 두기 좋은 날일지도." % cats[n["dn"]]["n"]), Color("#b0301e"), false])
	if g.is_auction_today():
		items.append(["경매 공고", "오늘 시립 경매장 · 참가비 %s" % GameState.fmt(g.auction_fee()), func(): _open_auction(), Color("#8a1a2a"), true])
	if g.has_staff("analyst"):
		items.append(["분석가 메모", "내일은 %s이(가) 뜹니다" % cats[g.next_up]["n"], func(): pass, Color("#6b4126"), false])
	for k in D.staff:
		if not g.has_staff(k):
			items.append(["%s 구함" % D.staff[k]["n"], "%s · 일급 %s" % [D.staff[k]["pn"], GameState.fmt(D.staff[k]["w"])], func(): show_hire(k), Color("#2a6a5a"), true])
	for s in n.get("sub", []):
		items.append(["단신", s, func(): pass, Color("#3a3428"), false])
	for i in mini(items.size(), 12):
		var it: Array = items[i]
		var b := Button.new()
		b.text = "%s\n%s" % [it[0], it[1]]
		b.custom_minimum_size = Vector2(172, 64)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", font_b)
		b.add_theme_font_size_override("font_size", 12)
		for st in ["font_color", "font_pressed_color", "font_hover_color"]:
			b.add_theme_color_override(st, it[3])
		var ad: bool = it[4]
		var bc := Color("#3aa08a") if ad else Color("#b8ad94")
		b.add_theme_stylebox_override("normal", _box(Color("#efe6cf"), 3 if ad else 1, bc, 30 if ad else 2, 4))
		b.add_theme_stylebox_override("hover", _box(Color("#f6efdc"), 3 if ad else 1, bc, 30 if ad else 2, 4))
		b.add_theme_stylebox_override("pressed", _box(Color("#e0d6bc"), 3 if ad else 1, bc, 30 if ad else 2, 4))
		var cb: Callable = it[2]
		b.pressed.connect(func():
			cb.call()
			g.save_game()
			_flush_toasts())
		grid.add_child(b)


func _render_night() -> void:
	var sb := Button.new()
	sb.text = "영업 종료\n영수증 보기"
	sb.position = Vector2(440, 150)
	sb.size = Vector2(290, 150)
	sb.focus_mode = Control.FOCUS_NONE
	sb.add_theme_font_override("font", font_k)
	sb.add_theme_font_size_override("font_size", 28)
	for st in ["font_color", "font_pressed_color", "font_hover_color"]:
		sb.add_theme_color_override(st, Color("#9ac4ff"))
	sb.add_theme_stylebox_override("normal", _box(INK, 6, Color("#3a5a8a"), 18, 8))
	sb.add_theme_stylebox_override("pressed", _box(INK.lightened(0.1), 6, Color("#3a5a8a"), 18, 8))
	sb.add_theme_stylebox_override("hover", _box(INK.lightened(0.05), 6, Color("#3a5a8a"), 18, 8))
	sb.pressed.connect(func(): show_receipt())
	dyn.add_child(sb)


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
	var ww := minf(vs.x - 40, wdt)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(bgc, 6, border, 12, 16))
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
	b.add_theme_stylebox_override("normal", _box(bg, 0, Color.BLACK, 10, 6))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.08), 0, Color.BLACK, 10, 6))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.2), 0, Color.BLACK, 10, 6))
	b.add_theme_stylebox_override("disabled", _box(bg.darkened(0.3), 0, Color.BLACK, 10, 6))
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
	var h := row(v)
	var left := _vbox(h, Color("#f6efdc"))
	var spot := PanelContainer.new()
	spot.add_theme_stylebox_override("panel", _box(Color("#3a3a40"), 0, Color.BLACK, 10, 10))
	spot.custom_minimum_size = Vector2(300, 250)
	left.add_child(spot)
	var em := Label.new()
	em.text = it["e"]
	em.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	em.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	em.add_theme_font_size_override("font_size", 130)
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
		btn(cv, "🔍 정밀 감정  %s" % GameState.fmt(g.appr_fee(it)), func():
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
	grid.columns = 2
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
		t(cv, "%s  %s" % [it["e"], it["name"]], 18, font_k)
		var flags := ""
		if it["restoring"]:
			flags += " · 수리 중"
		if it["suspect"] or (it["known"] and it["fake"]):
			flags += " · 가품 확정" if it["known"] else " · 가품 의심"
		t(cv, "%s · %s · %s%s" % [rar["n"], D.items["condition"][int(it["c"])]["n"], D.items["categories"][it["cat"]]["n"], flags], 14, null, Color(rar["c"]).darkened(0.2))
		if g.is_pawned(it):
			t(cv, "🔒 담보 — %s님 · %d일차까지 · 상환 %s" % [it["pawn"]["owner"], int(it["pawn"]["due"]), GameState.fmt(it["pawn"]["repay"])], 14, font_b, Color("#8a5a10"))
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
	t(v, "시립 경매장 · %d/%d번 물건" % [int(a["i"]) + 1, a["lots"].size()], 24, font_k)
	var top := row(v)
	var left := _vbox(top, Color("#f6e7d0"))
	t(left, it["e"], 90, null, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
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
		t(cv, ("✋ " if lead else "") + b["n"], 12, font_b, Color("#ffd77a") if lead else null, HORIZONTAL_ALIGNMENT_CENTER)
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
	t(v, "한 번이라도 손에 넣은 물건이 기록됩니다. 한 종류를 모두 모으면 수집가 협회 상금과 평판을 받습니다.", 14)
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
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		v.add_child(grid)
		for it in items:
			var key := "%s/%s" % [ck, it[0]]
			var owned := g.collection.has(key)
			var card := PanelContainer.new()
			var rc := Color(D.items["rarity"][int(g.collection[key])]["c"]) if owned else Color("#4a4a5a")
			card.add_theme_stylebox_override("panel", _box(Color("#3a3a4e") if owned else Color("#2e2e3c"), 3, rc, 10, 6))
			card.custom_minimum_size = Vector2(100, 92)
			grid.add_child(card)
			var cv := VBoxContainer.new()
			cv.set_meta("ink", Color("#eceaf6"))
			card.add_child(cv)
			t(cv, it[1] if owned else "?", 30, null, Color.WHITE if owned else Color("#6a6a80"), HORIZONTAL_ALIGNMENT_CENTER)
			t(cv, it[0] if owned else "???", 11, font_b, null, HORIZONTAL_ALIGNMENT_CENTER)
