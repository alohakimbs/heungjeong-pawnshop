extends Control
## 메인 화면: 전당포 카운터 장면 하나가 곧 UI. 모든 조작은 가게 소품으로 한다.
## 설계 좌표 400x820 (웹 프로토타입 v0.2와 같은 좌표). 게임 규칙은 GameState에 있고 여기는 그리기·입력만.

const GameState := preload("res://scripts/core/game_state.gd")
const SvgArt := preload("res://scripts/ui/svg_art.gd")
const W := 400.0
const H := 820.0

var g: GameState
var D  # 게임 데이터 (오토로드 GameData, 없으면 직접 생성)
var font_r: Font = preload("res://assets/fonts/NotoSansKR-Regular.otf")
var font_b: Font = preload("res://assets/fonts/NotoSansKR-Bold.otf")
var font_k: Font = preload("res://assets/fonts/NotoSansKR-Black.otf")

var stage: Control
var back_tex: TextureRect
var cust_tex: TextureRect
var front_tex: TextureRect
var dyn: Control  # 매 렌더마다 다시 만드는 라벨·버튼
var modal: Control
var toast_lbl: Label
var bob_tween: Tween
var _cache := {}
var _px := 2.0  # 래스터 배율


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
	if g.phase == "morning":
		show_paper()
	elif g.phase == "night":
		show_receipt()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if g:
			g.save_game()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if modal and modal.visible:
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
	back_tex = _tex_rect(Vector2(0, 0), Vector2(W, 480))
	cust_tex = _tex_rect(Vector2(90, 120), Vector2(220, 355))
	front_tex = _tex_rect(Vector2(0, 396), Vector2(W, 424))
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
	toast_lbl.add_theme_color_override("font_color", Color("#2a1a0a"))
	toast_lbl.add_theme_stylebox_override("normal", _box(Color("#fff6a8"), 0, Color.BLACK, 4, 10))
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
	var px := clampf(snappedf(real, 0.5), 1.0, 4.0)
	if px != _px:
		_px = px
		_cache.clear()
		render()
	toast_lbl.position = Vector2(vs.x * 0.1, 16)
	toast_lbl.size = Vector2(vs.x * 0.8, 0)


func _box(c: Color, border := 0, bc := Color.BLACK, radius := 8, pad := 8) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_border_width_all(border)
	b.border_color = bc
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(pad)
	return b


# ================================================================ 그리기 도우미
func _raster(key: String, body: String, vb: Array) -> Texture2D:
	var k := "%s|%s" % [key, body.hash()]
	if _cache.has(k):
		return _cache[k]
	if _cache.size() > 40:
		_cache.clear()
	var t := SvgArt.rasterize(body, vb, _px)
	_cache[k] = t
	return t


func lbl(text: String, pos: Vector2, size: Vector2, fs := 14, color := Color("#1e1612"), font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, rot := 0.0) -> Label:
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
	l.clip_text = false
	dyn.add_child(l)
	return l


## 소품 위에 투명 버튼을 얹는다
func hot(rect: Rect2, label: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.flat = true
	b.tooltip_text = label
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	var press := _box(Color(1, 1, 1, 0.12), 0, Color.BLACK, 10)
	b.add_theme_stylebox_override("pressed", press)
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
	t.tween_interval(2.2)
	t.tween_callback(func(): toast_lbl.visible = false)


# ================================================================ 장면 렌더링
func render() -> void:
	if stage == null:
		return
	for c in dyn.get_children():
		c.queue_free()
	var c := g.cur
	back_tex.texture = _raster("back", _back_svg(), [0, 0, W, 480])
	_render_customer()
	front_tex.texture = _raster("front", _front_svg(), [0, 396, W, 424])
	_render_back_labels()
	if not c.is_empty():
		_render_bubble()
	_render_counter()
	_flush_toasts()


func _render_customer() -> void:
	var c := g.cur
	if c.is_empty():
		cust_tex.visible = false
		if bob_tween:
			bob_tween.kill()
		return
	var L: Dictionary
	if c.has("look"):
		L = SvgArt.look(c["look"])
	else:
		L = SvgArt.customer_look(c.get("arch", "student"), c["tr"], int(c.get("look_seed", 1)))
	var md := g.mood()
	cust_tex.texture = _raster("cust", SvgArt.draw_char(L, md), SvgArt.CHAR_VB)
	cust_tex.visible = true
	if bob_tween:
		bob_tween.kill()
	cust_tex.position = Vector2(90, 120)
	bob_tween = create_tween().set_loops()
	if md == "angry" and not c["gone"]:
		bob_tween.tween_property(cust_tex, "position:x", 84.0, 0.06)
		bob_tween.tween_property(cust_tex, "position:x", 96.0, 0.12)
		bob_tween.tween_property(cust_tex, "position:x", 90.0, 0.06)
		bob_tween.tween_interval(1.6)
	else:
		bob_tween.tween_property(cust_tex, "position:y", 124.0, 1.7).set_trans(Tween.TRANS_SINE)
		bob_tween.tween_property(cust_tex, "position:y", 120.0, 1.7).set_trans(Tween.TRANS_SINE)


func _back_svg() -> String:
	var sh := g.shop_info()
	var c := g.cur
	var s := '<defs><pattern id="st" width="24" height="24" patternUnits="userSpaceOnUse"><rect width="24" height="24" fill="%s"/><rect width="12" height="24" fill="#fff" opacity=".05"/><circle cx="18" cy="6" r="1.6" fill="#ffd77a" opacity=".25"/></pattern><radialGradient id="lamp" cx=".5" cy=".1" r=".75"><stop offset="0" stop-color="#ffe3a3" stop-opacity=".45"/><stop offset="1" stop-color="#000" stop-opacity=".35"/></radialGradient><linearGradient id="gl" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#cfe8f0" stop-opacity=".5"/><stop offset=".5" stop-color="#fff" stop-opacity=".2"/><stop offset="1" stop-color="#cfe8f0" stop-opacity=".5"/></linearGradient><linearGradient id="br" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffe29a"/><stop offset=".5" stop-color="#d9a441"/><stop offset="1" stop-color="#8a6420"/></linearGradient></defs>' % sh.get("wall", "#7a2e2a")
	s += '<rect width="400" height="480" fill="url(#st)"/><rect y="372" width="400" height="108" fill="#3e2416"/><rect y="368" width="400" height="8" fill="#7a4a2c"/>'
	for i in 4:
		s += '<rect x="%d" y="386" width="80" height="76" rx="3" fill="none" stroke="#000" stroke-opacity=".25" stroke-width="3"/>' % (10 + i * 100)
	s += '<rect width="400" height="480" fill="url(#lamp)"/><path d="M200 0 L200 22" stroke="#222" stroke-width="2"/><path d="M174 40 Q200 14 226 40Z" fill="#2a3a2a"/><ellipse cx="200" cy="40" rx="12" ry="4" fill="#ffe9a8"/>'
	if c.is_empty() and not g.is_auction_today():
		s += '<rect x="140" y="90" width="120" height="86" fill="#c9a227"/><rect x="148" y="98" width="104" height="70" fill="#2e4a5a"/><circle cx="222" cy="118" r="10" fill="#ffd77a"/><path d="M148 168 L180 130 L205 158 L222 140 L252 168Z" fill="#4a7a5a"/>'
	if g.is_auction_today():
		s += '<g transform="rotate(-4 200 140)"><rect x="140" y="88" width="120" height="96" fill="#f3ead4"/></g>'
	# 달력
	s += '<rect x="10" y="12" width="82" height="68" rx="3" fill="#fffaf0"/><rect x="10" y="12" width="82" height="20" rx="3" fill="#c4402a"/>'
	# 성향 메모지
	if not c.is_empty() and not c.get("visitor", false):
		for i in c["tr"].size():
			var seen: bool = c["seen"].has(c["tr"][i])
			s += '<g transform="rotate(%d 51 %d)"><rect x="12" y="%d" width="78" height="32" fill="%s"/></g>' % [-3 if i == 0 else 3, 104 + i * 36, 88 + i * 36, "#fff6a8" if seen else "#f0e6c8"]
	# 창고 문
	s += '<rect x="8" y="164" width="84" height="308" fill="#5a3420"/><rect x="14" y="170" width="72" height="300" fill="#7a4a2c"/><rect x="22" y="182" width="56" height="70" fill="#2a3a44"/><rect x="22" y="182" width="56" height="70" fill="url(#gl)"/><rect x="22" y="268" width="56" height="80" rx="3" fill="none" stroke="#000" stroke-opacity=".25" stroke-width="3"/><rect x="22" y="362" width="56" height="96" rx="3" fill="none" stroke="#000" stroke-opacity=".25" stroke-width="3"/><circle cx="76" cy="330" r="6" fill="url(#br)"/><rect x="20" y="274" width="60" height="40" rx="4" fill="#f6eedd"/>'
	# 코르크보드
	s += '<rect x="300" y="196" width="94" height="72" rx="3" fill="#6b4126"/><rect x="305" y="201" width="84" height="62" fill="#b98a55"/><rect x="318" y="254" width="58" height="18" rx="3" fill="#f6eedd"/>'
	for i in mini(g.staff.size(), 6):
		var x := 309 + (i % 3) * 27
		var y := 205 + (i / 3) * 29
		var L := SvgArt.look(D.staff[g.staff[i]]["L"])
		s += '<rect x="%d" y="%d" width="24" height="26" fill="#fff"/><svg x="%d" y="%d" width="20" height="18" viewBox="-60 -80 120 110">%s</svg>' % [x, y, x + 2, y + 2, SvgArt.draw_char(L, "ok")]
	# 진열장
	s += '<rect x="300" y="276" width="96" height="196" fill="#3a2214"/><rect x="305" y="281" width="86" height="186" fill="#1e120c"/>'
	for y in [340, 402, 464]:
		s += '<rect x="303" y="%d" width="90" height="6" fill="#6b4126"/>' % y
	return s


func _front_svg() -> String:
	var c := g.cur
	var it := g.cur_item()
	var s := '<defs><linearGradient id="wd" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8a5634"/><stop offset=".08" stop-color="#6b4126"/><stop offset="1" stop-color="#3e2414"/></linearGradient><radialGradient id="felt" cx=".5" cy=".4" r=".6"><stop offset="0" stop-color="#2f6a52"/><stop offset="1" stop-color="#1a3f30"/></radialGradient><linearGradient id="br" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffe29a"/><stop offset=".5" stop-color="#d9a441"/><stop offset="1" stop-color="#8a6420"/></linearGradient></defs>'
	# 모래시계 (손님 앞)
	if not c.is_empty() and not c.get("visitor", false) and g.neg != null:
		var m := g.neg.patience_ratio() if not c["gone"] else (0.0 if c["mood"] == "angry" else g.neg.patience_ratio())
		var col := "#e6b85a" if m > 0.33 else "#d9483a"
		s += '<g transform="translate(110,400)"><rect x="-2" y="0" width="36" height="6" rx="2" fill="url(#br)"/><rect x="-2" y="62" width="36" height="6" rx="2" fill="url(#br)"/><path d="M4 6 L28 6 Q28 26 18 34 Q28 42 28 62 L4 62 Q4 42 14 34 Q4 26 4 6Z" fill="#dff1f5" fill-opacity=".55" stroke="#9ab" stroke-width="1.5"/><path d="M%s %s L%s %s L17 32 L15 32Z" fill="%s"/><path d="M5 61 Q16 %s 27 61Z" fill="%s"/></g>' % [SvgArt.n(16 - 11 * m), SvgArt.n(30 - 22 * m), SvgArt.n(16 + 11 * m), SvgArt.n(30 - 22 * m), col, SvgArt.n(61 - 24 * (1 - m)), col]
	# 카운터
	s += '<path d="M0 470 L400 470 L400 820 L0 820Z" fill="url(#wd)"/><rect y="466" width="400" height="10" fill="#a06a3d"/><rect y="476" width="400" height="3" fill="#000" opacity=".3"/>'
	for y in [530, 610, 700, 780]:
		s += '<path d="M0 %d Q120 %d 220 %d T400 %d" stroke="#000" stroke-opacity=".12" stroke-width="2" fill="none"/>' % [y, y - 6, y + 2, y]
	# 금전등록기
	s += '<path d="M10 600 L14 520 L108 520 L112 600Z" fill="#8a2a22"/><rect x="18" y="490" width="86" height="36" rx="4" fill="#5a1a14"/><rect x="24" y="496" width="74" height="24" rx="2" fill="#0e2a1a"/>'
	for r in 3:
		for k in 4:
			s += '<rect x="%d" y="%d" width="16" height="10" rx="2" fill="#f0e4cc"/>' % [22 + k * 20, 534 + r * 14]
	s += '<rect x="10" y="582" width="102" height="18" fill="#5a1a14"/>'
	if g.sp > 0:
		s += '<g transform="rotate(8 98 494)"><rect x="80" y="478" width="34" height="30" fill="#fff6a8"/></g>'
	# 펠트 매트
	s += '<ellipse cx="184" cy="548" rx="66" ry="44" fill="url(#felt)"/><ellipse cx="184" cy="548" rx="58" ry="37" fill="none" stroke="#d9a441" stroke-opacity=".5" stroke-dasharray="4 4"/>'
	if not it.is_empty():
		s += '<circle cx="184" cy="540" r="34" fill="%s" opacity=".35"/>' % D.items["rarity"][int(it["r"])]["c"]
		s += '<path d="M232 528 Q246 510 262 506" stroke="#e8dcc0" stroke-width="2" fill="none"/><path d="M260 490 L392 490 L392 600 L260 600 L252 545Z" fill="#f6eedd"/><circle cx="264" cy="545" r="4" fill="#7a4f2c"/><circle cx="279" cy="528" r="5" fill="%s"/>' % D.items["rarity"][int(it["r"])]["c"]
		if it["known"] and it["fake"]:
			s += '<g transform="rotate(-14 184 548)"><rect x="140" y="530" width="88" height="34" rx="5" fill="none" stroke="#c4402a" stroke-width="4"/></g>'
		if it["suspect"] and not it["known"]:
			s += '<g transform="rotate(10 360 512)"><rect x="330" y="498" width="58" height="24" rx="4" fill="none" stroke="#c4402a" stroke-width="3"/></g>'
	# 신문
	s += '<g transform="rotate(-6 350 650)"><rect x="306" y="612" width="86" height="72" fill="#efe6cf"/><rect x="312" y="618" width="74" height="12" fill="#2a2a2a"/>'
	for y in [640, 650, 660, 670]:
		s += '<rect x="312" y="%d" width="%d" height="4" fill="#9a9080"/>' % [y, 74 if y % 20 else 44]
	s += '</g>'
	var live := g.is_haggling()
	if live and not it.is_empty() and not it["known"]:
		s += '<circle cx="336" cy="736" r="20" fill="#cfe8f0" fill-opacity=".5" stroke="url(#br)" stroke-width="6"/><path d="M350 750 L366 768" stroke="#6b4126" stroke-width="9" stroke-linecap="round"/>'
	if live and not c["buy"] and not it.is_empty() and (it["suspect"] or (it["known"] and it["fake"])) and not c["accused"]:
		s += '<g transform="rotate(-8 350 790)"><rect x="306" y="772" width="88" height="40" rx="6" fill="#c4402a"/></g>'
	if g.phase == "open" and not c.is_empty() and not c.get("visitor", false):
		var op := "1" if live else ".35"
		s += '<g opacity="%s"><ellipse cx="50" cy="660" rx="34" ry="8" fill="#3a2214"/><path d="M22 658 Q22 622 50 620 Q78 622 78 658Z" fill="url(#br)"/><rect x="46" y="608" width="8" height="12" rx="3" fill="#8a6420"/><circle cx="50" cy="607" r="6" fill="url(#br)"/>' % op
		s += '<rect x="10" y="698" width="80" height="50" rx="8" fill="#f6eedd"/><path d="M24 728 Q30 712 44 714 L60 712 Q72 714 76 724 L70 734 Q58 742 44 738 Q30 738 24 728Z" fill="#eac29a" stroke="#8a5a3a" stroke-width="2"/>'
		s += '<rect x="14" y="774" width="72" height="34" rx="6" fill="#4a5a6a"/></g>'
		s += '<rect x="100" y="606" width="200" height="210" rx="14" fill="#2e3238"/><rect x="104" y="610" width="192" height="202" rx="11" fill="#3c424a"/><rect x="110" y="616" width="180" height="44" rx="5" fill="#b7c8a4"/>'
	if g.phase in ["morning", "night"]:
		var night := g.phase == "night"
		s += '<path d="M150 590 L200 562 L250 590" stroke="#c9a227" stroke-width="3" fill="none"/><circle cx="200" cy="560" r="5" fill="url(#br)"/><rect x="104" y="590" width="192" height="100" rx="10" fill="#2a1a10"/><rect x="112" y="598" width="176" height="84" rx="6" fill="none" stroke="%s" stroke-width="3"/>' % ("#3a5a8a" if night else "#c4402a")
	return s


func _render_back_labels() -> void:
	var c := g.cur
	lbl("%d일차" % g.day, Vector2(10, 12), Vector2(82, 20), 13, Color.WHITE, font_b, HORIZONTAL_ALIGNMENT_CENTER)
	lbl("평판 %d" % g.rep, Vector2(10, 34), Vector2(82, 26), 18, Color("#1e1612"), font_k, HORIZONTAL_ALIGNMENT_CENTER)
	lbl("Lv.%d 딜러" % g.lv, Vector2(10, 58), Vector2(82, 20), 12, Color("#6b4126"), font_b, HORIZONTAL_ALIGNMENT_CENTER)
	if c.is_empty() and not g.is_auction_today():
		lbl("창업 기념 · %s" % g.shop_info()["n"], Vector2(100, 180), Vector2(200, 24), 14, Color("#fbe7c9"), font_b, HORIZONTAL_ALIGNMENT_CENTER)
	if g.is_auction_today():
		lbl("오늘 경매!\n시립 경매장\n참가비 %s" % GameState.fmt(g.auction_fee()), Vector2(140, 92), Vector2(120, 88), 15, Color("#8a1a2a"), font_k, HORIZONTAL_ALIGNMENT_CENTER, -4)
		hot(Rect2(136, 84, 128, 104), "경매 참가", func(): _open_auction())
	if not c.is_empty() and not c.get("visitor", false):
		for i in c["tr"].size():
			var k: String = c["tr"][i]
			var seen: bool = c["seen"].has(k)
			lbl(D.traits["traits"][k]["n"] if seen else "성향 ?", Vector2(12, 88 + i * 36), Vector2(78, 32), 15, Color("#2a1a0a"), font_b, HORIZONTAL_ALIGNMENT_CENTER, -3 if i == 0 else 3)
			var desc: String = ("%s: %s" % [D.traits["traits"][k]["n"], D.traits["traits"][k]["d"]]) if seen else "심리 스킬이나 프로파일러가 있으면 보입니다"
			hot(Rect2(12, 88 + i * 36, 78, 32), desc, func(): g.toast(desc))
	lbl("창고", Vector2(20, 276), Vector2(60, 20), 15, Color("#3a2010"), font_k, HORIZONTAL_ALIGNMENT_CENTER)
	lbl("%d/%d" % [g.inv.size(), g.cap()], Vector2(20, 294), Vector2(60, 18), 14, Color("#c4402a") if g.inv.size() >= g.cap() else Color("#3a2010"), font_b, HORIZONTAL_ALIGNMENT_CENTER)
	hot(Rect2(8, 164, 84, 308), "창고 열기", func(): show_inv())
	if g.staff.is_empty():
		lbl("구인 중!", Vector2(305, 210), Vector2(84, 30), 14, Color("#3a2010"), font_b, HORIZONTAL_ALIGNMENT_CENTER)
	lbl("직원", Vector2(318, 254), Vector2(58, 18), 12, Color("#3a2010"), font_k, HORIZONTAL_ALIGNMENT_CENTER)
	hot(Rect2(300, 196, 94, 72), "직원 게시판", func(): show_staff())
	for i in mini(g.inv.size(), 12):
		var l := lbl(g.inv[i]["e"], Vector2(308 + (i % 4) * 21, 312 + (i / 4) * 62), Vector2(22, 26), 17, Color.WHITE, null, HORIZONTAL_ALIGNMENT_CENTER)
	hot(Rect2(300, 276, 96, 120), "진열장 (창고)", func(): show_inv())


func _render_bubble() -> void:
	var c := g.cur
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", _box(Color("#2a1a10"), 0, Color.BLACK, 6, 4))
	tag.position = Vector2(104, 8)
	var tl := Label.new()
	tl.text = "%s · %s%s" % [c["name"], c["role"], " ★단골" if c.get("sk", "") != "" else ""]
	tl.add_theme_font_override("font", font_b)
	tl.add_theme_font_size_override("font_size", 14)
	tl.add_theme_color_override("font_color", Color("#ffd77a"))
	tag.add_child(tl)
	dyn.add_child(tag)
	var bub := PanelContainer.new()
	bub.add_theme_stylebox_override("panel", _box(Color("#fffaf0"), 3, Color("#2a1a10"), 16, 10))
	bub.position = Vector2(100, 38)
	bub.custom_minimum_size = Vector2(292, 0)
	bub.size = Vector2(292, 0)
	bub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := Label.new()
	bl.text = c["msg"]
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(270, 0)
	bl.add_theme_font_override("font", font_r)
	bl.add_theme_font_size_override("font_size", 14)
	bl.add_theme_color_override("font_color", Color("#1e1612"))
	bub.add_child(bl)
	dyn.add_child(bub)
	var tail := Polygon2D.new()
	tail.color = Color("#fffaf0")
	dyn.add_child(tail)
	var fit_tail := func():
		var by := bub.position.y + bub.size.y
		tail.polygon = PackedVector2Array([Vector2(182, by - 3), Vector2(196, by + 16), Vector2(206, by - 3)])
	bub.resized.connect(fit_tail)
	fit_tail.call_deferred()


func _render_counter() -> void:
	var c := g.cur
	var it := g.cur_item()
	var live := g.is_haggling()
	lbl(GameState.fmt(g.money), Vector2(24, 496), Vector2(74, 24), 14 if str(g.money).length() > 6 else 16, Color("#ff7a6a") if g.money < 0 else Color("#7dffb0"), font_b, HORIZONTAL_ALIGNMENT_CENTER)
	lbl("장부 · 성장", Vector2(10, 582), Vector2(102, 18), 12, Color("#ffd77a"), font_b, HORIZONTAL_ALIGNMENT_CENTER)
	if g.sp > 0:
		lbl("SP+%d" % g.sp, Vector2(80, 480), Vector2(34, 26), 12, Color("#c4402a"), font_k, HORIZONTAL_ALIGNMENT_CENTER, 8)
	hot(Rect2(8, 486, 106, 116), "장부·성장", func(): show_ledger())
	# 물건
	if not it.is_empty():
		var rar: Dictionary = D.items["rarity"][int(it["r"])]
		lbl(it["e"], Vector2(144, 508), Vector2(80, 64), 46, Color.WHITE, null, HORIZONTAL_ALIGNMENT_CENTER)
		if it["known"] and it["fake"]:
			lbl("가품", Vector2(140, 530), Vector2(88, 34), 20, Color("#c4402a"), font_k, HORIZONTAL_ALIGNMENT_CENTER, -14)
		lbl(it["name"], Vector2(272, 494), Vector2(120, 22), 15 if it["name"].length() <= 7 else 13, Color("#1e1612"), font_k)
		var tr := g.trend_of(it["cat"])
		lbl("%s · %s%s" % [rar["n"], D.items["condition"][int(it["c"])]["n"], " ▲" if tr > 1.12 else (" ▼" if tr < 0.88 else "")], Vector2(288, 520), Vector2(104, 18), 12, Color("#1e1612"))
		var e := g.est(it)
		lbl("정밀 감정가" if it["known"] else "추정가", Vector2(272, 540), Vector2(110, 16), 11, Color("#6b5a48"))
		lbl(GameState.fmt(g.val(it, false)) if it["known"] else "%s~%s" % [GameState.fmt(e[0]), GameState.fmt(e[1])], Vector2(272, 556), Vector2(120, 22), 15 if it["known"] else 13, Color("#1f6a66"), font_k)
		lbl("매입가 %s" % GameState.fmt(it["paid"]) if int(it["paid"]) > 0 else ("탭: 추정가 입력" if live else ""), Vector2(272, 578), Vector2(120, 18), 11, Color("#8a6a4a"), font_b)
		if it["suspect"] and not it["known"]:
			lbl("가품?", Vector2(330, 498), Vector2(58, 24), 13, Color("#c4402a"), font_k, HORIZONTAL_ALIGNMENT_CENTER, 10)
		if live:
			hot(Rect2(252, 488, 144, 114), "추정가를 계산기에 입력", func():
				var ee := g.est(it)
				g.draft = GameState.r10(g.val(it, false)) if it["known"] else (ee[1] if c["buy"] else ee[0]))
	# 신문
	lbl("신문", Vector2(306, 690), Vector2(86, 20), 14, Color("#fbe7c9"), font_b, HORIZONTAL_ALIGNMENT_CENTER)
	hot(Rect2(300, 606, 96, 108), "신문 읽기", func(): show_paper())
	if live and not it.is_empty() and not it["known"]:
		lbl("정밀 감정 %s" % GameState.fmt(g.appr_fee(it)), Vector2(300, 776), Vector2(100, 18), 12, Color("#fbe7c9"), font_b, HORIZONTAL_ALIGNMENT_CENTER)
		hot(Rect2(310, 712, 70, 66), "돋보기 정밀 감정", func(): g.appraise(it["id"]))
	if live and not c["buy"] and not it.is_empty() and (it["suspect"] or (it["known"] and it["fake"])) and not c["accused"]:
		lbl("가짜잖아요!", Vector2(306, 772), Vector2(88, 40), 15, Color.WHITE, font_k, HORIZONTAL_ALIGNMENT_CENTER, -8)
		hot(Rect2(304, 768, 92, 48), "가품 지적", func(): g.accuse())
	# 아침/밤 팻말, 불청객, 흥정
	match g.phase:
		"morning":
			lbl("CLOSED", Vector2(104, 600), Vector2(192, 44), 30, Color("#ff8a6a"), font_k, HORIZONTAL_ALIGNMENT_CENTER)
			lbl("탭해서 영업 시작", Vector2(104, 644), Vector2(192, 30), 16, Color("#fbe7c9"), font_b, HORIZONTAL_ALIGNMENT_CENTER)
			hot(Rect2(104, 588, 192, 104), "영업 시작", func(): g.flip_open())
		"night":
			lbl("영업 종료", Vector2(104, 600), Vector2(192, 44), 28, Color("#9ac4ff"), font_k, HORIZONTAL_ALIGNMENT_CENTER)
			lbl("탭해서 영수증 보기", Vector2(104, 644), Vector2(192, 30), 16, Color("#fbe7c9"), font_b, HORIZONTAL_ALIGNMENT_CENTER)
			hot(Rect2(104, 588, 192, 104), "영수증 보기", func(): show_receipt())
		"visit":
			if not c["gone"]:
				for i in c["opts"].size():
					_big_button(Rect2(104, 616 + i * 66, 288, 56), "\"%s\"" % c["opts"][i], Color("#1f8a86"), Color.WHITE, func(): g.visit_pick(i))
			else:
				_big_button(Rect2(104, 616, 288, 64), "손님 맞이 시작 ▶", Color("#d9a441"), Color("#2a1a0a"), func(): g.open_shop())
		"open":
			_render_haggle()


func _big_button(rect: Rect2, text: String, bg: Color, fg: Color, cb: Callable) -> void:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_k)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_stylebox_override("normal", _box(bg, 3, bg.darkened(0.4), 14))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.06), 3, bg.darkened(0.4), 14))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.15), 3, bg.darkened(0.4), 14))
	b.pressed.connect(func(): _act(cb))
	dyn.add_child(b)


func _render_haggle() -> void:
	var c := g.cur
	var live := g.is_haggling()
	var their := g.their_price()
	lbl("최종 제안", Vector2(10, 676), Vector2(80, 20), 14, Color("#ffd77a"), font_k, HORIZONTAL_ALIGNMENT_CENTER)
	hot(Rect2(14, 600, 72, 96), "종 치기: 최종 제안", func(): g.propose(g.draft, true), live)
	lbl("%s 수락" % GameState.fmt(their), Vector2(4, 752), Vector2(92, 18), 12, Color("#ffd77a"), font_k, HORIZONTAL_ALIGNMENT_CENTER)
	hot(Rect2(8, 696, 84, 76), "악수: 손님 가격 수락", func(): g.accept(), live)
	lbl("안 팔아요" if c["buy"] else "안 사요", Vector2(14, 774), Vector2(72, 34), 15, Color.WHITE, font_k, HORIZONTAL_ALIGNMENT_CENTER)
	hot(Rect2(12, 772, 76, 40), "거절", func(): g.refuse(), live)
	# 계산기
	if c["gone"]:
		lbl(c["res"], Vector2(116, 618), Vector2(170, 40), 13, Color("#1e2a14"), font_b).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_big_button(Rect2(110, 668, 180, 140), ("다음 손님\n대기 %d명 ▶" % g.queue) if g.queue > 0 else "가게 문 닫기\n오늘 장사 끝 ▶", Color("#d9a441"), Color("#2a1a0a"), func(): g.next_customer())
		return
	lbl("%s %s%s" % ["손님 제시" if c["buy"] else "손님 요구", GameState.fmt(their), (" · 내 직전 %s" % GameState.fmt(g.neg.last)) if g.neg.last != -1 else ""], Vector2(114, 616), Vector2(172, 18), 10, Color("#3a4a2a"))
	lbl(GameState.fmt(g.draft), Vector2(114, 632), Vector2(170, 28), 22, Color("#14200c"), font_k, HORIZONTAL_ALIGNMENT_RIGHT)
	var keys := [["7", "8", "9", "⌫"], ["4", "5", "6", "-10%"], ["1", "2", "3", "+10%"], ["0", "00", "C", "제시"]]
	for j in 4:
		for i in 4:
			var k: String = keys[j][i]
			var ok := k == "제시"
			var op := i == 3 or k == "C"
			var bgc := Color("#1f8a86") if ok else (Color("#5a636e") if op else Color("#e8e2d4"))
			var b := Button.new()
			b.position = Vector2(110 + i * 46, 666 + j * 37)
			b.size = Vector2(42, 33)
			b.text = k
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_override("font", font_k)
			b.add_theme_font_size_override("font_size", 13 if k.length() > 2 else 17)
			var fg := Color.WHITE if (ok or op) else Color("#1e1612")
			for st in ["font_color", "font_pressed_color", "font_hover_color"]:
				b.add_theme_color_override(st, fg)
			var sb := _box(bgc, 0, Color.BLACK, 6, 0)
			sb.shadow_color = Color(0, 0, 0, 0.35)
			sb.shadow_offset = Vector2(0, 3)
			sb.shadow_size = 1
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sb)
			b.add_theme_stylebox_override("pressed", _box(bgc.darkened(0.2), 0, Color.BLACK, 6, 0))
			b.pressed.connect(func(): _act(func(): _key(k)))
			dyn.add_child(b)


func _key(k: String) -> void:
	if not g.is_haggling():
		return
	var their := g.their_price()
	match k:
		"제시":
			g.propose(g.draft)
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


# ================================================================ 오버레이
func close_modal() -> void:
	modal.visible = false
	for c in modal.get_children():
		c.queue_free()
	render()


## 실물 느낌의 시트(신문·장부·창고 등). 내용을 담을 VBoxContainer를 돌려준다.
func sheet(bgc: Color, ink: Color, border := Color("#6b4126"), closable := true) -> VBoxContainer:
	for c in modal.get_children():
		c.queue_free()
	modal.visible = true
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.02, 0.01, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var vs := get_viewport_rect().size
	var wdt := minf(vs.x - 24, 520)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(bgc, 6, border, 6, 14))
	panel.position = Vector2((vs.x - wdt) / 2, 18)
	panel.size = Vector2(wdt, vs.y - 36)
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
		x.add_theme_font_size_override("font_size", 16)
		x.add_theme_color_override("font_color", ink)
		x.size_flags_horizontal = Control.SIZE_SHRINK_END
		x.pressed.connect(close_modal)
		v.add_child(x)
	return v


func t(v: VBoxContainer, text: String, fs := 15, font: Font = null, color = null, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
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
	b.add_theme_font_size_override("font_size", 16)
	for st in ["font_color", "font_pressed_color", "font_hover_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", fg.darkened(0.4))
	b.add_theme_stylebox_override("normal", _box(bg, 0, Color.BLACK, 8, 6))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.08), 0, Color.BLACK, 8, 6))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.2), 0, Color.BLACK, 8, 6))
	b.add_theme_stylebox_override("disabled", _box(bg.darkened(0.3), 0, Color.BLACK, 8, 6))
	b.pressed.connect(func():
		cb.call()
		g.save_game()
		_flush_toasts())
	parent.add_child(b)
	return b


func row(v: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	return h


func show_paper() -> void:
	var v := sheet(Color("#f3ead4"), Color("#1d1915"), Color("#1d1915"))
	var n := g.news
	t(v, "흥정 일보", 34, font_k, null, HORIZONTAL_ALIGNMENT_CENTER)
	t(v, "%d일차 · 1부 $1 · 단골 할인 없음" % g.day, 13, null, null, HORIZONTAL_ALIGNMENT_CENTER)
	t(v, n.get("head", ""), 22, font_k)
	t(v, "시세 소식", 16, font_b)
	var an := g.has_staff("analyst")
	var cats: Dictionary = D.items["categories"]
	if n.has("up"):
		var pu := "" if not an else " (%+d%%)" % int(round((g.trend_of(n["up"]) - 1) * 100))
		var pd := "" if not an else " (%+d%%)" % int(round((g.trend_of(n["dn"]) - 1) * 100))
		t(v, "▲ %s — %s%s" % [cats[n["up"]]["n"], cats[n["up"]]["up"], pu], 15, font_b, Color("#1d7a3a"))
		t(v, "▼ %s — %s%s" % [cats[n["dn"]]["n"], cats[n["dn"]]["dn"], pd], 15, font_b, Color("#b0301e"))
		if an:
			t(v, "분석가 메모: 내일은 %s이(가) 뜹니다!" % cats[g.next_up]["n"], 15, font_b, Color("#6b4126"))
	t(v, "단신", 16, font_b)
	for s in n.get("sub", []):
		t(v, s, 14)
	t(v, ("[공고] 오늘 시립 경매장 경매. 참가비 %s" % GameState.fmt(g.auction_fee())) if g.day == g.auction_day else "다음 경매: %d일차" % g.auction_day, 14, font_b)
	btn(v, "신문 내려놓기", close_modal)


func show_receipt() -> void:
	var r := g.receipt
	if r.is_empty():
		return
	var v := sheet(Color("#fffdf6"), Color("#222222"), Color("#cccccc"), false)
	t(v, "흥정왕 전당포", 22, font_k, null, HORIZONTAL_ALIGNMENT_CENTER)
	t(v, "%s · %d일차 마감" % [r["shop"], r["day"]], 14, null, null, HORIZONTAL_ALIGNMENT_CENTER)
	for pair in [["거래", "%d건" % r["deals"]], ["매입", GameState.fmt(-r["bought"])], ["판매", GameState.fmt(r["sold"])], ["임대료", GameState.fmt(-r["rent"])], ["직원 급여", GameState.fmt(-r["wages"])], ["현금 변화", GameState.fmt(r["d"])], ["경험치", "+%d XP" % r["xp"]]]:
		var h := row(v)
		var a := t(v, pair[0], 15)
		a.reparent(h)
		a.autowrap_mode = TextServer.AUTOWRAP_OFF
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := t(v, pair[1], 15, font_b, Color("#2f8a4a") if pair[0] == "현금 변화" and r["d"] >= 0 else (Color("#c4402a") if pair[0] == "현금 변화" else null), HORIZONTAL_ALIGNMENT_RIGHT)
		b.reparent(h)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
	for nt in r["notes"]:
		t(v, "· " + nt, 14)
	t(v, "*창고 물건은 현금이 아니라 재고입니다.", 12, null, Color("#777777"))
	btn(v, "결과 보기" if g.is_bankrupt() else "불 끄고 퇴근 → 다음 날", func():
		if not g.next_day():
			_show_bankrupt()
			return
		close_modal()
		show_paper())


func _show_bankrupt() -> void:
	var v := sheet(Color("#f3ead4"), Color("#1d1915"), Color("#1d1915"), false)
	t(v, "파산!", 32, font_k)
	t(v, "%d일 동안 버텼습니다. 빚쟁이들이 셔터를 두드립니다." % g.day, 16)
	btn(v, "새로 시작", func():
		g = GameState.new(D)
		g.start_day()
		g.save_game()
		close_modal()
		show_paper())


func show_inv() -> void:
	var v := sheet(Color("#7a4f2c"), Color("#fbefd9"), Color("#4a2a18"))
	t(v, "창고 %d/%d" % [g.inv.size(), g.cap()], 26, font_k)
	t(v, "사러 온 손님은 여기서 물건을 고릅니다. 도매상은 흥정 없이 바로 사 가지만 실제 가치의 절반만 쳐주고, 가품은 귀신같이 알아봅니다.", 13)
	if g.inv.is_empty():
		t(v, "텅 비었다... 손님에게 물건을 사들이자.", 16, font_b)
	var items := g.inv.duplicate()
	items.sort_custom(func(a, b): return g.val(a, true) > g.val(b, true))
	for it in items:
		g.inspect(it)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(Color("#f6eedd"), 0, Color.BLACK, 10, 10))
		v.add_child(card)
		var cv := VBoxContainer.new()
		cv.set_meta("ink", Color("#1e1612"))
		card.add_child(cv)
		var rar: Dictionary = D.items["rarity"][int(it["r"])]
		t(cv, "%s  %s" % [it["e"], it["name"]], 18, font_k)
		var flags := ""
		if it["restoring"]:
			flags += " · 수리 중"
		if it["suspect"] or (it["known"] and it["fake"]):
			flags += " · 가품 확정" if it["known"] else " · 가품 의심"
		t(cv, "%s · %s · %s%s" % [rar["n"], D.items["condition"][int(it["c"])]["n"], D.items["categories"][it["cat"]]["n"], flags], 13, null, Color(rar["c"]).darkened(0.2))
		var e := g.est(it)
		t(cv, ("감정가 %s" % GameState.fmt(g.val(it, false))) if it["known"] else "추정 %s~%s" % [GameState.fmt(e[0]), GameState.fmt(e[1])], 15, font_b, Color("#1f6a66"))
		t(cv, "매입 %s" % GameState.fmt(it["paid"]), 13)
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
			show_inv(), Color("#c4402a"), Color.WHITE, not it["restoring"])


func show_staff() -> void:
	var v := sheet(Color("#b98a55"), Color("#1e1612"), Color("#6b4126"))
	t(v, "직원 게시판", 26, font_k)
	t(v, "자리 %d/%d · 가게를 넓히면 자리가 늘어요" % [g.staff.size(), g.staff_slots()], 14, font_b)
	for k in D.staff:
		var s: Dictionary = D.staff[k]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(Color.WHITE, 0, Color.BLACK, 2, 8))
		v.add_child(card)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		card.add_child(h)
		var pic := TextureRect.new()
		pic.texture = _raster("staff_" + k + str(g.has_staff(k)), SvgArt.draw_char(SvgArt.look(s["L"]), "happy" if g.has_staff(k) else "ok"), [-80, -100, 160, 175])
		pic.custom_minimum_size = Vector2(96, 105)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(pic)
		var cv := VBoxContainer.new()
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.set_meta("ink", Color("#1e1612"))
		h.add_child(cv)
		t(cv, s["pn"], 17, font_k)
		t(cv, "%s · 일급 %s" % [s["n"], GameState.fmt(s["w"])], 13, font_b, Color("#6b4126"))
		t(cv, s["d"], 13)
		t(cv, s["q"], 13, null, Color("#555555"))
		if g.has_staff(k):
			btn(cv, "해고", func():
				g.fire(k)
				show_staff(), Color("#c4402a"), Color.WHITE)
		else:
			btn(cv, "고용", func():
				g.hire(k)
				show_staff(), Color("#1f8a86"), Color.WHITE, g.staff.size() < g.staff_slots())


func show_ledger() -> void:
	var v := sheet(Color("#fbf6e9"), Color("#22201c"), Color("#5a2a1c"))
	t(v, "사장 장부", 26, font_k)
	t(v, "Lv.%d 딜러 · 경험치 %d/%d · 스킬 포인트 %d" % [g.lv, g.xp, g.lv * 120, g.sp], 15, font_b)
	var sk := {"haggle": ["흥정", "판매자는 더 싸게, 구매자는 더 비싸게"], "appraise": ["감정", "추정가가 좁아지고 가품이 보임"], "psych": ["심리", "손님 성향을 읽음 (1레벨 1개, 3레벨 전부)"], "charm": ["화술", "손님 인내심 증가"]}
	for k in sk:
		var h := row(v)
		var cv := VBoxContainer.new()
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.set_meta("ink", Color("#22201c"))
		h.add_child(cv)
		t(cv, "%s  %s%s" % [sk[k][0], "●".repeat(g.skills[k]), "○".repeat(5 - g.skills[k])], 17, font_k)
		t(cv, sk[k][1], 12)
		var b := btn(h, "+1", func():
			g.skill_up(k)
			show_ledger(), Color("#1f8a86"), Color.WHITE, g.sp > 0 and g.skills[k] < 5)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.custom_minimum_size = Vector2(64, 46)
	var cur_sh := g.shop_info()
	t(v, "가게", 20, font_k)
	t(v, "지금: %s · 임대료 %s/일 · 창고 %d칸 · 손님 %d명" % [cur_sh["n"], GameState.fmt(cur_sh["rent"]), g.cap(), int(cur_sh["cust"])], 14)
	if g.shop + 1 < D.shops.size():
		var nx: Dictionary = D.shops[g.shop + 1]
		t(v, "다음: %s · 창고 %d칸 · 손님 %d명 · 임대료 %s/일" % [nx["n"], int(nx["st"]), int(nx["cust"]), GameState.fmt(nx["rent"])], 13)
		btn(v, "%s에 이전 계약" % GameState.fmt(nx["cost"]), func():
			g.move_shop()
			show_ledger(), Color("#d9a441"), Color("#2a1a0a"), g.can_move())
	else:
		t(v, "최고의 가게! 이 거리의 흥정왕입니다.", 15, font_b)
	t(v, "단골 수첩", 20, font_k)
	if g.rel.is_empty():
		t(v, "아직 단골이 없습니다. ★단골 손님은 지난 거래를 기억합니다.", 13)
	var outcome := {"steal": "내가 이득", "fair": "공정 거래", "angry": "화내고 떠남", "scam": "가품을 팔았음"}
	for k in g.rel:
		t(v, "%s — 방문 %d회, 지난번: %s" % [D.specials[k]["n"], int(g.rel[k]["visits"]), outcome.get(g.rel[k].get("last", ""), "-")], 14)
	t(v, "누적 거래 %d건 · 판매 차익 %s" % [int(g.stats["deals"]), GameState.fmt(g.stats["profit"])], 13)
	btn(v, "처음부터 다시 하기", func():
		var w := sheet(Color("#f3ead4"), Color("#1d1915"), Color("#1d1915"))
		t(w, "처음부터 다시?", 24, font_k)
		t(w, "지금 진행 상황이 사라집니다.", 15)
		btn(w, "다시 시작", func():
			g = GameState.new(D)
			g.start_day()
			g.save_game()
			close_modal()
			show_paper(), Color("#c4402a"), Color.WHITE), Color("#8a8178"), Color.WHITE)


func _open_auction() -> void:
	if g.start_auction():
		show_auction()
	else:
		_flush_toasts()


func show_auction() -> void:
	if g.auction.is_empty():
		close_modal()
		return
	var v := sheet(Color("#24161a"), Color("#f6e7d0"), Color("#a8823a"), false)
	var it := g.lot()
	var a := g.auction
	t(v, "시립 경매장 · %d/%d번 물건" % [int(a["i"]) + 1, a["lots"].size()], 22, font_k)
	var h := row(v)
	for b in D.text["auction_npcs"]:
		var cv := VBoxContainer.new()
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.set_meta("ink", Color("#f6e7d0"))
		h.add_child(cv)
		var pic := TextureRect.new()
		var lead: bool = a["leader"] == b["n"]
		pic.texture = _raster("npc_" + b["n"] + str(lead), SvgArt.draw_char(SvgArt.look(b["L"]), "happy" if lead else "ok"), [-80, -100, 160, 175])
		pic.custom_minimum_size = Vector2(80, 88)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cv.add_child(pic)
		t(cv, ("🖐 " if lead else "") + b["n"], 12, font_b, Color("#ffd77a") if lead else null, HORIZONTAL_ALIGNMENT_CENTER)
	var rar: Dictionary = D.items["rarity"][int(it["r"])]
	var e := g.est(it, not g.has_staff("expert"))
	t(v, "%s %s" % [it["e"], it["name"]], 22, font_k)
	t(v, "%s · %s%s" % [rar["n"], D.items["condition"][int(it["c"])]["n"] if g.has_staff("expert") else "상태 ?", " · 가품 의심" if it["suspect"] else ""], 14, font_b, Color(rar["c"]).lightened(0.3))
	t(v, "추정가 %s ~ %s · 내 금고 %s · 창고 %d/%d" % [GameState.fmt(e[0]), GameState.fmt(e[1]), GameState.fmt(g.money), g.inv.size(), g.cap()], 13)
	t(v, GameState.fmt(a["price"]), 34, font_k, Color("#ffd77a"), HORIZONTAL_ALIGNMENT_CENTER)
	t(v, ("내가 최고가" if a["leader"] == "me" else a["leader"] + " 최고가") if a["leader"] != "" else "아직 입찰 없음", 14, null, null, HORIZONTAL_ALIGNMENT_CENTER)
	if a["over"]:
		t(v, a["res"], 17, font_b, null, HORIZONTAL_ALIGNMENT_CENTER)
		btn(v, "다음 물건" if int(a["i"]) < a["lots"].size() - 1 else "경매장 나가기", func():
			if not g.auction_next():
				close_modal()
				show_paper()
			else:
				show_auction(), Color("#d9a441"), Color("#2a1a0a"))
	else:
		btn(v, "번호판 들기  %s" % GameState.fmt(g.next_bid_price()), func():
			g.auction_bid()
			show_auction(), Color("#d9a441"), Color("#3a2108"))
		btn(v, "이번 물건 포기", func():
			g.auction_pass()
			show_auction(), Color("#4a3a3e"), Color("#f6e7d0"), a["leader"] != "me")
	for l in a["log"]:
		t(v, l, 13, null, Color("#d9c3a5"))
