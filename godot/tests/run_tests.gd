extends SceneTree
## 헤드리스 테스트 러너.
## 실행: godot --headless --path godot -s res://tests/run_tests.gd
## 실패가 하나라도 있으면 종료 코드 1 (CI에서 빌드를 막는다).

const Negotiation := preload("res://scripts/core/negotiation.gd")
const GameDataScript := preload("res://scripts/core/game_data.gd")
const GameState := preload("res://scripts/core/game_state.gd")
const Bots := preload("res://tests/bots.gd")

var data

var passed := 0
var failed := 0


func _init() -> void:
	data = GameDataScript.new()
	for scr in [GameState, Bots, Negotiation, load("res://scripts/ui/svg_art.gd"), load("res://scripts/ui/item_art.gd"), load("res://scripts/ui/shop_screen.gd"), load("res://scripts/ui/sfx.gd")]:
		if not scr.can_instantiate():
			print("✗ 스크립트 컴파일 실패: ", scr.resource_path)
			quit(1)
			return
	test_data_files()
	test_offer_at_ask_deals()
	test_seller_never_below_min()
	test_buyer_never_above_max()
	test_lowball_eventually_leaves()
	test_proud_leaves_on_insult()
	test_final_offer()
	test_repeat_offer_costs_patience()
	test_day_cycle()
	test_estimate_contains_value()
	test_save_roundtrip()
	test_regular_remembers()
	test_flow_and_queue()
	test_debt_liquidation()
	test_pawn()
	test_specials()
	test_stats_and_collection()
	test_all_events()
	test_event_effects()
	test_later()
	test_goal()
	test_belongings_regressions()
	test_large_customer_day()
	test_trips()
	test_sim_random()
	test_sim_smart()
	data.free()
	# 화면 테스트는 씬 트리가 돌기 시작한 뒤(_process)에 실행한다


var _frames := 0
var _main = null


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
	elif _frames == 3:
		test_ui_smoke()
		print("\n결과: %d 통과, %d 실패" % [passed, failed])
		quit(1 if failed > 0 else 0)
	return false


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  ✓ ", name)
	else:
		failed += 1
		print("  ✗ 실패: ", name)


func make(seed_value: int) -> Negotiation:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Negotiation.new(rng)


func test_data_files() -> void:
	print("[데이터]")
	var gd = GameDataScript.new()
	var cats: Dictionary = gd.items.get("categories", {})
	var n_items := 0
	for k in cats:
		n_items += cats[k]["items"].size()
	check(cats.size() >= 10, "카테고리 10개 이상 (%d)" % cats.size())
	check(n_items >= 80, "물건 80종 이상 (%d)" % n_items)
	check(gd.shops.size() == 5, "가게 5단계")
	check(gd.specials.size() == 8, "단골 8명")
	check(gd.traits.get("traits", {}).size() == 12, "성향 12종")
	gd.free()


func test_offer_at_ask_deals() -> void:
	print("[요구가 이상 제시 → 즉시 거래]")
	var n := make(1)
	n.setup_seller(1000, [])
	check(n.propose(n.ask) == Negotiation.Result.DEAL, "판매 손님: 요구가 그대로 제시하면 거래")
	var b := make(2)
	b.setup_buyer(1000, 0, [])
	check(b.propose(b.offer) == Negotiation.Result.DEAL, "구매 손님: 제시가 그대로 부르면 거래")


func test_seller_never_below_min() -> void:
	print("[속성: 판매 손님은 마지노선 아래로 절대 안 판다]")
	var ok := true
	var deals := 0
	var all_traits := ["greedy", "naive", "hasty", "calm", "expert", "proud", "desperate", "scammer", "chatty"]
	for s in 3000:
		var n := make(s)
		var tr := [all_traits[s % all_traits.size()]] if s % 3 else []
		n.setup_seller(200 + (s % 50) * 137, tr, s % 6, s % 6)
		var floor_price := n.min_price
		var x := int(n.ask * n.rng.randf_range(0.2, 0.7))
		for i in 30:
			var r := n.propose(x, n.rng.randf() < 0.05)
			if r == Negotiation.Result.DEAL:
				deals += 1
				if n.deal_price < floor_price:
					ok = false
				break
			if r == Negotiation.Result.LEAVE_ANGRY:
				break
			check_ask_floor(n, floor_price)
			x = int(x + (n.ask - x) * n.rng.randf_range(0.1, 0.6)) + 10
	check(ok, "3000회 흥정 중 마지노선 이하 거래 0건")
	check(deals > 300, "거래도 충분히 성사됨 (%d건)" % deals)


var _floor_ok := true
func check_ask_floor(n: Negotiation, floor_price: int) -> void:
	if n.ask < floor_price and _floor_ok:
		_floor_ok = false
		check(false, "요구가가 마지노선 아래로 내려감")


func test_buyer_never_above_max() -> void:
	print("[속성: 구매 손님은 최대 지불액 위로 절대 안 산다]")
	var ok := true
	var deals := 0
	for s in 3000:
		var n := make(10000 + s)
		var tr := [["rich", "stingy", "collector", "naive", "expert", "proud", "hasty", "calm"][s % 8]]
		n.setup_buyer(150 + (s % 40) * 211, s % 4, tr, s % 6, s % 6)
		var ceiling := n.max_price
		var y := int(n.offer * n.rng.randf_range(1.4, 3.0))
		for i in 30:
			var r := n.propose(y, n.rng.randf() < 0.05)
			if r == Negotiation.Result.DEAL:
				deals += 1
				if n.deal_price > ceiling:
					ok = false
				break
			if r == Negotiation.Result.LEAVE_ANGRY:
				break
			if n.offer > ceiling:
				ok = false
			y = maxi(n.offer, int(y - (y - n.offer) * n.rng.randf_range(0.1, 0.6)) - 10)
	check(ok, "3000회 흥정 중 최대 지불액 초과 거래 0건")
	check(deals > 300, "거래도 충분히 성사됨 (%d건)" % deals)


func test_lowball_eventually_leaves() -> void:
	print("[헐값만 부르면 결국 떠난다]")
	var n := make(7)
	n.setup_seller(2000, ["calm"])
	var r := Negotiation.Result.CONTINUE
	var x := 100
	var steps := 0
	while r == Negotiation.Result.CONTINUE and steps < 50:
		r = n.propose(x)
		x += 10
		steps += 1
	check(r == Negotiation.Result.LEAVE_ANGRY, "느긋한 손님도 결국 화내고 떠남 (%d번째)" % steps)
	var h := make(8)
	h.setup_seller(2000, ["hasty"])
	var hs := 0
	r = Negotiation.Result.CONTINUE
	x = 100
	while r == Negotiation.Result.CONTINUE and hs < 50:
		r = h.propose(x)
		x += 10
		hs += 1
	check(hs < steps, "성급한 손님이 더 빨리 떠남 (%d < %d)" % [hs, steps])


func test_proud_leaves_on_insult() -> void:
	print("[자존심 손님]")
	var n := make(3)
	n.setup_seller(1000, ["proud"])
	check(n.propose(int(n.min_price * 0.3)) == Negotiation.Result.LEAVE_ANGRY and n.line == "insulted", "마지노선 45% 미만 제시 → 즉시 퇴장")


func test_final_offer() -> void:
	print("[최종 제안]")
	var n := make(4)
	n.setup_seller(1000, [])
	check(n.propose(n.min_price, true) == Negotiation.Result.DEAL, "마지노선 이상 최종 제안 → 거래")
	var m := make(5)
	m.setup_seller(1000, [])
	check(m.propose(m.min_price - 10, true) == Negotiation.Result.LEAVE_ANGRY, "마지노선 미만 최종 제안 → 퇴장")


func test_repeat_offer_costs_patience() -> void:
	print("[같은 가격 반복]")
	var n := make(6)
	n.setup_seller(5000, ["calm"])
	var x := int(n.min_price * 0.5)
	n.propose(x)
	var before := n.patience
	n.propose(x)
	check(n.line == "repeat" and n.patience <= before - 15, "같은 가격 반복 시 인내심 15 이상 감소")


func new_game(seed_value: int):
	var g = GameState.new(data, seed_value)
	g.start_day()
	return g


func test_day_cycle() -> void:
	print("[하루 흐름]")
	var g = new_game(11)
	check(g.phase == "morning" and not g.news.is_empty(), "아침: 신문 생성")
	g.event = ""
	g.flip_open()
	check(g.phase == "open" and not g.cur.is_empty(), "문 열면 첫 손님 등장")
	var first_queue: int = g.queue
	g.refuse()
	check(g.cur["gone"], "거절하면 손님이 떠남")
	g.next_customer()
	check(g.queue == first_queue - 1, "다음 손님 호출 시 대기열 감소")
	while g.phase == "open":
		if not g.cur["gone"]:
			g.refuse()
		g.next_customer()
	check(g.phase == "night" and not g.receipt.is_empty(), "손님이 다 가면 마감 영수증")
	var before: int = g.money
	check(g.receipt["d"] == -int(g.shop_info()["rent"]), "거래 없는 날 현금 변화 = -임대료")
	check(g.next_day() and g.day == 2 and g.phase == "morning", "다음 날 아침으로")


func test_estimate_contains_value() -> void:
	print("[감정: 실제 가치는 항상 추정 범위 안]")
	var g = new_game(12)
	var ok := true
	for i in 2000:
		var it: Dictionary = g.gen_item(0.2)
		var e: Array = g.est(it)
		var v: float = g.val(it, true)
		if v < e[0] - 10 or v > e[1] + 10:
			ok = false
	check(ok, "2000개 물건 모두 추정 범위 안 (반올림 오차 10냥 허용)")


func test_save_roundtrip() -> void:
	print("[저장/불러오기]")
	var g = new_game(13)
	g.event = ""
	g.flip_open()
	g.propose(int(g.their_price() * 0.5))
	var a := JSON.stringify(g.to_dict())
	var h = GameState.new(data, 99)
	h.from_dict(JSON.parse_string(a))
	var b := JSON.stringify(h.to_dict())
	check(JSON.parse_string(a) == JSON.parse_string(b), "저장 → 불러오기 → 저장 결과 동일")
	check(h.is_haggling() == g.is_haggling() and h.their_price() == g.their_price(), "흥정 중 상태도 복원")
	var path := "user://test_save.json"
	check(g.save_game(path) and h.load_game(path) and h.money == g.money, "파일 저장/불러오기")


func test_regular_remembers() -> void:
	print("[단골이 지난 거래를 기억]")
	var g = new_game(14)
	g.rel["pierre"] = {"visits": 1, "last": "angry"}
	var seen := false
	for i in 400:
		g.today["sp"] = []
		var c: Dictionary = g.gen_customer()
		if c.get("sk", "") == "pierre":
			seen = String(c["msg"]).begins_with(String(data.specials["pierre"]["cb"]["angry"]))
			break
	check(seen, "화내고 떠났던 단골이 그 일을 언급하며 재방문")


func test_sim_random() -> void:
	print("[자동 플레이: 무작위 봇 5명 × 30일]")
	var errs: Array = []
	var days := 0
	for s in 5:
		var g = new_game(100 + s)
		var bot = Bots.new(g, "random", 200 + s)
		for d in 30:
			days += 1
			if not bot.play_day():
				break
		errs.append_array(bot.errors)
	check(errs.is_empty(), "규칙 위반 0건 (%d일 진행)%s" % [days, "" if errs.is_empty() else " — " + str(errs.slice(0, 3))])


func test_sim_smart() -> void:
	print("[자동 플레이: 숙련 봇 8명 × 30일 — 밸런스]")
	var worths: Array = []
	var bankrupt := 0
	var errs: Array = []
	var shops: Array = []
	for s in 8:
		var g = new_game(300 + s)
		var bot = Bots.new(g, "smart", 400 + s)
		var alive := true
		for d in 30:
			if not bot.play_day():
				alive = false
				break
		if not alive:
			bankrupt += 1
		worths.append(int(bot.net_worth()))
		shops.append(g.shop)
		errs.append_array(bot.errors)
	worths.sort()
	var moved := shops.filter(func(x): return x >= 1).size()
	print("    30일 후 순자산(현금+재고 절반+가게 투자): ", worths, " · 가게 단계: ", shops)
	check(errs.is_empty(), "규칙 위반 0건")
	check(bankrupt == 0, "숙련 플레이는 파산하지 않음 (파산 %d)" % bankrupt)
	check(worths[worths.size() / 2] > 5000, "숙련 플레이 중앙값 순자산이 시작 자금(5,000냥)보다 큼")
	check(moved >= 4, "숙련 플레이 절반 이상이 30일 안에 첫 가게 이전 (%d/8)" % moved)


func test_goal() -> void:
	print("[목표: 가게 확장 단계 → 이전, 살림 사고 되팔기]")
	var g := GameState.new(data)
	g.start_day()
	check(not FileAccess.file_exists("res://data/story.json"), "이야기 장면 없음")
	var gl: Dictionary = g.goal()
	check(gl.get("kind", "") == "up" and gl["step"] == 1 and gl["of"] == 3, "첫 목표는 가게 확장 1/3단계")
	g.money = 100000
	check(not g.can_move(), "확장을 다 안 하면 이전 불가")
	var c0 := g.cap()
	var q0 := g.cust_base()
	var r0 := g.rep
	g.expand(); g.expand(); g.expand()
	check(g.cap() == c0 + 3 and g.cust_base() == q0 + 1 and g.rep == r0 + 10, "확장 효과: 창고 +3, 손님 +1, 평판 +10")
	check(g.goal()["kind"] == "move" and g.can_move(), "확장을 마치면 다음 목표는 이전")
	g.move_shop()
	check(g.shop == 1 and g.shop_up == 0 and g.goal()["kind"] == "up", "이전하면 새 가게의 확장이 다시 시작")
	g.shop = data.shops.size() - 1
	g.shop_up = 3
	check(g.goal().is_empty(), "마지막 가게까지 다 키우면 목표 없음(흥정왕)")
	g.shop = 0
	g.shop_up = 0
	# 살림
	g.money = 100000
	var ch0 := g.charm_lv()
	check(not g.buy_belong("observatory"), "좋은 집이 없으면 비싼 창밖 풍경은 못 삼")
	check(g.buy_belong("canal") and g.home == "canal" and g.charm_lv() == ch0 + 1, "수로변 기와집: 집 2단계 → 화술 +1")
	var m0 := g.money
	check(g.buy_belong("garden") and g.money == m0 - 90000 + g.resale("canal"), "새 집을 사면 옛 집은 되팔림")
	check(g.buy_belong("farm") and g.view == "farm", "창밖 풍경을 사면 바로 걸림")
	g.money += 20000
	g.buy_belong("bike")
	check(g.best_lv("ride") == 2, "탈것 단계")
	var m1 := g.money
	var got := g.sell_belong("bike")
	check(got == g.resale("bike") and g.money == m1 + got and not g.owns("bike"), "급전: 탈것을 70%에 되팔기")
	got = g.sell_belong("garden")
	check(got > 0 and g.home == "backroom" and g.view == "unkyeong", "집을 팔면 뒷방으로, 높은 풍경은 내려감")
	check(g.sell_belong("backroom") == 0, "뒷방은 팔 수 없음")
	var h := GameState.new(data)
	h.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(h.owned == g.owned and h.home == g.home and h.shop_up == g.shop_up, "살림·확장 저장")

func test_belongings_regressions() -> void:
	print("[살림 거래·마감 회복 회귀]")
	var g = new_game(930)
	check(g.resale("backroom") == 0 and g.resale("missing") == 0, "무료·없는 살림의 되팔기 값은 0냥")
	var before: int = g.money
	g.buy_belong("alley")
	check(g.money == before - 2500, "무료 뒷방 교환으로 돈이 생기지 않음")
	g.money = 100000
	g.buy_belong("canal")
	g.buy_belong("farm")
	g.buy_belong("alley")
	check(g.view == "unkyeong" and g.owns("farm") and not g.set_view("farm"), "집 단계가 내려가면 풍경만 기본으로, 소유권 유지")
	check(int(g.today.get("assets_bought", 0)) == 26000 and int(g.today.get("assets_sold", 0)) == 14350, "집 교환의 구입·되팔기 금액을 분리 기록")
	g.buy_belong("cart")
	g.close_shop()
	g.money = g.bankrupt_line() - 500
	var day_before: int = g.day
	check(not g.next_day() and g.day == day_before, "파산선 아래에서는 다음 날로 진행하지 않음")
	g.sell_belong("cart")
	check(not g.is_bankrupt() and g.next_day() and g.day == day_before + 1, "밤에 살림을 팔아 파산선 회복 후 다음 날 진행")
	check(int(g.history[-1].get("assets_sold", 0)) == 15400, "마감 뒤 살림 되팔기도 그날 기록에 포함")
	var h = new_game(931)
	h.money = 100000
	h.shop_up = 3
	var fees: int = int(h.today.get("fees", 0))
	h.move_shop()
	check(int(h.today.get("fees", 0)) == fees + 6000, "가게 이전 비용도 장부에 기록")
	var missing: Array = []
	for cat in ["home", "ride", "ship"]:
		for b in data.belong[cat]:
			if not ResourceLoader.exists("res://assets/belong/%s.png" % b["id"]):
				missing.append(b["id"])
	check(missing.is_empty(), "집·탈것·우주선 14종 모두 실제 그림 존재 %s" % str(missing))


func test_trips() -> void:
	print("[가게 준비: 운경 장소별 기능]")
	var g := GameState.new(data)
	g.start_day()
	g.money = 50000
	check(g.visit("market") != "" and g.journal.has("market") and g.visit("market") == "", "처음 간 곳만 견문록에 적음")
	var lst := g.stall("market")
	check(lst.size() == 4 and g.stall("market") == lst, "월류시장 오늘 매물 4개(하루 동안 같음)")
	var n := g.inv.size()
	check(g.stall_buy("market", 0) and g.inv.size() == n + 1 and g.stall("market").size() == 3, "매물 사기")
	check(g.stall("port").size() == 3, "천문항 매물 3개")
	var c0 := g.cap()
	check(g.equip_up("shelf") and g.cap() == c0 + 2, "옥맥공방: 진열장 강화로 창고 +2")
	var a0 := g.app_lv()
	g.equip_up("lens")
	check(g.app_lv() == a0 + 1, "감정 렌즈 강화로 감정 실력 +1")
	g.equip_up("censer")
	check(g.charm_lv() == int(g.skills["charm"]) + 1, "청동 향로로 화술 +1")
	g.inv[0]["c"] = 0
	check(g.repair_now(g.inv[0]["id"]) and int(g.inv[0]["c"]) == 1, "옥맥공방 즉시 수리")
	check(g.forecast().contains("귀해진") and g.forecast() == "", "설운관 관측은 하루 한 번")
	var b0 := int(g.today.get("bonus", 0))
	check(g.promote() and int(g.today["bonus"]) == b0 + 2 and not g.promote(), "청경농원 홍보: 오늘 손님 +2, 하루 한 번")
	g.phase = "open"
	check(not g.equip_up("lens") and not g.stall_buy("market", 0), "영업 중엔 가게 준비 불가")
	var all_ok := true
	for k in data.trips:
		var tp: Dictionary = data.trips[k]
		all_ok = all_ok and ResourceLoader.exists("res://assets/places/%s.jpg" % tp["img"])
		for bad in ["조선", "한양", "결계", "청룡항", "황룡성"]:
			all_ok = all_ok and not String(tp["d"]).contains(bad)
	check(all_ok and data.trips.size() == 6, "장소 6곳 모두 컨셉 아트 배경")


func test_later() -> void:
	print("[나중에: 손님을 줄 뒤로]")
	var g := GameState.new(data)
	g.start_day()
	g.event = ""
	g.flip_open()
	if g.cur.get("visitor", false):
		g.visit_pick(0)
		g.open_shop()
	var nm: String = g.cur["name"]
	var price: int = g.their_price()
	var before: Array = g.remaining()
	g.defer()
	check(g.cur["gone"] and g.later.size() == 1, "나중에 → 손님이 줄 뒤로")
	var after: Array = g.remaining()
	check(after[0] + after[1] == before[0] + before[1] + 1, "남은 손님 수에 미룬 손님 포함")
	g.next_customer()
	var guard := 0
	while g.phase == "open" and not g.cur.get("deferred", false) and guard < 60:
		guard += 1
		if not g.cur.get("gone", false):
			g.refuse()
		g.next_customer()
	check(g.cur.get("name", "") == nm and g.cur["stage"] == "intro" and not g.cur["gone"] and g.later.is_empty(), "마감 전에 같은 손님이 다시 옴")
	check(g.their_price() == price, "다시 와도 같은 값")
	g.defer()
	check(not g.cur["gone"], "나중에는 한 번만")


func test_ui_smoke() -> void:
	print("[화면: 세로 메인 장면·흐름·오버레이]")
	var main = _main
	var ok: bool = ("g" in main) and main.g != null and main.stage != null
	check(ok, "메인 장면 생성 (화면 스크립트 컴파일 포함)")
	if not ok:
		return
	var g = main.g
	check(g.phase == "morning" and main.dyn.get_child_count() > 10, "아침: 신문과 열기 팻말 표시")
	g.event = "peddler"
	main._act(func(): g.flip_open())
	check(g.phase == "visit" and main.cust_tex.visible and main.cust_tex.texture != null, "방문객이 화면에 그려짐")
	main._act(func(): g.visit_pick(1))
	g.phase = "morning"
	g.cur = {}
	main.render()
	g.event = ""
	main._act(func(): g.flip_open())
	if g.cur.get("visitor", false) or g.cur["gone"]:
		g.cur = {}
		g.queue += 1
		g.next_customer()
		main._act(func(): pass)
	check(g.phase == "open" and g.cur["stage"] == "intro" and String(g.cur["msg"]).contains("냥"), "손님이 들어오자마자 물건과 값을 내밂")
	var labels: Array = main._choices().map(func(o): return o[0])
	check(labels == ["거래합시다", "필요 없소", "나중에 오시오"], "거래합시다 / 필요 없소 / 나중에 선택지 %s" % str(labels))
	var r0: Array = g.remaining()
	check(r0[0] + r0[1] == g.queue, "남은 손님(사러+팔러) = 줄 길이")
	main._choices()[0][1].call()
	main.render()
	check(String(g.cur["msg"]).contains("냥"), "첫 말풍선에 부른 값이 있음")
	main.show_inspect(g.cur_item())
	check(main.modal.visible, "계산대 물건 누르면 살펴보기 창")
	main.close_modal()
	main.render()
	check(g.cur["stage"] == "haggle", "흥정 진행 중")
	var labels2: Array = []
	for c in main.dyn.get_children():
		if c is Button and not c.is_queued_for_deletion():
			labels2.append(c.text)
	check(labels2.any(func(x): return String(x).ends_with("제안하기")) and labels2.has("거래 거절") and not labels2.has("최종 제안"), "흥정 패널: 제안하기 + 거래 거절 + 수락 (최종 제안 버튼 없음) %s" % str(labels2))
	var before: int = g.neg.rounds
	g.draft = int(g.their_price() * 0.7)
	g.propose(g.draft)
	check(g.neg.rounds == before + 1 or g.cur["gone"], "가격표 ✓로 제안 반영")
	g.cur["gone"] = true
	var nm: String = g.cur["name"]
	main._act(func(): pass)
	check(main._auto_tw != null, "손님이 떠나면 다음 손님 자동 예약")
	var opened := true
	for f in ["show_menu", "show_inv", "show_staff", "show_ledger", "show_traits", "show_keypad"]:
		main.call(f)
		opened = opened and main.modal.visible
		main.close_modal()
	check(opened, "창고·직원·장부·성향·키패드 화면이 열림")
	for f in ["show_collection"]:
		main.call(f)
		opened = opened and main.modal.visible
		main.close_modal()
	main.show_stats("week")
	check(opened and main.modal.visible, "도감·통계 화면이 열림")
	main.close_modal()
	check(main.sfx != null and main.sfx.bank.size() == 6, "효과음 6종 합성")
	var missing: Array = []
	for ck in main.D.items["categories"]:
		for it in main.D.items["categories"][ck]["items"]:
			if not ItemArt.MAP.has(it[1]):
				missing.append(it[1])
	check(missing.is_empty(), "모든 물건에 그림 아이콘이 있음 %s" % str(missing))
	var no_art: Array = []
	for a in main.D.archetypes.filter(func(x): return not x.get("needs_art", false)):
		for md in ["ok", "happy", "angry", "meh"]:
			if main._char_tex(a["id"], md) == null or not ResourceLoader.exists("res://assets/chars/%s_%s.png" % [a["id"], md]):
				no_art.append("%s_%s" % [a["id"], md])
	for k in main.D.specials:
		if main._char_tex(main._char_key({"sk": k}), "angry") == null:
			no_art.append(k)
	for k in main.D.events:
		if main._char_tex(main._char_key({"visitor": true, "vk": k}), "ok") == null:
			no_art.append("v_" + k)
	for k in main.D.staff:
		if main._char_tex("s_" + k, "ok") == null:
			no_art.append("s_" + k)
	check(no_art.is_empty(), "손님·단골·불청객·직원 모두 손그림 있음 %s" % str(no_art))
	test_night_recovery_ui()
	check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) < int(ProjectSettings.get_setting("display/window/size/viewport_height")) and int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 1, "세로 화면 설정")


func test_flow_and_queue() -> void:
	print("[원작 흐름: 인사 → 살펴보기 → 흥정, 대기 줄]")
	var g = new_game(21)
	g.event = ""
	g.flip_open()
	check(g.cur["stage"] == "intro" and not String(g.cur["msg"]).contains("냥"), "첫 대사는 인사(가격 없음)")
	check(g.upcoming.size() == mini(2, g.queue), "대기 줄에 다음 손님 %d명" % g.upcoming.size())
	var next_name: String = g.upcoming[0]["name"] if g.upcoming.size() > 0 else ""
	g.look_item()
	check(g.cur["stage"] == "look", "살펴보기 단계")
	g.start_haggle()
	check(g.cur["stage"] == "haggle" and String(g.cur["msg"]).contains("냥"), "흥정 시작 시 가격 제시")
	g.refuse()
	g.next_customer()
	check(next_name == "" or g.cur["name"] == next_name, "대기 줄 맨 앞 손님이 다음으로 들어옴")


func test_debt_liquidation() -> void:
	print("[빚이 생기면 재고로 메움]")
	var g = new_game(22)
	g.event = ""
	g.flip_open()
	for i in 4:
		var it: Dictionary = g.gen_item(0.0)
		it["paid"] = 100
		g.inv.append(it)
	g.money = -500
	g.queue = 0
	g.cur["gone"] = true
	g.next_customer()
	check(g.phase == "night" and (g.money >= 0 or g.inv.is_empty()), "마감 때 재고 처분으로 빚 상환 (현금 %s, 남은 재고 %d)" % [g.fmt(g.money), g.inv.size()])


func test_pawn() -> void:
	print("[전당포: 맡기기 → 상환 또는 몰수]")
	var redeemed := 0
	var forfeited := 0
	var blocked := true
	for s in 40:
		var g = new_game(500 + s)
		g.event = ""
		g.flip_open()
		var guard := 0
		while not g.cur.get("pawn", false) and guard < 200:
			guard += 1
			g.queue = 5
			g.cur["gone"] = true
			g.next_customer()
		if not g.cur.get("pawn", false):
			continue
		var it: Dictionary = g.cur["item"]
		var loan: int = g.neg.ask
		g.accept()
		if not g.is_pawned(it):
			continue  # 돈이 부족하거나 창고가 차서 대출 불가 — 이 경우는 건너뜀
		blocked = blocked and not g.dump(it["id"])
		var start_money: int = g.money
		var due: int = it["pawn"]["due"]
		var repay: int = it["pawn"]["repay"]
		for d in 10:
			g.queue = 0
			if g.phase == "open":
				g.cur["gone"] = true
				g.next_customer()
			if g.find_item(it["id"]).is_empty():
				redeemed += 1
				break
			if not g.is_pawned(it):
				forfeited += 1
				if g.day != due + 1:
					check(false, "기한 다음 날 마감 때 몰수 (%d일차 기한, %d일차 몰수)" % [due, g.day])
				break
			g.next_day()
			g.event = ""
			g.flip_open()
		check(repay > loan, "상환액이 대출금보다 큼 (%s → %s)" % [g.fmt(loan), g.fmt(repay)]) if s == 0 else null
	check(blocked, "담보 물건은 기한 전 도매 처분 불가")
	check(redeemed > 0 and forfeited > 0, "상환 %d건 · 몰수 %d건 모두 발생" % [redeemed, forfeited])


func test_specials() -> void:
	print("[특수 선택지: 스킬·직원·평판 조건]")
	var g = new_game(31)
	g.event = ""
	g.flip_open()
	g.start_haggle()
	check(g.special_options().is_empty(), "조건 미달이면 특수 선택지 없음")
	g.skills["charm"] = 3
	g.skills["psych"] = 2
	g.rep = 40
	g.staff.append("expert")
	var ids: Array = g.special_options().map(func(o): return o[0])
	check(ids.has("persuade") and ids.has("read") and ids.has("fame"), "화술·심리·평판 선택지 등장 %s" % str(ids))
	g.use_special("read")
	check(g.cur.has("read") and not g.special_options().map(func(o): return o[0]).has("read"), "속마음 읽기는 한 번만, 칠판에 범위 표시")
	var lim: int = g.neg.max_price if g.cur["buy"] else g.neg.min_price
	check(g.cur["read"][0] <= lim and lim <= g.cur["read"][1], "읽은 범위 안에 실제 한계선이 있음")
	var before: int = g.their_price()
	g.use_special("persuade")
	check(g.cur["gone"] or (g.their_price() != before or String(g.cur["msg"]).contains("말로")), "설득 결과가 가격이나 대사에 반영")


func test_stats_and_collection() -> void:
	print("[통계·도감]")
	var g = new_game(41)
	var bot = Bots.new(g, "random", 41)
	for d in 10:
		bot.play_day()
	var sum: Dictionary = g.stats_sum(0)
	check(int(sum["days"]) == g.history.size() and g.history.size() >= 9, "마감한 날마다 기록 (%d일)" % g.history.size())
	check(int(sum["cash"]) == g.money - 5000, "기록된 현금 변화 합계 = 실제 현금 변화 (%s)" % g.fmt(int(sum["cash"])))
	var w: Dictionary = g.stats_sum(7)
	check(int(w["days"]) == mini(7, g.history.size()), "최근 7일 합계")
	var h = new_game(42)
	var cat: String = "painting"
	var m0: int = h.money
	for t in data.items["categories"][cat]["items"]:
		h.collect({"cat": cat, "name": t[0], "r": 1})
	check(h.col_done.has(cat) and h.money > m0 and h.collection.size() == data.items["categories"][cat]["items"].size(), "한 종류 완성 시 상금 지급")


func test_all_events() -> void:
	print("[불청객 이벤트: 모든 선택지]")
	var ok := true
	var n := 0
	for k in data.events:
		for i in data.events[k]["opts"].size():
			var g = new_game(600 + n)
			g.money = 20000
			g.event = k
			g.flip_open()
			if g.phase != "visit" or g.cur["vk"] != k:
				ok = false
			g.visit_pick(i)
			if not g.cur["gone"] or String(g.cur["msg"]) == "":
				ok = false
			g.open_shop()
			if g.phase != "open":
				ok = false
			n += 1
	check(ok, "이벤트 %d종 · 선택지 %d개 모두 정상 진행" % [data.events.size(), n])


func _visit(k: String, i: int, seed := 900, money := 5000):
	var g = new_game(seed)
	g.money = money
	g.event = k
	g.flip_open()
	g.visit_pick(i)
	return g


func test_event_effects() -> void:
	print("[불청객 이벤트: 효과]")
	var g = _visit("insurance", 0)
	check(g.money == 4700 and g.cur["mood"] == "happy", "자릿세 300냥 지불")
	g = new_game(901)
	g.money = 5000
	g.staff.append("guard")
	g.event = "insurance"
	g.flip_open()
	g.visit_pick(1)
	check(g.money == 5000 and String(g.cur["msg"]).contains("문지기"), "문지기가 왈패를 막음")
	g = _visit("tax", 0, 902, 20000)
	check(g.money == 19000, "세금 5%% 추징 (%d)" % g.money)
	g = new_game(903)
	g.inv.clear()
	g.event = "grandma"
	g.flip_open()
	g.visit_pick(0)
	check(g.inv.size() == 1, "별할멈이 물건을 줌")
	g = new_game(904)
	g.money = 50000
	g.inv.clear()
	g.event = "peddler"
	g.flip_open()
	g.visit_pick(0)
	check(g.inv.size() == 1 and g.money == 50000 - int(g.inv[0]["paid"]) and int(g.inv[0]["paid"]) > 0, "방물장수 보따리 구입")
	g = new_game(905)
	g.money = 50000
	g.inv.clear()
	var it = g.gen_item(0.0)
	it["c"] = 1
	g.inv.append(it)
	g.event = "goblin"
	g.flip_open()
	g.visit_pick(0)
	check(int(g.inv[0]["c"]) == 2 and g.money == 49850, "도깨비 땜장이가 상태를 한 단계 올림")
	g = new_game(906)
	g.inv.clear()
	g.money = 50000
	g.event = "goblin"
	g.flip_open()
	g.visit_pick(0)
	check(g.money == 50000, "고칠 물건이 없으면 돈을 받지 않음")
	g = new_game(907)
	g.staff.append("analyst")
	var r0: int = g.rep
	g.event = "inspector"
	g.flip_open()
	g.visit_pick(0)
	check(g.rep == r0 + 2, "시세꾼이 있으면 검사 통과 + 평판")
	var bad: Array = []
	for k in data.events:
		var e: Dictionary = data.events[k]
		if e.get("res", []).size() != e["opts"].size():
			bad.append(k)
		if JSON.stringify(e).contains("$"):
			bad.append(k + "$")
	check(bad.is_empty(), "모든 이벤트에 선택지별 결과가 있고 달러 표기 없음 %s" % str(bad))


func _find_button(node: Node, text: String) -> Button:
	if node.is_queued_for_deletion():
		return null
	if node is Button and node.text.begins_with(text):
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func test_night_recovery_ui() -> void:
	var old = _main.g
	var g = GameState.new(_main.D, 932)
	g.start_day()
	g.money = 10000
	g.buy_belong("alley")
	g.buy_belong("cart")
	g.close_shop()
	g.money = -3500
	_main.g = g
	_main.show_receipt()
	var enter := _find_button(_main.modal, "살림 되팔아 현금 마련")
	check(enter != null, "마감 장부에 살림 되팔기 진입 버튼")
	if enter != null:
		enter.pressed.emit()
	var sell := _find_button(_main.modal, "짐꾼 로봇 수레 팔기")
	check(sell != null, "마감 중 실제 살림 판매 버튼이 열림")
	if sell != null:
		sell.pressed.emit()
	check(g.money == -2450 and not g.is_bankrupt(), "마감 화면에서 판매하면 실제 현금과 파산 여부 갱신")
	var back := _find_button(_main.modal, "마감 장부로 돌아가기")
	if back != null:
		back.pressed.emit()
	var next := _find_button(_main.modal, "불 끄고 퇴근")
	check(back != null and next != null, "살림을 판 뒤 마감 장부와 다음 날로 복귀")
	if next != null:
		next.pressed.emit()
	check(g.day == 2 and g.phase == "morning", "마감 회복 전체 화면 흐름으로 다음 날 도달")
	_main.g = old
	_main.close_modal()


func test_large_customer_day() -> void:
	print("[후반 많은 손님 진단]")
	var g = new_game(933)
	g.rep = 15000
	g.event = ""
	var bot = Bots.new(g, "smart", 1033)
	check(bot.day_step_limit() > 2000, "후반 행동 한도가 평판에 따라 늘어남")
	var n := 0
	while g.phase != "night" and n < bot.day_step_limit():
		if g.phase == "morning":
			g.flip_open()
		elif g.cur.get("gone", false):
			g.next_customer()
		else:
			g.refuse()
		n += 1
	check(g.phase == "night" and n > 1000, "평판 15,000의 많은 손님도 정상 마감 가능")
