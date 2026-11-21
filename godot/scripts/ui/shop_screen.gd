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
const PRICE_POS := Vector2(110, 862)
const COUNTER_Y := 660.0
const DESK_Y := 740.0

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
var title: Control
var _last_cust := ""
var fx: Control  # 도장 자국·돈 글씨 같은 잠깐 연출
var _auto_tw: Tween  # 손님이 떠나면 잠시 뒤 다음 손님
const NEXT_DELAY := 0.9


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
	_show_title()


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
	front_tex = _tex_rect(Vector2(0, COUNTER_Y - 80), Vector2(W, H - COUNTER_Y + 80))
	dyn = Control.new()
	dyn.size = Vector2(W, H)
	dyn.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.add_child(dyn)
	fx = Control.new()
	fx.size = Vector2(W, H)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(fx)
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	add_child(modal)
	toast_lbl = Label.new()
	toast_lbl.add_theme_font_override("font", font_b)
	toast_lbl.add_theme_font_size_override("font_size", 17)
	toast_lbl.add_theme_color_override("font_color", INK)
	toast_lbl.add_theme_stylebox_override("normal", _tex_box("hanji", Color("#f6e7c0"), 16))
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
	toast_lbl.position = Vector2(vs.x * 0.08, vs.y * 0.80)
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
	var art := "res://assets/items/%s.png" % key
	if ResourceLoader.exists(art):
		return load(art)
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
	_brisk()
	var after := _state_snap()
	_play_for(before, after)
	g.save_game()
	render()
	_fx_for(before, after)
	_tutorial()
	_schedule_next()


func _state_snap() -> Dictionary:
	return {"name": g.cur.get("name", ""), "gone": g.cur.get("gone", false), "visitor": g.cur.get("visitor", false), "mood": g.cur.get("mood", ""), "money": g.money, "lv": g.lv, "rounds": g.neg.rounds if g.neg != null else 0}


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
	toast_lbl.size.y = 0
	var t := create_tween()
	t.tween_interval(clampf(1.2 + m.length() * 0.05, 1.6, 4.5))
	t.tween_callback(func(): toast_lbl.visible = false)


# ================================================================ 렌더링
func render() -> void:
	if stage == null:
		return
	for c in dyn.get_children():
		c.queue_free()
	var bg_path := "res://assets/bg/bg_%d.png" % g.shop
	if ResourceLoader.exists(bg_path):
		# 손그림 배경(2:3): 위쪽 540x810을 채우고 나머지는 어두운 바닥색
		back_tex.texture = load(bg_path)
		back_tex.size = Vector2(W, W * 1.5)
		back_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		back_tex.texture = _raster("back", _back_svg(), [0, 0, W, H])
		back_tex.size = Vector2(W, H)
		back_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_render_queue()
	_render_customer()
	front_tex.texture = _raster("front", _front_svg(), [0, COUNTER_Y - 80, W, H - COUNTER_Y + 80])
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


# ================================================================ 경쾌한 진행
## 원작처럼 손님이 들어오자마자 물건을 내밀고 값을 부른다(인사·살펴보기 단계 생략).
## 살펴보기는 계산대 위 물건을 누르면 언제든 열린다.
func _brisk() -> void:
	if g.phase != "open" or g.cur.is_empty() or g.cur.get("visitor", false) or g.cur.get("gone", false):
		return
	if g.cur.get("stage", "") == "intro":
		var greet: String = g.cur.get("msg", "")
		g.look_item()
		g.start_haggle()
		# 인사말 + 부른 값을 한 말풍선에
		if greet != "" and not String(g.cur["msg"]).begins_with(greet):
			g.cur["msg"] = greet + " " + String(g.cur["msg"])


## 손님이 떠났으면 잠깐 반응을 보여 준 뒤 다음 손님을 자동으로 부른다.
func _schedule_next() -> void:
	if _auto_tw:
		_auto_tw.kill()
		_auto_tw = null
	if g.phase != "open" or g.cur.is_empty() or not g.cur.get("gone", false) or g.cur.get("visitor", false):
		return
	var who: String = g.cur.get("name", "")
	_auto_tw = create_tween()
	_auto_tw.tween_interval(NEXT_DELAY)
	_auto_tw.tween_callback(func():
		if modal.visible or title != null:
			return
		if g.phase == "open" and g.cur.get("gone", false) and g.cur.get("name", "") == who:
			_act(func(): g.next_customer()))


# ================================================================ 연출
## 거래 성사 → 장부에 붉은 「成」 도장이 쿵. 돈이 바뀌면 위에 금액이 떠오른다.
func _fx_for(a: Dictionary, b: Dictionary) -> void:
	var dm := int(b["money"]) - int(a["money"])
	if dm != 0:
		var l := Label.new()
		l.text = ("+" if dm > 0 else "−") + GameState.fmt(absi(dm))
		l.add_theme_font_override("font", font_k)
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", Color("#ffe08a") if dm > 0 else Color("#ff8a6a"))
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", Color("#1a0c06"))
		l.position = Vector2(360, 56)
		l.size = Vector2(170, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fx.add_child(l)
		var tw := create_tween()
		tw.tween_property(l, "position:y", 86.0, 0.7).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.35)
		tw.tween_callback(l.queue_free)
	if b["gone"] and not a["gone"] and b["name"] == a["name"] and not b.get("visitor", false):
		var ok: bool = b["mood"] == "happy"
		var st := Label.new()
		st.text = "成" if ok else "破"
		st.add_theme_font_override("font", font_k)
		st.add_theme_font_size_override("font_size", 84)
		st.add_theme_color_override("font_color", Color(SEAL, 0.85) if ok else Color(0.15, 0.1, 0.08, 0.8))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(6)
		sb.border_color = Color(SEAL, 0.85) if ok else Color(0.15, 0.1, 0.08, 0.8)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(4)
		st.add_theme_stylebox_override("normal", sb)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.size = Vector2(130, 130)
		st.position = Vector2(W / 2 - 65, DESK_Y + 60)
		st.pivot_offset = Vector2(65, 65)
		st.rotation_degrees = -12
		st.scale = Vector2(2.2, 2.2)
		st.modulate.a = 0.0
		fx.add_child(st)
		var tw := create_tween()
		tw.tween_property(st, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(st, "modulate:a", 1.0, 0.1)
		tw.tween_interval(0.5)
		tw.tween_property(st, "modulate:a", 0.0, 0.25)
		tw.tween_callback(st.queue_free)


## 첫날 안내: 처음 한 번씩만 한지 쪽지로 알려 준다.
func _tutorial() -> void:
	var seen: Array = g.stats.get("tut", [])
	var key := ""
	var msg := ""
	if g.phase == "morning":
		key = "morning"
		msg = "아침마다 「은하 일보」에서 오르고 내린 물건을 확인하세요. 준비가 되면 아래 영업패를 눌러 문을 엽니다."
	elif g.phase == "open" and not g.cur.is_empty() and not g.cur.get("visitor", false):
		match g.cur.get("stage", ""):
			"intro":
				key = "intro"
				msg = "손님을 누르면 성향이 보입니다. 장부에 적힌 글씨를 눌러 대답하세요."
			"look":
				key = "look"
				msg = "계산대 위 물건을 누르면 다시 살펴볼 수 있어요. 견적보다 싸게 사서 비싸게 파는 게 장사!"
			"haggle":
				key = "haggle"
				msg = "손님이 값을 불렀어요! 숫자를 끌어 내 값을 정하고 「제안」 도장을 쾅. 향이 다 타면 손님이 떠나요. 물건을 누르면 자세히 볼 수 있어요."
	if key == "" or seen.has(key):
		return
	seen.append(key)
	g.stats["tut"] = seen
	toast(msg)


## 타이틀: 대전당 배경 + 이름 + 이어하기/새로 시작
func _show_title() -> void:
	title = Control.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.z_index = 40
	add_child(title)
	var vs := get_viewport_rect().size
	var bgc := ColorRect.new()
	bgc.color = Color("#120c14")
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(bgc)
	var art := TextureRect.new()
	if ResourceLoader.exists("res://assets/bg/bg_4.png"):
		art.texture = load("res://assets/bg/bg_4.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size = vs
	art.modulate = Color(0.75, 0.72, 0.8)
	title.add_child(art)
	for k in [["fox_happy", Vector2(vs.x * 0.02, vs.y * 0.42), false], ["rabbit_happy", Vector2(vs.x * 0.56, vs.y * 0.44), true]]:
		var cp := TextureRect.new()
		cp.texture = _char_tex(String(k[0]).split("_")[0], "happy")
		cp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		cp.size = Vector2(vs.x * 0.42, vs.y * 0.42)
		cp.position = k[1]
		cp.flip_h = k[2]
		title.add_child(cp)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.02, 0.04, 0.55)
	shade.position = Vector2(0, vs.y * 0.08)
	shade.size = Vector2(vs.x, 200)
	title.add_child(shade)
	var name_l := Label.new()
	name_l.text = "흥정왕 전당포"
	name_l.add_theme_font_override("font", font_k)
	name_l.add_theme_font_size_override("font_size", 56)
	name_l.add_theme_color_override("font_color", Color("#f6d27a"))
	name_l.add_theme_constant_override("outline_size", 8)
	name_l.add_theme_color_override("font_outline_color", Color("#2a1408"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.position = Vector2(0, vs.y * 0.08 + 36)
	name_l.size = Vector2(vs.x, 80)
	title.add_child(name_l)
	var sub := Label.new()
	sub.text = "궤도 위 한옥 전당포에서 은하 골동을 흥정하라"
	sub.add_theme_font_override("font", font_b)
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color("#f1e6cb"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, vs.y * 0.08 + 120)
	sub.size = Vector2(vs.x, 30)
	title.add_child(sub)
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", _tex_box("hanji", HANJI, 22))
	paper.position = Vector2(vs.x * 0.15, vs.y * 0.74)
	paper.custom_minimum_size = Vector2(vs.x * 0.7, 0)
	title.add_child(paper)
	var v := VBoxContainer.new()
	v.set_meta("ink", INK)
	v.add_theme_constant_override("separation", 6)
	paper.add_child(v)
	var fresh: bool = g.day <= 1 and g.phase == "morning" and int(g.stats.get("deals", 0)) == 0
	btn(v, "처음 시작하기" if fresh else "이어하기  ·  %d일째" % g.day, func():
		sfx.play("door")
		_close_title())
	if not fresh:
		btn(v, "새로 시작하기", func():
			g = GameState.new(D)
			g.start_day()
			g.save_game()
			_close_title(), Color("#8a3020"))
	btn(v, "효과음 끄기" if not sfx.muted else "효과음 켜기", func():
		sfx.muted = not sfx.muted
		g.stats["muted"] = sfx.muted
		title.queue_free()
		_show_title(), Color("#5a5a5a"))


func _close_title() -> void:
	_brisk()
	if title:
		var t0 := title
		title = null
		var tw := create_tween()
		tw.tween_property(t0, "modulate:a", 0.0, 0.35)
		tw.tween_callback(t0.queue_free)
	render()
	_tutorial()
	if g.phase == "night":
		show_receipt()


## 손그림 캐릭터(assets/chars). 없으면 null → 코드 그림으로 대신한다.
func _char_key(c: Dictionary) -> String:
	if c.get("visitor", false):
		var art: String = c.get("art", "")
		if art == "" and D.events.has(c.get("vk", "")):
			art = String(D.events[c["vk"]].get("art", ""))
		return art if art != "" else "v_" + String(c.get("vk", ""))
	var sk: String = c.get("sk", "")
	if sk != "":
		return "granny_junk" if sk == "granny" else sk
	return String(c.get("arch", ""))


func _char_tex(base: String, mood: String) -> Texture2D:
	if base == "":
		return null
	for k in [base + "_" + mood, base + "_ok", base]:
		var path := "res://assets/chars/%s.png" % k
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _render_queue() -> void:
	var waiting: Array = g.upcoming if g.phase == "open" else []
	var spots := [Vector2(452, 392), Vector2(8, 392)]
	for i in 2:
		var t: TextureRect = queue_tex[i]
		if i < waiting.size():
			var art := _char_tex(_char_key(waiting[i]), "ok")
			t.texture = art if art != null else _raster("q%d" % i, SvgArt.draw_char(_look_of(waiting[i]), "ok", true), SvgArt.STAND_VB)
			t.position = spots[i]
			t.size = Vector2(78, 168)
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.modulate = Color(0.5, 0.48, 0.62, 0.7)
			t.visible = true
		else:
			t.visible = false


func _render_customer() -> void:
	var c := g.cur
	if c.is_empty() or not (g.phase == "open" or g.phase == "visit"):
		cust_tex.visible = false
		if bob_tween:
			bob_tween.kill()
		return
	var md := g.mood()
	var art := _char_tex(_char_key(c), md)
	var base := Vector2(120, 170)
	if art != null:
		# 전신 그림: 머리는 말풍선 아래, 무릎 아래는 계산대에 가려진다. 비율 유지(늘어나 흐려지지 않게 최대 높이 제한).
		var hh := 500.0
		var ww := minf(hh * art.get_width() / float(art.get_height()), 500.0)
		cust_tex.texture = art
		cust_tex.stretch_mode = TextureRect.STRETCH_SCALE
		cust_tex.size = Vector2(ww, hh)
		base = Vector2((W - ww) / 2.0, 200)
		cust_tex.flip_h = c.get("arch", "") != "" and int(c.get("look_seed", 0)) % 2 == 1
	cust_tex.visible = true
	if bob_tween:
		bob_tween.kill()
	cust_tex.position = base
	var who := "%s|%s" % [c.get("name", ""), c.get("vk", "")]
	if who != _last_cust:
		_last_cust = who
		cust_tex.modulate.a = 0.0
		var tin := create_tween()
		tin.tween_property(cust_tex, "modulate:a", 1.0, 0.18)
	elif c.get("gone", false):
		var tout := create_tween()
		tout.tween_interval(0.35)
		tout.tween_property(cust_tex, "modulate:a", 0.0, 0.45)
	else:
		cust_tex.modulate.a = 1.0
	bob_tween = create_tween().set_loops()
	if md == "angry" and not c.get("gone", false):
		bob_tween.tween_property(cust_tex, "position:x", base.x - 8, 0.06)
		bob_tween.tween_property(cust_tex, "position:x", base.x + 8, 0.12)
		bob_tween.tween_property(cust_tex, "position:x", base.x, 0.06)
		bob_tween.tween_interval(1.6)
	else:
		bob_tween.tween_property(cust_tex, "position:y", base.y + 5, 1.7).set_trans(Tween.TRANS_SINE)
		bob_tween.tween_property(cust_tex, "position:y", base.y, 1.7).set_trans(Tween.TRANS_SINE)
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
	var dy := DESK_Y
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := func(v: float) -> String: return SvgArt.n(v)
	var s := '<defs>'
	s += '<linearGradient id="cf" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6a3a22"/><stop offset="1" stop-color="#2e170c"/></linearGradient>'
	s += '<linearGradient id="ct" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b0723e"/><stop offset="1" stop-color="#6a3a1e"/></linearGradient>'
	s += '<linearGradient id="dk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7a4a2a"/><stop offset="1" stop-color="#4a2a16"/></linearGradient>'
	s += '<radialGradient id="lamp" cx="0.5" cy="0.05" r="0.9"><stop offset="0" stop-color="#ffd890" stop-opacity="0.35"/><stop offset="1" stop-color="#000" stop-opacity="0.45"/></radialGradient>'
	s += '<radialGradient id="silk" cx="0.4" cy="0.35" r="0.8"><stop offset="0" stop-color="#fff" stop-opacity="0.45"/><stop offset="1" stop-color="#000" stop-opacity="0.25"/></radialGradient>'
	s += '</defs>'
	# --- 계산대 앞판
	s += '<rect x="0" y="%s" width="540" height="%s" fill="url(#cf)"/>' % [n.call(y0 + 22), n.call(dy - y0 - 22)]
	var x := 0.0
	while x < 540:
		s += '<path d="M%s,%s V%s" stroke="#1a0c06" stroke-width="2" opacity="0.6"/>' % [n.call(x), n.call(y0 + 22), n.call(dy)]
		for k in 3:
			var gy := y0 + 40 + rng.randf() * (dy - y0 - 60)
			s += '<path d="M%s,%s q%s,%s %s,%s" stroke="#000" stroke-width="1" fill="none" opacity="0.18"/>' % [n.call(x + 8), n.call(gy), n.call(20), n.call(rng.randf_range(-6, 6)), n.call(54), n.call(rng.randf_range(-4, 4))]
		x += 67.5
	# 단청 띠
	s += '<rect x="0" y="%s" width="540" height="16" fill="#2f6a5a"/>' % n.call(y0 + 8)
	var bx := 0.0
	while bx < 540:
		s += '<path d="M%s,%s h18 l6,8 l-6,8 h-18 l6,-8 Z" fill="#c8402e"/><circle cx="%s" cy="%s" r="3" fill="#f0c860"/><path d="M%s,%s h10" stroke="#3a5aa0" stroke-width="3"/>' % [n.call(bx + 4), n.call(y0 + 8), n.call(bx + 34), n.call(y0 + 16), n.call(bx + 40), n.call(y0 + 16)]
		bx += 54
	s += '<path d="M0,%s H540 M0,%s H540" stroke="#1a0c06" stroke-width="2.5"/>' % [n.call(y0 + 8), n.call(y0 + 24)]
	# 계산대 상판
	s += '<rect x="-4" y="%s" width="548" height="22" rx="3" fill="url(#ct)" stroke="#1a0c06" stroke-width="3"/>' % n.call(y0 - 12)
	s += '<path d="M4,%s H536" stroke="#f0c890" stroke-width="2" opacity="0.55"/>' % n.call(y0 - 8)
	if ResourceLoader.exists("res://assets/ui/props.png"):
		pass  # 손그림 궤짝·장부·방석은 _render_counter에서 그림 위에 얹는다
	else:
		s += _props_svg(it, y0)
	s += '<rect x="0" y="%s" width="540" height="%s" fill="url(#dk)"/>' % [n.call(dy), n.call(H - dy)]
	return s + _desk_svg(dy, rng)


func _props_svg(it: Dictionary, y0: float) -> String:
	var n := func(v: float) -> String: return SvgArt.n(v)
	var s := ""
	# 비단 방석 (희귀도 색)
	var cloth := "#3a5aa0" if it.is_empty() else str(D.items["rarity"][int(it["r"])]["c"])
	s += '<ellipse cx="270" cy="%s" rx="118" ry="16" fill="#000" opacity="0.35"/>' % n.call(y0 + 2)
	s += '<path d="M160,%s Q270,%s 380,%s Q392,%s 380,%s Q270,%s 160,%s Q148,%s 160,%s Z" fill="%s" stroke="#1a0c06" stroke-width="3"/>' % [n.call(y0 - 26), n.call(y0 - 40), n.call(y0 - 26), n.call(y0 - 12), n.call(y0 + 2), n.call(y0 + 12), n.call(y0 + 2), n.call(y0 - 12), n.call(y0 - 26), cloth]
	s += '<path d="M160,%s Q270,%s 380,%s Q392,%s 380,%s Q270,%s 160,%s Q148,%s 160,%s Z" fill="url(#silk)"/>' % [n.call(y0 - 26), n.call(y0 - 40), n.call(y0 - 26), n.call(y0 - 12), n.call(y0 + 2), n.call(y0 + 12), n.call(y0 + 2), n.call(y0 - 12), n.call(y0 - 26)]
	s += '<path d="M176,%s Q270,%s 364,%s" stroke="#f0d080" stroke-width="2" fill="none" stroke-dasharray="5 4"/>' % [n.call(y0 - 14), n.call(y0 - 2), n.call(y0 - 14)]
	for tx in [158.0, 382.0]:
		s += '<path d="M%s,%s v10" stroke="#d9a441" stroke-width="3"/><path d="M%s,%s l-5,16 h10 Z" fill="#c8402e" stroke="#1a0c06" stroke-width="1.5"/>' % [n.call(tx), n.call(y0 - 4), n.call(tx), n.call(y0 + 6)]
	# 반닫이 궤짝 (창고)
	s += '<g transform="translate(18,%s)">' % n.call(y0 - 72)
	s += '<rect x="2" y="70" width="128" height="8" fill="#000" opacity="0.35"/>'
	s += '<rect width="128" height="72" rx="4" fill="#7a4222" stroke="#1a0c06" stroke-width="3"/>'
	s += '<rect x="0" y="0" width="128" height="22" rx="4" fill="#8a4e2a" stroke="#1a0c06" stroke-width="3"/>'
	for c2 in [[0, 0], [110, 0], [0, 54], [110, 54]]:
		s += '<rect x="%d" y="%d" width="18" height="18" fill="#c9963a" stroke="#1a0c06" stroke-width="1.5"/>' % c2
	s += '<path d="M52,22 h24 v20 a12,12 0 0 1 -24,0 Z" fill="#d9a441" stroke="#1a0c06" stroke-width="2"/><circle cx="64" cy="38" r="3" fill="#1a0c06"/>'
	s += '</g>'
	# 장부 더미 + 붓
	s += '<g transform="translate(410,%s)">' % n.call(y0 - 46)
	s += '<rect x="0" y="30" width="110" height="16" rx="2" fill="#3a4a6a" stroke="#1a0c06" stroke-width="2.5"/><rect x="6" y="16" width="100" height="16" rx="2" fill="#8a3030" stroke="#1a0c06" stroke-width="2.5"/><rect x="2" y="2" width="104" height="16" rx="2" fill="#d8c8a0" stroke="#1a0c06" stroke-width="2.5"/>'
	s += '<path d="M30,2 v44 M78,2 v44" stroke="#c8402e" stroke-width="2"/>'
	s += '<path d="M20,-6 L100,-20" stroke="#5a3420" stroke-width="5" stroke-linecap="round"/><path d="M100,-20 l12,-2" stroke="#1a0c06" stroke-width="7" stroke-linecap="round"/>'
	s += '</g>'
	return s


func _desk_svg(dy: float, rng: RandomNumberGenerator) -> String:
	var n := func(v: float) -> String: return SvgArt.n(v)
	var s := ""
	var py := dy
	while py < H:
		s += '<path d="M0,%s H540" stroke="#1a0c06" stroke-width="2" opacity="0.55"/>' % n.call(py)
		for k in 4:
			var gx := rng.randf_range(0, 460)
			s += '<path d="M%s,%s c30,%s 70,%s 110,%s" stroke="#000" stroke-width="1.2" fill="none" opacity="0.16"/>' % [n.call(gx), n.call(py + rng.randf_range(10, 52)), n.call(rng.randf_range(-6, 6)), n.call(rng.randf_range(-6, 6)), n.call(rng.randf_range(-3, 3))]
		s += '<path d="M%s,%s q8,-6 16,0 q-8,6 -16,0" fill="#2a160a" opacity="0.4"/>' % [n.call(rng.randf_range(20, 500)), n.call(py + rng.randf_range(15, 45))]
		py += 62
	s += '<rect x="0" y="%s" width="540" height="%s" fill="url(#lamp)"/>' % [n.call(dy), n.call(H - dy)]
	s += '<rect x="0" y="%s" width="540" height="10" fill="#000" opacity="0.45"/><path d="M0,%s H540" stroke="#1a0c06" stroke-width="4"/>' % [n.call(dy), n.call(dy)]
	return s


func _render_hud() -> void:
	# 대들보 위: [장부] · 날짜/가게 · 돈
	pic(_raster("beam", _beam_svg(), [0, 0, W, 66]), Vector2.ZERO, Vector2(W, 66))
	lbl("%d일째" % g.day, Vector2(14, 4), Vector2(200, 28), 21, HANJI, font_k)
	lbl(g.shop_info()["n"], Vector2(14, 30), Vector2(220, 20), 13, GOLD, font_b)
	pic(_icon("coins"), Vector2(352, 10), Vector2(40, 40))
	lbl(GameState.fmt(g.money), Vector2(392, 10), Vector2(140, 40), 21, Color("#ff8a6a") if g.money < 0 else Color("#ffe2a0"), font_k, HORIZONTAL_ALIGNMENT_RIGHT)


## 위쪽 대들보: 나무 + 금테 + 단청 띠
func _beam_svg() -> String:
	var s := '<defs><linearGradient id="bm" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4a2a1a"/><stop offset="1" stop-color="#2a160c"/></linearGradient></defs>'
	s += '<rect width="540" height="58" fill="url(#bm)"/>'
	for i in 6:
		s += '<path d="M%d,%d c60,-4 120,4 180,0" stroke="#000" stroke-width="1" fill="none" opacity="0.25"/>' % [i * 90, 10 + (i * 7) % 40]
	s += '<rect y="52" width="540" height="8" fill="#2f6a5a"/>'
	var x := 0
	while x < 540:
		s += '<path d="M%d,52 l6,4 l-6,4 l-6,-4 Z" fill="#c8402e"/><circle cx="%d" cy="56" r="1.8" fill="#f0c860"/>' % [x + 10, x + 22]
		x += 24
	s += '<path d="M0,52 H540 M0,60 H540" stroke="#d9a441" stroke-width="1.5"/><path d="M0,61.5 H540" stroke="#000" stroke-width="3" opacity="0.5"/>'
	s += '<rect x="356" y="10" width="176" height="38" rx="4" fill="#000" opacity="0.3"/>'
	return s


## 물건에 매단 작은 한지 꼬리표
func _obj_tag(pos: Vector2, text: String, fg: Color) -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#efe2c0")
	sb.border_color = Color("#3a2414")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.rotation_degrees = -4
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_k)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", fg)
	p.add_child(l)
	dyn.add_child(p)


func _render_counter() -> void:
	var it := g.cur_item()
	var full := g.inv.size() >= g.cap()
	_obj_tag(Vector2(30, COUNTER_Y - 104), "창고 %d/%d" % [g.inv.size(), g.cap()], Color("#9a2a1a") if full else INK)
	hot(Rect2(14, COUNTER_Y - 110, 140, 130), "창고 열기", func(): show_inv())
	_obj_tag(Vector2(424, COUNTER_Y - 84), "장부" + (" ●" if g.sp > 0 else ""), SEAL if g.sp > 0 else INK)
	hot(Rect2(396, COUNTER_Y - 110, 140, 130), "장부 열기", func(): show_menu())
	if not it.is_empty() and g.phase == "open":
		pic(_icon(it["e"]), Vector2(195, COUNTER_Y - 152), Vector2(150, 150))
		if it["known"] and it["fake"]:
			lbl("가품", Vector2(220, COUNTER_Y - 90), Vector2(100, 44), 28, SEAL, font_k, HORIZONTAL_ALIGNMENT_CENTER, -14)
		hot(Rect2(180, COUNTER_Y - 160, 180, 180), "물건 살펴보기", func(): show_inspect(it))


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
		return ["방문객 · " + c["name"], Color("#c98a5a")]
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
	box.add_theme_stylebox_override("panel", _tex_box("hanji", HANJI, 14))
	box.position = Vector2(18, 72)
	box.size = Vector2(504, 0)
	box.custom_minimum_size = Vector2(504, 92)
	var bl := Label.new()
	bl.text = c["msg"]
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var lines := int(ceil(String(c["msg"]).length() / 25.0))
	bl.custom_minimum_size = Vector2(478, maxf(66, lines * 28))
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
	tail.position = Vector2(0, 72 + maxf(92, lines * 28 + 28) - 3)
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
		_page()
		var y := DESK_Y + 40.0
		for o in _choices():
			_ink_line(Rect2(44, y, 452, 52), o[0], o[1], o.size() > 2 and o[2], 21)
			y += 60.0


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
			var out: Array = [[("%s, 그만큼 빌려드리리다" if c.get("pawn", false) else ("%s, 그 값에 팔겠소" if c.get("buy", false) else "%s, 그 값에 사겠소")) % GameState.fmt(g.their_price()), func(): g.accept()]]
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


## 흥정 중 아래 책상: 펼친 흥정 장부(물건·값·향) + 책상 위 도장 세 개. 버튼처럼 보이는 상자 없이 그림 위를 누른다.
func _render_haggle_desk() -> void:
	var it := g.cur_item()
	if it.is_empty() or g.neg == null:
		return
	var pawn: bool = g.cur.get("pawn", false)
	_page()
	var y0 := DESK_Y + 14.0
	var rar: Dictionary = D.items["rarity"][int(it["r"])]
	var e := g.est(it)
	var est_s: String = GameState.fmt(g.val(it, false)) if it["known"] else "%s~%s" % [GameState.fmt(e[0]), GameState.fmt(e[1])]
	lbl(it["name"], Vector2(46, y0 + 10), Vector2(280, 28), 19, INK, font_k)
	lbl("%s · %s" % [rar["n"], D.items["condition"][int(it["c"])]["n"]], Vector2(46, y0 + 38), Vector2(280, 20), 14, Color(rar["c"]).darkened(0.3), font_b)
	var extra := ""
	if g.cur.has("read"):
		extra = " · 속마음 %s~%s" % [GameState.fmt(g.cur["read"][0]), GameState.fmt(g.cur["read"][1])]
	if pawn:
		extra = " · %d일 · 상환 %d%%" % [g.cur["days"], int(round((1.1 + 0.03 * g.cur["days"]) * 100))]
	lbl("견적 %s%s" % [est_s, extra], Vector2(46, y0 + 60), Vector2(450, 22), 14, Color("#1f5a56"), font_b)
	lbl("빌려 달라는 돈" if pawn else "손님 부른 값", Vector2(300, y0 + 10), Vector2(196, 20), 13, Color("#7a6a5a"), font_b, HORIZONTAL_ALIGNMENT_RIGHT)
	lbl(GameState.fmt(g.their_price()), Vector2(280, y0 + 28), Vector2(216, 34), 26, SEAL, font_k, HORIZONTAL_ALIGNMENT_RIGHT)
	hot(Rect2(300, y0 + 4, 200, 64), "손님 값 그대로 수락", func(): g.accept())
	# 인내심: 향로에 꽂힌 향이 타들어 간다
	var m := clampf(g.neg.patience_ratio(), 0, 1)
	lbl("향", Vector2(44, y0 + 80), Vector2(24, 22), 14, Color("#6a4a2a"), font_k)
	var burner := ColorRect.new()
	burner.color = Color("#5a3a22")
	burner.position = Vector2(66, y0 + 86)
	burner.size = Vector2(10, 10)
	burner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dyn.add_child(burner)
	var stick := ColorRect.new()
	stick.color = Color("#a0703a")
	stick.position = Vector2(76, y0 + 89)
	stick.size = Vector2(416 * m, 3)
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dyn.add_child(stick)
	var ember := ColorRect.new()
	ember.color = Color("#e8502e") if m < 0.34 else Color("#f0a040")
	ember.position = Vector2(76 + 416 * m - 3, y0 + 87)
	ember.size = Vector2(6, 7)
	ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dyn.add_child(ember)
	var smoke := lbl("∿", Vector2(76 + 416 * m - 8, y0 + 68), Vector2(20, 20), 16, Color(0.4, 0.35, 0.3, 0.6), font_b)
	smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween().set_loops()
	tw.tween_property(smoke, "position:y", y0 + 62, 1.2)
	tw.parallel().tween_property(smoke, "modulate:a", 0.2, 1.2)
	tw.tween_property(smoke, "position:y", y0 + 68, 0.01)
	tw.parallel().tween_property(smoke, "modulate:a", 1.0, 0.01)
	smoke.tree_exiting.connect(func(): tw.kill())
	if g.has_staff("profiler"):
		lbl("인내심 %d/%d" % [maxi(0, int(g.neg.patience)), int(g.neg.max_patience)], Vector2(356, y0 + 92), Vector2(140, 18), 11, Color("#7a6a5a"), font_b, HORIZONTAL_ALIGNMENT_RIGHT)
	# 내 값: 붓글씨 숫자 + 양옆 먹 표시(−/+), 끌거나 눌러서 입력
	var py := y0 + 108.0
	_ink_mark(Rect2(40, py, 64, 58), false, func():
		g.draft = maxi(10, GameState.r10(g.draft - maxf(10.0, g.their_price() * 0.05))))
	_ink_mark(Rect2(436, py, 64, 58), true, func():
		g.draft = GameState.r10(g.draft + maxf(10.0, g.their_price() * 0.05)))
	lbl(GameState.fmt(g.draft), PRICE_POS, Vector2(320, 58), 36, INK, font_k, HORIZONTAL_ALIGNMENT_CENTER)
	var ul := ColorRect.new()
	ul.color = Color(0.16, 0.1, 0.06, 0.7)
	ul.position = Vector2(150, py + 56)
	ul.size = Vector2(240, 3)
	ul.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dyn.add_child(ul)
	var pb := hot(Rect2(110, py, 320, 60), "내 제시 가격: 좌우로 끌어 조정, 눌러서 직접 입력", func(): show_keypad())
	pb.gui_input.connect(_on_sign_drag)
	if int(g.stats.get("deals", 0)) < 3:
		lbl("숫자를 좌우로 끌거나 눌러서 쓰기", Vector2(90, py + 60), Vector2(360, 18), 13, Color("#5a4a3a"), font_b, HORIZONTAL_ALIGNMENT_CENTER)
	# 수: 손님 값 수락 + 특수 선택지 (먹글씨 줄)
	var opts := _choices().filter(func(o): return o[0] != "관심 없소")
	var oy := py + 80.0
	for i in mini(opts.size(), 4):
		var o: Array = opts[i]
		var lone := i == opts.size() - 1 and i % 2 == 0
		_ink_line(Rect2(40 + (i % 2) * 230, oy + (i / 2) * 36, 460 if lone else 230, 34), o[0], o[1], o.size() > 2 and o[2], 16)
	# 책상 위: 가운데 인주 도장 하나(제안), 양옆 먹글씨(최종 제안 · 거절)
	var sy := H - 104.0
	_ink_line(Rect2(28, sy + 34, 150, 52), "최종 제안", func():
		sfx.play("bell")
		g.propose(g.draft, true), false, 21, true, true)
	_seal_obj(Rect2(200, sy, 140, 98), "제안", Color("#93392c"), func(): g.propose(g.draft))
	_ink_line(Rect2(362, sy + 34, 150, 52), "거절", func(): g.refuse(), false, 21, true, true)


## 먹으로 그은 −/+ 표시 (글꼴에 기대지 않고 획으로)
func _ink_mark(rect: Rect2, plus: bool, cb: Callable) -> void:
	var c := rect.get_center()
	var bars := [Rect2(c.x - 14, c.y - 2.5, 28, 5)]
	if plus:
		bars.append(Rect2(c.x - 2.5, c.y - 14, 5, 28))
	for r in bars:
		var cr := ColorRect.new()
		cr.color = INK
		cr.position = r.position
		cr.size = r.size
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dyn.add_child(cr)
	hot(rect, "올리기" if plus else "내리기", cb)


## 책상 위 펼친 한지 장부 (버튼 판이 아니라 종이 한 장)
func _page() -> void:
	var r := Rect2(20, DESK_Y + 12, 500, H - DESK_Y - (128 if g.is_haggling() and g.cur.get("stage", "") == "haggle" else 36))
	pic(_raster("page%d" % int(r.size.y), _page_svg(r.size), [0, 0, r.size.x, r.size.y]), r.position, r.size)


func _page_svg(sz: Vector2) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var w := sz.x
	var h := sz.y
	var s := '<rect x="6" y="9" width="%s" height="%s" rx="3" fill="#000" opacity="0.4" transform="rotate(-0.6)"/>' % [SvgArt.n(w - 8), SvgArt.n(h - 10)]
	s += '<rect x="2" y="2" width="%s" height="%s" rx="2" fill="#efe2c0" transform="rotate(-0.6)"/>' % [SvgArt.n(w - 6), SvgArt.n(h - 10)]
	for i in int(w * h / 900):
		var fx := rng.randf_range(6, w - 8)
		var fy := rng.randf_range(6, h - 12)
		s += '<path d="M%s,%s q%s,%s %s,%s" stroke="#a08a60" stroke-width="0.6" fill="none" opacity="0.3"/>' % [SvgArt.n(fx), SvgArt.n(fy), SvgArt.n(rng.randf_range(2, 6)), SvgArt.n(rng.randf_range(-2, 2)), SvgArt.n(rng.randf_range(6, 14)), SvgArt.n(rng.randf_range(-2, 2))]
	var y := 34.0
	while y < h - 16:
		s += '<path d="M16,%s H%s" stroke="#b8a27a" stroke-width="0.8" opacity="0.55"/>' % [SvgArt.n(y), SvgArt.n(w - 16)]
		y += 30
	s += '<path d="M14,8 V%s" stroke="#c8402e" stroke-width="1" opacity="0.45"/>' % SvgArt.n(h - 14)
	s += '<rect x="0" y="0" width="%s" height="%s" fill="none" stroke="#7a5a3a" stroke-width="1" opacity="0.5" transform="rotate(-0.6)"/>' % [SvgArt.n(w - 4), SvgArt.n(h - 8)]
	return s


## 종이에 쓴 먹글씨 한 줄. 누르면 먹 번짐이 생긴다.
func _ink_line(rect: Rect2, text: String, cb: Callable, special := false, fs := 20, center := false, on_wood := false) -> Button:
	var b := Button.new()
	b.text = ("" if center else "◦ ") + text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", font_k if center else font_b)
	b.add_theme_font_size_override("font_size", fs)
	var fg := Color("#2a3a7a") if special else INK
	if on_wood:
		fg = Color("#f1e2c0")
		b.add_theme_constant_override("outline_size", 4)
		b.add_theme_color_override("font_outline_color", Color("#1a0c06"))
	for st in ["font_color", "font_hover_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_pressed_color", SEAL)
	var empty := StyleBoxEmpty.new()
	var wash := StyleBoxFlat.new()
	wash.bg_color = Color(0.3, 0.18, 0.08, 0.14)
	wash.set_corner_radius_all(14)
	for st in ["normal", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_stylebox_override("hover", wash)
	b.add_theme_stylebox_override("pressed", wash)
	b.pressed.connect(func(): _act(cb))
	dyn.add_child(b)
	return b


## 책상 위에 세워 둔 도장 (손잡이 + 인면). 누르면 쿵 찍힌다.
func _seal_obj(rect: Rect2, text: String, c: Color, cb: Callable) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var col := "#" + c.to_html(false)
	var sv := '<ellipse cx="%s" cy="%s" rx="%s" ry="7" fill="#000" opacity="0.45"/>' % [SvgArt.n(w / 2), SvgArt.n(h - 6), SvgArt.n(w / 2 - 6)]
	sv += '<rect x="%s" y="6" width="56" height="28" rx="8" fill="#6a4226" stroke="#1a0c06" stroke-width="2.5"/>' % SvgArt.n(w / 2 - 28)
	sv += '<path d="M%s,14 h40" stroke="#d9a441" stroke-width="2" opacity="0.8"/>' % SvgArt.n(w / 2 - 20)
	sv += '<rect x="%s" y="32" width="%s" height="10" fill="#5a3420" stroke="#1a0c06" stroke-width="2.5"/>' % [SvgArt.n(w / 2 - 26), SvgArt.n(52)]
	sv += '<path d="M8,42 H%s L%s,%s H4 Z" fill="%s" stroke="#1a0c06" stroke-width="2.5"/>' % [SvgArt.n(w - 8), SvgArt.n(w - 4), SvgArt.n(h - 10), col]
	sv += '<path d="M12,46 H%s" stroke="#fff" stroke-width="2" opacity="0.25"/>' % SvgArt.n(w - 12)
	var skin := pic(_raster("sealobj", sv, [0, 0, w, h]), rect.position, rect.size)
	var b := _skinned_button(Rect2(rect.position + Vector2(0, 40), Vector2(w, h - 48)), text, cb, skin, font_k, 20, Color("#fff4dc"))
	b.add_theme_color_override("font_color", Color("#f3e2c4"))
	var top := Button.new()
	top.flat = true
	top.position = rect.position
	top.size = Vector2(w, 42)
	top.focus_mode = Control.FOCUS_NONE
	var e := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		top.add_theme_stylebox_override(st, e)
	top.button_down.connect(func(): b.button_down.emit())
	top.button_up.connect(func(): b.button_up.emit())
	top.pressed.connect(func(): _act(cb))
	dyn.add_child(top)


## 도장 모양 버튼 (인주 그림 위에 글자)
func _stamp(rect: Rect2, text: String, c: Color, cb: Callable, fs := 22) -> void:
	var skin := pic(_raster("seal", _seal_svg(rect.size, "#" + c.to_html(false), text.hash()), [0, 0, rect.size.x, rect.size.y]), rect.position, rect.size)
	var b := _skinned_button(rect, text, cb, skin, font_k, fs, Color("#fff4dc"))
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))


## 책상에 기대 세운 나무 영업패. 끈으로 매단 패에 글자를 새긴 모양.
func _plaque(rect: Rect2, text: String, hint: String, cb: Callable, raw := false) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var sv := '<path d="M%s,4 L%s,34 M%s,4 L%s,34" stroke="#c8a060" stroke-width="3"/><circle cx="%s" cy="4" r="5" fill="#c9963a" stroke="#1a0c06" stroke-width="2"/>' % [SvgArt.n(w / 2), SvgArt.n(w * 0.2), SvgArt.n(w / 2), SvgArt.n(w * 0.8), SvgArt.n(w / 2)]
	sv += '<path d="M10,%s Q%s,%s %s,%s L%s,%s Q%s,%s 10,%s Z" fill="#000" opacity="0.4" transform="translate(4,6)"/>' % [SvgArt.n(34), SvgArt.n(w / 2), SvgArt.n(26), SvgArt.n(w - 10), SvgArt.n(34), SvgArt.n(w - 10), SvgArt.n(h - 30), SvgArt.n(w / 2), SvgArt.n(h - 22), SvgArt.n(h - 30)]
	sv += '<path d="M10,%s Q%s,%s %s,%s L%s,%s Q%s,%s 10,%s Z" fill="#8a5a32" stroke="#1a0c06" stroke-width="3"/>' % [SvgArt.n(34), SvgArt.n(w / 2), SvgArt.n(26), SvgArt.n(w - 10), SvgArt.n(34), SvgArt.n(w - 10), SvgArt.n(h - 30), SvgArt.n(w / 2), SvgArt.n(h - 22), SvgArt.n(h - 30)]
	for i in 5:
		sv += '<path d="M20,%d c60,-5 %s,5 %s,0" stroke="#000" stroke-width="1" fill="none" opacity="0.2"/>' % [48 + i * 16, SvgArt.n(w * 0.5), SvgArt.n(w - 40)]
	sv += '<rect x="24" y="44" width="%s" height="%s" rx="3" fill="none" stroke="#3a1e0c" stroke-width="2" opacity="0.6"/>' % [SvgArt.n(w - 48), SvgArt.n(h - 84)]
	var skin := pic(_raster("plaque", sv, [0, 0, w, h]), rect.position, rect.size)
	var b := _skinned_button(Rect2(rect.position + Vector2(0, 30), Vector2(w, h - 60)), text, cb, skin, font_k, 38, Color("#2a1408"), raw)
	b.add_theme_constant_override("outline_size", 2)
	b.add_theme_color_override("font_outline_color", Color("#c08a50"))
	lbl(hint, Vector2(rect.position.x - 40, rect.end.y + 4), Vector2(w + 80, 22), 14, Color("#e8d0a8"), font_b, HORIZONTAL_ALIGNMENT_CENTER)


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
	_plaque(Rect2(120, DESK_Y + 120, 300, 150), "閉 · 닫힘", "패를 뒤집어 문을 엽니다", func(): g.flip_open())


## 아침 방문(榜文): 「은하 일보」. 시세·경매·구인·팁을 붙인 종이 쪽지.
func _render_newspaper() -> void:
	var n := g.news
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", _tex_box("hanji", Color("#f3e6c6"), 20))
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
		var nb := StyleBoxFlat.new()
		nb.bg_color = Color(0, 0, 0, 0)
		nb.border_width_bottom = 1
		nb.border_width_top = 1
		nb.border_color = Color(0.16, 0.1, 0.06, 0.35)
		nb.set_content_margin_all(6)
		var nh := nb.duplicate()
		nh.bg_color = Color(0.4, 0.25, 0.1, 0.12)
		b.add_theme_stylebox_override("normal", nb)
		b.add_theme_stylebox_override("hover", nh)
		b.add_theme_stylebox_override("pressed", nh)
		if ad:
			var mark := Label.new()
			mark.text = "印"
			mark.add_theme_font_override("font", font_k)
			mark.add_theme_font_size_override("font_size", 13)
			mark.add_theme_color_override("font_color", SEAL)
			mark.position = Vector2(4, 2)
			mark.rotation_degrees = -8
			b.add_child(mark)
		var cb: Callable = it[2]
		b.pressed.connect(func():
			cb.call()
			g.save_game()
			_flush_toasts())
		grid.add_child(b)


func _render_night() -> void:
	lbl("오늘 장사는 여기까지", Vector2(40, 300), Vector2(460, 60), 30, HANJI, font_k, HORIZONTAL_ALIGNMENT_CENTER)
	_plaque(Rect2(120, DESK_Y + 110, 300, 150), "마감", "패를 눌러 오늘 장부를 셈합니다", func(): show_receipt(), true)


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
	_schedule_next()


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
	panel.add_theme_stylebox_override("panel", _tex_box("lacquer" if dark else "hanji", Color.WHITE if dark else HANJI.lerp(bgc, 0.35), 22))
	panel.position = Vector2((vs.x - ww) / 2, 14)
	panel.size = Vector2(ww, vs.y - 28)
	modal.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var v := VBoxContainer.new()
	# 내용 높이에 맞춰 판을 줄이고 화면 가운데에 둔다(빈 공간 제거)
	v.resized.connect(func():
		var want := minf(v.size.y + 48, vs.y - 28)
		panel.size = Vector2(ww, want)
		panel.position = Vector2((vs.x - ww) / 2, (vs.y - want) / 2))
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


## 9분할 텍스처 판: hanji(한지) · lacquer(옻칠+금테)
func _tex_box(kind: String, tint := Color.WHITE, pad := 16) -> StyleBoxTexture:
	var k := "box_" + kind
	var tex: Texture2D
	if _cache.has(k):
		tex = _cache[k]
	else:
		var body := ""
		if kind == "lacquer":
			body = '<rect x="3" y="3" width="154" height="154" rx="5" fill="#2b1d1f" stroke="#120a08" stroke-width="3"/>'
			body += '<rect x="3" y="3" width="154" height="154" rx="5" fill="url(#g)" opacity="0.5"/>'
			body += '<rect x="10" y="10" width="140" height="140" rx="3" fill="none" stroke="#c9963a" stroke-width="3"/>'
			body += '<rect x="15" y="15" width="130" height="130" rx="2" fill="none" stroke="#c9963a" stroke-width="1" opacity="0.7"/>'
			for c in [[10, 10, 1, 1], [150, 10, -1, 1], [10, 150, 1, -1], [150, 150, -1, -1]]:
				body += '<path d="M%d,%d l%d,0 l0,%d l%d,0 l0,%d Z" fill="#d9a441"/>' % [c[0], c[1], 12 * c[2], 4 * c[3], -8 * c[2], 8 * c[3]]
			body = '<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6a2a2a"/><stop offset="1" stop-color="#000"/></linearGradient></defs>' + body
		else:
			body = _slip_svg(Vector2(160, 160), "#ffffff", 11)
		tex = SvgArt.rasterize(body, [0, 0, 160, 160], 1.0)
		_cache[k] = tex
	var b := StyleBoxTexture.new()
	b.texture = tex
	b.set_texture_margin_all(24)
	if kind == "hanji":
		b.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		b.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	b.set_content_margin_all(pad)
	b.modulate_color = tint
	return b


## 나무판 버튼: 색은 bg, 결무늬와 먹선 테두리
func _plank_box(bg: Color, shade := Color.WHITE) -> StyleBoxTexture:
	var k := "plank_" + bg.to_html(false)
	var tex: Texture2D
	if _cache.has(k):
		tex = _cache[k]
	else:
		var body := '<rect x="1" y="4" width="118" height="44" rx="4" fill="#000" opacity="0.35"/>'
		body += '<rect x="1" y="1" width="118" height="44" rx="4" fill="#%s" stroke="#1a0e08" stroke-width="2.5"/>' % bg.to_html(false)
		for i in 4:
			var yy := 9 + i * 9
			body += '<path d="M6,%d C40,%d 80,%d 114,%d" stroke="#000" stroke-width="1" fill="none" opacity="0.14"/>' % [yy, yy - 3 + i % 2 * 5, yy + 3, yy]
		body += '<rect x="5" y="5" width="110" height="36" rx="2" fill="none" stroke="#fff" stroke-width="1" opacity="0.18"/>'
		tex = SvgArt.rasterize(body, [0, 0, 120, 50], 1.0)
		_cache[k] = tex
	var b := StyleBoxTexture.new()
	b.texture = tex
	b.texture_margin_left = 14
	b.texture_margin_right = 14
	b.texture_margin_top = 12
	b.texture_margin_bottom = 14
	b.set_content_margin_all(8)
	b.modulate_color = shade
	return b


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
	# 종이 위 먹글씨(밝은 판) / 옻칠 위 금글씨(어두운 판). 상자 없이 밑줄만.
	var ink: Color = parent.get_meta("ink") if parent.has_meta("ink") else INK
	var dark_sheet := ink.get_luminance() > 0.5
	var col: Color
	if dark_sheet:
		col = Color("#f0c870") if bg.get_luminance() < 0.6 else bg
	else:
		col = bg.darkened(0.15) if bg.get_luminance() < 0.55 and bg.get_luminance() > 0.08 else INK
		if bg.get_luminance() >= 0.55:
			col = Color("#7a5a1a")
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", font_k)
	b.add_theme_font_size_override("font_size", 17)
	for st in ["font_color", "font_hover_color"]:
		b.add_theme_color_override(st, col)
	b.add_theme_color_override("font_pressed_color", SEAL if not dark_sheet else Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(col, 0.35))
	var under := StyleBoxFlat.new()
	under.bg_color = Color(0, 0, 0, 0)
	under.border_width_bottom = 2
	under.border_color = Color(col, 0.55)
	under.set_content_margin_all(6)
	var wash := under.duplicate()
	wash.bg_color = Color(col, 0.12)
	wash.set_corner_radius_all(10)
	var off := under.duplicate()
	off.border_color = Color(col, 0.15)
	b.add_theme_stylebox_override("normal", under)
	b.add_theme_stylebox_override("hover", wash)
	b.add_theme_stylebox_override("pressed", wash)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
	var art: Texture2D = _char_tex("s_" + key.trim_prefix("staff_").trim_suffix("h"), mood) if key.begins_with("staff_") else null
	pic.texture = art if art != null else _raster(key, SvgArt.draw_char(SvgArt.look(L), mood), [-80, -100, 160, 175])
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
		var npc_art := _char_tex(String(b.get("art", "")), "happy" if lead else "ok")
		if npc_art != null:
			var np := TextureRect.new()
			np.texture = npc_art
			np.custom_minimum_size = Vector2(90, 120)
			np.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			np.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cv.add_child(np)
		else:
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
